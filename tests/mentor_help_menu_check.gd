extends SceneTree

const MentorTopicMenuScript := preload("res://scripts/ui/mentor_topic_menu.gd")
const MENU_PATH := "res://scripts/ui/mentor_topic_menu.gd"
const MATEO_PATH := "res://scripts/world/kanto/towns/ev_training_expert_mateo.gd"
const GIDEON_PATH := "res://scripts/world/kanto/towns/catching_mentor_gideon.gd"

const REQUIRED_KEYS: Array[String] = [
	"ui.mentor_help.eyebrow",
	"mentor.mateo.help.topic.basics",
	"mentor.mateo.help.topic.earning",
	"mentor.mateo.help.topic.allocating",
	"mentor.mateo.help.topic.limits",
	"mentor.mateo.help.allocating.1",
	"mentor.mateo.help.limits.1",
	"mentor.gideon.help.topic.finding",
	"mentor.gideon.help.topic.catching",
	"mentor.gideon.help.topic.odds",
	"mentor.gideon.help.finding.1",
	"mentor.gideon.help.catching.1",
]

var failed := false


func _init() -> void:
	var menu: CanvasLayer = MentorTopicMenuScript.new()
	_check(menu != null, "mentor topic menu script instantiates")
	if menu != null:
		_check(menu.call("_panel_style") is StyleBoxFlat, "mentor topic menu uses its themed panel")
		var topics: Array[Dictionary] = [
			{"id": "one", "label": "First topic"},
			{"id": "two", "label": "Second topic"},
		]
		menu.call("_build_menu", "Mentor", "Choose a topic", topics, "MENTOR NOTES", "Close")
		_check(
			menu.find_children("*", "Button", true, false).size() == 3,
			"mentor topic menu renders every topic plus a close action"
		)
		menu.free()

	var menu_source := FileAccess.get_file_as_string(MENU_PATH)
	_check(menu_source.contains('event.is_action_pressed("ui_cancel")'), "mentor menu can close with ui_cancel")
	_check(menu_source.contains("return await topic_selected"), "mentor menu exposes an awaitable topic result")

	var mateo_source := FileAccess.get_file_as_string(MATEO_PATH)
	_check(mateo_source.contains("await _show_completed_help()"), "completed Mateo quest opens reusable help")
	_check(mateo_source.contains('"allocating"') and mateo_source.contains('"limits"'), "Mateo covers allocation and EV limits")
	_check(mateo_source.contains("while true:"), "Mateo returns to the topic menu after an explanation")
	_check(mateo_source.contains("var greeting: Array[String]"), "Mateo passes a typed greeting array to dialogue resolution")
	_check(mateo_source.contains("func _resolve_lines(dialogue_id: String, fallback: Array)"), "Mateo accepts inline fallback dialogue arrays")

	var gideon_source := FileAccess.get_file_as_string(GIDEON_PATH)
	_check(gideon_source.contains("await _show_completed_help()"), "completed Gideon quest opens reusable help")
	_check(gideon_source.contains('"finding"') and gideon_source.contains('"catching"'), "Gideon covers finding and catching Pokemon")
	_check(gideon_source.contains("while true:"), "Gideon returns to the topic menu after an explanation")
	_check(gideon_source.contains("var greeting: Array[String]"), "Gideon passes a typed greeting array to dialogue resolution")
	_check(gideon_source.contains("func _resolve_dialogue_lines(dialogue_id: String, fallback: Array)"), "Gideon accepts inline fallback dialogue arrays")

	for locale: String in ["en", "nl", "pt_BR"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % locale))
		var catalog := parsed as Dictionary if parsed is Dictionary else {}
		for key: String in REQUIRED_KEYS:
			_check(catalog.has(key), "%s contains mentor help key %s" % [locale, key])

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
