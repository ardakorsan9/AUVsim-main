# GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION - PASS

**TASK_ID:** `GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001`  
**Date:** 2026-08-09 08:40:33  
**Class:** bounded read-only closed-loop diagnostic after the R10 plant-feasibility PASS  
**MATLAB runs:** 1 (single bounded invocation, no retry)  
**Production / CODEX_VERTICAL_PLAN:** untouched (read-only inputs, fingerprinted pre and post)  
**Physical / hardware readiness:** **NOT_CERTIFIED**  
**Gate 9:** locked  
**Host runtime:** 109.2 s  

## 1. Verdict and answer

**PASS.**

The stored nominal cell was reproduced bit-for-bit, so the instrumentation describes the frozen production loop and attribution is admissible.

**Earliest stage that demands or creates the 25 deg rudder envelope: `S2_CTRL_TERM_P` (class CONTROLLER), first at t = 1.200 s.**

**BLOCKER.** No single rail origin is evidenced, therefore no corrective candidate is stated. Reasons: 3 existing contributions reach the 25 deg envelope on their own, so the demand is not traceable to one term. A corrective candidate proposed on a multi-origin or unreproduced rail would be a guess presented as a finding.

Nothing here is promoted, and no gain, law, path, threshold, shaper or feedforward was added or changed.

## 2. Scope

| Item | Value |
|---|---|
| Cell | `R10_U1.5` (family R10, U = 1.50 m/s), index 7 |
| Horizon | 30.0 s at dt = 0.0250 s, 1200 control ticks, nominal only |
| Draws / hooks | none: no Monte Carlo draw, no sensor, actuator or power hook |
| Scope note | exactly one cell (R10_U1.5, index 7 of 8) and exactly one nominal horizon; no Monte Carlo draw, no sensor hook, no actuator hook, no power hook |
| Free disk at start | 4.46 GiB (>= 3 GiB: 1) |
| Artifact footprint | 0.52 MiB (< 150 MiB: 1) |

## 3. Sources (exactly 3, no repo scan)

| # | Path | Fingerprint |
|---|---|---|
| 1 | `controller_law.m` | `n=9402.s1=732890.s2=3334742186` |
| 2 | `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` |
| 3 | `run_gate8_actuator_order_scan_repair.m` | `n=121098.s1=9464134.s2=3103638627` |

**Record dereferenced by reference:** `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR.mat`, fingerprint `n=1027924.s1=134415885.s2=723942667`. FROZEN_BY_REFERENCE - the accepted Gate 8 attempt-2 record. Its path is the artifact path source #3 declares for itself (fullfile('suite_results', TAG)); it is a transitive dependency of source #3, not a fourth reasoning source. cfg, the campaign constants and the stored nominal fingerprints are taken from it verbatim and never re-derived. Fingerprint equality below is the proof that the same record was used.

Record identity: `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_001`, created 2026-08-09 04:30:20, verdict FAIL.

**Cell geometry provenance:** ASSUMED_RECONSTRUCTION - the frozen X / XZ / R10 cell definitions (waypoints, horizon, initial state, u_ref schedule) live in per-cell driver scripts that are outside this task 3-source budget. Geometry here is harness-declared, NOT the frozen production cell. U labels the initial BODY surge trim; u_ref is owned internally by production guidance_law.

**Recorded plant trim requirement:** 4.058 deg. RECORDED_EVIDENCE quoted by the task statement from the R10 plant feasibility PASS: the steady rudder the plant requires to hold this turn. It is reported here for comparison only. It is not used as a gate, a threshold or a target, and nothing in this driver is tuned toward it.

## 4. Frames and units

| Item | Value |
|---|---|
| frames.position | NED inertial [m]; z positive DOWN (depth = +z) |
| frames.rates | BODY angular rates p,q,r [rad/s]; BODY velocity u,v,w [m/s] |
| frames.euler | phi,theta,psi [rad] internally (deg only where a name says _deg) |
| frames.pitch_sign | theta > 0 = nose UP = depth decreasing |
| frames.actuators | delta_e, delta_r signed per production convention; thrust pu |
| frames.units | SI (m, m/s, rad, rad/s, s); deg only where labelled |
| frames.source_ref | GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.mat R.frames (frozen chain from GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat, not re-derived) |
| frames.label | INTERFACE_SPECIFIED |
| frames.derived_units | rail dwell and rate dwell are dimensionless fractions of the run; realized slew in deg/s; fin limits in deg; energy proxies in native units |
| frames.this_task_note | positions NED in m with z positive down; BODY rates p,q,r; angles in rad internally and deg only where a name says so; rudder deflection deg; curvature 1/m; arc length m; dwell is a dimensionless fraction of the horizon |
| declared rudder envelope | 25.0000 deg, read from the production parameter set at run time; recorded configuration value 25 deg (match 1) |
| controller rate limit | 40 deg/s, i.e. 1.0000 deg per 0.0250 s tick |
| controller / guidance period | 0.0250 s / 0.0750 s |

Production fingerprints:

| File | pre | post | == record |
|---|---|---|---|
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | `n=10845.s1=886194.s2=515073390` | 1 |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | `n=9402.s1=732890.s2=3334742186` | 1 |
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | `n=14601.s1=1095745.s2=3464382495` | 1 |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | `n=6065.s1=426918.s2=1254438441` | 1 |
| `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990739` | `n=11604.s1=883372.s2=792990739` | 1 |
| `suite_results/CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | `n=43101.s1=4310210.s2=3268810005` | 1 |

Fingerprint formula `n=<bytes>.s1=<sum>.s2=<mod(sum(i*b_i),2^32)>`, identical to the formula the accepted record uses, so the columns are directly comparable.

## 5. Reproduction BEFORE attribution

| Execution | What it is | Fingerprint | Equal to |
|---|---|---|---|
| A | unmodified production `continuous_path_tracking` | `n=153600.s1=19094896.s2=2901292177` | stored nominal: 1 |
| B | shadow replica of the accepted hooks-off loop, 3-output controller call | `n=153600.s1=19094896.s2=2901292177` | stored hooks-off: 1, A: 1 |
| C | same replica reading the optional 4th controller output | `n=153600.s1=19094896.s2=2901292177` | B: 1, A: 1 |
| D | deterministic replay of C | `n=153600.s1=19094896.s2=2901292177` | C external: 1, C full log: 1 |

Stored nominal fingerprint `n=153600.s1=19094896.s2=2901292177`; stored hooks-off fingerprint `n=153600.s1=19094896.s2=2901292177`.

Parity detail, production against the instrumented replica: bit-identical on vp,t,vel,av,ori,yaw_ref,pitch_ref,u_ref.

**Reproduction admitted: 1.** Attribution is reported only under this condition.

The recorded rail evidence for this cell in the accepted record is max abs rudder 25.000 deg with dwell 0.2817; this run measures 25.000 deg with dwell 0.2817 on the same horizon.

## 6. Logged channels: units, frames, provenance

| # | Channel | Unit | Provenance and frame |
|---|---|---|---|
| 1 | `t` | s | HARNESS | simulation time at which this control tick executed, i.e. (k-1)*dt |
| 2 | `x_ned` | m | PLANT_STATE | NED x of the plant state entering this tick (truth) |
| 3 | `y_ned` | m | PLANT_STATE | NED y of the plant state entering this tick (truth) |
| 4 | `z_ned` | m | PLANT_STATE | NED z, positive down (depth), entering this tick (truth) |
| 5 | `phi_deg` | deg | PLANT_STATE | BODY roll angle (truth) |
| 6 | `theta_deg` | deg | PLANT_STATE | BODY pitch angle, model sign (truth) |
| 7 | `psi_deg` | deg | PLANT_STATE | BODY yaw angle in NED (truth) |
| 8 | `u_body` | m/s | PLANT_STATE | BODY surge velocity (truth) |
| 9 | `v_body` | m/s | PLANT_STATE | BODY sway velocity (truth) |
| 10 | `r_body_degs` | deg/s | PLANT_STATE | BODY yaw rate fed to the controller (truth, hooks off) |
| 11 | `p_body_degs` | deg/s | PLANT_STATE | BODY roll rate fed to the controller (truth, hooks off) |
| 12 | `kappa_f_invm` | 1/m | GUIDANCE_PUBLISHED | filtered path curvature at the guidance progress point |
| 13 | `R_path_m` | m | GUIDANCE_DERIVED | path radius 1/max(|kappa_f|,1e-4) as guidance forms it |
| 14 | `U_h_guid` | m/s | GUIDANCE_PUBLISHED | inertial horizontal speed used by guidance for the yaw-rate feedforward |
| 15 | `seg_idx` | - | RECONSTRUCTED_GEOMETRY | index of the nearest waypoint-polyline segment |
| 16 | `s_proj_m` | m | RECONSTRUCTED_GEOMETRY | arc length of the nearest-point projection along the polyline |
| 17 | `cte_signed_m` | m | RECONSTRUCTED_GEOMETRY | horizontal cross-track, positive to the left-hand normal of the path tangent |
| 18 | `cte_abs3d_m` | m | RECONSTRUCTED_GEOMETRY | unsigned 3D distance to the polyline |
| 19 | `z_err_m` | m | RECONSTRUCTED_GEOMETRY | z minus path z at the projection, positive = vehicle below path |
| 20 | `yaw_ref_deg` | deg | GUIDANCE_OUTPUT | yaw reference in NED handed to the controller |
| 21 | `e_psi_deg` | deg | CONTROLLER_PUBLISHED | wrapped heading error yaw_ref minus psi as the controller forms it |
| 22 | `r_ff_degs` | deg/s | GUIDANCE_OUTPUT | yaw-rate feedforward handed to the controller |
| 23 | `e_r_degs` | deg/s | CONTROLLER_PUBLISHED | yaw-rate error r minus r_ff as the controller forms it |
| 24 | `term_P_deg` | deg | RECONSTRUCTED_FROM_PUBLISHED | existing proportional heading contribution Kp_psi * e_psi |
| 25 | `term_D_deg` | deg | RECONSTRUCTED_FROM_PUBLISHED | existing yaw-rate damping contribution -Kd_psi * r |
| 26 | `term_FF_deg` | deg | RECONSTRUCTED_FROM_PUBLISHED | existing feedforward contribution +Kd_psi * r_ff |
| 27 | `dr_yaw_deg` | deg | CONTROLLER_PUBLISHED | published yaw-channel sum before the roll damp is added |
| 28 | `dr_p_deg` | deg | CONTROLLER_PUBLISHED | published unscaled roll-rate damp -Kp_roll * p |
| 29 | `g_ac_frac` | - | CONTROLLER_PUBLISHED | published gain-scheduling factor applied to the roll damp |
| 30 | `dr_damp_deg` | deg | CONTROLLER_PUBLISHED | published scheduled roll damp g_ac * dr_p |
| 31 | `dr_raw_deg` | deg | RECONSTRUCTED_FROM_PUBLISHED | raw rudder command before any limiter, dr_yaw + dr_damp |
| 32 | `dr_recon_deg` | deg | RECONSTRUCTED_FROM_PUBLISHED | sum of the four existing contributions, completeness check against dr_raw |
| 33 | `dr_postmag_deg` | deg | CONTROLLER_PUBLISHED | published command after the magnitude limit |
| 34 | `dr_postmag_rec_deg` | deg | RECONSTRUCTED_FROM_PUBLISHED | magnitude limit recomputed from dr_raw, checked against the published value |
| 35 | `dr_postrate_deg` | deg | CONTROLLER_PUBLISHED | published command after the rate limit, i.e. the controller return value |
| 36 | `dr_postrate_rec_deg` | deg | RECONSTRUCTED_FROM_PUBLISHED | rate limit recomputed from the previous tick, checked against the published one |
| 37 | `dr_plant_deg` | deg | HARNESS_OBSERVED | value actually placed in the plant control structure this tick |
| 38 | `mag_sat_flag` | - | RECONSTRUCTED_FROM_PUBLISHED | 1 when the magnitude limiter clipped the raw command this tick |
| 39 | `rate_sat_flag` | - | RECONSTRUCTED_FROM_PUBLISHED | 1 when the rate limiter clipped the post-magnitude command this tick |
| 40 | `rail_flag` | - | RECONSTRUCTED_FROM_PUBLISHED | 1 when the plant input sits at the declared magnitude envelope |
| 41 | `slew_degs` | deg/s | RECONSTRUCTED_FROM_PUBLISHED | realized rudder slew of the plant input over this tick |
| 42 | `delta_e_deg` | deg | CONTROLLER_OUTPUT | elevator command returned by the controller, logged for context only |
| 43 | `delta_r_max_deg` | deg | PRODUCTION_PARAMETER | declared rudder magnitude envelope read from the production parameter set |

`CONTROLLER_PUBLISHED` means the value is read from the optional diagnostic output the production controller already exports. `GUIDANCE_PUBLISHED` means it is read from a diagnostic global the production guidance already publishes. `RECONSTRUCTED_FROM_PUBLISHED` means it is recomputed here from those published values and checked against a published result in section 8. `RECONSTRUCTED_GEOMETRY` means it is computed here from the logged position and the cell waypoint polyline: it is nearest-point projection over the whole polyline, which is not the monotonic forward-window projection guidance keeps internally, and that difference is declared rather than absorbed. No channel is named that the loop does not actually produce.

## 7. Rail measurement

| Quantity | Value |
|---|---|
| Declared rudder envelope | 25.0000 deg |
| Max abs raw command before any limiter | 466.6729 deg |
| Max abs plant input | 25.0000 deg |
| Max abs realized slew | 40.0000 deg/s |
| Rail dwell (plant input at the envelope) | 0.2817 of the horizon, 8.450 s, 12 intervals, longest 2.300 s, first at t = 1.825 s |
| Magnitude-limiter dwell | 0.8908 of the horizon, first at t = 1.200 s |
| Rate-limiter dwell | 0.6917 of the horizon, first at t = 0.000 s |
| Recorded plant trim requirement | 4.058 deg (evidence only) |
| Plant input peak / trim requirement | 6.161 |
| Raw demand peak / trim requirement | 115.001 |

Path geometry over the horizon: median curvature 0.09829 1/m (radius 10.174 m), median inertial horizontal speed 1.5607 m/s, yaw-rate feedforward median 8.7828 deg/s and peak 9.4881 deg/s, achieved yaw rate median 10.5940 deg/s, signed cross-track median 0.0393 m and peak abs 0.2126 m, path segments 1 to 16, arc length 0.00 to 47.53 m.

## 8. Attribution completeness

| Check | Value | Tolerance | Pass |
|---|---|---|---|
| max abs (sum of existing contributions minus logged raw command) | 1.137e-13 deg | 1.0e-09 deg | 1 |
| rms of that residual | 1.683e-14 deg | - | - |
| max abs (recomputed post-magnitude minus published post-magnitude) | 0.000e+00 deg | 1.0e-09 deg | 1 |
| max abs (recomputed post-rate minus published post-rate) | 0.000e+00 deg | 1.0e-09 deg | 1 |
| plant input identical to the published post-rate command | 1200/1200 samples | all | 1 |

The raw rudder command is fully accounted for by four existing contributions and nothing else. Because the reconstruction closes to 1.137e-13 deg with no integral term in the sum, no accumulating rudder state exists that could be carrying the command.

| Contribution | Peak abs [deg] | Median share of the raw command at rail samples | Median share over the horizon | Reaches the envelope alone |
|---|---|---|---|---|
| `S2_CTRL_TERM_P` | 434.5376 | 1.3114 | 1.0365 | 1 |
| `S3_CTRL_TERM_D` | 197.7222 | -0.8813 | -0.3148 | 1 |
| `S4_CTRL_TERM_FF` | 123.3455 | 0.5326 | 0.3766 | 1 |
| `S5_CTRL_TERM_ROLLDAMP` | 6.2432 | -0.0007 | -0.0014 | 0 |

Shares are computed over 338 samples, selected as samples with the plant input at the declared envelope.

## 9. Stage ladder

a stage DEMANDS the rail when its own output magnitude reaches the declared envelope before any limiter acts on it; a stage CREATES the rail when its output sits at the envelope while its input does not. The origin is the earliest stage in the executed order that does either.

| Stage | Class | Signal | Peak abs | Median abs | Demands the envelope | Creates the envelope | First at | Dwell | Dwell after 10 s |
|---|---|---|---|---|---|---|---|---|---|
| `S1_REFERENCE_TRANSIENT` | REFERENCE | heading error created by the yaw reference against the achieved heading | 13.5793 | 4.8774 | 0 | 0 | never | 0.0000 | 0.0000 |
| `S2_CTRL_TERM_P` | CONTROLLER | existing proportional heading contribution | 434.5376 | 156.0755 | 1 | 0 | 1.200 s | 0.8967 | 0.9350 |
| `S3_CTRL_TERM_D` | CONTROLLER | existing yaw-rate damping contribution | 197.7222 | 137.7224 | 1 | 0 | 1.400 s | 0.9067 | 0.9300 |
| `S4_CTRL_TERM_FF` | CONTROLLER | existing yaw-rate feedforward contribution | 123.3455 | 114.1767 | 1 | 0 | 1.200 s | 0.9600 | 1.0000 |
| `S5_CTRL_TERM_ROLLDAMP` | CONTROLLER | existing scheduled roll-rate damp contribution | 6.2432 | 0.5336 | 0 | 0 | never | 0.0000 | 0.0000 |
| `S6_RAW_SUM` | CONTROLLER | sum of the existing contributions before any limiter | 466.6729 | 129.8066 | 1 | 0 | 1.200 s | 0.8908 | 0.9437 |
| `S7_MAGNITUDE_LIMIT` | LIMITER | command after the magnitude limit | 25.0000 | 25.0000 | 1 | 1 | 1.200 s | 0.8908 | 0.9437 |
| `S8_RATE_LIMIT` | LIMITER | command after the rate limit | 25.0000 | 15.0000 | 1 | 0 | 1.825 s | 0.2817 | 0.3488 |
| `S9_PLANT_INPUT` | PLANT_INPUT | value handed to the plant | 25.0000 | 15.0000 | 1 | 0 | 1.825 s | 0.2817 | 0.3488 |

Peak and median are in deg for every stage except `S1_REFERENCE_TRANSIENT`, whose signal is a heading error in deg and is therefore never compared with a rudder envelope.

## 10. Category determinations

| Category | Determination | Evidence |
|---|---|---|
| reference transient | **EXCLUDED_AS_SOLE_CAUSE** | rail dwell 0.1475 over t < 10 s and 0.3488 over t >= 10 s; peak heading error 11.411 deg early and 13.579 deg late; heading error settles below 5 deg at no time in this horizon; maximum yaw-reference slew 105.414 deg/s |
| controller term | **EVIDENCED** | largest existing contribution is S2_CTRL_TERM_P at 434.538 deg peak with median share 1.3114 of the raw command at rail samples; 3 of 4 contributions reach the 25 deg envelope on their own |
| integrator windup | **EXCLUDED_STRUCTURALLY** | the rudder channel of the production controller carries no integral state: the raw command is fully reconstructed from the proportional, rate-damping, feedforward and roll-damp contributions with a maximum residual of 1.137e-13 deg over 1200 samples, so no unmodelled accumulating state can be carrying the command |
| magnitude limit | **ENGAGED_AS_CONSEQUENCE** | the magnitude limiter clipped on 0.8908 of the horizon, first at t = 1.200 s; the raw command it received peaked at 466.673 deg against the 25 deg envelope, so the limiter reports a demand it did not create |
| actuator dynamics | **NOT_PRESENT_IN_THIS_CELL** | this is the nominal hooks-off horizon: no lag, transport delay, jitter or slew model is inserted between the controller return value and the plant. The plant input equals the controller return value in 1200 of 1200 samples, and the realized slew 40.000 deg/s is produced by the controller rate limiter alone |

## 11. Transient against sustained

| Quantity | Value |
|---|---|
| Declared transient window | first 10 s of the horizon |
| Heading error settles below 5 deg | never within this horizon |
| Rail dwell inside the transient window | 0.1475 |
| Rail dwell after the transient window | 0.3488 |
| Peak abs heading error, transient / sustained | 11.4114 deg / 13.5793 deg |
| Median heading error after the transient window | 5.1897 deg |
| Peak yaw-reference slew | 105.4137 deg/s |
| Rail confined to the transient window | 0 |
| Rail sustained beyond the transient window | 1 |

## 12. Single-origin decision

Declared before evaluation. C1 the attribution arithmetic is complete, i.e. the reconstructed contributions sum to the logged raw command within tolerance. C2 the stored nominal cell was reproduced bit-for-bit, so the instrumentation describes production. C3 at most one existing contribution reaches the declared envelope on its own, so the demand is not traceable to two independent terms at once. C4 the earliest stage is unambiguous: either it is that one contribution and that contribution holds a median share of at least 0.90 of the raw command at rail samples, or no contribution reaches the envelope alone and the earliest stage is the summation of the existing contributions, in which case the origin is the superposition and is reported as such rather than as a term.

| Criterion | Result |
|---|---|
| C1 attribution arithmetic complete | 1 |
| C2 stored nominal cell reproduced bit-for-bit | 1 |
| C3 at most one contribution reaches the envelope alone | 0 (3 do) |
| C4 earliest stage unambiguous | 0 (earliest `S2_CTRL_TERM_P`, dominant contribution `S2_CTRL_TERM_P`, median share 1.3114) |
| Origin kind | AMBIGUOUS |
| **Single origin evidenced** | **0** |

earliest stage demanding or creating the 25 deg envelope = S2_CTRL_TERM_P (class CONTROLLER, kind AMBIGUOUS) at t = 1.200 s; C1 completeness 1, C2 reproduction 1, C3 at most one contribution reaches it alone 0 (3 do), C4 unambiguous earliest stage 0 (dominant contribution S2_CTRL_TERM_P, median share 1.3114)

**BLOCKER.** No single rail origin is evidenced, therefore no corrective candidate is stated. Reasons: 3 existing contributions reach the 25 deg envelope on their own, so the demand is not traceable to one term. A corrective candidate proposed on a multi-origin or unreproduced rail would be a guess presented as a finding.

## 13. Hard gates

| ID | Requirement | Pass | Detail |
|---|---|---|---|
| HL1 | Stored nominal cell reproduced: production, hooks-off replica and instrumented replica are bit-identical to each other | PASS | production hash n=153600.s1=19094896.s2=2901292177; hooks-off n=153600.s1=19094896.s2=2901292177; instrumented n=153600.s1=19094896.s2=2901292177; parity detail: bit-identical on vp,t,vel,av,ori,yaw_ref,pitch_ref,u_ref |
| HL2 | Exact baseline parity against the accepted Gate 8 record for this cell (external outputs and fingerprints) | PASS | stored nominal n=153600.s1=19094896.s2=2901292177 (match 1), stored hooks-off n=153600.s1=19094896.s2=2901292177 (match 1), instrumented match 1 |
| HL3 | Deterministic replay: the instrumented run reproduces its external outputs AND its full diagnostic log bit-for-bit | PASS | external hash equal 1, 1200x43 log matrix isequaln 1 |
| HL4 | Finite, complete logs over the full declared horizon (no NaN/Inf, no early termination) | PASS | 1200/1200 samples, all finite 1, T_final 30.0 s at dt 0.0250 s |
| HL5 | Attribution completeness: the reconstructed sum of existing controller contributions equals the logged raw rudder command within tolerance | PASS | max |sum(existing terms) - raw| = 1.137e-13 deg (tolerance 1.0e-09 deg); max |recomputed post-magnitude - published| = 0.000e+00 deg; max |recomputed post-rate - published| = 0.000e+00 deg; plant input equals published post-rate command in 1200/1200 samples |
| HL6 | Zero direct-actuator, surface or automatic-accommodation path anywhere in this driver | PASS | token audit clean=1, self-match-free=1, positive control 10/10; the only signal reaching the plant is the value the production controller returned, in 1200/1200 samples |
| HL7 | Production files and CODEX_VERTICAL_PLAN unchanged and identical to the accepted record | PASS | unchanged pre vs post = 1, identical to the record = 6/6 |
| HL8 | Read-only instrumentation: no gain, law, path, threshold, shaper or feedforward introduced or modified | PASS | the driver calls the unmodified production guidance_law and controller_law, reads the optional 4th controller output and the diagnostic globals both already export, and performs arithmetic only on copies. No global gain is written by this driver. Every reconstruction is checked against a published value (HL5). |
| HL9 | Single 30 s nominal horizon on exactly one cell, one MATLAB invocation, no retry | PASS | R10_U1.5, 30.0 s, 4 executions of that same horizon (production, hooks-off, instrumented, replay) inside one invocation |
| HL10 | A single rail origin is evidenced by the declared criteria, otherwise a blocker is stated instead of a conclusion | PASS | earliest stage demanding or creating the 25 deg envelope = S2_CTRL_TERM_P (class CONTROLLER, kind AMBIGUOUS) at t = 1.200 s; C1 completeness 1, C2 reproduction 1, C3 at most one contribution reaches it alone 0 (3 do), C4 unambiguous earliest stage 0 (dominant contribution S2_CTRL_TERM_P, median share 1.3114) |

## 14. Forbidden-path audit

| Property | Value |
|---|---|
| Construction | tokens assembled from two fragments at run time; the fenced declaration block holds fragments only, so no complete token literal exists in the file |
| Tokens checked | 10 |
| Declaration lines excluded | 5 of 1855 |
| Hits including the declaration region | 0 |
| Hits excluding the declaration region | 0 |
| Self-match free | 1 |
| Positive control | 1 (10 of 10 tokens detected in a synthetic probe) |
| Audit clean | 1 |

The only value that reaches the plant in this driver is the value the production controller returned, verified sample by sample in section 8. There is no direct-actuator path, no surface path and no automatic accommodation path.

## 15. Visual QA (programmatic)

visual QA is programmatic: every figure file is re-opened after writing, its pixel dimensions are read back, and the series it claims to show are re-checked against the recorded log. Nothing here is a human impression.

**Verdict: VISUAL_QA_PASS.**

| Check | Pass | Detail |
|---|---|---|
| `files_written` | 1 | 2/2 PNG files exist, exceed 8 KiB and are at least 600x400 px |
| `log_all_finite` | 1 | 1200 samples x 43 channels, all finite |
| `horizon_complete` | 1 | the last control tick executes at t = 29.9750 s, one step dt = 0.0250 s before the declared 30.0 s horizon end, and 1200 ticks were logged |
| `plotted_chain_is_ordered` | 1 | the plotted post-magnitude series never exceeds the raw series it is derived from |
| `plant_input_within_envelope` | 1 | max abs plant rudder input 25.0000 deg against the declared 25 deg envelope |
| `declared_envelope_matches_record` | 1 | production rudder envelope 25.0000 deg equals the recorded configuration value 25 deg |
| `rail_evidence_present` | 1 | the plant input reaches the declared envelope on 0.2817 of the horizon, first at t = 1.825 s |
| `axis_labels_carry_units` | 1 | every plotted axis carries its unit and frame: positions m NED, depth m positive down, rudder deg, slew deg/s, yaw rate deg/s, curvature 1/m, cross-track m, time s, dwell a dimensionless fraction of the horizon |
| `tex_interpreter_disabled` | 1 | all titles, legends and tick labels are drawn with Interpreter none, so underscored names render literally |

| Figure | Size [KiB] | Pixels | OK |
|---|---|---|---|
| `GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.png` | 330.7 | 1925x1513 | 1 |
| `GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_01_reproduction_and_closure.png` | 119.8 | 1605x1032 | 1 |
| `GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_02_visual_qa.png` | 83.1 | 1433x803 | 1 |

## 16. Honesty ledger

| Claim | Status |
|---|---|
| Attribution validity | conditional on bit-identical reproduction of the stored nominal cell; admitted = 1 |
| Cross-track, segment index and arc length | **RECONSTRUCTED_GEOMETRY** - computed here by nearest-point projection on the cell polyline, not read from guidance internals, which use a monotonic forward-window projection |
| Controller contributions | read from values the production controller already publishes, then re-summed and checked against the published raw command |
| Integrator windup on the rudder channel | **EXCLUDED_STRUCTURALLY** - no integral state exists there and the reconstruction closes without one |
| Actuator dynamics | **NOT_PRESENT** in this nominal cell - no lag, delay, jitter or slew model is inserted; the plant input is the controller return value |
| Plant trim requirement 4.058 deg | **RECORDED_EVIDENCE ONLY** - reported for comparison, never used as a threshold or a target |
| Cell geometry | **ASSUMED_RECONSTRUCTION** carried unchanged from the accepted record, byte-identical, which makes the comparison valid without making the geometry frozen |
| Corrective candidate | stated only if a single origin is evidenced, and stated as a bounded measurement task, never as an applied change |
| Promotion | none. No gate is moved by this task |
| Hardware | **NOT_CERTIFIED**. A simulation result is never hardware certification |
| Gate 9 | **locked** |

## 17. Artifacts

- `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.png`
- `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_01_reproduction_and_closure.png`
- `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_02_visual_qa.png`
- `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.md`
- `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.mat`
- `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_run.log`

Total footprint 0.52 MiB (< 150 MiB: 1).

All priors and reconstructions remain **ASSUMED**. Hardware remains **NOT_CERTIFIED**. Gate 9 remains **locked**; Gate 9B remains post-Gate 9.
