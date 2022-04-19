extends Node
var game:Node


const leader = {
	"arthur": {
		"stun": 0.25,
		"description": "25% chance to stun enemy"
	},
	"bokuden": {
		"critical": 0.2,
		"description": "20% chance to double damage"
	},
	"lorne": {
		"defense": 5,
		"description": "Ignores 5 damage on hits"
	},
	"hongi": {
		"counter": 10,
		"description": "Returns 10 damage on melee hits"
	},
	"raja": {
		"dodge": 0.2,
		"description": "20% chance to avoid hits"
	},
	"robin": {
		"multishot": 2,
		"description": "Can shoot 2 arrows at once"
	},
	"rollo": {
		"cleave": 0.5,
		"description": "Cleaves enemies by  50% damage"
	},
	"sida": {
		"pierce": 0.4,
		"description": "40% spear piercing chance "
	},
	"takoda": {
		"bleed": 4,
		"description": "Extra 4 stack damage"
	},
	"tomyris": {
		"agile": 0.05,
		"description": "Extra 5% stack attack speed"
	}
}



func _ready():
	game = get_tree().get_current_scene()



func hit(attacker, target, projectile, counter):
	var modifiers = {
		"damage": attacker.current_damage,
		"dodge": false
	}
	if target.display_name in game.unit.skills.leader:
		var target_skills = game.unit.skills.leader[target.display_name]
		
		if "dodge" in target_skills:
			modifiers.dodge = (randf() <  target_skills.dodge)
			
		if "defense" in target_skills:
			modifiers.damage -= target_skills.defense
		
		if not counter:
			if "counter" in target_skills and not attacker.ranged:
				game.unit.attack.take_hit(target, attacker, false, target_skills.counter)
			
	if attacker.display_name in game.unit.skills.leader:
		var attacker_skills = game.unit.skills.leader[attacker.display_name]
		if not counter:
			
			if "stun" in attacker_skills:
				if randf() < attacker_skills.stun: target.stun_start()
			
			if "critical" in attacker_skills:
				if randf() <  attacker_skills.critical:
					modifiers.damage *= 2
			
			if "bleed" in attacker_skills:
				if attacker.last_target == attacker.target:
					modifiers.damage += attacker_skills.bleed * attacker.attack_count
			
			if "agile" in attacker_skills:
				if attacker.last_target == attacker.target:
					attacker.current_attack_speed += attacker_skills.agile * attacker.attack_count
	
	
	return modifiers
