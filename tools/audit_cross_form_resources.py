#!/usr/bin/env python3
"""Read-only v14 archive inventory and conservative cross-pair sharing study.

Filename signatures nominate candidates; a separate Godot run must recompute
their full resource signatures before any saving is reported as verified.
No candidate archive, production catalog or remote object is changed.
"""
import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile

from probe_v13_compression import PIN_FIELDS, checked_bytes, encoded, read, require, unpack_pck, write

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = re.compile(r"^(textures|meshes|skins|libraries)/([0-9a-f]{64})\.res$")
REVISION = "approved-pokemon-3d-v14"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def catalog():
    meta = read(ROOT / "release/approved_3d_bundles_v14.json")
    trusted = ROOT / "data/model_pair_release_v14_catalog.json"
    index = ROOT / "release/approved_3d_bundles_v14_index.json"
    binding = read(ROOT / "release/approved_3d_v14_binding.json")
    require(meta["revision"] == binding["revision"] == REVISION, "Unexpected release")
    require(binding["publication_approved"] and binding["runtime_approved"], "Unapproved binding")
    require(sha(index) == meta["index"]["sha256"] == binding["bundle_index_sha256"], "Index pin mismatch")
    require(sha(trusted) == binding["trusted_catalog_sha256"], "Trusted catalog pin mismatch")
    full = {a["asset_id"]: a for a in read(trusted)["assets"]}
    wire = read(index)
    require(wire["catalog_revision"] == REVISION and wire["production_approved"], "Unapproved index")
    assets = []
    for compact, pin in zip(wire["assets"], meta["bundles"], strict=True):
        asset = full[compact["asset_id"]] if compact.get("format") == "model-pair-ref-v1" else compact
        require(all(asset[k] == pin[k] for k in PIN_FIELDS), "Release bundle pin mismatch")
        if compact.get("format") == "model-pair-ref-v1":
            require(compact == {"asset_id": asset["asset_id"], "format": "model-pair-ref-v1", "sha256": asset["sha256"]}, "Forged reference")
        assets.append(asset)
    require(len(assets) == len({a["asset_id"] for a in assets}) == 1420, "Incomplete v14 collection")
    require(sum(a["size_bytes"] for a in assets) == meta["total_bundle_bytes"], "Wrong collection total")
    return meta, assets


def inventory(asset, source):
    require(Path(source).is_absolute(), "Source must be an existing absolute path")
    data = checked_bytes(source, asset)
    resources = []
    if asset.get("format") == "model-pair-pck-v1":
        members, _ = unpack_pck(data, asset)
        for name, payload in members.items():
            match = RESOURCE.fullmatch(name)
            if match:
                resources.append({"path": name, "category": match[1], "signature": match[2],
                                  "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})
            else:
                require(name in ("bundle.json", "models/normal.scn", "models/shiny.scn"), "Unknown resource class")
        schema = asset["pair_manifest"]["schema"]
    else:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            names = archive.namelist()
            require(len(names) == len(set(names)) and set(names) == {"bundle.json", "models/normal.scn", "models/shiny.scn"}, "Unexpected ZIP members")
            manifest = json.loads(archive.read("bundle.json"))
            require(manifest["asset_id"] == asset["asset_id"] and manifest["version"] == asset["version"], "ZIP manifest mismatch")
            for appearance in asset["appearances"]:
                payload = archive.read("models/" + appearance["variant"] + ".scn")
                require(hashlib.sha256(payload).hexdigest() == appearance["runtime_sha256"], "ZIP scene pin mismatch")
        schema = 0
    return {"asset_id": asset["asset_id"], "sha256": asset["sha256"], "bytes": len(data),
            "schema": schema, "resources": resources, "source": str(source)}


def groups(rows, key):
    found = defaultdict(list)
    for row in rows:
        for resource in row["resources"]:
            found[key(resource)].append({"asset_id": row["asset_id"], **resource})
    result = []
    for _, occurrences in sorted(found.items()):
        # Duplicates inside one pair are a different scope, already covered by
        # normal/shiny sharing. Never count those as cross-pair savings.
        by_asset = defaultdict(list)
        for entry in occurrences:
            by_asset[entry["asset_id"]].append(entry)
        if len(by_asset) < 2:
            continue
        require(all(len(entries) == 1 for entries in by_asset.values()), "Repeated resource key inside a pair")
        result.append({"category": occurrences[0]["category"], "occurrences": occurrences,
                       "member_byte_opportunity": sum(x["bytes"] for x in occurrences) - min(x["bytes"] for x in occurrences)})
    return result


def measure(sources_path, output, workers):
    require(not output.exists(), "Fresh output directory required")
    meta, assets = catalog()
    sources = read(sources_path)
    require(sources["revision"] == REVISION and sources["metadata_sha256"] == sha(ROOT / "release/approved_3d_bundles_v14.json"), "Source mapping pin mismatch")
    require(set(sources["sources"]) == {a["asset_id"] for a in assets}, "Incomplete source mapping")
    with ThreadPoolExecutor(max_workers=workers) as pool:
        rows = list(pool.map(lambda a: inventory(a, sources["sources"][a["asset_id"]]), assets))
    nominated = groups(rows, lambda r: r["path"])
    exact = groups(rows, lambda r: (r["sha256"], r["bytes"]))
    selected = defaultdict(set)
    for group in nominated:
        for row in group["occurrences"]:
            selected[row["asset_id"]].add(row["path"])
    jobs = [{"source": sources["sources"][a["asset_id"]], "asset": a,
             "resources": sorted(selected[a["asset_id"]]),
             "inspect_embedded": a.get("pair_manifest", {}).get("schema", 0) < 2}
            for a in assets if a["asset_id"] in selected or a.get("pair_manifest", {}).get("schema", 0) < 2]
    output.mkdir(parents=True)
    write(output / "engine-job.json", {"schema": 1, "jobs": jobs})
    report = {"schema": 1, "revision": REVISION, "production_approved": False,
              "complete": False, "archives_verified": len(rows), "source_bytes": meta["total_bundle_bytes"],
              "source_metadata_sha256": sources["metadata_sha256"],
              "implementation_sha256": sha(__file__),
              "engine_script_sha256": sha(ROOT / "tools/sprite_factory/cross_form_resource_check.gd"),
              "engine_job_sha256": sha(output / "engine-job.json"),
              "cohorts": dict(Counter(str(r["schema"]) for r in rows)),
              "external_resources": sum(len(r["resources"]) for r in rows),
              "byte_identical_groups": exact, "nominated_groups": nominated,
              "inventory": [{k: v for k, v in r.items() if k != "source"} for r in rows]}
    write(output / "inventory.json", report)
    print(f"INVENTORY_OK archives={len(rows)} nominated_groups={len(nominated)} engine_packs={len(jobs)}", flush=True)


def finalize(output):
    report = read(output / "inventory.json")
    require(sha(output / "engine-job.json") == report["engine_job_sha256"], "Changed engine job")
    require(sha(__file__) == report["implementation_sha256"], "Changed inventory implementation")
    script = ROOT / "tools/sprite_factory/cross_form_resource_check.gd"
    require(sha(script) == report["engine_script_sha256"], "Changed engine implementation")
    engine = read(output / "engine-report.json")
    require(engine["complete"] and engine["errors"] == [] and engine["job_sha256"] == report["engine_job_sha256"], "Engine run incomplete or unbound")
    require(engine["script_sha256"] == report["engine_script_sha256"], "Engine script pin mismatch")
    expected = {(r["asset_id"], r["path"]): r for g in report["nominated_groups"] for r in g["occurrences"]}
    require(len(engine["resources"]) == len(expected), "Engine occurrence count mismatch")
    seen = set()
    for proof in engine["resources"]:
        key = (proof["asset_id"], proof["path"])
        require(key in expected and key not in seen, "Unknown or repeated engine occurrence")
        row = expected[key]
        require(proof["signature"] == row["signature"] and proof["sha256"] == row["sha256"], "Full resource signature mismatch")
        require(not proof["local_to_scene"] and proof["dependencies"] == 0 and proof["sensitive_tracks"] == 0, "Unsafe resource sharing candidate")
        seen.add(key)
    by_category = Counter()
    for group in report["nominated_groups"]:
        by_category[group["category"]] += group["member_byte_opportunity"]
        # Fractional owner allocation would imply an accuracy we do not have.
        # Attribute to a group of species IDs, with no guessed family mapping.
        group["species_ids"] = sorted({x["asset_id"].split(":")[1] for x in group["occurrences"]})
    # Embedded resources have no individually measured archive size. Record
    # strict matches separately; adding raw image bytes to compressed member
    # opportunities would falsely inflate the advertised saving.
    semantic = defaultdict(set)
    for row in report["inventory"]:
        for resource in row["resources"]:
            semantic[(resource["category"], resource["signature"])].add(row["asset_id"])
    embedded_keys = set()
    for row in engine["embedded_resources"]:
        if row["eligible"]:
            key = (row["category"], row["signature"])
            semantic[key].add(row["asset_id"])
            embedded_keys.add(key)
    embedded_matches = [{"category": k[0], "signature": k[1], "asset_ids": sorted(semantic[k])}
                        for k in sorted(embedded_keys) if len(semantic[k]) > 1]
    report.update(complete=True, engine_report_sha256=sha(output / "engine-report.json"),
                  verified_resource_occurrences=len(seen), engine_godot=engine["godot"],
                  candidate_member_bytes=sum(by_category.values()), by_category=dict(by_category),
                  embedded_pairs_verified=engine["embedded_pairs"],
                  embedded_resource_objects=len(engine["embedded_resources"]),
                  embedded_cross_pair_matches=embedded_matches,
                  top_groups=sorted(report["nominated_groups"], key=lambda g: g["member_byte_opportunity"], reverse=True)[:20],
                  limitations=["Compressed member-byte opportunity, not measured replacement archive or guaranteed savings.",
                               "Production loader requires each dependency to stay inside its pair namespace; sharing needs a versioned loader/launcher format.",
                               "Strict full resource signatures exclude paths and scene-unique labels but preserve names, locality, pixels/mipmaps and all other stored properties.",
                               "Embedded resources are semantically inventoried, but their matches have no measured standalone archive saving and are excluded from the member-byte total.",
                               "Immutable resource files differ even with matching semantic signatures; this is not simple object deletion.",
                               "No rewritten scenes, rendered battles, runtime lifetime qualification, remote publication or cleanup."])
    write(output / "report.json", report)
    print(f"AUDIT_OK candidate_member_bytes={report['candidate_member_bytes']} categories={dict(by_category)}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workers", type=int, choices=range(1, 5), default=2)
    parser.add_argument("--finalize", action="store_true")
    args = parser.parse_args()
    if args.finalize:
        finalize(args.output.resolve())
    else:
        require(args.sources is not None, "--sources required for inventory")
        measure(args.sources, args.output.resolve(), args.workers)


if __name__ == "__main__":
    main()
