#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="/tmp/eye_break_tests"

echo "Compiling test binary..."
swiftc -O -o "$OUT" \
    "$SCRIPT_DIR/Sources/Quotes.swift" \
    "$SCRIPT_DIR/Sources/Preferences.swift" \
    "$SCRIPT_DIR/Sources/Statistics.swift" \
    "$SCRIPT_DIR/Sources/SoundManager.swift" \
    "$SCRIPT_DIR/Sources/Theme.swift" \
    "$SCRIPT_DIR/Tests/test_core.swift" \
    -framework Cocoa \
    -framework IOKit

echo "Running tests..."
echo ""
"$OUT"
STATUS=$?

rm -f "$OUT"
exit $STATUS
