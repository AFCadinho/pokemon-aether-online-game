> **Upcoming gameplay update:** This guide describes the Daycare services prepared for the next gameplay update. Some options may not be available in your current client yet. Current in-game eligibility checks and quotes are authoritative.

The **Route 5 Daycare** is a place to prepare your Pokémon. Offline training is only one of its services: you can also improve IVs through **Aethering**, buy **Wings**, and choose a **Nature effect**.

## Find the right NPC

Enter the Daycare on **Route 5 in Kanto** and speak to the NPC for the service you need. The nearby PC helps you prepare your Party.

| NPC | Service |
| --- | --- |
| **Daycare Trainer** | Train EXP, EVs, or both while you are offline. |
| **Aether Keeper** | Use a compatible Donor to change a Recipient's IVs. |
| **Wing Merchant** | Buy optional IV locks for Aethering. |
| **Nature Specialist** | Apply a chosen Nature's stat effect to an eligible Pokémon. |

Bring the Pokémon you want to use **in your Party**. Being in your PC does not make it selectable in these service windows.

**EXP and levels, EVs, IVs, and Nature effects are different things.** Training does not improve IVs or change a Nature. Wings do not train EVs. Aethering does not add EXP or EVs.

## Offline EXP and EV training

### Start training

1. Speak to the **Daycare Trainer** and open **New training**.
2. Choose a Pokémon from your Party.
3. Enable **Train EXP**, **Train EVs**, or both.
4. Choose your target level and/or **final EV values**.
5. Select **Calculate cost**. Check the price, total duration and targets.
6. Select **Start training** and confirm payment.

The Pokémon leaves your Party while it trains. It cannot battle, trade or be used elsewhere until you collect it. You must keep at least one usable Pokémon in your Party when leaving another Pokémon here.

![Illustrative offline training setup and calculated cost](upload://zdBzopq30prEkuYknxugnC7CHoq.png)

*Example data shown in the game interface; this is not a live player transaction.*

### What the targets mean

- **EXP only:** gain the EXP needed for your target level, without EV training.
- **EVs only:** train the chosen EVs, **without gaining EXP**.
- **Both:** EXP and EV training run at the same time. The total duration is whichever takes longer, **not the two times added together**.

Your EXP target is limited by your current story progression. The displayed **Daycare level cap** prevents skipping story restrictions. Level 100 requires the appropriate League progression.

The price uses the **missing EXP**, not a fixed price per level. Pokémon with different growth curves can need different amounts of EXP for the same target level.

For EVs, enter the **final total for each stat**, not the number you want to add. Existing allocated EVs cannot be lowered here. The limits are **252 per stat** and **510 in total**. Stored EVs for a stat are used first; they do not count as newly trained EVs for the training charge.

### Price and time

Each Pokémon has its own one-time price:

**500 ₽ start fee + 1 ₽ per 20 missing EXP, rounded up + 50 ₽ per new EV.**

For example, 10,001 missing EXP and 100 new EVs cost **500 + 501 + 5,000 = 6,001 ₽**. Stored EV allocation can reduce the number of new EVs required.

The server calculates the duration using a fixed training reference. Double EXP, double EVs, Macho Brace, Power items and other manual training boosts do not speed up Daycare training. Check **Calculate cost** for your exact time; manual training with boosts can be faster.

### Up to six Pokémon, including while offline

You can have **up to six Pokémon training at once**, each with its own targets, price and timer. Training continues when you log out. To fill all six places, use the PC to replenish your Party between deposits while keeping a usable Party Pokémon.

Open **At the Daycare** to see each Pokémon's icon, targets and remaining time. **Pick up** becomes available after all selected training is complete. A finished Pokémon still occupies its place until collected.

![Illustrative active and finished Daycare training](upload://ywrF2NRuhKXmmtAmOsCMicdDgh1.png)

There is currently **no early pickup or cancellation**. You pay when training starts; there is no late collection fee. Collection goes to your Party when there is room, otherwise to your PC. If both are full, free a space and try again.

Training does not automatically overwrite moves or force evolution. Any available move or evolution choices are offered for review when you collect your Pokémon.

## Aethering: change IVs

Speak to the **Aether Keeper**. Choose two compatible Pokémon from your Party:

- **Recipient:** the Pokémon you keep.
- **Donor:** the Pokémon that is **permanently consumed**.

> **Aethering cannot be undone.** Review the two Pokémon and every IV outcome before confirming. A shiny Donor is still consumed; it does not make the Recipient shiny.

The pair must share at least one eligible **Egg Group**. Both groups count for Pokémon with two. Pokémon without an eligible group cannot be used. **Ditto only matches Ditto** here; it is not a universal partner.

### What happens to each IV?

| Situation | Result for the Recipient |
| --- | --- |
| Both Pokémon have the same IV in a stat, with no lock | That IV stays the same. |
| Their IVs differ, with no lock | That stat is rerolled randomly from **0 to 31**. |
| Recipient lock selected | Keep the Recipient's existing IV in that stat. |
| Donor lock selected | Copy the Donor's IV in that stat. |

A reroll is **not an average** and does **not guarantee an improvement**. Even a high IV can become 0. The preview displays **?** where the final IV is random.

You can select **at most one Recipient lock and one Donor lock**, on **different stats**. Each lock consumes one matching Wing.

![Illustrative Aethering comparison with guaranteed IVs and random outcomes](upload://53AKoWxN8CmBe8I2GeGGF5D1zqR.png)

For example, keep your Recipient's **31 ATK** with a Recipient lock and copy the Donor's **31 DEF** with a Donor lock. Other differing, unlocked IVs still reroll. Matching unlocked IVs stay unchanged.

### Wings are optional

Every Aethering costs **10,000 ₽**. With no locks selected, **no Wings are required**. Use **Without Wings** to remove both locks.

The **Wing Merchant** sells each Wing for **10,000 ₽**:

| Wing | Stat it can lock |
| --- | --- |
| Health Wing | HP |
| Muscle Wing | Attack |
| Resist Wing | Defense |
| Genius Wing | Special Attack |
| Clever Wing | Special Defense |
| Swift Wing | Speed |

If you need to buy all the Wings first, the combined cost is **10,000 ₽ without locks**, **20,000 ₽ with one lock**, or **30,000 ₽ with two locks**. Already owned Wings do not need to be bought again. The Merchant's Wing prices are not reduced by Blessing discounts.

In PokeAether these Wings are **Aethering IV locks**. They cannot be held and do not directly add IVs or EVs.

### Eligibility and what you keep

Remove the Donor's held item before using it. Protected Pokémon, such as original starters and other restricted Pokémon, may be unavailable. Active loans, rentals, trade reservations and similar commitments can also block a Pokémon. The selection window explains why a Party member cannot be used.

The Recipient keeps its species, level, EXP, EVs, Nature, shiny state and moves. Its IVs and resulting stats change. Aethering does not provide a free heal or revive.

## Nature Specialist: choose a stat effect

The **Nature Specialist** applies a chosen Nature's **stat effect**, similar to a Mint. The Pokémon's **original Nature remains recorded**.

1. Bring an eligible Pokémon in your Party.
2. Choose the Pokémon and the desired Nature effect.
3. Preview the **before and after stats** and the price.
4. Confirm only when the effect and price are right for you.

![Illustrative Nature treatment preview with stat differences and price](upload://85jKBqbggO8EDcaaptBEz4pgoae.png)

### Which Pokémon can be treated?

Normally, you must be the Pokémon's verified **Original Trainer**. Simply owning a traded Pokémon does not qualify. Buying back a Pokémon for which you are the verified Original Trainer can qualify.

Some staff gifts have explicit treatment permission. That permission is lost permanently if ownership is transferred; buying the gift back does not restore it. Other restrictions, including active loans, can still prevent treatment. Check the reason displayed beside an unavailable Party Pokémon.

### One treatment per account every seven days

You can complete **one successful Nature treatment per account per rolling seven days**. This is shared by all your Pokémon, including shinies. It does not reset on a particular weekday, and unused weeks do not stack.

Failed attempts do not charge money or start the cooldown. The window shows when another treatment becomes available.

### Default prices

The price depends on the Pokémon's **current species rarity**, with a default **10× multiplier for shinies**. Evolution can therefore change the price bracket.

| Current species rarity | Normal | Shiny |
| --- | ---: | ---: |
| Common | 125,000 ₽ | 1,250,000 ₽ |
| Uncommon | 250,000 ₽ | 2,500,000 ₽ |
| Rare | 500,000 ₽ | 5,000,000 ₽ |
| Very Rare | 1,000,000 ₽ | 10,000,000 ₽ |
| Ultra Rare | 2,000,000 ₽ | 20,000,000 ₽ |
| Legendary | 4,000,000 ₽ | 40,000,000 ₽ |

These are the default economy settings and may change during alpha. **Always check the current in-game quote.**

The paid stat effect remains through levelling, EV training, evolution, Aethering and trading. **Synchronize uses the original Nature**, not the paid Nature effect.

## Helpful guides

- [Pokémon stats: IVs, EVs and Natures](https://forums.pokeaether.com/t/100)
- [EV training](https://forums.pokeaether.com/t/28)
- [Story level caps](https://forums.pokeaether.com/t/85)
- [Pokémon Storage](https://forums.pokeaether.com/t/34)
- [Aether Band and Aether Power Band](https://forums.pokeaether.com/t/aether-training-items-aether-band-aether-power-band/110)