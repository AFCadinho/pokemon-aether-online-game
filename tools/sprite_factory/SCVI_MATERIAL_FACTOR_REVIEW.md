# Material/effect holds: controlled interventions

## Outcome

47 isolated Forward+/Vulkan captures establish two different problems, not one
species-level correction. No SCN, GLB, approved package or visual-pass count is
changed. The only implementation change is a native-source refraction gate.

**Spiritomb's face exists behind an incorrectly opaque shell.** Removing only
the source Transparent/TransparentInner surfaces exposes the green facial
geometry. This is a causal diagnostic, not an acceptable final material: it also
removes the purple body. Visibility remains fixed to the source idle values in
both captures. The dynamic visibility hold is separate.

**Gastly's large faceted silhouette is driven by the current displacement
approximation.** Setting displacement height to zero makes the shell round, not
correct smoke. Changing depth prepass, opacity or color UV alone does not remove
the deformation. No guessed replacement displacement is shipped.

## Native refraction must not pass an opaque-material gate

The native material records identify `Transparent` + `TransparentInner`,
`RefractionMode=Thin`, premultiplied-alpha blending and Fresnel alpha parameters.
The two affected surfaces become opaque in the historical export. The response
pack validates the resulting StandardMaterial3D, and its runtime shader writes
RGB/roughness/specular without alpha. That downstream check cannot establish
that the original transparent graph was preserved.

`material_profiles.classify()` now rejects native Transparent/TransparentInner
shaders or an explicitly enabled RefractionMode before export. It returns a
named `scvi_transparent_refraction_unimplemented` reason. This uses no species,
resource IDs or surface-name rules. It also rejects such semantics when an
otherwise recognized effect signature is present. Eye/EyeClearCoat materials
are not rejected merely for a premultiplied-alpha label; their existing graph
validation remains required.

Rechecking the exact source materials of all 88 historical conversions changes
only Spiritomb's material preflight from pass to hold (two surfaces). The other
87 results are unchanged. Original source hashes match the jobs and all 88 GLB
and SCN hashes still match their reports. This is not a fresh conversion run or
a claim that 87 are visually ready. Spiritomb was already on visual and dynamic
visibility holds; historical reports are not rewritten.

## Smoke/fire experiment

Same three existing SCNs: Gastly (NonDirectional/UV2), Charmander (Unlit/UV1),
Moltres (Unlit/UV2, three materials). Each has five modes and three effect times
(0, 0.5, 1 seconds), for 45 captures. The idle pose, camera, lighting and all
other shader parameters are held constant. Experimental changes occur only in
memory, after the existing two-pass response setup; effect shells remain absent
from the irradiance copy as in the baseline.

| Single intervention | Observation |
| --- | --- |
| Remove alpha depth prepass | Small pixel changes; does not eliminate the principal shell deformation. |
| Set displacement height to zero | Strongly changes Gastly's silhouette to a round shell; also changes both fire cases. Removing displacement is not a smoke/fire solution. |
| Sample baked color with static UV | Changes moving color patterns, not the main silhouette. Does not prove that static UV is the source convention. |
| Force opacity to one | Gastly's shell obscures the face. Charmander's captures are pixel-identical to baseline; its mask alpha is zero throughout. Moltres changes only slightly. |

The source displacement maps are grayscale, not three-axis vector displacement.
The current centered normal-displacement formula is still an unverified
approximation. Gastly's source displacement height is about 0.3; zeroing that
uniform isolates its influence but does not establish the correct direction,
units, midpoint, topology requirements or timing. Source `Opaque` labels alone
are not a justification for forcing these reconstructed effects opaque.

Direct inspection covered all five Gastly modes at 0.5 seconds, Charmander's
baseline/static-color pair, Moltres's baseline/static-color pair, and both
Spiritomb captures. Pixel-difference counts for all 45 smoke/fire captures are
recorded as diagnostic measurements, not a quality score. These are one-view,
fixed-pose interventions, not full animation, shiny or gameplay certification.

## Evidence and checks

`material_factor_results.json` binds 88 source preflight results and 47 image
hashes to their original runtime hashes and local probe/report hashes.

- `.tmp/material-factor-probe-01/`: 45 smoke/fire images.
- `.tmp/transparent-factor-probe-01/`: source-idle visibility, before/after
  removal of the two native transparent surfaces from both render passes.
- 43 SCVI, 20 visibility and 5 effect tests pass (68 total).
- Three new source-profile tests cover shader/name independence, precedence
  over recognized effect profiles and preservation of the eye/clearcoat path.

No game-client behavior changed, no player-facing changelog entry is needed,
and no complete paired verification or release is performed.

## Next bounded implementation

Keep the refraction source gate until a generic transparent-shell response is
implemented and independently reviewed. Do not hide the shell permanently.
For smoke/fire, review the displacement reconstruction against a trusted source
reference before changing the formula; do not tune a height per Pokémon. The
current cohort is sufficient. No larger batch or individual manifests are needed.
