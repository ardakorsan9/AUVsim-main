# GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE - CLOSED

**TASK_ID:** `GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_001`  
**Date:** 2026-08-09 11:32:09  
**Class:** Gate 8 R10 - isolated, read-only guidance/controller signal logging and yaw-reference closure  
**MATLAB runs:** 1 (single bounded invocation, no retry)  
**Horizons:** 1 nominal 30 s horizon on the frozen R10_U1.5 cell  
**Production / CODEX_VERTICAL_PLAN:** untouched (read-only inputs, fingerprinted pre and post)  
**Physical / hardware readiness:** **NOT_CERTIFIED**  
**Gate 9:** locked  
**Host runtime:** 81.9 s  
**Artifact footprint:** 0.31 MiB (budget 150 MiB)  

## 1. Verdict

**CLOSED.**

Frozen parity, log closure, geometry identity and bounded continuity all passed, so the course offset identified below is admissible evidence and exactly one shadow reference candidate is stated in section 9. Nothing was implemented, evaluated or promoted.

**Scope honesty.** This task adds observation, not capability. No gain, law, path or threshold was edited; no external shaper and no current feedforward exists here; nothing was promoted. `k_beta = 1.35` is measured and left in place. Simulation is not hardware certification.

## 2. Sources (exactly 3, no repo scan)

| # | Path | Fingerprint |
|---|------|-------------|
| 1 | `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` |
| 2 | `controller_law.m` | `n=9402.s1=732890.s2=3334742186` |
| 3 | `run_gate8_actuator_order_scan_repair.m` | `n=121098.s1=9464134.s2=3103638627` |

Fingerprint formula `n=<bytes>.s1=<sum b_i>.s2=<mod(sum(i*b_i), 2^32)>`, carried verbatim from source #3 so every number in this report is directly comparable with the Gate 7 / Gate 8 record.

**Cell provenance.** cell geometry carried byte-identically from run_gate8_actuator_order_scan_repair.m (g9_cells). It remains an ASSUMED_RECONSTRUCTION of the frozen R10 definition, exactly as recorded there; nothing is re-derived here. The external fingerprint check below is what proves the same cell is being driven.

## 3. Frozen parity, checked BEFORE any analysis

| Item | Value |
|------|-------|
| Cell | `R10_U1.5` (family R10, U = 1.50 m/s, 26 waypoints, index 7 of the frozen set) |
| Horizon | dt = 0.025 s, T_final = 30 s, 1200 controller ticks |
| Required external fingerprint | `n=153600.s1=19094896.s2=2901292177` |
| Production reproduce | `n=153600.s1=19094896.s2=2901292177` (match = 1, 19.5 s) |
| Instrumented reproduce | `n=153600.s1=19094896.s2=2901292177` (match = 1, 16.3 s) |
| Array parity production vs instrumented | 1 (bit-identical on vp,t,vel,av,ori,yaw_ref,pitch_ref,u_ref) |
| Guidance cadence | dt_guidance global 0.075000 s, guidance_period 3 controller ticks, effective 0.075000 s |
| Lookahead | lookahead_distance = 1.2500 m, applied L = max(lookahead_distance, 1.0) = 1.2500 m |

Production and plan fingerprints:

| File | pre | post | unchanged |
|------|-----|------|-----------|
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | `n=14601.s1=1095745.s2=3464382495` | 1 |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | `n=9402.s1=732890.s2=3334742186` | 1 |
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | `n=10845.s1=886194.s2=515073390` | 1 |
| `init_parameters.m` | `n=4205.s1=309116.s2=664235741` | `n=4205.s1=309116.s2=664235741` | 1 |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | `n=6065.s1=426918.s2=1254438441` | 1 |
| `suite_results/CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | `n=43101.s1=4310210.s2=3268810005` | 1 |

## 4. What was logged, with units and frames

The observer records **1200 controller ticks**, of which **400** are guidance updates, into a single table with 52 named columns.

| Frame / unit | Definition |
|---|---|
| position | NED, metres, x North, y East, z DOWN so depth = +z |
| attitude | Euler phi/theta/psi in rad (ZYX); physical pitch theta_phys = -theta |
| body_vel | BODY-frame u,v,w in m/s; BODY rates p,q,r in rad/s |
| course | course over ground chi_og = atan2(ydot_NED, xdot_NED) in rad, wrapped to (-pi,pi]; heading psi in rad; sideslip beta in rad, positive to starboard |
| path | arc-length s in m along the polyline; curvature kappa in rad/m, positive left-turn |
| crosstrack | signed y_e in m = dot(p_veh - p_path, n_h) with n_h = [-t_x_hat(2), t_x_hat(1)] the right-hand horizontal normal; y_e > 0 = vehicle to starboard of path |
| lookahead | L in m, applied as an arc-length offset s_look = s_prog + L |
| time | timestamps in s from run start; guidance tick and controller tick both recorded |
| fins | delta_r / delta_e in rad internally, deg only where a name says so |
| source_ref | frame chain carried verbatim from the Gate 8 record via run_gate8_actuator_order_scan_repair.m |

**Columns (all in `R.log`, names in `R.log_cols`):** `t_s`, `k_tick`, `gupd`, `x_m`, `y_m`, `z_m`, `phi_rad`, `theta_rad`, `psi_rad`, `u_mps`, `v_mps`, `w_mps`, `p_rps`, `q_rps`, `r_rps`, `xdot_mps`, `ydot_mps`, `zdot_mps`, `U_h_mps`, `chi_og_rad`, `beta_g_rad`, `beta_noclamp_rad`, `beta_rollheave_rad`, `beta_exact_rad`, `s_prog_m`, `s_total_m`, `kappa_raw_radpm`, `kappa_f_radpm`, `y_e_m`, `chi_now_rad`, `chi_path_rad`, `chi_f_rad`, `chi_los_rad`, `L_m`, `yaw_raw_rad`, `yaw_cont_rad`, `yaw_out_rad`, `dy_des_rad`, `dy_app_rad`, `near_end`, `yaw_ref_prod_rad`, `yaw_ref_held_rad`, `psi_ctrl_rad`, `e_psi_dbg_rad`, `e_r_rps`, `r_ff_rps`, `dr_yaw_rad`, `delta_r_cmd_rad`, `delta_r_rad`, `g_ac`, `pitch_ref_rad`, `u_ref_mps`

all angles rad unless the name says deg; positions m NED with z down; speeds m/s; rates rad/s; curvature rad/m; arc length and lookahead m; time s. gupd = 1 on ticks where the production guidance law updated, 0 on held ticks.

Every requested signal is present: `yaw_ref` (production, and the held value the controller actually consumed), achieved `psi`, `s_prog`, `kappa_f` (and `kappa_raw`), signed `y_e`, `chi_f`, `chi_los` together with the course tangent `chi_now` and the lookahead course `chi_path`, `beta`, `U_h`, lookahead `L`, the filter states (`chi_f`, `yaw_cont`), the slew-limited output (`yaw_out`, with desired and applied increments), and the held controller input with its own `e_psi`, `e_r`, `dr_yaw` and realized `delta_r`. Each row carries its timestamp in s.

## 5. Instrumentation neutrality

The observer re-executes the yaw-channel arithmetic of `guidance_law.m` verbatim, in the same order, on the same inputs, holding its own state. It is invoked **after** the production guidance call inside the same tick, writes no global, and draws no random number. `controller_law` is called with its optional 4th diagnostic output, which builds a struct and touches no persistent state.

Neutrality is proven rather than asserted: the instrumented loop reproduces the required external fingerprint `n=153600.s1=19094896.s2=2901292177` (match = 1) and is array-parity identical to the production call (bit-identical on vp,t,vel,av,ori,yaw_ref,pitch_ref,u_ref). Cadence, state and call order are therefore unchanged by construction and by measurement.

## 6. Closure of the implemented yaw reference

Tolerances were declared before the run: observer/component sum 1e-12 rad, recursion 1e-09 rad, identity 1e-09 rad.

| Closure | max abs residual [rad] | Tolerance | Pass |
|---|---|---|---|
| observer yaw_out vs production yaw_ref | 0.000e+00 | 1e-12 | 1 |
| component sum `wrapToPi(chi_f + 0.75*chi_los - 1.35*beta)` vs logged yaw_raw | 0.000e+00 | 1e-12 | 1 |
| full recursion (unwrap + 0.35 blend + slew clip) rebuilt from logged components vs production yaw_ref | 0.000e+00 | 1e-09 | 1 |
| `e_psi = wrapToPi(yaw_ref - psi)` vs the controller's own e_psi | 0.000e+00 | 1e-12 | 1 |

Heading tracking on this horizon: `e_psi` rms 6.3377 deg, peak 13.5793 deg over 400 guidance ticks.

## 7. Geometry identity and the identified course offset

**Exact course decomposition.** With `a = cos(theta)*u + sin(theta)*sin(phi)*v + sin(theta)*cos(phi)*w` and `b = cos(phi)*v - sin(phi)*w`, the NED velocity gives `chi_og = psi + atan2(b, a)` exactly. Measured residual over the horizon: **8.882e-16 rad**.

**Four-term course-offset identity.** From the implemented law and the exact kinematics,

```
wrap(chi_og - (chi_f + 0.75*chi_los)) = lag - e_psi - (k_beta-1)*beta + (beta_exact - beta)
```

where `lag = wrap(yaw_ref - yaw_raw)` is the combined course-filter and slew-limiter lag. Measured closure: **2.005e-15 rad** (all guidance ticks: 2.005e-15 rad).

| Term | Steady-window mean [deg] |
|---|---|
| filter + slew lag | -1.2524 |
| -e_psi (heading tracking) | -3.8352 |
| -(k_beta-1)*beta (structural over-crab) | 0.2764 |
| beta model residual | 0.0417 |
| **total measured course offset** | **-4.7693** |

**Zero-curvature reduction.** with kappa = 0 the recorded lead law returns identically zero and the implemented chi_f / yaw_out recursions converge onto the constant course reference, so the whole lead is a curvature effect and carries no constant bias Recorded lead law at kappa = 0: max abs(lead) = 0.000e+00 rad. Implemented pipeline driven by a constant course: settle residual 2.220e-16 rad.

## 8. Curvature lead, wraps, continuity and the crab residual

### 8.1 Analytic curvature lead

Recorded law: `lead_pred = kappa_f * (L - U * dt_g * 4.428571)`, with 4.428571 = 0.72/0.28 + 0.65/0.35 = 18/7 + 13/7 = 31/7 guidance ticks, the summed first-order lag of the course filter chi_f (alpha 0.28) and the slew-limited output filter yaw_out (alpha 0.35). Multiplied by U*dt_g it is the arc-length the lead is eroded by, so the net lead is kappa*(L - U*dt_g*31/7).

| Quantity | Value |
|---|---|
| window | t in [10, 28] s, guidance ticks, near_end excluded: 240 samples |
| measured mean lead | 4.1369 deg |
| predicted mean lead (effective dt_g = 0.0750 s) | 4.2069 deg |
| predicted mean lead (nominal dt_g = 0.0750 s) | 4.2069 deg |
| mean residual / rms / peak | -0.0699 / 6.6455 / 13.6262 deg |
| frozen polyline tangent step (max / mean) | 18.0000 / 18.0000 deg |
| quantisation envelope (half a tangent step) | 9.0000 deg |
| kappa_f mean / std | 0.10021 / 0.00317 rad/m |
| U_h mean, L applied | 1.5576 m/s, 1.2500 m |

**Classification:** CONSISTENT-IN-MEAN: the measured lead matches kappa*(L - U*dt_g*31/7) to within the waypoint-quantisation envelope of the frozen polyline. The instantaneous residual is a sawtooth at the waypoint rate, not a modelling error in the lead law.

### 8.2 Wraps and bounded continuity

| Check | Value |
|---|---|
| wrap events on the wrapped reference | 1 |
| `wrap(wrap(yaw_cont) - yaw_raw)` max abs | 8.882e-16 rad |
| max per-tick abs(d yaw_cont) | 0.0909 rad (must be <= pi) |
| max per-tick abs(d yaw_out) | 4.599539e-02 rad against the implemented bound 5.235988e-02 rad |
| slew limiter engagements | 0 of 400 guidance ticks |
| unwrapped total turn | 4.7746 rad |
| all logged signals finite | 1 |

### 8.3 Crab residual, classified and left unchanged

the guidance reference is psi_ref = chi_f + 0.75*chi_los - k_beta*beta with k_beta = 1.35, while the exact course kinematics are chi = psi + beta. With perfect heading tracking the achieved course therefore sits at chi_f + 0.75*chi_los - (k_beta - 1)*beta, i.e. the implemented law over-compensates sideslip by 0.35*beta.

k_beta = 1.35 left unchanged; mean abs(beta) 0.790 deg, peak 2.417 deg; structural over-crab term -(k_beta-1)*beta mean 0.2764 deg, peak 0.8458 deg; sideslip model residual mean 0.0417 deg (clamp 0.0000 + roll/heave 0.0419 + pitch projection -0.0001, additive split closes to 4.34e-19 rad); total steady course offset mean -4.7693 deg, rms 7.6353 deg; dominant term: heading_tracking_error (3.8352 deg)

**Classification:** STRUCTURAL, LAW-INHERENT, NOT A DISTURBANCE. The crab residual is a deterministic function of the implemented k_beta and of the sideslip model the law uses (atan2(v, max(u,0.35)) instead of the exact horizontal projection). It is reproducible tick-for-tick from the log and is not a current, a bias or an estimator error. It is recorded here and deliberately left unchanged.

## 9. Shadow reference candidate

Exactly **one** candidate is stated, and only because frozen parity (1), log closure (1), geometry identity (1) and bounded continuity (1) all passed.

**SHADOW_COURSE_REFERENCE_OFFSET_CANDIDATE_C1**

C1: a shadow-only course reference that removes the identified structural over-crab term, i.e. evaluates chi_ref = chi_f + 0.75*chi_los - beta (k_beta = 1) as a LOGGED SHADOW SIGNAL ONLY, alongside the untouched production reference.

*Rationale:* the four-term identity closes to 2.01e-15 rad, so the achieved course sits at chi_f + 0.75*chi_los - (k_beta-1)*beta + lag - e_psi + model residual. The only term that is a pure design constant is -(k_beta-1)*beta, measured here at 0.2764 deg mean and 0.8458 deg peak. C1 is the minimal shadow probe that isolates it.

*Status:* **CANDIDATE_ONLY - NOT IMPLEMENTED, NOT EVALUATED, NOT PROMOTED**. C1 must be run as a shadow observer against the same frozen cell and the same external fingerprint before any comparison is admissible. It changes no gain, no law, no path and no threshold in this task. Promotion would require its own parity-first gate and is out of scope here. Gate 9 stays locked.

## 10. Hard gates

| ID | Requirement | Pass | Evidence |
|---|---|---|---|
| HG1 | Frozen parity: the production reproduce AND the instrumented reproduce both carry the required external fingerprint, and production files are unchanged | 1 | production hash n=153600.s1=19094896.s2=2901292177 (== required 1), instrumented hash n=153600.s1=19094896.s2=2901292177 (== required 1), array parity 1 (bit-identical on vp,t,vel,av,ori,yaw_ref,pitch_ref,u_ref), production+CODEX fingerprints unchanged 1 |
| HG2 | Log closure: the recorded component sum reproduces the production yaw_ref, and e_psi = wrap(yaw_ref - psi) reproduces the controller's own e_psi | 1 | observer vs production yaw_ref max abs diff = 0.000e+00 rad (tol 1e-12); component-sum recursion rebuilt from logged chi_f, chi_los, beta max abs diff = 0.000e+00 rad (tol 1e-09); e_psi vs controller dbg max abs diff = 0.000e+00 rad (tol 1e-12); 400 guidance ticks |
| HG3 | Geometry identity: exact course = psi + beta closes, and the four-term course-offset decomposition closes onto the achieved course; zero-curvature reduction holds | 1 | chi_og vs psi+beta_exact max abs diff = 8.882e-16 rad; four-term course-offset identity max abs diff = 2.005e-15 rad (tol 1e-09); zero-curvature lead reduction max abs(lead) = 0.000e+00 rad; zero-curvature pipeline settle residual = 2.220e-16 rad |
| HG4 | Bounded continuity: the slew-limited output respects its own per-tick bound, the unwrap is continuous across every wrap event, and every logged signal is finite | 1 | max abs(d yaw_out) = 4.599539e-02 rad against the implemented bound 5.235988e-02 rad (deg2rad(40)*dt_g); slew limiter engaged on 0/400 ticks; 1 wrap events on the wrapped reference, max abs(wrap(wrap(yaw_cont) - yaw_raw)) = 8.882e-16 rad; max abs(d yaw_cont) = 0.0909 rad (<= pi); finite 1 |
| HG5 | Instrumentation neutrality: the observer changes no cadence, no state and no call order (proven by fingerprint, not asserted) | 1 | observer owns its own state, writes no global, draws no random number, and runs after the production guidance call in the same tick; instrumented fingerprint n=153600.s1=19094896.s2=2901292177 == required 1, 1200 controller ticks logged, 400 guidance updates |
| HG6 | Curvature-lead law recorded and classified against the implemented pipeline (reported evidence, no threshold and no gain touched) | 1 | measured lead 4.137 deg vs predicted 4.207 deg (effective dt_g 0.0750 s) and 4.207 deg (nominal dt_g 0.0750 s); mean residual -0.070 deg, rms 6.646 deg, peak 13.626 deg against the +-9.000 deg waypoint-quantisation envelope of the frozen 26-point polyline (max tangent step 18.000 deg); classification: CONSISTENT-IN-MEAN: the measured lead matches kappa*(L - U*dt_g*31/7) to within the waypoint-quantisation envelope of the frozen polyline. The instantaneous residual is a sawtooth at the waypoint rate, not a modelling error in the lead law. |
| HG7 | Crab residual classified without being changed (k_beta stays 1.35) | 1 | k_beta = 1.35 left unchanged; mean abs(beta) 0.790 deg, peak 2.417 deg; structural over-crab term -(k_beta-1)*beta mean 0.2764 deg, peak 0.8458 deg; sideslip model residual mean 0.0417 deg (clamp 0.0000 + roll/heave 0.0419 + pitch projection -0.0001, additive split closes to 4.34e-19 rad); total steady course offset mean -4.7693 deg, rms 7.6353 deg; dominant term: heading_tracking_error (3.8352 deg) |
| HG8 | No gain / law / path / threshold edit, no external shaper, no current-FF, no promotion | 1 | this driver only reads. The single change to the execution path is an observer call placed after the production guidance call; it returns values and is discarded. Production fingerprints pre == post proves no file was written. |

## 11. Visual evidence and QA

- `suite_results/GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE.png`
- `suite_results/GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_qa.png`

Visual QA verdict: **VISUAL_QA_PASS**. visual QA is programmatic: every figure file is re-opened after writing, its pixel dimensions are read back, and the series it claims to show are re-checked against the recorded log. Nothing here is a human impression.

| Check | Pass | Detail |
|---|---|---|
| files_written | 1 | 2/2 PNG files exist, exceed 8 KiB and are at least 600x400 px |
| no_nan_in_plotted_log | 1 | 1200 logged ticks x 52 columns, all finite |
| log_covers_full_horizon | 1 | 1200/1200 ticks logged over the single 30 s horizon |
| plotted_reference_equals_production | 1 | the yaw reference drawn in the figures is the production output; observer vs production max abs diff = 0.000e+00 rad |
| wrap_events_actually_present | 1 | 1 wrap events on the wrapped reference, so the unwrap panel shows a real crossing rather than an empty claim |
| slew_bound_drawn_matches_code | 1 | the bound line drawn is deg2rad(40)*dt_g = 5.235988e-02 rad, read from the implemented expression |
| axis_labels_carry_units_and_frames | 1 | every plotted axis is labelled with unit and frame: positions m NED with z down, angles deg (wrapped where stated), curvature rad/m, cross-track m signed positive to starboard of the path, time s |
| tex_interpreter_disabled | 1 | all titles, labels, legends and tick labels use Interpreter none so underscored names render literally |

| Figure | KiB | px |
|---|---|---|
| GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE.png | 223.5 | 1925x1284 |
| GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_qa.png | 92.6 | 1605x1032 |

## 12. Limits of this evidence

- One cell, one nominal 30 s horizon, no disturbance, no sensor chain and no actuator chain. Everything here describes the frozen R10_U1.5 nominal trajectory and nothing else.
- The cell geometry remains an ASSUMED_RECONSTRUCTION carried from the Gate 8 record. The external fingerprint proves the same arithmetic is being driven; it does not upgrade the geometry label.
- The curvature-lead law is a smooth-curvature idealisation. On a 26-point polyline the instantaneous residual is dominated by waypoint quantisation, so only the windowed mean is interpreted.
- The crab residual is classified, not corrected. `k_beta` is still 1.35 in production.
- No estimator exists on this path: x and y are truth, not estimated. Unchanged and declared, not faked.
- Hardware **NOT_CERTIFIED**. Gate 9 remains **locked**; Gate 9B remains post-Gate 9.

## 13. Next exact task

`gate8_r10_shadow_course_reference_offset_probe` - run SHADOW_COURSE_REFERENCE_OFFSET_CANDIDATE_C1 as a logged shadow signal on the same frozen cell under the same external fingerprint, parity-first, and report the course-offset difference without touching production. Promotion stays out of scope until that probe has its own gate.

