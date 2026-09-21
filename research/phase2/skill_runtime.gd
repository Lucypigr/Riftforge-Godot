extends RefCounted
## Shared casting and cooldown logic. Phase 4 damage is opt-in, preserving old regressions.
const SkillDefinition = preload("res://research/phase2/skill_definition.gd")
const CombatResolver = preload("res://research/phase2/combat_resolver.gd")
const CombatResolverV2 = preload("res://research/phase4/combat_resolver_v2.gd")

var mana: float = 100.0
var use_combat_v2: bool = false
var _cooldowns: Dictionary = {}

func _init(start_mana: float = 100.0) -> void:
	mana = maxf(0.0, start_mana)

func remaining(skill_id: StringName) -> float:
	return float(_cooldowns.get(skill_id, 0.0))

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for skill_id in _cooldowns.keys():
		var left: float = maxf(0.0, float(_cooldowns[skill_id]) - delta)
		if left == 0.0:
			_cooldowns.erase(skill_id)
		else:
			_cooldowns[skill_id] = left

func can_cast(skill: SkillDefinition) -> Dictionary:
	if skill == null or not skill.validate().is_empty():
		return {"ok": false, "reason": "invalid_skill"}
	if remaining(skill.skill_id) > 0.0:
		return {"ok": false, "reason": "cooldown"}
	if mana < skill.mana_cost:
		return {"ok": false, "reason": "insufficient_mana"}
	return {"ok": true}

func cast(skill: SkillDefinition, origin: Vector3, aim: Vector3, targets: Array, modifiers: Dictionary = {}, crit_roll: float = 0.99) -> Dictionary:
	var allowed: Dictionary = can_cast(skill)
	if not bool(allowed.get("ok", false)):
		return allowed
	var horizontal_aim: Vector3 = Vector3(aim.x, 0.0, aim.z)
	if skill.delivery == "projectile" and horizontal_aim.length_squared() < 0.0001:
		return {"ok": false, "reason": "invalid_aim"}
	mana -= skill.mana_cost
	_cooldowns[skill.skill_id] = skill.cooldown
	var shots: Array[Dictionary] = []
	var hits: Array[Dictionary] = []
	var feedback: Array[Dictionary] = []
	if skill.delivery == "projectile":
		# Spawn only: projectile collision MUST call resolve_projectile_hit.
		shots.append({"skill_id": skill.skill_id, "origin": origin,
			"direction": horizontal_aim.normalized(), "max_distance": skill.cast_range})
	else:
		for candidate in targets:
			if typeof(candidate) != TYPE_DICTIONARY:
				continue
			var target: Dictionary = candidate
			if not target.has("position") or typeof(target["position"]) != TYPE_VECTOR3:
				continue
			var difference: Vector3 = target["position"] - origin
			difference.y = 0.0
			if difference.length_squared() > skill.radius * skill.radius:
				continue
			var result: Dictionary = CombatResolverV2.resolve(skill, target, modifiers, randf(), randf()) if use_combat_v2 else CombatResolver.resolve(skill, target, modifiers, crit_roll)
			if bool(result.get("ok", false)):
				if bool(result.get("hit", true)):
					hits.append({"target_id": target.get("id", ""), "damage": result["damage"]})
				feedback.append(result["feedback"])
	return {"ok": true, "mana_left": mana, "shots": shots, "hits": hits, "feedback": feedback}

func resolve_projectile_hit(skill: SkillDefinition, target: Dictionary, modifiers: Dictionary = {}, crit_roll: float = 0.99) -> Dictionary:
	if skill == null or skill.delivery != "projectile":
		return {"ok": false, "reason": "not_a_projectile", "damage": 0}
	return CombatResolverV2.resolve(skill, target, modifiers, randf(), crit_roll) if use_combat_v2 else CombatResolver.resolve(skill, target, modifiers, crit_roll)
