extends SceneTree
## Exercise generated badges and their real container sizes without model downloads.
const Typography = preload("res://scripts/battle/battle_ui/immersive_typography.gd")

class BattleFixture:
	extends Control
	var coop_mode := false

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings: Node = root.get_node("SettingsManager")
	var battle := BattleFixture.new()
	root.add_child(battle)
	var hud: Control = load("res://scenes/battle/pokemon_hud_panel.tscn").instantiate()
	battle.add_child(hud)
	hud.scale = Vector2.ONE * 0.65
	var hp_name: Label = hud.find_child("NameLabel", true, false)
	hp_name.text = "Bellsprout"
	var badges: Control = load("res://scenes/battle/stat_stage_panel.tscn").instantiate()
	battle.add_child(badges)
	badges.scale = Vector2.ONE * 0.5
	var typography := Typography.new()
	typography.battle = battle
	battle.add_child(typography)
	typography.set_process(false)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		battle.scale = Vector2.ONE * (float(dimensions.x) / 1280.0)
		for ui_scale in [80.0, 100.0, 125.0, 150.0]:
			settings.ui_scale = ui_scale
			for coop in [false, true]:
				battle.coop_mode = coop
				for mode in ["2d", "2.5d", "3d"]:
					settings.battle_presentation_mode = mode
					badges.set_badges([
						{"label": "Atk", "value": "▲ 1"},
						{"label": "SpA", "value": "▼ 1"},
						{"label": "Taunt", "line": "modifier"},
					])
					typography._scan(battle)
					typography._process(0.0)
					for frame in 3:
						await process_frame
					var context := str(dimensions, " ui=", ui_scale, " coop=", coop, " mode=", mode)
					var hp_pixels := _font_pixels(hp_name)
					for label: Node in badges.find_children("*Label", "Label", true, false):
						if not label.is_visible_in_tree():
							continue
						_check(_font_pixels(label) < hp_pixels,
							context + ": stat/effect text must remain smaller than HP text")
					_check(badges.stat_stage_row.get_global_rect().size.x < hud.get_global_rect().size.x,
						context + ": two stat badges must fit within the HP card width")
		if not failed:
			print("COMPACT_BATTLE_BADGES_OK ", dimensions)
	battle.free()
	quit(1 if failed else 0)

func _font_pixels(label: Label) -> float:
	return label.get_theme_font_size("font_size") * label.get_screen_transform().y.length()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
