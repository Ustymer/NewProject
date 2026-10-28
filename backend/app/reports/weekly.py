import asyncio
import csv
import io
import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from app.models import Meeting, User, meeting_participants

TZ = ZoneInfo("Europe/Kyiv")


def report_key(week: str) -> str:
    return f"reports/{week}.csv"  # same week -> same key -> idempotent


def week_bounds(week: str) -> tuple[datetime, datetime]:
    start = datetime.strptime(f"{week}-1", "%G-W%V-%u").replace(tzinfo=TZ)
    return start, start + timedelta(days=7)


def previous_week(week: str) -> str:
    return (week_bounds(week)[0] - timedelta(days=7)).strftime("%G-W%V")


def current_previous_week() -> str:
    return previous_week(datetime.now(TZ).strftime("%G-W%V"))


async def _build(week: str) -> bytes:
    secs = func.extract("epoch", Meeting.ends_at - Meeting.starts_at)
    engine = create_async_engine(os.environ["DATABASE_URL"], poolclass=NullPool)

    def in_week(w):
        s, e = week_bounds(w)
        return Meeting.starts_at >= s, Meeting.starts_at < e

    async def totals(conn, w):
        row = (
            await conn.execute(
                select(func.count(Meeting.id), func.coalesce(func.sum(secs), 0)).where(*in_week(w))
            )
        ).one()
        return row[0], round(float(row[1]) / 3600, 2)

    async with engine.connect() as conn:
        cnt, hrs = await totals(conn, week)
        pcnt, phrs = await totals(conn, previous_week(week))
        n_parts = (
            select(func.count())
            .select_from(meeting_participants)
            .where(meeting_participants.c.meeting_id == Meeting.id)
            .scalar_subquery()
        )
        top = (
            await conn.execute(
                select(Meeting.title, Meeting.starts_at, secs, n_parts)
                .where(*in_week(week))
                .order_by(secs.desc())
                .limit(5)
            )
        ).all()
        owners = (
            await conn.execute(
                select(User.email, func.count(Meeting.id), func.sum(secs))
                .join(User, User.id == Meeting.owner_id)
                .where(*in_week(week))
                .group_by(User.email)
                .order_by(User.email)
            )
        ).all()
    await engine.dispose()

    out = io.StringIO()
    w = csv.writer(out)
    w.writerow(["section", "week", "meetings", "hours"])
    w.writerow(["totals", week, cnt, hrs])
    w.writerow(["totals", previous_week(week), pcnt, phrs])
    w.writerow(["change", "", cnt - pcnt, round(hrs - phrs, 2)])
    w.writerow([])
    w.writerow(["top5", "title", "starts_at", "hours", "participants"])
    for t, s, d, p in top:
        w.writerow(["top5", t, s.astimezone(TZ).isoformat(), round(float(d) / 3600, 2), p])
    w.writerow([])
    w.writerow(["per_owner", "email", "meetings", "hours"])
    for email, c, d in owners:
        w.writerow(["per_owner", email, c, round(float(d) / 3600, 2)])
    return out.getvalue().encode()


def build_weekly_report(week: str) -> bytes:
    """Meetings of one ISO week (e.g. "2026-W40") as CSV."""
    return asyncio.run(_build(week))
