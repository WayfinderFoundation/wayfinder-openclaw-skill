#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$SCRIPT_DIR/wayfinder"
OUTPUT="$SCRIPT_DIR/wayfinder.skill"

rm -f "$OUTPUT"
cd "$SKILL_DIR"
zip -r "$OUTPUT" skill.json SKILL.md references/

echo "Generated $OUTPUT"
