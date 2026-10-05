#!/usr/bin/env python3
"""Focused checks against the user's local Ember dump; no ROMFS fixture in Git."""
import argparse
from pathlib import Path
import struct
from extract_sv_ember import inspect_particle, legacy_bntx


def rejected(raw):
    try:
        inspect_particle(raw)
    except (ValueError, struct.error):
        return
    raise AssertionError('Malformed particle source accepted')


def main(source, watergun=None, contacts=None):
    expected = {'ew0052_fire_muzzle': (3, 'fire', 'cpt_2_fire0005'),
                'ew0052_bullet': (4, 'fire_core', 'cpt_2_fire0010'),
                'ew0052_hit': (6, 'fire_Child', 'cpt_2_fire0008')}
    for stem, (count, name, texture) in expected.items():
        path = source / (stem + '.ptcl')
        raw = path.read_bytes()
        parsed, bntx = inspect_particle(raw)
        assert len(parsed['emitters']) == count
        emitter = next(e for e in parsed['emitters'] if e['name'] == name)
        assert emitter['textures'][0] == texture
        adapted = legacy_bntx(bntx)
        assert len(adapted) == len(bntx) and adapted != bntx
        assert path.read_bytes() == raw
        rejected(raw[:20])
        rejected(raw[:-1])
        rejected(raw[:10] + b'\xff\xff' + raw[12:])
        broken = bytearray(raw)
        struct.pack_into('<I', broken, 0x40 + 8, 0)  # ESTA child points at itself.
        rejected(broken)
        broken = bytearray(raw)
        struct.pack_into('<I', broken, 0x40 + 12, 0)  # Non-progressing next section.
        rejected(broken)
        broken = bytearray(bntx)
        table = struct.unpack_from('<Q', broken, 40)[0]
        entry = struct.unpack_from('<Q', broken, table)[0]
        struct.pack_into('<H', broken, entry + 18, 9)
        try:
            legacy_bntx(broken)
        except ValueError:
            pass
        else:
            raise AssertionError('Unsupported BNTX tile mode accepted')
    if watergun is not None:
        expected_water = {'ew0055_muzzle01': 2, 'ew0055_shot01': 13, 'ew0055_hit01': 8}
        for stem, count in expected_water.items():
            raw = (watergun / (stem + '.ptcl')).read_bytes()
            parsed, bntx = inspect_particle(raw)
            assert len(parsed['emitters']) == count
            adapted = legacy_bntx(bntx, allow_bc5=True)
            assert len(adapted) == len(bntx) and adapted != bntx
            try:
                legacy_bntx(bntx)
            except ValueError:
                pass
            else:
                raise AssertionError('BC5 requires explicit opt-in')
        print('SV_WATERGUN_EXTRACTION_OK parts=3 emitters=23 bc5_explicit=true')
    if contacts is not None:
        expected_contact = {'ew0033_at_bgkem': 1, 'ew0033_at_srash01': 1, 'ew0033_df_hit': 6,
                            'ew0010_hit': 5, 'ew0044_tooth': 7, 'ew0044_df_hit': 9}
        for stem, count in expected_contact.items():
            path = contacts / stem.split('_')[0] / (stem + '.ptcl')
            raw = path.read_bytes()
            parsed, bntx = inspect_particle(raw)
            assert len(parsed['emitters']) == count
            assert len(legacy_bntx(bntx, allow_bc3=stem == 'ew0010_hit')) == len(bntx)
            assert path.read_bytes() == raw
            rejected(raw[:-1])
            if stem == 'ew0010_hit':
                for flags in [{}, {'allow_bc5': True}]:
                    try:
                        legacy_bntx(bntx, **flags)
                    except ValueError:
                        pass
                    else:
                        raise AssertionError('BC3 requires explicit opt-in')
                table = struct.unpack_from('<Q', bntx, 40)[0]
                entry = struct.unpack_from('<Q', bntx, table)[0]
                for offset, value in [(entry + 88, 5), (entry + 28, 0xFF)]:
                    broken = bytearray(bntx)
                    broken[offset] = value
                    try:
                        legacy_bntx(broken, allow_bc3=True)
                    except ValueError:
                        pass
                    else:
                        raise AssertionError('Unknown BC3 format/swizzle accepted')
        print('SV_CONTACT_EXTRACTION_OK parts=6 emitters=29 bc3_explicit=true source_unchanged=true')
    print('SV_EMBER_EXTRACTION_OK parts=3 emitters=13 invalid_inputs_rejected=18 source_unchanged=true')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--watergun', type=Path)
    parser.add_argument('--contacts', type=Path, help='SV romfs/effect/battle_ew')
    args = parser.parse_args()
    main(args.source, args.watergun, args.contacts)
