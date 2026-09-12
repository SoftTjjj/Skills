#!/usr/bin/env python3
"""Emit CST timestamp and ISO-week log filename metadata."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timedelta, timezone


CST = timezone(timedelta(hours=8), "CST")


def build_meta(now: datetime) -> dict[str, str]:
    now = now.astimezone(CST)
    iso_year, iso_week, iso_weekday = now.isocalendar()
    monday = now - timedelta(days=iso_weekday - 1)
    sunday = monday + timedelta(days=6)
    week_start = monday.strftime("%m%d")
    week_end = sunday.strftime("%m%d")
    weekly_file = f"{iso_year}-W{iso_week:02d}-{week_start}-{week_end}.md"
    return {
        "timestamp": now.strftime("%Y-%m-%d %H:%M:%S CST"),
        "timezone": "CST",
        "utc_offset": "+08:00",
        "iso_week": f"{iso_year}-W{iso_week:02d}",
        "week_start": week_start,
        "week_end": week_end,
        "weekly_file": weekly_file,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Print CST timestamp and ISO weekly log filename metadata as JSON."
    )
    parser.add_argument(
        "--at",
        help=(
            "Optional ISO datetime for deterministic checks. Naive values are treated "
            "as CST; timezone-aware values are converted to CST."
        ),
    )
    return parser.parse_args()


def parse_at(value: str) -> datetime:
    normalized = value.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=CST)
    return parsed


def main() -> None:
    args = parse_args()
    now = parse_at(args.at) if args.at else datetime.now(CST)
    print(json.dumps(build_meta(now), ensure_ascii=True, sort_keys=True))


if __name__ == "__main__":
    main()
