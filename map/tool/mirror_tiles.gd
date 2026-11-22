@tool
extends TileMapLayer

# =============================================================================
# Mirror tiles (map/tool/mirror_tiles.gd) — PORTED to TileMapLayer
# =============================================================================
# Attach to one of a map's contract TileMapLayers (tiles/ground/Ground,
# tiles/walls/Walls, tiles/trees/Trees): every edit made through Godot's
# built-in tile editors is mirrored 180° around the map center on THIS layer,
# so symmetric maps paint half and get the whole.
#
# Ported from the old TileMap (multi-layer, Godot-3-style API) subclass: the
# runtime contract layers are TileMapLayer nodes (map_validator.gd), and the
# mirror math now lives in the shared, unit-tested
# addons/map_editor/tile_brush_logic.gd (mirrored_cell) so the plugin's
# painting brush and this auto-mirror use the exact same formula.
#
# map_size is the mirror area in pixels; when ZERO it falls back to the
# owning BaseMap's size.
# =============================================================================

const TileBrushLogic := preload("res://addons/map_editor/tile_brush_logic.gd")

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
		var mirrored_coords = _mirrored_coords(cell.coords)
		if cell.present:
			set_cell(mirrored_coords, cell.source_id, cell.atlas_coords, cell.alternative_tile)
		else:
			erase_cell(mirrored_coords)
	_is_syncing = false
	_cell_snapshot = _get_cell_snapshot()


func _get_cell_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for coords in get_used_cells():
		snapshot[_cell_key(coords)] = {
			"coords": coords,
			"present": true,
			"source_id": get_cell_source_id(coords),
			"atlas_coords": get_cell_atlas_coords(coords),
			"alternative_tile": get_cell_alternative_tile(coords),
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
				"coords": _cell_snapshot[cell_key].coords,
				"present": false,
			}
	return changed_cells


func _cell_key(coords: Vector2i) -> String:
	return "%d:%d" % [coords.x, coords.y]


func _mirrored_coords(coords: Vector2i) -> Vector2i:
	return TileBrushLogic.mirrored_cell(coords, TileBrushLogic.cell_size_of(self), _mirror_size_px())


func _mirror_size_px() -> Vector2:
	return TileBrushLogic.mirror_size_for(self)


# Paint a cell and its mirrored twin in one call.
func set_mirrored_cell(coords: Vector2i, source_id: int = -1, atlas_coords: Vector2i = Vector2i(-1, -1), alternative_tile: int = 0) -> void:
	set_cell(coords, source_id, atlas_coords, alternative_tile)
	var mirrored := _mirrored_coords(coords)
	if mirrored != coords:
		set_cell(mirrored, source_id, atlas_coords, alternative_tile)
