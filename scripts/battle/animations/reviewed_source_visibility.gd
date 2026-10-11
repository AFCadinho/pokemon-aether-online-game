extends RefCounted
## Apply source-authored or explicitly reviewed visibility for exact scene revisions.
## Keep downloaded geometry/materials and the source scene's animation library intact.
const DATA = preload("res://resources/battle/model_visibility/roaring_moon.json")
const REPAIRS = preload("res://resources/battle/model_visibility/catalog_repairs.json")
const Pack = preload("res://scripts/battle/animations/source_visibility_pack.gd")
const META := "pokeaether_source_visibility_revision"

static func _registry(identity: String) -> Dictionary:
	return REPAIRS.data if REPAIRS.data.models.has(identity) else DATA.data

static func matches(identity: String,digest: String) -> bool:
	digest = preload("res://scripts/services/model_pair_pilot.gd").source_digest(identity,digest)
	var model: Dictionary=_registry(identity).models.get(identity,{})
	return not digest.is_empty() and (digest==model.get("source_sha256","") or digest==model.get("container_sha256",""))

static func apply(actor: Node,identity: String,digest: String) -> bool:
	if actor==null or not matches(identity,digest):return false
	var revision:=identity+":"+digest
	if actor.get_meta(META,"")==revision:return true
	var players:=actor.find_children("*","AnimationPlayer",true,false)
	if players.size()!=1:return false
	var player: AnimationPlayer=players[0]
	if not player.has_animation_library(""):return false
	var original:=player.get_animation_library("")
	var private_library: AnimationLibrary=original.duplicate(true)
	var registry := _registry(identity)
	var model: Dictionary=registry.models[identity]
	var clips: Dictionary=registry.profiles[model.profile].clips if model.has("profile") else registry.clips
	var manifest: Dictionary={"schema":1,"glb_sha256":model.glb_sha256,"clips":clips}
	player.remove_animation_library("")
	player.add_animation_library("",private_library)
	var pack:=Pack.new()
	if not pack.apply(actor,manifest,model.glb_sha256):
		player.remove_animation_library("")
		player.add_animation_library("",original)
		return false
	actor.set_meta(META,revision)
	return true
