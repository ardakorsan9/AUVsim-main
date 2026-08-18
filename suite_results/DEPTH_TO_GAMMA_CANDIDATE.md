# DEPTH_TO_GAMMA_CANDIDATE_001 — Model depth→gamma PI candidate @ U=1.50

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\run_depth_outer_baseline.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_to_gamma.m` (production `guidance_law.m` / `controller_law.m` untouched)
- Baseline: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.mat` / `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.md` (DEPTH_OUTER_BASELINE_001 identical paths/IC/windows)
- Driver: `run_depth_to_gamma_candidate.m` (one invocation; no production edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_TO_GAMMA_CANDIDATE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_TO_GAMMA_CANDIDATE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_TO_GAMMA_CANDIDATE.png`
- Seed: 0 | Kp_roll frozen=0.605072 | Kp_x=25 | thrust_trim=13.4 N
- CODEX_VERTICAL_PLAN.md: untouched

## Frames / units

| Item | Definition |
|------|------------|
| Inertial | NED (North-East-Down): x North, y East, z Down |
| Body | BODY: x forward, y starboard, z down; rates p,q,r about BODY; Euler ZYX (psi,theta,phi) with ang_dot = JJ*[p;q;r] |
| z / depth positive down? | **YES** — depth ≡ z_NED [m] |
| e_z | e_z = z − z_ref = cte(3) = z_veh−z_path (filtered z_e_f) [m] |
| Kinematics | ė_z ≈ U · Gdc · gamma_corr |
| theta_phys | theta_phys = -theta  [rad]; dive-positive matches atan2(dz,dx) with z down |
| Cascade | frozen theta/q + climb FF (`k_gamma_climb=0.1320695001`) |

## Candidate equations / gains / poles

```
e_z = z - z_ref  (NED down; = cte(3) = z_veh-z_path, filtered z_e_f)
ė_z ≈ U * Gdc * gamma_corr
Kp = 2*zeta*wn/(U*Gdc);  Ki = wn^2/(U*Gdc)
gamma_corr_raw = -Kp*e_z - Ki*I
gamma_corr = rate_limit(sat(gamma_corr_raw, ±12deg), 3deg/s)
conditional I + Kaw*aw back-calc on sat; bumpless I=0
pitch_raw = pitch_geom + gamma_corr  (thru frozen theta/q + climb FF)
```

| Symbol | Value | Units |
|--------|------:|-------|
| wn | 0.0800 | rad/s |
| zeta | 1.0000 | — |
| U | 1.5000 | m/s |
| Gdc | 0.9404 | rad/rad |
| Kp | 0.11342691 | rad/m |
| Ki | 0.00453708 | rad/(m·s) |
| Kaw | 0.04000000 | 1/s |
| |gamma_corr| clamp | ±12.0 | deg |
| |d gamma_corr/dt| | ≤3.0 | deg/s |
| Desired poles | -0.08, -0.08 | rad/s |

Provenance: Gdc=0.9404 from OUTER_GAMMA_* mean closed-inner T_gamma DC (OUTER_GAMMA_ADRC_SCAFFOLD / OUTER_GAMMA_PI_SCAFFOLD / OUTER_GAMMA_INDI_AUDIT); wn/zeta fixed by task; U=1.5 design speed; NED z-down kinematics.

## Baseline → candidate (exact)

| Scenario | GateB | GateC | zMAE B→C | zp95 B→C | zbias B→C | settle B→C | thMAE B→C | gMAE B→C | deSat B→C | chat B→C |
|----------|:-----:|:-----:|---------:|---------:|----------:|-----------:|----------:|---------:|----------:|---------:|
| HOLD | NO | NO | 0.2739→0.1499 | 0.3213→0.2289 | -0.2788→-0.1472 | 5.00→0.03 | 0.2185→0.3653 | 0.5906→0.5849 | 0.00→0.00 | 0.2022→0.4068 |
| STEP_P2 | YES | NO | 0.0441→0.0721 | 0.1004→0.1536 | 0.0167→-0.0831 | 13.78→12.98 | 0.1022→0.2100 | 0.5210→0.9783 | 0.00→0.00 | 0.1066→0.3811 |
| STEP_M2 | NO | NO | 0.4477→0.2777 | 0.5471→0.5090 | -0.3051→-0.0795 | NaN→19.77 | 0.1172→0.3030 | 1.0042→1.8447 | 0.00→0.00 | 0.2585→0.4530 |
| XZ_RAMP | NO | YES | 0.3730→0.2239 | 0.4263→0.2474 | -0.3214→-0.1976 | NaN→17.10 | 0.0831→0.0325 | 0.6343→0.3755 | 0.00→0.00 | 0.2302→0.0118 |

- Aggregate depth MAE: 0.2847 → 0.1809 (improve 36.4%)
- Persistent settle count: 1 → 4 | settle_improve_frac=0.750
- all_depth_gates=NO | agg_improve=YES | depth_reg=NO | att_act=NO
- First fail: `STEP_M2:settle(19.77>18.00 or NaN)`

## Fixed windows / gates (identical to baseline)

- settle_t0=5.0s end_frac=0.88 depth_band=±0.25m step_post_hold=3.0s L_smooth=15.0m z0=10.0
- HOLD/STEP/RAMP depth gates unchanged from DEPTH_OUTER_BASELINE
- Level trim pass=YES ||ν̇||=2.73e-13; climb pass=YES ||ν̇||=2.26e-13

## Decision

- Verdict: **FAIL**
- Next: **`REJECT_DEPTH_TO_GAMMA_CANDIDATE`**
- Detail: Reject/revert isolated candidate (production untouched). First fail: STEP_M2:settle(19.77>18.00 or NaN). Next bounded alternative (not a sweep): raised-cosine depth-reference soft-start / command shaping on z_ref before the same PI, or one NDO buoyancy-bias observer feeding gamma_corr (fixed b0 from Gdc).
- Bounded alternative (not a sweep): **`bounded_zref_raised_cosine_softstart_or_NDO_buoyancy`** — Prefer one bounded depth-reference raised-cosine soft-start (shape z_ref transitions; keep FIXED Kp/Ki) OR one NDO estimating constant buoyancy/trim depth bias with b0=U*Gdc, feeding gamma_corr — no gain sweep.
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Scenarios: HOLD=NO | STEP_P2=NO | STEP_M2=NO | XZ_RAMP=YES
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_TO_GAMMA_CANDIDATE.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_TO_GAMMA_CANDIDATE.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_TO_GAMMA_CANDIDATE.png`
