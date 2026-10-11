# Reviewed attack surfaces: family routing follow-up

## Result

- Linked existing individually reviewed surfaces for **30 exact forms**; no marker coordinates were added or moved.
- Inspected **37 representative effects**, six sampled fractions and two views, plus the initial side/rear inspection pass.
- Generic recipe beams share native action/timing by family. Dedicated presenters retain explicit exceptions.
- Added **73 configured supported learnset routes**. Missing-route forms: **323 → 304**; mouth requests: **111 → 81**. Hand: **231**, foot: **1** (categories overlap). Eleven changed forms still have missing hand routes.

This is a bounded routing review, not completion of all Pokémon or all animation presentation. [Machine-readable decisions and evidence](attack-attachment-family-routing-review.json) retain each preview path, hash, native action, timing and model hash. Preview images are local review artifacts under `.tmp/attack-attachments/family-moves-v448/`.

## Individual decisions

| Form | Generic mouth request uses | Decision |
| --- | --- | --- |
| brambleghast | face | Front twig below the eyes. Rejected emission during the spin; charge starts at .67 and beam launches at .70 after the face returns forward. |
| bramblin | face | Lower front twig below the floating eyes. Beam starts after the roll has settled; no casting through the rotating branch cage. |
| cubone | muzzle | Reviewed lower skull muzzle. Reduced Mud-Slap size and arc leave the skull visible at release. |
| darkrai-mega | face | Lower face below the white crest, independently measured for this form. Special-attack beam exits forward; crest can hide the early charge from the rear. |
| diglett | face | Front surface below the nose; late special-attack release reuses the reviewed sludge window. This is a surface casting point, not an exposed mouth cavity. |
| diglett-alola | face | Own front surface below the nose; late special-attack release. Hair and rock base are excluded. |
| dugtrio | face_primary | Single foreground head for generic casting and Mud-Slap; physical release after the forward bow. Existing explicit multi-head sound routes stay intact. |
| dugtrio-alola | face_primary | Own foreground head, with hair clear of the late physical release. Existing multi-head sound choices are retained. |
| glimmora-mega | spike | Long front central spike tip, ahead of the flower petals; narrow special-attack beam follows the tip. |
| golisopod | face | Front face between antenna roots. Special beam clears the opening as the arms spread. Bug Bite uses the face route; precise target contact spacing remains outside this approval. |
| golisopod-mega | face | Own purple front face point; beam follows it below the upper appendages. Upper claws and possible arm nozzles are not certified here. |
| magnemite | eye | Central eye; narrow beam uses the already reviewed special clip and stays between the magnets during release. |
| magneton | face | Three eye points remain separate. Volt Switch emits three beams and Screech uses three sound sources; front views distinguish these from the magnets. |
| magnezone | eye | Central red lens. Physical clip keeps the lens facing the target; generic beams use its existing reviewed timing. |
| mimikyu | casting | True-body casting surface below the costume head, not the painted Pikachu mouth. Beam and reduced Shadow Ball use this point. |
| mimikyu-busted | casting | Independently reviewed true-body casting surface; native special clip lifts the costume head temporarily. Reduced Shadow Ball and beam remain below it. |
| necrozma | face | Front prism below the colored eyes. Rejected special clip turns the front away; physical clip exposes the prism during the main beam window. Sweeping arms can occlude early windup. |
| nosepass | nose | Nose tip casting surface. Reduced Mud-Slap forms in front of the tip, not above the stone head. |
| poltchageist | spirit | Generic beams use the extended spoon tip; dedicated Shadow Ball uses the spirit spiral above the pot. The reduced effects follow the separate native surfaces. |
| regice | face | Face-dot center. Reduced Mud-Slap uses the exposed front panel while arms move to either side. |
| regieleki | face | Face-dot center with reduced beam width. Native electrical arm strands can cross the viewing line; this approves the origin, not all strand clearance. |
| regigigas | face | Center of the yellow face strip, not either shoulder gem. Reduced Mud-Slap remains attached during the forward lean. |
| regirock | face | Face-dot panel between the shoulder rocks. Reduced Mud-Slap stays on the front surface. |
| registeel | face | Face-dot center on the dark front panel. Reduced Mud-Slap follows it while the hands lift nearby. |
| sandy-shocks | eye_upper | Upper central eye selected as one source. Physical clip exposes the eye; rejected special clip moved the magnets across the beam path. |
| scovillain-mega | mouth_red | Own red mouth for generic beams and Flamethrower using physical_attack; Solar Beam explicitly uses the green mouth and special_attack. Narrow effects remain within the respective open lips. |
| voltorb | face | Front seam below the eyes as a casting surface. Narrow generic beam follows the forward-facing special clip. |
| voltorb-hisui | face | Own front seam surface; physical clip and later .43 release avoid casting during the downward roll. |
| wo-chien | face | Front leaf cluster beneath the eyestalks as a casting surface, not an oral cavity. Narrow beam follows the lowered face. |
| wugtrio | muzzle | Reviewed three muzzle points; Mud-Slap presenter uses the primary source. Smaller projectile and lower arc expose the head at release; this does not certify three-projectile choreography. |

## Focused verification

- Both attachment and choreography regression scenes passed, including move-over-family precedence, unavailable actions, exact action matching, shiny routing, all four actor slots, cancellation and substitutes.
- All 60 normal/shiny runtime models passed binding, native action availability, reviewed model hash and 21-fraction pose checks with zero errors.
- Coverage and learnset audits passed across 1,200 forms; backlog regenerated from the current sources.
- Eight representative effects had identical actions, timing and sampled anchors in offline trainer and wild stage contexts. No live NPC/wild encounter or server battle preparation was exercised.

## Remaining limits

- Golisopod Bug Bite contact spacing still needs a target-oriented pass.
- Regieleki arm strands and Necrozma windup can obscure the source; no complete mesh-clearance certification.
- Mimikyu dedicated Shadow Ball retains its existing star decoration after launch.
- No live NPC or wild encounter was played; battle-kind comparisons use the offline stage.
- Generic mouth aliases are deliberate surface alternatives where the model has no visible oral cavity.
- Existing geometry blockers and missing limb/anatomical routes remain tracked separately.

Next: assess the remaining 81 mouth and 231 hand requests by attack family. Prefer linking already reviewed points where the anatomy supports it; concealed or unsuitable parts require a specific alternative or calibration. The count does not include all remaining effect timing and contact work.
