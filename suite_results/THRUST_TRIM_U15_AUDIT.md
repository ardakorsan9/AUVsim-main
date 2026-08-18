# THRUST_TRIM_U15_AUDIT

**TASK_ID:** THRUST_TRIM_U15_AUDIT_001
**Date:** 2026-08-05 23:38:21
**Overall verdict:** **PASS**

## Provenance

- Read-only: `SPEED_BASELINE_AUDIT.mat`, `TRIM_OPERATING_POINTS.mat`, `underwater777_vehicle_dynamics.m`
- Driver: `run_thrust_trim_u15_audit.m` (one invocation; no production edit)
- Artifacts: `suite_results/THRUST_TRIM_U15_AUDIT.{md,mat,png}`
- Current law (from SPEED baseline): Ttrim=13.4000 N, Kp_x=25, e_tol=±0.030 m/s
- Formula: `e_ss = (Treq - Ttrim) / Kp_x`

## Prior label correction (history NOT overwritten)

TRIM_OPERATING_POINTS / LOCAL_SS "U=1.5" / "level_U15" / "climb" points have BODY u*=1.81718 / 1.75462 (not exact 1.5). Do not relabel those artifacts; this audit introduces separate exact-u=1.5 plant trims.

| Prior artifact | Labeled | Actual BODY u* | Actual T* |
|----------------|---------|---------------:|----------:|
| TRIM level_U15 | U=1.5 | 1.81718 | 5.46329 N |
| TRIM XZ_slope | U≈1.5 climb | 1.75462 | 7.01987 N |
| TRIM helix_R10 | (periodic) | 1.55647 | 4.66791 N |

## Frames / units / signs

```
State: NED η + BODY ν; u controller variable = BODY surge [m/s]
Inputs: delta_r, delta_e [rad], thrust=Xprop [N]
theta_phys = -theta; elevator_sign=+1
Climb: gamma=atan(0.4)=0.380506 rad (21.8014 deg); slope dz/dx=0.4000
```

## level_exact_u15 — **PASS**

- **Class:** steady_translating_trim
- **Provenance:** PLANT_SOLVE (u fixed = 1.500)
- **Constraint:** level: nu_dot~0, phi_dot~0, theta_dot~0, zdot~0, u=Ufix fixed, dr=0
- **Frames:** NED+BODY SI; thrust=Xprop [N]; θ_phys=-θ
- **Seed (prior OP, different u):** u_seed=1.81718, T_seed=5.46329 → exitflag=1

### x*, u*

```
x* = [0 0 0 0 -0.0333395 0 1.5 0 -0.0500278 0 -1.1447e-26 0 ]
u* = [dr=0, de=-0.116328 rad (-6.6651 deg), thrust=3.81167 N]
necessary: w=-0.0500278, theta=-0.0333395 rad (-1.9102 deg), de=-0.116328, thrust=3.81167
```

### Residuals

```
eta_dot = [1.50083 0 6.93889e-18 0 -1.1447e-26 0 ]
nu_dot  = [-2.35052e-16 0 -2.55443e-14 0 1.08936e-14 0 ]
nu_dot_norm_comp = [2.351e-16 0 8.515e-14 0 5.447e-14 0 ]
norm_dyn = 8.51477e-14  (PASS if <= 0.01)
slope_err = 6.93889e-18  att_rates(φ̇,θ̇,ψ̇)=[0 -1.14e-26 0 ]
```

## XZ_exact_u15_gamma_atan0p4 — **PASS**

- **Class:** steady_translating_trim
- **Provenance:** PLANT_SOLVE (u fixed = 1.500)
- **Constraint:** climb: nu_dot~0, att_rates~0, zdot=0.4*xdot (gamma=atan(0.4)), u=Ufix fixed, dr=0
- **Frames:** NED+BODY SI; thrust=Xprop [N]; θ_phys=-θ
- **Seed (prior OP, different u):** u_seed=1.75462, T_seed=7.01987 → exitflag=1

### x*, u*

```
x* = [0 0 0 0 -0.431841 0 1.5 0 -0.0770689 0 2.51453e-25 0 ]
u* = [dr=0, de=-0.0210529 rad (-1.2062 deg), thrust=5.73772 N]
necessary: w=-0.0770689, theta=-0.431841 rad (-24.7426 deg), de=-0.0210529, thrust=5.73772
```

### Residuals

```
eta_dot = [1.39455 0 0.557821 0 2.51453e-25 0 ]
nu_dot  = [-8.37473e-16 0 -4.06193e-14 0 1.92286e-14 0 ]
nu_dot_norm_comp = [8.375e-16 0 1.354e-13 0 9.614e-14 0 ]
norm_dyn = 1.35398e-13  (PASS if <= 0.01)
slope_err = 0  att_rates(φ̇,θ̇,ψ̇)=[0 2.51e-25 0 ]
```

## R10 helix — EMPIRICAL (exact-u UNKNOWN)

- **Class:** periodic_or_quasi_steady (NOT ordinary LTI trim)
- **Provenance:** EMPIRICAL
- **Exact-u Treq:** **UNKNOWN**
- **Reason:** Observed cycle-mean thrust balances BODY u at u_mean≠Ufix under P-only law; helix failed rotating-frame relative-eq (TRIM_OPERATING_POINTS); quadratic-drag rescale from off-trim u is not a valid exact-u equilibrium. No fabricated LTI helix trim.
- **Source window:** SPEED_BASELINE_AUDIT.mat SH + H.mask_hold (n=1712, t=[2.22,45.00])

```
u_mean=1.55648  u_std=0.02898  uref_mean=1.2072  gap_from_Ufix=+0.05648 m/s
T_cycle_mean=4.66572 N  T_std=0.1996  T_rms=4.66998
delta_e_mean=-0.097702 rad  delta_r_mean=0.0772241 rad
T_reconstruct(P-law)=4.66794 N (consistency)
prior helix u*/T*=1.55647 / 4.66791 (periodic; LTI=NO)
```

## Required thrust comparison

| Route | Treq [N] | Provenance | e_ss @ Ttrim=13.40 | |e_ss|≤0.03? |
|-------|---------:|------------|------------------:|:-----------:|
| Level (exact u=1.5) | 3.811667 | PLANT_SOLVE | -0.3835 | NO |
| XZ γ=atan(0.4) | 5.737715 | PLANT_SOLVE | -0.3065 | NO |
| R10 helix | UNKNOWN | EMPIRICAL cycle-mean=4.6657 N @ u≠1.5 | UNKNOWN | NO |

Current Ttrim=13.40 N vs plant: level ΔT=-9.588 N, XZ ΔT=-7.662 N.

## Common constant Ttrim feasibility

- dT_tol = e_tol × Kp_x = 0.0300 × 25 = **0.7500 N**
- Level/XZ Treq span = **1.9260 N** (need ≤ 1.5000 N for a common band)
- Level+XZ common band: **empty** (span too large)
- All-routes certifiable (incl. R10 exact-u): **NO**
- **Common Ttrim feasible:** **NO**

### Decision

Level/XZ Treq span=1.9260 N exceeds 2*dT_tol=1.5000 N (dT_tol=e_tol*Kpx=0.7500). No constant Ttrim meets |e_ss|<=0.030 on both known routes; R10 exact-u also UNKNOWN.

**Recommended next architecture (exactly one):** `speed-reference drag feedforward + anti-windup PI`

Justification: Plant-required thrust at exact BODY u=1.5 differs by route (level=3.812 vs XZ=5.738 N). Constant Ttrim cannot null both within ±0.030 m/s under P-only Kpx=25. Recommend speed-reference drag feedforward (T_ff(u_ref)) plus anti-windup PI to absorb path-dependent residual (climb restoring / helix cycle-mean) — not a static route schedule alone, which fails under Uref steps and continuous envelopes.

No Kp change. No production implementation in this task.

## Feedback

- PASS/FAIL: **PASS**
- Level: u*=1.5 Treq=3.81167 N de=-6.6651 deg θ=-1.9102 deg w=-0.050028 norm_dyn=8.51e-14 (PASS)
- XZ: u*=1.5 Treq=5.73772 N de=-1.2062 deg θ=-24.7426 deg w=-0.077069 norm_dyn=1.35e-13 (PASS)
- R10: EMPIRICAL T_cycle=4.6657 N @ u_mean=1.5565; exact-u=UNKNOWN
- Common trim: NO
- Files: `suite_results/THRUST_TRIM_U15_AUDIT.md` `.mat` `.png`; append `STATE_SPACE_MODEL_AUDIT.md`
- Next: `implement_speed_drag_ff_plus_aw_PI`
