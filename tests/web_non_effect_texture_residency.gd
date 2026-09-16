# Native dependency investigation only: does not instantiate gameplay or log in.
extends SceneTree

const PATHS := [
	"res://assets/ui/moon.png",
	"res://assets/ui/pokeaether_combo_logo.png",
	"res://assets/ui/pokeaether_text_logo.png",
	"res://assets/tilesets/da5h3mn-180d5fbd-2009-494d-8302-b394efb10c92.png",
	"res://assets/tilesets/overworld/buildings/Buildings3.png",
	"res://assets/tilesets/Custom Outside tileset.png",
	"res://assets/tilesets/Gen 4 Pack/Tilesets/Custom Outside tileset.png",
	"res://assets/battles/capture/capture_balls_gen4.png",
	"res://assets/battles/mechanics/tera-icon.png",
	"res://assets/background/hazards/spikes.png",
	"res://assets/background/hazards/stealth_rock.png",
	"res://assets/background/hazards/sticky_webs.png",
	"res://assets/background/hazards/toxic_spikes.png",
	"res://assets/background/platform/cave_platform.png",
	"res://assets/background/platform/grass_platform.png",
	"res://assets/background/platform/grass_platform_v2.png",
	"res://assets/background/platform/grass_platform_v3.png",
	"res://assets/background/platform/pvp_stadium_platform.png",
	"res://assets/background/platform/water_platform.png",
	"res://assets/background/screens/aurora_veil.png",
	"res://assets/background/screens/light_screen.png",
	"res://assets/background/screens/reflect.png",
	"res://assets/battles/effect/light_screen.png",
	"res://assets/battles/effect/spikes.png",
	"res://assets/battles/effect/stealth_rock.png",
	"res://assets/sprites/battle_buttons/run.png",
]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_snapshot("autoload_dependencies")
	var login: PackedScene = load("res://scenes/interface/login_screen.tscn")
	assert(login != null)
	_snapshot("login_scene_dependencies")
	login = null
	await process_frame
	await process_frame
	_snapshot("login_resource_released")
	var world: PackedScene = load("res://scenes/world.tscn")
	assert(world != null)
	_snapshot("world_scene_dependencies")
	var pallet: PackedScene = load("res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn")
	assert(pallet != null)
	_snapshot("world_and_pallet_dependencies")
	quit(0)

func _snapshot(label: String) -> void:
	var stats: Dictionary = get_root().get_node("WebMemoryProbe").diagnostic_cached_world_textures(PATHS)
	print("NON_EFFECT_RESIDENCY ", JSON.stringify({"label": label, "cachedWorldTextures": stats,
		"nativeDependenciesOnly": true, "realLoggedInWorld": false}))
