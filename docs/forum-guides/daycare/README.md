# Official Daycare guide

Published as `adinho` in public **Official Guides** (category 13):
[Daycare — Training, IVs and Natures](https://forums.pokeaether.com/t/daycare-training-ivs-and-natures/113).

The English guide covers the Route 5 hub: Party admission, six parallel training
places, independent EXP/EV targets, stored EVs, story caps, pricing, collection,
Aethering compatibility and random IVs, optional Wings, Donor consumption,
Nature eligibility, original/effective Nature, default prices and the account's
rolling seven-day limit. All three service windows share the same public URL in
`scripts/core/external_links.gd`. Labels and tooltips are localized in en, nl, pt_BR and zh_CN; the tooltip
identifies the guide language as English.

The opening upcoming-update notice is deliberate: these services are prepared
on local development, while the approved frontend `main` at `edaf9480d` does
not contain `scripts/ui/daycare_popup.gd`. This task publishes forum content;
it does not deploy gameplay or promote a release.

## Publication and verification

- `guide.md` is the exact published Markdown, including upload references and
  Discourse's trimming of the final newline. Its SHA-256 matches the saved post.
- `publication.json` records topic/post IDs, public URL, author, category,
  upload references, rendered headings and anonymous verification.
- The public HTML, topic JSON and four original images returned HTTP 200.
  Downloaded image pixels matched the reviewed local captures exactly.
- `reviewed-draft.sha256` records the pre-upload-reference draft hash.
- Before publication, the running Discourse container, public category, active
  author and absence of an existing Daycare/Aethering guide were checked.
- Publication used Discourse `UploadCreator` and `PostCreator` as the application
  user. No direct database updates, forum configuration changes or game
  production mutations were used. Do not rerun creation: topic 113 exists.

## Native screenshots

The four PNGs under `0/` use the real service scenes and **illustrative local
fixtures**. No player session, account service, purchase, treatment, training
order or Donor consumption was used. The folder number is a capture target,
not the public topic ID. All four images were visually reviewed. The Aethering
capture is scrolled to show all six outcomes and the Wing requirements.

Run from the game workspace, substituting the assigned slot and output path:

```sh
POKEAETHER_GATEWAY_URL=http://127.0.0.1:9 ops/worktrees/slot-env slot-a -- godot \
  --path .worktrees/slot-a/frontend --rendering-method gl_compatibility \
  --audio-driver Dummy --windowed --resolution 640x360 \
  --log-file /absolute/slot/runtime/test-logs/daycare-capture.log \
  --script res://docs/forum-guides/daycare/capture.gd \
  -- /absolute/path/to/capture-output
```

A graphical display is required. `capture-provenance.json` records example-data
status, UI source hashes, base revisions, image hashes and native control sizes.
`captures-daycare.json` is the capture script's output manifest.

## Gameplay sources and focused checks

Facts were checked against the paired backend's `docs/daycare_training.md`,
`docs/aethering_backend.md`, `docs/nature_specialist.md`,
`account-service/daycare_services.py`, `account-service/aethering_services.py`,
`account-service/nature_specialist_services.py`,
`account-service/game_settings_services.py` and
`pokemon-data/data/shops/kanto/daycare_wing_merchant.json`, plus the native UI.
These sources govern gameplay; the forum does not define server rules.

All four focused Godot checks passed through the assigned slot environment:

- `tests/daycare_training_check.gd`
- `tests/aethering_ui_check.gd`
- `tests/nature_specialist_check.gd`
- `tests/daycare_guide_check.gd`

The new check verifies all three buttons, their shared callback, translated
labels/tooltips, visible titles and button bounds in four locales at 1280×960
and 520×700. It never launches a browser. Existing shared 3D model verification
warnings were emitted by an unrelated autoload; these checks do not certify
3D model delivery. No complete paired certification or authenticated end-to-end
service transaction was run for this documentation/link change.
