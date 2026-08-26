extends RefCounted


static func parse(response: Dictionary) -> Dictionary:
	if response.has("available"):
		var mode := str(response.get("mode", "")).strip_edges().to_lower()
		if typeof(response.get("available")) != TYPE_BOOL or not mode in ["open", "draining", "closed"]:
			return {"valid": false, "online": false}
		var available := bool(response.get("available", false))
		if available != (mode == "open"):
			return {"valid": false, "online": false}
		return {
			"valid": true,
			"online": available,
			"reachable": true,
			"maintenance": not available,
			"server_status": mode,
			"message": str(response.get("message", "")).strip_edges(),
			"disconnect_at": str(response.get("disconnectAt", "")).strip_edges(),
		}

	# Keep accepting the old infrastructure-health shape for local overrides.
	var status_text := str(response.get("status", "")).strip_edges().to_lower()
	if status_text not in ["online", "ok", "degraded"]:
		return {"valid": false, "online": false}
	return {
		"valid": true,
		"online": status_text in ["online", "ok"],
		"reachable": true,
		"maintenance": false,
		"server_status": status_text,
		"message": "",
	}
