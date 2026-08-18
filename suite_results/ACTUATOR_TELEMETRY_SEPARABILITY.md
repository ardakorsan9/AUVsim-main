# ACTUATOR_TELEMETRY_SEPARABILITY

**TASK_ID:** ACTUATOR_TELEMETRY_SEPARABILITY_001  
**Date:** 2026-08-06 08:27:40  
**Logical SIL verdict:** **PASS**  
**Hardware / deployment:** **NOT_CERTIFIED** (regardless of SIL)  

Isolated causal SIL telemetry emulator + fault-class separability. No production edit. No new nonlinear run. L5 truth forbidden to classifiers.

## Sources (read-only, ≤3)

1. `suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md`
2. `suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.mat`
3. `suite_results/RUDDER_CUSUM_DETECTOR.mat`

## Seed split (published, disjoint)

| Set | Seeds | N | Role |
|---|---|---:|---|
| TRAIN | 6101:6120 | 20 | identify TBD predicate thresholds |
| VAL | 7101:7140 | 40 | score confusion / P/R / safety after freeze |

- Policy: `fixed published TRAIN=6101:6120 VAL=7101:7140 (twister); disjoint from CUSUM 2101/3101`
- Disjoint train/val: **YES**
- Disjoint from CUSUM 2101/3101: **YES**

## ASSUMED SIL models (NOT hardware)

| Item | Value | Label |
|---|---|---|
| Position lag τ | 0.050 s (1st-order) | ASSUMED |
| Meas noise σ | 0.050 deg | ASSUMED |
| Current I0 / k_rate / k_hold | 1.20 A / 8.0 / 2.5 | ASSUMED |
| Current noise σ | 0.050 A | ASSUMED |
| Supply / temp stubs | 24.0 V / 35.0 °C | ASSUMED |
| Hydro residual level | 0.350 (synthetic r_B2) | ASSUMED |
| Sensor jump inject | 8.0 deg | ASSUMED |
| Stale hold | 0.200 s (> T_stale) | ASSUMED |

These are **logical SIL defaults** for separability; they are **not** vendor/hardware ID.

## FIXED anchors

| Item | Value | Provenance |
|---|---|---|
| dt | 0.025 s | FIXED coverage/ICD |
| f_ctrl | 40 Hz | DERIVED |
| δr_max | ±25 deg | FIXED ICD |
| rate limit | 40 deg/s | FIXED |
| CUSUM κ / h / G_nom | 0.066156 / 11.066456 / 0.851915 | FIXED CUSUM mat |
| T_stale / N_miss | 0.075 s / 3 | ASSUMED ICD §5 |

## Frozen predicate thresholds (TRAIN→freeze→VAL)

| ID | Thresholds | Provenance |
|---|---|---|
| P-TRACK | e_track=4.6490 deg, N_track=8 | TBD→TRAIN_DERIVED / ASSUMED N |
| P-STALL | I_stall=6.627 A, N_stall=8, ω_stall_max=2.0 deg/s, ω_cmd_min=5.0 deg/s | TBD→TRAIN / ASSUMED |
| P-OPEN | I_open_max=0.250 A, N_open=8, cmd_min=2.0 deg | TBD→TRAIN / ASSUMED |
| P-SENS | d_jump=3.777 deg, N_sens_freeze=8, BIT FAULT_SENSOR | TBD→TRAIN / ASSUMED |
| P-HYDRO | CUSUM q>h latched + meas tracks cmd (NOT P-TRACK/SENS/OPEN/STALL) + N_hydro=4 | CUSUM FIXED + ASSUMED confirm |
| P-INCONC | STALE/DROPOUT or conflicting predicates | ICD fail-silent |

Frozen at 2026-08-06 08:27:40 before VAL open: **YES**

## Layers / leakage

| Layer | Online classifier? |
|---|---|
| L0-L4 | YES |
| L5 sim truth | **NO** |

### No-leakage checks

| Check | Result |
|---|:---:|
| L5 fed to classifier | NO |
| eta_true in predicates | NO |
| delta_r_app in predicates | NO |
| Labels in online update | NO |
| Train/val seeds disjoint | YES |
| Thresholds frozen before VAL | YES |
| New NL run | NO |
| Production edited | NO |

Classifier consumes only L0-L4 frames + frozen CUSUM score from ASSUMED residual proxy rebuilt from L0 cmd/u and class-conditional residual model; L5 (eta_true, stuck_true, open_true, sensor_true, hydro_true, truth_class) stored separately and used only in post-hoc scoring. TRAIN identified TBD thr; VAL scored after freeze. Coverage/CUSUM mats used for FIXED anchors + L0 cmd replay only.

## VAL confusion matrix (rows=true, cols=pred)

|  | HEALTHY | TRACK | STALL | OPEN | SENS | HYDRO | STALE | CONFLICT |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| HEALTHY | 40 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| TRACK | 0 | 40 | 0 | 0 | 0 | 0 | 0 | 0 |
| STALL | 0 | 0 | 40 | 0 | 0 | 0 | 0 | 0 |
| OPEN | 0 | 0 | 0 | 40 | 0 | 0 | 0 | 0 |
| SENS | 0 | 0 | 0 | 0 | 40 | 0 | 0 | 0 |
| HYDRO | 0 | 0 | 0 | 0 | 0 | 40 | 0 | 0 |
| STALE | 0 | 0 | 0 | 0 | 0 | 0 | 40 | 0 |
| CONFLICT | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 40 |

## Per-class precision / recall (VAL)

| Class | Precision | Recall | Isolable gate |
|---|---:|---:|:---:|
| HEALTHY | 100.00% | 100.00% | — |
| TRACK | 100.00% | 100.00% | PASS |
| STALL | 100.00% | 100.00% | PASS |
| OPEN | 100.00% | 100.00% | PASS |
| SENS | 100.00% | 100.00% | PASS |
| HYDRO | 100.00% | 100.00% | PASS |
| STALE | 100.00% | 100.00% | — |
| CONFLICT | 100.00% | 100.00% | — |

## Safety / delay

| Metric | Value | Gate |
|---|---:|---|
| Healthy false isolation rate | 0.0000% | ≤1% → PASS |
| STALE/DROPOUT asserting RUDDER_ISOLATED | 0 | must be 0 → PASS |
| CONFLICT asserting RUDDER_ISOLATED | 0 | must be 0 → PASS |

### Detection / isolation delay (VAL, isolable classes, seconds after t_fault)

| Class | N detect | med | p95 |
|---|---:|---:|---:|
| TRACK | 40 | 1.375 | 1.375 |
| STALL | 40 | 0.175 | 0.175 |
| OPEN | 40 | 0.175 | 0.175 |
| SENS | 40 | 0.025 | 0.025 |
| HYDRO | 40 | 1.050 | 1.050 |

## Gate summary

| Gate | Result |
|---|:---:|
| Isolable class P/R ≥95% | PASS |
| Healthy false isolation ≤1% | PASS |
| STALE/CONFLICT never RUDDER_ISOLATED | PASS |
| **Logical SIL** | **PASS** |
| Hardware/deployment | NOT_CERTIFIED |

## Decision rule (causal)

```
RUDDER_ISOLATED := (P-TRACK ∨ P-STALL ∨ P-OPEN ∨ P-HYDRO ∨ P-SENS)
                 ∧ ¬P-INCONC
Priority on conflict among isolable predicates → P-INCONC (fail-silent)
STALE/DROPOUT → P-INCONC; never RUDDER_ISOLATED
Latch until explicit ISOLATION_RESET (per-episode reset in SIL)
```

## Artifacts

- `suite_results/ACTUATOR_TELEMETRY_SEPARABILITY.md`
- `suite_results/ACTUATOR_TELEMETRY_SEPARABILITY.mat`
- `suite_results/ACTUATOR_TELEMETRY_SEPARABILITY.png`
- Driver: `run_actuator_telemetry_separability.m`

## Next

bench/HIL identification and acceptance-test plan (AT-B*/AT-H*); revise only if hardware disagrees — do not retune controller.

CODEX_VERTICAL_PLAN untouched. Production frozen.
