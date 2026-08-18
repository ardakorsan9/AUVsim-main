# DEPTH_GAMMA_COUPLED_PLANT_ID_001 — Depth/γ coupled sagittal plant ID

**Gate-1 verdict: PARTIAL**  
**Stamp:** 2026-08-08 01:45:23  
**Next exact task:** `depth_gamma_speed_scheduled_id_extension`

## Provenance

- Sources (exactly 3):
  1. `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.mat` (IDENTIFIED A,B,x0,u0; jac PASS)
  2. `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.mat` (IDENTIFIED A,B,x0,u0; jac PASS)
  3. `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SS_VALIDATION.mat` (NL vs LTI traj; level/climb PASS)
- Driver: `run_depth_gamma_coupled_plant_id.m` (isolated; production untouched)
- Plant RHS underlying SS: `underwater777_vehicle_dynamics` (IMPLEMENTED; not re-edited)
- No controller/guidance/plant edits; no retune; CODEX_VERTICAL_PLAN untouched
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_COUPLED_PLANT_ID.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_COUPLED_PLANT_ID.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_COUPLED_PLANT_ID.png`

## Evidence labels

| Item | Label |
|---|---|
| Local A,B (level/climb) | IDENTIFIED |
| theta_phys=-theta | IMPLEMENTED |
| alpha=atan2(w,u) + analytic linearization | DERIVED |
| gamma=theta_phys+alpha | DERIVED |
| ID tolerances (nrmse/corr) | ASSUMED (declared) |
| Hydro coeff provenance | TO_BE_IDENTIFIED (no invented values) |
| Speed-scheduled family U=1.0/1.5/2.0 | TO_BE_IDENTIFIED |

## BODY / NED signs and units

- Frame: NED inertial eta + BODY nu; Euler ZYX
- NED z positive down [m]; depth ≡ z (IMPLEMENTED plant/controller contract)
- Euler theta [rad] BODY pitch in plant state; theta_phys = -theta (IMPLEMENTED)
- BODY alpha = atan2(w,u) [rad] (DERIVED kinematic AoA)
- gamma = theta_phys + alpha [rad] (DERIVED; equals NED flight-path when phi=v=0)
- BODY surge u, heave w [m/s]; w>0 heave +z_body
- BODY pitch rate q [rad/s]
- elevator [rad]; delta_e>0 → +Z/+M via Zuuds/Muuds*u^2 (IMPLEMENTED plant signs)
- thrust = Xprop [N] (IMPLEMENTED)
- Hydro numeric coeffs not re-identified here; A,B are IDENTIFIED local FD Jacobians of underwater777_vehicle_dynamics at documented trims. No invented hydro provenance.

## Sagittal coupled model

States `x_r = [z, θ, u, w, q]^T` (sufficient for z,u,w,theta,q).  
Inputs `u_r = [δ_e, thrust]^T`.  
Outputs `y = [z, θ_phys, α, γ, w, q]^T` with

```
θ_phys = -θ
α = atan2(w,u)
δα = (∂α/∂u)δu + (∂α/∂w)δw,  ∂α/∂u=-w/(u²+w²), ∂α/∂w=u/(u²+w²)  (at trim)
γ = θ_phys + α
```

### Operating point: LEVEL

```
x* = [0           0           0           0  -0.0227668           0     1.81718           0  -0.0413785           0 -3.3105e-29           0]
u* = [0 -0.0824284    5.46329]
trim: u=1.81718 w=-0.0413785 θ=-0.0227668 θ_phys=0.0227668 α=-0.0227668 γ=0
dα/du=0.0125243  dα/dw=0.550019
```

A_sag (5×5) [z θ u w q]:
```
  0.00000000e+00  -1.81764940e+00   2.27648609e-02   9.99740847e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
  0.00000000e+00   1.70085338e-01  -1.85812687e-01  -1.05250393e-01   9.76276231e-02
  0.00000000e+00   1.95769584e-02   5.81812142e-02  -1.10355355e+00   7.23610071e-01
  0.00000000e+00  -7.34439448e-01   1.02069387e-01   5.53054544e+00  -6.08293049e-01
```

B_sag (5×2) [δe thrust]:
```
  0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00
  4.46502561e-02   3.12736081e-02
 -4.10033133e-01   6.67559000e-05
 -2.34621710e+00  -2.30327653e-03
```

C_y (6×5):
```
  1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   1.25243410e-02   5.50018529e-01   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   1.25243410e-02   5.50018529e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
```

Full poles (Re↓):
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
Reduced sagittal poles:
```
 1: +7.350478e-01 +0.000000e+00i
 2: +2.410699e-01 +0.000000e+00i
 3: +0.000000e+00 +0.000000e+00i
 4: -1.258984e-01 +0.000000e+00i
 5: -2.747879e+00 +0.000000e+00i
```
Unstable full: +1.242+0i; +0.735+0i; +0.2411+0i
Unstable reduced: +0.735+0i; +0.2411+0i

| Check | Rank | Cond(σmax/σmin) | σmin | Tol |
|---|---:|---:|---:|---:|
| Ctrl (scaled) | 5/5 | 442.7 | 0.08217 | 7.105e-14 |
| Obs y-map (scaled) | 5/5 | 214.5 | 0.6743 | 8.527e-13 |
| Obs state I5 (scaled) | 5/5 | 144.5 | 1 | 7.105e-13 |

Finite-horizon gains Gfh=y(T=0.600s) unit step (DERIVED):
```
  4.96462449e-02   2.55304968e-04
  4.74107466e-01   2.36260934e-04
 -2.54343913e-01   3.04748206e-04
  2.19763553e-01   5.41009140e-04
 -4.61913621e-01   1.50534747e-04
 -1.69877623e+00  -4.79943557e-04
```
Ridge-DC Gdc (ASSUMED regularizer):
```
  2.49233186e+05  -3.59861261e+03
  1.45723183e+01  -2.14731582e-01
 -8.60477818e-01   1.67499136e-02
  1.37118405e+01  -1.97981669e-01
 -1.28286782e+00   2.24386103e-02
 -1.45723183e-03   2.14731582e-05
```
Gfh = reduced LTI step response at T=0.600s (DERIVED); Gdc = C(-(A-1e-04 I))^{-1}B ridge DC (ASSUMED regularizer; z-integrator)

Elevator/thrust cross-coupling (|Gfh| ratio δe/thrust):

| Out | |G_de| | |G_th| | ratio | elev-dom? |
|---|---:|---:|---:|:---:|
| z | 0.04965 | 0.0002553 | 194.5 | Y |
| theta_phys | 0.4741 | 0.0002363 | 2007 | Y |
| alpha | 0.2543 | 0.0003047 | 834.6 | Y |
| gamma | 0.2198 | 0.000541 | 406.2 | Y |
| w | 0.4619 | 0.0001505 | 3068 | Y |
| q | 1.699 | 0.0004799 | 3540 | Y |

### Operating point: CLIMB

```
x* = [0            0            0            0    -0.418597            0      1.75462            0    -0.066866            0 -1.12262e-27            0]
u* = [0 -0.0211301    7.01987]
trim: u=1.75462 w=-0.066866 θ=-0.418597 θ_phys=0.418597 α=-0.0380901 γ=0.380506
dα/du=0.0216875  dα/dw=0.569098
```

A_sag (5×5) [z θ u w q]:
```
  0.00000000e+00  -1.63030627e+00   4.06478532e-01   9.13660333e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
  0.00000000e+00   1.55311779e-01  -1.74968196e-01  -1.02491953e-01   1.50274161e-01
  0.00000000e+00  -1.12632455e-02   4.33698519e-02  -1.17276450e+00   6.98761321e-01
  0.00000000e+00  -6.64437817e-01  -1.35154882e-01   5.38559892e+00  -5.89502566e-01
```

B_sag (5×2) [δe thrust]:
```
  0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00
  4.16289044e-02   3.12736081e-02
 -3.82287396e-01   6.67559000e-05
 -2.18745548e+00  -2.30327653e-03
```

C_y (6×5):
```
  1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   2.16874834e-02   5.69097504e-01   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   2.16874834e-02   5.69097504e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
```

Full poles (Re↓):
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
Reduced sagittal poles:
```
 1: +4.870644e-01 +2.493178e-01i
 2: +4.870644e-01 -2.493178e-01i
 3: +0.000000e+00 +0.000000e+00i
 4: -1.685441e-01 +0.000000e+00i
 5: -2.742820e+00 +0.000000e+00i
```
Unstable full: +1.235+0i; +0.4871+0.2493i; +0.4871-0.2493i
Unstable reduced: +0.4871+0.2493i; +0.4871-0.2493i

| Check | Rank | Cond(σmax/σmin) | σmin | Tol |
|---|---:|---:|---:|---:|
| Ctrl (scaled) | 5/5 | 390.3 | 0.07871 | 3.553e-14 |
| Obs y-map (scaled) | 5/5 | 604.6 | 0.2332 | 8.527e-13 |
| Obs state I5 (scaled) | 5/5 | 140.8 | 1 | 7.105e-13 |

Finite-horizon gains Gfh=y(T=0.600s) unit step (DERIVED):
```
  4.02056202e-02   2.35318807e-03
  4.39146935e-01   4.98223809e-04
 -2.35255207e-01   3.48112055e-04
  2.03891728e-01   8.46335863e-04
 -4.11763105e-01  -6.38440794e-05
 -1.56457792e+00  -1.79440629e-03
```
Ridge-DC Gdc (ASSUMED regularizer):
```
  7.32928291e+04   5.95521859e+02
  5.93360168e+00  -1.39253128e-02
 -3.56919347e-01   7.94703204e-03
  5.57668233e+00  -5.97828072e-03
 -4.45546604e-01   6.83841862e-03
 -5.93360168e-04   1.39253128e-06
```
Gfh = reduced LTI step response at T=0.600s (DERIVED); Gdc = C(-(A-1e-04 I))^{-1}B ridge DC (ASSUMED regularizer; z-integrator)

Elevator/thrust cross-coupling (|Gfh| ratio δe/thrust):

| Out | |G_de| | |G_th| | ratio | elev-dom? |
|---|---:|---:|---:|:---:|
| z | 0.04021 | 0.002353 | 17.09 | Y |
| theta_phys | 0.4391 | 0.0004982 | 881.4 | Y |
| alpha | 0.2353 | 0.0003481 | 675.8 | Y |
| gamma | 0.2039 | 0.0008463 | 240.9 | Y |
| w | 0.4118 | 6.384e-05 | 6450 | Y |
| q | 1.565 | 0.001794 | 871.9 | Y |

## Declared ID tolerances

| Quantity | Value | Label |
|---|---:|---|
| nrmse_rel max | 0.20 | ASSUMED |
| corr min | 0.95 | ASSUMED |
| energy floor (scale-norm) | 1.0e-04 | ASSUMED |
| horizon T | 0.600 s | IDENTIFIED (SS_VALIDATION) |

NRMSE_rel<=0.20 and corr>=0.95 on energetic sagittal channels; near-zero energy excluded; horizon = SS_VALIDATION T_end

## SS_VALIDATION transform compare (independent)

Both NL and LTI state trajectories transformed with the same nonlinear maps; linear C·δx_r also reported. Cases: elev_pulse + theta_ic (sagittal); rudder excluded. Overall traj PASS: **YES** (4/4).

| Trim | Channel | PASS | z | θ_phys | α | γ | w | q |
|---|---|:---:|---:|---:|---:|---:|---:|---:|
| level | elev_pulse | PASS | n0 | 0.000382 / 1.000 | 0.000109 / 1.000 | 0.000273 / 1.000 | 0.000666 / 1.000 | 0.0109 / 1.000 |
| level | theta_ic | PASS | 2.16e-06 / 1.000 | 5.75e-05 / 1.000 | 2.12e-05 / 1.000 | 3.69e-05 / 1.000 | 0.000129 / 1.000 | 0.00213 / 1.000 |
| climb | elev_pulse | PASS | n0 | 0.00033 / 1.000 | 9.22e-05 / 1.000 | 0.000238 / 1.000 | 0.000544 / 1.000 | 0.00941 / 1.000 |
| climb | theta_ic | PASS | 1.79e-05 / 1.000 | 3.63e-05 / 1.000 | 1.5e-05 / 1.000 | 2.26e-05 / 1.000 | 8.68e-05 / 1.000 | 0.00163 / 1.000 |

Cells: `nrmse_rel / corr` (n0 = near-zero excluded).

## Speed-family / Gate-1 honesty

- Level BODY u* = 1.81718 m/s; climb BODY u* = 1.75462 m/s
- Class: level/climb U=1.5 family (BODY u*≈1.82/1.75; not exact 1.5)
- Bounded U={1.0,1.5,2.0} family in sources: **NO**
- Only LOCAL_SS_LEVEL + LOCAL_SS_CLIMB (+ SS_VALIDATION) available; both are the TRIM U=1.5-class translating points. No U=1.0 or U=2.0 validated A,B in sources → Gate-1 full PASS blocked; verdict PARTIAL.
- Therefore Gate-1 full PASS is **not** claimed; verdict = **PARTIAL**.

## Next

- Exact next task: `depth_gamma_speed_scheduled_id_extension`
- Extend coupled sagittal ID to U={1.0,1.5,2.0} level+climb (bounded LTI/LPV family); no production retune.
