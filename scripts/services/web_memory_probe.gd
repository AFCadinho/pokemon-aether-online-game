extends Node

var enabled := false
var elapsed := 0.0

func _ready() -> void:
	if OS.has_feature("web"):
		enabled = bool(JavaScriptBridge.eval("Boolean(window.pokeaetherMemoryProbe)", true))
	set_process(enabled)
	mark("engine_ready")

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 1.0:
		elapsed = 0.0
		mark("sample")

func mark(label: String) -> void:
	if not enabled:
		return
	var sample := {"label": label, "engineTicksMs": Time.get_ticks_msec(),
		"textureCounterBytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"resourceCount": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodeCount": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphanNodeCount": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"spriteCache": WebPokemonSpriteService.diagnostic_cache_stats()}
	# Separate opt-in: traversal adds diagnostic overhead, so never enable this
	# for battle latency comparisons. Only counts/script types, no node names,
	# player identifiers or private node properties are recorded.
	if bool(JavaScriptBridge.eval("window.pokeaetherMemoryNodeCounts === true", true)):
		sample["sceneNodeTypes"] = diagnostic_scene_node_types(get_tree().root)
	JavaScriptBridge.eval("window.pokeaetherMemoryProbe.record(%s)" % JSON.stringify(sample), true)

func diagnostic_scene_node_types(root: Node) -> Dictionary:
	var counts := {}
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var script := node.get_script() as Script
		var key := script.resource_path if script != null else node.get_class()
		counts[key] = int(counts.get(key, 0)) + 1
		for child: Node in node.get_children(true):
			pending.append(child)
	return counts
