# goap/

The AI brain: Goal-Oriented Action Planning.

- `goap_system/agent.gd` — per-unit controller (goal selection, plan
  following, signals). One Agent node per unit, wired in `Unit.gd`.
- `goap_system/planner.gd` — builds the cheapest valid action chain for a
  goal's desired state (recursive precondition matching, depth-capped).
- `goap_system/goap.gd` — the autoload: the planner, both registries, and the
  per-tick agent pump (no move/navigation members; use
  `Goap.get_action("Move"/"Navigate")` and the `Navigation` autoload).
- `game_logic/actions/` — 18 actions; each extends
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

Where docs disagree, `../ARCHITECTURE.md` is the source of truth.

## Troubleshooting (symptom -> first check -> likely cause)

Run diagnostics before changing code. Most "the AI is broken" reports are one
of the five rows below.

| Symptom | First check | Likely causes (most common first) |
|---------|-------------|-----------------------------------|
| Unit stands still, `goal=NONE` | `godot --path . -- --freeze-report` (samples every ~2s, read-only) | A stranded fact is gating every goal: `is_retreating`, `ready_to_fight=false`, a truthy `unit.target` (dead/out-of-sight target never released), or write-once `lane_route_finished`. |
| Unit holds a goal but has an EMPTY plan | Set `Goap.debug_planning = true` (debugger or test); the pump logs a `Planner.explain()` warning with `reason`/`unsatisfied`/`produced_by` | A stale success fact (planner thinks the desired state is already true — this is why `EnemyDefeated`/`FriendsSafe`/`NeedSafety`/`Recover` reset facts in `is_valid()`), or a desired fact no action produces. |
| Plan exists but the unit does not act | Check `perform()` returns true and that something drives the step | `Move`'s step is driven by `Collisions` for `state == "move"` units; `perform()` returning true is what advances the plan; the agent replans ONLY when the goal changes (no mid-plan revalidation). |
| Planner picks a nonsensical plan | Compare the action's banner precond/effects with its runtime behavior | The planner has NO contradiction check — preconditions are merged by assignment, so keep them consistent with the goal and ancestors by hand. |
| A fact never becomes true / planner lists it as `unsatisfied` forever | Run the suite; `tests/unit/test_state_keys.gd` fails NAMING the unknown key | A misspelled state key (the suite greps every `set_state`/`get_state`/`erase_state` literal against `docs/ai/world-state.md`). Also remember `null != false`: an unset key does NOT satisfy a `false` precondition; typed `-> bool` reads must pass a default. |
| New action is never planned | Run the suite; `tests/unit/test_goap_contract_lint.gd` and `test_planner_real_actions.gd` fail with the reason | Empty `get_effects()` (that makes it a service object), `is_valid()` returning false, or the registry count assertion needs updating. |

Also useful: `Goap.get_action_planner().explain(agent, goal)` returns a dict
(`desired`, `already`, `unsatisfied`, `produced_by`, `plan`, `reason`) —
callable from any test or debugger. The FREEZE_REPORT and explain paths are
read-only and off by default, so they cannot alter the golden replay.

## Verify your change

```
./tests/run_suite.sh /path/to/godot        # everything, ~45s
# or, unit suite only:
godot --headless --path . res://tests/test_runner.tscn
```

Green means ALL of: `passed=364 failed=0` (bump `EXPECTED_UNIT_TESTS` in
`tests/run_suite.sh` when you add tests), boot smoke OK, golden replay
unchanged, and ZERO `SCRIPT ERROR` lines (a script error silently swallows
assertions — a "passing" suite with script errors is lying). A new test file
must be registered in `tests/run_tests.gd` twice: a preload/load entry AND a
`_run_suite(...)` call. If the golden replay fails on an INTENDED behavior
change, re-record with `--golden-update` and say why in the commit
(DECISIONS.md D12).
