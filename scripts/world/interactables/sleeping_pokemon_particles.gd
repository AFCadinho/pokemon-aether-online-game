@tool
extends Node2D
## Small pixel Zs drift from the sleeper's head, then fade away.

const CYCLE_SECONDS := 3.6
const GLYPH := ["11111", "00010", "00100", "01000", "11111"]
const INK := Color("dcecf4")
const OUTLINE := Color("294653")

var _elapsed := 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	_elapsed = fmod(_elapsed + delta, CYCLE_SECONDS)
	queue_redraw()


func _draw() -> void:
	for index in range(3):
		var phase := fmod(_elapsed / CYCLE_SECONDS + float(index) / 3.0, 1.0)
		var opacity := smoothstep(0.0, 0.15, phase) * (1.0 - smoothstep(0.65, 1.0, phase))
		var origin := Vector2(phase * 17.0, -phase * 40.0).round()
		var pixels: Array[Vector2] = []
		for y in range(GLYPH.size()):
			for x in range(GLYPH[y].length()):
				if GLYPH[y][x] == "1":
					pixels.append(origin + Vector2(x, y) * 2.0)
		# Draw all outlines first to keep the solid pixel strokes connected.
		for pixel in pixels:
			draw_rect(Rect2(pixel - Vector2.ONE, Vector2(4, 4)), Color(OUTLINE, opacity))
		for pixel in pixels:
			draw_rect(Rect2(pixel, Vector2(2, 2)), Color(INK, opacity))
