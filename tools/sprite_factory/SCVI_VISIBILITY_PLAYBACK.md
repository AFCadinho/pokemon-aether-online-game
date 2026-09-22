# Generic source visibility playback — first supported subset

> Follow-up: `SCVI_VISIBILITY_VARIANTS.md` resolves the fifteen variant-target
> holds through catalog and mesh-table membership. Visibility preflight is now
> 86/88; the two dynamic-clock holds remain. Historical counts below are retained.

## Implemented

New identity-bound SCVI exports emit a GLB-hash-bound `visibility` payload.
`prepare_battle_3d_runtime.gd` binds it into native AnimationPlayer Boolean
property tracks before saving the self-contained SCN. There is no separate
runtime clock, per-species branch, permanent accessory exclusion or new network
contract. Existing model packages are not modified or automatically replaced.

Supported storage: fixed Boolean and explicit framed-8/framed-16 bitsets.
Framed values use least-significant-bit-first packing with one bit per frame key;
unused padding must be zero. The source's explicit frame indices are divided by
its own FPS. Root duration is `(frame_count - 1) / fps`, and both duration and loop
flag must match the skeletal clip. Unsupported timeline metadata is rejected.

The bit interpretation is grounded in the observed source bitsets and tested
against explicit frame transitions: Decidueye's cap/cloak and wing tracks have
complementary `[5]`/`[2]` payloads at frames `[0,28,125]`; Magearna switches body
and ball using `[1]`/`[2]` at frames `[0,54]`. The independently encoded synthetic
fixtures exercise bit order and byte boundaries. Framed-16 support has synthetic
coverage; the five live controls exercise fixed and framed-8 tracks.

**Dynamic Boolean storage remains unsupported.** Its sample clock and truncated
payload semantics are not established by the raw bytes. The exporter raises an
explicit error rather than stretching bits over a clip or holding an inferred
last value. This is a supported-subset implementation, not complete TRACM parity.

## Binding and lifecycle guarantees

- Each clip is bound to the identity inventory's exact source-file hash and
  skeletal source-action name, not a species identifier.
- The source shape target maps to the exact exported mesh-node name by removing
  the structural `_shape` suffix. No fuzzy matching or variant-ID replacement.
- Every mesh must have exactly one track in every exported clip. Missing,
  duplicate, ambiguous and additional target references are explicit holds.
- Every track starts at time zero. Clip changes therefore establish a complete
  visibility state instead of inheriting a previous action's accessories.
- Discrete Boolean keys never blend into partial visibility. Loop restart follows
  the existing AnimationPlayer clock; `RESET` and initial mesh state use idle's
  first key. Actor-level hiding remains separate from mesh visibility.
- Godot validates the entire payload before changing any animation. Existing
  visibility tracks or RESET visibility are never overwritten silently.
- The current material-response helper already mirrors mesh visibility into its
  light-copy actor. No new helper or polling loop is required.

The new payload travels in `export.json` alongside material-response/effect data.
When assembling a stage report, retain `visibility` just like those fields.
Older reports without visibility remain usable for historical comparisons; their
existence does not imply that visibility was implemented or approved for them.

## Same-cohort preflight, no upscale

All **88 previous technical candidates** were checked against their existing,
unchanged GLBs and current source metadata:

| Visibility-only preflight | Count |
| --- | ---: |
| Supported encoding, exact clock and complete mesh binding | 71 |
| Unresolved target names associated with another variant | 15 |
| Unsupported dynamic visibility clock | 2 |

The two dynamic holds are Meowth and Spiritomb. The fifteen binding holds are
Raichu, Gyarados, Eevee, Hypno, Scyther, Magikarp, Sudowoodo, Wooper, Quagsire,
Murkrow, Scizor, Heracross, Donphan, Staraptor and Garchomp. These are **new
visibility-feature coverage results**, not a replacement for the historical
79/100 visual screening or a claim that those fifteen models are visually bad.
No catalog approval states were changed. The existing twelve technical/source
holds outside the 88 are untouched.

## Runtime controls and evidence

Rillaboom, Decidueye, Magearna and Cinderace plus Dragonite as a control were
converted into new local SCNs using unchanged source GLBs and materials. This
is an actual converter/serialization run, not the earlier in-memory visibility
intervention. All five reload successfully as self-contained scenes.

The corrected Forward+/Vulkan runtime renderer captured **35 native clips,
1,149 motion frames and 50 static views**. Each motion frame asserts every mesh's
visibility against the exported source keys at the player's current clip time.
There were **zero visibility assertion failures and zero bone-pose mismatches**.
Idle, sleep and faint loops run for two cycles. Selected visual checks confirm:

- Rillaboom's suspended sticks disappear during sleep.
- Decidueye's idle arrow disappears while the correct wing form appears during
  its special attack.
- Magearna changes from its body to the closed form across source frame 54 and
  remains closed in faint loop, without the bouquet.
- Cinderace's idle black effect is absent.

This is targeted validation, not full battle/shiny/arena certification and not
a manual inspection of every captured frame. Spiritomb's facial material problem,
the smoke/fire profiles and Dugtrio's source-pose question are not fixed here.

Focused tests cover Python decoding/export gates; Godot seek boundaries, clip
switches, looping, RESET, scene serialization, independent instances and atomic
rejection. The converter integration test also checks publication boundaries and
an arbitrarily renamed fixture species, proving there is no species allowlist.

`visibility_playback_results.json` records the 88 preflight results, five new SCN
hashes and diagnostic artifact hashes. Local evidence:
`.tmp/visibility-stage-01.json`, `.tmp/visibility-runtime-01/` and
`.tmp/visibility-native-images-01/`. None is installed into the player catalog.

## Next bounded investigation

Resolve variant target membership from source metadata before extending mesh
binding; do not replace `_01_` with `_00_` or add fifteen manifests. Establish
dynamic sample-clock semantics independently before enabling that encoding.
Keep the four repaired accessory models as review candidates, not automatic
production approvals. No larger cohort is needed for either question.
