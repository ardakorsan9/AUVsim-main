# YAW_ROLL_DAMPING_BENCHMARK_001 — Coordinated yaw-roll p-damping benchmark

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.mat`
- Driver: `run_yaw_roll_damping_benchmark.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.png`
- Seed: 0 | rudder limits +/-25 deg, 40 deg/s

## Law / gain / poles

```
dr_cmd = sat( dr_yaw + g_ac*( -Kp*p + Kphi*(phi-phi_eq) ) ); Kphi=0
Sign: Bp=d(p_dot)/d(dr)>0 => dr_damp=-Kp*p (Kp>0) | Bp_level=1.3922 Bp_climb=1.2980
Gain: Kp=1.704286 s (ONE derived; zdes=0.12; robust max(level,climb))
Kphi=0 (no bank-to-zero); phi_eq=0 straight, empirical 1.4610 deg on R10
Anti-conflict: g_ac=1/(1+(|e_psi|/ 3.0deg)^2+(|e_r|/ 8.0dps)^2)
Level poles: open f=0.7947 Hz z=0.00428 -> cl f=0.9063 Hz z=0.23062
Climb poles: open f=0.7607 Hz z=0.00396 -> cl f=0.8834 Hz z=0.12000
Per-model Newton K: level=0.807552 climb=1.704286
```

## phi_eq

| Route | phi_eq [deg] | note |
|-------|-------------:|------|
| X | 0.0000 | forced_zero_straight |
| XZ | 0.0000 | forced_zero_straight |
| H | 1.4610 | empirical_cycle_mean_not_equilibrium (from ROLL_TRIM_RELATIVE_AUDIT) |

## Before / after (steady)

| Route | metric | base | cand | d% |
|-------|--------|-----:|-----:|---:|
| X | tildeMAE | 0.0000 | 0.0000 | +0.00 |
| X | tildeRMS | 0.0000 | 0.0000 | +0.00 |
| X | pRMS | 0.0000 | 0.0000 | +0.00 |
| X | yawMAE | 0.0000 | 0.0000 | +0.00 |
| X | yawRMS | 0.0000 | 0.0000 | +0.00 |
| X | yawP95 | 0.0000 | 0.0000 | +0.00 |
| X | pitchMAE | 0.0110 | 0.0110 | +0.00 |
| XZ | tildeMAE | 0.0000 | 0.0000 | +0.00 |
| XZ | tildeRMS | 0.0000 | 0.0000 | +0.00 |
| XZ | pRMS | 0.0000 | 0.0000 | +0.00 |
| XZ | yawMAE | 0.0000 | 0.0000 | +0.00 |
| XZ | yawRMS | 0.0000 | 0.0000 | +0.00 |
| XZ | yawP95 | 0.0000 | 0.0000 | +0.00 |
| XZ | pitchMAE | 0.1214 | 0.1214 | +0.00 |
| H | tildeMAE | 0.4619 | 0.2308 | -50.02 |
| H | tildeRMS | 0.5538 | 0.3189 | -42.41 |
| H | pRMS | 2.7611 | 1.5857 | -42.57 |
| H | yawMAE | 0.1748 | 0.1752 | +0.26 |
| H | yawRMS | 0.2041 | 0.2068 | +1.30 |
| H | yawP95 | 0.3493 | 0.3670 | +5.07 |
| H | pitchMAE | 0.0413 | 0.0411 | -0.43 |

R10 roll improve: tildeRMS d%=-42.41 (need <=-10) | pRMS d%=-42.57 (need <=-10) | pass=YES

## Gates

| Gate | Result | Detail |
|------|:------:|--------|
| R10 tildeRMS or pRMS improve >=10% | YES | d_tilde=-42.41% d_p=-42.57% |
| Yaw MAE/RMS/p95 regress <=2% | NO | d%=0.26/1.30/5.07 |
| Pitch gates preserved | YES | abs X/XZ/H + reg<=2% |
| Rudder rate/near/sat not worsen | YES | rate 38.343->38.362 near 0.00->0.00 sat 0.00->0.00 |
| X/XZ remain clean | YES | |

## Decision

- Verdict: **FAIL**
- Next: `reject_revert_diagnostic`
- Detail: REJECT diagnostic candidate; production untouched. Reasons: yaw regress>2%.

## Feedback

- Verdict: **FAIL**
- Equation/gain: dr=dr_yaw - 1.704286*p (Kphi=0); poles level z 0.00428->0.23062, climb 0.00396->0.12000
- R10 before/after: tildeRMS 0.5538->0.3189 (-42.41%); pRMS 2.7611->1.5857 (-42.57%)
- Yaw d% MAE/RMS/p95: 0.26 / 1.30 / 5.07 | act ok=YES | X/XZ clean=YES
- Next: reject_revert_diagnostic
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.png`
