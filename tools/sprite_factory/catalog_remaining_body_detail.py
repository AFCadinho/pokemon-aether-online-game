"""Source-pinned normal-body material review candidates for six Biochao forms.

Four sources mix a missing `Colors` vertex attribute with their albedo at
factor 0.5. Blender therefore renders half the linear albedo; glTF exports
only the raw image. Unown's body uses a layered shader and needs its authored
Base Color bake. Darmanitan has a separate visual contrast calibration.
Nothing here approves a model for catalog use.
"""

import hashlib
from pathlib import Path

from PIL import Image

from catalog_remaining_eye_bake import append_png, write_glb
from catalog_remaining_shiny_glb import read_glb


POLICY = "remaining-six-body-detail-review-v1"
SOURCES = {
    "unown": ("8e1deb6e7cf14e12f2cf52235c45035b913a7b9e60950fa4473683dd5248fafb", 1.0, ("body",)),
    "darmanitan-standard": ("2bd48db021316e0ca499d9a569d9dbf4b34b03c514df5ed7de7367f76e9ac27d", 0.7,
                           ("BodyA00", "BodyA01", "BodyAVco", "BodyB")),
    "wishiwashi": ("028fdad10505fcea05f8e03ef5dac10ada2fec7ab1077066e5fd96663b6ba669", 0.5,
                   ("BodyVco", "BodyTattuSpcVco00", "BodyTattuSpcVco01")),
    "silvally": ("25ab80539f2636429ef5e65087ba27e75946261283629da3a1e58c789ae7bb8f", 0.5,
                 ("BodyA", "BodyASpc00", "BodyASpc01", "BodyB", "BodyBSpc00", "BodyBSpc01", "BodyBSpc02", "BodyCIncVco11")),
    "obstagoon": ("bc0043d5fef6670097ca875a90d4f452f9eecc2ea44035a68048a812710ddbbe", 0.5,
                  ("BodyA00", "BodyA01", "BodyA02", "BodyB00", "BodyB01")),
    "cursola": ("393b3e2f6ec5adbdde009878602011e7d3cd4f4962225aeff1df75d86091d86a", 0.5,
                ("BodyA", "BodyB", "Mouth", "Feeler00", "Feeler01", "Feeler02", "Feeler03", "Feeler04", "Missile")),
}


def repair(species, source_sha256, source, target, unown_body_bake=None):
    expected_sha, brightness, names = SOURCES[species]
    if source_sha256 != expected_sha:
        raise ValueError("Source hash changed; body materials need fresh review")
    document, binary = read_glb(Path(source))
    binary = bytearray(binary)
    found = {material["name"]: material for material in document["materials"]
             if material["name"] in names}
    if set(found) != set(names):
        raise ValueError("Expected body material set differs from exported GLB")
    if species == "unown":
        if unown_body_bake is None:
            raise ValueError("Unown needs its authored body bake")
        with Image.open(unown_body_bake) as image:
            ranges = image.convert("RGB").getextrema()
            if image.size != (512, 512) or ranges[2][1] <= ranges[0][1] + 20:
                raise ValueError("Unown body bake does not contain its blue authored colour")
        material = found["body"]
        pbr = material["pbrMetallicRoughness"]
        if "baseColorTexture" in pbr or pbr.get("baseColorFactor") != [0.12, 0.12, 0.14, 1.0]:
            raise ValueError("Unown body is not the pinned charcoal diagnostic")
        texture = append_png(document, binary, Path(unown_body_bake).read_bytes(),
                             "unown_authored_body_base_color", 0)
        pbr["baseColorTexture"] = {"index": texture}
        pbr.pop("baseColorFactor")
    else:
        for material in found.values():
            pbr = material["pbrMetallicRoughness"]
            if "baseColorTexture" not in pbr:
                raise ValueError("Body albedo texture is missing")
            factor = pbr.get("baseColorFactor", [1, 1, 1, 1])
            if len(factor) != 4 or factor[:3] != [1, 1, 1]:
                raise ValueError("Body already has a colour adjustment")
            pbr["baseColorFactor"] = [brightness, brightness, brightness, factor[3]]
    target = Path(target)
    write_glb(target, document, binary)
    return {"policy": POLICY, "source_sha256": expected_sha,
            "body_materials": list(names), "runtime_approved": False,
            "glb_sha256": hashlib.sha256(target.read_bytes()).hexdigest()}
