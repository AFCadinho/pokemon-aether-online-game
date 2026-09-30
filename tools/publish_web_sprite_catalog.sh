#!/usr/bin/env bash
# Publish one immutable sprite catalog only after a conclusive missing-file response.
set -Eeuo pipefail

[[ $# == 3 ]] || { echo 'Usage: publish_web_sprite_catalog.sh STYLE SIDE VERSION' >&2; exit 1; }
style="$1"
side="$2"
version="$3"
[[ "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo 'Invalid sprite version' >&2; exit 1; }
: "${ASSET_BASE_URL:?Asset origin is required}"
: "${SOURCE_ASSET_BASE_URL:?Source asset origin is required}"
: "${R2_BUCKET:?Sprite bucket is required}"

# A failed request is not proof of absence. Retry transport/server errors, then
# accept only 200 (present) or 404 (missing); stop on every other outcome.
missing=false
for filename in animation.json sheet.png; do
  url="${ASSET_BASE_URL}/web/assets/${version}/pikachu/${filename}"
  if ! status="$(curl --silent --show-error --head --output /dev/null \
      --write-out '%{http_code}' --retry 4 --retry-all-errors --retry-delay 2 \
      --retry-max-time 90 --connect-timeout 10 --max-time 30 "$url")"; then
    echo "Could not check browser sprite catalog ${version}; upload was not started." >&2
    exit 1
  fi
  case "$status" in
    200) ;;
    404) missing=true ;;
    *) echo "Unexpected HTTP ${status} checking ${version}/${filename}; upload was not started." >&2; exit 1 ;;
  esac
done
if ! $missing; then
  echo "Browser sprite catalog already exists: ${version}"
  exit 0
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/pokeaether-web-sprites.XXXXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT
curl --fail --silent --show-error --location --retry 4 --retry-all-errors \
  --retry-delay 2 --retry-max-time 90 --connect-timeout 10 --max-time 180 \
  --output "$scratch/source.zip" "${SOURCE_ASSET_BASE_URL}/assets/${version}.zip"
python3 tools/extract_web_sprite_pack.py "$scratch/source.zip" \
  --style "$style" --side "$side" --output "$scratch/catalog"
# Extraction changes timestamps. Compare content while preserving the rule
# that an existing immutable object can never be overwritten.
rclone copy "$scratch/catalog" "R2:${R2_BUCKET}/web/assets/${version}" \
  --immutable --checksum --header-upload 'Cache-Control: public, max-age=31536000, immutable'
