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

