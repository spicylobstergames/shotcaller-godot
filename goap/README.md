# goap/

The AI brain: Goal-Oriented Action Planning.

- `goap_system/agent.gd` — per-unit controller (goal selection, plan
  following, signals). One Agent node per unit, wired in `Unit.gd`.
- `goap_system/planner.gd` — builds the cheapest valid action chain for a
  goal's desired state (recursive precondition matching, depth-capped).
- `goap_system/goap.gd` — the autoload: registries, planner, navigation.
- `game_logic/actions/` — 19 actions; each extends
  `goap_system/action_contract.gd`. Planning reads is_valid/get_cost/
  get_preconditions/get_effects; execution calls enter/perform/exit.
- `game_logic/goals/` — 8 goals; `get_desired_state()` must be satisfiable
  by the effects of registered actions (contract drift breaks planning —
  `tests/unit/test_planner_real_actions.gd` guards this).
- `game_logic/world_state.gd` — the WorldState autoload.

When adding an action: create the script, register it in
`action_registry.gd`, and confirm `test_planner_real_actions.gd` still
passes (the registry count is asserted there).

## Reading the code

Every core file, action, and goal starts with a `GOAP-GUIDE:` banner stating
its purpose, contract (`is_valid`/`cost`/preconditions/effects), lifecycle
(`enter`/`perform`/`exit`), the state facts it reads and writes, and its known
traps. List them all with:

```
grep -rl "GOAP-GUIDE" goap/
```

Companion docs: `../ARCHITECTURE.md` (verified system map),
`../docs/ai/architecture.md` (long-form GOAP narrative),
`../docs/ai/world-state.md` (state-fact catalog),
`../docs/ai/adding-behavior.md` (adding actions/goals), and
`../IMPROVEMENT_PLAN.md` (open work).
