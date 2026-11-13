# unit/

Every fighting entity descends from `Unit.tscn` / `Unit.gd`.

- `Unit.gd` — movement (navigation + manual step), combat state, hp/regen,
  gold/exp, and the signal surface (`unit_arrived`, `unit_attack_hitted`,
  `unit_death_started`, ...). Those signal names are wiring contracts:
  `goap/goap_system/agent.gd` connects them in `_ready()`, and actions/UI
  emit or listen. Renaming one breaks the chain silently.
- Each unit has an `Agent` child (GOAP controller) — see `../goap/`.
- `leaders/` — playable leader scenes (arthur, joan, ...); their passive
  skills come from `../skills/resources/leader_passives.tres` keyed by
  display name.
- `pawns/`, `neutrals/`, `buildings/` — spawnable scenes; `../map/spawns.gd`
  instantiates them by name (cemetery recycling expects matching names).
