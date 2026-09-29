"""Create source-faithful eye-texture review GLBs for five pinned Biochao models.

The source mirrorTexture graph is lost by glTF. Bake its Base Color over the
source UV domain, then give the eye primitives local 0..1 UVs for that bake.
This only creates review candidates; it does not qualify shinies or battles.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

from catalog_remaining_eye_bake import append_png, write_glb
from catalog_remaining_shiny_glb import read_glb


SOURCES = {
    "darmanitan-standard": ("pm0555_11_12.blend", "2bd48db021316e0ca499d9a569d9dbf4b34b03c514df5ed7de7367f76e9ac27d", ("Eye",)),
    "wishiwashi": ("pm0820_11.blend", "028fdad10505fcea05f8e03ef5dac10ada2fec7ab1077066e5fd96663b6ba669", ("Eye",)),
    "silvally": ("pm0862_11.blend", "25ab80539f2636429ef5e65087ba27e75946261283629da3a1e58c789ae7bb8f", ("Eye11",)),
    "obstagoon": ("pm0928_00_31.blend", "bc0043d5fef6670097ca875a90d4f452f9eecc2ea44035a68048a812710ddbbe", ("LEye", "REye")),
    "cursola": ("pm0947_00_31.blend", "393b3e2f6ec5adbdde009878602011e7d3cd4f4962225aeff1df75d86091d86a", ("Eye",)),
}


def eye_primitives(document, binary, names):
    selected = {name: [] for name in names}
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            name = document["materials"][primitive["material"]]["name"]
            if name not in selected:
                continue
            accessor = document["accessors"][primitive["attributes"]["TEXCOORD_0"]]
            view = document["bufferViews"][accessor["bufferView"]]
            if accessor["componentType"] != 5126 or accessor["type"] != "VEC2":
                raise ValueError(f"{name}: unsupported UV accessor")
            offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", 8)
            values = [struct.unpack_from("<2f", binary, offset + i * stride)
                      for i in range(accessor["count"])]
            selected[name].append((primitive, values))
    if any(len(items) != 1 for items in selected.values()):
        raise ValueError("Expected one primitive for each named eye material")
    return selected


def repair(species, source, glb, target):
    expected_name, expected_hash, names = SOURCES[species]
    if source.name != expected_name or hashlib.sha256(source.read_bytes()).hexdigest() != expected_hash:
        raise ValueError("Unrecognized source model; eye material needs fresh review")
    document, binary = read_glb(glb)
    binary = bytearray(binary)
    selected = eye_primitives(document, binary, names)
    job = {"source": str(source), "materials": []}
    bounds = {}
    for name, items in selected.items():
        values = items[0][1]
        u0, u1 = min(v[0] for v in values), max(v[0] for v in values)
        v0, v1 = min(v[1] for v in values), max(v[1] for v in values)
        if u1 <= u0 or v1 <= v0:
            raise ValueError(f"{name}: degenerate eye UV bounds")
        bounds[name] = (u0, u1, v0, v1)
        job["materials"].append({"name": name, "source_uv_bounds": [u0, u1, 1 - v1, 1 - v0],
                                 "output": str(target.parent / f"{species}-{name}-source-eye.png")})
    target.parent.mkdir(parents=True, exist_ok=True)
    job_path = target.parent / f"{species}-eye-domain-job.json"
    job_path.write_text(json.dumps(job, indent=2) + "\n")
    worker = Path(__file__).with_name("catalog_remaining_eye_domain_worker.py").resolve()
    command = ["flatpak", "run", "--unshare=network", "--nofilesystem=host",
               "--filesystem=" + str(source.parent), "--filesystem=" + str(target.parent),
               "--filesystem=" + str(worker.parent) + ":ro", "org.blender.Blender",
               "--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1",
               "--python", str(worker), "--", str(job_path)]
    log = target.parent / f"{species}-eye-domain-bake.log"
    with log.open("w") as stream:
        subprocess.run(command, check=True, timeout=180, stdout=stream, stderr=subprocess.STDOUT)
    for item in job["materials"]:
        name = item["name"]
        material = next(m for m in document["materials"] if m["name"] == name)
        pbr = material["pbrMetallicRoughness"]
        old = pbr["baseColorTexture"]
        sampler = document["textures"][old["index"]].get("sampler", 0)
        index = append_png(document, binary, Path(item["output"]).read_bytes(),
                           name + "_source_eye_domain", sampler)
        pbr["baseColorTexture"] = {**old, "index": index}
        material["alphaMode"] = "OPAQUE"
        material.pop("emissiveFactor", None)
        material.pop("emissiveTexture", None)
        u0, u1, v0, v1 = bounds[name]
        for primitive, values in selected[name]:
            packed = b"".join(struct.pack("<2f", (u - u0) / (u1 - u0), (v - v0) / (v1 - v0))
                              for u, v in values)
            view = len(document["bufferViews"])
            document["bufferViews"].append({"buffer": 0, "byteOffset": len(binary),
                                             "byteLength": len(packed)})
            binary.extend(packed)
            accessor = len(document["accessors"])
            document["accessors"].append({"bufferView": view, "componentType": 5126,
                                           "count": len(values), "type": "VEC2"})
            primitive["attributes"]["TEXCOORD_0"] = accessor
    write_glb(target, document, binary)
    return {"species": species, "source_sha256": expected_hash, "eye_materials": list(names),
            "glb": str(target), "glb_sha256": hashlib.sha256(target.read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--species", choices=SOURCES, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--glb", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(repair(args.species, args.source.resolve(), args.glb.resolve(),
                            args.target.resolve()), indent=2))


if __name__ == "__main__":
    main()
