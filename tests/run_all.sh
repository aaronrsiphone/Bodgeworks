#!/usr/bin/env bash
# Runs every automated test and exits non-zero if any of them fail.
#
#   GODOT=/path/to/godot tests/run_all.sh
#
# Headless physics runs in real time, so the drive scenarios run in parallel.
# The garage test needs a display: it runs under xvfb-run when that's installed
# (or directly if $DISPLAY is set), and is skipped otherwise.
# Logs (one per test) and the garage screenshots go to $LOG_DIR, or
# $TEST_OUTPUT_DIR (set by CI), or a new temp folder.

set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "Godot not found: set GODOT=/path/to/godot" >&2
	exit 2
fi
LOG_DIR="${LOG_DIR:-${TEST_OUTPUT_DIR:-$(mktemp -d -t bodgeworks-tests.XXXXXX)}}"
mkdir -p "$LOG_DIR"
LOG_DIR="$(cd "$LOG_DIR" && pwd)" # absolute, so Godot can save screenshots there
TIMEOUT="${TEST_TIMEOUT:-180}" # seconds per test, so a hang counts as a failure

DRIVE_SCENARIOS=(
	"buggy straight"
	"buggy turn"
	"buggy pond"
	"buggy pyramid"
	"amphibian pond"
	"amphibian ramp"
	"amphibian swim"
	"forklift push"
	"amphibian power"
	"buggy airprop"
)

names=()
pids=()

# run <name> <godot args...>: starts one test in the background.
run() {
	local name="$1"
	shift
	timeout "$TIMEOUT" "$@" >"$LOG_DIR/$name.log" 2>&1 &
	names+=("$name")
	pids+=($!)
}

start=$(date +%s)
echo "Logs: $LOG_DIR"
echo "Importing assets..."
if ! "$GODOT" --headless --path . --import >"$LOG_DIR/import.log" 2>&1; then
	echo "FAIL  import (see $LOG_DIR/import.log)"
	exit 1
fi

for s in "${DRIVE_SCENARIOS[@]}"; do
	# shellcheck disable=SC2086 # split "vehicle scenario" into two args
	run "drive_${s// /_}" "$GODOT" --headless --path . --script res://tests/drive_test.gd -- $s
done
run mission_forklift "$GODOT" --headless --path . --script res://tests/mission_test.gd -- res://tests/blueprints/forklift.json

garage_cmd=("$GODOT" --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/garage_test.gd -- "$LOG_DIR")
skipped=()
if command -v xvfb-run >/dev/null 2>&1; then
	run garage xvfb-run -a -s "-screen 0 1280x720x24" "${garage_cmd[@]}"
elif [ -n "${DISPLAY:-}" ]; then
	run garage "${garage_cmd[@]}"
else
	skipped+=(garage)
fi

failed=0
for i in "${!pids[@]}"; do
	name="${names[$i]}"
	log="$LOG_DIR/$name.log"
	wait "${pids[$i]}"
	code=$?
	why=""
	if [ "$code" -eq 124 ]; then
		why="timed out after ${TIMEOUT}s"
	elif [ "$code" -ne 0 ]; then
		why="exit code $code"
	elif grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
		# A runtime script error stops that function but not Godot, so catch it here.
		why="script error"
	elif ! grep -q "^RESULT .*PASS" "$log"; then
		why="no PASS result"
	fi
	if [ -z "$why" ]; then
		printf "PASS  %-24s %s\n" "$name" "$(grep -m1 '^RESULT' "$log" | cut -c1-90)"
	else
		failed=$((failed + 1))
		printf "FAIL  %-24s %s (log: %s)\n" "$name" "$why" "$log"
		grep -E "  FAIL  |^RESULT|SCRIPT ERROR|ERROR:" "$log" | head -n 10 | sed 's/^/        /'
	fi
done
for name in "${skipped[@]}"; do
	printf "SKIP  %-24s no xvfb-run and no \$DISPLAY\n" "$name"
done

total=${#pids[@]}
echo
echo "$((total - failed))/$total passed, ${#skipped[@]} skipped, in $(($(date +%s) - start))s"
[ "$failed" -eq 0 ]
