# Official guide screenshot coverage

All 47 official guides have screenshots. This batch adds 49 image placements to 25 previously unillustrated guides and replaces the outdated Aethernet screenshot. The other 21 guides retain their reviewed images. The complete collection contains 92 image placements.

The screenshots use actual native Godot interface controls in English. Account balances, party details, guild membership and quest progress are illustrative examples, not a live player's state. Relevant captions identify examples. Catalog entries, prices, unlocks and quest text come from the current paired game sources.

Existing guide wording and category placement are preserved. The Kanto walkthrough's four images remain inside its five closed spoiler sections. Changes use Discourse UploadCreator and PostRevisor, with author/category/duplicate checks, revision digest guards, rendered previews and attachment checks.

`publication.json` records revised topics and uploads. `publication-verification.json` records public page/image checks and pixel comparison against local original PNGs. `capture-manifest.json` records files, dimensions, captions, section anchors and SHA-256 hashes. `capture-provenance.json` records revisions and fixture sources; `existing-guide-review.json` records retained topics.

## Reproducing native captures

Use the workspace's assigned slot and isolated Godot environment. From the game workspace, replace the group below with `summary`, `activities`, `economy`, `guilds`, `rentals-loans`, `battles`, `moves-story` or `extras`:

```sh
POKEAETHER_GATEWAY_URL=http://127.0.0.1:9 ops/worktrees/slot-env slot-a -- godot \
  --path .worktrees/slot-a/frontend --rendering-method gl_compatibility \
  --audio-driver Dummy --resolution 640x360 \
  --script res://docs/forum-guides/all-guides/capture/summary.gd \
  -- /absolute/path/to/capture-output
```

A graphical display is required. The capture scripts assert that no player session is authenticated, use a 1920×1080 SubViewport, and crop the rendered native control. Fixtures are local and public; this does not start a game backend or battle. Full viewport originals remain under the slot's ignored `.tmp/all-guides/full` directory. Capture routines do not publish to the forum.

## Guide audit

| Guide | Images | Action |
| --- | ---: | --- |
| [Thieving Guide](https://forums.pokeaether.com/t/thieving-guide/27) | 5 | Existing screenshots reviewed |
| [EV Training Guide](https://forums.pokeaether.com/t/ev-training-guide/28) | 7 | Existing screenshots reviewed |
| [Trainer Rematch Guide](https://forums.pokeaether.com/t/trainer-rematch-guide/29) | 7 | Existing screenshots reviewed |
| [Aethernet Travel Guide](https://forums.pokeaether.com/t/aethernet-travel-guide/30) | 1 | Updated fare screenshot |
| [Battle Damage Calculator Guide](https://forums.pokeaether.com/t/battle-damage-calculator-guide/31) | 1 | Existing screenshots reviewed |
| [Chat and Messaging Guide](https://forums.pokeaether.com/t/chat-and-messaging-guide/32) | 1 | Existing screenshots reviewed |
| [Shiny Tracker Guide](https://forums.pokeaether.com/t/shiny-tracker-guide/33) | 1 | Existing screenshots reviewed |
| [Pokémon Storage and Party Guide](https://forums.pokeaether.com/t/pokemon-storage-and-party-guide/34) | 1 | Existing screenshots reviewed |
| [Friends, Blocking and Private Messages Guide](https://forums.pokeaether.com/t/friends-blocking-and-private-messages-guide/35) | 1 | Existing screenshots reviewed |
| [Guilds and Membership](https://forums.pokeaether.com/t/guilds-and-membership/36) | 1 | Existing screenshots reviewed |
| [Player Trading Guide](https://forums.pokeaether.com/t/player-trading-guide/37) | 1 | Existing screenshots reviewed |
| [Global Boosts Guide](https://forums.pokeaether.com/t/global-boosts-guide/38) | 1 | Existing screenshots reviewed |
| [Fishing Guide](https://forums.pokeaether.com/t/fishing-guide/39) | 1 | Existing screenshots reviewed |
| [Field Moves and Charms Guide](https://forums.pokeaether.com/t/field-moves-and-charms-guide/40) | 1 | Existing screenshots reviewed |
| [Quest Log Guide](https://forums.pokeaether.com/t/quest-log-guide/41) | 1 | Existing screenshots reviewed |
| [Mail and Attachments](https://forums.pokeaether.com/t/mail-and-attachments/42) | 1 | Existing screenshots reviewed |
| [Pokédex Guide](https://forums.pokeaether.com/t/pokedex-guide/43) | 1 | Existing screenshots reviewed |
| [Bag and Hotbar Guide](https://forums.pokeaether.com/t/bag-and-hotbar-guide/44) | 1 | Existing screenshots reviewed |
| [Aether Exchange Guide](https://forums.pokeaether.com/t/aether-exchange-guide/45) | 1 | Existing screenshots reviewed |
| [Trade Evolution Guide](https://forums.pokeaether.com/t/trade-evolution-guide/52) | 4 | Existing screenshots reviewed |
| [Shiny Odds & Multipliers Guide](https://forums.pokeaether.com/t/shiny-odds-multipliers-guide/55) | 1 | Added screenshots |
| [Aether Blessing Membership Guide](https://forums.pokeaether.com/t/aether-blessing-membership-guide/56) | 1 | Added screenshots |
| [Battle Timer Guide](https://forums.pokeaether.com/t/battle-timer-guide/58) | 2 | Added screenshots |
| [Official Rock Smash Guide](https://forums.pokeaether.com/t/official-rock-smash-guide/59) | 2 | Added screenshots |
| [Skills Guide](https://forums.pokeaether.com/t/skills-guide/60) | 2 | Added screenshots |
| [Aether Clash: Guild Duel Guide](https://forums.pokeaether.com/t/aether-clash-guild-duel-guide/70) | 2 | Added screenshots |
| [Ranked Battles and Rating Guide](https://forums.pokeaether.com/t/ranked-battles-and-rating-guide/71) | 1 | Added screenshots |
| [Getting Started in PokeAether](https://forums.pokeaether.com/t/getting-started-in-pokeaether/84) | 2 | Added screenshots |
| [Level Caps, EXP & Traded Pokémon](https://forums.pokeaether.com/t/level-caps-exp-traded-pokemon/85) | 2 | Added screenshots |
| [Pokémon Rentals & Rental Teams](https://forums.pokeaether.com/t/pokemon-rentals-rental-teams/86) | 2 | Added screenshots |
| [Move Maniac & Move Deleter](https://forums.pokeaether.com/t/move-maniac-move-deleter/87) | 2 | Added screenshots |
| [Weekly Bosses: Zapdos](https://forums.pokeaether.com/t/weekly-bosses-zapdos/88) | 1 | Added screenshots |
| [Mounts, Licenses & Mount Boxes](https://forums.pokeaether.com/t/mounts-licenses-mount-boxes/89) | 2 | Added screenshots |
| [AI Sparring Guide](https://forums.pokeaether.com/t/ai-sparring-guide/90) | 1 | Added screenshots |
| [Currencies, Aether Credit Card & Account Binding](https://forums.pokeaether.com/t/currencies-aether-credit-card-account-binding/91) | 2 | Added screenshots |
| [Player Loans: Borrowing & Lending](https://forums.pokeaether.com/t/player-loans-borrowing-lending/92) | 1 | Added screenshots |
| [Clothing, Colours & Aether Atelier](https://forums.pokeaether.com/t/clothing-colours-aether-atelier/93) | 1 | Added screenshots |
| [Battle Replays: Save, Watch & Share](https://forums.pokeaether.com/t/battle-replays-save-watch-share/94) | 1 | Added screenshots |
| [Item Dex: Where to Find Items](https://forums.pokeaether.com/t/item-dex-where-to-find-items/95) | 4 | Existing screenshots reviewed |
| [Guild Bank: Donate, Borrow & Withdraw](https://forums.pokeaether.com/t/guild-bank-donate-borrow-withdraw/96) | 2 | Added screenshots |
| [Guild Training Against Bots](https://forums.pokeaether.com/t/guild-training-against-bots/97) | 2 | Added screenshots |
| [Catching Pokémon & Choosing Poké Balls](https://forums.pokeaether.com/t/catching-pokemon-choosing-poke-balls/98) | 4 | Added screenshots |
| [Pokémon Evolution & Happiness](https://forums.pokeaether.com/t/pokemon-evolution-happiness/99) | 2 | Added screenshots |
| [Understanding Pokémon Stats, Natures & Abilities](https://forums.pokeaether.com/t/understanding-pokemon-stats-natures-abilities/100) | 4 | Added screenshots |
| [Held Items: Choosing & Using Them](https://forums.pokeaether.com/t/held-items-choosing-using-them/101) | 2 | Added screenshots |
| [Kanto Story Walkthrough: Your First Three Badges](https://forums.pokeaether.com/t/kanto-story-walkthrough-your-first-three-badges/102) | 4 | Added screenshots |
| [Wild Encounter Guide: Finding Pokémon](https://forums.pokeaether.com/t/wild-encounter-guide-finding-pokemon/105) | 1 | Existing screenshots reviewed |
