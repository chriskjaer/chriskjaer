#!/usr/bin/env python3

import argparse
import html
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Dict, List


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

        for item in items:
            title = item.find("title").text if item.find("title") is not None else ""
            author = (
                item.find("author_name").text if item.find("author_name") is not None else ""
            )
            link = item.find("link").text if item.find("link") is not None else ""
            books.append({"title": title or "", "author": author or "", "link": link or ""})

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


def _smol_li(title: str, author: str) -> str:
    title = html.escape(title.strip())
    author = html.escape(author.strip())

    if not title:
        title = "(untitled)"

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


def _write_list(out_path: Path, shelf: str, books: List[Dict[str, Any]]) -> None:
    header = [
        "-# Generated file. Do not edit.",
        f"-# Source: Goodreads shelf '{shelf}' (user {GOODREADS_USER_ID}).",
        "-# Update: make build (or scripts/generate_books_from_goodreads.py).",
        "",
    ]

    items = []
    for book in books:
        items.append(_smol_li(str(book.get("title", "")), str(book.get("author", ""))))

    if not items:
        items = [
            "li",
            "  span.book",
            "    | (no data)",
        ]

    out_path.write_text("\n".join(header + ["\n\n".join(items), ""]))


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
