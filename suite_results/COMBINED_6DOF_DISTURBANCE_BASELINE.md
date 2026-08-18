# COMBINED_6DOF_DISTURBANCE_BASELINE_001 — Combined nonlinear 6DOF disturbance baseline

**Overall verdict: FAIL**

**Label: PLANT-DISTURBANCE + ESTIMATOR (offline observer; NOT sensor-in-loop)**

## Provenance

- Read-only: `run_bounded_current_hook.m`, `run_current_observer_bias_latency.m`, `suite_results/SPEED_ENVELOPE_AUDIT.md`
- Priors: BOUNDED_CURRENT_HOOK=PASS; CURRENT_OBSERVER_BIAS_LATENCY=PASS
- Driver: `run_combined_6dof_disturbance_baseline.m` (one invocation)
- Production plant/controller/guidance: **UNTOUCHED / FROZEN**
- Observer fed to control: **NO** (offline only; NOT sensor-in-loop)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\COMBINED_6DOF_DISTURBANCE_BASELINE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\COMBINED_6DOF_DISTURBANCE_BASELINE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\COMBINED_6DOF_DISTURBANCE_BASELINE.png`
- Did **not** touch `CODEX_VERTICAL_PLAN.md`

## Setup

- U=1.5 m/s; Vc=[0.00, 0.15, 0.00] NED; routes X / XZ / R10
- Two repeats; plant seed=0; observer seed=42; identity required
- Hard gates = SPEED_ENVELOPE absolutes; <=2% regression vs SPEED_ENVELOPE U=1.5 on no-current
- Observer gates = prior bias/latency (bias<=0.030 RMSE<=0.035 p95<=0.070 final<=0.050 no hits)
- Act rate limit: 40 deg/s elev/rudder

## Identity

- deterministic identity (bit-match after clear persistent/RNG) — max|Δstate|=0.000e+00 max|Δobs|=0.000e+00

## Before → after (no-current → Vc cross) @ U=1.5

| Route | thMAE | gMAE | yawMAE | CTE | e_z_rms | uMAE | deSat% | drSatF% | chat | FEAS_c | first_c |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|---|
| X | 0.0110→0.0247 | 0.3311→0.3404 | 0.0000→0.1036 | 0.247→0.256 | 0.2426→0.2428 | 0.3176→0.3154 | 0.00→0.00 | 0.00→2.64 | 0.1530→0.2056 | YES | none |
| XZ | 0.1214→0.1431 | 0.4182→0.4254 | 0.0000→0.0784 | 0.372→0.352 | 0.3521→0.3272 | 0.2550→0.2532 | 0.00→0.00 | 0.00→2.39 | 0.1955→0.2078 | YES | none |
| R10 | 0.0411→0.2046 | 0.6584→0.6008 | 0.1740→0.4046 | 0.269→0.238 | 0.2240→0.2064 | 0.3494→0.3546 | 0.00→0.00 | 0.67→6.06 | 0.1501→0.1633 | NO | rudder_sat_full(6.06%>1.00%) |

## No-current vs SPEED_ENVELOPE U=1.5 (<=2% regression)

| Route | PASS | First |
|---|:---:|---|
| X | YES | none |
| XZ | YES | none |
| R10 | YES | none |

## Current-case hard gates (SPEED_ENVELOPE absolutes)

| Route | FEAS | First limit | thMAE | gMAE | yawMAE | CTE | ez_rms | deSat | drSatF | deRateU | chat | bound |
|---|:---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| X | YES | none | 0.0247 | 0.3404 | 0.1036 | 0.256 | 0.2428 | 0.00 | 2.64 | 0.029 | 0.2056 | YES |
| XZ | YES | none | 0.1431 | 0.4254 | 0.0784 | 0.352 | 0.3272 | 0.00 | 2.39 | 0.019 | 0.2078 | YES |
| R10 | NO | rudder_sat_full(6.06%>1.00%) | 0.2046 | 0.6008 | 0.4046 | 0.238 | 0.2064 | 0.00 | 6.06 | 0.010 | 0.1633 | YES |

## Offline observer (declared bias+latency harness)

| Route | bias||mean|| | RMSE_ss | p95_ss | final||err|| | hits | PASS |
|---|---:|---:|---:|---:|---:|:---:|
| X | 8.9636e-03 | 9.9530e-03 | 1.3499e-02 | 1.0866e-02 | 0 | YES |
| XZ | 7.8878e-03 | 8.6337e-03 | 1.1479e-02 | 9.3543e-03 | 0 | YES |
| R10 | 1.2496e-02 | 1.7361e-02 | 2.6734e-02 | 1.8591e-02 | 0 | YES |

## PASS gates

| Gate | Result |
|---|---|
| repeats_identical | PASS |
| states_bounded | PASS |
| route_actuator_hard_current | FAIL |
| no_current_hard | PASS |
| no_current_reg_le_2pct | PASS |
| observer_prior | PASS |
| offline_not_in_loop | PASS |
| production_untouched | PASS |

**Overall: FAIL** | first_limit=`R10_curr:rudder_sat_full(6.06%>1.00%)`

## Next bounded roadmap gate

- **`isolated_current_compensation_candidate`** (crab_current_feedforward)
- FAIL first=`R10_curr:rudder_sat_full(6.06%>1.00%)`. Plant tracking/actuator limit under Vc cross-current → next: ONE isolated crab/current feedforward compensation candidate (production frozen; observer stays offline).
- Do **not** feed observer to control; do **not** promote to production.
- CODEX_VERTICAL_PLAN untouched.
