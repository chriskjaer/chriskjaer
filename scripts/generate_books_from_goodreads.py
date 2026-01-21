#!/usr/bin/env python3

import argparse
import datetime as dt
import html
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import Any, Dict, List, Optional


REPO_ROOT = Path(__file__).resolve().parents[1]
CACHE_DIR = REPO_ROOT / "src" / "data" / "goodreads_cache"
DATA_DIR = REPO_ROOT / "src" / "data"
GOODREADS_USER_ID = "32620052"  # https://www.goodreads.com/user/show/32620052-chris


def _run_goodreads_cli(*args: str) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env["GOODREADS_CACHE_DIR"] = str(CACHE_DIR)
    return subprocess.run(
        [sys.executable, str(REPO_ROOT / "scripts" / "goodreads_cli.py"), *args],
        check=False,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def _cache_path(shelf: str) -> Path:
    return CACHE_DIR / f"{GOODREADS_USER_ID}_{shelf}.json"


def _load_cached_json(shelf: str) -> List[Dict[str, Any]]:
    path = _cache_path(shelf)
    if not path.exists():
        return []
    with path.open() as f:
        return json.load(f)


def _parse_rss_date(value: str) -> Optional[str]:
    value = (value or "").strip()
    if not value:
        return None

    # Goodreads RSS values are usually ISO-ish.
    for fmt in (
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S%z",
        "%a, %d %b %Y %H:%M:%S %z",
    ):
        try:
            parsed = dt.datetime.strptime(value, fmt)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=dt.timezone.utc)
            return parsed.astimezone(dt.timezone.utc).isoformat()
        except ValueError:
            continue

    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(dt.timezone.utc).isoformat()
    except ValueError:
        return None


def _fetch_shelf_rss_stdlib(shelf: str, max_pages: int = 10) -> List[Dict[str, Any]]:
    books: List[Dict[str, Any]] = []

    for page in range(1, max_pages + 1):
        url = (
            "https://www.goodreads.com/review/list_rss/"
            f"{GOODREADS_USER_ID}?shelf={shelf}&per_page=100&page={page}"
        )

        try:
            with urllib.request.urlopen(url, timeout=10) as resp:
                rss_xml = resp.read().decode("utf-8", errors="replace")
        except (urllib.error.URLError, TimeoutError) as e:
            raise RuntimeError(f"rss fetch failed page={page}: {e}")

        root = ET.fromstring(rss_xml)
        items = root.findall(".//item")
        if not items:
            break

        def _t(name: str) -> str:
            el = item.find(name)
            return el.text if el is not None and el.text is not None else ""

        for item in items:
            books.append(
                {
                    "title": _t("title"),
                    "author": _t("author_name"),
                    "link": _t("link"),
                    "rating": _t("user_rating"),
                    "date_read": _parse_rss_date(_t("user_read_at")),
                    "date_added": _parse_rss_date(_t("user_date_created")),
                }
            )

    return books


def _write_cache_json(shelf: str, books: List[Dict[str, Any]]) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = _cache_path(shelf)
    path.write_text(json.dumps(books, indent=2) + "\n")


def _fetch_shelf_json(shelf: str, refresh: bool) -> List[Dict[str, Any]]:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    def _try_cli(use_cache: bool):
        args = ["--user-id", GOODREADS_USER_ID, "--json", "list", shelf]
        if use_cache:
            args.append("--cache")
        p = _run_goodreads_cli(*args)
        if p.returncode != 0:
            return None
        return json.loads(p.stdout)

    def _try_rss():
        try:
            books = _fetch_shelf_rss_stdlib(shelf)
        except Exception:
            return None
        _write_cache_json(shelf, books)
        return books

    # Refresh path: prefer live network, but don't break builds.
    if refresh:
        for attempt in (_try_cli(False), _try_rss()):
            if attempt is not None:
                return attempt
        cached = _load_cached_json(shelf)
        if cached:
            return cached
        return []

    # Default path: try live network via cli/rss, then cache.
    for attempt in (_try_cli(False), _try_rss(), _try_cli(True)):
        if attempt is not None:
            return attempt

    cached = _load_cached_json(shelf)
    if cached:
        return cached

    return []


def _parse_dt(value: Any) -> Optional[dt.datetime]:
    if not value:
        return None

    raw = str(value).strip()
    if not raw:
        return None

    # Common case: already ISO-ish.
    try:
        parsed = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(dt.timezone.utc)
    except ValueError:
        pass

    # Goodreads sometimes emits RFC2822-ish timestamps.
    try:
        parsed = parsedate_to_datetime(raw)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(dt.timezone.utc)
    except (TypeError, ValueError):
        return None


def _format_finished_date(value: Any) -> str:
    parsed = _parse_dt(value)
    if not parsed:
        return ""
    return parsed.date().isoformat()


def _format_rating(value: Any) -> str:
    raw = str(value or "").strip()
    if not raw:
        return ""
    try:
        rating = int(float(raw))
    except ValueError:
        return ""
    if rating <= 0:
        return ""
    return "★" * min(rating, 5)


def _smol_li_basic(book: Dict[str, Any]) -> str:
    title = html.escape(str(book.get("title", "")).strip()) or "(untitled)"
    author = html.escape(str(book.get("author", "")).strip())

    lines = [
        "li",
        "  span.book",
        f"    | {title}",
    ]

    if author:
        lines += [
            "  | ",
            "",
            "  span.author",
            f"    | — {author}",
        ]

    return "\n".join(lines)


def _smol_li_read(book: Dict[str, Any]) -> str:
    title = html.escape(str(book.get("title", "")).strip()) or "(untitled)"
    author = html.escape(str(book.get("author", "")).strip())
    finished = html.escape(_format_finished_date(book.get("date_read")))
    rating = html.escape(_format_rating(book.get("rating")))

    lines = [
        "li",
        "  span.book",
        f"    | {title}",
    ]

    if author:
        lines += [
            "  | ",
            "",
            "  span.author",
            f"    | — {author}",
        ]

    meta_parts: List[str] = []
    if finished:
        meta_parts.append(finished)
    if rating:
        meta_parts.append(rating)

    if meta_parts:
        lines += [
            "  | ",
            "",
            "  span.meta",
            f"    | ({' · '.join(meta_parts)})",
        ]

    return "\n".join(lines)


def _write_fragment(out_path: Path, header_lines: List[str], body: str) -> None:
    out_path.write_text("\n".join(header_lines + [body, ""]))


def _write_list(out_path: Path, shelf: str, books: List[Dict[str, Any]]) -> None:
    header = [
        "-# Generated file. Do not edit.",
        f"-# Source: Goodreads shelf '{shelf}' (user {GOODREADS_USER_ID}).",
        "-# Update: make build (or scripts/generate_books_from_goodreads.py).",
        "",
    ]

    if shelf == "read":
        def _sort_key(b: Dict[str, Any]):
            return _parse_dt(b.get("date_read")) or dt.datetime.min.replace(tzinfo=dt.timezone.utc)

        sorted_books = sorted(books, key=_sort_key, reverse=True)

        by_year: Dict[int, List[Dict[str, Any]]] = {}
        for book in sorted_books:
            parsed = _parse_dt(book.get("date_read"))
            year = parsed.year if parsed else 0
            by_year.setdefault(year, []).append(book)

        years = sorted(by_year.keys(), reverse=True)
        blocks: List[str] = []
        for year in years:
            title = str(year) if year else "Unknown year"
            blocks.append("h3.year")
            blocks.append(f"  | {html.escape(title)}")
            blocks.append("ol.book_list")
            year_items = [
                "\n".join(
                    "  " + line if i != 0 else "  " + line
                    for i, line in enumerate(_smol_li_read(book).splitlines())
                )
                for book in by_year[year]
            ]
            if year_items:
                blocks.append("\n\n".join(year_items))
            else:
                blocks.append("  li\n    span.book\n      | (no data)")

        _write_fragment(out_path, header, "\n".join(blocks))
        return

    if shelf == "to-read":
        def _sort_key(b: Dict[str, Any]):
            return _parse_dt(b.get("date_added")) or dt.datetime.min.replace(tzinfo=dt.timezone.utc)

        books = sorted(books, key=_sort_key, reverse=True)

    items = []
    for book in books:
        items.append(_smol_li_basic(book))

    if not items:
        items = [
            "li",
            "  span.book",
            "    | (no data)",
        ]

    _write_fragment(out_path, header, "\n\n".join(items))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate src/data/books_*.smol from Goodreads")
    parser.add_argument("--refresh", action="store_true", help="Try network refresh first")
    args = parser.parse_args()

    shelves = {
        "currently-reading": DATA_DIR / "books_currently_reading.smol",
        "read": DATA_DIR / "books_read.smol",
        "to-read": DATA_DIR / "books_to_read.smol",
    }

    for shelf, out_path in shelves.items():
        books = _fetch_shelf_json(shelf, refresh=args.refresh)
        _write_list(out_path, shelf, books)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
