# SPEED_BASELINE_AUDIT_001 — Surge-speed baseline / root cause

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\init_parameters.m`
- Driver: `run_speed_baseline_audit.m` (one invocation; no production edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.png`
- Seed: 0 | Kp_roll frozen=0.605072 | Kp_x=25 | thrust_trim=13.4 N

## Law / frame / units

```
thrust = sat(thrust_trim + Kp_x*(u_ref - u); [thrust_min,thrust_max])
Frame: BODY u [m/s] controller var; Uh=hypot(xdot,ydot); |V|=||nu_lin||
Units: u,u_ref,Uh,|V| [m/s]; thrust [N]; Kp_x [N/(m/s)]
```

## Steady hold metrics (BODY u vs u_ref)

| Route | signed | MAE | RMS | p95 | max | Uh_mean | |V|_mean | frame_gap_Uh |
|-------|-------:|----:|----:|----:|----:|--------:|--------:|-------------:|
| X | -0.3176 | 0.3176 | 0.3176 | 0.3188 | 0.3188 | 1.8176 | 1.8177 | 0.0004 |
| XZ | -0.2550 | 0.2550 | 0.2550 | 0.2567 | 0.2567 | 1.6299 | 1.7559 | 0.1247 |
| R10 | -0.3494 | 0.3494 | 0.3495 | 0.3720 | 0.3781 | 1.5568 | 1.5579 | 0.0002 |

## Thrust (steady hold)

| Route | mean | RMS | rateRMS | near% | sat% | trim | prop | trim_frac |
|-------|-----:|----:|--------:|------:|-----:|-----:|-----:|----------:|
| X | 5.461 | 5.461 | 0.011 | 0.00 | 0.00 | 13.400 | -7.939 | 2.454 |
| XZ | 7.025 | 7.025 | 0.007 | 0.00 | 0.00 | 13.400 | -6.375 | 1.907 |
| R10 | 4.666 | 4.670 | 0.390 | 0.00 | 0.00 | 13.400 | -8.734 | 2.872 |
| STEP | 5.994 | 6.061 | 11.225 | 0.00 | 0.00 | 13.400 | -7.406 | 2.236 |

## Step 1.3→1.5→1.3

| Leg | uref | settle_s | OS% | lag_s | MAE | signed | PASS |
|-----|-----:|---------:|----:|------:|----:|-------:|:----:|
| 1 | 1.30 | NaN | 0.00 | 0.025 | 0.3091 | -0.3091 | NO |
| 2 | 1.50 | NaN | 158.28 | NaN | 0.2962 | -0.2962 | NO |
| 3 | 1.30 | NaN | 0.00 | NaN | 0.3735 | -0.3735 | NO |

## Coupling / freeze vs ROLL_PRODUCTION_CLOSURE

| Route | pitchMAE | yawMAE | tildeRMS/MAE | pRMS | CTE | freeze |
|-------|---------:|-------:|-------------:|-----:|----:|:------:|
| X | 0.0110 | 0.0000 | MAE 0.0000 | 0.0000 | 0.2467 | YES |
| XZ | 0.1214 | 0.0000 | MAE 0.0000 | 0.0000 | 0.3953 | YES |
| R10 | 0.0411 | 0.1747 | RMS 0.4376 | 2.1700 | 0.2301 | YES |

## Gate table

| Gate | Result | Detail |
|------|:------:|--------|
| Pref u MAE≤0.03 p95≤0.05 (X/XZ/R10) | NO | X=NO XZ=NO H=NO |
| Hard u MAE≤0.07 p95≤0.10 (X/XZ/R10) | NO | X=NO XZ=NO H=NO |
| Step settle≤6s OS≤10% ±0.05 | NO | worst_ts=NaN worst_OS=158.28 |
| Thrust sat≤1% | YES | X=0.00 XZ=0.00 H=0.00 Step=0.00 |
| Frozen pitch/yaw/roll/path | YES | pitch=YES yaw=YES roll=YES path=YES |

## Root class / decision

- Root class: **TRIM_TABLE_BIAS**
- Verdict: **FAIL**
- Next: `audit_thrust_trim_at_Uref`
- Detail: Steady e_u≈(T-Ttrim)/Kp_x with |e| large and T≠Ttrim=13.40 N; single thrust_trim@Uref audit (no gain) before envelope.
- Production: untouched (no gain / no law edit)

## Feedback

- PASS/FAIL: **FAIL**
- Key: X mae/p95=0.3176/0.3188 | XZ=0.2550/0.2567 | R10=0.3494/0.3720 | step_ok=NO
- Root: TRIM_TABLE_BIAS
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.png`
- Next: audit_thrust_trim_at_Uref
