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
