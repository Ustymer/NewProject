import json
import logging
import os

import boto3
from fastapi import APIRouter, Body

from app.reports.weekly import build_weekly_report, current_previous_week, report_key

log = logging.getLogger("uvicorn.error")
router = APIRouter()


@router.post("/events")
def events(event: dict = Body(...)):
    """SQS batch from Lambda Web Adapter. Sync on purpose: build_weekly_report uses asyncio.run."""
    failures = []
    for rec in event.get("Records", []):
        try:
            body = json.loads(rec["body"])
            week = body.get("week") or current_previous_week()
            log.info(
                "report-builder triggered trigger=%s via=sqs week=%s", body.get("source"), week
            )
            if os.environ.get("FAIL_WEEK") == week:
                raise RuntimeError("forced failure")
            key = report_key(week)
            boto3.client("s3").put_object(
                Bucket=os.environ["REPORTS_BUCKET"],
                Key=key,
                Body=build_weekly_report(week),
                ContentType="text/csv",
            )
            log.info("report saved key=%s", key)
        except Exception:
            log.exception("report failed")
            failures.append({"itemIdentifier": rec["messageId"]})
    return {"batchItemFailures": failures}
