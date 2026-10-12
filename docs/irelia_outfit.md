# Irelia Outfit Box

Search Dev Tools → Add Item for `Irelia`; grant `irelia-outfit`.
One box fits both male and female models and contains six separately activated
items: Tunic (`Irelia_Shirt`, top), Trousers (`Irelia_Trousers`, bottom), Boots
(`Irelia_Shoes`, shoes), Hair (`Irelia_Hair`, hair), Circlet (`Irelia_Circlet`,
headgear), and Floating Blades (`Irelia_Blades`, Back).

Opening the box puts the six parts in the Bag. Activate each to unlock it in
Character Customization. Standard tradeable wardrobe rules apply; bound boxes
propagate binding to every component. Gender changes retain ownership and
resolve each item to the corresponding model. No role restriction or Store
offer is configured.

All 56 PNGs are byte-identical to Irelia revision 4; see
`irelia_asset_hashes.json`. Revision 3 simplifies the overworld blades into broader, five-colour silhouettes
and restores the right-facing hair coverage around the native ear. Revision 4
also covers rear scalp gaps with the original hair mask in every walking,
fishing and riding frame. Other directions, trainer art and all clothing
are unchanged.
Trainer images are 160×160. Overworld images are 256×256 with four 64×64 frames
per direction (down, left, right, up), including walking, fishing and riding.
Other movement styles use existing appearance fallbacks. Both the circlet and
hair use authored activity alignment, without extra offsets. Colours are fixed.

The tunic's thigh panel belongs to the top and renders over the trousers.
The two blade planes (`cape`, `cape_overlay`) follow one equipped Back item.
The game draws its rear-view overlay above clothing and below hair, using the
existing renderer ordering. No base sprites or global layer orders changed.

Validation: `tests/irelia_outfit_check.gd` covers resource resolution, all
movement styles, local/remote animation synchronization, fixed colours,
icons, translations and both genders; backend `tests.test_irelia_outfit`
covers grants, box contents, ownership, binding and gender changes.
