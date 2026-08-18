# DEPTH_OUTER_BASELINE_001 — Nonlinear 6DOF depth/guidance baseline @ U=1.50

**Overall verdict (audit completeness): PASS**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\continuous_path_tracking.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\controller_law.m`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m`
- Driver: `run_depth_outer_baseline.m` (one invocation; no production edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.png`
- Seed: 0 | Kp_roll frozen=0.605072 | Kp_x=25 | thrust_trim=13.4 N
- Certified speed envelope (prior): common X/XZ/R10 = [1.50, 2.00] m/s
- Production: theta/q cascade + climb FF frozen; K_gamma=0, K_zdot=0
- CODEX_VERTICAL_PLAN.md: untouched

## Frames / units / provenance

| Item | Definition |
|------|------------|
| Inertial | NED (North-East-Down): x North, y East, z Down |
| Body | BODY: x forward, y starboard, z down; rates p,q,r about BODY; Euler ZYX (psi,theta,phi) with ang_dot = JJ*[p;q;r] |
| z / depth positive down? | **YES** — depth ≡ z_NED [m] |
| State | `g = [x y z phi theta psi u v w p q r]` |
| State provenance | plant underwater777_vehicle_dynamics; integrated by ode45 in continuous_path_tracking every dt_controller |
| Inputs | `controls.delta_r, controls.delta_e, controls.thrust` |
| Input provenance | controller_law(yaw_ref,pitch_ref,u_ref,...) → rudder/elevator/thrust; guidance_law ZOH every dt_guidance |
| R | pos_dot = R(phi,theta,psi)*[u;v;w]; R row3=[-sin(theta), cos(theta)sin(phi), cos(theta)cos(phi)] (Fossen NED) |
| U_h, zdot | U_h=hypot(x_dot,y_dot); zdot=pos_dot(3)  [continuous_path_tracking] |
| theta_phys | theta_phys = -theta  [rad]; dive-positive matches atan2(dz,dx) with z down |
| Timing | dt_controller=0.0250s dt_guidance=0.0750s lookahead=1.25m |
| Actuator limits | |dr|<=25.0deg |de|<=15.0deg rate<=40deg/s; thrust in [-100,300] N |
| Pitch ref limits | |pitch_ref|<=26.0deg; |dpitch_ref/dt|<=6.0deg/s |

## Exact path-error / pitch / gamma equations (production guidance)

```
cte = p_veh - p_path(s)
z_e_f = 0.93*z_e_f + 0.07*cte(3)     % cte(3)=z_veh-z_path
z_e_i += z_e_f*dt_g;  |z_e_i|<=25
zd_e_f = 0.85*zd_e_f + 0.15*(zdot - zdot_path)
pitch_corr = -0.050*z_e_f - 0.006*z_e_i - K_zdot*zd_e_f   % |corr|<=9deg; K_zdot=0
pitch_geom = 0.65*atan2(t_look_z,||t_h||) + 0.35*atan2(t_now_z,||t_h||)
gamma_actual = atan2(zdot, max(U_h,0.05))
gamma_path   = atan2(zdot_path, U_path_h)
e_gamma = wrapToPi(gamma_path - gamma_actual); eg_f = 0.85*eg_f+0.15*e
pitch_raw = pitch_geom + K_gamma*eg_f + pitch_corr   % K_gamma=0, alpha_hat OFF
pitch_ref = rate_limit(filter(pitch_raw), ±pitch_ref_max, pitch_ref_rate_max)
e_theta = pitch_ref - theta_phys;  theta_phys=-theta
de = de_trim + de_uw_ff + de_climb_ff + de_fb
de_climb_ff = sat(0.1320695001*pitch_ref, ±2.8793deg)
thrust = thrust_trim + Kp_x*(u_ref - u)
```

## Level trim @ U=1.50 (physically consistent)

| Trim | pass | ||ν̇||_scaled | T* [N] | δe* [deg] | θ* [deg] | w* [m/s] |
|------|:----:|-------------:|-------:|----------:|---------:|---------:|
| level | YES | 2.73e-13 | 3.8117 | -6.665 | -1.9102 | -0.05003 |
| climb(0.4) | YES | 2.26e-13 | 5.7377 | -1.206 | -24.7426 | -0.07707 |

- HOLD/STEP IC: level trim (θ,v,w,q) + u=Uref + path start pose.
- XZ_RAMP IC: path-tangent θ + climb-trim (v,w) + u=Uref.
- Step smoothing: raised-cosine over L=15.0 m; max|dz/dx|=π·2/(2L)=0.209 → γ_max≈11.8° < pitch_ref_max.

## Fixed windows

- `settle_t0=5.0s`, `end_frac=0.88`, depth band=±0.25 m
- HOLD: acq until persistent |e_z|≤band (fallback t≥settle_t0); steady to end_frac
- STEP: acq until x≥x_trans1 + 3.0s; persistent settle on |e_z|≤band; steady thereafter
- XZ_RAMP: persistent |e_z|≤band (else settle_t0 floor); pitch windows via `compute_pitch_window_metrics`
- z0=10.0 m (NED down); +2m = dive; −2m = ascend

## Conservative gates (from X/XZ route tolerances; SPEED_ENVELOPE absolutes)

```
HOLD: |e_z| MAE<=0.30 p95<=0.50 |bias|<=0.25 maxdev<=0.60 | θ MAE<=0.10 p95<=0.50 | γ MAE<=0.50 p95<=1.00
STEP: |e_z| MAE<=0.45 p95<=0.80 |bias|<=0.35 OS<=0.60 settle<=18s | θ/γ as XZ-class
RAMP: |e_z| MAE<=0.55 p95<=0.80 |bias|<=0.45 | θ MAE<=0.30 p95<=0.50 | γ MAE<=1.00 p95<=1.50 | CTE<=0.60
ACT: elev/rud/thr sat<=1% | rate util<=1 | chatter<=0.20 deg/s | states bounded
```

## Results

| Scenario | Gate | First fail | zMAE | zp95 | zbias | zOS/max | settle | thMAE | gMAE | uMAE | yaw | CTE | deSat% | chat | bound |
|----------|:----:|------------|-----:|-----:|------:|--------:|-------:|------:|-----:|-----:|----:|----:|-------:|-----:|:-----:|
| HOLD | NO | depth_bias(0.2788>0.2500) | 0.2739 | 0.3213 | -0.2788 | 0.0000/0.3215 | 5.00 | 0.2185 | 0.5906 | 0.3185 | 0.0000 | 0.274 | 0.00 | 0.2022 | YES |
| STEP_P2 | YES | none | 0.0441 | 0.1004 | 0.0167 | 0.0100/0.6894 | 13.78 | 0.1022 | 0.5210 | 0.3157 | 0.0000 | 0.044 | 0.00 | 0.1066 | YES |
| STEP_M2 | NO | settle(NaN>18.00 or NaN) | 0.4477 | 0.5471 | -0.3051 | 0.5486/0.5487 | NaN | 0.1172 | 1.0042 | 0.3147 | 0.0000 | 0.448 | 0.00 | 0.2585 | YES |
| XZ_RAMP | NO | settle(NaN>18.00 or NaN) | 0.3730 | 0.4263 | -0.3214 | 0.0000/0.4267 | NaN | 0.0831 | 0.6343 | 0.2555 | 0.0000 | 0.422 | 0.00 | 0.2302 | YES |

### Actuator magnitude / rate (steady)

| Scenario | de_mag | dr_mag | thr_mag | de_rate | dr_rate | thr_rate | rudSat% | thrSat% |
|----------|-------:|-------:|--------:|--------:|--------:|---------:|--------:|--------:|
| HOLD | 0.324 | 0.000 | 0.018 | 0.007 | 0.000 | 0.000 | 0.00 | 0.00 |
| STEP_P2 | 0.306 | 0.000 | 0.018 | 0.005 | 0.000 | 0.000 | 0.00 | 0.00 |
| STEP_M2 | 0.316 | 0.000 | 0.018 | 0.009 | 0.000 | 0.000 | 0.00 | 0.00 |
| XZ_RAMP | 0.088 | 0.000 | 0.023 | 0.007 | 0.000 | 0.000 | 0.00 | 0.00 |

## Determinism

- rng(0,'twister'); second_run=NO
- Plant/controller deterministic (ode45 + fixed IC); rng unused by dynamics. PITCH_YAW_FINAL_CLOSURE_001 already established bit-identical two-repeat identity after clear persistent on X/XZ/R10 — cited without re-run.
- Prior: `suite_results/PITCH_YAW_CLOSURE.md (X/XZ/H deterministic identity)`

## Decision

- Audit completeness: **PASS**
- All scenario gates: **NO**
- Next bounded decision: **`derive_model_based_depth_to_gamma_outer`**
- Detail: ≥1 scenario FAIL vs conservative gates; next bounded step = one model-based depth→gamma outer candidate with anti-windup + reference shaping (production cascade frozen; do not invent gains in this audit).
- Production: untouched

## Feedback

- PASS/FAIL (audit): **PASS**
- Scenarios: HOLD=NO | STEP_P2=YES | STEP_M2=NO | XZ_RAMP=NO
- Next: `derive_model_based_depth_to_gamma_outer`
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_OUTER_BASELINE.png`
