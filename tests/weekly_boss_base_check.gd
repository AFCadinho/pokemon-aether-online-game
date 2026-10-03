extends SceneTree

const BossDefinition := preload("res://scripts/world/npcs/weekly_boss_definition.gd")
var failed := false
var emitted_difficulty := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var boss = load("res://scenes/npcs/weekly_boss.tscn").instantiate()
	var definition := BossDefinition.new()
	definition.boss_id = "example_boss"
	definition.display_name = "Example Boss"
	definition.species_id = "zapdos"
	boss.boss_definition = definition
	boss._apply_boss_definition()
	boss._setup_nameplate()
	_check(boss.nameplate_label.text == "Example Boss", "boss uses its own display name")
	_check(boss.nameplate_label.label_settings.font_color == Color("#ff5555"), "boss nameplate text is red")
	_check(boss.nameplate_label.label_settings.outline_size == 3, "boss nameplate keeps readable outline")
	_check(not boss.request_challenge("hard"), "unloaded status cannot start a challenge")
	_check(not boss.apply_weekly_status({"bossId": "another_boss", "state": "available"}), "another boss status is rejected")
	_check(boss.apply_weekly_status({"bossId": "example_boss", "state": "available"}), "server availability is accepted")
	_check(not boss.request_challenge("invalid"), "unknown difficulty is rejected")
	boss.challenge_requested.connect(func(_boss_id: String, difficulty: String): emitted_difficulty = difficulty)
	_check(boss.request_challenge("hard"), "Hard challenge request emits")
	_check(emitted_difficulty == "hard", "difficulty travels through the challenge signal")
	_check(not boss.request_challenge("easy"), "second local request waits for server status")
	boss.apply_weekly_status({"bossId": "example_boss", "state": "completed"})
	_check(not boss.request_challenge("hard"), "completed week prevents local requests")
	boss.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL %s" % label)
