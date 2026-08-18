# ACTUATOR_BENCH_HIL_ACCEPTANCE_PLAN

**TASK_ID:** ACTUATOR_BENCH_HIL_ACCEPTANCE_PLAN_001  
**Date:** 2026-08-06 08:32:29  
**Document type:** Executable bench / HIL identification + acceptance-test plan only  
**Verdict:** Plan complete. **No hardware action. No production edit. No MATLAB run. No safe-mode promotion.**

## Sources (read-only, ≤3)

1. `suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md` — L0–L4 signal dictionary, CAL-*, AT-B*/AT-H* stubs, predicates, timing/stale, fail-silent
2. `suite_results/ACTUATOR_TELEMETRY_SEPARABILITY.md` — Logical SIL PASS; TRAIN/VAL seeds; frozen ASSUMED thresholds; hardware NOT_CERTIFIED
3. `suite_results/FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS.md` — R-AF1–R-AF3, R-ID1–R-ID3; software-only isolation NOT supportable; auto-accommodation PROHIBITED

Cross-ref (not a fourth claim source): `suite_results/STATE_SPACE_MODEL_AUDIT.md` — plant inputs commanded; actuator position/current/health **NOT_IMPLEMENTED**.

Production `controller_law` / plant / guidance **unchanged**. `CODEX_VERTICAL_PLAN.md` untouched.

---

## 0. Purpose, scope, non-goals

### Purpose

Provide a step-by-step **bench identification** and **HIL acceptance** campaign that:

1. Maps vendor rudder (REQUIRED) / elevator (OPTIONAL) hardware telemetry onto ICD §4 fields.
2. Identifies hardware values currently labeled **TO_BE_IDENTIFIED** (ε_*, I_stall, travel stops, sync, etc.).
3. Accepts or rejects transfer of SIL-frozen predicates to hardware **without retuning the production controller**.
4. Produces auditable evidence for R-AF1–R-AF3 and R-ID1–R-ID2 readiness — **not** for safe-mode enable.

### In scope

- Dry-bench actuator ID, safety interlocks, wiring/time-sync, calibration, fault injection on bench, HIL confounder suites.
- Operator roles, preconditions, abort conditions, data schema, evidence retention.
- Expansion of ICD AT-B* / AT-H* into executable stepwise procedures.
- Acceptance gates with published train/validation split.

### Explicit non-goals

- No production plumbing of telemetry into `controller_law` or `continuous_path_tracking`.
- No accommodation, tangent-exit, surface, mission_manager, or safe-mode enable.
- No automatic latch clear / auto-recovery.
- No vendor protocol invention (CAN/RS485/EtherCAT bit packing deferred to user-supplied ICD).
- No MATLAB execution in this task; no hardware energize in this task.

---

## 1. Provenance labels (mandatory on every numeric)

| Label | Meaning | Use in this plan |
|---|---|---|
| **FIXED** | Verbatim from named source / vendor datasheet once supplied | Control timing, mag/rate limits, CUSUM κ/h/G_nom, published seeds |
| **ASSUMED** | SIL logical default from separability study | SIL models/thresholds until hardware ID replaces them |
| **TO_BE_IDENTIFIED** | Requires bench/HIL measurement or vendor ICD | ε_*, mechanical stops, current scales, thermal limits, integrity algo |
| **TRAIN_DERIVED** | Identified on TRAIN only, frozen before VAL | Hardware predicate thresholds after bench TRAIN |

**Rule:** SIL ASSUMED thresholds **shall not** be copied into hardware isolation as FIXED without a TRAIN→freeze→VAL campaign on real telemetry. Unvalidated ε_* from ICD CAL placeholders are planning aids only — **not** isolation thresholds.

---

## 2. Value registry (FIXED / ASSUMED / TO_BE_IDENTIFIED)

### 2.1 FIXED (vendor-neutral control anchors + SIL CUSUM)

| Item | Value | Provenance |
|---|---|---|
| `dt_controller` | 0.025 s | FIXED ICD / coverage |
| `f_ctrl` | 40 Hz | DERIVED |
| Rudder mag limit `δr_max` | ±25 deg | FIXED ICD / FAULT R-ID1 |
| Elevator mag limit `δe_max` | ±15 deg | FIXED ICD |
| Software command rate limit | 40 deg/s (rudder & elevator cmd) | FIXED `controller_law` |
| Max cmd step / tick | 1.0 deg/sample | DERIVED |
| CUSUM κ / h / G_nom | 0.066156 / 11.066456 / 0.851915 | FIXED CUSUM mat (detect layer only) |
| SIL TRAIN seeds | 6101:6120 (N=20) | FIXED SEPARABILITY |
| SIL VAL seeds | 7101:7140 (N=40) | FIXED SEPARABILITY |
| Disjoint from CUSUM 2101/3101 | YES | FIXED SEPARABILITY |
| Detect latch / isolation latch | Explicit reset only; no auto-clear | FIXED FAULT §6 |
| Auto-accommodation / auto-surface | PROHIBITED | FIXED FAULT |

### 2.2 ASSUMED (SIL only — replace on hardware ID)

| Item | Value | Label |
|---|---|---|
| Position lag τ | 0.050 s (1st-order) | ASSUMED SIL |
| Meas noise σ | 0.050 deg | ASSUMED SIL |
| Current I0 / k_rate / k_hold | 1.20 A / 8.0 / 2.5 | ASSUMED SIL |
| Current noise σ | 0.050 A | ASSUMED SIL |
| Supply / temp stubs | 24.0 V / 35.0 °C | ASSUMED SIL |
| Hydro residual proxy level | 0.350 (synthetic r_B2) | ASSUMED SIL |
| Sensor jump inject | 8.0 deg | ASSUMED SIL |
| Stale hold inject | 0.200 s | ASSUMED SIL |
| `T_stale` | 0.075 s (3 ticks) | ASSUMED ICD §5 |
| `N_miss` | 3 frames | ASSUMED ICD §5 |
| Current/torque min rate | 10 Hz | ASSUMED ICD |
| Voltage/temp min rate | 1 Hz | ASSUMED ICD |
| **Frozen SIL predicates (NOT hardware-certified)** | | |
| P-TRACK | e_track=4.6490 deg, N_track=8 | ASSUMED / TRAIN_DERIVED SIL |
| P-STALL | I_stall=6.627 A, N_stall=8, ω_stall_max=2.0 deg/s, ω_cmd_min=5.0 deg/s | ASSUMED / TRAIN_DERIVED SIL |
| P-OPEN | I_open_max=0.250 A, N_open=8, cmd_min=2.0 deg | ASSUMED / TRAIN_DERIVED SIL |
| P-SENS | d_jump=3.777 deg, N_sens_freeze=8 | ASSUMED / TRAIN_DERIVED SIL |
| P-HYDRO confirm | N_hydro=4 + CUSUM latch + not TRACK/SENS/OPEN/STALL | ASSUMED SIL + FIXED CUSUM |

### 2.3 TO_BE_IDENTIFIED (user / bench must supply)

| Item | Needed for | Owner |
|---|---|---|
| Vendor actuator ICD (bus, PDU, BIT map, endianness) | Field mapping §4 | User / vendor |
| Encoder / position feedback presence, resolution, polarity | R-AF1, CAL-SIGN | User |
| Motor current or torque proxy channel + scale | R-AF2, P-STALL/OPEN | User |
| Health/BIT stall/open/sensor encoding → ICD enums | P-STALL/OPEN/SENS | User |
| Mechanical end-stop angles (if ≠ software ±25/±15) | CAL-ENDSTOP | Bench ID |
| ε_zero, ε_end, ε_hyst (calibration tolerances) | AT-B1 | Bench TRAIN |
| Hardware I_stall, I_open_max, V_undervolt, T_thermal_warn/fault | AT-B2/B3, AT-B-BIT | Bench TRAIN |
| Integrity checksum/auth algorithm | Cyber § ICD 12 | Vendor ICD |
| Common-clock epoch / PTP or PPS sync method | R-TIM-2 | Bench + HIL |
| Dry-bench E-stop rating, current limits, fixture stiffness | Safety §3 | User / lab |
| HIL vehicle/drive-in-loop platform availability | AT-H* | User |
| Elevator telemetry present? (OPTIONAL) | ELEV_* N/A if absent | User |

---

## 3. Required equipment

### 3.1 Minimum (rudder REQUIRED)

| Equipment | Spec / note |
|---|---|
| Rudder actuator + drive matching vehicle intended unit | Or form-fit bench equivalent with same telem schema |
| Position feedback (encoder / potentiometer / drive-reported angle) | Must map to `meas_angle` @ ≥ 40 Hz |
| Current sense **or** documented health BIT with stall/open | R-AF2 |
| Bench fixture locking surface / hinge load cell optional | Stall / hysteresis |
| Programmable command source | Emits L0 `cmd_angle` after mag+rate limit semantics (±25 deg, 40 deg/s) |
| Telemetry logger ≥ 40 Hz with sequence + timestamp | ICD L4 |
| Common time reference | PTP / PPS / shared host clock — method TO_BE_IDENTIFIED |
| Multimeter / clamp meter (calibrated) | Current/voltage BIT cross-check |
| Thermocouple or drive-reported temperature | Thermal BIT |
| E-stop, current-limited PSU, guarded fixture | §4 safety |

### 3.2 Optional

| Equipment | Spec / note |
|---|---|
| Elevator actuator + same logical schema | OPTIONAL; absence ≠ fault |
| HIL host running offline CUSUM/FDI scaffold (read-only w.r.t. production) | Detect + isolation message logging only |
| Inject switches for open/disable, encoder freeze, supply sag | Controlled fault inject |
| Hydro/vehicle motion simulator or recorded R10 helix logs | AT-H hydro / confounders |

### 3.3 Explicitly out of scope for this plan's equipment list

Production vehicle wet-test, ballast, auto-surface hardware, mission_manager.

---

## 4. Dry-bench safety interlocks / E-stop / current limits

**Policy:** No energized motion until PRE-SAFE checklist signed. This document does **not** authorize energization.

| ID | Interlock / limit | Requirement | Provenance |
|---|---|---|---|
| SAFE-1 | Hard E-stop | Cuts drive enable + motor power within **TO_BE_IDENTIFIED** ms; latch requires manual reset | ASSUMED need |
| SAFE-2 | Soft stop | Host command → 0 with rate ≤ 40 deg/s; does not replace E-stop | FIXED rate |
| SAFE-3 | Software mag clamp | Commands never exceed ±δ*_max regardless of script error | FIXED |
| SAFE-4 | PSU current limit | Set ≤ **TO_BE_IDENTIFIED** A (vendor continuous + margin); locked-rotor test uses dedicated limit profile | TO_BE_IDENTIFIED |
| SAFE-5 | Mechanical guards | Hands clear; hinge travel physically limited before first CAL-ENDSTOP | — |
| SAFE-6 | Stall test arming | Locked-rotor only after dual-operator confirm + time-boxed pulse (≤ **TO_BE_IDENTIFIED** s) | TO_BE_IDENTIFIED |
| SAFE-7 | Thermal abort | If `temperature` > T_abort (**TO_BE_IDENTIFIED**) → E-stop path | TO_BE_IDENTIFIED |
| SAFE-8 | No accommodation path | Bench FDI outputs **messages only**; command path remains scripted open-loop / scheduled — never auto-rewrites authority | FIXED FAULT |

**Abort hierarchy (highest first):** E-stop → thermal/current trip → operator abort → script abort condition (§9) → fail-silent FDI inhibit.

---

## 5. Wiring and time-sync checks (pre-power and post-power)

### 5.1 Pre-power wiring checklist (record PASS/FAIL)

| Step | Check | Pass |
|---|---|---|
| W1 | Power polarity / voltage matches vendor ICD | |
| W2 | Enable / inhibit lines default safe (disabled) | |
| W3 | Feedback connector continuity; shield/grounds per vendor | |
| W4 | Current-sense polarity documented | |
| W5 | Logger taps do not back-drive command lines | |
| W6 | E-stop series in enable chain verified open-circuit when pressed | |

### 5.2 Time-sync checklist

| Step | Check | Pass criteria | Provenance |
|---|---|---|---|
| TS1 | Common clock identified | Method recorded (PTP/PPS/host) | TO_BE_IDENTIFIED method |
| TS2 | `timestamp` monotonic on telem | No backward jumps except documented wrap | ICD |
| TS3 | `sequence` increments by 1 | Gap ⇒ DROPOUT | ASSUMED ICD |
| TS4 | Cmd–meas pair skew | \|t_cmd − t_meas\| ≤ 0.025 s for VALID pairs | FIXED R-TIM-2 |
| TS5 | Deliberate skew inject > 0.025 s | Pair marked `STALE_PAIR` / P-INCONC; no `RUDDER_ISOLATED` | AT-H2 |

---

## 6. Calibration sequence (must precede fault AT-B*)

Execute in order. Record ε_* as **TRAIN_DERIVED** candidates; freeze before VAL acceptance.

| Order | Test ID | Procedure (stepwise) | Pass criteria | Labels |
|---|---|---|---|---|
| 1 | CAL-ZERO | (a) Enable drive unloaded. (b) Command 0 for ≥ 2 s. (c) Log `meas_angle`. (d) Compute mean/std. | \|mean(meas)\| ≤ ε_zero | ε_zero **TO_BE_IDENTIFIED** (ICD planning placeholder 0.2 deg — **not** isolation thr) |
| 2 | CAL-SIGN | (a) Positive cmd pulse ≤ +5 deg, ≤ 10 deg/s. (b) Observe Δmeas. | sign(Δmeas)=sign(Δcmd) | Fail ⇒ calibration FAIL, not hydro isolation |
| 3 | CAL-HYST | (a) Triangle ±min(10 deg, 0.5·δ*_max) at ≤ 10 deg/s. (b) Measure blind-zone max\|cmd−meas\|. | ≤ ε_hyst | rate ASSUMED; ε_hyst **TO_BE_IDENTIFIED** |
| 4 | CAL-RATE | (a) Slew cmd at 40 deg/s unloaded within soft limits. (b) Estimate meas_rate. | \|meas_rate\| ≥ 0.8·cmd_rate; no FAULT_STALL | 0.8 ASSUMED; 40 deg/s FIXED |
| 5 | CAL-ENDSTOP | (a) Approach software ±δ*_max only. (b) If mechanical stop ≠ software, approach under interlock with reduced current. | meas within ε_end of stop; BIT may assert | stop angles / ε_end **TO_BE_IDENTIFIED** |
| 6 | CAL-MAP | Publish sign, zero offset, counts→rad scale into calibration table | Table signed by Test Lead | — |

**Gate CAL-G1:** All CAL-* PASS with recorded ε_* before AT-B2+.

---

## 7. Data schema (evidence logs)

### 7.1 Per-frame telem (ICD §4; rudder required)

Store one row per frame, surface tag `{rudder|elevator}`:

`surface, cmd_angle_rad, meas_angle_rad, applied_angle_rad, motor_current_or_torque, supply_voltage, temperature, health_bit, sat_mag, sat_rate, timestamp_s, sequence, validity, quality, stale, dropout`

### 7.2 Monitor / FDI log (message-only)

`t, state, RUDDER_RESID_ANOMALY, ISOLATION_INCONCLUSIVE_reason, RUDDER_ISOLATED_class, evidence_ids, reset_events`

### 7.3 Sim-only / inject truth (L5 — offline scoring only)

`eta_true, stuck_true, open_true, sensor_true, hydro_true, truth_class, inject_t0` — **NEVER** fed to online predicates (R-SEP-1).

### 7.4 Run metadata

`run_id, test_id, operator, date, TRAIN|VAL|SMOKE, seed_or_rep, firmware_rev, calib_table_id, interlock_checklist_id, abort_flag`

### 7.5 Retention

| Artifact | Retention | Integrity |
|---|---|---|
| Raw telem + FDI logs | ≥ **TO_BE_IDENTIFIED** (ASSUMED planning: 5 years or project closeout) | checksum manifest |
| Signed test records (§14) | Same | PDF/md + hash |
| Calibration tables | Versioned; immutable after freeze | git or vault |
| Photos of wiring / fixture | Per campaign | — |
| L5 inject configs | With offline scores only | Separate path from online inputs |

---

## 8. Operator roles

| Role | Authority | May not |
|---|---|---|
| **Test Lead** | Approves energize, freeze thresholds, sign PASS/FAIL | Change production controller |
| **Bench Operator** | Runs scripts, presses E-stop, logs | Declare hardware certified alone |
| **Safety Observer** | Monitors interlocks; may abort anytime | Operate command script simultaneously (independence) |
| **Data Recorder** | Verifies schema, sync, checksums | Edit L5 into online inputs |
| **FDI Analyst** (offline) | Scores P/R after freeze | Reset latches without procedure; enable accommodation |

Reset of `MONITOR_RESET` / `ISOLATION_RESET`: human or validated procedure only (**FIXED**).

---

## 9. Preconditions, abort conditions

### 9.1 Global preconditions (every AT-*)

1. PRE-SAFE checklist signed (SAFE-1..8, W1–W6).  
2. CAL-G1 PASS for any test requiring calibrated meas.  
3. Telemetry rate ≥ 40 Hz for `meas_angle` (R-AF1).  
4. R-AF2 path present (current **or** health_bit with stall/open meaning).  
5. Logger writing schema §7; L5 segregated.  
6. No production code checkout modifications for this campaign.  
7. User-supplied vendor ICD + bench availability (§15) confirmed.

### 9.2 Abort conditions (immediate stop + FAIL or INCOMPLETE)

| Abort ID | Condition | Record |
|---|---|---|
| A1 | E-stop pressed or enable lost unexpectedly | FAIL-SAFE |
| A2 | Current > SAFE-4 trip | FAIL-SAFE |
| A3 | Temperature > T_abort | FAIL-SAFE |
| A4 | Uncommanded motion | FAIL-SAFE |
| A5 | Integrity / checksum storm | FAIL_SILENT expected path; abort if command path compromised |
| A6 | Time sync loss (skew unmeasurable) | INCOMPLETE |
| A7 | Schema field missing for required rudder L1 | NONCOMPLIANT R-AF1 |
| A8 | Any script attempts accommodation / authority rewrite | **HARD FAIL** — campaign invalid |

---

## 10. Train / validation split (prespecified)

### 10.1 SIL reference (already published — do not reuse as hardware claim)

| Set | Seeds | N | Role |
|---|---|---:|---|
| SIL TRAIN | 6101:6120 | 20 | SIL thr ID (done; frozen) |
| SIL VAL | 7101:7140 | 40 | SIL score (PASS logical) |

### 10.2 Hardware bench/HIL split (new campaign)

| Set | Definition | N (min) | Role |
|---|---|---:|---|
| HW-TRAIN | First chronological block of healthy + per-class inject reps; seeds/reps **8101:8120** (published here) | 20 episodes (≥2 per isolable class + healthy) | Identify hardware ε_*, I_*, predicate thr → freeze |
| HW-VAL | Disjoint block **9101:9140** | 40 episodes | Score gates after freeze; **no thr retune** |
| Disjoint | HW-TRAIN ∩ HW-VAL = ∅; also disjoint from SIL 6101/7101 and CUSUM 2101/3101 | — | YES required |
| Freeze rule | Thresholds written to `HW_PRED_THRESHOLDS_FREEZE.md` with timestamp **before** HW-VAL open | — | Mandatory |

If hardware disagrees with SIL ASSUMED models: **revise thresholds / mapping only** — **do not retune controller** (SEPARABILITY next-step policy).

---

## 11. Acceptance gates (prespecified)

All gates evaluated on **HW-VAL** after freeze unless noted. SIL VAL numbers are reference only.

| Gate ID | Metric | Pass criterion | Notes |
|---|---|---|---|
| G-ALIGN | Time alignment | ≥ 99% of paired samples \|Δt\| ≤ 0.025 s; else STALE_PAIR | R-TIM-2 |
| G-POS | Healthy position error | HW-VAL healthy: p50/p95 \|e_pos\| ≤ freeze envelopes from HW-TRAIN | Distributions recorded |
| G-PR | Per-class precision/recall | Isolable classes TRACK/STALL/OPEN/SENS/HYDRO: P≥95% and R≥95% each | Elevator N/A if absent |
| G-FA | Healthy false isolation | Rate of `RUDDER_ISOLATED` on healthy ≤ 1% | Match SIL gate |
| G-DELAY | Detection/isolation delay | Record med/p95 per class after t_fault; p95 ≤ **TO_BE_IDENTIFIED** budget (planning ASSUMED 3.0 s detect-layer heritage — **not** certified for hardware until set) | Set budget before HW-VAL |
| G-FAILSIL | Stale/conflict | STALE/DROPOUT/CONFLICT asserting `RUDDER_ISOLATED` = 0 | FIXED policy |
| G-NOACC | No automatic accommodation | Audit log: zero authority changes from FDI | FIXED FAULT |
| G-AF | R-AF1/R-AF2 provisioning | Meas @≥40 Hz; current or health present | Entry to isolation claims |
| G-ID2 | Confounder rejection | Under Vc / G_nom± / IMU-DVL hard-fault cases: no `RUDDER_ISOLATED` without actuator corroboration | FAULT R-ID2 |

**Overall hardware certification:** all G-* PASS → `HARDWARE_TELEMETRY_ACCEPTED` for isolation **evidence path** only.  
**Still forbidden:** safe-mode promotion, accommodation enable, production wiring.

---

## 12. Expanded AT-B* (bench) — stepwise

Notation: each test produces a signed §14 record. Rudder mandatory; elevator optional mirror with `ELEV_` prefix.

### AT-B1 — Healthy tracking + CAL suite

| Step | Action | Expect |
|---|---|---|
| B1.1 | Complete §6 CAL-ZERO/SIGN/HYST/RATE/ENDSTOP | CAL-G1 PASS |
| B1.2 | Hold random cmd within ±0.8·δr_max, rate ≤ 20 deg/s, ≥ 30 s | P-TRACK false; health OK |
| B1.3 | Record e_pos distribution | Feed G-POS / HW-TRAIN |
| B1.4 | Verify no `RUDDER_ISOLATED` | G-FA component |

**Pass:** CAL-G1 + healthy track within ε envelopes + no isolation.

### AT-B2 — Stall / locked-rotor

| Step | Action | Expect |
|---|---|---|
| B2.1 | Arm SAFE-6; set current limit profile | Signed |
| B2.2 | Mechanically lock hinge or command into hard fixture | — |
| B2.3 | Apply cmd_rate > ω_cmd_min for ≥ N_stall ticks | — |
| B2.4 | Observe current/BIT and meas_rate | P-STALL; **not** P-HYDRO |
| B2.5 | Release; explicit ISOLATION_RESET | Latch clears only on reset |

**Pass:** P-STALL asserts; P-HYDRO false; G-NOACC.

### AT-B3 — Open / drive loss

| Step | Action | Expect |
|---|---|---|
| B3.1 | Command \|cmd\| > cmd_min | — |
| B3.2 | Disable drive / open enable / pull power under E-stop oversight | — |
| B3.3 | Observe current≈0 or FAULT_OPEN; meas freeze | P-OPEN |
| B3.4 | Confirm no P-HYDRO | — |

**Pass:** P-OPEN; fail-safe stop; G-NOACC.

### AT-B4 — Zero / sign / end stops / hysteresis / rate (detailed evidence of CAL)

Re-run CAL-* with formal distributions (N≥3 reps each direction).  
**Pass:** Same as CAL-G1 with published ε_* freeze candidates.

### AT-B5 — Feedback freeze

| Step | Action | Expect |
|---|---|---|
| B5.1 | Healthy motion baseline | — |
| B5.2 | Freeze encoder / hold last meas while cmd moves (inject) | P-SENS or P-TRACK per freeze policy; **inhibit P-HYDRO** |
| B5.3 | Restore feedback; explicit reset | — |

**Pass:** No hydro isolation on sensor freeze; G-FAILSIL if validity drops.

### AT-B6 — Feedback jump

| Step | Action | Expect |
|---|---|---|
| B6.1 | Inject step \|Δmeas\| > d_jump in one tick | P-SENS |
| B6.2 | Confirm conflict/inconclusive vs HYDRO | No false HYDRO |

**Pass:** P-SENS; G-PR SENS.

### AT-B7 — Dropout / stale

| Step | Action | Expect |
|---|---|---|
| B7.1 | Drop N_miss≥3 frames or hold age > T_stale | validity STALE/DROPOUT |
| B7.2 | Observe FDI | FAIL_SILENT / P-INCONC; **`RUDDER_ISOLATED` count = 0** |

**Pass:** G-FAILSIL.

### AT-B8 — Current / voltage / thermal BIT

| Step | Action | Expect |
|---|---|---|
| B8.1 | Cross-check `motor_current` vs clamp meter | Scale error ≤ **TO_BE_IDENTIFIED** |
| B8.2 | Sag supply to V_undervolt (**TO_BE_IDENTIFIED**) | WARN or P-OPEN path per ICD map |
| B8.3 | Thermal soak or inject temp telemetry | WARN/FAULT_INTERNAL per vendor map; SAFE-7 if T_abort |

**Pass:** BIT mapping table signed; no accommodation.

### AT-B9 — Timing skew (bench)

| Step | Action | Expect |
|---|---|---|
| B9.1 | Offset logger timestamp > 0.025 s vs cmd clock | STALE_PAIR |
| B9.2 | Run isolation predicates | No `RUDDER_ISOLATED` |

**Pass:** G-ALIGN / G-FAILSIL.

---

## 13. Expanded AT-H* (HIL) — stepwise

Preconditions: AT-B1–B9 complete or waived with Test Lead risk acceptance in writing; HW thresholds frozen or HIL uses HW-TRAIN freeze.

### AT-H1 — Schema parity + healthy HIL tracking

| Step | Action | Expect |
|---|---|---|
| H1.1 | Map real drive telem → ICD §4 | Parity checklist ICD §8.2 PASS |
| H1.2 | Replay / closed-loop scheduled cmds at 40 Hz | meas tracks; P-TRACK false |
| H1.3 | Log L0–L4 only into online FDI | L5 absent online |

**Pass:** Schema parity + healthy gates subset.

### AT-H2 — Timing skew > 0.025 s

| Step | Action | Expect |
|---|---|---|
| H2.1 | Introduce sync skew > 1 tick | STALE_PAIR |
| H2.2 | Attempt isolation | No `RUDDER_ISOLATED` |

**Pass:** G-ALIGN / G-FAILSIL.

### AT-H3 — Hydro-effectiveness confounder (R-ID1 probe path)

| Step | Action | Expect |
|---|---|---|
| H3.1 | Known U∈{1.50,1.75,2.00} on R10 envelope (log replay or HIL vehicle) | Envelope FIXED FAULT |
| H3.2 | Small rudder probe within ±25 deg, ≤ 40 deg/s | R-ID1 |
| H3.3 | Case A: meas tracks cmd; inject / emulate η-loss at plant-input channel only | P-HYDRO candidate iff residual anomaly + not TRACK/SENS/OPEN/STALL |
| H3.4 | Case B: hinge stuck (meas≠cmd) | P-TRACK; not HYDRO |

**Pass:** Separability on hardware consistent with G-PR; residual-alone never isolates.

### AT-H4 — Current (Vc) confounder (R-ID2)

| Step | Action | Expect |
|---|---|---|
| H4.1 | Nonzero Vc case (declared magnitude **TO_BE_IDENTIFIED** for campaign) | — |
| H4.2 | Residual may rise | Detect-only allowed |
| H4.3 | Isolation | **Must not** declare `RUDDER_ISOLATED` without actuator corroboration |

**Pass:** G-ID2.

### AT-H5 — Model / G_nom / sensor confounders (R-ID2)

| Step | Action | Expect |
|---|---|---|
| H5.1 | G_nom perturbation **TO_BE_IDENTIFIED** (±% recorded) | — |
| H5.2 | IMU/DVL hard-fault inject on residual inputs | — |
| H5.3 | Isolation decision | No rudder isolation without L1/L2 corroboration |

**Pass:** G-ID2; H2/H7/H8 policy.

### AT-H6 — Combined HIL VAL battery

Execute HW-VAL seeds/reps 9101:9140 covering healthy + TRACK + STALL + OPEN + SENS + HYDRO + STALE + CONFLICT.  
**Pass:** All §11 gates.

### AT-H7 — No automatic accommodation audit

| Step | Action | Expect |
|---|---|---|
| H7.1 | During any latched isolation message | Commands follow pre-script only |
| H7.2 | Diff command authority logs | Zero FDI-driven changes |

**Pass:** G-NOACC.

---

## 14. Requirements → test traceability matrix

| Requirement | Source | Tests | Evidence |
|---|---|---|---|
| R-AF1 meas @ ≥40 Hz aligned | FAULT / ICD | TS4, AT-B1, AT-H1 | Rate + skew stats |
| R-AF2 current or health | FAULT / ICD | AT-B2, B3, B8 | BIT/current logs |
| R-AF3 cmd vs plant-input vs meas boundary | FAULT / ICD | AT-H1, H3 | Schema + L5 segregation check |
| R-ID1 probe vs r(G_nom,u,δr_meas) | FAULT | AT-H3 | Probe records |
| R-ID2 confounder rejection | FAULT | AT-H4, H5 | No false isolation |
| R-ID3 η̂ offline | FAULT | Deferred post-accept offline study | Not gate for this plan PASS |
| R-TIM-1 / R-TIM-2 | ICD | TS*, AT-B9, AT-H2 | Sync reports |
| R-SGN-1 / CAL-* | ICD | AT-B1, B4 | Cal table |
| P-TRACK…P-INCONC | ICD / SIL | AT-B2–B7, AT-H3–H6 | Confusion + P/R |
| Fail-silent stale/conflict | ICD / SIL / FAULT | AT-B7, B9, H2 | G-FAILSIL |
| No auto accommodation / surface | FAULT | AT-H7, SAFE-8 | G-NOACC |
| H1 detect-only heritage | FAULT | AT-H3 residual channel | Alarm≠isolation |
| H7 block isolation w/o position | FAULT | Entry gate G-AF | Checklist |
| Latch explicit reset | FAULT / ICD | AT-B2.5, B5.3 | Reset audit |

SIL AT-S1–S6 remain software regression references; hardware acceptance is AT-B*/AT-H* only.

---

## 15. Blockers / materials the user must supply

Campaign **cannot energize or certify** until the following are provided:

1. **Vendor actuator ICD** — electrical, bus/protocol, PDU layout, BIT code map to ICD enums, polarity, absolute/encoder counts.  
2. **Confirmation of encoder / position telemetry** at ≥ 40 Hz (R-AF1) and **current or health** (R-AF2).  
3. **Physical bench** — fixture, E-stop, current-limited supply, guarded travel, calibrated meters.  
4. **Signed lab safety procedure** aligning SAFE-1..8 with site rules (T_abort, current limits, stall pulse duration).  
5. **Time-sync method** choice (PTP/PPS/host) and cabling.  
6. **HIL platform access** (or recorded vehicle logs with declared U/Vc) for AT-H3–H6.  
7. **Authority letter** that FDI remains message-only (no production merge, no safe-mode enable).  
8. Elevator: explicit **PRESENT** or **ABSENT** declaration.

Until items 1–3 exist: status remains **BLOCKED — EXTERNAL HARDWARE / ICD**.

---

## 16. Test record template

```
TEST RECORD — ACTUATOR_BENCH_HIL_ACCEPTANCE_PLAN_001
run_id: ____________  test_id: AT-___  date: __________
TRAIN / VAL / SMOKE: ______  seed/rep: ______
surface: rudder / elevator
operators: Lead______ Op______ Safety______ Recorder______

Preconditions §9.1: PASS / FAIL
Cal table id: ________  Firmware: ________
Interlock checklist id: ________

Procedure steps executed: (attach script log)
Inject / fault class truth (L5 offline): ________
Online inputs L0–L4 only confirmed: YES / NO

Metrics:
  align_pct_le_1tick: ____
  e_pos p50/p95 (deg): ____ / ____
  pred_class: ________  truth_class: ________
  t_detect_s / t_isolate_s: ____ / ____
  RUDDER_ISOLATED asserted: YES / NO
  STALE/CONFLICT isolation count: ____
  accommodation events: ____

Abort? NO / YES (id A__): ________
PASS / FAIL / INCOMPLETE
Sign: Lead__________ Safety__________ Date__________
Hash of raw log: ____________________
```

---

## 17. Decision rule (unchanged causal policy)

```
RUDDER_ISOLATED := (P-TRACK ∨ P-STALL ∨ P-OPEN ∨ P-HYDRO ∨ P-SENS)
                 ∧ ¬P-INCONC
Priority on conflict among isolable predicates → P-INCONC (fail-silent)
STALE/DROPOUT → P-INCONC; never RUDDER_ISOLATED
Latch until explicit ISOLATION_RESET
Messages only — no control authority change
```

Hardware thresholds replace SIL ASSUMED only via HW-TRAIN freeze → HW-VAL.

---

## 18. Execution order (campaign checklist)

1. Collect §15 materials → clear EXTERNAL HARDWARE gate.  
2. PRE-SAFE + wiring + sync.  
3. CAL sequence → CAL-G1.  
4. AT-B1–B9 on HW-TRAIN → identify thr → **freeze**.  
5. AT-B* sample on HW-VAL (subset) + AT-H1–H2.  
6. AT-H3–H5 confounders.  
7. AT-H6 full HW-VAL battery → score §11.  
8. AT-H7 accommodation audit.  
9. Publish hardware accept/reject report (future task).  
10. **Stop** — do not promote safe-mode.

---

## 19. External-hardware gate status

| Gate | Status |
|---|---|
| Plan document complete | **PASS** (this file) |
| Logical SIL separability | **PASS** (prior; NOT_CERTIFIED hardware) |
| Vendor ICD supplied | **NOT SUPPLIED** → blocker |
| Encoder/current telem confirmed on bench | **NOT CONFIRMED** → blocker |
| Bench/HIL energized / executed | **NOT EXECUTED** (forbidden this task) |
| Hardware acceptance G-* | **NOT RUN** |
| Production controller edit | **NONE** (frozen) |
| Safe-mode / accommodation promotion | **NOT AUTHORIZED** |

### EXTERNAL-HARDWARE GATE: **BLOCKED**

Waiting on user-supplied actuator/vendor ICD, encoder/current telemetry, and bench (§15).  
No safe-mode promotion. No production edit. No MATLAB run in this task.

---

## Files

- `suite_results/ACTUATOR_BENCH_HIL_ACCEPTANCE_PLAN.md` (this plan)
- Append: `suite_results/PITCH_CONTROL_RESEARCH_LOG.md`
- Cross-ref append: `suite_results/STATE_SPACE_MODEL_AUDIT.md`
- Production unchanged; `CODEX_VERTICAL_PLAN.md` untouched.
