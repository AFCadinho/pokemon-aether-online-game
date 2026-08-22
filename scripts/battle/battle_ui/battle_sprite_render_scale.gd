extends RefCounted


static func resolve(metadata: Dictionary, side: String) -> float:
	if metadata.has("render_scale"):
		return max(float(metadata.get("render_scale", 1.0)), 1.0)

	var frame_width := float(metadata.get("frame_width", 0.0))
	var frame_height := float(metadata.get("frame_height", 0.0))
	var normalized_side := side.replace("\\", "/").strip_edges().to_lower()
	var is_front_sprite := normalized_side.ends_with("/front") or normalized_side.ends_with("/shiny_front")
	if normalized_side == "front" or normalized_side == "shiny_front":
		is_front_sprite = true
	if (
		is_front_sprite
		and str(metadata.get("resample", "")).strip_edges().to_lower() == "static-source"
		and max(frame_width, frame_height) >= 160.0
	):
		return 2.0
	if metadata.has("scale"):
		return max(float(metadata.get("scale", 1.0)), 1.0)

	return 1.0
