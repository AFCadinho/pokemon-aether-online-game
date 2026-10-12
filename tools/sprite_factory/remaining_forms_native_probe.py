"""Read-only evidence for the 53 remaining forms; this never admits models.

Run with the existing SCVI importer's directory and dependencies on PYTHONPATH.
Archive listings establish absence only inside those particular archives.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import zipfile

from scvi_material_probe import inspect_materials
from scvi_tracm import _Buffer, inspect_tracm


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def pin(path):
    return {"path": str(path), "sha256": sha(path)}


def plain(value):
    if isinstance(value, bytes):
        return value.decode()
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    if isinstance(value, list):
        return [plain(v) for v in value]
    if hasattr(value, "tolist"):
        return value.tolist()
    return {k: plain(v) for k, v in vars(value).items()}


def skeleton(path):
    from Titan.Model.TRSKL import TRSKLT
    return plain(TRSKLT.InitFromPackedBuf(path.read_bytes()))


def compare_skeletons(base, variant):
    a, b = skeleton(base), skeleton(variant)
    changes = []
    for index, (x, y) in enumerate(zip(a["transformNodes"], b["transformNodes"])):
        if x != y:
            changes.append({"index": index, "rig_indices": [x["rigIdx"], y["rigIdx"]], "changes": {
                k: [x[k], y[k]] for k in x if x[k] != y[k]}})
    equal_counts = len(a["transformNodes"]) == len(b["transformNodes"])
    return {"base": pin(base), "variant": pin(variant),
            "bone_counts": [len(a["bones"]), len(b["bones"])],
            "transform_counts": [len(a["transformNodes"]), len(b["transformNodes"])],
            "bone_records_equal": a["bones"] == b["bones"],
            "other_skeleton_fields_equal": all(a[k] == b[k] for k in a if k not in ("bones", "transformNodes")),
            "transform_changes": changes,
            "only_transform_names_differ": equal_counts and all(set(c["changes"]) == {"name"} for c in changes)}


def selectors(path):
    b = _Buffer(path.read_bytes())
    return [{"name": b.string(v, 0),
             "switches": [[b.string(t, 0), b.scalar(t, 1, b.u8)] for t in b.tables(v, 2)],
             "properties": [{"name": b.string(t, 0),
                             "mappers": [[b.string(m, i) for i in range(3)] for m in b.tables(t, 1)]}
                            for t in b.tables(v, 3)]}
            for v in b.tables(b.u32(0), 2)]


def resource(directory):
    files = sorted(p for p in directory.rglob("*") if p.is_file())
    info = {"path": str(directory), "file_counts": dict(sorted(Counter(p.suffix for p in files).items())),
            "motions": [p.name for p in files if p.suffix == ".tranm"],
            "files": [pin(p) for p in files if p.suffix in (".trmdl", ".trskl", ".trpokecfg", ".trmtr", ".trmmt")],
            "models": [], "materials": [], "selectors": []}
    for p in files:
        if p.suffix == ".trmdl":
            b = _Buffer(p.read_bytes())
            info["models"].append({"file": p.name,
                                   "meshes": [b.string(t, 0) for t in b.tables(b.u32(0), 1)],
                                   "skeleton": b.string(b.pointer(b.u32(0), 2), 0)})
        elif p.suffix == ".trmtr":
            info["materials"].append({"file": p.name, "rows": inspect_materials(p)})
        elif p.suffix == ".trmmt":
            info["selectors"].append({"file": p.name, "variants": selectors(p)})
    return info


def collect(args):
    here = Path(__file__).resolve().parent
    previous = json.loads((here / "alternate_forms_recovery_result.json").read_text())
    intake = json.loads((here / "alternate_forms_source_intake.json").read_text())
    held = {e["species"] for e in previous["entries"] if e["status"] == "held"}
    pms = {Path(p).parent.name for e in intake["entries"] if e["species"] in held for p in e["source_directories"]}
    pms.update(["pm0351", "pm0412", "pm0413", "pm0421", "pm0800", "pm1133", "pm1134"])
    pms.update(e["resource"][:6] for e in previous["entries"] if e["species"] in held and e.get("resource"))
    pms.add("pm0768")
    za_paths = [line.split()[-1] for line in args.za_listing.read_text().splitlines() if line.strip()]
    result = {"schema": 1, "runtime_approved": False,
              "worker": pin(Path(__file__).resolve()), "previous_result": pin(here / "alternate_forms_recovery_result.json"),
              "za_listing": pin(args.za_listing), "sv_listing": pin(args.sv_listing),
              "families": {}, "skeleton_comparisons": {},
              "archive_members": {}, "state_channels": {}}
    for archive in sorted((args.source_root / "Biochao").glob("Gen*.zip")):
        with zipfile.ZipFile(archive) as z:
            result["archive_members"][archive.name] = [
                {"name": i.filename, "bytes": i.file_size, "crc32": f"{i.CRC:08x}"}
                for i in z.infolist() if any(Path(i.filename).stem.startswith(pm) for pm in pms)]
    # The outer ZIP contains only SV-Everything.7z, not individual motions.
    sv_names = [line.split()[-1] for line in args.sv_listing.read_text().splitlines() if line.strip()]
    for pm in sorted(pms):
        scvi = args.source_root / "Pokémon SCVI Base + DLC Model Dump" / pm
        raw = args.source_root / "SV Every File/romfs/pokemon/data" / pm
        native = args.za_root / pm
        za = [p for p in za_paths if p.startswith(pm + "/")]
        sv = [p for p in sv_names if re.search(r"(?:^|/)" + pm + r"/", p)]
        result["families"][pm] = {
            "scvi": [resource(p) for p in sorted(scvi.glob("*")) if p.is_dir()],
            "za_extracted": [resource(p) for p in sorted(native.glob("*")) if p.is_dir()],
            "za_archive_resources": sorted({p.split("/")[1] for p in za if len(p.split("/")) > 2}),
            "za_archive_motion_count": sum(p.endswith(".tranm") for p in za),
            "sv_archive_motion_count": sum(p.endswith(".tranm") for p in sv),
            "sv_archive_sidechannel_count": sum(p.endswith(".tracm") for p in sv),
            "extracted_sv_motion_count": len(list(raw.rglob("*.tranm"))),
        }
    for pm in ("pm1133", "pm1134", "pm0382", "pm0383"):
        tea = pm in ("pm1133", "pm1134")
        root = (args.source_root / "Pokémon SCVI Base + DLC Model Dump") if tea else args.za_root
        a, b = ("11", "12") if tea else ("00", "51")
        result["skeleton_comparisons"][pm] = compare_skeletons(
            root / pm / f"{pm}_{a}_00" / f"{pm}_{a}_00.trskl",
            root / pm / f"{pm}_{b}_00" / f"{pm}_{b}_00.trskl")
    from PIL import Image, ImageChops
    result["tea_texture_differences"] = []
    for pm in ("pm1133", "pm1134"):
        folder = args.source_root / "Pokémon SCVI Base + DLC Model Dump" / pm / f"{pm}_11_00"
        for variant in ("", "_rare"):
            paths = [folder / f"{pm}_{f}_00_body{variant}_alb.png" for f in ("11", "12")]
            images = [Image.open(p).convert("RGB") for p in paths]
            if images[0].size != images[1].size:
                raise ValueError("Texture comparison requires matching source dimensions")
            difference = ImageChops.difference(*images)
            result["tea_texture_differences"].append({
                "family": pm, "variant": "shiny" if variant else "normal", "images": [pin(p) for p in paths],
                "dimensions": list(images[0].size), "difference_bbox": difference.getbbox(),
                "changed_pixels": sum(pixel != (0, 0, 0) for pixel in difference.get_flattened_data())})
    for pm, form in (("pm0768", "00"), ("pm0770", "11")):
        d = args.za_root / pm / f"{pm}_{form}_00"
        result["state_channels"][pm] = [{**pin(p), "channels": inspect_tracm(p)} for p in sorted(d.glob("*wait*.tracm"))]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.output.exists():
        raise ValueError("Keep previous evidence; use a fresh output path")
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Inspected {len(pms)} resource families; output {args.output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("source-root", "za-root", "za-listing", "sv-listing", "output"):
        parser.add_argument("--" + option, type=Path, required=True)
    collect(parser.parse_args())
