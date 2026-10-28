"""The agenda parser as a tiny FastAPI app in its own Lambda function (same image, other command,
no VPC). It receives text and returns JSON; it never touches the database."""

import asyncio
import json
import time
from datetime import date

from botocore.exceptions import BotoCoreError, ClientError
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from app.ai.agenda import PARSER_MODEL, PROMPT_VERSION, AgendaParseError, cost_usd, parse_agenda
from app.auth import InvalidTokenError, TokenVerifier
from app.config import settings

MAX_CHARS = 10_000
THROTTLED = {"ThrottlingException", "TooManyRequestsException", "ServiceQuotaExceededException"}

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["POST"],
    allow_headers=["authorization", "content-type"],
)

_verifier: TokenVerifier | None = None


def get_verifier() -> TokenVerifier:
    global _verifier
    if _verifier is None:
        if not settings.cognito_user_pool_id or not settings.cognito_client_id:
            raise HTTPException(503, "Authentication is not configured")
        _verifier = TokenVerifier(settings.cognito_user_pool_id, settings.cognito_client_id)
    return _verifier


class ParseRequest(BaseModel):
    text: str
    today: date
    tz: str


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.post("/parse")
async def parse(req: ParseRequest, authorization: str = Header(default="")) -> dict:
    token = authorization.removeprefix("Bearer ").strip()
    try:
        claims = await get_verifier().verify(token)
    except InvalidTokenError:
        raise HTTPException(401, "Invalid or expired token") from None
    if len(req.text) > MAX_CHARS:
        raise HTTPException(413, f"Text is longer than {MAX_CHARS} characters")

    started = time.monotonic()
    try:
        agenda, usage = await asyncio.to_thread(parse_agenda, req.text, req.today, req.tz)
    except AgendaParseError as error:
        raise HTTPException(422, str(error)) from None
    except ClientError as error:
        code = error.response.get("Error", {}).get("Code", "")
        print(
            json.dumps({"event": "bedrock_error", "code": code, "message": str(error)[:300]}),
            flush=True,
        )
        if code in THROTTLED:
            raise HTTPException(429, "The service is busy, try again in a minute") from None
        raise HTTPException(502, "The model service is unavailable") from None
    except BotoCoreError:
        raise HTTPException(502, "The model service is unavailable") from None

    print(
        json.dumps(
            {
                "event": "agenda_parsed",
                "user": claims["sub"],
                "model": PARSER_MODEL,
                "prompt_version": PROMPT_VERSION,
                **usage,
                "latency_ms": int((time.monotonic() - started) * 1000),
                "cost_usd": cost_usd(PARSER_MODEL, usage),
            }
        ),
        flush=True,
    )
    return {
        "agenda": agenda.model_dump(mode="json"),
        "model": PARSER_MODEL,
        "prompt_version": PROMPT_VERSION,
    }
