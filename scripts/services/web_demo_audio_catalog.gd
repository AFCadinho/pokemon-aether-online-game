extends RefCounted

## Web export cannot infer ResourceLoader calls made from dynamic music paths.
## Keep every browser-demo music stream as an explicit preload so Godot packs
## its imported .oggvorbisstr resource, rather than only the raw source file.

const STREAMS := {
	"res://assets/music/login/lugia_theme_lofi.ogg": preload("res://assets/music/login/lugia_theme_lofi.ogg"),
	"res://assets/music/overworld/kanto/towns/pallet_town.ogg": preload("res://assets/music/overworld/kanto/towns/pallet_town.ogg"),
	"res://assets/music/overworld/kanto/towns/viridian_city.ogg": preload("res://assets/music/overworld/kanto/towns/viridian_city.ogg"),
	"res://assets/music/overworld/kanto/routes/route1.ogg": preload("res://assets/music/overworld/kanto/routes/route1.ogg"),
	"res://assets/music/overworld/kanto/interiors/oaks_lab.ogg": preload("res://assets/music/overworld/kanto/interiors/oaks_lab.ogg"),
	"res://assets/music/overworld/kanto/interiors/pokemon_center.ogg": preload("res://assets/music/overworld/kanto/interiors/pokemon_center.ogg"),
	"res://assets/music/battle/wild/Kanto Wild Battle.ogg": preload("res://assets/music/battle/wild/Kanto Wild Battle.ogg"),
	"res://assets/music/battle/trainer/Kalos Trainer Battle.ogg": preload("res://assets/music/battle/trainer/Kalos Trainer Battle.ogg"),
}


static func get_stream(path: String) -> AudioStream:
	return STREAMS.get(path, null) as AudioStream
