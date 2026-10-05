# Mega model preparation

2026-10-05 — `mega-model-prefetch`.

## Cause and correction

The desktop presenter already anticipated a small set of ability/stance forms.
Mega forms were only staged by `prepare_mega_form` after the public transformation
event arrived. Its cold path could download/import a model during the turn.

`model_form_dependencies.gd` now supplies the shared list of possible art forms:

- reviewed Mega identities, including X/Y/Z alternatives;
- explicit catalog base-form relationships for exceptional species names;
- the existing ability/stance dependencies, preserved unchanged.

Only reviewed/supported target art is included, retaining the combatant's shiny
flag. The list uses public species relationships, never hidden opponent items,
and does not change Mega eligibility or activate gameplay forms. Already Mega
identities do not request sibling Mega forms.

The presenter includes these dependencies in both the on-demand download request
and its resource loading queue before `await_prepared` returns. The old event-time
preparation remains as a recovery path. Party/area background prefetch also expands
its queue with the same form dependencies; ordinary requested models retain priority.
A Pokédex request alone still downloads only the requested Pokémon.

Downloads persist through the existing verified installation path. No content
index, bundle, hash checks or update selection changed. A first battle can require
more initial downloads. Preloading does not promise zero shader/actor creation
cost on every graphics driver. This change is for desktop 2.5D/3D; browser/mobile
and desktop 2D retain their existing download behavior.

## Focused checks

- `tests/mega_model_prefetch_check.gd`: explicit X/Y/Z, Rayquaza, special base
  names, shiny handling, deduplication, unsupported-form exclusion and background
  queue expansion. A delayed offline provider and synthetic approved scene fixtures
  exercise the real presenter: all six Garchomp base/Mega/Z appearances are loaded
  before battle; both transformations need no additional downloads/imports. A
  cached catalog works with the downloader disabled. Fixture approvals are only
  modified in the test process and restored afterward.
- `tests/wild_3d_opponent_preparation_check.gd`: normal/shiny wild leads, early
  arena reveal, input readiness, download feedback and no interim sprite flash.
- `tests/cached_3d_battle_ready_check.gd`: installed-model fast path, cache reuse,
  continued SHA validation, corruption repair routing and downloader lock handling.

All checks run with `ops/worktrees/slot-env slot-a`. No external network, production
access or content upload is needed. Delivery to players requires a client release.
