extends WorldInteractable

class_name PokemonTowerSpiritGate

## Presentation stays local; trusted battle settlement and the farewell receipt
## own the stair. Merely possessing a Scope can never open it.
const SCOPE_ITEM_ID := "silph-scope"
const QUEST_ID := "calm_pokemon_tower_spirit"
const CONFIRMATION := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const ActorFrames := preload("res://scripts/world/story/rocket_trio_actor.gd")
const REINA_FRAMES := preload("res://assets/npcs/classes/lass_frames.tres")

signal scope_selected(accepted: bool)

# Runtime lookup also allows isolated checks to preload this controller before
# GameState finishes loading its world scene.
var GameState: Node
var StoryService: Node
var InventoryService: Node
var StorySequenceRunner: Node
var GameErrorDialogService: Node
var LocalizationManager: Node
var TrainerPortraitCatalog: Node

var _story_player: Node2D
var _phase := ""
var _stage := 0
var _actors: Dictionary = {}
var _motion: Tween
var _menu_layer: CanvasLayer
var _particles: CPUParticles2D
var _auto_retry_after := 0


func _ready() -> void:
	GameState = get_node("/root/GameState")
	StoryService = get_node("/root/StoryService")
	InventoryService = get_node("/root/InventoryService")
	StorySequenceRunner = get_node("/root/StorySequenceRunner")
	GameErrorDialogService = get_node("/root/GameErrorDialogService")
	LocalizationManager = get_node("/root/LocalizationManager")
	TrainerPortraitCatalog = get_node("/root/TrainerPortraitCatalog")
	super._ready()
	_add_actor("Marowak", FollowerSpriteService.get_sprite_frames("marowak", false))
	_add_actor("Cubone", FollowerSpriteService.get_sprite_frames("cubone", false))
	var atlas := REINA_FRAMES.get_frame_texture(&"default", 0) as AtlasTexture
	_add_actor("Reina", ActorFrames.build_frames(atlas.atlas))
	_reset_actors()


func _process(delta: float) -> void:
	super._process(delta)
	# Settlement refreshes StoryService after the battle UI has closed. This
	# also resumes the farewell after reconnecting on 6F, without replaying it
	# every frame if a request fails.
	if (
		_is_farewell_active() and player_nearby and is_instance_valid(nearby_player)
		and not is_interacting and not GameState.is_overworld_input_locked()
		and not GameState.is_ui_input_locked() and Time.get_ticks_msec() >= _auto_retry_after
	):
		_auto_retry_after = Time.get_ticks_msec() + 5000
		await _start_manual_interaction(nearby_player)


func is_passage_open() -> bool:
	return StoryService.is_requirement_met(QUEST_ID, "farewell_marowak", "completed")


func can_reveal_spirit() -> bool:
	return (
		InventoryService.has_item(SCOPE_ITEM_ID)
		and StoryService.is_requirement_met("confront_team_rocket_boss", "confront_boss", "completed")
		and StoryService.is_requirement_met(QUEST_ID, "battle_marowak", "active")
	)


func _is_farewell_active() -> bool:
	return StoryService.is_requirement_met(QUEST_ID, "farewell_marowak", "active")


func blocks_world_position(world_position: Vector2) -> bool:
	return not is_passage_open() and super.blocks_world_position(world_position)


func _can_start_manual_interaction() -> bool:
	return not is_passage_open() and super._can_start_manual_interaction()


func interact_with_player(player: Node2D) -> void:
	await _run_story_or_legacy_interaction(player, "interact")


func _run_story_or_legacy_interaction(player: Node2D, _trigger: String) -> Dictionary:
	if is_passage_open():
		return {"success": true}
	_story_player = player
	_phase = ""
	if _is_farewell_active():
		return await _run_spirit_hook("farewell", "MarowakFarewell", player)
	var actions: Array = [{"type": "dialogue", "dialogueId": "kanto_pokemon_tower_spirit_warning"}]
	if not can_reveal_spirit():
		actions.append({"type": "dialogue", "dialogueId": "kanto_pokemon_tower_player_scope_needed"})
	var result: Dictionary = await StorySequenceRunner.run_sequence(actions, self, player)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_report_to_staff_message()
		return result
	if can_reveal_spirit() and await _ask_use_scope():
		return await _run_spirit_hook("battle", "MarowakChallenge", player)
	return {"success": true, "status": "declined"}


func _run_spirit_hook(phase: String, hook_name: String, player: Node2D) -> Dictionary:
	var hook := get_node_or_null(hook_name)
	if hook == null:
		await GameErrorDialogService.show_report_to_staff_message()
		return {"success": false}
	_phase = phase
	var result: Dictionary = await hook.try_handle_interaction(self, player, "interact")
	abort_story_sequence()
	return result


func prepare_story_sequence() -> Dictionary:
	_stage = 0
	_reset_actors()
	if _phase == "battle":
		_burst(Color(0.65, 0.8, 1.0))
		var marowak: AnimatedSprite2D = _actors.Marowak
		marowak.visible = true
		if is_instance_valid(_story_player):
			var offset := _story_player.global_position - global_position
			var direction := "down" if offset.y >= 0 else "up"
			if absf(offset.x) > absf(offset.y):
				direction = "right" if offset.x >= 0 else "left"
			marowak.play("idle_" + direction)
		marowak.modulate.a = 0.0
		_motion = create_tween()
		_motion.tween_property(marowak, "modulate:a", 0.8, 0.8)
		await _wait_for_motion()
	elif _phase == "farewell":
		var marowak: AnimatedSprite2D = _actors.Marowak
		marowak.visible = true
		# The current 6F art has a narrow stair passage. Meet Cubone in
		# the open room below it, following the actual walkable corridor.
		_motion = create_tween()
		_motion.tween_property(marowak, "position", Vector2(0, 64), 0.6)
		_motion.tween_property(marowak, "position", Vector2(-64, 64), 0.6)
		await _wait_for_motion()
		marowak.z_index = floori(global_position.y + 64)
		marowak.play("idle_left")
		await _move_visitors(true)
	return {"success": is_inside_tree()}


func show_dialogue(lines: Array[String] = [], speaker_name := "", _portrait: Texture2D = null) -> bool:
	var box := _get_dialogue_box()
	if box == null:
		return false
	var portrait: Texture2D
	if _phase == "farewell" and _stage in [0, 2, 4]:
		portrait = TrainerPortraitCatalog.get_texture(
			TrainerPortraitCatalog.resolve_portrait_id("", "kanto_lavender_fuji_helper", "trainer_class_lass"))
	elif _phase == "farewell" and _stage == 1:
		portrait = PokemonAssets.load_home_sprite("cubone", false)
	elif _phase == "battle" and _stage == 1:
		portrait = PokemonAssets.load_home_sprite("marowak", false)
	box.call("start_dialogue", lines, speaker_name, portrait, portrait != null)
	await box.dialogue_finished
	if _phase == "farewell" and _stage == 3:
		await _release_spirit()
	elif _phase == "farewell" and _stage == 4:
		await _move_visitors(false)
	_stage += 1
	return is_inside_tree()


func _ask_use_scope() -> bool:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 120
	add_child(_menu_layer)
	var dialog := CONFIRMATION.instantiate() as AetherConfirmationDialog
	_menu_layer.add_child(dialog)
	dialog.configure(LocalizationManager.text("ui.pokemon_tower.scope.title"),
		LocalizationManager.text("ui.pokemon_tower.scope.prompt"),
		LocalizationManager.text("common.yes"), LocalizationManager.text("common.no"))
	dialog.confirmed.connect(func(): scope_selected.emit(true), CONNECT_ONE_SHOT)
	dialog.canceled.connect(func(): scope_selected.emit(false), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(500, 250))
	var accepted: bool = await scope_selected
	if is_instance_valid(_menu_layer):
		_menu_layer.queue_free()
	_menu_layer = null
	return accepted


func _add_actor(actor_name: String, frames: SpriteFrames) -> void:
	var actor := AnimatedSprite2D.new()
	actor.name = actor_name
	actor.sprite_frames = frames
	actor.offset = Vector2(0, -16)
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.z_as_relative = false
	actor.z_index = floori(global_position.y)
	add_child(actor)
	_actors[actor_name] = actor


func _reset_actors() -> void:
	for actor: AnimatedSprite2D in _actors.values():
		actor.visible = false
		actor.modulate = Color.WHITE
		actor.position = Vector2.ZERO
		actor.play("idle_right" if actor.name == &"Marowak" else "idle_left")
	if _actors.has("Marowak"):
		(_actors.Marowak as AnimatedSprite2D).modulate = Color(0.8, 0.85, 1.0, 0.8)


func _move_visitors(arriving: bool) -> void:
	var reina: AnimatedSprite2D = _actors.Reina
	var cubone: AnimatedSprite2D = _actors.Cubone
	var targets := [Vector2(-128, 64), Vector2(-96, 64)]
	var actors: Array[AnimatedSprite2D] = [reina, cubone]
	_motion = create_tween().set_parallel(true)
	for index: int in range(actors.size()):
		var actor := actors[index]
		actor.visible = true
		actor.z_index = floori(global_position.y + 64)
		if arriving:
			actor.position = targets[index] - Vector2(128, 0)
		actor.play("walk_right" if arriving else "walk_left")
		_motion.tween_property(actor, "position", targets[index] if arriving else targets[index] - Vector2(128, 0), 1.2)
	await _wait_for_motion()
	for actor: AnimatedSprite2D in actors:
		actor.play("idle_right")
		actor.visible = arriving


func _release_spirit() -> void:
	var marowak: AnimatedSprite2D = _actors.Marowak
	_burst(Color(0.8, 0.9, 1.0))
	_motion = create_tween().set_parallel(true)
	_motion.tween_property(marowak, "position:y", marowak.position.y - 40.0, 1.5)
	_motion.tween_property(marowak, "modulate:a", 0.0, 1.5)
	await _wait_for_motion()
	marowak.visible = false


func _burst(tint: Color) -> void:
	if is_instance_valid(_particles):
		_particles.queue_free()
	_particles = CPUParticles2D.new()
	var marowak: AnimatedSprite2D = _actors.Marowak
	_particles.position = marowak.position + Vector2(0, -16)
	_particles.z_as_relative = false
	_particles.z_index = floori(global_position.y + marowak.position.y) + 1
	_particles.amount = 28
	_particles.lifetime = 1.4
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.direction = Vector2.UP
	_particles.spread = 100.0
	_particles.gravity = Vector2(0, -8)
	_particles.initial_velocity_min = 10.0
	_particles.initial_velocity_max = 30.0
	_particles.scale_amount_min = 1.0
	_particles.scale_amount_max = 2.0
	_particles.color = tint
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	_particles.color_ramp = fade
	add_child(_particles)
	_particles.emitting = true


func _wait_for_motion() -> void:
	while _motion != null and _motion.is_valid() and _motion.is_running():
		await get_tree().process_frame


func abort_story_sequence() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	_phase = ""
	_stage = 0
	_reset_actors()
	if is_instance_valid(_particles):
		_particles.queue_free()
	_particles = null


func _exit_tree() -> void:
	if is_instance_valid(_menu_layer):
		scope_selected.emit(false)
	abort_story_sequence()
