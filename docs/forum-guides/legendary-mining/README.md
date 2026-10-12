# Legendary Mining forum guide update

Updates the existing [Official Rock Smash Guide](https://forums.pokeaether.com/t/official-rock-smash-guide/59), post 66, under its existing author adinho and public Exploration & Activities category.

The gameplay changes are local development for the next release. The guide explicitly labels the new ore drops, rock tiers, protection and museum buyer as upcoming and not deployed yet. Existing guide sections and both original screenshots remain.

59-guide.md is the exact published Markdown, including Discourse upload references. publication.json records its revision and public verification.

## Native captures

capture.gd renders the museum, the actual sell-all confirmation and the Rock Smash Rewards control without authenticating a player or starting a backend. Its fixture has two Emberite Ore and one of every other ore, worth 445,000 Pokédollars. The rewards fixture uses base chances at Level 100 with no protection bonus.

The three PNGs were visually checked. The two interface screenshots are attached to the guide; the unobstructed museum image is retained for position review.

Run the capture through the assigned slot:

    ops/worktrees/slot-env slot-c -- godot --path .worktrees/slot-c/frontend --rendering-method gl_compatibility --script res://docs/forum-guides/legendary-mining/capture.gd

Forum edits use Discourse UploadCreator and PostRevisor with existing-author, category, duplicate-topic, version and content-digest guards; the rendered preview and saved attachments are checked. No game deployment is performed.
