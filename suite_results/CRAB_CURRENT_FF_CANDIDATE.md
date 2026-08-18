# CRAB_CURRENT_FF_CANDIDATE_001 — Isolated crab-current yaw-ref feedforward

**Overall verdict: FAIL**

## Provenance

- Read-only: `guidance_law.m`, `run_combined_6dof_disturbance_baseline.m`, `run_current_observer_bias_latency.m`
- Prior: COMBINED_6DOF_DISTURBANCE_BASELINE FAIL first=`R10_curr:rudder_sat_full(6.06%>1.00%)`
- Driver: `run_crab_current_ff_candidate.m` (one invocation)
- Production plant/controller/guidance: **UNTOUCHED / FROZEN**
- Gain sweep: **NO**
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CRAB_CURRENT_FF_CANDIDATE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CRAB_CURRENT_FF_CANDIDATE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CRAB_CURRENT_FF_CANDIDATE.png`
- Did **not** touch `CODEX_VERTICAL_PLAN.md`

## Algebra (no double-count)

```
PROD:  yaw_raw = wrap(chi_f + 0.75*chi_los - k_beta*beta); beta=atan2(v,u)
PROD:  r_ff = U_h * kappa_f  (yaw-RATE curvature FF; unchanged)
CAND:  th=[tN,tE] path horiz unit tangent; Vhat_NE=Vhat(1:2); vw=Uref*th-Vhat_NE; dpsi_raw=wrap(atan2(vw_E,vw_N)-atan2(th_E,th_N)); dpsi=rate_limit(clamp(act*dpsi_raw,±8deg), 3deg/s); act=0.5*(1-cos(pi*min(t,5)/5))
COMPOSE: yaw_ref_ff = yaw_ref_prod + dpsi  (added ONCE)
```
- beta compensates BODY sideslip vs WATER velocity; dpsi compensates WATER-track vs PATH tangent from estimated CURRENT; r_ff is rate FF from curvature — not a heading bias. Do NOT fold Vhat into beta or replace LOS; add dpsi once only.

## Setup

- U=1.5 m/s; Vc=[0.00, 0.15, 0.00] NED; routes X / XZ / R10
- Observer wo=0.50; declared noise/bias/latency; seed_obs=42; seed_plant=0
- dpsi clamp ±8 deg, rate 3 deg/s, half-cosine act T=5 s
- Act rate limit plant: 40 deg/s elev/rudder

## Before → after (CURRENT baseline → crab FF) @ U=1.5

| Route | thMAE | gMAE | yawMAE | CTE | deSat% | drSatF% | chat | drRateU | FEAS | first |
|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|---|
| X | 0.0247→0.0245 | 0.3404→0.3452 | 0.1036→0.1816 | 0.256→0.390 | 0.00→0.00 | 2.64→2.92 | 0.2056→0.1979 | 0.379→0.610 | YES | none |
| XZ | 0.1431→0.1365 | 0.4254→0.4275 | 0.0784→0.1519 | 0.352→0.451 | 0.00→0.00 | 2.39→2.50 | 0.2078→0.2172 | 0.299→0.567 | YES | none |
| R10 | 0.2046→0.2026 | 0.6008→0.6015 | 0.4046→0.3922 | 0.238→0.282 | 0.00→0.00 | 6.06→9.00 | 0.1633→0.1665 | 0.943→0.938 | NO | rudder_sat_full(9.00%>1.00%) |

## R10 sat / smoothness improvement

| Metric | Baseline | Candidate | Improve |
|---|---:|---:|---:|
| rudder full-sat % | 6.06 | 9.00 | -48.6% |
| smooth proxy (hypot rate,chat) | 0.9572 | 0.9522 | 0.5% |
| pass >=10% | — | — | NO |

## Regression vs CURRENT baseline (<=2%)

| Route | PASS | First |
|---|:---:|---|
| X | NO | thP95(0.06639>0.06492=+2%) |
| XZ | NO | gP95(0.8732>0.8648=+2%) |
| R10 | NO | CTE(0.2818>0.2428=+2%) |

## Observer (in-loop causal Vhat; declared harness gates)

| Route | bias||mean|| | RMSE_ss | p95_ss | final||err|| | hits | PASS |
|---|---:|---:|---:|---:|---:|:---:|
| X | 8.9481e-03 | 9.9518e-03 | 1.3529e-02 | 1.0927e-02 | 0 | YES |
| XZ | 8.4004e-03 | 9.8945e-03 | 1.4359e-02 | 8.9720e-03 | 0 | YES |
| R10 | 1.1316e-02 | 1.7261e-02 | 2.6735e-02 | 1.4462e-02 | 0 | YES |

## Traces saved

- Per route in `.mat`: `traces.dpsi`, `traces.dpsi_raw`, `traces.dpsi_act`,
  `traces.Vhat`, `traces.delta_r`, `traces.th`, `traces.psi_ref_prod`, `traces.psi_ref`

## PASS gates

| Gate | Result |
|---|---|
| production_untouched | PASS |
| no_gain_sweep | PASS |
| states_bounded | PASS |
| route_hard_all | FAIL |
| r10_rudder_sat_le_1pct | FAIL |
| r10_sat_or_smooth_improve_ge_10pct | FAIL |
| reg_le_2pct_all | FAIL |
| observer_prior | PASS |
| bounded_no_chatter | FAIL |

**Overall: FAIL** | first_limit=`X_reg:thP95(0.06639>0.06492=+2%)`

## Next bounded roadmap gate

- **`guidance_mission_baseline`** (guidance_mission)
- REJECT crab-current FF candidate (production untouched). First fail=`X_reg:thP95(0.06639>0.06492=+2%)`. Advance to guidance/mission baseline.
- Do **not** promote to production. CODEX_VERTICAL_PLAN untouched.
