# STATE_SPACE_MODEL_AUDIT

Living audit of plant equations, trim operating points, and linearization provenance.
Controller/guidance/plant production stack frozen unless a later task explicitly changes them.


---

## TRIM_OPERATING_POINTS_001 — 2026-08-05 21:01:00

### Provenance

- Closure evidence: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\pitch_yaw_closure.mat` (PITCH_YAW_CLOSURE PASS)
- Exact plant RHS: `underwater777_vehicle_dynamics.m`
- Actuator law (read-only): `controller_law.m` (no edits)
- Driver: `run_trim_operating_points.m`
- Artifacts: `suite_results/TRIM_OPERATING_POINTS.{md,mat,png}`

### Plant equations (exact RHS structure)

```
State g = [η; ν] = [x y z φ θ ψ u v w p q r]^T
  η in NED [m], Euler ZYX [rad]; ν body [m/s], body rates [rad/s]
Inputs: delta_r, delta_e [rad], thrust=Xprop [N]
Kinematics:
  ṙ_pos = R(φ,θ,ψ) * [u;v;w]
  [φ̇;θ̇;ψ̇] = J(φ,θ) * [p;q;r]
Dynamics:
  A(ν) * ν̇ = τ(η,ν,u_act)     τ = [X;Y;Z;K;M;N] hydro + restoring + control (Yuudr u² δr, Zuuds/Muuds u² δe, Xprop)
Sign convention: theta_phys = -theta (path/controller pitch)
```

### Assumptions for trim classes

1. **Level U=1.5:** steady translating trim — seek ν̇≈0 with φ̇=θ̇≈0; ẋ allowed; ż≈0.
2. **XZ z=0.4x:** steady translating trim along slope — ν̇≈0; ż≈0.4 ẋ.
3. **R10 helix:** relative equilibrium in rotating frame (rate Ω≈ψ̇) — ν̇≈0 and (φ̇,θ̇,ψ̇−Ω)≈0.
   If residual or body-state variance fails → classify periodic/quasi-steady; **exclude from ordinary inertial LTI**.
4. Pass gate: max_i |ν̇_i|/scale_i ≤ 1% (helix: rotating-frame residual).

### Operating-point results

| Point | PASS | class | norm_dyn | LTI eligible |
|-------|:----:|-------|---------:|:------------:|
| Level | PASS | steady_translating_trim (level U=1.5) | 3.357e-16 | PASS |
| Climb | PASS | steady_translating_trim (climb z=0.4x) | 5.102e-16 | PASS |
| Helix | FAIL | periodic_or_quasi_steady (NOT ordinary LTI trim) | 0.01128 | FAIL |

### x*, u* (canonical)

```
LEVEL x*=[0 0 0 0 -0.0227668 0 1.81718 0 -0.0413785 0 -3.3105e-29 0 ]
LEVEL u*=[0 -0.0824284 5.46329 ]
CLIMB x*=[0 0 0 0 -0.418597 0 1.75462 0 -0.066866 0 -1.12262e-27 0 ]
CLIMB u*=[0 -0.0211301 7.01987 ]
HELIX x*=[10 0 0 0.0251806 -0.0687065 0 1.55647 -0.0449073 -0.0497616 0.00987982 0.00301344 0.158073 ]
HELIX u*=[0.0772008 -0.0977033 4.66791 ]
```

### Scaling used

```
x_scale=[10 10 10 1 1 1 1.5 0.3 0.3 0.2 0.2 0.2 ]
u_scale=[0.436 0.262 50 ]
nu_dot_scale=[1 0.3 0.3 0.2 0.2 0.2 ]
```

### Next audit step

Numerical linearization (`numerical_linearize_auv`) only at LTI-eligible points; for helix use rotating-frame coordinates if relative-eq PASS, else skip ordinary A,B about inertial mean.


---

## LOCAL_SS_LEVEL_001 — 2026-08-05 21:11:12

### Provenance

- Plant RHS: `underwater777_vehicle_dynamics.m` (exact; no controller/guidance edits)
- Trim source: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_OPERATING_POINTS.mat` (OP.level)
- Driver: `run_local_ss_level.m`
- Method: scale-aware central FD, eps_rel=0.0001 and half-step; report half-step A,B
- Full matrix paths:
  - `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.md`
  - `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.mat`
  - `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.png`

### Gate

- dA_rel=3.19138e-05 (0.003%), dB_rel=1.47636e-13 (0.000%), eig_structure_stable=YES
- **Jacobian verdict: PASS**

### x*, u*

```
x*=[0              0              0              0   -0.022766828              0      1.8171783              0   -0.041378536              0 -3.3105035e-29              0]
u*=[0 -0.082428446    5.4632865]
```

### Frame / signs

- NED inertial η + BODY ν; Euler ZYX; inputs delta_r,delta_e,thrust=Xprop
- delta_r>0 → +Y/+N via Yuudr/Nuudr*u^2; delta_e>0 → +Z/+M via Zuuds/Muuds*u^2; thrust=+Xprop
- Ideal C=I12, D=0

### Coupling (omitted in reduced models)

- ||A_vl||_F=0 (rel 0), ||A_lv||_F=0 (rel 0)
- Decoupled vertical [z,theta,u,w,q] w/ [de,thrust] and lateral [y,phi,psi,v,p,r] w/ [dr]; omitted: x-channel + cross V↔L blocks

### Zero modes

Translating-trim kinematic integrators: plant forces/moments depend on attitude+body rates/speeds, not on inertial x,y,z (no current/density gradient). Columns of A for x,y,z are ~0 (pure kinematic integrators → near-zero eigenvalues). Yaw psi enters only through NED kinematics R(phi,theta,psi); at level trim with v=w≈0 rates≈0, psi is a free heading integrator (zero mode). Column Frobenius norms A(:,x,y,z,psi)=[0.000e+00 0.000e+00 0.000e+00 1.818e+00].

### Eigenvalues (Re↓)

```
 1: +1.242290e+00 +0.000000e+00i
 2: +7.350478e-01 +0.000000e+00i
 3: +2.410699e-01 +0.000000e+00i
 4: +0.000000e+00 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: -2.138805e-02 +4.993445e+00i
 9: -2.138805e-02 -4.993445e+00i
10: -1.258984e-01 +0.000000e+00i
11: -2.747879e+00 +0.000000e+00i
12: -2.758271e+00 +0.000000e+00i
```

### Next

- LOCAL_SS_CLIMB at XZ translating trim if needed; helix remains non-LTI inertial.


---

## LOCAL_SS_CLIMB_TURN_001 — 2026-08-05 21:20:52

### Provenance

- Plant RHS: `underwater777_vehicle_dynamics.m` (exact; no controller/guidance edits)
- Trim source: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_OPERATING_POINTS.mat` (OP.climb)
- Level compare: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.mat`
- Driver: `run_local_ss_climb.m`
- Method: scale-aware central FD, eps_rel=0.0001 and half-step; report half-step A,B
- Perturbation form: `delta_xdot = A*delta_x + B*delta_u about translating climb (x*,u*)`
- Helix: EXCLUDED (periodic/quasi-steady); no fabricated rotating-frame LTI
- Full matrix paths:
  - `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.md`
  - `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.mat`
  - `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.png`

### Assumptions

- XZ climb is LTI-eligible steady translating trim (ν̇≈0; ż≈0.4ẋ)
- Linearization is plant-only about (x*,u*); C=I, D=0
- Same FD scales/eps as LOCAL_SS_LEVEL_001
- Reduced vertical/lateral blocks omit V↔L cross-coupling and x-channel

### Gate

- dA_rel=3.46337e-05 (0.003%), dB_rel=1.56801e-15 (0.000%), eig_structure_stable=YES
- **Jacobian verdict: PASS**

### x*, u*

```
x*=[0            0            0            0   -0.4185965            0      1.75462            0 -0.066866031            0 -1.12262e-27            0]
u*=[0 -0.021130121    7.0198724]
```

### Frame / signs

- NED inertial η + BODY ν; Euler ZYX; inputs delta_r,delta_e,thrust=Xprop
- delta_r>0 → +Y/+N via Yuudr/Nuudr*u^2; delta_e>0 → +Z/+M via Zuuds/Muuds*u^2; thrust=+Xprop
- Ideal C=I12, D=0

### Coupling (omitted in reduced models)

- ||A_vl||_F=0 (rel 0), ||A_lv||_F=0 (rel 0)
- Decoupled vertical [z,theta,u,w,q] w/ [de,thrust] and lateral [y,phi,psi,v,p,r] w/ [dr]; omitted: x-channel + cross V↔L blocks

### Climb vs level

- Normalized ||ΔA||_F/||A_level||=0.08983, ||ΔB||_F/||B_level||=0.06766; vertical ||ΔAv||=0.08543, ||ΔBv||=0.06766. YES — gain/model scheduling recommended (climb≠level)
- Scheduling: YES — gain/model scheduling recommended (climb≠level)

### Zero modes

Translating-trim kinematic integrators: plant forces/moments depend on attitude+body rates/speeds, not on inertial x,y,z (no current/density gradient). Columns of A for x,y,z are ~0 (pure kinematic integrators → near-zero eigenvalues). Yaw psi enters only through NED kinematics R(phi,theta,psi); at climb trim with v≈0 rates≈0, psi is a free heading integrator (zero mode). Perturbation dynamics about translating nominal: δẋ = A δx + B δu (absolute ẋ* = f(x*,u*) ≠ 0 is kinematics of the steady climb; linear model is about δ). Column Frobenius norms A(:,x,y,z,psi)=[0.000e+00 0.000e+00 0.000e+00 1.630e+00].

### Helix

Helix (TRIM OP.helix): EXCLUDED from ordinary inertial LTI — classified periodic/quasi-steady (rel residual ~0.02 > 1%). No fabricated rotating-frame A,B matrix in this task. Carry-forward only.

### Eigenvalues (Re↓)

```
 1: +1.235072e+00 +0.000000e+00i
 2: +4.870644e-01 +2.493178e-01i
 3: +4.870644e-01 -2.493178e-01i
 4: +0.000000e+00 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: -1.891401e-02 +4.779879e+00i
 9: -1.891401e-02 -4.779879e+00i
10: -1.685441e-01 +0.000000e+00i
11: -2.702354e+00 +0.000000e+00i
12: -2.742820e+00 +0.000000e+00i
```

### Next

- Use climb A,B for vertical LTI about XZ trim; schedule vs level if indicated.
- Helix remains non-LTI inertial (excluded).


---

## SS_VALIDATION_001 — 2026-08-05 21:27:52

### Provenance

- Plant: `underwater777_vehicle_dynamics.m` (exact)
- Models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`
- Driver: `run_ss_validation.m` (production untouched)
- Compare: NL `δx=x_pert−x_nom` vs LTI `δẋ=Aδx+Bδu`
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SS_VALIDATION.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SS_VALIDATION.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SS_VALIDATION.png`

### Verdicts

| Trim | Model validity | Notes |
|------|:--------------:|-------|
| Level | **PASS** | all level channels |
| Climb | **PASS** | all climb channels |
| Helix | EXCLUDED | carry-forward |

### Per-channel

| Trim/Channel | PASS | nrmse_rel | corr | T_valid [s] |
|---|:---:|---:|---:|---:|
| level/elev_pulse | PASS | 0.011 | 1.000 | 0.600 |
| level/rudder_pulse | PASS | 0.003 | 1.000 | 0.600 |
| level/theta_ic | PASS | 0.002 | 1.000 | 0.600 |
| climb/elev_pulse | PASS | 0.009 | 1.000 | 0.600 |
| climb/theta_ic | PASS | 0.002 | 1.000 | 0.600 |

### Validity horizon / envelope

- Sim window T_end=0.600s (OL maxRe≈1.242).
- **Level LTI envelope:** t ∈ [0, 0.600s], |δu|,|δθ| ≤ 0.5°.
- **Climb LTI envelope:** t ∈ [0, 0.600s], |δu|,|δθ| ≤ 0.5°.
- Outside envelope / larger δ: restrict local LTI (unstable modes + nonlinear).
- Amplitude linearity: 0.25° check required per channel (see SS_VALIDATION.md).

### Next

- Controllability / LQR may proceed on validated level & climb models inside envelopes; schedule gains (ΔA≈9%, ΔB≈7%).
- Helix remains excluded from ordinary inertial LTI.


---

## CTRL_OBS_AUDIT_001 — 2026-08-05 21:53:25

### Provenance

- Models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat` (SS_VALIDATION PASS)
- Driver: `run_ctrl_obs_audit.m` (read-only; no production edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CTRL_OBS_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CTRL_OBS_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CTRL_OBS_AUDIT.png`

### Verdict

**PASS** — scaled SVD + PBH controllability/observability at level & climb.

### Key numbers

| Case | level rank | climb rank | level cond | climb cond |
|---|---:|---:|---:|---:|
| Ctrl full | 12/12 | 12/12 | 8.27e+09 | 6.69e+09 |
| Ctrl vertical | 5/5 | 5/5 | 443 | 390 |
| Ctrl lateral | 6/6 | 6/6 | 6.37e+05 | 6.35e+05 |
| Obs A (I12) | 12/12 | 12/12 | 1.2e+09 | 7.06e+08 |
| Obs B (no xy) | 10/12 | 10/12 | Inf | Inf |
| Obs C (+INS xy) | 12/12 | 12/12 | 1.2e+09 | 7.06e+08 |

### Design implications

- Full ctrl rank level=12/12 climb=12/12 (tol-aware); cond(Qc_s) level=8.27e+09 climb=6.69e+09
- Vertical reduced rank level=5/5 climb=5/5; lateral level=6/6 climb=6/6
- level weakest dynamic ctrl PBH sigma_min=8.776e-02 at lam=-1.258984e-01 (x(0.54)+z(0.36)+u(0.07))
- climb weakest dynamic ctrl PBH sigma_min=8.865e-02 at lam=-1.891401e-02+4.779879e+00i (p(0.80)+phi(0.17)+v(0.01))
- Obs B (no x,y): SVD rank 10/12 = unobs dim 2 (absolute x,y only); z/psi/dynamics observable; PBH@λ=0 is per-eigenvalue
- Climb vs level: schedule LQR/LQI (ΔA~9%, ΔB~7%); full Qc_s cond~1e9 → prefer reduced V/L or careful weights
- Helix excluded. Next: scheduled LQR/LQI; INS/path-rel for absolute xy

### Next

- Scheduled LQR/LQI on level & climb; INS or path-relative for absolute xy; helix excluded.


---

## LQR_LQI_PITCH_BENCHMARK_001 — 2026-08-05 22:03:42

### Provenance

- Models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat` (SS_VALIDATION PASS; CTRL_OBS PASS)
- Actuator limits read from `controller_law.m` (no edit): |de|<=15deg, rate 40deg/s
- Driver: `run_lqr_lqi_pitch_benchmark.m` (read-only; no production edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LQR_LQI_PITCH_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LQR_LQI_PITCH_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LQR_LQI_PITCH_BENCHMARK.png`

### Verdict

**PASS** — isolated elevator-only LQR vs LQI pitch benchmark (level & climb).

### Subsystem

- Level: [theta_phys,w,q], PBH stab=YES, u omitted: PBH stabilizable elevator-only on [theta_phys,w,q]; surge held at trim (separate thrust). Coupling A(q,u)/A(w,u) frozen at delta_u=0.
- Climb: [theta_phys,w,q], PBH stab=YES, u omitted: PBH stabilizable elevator-only on [theta_phys,w,q]; surge held at trim (separate thrust). Coupling A(q,u)/A(w,u) frozen at delta_u=0.

### Selection

- Selected for optional NL test: `none`
- Reason: Both LQR and LQI pass all cases, but no clear single-architecture advantage for NL test.
- Rejected: No candidate selected (at most one, and only with clear reason). LQR ess_max=0.217 deg dist=0.040; LQI ess_max=0.383 dist=0.027.
- Production cascade unchanged (baseline X/XZ/helix metrics stand).

### Next

- No controller change. Optional NL smoke only if selected≠none; helix still excluded from LTI.


---

## ROLL_BASELINE_AUDIT_001 — 2026-08-05 22:14:28

### Provenance

- Closure: `suite_results/pitch_yaw_closure.mat` (PITCH_YAW PASS)
- Models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat` (lateral COP/dr validated)
- Driver: `run_roll_baseline_audit.m` (read-only; diagnostic resim=YES)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.png`

### Math / frame / units

```
State: η=[x y z φ θ ψ], ν=[u v w p q r]; inputs [δr δe Xprop]
Roll ref: φ_ref = 0; e_φ = 0 - φ; p body roll rate
Plant roll (level): λ = -2.138805e-02 ± j4.993445 → f=0.7947 Hz, ζ=0.00428
Plant roll (climb): λ = -1.891401e-02 ± j4.779879 → f=0.7607 Hz, ζ=0.00396
Lateral reduced: [y φ ψ v p r] w/ δr; cond(Qc_s)~6.4e5; controllable
Production rudder: δr = sat(Kp_ψ e_ψ - Kd_ψ e_r)  (no φ/p feedback)
Windows: X first_hold pitch; XZ/helix persistent pitch; φ metrics on same masks
```

### Roll baseline (steady φ)

| Route | MAE [°] | p95 [°] | max [°] | rud sat% | p peak f [Hz] | plant match |
|-------|--------:|--------:|--------:|---------:|--------------:|:-----------:|
| X | 0.0000 | 0.0000 | 0.0000 | 0.00 | 0.078 | 0 |
| XZ | 0.0000 | 0.0000 | 0.0000 | 0.00 | 0.078 | 0 |
| H | 1.4427 | 2.3038 | 3.2443 | 0.00 | 0.781 | 1 |

### Verdict / root / next

- Verdict: **FAIL**
- Root class: `yaw_command_induced_coupling`
- Next (not implemented): `scheduled_lateral_LQR_benchmark` — Helix-only FAIL: steady φ mean≈MAE=1.443° (≈HELIX trim bank φ*≈1.44°); AC rms≈0.553° at plant roll f=0.781 Hz (match=1, ζ_proxy=0.0071). X/XZ φ≡0 (no yaw). Root: yaw-command-induced coupling (quasi-steady bank + light plant-mode ripple). Cross-damping alone will not remove mean bank. Next: scheduled lateral LQR benchmark on [y φ ψ v p r] (not implement now).
- Preferred gates: FAIL | Hard gates: FAIL

### Next

- Do not implement now; queue single option `scheduled_lateral_LQR_benchmark`.


---

## ROLL_TRIM_RELATIVE_AUDIT_001 — 2026-08-05 22:29:36

### Provenance

- Read-only: `ROLL_BASELINE_AUDIT.mat`, `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`
- Driver: `run_roll_trim_relative_audit.m` (no re-sim; no controller edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.png`

### Math / frame / units

```
tilde_phi = phi - phi_eq
X/XZ: phi_eq = 0 (forced)
R10: phi_eq = IDENTIFIED robust median(per_turn_mean) = 0.025500 rad (1.4610 deg)
label: empirical_cycle_mean_not_equilibrium
Plant residual at mean (x*,u*): p_dot_norm=0.01128 norm_rel=0.019995 tol=0.01 → small=0
Plant roll level: f=0.7947 Hz ζ=0.00428
Gates hard: MAE≤0.75 p95≤1.5 max≤2 p_RMS≤3; pref: MAE≤0.25 p95≤0.5 p_RMS≤1
Absolute safety: max|phi|≤5 deg (separate)
```

### Trim-relative ripple (steady)

| Route | phi_eq [°] | tilde MAE | p95 | max | p_RMS | pref | hard |
|-------|----------:|----------:|----:|----:|------:|:----:|:----:|
| X | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | YES | YES |
| XZ | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | YES | YES |
| H | 1.4610 | 0.4619 | 1.0388 | 1.7833 | 2.7611 | NO | YES |

### Verdict / class / next

- Verdict: **PASS**
- Class: `stable_but_lightly_damped`
- Next (not implemented): `coordinated_yaw_roll_benchmark_about_phi_eq` — Hard trim-relative PASS / preferred FAIL. Classify stable-but-lightly-damped roll ripple about phi_eq=1.461 deg (empirical_cycle_mean_not_equilibrium). Recommend ONE coordinated yaw-roll benchmark about phi_eq (not zero). Plant f=0.795 Hz, zeta_proxy=0.0070, amp@plant=0.724 deg.
- Absolute max gate: YES | Hard: YES | Preferred: NO

### Next

- Do not implement now; queue single option `coordinated_yaw_roll_benchmark_about_phi_eq`.


---

## YAW_ROLL_DAMPING_BENCHMARK_001 — 2026-08-05 22:44:53

### Provenance

- Read-only: `ROLL_TRIM_RELATIVE_AUDIT.mat`, `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`
- Driver: `run_yaw_roll_damping_benchmark.m` (isolated; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BENCHMARK.png`

### Law / poles

```
dr_cmd = sat_mag_rate( dr_yaw + g_ac*(-Kp*p) ); Kphi=0
Kp=1.704286 s | zdes=0.12 | Bp_level=1.3922 Bp_climb=1.2980
Level: f 0.7947->0.9063 Hz, z 0.00428->0.23062
Climb: f 0.7607->0.8834 Hz, z 0.00396->0.12000
phi_eq: X=0 XZ=0 H=1.4610 deg (empirical; not forced to 0)
```

### R10 before/after

| metric | base | cand | d% |
|--------|-----:|-----:|---:|
| tildeRMS [deg] | 0.5538 | 0.3189 | -42.41 |
| pRMS [deg/s] | 2.7611 | 1.5857 | -42.57 |
| yawMAE [deg] | 0.1748 | 0.1752 | +0.26 |

### Verdict / next

- Verdict: **FAIL**
- Next: `reject_revert_diagnostic` — REJECT diagnostic candidate; production untouched. Reasons: yaw regress>2%.
- Production: untouched

### Next

- reject_revert_diagnostic


---

## YAW_ROLL_DAMPING_BACKOFF_002 — 2026-08-05 22:55:08

### Provenance

- Read-only: `YAW_ROLL_DAMPING_BENCHMARK.mat`, `ROLL_TRIM_RELATIVE_AUDIT.mat`, `controller_law.m`
- Driver: `run_yaw_roll_damping_backoff.m` (isolated; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_ROLL_DAMPING_BACKOFF.png`

### Law / poles

```
dr_cmd = sat_mag_rate( dr_yaw + g_ac*(-Kp*p) ); Kphi=0
Provenance: TUNED | Kp2=0.605072 = 1.704286*(1.80/5.07)
Level: f 0.7947->0.8343 Hz, z 0.00428->0.09362
Climb: f 0.7607->0.8043 Hz, z 0.00396->0.04949
phi_eq: X=0 XZ=0 H=1.4610 deg (empirical; not forced to 0)
```

### R10 before/after

| metric | base | cand | d% |
|--------|-----:|-----:|---:|
| tildeRMS [deg] | 0.5538 | 0.4376 | -20.99 |
| pRMS [deg/s] | 2.7611 | 2.1700 | -21.41 |
| yawMAE [deg] | 0.1748 | 0.1747 | -0.06 |
| yawRMS [deg] | 0.2041 | 0.2043 | +0.07 |
| yawP95 [deg] | 0.3493 | 0.3507 | +0.40 |

### Verdict / next

- Verdict: **PASS**
- Next: `two_repeat_production_integration_regression` — BACKOFF PASS at Kp2=0.605072 s: R10 roll improved (d_tildeRMS=-20.99%, d_pRMS=-21.41%); yaw/pitch/actuator/osc gates held; X/XZ clean. Recommend SEPARATE two-repeat production-integration regression; do NOT edit production in this task.
- Production: untouched

### Next

- two_repeat_production_integration_regression


---

## ROLL_PRODUCTION_CLOSURE_001 — 2026-08-05 23:06:28

### Provenance

- Sources: `controller_law.m`, `continuous_path_tracking.m`, `YAW_ROLL_DAMPING_BACKOFF.mat`
- Driver: `run_roll_production_closure.m` (one invocation; actual production law)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.png`

### Old -> new

```
OLD: dr_cmd = sat_mag_rate( Kp_psi*e_psi - Kd_psi*e_r )  [no roll damp]
NEW: dr_cmd = sat_mag_rate( dr_yaw + g_ac*(-0.605072*p) )
EQ:  dr_cmd = sat_mag_rate( dr_yaw + g_ac*(-Kp_roll*p) ); g_ac=1/(1+(|e_psi|/3deg)^2+(|e_r|/8dps)^2); Kphi=0
Kp_roll=0.605072 s | Kphi=0 | YAW_ROLL_DAMPING_BACKOFF PASS (TUNED Kp2)
phi_eq: X=0 XZ=0 H=1.4610 deg
```

### Repeat / R10

- Determinism: base=YES cand=YES (seed=0, 2-rep)
| metric | base | prod | d% |
|--------|-----:|-----:|---:|
| tildeRMS [deg] | 0.5538 | 0.4376 | -20.99 |
| pRMS [deg/s] | 2.7611 | 2.1700 | -21.41 |
| yawMAE [deg] | 0.1748 | 0.1747 | -0.06 |
| yawRMS [deg] | 0.2041 | 0.2043 | +0.07 |
| yawP95 [deg] | 0.3493 | 0.3507 | +0.40 |

### Verdict / next

- Verdict: **PASS**
- Next: `freeze_roll_production` — PRODUCTION CLOSURE PASS at Kp_roll=0.605072 s: R10 roll improved (d_tildeRMS=-20.99%, d_pRMS=-21.41%); yaw/pitch/path/actuator gates held; X/XZ clean; deterministic. Promote and FREEZE roll damping in production.
- Production: roll damp PROMOTION FROZEN

### Next

- freeze_roll_production


---

## SPEED_BASELINE_AUDIT_001 — 2026-08-05 23:20:05

### Provenance

- Read-only: `ROLL_PRODUCTION_CLOSURE.mat`, `controller_law.m`, `init_parameters.m`
- Driver: `run_speed_baseline_audit.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_BASELINE_AUDIT.png`

### Equations / units / frame

```
Thrust law: thrust = sat(thrust_trim + Kp_x*(u_ref - u); [thrust_min,thrust_max])
Controller variable: BODY u [m/s]; e_u = u_ref - u
Reported separately: Uh = hypot(xdot,ydot) [m/s]; |V| = ||[u v w]|| [m/s]
Kp_x = 25 N/(m/s); thrust_trim = 13.4 N; limits [-100, 300] N
u_trim / desired_speed = 1.5 / 1.5 m/s
Guidance may schedule u_ref <= desired_speed (curvature / near_end)
```

### Steady hold (BODY u)

| Route | signed e_u | MAE | p95 | thr_mean | sat% |
|-------|----------:|----:|----:|---------:|-----:|
| X | -0.3176 | 0.3176 | 0.3188 | 5.461 | 0.00 |
| XZ | -0.2550 | 0.2550 | 0.2567 | 7.025 | 0.00 |
| R10 | -0.3494 | 0.3494 | 0.3720 | 4.666 | 0.00 |

### Verdict / next

- Verdict: **FAIL**
- Root class: **TRIM_TABLE_BIAS**
- Pref/Hard/Step/Freeze: NO/NO/NO/YES
- Next: `audit_thrust_trim_at_Uref` — Steady e_u≈(T-Ttrim)/Kp_x with |e| large and T≠Ttrim=13.40 N; single thrust_trim@Uref audit (no gain) before envelope.
- Production: untouched

### Next

- audit_thrust_trim_at_Uref

---

## THRUST_TRIM_U15_AUDIT_001 — 2026-08-05 23:38:21

### Provenance

- Read-only: `SPEED_BASELINE_AUDIT.mat`, `TRIM_OPERATING_POINTS.mat`, `underwater777_vehicle_dynamics.m`
- Driver: `run_thrust_trim_u15_audit.m` (one invocation; production untouched)
- Artifacts: `suite_results/THRUST_TRIM_U15_AUDIT.{md,mat,png}`

### Prior label flag (not overwritten)

TRIM_OPERATING_POINTS / LOCAL_SS "U=1.5" / "level_U15" / "climb" points have BODY u*=1.81718 / 1.75462 (not exact 1.5). Do not relabel those artifacts; this audit introduces separate exact-u=1.5 plant trims.

### Exact BODY u=1.5 plant trims

| Point | PASS | u* | Treq [N] | de [deg] | θ [deg] | w | norm_dyn |
|-------|:----:|---:|---------:|---------:|--------:|--:|---------:|
| Level | PASS | 1.5 | 3.81167 | -6.6651 | -1.9102 | -0.050028 | 8.51e-14 |
| XZ γ=atan(0.4) | PASS | 1.5 | 5.73772 | -1.2062 | -24.7426 | -0.077069 | 1.35e-13 |
| R10 | EMPIRICAL | u_mean=1.5565 | T_cycle=4.6657 (exact-u **UNKNOWN**) | — | — | — | n/a |

### Common Ttrim / decision

```
e_ss=(Treq-Ttrim)/Kp_x; Kp_x=25; e_tol=±0.030; dT_tol=0.7500 N
Current Ttrim=13.40 N → e_ss level/XZ = -0.3835 / -0.3065 m/s
Treq span level/XZ=1.9260 N; common_feasible=NO
Architecture/range: speed-reference drag feedforward + anti-windup PI
```

Level/XZ Treq span=1.9260 N exceeds 2*dT_tol=1.5000 N (dT_tol=e_tol*Kpx=0.7500). No constant Ttrim meets |e_ss|<=0.030 on both known routes; R10 exact-u also UNKNOWN.

### Verdict / next

- Audit verdict: **PASS**
- Next: `implement_speed_drag_ff_plus_aw_PI`
- Production: untouched (no Kp / no law edit)


---

## SPEED_PI_FF_BENCHMARK_001 — 2026-08-05 23:51:34

### Provenance

- Read-only: `THRUST_TRIM_U15_AUDIT.mat`, `SPEED_BASELINE_AUDIT.mat`, `controller_law.m`
- Driver: `run_speed_pi_ff_benchmark.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.png`

### Equations / kD / Ki / poles

```
Tff = kD * u_ref_eff * |u_ref_eff|
kD = Treq_level/Ufix^2 = 1.6940741214
Tunsat = Tff + Kp*e + I; T = sat(Tunsat); I(0)=0
I += Ki*e*dt + Kaw*(T-Tunsat)*dt  (freeze e-int if sat against e)
Kp=25 Ki=13.83617834 Kaw=0.55344713  zeta=1/sqrt(2)  Ki=min(Ki_L,Ki_XZ)
Level a,b,wn,Ki = -0.153848, 0.0312736, 0.66163, 13.998
XZ    a,b,wn,Ki = -0.148436, 0.0312736, 0.6578, 13.836
CL poles level @Ki: [-0.4678+0.4624i -0.4678-0.4624i]
CL poles XZ @Ki:    [-0.4651+0.4651i -0.4651-0.4651i]
```

### Before / after hold (BODY u)

| Route | Base MAE/p95 | Cand MAE/p95 | Cand thr/I |
|-------|-------------:|-------------:|-----------:|
| X | 0.3176/0.3188 | 0.0008/0.0017 | 3.786/-0.043 |
| XZ | 0.2550/0.2567 | 0.0010/0.0020 | 5.750/1.923 |
| R10 | 0.3494/0.3720 | 0.0012/0.0059 | 3.154/0.686 |

### Verdict / next

- Verdict: **FAIL**
- Pref/Hard/Step/Reg/I: NO/NO/NO/NO/YES
- Next: `reject_candidate_no_ki_sweep` — REJECT single FF+AW-PI candidate (no second Ki sweep). Fail: step settle/OS, attitude/path regression. Ki was 13.8362 from pole target.
- Production: untouched


---

## PITCH_FLIGHTPATH_SEMANTICS_AUDIT_001 — 2026-08-06 00:05:21

### Provenance

- Read-only: `SPEED_PI_FF_BENCHMARK.mat`, `THRUST_TRIM_U15_AUDIT.mat`, `controller_law.m`
- Driver: `run_pitch_flightpath_semantics_audit.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.png`
- History: prior pitch MAE not overwritten; additive γ / θ_cmd metrics

### Identity

```
e_theta = pitch_ref - theta_phys  (attitude tracker)
gamma_ref = pitch_ref             (climb FF alias)
guidance pitch_geom ≈ gamma_path  (K_gamma=0, alpha_hat OFF)
gamma = theta_phys + atan2(w,u)   (phi=0,v=0 exact)
semantic_mismatch = 1
```

### Trim check

```
level: θ_phys=+1.9102 deg α=-1.9102 deg γ_kin=+0.0000 deg
XZ:    θ_phys=+24.7426 deg α=-2.9412 deg γ_kin=+21.8014 deg (path 21.8014)
```

### Steady baseline→candidate (legacy|θ| / γ MAE deg, CTE m)

| Route | legacy B→C | γ B→C | CTE B→C |
|-------|-----------:|------:|--------:|
| X | 0.011→0.191 | 0.331→0.394 | 0.247→0.290 |
| XZ | 0.121→0.141 | 0.418→0.669 | 0.400→0.558 |
| R10 | 0.041→0.138 | 0.657→1.028 | 0.269→0.401 |

### Root / next

- Verdict: **PASS**
- Root: Guidance builds pitch_ref = gamma_path + depth_corr (K_gamma=0, alpha_hat OFF); controller_law tracks pitch_ref as theta_phys (e_theta=pitch_ref-theta_phys); climb FF aliases gamma_ref:=pitch_ref. Exact-u trim needs theta_phys=gamma-alpha (level alpha=-1.910 deg, XZ alpha=-2.941 deg). Depth-I partially mimics alpha (closed-loop ref often nearer theta_cmd than raw gamma) but is not explicit AoA compensation — speed-dependent. Prior pitch MAE rewarded |pitch_ref-theta_phys| and understates true e_gamma. When SPEED candidate forces BODY u→1.5, alpha→trim and required attitude shifts; legacy pitch + CTE regress.
- Next: `measured_trim_alpha_compensation` — BOUNDED NEXT (do not implement here): keep attitude cascade; set theta_ref_cmd = gamma_ref_path - alpha_hat before controller. alpha_hat from (1) trim schedule on (u_ref, gamma_ref) using THRUST exact-u level/XZ alphas, and/or (2) measured BODY alpha=atan2(w,u) LPF. Sensors/frames: BODY u,w already in controller_law (12th arg); filter tau~0.3-1s; clamp |alpha_hat| (e.g. 8 deg, existing enable_alpha_hat scaffold). Helix: treat atan2(w,u) as APPROX — monitor resid=gamma_act-(theta_phys+alpha); if |phi| or |v| large, add roll/v correction or fall back to outer gamma later. Reject outer flight-path loop for this step (Tur5B K_gamma already tried; larger sensor/filter surface: needs reliable NED V or reconstructed gamma_act). Correct new metrics: report e_gamma and e_theta_req separately; do not overwrite historical pitch MAE definitions.
- Production: untouched


---

## ALPHA_COMP_SPEED_HOLD_001 — 2026-08-06 00:19:48

### Provenance

- Read-only: `SPEED_PI_FF_BENCHMARK.mat`, `PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat`, `guidance_law.m`
- Driver: `run_alpha_comp_speed_hold_benchmark.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.png`

### Toggles / equations

```
K_gamma=0; enable_alpha_hat=true (scaffold unchanged)
alpha_eff=theta_phys-gamma_act; alpha_hat LPF .98/.02 clamp +/-8deg
pitch_raw=gamma_path+depth_corr+alpha_hat
Speed PI+FF: kD=1.6940741214 Kp=25 Ki=13.83617834 Kaw=0.55344713
X/XZ exact gamma=theta+atan2(w,u); R10 BODY-alpha APPROX
```

### Before/after (P / U / A)

| Route | uMAE | γMAE° | CTE | γΔ% | CTEΔ% |
|-------|-----:|------:|----:|----:|------:|
| X | 0.3176/0.0008/0.0009 | 0.331/0.394/0.609 | 0.2467/0.2903/0.0747 | -54.6 | +74.3 |
| XZ | 0.2550/0.0010/0.0031 | 0.418/0.669/1.011 | 0.4002/0.5582/0.1806 | -51.2 | +67.6 |
| R10 | 0.3494/0.0012/0.0043 | 0.657/1.028/0.653 | 0.2690/0.4012/0.2517 | +36.5 | +37.3 |

### Verdict / next

- Verdict: **FAIL**
- Gates u/γ/CTE/yaw-roll/act/sat: YES/NO/YES/NO/NO/YES
- Next: `reject_alpha_hat_or_retune_guidance_base` — FAIL leave production unchanged. Fail: gamma MAE <10% improve, yaw/roll >2% vs prod, actuator >2% vs prod. Scaffold alpha_hat ON with speed PI+FF did not clear gates; consider trim-scheduled alpha or helix roll/v correction next.
- Production: untouched


---

## ALPHA_DEPTH_I_ABLATION_001 — 2026-08-06 00:34:02

### Provenance

- Read-only: `ALPHA_COMP_SPEED_HOLD_BENCHMARK.mat`, `PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat`, `guidance_law.m`
- Isolated helper: `guidance_law_depth_i_ablation.m` (production untouched)
- Driver: `run_alpha_depth_i_ablation.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_I_ABLATION.png`

### Equation delta

```
OLD: pitch_corr = -0.050*z_e_f - 0.006*z_e_i - K_zdot*zd_e_f
NEW: pitch_corr = -0.050*z_e_f + 0*z_e_i     - K_zdot*zd_e_f
K_gamma=0; enable_alpha_hat=true; speed PI+FF kD=1.6940741214 Kp=25 Ki=13.83617834 Kaw=0.55344713
```

### Before/after (P / U / AI / A0)

| Route | uMAE | γMAE° | CTE | γΔ% U→A0 | CTEΔ% |
|-------|-----:|------:|----:|---------:|------:|
| X | 0.3176/0.0008/0.0009/0.0009 | 0.331/0.394/0.609/0.357 | 0.2467/0.2903/0.0747/0.1007 | +9.4 | +65.3 |
| XZ | 0.2550/0.0010/0.0031/0.0032 | 0.418/0.669/1.011/0.559 | 0.4002/0.5582/0.1806/0.2507 | +16.5 | +55.1 |
| R10 | 0.3494/0.0012/0.0043/0.0041 | 0.657/1.028/0.653/0.386 | 0.2690/0.4012/0.2517/0.2398 | +62.4 | +40.2 |

### Verdict / next

- Verdict: **FAIL**
- Gates u/γ/CTE/yaw-roll/act/sat: YES/NO/YES/NO/NO/YES
- Next: `reduce_depth_P_or_trim_schedule_alpha` — FAIL leave production unchanged. Fail: gamma MAE <10% improve, yaw/roll >2% vs prod, actuator >2% vs prod. Zeroing depth-I with alpha_hat ON did not clear all gates.
- Production: untouched


---

## ALPHA_DEPTH_P_BACKOFF_001 — 2026-08-06 00:53:15

### Provenance

- Read-only: `ALPHA_DEPTH_I_ABLATION.mat`, `ALPHA_COMP_SPEED_HOLD_BENCHMARK.mat`, `guidance_law_depth_i_ablation.m`
- Isolated helper: `guidance_law_depth_p_backoff.m` (production untouched)
- Driver: `run_alpha_depth_p_backoff.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.png`

### Equation delta

```
OLD: pitch_corr = -0.050*z_e_f + 0*z_e_i - K_zdot*zd_e_f
NEW: pitch_corr = -0.040*z_e_f + 0*z_e_i - K_zdot*zd_e_f
K_gamma=0; enable_alpha_hat=true; Ki_z=0; speed PI+FF kD=1.6940741214 Kp=25 Ki=13.83617834 Kaw=0.55344713
```

### Before/after (P / U / A05 / A04)

| Route | uMAE | γMAE° | CTE | γΔ% U→A04 | CTEΔ% |
|-------|-----:|------:|----:|----------:|------:|
| X | 0.3176/0.0008/0.0009/0.0008 | 0.331/0.394/0.357/0.313 | 0.2467/0.2903/0.1007/0.1131 | +20.5 | +61.0 |
| XZ | 0.2550/0.0010/0.0032/0.0032 | 0.418/0.669/0.559/0.497 | 0.4002/0.5582/0.2507/0.2754 | +25.8 | +50.7 |
| R10 | 0.3494/0.0012/0.0041/0.0041 | 0.657/1.028/0.386/0.378 | 0.2690/0.4012/0.2398/0.2490 | +63.2 | +37.9 |

### Verdict / next

- Verdict: **FAIL**
- Gates u/γ/CTE/yaw-roll/act/settle/sat: YES/YES/YES/NO/NO/NO/YES
- Next: `speed_aware_roll_coupling_audit` — FAIL leave production unchanged. Fail: yaw/roll >2% vs prod, actuator >2% vs prod, settling worse. Measured-alpha closed after 3 failures (COMP + DEPTH_I + DEPTH_P). Next method: speed_aware_roll_coupling_audit.
- Production: untouched

---

## SPEED_AWARE_ROLL_COUPLING_AUDIT_001 — 2026-08-06 01:09:36

### Provenance

- Read-only: `ALPHA_DEPTH_P_BACKOFF.mat`, `ROLL_PRODUCTION_CLOSURE.mat`, `underwater777_vehicle_dynamics.m`
- Driver: `run_speed_aware_roll_coupling_audit.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.png`

### Decomposition

```
frozen phi_eq=1.4610 deg | P bank mean=1.4420 | A04 bank mean=0.8600
u: 1.5565 -> 1.2023 | u^2 auth ratio=0.5967
frozen tildeRMS: 0.4376 -> 0.6642 (+51.79%)
own-eq tildeRMS: 0.4372 -> 0.2827 (-35.34%)
pRMS: 2.1700 -> 1.4980 (-30.97%)
NOT an LTI trim (helix empirical)
```

### Verdict / next

- Verdict: **PASS**
- Class: **METRIC_MISMATCH**
- Gates valid/decomp/own/p/rudder: YES/YES/YES/YES/YES
- Next: `speed_scheduled_phi_eq_or_roll_metric` — PASS METRIC_MISMATCH: frozen phi_eq=1.461 deg (prod-speed bank) makes A04 tildeRMS 0.438->0.664 look worse, but own-eq/detrend ripple 0.437->0.283 and pRMS 2.170->1.498 improve. Bank mean 1.442->0.860 deg tracks u 1.556->1.202 (u^2 auth ratio=0.597). Next: schedule phi_eq or report own-eq tilde; do not retune roll for false regression.
- Production: untouched

### Next

- speed_scheduled_phi_eq_or_roll_metric

---

## TRIM_ALPHA_SCHEDULE_ID_001 — 2026-08-06 01:23:12

### Provenance

- Read-only: `THRUST_TRIM_U15_AUDIT.mat`, `ALPHA_DEPTH_P_BACKOFF.mat`, `SPEED_AWARE_ROLL_COUPLING_AUDIT.mat`
- Driver: `run_trim_alpha_schedule_id.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.png`

### Equation / coefficients

```
alpha_ff=c0/max(u_ref,u_min)^2 + c_gamma*gamma_path  [rad], clamp +/-8deg
c0=+7.5013943801e-02 [rad*(m/s)^2] DERIVED level α_hat*·u*^2
c_gamma=+4.7291247774e-02 DERIVED (α_XZ*-α_L*)/γ_XZ
u_min=0.9 FIXED; R10 not in fit
```

### Validation (A04 steady)

| Series | signed° | MAE° | p95° | max° |
|--------|--------:|-----:|-----:|-----:|
| X | -0.0263 | 0.0263 | 0.0757 | 0.1005 |
| XZ | -0.0607 | 0.0607 | 0.3770 | 0.4975 |
| R10 (held-out) | -0.0892 | 0.0892 | 0.2663 | 0.2880 |

### Verdict / next

- Verdict: **PASS**
- Gates X/XZ/R10mae/R10p95/sign/bound/leak: YES/YES/YES/YES/YES/YES/YES
- Sens R10 ΔMAE@±0.1 m/s: +0.381 / +0.436 deg
- Next: `integrate_trim_alpha_ff_replace_measured_ahat` — PASS: X/XZ MAE=0.026/0.061<=0.20; R10 MAE=0.089<=0.35 p95=0.266<=0.50; sign OK; continuous/bounded; no R10 leakage. Next: replace measured alpha_hat with this alpha_ff schedule (no LPF); watch elevator-rate on acquisition.
- Production: untouched

### Next

- integrate_trim_alpha_ff_replace_measured_ahat


---

## TRIM_ALPHA_FF_BENCHMARK_001 — 2026-08-06 01:42:35

### Provenance

- Read-only: `TRIM_ALPHA_SCHEDULE_ID.mat`, `ALPHA_DEPTH_P_BACKOFF.mat`, `guidance_law.m`
- Isolated helper: `guidance_law_trim_alpha_ff.m` (production untouched)
- Driver: `run_trim_alpha_ff_benchmark.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_BENCHMARK.png`

### Equation delta

```
OLD: alpha_hat=LPF(.98/.02,theta_phys-gamma); pitch_raw=gamma_path+pitch_corr+alpha_hat
NEW: alpha_ff=c0/max(u_ref,.9)^2+c_gamma*gamma_path; pitch_raw=gamma_path+pitch_corr+alpha_ff (no LPF)
c0=0.0750139438014 c_gamma=0.0472912477744 | Kz=.04 Ki=0 K_gamma=0 | speed PI+FF kD=1.6940741214
Roll: own-eq tilde (not frozen phi_eq)
```

### Before/after (P / U / A04 / AFF)

| Route | uMAE | γMAE° | CTE | γΔ% U→AFF | CTEΔ% |
|-------|-----:|------:|----:|----------:|------:|
| X | 0.3176/0.0008/0.0008/0.0005 | 0.331/0.394/0.313/0.272 | 0.2467/0.2903/0.1131/0.0357 | +30.9 | +87.7 |
| XZ | 0.2550/0.0010/0.0032/0.0008 | 0.418/0.669/0.497/0.297 | 0.4002/0.5582/0.2754/0.0617 | +55.6 | +88.9 |
| R10 | 0.3494/0.0012/0.0041/0.0039 | 0.657/1.028/0.378/0.121 | 0.2690/0.4012/0.2490/0.2000 | +88.2 | +50.2 |

### Verdict / next

- Verdict: **FAIL**
- Gates u/γ/CTE/own-yr/act+settle/vsA04/sat: YES/YES/YES/YES/NO/NO/YES
- Next: `blend_alpha_ff_with_soft_lpf_or_rate_limit` — FAIL leave production unchanged. Fail: settling/OS/acq-rate regress >2% vs prod, acq/rates not improve vs measured A04. Next: blend_alpha_ff_with_soft_lpf_or_rate_limit.
- Production: untouched

### Next

- blend_alpha_ff_with_soft_lpf_or_rate_limit


---

## TRIM_ALPHA_FF_RATE_LIMIT_001 — 2026-08-06 01:51:42

### Provenance

- Read-only: `TRIM_ALPHA_FF_BENCHMARK.mat`, `TRIM_ALPHA_SCHEDULE_ID.mat`, `guidance_law_trim_alpha_ff.m`
- Isolated helper: `guidance_law_trim_alpha_ff_rate_limit.m` (production untouched)
- Driver: `run_trim_alpha_ff_rate_limit.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_FF_RATE_LIMIT.png`

### Shaping equation

```
alpha_ff=c0/max(u_ref,.9)^2+c_gamma*gamma_path; clamp +/-8deg
alpha_cmd(0)=0; |d alpha_cmd/dt|<=2deg/s; pitch_raw=gamma_path+pitch_corr+alpha_cmd (no LPF)
c0=0.0750139438014 c_gamma=0.0472912477744 | Kz=.04 Ki=0 K_gamma=0 | speed PI+FF kD=1.6940741214
Roll: own-eq tilde (not frozen phi_eq)
```

### Before/after (P / A04 / AFF / RL)

| Route | uMAE | γMAE° | CTE | settle AFF→RL | OS AFF→RL | γΔ% U→RL | CTEΔ% |
|-------|-----:|------:|----:|--------------:|----------:|---------:|------:|
| X | 0.3176/0.0008/0.0005/0.0006 | 0.331/0.313/0.272/0.290 | 0.2467/0.1131/0.0357/0.0235 | 3.125→3.350 (-7.2%) | 2.058→1.498 (+27.2%) | +26.3 | +91.9 |
| XZ | 0.2550/0.0032/0.0008/0.0009 | 0.418/0.497/0.297/0.362 | 0.4002/0.2754/0.0617/0.1192 | 6.150→5.750 (+6.5%) | 3.977→3.350 (+15.8%) | +45.9 | +78.6 |
| R10 | 0.3494/0.0041/0.0039/0.0039 | 0.657/0.378/0.121/0.150 | 0.2690/0.2490/0.2000/0.2060 | 2.650→2.975 (-12.3%) | 2.269→1.769 (+22.0%) | +85.4 | +48.6 |

### Verdict / next

- Verdict: **FAIL**
- Gates u/γ/CTE/own-yr/act/settle/vsAFF/sat: YES/YES/YES/YES/NO/NO/NO/YES
- Next: `alpha_cmd_slew_with_soft_start_or_1deg_s` — FAIL leave production unchanged. Fail: elevator/rudder rates regress >2% vs prod, settle/OS worsen >2% vs prod, settle/OS not improve >=10% vs unshaped AFF. Next: alpha_cmd_slew_with_soft_start_or_1deg_s.
- Production: untouched

### Next

- alpha_cmd_slew_with_soft_start_or_1deg_s


---

## TRIM_ALPHA_TRANSIENT_GATE_AUDIT_001 — 2026-08-06 02:00:20

### Provenance

- Read-only: `TRIM_ALPHA_FF_RATE_LIMIT.mat`, `TRIM_ALPHA_FF_BENCHMARK.mat`, `PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat`
- Driver: `run_trim_alpha_transient_gate_audit.m` (one invocation; no sim; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TRANSIENT_GATE_AUDIT.png`

### Definitions

```
band=±0.50deg persistent | e_gamma=γ_ref-γ_act | OS vs mean(γ_ref|ss) | prior OS was |e_θ| peak
```

### Corrected γ settle / OS (AFF→RL) and prior eth settle / OS

| Route | γ set AFF→RL | γ OS AFF→RL | prior set | prior OS | corr act | prior act |
|-------|-------------:|------------:|----------:|---------:|:--------:|:---------:|
| X | 7.375→7.375 (+0.0%) | 0.768→0.720 (+6.2%) | 3.125→3.350 | 2.058→1.498 | NO | YES |
| XZ | 8.475→8.650 (-2.1%) | 0.899→0.885 (+1.5%) | 6.150→5.750 | 3.977→3.350 | YES | NO |
| R10 | 2.875→3.325 (-15.7%) | 0.000→0.000 (NaN%) | 2.650→2.975 | 2.269→1.769 | NO | YES |

### Verdict / next

- Verdict: **PASS** | Class: **METRIC_BUG**
- Audit gates valid/defs/bool: YES/YES/YES
- Next: `two_repeat_closure_egamma_persistent_gates` — METRIC_BUG: prior settle/OS gated on legacy e_theta (OS=|e_θ| peak); actuator acq windows coupled to e_θ settle so steady-rate improve still FAIL. Corrected two-repeat closure: gate settle/OS on persistent |e_gamma|<=0.5deg; OS vs mean(gamma_ref|steady); actuator rates on gamma-derived (or fixed) windows; zeros use abs tol. Do not promote until two-repeat with corrected gates. Note: corrected gamma gates may still FAIL some settle/OS rows — closure must report both; do not treat prior eth-OS as evidence of shaping need.
- Production: untouched

### Next

- two_repeat_closure_egamma_persistent_gates


---

## TRIM_ALPHA_TWO_REPEAT_CLOSURE_001 — 2026-08-06 02:11:37

### Provenance

- Read-only: `TRIM_ALPHA_FF_RATE_LIMIT.mat`, `TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat`, `TRIM_ALPHA_SCHEDULE_ID.mat`
- Isolated helper: `guidance_law_trim_alpha_ff_rate_limit.m` (production untouched)
- Driver: `run_trim_alpha_two_repeat_closure.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_TWO_REPEAT_CLOSURE.png`

### Corrected metrics

```
e_gamma persistent +/-0.50deg | fixed acq t<5s | steady t>=5 & s<0.88s_tot
OS vs mean(gamma_ref|ss) | actuators identical fixed masks | own-eq roll
alpha_cmd |dα/dt|<=2deg/s | Kz=.04 Ki=0 | speed PI+FF kD=1.6940741214
```

### Corrected table (P/U/C)

| Route | uMAE | γMAE° | CTE | settle | acqMAE | OS | dip | γΔ%P/U |
|-------|-----:|------:|----:|-------:|-------:|---:|----:|--------:|
| X | 0.3176/0.0008/0.0006 | 0.331/0.394/0.290 | 0.2467/0.2903/0.0235 | 7.350→7.375 | 1.233→0.883 | 0.000→0.719 | 1.747→1.850 | +12.2/+26.3 |
| XZ | 0.2551/0.0015/0.0014 | 0.443/0.711/0.384 | 0.3953/0.5507/0.1238 | NaN→8.650 | 2.119→2.035 | 0.000→0.802 | 3.650→4.262 | +13.3/+46.1 |
| R10 | 0.3478/0.0038/0.0033 | 0.597/1.079/0.144 | 0.2759/0.3979/0.2096 | 39.000→3.325 | 1.527→0.981 | 0.000→0.206 | 1.901→2.033 | +75.8/+86.6 |

### Verdict / next

- Verdict: **FAIL** | Determinism: **PASS**
- Gates det/u/γ/CTE/set/acq/peak/act/yr/sat: YES/YES/YES/YES/NO/YES/NO/NO/YES/YES
- Next: `alpha_cmd_soft_start_cosine_1deg_s` — FAIL leave production unchanged. Fail: persistent settling not improve vs P, dip/p95/max >2% worse vs P, actuator RMS/rate >2% worse vs P. One final bounded reference shaper: alpha_cmd soft-start cosine envelope with |dα/dt|≤1deg/s (half of current 2deg/s); hold schedule/gains fixed; stop further shaping.
- Production: untouched

### Next

- alpha_cmd_soft_start_cosine_1deg_s


---

## ALPHA_COSINE_SOFTSTART_001 — 2026-08-06 02:21:19

### Provenance

- Read-only: `TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat`, `TRIM_ALPHA_FF_RATE_LIMIT.mat`, `TRIM_ALPHA_TRANSIENT_GATE_AUDIT.mat`
- Isolated helper: `guidance_law_trim_alpha_ff_cosine_softstart.m` (production untouched)
- Driver: `run_alpha_cosine_softstart.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COSINE_SOFTSTART.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COSINE_SOFTSTART.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COSINE_SOFTSTART.png`

### Exact shaping

```
alpha0=alpha_ff(0); Tsoft=pi*|alpha0|/(2*1deg/s); alpha0~0 => skip
t<=Tsoft: alpha_cmd=alpha0/2*(1-cos(pi*t/Tsoft))
t>Tsoft:  |d alpha_cmd/dt|<=1deg/s | schedule/gains unchanged | kD=1.6940741214
e_gamma persistent +/-0.50deg | fixed acq t<5s | own-eq roll
```

### Corrected table (P/RL/CS)

| Route | uMAE | γMAE° | CTE | settle | acqMAE | OS | dip | γΔ%P/U |
|-------|-----:|------:|----:|-------:|-------:|---:|----:|--------:|
| X | 0.3176/0.0006/0.0008 | 0.331/0.290/0.367 | 0.2467/0.0235/0.0368 | 7.350→8.500 | 1.233→1.108 | 0.000→0.680 | 1.747→2.189 | -11.1/+6.8 |
| XZ | 0.2551/0.0014/0.0017 | 0.443/0.384/0.494 | 0.3953/0.1238/0.2006 | NaN→12.125 | 2.119→2.621 | 0.000→0.288 | 3.650→4.769 | -11.7/+30.5 |
| R10 | 0.3478/0.0033/0.0035 | 0.597/0.144/0.212 | 0.2759/0.2096/0.2219 | 39.000→10.700 | 1.527→1.529 | 0.000→0.000 | 1.901→2.502 | +64.5/+80.3 |

### Verdict / next

- Verdict: **FAIL** | Prior-load: **PASS**
- Gates det/u/γ/CTE/set/acq/peak/act/yr/sat: YES/YES/NO/YES/NO/NO/NO/NO/YES/YES
- Next: `outer_gamma_loop_INDI_audit` — FAIL leave production unchanged. Fail: steady gamma <5% vs P or <10% vs U, persistent settling not improve vs P, acq MAE not improve vs P, dip/p95/max >2% worse vs P, actuator RMS/rate >2% worse vs P. Stop trim-alpha shaping; advance to outer gamma-loop/INDI audit.
- Production: untouched

### Next

- outer_gamma_loop_INDI_audit



---

## OUTER_GAMMA_INDI_AUDIT_001 — 2026-08-06 02:38:38

### Provenance

- Read-only: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`, `TRIM_ALPHA_TWO_REPEAT_CLOSURE.mat`
- Driver: `run_outer_gamma_indi_audit.m` (one invocation; no controller edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_INDI_AUDIT.png`

### Equations

```
gamma = -theta + atan2(w,u)
Cgamma_v=[0,-1,da/du,da/dw,0] on [z,theta,u,w,q]
G_delta = Cgamma*B_de  (reldeg-1 Markov)
```

### Key numbers

| Qty | level | climb |
|---|---:|---:|
| Gdc gamma/de | 13.7077 | 5.575 |
| Gdelta | -0.224967 | -0.216656 |
| reldeg | 1 | 1 |
| |T_gamma|/Gdc at bw_th/3 | 1.025 | 0.999 |
| 3x-flat OK | 1 | 1 |

### Verdict / next

- Verdict: **PASS** | Decision: **`INDI_FIRST`**
- Reason: INDI_FIRST: authority gate failed (Gdc/Gdelta OP variation or headroom); RHP zero in open-loop gamma<-de (NMP inverse response). Reldeg-1 gives direct Gdelta=Cgamma*B_de (dGdelta small vs dGdc) for filtered-gamma_dot INDI.
- Next: `implement_incremental_gamma_INDI_scaffold`
- Production: untouched

### Next

- implement_incremental_gamma_INDI_scaffold


---

## GAMMA_INDI_SCAFFOLD_001 — 2026-08-06 02:44:29

### Provenance

- Read-only: `OUTER_GAMMA_INDI_AUDIT.mat`, `controller_law.m`, `underwater777_vehicle_dynamics.m`
- Driver: `run_gamma_indi_scaffold.m` (one invocation; no production edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GAMMA_INDI_SCAFFOLD.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GAMMA_INDI_SCAFFOLD.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GAMMA_INDI_SCAFFOLD.png`

### Equations

```
nu = gamma_ref_dot + 0.46*e_gamma  clip +/-6deg/s
de_indi = de_f + (nu - gamma_dot_f)/Gdelta, Gdelta=-0.2208
de_corr = sat(de_indi-de_base,+/-2deg); tau_f=0.15s
```

### Key numbers

| OP/step | MAE_b° | MAE_s° | set_b | set_s | PASS |
|---|---:|---:|---:|---:|:---:|
| level +1 | 0.0499 | 0.9034 | 6.38 | Inf | NO |
| level -1 | 0.0473 | 0.9968 | 3.75 | Inf | NO |
| climb +1 | 0.4568 | 0.8591 | Inf | Inf | NO |
| climb -1 | 0.5793 | 0.9818 | Inf | Inf | NO |

### Verdict / next

- Verdict: **FAIL** | Decision: **`REJECT_DIRECT_INDI_SCAFFOLD`**
- Reason: Direct incremental gamma-INDI scaffold rejected: level+1deg[wrong gamma sign,MAE/settle not improved >=5%]; level-1deg[MAE/settle not improved >=5%]; climb+1deg[MAE/settle not improved >=5%]; climb-1deg[wrong gamma sign,MAE/settle not improved >=5%] Prefer outer gamma PI/ADRC on theta/q cascade.
- Next: `implement_outer_gamma_PI_or_ADRC`
- Production: untouched

### Next

- implement_outer_gamma_PI_or_ADRC


---

## OUTER_GAMMA_PI_SCAFFOLD_001 — 2026-08-06 02:52:47

### Provenance

- Read-only: `OUTER_GAMMA_INDI_AUDIT.mat`, `controller_law.m`, `underwater777_vehicle_dynamics.m`
- Driver: `run_outer_gamma_pi_scaffold.m` (one invocation; no production edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_PI_SCAFFOLD.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_PI_SCAFFOLD.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_PI_SCAFFOLD.png`
- Prior FAIL: direct gamma-INDI (NMP/RHP-zero sign conflict)

### Equations

```
gamma=-theta+atan2(w,u); e=wrap(gamma_ref-gamma)
theta_path=theta*+(gamma_ref-gamma*)
dtheta=sat(Kp*e+sat(Ki*int,+/-2deg),+/-4deg)
pitch_ref=theta_path+dtheta; conditional-I + Kaw back-calc; bumpless int(0)=0
Kp=0.228822 [-]; Ki=0.319011 [1/s]; wo=0.3; FO poles -0.3,-1.394 zeta=1.310
```

### Key numbers

| OP/step | MAE_b° | MAE_s° | p95_b° | p95_s° | set_b | set_s | PASS |
|---|---:|---:|---:|---:|---:|---:|:---:|
| level +1 | 0.0499 | 0.0658 | 0.1389 | 0.3321 | 6.38 | 5.38 | NO |
| level -1 | 0.0473 | 0.0698 | 0.1930 | 0.3623 | 3.75 | 5.80 | NO |
| climb +1 | 0.4568 | 0.1697 | 0.9452 | 0.2562 | Inf | Inf | YES |
| climb -1 | 0.5793 | 0.2608 | 1.3413 | 0.5446 | Inf | Inf | NO |

Agg MAEΔ=+50.0% settleΔ=-2.3%

### Verdict / next

- Verdict: **FAIL** | Decision: **`REJECT_OUTER_GAMMA_PI_SCAFFOLD`**
- Reason: Outer gamma-PI scaffold rejected: level+1deg[MAE/p95 worsen>2%,overshoot]; level-1deg[MAE/p95 worsen>2%,overshoot]; climb-1deg[overshoot] Next: one ADRC audit/candidate on theta/q cascade.
- Next: `ADRC_outer_gamma_audit_candidate`
- Production: untouched

### Next

- ADRC_outer_gamma_audit_candidate


---

## OUTER_GAMMA_ADRC_SCAFFOLD_001 — 2026-08-06 03:02:11

### Provenance

- Read-only: `OUTER_GAMMA_INDI_AUDIT.mat`, `controller_law.m`, `underwater777_vehicle_dynamics.m`
- Driver: `run_outer_gamma_adrc_scaffold.m` (one invocation; no production edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_ADRC_SCAFFOLD.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_ADRC_SCAFFOLD.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\OUTER_GAMMA_ADRC_SCAFFOLD.png`
- Prior FAIL: direct gamma-INDI; unscheduled outer gamma-PI (level regression)

### Equations

```
gamma=-theta+atan2(w,u); e=wrap(gamma_ref-gamma)
b0=Gdc*bwi [1/s]; wc=0.25; wo=0.75
z1dot=z2+b0*u+2*wo*(gamma-z1); z2dot=wo^2*(gamma-z1)
u=(wc*e-z2)/b0; dtheta=gate(|g_ref|)*sat(u,+/-4deg)
gate: 0 for |g|<=5deg, smoothstep to 1 at 15deg; init z1=gamma,z2=0
b0=1.31106 1/s; poles ctrl=-0.25 eso=-0.75(x2)
```

### Key numbers

| OP/step | MAE_b° | MAE_s° | p95_b° | p95_s° | set_b | set_s | gate | PASS |
|---|---:|---:|---:|---:|---:|---:|---:|:---:|
| level +1 | 0.0499 | 0.0499 | 0.1389 | 0.1389 | 6.38 | 6.38 | 0.00 | YES |
| level -1 | 0.0473 | 0.0473 | 0.1930 | 0.1930 | 3.75 | 3.75 | 0.00 | YES |
| climb +1 | 0.4568 | 0.2029 | 0.9452 | 0.3327 | Inf | Inf | 1.00 | NO |
| climb -1 | 0.5793 | 0.1991 | 1.3413 | 0.6050 | Inf | Inf | 1.00 | NO |

Agg MAEΔ=+56.0% settleΔ=+0.0% | Climb MAEΔ=+61.2% settleΔ=+0.0%

### Verdict / next

- Verdict: **FAIL** | Decision: **`REJECT_OUTER_GAMMA_ADRC_SCAFFOLD`**
- Reason: Outer gamma LADRC scaffold rejected: climb+1deg[overshoot]; climb-1deg[overshoot] Reject ADRC; return to production nonlinear cascade / next roadmap gate.
- Next: `return_production_nonlinear_cascade_next_roadmap_gate`
- Production: untouched

### Next

- return_production_nonlinear_cascade_next_roadmap_gate


---

## SENSOR_NOISE_CURRENT_AUDIT_001 — 2026-08-06 04:11:08

### Provenance

- Read-only: `controller_law.m`, `continuous_path_tracking.m`, `underwater777_vehicle_dynamics.m`
- Driver: `run_sensor_noise_current_audit.m` (one invocation; no production edit)
- Prior: CTRL_OBS_AUDIT IMU+DVL+depth+heading/INS; Depth PI/NDO rejected
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SENSOR_NOISE_CURRENT_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SENSOR_NOISE_CURRENT_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SENSOR_NOISE_CURRENT_AUDIT.png`
- Did not touch `CODEX_VERTICAL_PLAN.md`

### Verdict

**PASS** — sensor/noise/current interface audit completeness (not robustness).

### Key findings

| Item | Result |
|---|---|
| Current / nu_r | NOT_IMPLEMENTED — Vc≡0; damping uses nu; kinematics R*nu |
| Sensor noise / delay / IMU-DVL | NOT_IMPLEMENTED |
| Controller feedback | plant truth BODY/NED (ground≡water) |
| vs obs y_B | production = ideal full-state; realistic sensors ASSUMED only |
| Plumbing | zero-pert X/XZ/R10 @ U=1.5; sensor innov ≡ 0; sensitivity DEFERRED |
| X/XZ/R10 sensor_innov≡0 | YES / YES / YES |

### Estimator

- Conceptual y = [z phi theta psi u v w p q r]; absolute x,y missing under realistic y_B
- Process/meas disturbance vectors: NOT_IMPLEMENTED
- Candidate: **DEFER_ESTIMATOR — no justified current-observer/Kalman/complementary yet**

### Next

- `bounded_plant_current_OR_measurement_noise_hook` — Single next bounded gate: introduce ONE explicit hook — either (a) constant/bounded NED current Vc with nu_r=nu-R'*Vc in plant damping+kinematics, OR (b) additive measurement noise on one realistic channel (e.g. depth or DVL u) with documented sigma — then re-run plumbing sensitivity. Do NOT design estimator yet. Production cascade+guidance remain frozen.


---

## BOUNDED_CURRENT_HOOK_001 — 2026-08-06 04:24:39

### Provenance

- Read-only: `underwater777_vehicle_dynamics.m`, `continuous_path_tracking.m`, `SENSOR_NOISE_CURRENT_AUDIT.md`
- Hook: `underwater777_vehicle_dynamics_current.m` (isolated; production untouched)
- Driver: `run_bounded_current_hook.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\BOUNDED_CURRENT_HOOK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\BOUNDED_CURRENT_HOOK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\BOUNDED_CURRENT_HOOK.png`
- Did not touch `CODEX_VERTICAL_PLAN.md`

### Convention

```
nu ground BODY; Vc NED const; nu_c=R'*Vc; nu_r=nu-nu_c;
eta_dot=R*nu; hydro damping/lift/CS + Coriolis linear use nu_r
```

### Verdict

**PASS** — hook correctness (not robustness; not hardware).

### Key numbers

| Item | Value |
|---|---|
| RHS max|Δ| Vc=0 | 0.000e+00 |
| X traj max|Δ| Vc=0 | 0.000e+00 |
| X CTE b→c | 0.2467 → 0.2557 |
| X e_z b→c | 0.2110 → 0.2110 |
| X eψ° b→c | 0.0000 → 1.3393 |
| X max|Δy| | 0.1122 m |
| XZ traj max|Δ| Vc=0 | 0.000e+00 |
| XZ CTE b→c | 0.3953 → 0.3778 |
| XZ e_z b→c | 0.3106 → 0.2931 |
| XZ eψ° b→c | 0.0000 → 1.2456 |
| XZ max|Δy| | 0.1154 m |
| R10 traj max|Δ| Vc=0 | 0.000e+00 |
| R10 CTE b→c | 0.2300 → 0.1751 |
| R10 e_z b→c | 0.2185 → 0.2027 |
| R10 eψ° b→c | 1.1324 → 1.5535 |
| R10 max|Δy| | 0.3172 m |

### Next

- `INS_ground_minus_DVL_water_current_observer_ONLY` — Hook PASS exposes V_ground_ned and V_water_body; conceptual INS−DVL pair can observe Vc. Implement ONE isolated observer candidate next; no production retune. If observer unjustified in practice, fall back to measurement-noise hook.


---

## CURRENT_OBSERVER_IDEAL_001 — 2026-08-06 04:30:56

### Provenance

- Read-only: `underwater777_vehicle_dynamics_current.m`, `run_bounded_current_hook.m`, `BOUNDED_CURRENT_HOOK.md`
- Trajectories: `BOUNDED_CURRENT_HOOK.mat` (hook PASS)
- Driver: `run_current_observer_ideal.m` (one invocation; offline observer)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_IDEAL.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_IDEAL.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_IDEAL.png`
- Production + current hook untouched; observer NOT fed to guidance/control
- Did not touch `CODEX_VERTICAL_PLAN.md`

### Frames / observer

```
INS Vg_NED=R*nu; DVL Vw_BODY=nu_r; Vw_NED=R*nu_r;
y_c=Vg_NED-Vw_NED (=Vc ideal); dVhat/dt=wo*(y_c-Vhat), wo=0.50, bound±0.5
```

### Verdict

**PASS** — ideal-signal math/plumbing only (not hardware; not noise robustness).

### Key numbers

| Item | Value |
|---|---|
| identity residual max (all) | 6.661e-16 m/s |
| final ||err|| max (all) | 1.851e-05 m/s |
| 2% settle max (all) | 7.825 s |
| bound hits total | 0 |
| X id / final / settle | 4.441e-16 / 1.851e-05 / 7.83 s |
| XZ id / final / settle | 6.661e-16 / 2.505e-06 / 7.83 s |
| R10 id / final / settle | 5.274e-16 / 2.538e-11 / 7.83 s |

### Observability note

Ideal algebraic pair requires BOTH ground velocity (INS) and water-relative velocity (DVL) in consistent frames; missing either channel leaves Vc unobservable from kinematics alone. Attitude enters only via R; with perfect nu and nu_r, R cancels and y_c=Vc exactly. This certifies math/plumbing only — sensor noise, bias, latency, lever-arm, and frame misalignment are NOT tested. Do not promote to production guidance/control.

### Next

- `measurement_noise_hook_INS_DVL_pair` — Next bounded gate: documented additive measurement-noise hook on the conceptual INS ground-velocity / DVL water-velocity pair, then re-run observer sensitivity (still offline). Never promote observer to production yet.


---

## CURRENT_OBSERVER_NOISE_001 — 2026-08-06 04:59:45

### Provenance

- Read-only: `run_current_observer_ideal.m`, `CURRENT_OBSERVER_IDEAL.mat`, `BOUNDED_CURRENT_HOOK.mat`
- Ideal observer PASS; production + current hook untouched; offline only
- Driver: `run_current_observer_noise.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_NOISE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_NOISE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_NOISE.png`
- Did not touch `CODEX_VERTICAL_PLAN.md`

### Noise case (TEST ASSUMPTION — not hardware)

```
INS σ=0.020 m/s @ 20 Hz ZOH; DVL σ=0.010 m/s @ 5 Hz ZOH;
independent, bias=0, delay=0, rng(42); y_c=Vg-R*Vw (truth R);
same observer wo=0.50 (no tuning); steady t>=10.0 s
```

### Verdict

**PASS** — declared synthetic noise case only (not hardware; bias/latency deferred).

### Key numbers

| Item | Value |
|---|---|
| bias||mean|| max (all) | 2.3553e-03 m/s |
| steady RMSE max (all) | 5.3153e-03 m/s |
| p95 max (all) | 1.0763e-02 m/s |
| final ||err|| max (all) | 4.8865e-03 m/s |
| bound hits total | 0 |
| X bias/rmse/p95/final | 1.410e-03 / 4.508e-03 / 7.349e-03 / 4.886e-03 |
| XZ bias/rmse/p95/final | 2.355e-03 / 4.405e-03 / 6.775e-03 / 2.450e-03 |
| R10 bias/rmse/p95/final | 1.646e-03 / 5.315e-03 / 1.076e-02 / 4.881e-03 |

### Route/attitude note

DVL BODY noise rotated by truth R → NED innovation cov is attitude-dependent; R10 (large ψ swing) should differ from X/XZ. INS noise already in NED is attitude-independent. Ideal y_c≡Vc; noisy y_c = Vc + n_ins - R*n_dvl (zero bias/delay case).

### Next

- `bias_latency_audit_INS_DVL` — Noise PASS → next bounded gate: ONE bias/latency audit on the INS/DVL pair (still offline). Never feed observer to control; never promote to production.
- Never feed observer to control; never promote to production.


---

## CURRENT_OBSERVER_BIAS_LATENCY_001 — 2026-08-06 05:12:39

### Provenance

- Read-only: `run_current_observer_noise.m`, `CURRENT_OBSERVER_NOISE.mat`, `BOUNDED_CURRENT_HOOK.mat`
- Noise-only observer PASS; production + current hook untouched; offline only
- Driver: `run_current_observer_bias_latency.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_BIAS_LATENCY.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_BIAS_LATENCY.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CURRENT_OBSERVER_BIAS_LATENCY.png`
- Did not touch `CODEX_VERTICAL_PLAN.md`

### Bias+latency case (TEST ASSUMPTION — not hardware)

```
Noise retained rng(42); INS bias=[+0.010,-0.005,+0.005]@50ms;
DVL bias=[+0.005,+0.000,-0.003]@200ms; causal ZOH delay;
SIMPLIFYING: delayed DVL BODY × CURRENT truth R;
same observer wo=0.50 (no tuning); steady t>=10.0 s
```

### Verdict

**PASS** — declared synthetic bias+latency case only (not hardware; attitude/misalign/lever-arm deferred).

### Key numbers

| Item | Value |
|---|---|
| bias||mean|| max (all) | 1.2496e-02 m/s |
| steady RMSE max (all) | 1.7361e-02 m/s |
| p95 max (all) | 2.6734e-02 m/s |
| final ||err|| max (all) | 1.8591e-02 m/s |
| bound hits total | 0 |
| X bias/rmse/p95/final | 8.964e-03 / 9.953e-03 / 1.350e-02 / 1.087e-02 |
| XZ bias/rmse/p95/final | 7.888e-03 / 8.634e-03 / 1.148e-02 / 9.354e-03 |
| R10 bias/rmse/p95/final | 1.250e-02 / 1.736e-02 / 2.673e-02 / 1.859e-02 |
| R10−X Δbias / ΔRMSE | 3.532e-03 / 7.408e-03 |

### Route/attitude note

Delayed DVL BODY is rotated by CURRENT truth R → NED innovation is attitude-dependent even with constant BODY bias. R10 (large ψ swing) maps fixed BODY DVL bias through a rotating frame → time-varying NED bias contribution; X/XZ nearly constant attitude → nearer to static NED bias. INS NED bias is attitude-independent. Latency adds causal phase lag on both channels.

### SIMPLIFYING ASSUMPTION

SIMPLIFYING ASSUMPTION: delayed DVL BODY sample is rotated into NED using the CURRENT truth attitude R(t), not R(t-latency). This decouples attitude latency from DVL velocity latency for this declared synthetic case only; not a hardware claim.

### Next

- `combined_nonlinear_6dof_disturbance_regression_baseline` — Bias/latency PASS → next bounded gate: combined nonlinear 6DOF disturbance regression baseline (still offline / not production). Never feed observer to control; never promote to production.
- Never feed observer to control; never promote to production.


---

## FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS_001 — 2026-08-06 08:07:40

### Cross-reference (requirements audit; no plant/SS change)

- Primary artifact: `suite_results/FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS.md`
- Research log: `suite_results/PITCH_CONTROL_RESEARCH_LOG.md` (FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS_001)
- Plant interface reminder (this audit): inputs remain commanded `delta_r, delta_e, thrust`; no actuator position/current/health feedback in production stack.
- Sensor reminder: production feedback = plant-truth BODY/NED; realistic IMU/DVL noise-delay plumbing NOT_IMPLEMENTED for control (CUSUM uses ASSUMED synthetic corruption offline only).
- FDI implication: command+IMU+DVL CUSUM = anomaly detection only; software-only rudder isolation NOT supportable until actuator telemetry ICD + identification requirements are met.
- Next bounded gate (from requirements audit): `actuator_feedback_telemetry_interface_specification` (not tangent-exit safe-mode).
- Production controller/guidance/plant unchanged; CODEX_VERTICAL_PLAN untouched.

---

## ACTUATOR_FEEDBACK_TELEMETRY_ICD_001 — 2026-08-06 08:12:43

### Cross-reference (actuator telemetry ICD; no plant/SS change)

- Primary artifact: `suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md`
- Research log: `suite_results/PITCH_CONTROL_RESEARCH_LOG.md` (ACTUATOR_FEEDBACK_TELEMETRY_ICD_001)
- Plant interface reminder: production inputs remain commanded `delta_r, delta_e, thrust` only; L1–L4 actuator meas/current/health/validity telemetry specified but **NOT_IMPLEMENTED** in production stack.
- ICD anchors from control path: `dt_controller=0.025` s → 40 Hz telem min; `|δr|≤25deg`, `|δe|≤15deg`, software slew 40 deg/s (`controller_law` rate limit); sim must log plant-input vs command separately from online monitor inputs (no L5 fault-truth leakage).
- FDI implication: isolation predicates (track/stall/open/sensor/hydro) defined with TBD thresholds; CUSUM remains detect-only until emulator separability + R-ID* PASS.
- Next bounded gate: `isolated_telemetry_emulator_and_fault_class_separability_study` (no accommodation/safe-mode wiring).
- Production controller/guidance/plant unchanged; CODEX_VERTICAL_PLAN untouched.

---

## ACTUATOR_BENCH_HIL_ACCEPTANCE_PLAN_001 — 2026-08-06 08:32:29

### Cross-reference (bench/HIL acceptance plan; no plant/SS change)

- Primary artifact: `suite_results/ACTUATOR_BENCH_HIL_ACCEPTANCE_PLAN.md`
- Research log: `suite_results/PITCH_CONTROL_RESEARCH_LOG.md` (ACTUATOR_BENCH_HIL_ACCEPTANCE_PLAN_001)
- Plant interface reminder: production inputs remain commanded `delta_r, delta_e, thrust` only; L1–L4 actuator meas/current/health/validity still **NOT_IMPLEMENTED** in production stack.
- Plan expands ICD AT-B*/AT-H* into executable ID/acceptance steps; SIL ASSUMED predicates from ACTUATOR_TELEMETRY_SEPARABILITY remain logical-only until HW-TRAIN freeze → HW-VAL.
- FDI implication: isolation evidence path may become hardware-acceptable only after EXTERNAL-HARDWARE materials + G-* PASS; safe-mode/accommodation remain **PROHIBITED** / **NOT_IMPLEMENTED**.
- EXTERNAL-HARDWARE GATE: **BLOCKED** (vendor ICD / encoder-current telem / bench not supplied this task).
- Production controller/guidance/plant unchanged; CODEX_VERTICAL_PLAN untouched.


## REALISM_GAP_AUDIT_001 — 2026-08-06

### Cross-reference (plant/sensor/actuator/computation realism; no plant/SS change)

- Primary artifact: `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md`
- Research log: `suite_results/PITCH_CONTROL_RESEARCH_LOG.md` (REALISM_GAP_AUDIT_001)
- Antecedent: `AUV_VISUAL_EVIDENCE_PACK_001` PASS; production frozen.
- Plant reminder: `underwater777_vehicle_dynamics.m` applies commanded `delta_r,delta_e,thrust` with no servo dynamics; hydro globals lack provenance/uncertainty in audited sources; production `Vc≡0`; sensing for control remains plant-truth.
- Actuator reminder: `controller_law.m` software mag + 40 deg/s slew only; visual rudder chatter 37.738 deg/s with ±40 deg/s rate contact flagged as realism concern (panel PASS ≠ physics cert).
- Next bounded gate: `actuator_dynamics_realism_baseline` (isolated; no controller retune; no HW certification claim).
- Production controller/guidance/plant unchanged; CODEX_VERTICAL_PLAN untouched.


---

## DEPTH_GAMMA_COUPLED_PLANT_ID_001 — 2026-08-08 01:45:23

### Provenance

- Sources (exactly 3): LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat, SS_VALIDATION.mat
- Driver: `run_depth_gamma_coupled_plant_id.m` (production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_COUPLED_PLANT_ID.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_COUPLED_PLANT_ID.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_COUPLED_PLANT_ID.png`

### Verdict

**PARTIAL** — sagittal coupled depth/γ plant ID at level+climb U=1.5-class only.

### Key

- θ_phys=-θ (IMPLEMENTED); α=atan2(w,u) linearized (DERIVED); γ=θ_phys+α (DERIVED)
- LEVEL unstable reduced: +0.735+0i; +0.2411+0i; CLIMB unstable reduced: +0.4871+0.2493i; +0.4871-0.2493i
- Ctrl/Obs ranks level 5/5, climb 5/5 (scaled sagittal)
- Traj transform compare: 4/4 PASS (tol nrmse≤0.20 corr≥0.95)
- Speed family U={1.0,1.5,2.0}: absent → Gate-1 full PASS not claimed
- Hydro coeffs: TO_BE_IDENTIFIED (no invented provenance)

### Next

- `depth_gamma_speed_scheduled_id_extension`


---

## WATER_CURRENT_FEASIBILITY_MAP_001 — Gate 4A

- Verdict: **PASS**; currents **ASSUMED**; actuator readiness **NOT_CERTIFIED**.
- Deterministic 32-case offline map; robustness failures remain explicit.
- Production/controller/guidance/references frozen; no crab-current FF or external shaper.
- Next: Gate 4B feasibility-aware guidance/reference-governor SHADOW candidate.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_REFERENCE_GOVERNOR_001 — Gate 4B shadow candidate 1 (research log)

- Verdict: **PARTIAL**; currents **ASSUMED** truth/bound oracle, not a certified estimator; actuators **NOT_CERTIFIED**.
- Primary contact reduction -0.360%; worst-margin improvement 0.000000; exact FEASIBLE parity 1.
- Production frozen; no Vc yaw/crab angle, retune, geometry change, or external shaper.
- Structurally different, untried: internal finite-horizon arc-length governor using a rudder-state predictor and constraint projection. No sweep. No promotion without identical regressions; shadow evidence only.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_001 — Gate 4B final candidate 3/3

- Verdict: **FAIL**; Gate 4B **CLOSED after 3 candidates**.
- Single authorized MATLAB call stopped at a pre-execution parse blocker; 32 declared, 0 executed.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen.
- Gate 5 is prohibited absent an explicit residual-risk waiver.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_RERUN_001 — 4B syntax-fix validation exception beyond 3/3 (research log)

- Verdict: **FAIL** — Gate 4B syntax-fix validation exception FAIL; causal residual risk remains after authorized rerun.
- Coverage: 32 declared / **0 executed**; pass-through n/a, RESHAPE n/a, REFUSE n/a.
- Causal FAIL: route/current logical-mask orientation (1x32 & 32x1 → 32x32) aborted governor before any contract.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen; not promoted.
- Prior `WATER_CURRENT_ADMISSION_GOVERNOR.*` FAIL artifacts preserved; RERUN artifacts written.
- Next: Gate 5 prohibited absent explicit residual-risk waiver; currents ASSUMED and actuators NOT_CERTIFIED.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_RERUN2_001 — 4B mask-orientation validation exception beyond 3/3 (research log)

- Verdict: **FAIL** — Gate 4B mask-orientation validation exception FAIL; causal residual risk remains after authorized rerun2.
- Coverage: 32/32; pass-through 18, RESHAPE 3, REFUSE 11.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen.
- Production not promoted; refusal never counted as tracking success.
- Next: Gate 5 prohibited absent explicit residual-risk waiver; currents ASSUMED and actuators NOT_CERTIFIED.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_RERUN2_001 — causal residual clarification (research log)

- Mask orientation validated; campaign executed 32/32 (18 PASS_THROUGH / 3 RESHAPE / 11 REFUSE).
- Verdict remains **FAIL** on `admitted_secondary_within_2pct` for RESHAPE rows 22-24 (depth_rms).
- Contact reduction gate passed; hard violations zero; refusals deterministic and not counted as tracking success.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen; Gate 5 prohibited without waiver.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

<!-- APPEND_MARKER:GATE8_RESIDUAL_RISK_WAIVER_AND_GATE9_ENTRY_001 -->

## Append: GATE8_RESIDUAL_RISK_WAIVER_AND_GATE9_ENTRY_001 (model-audit log)

**Date:** 2026-08-09 12:21:58 | **Class:** doc-only Gate 8 disposition | **MATLAB runs:** 0 | **Source/runtime edits:** NONE | **Repo scan:** NONE | **Production/CODEX_VERTICAL_PLAN:** untouched | **HW:** **NOT_CERTIFIED**

**Gate 8 verdict: `WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT`. Gate 8 is NOT PASS.** Issued under the readiness-plan rule permitting a prior gate to be explicitly waived with a written residual risk, after three failed Monte Carlo closure attempts and with the scalar-rescaling and C1 course-reference methods CLOSED.

Sources read (exactly 3): `suite_results/AUV_REALIZATION_READINESS_PLAN.md`, `suite_results/AUTONOMOUS_EXECUTION_POLICY.md`, `suite_results/GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE.md`.

### Model-side residual risk (what the state-space picture does and does not support)

| # | Item | Status | Label |
|---|------|--------|-------|
| R1 | R10 production rudder rail: raw demand 466.6729 deg pre-limiter, plant input pinned at the 25.0000 deg envelope for 0.2817 of a 30 s horizon, magnitude dwell 0.8908, rate dwell 0.6917, peak realized slew 40.0000 deg/s. Origin **multi-source** — 3 contributions each reach the envelope alone, earliest `S2_CTRL_TERM_P` at t = 1.200 s; integrator windup **EXCLUDED_STRUCTURALLY** (no integral state on the rudder channel and the reconstruction closes without one); actuator dynamics NOT_PRESENT_IN_THIS_CELL | **UNRESOLVED / BLOCKER** | `IMPLEMENTED` measurement |
| R2 | Rigid-body parameter uncertainty — CG/CB ±2 cm per axis, buoyancy ±3% — is **drawn into the campaign vector and never injected**: no shadow plant-parameter seam exists, so the state-space model was never perturbed in mass, restoring or buoyancy. Any distribution reported for Gate 8 is therefore **blind to the parameters that dominate the vertical restoring and trim** | **UNSUPPORTED** (HG11) | `ASSUMED` prior, not exercised |
| R3 | Gate 7 16-case FDIR matrix not re-driven through the Monte Carlo loop under the same draws | **NOT_EVALUATED** (HG12) | — |
| R4 | The 8 evaluation cells (X/XZ at U = {1.0, 1.5, 2.0}, R10 at U = {1.5, 2.0}) are an **`ASSUMED_RECONSTRUCTION`**, not a binding to the frozen cell definitions, so operating-point coverage of the identified plant family is asserted rather than proved | **OPEN** (HG13) | `ASSUMED_RECONSTRUCTION` |
| R5 | Estimator streams absent on the Gate 8 path: the loop runs on truth `x`, `y`; the Gate 5B 18-state error-state EKF and the Gate 5C availability manager were never inserted, so no estimation error enters any state trajectory reported here | **NOT_IMPLEMENTED** | `NOT_IMPLEMENTED` |
| R6 | Power/propulsion coupling exercised only as a thrust-authority derate; the brownout branch was never entered | **PARTIAL** | `PARTIAL` |
| R7 | Hydro coefficients, speed family, servo τ / deadband / hysteresis, thruster map and sensor σ / bias / delay remain unidentified; mission / nav / actuator-feedback rates unspecified | **OPEN** | `TO_BE_IDENTIFIED` |
| R8 | Hardware readiness | **NOT_CERTIFIED** | `NOT_CERTIFIED` |

### Why the plant model itself is judged feasible

The failures above are coverage and injection failures, not evidence of an ill-posed or divergent model. Positively established: the hooks-off shadow path is bit-identical to unmodified `continuous_path_tracking.m` in 8/8 cells; the R10 cell reproduces fingerprint `n=153600.s1=19094896.s2=2901292177` across unmodified production, hooks-off replica and instrumented replica; reverse-order replay and reset sentinels reproduce bitwise; the reconstructed contribution sum matches the logged raw command to 1.137e-13 deg over 1200 samples against a 1e-9 deg tolerance; the exact course identity `chi = psi + beta` closes to 8.882e-16 rad and the four-term course-offset identity to 2.005e-15 rad; the C1 probe rebuilt the production reference to a worst residual of 1.332e-15 rad. Distributionally, pooled `cte_max` P5/P50/P95/worst = 0.110 / 0.342 / 0.565 / 0.826 m with pass probability 0.8594 (Wilson 95% CI [0.8115, 0.8967]) once the limiter-ordering defect was removed, with **zero** rate violations against the 40 deg/s envelope.

So the state-space and kinematic identities close to numerical noise and the integration is reproducible — but the model was never perturbed in CG/CB/buoyancy, never observed through an estimator, and never bound to frozen cell geometry. Those three gaps are why this is a waiver and not a PASS.

### No closed method will be re-run against this model

Coordinated scalar rescaling of `(Kp_psi, Kd_psi)` at fixed `Td` is `SCALAR_METHOD_CLOSED`: across its anchors the rail trades monotonically against cross-track error (cte max 0.21262 m at `s = 1` versus 0.89243 m at `s = 0.017453`). The C1 course-reference change (`k_beta` 1.35 → 1.00) is `REJECT_C1_METHOD_CLOSED` on a structural ratio — a 0.335019 deg over-crab term against a 5.625664 deg heading error can move the implied P demand by at most tenths of a per cent, and the attribution identity shows the offset is transferred rather than removed. gamma INDI/PI/LADRC, depth PI/NDO, crab-current FF and the simple polyline shaper remain permanently banned.

**Next exact task (exactly one):** `GATE9_SIMULATION_RC_ASSESSMENT_001` — bounded RC assessment and evidence-range assembly; every requirement range `DERIVED` and carrying its `ASSUMED` / `TO_BE_IDENTIFIED` parent label. Gate 9 PASS remains impossible unless every hard safety gate passes. Simulation is not hardware certification.


---

## GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001 — embedded-transfer gap audit

**Verdict: FAIL. RC_NOT_GRANTED sustained. State: `AWAIT_STM32_EXACT_PART_NUMBER`.**

Read-only, fast whole-code embedded-transfer audit. No MATLAB, no execution, no repo scan, no runtime edit, no source edit, no candidate retry, no promotion, no label upgrade.

**Sources read: exactly 3, no repo scan** — `continuous_path_tracking.m` (10845 B, sha256 `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b`), `guidance_law.m` (14601 B, `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3`), `controller_law.m` (9402 B, `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890`). Every line citation in the report refers to these three files. No other file was source-reviewed; `init_parameters`, `underwater777_vehicle_dynamics`, `wrapToPi` and `interp1` are named only as call-graph entries and their contents are TO_BE_IDENTIFIED.

**Carried Gate 9 disposition, not re-derived:** RC_NOT_GRANTED; residual risks R1–R8 all OPEN; exact target ABSENT.

**Gate 9B PASS criteria and result:** zero software/safety BLOCKER — **NOT MET (14 distinct blocker classes)**; complete embedded handoff manifest — **NOT MET (42 rows; 15 TO_BE_IDENTIFIED, 6 ASSUMED/partial, 4 required units absent)**.

**Deployable core vs simulation.** Only `inertial_velocity_ned` (`continuous_path_tracking.m:228–244`) is transferable as-is: pure, fixed-size, allocation-free. `controller_law.m:59–179` is straight-line and bounded-cost and is the most transfer-ready control unit. `guidance_law.m:52–279` plus helpers `:283–394` are the control law proper but are O(n) per tick in an unbounded `path`. `continuous_path_tracking.m:1–226` is simulation harness (fixed-horizon loop `:71`, host variable-step integrator `:101`, ~30 whole-mission log buffers `:20–63`, stdout in-loop `:104–106,183–184`, 28 export globals `:189–225`). `underwater777_vehicle_dynamics` is plant, not read. **The repository does not currently contain a separable deployable control core; the gap is architectural and is not closed by choosing a target.**

**Findings: 71 total** — 51 BLOCKER (14 distinct classes), 8 TARGET_DEPENDENT, 2 EXTERNAL_HIL, 10 COSMETIC (6 of them positive). Labels: 34 IMPLEMENTED, 34 DERIVED, 0 ASSUMED in findings, 11 TO_BE_IDENTIFIED.

**The 14 software/safety BLOCKER classes (all host-side, all target-independent):**
- **B01** no deterministic init/step/reset API; `persistent` survives across missions (`guidance_law.m:21,68–80`; `controller_law.m:23–25,151–154`).
- **B02** navigation layer absent — every control input is plant truth (`continuous_path_tracking.m:72–94`), including sideslip `beta` (`guidance_law.m:168–173`) and flight-path `gamma_actual` (`:210`); code-level form of carried R5.
- **B03** mission and actuator layers are not interfaces (`guidance_law.m:1`; `controller_law.m:1`; `continuous_path_tracking.m:96–98`).
- **B04** global parameter/diagnostic coupling; functions mutate their own configuration (`guidance_law.m:13–19,27–34`; `controller_law.m:12–30,38–57`; harness rewrites both rate globals at `continuous_path_tracking.m:9–17`); plant derivatives `Muw`/`Muuds` and fitted constants hard-coded in the controller (`controller_law.m:52–54,111–112`); not reentrant.
- **B05** dynamic/variable-size memory: run-length log allocation (`continuous_path_tracking.m:19–63`), reallocation on the fault path (`:107–114`), unbounded `path` with per-tick `zeros(n,1)` (`guidance_law.m:54,62,285`), `nargout`-dependent 27-field struct (`controller_law.m:181–213`).
- **B06** host-only step driver: `ode45` with anonymous handle (`continuous_path_tracking.m:101`), `try/catch` + `ME.message` (`:100–106`), in-loop `fprintf` (`:104–106,183–184`).
- **B07** non-base-language calls inside the core: `wrapToPi` (`guidance_law.m:164,173,180,212`; `controller_law.m:61`), `interp1(...,'extrap')` (`controller_law.m:222`), `find(...,1,'last'/'first')` (`guidance_law.m:324–327,361–362`).
- **B08** NaN used as control-flow sentinel (`guidance_law.m:71–73,79,161,177,239`); no floating-point format or mode policy anywhere.
- **B09** unbounded numeric ranges: never-rewrapped heading accumulator (`guidance_law.m:180,254,263`), gain-dependent integrator limits up to ~1.4e5 rad (`controller_law.m:83,102`), curvature reciprocal to 1e4 m (`guidance_law.m:135,150`).
- **B10** **highest severity** — no parameter validity check and no input validity check. Thirteen unguarded globals (`controller_law.m:12–17`) used at `:63,66,70,82–83,86,102,106,133,136,139,178–179`; if `init_parameters` has not run, `max(min(x,[]),[])` yields empty and an **empty actuator command propagates silently** instead of a fault or a safe state. No NaN/Inf/range check on any navigation input, and no reset to recover from a poisoned integrator. Unbounded trim extrapolation at `:222` can consume full elevator authority off-table.
- **B11** sample time owned by globals (`controller_law.m:56–58`; `guidance_law.m:32–36`); rate ratio rounded without check (`continuous_path_tracking.m:69,84`) which desynchronises `z_e_i` (`guidance_law.m:194`), the pitch rate limit (`:258`) and `pitch_ref_dot` (`:265`); unguarded ZOH with no hold-age (`continuous_path_tracking.m:68`); nine hard-coded filter alphas that bake in the tuning sample rate (`guidance_law.m:134,147,164,202,213,222,226,243,252`). The correct pattern already exists at `controller_law.m:57,76`.
- **B12** anti-windup computed before the rate limiter and therefore blind to rate saturation (`controller_law.m:133,140–142,149–152`) — with a 40 deg/s limit, rate saturation is the likely dominant limiter; guidance depth integrator has no anti-windup under three cascaded downstream saturations (`guidance_law.m:194–195,204,229,256–261`); no bumpless transfer; saturation flag exists only in the optional debug struct (`controller_law.m:202`), invisible to the production three-output call (`continuous_path_tracking.m:91`); rudder saturation never reported back to guidance (carried R1 visible as a missing feedback path).
- **B13** no FDIR interface, no watchdog kick, no deadline/overrun/jitter detection, no safe state, no timing instrumentation of any kind; the only fault-shaped construct prints, truncates and breaks (`continuous_path_tracking.m:100–116`); guidance absorbs implausible progress silently (`guidance_law.m:95–105`).
- **B14** no transport schema at any of the four existing boundaries — version, timestamp, sequence, validity, heartbeat and stale rule are absent everywhere; log keys are bare global names (`continuous_path_tracking.m:189–225`; `guidance_law.m:231–238`; `controller_law.m:156–176`); sign and frame conventions survive only in comments (`controller_law.m:3–4,73–74`, `elevator_sign` `:17,46,107,136`; `guidance_law.m:192–193,201`), and losing them is a pitch-divergence hazard. Twin equivalence is untestable: all four preconditions (identical initial state, identical timed inputs, identical parameters, stable log keys) fail.

**TARGET_DEPENDENT (8):** heap budget, in-loop `exp` (`controller_law.m:76`), curvature dynamic range, host `eps` as divisor guard (`:66`), intra-frame scheduling/jitter/phase, transport medium and encoding, stack budget (favourable: recursion-free, depth ≤ 3), absolute WCET/footprint/achievable rate. **EXTERNAL_HIL (2):** actuator dynamics absent from the read set (`continuous_path_tracking.m:96–98`); actuator and sensor numerics require a bench. **Positive findings:** control path is RNG-free and clock-free and therefore bit-reproducible on a fixed FP configuration; units are internally SI-consistent with no dimensional defect found; magnitude saturation, rate limiting and back-calculation anti-windup are all present; `controller_law` is recursion-free and straight-line.

**Recommended host-side fix order (recommendation only, not an authorisation to edit):** B10 → B01 → B04 → B11 → B14 → B12 → B13 → B05/B07/B08/B09 → B02/B03 → B06.

**Constraint restated.** Target work remains **FORBIDDEN** until the user supplies the **exact target part number and board** *and* each of B01–B14 is individually dispositioned (fixed, formally waived with recorded residual risk, or deferred with an owner). A part number alone does not unblock, because all 14 blockers are host-side. **No MCU family, vendor, brand, board or part number is named in this record.** Simulation is not hardware certification: **NOT_CERTIFIED**.

**Integrity.** Production sources verified **UNTOUCHED** (hashes above, identical before and after). `suite_results/CODEX_VERTICAL_PLAN.md` **UNTOUCHED — not read, not written** (43101 B, sha256 `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c`). No file deleted, renamed, moved, truncated or overwritten; all evidence preserved. Writes: created `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`; append-only to `suite_results/AUV_REALIZATION_READINESS_PLAN.md`, `suite_results/AUTONOMOUS_EXECUTION_POLICY.md`, `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md`, `suite_results/PITCH_CONTROL_RESEARCH_LOG.md`, `suite_results/STATE_SPACE_MODEL_AUDIT.md` — each appended without being read, each receiving this identical block.

Full report: `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`.

<!-- APPEND_MARKER:CG_PRE0_TOOLCHAIN_CAPABILITY_001 -->

## Append: CG_PRE0_TOOLCHAIN_CAPABILITY_001 — MATLAB→C++ pretarget capability gate

**Date:** 2026-08-10 01:59 | **Class:** read-only toolchain capability gate | **MATLAB runs:** 1 | **Install/config/source edits:** NONE | **Repo scan:** NONE | **Production/CODEX:** untouched | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** MATLAB R2025b PCWIN64 bridge OK. MATLAB Coder PRESENT+LICENSE_AVAILABLE with resolvable `codegen`/`coder` APIs. Simulink Coder / Embedded Coder classic license features test true (`Real-Time_Workshop`, `RTW_Embedded_Coder`) but products MISSING from `ver`. C/C++ MEX compiler selected=0 installed=0 → executable codegen BLOCKED. STM32-relevant add-ons=0 (MISSING/HARDWARE_BLOCKED). Tiny Coder smoke SKIPPED (exact reason: would require mex/compiler setup, forbidden). C: avail before 4565749760 B (4.25 GiB) → after MATLAB 4554731520 B; small text evidence only.

**Sources read: exactly 3** — `GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`, `AUTONOMOUS_EXECUTION_POLICY.md`, `AUV_REALIZATION_READINESS_PLAN.md`. Gate 9B FAIL / 14 BLOCKERs / `AWAIT_STM32_EXACT_PART_NUMBER` carried, not re-opened.

**Evidence:** `suite_results/CG_PRE0_TOOLCHAIN_CAPABILITY.md` · status board `suite_results/CG_CODEGEN_STATUS.md`.

**Next exact task (exactly one):** `CG0_CODEGEN_BOUNDARY_INVENTORY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG0_CODEGEN_BOUNDARY_INVENTORY_001 -->

## Append: CG0_CODEGEN_BOUNDARY_INVENTORY_001 — codegen boundary inventory

**Date:** 2026-08-10 02:12 | **Class:** read-only source inventory | **MATLAB runs:** 0 | **Source edits:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Scoped 178 root `.m` (0 `.mlx`/`.slx`/`.sldd`); first-level `shadow_r10/` empty of sources. Excluded `suite_results`/dot/git/cache. Classes: DEPLOY 2 · SHARED_SUPPORT 2 · SIMULATION_ONLY 156 · ARCHIVE_REJECTED 18 · HARDWARE_BLOCKED(files) 0. Full review: `controller_law.m`, `guidance_law.m`, `continuous_path_tracking.m`, `init_parameters.m`, `underwater777_vehicle_dynamics.m`; remainder header/call → `NEEDS_CG1_REVIEW`. Deploy graph: cpt → init_parameters / inertial_velocity_ned / guidance_law / controller_law / ode45(plant). Nav/EKF, Mission, FDIR, allocation, actuator feedback = evidence/harnesses only (not production runtime). Compiler MISSING remains PARTIAL; static CG1 allowed.

**Evidence:** `suite_results/CG0_CODEGEN_BOUNDARY.md` · `suite_results/CG0_CODEGEN_MANIFEST.csv` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001 -->

## Append: CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001 — static controller Coder compat

**Date:** 2026-08-10 02:22 | **Class:** bounded static MATLAB Coder audit (accepted controller only) | **MATLAB runs:** 0 | **Source edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** `controller_law.m` scalar core (`:59–179`) directly portable (sin/cos/exp/sign/clamps); lift-as-is blocked by globals + un-resettable persistent, variable nargin/nargout dbg, `wrapToPi`, unbounded `interp1` extrap/trim tables, empty-unguarded gains/limits, dt-from-global. Fixed-signature future API specified only (`Params`/`State`/`Input`/`Output`/`Debug` + init/reset ownership + finite/range guards); **not implemented**. Gains frozen; rejected methods closed. Compiler/tool install remains deferred.

**Sources read: exactly 3** — `controller_law.m`, `suite_results/CG0_CODEGEN_BOUNDARY.md`, `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`.

**Evidence:** `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001 -->

## Append: CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001 — static guidance Coder compat

**Date:** 2026-08-10 02:25 | **Class:** bounded static MATLAB Coder audit (accepted guidance only) | **MATLAB runs:** 0 | **Source edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** `guidance_law.m` LOS/course/β/pitch/Tur4A–5B scalar algebra portable after owned wrap; lift-as-is blocked by 19 globals + 13 un-resettable persistents, variable nargin defaults, unbounded `path` + per-tick `zeros(n,1)`, `find`/`sum` O(n) helpers, toolbox `wrapToPi`, NaN init sentinels, dt-from-global, no path validity/seq. Fixed-signature future API specified only (`Params`/`State`/`Input`/`Output`/`Debug` + bounded path capacity, segment/angle-wrap ownership, finite/range guards); **not implemented** — await golden parity. Accepted LOS tuning frozen; rejected γ-structural/LADRC/INDI/crab-current-FF/polyline closed. Compiler/tool install remains deferred.

**Sources read: exactly 3** — `guidance_law.m`, `suite_results/CG0_CODEGEN_BOUNDARY.md`, `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`.

**Evidence:** `suite_results/CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY.md` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001 -->

## Append: CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001 — nav/FDIR runtime boundary

**Date:** 2026-08-10 02:42 | **Class:** bounded static runtime-boundary audit (exactly 3 nav/FDIR sources) | **MATLAB runs:** 0 | **Source edits:** NONE | **Repo scan:** NONE | **Harness inspect:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** Reusable cores: 18-state propagate/Joseph/admit order (baseline), optional USBL + health-only availability FSM (availability fork), rudder B2 residual+persistence latch (monitor). SIMULATION_ONLY: action-string dispatch, batch N-logs, cell/dynamic structs, innov growth, metrics/gates/truth scoring, `eig`/`error`/`assert`. Lift-as-is **FAIL** — files do **not** DEPLOY. Spec only: `nav_init/reset/propagate/update/output`, `availability_step`, `rudder_fdir_init/reset/step` + Params/State/Input/Output/Health; preserve truth firewall, Joseph form, deterministic order, FDIR latch; thresholds ASSUMED/NOT_CERTIFIED. Compiler/tool install deferred.

**Sources read: exactly 3** — `navigation_multirate_ekf_baseline.m`, `navigation_multirate_ekf_availability.m`, `isolated_online_rudder_residual_monitor.m`.

**Evidence:** `suite_results/CG1C_NAV_FDIR_RUNTIME_BOUNDARY.md` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001 -->

## Append: CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001 — controller golden corpus

**Date:** 2026-08-10 03:00 | **Class:** SIMULATION_ONLY MATLAB golden capture (accepted controller) | **MATLAB runs:** 1 | **Source edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Bounded deterministic corpus `CG2A_CONTROLLER_GOLDEN_V1` (schema 1): N=100 steps × 13 finite inputs × 30 Debug fields; 13 coverage cases (cold nominal; U={1,1.5,2}; yaw wrap ±π; climb/descent; rudder/elevator mag+40°/s slew; pitch I/AW; roll-rate damp; nonzero w @ accepted λ_muw_ff=0). Forced accepted `dt=0.025`. Dual replay with `clear controller_law` → `isequaln` outputs+Debug. Finite + mag/slew checks PASS. `controller_law.m` / `init_parameters.m` fingerprints UNTOUCHED. **C++ parity NOT CLAIMED.** Compiler/tool install deferred.

**Sources read: exactly 3** — `controller_law.m`, `init_parameters.m`, `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md`.

**Evidence:** `suite_results/CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE.md` · `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat` · `suite_results/CG2A_CONTROLLER_GOLDEN_V1.json` · `run_cg2a_controller_golden_parity_capture.m`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001 -->

## Append: CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001 — explicit-state controller prototype

**Date:** 2026-08-10 03:14 | **Class:** SIMULATION_ONLY MATLAB explicit-state prototype + golden parity | **MATLAB runs:** 1 | **Production edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Isolated fixed-ABI prototype `controller_codegen_init/reset/step` (Params from golden snapshot only; deterministic zero State). Replayed all 100 golden steps: exact `isequaln` on every Output+Debug field; dual reset replay A==B; mag/slew bounds OK (40°/s). Label `DEPLOY_CANDIDATE/NOT_IN_PRODUCTION`. TEMPORARY_BLOCKER retained: `wrapToPi`, fixed-table `interp1` linear/extrap. `controller_law.m` fingerprint UNTOUCHED. **C++ parity NOT CLAIMED.** Compiler/tool install deferred.

**Sources read: exactly 3** — `controller_law.m`, `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md`, `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat`.

**Evidence:** `suite_results/CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE.md` · `controller_codegen_{init,reset,step}.m` · `run_cg2a_controller_explicit_state_prototype.m`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001 -->

## Append: CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001 — guidance golden corpus

**Date:** 2026-08-10 03:29 | **Class:** SIMULATION_ONLY MATLAB golden parity capture | **MATLAB runs:** 1 | **Production edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Bounded deterministic corpus `CG2B_GUIDANCE_GOLDEN_V1` (schema 1): N=102 steps × full 8-input `guidance_law` calls × 6 outputs × 11 `last_*` diagnostics; 16 coverage cases (cold/open straight; U_h∈{1,1.5,2}; ±CTE/±depth; multi-seg/curvature; closed seam; near-end slowdown; progress back-snap; yaw wrap ±π; sway β; Tur4A/5A/5B inputs @ accepted K_zdot=0,K_gamma=0,α̂ off). Paths stored padded MAX=32×3 + n_path/path_id; legacy calls use active rows. Forced accepted `dt_guidance=0.075`. Dual replay with identical `reset_before` + `clear guidance_law` → `isequaln` outputs+diagnostics. Finite + range/slew/progress checks PASS. `guidance_law.m` / `init_parameters.m` fingerprints UNTOUCHED. **C++ parity NOT CLAIMED.** Compiler/tool install deferred.

**Sources read: exactly 3** — `guidance_law.m`, `init_parameters.m`, `suite_results/CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY.md`.

**Evidence:** `suite_results/CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE.md` · `suite_results/CG2B_GUIDANCE_GOLDEN_V1.mat` · `suite_results/CG2B_GUIDANCE_GOLDEN_V1.json` · `run_cg2b_guidance_golden_parity_capture.m`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

