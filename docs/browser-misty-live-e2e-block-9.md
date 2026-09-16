# Browser Misty live E2E — bounded local acceptance

## Result

On 2026-09-16, the rendered browser at `http://127.0.0.1:8062/` completed a
real Misty trainer battle against slot C's disposable Compose runtime. The
browser made the actual trainer-battle and choice-and-resolve calls; no battle
routes or responses were mocked. The account service returned a trainer reward
and `gymBadgeAward.awarded=true`; the subsequent story refresh showed
`challenge_cerulean_gym=completed`. The player remained in the Cerulean Gym.
Seven canvas actions were issued, with no browser page errors or runtime
attestation loss. The final report and screenshots are slot-owned under
`builds/web-misty-real-battle/` (not committed or copied elsewhere).

The browser export receipt is clean frontend commit `0f0436cd2`, PCK SHA-256
`5bb39bfb51ba7e0ab9a5599aa48e67e1335cf8beee832e533fa02802f25f01f0`.
Only export-excluded test files and documentation changed after it. This test
uses a level-28 Kartana with legal moves and a developer-created story
checkpoint at `challenge_misty`; it validates the victory/reward path, **not**
the balance of a normal player's team or a fresh-account playthrough.

The separate existing rendered-browser battle run also passed: three real
dev/wild battle starts, four resolved choices and three teardown markers, plus
Pallet → Player's House → Pallet. It used the Grass fixture at `help_bill` and
does not count as a Misty or fresh-story test. Its report is
`builds/web-real-battle-memory/storyline_e2e_battle_boundary_20260916/report.json`:
`success=true`, `sourceUnchanged=true`, `runtimeLost=false`, zero page errors.

## Failed attempts and guard corrections

The first Misty attempt spawned too far from the leader and never started a
battle. The second reached her but the level-100 fixture was correctly rejected
by the one-badge level cap of 28 (HTTP 409). A level-28 Venusaur started and
played a real battle but lost, returning to Player's House. The original test
only required teardown and briefly produced a false positive. It now requires
the actual reward's Cascade Badge, completed quest and the player still in the
gym. Another fixture iteration failed before login because it supplied a move
not legal at level 28. The final fixture is legal and the strict test passes.
These failed runs are not counted as acceptance evidence.

All real-backend attempts used `ops/worktrees/runtime-lock slot-c` and
`backend/ops/run_web_battle_memory_runtime`. The wrapper attested the slot-C
Compose project and PostgreSQL tmpfs, and each exit printed
`WEB_MEMORY_RUNTIME restored=1`. The final normal gateway returned HTTP 200,
all defined health checks were healthy, no slot-C services remained and normal
PostgreSQL retained its original named persistent volume. No production access,
deployment, push or main promotion occurred.

## Other focused coverage

81 isolated account/story tests passed, including starter, Parcel, Mt. Moon,
Bill, Misty progression and the web fixture contract. Seven focused Godot
checks passed for Player's House introduction, Gary in Oak's lab, story
interaction, checkpoint world state, Mt. Moon layout, Route 4 transition and
Misty's Route 25 date sequence. The earlier rendered browser smoke passed Bill's
meeting/computer/ticket and all 16 Misty-module gameplay maps without runtime
errors. These are complementary regressions, not one continuous journey.

## Remaining release acceptance

There is **no passing single-account, fresh-start browser playthrough** from
father/starter through Oak's Parcel, Brock, Mt. Moon, Bill and a legitimate
Misty win without checkpoints. Side quests and Route 5 boundary behavior are
not covered end-to-end by this new live test. Windows/macOS exports were
packaged and their atlases inspected in block 8, but native playthroughs on
those operating systems remain unverified. Development remains uncertified; the
complete paired pre-promotion gate was not run.
