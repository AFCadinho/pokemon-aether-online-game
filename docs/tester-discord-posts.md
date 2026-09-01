# Concrete Discord test posts

These posts tell testers exactly which feature to test and how to test it. The
English is kept simple for people who do not speak English as their first
language.

Do not send every post to every tester. Give each tester one or more numbered
tests. Replace all text between `[SQUARE BRACKETS]` before posting.

## Plan for the test leader

Prepare these accounts before the week starts:

- a new account for Tests 01 and 02;
- accounts saved before Pewter City, Mt. Moon, and Cerulean City;
- one normal account with test items, money, Pokémon, badges, HMs, a mount, and
  access to all current areas;
- two accounts for social, mail, trade, loan, and Exchange tests;
- accounts in two test Guilds with Leader, Captain, and Member roles;
- at least three accounts with PvP teams that the game accepts;
- enough players for an Aether Clash Guild Duel.

Only use test Pokémon, items, money, Aetherite, Battle Points, and Aether Gems
that may safely be spent or moved. Never test a real-money payment unless a
separate approved payment test is planned.

## Feature list

| Test | Feature |
|---|---|
| 01 | Launcher, account, login, New Game, and character creation |
| 02 | Pallet Town, starter, Gary, Oak's Parcel, and Town Map |
| 03 | Fishing, Thieving, Mankey, Trainer School, and EV lesson quests |
| 04 | Route 2, Viridian Forest, Pewter Gym, Brock, and Rock Smash lesson |
| 05 | Route 3 and the complete Mt. Moon story |
| 06 | Cerulean City, Nugget Bridge, Route 25, Bill, and Misty |
| 07 | Wild encounters, catching, Party, healing, and Pokédex |
| 08 | Battle actions, levels, move learning, evolution, and blackout |
| 09 | Bag, hotbar, usable items, held items, and item amounts |
| 10 | Pokémon Storage, Summary, Pokédex, and Item Dex |
| 11 | Map travel, Aethernet, Cyclizar, followers, and saved position |
| 12 | Fishing, Thieving, Rock Smash, and field moves |
| 13 | Global Boosts and Global Heal |
| 14 | Poké Mart, Move Maniac, Move Deleter, and Aether Clash vendors |
| 15 | Aether Exchange listings and item wishlists |
| 16 | Trainer Card, Character Customization, Gift Store, and Atelier |
| 17 | Settings, controls, language, graphics, and saved settings |
| 18 | Other players, chat, private messages, friends, and blocking |
| 19 | Player mail with an item, money, and a Pokémon |
| 20 | Player Trade with Pokémon, items, and money |
| 21 | Player Loans with Pokémon and reusable held items |
| 22 | Guild search, members, roles, management, and Guild Bank |
| 23 | Casual PvP room from room code to result |
| 24 | Ranked PvP, Aether OU, Aether UU, rewards, and rating |
| 25 | Watching a live PvP battle |
| 26 | Aether Clash Guild Duel challenge and arena entry |
| 27 | Aether Clash battle, jail, watching, and final result |
| 28 | Shiny Tracker, Aether Blessing, reward cards, and Live Events |

A simple week can use Tests 01–07 on days 1 and 2, Tests 08–17 and 28 on day 3,
Tests 18–22 on day 4, and Tests 23–27 in one planned group session on day 5.

---

## Post 0 — Start of the test week

```text
🧪 POKEAETHER TEST WEEK

This week we will test the features that are already in the game. We will not focus on new features.

You will receive one or more numbered test tasks. Each task tells you:
• What account or items you need
• The exact steps to follow
• What must work for the test to pass

Please follow every step in order. Do not only play freely.

For every task, send:
Result: PASS / FAIL / BLOCKED / SKIPPED
Failed step number:
Bug report link:
Anything that was hard to understand:

Game version: [GAME VERSION]
Test server: [TEST SERVER]
Bug channel: [BUG CHANNEL/LINK]

PASS means every step worked.
FAIL means one or more steps did not work.
BLOCKED means another problem stopped the test.
SKIPPED means you did not do the test.
```

## Post 01 — Launcher, account, and New Game

```text
🧪 TEST 01 — LAUNCHER, ACCOUNT, AND NEW GAME

YOU NEED
• A new test email address and no game progress
• Game version [GAME VERSION]

STEPS
1. Open the launcher.
2. Check that news and server status are visible.
3. Let the launcher check for an update, then start the game.
4. Create a new account and finish email verification.
5. Try to log in once with a wrong password. Read the error.
6. Log in with the correct password.
7. Start New Game. Read the full warning before you continue.
8. Create a character. Change the look and colours before you save.
9. Try one name that is not allowed. Then choose an allowed name.
10. Enter the world and check that you start inside the Player's House.
11. Close the game normally. Start it again and log in.

PASS WHEN
• The launcher opens the correct game version.
• Wrong details show a clear error. Correct details work.
• Your name and look are saved once.
• You return to the same new character after logging in again.

SEND BACK
Result: [PASS / FAIL / BLOCKED / SKIPPED]
Failed step:
Bug link:
```

## Post 02 — Pallet Town and Viridian story

```text
🧪 TEST 02 — STARTER, GARY, OAK'S PARCEL, AND TOWN MAP

YOU NEED
• A new character at the start of the story

STEPS
1. Talk to your father in the Player's House.
2. Follow the Quest Log to Professor Oak's Lab.
3. Choose one starter. Open Party and check its Summary.
4. Try to use the starter choice again. You must not receive a second starter.
5. Train your starter to level 10 and return to Dadinho on Route 1.
6. Return to Oak's Lab and finish the Gary battle.
7. Talk to Oak to start Oak's Parcel quest.
8. Go to the item seller in the Viridian City Pokémon Center and take the Parcel.
9. Return the Parcel to Oak.
10. Go home and talk to Mom.
11. Go to Rival's House and receive the Town Map from Gary's sister.
12. Log out and back in. Check Party, Bag, Town Map, and Quest Log.

PASS WHEN
• The Quest Log always shows the correct next step.
• You receive one starter, one Parcel reward, and one Town Map.
• Gary's battle and story scenes happen only one time.
• Finished quests stay finished after login.

SEND BACK
Result:
Failed step:
Last correct quest step:
Bug link:
```

## Post 03 — Early quests and lessons

```text
🧪 TEST 03 — FISHING, THIEVING, MANKEY, TRAINER SCHOOL, AND EV LESSON

YOU NEED
• An account that finished Oak's Parcel

STEPS
1. Take the Old Rod lesson from the Fishing Guru in Pallet Town.
2. Use the rod, catch a Magikarp, and return to the Fishing Guru.
3. Start the Thieving lesson with Master Thief Rook in Viridian City.
4. Try to pickpocket League Fan Dorian and one child. Return to Rook.
5. Start Gideon's catching quest. Catch a Mankey on Route 22 and return to him.
6. Meet Gary on Route 22 and return to Viridian City.
7. Visit the Trainer School and speak with Dadinho.
8. Start Mateo's EV lesson. Choose one Pokémon and one stat.
9. Defeat the four named training Pokémon with that Pokémon in the fight.
10. Add the four EV points in Pokémon Summary, then return to Mateo.
11. Check every reward card, Quest Log entry, Bag amount, and skill XP.

PASS WHEN
• Each quest counter goes up only after the correct action.
• Each quest reward is received one time.
• The EV screen adds points to the chosen Pokémon and stat.
• Every finished quest stays finished after a map change and login.

SEND BACK
Result:
Failed step:
Quest name and shown number:
Bug link:
```

## Post 04 — Viridian Forest, Brock, and Rock Smash

```text
🧪 TEST 04 — VIRIDIAN FOREST, BROCK, AND ROCK SMASH

YOU NEED
• An account ready to travel north from Viridian City

STEPS
1. Try to enter Route 3 before beating Brock. Check the message that stops you.
2. Travel through Route 2, both forest gates, and Viridian Forest.
3. Test paths near trees, grass, walls, signs, and gate doors.
4. Enter Pewter City and the Pewter Gym.
5. Fight the Gym Trainers, then fight Brock.
6. Check the Boulder Badge, TM Rock Slide, Aetherite, and other shown rewards.
7. Return to the Route 3 exit. It must now let you pass.
8. Find Karate Master Kenji in Pewter City and receive HM Rock Smash.
9. Break all four training rocks near Kenji.
10. Return to Kenji and finish the lesson.
11. Log out and back in. Check badge, HM, quest, and rewards.

PASS WHEN
• Route 3 is closed before Brock and open after Brock.
• Brock can give each reward only one time.
• All four rocks count once and the Rock Smash lesson finishes.
• Every map exit works in the correct direction and no path traps the player.

SEND BACK
Result:
Failed step:
Map or quest name:
Bug link:
```

## Post 05 — Route 3 and Mt. Moon

```text
🧪 TEST 05 — COMPLETE MT. MOON STORY

YOU NEED
• An account with the Boulder Badge at the start of Route 3

STEPS
1. Travel across Route 3 and enter the Route 3 Pokémon Center.
2. Enter Mt. Moon and talk to the Hiker near the entrance.
3. Use ladders to visit 1F, B1F, and B2F. Go back through at least one ladder.
4. Find and defeat all four suspicious people shown by the quest.
5. Find Miguel near the fossils and defeat him.
6. Look at both fossils and choose only one.
7. Check that the chosen fossil is in Bag under Other.
8. Continue through the Team Rocket ambush.
9. Leave Mt. Moon through the correct exit and travel through Route 4.
10. Check the Quest Log, Trainer Card rewards, Bag, and next story goal.
11. Log out in a safe place and check everything again after login.

PASS WHEN
• Every defeated person adds exactly one to the quest.
• The player receives only the chosen fossil.
• Battles and story scenes do not repeat after they are finished.
• Every floor, ladder, entrance, and exit places the player correctly.

SEND BACK
Result:
Failed step:
Mt. Moon floor or quest number:
Bug link:
```

## Post 06 — Cerulean, Bill, and Misty

```text
🧪 TEST 06 — CERULEAN CITY, NUGGET BRIDGE, BILL, AND MISTY

YOU NEED
• An account arriving in Cerulean City from Route 4

STEPS
1. Visit Cerulean Gym before finding Misty. Check what the Gym tells you.
2. Go north to Route 24. Gary must stop you before Nugget Bridge.
3. Finish the Gary battle.
4. Defeat the five Nugget Bridge Trainers in order.
5. Speak with the recruiter at the end of the bridge.
6. Enter Route 25 and finish the Misty and Dadinho story scene.
7. Follow Route 25 to Bill's House.
8. Speak with Bill, then use his computer to start the Cell Separation System.
9. Speak with Bill again and receive the S.S. Ticket.
10. Return to Cerulean Gym.
11. Defeat the three Gym Trainers and then Misty.
12. Check the Cascade Badge, quest rewards, Aetherite, Bag, and Trainer Card.
13. Log out and check the completed story again after login.

PASS WHEN
• Misty is unavailable before Bill and available after Bill.
• The five bridge wins and three Gym Trainer wins count correctly.
• Bill changes back once and gives one S.S. Ticket.
• Misty gives one Cascade Badge and the correct shown rewards.

SEND BACK
Result:
Failed step:
Last correct story event:
Bug link:
```

## Post 07 — Wild Pokémon, catching, and healing

```text
🧪 TEST 07 — WILD ENCOUNTERS, CATCHING, PARTY, AND HEALING

YOU NEED
• Poké Balls
• A Party with at least two Pokémon
• One free Party place, then a full Party later

STEPS
1. Walk in tall grass until a wild battle starts.
2. Use one move, switch Pokémon, and run from the battle.
3. Start another wild battle. Lower the wild Pokémon's HP and throw a Poké Ball.
4. Catch it and check Party, Pokémon Summary, and Pokédex.
5. Fill the Party, then catch another Pokémon. Check that it goes to Pokémon Storage.
6. Prepare an active Pokémon with low HP. Throw a Poké Ball and let it fail while the wild Pokémon makes your active Pokémon faint.
7. Check that you can choose the next Party Pokémon and continue the battle.
8. Take damage, then heal at a Pokémon Center.
9. Change map and check that all Party HP is still full.
10. Log out and check both caught Pokémon again.

PASS WHEN
• Every chosen battle action happens one time.
• A catch goes to Party when there is space and Storage when Party is full.
• A failed catch plus a faint does not freeze the Party choice.
• Healing and caught Pokémon stay correct after map change and login.

SEND BACK
Result:
Failed step:
Wild Pokémon and map:
Bug link:
```

## Post 08 — Battles, levels, moves, and evolution

```text
🧪 TEST 08 — BATTLE PROGRESS, MOVE LEARNING, EVOLUTION, AND BLACKOUT

YOU NEED
• One Pokémon close to a new level
• One Pokémon close to the current level cap
• One Pokémon ready to learn a fifth move
• One Pokémon ready to evolve by level or Evolution Stone

STEPS
1. Win a Trainer battle. Use a move, switch Pokémon, and use one battle item.
2. Let one Party Pokémon faint and finish the battle with another Pokémon.
3. Check XP and the level-up reward card.
4. Learn a move when there is a free move place.
5. When learning a fifth move, replace one old move. Check the final four moves.
6. On another move question, choose cancel. Check that the old moves stay.
7. Reach the current level cap. Check that the Pokémon does not go above it.
8. Evolve the prepared Pokémon. Check its name, picture, stats, moves, and Pokédex.
9. Lose a separate battle with the full Party.
10. Check the blackout message, money change, healing, and return place.
11. Log out and check levels, moves, evolution, HP, and money again.

PASS WHEN
• XP, moves, and evolution are saved once.
• The level cap is followed.
• Fainting and losing never leave the player stuck in battle.
• Blackout returns the player to a safe place with the correct result.

SEND BACK
Result:
Failed step:
Pokémon and battle type:
Bug link:
```

## Post 09 — Bag, hotbar, and held items

```text
🧪 TEST 09 — BAG, HOTBAR, USABLE ITEMS, AND HELD ITEMS

YOU NEED
• Two healing items
• One Moomoo Milk if available
• One held item
• One fossil if available

STEPS
1. Open every Bag section and use search or filters.
2. Note the amount of one healing item. Damage a Pokémon and use the item from Bag.
3. Add another healing item to the hotbar. Use it from the hotbar.
4. If available, use Moomoo Milk on a damaged Pokémon. Check that it heals up to 100 HP.
5. Give a held item to a Party Pokémon.
6. Replace the held item, then move the held item back to Bag.
7. Open Pokémon Storage and move a held item from a stored Pokémon to Bag.
8. Check that fossils are under Other and cannot be used as held items.
9. Close and reopen Bag. Then log out and back in.

PASS WHEN
• Every use removes exactly one item when the item should be used up.
• HP changes by the shown amount and never goes over maximum HP.
• Held items appear in only one place and never copy or disappear.
• Bag sections, amounts, and hotbar stay correct after login.

SEND BACK
Result:
Failed step:
Item name and amount before/after:
Bug link:
```

## Post 10 — Pokémon Storage and Dex pages

```text
🧪 TEST 10 — POKÉMON STORAGE, SUMMARY, POKÉDEX, AND ITEM DEX

YOU NEED
• A full Party
• At least five Pokémon in Storage
• Pokémon with different types, levels, and caught status

STEPS
1. Open Pokémon Storage at a PC.
2. Move one Party Pokémon to a box and one box Pokémon to Party.
3. Move Pokémon between two different boxes.
4. Use name, type, level, and other available filters. Clear all filters.
5. Open Pokémon Summary from Party and from Storage.
6. Click the Summary picture to check front and back sprites.
7. Move a held item from a stored Pokémon directly to Bag.
8. Catch a new Pokémon with a full Party. Find it in Storage.
9. Open Pokédex. Find the new caught Pokémon and check its shown information and reward.
10. Open Item Dex. Check one owned item, one unknown item, its source information, and any shown reward.
11. Log out and check Party, boxes, held item, Pokédex, and Item Dex again.

PASS WHEN
• Each Pokémon is in one place only.
• Filters show the correct Pokémon and do not hide them after reset.
• Summary data is the same from Party and Storage.
• Caught and owned information stays correct after login.

SEND BACK
Result:
Failed step:
Pokémon or item name:
Bug link:
```

## Post 11 — Maps, Aethernet, mount, and follower

```text
🧪 TEST 11 — MAP TRAVEL, AETHERNET, CYCLIZAR, AND FOLLOWER

YOU NEED
• Access to Pallet, Viridian, Pewter, and Cerulean
• A follower Pokémon
• Cyclizar and the Kanto land-mount licence
• Money for one Aethernet trip

STEPS
1. Use three outdoor map exits in both directions.
2. Enter and leave a house, Pokémon Center, Gym, gate, and cave.
3. Check that every exit places you near the correct door or path.
4. Walk against trees, water, walls, counters, map edges, and other blocked places.
5. Walk in all directions with a follower. Stop and check the space between you.
6. Ride Cyclizar outdoors. Enter another outdoor map, finish one battle, and return.
7. Enter a building and check the mount and follower behaviour.
8. Log out outdoors while riding. Log in and check the mount again.
9. Open Aethernet travel. Check available and locked places and the shown prices.
10. Travel once. Check the purple effect, arrival place, and exact money change.

PASS WHEN
• The player cannot walk through blocked places or become trapped.
• Exits work both ways and use the correct arrival place.
• Cyclizar and the follower behave correctly across maps, battle, buildings, and login.
• Aethernet takes the shown price once and sends you to the chosen place.

SEND BACK
Result:
Failed step:
Start map and end map:
Bug link:
```

## Post 12 — Skills and field moves

```text
🧪 TEST 12 — FISHING, THIEVING, ROCK SMASH, AND FIELD MOVES

YOU NEED
• Old Rod
• HM Rock Smash
• Test accounts with and without the needed HMs and badges
• Access to Cut, Flash, Strength, Surf, or weather actions where possible

STEPS
1. Try Fishing where there is no water. Read the message.
2. Fish at water where Fishing works. Finish one failed try and one catch. Check Fishing XP.
3. Try Thieving on a person where it does not work, then on a person where it does. Check success or failure, reward, XP, and wait time.
4. Try to pickpocket Officer Jenny. Let the full arrest scene finish and check the jail result.
5. Break one normal Rock Smash rock. Check reward, XP, and the daily state.
6. Try the same daily rock again. It must not give a second daily reward.
7. Try one field move without the needed HM or badge. Read the message.
8. Use the same field move with the correct HM and badge.
9. Test all available Cut, Flash, Strength, Surf, Rock Smash, and weather actions on the prepared account.
10. Change map and log in again. Check skill XP, wait times, and daily rocks.

PASS WHEN
• Actions in the wrong place give a clear reason and no reward.
• Actions in the correct place give the shown reward and XP once.
• Arrest waits for the dialogue and ends in the correct place.
• HMs and badges open only the correct field moves.

SEND BACK
Result:
Failed step:
Skill, target, and map:
Bug link:
```

## Post 13 — Global Boosts and Global Heal

```text
🧪 TEST 13 — GLOBAL BOOSTS AND GLOBAL HEAL

ONLY DO THIS ON [TEST SERVER] WHEN [TEST LEADER] SAYS START.

YOU NEED
• Two online accounts
• At least ₽20,000 test money on each account
• A damaged Party on both accounts

STEPS
1. Both players open the Global Boost list.
2. Check Battle XP, EV, Rare Encounter, Fishing, Thieving, and Rock Smash boosts.
3. Player A adds exactly ₽10,000 to the chosen test boost.
4. Check that Player A has ₽10,000 less and 10 more Aetherite. Check the boost amount on both screens.
5. Player B adds another allowed amount. Check both screens again.
6. Only if the test leader allows it, finish funding the boost.
7. Check the System chat message, on-screen card, active boost, and one-hour timer.
8. Do the boosted activity once and compare its XP or result with the shown boost.
9. Damage both Parties. Let Player A use Global Heal.
10. Check healing, the message/card, and the shared wait time on both accounts.

PASS WHEN
• Money, Aetherite, and funding progress change by the correct shown amounts.
• Both players see updates without reopening the menu.
• An active boost shows one clear timer and changes only its named activity.
• Global Heal heals all players once and shows the same wait time.

SEND BACK
Result:
Failed step:
Boost name and amounts before/after:
Bug link:
```

## Post 14 — Shops, move services, and Lobby vendors

```text
🧪 TEST 14 — SHOPS, MOVE SERVICES, AND AETHER CLASH VENDORS

YOU NEED
• Test money
• One tradeable Bag item to sell
• One Pokémon with an old move it can relearn
• One Pokémon with four moves
• The materials shown by the Move Maniac
• Access to the Aether Clash Lobby and assigned test currency

STEPS
1. Open a Poké Mart and buy one item. Check money and Bag amount.
2. Sell one tradeable item. Also try an item that the shop does not sell itself.
3. Cancel one buy or sell before confirming. Check that nothing changes.
4. Find the Move Maniac in a Pokémon Center.
5. Select a Pokémon and an old move. Check move details, price, and owned materials.
6. Teach the move. If it becomes a fifth move, choose one move to forget.
7. Check the Pokémon's four final moves and material amounts.
8. Find the Move Deleter. Delete one chosen move.
9. Cancel a second delete and check that the move stays.
10. Visit the Battle Point vendor in the Aether Clash Lobby. Buy only the assigned test item.
11. Open the Mega Stone Seller and Z-Crystal Seller. Check prices and an item you already own.
12. If assigned, buy one Z-Crystal. Check its ∞ mark and confirm that assigning it does not use it up.
13. Change map and log in again. Check money, Battle Points, Bag, materials, and moves.

PASS WHEN
• Buy, sell, teaching, and deleting use the shown cost once.
• Cancel changes nothing.
• A fifth move always asks which move to forget.
• A permanent owned item cannot be bought twice, and a Z-Crystal is not used up.
• The final moves and amounts stay correct after login.

SEND BACK
Result:
Failed step:
Shop, item, Pokémon, or move name:
Bug link:
```

## Post 15 — Aether Exchange and wishlists

```text
🧪 TEST 15 — AETHER EXCHANGE LISTINGS AND ITEM WISHLISTS

YOU NEED
• Two test accounts: Buyer and Seller
• One test Pokémon, two copies of one tradeable item, and test money

STEPS
1. Buyer opens Browse. Search, sort, and filter Pokémon and items.
2. Open one Pokémon listing and check its read-only Summary.
3. Seller lists one test item. Check price, fee, amount, and My Orders.
4. Buyer finds and buys it.
5. Check Buyer's item and money. Check Seller's money and order state.
6. Seller lists one test Pokémon. Buyer opens its Summary and buys it.
7. Check Party or Storage on Buyer and Seller.
8. Buyer opens Item Wishlists and offers money for one item.
9. Check that the offer appears and the money is held correctly.
10. Cancel the wish. Check that the full offered money returns.
11. Make the wish again. Seller fills it with the second item copy.
12. Check the final item, money, and order history on both accounts.
13. Log both accounts out and check everything again.

PASS WHEN
• Search, filters, and Summary show the correct listing.
• Each sale moves one asset and the correct money one time.
• Cancelling a wish gives a full refund.
• Filling a wish gives the item to Buyer and money to Seller once.

SEND BACK
Result:
Failed step:
Listing or wish name and amounts:
Bug link:
```

## Post 16 — Appearance, Trainer Card, Store, and Atelier

```text
🧪 TEST 16 — CHARACTER LOOK AND COSMETIC SCREENS

YOU NEED
• An account with at least one wardrobe item
• Test Aether Gems or Atelier materials only if the test leader gives them

STEPS
1. Open your Trainer Card. Check Overview, Badges, and PvP pages.
2. Open Character Customization. Change hair, colours, top, trousers, and shoes.
3. Choose no hair. Check that no hair-coloured dot stays on the face.
4. Equip one wardrobe item, save, then return it to Bag.
5. Open the Aether Gift Store. Use each category and open item details.
6. Turn the character preview in all directions. Check the full body and shoes.
7. Open an item you already own. It must show that you cannot buy it again when it is permanent.
8. Do not make a real-money payment. If test Gems are given, buy only the named test item.
9. Open Aether Atelier if your account has access. Preview a colour and create or dye only the assigned test item.
10. Log out and check Trainer Card, saved look, Bag, and wardrobe again.

PASS WHEN
• The saved character looks the same in the world, preview, and Trainer Card.
• Equipping and returning moves one item between wardrobe and Bag.
• Store previews show the full outfit and correct price.
• No real payment starts without a clear choice and confirmation.

SEND BACK
Result:
Failed step:
Cosmetic or screen name:
Bug link:
```

## Post 17 — Settings and saved choices

```text
🧪 TEST 17 — SETTINGS, CONTROLS, LANGUAGE, AND GRAPHICS

YOU NEED
• Any normal test account

STEPS
1. Open every Settings page. Check Controls, Graphics, Audio, Gameplay, Support, About, and Account pages that are shown.
2. Lower music and sound. Check that each sound type changes.
3. Turn Move Animations off. Finish one short battle. Turn them on and compare.
4. Change the Interact key. Use the new key on a character or sign.
5. Change the Running Shoes, Fishing, or Mount key and test it.
6. Change the game window between two sizes.
7. Set outdoor zoom to Auto. Check whether it changes between 1× and 2× with window size.
8. Choose fixed 1× and fixed 2× and check both.
9. Change language. Open Bag, Quest Log, PvP, Settings, and one dialogue.
10. Log out, close the game, start again, and check all changed settings.

PASS WHEN
• Changed sound, keys, zoom, and language work at once.
• Text is not cut off and buttons do not cover each other.
• The old key stops the action when a new key is saved.
• All saved choices stay after restart.

SEND BACK
Result:
Failed step:
Setting, language, and window size:
Bug link:
```

## Post 18 — Players, chat, and friends

```text
🧪 TEST 18 — OTHER PLAYERS, CHAT, PRIVATE MESSAGES, AND FRIENDS

YOU NEED
• Two test accounts on two game clients

STEPS
1. Put both players on the same map.
2. Move, turn, use a follower, and use a mount. Compare what both players see.
3. Change one player's map. Check that they leave the old Nearby Players list.
4. Send one message in Global, Map, Trade, and Help chat.
5. Open All chat. Check that each message appears once with the correct channel name.
6. Send a private message in both directions.
7. Player A sends a friend request. Player B declines it.
8. Send it again and accept it. Check online status and friend actions.
9. Open each other's public Trainer Card.
10. Remove the friend. Block the test user, check the result, then unblock them.
11. Log one player out. Check the other player's map, friend, and online lists.

PASS WHEN
• Both players see the same name, look, movement, follower, and mount.
• Messages appear one time in the correct place.
• Friend, block, online, and map status update correctly.
• A public Trainer Card shows public data only.

SEND BACK
Result:
Failed step:
What Player A saw and what Player B saw:
Bug link:
```

## Post 19 — Player mail with gifts

```text
🧪 TEST 19 — MAIL WITH AN ITEM, MONEY, AND A POKÉMON

YOU NEED
• Sender and Receiver test accounts
• One test item and one test Pokémon that may safely be moved
• Test money

STEPS
1. Sender writes a mail with subject and message only. Receiver opens it and replies.
2. Sender writes a second mail.
3. Add one item, some money, and one Pokémon to the second mail.
4. Before sending, remove the item or Pokémon and add it again.
5. Note Sender's Bag, Party or Storage, and money. Send the mail.
6. Check that the sending fee, item, money, and Pokémon leave Sender once.
7. Receiver opens the mail and views the Pokémon Summary before claiming it.
8. Claim the item, money, and Pokémon.
9. With a full Party, check that the Pokémon goes to Storage.
10. Try to claim the same item, money, and Pokémon again.
11. Delete the finished mail. Log both accounts out and check all assets again.

PASS WHEN
• The mail arrives once with the correct sender, subject, and message.
• Every sent item, Pokémon, and money amount moves once and cannot be claimed twice.
• The Summary shows the correct original Trainer.
• Money, item, Pokémon, and fee stay correct after login.

SEND BACK
Result:
Failed step:
Sent item, Pokémon, and amounts before/after:
Bug link:
```

## Post 20 — Player Trade

```text
🧪 TEST 20 — TRADE POKÉMON, ITEMS, AND MONEY

YOU NEED
• Player A and Player B on the same map
• Test Pokémon and items on both accounts that may safely be moved
• Test money

STEPS
1. Player A sends a trade invite. Player B declines it.
2. Send a new invite and accept it.
3. Both players add one Pokémon, one item stack, and some money.
4. Open the offered Pokémon Summary on both sides.
5. Player A presses Ready. Then Player B changes an offer.
6. Check that Ready is removed and both players see the new offer.
7. Press Ready on both sides. Read the final Gives and Receives screen.
8. Both players confirm the exact same final trade.
9. Check Party, Storage, Bag, and money on both accounts.
10. Start another trade and leave before confirming. Check that all assets stay with the original owners.
11. Try to offer a Pokémon above the other player's trade cap. Read the error.
12. Log both accounts out and check the completed and cancelled trades again.

PASS WHEN
• Both players always see the same offer.
• Any change removes Ready and needs a new review.
• The finished trade moves every shown asset once.
• Cancelled trades and trades the game does not allow move nothing.

SEND BACK
Result:
Failed step:
What each player gave and received:
Bug link:
```

## Post 21 — Player Loans

```text
🧪 TEST 21 — LOAN POKÉMON AND REUSABLE ITEMS

YOU NEED
• Lender and Borrower on the same map
• One Party Pokémon, one Storage Pokémon, and two reusable held items
• A short test loan time and a test fee if [TEST LEADER] asks for one

STEPS
1. Lender offers the Party Pokémon. Borrower accepts it.
2. Check that it leaves Lender and appears once for Borrower with a loan mark and end time.
3. Repeat with the Storage Pokémon. Lender must still keep one Party Pokémon.
4. Loan both reusable held items.
5. Borrower attaches one loaned item to a Pokémon, removes it, and returns it.
6. Lender asks for one Pokémon back. Borrower says no.
7. Ask again. Borrower accepts the return.
8. Return another asset while Lender is offline. Lender logs in and checks the message and Loan Returns.
9. If a short loan can end during this session, let one end and check the automatic return.
10. Open Player Loans and search the 30-day history.
11. Check Party, Storage, Bag, fee, and loan state on both accounts after login.

PASS WHEN
• Every asset has one owner and one current holder.
• Loan marks and time are visible in Party, Storage, Bag, and Summary.
• Saying no keeps the loan. Accepting or time ending returns it once.
• No Pokémon or item disappears or is copied.

SEND BACK
Result:
Failed step:
Loaned asset and state on both accounts:
Bug link:
```

## Post 22 — Guild features and Guild Bank

```text
🧪 TEST 22 — GUILD SEARCH, MEMBERS, ROLES, MANAGEMENT, AND BANK

YOU NEED
• Guild Leader, Captain, Member, and non-member test accounts
• Test money, an item, and a Pokémon that may safely be moved

STEPS
1. Non-member searches for the test Guild and opens its public page.
2. Read the recruitment checklist and send an application.
3. Leader opens the application, views the Trainer Card, and accepts it.
4. Leader invites another test player. Accept the invite.
5. Change one player between Member and Captain. Check the member list.
6. Leader changes the Guild profile, announcement, recruitment text, and emblem.
7. Member tries one action they are not allowed to do. Read the error.
8. Deposit test money into Guild Bank.
9. Deposit one test Pokémon and one test item or consumable into the correct Guild storage.
10. Test one allowed borrow or withdrawal and one blocked borrow or withdrawal.
11. Change that member's Bank permission and try again.
12. Search and filter Guild History and Guild Bank logs. Check every test action.
13. Log all accounts out and check Guild data again.

PASS WHEN
• Search, applications, invites, roles, and member counts update correctly.
• Each role can do only its allowed actions.
• Bank assets and money move once and logs show the correct player and action.
• Profile, announcement, emblem, permissions, and logs stay after login.

SEND BACK
Result:
Failed step:
Account role and action:
Bug link:
```

## Post 23 — Casual PvP room

```text
🧪 TEST 23 — CASUAL PVP FROM ROOM CODE TO RESULT

YOU NEED
• Player A and Player B with battle teams that the game accepts

STEPS
1. Player A opens PvP > Casual and creates a room.
2. Copy the room code. Player B first tries one wrong code and reads the error.
3. Player B joins with the correct code.
4. Both players check team preview and choose their starting Pokémon.
5. Play several turns. Use moves and switch Pokémon.
6. Compare HP, status, weather or field effects, and turn order on both screens.
7. Finish the battle normally.
8. Check the winner, loser, battle result, and match history on both accounts.
9. Check Ranked rating and Battle Points before and after. Casual must not change them.
10. Start a second Casual room. One player gives up.
11. Check that both players return to the game world and can move.
12. Log in again and check match history and Ranked values.

PASS WHEN
• The correct code joins one room and a wrong code gives a clear error.
• Both players see the same turns, HP, and final winner.
• Giving up ends the battle for both players.
• Casual does not change Ranked rating or give Ranked rewards.

SEND BACK
Result:
Failed step and turn number:
What Player A and Player B saw:
Bug link:
```

## Post 24 — Ranked PvP and Aether UU

```text
🧪 TEST 24 — RANKED, AETHER OU, AETHER UU, RATING, AND REWARDS

YOU NEED
• Two players with Aether OU and Aether UU teams that the game accepts
• One team with a Pokémon or rule that is not allowed

STEPS
1. Choose Aether OU. Try the team that is not allowed and read every team error.
2. Fix the team and enter the Ranked queue.
3. Leave the queue once. Check that the queue closes.
4. Both players enter the same Ranked queue again and wait for the match.
5. Play the battle to a normal result.
6. Check the result screen. Winner must receive 1,000 Battle Points and loser 500.
7. Check the shown rating change for both players.
8. Open Ranked history, leaderboard, and both Trainer Cards. Compare the numbers.
9. Repeat team checking and one match in Aether UU.
10. Check that Aether UU appears as the correct format in queue, live battle, history, and result.
11. Start one more Ranked battle and give up. Check result, rating, and reward once.
12. Log in again and compare Battle Points, rating, history, and Trainer Card.

PASS WHEN
• Teams that are not allowed cannot enter, and every problem is named clearly.
• Queue join and leave show the correct state.
• Both players see the same winner and rating changes.
• Each result and Battle Point reward is added once in every screen.

SEND BACK
Result:
Failed step, format, and turn number:
Rating and Battle Points before/after:
Bug link:
```

## Post 25 — Watch a live PvP battle

```text
🧪 TEST 25 — WATCH A LIVE PVP BATTLE

YOU NEED
• Player A and Player B in a Casual or Ranked battle
• Player C as the watcher

STEPS
1. Player C opens PvP > Live Battles.
2. Refresh the list and find the battle between A and B.
3. Open the live battle.
4. Compare Pokémon, HP, status, weather, field effects, messages, and turn result with Players A and B.
5. Player C tries normal battle buttons. The watcher must not be able to choose an action.
6. Let A and B switch Pokémon and make at least three more turns.
7. Player C closes the watched battle and opens it again.
8. Finish the battle. Check that Player C sees the same winner.
9. Refresh Live Battles. The finished battle must leave the live list.
10. Open match history and check the final result.

PASS WHEN
• The live list opens the correct battle.
• The watcher sees the same public battle events and winner.
• The watcher cannot control either team.
• Closing and reopening does not affect the real battle.

SEND BACK
Result:
Failed step and turn number:
Difference between player and watcher screens:
Bug link:
```

## Post 26 — Aether Clash challenge and entry

```text
🧪 TEST 26 — GUILD DUEL CHALLENGE, TIMER, PORTAL, AND ENTRY

YOU NEED
• Two test Guilds
• Leader, Captain, and Member accounts in both Guilds
• At least one extra watcher

STEPS
1. A normal Member tries to challenge the other Guild. This must be blocked.
2. A Leader or Captain right-clicks a player from the other Guild and sends a challenge.
3. The other Guild declines the first challenge.
4. Send a new challenge. A Leader or Captain accepts it.
5. Check the System chat message, on-screen message, directions, and two-minute entry timer.
6. Open the Guild page and check the active Clash information.
7. Members from both Guilds enter through the Guild Duel portal.
8. Check that both Guilds arrive in different team areas.
9. Let one member enter after the entry time. This player must enter as a watcher, not a fighter.
10. If public watching was chosen, let the extra non-member watcher enter.
11. Check player counts. Your own team names must be clear. Opponent names must stay hidden until battle.

PASS WHEN
• Only a Leader or Captain can challenge or answer.
• Declining closes the first challenge. Accepting starts one Clash.
• Every allowed member sees the same timer and directions.
• On-time players become fighters. Late or public players become watchers.

SEND BACK
Result:
Failed step:
Guild role, entry time, and final player state:
Bug link:
```

## Post 27 — Aether Clash battle and result

```text
🧪 TEST 27 — GUILD DUEL BATTLE, JAIL, WATCHING, AND FINAL RESULT

YOU NEED
• The active Guild Duel from Test 26

STEPS
1. Move around both team areas and the battle area. Check walls, exits, and shown controls.
2. Fire Poké Balls at walls and opponents. Balls must stop at walls.
3. Hit an active opponent and start a battle.
4. Check the single 7.5-minute battle timer on both players.
5. Let the battle finish. Check that the loser goes to jail and the winner returns to the arena.
6. In jail, use the watching orb and move the free camera.
7. Find the spinning Poké Ball above an active battle and open that battle.
8. Return from the watched battle to the jail camera.
9. Continue until one Guild has no active fighters.
10. Check winner, survivors, player results, full timeline, System chat, and any prize.
11. Wait for a battle result to close by itself after five seconds.
12. Leave the arena. Check that players can move normally and both Guilds can use Guild features again.

PASS WHEN
• A hit starts one battle and never starts a second battle before the first closes.
• Losers, winners, and watchers go to the correct places.
• Camera, battle markers, timer, exits, and controls always stay usable.
• Both Guilds see the same final winner, timeline, and prize once.

SEND BACK
Result:
Failed step and timer value:
What each player or watcher saw:
Bug link:
```

## Post 28 — Tracker, Blessing, and notifications

```text
🧪 TEST 28 — SHINY TRACKER, AETHER BLESSING, AND REWARD CARDS

YOU NEED
• Two test accounts
• One test Aether Blessing Voucher
• A Pokémon close to a new level
• A Live Event only if one is planned by [TEST LEADER]

STEPS
1. Open the Shiny Tracker from Bag and hotbar slot 2 before starting a hunt.
2. Start a hunt for a Pokémon that can appear on your map.
3. Meet that Pokémon two times. Check that the current hunt number changes by two.
4. Share the hunt in chat. The second player opens the shared Tracker card and checks the target and shown numbers.
5. Use the test Aether Blessing Voucher. Open Player Buffs and check the end time and listed bonuses.
6. Open an NPC shop and Aethernet. Check the shown Blessing discount. Do not test Shiny luck by counting a few encounters.
7. Choose the Blessed chat title on the Trainer Card and send one chat message.
8. Receive one item or money reward, catch a Pokémon, and level up the prepared Pokémon.
9. Check the stacked reward cards, pictures, amounts, and one sound for the reward group.
10. If a Live Event is active, check System chat, the on-screen card, and its time left.
11. Log out and check the hunt, Blessing time, title, and rewards again.

PASS WHEN
• Tracker numbers change only for the correct encounters and the shared card opens.
• Blessing time and bonuses are clear and the shop or travel price has the shown discount.
• Every reward card shows the correct item, Pokémon, or amount once.
• Live Event text and time match in chat and on screen.

SEND BACK
Result:
Failed step:
Tracker number, Blessing time, or reward amount:
Bug link:
```

---

## Post 29 — Easy bug report

Copy the message from `🐛 BUG REPORT` through the final three backticks into
Discord. If you do not know an answer, write `I do not know`.

````text
🐛 BUG REPORT

**Short name:** [WHAT WENT WRONG AND WHERE?]
**Test number:** [FOR EXAMPLE: TEST 07]
**Game version:** [GAME VERSION]
**Character name:** [NO EMAIL OR PASSWORD]
**Computer:** [WINDOWS / LINUX / MACOS]
**Place in the game:** [MAP OR MENU]

**How big is the problem?**
[BLOCKER: I CANNOT CONTINUE]
[HIGH: A MAIN FEATURE DOES NOT WORK]
[MEDIUM: I CAN CONTINUE IN ANOTHER WAY]
[LOW: SMALL TEXT, SOUND, OR PICTURE PROBLEM]

**What did you have before the test?**
[ACCOUNT, POKÉMON, ITEMS, QUEST, OR OTHER START INFORMATION]

**What did you do?**
1. [FIRST STEP]
2. [SECOND STEP]
3. [THIRD STEP]

**What should happen?**
[EXPECTED RESULT]

**What happened?**
[ACTUAL RESULT]

**Did it happen every time?** [YES / NO / ONLY ONE TIME]
**Does it still happen after restarting the game?** [YES / NO / NOT TESTED]
**Picture or video:** [ADD IT HERE]
```
````

## Post 30 — Test a completed fix

```text
🔁 PLEASE TEST THIS FIX

Fixed problem: [BUG NAME]
Bug link: [LINK]
New game version: [GAME VERSION]
Tester: [TESTER NAME]
Main test: [TEST NUMBER]

STEPS
1. Use the same account and start point from the bug report.
2. Follow the old bug steps exactly.
3. Check that the old problem is gone.
4. Finish every step in the main numbered test.
5. Close the game, log in again, and check the result one more time.

SEND BACK
Result: PASS / FAIL / BLOCKED
Old problem gone: YES / NO
Main test also passed: YES / NO
New bug link:

Please use the new game version. Do not test this fix on the old version.
```
