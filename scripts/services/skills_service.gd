extends Node

class_name SkillsServiceNode

signal state_changed(skills: Array)
signal fishing_catalog_changed(catalog: Dictionary)

const SKILLS_ENDPOINT := "/game/skills"
const FISHING_CATALOG_ENDPOINT := "/encounters/fishing-catalog"
const REQUEST_TIMEOUT_SECONDS := 8.0

var skills: Array = []
var fishing_catalog: Dictionary = {}
var state_loaded := false
var was_authenticated := false


func _ready() -> void:
	set_process(true)
	if not ThievingService.state_changed.is_connected(_on_thieving_state_changed):
		ThievingService.state_changed.connect(_on_thieving_state_changed)


func _process(_delta: float) -> void:
	var authenticated := AuthService.is_authenticated()
	if not authenticated and was_authenticated:
		skills.clear()
		fishing_catalog.clear()
		state_loaded = false
		state_changed.emit([])
		fishing_catalog_changed.emit({})
	was_authenticated = authenticated


func load_skills(area_id := "") -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var endpoint := SKILLS_ENDPOINT
	var normalized_area_id := str(area_id).strip_edges()
	if normalized_area_id != "":
		endpoint += "?areaId=%s" % normalized_area_id.uri_encode()
	var response := await _request_json(endpoint)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	var next_skills: Variant = body.get("skills", [])
	skills = (next_skills as Array).duplicate(true) if next_skills is Array else []
	state_loaded = true
	state_changed.emit(skills.duplicate(true))
	var catalog_result := await load_fishing_catalog()
	return {
		"success": true,
		"skills": skills.duplicate(true),
		"fishingCatalogLoaded": bool(catalog_result.get("success", false)),
	}


func load_fishing_catalog(force_refresh := false) -> Dictionary:
	if not force_refresh and not fishing_catalog.is_empty():
		return {"success": true, "catalog": fishing_catalog.duplicate(true)}
	var response := await _request_json(FISHING_CATALOG_ENDPOINT)
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	var catalog := _dictionary_from_value(body.get("catalog", {}))
	if catalog.is_empty():
		return {"success": false, "error": "Fishing catalog response was empty."}
	fishing_catalog = catalog.duplicate(true)
	fishing_catalog_changed.emit(fishing_catalog.duplicate(true))
	return {"success": true, "catalog": fishing_catalog.duplicate(true)}


func get_skills() -> Array:
	return skills.duplicate(true)


func get_fishing_catalog() -> Dictionary:
	return fishing_catalog.duplicate(true)


func get_skill(skill_id: String) -> Dictionary:
	var normalized_id := skill_id.strip_edges().to_lower()
	for skill_value: Variant in skills:
		var skill := _dictionary_from_value(skill_value)
		if str(skill.get("id", "")).strip_edges().to_lower() == normalized_id:
			return skill.duplicate(true)
	return {}


func _on_thieving_state_changed(thieving_state: Dictionary) -> void:
	if not state_loaded or thieving_state.is_empty():
		return
	for index in range(skills.size()):
		var skill := _dictionary_from_value(skills[index])
		if str(skill.get("id", "")) != "thieving":
			continue
		var level := maxi(int(thieving_state.get("level", 1)), 1)
		var skill_unlocked := bool(thieving_state.get("unlocked", false))
		skill["unlocked"] = skill_unlocked
		var experience_into_level := maxi(int(thieving_state.get("experienceIntoLevel", 0)), 0)
		var experience_for_next_level := maxi(int(thieving_state.get("experienceForNextLevel", 0)), 0)
		skill["level"] = level
		skill["totalExperience"] = maxi(int(thieving_state.get("totalExperience", 0)), 0)
		skill["experienceIntoLevel"] = experience_into_level
		skill["experienceForNextLevel"] = experience_for_next_level
		skill["progressPercent"] = 100.0 if level >= 100 or experience_for_next_level <= 0 else clampf(
			float(experience_into_level) / float(experience_for_next_level) * 100.0,
			0.0,
			100.0
		)
		var stats := _dictionary_from_value(skill.get("stats", {}))
		stats["currency"] = maxi(int(thieving_state.get("currency", 0)), 0)
		stats["wanted"] = clampi(int(thieving_state.get("wanted", 0)), 0, 100)
		stats["rewardBonusPercent"] = mini(maxi(level - 1, 0), 100)
		stats["wantedReductionPercent"] = minf(float(maxi(level - 1, 0)) * 0.5, 40.0)
		stats["maximumCatchReductionPercent"] = minf(float(maxi(level - 1, 0)) * 0.2, 20.0)
		skill["stats"] = stats
		var unlocks_value: Variant = skill.get("unlocks", [])
		if unlocks_value is Array:
			var unlocks: Array = unlocks_value as Array
			for unlock_index in range(unlocks.size()):
				var unlock := _dictionary_from_value(unlocks[unlock_index])
				unlock["unlocked"] = skill_unlocked and level >= int(unlock.get("requiredLevel", 1))
				unlocks[unlock_index] = unlock
			skill["unlocks"] = unlocks
		var targets_value: Variant = skill.get("targets", [])
		if targets_value is Array:
			var attempted_value: Variant = thieving_state.get("attemptedNpcIds", [])
			var attempted_ids: Array = attempted_value as Array if attempted_value is Array else []
			var jailed := bool(thieving_state.get("jailed", false))
			var targets: Array = targets_value as Array
			for target_index in range(targets.size()):
				var target := _dictionary_from_value(targets[target_index])
				var attempted_today := str(target.get("npcId", "")) in attempted_ids
				var unlocked := skill_unlocked and level >= int(target.get("requiredLevel", 1))
				target["unlocked"] = unlocked
				target["attemptedToday"] = attempted_today
				target["availableToday"] = unlocked and not attempted_today and not jailed
				targets[target_index] = target
			skill["targets"] = targets
		skills[index] = skill
		state_changed.emit(skills.duplicate(true))
		return


func _request_json(endpoint: String) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var error := request.request(base_url + endpoint, GatewayApiConfig.get_accept_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}
	var result: Array = await request.request_completed
	request.queue_free()
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	var response_body := _dictionary_from_value(parsed)
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "status": response_code, "error": "Network request failed.", "body": response_body}
	if response_code < 200 or response_code >= 300:
		return {"success": false, "status": response_code, "error": _extract_error(response_body, response_code), "body": response_body}
	return {"success": true, "status": response_code, "body": response_body}


func _extract_error(body: Dictionary, status: int) -> String:
	var detail: Variant = body.get("detail", body.get("message", body.get("error", "")))
	if detail is Dictionary:
		return str((detail as Dictionary).get("message", (detail as Dictionary).get("code", "Request failed.")))
	var message := str(detail).strip_edges()
	return message if message != "" else "Request failed with status %d." % status


func _dictionary_from_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
