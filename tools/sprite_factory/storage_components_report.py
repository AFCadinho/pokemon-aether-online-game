"""Summarize real component files; do not mix proxies with measured bytes."""
import argparse
import json
import statistics
from pathlib import Path


def summarize(directory):
    directory = Path(directory)
    data = json.loads((directory / "prototype.json").read_text())
    components = data["components"]

    def size(ids):
        return sum(components[key]["bytes"] for key in set(ids))

    pairs = []
    all_ids, normal_ids = set(), set()
    for species in sorted({e["species"] for e in data["entries"]}):
        normal = next(e for e in data["entries"] if e["identity"] == species)
        shiny = next(e for e in data["entries"] if e["identity"] == species + "@shiny")
        n, s = set(normal["components"]), set(shiny["components"])
        all_ids |= n | s
        normal_ids |= n
        shared = n & s
        kinds = {}
        for key in shared:
            kind = components[key]["kind"]
            kinds[kind] = kinds.get(kind, 0) + 1
        pairs.append(dict(
            species=species, old_normal_bytes=normal["old_bytes"],
            old_shiny_bytes=shiny["old_bytes"], new_normal_bytes=size(n),
            new_shiny_standalone_bytes=size(s), new_pair_bytes=size(n | s),
            incremental_shiny_bytes=size(s - n), shared_bytes=size(shared),
            shared_components_by_kind=kinds,
            original_hashes=[normal["source_sha256"], shiny["source_sha256"]],
        ))
    old = sum(e["old_bytes"] for e in data["entries"])
    actual = sum(p.stat().st_size for p in directory.iterdir()
                 if p.suffix in (".res", ".scn") or p.name == "prototype.json")
    expected = size(all_ids) + (directory / "prototype.json").stat().st_size
    assert actual == expected, "Unreferenced or unaccounted package files"
    avg_normal = size(normal_ids) / len(pairs)
    avg_pair = size(all_ids) / len(pairs)
    result = dict(
        prototype_only=True, production_approved=False, pairs=pairs, old_bytes=old, new_package_bytes=actual,
        manifest_bytes=(directory / "prototype.json").stat().st_size,
        savings_percent=100 * (1 - actual / old), component_count=len(all_ids),
        normal_only_bytes=size(normal_ids), both_appearances_bytes=size(all_ids),
        normal_mean_mib=avg_normal / 2**20, pair_mean_mib=avg_pair / 2**20,
        extrapolation_gib={str(n): dict(normal=avg_normal*n/2**30,
                                       normal_and_shiny=avg_pair*n/2**30)
                           for n in [151, 500, 1000]},
    )
    for kind in ["visual", "original", "components"]:
        path = directory.parent / (directory.name + "-" + kind + ".json")
        if not path.exists():
            continue
        report = json.loads(path.read_text())
        if kind == "visual":
            result[kind] = dict(complete=report["complete"],
                               samples=len(report["comparisons"]),
                               pixel_exact=sum(c["pixel_exact"] for c in report["comparisons"]),
                               renderer=report["renderer"])
        else:
            loads = report.get("loads", [])
            def timing(rows):
                values = sorted(row["ms"] for row in rows)
                return dict(count=len(values), median_ms=statistics.median(values),
                            p95_ms=values[min(len(values)-1, int(len(values)*.95))],
                            max_ms=max(values)) if values else {}
            result[kind] = dict(complete=report["complete"],
                integrity_check_ms=report["integrity_check_ms"],
                first_pass=timing([r for r in loads[:24] if not r["hit"]]),
                reloaded=timing([r for r in loads[24:] if not r["hit"]]),
                cache_hit=timing([r for r in loads if r["hit"]]),
                baseline_memory=report["baseline_memory"], cycles=report["cycles"])
    result["runtime_measurements"] = (
        "Not run: visual gate stopped; no load, RAM/VRAM or lifecycle qualification."
        if "components" not in result else "See measured process-specific results.")
    result["extrapolation_caveat"] = (
        "Arithmetic for these six older control pairs only; not a measured 75-model migration. "
        "Mean/extrapolations exclude manifest overhead; package total includes it.")
    diagnostic = directory.parent / (directory.name + "-diagnostic.json")
    if diagnostic.exists():
        result["isolated_diagnostic"] = json.loads(diagnostic.read_text()).get("diagnostic", [])
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("output")
    args = parser.parse_args()
    Path(args.output).write_text(json.dumps(summarize(args.directory), indent=2) + "\n")
