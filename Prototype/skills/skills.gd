extends Node
var game:Node


const leader = {
	"arthur": "stun",
	"bokuden": "critical",
	"lorne": "defense",
	"hongi": "counter",
	"raja": "dodge",
	"robin": "multishot",
	"rollo": "cleave",
	"sida": "agile",
	"takoda": "precision",
	"tomyris": "pierce"
}



func _ready():
	game = get_tree().get_current_scene()


