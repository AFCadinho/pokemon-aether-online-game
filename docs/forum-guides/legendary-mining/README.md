# Legendary Mining forum guide update

Updates the existing [Official Rock Smash Guide](https://forums.pokeaether.com/t/official-rock-smash-guide/59), post 66, under its existing author adinho and public Exploration & Activities category.

The guide labels the expansion from 29 to 55 daily rocks, Legendary Mining Drops and the museum sale as upcoming gameplay additions. Revision 6 adds the eight new map locations and their level distributions, the Route 18 mine entry requirement, daily skill tracking, the updated 75 Aetherite lesson reward, Repel drops and a reachable money example. The former Rocks and Rewards screenshots are replaced by three native interface previews; the two Legendary Mining screenshots remain. No gameplay deployment is performed.

59-guide.md is the exact published Markdown, including Discourse upload references. publication.json records its revision and public verification.

## Native captures

capture.gd renders the museum, the actual sell-all confirmation and the Rock Smash Rewards control without authenticating a player or starting a backend. Its fixture has two Emberite Ore and one of every other ore, worth 445,000 Pokédollars. The rewards fixture uses base chances at Level 100 with no protection bonus.

The three PNGs were visually checked. The two interface screenshots are attached to the guide; the unobstructed museum image is retained for position review.

Run the capture through the assigned slot:

    ops/worktrees/slot-env slot-c -- godot --path .worktrees/slot-c/frontend --rendering-method gl_compatibility --script res://docs/forum-guides/legendary-mining/capture.gd

Forum edits use Discourse UploadCreator and PostRevisor with existing-author, category, duplicate-topic, version and content-digest guards; the rendered preview and saved attachments are checked. No game deployment is performed.

## Rock expansion captures — 22 October 2026

`capture-rock-expansion.gd` renders the real Skills panel from `captures-rock-expansion.json`. The fixture derives its 55 rock records and level-75 item probabilities from the backend development catalog. It uses a synthetic Level 75 player, with the Route 18 surface west rock and mine northwest rock marked complete. It does not authenticate, read account data or start a backend. Any unauthenticated reward request is invalidated before the successful local reward fixture is rendered.

- `04-daily-rocks-route18.png`: eight surface/mine cards, 2/8 area completion and 2/55 overall.
- `05-daily-rocks-rock-tunnel.png`: eight cards with separate floor labels.
- `06-item-rewards.png`: native Items category showing all three Repel types and per-smash probabilities.

All three images were visually inspected before upload. `capture-provenance.json` records source commits, the backend catalog digest and the synthetic state. `publication.json` records revision 6, upload metadata and anonymous public JSON/HTML verification. The existing author, category (20, under Official Guides 13) and topic are preserved.

Reproduce from the assigned slot:

    ops/worktrees/slot-env slot-c -- godot --path .worktrees/slot-c/frontend --rendering-method gl_compatibility --script res://docs/forum-guides/legendary-mining/capture-rock-expansion.gd
