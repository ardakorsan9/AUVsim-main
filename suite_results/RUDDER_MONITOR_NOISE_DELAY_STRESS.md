# RUDDER_MONITOR_NOISE_DELAY_STRESS

**TASK_ID:** RUDDER_MONITOR_NOISE_DELAY_STRESS_001
**Date:** 2026-08-06 07:31:24
**Robustness verdict:** **PASS**
**Deployment certification:** **NOT_CERTIFIED**

Stress frozen causal B2 monitor via async sensor sampling / ZOH / noise / bias / latency replay. No nonlinear rerun. No threshold retune. Production cascade+guidance+plant **frozen**.

## Sources (read-only)

1. `isolated_online_rudder_residual_monitor.m`
2. `suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.mat`
3. `suite_results/CURRENT_OBSERVER_NOISE.md` + `CURRENT_OBSERVER_BIAS_LATENCY.md`
Replay streams: `feasibility.R.TN (HELIX_R10)` | `RUDDER_FAULT_BASELINE.mat`

## Frozen B2 parameters (NO retune)

| Item | Value |
|---|---:|
| G_nom [1/(m^2·rad)] | 0.851915 |
| thr_B2 [frac] | 0.277140 |
| \|δr\|_gate [deg] | 1.0 |
| u_floor [m/s] | 0.30 |
| Warmup | t > 5.0 s |
| Persistence | 0.25 s (Np=10 @ dt=0.025) |
| Retuned | NO |
| Forbidden to monitor | δr_app / η_r / fault labels |

## Input corruption parameters

### DVL surge u (REUSED from CURRENT_OBSERVER — exact)

```
DVL Vw_BODY-x: σ=0.010 m/s @ 5 Hz ZOH
bias = +0.005 m/s (BODY-x from [+0.005, 0, -0.003])
latency = 200 ms
Delay: causal timestamp/ZOH (last update with t_u <= t - latency)
```

### IMU yaw-rate r (**ASSUMED** stress envelope — NOT hardware spec)

ASSUMED stress envelope (NOT a hardware spec): IMU yaw-rate assumptions absent from CURRENT_OBSERVER noise/bias/latency reports; one conservative declared synthetic envelope for this stress only.

```
IMU r: σ=0.20 deg/s (= 3.490659e-03 rad/s) @ 100 Hz ZOH
bias = +0.05 deg/s (= +8.726646e-04 rad/s)
latency = 50 ms
Delay: causal timestamp/ZOH (same model as DVL)
```

- `delta_r_cmd`: known command — **not** corrupted.
- Channels independent; `causal_timestamp_ZOH`.
- Seeds: **fixed published list 1001:1040 (twister)** (N=40).

## Aggregate metrics

| Metric | Value | Gate | Result |
|--------|------:|------|:------:|
| Detection probability Pd | 100.0% (40/40) | ≥95% | YES |
| Delay median [s] | 0.375 | — | — |
| Delay p95 [s] | 0.387 | ≤3.0 | YES |
| Misses | 0 | — | — |
| Prefault alarms (fault runs) | 0 | — | — |
| Agg nominal FA latched samples | 0.0000% (0/64000) | ≤1% | YES |
| Agg nominal FA persist samples | 0.0000% | report | — |
| **Robustness** | **PASS** | all three | **YES** |
| **Deployment** | **NOT_CERTIFIED** | — | — |

### Residual distributions (gated)

| Pool | n | median | mean | p95 | max |
|------|--:|-------:|-----:|----:|----:|
| Nominal (all seeds) | 63840 | 0.0006 | 0.0682 | 0.2479 | 0.3717 |
| Fault post-t_f (all seeds) | 40680 | 0.5007 | 0.4760 | 0.5836 | 0.6288 |

## Per-seed table

| seed | FA_latched% | FA_persist% | detected | delay[s] | miss | prefault | resid_nom_med | resid_f_post_med |
|-----:|------------:|-------------:|:--------:|---------:|:----:|:--------:|--------------:|-----------------:|
| 1001 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5003 |
| 1002 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5010 |
| 1003 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5028 |
| 1004 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5009 |
| 1005 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0009 | 0.5012 |
| 1006 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0036 | 0.5041 |
| 1007 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0062 | 0.4996 |
| 1008 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0039 | 0.5001 |
| 1009 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5007 |
| 1010 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.4997 |
| 1011 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0012 | 0.4996 |
| 1012 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0008 | 0.5023 |
| 1013 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0015 | 0.5011 |
| 1014 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0016 | 0.5000 |
| 1015 | 0.000 | 0.000 | YES | 0.400 | NO | NO | 0.0034 | 0.5009 |
| 1016 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0016 | 0.4996 |
| 1017 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0053 | 0.5024 |
| 1018 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0012 | 0.4997 |
| 1019 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5006 |
| 1020 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5026 |
| 1021 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0007 | 0.5015 |
| 1022 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5021 |
| 1023 | 0.000 | 0.000 | YES | 0.400 | NO | NO | 0.0027 | 0.5022 |
| 1024 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0043 | 0.5020 |
| 1025 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5040 |
| 1026 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0030 | 0.5006 |
| 1027 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0082 | 0.4995 |
| 1028 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5012 |
| 1029 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0017 | 0.4993 |
| 1030 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0017 | 0.5012 |
| 1031 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0020 | 0.5006 |
| 1032 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.4996 |
| 1033 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0007 | 0.5014 |
| 1034 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.4989 |
| 1035 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5004 |
| 1036 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.4997 |
| 1037 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.5006 |
| 1038 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0060 | 0.5017 |
| 1039 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0015 | 0.4986 |
| 1040 | 0.000 | 0.000 | YES | 0.375 | NO | NO | 0.0000 | 0.4997 |

## Clean reference (no corruption)

- Isolated-monitor clean delay=0.375 s, FA_latched=0.000% (from prior MAT).

## Deployment NOT_CERTIFIED reasons

- Single path only (HELIX_R10)
- Single speed only (U≈1.5 m/s)
- Single current condition (fault-baseline / feasibility traj)
- Single fault magnitude only (eta_r:1→0.50)
- IMU yaw-rate envelope ASSUMED (not hardware-validated)
- Synthetic DVL corruption from CURRENT_OBSERVER docs (not hardware)

## Next

- **`fault_magnitude_speed_coverage`** — Robustness PASS → next: fault-magnitude/speed coverage; deployment still NOT_CERTIFIED.

## Files

- `run_rudder_monitor_noise_delay_stress.m` (isolated runner)
- `suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.md`
- `suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.mat`
- `suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.png`
- Monitor: `isolated_online_rudder_residual_monitor.m` (untouched)
- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.
