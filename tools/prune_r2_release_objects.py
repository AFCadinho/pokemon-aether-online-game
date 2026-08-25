#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import hmac
import http.client
import json
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote, unquote, urlparse
from urllib.request import Request, urlopen

from upload_launcher_release import R2Config, _canonical_uri, _get_signature_key, _load_config


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST_DIR = PROJECT_ROOT / "builds" / "launcher"
DEFAULT_PUBLIC_BASE_URL = "https://updates.pokeaether.com"
REMOTE_MANIFEST_NAMES = (
    "manifest.json",
    "manifest-windows.json",
    "manifest-linux.json",
    "manifest-macos.json",
)
REQUIRED_LOCAL_MANIFEST_NAMES = {
    "manifest.json",
    "manifest-windows.json",
    "manifest-linux.json",
}
ASSET_FAMILY_PREFIXES = (
    ("pokemon-gen5-shiny-front-", "pokemon-gen5-shiny-front"),
    ("pokemon-gen5-shiny-back-", "pokemon-gen5-shiny-back"),
    ("pokemon-gen5-front-", "pokemon-gen5-front"),
    ("pokemon-gen5-back-", "pokemon-gen5-back"),
    ("pokemon-shiny-front-scale1-128-", "pokemon-shiny-front"),
    ("pokemon-shiny-back-scale1-128-", "pokemon-shiny-back"),
    ("pokemon-front-scale1-128-", "pokemon-front"),
    ("pokemon-back-scale1-128-", "pokemon-back"),
    ("pokemon-home-shiny-", "pokemon-home-shiny"),
    ("pokemon-home-", "pokemon-home"),
    ("music-", "music"),
)
GAME_OBJECT_PATTERN = re.compile(r"^game-.+-(windows|linux|macos)\.zip$")


@dataclass(frozen=True)
class R2Object:
    key: str
    size: int
    last_modified: dt.datetime


@dataclass(frozen=True)
class PrunePlan:
    delete: tuple[R2Object, ...]
    retained_for_rollback: tuple[R2Object, ...]
    retained_recent: tuple[R2Object, ...]
    ignored: tuple[R2Object, ...]


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Delete obsolete immutable game and asset-pack objects from Cloudflare R2 "
            "after a successful manifest publication. Dry-run is the default."
        )
    )
    parser.add_argument(
        "manifest_dir",
        nargs="?",
        default=str(DEFAULT_MANIFEST_DIR),
        help="Directory containing the newly generated launcher manifests.",
    )
    parser.add_argument(
        "--public-base-url",
        default=DEFAULT_PUBLIC_BASE_URL,
        help="Public update origin used by manifest URLs.",
    )
    parser.add_argument(
        "--retain-previous",
        type=int,
        default=1,
        help="Previous immutable object versions to retain per asset pack or game platform.",
    )
    parser.add_argument(
        "--minimum-age-hours",
        type=int,
        default=24,
        help="Never delete an object younger than this many hours.",
    )
    parser.add_argument(
        "--max-delete",
        type=int,
        default=200,
        help="Refuse the cleanup when more than this many objects would be deleted.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually delete the planned objects. Without this flag the command is a dry-run.",
    )
    args = parser.parse_args()

    if args.retain_previous < 1:
        raise SystemExit("--retain-previous must be at least 1 so rollback remains possible")
    if args.minimum_age_hours < 1:
        raise SystemExit("--minimum-age-hours must be at least 1")
    if args.max_delete < 1:
        raise SystemExit("--max-delete must be at least 1")

    manifest_dir = Path(args.manifest_dir).resolve()
    manifests = _load_local_manifests(manifest_dir)
    manifests.extend(_load_remote_manifests(args.public_base_url))
    protected_keys = _protected_keys_from_manifests(manifests, args.public_base_url)
    _assert_required_references(protected_keys)

    config = _load_config()
    objects = _list_release_objects(config)
    _assert_protected_objects_exist(objects, protected_keys)
    plan = _build_prune_plan(
        objects,
        protected_keys,
        retain_previous=args.retain_previous,
        minimum_age=dt.timedelta(hours=args.minimum_age_hours),
        now=dt.datetime.now(dt.UTC),
    )

    print(
        "R2 cleanup plan: "
        f"delete={len(plan.delete)} "
        f"rollback={len(plan.retained_for_rollback)} "
        f"recent={len(plan.retained_recent)} "
        f"ignored={len(plan.ignored)}"
    )
    for item in plan.delete:
        print(f"DELETE {item.key} ({item.size} bytes)")

    if len(plan.delete) > args.max_delete:
        raise SystemExit(
            f"Refusing to delete {len(plan.delete)} objects; --max-delete is {args.max_delete}"
        )
    if not args.apply:
        print("Dry-run only; pass --apply to delete the planned objects.")
        return

    for item in plan.delete:
        _delete_object(config, item.key)
        print(f"Deleted s3://{config.bucket}/{item.key}")
    print(f"R2 cleanup complete: deleted {len(plan.delete)} obsolete objects.")


def _load_local_manifests(manifest_dir: Path) -> list[dict]:
    if not manifest_dir.is_dir():
        raise SystemExit(f"Manifest directory does not exist: {manifest_dir}")
    manifest_paths = sorted(manifest_dir.glob("manifest*.json"))
    names = {path.name for path in manifest_paths}
    missing = sorted(REQUIRED_LOCAL_MANIFEST_NAMES - names)
    if missing:
        raise SystemExit(f"Missing required local manifests: {', '.join(missing)}")
    return [_read_manifest(path.read_text(encoding="utf-8"), str(path)) for path in manifest_paths]


def _load_remote_manifests(public_base_url: str) -> list[dict]:
    manifests: list[dict] = []
    base_url = public_base_url.rstrip("/")
    for name in REMOTE_MANIFEST_NAMES:
        url = f"{base_url}/{name}"
        request = Request(url, headers={"Cache-Control": "no-cache", "User-Agent": "PokeAether-R2-Pruner/1"})
        try:
            with urlopen(request, timeout=30) as response:
                manifests.append(_read_manifest(response.read().decode("utf-8"), url))
        except HTTPError as error:
            if name == "manifest-macos.json" and error.code == 404:
                print(f"Optional remote manifest is not published: {url}")
                continue
            raise SystemExit(f"Could not read remote manifest {url}: HTTP {error.code}") from error
        except (URLError, TimeoutError) as error:
            raise SystemExit(f"Could not read remote manifest {url}: {error}") from error
    return manifests


def _read_manifest(text: str, source: str) -> dict:
    try:
        value = json.loads(text)
    except json.JSONDecodeError as error:
        raise SystemExit(f"Invalid JSON manifest {source}: {error}") from error
    if not isinstance(value, dict):
        raise SystemExit(f"Manifest must contain a JSON object: {source}")
    return value


def _protected_keys_from_manifests(manifests: list[dict], public_base_url: str) -> set[str]:
    protected: set[str] = set()
    for manifest in manifests:
        game = manifest.get("game")
        if isinstance(game, dict):
            key = _key_from_public_url(game.get("url"), public_base_url)
            if key is not None:
                protected.add(key)
        asset_packs = manifest.get("assetPacks")
        if not isinstance(asset_packs, list):
            continue
        for pack in asset_packs:
            if not isinstance(pack, dict):
                continue
            key = _key_from_public_url(pack.get("url"), public_base_url)
            if key is not None:
                protected.add(key)
    return protected


def _key_from_public_url(value: object, public_base_url: str) -> str | None:
    if not isinstance(value, str) or not value:
        return None
    base = urlparse(public_base_url.rstrip("/"))
    parsed = urlparse(value)
    if parsed.scheme != base.scheme or parsed.netloc != base.netloc:
        return None
    base_path = base.path.rstrip("/")
    if base_path and not parsed.path.startswith(f"{base_path}/"):
        return None
    relative_path = parsed.path[len(base_path):].lstrip("/")
    key = unquote(relative_path)
    if not key or any(part in {"", ".", ".."} for part in key.split("/")):
        return None
    return key


def _assert_required_references(protected_keys: set[str]) -> None:
    protected_families = {
        family
        for key in protected_keys
        if (family := _object_family(key)) is not None
    }
    required = {f"assets:{family}" for _, family in ASSET_FAMILY_PREFIXES}
    required.update({"game:windows", "game:linux"})
    missing = sorted(required - protected_families)
    if missing:
        raise SystemExit(f"Manifest safety check is missing protected release families: {', '.join(missing)}")


def _assert_protected_objects_exist(objects: list[R2Object], protected_keys: set[str]) -> None:
    existing = {item.key for item in objects}
    protected_release_keys = {key for key in protected_keys if _object_family(key) is not None}
    missing = sorted(protected_release_keys - existing)
    if missing:
        raise SystemExit(
            "Protected manifest objects are missing from R2; refusing cleanup: " + ", ".join(missing)
        )


def _object_family(key: str) -> str | None:
    if key.startswith("assets/"):
        file_name = key.removeprefix("assets/")
        if "/" in file_name or not file_name.endswith(".zip"):
            return None
        for prefix, family in ASSET_FAMILY_PREFIXES:
            if file_name.startswith(prefix):
                return f"assets:{family}"
        return None
    if key.startswith("game/"):
        file_name = key.removeprefix("game/")
        if "/" in file_name:
            return None
        match = GAME_OBJECT_PATTERN.fullmatch(file_name)
        if match is not None:
            return f"game:{match.group(1)}"
    return None


def _build_prune_plan(
    objects: list[R2Object],
    protected_keys: set[str],
    *,
    retain_previous: int,
    minimum_age: dt.timedelta,
    now: dt.datetime,
) -> PrunePlan:
    families: dict[str, list[R2Object]] = {}
    ignored: list[R2Object] = []
    for item in objects:
        family = _object_family(item.key)
        if family is None:
            ignored.append(item)
            continue
        families.setdefault(family, []).append(item)

    delete: list[R2Object] = []
    rollback: list[R2Object] = []
    recent: list[R2Object] = []
    for family_objects in families.values():
        unprotected = sorted(
            (item for item in family_objects if item.key not in protected_keys),
            key=lambda item: (item.last_modified, item.key),
            reverse=True,
        )
        rollback.extend(unprotected[:retain_previous])
        for item in unprotected[retain_previous:]:
            if now - item.last_modified < minimum_age:
                recent.append(item)
            else:
                delete.append(item)

    sort_key = lambda item: item.key
    return PrunePlan(
        delete=tuple(sorted(delete, key=sort_key)),
        retained_for_rollback=tuple(sorted(rollback, key=sort_key)),
        retained_recent=tuple(sorted(recent, key=sort_key)),
        ignored=tuple(sorted(ignored, key=sort_key)),
    )


def _list_release_objects(config: R2Config) -> list[R2Object]:
    objects: list[R2Object] = []
    for prefix in ("assets/", "game/"):
        continuation_token = ""
        while True:
            query = [("list-type", "2"), ("prefix", prefix)]
            if continuation_token:
                query.append(("continuation-token", continuation_token))
            status, reason, body = _signed_request(config, "GET", "", query=query)
            if status < 200 or status >= 300:
                raise SystemExit(f"R2 object listing failed for {prefix}: {status} {reason}")
            try:
                root = ET.fromstring(body)
            except ET.ParseError as error:
                raise SystemExit(f"R2 returned invalid object listing XML for {prefix}: {error}") from error
            for node in root.findall("{*}Contents"):
                key = node.findtext("{*}Key", default="")
                modified_text = node.findtext("{*}LastModified", default="")
                size_text = node.findtext("{*}Size", default="0")
                if not key or not modified_text:
                    continue
                objects.append(
                    R2Object(
                        key=key,
                        size=int(size_text),
                        last_modified=dt.datetime.fromisoformat(modified_text.replace("Z", "+00:00")),
                    )
                )
            if root.findtext("{*}IsTruncated", default="false").lower() != "true":
                break
            continuation_token = root.findtext("{*}NextContinuationToken", default="")
            if not continuation_token:
                raise SystemExit(f"R2 listing for {prefix} was truncated without a continuation token")
    return objects


def _delete_object(config: R2Config, key: str) -> None:
    if _object_family(key) is None:
        raise SystemExit(f"Refusing to delete an object outside the release allowlist: {key}")
    status, reason, _ = _signed_request(config, "DELETE", key)
    if status < 200 or status >= 300:
        raise SystemExit(f"R2 delete failed for {key}: {status} {reason}")


def _signed_request(
    config: R2Config,
    method: str,
    key: str,
    *,
    query: list[tuple[str, str]] | None = None,
) -> tuple[int, str, bytes]:
    parsed_endpoint = urlparse(config.endpoint)
    if parsed_endpoint.scheme != "https":
        raise SystemExit("R2_ENDPOINT must use https")

    host = parsed_endpoint.netloc
    canonical_uri = _canonical_uri(config.bucket, key)
    canonical_query = "&".join(
        f"{quote(name, safe='-_.~')}={quote(value, safe='-_.~')}"
        for name, value in sorted(query or [])
    )
    payload_hash = hashlib.sha256(b"").hexdigest()
    now = dt.datetime.now(dt.UTC)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    credential_scope = f"{date_stamp}/auto/s3/aws4_request"
    headers = {
        "Host": host,
        "X-Amz-Content-Sha256": payload_hash,
        "X-Amz-Date": amz_date,
    }
    canonical_headers = "".join(f"{name.lower()}:{headers[name]}\n" for name in sorted(headers))
    signed_headers = ";".join(name.lower() for name in sorted(headers))
    canonical_request = "\n".join(
        [method, canonical_uri, canonical_query, canonical_headers, signed_headers, payload_hash]
    )
    string_to_sign = "\n".join(
        [
            "AWS4-HMAC-SHA256",
            amz_date,
            credential_scope,
            hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
        ]
    )
    signing_key = _get_signature_key(config.secret_access_key, date_stamp, "auto", "s3")
    signature = hmac.new(signing_key, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
    headers["Authorization"] = (
        "AWS4-HMAC-SHA256 "
        f"Credential={config.access_key_id}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )

    request_target = canonical_uri
    if canonical_query:
        request_target = f"{request_target}?{canonical_query}"
    connection = http.client.HTTPSConnection(host, timeout=60)
    try:
        connection.request(method, request_target, headers=headers)
        response = connection.getresponse()
        return response.status, response.reason, response.read()
    finally:
        connection.close()


if __name__ == "__main__":
    main()
