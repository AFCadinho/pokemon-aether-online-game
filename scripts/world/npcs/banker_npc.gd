@tool
extends DialogueNPC

class_name BankerNPC

const BANK_ICON: Texture2D = preload("res://assets/ui/bank_money.svg")

var bank_marker: Sprite2D


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	bank_marker = Sprite2D.new()
	bank_marker.name = "BankMarker"
	bank_marker.texture = BANK_ICON
	bank_marker.position = Vector2(0, -112)
	bank_marker.scale = Vector2(0.55, 0.55)
	bank_marker.z_index = 513
	add_child(bank_marker)


func interact_with_player(_player: Node2D) -> void:
	await _load_npc_metadata()
	var ui_overlay := (
		get_tree().current_scene.get_node_or_null("UIOverlay")
		if get_tree().current_scene != null
		else null
	)
	if ui_overlay != null and ui_overlay.has_method("open_bank"):
		ui_overlay.call("open_bank")
		return
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	var message := (
		str(localization_manager.call("text", "ui.bank.error.unavailable"))
		if localization_manager != null
		else "Banking is unavailable right now."
	)
	await show_dialogue([message])
