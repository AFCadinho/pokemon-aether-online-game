extends RefCounted
## Restore source-authored mesh visibility only for these exact scene revisions.
## Keep downloaded geometry/materials and the source scene's animation library intact.
const DATA = preload("res://resources/battle/model_visibility/roaring_moon.json")
const Pack = preload("res://scripts/battle/animations/source_visibility_pack.gd")
const META := "pokeaether_source_visibility_revision"

static func matches(identity: String,digest: String) -> bool:
	var model: Dictionary=DATA.data.models.get(identity,{})
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
	var model: Dictionary=DATA.data.models[identity]
	var manifest: Dictionary={"schema":1,"glb_sha256":model.glb_sha256,"clips":DATA.data.clips}
	player.remove_animation_library("")
	player.add_animation_library("",private_library)
	var pack:=Pack.new()
	if not pack.apply(actor,manifest,model.glb_sha256):
		player.remove_animation_library("")
		player.add_animation_library("",original)
		return false
	actor.set_meta(META,revision)
	return true
