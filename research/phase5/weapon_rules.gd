extends RefCounted
## Original Riftforge weapon behavior; missing fields retain the previous ranged starter behavior.

static func mode(weapon: Dictionary) -> String:
	return "melee" if str(weapon.get("attack_mode", "ranged")) == "melee" else "ranged"

static func interval(weapon: Dictionary) -> float:
	var base: float = maxf(0.1, float(weapon.get("attack_interval", 0.205)))
	var speed_bonus: float = clampf(float(weapon.get("attack_speed_percent", 0.0)), -70.0, 300.0)
	return clampf(base / (1.0 + speed_bonus / 100.0), 0.1, 2.0)

static func reach(weapon: Dictionary) -> float:
	var default_reach: float = 3.1 if mode(weapon) == "melee" else 26.0
	return clampf(float(weapon.get("attack_reach", default_reach)), 1.0, 40.0)

static func within_arc(origin: Vector3, aim: Vector3, target: Vector3, radius: float, half_angle_deg: float = 65.0) -> bool:
	var difference: Vector3 = target - origin
	difference.y = 0.0
	if difference.length_squared() > radius * radius:
		return false
	if difference.length_squared() <= 0.0001:
		return true
	var facing: Vector3 = Vector3(aim.x, 0.0, aim.z)
	if facing.length_squared() <= 0.0001:
		return false
	return difference.normalized().dot(facing.normalized()) >= cos(deg_to_rad(half_angle_deg))
