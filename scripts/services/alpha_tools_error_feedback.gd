extends RefCounted

class_name AlphaToolsErrorFeedback


static func team_creation_failure(
	created_count: int,
	pokemon_index: int,
	pokemon_data: Dictionary,
	response: Dictionary
) -> String:
	var reason := BackendErrorLocalizationService.diagnostic_message(response)
	if reason.is_empty():
		reason = str(response.get("error", "Unknown error")).strip_edges()
	if reason.is_empty():
		reason = "Unknown error"

	var species := str(pokemon_data.get(
		"species",
		pokemon_data.get("speciesId", pokemon_data.get("species_id", "Unknown Pokemon"))
	)).strip_edges()
	if species.is_empty():
		species = "Unknown Pokemon"

	return "Created %s Alpha Pokemon, then Pokemon %s (%s) failed: %s" % [
		created_count,
		pokemon_index,
		species,
		reason,
	]
