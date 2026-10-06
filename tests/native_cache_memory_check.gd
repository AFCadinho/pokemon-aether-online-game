extends "res://tests/battle_3d_regional_stress_check.gd"
## The same real battle gate, with memory observations and stable cache costs.
const BudgetApproval = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
var memory_peak := {"rss_bytes": 0, "static_bytes": 0, "texture_bytes": 0, "buffer_bytes": 0}
var last_memory_sample := 0
var cache_observations := []

func _sample_frame() -> void:
	super._sample_frame()
	if Time.get_ticks_msec() - last_memory_sample < 300: return
	last_memory_sample = Time.get_ticks_msec()
	var status := FileAccess.open("/proc/self/status", FileAccess.READ)
	if status != null:
		while not status.eof_reached():
			var line := status.get_line()
			if line.begins_with("VmRSS:"):
				memory_peak.rss_bytes = maxi(memory_peak.rss_bytes, int(line.trim_prefix("VmRSS:").strip_edges().split("kB")[0]) * 1024)
				break
	memory_peak.static_bytes = maxi(memory_peak.static_bytes, OS.get_static_memory_usage())
	memory_peak.texture_bytes = maxi(memory_peak.texture_bytes, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))
	memory_peak.buffer_bytes = maxi(memory_peak.buffer_bytes, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED))

func _ready_pair(species: String, left_shiny: bool, right_shiny: bool) -> void:
	await super._ready_pair(species, left_shiny, right_shiny)
	var costs := {}
	for identity: String in stage.validated_entries:
		var entry: Dictionary = stage.validated_entries[identity]
		var profile := BudgetApproval.resolve(identity, entry._verified_runtime_hash)
		var expected := maxi(entry._source_bytes, int(profile.get("cache_source_bytes", 0)))
		assert(entry._cache_source_bytes == expected)
		if Cache.items.has(entry._resource_cache_key):
			assert(Cache.items[entry._resource_cache_key].bytes == expected, "Smaller container changed the approved cache cost")
		costs[identity] = expected
	assert(Cache.source_bytes <= Cache.MAX_SOURCE_BYTES and Cache.items.size() <= Cache.MAX_ENTRIES)
	cache_observations.append({"species": species, "left_shiny": left_shiny, "arena": root.get_node("SettingsManager").battle_3d_arena,
		"costs": costs, "retained_bytes": Cache.source_bytes, "retained_entries": Cache.items.size()})

func _run() -> void:
	await super._run()
	var path := OS.get_environment("POKEAETHER_BATCH01_STRESS_OUTPUT")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report["memory_peak"] = memory_peak
	report["cache_observations"] = cache_observations
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
