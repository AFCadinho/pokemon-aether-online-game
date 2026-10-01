extends "catalog_batch_battle_review.gd"
## Current screenshots; reuse measured geometry only after exact old/new scene parity.
var revisions:Dictionary={}
var measurements:Dictionary={}
func _initialize() -> void:
 var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_REVISION_PARITY")))
 for p:Dictionary in proof.pairs:revisions[p.species]=p
 for r:Dictionary in JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_REVISION_MEASUREMENTS"))).entries:measurements[r.species]=r
 var old:Dictionary={}
 for r:Dictionary in JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_REVISION_OLD_RUNTIME"))):old[r.species]=r
 for r:Dictionary in JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_PHASE5_RUNTIME_REPORT"))):
  assert(revisions.has(r.species) and measurements.has(r.species))
  var p:Dictionary=revisions[r.species]
  assert(p.shiny_runtime_sha256==r.runtime_sha256 and FileAccess.get_sha256(r.runtime_path)==r.runtime_sha256)
  assert(p.normal_runtime_sha256==old[r.species].runtime_sha256 and FileAccess.get_sha256(old[r.species].runtime_path)==p.normal_runtime_sha256)
 _run.call_deferred()
func _measure(entry:Dictionary,model:Node3D,player:AnimationPlayer) -> Dictionary:
 if entry.species=="dragonite":return await super._measure(entry,model,player)
 var measured:Dictionary=measurements[entry.species].duplicate(true)
 model.scale=Vector3.ONE*float(measured.scale)
 measured["measurement_origin"]="Previous measured scene; exact old/new geometry, skins, transforms and animation parity; current revised material screenshots and bounds independently rendered"
 measured["revision_geometry_sha256"]=revisions[entry.species].geometry_animation_sha256
 for action in measured.clips:assert(player.has_animation(action) and is_equal_approx(player.get_animation(action).length,measured.clips[action].duration))
 return measured
func _validate_motion(entry:Dictionary,_model:Node3D,_player:AnimationPlayer,_measured:Dictionary) -> Dictionary:
 return measurements[entry.species].corrected_clearance_120hz.duplicate(true)
