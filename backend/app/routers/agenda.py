import asyncio
from datetime import date

from botocore.exceptions import BotoCoreError, ClientError
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.ai.agenda import (
    PARSER_MODEL,
    PROMPT_VERSION,
    AgendaParseError,
    parse_agenda,
)
from app.auth import get_current_user

router = APIRouter(
    prefix="/agenda",
    tags=["agenda"],
    dependencies=[Depends(get_current_user)],
)


class ParseRequest(BaseModel):
    text: str = Field(min_length=1, max_length=10_000)
    today: date
    tz: str = "Europe/Kyiv"


@router.post("/parse")
async def parse(request: ParseRequest) -> dict:
    try:
        agenda, usage = await asyncio.to_thread(
            parse_agenda,
            request.text,
            request.today,
            request.tz,
        )
    except AgendaParseError as error:
        raise HTTPException(422, str(error)) from None
    except ClientError, BotoCoreError:
        raise HTTPException(502, "The model service is unavailable") from None

    return {
        "agenda": agenda.model_dump(mode="json"),
        "model": PARSER_MODEL,
        "prompt_version": PROMPT_VERSION,
    }
