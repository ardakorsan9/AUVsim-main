# PROPULSION_POWER_COMPUTE_PARITY_FIX_RESUME_001

**Verdict: PASS** — Gate6 attempt2 RESUMED (this is not attempt3).

- Marker: `PROPULSION_POWER_COMPUTE_PARITY_FIX_RESUME_001`
- Simulation-only, **NOT_CERTIFIED**. Gate4 remains **shadow-only**.
- MATLAB pid: 15892 (single process after resume). Wall time: 630.3 s.

## Recovery provenance

| Record | State | Preserved |
|---|---|---|
| attempt1 | **FAIL**, shadow-only: local X/XZ loop incomparable to frozen `SPEED_ENVELOPE_AUDIT`; two MATLAB starts | yes, not reopened |
| attempt2 (interrupted) | host-power/bridge loss. `continuous_path_tracking_propulsion.m` created and marker-verified; driver absent; **no MATLAB process had been started** | yes, recorded |
| this resume | completed the driver and used one MATLAB invocation | — |

- Reason the resume is not attempt3: no MATLAB run existed in attempt2, so no attempt2 result was consumed or replaced. The clone from attempt2 is reused byte-for-byte.
- Clone check: clone reduces byte-for-byte to continuous_path_tracking.m (233 lines; 18 marker lines)

## Sources read (exactly three; no repo scan)

1. `continuous_path_tracking_propulsion.m` (attempt2 clone)
2. `run_speed_envelope_audit.m` (frozen accepted harness definitions)
3. `suite_results/SPEED_ENVELOPE_AUDIT.mat` (accepted reference: task=SPEED_ENVELOPE_AUDIT_001, verdict=PASS)

## Gate ledger

| Gate | Result | Detail |
|---|:---:|---|
| `G_single_matlab` | **PASS** | pid=15892 prior_lock=0 () |
| `G_clone_minimal_diff` | **PASS** | clone reduces byte-for-byte to continuous_path_tracking.m (233 lines; 18 marker lines) |
| `G_accepted_set_consistent` | **PASS** | all declared accepted cells FEASIBLE in frozen MAT |
| `G_parity_accepted_baseline` | **PASS** | cells=8 exact=1 within_tol(1e-12)=1 max_sig_diff=0.000e+00 |
| `G_production_plan_fingerprints` | **PASS** | 9 files byte-identical before/after (SHA-256) |
| `G_finite_states` | **PASS** | 32 runs, all finite+bounded=1 |
| `G_frozen_tracking_actuator` | **PASS** | ideal-hook cells FEASIBLE=8/8; variant cells FEASIBLE=24/24 (variant loss is a RESULT, not a gate) |
| `G_thrust_limits` | **PASS** | realized thrust inside declared [T_min,T_max] for 32/32 runs; T_real span [0.710, 28.480] N |
| `G_battery_current_conditional` | **PASS** | CONDITIONAL on ASSUMED eta in [0.35,0.60] and V_bus {24  48} V: power/energy/current finite, non-negative, ordered for 32/32 runs. No certified limit is asserted. |
| `G_deterministic_replay` | **PASS** | X@1.00 variant=nominal bitwise_max_diff=0.000e+00 over 360 decimated samples |
| `G_pareto_reported` | **PASS** | 9 nondominated (variant,cell) points of 32 |
| `G_artifacts_readable` | **PASS** | MD/MAT/PNG re-opened and structurally verified in-process |

## Phase 1 — ideal-hook parity vs accepted MAT (tol 1e-12)

The accepted cells are re-run through the clone with `prop.ideal == true` (exact passthrough, no arithmetic on the command).

| Cell | Parity | max sig diff | max metric diff | worst field | FEAS match | first_limit match |
|---|:---:|---:|---:|---|:---:|:---:|
| X@1.00 | **EXACT** | 0.000e+00 | 0.000e+00 | `` | YES | YES |
| XZ@1.00 | **EXACT** | 0.000e+00 | 0.000e+00 | `` | YES | YES |
| X@1.50 | **EXACT** | 0.000e+00 | 0.000e+00 | `` | YES | YES |
| XZ@1.50 | **EXACT** | 0.000e+00 | 0.000e+00 | `` | YES | YES |
| H@1.50 | **EXACT** | 0.000e+00 | 0.000e+00 | `` | YES | YES |
| X@2.00 | **EXACT** | 0.000e+00 | 0.000e+00 | `` | YES | YES |
| XZ@2.00 | **EXACT** | 0.000e+00 | 0.000e+00 | `` | YES | YES |
| H@2.00 | **EXACT** | 0.000e+00 | 0.000e+00 | `` | YES | YES |

## Declared ASSUMED actuator variants (frozen before the run; no tuning)

| Variant | ideal | tau [s] | gain | slew [N/s] | T_min [N] | T_max [N] | Rationale |
|---|:---:|---:|---:|---:|---:|---:|---|
| `ideal` | 1 | 0.000 | 1.000 | Inf | -Inf | Inf | exact passthrough; parity hook against accepted audit |
| `nominal` | 0 | 0.300 | 1.000 | 8 | -100.000 | 300.000 | ASSUMED mid-range thruster lag/gain/slew |
| `slow_low` | 0 | 0.600 | 0.900 | 4 | -100.000 | 300.000 | ASSUMED slow lag, low gain, tight slew (worst dynamic corner) |
| `fast_high` | 0 | 0.150 | 1.100 | 16 | -100.000 | 300.000 | ASSUMED fast lag, high gain, loose slew (aggressive corner) |

Actuator chain (ASSUMED, declared, simulation-only): gain error, then exact-ZOH first-order lag, then slew-rate limit, then saturation.

## Component-neutral power / energy model

- `P_useful = max(T_real .* u_body, 0); P_in in [P_useful/eta_hi, P_useful/eta_lo]`
- eta_total in [0.35, 0.60] — ASSUMED total (prop x motor x drive) efficiency interval, simulation-only
- V_bus [24 48] V — ASSUMED DC bus voltages; current is CONDITIONAL on this assumption
- no regeneration credit: negative T*u clipped to zero for input energy
- No propeller, motor, ESC or battery part is identified; results are **ranges**, never point certifications.

## Phase 2 — variant results (frozen gates)

| Variant | Cell | FEAS | first limit | worst margin | uMAE | thMAE | gMAE | CTE | slew% | sat% | T_real span [N] | P_hi p95 [W] | E range [Wh] | I@24V | I@48V |
|---|---|:---:|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---:|---:|
| `ideal` | X@1.00 | YES | none | 0.05974 | 0.3174 | 0.0403 | 0.3779 | 0.250 | 0.00 | 0.00 | [5.43, 25.89] | 28.5 | [0.09, 0.16] | 1.2 | 0.6 |
| `ideal` | XZ@1.00 | YES | none | 0.08684 | 0.2547 | 0.1369 | 0.3597 | 0.365 | 0.00 | 0.00 | [7.00, 25.89] | 35.4 | [0.14, 0.23] | 1.5 | 0.7 |
| `ideal` | X@1.50 | YES | none | 0.08896 | 0.3176 | 0.0110 | 0.3305 | 0.247 | 0.00 | 0.00 | [5.43, 13.39] | 28.5 | [0.09, 0.15] | 1.2 | 0.6 |
| `ideal` | XZ@1.50 | YES | none | 0.09762 | 0.2550 | 0.1214 | 0.4182 | 0.372 | 0.00 | 0.00 | [6.98, 13.39] | 35.4 | [0.13, 0.22] | 1.5 | 0.7 |
| `ideal` | H@1.50 | YES | none | 0.001756 | 0.3494 | 0.0411 | 0.6584 | 0.269 | 0.00 | 0.00 | [3.95, 13.22] | 21.1 | [0.16, 0.27] | 0.9 | 0.4 |
| `ideal` | X@2.00 | YES | none | 0.06578 | 0.3178 | 0.0342 | 0.3132 | 0.246 | 0.00 | 0.00 | [0.89, 5.50] | 28.5 | [0.08, 0.13] | 1.2 | 0.6 |
| `ideal` | XZ@2.00 | YES | none | 0.08997 | 0.2555 | 0.1197 | 0.5048 | 0.373 | 0.00 | 0.00 | [0.89, 7.07] | 35.4 | [0.12, 0.21] | 1.5 | 0.7 |
| `ideal` | H@2.00 | YES | none | 0.004409 | 0.0952 | 0.0714 | 0.4794 | 0.206 | 0.00 | 0.00 | [5.67, 13.16] | 74.9 | [0.26, 0.45] | 3.1 | 1.6 |
| `nominal` | X@1.00 | YES | none | 0.07271 | 0.3183 | 0.0273 | 0.3811 | 0.250 | 14.17 | 0.00 | [3.31, 25.89] | 28.5 | [0.10, 0.17] | 1.2 | 0.6 |
| `nominal` | XZ@1.00 | YES | none | 0.08964 | 0.2550 | 0.1290 | 0.3966 | 0.368 | 10.00 | 0.00 | [5.66, 25.89] | 35.4 | [0.14, 0.24] | 1.5 | 0.7 |
| `nominal` | X@1.50 | YES | none | 0.08749 | 0.3177 | 0.0125 | 0.3311 | 0.247 | 0.00 | 0.00 | [5.41, 13.39] | 28.5 | [0.09, 0.15] | 1.2 | 0.6 |
| `nominal` | XZ@1.50 | YES | none | 0.1017 | 0.2550 | 0.1199 | 0.4256 | 0.372 | 0.00 | 0.00 | [6.97, 13.39] | 35.4 | [0.13, 0.22] | 1.5 | 0.7 |
| `nominal` | H@1.50 | YES | none | 0.002184 | 0.3499 | 0.0442 | 0.6600 | 0.269 | 0.00 | 0.00 | [3.75, 13.22] | 21.1 | [0.16, 0.27] | 0.9 | 0.4 |
| `nominal` | X@2.00 | YES | none | 0.06589 | 0.3176 | 0.0341 | 0.3124 | 0.246 | 0.00 | 0.00 | [0.89, 5.50] | 28.5 | [0.08, 0.13] | 1.2 | 0.6 |
| `nominal` | XZ@2.00 | YES | none | 0.09224 | 0.2553 | 0.1189 | 0.4938 | 0.373 | 0.00 | 0.00 | [0.89, 7.07] | 35.4 | [0.12, 0.21] | 1.5 | 0.7 |
| `nominal` | H@2.00 | YES | none | 0.004618 | 0.1032 | 0.0714 | 0.4792 | 0.206 | 0.00 | 0.00 | [5.49, 13.16] | 75.5 | [0.26, 0.45] | 3.1 | 1.6 |
| `slow_low` | X@1.00 | YES | none | 0.03581 | 0.3313 | 0.0642 | 0.4121 | 0.242 | 29.86 | 0.00 | [0.71, 23.30] | 27.8 | [0.11, 0.18] | 1.2 | 0.6 |
| `slow_low` | XZ@1.00 | YES | none | 0.2105 | 0.2320 | 0.0895 | 0.4950 | 0.367 | 21.82 | 0.00 | [2.89, 23.30] | 34.2 | [0.14, 0.24] | 1.4 | 0.7 |
| `slow_low` | X@1.50 | YES | none | 0.08203 | 0.2984 | 0.0180 | 0.3344 | 0.250 | 0.00 | 0.00 | [5.10, 12.05] | 27.6 | [0.09, 0.15] | 1.2 | 0.6 |
| `slow_low` | XZ@1.50 | YES | none | 0.1015 | 0.2299 | 0.1187 | 0.4557 | 0.384 | 0.00 | 0.00 | [6.67, 12.05] | 34.2 | [0.13, 0.21] | 1.4 | 0.7 |
| `slow_low` | H@1.50 | YES | none | 0.002387 | 0.3345 | 0.0506 | 0.6738 | 0.272 | 2.72 | 0.00 | [3.20, 11.90] | 20.5 | [0.15, 0.26] | 0.9 | 0.4 |
| `slow_low` | X@2.00 | YES | none | 0.06104 | 0.2982 | 0.0390 | 0.3127 | 0.249 | 0.00 | 0.00 | [0.80, 5.39] | 27.6 | [0.08, 0.13] | 1.2 | 0.6 |
| `slow_low` | XZ@2.00 | YES | none | 0.0968 | 0.2301 | 0.1172 | 0.5147 | 0.386 | 0.00 | 0.00 | [0.80, 6.95] | 34.2 | [0.11, 0.20] | 1.4 | 0.7 |
| `slow_low` | H@2.00 | YES | none | 0.004429 | 0.0935 | 0.0715 | 0.4904 | 0.210 | 0.00 | 0.00 | [5.09, 11.84] | 68.0 | [0.25, 0.44] | 2.8 | 1.4 |
| `fast_high` | X@1.00 | YES | none | 0.0624 | 0.3342 | 0.0376 | 0.3738 | 0.248 | 3.47 | 0.00 | [5.51, 28.48] | 29.3 | [0.10, 0.17] | 1.2 | 0.6 |
| `fast_high` | XZ@1.00 | YES | none | 0.08351 | 0.2761 | 0.1365 | 0.3581 | 0.356 | 1.70 | 0.00 | [7.11, 28.48] | 36.4 | [0.14, 0.24] | 1.5 | 0.8 |
| `fast_high` | X@1.50 | YES | none | 0.09129 | 0.3340 | 0.0087 | 0.3290 | 0.244 | 0.00 | 0.00 | [5.51, 14.73] | 29.3 | [0.09, 0.16] | 1.2 | 0.6 |
| `fast_high` | XZ@1.50 | YES | none | 0.09287 | 0.2763 | 0.1243 | 0.4047 | 0.362 | 0.00 | 0.00 | [7.10, 14.73] | 36.4 | [0.13, 0.23] | 1.5 | 0.8 |
| `fast_high` | H@1.50 | YES | none | 0.002391 | 0.3638 | 0.0414 | 0.6486 | 0.267 | 0.00 | 0.00 | [3.94, 14.54] | 21.7 | [0.16, 0.28] | 0.9 | 0.5 |
| `fast_high` | X@2.00 | YES | none | 0.06977 | 0.3340 | 0.0302 | 0.3114 | 0.243 | 0.00 | 0.00 | [0.98, 5.59] | 29.3 | [0.08, 0.14] | 1.2 | 0.6 |
| `fast_high` | XZ@2.00 | YES | none | 0.09369 | 0.2765 | 0.1192 | 0.4700 | 0.364 | 0.00 | 0.00 | [0.98, 7.19] | 36.4 | [0.12, 0.21] | 1.5 | 0.8 |
| `fast_high` | H@2.00 | YES | none | 0.004844 | 0.1111 | 0.0710 | 0.4699 | 0.204 | 0.00 | 0.00 | [5.71, 14.48] | 83.1 | [0.27, 0.47] | 3.5 | 1.7 |

## Pareto and limiting cases

- costs = (speed MAE [m/s], mid-bracket propulsion energy [Wh]); minimise both

| Cell | Variant | speed MAE | E mid [Wh] | FEAS | Nondominated | first limit |
|---|---|---:|---:|:---:|:---:|---|
| H@1.50 | `ideal` | 0.3494 | 0.212 | YES | NO | none |
| H@1.50 | `nominal` | 0.3499 | 0.212 | YES | NO | none |
| H@1.50 | `slow_low` | 0.3345 | 0.207 | YES | YES | none |
| H@1.50 | `fast_high` | 0.3638 | 0.218 | YES | NO | none |
| H@2.00 | `ideal` | 0.0952 | 0.357 | YES | NO | none |
| H@2.00 | `nominal` | 0.1032 | 0.358 | YES | NO | none |
| H@2.00 | `slow_low` | 0.0935 | 0.346 | YES | YES | none |
| H@2.00 | `fast_high` | 0.1111 | 0.369 | YES | NO | none |
| X@1.00 | `ideal` | 0.3174 | 0.128 | YES | YES | none |
| X@1.00 | `nominal` | 0.3183 | 0.133 | YES | NO | none |
| X@1.00 | `slow_low` | 0.3313 | 0.145 | YES | NO | none |
| X@1.00 | `fast_high` | 0.3342 | 0.133 | YES | NO | none |
| X@1.50 | `ideal` | 0.3176 | 0.119 | YES | NO | none |
| X@1.50 | `nominal` | 0.3177 | 0.120 | YES | NO | none |
| X@1.50 | `slow_low` | 0.2984 | 0.116 | YES | YES | none |
| X@1.50 | `fast_high` | 0.3340 | 0.123 | YES | NO | none |
| X@2.00 | `ideal` | 0.3178 | 0.107 | YES | NO | none |
| X@2.00 | `nominal` | 0.3176 | 0.106 | YES | NO | none |
| X@2.00 | `slow_low` | 0.2982 | 0.102 | YES | YES | none |
| X@2.00 | `fast_high` | 0.3340 | 0.110 | YES | NO | none |
| XZ@1.00 | `ideal` | 0.2547 | 0.184 | YES | YES | none |
| XZ@1.00 | `nominal` | 0.2550 | 0.188 | YES | NO | none |
| XZ@1.00 | `slow_low` | 0.2320 | 0.193 | YES | YES | none |
| XZ@1.00 | `fast_high` | 0.2761 | 0.190 | YES | NO | none |
| XZ@1.50 | `ideal` | 0.2550 | 0.175 | YES | NO | none |
| XZ@1.50 | `nominal` | 0.2550 | 0.176 | YES | NO | none |
| XZ@1.50 | `slow_low` | 0.2299 | 0.170 | YES | YES | none |
| XZ@1.50 | `fast_high` | 0.2763 | 0.181 | YES | NO | none |
| XZ@2.00 | `ideal` | 0.2555 | 0.163 | YES | NO | none |
| XZ@2.00 | `nominal` | 0.2553 | 0.163 | YES | NO | none |
| XZ@2.00 | `slow_low` | 0.2301 | 0.156 | YES | YES | none |
| XZ@2.00 | `fast_high` | 0.2765 | 0.168 | YES | NO | none |

**Limiting cases**

- Most slew-limited: `slow_low` X@1.00 at 29.86% of steps.
- Most saturation-limited: `ideal` X@1.00 at 0.00% of steps.
- Highest upper-bracket energy: `fast_high` H@2.00 at 0.47 Wh.
- Tightest frozen-gate margin: `ideal` H@1.50 margin=0.001756 (first limit: none).
- No cell lost FEASIBLE under any declared variant.

## Determinism

- X@1.00 variant=nominal bitwise_max_diff=0.000e+00 over 360 decimated samples

## Fingerprints (production and vertical plan, before / after)

| File | Bytes | SHA-256 before | SHA-256 after | Same |
|---|---:|---|---|:---:|
| `continuous_path_tracking.m` | 10845 | `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b` | `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b` | YES |
| `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` | YES |
| `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` | YES |
| `init_parameters.m` | 4205 | `09803f4956b64227403919229781086c367e620f5736cfd680d1b15081237a9a` | `09803f4956b64227403919229781086c367e620f5736cfd680d1b15081237a9a` | YES |
| `underwater777_vehicle_dynamics.m` | 6065 | `612e1009f7d65968109be1e8352d472730db65c08b0c15a17e6cde7a9f629558` | `612e1009f7d65968109be1e8352d472730db65c08b0c15a17e6cde7a9f629558` | YES |
| `compute_path_following_metrics.m` | 11604 | `6d3c2e77059d451056304aa61d86c55f78dd8367579c58ba40a20ea708bada05` | `6d3c2e77059d451056304aa61d86c55f78dd8367579c58ba40a20ea708bada05` | YES |
| `compute_pitch_window_metrics.m` | 5277 | `fa5919cc783f4d9e0a286d93938d5ec688b6cdb7481f3f6f9dcb675a14f74b94` | `fa5919cc783f4d9e0a286d93938d5ec688b6cdb7481f3f6f9dcb675a14f74b94` | YES |
| `generate_balanced_helical_path.m` | 564 | `8773ecbebc7c12d6153b900913abf7a5e8c6847919a0ff15d5a315e8a8f837c1` | `8773ecbebc7c12d6153b900913abf7a5e8c6847919a0ff15d5a315e8a8f837c1` | YES |
| `suite_results\CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` | YES |

- Production and `CODEX_VERTICAL_PLAN.md` are byte-identical before and after this run; nothing in production was written.

## Frozen definitions reused verbatim

- Accepted cells: X@1.00, XZ@1.00, X@1.50, XZ@1.50, H@1.50, X@2.00, XZ@2.00, H@2.00
- Windows/gates/limits copied from `run_speed_envelope_audit.m` without change (seed=0, Kp_roll=0.605072, Kp_x=25, thrust_trim=13.4 N).
- Production stack untouched: nonlinear theta/q cascade + climb FF frozen.

## Artifacts

- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.md`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.mat`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.png`
