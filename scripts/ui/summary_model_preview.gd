extends "res://scripts/ui/pokedex_model_preview.gd"
## Card-owned preview; never modifies animations in shared model resources.
var clips: OptionButton
var replay: Button
var pause: Button
var configured_player: AnimationPlayer

func _ready() -> void:
	super._ready()
	tooltip_text = "Drag to rotate the 3D model"
	var controls := HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 6
	controls.offset_top = -64
	controls.offset_bottom = -38
	controls.add_theme_constant_override("separation", 3)
	add_child(controls)
	clips = OptionButton.new()
	clips.name = "ModelAnimations"
	clips.custom_minimum_size.x = 125
	clips.fit_to_longest_item = false
	clips.add_theme_font_size_override("font_size", 11)
	controls.add_child(clips)
	clips.item_selected.connect(func(_index): play_selected())
	replay = Button.new()
	replay.text = "↻"
	replay.tooltip_text = "Replay animation"
	controls.add_child(replay)
	replay.pressed.connect(play_selected)
	pause = Button.new()
	pause.text = "Ⅱ"
	pause.tooltip_text = "Pause / resume animation"
	controls.add_child(pause)
	pause.pressed.connect(toggle_pause)
	for button: BaseButton in [clips, replay, pause]:
		button.add_theme_color_override("font_color", Color("dcecf7"))
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("10344b") if state in ["hover", "pressed"] else Color("071827")
			style.border_color = Color("3f7d98")
			style.set_border_width_all(1)
			style.set_corner_radius_all(4)
			style.content_margin_left = 5
			style.content_margin_right = 5
			button.add_theme_stylebox_override(state, style)
	_set_controls_enabled(false)

func _set_controls_enabled(enabled: bool) -> void:
	clips.disabled = not enabled
	replay.disabled = not enabled
	pause.disabled = not enabled

func _process(delta: float) -> void:
	# Hidden cards consume neither animation updates nor render frames.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if not is_visible_in_tree():
		if player != null:
			player.active = false
		return
	if player != null:
		player.active = true
	super._process(delta)
	if player == null or player == configured_player:
		return
	configured_player = player
	clips.clear()
	for clip in player.get_animation_list():
		if clip == "RESET":
			continue
		clips.add_item(String(clip).replace("_", " ").capitalize())
		clips.set_item_metadata(clips.item_count - 1, clip)
		if clip == "idle":
			clips.select(clips.item_count - 1)
	_set_controls_enabled(clips.item_count > 0)
	status.text = ""
	_fit_model()
	play_selected()

func play_selected() -> void:
	if player == null or clips.selected < 0:
		return
	var clip := str(clips.get_item_metadata(clips.selected))
	if not player.has_animation(clip):
		return
	player.stop()
	player.play(clip)
	player.advance(0)
	pause.text = "Ⅱ"

func toggle_pause() -> void:
	if player == null:
		return
	if player.is_playing():
		player.pause()
		pause.text = "▶"
	else:
		player.play()
		pause.text = "Ⅱ"

func _fit_model() -> void:
	var bounds := AABB()
	var found := false
	for mesh in actor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found:
		return
	var radius := maxf(bounds.size.length() * 0.5, 0.1)
	var target := bounds.get_center()
	camera.position = target + Vector3(0, 0.1, 1).normalized() * radius * 4.5
	camera.look_at(target)
	camera.near = maxf(radius * 0.01, 0.001)
	camera.far = maxf(radius * 12, 10)

func _clear_actor() -> void:
	configured_player = null
	super._clear_actor()
	if clips != null:
		clips.clear()
		_set_controls_enabled(false)
