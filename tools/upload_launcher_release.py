#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import hmac
import http.client
import mimetypes
import os
from pathlib import Path
from urllib.parse import quote, urlparse


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RELEASE_DIR = PROJECT_ROOT / "builds" / "launcher"


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

        key = "/".join(part for part in [args.prefix.strip("/"), file_name] if part)
        _upload_file(config, file_path, key)
        print(f"Uploaded {file_path.name} -> s3://{config.bucket}/{key}")


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
            or (file_path.name.startswith("game-") and file_path.suffix == ".zip")
        )
    )


def _upload_file(config: R2Config, file_path: Path, key: str) -> None:
    parsed_endpoint = urlparse(config.endpoint)
    if parsed_endpoint.scheme != "https":
        raise SystemExit("R2_ENDPOINT must use https")

    host = parsed_endpoint.netloc
    canonical_uri = _canonical_uri(config.bucket, key)
    payload_hash = _sha256_hex(file_path)
    content_length = file_path.stat().st_size
    content_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"

    now = dt.datetime.now(dt.UTC)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    credential_scope = f"{date_stamp}/auto/s3/aws4_request"

    headers = {
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

    connection = http.client.HTTPSConnection(host, timeout=120)
    try:
        with file_path.open("rb") as file:
            connection.request("PUT", canonical_uri, body=file, headers=headers)
            response = connection.getresponse()
            response_body = response.read().decode("utf-8", errors="replace")
            if response.status < 200 or response.status >= 300:
                raise SystemExit(
                    f"Upload failed for {file_path.name}: {response.status} {response.reason}\n{response_body}"
                )
    finally:
        connection.close()


def _canonical_uri(bucket: str, key: str) -> str:
    parts = [bucket] + [part for part in key.split("/") if part]
    return "/" + "/".join(quote(part, safe="-_.~") for part in parts)


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
