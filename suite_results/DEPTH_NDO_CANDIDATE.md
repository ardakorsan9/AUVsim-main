# DEPTH_NDO_CANDIDATE_001 — Depth-rate NDO candidate @ U=1.50

**Overall verdict: FAIL**

## Provenance

- Read-only: `run_depth_to_gamma_candidate.m`, `DEPTH_OUTER_BASELINE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m`
- Prior: DEPTH_TO_GAMMA_CANDIDATE_001 REJECTED (agg MAE −36% but transient/attitude gates FAIL); production frozen
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_ndo.m` (production `guidance_law.m` / `controller_law.m` untouched)
- Baseline: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.mat` / `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.md` (DEPTH_OUTER_BASELINE_001 identical paths/IC/windows)
- Driver: `run_depth_ndo_candidate.m` (one invocation; no production edit; no sweep)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_NDO_CANDIDATE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_NDO_CANDIDATE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_NDO_CANDIDATE.png`
- Seed: 0 | Kp_roll frozen=0.605072 | Kp_x=25 | thrust_trim=13.4 N
- CODEX_VERTICAL_PLAN.md: untouched

## Frames / units / signs

| Item | Definition |
|------|------------|
| Inertial | NED (North-East-Down): x North, y East, z Down |
| Body | BODY: x forward, y starboard, z down; rates p,q,r about BODY; Euler ZYX (psi,theta,phi) with ang_dot = JJ*[p;q;r] |
| z / depth positive down? | **YES** — depth ≡ z_NED [m] |
| e | e = z − z_ref = cte(3) = z_veh−z_path (filtered z_e_f) [m] |
| Kinematics | ė ≈ b0·gamma_corr + d, b0=U·Gdc [m/(s·rad)] |
| d_meas | (zdot − zdot_ref) − b0·gamma_corr_prev [m/s] |
| theta_phys | theta_phys = -theta  [rad]; dive-positive matches atan2(dz,dx) with z down |
| Cascade | frozen theta/q + climb FF (`k_gamma_climb=0.1320695001`) |

## Candidate equations / gains / bounds

```
e = z - z_ref  (NED down; = cte(3) = z_veh-z_path, filtered z_e_f)
ė ≈ b0*gamma_corr + d,  b0 = U*Gdc = 1.5*0.9404 = 1.4106 m/(s·rad)
d_meas = (zdot - zdot_ref) - b0*gamma_corr_prev   [m/s]
dhat_dot = wo*(d_meas - dhat),  wo=0.30 rad/s; |dhat|≤0.50 m/s
gamma_corr_raw = (-kz*e - dhat)/b0,  kz=0.08 1/s
gamma_corr = rate_limit(sat(gamma_corr_raw, ±9deg), 2deg/s)
bumpless: dhat=0, gamma_corr=0; soft reset if |e|>8 m
filter: z_e_f=0.93/0.07 cte(3); zd_e_f & d_meas LPF 0.85/0.15
pitch_raw = pitch_geom + gamma_corr  (thru frozen theta/q + climb FF)
```

| Symbol | Value | Units |
|--------|------:|-------|
| U | 1.5000 | m/s |
| Gdc | 0.9404 | rad/rad |
| b0 = U·Gdc | 1.410600 | m/(s·rad) |
| kz | 0.0800 | 1/s |
| wo | 0.3000 | rad/s |
| |gamma_corr| clamp | ±9.0 | deg |
| |d gamma_corr/dt| | ≤2.0 | deg/s |
| |dhat| bound | ±0.50 | m/s |
| Desired depth pole | -0.08 | 1/s |

Provenance: Gdc=0.9404 from OUTER_GAMMA_* mean closed-inner T_gamma DC; b0/kz/wo/clamps fixed by DEPTH_NDO_CANDIDATE_001; prior depth→gamma PI rejected (agg MAE −36% but transient/attitude FAIL); U=1.5; NED z-down.

## Baseline → candidate (exact)

| Scenario | GateB | GateC | zMAE B→C | zp95 B→C | zbias B→C | settle B→C | thMAE B→C | gMAE B→C | deSat B→C | chat B→C |
|----------|:-----:|:-----:|---------:|---------:|----------:|-----------:|----------:|---------:|----------:|---------:|
| HOLD | NO | NO | 0.2739→0.0650 | 0.3213→0.1546 | -0.2788→-0.0325 | 5.00→0.03 | 0.2185→0.3612 | 0.5906→0.5683 | 0.00→0.00 | 0.2022→0.5348 |
| STEP_P2 | YES | NO | 0.0441→0.2542 | 0.1004→0.6263 | 0.0167→-0.1322 | 13.78→18.87 | 0.1022→0.9804 | 0.5210→3.4473 | 0.00→0.00 | 0.1066→2.2316 |
| STEP_M2 | NO | NO | 0.4477→0.2154 | 0.5471→0.5253 | -0.3051→0.1291 | NaN→17.78 | 0.1172→0.9981 | 1.0042→3.4793 | 0.00→0.00 | 0.2585→2.1009 |
| XZ_RAMP | NO | NO | 0.3730→0.0813 | 0.4263→0.1482 | -0.3214→-0.0349 | NaN→0.03 | 0.0831→0.0558 | 0.6343→0.4651 | 0.00→0.00 | 0.2302→0.3574 |

- Aggregate depth MAE: 0.2847 → 0.1540 (improve 45.9%)
- Persistent settle count: 1 → 4 | settle_improve_frac=0.750
- all_depth_gates=NO | agg_improve=YES | depth_reg=NO | att_act=NO
- First fail: `STEP_P2:depth_OS(0.6689>0.6000)`

## Observer residual / bounds

| Scenario | resid_RMS [m/s] | resid_max [m/s] | |dhat|_max [m/s] | dhat_mean [m/s] | bound [m/s] | bound_hit | n_reset | |γ_corr|_max [deg] |
|----------|----------------:|----------------:|----------------:|----------------:|-----------:|:---------:|--------:|-------------------:|
| HOLD | 0.01883 | 0.04182 | 0.04929 | -0.02750 | 0.50 | NO | 3 | 2.477 |
| STEP_P2 | 0.08654 | 0.20690 | 0.15464 | 0.00026 | 0.50 | NO | 3 | 7.758 |
| STEP_M2 | 0.08825 | 0.19190 | 0.15116 | -0.05108 | 0.50 | NO | 3 | 8.003 |
| XZ_RAMP | 0.01677 | 0.04604 | 0.05613 | -0.04672 | 0.50 | NO | 3 | 2.733 |

## Fixed windows / gates (identical to baseline)

- settle_t0=5.0s end_frac=0.88 depth_band=±0.25m step_post_hold=3.0s L_smooth=15.0m z0=10.0
- HOLD/STEP/RAMP depth gates unchanged from DEPTH_OUTER_BASELINE
- Level trim pass=YES ||ν̇||=2.73e-13; climb pass=YES ||ν̇||=2.26e-13

## Decision

- Verdict: **FAIL**
- Next: **`REJECT_DEPTH_NDO_CANDIDATE`**
- Detail: Reject depth redesign (production untouched). First fail: STEP_P2:depth_OS(0.6689>0.6000). Advance next to sensor/noise/current-estimator baseline (not another depth outer redesign).
- Bounded alternative (not a sweep): **`sensor_noise_current_estimator_baseline`** — Reject further depth redesign. Next bounded step: sensor/noise/current-estimator baseline audit with production cascade+guidance frozen.
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Scenarios: HOLD=NO | STEP_P2=NO | STEP_M2=NO | XZ_RAMP=NO
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_NDO_CANDIDATE.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_NDO_CANDIDATE.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_NDO_CANDIDATE.png`
