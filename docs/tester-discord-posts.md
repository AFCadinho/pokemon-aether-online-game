# English Discord posts for testers

These messages can be copied directly into Discord. Replace anything between
`[SQUARE BRACKETS]` before posting. Delete a line if it does not apply.

The messages intentionally split the testing week into smaller posts. This
makes assignments and results easier to follow than one very long announcement.

## Post 1 — Announce the testing week

```text
🧪 POKEAETHER TESTING WEEK

From [START DATE] until [END DATE], we are pausing new feature work and focusing entirely on testing the game we already have.

Our goal is to find progression blockers, lost or duplicated data, battle problems, unclear instructions, multiplayer issues, and anything else that makes the current game difficult to play.

You do not need technical knowledge to help. Please play like a normal player, follow your assigned test journey, and report anything that behaves differently from what you expected.

Build: [BUILD/VERSION]
Environment: [TEST SERVER/ENVIRONMENT]
Download: [DOWNLOAD LINK]
Testing guide: [TEST GUIDE LINK]
Bug reports: [BUG REPORT CHANNEL/LINK]

Please react with ✅ if you can participate this week. Thank you for helping us make the current PokeAether experience more reliable!
```

## Post 2 — What every tester needs to know

```text
📋 BEFORE YOU START TESTING

Please follow these rules during the test week:

1. Use only the test account assigned to you.
2. Write down the game build, your operating system, and your screen resolution.
3. Follow the steps of your assigned test in order.
4. Give every test one result: PASS, FAIL, BLOCKED, or SKIPPED.
5. Create a separate bug report for each problem you find.
6. Add a screenshot or short video whenever it helps explain the problem.
7. Never post your password, email address, session details, private messages, or another player's private information.
8. Do not intentionally crash, spam, or overload the server.
9. Do not test real-money purchases or risk valuable items unless the test lead explicitly asks you to.

Result meanings:
✅ PASS — Every step worked and the final result was correct.
❌ FAIL — At least one step failed or produced the wrong result.
⛔ BLOCKED — Another problem prevented you from finishing the test.
⏭️ SKIPPED — The test was not assigned or the feature was unavailable.

If you are unsure whether something is a bug, report it anyway and describe what confused you.
```

## Post 3 — Individual assignment

Send this as a direct message or tag the tester in the testing channel.

```text
Hi [TESTER NAME]! Your PokeAether test assignment is ready.

Test card(s): [E2E NUMBER AND NAME]
Account/character: [ASSIGNED TEST ACCOUNT OR CHARACTER]
Build: [BUILD/VERSION]
Deadline: [DATE AND TIME]
Instructions: [TEST GUIDE LINK]
Report bugs here: [BUG REPORT CHANNEL/LINK]

When you finish, please reply with:

Result: [PASS / FAIL / BLOCKED / SKIPPED]
Bug report links:
Time spent:
Anything confusing, even if it technically worked:

Please contact [TEST LEAD] if your account, build, or starting situation is not correct. Have fun testing!
```

## Post 4 — Day 1: launcher and new-player journey

```text
🌱 TESTING DAY 1 — NEW-PLAYER JOURNEY

Today's focus is the experience from opening the launcher to catching and healing your first Pokémon.

Please test:
• Launcher update, news/server status, and starting the game
• Account creation and login, including one incorrect-password attempt
• New Game warnings and character creation
• Movement, collision, NPC interaction, and opening/closing menus
• Following the Quest Log to Professor Oak
• Choosing a starter and completing the first required battle
• Travelling from Pallet Town through Route 1 to Viridian City
• One wild battle, catching a Pokémon, checking the Pokédex, and healing at a Pokémon Center
• Closing the game, logging in again, and checking that progress remains correct

Pay special attention to anything that leaves a new player confused or unsure where to go. If you are stuck for more than five minutes, report where and why.

Assigned cards: E2E-01 to E2E-04
Build: [BUILD/VERSION]
Instructions: [TEST GUIDE LINK]
Results: [RESULTS CHANNEL/LINK]
```

## Post 5 — Day 2: current story and saved progress

```text
🗺️ TESTING DAY 2 — STORY AND SAVED PROGRESS

Today's goal is to play through the current Kanto story using only the Quest Log, NPC dialogue, and signs for directions.

Please continue through the available journey:
• Viridian Forest and Pewter City
• Brock and the first Gym reward
• Route 3 and Mt. Moon
• Cerulean City
• Route 24 and Nugget Bridge
• Route 25 and Bill's quest
• The available Cerulean Gym story and Misty battle

After every major step, check the Quest Log, Bag, Trainer Card, badges, rewards, and access to the next area. Rewards and story events must happen exactly once.

Before logging out, write down your map, Party, money, important items, quests, and badges. Log back in and compare everything.

If your build ends before one of these sections, report the last quest objective you successfully completed and mark only the unavailable steps as SKIPPED.

Assigned cards: E2E-05 and E2E-06
Build: [BUILD/VERSION]
Instructions: [TEST GUIDE LINK]
Results: [RESULTS CHANNEL/LINK]
```

## Post 6 — Day 3: battles, inventory, world, and skills

```text
⚔️ TESTING DAY 3 — CORE GAME SYSTEMS

Today's tests are being divided between testers. Please complete only the cards assigned to you.

Battle testing:
• Win a wild battle and a Trainer battle
• Switch Pokémon and use a battle item
• Continue after a Pokémon faints
• Check XP, level-ups, new moves, rewards, and the return to the overworld

Inventory and Storage testing:
• Bag categories and using an item
• Held items
• Moving Pokémon between Party and Storage boxes
• Search, filters, Pokémon Summary, Pokédex, and Item Dex
• Logging in again to check that everything was saved

World testing:
• Doors and map transitions in both directions
• Collision around water, trees, stairs, bridges, edges, and narrow paths
• NPCs, signs, followers, mounts, music, weather, and day/night
• Available field moves and the message shown when requirements are missing

Quest and skill testing:
• Accepting, progressing, and completing a sidequest
• Checking every listed reward
• Available Fishing, Thieving, and Rock Smash actions
• XP, cooldowns, success, failure, and progress after logging in again

Assigned cards: [E2E-07 / E2E-08 / E2E-09 / E2E-10]
Build: [BUILD/VERSION]
Instructions: [TEST GUIDE LINK]
Results: [RESULTS CHANNEL/LINK]
```

## Post 7 — Day 4: settings, recovery, and social features

```text
💬 TESTING DAY 4 — SETTINGS, RECOVERY, AND SOCIAL FEATURES

Settings testers:
• Open and close every available main menu
• Change audio, graphics, zoom, controls, and at least one hotkey
• Test windowed mode and at least two resolutions
• Change language and perform normal gameplay actions
• Restart and check that the settings were saved
• Report clipped text, overlapping controls, missing icons, or unreadable colors

Social testers working in pairs:
• Meet on the same map and compare appearance, follower, and movement
• Test available chat channels and one private message
• Send, accept, and remove a friend request
• Open each other's public Trainer Card
• Let one player log out and return, then check online status and presence

Only perform the connection-recovery test if the test lead assigned it to you. Never stop a server or alter server data.

Assigned cards: E2E-11 to E2E-14
Partner: [PARTNER NAME]
Session time: [DATE/TIME/TIME ZONE]
Build: [BUILD/VERSION]
Instructions: [TEST GUIDE LINK]
Results: [RESULTS CHANNEL/LINK]
```

## Post 8 — Multiplayer session invitation

```text
👥 SCHEDULED MULTIPLAYER TEST SESSION

We need multiple testers online at the same time to test trading, Casual battles, Ranked, spectating, Guilds, and Aether Clash.

Date: [DATE]
Time: [TIME AND TIME ZONE]
Expected duration: [DURATION]
Build: [BUILD/VERSION]
Meet in: [VOICE/TEXT CHANNEL]
Test lead: [NAME]

Please arrive with:
• The assigned test account
• A legal battle team, if assigned to PvP
• Only test Pokémon/items that may safely be traded
• Discord open so both sides can compare their results

React with ✅ if you will attend or ❌ if you need a different time. Please do not start the assigned trade or match before the test lead records who is participating.
```

## Post 9 — Day 5: trade, PvP, Guild, and Aether Clash

```text
🏆 TESTING DAY 5 — MULTIPLAYER AND PVP

Please join the scheduled session before starting these tests.

Trade pair:
• Refuse one invitation, then accept a new one
• Change both offers and confirm that previous approval is cleared
• Complete one trade and cancel one trade
• Check ownership on both accounts and again after logging in

PvP group:
• Complete one Casual room battle
• Complete one Ranked battle
• Test one forfeit
• Let a third tester spectate a live battle
• Compare turns, HP, timer, result, match history, rating, leaderboard, and Battle Points
• Confirm that Casual does not change Ranked rating

Guild/Aether Clash group, if access is available:
• Test invitations/applications and member permissions
• Perform only the assigned test deposit and withdrawal, then check logs
• Test Guild chat and public Guild information
• Enter the Aether Clash Lobby
• Complete the assigned Guild Duel flow, including invitation, entry, battle, spectating, result, and exit

Use only disposable test items and Pokémon. Report mismatched results from both player perspectives.

Assigned cards: E2E-14 to E2E-16
Session time: [DATE/TIME/TIME ZONE]
Build: [BUILD/VERSION]
Instructions: [TEST GUIDE LINK]
Results: [RESULTS CHANNEL/LINK]
```

## Post 10 — Bug report template

The outer four backticks are only there to display this post in this document.
Copy the content starting at `🐛` through the final backticks into Discord.

````text
🐛 BUG REPORT

**Title:** [Short description of what failed and where]
**Test card:** [For example: E2E-07]
**Severity:** [Blocker / High / Medium / Low]
**Build:** [BUILD/VERSION]
**Test character:** [CHARACTER NAME — no email or password]
**Operating system:** [WINDOWS/LINUX/MACOS]
**Screen resolution:** [RESOLUTION]
**Map/screen:** [LOCATION]

**Starting situation:**
[What was true immediately before the problem?]

**Steps to reproduce:**
1. [FIRST STEP]
2. [SECOND STEP]
3. [THIRD STEP]

**Expected result:**
[What should have happened?]

**Actual result:**
[What happened instead?]

**Frequency:** [For example: 1/1, 2/3, or sometimes]
**Still present after restart:** [Yes / No / Not tested]
**Attachment:** [Screenshot/video/log if requested]
```
````

## Post 11 — Urgent Blocker/High bug alert

```text
🚨 IMPORTANT TESTING ISSUE

We found a possible [BLOCKER/HIGH] severity issue:
[ONE-SENTENCE DESCRIPTION]

Affected build: [BUILD/VERSION]
Bug report: [LINK]

Until the test lead confirms otherwise:
• [STOP THIS SPECIFIC TEST / AVOID THIS SPECIFIC ACTION]
• Do not create duplicate reports unless your result is meaningfully different.
• Continue with unrelated assigned tests if it is safe to do so.

Reply in [CHANNEL] if this issue blocks your assignment.
```

## Post 12 — Retest request after a fix

```text
🔁 FIX READY FOR RETEST

The following issue should now be fixed:
[BUG TITLE]

Bug report: [LINK]
New build: [BUILD/VERSION]
Retest owner: [TESTER NAME]
Related test card: [E2E NUMBER]

Please:
1. Repeat the original reproduction steps exactly.
2. Confirm whether the original problem is gone.
3. Complete the rest of the related test card.
4. Check one nearby flow that could have been affected.
5. Reply with PASS or FAIL and include the new result.

Do not mark the bug as fixed based only on the patch notes; it needs a result from the new build.
```

## Post 13 — Daily check-in

```text
📊 DAILY TESTING CHECK-IN — [DATE]

Please post your summary before [TIME AND TIME ZONE]:

Tester:
Build:
PASS:
FAIL:
BLOCKED:
SKIPPED:
New Blocker/High bug links:
Fixes retested successfully:
Most important open question:

Short answers are fine. Every assigned test must have a result, even when it was blocked or skipped.
```

## Post 14 — End-of-week message

```text
✅ POKEAETHER TESTING WEEK — FINAL CHECK

Thank you to everyone who tested this week. Before we close the test round, please check that:

• Every assigned test has a PASS, FAIL, BLOCKED, or SKIPPED result.
• Every FAIL or BLOCKED result links to a bug report.
• Your bug reports include the build and clear reproduction steps.
• Any fix you were asked to retest has a result from the new build.
• You have reported anything that was confusing, even if you eventually found a workaround.

Please submit missing results before [DEADLINE].

Results overview: [LINK]
Open issues: [LINK]
Next update from the team: [DATE/CHANNEL]

Your reports directly help us decide what must be fixed before feature development resumes.
```

## Optional short reminders

### Start-of-session reminder

```text
Testing starts in 30 minutes. Please update to build [BUILD/VERSION], open [VOICE/TEXT CHANNEL], and have your assigned account ready. Do not begin multiplayer actions until the test lead gives the signal.
```

### Missing-result reminder

```text
Hi [TESTER NAME], we are still missing a result for [TEST CARD]. Please reply with PASS, FAIL, BLOCKED, or SKIPPED before [DEADLINE]. If you were blocked, tell us which issue stopped you.
```

### Build-changed reminder

```text
⚠️ The test build has changed from [OLD BUILD] to [NEW BUILD]. Please finish or stop your current test safely, update the game, and include the new build number in every new result. Wait for a retest assignment before repeating completed cards.
```
