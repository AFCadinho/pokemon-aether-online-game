#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ORIGINAL_ARGS=("$@")
MODE="auto"
PORT=""
UPSTREAM="http://127.0.0.1:8000"
GODOT_BIN="${GODOT_BIN:-}"
BUILD=true
OPEN_BROWSER=true

usage() {
  cat <<'EOF'
Usage: ./run_web_local.sh [options]

Build and run the PokeAether browser client on localhost.

Options:
  --connected       Require the local backend gateway (default port 8000)
  --offline         Run without accounts or online gameplay
  --skip-build      Reuse the existing builds/web export
  --no-open         Do not open the default browser automatically
  --port PORT       Override the preview port (defaults: 8061/8060)
  --upstream URL    Local gateway URL (default: http://127.0.0.1:8000)
  --godot PATH      Godot 4.6 executable (or set GODOT_BIN)
  -h, --help        Show this help

With no mode option, the script uses the connected preview when the local
gateway is reachable and otherwise falls back to the offline preview.
Press Ctrl-C in this terminal to stop the preview server.
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --connected) MODE="connected" ;;
    --offline) MODE="offline" ;;
    --skip-build) BUILD=false ;;
    --no-open) OPEN_BROWSER=false ;;
    --port)
      [[ $# -ge 2 ]] || die "--port requires a value"
      PORT="$2"
      shift
      ;;
    --upstream)
      [[ $# -ge 2 ]] || die "--upstream requires a value"
      UPSTREAM="$2"
      shift
      ;;
    --godot)
      [[ $# -ge 2 ]] || die "--godot requires a value"
      GODOT_BIN="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -z "$PORT" || "$PORT" =~ ^[0-9]+$ && "$PORT" -ge 1 && "$PORT" -le 65535 ]] \
  || die "--port must be between 1 and 65535"

# Slot builds must use their isolated Godot state. Re-enter through the
# workspace helper automatically so this same command works in task slots and
# in the normal integration checkout.
slot="$(basename -- "$(dirname -- "$ROOT")")"
if [[ "$slot" == slot-* && "${POKEAETHER_SLOT:-}" != "$slot" ]]; then
  workspace="$(cd -- "$ROOT/../../.." && pwd -P)"
  exec "$workspace/ops/worktrees/slot-env" "$slot" -- "$ROOT/run_web_local.sh" "${ORIGINAL_ARGS[@]}"
fi

if $BUILD; then
  if [[ -z "$GODOT_BIN" ]]; then
    GODOT_BIN="$(command -v godot || command -v godot4 || true)"
  fi
  [[ -n "$GODOT_BIN" && -x "$GODOT_BIN" ]] \
    || die "Godot was not found. Install Godot 4.6 or pass --godot PATH."
  printf 'Building local browser client with %s...\n' "$GODOT_BIN"
  python3 "$ROOT/tools/build_web_preview.py" --godot "$GODOT_BIN"
elif [[ ! -s "$ROOT/builds/web/index.html" ]]; then
  die "--skip-build requested, but builds/web/index.html does not exist"
fi

validate_upstream() {
  python3 - "$UPSTREAM" <<'PY'
import sys
from urllib.parse import urlsplit

value = urlsplit(sys.argv[1])
valid = (
    value.scheme == "http"
    and value.hostname == "127.0.0.1"
    and value.port is not None
    and value.username is None
    and value.password is None
    and value.path in {"", "/"}
    and not value.query
    and not value.fragment
)
raise SystemExit(0 if valid else 1)
PY
}

gateway_reachable() {
  python3 - "$UPSTREAM" <<'PY'
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

try:
    request = Request(sys.argv[1].rstrip("/") + "/auth/status", method="GET")
    with urlopen(request, timeout=0.75):
        pass
except HTTPError:
    pass  # An HTTP response still proves that the local gateway is present.
except (URLError, TimeoutError, OSError):
    raise SystemExit(1)
PY
}

if [[ "$MODE" != "offline" ]]; then
  validate_upstream || die "--upstream must be an explicit http://127.0.0.1:PORT URL"
fi

if [[ "$MODE" == "auto" ]]; then
  if gateway_reachable; then
    MODE="connected"
  else
    MODE="offline"
    printf 'Local gateway is not running at %s; using offline preview.\n' "$UPSTREAM"
  fi
elif [[ "$MODE" == "connected" ]] && ! gateway_reachable; then
  die "local gateway is not reachable at $UPSTREAM"
fi

if [[ "$MODE" == "connected" ]]; then
  PORT="${PORT:-8061}"
  REQUIREMENTS="$ROOT/tools/web-preview-requirements.txt"
  VENV="$ROOT/builds/web-preview-venv"
  REQUIREMENTS_HASH="$(sha256sum "$REQUIREMENTS" | cut -d' ' -f1)"
  INSTALLED_HASH=""
  [[ -f "$VENV/.requirements-sha256" ]] && INSTALLED_HASH="$(<"$VENV/.requirements-sha256")"
  if [[ ! -x "$VENV/bin/python" || "$INSTALLED_HASH" != "$REQUIREMENTS_HASH" ]]; then
    printf 'Installing pinned connected-preview dependencies...\n'
    python3 -m venv "$VENV"
    "$VENV/bin/python" -m pip install --disable-pip-version-check -r "$REQUIREMENTS"
    printf '%s\n' "$REQUIREMENTS_HASH" > "$VENV/.requirements-sha256"
  fi
  SERVER=("$VENV/bin/python" "$ROOT/tools/serve_web_connected.py" --upstream "$UPSTREAM" --port "$PORT")
else
  PORT="${PORT:-8060}"
  SERVER=(python3 "$ROOT/tools/serve_web_preview.py" --port "$PORT")
fi

URL="http://127.0.0.1:$PORT"
printf 'Starting %s browser preview at %s\n' "$MODE" "$URL"
printf 'Press Ctrl-C to stop.\n'

if $OPEN_BROWSER; then
  python3 - "$URL" <<'PY' &
import sys
import time
import webbrowser
from urllib.error import URLError
from urllib.request import urlopen

url = sys.argv[1]
for _ in range(50):
    try:
        with urlopen(url, timeout=0.25):
            break
    except (URLError, TimeoutError, OSError):
        time.sleep(0.1)
else:
    raise SystemExit(0)
webbrowser.open(url)
PY
fi

exec "${SERVER[@]}"
