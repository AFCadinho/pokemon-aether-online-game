extends "catalog_batch_battle_review.gd"
## Capture a material variant using measured geometry only after exact SCN parity.
var paired_geometry:Dictionary={}
var measured_normals:Dictionary={}
func _initialize() -> void:
 var parity_path:=OS.get_environment("POKEAETHER_VARIANT_PARITY")
 var measurement_path:=OS.get_environment("POKEAETHER_VARIANT_NORMAL_MEASUREMENTS")
 var runtime_path:=OS.get_environment("POKEAETHER_PHASE5_RUNTIME_REPORT")
 var normal_runtime_path:=OS.get_environment("POKEAETHER_VARIANT_NORMAL_RUNTIME")
 assert(parity_path.is_absolute_path() and measurement_path.is_absolute_path())
 var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(parity_path))
 for p:Dictionary in proof.pairs:paired_geometry[p.species]=p
 for row:Dictionary in JSON.parse_string(FileAccess.get_file_as_string(measurement_path)).entries:
  measured_normals[row.species]=row
 var normal_rows:Dictionary={}
 for row:Dictionary in JSON.parse_string(FileAccess.get_file_as_string(normal_runtime_path)):
  normal_rows[row.species]=row
 for row:Dictionary in JSON.parse_string(FileAccess.get_file_as_string(runtime_path)):
  var name:=str(row.species).trim_suffix("-shiny")
  assert(paired_geometry.has(name) and measured_normals.has(name))
  var p:Dictionary=paired_geometry[name]
  assert(p.shiny_runtime_sha256==row.runtime_sha256 and FileAccess.get_sha256(row.runtime_path)==row.runtime_sha256)
  assert(normal_rows[name].runtime_sha256==p.normal_runtime_sha256 and FileAccess.get_sha256(normal_rows[name].runtime_path)==p.normal_runtime_sha256)
 _run.call_deferred()
func _measure(entry:Dictionary, model:Node3D, player:AnimationPlayer) -> Dictionary:
 if entry.species=="dragonite":return await super._measure(entry,model,player)
 var name:=str(entry.species).trim_suffix("-shiny")
 var measured:Dictionary=measured_normals[name].duplicate(true)
 model.scale=Vector3.ONE*float(measured.scale)
 measured["measurement_origin"]="Exact normal/shiny scene geometry, skin and motion parity; normal 60/120 Hz evidence reused; screenshots and bounds captured from shiny"
 measured["paired_geometry_sha256"]=paired_geometry[name].geometry_animation_sha256
 for action in measured.clips:
  assert(player.has_animation(action) and is_equal_approx(player.get_animation(action).length,measured.clips[action].duration))
 return measured
func _validate_motion(entry:Dictionary, _model:Node3D, _player:AnimationPlayer, _measured:Dictionary) -> Dictionary:
 return measured_normals[str(entry.species).trim_suffix("-shiny")].corrected_clearance_120hz.duplicate(true)
