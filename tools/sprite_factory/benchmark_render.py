"""Compare an archived Sprite Factory renderer with a candidate worker.

This renders a short, explicit action slice into a temporary output directory.
It never changes an existing build or approval state.
"""

import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def run(label, worker, source, manifest, root, geometry_scan, batch_animation, samples):
    output = root / label
    output.mkdir()
    result = output / "result.json"
    job = output / "job.json"
    job.write_text(json.dumps({
        "mode": "render",
        "manifest": manifest,
        "variant": "normal",
        "output": str(output),
        "result": str(result),
        "geometry_scan": geometry_scan,
        "batch_animation": batch_animation,
        "taa_render_samples": samples,
    }, indent=2))
    command = ["flatpak", "run", "org.blender.Blender", "--background", "--factory-startup",
               "--disable-autoexec", str(source), "--python-exit-code", "1", "--python",
               str(worker), "--", str(job)]
    started = time.perf_counter()
    with (output / "blender.log").open("w") as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
    return output, json.loads(result.read_text()), time.perf_counter() - started


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--reference-build", type=Path, required=True)
    parser.add_argument("--candidate-worker", type=Path,
                        default=Path(__file__).with_name("blender_worker.py"))
    parser.add_argument("--output-parent", type=Path, required=True)
    parser.add_argument("--view", choices=("front", "back"), default="front")
    parser.add_argument("--action", default="idle")
    parser.add_argument("--frames", type=int, default=30)
    parser.add_argument("--samples", type=int, choices=(16, 32, 64), default=16)
    args = parser.parse_args()
    source = args.source.resolve()
    reference = args.reference_build.resolve()
    candidate_worker = args.candidate_worker.resolve()
    output_parent = args.output_parent.resolve()
    manifest = json.loads((reference / "provenance.json").read_text())["identity"]["manifest"]
    manifest["cameras"] = {args.view: manifest["cameras"][args.view]}
    action = manifest["actions"].get(args.action)
    if action is None:
        parser.error("reference build has no requested action")
    action["frames"] = action["frames"][:args.frames]
    if len(action["frames"]) != args.frames:
        parser.error("reference action has fewer frames than requested")
    manifest["actions"] = {args.action: action}
    root = Path(tempfile.mkdtemp(prefix="sprite-render-benchmark-", dir=output_parent))
    baseline, _baseline_result, baseline_elapsed = run(
        "baseline", reference / "blender_worker.py", source, manifest, root, True, False, 64)
    candidate, candidate_result, candidate_elapsed = run(
        "candidate", candidate_worker, source, manifest, root, False, True, args.samples)
    baseline_frames = sorted((baseline / "masters" / args.view / args.action).glob("*.png"))
    candidate_frames = sorted((candidate / "masters" / args.view / args.action).glob("*.png"))
    if len(baseline_frames) != len(candidate_frames) or len(baseline_frames) != args.frames:
        raise RuntimeError("benchmark produced an unexpected frame count")
    changed = []
    visible_means = []
    maxima = []
    for index, (left, right) in enumerate(zip(baseline_frames, candidate_frames)):
        with Image.open(left) as a, Image.open(right) as b:
            a = a.convert("RGBA")
            b = b.convert("RGBA")
            diff = ImageChops.difference(a, b)
            if diff.getbbox():
                changed.append(index)
            bbox = ImageChops.lighter(a.getchannel("A"), b.getchannel("A")).getbbox()
            if bbox:
                visible_means.append(sum(ImageStat.Stat(diff.crop(bbox)).mean) / 4)
            maxima.append(max(high for _low, high in diff.getextrema()))
    report = {
        "schema": 1,
        "view": args.view,
        "action": args.action,
        "frames": args.frames,
        "candidate_samples": args.samples,
        "changed_frames": changed,
        "visible_mean_absolute_channel_delta": sum(visible_means) / len(visible_means),
        "maximum_channel_delta": max(maxima),
        "baseline_elapsed_seconds": baseline_elapsed,
        "candidate_elapsed_seconds": candidate_elapsed,
        "speedup": baseline_elapsed / candidate_elapsed,
        "candidate_timings": candidate_result.get("timings"),
        "output": str(root),
    }
    (root / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
