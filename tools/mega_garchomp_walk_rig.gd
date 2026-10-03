extends RefCounted

# Hand-rigged on the native 96 px grid. Upper-body and seat pixels are locked.
# The game exports every pixel at exactly 2x, with no filtered rotations.
const SIZE := 96
static var SIDE_NEAR := PackedVector2Array([Vector2(51,47),Vector2(59,47),Vector2(64,53),Vector2(65,65),Vector2(46,65),Vector2(49,55),Vector2(51,52)])
static var SIDE_FAR := PackedVector2Array([Vector2(31,54),Vector2(39,54),Vector2(45,57),Vector2(46,65),Vector2(26,65),Vector2(26,58)])

static func animate(tile: Image, row: int, phase: int) -> Image:
	var source := tile.duplicate() as Image
	source.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	if phase == 0:
		return tile.duplicate()
	var result: Image
	if row == 1 or row == 2:
		if row == 2:
			source.flip_x()
		result = _side(source, phase)
		if row == 2:
			result.flip_x()
	else:
		result = _front_back(source, row, phase)
	result.resize(SIZE * 2, SIZE * 2, Image.INTERPOLATE_NEAREST)
	return result

static func _side(source: Image, phase: int) -> Image:
	var base := source.duplicate() as Image
	var near := _extract(source, SIDE_NEAR)
	_erase(base, SIDE_NEAR)
	_erase(base, SIDE_FAR)
	# Contact -> passing -> opposite contact -> recovery. The far leg is
	# constructed from the existing long leg, behind the untouched torso/arms.
	var far_leg := near.duplicate() as Image
	for y in range(SIZE):
		for x in range(SIZE):
			var color := far_leg.get_pixel(x, y)
			if color.a > 0:
				color.r *= 0.80
				color.g *= 0.80
				color.b *= 0.88
				far_leg.set_pixel(x,y,color)
	var result := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	var near_dx: int = [0,-9,-18,-9][phase]
	var far_dx: int = [0,8,17,8][phase]
	var near_lift: int = [0,4,0,0][phase]
	var far_lift: int = [0,0,0,4][phase]
	# Same hip anchor, opposite feet; far leg has an eight-pixel hip inset.
	_paint_leg(result, far_leg, 47, -8, far_dx - 15, far_lift, 63)
	result.blend_rect(base, Rect2i(0,0,SIZE,SIZE), Vector2i.ZERO)
	_paint_leg(result, near, 47, 0, near_dx, near_lift, 63)
	return result

static func _front_back(source: Image, row: int, phase: int) -> Image:
	var result := source.duplicate() as Image
	var top := 51 if row == 0 else 54
	for side in range(2):
		var start := 34 if side == 0 else 49
		var finish := 46 if side == 0 else 62
		var shape := PackedVector2Array([Vector2(start,top),Vector2(finish,top),Vector2(finish,65),Vector2(start,65)])
		var leg := _extract(source,shape)
		_erase(result,shape)
		var bottom := leg.get_used_rect().end.y - 1
		var target_bottom: int = ([0,63,63,56] if side == 0 else [0,56,58,63])[phase]
		_paint_leg(result,leg,top,0,0,bottom-target_bottom,bottom)
	return result

static func _paint_leg(target: Image, leg: Image, hip_y: int, hip_dx: int, foot_dx: int, lift: int, bottom: int) -> void:
	# Inverse map avoids holes when extending/compressing the shin. A bent
	# knee leads the lifted foot; all samples stay on the source pixel grid.
	var height := float(bottom - hip_y)
	var target_height := maxf(height - lift, 1.0)
	for y in range(hip_y, mini(SIZE, bottom-lift+1)):
		var t := clampf(float(y-hip_y) / target_height,0.0,1.0)
		var foot_height := minf(4.0,height-1.0)
		var shin_height := maxf(target_height-foot_height,1.0)
		var sy := y + lift if y >= bottom-lift-foot_height else hip_y + roundi(float(y-hip_y)/shin_height*(height-foot_height))
		sy = clampi(sy,hip_y,bottom)
		var knee := -2.0 * sin(t * PI) if lift > 0 and foot_dx != 0 else 0.0
		var dx := hip_dx + roundi(t * foot_dx + knee)
		for x in range(SIZE):
			var sx := x - dx
			if sx < 0 or sx >= SIZE:
				continue
			var pixel := leg.get_pixel(sx,sy)
			if pixel.a > 0:
				target.set_pixel(x,y,pixel)

static func _extract(source: Image, shape: PackedVector2Array) -> Image:
	var result := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),shape):
				result.set_pixel(x,y,source.get_pixel(x,y))
	return result

static func _erase(target: Image, shape: PackedVector2Array) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),shape):
				target.set_pixel(x,y,Color.TRANSPARENT)
