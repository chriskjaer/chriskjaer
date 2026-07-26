#!/usr/bin/env python3
"""HTML-escape selected fields in pipe-delimited rows."""

from __future__ import annotations

import argparse
import html
import sys


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fields", default="5,6")
    args = parser.parse_args()
    fields = {int(value) - 1 for value in args.fields.split(",")}

    for raw_line in sys.stdin:
        parts = raw_line.rstrip("\n").split("|")
        for index in fields:
            if 0 <= index < len(parts):
                parts[index] = html.escape(parts[index], quote=True)
        print("|".join(parts))


if __name__ == "__main__":
    main()
