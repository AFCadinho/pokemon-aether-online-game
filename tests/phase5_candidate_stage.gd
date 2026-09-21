extends "res://scripts/battle/battle_ui/experimental_battle_3d.gd"
## Test-only adapter. Never loaded by the game or registered in Settings.
const REVIEW = preload("res://docs/phase5b-review-decisions.json")
var load_spans: Array[Dictionary] = []
var use_runtime_registry := false

func _span(label: String, started: int) -> void:
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	if elapsed > 1.0:
		load_spans.append({"operation": label, "ms": elapsed, "frame": Engine.get_process_frames()})

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._process(delta)
	_span("presenter process (inclusive)", started)

func _load_catalog(path: String) -> void:
	var started := Time.get_ticks_usec()
	super._load_catalog(path)
	_span("catalog (inclusive validation)", started)

func _queue_needed_models() -> void:
	var started := Time.get_ticks_usec()
	super._queue_needed_models()
	_span("demand validation", started)

func _import_next_model() -> void:
	var started := Time.get_ticks_usec()
	super._import_next_model()
	_span("threaded load dispatch/collect", started)

func _catalog_species_allowed(species: String) -> bool:
	if use_runtime_registry:
		return super._catalog_species_allowed(species)
	var base := species.trim_suffix("@shiny")
	for entry: Dictionary in REVIEW.data.entries:
		if entry.species == base:
			return entry.status == "eligible_for_5c_normal"
	return false

func _supports_combatant(species: String, shiny: bool, double: bool, substitute: bool) -> bool:
	if use_runtime_registry:
		return super._supports_combatant(species, shiny, double, substitute)
	return _catalog_species_allowed(species) and (not shiny or catalog_entries.has(species + "@shiny")) and not double and not substitute

func _combatant_key(index: int) -> String:
	if use_runtime_registry:
		return super._combatant_key(index)
	var species: String = combatants[index].species
	return species + "@shiny" if combatants[index].shiny and not species.is_empty() else species

func _motion_profile(species: String) -> Dictionary:
	if use_runtime_registry:
		return super._motion_profile(species)
	return catalog_entries.get(species, {}).get("_review_motion", {})

func _visual_rect(index: int) -> Rect2:
	if use_runtime_registry:
		return super._visual_rect(index)
	if actors[index] == null or not actors[index].visible:
		return Rect2()
	var data: Dictionary = entries[identities[index]].get("_review_bounds", {}).get(current_actions[index], {})
	assert(not data.is_empty())
	var box := AABB(Vector3(data.min[0], data.min[1], data.min[2]), Vector3(data.size[0], data.size[1], data.size[2]))
	var rect := Rect2()
	for corner in 8:
		var point := _project_to_ui(actors[index].global_transform * box.get_endpoint(corner))
		rect = Rect2(point, Vector2.ZERO) if corner == 0 else rect.expand(point)
	return rect
