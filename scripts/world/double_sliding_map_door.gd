extends "res://scripts/world/sliding_map_door.gd"
## Two leaves retract behind a fixed curved gym frame.

func _column_top(column: int) -> int:
	var edge := mini(column, int(panel_size.x) - 1 - column)
	return 0 if edge < 2 else (2 if edge < 10 else (4 if edge < 20 else 6))

func _draw() -> void:
	if pieces.is_empty() or open_amount <= 0.0:
		return
	var half := int(panel_size.x) / 2
	var offset := roundi(half * open_amount)
	for x in range(int(panel_size.x)):
		var top := _column_top(x)
		var bottom := top + int(panel_size.y) - 6
		draw_rect(Rect2(x, top, 1, bottom - top), opening_color)
		var source_x := x + offset if x < half else x - offset
		if (x < half and source_x >= half) or (x >= half and source_x < half):
			continue
		# Clip both the source leaf and destination opening, leaving the curved
		# lintel and sill stationary throughout the horizontal movement.
		var source_top := _column_top(source_x)
		for piece: Dictionary in pieces:
			var region: Rect2 = piece.destination
			if source_x < region.position.x or source_x >= region.end.x:
				continue
			var start := maxf(maxi(top, source_top), region.position.y)
			var end := minf(mini(bottom, source_top + int(panel_size.y) - 6), region.end.y)
			if end <= start:
				continue
			var source: Rect2 = piece.source
			source.position += Vector2(source_x - region.position.x, start - region.position.y)
			source.size = Vector2(1, end - start)
			draw_texture_rect_region(piece.texture, Rect2(x, start, 1, end - start), source)
