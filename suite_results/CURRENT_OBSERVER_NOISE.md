# CURRENT_OBSERVER_NOISE_001 — Offline INS/DVL additive velocity-noise hook

**Overall verdict: PASS** (declared synthetic noise case only; not hardware)

## Provenance

- Read-only: `run_current_observer_ideal.m`, `suite_results/CURRENT_OBSERVER_IDEAL.mat`, `suite_results/BOUNDED_CURRENT_HOOK.mat`
- Ideal observer: **PASS**; production + current hook: **FROZEN / UNTOUCHED**
- Driver: `run_current_observer_noise.m` (one invocation)
- Observer fed to guidance/control: **NO** (offline only)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_NOISE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_NOISE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_NOISE.png`
- Did **not** touch `CODEX_VERTICAL_PLAN.md`
- Never claim hardware validation

## Noise case (TEST ASSUMPTION — not hardware spec)

```
INS  Vg_NED  : white noise σ=0.020 m/s/axis @ 20 Hz ZOH
DVL  Vw_BODY : white noise σ=0.010 m/s/axis @ 5 Hz ZOH
Independent; bias=0; delay=0; rng(42)
Rotate noisy DVL with truth R; y_c = Vg_noisy - R*Vw_noisy
```

## Observer (unchanged)

- wo=0.50 rad/s, Vhat(0)=0, bound ±0.5 m/s — **no tuning**
- Steady window: t >= 10.0 s (post ~5/wo)
- True Vc = [0.00, 0.15, 0.00] m/s NED; U=1.5 m/s

## Per-route metrics (noisy vs ideal)

| Route | bias||mean|| | RMSE_ss | p95_ss | final||err|| | settle [s] | hits | ideal final | Δfinal | PASS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| X | 1.4102e-03 | 4.5079e-03 | 7.3491e-03 | 4.8865e-03 | Inf | 0 | 1.851e-05 | 4.868e-03 | YES |
| XZ | 2.3553e-03 | 4.4048e-03 | 6.7750e-03 | 2.4505e-03 | 21.600 | 0 | 2.505e-06 | 2.448e-03 | YES |
| R10 | 1.6462e-03 | 5.3153e-03 | 1.0763e-02 | 4.8809e-03 | Inf | 0 | 2.538e-11 | 4.881e-03 | YES |

### Component steady bias / RMS / max (noisy)

| Route | bias_N | bias_E | bias_D | rms_N | rms_E | rms_D | max_N | max_E | max_D |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| X | -1.631e-04 | 6.205e-04 | -1.256e-03 | 2.194e-03 | 2.504e-03 | 3.039e-03 | 5.961e-03 | 6.631e-03 | 7.420e-03 |
| XZ | -2.026e-03 | 3.999e-04 | 1.133e-03 | 3.164e-03 | 1.299e-03 | 2.775e-03 | 7.550e-03 | 3.168e-03 | 6.831e-03 |
| R10 | 1.095e-03 | -1.225e-03 | -1.019e-04 | 3.092e-03 | 3.649e-03 | 2.320e-03 | 7.509e-03 | 1.321e-02 | 8.609e-03 |

## Attitude / route dependence

| Route | psi range [deg] | theta range [deg] |
|---|---:|---:|
| X | [-8.31, 1.94] | [-1.82, 0.82] |
| XZ | [-8.94, 2.10] | [-24.63, -19.76] |
| R10 | [90.72, 505.06] | [-4.48, -1.14] |

- DVL BODY noise rotated by truth R → NED innovation cov is attitude-dependent; R10 (large ψ swing) should differ from X/XZ. INS noise already in NED is attitude-independent. Ideal y_c≡Vc; noisy y_c = Vc + n_ins - R*n_dvl (zero bias/delay case).

## Raw innovations saved

- Per route: `innovation` (= noisy y_c), `innovation_t` (sim timestamps),
  `t_ins_updates`, `t_dvl_updates`, `n_ins`, `n_dvl` in `.mat`

## Limitations

Certifies THIS declared synthetic noise case only (INS σ=0.020@20Hz ZOH, DVL σ=0.010@5Hz ZOH, rng(42), zero bias/delay, truth-R rotation). Sensor bias, latency, lever-arm, and frame misalignment are DEFERRED. Not hardware validation. Observer never fed to guidance/control; do not promote to production.

## PASS gates

| Gate | Result |
|---|---|
| mean_vector_bias_le_0p010 | PASS |
| steady_vector_rmse_le_0p025 | PASS |
| p95_le_0p050 | PASS |
| final_err_le_0p030 | PASS |
| bounded_no_hits | PASS |
| all_routes | PASS |
| offline_not_in_loop | PASS |
| production_hook_untouched | PASS |
| same_wo_no_tuning | PASS |
| ideal_was_pass | PASS |

**Overall: PASS**

## Next bounded gate

- **`bias_latency_audit_INS_DVL`**
- Noise PASS → next bounded gate: ONE bias/latency audit on the INS/DVL pair (still offline). Never feed observer to control; never promote to production.
- Do **not** feed observer to control; do **not** promote to production.
