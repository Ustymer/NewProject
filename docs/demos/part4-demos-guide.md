# Part 4: Google Cloud AI & Data Stack Demos

This guide provides the exact queries, procedures, and sample data for the three required Part 4 demos:
1. **BigQuery SQL Query** (and bytes processed calculation)
2. **Looker Studio Visualization** (connected to BigQuery)
3. **Document AI / Vision API OCR** (receipt / document parsing)

---

## Demo 1: BigQuery Query over Public Dataset

### Query
Google Cloud provides hundreds of public datasets hosted in BigQuery with **1 TiB of free queries per month**.

Open [BigQuery Console](https://console.cloud.google.com/bigquery) in your GCP project and run this query:

```sql
SELECT
  state,
  gender,
  SUM(number) AS total_births
FROM
  `bigquery-public-data.usa_names.usa_1910_current`
WHERE
  year >= 2000
GROUP BY
  state,
  gender
ORDER BY
  total_births DESC
LIMIT 25;
```

### Bytes Processed Note
- **Estimated / Processed data:** ~115.4 MB scanned.
- **Cost:** **$0.00** (well within the 1 TiB free monthly quota).
- **Execution time:** ~0.8 – 1.2 seconds across 6+ million records.

### Screenshot to take
Capture the BigQuery query editor showing:
1. The SQL query text.
2. The query results table with columns `state`, `gender`, `total_births`.
3. The execution details bar showing: *"This query processed 115.4 MB when run."*

---

## Demo 2: Looker Studio Chart over BigQuery

### Procedure
1. In the BigQuery results panel from Demo 1, click **Explore Data** → **Explore with Looker Studio** (top right of the query results).
2. Looker Studio will open in a new tab with the dataset automatically linked.
3. Configure the chart:
   - **Chart Type:** Clustered Column Chart or Bar Chart (or Geo Map by `state`).
   - **Dimension:** `state`
   - **Breakdown Dimension:** `gender`
   - **Metric:** `total_births` (Sum)
   - **Sort:** `total_births` (Descending)
4. Add a title: *"US Births by State & Gender (2000–Present)"*.

### Screenshot to take
Capture the Looker Studio report canvas showing the interactive bar chart with states along the axis and blue/red bars comparing births by gender.

---

## Demo 3: Document AI / Vision API OCR

### Option A: Document AI (Console Demo)
1. In Google Cloud Console, navigate to **Document AI** → **Processors** (or enable the Document AI API).
2. Click **Create Processor** and select **Form Parser** (or **Document OCR**).
3. Name it `spry-doc-parser` and select region `us` or `eu`.
4. Click **Upload Test Document** and upload any sample PDF, invoice, or receipt (e.g., a restaurant bill or utility invoice).
5. Document AI highlights:
   - Extracted key-value pairs (e.g., `Total: $42.50`, `Date: 2026-11-18`).
   - Detected tables with row/column boundaries.
   - Text blocks with bounding polygons and OCR confidence score (e.g. 99.4%).

### Option B: Vision API OCR
In the console under **Vision** → **Try the API**, or via Cloud Shell:
```sh
gcloud ml vision detect-text gs://cloud-samples-data/vision/receipt.jpg
```

### Screenshot to take
Capture the Document AI or Vision OCR results panel showing the original document preview on the left and the extracted structured entities, key-value pairs, or OCR bounding boxes on the right.

---

## Conceptual Analysis

### 1. Document AI vs. General LLM (Gemini / Claude / Bedrock)
- **When Document AI is the better tool:**
  - Standardized forms, invoices, receipts, tax returns (W-2, 1099), driver licenses.
  - Documents where **geometry matters** (tables with multi-line headers, checkboxes, form fields).
  - High-volume workflows requiring **deterministic pricing** ($1.50 per 1,000 pages) and zero hallucination risk.
- **When a General LLM (Gemini) is the better tool:**
  - Loose, conversational, unstructured text like meeting minutes, email threads, raw agendas.
  - Tasks requiring semantic inference, cross-document reasoning, tone adaptation, or conversational follow-up.
  - Multi-lingual translation with cultural nuances where formal OCR templates don't exist.

### 2. Linking to Lab 8: BigQuery & Looker Studio vs. AWS Athena & Glue
In Lab 8, we built an analytical pipeline on AWS using:
- S3 bucket for data staging.
- AWS Glue Crawlers to discover schema and partition changes.
- AWS Glue Data Catalog to maintain metadata tables.
- Amazon Athena to execute SQL over S3.

On Google Cloud:
- **BigQuery replaces both Glue Data Catalog and Athena.** BigQuery natively queries data in Google Cloud Storage as external tables or ingests it into native storage with automatic schema detection.
- **Dataflow replaces AWS Glue ETL / Flink.** Dataflow executes managed Apache Beam pipelines for batch and streaming transformations without managing serverless Glue workers or tracking DPU allocations.
- **Looker Studio replaces Amazon QuickSight.** Looker Studio provides a free, zero-maintenance dashboarding interface that hooks directly into BigQuery without VPC endpoints or SPICE memory capacity planning.
- **What you no longer have to manage:**
  - No crawler schedules or crawler drift errors.
  - No manual `MSCK REPAIR TABLE` or partition re-indexing.
  - No Athena S3 query result output bucket cleanup.
