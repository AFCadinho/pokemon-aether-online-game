extends Node
## Presentation mirrors existing trainer identity/commands, never battle authority.
var battle: Control
var cards: Array[Panel] = []
var heads: Array[Control] = []
var art: Array[TextureRect] = []
var commands: Array[Label] = []
var appearances: Array[Dictionary] = [{}, {}]

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
		command.add_theme_font_size_override("font_size",14)
		command.add_theme_stylebox_override("normal",style)
		command.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(command)
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
		if state != appearances[index]:
			appearances[index] = state.duplicate(true)
			if not state.is_empty():
				heads[index].set_appearance_state(state)
		heads[index].visible = not state.is_empty()
		var texture: Texture2D = trainer.catalog_sprite.texture
		if texture == null and trainer.npc_sprite.sprite_frames != null:
			texture = trainer.npc_sprite.sprite_frames.get_frame_texture(trainer.npc_sprite.animation, trainer.npc_sprite.frame)
		art[index].texture = texture
		art[index].visible = state.is_empty() and texture != null and trainer.visible
		cards[index].visible = heads[index].visible or art[index].visible
		cards[index].position = Vector2(18 if index == 0 else stage.size.x - 82, 12)
		# Keep command generation/visibility semantics, suppress only stage artwork.
		trainer.modulate.a = 0.0
		var callout = trainer.command_callout
		commands[index].text = callout.message_label.text
		commands[index].visible = callout.visible and trainer.visible
		commands[index].modulate.a = callout.modulate.a
		commands[index].position = Vector2(76 if index == 0 else -246, 36)
		commands[index].size = Vector2(234,54)
		if source != null:
			source.hide()
