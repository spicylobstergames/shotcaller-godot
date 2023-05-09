@tool

extends MultiMeshInstance2D

@export var do_distribution := false : set = _set_do_distribution

@export var in_a_rows: int = 1
@export var row_distance: int = 10
@export var col_distance: int = 10

@export var random_range: int = 0
@export var random_range_y: int = 0

@export var center_light: Vector2 = Vector2.ZERO
@export var focal_size: Vector2 = Vector2.ONE

@export var noise_strength = 0.5  # (float,0,1)
@export var focus = 1.0 # (float,0,1,1e-9)

@export var colors: Array = [
	Color(0.086275, 0.352941, 0.298039, 1.0),
	Color(0.137255, 0.564706, 0.388235, 1.0),
	Color(0.117647, 0.737255, 0.450980, 1.0),
	Color(0.568627, 0.858824, 0.411765, 1.0),
	Color(0.803922, 0.874510, 0.423529, 1.0)
]

var open_simplex_noise = FastNoiseLite.new()

func _ready():
	var noise_seed = randi()
	open_simplex_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	open_simplex_noise.fractal_octaves = 4
	open_simplex_noise.domain_warp_frequency  = 7
	open_simplex_noise.fractal_gain = 0.5
	open_simplex_noise.fractal_lacunarity = 2
	open_simplex_noise.seed = noise_seed
	
	_update_distribution()

func _update_distribution():
	var multi_mesh = self.multimesh
	multi_mesh.mesh = $silouet.mesh
	
	var rows = ceil(multi_mesh.instance_count/in_a_rows)
	var current_row = 0
	
	while current_row < rows:
		var vectors = []
		
		for i in in_a_rows:
			var x = (i%in_a_rows)*col_distance
			vectors.append(Vector2(
				int(
					x + randf_range(-random_range,random_range)
				), 
				int(current_row * row_distance + open_simplex_noise.get_noise_1d(x) * random_range_y)
			))
		
		vectors.sort_custom(sort_y)
		
		for index in vectors.size():
			var v = vectors[index]
			var i = current_row * in_a_rows + index
			
			var t = Transform2D(0.0, v)
			multi_mesh.set_instance_transform_2d(i, t)
			
			var dis2center = ellipse_distance(center_light - position, v,focal_size)*0.1
			
			var color_index = (1 / (focus*pow(dis2center, 2) + 1) * (1-noise_strength)) * (colors.size())
			color_index += map_range(open_simplex_noise.get_noise_2d(v.x ,v.y), -1,1, 0, colors.size()) * noise_strength * (1- 1 / (focus*pow(dis2center, 2) + 1))
			
			var instance_color =  lerp_color(
				colors[min(colors.size() - 1, floor(color_index))],
				colors[min(colors.size() - 1, ceil(color_index))],
				clamp((color_index - floor(color_index))/(ceil(color_index) - floor(color_index)),0,1)
			)
			
			multi_mesh.set_instance_color(i, instance_color)
			
		current_row += 1;

func lerp_color(c1:Color, c2:Color, t:float):
	return Color(clamp(lerp(c1.r,c2.r,t), 0, 1), clamp(lerp(c1.g,c2.g,t), 0, 1), clamp(lerp(c1.b,c2.b,t), 0, 1))

func ellipse_distance(p1:Vector2, p2:Vector2, f:Vector2):
	return sqrt(pow((p1.x-p2.x)/f.x, 2) + pow((p1.y-p2.y)/f.y, 2))

func map_range(t, min1, max1, min2, max2):
	return lerp(min2, max2, inverse_lerp(min1, max1, t))

func sort_y(a,b):
	return a.y < b.y

func _set_do_distribution(value):
	if value:
		_update_distribution()
