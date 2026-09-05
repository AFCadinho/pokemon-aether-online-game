extends RefCounted

class_name RockSmashLevelPalette

const LEVEL_COLORS := {
	1: Color("#a86f3d"),
	5: Color("#18c8b0"),
	10: Color("#4aa8ff"),
	20: Color("#ae70ff"),
	50: Color("#ff8954"),
	75: Color("#ffd34d"),
}


static func color_for_required_level(required_level: int) -> Color:
	var color: Variant = LEVEL_COLORS.get(required_level, Color.WHITE)
	return color as Color
