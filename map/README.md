# map/

Tile-map battlefields and everything that populates them.

- `maps/` — the playable map scenes (`three_lane_map.tscn` is the battle
  map). A map scene must expose `size`, `camera_limit`, `zoom_limit`,
  `lanes`, and `buildings/<team>/<building>` nodes — `map_manager.gd` and
  `spawns.gd` read them by path.
- `map_manager.gd` — instantiates maps, creates the unit/projectile/block
  containers, sets up buildings and lanes. Map-ready flows THROUGH the
  minimap UI (`ui/minimap.gd`) — headless runs rely on the
  `DisplayServer.get_name() == "headless"` guard there; do not remove it.
- `spawns.gd` — spawn timers, cemetery recycling, camp/lumberjack hiring.
  `camp_hire` pools team gold and refuses the hire when insufficient;
  `lumberjack_hire` splits the cost the same way but has NO affordability
  check (can drive leaders negative — do not assume a gate exists).
  Regression-tested in `tests/unit/test_spawns.gd`.
- `pathfind/` — jump-point pathfinding (the `Finder` autoload).
- `tool/mirror_tiles.gd` — @tool map-editor TileMap (mirror painting).
  Its coordinate math is regression-tested against production methods in
  `tests/unit/test_mirror_tiles.gd`.
- `../addons/map_editor/` — editor plugin (enable it in Project Settings →
  Plugins): a dock with **New map scene** (scaffolds a contract-satisfying
  map — tiles/ground|walls|trees TileMapLayers with the shared TileSets,
  fog, `buildings/<team>/<building>`, a default `mid` lane, `closest_tree`
  markers), **Validate open map** (checks the runtime contract that
  `map_manager.gd`/`spawns.gd` read by path, including building `subtype`
  matching a lane), and **Draw lanes** (canvas mode: left-click adds
  tile-snapped points to the selected lane, Escape exits, "New lane" adds a
  `lane_N` line — all undoable). Scaffold, validator, and lane logic are
  editor-free RefCounted code, regression-tested in
  `tests/unit/test_map_editor.gd` / `test_lane_logic.gd` /
  `test_map_loader.gd`.
- `map_manager.gd` resolves maps generically: preloaded shipping maps by
  var, anything else by `map/maps/<name>.tscn` — so maps authored with the
  plugin load by name (`current_map = "my_map"`), though end-to-end boot of
  a new map is not yet covered by automated tests.
