extends RefCounted
## Original, intentionally simplified ARPG damage model; NOT Grim Dawn's formulas.

static func damage(base: float, flat_bonus: float, increased_percent: float, more_multiplier: float, crit_chance: float, crit_multiplier: float, resistance: float, roll: float) -> int:
	var raw: float = maxf(0.0, base + flat_bonus)
	raw *= maxf(0.0, 1.0 + increased_percent / 100.0)
	raw *= maxf(0.0, more_multiplier)
	if roll < clampf(crit_chance, 0.0, 1.0):
		raw *= maxf(1.0, crit_multiplier)
	raw *= 1.0 - clampf(resistance, -0.5, 0.75)
	return maxi(1, int(round(raw)))

static func incoming(raw: float, armor: float) -> int:
	return maxi(1, int(round(raw * (1.0 - clampf(armor, 0.0, 0.7)))))
