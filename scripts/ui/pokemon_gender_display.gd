extends RefCounted

class_name PokemonGenderDisplay

const MALE_COLOR := Color("#62d7ff")
const FEMALE_COLOR := Color("#ff82ba")


static func presentation(gender: String) -> Dictionary:
	match gender.strip_edges().to_lower():
		"male", "m", "♂":
			return {
				"visible": true,
				"symbol": "M",
				"color": MALE_COLOR,
				"localization_key": "battle.gender.male",
			}
		"female", "f", "♀":
			return {
				"visible": true,
				"symbol": "F",
				"color": FEMALE_COLOR,
				"localization_key": "battle.gender.female",
			}

	return {
		"visible": false,
		"symbol": "",
		"color": Color.WHITE,
		"localization_key": "",
	}
