import logging, os, urllib.parse
from email.message import EmailMessage
import boto3

log = logging.getLogger()
log.setLevel(logging.INFO)
s3 = boto3.client("s3")
ses = boto3.client("sesv2")

def handler(event, context):
    for r in event["Records"]:
        bucket = r["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(r["s3"]["object"]["key"])
        log.info("report-mailer triggered trigger=s3 key=%s", key)
        data = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
        week = key.rsplit("/", 1)[-1][:-4]
        msg = EmailMessage()
        msg["Subject"] = "Weekly meetings report " + week
        msg["From"] = os.environ["SENDER"]
        msg["To"] = os.environ["RECIPIENTS"]
        msg.set_content("The report for " + week + " is attached.")
        msg.add_attachment(data, maintype="text", subtype="csv", filename=week + ".csv")
        ses.send_email(Content={"Raw": {"Data": msg.as_bytes()}})
        log.info("report-mailer sent %s", key)
