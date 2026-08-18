# AUTONOMOUS_EXECUTION_POLICY — PLAN_REFINEMENT_001 (+ PLAN_REFINEMENT_002 clarification)

**Date:** 2026-08-08  
**Class:** doc-only autonomous execution / promotion policy  
**MATLAB run:** NO · **model/controller edits:** NO · **CODEX_VERTICAL_PLAN:** untouched  
**Physical / hardware readiness:** **NOT_CERTIFIED**  
**PLAN_REFINEMENT_002:** Clarifies Gate 0 “freeze frames/signs” (vehicle frame/sign convention) and prompt bounds as **characters** (not tokens/words). All other PLAN_REFINEMENT_001 rules unchanged.

## Sources (strict, ≤2)

| # | Path | Role |
|---|------|------|
| 1 | `suite_results/AUV_REALIZATION_READINESS_PLAN.md` | Ordered gates; Gate 0 hygiene; frozen envelopes; Gate 1 PARTIAL; next = speed-scheduled ID |
| 2 | `suite_results/AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md` | Layering; clocks; fail-silent / no auto-surface; truth/measured/estimated; Gate 7 ICD prep |

**Evidence labels** (do not upgrade without new evidence):  
`IMPLEMENTED` · `INTERFACE_SPECIFIED` · `IDENTIFIED` · `DERIVED` · `TUNED` · `FIXED` · `ASSUMED` · `TO_BE_IDENTIFIED` · `NOT_IMPLEMENTED` · `NOT_CERTIFIED`

This policy **does not rewrite** gate PASS criteria in the readiness plan. It adds autonomous-agent execution rules, refinement hooks, and promotion/Pareto discipline for Cursor/Codex task loops. Simulation PASS ≠ hardware certification.

---

## 1. Verdict

**Autonomous execution policy: CREATED.**  
Agents may advance digital-twin work only under Gate 0 hygiene, frozen prompts/sources, honest labels, and the promotion rules below. Gate order and EXTERNAL terminus remain as in the readiness plan.

**Next technical task (unchanged):** `depth_gamma_speed_scheduled_id_extension` for U={1.0, 1.5, 2.0}.  
**Do not edit:** `suite_results/CODEX_VERTICAL_PLAN.md`.

---

## 2. Cursor / agent prompt bounds

| Bound | Limit | Rule |
|-------|-------|------|
| Default prompt | **≤ 1600 characters** | Prefer single gate, single next task, frozen sources |
| Complex EKF / interface | **≤ 2400 characters** | Only for bounded complex EKF/interface tasks (e.g. Gate 5 EKF interface or mission ICD wiring as the explicit task) |
| Sources | **max 3** read paths per task | Prefer readiness plan + ICD + one evidence MD; never invent sources |
| MATLAB | **max 1** MATLAB invocation per task | Doc-only tasks: **0**; ID/bench scripts: one bounded call |
| Scope | One `TASK_ID` / one next exact task | No leapfrog of Gates 3–6 into Gate 7 implementation |
| CODEX | Untouched | Never edit `CODEX_VERTICAL_PLAN.md` |

---

## 3. Gate refinement hooks (additive — do not replace readiness PASS tables)

### Gate 0 — Artifact / disk preflight (+ freeze & cleanup)

**ID:** `artifact_disk_preflight_gate` (hygiene; every task)

| Rule | Requirement | Label |
|------|-------------|-------|
| Freeze frames / signs | Freeze the vehicle **coordinate-frame and sign convention** before heavy work: BODY/NED axes, Euler/rates, depth z-down, actuator signs — with **units** and a **source reference**. Does **not** mean git/status snapshot or task signing | `INTERFACE_SPECIFIED` |
| Volume / start | ≥ 3 GiB free to start heavy runs; preferred ≥ 5 GiB (readiness append) | process |
| Preserve | Keep **accepted** MD/MAT/PNG and **source**; never delete frozen evidence | process |
| Cleanup allowed | **Only** verified **inactive** project caches: `slprj/`, `*.slxc`, and other **generated** Simulink/MATLAB caches attributable as unused | process |
| Cleanup forbidden | Accepted evidence; source; OS/admin global temp wipes; deleting anything not verified inactive | process |
| Dedup | No duplicate raw MAT for the same accepted run tag | process |

### Gate 2 — Structural depth/γ (+ bumpless transfer)

Additive to structural decoupling / governor / AW:

| Hook | Requirement | Label |
|------|-------------|-------|
| Bumpless mode transfer | Mode or branch switches (governor engage, AW engage, structure swap) must be **bumpless** in command/state handoff — no step discontinuities beyond declared envelope | `INTERFACE_SPECIFIED` · sim policy |
| Bumpless estimator transfer | If/when estimated streams exist, estimator/init handoff across modes must be bumpless (aligns with Gate 5 truth/measured/estimated) | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` until Gate 5 |

Does **not** reopen rejected depth/γ controllers (gamma INDI/PI/LADRC, depth PI/NDO).

### Gate 3 — Closed-loop actuator realism (+ allocation & delay grid)

| Hook | Requirement | Label |
|------|-------------|-------|
| Control-allocation abstraction | Fin/thrust commands pass through an explicit **allocation** layer (logical δe/δr/thrust → actuator channels) so lag/deadband attach without rewriting guidance/controller APIs | `INTERFACE_SPECIFIED` · `NOT_IMPLEMENTED` |
| Actuator / ESC delay grid | Closed-loop delay cases **{0, 15, 30} ms** plus jitter | `ASSUMED` until bench ID |
| Provenance | τ/deadband/delay remain `ASSUMED` unless EXTERNAL/bench upgrades; gate remains **NOT_CERTIFIED** | honesty |

### Gate 5 — Multirate nav / EKF (+ availability matrix)

| Hook | Requirement | Label |
|------|-------------|-------|
| Availability matrix | Explicit cases: **DVL bottom-lock loss**, **pressure disagreement**, optional **USBL outage** | `INTERFACE_SPECIFIED` · scenarios `ASSUMED` until field data |
| Metrics | Measure **dead-reckoning duration** and **simulated safe-hold trigger** latency/conditions | sim evidence |
| Surface policy | **No auto-surface** on availability loss (align ICD §6; HIL required for any surface policy) | `INTERFACE_SPECIFIED` |
| Streams | Every controlled channel tagged `{truth, measured, estimated}` | Gate 5 PASS language |

### Gate 6B — Real-time / power-integrity contract (subset of Gate 6)

**ID hook:** `real_time_power_integrity_contract` under propulsion/power/compute realism.

| Field | Requirement | Label |
|-------|-------------|-------|
| Timing contract | Document **period**, **deadline**, **WCET**, **jitter**, **overrun** policy, **priority** | `INTERFACE_SPECIFIED` |
| Power integrity | **Brownout** / undervoltage inputs into compute/actuate health | `INTERFACE_SPECIFIED` · thresholds `ASSUMED` |
| Rates | Numeric mission/nav/actuator-feedback rates remain **`TO_BE_IDENTIFIED`** unless evidenced (controller 40 Hz FIXED target; guidance 13.33 Hz DERIVED per ICD) | clocks |
| Cert | Sim delay/power envelopes only → **NOT_CERTIFIED** | honesty |

### Gate 7 — Mission manager / fail-silent (+ FDIR matrix)

Sim-only FDIR checklist (**NOT_CERTIFIED**; does not PASS Gate 7 without Gates 3–6):

| Fault / monitor | Response class (sim) |
|-----------------|----------------------|
| Stale **IMU** / **DVL** / **depth** | Integrity flag → fail-silent / safe-hold path |
| Mission **heartbeat** loss | Stale mission → fail-silent; hold last safe local refs |
| Actuator **stuck** / abnormal **current** | Actuator health → constrain or hold |
| **Bus timeout** | Treat as stale/invalid uplink/downlink |
| **Undervoltage** / **leak** | VehicleHealth proxies → safe-hold (sim) |

**No** auto-surface / auto-accommodate without HIL-validated policy. Local mag/rate/safety authority overrides mission.

### Gate 8 — Monte Carlo (+ independent priors)

MC factors (independent draws; **`ASSUMED` priors** until Gate 9 / EXTERNAL ID):

| Factor | Prior / range |
|--------|----------------|
| CG / CB offset | **±2 cm** each axis (independent) |
| Buoyancy | **±3%** |
| Sensors | Bias / delay / dropout per availability matrix |
| Actuators | Lag / delay (incl. Gate 3 `{0,15,30}` ms + jitter priors) |
| Battery / power | Envelope / brownout proxies from Gate 6B |

No silent narrowing of uncertainty to force PASS. Percentiles over means alone.

---

## 4. Promotion policy (candidate → accepted production / frozen metric)

Applies when promoting an isolated branch or retune into accepted evidence. Does **not** reopen frozen cascade casually.

| Class | Rule |
|-------|------|
| Primary KPI | Candidate must improve primary KPI by **≥ 5%** (declare KPI a priori) |
| Secondary non-safety | May be **≤ 2% worse** **only if** all absolute gates still PASS |
| Zero tolerance | **Any** instability, or hard **magnitude / rate / saturation / depth / collision / watchdog / FDIR** failure → **reject** (no trade) |
| Labels | Do not upgrade `ASSUMED`→`IDENTIFIED` without evidence |
| Rejected architectures | Never retry closed dead-ends listed in readiness plan |

---

## 5. Pareto tracking vector

Every promotion or gate-comparison report must track (or explicitly mark N/A with reason):

| Axis | Intent |
|------|--------|
| **Tracking** | CTE / attitude / depth / speed errors vs frozen defs |
| **Actuator margin** | Mag/rate headroom, sat/rate-rail dwell |
| **Energy** | Thrust / \(u^2\delta\) proxies / power draw when available |
| **Estimation** | NEES / integrity / availability when Gate 5+ |
| **Timing** | Period/deadline/jitter/overrun (Gate 6B) |
| **Safety** | Watchdog/FDIR/safe-hold triggers; no auto-surface violations |

Treat as a **Pareto vector**: no silent win on one axis by hiding losses on safety or hard envelopes.

---

## 6. Relation to realization sequence

```text
Gate0 freeze frames/signs (coord/sign convention) + cache-cleanup hygiene (every task)
  → Gates 1–9 as readiness plan (unchanged PASS tables)
  → this policy’s additive hooks bind at Gates 2,3,5,6B,7,8
  → EXTERNAL only after Gate 9
```

Gate 1 remains **PARTIAL** (U=1.5 level/climb). Mission ICD remains Gate 7 **prep**, not PASS.

---

## 7. Next exact task

**`depth_gamma_speed_scheduled_id_extension`** for U={1.0, 1.5, 2.0}.  
No brand/purchase. No CODEX_VERTICAL_PLAN edits. No gate rewrite.

---

## 8. Cross-references

- `suite_results/AUV_REALIZATION_READINESS_PLAN.md`  
- `suite_results/AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md`  
- **Do not edit:** `suite_results/CODEX_VERTICAL_PLAN.md`

---

## 9. PLAN_REFINEMENT_002 clarifications (doc-only)

| Item | Corrected meaning |
|------|-------------------|
| Freeze frames / signs | Vehicle **coordinate-frame and sign convention** (BODY/NED axes, Euler/rates, depth z-down, actuator signs) with units + source reference. **Not** git/status snapshot or task signing. |
| Prompt limits | **Characters** (not tokens/words): default **≤1600**; only bounded complex EKF/interface tasks **≤2400**. |

All other PLAN_REFINEMENT_001 rules, next task, and gate order unchanged.

---

<!-- APPEND_MARKER:EMBEDDED_HANDOFF_TRANSITION_PLAN_001 -->

## 10. Append: EMBEDDED_HANDOFF_TRANSITION_PLAN_001 — Gate 9B execution rules (doc-only, additive)

**Date:** 2026-08-09 · **Class:** doc-only · **MATLAB/code:** NO · **CODEX_VERTICAL_PLAN:** untouched · **HW:** **NOT_CERTIFIED**

Additive only: §§1–9 rules, prompt bounds, promotion policy, Pareto vector, gate order and all rejected-architecture bans are unchanged. **Next technical task remains Gate 8.**

### Gate 9B hook — `embedded_transfer_readiness_audit` (POST-GATE9)

| Rule | Requirement | Label |
|------|-------------|-------|
| Trigger | Runs **only after Gate 9 PASS**; never leapfrogs Gate 8 | process |
| Mode | **Audit, not campaign**: revisit all production/runtime code and all accepted **and** failed evidence; **do not rerun** research candidates or closed dead-ends | process |
| Scope | Checklist A1–A13 in the readiness-plan append: reachable runtime inventory; static/analyzer/compile; TODO & dead branches; forbidden rejected methods; frames/units/signs; rates/ZOH/timestamps; truth/measured/estimated; bounds/NaN/overflow; determinism/reset/bumpless; dynamic allocation/file I/O/globals/persistent & unsupported embedded constructs; layer ownership; FDIR/watchdog authority; evidence/provenance traceability | `INTERFACE_SPECIFIED` |
| Classification | Every finding is exactly one of **BLOCKER** / **TARGET_DEPENDENT** / **EXTERNAL_HIL** / **COSMETIC** | mandatory |
| PASS | No unresolved software/safety **BLOCKER** **and** a complete **embedded handoff manifest** | gate |
| Cert boundary | Gate 9B PASS **never** upgrades a `NOT_CERTIFIED` hardware claim; no timing/memory/numeric claim on real silicon | honesty |
| Cosmetics | Minor plot/prose cosmetic defects **do not block transfer** but are **tracked** in the audit register until repaired by a regenerating run | process |
| Terminus | On PASS, stop at **`AWAIT_STM32_EXACT_PART_NUMBER`**. **Do not select, guess, recommend or imply an MCU.** No purchase/brand/vendor claim | hard stop |

### Post-stop unlock (defined, not authorized now)

After the user supplies the **exact STM32 part number and board**, target-specific realization phase 1 may begin: toolchain/codegen strategy; clock/FPU/cache/MPU; RTOS task map against the Gate 6B timing contract; HAL/LL & peripherals; DMA/interrupts; memory/stack/Flash/RAM/WCET budgets; numeric type selection; comms/bootloader/logging; **SIL → PIL → HIL** evidence. Prompt bounds (§2), source/MATLAB caps and promotion policy (§4) apply unchanged.

**Next exact task (unchanged):** `gate8_monte_carlo_independent_priors_campaign`.

---

<!-- APPEND_MARKER:GATE8_RESIDUAL_RISK_WAIVER_AND_GATE9_ENTRY_001 -->

## 11. Append: GATE8_RESIDUAL_RISK_WAIVER_AND_GATE9_ENTRY_001 — waiver, bounded Gate 9 entry, audit relaxation (doc-only, additive)

**Date:** 2026-08-09 12:21:58 · **Class:** doc-only · **MATLAB:** 0 · **Source/runtime edits:** NONE · **Repo scan:** NONE · **CODEX_VERTICAL_PLAN:** untouched · **HW:** **NOT_CERTIFIED**

Additive only. §§1–10 rules, prompt bounds, source/MATLAB caps, promotion policy, Pareto vector and every rejected-architecture ban are unchanged and are **reinforced**, not relaxed, by this append. Sources read for this task: exactly 3 — `AUV_REALIZATION_READINESS_PLAN.md`, this file, `GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE.md`.

### 11.1 Gate 8 disposition recorded

**Gate 8 verdict: `WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT`.** Gate 8 is **NOT PASS** and must never be transcribed as PASS. The waiver is issued under the readiness plan §4 rule *"PASS or explicitly waived with a written residual risk"*, on the user's direction to finish the simulation-readiness phase and to stop a method line after repeated nonproductive closure attempts.

Attempt tally that justifies stopping: **three failed Monte Carlo closure attempts** — `GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001` (**FAIL**, HG5/HG8/HG11/HG12/HG13), `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_001` (**FAIL**, HG5/HG11/HG12/HG13), and the R10 rail-closure line ending in `GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE_001` (**REJECT_C1_METHOD_CLOSED**), with `GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001` returning **BLOCKER / no single origin evidenced**.

### 11.2 Ban list extended (never retry)

| Closed method | Closure record | Reason closure is structural |
|---|---|---|
| Coordinated scalar rescaling of `(Kp_psi, Kd_psi)` at fixed `Td` | `SCALAR_METHOD_CLOSED` (PG7) | No stored anchor cleared PG1–PG9; rail dwell falls only by trading cross-track error (0.21262 → 0.89243 m across the anchor set) |
| C1 shadow course reference, `k_beta` 1.35 → 1.00 | `REJECT_C1_METHOD_CLOSED` | Conjunctive primary: over-crab removal +100.0000% but implied P demand +0.3806% against a declared +5% floor; the term is 0.335019 deg against a 5.625664 deg heading error, so the ratio is fixed by structure |
| gamma INDI / PI / LADRC · depth PI / NDO · crab-current FF · simple polyline shaper | pre-existing | unchanged standing ban |

**Rule:** a rejection on **effect size with a stated ratio** is a closure, not a near-miss. It may be cited as evidence and must never be re-run to seek a different number.

### 11.3 Bounded Gate 9 entry (the only thing this waiver unlocks)

| Rule | Requirement | Label |
|------|-------------|-------|
| Scope | **Assessment and evidence-range assembly only**: reproducibility assessment from accepted evidence, component requirement ranges, residual-risk register R1–R8 as a first-class output | `INTERFACE_SPECIFIED` |
| Range provenance | Every requirement range is `DERIVED` and must carry its **parent label** (`ASSUMED` / `TO_BE_IDENTIFIED`) and the residual-risk item that limits it | mandatory |
| Forbidden | New campaigns to manufacture PASS; any banned/closed-method retry; production gain/law/path/threshold/shaper/feedforward edits; label upgrades; `CODEX_VERTICAL_PLAN.md` edits; vendor/brand/part/purchase claims | hard |
| **PASS impossibility** | Gate 9 **cannot** be recorded PASS unless **every hard safety gate passes**. With R1 (R10 rudder rail) unresolved and HG11/HG12/HG13 open, Gate 9 PASS is **unavailable by construction**; **PARTIAL or FAIL is the expected and acceptable outcome** | hard |
| Honesty | A Gate 9 PARTIAL/FAIL is a correct result, not a failure of the task. Do not narrow scope or uncertainty to reach PASS | §4 discipline |

### 11.4 Gate 9B trigger relaxation (audit only)

The §10 rule *"runs only after Gate 9 PASS"* is amended in exactly one respect:

| Item | Old | New |
|------|-----|-----|
| Trigger | Gate 9 **PASS** | Gate 9 **disposition recorded**, RC may be **PARTIAL or FAIL** |
| Mode | audit, not campaign | unchanged — **read-only**, fast whole-code embedded-readiness **gap** audit; evidence read, never re-executed |
| Classification | BLOCKER / TARGET_DEPENDENT / EXTERNAL_HIL / COSMETIC | unchanged, mandatory |
| **Gate 9B PASS** | no unresolved BLOCKER **and** complete manifest | **unchanged and not relaxed** — an audit over a PARTIAL/FAIL RC will normally report BLOCKERs and therefore not PASS |
| Cert boundary | never upgrades `NOT_CERTIFIED` | unchanged |

Rationale: the audit is a **gap inventory**, so running it early costs nothing and surfaces `TARGET_DEPENDENT` work sooner. Its PASS bar is untouched, so nothing is smuggled through.

### 11.5 STM32 hard stop, hardened

`AWAIT_STM32_EXACT_PART_NUMBER` remains the terminus. Target-specific realization phase 1 may begin only when **both** hold:

1. the user supplies the **exact STM32 part number and board**; **and**
2. every unresolved blocker — residual-risk register R1–R8 plus every Gate 9B **BLOCKER** finding — is **explicitly dispositioned** as fixed, waived-with-written-residual-risk, `TARGET_DEPENDENT` or `EXTERNAL_HIL`.

No MCU is selected, guessed, recommended or implied. No purchase, brand or vendor claim is made. Prompt bounds (§2), source/MATLAB caps and promotion policy (§4) apply unchanged throughout.

### 11.6 Next exact task (exactly one)

**`GATE9_SIMULATION_RC_ASSESSMENT_001`**. Gate 8 stays `WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT`, never PASS. Simulation is not hardware certification (**NOT_CERTIFIED**).


<!-- APPEND_MARKER:GATE9_SIMULATION_RC_ASSESSMENT_001 -->

## Append: GATE9_SIMULATION_RC_ASSESSMENT_001 (Gate 9 disposition)

**Date:** 2026-08-09 12:53:47 | **Class:** bounded read-only Gate 9 RC assessment and evidence-range assembly | **MATLAB runs:** 1 | **New campaign:** NONE | **Method retry:** NONE | **Repo scan:** NONE | **Production/CODEX:** byte-identical | **HW:** **NOT_CERTIFIED**

**Verdict: `FAIL` (`RC_NOT_GRANTED`). Gate 9 is NOT PASS and must never be transcribed as PASS.**

- **Zero tolerance applied.** zero tolerance applied: 2 declared gates are FAIL, 2 are WAIVED and not PASS, and 2 residual-risk items are OPEN at BLOCKER severity (R1 R10 rudder rail; R7 hardware NOT_CERTIFIED). HG11, HG12 and HG13 remain open, so Gate 9 PASS is unavailable by construction.
- **Sources read: exactly 3, no repo scan** - `suite_results/AUV_REALIZATION_READINESS_PLAN.md`, `suite_results/PROPULSION_POWER_COMPUTE_PARITY_FIX.mat`, `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.mat`. The two MAT records were loaded and introspected in this run; the plan supplied transcribed constants. Every other file named below is dereferenced from the plan record, not re-read and not re-run.
- **Verification matrix Gates 0-8 as declared:** Gate 0 PASS, Gate 1 PASS, Gate 2 FAIL (CLOSED_AFTER_3_ATTEMPTS), Gate 3 FAIL (CLOSED_AFTER_3_ATTEMPTS), Gate 4 WAIVED (4A PASS, 4B closed FAIL, shadow-only), Gate 5 PASS (interface and integrity only, accuracy CHARACTERIZATION), Gate 6 PASS, Gate 6B PASS, Gate 7 PASS (simulation scope), Gate 8 WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT and never PASS.
- **Residual risk R1-R8 published as a first-class output, all OPEN.** R1 R10 rudder rail (BLOCKER, raw demand 466.6729 deg, rail dwell 0.2817, magnitude dwell 0.8908, rate dwell 0.6917, peak slew 40.0000 deg/s) - R2 CG/CB and buoyancy priors drawn but never injected (HG11) - R3 Gate 7 FDIR matrix not re-drawn under MC (HG12) - R4 cell geometry ASSUMED_RECONSTRUCTION (HG13) - R5 estimator streams NOT_IMPLEMENTED on the Gate 8 path - R6 power coverage PARTIAL, brownout branch never entered - R7 hardware NOT_CERTIFIED, actuator and sensor numerics TO_BE_IDENTIFIED - R8 upstream gate debt (Gate 4 waiver open, Gates 2 and 3 closed after three attempts).
- **Pareto vector:** tracking ACCEPTABLE (pooled cte_max P50 0.342 m, P95 0.565 m) - actuator margin **CRITICAL, effectively zero** - energy ACCEPTABLE with coverage factors (15.59 Wh/km, 6.88 A peak) - estimation **OPEN, no accuracy claim** - timing PARTIAL (budgets declared, never measured on a target) - safety PASS in simulation scope only (17/17 FDIR, 0 false alarms, 0 surface, 0 accommodation).
- **ICD boundary Mission -> Guidance -> Navigation -> Controller -> Actuator** tabulated with version, timestamp, sequence, validity/quality/integrity, heartbeat, stale rule, frame, unit and twin-log key per boundary. Local magnitude, rate and safety authority overrides mission; stale mission means fail-silent, never auto-surface and never auto-accommodation.
- **Procurement-ready requirement RANGES: 31 rows**, covering servo tau / rate / deadband / resolution / envelope, thruster lag and thrust, bus current, energy per km, source impedance and hold-up, DVL and IMU error against an ASSUMED dead-reckoning horizon grid, sensor cadence, transport delay, dropout, depth sensing, and compute period / deadline / WCET / jitter / overrun / utilisation. Every row is `DERIVED` from an `ASSUMED` or `TO_BE_IDENTIFIED` parent and carries unit, frame, source and limiting risk. **No vendor, brand, part number or purchase claim appears anywhere.** Two rows publish no number on purpose: `RR-06` (thruster variant time constants are not quoted in the permitted sources) and `RR-25` (mission, navigation and actuator-feedback cadences are unconstrained by any permitted source).
- **Selected ranges, for the record.** Servo tau 0.0125..0.100 s - servo rate 80..160 deg/s with a 40 deg/s hard floor - deadband plus backlash 0..0.10 deg - continuous thrust >= 16.865 N, peak >= 21.081 N - bus current continuous >= 8.256 A, peak >= 10.320 A - energy 18.708..23.385 Wh/km - source impedance <= 0.01453 ohm per volt of nominal bus - hold-up >= 100 ms - controller WCET <= 12.50 ms, jitter <= 2.50 ms - guidance WCET <= 37.50 ms, jitter <= 7.50 ms - transport delay <= 30 ms hard.
- **Reproducibility is evidenced, physical validity is not.** Exact nominal parity in 8/8 cells, bitwise reverse-order replay everywhere it was tested, the R10 fingerprint `n=153600.s1=19094896.s2=2901292177` reproduced across three code paths, and cross-process reproduction of the Gate 5B estimator. That proves the twin computes the same thing twice; it says nothing about whether what it computes is physically right, which is precisely what R1-R8 leave open.
- **EXTERNAL stops recorded explicitly:** hull and mechanical CAD NOT STARTED; vendor purchase FORBIDDEN; bench and HIL REQUIRED to convert the actuator, propulsion and compute rows into identified facts; wet trials REQUIRED to close R1 honestly; real-data system identification REQUIRED before any `ASSUMED` or `TO_BE_IDENTIFIED` label can become `IDENTIFIED`.
- **Preserved.** Production `continuous_path_tracking.m`, `controller_law.m`, `guidance_law.m` and `CODEX_VERTICAL_PLAN.md` are byte- and SHA-256-identical before and after this run (YES). No accepted evidence artifact was deleted, overwritten or re-labelled. No gain, law, path, threshold, shaper or feedforward was touched. No closed method was retried.
- **Evidence:** `suite_results/GATE9_SIMULATION_RC_ASSESSMENT.{md,mat,png}` plus `suite_results/GATE9_SIMULATION_RC_ASSESSMENT_qa.png` and `suite_results/GATE9_SIMULATION_RC_ASSESSMENT_run.log`. Visual QA verdict VISUAL_QA_PASS.
- **Next exact task (exactly one):** `GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001` - read-only fast whole-code embedded-readiness gap audit over A1-A13, every finding classified BLOCKER / TARGET_DEPENDENT / EXTERNAL_HIL / COSMETIC, evidence read and never re-executed. Its PASS bar is unchanged, so an audit over a FAIL RC will normally report BLOCKERs and not PASS.
- **STM32 adaptation remains FORBIDDEN** pending both the exact part number and board and an explicit disposition of every unresolved blocker. No processor is selected, guessed, recommended or implied. Simulation is not hardware certification (**NOT_CERTIFIED**).


---

## GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001 — embedded-transfer gap audit

**Verdict: FAIL. RC_NOT_GRANTED sustained. State: `AWAIT_STM32_EXACT_PART_NUMBER`.**

Read-only, fast whole-code embedded-transfer audit. No MATLAB, no execution, no repo scan, no runtime edit, no source edit, no candidate retry, no promotion, no label upgrade.

**Sources read: exactly 3, no repo scan** — `continuous_path_tracking.m` (10845 B, sha256 `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b`), `guidance_law.m` (14601 B, `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3`), `controller_law.m` (9402 B, `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890`). Every line citation in the report refers to these three files. No other file was source-reviewed; `init_parameters`, `underwater777_vehicle_dynamics`, `wrapToPi` and `interp1` are named only as call-graph entries and their contents are TO_BE_IDENTIFIED.

**Carried Gate 9 disposition, not re-derived:** RC_NOT_GRANTED; residual risks R1–R8 all OPEN; exact target ABSENT.

**Gate 9B PASS criteria and result:** zero software/safety BLOCKER — **NOT MET (14 distinct blocker classes)**; complete embedded handoff manifest — **NOT MET (42 rows; 15 TO_BE_IDENTIFIED, 6 ASSUMED/partial, 4 required units absent)**.

**Deployable core vs simulation.** Only `inertial_velocity_ned` (`continuous_path_tracking.m:228–244`) is transferable as-is: pure, fixed-size, allocation-free. `controller_law.m:59–179` is straight-line and bounded-cost and is the most transfer-ready control unit. `guidance_law.m:52–279` plus helpers `:283–394` are the control law proper but are O(n) per tick in an unbounded `path`. `continuous_path_tracking.m:1–226` is simulation harness (fixed-horizon loop `:71`, host variable-step integrator `:101`, ~30 whole-mission log buffers `:20–63`, stdout in-loop `:104–106,183–184`, 28 export globals `:189–225`). `underwater777_vehicle_dynamics` is plant, not read. **The repository does not currently contain a separable deployable control core; the gap is architectural and is not closed by choosing a target.**

**Findings: 71 total** — 51 BLOCKER (14 distinct classes), 8 TARGET_DEPENDENT, 2 EXTERNAL_HIL, 10 COSMETIC (6 of them positive). Labels: 34 IMPLEMENTED, 34 DERIVED, 0 ASSUMED in findings, 11 TO_BE_IDENTIFIED.

**The 14 software/safety BLOCKER classes (all host-side, all target-independent):**
- **B01** no deterministic init/step/reset API; `persistent` survives across missions (`guidance_law.m:21,68–80`; `controller_law.m:23–25,151–154`).
- **B02** navigation layer absent — every control input is plant truth (`continuous_path_tracking.m:72–94`), including sideslip `beta` (`guidance_law.m:168–173`) and flight-path `gamma_actual` (`:210`); code-level form of carried R5.
- **B03** mission and actuator layers are not interfaces (`guidance_law.m:1`; `controller_law.m:1`; `continuous_path_tracking.m:96–98`).
- **B04** global parameter/diagnostic coupling; functions mutate their own configuration (`guidance_law.m:13–19,27–34`; `controller_law.m:12–30,38–57`; harness rewrites both rate globals at `continuous_path_tracking.m:9–17`); plant derivatives `Muw`/`Muuds` and fitted constants hard-coded in the controller (`controller_law.m:52–54,111–112`); not reentrant.
- **B05** dynamic/variable-size memory: run-length log allocation (`continuous_path_tracking.m:19–63`), reallocation on the fault path (`:107–114`), unbounded `path` with per-tick `zeros(n,1)` (`guidance_law.m:54,62,285`), `nargout`-dependent 27-field struct (`controller_law.m:181–213`).
- **B06** host-only step driver: `ode45` with anonymous handle (`continuous_path_tracking.m:101`), `try/catch` + `ME.message` (`:100–106`), in-loop `fprintf` (`:104–106,183–184`).
- **B07** non-base-language calls inside the core: `wrapToPi` (`guidance_law.m:164,173,180,212`; `controller_law.m:61`), `interp1(...,'extrap')` (`controller_law.m:222`), `find(...,1,'last'/'first')` (`guidance_law.m:324–327,361–362`).
- **B08** NaN used as control-flow sentinel (`guidance_law.m:71–73,79,161,177,239`); no floating-point format or mode policy anywhere.
- **B09** unbounded numeric ranges: never-rewrapped heading accumulator (`guidance_law.m:180,254,263`), gain-dependent integrator limits up to ~1.4e5 rad (`controller_law.m:83,102`), curvature reciprocal to 1e4 m (`guidance_law.m:135,150`).
- **B10** **highest severity** — no parameter validity check and no input validity check. Thirteen unguarded globals (`controller_law.m:12–17`) used at `:63,66,70,82–83,86,102,106,133,136,139,178–179`; if `init_parameters` has not run, `max(min(x,[]),[])` yields empty and an **empty actuator command propagates silently** instead of a fault or a safe state. No NaN/Inf/range check on any navigation input, and no reset to recover from a poisoned integrator. Unbounded trim extrapolation at `:222` can consume full elevator authority off-table.
- **B11** sample time owned by globals (`controller_law.m:56–58`; `guidance_law.m:32–36`); rate ratio rounded without check (`continuous_path_tracking.m:69,84`) which desynchronises `z_e_i` (`guidance_law.m:194`), the pitch rate limit (`:258`) and `pitch_ref_dot` (`:265`); unguarded ZOH with no hold-age (`continuous_path_tracking.m:68`); nine hard-coded filter alphas that bake in the tuning sample rate (`guidance_law.m:134,147,164,202,213,222,226,243,252`). The correct pattern already exists at `controller_law.m:57,76`.
- **B12** anti-windup computed before the rate limiter and therefore blind to rate saturation (`controller_law.m:133,140–142,149–152`) — with a 40 deg/s limit, rate saturation is the likely dominant limiter; guidance depth integrator has no anti-windup under three cascaded downstream saturations (`guidance_law.m:194–195,204,229,256–261`); no bumpless transfer; saturation flag exists only in the optional debug struct (`controller_law.m:202`), invisible to the production three-output call (`continuous_path_tracking.m:91`); rudder saturation never reported back to guidance (carried R1 visible as a missing feedback path).
- **B13** no FDIR interface, no watchdog kick, no deadline/overrun/jitter detection, no safe state, no timing instrumentation of any kind; the only fault-shaped construct prints, truncates and breaks (`continuous_path_tracking.m:100–116`); guidance absorbs implausible progress silently (`guidance_law.m:95–105`).
- **B14** no transport schema at any of the four existing boundaries — version, timestamp, sequence, validity, heartbeat and stale rule are absent everywhere; log keys are bare global names (`continuous_path_tracking.m:189–225`; `guidance_law.m:231–238`; `controller_law.m:156–176`); sign and frame conventions survive only in comments (`controller_law.m:3–4,73–74`, `elevator_sign` `:17,46,107,136`; `guidance_law.m:192–193,201`), and losing them is a pitch-divergence hazard. Twin equivalence is untestable: all four preconditions (identical initial state, identical timed inputs, identical parameters, stable log keys) fail.

**TARGET_DEPENDENT (8):** heap budget, in-loop `exp` (`controller_law.m:76`), curvature dynamic range, host `eps` as divisor guard (`:66`), intra-frame scheduling/jitter/phase, transport medium and encoding, stack budget (favourable: recursion-free, depth ≤ 3), absolute WCET/footprint/achievable rate. **EXTERNAL_HIL (2):** actuator dynamics absent from the read set (`continuous_path_tracking.m:96–98`); actuator and sensor numerics require a bench. **Positive findings:** control path is RNG-free and clock-free and therefore bit-reproducible on a fixed FP configuration; units are internally SI-consistent with no dimensional defect found; magnitude saturation, rate limiting and back-calculation anti-windup are all present; `controller_law` is recursion-free and straight-line.

**Recommended host-side fix order (recommendation only, not an authorisation to edit):** B10 → B01 → B04 → B11 → B14 → B12 → B13 → B05/B07/B08/B09 → B02/B03 → B06.

**Constraint restated.** Target work remains **FORBIDDEN** until the user supplies the **exact target part number and board** *and* each of B01–B14 is individually dispositioned (fixed, formally waived with recorded residual risk, or deferred with an owner). A part number alone does not unblock, because all 14 blockers are host-side. **No MCU family, vendor, brand, board or part number is named in this record.** Simulation is not hardware certification: **NOT_CERTIFIED**.

**Integrity.** Production sources verified **UNTOUCHED** (hashes above, identical before and after). `suite_results/CODEX_VERTICAL_PLAN.md` **UNTOUCHED — not read, not written** (43101 B, sha256 `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c`). No file deleted, renamed, moved, truncated or overwritten; all evidence preserved. Writes: created `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`; append-only to `suite_results/AUV_REALIZATION_READINESS_PLAN.md`, `suite_results/AUTONOMOUS_EXECUTION_POLICY.md`, `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md`, `suite_results/PITCH_CONTROL_RESEARCH_LOG.md`, `suite_results/STATE_SPACE_MODEL_AUDIT.md` — each appended without being read, each receiving this identical block.

Full report: `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`.

<!-- APPEND_MARKER:CG_PRE0_TOOLCHAIN_CAPABILITY_001 -->

## Append: CG_PRE0_TOOLCHAIN_CAPABILITY_001 — MATLAB→C++ pretarget capability gate

**Date:** 2026-08-10 01:59 | **Class:** read-only toolchain capability gate | **MATLAB runs:** 1 | **Install/config/source edits:** NONE | **Repo scan:** NONE | **Production/CODEX:** untouched | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** MATLAB R2025b PCWIN64 bridge OK. MATLAB Coder PRESENT+LICENSE_AVAILABLE with resolvable `codegen`/`coder` APIs. Simulink Coder / Embedded Coder classic license features test true (`Real-Time_Workshop`, `RTW_Embedded_Coder`) but products MISSING from `ver`. C/C++ MEX compiler selected=0 installed=0 → executable codegen BLOCKED. STM32-relevant add-ons=0 (MISSING/HARDWARE_BLOCKED). Tiny Coder smoke SKIPPED (exact reason: would require mex/compiler setup, forbidden). C: avail before 4565749760 B (4.25 GiB) → after MATLAB 4554731520 B; small text evidence only.

**Sources read: exactly 3** — `GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`, `AUTONOMOUS_EXECUTION_POLICY.md`, `AUV_REALIZATION_READINESS_PLAN.md`. Gate 9B FAIL / 14 BLOCKERs / `AWAIT_STM32_EXACT_PART_NUMBER` carried, not re-opened.

**Evidence:** `suite_results/CG_PRE0_TOOLCHAIN_CAPABILITY.md` · status board `suite_results/CG_CODEGEN_STATUS.md`.

**Next exact task (exactly one):** `CG0_CODEGEN_BOUNDARY_INVENTORY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG0_CODEGEN_BOUNDARY_INVENTORY_001 -->

## Append: CG0_CODEGEN_BOUNDARY_INVENTORY_001 — codegen boundary inventory

**Date:** 2026-08-10 02:12 | **Class:** read-only source inventory | **MATLAB runs:** 0 | **Source edits:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Scoped 178 root `.m` (0 `.mlx`/`.slx`/`.sldd`); first-level `shadow_r10/` empty of sources. Excluded `suite_results`/dot/git/cache. Classes: DEPLOY 2 · SHARED_SUPPORT 2 · SIMULATION_ONLY 156 · ARCHIVE_REJECTED 18 · HARDWARE_BLOCKED(files) 0. Full review: `controller_law.m`, `guidance_law.m`, `continuous_path_tracking.m`, `init_parameters.m`, `underwater777_vehicle_dynamics.m`; remainder header/call → `NEEDS_CG1_REVIEW`. Deploy graph: cpt → init_parameters / inertial_velocity_ned / guidance_law / controller_law / ode45(plant). Nav/EKF, Mission, FDIR, allocation, actuator feedback = evidence/harnesses only (not production runtime). Compiler MISSING remains PARTIAL; static CG1 allowed.

**Evidence:** `suite_results/CG0_CODEGEN_BOUNDARY.md` · `suite_results/CG0_CODEGEN_MANIFEST.csv` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001 -->

## Append: CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001 — static controller Coder compat

**Date:** 2026-08-10 02:22 | **Class:** bounded static MATLAB Coder audit (accepted controller only) | **MATLAB runs:** 0 | **Source edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** `controller_law.m` scalar core (`:59–179`) directly portable (sin/cos/exp/sign/clamps); lift-as-is blocked by globals + un-resettable persistent, variable nargin/nargout dbg, `wrapToPi`, unbounded `interp1` extrap/trim tables, empty-unguarded gains/limits, dt-from-global. Fixed-signature future API specified only (`Params`/`State`/`Input`/`Output`/`Debug` + init/reset ownership + finite/range guards); **not implemented**. Gains frozen; rejected methods closed. Compiler/tool install remains deferred.

**Sources read: exactly 3** — `controller_law.m`, `suite_results/CG0_CODEGEN_BOUNDARY.md`, `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`.

**Evidence:** `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001 -->

## Append: CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001 — static guidance Coder compat

**Date:** 2026-08-10 02:25 | **Class:** bounded static MATLAB Coder audit (accepted guidance only) | **MATLAB runs:** 0 | **Source edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** `guidance_law.m` LOS/course/β/pitch/Tur4A–5B scalar algebra portable after owned wrap; lift-as-is blocked by 19 globals + 13 un-resettable persistents, variable nargin defaults, unbounded `path` + per-tick `zeros(n,1)`, `find`/`sum` O(n) helpers, toolbox `wrapToPi`, NaN init sentinels, dt-from-global, no path validity/seq. Fixed-signature future API specified only (`Params`/`State`/`Input`/`Output`/`Debug` + bounded path capacity, segment/angle-wrap ownership, finite/range guards); **not implemented** — await golden parity. Accepted LOS tuning frozen; rejected γ-structural/LADRC/INDI/crab-current-FF/polyline closed. Compiler/tool install remains deferred.

**Sources read: exactly 3** — `guidance_law.m`, `suite_results/CG0_CODEGEN_BOUNDARY.md`, `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`.

**Evidence:** `suite_results/CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY.md` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001 -->

## Append: CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001 — nav/FDIR runtime boundary

**Date:** 2026-08-10 02:42 | **Class:** bounded static runtime-boundary audit (exactly 3 nav/FDIR sources) | **MATLAB runs:** 0 | **Source edits:** NONE | **Repo scan:** NONE | **Harness inspect:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** Reusable cores: 18-state propagate/Joseph/admit order (baseline), optional USBL + health-only availability FSM (availability fork), rudder B2 residual+persistence latch (monitor). SIMULATION_ONLY: action-string dispatch, batch N-logs, cell/dynamic structs, innov growth, metrics/gates/truth scoring, `eig`/`error`/`assert`. Lift-as-is **FAIL** — files do **not** DEPLOY. Spec only: `nav_init/reset/propagate/update/output`, `availability_step`, `rudder_fdir_init/reset/step` + Params/State/Input/Output/Health; preserve truth firewall, Joseph form, deterministic order, FDIR latch; thresholds ASSUMED/NOT_CERTIFIED. Compiler/tool install deferred.

**Sources read: exactly 3** — `navigation_multirate_ekf_baseline.m`, `navigation_multirate_ekf_availability.m`, `isolated_online_rudder_residual_monitor.m`.

**Evidence:** `suite_results/CG1C_NAV_FDIR_RUNTIME_BOUNDARY.md` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001 -->

## Append: CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001 — controller golden corpus

**Date:** 2026-08-10 03:00 | **Class:** SIMULATION_ONLY MATLAB golden capture (accepted controller) | **MATLAB runs:** 1 | **Source edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Bounded deterministic corpus `CG2A_CONTROLLER_GOLDEN_V1` (schema 1): N=100 steps × 13 finite inputs × 30 Debug fields; 13 coverage cases (cold nominal; U={1,1.5,2}; yaw wrap ±π; climb/descent; rudder/elevator mag+40°/s slew; pitch I/AW; roll-rate damp; nonzero w @ accepted λ_muw_ff=0). Forced accepted `dt=0.025`. Dual replay with `clear controller_law` → `isequaln` outputs+Debug. Finite + mag/slew checks PASS. `controller_law.m` / `init_parameters.m` fingerprints UNTOUCHED. **C++ parity NOT CLAIMED.** Compiler/tool install deferred.

**Sources read: exactly 3** — `controller_law.m`, `init_parameters.m`, `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md`.

**Evidence:** `suite_results/CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE.md` · `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat` · `suite_results/CG2A_CONTROLLER_GOLDEN_V1.json` · `run_cg2a_controller_golden_parity_capture.m`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001 -->

## Append: CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001 — explicit-state controller prototype

**Date:** 2026-08-10 03:14 | **Class:** SIMULATION_ONLY MATLAB explicit-state prototype + golden parity | **MATLAB runs:** 1 | **Production edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Isolated fixed-ABI prototype `controller_codegen_init/reset/step` (Params from golden snapshot only; deterministic zero State). Replayed all 100 golden steps: exact `isequaln` on every Output+Debug field; dual reset replay A==B; mag/slew bounds OK (40°/s). Label `DEPLOY_CANDIDATE/NOT_IN_PRODUCTION`. TEMPORARY_BLOCKER retained: `wrapToPi`, fixed-table `interp1` linear/extrap. `controller_law.m` fingerprint UNTOUCHED. **C++ parity NOT CLAIMED.** Compiler/tool install deferred.

**Sources read: exactly 3** — `controller_law.m`, `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md`, `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat`.

**Evidence:** `suite_results/CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE.md` · `controller_codegen_{init,reset,step}.m` · `run_cg2a_controller_explicit_state_prototype.m`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001 -->

## Append: CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001 — guidance golden corpus

**Date:** 2026-08-10 03:29 | **Class:** SIMULATION_ONLY MATLAB golden parity capture | **MATLAB runs:** 1 | **Production edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Bounded deterministic corpus `CG2B_GUIDANCE_GOLDEN_V1` (schema 1): N=102 steps × full 8-input `guidance_law` calls × 6 outputs × 11 `last_*` diagnostics; 16 coverage cases (cold/open straight; U_h∈{1,1.5,2}; ±CTE/±depth; multi-seg/curvature; closed seam; near-end slowdown; progress back-snap; yaw wrap ±π; sway β; Tur4A/5A/5B inputs @ accepted K_zdot=0,K_gamma=0,α̂ off). Paths stored padded MAX=32×3 + n_path/path_id; legacy calls use active rows. Forced accepted `dt_guidance=0.075`. Dual replay with identical `reset_before` + `clear guidance_law` → `isequaln` outputs+diagnostics. Finite + range/slew/progress checks PASS. `guidance_law.m` / `init_parameters.m` fingerprints UNTOUCHED. **C++ parity NOT CLAIMED.** Compiler/tool install deferred.

**Sources read: exactly 3** — `guidance_law.m`, `init_parameters.m`, `suite_results/CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY.md`.

**Evidence:** `suite_results/CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE.md` · `suite_results/CG2B_GUIDANCE_GOLDEN_V1.mat` · `suite_results/CG2B_GUIDANCE_GOLDEN_V1.json` · `run_cg2b_guidance_golden_parity_capture.m`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

