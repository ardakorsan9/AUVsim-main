# ROLL_TRIM_RELATIVE_AUDIT_001 — Trim-relative roll audit

**Overall verdict: PASS**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.mat`
- Driver: `run_roll_trim_relative_audit.m` (one invocation; no re-sim; no controller edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.png`

## Purpose

Separate required/benign helix turn bank from roll ripple before control design.
Absolute φ safety envelope kept separate from trim-relative $\tilde\phi=\phi-\phi_{eq}$.
Do **not** call steady bank an error without plant residual evidence.

## Plant roll mode (LOCAL_SS)

| Op | λ | f [Hz] | ζ | T [s] |
|----|---|-------:|--:|------:|
| Level | -2.1388e-02±j4.9934 | 0.7947 | 0.0043 | 1.258 |
| Climb | -1.8914e-02±j4.7799 | 0.7607 | 0.0040 | 1.315 |

## phi_eq provenance

| Route | phi_eq [°] | label | provenance |
|-------|----------:|-------|------------|
| X | 0.0000 | equilibrium_trivial | forced_zero_straight_no_yaw |
| XZ | 0.0000 | equilibrium_trivial | forced_zero_straight_no_yaw |
| H | 1.4610 | empirical_cycle_mean_not_equilibrium | IDENTIFIED robust turn median(per_turn_mean)=1.4610 deg; plant roll residual NOT small → empirical bank, not equilibrium |

### R10 identification detail

- Estimator: **median(per_turn_mean)** → φ_eq = 1.4610°
- Overall mean/median: 1.4427° / 1.4350°
- Robust turn mean/med: 1.4610° / 1.4854°
- First/last half means: 1.4541° / 1.4314° (Δ=0.0227°, stable=1)
- Per-turn means [°]: [1.44 1.483] (spread=0.0430°, n_turns=2, stable=1)
- Identification confidence: **high**

## Plant roll residual (exact RHS at mean state/input)

- Evaluated at canonical helix point from steady-window mean (thrust reconstructed: thrust_trim+Kp_x(u_ref−u))
- p_dot = -2.255944e-03 rad/s² (norm = 0.01128 vs tol 0.01)
- φ_dot = -9.997339e-04 rad/s
- norm_dyn = 0.01128 | norm_rel (rotating) = 0.019995
- ν̇_norm_comp = [0.003495 0.003369 0.0005698 0.01128 2.852e-05 0.004772 ]
- Residual small? **NO** → label **empirical_cycle_mean_not_equilibrium**
- Note: p_dot=-2.2559e-03 (norm=0.01128), norm_dyn=0.01128, norm_rel=0.01999 (tol=0.01); phi*=1.4427 deg

## Absolute φ safety envelope (ref=0 context)

| Route | signed_mean [°] | MAE | RMS | p95 | max | abs_max≤5° |
|-------|----------------:|----:|----:|----:|----:|:----------:|
| X | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | YES |
| XZ | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | YES |
| H_R10 | 1.4427 | 1.4427 | 1.5453 | 2.3038 | 3.2443 | YES |

## Trim-relative ripple $\tilde\phi=\phi-\phi_{eq}$

Hard: MAE≤0.75°, p95≤1.5°, max≤2°, p_RMS≤3°/s. Preferred: MAE≤0.25°, p95≤0.5°, p_RMS≤1°/s.

| Route | signed_mean | MAE | RMS | p95 | max | p MAE | p RMS | p p95 | pref | hard |
|-------|------------:|----:|----:|----:|----:|------:|------:|------:|:----:|:----:|
| X | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | YES | YES |
| XZ | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | YES | YES |
| H_R10 | -0.0183 | 0.4619 | 0.5538 | 1.0388 | 1.7833 | 2.3090 | 2.7611 | 5.1521 | NO | YES |

### R10 spectrum / cycle decay

- Peak f(φ̃)/f(p) = 0.7812 / 0.7812 Hz | plant f = 0.7947 Hz | match = 1 | Δf = 0.0135 Hz
- Amplitude @ plant roll (0.795 Hz): **0.7244°**
- Cycle-to-cycle decay = 0.02865 (growth = -0.02865); damp_proxy ζ ≈ 0.00695
- Spectral confidence: **high**
- Envelope peaks [°] (first/last 5): [2.99 1.55 1.34 1.33 1.22] … [0.631 0.704 0.718 0.815 0.956]
- Yaw wrap ss MAE = 0.1748° (preserved context)

## Gates summary

- Absolute max≤5° all routes: **YES**
- Trim-relative hard all routes: **YES**
- Trim-relative preferred all routes: **NO**

## Decision

- Class: **stable_but_lightly_damped**
- Next (one bounded option, not implemented): `coordinated_yaw_roll_benchmark_about_phi_eq`
- Detail: Hard trim-relative PASS / preferred FAIL. Classify stable-but-lightly-damped roll ripple about phi_eq=1.461 deg (empirical_cycle_mean_not_equilibrium). Recommend ONE coordinated yaw-roll benchmark about phi_eq (not zero). Plant f=0.795 Hz, zeta_proxy=0.0070, amp@plant=0.724 deg.

## Feedback

- Verdict: **PASS**
- phi_eq [°]: X=0.0000, XZ=0.0000, H=1.4610 (empirical_cycle_mean_not_equilibrium)
- Residual small: NO (p_dot_norm=0.01128, norm_rel=0.01999)
- H tilde MAE/p95/max [°]: 0.4619 / 1.0388 / 1.7833 | p_RMS=2.7611 deg/s
- Ripple gates: pref=NO hard=YES | amp@0.795Hz=0.7244° decay/cyc=0.0286
- Next: coordinated_yaw_roll_benchmark_about_phi_eq
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_TRIM_RELATIVE_AUDIT.png`
