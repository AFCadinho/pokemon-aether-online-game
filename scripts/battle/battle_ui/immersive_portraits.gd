extends Node
## Presentation mirrors existing trainer identity/commands, never battle authority.
var battle: Control
var cards: Array[Panel] = []
var heads: Array[Control] = []
var art: Array[TextureRect] = []
var commands: Array[Label] = []
var appearances: Array[Dictionary] = [{}, {}]
var speakers: Array[Control] = []
var figures: Array[Node2D] = []
var figure_textures: Array[Texture2D] = [null, null]

func _ready() -> void:
	for index in 2:
		var card := Panel.new()
		card.name = "TrainerPortrait" + str(index)
		card.size = Vector2(64,64)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.z_index = 80
		var style := StyleBoxFlat.new()
		style.bg_color = Color("071323ef")
		style.border_color = Color("329bdf")
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		card.add_theme_stylebox_override("panel", style)
		battle.get_node("%BattleStage").add_child(card)
		cards.append(card)
		var head := preload("res://scripts/ui/trainer_head_portrait.gd").new()
		card.add_child(head)
		head.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		heads.append(head)
		var texture := TextureRect.new()
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(texture)
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.append(texture)
		var command := Label.new()
		command.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		command.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		command.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		command.add_theme_font_size_override("font_size",14)
		var bubble_style := style.duplicate() as StyleBoxFlat
		bubble_style.content_margin_left = 10
		bubble_style.content_margin_right = 10
		bubble_style.content_margin_top = 8
		bubble_style.content_margin_bottom = 8
		command.add_theme_stylebox_override("normal",bubble_style)
		command.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var speaker := Control.new()
		speaker.name = "SpeakingTrainer" + str(index)
		speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speaker.z_index = 80
		speaker.hide()
		battle.get_node("%BattleStage").add_child(speaker)
		speakers.append(speaker)
		var figure := Node2D.new()
		speaker.add_child(figure)
		figures.append(figure)
		speaker.add_child(command)
		commands.append(command)

func _process(_delta: float) -> void:
	var stage: Control = battle.battle_stage
	for index in 2:
		var trainer = battle.player_trainer_sprite if index == 0 else battle.enemy_trainer_sprite
		var source = battle.vs_panel_container.player_1_portrait if index == 0 else battle.vs_panel_container.player_2_portrait
		var state: Dictionary = trainer.player_appearance_state
		if state.is_empty() and source != null:
			state = source.appearance_state
		# Wild encounters still have a local player, but no opposing trainer.
		if index == 0 and state.is_empty() and not trainer.visible and not battle._is_spectator_battle() and not battle.replay_mode:
			state = PlayerSave.to_appearance_state()
		var identity_changed := state != appearances[index]
		if identity_changed:
			appearances[index] = state.duplicate(true)
			if not state.is_empty():
				heads[index].set_appearance_state(state)
		heads[index].visible = not state.is_empty()
		var texture: Texture2D = trainer.catalog_sprite.texture
		if texture == null and trainer.npc_sprite.sprite_frames != null:
			texture = trainer.npc_sprite.sprite_frames.get_frame_texture(trainer.npc_sprite.animation, trainer.npc_sprite.frame)
		art[index].texture = texture
		art[index].visible = state.is_empty() and texture != null and trainer.visible
		if identity_changed or texture != figure_textures[index]:
			figure_textures[index] = texture
			_rebuild_figure(index, state, texture)
		cards[index].visible = heads[index].visible or art[index].visible
		cards[index].position = Vector2(18 if index == 0 else stage.size.x - 82, 12)
		# Keep command generation/visibility semantics, suppress only stage artwork.
		trainer.modulate.a = 0.0
		var callout = trainer.command_callout
		commands[index].text = callout.message_label.text
		commands[index].visible = callout.visible and trainer.visible
		# Mirror the existing callout lifetime: no second timer or gameplay delay.
		speakers[index].visible = commands[index].visible
		speakers[index].modulate.a = callout.modulate.a
		var width := minf(350.0, stage.size.x * 0.5 - 100.0)
		var slide: float = (1.0 - callout.modulate.a) * 18.0
		speakers[index].position = Vector2(88.0 - slide if index == 0 else stage.size.x - 88.0 - width + slide, 150.0)
		figures[index].position.x = 60.0 if index == 0 else width - 60.0
		var bubble_width := minf(200.0, maxf(100.0, width - 100.0))
		commands[index].position = Vector2(56.0 if index == 0 else width - 56.0 - bubble_width, -58.0)
		commands[index].size = Vector2(bubble_width, 64.0)
		if source != null:
			source.hide()

func _rebuild_figure(index: int, state: Dictionary, fallback: Texture2D) -> void:
	var figure := figures[index]
	for child in figure.get_children():
		child.free()
	var layers: Array[Dictionary] = []
	if not state.is_empty():
		layers.assign(BattlePlayerTrainerCatalog.build_layers(state))
	if layers.is_empty() and fallback != null:
		layers.append({"texture": fallback, "scale": 1.0})
	var bounds := Rect2()
	for layer in layers:
		var texture := layer.get("texture") as Texture2D
		if texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2.ONE * float(layer.get("scale", 1.0))
		sprite.flip_h = index == 0 and not state.is_empty()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		figure.add_child(sprite)
		var used := texture.get_image().get_used_rect()
		var rect := Rect2((Vector2(used.position) - texture.get_size() * 0.5) * sprite.scale, Vector2(used.size) * sprite.scale)
		if sprite.flip_h:
			rect.position.x = -rect.end.x
		bounds = rect if not bounds.has_area() else bounds.merge(rect)
	if bounds.has_area():
		var factor := minf(112.0 / bounds.size.x, 180.0 / bounds.size.y)
		figure.scale = Vector2.ONE * factor
		# Center each layer on the same visible-art bounds, like the trainer card.
		for sprite: Sprite2D in figure.get_children():
			sprite.position = -Vector2(bounds.get_center().x, bounds.position.y)
	figure.position.y = 0.0
