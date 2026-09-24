extends Resource
## Riftforge original data contract. This is NOT an extracted Grim Dawn skill.
## Instances can later be saved as .tres or generated from original JSON.

@export var skill_id: StringName = &""
@export var display_name: String = ""
@export_enum("projectile", "area") var delivery: String = "projectile"
@export var damage_type: StringName = &"fire"
@export var base_damage: float = 10.0
@export var mana_cost: float = 5.0
@export var cooldown: float = 0.5
@export var cast_range: float = 12.0
@export var radius: float = 0.0
@export_range(0.0, 1.0) var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.5

func validate() -> Array[String]:
	var errors: Array[String] = []
	if String(skill_id).strip_edges().is_empty():
		errors.append("skill_id is required")
	if delivery != "projectile" and delivery != "area":
		errors.append("delivery must be projectile or area")
	if base_damage < 0.0 or mana_cost < 0.0 or cooldown < 0.0:
		errors.append("damage, mana and cooldown must not be negative")
	if cast_range <= 0.0:
		errors.append("cast_range must be positive")
	if delivery == "area" and radius <= 0.0:
		errors.append("area skills need a positive radius")
	if crit_chance < 0.0 or crit_chance > 1.0 or crit_multiplier < 1.0:
		errors.append("critical settings are invalid")
	return errors
