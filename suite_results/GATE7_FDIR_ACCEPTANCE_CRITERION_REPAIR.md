# GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR - GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001

**Date:** 2026-08-09 01:18:18  
**Class:** Gate 7 attempt 2 - acceptance-criterion repair + bit-identical re-run of the frozen 16-case matrix  
**MATLAB runs:** 1 (single invocation, no retry) - **production edits:** NO - **CODEX_VERTICAL_PLAN:** untouched - **prior Gate 7 artifacts:** preserved  
**Physical / hardware readiness:** **NOT_CERTIFIED** (simulation-only; no HIL, no bench)  
**Verdict:** **PASS** (17/17 hard gates)

## 0. Scope of this task (what was and was not changed)

| Item | Status |
|---|---|
| Monitor set, precedence, latching, hysteresis | **unchanged** (inherited verbatim) |
| Thresholds, debounces, declared bounds | **unchanged** (inherited from the prior MAT and re-derived from the same primitives) |
| Injection windows, scenario matrix, 16 cases | **unchanged** (rebuilt with identical code and compared element-by-element) |
| Plant surrogate, clocks, envelopes, power model | **unchanged** |
| Recovery acceptance criterion | **repaired**: binary `expect_recover` replaced by `{must_recover, must_not_recover, not_applicable_no_degradation}` |
| Detect-to-action metric | **repaired**: time until the ACTIVE response severity reaches the severity the monitor requires |
| Figure banner TeX underscores, panel-6 framing | **fixed** (display only, no data change) |
| Tuning, promotion, production wiring | **none** |

## Sources (strict, exactly 3)

| # | Path | Role | Fingerprint |
|---|------|------|-------------|
| 1 | `run_gate7_mission_manager_fail_silent_sim.m` | Attempt-1 driver: the exact simulation logic re-executed here (copied verbatim, not modified in place) | `n=81992.s1=6194409.s2=2881778828` |
| 2 | `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.mat` | Attempt-1 result MAT: frozen config, scenario matrix, per-case logs, hashes and metrics used as the parity oracle | `n=720858.s1=92497766.s2=119496461` |
| 3 | `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.md` | Attempt-1 report: the recorded PARTIAL verdict, the HG8 defect, the detect-to-action defect and the two cosmetic figure defects | `n=27042.s1=2219048.s2=593309718` |

Upstream frozen sources are **not** re-read here; they are carried forward from the prior MAT:

| # | Path | Fingerprint recorded by attempt 1 |
|---|---|---|
| 1 | `suite_results/AUTONOMOUS_EXECUTION_POLICY.md` | `n=10697.s1=904098.s2=521717115` |
| 2 | `suite_results/AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md` | `n=13422.s1=1148139.s2=3413933708` |
| 3 | `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.mat` | `n=419060.s1=55439208.s2=1302865235` |

Gate 6B precondition inherited through attempt 1: `REAL_TIME_POWER_INTEGRITY_CONTRACT_001` verdict **PASS**.

### Source-binding checks

| Check | Result |
|-------|--------|
| `md_verdict_partial` | YES |
| `md_hg8_failed` | YES |
| `md_names_repair` | YES |
| `md_three_valued` | YES |
| `md_action_metric` | YES |
| `md_tex_banner` | YES |
| `md_panel6_framing` | YES |
| `mat_has_cfg` | YES |
| `driver_has_sim` | YES |

## 1. The two repaired acceptance definitions

### 1.1 Three-valued recovery expectation

Attempt 1 compared a binary flag `expect_recover` against an observable `recovered` defined as "the last so `S01 NOMINAL` and `S14 CONFOUNDER_BENIGN` failed a comparison that should never have been applied to them.

| Class | Meaning | Assertion |
|---|---|---|
| `must_recover` | degradation is expected and the vehicle must return to MISSION_FOLLOW | `recovered == 1`, episode count matches, min dwell respected |
| `must_not_recover` | degradation is expected and must persist to the horizon (latching leak) | `recovered == 0`, episode count matches, min dwell respected |
| `not_applicable_no_degradation` | no fault is injected, so recovery is not a meaningful assertion | zero trips **and** zero episodes **and** zero degraded dwell; `recovered` is not consulted |

The class is a pure function of the frozen attempt-1 schedule: a case with no expected monitor, no injection window and zero expected episodes is `not_applicable_no_degradation`; otherwise the class is `must_recover` when the frozen `expect_recover` was 1 and `must_not_recover` when it was 0. No case changed its injected content.

| Code | Scenario | Frozen expect_recover | Repaired class |
|---|---|---|---|
| S01 | NOMINAL | 0 | `not_applicable_no_degradation` |
| S02 | INVALID_SCHEMA_FRAME_INTEGRITY | 1 | `must_recover` |
| S03 | OUT_OF_ORDER_REPLAY | 1 | `must_recover` |
| S04 | EXPIRED_SEGMENT | 1 | `must_recover` |
| S05 | MISSION_HEARTBEAT_LOSS | 1 | `must_recover` |
| S06 | BUS_TIMEOUT | 1 | `must_recover` |
| S07 | STALE_IMU | 1 | `must_recover` |
| S08 | STALE_DVL | 1 | `must_recover` |
| S09 | STALE_DEPTH | 1 | `must_recover` |
| S10 | ACTUATOR_STUCK_CURRENT | 1 | `must_recover` |
| S11 | UNDERVOLTAGE | 1 | `must_recover` |
| S12 | LEAK | 0 | `must_not_recover` |
| S13 | WATCHDOG_OVERRUN | 1 | `must_recover` |
| S14 | CONFOUNDER_BENIGN | 0 | `not_applicable_no_degradation` |
| S15 | MULTI_FAULT_PRECEDENCE | 0 | `must_not_recover` |
| S16 | FORBIDDEN_MISSION_COMMANDS | 1 | `must_recover` |

### 1.2 Severity-based detect-to-action

Attempt 1 measured "time from detection to the next mode change". When a higher-precedence monitor has already forced an equal or more severe response, there is no next mode change to observe and the metric either overstated the delay (`S06`/`M9`: 0.2250 s against a 0.200 s bound) or returned `NaN` (`S15`/`M1`, `S15`/`M2`).

Repaired definition: the required response severity of monitor `m` is its declared ladder level `mon_mode(m)` (0 MISSION_FOLLOW, 1 HOLD_LAST_SAFE, 2 CONSTRAIN, 3 SAFE_HOLD). The action time is the first logged instant at or after detection at which the active mode is **at least** that severe. If the active mode already satisfies the requirement at detection, the gap is exactly 0 (the required response is already in force). Bound unchanged at 0.200 s.

| Case | Monitor | Required response | Detect [s] | Action [s] | Repaired gap [s] | Bound [s] | Attempt-1 gap [s] |
|---|---|---|---|---|---|---|---|
| S02 | M9 MISSION_STALE | HOLD_LAST_SAFE | 14.0500 | 14.0500 | 0.0000 | 0.200 | 0.0000 |
| S03 | M9 MISSION_STALE | HOLD_LAST_SAFE | 14.0500 | 14.0500 | 0.0000 | 0.200 | 0.0000 |
| S04 | M9 MISSION_STALE | HOLD_LAST_SAFE | 14.0500 | 14.0500 | 0.0000 | 0.200 | 0.0000 |
| S05 | M9 MISSION_STALE | HOLD_LAST_SAFE | 14.0500 | 14.0500 | 0.0000 | 0.200 | 0.0000 |
| S06 | M8 BUS_TIMEOUT | HOLD_LAST_SAFE | 12.2750 | 12.2750 | 0.0000 | 0.200 | 0.0000 |
| S06 | M9 MISSION_STALE | HOLD_LAST_SAFE | 14.0500 | 14.0500 | 0.0000 | 0.200 | 0.2250 |
| S07 | M5 IMU_STALE | SAFE_HOLD | 12.1250 | 12.1250 | 0.0000 | 0.200 | 0.0000 |
| S08 | M6 DVL_STALE | CONSTRAIN | 10.9250 | 10.9250 | 0.0000 | 0.200 | 0.0000 |
| S09 | M7 DEPTH_STALE | SAFE_HOLD | 12.4750 | 12.4750 | 0.0000 | 0.200 | 0.0000 |
| S10 | M4 ACTUATOR_STUCK_CURRENT | CONSTRAIN | 12.2000 | 12.2000 | 0.0000 | 0.200 | 0.0000 |
| S11 | M2 UNDERVOLTAGE | SAFE_HOLD | 12.1000 | 12.1000 | 0.0000 | 0.200 | 0.0000 |
| S12 | M1 LEAK | SAFE_HOLD | 18.0250 | 18.0250 | 0.0000 | 0.200 | 0.0000 |
| S13 | M3 WATCHDOG_OVERRUN | SAFE_HOLD | 12.0750 | 12.0750 | 0.0000 | 0.200 | 0.0000 |
| S15 | M1 LEAK | SAFE_HOLD | 22.0250 | 22.0250 | 0.0000 | 0.200 | NaN |
| S15 | M2 UNDERVOLTAGE | SAFE_HOLD | 14.1000 | 14.1000 | 0.0000 | 0.200 | NaN |
| S15 | M9 MISSION_STALE | HOLD_LAST_SAFE | 12.0500 | 12.0500 | 0.0000 | 0.200 | 0.0000 |
| S16 | M9 MISSION_STALE | HOLD_LAST_SAFE | 12.0500 | 12.0500 | 0.0000 | 0.200 | 0.0000 |

Every repaired gap in the table above is exactly 0. That is a direct consequence of the frozen schedule, not a favourable rounding: the watchdog/FDIR task and the controller share the same response-ladder level computed at the detecting watchdog tick is already present in the log sample emitted by that same tick. The metric therefore has no resolution below one controller period here, and it is reported as a consistency check on the ladder, not as a measured latency. A real system with asynchronous safety and control tasks would show a non-zero gap; that remains `TO_BE_IDENTIFIED`.

## 2. Raw-behaviour parity against the prior MAT

| Compared object | Requirement | Result |
|---|---|---|
| Per-case hash, pass A | exact equality with `R.replay_hash_A` | YES |
| Per-case hash, pass B | exact equality with `R.replay_hash_B` | YES |
| Replay flags | exact equality | YES |
| Per-case struct (all attempt-1 fields, incl. full log matrix and Ack matrix) | exact equality | YES - 16 elements x 61 fields exactly equal |
| Logged time series and Ack matrices, re-asserted directly | exact equality | YES - 16/16 case log + ack matrices identical |
| Aggregate metrics (all attempt-1 fields) | exact equality | YES - 30/30 fields exactly equal |
| Scenario matrix (windows, expected monitors, injection onsets, confounder flag, episodes, notes) | exact equality | YES - 16 elements x 9 fields exactly equal |
| Configuration | inherited verbatim; every derived threshold re-derived from primitives and matched | YES |

Only the acceptance fields and the derived action-latency field differ, plus the regenerated display artifacts:

| Object | Fields added | Fields removed |
|---|---|---|
| per-case | `act_gap_sev`, `act_req_mode`, `t_action_sev` | none |
| metrics | `act_gap_sev`, `act_gap_sev_labels`, `act_gap_sev_worst` | none |
| scenario | `rec_class` | none |

## 3. Results (identical to attempt 1 by construction, re-reported)

| Code | Msgs | Acc | Rej | Ack mismatch | Trips | Expected | FA | Missed | Episodes | HLS [s] | CONSTR [s] | SAFE_HOLD [s] | Recovered | Class | Class met | Replay |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S01 | 40 | 40 | 0 | 0 | none | none | 0 | 0 | 0 | 0.00 | 0.00 | 0.00 | 1 (N/A) | `not_applicable_no_degradation` | YES | YES |
| S02 | 40 | 28 | 12 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 8.95 | 1 | `must_recover` | YES | YES |
| S03 | 40 | 30 | 10 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 6.95 | 1 | `must_recover` | YES | YES |
| S04 | 40 | 30 | 10 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 6.95 | 1 | `must_recover` | YES | YES |
| S05 | 28 | 28 | 0 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 8.95 | 1 | `must_recover` | YES | YES |
| S06 | 30 | 30 | 0 | 0 | M8,M9 | M8,M9 | 0 | 0 | 1 | 2.00 | 0.00 | 8.72 | 1 | `must_recover` | YES | YES |
| S07 | 40 | 40 | 0 | 0 | M5 | M5 | 0 | 0 | 1 | 0.00 | 0.00 | 6.85 | 1 | `must_recover` | YES | YES |
| S08 | 40 | 40 | 0 | 0 | M6 | M6 | 0 | 0 | 1 | 0.00 | 5.00 | 9.05 | 1 | `must_recover` | YES | YES |
| S09 | 40 | 40 | 0 | 0 | M7 | M7 | 0 | 0 | 1 | 0.00 | 0.00 | 8.50 | 1 | `must_recover` | YES | YES |
| S10 | 40 | 40 | 0 | 0 | M4 | M4 | 0 | 0 | 1 | 0.00 | 2.00 | 6.80 | 1 | `must_recover` | YES | YES |
| S11 | 40 | 40 | 0 | 0 | M2 | M2 | 0 | 0 | 1 | 0.00 | 0.00 | 4.90 | 1 | `must_recover` | YES | YES |
| S12 | 40 | 40 | 0 | 0 | M1 | M1 | 0 | 0 | 1 | 0.00 | 0.00 | 21.98 | 0 | `must_not_recover` | YES | YES |
| S13 | 40 | 40 | 0 | 0 | M3 | M3 | 0 | 0 | 1 | 0.00 | 0.00 | 5.93 | 1 | `must_recover` | YES | YES |
| S14 | 42 | 42 | 0 | 0 | none | none | 0 | 0 | 0 | 0.00 | 0.00 | 0.00 | 1 (N/A) | `not_applicable_no_degradation` | YES | YES |
| S15 | 20 | 20 | 0 | 0 | M1,M2,M9 | M1,M2,M9 | 0 | 0 | 1 | 2.00 | 0.00 | 25.95 | 0 | `must_not_recover` | YES | YES |
| S16 | 40 | 28 | 12 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 8.95 | 1 | `must_recover` | YES | YES |

### Detection delays vs declared bounds (unchanged numbers)

| Case | Monitor | Latency from fault onset [s] | Bound [s] | Margin [s] | Latency from condition crossing [s] | Bound [s] |
|---|---|---|---|---|---|---|
| S02 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 |
| S03 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 |
| S04 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 |
| S05 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 |
| S06 | M8 BUS_TIMEOUT | 0.2750 | 0.820 | +0.5450 | 0.0075 | 0.050 |
| S06 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 |
| S07 | M5 IMU_STALE | 0.1250 | 0.225 | +0.1000 | 0.0000 | 0.050 |
| S08 | M6 DVL_STALE | 0.9250 | 1.150 | +0.2250 | 0.0225 | 0.050 |
| S09 | M7 DEPTH_STALE | 0.4750 | 0.600 | +0.1250 | 0.0225 | 0.050 |
| S10 | M4 ACTUATOR_STUCK_CURRENT | 0.2000 | 0.250 | +0.0500 | 0.1975 | 0.250 |
| S11 | M2 UNDERVOLTAGE | 0.1000 | 0.150 | +0.0500 | 0.0975 | 0.150 |
| S12 | M1 LEAK | 0.0250 | 0.100 | +0.0750 | 0.0250 | 0.100 |
| S13 | M3 WATCHDOG_OVERRUN | 0.0750 | 0.125 | +0.0500 | 0.0225 | 0.050 |
| S15 | M1 LEAK | 0.0250 | 0.100 | +0.0750 | 0.0250 | 0.100 |
| S15 | M2 UNDERVOLTAGE | 0.1000 | 0.150 | +0.0500 | 0.0975 | 0.150 |
| S15 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 |
| S16 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 |

### Counts

| Quantity | Value |
|---|---|
| Scenarios | 16 (x2 passes = 32 deterministic executions) |
| Mission messages delivered / accepted / rejected | 600 / 556 / 44 |
| Ack code mismatches vs independently specified ground truth | 0 |
| Reject histogram [OK SCHEMA FRAME INTEG ORDER EXPIRE BOUNDS LINK FORBID] | [556    4    4    4   10   10    0    0   12] |
| Expected detections / detected in bound / late / missed | 17 / 17 / 0 / 0 |
| Isolation exact (monitor set == expected set) | 16 / 16 cases |
| False alarms | 0 |
| Benign confounder events planted (must not trip) | 7 |
| Mission hint clamp events / unclamped | 42 / 0 |
| Surface commands requested by mission / issued | 4 / **0** |
| Direct-actuator commands requested / issued | 4 / **0** |
| Accommodation requests / automatic accommodations performed | 4 / **0** |
| Magnitude / rate / bound violations | 0 / 0 / 0 |
| Monotonic seq and t_mono on every emission | YES |
| Worst severity-based detect-to-action (repaired) | 0.0000 s (bound 0.200 s) |
| Worst next-mode-change gap (attempt-1 definition, retained for comparison) | 0.2250 s |

## 4. Pareto tracking vector

| Axis | Value | Note |
|---|---|---|
| Tracking | mean surrogate path error 1.144 m, max 7.805 m (MISSION_FOLLOW only) | surrogate geometry, **not** a production tracking metric |
| Actuator margin | min elevator margin 0.263, min rudder margin 0.000 of frozen envelope | envelopes 15/25 deg, 40 deg/s inherited |
| Energy | mean thrust^2 proxy 0.0905, max thrust 0.393 pu | inherited power model, no re-measurement |
| Estimation | **N/A** | measured/estimated streams are `NOT_IMPLEMENTED` until Gate 5; no NEES claim |
| Timing | controller deadline misses 201 (injected), watchdog misses 0, **repaired** detect->action worst 0.0000 s (bound 0.200 s) | Gate 6B budgets inherited, no new WCET claim |
| Safety | false alarms 0, missed detections 0, surface/accommodation/direct-actuator commands 0/0/0, min depth 3.00 m | local safety authority always wins |

## 5. Hard gates (15 original with HG8 repaired, plus HG16 parity and HG17 criterion scope)

| ID | Requirement | Result | Detail |
|---|---|---|---|
| HG1 | Deterministic replay: independent reverse-order re-execution reproduces every case hash bit-for-bit | **PASS** | 16/16 case hashes identical |
| HG2 | Monotonic logs: seq strictly +1 and t_mono strictly increasing on every emitted output, every case | **PASS** | monotonic seq/t_mono on 16/16 cases |
| HG3 | No false FDIR: NOMINAL and CONFOUNDER_BENIGN produce zero monitor trips, zero degraded dwell, zero rejects | **PASS** | S01 trips=0 dwell=0.000 rej=0 | S14 trips=0 dwell=0.000 rej=0 (confounder events planted=7) |
| HG4 | Every injected fault detected inside its declared bound (from fault onset AND from condition crossing) | **PASS** | detected 17/17 expected, late=0, missed=0, worst onset-latency margin 0.0500 s |
| HG5 | Zero false alarms across the whole matrix (no monitor trips outside its declared scenario) | **PASS** | false alarms=0 over 16 cases |
| HG6 | Correct isolation: the active-monitor set equals the declared expected set in every case | **PASS** | 16/16 cases with exact monitor-set match |
| HG7 | Precedence and latching: LEAK > UNDERVOLTAGE > MISSION_STALE, and LEAK latches (no auto-clear) | **PASS** | S15 top-monitor precedence ok=1, leak latched to horizon=1 (safe-hold dwell 25.95 s) |
| HG8 | Recovery hysteresis without chatter under a REPAIRED three-valued expectation {must_recover / must_not_recover / not_applicable_no_degradation}: one degraded episode per injected fault, min dwell respected, recovery asserted only where degradation is expected; fault-free cases are not_applicable and must instead show zero trips, zero episodes and zero degraded dwell; and the REPAIRED detect-to-action (time until the active response severity reaches the severity this monitor requires, an already-active higher-severity response counting as immediate) is inside its unchanged declared bound | **PASS** | all 16 cases meet their three-valued recovery expectation (12 must_recover, 2 must_not_recover, 2 not_applicable_no_degradation); min dwell 1.0 s respected; worst severity-based detect-to-action 0.0000 s over 17 detections (bound 0.200 s), no NaN |
| HG9 | Bumpless bounded output: no reference step beyond the local rate envelope at any tick, including mode transitions | **PASS** | rate violations=0, magnitude violations=0, worst step/limit ratio=1.0000 |
| HG10 | Zero surface, zero automatic accommodation, zero direct-actuator mission commands issued | **PASS** | issued surface=0 accommodation=0 direct-actuator=0 (requested by mission and rejected: 4 / 4 / 4) |
| HG11 | Path / reference governance: curvature, slope, rate and depth bounds respected; mission hints clamped, never obeyed raw | **PASS** | bound violations=0, clamp events=42, unclamped hints=0, kappa_max=0.0249/0.10, slope_max=6.51/15.0 deg, depth [3.00 9.02] m |
| HG12 | Ack / rejection codes exact: every invalid message rejected with the independently specified code, every valid message accepted | **PASS** | 600 acks, 556 accepted, 44 rejected, 0 code mismatches |
| HG13 | Production + CODEX_VERTICAL_PLAN byte-identical, and the prior Gate 7 artifacts preserved | **PASS** | 6 production/plan files fingerprinted, 0 changed; full-triple cross-match against the prior Gate 7 mat 6/6; 4 prior Gate 7 artifacts preserved byte-identical: YES |
| HG14 | Artifacts written and total footprint < 300 MiB | **PASS** | mat=0.69 MiB, png=0.13 MiB, total=0.82 MiB (< 300 MiB target) |
| HG15 | Label honesty: mission/nav/actuator-feedback rates remain TO_BE_IDENTIFIED, every fault number ASSUMED, hardware NOT_CERTIFIED | **PASS** | mission/nav rates TO_BE_IDENTIFIED (ASSUMED sim placeholders); fault schedule ASSUMED and unchanged; verdict scope = simulation only |
| HG16 | Raw-behaviour parity: every frozen case input, event schedule, threshold, output time series and per-case hash, and every unaffected metric, is exactly equal to the prior Gate 7 MAT | **PASS** | hashA=YES hashB=YES replay_flags=YES | per_case: 16 elements x 61 fields exactly equal | metrics: 30/30 fields exactly equal | scenarios: 16 elements x 9 fields exactly equal | cfg inherited+derived-rechecked=YES | time series: 16/16 case log + ack matrices identical |
| HG17 | Criterion scope: the only changes are the three-valued recovery expectation and the severity-based detect-to-action field; no field removed, no undeclared field added, S01/S14 are not_applicable_no_degradation, and the class map is a pure function of the frozen prior expectation | **PASS** | per-case added {act_gap_sev,act_req_mode,t_action_sev} removed {}; metrics added {act_gap_sev,act_gap_sev_labels,act_gap_sev_worst} removed {}; scenario added {rec_class} removed {}; S01 N/A=YES, S14 N/A=YES, class map pure=YES |

## 6. Preservation

### Production and plan

| File | Fingerprint pre | Fingerprint post | Identical | Matches attempt-1 record |
|---|---|---|---|---|
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | `n=10845.s1=886194.s2=515073390` | YES | YES |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | `n=9402.s1=732890.s2=3334742186` | YES | YES |
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | `n=14601.s1=1095745.s2=3464382495` | YES | YES |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | `n=6065.s1=426918.s2=1254438441` | YES | YES |
| `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990739` | `n=11604.s1=883372.s2=792990739` | YES | YES |
| `suite_results/CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | `n=43101.s1=4310210.s2=3268810005` | YES | YES |

### Prior Gate 7 artifacts (must survive untouched)

| Artifact | Fingerprint pre | Fingerprint post | Identical |
|---|---|---|---|
| `run_gate7_mission_manager_fail_silent_sim.m` | `n=81992.s1=6194409.s2=2881778828` | `n=81992.s1=6194409.s2=2881778828` | YES |
| `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.mat` | `n=720858.s1=92497766.s2=119496461` | `n=720858.s1=92497766.s2=119496461` | YES |
| `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.md` | `n=27042.s1=2219048.s2=593309718` | `n=27042.s1=2219048.s2=593309718` | YES |
| `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.png` | `n=130828.s1=16459963.s2=1928623955` | `n=130828.s1=16459963.s2=1928623955` | YES |

This task writes only `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.{md,mat,png}` and `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_run.log`, plus one marked append to each of the three running logs.

## 7. Visual QA (regenerated 9-panel figure)

| Panel | Content | Change vs attempt 1 |
|---|---|---|
| 1 response-ladder matrix | mode per case over time | colorbar labels de-underscored, tick interpreter set to `none` |
| 2 S15 precedence | mode, top monitor, scaled bus voltage | unchanged |
| 3 latency vs bound | now grouped bars: detection latency ratio **and** repaired action-gap ratio | new second series, monitor names de-underscored |
| 4 S05 bounded/bumpless refs | pitch reference, theta, reference rate, limits | unchanged |
| 5 depth, all cases | no-auto-surface evidence | unchanged |
| 6 3D geometry | waypoint polyline plus S01/S05 trajectories | **framing fixed**: axes zoomed to the traversed extent with 8% padding instead of the full waypoint bounding box, so the panel is filled; no data changed, unreached waypoints simply fall outside the view |
| 7 Ack histogram | reject-code counts | tick interpreter set to `none` |
| 8 ladder dwell | stacked dwell per case, annotated `R` / `N` / `-` for the three-valued class | class annotation added |
| 9 gate summary | 17 gates | now 17 bars |
| banner | task banner | **TeX defect fixed**: annotation drawn with `Interpreter` = `none`, so underscores render literally instead of as subscripts |

## 8. Honest limits

1. **Simulation only.** No HIL, no bench, no vehicle. `NOT_CERTIFIED`. This task changed an acceptance definition; it did not add physical evidence of any kind.
2. **The vehicle response is an ASSUMED kinematic surrogate**, unchanged from attempt 1, deliberately not the production plant.
3. **Every threshold, window and debounce is still ASSUMED** and is byte-identical to attempt 1. Nothing was widened, narrowed, added or removed.
4. **Mission / navigation / actuator-feedback rates remain TO_BE_IDENTIFIED.**
5. **Repairing an acceptance criterion is not the same as passing a harder test.** The repaired HG8 asserts *less* on `S01`/`S14` about recovery and *more* about their being fault-free; the 14 degrading cases are asserted exactly as before. The repaired detect-to-action asserts a weaker-looking but semantically correct property: it credits a response that is already at or above the required severity. Both changes were named in the attempt-1 report before this run.
6. **HG16 is the guard against self-serving repair.** If the acceptance change had leaked into the simulation, the per-case hashes would differ and HG16 would fail. It does not fail, so the underlying behaviour reported here is literally the attempt-1 behaviour.
7. **No transport, middleware or wire format** is selected or validated; the message set stays `INTERFACE_SPECIFIED`.
8. **Single MATLAB invocation, no retry.** No tuning loop stands behind these numbers.
9. **The upstream frozen sources were not re-read.** Their fingerprints are carried forward from the attempt-1 MAT, so this run inherits, rather than re-proves, the Gate 6B precondition and the policy/ICD bindings.
10. **HG12 remains a self-consistency check, not an oracle**, exactly as recorded in attempt 1.
11. **The repaired detect-to-action metric has one-controller-period resolution.** Watchdog/FDIR and controller run on the same 25 ms tick here, so a correctly ladder-driven response is always visible in the same logged sample as its detection. The metric can therefore only catch a ladder that fails to escalate at all; it cannot measure sub-tick response latency, and no such latency is claimed.

## 9. Verdict and next exact task

**PASS** - 17/17 hard gates.

All Gate 7 hard gates hold under the corrected acceptance semantics, and HG16 shows the underlying simulated behaviour is bit-identical to the attempt-1 run that produced PARTIAL. Zero false alarms, zero surface commands, zero automatic accommodations and zero direct-actuator commands remain. Gate 7 is **PASS at simulation scope only**; no hardware label is upgraded and no safe-mode behaviour is certified. **Gate 8 is unlocked.**

**Next exact task:** `gate8_monte_carlo_independent_priors_campaign` - Monte Carlo over the policy Gate 8 factor table (CG/CB +-2 cm per axis, buoyancy +-3%, sensor bias/delay/dropout per the availability matrix, actuator lag/delay {0,15,30} ms + jitter, battery/brownout envelopes from Gate 6B), independent draws, percentiles over means, no silent narrowing of priors.

**Do not edit:** `suite_results/CODEX_VERTICAL_PLAN.md` and the attempt-1 Gate 7 artifacts (all fingerprinted above).

## 9b. Post-run addendum (analysis only - no re-run, no number changed, verdict stays PASS)

Written after the single MATLAB invocation. Nothing below re-executes anything, edits any metric, or changes any gate.

### Visual QA of `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.png` (9 panels, inspected as rendered)

| Panel | Reading | QA |
|---|---|---|
| figure banner | `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001 - acceptance-criterion repair + identical re-run - SIMULATION ONLY - production untouched - rates TO_BE_IDENTIFIED - fault schedule ASSUMED and unchanged - NOT_CERTIFIED` renders with literal underscores | **attempt-1 TeX defect fixed** |
| 1 response-ladder matrix | S01 and S14 uniformly FOLLOW; every fault case one contiguous degraded band returning to FOLLOW, except S12 and S15 which stay in SAFE_HOLD to the horizon; colorbar reads FOLLOW / HOLD-LAST / CONSTRAIN / SAFE-HOLD with no subscripting | legible, matches the tables |
| 2 S15 precedence | top-monitor trace steps 9 -> 2 -> 9 -> 1 and stays at 1 after the leak; mode reaches SAFE_HOLD and never leaves | legible |
| 3 latency and action gap vs bound | detection-latency bars all below the red bound line (worst ratio about 0.8); the repaired action-gap series is flat at zero, which is the honest reading of a metric whose resolution is one controller tick | legible; the zero series is visually empty by construction, and section 1.2 says why |
| 4 S05 bounded/bumpless refs | pitch reference inside +-15 deg; per-guidance-tick rate touches +-10 deg/s at transitions and never exceeds it | legible; the rate trace is spiky by nature (step-and-hold reference) |
| 5 depth, all cases | band 3.00 to 9.02 m, far from the surface, no case trends shallow during a degraded episode | legible; strongest single piece of no-auto-surface evidence |
| 6 3D geometry | waypoint polyline plus S01 and S05 trajectories, axes now zoomed to the traversed extent | **attempt-1 framing defect fixed**; the panel is filled. Residual honesty note: the zoom means only the first two waypoints are inside the view, so the panel no longer shows the whole planned path. The underlying limitation is unchanged - at 1.2 m/s over 40 s the surrogate only covers the first leg - and fixing that would require a longer horizon, which is a scenario change this task is not allowed to make |
| 7 Ack histogram | 556 OK against 4/4/4/10/10/12 rejects | acceptable; a log scale would still help |
| 8 ladder dwell per case | stacked hold-last-safe / constrain / safe-hold, each case annotated `R` (must recover), `N` (must not recover) or `-` (not applicable) | legible; the annotation makes the repaired criterion readable straight off the figure |
| 9 gate summary | 17 green bars, none red | legible |

### One defect in this report, recorded rather than silently patched

In section 1.2, the sentence beginning "Every repaired gap in the table above is exactly 0" is truncated: a `printf` conversion was split across two write calls in the report generator, so the fragment " 25 ms tick in this harness, so the" was dropped. The intended sentence is:

> Every repaired gap in the table above is exactly 0. That is a direct consequence of the frozen schedule, not a favourable rounding: the watchdog/FDIR task and the controller share the same 25 ms tick in this harness, so the response-ladder level computed at the detecting watchdog tick is already present in the log sample emitted by that same tick. The metric therefore has no resolution below one controller period here, and it is reported as a consistency check on the ladder, not as a measured latency. A real system with asynchronous safety and control tasks would show a non-zero gap; that remains `TO_BE_IDENTIFIED`.

The same statement, uncorrupted, is in honest-limit 11. This is a prose defect in a generated artifact, not a data, metric or gate defect; no number, gate or verdict depends on it. The generator has been corrected in `run_gate7_fdir_acceptance_criterion_repair.m` so a future invocation emits the full sentence, but the artifact above is left exactly as MATLAB wrote it, because repairing it in place would require either a second MATLAB invocation (forbidden by this task) or hand-editing a generated evidence file (worse).

## 10. Artifacts

| Artifact | Size |
|---|---|
| `suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.md` | this report |
| `suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat` | 0.69 MiB (config, frozen schedule with repaired classes, per-case logs, parity record, gates) |
| `suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.png` | 0.13 MiB (9-panel visual QA, banner and framing fixed) |
| `suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_run.log` | console transcript |

Host runtime 89.5 s, free space at start 4.45 GiB, MATLAB invocations: 1.
