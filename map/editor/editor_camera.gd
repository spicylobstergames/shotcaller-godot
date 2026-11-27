extends Camera2D

# =============================================================================
# Editor camera (map/editor/editor_camera.gd)
# =============================================================================
# The editor's own Camera2D. The gameplay camera (controls/crafty_camera.gd,
# autoload 'Crafty') is NOT used here: its process()/input() only do work while
# WorldState's game_started is set and its limits/zoom belong to the playing
# map, and the editor has no game running. This camera is a child of the editor
# root (not of the map) so it stays out of the saved scene and its internal
# _process keeps running.
#
# The host feeds raw InputEvents into handle_input() from _unhandled_input, so
# the UI gets first refusal on every click and this camera only sees what the
# UI did not consume. Middle-drag pans, the wheel zooms; the map tools use
# left/right.
# =============================================================================

const MIN_ZOOM := 0.25
const MAX_ZOOM := 4.0
const ZOOM_STEP := 1.15

var _panning := false


func _ready() -> void:
	make_current()


# Center on the map and fit all of it in the window (clamped so a tiny map does
# not zoom into infinity).
func frame_map(map_size: Vector2, viewport_size: Vector2) -> void:
	position = map_size / 2.0
	var fit := minf(viewport_size.x / maxf(map_size.x, 1.0), viewport_size.y / maxf(map_size.y, 1.0))
	var level := clampf(fit, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(level, level)


# True when the event was camera business and the host must mark it handled.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
				return true
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_set_zoom(zoom.x * ZOOM_STEP)
					return true
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_set_zoom(zoom.x / ZOOM_STEP)
					return true
	elif event is InputEventMouseMotion:
		if not _panning:
			return false
		if not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
			# The middle button was let go (possibly over the UI or outside the
			# window): stop rather than dragging on every later mouse move.
			_panning = false
			return false
		# Screen deltas are zoom-scaled: one screen pixel is 1/zoom world units.
		position -= event.relative / zoom
		return true
	return false


func _set_zoom(level: float) -> void:
	var clamped := clampf(level, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(clamped, clamped)
