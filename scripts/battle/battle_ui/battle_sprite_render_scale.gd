extends RefCounted


static func resolve(metadata: Dictionary, side: String) -> float:
	if metadata.has("render_scale"):
		return max(float(metadata.get("render_scale", 1.0)), 1.0)

	var frame_width := float(metadata.get("frame_width", 0.0))
	var frame_height := float(metadata.get("frame_height", 0.0))
	# Older published static ZA sheets from this reviewed pack omit render_scale.
	# Their 96 px logical canvas is exported at 1x/2x/3x; do not apply this
	# inference to animated sheets or unrelated sprite sources.
	if str(metadata.get("source_pack", "")) == "Generation 9 Pack 3.3.6":
		return max(max(frame_width, frame_height) / 96.0, 1.0)
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
