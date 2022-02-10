extends Sprite

func _ready():
	var blood_aim = lerp($BloodLowerBound.position, $BloodUpperBound.position, 0.5)
	
	$Particles2D.rotation = blood_aim.angle()
