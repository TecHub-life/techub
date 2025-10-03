#!/usr/bin/env bash
set -euo pipefail

# Determine repository root (this script's directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

ENV_FILE_DEFAULT="$ROOT_DIR/.env"
ENV_FILE="${1:-"$ENV_FILE_DEFAULT"}"
OUT_FILE="$ROOT_DIR/.env.example"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: Input .env file not found at: $ENV_FILE" >&2
  echo "Usage: $(basename "$0") [path/to/.env]" >&2
  exit 1
fi

# Generate a sanitized .env.example by preserving keys and removing values.
# - Keeps blank lines and comments
# - Supports 'export KEY=value' and 'KEY=value'
# - Trims whitespace around '='
# - Does not evaluate variable expansions
tmp_file="$(mktemp)"
awk '
BEGIN { OFS=""; }
{
  line=$0
  sub(/\r$/, "", line)
  if (line ~ /^[[:space:]]*$/) { print ""; next }
  if (line ~ /^[[:space:]]*#/) { print line; next }
  if (match(line, /^[[:space:]]*export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=/, m)) {
    print "export ", m[1], "="
    next
  }
  if (match(line, /^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=/, m)) {
    print m[1], "="
    next
  }
  print line
}
' "$ENV_FILE" > "$tmp_file"

mv "$tmp_file" "$OUT_FILE"

echo "Wrote cleaned example to $OUT_FILE"


