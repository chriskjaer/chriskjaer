#!/usr/bin/awk -f

# HTML-escape selected fields in pipe-delimited rows.
# Usage: awk -v FIELDS=5,6 -f scripts/html_escape_rows.awk

function html_escape(value) {
  gsub(/&/, "\\&amp;", value)
  gsub(/</, "\\&lt;", value)
  gsub(/>/, "\\&gt;", value)
  gsub(/\"/, "\\&quot;", value)
  gsub(/'/, "\\&#x27;", value)
  return value
}

BEGIN {
  FS = "\\|"
  OFS = "|"
  if (FIELDS == "") FIELDS = "5,6"
  count = split(FIELDS, selected, ",")
  for (i = 1; i <= count; i++) escape_field[selected[i] + 0] = 1
}

{
  for (i = 1; i <= NF; i++) {
    if (escape_field[i]) $i = html_escape($i)
  }
  print
}
