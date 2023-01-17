tool

extends MultiMeshInstance2D

export var do_distribution := false setget _set_do_distribution

export(int) var in_a_rows = 1
export(int) var row_distance = 10

export(int) var random_range = 0
export(int) var random_range_y = 0

export(Vector2) var center_light = Vector2.ZERO
export(Vector2) var focal_size = Vector2.ONE

export(float,0,1) var noise_strength = 0.5 
export(float,0,1,1e-9) var focus = 1.0

export(Array) var colors = [
	Color(0.086275, 0.352941, 0.298039, 1.0),
	Color(0.137255, 0.564706, 0.388235, 1.0),
	Color(0.117647, 0.737255, 0.450980, 1.0),
	Color(0.568627, 0.858824, 0.411765, 1.0),
	Color(0.803922, 0.874510, 0.423529, 1.0)
]

var open_simplex_noise = OpenSimplexNoise.new()

func _ready():
	var noise_seed = randi()
	open_simplex_noise.seed = noise_seed
	open_simplex_noise.octaves = 4
	open_simplex_noise.period = 7
	open_simplex_noise.persistence = 0.5
	open_simplex_noise.lacunarity = 2
	
	_update_distribution()

func _update_distribution():
	var multi_mesh = self.multimesh
	multi_mesh.mesh = $silouet.mesh
	var screen_size = get_viewport_rect().size
	
	var rows = ceil(multi_mesh.instance_count/in_a_rows)
	var current_row = 0
	
	while current_row < rows:
		var vectors = []
		
		for i in in_a_rows:
			var x = (i%in_a_rows)*((screen_size.x + 50)/in_a_rows)
			vectors.append(Vector2(
				int(
					x + rand_range(-random_range,random_range)
				), 
				int(current_row * row_distance + open_simplex_noise.get_noise_1d(x) * random_range_y)
			))
		
		vectors.sort_custom(self, "sort_y")
		
		for index in vectors.size():
			var v = vectors[index]
			var i = current_row * in_a_rows + index
			
			var t = Transform2D(0.0, v)
			multi_mesh.set_instance_transform_2d(i, t)
			
			var dis2center = ellipse_distance(center_light - position, v,focal_size)*0.1
			
			var color_index = (1 / (focus*pow(dis2center, 2) + 1) * (1-noise_strength)) * (colors.size())
			color_index += map_range(open_simplex_noise.get_noise_2d(v.x ,v.y), -1,1, 0, colors.size()) * noise_strength * (1- 1 / (focus*pow(dis2center, 2) + 1))
			
			multi_mesh.set_instance_color(i, lerp_color(
											colors[min(colors.size() - 1, floor(color_index))],
											colors[min(colors.size() - 1, ceil(color_index))],
											clamp((color_index - floor(color_index))/(ceil(color_index) - floor(color_index)),0,1)));
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
