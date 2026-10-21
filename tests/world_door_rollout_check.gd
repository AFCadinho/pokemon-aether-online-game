extends SceneTree
class Actor:
	extends Node2D
	func get_feet_position()->Vector2:return global_position
class Access:
	extends Node
	var is_unlocked:=false
var failed:=false
var count:=0
func _init()->void:run.call_deferred()
func run()->void:
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "Export presets load")
	for section: String in presets.get_sections():
		if section.ends_with(".options"):
			continue
		check("resources/world/map_doors.json" in str(presets.get_value(section,"include_filter","")), section+" includes door catalog")
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/world/map_doors.json"))
	for path:String in catalog:
		var original:Node=load(path).instantiate()
		check(not original.has_node("DoorAnimator"),path+" has no competing legacy animator")
		var definitions:Array=catalog[path]
		var visual:Node=original.get_node(definitions[0].visual)
		var controller:Node=original.get_node("MapDoors")
		for entry:Dictionary in definitions:
			if not str(entry.lock).is_empty():check(original.has_node(entry.lock),entry.id+" existing access lock")
			if entry.enabled:
				var exit_node:=original.get_node_or_null(entry.exit)
				check(exit_node!=null and exit_node.has_method("contains_world_position") and not str(exit_node.get("target_scene_path")).is_empty(),entry.id+" keeps an authorized entrance")
				for spawn:String in entry.arrivals:check(original.has_node("Spawns/"+spawn),entry.id+" existing return marker")
		original.remove_child(visual);original.remove_child(controller);original.free()
		var map:=Node2D.new();map.scene_file_path=path;root.add_child(map)
		var players:=Node2D.new();players.name="Players"
		var entities:=Node2D.new();entities.name="Entities";map.add_child(entities);entities.add_child(players)
		var local:=Actor.new();local.name="Player";players.add_child(local);local.position=Vector2(-10000,-10000)
		var remotes:=Node2D.new();remotes.name="RemotePlayers";players.add_child(remotes)
		var locks:Dictionary={}
		for entry:Dictionary in definitions:
			if str(entry.lock).is_empty():continue
			var parts:=str(entry.lock).split("/")
			var parent:Node=map
			for i in range(parts.size()-1):
				if not parent.has_node(parts[i]):
					var folder:=Node.new();folder.name=parts[i];parent.add_child(folder)
				parent=parent.get_node(parts[i])
			var lock:=Access.new();lock.name=parts[-1];parent.add_child(lock);locks[entry.id]=lock
		map.add_child(visual);map.add_child(controller)
		for door:Node in controller.doors.values():door.set_process(false)
		var sfx:=root.get_node("SfxManager")
		for entry:Dictionary in definitions:
			count+=1
			var door:Node2D=controller.doors[entry.id]
			check(not door.pieces.is_empty(),entry.id+" resolves complete source layers")
			var front:Vector2=door.to_global(door.activation_rect.get_center())
			local.position=front
			var sound_count:=sfx.get_child_count()
			if locks.has(entry.id) or not entry.enabled:
				tick(door,0.5)
				check(door.open_amount==0.0 and sfx.get_child_count()==sound_count,entry.id+" locked/unavailable stays silent and closed")
			if not entry.enabled:continue
			if locks.has(entry.id):locks[entry.id].is_unlocked=true
			tick(door,0.5)
			check(door.open_amount==1.0 and sfx.get_child_count()==sound_count+1,entry.id+" approach opens with one sound")
			var remote:=Actor.new();remotes.add_child(remote);remote.position=front
			local.position=Vector2(-10000,-10000);tick(door,0.5)
			check(door.open_amount==1.0,entry.id+" remote player holds open")
			remote.free();tick(door,0.5)
			check(door.open_amount==0.0,entry.id+" closes when last player leaves")
			local.position=front
			if locks.has(entry.id):locks[entry.id].is_unlocked=false
			for spawn:String in entry.arrivals:
				sound_count=sfx.get_child_count()
				controller.prepare_player_arrival(spawn);controller.prepare_player_arrival(spawn);tick(door,0.5)
				check(door.open_amount==1.0 and sfx.get_child_count()==sound_count,entry.id+" return starts silently open")
				local.position=Vector2(-10000,-10000);tick(door,0.5);local.position=front
			local.position=Vector2(-10000,-10000)
		map.free()
	print("World door rollout: ",count," doors in ",catalog.size()," maps: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
func tick(door:Node,seconds:float)->void:
	for i in range(ceili(seconds/0.01)):door.call("_process",0.01)
func check(ok:bool,message:String)->void:
	if not ok:push_error("FAIL "+message)
	failed=failed or not ok
