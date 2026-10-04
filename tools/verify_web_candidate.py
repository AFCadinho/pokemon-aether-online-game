#!/usr/bin/env python3
"""Verify a frozen browser candidate against its successful GitHub source run."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SHA = re.compile(r"[a-f0-9]{40}")


def verify_source_run(run: dict, run_id: str, repo: Path = ROOT) -> str:
    source = run.get("head_sha", "")
    if (not re.fullmatch(r"[0-9]+", run_id)
            or str(run.get("id")) != run_id
            or run.get("path") != ".github/workflows/deploy-web-cloudflare.yml"
            or run.get("event") != "workflow_dispatch"
            or run.get("head_branch") != "main"
            or run.get("status") != "completed"
            or run.get("conclusion") != "success"
            or not SHA.fullmatch(source)):
        raise ValueError("Candidate must come from the successful main preview workflow run requested.")
    # Publication tooling may advance independently of the frozen game build.
    result = subprocess.run(["git", "merge-base", "--is-ancestor", source, "HEAD"], cwd=repo,
                            capture_output=True, text=True)
    if result.returncode:
        raise ValueError("Candidate source commit is not contained in the publisher's approved main history.")
    return source


def verify_artifact(root: Path, run: dict, run_id: str) -> dict:
    candidate = json.loads((root / "candidate.json").read_text())
    metadata = json.loads((root / "r2/web-release.json").read_text())
    manifest = json.loads((root / "r2/manifest-web.json").read_text())
    pages = root / "pages-production"
    config = json.loads((pages / "web-release-config.json").read_text())
    source = run["head_sha"]
    build_id = candidate.get("buildId", "")
    if not re.fullmatch(re.escape(f"{source}-{run_id}-") + r"[1-9][0-9]*", build_id):
        raise ValueError("Candidate build ID does not match its verified source run.")
    version = candidate.get("releaseVersion")
    if (candidate.get("runId") != run_id or candidate.get("sourceSha") != source
            or metadata.get("buildId") != build_id
            or metadata.get("releaseVersion") != version
            or manifest.get("gameVersion") != version
            or manifest.get("gameBuildId") != build_id
            or manifest.get("game", {}).get("version") != version
            or manifest.get("game", {}).get("buildId") != build_id
            or manifest.get("game", {}).get("url") != "https://play.pokeaether.com"
            or config.get("buildId") != build_id or config.get("clientBuildId") != build_id
            or config.get("releaseVersion") != version
            or config.get("assetBaseUrl") != "https://web-assets.pokeaether.com"):
        raise ValueError("Candidate manifests and production page configuration do not match the verified run.")
    html = (pages / "index.html").read_text()
    if f'"buildId":"{build_id}"' not in html or f'"clientBuildId":"{build_id}"' not in html:
        raise ValueError("Production page does not identify this candidate build.")
    # Old successful candidates remain publishable. New candidates also pin the
    # complete production page bundle, including map modules. Pages Functions
    # are restored from the verified source commit before deployment.
    if candidate.get("schemaVersion", 1) == 2:
        expected = candidate.get("pageFiles")
        actual = {path.relative_to(pages).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                  for path in pages.rglob("*") if path.is_file()}
        if not expected or expected != actual:
            raise ValueError("Candidate production page files changed after the build checks.")
    elif candidate.get("schemaVersion", 1) != 1:
        raise ValueError("Unsupported candidate schema.")
    return candidate


def verify_active_build(candidate: dict, manifest_build: str, api_build: str) -> None:
    allowed = {candidate["previewClientBuildId"], candidate["buildId"]}
    if manifest_build != api_build or manifest_build not in allowed:
        raise ValueError("The active browser release changed or the API and manifest disagree. "
                         "Resolve the active release before publishing this candidate.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-json", type=Path)
    parser.add_argument("--run-id")
    parser.add_argument("--candidate-dir", type=Path)
    parser.add_argument("--manifest-build")
    parser.add_argument("--api-build")
    args = parser.parse_args()
    try:
        if args.manifest_build is not None or args.api_build is not None:
            if not args.candidate_dir or args.manifest_build is None or args.api_build is None:
                parser.error("Active-release verification needs the candidate and both build IDs.")
            candidate = json.loads((args.candidate_dir / "candidate.json").read_text())
            verify_active_build(candidate, args.manifest_build, args.api_build)
            print("Active release is compatible with this candidate (including publication retries).")
        else:
            if not args.run_json or not args.run_id:
                parser.error("Source verification requires --run-json and --run-id.")
            run = json.loads(args.run_json.read_text())
            source = verify_source_run(run, args.run_id)
            if args.candidate_dir:
                candidate = verify_artifact(args.candidate_dir, run, args.run_id)
                print(f"Verified frozen candidate {candidate['buildId']} (version {candidate['releaseVersion']}).")
            else:
                print(f"Verified candidate source commit {source}; no rebuild required when publication tooling advances.")
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f"Candidate verification failed: {error}\n")


if __name__ == "__main__":
    main()
