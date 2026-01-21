#!/usr/bin/env python3
"""Goodreads CLI - Interact with Goodreads profile via RSS feeds and web scraping.

Vendored from Clawdbot: /home/clawdbot/clawd/goodreads/scripts/goodreads_cli.py

Small tweak: cache directory can be controlled via env:
- GOODREADS_CACHE_DIR
- XDG_CACHE_HOME (uses <XDG_CACHE_HOME>/goodreads)

Goodreads API is deprecated, so this uses:
- RSS feeds for reading data (public, no auth required)
- Web scraping for updates (requires browser automation via playwright)
"""

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import quote_plus

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Error: Required packages not installed.", file=sys.stderr)
    print("Install with: pip install requests beautifulsoup4", file=sys.stderr)
    sys.exit(1)


class GoodreadsClient:
    """Goodreads client using RSS feeds and web scraping."""

    def __init__(self, user_id: str, cache_dir: Optional[Path] = None):
        self.user_id = user_id
        self.base_url = "https://www.goodreads.com"

        if cache_dir is None:
            cache_dir_env = os.environ.get("GOODREADS_CACHE_DIR")
            xdg_cache_home = os.environ.get("XDG_CACHE_HOME")
            if cache_dir_env:
                cache_dir = Path(cache_dir_env)
            elif xdg_cache_home:
                cache_dir = Path(xdg_cache_home) / "goodreads"
            else:
                cache_dir = Path.home() / ".cache" / "goodreads"

        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
            }
        )

    def _get_cache_path(self, shelf: str) -> Path:
        """Get cache file path for a shelf."""
        return self.cache_dir / f"{self.user_id}_{shelf}.json"

    def _fetch_rss(self, shelf: str = "read", per_page: int = 100, page: int = 1) -> str:
        """Fetch RSS feed for a shelf."""
        url = f"{self.base_url}/review/list_rss/{self.user_id}?shelf={shelf}&per_page={per_page}&page={page}"
        response = self.session.get(url, timeout=10)
        response.raise_for_status()
        return response.text

    def _parse_rss_item(self, item: ET.Element) -> Dict:
        """Parse a single RSS item into a book dict."""
        book = {
            "title": item.find("title").text if item.find("title") is not None else "",
            "link": item.find("link").text if item.find("link") is not None else "",
            "author": item.find("author_name").text if item.find("author_name") is not None else "",
            "isbn": item.find("isbn").text if item.find("isbn") is not None else "",
            "rating": item.find("user_rating").text if item.find("user_rating") is not None else "",
            "date_read": item.find("user_read_at").text if item.find("user_read_at") is not None else "",
            "date_added": item.find("user_date_created").text if item.find("user_date_created") is not None else "",
            "review": "",
        }

        # Extract review from description
        desc = item.find("description")
        if desc is not None and desc.text:
            soup = BeautifulSoup(desc.text, "html.parser")
            book["review"] = soup.get_text().strip()

        # Get book ID from link
        if book["link"]:
            parts = book["link"].split("/")
            if "show" in parts:
                idx = parts.index("show")
                if idx + 1 < len(parts):
                    book["book_id"] = parts[idx + 1].split("-")[0]

        return book

    def get_shelf(self, shelf: str = "read", use_cache: bool = False, max_pages: int = 10) -> List[Dict]:
        """Get all books from a shelf."""
        cache_path = self._get_cache_path(shelf)

        if use_cache and cache_path.exists():
            with open(cache_path) as f:
                return json.load(f)

        books = []
        page = 1

        while page <= max_pages:
            try:
                rss_xml = self._fetch_rss(shelf, per_page=100, page=page)
                root = ET.fromstring(rss_xml)

                items = root.findall(".//item")
                if not items:
                    break

                for item in items:
                    book = self._parse_rss_item(item)
                    books.append(book)

                page += 1
            except Exception as e:
                print(f"Error fetching page {page}: {e}", file=sys.stderr)
                break

        # Cache the results
        with open(cache_path, "w") as f:
            json.dump(books, f, indent=2)

        return books

    def get_currently_reading(self) -> List[Dict]:
        """Get books currently being read."""
        return self.get_shelf("currently-reading")

    def search_books(self, query: str) -> List[Dict]:
        """Search for books by title or author."""
        url = f"{self.base_url}/search?q={quote_plus(query)}"
        response = self.session.get(url, timeout=10)
        response.raise_for_status()

        soup = BeautifulSoup(response.text, "html.parser")
        books = []

        for result in soup.select('tr[itemtype="http://schema.org/Book"]')[:10]:
            title_elem = result.select_one(".bookTitle")
            author_elem = result.select_one(".authorName")

            if title_elem and author_elem:
                book = {
                    "title": title_elem.get_text(strip=True),
                    "author": author_elem.get_text(strip=True),
                    "link": self.base_url + title_elem.get("href", ""),
                }
                books.append(book)

        return books

    def get_stats(self) -> Dict:
        """Get reading statistics."""
        shelves = {
            "read": self.get_shelf("read"),
            "currently-reading": self.get_shelf("currently-reading"),
            "to-read": self.get_shelf("to-read"),
        }

        stats = {
            "total_read": len(shelves["read"]),
            "currently_reading": len(shelves["currently-reading"]),
            "to_read": len(shelves["to-read"]),
            "books_by_year": {},
        }

        # Count books by year
        for book in shelves["read"]:
            if book["date_read"]:
                try:
                    year = datetime.fromisoformat(book["date_read"].replace("Z", "+00:00")).year
                    stats["books_by_year"][year] = stats["books_by_year"].get(year, 0) + 1
                except Exception:
                    pass

        return stats


def cmd_list(args):
    """List books from a shelf."""
    client = GoodreadsClient(args.user_id)
    books = client.get_shelf(args.shelf, use_cache=args.cache)

    if args.json:
        print(json.dumps(books, indent=2))
    else:
        for i, book in enumerate(books, 1):
            rating = "★" * int(book["rating"]) if book["rating"] else "unrated"
            print(f"{i}. {book['title']} by {book['author']} - {rating}")
            if args.verbose and book["review"]:
                print(f"   Review: {book['review'][:100]}...")


def cmd_currently_reading(args):
    """Show currently reading books."""
    client = GoodreadsClient(args.user_id)
    books = client.get_currently_reading()

    if args.json:
        print(json.dumps(books, indent=2))
    else:
        if not books:
            print("No books currently being read.")
        else:
            for book in books:
                print(f"📖 {book['title']} by {book['author']}")
                if book["date_added"]:
                    print(f"   Started: {book['date_added']}")


def cmd_stats(args):
    """Show reading statistics."""
    client = GoodreadsClient(args.user_id)
    stats = client.get_stats()

    if args.json:
        print(json.dumps(stats, indent=2))
    else:
        print(f"📚 Total books read: {stats['total_read']}")
        print(f"📖 Currently reading: {stats['currently_reading']}")
        print(f"📋 To read: {stats['to_read']}")
        print("\nBooks read by year:")
        for year in sorted(stats["books_by_year"].keys(), reverse=True):
            count = stats["books_by_year"][year]
            print(f"  {year}: {count}")


def cmd_search(args):
    """Search for books."""
    client = GoodreadsClient(args.user_id)
    books = client.search_books(args.query)

    if args.json:
        print(json.dumps(books, indent=2))
    else:
        for i, book in enumerate(books, 1):
            print(f"{i}. {book['title']} by {book['author']}")
            print(f"   {book['link']}")


def main():
    parser = argparse.ArgumentParser(description="Goodreads CLI")
    parser.add_argument("--user-id", default="chriskjaer", help="Goodreads user ID")
    parser.add_argument("--json", action="store_true", help="Output as JSON")

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # List command
    list_parser = subparsers.add_parser("list", help="List books from a shelf")
    list_parser.add_argument(
        "shelf",
        nargs="?",
        default="read",
        help="Shelf name (read, currently-reading, to-read)",
    )
    list_parser.add_argument("--cache", action="store_true", help="Use cached data")
    list_parser.add_argument("-v", "--verbose", action="store_true", help="Show reviews")
    list_parser.set_defaults(func=cmd_list)

    # Currently reading command
    cr_parser = subparsers.add_parser("currently-reading", help="Show currently reading books")
    cr_parser.set_defaults(func=cmd_currently_reading)

    # Stats command
    stats_parser = subparsers.add_parser("stats", help="Show reading statistics")
    stats_parser.set_defaults(func=cmd_stats)

    # Search command
    search_parser = subparsers.add_parser("search", help="Search for books")
    search_parser.add_argument("query", help="Search query")
    search_parser.set_defaults(func=cmd_search)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    try:
        args.func(args)
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
