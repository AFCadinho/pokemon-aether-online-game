extends Node3D
## Offline inspection only; rendered after the stage and its move effects.
var stage: Node
var selected_move: Callable
var enabled: Callable
var markers: Array[MeshInstance3D] = []
var labels: Array[Label3D] = []
func _init() -> void:
	process_priority = 12
	set_meta("battle_field_visual", true)
func _process(_delta: float) -> void:
	var cursor := 0
	if is_instance_valid(stage) and stage.active and enabled.call():
		for pair in [["p1", "p2"], ["p2", "p1"]]:
			if stage._move_visual(pair[0]) == null or stage._move_visual(pair[1]) == null: continue
			var anchors: Dictionary = stage._move_anchors(pair[0], pair[1], selected_move.call())
			for i in anchors.sources.size():
				if cursor >= markers.size(): _add_marker()
				markers[cursor].position = anchors.sources[i]
				markers[cursor].show()
				labels[cursor].position = anchors.sources[i] + Vector3.UP * (0.16 + 0.12 * i)
				labels[cursor].text = anchors.attachment_part + (" " + str(i + 1) if anchors.sources.size() > 1 else "")
				labels[cursor].show()
				cursor += 1
	for i in range(cursor, markers.size()):
		markers[i].hide()
		labels[i].hide()
func _add_marker() -> void:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	marker.mesh = sphere
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.MAGENTA
	material.no_depth_test = true
	marker.material_override = material
	add_child(marker)
	markers.append(marker)
	var label := Label3D.new()
	label.font_size = 28
	label.pixel_size = 0.0025
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	labels.append(label)
