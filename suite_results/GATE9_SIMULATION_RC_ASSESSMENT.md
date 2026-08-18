# GATE9_SIMULATION_RC_ASSESSMENT - Gate 9 simulation release-candidate assessment

**Task:** `GATE9_SIMULATION_RC_ASSESSMENT_001` | **Date:** 2026-08-09 12:53:47 | **Class:** bounded read-only evidence and range assembly | **MATLAB invocations:** 1 | **New simulation campaign:** NONE | **Method retry:** NONE | **Repo scan:** NONE

## VERDICT

**Gate 9 disposition: `FAIL` (`RC_NOT_GRANTED`).**

zero tolerance applied: 2 declared gates are FAIL, 2 are WAIVED and not PASS, and 2 residual-risk items are OPEN at BLOCKER severity (R1 R10 rudder rail; R7 hardware NOT_CERTIFIED). HG11, HG12 and HG13 remain open, so Gate 9 PASS is unavailable by construction.

**Deliverables:** COMPLETE - the assessment, the manifest, the matrix, the register, the Pareto vector, the ICD boundary and the requirement ranges are all published; only the RC itself is refused.

**Physical / hardware readiness: `NOT_CERTIFIED`.** Nothing in this document certifies any component, any timing on any processor, or any wet behaviour. Every requirement range is a specification that a future component must be shown to meet; none of them is a statement that a component meets it. No vendor, brand, part number, quotation or purchase is named, implied or recommended anywhere.

---

## 1. Reproducibility and provenance manifest

### 1.1 Sources read (exactly 3, no repo scan)

| # | Path | Role | Bytes | SHA-256 | n.s1.s2 |
|---|------|------|-------|---------|---------|
| 1 | `suite_results/AUV_REALIZATION_READINESS_PLAN.md` | Gate order, waiver rule, full gate history, frozen production anchors (transcribed constants) | 100301 | `9eb48b919a84b3c984a56217bab809b4f8f859a093f40137438db7a7ab17cdd7` | `n=100301.s1=8574698.s2=3293082657` |
| 2 | `suite_results/PROPULSION_POWER_COMPUTE_PARITY_FIX.mat` | Gate 6 propulsion / power / compute parity record (loaded and introspected in this run) | 3274552 | `338671b92f2de44c157cf15c12ec949f8c6ee0d6e6da4e45ca6f7af29b17fc6f` | `n=3274552.s1=115460397.s2=2842440884` |
| 3 | `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.mat` | Gate 6B real-time and power-integrity contract (loaded and introspected in this run) | 419060 | `c177a08715e4a009b21b57f6b5bf53e7f197db5cc7c52deff4bdb94cd53daf22` | `n=419060.s1=55439208.s2=1302865235` |

No other evidence file was opened for content. The four files in the integrity set below were opened **only to hash them**, before and after every write, to prove they were not modified.

### 1.2 Frozen integrity set (production + CODEX), unchanged across this run

| Path | Bytes | SHA-256 before | SHA-256 after | Unchanged |
|------|-------|----------------|---------------|-----------|
| `continuous_path_tracking.m` | 10845 | `e490453b094f2049...` | `e490453b094f2049...` | **YES** |
| `controller_law.m` | 9402 | `16b7c20a14f1a1af...` | `16b7c20a14f1a1af...` | **YES** |
| `guidance_law.m` | 14601 | `2d70cea916107649...` | `2d70cea916107649...` | **YES** |
| `suite_results/CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb7584...` | `000ba87721bb7584...` | **YES** |

**Production and `CODEX_VERTICAL_PLAN.md` untouched: YES.** The hashes above are taken before any work and again after all computation and figure emission. A third verification is taken after the document appends and is recorded in `GATE9_SIMULATION_RC_ASSESSMENT_run.log`; the integrity set is disjoint from every file this task writes.

### 1.3 Frozen seeds, solver and cadences

| Item | Value | Label |
|------|-------|-------|
| Monte Carlo seed | `20260809` | ASSUMED, frozen at the Gate 8 campaign |
| Draw vectors x cells | 32 x 8 = 256 runs | ASSUMED |
| Replay draws (determinism sentinels) | [1 16 32] | IMPLEMENTED |
| Integration step | dt = 0.0250 s, T_final = 30 s, fixed step | ASSUMED |
| Controller cadence | 0.0250 s / 40.0 Hz | **FIXED** |
| Guidance cadence | 0.0750 s / 13.333 Hz (PSD marker) | **DERIVED** |
| Legacy controller step | 0.0375 s | ASSUMED evidence-only, never promoted |
| Mission / navigation / actuator-feedback cadence | not issued | **TO_BE_IDENTIFIED** |
| Controller calls in the Gate 6 budget run | 42000 | IMPLEMENTED |
| Plant RHS evaluations in the Gate 6 budget run | 2564886 | IMPLEMENTED |
| R10 nominal reproduction fingerprint | `n=153600.s1=19094896.s2=2901292177` | IMPLEMENTED, reproduced across production, hooks-off replica and instrumented replica |

### 1.4 Reproducibility assessment (from accepted evidence, not re-run here)

Bit-reproducibility is **evidenced** at every point where it was tested: exact nominal parity between the hooks-off shadow path and unmodified `continuous_path_tracking.m` in 8/8 cells; bitwise deterministic reverse-order replay and first/last reset sentinels in every Gate 5, 6, 7 and 8 record; the R10 cell reproducing the same fingerprint across three independent code paths; cross-process reproduction of the Gate 5B estimator; and 16/16 parity records identical with a largest observed difference of 0.000e+00 at the Gate 5C revalidation.

That is necessary but not sufficient for a release candidate. Reproducibility proves the twin computes the same thing twice; it says nothing about whether what it computes is physically right. The physical question is answered by the residual-risk register in section 3, and the answer is that it is not yet answered.

### 1.5 Introspection of the two loaded records

| Record | Top-level variables | Flattened leaf entries |
|--------|--------------------:|-----------------------:|
| `PROPULSION_POWER_COMPUTE_PARITY_FIX.mat` | 23 | 5055 |
| `REAL_TIME_POWER_INTEGRITY_CONTRACT.mat` | 1 | 806 |

Harvest probe coverage over those leaves (used to check that a number quoted below actually exists in the records rather than only in prose):

| Probe | Matching leaves | First match |
|-------|----------------:|-------------|
| `tau_lag` | 68 | `S2.ideal_runs(1).prop.tau = 0` |
| `thrust` | 46 | `S2.frozen.HG.thrust_sat = 1` |
| `current_amp` | 16 | `S2.gates.G_battery_current_conditional.pass = 1` |
| `energy` | 167 | `S2.ideal_runs(1).prop.why = exact passthrough; parity hook against accepted audit` |
| `voltage_pu` | 17 | `S2.power_model.V_bus = 24 48` |
| `efficiency` | 238 | `S2.clone_check.detail = clone reduces byte-for-byte to continuous_path_tracking.m (233 lines; 18 marker lines)` |
| `period` | 15 | `S3.R.grids.legacy_ctrl_period_ms = 37.5` |
| `deadline` | 0 | `<none>` |
| `wcet` | 9 | `S3.R.cfg.wcet_bud = 0.0025 0.0125 0.03 0.005 0.01` |
| `jitter` | 2 | `S3.R.grids.transport_jitter_ms = 0 2.5 5` |
| `overrun` | 41 | `S3.R.cfg.overrun = 5 elements` |
| `priority` | 0 | `<none>` |
| `rate_hz` | 306 | `S2.frozen.HG.rate_util = 1` |
| `delay_ms` | 15 | `S3.R.grids.transport_delay_ms = 0 15 30` |
| `margin` | 326 | `S2.ideal_runs(1).worst_margin = 0.0597422` |
| `seed` | 1 | `S2.frozen.seed_used = 0` |
| `dt_step` | 9 | `S2.parity(1).sig.dt = 0` |
| `gate_verdict` | 546 | `S2.gate4 = shadow_only` |
| `deadband` | 0 | `<none>` |
| `sensor` | 32 | `S2.ideal_runs(1).speed_bias = -0.317449` |
| `safehold` | 7 | `S3.R.replayA{1}.safe_hold_dwell = 0` |

---

## 2. Verification matrix, Gates 0-8

| Gate | ID | Status | Evidence summary | Evidence link |
|------|----|--------|------------------|---------------|
| **Gate 0** | `artifact_disk_preflight_gate` | **PASS** | free 4.34 GiB on the artifact volume against a 3 GiB start threshold; preferred 5 GiB reserve NOT met, recorded as a note not a waiver; artifact budget under 3 MiB | `this run log` |
| **Gate 1** | `depth_gamma_coupled_plant_identification_gate` | **PASS** | speed-scheduled sagittal ID at U={1.0,1.5,2.0}x{level,climb}; trim 6/6, jac 6/6, val 12/12; hydro CI NOT_CLAIMED, hydro coefficients and speed family remain TO_BE_IDENTIFIED | `DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}` |
| **Gate 2** | `depth_gamma_structural_decoupling_governor_aw_gate` | **FAIL** | CLOSED_AFTER_3_ATTEMPTS; attempt 3 primary KPI -68.61 pct against a +5 pct floor; production frozen, acceptance would need an explicit waiver | `DEPTH_GAMMA_STRUCTURAL_ATTEMPT3.{md,mat,png}` |
| **Gate 3** | `closed_loop_actuator_realism_gate` | **FAIL** | CLOSED_AFTER_3_ATTEMPTS on an R10 accepted-baseline parity blocker; all actuator values remain ASSUMED | `CLOSED_LOOP_ACTUATOR_HARNESS_FINAL record` |
| **Gate 4** | `water_relative_current_feasibility_guidance_gate` | **WAIVED** | 4A deterministic 32-case map PASS; 4B closed after 3 candidates and two authorised reruns, terminal FAIL on admitted_secondary_within_2pct for RESHAPE rows 22-24; the Gate 4 waiver is OPEN and shadow-only, never promoted | `WATER_CURRENT_* records` |
| **Gate 5** | `multirate_nav_truth_measured_estimated_ekf_gate` | **PASS** | INTERFACE AND INTEGRITY ONLY: 5A 12/12 cases and 22/22 validation gates, 5B 28/28 hard gates with proved truth blindness, 5C 24/24 cases and 32/32 hard gates with a status-only health machine; accuracy is CHARACTERIZATION and NOT_CERTIFIED, every sensor numeric stays ASSUMED | `NAV_MULTIRATE_* and NAV_AVAILABILITY_* records` |
| **Gate 6** | `propulsion_power_compute_realism_gate` | **PASS** | attempt 1 FAIL on tracking at the ideal actuator; the resumed parity fix passed 12/12 gates with 8/8 exact ideal-hook parity; power and energy are component-neutral ranges under an ASSUMED efficiency interval | `PROPULSION_POWER_COMPUTE_PARITY_FIX.{md,mat,png} (source #2)` |
| **Gate 6B** | `real_time_power_integrity_contract` | **PASS** | 13/13 declared hard gates over 5 tasks; WCET is a declared budget and not a measurement; mission, navigation and actuator-feedback rates remain TO_BE_IDENTIFIED | `REAL_TIME_POWER_INTEGRITY_CONTRACT.{md,mat,png} (source #3)` |
| **Gate 7** | `mission_manager_watchdog_fail_silent_gate` | **PASS** | simulation scope 17/17 hard gates after the acceptance-criterion repair, with attempt-1 raw behaviour proved identical; 17/17 injected faults detected, 0 false alarms, 0 surface, 0 accommodation, 0 direct-actuator commands | `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.{md,mat,png}` |
| **Gate 8** | `monte_carlo_distribution_regression_gate` | **WAIVED** | WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT and never PASS: three closure attempts failed, HG5 (R10 rail), HG11 (no plant-parameter injection seam), HG12 (FDIR matrix not re-drawn), HG13 (cell geometry ASSUMED_RECONSTRUCTION) all remain open | `GATE8_* records and the Gate 8 waiver append` |

**Status vocabulary is exactly as declared upstream.** `WAIVED` is not `PASS` and is never to be transcribed as one. Gate 8 in particular is `WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT`: the waiver unlocked this bounded assessment and nothing else.

---

## 3. Residual-risk register R1-R8 (first-class Gate 9 output)

| # | Risk | Severity | State | Evidence | Label | Consequence for this RC |
|---|------|----------|-------|----------|-------|--------------------------|
| **R1** | R10 production rudder rail unresolved | **BLOCKER** | OPEN | Raw rudder demand peaks 466.6729 deg pre-limiter; the plant input pins at the 25.0000 deg envelope for 0.2817 of a 30 s horizon (8.450 s, 12 intervals, longest 2.300 s, first at t = 1.825 s); magnitude dwell 0.8908, rate dwell 0.6917, peak realized slew 40.0000 deg/s. Multi-origin: three contributions each reach the envelope alone, earliest S2_CTRL_TERM_P at t = 1.200 s; windup EXCLUDED_STRUCTURALLY. | `IMPLEMENTED measurement / unresolved defect` | Zero actuator authority margin for current, servo lag, deadband or sensor noise. Directly limits RR-02 and RR-05. |
| **R2** | CG / CB / buoyancy priors drawn but never injected | **HIGH** | OPEN | CG/CB +/-2 cm per axis and buoyancy +/-3 pct enter the campaign draw vector and are never applied because no shadow plant-parameter seam exists. HG11 open. | `ASSUMED prior, UNSUPPORTED` | The recorded worst corner does not bound the true worst case, which is why RR-07 and RR-08 carry coverage factors. |
| **R3** | Gate 7 FDIR matrix not re-drawn inside Monte Carlo | **HIGH** | OPEN | The 16-case mission-manager and fail-silent matrix that passed 17/17 hard gates was never re-driven through the Monte Carlo loop under the same draws. HG12 open. | `NOT_EVALUATED under MC` | Fault detection, latching, hysteresis and the response ladder are unevidenced under distributed uncertainty. Limits RR-17 and RR-23. |
| **R4** | Cell geometry is an ASSUMED_RECONSTRUCTION | **MEDIUM** | OPEN | The eight production cells (X and XZ at U = {1.0,1.5,2.0}, R10 at U = {1.5,2.0}) were reconstructed rather than bound to the frozen cell definitions. HG13 open. | `ASSUMED_RECONSTRUCTION` | Every distributional statement inherits the reconstruction. Limits RR-05. |
| **R5** | Estimator streams absent on the Gate 8 path | **HIGH** | OPEN | The Monte Carlo and R10 diagnostic loops run on truth x and y; the Gate 5B and 5C estimator and availability manager were never inserted, so no navigation error propagates into any Gate 8 distribution. | `NOT_IMPLEMENTED` | Every navigation requirement range RR-12 to RR-18 is an allocation against a budget the twin has never actually spent. |
| **R6** | Power coverage PARTIAL | **MEDIUM** | OPEN | Thrust-authority derate only; the brownout branch was never entered in any Monte Carlo run, so the real-time power-integrity contract is not distributionally exercised. | `PARTIAL` | Limits RR-08 to RR-11: the power integrity numbers are single-case, not distributional. |
| **R7** | Hardware readiness NOT_CERTIFIED | **BLOCKER for hardware claims** | OPEN | No bench, no HIL and no wet data anywhere in the chain. Servo tau, deadband, hysteresis, thruster map, sensor sigma / bias / delay and the mission, navigation and actuator-feedback rates all remain TO_BE_IDENTIFIED. | `NOT_CERTIFIED / TO_BE_IDENTIFIED` | Every range in this document is a requirement to be met by future components, never a statement that any component meets it. |
| **R8** | Upstream gate debt carried forward | **HIGH** | OPEN | The Gate 4 waiver remains OPEN and shadow-only; Gate 1 hydro coefficients and the speed family remain TO_BE_IDENTIFIED; Gate 2 and Gate 3 are CLOSED_AFTER_3_ATTEMPTS with actuator values ASSUMED. | `carried forward` | Structural vertical control and closed-loop actuator realism were never closed, so the RC rests on a frozen cascade that three structural attempts failed to improve. |

---

## 4. Pareto vector

| Axis | Evidenced position | Assessment | Limiting risk |
|------|--------------------|------------|---------------|
| **tracking** | pooled cte_max P5/P50/P95/worst = 0.110 / 0.342 / 0.565 / 0.826 m; R10 cell cte max 0.21262 m, median 0.10051 m; grid-mean depth MAE 0.269528 m frozen | **ACCEPTABLE (bounded, not divergent)** | R4, R5 |
| **actuator margin** | rudder rail dwell 0.2817, magnitude-limiter dwell 0.8908, rate-limiter dwell 0.6917, peak realized slew exactly 40.0000 deg/s, fin moving duty up to 99.7 pct | **CRITICAL - effectively zero margin** | R1 (BLOCKER) |
| **energy** | worst-corner 15.59 Wh/km with energy margin +0.896 and peak bus current 6.88 A with current margin +0.541, under an ASSUMED efficiency interval | **ACCEPTABLE with coverage factors** | R2, R6 |
| **estimation** | interface and integrity only: 18-state error-state EKF with proved truth blindness and a status-only availability machine; accuracy is CHARACTERIZATION; the Gate 8 path used truth x and y | **OPEN - no accuracy claim exists** | R5 |
| **timing** | controller 25 ms FIXED, guidance 75 ms DERIVED, 13/13 real-time gates; 200 overload misses all accounted; safe-hold 3 ms after the third consecutive miss; host mean 31.919 ms/step is NOT a WCET | **PARTIAL - budgets declared, never measured on a target** | R7, TARGET_DEPENDENT |
| **safety** | 17/17 FDIR hard gates, 17/17 injected faults detected inside declared bounds, 0 false alarms, 0 missed, 0 surface, 0 accommodation, 0 direct-actuator commands; brownout to safe-hold in 79 ms | **PASS in simulation scope only** | R3, R6 |

The vector is not balanced. Energy, safety and tracking sit in acceptable territory while actuator margin is effectively zero and estimation contributes nothing at all to the distribution. A release candidate declared on this shape would be a candidate whose only comfortable axes are the ones that were actually exercised.

---

## 5. ICD boundary: Mission -> Guidance -> Navigation -> Controller -> Actuator

| Boundary | Message set | Cadence | Version key | Timestamp key | Sequence key | Validity keys | Heartbeat | Stale rule | Frame | Unit | Twin-log key | Maturity |
|----------|-------------|---------|-------------|---------------|--------------|---------------|-----------|------------|-------|------|--------------|----------|
| **Mission -> Guidance** | MissionCommand / WaypointSet / TrajectorySegment | TO_BE_IDENTIFIED | `schema_version` | `t_mono` | `seq` | valid + quality + integrity + validity horizon | heartbeat present, mission stale triggers fail-silent | stale age vs declared stale limit | NED | SI (m, m/s, rad) | `MISSION.cmd.*` | INTERFACE_SPECIFIED, manager NOT_IMPLEMENTED on the runtime path |
| **Guidance -> Controller** | course / yaw and depth reference set | 13.333 Hz DERIVED (75 ms) | `schema_version` | `t_mono` | `seq` | valid + quality | heartbeat at the guidance tick | held reference age <= one guidance period (ZOH) | NED course, BODY sideslip | SI (rad, m) | `GUID.yaw_ref, GUID.chi_f, GUID.chi_los, GUID.beta` | IMPLEMENTED and signal-logged: observer vs production yaw_ref closes to 0.000e+00 rad |
| **Navigation -> Controller** | StateEstimate (ESTIMATED bus) | 40 Hz consumer side; aiding channels multirate | `schema_version` | `t_mono` | `seq` | status + source mask + health + covariance | per-channel heartbeat and admission counters | per-channel stale age with entry / exit dwell hysteresis | NED position and velocity, BODY rates | SI (m, m/s, rad, rad/s) | `EST.x, EST.P, EST.status, EST.health` | IMPLEMENTED at Gate 5B/5C but NOT_IMPLEMENTED on the Gate 8 path, which used truth x and y (R5) |
| **Controller -> Actuator** | FinCommand (elevator, rudder) + thrust demand | 40 Hz FIXED (25 ms), ZOH | `schema_version` | `t_mono` | `seq` | valid + saturation and rail flags | heartbeat at the controller tick | command stale limit, hold-last-safe on expiry | BODY surface deflection | deg for surfaces, native production unit for thrust | `CTRL.delta_e, CTRL.delta_r, CTRL.thrust` | IMPLEMENTED; local magnitude, rate and safety authority overrides mission |
| **Actuator -> Controller (feedback)** | ActuatorStatus (position, current, health) | TO_BE_IDENTIFIED | `schema_version` | `t_mono` | `seq` | valid + stuck and overcurrent flags | heartbeat, bus timeout monitored | stale age drives the actuator monitors | BODY surface deflection | deg, A | `ACT.pos, ACT.current, ACT.health` | INTERFACE_SPECIFIED only; no feedback hardware exists, rate TO_BE_IDENTIFIED (R7) |

Two standing rules of this boundary are unchanged and are restated because the requirement ranges depend on them: local magnitude, rate and safety authority **overrides mission**, and a stale mission input results in **fail-silent**, never an automatic surface and never an automatic accommodation.

---

## 6. Procurement-ready component requirement RANGES

**Reading rule.** Each row is a requirement expressed as a range, `DERIVED` in this document from a parent that is either `ASSUMED` or `TO_BE_IDENTIFIED`. The parent column names that parent and the label column gives its provenance. No row names a vendor, a brand, a part number or a price, and no row asserts that any component satisfies it. A range is closed only by bench, HIL, wet or real-data identification, all of which are EXTERNAL to this plan.

| ID | Parameter | Unit | Frame / axis | **Range** | Derivation | Parent label | Parent / source | Limiting risk |
|----|-----------|------|--------------|-----------|------------|--------------|------------------|---------------|
| `RR-01` | Servo first-order response time constant tau (elevator and rudder) | s | actuator channel, per surface | **0.0125 .. 0.100** | DERIVED: lower = 0.5 x controller period Tc = 0.0125 s, below which servo bandwidth exceeds the 40 Hz command bandwidth and buys no closed-loop benefit; upper = 4 x Tc = 0.100 s, which is the ASSUMED tau grid point carrying recorded shadow evidence (rudder RMSE 0.7063 deg, delay 0.0750 s, rate dwell 0.00 pct). | `ASSUMED` | ASSUMED tau grid {0.05, 0.10, 0.20} s; FIXED Tc = 0.025 s | R7 (servo tau TO_BE_IDENTIFIED), R1 (no rate margin at the rail) |
| `RR-02` | Servo no-load angular rate (elevator and rudder) | deg/s | actuator channel, per surface | **80 .. 160 (hard floor 40)** | DERIVED: hard floor = the FIXED software rate limit 40 deg/s; the required band is 2x..4x that floor because the R10 cell shows rate-limiter dwell 0.6917 and peak realized slew exactly 40.0000 deg/s, i.e. ZERO rate margin at the software limit. | `TO_BE_IDENTIFIED` | servo no-load rate TO_BE_IDENTIFIED; FIXED software rate limit 40 deg/s | R1 (R10 rudder rail unresolved, BLOCKER) |
| `RR-03` | Servo total deadband + backlash (mechanical play referred to surface) | deg | surface deflection, per surface | **0 .. 0.10 accept; (0.10 .. 0.25] conditional on written waiver** | DERIVED: open-loop deadband sensitivity gives rudder RMSE degradation vs w=0 of 1.03 pct at 0.10 deg, 6.17 pct at 0.25 deg and 22.70 pct at 0.50 deg. The promotion policy admits at most 2.0 pct secondary non-safety regression, so 0.10 deg is the only grid width inside policy. | `ASSUMED` | ASSUMED play-free deadband grid {0, 0.10, 0.25, 0.50} deg (open loop, not closed-loop limit cycle) | R7 (deadband/hysteresis TO_BE_IDENTIFIED), R1 |
| `RR-04` | Servo command and feedback angular resolution | deg | surface deflection, per surface | **<= 0.020** | DERIVED: 0.2 x the RR-03 deadband ceiling 0.10 deg, so quantisation cannot consume more than one fifth of the admissible play budget. | `ASSUMED` | child of RR-03 (ASSUMED deadband grid) | R7 |
| `RR-05` | Surface deflection envelope to be mechanically guaranteed | deg | BODY, elevator / rudder | **elevator >= +/-15 ; rudder >= +/-25** | DERIVED: the FIXED software magnitude envelope must be reachable mechanically without hard-stop contact; the R10 plant input pins at 25.0000 deg for 0.2817 of a 30 s horizon so the rudder stop is exercised continuously. | `ASSUMED` | FIXED software envelope elevator 15 deg, rudder 25 deg (frozen production anchor) | R1 (rail dwell), R4 (cell geometry ASSUMED_RECONSTRUCTION) |
| `RR-06` | Propulsion first-order thrust lag time constant tau_thr | s | BODY x (surge) | **BRACKET ONLY: [ideal .. slow-and-low-authority ASSUMED variant]; numeric upper UNRESOLVED_IN_PERMITTED_SOURCES** | DERIVED: the Gate 6 worst-corner budget was met across the whole ASSUMED thruster variant family (ideal, nominal lag-map, slow+low-authority, high-authority), all four of which are Pareto non-dominated, so the evidenced admissible bracket is the family span. The numeric tau of each variant is not quoted in the permitted sources, therefore no number is invented here. | `ASSUMED` | ASSUMED thruster variant family {ideal, nominal lag-map, slow+low-authority, high-authority} | R7 (thruster map TO_BE_IDENTIFIED), R6 (power coverage PARTIAL) |
| `RR-07` | Continuous / peak axial thrust capability | N | BODY x (surge) | **continuous >= 16.865 ; peak >= 21.081** | DERIVED: worst-corner peak realized thrust 14.054 N scaled by the ASSUMED coverage factors 1.20 (continuous) and 1.50 (peak). Coverage is required because buoyancy +/-3 pct and CG/CB +/-2 cm were drawn but never injected, so the recorded corner does not bound the true worst case. | `ASSUMED` | worst-corner peak realized thrust 14.054 N under ASSUMED thruster family | R2 (CG/CB/buoyancy UNSUPPORTED), R6 |
| `RR-08` | Bus current delivery capability | A | electrical bus | **continuous >= 8.256 ; peak >= 10.320** | DERIVED: worst-corner peak bus current 6.88 A (recorded current margin +0.541) scaled by the ASSUMED coverage factors 1.20 and 1.50. | `ASSUMED` | worst-corner peak bus current 6.88 A | R6, R2 |
| `RR-09` | Usable stored energy per kilometre of track | Wh/km | mission profile | **18.708 .. 23.385** | DERIVED: worst-corner 15.59 Wh/km (recorded energy margin +0.896) scaled by the ASSUMED coverage factors 1.20 and 1.50. Absolute pack energy needs the mission range, which is TO_BE_IDENTIFIED, so only the per-km rate is specified. | `ASSUMED` | worst-corner 15.59 Wh/km at the pessimistic ASSUMED corner | R6 |
| `RR-10` | Bus source impedance under peak transient (power integrity) | ohm per volt of nominal bus | electrical bus | **<= 0.01453** | DERIVED: the undervoltage trigger is 0.85 pu, so the admissible sag is 0.15 pu; dividing by the RR-08 peak current 10.320 A gives the normalised source-impedance ceiling. Expressed per volt of nominal bus because the nominal bus voltage is TO_BE_IDENTIFIED. Observed brownout minimum in the injected case was 0.803 pu, which is a stimulus, not a supply property. | `TO_BE_IDENTIFIED` | nominal bus voltage TO_BE_IDENTIFIED; ASSUMED trigger 0.85 pu | R6 (brownout branch never entered under MC) |
| `RR-11` | Supply hold-up time through an undervoltage excursion | ms | electrical bus | **>= 100** | DERIVED: health declaration to safe-hold took 79 ms in the brownout case; a 1.25x ASSUMED margin rounded up to the next 10 ms gives the hold-up floor, so the bus must survive the detection-to-safe-hold interval without loss of compute or state. | `ASSUMED` | ASSUMED brownout case; safe-hold declared 79 ms after trigger | R6 |
| `RR-12.1` | DVL velocity error (noise 1-sigma + residual bias, combined) at dead-reckoning horizon T_DR = 1 s | m/s | BODY u,v,w (bottom-lock) | **<= 0.05650** | DERIVED: allocate 10 pct of the pooled cte_max P95 of 0.565 m to navigation-induced lateral error, i.e. 0.0565 m, and divide by the ASSUMED dead-reckoning horizon 1 s. | `ASSUMED` | ASSUMED T_DR grid {1,5,10,30} s; pooled cte_max P95 0.565 m from the waived Gate 8 campaign | R5 (estimator streams NOT_IMPLEMENTED on the Gate 8 path) |
| `RR-12.2` | DVL velocity error (noise 1-sigma + residual bias, combined) at dead-reckoning horizon T_DR = 5 s | m/s | BODY u,v,w (bottom-lock) | **<= 0.01130** | DERIVED: allocate 10 pct of the pooled cte_max P95 of 0.565 m to navigation-induced lateral error, i.e. 0.0565 m, and divide by the ASSUMED dead-reckoning horizon 5 s. | `ASSUMED` | ASSUMED T_DR grid {1,5,10,30} s; pooled cte_max P95 0.565 m from the waived Gate 8 campaign | R5 (estimator streams NOT_IMPLEMENTED on the Gate 8 path) |
| `RR-12.3` | DVL velocity error (noise 1-sigma + residual bias, combined) at dead-reckoning horizon T_DR = 10 s | m/s | BODY u,v,w (bottom-lock) | **<= 0.00565** | DERIVED: allocate 10 pct of the pooled cte_max P95 of 0.565 m to navigation-induced lateral error, i.e. 0.0565 m, and divide by the ASSUMED dead-reckoning horizon 10 s. | `ASSUMED` | ASSUMED T_DR grid {1,5,10,30} s; pooled cte_max P95 0.565 m from the waived Gate 8 campaign | R5 (estimator streams NOT_IMPLEMENTED on the Gate 8 path) |
| `RR-12.4` | DVL velocity error (noise 1-sigma + residual bias, combined) at dead-reckoning horizon T_DR = 30 s | m/s | BODY u,v,w (bottom-lock) | **<= 0.00188** | DERIVED: allocate 10 pct of the pooled cte_max P95 of 0.565 m to navigation-induced lateral error, i.e. 0.0565 m, and divide by the ASSUMED dead-reckoning horizon 30 s. | `ASSUMED` | ASSUMED T_DR grid {1,5,10,30} s; pooled cte_max P95 0.565 m from the waived Gate 8 campaign | R5 (estimator streams NOT_IMPLEMENTED on the Gate 8 path) |
| `RR-13.1` | IMU gyro residual bias (post-calibration, in-run) at dead-reckoning horizon T_DR = 1 s | deg/s | BODY p,q,r | **<= 0.38352** | DERIVED: allocate 10 pct of the measured steady heading tracking error 3.8352 deg to estimator bias drift, i.e. 0.3835 deg, and divide by the ASSUMED dead-reckoning horizon 1 s. | `ASSUMED` | ASSUMED T_DR grid; measured heading error 3.8352 deg from the guidance signal-log closure | R5, R1 (heading error is the dominant rail contributor) |
| `RR-13.2` | IMU gyro residual bias (post-calibration, in-run) at dead-reckoning horizon T_DR = 5 s | deg/s | BODY p,q,r | **<= 0.07670** | DERIVED: allocate 10 pct of the measured steady heading tracking error 3.8352 deg to estimator bias drift, i.e. 0.3835 deg, and divide by the ASSUMED dead-reckoning horizon 5 s. | `ASSUMED` | ASSUMED T_DR grid; measured heading error 3.8352 deg from the guidance signal-log closure | R5, R1 (heading error is the dominant rail contributor) |
| `RR-13.3` | IMU gyro residual bias (post-calibration, in-run) at dead-reckoning horizon T_DR = 10 s | deg/s | BODY p,q,r | **<= 0.03835** | DERIVED: allocate 10 pct of the measured steady heading tracking error 3.8352 deg to estimator bias drift, i.e. 0.3835 deg, and divide by the ASSUMED dead-reckoning horizon 10 s. | `ASSUMED` | ASSUMED T_DR grid; measured heading error 3.8352 deg from the guidance signal-log closure | R5, R1 (heading error is the dominant rail contributor) |
| `RR-13.4` | IMU gyro residual bias (post-calibration, in-run) at dead-reckoning horizon T_DR = 30 s | deg/s | BODY p,q,r | **<= 0.01278** | DERIVED: allocate 10 pct of the measured steady heading tracking error 3.8352 deg to estimator bias drift, i.e. 0.3835 deg, and divide by the ASSUMED dead-reckoning horizon 30 s. | `ASSUMED` | ASSUMED T_DR grid; measured heading error 3.8352 deg from the guidance signal-log closure | R5, R1 (heading error is the dominant rail contributor) |
| `RR-14` | IMU update rate | Hz | BODY | **>= 40 floor ; 160 .. 400 preferred** | DERIVED: floor = one fresh sample per controller period (40 Hz FIXED); the preferred band is 4x..10x that floor so that ZOH and aliasing margin exist inside the 0.025 s tick. | `TO_BE_IDENTIFIED` | IMU cadence TO_BE_IDENTIFIED; controller 40 Hz FIXED | R5 |
| `RR-15` | DVL update rate | Hz | BODY | **>= 13.333 for gap-free use ; slower admissible only if RR-12 and RR-17 hold** | DERIVED: one fresh bottom-lock velocity per guidance period 0.075 s (13.333 Hz DERIVED). A slower sensor is admissible only when the resulting gap is covered by the RR-12 dead-reckoning row and the RR-17 dropout limit. | `TO_BE_IDENTIFIED` | DVL cadence TO_BE_IDENTIFIED; guidance 13.333 Hz DERIVED | R5 |
| `RR-16` | Sensor-to-controller transport delay (sense to actuate), any aiding channel | ms | end to end | **<= 30 hard ; <= 15 preferred** | DERIVED: the real-time contract was exercised at 0, 15 and 30 ms transport delay plus jitter and held its declared gates; the largest exercised value becomes the hard ceiling and the middle value the preferred ceiling. No delay beyond the exercised set may be assumed safe. | `ASSUMED` | ASSUMED transport-delay cases {0,15,30} ms + jitter at Gate 6B | R5, R7 |
| `RR-17` | Aiding-channel dropout (DVL bottom-lock loss, heading loss) | dimensionless duty and s | per channel | **max contiguous <= selected T_DR from RR-12 ; cumulative duty <= 0.10** | DERIVED: the contiguous limit is exactly the dead-reckoning horizon that RR-12 and RR-13 were solved for, so the two rows are consistent by construction; the cumulative duty ceiling is the ASSUMED 10 pct allocation used throughout this table. | `ASSUMED` | ASSUMED outage profiles; availability manager is status-only and provably inert | R5, R3 |
| `RR-18` | Depth (pressure) sensing error, noise plus residual bias | m | NED z, positive down | **<= 0.02695** | DERIVED: 10 pct of the frozen baseline grid-mean depth MAE 0.269528 m, so depth sensing cannot dominate the depth error the twin already carries. | `ASSUMED` | frozen baseline grid-mean depth MAE 0.269528 m | R5 |
| `RR-19` | Controller task period and relative deadline | ms | compute | **period = 25.0 (FIXED) ; deadline <= 25.0** | DERIVED: transcribed from the frozen ICD clock, controller 40 Hz FIXED, with an implicit deadline equal to the period as declared by the real-time contract. | `ASSUMED` | controller 25 ms / 40 Hz FIXED; legacy 37.5 ms is ASSUMED evidence-only and not promoted | R7 |
| `RR-20` | Controller task WCET budget (requirement, never a measurement) | ms | compute | **<= 12.50** | DERIVED: half the 25.0 ms controller period, leaving the other half for guidance, navigation, FDIR and RTOS overhead. The host mean of 31.919 ms per step is NOT a WCET and must never be quoted as one. | `TO_BE_IDENTIFIED` | WCET on any target is TO_BE_IDENTIFIED; no timing claim on real silicon exists | R7, and TARGET_DEPENDENT until an exact part and board are supplied |
| `RR-21` | Guidance task period and WCET budget | ms | compute | **period = 75.0 (DERIVED) ; WCET <= 37.50** | DERIVED: guidance cadence 13.333 Hz is itself DERIVED from the frozen PSD marker; the WCET budget is half that period on the same half-period rule as RR-20. | `ASSUMED` | guidance 75 ms / 13.333 Hz DERIVED | R7 |
| `RR-22` | Task release jitter | ms | compute | **controller <= 2.50 ; guidance <= 7.50** | DERIVED: 10 pct of each task period, the same allocation fraction used for the sensing rows, so schedule noise cannot consume the WCET budget. | `ASSUMED` | ASSUMED 10 pct allocation; jitter bounds declared per task in the real-time contract | R7 |
| `RR-23` | Deadline overrun handling | count and ms | compute | **every miss accounted ; safe-hold within 3 ms of the 3-th consecutive miss** | DERIVED: the overload burst produced 200 controller misses, all accounted, with safe-hold engaged 3 ms after the 3-th consecutive miss. That observed behaviour becomes the requirement: no silent miss, deterministic ladder, no auto-surface and no auto-accommodation. | `ASSUMED` | ASSUMED overload burst case at Gate 6B | R3 (FDIR not re-drawn under MC), R7 |
| `RR-24` | Total processor utilisation across the declared task set | dimensionless | compute | **<= 0.70** | DERIVED: an ASSUMED scheduling headroom of 30 pct over the declared five-task set, so that the WCET budgets of RR-20 and RR-21 remain schedulable once mission, navigation and actuator-feedback rates are identified. | `TO_BE_IDENTIFIED` | mission / navigation / actuator-feedback rates TO_BE_IDENTIFIED | R7, TARGET_DEPENDENT |
| `RR-25` | Mission, navigation and actuator-feedback task rates | Hz | compute and bus | **TO_BE_IDENTIFIED - no range is issued** | NOT DERIVED ON PURPOSE: no evidence in the permitted sources constrains these three cadences. Issuing a number here would be manufacture, so the row is published empty and blocking. | `TO_BE_IDENTIFIED` | declared TO_BE_IDENTIFIED at Gate 6B and unchanged since | R7, R3 |

**Parentage audit:** 31 rows total, 24 with an `ASSUMED` parent, 7 with a `TO_BE_IDENTIFIED` parent, **0 rows with no admissible parent**. Two rows deliberately publish no number: `RR-06` because the thruster variant time constants are not quoted in the permitted sources, and `RR-25` because nothing in the permitted sources constrains the mission, navigation or actuator-feedback cadences. Inventing either would be manufacture.

---

## 7. Explicit EXTERNAL stops

| Stop | Scope | Status |
|------|-------|--------|
| **CAD** | Hull and mechanical CAD, fin geometry, servo mounting, pressure housing | NOT STARTED - forbidden before a Gate 9 range set exists, and this range set is issued under a FAIL disposition |
| **PURCHASE** | Any vendor selection, part number, quotation or purchase order | FORBIDDEN - this document names no vendor and no part; the ranges are requirements a component must satisfy, never a claim that one does |
| **BENCH / HIL** | Servo tau, deadband, hysteresis, current and thermal load; thruster map; processor WCET, memory and jitter on a real target | REQUIRED to convert RR-01 to RR-06 and RR-19 to RR-24 from DERIVED requirements into IDENTIFIED facts |
| **WET** | In-water trials, current exposure, bottom-lock behaviour, real disturbance spectra | REQUIRED to close R1 honestly and to replace the ASSUMED current profiles |
| **REAL-DATA SYSTEM ID** | Hydrodynamic coefficients, speed family, added mass, restoring, propulsion map, sensor sigma / bias / delay | REQUIRED to upgrade any ASSUMED or TO_BE_IDENTIFIED label to IDENTIFIED; no simulation run can do this |

---

## 8. Task hygiene and claim boundary

| Constraint | Result |
|------------|--------|
| Sources read | exactly 3, listed in section 1.1, no repo scan |
| MATLAB invocations | 1 (this run), used only to read the two records and emit artifacts |
| New simulation campaign | NONE |
| Method retry | NONE; every closed method stays closed |
| Production / controller / guidance edits | NONE, proved by hash before and after |
| `CODEX_VERTICAL_PLAN.md` | untouched, proved by hash before and after |
| Label upgrades | NONE |
| Accepted evidence | preserved; nothing deleted, nothing overwritten |
| Vendor / brand / part / purchase claims | NONE |
| Hardware certification claims | NONE - `NOT_CERTIFIED` throughout |
| Disk preflight | free 4.34 GiB, 3 GiB start threshold YES, 5 GiB preferred reserve NO |
| Visual QA | VISUAL_QA_PASS (main 2292x1563 px ink 0.149, QA 1771x1146 px ink 0.065, both decoded from disk after writing) |

### Why this is a FAIL and not a PARTIAL

The zero-tolerance rule is explicit: an unresolved hard safety gate prevents a Gate 9 PASS, and the declared matrix must be reported exactly as it stands. Of the 10 declared rows, 2 are **FAIL** and 2 are **WAIVED** and therefore not PASS, and the residual-risk register carries 2 open **BLOCKER** items - R1, which removes essentially all actuator authority margin on one production cell, and R7, which is the standing hardware boundary. A PARTIAL would imply that the release candidate is partially granted. It is not granted at all. What is complete is the assessment, not the candidate.

This is the outcome the Gate 8 waiver predicted in writing before the work began, and recording it honestly is the deliverable.

### Files created or changed by this task

- `suite_results/GATE9_SIMULATION_RC_ASSESSMENT.md            (created)`
- `suite_results/GATE9_SIMULATION_RC_ASSESSMENT.mat           (created)`
- `suite_results/GATE9_SIMULATION_RC_ASSESSMENT.png           (created)`
- `suite_results/GATE9_SIMULATION_RC_ASSESSMENT_qa.png        (created)`
- `suite_results/GATE9_SIMULATION_RC_ASSESSMENT_run.log       (created)`
- `suite_results/AUV_REALIZATION_READINESS_PLAN.md   (appended)`
- `suite_results/AUTONOMOUS_EXECUTION_POLICY.md      (appended)`
- `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md(appended)`
- `suite_results/PITCH_CONTROL_RESEARCH_LOG.md       (appended)`
- `run_gate9_simulation_rc_assessment.m              (created, this driver)`

The four appended documents receive one marker-guarded append each and are never rewritten. Every other file in `suite_results/` is untouched.

---

## 9. Next task (exactly one)

**`GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001`** - read-only fast whole-code embedded-readiness gap audit over checklist A1-A13. Evidence is read, never re-executed; closed dead-ends are read as evidence only. Every finding is classified `BLOCKER` / `TARGET_DEPENDENT` / `EXTERNAL_HIL` / `COSMETIC`. Its own PASS bar is unchanged and not relaxed, so an audit over a FAIL RC will normally report BLOCKERs and therefore not PASS Gate 9B.

**STM32 adaptation remains FORBIDDEN.** The terminus `AWAIT_STM32_EXACT_PART_NUMBER` stands: target-specific work may begin only when the user supplies the exact part number and board **and** every unresolved blocker (R1-R8 plus any Gate 9B BLOCKER) is explicitly dispositioned as fixed, waived with written residual risk, `TARGET_DEPENDENT` or `EXTERNAL_HIL`. No processor is selected, guessed, recommended or implied.

---

## Appendix A - full leaf inventory of the two loaded records

Published so that every number quoted above can be traced to a stored field, and so that the two rows that publish no number can be shown to have no stored source rather than an overlooked one.

| Leaf | Class | Size | Summary |
|------|-------|------|---------|
| `S2.attempt` | char | 1x22 | gate6_attempt2_resumed |
| `S2.attempt_note` | char | 1x131 | attempt1 FAIL shadow-only preserved; attempt2 interrupted by host power/bridge loss with no MATLAB start; this resume completed it... |
| `S2.cells` | struct-array | 1x8 | 8 elements |
| `S2.cells(1).route` | char | 1x1 | X |
| `S2.cells(1).U` | double | 1x1 | 1 |
| `S2.cells(1).ir` | double | 1x1 | 1 |
| `S2.cells(1).iu` | double | 1x1 | 1 |
| `S2.cells(2).route` | char | 1x2 | XZ |
| `S2.cells(2).U` | double | 1x1 | 1 |
| `S2.cells(2).ir` | double | 1x1 | 2 |
| `S2.cells(2).iu` | double | 1x1 | 1 |
| `S2.cells(3).route` | char | 1x1 | X |
| `S2.cells(3).U` | double | 1x1 | 1.5 |
| `S2.cells(3).ir` | double | 1x1 | 1 |
| `S2.cells(3).iu` | double | 1x1 | 3 |
| `S2.cells(4).route` | char | 1x2 | XZ |
| `S2.cells(4).U` | double | 1x1 | 1.5 |
| `S2.cells(4).ir` | double | 1x1 | 2 |
| `S2.cells(4).iu` | double | 1x1 | 3 |
| `S2.cells(5).route` | char | 1x1 | H |
| `S2.cells(5).U` | double | 1x1 | 1.5 |
| `S2.cells(5).ir` | double | 1x1 | 3 |
| `S2.cells(5).iu` | double | 1x1 | 3 |
| `S2.cells(6).route` | char | 1x1 | X |
| `S2.cells(6).U` | double | 1x1 | 2 |
| `S2.cells(6).ir` | double | 1x1 | 1 |
| `S2.cells(6).iu` | double | 1x1 | 5 |
| `S2.cells(7).route` | char | 1x2 | XZ |
| `S2.cells(7).U` | double | 1x1 | 2 |
| `S2.cells(7).ir` | double | 1x1 | 2 |
| `S2.cells(7).iu` | double | 1x1 | 5 |
| `S2.cells(8).route` | char | 1x1 | H |
| `S2.cells(8).U` | double | 1x1 | 2 |
| `S2.cells(8).ir` | double | 1x1 | 3 |
| `S2.cells(8).iu` | double | 1x1 | 5 |
| `S2.certification` | char | 1x29 | SIMULATION_ONLY_NOT_CERTIFIED |
| `S2.clone_check.n_orig` | double | 1x1 | 233 |
| `S2.clone_check.n_reduced` | double | 1x1 | 233 |
| `S2.clone_check.match` | logical | 1x1 | 1 |
| `S2.clone_check.n_marked` | double | 1x1 | 18 |
| `S2.clone_check.detail` | char | 1x86 | clone reduces byte-for-byte to continuous_path_tracking.m (233 lines; 18 marker lines) |
| `S2.clone_check.first_diff` | double | 1x1 | 0 |
| `S2.fingerprints_after` | struct-array | 1x9 | 9 elements |
| `S2.fingerprints_after(1).name` | char | 1x26 | continuous_path_tracking.m |
| `S2.fingerprints_after(1).path` | char | 1x69 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\continuous_path_tracking.m |
| `S2.fingerprints_after(1).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_after(1).bytes` | double | 1x1 | 10845 |
| `S2.fingerprints_after(1).sha256` | char | 1x64 | e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b |
| `S2.fingerprints_after(2).name` | char | 1x16 | controller_law.m |
| `S2.fingerprints_after(2).path` | char | 1x59 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m |
| `S2.fingerprints_after(2).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_after(2).bytes` | double | 1x1 | 9402 |
| `S2.fingerprints_after(2).sha256` | char | 1x64 | 16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890 |
| `S2.fingerprints_after(3).name` | char | 1x14 | guidance_law.m |
| `S2.fingerprints_after(3).path` | char | 1x57 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law.m |
| `S2.fingerprints_after(3).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_after(3).bytes` | double | 1x1 | 14601 |
| `S2.fingerprints_after(3).sha256` | char | 1x64 | 2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3 |
| `S2.fingerprints_after(4).name` | char | 1x17 | init_parameters.m |
| `S2.fingerprints_after(4).path` | char | 1x60 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\init_parameters.m |
| `S2.fingerprints_after(4).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_after(4).bytes` | double | 1x1 | 4205 |
| `S2.fingerprints_after(4).sha256` | char | 1x64 | 09803f4956b64227403919229781086c367e620f5736cfd680d1b15081237a9a |
| `S2.fingerprints_after(5).name` | char | 1x32 | underwater777_vehicle_dynamics.m |
| `S2.fingerprints_after(5).path` | char | 1x75 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m |
| `S2.fingerprints_after(5).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_after(5).bytes` | double | 1x1 | 6065 |
| `S2.fingerprints_after(5).sha256` | char | 1x64 | 612e1009f7d65968109be1e8352d472730db65c08b0c15a17e6cde7a9f629558 |
| `S2.fingerprints_after(6).name` | char | 1x32 | compute_path_following_metrics.m |
| `S2.fingerprints_after(6).path` | char | 1x75 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\compute_path_following_metrics.m |
| `S2.fingerprints_after(6).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_after(6).bytes` | double | 1x1 | 11604 |
| `S2.fingerprints_after(6).sha256` | char | 1x64 | 6d3c2e77059d451056304aa61d86c55f78dd8367579c58ba40a20ea708bada05 |
| `S2.fingerprints_after(7).name` | char | 1x30 | compute_pitch_window_metrics.m |
| `S2.fingerprints_after(7).path` | char | 1x73 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\compute_pitch_window_metrics.m |
| `S2.fingerprints_after(7).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_after(7).bytes` | double | 1x1 | 5277 |
| `S2.fingerprints_after(7).sha256` | char | 1x64 | fa5919cc783f4d9e0a286d93938d5ec688b6cdb7481f3f6f9dcb675a14f74b94 |
| `S2.fingerprints_after(8).name` | char | 1x32 | generate_balanced_helical_path.m |
| `S2.fingerprints_after(8).path` | char | 1x75 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\generate_balanced_helical_path.m |
| `S2.fingerprints_after(8).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_after(8).bytes` | double | 1x1 | 564 |
| `S2.fingerprints_after(8).sha256` | char | 1x64 | 8773ecbebc7c12d6153b900913abf7a5e8c6847919a0ff15d5a315e8a8f837c1 |
| `S2.fingerprints_after(9).name` | char | 1x36 | suite_results\CODEX_VERTICAL_PLAN.md |
| `S2.fingerprints_after(9).path` | char | 1x79 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CODEX_VERTICAL_PLAN.md |
| `S2.fingerprints_after(9).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_after(9).bytes` | double | 1x1 | 43101 |
| `S2.fingerprints_after(9).sha256` | char | 1x64 | 000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c |
| `S2.fingerprints_before` | struct-array | 1x9 | 9 elements |
| `S2.fingerprints_before(1).name` | char | 1x26 | continuous_path_tracking.m |
| `S2.fingerprints_before(1).path` | char | 1x69 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\continuous_path_tracking.m |
| `S2.fingerprints_before(1).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_before(1).bytes` | double | 1x1 | 10845 |
| `S2.fingerprints_before(1).sha256` | char | 1x64 | e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b |
| `S2.fingerprints_before(2).name` | char | 1x16 | controller_law.m |
| `S2.fingerprints_before(2).path` | char | 1x59 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m |
| `S2.fingerprints_before(2).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_before(2).bytes` | double | 1x1 | 9402 |
| `S2.fingerprints_before(2).sha256` | char | 1x64 | 16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890 |
| `S2.fingerprints_before(3).name` | char | 1x14 | guidance_law.m |
| `S2.fingerprints_before(3).path` | char | 1x57 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law.m |
| `S2.fingerprints_before(3).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_before(3).bytes` | double | 1x1 | 14601 |
| `S2.fingerprints_before(3).sha256` | char | 1x64 | 2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3 |
| `S2.fingerprints_before(4).name` | char | 1x17 | init_parameters.m |
| `S2.fingerprints_before(4).path` | char | 1x60 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\init_parameters.m |
| `S2.fingerprints_before(4).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_before(4).bytes` | double | 1x1 | 4205 |
| `S2.fingerprints_before(4).sha256` | char | 1x64 | 09803f4956b64227403919229781086c367e620f5736cfd680d1b15081237a9a |
| `S2.fingerprints_before(5).name` | char | 1x32 | underwater777_vehicle_dynamics.m |
| `S2.fingerprints_before(5).path` | char | 1x75 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m |
| `S2.fingerprints_before(5).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_before(5).bytes` | double | 1x1 | 6065 |
| `S2.fingerprints_before(5).sha256` | char | 1x64 | 612e1009f7d65968109be1e8352d472730db65c08b0c15a17e6cde7a9f629558 |
| `S2.fingerprints_before(6).name` | char | 1x32 | compute_path_following_metrics.m |
| `S2.fingerprints_before(6).path` | char | 1x75 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\compute_path_following_metrics.m |
| `S2.fingerprints_before(6).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_before(6).bytes` | double | 1x1 | 11604 |
| `S2.fingerprints_before(6).sha256` | char | 1x64 | 6d3c2e77059d451056304aa61d86c55f78dd8367579c58ba40a20ea708bada05 |
| `S2.fingerprints_before(7).name` | char | 1x30 | compute_pitch_window_metrics.m |
| `S2.fingerprints_before(7).path` | char | 1x73 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\compute_pitch_window_metrics.m |
| `S2.fingerprints_before(7).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_before(7).bytes` | double | 1x1 | 5277 |
| `S2.fingerprints_before(7).sha256` | char | 1x64 | fa5919cc783f4d9e0a286d93938d5ec688b6cdb7481f3f6f9dcb675a14f74b94 |
| `S2.fingerprints_before(8).name` | char | 1x32 | generate_balanced_helical_path.m |
| `S2.fingerprints_before(8).path` | char | 1x75 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\generate_balanced_helical_path.m |
| `S2.fingerprints_before(8).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_before(8).bytes` | double | 1x1 | 564 |
| `S2.fingerprints_before(8).sha256` | char | 1x64 | 8773ecbebc7c12d6153b900913abf7a5e8c6847919a0ff15d5a315e8a8f837c1 |
| `S2.fingerprints_before(9).name` | char | 1x36 | suite_results\CODEX_VERTICAL_PLAN.md |
| `S2.fingerprints_before(9).path` | char | 1x79 | C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CODEX_VERTICAL_PLAN.md |
| `S2.fingerprints_before(9).exists` | logical | 1x1 | 1 |
| `S2.fingerprints_before(9).bytes` | double | 1x1 | 43101 |
| `S2.fingerprints_before(9).sha256` | char | 1x64 | 000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c |
| `S2.frozen.HG.X.pitch_mae` | double | 1x1 | 0.1 |
| `S2.frozen.HG.X.pitch_p95` | double | 1x1 | 0.5 |
| `S2.frozen.HG.X.gamma_mae` | double | 1x1 | 0.5 |
| `S2.frozen.HG.X.gamma_p95` | double | 1x1 | 1 |
| `S2.frozen.HG.XZ.pitch_mae` | double | 1x1 | 0.3 |
| `S2.frozen.HG.XZ.pitch_p95` | double | 1x1 | 0.5 |
| `S2.frozen.HG.XZ.gamma_mae` | double | 1x1 | 1 |
| `S2.frozen.HG.XZ.gamma_p95` | double | 1x1 | 1.5 |
| `S2.frozen.HG.H.pitch_mae` | double | 1x1 | 0.3 |
| `S2.frozen.HG.H.pitch_p95` | double | 1x1 | 0.5 |
| `S2.frozen.HG.H.gamma_mae` | double | 1x1 | 1.5 |
| `S2.frozen.HG.H.gamma_p95` | double | 1x1 | 2.5 |
| `S2.frozen.HG.H.yaw_mae` | double | 1x1 | 1 |
| `S2.frozen.HG.H.yaw_p95` | double | 1x1 | 2 |
| `S2.frozen.HG.elev_sat` | double | 1x1 | 1 |
| `S2.frozen.HG.rud_sat_ss` | double | 1x1 | 1 |
| `S2.frozen.HG.rud_sat_full` | double | 1x1 | 1 |
| `S2.frozen.HG.chatter` | double | 1x1 | 0.2 |
| `S2.frozen.HG.ratio_lo` | double | 1x1 | 0.98 |
| `S2.frozen.HG.ratio_hi` | double | 1x1 | 1.02 |
| `S2.frozen.HG.rate_util` | double | 1x1 | 1 |
| `S2.frozen.HG.thrust_sat` | double | 1x1 | 1 |
| `S2.frozen.HG.trim_tol` | double | 1x1 | 0.01 |
| `S2.frozen.HG.phi_eq.X` | double | 1x1 | 0 |
| `S2.frozen.HG.phi_eq.XZ` | double | 1x1 | 0 |
| `S2.frozen.HG.phi_eq.H` | double | 1x1 | 0.0255 |
| `S2.frozen.lim.dr_max` | double | 1x1 | 0.436332 |
| `S2.frozen.lim.de_max` | double | 1x1 | 0.261799 |
| `S2.frozen.lim.dr_rate` | double | 1x1 | 0.698132 |
| `S2.frozen.lim.de_rate` | double | 1x1 | 0.698132 |
| `S2.frozen.lim.near_frac` | double | 1x1 | 0.8 |
| `S2.frozen.lim.thrust_max` | double | 1x1 | 300 |
| `S2.frozen.lim.thrust_min` | double | 1x1 | -100 |
| `S2.frozen.Tfin` | double | 1x3 | 18 22 45 |
| `S2.frozen.win_mode` | cell | 1x3 | 3 elements |
| `S2.frozen.win_mode{1}` | char | 1x10 | first_hold |
| `S2.frozen.win_mode{2}` | char | 1x10 | persistent |
| `S2.frozen.win_mode{3}` | char | 1x10 | persistent |
| `S2.frozen.lambda0` | double | 1x3 | 0.25 0 0.25 |
| `S2.frozen.seed_used` | double | 1x1 | 0 |
| `S2.frozen.Kp_roll` | double | 1x1 | 0.605072 |
| `S2.frozen.Kp_x` | double | 1x1 | 25 |
| `S2.frozen.thrust_trim` | double | 1x1 | 13.4 |
| `S2.frozen.parity_tol` | double | 1x1 | 1e-12 |
| `S2.gate4` | char | 1x11 | shadow_only |
| `S2.gates.G_single_matlab.pass` | logical | 1x1 | 1 |
| `S2.gates.G_single_matlab.detail` | char | 1x25 | pid=15892 prior_lock=0 () |
| `S2.gates.G_clone_minimal_diff.pass` | logical | 1x1 | 1 |
| `S2.gates.G_clone_minimal_diff.detail` | char | 1x86 | clone reduces byte-for-byte to continuous_path_tracking.m (233 lines; 18 marker lines) |
| `S2.gates.G_accepted_set_consistent.pass` | logical | 1x1 | 1 |
| `S2.gates.G_accepted_set_consistent.detail` | char | 1x50 | all declared accepted cells FEASIBLE in frozen MAT |
| `S2.gates.G_parity_accepted_baseline.pass` | logical | 1x1 | 1 |
| `S2.gates.G_parity_accepted_baseline.detail` | char | 1x58 | cells=8 exact=1 within_tol(1e-12)=1 max_sig_diff=0.000e+00 |
| `S2.gates.G_production_plan_fingerprints.pass` | logical | 1x1 | 1 |
| `S2.gates.G_production_plan_fingerprints.detail` | char | 1x45 | 9 files byte-identical before/after (SHA-256) |
| `S2.gates.G_finite_states.pass` | logical | 1x1 | 1 |
| `S2.gates.G_finite_states.detail` | char | 1x29 | 32 runs, all finite+bounded=1 |
| `S2.gates.G_frozen_tracking_actuator.pass` | logical | 1x1 | 1 |
| `S2.gates.G_frozen_tracking_actuator.detail` | char | 1x98 | ideal-hook cells FEASIBLE=8/8; variant cells FEASIBLE=24/24 (variant loss is a RESULT, not a gate) |
| `S2.gates.G_thrust_limits.pass` | logical | 1x1 | 1 |
| `S2.gates.G_thrust_limits.detail` | char | 1x91 | realized thrust inside declared [T_min,T_max] for 32/32 runs; T_real span [0.710, 28.480] N |
| `S2.gates.G_battery_current_conditional.pass` | logical | 1x1 | 1 |
| `S2.gates.G_battery_current_conditional.detail` | char | 1x162 | CONDITIONAL on ASSUMED eta in [0.35,0.60] and V_bus {24 48} V: power/energy/current finite, non-negative, ordered for 32/32 runs. ... |
| `S2.gates.G_deterministic_replay.pass` | logical | 1x1 | 1 |
| `S2.gates.G_deterministic_replay.detail` | char | 1x76 | X@1.00 variant=nominal bitwise_max_diff=0.000e+00 over 360 decimated samples |
| `S2.gates.G_pareto_reported.pass` | logical | 1x1 | 1 |
| `S2.gates.G_pareto_reported.detail` | char | 1x42 | 9 nondominated (variant,cell) points of 32 |
| `S2.gates.G_artifacts_readable.pass` | logical | 1x1 | 1 |
| `S2.gates.G_artifacts_readable.detail` | char | 1x57 | MD/MAT/PNG re-opened and structurally verified in-process |
| `S2.ideal_runs` | struct-array | 8x1 | 8 elements |
| `S2.ideal_runs(1).route` | char | 1x1 | X |
| `S2.ideal_runs(1).U` | double | 1x1 | 1 |
| `S2.ideal_runs(1).variant` | char | 1x5 | ideal |
| `S2.ideal_runs(1).prop.name` | char | 1x5 | ideal |
| `S2.ideal_runs(1).prop.ideal` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).prop.tau` | double | 1x1 | 0 |
| `S2.ideal_runs(1).prop.gain` | double | 1x1 | 1 |
| `S2.ideal_runs(1).prop.slew` | double | 1x1 | Inf |
| `S2.ideal_runs(1).prop.T_min` | double | 1x1 | -Inf |
| `S2.ideal_runs(1).prop.T_max` | double | 1x1 | Inf |
| `S2.ideal_runs(1).prop.why` | char | 1x53 | exact passthrough; parity hook against accepted audit |
| `S2.ideal_runs(1).feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).first_limit` | char | 1x4 | none |
| `S2.ideal_runs(1).worst_margin` | double | 1x1 | 0.0597422 |
| `S2.ideal_runs(1).speed_mae` | double | 1x1 | 0.317449 |
| `S2.ideal_runs(1).speed_bias` | double | 1x1 | -0.317449 |
| `S2.ideal_runs(1).theta_mae` | double | 1x1 | 0.0402578 |
| `S2.ideal_runs(1).gamma_mae` | double | 1x1 | 0.377924 |
| `S2.ideal_runs(1).yaw_mae` | double | 1x1 | 0 |
| `S2.ideal_runs(1).cte` | double | 1x1 | 0.250143 |
| `S2.ideal_runs(1).bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).finite` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).T_cmd_min` | double | 1x1 | 5.42863 |
| `S2.ideal_runs(1).T_cmd_max` | double | 1x1 | 25.8906 |
| `S2.ideal_runs(1).T_real_min` | double | 1x1 | 5.42863 |
| `S2.ideal_runs(1).T_real_max` | double | 1x1 | 25.8906 |
| `S2.ideal_runs(1).T_lim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).slew_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(1).sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(1).P_lo_mean` | double | 1x1 | 16.5468 |
| `S2.ideal_runs(1).P_hi_mean` | double | 1x1 | 28.3659 |
| `S2.ideal_runs(1).P_lo_p95` | double | 1x1 | 16.636 |
| `S2.ideal_runs(1).P_hi_p95` | double | 1x1 | 28.5189 |
| `S2.ideal_runs(1).E_lo_Wh` | double | 1x1 | 0.0941988 |
| `S2.ideal_runs(1).E_hi_Wh` | double | 1x1 | 0.161484 |
| `S2.ideal_runs(1).E_mid_Wh` | double | 1x1 | 0.127841 |
| `S2.ideal_runs(1).I_hi_24V` | double | 1x1 | 1.18829 |
| `S2.ideal_runs(1).I_hi_48V` | double | 1x1 | 0.594144 |
| `S2.ideal_runs(1).cond_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).sig.t` | double | 360x1 | n=360 min=0.025 max=17.975 mean=9 |
| `S2.ideal_runs(1).sig.T_cmd` | double | 360x1 | n=360 min=5.42863 max=25.8906 mean=6.65423 |
| `S2.ideal_runs(1).sig.T_real` | double | 360x1 | n=360 min=5.42863 max=25.8906 mean=6.65423 |
| `S2.ideal_runs(1).sig.u_body` | double | 360x1 | n=360 min=1.01894 max=1.81848 mean=1.7706 |
| `S2.ideal_runs(1).sig.P_lo` | double | 360x1 | n=360 min=16.4531 max=43.9683 mean=18.9008 |
| `S2.ideal_runs(1).sig.P_hi` | double | 360x1 | n=360 min=28.2053 max=75.3742 mean=32.4014 |
| `S2.ideal_runs(1).sig.ds` | double | 1x1 | 2 |
| `S2.ideal_runs(1).M.speed.signed_mean` | double | 1x1 | -0.317449 |
| `S2.ideal_runs(1).M.speed.mae` | double | 1x1 | 0.317449 |
| `S2.ideal_runs(1).M.speed.p95` | double | 1x1 | 0.318834 |
| `S2.ideal_runs(1).M.speed.rms` | double | 1x1 | 0.317451 |
| `S2.ideal_runs(1).M.speed.n` | double | 1x1 | 521 |
| `S2.ideal_runs(1).M.speed.u_mean` | double | 1x1 | 1.81707 |
| `S2.ideal_runs(1).M.speed.u_ref_mean` | double | 1x1 | 1.49963 |
| `S2.ideal_runs(1).M.theta.mae_deg` | double | 1x1 | 0.0402578 |
| `S2.ideal_runs(1).M.theta.p95_deg` | double | 1x1 | 0.0629817 |
| `S2.ideal_runs(1).M.theta.rms_deg` | double | 1x1 | 0.0434156 |
| `S2.ideal_runs(1).M.theta.n` | double | 1x1 | 521 |
| `S2.ideal_runs(1).M.gamma.mae_deg` | double | 1x1 | 0.377924 |
| `S2.ideal_runs(1).M.gamma.p95_deg` | double | 1x1 | 0.827819 |
| `S2.ideal_runs(1).M.gamma.rms_deg` | double | 1x1 | 0.447613 |
| `S2.ideal_runs(1).M.gamma.n` | double | 1x1 | 521 |
| `S2.ideal_runs(1).M.yaw.mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.yaw.p95_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.yaw.rms_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.yaw.n` | double | 1x1 | 521 |
| `S2.ideal_runs(1).M.yaw.rudder_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.yaw.rudder_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.yaw.ratio_r_Uh_kappa` | double | 1x1 | NaN |
| `S2.ideal_runs(1).M.yaw.n_ratio_valid` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.roll.tilde_mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.roll.p_rms_dps` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.path.mean_cte` | double | 1x1 | 0.250143 |
| `S2.ideal_runs(1).M.path.max_cte` | double | 1x1 | 0.277724 |
| `S2.ideal_runs(1).M.path.pm_mean_cte` | double | 1x1 | 0.250143 |
| `S2.ideal_runs(1).M.act.de_mag_util` | double | 1x1 | 0.320496 |
| `S2.ideal_runs(1).M.act.dr_mag_util` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.act.thr_mag_util` | double | 1x1 | 0.0182126 |
| `S2.ideal_runs(1).M.act.de_rate_util` | double | 1x1 | 0.00529596 |
| `S2.ideal_runs(1).M.act.dr_rate_util` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.act.thr_rate_util` | double | 1x1 | 0.000105009 |
| `S2.ideal_runs(1).M.act.de_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.act.dr_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.act.dr_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.act.thr_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.act.chatter_dps` | double | 1x1 | 0.161405 |
| `S2.ideal_runs(1).M.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.persistent_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.sim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.sim_err` | char | 0x0 |  |
| `S2.ideal_runs(1).M.trim.name` | char | 1x5 | level |
| `S2.ideal_runs(1).M.trim.class` | char | 1x23 | steady_translating_trim |
| `S2.ideal_runs(1).M.trim.provenance` | char | 1x11 | PLANT_SOLVE |
| `S2.ideal_runs(1).M.trim.Ufix` | double | 1x1 | 1 |
| `S2.ideal_runs(1).M.trim.slope` | double | 1x1 | 0 |
| `S2.ideal_runs(1).M.trim.x_star` | double | 12x1 | n=12 min=-0.0744258 max=1 mean=0.0709404 |
| `S2.ideal_runs(1).M.trim.u_star` | double | 3x1 | 0 -0.221162 1.9911 |
| `S2.ideal_runs(1).M.trim.Treq` | double | 1x1 | 1.9911 |
| `S2.ideal_runs(1).M.trim.norm_dyn` | double | 1x1 | 3.57237e-11 |
| `S2.ideal_runs(1).M.trim.residual.nu_dot` | double | 6x1 | 1.02438e-13 0 8.97773e-12 0 -3.90191e-12 0 |
| `S2.ideal_runs(1).M.trim.residual.eta_dot` | double | 6x1 | 1.00277 0 5.4487e-13 0 8.58837e-23 0 |
| `S2.ideal_runs(1).M.trim.residual.norm_dyn` | double | 1x1 | 3.57237e-11 |
| `S2.ideal_runs(1).M.trim.residual.att_rate` | double | 3x1 | 0 8.58837e-23 0 |
| `S2.ideal_runs(1).M.trim.pass` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.trim.exitflag` | double | 1x1 | 1 |
| `S2.ideal_runs(1).M.trim.documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.trim.slope_err` | double | 1x1 | 5.4487e-13 |
| `S2.ideal_runs(1).M.Uref` | double | 1x1 | 1 |
| `S2.ideal_runs(1).M.route` | char | 1x1 | X |
| `S2.ideal_runs(1).M.feas.gates.trim_documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.trim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.pitch_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.pitch_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.gamma_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.gamma_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.yaw_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.elev_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.thrust_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.dr_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.gates.de_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.first_limit` | char | 1x4 | none |
| `S2.ideal_runs(1).M.feas.feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.margin.pitch_mae` | double | 1x1 | 0.0597422 |
| `S2.ideal_runs(1).M.feas.margin.pitch_p95` | double | 1x1 | 0.437018 |
| `S2.ideal_runs(1).M.feas.margin.gamma_mae` | double | 1x1 | 0.122076 |
| `S2.ideal_runs(1).M.feas.margin.gamma_p95` | double | 1x1 | 0.172181 |
| `S2.ideal_runs(1).M.feas.margin.elev_sat` | double | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.margin.de_rate` | double | 1x1 | 0.994704 |
| `S2.ideal_runs(1).M.feas.margin.dr_rate` | double | 1x1 | 1 |
| `S2.ideal_runs(1).M.feas.worst_margin` | double | 1x1 | 0.0597422 |
| `S2.ideal_runs(2).route` | char | 1x2 | XZ |
| `S2.ideal_runs(2).U` | double | 1x1 | 1 |
| `S2.ideal_runs(2).variant` | char | 1x5 | ideal |
| `S2.ideal_runs(2).prop.name` | char | 1x5 | ideal |
| `S2.ideal_runs(2).prop.ideal` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).prop.tau` | double | 1x1 | 0 |
| `S2.ideal_runs(2).prop.gain` | double | 1x1 | 1 |
| `S2.ideal_runs(2).prop.slew` | double | 1x1 | Inf |
| `S2.ideal_runs(2).prop.T_min` | double | 1x1 | -Inf |
| `S2.ideal_runs(2).prop.T_max` | double | 1x1 | Inf |
| `S2.ideal_runs(2).prop.why` | char | 1x53 | exact passthrough; parity hook against accepted audit |
| `S2.ideal_runs(2).feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).first_limit` | char | 1x4 | none |
| `S2.ideal_runs(2).worst_margin` | double | 1x1 | 0.0868412 |
| `S2.ideal_runs(2).speed_mae` | double | 1x1 | 0.254676 |
| `S2.ideal_runs(2).speed_bias` | double | 1x1 | -0.254676 |
| `S2.ideal_runs(2).theta_mae` | double | 1x1 | 0.136889 |
| `S2.ideal_runs(2).gamma_mae` | double | 1x1 | 0.359709 |
| `S2.ideal_runs(2).yaw_mae` | double | 1x1 | 0 |
| `S2.ideal_runs(2).cte` | double | 1x1 | 0.364609 |
| `S2.ideal_runs(2).bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).finite` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).T_cmd_min` | double | 1x1 | 6.99912 |
| `S2.ideal_runs(2).T_cmd_max` | double | 1x1 | 25.8906 |
| `S2.ideal_runs(2).T_real_min` | double | 1x1 | 6.99912 |
| `S2.ideal_runs(2).T_real_max` | double | 1x1 | 25.8906 |
| `S2.ideal_runs(2).T_lim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).slew_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(2).sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(2).P_lo_mean` | double | 1x1 | 20.5635 |
| `S2.ideal_runs(2).P_hi_mean` | double | 1x1 | 35.2518 |
| `S2.ideal_runs(2).P_lo_p95` | double | 1x1 | 20.6504 |
| `S2.ideal_runs(2).P_hi_p95` | double | 1x1 | 35.4007 |
| `S2.ideal_runs(2).E_lo_Wh` | double | 1x1 | 0.135321 |
| `S2.ideal_runs(2).E_hi_Wh` | double | 1x1 | 0.231979 |
| `S2.ideal_runs(2).E_mid_Wh` | double | 1x1 | 0.18365 |
| `S2.ideal_runs(2).I_hi_24V` | double | 1x1 | 1.47503 |
| `S2.ideal_runs(2).I_hi_48V` | double | 1x1 | 0.737514 |
| `S2.ideal_runs(2).cond_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).sig.t` | double | 440x1 | n=440 min=0.025 max=21.975 mean=11 |
| `S2.ideal_runs(2).sig.T_cmd` | double | 440x1 | n=440 min=6.99912 max=25.8906 mean=7.92578 |
| `S2.ideal_runs(2).sig.T_real` | double | 440x1 | n=440 min=6.99912 max=25.8906 mean=7.92578 |
| `S2.ideal_runs(2).sig.u_body` | double | 440x1 | n=440 min=1.01736 max=1.75566 mean=1.71946 |
| `S2.ideal_runs(2).sig.P_lo` | double | 440x1 | n=440 min=20.4801 max=43.9003 mean=22.1933 |
| `S2.ideal_runs(2).sig.P_hi` | double | 440x1 | n=440 min=35.1088 max=75.2576 mean=38.0457 |
| `S2.ideal_runs(2).sig.ds` | double | 1x1 | 2 |
| `S2.ideal_runs(2).M.speed.signed_mean` | double | 1x1 | -0.254676 |
| `S2.ideal_runs(2).M.speed.mae` | double | 1x1 | 0.254676 |
| `S2.ideal_runs(2).M.speed.p95` | double | 1x1 | 0.256015 |
| `S2.ideal_runs(2).M.speed.rms` | double | 1x1 | 0.254678 |
| `S2.ideal_runs(2).M.speed.n` | double | 1x1 | 598 |
| `S2.ideal_runs(2).M.speed.u_mean` | double | 1x1 | 1.7543 |
| `S2.ideal_runs(2).M.speed.u_ref_mean` | double | 1x1 | 1.49963 |
| `S2.ideal_runs(2).M.theta.mae_deg` | double | 1x1 | 0.136889 |
| `S2.ideal_runs(2).M.theta.p95_deg` | double | 1x1 | 0.413159 |
| `S2.ideal_runs(2).M.theta.rms_deg` | double | 1x1 | 0.193034 |
| `S2.ideal_runs(2).M.theta.n` | double | 1x1 | 598 |
| `S2.ideal_runs(2).M.gamma.mae_deg` | double | 1x1 | 0.359709 |
| `S2.ideal_runs(2).M.gamma.p95_deg` | double | 1x1 | 0.702462 |
| `S2.ideal_runs(2).M.gamma.rms_deg` | double | 1x1 | 0.414539 |
| `S2.ideal_runs(2).M.gamma.n` | double | 1x1 | 598 |
| `S2.ideal_runs(2).M.yaw.mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.yaw.p95_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.yaw.rms_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.yaw.n` | double | 1x1 | 681 |
| `S2.ideal_runs(2).M.yaw.rudder_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.yaw.rudder_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.yaw.ratio_r_Uh_kappa` | double | 1x1 | NaN |
| `S2.ideal_runs(2).M.yaw.n_ratio_valid` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.roll.tilde_mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.roll.p_rms_dps` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.path.mean_cte` | double | 1x1 | 0.364609 |
| `S2.ideal_runs(2).M.path.max_cte` | double | 1x1 | 0.402802 |
| `S2.ideal_runs(2).M.path.pm_mean_cte` | double | 1x1 | 0.388689 |
| `S2.ideal_runs(2).M.act.de_mag_util` | double | 1x1 | 0.0820006 |
| `S2.ideal_runs(2).M.act.dr_mag_util` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.act.thr_mag_util` | double | 1x1 | 0.0234436 |
| `S2.ideal_runs(2).M.act.de_rate_util` | double | 1x1 | 0.00516217 |
| `S2.ideal_runs(2).M.act.dr_rate_util` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.act.thr_rate_util` | double | 1x1 | 2.04233e-05 |
| `S2.ideal_runs(2).M.act.de_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.act.dr_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.act.dr_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.act.thr_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(2).M.act.chatter_dps` | double | 1x1 | 0.177873 |
| `S2.ideal_runs(2).M.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.persistent_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.sim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.sim_err` | char | 0x0 |  |
| `S2.ideal_runs(2).M.trim.name` | char | 1x5 | climb |
| `S2.ideal_runs(2).M.trim.class` | char | 1x23 | steady_translating_trim |
| `S2.ideal_runs(2).M.trim.provenance` | char | 1x11 | PLANT_SOLVE |
| `S2.ideal_runs(2).M.trim.Ufix` | double | 1x1 | 1 |
| `S2.ideal_runs(2).M.trim.slope` | double | 1x1 | 0.4 |
| `S2.ideal_runs(2).M.trim.x_star` | double | 12x1 | n=12 min=-0.488887 max=1 mean=0.0335256 |
| `S2.ideal_runs(2).M.trim.u_star` | double | 3x1 | 0 0.0257758 3.96822 |
| `S2.ideal_runs(2).M.trim.Treq` | double | 1x1 | 3.96822 |
| `S2.ideal_runs(2).M.trim.norm_dyn` | double | 1x1 | 5.4057e-16 |
| `S2.ideal_runs(2).M.trim.residual.nu_dot` | double | 6x1 | -1.72419e-18 0 -8.84884e-17 0 9.06003e-17 0 |
| `S2.ideal_runs(2).M.trim.residual.eta_dot` | double | 6x1 | 0.933957 0 0.373583 0 -1.33754e-27 0 |
| `S2.ideal_runs(2).M.trim.residual.norm_dyn` | double | 1x1 | 5.4057e-16 |
| `S2.ideal_runs(2).M.trim.residual.att_rate` | double | 3x1 | 0 -1.33754e-27 0 |
| `S2.ideal_runs(2).M.trim.pass` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.trim.exitflag` | double | 1x1 | 1 |
| `S2.ideal_runs(2).M.trim.documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.trim.slope_err` | double | 1x1 | 5.55112e-17 |
| `S2.ideal_runs(2).M.Uref` | double | 1x1 | 1 |
| `S2.ideal_runs(2).M.route` | char | 1x2 | XZ |
| `S2.ideal_runs(2).M.feas.gates.trim_documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.trim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.pitch_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.pitch_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.gamma_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.gamma_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.yaw_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.elev_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.thrust_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.dr_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.gates.de_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.first_limit` | char | 1x4 | none |
| `S2.ideal_runs(2).M.feas.feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.margin.pitch_mae` | double | 1x1 | 0.163111 |
| `S2.ideal_runs(2).M.feas.margin.pitch_p95` | double | 1x1 | 0.0868412 |
| `S2.ideal_runs(2).M.feas.margin.gamma_mae` | double | 1x1 | 0.640291 |
| `S2.ideal_runs(2).M.feas.margin.gamma_p95` | double | 1x1 | 0.797538 |
| `S2.ideal_runs(2).M.feas.margin.elev_sat` | double | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.margin.de_rate` | double | 1x1 | 0.994838 |
| `S2.ideal_runs(2).M.feas.margin.dr_rate` | double | 1x1 | 1 |
| `S2.ideal_runs(2).M.feas.worst_margin` | double | 1x1 | 0.0868412 |
| `S2.ideal_runs(3).route` | char | 1x1 | X |
| `S2.ideal_runs(3).U` | double | 1x1 | 1.5 |
| `S2.ideal_runs(3).variant` | char | 1x5 | ideal |
| `S2.ideal_runs(3).prop.name` | char | 1x5 | ideal |
| `S2.ideal_runs(3).prop.ideal` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).prop.tau` | double | 1x1 | 0 |
| `S2.ideal_runs(3).prop.gain` | double | 1x1 | 1 |
| `S2.ideal_runs(3).prop.slew` | double | 1x1 | Inf |
| `S2.ideal_runs(3).prop.T_min` | double | 1x1 | -Inf |
| `S2.ideal_runs(3).prop.T_max` | double | 1x1 | Inf |
| `S2.ideal_runs(3).prop.why` | char | 1x53 | exact passthrough; parity hook against accepted audit |
| `S2.ideal_runs(3).feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).first_limit` | char | 1x4 | none |
| `S2.ideal_runs(3).worst_margin` | double | 1x1 | 0.0889646 |
| `S2.ideal_runs(3).speed_mae` | double | 1x1 | 0.317556 |
| `S2.ideal_runs(3).speed_bias` | double | 1x1 | -0.317556 |
| `S2.ideal_runs(3).theta_mae` | double | 1x1 | 0.0110354 |
| `S2.ideal_runs(3).gamma_mae` | double | 1x1 | 0.330526 |
| `S2.ideal_runs(3).yaw_mae` | double | 1x1 | 0 |
| `S2.ideal_runs(3).cte` | double | 1x1 | 0.246718 |
| `S2.ideal_runs(3).bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).finite` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).T_cmd_min` | double | 1x1 | 5.42947 |
| `S2.ideal_runs(3).T_cmd_max` | double | 1x1 | 13.3906 |
| `S2.ideal_runs(3).T_real_min` | double | 1x1 | 5.42947 |
| `S2.ideal_runs(3).T_real_max` | double | 1x1 | 13.3906 |
| `S2.ideal_runs(3).T_lim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).slew_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(3).sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(3).P_lo_mean` | double | 1x1 | 16.5396 |
| `S2.ideal_runs(3).P_hi_mean` | double | 1x1 | 28.3537 |
| `S2.ideal_runs(3).P_lo_p95` | double | 1x1 | 16.6304 |
| `S2.ideal_runs(3).P_hi_p95` | double | 1x1 | 28.5093 |
| `S2.ideal_runs(3).E_lo_Wh` | double | 1x1 | 0.0877794 |
| `S2.ideal_runs(3).E_hi_Wh` | double | 1x1 | 0.150479 |
| `S2.ideal_runs(3).E_mid_Wh` | double | 1x1 | 0.119129 |
| `S2.ideal_runs(3).I_hi_24V` | double | 1x1 | 1.18789 |
| `S2.ideal_runs(3).I_hi_48V` | double | 1x1 | 0.593944 |
| `S2.ideal_runs(3).cond_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).sig.t` | double | 360x1 | n=360 min=0.025 max=17.975 mean=9 |
| `S2.ideal_runs(3).sig.T_cmd` | double | 360x1 | n=360 min=5.42947 max=13.3906 mean=5.90379 |
| `S2.ideal_runs(3).sig.T_real` | double | 360x1 | n=360 min=5.42947 max=13.3906 mean=5.90379 |
| `S2.ideal_runs(3).sig.u_body` | double | 360x1 | n=360 min=1.50759 max=1.81845 mean=1.79992 |
| `S2.ideal_runs(3).sig.P_lo` | double | 360x1 | n=360 min=16.4553 max=33.6459 mean=17.6027 |
| `S2.ideal_runs(3).sig.P_hi` | double | 360x1 | n=360 min=28.2091 max=57.6786 mean=30.1761 |
| `S2.ideal_runs(3).sig.ds` | double | 1x1 | 2 |
| `S2.ideal_runs(3).M.speed.signed_mean` | double | 1x1 | -0.317556 |
| `S2.ideal_runs(3).M.speed.mae` | double | 1x1 | 0.317556 |
| `S2.ideal_runs(3).M.speed.p95` | double | 1x1 | 0.318803 |
| `S2.ideal_runs(3).M.speed.rms` | double | 1x1 | 0.317557 |
| `S2.ideal_runs(3).M.speed.n` | double | 1x1 | 521 |
| `S2.ideal_runs(3).M.speed.u_mean` | double | 1x1 | 1.81718 |
| `S2.ideal_runs(3).M.speed.u_ref_mean` | double | 1x1 | 1.49963 |
| `S2.ideal_runs(3).M.theta.mae_deg` | double | 1x1 | 0.0110354 |
| `S2.ideal_runs(3).M.theta.p95_deg` | double | 1x1 | 0.0418939 |
| `S2.ideal_runs(3).M.theta.rms_deg` | double | 1x1 | 0.0164367 |
| `S2.ideal_runs(3).M.theta.n` | double | 1x1 | 521 |
| `S2.ideal_runs(3).M.gamma.mae_deg` | double | 1x1 | 0.330526 |
| `S2.ideal_runs(3).M.gamma.p95_deg` | double | 1x1 | 0.703235 |
| `S2.ideal_runs(3).M.gamma.rms_deg` | double | 1x1 | 0.38583 |
| `S2.ideal_runs(3).M.gamma.n` | double | 1x1 | 521 |
| `S2.ideal_runs(3).M.yaw.mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.yaw.p95_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.yaw.rms_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.yaw.n` | double | 1x1 | 521 |
| `S2.ideal_runs(3).M.yaw.rudder_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.yaw.rudder_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.yaw.ratio_r_Uh_kappa` | double | 1x1 | NaN |
| `S2.ideal_runs(3).M.yaw.n_ratio_valid` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.roll.tilde_mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.roll.p_rms_dps` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.path.mean_cte` | double | 1x1 | 0.246718 |
| `S2.ideal_runs(3).M.path.max_cte` | double | 1x1 | 0.269856 |
| `S2.ideal_runs(3).M.path.pm_mean_cte` | double | 1x1 | 0.246718 |
| `S2.ideal_runs(3).M.act.de_mag_util` | double | 1x1 | 0.319595 |
| `S2.ideal_runs(3).M.act.dr_mag_util` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.act.thr_mag_util` | double | 1x1 | 0.0182037 |
| `S2.ideal_runs(3).M.act.de_rate_util` | double | 1x1 | 0.00499454 |
| `S2.ideal_runs(3).M.act.dr_rate_util` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.act.thr_rate_util` | double | 1x1 | 3.67023e-05 |
| `S2.ideal_runs(3).M.act.de_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.act.dr_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.act.dr_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.act.thr_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.act.chatter_dps` | double | 1x1 | 0.153014 |
| `S2.ideal_runs(3).M.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.persistent_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.sim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.sim_err` | char | 0x0 |  |
| `S2.ideal_runs(3).M.trim.name` | char | 1x5 | level |
| `S2.ideal_runs(3).M.trim.class` | char | 1x23 | steady_translating_trim |
| `S2.ideal_runs(3).M.trim.provenance` | char | 1x11 | PLANT_SOLVE |
| `S2.ideal_runs(3).M.trim.Ufix` | double | 1x1 | 1.5 |
| `S2.ideal_runs(3).M.trim.slope` | double | 1x1 | 0 |
| `S2.ideal_runs(3).M.trim.x_star` | double | 12x1 | n=12 min=-0.0500278 max=1.5 mean=0.118053 |
| `S2.ideal_runs(3).M.trim.u_star` | double | 3x1 | 0 -0.116328 3.81167 |
| `S2.ideal_runs(3).M.trim.Treq` | double | 1x1 | 3.81167 |
| `S2.ideal_runs(3).M.trim.norm_dyn` | double | 1x1 | 2.72939e-13 |
| `S2.ideal_runs(3).M.trim.residual.nu_dot` | double | 6x1 | 6.42504e-16 0 6.90016e-14 0 -2.93888e-14 0 |
| `S2.ideal_runs(3).M.trim.residual.eta_dot` | double | 6x1 | 1.50083 0 4.16334e-17 0 2.63356e-24 0 |
| `S2.ideal_runs(3).M.trim.residual.norm_dyn` | double | 1x1 | 2.72939e-13 |
| `S2.ideal_runs(3).M.trim.residual.att_rate` | double | 3x1 | 0 2.63356e-24 0 |
| `S2.ideal_runs(3).M.trim.pass` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.trim.exitflag` | double | 1x1 | 1 |
| `S2.ideal_runs(3).M.trim.documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.trim.slope_err` | double | 1x1 | 4.16334e-17 |
| `S2.ideal_runs(3).M.Uref` | double | 1x1 | 1.5 |
| `S2.ideal_runs(3).M.route` | char | 1x1 | X |
| `S2.ideal_runs(3).M.feas.gates.trim_documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.trim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.pitch_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.pitch_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.gamma_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.gamma_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.yaw_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.elev_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.thrust_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.dr_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.gates.de_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.first_limit` | char | 1x4 | none |
| `S2.ideal_runs(3).M.feas.feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.margin.pitch_mae` | double | 1x1 | 0.0889646 |
| `S2.ideal_runs(3).M.feas.margin.pitch_p95` | double | 1x1 | 0.458106 |
| `S2.ideal_runs(3).M.feas.margin.gamma_mae` | double | 1x1 | 0.169474 |
| `S2.ideal_runs(3).M.feas.margin.gamma_p95` | double | 1x1 | 0.296765 |
| `S2.ideal_runs(3).M.feas.margin.elev_sat` | double | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.margin.de_rate` | double | 1x1 | 0.995005 |
| `S2.ideal_runs(3).M.feas.margin.dr_rate` | double | 1x1 | 1 |
| `S2.ideal_runs(3).M.feas.worst_margin` | double | 1x1 | 0.0889646 |
| `S2.ideal_runs(4).route` | char | 1x2 | XZ |
| `S2.ideal_runs(4).U` | double | 1x1 | 1.5 |
| `S2.ideal_runs(4).variant` | char | 1x5 | ideal |
| `S2.ideal_runs(4).prop.name` | char | 1x5 | ideal |
| `S2.ideal_runs(4).prop.ideal` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).prop.tau` | double | 1x1 | 0 |
| `S2.ideal_runs(4).prop.gain` | double | 1x1 | 1 |
| `S2.ideal_runs(4).prop.slew` | double | 1x1 | Inf |
| `S2.ideal_runs(4).prop.T_min` | double | 1x1 | -Inf |
| `S2.ideal_runs(4).prop.T_max` | double | 1x1 | Inf |
| `S2.ideal_runs(4).prop.why` | char | 1x53 | exact passthrough; parity hook against accepted audit |
| `S2.ideal_runs(4).feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).first_limit` | char | 1x4 | none |
| `S2.ideal_runs(4).worst_margin` | double | 1x1 | 0.0976224 |
| `S2.ideal_runs(4).speed_mae` | double | 1x1 | 0.255 |
| `S2.ideal_runs(4).speed_bias` | double | 1x1 | -0.255 |
| `S2.ideal_runs(4).theta_mae` | double | 1x1 | 0.121421 |
| `S2.ideal_runs(4).gamma_mae` | double | 1x1 | 0.418212 |
| `S2.ideal_runs(4).yaw_mae` | double | 1x1 | 0 |
| `S2.ideal_runs(4).cte` | double | 1x1 | 0.371639 |
| `S2.ideal_runs(4).bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).finite` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).T_cmd_min` | double | 1x1 | 6.98159 |
| `S2.ideal_runs(4).T_cmd_max` | double | 1x1 | 13.3906 |
| `S2.ideal_runs(4).T_real_min` | double | 1x1 | 6.98159 |
| `S2.ideal_runs(4).T_real_max` | double | 1x1 | 13.3906 |
| `S2.ideal_runs(4).T_lim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).slew_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(4).sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(4).P_lo_mean` | double | 1x1 | 20.5436 |
| `S2.ideal_runs(4).P_hi_mean` | double | 1x1 | 35.2176 |
| `S2.ideal_runs(4).P_lo_p95` | double | 1x1 | 20.6523 |
| `S2.ideal_runs(4).P_hi_p95` | double | 1x1 | 35.404 |
| `S2.ideal_runs(4).E_lo_Wh` | double | 1x1 | 0.129156 |
| `S2.ideal_runs(4).E_hi_Wh` | double | 1x1 | 0.221411 |
| `S2.ideal_runs(4).E_mid_Wh` | double | 1x1 | 0.175284 |
| `S2.ideal_runs(4).I_hi_24V` | double | 1x1 | 1.47517 |
| `S2.ideal_runs(4).I_hi_48V` | double | 1x1 | 0.737583 |
| `S2.ideal_runs(4).cond_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).sig.t` | double | 440x1 | n=440 min=0.025 max=21.975 mean=11 |
| `S2.ideal_runs(4).sig.T_cmd` | double | 440x1 | n=440 min=6.98159 max=13.3906 mean=7.305 |
| `S2.ideal_runs(4).sig.T_real` | double | 440x1 | n=440 min=6.98159 max=13.3906 mean=7.305 |
| `S2.ideal_runs(4).sig.u_body` | double | 440x1 | n=440 min=1.50601 max=1.75636 mean=1.74372 |
| `S2.ideal_runs(4).sig.P_lo` | double | 440x1 | n=440 min=20.437 max=33.6107 mean=21.173 |
| `S2.ideal_runs(4).sig.P_hi` | double | 440x1 | n=440 min=35.0348 max=57.6184 mean=36.2965 |
| `S2.ideal_runs(4).sig.ds` | double | 1x1 | 2 |
| `S2.ideal_runs(4).M.speed.signed_mean` | double | 1x1 | -0.255 |
| `S2.ideal_runs(4).M.speed.mae` | double | 1x1 | 0.255 |
| `S2.ideal_runs(4).M.speed.p95` | double | 1x1 | 0.256712 |
| `S2.ideal_runs(4).M.speed.rms` | double | 1x1 | 0.255003 |
| `S2.ideal_runs(4).M.speed.n` | double | 1x1 | 634 |
| `S2.ideal_runs(4).M.speed.u_mean` | double | 1x1 | 1.75463 |
| `S2.ideal_runs(4).M.speed.u_ref_mean` | double | 1x1 | 1.49963 |
| `S2.ideal_runs(4).M.theta.mae_deg` | double | 1x1 | 0.121421 |
| `S2.ideal_runs(4).M.theta.p95_deg` | double | 1x1 | 0.402378 |
| `S2.ideal_runs(4).M.theta.rms_deg` | double | 1x1 | 0.176853 |
| `S2.ideal_runs(4).M.theta.n` | double | 1x1 | 634 |
| `S2.ideal_runs(4).M.gamma.mae_deg` | double | 1x1 | 0.418212 |
| `S2.ideal_runs(4).M.gamma.p95_deg` | double | 1x1 | 0.727292 |
| `S2.ideal_runs(4).M.gamma.rms_deg` | double | 1x1 | 0.474473 |
| `S2.ideal_runs(4).M.gamma.n` | double | 1x1 | 634 |
| `S2.ideal_runs(4).M.yaw.mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.yaw.p95_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.yaw.rms_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.yaw.n` | double | 1x1 | 681 |
| `S2.ideal_runs(4).M.yaw.rudder_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.yaw.rudder_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.yaw.ratio_r_Uh_kappa` | double | 1x1 | NaN |
| `S2.ideal_runs(4).M.yaw.n_ratio_valid` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.roll.tilde_mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.roll.p_rms_dps` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.path.mean_cte` | double | 1x1 | 0.371639 |
| `S2.ideal_runs(4).M.path.max_cte` | double | 1x1 | 0.413298 |
| `S2.ideal_runs(4).M.path.pm_mean_cte` | double | 1x1 | 0.39525 |
| `S2.ideal_runs(4).M.act.de_mag_util` | double | 1x1 | 0.0839138 |
| `S2.ideal_runs(4).M.act.dr_mag_util` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.act.thr_mag_util` | double | 1x1 | 0.0234167 |
| `S2.ideal_runs(4).M.act.de_rate_util` | double | 1x1 | 0.00568599 |
| `S2.ideal_runs(4).M.act.dr_rate_util` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.act.thr_rate_util` | double | 1x1 | 2.20466e-05 |
| `S2.ideal_runs(4).M.act.de_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.act.dr_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.act.dr_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.act.thr_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(4).M.act.chatter_dps` | double | 1x1 | 0.195507 |
| `S2.ideal_runs(4).M.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.persistent_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.sim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.sim_err` | char | 0x0 |  |
| `S2.ideal_runs(4).M.trim.name` | char | 1x5 | climb |
| `S2.ideal_runs(4).M.trim.class` | char | 1x23 | steady_translating_trim |
| `S2.ideal_runs(4).M.trim.provenance` | char | 1x11 | PLANT_SOLVE |
| `S2.ideal_runs(4).M.trim.Ufix` | double | 1x1 | 1.5 |
| `S2.ideal_runs(4).M.trim.slope` | double | 1x1 | 0.4 |
| `S2.ideal_runs(4).M.trim.x_star` | double | 12x1 | n=12 min=-0.431841 max=1.5 mean=0.0825909 |
| `S2.ideal_runs(4).M.trim.u_star` | double | 3x1 | 0 -0.0210529 5.73772 |
| `S2.ideal_runs(4).M.trim.Treq` | double | 1x1 | 5.73772 |
| `S2.ideal_runs(4).M.trim.norm_dyn` | double | 1x1 | 2.26319e-13 |
| `S2.ideal_runs(4).M.trim.residual.nu_dot` | double | 6x1 | -8.30317e-15 0 6.68353e-14 0 7.79311e-15 0 |
| `S2.ideal_runs(4).M.trim.residual.eta_dot` | double | 6x1 | 1.39455 0 0.557821 0 -1.06378e-23 0 |
| `S2.ideal_runs(4).M.trim.residual.norm_dyn` | double | 1x1 | 2.26319e-13 |
| `S2.ideal_runs(4).M.trim.residual.att_rate` | double | 3x1 | 0 -1.06378e-23 0 |
| `S2.ideal_runs(4).M.trim.pass` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.trim.exitflag` | double | 1x1 | 1 |
| `S2.ideal_runs(4).M.trim.documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.trim.slope_err` | double | 1x1 | -8.88178e-16 |
| `S2.ideal_runs(4).M.Uref` | double | 1x1 | 1.5 |
| `S2.ideal_runs(4).M.route` | char | 1x2 | XZ |
| `S2.ideal_runs(4).M.feas.gates.trim_documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.trim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.pitch_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.pitch_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.gamma_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.gamma_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.yaw_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.elev_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.thrust_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.dr_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.gates.de_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.first_limit` | char | 1x4 | none |
| `S2.ideal_runs(4).M.feas.feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.margin.pitch_mae` | double | 1x1 | 0.178579 |
| `S2.ideal_runs(4).M.feas.margin.pitch_p95` | double | 1x1 | 0.0976224 |
| `S2.ideal_runs(4).M.feas.margin.gamma_mae` | double | 1x1 | 0.581788 |
| `S2.ideal_runs(4).M.feas.margin.gamma_p95` | double | 1x1 | 0.772708 |
| `S2.ideal_runs(4).M.feas.margin.elev_sat` | double | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.margin.de_rate` | double | 1x1 | 0.994314 |
| `S2.ideal_runs(4).M.feas.margin.dr_rate` | double | 1x1 | 1 |
| `S2.ideal_runs(4).M.feas.worst_margin` | double | 1x1 | 0.0976224 |
| `S2.ideal_runs(5).route` | char | 1x1 | H |
| `S2.ideal_runs(5).U` | double | 1x1 | 1.5 |
| `S2.ideal_runs(5).variant` | char | 1x5 | ideal |
| `S2.ideal_runs(5).prop.name` | char | 1x5 | ideal |
| `S2.ideal_runs(5).prop.ideal` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).prop.tau` | double | 1x1 | 0 |
| `S2.ideal_runs(5).prop.gain` | double | 1x1 | 1 |
| `S2.ideal_runs(5).prop.slew` | double | 1x1 | Inf |
| `S2.ideal_runs(5).prop.T_min` | double | 1x1 | -Inf |
| `S2.ideal_runs(5).prop.T_max` | double | 1x1 | Inf |
| `S2.ideal_runs(5).prop.why` | char | 1x53 | exact passthrough; parity hook against accepted audit |
| `S2.ideal_runs(5).feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).first_limit` | char | 1x4 | none |
| `S2.ideal_runs(5).worst_margin` | double | 1x1 | 0.00175597 |
| `S2.ideal_runs(5).speed_mae` | double | 1x1 | 0.349369 |
| `S2.ideal_runs(5).speed_bias` | double | 1x1 | -0.349369 |
| `S2.ideal_runs(5).theta_mae` | double | 1x1 | 0.0411291 |
| `S2.ideal_runs(5).gamma_mae` | double | 1x1 | 0.658429 |
| `S2.ideal_runs(5).yaw_mae` | double | 1x1 | 0.174042 |
| `S2.ideal_runs(5).cte` | double | 1x1 | 0.269362 |
| `S2.ideal_runs(5).bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).finite` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).T_cmd_min` | double | 1x1 | 3.94749 |
| `S2.ideal_runs(5).T_cmd_max` | double | 1x1 | 13.2206 |
| `S2.ideal_runs(5).T_real_min` | double | 1x1 | 3.94749 |
| `S2.ideal_runs(5).T_real_max` | double | 1x1 | 13.2206 |
| `S2.ideal_runs(5).T_lim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).slew_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(5).sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(5).P_lo_mean` | double | 1x1 | 12.0954 |
| `S2.ideal_runs(5).P_hi_mean` | double | 1x1 | 20.7349 |
| `S2.ideal_runs(5).P_lo_p95` | double | 1x1 | 12.3088 |
| `S2.ideal_runs(5).P_hi_p95` | double | 1x1 | 21.1007 |
| `S2.ideal_runs(5).E_lo_Wh` | double | 1x1 | 0.155977 |
| `S2.ideal_runs(5).E_hi_Wh` | double | 1x1 | 0.267389 |
| `S2.ideal_runs(5).E_mid_Wh` | double | 1x1 | 0.211683 |
| `S2.ideal_runs(5).I_hi_24V` | double | 1x1 | 0.879197 |
| `S2.ideal_runs(5).I_hi_48V` | double | 1x1 | 0.439599 |
| `S2.ideal_runs(5).cond_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).sig.t` | double | 360x1 | n=360 min=0.025 max=44.9 mean=22.4625 |
| `S2.ideal_runs(5).sig.T_cmd` | double | 360x1 | n=360 min=3.95223 max=13.2206 mean=4.80916 |
| `S2.ideal_runs(5).sig.T_real` | double | 360x1 | n=360 min=3.95223 max=13.2206 mean=4.80916 |
| `S2.ideal_runs(5).sig.u_body` | double | 360x1 | n=360 min=1.50732 max=1.70256 mean=1.56126 |
| `S2.ideal_runs(5).sig.P_lo` | double | 360x1 | n=360 min=10.7757 max=33.2127 mean=12.5147 |
| `S2.ideal_runs(5).sig.P_hi` | double | 360x1 | n=360 min=18.4727 max=56.9361 mean=21.4538 |
| `S2.ideal_runs(5).sig.ds` | double | 1x1 | 5 |
| `S2.ideal_runs(5).M.speed.signed_mean` | double | 1x1 | -0.349369 |
| `S2.ideal_runs(5).M.speed.mae` | double | 1x1 | 0.349369 |
| `S2.ideal_runs(5).M.speed.p95` | double | 1x1 | 0.372017 |
| `S2.ideal_runs(5).M.speed.rms` | double | 1x1 | 0.34946 |
| `S2.ideal_runs(5).M.speed.n` | double | 1x1 | 1712 |
| `S2.ideal_runs(5).M.speed.u_mean` | double | 1x1 | 1.55658 |
| `S2.ideal_runs(5).M.speed.u_ref_mean` | double | 1x1 | 1.20721 |
| `S2.ideal_runs(5).M.theta.mae_deg` | double | 1x1 | 0.0411291 |
| `S2.ideal_runs(5).M.theta.p95_deg` | double | 1x1 | 0.0986226 |
| `S2.ideal_runs(5).M.theta.rms_deg` | double | 1x1 | 0.0711297 |
| `S2.ideal_runs(5).M.theta.n` | double | 1x1 | 1712 |
| `S2.ideal_runs(5).M.gamma.mae_deg` | double | 1x1 | 0.658429 |
| `S2.ideal_runs(5).M.gamma.p95_deg` | double | 1x1 | 1.37854 |
| `S2.ideal_runs(5).M.gamma.rms_deg` | double | 1x1 | 0.749974 |
| `S2.ideal_runs(5).M.gamma.n` | double | 1x1 | 1712 |
| `S2.ideal_runs(5).M.yaw.mae_deg` | double | 1x1 | 0.174042 |
| `S2.ideal_runs(5).M.yaw.p95_deg` | double | 1x1 | 0.347445 |
| `S2.ideal_runs(5).M.yaw.rms_deg` | double | 1x1 | 0.203181 |
| `S2.ideal_runs(5).M.yaw.n` | double | 1x1 | 1601 |
| `S2.ideal_runs(5).M.yaw.rudder_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(5).M.yaw.rudder_sat_full_pct` | double | 1x1 | 0.666667 |
| `S2.ideal_runs(5).M.yaw.ratio_r_Uh_kappa` | double | 1x1 | 1.01824 |
| `S2.ideal_runs(5).M.yaw.n_ratio_valid` | double | 1x1 | 1601 |
| `S2.ideal_runs(5).M.roll.tilde_mae_deg` | double | 1x1 | 0.324894 |
| `S2.ideal_runs(5).M.roll.p_rms_dps` | double | 1x1 | 2.09778 |
| `S2.ideal_runs(5).M.path.mean_cte` | double | 1x1 | 0.269362 |
| `S2.ideal_runs(5).M.path.max_cte` | double | 1x1 | 0.401452 |
| `S2.ideal_runs(5).M.path.pm_mean_cte` | double | 1x1 | 0.229973 |
| `S2.ideal_runs(5).M.act.de_mag_util` | double | 1x1 | 0.373191 |
| `S2.ideal_runs(5).M.act.dr_mag_util` | double | 1x1 | 0.17697 |
| `S2.ideal_runs(5).M.act.thr_mag_util` | double | 1x1 | 0.0155526 |
| `S2.ideal_runs(5).M.act.de_rate_util` | double | 1x1 | 0.00573702 |
| `S2.ideal_runs(5).M.act.dr_rate_util` | double | 1x1 | 0.959652 |
| `S2.ideal_runs(5).M.act.thr_rate_util` | double | 1x1 | 0.00130012 |
| `S2.ideal_runs(5).M.act.de_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(5).M.act.dr_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(5).M.act.dr_sat_full_pct` | double | 1x1 | 0.666667 |
| `S2.ideal_runs(5).M.act.thr_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(5).M.act.chatter_dps` | double | 1x1 | 0.150096 |
| `S2.ideal_runs(5).M.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.persistent_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.sim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.sim_err` | char | 0x0 |  |
| `S2.ideal_runs(5).M.trim.name` | char | 1x9 | helix_R10 |
| `S2.ideal_runs(5).M.trim.class` | char | 1x24 | periodic_or_quasi_steady |
| `S2.ideal_runs(5).M.trim.provenance` | char | 1x17 | EMPIRICAL_UNKNOWN |
| `S2.ideal_runs(5).M.trim.Ufix` | double | 1x1 | 1.5 |
| `S2.ideal_runs(5).M.trim.slope` | double | 1x1 | NaN |
| `S2.ideal_runs(5).M.trim.x_star` | double | 12x1 | n=12 min=0 max=1.5 mean=0.125 |
| `S2.ideal_runs(5).M.trim.u_star` | double | 3x1 | 0 NaN NaN |
| `S2.ideal_runs(5).M.trim.Treq` | double | 1x1 | NaN |
| `S2.ideal_runs(5).M.trim.norm_dyn` | double | 1x1 | NaN |
| `S2.ideal_runs(5).M.trim.residual.norm_dyn` | double | 1x1 | NaN |
| `S2.ideal_runs(5).M.trim.residual.note` | char | 1x37 | exact-u LTI helix trim not fabricated |
| `S2.ideal_runs(5).M.trim.pass` | logical | 1x1 | 0 |
| `S2.ideal_runs(5).M.trim.exitflag` | double | 1x1 | 0 |
| `S2.ideal_runs(5).M.trim.documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.trim.slope_err` | double | 1x1 | NaN |
| `S2.ideal_runs(5).M.trim.reason` | char | 1x120 | Exact-u helix trim UNKNOWN; prior rotating-frame relative-eq failed. IC = path-tangent + u=Uref; no fabricated LTI trim. |
| `S2.ideal_runs(5).M.Uref` | double | 1x1 | 1.5 |
| `S2.ideal_runs(5).M.route` | char | 1x1 | H |
| `S2.ideal_runs(5).M.feas.gates.trim_documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.trim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.pitch_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.pitch_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.gamma_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.gamma_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.yaw_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.yaw_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.rud_sat_ss` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.rud_sat_full` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.ratio` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.chatter` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.elev_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.thrust_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.dr_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.gates.de_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.first_limit` | char | 1x4 | none |
| `S2.ideal_runs(5).M.feas.feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.margin.pitch_mae` | double | 1x1 | 0.258871 |
| `S2.ideal_runs(5).M.feas.margin.pitch_p95` | double | 1x1 | 0.401377 |
| `S2.ideal_runs(5).M.feas.margin.gamma_mae` | double | 1x1 | 0.841571 |
| `S2.ideal_runs(5).M.feas.margin.gamma_p95` | double | 1x1 | 1.12146 |
| `S2.ideal_runs(5).M.feas.margin.elev_sat` | double | 1x1 | 1 |
| `S2.ideal_runs(5).M.feas.margin.de_rate` | double | 1x1 | 0.994263 |
| `S2.ideal_runs(5).M.feas.margin.dr_rate` | double | 1x1 | 0.0403479 |
| `S2.ideal_runs(5).M.feas.margin.yaw_mae` | double | 1x1 | 0.825958 |
| `S2.ideal_runs(5).M.feas.margin.rud_sat_full` | double | 1x1 | 0.333333 |
| `S2.ideal_runs(5).M.feas.margin.ratio` | double | 1x1 | 0.00175597 |
| `S2.ideal_runs(5).M.feas.worst_margin` | double | 1x1 | 0.00175597 |
| `S2.ideal_runs(6).route` | char | 1x1 | X |
| `S2.ideal_runs(6).U` | double | 1x1 | 2 |
| `S2.ideal_runs(6).variant` | char | 1x5 | ideal |
| `S2.ideal_runs(6).prop.name` | char | 1x5 | ideal |
| `S2.ideal_runs(6).prop.ideal` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).prop.tau` | double | 1x1 | 0 |
| `S2.ideal_runs(6).prop.gain` | double | 1x1 | 1 |
| `S2.ideal_runs(6).prop.slew` | double | 1x1 | Inf |
| `S2.ideal_runs(6).prop.T_min` | double | 1x1 | -Inf |
| `S2.ideal_runs(6).prop.T_max` | double | 1x1 | Inf |
| `S2.ideal_runs(6).prop.why` | char | 1x53 | exact passthrough; parity hook against accepted audit |
| `S2.ideal_runs(6).feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).first_limit` | char | 1x4 | none |
| `S2.ideal_runs(6).worst_margin` | double | 1x1 | 0.0657829 |
| `S2.ideal_runs(6).speed_mae` | double | 1x1 | 0.317757 |
| `S2.ideal_runs(6).speed_bias` | double | 1x1 | -0.317757 |
| `S2.ideal_runs(6).theta_mae` | double | 1x1 | 0.0342171 |
| `S2.ideal_runs(6).gamma_mae` | double | 1x1 | 0.313206 |
| `S2.ideal_runs(6).yaw_mae` | double | 1x1 | 0 |
| `S2.ideal_runs(6).cte` | double | 1x1 | 0.245725 |
| `S2.ideal_runs(6).bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).finite` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).T_cmd_min` | double | 1x1 | 0.890627 |
| `S2.ideal_runs(6).T_cmd_max` | double | 1x1 | 5.49812 |
| `S2.ideal_runs(6).T_real_min` | double | 1x1 | 0.890627 |
| `S2.ideal_runs(6).T_real_max` | double | 1x1 | 5.49812 |
| `S2.ideal_runs(6).T_lim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).slew_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(6).sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(6).P_lo_mean` | double | 1x1 | 16.5261 |
| `S2.ideal_runs(6).P_hi_mean` | double | 1x1 | 28.3305 |
| `S2.ideal_runs(6).P_lo_p95` | double | 1x1 | 16.632 |
| `S2.ideal_runs(6).P_hi_p95` | double | 1x1 | 28.512 |
| `S2.ideal_runs(6).E_lo_Wh` | double | 1x1 | 0.0786024 |
| `S2.ideal_runs(6).E_hi_Wh` | double | 1x1 | 0.134747 |
| `S2.ideal_runs(6).E_mid_Wh` | double | 1x1 | 0.106675 |
| `S2.ideal_runs(6).I_hi_24V` | double | 1x1 | 1.188 |
| `S2.ideal_runs(6).I_hi_48V` | double | 1x1 | 0.593999 |
| `S2.ideal_runs(6).cond_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).sig.t` | double | 360x1 | n=360 min=0.025 max=17.975 mean=9 |
| `S2.ideal_runs(6).sig.T_cmd` | double | 360x1 | n=360 min=0.890627 max=5.49804 mean=5.17201 |
| `S2.ideal_runs(6).sig.T_real` | double | 360x1 | n=360 min=0.890627 max=5.49804 mean=5.17201 |
| `S2.ideal_runs(6).sig.u_body` | double | 360x1 | n=360 min=1.8157 max=1.99561 mean=1.82849 |
| `S2.ideal_runs(6).sig.P_lo` | double | 360x1 | n=360 min=2.96224 max=16.638 mean=15.7245 |
| `S2.ideal_runs(6).sig.P_hi` | double | 360x1 | n=360 min=5.07813 max=28.5222 mean=26.9562 |
| `S2.ideal_runs(6).sig.ds` | double | 1x1 | 2 |
| `S2.ideal_runs(6).M.speed.signed_mean` | double | 1x1 | -0.317757 |
| `S2.ideal_runs(6).M.speed.mae` | double | 1x1 | 0.317757 |
| `S2.ideal_runs(6).M.speed.p95` | double | 1x1 | 0.320319 |
| `S2.ideal_runs(6).M.speed.rms` | double | 1x1 | 0.31776 |
| `S2.ideal_runs(6).M.speed.n` | double | 1x1 | 521 |
| `S2.ideal_runs(6).M.speed.u_mean` | double | 1x1 | 1.81738 |
| `S2.ideal_runs(6).M.speed.u_ref_mean` | double | 1x1 | 1.49963 |
| `S2.ideal_runs(6).M.theta.mae_deg` | double | 1x1 | 0.0342171 |
| `S2.ideal_runs(6).M.theta.p95_deg` | double | 1x1 | 0.063712 |
| `S2.ideal_runs(6).M.theta.rms_deg` | double | 1x1 | 0.0375579 |
| `S2.ideal_runs(6).M.theta.n` | double | 1x1 | 521 |
| `S2.ideal_runs(6).M.gamma.mae_deg` | double | 1x1 | 0.313206 |
| `S2.ideal_runs(6).M.gamma.p95_deg` | double | 1x1 | 0.654555 |
| `S2.ideal_runs(6).M.gamma.rms_deg` | double | 1x1 | 0.363927 |
| `S2.ideal_runs(6).M.gamma.n` | double | 1x1 | 521 |
| `S2.ideal_runs(6).M.yaw.mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.yaw.p95_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.yaw.rms_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.yaw.n` | double | 1x1 | 521 |
| `S2.ideal_runs(6).M.yaw.rudder_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.yaw.rudder_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.yaw.ratio_r_Uh_kappa` | double | 1x1 | NaN |
| `S2.ideal_runs(6).M.yaw.n_ratio_valid` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.roll.tilde_mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.roll.p_rms_dps` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.path.mean_cte` | double | 1x1 | 0.245725 |
| `S2.ideal_runs(6).M.path.max_cte` | double | 1x1 | 0.267461 |
| `S2.ideal_runs(6).M.path.pm_mean_cte` | double | 1x1 | 0.245725 |
| `S2.ideal_runs(6).M.act.de_mag_util` | double | 1x1 | 0.319168 |
| `S2.ideal_runs(6).M.act.dr_mag_util` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.act.thr_mag_util` | double | 1x1 | 0.0181869 |
| `S2.ideal_runs(6).M.act.de_rate_util` | double | 1x1 | 0.00486767 |
| `S2.ideal_runs(6).M.act.dr_rate_util` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.act.thr_rate_util` | double | 1x1 | 4.37441e-05 |
| `S2.ideal_runs(6).M.act.de_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.act.dr_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.act.dr_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.act.thr_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.act.chatter_dps` | double | 1x1 | 0.149843 |
| `S2.ideal_runs(6).M.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.persistent_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.sim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.sim_err` | char | 0x0 |  |
| `S2.ideal_runs(6).M.trim.name` | char | 1x5 | level |
| `S2.ideal_runs(6).M.trim.class` | char | 1x23 | steady_translating_trim |
| `S2.ideal_runs(6).M.trim.provenance` | char | 1x11 | PLANT_SOLVE |
| `S2.ideal_runs(6).M.trim.Ufix` | double | 1x1 | 2 |
| `S2.ideal_runs(6).M.trim.slope` | double | 1x1 | 0 |
| `S2.ideal_runs(6).M.trim.x_star` | double | 12x1 | n=12 min=-0.0376238 max=2 mean=0.161964 |
| `S2.ideal_runs(6).M.trim.u_star` | double | 3x1 | 0 -0.0690247 6.57404 |
| `S2.ideal_runs(6).M.trim.Treq` | double | 1x1 | 6.57404 |
| `S2.ideal_runs(6).M.trim.norm_dyn` | double | 1x1 | 1.76256e-13 |
| `S2.ideal_runs(6).M.trim.residual.nu_dot` | double | 6x1 | -3.59645e-16 0 -4.46361e-14 0 1.88981e-14 0 |
| `S2.ideal_runs(6).M.trim.residual.eta_dot` | double | 6x1 | 2.00035 0 6.93889e-18 0 9.7897e-25 0 |
| `S2.ideal_runs(6).M.trim.residual.norm_dyn` | double | 1x1 | 1.76256e-13 |
| `S2.ideal_runs(6).M.trim.residual.att_rate` | double | 3x1 | 0 9.7897e-25 0 |
| `S2.ideal_runs(6).M.trim.pass` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.trim.exitflag` | double | 1x1 | 1 |
| `S2.ideal_runs(6).M.trim.documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.trim.slope_err` | double | 1x1 | 6.93889e-18 |
| `S2.ideal_runs(6).M.Uref` | double | 1x1 | 2 |
| `S2.ideal_runs(6).M.route` | char | 1x1 | X |
| `S2.ideal_runs(6).M.feas.gates.trim_documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.trim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.pitch_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.pitch_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.gamma_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.gamma_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.yaw_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.elev_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.thrust_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.dr_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.gates.de_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.first_limit` | char | 1x4 | none |
| `S2.ideal_runs(6).M.feas.feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.margin.pitch_mae` | double | 1x1 | 0.0657829 |
| `S2.ideal_runs(6).M.feas.margin.pitch_p95` | double | 1x1 | 0.436288 |
| `S2.ideal_runs(6).M.feas.margin.gamma_mae` | double | 1x1 | 0.186794 |
| `S2.ideal_runs(6).M.feas.margin.gamma_p95` | double | 1x1 | 0.345445 |
| `S2.ideal_runs(6).M.feas.margin.elev_sat` | double | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.margin.de_rate` | double | 1x1 | 0.995132 |
| `S2.ideal_runs(6).M.feas.margin.dr_rate` | double | 1x1 | 1 |
| `S2.ideal_runs(6).M.feas.worst_margin` | double | 1x1 | 0.0657829 |
| `S2.ideal_runs(7).route` | char | 1x2 | XZ |
| `S2.ideal_runs(7).U` | double | 1x1 | 2 |
| `S2.ideal_runs(7).variant` | char | 1x5 | ideal |
| `S2.ideal_runs(7).prop.name` | char | 1x5 | ideal |
| `S2.ideal_runs(7).prop.ideal` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).prop.tau` | double | 1x1 | 0 |
| `S2.ideal_runs(7).prop.gain` | double | 1x1 | 1 |
| `S2.ideal_runs(7).prop.slew` | double | 1x1 | Inf |
| `S2.ideal_runs(7).prop.T_min` | double | 1x1 | -Inf |
| `S2.ideal_runs(7).prop.T_max` | double | 1x1 | Inf |
| `S2.ideal_runs(7).prop.why` | char | 1x53 | exact passthrough; parity hook against accepted audit |
| `S2.ideal_runs(7).feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).first_limit` | char | 1x4 | none |
| `S2.ideal_runs(7).worst_margin` | double | 1x1 | 0.0899693 |
| `S2.ideal_runs(7).speed_mae` | double | 1x1 | 0.255532 |
| `S2.ideal_runs(7).speed_bias` | double | 1x1 | -0.255532 |
| `S2.ideal_runs(7).theta_mae` | double | 1x1 | 0.119688 |
| `S2.ideal_runs(7).gamma_mae` | double | 1x1 | 0.504844 |
| `S2.ideal_runs(7).yaw_mae` | double | 1x1 | 0 |
| `S2.ideal_runs(7).cte` | double | 1x1 | 0.372599 |
| `S2.ideal_runs(7).bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).finite` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).T_cmd_min` | double | 1x1 | 0.890627 |
| `S2.ideal_runs(7).T_cmd_max` | double | 1x1 | 7.07342 |
| `S2.ideal_runs(7).T_real_min` | double | 1x1 | 0.890627 |
| `S2.ideal_runs(7).T_real_max` | double | 1x1 | 7.07342 |
| `S2.ideal_runs(7).T_lim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).slew_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(7).sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(7).P_lo_mean` | double | 1x1 | 20.5108 |
| `S2.ideal_runs(7).P_hi_mean` | double | 1x1 | 35.1614 |
| `S2.ideal_runs(7).P_lo_p95` | double | 1x1 | 20.6533 |
| `S2.ideal_runs(7).P_hi_p95` | double | 1x1 | 35.4056 |
| `S2.ideal_runs(7).E_lo_Wh` | double | 1x1 | 0.12024 |
| `S2.ideal_runs(7).E_hi_Wh` | double | 1x1 | 0.206126 |
| `S2.ideal_runs(7).E_mid_Wh` | double | 1x1 | 0.163183 |
| `S2.ideal_runs(7).I_hi_24V` | double | 1x1 | 1.47523 |
| `S2.ideal_runs(7).I_hi_48V` | double | 1x1 | 0.737616 |
| `S2.ideal_runs(7).cond_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).sig.t` | double | 440x1 | n=440 min=0.025 max=21.975 mean=11 |
| `S2.ideal_runs(7).sig.T_cmd` | double | 440x1 | n=440 min=0.890627 max=7.07331 mean=6.70005 |
| `S2.ideal_runs(7).sig.T_real` | double | 440x1 | n=440 min=0.890627 max=7.07331 mean=6.70005 |
| `S2.ideal_runs(7).sig.u_body` | double | 440x1 | n=440 min=1.75269 max=1.99406 mean=1.76734 |
| `S2.ideal_runs(7).sig.P_lo` | double | 440x1 | n=440 min=2.95993 max=20.6622 mean=19.6789 |
| `S2.ideal_runs(7).sig.P_hi` | double | 440x1 | n=440 min=5.07417 max=35.4209 mean=33.7352 |
| `S2.ideal_runs(7).sig.ds` | double | 1x1 | 2 |
| `S2.ideal_runs(7).M.speed.signed_mean` | double | 1x1 | -0.255532 |
| `S2.ideal_runs(7).M.speed.mae` | double | 1x1 | 0.255532 |
| `S2.ideal_runs(7).M.speed.p95` | double | 1x1 | 0.258545 |
| `S2.ideal_runs(7).M.speed.rms` | double | 1x1 | 0.255537 |
| `S2.ideal_runs(7).M.speed.n` | double | 1x1 | 679 |
| `S2.ideal_runs(7).M.speed.u_mean` | double | 1x1 | 1.75516 |
| `S2.ideal_runs(7).M.speed.u_ref_mean` | double | 1x1 | 1.49963 |
| `S2.ideal_runs(7).M.theta.mae_deg` | double | 1x1 | 0.119688 |
| `S2.ideal_runs(7).M.theta.p95_deg` | double | 1x1 | 0.410031 |
| `S2.ideal_runs(7).M.theta.rms_deg` | double | 1x1 | 0.17289 |
| `S2.ideal_runs(7).M.theta.n` | double | 1x1 | 679 |
| `S2.ideal_runs(7).M.gamma.mae_deg` | double | 1x1 | 0.504844 |
| `S2.ideal_runs(7).M.gamma.p95_deg` | double | 1x1 | 0.973885 |
| `S2.ideal_runs(7).M.gamma.rms_deg` | double | 1x1 | 0.579506 |
| `S2.ideal_runs(7).M.gamma.n` | double | 1x1 | 679 |
| `S2.ideal_runs(7).M.yaw.mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.yaw.p95_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.yaw.rms_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.yaw.n` | double | 1x1 | 681 |
| `S2.ideal_runs(7).M.yaw.rudder_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.yaw.rudder_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.yaw.ratio_r_Uh_kappa` | double | 1x1 | NaN |
| `S2.ideal_runs(7).M.yaw.n_ratio_valid` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.roll.tilde_mae_deg` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.roll.p_rms_dps` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.path.mean_cte` | double | 1x1 | 0.372599 |
| `S2.ideal_runs(7).M.path.max_cte` | double | 1x1 | 0.424465 |
| `S2.ideal_runs(7).M.path.pm_mean_cte` | double | 1x1 | 0.401033 |
| `S2.ideal_runs(7).M.act.de_mag_util` | double | 1x1 | 0.0862471 |
| `S2.ideal_runs(7).M.act.dr_mag_util` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.act.thr_mag_util` | double | 1x1 | 0.0233724 |
| `S2.ideal_runs(7).M.act.de_rate_util` | double | 1x1 | 0.00622067 |
| `S2.ideal_runs(7).M.act.dr_rate_util` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.act.thr_rate_util` | double | 1x1 | 3.9939e-05 |
| `S2.ideal_runs(7).M.act.de_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.act.dr_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.act.dr_sat_full_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.act.thr_sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(7).M.act.chatter_dps` | double | 1x1 | 0.211413 |
| `S2.ideal_runs(7).M.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.persistent_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.sim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.sim_err` | char | 0x0 |  |
| `S2.ideal_runs(7).M.trim.name` | char | 1x5 | climb |
| `S2.ideal_runs(7).M.trim.class` | char | 1x23 | steady_translating_trim |
| `S2.ideal_runs(7).M.trim.provenance` | char | 1x11 | PLANT_SOLVE |
| `S2.ideal_runs(7).M.trim.Ufix` | double | 1x1 | 2 |
| `S2.ideal_runs(7).M.trim.slope` | double | 1x1 | 0.4 |
| `S2.ideal_runs(7).M.trim.x_star` | double | 12x1 | n=12 min=-0.410113 max=2 mean=0.127555 |
| `S2.ideal_runs(7).M.trim.u_star` | double | 3x1 | 0 -0.0191344 8.47356 |
| `S2.ideal_runs(7).M.trim.Treq` | double | 1x1 | 8.47356 |
| `S2.ideal_runs(7).M.trim.norm_dyn` | double | 1x1 | 6.37841e-13 |
| `S2.ideal_runs(7).M.trim.residual.nu_dot` | double | 6x1 | -2.71128e-15 0 -1.57436e-13 0 7.25075e-14 0 |
| `S2.ideal_runs(7).M.trim.residual.eta_dot` | double | 6x1 | 1.85777 0 0.743107 0 -7.15941e-24 0 |
| `S2.ideal_runs(7).M.trim.residual.norm_dyn` | double | 1x1 | 6.37841e-13 |
| `S2.ideal_runs(7).M.trim.residual.att_rate` | double | 3x1 | 0 -7.15941e-24 0 |
| `S2.ideal_runs(7).M.trim.pass` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.trim.exitflag` | double | 1x1 | 1 |
| `S2.ideal_runs(7).M.trim.documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.trim.slope_err` | double | 1x1 | 1.11022e-16 |
| `S2.ideal_runs(7).M.Uref` | double | 1x1 | 2 |
| `S2.ideal_runs(7).M.route` | char | 1x2 | XZ |
| `S2.ideal_runs(7).M.feas.gates.trim_documented` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.trim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.pitch_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.pitch_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.gamma_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.gamma_p95` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.yaw_mae` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.elev_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.thrust_sat` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.dr_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.gates.de_rate` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.first_limit` | char | 1x4 | none |
| `S2.ideal_runs(7).M.feas.feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.margin.pitch_mae` | double | 1x1 | 0.180312 |
| `S2.ideal_runs(7).M.feas.margin.pitch_p95` | double | 1x1 | 0.0899693 |
| `S2.ideal_runs(7).M.feas.margin.gamma_mae` | double | 1x1 | 0.495156 |
| `S2.ideal_runs(7).M.feas.margin.gamma_p95` | double | 1x1 | 0.526115 |
| `S2.ideal_runs(7).M.feas.margin.elev_sat` | double | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.margin.de_rate` | double | 1x1 | 0.993779 |
| `S2.ideal_runs(7).M.feas.margin.dr_rate` | double | 1x1 | 1 |
| `S2.ideal_runs(7).M.feas.worst_margin` | double | 1x1 | 0.0899693 |
| `S2.ideal_runs(8).route` | char | 1x1 | H |
| `S2.ideal_runs(8).U` | double | 1x1 | 2 |
| `S2.ideal_runs(8).variant` | char | 1x5 | ideal |
| `S2.ideal_runs(8).prop.name` | char | 1x5 | ideal |
| `S2.ideal_runs(8).prop.ideal` | logical | 1x1 | 1 |
| `S2.ideal_runs(8).prop.tau` | double | 1x1 | 0 |
| `S2.ideal_runs(8).prop.gain` | double | 1x1 | 1 |
| `S2.ideal_runs(8).prop.slew` | double | 1x1 | Inf |
| `S2.ideal_runs(8).prop.T_min` | double | 1x1 | -Inf |
| `S2.ideal_runs(8).prop.T_max` | double | 1x1 | Inf |
| `S2.ideal_runs(8).prop.why` | char | 1x53 | exact passthrough; parity hook against accepted audit |
| `S2.ideal_runs(8).feasible` | logical | 1x1 | 1 |
| `S2.ideal_runs(8).first_limit` | char | 1x4 | none |
| `S2.ideal_runs(8).worst_margin` | double | 1x1 | 0.00440917 |
| `S2.ideal_runs(8).speed_mae` | double | 1x1 | 0.0951939 |
| `S2.ideal_runs(8).speed_bias` | double | 1x1 | -0.0951939 |
| `S2.ideal_runs(8).theta_mae` | double | 1x1 | 0.0714492 |
| `S2.ideal_runs(8).gamma_mae` | double | 1x1 | 0.479393 |
| `S2.ideal_runs(8).yaw_mae` | double | 1x1 | 0.202251 |
| `S2.ideal_runs(8).cte` | double | 1x1 | 0.206062 |
| `S2.ideal_runs(8).bounded` | logical | 1x1 | 1 |
| `S2.ideal_runs(8).finite` | logical | 1x1 | 1 |
| `S2.ideal_runs(8).T_cmd_min` | double | 1x1 | 5.67227 |
| `S2.ideal_runs(8).T_cmd_max` | double | 1x1 | 13.1608 |
| `S2.ideal_runs(8).T_real_min` | double | 1x1 | 5.67227 |
| `S2.ideal_runs(8).T_real_max` | double | 1x1 | 13.1608 |
| `S2.ideal_runs(8).T_lim_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(8).slew_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(8).sat_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(8).P_lo_mean` | double | 1x1 | 37.66 |
| `S2.ideal_runs(8).P_hi_mean` | double | 1x1 | 64.5601 |
| `S2.ideal_runs(8).P_lo_p95` | double | 1x1 | 43.6649 |
| `S2.ideal_runs(8).P_hi_p95` | double | 1x1 | 74.8542 |
| `S2.ideal_runs(8).E_lo_Wh` | double | 1x1 | 0.26312 |
| `S2.ideal_runs(8).E_hi_Wh` | double | 1x1 | 0.451063 |
| `S2.ideal_runs(8).E_mid_Wh` | double | 1x1 | 0.357092 |
| `S2.ideal_runs(8).I_hi_24V` | double | 1x1 | 3.11892 |
| `S2.ideal_runs(8).I_hi_48V` | double | 1x1 | 1.55946 |
| `S2.ideal_runs(8).cond_ok` | logical | 1x1 | 1 |
| `S2.ideal_runs(8).sig.t` | double | 360x1 | n=360 min=0.025 max=44.9 mean=22.4625 |
| `S2.ideal_runs(8).sig.T_cmd` | double | 360x1 | n=360 min=5.67298 max=13.1608 mean=6.69242 |
| `S2.ideal_runs(8).sig.T_real` | double | 360x1 | n=360 min=5.67298 max=13.1608 mean=6.69242 |
| `S2.ideal_runs(8).sig.u_body` | double | 360x1 | n=360 min=1.86726 max=2.10581 mean=1.89003 |
| `S2.ideal_runs(8).sig.P_lo` | double | 360x1 | n=360 min=18.8854 max=43.98 mean=21.0943 |
| `S2.ideal_runs(8).sig.P_hi` | double | 360x1 | n=360 min=32.375 max=75.3942 mean=36.1617 |
| `S2.ideal_runs(8).sig.ds` | double | 1x1 | 5 |
| `S2.ideal_runs(8).M.speed.signed_mean` | double | 1x1 | -0.0951939 |
| `S2.ideal_runs(8).M.speed.mae` | double | 1x1 | 0.0951939 |
| `S2.ideal_runs(8).M.speed.p95` | double | 1x1 | 0.163864 |
| `S2.ideal_runs(8).M.speed.rms` | double | 1x1 | 0.106705 |
| `S2.ideal_runs(8).M.speed.n` | double | 1x1 | 27 |
| `S2.ideal_runs(8).M.speed.u_mean` | double | 1x1 | 2.04987 |
| `S2.ideal_runs(8).M.speed.u_ref_mean` | double | 1x1 | 1.95467 |
| `S2.ideal_runs(8).M.theta.mae_deg` | double | 1x1 | 0.0714492 |
| `S2.ideal_runs(8).M.theta.p95_deg` | double | 1x1 | 0.389672 |
| `S2.ideal_runs(8).M.theta.rms_deg` | double | 1x1 | 0.136051 |
| `S2.ideal_runs(8).M.theta.n` | double | 1x1 | 1800 |
| `S2.ideal_runs(8).M.gamma.mae_deg` | double | 1x1 | 0.479393 |
| `S2.ideal_runs(8).M.gamma.p95_deg` | double | 1x1 | 1.20136 |
| `S2.ideal_runs(8).M.gamma.rms_deg` | double | 1x1 | 0.585864 |
| `S2.ideal_runs(8).M.gamma.n` | double | 1x1 | 1800 |
| `S2.ideal_runs(8).M.yaw.mae_deg` | double | 1x1 | 0.202251 |
| `S2.ideal_runs(8).M.yaw.p95_deg` | double | 1x1 | 0.388888 |
| `S2.ideal_runs(8).M.yaw.rms_deg` | double | 1x1 | 0.235327 |
| `S2.ideal_runs(8).M.yaw.n` | double | 1x1 | 1601 |
| `S2.ideal_runs(8).M.yaw.rudder_sat_ss_pct` | double | 1x1 | 0 |
| `S2.ideal_runs(8).M.yaw.rudder_sat_full_pct` | double | 1x1 | 0.166667 |
| `S2.ideal_runs(8).M.yaw.ratio_r_Uh_kappa` | double | 1x1 | 1.01559 |
| `S2.ideal_runs(8).M.yaw.n_ratio_valid` | double | 1x1 | 1601 |
| `S2.ideal_runs(8).M.roll.tilde_mae_deg` | double | 1x1 | 0.722939 |
| `S2.ideal_runs(8).M.roll.p_rms_dps` | double | 1x1 | 2.72864 |
| `S2.ideal_runs(8).M.path.mean_cte` | double | 1x1 | 0.206062 |
| `S2.ideal_runs(8).M.path.max_cte` | double | 1x1 | 0.333168 |
| `S2.ideal_runs(8).M.path.pm_mean_cte` | double | 1x1 | 0.192633 |
| `S2.ideal_runs(8).M.act.de_mag_util` | double | 1x1 | 0.253264 |
| `S2.ideal_runs(8).M.act.dr_mag_util` | double | 1x1 | 0.192814 |
| `S2.ideal_runs(8).M.act.thr_mag_util` | double | 1x1 | 0.0367338 |
| `S2.ideal_runs(8).M.act.de_rate_util` | double | 1x1 | 0.034354 |
| `S2.ideal_runs(8).M.act.dr_rate_util` | double | 1x1 | 0.970503 |

*(4661 further leaves omitted from the table; the complete inventory is stored in `GATE9_SIMULATION_RC_ASSESSMENT.mat` under `Gate9.inventory`.)*

