# Part 3: Cost Comparison & Analysis: AWS vs. Google Cloud

All prices are on-demand list prices in USD (AWS in `us-east-1` / `eu-north-1`, Google Cloud in `us-central1`), excluding tax, calculated over 730 hours per month.

---

## 1. Reference: Spry Core (Idle for a Month, 0 Requests)

| Component | AWS (Lab 4, Stage 2) | Google Cloud (Cloud SQL) | Google Cloud (Firestore Alternative) |
|---|---|---|---|
| **Frontend + CDN + HTTPS** | CloudFront Free Plan + S3 & WAF: **$0.00** | Firebase Hosting Free Tier (10 GB stored, 360 MB/day egress): **$0.00** | Firebase Hosting: **$0.00** |
| **API** | AWS Lambda (0 requests): **$0.00** | Cloud Run (scaled to 0 instances): **$0.00** | Cloud Run (scaled to 0 instances): **$0.00** |
| **Database Compute** | Aurora Serverless v2 (pauses after 5 min idle): **$0.00** | Cloud SQL `db-f1-micro` (running 730h @ $0.0105/h): **$7.67** *(or **$0.00** if stopped)* | Firestore (0 reads/writes, serverless): **$0.00** |
| **Database Storage** | ~1 GB Aurora storage @ $0.10/GB: **$0.10** | 10 GB SSD @ $0.17/GB: **$1.70** *(billed even when instance stopped)* | Stored data (<1 GiB free): **$0.00** |
| **Registry, Secrets, Logs** | ECR, SSM Parameter Store, CloudWatch: **~$0.20** | Artifact Registry (0.5 GB free), Secret Manager (6 versions free), Cloud Logging (50 GiB free): **$0.00** | Within GCP free tiers: **$0.00** |
| **Total / month** | **≈ $0.30** | **≈ $9.37** *(or **≈ $1.70** with stopped DB)* | **$0.00** |

---

## 2. Recomputed Cost Across the Four Traffic Profiles

### Profile 1: Nobody (Zero Traffic for 1 Month)
- **AWS:** **$0.30** (Aurora pauses after 5 minutes; storage only).
- **Google Cloud (Cloud SQL 24/7):** **$9.37** (`db-f1-micro` runs continuously).
- **Google Cloud (Cloud SQL stopped):** **$1.70** (only 10 GB storage billed).
- **Google Cloud (Firestore):** **$0.00**.
- **Cheaper Cloud:** **AWS** (or GCP with Firestore).

### Profile 2: Class Demos (10 sessions × 2 hours = 20 active hours)
- **Assumptions:** ~50,000 API requests, ~250,000 DB queries across 10 two-hour sessions.
- **AWS:**
  - Lambda: within 1M free requests ($0.00).
  - Aurora Serverless v2: 22.5 hours active (including 15 min cool-down each session). At 0.5 ACU × $0.12/ACU-h = **$1.35** compute + $0.10 storage = **$1.45**.
  - S3 / CloudFront: $0.00.
  - **AWS Total: ≈ $1.55**
- **Google Cloud (Cloud SQL):**
  - Cloud Run: 50,000 requests is within 2M free requests ($0.00).
  - Cloud SQL if left running 24/7: $7.67 compute + $1.70 storage = **$9.37**.
  - Cloud SQL if started only for demos (22.5 hours): 22.5h × $0.0105/h = $0.24 compute + $1.70 storage = **$1.94**.
- **Cheaper Cloud:** **AWS** ($1.55 vs $9.37 running, or $1.55 vs $1.94 stopped).

### Profile 3: Office Hours (8 hours/day × 22 work days = 176 active hours)
- **Assumptions:** ~200,000 requests/month; active during business hours, idle nights/weekends.
- **AWS:**
  - Lambda: within free tier ($0.00).
  - Aurora Serverless v2: ~185 hours active (with cool-downs). Minimum 0.5 ACU × $0.12 × 185h = **$11.10** compute + $0.10 storage = **$11.20**.
  - **AWS Total: ≈ $11.40**
- **Google Cloud (Cloud SQL):**
  - Cloud Run: within free tier ($0.00).
  - Cloud SQL running 24/7: $7.67 compute + $1.70 storage = **$9.37**.
  - Cloud SQL stopped on nights/weekends (185h active): 185h × $0.0105/h = $1.94 compute + $1.70 storage = **$3.64**.
- **Cheaper Cloud:** **Google Cloud** ($9.37 running or $3.64 stopped vs $11.40 on AWS).

### Profile 4: Busy Around the Clock (24/7, 730 hours/month)
- **Assumptions:** ~2,000,000 requests/month; database is kept constantly active.
- **AWS:**
  - Lambda: 2M requests (1M billable @ $0.20/M + vCPU time) ≈ **$1.50**.
  - Aurora Serverless v2: 730 hours @ 0.5 ACU minimum = 730 × 0.5 × $0.12 = **$43.80** compute (and if workload spikes to 1 ACU during peak hours, compute easily exceeds **$75.00+**). Storage = $0.15.
  - **AWS Total: ≈ $45.50 – $80.00+**
- **Google Cloud (Cloud SQL):**
  - Cloud Run: 2M requests free; active compute time within free tier or ~$0.50.
  - Cloud SQL `db-f1-micro`: 730h × $0.0105/h = **$7.67** compute + $1.70 storage = **$9.37**.
  - **GCP Total: ≈ $9.90 – $10.50**
- **Cheaper Cloud:** **Google Cloud is substantially cheaper** (~$10/mo vs ~$46–80/mo).

---

## 3. Core Questions Answered

### Q1: Which cloud is cheaper for each profile, and which single line decides it?

- **Profile 1 (Nobody):** **AWS is cheaper** ($0.30 vs $9.37).
- **Profile 2 (Class demos):** **AWS is cheaper** ($1.55 vs $9.37 running, or $1.94 stopped).
- **Profile 3 (Office hours):** **GCP is cheaper** ($9.37 running / $3.64 stopped vs $11.40).
- **Profile 4 (Busy 24/7):** **GCP is dramatically cheaper** (~$10.40 vs ~$46.00+).

**The deciding line:** **Database Compute.**
- On AWS, Aurora Serverless v2 scales down to 0 ACU and **pauses automatically**, costing $0 compute when nobody visits. However, its running rate is expensive: 0.5 ACU costs **$0.06 per hour** ($0.12 per ACU-hour).
- On GCP, Cloud SQL `db-f1-micro` costs only **$0.0105 per hour** (nearly **6× cheaper** per active hour than Aurora's minimum), but it **never pauses automatically**.
- Therefore, for bursty or near-zero workloads, Aurora's auto-pause wins. As soon as the database is kept active for more than ~150 hours a month, Cloud SQL's much lower hourly rate wins decisively.

---

### Q2: Aurora can become more expensive than an instance when something keeps it awake. Where is the equivalent trap on the GCP side?

On AWS, the trap is an unclosed connection, background polling loop, or health check that prevents Aurora from pausing, silently driving the bill to $43.80/month.

On Google Cloud, there are three equivalent architectural traps:

1. **The Cloud SQL Idle Instance Trap (The primary student trap):**
   Unlike Aurora, Cloud SQL has **no auto-pause capability**. If a student finishes a lab, closes their laptop, and leaves the instance deployed, it continues billing $0.0105/hour + SSD storage every hour forever ($9.37/month), draining credits or generating unexpected credit card bills.

2. **The Cloud Run Minimum Instances Trap (`min_instances > 0`):**
   If `min_instances = 1` is configured on Cloud Run (e.g. to eliminate cold starts), Cloud Run allocates and continuously bills container CPU and memory 24/7 (~$24/month for 1 vCPU / 1 GiB), completely negating serverless scale-to-zero savings.

3. **The Firestore N+1 Read Explosion Trap:**
   Teams switching to Firestore to achieve a $0 database bill often encounter query traps. Firestore bills per document read. An unpaginated meeting list endpoint with 50 meetings and 10 attendees per meeting that issues separate document reads will perform 500 reads on every page refresh. Just 100 page views exhaust the daily 50,000 free read quota, after which every click costs money.
