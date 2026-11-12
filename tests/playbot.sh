#!/usr/bin/env bash
# Runs the playtest bot (tests/playbot.gd) once per crew and story branch, and reports every
# mission that can't be finished. Exit code 0 only if no run got stuck. Like tests/run.sh, it reads
# the verdict from the summary line because Godot 4.5.1 aborts at shutdown in script mode
# (see docs/TECH_NOTES.md).
#   tests/playbot.sh            all four runs (about 10 minutes)
#   tests/playbot.sh --quick    just the first
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
RUNS=("vlakte_vipers 0" "tortel_crew 1" "duin_boys 0" "klipspringers 1")
[[ "${1:-}" == "--quick" ]] && RUNS=("${RUNS[0]}")
FAILED=0
for run in "${RUNS[@]}"; do
  set -- $run
  LOG="$(mktemp)"
  timeout "${BOT_TIMEOUT:-900}" "$GODOT" --headless --path . --fixed-fps 60 -s tests/playbot.gd -- --crew="$1" --choice="$2" 2>&1 | tee "$LOG" | grep -E "^==|STUCK|^PLAYBOT"
  SUMMARY="$(grep -E '^PLAYBOT: ' "$LOG" | tail -1)"
  rm -f "$LOG"
  case "$SUMMARY" in
    *" 0 stuck") ;;
    "") echo "RUN $1/$2 DID NOT FINISH"; FAILED=1 ;;
    *) FAILED=1 ;;
  esac
done
[[ $FAILED -eq 0 ]] && { echo "BOT OK: no mission is stuck in any run"; exit 0; }
echo "BOT FOUND PROBLEMS"; exit 1
