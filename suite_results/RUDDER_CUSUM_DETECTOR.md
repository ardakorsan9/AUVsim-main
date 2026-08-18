# RUDDER_CUSUM_DETECTOR

**TASK_ID:** RUDDER_CUSUM_DETECTOR_001
**Date:** 2026-08-06 08:02:30
**Coverage verdict:** **PASS**

One-sided CUSUM on frozen B2 residual. No NL rerun. B2/G_nom **unchanged**. Production **frozen**. Applied rudder forbidden.

## Sources (read-only, ≤3)

1. `suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.mat`
2. `suite_results/SPEED_ENVELOPE_AUDIT.mat`
3. `suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.md`

## Seed split (published, disjoint)

| Set | Seeds | N | Role |
|---|---|---:|---|
| TRAIN | 2101:2120 | 20 | calibrate κ,h on nominal+corruption only |
| VAL | 3101:3140 | 40 | unseen-nominal FA + 9-cell noisy fault replay |

- Policy: `fixed published TRAIN=2101:2120 VAL=3101:3140 (twister); disjoint`
- Disjoint from prior stress 1001:1040: **YES**

## Equations / units

```
r_B2 = max(0, 1 - r/(max(u,u_floor)^2 * delta_r_cmd) / G_nom)  [frac]
q_k = max(0, q_{k-1} + r_B2,k - kappa) when gated; else q_k=0 (reset)
alarm if q_k > h; latch until reset; warmup t<=t_warmup: no accumulate
```

| Symbol | Units |
|---|---|
| r_B2 | dimensionless frac-loss proxy |
| κ (kappa) | same as r_B2 (frac) |
| h | CUSUM score (frac·samples) |
| q | CUSUM score (frac·samples) |
| G_nom | 1/(m^2·rad) |
| r, u, δr_cmd | rad/s, m/s, rad |

## Frozen B2 (unchanged) + calibrated CUSUM

| Item | Value |
|---|---:|
| G_nom [1/(m^2·rad)] | 0.851915 |
| thr_B2 [frac] (comparator only) | 0.277140 |
| \|δr\|_gate [deg] | 1.0 |
| u_floor [m/s] | 0.30 |
| Warmup | t > 5.0 s |
| B2 Np (comparator) | 10 |
| **κ (CUSUM)** | **0.066156** |
| **h (CUSUM)** | **11.066456** |
| B2/G_nom altered | NO |
| Retuned B2 | NO |

### Selection rule (TRAIN only)

TRAIN only (all-U R10 pre-fault + declared corruption): kappa ∈ [μ0, p80(r_B2_gated)] grid; h := 1.5·max_q_train + 0.25; accept if train FA_latched_samples ≤ 1%; among accepted pick smallest kappa (Page H0 allowance + mild-shift sensitivity). Freeze before post-fault open.

- Nominal source: `coverage U=1.50 pre-fault (t<19.60s) | coverage U=1.75 pre-fault (t<19.45s) | coverage U=2.00 pre-fault (t<19.30s)`
- Train resid gated: n=34460 med=0.0000 mean=0.0662 p95=0.2769 max=0.4135
- Train FA_latched after freeze: 0.0000% | train max q: 7.2110
- Accepted (κ,h) trials: 15

## No-leakage proof

| Check | Result |
|---|:---:|
| Calibrated on fault post-t_f | NO |
| Used δr_app in detector | NO |
| Used η_r in detector | NO |
| Labels in detector update | NO |
| Train/val seeds disjoint | YES |
| κ,h frozen before fault open | YES |
| B2/G_nom altered | NO |

PHASE A used only pre-fault (t<t_f) streams + TRAIN seeds to select (kappa,h); cusum_cfg frozen; PHASE B then opened post-fault logs for VAL-seed noisy replay; fault labels / eta / delta_r_app used only in post-hoc scoring after replay; residual uses frozen G_nom unchanged.

## Declared sensor corruption (VAL/TRAIN)

DVL: σ=0.010 m/s @ 5 Hz ZOH, bias=+0.005 m/s, lat=200 ms (CURRENT_OBSERVER). IMU ASSUMED: σ=0.20 deg/s @ 100 Hz ZOH, bias=+0.05 deg/s, lat=50 ms.

## Unseen-nominal false alarms (VAL)

| U | FA_latched% | n_latched | n_post |
|---:|---:|---:|---:|
| 1.50 | 0.0000 | 0 | 23320 |
| 1.75 | 0.0000 | 0 | 23080 |
| 2.00 | 0.0000 | 0 | 22840 |
| **AGG** | **0.0000** | 0 | 69240 |

Gate FA_agg ≤ 1%: **YES**

## Per-cell CUSUM (VAL noisy replay)

| U | η | loss% | Pd | misses | med delay | p95 delay | preFA | cell |
|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| 1.50 | 0.75 | 25 | 100.0% (40/40) | 0 | 1.175 | 1.275 | 0 | PASS |
| 1.50 | 0.50 | 50 | 100.0% (40/40) | 0 | 0.500 | 0.525 | 0 | PASS |
| 1.50 | 0.25 | 75 | 100.0% (40/40) | 0 | 0.400 | 0.438 | 0 | PASS |
| 1.75 | 0.75 | 25 | 100.0% (40/40) | 0 | 1.025 | 1.150 | 0 | PASS |
| 1.75 | 0.50 | 50 | 100.0% (40/40) | 0 | 0.475 | 0.512 | 0 | PASS |
| 1.75 | 0.25 | 75 | 100.0% (40/40) | 0 | 0.400 | 0.425 | 0 | PASS |
| 2.00 | 0.75 | 25 | 100.0% (40/40) | 0 | 1.263 | 1.338 | 0 | PASS |
| 2.00 | 0.50 | 50 | 100.0% (40/40) | 0 | 0.550 | 0.588 | 0 | PASS |
| 2.00 | 0.25 | 75 | 100.0% (40/40) | 0 | 0.450 | 0.475 | 0 | PASS |

## B2 vs CUSUM (same VAL noise)

| U | η | CUSUM Pd | CUSUM p95 | B2 Pd | B2 p95 | B2 clean delay |
|---:|---:|---:|---:|---:|---:|---:|
| 1.50 | 0.75 | 100.0% | 1.275 | 15.0% | 8.850 | NaN |
| 1.50 | 0.50 | 100.0% | 0.525 | 100.0% | 0.375 | 0.375 |
| 1.50 | 0.25 | 100.0% | 0.438 | 100.0% | 0.375 | 0.375 |
| 1.75 | 0.75 | 100.0% | 1.150 | 47.5% | 23.894 | NaN |
| 1.75 | 0.50 | 100.0% | 0.512 | 100.0% | 0.375 | 0.375 |
| 1.75 | 0.25 | 100.0% | 0.425 | 100.0% | 0.375 | 0.325 |
| 2.00 | 0.75 | 100.0% | 1.338 | 77.5% | 2.550 | 2.550 |
| 2.00 | 0.50 | 100.0% | 0.588 | 100.0% | 0.375 | 0.375 |
| 2.00 | 0.25 | 100.0% | 0.475 | 100.0% | 0.375 | 0.300 |

## Coverage gates

| Gate | Result |
|---|:---:|
| Every cell Pd≥95% and p95 delay≤3 s | YES |
| Agg unseen-nominal FA≤1% | YES |
| **Coverage** | **PASS** |

## Next

- **`fault_isolation_safe_mode_requirements_audit`** — Coverage PASS → next: fault-isolation / safe-mode requirements audit; production remains frozen.

## Files

- `run_rudder_cusum_detector.m` (isolated runner + local stateful CUSUM)
- `suite_results/RUDDER_CUSUM_DETECTOR.md`
- `suite_results/RUDDER_CUSUM_DETECTOR.mat`
- `suite_results/RUDDER_CUSUM_DETECTOR.png`
- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.
