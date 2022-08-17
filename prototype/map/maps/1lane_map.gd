extends YSort
var game:Node

# self = game.map

onready var blocks = get_node("blocks")
onready var walls = get_node("tiles/walls")
onready var trees = get_node("tiles/trees")
onready var fog = get_node("fog")

onready var red_castle = get_node("buildings/red/castle")
onready var blue_castle = get_node("buildings/blue/castle")

var size:int = 1056
var mid = Vector2(size/2, size/2)

const tile_size = 64
const half_tile_size = tile_size / 2

const neutrals = ["blacksmith"]

var lanes:Array = ["mid"]
var lanes_paths = {}

var fog_of_war:bool = true

var zoom_limit:Vector2 = Vector2(0.5,1.76)
