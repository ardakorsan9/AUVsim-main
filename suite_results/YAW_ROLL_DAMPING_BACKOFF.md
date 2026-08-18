# YAW_ROLL_DAMPING_BACKOFF_002 — Constrained yaw-roll p-damping backoff

**Overall verdict: PASS**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`
- Driver: `run_yaw_roll_damping_backoff.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.png`
- Seed: 0 | rudder limits +/-25 deg, 40 deg/s

## Law / gain / poles

```
dr_cmd = sat( dr_yaw + g_ac*( -Kp*p + Kphi*(phi-phi_eq) ) ); Kphi=0
Provenance: TUNED | Kp2=Kp1*(1.80/5.07) from observed yaw-p95 sensitivity; safety target 1.80%; rejected Kp1=1.704286 gave +5.07%
Sign: Bp=d(p_dot)/d(dr)>0 => dr_damp=-Kp*p (Kp>0) | Bp_level=1.3922 Bp_climb=1.2980
Gain: Kp2=0.605072 s = 1.704286*(1.80/5.07); Kphi=0; NO sweep
Kphi=0 (no bank-to-zero); phi_eq=0 straight, empirical 1.4610 deg on R10
Anti-conflict: g_ac=1/(1+(|e_psi|/ 3.0deg)^2+(|e_r|/ 8.0dps)^2)
Limiter: sum yaw+damp THEN mag/rate (identical placement)
Level poles: open f=0.7947 Hz z=0.00428 -> cl f=0.8343 Hz z=0.09362 (Kp1 z=0.23062)
Climb poles: open f=0.7607 Hz z=0.00396 -> cl f=0.8043 Hz z=0.04949 (Kp1 z=0.12000)
Poles method: modal_linear_from_BENCHMARK_open_cl_at_Kp1 | poles_ok=1
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
| H | tildeMAE | 0.4619 | 0.3415 | -26.06 |
| H | tildeRMS | 0.5538 | 0.4376 | -20.99 |
| H | pRMS | 2.7611 | 2.1700 | -21.41 |
| H | yawMAE | 0.1748 | 0.1747 | -0.06 |
| H | yawRMS | 0.2041 | 0.2043 | +0.07 |
| H | yawP95 | 0.3493 | 0.3507 | +0.40 |
| H | pitchMAE | 0.0413 | 0.0411 | -0.33 |

R10 roll improve: tildeRMS d%=-20.99 (need <=-10) | pRMS d%=-21.41 (need <=-10) | pass=YES

## Gates

| Gate | Result | Detail |
|------|:------:|--------|
| Level/climb poles stable + zeta up | YES | L z 0.00428->0.09362; C z 0.00396->0.04949 |
| R10 tildeRMS or pRMS improve >=10% | YES | d_tilde=-20.99% d_p=-21.41% |
| Yaw MAE/RMS/p95 regress <=2% | YES | d%=-0.06/0.07/0.40 |
| Pitch gates preserved | YES | abs X/XZ/H + reg<=2% |
| Rudder RMS/rate/near/sat not worsen >2% | YES | rms +0.01% rate +0.30% near 0.00->0.00 sat 0.00->0.00 |
| X/XZ remain clean | YES | |
| No new oscillation | YES | growth base=0.515 cand=0.386 (late/early tildeRMS) |

## Decision

- Verdict: **PASS**
- Next: `two_repeat_production_integration_regression`
- Detail: BACKOFF PASS at Kp2=0.605072 s: R10 roll improved (d_tildeRMS=-20.99%, d_pRMS=-21.41%); yaw/pitch/actuator/osc gates held; X/XZ clean. Recommend SEPARATE two-repeat production-integration regression; do NOT edit production in this task.

## Feedback

- Verdict: **PASS**
- K derivation: Kp2=0.605072 = 1.704286*(1.80/5.07) [TUNED]
- Equation/gain: dr=dr_yaw - 0.605072*p (Kphi=0); poles level z 0.00428->0.09362, climb 0.00396->0.04949
- R10 before/after: tildeRMS 0.5538->0.4376 (-20.99%); pRMS 2.7611->2.1700 (-21.41%)
- Yaw d% MAE/RMS/p95: -0.06 / 0.07 / 0.40 | act ok=YES | X/XZ clean=YES | osc=YES
- Next: two_repeat_production_integration_regression
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.png`
