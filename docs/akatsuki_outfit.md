# Akatsuki outfit box

`akatsuki-outfit` (Akatsuki Outfit Box) contains four separate cosmetics for male and female players: `akatsuki-shirt`, `akatsuki-trousers`, `akatsuki-shoes` and `akatsuki-headband`. It is available through item grants/dev tools, with no Gift Store listing or role restriction. Search for `Akatsuki` in Add Item.

Opening the box puts the components in the Bag. Activating each one moves it to Character Customization. The robe uses Top, the trousers Bottom, sandals Shoes and the separate headband Headgear. Normal items follow the existing tradeable wardrobe lifecycle; bound box contents retain their binding. Logical appearance IDs and ownership survive gender changes.

The 32 PNGs are byte-identical to revision 2 of `designs/Akatsuki/Model Assets`. The robe is continuous fabric over the trousers down to the ankles, with a small lower opening. Both models have 160×160 trainer textures and 256×256 overworld sheets with authored walk/fish/ride frames. Existing movement fallbacks cover running, surfing, mounts, surf fishing and pickpocketing. Authored headgear poses use the existing offset handling. No body sprites or rendering code were changed.

`akatsuki_asset_hashes.json` records source mappings and SHA-256 hashes. The trainer manifest and generated cosmetic variant catalog register all four parts. Item labels and box descriptions are present in EN/NL/PT-BR/ZH-CN.

Focused checks: `tests/akatsuki_outfit_check.gd` (both genders, native textures, all movement fallbacks, icons, ownership classification, local/remote animation sync, headband activity offsets and presence). Paired backend `tests.test_akatsuki_outfit` checks box lifecycle, gender changes, binding and dev search.
