# GATE8_MONTE_CARLO_INDEPENDENT_PRIORS - FAIL

**TASK_ID:** `GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001`  
**Date:** 2026-08-09 02:02:08  
**Class:** Gate 8 isolated Monte Carlo distribution campaign (shadow-only driver + hooks)  
**MATLAB runs:** 1 (single bounded invocation, no retry)  
**Production / CODEX_VERTICAL_PLAN:** untouched  
**Physical / hardware readiness:** **NOT_CERTIFIED**  
**Host runtime:** 5618.2 s  

## 1. Verdict

**FAIL.**

Gate 8 is **FAIL**. The distribution campaign itself ran clean on the reachable factors, but the gate cannot be claimed PASS because the following hard gates did not pass: **HG5, HG8, HG11, HG12, HG13**. Nothing was narrowed, re-scoped or faked to hide this.

Gate 9 stays **locked** (unlocks only on Gate 8 PASS). Gate 9B remains post-Gate 9.

## 2. Sources (exactly 3, no repo scan)

| # | Path | Fingerprint |
|---|------|-------------|
| 1 | `continuous_path_tracking_propulsion.m` | `n=15861.s1=1261880.s2=1306658324` |
| 2 | `suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat` | `n=723780.s1=93292499.s2=622488880` |
| 3 | `suite_results/AUTONOMOUS_EXECUTION_POLICY.md` | `n=13378.s1=1135839.s2=3317405631` |

Gate 7 precondition: `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001` verdict = **PASS** (16 FDIR cases).

## 3. Gate 0 hygiene / frames

| Item | Value |
|------|-------|
| Free disk at start | 4.41 GiB (>= 3 GiB required: 1; >= 5 GiB preferred: 0) |
| frames.position | NED inertial [m]; z positive DOWN (depth = +z) |
| frames.rates | BODY angular rates p,q,r [rad/s]; BODY velocity u,v,w [m/s] |
| frames.euler | phi,theta,psi [rad] internally (deg only where a name says _deg) |
| frames.pitch_sign | theta > 0 = nose UP = depth decreasing |
| frames.actuators | delta_e, delta_r signed per production convention; thrust pu |
| frames.units | SI (m, m/s, rad, rad/s, s); deg only where labelled |
| frames.source_ref | GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat R.frames (frozen, not re-derived) |
| frames.label | INTERFACE_SPECIFIED |

Production fingerprints (pre / post / Gate 7 record):

| File | pre | post | == Gate 7 |
|------|-----|------|-----------|
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | `n=10845.s1=886194.s2=515073390` | 1 |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | `n=9402.s1=732890.s2=3334742186` | 1 |
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | `n=14601.s1=1095745.s2=3464382495` | 1 |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | `n=6065.s1=426918.s2=1254438441` | 1 |
| `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990739` | `n=11604.s1=883372.s2=792990739` | 1 |
| `suite_results/CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | `n=43101.s1=4310210.s2=3268810005` | 1 |

Fingerprint formula `n=<bytes>.s1=<sum>.s2=<mod(sum(i*b_i),2^32)>` is the same one the accepted Gate 7 evidence used, so the values above are directly comparable.

Clone-reduction diagnostic (`continuous_path_tracking_propulsion.m` -> `continuous_path_tracking.m`): checked=1, exact=1, differing lines=0. clone reduced to 244 lines vs production 244 lines; 0 differing lines

## 4. Campaign definition

| Item | Value |
|------|-------|
| Recorded seed | `20260809` (fixed; one independent mt19937ar substream per factor, one per run) |
| Draw vectors | 32 independent vectors, the same 32 applied to every cell (common random numbers) |
| Cells | 8: X U={1.0,1.5,2.0}, XZ U={1.0,1.5,2.0}, R10 U={1.5,2.0} |
| Step / horizon | dt = 0.025 s, T_final = 30 s |
| MC runs | 8 nominal + 256 Monte Carlo + 32 replay |
| Replay subset | draws [1 16 32], executed in reverse cell and draw order |

**Cell provenance (read this before quoting any number):** ASSUMED_RECONSTRUCTION - the frozen X / XZ / R10 cell definitions (waypoints, horizon, initial state, u_ref schedule) live in per-cell driver scripts that are outside this task 3-source budget. Geometry here is harness-declared, NOT the frozen production cell. U labels the initial BODY surge trim; u_ref is owned internally by production guidance_law.

**Actuator envelope provenance:** fin magnitude/rate envelope = Gate 7 declared 15 deg / 25 deg / 40 deg/s converted to radians (production delta_e, delta_r are radians); thrust envelope derived per cell from that cell nominal command range with 25 percent ASSUMED headroom, because no source establishes the production thrust unit

| Cell | nominal max abs delta_e [deg] | nominal max abs delta_r [deg] | nominal max abs thrust [native units] | thrust rail used |
|---|---|---|---|---|
| `X_U1.0` | 6.826 | 0.000 | 25.89 | 32.36 |
| `X_U1.5` | 5.608 | 0.000 | 13.39 | 16.74 |
| `X_U2.0` | 5.227 | 0.000 | 5.488 | 6.86 |
| `XZ_U1.0` | 6.826 | 0.000 | 25.89 | 32.36 |
| `XZ_U1.5` | 5.797 | 0.000 | 13.39 | 16.74 |
| `XZ_U2.0` | 5.775 | 0.000 | 5.94 | 7.425 |
| `R10_U1.5` | 6.592 | 25.000 | 13.25 | 16.56 |
| `R10_U2.0` | 6.307 | 25.000 | 4.882 | 6.103 |

If a nominal fin column already sits at or above the 15 / 25 deg Gate 3 envelope, the saturation dwell reported below is a statement about that ASSUMED envelope, not about the Monte Carlo draws.

## 5. Prior table - independent, unchanged, all ASSUMED

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

25 SUPPORTED, 3 PARTIAL, 7 UNSUPPORTED. No prior was narrowed. UNSUPPORTED factors are still **drawn and stored** in `R.draws` so the campaign can be replayed unchanged the moment a plant-parameter interface exists.

## 6. Hard gates

| ID | Requirement | Pass | Detail |
|---|---|---|---|
| HG1 | Exact nominal parity: shadow loop with all hooks off reproduces the unmodified production continuous_path_tracking bit-for-bit in every cell | PASS | bit-identical on vp/t/vel/av/ori/yaw_ref/pitch_ref/u_ref | bit-identical on vp/t/vel/av/ori/yaw_ref/pitch_ref/u_ref | bit-identical on vp/t/vel/av/ori/yaw_ref/pitch_ref/u_ref | bit-identical on vp/t/vel/av/ori/yaw_ref/pitch_ref/u_ref | bit-identical on vp/t/vel/av/ori/yaw_ref/pitch_ref/u_ref | bit-identical on vp/t/vel/av/ori/yaw_ref/pitch_ref/u_ref | bit-identical on vp/t/vel/av/ori/yaw_ref/pitch_ref/u_ref | bit-identical on vp/t/vel/av/ori/yaw_ref/pitch_ref/u_ref |
| HG2 | Deterministic draw/replay: reverse-order re-execution reproduces every replayed run hash bit-for-bit | PASS | 32/32 replay runs matched |
| HG3 | Finite bounded states in every run (no NaN/Inf, no early termination) | PASS | 264/264 finite, 264/264 complete |
| HG4 | Zero instability (divergence / |theta|>85 deg / |rate|>200 deg/s) | PASS | 0 unstable runs |
| HG5 | Zero hard magnitude / rate / saturation-rail violations (rail dwell <= 25 percent per channel) | **FAIL** | mag=0 rate=151 rail=2 |
| HG6 | Zero depth / collision violations (depth kept inside [1.0, 30.0] m) | PASS | 0 depth violations |
| HG7 | Zero watchdog / FDIR violations (monitor trips are constrain-or-hold, never unhandled) | PASS | fdir=0 wd=0, 200 benign monitor trips |
| HG8 | No surface / no automatic accommodation / no direct-actuator path anywhere in the shadow driver | **FAIL** | token scan clean=0; surface=0 accom=0 direct=0 |
| HG9 | Production + CODEX_VERTICAL_PLAN fingerprints unchanged, and identical to the accepted Gate 7 record | PASS | unchanged=1, gate7-identical=6/6 |
| HG10 | >= 32 independent draw vectors applied to every production cell (8 cells) | PASS | 32 draws x 8 cells = 256 MC runs |
| HG11 | Every declared prior is actually EXERCISED (drawn AND physically injected) | **FAIL** | 25 SUPPORTED / 3 PARTIAL / 7 UNSUPPORTED injections |
| HG12 | Gate 7 mission/FDIR 16-case matrix re-drawn under the MC priors | **FAIL** | carried forward as recorded reference only; harness not reproducible inside the 3-source budget |
| HG13 | Production cells are the FROZEN X / XZ / R10 definitions | **FAIL** | cell geometry is an ASSUMED_RECONSTRUCTION (frozen cell drivers outside the 3-source budget) |
| HG14 | truth / measured / estimated kept distinct | PASS | truth = plant state; measured = biased/delayed/dropped sensor stream feeding guidance+controller; estimated = NOT_IMPLEMENTED (no estimator on the production tracking path) |
| HG15 | Label honesty: every prior remains ASSUMED, no ASSUMED->IDENTIFIED upgrade | PASS | 35/35 ASSUMED |
| HG16 | No cherry-picking: every executed run is reported (pooled + per-cell), none dropped | PASS | 264 runs recorded / 264 executed |

## 7. Pass probability

Pooled: **103 / 256 = 0.4023**, Wilson 95% CI [0.3441, 0.4634].

| Cell | draws | pass | p | Wilson 95% CI |
|---|---|---|---|---|
| `X_U1.0` | 32 | 14 | 0.4375 | [0.2817, 0.6067] |
| `X_U1.5` | 32 | 13 | 0.4062 | [0.2552, 0.5774] |
| `X_U2.0` | 32 | 14 | 0.4375 | [0.2817, 0.6067] |
| `XZ_U1.0` | 32 | 15 | 0.4688 | [0.3087, 0.6355] |
| `XZ_U1.5` | 32 | 12 | 0.3750 | [0.2293, 0.5475] |
| `XZ_U2.0` | 32 | 14 | 0.4375 | [0.2817, 0.6067] |
| `R10_U1.5` | 32 | 11 | 0.3438 | [0.2041, 0.5169] |
| `R10_U2.0` | 32 | 10 | 0.3125 | [0.1795, 0.4857] |

## 8. Pooled distributions (all 256 MC runs, nothing dropped)

| KPI | P5 | P50 | P95 | worst | mean |
|---|---|---|---|---|---|
| `cte_mean` | 0.04952 | 0.2 | 0.3319 | 0.3715 | 0.1986 |
| `cte_max` | 0.1104 | 0.342 | 0.5652 | 0.8261 | 0.3442 |
| `depth_err_max` | 0.07333 | 0.287 | 0.5267 | 0.5847 | 0.2934 |
| `u_err_rms` | 0.0911 | 0.3104 | 0.8135 | 0.8284 | 0.3863 |
| `theta_absmax_deg` | 1.664 | 4.722 | 8.425 | 8.632 | 4.951 |
| `de_absmax` | 5.574 | 6.283 | 7.457 | 8.007 | 6.351 |
| `dr_absmax` | 2.635 | 24.85 | 25 | 25 | 22.21 |
| `thr_max` | 4.936 | 13.07 | 26.76 | 27.61 | 13.53 |
| `energy_thrust` | 122.7 | 165.9 | 189.6 | 193.7 | 162.1 |
| `energy_fin` | 0.7341 | 5.014 | 9.307 | 10.31 | 5.233 |
| `err_theta_max_deg` | 0.02772 | 0.2873 | 0.5089 | 0.5357 | 0.2713 |
| `err_z_max_m` | 0.05483 | 0.1512 | 0.3517 | 0.3609 | 0.1665 |
| `V_min` | 0.8571 | 0.9004 | 0.955 | 0.8535 | 0.9008 |
| `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `td_mean` | 0.0004036 | 0.0165 | 0.032 | 0.03216 | 0.0175 |
| `trip_dwell` | 0 | 0.975 | 1.975 | 2.075 | 0.9781 |

## 9. Per-cell distributions

| Cell | KPI | nominal | P5 | P50 | P95 | worst |
|---|---|---|---|---|---|---|
| `X_U1.0` | `cte_mean` | 0.1404 | 0.03618 | 0.1545 | 0.2761 | 0.2873 |
| `X_U1.0` | `cte_max` | 0.2003 | 0.06657 | 0.229 | 0.3876 | 0.4078 |
| `X_U1.0` | `depth_err_max` | 0.2003 | 0.0507 | 0.2208 | 0.3852 | 0.4062 |
| `X_U1.0` | `u_err_rms` | 0.7958 | 0.7828 | 0.8036 | 0.827 | 0.8284 |
| `X_U1.0` | `theta_absmax_deg` | 1.736 | 1.589 | 1.846 | 2.113 | 2.118 |
| `X_U1.0` | `de_absmax` | 6.826 | 6.281 | 7.096 | 7.81 | 8.006 |
| `X_U1.0` | `dr_absmax` | 0 | 1.657 | 24.27 | 24.99 | 25 |
| `X_U1.0` | `thr_max` | 25.89 | 24.58 | 25.91 | 27.4 | 27.61 |
| `X_U1.0` | `energy_thrust` | 185.4 | 179.9 | 183.6 | 187.5 | 188.1 |
| `X_U1.0` | `energy_fin` | 0.6879 | 0.7332 | 4.636 | 6.988 | 7.1 |
| `X_U1.0` | `err_theta_max_deg` | 0 | 0.01635 | 0.2782 | 0.5013 | 0.5153 |
| `X_U1.0` | `err_z_max_m` | 0 | 0.05537 | 0.1534 | 0.3495 | 0.3609 |
| `X_U1.0` | `V_min` | 1 | 0.8571 | 0.9002 | 0.9543 | 0.8538 |
| `X_U1.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `X_U1.0` | `td_mean` | 0 | 0.0004295 | 0.01649 | 0.03199 | 0.03212 |
| `X_U1.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `X_U1.5` | `cte_mean` | 0.1367 | 0.03873 | 0.1521 | 0.2832 | 0.2862 |
| `X_U1.5` | `cte_max` | 0.1844 | 0.06963 | 0.2334 | 0.3938 | 0.3972 |
| `X_U1.5` | `depth_err_max` | 0.1844 | 0.05847 | 0.2111 | 0.3913 | 0.3955 |
| `X_U1.5` | `u_err_rms` | 0.309 | 0.295 | 0.3147 | 0.3366 | 0.3394 |
| `X_U1.5` | `theta_absmax_deg` | 1.69 | 1.558 | 1.809 | 2.08 | 2.146 |
| `X_U1.5` | `de_absmax` | 5.608 | 5.522 | 5.686 | 5.946 | 5.963 |
| `X_U1.5` | `dr_absmax` | 0 | 3.523 | 24.41 | 24.99 | 25 |
| `X_U1.5` | `thr_max` | 13.39 | 12.52 | 13.44 | 14.37 | 14.52 |
| `X_U1.5` | `energy_thrust` | 172 | 166 | 169.6 | 173.3 | 174.7 |
| `X_U1.5` | `energy_fin` | 0.6743 | 0.8694 | 4.606 | 6.976 | 7.019 |
| `X_U1.5` | `err_theta_max_deg` | 0 | 0.02687 | 0.284 | 0.5014 | 0.5119 |
| `X_U1.5` | `err_z_max_m` | 0 | 0.05528 | 0.1534 | 0.3496 | 0.3609 |
| `X_U1.5` | `V_min` | 1 | 0.8571 | 0.9001 | 0.9539 | 0.8535 |
| `X_U1.5` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `X_U1.5` | `td_mean` | 0 | 0.0004276 | 0.01652 | 0.03197 | 0.03216 |
| `X_U1.5` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `X_U2.0` | `cte_mean` | 0.1347 | 0.04056 | 0.1473 | 0.2824 | 0.2881 |
| `X_U2.0` | `cte_max` | 0.1757 | 0.07447 | 0.2305 | 0.3931 | 0.3966 |
| `X_U2.0` | `depth_err_max` | 0.1757 | 0.06513 | 0.1969 | 0.3857 | 0.3923 |
| `X_U2.0` | `u_err_rms` | 0.178 | 0.1543 | 0.1751 | 0.1932 | 0.1933 |
| `X_U2.0` | `theta_absmax_deg` | 1.664 | 1.61 | 1.796 | 2.142 | 2.159 |
| `X_U2.0` | `de_absmax` | 5.227 | 5.343 | 5.724 | 6.241 | 6.319 |
| `X_U2.0` | `dr_absmax` | 0 | 2.871 | 24.21 | 25 | 25 |
| `X_U2.0` | `thr_max` | 5.488 | 5.32 | 5.411 | 5.55 | 5.606 |
| `X_U2.0` | `energy_thrust` | 159 | 152.2 | 155.7 | 159.8 | 161.8 |
| `X_U2.0` | `energy_fin` | 0.6648 | 0.8556 | 4.517 | 7.052 | 7.208 |
| `X_U2.0` | `err_theta_max_deg` | 0 | 0.03548 | 0.2886 | 0.5092 | 0.5178 |
| `X_U2.0` | `err_z_max_m` | 0 | 0.0553 | 0.1534 | 0.3496 | 0.3609 |
| `X_U2.0` | `V_min` | 1 | 0.8584 | 0.9007 | 0.9534 | 0.8549 |
| `X_U2.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `X_U2.0` | `td_mean` | 0 | 0.0004279 | 0.01653 | 0.032 | 0.03213 |
| `X_U2.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `XZ_U1.0` | `cte_mean` | 0.1886 | 0.06258 | 0.2 | 0.3228 | 0.3359 |
| `XZ_U1.0` | `cte_max` | 0.3832 | 0.1835 | 0.3945 | 0.5633 | 0.589 |
| `XZ_U1.0` | `depth_err_max` | 0.3813 | 0.1807 | 0.391 | 0.5603 | 0.5847 |
| `XZ_U1.0` | `u_err_rms` | 0.7884 | 0.7752 | 0.796 | 0.8195 | 0.82 |
| `XZ_U1.0` | `theta_absmax_deg` | 8.176 | 7.933 | 8.286 | 8.546 | 8.564 |
| `XZ_U1.0` | `de_absmax` | 6.826 | 6.278 | 7.097 | 7.809 | 8.007 |
| `XZ_U1.0` | `dr_absmax` | 0 | 1.66 | 24.59 | 25 | 25 |
| `XZ_U1.0` | `thr_max` | 25.89 | 24.58 | 25.91 | 27.4 | 27.61 |
| `XZ_U1.0` | `energy_thrust` | 190.9 | 185.2 | 189.2 | 193.1 | 193.7 |
| `XZ_U1.0` | `energy_fin` | 0.6187 | 0.6631 | 4.62 | 6.913 | 6.966 |
| `XZ_U1.0` | `err_theta_max_deg` | 0 | 0.04718 | 0.2802 | 0.5062 | 0.5357 |
| `XZ_U1.0` | `err_z_max_m` | 0 | 0.05619 | 0.1512 | 0.3464 | 0.3609 |
| `XZ_U1.0` | `V_min` | 1 | 0.8571 | 0.9002 | 0.9543 | 0.8538 |
| `XZ_U1.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `XZ_U1.0` | `td_mean` | 0 | 0.0004223 | 0.01652 | 0.03205 | 0.03216 |
| `XZ_U1.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `XZ_U1.5` | `cte_mean` | 0.1846 | 0.05876 | 0.1945 | 0.3305 | 0.3364 |
| `XZ_U1.5` | `cte_max` | 0.3671 | 0.1666 | 0.3815 | 0.5688 | 0.5815 |
| `XZ_U1.5` | `depth_err_max` | 0.3653 | 0.1636 | 0.3796 | 0.5647 | 0.5768 |
| `XZ_U1.5` | `u_err_rms` | 0.3015 | 0.2873 | 0.3072 | 0.3291 | 0.3312 |
| `XZ_U1.5` | `theta_absmax_deg` | 8.123 | 7.925 | 8.257 | 8.499 | 8.632 |
| `XZ_U1.5` | `de_absmax` | 5.797 | 5.801 | 6.108 | 6.465 | 6.601 |
| `XZ_U1.5` | `dr_absmax` | 0 | 3.444 | 24.42 | 25 | 25 |
| `XZ_U1.5` | `thr_max` | 13.39 | 12.52 | 13.44 | 14.37 | 14.52 |
| `XZ_U1.5` | `energy_thrust` | 177.6 | 171.4 | 175.1 | 179.2 | 179.8 |
| `XZ_U1.5` | `energy_fin` | 0.6028 | 0.8049 | 4.462 | 6.879 | 7.005 |
| `XZ_U1.5` | `err_theta_max_deg` | 0 | 0.05009 | 0.2856 | 0.512 | 0.5228 |
| `XZ_U1.5` | `err_z_max_m` | 0 | 0.05611 | 0.1513 | 0.346 | 0.3609 |
| `XZ_U1.5` | `V_min` | 1 | 0.8571 | 0.9001 | 0.9539 | 0.8535 |
| `XZ_U1.5` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `XZ_U1.5` | `td_mean` | 0 | 0.0004296 | 0.0165 | 0.03199 | 0.03209 |
| `XZ_U1.5` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `XZ_U2.0` | `cte_mean` | 0.1831 | 0.06113 | 0.1931 | 0.3295 | 0.3325 |
| `XZ_U2.0` | `cte_max` | 0.3599 | 0.166 | 0.3725 | 0.5639 | 0.5674 |
| `XZ_U2.0` | `depth_err_max` | 0.3581 | 0.162 | 0.3698 | 0.5604 | 0.5626 |
| `XZ_U2.0` | `u_err_rms` | 0.1861 | 0.1624 | 0.1825 | 0.2016 | 0.2016 |
| `XZ_U2.0` | `theta_absmax_deg` | 8.097 | 7.885 | 8.249 | 8.517 | 8.596 |
| `XZ_U2.0` | `de_absmax` | 5.775 | 5.788 | 6.047 | 6.407 | 6.433 |
| `XZ_U2.0` | `dr_absmax` | 0 | 2.849 | 24.31 | 25 | 25 |
| `XZ_U2.0` | `thr_max` | 5.94 | 5.772 | 5.894 | 6.108 | 6.133 |
| `XZ_U2.0` | `energy_thrust` | 164.7 | 157.8 | 161.4 | 165.8 | 167.5 |
| `XZ_U2.0` | `energy_fin` | 0.5912 | 0.7865 | 4.602 | 6.992 | 7.08 |
| `XZ_U2.0` | `err_theta_max_deg` | 0 | 0.05114 | 0.2893 | 0.517 | 0.5248 |
| `XZ_U2.0` | `err_z_max_m` | 0 | 0.05603 | 0.1512 | 0.3456 | 0.3609 |
| `XZ_U2.0` | `V_min` | 1 | 0.8581 | 0.9005 | 0.9538 | 0.8549 |
| `XZ_U2.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `XZ_U2.0` | `td_mean` | 0 | 0.0004355 | 0.01649 | 0.03202 | 0.03209 |
| `XZ_U2.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `R10_U1.5` | `cte_mean` | 0.2123 | 0.1254 | 0.2463 | 0.3506 | 0.3608 |
| `R10_U1.5` | `cte_max` | 0.2857 | 0.3079 | 0.4222 | 0.5872 | 0.762 |
| `R10_U1.5` | `depth_err_max` | 0.2206 | 0.1467 | 0.2429 | 0.4072 | 0.4375 |
| `R10_U1.5` | `u_err_rms` | 0.09038 | 0.07817 | 0.09511 | 0.1137 | 0.1143 |
| `R10_U1.5` | `theta_absmax_deg` | 4.672 | 4.415 | 4.731 | 4.928 | 4.967 |
| `R10_U1.5` | `de_absmax` | 6.592 | 6.465 | 6.671 | 6.907 | 6.928 |
| `R10_U1.5` | `dr_absmax` | 25 | 25 | 25 | 25 | 25 |
| `R10_U1.5` | `thr_max` | 13.25 | 12.39 | 13.3 | 14.23 | 14.37 |
| `R10_U1.5` | `energy_thrust` | 138 | 132.3 | 136.6 | 142.4 | 143.7 |
| `R10_U1.5` | `energy_fin` | 7.504 | 5.931 | 8.222 | 9.895 | 10.31 |
| `R10_U1.5` | `err_theta_max_deg` | 0 | 0.02346 | 0.2791 | 0.4968 | 0.5128 |
| `R10_U1.5` | `err_z_max_m` | 0 | 0.05385 | 0.1518 | 0.348 | 0.3577 |
| `R10_U1.5` | `V_min` | 1 | 0.8571 | 0.9001 | 0.9539 | 0.8535 |
| `R10_U1.5` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `R10_U1.5` | `td_mean` | 0 | 0.0004202 | 0.0165 | 0.03197 | 0.03203 |
| `R10_U1.5` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |
| `R10_U2.0` | `cte_mean` | 0.204 | 0.129 | 0.2296 | 0.3624 | 0.3715 |
| `R10_U2.0` | `cte_max` | 0.2946 | 0.2606 | 0.3891 | 0.7394 | 0.8261 |
| `R10_U2.0` | `depth_err_max` | 0.2151 | 0.1482 | 0.243 | 0.3976 | 0.4084 |
| `R10_U2.0` | `u_err_rms` | 0.4166 | 0.3976 | 0.4147 | 0.4317 | 0.4341 |
| `R10_U2.0` | `theta_absmax_deg` | 4.604 | 4.389 | 4.705 | 4.924 | 4.95 |
| `R10_U2.0` | `de_absmax` | 6.307 | 6.136 | 6.423 | 6.725 | 6.727 |
| `R10_U2.0` | `dr_absmax` | 25 | 25 | 25 | 25 | 25 |
| `R10_U2.0` | `thr_max` | 4.882 | 4.701 | 4.941 | 5.145 | 5.301 |
| `R10_U2.0` | `energy_thrust` | 126.4 | 117.7 | 123.9 | 129.4 | 129.9 |
| `R10_U2.0` | `energy_fin` | 6.719 | 5.587 | 8.152 | 10.01 | 10.04 |
| `R10_U2.0` | `err_theta_max_deg` | 0 | 0.0268 | 0.2772 | 0.499 | 0.5353 |
| `R10_U2.0` | `err_z_max_m` | 0 | 0.05385 | 0.1519 | 0.3481 | 0.3578 |
| `R10_U2.0` | `V_min` | 1 | 0.8571 | 0.8998 | 0.9527 | 0.8538 |
| `R10_U2.0` | `brown_dwell` | 0 | 0 | 0 | 0 | 0 |
| `R10_U2.0` | `td_mean` | 0 | 0.0004131 | 0.01652 | 0.0321 | 0.03215 |
| `R10_U2.0` | `trip_dwell` | 0 | 0 | 0.975 | 1.975 | 2.075 |

## 10. Failure taxonomy

| Category | Runs | Fraction |
|---|---|---|
| nonfinite | 0 | 0.0000 |
| early_termination | 0 | 0.0000 |
| instability | 0 | 0.0000 |
| magnitude | 0 | 0.0000 |
| rate | 151 | 0.5898 |
| sat_rail | 2 | 0.0078 |
| depth | 0 | 0.0000 |
| tracking | 0 | 0.0000 |
| speed | 0 | 0.0000 |
| attitude | 0 | 0.0000 |
| power | 0 | 0.0000 |
| fdir | 0 | 0.0000 |

## 11. Sensitivity (Spearman rank correlation)

- **cte_max**: `dep_bias` 0.661 (SUPPORTED), `imu_bias_theta` -0.427 (SUPPORTED), `imu_bias_phi` -0.341 (SUPPORTED), `cb_dz` -0.259 (UNSUPPORTED), `cb_dx` 0.224 (UNSUPPORTED), `imu_bias_psi` 0.200 (SUPPORTED)
- **cte_mean**: `dep_bias` 0.832 (SUPPORTED), `imu_bias_theta` -0.566 (SUPPORTED), `imu_bias_phi` -0.440 (SUPPORTED), `cb_dz` -0.345 (UNSUPPORTED), `cb_dx` 0.315 (UNSUPPORTED), `imu_bias_psi` 0.268 (SUPPORTED)
- **depth_err_max**: `dep_bias` 0.767 (SUPPORTED), `imu_bias_theta` -0.523 (SUPPORTED), `imu_bias_phi` -0.415 (SUPPORTED), `cb_dz` -0.336 (UNSUPPORTED), `cb_dx` 0.304 (UNSUPPORTED), `imu_bias_psi` 0.277 (SUPPORTED)
- **u_err_rms**: `dvl_bias_u` -0.052 (SUPPORTED), `gain_thrust` 0.036 (SUPPORTED), `dvl_bias_w` -0.029 (SUPPORTED), `imu_bias_phi` -0.028 (SUPPORTED), `dvl_lock_loss_t0f` 0.022 (SUPPORTED), `imu_bias_q` 0.022 (SUPPORTED)
- **de_absmax**: `imu_delay` 0.114 (SUPPORTED), `imu_bias_theta` -0.111 (SUPPORTED), `dvl_delay` 0.081 (SUPPORTED), `imu_bias_psi` 0.071 (SUPPORTED), `dvl_lock_loss_dur` 0.071 (SUPPORTED), `imu_bias_p` 0.065 (SUPPORTED)
- **dr_absmax**: `td_transport` 0.245 (SUPPORTED), `load_scale` -0.202 (PARTIAL), `dvl_lock_loss_dur` 0.202 (SUPPORTED), `imu_bias_phi` -0.166 (SUPPORTED), `cb_dx` 0.152 (UNSUPPORTED), `dep_bias` 0.149 (SUPPORTED)
- **energy_thrust**: `dvl_bias_u` -0.102 (SUPPORTED), `dvl_bias_w` -0.068 (SUPPORTED), `gain_thrust` 0.056 (SUPPORTED), `jitter_max` 0.056 (SUPPORTED), `dvl_lock_loss_t0f` 0.050 (SUPPORTED), `imu_drop_p` 0.044 (SUPPORTED)
- **err_theta_max_deg**: `imu_bias_theta` -0.374 (SUPPORTED), `slew_thrust` 0.365 (SUPPORTED), `dep_disagree_dur` -0.345 (SUPPORTED), `k_ir_scale` -0.305 (PARTIAL), `imu_bias_p` 0.267 (SUPPORTED), `tau_thrust` 0.244 (SUPPORTED)
- **V_min**: `V0` 0.935 (PARTIAL), `td_transport` -0.473 (SUPPORTED), `dvl_delay` 0.410 (SUPPORTED), `dvl_bias_v` 0.377 (SUPPORTED), `dep_disagree_t0f` 0.368 (SUPPORTED), `dvl_bias_w` 0.303 (SUPPORTED)
- **td_mean**: `td_transport` 0.938 (SUPPORTED), `gain_thrust` 0.483 (SUPPORTED), `V0` -0.482 (PARTIAL), `dvl_delay` -0.342 (SUPPORTED), `dep_disagree_dur` -0.317 (SUPPORTED), `cg_dz` -0.312 (UNSUPPORTED)

UNSUPPORTED factors necessarily show rho near zero because they were never injected. That zero is an artefact of the missing interface, **not** evidence of insensitivity to CG / CB / buoyancy.

## 12. Pareto vector

| Axis | Metric | Nominal (median over cells) | MC P50 | MC P95 | MC worst | Status |
|---|---|---|---|---|---|---|
| Tracking | `cte_max` | 0.2901 | 0.342 | 0.5652 | 0.8261 | REPORTED |
| ActuatorMargin | `act_margin_de` | 8.948 | 8.717 | 9.426 | 6.993 | REPORTED |
| Energy | `energy_thrust` | 168.4 | 165.9 | 189.6 | 193.7 | REPORTED |
| Estimation | `err_theta_max_deg` | 0 | 0.2873 | 0.5089 | 0.5357 | PARTIAL - measured-vs-truth only; no estimator/NEES on the production path |
| Timing | `td_mean` | 0 | 0.0165 | 0.032 | 0.03216 | PARTIAL - simulated command transport delay only; target WCET/deadline TO_BE_IDENTIFIED |
| Safety | `trip_dwell` | 0 | 0.975 | 1.975 | 2.075 | REPORTED |

## 13. Gate 7 mission / FDIR 16-case matrix - carried, NOT re-drawn

The 16 Gate 7 cases were **not** re-simulated under the MC priors. Their harness is a separate driver that is outside this task 3-source budget, and reconstructing FDIR dynamics from recorded logs would have been fabrication. The accepted Gate 7 nominal values are reproduced below purely as the reference the next task must reproduce.

| # | Case | Recovery class | cte_max | depth_min | depth_max | V_min | surface | accom | direct-act | MC re-drawn |
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

## 14. Honesty ledger

| Claim | Status |
|---|---|
| CG / CB / buoyancy priors injected into the plant | **UNSUPPORTED** - drawn and stored, never applied; production `underwater777_vehicle_dynamics.m` exposes no shadow parameter interface and editing it is forbidden |
| Battery / power / brownout | **PARTIAL** - reaches the plant only as a thrust-authority derate; no bus, compute or actuator-supply coupling exists on this path |
| Estimated streams | **NOT_IMPLEMENTED** - no estimator on the production tracking path; horizontal position is passed as truth and labelled, not faked |
| Timing / WCET | **PARTIAL** - simulated command transport delay only; target period/deadline/WCET/overrun remain TO_BE_IDENTIFIED |
| Watchdog / mission / bus / leak / actuator-current monitors | **UNSUPPORTED on this path** - no mission bus exists in the tracking loop; only IMU/DVL/depth staleness and undervoltage are reachable |
| Frozen production cell definitions | **ASSUMED_RECONSTRUCTION** - see section 4 |
| Every prior label | ASSUMED (no ASSUMED -> IDENTIFIED upgrade anywhere) |
| Hardware | NOT_CERTIFIED |

## 15. Artifacts

- `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.png`
- `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_01_parity_replay.png`
- `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_02_pass_probability.png`
- `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_03_truth_measured_power.png`
- `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_04_sensitivity.png`
- `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.md`
- `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.mat`

Total footprint 0.48 MiB (< 300 MiB: 1).

## 16. Next exact task (one, bounded, untried)

**`gate8_plant_parameter_shadow_interface`** - add a *shadow-only* parameter-injection seam so CG / CB / buoyancy priors can physically enter the plant without editing production: a read-only clone of `underwater777_vehicle_dynamics.m` marked with the same BEGIN/ORIG/END reduction contract that `continuous_path_tracking_propulsion.m` already proves, plus a mechanical reduction gate showing the clone reduces byte-identically to production. One MATLAB call, parity-first: the clone at zero offset must reproduce this report nominal hashes bit-for-bit before any Monte Carlo is re-run. Gate 8 is re-scored only after that seam exists.

No brand, no purchase, no MCU selection. `CODEX_VERTICAL_PLAN.md` untouched. Gate 9 stays locked.

---

<!-- ERRATUM:GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001 -->

## 17. Erratum - post-run defect analysis (no number altered, no gate flipped)

Added after the single MATLAB invocation, by inspection of the recorded `.mat` only. **No value in sections 1-16 was edited, no gate result was changed, and MATLAB was not re-invoked.** The recorded verdict stays **FAIL**. What changes is the *attribution* of two of the four failing gates: they are defects in this shadow harness, not evidence about the vehicle.

### E1 - HG8 failed on a self-referential token scan (harness defect, not a finding)

`g8_self_scan` reads its own source file and searches for forbidden call tokens. The token list is a literal in that same file, so the scan always matches itself. External verification over the driver source finds the tokens on exactly three lines - 1259, 1260, 1261 - which are the `tok = {...}` literal, and nowhere else. The substantive counters in the same gate were all zero (`surface=0 accom=0 direct=0`), and the tracking loop has no mission-command interface at all. **The no-surface / no-accommodation / no-direct-actuator property holds; the check that measures it is broken.**

### E2 - HG5 "rate" failures (151/256) are a limiter-ordering defect, not a plant or prior effect

In `g8_actuators` the fin rate limit is applied *before* the transport-delay + jitter resampler. Because the jitter redraws the fractional delay every tick, the resampler re-interpolates an already rate-limited signal and inflates the apparent step. The recorded data matches that mechanism almost exactly:

| draw | jitter_max [ms] | td_transport [ms] | realized slew [deg/s] | 40*(1 + jitter/dt) | cells failing |
|---|---|---|---|---|---|
| 27 | 0.052 | 15 | 40.08 | 40.08 | 0/8 |
| 4 | 0.264 | 15 | 40.41 | 40.42 | 0/8 |
| 1 | 2.918 | 30 | 44.60 | 44.67 | 8/8 |
| 24 | 4.190 | 30 | 46.51 | 46.70 | 8/8 |
| 14 | 4.698 | 0 | 47.35 | 47.52 | 8/8 |

The realized slew is a deterministic function of `jitter_max` alone; `td_transport` has no influence (draws with `td_transport = 0` fail just as hard). With the gate threshold at 40 * 1.05 = 42 deg/s, every draw with `jitter_max > 1.25 ms` fails by construction. **The 40 deg/s envelope was never actually violated by the controller - it was violated by the order of two blocks inside this harness.** The physical ordering is the reverse: transport delay and jitter happen on the command path, and the actuator enforces its rate limit downstream of them.

**The 2 `sat_rail` failures are NOT a defect and stand as real evidence.** Nominal `delta_r` in both R10 cells is exactly 25.000 deg, i.e. the production controller already saturates its own rudder at the same 25 deg the Gate 3 envelope declares. Rudder rail dwell above 25 percent of the run in the 10 m helix is therefore a genuine property of the frozen controller under a 0.1 1/m curvature, not an artefact of the injected priors.

### E3 - Correction to the closing sentence of section 11

Section 11 states that UNSUPPORTED factors "necessarily show rho near zero". **That is wrong and its own table disproves it** (`cb_dz` -0.259, `cb_dx` 0.224 against `cte_max`). The correct statement: a factor that was never injected cannot influence any KPI, so *any* non-zero rank correlation reported for an UNSUPPORTED factor is pure finite-sample noise - 32 distinct draw values replicated across 8 cells. Those coefficients must not be read as sensitivity, in either direction, and the apparent ranking of `cb_dz` above several genuinely injected sensor factors is a sampling artefact.

### E4 - The brownout response path was never exercised

`V0`, `k_ir_scale` and `load_scale` were injected and did move the bus voltage (see `_03` panel), but the minimum voltage over all 256 runs was 0.8535 pu against a 0.85 pu threshold, so `brown_dwell = 0` in every run. The voltage-sag model was exercised; the **undervoltage detection and thrust-authority derate branch was not**. The POWER group should therefore be read as PARTIAL *and* partially UNEXERCISED, which is stricter than the section 5 label.

### E5 - Cosmetic defects (tracked, non-blocking)

- Figure titles pass underscores to the TeX interpreter, so `NOT_CERTIFIED` renders as `NOT` with a subscript `C`. Affects the main figure title and several axis labels.
- Panel `_03` bottom-right y-label reads `thrust [pu]`; the values are in the production thrust unit, which this task explicitly declined to assume is per-unit.

### Revised next exact task (supersedes section 16)

**`gate8_actuator_order_and_scan_repair`** - repair the two harness defects and re-run the identical campaign, following the precedent already set by `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR`:

1. move the fin magnitude and rate limiter **downstream** of the transport-delay and jitter resampler, so the signal that reaches the plant respects the declared envelope by construction;
2. make the forbidden-token scan non-self-matching (build the tokens so the literal cannot match itself, or exclude the declaring lines);
3. re-run with the **same recorded seed 20260809 and the same 32 draw vectors**, and require the draw matrix, the nominal parity hashes and the replay hashes to come back bit-identical to this report before any metric is compared.

Nothing else changes: no new prior, no widened source budget, no re-tuned threshold. This task cannot by itself produce a Gate 8 PASS - **HG11** (CG / CB / buoyancy have no injection seam), **HG12** (Gate 7 16-case FDIR matrix not re-drawn) and **HG13** (cell geometry is a reconstruction) remain open and are already recorded as failures above. It is a prerequisite: there is no value in injecting plant-parameter priors into a harness that manufactures a 59 percent spurious rate-violation rate.

Gate 9 remains **locked**. Gate 9B remains post-Gate 9. All priors remain **ASSUMED**. Hardware remains **NOT_CERTIFIED**.
