@tool
extends WorldInteractable

class_name AetherBeacon

signal activation_state_changed(activated: bool)

@export var destination_id := ""
@export_range(0.5, 4.0, 0.1) var animation_speed := 1.4

@onready var floating_visual: Node2D = get_node_or_null("FloatingVisual")
@onready var glow: CanvasItem = get_node_or_null("FloatingVisual/Glow")
@onready var ring: Node2D = get_node_or_null("FloatingVisual/Ring")
@onready var crystal: CanvasItem = get_node_or_null("FloatingVisual/Crystal")
@onready var core: CanvasItem = get_node_or_null("FloatingVisual/Crystal/Core")
@onready var sparks: Node2D = get_node_or_null("FloatingVisual/Sparks")
@onready var pedestal_rune: CanvasItem = get_node_or_null("Pedestal/Rune")

var _animation_time := 0.0
var _base_visual_position := Vector2.ZERO
var _activated := false


func _ready() -> void:
	interactable_kind = "aether_beacon"
	# Beacons are intentionally usable from every side. Keep this invariant in
	# code so stale inherited-scene overrides cannot silently disable attuning.
	requires_facing = false
	interaction_shape_size = Vector2(80, 80)
	display_name = LocalizationManager.text("world.aether_beacon.name")
	if floating_visual != null:
		_base_visual_position = floating_visual.position
	super._ready()
	_apply_activation_state(false)
	if not Engine.is_editor_hint():
		_refresh_activation_state.call_deferred()


func _process(delta: float) -> void:
	_animate_placeholder(delta)
	if not Engine.is_editor_hint():
		await super._process(delta)


func is_activated() -> bool:
	return _activated


func interact_with_player(_player: Node2D) -> void:
	if destination_id.strip_edges().is_empty():
		await show_dialogue(
			[LocalizationManager.text("world.aether_beacon.dormant")],
			display_name
		)
		return
	var result: Dictionary = await TransitService.attune(destination_id, global_position)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.transit_unavailable")
		return
	var body := result.get("body", {}) as Dictionary
	_apply_activation_state(true)
	if bool(body.get("newlyAttuned", false)):
		var network := body.get("network", {}) as Dictionary
		var destination_name := _destination_name_from_network(network)
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text(
				"ui.transit.attuned_system",
				{"name": destination_name}
			)
		)
		await _show_keeper_dialogue([
			LocalizationManager.text("npc.transit.attuned"),
			LocalizationManager.text("npc.transit.return_hint"),
		])
		return
	await _show_keeper_dialogue([
		LocalizationManager.text("world.aether_beacon.already_attuned"),
	])


func _show_keeper_dialogue(lines: Array[String]) -> bool:
	var keeper := _find_local_keeper()
	if keeper != null:
		var shown_value: Variant = await keeper.call("show_dialogue", lines)
		return bool(shown_value)

	var portrait: Texture2D
	var catalog := get_node_or_null("/root/TrainerPortraitCatalog")
	if catalog != null and catalog.has_method("get_texture"):
		portrait = catalog.call("get_texture", "showdown_psychic_gen6") as Texture2D
	return await show_dialogue(lines, "Aethernet Keeper", portrait)


func _find_local_keeper() -> Node:
	for candidate: Node in get_tree().get_nodes_in_group("aethernet_keeper"):
		if str(candidate.get("local_destination_id")) == destination_id:
			return candidate
	return null


func _destination_name_from_network(network: Dictionary) -> String:
	for destination_value: Variant in network.get("destinations", []):
		if not destination_value is Dictionary:
			continue
		var destination := destination_value as Dictionary
		if str(destination.get("destinationId", "")) == destination_id:
			return str(destination.get("name", destination_id))
	return destination_id.replace("_", " ").capitalize()


func _refresh_activation_state() -> void:
	var result: Dictionary = await TransitService.load_network()
	if not bool(result.get("success", false)):
		return
	var network := result.get("body", {}) as Dictionary
	if str(network.get("localDestinationId", "")) == destination_id:
		_apply_activation_state(bool(network.get("localAttuned", false)))
		return
	for destination_value: Variant in network.get("destinations", []):
		if not destination_value is Dictionary:
			continue
		var destination := destination_value as Dictionary
		if str(destination.get("destinationId", "")) == destination_id:
			_apply_activation_state(bool(destination.get("attuned", false)))
			return


func _apply_activation_state(activated: bool) -> void:
	var changed := _activated != activated
	_activated = activated
	if glow != null:
		glow.visible = activated
	if ring != null:
		ring.visible = activated
	if sparks != null:
		sparks.visible = activated
	if crystal != null:
		crystal.modulate = Color.WHITE if activated else Color(0.48, 0.61, 0.65, 1.0)
	if core != null:
		core.modulate = Color.WHITE if activated else Color(0.3, 0.43, 0.46, 0.75)
	if pedestal_rune != null:
		pedestal_rune.modulate = Color(0.45, 1.0, 1.0, 1.0) if activated else Color(0.22, 0.34, 0.36, 0.7)
	if changed:
		activation_state_changed.emit(activated)


func _animate_placeholder(delta: float) -> void:
	_animation_time += delta * animation_speed
	if floating_visual != null:
		var bob_height := 2.0 if _activated else 0.75
		floating_visual.position = _base_visual_position + Vector2(0.0, round(sin(_animation_time) * bob_height))
	if _activated and ring != null:
		ring.rotation = _animation_time * 0.5
	if _activated and glow != null:
		glow.modulate.a = 0.28 + (sin(_animation_time * 1.7) + 1.0) * 0.1
