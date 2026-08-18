# ACTUATOR_FEEDBACK_TELEMETRY_ICD

**TASK_ID:** ACTUATOR_FEEDBACK_TELEMETRY_ICD_001  
**Date:** 2026-08-06 08:12:43  
**Document type:** Logical interface control document (ICD) only  
**Verdict:** Spec complete for rudder-minimum / elevator-optional actuator feedback + telemetry. **No production edit. No MATLAB run. No vendor protocol invented.**

## Sources (read-only, ≤3)

1. `suite_results/FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS.md` — software-only isolation NOT supportable; R-AF1–R-AF3 / R-ID1–R-ID3 gate actuator corroboration before `RUDDER_ISOLATED`
2. `controller_law.m` — commanded `delta_r`, `delta_e`, `thrust`; mag sat on `delta_r_max` / `delta_e_max`; rate limit `max_d* = deg2rad(40)*dt_controller`; no actuator feedback consumed
3. `continuous_path_tracking.m` — plant+controller every `dt_controller`; `controls.delta_r/delta_e/thrust` to plant; suite logs command-side angles only

Cross-ref (not a fourth claim source): `suite_results/STATE_SPACE_MODEL_AUDIT.md` — plant inputs commanded; actuator position/current/health **NOT_IMPLEMENTED**.

Production `controller_law` / plant / guidance **unchanged**. `CODEX_VERTICAL_PLAN.md` untouched.

---

## 0. Scope, non-goals, provenance labels

### In scope

- Logical signal dictionary for **rudder (REQUIRED)** and **elevator (OPTIONAL)** feedback/telemetry.
- Timing, range, rate, units, frames/signs, calibration, time sync, logging, sim–hardware parity.
- Strict separation of **sim-only fault truth** from **online monitor inputs**.
- Isolation **predicates** (logical) for position-tracking error, stall, open/drive loss, feedback-sensor fault, hydrodynamic effectiveness loss — thresholds unvalidated → **TBD**.
- State machine / messages, latch/reset authority, fail-silent behavior, cybersecurity/data-integrity basics, bench/SIL/HIL acceptance tests.

### Explicit non-goals (this task)

- No accommodation, safe-mode, tangent-exit, surface, or mission_manager wiring.
- No production plumbing of telemetry into `controller_law` or `continuous_path_tracking`.
- No vendor bus/protocol (CAN/RS485/EtherCAT/etc.) selection or bit packing.
- No severity η̂ promotion, no CUSUM retune, no FDI enable.

### Provenance label definitions (apply to every numeric)

| Label | Meaning |
|---|---|
| **FIXED** | Taken verbatim from named source or this task statement |
| **DERIVED** | Arithmetic consequence of FIXED values |
| **ASSUMED** | Logical default for ICD completeness; not validated on hardware |
| **TO_BE_IDENTIFIED** | Requires vendor datasheet, bench ID, or separate campaign |

---

## 1. Control-loop timing baseline (derivation anchor)

| Item | Value | Provenance |
|---|---|---|
| Controller / plant step `dt_controller` | 0.025 s | **FIXED** (task; `continuous_path_tracking` multi-rate example `0.075/0.025 = 3`) |
| Controller update rate `f_ctrl` | 40 Hz | **DERIVED** (= 1/0.025) |
| `controller_law` empty-global fallback `dt_controller` | 0.0375 s | **FIXED** (code default) — **ICD design rate remains 0.025 s**; fallback noted only |
| Rudder mag limit `δr_max` | ±25 deg (±π·25/180 rad) | **FIXED** (task; FAULT R-ID1 `δr_max=25°`) |
| Elevator mag limit `δe_max` | ±15 deg | **FIXED** (task; matches `controller_law` use of `delta_e_max` and prior audit citation) |
| Software command rate limit (rudder) | 40 deg/s | **FIXED** (`controller_law`: `max_dr = deg2rad(40)*dt`) |
| Software command rate limit (elevator) | 40 deg/s | **FIXED** (`controller_law`: `max_de = deg2rad(40)*dt`) — elevator optional for telemetry; rate still applies to command side |
| Max commanded step per control tick (rudder) | 1.0 deg/sample | **DERIVED** (= 40 deg/s × 0.025 s) |
| Max commanded step per control tick (elevator) | 1.0 deg/sample | **DERIVED** (same rate limit) |
| Guidance ZOH example | `dt_guidance` / `dt_controller` integer period (e.g. 3) | **ASSUMED** pattern from `continuous_path_tracking` comment; guidance rate not part of actuator ICD |

**ICD requirement R-TIM-1:** Actuator measured-angle telemetry for rudder SHALL be available at **≥ `f_ctrl` = 40 Hz** (**DERIVED** from FAULT R-AF1 “≥ control rate” + FIXED `dt_controller`). Subsampling below control rate is non-compliant for isolation corroboration.

**ICD requirement R-TIM-2:** Command and measured samples used in isolation predicates SHALL be time-aligned to within **1 control tick** (≤ 0.025 s) (**DERIVED**). Larger skew → mark pair `VALIDITY=STALE_PAIR` (**ASSUMED** name).

---

## 2. Interface layers (do not conflate)

| Layer | Content | Online monitor may use? |
|---|---|---|
| **L0 Command** | Controller-issued surface command after mag/rate limit (`delta_r` / `delta_e` from `controller_law`) | YES |
| **L1 Measured / applied angle** | Feedback transducer or drive-reported surface angle | YES (required for isolation) |
| **L2 Electrical / thermal** | Motor current or torque proxy, supply voltage, temperature | YES (rudder min: current **or** health; see §3) |
| **L3 Health / BIT** | Discrete health, saturation flags, BIT codes | YES |
| **L4 Transport meta** | Timestamp, sequence, validity/quality, stale/dropout | YES |
| **L5 Sim-only fault truth** | Injected η, stuck angle, open-circuit flag, sensor-bias truth, etc. | **NO** — logging/audit only; never fed to online isolation predicates |

Today’s production path (`continuous_path_tracking` → `controls.*` → plant) exposes **L0 only**. L1–L4 **NOT_IMPLEMENTED**. L5 exists only as offline inject conventions (FAULT: η at plant-input invisible to detector by design).

---

## 3. Channel applicability

| Channel | Role | Telemetry mandate |
|---|---|---|
| Rudder `δr` | Yaw authority; isolation gate for `RUDDER_ISOLATED` | **REQUIRED** (FAULT R-AF1, R-AF2) |
| Elevator `δe` | Pitch authority; confounder / future isolation | **OPTIONAL** (same logical schema; may be absent) |
| Thrust | Speed; out of this ICD’s actuator-surface scope | **OUT OF SCOPE** (command exists; thruster feedback not specified here) |

If elevator telemetry is absent, elevator-related isolation predicates remain **NOT_APPLICABLE**; rudder isolation SHALL NOT assume elevator health from silence.

---

## 4. Logical signal dictionary

Units in the **software/control domain** match `controller_law` / plant: angles and rates in **radians** and **rad/s** unless a field is explicitly labeled `_deg`. Human ICD tables also show degrees for readability.

### 4.1 Per-surface fields (rudder required; elevator optional)

| Field ID | Description | Unit | Range / enum | Update rate | Provenance |
|---|---|---|---|---|---|
| `cmd_angle` | Commanded surface angle after controller mag+rate limit (L0) | rad | rudder ∈ [−δr_max, +δr_max]; elevator ∈ [−δe_max, +δe_max] | ≥ 40 Hz | Limits **FIXED**; rate **FIXED** |
| `meas_angle` | Measured / reported surface angle (L1) | rad | Same mechanical travel as surface; see §6 | ≥ 40 Hz | Rate **DERIVED**; full-scale travel **TO_BE_IDENTIFIED** if beyond software limit |
| `applied_angle` | Best estimate of hydrodynamic applied angle at plant input | rad | Same as meas unless drive model differs | ≥ 40 Hz or same as meas | **ASSUMED** `applied_angle ≡ meas_angle` until drive model ID; sim may set independently (§8) |
| `motor_current` **or** `torque_proxy` | Electrical load indicator (L2) | A or N·m (declare one) | **TO_BE_IDENTIFIED** | ≥ 40 Hz preferred; ≥ 10 Hz min | Min rate **ASSUMED**; scale **TO_BE_IDENTIFIED** |
| `supply_voltage` | Actuator / drive supply | V | **TO_BE_IDENTIFIED** | ≥ 1 Hz | **ASSUMED** slow thermal/supply class |
| `temperature` | Drive or motor temperature | °C | **TO_BE_IDENTIFIED** | ≥ 1 Hz | **ASSUMED** |
| `health_bit` | Aggregated health / BIT discrete (L3) | enum / bitfield | Logical enums §4.2; vendor bits **TO_BE_IDENTIFIED** | ≤ 1 control tick latency | — |
| `sat_mag` | Magnitude saturation active | bool | {0,1} | ≥ 40 Hz | Aligns with controller mag sat semantics (**ASSUMED** mapping) |
| `sat_rate` | Rate saturation / slew limited | bool | {0,1} | ≥ 40 Hz | Aligns with 40 deg/s software slew (**FIXED** rate) |
| `timestamp` | Sample time of this telemetry frame | s (common mission clock) | monotonic | with frame | Epoch **TO_BE_IDENTIFIED**; sync §7 |
| `sequence` | Monotonic frame counter | uint32 (logical) | wraps at 2³²−1 | with frame | Width **ASSUMED** |
| `validity` | Frame validity | enum §4.3 | — | with frame | — |
| `quality` | Soft quality metric | enum or [0,1] | **ASSUMED** {GOOD, DEGRADED, BAD} or scalar | with frame | Encoding **ASSUMED** |
| `stale` | Age exceeded stale threshold | bool | — | derived | Threshold §5 |
| `dropout` | Missing expected frame | bool / count | — | derived | — |

**R-AF2 compliance:** Rudder SHALL provide (`health_bit` with documented stall/open meaning) **and/or** (`motor_current` or `torque_proxy`). At least one path required; both preferred.

### 4.2 Logical `health_bit` enums (vendor-neutral)

| Enum | Meaning |
|---|---|
| `OK` | No actuator health fault asserted |
| `WARN` | Non-fatal BIT / thermal / voltage warn |
| `FAULT_STALL` | Stall / overload asserted by drive or monitor |
| `FAULT_OPEN` | Open circuit / drive loss / enable lost |
| `FAULT_SENSOR` | Feedback sensor BIT fail |
| `FAULT_INTERNAL` | Unspecified drive internal fault |
| `NOT_REPORTED` | Channel absent or not yet provisioned |

Vendor-specific BIT codes map **into** these enums via a calibration table (**TO_BE_IDENTIFIED**). This ICD does not define bit positions.

### 4.3 `validity` enums

| Enum | Meaning |
|---|---|
| `VALID` | Passes CRC/integrity (if any), in-range, not stale |
| `INVALID_RANGE` | Outside declared physical range |
| `INVALID_INTEGRITY` | Checksum / auth failure |
| `STALE` | Age > stale threshold |
| `DROPOUT` | Expected frame missing |
| `NOT_AVAILABLE` | Optional channel not provisioned (elevator OK; rudder non-compliant) |

---

## 5. Timing, stale, dropout (numeric)

| Item | Value | Provenance |
|---|---|---|
| Rudder `meas_angle` min rate | 40 Hz | **DERIVED** |
| Elevator `meas_angle` min rate (if present) | 40 Hz | **DERIVED** (same control alignment) |
| Current/torque min rate | 10 Hz | **ASSUMED** |
| Voltage/temp min rate | 1 Hz | **ASSUMED** |
| Max end-to-end telemetry latency (meas vs cmd align) | 0.025 s | **DERIVED** (1 tick) |
| Stale threshold `T_stale` | 0.075 s (3 ticks) | **ASSUMED** |
| Dropout declare after consecutive misses `N_miss` | 3 frames at expected rate | **ASSUMED** |
| Sequence gap ⇒ dropout | any Δseq ≠ 1 (mod 2³²) | **ASSUMED** |

On `STALE` or `DROPOUT`: isolation predicates that require that signal SHALL inhibit (fail-silent to **inconclusive**, not to `RUDDER_ISOLATED`) — see §10–§11.

---

## 6. Frames, signs, units

| Rule | Specification | Provenance |
|---|---|---|
| Software angle unit | radians | **FIXED** (`controller_law` / plant) |
| Sign of `cmd_angle` (rudder) | Identical to production `delta_r` sign convention | **FIXED** (command side) |
| Sign of `meas_angle` | SHALL match `cmd_angle` (same positive direction) after calibration | **ASSUMED** until zero/end-stop tests PASS |
| Frame | BODY / vehicle surface hinge angle, not NED | **ASSUMED** (surface actuator) |
| Rate of measured angle for monitors | `(meas[k]−meas[k−1])/dt_telem` | **DERIVED** method; filter **TO_BE_IDENTIFIED** |
| Elevator sign | Respect production `elevator_sign` on command path; meas SHALL be calibrated to same physical sense as `delta_e` | **FIXED** existence of `elevator_sign`; meas mapping **TO_BE_IDENTIFIED** |

**R-SGN-1:** A positive step in `cmd_angle` with healthy tracking SHALL produce a positive step in `meas_angle` within hysteresis (§7). Sign inversion ⇒ calibration FAIL, not isolation of hydro loss.

---

## 7. Calibration, zero, end-stop, hysteresis

Bench / SIL procedures (logical; no vendor script):

| Test ID | Procedure | Pass criteria | Provenance |
|---|---|---|---|
| CAL-ZERO | Command 0; record `meas_angle` over ≥ 2 s | \|mean(meas)\| ≤ ε_zero | ε_zero **TO_BE_IDENTIFIED** (ASSUMED placeholder 0.2 deg for planning only — **not** an isolation threshold) |
| CAL-ENDSTOP | Command ±δ*_max software limits; approach mechanical stops only under bench interlock | meas reaches within ε_end of stop; BIT may assert end-stop | stop angles **TO_BE_IDENTIFIED** if ≠ software limits |
| CAL-HYST | Triangle cmd within ±min(10 deg, 0.5·δ*_max) at ≤ 10 deg/s | max\|cmd−meas\| blind zone ≤ ε_hyst | rates **ASSUMED**; ε_hyst **TO_BE_IDENTIFIED** |
| CAL-RATE | Cmd slew at software 40 deg/s; verify meas tracks without BIT stall | \|meas_rate\| ≥ 0.8·cmd_rate when unloaded | 0.8 **ASSUMED**; 40 deg/s **FIXED** |
| CAL-SIGN | Positive cmd pulse; meas Δ same sign | sign match | — |

Unvalidated ε_* values are **not** to be copied into online isolation thresholds.

---

## 8. Sim–hardware parity and fault-truth separation

### 8.1 Logging boundary (FAULT R-AF3)

| Stream | Sim | Hardware | Online isolation input? |
|---|---|---|---|
| `cmd_angle` | `controller_law` output / `controls.delta_*` | Same logical command | YES |
| `meas_angle` | Emulated feedback (§ next gate) | Transducer / drive report | YES |
| `applied_angle` / plant input | Explicit plant-input angle after inject | Not directly observable; use meas or drive model | YES only if not taken from L5 truth |
| L5 fault truth (`η_true`, `stuck_true`, …) | Sim inject parameters | N/A | **NO** |
| Residual CUSUM (`RUDDER_RESID_ANOMALY`) | Offline scaffold | Same detect-only role | Detect layer only; **not** isolation proof |

**R-SEP-1:** Any field named `*_true`, `*_inject`, `eta_plant`, or equivalent SHALL be tagged `SIM_ONLY` and excluded from online monitor input structs.

**R-SEP-2:** In sim, multiplicative effectiveness inject (FAULT: `δr_app = η·δr_cmd`) SHALL be visible on an explicit plant-input log channel distinct from `cmd_angle`, and SHALL NOT be aliased as `meas_angle` unless the emulator models a sensor that sees applied angle (**ASSUMED** default: meas tracks **commanded** hinge unless fault-class under test says otherwise — emulator study decides).

### 8.2 Parity checklist

1. Same field IDs, units, signs, sequence/validity semantics.  
2. Same `dt` alignment rules vs `dt_controller = 0.025` s.  
3. Same saturation semantics relative to ±25 deg / ±15 deg / 40 deg/s.  
4. Hardware-only: voltage/temp ranges **TO_BE_IDENTIFIED**; sim may stub with `NOT_REPORTED` if unused by predicates under test.

---

## 9. Isolation predicates (logical; thresholds TBD)

Predicates consume **only** L0–L4 (+ vehicle motion sensors already available). They do **not** consume L5. CUSUM residual may gate **detect** but cannot alone set `RUDDER_ISOLATED` (FAULT §7).

Notation: `e_pos = wrap(cmd_angle − meas_angle)` [rad]. Persistence counts use control ticks of 0.025 s (**FIXED**).

| ID | Fault class | Predicate (logical) | Thresholds | Notes |
|---|---|---|---|---|
| P-TRACK | Position-tracking error (servo follows poorly / stuck / jam at hinge) | `validity==VALID` AND \|e_pos\| > e_track for N_track ticks AND NOT (cmd and meas both rate-sat consistently) | e_track, N_track = **TBD** | Distinguishes from hydro loss when hinge disagrees with cmd |
| P-STALL | Stall / overload | `health_bit==FAULT_STALL` OR (current/torque > I_stall for N_stall AND \|d(meas)/dt\| < ω_stall_max AND \|cmd_rate_cmd\| > ω_cmd_min) | I_stall, N_stall, ω_* = **TBD** | Requires R-AF2 current **or** BIT |
| P-OPEN | Open / drive loss | `health_bit==FAULT_OPEN` OR (supply_voltage < V_undervolt) OR (current ≈ 0 for N_open while \|cmd\| > cmd_min AND meas frozen) | V_*, N_open, cmd_min = **TBD** | — |
| P-SENS | Feedback-sensor fault | `health_bit==FAULT_SENSOR` OR `validity∈{INVALID_*}` OR (meas jumps > Δ_jump in one tick) OR frozen meas with good current motion **TBD** secondary | Δ_jump = **TBD** (upper bound hint: ≫ 1.0 deg/tick software step — **DERIVED** step size, not a validated sensor threshold) | Sensor fault **confounds** residual; clears path to isolation of rudder hydro |
| P-HYDRO | Hydrodynamic effectiveness loss | `RUDDER_RESID_ANOMALY` latched AND P-TRACK false (meas tracks cmd) AND P-SENS false AND P-OPEN false AND current/BIT not stall AND confounder policy (current/Vc inhibit) satisfied | Residual params FIXED in CUSUM doc; hydro confirm windows = **TBD** | Needs cmd−meas agreement + anomaly; FAULT R-ID1 probe for confirmation |
| P-INCONC | Inconclusive | Any required signal stale/dropout OR conflicting predicates OR Vc-unestimated per FAULT H8 | — | Default safe output |

**Isolation decision (required, still NOT_IMPLEMENTED in production):**

```
RUDDER_ISOLATED := (P-TRACK ∨ P-STALL ∨ P-OPEN ∨ P-HYDRO) ∧ ¬P-SENS_conflict ∧ ¬P-INCONC
```

Exact boolean priority / mutex among P-TRACK vs P-HYDRO is **TO_BE_IDENTIFIED** by the next separability study; ICD forbids declaring isolation on residual alone.

Elevator optional mirrors of P-* use prefix `ELEV_` and do not authorize rudder isolation.

---

## 10. State machine and messages

### 10.1 States (actuator FDI service — logical)

| State | Meaning | Control authority change? |
|---|---|---|
| `TELEMETRY_ABSENT` | Rudder L1/L2/L3 not provisioned | None (isolation blocked) |
| `MONITOR_INIT` | Warmup / sync acquire | None |
| `MONITOR_OK` | Frames valid; no latch | None |
| `DETECT_ANOMALY` | `RUDDER_RESID_ANOMALY` (CUSUM) only | None (FAULT H1) |
| `ISOLATION_INCONCLUSIVE` | Anomaly or predicate conflict without unique class | None |
| `RUDDER_ISOLATED_*` | Unique class latched (`_TRACK|_STALL|_OPEN|_HYDRO|_SENSOR`) | **Forbidden in this gate** — message only; no accommodation |
| `FAIL_SILENT` | Integrity/stale storm; outputs inhibited | None |

Elevator: parallel optional states; absence ≠ fault.

### 10.2 Messages (logical names only)

| Message | Payload (min) | Producer → consumer |
|---|---|---|
| `ACT_TELEM_FRAME` | §4 fields for one surface | Actuator IO → logger / FDI |
| `RUDDER_RESID_ANOMALY` | CUSUM q, time | Detect scaffold → log / FDI |
| `ISOLATION_INCONCLUSIVE` | reason codes | FDI → log |
| `RUDDER_ISOLATED` | class enum, evidence IDs | FDI → log only until mission API exists |
| `MONITOR_RESET` / `ISOLATION_RESET` | authority token | Human / validated procedure → FDI |

No bus IDs, DBC, or PDU layouts (**not invented**).

---

## 11. Latch / reset authority / fail-silent

| Item | Policy | Provenance |
|---|---|---|
| Detect latch | Remains until explicit `MONITOR_RESET` | **FIXED** (FAULT §6) |
| Isolation latch | Remains until explicit `ISOLATION_RESET`; auto-clear on residual quiet **PROHIBITED** | **FIXED** (FAULT) |
| Reset authority | Human or validated procedure; APIs **NOT_IMPLEMENTED** | **FIXED** |
| Auto-recovery / auto-surface / accommodation | **PROHIBITED** this gate | **FIXED** |
| Fail-silent | On integrity fail, stale, or dropout of required rudder meas: do not assert `RUDDER_ISOLATED`; emit `FAIL_SILENT` / `ISOLATION_INCONCLUSIVE` | **ASSUMED** policy consistent with FAULT H2/H7 |
| Missing optional elevator telem | No elevator messages; rudder path unaffected | **ASSUMED** |

---

## 12. Cybersecurity / data-integrity (basics)

Logical requirements only (no crypto suite selection):

1. **Integrity:** Frames used for isolation SHALL carry a checksum or authenticated integrity field when transported off-board the actuator drive (**ASSUMED** need; algorithm **TO_BE_IDENTIFIED**).  
2. **Replay:** `timestamp` + `sequence` monotonicity checks mandatory; replay ⇒ `INVALID_INTEGRITY`.  
3. **Source separation:** Sim L5 truth channels SHALL NOT share names/topics with online inputs (R-SEP-1).  
4. **Write protection:** Online monitors are read-only w.r.t. actuator commands; ICD consumers SHALL NOT write `cmd_angle`.  
5. **Logging integrity:** Isolation evidence logs SHALL retain cmd, meas, validity, sequence, and predicate IDs for audit.

---

## 13. Acceptance tests (bench / SIL / HIL)

| ID | Level | Intent | Pass / fail (logical) |
|---|---|---|---|
| AT-B1 | Bench | CAL-ZERO / ENDSTOP / HYST / RATE / SIGN | All CAL-* PASS with recorded ε_* |
| AT-B2 | Bench | Stall BIT or current proxy vs locked-rotor | P-STALL asserts; no P-HYDRO |
| AT-B3 | Bench | Open drive / disable | P-OPEN asserts |
| AT-S1 | SIL | Emulator: healthy tracking | P-TRACK false; meas follows cmd within TBD |
| AT-S2 | SIL | Emulator: stuck meas ≠ cmd | P-TRACK true; residual may also trip — class TRACK not HYDRO |
| AT-S3 | SIL | Emulator: meas tracks cmd + η inject at plant | P-HYDRO candidate; P-TRACK false |
| AT-S4 | SIL | Emulator: sensor freeze/jump | P-SENS; isolation of HYDRO inhibited |
| AT-S5 | SIL | Dropout / stale injection | FAIL_SILENT; no `RUDDER_ISOLATED` |
| AT-S6 | SIL | Confounder: Vc / G_nom / IMU-DVL hard-fault per FAULT R-ID2 | Must **not** declare `RUDDER_ISOLATED` without actuator corroboration |
| AT-H1 | HIL | Replay AT-S* with real drive telemety schema mapped to §4 | Parity checklist §8.2 PASS |
| AT-H2 | HIL | Time sync skew > 0.025 s | STALE_PAIR; no isolation |

Numeric Pd/FA gates for isolation separability = **TBD** (next bounded gate). Detect-layer CUSUM gates remain as in FAULT/CUSUM docs and are **not** reopened here.

---

## 14. Mapping to FAULT requirements

| FAULT req | ICD coverage |
|---|---|
| R-AF1 | §4 `meas_angle` @ ≥ 40 Hz; §5 alignment |
| R-AF2 | §4 current/torque **or** health_bit |
| R-AF3 | §8 logging boundary cmd vs plant-input vs meas |
| R-ID1 | Probe within ±25 deg, ≤ 40 deg/s; compare r(G_nom,u,δr_meas) — procedure retained; not executed this task |
| R-ID2 | AT-S6 confounder rejection |
| R-ID3 | Severity η̂ deferred; needs meas; offline only |

---

## 15. Current production gap (frozen)

| Item | Status |
|---|---|
| `controller_law` consumes actuator feedback | **NO** — outputs commands only |
| `continuous_path_tracking` logs | Command-side `delta_r`/`delta_e` only |
| Plant input vs command distinction for η | Sim inject invisible to online detector (by design) |
| FDI / safe-mode APIs | **NOT_IMPLEMENTED** |

---

## 16. Next bounded gate

**Selected:** `isolated_telemetry_emulator_and_fault_class_separability_study`

Scope:

1. Offline emulator of §4 rudder frames (elevator optional stub).  
2. Inject separable classes: track error, stall/open, sensor fault, hydro η-loss.  
3. Measure class confusion vs residual-only baseline.  
4. **Still forbidden:** accommodation, safe-mode wiring, production edits.

**Not selected:** tangent-exit / safe-mode baseline (still blocked on isolation defensibility until separability PASS + R-ID*).

---

## Files

- `suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md` (this ICD)
- Append: `suite_results/PITCH_CONTROL_RESEARCH_LOG.md`
- Cross-ref append: `suite_results/STATE_SPACE_MODEL_AUDIT.md`
- Production unchanged; `CODEX_VERTICAL_PLAN.md` untouched.
