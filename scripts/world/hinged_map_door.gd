extends "res://scripts/world/sliding_map_door.gd"
## Six pixel-aligned inward swing frames, hinged on the right jamb.
## Reuses the map artwork and shared proximity/access/arrival controller.

func _draw() -> void:
	if pieces.is_empty() or open_amount <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, panel_size), opening_color)
	var frame := clampi(ceili(open_amount * 6.0), 1, 6)
	var angle := frame * PI / 12.0
	var width := roundi(panel_size.x * cos(angle))
	# At 90 degrees the leaf and its edge are concealed by the fixed jamb.
	if width <= 0:
		return
	var depth := roundf(panel_size.y * 0.4 * sin(angle))
	var shade := Color.WHITE.darkened(0.25 * sin(angle))
	# The free edge travels UP into the building; both corners follow the
	# same arc. The old symmetric vertical squeeze looked like a sliding leaf.
	# Clip against the lintel instead of squashing the whole door to fit it.
	for column in range(width):
		var source_x := mini(int(float(column) / width * panel_size.x), int(panel_size.x) - 1)
		var rise := roundf(depth * (1.0 - float(column) / maxf(1.0, width - 1.0)))
		for piece: Dictionary in pieces:
			var region: Rect2 = piece.destination
			if source_x < region.position.x or source_x >= region.end.x:
				continue
			var source: Rect2 = piece.source
			source.position.x += source_x - region.position.x
			source.size.x = 1
			var top := region.position.y - rise
			var clipped_top := maxf(0.0, top)
			source.position.y += clipped_top - top
			source.size.y -= clipped_top - top
			if source.size.y > 0:
				draw_texture_rect_region(piece.texture, Rect2(panel_size.x - width + column, clipped_top, 1, source.size.y), source, shade)
	# A visible leaf edge and fixed hinge distinguish rotation from translation.
	var edge_width := 1.0 if frame < 3 else 2.0
	var edge_x := panel_size.x - maxf(width, edge_width)
	draw_rect(Rect2(edge_x, 0, edge_width, panel_size.y - depth), Color("34444b"))
