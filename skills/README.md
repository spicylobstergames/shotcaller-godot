# skills/

Leader passives and the modifier system.

- `passive_skills.gd` (autoload `Skills`) — loads
  `resources/leader_passives.tres` into the `leader` dictionary (keyed by
  display name: "arthur", "raja", ...). Owns `hit_modifiers()` — the combat
  resolution pipeline (dodge/stun/critical/cleave/pierce/bleed/agile/
  counter). Fully regression-tested in `tests/unit/test_passive_skills.gd`.
  CAUTION: a unit in the leader table with an EMPTY skill dict makes
  `hit_modifiers` return null (pinned quirk) — keep .tres entries non-empty.
- `modifiers.gd` (autoload `Modifiers`) — per-unit modifier stacks and level
  scaling; `get_value(unit, mod)` is called from movement, combat, and regen.
  All unit reads go through `unit.get(property)` with null checks — keep
  them (test doubles and optional properties depend on it).
- `active/` + `active_skills.gd` — player-cast active abilities.
- `skill_resource.gd` — Resource schema for skill data.
