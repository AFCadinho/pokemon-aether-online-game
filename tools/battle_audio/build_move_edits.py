#!/usr/bin/env python3
"""Build short, pitch-preserving 3D edits from the packaged 2D WAVs (ffmpeg).

Run from anywhere. Only writes assets/battles/moves_3d/audio_edited.
These are authored edits of existing audio, NOT extracted Scarlet/Violet audio.
"""
import argparse
import hashlib
import json
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/battles/moves_3d/audio_edited'
# move, source stem, visual role, source start/end, maximum edited seconds.
# Moonblast uses the final rising portion during charge, not its 2s preamble.
# Magical Leaf removes the second repeated 2D volley; Flash Cannon removes its
# delayed second swell. Short attacks retain their initial transient.
EDITS = [
 ('tackle','Tackle','impact',0,.454,.454),
 ('scratch','Scratch','impact',0,.558,.558),
 ('bite','Bite','impact',0,.407,.407),
 ('ember','Ember','launch',0,.55,.38),
 ('watergun','Water Gun','stream',0,.85,.50),
 ('thundershock','Thundershock','stream',0,.85,.45),
 ('thunderbolt','Thunderbolt2','stream',0,.85,.45),
 ('thunderbolt','Thunderbolt1','impact',0,.65,.32),
 ('flamethrower','Flamethrower','stream',0,.75,.50),
 ('bubble','Bubble','stream',0,.85,.48),
 ('icebeam','Ice Beam','stream',0,.85,.50),
 ('razorleaf','Razor Leaf1','launch',0,.65,.34),
 ('razorleaf','Razor Leaf2','impact',0,.45,.28),
 ('quickattack','Quick Attack','launch',0,.544,.36),
 ('shadowball','Shadow Ball1','launch',0,.80,.36),
 ('shadowball','Shadow Ball2','impact',0,.65,.32),
 ('sludgebomb','Sludge Bomb1','launch',0,.399,.30),
 ('sludgebomb','Sludge Bomb2','impact',0,.65,.32),
 ('focusblast','Focus Blast1','launch',0,.85,.42),
 ('moonblast','Moonblast1','charge',1.45,2.08,.24),
 ('moonblast','Moonblast2','impact',0,.70,.34),
 ('iceshard','Ice Shard','launch',0,.65,.35),
 ('poisonsting','Poison Sting','launch',0,.60,.30),
 ('swift','Swift1','launch',0,.434,.30),
 ('swift','Swift2','impact',0,.70,.34),
 ('flashcannon','Flash Cannon','stream',0,.85,.48),
 ('magicalleaf','Magical Leaf1','launch',0,.78,.38),
 ('magicalleaf','Magical Leaf2','impact',0,.45,.28),
 ('waterpulse','Water Pulse','launch',0,.65,.36),
 ('waterpulse','Water Pulse2','impact',0,.50,.30),
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit():
    import struct
    manifest = json.loads((OUT / 'manifest.json').read_text())
    assert len(manifest['entries']) == len(EDITS)
    for name, entry in manifest['entries'].items():
        for field, hash_field in [('source', 'source_sha256'), ('path', 'sha256')]:
            path = ROOT / entry[field].removeprefix('res://')
            assert sha(path) == entry[hash_field], name
        with wave.open(str(ROOT / entry['path'].removeprefix('res://'))) as wav:
            assert wav.getsampwidth() == 2
            raw = wav.readframes(wav.getnframes())
            samples = struct.unpack('<' + 'h' * (len(raw) // 2), raw)
            peak = max(abs(value) for value in samples)
            assert 100 < peak < 32767, (name, 'silent/clipped', peak)
            assert max(abs(value) for value in samples[:2] + samples[-2:]) < 150, name
            duration = wav.getnframes() / wav.getframerate()
            assert abs(duration - entry['duration_seconds']) < .0001, name
            assert 0 < duration <= .56, name
    print('PCM_AUDIT_OK files=30 source_hashes=true edited_hashes=true '
          'non_silent=true clipping=false faded_edges=true')


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = {}
    for move, stem, role, start, end, target in EDITS:
        name = f'PRSFX- {stem}.wav'
        source = ROOT / 'assets/battles/animations' / move / name
        with wave.open(str(source)) as wav:
            end = min(end, wav.getnframes() / wav.getframerate())
        length = min(target, end - start)
        tempo = (end - start) / length
        filters = [f'atrim=start={start}:end={end}', 'asetpts=PTS-STARTPTS']
        # Keep each WSOLA stage <=2x instead of dropping samples at high ratios.
        while tempo > 2:
            filters.append('atempo=2')
            tempo /= 2
        filters += [f'atempo={tempo:.9f}', 'aresample=44100',
                    'alimiter=limit=0.97:level=false:latency=true',
                    f'apad=whole_dur={length}', f'atrim=duration={length}',
                    'afade=t=in:d=0.005',
                    f'afade=t=out:st={max(0, length - .055):.6f}:d=0.055']
        output = OUT / (move + '_' + role + '.wav')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                        '-i', str(source), '-af', ','.join(filters), '-ar', '44100',
                        '-c:a', 'pcm_s16le', '-map_metadata', '-1', str(output)],
                       check=True)
        with wave.open(str(output)) as wav:
            actual = wav.getnframes() / wav.getframerate()
        assert abs(actual - length) < .002
        entries[name] = {
            'role': role, 'path': 'res://' + str(output.relative_to(ROOT)),
            'source': 'res://' + str(source.relative_to(ROOT)),
            'source_sha256': sha(source), 'sha256': sha(output),
            'source_start': start, 'source_end': end, 'duration_seconds': actual,
            'filters': ','.join(filters),
        }
    manifest = {'note': 'Authored 3D edits of existing 2D assets; no original SV audio.',
                'entries': entries}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Built {len(entries)} 3D sound edits; originals unchanged.')
    audit()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Validate packaged edits without writing')
    args = parser.parse_args()
    audit() if args.check else build()
