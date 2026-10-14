extends RefCounted

const CREDITS_URL := "https://pokeaether.com/credits"

# Public Official Guide shared by all Route 5 Daycare services.
const DAYCARE_GUIDE_URL := "https://forums.pokeaether.com/t/daycare-training-ivs-and-natures/113"

static func open_daycare_guide() -> void:
	OS.shell_open(DAYCARE_GUIDE_URL)
