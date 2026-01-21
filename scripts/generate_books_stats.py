#!/usr/bin/env python3

import json
from pathlib import Path
from typing import Dict


REPO_ROOT = Path(__file__).resolve().parents[1]
CACHE_DIR = REPO_ROOT / "src" / "data" / "goodreads_cache"
DATA_DIR = REPO_ROOT / "src" / "data"
GOODREADS_USER_ID = "32620052"


def main() -> int:
    read_path = CACHE_DIR / f"{GOODREADS_USER_ID}_read.json"
    if not read_path.exists():
        return 0

    books = json.loads(read_path.read_text())

    counts: Dict[int, int] = {}
    for book in books:
        date_read = (book.get("date_read") or "").strip()
        if len(date_read) >= 4 and date_read[:4].isdigit():
            year = int(date_read[:4])
            counts[year] = counts.get(year, 0) + 1

    # newest first
    years = sorted(counts.keys(), reverse=True)

    out_lines = [
        "-# Generated file. Do not edit.",
        "-# Source: Goodreads read shelf cache.",
        "",
        "ul.chart",
    ]

    if not years:
        out_lines += [
            "  li",
            "    | (no data)",
        ]
    else:
        max_count = max(counts.values())
        for year in years:
            count = counts[year]
            pct = int(round((count / max_count) * 100)) if max_count else 0
            out_lines += [
                "  li.bar",
                "    span.year",
                f"      | {year}",
                "    span.track",
                f"      span.fill(style=\"width: {pct}%\")",
                "    span.count",
                f"      | {count}",
            ]

    (DATA_DIR / "books_stats.smol").write_text("\n".join(out_lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
