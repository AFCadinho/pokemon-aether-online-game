"""Produce a review candidate for Biochao Unown A's red export artifact.

The archived source's body albedo is white, but the generic Blender-to-glTF
shader bake produces a flat red body. This replaces that unsupported shader
output with an opaque charcoal PBR colour. It does not approve normal or shiny.
"""

import hashlib
from pathlib import Path

from catalog_remaining_eye_bake import write_glb
from catalog_remaining_shiny_glb import read_glb


SOURCE_SHA256 = "8e1deb6e7cf14e12f2cf52235c45035b913a7b9e60950fa4473683dd5248fafb"
BODY_COLOR = [0.12, 0.12, 0.14, 1.0]


def repair(source, target, source_sha256):
    if source_sha256 != SOURCE_SHA256:
        raise ValueError("Unown A source hash changed")
    document, binary = read_glb(Path(source))
    materials = [m for m in document.get("materials", []) if m.get("name") == "body"]
    if len(materials) != 1:
        raise ValueError("Expected one Unown body material")
    body = materials[0]
    if not body.get("pbrMetallicRoughness", {}).get("baseColorTexture"):
        raise ValueError("Expected the original baked body texture")
    body["pbrMetallicRoughness"].pop("baseColorTexture")
    body["pbrMetallicRoughness"]["baseColorFactor"] = BODY_COLOR
    body["alphaMode"] = "OPAQUE"
    for material in document["materials"]:
        if material.get("name") in ("body", "eye"):
            material.pop("emissiveTexture", None)
            material.pop("emissiveFactor", None)
    write_glb(Path(target), document, binary)
    return {"policy": "unown-a-flat-body-review-v1",
            "sha256": hashlib.sha256(Path(target).read_bytes()).hexdigest(),
            "runtime_approved": False}
