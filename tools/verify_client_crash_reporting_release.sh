#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 /path/to/PokeAether.x86_64" >&2
	exit 2
fi

client_executable="$1"
if [[ ! -x "$client_executable" ]]; then
	echo "Client executable is missing or not executable: $client_executable" >&2
	exit 2
fi

test_root="$(mktemp -d "${TMPDIR:-/tmp}/pokeaether-crash-release-check.XXXXXX")"
client_pid=""

cleanup() {
	if [[ -n "$client_pid" ]] && kill -0 "$client_pid" 2>/dev/null; then
		kill -KILL "$client_pid" 2>/dev/null || true
		wait "$client_pid" 2>/dev/null || true
	fi
	rm -rf -- "$test_root"
}
trap cleanup EXIT

data_home="$test_root/data"
config_home="$test_root/config"
cache_home="$test_root/cache"
mkdir -p "$data_home" "$config_home" "$cache_home"

run_client() {
	env \
		XDG_DATA_HOME="$data_home" \
		XDG_CONFIG_HOME="$config_home" \
		XDG_CACHE_HOME="$cache_home" \
		"$client_executable" "$@"
}

run_client --headless --quit-after 8 >"$test_root/clean-run.log" 2>&1

state_file="$(find "$data_home" -path '*/diagnostics/client_session_state.json' -print -quit)"
if [[ -z "$state_file" ]] || ! grep -q '"cleanShutdown":true' "$state_file"; then
	echo "Clean client shutdown did not leave a clean session marker." >&2
	exit 1
fi

diagnostics_dir="$(dirname "$state_file")"
report_file="$diagnostics_dir/latest_crash_report.txt"
if [[ -e "$report_file" ]]; then
	echo "A clean client shutdown incorrectly produced a crash report." >&2
	exit 1
fi

run_client --headless >"$test_root/interrupted-run.log" 2>&1 &
client_pid=$!

for _attempt in $(seq 1 100); do
	if [[ -f "$state_file" ]] && grep -q '"cleanShutdown":false' "$state_file"; then
		break
	fi
	sleep 0.1
done

if ! kill -0 "$client_pid" 2>/dev/null; then
	echo "Client stopped before the interrupted-session test could run." >&2
	exit 1
fi
if ! grep -q '"cleanShutdown":false' "$state_file"; then
	echo "Running client did not leave an active session marker." >&2
	exit 1
fi

kill -KILL "$client_pid"
wait "$client_pid" 2>/dev/null || true
client_pid=""

if ! grep -q '"cleanShutdown":false' "$state_file"; then
	echo "Interrupted client session was incorrectly marked clean." >&2
	exit 1
fi

run_client --headless --quit-after 12 >"$test_root/recovery-run.log" 2>&1

if [[ ! -s "$report_file" ]]; then
	echo "Client restart did not produce a crash report." >&2
	exit 1
fi
if ! grep -q '^POKEAETHER CLIENT CRASH REPORT$' "$report_file"; then
	echo "Generated crash report is missing its header." >&2
	exit 1
fi
if ! grep -q '^END OF REPORT$' "$report_file"; then
	echo "Generated crash report is incomplete." >&2
	exit 1
fi
if grep -Eq '/home/|\\Users\\' "$report_file"; then
	echo "Generated crash report contains a private local path." >&2
	exit 1
fi
if ! grep -q '"cleanShutdown":true' "$state_file"; then
	echo "Recovery run did not finish with a clean session marker." >&2
	exit 1
fi

echo "PASS verify_client_crash_reporting_release"
