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
		"spriteCache": WebPokemonSpriteService.diagnostic_cache_stats()}
	JavaScriptBridge.eval("window.pokeaetherMemoryProbe.record(%s)" % JSON.stringify(sample), true)
