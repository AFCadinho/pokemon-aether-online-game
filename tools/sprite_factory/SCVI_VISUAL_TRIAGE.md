# Fixed 100 — visual evidence triage

## Outcome

All **88 technically converted candidates** were inspected across **440 existing
pose images**: idle front/back, special attack, sleep and faint start. Runtime
SCN hashes were verified against their original reports for all 88. No source,
model, converter, shader or approval was changed, and nothing was reexported.

This is a completed **static evidence triage**, not completed moving-animation
review or a production visual gate. The requested fully automatic visual yield
is **not established**. Do not present the technical 88/100 as visual success.

| Static screening result | Count |
| --- | ---: |
| No conspicuous defect in the five supplied poses | 15 |
| Visible issue requiring follow-up | 63 |
| Shading/detail ambiguous at the supplied capture quality | 10 |
| Technical/source holds, not visually reviewable | 12 |

The first row is **15/100** of the fixed cohort and **15/88 (17.0%)** of technical
candidates. These are *static clean candidates*, **not `visual_pass` approvals**.
No full approvals were issued (`visual_pass`: 0/100 and 0/88). That means the gate
has not been completed, **not** that zero models are good. The JSON deliberately
stores the fully automatic yield as `null`, not an invented percentage.

The fifteen static clean candidates are Raichu, Eevee, Jolteon, Articuno,
Lucario, Golduck, Mankey, Primeape, Tauros, Zapdos, Mewtwo, Scizor, Staraptor,
Volcarona and Flapple. They still need motion and placement review.

## Important evidence limitations

The recovered 84-model captures use the existing material-response helper with
paired SubViewports at 512×512. The later Eevee, Charmander, Spiritomb and Moltres
captures use a direct-root viewer with different lighting, framing and resolution.
These are not one standardized comparative render run. In particular, apparent
quality differences between old and new captures cannot be attributed to the
model source alone.

All views are auto-fit. They establish neither relative battle scale nor
grounding/float height. Five still images also cannot establish interpolation,
animation transitions, loop seams, timing perception, intermittent visibility or
the full faint loop. Existing technical pose/timing checks do not replace those
visual checks. No `animation_issue` or `placement_issue` has been asserted solely
from the absence of such evidence.

Each candidate therefore retains `needs_human_review`, plus observed issue labels
where warranted. `material_issue` describes the image symptom, not a proven
material-code root cause. The fixed cohort is deliberately varied, not a random
sample from which a population success rate can be estimated.

## Shared findings, without fixes

### Repeated contours and pose-dependent shading

Many captures show facial or body contours at a different position from the
current pose. Particularly clear examples include Jigglypuff/Wigglytuff's repeated
eyes and arms, Diglett/Dugtrio's extra eye outlines, Voltorb/Electrode's extra eye
shapes, Ditto's small mouth below the attack mouth, and Drifblim's cloud-like
patches across its balloon. Dragonite also has bright seams visible in the
original uncropped idle image, not just in the enlarged review sheet.

This is a shared diagnostic group, not evidence for dozens of individual art
fixes. The existing response bake is documented as idle-baked, and the old viewer
uses paired render targets. Material response/baking and capture synchronization
are plausible investigation areas; **this review does not establish which causes
the symptom**. Do not repair or reject sources individually on this evidence.

### Effect/accessory observations

| Model | Visible observation |
| --- | --- |
| Gastly | Angular overlapping smoke surfaces and dark cutout-like areas obscure the face |
| Charmander | Flame is a coarse solid polygon strip |
| Moltres | Conspicuous polygonal flame surfaces around wings, head and tail |
| Spiritomb | Face unreadable in supplied front/back views; residual effect pieces below sleeping stone |
| Rillaboom | Drumsticks remain suspended beside the sleeping body |
| Decidueye | Arrow stays visible alongside/below the model, including sleep |
| Magearna | Bouquet remains visible in idle, sleep and faint captures |
| Cinderace | Opaque black effect/ball geometry remains beside the feet |

These are eight members of observation groups, not eight proven independent
bugs. Accessory visibility and effect rendering may need distinct investigations.
Spiritomb's face visibility also needs a controlled camera/material check before
deciding whether facing or shading is responsible.

## Previous corrections and blocked queue

All 88 runtime records have an empty `source_repair`; none used the explicitly
authored Bulbasaur vine exclusion in `reviewed_source_repairs.json`. Bulbasaur is
outside this fixed cohort. This provenance field is not proof of an entirely
untouched historical source lineage. Prior generic mapping/material/timing fixes
and catalog-backed identity remapping are not per-species art corrections.
There is no correction-adjusted *full* visual yield to report until the visual
gate has actually passed candidates.

The same twelve holds remain unchanged:

- Missing catalog identities: Silvally, Blacephalon, Marshadow, Stakataka,
  Alcremie, Hydrapple, Terapagos.
- Pikachu: source skeleton-priority discrepancy, still held despite importer A/B
  equivalence in the previously tested clips.
- Grimer and Muk: unsupported lit displacement/animated-normal material family.
- Ceruledge: distinct lit displacement plus fire material family.
- Typhlosion: unsupported auxiliary visibility playback.

## Evidence and next decision

`catalog_100_visual_triage_results.json` records every fixed-cohort member,
per-model observation, labels, runtime/report hashes and all 440 image hashes.
Paths are relative to the retained slot-b root; model/image binaries remain
local and are not copied into version control. Eighteen labelled contact sheets
are at `frontend/.tmp/visual-review-88/sheet-01.png` through `sheet-18.png`.
They crop background and resize for inspection only; original PNGs are unchanged.

Before using this as an automatic-production metric, capture the unchanged SCNs
under one consistent existing runtime presentation, inspect moving clips and
check calibrated placement. A small control set (for example Dragonite,
Jigglypuff, Ditto and Eevee) can first determine whether the shared contour symptom
is also present in the actual presentation. Only then is a full 88-model motion
review meaningful. That follow-up is **not performed in this report**, and fixes
must remain a separate task after review.

Focused validation for this report checks exact cohort membership, 88 runtime
hashes, 440 PNG hashes/dimensions, report hashes, labels, counts and the absence of
runtime approvals/source repairs. No full paired gate or production activation.
