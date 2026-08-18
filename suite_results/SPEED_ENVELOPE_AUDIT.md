# SPEED_ENVELOPE_AUDIT_001 — Production nonlinear 6DOF speed envelope audit

**Overall verdict (audit completeness): PASS**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_CONTROL_RESEARCH_LOG.md`
- Driver: `run_speed_envelope_audit.m` (one invocation; no production edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_ENVELOPE_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_ENVELOPE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_ENVELOPE_AUDIT.png`
- Seed: 0 | Kp_roll frozen=0.605072 | Kp_x=25 | thrust_trim=13.4 N (production)
- Production: nonlinear theta/q cascade + climb FF frozen; gamma INDI/PI/ADRC rejected

## Rejected gamma methods (context)

| Method | Decision |
|--------|----------|
| Direct incremental gamma-INDI | REJECT_DIRECT_INDI_SCAFFOLD |
| Outer gamma-PI on theta/q | REJECT_OUTER_GAMMA_PI_SCAFFOLD |
| Outer gamma LADRC on theta/q | REJECT_OUTER_GAMMA_ADRC_SCAFFOLD |

## Preserved yaw-envelope conclusions (not reopened)

- R=5 @1.5: **hard authority FAIL** (rudder sat ~95%)
- R=7.5 @1.5: **soft FAIL** (sat 1.06%, ratio 1.024)
- R=8 @1.5: soft FAIL (full sat 6.67%, ratio 1.0236)
- R=10 @1.5: **PASS** (comfortable); this grid uses R10 only

## Hard gates (absolute; no extrapolate)

```
FEASIBLE iff: trim residual documented (+ X/XZ norm_dyn<=0.01),
  states bounded, pitch/gamma/yaw hard gates, actuator/rate limits pass.
X:  pitch MAE<=0.10 p95<=0.50 | gamma MAE<=0.50 p95<=1.00
XZ: pitch MAE<=0.30 p95<=0.50 | gamma MAE<=1.00 p95<=1.50
H:  pitch MAE<=0.30 p95<=0.50 | gamma MAE<=1.50 p95<=2.50
    yaw MAE<=1.00 p95<=2.00 | rud sat ss/full<=1% | ratio[0.98,1.02] | chat<=0.20
Act: elev/thrust sat<=1% | rate util de/dr <= 100% of 40 deg/s
```

## Grid results

| Route | Uref | TrimNorm | FEAS | First limit | uMAE | uP95 | thMAE | thP95 | gMAE | gP95 | yawMAE | CTE | deSat% | drSatF% | deRateU | thrSat% | chat | bound |
|-------|-----:|---------:|:----:|-------------|-----:|-----:|------:|------:|-----:|-----:|-------:|----:|-------:|--------:|--------:|--------:|-----:|:-----:|
| X | 1.00 | 3.57e-11 | YES | none | 0.3174 | 0.3188 | 0.0403 | 0.0630 | 0.3779 | 0.8278 | 0.0000 | 0.250 | 0.00 | 0.00 | 0.005 | 0.00 | 0.1614 | YES |
| X | 1.25 | 2.76e-13 | YES | none | 0.3175 | 0.3188 | 0.0135 | 0.0239 | 0.3496 | 0.7550 | 0.0000 | 0.248 | 0.00 | 0.00 | 0.005 | 0.00 | 0.1564 | YES |
| X | 1.50 | 2.73e-13 | YES | none | 0.3176 | 0.3188 | 0.0110 | 0.0419 | 0.3305 | 0.7032 | 0.0000 | 0.247 | 0.00 | 0.00 | 0.005 | 0.00 | 0.1530 | YES |
| X | 1.75 | 2.77e-14 | YES | none | 0.3176 | 0.3193 | 0.0264 | 0.0584 | 0.3182 | 0.6678 | 0.0000 | 0.246 | 0.00 | 0.00 | 0.005 | 0.00 | 0.1507 | YES |
| X | 2.00 | 1.76e-13 | YES | none | 0.3178 | 0.3203 | 0.0342 | 0.0637 | 0.3132 | 0.6546 | 0.0000 | 0.246 | 0.00 | 0.00 | 0.005 | 0.00 | 0.1498 | YES |
| XZ | 1.00 | 5.41e-16 | YES | none | 0.2547 | 0.2560 | 0.1369 | 0.4132 | 0.3597 | 0.7025 | 0.0000 | 0.365 | 0.00 | 0.00 | 0.005 | 0.00 | 0.1779 | YES |
| XZ | 1.25 | 7.2e-13 | YES | none | 0.2548 | 0.2563 | 0.1278 | 0.4071 | 0.3858 | 0.7081 | 0.0000 | 0.369 | 0.00 | 0.00 | 0.005 | 0.00 | 0.1869 | YES |
| XZ | 1.50 | 2.26e-13 | YES | none | 0.2550 | 0.2567 | 0.1214 | 0.4024 | 0.4182 | 0.7273 | 0.0000 | 0.372 | 0.00 | 0.00 | 0.006 | 0.00 | 0.1955 | YES |
| XZ | 1.75 | 9.96e-14 | YES | none | 0.2552 | 0.2573 | 0.1180 | 0.3967 | 0.4544 | 0.8212 | 0.0000 | 0.373 | 0.00 | 0.00 | 0.006 | 0.00 | 0.2032 | YES |
| XZ | 2.00 | 6.38e-13 | YES | none | 0.2555 | 0.2585 | 0.1197 | 0.4100 | 0.5048 | 0.9739 | 0.0000 | 0.373 | 0.00 | 0.00 | 0.006 | 0.00 | 0.2114 | YES |
| H | 1.00 | NaN | NO | rudder_sat_full(2.00%>1.00%) | 0.3956 | 0.4020 | 0.1063 | 0.2775 | 0.9493 | 1.3573 | 0.1513 | 0.358 | 0.00 | 2.00 | 0.006 | 0.00 | 0.1842 | YES |
| H | 1.25 | NaN | NO | rudder_sat_full(1.33%>1.00%) | 0.3827 | 0.4028 | 0.0745 | 0.2010 | 0.8706 | 1.4649 | 0.1528 | 0.314 | 0.00 | 1.33 | 0.006 | 0.00 | 0.1873 | YES |
| H | 1.50 | NaN | YES | none | 0.3494 | 0.3720 | 0.0411 | 0.0986 | 0.6584 | 1.3785 | 0.1740 | 0.269 | 0.00 | 0.67 | 0.006 | 0.00 | 0.1501 | YES |
| H | 1.75 | NaN | YES | none | 0.3124 | 0.3374 | 0.0447 | 0.2468 | 0.5385 | 1.2645 | 0.1973 | 0.239 | 0.00 | 0.33 | 0.006 | 0.00 | 0.1317 | YES |
| H | 2.00 | NaN | YES | none | 0.0952 | 0.1639 | 0.0714 | 0.3897 | 0.4794 | 1.2014 | 0.2023 | 0.206 | 0.00 | 0.17 | 0.034 | 0.00 | 0.1470 | YES |

## Contiguous certified speed ranges (grid only; never extrapolate)

| Route | Certified contiguous U | n | Worst margin |
|-------|------------------------|--:|-------------:|
| X | [1.00, 2.00] m/s (grid-contiguous; no extrapolate) | 5 | 0.05974 |
| XZ | [1.00, 2.00] m/s (grid-contiguous; no extrapolate) | 5 | 0.08684 |
| H | [1.50, 2.00] m/s (grid-contiguous; no extrapolate) | 3 | 0.001756 |
| Intersection | [1.50, 2.00] m/s | 3 | — |

- Worst-case margin across certified cells: **0.001756**

## Decision

- Audit completeness: **PASS**
- Envelope inadequate: NO
- Recommended next bounded gate: **`depth_outer_loop_baseline`**
- Detail: Speed envelope adequate on certified contiguous multi-route range. Recommend depth outer-loop baseline next (production cascade frozen).
- Reason: intersect=[1.50, 2.00] m/s worst_margin=0.001756
- Production: untouched

## Feedback

- PASS/FAIL: **PASS**
- Certified: X=[1.00, 2.00] m/s (grid-contiguous; no extrapolate) | XZ=[1.00, 2.00] m/s (grid-contiguous; no extrapolate) | R10=[1.50, 2.00] m/s (grid-contiguous; no extrapolate) | intersect=[1.50, 2.00] m/s
- Next: `depth_outer_loop_baseline`
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_ENVELOPE_AUDIT.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_ENVELOPE_AUDIT.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_ENVELOPE_AUDIT.png`
