# ADR 0008: Multicloud Architecture and Google Cloud Platform Migration

Status: Accepted

## Context

By Lab 7, Spry (NewProject) runs on AWS and is managed via Terraform and CloudFormation:
- Frontend: React SPA in private S3 bucket distributed via CloudFront with WAF.
- API: FastAPI running in container on AWS Lambda (via Lambda Web Adapter) with Function URL.
- Database: Aurora Serverless v2 (PostgreSQL 17, 0–1 ACU, pauses on idle).
- Background batch & AI: SQS, EventBridge Scheduler, SES, and Amazon Bedrock.

Architects regularly face the challenge of multicloud redundancy, vendor lock-in mitigation, and cloud-to-cloud migration. This ADR evaluates what it takes to run Spry on Google Cloud Platform (GCP), decides which services to replace, keep on AWS, or drop for the core MVP, and documents the architectural and financial trade-offs.

---

## Service Decision Matrix

| Spry on AWS | On Google Cloud | Decision | Architectural Rationale & Differences |
|---|---|---|---|
| **S3 + CloudFront (Free plan) + WAF, static frontend** | **Firebase Hosting** | **Replace** | Firebase Hosting provides a global CDN, automated SSL certificate, custom domains, and zero idle cost (10 GB storage, 360 MB/day egress free). Unlike raw Google Cloud Storage (which requires an expensive HTTP(S) Load Balancer billing ~$18+/month even when idle), Firebase Hosting includes HTTPS out of the box and seamlessly rewrites `/api/**` to Cloud Run, avoiding CORS issues entirely. |
| **Lambda + Function URL, FastAPI** | **Cloud Run** | **Replace** | Cloud Run runs the standard container natively, scales to zero, and terminates HTTPS automatically with a public URL. Eliminates the AWS Lambda Web Adapter (`aws-lambda-adapter`) and Mangum layers. Cloud Run provides standard HTTP request handling on the `$PORT` environment variable. |
| **ECR** | **Artifact Registry** | **Replace** | Native OCI-compliant registry. 0.5 GB free tier storage per month; integrates directly with Cloud Run IAM without long-lived credentials. |
| **Aurora Serverless v2 (0–1 ACU, pauses)** | **Cloud SQL for PostgreSQL (`db-f1-micro`)** | **Replace (Core)** | Cloud SQL provides PostgreSQL compatibility without code changes. Unlike Aurora, Cloud SQL does not automatically pause compute when idle; it runs and bills continuously ($0.0105/hr ≈ $7.67/mo) unless stopped manually or via automation. |
| **DynamoDB (if NoSQL)** | **Firestore** | **Drop for Core** | Firestore offers a generous free tier (50k reads, 20k writes/day free), yielding $0/month idle. However, it requires a complete rewrite of SQLAlchemy models, Alembic migrations, foreign keys, and relations into document structures. Kept Cloud SQL for relational compatibility. |
| **Cognito User Pool + Google IDP** | **Identity Platform (Firebase Auth) / Kept on AWS** | **Keep on AWS (Phase 1)** | Keeping Cognito on AWS prevents disruption to existing student accounts and Google OAuth credentials. For full GCP migration, Identity Platform provides 50,000 MAUs free (vs Cognito's 10,000). |
| **EventBridge Scheduler** | **Cloud Scheduler** | **Keep on AWS** | Non-core for MVP. Kept on AWS to drive the weekly report pipeline. (GCP provides 3 free jobs/month). |
| **SQS** | **Cloud Tasks / Pub/Sub** | **Keep on AWS** | Kept on AWS with the report pipeline. |
| **S3 event → Lambda** | **Cloud Storage + Eventarc → Cloud Run** | **Keep on AWS** | Kept on AWS with the report pipeline. |
| **SES** | **External provider (SendGrid/Mailgun) or keep SES** | **Keep SES** | Google Cloud does not provide a native SMTP/transactional email service. Using AWS SES cross-cloud or SendGrid via Secret Manager API keys is the standard multicloud solution. |
| **Bedrock (Claude, Nova)** | **Vertex AI (Gemini / Claude)** | **Keep on AWS (Phase 1)** | Bedrock currently runs the agenda parser. Vertex AI Studio offers Gemini 1.5/2.0 Flash at lower token rates, but core app migration leaves AI on AWS initially. |
| **SSM Parameter Store / Secrets Manager** | **Secret Manager** | **Replace** | GCP Secret Manager provides 6 active secret versions and 10,000 operations/month for free. Used to store generated database passwords and connection strings. |
| **CloudWatch Logs** | **Cloud Logging** | **Replace** | Cloud Run automatically sends container stdout/stderr to Cloud Logging without extra agents or costs within the 50 GiB/month free tier. |
| **IAM Roles** | **Service Accounts + IAM Roles** | **Replace** | Dedicated service accounts created per component (`sa-cloud-run`) with least privilege (`roles/cloudsql.client`, `roles/secretmanager.secretAccessor`). No long-lived service account keys downloaded; laptop uses Application Default Credentials (ADC) and CI uses Workload Identity Federation. |
| **Terraform AWS provider** | **Terraform Google provider** | **Replace (`gcp/`)** | Created an isolated `gcp/` Terraform root module with its own state to prevent cross-cloud blast radius. |

---

## Key Architectural Decisions

### 1. The Database: Cloud SQL vs. Firestore vs. Cross-Cloud Aurora

We evaluated four strategies for the Spry database on Google Cloud:

1. **Cloud SQL for PostgreSQL (`db-f1-micro`) 24/7:**
   - **Cost:** ~$7.67/month for shared-core compute + ~$1.70/month for 10 GB SSD = **~$9.37/month** base cost.
   - **Latency:** Sub-5ms low latency between Cloud Run and Cloud SQL in `us-central1` via the Cloud SQL Auth Proxy unix socket (`/cloudsql/...`).
   - **Code impact:** **Zero changes.** Existing SQLAlchemy models, Pydantic schemas, and Alembic migrations work unmodified.
   - **Verdict:** Selected for the primary GCP deployment.

2. **Cloud SQL stopped during inactivity (Night/Weekends):**
   - **Cost:** Compute is billed $0 while stopped; only storage is billed ($1.70/mo). For example, running 40 hours a month costs ~$0.42 compute + $1.70 storage = **~$2.12/month**.
   - **Latency:** Instant while running, but when stopped the API is unavailable until started (60–90 second startup time).
   - **Code impact:** Zero code changes. Can be automated via `gcloud sql instances patch --activation-policy=NEVER` or Cloud Scheduler.

3. **Firestore (NoSQL):**
   - **Cost:** **$0.00/month** under free tier (50,000 reads, 20,000 writes/day free).
   - **Latency:** Fast document lookups (~15–25ms), serverless scaling with no idle instances.
   - **Code impact:** **Prohibitive.** Requires throwing away relational models, foreign keys, cascade deletes, and Alembic migrations. Data must be denormalized. A list query fetching 20 meetings with 5 participants each could consume 100+ reads per page refresh.

4. **Keep Database on AWS Aurora and connect across clouds:**
   - **Cost:** ~$0.10/month on AWS when paused.
   - **Latency:** Severe penalty: 60–120ms round-trip WAN latency per SQL query across US regions. A single HTTP request making 3–5 SQL queries suffers a 300–600ms latency hit.
   - **Egress & Security:** Incurs cross-cloud egress fees and requires public database endpoint exposure or complex cross-cloud IPsec VPN.
   - **Verdict:** Rejected due to unacceptable latency and security posture.

---

### 2. Transactional E-mail

- **Chosen Approach:** Multicloud via Amazon SES (or SendGrid).
- **Secret Management:** The SMTP credentials / API key are stored in GCP Secret Manager (`projects/$PROJECT_ID/secrets/mailer-api-key`) and mapped into Cloud Run as an environment variable. No secrets are stored in Git.

---

### 3. Features Not Moved to GCP (And Why)

1. **Cognito User Pool:** Retained on AWS for Phase 1. The frontend already authenticates with Cognito and obtains JWT ID tokens; Cloud Run can validate JWT claims against Cognito's JWKS endpoint without migrating user credentials.
2. **Weekly Report Pipeline (EventBridge + SQS + Lambda + SES):** Asynchronous background job that only runs on Monday mornings. Running it on AWS costs <$0.05/month; duplicating it onto Cloud Scheduler + Pub/Sub + Cloud Run adds migration effort with no user-facing gain.
3. **Agenda Parser (Bedrock):** Kept on AWS for initial milestone; can be migrated as a stretch goal to Vertex AI Gemini 2.0 Flash.

---

### 4. Specialized AI (Document AI / Vision API) vs. General LLM (Gemini / Bedrock)

| Factor | Specialized AI (Document AI / Vision API) | General LLM (Gemini 2.0 Flash / Claude) |
|---|---|---|
| **Best For** | Structured receipts, invoices, forms, tax documents, dense tables, exact bounding-box OCR. | Unstructured meeting notes, conversational agendas, messy human handwriting, intent summarization. |
| **Output** | Deterministic key-value pairs, normalized tables, confidence scores per entity. | Natural language responses, structured JSON when prompted with schemas. |
| **Pricing Model** | Per page / per operation (e.g. OCR: first 1k pages free, then $1.50/1k; Form Parser: $30/1k pages). | Per input/output token (e.g. Gemini 2.0 Flash: $0.10 / $0.40 per 1M tokens). |
| **Speed & Accuracy** | Fast, high precision on standardized document geometry; zero hallucination. | Flexible, can infer implied dates and participants, but subject to hallucination or schema drift. |

**Conclusion:** Use Document AI when parsing rigid documents, scanned PDFs, or receipts with tabular columns. Use General LLMs (Gemini) when interpreting ambiguous meeting agendas or unstructured natural language prompts.

---

### 5. BigQuery & Data Stack vs. AWS Athena & Glue (Lab 8 Comparison)

In Lab 8, querying payment data on AWS required:
1. S3 bucket data staging in partitioned directories.
2. AWS Glue Crawlers to discover schemas and partitions.
3. AWS Glue Data Catalog table definitions.
4. Amazon Athena SQL engine executing queries against S3.

On Google Cloud:
- **BigQuery** unifies the storage, catalog, and compute engine in a single serverless platform. External queries on Cloud Storage or native tables require no crawler jobs or catalog synchronization.
- **Looker Studio** connects directly to BigQuery queries or views natively in seconds without configuring JDBC/ODBC bridges or VPC endpoints.
- **Maintenance eliminated:** No crawler runs to monitor, no partition repair (`MSCK REPAIR TABLE`), and no Glue Catalog sync failures.
