extends RefCounted

class_name RockSmashLevelPalette

const LEVEL_COLORS := {
	1: Color("#ffffff"),
	5: Color("#b9d59f"),
	10: Color("#9fcadf"),
	20: Color("#c5a7dd"),
	50: Color("#e79a73"),
	75: Color("#f1d36f"),
}


static func color_for_required_level(required_level: int) -> Color:
	var color: Variant = LEVEL_COLORS.get(required_level, Color.WHITE)
	return color as Color
