extends PanelContainer

func prepare(ability_icon, ability_name, ability_description):
	$"%ability_icon".texture = ability_icon
	$"%ability_name".text = ability_name
	$"%ability_description".text = ability_description
