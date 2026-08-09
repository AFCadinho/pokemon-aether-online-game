extends SceneTree

const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")
const BENCHMARK_REVISION := "calc2.4-2026-08-09"
const ITERATIONS := 300
const WARMUP_ITERATIONS := 20
const P99_BUDGET_MS := 16.0
const MAX_STATIC_MEMORY_BYTES := 536870912


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := DamageCalcPanel.new()
	panel.name = "BattleDamageCalcPanelBenchmark"
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame

	var response := _response_fixture()
	for _index in range(WARMUP_ITERATIONS):
		panel.show_response(response)
		await process_frame

	var samples: Array[float] = []
	var peak_static_memory_bytes := OS.get_static_memory_usage()
	for _index in range(ITERATIONS):
		var started_usec := Time.get_ticks_usec()
		panel.show_response(response)
		samples.append(float(Time.get_ticks_usec() - started_usec) / 1000.0)
		await process_frame
		peak_static_memory_bytes = maxi(peak_static_memory_bytes, OS.get_static_memory_usage())

	samples.sort()
	var result := {
		"schemaVersion": 1,
		"benchmarkRevision": BENCHMARK_REVISION,
		"godotVersion": Engine.get_version_info().get("string", "unknown"),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"iterations": ITERATIONS,
		"rows": 8,
		"latencyMs": {
			"p50": _percentile(samples, 0.50),
			"p95": _percentile(samples, 0.95),
			"p99": _percentile(samples, 0.99),
			"max": samples[-1],
		},
		"peakStaticMemoryBytes": peak_static_memory_bytes,
		"budgets": {
			"p99Ms": P99_BUDGET_MS,
			"maxStaticMemoryBytes": MAX_STATIC_MEMORY_BYTES,
		},
	}
	print("CALCDEX_RENDER_BENCHMARK %s" % JSON.stringify(result))

	if float(result["latencyMs"]["p99"]) > P99_BUDGET_MS:
		push_error("Calcdex render p99 exceeded %.1f ms" % P99_BUDGET_MS)
		quit(1)
		return
	if peak_static_memory_bytes > MAX_STATIC_MEMORY_BYTES:
		push_error("Calcdex render static memory exceeded %d bytes" % MAX_STATIC_MEMORY_BYTES)
		quit(1)
		return
	quit(0)


func _percentile(sorted_samples: Array[float], quantile: float) -> float:
	var index := maxi(0, ceili(float(sorted_samples.size()) * quantile) - 1)
	return snappedf(sorted_samples[index], 0.001)


func _response_fixture() -> Dictionary:
	var rows: Array[Dictionary] = []
	for index in range(8):
		rows.append({
			"move": {"name": "Benchmark Move %d" % (index + 1), "type": "Electric", "category": "Special"},
			"damage": [42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57],
			"minDamage": 42,
			"maxDamage": 57,
			"averageDamage": 49.5,
			"minPercent": 24.1,
			"maxPercent": 32.8,
			"shortLabel": "24.1-32.8%",
			"hkoLabel": "4HKO",
			"koSummaryLabel": "guaranteed 4HKO",
			"ohkoChance": 0.0,
			"hitsToKoChance": 1.0,
			"hitsToKo": 4,
			"recoveryNote": "",
			"koWarnings": [],
			"warnings": [],
		})
	return {
		"success": true,
		"attacker": {"species": "Pikachu", "level": 50, "boosts": {"spa": 1}},
		"defender": {
			"species": "Mew",
			"level": 50,
			"hp": {"display": "73%", "percent": 73},
			"knownFields": ["identity", "level", "status"],
			"unknownFields": ["item", "ability", "nature", "evs", "ivs"],
			"assumptions": {"nature": "Hardy", "evs": {}, "ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31}},
		},
		"results": rows,
		"warnings": ["Opponent item and ability are unknown."],
	}
