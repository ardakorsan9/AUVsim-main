# REAL_TIME_POWER_INTEGRITY_CONTRACT - REAL_TIME_POWER_INTEGRITY_CONTRACT_001

**Date:** 2026-08-08  
**Gate:** 6B (real-time / power-integrity contract, subset of Gate 6) - **isolated** simulation/interface gate  
**Class:** isolated executable timing/power contract + event simulation  
**MATLAB runs:** 1 (single invocation, no retry) - **production edits:** NONE - **CODEX_VERTICAL_PLAN:** untouched  
**Component neutrality:** no vendor, board, battery, or bus voltage in volts is claimed; power is per-unit (pu)  
**Physical / hardware readiness:** **NOT_CERTIFIED** (simulation-only delay/power envelopes)

## 0. Verdict

**PASS** - 13 of 13 declared hard gates pass.

Gate 6B is **PASS** on its declared hard gates. Gate 7 (mission manager / fail-silent) is unlocked as the *next gate*, still `NOT_CERTIFIED` and still requiring Gates 3-6 envelopes and HIL for any real safe-mode policy.

Simulation PASS is **not** hardware certification. Every timing number below is produced by a
deterministic scheduler simulation with **ASSUMED** execution-time, delay, jitter and power models.

## 1. Sources (strict, exactly 3)

| # | Path | Role |
|---|------|------|
| 1 | `suite_results/AUTONOMOUS_EXECUTION_POLICY.md` | Gate 6B hook fields, prompt/source/MATLAB bounds, Pareto vector, promotion + honesty rules |
| 2 | `suite_results/AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md` | Layering, clocks (40 Hz FIXED / 13.33 Hz DERIVED), header/seq/t_mono, stale + fail-silent, no auto-surface |
| 3 | `suite_results/PROPULSION_POWER_COMPUTE_PARITY_FIX.mat` | Accepted Gate 6 power/parity evidence (inherited power anchors only) |

Source 3 fingerprint: `n=3274552.s1=115460397.s2=2621211975` (read-only).

Inherited Gate 6 anchors (**not re-measured here**, used only to scale the per-unit load proxy and to report energy context):

| Anchor | Value | Label |
|--------|-------|-------|
| `P_lo_mean` | 16.5468 | Gate 6 accepted evidence (inherited) |
| `P_hi_mean` | 28.3659 | Gate 6 accepted evidence (inherited) |
| `P_lo_p95` | 16.636 | Gate 6 accepted evidence (inherited) |
| `P_hi_p95` | 28.5189 | Gate 6 accepted evidence (inherited) |
| `E_lo_Wh` | 0.0941988 | Gate 6 accepted evidence (inherited) |
| `E_mid_Wh` | 0.127841 | Gate 6 accepted evidence (inherited) |
| `E_hi_Wh` | 0.161484 | Gate 6 accepted evidence (inherited) |
| `I_hi_24V` | 1.18829 | Gate 6 accepted evidence (inherited) |
| `I_hi_48V` | 0.594144 | Gate 6 accepted evidence (inherited) |
| `max_metric_diff` | 0 | Gate 6 accepted evidence (inherited) |
| `max_sig_diff` | 0 | Gate 6 accepted evidence (inherited) |

No other repository file was read. Production files were **fingerprinted only** (byte checksum), never parsed.

## 2. Gate 0 hygiene - frames / signs freeze and preflight

| Item | Value | Label |
|------|-------|-------|
| Position frame | NED inertial [m]; z positive DOWN (depth = +z) | `INTERFACE_SPECIFIED` |
| Body streams | BODY angular rates p,q,r [rad/s]; BODY velocity u,v,w [m/s] | `INTERFACE_SPECIFIED` |
| Attitude | phi,theta,psi [rad] (report/plots in deg where labelled) | `INTERFACE_SPECIFIED` |
| Actuators | delta_e, delta_r [deg] signed per production convention; thrust in [0,1] pu | `INTERFACE_SPECIFIED` |
| Source reference | AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md Sec.4 (SI, NED/BODY) | - |
| Free volume at start | 4.35 GiB | >= 3 GiB minimum met; **below the preferred 5 GiB** - recorded as disk-pressure debt |
| Cache cleanup | none performed (no verified-inactive cache identified without a repo scan) | process |
| Accepted evidence | preserved; no accepted MD/MAT/PNG deleted or rewritten | process |

## 3. Timing contract (declared BEFORE execution)

Scheduler model: **single compute core, fixed-priority, preemptive**, micro-tick 0.5 ms (quantisation declared).
Priority 1 = highest. A dedicated **safety watchdog** task sits above the controller so that a fully
starved controller cannot freeze the actuator command path.

| # | Task | Period | Rel. deadline | WCET **budget** (requirement) | Jitter bound | Prio | ZOH / buffer | Overrun action | Rate label |
|---|------|--------|---------------|-------------------------------|--------------|------|--------------|----------------|------------|
| 1 | `watchdog_safety` | 25 ms | 25 ms | 2.5 ms | 1 ms | 1 | direct safe-hold authority, no ZOH consumer | never skipped by design (highest priority); miss => hard fault flag | ASSUMED (safety monitor, harness-declared) |
| 2 | `controller` | 25 ms | 25 ms | 12.5 ms | 2.5 ms | 2 | ZOH of guidance refs, buffer depth 1 | abort instance, hold last actuator command (ZOH); 3 consecutive => safe-hold | FIXED 40 Hz / 25 ms (ICD Sec.3 interface target) |
| 3 | `guidance` | 75 ms | 75 ms | 30 ms | 5 ms | 3 | ZOH to controller for N = round(0.075/0.025) = 3 ticks | skip instance, hold last refs; 2 consecutive => refs stale => safe-hold | DERIVED 13.33 Hz / 75 ms (ICD Sec.3) |
| 4 | `navigation` | 25 ms | 25 ms | 5 ms | 2.5 ms | 4 | ZOH latest-valid sample, buffer depth 1 | drop sample, mark nav stale | TO_BE_IDENTIFIED (sim placeholder 25 ms, ASSUMED) |
| 5 | `mission` | 1000 ms | 1000 ms | 10 ms | 10 ms | 5 | hold-last-valid, buffer depth 2, stale timeout 3.0 s | no publication => age grows => stale => fail-silent hold last safe refs | TO_BE_IDENTIFIED (sim placeholder 1000 ms, ASSUMED) |

- **WCET semantics:** `REQUIREMENT_BUDGET (not a measured WCET; no measurement-based WCET is claimed)`. Response times reported later are *simulated* response times under an
  ASSUMED execution-time model; they are **not** a measured WCET and must not be promoted to one.
- **Controller 25 ms is FIXED** (ICD Sec. 3 interface target for the mission-ready twin).
- **Guidance 75 ms is DERIVED**, with `N = round(0.075/0.025) = 3` controller ticks of ZOH.
- **Mission / navigation / actuator-feedback rates remain `TO_BE_IDENTIFIED`.** The harness uses
  sim placeholders (nav 25 ms, mission 1000 ms) that are explicitly `ASSUMED` and carry **no**
  identification claim; they exist only so the event simulation is executable.

### 3.1 Legacy 37.5 ms reconciliation (ASSUMED, evidence-only)

The readiness lineage records an older `dt_controller = 0.0375` s default (`ASSUMED`); the ICD records
40 Hz / 25 ms as the `FIXED` interface target. This gate **reconciles them as evidence only**:

| Item | Position |
|------|----------|
| 25 ms / 40 Hz | `FIXED` interface target - used for every gate-bearing case |
| 37.5 ms / 26.67 Hz | `ASSUMED`, **evidence-only** legacy note - simulated as case `L37` for comparison |
| Production effect | **NONE.** No production file was edited; `continuous_path_tracking.m`, `controller_law.m`, `guidance_law.m` are byte-identical (Sec. 8) |
| Promotion | The legacy value is **not** promoted, and the FIXED target is **not** re-opened, by this gate |

`L37` is reported for information. It does **not** carry the verdict: hard gates HG4/HG10 are keyed to the 25 ms FIXED target.

## 4. Power-integrity contract (per-unit, component-neutral)

| Field | Value | Label |
|-------|-------|-------|
| Nominal bus | 1.00 pu (no volts claimed) | `INTERFACE_SPECIFIED` |
| Undervoltage warning | 0.92 pu | `ASSUMED` |
| Brownout / safe-hold trigger | 0.85 pu | `ASSUMED` |
| Compute-reset floor | 0.75 pu | `ASSUMED`, **NOT_EXERCISED** in this gate |
| Source-impedance sag | 0.040 pu sag per pu current | `ASSUMED` |
| Load model | P = 0.12 + 0.88 * thrust^1.5 [pu] | `ASSUMED` |
| Compute throttle | x0.90 below warn, x0.75 below brownout | `ASSUMED` (couples power sag into timing) |
| Undervoltage debounce | 100 ms | `ASSUMED` |
| Safe-hold exit dwell | 1.00 s of clean conditions | `ASSUMED` |
| Mission stale timeout | 3.00 s | `ASSUMED` (mission rate is `TO_BE_IDENTIFIED`) |

Brownout propagation path (simulated): `V_bus(pu) -> undervoltage debounce -> VehicleHealth -> safe-hold latch -> bounded actuator ramp`.
Safe-hold action set is closed and declared: `{hold last safe refs, fins ramp to neutral at <= 40 deg/s, thrust ramp to 0 at <= 0.50 pu/s}`.
**No auto-surface, no auto-accommodation, no depth command** is emitted by any path in this harness (HG9 counts them; both counters are structurally and observably zero).

## 5. Declared grids (frozen before execution, all `ASSUMED`)

| Grid | Values |
|------|--------|
| Transport delay | {0, 15, 30} ms |
| Transport jitter | {0, 2.5, 5} ms (in-order delivery assumed; no reordering) |
| Release jitter scale | {0, 1} x declared per-task jitter bound |
| CPU load multiplier | {1, 1.6, 2.2} x nominal execution model |
| Interference (burst) | {0, 0.35, 0.6} fraction of core stolen by higher-priority ISR/DMA proxy |
| Brownout dip | {0.08, 0.15, 0.18} pu |
| Legacy controller period | 37.5 ms (evidence-only) |

Horizon 30 s per case; 7 named cases x 2 independent replays + 9 delay x jitter sweep points.

## 6. Cases and per-case results

| Code | Case | Delay | Tx jitter | Load | Interf. | Dip | Ctrl period |
|------|------|-------|-----------|------|---------|-----|-------------|
| `NOM` | NOMINAL | 0 ms | 0.0 ms | x1.0 | 0.00 | 0.00 pu | 25 ms |
| `D15` | DELAY\_15MS\_JITTER | 15 ms | 2.5 ms | x1.0 | 0.00 | 0.00 pu | 25 ms |
| `D30` | DELAY\_30MS\_JITTER | 30 ms | 5.0 ms | x1.0 | 0.00 | 0.00 pu | 25 ms |
| `OVL` | OVERLOAD\_BURST | 15 ms | 2.5 ms | x2.2 | 0.60 | 0.00 pu | 25 ms |
| `BRN` | BROWNOUT\_RECOVERY | 15 ms | 2.5 ms | x1.0 | 0.00 | 0.18 pu | 25 ms |
| `STL` | MISSION\_STALE\_FAIL\_SILENT | 15 ms | 2.5 ms | x1.0 | 0.00 | 0.00 pu | 25 ms |
| `L37` | LEGACY\_37P5MS\_ASSUMED | 15 ms | 2.5 ms | x1.0 | 0.00 | 0.00 pu | 37.5 ms |

| Code | CTRL resp p95 / max [ms] | CTRL miss | GUID miss | WD miss | e2e p95 / max / bound [ms] | V_min [pu] | safe-hold [s] | detect lat [ms] | outputs bounded |
|------|--------------------------|-----------|-----------|---------|----------------------------|------------|---------------|-----------------|-----------------|
| `NOM` | 7.5 / 7.5 | 0 | 0 | 0 | 82.0 / 82.5 / 125.0 | 0.985 | 0.00 | n/a | OK |
| `D15` | 7.4 / 8.0 | 0 | 0 | 0 | 98.3 / 100.9 / 145.0 | 0.985 | 0.00 | n/a | OK |
| `D30` | 7.4 / 8.0 | 0 | 0 | 0 | 114.9 / 118.1 / 160.0 | 0.985 | 0.00 | n/a | OK |
| `OVL` | 15.2 / 16.0 | 200 | 67 | 0 | 155.6 / 5178.3 / 145.0 | 0.977 | 6.47 | 12 | OK |
| `BRN` | 7.5 / 9.6 | 0 | 0 | 0 | 98.3 / 125.4 / 145.0 | 0.803 | 2.07 | 79 | OK |
| `STL` | 7.4 / 8.0 | 0 | 0 | 0 | 98.3 / 100.9 / 145.0 | 0.976 | 7.00 | 20 | OK |
| `L37` | 7.0 / 8.0 | 0 | 0 | 0 | 98.4 / 100.3 / 170.0 | 0.985 | 0.00 | n/a | OK |

`detect lat` = worst of {undervoltage -> safe-hold, mission-stale -> safe-hold, 3rd consecutive controller
miss -> safe-hold} for that case; `n/a` where the case injects no fault. The `e2e max` figure for `OVL` is
reference **staleness** measured while the controller is starved and safe-hold owns the output path - it is
deliberately reported, not suppressed, and it is not a tracking-loop latency.

Deadline accounting for all 5 tasks x 7 cases closes exactly as released = completed + missed + in-flight-at-horizon (HG3).

### 6.1 Per-case PASS/FAIL against the case expectation declared before execution

| Code | Expectation (declared a priori) | Observed | Result |
|------|--------------------------------|----------|--------|
| `NOM` | zero misses, zero safe-hold, zero stale, bounded outputs | miss=0, hold=0.00 s, stale=0 | PASS |
| `D15` | no CPU deadline loss, e2e within bound, no safe-hold | e2e max=100.9 ms (bound 145.0), miss=0, hold=0.00 s | PASS |
| `D30` | no CPU deadline loss, e2e within bound, no safe-hold | e2e max=118.1 ms (bound 160.0), miss=0, hold=0.00 s | PASS |
| `OVL` | misses occur and are counted; safe-hold <= 2 periods after 3rd consecutive miss; watchdog never misses; recovery | ctrl miss=200, gap=3 ms, wd miss=0, recovered=1 | PASS |
| `BRN` | V dips below 0.85 pu, undervoltage -> safe-hold within debounce+2 periods, recovery, no auto-surface | V_min=0.803, detect=79 ms, hold=2.07 s, surface_cmds=0 | PASS |
| `STL` | heartbeat loss -> stale within <= 2 periods of the 3.0 s timeout -> fail-silent hold -> recovery on heartbeat return | detect=20 ms, hold=7.00 s, recovered=1 | PASS |
| `L37` | **evidence-only**: report timing deltas vs the 25 ms FIXED target; must stay deterministic and bounded; carries no verdict | resp max=8.0 ms, miss=0, bounded=OK | INFO |

## 7. Pareto tracking vector (policy Sec. 5)

| Axis | Value | Note |
|------|-------|------|
| **Tracking** | **N/A** | Deliberate: this gate contains no production plant. The internal first-order surrogate exists only to generate bounded deterministic command traffic; no CTE/attitude/depth claim is made or implied. |
| **Actuator margin** | max abs(delta_e) 8.27 deg (55% of 15), max abs(delta_r) 6.84 deg (27% of 25), peak rate util 100% | bounded in every case incl. safe-hold transitions |
| **Energy** | surrogate load P mean 0.320 pu / peak 0.365 pu | absolute watts are **inherited Gate 6 evidence only**, not re-measured here |
| **Estimation** | **N/A** | Gate 5 truth/measured/estimated streams are not instantiated in this harness; nav is a placeholder publisher with `TO_BE_IDENTIFIED` rate |
| **Timing** | period/deadline/jitter/overrun fully accounted, Sec. 3 + Sec. 6 | primary axis of this gate |
| **Safety** | safe-hold entries 1 (OVL), 1 (BRN), 1 (STL); auto-surface violations **0**; mission-limit-widening events **0** | local authority wins in all cases |

No axis was improved by hiding a loss on safety or on a hard envelope.

## 8. Hard gates (declared a priori) and integrity

| Gate | Requirement | Result | Detail |
|------|-------------|--------|--------|
| `HG1` | Deterministic replay: independent re-execution (reverse order) yields identical case hash | **PASS** | 7/7 case hashes identical |
| `HG2` | Monotonic seq (+1) and strictly increasing t_mono on every emitted output | **PASS** | all cases monotonic |
| `HG3` | Deadline accounting closes: released == completed + missed + in-flight-at-horizon, every task, every case | **PASS** | closure exact for 5 tasks x 7 cases; 0 job(s) still executing at the 30 s horizon |
| `HG4` | NOMINAL: zero deadline misses (WD/CTRL/GUID), zero safe-hold, zero stale (no false positives) | **PASS** | miss=[0 0 0] hold=0.000 s stale=0 |
| `HG5` | Bounded outputs: magnitude and rate envelopes never violated, including mode transitions | **PASS** | magnitude violations=0, rate violations=0 (all cases) |
| `HG6` | Mission cannot raise limits: every out-of-envelope mission hint clamped by guidance | **PASS** | clamp events=375, unclamped=0, max abs(pitch_ref)=15.000 deg (limit 15.0) |
| `HG7` | Stale detection: mission heartbeat loss detected <= 2 controller periods after timeout, fail-silent hold, recovery observed | **PASS** | detect latency=0.0203 s (bound 0.0500), hold=7.00 s, recovered=1 |
| `HG8` | Overrun: CPU overload produces counted misses, safe-hold within 2 periods of 3rd consecutive miss, watchdog never misses, recovery observed | **PASS** | ctrl misses=200, wd misses=0, action gap=0.0030 s, recovered=1 |
| `HG9` | Brownout: undervoltage -> health -> safe-hold within debounce+2 periods, recovery observed, zero auto-surface / auto-accommodation | **PASS** | V_min=0.803 pu, detect=0.0785 s (bound 0.1500), hold=2.07 s, recovered=1, surface_cmds=0 |
| `HG10` | Delay/jitter envelope: 15/30 ms transport + jitter stays inside declared end-to-end latency bound and consumes no CPU deadline | **PASS** | D15: e2e_max=100.9 ms (bound 145.0), ctrl miss=0; D30: e2e_max=118.1 ms (bound 160.0), ctrl miss=0; |
| `HG11` | Production + CODEX_VERTICAL_PLAN byte-identical (pre/post fingerprints) | **PASS** | 6 files fingerprinted, 0 changed |
| `HG12` | Artifacts written and total artifact footprint < 300 MiB | **PASS** | mat=0.40 MiB, png=0.14 MiB |
| `HG13` | Label honesty (structural): WCET fields are requirement budgets; no measured-WCET and no IDENTIFIED hardware claim emitted | **PASS** | wcet_claim = REQUIREMENT_BUDGET; mission/nav/actuator-feedback rates remain TO_BE_IDENTIFIED |

Two gates are deliberately **structural self-checks** and are labelled as such rather than dressed up as
discoveries: **HG5** verifies that no path (controller, watchdog, safe-hold entry and exit) bypasses the
single rate/magnitude-limited emission choke point where boundedness is enforced by construction, and
**HG13** verifies that the report emits budgets rather than measured-WCET or hardware-identification claims.
**HG1** proves reproducibility inside one session, not cross-platform bit-determinism.

### 8.1 Production fingerprints (byte checksum: length + byte sum + position-weighted modular sum; not cryptographic)

| File | Pre | Post | Identical |
|------|-----|------|-----------|
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073395` | `n=10845.s1=886194.s2=515073395` | YES |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | `n=9402.s1=732890.s2=3334742186` | YES |
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382500` | `n=14601.s1=1095745.s2=3464382500` | YES |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | `n=6065.s1=426918.s2=1254438441` | YES |
| `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990744` | `n=11604.s1=883372.s2=792990744` | YES |
| `suite_results/CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810110` | `n=43101.s1=4310210.s2=3268810110` | YES |

### 8.2 Host runtime vs WCET (explicitly distinguished)

| Quantity | Value | Meaning |
|----------|-------|---------|
| Host wall-clock runtime of this MATLAB invocation | 47.03 s | Desktop host, non-real-time OS, includes plotting and file I/O. **Carries no timing evidence for the target** and is **not** a WCET. |
| Controller WCET **budget** | 12.5 ms | A **requirement** allocated in Sec. 3, to be verified on target by measurement + analysis (EXTERNAL). |
| Controller simulated response max | 7.5 ms (NOM) | Output of the ASSUMED execution-time model, not a measurement. |
| Measured WCET | **absent by construction** | No measurement-based WCET exists in this repository; none is claimed. |

## 9. Honest labels, blockers and carried debt

| Item | Label |
|------|-------|
| Controller 25 ms / 40 Hz | `FIXED` (interface target) |
| Guidance 75 ms / 13.33 Hz | `DERIVED` |
| Legacy 37.5 ms | `ASSUMED`, evidence-only, **not** promoted, **no** production edit |
| Mission / navigation / actuator-feedback rates | `TO_BE_IDENTIFIED` (sim placeholders are `ASSUMED`) |
| WCET budgets, jitter bounds, delay/interference/brownout grids, throttle model | `ASSUMED` |
| Timing contract, header (seq/t_mono/valid), safe-hold action set, watchdog authority | `INTERFACE_SPECIFIED` |
| Event simulation, deterministic replay, deadline accounting, bounded emission | `IMPLEMENTED` (in this isolated harness only) |
| Hardware / power electronics / compute platform | `NOT_CERTIFIED`, no component identified |

**Blockers (honest):**

1. No measured execution times on any target: every WCET figure is a **budget**. Until an EXTERNAL bench measurement exists, schedulability here is an assumption test, not proof.
2. Mission / nav / actuator-feedback rates remain `TO_BE_IDENTIFIED`, so mission ZOH/buffer sizing and the 3.0 s stale timeout cannot be frozen.
3. Brownout thresholds and the sag/throttle coupling are `ASSUMED` per-unit proxies; the compute-reset floor (0.75 pu) is declared but **NOT_EXERCISED**.
4. Single-core, no-cache, no-DMA-contention scheduler model; interference is a single scalar proxy.
5. Fail-silent / safe-hold is simulated only. No auto-surface or accommodation policy exists, and none may be added without HIL validation.
6. Determinism is verified by independent re-execution inside one session (reverse case order); it does not prove cross-version or cross-platform bit-determinism.
7. **Sampled-debounce quantisation:** the undervoltage debounce is declared as 100 ms but is accumulated in 25 ms watchdog samples, and the first sample that observes `V < V_bo` credits a full sample interval. Detection can therefore fire up to one sample *early* in wall-clock terms - which is why `BRN` reports 79 ms detect latency against a 100 ms declared debounce. This is an artefact of the sampled implementation, not a faster detector; the declared bound used by HG9 (debounce + 2 periods) still holds. A continuous-time debounce would need a 4-sample counter to be equivalent.

**Carried QA debt (recorded, not actioned):**

1. **This task's own figure:** in panel `P5` of `REAL_TIME_POWER_INTEGRITY_CONTRACT.png`, six of the seven cases sit at 0% controller deadline miss, so their point labels crowd and partially overlap along the zero line. Cosmetic only - every value in that panel is tabulated exactly in Sec. 6. Not fixed here because the single permitted MATLAB invocation was already spent; the fix (stagger labels or split the zero-miss cluster onto a secondary axis) is deferred to the next task that regenerates this figure.
2. **Inherited from Gate 6:** the accepted Gate 6 artifact `suite_results/PROPULSION_POWER_COMPUTE_PARITY_FIX.png` contains a **minor overlapping parity annotation**. This is **cosmetic only**: it does not affect the accepted Gate 6 numbers or verdict. Per Gate 0 preservation rules the accepted Gate 6 MD/MAT/PNG were **not** rerun, regenerated, or altered by this task. Fix is deferred to the next task that legitimately regenerates that figure.

## 10. Next exact task

Gate 6B PASS unlocks Gate 7 as the next gate. Single untried next task:

**`gate7_mission_manager_fail_silent_sim`** - bind the Sec. 3 timing contract and the safe-hold action set to a constrained 3D mission manager (MissionCommand / WaypointSet / Ack), exercising heartbeat loss, bus timeout and stale-segment rejection with the same deterministic replay + fingerprint discipline. Rates stay `TO_BE_IDENTIFIED`; no auto-surface; `NOT_CERTIFIED`.

Not attempted here, deliberately: any production clock edit, any promotion of `ASSUMED` to `IDENTIFIED`, any component selection, any Gate 7 implementation.

## 11. Artifacts

| Artifact | Size |
|----------|------|
| `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.md` | this file |
| `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.mat` | 407.6 KiB (`-v7`, full contract + per-case output logs + gates) |
| `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.png` | 144.4 KiB (6 panels, visually QA'd) |

Total artifact footprint is far below the 300 MiB target.

## 12. Cross-references

- `suite_results/AUTONOMOUS_EXECUTION_POLICY.md` (Gate 6B hook, Pareto vector, promotion rules)
- `suite_results/AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md` (clocks, header, fail-silent, no auto-surface)
- `suite_results/PROPULSION_POWER_COMPUTE_PARITY_FIX.mat` (accepted Gate 6 power evidence)
- **Do not edit:** `suite_results/CODEX_VERTICAL_PLAN.md` (verified byte-identical, Sec. 8.1)
