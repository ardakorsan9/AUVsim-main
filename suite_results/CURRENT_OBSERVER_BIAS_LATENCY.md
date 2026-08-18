# CURRENT_OBSERVER_BIAS_LATENCY_001 — Offline INS/DVL bias+latency audit

**Overall verdict: PASS** (declared synthetic bias+latency case only; not hardware)

## Provenance

- Read-only: `run_current_observer_noise.m`, `suite_results/CURRENT_OBSERVER_NOISE.mat`, `suite_results/BOUNDED_CURRENT_HOOK.mat`
- Noise-only observer: **PASS**; production + current hook: **FROZEN / UNTOUCHED**
- Driver: `run_current_observer_bias_latency.m` (one invocation)
- Observer fed to guidance/control: **NO** (offline only)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_BIAS_LATENCY.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_BIAS_LATENCY.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_BIAS_LATENCY.png`
- Did **not** touch `CODEX_VERTICAL_PLAN.md`
- Never claim hardware validation

## Bias+latency case (TEST ASSUMPTION — not hardware spec)

```
Noise retained: INS σ=0.020 @ 20 Hz ZOH; DVL σ=0.010 @ 5 Hz ZOH; rng(42)
INS  Vg_NED  bias=[+0.010, -0.005, +0.005] m/s, latency=50 ms
DVL  Vw_BODY bias=[+0.005, +0.000, -0.003] m/s, latency=200 ms
Delay: causal timestamp/ZOH (use last update with t_u <= t - latency)
Rotate delayed DVL with CURRENT truth R (SIMPLIFYING ASSUMPTION)
y_c = Vg_delayed_NED - R_current * Vw_delayed_BODY
```

### SIMPLIFYING ASSUMPTION (documented)

SIMPLIFYING ASSUMPTION: delayed DVL BODY sample is rotated into NED using the CURRENT truth attitude R(t), not R(t-latency). This decouples attitude latency from DVL velocity latency for this declared synthetic case only; not a hardware claim.

## Observer (unchanged)

- wo=0.50 rad/s, Vhat(0)=0, bound ±0.5 m/s — **no tuning**
- Steady window: t >= 10.0 s (post ~5/wo)
- True Vc = [0.00, 0.15, 0.00] m/s NED; U=1.5 m/s

## Per-route metrics (bias+latency vs noise-only)

| Route | bias||mean|| | RMSE_ss | p95_ss | max_ss | final||err|| | settle [s] | hits | noise bias | Δbias | PASS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| X | 8.9636e-03 | 9.9530e-03 | 1.3499e-02 | 1.4875e-02 | 1.0866e-02 | Inf | 0 | 1.410e-03 | 7.553e-03 | YES |
| XZ | 7.8878e-03 | 8.6337e-03 | 1.1479e-02 | 1.3039e-02 | 9.3543e-03 | Inf | 0 | 2.355e-03 | 5.532e-03 | YES |
| R10 | 1.2496e-02 | 1.7361e-02 | 2.6734e-02 | 2.8703e-02 | 1.8591e-02 | Inf | 0 | 1.646e-03 | 1.085e-02 | YES |

### Component steady bias (noise → bias+latency)

| Route | bl_N | bl_E | bl_D | noise_N | noise_E | noise_D | ΔN | ΔE | ΔD |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| X | 4.782e-03 | -4.065e-03 | 6.400e-03 | -1.631e-04 | 6.205e-04 | -1.256e-03 | 4.945e-03 | -4.686e-03 | 7.656e-03 |
| XZ | 2.435e-03 | -3.868e-03 | 6.429e-03 | -2.026e-03 | 3.999e-04 | 1.133e-03 | 4.460e-03 | -4.268e-03 | 5.295e-03 |
| R10 | 7.184e-03 | -6.906e-03 | 7.539e-03 | 1.095e-03 | -1.225e-03 | -1.019e-04 | 6.090e-03 | -5.681e-03 | 7.641e-03 |

### Innovation mean / lag-1 autocorrelation (steady)

| Route | innov||mean|| | mean_N | mean_E | mean_D | acorr_N | acorr_E | acorr_D |
|---|---:|---:|---:|---:|---:|---:|---:|
| X | 1.476e-01 | 4.538e-03 | 1.473e-01 | 8.008e-03 | 0.621 | 0.620 | 0.575 |
| XZ | 1.459e-01 | 2.546e-03 | 1.457e-01 | 6.469e-03 | 0.561 | 0.527 | 0.601 |
| R10 | 1.435e-01 | 7.180e-03 | 1.431e-01 | 7.700e-03 | 0.592 | 0.649 | 0.540 |

## Attitude / R10 rotation sensitivity

| Route | psi range [deg] | theta range [deg] | bias | RMSE |
|---|---:|---:|---:|---:|
| X | [-8.31, 1.94] | [-1.82, 0.82] | 8.964e-03 | 9.953e-03 |
| XZ | [-8.94, 2.10] | [-24.63, -19.76] | 7.888e-03 | 8.634e-03 |
| R10 | [90.72, 505.06] | [-4.48, -1.14] | 1.250e-02 | 1.736e-02 |

- R10−X Δbias=3.532e-03, ΔRMSE=7.408e-03; R10−XZ Δbias=4.608e-03, ΔRMSE=8.727e-03
- Delayed DVL BODY is rotated by CURRENT truth R → NED innovation is attitude-dependent even with constant BODY bias. R10 (large ψ swing) maps fixed BODY DVL bias through a rotating frame → time-varying NED bias contribution; X/XZ nearly constant attitude → nearer to static NED bias. INS NED bias is attitude-independent. Latency adds causal phase lag on both channels.

## Raw delayed timestamps / innovations saved

- Per route in `.mat`: `innovation`, `innovation_t`,
  `t_ins_src`, `t_ins_avail`, `t_dvl_src`, `t_dvl_avail`,
  `t_ins_updates`, `t_dvl_updates`, `n_ins`, `n_dvl`

## Limitations

Certifies THIS declared synthetic bias+latency case only (INS bias=[+0.010,-0.005,+0.005]@50ms, DVL bias=[+0.005,0,-0.003]@200ms, rng(42) noise retained, causal ZOH delay, CURRENT-truth-R on delayed DVL). Attitude error, frame misalignment, and lever-arm are DEFERRED. Not hardware validation. Observer never fed to guidance/control; do not promote to production.

## PASS gates

| Gate | Result |
|---|---|
| steady_vector_bias_le_0p030 | PASS |
| steady_vector_rmse_le_0p035 | PASS |
| p95_le_0p070 | PASS |
| final_err_le_0p050 | PASS |
| bounded_no_hits | PASS |
| all_routes | PASS |
| offline_not_in_loop | PASS |
| production_hook_untouched | PASS |
| same_wo_no_tuning | PASS |
| noise_was_pass | PASS |

**Overall: PASS**

## Next bounded gate

- **`combined_nonlinear_6dof_disturbance_regression_baseline`**
- Bias/latency PASS → next bounded gate: combined nonlinear 6DOF disturbance regression baseline (still offline / not production). Never feed observer to control; never promote to production.
- Do **not** feed observer to control; do **not** promote to production.
