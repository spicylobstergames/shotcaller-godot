extends Node
var game:Node


const leader = {
	"arthur": {
		"bonus damage": 10,
		"stun": 0.25,
		"description": "25% chance to stun enemy"
	},
	"bokuden": {
		"bonus attack speed": 0.2,
		"critical": 0.2,
		"description": "20% chance to double damage"
	},
	"lorne": {
		"respawn reduction": 0.8,
		"defense": 5,
		"description": "Ignores 5 damage on hits"
	},
	"hongi": {
		"bonus hp": 100,
		"counter": 10,
		"description": "Returns 10 damage on melee hits"
	}, 
	"nagato": {
		"bonus retreat speed": 1.2,
		"multi": 2,
		"description": "Multiple units"
		},
	"osman": {
		"bonus gold": 1,
		"drinker": 1.2,
		"description": "Extra 20% effect from potions"
	},
	"raja": {
		"bonus speed": 1.1,
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



func _ready():
	game = get_tree().get_current_scene()



func projectile_release(attacker):
	if attacker.display_name in game.unit.skills.leader:
		var attacker_skills = game.unit.skills.leader[attacker.display_name]
		
		if "multishot" in attacker_skills:
			var enemies = attacker.get_units_on_sight({"team": attacker.oponent_team()})
			var sorted = game.utils.sort_by_distance(attacker, enemies)
			for enemy in sorted:
				if enemy.unit != attacker.target and game.unit.attack.in_range(attacker, enemy.unit):
					secondary_projectile(attacker, enemy.unit)


func secondary_projectile(attacker, target):
	var target_position = target.global_position + target.collision_position
	attacker.weapon.look_at(target_position)
	game.unit.attack.projectile_start(attacker, target)



func hit_modifiers(attacker, target, projectile, modifiers):
	modifiers = {
		"damage": attacker.current_damage,
		"cleave": "cleave" in modifiers,
		"dodge": false,
		"counter": false,
		"pierce": false
	}
	if target and target.display_name in game.unit.skills.leader:
		var target_skills = game.unit.skills.leader[target.display_name]
		
		if "dodge" in target_skills:
			modifiers.dodge = (randf() <  target_skills.dodge)
			
		if "defense" in target_skills:
			modifiers.damage -= target_skills.defense
		
		if not modifiers.counter:
			if "counter" in target_skills and not attacker.ranged:
				modifiers.damage = target_skills.counter
				game.unit.attack.take_hit(target, attacker, projectile, modifiers)
			
	if attacker.display_name in game.unit.skills.leader:
		var attacker_skills = game.unit.skills.leader[attacker.display_name]
		if not modifiers.counter:
			if "stun" in attacker_skills:
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
				attacker.current_attack_speed = attacker.attack_speed + (attacker_skills.agile * min(10, attacker.attack_count))
	
	return modifiers
