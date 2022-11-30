extends Node
var game:Node

# self = Behavior.skills


const leader = {
	"arthur": {
		"bonus damage": 20,
		"stun": 0.25,
		"description": "25% chance to stun enemy"
	},
	"bokuden": {
		"bonus attack speed": 0.2,
		"critical": 0.2,
		"description": "20% chance to double damage"
	},
	"joan": {
		"bonus hp": 100,
		"counter": 10,
		"description": "Returns 10 damage on melee hits"
	},
	"hongi": {
		"bonus hp": 100,
		"counter": 10,
		"description": "Returns 10 damage on melee hits"
	},
	"lorne": {
		"respawn reduction": 0.8,
		"defense": 5,
		"description": "Ignores extra 5 damage on hits"
	},
	"nagato": {
		"bonus_retreat_speed": 10,
		"clones": 2,
		"description": "Multiple units"
		},
	"osman": {
		"bonus gold": 1,
		"drinker": 1.2,
		"description": "Extra 20% effect from potions"
	},
	"raja": {
		"bonus_speed": 5,
		"dodge": 0.2,
		"description": "20% chance to avoid hits"
	},
	"robin": {
		"bonus projectile speed": 1.5,
		"multishot": 2,
		"description": "Can shoot 2 arrows at once"
	},
	"rollo": {
		"bonus melee range": 1.5,
		"cleave": 0.5,
		"description": "Cleaves enemies by  50% damage"
	},
	"sida": {
		"bonus vision": 1.5,
		"pierce": 0.4,
		"description": "40% spear piercing chance"
	},
	"takoda": {
		"bonus hp regen": 2,
		"bleed": 5,
		"description": "Extra 5 stack damage max 10"
	},
	"tomyris": {
		"bonus range": 1.4,
		"agile": 0.1,
		"description": "Extra 10% stack attack speed max 10"
	}
}


func get_value(unit, skill_name):
	if unit.type == "leader":
		var leader_skills = Behavior.skills.leader[unit.display_name]
		if skill_name in leader_skills:
			return leader_skills[skill_name]
	return 0

func _ready():
	game = get_tree().get_current_scene()



func projectile_release(attacker):
	if attacker.display_name in Behavior.skills.leader:
		var attacker_skills = Behavior.skills.leader[attacker.display_name]
		
		if "multishot" in attacker_skills:
			var enemies = attacker.get_units_on_sight({"team": attacker.oponent_team()})
			var sorted = attacker.sort_by_distance(enemies)
			for enemy in sorted:
				if (enemy.unit != attacker.target and 
					Behavior.attack.in_range(attacker, enemy.unit)):
					secondary_projectile(attacker, enemy.unit)


func secondary_projectile(attacker, target):
	var target_position = target.global_position + target.collision_position
	attacker.weapon.look_at(target_position)
	Behavior.attack.projectile_start(attacker, target)



func hit_modifiers(attacker, target, projectile, modifiers):
	var damage
	if modifiers.has("damage"): 
		damage = modifiers.damage
	else:
		damage = Behavior.modifiers.get_value(attacker, "damage")
	modifiers = {
		"damage": damage,
		"cleave": "cleave" in modifiers,
		"dodge": false,
		"counter": false,
		"pierce": false
	}
	if target and target.display_name in Behavior.skills.leader:
		var target_skills = Behavior.skills.leader[target.display_name]
		
		if "dodge" in target_skills:
			modifiers.dodge = (randf() <  target_skills.dodge)
			
		if not modifiers.counter:
			if "counter" in target_skills and not attacker.ranged:
				modifiers.damage = target_skills.counter
				Behavior.attack.take_hit(target, attacker, projectile, modifiers)
			
	if attacker.display_name in Behavior.skills.leader:
		var attacker_skills = Behavior.skills.leader[attacker.display_name]
		if not modifiers.counter:
			if "stun" in attacker_skills and target.type != "building":
				if randf() < attacker_skills.stun: 
					target.stun_start()
			
			if "critical" in attacker_skills:
				if randf() <  attacker_skills.critical:
					modifiers.damage *= 2
			
			if "cleave" in attacker_skills:
				if modifiers.cleave:
					modifiers.damage *= attacker_skills.cleave
			
			if "pierce" in attacker_skills:
				if randf() <  attacker_skills.pierce:
					modifiers.pierce = true
			
			if "bleed" in attacker_skills:
				modifiers.damage += attacker_skills.bleed * min(10, attacker.attack_count)
			
			if "agile" in attacker_skills:
				Behavior.modifiers.remove(attacker, "attack_speed", "agile")
				Behavior.modifiers.add(attacker, "attack_speed", "agile", attacker_skills.agile * min(10, attacker.attack_count))
	
	return modifiers
