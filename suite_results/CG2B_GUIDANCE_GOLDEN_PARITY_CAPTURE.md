# CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE

**TASK_ID:** `CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001`  
**Corpus:** `CG2B_GUIDANCE_GOLDEN_V1` (schema_version=1)  
**Mode:** SIMULATION_ONLY · MATLAB-only · no MEX/codegen/compiler  
**Captured (UTC):** 2026-08-10T00:29:14Z  
**Hardware:** **NOT_CERTIFIED**  
**Compiler:** deferred (CG_PRE0 PARTIAL carried)  
**C++ parity:** **NOT CLAIMED**  
**CODEX_VERTICAL_PLAN.md:** UNTOUCHED  

> ### Verdict: **PASS**

| PASS gate | Required | Observed | Met? |
|---|---|---|---|
| Deterministic replay (`isequaln` Y+Diagnostics) | yes | outputs=1 diag=1 | YES |
| Finite outputs (+ diagnostics/inputs) | yes | Y=1 Dbg=1 U=1 | YES |
| Source fingerprint unchanged | yes | guidance/init match pre=post | YES |

**Next exact task (exactly one):** `CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001`

---

## 1. Corpus dimensions

| Field | Value |
|---|---:|
| N_steps | 102 |
| N_inputs_call | 8 (full guidance_law arity) |
| MAX_PATH_POINTS | 32 |
| N_paths | 8 |
| dt_guidance (forced accepted) | 0.075 s |
| Diagnostic fields recorded | 11 |
| Cases | 16 |
| Replays | 2 (identical `reset_before` + `clear guidance_law`) |
| MATLAB invocations | 1 |

**Call signature (fixed 8 inputs → 6 outputs):**  
`[yaw_ref,pitch_ref,u_ref,next_progress_index,r_ff,pitch_ref_dot]=guidance_law(pos,path,prog,u,v,U_h,zdot,theta_phys)`

**Corpus U columns:**  
`pos_x, pos_y, pos_z, progress_index, u_body, v_body, U_h, zdot_inertial, theta_phys` + `path_id` (legacy call uses active `path_pad(1:n_path,:,id)` rows).

**Diagnostic globals recorded:**  
`last_guidance_U_h, last_guidance_kappa, last_r_ff, last_gamma_actual, last_gamma_path, last_alpha_eff, last_e_gamma, last_e_z, last_e_zdot, last_zdot_inertial, last_alpha_hat`

---

## 2. Coverage matrix

| Case ID | Steps | Path | Coverage tag |
|---|---:|---:|---|
| `C01_cold_open_straight` | 6 | 1 | cold;open_straight |
| `C_u_1` | 4 | 1 | U_h=u_body=1 |
| `C_u_1.5` | 4 | 1 | U_h=u_body=1.5 |
| `C_u_2` | 4 | 1 | U_h=u_body=2 |
| `C05_cte_pos` | 5 | 1 | positive_cross_track |
| `C06_cte_neg` | 5 | 1 | negative_cross_track |
| `C07_depth_pos` | 6 | 1 | positive_depth_error;vehicle_below |
| `C08_depth_neg` | 6 | 1 | negative_depth_error;vehicle_above |
| `C09_multiseg_curve` | 8 | 2 | multi_segment;curvature |
| `C10_closed_seam` | 8 | 3 | closed_path_seam |
| `C11_near_end` | 6 | 4 | near_end_slowdown |
| `C12_progress_backsnap` | 8 | 1 | progress_advance;back_snap_protect |
| `C13_yaw_wrap_pos_pi` | 8 | 6 | course_yaw_wrap_+pi |
| `C14_yaw_wrap_neg_pi` | 8 | 7 | course_yaw_wrap_-pi |
| `C15_beta_sway` | 6 | 1 | nonzero_sway_beta |
| `C16_tur4a5a5b` | 10 | 8 | Tur4A_r_ff;Tur5A_zdot;Tur5B_theta_phys;accepted_gains |

| Probe | Result |
|---|---|
| U_h∈{1.0,1.5,2.0} | 1/1/1 |
| ± cross-track | 1 / 1 |
| ± depth error | 1 / 1 |
| nonzero sway β | 1 |
| nonzero zdot / theta_phys | 1 / 1 |
| Tur4A κ / r_ff activity | 1 |
| near-end u_ref slowdown | 1 |
| yaw unwrap span | 1 |
| reset_before boundaries | 1 |
| accepted K_zdot=0 / K_gamma=0 / α̂ off | 1/1/1 |

### Path library (padded MAX×3 + n_path)

| path_id | name | n_path | closed | note |
|---|---|---:|---|---|
| 1 | `open_straight_x` | 7 | 0 | cold/open straight |
| 2 | `open_curve_climb` | 6 | 0 | multi-segment/curvature |
| 3 | `closed_square` | 5 | 1 | closed-path seam |
| 4 | `open_short_end` | 5 | 0 | near-end slowdown |
| 5 | `open_neg_x_pi` | 5 | 0 | course ~+pi |
| 6 | `arc_cross_pos_pi` | 9 | 0 | yaw wrap +pi |
| 7 | `arc_cross_neg_pi` | 9 | 0 | yaw wrap -pi |
| 8 | `closed_circle_r10` | 17 | 1 | Tur4A curvature |

---

## 3. Source hashes

| File | Bytes | SHA-256 (pre) | Post match |
|---|---:|---|---|
| `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` | YES |
| `init_parameters.m` | 4205 | `09803f4956b64227403919229781086c367e620f5736cfd680d1b15081237a9a` | YES |

---

## 4. Parameter snapshot (accepted)

| Param | Value |
|---|---:|
| dt_guidance | 0.075 |
| dt_controller | 0.025 |
| lookahead_distance | 1.25 |
| desired_speed | 1.5 |
| pitch_ref_max / rate_max [rad]/[rad/s] | 0.453785605519 / 0.10471975512 |
| K_zdot (accepted Tur5A) | 0 |
| K_gamma (accepted Tur5B) | 0 |
| enable_alpha_hat | 0 |
| k_beta (frozen literal) | 1.35 |
| MAX_PATH_POINTS (corpus) | 32 |

---

## 5. Finite / range / slew / progress checks

| Check | Pass |
|---|---|
| Inputs finite | YES |
| Outputs finite | YES |
| Diagnostics finite | YES |
| |pitch_ref| ≤ pitch_ref_max | YES |
| |r_ff| ≤ 40°/s | YES |
| pitch slew ≤ rate_max·dt (non-reset) | YES (max step 0.00785398 vs lim 0.00785398) |
| open-path progress nondecreasing | YES |
| next_progress_index ∈ [1,n_path] | YES |

---

## 6. Determinism

Within one MATLAB process: replay A with `clear guidance_law` at each `reset_before`, then `clear guidance_law` and replay B with identical resets on identical `U`/paths.

| Item | `isequaln` |
|---|---|
| Outputs (6) | YES |
| Diagnostics (all last_* globals) | YES |
| Determinism PASS | YES |

---

## 7. Artifacts

| Path | Role |
|---|---|
| `suite_results/CG2B_GUIDANCE_GOLDEN_V1.mat` | lean versioned corpus (U,paths,Y,Diagnostics,params,det,checks) |
| `suite_results/CG2B_GUIDANCE_GOLDEN_V1.json` | schema/hashes/determinism metadata |
| `run_cg2b_guidance_golden_parity_capture.m` | SIMULATION_ONLY harness |
| `guidance_law.m` / `init_parameters.m` | **UNTOUCHED** |

**Units/frames:** position/path m NED; speeds m/s BODY or NED-horiz as named; angles rad; `yaw_ref` continuous unwrap; Tur4A `r_ff=U_h*κ`; Tur5A/B inputs exercised at accepted K_zdot=0, K_gamma=0, enable_alpha_hat=false.

Rejected methods remain closed (γ-structural / LADRC / INDI / crab-current-FF / polyline substitutes). No production call-path change. This capture is a MATLAB golden twin baseline — **not** C++ parity.

---

*End of CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE. Verdict: **PASS**. Next: `CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001`.*
