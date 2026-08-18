# TRIM_ALPHA_FF_RATE_LIMIT_001 — Rate-limit shaping of trim alpha_ff (no LPF)

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_trim_alpha_ff.m`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_trim_alpha_ff_rate_limit.m` (production guidance untouched)
- Driver: `run_trim_alpha_ff_rate_limit.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.png`
- Seed: 0 | P/A04/AFF loaded from TRIM_ALPHA_FF_BENCHMARK; RL simulated

## Exact shaping equation

```
alpha_ff  = c0/max(u_ref,u_min)^2 + c_gamma*gamma_path; clamp +/-8deg
alpha_cmd(0) = 0
alpha_cmd(k) = alpha_cmd(k-1) + sat(alpha_ff-alpha_cmd(k-1), +/- rate_max*dt)
  with |d alpha_cmd/dt| <= 2 deg/s  (=1/3 of pitch_ref_rate_max=6deg/s)
pitch_raw = gamma_path + pitch_corr + alpha_cmd   (NO LPF)
c0=0.0750139438014  c_gamma=0.0472912477744  u_min=0.9  rate_max=2deg/s
UNCHANGED: schedule, Kz=.040, Ki_z=0, K_gamma=0, depth filters/clamps,
           speed PI+FF, all attitude/yaw/roll gains and actuator limits
Speed: kD=1.6940741214 Kp=25 Ki=13.83617834 Kaw=0.55344713
Roll gate: tilde_own = phi - phi_eq_own (per-speed empirical)
```

## Before / after (P / A04 / AFF / RL)

| Route | uMAE P/A04/AFF/RL | uP95 RL | γMAE° P/A04/AFF/RL | γΔ% U→RL | CTE P/A04/AFF/RL | CTEΔ% | yaw° P→RL | ownT P→RL | pRMS P→RL |
|-------|-----------------:|-------:|------------------:|---------:|-----------------:|------:|----------:|----------:|----------:|
| X | 0.3176/0.0008/0.0005/0.0006 | 0.0022 | 0.331/0.313/0.272/0.290 | +26.3 | 0.2467/0.1131/0.0357/0.0235 | +91.9 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| XZ | 0.2550/0.0032/0.0008/0.0009 | 0.0030 | 0.418/0.497/0.297/0.362 | +45.9 | 0.4002/0.2754/0.0617/0.1192 | +78.6 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| R10 | 0.3494/0.0041/0.0039/0.0039 | 0.0273 | 0.657/0.378/0.121/0.150 | +85.4 | 0.2690/0.2490/0.2000/0.2060 | +48.6 | 0.1747→0.1361 | 0.4372→0.2895 | 2.1700→1.5365 |

## Acquisition / rates (P / A04 / AFF / RL)

| Route | settle[s] P/A04/AFF/RL | OS° P/A04/AFF/RL | setΔ% AFF→RL | OSΔ% AFF→RL | deRate P/AFF/RL | drRate P/AFF/RL |
|-------|-----------------------:|-----------------:|-------------:|------------:|----------------:|----------------:|
| X | 2.650/3.125/3.125/3.350 | 0.620/0.866/2.058/1.498 | -7.2 | +27.2 | 0.0035/0.0012/0.0014 | 0.0000/0.0000/0.0000 |
| XZ | 6.175/3.425/6.150/5.750 | 1.754/2.503/3.977/3.350 | +6.5 | +15.8 | 0.0040/0.0009/0.0015 | 0.0000/0.0000/0.0000 |
| R10 | 2.225/2.900/2.650/2.975 | 0.703/1.042/2.269/1.769 | -12.3 | +22.0 | 0.0040/0.0022/0.0021 | 0.6716/0.6511/0.6514 |

## Own-eq roll / actuators / chatter / alpha rate

| Route | phi_eq° P/A04/RL | ownT RMS P→RL | deSat% P→RL | thrSat% RL | I chatter | αcmd rate max°/s |
|-------|-----------------:|--------------:|------------:|-----------:|----------:|-----------------:|
| X | 0.000/0.000/0.000 | 0.0000→0.0000 | 0.00→0.00 | 0.00 | YES | 2.000 |
| XZ | 0.000/0.000/0.000 | 0.0000→0.0000 | 0.00→0.00 | 0.00 | YES | 2.000 |
| R10 | 1.442/0.860/0.862 | 0.4372→0.2895 | 0.00→0.00 | 0.00 | YES | 2.000 |

## Gate table (candidate = rate-limited AFF)

| Gate | Result | Detail |
|------|:------:|--------|
| Comp u MAE≤0.07 p95≤0.10 | YES | X=YES XZ=YES H=YES |
| γ MAE improve ≥10% vs U | YES | X=+26.3% XZ=+45.9% H=+85.4% |
| CTE improve ≥10% vs U | YES | X=+91.9% XZ=+78.6% H=+48.6% |
| Settle/OS improve ≥10% vs unshaped AFF | NO | set X/XZ/H=-7.2/+6.5/-12.3 OS=+27.2/+15.8/+22.0 |
| Settle/OS regress ≤2% vs production | NO | |
| Elevator/rudder rates regress ≤2% vs production | NO | |
| Own-eq yaw/roll ≤2% vs production | YES | |
| Sat≤1% / no chatter | YES | |

## Decision

- Verdict: **FAIL**
- Next: `alpha_cmd_slew_with_soft_start_or_1deg_s`
- Detail: FAIL leave production unchanged. Fail: elevator/rudder rates regress >2% vs prod, settle/OS worsen >2% vs prod, settle/OS not improve >=10% vs unshaped AFF. Next: alpha_cmd_slew_with_soft_start_or_1deg_s.
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Shaping: `α_cmd(0)=0; |dα_cmd/dt|≤2°/s; pitch_raw=γ_path+pitch_corr+α_cmd`
- γMAE° P/A04/AFF/RL: X 0.331/0.313/0.272/0.290 | XZ 0.418/0.497/0.297/0.362 | R10 0.657/0.378/0.121/0.150
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.png`
- Next: `alpha_cmd_slew_with_soft_start_or_1deg_s`
