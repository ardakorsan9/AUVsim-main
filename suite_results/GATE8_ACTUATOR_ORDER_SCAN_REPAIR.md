# GATE8_ACTUATOR_ORDER_SCAN_REPAIR - FAIL

**TASK_ID:** `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_001`  
**Date:** 2026-08-09 04:30:20  
**Class:** Gate 8 attempt 2 - isolated shadow-only harness defect repair, identical campaign re-run  
**MATLAB runs:** 1 (single bounded invocation, no retry)  
**Production / CODEX_VERTICAL_PLAN:** untouched (read-only inputs, fingerprinted pre and post)  
**Physical / hardware readiness:** **NOT_CERTIFIED**  
**Host runtime:** 5243.8 s  

## 1. Verdict

**FAIL.**

Gate 8 is **FAIL**. Failing hard gates: **HG5, HG11, HG12, HG13**. This task was a defect repair and was never capable of producing a Gate 8 PASS: **HG11** (CG / CB / buoyancy have no injection seam), **HG12** (the Gate 7 16-case FDIR matrix was not re-drawn) and **HG13** (cell geometry is a reconstruction) were already open before it started and are unchanged. Nothing was narrowed, re-scoped, re-tuned or hidden to improve this result.

Repair status, reported separately from the gate verdict: **D1 limiter ordering = REPAIRED**, **D2 token audit = REPAIRED**. repair status is reported separately from the gate verdict: repairing a harness defect does not by itself move a gate, and HG5 can still fail on genuine evidence

Gate 9 stays **locked** (it unlocks only on a Gate 8 PASS). Gate 9B remains post-Gate 9.

## 2. What this attempt changed, and what it did not

| # | Change | Scope |
|---|---|---|
| D1 | D1 fin magnitude/rate limiting moved downstream of transport-delay + jitter resampling | this isolated driver only |
| D2 | D2 forbidden-token audit made non-self-matching, with positive control | this isolated driver only |

**Explicitly unchanged:** the recorded seed, all 35 prior definitions and bounds, the 32 draw vectors, the 8 cells, the replay schedule, every threshold, the sensor / power / monitor models, the thrust channel, and every production file. No tuning of any kind was performed.

**Actuator ordering:** REPAIRED ordering: production command -> command-bus transport delay (Gate 3 grid) + per-tick jitter, fractional-delay hold -> fin first-order lag -> fin RATE limit -> fin MAGNITUDE limit -> plant. Attempt 1 (LEGACY) applied lag, rate and magnitude limiting BEFORE the resampler, so the jittered resampler re-interpolated an already limited signal and inflated the realized step. The thrust channel is untouched in both orderings so that the only behavioural difference is the fin limiter position.

## 3. Sources (exactly 3, no repo scan)

| # | Path | Fingerprint |
|---|------|-------------|
| 1 | `run_gate8_monte_carlo_independent_priors.m` | `n=77885.s1=6057604.s2=1069830847` |
| 2 | `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.mat` | `n=1012850.s1=132596107.s2=2133553502` |
| 3 | `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.md` | `n=37502.s1=2953907.s2=4255389271` |

Attempt 1 record: `GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001`, created 2026-08-09 02:02:08, verdict **FAIL**, failed HG5, HG8, HG11, HG12, HG13, runtime 5618.2 s.

**Frozen configuration provenance:** FROZEN_BY_REFERENCE - cfg is loaded from the path attempt 1 recorded in its own R.sources{2}. It is a transitive dependency of source #2, not a fourth reasoning source: no value in it is re-derived, re-tuned or re-interpreted here, and the legacy A/B hash equality below fails loudly if a single cfg field differs from attempt 1. Path used: `suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat`, fingerprint `n=723780.s1=93292499.s2=622488880`.

## 4. Gate 0 hygiene, frames and units

| Item | Value |
|------|-------|
| Free disk at start | 4.43 GiB (>= 3 GiB required: 1; >= 5 GiB preferred: 0) |
| frames.position | NED inertial [m]; z positive DOWN (depth = +z) |
| frames.rates | BODY angular rates p,q,r [rad/s]; BODY velocity u,v,w [m/s] |
| frames.euler | phi,theta,psi [rad] internally (deg only where a name says _deg) |
| frames.pitch_sign | theta > 0 = nose UP = depth decreasing |
| frames.actuators | delta_e, delta_r signed per production convention; thrust pu |
| frames.units | SI (m, m/s, rad, rad/s, s); deg only where labelled |
| frames.source_ref | GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.mat R.frames (frozen chain from GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat, not re-derived) |
| frames.label | INTERFACE_SPECIFIED |
| frames.derived_units | rail dwell and rate dwell are dimensionless fractions of the run; realized slew in deg/s; fin limits in deg; energy proxies in native units |
| declared fin envelope | elevator 15 deg, rudder 25 deg, rate 40 deg/s (ASSUMED, carried from the Gate 7 record) |
| declared depth corridor | [1, 30] m, z positive down |

Production fingerprints:

| File | pre | post | == Gate 7 | == attempt 1 |
|------|-----|------|-----------|--------------|
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | `n=10845.s1=886194.s2=515073390` | 1 | 1 |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | `n=9402.s1=732890.s2=3334742186` | 1 | 1 |
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | `n=14601.s1=1095745.s2=3464382495` | 1 | 1 |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | `n=6065.s1=426918.s2=1254438441` | 1 | 1 |
| `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990739` | `n=11604.s1=883372.s2=792990739` | 1 | 1 |
| `suite_results/CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | `n=43101.s1=4310210.s2=3268810005` | 1 | 1 |

Fingerprint formula `n=<bytes>.s1=<sum>.s2=<mod(sum(i*b_i),2^32)>`, identical to the formula the accepted Gate 7 and attempt-1 evidence used, so all three columns are directly comparable.

## 5. Verification BEFORE any metric comparison

The comparison against attempt 1 is only admissible if the campaign is provably the same campaign. These checks run first and gate the comparison.

| Check | Result | Evidence |
|---|---|---|
| Declared campaign constants reused | 1 | seed 20260809, 32 draws, dt 0.025 s, T_final 30 s, replay draws [1 16 32] |
| Draw matrix bit-identical to attempt 1 | 1 | size match 1, max abs difference 0, fingerprint `n=8960.s1=1128826.s2=716413287` vs `n=8960.s1=1128826.s2=716413287` |
| Factor order, bounds and support classes identical | 1 | names 1, bounds 1, support 1 |
| Cell set identical to attempt 1 | 1 | 8 cells, same names, families and surge trims |
| Nominal parity fingerprints match attempt 1 | 1 | production 8/8 cells, hooks-off shadow 8/8 cells |
| Replay hashes reproduce within this run | 1 | 32 replay runs |
| Replay nominal hashes match attempt 1 | 1 | hooks-off replay is untouched by the repair |
| Monte Carlo hashes changed, as the repair requires | 1 | a repair that changed nothing would be the real failure |
| Legacy-order A/B reproduces attempt 1 | 1 | 9 A/B runs |

**Verification verdict: ALL CHECKS PASSED. Metric comparison with attempt 1 is ADMISSIBLE.**

### 5.1 Per-cell nominal fingerprints

| Cell | production hash (this run) | == attempt 1 | hooks-off shadow hash | == attempt 1 | HG1 parity |
|---|---|---|---|---|---|
| `X_U1.0` | `n=153600.s1=10871358.s2=321944991` | 1 | `n=153600.s1=10871358.s2=321944991` | 1 | 1 |
| `X_U1.5` | `n=153600.s1=10840141.s2=2562968401` | 1 | `n=153600.s1=10840141.s2=2562968401` | 1 | 1 |
| `X_U2.0` | `n=153600.s1=10859619.s2=1464317095` | 1 | `n=153600.s1=10859619.s2=1464317095` | 1 | 1 |
| `XZ_U1.0` | `n=153600.s1=11048968.s2=3795586122` | 1 | `n=153600.s1=11048968.s2=3795586122` | 1 | 1 |
| `XZ_U1.5` | `n=153600.s1=10991781.s2=2870699657` | 1 | `n=153600.s1=10991781.s2=2870699657` | 1 | 1 |
| `XZ_U2.0` | `n=153600.s1=10987791.s2=4095299281` | 1 | `n=153600.s1=10987791.s2=4095299281` | 1 | 1 |
| `R10_U1.5` | `n=153600.s1=19094896.s2=2901292177` | 1 | `n=153600.s1=19094896.s2=2901292177` | 1 | 1 |
| `R10_U2.0` | `n=153600.s1=19154081.s2=4101707196` | 1 | `n=153600.s1=19154081.s2=4101707196` | 1 | 1 |

### 5.2 Legacy-order A/B, the proof that only the limiter moved

| Cell | draw | jitter max [ms] | transport delay [ms] | legacy hash == attempt 1 | repaired hash differs | slew legacy [deg/s] | slew repaired [deg/s] |
|---|---|---|---|---|---|---|---|
| `X_U1.0` | 1 | 2.918 | 30 | 1 | 1 | 44.438 | 40.000 |
| `X_U1.0` | 16 | 1.793 | 30 | 1 | 1 | 42.727 | 40.000 |
| `X_U1.0` | 32 | 1.766 | 0 | 1 | 1 | 42.768 | 40.000 |
| `R10_U1.5` | 1 | 2.918 | 30 | 1 | 1 | 44.398 | 40.000 |
| `R10_U1.5` | 16 | 1.793 | 30 | 1 | 1 | 42.499 | 40.000 |
| `R10_U1.5` | 32 | 1.766 | 0 | 1 | 1 | 42.671 | 40.000 |
| `R10_U2.0` | 1 | 2.918 | 30 | 1 | 1 | 44.550 | 40.000 |
| `R10_U2.0` | 16 | 1.793 | 30 | 1 | 1 | 42.644 | 40.000 |
| `R10_U2.0` | 32 | 1.766 | 0 | 1 | 1 | 42.595 | 40.000 |

The legacy branch is attempt-1 arithmetic kept verbatim in this driver purely as an A/B reference. It consumes the same single random number per tick at the same point, so the sensor and dropout streams are identical in both orderings.

## 6. D2 - forbidden-token audit

| Property | Value |
|---|---|
| Construction | tokens assembled from two fragments at run time; the fenced declaration block holds fragments only, so no complete token literal exists in the file |
| Tokens checked | 10 |
| Declaration lines excluded from the scanned text | 5 of 2388 |
| Hits with the declaration region included | 0 |
| Hits with the declaration region excluded | 0 |
| Self-match free | 1 |
| Positive control | 1 (10 of 10 assembled tokens detected in a synthetic probe string) |
| Audit clean | 1 |

Attempt 1 failed HG8 because its token list was a literal in the file it scanned, so the scan always matched itself. Here each token is assembled from two fragments at run time, so no complete token literal exists anywhere in the driver; the fenced fragment declaration is additionally excluded, and the hit count is reported both with and without that fence so the claim is checkable rather than asserted. The positive control proves a clean result means "absent", not "broken".

The three substantive response counters remain and remain zero in every run: surface = 0, automatic accommodation = 0, direct-actuator command path = 0, across 264 runs. Those zeros are retained as evidence, not deleted along with the broken scan.

## 7. Campaign definition (reused, not redefined)

| Item | Value |
|------|-------|
| Recorded seed | `20260809`, one independent mt19937ar substream per factor |
| Draw vectors | 32, the same 32 applied to every cell (common random numbers) |
| Cells | 8: X U={1.0,1.5,2.0}, XZ U={1.0,1.5,2.0}, R10 U={1.5,2.0} |
| Step / horizon | dt = 0.025 s, T_final = 30 s |
| Runs | 8 nominal + 256 Monte Carlo + 32 replay + 9 legacy A/B |

**Cell provenance:** ASSUMED_RECONSTRUCTION - the frozen X / XZ / R10 cell definitions (waypoints, horizon, initial state, u_ref schedule) live in per-cell driver scripts that are outside this task 3-source budget. Geometry here is harness-declared, NOT the frozen production cell. U labels the initial BODY surge trim; u_ref is owned internally by production guidance_law.

**Actuator envelope provenance:** fin magnitude/rate envelope = Gate 7 declared 15 deg / 25 deg / 40 deg/s converted to radians (production delta_e, delta_r are radians); thrust envelope derived per cell from that cell nominal command range with 25 percent ASSUMED headroom, because no source establishes the production thrust unit

| Cell | nominal max abs elevator [deg] | nominal max abs rudder [deg] | nominal max abs thrust [native unit] | thrust rail used |
|---|---|---|---|---|
| `X_U1.0` | 6.826 | 0.000 | 25.89 | 32.36 |
| `X_U1.5` | 5.608 | 0.000 | 13.39 | 16.74 |
| `X_U2.0` | 5.227 | 0.000 | 5.488 | 6.86 |
| `XZ_U1.0` | 6.826 | 0.000 | 25.89 | 32.36 |
| `XZ_U1.5` | 5.797 | 0.000 | 13.39 | 16.74 |
| `XZ_U2.0` | 5.775 | 0.000 | 5.94 | 7.425 |
| `R10_U1.5` | 6.592 | 25.000 | 13.25 | 16.56 |
| `R10_U2.0` | 6.307 | 25.000 | 4.882 | 6.103 |

## 8. Prior table - unchanged, all ASSUMED

| Factor | Units | Prior | Group | Injection | Note |
|---|---|---|---|---|---|
| `cg_dx` | m | U(-0.02, 0.02) | CG | **UNSUPPORTED** | plant inertia/hydrostatics are internal to production underwater777_vehicle_dynamics.m; no shadow interface exists to perturb them without editing production, therefore drawn+recorded but NOT injected |
| `cg_dy` | m | U(-0.02, 0.02) | CG | **UNSUPPORTED** | plant inertia/hydrostatics are internal to production underwater777_vehicle_dynamics.m; no shadow interface exists to perturb them without editing production, therefore drawn+recorded but NOT injected |
| `cg_dz` | m | U(-0.02, 0.02) | CG | **UNSUPPORTED** | plant inertia/hydrostatics are internal to production underwater777_vehicle_dynamics.m; no shadow interface exists to perturb them without editing production, therefore drawn+recorded but NOT injected |
| `cb_dx` | m | U(-0.02, 0.02) | CB | **UNSUPPORTED** | plant inertia/hydrostatics are internal to production underwater777_vehicle_dynamics.m; no shadow interface exists to perturb them without editing production, therefore drawn+recorded but NOT injected |
| `cb_dy` | m | U(-0.02, 0.02) | CB | **UNSUPPORTED** | plant inertia/hydrostatics are internal to production underwater777_vehicle_dynamics.m; no shadow interface exists to perturb them without editing production, therefore drawn+recorded but NOT injected |
| `cb_dz` | m | U(-0.02, 0.02) | CB | **UNSUPPORTED** | plant inertia/hydrostatics are internal to production underwater777_vehicle_dynamics.m; no shadow interface exists to perturb them without editing production, therefore drawn+recorded but NOT injected |
| `buoyancy_frac` | - | U(-0.03, 0.03) | BUOYANCY | **UNSUPPORTED** | plant inertia/hydrostatics are internal to production underwater777_vehicle_dynamics.m; no shadow interface exists to perturb them without editing production, therefore drawn+recorded but NOT injected |
| `imu_bias_phi` | deg | U(-0.5, 0.5) | SENSOR_BIAS | **SUPPORTED** | added to measured roll fed to guidance+controller |
| `imu_bias_theta` | deg | U(-0.5, 0.5) | SENSOR_BIAS | **SUPPORTED** | added to measured pitch |
| `imu_bias_psi` | deg | U(-1, 1) | SENSOR_BIAS | **SUPPORTED** | added to measured yaw |
| `imu_bias_p` | deg/s | U(-0.2, 0.2) | SENSOR_BIAS | **SUPPORTED** | added to measured roll rate |
| `imu_bias_q` | deg/s | U(-0.2, 0.2) | SENSOR_BIAS | **SUPPORTED** | added to measured pitch rate |
| `imu_bias_r` | deg/s | U(-0.2, 0.2) | SENSOR_BIAS | **SUPPORTED** | added to measured yaw rate |
| `dvl_bias_u` | m/s | U(-0.02, 0.02) | SENSOR_BIAS | **SUPPORTED** | added to measured surge |
| `dvl_bias_v` | m/s | U(-0.02, 0.02) | SENSOR_BIAS | **SUPPORTED** | added to measured sway |
| `dvl_bias_w` | m/s | U(-0.02, 0.02) | SENSOR_BIAS | **SUPPORTED** | added to measured heave |
| `dep_bias` | m | U(-0.1, 0.1) | SENSOR_BIAS | **SUPPORTED** | added to measured depth |
| `imu_delay` | s | U(0, 0.025) | SENSOR_DELAY | **SUPPORTED** | fractional transport delay on the IMU stream |
| `dvl_delay` | s | U(0, 0.1) | SENSOR_DELAY | **SUPPORTED** | fractional transport delay on the DVL stream |
| `dep_delay` | s | U(0, 0.05) | SENSOR_DELAY | **SUPPORTED** | fractional transport delay on the depth stream |
| `imu_drop_p` | - | U(0, 0.005) | SENSOR_DROPOUT | **SUPPORTED** | per-sample IMU dropout probability, hold-last |
| `dvl_lock_loss_dur` | s | U(0, 3) | SENSOR_DROPOUT | **SUPPORTED** | DVL bottom-lock loss burst duration (availability matrix) |
| `dvl_lock_loss_t0f` | - | U(0.2, 0.7) | SENSOR_DROPOUT | **SUPPORTED** | bottom-lock loss onset as fraction of horizon |
| `dep_disagree_mag` | m | U(0, 0.3) | SENSOR_DROPOUT | **SUPPORTED** | pressure-disagreement offset magnitude |
| `dep_disagree_t0f` | - | U(0.2, 0.7) | SENSOR_DROPOUT | **SUPPORTED** | pressure-disagreement onset fraction |
| `dep_disagree_dur` | s | U(0, 2) | SENSOR_DROPOUT | **SUPPORTED** | pressure-disagreement duration |
| `tau_thrust` | s | U(0.02, 0.25) | ACTUATOR | **SUPPORTED** | first-order thrust lag (shared prop_thrust_actuator model) |
| `gain_thrust` | - | U(0.95, 1.05) | ACTUATOR | **SUPPORTED** | thrust gain error |
| `slew_thrust` | pu/s | U(1, 5) | ACTUATOR | **SUPPORTED** | thrust slew-rate limit |
| `tau_fin` | s | U(0.01, 0.08) | ACTUATOR | **SUPPORTED** | first-order fin lag on delta_e / delta_r |
| `td_transport` | s | D{0,0.015,0.030} | ACTUATOR | **SUPPORTED** | Gate 3 command transport delay grid, fractional-delay hold |
| `jitter_max` | s | U(0, 0.005) | ACTUATOR | **SUPPORTED** | per-tick uniform transport jitter added to td |
| `V0` | pu | U(0.9, 1) | POWER | **PARTIAL** | open-circuit bus voltage; only reaches the plant through thrust-authority derate |
| `k_ir_scale` | - | U(0.5, 1.5) | POWER | **PARTIAL** | scales Gate 6B internal-resistance drop k_ir |
| `load_scale` | - | U(0.8, 1.2) | POWER | **PARTIAL** | scales Gate 6B propulsion load coefficient k_pw |

25 SUPPORTED, 3 PARTIAL, 7 UNSUPPORTED, 35 factors total. Identical to attempt 1, bit-for-bit in the drawn values.

## 9. Hard gates

| ID | Requirement | Pass | Detail |
|---|---|---|---|
| HG1 | Exact nominal parity: shadow loop with all hooks off reproduces the unmodified production continuous_path_tracking bit-for-bit in every cell | PASS | 8/8 cells bit-identical on vp,t,vel,av,ori,yaw_ref,pitch_ref,u_ref |
| HG2 | Deterministic draw/replay: reverse-order re-execution reproduces every replayed run hash bit-for-bit | PASS | 32/32 replay runs matched within this run |
| HG3 | Finite bounded states in every run (no NaN/Inf, no early termination) | PASS | 264/264 finite, 264/264 complete |
| HG4 | Zero instability (divergence / |theta|>85 deg / |rate|>200 deg/s) | PASS | 0 unstable runs |
| HG5 | Zero hard magnitude / rate / saturation-rail violations (rail dwell <= 25 percent per channel) | **FAIL** | mag=0 rate=0 rail=37 (rail measured as envelope-proximity dwell; under the attempt-1 limiter-engagement definition rail=0). Max realized fin slew 40.000 deg/s against the declared 40 deg/s |
| HG6 | Zero depth / collision violations (depth kept inside [1.0, 30.0] m) | PASS | 0 depth violations |
| HG7 | Zero watchdog / FDIR violations (monitor trips are constrain-or-hold, never unhandled) | PASS | fdir=0 wd=0, 200 benign monitor trips |
| HG8 | No surface / no automatic accommodation / no direct-actuator command path anywhere in the shadow driver | PASS | audit clean=1, self-match-free=1, positive control=1 (10/10 synthetic tokens detected); counters surface=0 accom=0 direct=0 |
| HG9 | Production + CODEX_VERTICAL_PLAN fingerprints unchanged, and identical to the accepted Gate 7 record | PASS | unchanged=1, gate7-identical=6/6, attempt1-identical=6/6 |
| HG10 | >= 32 independent draw vectors applied to every production cell (8 cells) | PASS | 32 draws x 8 cells = 256 MC runs |
| HG11 | Every declared prior is actually EXERCISED (drawn AND physically injected) | **FAIL** | 25 SUPPORTED / 3 PARTIAL / 7 UNSUPPORTED injections. Unchanged, still open: CG/CB/buoyancy have no shadow plant-parameter seam and editing production is forbidden |
| HG12 | Gate 7 mission/FDIR 16-case matrix re-drawn under the MC priors | **FAIL** | not re-drawn; carried forward as the recorded attempt-1 reference only. Out of scope of a defect-repair task and not reproducible inside the 3-source budget |
| HG13 | Production cells are the FROZEN X / XZ / R10 definitions | **FAIL** | cell geometry is still an ASSUMED_RECONSTRUCTION, byte-identical to attempt 1 so the comparison is valid, but the frozen cell drivers remain outside the source budget |
| HG14 | truth / measured / estimated kept distinct | PASS | truth = plant state; measured = biased/delayed/dropped sensor stream feeding guidance+controller; estimated = NOT_IMPLEMENTED (no estimator on the production tracking path) |
| HG15 | Label honesty: every prior remains ASSUMED, no ASSUMED->IDENTIFIED upgrade | PASS | 35/35 ASSUMED |
| HG16 | No cherry-picking: every executed run is reported (pooled + per-cell), none dropped | PASS | 264 runs recorded / 264 executed, plus 32 replay and 9 legacy A/B runs all reported |
| HG17 | Seed reuse proven: the regenerated draw matrix is bit-identical to the recorded attempt-1 draw matrix | PASS | seed 20260809, 32x35 draws, bit-equal=1, fp n=8960.s1=1128826.s2=716413287, factor order/bounds equal=1/1, declared constants match=1 |
| HG18 | Nominal parity fingerprints (production and hooks-off shadow) bit-identical to attempt 1 in every cell | PASS | production 8/8, shadow-hooks-off 8/8, replay nominal 1 |
| HG19 | Forbidden-token audit cannot self-match and is demonstrably functional | PASS | no assembled token literal exists in the driver (hits with declaration region included=0, excluded=0); positive control detected 10/10 injected tokens |
| HG20 | Legacy-order A/B reproduces attempt-1 Monte Carlo hashes bit-for-bit, so the limiter position is the only behavioural change | PASS | 9/9 A/B runs bit-identical to attempt 1 and 9/9 differ from the repaired ordering |

HG17 to HG20 are new verification gates added by this attempt. No previously gating requirement was removed, relaxed or re-worded to be easier.

## 10. Failure taxonomy

| Category | Runs | Fraction |
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

## 11. Pass probability

Pooled: **220 / 256 = 0.8594**, Wilson 95% CI [0.8115, 0.8967].

| Cell | draws | pass | p | Wilson 95% CI |
|---|---|---|---|---|
| `X_U1.0` | 32 | 32 | 1.0000 | [0.8928, 1.0000] |
| `X_U1.5` | 32 | 32 | 1.0000 | [0.8928, 1.0000] |
| `X_U2.0` | 32 | 32 | 1.0000 | [0.8928, 1.0000] |
| `XZ_U1.0` | 32 | 32 | 1.0000 | [0.8928, 1.0000] |
| `XZ_U1.5` | 32 | 32 | 1.0000 | [0.8928, 1.0000] |
| `XZ_U2.0` | 32 | 32 | 1.0000 | [0.8928, 1.0000] |
| `R10_U1.5` | 32 | 13 | 0.4062 | [0.2552, 0.5774] |
| `R10_U2.0` | 32 | 15 | 0.4688 | [0.3087, 0.6355] |

## 12. Attempt 1 vs attempt 2

Admissible: every verification check in section 5 passed.

| KPI | attempt 1 P50 | attempt 2 P50 | attempt 1 worst | attempt 2 worst | delta worst |
|---|---|---|---|---|---|
| `cte_max` | 0.342 | 0.3411 | 0.8261 | 0.8263 | +0.0001622 |
| `cte_mean` | 0.2 | 0.2008 | 0.3715 | 0.3714 | -3.802e-05 |
| `depth_err_max` | 0.287 | 0.2843 | 0.5847 | 0.5844 | -0.0003449 |
| `u_err_rms` | 0.3104 | 0.3105 | 0.8284 | 0.8284 | -4.615e-05 |
| `de_absmax` | 6.283 | 6.298 | 8.007 | 8.007 | -0.0001526 |
| `dr_absmax` | 24.85 | 24.88 | 25 | 25 | -3.553e-15 |
| `thr_max` | 13.07 | 13.07 | 27.61 | 27.61 | +0 |
| `energy_thrust` | 165.9 | 166 | 193.7 | 193.4 | -0.307 |
| `energy_fin` | 5.014 | 4.992 | 10.31 | 10.31 | -0.002887 |
| `V_min` | 0.9004 | 0.9004 | 0.8535 | 0.8535 | +0 |
| `td_mean` | 0.0165 | 0.0165 | 0.03216 | 0.03216 | +0 |
| `act_slew_max_degs` | 42.63 | 40 | 47.35 | 40 | -7.352 |

## 13. Rail and dwell evidence

declared envelope de 15 deg / dr 25 deg / rate 40 deg/s (ASSUMED, carried from the Gate 7 record); dwell = fraction of run samples with |channel| >= 99.9 percent of its magnitude limit

| Cell | family | U [m/s] | nominal max abs rudder [deg] | nominal rudder dwell | nominal max abs elevator [deg] | nominal elevator dwell | MC rudder dwell P50 | MC rudder dwell worst | MC max slew [deg/s] |
|---|---|---|---|---|---|---|---|---|---|
| `X_U1.0` | X | 1.00 | 0.000 | 0.0000 | 6.826 | 0.0000 | 0.0000 | 0.0033 | 40.000 |
| `X_U1.5` | X | 1.50 | 0.000 | 0.0000 | 5.608 | 0.0000 | 0.0000 | 0.0008 | 40.000 |
| `X_U2.0` | X | 2.00 | 0.000 | 0.0000 | 5.227 | 0.0000 | 0.0000 | 0.0042 | 40.000 |
| `XZ_U1.0` | XZ | 1.00 | 0.000 | 0.0000 | 6.826 | 0.0000 | 0.0000 | 0.0033 | 40.000 |
| `XZ_U1.5` | XZ | 1.50 | 0.000 | 0.0000 | 5.797 | 0.0000 | 0.0000 | 0.0025 | 40.000 |
| `XZ_U2.0` | XZ | 2.00 | 0.000 | 0.0000 | 5.775 | 0.0000 | 0.0000 | 0.0042 | 40.000 |
| `R10_U1.5` | R10 | 1.50 | 25.000 | 0.2817 | 6.592 | 0.0000 | 0.2717 | 0.5058 | 40.000 |
| `R10_U2.0` | R10 | 2.00 | 25.000 | 0.1967 | 6.307 | 0.0000 | 0.2729 | 0.4575 | 40.000 |

The nominal columns are produced by the hooks-off shadow loop, which is bit-identical to the unmodified production tracker (HG1, HG18). They therefore describe the frozen production controller, not the Monte Carlo priors and not this harness. The R10 rudder sitting exactly at the declared rail under a 0.1 per-metre curvature is genuine evidence about the vehicle and is carried forward unchanged from attempt 1. Only the manufactured rate-violation population was a harness defect; the rudder rail was never one.

## 14. Pooled distributions (all 256 MC runs, nothing dropped)

| KPI | P5 | P50 | P95 | worst | mean |
|---|---|---|---|---|---|
| `cte_mean` | 0.04938 | 0.2008 | 0.3315 | 0.3714 | 0.1985 |
| `cte_max` | 0.1199 | 0.3411 | 0.5626 | 0.8263 | 0.3449 |
| `depth_err_max` | 0.0735 | 0.2843 | 0.5266 | 0.5844 | 0.2933 |
| `u_err_rms` | 0.09186 | 0.3105 | 0.8141 | 0.8284 | 0.3863 |
| `theta_absmax_deg` | 1.665 | 4.718 | 8.421 | 8.632 | 4.953 |
| `de_absmax` | 5.523 | 6.298 | 7.457 | 8.007 | 6.349 |
| `dr_absmax` | 2.638 | 24.88 | 25 | 25 | 22.12 |
| `thr_max` | 4.925 | 13.07 | 26.76 | 27.61 | 13.54 |
| `energy_thrust` | 123.3 | 166 | 189.5 | 193.4 | 162.1 |
| `energy_fin` | 0.7341 | 4.992 | 9.465 | 10.31 | 5.246 |
| `err_theta_max_deg` | 0.02772 | 0.2873 | 0.5099 | 0.5357 | 0.2712 |
| `err_z_max_m` | 0.05483 | 0.1513 | 0.3516 | 0.3609 | 0.1665 |
| `V_min` | 0.8571 | 0.9004 | 0.9548 | 0.8535 | 0.9008 |
| `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `td_mean` | 0.0004036 | 0.0165 | 0.032 | 0.03216 | 0.0175 |
| `trip_dwell` | 0 | 0.975 | 1.975 | 2.075 | 0.9781 |
| `act_slew_max_degs` | 39.84 | 40 | 40 | 40 | 39.85 |
| `rail_dwell_dr_env` | 0 | 0 | 0.4033 | 0.5058 | 0.06741 |

## 15. Per-cell distributions

| Cell | KPI | nominal | P5 | P50 | P95 | worst |
|---|---|---|---|---|---|---|
| `X_U1.0` | `cte_mean` | 0.1404 | 0.03603 | 0.1535 | 0.2764 | 0.2874 |
| `X_U1.0` | `cte_max` | 0.2003 | 0.06553 | 0.2416 | 0.3863 | 0.4096 |
| `X_U1.0` | `depth_err_max` | 0.2003 | 0.05138 | 0.2211 | 0.3852 | 0.4062 |
| `X_U1.0` | `u_err_rms` | 0.7958 | 0.7828 | 0.8036 | 0.827 | 0.8284 |
| `X_U1.0` | `theta_absmax_deg` | 1.736 | 1.586 | 1.848 | 2.091 | 2.11 |
| `X_U1.0` | `de_absmax` | 6.826 | 6.285 | 7.096 | 7.814 | 8.007 |
| `X_U1.0` | `dr_absmax` | 0 | 1.658 | 24.57 | 25 | 25 |
| `X_U1.0` | `thr_max` | 25.89 | 24.58 | 25.91 | 27.4 | 27.61 |
| `X_U1.0` | `energy_thrust` | 185.4 | 180 | 183.7 | 186.6 | 188 |
| `X_U1.0` | `energy_fin` | 0.6879 | 0.7332 | 4.593 | 7.028 | 7.085 |
| `X_U1.0` | `err_theta_max_deg` | 0 | 0.0167 | 0.2782 | 0.5013 | 0.5153 |
| `X_U1.0` | `err_z_max_m` | 0 | 0.0554 | 0.1534 | 0.3496 | 0.3609 |
| `X_U1.0` | `V_min` | 1 | 0.8571 | 0.9002 | 0.9543 | 0.8538 |
| `X_U1.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `X_U1.0` | `td_mean` | 0 | 0.0004295 | 0.01649 | 0.03199 | 0.03212 |
| `X_U1.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `X_U1.0` | `act_slew_max_degs` | 40 | 39.74 | 40 | 40 | 40 |
| `X_U1.0` | `rail_dwell_dr_env` | 0 | 0 | 0 | 0.003167 | 0.003333 |
| `X_U1.5` | `cte_mean` | 0.1367 | 0.04017 | 0.1527 | 0.2833 | 0.2897 |
| `X_U1.5` | `cte_max` | 0.1844 | 0.07349 | 0.2252 | 0.394 | 0.4015 |
| `X_U1.5` | `depth_err_max` | 0.1844 | 0.05849 | 0.211 | 0.3917 | 0.3991 |
| `X_U1.5` | `u_err_rms` | 0.309 | 0.2949 | 0.3148 | 0.3367 | 0.3394 |
| `X_U1.5` | `theta_absmax_deg` | 1.69 | 1.565 | 1.817 | 2.081 | 2.209 |
| `X_U1.5` | `de_absmax` | 5.608 | 5.466 | 5.677 | 5.955 | 5.965 |
| `X_U1.5` | `dr_absmax` | 0 | 3.44 | 24.76 | 24.98 | 24.98 |
| `X_U1.5` | `thr_max` | 13.39 | 12.52 | 13.44 | 14.37 | 14.52 |
| `X_U1.5` | `energy_thrust` | 172 | 166 | 169.5 | 173.8 | 173.9 |
| `X_U1.5` | `energy_fin` | 0.6743 | 0.8695 | 4.477 | 6.975 | 7.065 |
| `X_U1.5` | `err_theta_max_deg` | 0 | 0.02687 | 0.284 | 0.5014 | 0.5119 |
| `X_U1.5` | `err_z_max_m` | 0 | 0.05528 | 0.1534 | 0.3496 | 0.3608 |
| `X_U1.5` | `V_min` | 1 | 0.8571 | 0.9001 | 0.9539 | 0.8535 |
| `X_U1.5` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `X_U1.5` | `td_mean` | 0 | 0.0004276 | 0.01652 | 0.03197 | 0.03216 |
| `X_U1.5` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `X_U1.5` | `act_slew_max_degs` | 40 | 38.92 | 40 | 40 | 40 |
| `X_U1.5` | `rail_dwell_dr_env` | 0 | 0 | 0 | 0.0008333 | 0.0008333 |
| `X_U2.0` | `cte_mean` | 0.1347 | 0.04053 | 0.1474 | 0.2804 | 0.2828 |
| `X_U2.0` | `cte_max` | 0.1757 | 0.07651 | 0.2274 | 0.3868 | 0.3905 |
| `X_U2.0` | `depth_err_max` | 0.1757 | 0.06514 | 0.1972 | 0.3839 | 0.3869 |
| `X_U2.0` | `u_err_rms` | 0.178 | 0.154 | 0.1746 | 0.1931 | 0.1935 |
| `X_U2.0` | `theta_absmax_deg` | 1.664 | 1.599 | 1.802 | 2.096 | 2.101 |
| `X_U2.0` | `de_absmax` | 5.227 | 5.313 | 5.684 | 6.095 | 6.26 |
| `X_U2.0` | `dr_absmax` | 0 | 2.82 | 24.34 | 25 | 25 |
| `X_U2.0` | `thr_max` | 5.488 | 5.314 | 5.414 | 5.547 | 5.6 |
| `X_U2.0` | `energy_thrust` | 159 | 152.2 | 155.8 | 160.3 | 161.6 |
| `X_U2.0` | `energy_fin` | 0.6648 | 0.8507 | 4.624 | 7.097 | 7.208 |
| `X_U2.0` | `err_theta_max_deg` | 0 | 0.03549 | 0.2874 | 0.5092 | 0.5178 |
| `X_U2.0` | `err_z_max_m` | 0 | 0.0552 | 0.1533 | 0.3496 | 0.3609 |
| `X_U2.0` | `V_min` | 1 | 0.8584 | 0.9008 | 0.9535 | 0.8549 |
| `X_U2.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `X_U2.0` | `td_mean` | 0 | 0.0004279 | 0.01653 | 0.032 | 0.03213 |
| `X_U2.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `X_U2.0` | `act_slew_max_degs` | 40 | 37.55 | 40 | 40 | 40 |
| `X_U2.0` | `rail_dwell_dr_env` | 0 | 0 | 0 | 0.0025 | 0.004167 |
| `XZ_U1.0` | `cte_mean` | 0.1886 | 0.06029 | 0.1985 | 0.3228 | 0.3354 |
| `XZ_U1.0` | `cte_max` | 0.3832 | 0.1831 | 0.3945 | 0.5617 | 0.5881 |
| `XZ_U1.0` | `depth_err_max` | 0.3813 | 0.1807 | 0.3913 | 0.5587 | 0.5844 |
| `XZ_U1.0` | `u_err_rms` | 0.7884 | 0.7752 | 0.7958 | 0.8196 | 0.82 |
| `XZ_U1.0` | `theta_absmax_deg` | 8.176 | 7.944 | 8.285 | 8.533 | 8.539 |
| `XZ_U1.0` | `de_absmax` | 6.826 | 6.284 | 7.097 | 7.808 | 8.007 |
| `XZ_U1.0` | `dr_absmax` | 0 | 1.658 | 24.58 | 25 | 25 |
| `XZ_U1.0` | `thr_max` | 25.89 | 24.58 | 25.91 | 27.4 | 27.61 |
| `XZ_U1.0` | `energy_thrust` | 190.9 | 185.4 | 189.1 | 192.1 | 193.4 |
| `XZ_U1.0` | `energy_fin` | 0.6187 | 0.6631 | 4.506 | 6.866 | 6.97 |
| `XZ_U1.0` | `err_theta_max_deg` | 0 | 0.0474 | 0.28 | 0.5123 | 0.5357 |
| `XZ_U1.0` | `err_z_max_m` | 0 | 0.05618 | 0.1513 | 0.3463 | 0.3609 |
| `XZ_U1.0` | `V_min` | 1 | 0.8571 | 0.9002 | 0.9543 | 0.8538 |
| `XZ_U1.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `XZ_U1.0` | `td_mean` | 0 | 0.0004223 | 0.01652 | 0.03205 | 0.03216 |
| `XZ_U1.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `XZ_U1.0` | `act_slew_max_degs` | 40 | 38.85 | 40 | 40 | 40 |
| `XZ_U1.0` | `rail_dwell_dr_env` | 0 | 0 | 0 | 0.002333 | 0.003333 |
| `XZ_U1.5` | `cte_mean` | 0.1846 | 0.06331 | 0.1969 | 0.3307 | 0.3343 |
| `XZ_U1.5` | `cte_max` | 0.3671 | 0.1975 | 0.3845 | 0.5696 | 0.5712 |
| `XZ_U1.5` | `depth_err_max` | 0.3653 | 0.1952 | 0.3796 | 0.5653 | 0.5666 |
| `XZ_U1.5` | `u_err_rms` | 0.3015 | 0.2873 | 0.3061 | 0.3289 | 0.3312 |
| `XZ_U1.5` | `theta_absmax_deg` | 8.123 | 7.938 | 8.254 | 8.61 | 8.632 |
| `XZ_U1.5` | `de_absmax` | 5.797 | 5.84 | 6.065 | 6.441 | 6.443 |
| `XZ_U1.5` | `dr_absmax` | 0 | 3.516 | 24.5 | 25 | 25 |
| `XZ_U1.5` | `thr_max` | 13.39 | 12.52 | 13.44 | 14.37 | 14.52 |
| `XZ_U1.5` | `energy_thrust` | 177.6 | 171.4 | 175.3 | 179.1 | 181.3 |
| `XZ_U1.5` | `energy_fin` | 0.6028 | 0.7933 | 4.53 | 6.873 | 7.019 |
| `XZ_U1.5` | `err_theta_max_deg` | 0 | 0.04311 | 0.2859 | 0.5158 | 0.5214 |
| `XZ_U1.5` | `err_z_max_m` | 0 | 0.05611 | 0.1513 | 0.346 | 0.3609 |
| `XZ_U1.5` | `V_min` | 1 | 0.8571 | 0.9001 | 0.9539 | 0.8535 |
| `XZ_U1.5` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `XZ_U1.5` | `td_mean` | 0 | 0.0004296 | 0.0165 | 0.03199 | 0.03209 |
| `XZ_U1.5` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `XZ_U1.5` | `act_slew_max_degs` | 40 | 39.63 | 40 | 40 | 40 |
| `XZ_U1.5` | `rail_dwell_dr_env` | 0 | 0 | 0 | 0.001667 | 0.0025 |
| `XZ_U2.0` | `cte_mean` | 0.1831 | 0.06332 | 0.1933 | 0.3297 | 0.3332 |
| `XZ_U2.0` | `cte_max` | 0.3599 | 0.1917 | 0.3735 | 0.5645 | 0.5686 |
| `XZ_U2.0` | `depth_err_max` | 0.3581 | 0.1889 | 0.3709 | 0.5612 | 0.5644 |
| `XZ_U2.0` | `u_err_rms` | 0.1861 | 0.1619 | 0.1832 | 0.2014 | 0.2016 |
| `XZ_U2.0` | `theta_absmax_deg` | 8.097 | 7.922 | 8.245 | 8.458 | 8.582 |
| `XZ_U2.0` | `de_absmax` | 5.775 | 5.824 | 6.035 | 6.445 | 6.555 |
| `XZ_U2.0` | `dr_absmax` | 0 | 2.854 | 24.37 | 25 | 25 |
| `XZ_U2.0` | `thr_max` | 5.94 | 5.774 | 5.9 | 6.164 | 6.209 |
| `XZ_U2.0` | `energy_thrust` | 164.7 | 157.8 | 161.5 | 165.9 | 166 |
| `XZ_U2.0` | `energy_fin` | 0.5912 | 0.7739 | 4.451 | 6.987 | 7.071 |
| `XZ_U2.0` | `err_theta_max_deg` | 0 | 0.05376 | 0.2896 | 0.517 | 0.5236 |
| `XZ_U2.0` | `err_z_max_m` | 0 | 0.05605 | 0.1512 | 0.3456 | 0.3609 |
| `XZ_U2.0` | `V_min` | 1 | 0.8578 | 0.9006 | 0.9534 | 0.8549 |
| `XZ_U2.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `XZ_U2.0` | `td_mean` | 0 | 0.0004355 | 0.01649 | 0.03202 | 0.03209 |
| `XZ_U2.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `XZ_U2.0` | `act_slew_max_degs` | 40 | 39.79 | 40 | 40 | 40 |
| `XZ_U2.0` | `rail_dwell_dr_env` | 0 | 0 | 0 | 0.003083 | 0.004167 |
| `R10_U1.5` | `cte_mean` | 0.2123 | 0.1227 | 0.2488 | 0.3519 | 0.3704 |
| `R10_U1.5` | `cte_max` | 0.2857 | 0.2658 | 0.4361 | 0.5872 | 0.7598 |
| `R10_U1.5` | `depth_err_max` | 0.2206 | 0.1467 | 0.2405 | 0.3981 | 0.4355 |
| `R10_U1.5` | `u_err_rms` | 0.09038 | 0.07843 | 0.09467 | 0.1148 | 0.1154 |
| `R10_U1.5` | `theta_absmax_deg` | 4.672 | 4.444 | 4.706 | 4.962 | 5.038 |
| `R10_U1.5` | `de_absmax` | 6.592 | 6.313 | 6.654 | 6.904 | 6.926 |
| `R10_U1.5` | `dr_absmax` | 25 | 25 | 25 | 25 | 25 |
| `R10_U1.5` | `thr_max` | 13.25 | 12.39 | 13.3 | 14.23 | 14.37 |
| `R10_U1.5` | `energy_thrust` | 138 | 131.9 | 137.3 | 142.4 | 142.7 |
| `R10_U1.5` | `energy_fin` | 7.504 | 5.956 | 8.069 | 9.994 | 10.31 |
| `R10_U1.5` | `err_theta_max_deg` | 0 | 0.02345 | 0.2784 | 0.5008 | 0.5128 |
| `R10_U1.5` | `err_z_max_m` | 0 | 0.05384 | 0.1519 | 0.3479 | 0.3577 |
| `R10_U1.5` | `V_min` | 1 | 0.8571 | 0.9001 | 0.9539 | 0.8535 |
| `R10_U1.5` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `R10_U1.5` | `td_mean` | 0 | 0.0004202 | 0.0165 | 0.03197 | 0.03203 |
| `R10_U1.5` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `R10_U1.5` | `act_slew_max_degs` | 40 | 40 | 40 | 40 | 40 |
| `R10_U1.5` | `rail_dwell_dr_env` | 0.2817 | 0.07983 | 0.2717 | 0.4795 | 0.5058 |
| `R10_U2.0` | `cte_mean` | 0.204 | 0.1226 | 0.2316 | 0.349 | 0.3714 |
| `R10_U2.0` | `cte_max` | 0.2946 | 0.2605 | 0.4298 | 0.7353 | 0.8263 |
| `R10_U2.0` | `depth_err_max` | 0.2151 | 0.1482 | 0.2361 | 0.3978 | 0.4263 |
| `R10_U2.0` | `u_err_rms` | 0.4166 | 0.3973 | 0.4145 | 0.4345 | 0.4373 |
| `R10_U2.0` | `theta_absmax_deg` | 4.604 | 4.375 | 4.732 | 4.994 | 5.075 |
| `R10_U2.0` | `de_absmax` | 6.307 | 6.182 | 6.461 | 6.727 | 6.824 |
| `R10_U2.0` | `dr_absmax` | 25 | 25 | 25 | 25 | 25 |
| `R10_U2.0` | `thr_max` | 4.882 | 4.815 | 4.932 | 5.121 | 5.299 |
| `R10_U2.0` | `energy_thrust` | 126.4 | 119.1 | 123.8 | 128.3 | 129 |
| `R10_U2.0` | `energy_fin` | 6.719 | 5.96 | 8.032 | 9.976 | 10.03 |
| `R10_U2.0` | `err_theta_max_deg` | 0 | 0.02682 | 0.2777 | 0.499 | 0.5353 |
| `R10_U2.0` | `err_z_max_m` | 0 | 0.05384 | 0.1518 | 0.3481 | 0.3579 |
| `R10_U2.0` | `V_min` | 1 | 0.8574 | 0.8998 | 0.9527 | 0.8539 |
| `R10_U2.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `R10_U2.0` | `td_mean` | 0 | 0.0004131 | 0.01652 | 0.0321 | 0.03215 |
| `R10_U2.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `R10_U2.0` | `act_slew_max_degs` | 40 | 40 | 40 | 40 | 40 |
| `R10_U2.0` | `rail_dwell_dr_env` | 0.1967 | 0.082 | 0.2729 | 0.4487 | 0.4575 |

## 16. Sensitivity (Spearman rank correlation)

- **cte_max**: `dep_bias` 0.660 (SUPPORTED), `imu_bias_theta` -0.427 (SUPPORTED), `imu_bias_phi` -0.362 (SUPPORTED), `cb_dz` -0.236 (UNSUPPORTED), `cb_dx` 0.224 (UNSUPPORTED), `imu_delay` 0.192 (SUPPORTED)
- **cte_mean**: `dep_bias` 0.835 (SUPPORTED), `imu_bias_theta` -0.567 (SUPPORTED), `imu_bias_phi` -0.447 (SUPPORTED), `cb_dz` -0.336 (UNSUPPORTED), `cb_dx` 0.310 (UNSUPPORTED), `imu_bias_psi` 0.265 (SUPPORTED)
- **depth_err_max**: `dep_bias` 0.765 (SUPPORTED), `imu_bias_theta` -0.521 (SUPPORTED), `imu_bias_phi` -0.414 (SUPPORTED), `cb_dz` -0.337 (UNSUPPORTED), `cb_dx` 0.305 (UNSUPPORTED), `imu_bias_psi` 0.276 (SUPPORTED)
- **u_err_rms**: `dvl_bias_u` -0.052 (SUPPORTED), `gain_thrust` 0.036 (SUPPORTED), `dvl_bias_w` -0.030 (SUPPORTED), `imu_bias_phi` -0.028 (SUPPORTED), `dvl_lock_loss_t0f` 0.022 (SUPPORTED), `tau_thrust` 0.022 (SUPPORTED)
- **de_absmax**: `imu_delay` 0.109 (SUPPORTED), `imu_bias_theta` -0.075 (SUPPORTED), `dvl_delay` 0.068 (SUPPORTED), `dvl_lock_loss_dur` 0.061 (SUPPORTED), `imu_bias_psi` 0.056 (SUPPORTED), `dep_bias` 0.055 (SUPPORTED)
- **dr_absmax**: `td_transport` 0.266 (SUPPORTED), `load_scale` -0.212 (PARTIAL), `dvl_lock_loss_dur` 0.202 (SUPPORTED), `cb_dx` 0.197 (UNSUPPORTED), `dep_bias` 0.170 (SUPPORTED), `jitter_max` -0.165 (SUPPORTED)
- **energy_thrust**: `dvl_bias_u` -0.097 (SUPPORTED), `dvl_bias_w` -0.067 (SUPPORTED), `jitter_max` 0.057 (SUPPORTED), `gain_thrust` 0.053 (SUPPORTED), `dvl_lock_loss_t0f` 0.048 (SUPPORTED), `imu_drop_p` 0.043 (SUPPORTED)
- **err_theta_max_deg**: `imu_bias_theta` -0.374 (SUPPORTED), `slew_thrust` 0.364 (SUPPORTED), `dep_disagree_dur` -0.346 (SUPPORTED), `k_ir_scale` -0.305 (PARTIAL), `imu_bias_p` 0.268 (SUPPORTED), `cb_dx` 0.244 (UNSUPPORTED)
- **V_min**: `V0` 0.935 (PARTIAL), `td_transport` -0.472 (SUPPORTED), `dvl_delay` 0.410 (SUPPORTED), `dvl_bias_v` 0.376 (SUPPORTED), `dep_disagree_t0f` 0.368 (SUPPORTED), `dvl_bias_w` 0.303 (SUPPORTED)
- **td_mean**: `td_transport` 0.938 (SUPPORTED), `gain_thrust` 0.483 (SUPPORTED), `V0` -0.482 (PARTIAL), `dvl_delay` -0.342 (SUPPORTED), `dep_disagree_dur` -0.317 (SUPPORTED), `cg_dz` -0.312 (UNSUPPORTED)
- **act_slew_max_degs**: `td_transport` 0.333 (SUPPORTED), `V0` -0.280 (PARTIAL), `load_scale` -0.249 (PARTIAL), `tau_fin` 0.213 (SUPPORTED), `dvl_bias_u` -0.203 (SUPPORTED), `cb_dx` 0.192 (UNSUPPORTED)

A factor that was never injected cannot influence any KPI, so any non-zero coefficient on an UNSUPPORTED factor is finite-sample noise over 32 distinct draw values replicated across 8 cells. It must not be read as sensitivity in either direction. This corrects the attempt-1 wording, which claimed such coefficients would be near zero; its own table disproved that.

## 17. Pareto vector

| Axis | Metric | Nominal (median over cells) | MC P50 | MC P95 | MC worst | Status |
|---|---|---|---|---|---|---|
| Tracking | `cte_max` | 0.2901 | 0.3411 | 0.5626 | 0.8263 | REPORTED |
| ActuatorMargin | `act_margin_de` | 8.948 | 8.702 | 9.477 | 6.993 | REPORTED |
| Energy | `energy_thrust` | 168.4 | 166 | 189.5 | 193.4 | REPORTED |
| Estimation | `err_theta_max_deg` | 0 | 0.2873 | 0.5099 | 0.5357 | PARTIAL - measured-vs-truth only; no estimator/NEES on the production path |
| Timing | `td_mean` | 0 | 0.0165 | 0.032 | 0.03216 | PARTIAL - simulated command transport delay only; target WCET/deadline TO_BE_IDENTIFIED |
| Safety | `trip_dwell` | 0 | 0.975 | 1.975 | 2.075 | REPORTED |

## 18. Gate 7 mission / FDIR 16-case matrix - carried, still NOT re-drawn

HG12 remains an honest failure. The 16 cases were not re-simulated under the Monte Carlo priors; their harness is a separate driver outside this task 3-source budget, and reconstructing FDIR dynamics from recorded logs would be fabrication. The accepted values are reproduced only as the reference a future task must reproduce.

| # | Case | Recovery class | cte_max [m] | depth_min [m] | depth_max [m] | V_min [pu] | surface | accommodation | direct-actuator | MC re-drawn |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | NOMINAL | not_applicable_no_degradation | 7.594 | 3 | 6.683 | 0.992 | 0 | 0 | 0 | NO |
| 2 | INVALID_SCHEMA_FRAME_INTEGRITY | must_recover | 7.741 | 3 | 5.956 | 0.9901 | 0 | 0 | 0 | NO |
| 3 | OUT_OF_ORDER_REPLAY | must_recover | 7.566 | 3 | 6.13 | 0.9902 | 0 | 0 | 0 | NO |
| 4 | EXPIRED_SEGMENT | must_recover | 7.566 | 3 | 6.13 | 0.9902 | 0 | 0 | 0 | NO |
| 5 | MISSION_HEARTBEAT_LOSS | must_recover | 7.741 | 3 | 5.956 | 0.9901 | 0 | 0 | 0 | NO |
| 6 | BUS_TIMEOUT | must_recover | 7.647 | 3 | 6.01 | 0.9901 | 0 | 0 | 0 | NO |
| 7 | STALE_IMU | must_recover | 7.579 | 3 | 6.178 | 0.9902 | 0 | 0 | 0 | NO |
| 8 | STALE_DVL | must_recover | 7.747 | 3 | 5.957 | 0.9901 | 0 | 0 | 0 | NO |
| 9 | STALE_DEPTH | must_recover | 7.548 | 3 | 6.049 | 0.9901 | 0 | 0 | 0 | NO |
| 10 | ACTUATOR_STUCK_CURRENT | must_recover | 7.487 | 3 | 6.168 | 0.9902 | 0 | 0 | 0 | NO |
| 11 | UNDERVOLTAGE | must_recover | 7.393 | 3 | 6.324 | 0.812 | 0 | 0 | 0 | NO |
| 12 | LEAK | must_not_recover | 0.05681 | 3 | 4.653 | 0.992 | 0 | 0 | 0 | NO |
| 13 | WATCHDOG_OVERRUN | must_recover | 6.944 | 3 | 6.327 | 0.9903 | 0 | 0 | 0 | NO |
| 14 | CONFOUNDER_BENIGN | not_applicable_no_degradation | 7.382 | 3 | 9.021 | 0.912 | 0 | 0 | 0 | NO |
| 15 | MULTI_FAULT_PRECEDENCE | must_not_recover | 0.05681 | 3 | 4.289 | 0.812 | 0 | 0 | 0 | NO |
| 16 | FORBIDDEN_MISSION_COMMANDS | must_recover | 7.805 | 3 | 5.992 | 0.9901 | 0 | 0 | 0 | NO |

## 19. Visual QA (programmatic)

visual QA is programmatic: every figure file is re-opened after writing, its pixel dimensions are read back, and the series it claims to show are re-checked against the recorded run data. Nothing here is a human impression.

**Verdict: VISUAL_QA_PASS.**

| Check | Pass | Detail |
|---|---|---|
| `files_written` | 1 | 6/6 PNG files exist, exceed 8 KiB and are at least 600x400 px |
| `no_nan_in_plotted_logs` | 1 | 16200 logged samples x 18 columns, all finite |
| `log_coverage` | 1 | 54 time-series logs retained (all 8 nominal cells plus MC draws) |
| `slew_curve_bounded` | 1 | max realized fin slew over 256 MC runs = 40.0000 deg/s against the declared 40 deg/s |
| `magnitude_curve_bounded` | 1 | max realized elevator 8.0066 deg (limit 15), max realized rudder 25.0000 deg (limit 25) |
| `rail_evidence_preserved` | 1 | 2 of 8 nominal cells still show the production rudder at the 25 deg rail |
| `iss_counters_zero` | 1 | the three forbidden-response counters are zero in every run and are retained as zero evidence |
| `axis_labels_carry_units` | 1 | every plotted axis is labelled with its unit and frame: positions m NED, depth m positive down, fin deflection deg, fin slew deg/s, voltage pu, time s, thrust in the native production thrust unit which this task does not assume to be per-unit |
| `tex_interpreter_disabled` | 1 | all titles, legends and tick labels are drawn with Interpreter none, so underscored names render literally (attempt-1 defect E5 closed) |

| Figure | Size [KiB] | Pixels | OK |
|---|---|---|---|
| `GATE8_ACTUATOR_ORDER_SCAN_REPAIR.png` | 218.3 | 1925x1330 | 1 |
| `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_01_verification.png` | 53.7 | 1490x1032 | 1 |
| `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_02_limiter_order.png` | 76.5 | 1605x911 | 1 |
| `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_03_rail_evidence.png` | 125.5 | 1605x911 | 1 |
| `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_04_truth_measured_power.png` | 170.6 | 1490x871 | 1 |
| `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_05_sensitivity.png` | 47.8 | 1719x871 | 1 |

## 20. Honesty ledger

| Claim | Status |
|---|---|
| CG / CB / buoyancy priors injected into the plant | **UNSUPPORTED, unchanged** - drawn and stored, never applied; production `underwater777_vehicle_dynamics.m` exposes no shadow parameter seam and editing production is forbidden |
| Battery / power / brownout | **PARTIAL and partly UNEXERCISED** - the voltage sag model was injected and moved the bus, but the minimum voltage stayed above the brownout threshold in every run, so the detection and thrust-authority derate branch was never entered |
| Estimated streams | **NOT_IMPLEMENTED** - no estimator on the production tracking path; horizontal position is passed as truth and labelled, not faked |
| Timing / WCET | **PARTIAL** - simulated command transport delay and jitter only; target period, deadline, WCET and overrun remain TO_BE_IDENTIFIED |
| Watchdog / mission / bus / leak / actuator-current monitors | **UNSUPPORTED on this path** - no mission bus exists in the tracking loop; only IMU, DVL and depth staleness plus undervoltage are reachable |
| Frozen production cell definitions | **ASSUMED_RECONSTRUCTION** - byte-identical to attempt 1, which makes the comparison valid but does not make the geometry frozen |
| Rate-violation population of attempt 1 | **HARNESS DEFECT, now repaired** - it measured limiter ordering inside the shadow driver, never the vehicle |
| R10 rudder rail and dwell | **GENUINE EVIDENCE, preserved** - measured on the hooks-off path that is bit-identical to production |
| Every prior label | ASSUMED (no ASSUMED to IDENTIFIED upgrade anywhere) |
| Hardware | NOT_CERTIFIED. A simulation result is never hardware certification. |

## 21. Artifacts

- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR.png`
- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR_01_verification.png`
- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR_02_limiter_order.png`
- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR_03_rail_evidence.png`
- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR_04_truth_measured_power.png`
- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR_05_sensitivity.png`
- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR_06_visual_qa.png`
- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR.md`
- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR.mat`
- `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR_run.log`

Total footprint 0.79 MiB (< 300 MiB: 1).

## 22. Next exact task (one, bounded, structural)

**`gate8_frozen_cell_and_plant_seam_closure`** - one bounded structural task that closes the three remaining Gate 8 failures at their common root, which is that the campaign currently has no verified stimulus definition and no plant-parameter entry point. It has three parts and one acceptance rule.

1. **Frozen cells (HG13).** Bind the campaign to the actual frozen X / XZ / R10 cell definitions by loading their waypoints, horizon, initial state and speed schedule from the accepted per-cell evidence records rather than re-declaring them in the harness, and record a byte-level provenance fingerprint for each. Where a frozen definition genuinely differs from the reconstruction used in attempts 1 and 2, report the difference instead of absorbing it.
2. **Gate 7 matrix (HG12).** Re-drive the 16-case mission and FDIR matrix through this same shadow loop under the same 32 draw vectors, reusing the recorded Gate 7 fault schedule so the cases are injected rather than reconstructed, and re-score recovery class per case under the priors.
3. **Shadow CG / CB / buoyancy seam (HG11).** Add a shadow-only, read-only reducible clone of the plant carrying the same BEGIN / ORIG / END reduction contract that `continuous_path_tracking_propulsion.m` already proves, so the seven plant-parameter priors can physically enter the dynamics without editing production, plus a mechanical reduction gate showing the clone reduces byte-identically to production.

**Acceptance rule, parity-first:** at the zero draw and with the frozen cells bound, the clone must reproduce the nominal hashes recorded in this report bit-for-bit before a single Monte Carlo metric is compared. One MATLAB invocation, isolated artifacts, no production edit, no new prior, no threshold change. Gate 8 is re-scored only after all three parts exist together, because scoring any one of them alone would leave the other two silently carrying the result.

No brand, no purchase, no MCU selection. `CODEX_VERTICAL_PLAN.md` untouched. All priors remain **ASSUMED**. Hardware remains **NOT_CERTIFIED**. Gate 9 remains **locked**; Gate 9B remains post-Gate 9.
