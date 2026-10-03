extends PlayerGameStateServiceNode
var request_count := 0
var fail_profile := false
var profile_user_id := 1
var save_during_profile := false
var preferences := {"showFollower": false, "runningShoes": true, "favoriteAiSparringTeamId": "team-7"}

func _request_json(url: String, method: HTTPClient.Method, _headers: PackedStringArray, body: String) -> Dictionary:
	request_count += 1
	if url.ends_with("/game/profile"):
		if fail_profile:
			return {"success": false, "error": "timeout"}
		var old_preferences := preferences.duplicate(true)
		if save_during_profile:
			await save_player_preferences({"showFollower": true})
		return {"success": true, "body": {
			"user": {"id": profile_user_id},
			"preferences": {"preferences": old_preferences},
		}}
	if method == HTTPClient.METHOD_PUT:
		preferences = JSON.parse_string(body)
	return {"success": true, "body": {
		"preferences": preferences.duplicate(true),
		"favoritePokemonOptions": [{"species": "Pikachu", "shiny": false}],
	}}


