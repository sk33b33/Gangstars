#!/usr/bin/env bash
# Runs the Godot test suite and returns 0 only if every check passed.
#   tests/run.sh [--soak-minutes=2] [--units-only]
# Why a wrapper: when the suite is run as a SceneTree script, Godot 4.5.1 (headless) aborts with a
# heap error while shutting down ("corrupted size vs. prev_size"). That happens after the summary
# is printed and only in this script mode: the game itself exits cleanly (checked with
# --quit-after, and with SceneTree.quit() from inside the game). So the verdict is read from the
# summary line, not from Godot's exit code.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
timeout "${TEST_TIMEOUT:-1500}" "$GODOT" --headless --path . --fixed-fps 60 -s tests/run_tests.gd -- "${@:---soak-minutes=2}" 2>&1 | tee "$LOG"
SUMMARY="$(grep -E '^[0-9]+ passed, [0-9]+ failed' "$LOG" | tail -1)"
rm -f "$LOG"
case "$SUMMARY" in
  *" 0 failed") echo "TESTS OK: $SUMMARY"; exit 0 ;;
  "") echo "TESTS DID NOT FINISH (no summary line)"; exit 2 ;;
  *) echo "TESTS FAILED: $SUMMARY"; exit 1 ;;
esac
