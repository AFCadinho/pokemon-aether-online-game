extends SceneTree

const Hud = preload("res://scripts/battle/battle_ui/immersive_hud.gd")

func _init() -> void:
	var extent := Vector2(182, 46)
	# An ordinary model leaves room above: preserve its centered HP panel.
	var centered := Vector2(315, 150)
	assert(Hud.clear_model_hud(centered, extent, Rect2(280, 208, 260, 300)) == centered)
	# A tall animation reaches the sprite top clamp: use available space above.
	for bounds in [Rect2(255, 100, 306, 360), Rect2(660, 99, 310, 330), Rect2(30, 100, 210, 360)]:
		var target := Vector2(bounds.get_center().x - extent.x / 2, 62)
		assert(Rect2(target, extent).intersects(bounds))
		var result := Hud.clear_model_hud(target, extent, bounds)
		assert(not Rect2(result, extent).intersects(bounds))
		assert(result.x == target.x and result.y >= 16)
		assert(bounds.position.y - (result.y + extent.y) >= 12)
	# If no space exists above, retain the target instead of moving offscreen.
	assert(Hud.clear_model_hud(Vector2(400, 62), extent, Rect2(0, 40, 1152, 500)) == Vector2(400, 62))
	print("battle_3d_tall_hud_check: PASS")
	quit()
