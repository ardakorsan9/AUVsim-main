# CURRENT_OBSERVER_IDEAL_001 — Ideal-signal INS−DVL current observer

**Overall verdict: PASS** (math/plumbing only; not hardware; not noise robustness)

## Provenance

- Read-only: `underwater777_vehicle_dynamics_current.m`, `run_bounded_current_hook.m`, `suite_results/BOUNDED_CURRENT_HOOK.md`
- Trajectories: `suite_results/BOUNDED_CURRENT_HOOK.mat` (hook PASS; Vc=[0,+0.15,0] NED)
- Driver: `run_current_observer_ideal.m` (one invocation)
- Production plant/controller/guidance: **UNTOUCHED**
- Current hook: **UNTOUCHED**
- Observer fed to guidance/control: **NO** (offline only)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_IDEAL.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_IDEAL.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_IDEAL.png`
- Did **not** touch `CODEX_VERTICAL_PLAN.md`
- Never claim hardware validation

## Frames / units (exact)

```
nu_lin   : ground-relative BODY linear velocity [m/s]
Vc       : constant ocean current, NED [m/s]
R        : BODY→NED rotation (ZYX Euler)
INS      : Vg_NED = R * nu_lin              [m/s NED]
DVL      : Vw_BODY = nu_r_lin               [m/s BODY]
           Vw_NED  = R * Vw_BODY            [m/s NED]
y_c      : Vg_NED - Vw_NED  (= Vc ideal)    [m/s NED]
observer : dVhat/dt = wo*(y_c - Vhat)
           wo = 0.50 rad/s, Vhat(0)=0, axis bound ±0.5 m/s
           discrete: Vhat ← Vhat + (1-e^{-wo dt})(y_c-Vhat); then clamp
```

## Observer config

- Fixed wo=0.50 rad/s (no gain sweep)
- Vhat(0)=[0,0,0] m/s NED
- Bound ±0.5 m/s each axis
- Noise: none (ideal signals)
- True Vc = [0.00, 0.15, 0.00] m/s NED; U=1.5 m/s

## Per-route metrics

| Route | id residual max | err_N final | err_E final | err_D final | ||err|| final | ||err|| RMS | ||err|| max | 2% settle [s] | bound hits | PASS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| X | 4.441e-16 | 2.610e-17 | -1.851e-05 | 4.524e-19 | 1.851e-05 | 3.513e-02 | 1.481e-01 | 7.825 | 0 | YES |
| XZ | 6.661e-16 | -8.559e-18 | -2.505e-06 | 1.797e-18 | 2.505e-06 | 3.178e-02 | 1.481e-01 | 7.825 | 0 | YES |
| R10 | 5.274e-16 | 2.027e-17 | -2.538e-11 | 7.981e-20 | 2.538e-11 | 2.222e-02 | 1.481e-01 | 7.825 | 0 | YES |

## Attitude exercise (route dependence context)

| Route | psi range [deg] | theta range [deg] |
|---|---:|---:|
| X | [-8.31, 1.94] | [-1.82, 0.82] |
| XZ | [-8.94, 2.10] | [-24.63, -19.76] |
| R10 | [90.72, 505.06] | [-4.48, -1.14] |

- Under ideal INS+DVL, y_c ≡ Vc in NED for any attitude; observer FO dynamics therefore route-independent aside from sampling. R10 rotating attitude exercises R(·) plumbing without changing y_c.

## Observability limitations

Ideal algebraic pair requires BOTH ground velocity (INS) and water-relative velocity (DVL) in consistent frames; missing either channel leaves Vc unobservable from kinematics alone. Attitude enters only via R; with perfect nu and nu_r, R cancels and y_c=Vc exactly. This certifies math/plumbing only — sensor noise, bias, latency, lever-arm, and frame misalignment are NOT tested. Do not promote to production guidance/control.

## PASS gates (math/plumbing)

| Gate | Result |
|---|---|
| identity_residual_le_1e10 | PASS |
| final_vector_err_le_0p005 | PASS |
| settle_2pct_le_10s | PASS |
| bounded_no_hits | PASS |
| all_routes | PASS |
| offline_not_in_loop | PASS |
| production_hook_untouched | PASS |
| no_noise_no_sweep | PASS |

**Overall: PASS**

## Next bounded gate

- **`measurement_noise_hook_INS_DVL_pair`**
- Next bounded gate: documented additive measurement-noise hook on the conceptual INS ground-velocity / DVL water-velocity pair, then re-run observer sensitivity (still offline). Never promote observer to production yet.
- Do **not** promote to production.
