@tool
extends TileMap

@export var map_size := Vector2.ZERO

var _cell_snapshot: Dictionary = {}
var _sync_queued := false
var _is_syncing := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	if not changed.is_connected(_queue_mirror_sync):
		changed.connect(_queue_mirror_sync)
	_cell_snapshot = _get_cell_snapshot()


func _queue_mirror_sync() -> void:
	if _is_syncing or _sync_queued:
		return
	_sync_queued = true
	call_deferred("_sync_mirrored_cells")


func _sync_mirrored_cells() -> void:
	_sync_queued = false
	var current_snapshot = _get_cell_snapshot()
	var changed_cells = _get_changed_cells(current_snapshot)
	if changed_cells.is_empty():
		return

	_is_syncing = true
	for cell_key in changed_cells:
		var cell = changed_cells[cell_key]
		var mirrored_coords = _get_mirrored_coords(cell.coords)
		if cell.present:
			set_cell(cell.layer, mirrored_coords, cell.source_id, cell.atlas_coords, cell.alternative_tile)
		else:
			erase_cell(cell.layer, mirrored_coords)
	_is_syncing = false
	_cell_snapshot = _get_cell_snapshot()


func _get_cell_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for layer in get_layers_count():
		for coords in get_used_cells(layer):
			var cell_key = _cell_key(layer, coords)
			snapshot[cell_key] = {
				"layer": layer,
				"coords": coords,
				"present": true,
				"source_id": get_cell_source_id(layer, coords),
				"atlas_coords": get_cell_atlas_coords(layer, coords),
				"alternative_tile": get_cell_alternative_tile(layer, coords),
			}
	return snapshot


func _get_changed_cells(current_snapshot: Dictionary) -> Dictionary:
	var changed_cells: Dictionary = {}
	for cell_key in current_snapshot:
		if not _cell_snapshot.has(cell_key) or _cell_snapshot[cell_key] != current_snapshot[cell_key]:
			changed_cells[cell_key] = current_snapshot[cell_key]
	for cell_key in _cell_snapshot:
		if not current_snapshot.has(cell_key):
			changed_cells[cell_key] = {
				"layer": _cell_snapshot[cell_key].layer,
				"coords": _cell_snapshot[cell_key].coords,
				"present": false,
			}
	return changed_cells


func _cell_key(layer: int, coords: Vector2i) -> String:
	return "%d:%d:%d" % [layer, coords.x, coords.y]


func _get_mirrored_coords(coords: Vector2i) -> Vector2i:
	var cell_pos = map_to_local(coords)
	if tile_set == null:
		return coords
	var tile_size = Vector2(tile_set.tile_size)
	var mirror_size = map_size
	if mirror_size == Vector2.ZERO:
		var map = get_parent().get_parent()
		var configured_size = map.get("size")
		if configured_size is Vector2:
			mirror_size = configured_size
	return local_to_map(Vector2(
		(mirror_size.x - cell_pos.x) - tile_size.x,
		(mirror_size.y - cell_pos.y) - tile_size.y
	))


func set_mirrored_cell(layer: int, coords: Vector2i, source_id: int = -1, atlas_coords: Vector2i = Vector2i(-1, -1), alternative_tile: int = 0) -> void:
	super.set_cell(layer, coords, source_id, atlas_coords, alternative_tile)
	super.set_cell(layer, _get_mirrored_coords(coords), source_id, atlas_coords, alternative_tile)
