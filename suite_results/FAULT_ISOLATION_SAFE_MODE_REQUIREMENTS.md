# FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS

**TASK_ID:** FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS_001  
**Date:** 2026-08-06 08:07:40  
**Audit type:** Requirements only (no MATLAB run; production frozen)  
**Verdict:** Software-only rudder isolation is **NOT supportable**. Isolation/trigger authority for safe-mode is **NOT defensible** with command+IMU+DVL CUSUM alone.

## Sources (read-only, ≤3)

1. `suite_results/RUDDER_CUSUM_DETECTOR.md` — Coverage **PASS** (κ=0.066156, h=11.066456; all 9 VAL cells Pd=100%, FA_agg=0%)
2. `suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.md` — Detectability B2 **FAIL**; fixed-horizon survivability all-9 **PASS**
3. `suite_results/GUIDANCE_MISSION_BASELINE.md` — Mission execution **NO**; FDI/mission-manager/safe-mode APIs **NOT_IMPLEMENTED**

Cross-ref (not a fourth source for claims; plant/sensor interface context only): `suite_results/STATE_SPACE_MODEL_AUDIT.md` — plant inputs are commanded `delta_r, delta_e, thrust`; production feedback is plant-truth BODY/NED; sensor noise/delay/IMU–DVL plumbing and actuator position/current/health feedback are **NOT_IMPLEMENTED** / ASSUMED.

Production `controller_law` / `guidance_law` / plant **unchanged**. `CODEX_VERTICAL_PLAN.md` untouched.

---

## 1. Layer definitions (do not conflate)

| Layer | Meaning | Current status |
|---|---|---|
| **Detection** | Declare anomalous yaw-authority residual vs command×u² model | **PRESENT (offline scaffold)** — frozen B2 residual + one-sided CUSUM; not wired to mission |
| **Isolation** | Attribute anomaly to a unique fault class (rudder vs sensor vs current vs hydro vs other actuator) | **NOT_IMPLEMENTED** — residual is non-specific |
| **Severity estimation** | Estimate effectiveness η, stuck angle, or loss fraction with confidence bounds | **NOT_IMPLEMENTED** — η used only in post-hoc scoring; detector forbids δr_app / η |
| **Accommodation** | Change control/guidance authority (gain schedule, disable channel, alternate actuator) under isolated fault | **NOT_IMPLEMENTED** |
| **Mission abort / safe-mode** | Mission-manager authority to exit tracking, hold tangent, surface, or stop under latch | **NOT_IMPLEMENTED** |

Detection ≠ isolation. A latched CUSUM alarm is evidence of **model inconsistency**, not proof of **rudder fault**.

---

## 2. What command+IMU+DVL CUSUM can and cannot prove

### Demonstrated envelope (no extrapolation)

| Axis | Demonstrated only | Explicitly not certified |
|---|---|---|
| Geometry | R=10 m helix, pitch_h=2, turns=2, mid-turn inject at s≈31.49 m | Other radii, composite mission LEVEL/CLIMB/TURN/EXIT, X/XZ |
| Speed U | {1.50, 1.75, 2.00} m/s ⊂ SPEED_ENVELOPE R10 [1.50, 2.00] | U&lt;1.50, U&gt;2.00 |
| Effectiveness η | {0.75, 0.50, 0.25} (loss 25/50/75%); multiplicative δr_app=η·δr_cmd at plant-input | Stuck, jam, bias, rate-limit, asymmetric, elevator/thrust faults |
| Sensors (CUSUM VAL) | Declared DVL σ=0.010 m/s @5 Hz ZOH, bias=+0.005, lat=200 ms; IMU ASSUMED σ=0.20 deg/s @100 Hz, bias=+0.05, lat=50 ms | Unmodeled sensor outages, hard faults, misalignment, lever-arm |
| Current | **None in CUSUM train/val** | Any Vc; CRAB_CURRENT_FF separately **REJECTED** (R10 rudder sat) |
| Survivability | Fixed-horizon T=45 s complete ∩ bounded ∩ no-reset (coverage all-9) | Mission-goal success, safe-mode entry, abort, surface |

CUSUM coverage (VAL noisy replay): every cell Pd=100% (40/40), p95 delay ≤ 1.338 s ≤ 3 s; unseen-nominal FA_agg=0% (≤1%). B2 alone still **MISS** at U∈{1.50,1.75}/η=0.75 — CUSUM closes mild-fault detectability **within this envelope only**.

### Can prove (within envelope)

- Residual `r_B2 = max(0, 1 − r / (max(u,u_floor)² · δr_cmd) / G_nom)` persistently exceeds Page allowance under the gated CUSUM (κ,h frozen on TRAIN pre-fault + declared corruption).
- Under the **declared** multiplicative rudder-effectiveness injection + declared sensor corruption, detection delay and FA meet the stated gates.
- Detector does **not** use δr_app, η, or fault labels online (no-leakage checks PASS).

### Cannot prove

- That the rudder is the faulty component (**isolation**).
- Numeric severity η or remaining yaw authority (**severity estimation**).
- That the vehicle is unsafe to continue, or that any safe-mode/abort is required (**mission authority**).
- Behavior under current, hydro mismatch, other actuators, untested η/U/path, or sensor hard-faults.
- Hardware IMU/DVL fidelity (ASSUMED / synthetic corruption only).

---

## 3. Confounder assessment

| Confounder | Effect on B2/CUSUM | Isolation impact |
|---|---|---|
| **Ocean current Vc** | Changes water-relative flow and yaw response vs G_nom command×u²; can inflate or mask r_B2 | **Confounds** — not in CUSUM H0; crab/current compensation rejected on R10 sat; cannot attribute alarm to rudder |
| **Hydrodynamic mismatch** | Any Yuudr/Nuudr or G_nom error looks like frac-loss | **Confounds** — identical residual signature to η-loss |
| **Sensor faults (IMU r, DVL u)** | Corrupt numerator/denominator of r_B2; declared soft corruption FA-controlled, but hard bias/outage untested as alternate hypothesis | **Confounds** — same channel as “rudder loss”; no independent sensor FDI |
| **Actuator faults (rudder)** | Demonstrated class: multiplicative effectiveness only | Detectable as anomaly **if** other confounders absent; **not isolable** from above without δr feedback |
| **Other actuators (δe, thrust)** | Can couple into r/u; no dedicated monitors | **Confounds / unmonitored** |

**Conclusion:** Command+IMU+DVL residual supports **anomaly detection**, not **rudder isolation**.

---

## 4. Unavailable feedback and absent APIs (NOT_IMPLEMENTED)

### Actuator / health feedback (unavailable)

| Signal | Status |
|---|---|
| Rudder position feedback δr_meas / δr_app | **NOT_IMPLEMENTED** (detector forbids applied rudder; plant-input η inject is sim-only) |
| Elevator position feedback δe_meas | **NOT_IMPLEMENTED** |
| Actuator motor current / torque | **NOT_IMPLEMENTED** |
| Actuator health / BIT / fault discrete | **NOT_IMPLEMENTED** |
| Effectiveness η online estimate | **NOT_IMPLEMENTED** |

Plant/control interface per STATE_SPACE_MODEL_AUDIT: commanded `delta_r, delta_e, thrust` only; production sensing is ideal plant-truth (sensor noise/delay plumbing **NOT_IMPLEMENTED** for production).

### FDI / mission / safe-mode APIs (from GUIDANCE_MISSION_BASELINE)

| Function | Status |
|---|---|
| `mission_manager` | **NOT_IMPLEMENTED** |
| `fault_detection` (production-wired) | **NOT_IMPLEMENTED** (offline CUSUM scaffold only) |
| `fault_isolation` | **NOT_IMPLEMENTED** |
| `safe_mode` | **NOT_IMPLEMENTED** |
| `abort_recover` | **NOT_IMPLEMENTED** |
| `sensor_outage_handler` | **NOT_IMPLEMENTED** |
| `actuator_fail_handler` | **NOT_IMPLEMENTED** |
| Mission complete / success-criteria API | **NOT_IMPLEMENTED** |
| Mid-mission reset / bumpless mission handoff | **NOT_IMPLEMENTED** |
| Mission watchdog / stall / acquisition timeout | **NOT_IMPLEMENTED** |
| Online repath / avoid / dynamic replan | **NOT_IMPLEMENTED** |
| Segment blender / clothoid shaper / mode switch | **NOT_IMPLEMENTED** |

---

## 5. Hazard / requirements table

Scope of triggers: R10 helix @ U∈{1.50,1.75,2.00} only. Responses below are **requirements**, not implemented behavior. **Automatic recovery and automatic surfacing are PROHIBITED** until separately validated.

| ID | Hazard / need | Trigger | Evidence | Confidence / persistence | Required response | Authority owner | Verification method | Fail-safe if unmet |
|---|---|---|---|---|---|---|---|---|
| H1 | Undetected yaw-authority loss | Mid-turn multiplicative η∈{0.25,0.50,0.75} at demonstrated U | Gated r_B2 CUSUM q&gt;h | κ=0.066156, h=11.066456; warmup t&gt;5 s; \|δr\|_gate≥1°; latch until explicit reset; VAL Pd=100%, p95≤1.338 s, FA_agg=0% | **Detect-only alarm** `RUDDER_RESID_ANOMALY`; no control change | Offline monitor owner (not mission_manager — absent) | Replay VAL seed set 3101:3140 on frozen coverage logs; FA≤1%, Pd≥95%, p95≤3 s | Continue open-loop cascade; **do not** assert rudder fault |
| H2 | False attribution of anomaly to rudder | Any H1 alarm without actuator corroboration | Command+IMU+DVL residual alone | Confidence = **anomaly only**; isolation confidence = **0** until §7 feedback | Log `ISOLATION_INCONCLUSIVE`; **forbid** accommodation/abort on residual alone | Requirements / safety (human) | Confounder injection matrix (current, G_nom±, sensor hard-fault) must not auto-map to rudder_isolated | Treat as H1 detect-only |
| H3 | Mild loss missed by B2 | U∈{1.50,1.75}, η=0.75 | CUSUM (not thr_B2 alone) | Same as H1; B2 MISS documented | Prefer CUSUM latch over B2 for detect gate | Monitor owner | Mag×speed matrix all-9 CUSUM cells | Do not retune B2/G_nom |
| H4 | Continue after anomaly without mission policy | H1 latch | Alarm + no mission API | Persistence: latched | Hold detect flag; **no** auto safe-mode | **mission_manager NOT_IMPLEMENTED** | N/A until API exists | Operator/sim stop only (ode45 catch is sim abort, not vehicle safe-mode) |
| H5 | Premature safe-mode / surface | Any residual alarm | Insufficient isolation | N/A | **PROHIBIT** auto surface, auto recover, auto replan | Safety policy | Separate validation campaign required before enable | Remain in current cascade; latch alarm only |
| H6 | Mission-goal abort without criteria | Composite mission FAIL (baseline LEVEL gamma_MAE) | Offline metrics only | Mission complete flag **NOT_IMPLEMENTED** | Do not couple CUSUM to mission abort | **abort_recover NOT_IMPLEMENTED** | GUIDANCE_MISSION_BASELINE segment gates offline | Fixed-horizon stop only |
| H7 | Actuator fault without position corroboration | Suspected η-loss | Need \|δr_cmd−δr_meas\| and/or current/BIT | Isolation requires independent actuator evidence | Block `rudder_isolated` until §7 | Actuator telemetry owner | Closed-loop ID with commanded probe + measured δr | Software-only isolation **REJECTED** |
| H8 | Current-induced residual | Vc present (untested in CUSUM) | r_B2 rise without δr mismatch | Unknown FA under Vc | Do not use H1 as rudder proof under current | Same as H2 | Current stress **out of envelope** — defer | Detect-only or inhibit monitor when Vc unestimated |

---

## 6. Measurable entry / exit / reset / latch criteria

### Detect layer (CUSUM) — entry / latch (demonstrated)

- **Entry (accumulate):** t &gt; 5.0 s AND \|δr_cmd\| ≥ 1.0° AND u ≥ u_floor (0.30 m/s used in residual).
- **Alarm entry:** q_k &gt; h with κ=0.066156, h=11.066456 on frozen G_nom=0.851915.
- **Latch:** alarm remains set until **explicit reset** (CUSUM doc: latch until reset). Ungated samples reset q→0 but **do not** clear a latched alarm without reset API.
- **Exit from accumulating:** gate open fails → q:=0 (score reset, not alarm clear).

### Isolation / safe-mode / abort — required criteria (NOT_IMPLEMENTED; must be specified before enable)

| Mode | Entry (all required) | Exit / reset | Latch policy |
|---|---|---|---|
| `RUDDER_RESID_ANOMALY` (detect) | CUSUM alarm per above within demonstrated U×η×R10 | Manual/explicit `monitor_reset` only; **no auto-clear on silence** | Latch |
| `RUDDER_ISOLATED` | Detect latch **AND** actuator corroboration (§7) **AND** sensor-FDI clear **AND** current/inhibit policy satisfied | Explicit `isolation_reset` after human or validated procedure; **auto-recovery PROHIBITED** | Latch |
| `SAFE_MODE_TANGENT_EXIT` | `RUDDER_ISOLATED` (or higher-authority abort) **AND** mission_manager present **AND** validated entry suite PASS | Explicit exit command only; **no auto-recover to path track**; **no auto-surface** until separately validated | Latch until commanded |
| `MISSION_ABORT` | Documented abort criteria API (absent) + authority owner | Explicit only | Latch |

**Prohibitions (until separate validation artifacts exist):**

1. Automatic clearing of detect/isolation latches when residual returns to nominal.  
2. Automatic return to path tracking after safe-mode.  
3. Automatic surfacing, ballast blow, or ascent as default fault response.  
4. Coupling CUSUM alarm → accommodation or abort without isolation.

---

## 7. Software-only isolation decision

**Decision: NOT supportable.**

Reason: H1 evidence is a scalar residual consistent with rudder loss, current, hydro mismatch, IMU/DVL fault, and unmodeled coupling. Coverage PASS proves **detectability of injected η under declared noise**, not **unique diagnosis**.

### Minimum actuator-feedback and identification requirements (gate before isolation claims)

| Req | Minimum | Purpose |
|---|---|---|
| R-AF1 | Rudder position (or equivalent applied angle) δr_meas at ≥ control rate, time-aligned with δr_cmd | Corroborate cmd−meas mismatch vs residual-only |
| R-AF2 | Rudder health discrete and/or motor current (or torque proxy) with documented stall/open thresholds | Distinguish servo fault from hydro/sensor |
| R-AF3 | Explicit plant-input vs command logging boundary in sim **and** hardware ICD | Make η / stuck inject observable and auditable |
| R-ID1 | Identification protocol: commanded small rudder probe (within δr_max=25°, rate 40°/s envelope) comparing predicted r(G_nom,u,δr_meas) vs measured r under **known** U∈{1.50,1.75,2.00} on R10 | Separate effectiveness from sensor bias |
| R-ID2 | Confounder rejection tests: nonzero Vc case, G_nom perturbation, IMU/DVL hard-fault — isolation must not declare `RUDDER_ISOLATED` | Prove specificity |
| R-ID3 | Severity estimator offline first: η̂ from δr_meas/δr_cmd and/or r-response; report bias/variance on η∈{0.25,0.50,0.75} only (no extrapolation) | Enable later accommodation requirements |

Until R-AF1–R-AF2 and R-ID1–R-ID2 exist and PASS, any `rudder_isolated` or safe-mode trigger from CUSUM alone is **non-compliant** with this audit.

---

## 8. Authority ownership (as-required)

| Decision | Owner (required) | Present? |
|---|---|---|
| Raise residual anomaly | Monitor (CUSUM scaffold) | Offline only |
| Declare rudder isolated | FDI / isolation service | **NOT_IMPLEMENTED** |
| Enter safe-mode / abort | `mission_manager` | **NOT_IMPLEMENTED** |
| Reset latches | Explicit reset API + human or validated procedure | **NOT_IMPLEMENTED** |
| Change δr/δe/thrust authority | Accommodation / actuator_fail_handler | **NOT_IMPLEMENTED** |
| Surface / recover | `abort_recover` after separate validation | **NOT_IMPLEMENTED**; auto-surface **PROHIBITED** |

---

## 9. Next bounded gate

**Selected:** `actuator_feedback_telemetry_interface_specification`

**Not selected:** `isolated_tangent_exit_safe_mode_baseline` — blocked because isolation/trigger authority is **not defensible** without actuator corroboration and mission_manager APIs.

Scope of next gate (spec only; no production edit; no safe-mode enable):

1. ICD for δr_meas, optional δe_meas, health/current, time sync vs δr_cmd.  
2. Sim boundary: expose applied actuator independently from command (today η inject is invisible to detector by design).  
3. Mapping of signals → isolation predicates (cmd−meas, BIT) separate from CUSUM detect.  
4. Explicit non-goals: no accommodation, no tangent-exit, no surface, no production wiring.

---

## Files

- `suite_results/FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS.md` (this audit)
- Append: `suite_results/PITCH_CONTROL_RESEARCH_LOG.md`
- Cross-ref append: `suite_results/STATE_SPACE_MODEL_AUDIT.md`
- Production unchanged; `CODEX_VERTICAL_PLAN.md` untouched.
