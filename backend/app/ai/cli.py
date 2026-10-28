import os
import sys
from datetime import date

from app.ai.agenda import PARSER_MODEL, cost_usd, parse_agenda

text = os.environ.get("PARSE_TEXT") or sys.stdin.read()
agenda, usage = parse_agenda(text, date.today(), "Europe/Kyiv")
print(agenda.model_dump_json(indent=2))
print("model =", PARSER_MODEL, usage, "cost_usd =", cost_usd(PARSER_MODEL, usage))
