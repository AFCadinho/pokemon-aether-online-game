@tool
extends WorldInteractable

const QUEST := "confront_team_rocket_boss"
const GUARDS: Array[String] = ["kanto_rocket_hideout_b4f_grunt_2", "kanto_rocket_hideout_b4f_grunt_3"]
var _generation := 0
var _progress_loaded := false
var _opening := false
var _open := false
var _motion: Tween
var _openness := 0.0:
	set(value):
		_openness = value
		queue_redraw()

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	display_name = LocalizationManager.text("world.rocket_hideout.gate.name")
	StoryService.story_changed.connect(_on_story_changed)
	TrainerProgressService.progress_invalidated.connect(refresh_guard_progress)
	refresh_guard_progress.call_deferred()

func _exit_tree() -> void:
	_generation += 1
	if _motion != null and _motion.is_valid():
		_motion.kill()

func _on_story_changed(_revision: int) -> void:
	refresh_guard_progress.call_deferred()

func refresh_guard_progress() -> void:
	_generation += 1
	var generation := _generation
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	_opening = false
	var both_defeated := true
	# An earned boss victory also preserves passage for pre-gate saves.
	if not StoryService.is_requirement_met(QUEST, "confront_boss", "completed"):
		for guard: String in GUARDS:
			var result: Dictionary = await TrainerProgressService.get_progress(guard)
			if not is_inside_tree() or generation != _generation:
				return
			both_defeated = both_defeated and bool(result.get("success", false)) and bool(result.get("progress", {}).get("firstDefeated", false))
	var animate := _progress_loaded and not _open
	_progress_loaded = true
	if not both_defeated:
		if _motion != null and _motion.is_valid():
			_motion.kill()
		_motion = null
		_opening = false
		_open = false
		_openness = 0.0
		blocks_movement = true
		return
	if _open:
		return
	if animate:
		_opening = true
		# Keep the door closed while World presents the second guard's outro.
		while GameState.is_overworld_input_locked():
			await get_tree().process_frame
			if not is_inside_tree() or generation != _generation:
				return
		_motion = create_tween()
		_motion.tween_property(self, "_openness", 1.0, 0.45)
		while _motion != null and _motion.is_valid() and _motion.is_running():
			await get_tree().process_frame
		if not is_inside_tree() or generation != _generation:
			return
	_motion = null
	_opening = false
	_open = true
	_openness = 1.0
	blocks_movement = false

func is_gate_open() -> bool:
	return _open

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		super._process(delta)

func _can_start_manual_interaction() -> bool:
	return not _open and not _opening and super._can_start_manual_interaction()

func interact_with_player(_player: Node2D) -> void:
	if not _open:
		var lines: Array[String] = [LocalizationManager.text("world.rocket_hideout.gate.closed")]
		await show_dialogue(lines)

func _draw() -> void:
	# Sliding metal panels fit the existing two-tile corridor. The frame and
	# panels stay within the portal footprint and retract into its side walls.
	draw_rect(Rect2(-34, -20, 68, 40), Color("39464e"), false, 3.0)
	if _openness >= 1.0:
		return
	var shift := _openness * 30.0
	for side in [-1, 1]:
		var left := -32.0 - shift if side == -1 else shift
		var panel := Rect2(left, -18, 32, 36)
		draw_rect(panel, Color("84969b"))
		draw_rect(panel.grow(-2), Color("546973"), false, 2.0)
		for row in range(4):
			draw_line(Vector2(left + 4, -12 + row * 8), Vector2(left + 28, -12 + row * 8), Color("b4c0bd"), 2)
		draw_rect(Rect2(left + (25 if side == -1 else 3), -3, 4, 6), Color("e66d59"))
