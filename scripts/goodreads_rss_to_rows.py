#!/usr/bin/env python3
"""Validate one Goodreads RSS page and emit normalized pipe-delimited rows."""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import NoReturn

MAX_BYTES = 5 * 1024 * 1024
ALLOWED_NAMESPACED_TAGS = {
    "{http://www.w3.org/2005/Atom}link",
    "{http://www.w3.org/1999/xhtml}meta",
}


def fail(message: str) -> NoReturn:
    print(f"invalid Goodreads RSS: {message}", file=sys.stderr)
    raise SystemExit(1)


def text(item: ET.Element, tag: str) -> str:
    child = next((node for node in item if node.tag == tag), None)
    value = "" if child is None or child.text is None else child.text
    return " ".join(value.split()).replace("|", "¦")


def date_ymd(raw: str) -> str:
    if not raw:
        return ""
    if re.match(r"^\d{4}-\d{2}-\d{2}", raw):
        return raw[:10]
    try:
        return parsedate_to_datetime(raw).date().isoformat()
    except (TypeError, ValueError, OverflowError):
        return ""


def number(raw: str) -> int:
    try:
        return int(raw)
    except (TypeError, ValueError):
        return 0


def main() -> None:
    if len(sys.argv) != 4:
        fail("usage: goodreads_rss_to_rows.py <file> <shelf> <date-field>")

    path = Path(sys.argv[1])
    shelf = sys.argv[2]
    date_field = sys.argv[3]
    if date_field not in {"read_at", "created"}:
        fail(f"unsupported date field {date_field}")

    try:
        raw = path.read_bytes()
    except OSError as exc:
        fail(str(exc))

    if len(raw) > MAX_BYTES:
        fail(f"response exceeds {MAX_BYTES} bytes")
    upper = raw.upper()
    if b"<!DOCTYPE" in upper or b"<!ENTITY" in upper:
        fail("DTD and entity declarations are not allowed")

    try:
        root = ET.fromstring(raw)
    except ET.ParseError as exc:
        fail(str(exc))

    if root.tag != "rss":
        fail("root element is not unnamespaced rss")

    for element in root.iter():
        if element.tag.startswith("{") and element.tag not in ALLOWED_NAMESPACED_TAGS:
            fail(f"unexpected namespaced element {element.tag}")
        if any(attribute.startswith("{") for attribute in element.attrib):
            fail("namespaced attributes are not allowed")

    channels = [child for child in root if child.tag == "channel"]
    if len(channels) != 1:
        fail("expected exactly one direct rss/channel element")
    channel = channels[0]

    titles = [
        " ".join((child.text or "").split())
        for child in channel
        if child.tag == "title"
    ]
    expected_suffix = f" bookshelf: {shelf}"
    if len(titles) != 1 or not titles[0].endswith(expected_suffix):
        fail(f"channel title does not identify shelf {shelf}")

    items = [child for child in channel if child.tag == "item"]
    usable = 0
    xml_date_tag = "user_read_at" if date_field == "read_at" else "user_date_created"

    for item in items:
        title = text(item, "title")
        author = text(item, "author_name")
        date = date_ymd(text(item, xml_date_tag))
        if not title or not author or not date:
            continue

        rating = number(text(item, "user_rating"))
        pages = number(text(item, "num_pages"))
        print(f"{shelf} | {date} | {rating} | {pages} | {title} | {author}")
        usable += 1

    if not items:
        raise SystemExit(2)
    if usable == 0:
        raise SystemExit(3)


if __name__ == "__main__":
    main()
