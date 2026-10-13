#!/usr/bin/env python3
"""Independently decode PNGs; accept exact whole frames from either source run."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from probe_v13_compression import read, require, write


def check(directory, inputs):
    report = read(directory / 'report.json')
    fixture = read(inputs)
    require(report['complete'] and report['input_sha256'] == hashlib.sha256(inputs.read_bytes()).hexdigest(), 'Unbound render report')
    expected = {r['identity']: r for r in fixture['models']}
    require(len(report['records']) == len(expected), 'Incomplete appearance count')
    seen = set()
    frames = 0
    unstable_controls = 0
    for row in report['records']:
        require(row['identity'] in expected and row['identity'] not in seen, 'Unknown or duplicate appearance')
        seen.add(row['identity'])
        require(all(row[k] == expected[row['identity']][k] for k in ('source_sha256', 'candidate_sha256')), 'Changed scene pin')
        controls = [row[k] for k in ('source', 'repeat_source', 'candidate')]
        keys = set(controls[0]['frames'])
        require(len(keys) >= 10 and all(set(c['frames']) == keys for c in controls), 'Incomplete frame set')
        for field in ('camera_size', 'response_schema'):
            require(all(c[field] == controls[0][field] for c in controls), 'Changed camera or material-response mode')
        for key in sorted(keys):
            pixels = []
            modes = []
            for control in controls:
                matches = [Path(p).resolve() for p in control['paths'] if Path(p).stem == key]
                require(len(matches) == 1, 'Missing or duplicated PNG')
                matches[0].relative_to(directory.resolve())
                with Image.open(matches[0]) as image:
                    require(image.size == (512, 512) and image.mode in ('RGB', 'RGBA'), 'Invalid PNG geometry')
                    modes.append(image.mode)
                    data = image.tobytes()
                require(hashlib.sha256(data).hexdigest() == control['frames'][key], 'PNG hash mismatch')
                pixels.append(data)
            require(len(set(modes)) == 1, 'Different PNG formats')
            require(pixels[2] == pixels[0] or pixels[2] == pixels[1], 'Candidate matches neither complete source frame')
            unstable_controls += int(pixels[0] != pixels[1])
            frames += 1
    return {'schema': 1, 'complete': True, 'prototype_only': True, 'production_approved': False,
            'pairs': len(seen)//2, 'appearances': len(seen), 'candidate_frames': frames, 'pixels_exact': True,
            'source_control_frames_differing': unstable_controls,
            'acceptance': 'Exact whole-frame equality to first or repeated source; no pixel tolerance. Same rule as qualify_shared_model_catalog.compare.',
            'renderer': report['renderer'], 'device': report['device'],
            'render_report_sha256': hashlib.sha256((directory/'report.json').read_bytes()).hexdigest(),
            'verifier_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'render_clock_implementation_sha256': report['render_clock_implementation_sha256']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = check(args.directory, args.input)
    write(args.output, result)
    print('NEW_PAIR_PIXELS_OK ' + json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
