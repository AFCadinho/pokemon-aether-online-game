#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import hmac
import http.client
import mimetypes
import os
import time
from pathlib import Path
from urllib.parse import quote, urlparse


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RELEASE_DIR = PROJECT_ROOT / "builds" / "launcher"
MAX_UPLOAD_ATTEMPTS = 4
INITIAL_RETRY_DELAY_SECONDS = 2.0


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload launcher release files to Cloudflare R2.")
    parser.add_argument(
        "release_dir",
        nargs="?",
        default=str(DEFAULT_RELEASE_DIR),
        help="Directory containing launcher release files.",
    )
    parser.add_argument(
        "--file",
        action="append",
        dest="files",
        default=[],
        help="File name inside release_dir to upload. Can be passed multiple times.",
    )
    parser.add_argument(
        "--prefix",
        default="",
        help="Optional object key prefix in the bucket, for example releases/0.1.0.",
    )
    parser.add_argument(
        "--layout",
        choices=["flat", "updates"],
        default="flat",
        help="Object key layout. 'updates' stores game zips under game/ and asset packs under assets/.",
    )
    args = parser.parse_args()

    config = _load_config()
    release_dir = Path(args.release_dir).resolve()
    file_names = args.files if args.files else _discover_release_files(release_dir)
    if not file_names:
        raise SystemExit(f"No release files found in {release_dir}")

    for file_name in file_names:
        file_path = release_dir / file_name
        if not file_path.is_file():
            raise SystemExit(f"Missing release file: {file_path}")

        key = _build_object_key(file_name, args.prefix, args.layout)
        print(f"Uploading {file_path.name} ({file_path.stat().st_size} bytes) -> s3://{config.bucket}/{key}", flush=True)
        _upload_file(config, file_path, key)
        print(f"Uploaded {file_path.name} -> s3://{config.bucket}/{key}", flush=True)


class R2Config:
    def __init__(self, account_id: str, bucket: str, access_key_id: str, secret_access_key: str, endpoint: str) -> None:
        self.account_id = account_id
        self.bucket = bucket
        self.access_key_id = access_key_id
        self.secret_access_key = secret_access_key
        self.endpoint = endpoint.rstrip("/")


def _load_config() -> R2Config:
    account_id = _required_env("R2_ACCOUNT_ID")
    bucket = _required_env("R2_BUCKET")
    access_key_id = _required_env("R2_ACCESS_KEY_ID")
    secret_access_key = _required_env("R2_SECRET_ACCESS_KEY")
    endpoint = os.environ.get(
        "R2_ENDPOINT",
        f"https://{account_id}.r2.cloudflarestorage.com",
    )
    return R2Config(account_id, bucket, access_key_id, secret_access_key, endpoint)


def _required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing environment variable: {name}")
    return value


def _discover_release_files(release_dir: Path) -> list[str]:
    return sorted(
        file_path.name
        for file_path in release_dir.iterdir()
        if file_path.is_file()
        and (
        file_path.name == "manifest.json"
        or file_path.name.startswith("manifest-")
        or ".zip.part-" in file_path.name
        or file_path.suffix == ".zip"
        )
    )


def _build_object_key(file_name: str, prefix: str, layout: str) -> str:
    object_parts: list[str] = [part for part in [prefix.strip("/")] if part]
    if layout == "updates":
        if file_name.startswith("game-") and file_name.endswith(".zip"):
            object_parts.append("game")
        elif (
            file_name.startswith("pokemon-")
            or file_name.startswith("music-")
        ) and file_name.endswith(".zip"):
            object_parts.append("assets")
        elif file_name.startswith("PokeAetherLauncher-") and file_name.endswith(".zip"):
            object_parts.append("launcher")
            object_parts.append("latest")
    object_parts.append(file_name)
    return "/".join(object_parts)


def _upload_file(config: R2Config, file_path: Path, key: str) -> None:
    parsed_endpoint = urlparse(config.endpoint)
    if parsed_endpoint.scheme != "https":
        raise SystemExit("R2_ENDPOINT must use https")

    host = parsed_endpoint.netloc
    canonical_uri = _canonical_uri(config.bucket, key)
    payload_hash = _sha256_hex(file_path)
    content_length = file_path.stat().st_size
    content_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    cache_control = _get_cache_control_for_key(key)

    for attempt in range(1, MAX_UPLOAD_ATTEMPTS + 1):
        try:
            status, reason, response_body = _upload_file_once(
                config,
                file_path,
                host,
                canonical_uri,
                payload_hash,
                content_length,
                content_type,
                cache_control,
            )
        except (OSError, http.client.HTTPException) as error:
            failure = f"{type(error).__name__}: {error}"
            if attempt >= MAX_UPLOAD_ATTEMPTS:
                raise SystemExit(
                    f"Upload failed for {file_path.name} after {attempt} attempts: {failure}"
                ) from error
            _wait_before_retry(file_path.name, attempt, failure)
            continue

        if 200 <= status < 300:
            return

        failure = f"{status} {reason}"
        if response_body:
            failure = f"{failure}\n{response_body}"
        if not _is_retryable_http_status(status) or attempt >= MAX_UPLOAD_ATTEMPTS:
            raise SystemExit(f"Upload failed for {file_path.name}: {failure}")
        _wait_before_retry(file_path.name, attempt, failure)


def _upload_file_once(
    config: R2Config,
    file_path: Path,
    host: str,
    canonical_uri: str,
    payload_hash: str,
    content_length: int,
    content_type: str,
    cache_control: str,
) -> tuple[int, str, str]:

    now = dt.datetime.now(dt.UTC)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    credential_scope = f"{date_stamp}/auto/s3/aws4_request"

    headers = {
        "Cache-Control": cache_control,
        "Content-Length": str(content_length),
        "Content-Type": content_type,
        "Host": host,
        "X-Amz-Content-Sha256": payload_hash,
        "X-Amz-Date": amz_date,
    }
    canonical_headers = "".join(f"{name.lower()}:{headers[name]}\n" for name in sorted(headers))
    signed_headers = ";".join(name.lower() for name in sorted(headers))
    canonical_request = "\n".join(
        [
            "PUT",
            canonical_uri,
            "",
            canonical_headers,
            signed_headers,
            payload_hash,
        ]
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
        f"SignedHeaders={signed_headers}, "
        f"Signature={signature}"
    )

    connection = http.client.HTTPSConnection(host, timeout=600)
    try:
        with file_path.open("rb") as file:
            connection.request("PUT", canonical_uri, body=file, headers=headers)
            response = connection.getresponse()
            response_body = response.read().decode("utf-8", errors="replace")
            return response.status, response.reason, response_body
    finally:
        connection.close()


def _is_retryable_http_status(status: int) -> bool:
    return status in (408, 429) or 500 <= status < 600


def _wait_before_retry(file_name: str, attempt: int, failure: str) -> None:
    delay = INITIAL_RETRY_DELAY_SECONDS * (2 ** (attempt - 1))
    print(
        f"Upload attempt {attempt}/{MAX_UPLOAD_ATTEMPTS} for {file_name} failed: {failure}",
        flush=True,
    )
    print(f"Retrying in {delay:g} seconds.", flush=True)
    time.sleep(delay)


def _canonical_uri(bucket: str, key: str) -> str:
    parts = [bucket] + [part for part in key.split("/") if part]
    return "/" + "/".join(quote(part, safe="-_.~") for part in parts)


def _get_cache_control_for_key(key: str) -> str:
    file_name = key.rsplit("/", 1)[-1]
    if (
        key.startswith("launcher/latest/")
        or key.startswith("game/latest/")
        or file_name == "manifest.json"
        or file_name.startswith("manifest-")
    ):
        return "no-cache, max-age=0"

    return "public, max-age=31536000, immutable"


def _sha256_hex(file_path: Path) -> str:
    digest = hashlib.sha256()
    with file_path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _sign(key: bytes, message: str) -> bytes:
    return hmac.new(key, message.encode("utf-8"), hashlib.sha256).digest()


def _get_signature_key(key: str, date_stamp: str, region_name: str, service_name: str) -> bytes:
    date_key = _sign(("AWS4" + key).encode("utf-8"), date_stamp)
    region_key = _sign(date_key, region_name)
    service_key = _sign(region_key, service_name)
    return _sign(service_key, "aws4_request")


if __name__ == "__main__":
    main()
