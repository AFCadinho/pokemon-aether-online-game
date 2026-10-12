extends Node3D
## Twelve independent actors share the presenter's verified resources, never battle slots.
const ActionMap = preload("res://scripts/battle/animations/model_action_map.gd")
const SurfaceOrder = preload("res://scripts/battle/battle_ui/material_surface_order.gd")
const SourceVisibility = preload("res://scripts/battle/animations/reviewed_source_visibility.gd")
var slots: Array[Dictionary] = []
var nameplate_layer: Control
var name_font: FontFile
const NAME_FONT_SIZE := 18
const MAX_NAME_WIDTH := 240.0
const NAME_GAP := 8.0

func build(stage: Node, teams: Array) -> void:
	set_meta("battle_field_visual", true)
	nameplate_layer = Control.new()
	nameplate_layer.name = "TeamPreviewNameplates"
	nameplate_layer.set_meta("battle_preview_nameplates", true)
	nameplate_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate_layer.z_index = 2
	stage.add_child(nameplate_layer)
	nameplate_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_font = preload("res://assets/fonts/DejaVuSans.ttf").duplicate()
	name_font.multichannel_signed_distance_field = true
	name_font.fallbacks = [preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")]
	var origin: Vector3 = stage._position(0).lerp(stage._position(1), 0.5)
	var view: Vector3 = stage._default_camera_home() - stage.camera_target_for_preview()
	view.y = 0.0
	view = view.normalized()
	var right := Vector3(view.z, 0, -view.x)
	for side in 2:
		var sign_value := 1.0 if side == 0 else -1.0
		for index: int in teams[side].size():
			var identity: String = teams[side][index]
			var actor: Node3D = stage.packed[identity].instantiate()
			add_child(actor)
			var player: AnimationPlayer = stage._find_player(actor)
			var placement: Dictionary = stage.placements[identity]
			SurfaceOrder.apply(actor)
			var digest := str(stage.entries[identity].get("_verified_runtime_hash", ""))
			SourceVisibility.apply(actor, identity, digest)
			preload("res://scripts/battle/animations/gliscor_flight.gd").apply(player, identity, digest)
			preload("res://scripts/battle/animations/mega_garchomp_standing.gd").apply(player, identity, digest)
			preload("res://scripts/battle/animations/charmander_breath.gd").apply(player, identity, digest)
			if preload("res://scripts/battle/battle_ui/android_actor_exposure.gd").supported() and preload("res://scripts/battle/arenas/arena_catalog.gd").uses_outdoor_lighting(stage.arena_id):
				preload("res://scripts/battle/battle_ui/android_actor_exposure.gd").apply(actor)
			var mapped := ActionMap.resolve("idle", player.get_animation_list(), stage.entries[identity].action_timing)
			if not mapped.is_empty():
				var clip := player.get_animation(mapped.clip)
				clip.length = mapped.duration
				clip.loop_mode = Animation.LOOP_LINEAR
				player.play(mapped.clip, -1, mapped.speed)
				player.advance(0.0)
			var bounds := _bounds(actor)
			var authored_scale := float(placement.scale)
			var dimensions := bounds.size * authored_scale
			var shrink := minf(1.0, 1.65 / maxf(maxf(dimensions.x, dimensions.z), maxf(dimensions.y, 0.01)))
			actor.scale = Vector3.ONE * authored_scale * shrink
			actor.rotation.y = atan2(-view.x * sign_value, -view.z * sign_value) + deg_to_rad(float(placement.yaw_degrees))
			# Stagger the rows so the rear three cannot hide behind the front three.
			var row := index / 3
			var column := (index % 3) - 1.0 + (-0.25 if row == 0 else 0.25)
			var point: Vector3 = origin + view * sign_value * (2.7 + row * 1.8) + right * (column * 2.6 - sign_value * 1.4)
			point.y += (float(placement.lift) + float(placement.get("hover_height", 0.0))) * shrink
			actor.position = point
			var top := bounds.get_center()
			top.y = bounds.end.y
			var plate: PanelContainer = _create_nameplate() if side == 1 else null
			var connector: Line2D
			if plate != null:
				connector = Line2D.new()
				connector.width = 1.2
				connector.default_color = Color(0.75, 0.65, 0.95, 0.45)
				connector.z_index = -1
				nameplate_layer.add_child(connector)
			slots.append({"actor": actor, "player": player, "identity": identity, "side": side, "index": index,
				"nameplate": plate, "name_anchor": top, "connector": connector})
	set_names(stage.preview_names)
	update_nameplates(stage)

func _create_nameplate() -> PanelContainer:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.025, 0.03, 0.065, 0.94)
	card.border_color = Color(0.67, 0.5, 0.95, 0.9)
	card.set_border_width_all(1)
	card.set_corner_radius_all(5)
	card.content_margin_left = 10.0
	card.content_margin_right = 10.0
	card.content_margin_top = 4.0
	card.content_margin_bottom = 4.0
	plate.add_theme_stylebox_override("panel", card)
	nameplate_layer.add_child(plate)
	var label := Label.new()
	label.name = "SpeciesName"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	label.add_theme_font_override("font", name_font)
	label.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	plate.add_child(label)
	return plate

func set_names(names: Array) -> void:
	for slot in slots:
		if not is_instance_valid(slot.nameplate): continue
		var label := slot.nameplate.get_node("SpeciesName") as Label
		label.text = str(names[slot.side][slot.index])
		_fit_nameplate(slot.nameplate, label)

func _fit_nameplate(plate: PanelContainer, label: Label) -> void:
	var font_size := label.get_theme_font_size("font_size")
	var width := name_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	label.custom_minimum_size = Vector2(minf(width, MAX_NAME_WIDTH), ceilf(name_font.get_height(font_size)))
	# Reset explicit size when a same-model roster update shortens the name.
	plate.size = plate.get_combined_minimum_size()

func update_nameplates(stage: Node) -> void:
	if not is_instance_valid(nameplate_layer): return
	nameplate_layer.visible = visible and stage.active
	if not nameplate_layer.visible or not is_instance_valid(stage.camera) or not is_instance_valid(stage.viewport): return
	var screen: Transform2D = stage.get_viewport().get_final_transform() * nameplate_layer.get_global_transform_with_canvas()
	var ui_scale := float(stage.get_tree().root.get_node("SettingsManager").ui_scale) / 100.0
	# Three columns need room for both the names and the staggered rear row.
	var pixels := minf(NAME_FONT_SIZE * ui_scale, stage.size.x * screen.x.length() / 40.0)
	var font_size := maxi(8, roundi(pixels / maxf(0.1, screen.y.length())))
	var occupied: Array[Rect2] = []
	for slot in slots:
		var plate: PanelContainer = slot.nameplate
		if not is_instance_valid(plate): continue
		var label := plate.get_node("SpeciesName") as Label
		if label.get_theme_font_size("font_size") != font_size:
			label.add_theme_font_size_override("font_size", font_size)
			_fit_nameplate(plate, label)
		var point: Vector3 = slot.actor.global_transform * slot.name_anchor
		plate.visible = not stage.camera.is_position_behind(point)
		slot.connector.visible = plate.visible
		if not plate.visible: continue
		var anchor: Vector2 = stage.camera.unproject_position(point) * stage.size / Vector2(stage.viewport.size)
		var desired := anchor - Vector2(plate.size.x * 0.5, plate.size.y + NAME_GAP)
		desired.x = clampf(desired.x, NAME_GAP, maxf(NAME_GAP, stage.size.x - plate.size.x - NAME_GAP))
		desired.y = maxf(NAME_GAP, desired.y)
		# Keep neighboring names readable when tall bodies or a narrow field bring
		# their projected anchors together. Prefer raising a card directly above
		# its body; a shifted card gets a subtle connector to its own model.
		plate.position = _free_position(desired, plate.size, occupied, stage.size.x)
		slot.connector.visible = not plate.position.is_equal_approx(desired)
		slot.connector.points = PackedVector2Array([plate.position + Vector2(plate.size.x * 0.5, plate.size.y), anchor])
		occupied.append(plate.get_rect())

func _free_position(desired: Vector2, card_size: Vector2, occupied: Array[Rect2], field_width: float) -> Vector2:
	var columns: Array[float] = [desired.x]
	for rect in occupied:
		columns.append(rect.position.x - card_size.x - 6.0)
		columns.append(rect.end.x + 6.0)
	columns.sort_custom(func(a: float, b: float): return absf(a - desired.x) < absf(b - desired.x))
	# First keep the horizontal anchor, then try the nearest clear column.
	for x in columns:
		if x < NAME_GAP or x + card_size.x > field_width - NAME_GAP: continue
		for attempt in occupied.size() + 1:
			var candidate := Vector2(x, desired.y - attempt * (card_size.y + 6.0))
			if candidate.y < NAME_GAP: break
			if not occupied.any(func(rect: Rect2): return rect.grow(3.0).intersects(Rect2(candidate, card_size))):
				return candidate
	return desired

func set_presentation_visible(value: bool) -> void:
	visible = value
	if is_instance_valid(nameplate_layer): nameplate_layer.visible = value

func _bounds(actor: Node3D) -> AABB:
	var result := AABB()
	var meshes := actor.find_children("*", "MeshInstance3D", true, false)
	if actor is MeshInstance3D: meshes.append(actor)
	for mesh in meshes:
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var box: AABB = (actor.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		result = result.merge(box) if result.has_volume() else box
	return result

func animate(speed: float) -> void:
	for slot in slots:
		slot.player.speed_scale = maxf(speed, 0.0)

func cancel() -> void:
	hide()
	_clear_nameplates()
	for slot in slots:
		slot.player.stop()
	slots.clear()
	queue_free()

func _clear_nameplates() -> void:
	if not is_instance_valid(nameplate_layer): return
	nameplate_layer.hide()
	nameplate_layer.queue_free()
	nameplate_layer = null

func _exit_tree() -> void:
	_clear_nameplates()
