# CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE

**TASK_ID:** `CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001`  
**Corpus:** `CG2A_CONTROLLER_GOLDEN_V1` (schema_version=1)  
**Mode:** SIMULATION_ONLY · MATLAB-only · no MEX/codegen/compiler  
**Captured (UTC):** 2026-08-10T00:00:34Z  
**Hardware:** **NOT_CERTIFIED**  
**Compiler:** deferred (CG_PRE0 PARTIAL carried)  
**C++ parity:** **NOT CLAIMED**  
**CODEX_VERTICAL_PLAN.md:** UNTOUCHED  

> ### Verdict: **PASS**

| PASS gate | Required | Observed | Met? |
|---|---|---|---|
| Deterministic replay (`isequaln` Y+Debug) | yes | outputs=1 debug=1 | YES |
| Finite outputs (+ debug/inputs) | yes | Y=1 Dbg=1 U=1 | YES |
| Source fingerprint unchanged | yes | ctrl/init match pre=post | YES |

**Next exact task (exactly one):** `CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001`

---

## 1. Corpus dimensions

| Field | Value |
|---|---:|
| N_steps | 100 |
| N_inputs | 13 |
| dt_controller (forced accepted) | 0.025 s |
| Debug fields recorded | 30 |
| Cases | 13 |
| Replays | 2 (clear `controller_law` between) |
| MATLAB invocations | 1 |

**Input columns (fixed order):**  
`yaw_ref, pitch_ref, u_ref, psi, theta, r, q, u, r_ff, pitch_ref_dot, phi, w, p`

**Debug fields (every fixed field):**  
`e_theta, theta_phys, theta_phys_dot, int_angle, int_angle_max, int_rate, de_trim, de_uw_ff, de_fb, delta_e_angle_I, delta_e_cmd, delta_e_unsat, M_uw, M_elev, M_e_ff, G_de, b_u, rate_filt, theta_rate_cmd, mag_sat, p, e_psi, e_r, dr_yaw, dr_p, dr_damp, g_ac, delta_r_cmd, delta_r, Kp_roll`

---

## 2. Coverage matrix

| Case ID | Steps | Coverage tag |
|---|---:|---|
| `C01_cold_nominal` | 6 | cold_nominal;U=1.5 |
| `C_u_1` | 4 | U=1;trim_lookup |
| `C_u_1.5` | 4 | U=1.5;trim_lookup |
| `C_u_2` | 4 | U=2;trim_lookup |
| `C05_yaw_wrap_pos_pi` | 5 | yaw_wrap_+pi_boundary |
| `C06_yaw_wrap_neg_pi` | 5 | yaw_wrap_-pi_boundary |
| `C07_climb` | 8 | climb;pitch_ref>0;climb_ff |
| `C08_descent` | 8 | descent;pitch_ref<0;climb_ff |
| `C09_rudder_mag_slew` | 12 | rudder_magnitude;slew_40dps |
| `C10_elevator_mag_slew` | 12 | elevator_magnitude;slew_40dps |
| `C11_pitch_I_AW` | 16 | pitch_integrator;anti_windup_memory |
| `C12_roll_rate_damp` | 8 | roll_rate_damping;Kp_roll |
| `C13_muw_w_lambda0` | 8 | nonzero_w;accepted_lambda_muw_ff=0 |

| Probe | Result |
|---|---|
| U∈{1.0,1.5,2.0} | 1/1/1 |
| yaw wrap ±π | 1 |
| climb / descent | 1 / 1 |
| rudder mag/slew | 1 |
| elevator mag/slew | 1 |
| pitch I memory | 1 |
| AW activity | 1 |
| roll-rate damp | 1 |
| nonzero w + M_uw | 1 |
| accepted λ_muw_ff=0 | 1 |
| de_uw_ff identity (λ=0) | 1 |

---

## 3. Source hashes

| File | Bytes | SHA-256 (pre) | Post match |
|---|---:|---|---|
| `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` | YES |
| `init_parameters.m` | 4205 | `09803f4956b64227403919229781086c367e620f5736cfd680d1b15081237a9a` | YES |

---

## 4. Parameter snapshot (accepted)

| Param | Value |
|---|---:|
| dt_controller | 0.025 |
| tau_rate | 0.05 |
| Kp_psi / Kd_psi / Kp_x | 32 / 13 / 25 |
| Kp_roll | 0.605072 |
| Kp_angle / Ki_angle | 1.25 / 0.16 |
| Kp_rate / Ki_rate / Kaw_pitch | 0.95 / 0 / 1.2 |
| Kd_rate / Kd_damp | 0 / 0.8 |
| delta_r_max / delta_e_max [rad] | 0.436332312999 / 0.261799387799 |
| thrust_trim / min / max | 13.4 / -100 / 300 |
| elevator_sign | 1 |
| Muw / Muuds | 24 / -6.15 |
| lambda_muw_ff (accepted) | 0 |
| trim_speed_table | [0.8 1 1.5 2 ] |
| trim_elevator_table [rad] | [-0.160221 -0.127933 -0.0806342 -0.0553269 ] |
| k_gamma_climb / de_climb_lim | 0.1320695001 / 0.0502532651527 |
| slew_max | 40 deg/s (0.698131700798 rad/s) |

---

## 5. Finite / bounds / slew checks

| Check | Pass |
|---|---|
| Inputs finite | YES |
| Outputs finite | YES |
| Debug finite | YES |
| |δr| ≤ delta_r_max | YES |
| |δe| ≤ delta_e_max | YES |
| thrust in [min,max] | YES |
| rudder slew ≤ 40°/s·dt | YES (max step 0.0174533 rad vs lim 0.0174533) |
| elevator slew ≤ 40°/s·dt | YES (max step 0.0174533 rad vs lim 0.0174533) |

---

## 6. Determinism

Within one MATLAB process: replay A, `clear controller_law`, replay B on identical `U`.

| Item | `isequaln` |
|---|---|
| Outputs `(delta_r,delta_e,thrust)` | YES |
| Debug (all fixed fields) | YES |
| Determinism PASS | YES |

---

## 7. Artifacts

| Path | Role |
|---|---|
| `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat` | lean versioned corpus (U,Y,Debug,params,det,checks) |
| `suite_results/CG2A_CONTROLLER_GOLDEN_V1.json` | schema/hashes/determinism metadata |
| `run_cg2a_controller_golden_parity_capture.m` | SIMULATION_ONLY harness |
| `controller_law.m` / `init_parameters.m` | **UNTOUCHED** |

**Units/frames:** angles rad; rates rad/s BODY; surge/heave m/s BODY; thrust N; `theta` sim convention with `theta_phys=-theta`; pitch_ref physical.

Rejected methods remain closed. No production call-path change. This capture is a MATLAB golden twin baseline — **not** C++ parity.

---

*End of CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE. Verdict: **PASS**. Next: `CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001`.*
