#!/usr/bin/env bash
set -euo pipefail

TEST_PROFILE="${1:-quick}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_GODOT_BIN="/home/mintriago/Godot_v4.7.1-stable_linux.x86_64"
GODOT_EXECUTABLE="${GODOT_BIN:-$DEFAULT_GODOT_BIN}"

if [[ "$TEST_PROFILE" != "quick" && "$TEST_PROFILE" != "exhaustive" ]]; then
	echo "Usage: $0 [quick|exhaustive]" >&2
	exit 2
fi

if [[ ! -x "$GODOT_EXECUTABLE" ]]; then
	GODOT_EXECUTABLE="$(command -v godot || true)"
fi
if [[ -z "$GODOT_EXECUTABLE" || ! -x "$GODOT_EXECUTABLE" ]]; then
	echo "Godot 4.7.1 was not found. Set GODOT_BIN to its executable." >&2
	exit 2
fi

TEST_DATA_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/michikart-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_DATA_ROOT"' EXIT

CORE_SUITES=(
	tests/cup_progression.gd
	tests/cup_editor.gd
	tests/frontend_layout.gd
	tests/ui_redesign.gd
	tests/driving_physics.gd
	tests/race_telemetry.gd
	tests/time_trial.gd
	tests/time_trial_world.gd
	tests/track_authoring.gd
	tests/track_editor.gd
	tests/track_barriers.gd
	tests/track_minimap.gd
	tests/racing_line.gd
	tests/ai_barrier_avoidance.gd
	tests/race_intro.gd
	tests/item_physics.gd
	tests/item_catalog.gd
	tests/item_behaviors.gd
	tests/audio_teardown.gd
	tests/presentation_polish.gd
	tests/headless_smoke.gd
)

run_suite() {
	local suite="$1"
	shift
	local suite_name="${suite##*/}"
	local suite_data="$TEST_DATA_ROOT/${suite_name%.gd}-$RANDOM"
	local timeout_seconds="${TEST_TIMEOUT_SECONDS:-600}"
	if [[ "$TEST_PROFILE" == "exhaustive" ]]; then
		timeout_seconds="${TEST_TIMEOUT_SECONDS:-7200}"
	fi
	mkdir -p "$suite_data"
	echo "==> $suite $*"
	(
		export XDG_DATA_HOME="$suite_data"
		cd "$PROJECT_ROOT"
		timeout "$timeout_seconds" "$GODOT_EXECUTABLE" \
			--headless --path . --script "$suite" -- "$@"
	)
}

for suite in "${CORE_SUITES[@]}"; do
	run_suite "$suite"
done

run_suite tests/shortcut_drive.gd "--profile=$TEST_PROFILE"
run_suite tests/race_stability.gd "--profile=$TEST_PROFILE"

echo "All $TEST_PROFILE test suites passed."
