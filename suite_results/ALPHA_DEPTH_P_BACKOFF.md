# ALPHA_DEPTH_P_BACKOFF_001 — Depth-P backoff (0.050→0.040) on alpha-no-I

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_i_ablation.m`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_p_backoff.m` (production guidance untouched)
- Driver: `run_alpha_depth_p_backoff.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.png`
- Seed: 0

## Exact equation delta

```
OLD (alpha-no-I Kz=.05): pitch_corr = -0.050*z_e_f + 0*z_e_i - K_zdot*zd_e_f
NEW (candidate Kz=.04):  pitch_corr = -0.040*z_e_f + 0*z_e_i - K_zdot*zd_e_f
UNCHANGED: Ki_z=0, K_zdot, z_e_f/zd_e_f filters, |pitch_corr|<=9deg,
           z_e_i integrate+clamp +/-25, alpha_hat LPF .98/.02 +/-8deg,
           K_gamma=0, all controller gains, speed PI+FF, attitude/yaw/roll
Speed: kD=1.6940741214 Kp=25 Ki=13.83617834 Kaw=0.55344713
```

## Before / after (P / U / A05=Kz.05 / A04=Kz.04)

| Route | uMAE P/U/A05/A04 | uP95 A04 | γMAE° P/U/A05/A04 | γΔ% U→A04 | CTE P/U/A05/A04 | CTEΔ% | yaw° P→A04 | tilde P→A04 | pRMS P→A04 |
|-------|-----------------:|---------:|------------------:|----------:|-----------------:|------:|-----------:|------------:|-----------:|
| X | 0.3176/0.0008/0.0009/0.0008 | 0.0032 | 0.331/0.394/0.357/0.313 | +20.5 | 0.2467/0.2903/0.1007/0.1131 | +61.0 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| XZ | 0.2550/0.0010/0.0032/0.0032 | 0.0216 | 0.418/0.669/0.559/0.497 | +25.8 | 0.4002/0.5582/0.2507/0.2754 | +50.7 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| R10 | 0.3494/0.0012/0.0041/0.0041 | 0.0287 | 0.657/1.028/0.386/0.378 | +63.2 | 0.2690/0.4012/0.2398/0.2490 | +37.9 | 0.1747→0.1357 | 0.4376→0.6642 | 2.1700→1.4980 |

## Depth-corr components (steady MAE deg; A05 vs A04)

| Route | corr_P A05/A04 | corr_I A05/A04 | corr_zd A05/A04 | pitch_corr A05/A04 |
|-------|---------------:|---------------:|----------------:|-------------------:|
| X | 0.3113/0.2744 | 0.0000/0.0000 | 0.0000/0.0000 | 0.3113/0.2744 |
| XZ | 0.6248/0.5476 | 0.0000/0.0000 | 0.0000/0.0000 | 0.6248/0.5476 |
| R10 | 0.3380/0.3181 | 0.0000/0.0000 | 0.0000/0.0000 | 0.3380/0.3181 |

## Actuator / saturation / chatter (steady; A04 vs P)

| Route | deSat% P→A04 | drSat% P→A04 | thrSat% A04 | deRate A04/P | acq deRate A04/P | I chatter | ahat vs -α MAE° |
|-------|-------------:|-------------:|------------:|-------------:|-----------------:|----------:|----------------:|
| X | 0.00→0.00 | 0.00→0.00 | 0.00 | 0.0026/0.0035 | 0.1205/0.1273 | YES | 0.155 |
| XZ | 0.00→0.00 | 0.00→0.00 | 0.00 | 0.0065/0.0040 | 0.1145/0.0813 | YES | 0.268 |
| R10 | 0.00→0.00 | 0.00→0.00 | 0.00 | 0.0057/0.0040 | 0.1252/0.1369 | YES | 0.199 |

## Gate table (candidate = A04 Kz=.04)

| Gate | Result | Detail |
|------|:------:|--------|
| Comp u MAE≤0.07 p95≤0.10 | YES | X=YES XZ=YES H=YES |
| γ MAE improve ≥10% vs U | YES | X=+20.5% XZ=+25.8% H=+63.2% |
| CTE improve ≥10% vs U | YES | X=+61.0% XZ=+50.7% H=+37.9% |
| Yaw/roll ≤2% vs production | NO | |
| Actuator ≤2% vs production | NO | |
| Settling not worse vs prod | NO | |
| No sat/chatter/transient reg | YES | |

## Decision

- Verdict: **FAIL**
- Next: `speed_aware_roll_coupling_audit`
- Detail: FAIL leave production unchanged. Fail: yaw/roll >2% vs prod, actuator >2% vs prod, settling worse. Measured-alpha closed after 3 failures (COMP + DEPTH_I + DEPTH_P). Next method: speed_aware_roll_coupling_audit.
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Eq delta: `-0.050*z_e_f+0*z_e_i-K_zdot*zd_e_f` → `-0.040*z_e_f+0*z_e_i-K_zdot*zd_e_f`
- γMAE° U→A05→A04: X 0.394→0.357→0.313 | XZ 0.669→0.559→0.497 | R10 1.028→0.386→0.378
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.png`
- Next: `speed_aware_roll_coupling_audit`
