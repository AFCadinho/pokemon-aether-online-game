extends "res://tools/sprite_factory/phase5_battle_review.gd"
func _render_frame() -> void:
 Engine.max_fps=0
 OS.low_processor_usage_mode=false
 await process_frame
 RenderingServer.force_draw(false)

func _measure(entry:Dictionary, model:Node3D, player:AnimationPlayer) -> Dictionary:
 var result:Dictionary=await super._measure(entry,model,player)
 var margin_text:=OS.get_environment("POKEAETHER_BATCH_CLEARANCE_MARGIN")
 if not margin_text.is_empty():
  assert(margin_text.is_valid_float())
  var margin:=float(margin_text)
  assert(is_finite(margin) and margin>=.025 and margin<=.10)
  result.candidate_lift=maxf(0,margin-float(result.clips.idle.minimum_y))
  for action in result.clips:
   result.clips[action].clearance_with_idle_lift=float(result.clips[action].minimum_y)+result.candidate_lift
  result["clearance_margin"]=margin
 return result
