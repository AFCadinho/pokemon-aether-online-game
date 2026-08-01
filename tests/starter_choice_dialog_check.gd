extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dialog := StarterChoiceDialog.new()
	get_root().add_child(dialog)
	dialog.open([
		{
			"speciesId": "gible",
			"name": "Gible",
			"nationalDexNumber": 443,
			"generation": 4,
			"types": ["Dragon", "Ground"],
			"evolutionPaths": [[
				{"speciesId": "gible", "name": "Gible"},
				{"speciesId": "gabite", "name": "Gabite"},
				{"speciesId": "garchomp", "name": "Garchomp"},
			]],
		},
		{
			"speciesId": "larvitar",
			"name": "Larvitar",
			"nationalDexNumber": 246,
			"generation": 2,
			"types": ["Rock", "Ground"],
			"evolutionPaths": [[
				{"speciesId": "larvitar", "name": "Larvitar"},
				{"speciesId": "pupitar", "name": "Pupitar"},
				{"speciesId": "tyranitar", "name": "Tyranitar"},
			]],
		},
	])

	_expect(dialog.choices.size() == 2, "starter dialog accepts the server-owned catalog")
	_expect(dialog.filtered_choices.size() == 2, "starter dialog initially shows every supplied choice")
	_expect(dialog.find_child("StarterChoicePanel", true, false) != null, "starter dialog builds its themed modal panel")
	var selected := dialog.choices[0] as Dictionary
	dialog.call("_select_choice", selected)
	_expect(not dialog.choose_button.disabled, "selecting a starter enables confirmation")
	_expect(dialog.preview_name.text == "Gible", "starter preview shows the selected Pokemon")
	_expect(dialog.evolution_lines.get_child_count() == 1, "starter preview shows the evolution line")
	dialog.queue_free()
	quit(1 if failed else 0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
