extends YSort
var game:Node

# self = game.map

onready var blocks = get_node("blocks")
onready var walls = get_node("tiles/walls")
onready var fog = get_node("fog")

onready var red_castle = get_node("buildings/red/castle")
onready var blue_castle = get_node("buildings/blue/castle")

var size:int = 2112

const tile_size = 64
const half_tile_size = tile_size / 2

const neutrals = ["mine", "blacksmith", "lumbermill", "camp", "outpost"]

var lanes:Array = ["bot", "mid", "top"]
var lanes_paths = {}

var fog_of_war:bool = true
