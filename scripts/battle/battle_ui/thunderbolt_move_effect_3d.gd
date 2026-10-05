extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## SV Thunderbolt artwork on spatial ribbons, sampled from the native move clock.
const BOLT_SPRITES := {
	"bolt_charge": [preload("res://assets/battles/moves_3d/sv_thunderbolt/cpt_2_thunder0004.png"), Vector3(1, 0.82, 0.15), 8.0, false],
	"bolt_arc": [preload("res://assets/battles/moves_3d/sv_thunderbolt/upt_ew0085_thunder2203.png"), Vector3(1, 0.85, 0.18), 16.0, false],
	"bolt_core": [preload("res://assets/battles/moves_3d/sv_thunderbolt/upt_ew0085_thunder2203.png"), Vector3(1, 0.97, 0.74), 16.0, false],
	"bolt_hit": [preload("res://assets/battles/moves_3d/sv_thunderbolt/cpt_2_thunder0004.png"), Vector3(1, 0.9, 0.3), 8.0, false],
	"bolt_burst": [preload("res://assets/battles/moves_3d/sv_thunderbolt/cpt_2_shock0010.png"), Vector3(1, 0.87, 0.4), 8.0, false],
	"bolt_flash": [preload("res://assets/battles/moves_3d/sv_thunderbolt/cpt_0_flash0202.png"), Vector3(1, 0.96, 0.65), 1.0, false],
}

func _sprite_values(id: String) -> Array:
	return BOLT_SPRITES[id] if BOLT_SPRITES.has(id) else super._sprite_values(id)

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if key != "thunderbolt": return super._draw_source_move(from, to, right, up)
	var facing := Basis(right, up, right.cross(up))
	var travel := (elapsed - launch) / maxf(impact - launch, 0.01)
	var after := (elapsed - impact) / maxf(duration * 0.28, 0.01)
	var size := clampf(float(anchors.call().radius), 0.45, 1.15)
	if travel >= 0 and after < 0.75:
		var fade := 1.0 - clampf(after / 0.75, 0, 1)
		for i in 2:
			_source_sprite(from, 1.25, "bolt_charge", fmod(travel * 0.7 + i * 0.3, 0.75), fade, facing, i * PI * 0.5)
		_draw_discharge(from, from.lerp(to, clampf(travel, 0, 1)), fade)
	if hit and after >= 0 and after < 1:
		# Impact geometry requires event evidence; a dodging target never gets a corona.
		_source_sprite(to, size * 1.6, "bolt_flash", 0, (1.0 - after) * 0.8, facing)
		if after < 0.5:
			_source_sprite(to, size * (2.0 + after * 1.5), "bolt_burst", after * 2.0, 1.0 - after * 2.0, facing)
		for i in 4:
			var angle := i * TAU / 4.0
			var offset := Vector3(cos(angle), sin(angle), sin(angle * 2.0)) * size * 0.38
			_source_sprite(to + offset, size * 2.2, "bolt_hit", 0.125 + after * 0.875, 1.0 - after,
				facing, angle + after * 0.5)
	return true

func _draw_discharge(from: Vector3, to: Vector3, fade: float) -> void:
	var delta := to - from
	if delta.length_squared() < 0.0001: return
	var direction := delta.normalized()
	var side := direction.cross(Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT).normalized()
	var vertical := side.cross(direction).normalized()
	# Three intersecting ribbons keep the source lightning visible from any orbit.
	# Their positions, orientation and atlas phase are independent of the camera.
	for i in 3:
		var angle := i * PI / 3.0
		var x := side * cos(angle) + vertical * sin(angle)
		var basis_value := Basis(x, -direction, x.cross(-direction))
		var frame := 2 + (int(floor((elapsed - launch) * 24.0)) + i * 3) % 10
		_source_sprite((from + to) * 0.5, 1.0, "bolt_core" if i == 2 else "bolt_arc",
			float(frame) / 16.0, fade, basis_value, 0.0, Vector2(0.62 if i == 2 else 0.85, delta.length()))
