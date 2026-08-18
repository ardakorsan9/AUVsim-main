# ALPHA_DEPTH_I_ABLATION_001 — Depth-I ablation with alpha_hat + speed PI+FF

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law.m`
- Isolated helper: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law_depth_i_ablation.m` (production guidance untouched)
- Driver: `run_alpha_depth_i_ablation.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.png`
- Seed: 0

## Exact equation delta

```
OLD (prod / alpha+I): pitch_corr = -0.050*z_e_f - 0.006*z_e_i - K_zdot*zd_e_f
NEW (alpha-no-I):     pitch_corr = -0.050*z_e_f + 0*z_e_i     - K_zdot*zd_e_f
UNCHANGED: P gain 0.050, K_zdot, z_e_f/zd_e_f filters, |pitch_corr|<=9deg,
           z_e_i integrate+clamp +/-25, alpha_hat LPF .98/.02 +/-8deg,
           K_gamma=0, all controller gains, speed PI+FF
Speed: kD=1.6940741214 Kp=25 Ki=13.83617834 Kaw=0.55344713
```

## Before / after (P / U / AI=alpha+I / A0=alpha-no-I)

| Route | uMAE P/U/AI/A0 | uP95 A0 | γMAE° P/U/AI/A0 | γΔ% U→A0 | CTE P/U/AI/A0 | CTEΔ% | yaw° P→A0 | tilde P→A0 | pRMS P→A0 |
|-------|---------------:|--------:|-----------------:|---------:|---------------:|------:|----------:|-----------:|----------:|
| X | 0.3176/0.0008/0.0009/0.0009 | 0.0034 | 0.331/0.394/0.609/0.357 | +9.4 | 0.2467/0.2903/0.0747/0.1007 | +65.3 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| XZ | 0.2550/0.0010/0.0031/0.0032 | 0.0215 | 0.418/0.669/1.011/0.559 | +16.5 | 0.4002/0.5582/0.1806/0.2507 | +55.1 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| R10 | 0.3494/0.0012/0.0043/0.0041 | 0.0288 | 0.657/1.028/0.653/0.386 | +62.4 | 0.2690/0.4012/0.2517/0.2398 | +40.2 | 0.1747→0.1361 | 0.4376→0.6686 | 2.1700→1.5494 |

## Depth-corr components (steady MAE deg; AI vs A0)

| Route | corr_P AI/A0 | corr_I AI/A0 | pitch_corr AI/A0 | z_e_i mean AI/A0 |
|-------|-------------:|-------------:|-----------------:|-----------------:|
| X | 0.2363/0.3113 | 0.3669/0.0000 | 0.5896/0.3113 | -1.0674/-1.1791 |
| XZ | 0.4619/0.6248 | 0.7498/0.0000 | 1.1704/0.6248 | -2.1810/-2.5103 |
| R10 | 0.4071/0.3380 | 0.5429/0.0000 | 0.6756/0.3380 | -1.5354/-3.3668 |

## Actuator / saturation / chatter (steady; A0 vs P)

| Route | deSat% P→A0 | drSat% P→A0 | thrSat% A0 | deRate A0/P | acq deRate A0/P | I chatter | ahat vs -α MAE° |
|-------|------------:|------------:|-----------:|------------:|----------------:|----------:|----------------:|
| X | 0.00→0.00 | 0.00→0.00 | 0.00 | 0.0026/0.0035 | 0.1205/0.1273 | YES | 0.154 |
| XZ | 0.00→0.00 | 0.00→0.00 | 0.00 | 0.0067/0.0040 | 0.1142/0.0813 | YES | 0.265 |
| R10 | 0.00→0.00 | 0.00→0.00 | 0.00 | 0.0058/0.0040 | 0.1247/0.1369 | YES | 0.199 |

## Gate table (candidate = A0 alpha-no-I)

| Gate | Result | Detail |
|------|:------:|--------|
| Comp u MAE≤0.07 p95≤0.10 | YES | X=YES XZ=YES H=YES |
| γ MAE improve ≥10% vs U | NO | X=+9.4% XZ=+16.5% H=+62.4% |
| CTE improve ≥10% vs U | YES | X=+65.3% XZ=+55.1% H=+40.2% |
| Yaw/roll ≤2% vs production | NO | |
| Actuator ≤2% vs production | NO | |
| No sat/chatter/transient reg | YES | |

## Decision

- Verdict: **FAIL**
- Next: `reduce_depth_P_or_trim_schedule_alpha`
- Detail: FAIL leave production unchanged. Fail: gamma MAE <10% improve, yaw/roll >2% vs prod, actuator >2% vs prod. Zeroing depth-I with alpha_hat ON did not clear all gates.
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Eq delta: `-0.050*z_e_f-0.006*z_e_i-K_zdot*zd_e_f` → `-0.050*z_e_f+0*z_e_i-K_zdot*zd_e_f`
- γMAE° U→AI→A0: X 0.394→0.609→0.357 | XZ 0.669→1.011→0.559 | R10 1.028→0.653→0.386
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.png`
- Next: `reduce_depth_P_or_trim_schedule_alpha`
