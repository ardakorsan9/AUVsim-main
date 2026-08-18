# ROLL_PRODUCTION_CLOSURE_001 — Production roll-damp integration closure

**Overall verdict: PASS**

## Provenance

- Read-only sources: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\continuous_path_tracking.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.mat`
- Driver: `run_roll_production_closure.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.png`
- Seed: 0 | two repeats/route | rudder +/-25 deg, 40 deg/s

## Old -> new / equation / provenance

```
OLD: dr_cmd = sat_mag_rate( Kp_psi*e_psi - Kd_psi*e_r )  [no roll damp]
NEW: dr_cmd = sat_mag_rate( dr_yaw + g_ac*(-0.605072*p) )
EQ:  dr_cmd = sat_mag_rate( dr_yaw + g_ac*(-Kp_roll*p) ); g_ac=1/(1+(|e_psi|/3deg)^2+(|e_r|/8dps)^2); Kphi=0
Kp_roll=0.605072 s | Kphi=0 | provenance: YAW_ROLL_DAMPING_BACKOFF PASS (TUNED Kp2)
Yaw/pitch gains UNCHANGED (Kp_psi=32 Kd_psi=13)
Sum dr_damp BEFORE existing magnitude/rate limiter
Optional p input (default 0); continuous_path_tracking passes BODY p=state(10)
```

## Repeat table (seed=0)

| Mode | Route | det PASS | max|rep1-rep2| |
|------|-------|:--------:|---------------:|
| base Kp=0 | X | YES | 0.000e+00 |
| base Kp=0 | XZ | YES | 0.000e+00 |
| base Kp=0 | H | YES | 0.000e+00 |
| prod Kp=0.605072 | X | YES | 0.000e+00 |
| prod Kp=0.605072 | XZ | YES | 0.000e+00 |
| prod Kp=0.605072 | H | YES | 0.000e+00 |

## Before / after (steady, rep1)

| Route | metric | base | prod | d% |
|-------|--------|-----:|-----:|---:|
| X | tildeMAE | 0.0000 | 0.0000 | +0.00 |
| X | tildeRMS | 0.0000 | 0.0000 | +0.00 |
| X | pRMS | 0.0000 | 0.0000 | +0.00 |
| X | yawMAE | 0.0000 | 0.0000 | +0.00 |
| X | yawRMS | 0.0000 | 0.0000 | +0.00 |
| X | yawP95 | 0.0000 | 0.0000 | +0.00 |
| X | pitchMAE | 0.0110 | 0.0110 | +0.00 |
| X | pitchRMS | 0.0164 | 0.0164 | +0.00 |
| X | pitchP95 | 0.0419 | 0.0419 | +0.00 |
| X | pathCTE | 0.2467 | 0.2467 | +0.00 |
| XZ | tildeMAE | 0.0000 | 0.0000 | +0.00 |
| XZ | tildeRMS | 0.0000 | 0.0000 | +0.00 |
| XZ | pRMS | 0.0000 | 0.0000 | +0.00 |
| XZ | yawMAE | 0.0000 | 0.0000 | +0.00 |
| XZ | yawRMS | 0.0000 | 0.0000 | +0.00 |
| XZ | yawP95 | 0.0000 | 0.0000 | +0.00 |
| XZ | pitchMAE | 0.1214 | 0.1214 | +0.00 |
| XZ | pitchRMS | 0.1769 | 0.1769 | +0.00 |
| XZ | pitchP95 | 0.4024 | 0.4024 | +0.00 |
| XZ | pathCTE | 0.3953 | 0.3953 | +0.00 |
| H | tildeMAE | 0.4619 | 0.3415 | -26.06 |
| H | tildeRMS | 0.5538 | 0.4376 | -20.99 |
| H | pRMS | 2.7611 | 2.1700 | -21.41 |
| H | yawMAE | 0.1748 | 0.1747 | -0.06 |
| H | yawRMS | 0.2041 | 0.2043 | +0.07 |
| H | yawP95 | 0.3493 | 0.3507 | +0.40 |
| H | pitchMAE | 0.0413 | 0.0411 | -0.33 |
| H | pitchRMS | 0.0712 | 0.0711 | -0.11 |
| H | pitchP95 | 0.1000 | 0.0991 | -0.99 |
| H | pathCTE | 0.2304 | 0.2301 | -0.16 |

## Gate table

| Gate | Result | Detail |
|------|:------:|--------|
| Deterministic (2-rep) | YES | base=YES cand=YES |
| R10 tildeRMS or pRMS improve >=10% | YES | d_tilde=-20.99% d_p=-21.41% |
| Yaw MAE/RMS/p95 regress <=2% | YES | d%=-0.06/0.07/0.40 |
| Pitch MAE/RMS/p95 <=2% + prior abs | YES | X/XZ/H abs+reg |
| Path metrics regress <=2% | YES | X/XZ/H mean/max/rms CTE |
| Rudder RMS/rate/near/sat<=2%; full sat<=1% | YES | rms +0.01% rate +0.30% full 0.67->0.67 |
| X/XZ roll clean | YES | tildeMAE<=0.05 pRMS<=0.5 |

## Changed files

- `controller_law.m` — optional p; dr_damp=g_ac*(-Kp_roll*p); dbg
- `continuous_path_tracking.m` — pass BODY p=state(10); rudder suite logs
- `run_roll_production_closure.m` — this driver

## Decision

- Verdict: **PASS**
- Next: `freeze_roll_production`
- Detail: PRODUCTION CLOSURE PASS at Kp_roll=0.605072 s: R10 roll improved (d_tildeRMS=-20.99%, d_pRMS=-21.41%); yaw/pitch/path/actuator gates held; X/XZ clean; deterministic. Promote and FREEZE roll damping in production.
- Production: PROMOTION FROZEN (roll damp retained)

## Feedback

- PASS/FAIL: **PASS**
- Old->new: yaw-PD only -> yaw-PD + g_ac*(-0.605072*p); Kphi=0
- Provenance: YAW_ROLL_DAMPING_BACKOFF PASS (TUNED Kp2)
- R10 tildeRMS 0.5538->0.4376 (-20.99%); pRMS 2.7611->2.1700 (-21.41%)
- Yaw d% MAE/RMS/p95: -0.06 / 0.07 / 0.40
- Next: freeze_roll_production
- Evidence: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.png`
