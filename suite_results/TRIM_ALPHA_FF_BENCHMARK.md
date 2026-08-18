# TRIM_ALPHA_FF_BENCHMARK_001 — Trim alpha_ff replaces measured alpha_hat (no LPF)

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law.m`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_trim_alpha_ff.m` (production guidance untouched)
- Driver: `run_trim_alpha_ff_benchmark.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.png`
- Seed: 0 | P/U/A04 re-analyzed from ALPHA_DEPTH_P_BACKOFF; AFF simulated

## Exact equation delta

```
OLD (measured A04): alpha_hat = LPF(.98/.02, theta_phys-gamma_act); clamp +/-8deg
                    pitch_raw = gamma_path + pitch_corr + alpha_hat
NEW (trim AFF):     alpha_ff  = c0/max(u_ref,u_min)^2 + c_gamma*gamma_path; clamp +/-8deg
                    pitch_raw = gamma_path + pitch_corr + alpha_ff   (NO LPF)
c0=0.0750139438014  c_gamma=0.0472912477744  u_min=0.9
UNCHANGED: Kz=.040, Ki_z=0, K_zdot, K_gamma=0, depth filters/clamps,
           speed PI+FF, all attitude/yaw/roll gains and actuator limits
Speed: kD=1.6940741214 Kp=25 Ki=13.83617834 Kaw=0.55344713
Roll gate: tilde_own = phi - phi_eq_own (per-speed empirical), not frozen phi_eq
```

## Before / after (P / U / A04 / AFF)

| Route | uMAE P/U/A04/AFF | uP95 AFF | γMAE° P/U/A04/AFF | γΔ% U→AFF | CTE P/U/A04/AFF | CTEΔ% | yaw° P→AFF | ownT P→AFF | pRMS P→AFF |
|-------|-----------------:|---------:|------------------:|----------:|-----------------:|------:|-----------:|-----------:|-----------:|
| X | 0.3176/0.0008/0.0008/0.0005 | 0.0017 | 0.331/0.394/0.313/0.272 | +30.9 | 0.2467/0.2903/0.1131/0.0357 | +87.7 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| XZ | 0.2550/0.0010/0.0032/0.0008 | 0.0029 | 0.418/0.669/0.497/0.297 | +55.6 | 0.4002/0.5582/0.2754/0.0617 | +88.9 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| R10 | 0.3494/0.0012/0.0041/0.0039 | 0.0268 | 0.657/1.028/0.378/0.121 | +88.2 | 0.2690/0.4012/0.2490/0.2000 | +50.2 | 0.1747→0.1365 | 0.4372→0.2589 | 2.1700→1.4017 |

## Acquisition / rates (settling, overshoot, de/dr; P / A04 / AFF)

| Route | settle[s] P/A04/AFF | OS° P/A04/AFF | deRate P/A04/AFF | drRate P/A04/AFF | acq de P/A04/AFF | acq dr P/A04/AFF |
|-------|--------------------:|--------------:|-----------------:|-----------------:|-----------------:|-----------------:|
| X | 2.650/3.125/3.125 | 0.620/0.866/2.058 | 0.0035/0.0026/0.0012 | 0.0000/0.0000/0.0000 | 0.1273/0.1205/0.0779 | 0.0000/0.0000/0.0000 |
| XZ | 6.175/3.425/6.150 | 1.754/2.503/3.977 | 0.0040/0.0065/0.0009 | 0.0000/0.0000/0.0000 | 0.0813/0.1145/0.0807 | 0.0000/0.0000/0.0000 |
| R10 | 2.225/2.900/2.650 | 0.703/1.042/2.269 | 0.0040/0.0057/0.0022 | 0.6716/0.6523/0.6511 | 0.1369/0.1252/0.0743 | 0.6411/0.6269/0.6266 |

## Own-eq roll / actuators / chatter

| Route | phi_eq° P/A04/AFF | ownT RMS P→AFF | deSat% P→AFF | thrSat% AFF | I chatter | αff vs -α MAE° |
|-------|-----------------:|---------------:|-------------:|------------:|----------:|---------------:|
| X | 0.000/0.000/0.000 | 0.0000→0.0000 | 0.00→0.00 | 0.00 | YES | 0.004 |
| XZ | 0.000/0.000/0.000 | 0.0000→0.0000 | 0.00→0.00 | 0.00 | YES | 0.003 |
| R10 | 1.442/0.860/0.859 | 0.4372→0.2589 | 0.00→0.00 | 0.00 | YES | 0.045 |

## Gate table (candidate = trim AFF)

| Gate | Result | Detail |
|------|:------:|--------|
| Comp u MAE≤0.07 p95≤0.10 | YES | X=YES XZ=YES H=YES |
| γ MAE improve ≥10% vs U | YES | X=+30.9% XZ=+55.6% H=+88.2% |
| CTE improve ≥10% vs U | YES | X=+87.7% XZ=+88.9% H=+50.2% |
| Acq settle/OS/rates improve vs A04 | NO | |
| Acq/rates regress ≤2% vs production | NO | |
| Own-eq yaw/roll ≤2% vs production | YES | |
| Sat≤1% / no chatter | YES | |

## Decision

- Verdict: **FAIL**
- Next: `blend_alpha_ff_with_soft_lpf_or_rate_limit`
- Detail: FAIL leave production unchanged. Fail: settling/OS/acq-rate regress >2% vs prod, acq/rates not improve vs measured A04. Next: blend_alpha_ff_with_soft_lpf_or_rate_limit.
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Eq delta: measured LPF α̂ → `α_ff=c0/max(u_ref,.9)^2+c_γ·γ_path` (no LPF); Kz=.04 unchanged
- γMAE° U→A04→AFF: X 0.394→0.313→0.272 | XZ 0.669→0.497→0.297 | R10 1.028→0.378→0.121
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.png`
- Next: `blend_alpha_ff_with_soft_lpf_or_rate_limit`
