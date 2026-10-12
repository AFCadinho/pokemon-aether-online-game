extends RefCounted
## Shared by model motion, wind envelope and camera. Progress ends at contact.
const HEIGHT := 4.3

static func offset(progress: float, displacement: Vector3) -> Vector3:
	var q := clampf(progress,0,1)
	var forward := 0.15*smoothstep(0.0,0.45,q)+0.85*pow(smoothstep(0.45,1.0,q),1.3)
	return displacement*forward + Vector3.UP*HEIGHT*sin(smoothstep(0.0,1.0,q)*PI)

static func direction(progress: float, displacement: Vector3) -> Vector3:
	return (offset(minf(1,progress+0.015),displacement)-offset(maxf(0,progress-0.015),displacement)).normalized()
