import boto3

from app.ai.agenda import PARSER_MODEL

response = boto3.client("bedrock-runtime", region_name="eu-north-1").converse(
    modelId=PARSER_MODEL,
    messages=[{"role": "user", "content": [{"text": "In one sentence: what is an ISO week?"}]}],
    inferenceConfig={"maxTokens": 200},
)
print(response["output"]["message"]["content"][0]["text"])
print(response["stopReason"], response["usage"])
