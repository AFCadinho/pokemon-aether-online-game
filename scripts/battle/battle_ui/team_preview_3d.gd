extends Node3D
## Twelve independent actors share the presenter's verified resources, never battle slots.
const ActionMap = preload("res://scripts/battle/animations/model_action_map.gd")
const SurfaceOrder = preload("res://scripts/battle/battle_ui/material_surface_order.gd")
const SourceVisibility = preload("res://scripts/battle/animations/reviewed_source_visibility.gd")
var slots: Array[Dictionary] = []
var nameplate_layer: Control
var name_font: FontFile
const NAME_FONT_SIZE := 15
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
			var meshes := actor.find_children("*", "MeshInstance3D", true, false)
			if actor is MeshInstance3D: meshes.append(actor)
			var bounds := _bounds(actor, meshes)
			# Reviewed idle envelopes include skeletal motion beyond the bind mesh.
			var sampled: Dictionary = stage.visual_bounds.get(identity, {}).get("idle", {})
			var idle_bounds := AABB()
			if not sampled.is_empty():
				idle_bounds = AABB(Vector3(sampled.min[0], sampled.min[1], sampled.min[2]), Vector3(sampled.size[0], sampled.size[1], sampled.size[2]))
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
			var plate: PanelContainer = _create_nameplate() if side == 1 else null
			var connector: Line2D
			if plate != null:
				connector = Line2D.new()
				connector.width = 1.2
				connector.default_color = Color(0.75, 0.65, 0.95, 0.45)
				connector.z_index = -1
				nameplate_layer.add_child(connector)
			slots.append({"actor": actor, "player": player, "identity": identity, "side": side, "index": index,
				"nameplate": plate, "bounds_meshes": meshes, "idle_bounds": idle_bounds, "connector": connector})
	_sample_idle_bounds()
	set_names(stage.preview_names)
	update_nameplates(stage)

func _sample_idle_bounds() -> void:
	# Older approved models have no measured idle envelope. Sample their skin
	# once during construction, rather than baking vertices every rendered frame.
	if DisplayServer.get_name() == "headless": return
	var unmeasured: Array[Dictionary] = []
	for slot in slots:
		if not slot.idle_bounds.has_volume() and slot.bounds_meshes.any(func(mesh): return mesh.skin != null):
			unmeasured.append(slot)
	if unmeasured.is_empty(): return
	var positions: Array[float] = []
	for slot in unmeasured: positions.append(slot.player.current_animation_position)
	for sample in 8:
		for slot in unmeasured:
			slot.player.seek(slot.player.current_animation_length * sample / 8.0, true, true)
			for skeleton in slot.actor.find_children("*", "Skeleton3D", true, false):
				skeleton.force_update_all_bone_transforms()
		# Skinning data used by bake_mesh is synchronized by the renderer.
		RenderingServer.force_draw(false)
		for slot in unmeasured:
			var posed := AABB()
			for mesh in slot.bounds_meshes:
				if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
				var shape: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
				if shape == null: shape = mesh.mesh
				var box: AABB = (slot.actor.global_transform.affine_inverse() * mesh.global_transform) * shape.get_aabb()
				posed = posed.merge(box) if posed.has_volume() else box
			if posed.has_volume():
				slot.idle_bounds = slot.idle_bounds.merge(posed) if slot.idle_bounds.has_volume() else posed
	for index in unmeasured.size(): unmeasured[index].player.seek(positions[index], true, true)
	for slot in unmeasured:
		for skeleton in slot.actor.find_children("*", "Skeleton3D", true, false):
			skeleton.force_update_all_bone_transforms()
	RenderingServer.force_draw(false)

func _create_nameplate() -> PanelContainer:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.025, 0.03, 0.065, 0.94)
	card.border_color = Color(0.67, 0.5, 0.95, 0.9)
	card.set_border_width_all(1)
	card.set_corner_radius_all(5)
	card.content_margin_left = 8.0
	card.content_margin_right = 8.0
	card.content_margin_top = 3.0
	card.content_margin_bottom = 3.0
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
	var gap := NAME_GAP / maxf(0.1, screen.y.length())
	var occupied: Array[Rect2] = []
	var projected: Array[Rect2] = []
	# Project the whole volume, including its depth, rather than the midpoint
	# of its highest face. A tilted camera can put another corner higher on screen.
	for slot in slots:
		var bounds := _projected_bounds(stage, slot)
		projected.append(bounds)
		if bounds.has_area(): occupied.append(bounds.grow(gap))
	var cards: Array[Dictionary] = []
	for index in slots.size():
		var slot: Dictionary = slots[index]
		var plate: PanelContainer = slot.nameplate
		if not is_instance_valid(plate): continue
		var label := plate.get_node("SpeciesName") as Label
		if label.get_theme_font_size("font_size") != font_size:
			label.add_theme_font_size_override("font_size", font_size)
			_fit_nameplate(plate, label)
		var bounds: Rect2 = projected[index]
		plate.visible = bounds.has_area()
		slot.connector.hide()
		if not plate.visible: continue
		var anchor := Vector2(bounds.get_center().x, bounds.position.y)
		var desired := anchor - Vector2(plate.size.x * 0.5, plate.size.y + gap)
		desired.x = clampf(desired.x, gap, maxf(gap, stage.size.x - plate.size.x - gap))
		cards.append({"slot": slot, "anchor": anchor, "desired": desired})
	# Place the upper row first, so lower names can stay close to their models.
	cards.sort_custom(func(a: Dictionary, b: Dictionary): return a.desired.y < b.desired.y if a.desired.y != b.desired.y else a.desired.x < b.desired.x)
	for card in cards:
		var slot: Dictionary = card.slot
		var plate: PanelContainer = slot.nameplate
		var position := _free_position(card.desired, plate.size, occupied, stage.size.x, gap)
		# When the user zooms a model off-screen there may be no room above it.
		# Hide its plate until it fits instead of clamping it onto the model.
		plate.visible = position.is_finite()
		if not plate.visible: continue
		plate.position = position
		slot.connector.visible = absf(position.x - card.desired.x) > gap * 0.5
		slot.connector.points = PackedVector2Array([position + Vector2(plate.size.x * 0.5, plate.size.y), card.anchor])
		occupied.append(plate.get_rect().grow(gap * 0.5))

func _projected_bounds(stage: Node, slot: Dictionary) -> Rect2:
	var bounds := _bounds(slot.actor, slot.bounds_meshes)
	if slot.idle_bounds.has_volume(): bounds = bounds.merge(slot.idle_bounds)
	var result := Rect2()
	for corner in 8:
		var point: Vector3 = slot.actor.global_transform * bounds.get_endpoint(corner)
		if stage.camera.is_position_behind(point): return Rect2()
		var projected: Vector2 = stage.camera.unproject_position(point) * stage.size / Vector2(stage.viewport.size)
		result = Rect2(projected, Vector2.ZERO) if corner == 0 else result.expand(projected)
	return result if result.intersection(Rect2(Vector2.ZERO, stage.size)).has_area() else Rect2()

func _free_position(desired: Vector2, card_size: Vector2, occupied: Array[Rect2], field_width: float, gap: float) -> Vector2:
	var columns: Array[float] = [desired.x]
	for rect in occupied:
		columns.append(rect.position.x - card_size.x)
		columns.append(rect.end.x)
	var best := Vector2.INF
	var best_distance := INF
	for x in columns:
		if x < gap or x + card_size.x > field_width - gap: continue
		var y := desired.y
		for attempt in occupied.size() + 1:
			if y < gap: break
			var candidate := Rect2(Vector2(x, y), card_size)
			var next_y := y
			for rect in occupied:
				if rect.intersects(candidate): next_y = minf(next_y, rect.position.y - card_size.y - 0.1)
			if next_y == y:
				var distance := absf(x - desired.x) * 1.5 + absf(y - desired.y)
				if distance < best_distance:
					best = candidate.position
					best_distance = distance
				break
			y = next_y
	return best

func set_presentation_visible(value: bool) -> void:
	visible = value
	if is_instance_valid(nameplate_layer): nameplate_layer.visible = value

func _bounds(actor: Node3D, meshes: Array) -> AABB:
	var result := AABB()
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
