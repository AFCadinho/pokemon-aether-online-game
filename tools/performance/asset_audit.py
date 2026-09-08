"""Read tracked asset headers and animation duplicates; no imports or game launch."""
import hashlib
import json
import struct
import subprocess
from collections import defaultdict
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[2]
    files = subprocess.check_output(["git", "ls-files", "assets"], cwd=root, text=True).splitlines()
    duplicates = defaultdict(list)
    tracked_pngs = 0
    for name in files:
        path = root / name
        if path.suffix.lower() != ".png" or not path.is_file():
            continue
        with path.open("rb") as stream:
            header = stream.read(24)
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            continue
        tracked_pngs += 1
        width, height = struct.unpack(">II", header[16:24])
        if name in ["assets/ui/pokeaether_combo_logo.png", "assets/ui/pokeaether_text_logo.png"]:
            print(json.dumps({"login_texture": name, "width": width, "height": height,
                "rgba8_mib_estimate": width * height * 4 / 1048576}))
        if name.startswith("assets/battles/animations/"):
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            duplicates[digest].append((name, path.stat().st_size, width * height * 4))
    groups = [rows for rows in duplicates.values() if len(rows) > 1]
    groups.sort(key=lambda rows: (len(rows) - 1) * rows[0][1], reverse=True)
    print(json.dumps({"tracked_png_count": tracked_pngs, "identical_animation_png_groups": len(groups),
        "duplicate_source_png_bytes": sum((len(rows) - 1) * rows[0][1] for rows in groups)}))
    for rows in groups[:5]:
        print(json.dumps({"identical_paths": [row[0] for row in rows],
            "source_bytes_each": rows[0][1], "rgba8_mib_each_estimate": rows[0][2] / 1048576}))


if __name__ == "__main__":
    main()
