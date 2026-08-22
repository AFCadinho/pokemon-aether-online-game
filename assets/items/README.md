# Item Assets

Item icons live under:

`res://assets/items/icons/`

Use item ids from the backend item metadata JSON as the canonical key. UI code should resolve icons through a small item icon service/helper instead of hardcoding individual paths in scenes.

Recommended lookup flow:

1. Normalize the item id, for example `poke-ball`.
2. Try matching an icon file in `res://assets/items/icons/`.
3. Fall back to a default missing-item icon when no exact match exists.

Reward data should continue to use item ids:

```json
{ "id": "potion", "quantity": 2 }
```

## Mega Champions Phase 3 provenance

The 45 Mega Stone icons referenced by `data/mega_champions_catalog.generated.json`
already existed in the tracked item-icon corpus before the rollout work. Their
repository introduction is recorded by commit
`e69fb3c38c2e326fd62e0e0be16465a252ccbf23` (2026-06-20).

The original upstream source and license were not recorded with that import.
They therefore remain blocked from public Mega Champions release until a
licensing review identifies and approves their provenance. Phase 3 does not
import, replace, or publish any item or Pokémon artwork.
