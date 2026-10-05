# Scarlet/Violet move audio: source audit

Investigated 2026-10-05. No runtime audio changes.

## Result

The supplied SV dump includes move audio event references and audio engine
configuration, but no identifiable playable audio payload or Wwise banks were
found. The strongest candidate for original move sounds is **PM_SKILLS.bnk**:
27 of the 28 distinct event names in the latest ten move timelines hash to event
IDs in the public SV PM_SKILLS bank inventory. This is metadata corroboration,
not a successful extraction or listening test.

Current 3D moves therefore continue using their existing 2D sound assets. The
source-textured move effects do not imply that original SV audio was imported.

## Local evidence

Source root: `/home/adinho/Documents/3d_models/SV Every File/romfs`.

- `audio` contains 60 files: 31 `.bin` and 29 `.bfbs` configuration/schema files.
- `audio/fb/engine/init_settings/init_settings_data.bin` names `PM_SKILLS.bnk`,
  `BATTLE_SYSTEM.bnk`, `COMMON.bnk`, `PM.bnk`, `PM_VOICE.bnk`, `BGM.bnk`,
  `ME.bnk`, `DEMO.bnk`, `UI.bnk`, `VIB.bnk`, `ENV.bnk`, `NPC.bnk`, `PROPS.bnk`
  and `PL.bnk`, plus `Patch00.pck`, `LooseMedia.pck` and `Stream.pck`.
- Its schema contains `bankNames`, `asyncBankNames`, `packageNames` and
  `opusDecoderThread`; the BGM schema explicitly names `wwiseEventName`.
- The init configuration SHA-256 is
  `ae84f916bdc71afefb35806a87451382d1b82e12532062f2e32c261e65ab042c`.
- `SV Every File.zip` contains only `SV Every File/SV-Everything.7z`.
  All 290,156 paths listed in that inner archive exist in the loose extraction;
  no audio-extension entries were found in it. Re-extracting that archive will
  not supply the named banks/packages.
- The sibling `Pokémon SCVI Base + DLC Model Dump.rar` (37,541 entries) and
  `LegendsZAPkmnModelDumpWithDLC.rar` (141,516 entries) also have no entries with
  the inspected audio extensions.
- Header inspection covered 6,329 `.bin`, 751 `.arc`, 6,567 `.dat`, 6,450 `.tbl`
  and 6,318 `.bfbs` files in the loose SV RomFS. None began with `BKHD`, `AKPK`,
  `RIFF`, `RIFX`, `OggS`, `FSAR`, `FSTM`, `FWAV`, `BWAV`, `caff` or `fLaC`.

The main archive/loose extension search included `.wem`, `.bnk`, `.pck`, `.wav`,
`.ogg`, `.opus`, `.bwav`, `.bfwav`, `.bfstm`, `.bfsar`, `.nus3audio`, `.acb` and
`.awb`. The sibling archive check covered Wwise and common wave/stream formats.
These are filename and header checks, not recursive decoding of every unknown
compressed container. They cannot prove the absence of arbitrary embedded data.
The supplied dump's version and completeness are not established by its name.

## Event-to-bank evidence

Names below were read directly from
`effect/battle_ew/ewNNNN/ewNNNN.trtml` using `PLAY_[A-Z0-9_]+`.
IDs use lowercase UTF-8, 32-bit FNV-1 (multiply, then XOR), as implemented by
[wwiser's hash helper](https://github.com/bnnm/wwiser/blob/master/wwiser/wfnv.py).

The comparison uses the `EVENT NAMES (PM_SKILLS.bnk)` section of the
[SV name inventory](https://github.com/bnnm/wwiser-utils/blob/08e3068de9852917f354ef91d7d296d174eb986d/wwnames/Pokemon%20Scarlet%20%2B%20Violet%20%28Switch%29.txt).
Downloaded inventory SHA-256:
`f4286cb2e0c2ee3f10612b7197c0dd2cabd84d2d9ad2c7675a7a55ecb336d776`.
Most matching entries are unresolved numeric IDs in that inventory, not already
named events. Matching hashes support the association; local bank inspection is
still required to establish exact media dependencies and account for versions.

| Move | Event prefix | Suffixes | Event IDs, in suffix order |
| --- | --- | --- | --- |
| Shadow Ball | `PLAY_EW0247` | `_01`, `_02`, `_03` | 3286974411, 3286974408, 3286974409 |
| Sludge Bomb | `PLAY_EW0188` | `_01`, `_02` | 2926620683, 2926620680 |
| Focus Blast | `PLAY_EW0411` | `_01`, `_02`, `_03` | 275684242, 275684241, 275684240 |
| Moonblast | `PLAY_EW0585` | `_01`, `_02`, `_03` | 3277806348, 3277806351, 3277806350 |
| Ice Shard | `PLAY_EW0420` | `_01`, `_02`, `_03` | 1119893242, 1119893241, 1119893240 |
| Poison Sting | `PLAY_EW0040` | `_01`, `_02` | 2479552104, 2479552107 |
| Swift | `PLAY_EW0129` | `_01`, `_02` | 2099364330, 2099364329 |
| Flash Cannon | `PLAY_EW0430` | `_01`, `_02`, `_03` | 1766499403, 1766499400, 1766499401 |
| Magical Leaf | `PLAY_EW0345` | `_01`, `_02`, `_03` | 1454506482, 1454506481, 1454506480 |
| Water Pulse | `PLAY_EW0352` | `_01`, `_02`, `_03` | 2825120378, 2825120377, 2825120376 |

All 27 IDs in the table occur in that bank's public event inventory. Swift also
references `PLAY_EW0129_02_M_HIT` (1522028051), which does **not** occur in that
section. Do not silently map it to another event. Event suffixes alone do not
establish charge/launch/impact roles, timestamps, duration or the media filename.

## Material needed and conversion path

Obtain the original audio files from the matching source dump, preserving names
and layout. Keep `Init.bnk`, `PM_SKILLS.bnk`, their dependent banks/media and any
`SoundbanksInfo.xml`, bank `.txt`/`.json`, or `Wwise_IDs.h` metadata. The local
configuration's package names provide concrete search targets:
`LooseMedia.pck`, `Stream.pck`, `Patch00.pck`. They may package media/banks;
their exact contents and location have not been verified here. A loose `.wem`
directory alone may lack the event configuration required for correct playback.

The [wwiser extraction guide](https://github.com/bnnm/wwiser-utils/blob/master/doc/RIPPING.md)
describes this workflow:

1. Extract any Wwise `.pck` with its linked QuickBMS extractor, retaining original
   media IDs and bank names.
2. Load `Init.bnk`, the move bank and required dependencies into wwiser. Supply
   timeline event names through `wwnames.txt` to resolve the known hashes.
3. Generate event TXTP files and decode/listen with vgmstream. Bank events can
   layer several samples, so one `.wem` is not necessarily the complete sound.
4. Start with one move, such as Shadow Ball. Confirm its three event roles by
   listening and inspecting the bank/timeline; reject missing dependencies.
5. Export only reviewed event audio for Godot, record provenance, and align it
   to our current launch/impact clock. Test hit, dodge, cancellation and overlap
   before replacing an existing sound. Native SV timing is not yet decoded and
   our faster reconstructed animations may need different timing.

No audio was extracted or auditioned during this audit: the required payloads
were not found. The public name list contains metadata, not sound samples.
