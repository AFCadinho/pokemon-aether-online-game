#!/usr/bin/env python3
"""Make a tiny offline renderer project with its own import cache.

Tracked source scripts/shaders are referenced in place. No assets, caches,
userdata or environment configuration are copied from another checkout.
"""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.relative_to(root / ".tmp")
    if output.exists():
        raise ValueError("A fresh task-local probe project is required")
    output.mkdir(parents=True)
    files = ["tools/sprite_factory/native_resource_compression_check.gd",
             "tools/sprite_factory/native_paired_reference_check.gd",
             "tools/sprite_factory/native_warm_reference_diagnostic.gd",
             "tools/sprite_factory/native_surface_overlap_diagnostic.gd",
             "tools/sprite_factory/native_runtime_visibility_reference_check.gd",
             "tools/sprite_factory/visibility_pack.gd",
             "scripts/battle/animations/reviewed_source_visibility.gd",
             "scripts/battle/animations/source_visibility_pack.gd",
             "resources/battle/model_visibility/roaring_moon.json",
             "tools/sprite_factory/storage_components_check.gd",
             "tools/sprite_factory/storage_components.gd",
             "scripts/battle/battle_ui/material_response.gd",
             "scripts/battle/battle_ui/material_surface_order.gd",
             "scripts/battle/battle_ui/material_response.gdshader",
             "scripts/battle/battle_ui/material_irradiance.gdshader",
             "scripts/battle/battle_ui/material_effect.gd",
             "scripts/battle/battle_ui/material_fire.gdshader"]
    files += [str(path.relative_to(root)) for path in
              (root / "scripts/battle/battle_ui").glob("material_effect*.gdshader")]
    for relative in sorted(set(files)):
        source = root / relative
        assert source.is_file()
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.symlink_to(source)
        sidecar = Path(str(source) + ".uid")
        if sidecar.exists():
            Path(str(target) + ".uid").symlink_to(sidecar)
    # Preserve rendering settings; the test itself defines lights, camera,
    # world and MSAA exactly as the original storage comparison harness.
    rendering = (root / "project.godot").read_text().split("[rendering]", 1)[1].split("\n[", 1)[0]
    (output / "project.godot").write_text(
        'config_version=5\n\n[application]\nconfig/name="Native lossless model probe"\n'
        '\n[display]\nwindow/size/viewport_width=512\nwindow/size/viewport_height=512\n'
        '\n[rendering]' + rendering)
    print("NATIVE_PROBE_PROJECT_READY", output)


if __name__ == "__main__":
    main()
