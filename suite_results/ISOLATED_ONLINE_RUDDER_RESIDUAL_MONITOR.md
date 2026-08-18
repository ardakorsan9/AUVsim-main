# ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR

**TASK_ID:** ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR_001
**Date:** 2026-08-06 07:21:53
**Functional verdict:** **PASS**
**Deployment certification:** **NOT_CERTIFIED**

Isolated stateful causal online B2 rudder-health monitor. No nonlinear rerun. Production cascade+guidance+plant **frozen**.

## Sources (3 only)

1. `suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.md`
2. `suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.mat` (frozen G_nom/thr/gate/persist)
3. `suite_results/RUDDER_FAULT_BASELINE.mat` (fault replay log)

## Monitor (B2 primary)

```
g_hat = r_IMU / (max(u_DVL,u_floor)^2 * delta_r_cmd)
r_B2 = max(0, 1 - g_hat/G_nom)  % dimensionless
alarm if r_B2>thr for Np consecutive gated samples → LATCH until reset
```

| Item | Value |
|---|---:|
| G_nom [1/(m^2·rad)] | 0.851915 |
| thr_B2 [frac] | 0.277140 |
| \|δr\|_gate [deg] | 1.0 |
| u_floor [m/s] | 0.30 |
| Warmup | t > 5.0 s |
| Persistence | 0.25 s (Np=10 @ dt=0.025) |
| Retuned | NO |
| Inputs | δr_cmd (known) + r (IMU) + u (DVL) only |
| Forbidden | δr_app / η_r / fault labels / INS xy |

## Online behavior

- Sequential sample-by-sample `update`; causal (no future samples).
- Warmup: t≤5.0s → counter=0, no alarm.
- Gate: |δr_cmd|≤1.0° → counter reset.
- NaN/dropout on t/δr/r/u → residual=NaN, counter reset, no latch step.
- Persistence counter increments only on gated exceedance; else resets.
- Alarm latches on Np consecutive exceedances until `reset`.
- Units: δr [rad], r [rad/s], u [m/s], residual dimensionless.
- Reset API smoke: **YES**

## Replay scoring (labels post-hoc only)

| Gate | Result | Detail |
|------|:------:|--------|
| Nominal FA ≤1% (B2 persist) | YES | 0.000% (offline 0.000%) |
| Latched FA after warmup ≤1% | YES | 0.000% |
| Detection ≤3 s | YES | delay=0.375 s |
| No alarm before fault | YES | — |
| Parity with offline B2 | YES | Δdelay=0.000e+00s max|resid|=0.000e+00 |
| **Functional** | **PASS** | — |
| **Deployment** | **NOT_CERTIFIED** | see reasons |

### Deployment NOT_CERTIFIED reasons

- Sensor noise/delay NOT_IMPLEMENTED / untested on this monitor
- Other speeds / paths / currents untested (single R10@U=1.5 traj)
- Other fault magnitudes untested (only eta_r:1→0.50)
- ASSUMED-direct plant truth mapped to IMU/DVL; not real sensors

Functional PASS (if any) is replay-parity only; deployment remains NOT_CERTIFIED until robustness stress + broader coverage.

## Next

- **`bounded_synthetic_noise_delay_robustness_stress`** — Functional PASS → next: bounded synthetic noise/delay robustness stress; deployment still NOT_CERTIFIED.

## Files

- `isolated_online_rudder_residual_monitor.m` (monitor)
- `run_isolated_online_rudder_residual_monitor.m` (isolated runner)
- `suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.md`
- `suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.mat`
- `suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.png`
- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.
