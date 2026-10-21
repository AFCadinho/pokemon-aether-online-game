extends "res://scripts/world/sliding_map_door.gd"
## Four pixel-aligned inward swing frames, hinged on the right jamb.
## Reuses the map artwork and shared proximity/access/arrival controller.

func _draw() -> void:
	if pieces.is_empty() or open_amount <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, panel_size), opening_color)
	var frame := clampi(ceili(open_amount * 4.0), 1, 4)
	var width := roundi(panel_size.x * cos(frame * PI / 8.0))
	if width <= 0:
		return
	# Vertical strips give the free edge depth while the hinge stays fixed.
	# Integer destinations and nearest filtering keep the original pixel style.
	for column in range(width):
		var source_x := mini(int(float(column) / width * panel_size.x), int(panel_size.x) - 1)
		var inset := roundf((1.0 - float(column) / width) * frame * 2.0)
		var height_scale := (panel_size.y - inset * 2.0) / panel_size.y
		for piece: Dictionary in pieces:
			var region: Rect2 = piece.destination
			if source_x < region.position.x or source_x >= region.end.x:
				continue
			var source: Rect2 = piece.source
			source.position.x += source_x - region.position.x
			source.size.x = 1
			var top := roundf(inset + region.position.y * height_scale)
			var bottom := roundf(inset + region.end.y * height_scale)
			draw_texture_rect_region(piece.texture, Rect2(panel_size.x - width + column, top, 1, bottom - top), source)
