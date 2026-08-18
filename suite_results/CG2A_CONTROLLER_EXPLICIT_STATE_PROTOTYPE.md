# CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE

**TASK_ID:** `CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001`  
**Mode:** SIMULATION_ONLY · MATLAB-only · no MEX/codegen/compiler  
**Executed (UTC):** 2026-08-10T00:14:37Z  
**Hardware:** **NOT_CERTIFIED**  
**Compiler:** deferred (CG_PRE0 PARTIAL carried)  
**C++ parity:** **NOT CLAIMED**  
**Production call path:** UNTOUCHED  
**CODEX_VERTICAL_PLAN.md:** UNTOUCHED  
**Prototype label:** `DEPLOY_CANDIDATE/NOT_IN_PRODUCTION`  

> ### Verdict: **PASS**

| PASS gate | Required | Observed | Met? |
|---|---|---|---|
| Exact `isequaln` Output vs golden | yes | out_exact=1 | YES |
| Exact `isequaln` Debug vs golden | yes | dbg_exact=1 | YES |
| Dual reset replay equality | yes | out=1 dbg=1 | YES |
| `controller_law.m` fingerprint | untouched | match=1 | YES |

**Next exact task (exactly one):** `CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001`

---

## 1. API schema (fixed field sets)

```text
params = controller_codegen_init(params_in)   % from golden snapshot only
state  = controller_codegen_reset(params)     % deterministic zeros
[state,out,dbg] = controller_codegen_step(params,state,in)
```

**Params:** `Kp_psi,Kd_psi,Kp_x,Kp_roll,Kp_angle,Ki_angle,Kp_rate,Ki_rate,Kaw_pitch,Kd_rate,Kd_damp,delta_r_max,delta_e_max,thrust_max,thrust_min,thrust_trim,trim_speed_table,trim_elevator_table,elevator_sign,dt_controller,tau_rate,Muw,Muuds,lambda_muw_ff,muw_ff_u_min,muw_ff_u_lo,muw_ff_u_hi,muw_ff_clamp_deg,delta_e_trim,k_gamma_climb,de_climb_lim,slew_max_rad_s`

**State:** `prev_delta_r,prev_delta_e,int_angle,int_rate,rate_filt,prev_e_rate,initialized`

**Input:** `yaw_ref,pitch_ref,u_ref,psi,theta,r,q,u,r_ff,pitch_ref_dot,phi,w,p`

**Output:** `delta_r,delta_e,thrust`

**Debug (30):** `e_theta, theta_phys, theta_phys_dot, int_angle, int_angle_max, int_rate, de_trim, de_uw_ff, de_fb, delta_e_angle_I, delta_e_cmd, delta_e_unsat, M_uw, M_elev, M_e_ff, G_de, b_u, rate_filt, theta_rate_cmd, mag_sat, p, e_psi, e_r, dr_yaw, dr_p, dr_damp, g_ac, delta_r_cmd, delta_r, Kp_roll`

---

## 2. Parity vs `CG2A_CONTROLLER_GOLDEN_V1`

| Item | Value |
|---|---:|
| N_steps | 100 |
| dt | 0.025 |
| Output exact | 1 |
| Debug exact | 1 |
| Dual-reset exact | 1 |
| Output max abs | 0 |
| Output max rel | 0 |
| Output worst field | - @k=0 |
| Debug max abs | 0 |
| Debug max rel | 0 |
| Debug worst field | - @k=0 |
| MATLAB invocations | 1 |

---

## 3. Bounds / slew (prototype replay)

| Check | Pass |
|---|---|
| Outputs finite | YES |
| Debug finite | YES |
| |δr| ≤ delta_r_max | YES |
| |δe| ≤ delta_e_max | YES |
| thrust in [min,max] | YES |
| rudder slew ≤ 40°/s·dt | YES (max step 0.0174532925199 vs lim 0.0174532925199) |
| elevator slew ≤ 40°/s·dt | YES (max step 0.0174532925199 vs lim 0.0174532925199) |

---

## 4. Source hashes

| File | Bytes | SHA-256 | Role |
|---|---:|---|---|
| `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` | production UNTOUCHED |
| `controller_codegen_init.m` | 1885 | `85eeb0e182683933241558a7df5e80e61b4b27a1bcc28fd88be2f0f52576c153` | prototype |
| `controller_codegen_reset.m` | 583 | `8fb42aaf935d1a607d298cc4071b4de6de471a7e078d87412241ad09f24c4a01` | prototype |
| `controller_codegen_step.m` | 7479 | `3cca4dc9c94bc3a9a5ec7c6524231b3716571e3156792a96828e88c02aef82f8` | prototype |

---

## 5. Remaining TEMPORARY_BLOCKER items

| ID | Item | Status |
|---|---|---|
| TB-WRAP | `wrapToPi` in step (yaw error) | TEMPORARY_BLOCKER — kept for bit parity; own local wrap later |
| TB-INTERP | `interp1(...,'linear','extrap')` fixed trim tables | TEMPORARY_BLOCKER — kept for bit parity; endpoint-clamp lerp later |
| TB-STRING | interp1 method char args | carried with TB-INTERP |
| TB-EPS | host `eps` in g_ac schedule | carried (TARGET_DEPENDENT) |
| TB-PROD | production still uses globals/persistent | NOT_IN_PRODUCTION prototype only |

---

## 6. Integrity / isolation

| Item | Value |
|---|---|
| Isolated on FAIL | NO |
| Golden corpus | `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat` |
| Harness | `run_cg2a_controller_explicit_state_prototype.m` |
| Params source | golden `params_snapshot` only |
| State reset | deterministic zeros |

Rejected methods remain closed. Hardware **NOT_CERTIFIED**. C++ parity **NOT CLAIMED**.

*End of CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE. Verdict: **PASS**. Next: `CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001`.*
