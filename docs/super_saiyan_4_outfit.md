# Super Saiyan 4 (SS4) Outfit Box

Search for `SS4` or `Super Saiyan 4` in dev tools → Add Item. Item ID:
`super-saiyan-4-outfit`. One box fits both male and female models and contains
five separately activated wardrobe items:

| Item | Wardrobe slot | Appearance |
| --- | --- | --- |
| super-saiyan-4-shirt | Top | SS4_Shirt |
| super-saiyan-4-trousers | Bottom | SS4_Trousers |
| super-saiyan-4-shoes | Shoes | SS4_Shoes |
| super-saiyan-4-hair | Hair | SS4_Hair |
| super-saiyan-4-tail | Back | SS4_Tail |

Opening the box puts five items in the Bag. Activate each to unlock it in
Character Customization. The usual tradeable wardrobe lifecycle applies;
account-bound boxes keep all contents bound. Gender changes preserve owned
and equipped parts. No role restriction applies. The box is sold under Gift
Store → Cosmetics → Outfits for **450 Gems**, or 450 personal card credits
under the existing alternate-payment policy. Gem purchases are tradeable; card
purchases and all their contents stay bound. The Store previews all five parts
on both trainer and overworld models. Loose parts are not sold separately.

The 48 PNGs are byte-identical to the approved revision 4 of
`designs/Super Saiyan 4/Model Assets`. `super_saiyan_4_asset_hashes.json` records
each source, game path and hash. Trainer textures are 160×160; overworld
sheets are 256×256 with authored walk/fish/ride poses. Existing fallbacks cover
running, surfing, mounts, surf fishing and pickpocketing. Authored hair poses
use the existing activity-offset handling.

The tail is one Back item, drawn by `cape` and `cape_overlay` with the same
appearance ID. Both layers follow the body animation. The hair uses its
approved fixed colours instead of the player's ordinary hair tint. Trainer
and overworld palettes retain their individually approved designs.

Only the male trainer top opts into `skin_tint` in the trainer manifest. Its
three original skin shades pass through the same exact-palette skin recolour
as the body; red fur, blue bands and all non-skin pixels stay unchanged. No
base sprites were modified. Item labels are available in EN/NL/PT-BR/ZH-CN.

Focused validation: `tests/super_saiyan_4_outfit_check.gd`, trainer preview
regressions, generated cosmetic catalog checks and paired backend
`tests.test_super_saiyan_4_outfit` (inventory, wardrobe, binding, gender changes,
dev search, Store eligibility, exact-price purchasing and payment binding).
