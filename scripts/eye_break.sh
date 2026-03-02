#!/bin/bash
# Count Tongula's Eye Break Reminder
# Launches the Dracula-themed native UI.
# Ensures only one instance runs at a time.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$SCRIPT_DIR/eye_break_ui"

# Kill any existing instance
pkill -f "eye_break_ui" 2>/dev/null
sleep 0.2

if [[ -x "$BINARY" ]]; then
    "$BINARY"
else
    swift "$SCRIPT_DIR/eye_break_ui.swift"
fi
