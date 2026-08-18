# GATE7_MISSION_MANAGER_FAIL_SILENT_SIM - GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_001

**Date:** 2026-08-09 00:50:23  
**Class:** Gate 7 isolated mission-manager + deterministic FDIR / watchdog **simulation**  
**MATLAB runs:** 1 (single invocation, no retry) - **production edits:** NO - **CODEX_VERTICAL_PLAN:** untouched  
**Physical / hardware readiness:** **NOT_CERTIFIED** (simulation-only; no HIL, no bench)  
**Verdict:** **PARTIAL** (14/15 hard gates)

## Sources (strict, exactly 3)

| # | Path | Role | Fingerprint |
|---|------|------|-------------|
| 1 | `suite_results/AUTONOMOUS_EXECUTION_POLICY.md` | Gate 7 FDIR matrix, promotion + Pareto discipline, label vocabulary | `n=10697.s1=904098.s2=521717115` |
| 2 | `suite_results/AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md` | Layering, header fields, message set, authority / stale / fail-silent rules | `n=13422.s1=1148139.s2=3413933708` |
| 3 | `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.mat` | Accepted Gate 6B contract: clocks, envelopes, power thresholds, gate style | `n=419060.s1=55439208.s2=1302865235` |

Gate 6B precondition: `REAL_TIME_POWER_INTEGRITY_CONTRACT_001` verdict **PASS** (created 2026-08-08 23:54:03), inherited, not re-run.

### Source-binding checks

| Check | Result |
|-------|--------|
| `policy_gate7_fdir` | YES |
| `policy_no_surface` | YES |
| `policy_labels` | YES |
| `policy_pareto` | YES |
| `icd_messages` | YES |
| `icd_header` | YES |
| `icd_frames` | YES |
| `icd_fail_silent` | YES |
| `icd_local_override` | YES |
| `icd_no_direct_act` | YES |
| `g6b_pass` | YES |

## 1. What is IMPLEMENTED vs INTERFACE_SPECIFIED vs NOT_CERTIFIED

| Item | Label |
|------|-------|
| Isolated mission-manager ingress/validator, Ack generation, constrained-3D segment sequencing | `IMPLEMENTED` (this harness, simulation) |
| Deterministic FDIR/watchdog state machine: 9 monitors, precedence, latching, hysteresis | `IMPLEMENTED` (this harness, simulation) |
| Bounded command/reference governance + bumpless mode transfer | `IMPLEMENTED` (this harness, simulation) |
| MissionCommand / WaypointSet / TrajectorySegment / Ack wire contract, StateEstimate / VehicleHealth / ActuatorStatus uplinks | `INTERFACE_SPECIFIED` (exercised as in-process structs, no transport, no middleware) |
| Production guidance / controller / dynamics wiring | **NOT_IMPLEMENTED here by design** - production byte-identical, nothing tuned |
| Vehicle response used to close the loop | `ASSUMED` kinematic surrogate, **not** the production plant, no fidelity claimed |
| measured / estimated state streams | `NOT_IMPLEMENTED` (Gate 5); uplink StateEstimate is **truth-tagged** only |
| Mission / navigation / actuator-feedback rates | `TO_BE_IDENTIFIED` (ASSUMED sim placeholders 1000 ms / 25 ms) |
| All fault magnitudes, thresholds, windows, debounces | `ASSUMED` (frozen before the run, listed below) |
| Hardware / HIL / safe-mode certification | **`NOT_CERTIFIED`** |

## 2. Frames and signs (Gate 0 freeze, inherited)

| Field | Definition |
|-------|------------|
| `position` | NED inertial [m]; z positive DOWN (depth = +z) |
| `rates` | BODY angular rates p,q,r [rad/s]; BODY velocity u,v,w [m/s] |
| `euler` | phi,theta,psi [rad] internally (report/plots in deg where labelled) |
| `pitch_sign` | theta > 0 = nose UP = depth decreasing (dz/dt = -u*sin(theta)) in this surrogate |
| `actuators` | delta_e, delta_r [deg] signed per production convention; thrust in [0,1] pu |
| `units` | SI (m, m/s, rad, rad/s, N, s); deg only where a field name says _deg |
| `source_ref` | AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md Sec.4 + REAL_TIME_POWER_INTEGRITY_CONTRACT.mat frames |
| `label` | INTERFACE_SPECIFIED (frozen, not re-derived here) |

## 3. Clocks (inherited from the accepted Gate 6B contract)

| Task | Period | Label |
|------|--------|-------|
| watchdog / FDIR | 0.025 s | watchdog 25 ms : ASSUMED (harness-declared safety monitor) |
| controller | 0.025 s | controller 25 ms : FIXED 40 Hz (ICD Sec.3 interface target) |
| guidance | 0.075 s | guidance 75 ms : DERIVED 13.33 Hz (ICD Sec.3) |
| navigation | 0.025 s | navigation 25 ms : TO_BE_IDENTIFIED (ASSUMED sim placeholder) |
| mission | 1 s | mission 1000 ms : TO_BE_IDENTIFIED (ASSUMED sim placeholder) |
| link keepalive | 0.25 s | link keepalive 250 ms : TO_BE_IDENTIFIED (ASSUMED sim placeholder) |

Micro-integration step 0.0025 s (ASSUMED) resolves bus delay 15 ms + jitter 5 ms and sub-period detection latency.

## 4. Message contract exercised (INTERFACE_SPECIFIED)

Common header on every downlink message: `schema_version`, `mission_id`, `segment_id`, `seq` (monotonic), `t_mono` [s], `valid`, `quality`, `integrity` (CRC proxy), frame tag `NED`, units tag `SI`, validity horizon `t_valid_until` (default 6.0 s), heartbeat implied by publication at the mission period.

| Ack code | Meaning | Trigger |
|---|---|---|
| 0 | `ACK_OK` | header valid, payload inside envelope (soft hints clamped) |
| 1 | `RJ_SCHEMA` | `schema_version` not the accepted version |
| 2 | `RJ_FRAME_UNITS` | frame/units tag not NED/SI |
| 3 | `RJ_INTEGRITY` | integrity/CRC mismatch |
| 4 | `RJ_SEQ_ORDER` | `seq` <= last accepted (out-of-order / replay) |
| 5 | `RJ_EXPIRED` | `t_mono` beyond the declared validity horizon on arrival |
| 6 | `RJ_BOUNDS` | hard geometry outside envelope (curvature, invalid segment id) |
| 7 | `RJ_STALE_LINK` | reserved for link-level staleness (monitor M9, not an Ack) |
| 8 | `RJ_FORBIDDEN` | surface request, direct-actuator field, or accommodation request |

Authority rules enforced structurally: mission writes **only** the guidance-input struct (`segment id`, depth hint, speed hint, slope hint). There is **no** code path from any mission field to an actuator channel; soft hints are clamped to the local envelope, never obeyed raw; local magnitude/rate/safety authority always wins.

## 5. FROZEN fault schedule and monitor bounds (all ASSUMED, declared before the run)

| Monitor | Threshold / debounce | Response | Latch | Declared bound from onset | from condition crossing |
|---|---|---|---|---|---|
| M1 LEAK | leak proxy, debounce 0.05 s | SAFE_HOLD | YES | 0.100 s | 0.100 s |
| M2 UNDERVOLTAGE | V < 0.85 pu, debounce 0.10 s | SAFE_HOLD | NO | 0.150 s | 0.150 s |
| M3 WATCHDOG_OVERRUN | 3 consecutive controller deadline misses | SAFE_HOLD | NO | 0.125 s | 0.050 s |
| M4 ACTUATOR_STUCK_CURRENT | cmd-vs-shadow residual > 2.0 deg or current proxy > 0.50 pu, debounce 0.20 s | CONSTRAIN -> SAFE_HOLD after 2.0 s | NO | 0.250 s | 0.250 s |
| M5 IMU_STALE | IMU age > 0.15 s | SAFE_HOLD | NO | 0.225 s | 0.050 s |
| M6 DVL_STALE | DVL age > 1.00 s | CONSTRAIN -> SAFE_HOLD after 5.0 s dead-reckoning budget | NO | 1.150 s | 0.050 s |
| M7 DEPTH_STALE | depth age > 0.50 s | SAFE_HOLD | NO | 0.600 s | 0.050 s |
| M8 BUS_TIMEOUT | no frame of any kind (mission or 0.25 s link keepalive) for 0.50 s | HOLD_LAST_SAFE -> SAFE_HOLD after 2.0 s | NO | 0.820 s | 0.050 s |
| M9 MISSION_STALE | no ACCEPTED mission message for 3.00 s (rejected traffic does not refresh the mission clock) | HOLD_LAST_SAFE -> SAFE_HOLD after 2.0 s | NO | 4.070 s | 0.050 s |

Precedence (highest first): M1 LEAK > M2 UNDERVOLTAGE > M3 WATCHDOG_OVERRUN > M4 ACTUATOR > M5 IMU > M6 DVL > M7 DEPTH > M8 BUS > M9 MISSION_STALE. Recovery requires the condition clear for 1.0 s (hysteresis) and returns through the rate-limited reference path. LEAK never auto-clears: no auto-surface, no automatic accommodation.

### Scenario matrix (16 cases, 40 s each, deterministic)

| # | Code | Scenario | Injection window(s) [s] | Expected monitors | Recovery expected | Note |
|---|------|----------|--------------------------|-------------------|-------------------|------|
| 1 | S01 | NOMINAL | none | none | NO | no fault; false-alarm reference |
| 2 | S02 | INVALID_SCHEMA_FRAME_INTEGRITY | schema [12 24] frame [12 24] integrity [12 24] | M9 | YES | one corruption type per mission tick, cycling; rejected uplink is not fresh uplink so mission goes stale |
| 3 | S03 | OUT_OF_ORDER_REPLAY | replay [12 22] | M9 | YES |  |
| 4 | S04 | EXPIRED_SEGMENT | expired [12 22] | M9 | YES |  |
| 5 | S05 | MISSION_HEARTBEAT_LOSS | heartbeat [12 24] | M9 | YES |  |
| 6 | S06 | BUS_TIMEOUT | bus [12 22] | M8, M9 | YES |  |
| 7 | S07 | STALE_IMU | imu [12 18] | M5 | YES |  |
| 8 | S08 | STALE_DVL | dvl [10 24] | M6 | YES | DVL loss = CONSTRAIN then SAFE_HOLD after declared dead-reckoning budget |
| 9 | S09 | STALE_DEPTH | depth [12 20] | M7 | YES |  |
| 10 | S10 | ACTUATOR_STUCK_CURRENT | actuator [12 20] | M4 | YES |  |
| 11 | S11 | UNDERVOLTAGE | undervoltage [12 16] | M2 | YES |  |
| 12 | S12 | LEAK | leak [18 19] | M1 | NO | latching, no auto-clear, no auto-surface, no auto-accommodation |
| 13 | S13 | WATCHDOG_OVERRUN | wd-overrun [12 17] | M3 | YES |  |
| 14 | S14 | CONFOUNDER_BENIGN | benign confounders only | none | NO | near-threshold but legal: jitter, sub-threshold sensor gaps, sag above V_bo, single miss, over-limit soft hints, burst |
| 15 | S15 | MULTI_FAULT_PRECEDENCE | heartbeat [10 30] undervoltage [14 18] leak [22 23] | M1, M2, M9 | NO | precedence LEAK > UNDERVOLTAGE > MISSION_STALE; leak latches to end |
| 16 | S16 | FORBIDDEN_MISSION_COMMANDS | forbidden [10 22] | M9 | YES | surface request / direct-actuator field / accommodation request: rejected, never issued |

## 6. Results: detection, isolation, confounders, false alarms

| Code | Msgs | Acc | Rej | Ack mismatch | Trips | Expected | FA | Missed | Episodes | HLS [s] | CONSTR [s] | SAFE_HOLD [s] | Recovered | Replay |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S01 | 40 | 40 | 0 | 0 | none | none | 0 | 0 | 0 | 0.00 | 0.00 | 0.00 | YES | YES |
| S02 | 40 | 28 | 12 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 8.95 | YES | YES |
| S03 | 40 | 30 | 10 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 6.95 | YES | YES |
| S04 | 40 | 30 | 10 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 6.95 | YES | YES |
| S05 | 28 | 28 | 0 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 8.95 | YES | YES |
| S06 | 30 | 30 | 0 | 0 | M8,M9 | M8,M9 | 0 | 0 | 1 | 2.00 | 0.00 | 8.72 | YES | YES |
| S07 | 40 | 40 | 0 | 0 | M5 | M5 | 0 | 0 | 1 | 0.00 | 0.00 | 6.85 | YES | YES |
| S08 | 40 | 40 | 0 | 0 | M6 | M6 | 0 | 0 | 1 | 0.00 | 5.00 | 9.05 | YES | YES |
| S09 | 40 | 40 | 0 | 0 | M7 | M7 | 0 | 0 | 1 | 0.00 | 0.00 | 8.50 | YES | YES |
| S10 | 40 | 40 | 0 | 0 | M4 | M4 | 0 | 0 | 1 | 0.00 | 2.00 | 6.80 | YES | YES |
| S11 | 40 | 40 | 0 | 0 | M2 | M2 | 0 | 0 | 1 | 0.00 | 0.00 | 4.90 | YES | YES |
| S12 | 40 | 40 | 0 | 0 | M1 | M1 | 0 | 0 | 1 | 0.00 | 0.00 | 21.98 | NO | YES |
| S13 | 40 | 40 | 0 | 0 | M3 | M3 | 0 | 0 | 1 | 0.00 | 0.00 | 5.93 | YES | YES |
| S14 | 42 | 42 | 0 | 0 | none | none | 0 | 0 | 0 | 0.00 | 0.00 | 0.00 | YES | YES |
| S15 | 20 | 20 | 0 | 0 | M1,M2,M9 | M1,M2,M9 | 0 | 0 | 1 | 2.00 | 0.00 | 25.95 | NO | YES |
| S16 | 40 | 28 | 12 | 0 | M9 | M9 | 0 | 0 | 1 | 2.00 | 0.00 | 8.95 | YES | YES |

### Detection delays vs declared bounds

| Case | Monitor | Latency from fault onset [s] | Bound [s] | Margin [s] | Latency from condition crossing [s] | Bound [s] | Detect -> mode change [s] | Bound [s] |
|---|---|---|---|---|---|---|---|---|
| S02 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 | 0.0000 | 0.200 |
| S03 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 | 0.0000 | 0.200 |
| S04 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 | 0.0000 | 0.200 |
| S05 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 | 0.0000 | 0.200 |
| S06 | M8 BUS_TIMEOUT | 0.2750 | 0.820 | +0.5450 | 0.0075 | 0.050 | 0.0000 | 0.200 |
| S06 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 | 0.2250 | 0.200 |
| S07 | M5 IMU_STALE | 0.1250 | 0.225 | +0.1000 | 0.0000 | 0.050 | 0.0000 | 0.200 |
| S08 | M6 DVL_STALE | 0.9250 | 1.150 | +0.2250 | 0.0225 | 0.050 | 0.0000 | 0.200 |
| S09 | M7 DEPTH_STALE | 0.4750 | 0.600 | +0.1250 | 0.0225 | 0.050 | 0.0000 | 0.200 |
| S10 | M4 ACTUATOR_STUCK_CURRENT | 0.2000 | 0.250 | +0.0500 | 0.1975 | 0.250 | 0.0000 | 0.200 |
| S11 | M2 UNDERVOLTAGE | 0.1000 | 0.150 | +0.0500 | 0.0975 | 0.150 | 0.0000 | 0.200 |
| S12 | M1 LEAK | 0.0250 | 0.100 | +0.0750 | 0.0250 | 0.100 | 0.0000 | 0.200 |
| S13 | M3 WATCHDOG_OVERRUN | 0.0750 | 0.125 | +0.0500 | 0.0225 | 0.050 | 0.0000 | 0.200 |
| S15 | M1 LEAK | 0.0250 | 0.100 | +0.0750 | 0.0250 | 0.100 | NaN | 0.200 |
| S15 | M2 UNDERVOLTAGE | 0.1000 | 0.150 | +0.0500 | 0.0975 | 0.150 | NaN | 0.200 |
| S15 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 | 0.0000 | 0.200 |
| S16 | M9 MISSION_STALE | 2.0500 | 4.070 | +2.0200 | 0.0225 | 0.050 | 0.0000 | 0.200 |

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

## 7. Pareto tracking vector

| Axis | Value | Note |
|---|---|---|
| Tracking | mean surrogate path error 1.144 m, max 7.805 m (MISSION_FOLLOW only) | surrogate geometry, **not** a production tracking metric |
| Actuator margin | min elevator margin 0.263, min rudder margin 0.000 of frozen envelope | envelopes 15/25 deg, 40 deg/s inherited |
| Energy | mean thrust^2 proxy 0.0905, max thrust 0.393 pu | inherited power model, no re-measurement |
| Estimation | **N/A** | measured/estimated streams are `NOT_IMPLEMENTED` until Gate 5; no NEES claim |
| Timing | controller deadline misses 201 (injected), watchdog misses 0, detect->action worst 0.2250 s (bound 0.200 s) | Gate 6B budgets inherited, no new WCET claim |
| Safety | false alarms 0, missed detections 0, surface/accommodation/direct-actuator commands 0/0/0, min depth 3.00 m | local safety authority always wins |

## 8. Hard gates

| ID | Requirement | Result | Detail |
|---|---|---|---|
| HG1 | Deterministic replay: independent reverse-order re-execution reproduces every case hash bit-for-bit | **PASS** | 16/16 case hashes identical |
| HG2 | Monotonic logs: seq strictly +1 and t_mono strictly increasing on every emitted output, every case | **PASS** | monotonic seq/t_mono on 16/16 cases |
| HG3 | No false FDIR: NOMINAL and CONFOUNDER_BENIGN produce zero monitor trips, zero degraded dwell, zero rejects | **PASS** | S01 trips=0 dwell=0.000 rej=0 | S14 trips=0 dwell=0.000 rej=0 (confounder events planted=7) |
| HG4 | Every injected fault detected inside its declared bound (from fault onset AND from condition crossing) | **PASS** | detected 17/17 expected, late=0, missed=0, worst onset-latency margin 0.0500 s |
| HG5 | Zero false alarms across the whole matrix (no monitor trips outside its declared scenario) | **PASS** | false alarms=0 over 16 cases |
| HG6 | Correct isolation: the active-monitor set equals the declared expected set in every case | **PASS** | 16/16 cases with exact monitor-set match |
| HG7 | Precedence and latching: LEAK > UNDERVOLTAGE > MISSION_STALE, and LEAK latches (no auto-clear) | **PASS** | S15 top-monitor precedence ok=1, leak latched to horizon=1 (safe-hold dwell 25.95 s) |
| HG8 | Recovery hysteresis without chatter: one degraded episode per injected fault, min dwell respected, recovery only where declared | **FAIL** | S01(rec 1/0 ep 0/0) S14(rec 1/0 ep 0/0)  |
| HG9 | Bumpless bounded output: no reference step beyond the local rate envelope at any tick, including mode transitions | **PASS** | rate violations=0, magnitude violations=0, worst step/limit ratio=1.0000 |
| HG10 | Zero surface, zero automatic accommodation, zero direct-actuator mission commands issued | **PASS** | issued surface=0 accommodation=0 direct-actuator=0 (requested by mission and rejected: 4 / 4 / 4) |
| HG11 | Path / reference governance: curvature, slope, rate and depth bounds respected; mission hints clamped, never obeyed raw | **PASS** | bound violations=0, clamp events=42, unclamped hints=0, kappa_max=0.0249/0.10, slope_max=6.51/15.0 deg, depth [3.00 9.02] m |
| HG12 | Ack / rejection codes exact: every invalid message rejected with the independently specified code, every valid message accepted | **PASS** | 600 acks, 556 accepted, 44 rejected, 0 code mismatches |
| HG13 | Production + CODEX_VERTICAL_PLAN byte-identical (pre/post fingerprints) | **PASS** | 6 files fingerprinted, 0 changed; Gate 6B n/s1 cross-match 6/6 |
| HG14 | Artifacts written and total footprint < 300 MiB | **PASS** | mat=0.69 MiB, png=0.12 MiB, total=0.81 MiB (< 300 MiB target) |
| HG15 | Label honesty: mission/nav/actuator-feedback rates remain TO_BE_IDENTIFIED, every fault number ASSUMED, hardware NOT_CERTIFIED | **PASS** | mission/nav rates TO_BE_IDENTIFIED (ASSUMED sim placeholders); fault schedule ASSUMED; verdict scope = simulation only |

## 9. Production preservation

| File | Fingerprint pre | Fingerprint post | Identical | Gate 6B n/s1 cross-match |
|---|---|---|---|---|
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | `n=10845.s1=886194.s2=515073390` | YES | YES |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | `n=9402.s1=732890.s2=3334742186` | YES | YES |
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | `n=14601.s1=1095745.s2=3464382495` | YES | YES |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | `n=6065.s1=426918.s2=1254438441` | YES | YES |
| `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990739` | `n=11604.s1=883372.s2=792990739` | YES | YES |
| `suite_results/CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | `n=43101.s1=4310210.s2=3268810005` | YES | YES |

Fingerprint = `n` (bytes) `.s1` (byte sum) `.s2` (index-weighted sum mod 2^32). The Gate 6B cross-match column compares the `n` and `s1` terms against the fingerprints recorded in the accepted Gate 6B mat; the `s2` term of that earlier run is not re-derivable from the three frozen sources, so cross-run equality is asserted on `n` and `s1` only. Within this run, pre/post equality is asserted on the full triple.

## 10. Honest limits

1. **Simulation only.** No HIL, no bench, no vehicle. Every PASS statement is about this isolated harness, not about hardware. `NOT_CERTIFIED`.
2. **The vehicle response is an ASSUMED kinematic surrogate**, deliberately not the production plant. Nothing here validates production dynamics, gains, or tracking metrics.
3. **Fault magnitudes, thresholds, windows and debounces are ASSUMED** placeholders frozen before the run; none is identified from data. Detection "within bounds" means within *these declared* bounds.
4. **Mission / navigation / actuator-feedback rates remain TO_BE_IDENTIFIED.** The 1000 ms mission period and 25 ms nav period are ASSUMED sim placeholders, not requirements.
5. **No transport, middleware, or wire format** is selected or validated; the message set stays `INTERFACE_SPECIFIED` and in-process.
6. **measured / estimated streams do not exist yet** (Gate 5). The uplink StateEstimate used by the mission side is truth-tagged, so nav-integrity monitoring is exercised against publication age only, not against estimator quality.
7. **Fail-silent policy is not certified.** Hold-last-safe then safe-hold is demonstrated in simulation; any real safe-mode, surfacing, or accommodation policy still requires HIL validation (EXTERNAL).
8. **Single MATLAB invocation, no retry**, per the execution policy; there is no tuning loop behind these numbers.
9. **Declared modelling choices that shape the results:** (a) mission-message ingress and Ack generation are placed in the never-skipped high-priority path, so a compute overrun does not itself manufacture a mission-stale confound; (b) the link keepalive (0.25 s, ASSUMED) is separate from the mission application heartbeat, which is what makes BUS_TIMEOUT and MISSION_STALE separable at all; (c) a rejected message never refreshes the mission freshness clock. Different choices would change the reported matrix.
10. **HG12 is a self-consistency check, not an oracle.** The expected Ack code is stamped at emission from the frozen schedule and the receiver re-derives its own code after transport; agreement proves the receiver applies the declared precedence to what actually arrived, it does not independently prove the precedence itself is the right one.

## 11. Verdict and next exact task

**PARTIAL** - 14/15 hard gates.

Gate 7 is **not** PASS. The failing gates above are reported as-is; no threshold was widened and no scenario was removed to force a pass.

**Next exact task (structurally untried):** `gate7_fdir_monitor_observability_separation_audit` - an isolated audit that separates each failing monitor into (a) injection reachability, (b) observable residual, (c) declared bound, so the failure is attributed to schedule, observability, or bound choice before any threshold is touched.

**Do not edit:** `suite_results/CODEX_VERTICAL_PLAN.md` (byte-identical, fingerprinted above).

## 11b. Post-run addendum (analysis only - no re-run, no number changed, verdict stays PARTIAL)

Written after the single MATLAB invocation. Nothing below re-executes anything, edits any metric, or upgrades any gate.

### Why HG8 failed

`S01 NOMINAL` and `S14 CONFOUNDER_BENIGN` are reported as `rec 1/0`: the harness observed `recovered = 1` while the frozen matrix declared `expect_recover = 0`.

Both cases behaved exactly as required - `episodes = 0`, degraded dwell `0.000 s`, zero trips, zero rejects (that is what HG3 confirms). The failure is in the gate's own expectation encoding: `expect_recover = 0` was written to mean "no recovery is expected because nothing should break", but `recovered` is computed as "the last 1.0 s of the run is in MISSION_FOLLOW", which a never-degraded case satisfies trivially. The two fault-free cases therefore fail a comparison that should not have been applied to them at all. The 14 cases that do degrade all match their declared recovery expectation, including the two latching-leak cases (`S12`, `S15`) that correctly do **not** recover.

This is a defect in the acceptance criterion, not evidence of chatter, missed recovery, or bad hysteresis. It is **not** being fixed by widening a threshold or dropping a case, and the verdict is **not** upgraded: a hard gate that fails is reported as failed, and the criterion must be corrected and re-run under a new TASK_ID before Gate 7 can claim PASS.

### Second finding, not gated but reported

The Pareto timing row shows a worst detect-to-mode-change gap of `0.2250 s` against a declared `0.200 s`, from `S06` monitor `M9`. `M8 BUS_TIMEOUT` had already moved the vehicle into HOLD_LAST_SAFE before `M9 MISSION_STALE` tripped, so the next mode *change* attributable to `M9` was the escalation to SAFE_HOLD 2.0 s later, not a response to `M9` itself. The metric measures "time to the next mode change" rather than "time to a response at least as severe as this monitor demands", which is the wrong definition when a higher-precedence monitor is already active. No response was actually late; the required response was already in force. Both this metric and the HG8 criterion should be redefined together.

### Visual QA of `GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.png` (9 panels, inspected)

| Panel | Reading | QA |
|---|---|---|
| 1 response-ladder matrix | S01 and S14 uniformly FOLLOW; every fault case shows one contiguous degraded band with a return to FOLLOW, except the two latching-leak cases which stay in SAFE_HOLD to the horizon | legible, matches the tables |
| 2 S15 precedence | top-monitor trace steps 9 -> 2 -> 9 -> 1 and stays at 1 after the leak; mode reaches SAFE_HOLD and never leaves | legible |
| 3 detection latency vs bound | every bar below the red bound line, worst ratio about 0.8 | legible |
| 4 S05 bounded/bumpless refs | pitch reference inside +-15 deg; the per-guidance-tick rate touches +-10 deg/s at transitions and never exceeds it | legible; the rate trace is spiky by nature (step-and-hold reference) |
| 5 depth, all cases | band 3.00 to 9.02 m, far from the surface, no case trends shallow during a degraded episode | legible; strongest single piece of no-auto-surface evidence |
| 6 3D geometry | waypoint polyline plus two trajectories; at 1.2 m/s over 40 s the surrogate only covers the first leg, so the trajectory occupies a small part of the frame | **weak panel** - honest but low information; a longer horizon or an auto-zoom would fix it |
| 7 Ack histogram | 556 OK against 4/4/4/10/10/12 rejects, log-scale would help but counts are in the table | acceptable |
| 8 ladder dwell per case | stacked hold-last-safe / constrain / safe-hold per case, matches the results table | legible |
| 9 gate summary | 14 green, HG8 red | legible |
| figure banner | underscores in the title render as TeX subscripts (`GATE7_MISSION...` shows as subscripted text) | **cosmetic defect**, no effect on data |

Two cosmetic/QA defects (panel 6 framing, TeX interpretation of underscores in the banner) are recorded rather than fixed, because fixing them would require a second MATLAB invocation that this task is not allowed to make.

### Next exact task, refined by what actually failed

Section 11 names the generic follow-up. Given that the single failure is an acceptance-criterion defect rather than a monitor defect, the precise structurally untried next task is:

**`gate7_fdir_acceptance_criterion_repair_and_rerun`** - restate the recovery gate as a three-valued expectation (`must_recover` / `must_not_recover` / `not_applicable_no_degradation`), redefine the detect-to-action metric as "time until the active response is at least as severe as this monitor requires" so a higher-precedence response already in force counts as immediate, then re-run the identical 16-case frozen matrix under a new TASK_ID with no threshold, window, or scenario changed. Gate 8 stays locked until that run returns 15/15.

## 12. Artifacts

| Artifact | Size |
|---|---|
| `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.md` | this report |
| `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.mat` | 0.69 MiB (config, frozen schedule, per-case logs, gates) |
| `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.png` | 0.12 MiB (9-panel visual QA) |
| `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_run.log` | console transcript |

Host runtime 93.5 s, free space at start 4.34 GiB, MATLAB invocations: 1.
