# GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_001

**Verdict: FAIL** - Gate 9 stays LOCKED.

NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)

7 of 29 hard gates are not passed: HG1, HG2, HG5, HG11, HG12, HG13, HG18. HG5 fails on genuine, preserved physics (the R10 cells rail the production rudder at 25 deg). HG11, HG12 and HG13 are structurally BLOCKED by the 3-source budget, and each blocker is now demonstrated rather than asserted. HG1, HG2 and HG18 can only be attested from the prior record because attempt 2 never persisted the cell geometry it executed (new defect D3). Gate 9 stays locked.

## 1. Scope and source budget

Exactly three sources were read for reasoning. The production files listed above were opened byte-wise for integrity fingerprinting only and were not read as reasoning sources; the plant is exercised by CALL, not by reading its text.

| # | source | fingerprint |
|---|---|---|
| S1 | `continuous_path_tracking_propulsion.m` | `n=15861.s1=1261880.s2=1306658324` |
| S2 | `suite_results\GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat` | `n=723780.s1=93292499.s2=622488880` |
| S3 | `suite_results\GATE8_ACTUATOR_ORDER_SCAN_REPAIR.mat` | `n=1027924.s1=134415885.s2=723942667` |

Fingerprint function, recovered exactly from the prior records (6/6 match): `n=<bytes>.s1=<sum(byte)>.s2=<mod(sum(byte_i*i),2^32)>, i 1-based`.

| production file | fingerprint (pre) | unchanged post | identical to Gate 7 record |
|---|---|---|---|
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | 1 | 1 |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | 1 | 1 |
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | 1 | 1 |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | 1 | 1 |
| `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990739` | 1 | 1 |
| `suite_results\CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | 1 | 1 |

Production and CODEX_VERTICAL_PLAN are byte-identical to the accepted Gate 7 record, both before and after this run.

## 2. Hard gates

| gate | status | requirement | detail |
|---|---|---|---|
| HG1 | **ATTESTED** | Exact nominal parity: hooks-off shadow reproduces production bit-for-bit in every cell | attempt-2 record shows 8/8 bit-identical and its stored nominal / shadow hashes re-compare equal here (8/8). NOT re-executed: defect D3 means the executed cell geometry was never persisted, so this run cannot reproduce it. |
| HG2 | **ATTESTED** | Deterministic draw / replay reproduces every replayed run hash bit-for-bit | 32/32 replay runs matched in the attempt-2 record; not re-executed here (same D3 blocker) |
| HG3 | **ATTESTED** | Finite bounded states in every run | recomputed from the stored records: 0 nonfinite, 0 early terminations in 256 MC runs |
| HG4 | **ATTESTED** | Zero instability | recomputed: 0 unstable of 256 MC runs |
| HG5 | **FAIL** | Zero hard magnitude / rate / saturation-rail violations (rail dwell <= 25 percent per channel) | recomputed from the stored records: mag=0 rate=0 rail=36 of 256 MC runs. Worst rudder rail dwell 50.6 percent on R10 against the 25 percent gate. GENUINE physics, preserved: the R10 cells drive the production rudder onto its 25.000 deg magnitude rail. Neither the dwell definition nor the threshold is touched. |
| HG6 | **ATTESTED** | Zero depth / collision violations | recomputed: 0 depth violations |
| HG7 | **ATTESTED** | Zero watchdog / FDIR violations | recomputed: fdir=0 |
| HG8 | **PASS** | No surface / no accommodation / no direct-actuator path in the shadow driver | this driver issues no actuator command at all: it calls the production plant for a derivative probe with identically zero controls and otherwise only reads stored records. The three forbidden-response counters are zero in every stored run. |
| HG9 | **PASS** | Production and CODEX_VERTICAL_PLAN fingerprints unchanged and identical to the accepted Gate 7 record | fingerprint function recovered exactly (6/6); identical to the Gate 7 record 6/6 and to attempt 2 6/6 |
| HG10 | **ATTESTED** | At least 32 independent draw vectors applied to every production cell | 32 draws x 8 cells = 256 MC runs in the reused campaign |
| HG11 | **BLOCKED** | Every declared prior is actually EXERCISED (drawn AND physically injected) | 28/35 exercised; 7 plant priors (CG xyz, CB xyz, buoyancy) still not injectable. ADVANCE: a read-only seam now exists and reduces exactly to production at zero offsets (mechanical=1, numerical=1 over 486 bit-identity checks), and the blocker is now a measurement rather than an assertion - the hydrostatic response spans at most 3 directions (3 measured here), the yaw column of Minv is structurally unobservable, and the z-offset direction carries an unidentifiable BG scale. 0 of 7 injectable at a known magnitude, 2 of 7 scale-ambiguous, 5 of 7 structurally unidentifiable. |
| HG12 | **BLOCKED** | Gate 7 mission / FDIR 16-case matrix re-driven under all 32 stored draws | not re-driven. The 16 scenarios, the cfg and the per-case results are all present and 18/35 priors would couple to a monitor, but neither .mat carries the surrogate FDIR kernel and it lives outside the 3-source budget. Re-implementing it would be a different model, not a re-drive. |
| HG13 | **BLOCKED** | Production cells are the FROZEN X / XZ / R10 definitions | 6/8 geometry elements are contract-derivable from source #1 (horizon rule, sample rule, dt, ZOH ratio, state ORDER, u_ref ownership); the waypoints and initial-state VALUES are caller-supplied arguments and appear nowhere in the production loop. NEW: the production default horizon is 15 s while the attempt-2 reconstruction ran 30 s. |
| HG14 | **PASS** | truth / measured / estimated kept distinct | the plant probe reads TRUTH only (the production derivative), applies no sensor model and runs no estimator; the reused campaign keeps measured separate from truth and declares estimated NOT_IMPLEMENTED |
| HG15 | **PASS** | Label honesty: every prior remains ASSUMED | 35/35 ASSUMED; no ASSUMED -> IDENTIFIED upgrade. The seam refuses to promote its Minv reconstruction. |
| HG16 | **PASS** | No cherry-picking: every executed run is reported | all 264 stored runs re-scored and reported; 243 plant probe evaluations reported in full; nothing dropped |
| HG17 | **PASS** | Seed reuse proven: the scoring draw matrix is bit-identical to the recorded matrix | 32x35, fingerprint n=8960.s1=1128826.s2=716413287, bit-equal=1 |
| HG18 | **ATTESTED** | Nominal parity fingerprints bit-identical to the prior attempt in every cell | stored hashes re-compared equal, but not re-executed (defect D3: the cell geometry was never persisted) |
| HG19 | **PASS** | Forbidden-token audit cannot self-match and is demonstrably functional | inherited clean from attempt 2 and not weakened; this driver adds no command path to audit |
| HG20 | **PASS** | Repaired actuator ordering reused exactly (transport delay upstream of the fin rate and magnitude limits) | reused verbatim from source #3, unmodified: REPAIRED ordering: production command -> command-bus transport delay (Gate 3 grid) + per-tick jitter, fractional-delay hold -> fin first-order lag -> fin RATE limit -> fin MAGNITUDE limit -> plant.... |
| HG21 | **PASS** | Source budget honoured: exactly 3 reasoning sources, no repo scan | S1 continuous_path_tracking_propulsion.m, S2 the Gate 7 .mat, S3 the Gate 8 .mat. Production was opened byte-wise for fingerprinting only; the plant is exercised by call. |
| HG22 | **PASS** | Single MATLAB invocation, no retry | one -batch invocation; every stage is fault-tolerant so no stage can force a second run |
| HG23 | **PASS** | Artifact footprint below 300 MiB | measured after writing, see R.footprint_mib |
| HG24 | **PASS** | No production edits: fingerprints unchanged pre to post | see R.fp_unchanged |
| HG25 | **PASS** | Shadow plant seam reduces to production at zero offsets, mechanically and numerically | mechanical=1 (the single unmarked statement is a verbatim production call), numerical=1 (bit-identical over 486 checks using isequaln on raw doubles) |
| HG26 | **PASS** | Hydrostatic seam structure verified: body acceleration depends on attitude only through roll and pitch | independent of yaw=1, independent of depth=1, and the attitude dependence fits the 3-term hydrostatic basis to a relative residual of 5.01e-16 |
| HG27 | **PASS** | Independent rescoring reproduces the prior aggregates from the stored per-run records | 18 KPIs recomputed from the per-run records: max /delta/ on the convention-free worst-case statistic = 0.000e+00; max /delta/ on p50 = 0.000e+00 under MATLAB prctile ((i-0.5)/n); pass probability and Wilson interval reproduced = 1 |
| HG28 | **PASS** | No tuning, no threshold narrowing, no acceptance-criterion change | the 25 percent rail gate, the 99.9 percent dwell definition, the declared envelope and every cfg value are carried verbatim; no gate definition was relaxed to convert a failure into a pass |
| HG29 | **PASS** | Genuine R10 rudder rail preserved and reported, not suppressed | 2 of 8 nominal cells sit on the 25.000 deg rail; worst MC rudder rail dwell 50.6 percent; reported in the verdict, in the tables and in panel 04 |

`PASS` means verified in this run. `ATTESTED` means re-checked arithmetically from the stored record but not re-executed. `BLOCKED` means structurally impossible inside the declared source budget. `FAIL` means genuinely failed. Only `PASS` counts toward the verdict.

## 3. HG5 - the genuine R10 rudder rail, preserved

dwell = fraction of run samples with |channel| >= 99.9 percent of its magnitude limit; declared envelope de 15 deg / dr 25 deg / rate 40 deg/s (ASSUMED, carried from the Gate 7 record). NEITHER the definition NOR the 25 percent gate threshold is modified by this task.

| cell | nominal peak rudder [deg] | nominal dwell [%] | MC p50 dwell [%] | MC worst dwell [%] | on the 25 deg rail |
|---|---|---|---|---|---|
| X_U1.0 | 0.000 | 0.0 | 0.0 | 0.3 | 0 |
| X_U1.5 | 0.000 | 0.0 | 0.0 | 0.1 | 0 |
| X_U2.0 | 0.000 | 0.0 | 0.0 | 0.4 | 0 |
| XZ_U1.0 | 0.000 | 0.0 | 0.0 | 0.3 | 0 |
| XZ_U1.5 | 0.000 | 0.0 | 0.0 | 0.2 | 0 |
| XZ_U2.0 | 0.000 | 0.0 | 0.0 | 0.4 | 0 |
| R10_U1.5 | 25.000 | 28.2 | 27.2 | 50.6 | 1 |
| R10_U2.0 | 25.000 | 19.7 | 27.3 | 45.8 | 1 |

2 of 8 nominal cells drive the production rudder onto its 25.000 deg magnitude rail, and the worst Monte Carlo rudder rail dwell is 50.6 percent against a 25 percent gate. This is a feasibility property of the R10 turn geometry at these speeds, not a harness defect. It is reported as a failure rather than removed by redefining the dwell metric or relaxing the threshold.

## 4. HG13 - frozen cell geometry

**BLOCKED.** The frozen X / XZ / R10 definitions live in per-cell driver scripts: not in the production tracking loop and not in either .mat. Source #1 fixes the CONTRACT (horizon default, sample rule, dt, ZOH ratio, state ORDER, u_ref ownership) but carries no waypoint or initial-condition value. Closing HG13 needs the per-cell drivers, that is, a fourth source.

### 4.1 What source #1 does fix

Every claim below is a regexp assertion against the text of source #1, the production tracking loop clone, so the derivable / not-derivable split is evidence-backed rather than asserted.

| probe | element | verdict | value |
|---|---|---|---|
| P1 | production default horizon T_final [s] | DERIVED | T_final = 15 s |
| P2 | sample-count rule | DERIVED | n_steps = round(T_final/dt) |
| P3 | default plant / control step | DERIVED | dt = dt_controller (init_parameters global) |
| P4 | guidance zero-order-hold ratio | DERIVED | guidance_period = max(1,round(dt_guidance/dt)) |
| P5 | initial-state vector ORDER (schema only) | DERIVED | x y z phi theta psi u v w p q r |
| P8 | speed schedule u_ref ownership | DERIVED | u_ref is an OUTPUT of production guidance_law, so no per-cell speed schedule exists to freeze |
| P6 | X / XZ / R10 WAYPOINT VALUES | NOT_DERIVABLE | path is a caller-supplied INPUT ARGUMENT; no waypoint literal exists in the production loop |
| P7 | initial-state VALUES | NOT_DERIVABLE | state is a caller-supplied INPUT ARGUMENT; no initial-condition literal exists in the production loop |

### 4.2 Explicit differences from the prior reconstruction

| item | production contract | attempt-2 reconstruction | status |
|---|---|---|---|
| horizon T_final [s] | 15 (production default in source #1) | 30 (harness-declared) | DIFFERENT - previously unreported |
| samples per run | round(T_final/dt) = 600 at dt = 0.025 | 1200 | DIFFERENT - consequence of the horizon difference |
| plant / control step dt [s] | dt_controller from init_parameters | 0.025 | CONSISTENT with cfg T_ctrl, not provable from source #1 alone |
| guidance ZOH ratio | round(dt_guidance/dt) | 3 (cfg T_guid / T_ctrl) | CONSISTENT |
| speed schedule | u_ref produced inside guidance_law, not settable per cell | per-cell scalar U used as the initial BODY surge trim | CONSISTENT with the attempt-2 caveat |
| waypoints (X / XZ / R10) | caller-supplied argument, absent from the production loop | ASSUMED_RECONSTRUCTION, values never persisted in the attempt-2 .mat | NOT_DERIVABLE in budget |
| initial state | caller-supplied argument; only the 12-element ORDER is fixed by source #1 | ASSUMED_RECONSTRUCTION, values never persisted | NOT_DERIVABLE in budget |

The horizon difference is new. The production tracking loop defaults to 15 s while the reused campaign ran 30 s. That does not by itself invalidate the campaign, since a caller may legitimately pass any horizon, but it does mean the reconstruction was never the production default, which the prior record did not state.

### 4.3 Per-cell fingerprints of everything attempt 2 persisted

| cell | family | U [m/s] | descriptor fingerprint | geometry persisted | nominal hash (attempt 2) |
|---|---|---|---|---|---|
| X_U1.0 | X | 1.00 | `n=24.s1=2123.s2=26115` | 0 | `n=153600.s1=10871358.s2=321944991` |
| X_U1.5 | X | 1.50 | `n=26.s1=2227.s2=28698` | 0 | `n=153600.s1=10840141.s2=2562968401` |
| X_U2.0 | X | 2.00 | `n=24.s1=2125.s2=26148` | 0 | `n=153600.s1=10859619.s2=1464317095` |
| XZ_U1.0 | XZ | 1.00 | `n=26.s1=2303.s2=30601` | 0 | `n=153600.s1=11048968.s2=3795586122` |
| XZ_U1.5 | XZ | 1.50 | `n=28.s1=2407.s2=33387` | 0 | `n=153600.s1=10991781.s2=2870699657` |
| XZ_U2.0 | XZ | 2.00 | `n=26.s1=2305.s2=30637` | 0 | `n=153600.s1=10987791.s2=4095299281` |
| R10_U1.5 | R10 | 1.50 | `n=30.s1=2409.s2=35694` | 0 | `n=153600.s1=19094896.s2=2901292177` |
| R10_U2.0 | R10 | 2.00 | `n=28.s1=2307.s2=32744` | 0 | `n=153600.s1=19154081.s2=4101707196` |

### 4.4 New defect D3

NEW DEFECT D3 (reproducibility): attempt 2 persisted only name / family / U per cell. The waypoints, horizon, initial state and speed schedule it actually executed are absent from its .mat, so its HG1 and HG18 nominal-parity hashes cannot be independently re-executed from its own artifacts. They are re-checked here from the record only (ATTESTED), never re-run.

## 5. HG11 - shadow plant seam

**BLOCKED.** The seam mechanism exists and reduces exactly to production at zero offsets (M1 and M2 both hold), but no black-box seam can inject the seven plant priors at a KNOWN magnitude. Closing HG11 needs either a source-level clone of underwater777_vehicle_dynamics.m (a fourth source) or a declared, cited value of the vehicle W, B and BG. Neither is available in this budget, and inventing them would be an ASSUMED -> IDENTIFIED upgrade, which is forbidden.

### 5.1 The seam and its reduction contract

`gate8_shadow_plant_seam.m` is a READ_ONLY_WRAPPER (not a source-level clone: cloning would need a fourth source). It exposes independent CG and CB xyz offsets of +/-0.02 m and a buoyancy scale of +/-3 percent.

- **M1 mechanical reduction**: 1. With every marked region deleted, the entire body is `gdot = underwater777_vehicle_dynamics(t, g, controls); end`.
- **M2 numerical reduction**: 1. With the seam inactive, and again with the seam active at all-zero offsets, the returned derivative is bit-identical to production (`isequaln` on raw doubles) over 486 checks spanning the whole probe grid.

### 5.2 Why the seven priors still cannot be injected

At a fixed BODY velocity and zero controls, the only attitude-dependent term in the BODY acceleration is -Minv*g_eta(phi,theta). Over any attitude grid that term spans at most three directions (basis sin(theta), cos(theta)sin(phi), cos(theta)cos(phi)), which yields 18 observable numbers, while injecting an arbitrary CG / CB / buoyancy perturbation requires all 36 entries of Minv plus the absolute weight scale. The problem is therefore underdetermined by construction, no matter how many probes are run.

| probe | grid points | observable rank | relative fit residual | all finite |
|---|---|---|---|---|
| nu = 0 | 81 | 3 of 6 | 5.01e-16 | 1 |
| nu = [1.5 0 0 0 0 0] | 81 | 3 of 6 | 5.01e-16 | 1 |
| nu = mixed | 81 | 3 of 6 | 3.70e-16 | 1 |

The attitude dependence of the BODY acceleration is independent of yaw (1) and of depth (1), and it fits the three-term hydrostatic basis to a relative residual of 5.01e-16, which confirms the seam sits exactly where the theory puts it.

| prior | what injection needs | verdict | why |
|---|---|---|---|
| cg_dx | Minv columns 5 and 6 | **UNIDENTIFIABLE** | needs the yaw column of Minv; hydrostatics generate no yaw moment, so that column is structurally unobservable from outside the plant |
| cg_dy | Minv columns 4 and 6 | **UNIDENTIFIABLE** | needs the yaw column of Minv; structurally unobservable |
| cg_dz | Minv columns 4 and 5, plus the scalar BG | **SCALE_AMBIGUOUS** | direction is observable from q1 and q2, but the magnitude carries the unknown factor BG = (z_g*W - z_b*B)/W |
| cb_dx | Minv columns 5 and 6 | **UNIDENTIFIABLE** | as cg_dx |
| cb_dy | Minv columns 4 and 6 | **UNIDENTIFIABLE** | as cg_dy |
| cb_dz | Minv columns 4 and 5, plus the scalar BG | **SCALE_AMBIGUOUS** | as cg_dz |
| buoyancy_frac | Minv columns 1 to 3 | **UNIDENTIFIABLE** | needs the force columns of Minv, observable only if the nominal net weight W-B is non-zero; the probe measures it as zero |

**0 of 7 injectable at a known magnitude, 2 scale-ambiguous, 5 structurally unidentifiable.** This is the substantive change from attempt 2: the blocker was an assertion, and it is now a measurement.

## 6. HG12 - Gate 7 re-drive

**BLOCKED.** The Gate 7 record stores the 16 scenarios, the cfg and the per-case results, but not the surrogate mission / FDIR simulator that produced them; that kernel lives in the Gate 7 driver script, outside the 3-source budget. Re-implementing it from cfg would create a DIFFERENT model whose output could not reproduce the accepted per-case hashes, so rescoring against it would not be a re-drive of the accepted schedule. Carrying the attempt-2 reference forward unchanged is the only honest option.

Available: 16 scenarios, 32 draws and the full cfg. Missing: the executable surrogate FDIR kernel, present in neither .mat (0). 18 of 35 priors would couple to a Gate 7 monitor if the kernel were available.

| prior group | Gate 7 monitor it would drive | coupled |
|---|---|---|
| CG | none (plant-parameter prior, no monitor path) | 0 |
| CB | none (plant-parameter prior, no monitor path) | 0 |
| BUOYANCY | none (plant-parameter prior, no monitor path) | 0 |
| SENSOR_BIAS | none (a bias is not a staleness or integrity trip) | 0 |
| SENSOR_DELAY | IMU_STALE / DVL_STALE / DEPTH_STALE | 1 |
| SENSOR_DROPOUT | IMU_STALE / DVL_STALE / DEPTH_STALE | 1 |
| ACTUATOR | ACTUATOR_STUCK_CURRENT / BUS_TIMEOUT | 1 |
| POWER | UNDERVOLTAGE | 1 |

## 7. Reused campaign: seed, draws, actuator order and prior exercise

Seed 20260809, draw matrix 32 x 35, fingerprint `n=8960.s1=1128826.s2=716413287`, bit-identical to the recorded matrix: 1. The repaired actuator ordering is reused verbatim: REPAIRED ordering: production command -> command-bus transport delay (Gate 3 grid) + per-tick jitter, fractional-delay hold -> fin first-order lag -> fin RATE limit -> fin MAGNITUDE limit -> plant. Attempt 1 (LEGACY) applied lag, rate and magnitude limiting BEFORE the resampler, so the jittered resampler re-interpolated an already limited signal and inflated the realized step. The thrust channel is untouched in both orderings so that the only behavioural difference is the fin limiter position.

NON-GATING. The draw matrix used for scoring is the one loaded from source #3, so the reuse is exact by construction. Regenerating it from the recorded seed is reported only as a transparency check: a mismatch means attempt 2 used a draw recipe it did not publish, not that the reuse here is wrong. Regeneration from the recorded seed matched: 0.

| prior | group | declared range | span of the 32 draws | support | injected |
|---|---|---|---|---|---|
| cg_dx | CG | [-0.02, 0.02] | 93% | UNSUPPORTED | 0 |
| cg_dy | CG | [-0.02, 0.02] | 97% | UNSUPPORTED | 0 |
| cg_dz | CG | [-0.02, 0.02] | 91% | UNSUPPORTED | 0 |
| cb_dx | CB | [-0.02, 0.02] | 94% | UNSUPPORTED | 0 |
| cb_dy | CB | [-0.02, 0.02] | 96% | UNSUPPORTED | 0 |
| cb_dz | CB | [-0.02, 0.02] | 98% | UNSUPPORTED | 0 |
| buoyancy_frac | BUOYANCY | [-0.03, 0.03] | 91% | UNSUPPORTED | 0 |
| imu_bias_phi | SENSOR_BIAS | [-0.5, 0.5] | 95% | SUPPORTED | 1 |
| imu_bias_theta | SENSOR_BIAS | [-0.5, 0.5] | 98% | SUPPORTED | 1 |
| imu_bias_psi | SENSOR_BIAS | [-1, 1] | 91% | SUPPORTED | 1 |
| imu_bias_p | SENSOR_BIAS | [-0.2, 0.2] | 97% | SUPPORTED | 1 |
| imu_bias_q | SENSOR_BIAS | [-0.2, 0.2] | 99% | SUPPORTED | 1 |
| imu_bias_r | SENSOR_BIAS | [-0.2, 0.2] | 79% | SUPPORTED | 1 |
| dvl_bias_u | SENSOR_BIAS | [-0.02, 0.02] | 91% | SUPPORTED | 1 |
| dvl_bias_v | SENSOR_BIAS | [-0.02, 0.02] | 96% | SUPPORTED | 1 |
| dvl_bias_w | SENSOR_BIAS | [-0.02, 0.02] | 95% | SUPPORTED | 1 |
| dep_bias | SENSOR_BIAS | [-0.1, 0.1] | 98% | SUPPORTED | 1 |
| imu_delay | SENSOR_DELAY | [0, 0.025] | 94% | SUPPORTED | 1 |
| dvl_delay | SENSOR_DELAY | [0, 0.1] | 98% | SUPPORTED | 1 |
| dep_delay | SENSOR_DELAY | [0, 0.05] | 93% | SUPPORTED | 1 |
| imu_drop_p | SENSOR_DROPOUT | [0, 0.005] | 96% | SUPPORTED | 1 |
| dvl_lock_loss_dur | SENSOR_DROPOUT | [0, 3] | 94% | SUPPORTED | 1 |
| dvl_lock_loss_t0f | SENSOR_DROPOUT | [0.2, 0.7] | 96% | SUPPORTED | 1 |
| dep_disagree_mag | SENSOR_DROPOUT | [0, 0.3] | 94% | SUPPORTED | 1 |
| dep_disagree_t0f | SENSOR_DROPOUT | [0.2, 0.7] | 97% | SUPPORTED | 1 |
| dep_disagree_dur | SENSOR_DROPOUT | [0, 2] | 97% | SUPPORTED | 1 |
| tau_thrust | ACTUATOR | [0.02, 0.25] | 99% | SUPPORTED | 1 |
| gain_thrust | ACTUATOR | [0.95, 1.05] | 97% | SUPPORTED | 1 |
| slew_thrust | ACTUATOR | [1, 5] | 89% | SUPPORTED | 1 |
| tau_fin | ACTUATOR | [0.01, 0.08] | 89% | SUPPORTED | 1 |
| td_transport | ACTUATOR | [0, 0.03] | 100% | SUPPORTED | 1 |
| jitter_max | ACTUATOR | [0, 0.005] | 93% | SUPPORTED | 1 |
| V0 | POWER | [0.9, 1] | 97% | PARTIAL | 1 |
| k_ir_scale | POWER | [0.5, 1.5] | 94% | PARTIAL | 1 |
| load_scale | POWER | [0.8, 1.2] | 94% | PARTIAL | 1 |

**28 of 35 priors are physically exercised; 7 are drawn and recorded but never injected.** All 35 labels remain ASSUMED.

## 8. Independently recomputed distributions and Pareto

Every aggregate below was recomputed from the 256 stored per-run records rather than copied. Percentile convention: MATLAB prctile ((i-0.5)/n). Maximum absolute deviation from the prior record is 0.000e+00 on the convention-free worst-case statistic and 0.000e+00 on the median.

| KPI | p5 | p50 | p95 | worst | delta p50 vs attempt 2 | delta worst |
|---|---|---|---|---|---|---|
| cte_mean | 0.0493811 | 0.200769 | 0.331538 | 0.371445 | 0.00e+00 | 0.00e+00 |
| cte_max | 0.119924 | 0.341141 | 0.56261 | 0.826274 | 0.00e+00 | 0.00e+00 |
| depth_err_max | 0.0734971 | 0.284331 | 0.526639 | 0.584397 | 0.00e+00 | 0.00e+00 |
| u_err_rms | 0.0918568 | 0.310457 | 0.814108 | 0.828389 | 0.00e+00 | 0.00e+00 |
| theta_absmax_deg | 1.66501 | 4.71773 | 8.42051 | 8.63246 | 0.00e+00 | 0.00e+00 |
| de_absmax | 5.52323 | 6.29774 | 7.4567 | 8.00662 | 0.00e+00 | 0.00e+00 |
| dr_absmax | 2.63825 | 24.8823 | 25 | 25 | 0.00e+00 | 0.00e+00 |
| thr_max | 4.92517 | 13.07 | 26.7647 | 27.611 | 0.00e+00 | 0.00e+00 |
| energy_thrust | 123.273 | 165.966 | 189.536 | 193.378 | 0.00e+00 | 0.00e+00 |
| energy_fin | 0.734089 | 4.99203 | 9.46499 | 10.3103 | 0.00e+00 | 0.00e+00 |
| err_theta_max_deg | 0.0277156 | 0.287311 | 0.509856 | 0.5357 | 0.00e+00 | 0.00e+00 |
| err_z_max_m | 0.0548268 | 0.151284 | 0.351637 | 0.360919 | 0.00e+00 | 0.00e+00 |
| V_min | 0.857117 | 0.90036 | 0.954845 | 0.853529 | 0.00e+00 | 0.00e+00 |
| brown_dwell | 0 | 0 | 0 | 0 | 0.00e+00 | 0.00e+00 |
| td_mean | 0.000403564 | 0.0164959 | 0.0319989 | 0.0321575 | 0.00e+00 | 0.00e+00 |
| trip_dwell | 0 | 0.975 | 1.975 | 2.075 | 0.00e+00 | 0.00e+00 |
| act_slew_max_degs | 39.8355 | 40 | 40 | 40 | 0.00e+00 | 0.00e+00 |
| rail_dwell_dr_env | 0 | 0 | 0.403333 | 0.505833 | 0.00e+00 | 0.00e+00 |

| Pareto axis | metric | p50 | p95 | worst | attempt-2 worst | status |
|---|---|---|---|---|---|---|
| Tracking | cte_max | 0.341141 | 0.56261 | 0.826274 | 0.826274 | REPORTED |
| ActuatorMargin | act_margin_de | 8.70226 | 9.47677 | 6.99338 | 6.99338 | REPORTED |
| Energy | energy_thrust | 165.966 | 189.536 | 193.378 | 193.378 | REPORTED |
| Estimation | err_theta_max_deg | 0.287311 | 0.509856 | 0.5357 | 0.5357 | PARTIAL - measured-vs-truth only; no estimator/NEES on the production path |
| Timing | td_mean | 0.0164959 | 0.0319989 | 0.0321575 | 0.0321575 | PARTIAL - simulated command transport delay only; target WCET/deadline TO_BE_IDENTIFIED |
| Safety | trip_dwell | 0.975 | 1.975 | 2.075 | 2.075 | REPORTED |

| failure category | count | fraction |
|---|---|---|
| nonfinite | 0 | 0.0000 |
| early_termination | 0 | 0.0000 |
| instability | 0 | 0.0000 |
| magnitude | 0 | 0.0000 |
| rate | 0 | 0.0000 |
| sat_rail | 36 | 0.1406 |
| depth | 0 | 0.0000 |
| tracking | 0 | 0.0000 |
| speed | 0 | 0.0000 |
| attitude | 0 | 0.0000 |
| power | 0 | 0.0000 |
| fdir | 0 | 0.0000 |

Monte Carlo pass rate 220/256 = 0.859375, Wilson 95 percent interval [0.811461, 0.896663], reproduces the prior record: 1.

## 9. Visual QA

visual QA is programmatic: every figure is re-opened after writing, its pixel dimensions and byte size are read back, and the series behind each panel is re-checked for finiteness and for preservation of the rail evidence

**VISUAL_QA_PASS** - 6 of 7 files, 7 of 7 checks.

| check | pass | detail |
|---|---|---|
| files_written | 1 | 6/6 panels re-opened after writing; all exceed 8 KiB and 600x400 px |
| no_nan_in_plotted_data | 1 | 256 MC runs x 18 KPIs plotted, 0 nonfinite entries |
| rail_evidence_preserved | 1 | 2 of 8 nominal cells still drawn at the 25 deg rudder rail; the 25 percent threshold line is drawn, not moved |
| blocked_gates_visible | 1 | every BLOCKED gate is drawn in its own colour in the gate panel, so a blocker cannot be mistaken for a pass |
| axis_labels_carry_units | 1 | every plotted axis is labelled with unit and frame: deflection deg, dwell percent of run, BODY acceleration m/s^2 and rad/s^2, offsets m BODY |
| tex_interpreter_disabled | 1 | all titles, labels, legends and tick labels use Interpreter none so underscored names render literally |
| probe_grid_reported | 1 | 243 plant probe evaluations reported in full, with singular values and fit residuals |

- `suite_results\GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_01_gates.png 1605x1089 px 114 KiB ok=1`
- `suite_results\GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_02_cell_geometry.png 1662x894 px 85 KiB ok=1`
- `suite_results\GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_03_plant_seam.png 1662x1089 px 97 KiB ok=1`
- `suite_results\GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_04_rail_evidence.png 1662x894 px 38 KiB ok=1`
- `suite_results\GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_05_distributions.png 1662x1089 px 96 KiB ok=1`
- `suite_results\GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_06_prior_exercise.png 1662x1089 px 77 KiB ok=1`
- `suite_results\GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE.png 0x0 px 0 KiB ok=0`

## 10. Next task

**GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_001** - Bounded rail-aware yaw-feasibility envelope for the R10 family

- **Objective**: Determine, without changing any controller or guidance law, the largest combination of R10 turn curvature and surge speed for which the production rudder stays off its 25 deg magnitude rail, and express the result as a declared feasibility envelope kappa_max(u) that a future guidance-side admission check could read.
- **Method**: Open-loop steady-turn feasibility from the production plant only: sweep commanded turn rate against surge on a fixed grid, solve for the trim rudder each point requires, and mark the point infeasible when the required deflection reaches the declared 25 deg envelope. Pure plant evaluation, no closed-loop tuning.
- **Bounded by**: one horizon, one grid, no controller edit, no threshold change, no new priors
- **Explicitly excludes**: explicitly does NOT retry the rejected guidance transition shapers or the rejected current feed-forward candidates; it changes no gain and proposes no compensator
- **Why now**: HG5 is the only non-structural failure left, and it is a feasibility fact about the R10 geometry rather than a controller defect

## 11. Honesty statement

IMPLEMENTED = this isolated shadow driver only. All priors ASSUMED. Production and CODEX_VERTICAL_PLAN untouched (fingerprint-verified pre and post). Unsupported factors are drawn and recorded but NOT injected. A blocked gate is reported BLOCKED and is never softened into a pass. Simulation is never hardware certification.

Runtime 52.6 s. Artifact footprint 0.59 MiB against a 300 MiB limit.

## 12. Artifact completion note (post-hoc, no second MATLAB invocation)

Two defects in this task's own driver were found only at run time, both in the reporting stage and both
after every measurement and gate decision had already been made:

- **D4** - the overview-figure function read `R.fp_unchanged` before section S11 assigned it, so MATLAB
  never wrote `GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE.png`.
- **D5** - the markdown writer read `R.footprint_mib` before it was assigned, so this document was
  truncated at the end of section 11.

Both are recorded in the run log verbatim (`main figure error` and `md error`) rather than hidden. The task
permits at most one MATLAB invocation with no retry, and that invocation has been spent, so neither defect
was repaired by re-running MATLAB. They were closed outside MATLAB without recomputing anything:

- Sections 1 to 11 above are exactly what MATLAB wrote. Only this section and the runtime line were appended.
- `GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE.png` was composed from the MATLAB-written `.mat`. Every value drawn
  on it is read back from `R`; nothing is re-simulated, re-fitted, re-scored or re-interpreted.
- The six MATLAB-drawn panels are untouched.
- The `.mat` is exactly as MATLAB saved it and remains the authoritative record. Where this note and the
  `.mat` disagree, the `.mat` wins. In particular `R.visual_qa` records 6 of 7 files verified and
  `R.footprint_mib` records 0.55 MiB, because at the moment MATLAB measured them the overview PNG did not
  yet exist; the true final count is 9 artifacts totalling 0.59 MiB.

D4 and D5 change no gate outcome, no measurement and not the verdict. The verdict remains **FAIL** and
Gate 9 remains locked, for the reasons given in sections 3 to 6.

### 12.1 Correction to two HG11 justifications (verdicts unchanged)

The probe measured more than the pre-written justification text in `R.hg11.injectability` assumed. Two of the
`why` strings stored in the `.mat` are over-strong and are corrected here. **No verdict changes**: all seven
plant priors remain non-injectable, HG11 remains BLOCKED, and the overall verdict remains FAIL.

Measured basis at `nu = [1.5 0 0 0 0 0]` (BODY acceleration per unit of each attitude basis function), with
singular values 48.54, 1.508, 0.03944, then 1.3e-16, 6.7e-17, 1.4e-17:

| basis function | surge | sway | heave | roll | pitch | yaw |
|---|---|---|---|---|---|---|
| sin(theta) | +1.7014e-01 | -1.6e-18 | +2.1303e-02 | +2.8e-17 | -7.3503e-01 | +5.6e-19 |
| cos(theta)sin(phi) | -4.5e-18 | -3.0513e-01 | +7.2e-19 | -2.4915e+01 | +4.0e-18 | -7.0697e-02 |
| cos(theta)cos(phi)-1 | -3.3378e-04 | -5.3e-17 | -7.5594e-02 | -8.4e-15 | +1.7539e-02 | -1.8e-17 |

What the data actually shows:

1. The hydrostatic response splits cleanly into a longitudinal set (surge, heave, pitch) and a lateral set
   (sway, roll, yaw) to 1e-17, so the plant mass matrix is plane-decoupled.
2. `sin(theta)` and `cos(theta)cos(phi)-1` are **not** parallel in the longitudinal plane (cosine of the angle
   between them is -0.2486). Under the Fossen restoring structure, which the 5.0e-16 fit residual supports,
   that is only possible if the nominal net weight minus buoyancy is **non-zero**. The production plant is
   therefore not exactly neutrally buoyant. This is a new measured fact about production, obtained purely by
   black-box probing, and no numeric value for W, B or BG is claimed or promoted to IDENTIFIED.
3. The lateral support of `sin(theta)` is 2.8e-17, which puts the nominal lateral CG/CB offset at zero.

Corrections:

- **`buoyancy_frac`** - the stored reason says the force columns are "observable only if the nominal net
  weight W-B is non-zero; the probe measures it as zero". That is **wrong on both counts**: W-B is measured
  as non-zero, so the force columns *are* excited. The correct reason it is still not injectable is that the
  three observed vectors are fixed linear combinations of unknown nominal parameters with unknown columns of
  the inverse mass matrix, so no individual column can be isolated.
- **`cg_dx` / `cg_dy` / `cb_dx` / `cb_dy`** - the stored reason says "hydrostatics generate no yaw moment".
  That is only true when the nominal lateral and longitudinal CG/CB offsets both vanish, which the probe did
  not establish, and the measured yaw response to `cos(theta)sin(phi)` is -7.07e-02 rather than zero. The
  correct reason is again the rank argument below.

**The one argument that is fully supported by the measurement**, and the one HG11 should rest on: the
observable subspace is exactly 3-dimensional (three significant singular values, then a fall to machine
epsilon, reproduced identically at three different BODY velocities). Three observed 6-vectors are 18 numbers.
Injecting an arbitrary CG / CB / buoyancy perturbation requires all 36 entries of the inverse mass matrix plus
the 4 unknown nominal restoring parameters needed to deconvolve the observed combinations. 18 numbers cannot
determine 40 unknowns, so the problem is underdetermined by construction no matter how many probes are run.
**0 of 7 priors are injectable at a known magnitude**, which is exactly what the `.mat` records.
