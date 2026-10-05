# Short audio edits for native 3D moves

The 23 supported native moves now use 30 short edits of the existing 2D WAV
sources. Bubble Beam shares Bubble's edit. These are **not original SV sounds**;
original game sound banks are still missing (see [source audit](sv-move-audio-research.md)).
The 2D catalogs, source WAVs, common status/item sounds and damage sounds are
unchanged.

## Editing and playback

`tools/battle_audio/build_move_edits.py` declares each source interval, target
length and role. Run it with Python 3 and ffmpeg to regenerate
`assets/battles/moves_3d/audio_edited`. The manifest records original/output
SHA-256 hashes, source intervals and complete filter chains. Generation retains
pitch using chained atempo stages of at most 2x, with short fades at both ends;
a peak limiter prevents edit-induced clipping without automatic gain. Cuts
remove repeated volleys and long tails.

Examples (before runtime clock envelopes):

| Sound | Original | Edited | Role |
| --- | ---: | ---: | --- |
| Flash Cannon | 3.224 s | 0.480 s | Beam release |
| Moonblast 1 | 2.366 s | 0.240 s | Charge, using the final rising portion |
| Moonblast 2 | 2.166 s | 0.340 s | Confirmed impact |
| Magical Leaf 1 | 2.193 s | 0.380 s | One release volley |
| Shadow Ball 1 / 2 | 1.004 / 0.987 s | 0.360 / 0.320 s | Release / impact |

Move audio plans replace only reviewed source names with edited paths. Catalog
volume and pitch remain intact. Charge starts at action frame zero and ends at
launch; release starts at launch; impact starts at the target contact marker.
A short overlap/tail is bounded to the native animation clock, with a volume
fade before the endpoint. This also bounds short/fast species clips. Playback
speed changes the cue/envelope timing without multiplying sample pitch.
Samples do not loop/stretch to fill a slower animation window; they may finish
earlier at slow speed. At high speeds the envelope can cut a sample shorter.

The router supplies the same confirmed-hit flag as the VFX. Dodge/block/immune
presentations omit impact-only clips, including physical contact clips; charge
and projectile release sounds still play. Missing sound resources remain
optional. Expired cues are skipped on clock jumps. Cancel/replacement stops
streams immediately. Completed move nodes do not drain independently into the
next action. Existing common-effect audio retains its normal tail behavior.

Unknown catalog sound names have no 3D fallback to the old long WAV. The coverage
check requires explicit edits for every sound currently used by these 23 moves.

## Validation and review

Focused checks:

- `tests/move_audio_edits_check.gd`: all 23 moves, 3 native clip lengths, resource
  decoding, source-plan immutability, phase/end bounds and key regression lengths.
- `tests/battle_audio_playback_check.tscn`: fade, pause/resume, speed without pitch
  change, hit suppression, expired cues, cancellation and normal common playback.
- `tests/battle_move_effects_3d_check.tscn`: four actor slots, router hit/dodge and
  impact/recovery ownership, empty audio ownership after recovery.
- `tests/batch_four_moves_3d_check.tscn`: latest ten moves, paired emitters and
  hit/miss/block geometry, audio and cancellation integration.
- WAV audit: source/output hashes, duration, non-silent PCM, no full-scale
  clipping and quiet first/last samples.

Subjective sound approval is pending. Review especially Moonblast's charge,
Flash Cannon, Magical Leaf and fast misses. Open the existing batch preview with
`--moves --audio-review` through the assigned slot's `slot-env`. Its move picker
also includes the previously approved moves.
