# BOUNDED_CURRENT_HOOK_001 — Bounded constant-current plant hook

**Overall verdict: PASS** (hook correctness, not robustness; not hardware)

## Provenance

- Read-only: `underwater777_vehicle_dynamics.m`, `continuous_path_tracking.m`, `suite_results/SENSOR_NOISE_CURRENT_AUDIT.md`
- Hook (NEW, isolated): `underwater777_vehicle_dynamics_current.m`
- Driver: `run_bounded_current_hook.m` (one invocation)
- Production plant/controller/guidance/config: **UNTOUCHED**
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\BOUNDED_CURRENT_HOOK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\BOUNDED_CURRENT_HOOK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\BOUNDED_CURRENT_HOOK.png`
- Did **not** touch `CODEX_VERTICAL_PLAN.md`
- Never claim hardware validation

## Convention

```
nu     = ground-relative BODY velocity (state)
Vc     = constant NED current [m/s]  (global plant_Vc)
nu_c   = R'*Vc   (BODY linear; omega_c=0)
nu_r   = nu - nu_c
eta_dot= R*nu     (KEEP ground kinematics)
hydro  = damping/lift/control-surface speed use nu_r
Coriolis choice: C(nu_r)*nu_r — linear-velocity Coriolis/AM
  cross terms use nu_r + absolute rates (Fossen irrotational)
```

## Vc=0 identity (exact deltas)

| Check | max|Δ| | tol | PASS |
|---|---:|---:|:---:|
| RHS prod vs hook(Vc=0) | 0.000000e+00 | 1e-12 | YES |
| Traj X state | 0.000000e+00 | 1e-9 | YES |
| Traj X pos/vel/ori/rate/act max | 0.000e+00 / 0.000e+00 / 0.000e+00 / 0.000e+00 / 0.000e+00 |
| Traj XZ state | 0.000000e+00 | 1e-9 | YES |
| Traj XZ pos/vel/ori/rate/act max | 0.000e+00 / 0.000e+00 / 0.000e+00 / 0.000e+00 / 0.000e+00 |
| Traj R10 state | 0.000000e+00 | 1e-9 | YES |
| Traj R10 pos/vel/ori/rate/act max | 0.000e+00 / 0.000e+00 / 0.000e+00 / 0.000e+00 / 0.000e+00 |

## Sign / units

- Vc NED = [0.00, 0.15, 0.00] m/s
- psi=0 → nu_c BODY = [0.0000, 0.1500, 0.0000]
- psi=+90° → nu_c BODY = [0.1500, 0.0000, 0.0000]
- psi=0 + East Vc => +v BODY; psi=+90deg + East Vc => +u BODY; eta_dot=R*nu (ground), hydro uses nu_r
- Sign/units gate: **YES**

## Dissipative drag (water-relative)

- Xuu=-1.62 Yvv=-1310 Zww=-131 (all <0)
- max nu_r·F_quad = -3.739500e+00 (expect ≤0): **YES**

## Baseline → current metrics @ U=1.5, Vc=[0,+0.15,0] NED

| Route | CTE_b | CTE_c | e_z_b | e_z_c | eθ_b° | eθ_c° | eψ_b° | eψ_c° | max|Δy| | nu_c_rms | finite |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| X | 0.2467 | 0.2557 | 0.2110 | 0.2110 | 0.1651 | 0.1784 | 0.0000 | 1.3393 | 0.1122 | 0.1500 | YES |
| XZ | 0.3953 | 0.3778 | 0.3106 | 0.2931 | 0.4928 | 0.4966 | 0.0000 | 1.2456 | 0.1154 | 0.1500 | YES |
| R10 | 0.2300 | 0.1751 | 0.2185 | 0.2027 | 0.1430 | 0.2469 | 1.1324 | 1.5535 | 0.3172 | 0.1500 | YES |

## Actuator RMS (baseline → current)

| Route | δe_b | δe_c | δr_b | δr_c | T_b | T_c |
|---|---:|---:|---:|---:|---:|---:|
| X | 0.0837 | 0.0829 | 0.0000 | 0.1028 | 6.034 | 6.071 |
| XZ | 0.0270 | 0.0288 | 0.0000 | 0.0992 | 7.359 | 7.395 |
| R10 | 0.0965 | 0.0976 | 0.1034 | 0.1887 | 4.871 | 4.784 |

## Robustness (reported separately; NOT a PASS gate)

Cross-current perturbs tracking (see Δ CTE / e_z / e_ψ). Frozen controller not retuned. Robustness FAIL does not fail this task.

## PASS gates (hook correctness)

| Gate | Result |
|---|---|
| vc0_rhs_identity | PASS |
| vc0_traj_identity | PASS |
| ned_body_sign_units | PASS |
| drag_dissipative | PASS |
| states_finite_bounded | PASS |
| current_effect_nonzero | PASS |
| production_untouched | PASS |
| no_estimator_tuning | PASS |

**Overall: PASS**

## Next

- **`INS_ground_minus_DVL_water_current_observer_ONLY`**
- Hook PASS exposes V_ground_ned and V_water_body; conceptual INS−DVL pair can observe Vc. Implement ONE isolated observer candidate next; no production retune. If observer unjustified in practice, fall back to measurement-noise hook.
- Conceptual pair: INS ground-velocity (R*nu) minus DVL water-rel (nu_r) => Vc estimate
- Production remains frozen.
