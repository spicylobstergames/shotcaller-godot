# Decision Log

Design decisions made during development, with rationale. When you hit a
fork in the road, check here first — if the decision is recorded, follow it;
if not, make one, add it here, and say why.

Format: decision / alternatives considered / why.

---

## D1 — Hire payment is collective (pooled check, even split)

**Decision:** `camp_hire` pools gold across the team's leaders for the
affordability check and splits the cost evenly (`floor(cost / leaders)`) —
same convention as the pre-existing `lumberjack_hire`. The floor split can
leave a remainder unpaid (cost 3 across 2 leaders deducts 2); accepted.

**Alternatives:** per-leader full-cost deduction (the original buggy code —
2 leaders with 2 gold each passed a 3-gold check and both went negative);
individual affordability (each leader must afford the full cost — breaks
pooling semantics).

**Why:** consistency with `lumberjack_hire`'s existing convention; the bug
was the check/deduction mismatch, not the pooling idea. Regression-tested in
`test_spawns.gd` (`_test_camp_hire_gold_deduction_semantics`).

## D2 — `lumberjack_hire` has no affordability gate (pinned quirk)

**Decision:** NOT fixed. `lumberjack_hire` deducts unconditionally and can
drive a 0-gold leader negative. Pinned by
`_test_lumberjack_hire_has_no_affordability_gate`; documented in
ARCHITECTURE.md and COVERAGE.md.

**Alternatives:** add the same pooled gate as camp_hire.

**Why not:** that's a gameplay design change (who pays for lumberjacks?),
not a bug fix — it belongs to the project owner. Adding a gate must flip the
pinning test deliberately.

## D3 — Script-error budget counts `SCRIPT ERROR` lines only

**Decision:** the suite fails on any `SCRIPT ERROR` in Godot output; other
`ERROR`/`WARNING` lines (e.g. the intentional "Failed loading resource:
nonexistent_unit.tscn" from negative tests) do not fail it.

**Alternatives:** fail on all ERROR output.

**Why:** script errors can silently swallow assertions (a failing expression
aborts the statement containing it), which makes a "passing" suite lie.
Other engine errors are often intentional probes in negative tests; failing
on them would force suppressing real diagnostics.

## D4 — `advance_with_navigation` is left uncovered by tests

**Decision:** the boot smoke exercises the live movement path
(`MoveAction.calc_step`/`step`). The navigation refinement
(`Unit.advance_with_navigation`) is dormant by default
(`Goap.use_native_pathfinding = false`) and is not smoke-covered; if that
config flips on, add coverage then.

**Alternatives:** enable native pathfinding in the smoke scenario.

**Why:** testing a disabled path adds cost without protecting current
behavior; the config flag is the real decision point.

## D5 — Determinism strategy

**Decision:** two layers. (a) Unit tests avoid RNG entirely where possible —
`hit_modifiers` tests inject skill values 1.0/0.0 through the real
`Skills.leader` seam instead of seeding `randf()` (same branch, deterministic
outcome). (b) The golden replay seeds the global RNG (`seed(20240101)`),
passes `--fixed-fps 60` for constant frame deltas, and skips
`game.rng.randomize()` under `--golden`.

**Alternatives:** seeding-only everywhere (keeps the randf threshold
nondeterministic at boundaries); frame-recording gameplay.

**Why:** injection tests the same production branch without brittleness;
the golden replay needs full-stream determinism and gets it from the
fixed-fps + seed combination.

## D6 — Golden replay update protocol

**Decision:** when the golden comparison fails, the change is either a
regression (fix the code) or an intended behavior change — in which case
re-record with `--golden-update` and state the reason in the commit message.
The golden file (`tests/golden/replay_<frames>.txt`) is committed.

**Why:** the whole value of the replay is that silent divergence is loud.
Silently re-recording would destroy it.

## D7 — `EXPECTED_UNIT_TESTS` exact-count pin

**Decision:** `run_suite.sh` pins the exact expected assertion count; the
runner must emit a matching `TESTS_COMPLETE` token. Bump the pin when adding
tests.

**Alternatives:** minimum-threshold check (defeats count-drift detection);
no check (a bypassed runner can fake green).

**Why:** two-file agreement catches accidental drift and bypassed/crashed
runners. Honest limit: it cannot stop deliberate forgery (the pin is
readable) — self-reporting has that ceiling.

## D8 — WorldStateSnapshot erases absent keys on restore

**Decision:** keys that did not exist before a test are ERASED on restore,
not set to null. Setting null poisons `get_state(key, default)` for typed
readers (returns null instead of the default). Self-tested in
`test_helpers.gd`.

**Why:** the poisoning variant broke two production actions
(`get_lumber`/`wait_out` `is_valid() -> bool`) during planner-test
development.

## D9 — Mirror test expectations follow production semantics

**Decision:** mirror corner expectations use the production formula's actual
outputs (e.g. (0,0) → (98,78) on a 100×80 grid, not the intuitive (99,79)) —
`map_to_local` returns cell centers, so the mirror axis is center-aligned.
The invariant tests assert involution/reversibility properties, not assumed
corner mappings.

**Why:** "tests verify intended map symmetry" — the symmetry property holds
for every cell; hard-coding an off-by-one corner expectation would pin a
guess instead of the formula.

## D10 — Golden replay comparison robustness

**Decision:** the golden comparison is field-specific and sort-stable:
- Only POSITIONS get a tolerance (0.5 per axis) — platform float drift in
  movement. Every other field (hp, level, kills, deaths, time) is compared
  EXACTLY: hp 100 → 99 or time 1 → 2 is a real gameplay change, not drift.
- Generated node names (`@StaticBody2D@83`) are normalized (counter → `#`)
  BEFORE sorting, and units sort by the normalized identity + type + team
  (position as tie-breaker) — never by raw node names, whose allocation
  counters could reorder output that normalization then erases.
- Checkpoints at frames 100/200/300 catch mid-run divergence even if it
  converges by the final frame; the final checkpoint's frame label is
  computed independently (the intermediate-frame array doesn't contain it —
  indexing it would raise out-of-bounds and mask the real diagnostic).

**Alternatives:** per-frame hashing (heavy, still sampled — frames are
continuous); broad numeric tolerance (accepts real state changes like
hp 100 → 99 — proven by sabotage: that exact change passed the original
±1.0 comparison and fails the field-specific one).

**Why:** platform/build float differences are noise; state changes are
signal. The tolerance must be able to tell them apart, field by field.

## D11 — Port scope: defer GOAP-coupled suites onto the post-restructure base

**Decision:** the CI-verified suite is ported onto upstream main after the
GOAP restructure (`Orders` removed, `ChooseTarget`/`ChooseTactics` split,
global `Navigation`, `wait_out` deleted, movement re-planned through
WalkLane goals), but the GOAP-coupled suites (planner, agent, goal, movement,
navigation, orders — 14 test classes) and the golden replay are DEFERRED, not
ported and not deleted. The ported subset is everything targeting seams the
restructure did not touch: skills/modifiers, spawns/camp_hire, collisions,
mirror tiles, helpers, and the whole-project parse/scene smokes, plus the
boot smoke (now on the real three-lane map) and the script-error budget.

**Why:** upstream main broke the GOAP action/goal contract repeatedly within
days of the port (2 breaking merges during the port window). Porting deep
GOAP behavior pins against a moving API produces tests that rot on arrival
and block merges; porting the harness + stable-seam coverage gives upstream
a CI floor immediately. The deferred suites live on the PR branch and the
fork's `test-*` branches; re-entry criteria are in `COVERAGE.md`.

**Consequences:** until re-introduction, upstream main has no automated
planner/agent/lifecycle coverage — regressions there will surface only as
boot-smoke-level symptoms (frozen simulation) or not at all. The golden
replay's committed checkpoints pin pre-restructure behavior and MUST NOT be
re-added without a fresh `--golden-update` recording; comparing new behavior
against old checkpoints would read every restructure change as a regression.

**Also fixed in this port** (regression-tested; still-live bugs found on the
new base): `camp_hire` pooled-gold semantics + gold-less-leader crash,
`passive_skills` null-safe leader lookups + `counter` flag preservation,
`modifiers` null-safe `get_value`/`get_velocity`, and the headless minimap
stall (`frame_post_draw` never fires without a display) that blocked the
map-ready chain before any unit spawned.

## D12 — Full port: GOAP suites re-pointed, golden replay re-recorded

**Decision:** contrary to the interim D11 deferral, ALL remaining GOAP-coupled
suites were ported onto the post-restructure base, and the golden replay was
re-recorded from scratch. Per-suite outcomes:

- Ported with contract updates: planner (class names Move/Navigate/Retreat/
  WaitForRegeneration; Recover chain Retreat -> WaitForRegeneration),
  agent signals/target/tactic, action lifecycles (now through the REAL
  Agent instead of a duplicated plan-follower — the duplication rule wins),
  goal interactions, GOAP integration, movement (native switches removed;
  blocking is soft repulsion), navigation (global Navigation autoload),
  order action (completion via player_order_complete/has_player_command),
  attack targeting (priority system deleted upstream; proximity + can_hit
  pinned).
- NOT ported, subject removed upstream: the orders-panel signal suite
  (panel + priority-init chain deleted). The surviving successor path
  (tactics_panel build_leaders) runs in every boot-smoke run.
- PINNED, not "fixed": ArriveAtDestination.is_valid() hard-false (activation
  commented out upstream; arrival is collision-driven). Re-activating it
  would change AI behavior mid-upstream-development — that call belongs to
  upstream. recover.gd's agent-vs-unit on_arrive inconsistency documented.

**Golden replay:** the old checkpoints pinned pre-restructure behavior and
were replaced with a fresh recording on the new base, verified
byte-identical across two recordings. Never diff new behavior against the
old snapshots.

**Production regressions the port caught (fixed, regression-tested):**
nine actions unplanned by the flipped action_contract.is_valid default,
get_lumber's null-return is_valid aborting plan searches, camp_hire gold
semantics, passive_skills counter-flag erasure + null lookups, modifiers
null-safety, and the headless minimap stall. Full list in COVERAGE.md.

## D13 — main's GOAP perf fix did not survive the merge; re-port it as its own change

**Decision:** the merged tree keeps **upstream's** pump — `Goap.physics_process`
iterates every unit with only an `if unit.agent` guard
(`goap/goap_system/goap.gd:34`). main's pre-merge perf commit `d15ca30` is NOT
re-applied: not the `ai_delay` stagger (`Unit.ai_delay = randi_range(0,6)`;
process a unit only when `ai_delay == 0`, then reset to 6, else decrement — a
~7-frame planning interval per unit with randomized phase), and not the
`all_units.erase(self)` on death that came with the `!unit.dead` guard. The gap
is recorded here, measured on the new base, and left open as a follow-up instead
of being resolved inside the merge.

**Alternatives:** graft both back during conflict resolution (rejected —
`goap.gd` and `Unit.gd` conflicted on both sides; a scheduling change smuggled
into a 36-conflict merge hides a behavior change in a merge commit, and both
mechanisms move frame-by-frame agent state, which is exactly what the golden
replay now pins at frames 100/200/300 — D5/D6/D12). Re-port after the merge as a
standalone, measured change with its own tests and a `--golden-update`
re-record (chosen). Do nothing (rejected — the cost is measurable, below).

**Why — measured on the merged tree:** `godot --headless --path prototype
res://game.tscn -- --perf` (`tests/perf_monitor.gd`, added by fbe1822). fps
holds at ~145 for the first ~35 s, then collapses deeper each cycle — 6 at
t=37 s, 5 at t=52 s, sustained 3–4 from t=68 s — while `all_units` grows
monotonically 151 → 175 → 197 → 213 → 228 and ticks/s falls from ~60 to ~30.
The *simulation* is stalling, not just rendering. Memory stays flat (127 →
135 MB) while node count climbs (2949 → 5114): growing per-tick work, not a
leak. `dup=0` because `recycle()` (`map/spawns.gd:129`) reuses cemetery units
without re-appending; the growth is new wave spawns on top of permanent corpses.

**What the gap costs on this base:** nothing in production code removes from
`all_units` (appends only: `map/spawns.gd:45`, `collision/collisions.gd:41`,
`map/map_manager.gd:107`); `Unit.die()` (`unit/Unit.gd:493`) hides the corpse
and hands it to the cemetery but leaves the entry in the list; and neither the
pump nor `Agent.goap_process` (`goap/goap_system/agent.gd:168`) checks `dead` —
so every corpse keeps full goal evaluation and planning every physics tick,
forever.

**Trap to avoid when re-porting:** `d15ca30`'s erase-on-death had no matching
re-append — only `create()` appended (`map/spawns.gd:45`), `recycle()` never
did. Erasing a corpse therefore removed it from the simulation permanently: its
respawn came back through `recycle()` invisible to the GOAP pump, to selection,
and to the UI. A re-port must either re-append on recycle or prefer the
pump-side guard (`if unit.agent and not unit.dead`), which skips corpse work
without mutating a list every other system owns.

**Also found while measuring:** the pump runs at 60 ticks/s, not the 30 Hz the
docs claim — `Engine.get_physics_ticks_per_second()` reports 60 even though
`project.godot` sets `common/physics_fps=30` (Godot 4 renamed that key to
`physics/common/physics_ticks_per_second`; the legacy name is ignored). So GOAP
planning costs 2× the documented rate, and the whole golden replay is recorded
at 60 Hz. Fixing the setting is the same class of decision as the stagger: it
changes frame-by-frame state and needs its own re-record, not a drive-by edit.

**Consequences:** the fps decay is live on main and invisible to the suite —
`run_suite.sh` gates on 300 ticks, not wall-clock, and `--perf` is deliberately
never part of gating. Re-entry criteria for the re-port: (1) measure before and
after with `--perf` and put the numbers in the commit message, (2) a regression
test that dead units are not planned for, (3) a golden re-record with the reason
stated in the commit (D6/D12), (4) keep it upstream-facing — `goap.gd` is
upstream-owned, so a fork-only divergence there conflicts again.

## D14 — Golden replay: ±1 hp tolerance under the staggered agent cadence

With the staggered agent pump (`goap_process` every 7th physics tick,
per-unit random start frame), the golden replay's exact-hp comparison became
racy: units regenerate +1 hp per second, and the regen tick straddles a
checkpoint boundary in ~50% of runs — observed as a stable 9910 vs 9911 flip
on the smoke pawn at checkpoint 1 (frame 100) across otherwise identical
runs (same seed, same `--fixed-fps 60`). The flip is timing quantization,
not a gameplay change: a real combat regression shifts hp by a hit (~45),
never by 1.

`smoke_runner._lines_match` therefore tolerates ±1 hp (positions keep their
existing drift tolerance; every other field stays exact). Re-recording does
NOT fix a 50/50 boundary race, and loosening further (e.g. ±5) would mask
real damage regressions — do not widen it. Note also that manual golden
checks must use the canonical flags (`--headless --fixed-fps 60`): the
checkpoints are frame-indexed and headless frames otherwise run uncapped.
