extends Control

## Kleine, asset-onafhankelijke spinner voor mapovergangen.
## De ring wordt getekend vanuit de actuele Control-grootte en schaalt daardoor
## zonder aparte textures mee met verschillende resoluties.

const TRACK_COLOR := Color(0.42, 0.56, 0.76, 0.24)
const SPINNER_COLOR := Color(0.72, 0.84, 1.0, 0.96)
const ROTATION_SPEED := 4.4

var phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	phase = fmod(phase + delta * ROTATION_SPEED, TAU)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(minf(size.x, size.y) * 0.34, 4.0)
	var width := maxf(radius * 0.18, 2.0)
	draw_arc(center, radius, 0.0, TAU, 48, TRACK_COLOR, width, true)
	draw_arc(center, radius, phase, phase + TAU * 0.68, 36, SPINNER_COLOR, width, true)
