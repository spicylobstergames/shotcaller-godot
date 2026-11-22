# GOAP Improvement Plan (handoff document)

**Audience:** an implementing agent (including smaller/faster models) that will
pick up one work item at a time and turn it into a reviewed change.

**Source of truth for the system as it exists today:** `ARCHITECTURE.md`
(rewritten and verified against commit `d527203`). Read it before starting any
item here. The `Known gaps` section of that file and the work items below are
the same numbered evidence; this file adds the *how*.

**Author's note (2026-11-14):** work items **A** (documentation truth pass) and
**B** (arrival dispatch + ReturnLumber fix) were implemented in the session
that authored this file. Result: `TESTS_COMPLETE: passed=313 failed=0`,
boot smoke OK, **golden replay unchanged** (the debug smoke scenario does not
exercise the previously-dead hooks), zero script errors. New regression file:
`tests/unit/test_arrival_dispatch.gd` (sabotage-verified). Their specs are
retained below because they encode the evidence and acceptance criteria.
Items **C–F** are unstarted.

---

## 0. Ground rules (do not skip)

These come from `AGENTS.md`, `tests/README.md`, `docs/ai/adding-behavior.md`,
and `DECISIONS.md`. They are not optional.

1. **One focused change per task.** "Small, verifiable tasks ... each task on
   its own branch with a clean diff." Do not fold unrelated refactors in.
2. **Zero `SCRIPT ERROR` lines is part of green.** A suite that "passes" with
   script errors is lying — script errors swallow assertions.
3. **`run_suite.sh` pins an exact assertion count** (`EXPECTED_UNIT_TESTS` at
   `tests/run_suite.sh:26`). Adding tests → bump the pin in that file.
4. **New test files must be registered in `tests/run_tests.gd`** *and* their
   `run()` called in the registry list. Both.
5. **The golden replay** (`tests/golden/replay_300.txt`) pins real-game state
   at frames 100/200/300. If it fails: fix the regression, or if the behavior
   change is intended, re-record with `--golden-update` and state the reason in
   the commit (DECISIONS D6/D12). Never diff new behavior against an old
   snapshot.
6. **Tests must fail when production breaks.** Break the guarded line once,
   watch the test fail, revert. Never assert what a mock does.
7. **Read 2–3 similar implementations before adding an action/goal.**
8. **Do not change the planner or agent lifecycle for an ordinary behavior.**
   Tracks C/E exist precisely because those changes need their own decision,
   tests, and golden re-record.

## 1. Environment and verification

Godot binary (repo-local, gitignored): `.tools/godot/Godot_v4.7.2-stable_linux.x86_64`

Full suite (this is the only definition of done):

```bash
TEST_LOG_DIR="$PWD/.test-logs" \
  ./tests/run_suite.sh "$PWD/.tools/godot/Godot_v4.7.2-stable_linux.x86_64"
```

- `TEST_LOG_DIR` **must** be set in the agent sandbox: the script's default
  `$PROJECT_DIR/../.test-logs` resolves outside the workspace and is read-only
  there, which makes every step fail on `> "$LOG_DIR/...log"`.
- Baseline at the time of writing: `TESTS_COMPLETE: passed=306 failed=0`,
  `SMOKE_OK`, `GOLDEN_OK`, zero script errors.

Faster inner loop:

```bash
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/test_runner.tscn
```

Useful facts verified on this tree:

- Physics runs at **60 Hz**. `project.godot`'s `common/physics_fps=30` is the
  Godot 3 key name and is ignored; Godot 4 reads
  `physics/common/physics_ticks_per_second`. `Goap.physics_process` throttles
  each unit with `frames_til_next_process` (`6` = every 7th tick), so each unit
  plans at ~8.6 Hz.
- `tests/perf_monitor.gd` exists; `-- --perf` on `game.tscn` measures tick rate
  (used by DECISIONS D13, deliberately not part of gating).

## 2. Status board

| ID | Item | Status | Risk | Size |
|----|------|--------|------|------|
| A | Documentation truth pass | done 2026-11-14 | none | S |
| B | Arrival dispatch + ReturnLumber | done 2026-11-14 (313 tests; golden unchanged) | medium | M |
| C | Planner contradiction handling | **dropped 2026-11-21 (owner decision)** | — | — |
| D | State-fact hygiene | open | low-medium | M |
| E | Perf / cleanup | open — measure first | medium | M |
| F | Test hardening | open | low | S |

Suggested order for the remaining work: **F → D → C → E**. Rationale: F is
cheap and makes D/C safer; D removes the string-key traps that make C harder to
trust; C is a behavior change that should ride on D's hygiene; E needs
measurement and should not be bundled.

**Tooling landed alongside this plan (2026-11-14):** state-key lint and
contract lint (plus a GOAP-GUIDE banner test) in `test_state_keys.gd` /
`test_goap_contract_lint.gd`; a fast GOAP gate (`tests/run_goap_lint.sh`) with
a `--only=` filter in `run_tests.gd`; a generated `docs/ai/goap-index.md`
(`tools/gen_goap_index.sh`, freshness-tested); `docs/ai/goap-cheatsheet.md`;
`Planner.explain()` plus `Goap.debug_planning` empty-plan logging; field-level
golden diffs and `tests/record_golden.sh`; action/goal templates and
`tools/new_goap_{action,goal}.sh`; and `plans/` machine-readable work items.
**This completes Track D5.** Remaining items in `plans/` carry machine-readable
acceptance criteria.

---

## Track A — Documentation truth pass (DONE)

**Why:** every AI-facing doc currently describes code that no longer exists.
The next implementing agent will follow the false claims. `ARCHITECTURE.md` is
now correct; the rest must point at it.

### A1 — `AGENTS.md`

Remove/correct these verified-false claims:

- "30 Hz" everywhere (goals `is_valid` cadence). Real: physics 60 Hz, per-unit
  goal evaluation every 7th tick (~8.6 Hz). See `goap/goap_system/goap.gd:34-41`.
- "`MoveAction` precondition requires `has_path: false` ... goal `is_valid()`
  methods (specifically `WalkLane` and `ArriveAtDestination`) write `has_path`
  every frame." Real: `Move.get_preconditions()` is
  `{has_destiny: true, is_stunned: false}` (`move_action.gd:20-24`); neither
  goal's `is_valid` writes `has_path` (`arrive_at_destination.gd:8-9` is a
  hard `return false`).
- "`ChooseTarget` ... always returns `false` from `is_valid()`. It is **not**
  planned as an action." Real: `unit.attacks and !unit.target`
  (`choose_target.gd:8-10`); it **is** planned as target acquisition.
  Its "team priority dictionaries" no longer exist (the priority system was
  removed; see DECISIONS D12).
- "`goal_contract.gd` line 16 references `goals/keep_fed.gd`" — no such
  reference exists.
- "`move_action.smart` checks `get_state("stunned")` (line 165)" — there is no
  `smart` function in `move_action.gd` (file ends at line 164); the only
  `"stunned"` alias reads are defensive checks in `order_action.gd:102,138`.
- Keep the "process pump" and `has_path`/null notes, but rewrite the
  `has_path` one around `has_destiny` and the real arrival path (see B).
- Add pointers: `ARCHITECTURE.md` (system map) and
  `docs/ai/world-state.md` (fact catalog).

### A2 — `docs/ai/architecture.md`

This file duplicated GOAP architecture and had drifted badly (269 lines of
stale claims). **Outcome: kept as the full long-form GOAP walkthrough and
corrected in place** (not reduced to a pointer — the owner prefers improving
existing docs over replacing them). It is now cross-linked: `ARCHITECTURE.md`
is the canonical cross-system map, this file is the detailed GOAP narrative.
Corrections applied:

- replaced the "Contradiction checking" subsection with "Precondition
  merging — there is no contradiction check" (see C);
- removed the "30 Hz" claims (real: 60 Hz physics, ~8.6 Hz per unit);
- fixed the signal table to the real `_ready()` connections
  (`agent.gd:35-50`); `unit_move_ended`, `unit_stuned`,
  `unit_started_channeling`, `unit_healed`, `unit_leveled_up` are not
  connected; the signal is `unit_animation_ended`, not `unit_animation_end`;
- documented that `unit_arrived` is emitted by `Collisions` and wired exactly
  once (replacing the old "connected twice" known issue);
- removed `Goap.move` / `Goap.navigation` (do not exist; use
  `Goap.get_action(...)` and the `Navigation` autoload);
- noted that `ArriveAtDestination.is_valid()` hard-returns `false` and
  arrival is collision-driven;
- pointed "Planned improvements" at this file's tracks C/D/E/F instead of
  duplicating stale text.

### A3 — `docs/ai/world-state.md`

- The `has_path` entry: no precondition consumes `has_path`; `Move` consumes
  `has_destiny`.
- The `target` entry: claims agent scope; it lives on `unit.target` and
  `agent.set_state("target", …)` is intercepted (`agent.gd:74-78`).
- The `stunned` alias entry: only defensive reads in `order_action.gd`.
- Add missing keys or mark them dead: `opponents_in_sight` (written per frame
  by `enemy_defeated.gd:38`, never read), `after_arive` (typo; written by
  `order_action.gd` + `conquer_action.gd` + `prayer_action.gd`, read at
  `order_action.gd:90`), `resume_path`/`lane_resume_path` (writers/erasers
  only; readers commented out), `move`/`attack`/`idle`/`death` on unit state.
- The `ArriveAtDestination.is_valid()` producer claim ("line 11", "line 16") is
  wrong — that code is dead behind the hard return.
- Remove the duplicate `arrived_at_retreat` listing.
- Verify every line-number reference against the current file, or drop line
  numbers.

### A4 — `tests/COVERAGE.md`

- Header says "20 test classes, 255 assertions". Real: 23 registered classes
  (`tests/run_tests.gd:43-65`) and 306 assertions.
- Add the Track B/B5 regression tests to the test-class table once landed.

### A5 — `tests/run_tests.gd` header

The comment says the GOAP-coupled suites are "DEFERRED"; all 23 are registered
and run. Replace with a one-line note that the full suite is active (DECISIONS
D12) and bump the count note if the registry changes.

**Acceptance for Track A:** a fail-fast reading of any AI doc no longer sends
the reader to nonexistent files/keys; `run_suite.sh` output is unchanged (docs
do not affect it).

---

## Track B — Restore arrival dispatch + fix ReturnLumber (DONE, then SUPERSEDED)

> **Superseded (2026-11-21, DECISIONS D15):** the signal-based dispatch this
> track introduced (`unit_arrived` → `Agent.on_arrive` → per-action
> `on_arrive` hooks) was itself replaced after PR #239 review — arrival is
> now a GOAP state transition (`Collisions` →
> `ArriveAtDestination.advance_path` latches the facts; actions gate their
> effects in `perform()`). B1/B2 describe the replaced wiring; B3/B4
> (Recover delegation removal, ReturnLumber.enter navigation) still stand.
> The spec below is retained for the evidence and history.

**Why (evidence):**

- `Unit.on_arrive()` (`unit/Unit.gd:369`) emits `unit_arrived`, but **nothing
  connects `unit_arrived` and nothing calls `Unit.on_arrive()`**. The only
  arrival path in production is `Collisions.physics_process` calling
  `ArriveAtDestination.is_at_destination()` / `.on_arrive(unit)`
  (`collision/collisions.gd:73-80`).
- `Agent.on_arrive()` (`agent.gd:294`) and therefore every action's
  `on_arrive()` hook is unreachable. Dead in production: `GetLumber.on_arrive`
  (sets `has_wood`), `ReturnLumber.on_arrive`, `Hide.on_arrive` (sets
  `is_hiding`/`hiding_counter`), `RetreatAction.on_arrive` (sets
  `arrived_at_retreat`), `OrderAction.on_arrive` (conquer/pray).
- `ReturnLumber.enter` (`return_lumber.gd:25`) is
  `unit.current_destination = agent.set_state("deliver_position")` —
  `set_state` returns `null`, `Unit` has no `current_destination`, and the
  action never starts movement. It cannot deliver wood.

### B1 — `collision/collisions.gd`

After the existing `Goap.get_goal("ArriveAtDestination").on_arrive(unit1)`
call, emit the unit's arrival signal:

```gdscript
if Goap.get_goal("ArriveAtDestination").is_at_destination(unit1):
    Goap.get_goal("ArriveAtDestination").on_arrive(unit1)
    unit1.on_arrive()   # emits unit_arrived -> Agent.on_arrive
else:
    Goap.get_action("Move").step(unit1, delta)
```

Order matters: advance the path *first* so `WalkLane.on_arrive`'s
`current_path.is_empty()` check sees the post-advance state; then emit.

### B2 — `goap/goap_system/agent.gd`

In `_ready()`, add exactly **one** connection:

```gdscript
_unit.unit_arrived.connect(on_arrive)
```

Do **not** also connect the action directly — the historical double-connect
(`on_arrive` + `OrderAction.on_arrive`) is the bug described in the old docs.

### B3 — `goap/game_logic/goals/recover.gd`

`Recover.on_arrive(agent)` delegates `ArriveAtDestination.on_arrive(agent)` —
passing the **agent** where the function expects a **unit**
(`arrive_at_destination.gd:40-47` reads `unit.current_path`). With B1/B2
enabled this would fire and either error or double-advance the path. Recover's
plan is `[Retreat, WaitForRegeneration]`; the fact it needs
(`arrived_at_retreat`) is produced by `RetreatAction.on_arrive`. **Delete the
Recover delegation** (or make it a no-op) and let `RetreatAction.on_arrive`
do its job.

### B4 — `goap/game_logic/actions/return_lumber.gd`

Replace the broken `enter` body with a real move to `deliver_position`, using
the established movement API and its failure fallback:

```gdscript
func enter(agent):
    var unit = agent.get_unit()
    var deliver_position = agent.get_state("deliver_position")
    if deliver_position == null:
        return
    if not Goap.get_action("Navigate").move(unit, deliver_position):
        Goap.get_action("Move").move(unit, deliver_position)
```

Keep `on_arrive` as the completion point (it sets `returning_wood`, clears
`has_wood`, heals buildings). `has_wood` is the precondition, so this runs
after `GetLumber`.

### B5 — Regression tests

Required (per AGENTS.md "New action or goal ... at least one test"):

1. **Arrival dispatch reaches the current action.** Extend
   `tests/unit/test_agent_signals.gd` (already registered) with a stub unit that
   declares the same signals as `Unit` (see the existing stub in
   `test_action_lifecycles.gd`/`test_agent_signals.gd` for the pattern), set a
   plan containing a mock action with an `on_arrive(agent)` hook, emit
   `unit_arrived`, and assert the hook ran exactly once and that the current
   goal's `on_arrive` also ran. This must fail if B2 is reverted.
2. **`ReturnLumber.enter` starts movement.** A focused test that stubs the
   unit's `current_destiny`/`final_destiny` and `deliver_position`, calls the
   real action's `enter`, and asserts the unit is now travelling toward
   `deliver_position` (via the `Navigate`/`Move` fallback). If stubbing the
   autoload path is too heavy, assert the failure mode directly: the old line
   leaves `current_destiny == Vector2.ZERO`, the new one does not.
3. Bump `EXPECTED_UNIT_TESTS` in `tests/run_suite.sh` by the number added.

**Landed as:** `tests/unit/test_arrival_dispatch.gd` (registered in
`tests/run_tests.gd`), 7 assertions, `EXPECTED_UNIT_TESTS` 306 → 313. Both
production lines were sabotage-tested (reverting `unit_arrived.connect` fails
4 assertions; restoring the old `ReturnLumber.enter` fails 3 plus a script
error).

### B6 — Golden replay

Enabling the previously-dead `on_arrive` hooks changes real-game behavior
(lumberjacks can finally collect wood; retreats/hides complete). **Observed
outcome: the golden replay did not change** — the debug smoke scenario spawns
only a leader and a pawn and never reaches the lumberjack/hide/retreat hooks,
so frames 100/200/300 are identical. If a future scenario does exercise them,
expect the golden replay to fail; if the only diffs are the intended hook
effects, re-record with `--golden-update` and put the reason in the commit
message. Keep the D14 `±1 hp` tolerance as-is; do not widen it.

**Pitfalls:** do not wire `unit_arrived` twice; do not let `Recover` reach
`ArriveAtDestination.on_arrive`; `GetLumber.on_arrive` is an `await`
coroutine (`unit.channeling_timer.timeout`) — the agent dispatch calls it
without awaiting, which is the intended fire-and-forget pattern, but a test
must not assume `has_wood` is set synchronously (the timer must elapse or the
test must call `on_arrive` and then await/advance).

---

## Track C — Planner contradiction handling (DROPPED 2026-11-21)

> **Owner decision (PR #239 feedback):** none of the proposed options were
> taken. "There's no need to change the goap system" — the planner stays as
> it is (no contradiction rejection, no new "trap" actions). The sequencing
> problems the tracks were meant to address are handled instead by (a) the
> arrival state-transition rework (DECISIONS D15), (b) the deterministic
> `Navigate > Move` ordering from clearing `has_destiny` on stop/final
> arrival, and (c) the per-agent execution history for verifying expected
> sequences. The evidence below is retained; do not implement C1 without a
> new explicit owner request.

**Evidence:** `planner._build_plans` merges an action's preconditions into the
branch's desired state by dictionary assignment (`planner.gd:110-112`). No
conflict detection exists (`git log -S"contradict"` on the planner is empty).
Verified: goal `{b: true, x: true}`, actions `MakeX ({b: false} → {x: true})`
and `MakeNotB ({} → {b: false})` produce the plan `["MakeNotB", "MakeX"]`,
which falsifies `b`. `AGENTS.md` and `docs/ai/architecture.md` claim such
branches are rejected.

**Decision required (owner: project owner).** Two options:

**Prior art:** branch `planner-precondition-safety` (commits `27c0f21`
"Document current planner behavior on contradictory preconditions" and
`77b5d67` "Reject planner branches whose preconditions contradict the goal")
already implements the rejection — but against the pre-rename tree
(`prototype/goap/goap_system/planner.gd`), so it does not apply to `goap/`
directly. Its approach: carry a `satisfied` dictionary of facts the branch
already requires *and that currently hold* (at the node or an ancestor), and
reject any action whose precondition negates one of them or an outstanding
requirement in the branch. Port that into `goap/goap_system/planner.gd` and
re-point its `test_planner.gd` additions. Its author's note is the key
insight for the decision: at the time, precondition keys and goal-fact keys
did not overlap in the real registry, so the rejection only removed branches
that could never satisfy their goal (expected behavior-neutral for shipped
actions). Re-verify that against the current registry before assuming it.

- **C-option-1 — implement rejection.** Reject a branch when a new precondition
  conflicts with (a) a fact still required by the same branch, or (b) a fact an
  ancestor required to remain satisfied. This is what the docs promise;
  it changes planning outcomes for any contract with conflicting preconditions.
- **C-option-2 — document the limitation.** Cheaper, no behavior change; but
  plans can still falsify their own goal, so every action author must keep
  preconditions consistent by hand (which the docs already ask for).

### C1 — (if option 1) conflict-aware merge

Track, per node, the facts the branch requires *and* their polarity. When
merging `action.get_preconditions()`, if a key already exists in the node's
required set with the opposite value, reject the candidate (do not recurse).
Keep the existing `MAX_PLAN_DEPTH`, visited-signature, and cheapest-plan
behavior unchanged. Suggested shape: carry a `required: Dictionary` alongside
`state`, or detect conflicts by comparing the precondition against the
pre-merge `desired_state[key]`.

### C2 — tests

Extend `tests/unit/test_planner.gd` (registered) with:

- the `{b: true, x: true}` scenario above → assert the plan is empty under
  option 1;
- a non-conflicting variant that still plans (guard against over-rejection);
- an ancestor-conflict case (root requires `f: true`, action precondition
  `f: false` deep in the chain);
- the existing tests (cheapest plan, precondition chaining, no-solution) must
  still pass unchanged.

### C3 — golden replay

If option 1 changes real plans, re-record and state why (D6/D12). Also run the
boot smoke and confirm units still move (`SMOKE_RESULT ... moved=>0`).

---

## Track D — State-fact hygiene (OPEN)

**Evidence:** facts are string keys with no schema; `docs/ai/world-state.md`
has drifted; the `null != false` trap has already caused production bugs
(`get_lumber.is_valid`, D8). Known offenders: `opponents_in_sight` (unread),
`after_arive` (typo), `resume_path`/`lane_resume_path` (dead readers),
`stunned` (legacy alias), `death` (superseded by `unit.dead`).

### D1 — state-key constants

Add a script (e.g. `goap/goap_system/state_keys.gd`) with `const` keys, and
migrate `set_state`/`get_state`/precondition/effect/desired-state literals
incrementally (one behavior per commit). Do not rename keys as part of this —
constants must keep the exact current strings until a deliberate rename.

### D2 — documented reset contract

For every fact written by a goal's `is_valid()` or an action's `enter()`,
document **who clears it and when** (extend `docs/ai/world-state.md`). At
minimum: `has_destiny`, `arrived_at_destination`, `enemy_dead`,
`enemy_in_attack_range`, `friends_safe`, `is_threatened`, `has_wood`,
`returning_wood`, `is_retreating`, `arrived_at_retreat`. The invariant to
state: *a fact the planner treats as "already satisfied" must be reset before
the planner next reads it when the world no longer satisfies it.*

### D3 — remove dead keys

- `opponents_in_sight`: delete the write (`enemy_defeated.gd:38`) or give it a
  consumer; it allocates a full sight list per enemy-goal evaluation for no
  reader.
- `after_arive` → rename to `after_arrive` in all writers/readers, or leave
  and document the typo explicitly (renaming is safe: single file).
- `resume_path`/`lane_resume_path`: remove writers/erasers and the commented
  readers, or restore the resume feature deliberately.
- `stunned`: after Track B, verify only `order_action.gd` reads it; drop the
  alias and the defensive reads (canonical key is `is_stunned`).
- `death` on agent state: unused; `Unit.dead` is authoritative.

### D4 — `state_changed` arity

`agent.gd:8` declares `signal state_changed(goal, action)` but `agent.gd:156`
emits one combined string; `Unit.gd:140` connects `hud.update_state(text)`.
Decide the contract and make declaration/emission/consumer agree. Lowest-risk
fix: declare `signal state_changed(text)` (or emit
`goal.get_class_name(), action.get_class_name()` and change
`hud.update_state` to two args). Add an assertion in
`test_agent_signals.gd`.

### D5 — catalog completeness test

Add a test that scans `.gd` files (see `tests/helpers/fs_scan.gd`) for
`set_state("…")` / `get_state("…")` / precondition/effect keys and asserts each
appears in `docs/ai/world-state.md`. Keep a small allow-list for
unit-state names. This is the only durable guard against key rot.

---

## Track E — Perf and cleanup (OPEN, measure first)

### E1 — delete dead `ChooseTactics`

`goap/game_logic/actions/choose_tactics.gd` extends `Node` (violates the
action-contract invariant), hard-returns `is_valid() == false`, and is
referenced only by its own file and `action_registry.gd:6`. Delete the file and
the registry entry, then update the registry-count assertion in
`tests/unit/test_planner_real_actions.gd:89` (19 → 18) and any docs counts.

### E2 — corpse per-second work and `all_units` growth

Dead units are skipped by the pump (`goap.gd:36`) but
`WorldState.second_elapsed` still calls `Agent.on_every_second` for every
corpse, and corpses stay in `all_units`. `Unit.regenerate`/
`apply_damage_over_time` self-guard on `dead`, so this is wasted work rather
than a behavior bug. Options: disconnect `second_elapsed` in
`Agent.on_death_started`, or guard `on_every_second` on `_unit.dead`. Do **not**
erase from `all_units` on death without a matching re-append on `recycle()`
(D13 documents the invisible-respawn trap).

### E3 — planner cost

`planner._transform_tree_into_array` materializes every solution before
picking the cheapest; `_get_best_goal` re-calls `priority()` on the incumbent
each comparison (`agent.gd:184`). Measure with
`-- --perf` (`tests/perf_monitor.gd`) and DECISIONS D13 before/after; put the
numbers in the commit message. Candidate changes: cheapest-first
branch-and-bound, or cache `priority()` per goal per evaluation. Any planning
change → golden re-record.

### E4 — WorldState timer idempotency

`WorldState.setup_timers()` (`world_state.gd:50-55`) creates and adds a new
`Timer` on every `game.start()` and never stops the previous one;
`clear_state()` does not touch timers. Make setup idempotent (reuse/`queue_free`
correctly, stop before re-creating) and add a unit test for double-`start()`.

---

## Track F — Test hardening (OPEN)

### F1 — order-cancellation test tests the mock

`tests/unit/test_order_action.gd` asserts `player_order_cancelled`, a key set
only by its own `TestAgent.cancel_player_order()` double (lines 44-46, 108).
Production `Agent.cancel_player_order()` (`agent.gd:266-270`) sets
`player_order_complete = true` and `has_player_command = false`, and clears the
plan. Rewrite the assertion against production semantics; ideally drive the real
`Agent` (the pattern in `test_action_lifecycles.gd` shows it works outside the
tree).

### F2 — re-sabotage the ported planner/agent assertions

`tests/COVERAGE.md` "Known coverage limits" admits the ported assertions were
not individually re-sabotaged. For each assertion in `test_planner.gd`,
`test_planner_real_actions.gd`, `test_agent_signals.gd`,
`test_action_lifecycles.gd`: break the production line it claims to guard, watch
the test fail, revert. Record any assertion that survives (that test is
testing a mock).

### F3 — boot-smoke behavioral coverage for the arrival fix

If Track B lands, consider extending `tests/debug_map.gd` / the smoke scenario
so the boot smoke exercises a lumberjack (or a retreat) end-to-end, not just
leader/pawn movement. Keep assertions behavioral (`SMOKE_RESULT ... moved=>0`),
not structural.

---

## Appendix 1 — verified traps (cite these in reviews)

1. `null != false`: an unset key never satisfies a `false` precondition; typed
   `-> bool` reads must pass a default.
2. `has_destiny` is set by `Navigate.follow_path` and never cleared — stale
   `true` lets the planner emit a bare `[Move]`.
3. `Move.perform()` returns `false` only when `arrived_at_destination` is
   already true; otherwise it completes immediately (one-shot step).
4. Arrival is collision-driven; `ArriveAtDestination.is_valid()` is pinned
   `false` (`test_arrive_at_destination.gd`).
5. `agent.set_state("target", v)` writes `unit.target` via
   `ChooseTarget.set_target`, not `_state["target"]`.
6. Action instances are shared singletons; only team-scoped mutable state is
   allowed in them (`Taxes.player_tax/enemy_tax` is the surviving example).
7. `Goap` has **no** `move`/`navigation` members — `Goap.get_action(...)` and
   the `Navigation` autoload only.
8. The pump is `physics_process`, deliberately not a Godot virtual, called
   from `game.gd:170`.
9. Physics is 60 Hz (legacy project key ignored); per-unit cadence ~8.6 Hz.
10. Golden checkpoints are frame-indexed; manual runs need
    `--headless --fixed-fps 60`.

## Appendix 2 — file map for the work items

| Concern | File |
|---------|------|
| Pump/throttle | `goap/goap_system/goap.gd` |
| Agent lifecycle, signals, state | `goap/goap_system/agent.gd` |
| Planner | `goap/goap_system/planner.gd` |
| Contracts | `goap/goap_system/action_contract.gd`, `goal_contract.gd` |
| Registries | `goap/game_logic/action_registry.gd`, `goal_registry.gd` |
| Actions | `goap/game_logic/actions/*.gd` |
| Goals | `goap/game_logic/goals/*.gd` |
| Arrival driver | `collision/collisions.gd` |
| Units / signals | `unit/Unit.gd` |
| Facts catalog | `docs/ai/world-state.md` |
| System map | `ARCHITECTURE.md` |
| Suite | `tests/run_suite.sh`, `tests/run_tests.gd`, `tests/unit/*` |
| Golden | `tests/golden/replay_300.txt`, `tests/smoke/smoke_runner.gd` |

## Appendix 3 — reporting template for each completed item

```
Item:            <ID + title>
Branch:          <branch>
Files changed:   <list>
Tests added:     <file::assertion, or none + why>
Count pin:       EXPECTED_UNIT_TESTS 306 -> <N>
Suite:           passed=<N> failed=0 | smoke <result> | golden <ok|re-recorded>
Script errors:   0
Golden re-record: <no | yes + reason>
Could not verify: <list or "none">
```
