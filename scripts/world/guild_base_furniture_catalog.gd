extends RefCounted

const DATA_PATH := "res://data/guild_base_furniture.json"
const ATLAS_PATH := "res://data/guild_base_furniture_atlas.json"
static var data: Dictionary = {}
static var atlas: Dictionary = {}
static var items_by_id: Dictionary = {}

static func load_data() -> Dictionary:
	if data.is_empty():
		data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		atlas = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_PATH))
		for spec: Dictionary in data.items:
			items_by_id[str(spec.id)] = spec
	return data

static func item(id: String) -> Dictionary:
	load_data()
	return items_by_id.get(id, {})

static func footprint(placement: Dictionary) -> Rect2i:
	return Rect2i(int(placement.get("x", 0)), int(placement.get("y", 0)), int(placement.width), int(placement.height))

static func blocked_cells(placements: Array) -> Dictionary:
	var cells := {}
	for placement: Dictionary in placements:
		for cell: Vector2i in movement_cells(placement):
			cells[cell] = true
	return cells

static func movement_cells(placement: Dictionary) -> Array[Vector2i]:
	var spec := item(str(placement.furnitureId))
	var cells: Array[Vector2i] = []
	if str(spec.get("placement", "")) == "surface":
		return cells
	if not spec.has("collisionCells"):
		return rect_cells(footprint(placement)) if bool(spec.get("blocksMovement", false)) else cells
	var origin := Vector2i(int(placement.x), int(placement.y))
	if bool(spec.resizable):
		var mask := {}
		for cell: Array in spec.collisionCells:
			mask[Vector2i(cell[0], cell[1])] = true
		for y: int in range(int(placement.height)):
			for x: int in range(int(placement.width)):
				var source := Vector2i(0 if x == 0 else (2 if x == int(placement.width) - 1 else 1), 0 if y == 0 else (2 if y == int(placement.height) - 1 else 1))
				if mask.has(source):
					cells.append(origin + Vector2i(x, y))
	else:
		for cell: Array in spec.collisionCells:
			cells.append(origin + Vector2i(cell[0], cell[1]))
	return cells

static func rect_cells(rectangle: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(rectangle.position.y, rectangle.end.y):
		for x: int in range(rectangle.position.x, rectangle.end.x):
			cells.append(Vector2i(x, y))
	return cells

static func validate(room: Node, placements: Array) -> String:
	if placements.size() > int(load_data().maxRoomItems):
		return "invalid"
	var definition: Dictionary = load_data().rooms.get(room.room_key, {})
	var occupied := {}
	var rugs := {}
	var walls := {}
	var used_slots := {}
	var reserved := {}
	var by_id := {}
	for rectangle: Array in definition.get("reservedRects", []):
		for cell: Vector2i in rect_cells(Rect2i(rectangle[0], rectangle[1], rectangle[2], rectangle[3])):
			reserved[cell] = true
	for placement: Dictionary in placements:
		if by_id.has(placement.id):
			return "invalid"
		by_id[placement.id] = placement
	for placement: Dictionary in placements:
		var spec := item(str(placement.furnitureId))
		if spec.is_empty():
			return "invalid"
		if str(spec.placement) == "surface":
			var parent: Dictionary = by_id.get(str(placement.get("parentId", "")), {})
			var slot := int(placement.get("slot", -1))
			var parent_spec := item(str(parent.get("furnitureId", "")))
			if parent.is_empty() or parent.get("parentId") != null or parent.id == placement.id or slot < 0 or slot >= parent_spec.get("surfaceSlots", []).size():
				return "surface_required"
			var key := str(parent.id) + ":" + str(slot)
			if used_slots.has(key):
				return "overlap"
			used_slots[key] = true
			continue
		var rectangle := footprint(placement)
		if placement.get("parentId") != null or placement.get("slot") != null:
			return "invalid"
		if bool(spec.resizable) and (rectangle.size.x < 2 or rectangle.size.y < 2):
			return "invalid"
		if not bool(spec.resizable) and rectangle.size != Vector2i(spec.footprint[0], spec.footprint[1]):
			return "invalid"
		if str(spec.placement) == "wall" and rectangle.position.y != 4:
			return "outside"
		var region: Rect2 = room.get_node("FloorVisibilityMask").get_active_floor_region()
		var art_size := rectangle.size if bool(spec.resizable) else Vector2i(spec.visualSize[0], spec.visualSize[1])
		var offset := Vector2(0, -rectangle.size.y * 32) if bool(spec.resizable) else Vector2(spec.visualOffset[0], spec.visualOffset[1])
		var art := Rect2(Vector2(rectangle.position.x, rectangle.end.y) * 32 + offset, Vector2(art_size) * 32)
		if not region.encloses(art):
			return "outside"
		for cell: Vector2i in rect_cells(rectangle):
			if not room.is_walkable_tile(cell):
				return "outside"
			if not bool(spec.blocksMovement) and str(spec.category) == "floor":
				if rugs.has(cell):
					return "overlap"
				rugs[cell] = true
			if str(spec.placement) == "wall":
				if walls.has(cell):
					return "overlap"
				walls[cell] = true
		for cell: Vector2i in movement_cells(placement):
			if not room.is_walkable_tile(cell):
				return "outside"
			if occupied.has(cell) or reserved.has(cell):
				return "overlap"
			occupied[cell] = true
	var start := Vector2i(definition.entrance[0], definition.entrance[1])
	var reached := {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := point + direction
			if room.is_walkable_tile(next) and not occupied.has(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	for y: int in range(room.room_size.y):
		for x: int in range(room.room_size.x):
			var point := Vector2i(x, y)
			if room.is_walkable_tile(point) and not occupied.has(point) and not reached.has(point):
				return "path_blocked"
	return ""
