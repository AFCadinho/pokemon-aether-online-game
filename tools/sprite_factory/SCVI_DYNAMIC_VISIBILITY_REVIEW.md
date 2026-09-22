# Dynamic visibility: source audit, not playback approval

## Decision

Keep the active dynamic tracks blocked. The source audit rules out treating the
schema's root-level "frame multiplier" fields as proven clock multipliers, but
does **not** establish the correct dynamic sampling or end-of-stream behavior.
No playback code, species exceptions, assets or approvals change in this step.
The previous visibility result remains 86/88 supported and two explicit holds;
this is feature coverage, not production-ready yield or a new visual review.

## Evidence

Read-only inspection covered all 651 unique mapped TRACM files available in the
same 100-entry identity-hardening inventory, including sources of technically
blocked entries. 644 matched an existing pinned identity-evidence hash; the
remaining seven had no such proof and were inspected only as unapproved source
observations. Every file was hashed before and after inspection.

In **651/651 clips**, root slots 2, 3 and 4 equal, respectively, the numbers of
targets carrying material, visibility and blendshape channels. These are counts
of target tracks, not counts of individual material parameters. The values stay
constant across the selected clips of each examined model despite different
durations. For example, visibility is 4 for Meowth, 7 for Spiritomb and Magearna,
and 12 for Decidueye. These observations strongly support target-count semantics;
they do not independently prove engine implementation details.

The pinned [PokeDocs schema](https://raw.githubusercontent.com/pkZukan/PokeDocs/de20b28d82d5d8b473905eb2c24e5d8b47841ca8/SV/Flatbuffers/animation/tracm.fbs)
names these fields as multipliers and declares the payload as a Boolean vector.
Those labels alone are not a playback specification. Actual payload bytes include
255, 224 and 192; converting each byte to a Boolean loses information. The pinned
local generated Boolean accessor also reads one Boolean per byte, and the local
skeletal importer provides no visibility playback reference.

All **18 dynamic tracks** in this mapped source sample contain fewer packed bits
than clip frames. Eight belong to the two visibility holds in the converted
cohort; ten belong to other source entries, not ten newly converted models.

| Source case | Clip frames | Packed bits available | Raw bytes (one target) |
| --- | ---: | ---: | --- |
| Meowth physical attack, each nail | 91 | 56 | 0, 0, 224, 255, 255, 255, 3 |
| Spiritomb special attack, right eye | 139 | 40 | 255, 255, 0, 0, 192 |
| Spiritomb damage, right eye | 41 | 32 | 0, 0, 0, 240 |
| Spiritomb faint start, right eye | 121 | 24 | 255, 255, 15 |

Spiritomb's corresponding closed-eye streams complement the right-eye bytes.
This supports mutually exclusive states but cannot tell us when to sample them.
Raw FlatBuffers vtables for these eight tracks show no extra dynamic payload
field carrying a sample count or interval; the two timeline metadata fields are
absent (default zero). Vector lengths really count the listed bytes, not 32-bit
words. None of these observations establishes truncation or terminal padding.

## What is deliberately not implemented

- Stretching the available bits over the entire clip.
- Assuming one bit per source frame and holding the final bit afterward.
- Multiplying frame numbers by the root visibility value.
- Substituting fixed eye/nail states or disabling visibility for these species.

Some may produce a plausible-looking preview. That would not independently
verify source timing. A capture using the same guessed decoder as its expected
result would be circular evidence, so no new SCNs or rendered approvals were
produced for these cases.

## Regression evidence and next boundary

`visibility_dynamic_audit.json` records the inventory hash, aggregate counts,
source hashes, clocks and all 18 raw dynamic observations. Tests rebuild synthetic
FlatBuffers envelopes around every observed payload, check byte preservation,
and require an explicit unsupported-clock error. These are safety regressions,
not tests of a newly supported animation format.

Focused validation: 20 visibility tests and 40 SCVI tests pass; `git diff
--check` passes. No runtime behavior changed, so no Godot render or full paired
verification was needed.

Reopen this decoder only with an independently validated visibility reader or a
frame-addressable source reference that establishes sample cadence, bit order,
padding and tail behavior. Meowth and Spiritomb can remain in the blocked queue
while the next useful pipeline work investigates the shared material/effect
groups. Do not expand the cohort or make per-species visual fixes to bypass this
missing evidence.
