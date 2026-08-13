#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_GODOT_BIN="/home/mintriago/Godot_v4.7.1-stable_linux.x86_64"
GODOT_EXECUTABLE="${GODOT_BIN:-$DEFAULT_GODOT_BIN}"
LAN_TEST_PORT="${LAN_TEST_PORT:-17777}"
LAN_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/michikart-lan.XXXXXX")"
PIDS=()

cleanup() {
	for pid in "${PIDS[@]}"; do
		kill "$pid" 2>/dev/null || true
	done
	rm -rf -- "$LAN_TEST_ROOT"
}
trap cleanup EXIT

run_peer() {
	local label="$1"
	shift
	XDG_DATA_HOME="$LAN_TEST_ROOT/$label" "$GODOT_EXECUTABLE" \
		--headless --path "$PROJECT_ROOT" \
		--script tests/lan_loopback_peer.gd -- "$@" \
		>"$LAN_TEST_ROOT/$label.log" 2>&1 &
	PIDS+=("$!")
}

mkdir -p "$LAN_TEST_ROOT/host" "$LAN_TEST_ROOT/client1" "$LAN_TEST_ROOT/client2" "$LAN_TEST_ROOT/client3"
run_peer host --role=host "--port=$LAN_TEST_PORT"
sleep 0.4
for index in 1 2 3; do
	run_peer "client$index" --role=client "--client-index=$index" "--port=$LAN_TEST_PORT"
done

STATUS=0
for pid in "${PIDS[@]}"; do
	wait "$pid" || STATUS=1
done

for log in "$LAN_TEST_ROOT"/*.log; do
	echo "==> ${log##*/}"
	sed -n '1,160p' "$log"
done

exit "$STATUS"
