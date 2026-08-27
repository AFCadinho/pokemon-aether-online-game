extends SceneTree

const SCRIPT_EXPECTATIONS := {
	"res://scripts/ui/chat_moderation_center.gd": [
		"detention_duration_input.update_on_text_changed = true",
	],
	"res://scripts/ui/aether_exchange_popup.gd": [
		"spin.update_on_text_changed = true",
		"quantity_spin.update_on_text_changed = true",
		"price_spin.update_on_text_changed = true",
	],
	"res://scripts/ui/trade_workspace.gd": [
		"money_amount_spinbox.update_on_text_changed = true",
		"quantity.update_on_text_changed = true",
	],
	"res://scripts/ui/guild_popup.gd": [
		"amount.update_on_text_changed = true",
	],
	"res://scripts/ui/ui_overlay.gd": [
		"dev_item_quantity_spinbox.update_on_text_changed = true",
		"dev_money_amount_spinbox.update_on_text_changed = true",
		"pokemon_summary_ev_allocate_input.update_on_text_changed = true",
		"market_quantity_spinbox.update_on_text_changed = true",
		"bag_item_use_quantity_spinbox.update_on_text_changed = true",
	],
}

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for path: String in SCRIPT_EXPECTATIONS:
		var source := FileAccess.get_file_as_string(path)
		for expectation: String in SCRIPT_EXPECTATIONS[path]:
			_check(source.contains(expectation), "%s enables %s" % [path, expectation])

	var scene_source := FileAccess.get_file_as_string("res://scenes/interface/ui_overlay.tscn")
	_check(
		scene_source.count("type=\"SpinBox\"") == 2
			and scene_source.count("update_on_text_changed = true") == 2,
		"Scene-defined mail SpinBoxes update while typing"
	)

	var spinbox := SpinBox.new()
	spinbox.min_value = 1
	spinbox.max_value = 999999
	spinbox.value = 1000
	spinbox.update_on_text_changed = true
	root.add_child(spinbox)
	var line_edit := spinbox.get_line_edit()
	line_edit.text = "100000"
	line_edit.text_changed.emit(line_edit.text)
	await process_frame
	_check(int(spinbox.value) == 100000, "SpinBox value follows typed text without Enter")
	spinbox.queue_free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
