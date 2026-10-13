extends "catalog_dlc_runtime_review.gd"
## Source-scale Linux previews, including authored attachment regression samples.
func _run() -> void:
 process_frame.connect(func(): RenderingServer.force_draw(false))
 await super._run()

func _review(entry: Dictionary, output: String) -> Dictionary:
 root.size=Vector2i(640,640)
 var result: Dictionary=await super._review(entry,output)
 if not result.errors.is_empty():return result
 var packed:=load(entry.runtime_path) as PackedScene
 var actor:=packed.instantiate() as Node3D
 actor.scale*=float(entry.get("review_scale",1.0));world.add_child(actor)
 var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0]
 var box:=AABB();var first:=true
 for action: String in entry.animations:
  for fraction in [0.0,0.25,0.5,0.75,1.0]:
   var b:=await _sample(actor,player,action,fraction)
   box=b if first else box.merge(b);first=false
 var frames:=output.path_join(entry.species+"-frames")
 DirAccess.make_dir_recursive_absolute(frames)
 var sequence:=[]
 for i in 24:sequence.append({"action":"idle","fraction":float(i%12)/12,"angle":TAU*i/24})
 for action: String in entry.animations:
  for i in 12:sequence.append({"action":action,"fraction":float(i)/11,"angle":0.25})
 var caption:=Label.new();caption.position=Vector2(12,12);root.add_child(caption)
 var attachment_samples:=0
 for i in sequence.size():
  var pose: Dictionary=sequence[i]
  await _sample(actor,player,pose.action,pose.fraction)
  for attachment: BoneAttachment3D in actor.find_children("*","BoneAttachment3D",true,false):
   var skeleton:=attachment.get_parent() as Skeleton3D
   var expected:=skeleton.global_transform*skeleton.get_bone_global_pose(attachment.bone_idx)
   if not attachment.global_transform.is_equal_approx(expected):
    result.errors.append("Attachment diverges from bone: "+str(attachment.name)+"/"+str(pose.action))
   attachment_samples+=1
  camera.size=maxf(box.size.length()*1.12,0.1)
  camera.position=box.get_center()+Vector3(sin(pose.angle),0.25,cos(pose.angle)).normalized()*camera.size*3
  camera.look_at(box.get_center())
  caption.text=entry.species+" · "+pose.action+"\nReconstructie · visuele beoordeling vereist"
  await RenderingServer.frame_post_draw
  if root.get_texture().get_image().save_png(frames.path_join("%04d.png"%i))!=OK:result.errors.append("Frame write failed")
 result["attachment_samples"]=attachment_samples
 result["video_frames"]=sequence.size()
 result["video_policy"]="24-frame turntable; 12 evenly spaced samples per clip, not real-time playback"
 actor.free();caption.free()
 return result
