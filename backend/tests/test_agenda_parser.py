from datetime import date

import pytest
from pydantic import ValidationError

from app.ai.agenda import ActionItem, AgendaItem, ParsedAgenda


def test_valid_agenda():
    agenda = ParsedAgenda(
        title="Project meeting",
        starts_at="2026-10-29T15:00:00",
        duration_minutes=60,
        items=[{"topic": "Launch plan", "minutes": 20}],
        action_items=[{"task": "Prepare slides", "owner": "Anna"}],
        language="en",
    )
    assert agenda.items[0].topic == "Launch plan"
    assert agenda.action_items[0].owner == "Anna"


def test_agenda_item_requires_topic():
    with pytest.raises(ValidationError):
        AgendaItem(topic="")


def test_agenda_item_minutes_limit():
    with pytest.raises(ValidationError):
        AgendaItem(topic="Planning", minutes=481)


def test_action_item_requires_task():
    with pytest.raises(ValidationError):
        ActionItem(task="")


def test_action_item_accepts_due_date():
    item = ActionItem(task="Send notes", due=date(2026, 10, 30))
    assert item.due == date(2026, 10, 30)
