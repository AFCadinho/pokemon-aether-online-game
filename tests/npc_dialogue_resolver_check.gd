extends SceneTree

const ResolverScript := preload("res://scripts/services/npc_dialogue_service.gd")
const ROUTE_1_SCENE_PATH := (
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn"
)

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var resolver := ResolverScript.new()
	root.add_child(resolver)

	_check_selection(
		resolver,
		"metadata_dialogue",
		"override_dialogue",
		"legacy_dialogue",
		"override_dialogue",
		"scene_override",
		"explicit override wins"
	)
	_check_selection(
		resolver,
		"metadata_dialogue",
		"",
		"legacy_dialogue",
		"metadata_dialogue",
		"npc_metadata",
		"NPC metadata wins over the legacy scene field"
	)
	_check_selection(
		resolver,
		"",
		"",
		"legacy_dialogue",
		"legacy_dialogue",
		"legacy_scene",
		"legacy scene ids remain compatible"
	)

	var fallback_result: Dictionary = await resolver.resolve_dialogue(
		"",
		["Legacy fallback"],
		"Resolver test"
	)
	_check_true(bool(fallback_result.get("success", false)), "inline fallback remains available during migration")
	_check_true(bool(fallback_result.get("usedFallback", false)), "fallback use is explicit in the result")
	_check_equal(fallback_result.get("lines", []), ["Legacy fallback"], "fallback lines are preserved")
	_check_route_1_serialization()

	resolver.queue_free()
	quit(1 if failed else 0)


func _check_route_1_serialization() -> void:
	var packed_scene := load(ROUTE_1_SCENE_PATH) as PackedScene
	_check_true(packed_scene != null, "Route 1 scene loads with NPC scripts")
	if packed_scene == null:
		return
	var route := packed_scene.instantiate()
	var bug_catcher := route.get_node_or_null(
		"Entities/NPCs/BugCatcherTrainerNPC"
	)
	var alder := route.get_node_or_null(
		"Entities/NPCs/Dialogue/DialogueNPC"
	)
	_check_true(bug_catcher != null, "Route 1 Bug Catcher still instantiates")
	_check_true(alder != null, "Route 1 Alder still instantiates")
	if bug_catcher != null:
		_check_equal(
			str(bug_catcher.get("trainer_id")),
			"kanto_route_1_bug_catcher_1",
			"Route 1 trainer serialization is not shifted"
		)
		_check_equal(
			str(bug_catcher.get("display_name")),
			"Bug Catcher Big D",
			"Route 1 NPC presentation serialization is not shifted"
		)
		_check_true(
			bug_catcher.get("npc_sprite_frames") is SpriteFrames,
			"Route 1 NPC sprite serialization is not shifted"
		)
	if alder != null:
		_check_equal(str(alder.get("dialogue_id")), "", "Alder has no legacy scene dialogue")
	route.free()


func _check_selection(
	resolver: Node,
	metadata_id: String,
	override_id: String,
	legacy_id: String,
	expected_id: String,
	expected_source: String,
	message: String
) -> void:
	var selection: Dictionary = resolver.call(
		"select_dialogue_reference",
		metadata_id,
		override_id,
		legacy_id
	)
	_check_equal(selection.get("dialogueId", ""), expected_id, "%s id" % message)
	_check_equal(selection.get("source", ""), expected_source, "%s source" % message)


func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s expected=%s actual=%s" % [message, str(expected), str(actual)])


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
