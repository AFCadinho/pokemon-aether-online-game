# Individual hand calibration follow-up

## Result

- Added **18 hand points on nine exact forms**, enabling **37 supported learnset routes**.
- Individually inspected visible idle and native attack poses from front-quarter and side views; far-side occlusion is excluded from approval.
- Inspected one representative strike per form, six fractions and two views. Shared points serve the attack family; this is not a review of every move.
- Spinda uses its raised-hand second physical clip for hand strikes. Its kick routing/action selection stays separate.
- Missing-route forms: **304 → 295**; hand: **231 → 222**; mouth: **81**; foot: **1**. Categories overlap, and these counts exclude outstanding effect presentation work.

## Individual decisions and remaining limits

| Form | Decision / limit |
| --- | --- |
| ampharos-mega | Flipper endpoint follows the source glow. Impact decoration obscures exact contact; whole effect not certified. |
| kangaskhan | Adult hand source works, but the physical clip turns the torso away during the approach. Facing/timing needs a separate contact review. |
| kangaskhan-mega | Adult hand source works. Torso turn, jumping child and child follow-up strike are not resolved by the adult point. |
| marill | Hand origin binds correctly. Body overlaps Pikachu during contact and target impact art is much larger than the source. physical_attack_2 flattening is excluded from marker approval. |
| spinda | Raised-hand physical_attack_2 keeps hands more visible than the head-first bow. Target spacing and the detached drain impact remain pending. |
| pichu | Hand source drives the electric windup. Hand contact remains below the target face decoration; target-height/spacing needs review. |
| plusle | Red hand source drives the electric windup. Target spacing and impact height remain pending. |
| minun | Blue hand source drives the electric windup. Target spacing and impact height remain pending. |
| dusknoir | Refined finger-row source drives the fire windup. Turning attack clip and contact distance remain pending. |

Dusknoir's initial proximal hand proposal was rejected and moved to the distal finger/knuckle row. Kangaskhan's points belong to the adult, independently inspected in normal and Mega forms. The child remains separate anatomy. Marill's flattened second physical clip is outside the marker approval and is not the selected strike clip.

## Focused verification

- Attachment and choreography regression scenes passed, including exact normal/shiny bones, preserved mouth/foot routes and Spinda's hand-only action choice.
- All **18 normal/shiny runtime models** passed binding, model-revision and 21-fraction checks per native action, with zero errors.
- Coverage validation and learnset audit passed; the family backlog was regenerated from current sources.
- Pichu, Mega Kangaskhan and Dusknoir had identical actions, timing and sampled anchors in offline trainer/wild contexts. No live battle or server encounter was played.

[Machine-readable evidence](attack-attachment-hand-review.json) contains per-form definitions, model hashes, marker/effect image hashes, captures and outstanding limitations. Local images are retained under `.tmp/attack-attachments/hand-markers-v451/`, `hand-markers-v454/` and `family-moves-v455/`.

## Next work

Continue individual missing hand/wing/claw calibration by attack family. Keep the contact-presentation issues above in the queue even though these forms now have configured origins. The existing source-model blockers remain unresolved.
