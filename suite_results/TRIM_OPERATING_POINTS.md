# TRIM_OPERATING_POINTS

**TASK_ID:** TRIM_OPERATING_POINTS_001
**Date:** 2026-08-05 21:01:00
**Plant RHS:** `underwater777_vehicle_dynamics`
**Source MAT:** `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\pitch_yaw_closure.mat`
**Pass tol:** normalized dynamic / rotating-frame residual ≤ 1%

## Classification rules

| Class | Meaning | LTI about x*? |
|------|---------|---------------|
| equilibrium | η̇=0 and ν̇=0 | yes (hover) |
| steady translating trim | ν̇≈0, attitude rates≈0; η̇ allowed (constant velocity) | yes (perturbation about body state) |
| rotating-frame relative equilibrium | ν̇≈0 and (φ̇,θ̇,ψ̇−Ω)≈0 | yes **only in rotating frame** |
| periodic / quasi-steady | body state not constant enough or residual > tol | **no** ordinary LTI trim |

## Scaling

```
x_scale = [10 10 10 1 1 1 1.5 0.3 0.3 0.2 0.2 0.2 ]
u_scale = [0.436 0.262 50 ]
nu_dot_scale = [1 0.3 0.3 0.2 0.2 0.2 ]  % m/s^2, rad/s^2
norm_dyn = max_i |nu_dot_i|/nu_dot_scale_i
```

## level_U15 — **PASS**

- **Class:** steady_translating_trim (level U=1.5)
- **Source window:** closure mask_steady (n=521, t=[5.00,18.00])
- **Frames/units/signs:** state NED+body SI; u*=[δr,δe,thrust] rad/rad/N; θ_phys=-θ; elev_sign=+1
- **Refined solver used:** yes

### x* = [η; ν]

```
x* = [0 0 0 0 -0.0227668 0 1.81718 0 -0.0413785 0 -3.3105e-29 0 ]
mean(window) = [20.5925 0 -0.246718 0 -0.0219958 0 1.81718 0 -0.0419881 0 -0.00175771 0 ]
std(window)  = [6.84 0 0.0212 0 0.00685 0 0.000897 0 0.00035 0 0.000434 0 ]
```

### u*

```
u* = [delta_r=0 rad (0.0000 deg), delta_e=-0.0824284 rad (-4.7228 deg), thrust=5.46329 N]
mean(window) = [0 -0.0836697 5.46111 ]
std(window)  = [0 0.00114 0.0224 ]
```

### f(x*,u*) components

```
eta_dot = [1.81765 0 0 0 -3.3105e-29 0 ]
nu_dot  = [-4.44684e-19 0 -1.00711e-16 0 2.33666e-17 0 ]
nu_dot_norm_comp = [4.447e-19 0 3.357e-16 0 1.168e-16 0 ]
norm_dyn = 3.35704e-16  (PASS if <= 0.01)
```

## XZ_slope_z0p4x — **PASS**

- **Class:** steady_translating_trim (climb z=0.4x)
- **Source window:** closure mask_steady (n=634, t=[6.18,22.00])
- **Frames/units/signs:** state NED+body SI; u*=[δr,δe,thrust] rad/rad/N; θ_phys=-θ; elev_sign=+1
- **Refined solver used:** yes

### x* = [η; ν]

```
x* = [0 0 0 0 -0.418597 0 1.75462 0 -0.066866 0 -1.12262e-27 0 ]
mean(window) = [22.8902 0 8.72501 0 -0.419529 0 1.75462 0 -0.0675203 0 -0.00170678 0 ]
std(window)  = [7.46 0 2.99 0 0.00854 0 0.00121 0 0.000449 0 0.000388 0 ]
```

### u*

```
u* = [delta_r=0 rad (0.0000 deg), delta_e=-0.0211301 rad (-1.2107 deg), thrust=7.01987 N]
mean(window) = [0 -0.0219686 7.025 ]
std(window)  = [0 0.00148 0.0302 ]
```

### f(x*,u*) components

```
eta_dot = [1.63031 0 0.652123 0 -1.12262e-27 0 ]
nu_dot  = [-2.96795e-17 0 -1.14662e-16 0 1.02042e-16 0 ]
nu_dot_norm_comp = [2.968e-17 0 3.822e-16 0 5.102e-16 0 ]
norm_dyn = 5.10208e-16  (PASS if <= 0.01)
```

## helix_R10 — **FAIL**

- **Class:** periodic_or_quasi_steady (NOT ordinary LTI trim)
- **Source window:** closure mask_steady (n=1712, t=[2.23,45.00])
- **Frames/units/signs:** state NED+body SI; u*=[δr,δe,thrust] rad/rad/N; θ_phys=-θ; elev_sign=+1
- **Refined solver used:** no (window mean better/kept)

### x* = [η; ν]

```
x* = [10 0 0 0.0251806 -0.0687065 0 1.55647 -0.0449073 -0.0497616 0.00987982 0.00301344 0.158073 ]
mean(window) = [0.550717 0.374378 1.04717 0.0251806 -0.0687065 5.3698 1.55647 -0.0449073 -0.0497616 0.00987982 0.00301344 0.158073 ]
std(window)  = [7.02 6.86 0.769 0.00966 0.0137 1.94 0.029 0.00348 0.0015 0.0472 0.00235 0.00852 ]
```

### u*

```
u* = [delta_r=0.0772008 rad (4.4233 deg), delta_e=-0.0977033 rad (-5.5980 deg), thrust=4.66791 N]
mean(window) = [0.0772008 -0.0977033 4.66791 ]
std(window)  = [0.0283 0.00235 0.194 ]
```

### f(x*,u*) components

```
eta_dot = [1.55629 -0.0436402 0.0560992 -0.000999734 -0.000967473 0.158473 ]
nu_dot  = [-0.00349454 -0.0010108 -0.000170929 -0.00225594 5.70478e-06 -0.000954485 ]
nu_dot_norm_comp = [0.003495 0.003369 0.0005698 0.01128 2.852e-05 0.004772 ]
norm_dyn = 0.0112797  (PASS if <= 0.01)
norm_rel (rotating) = 0.0199947
Omega = 0.158478 rad/s (geom Uh/R = 0.155689)
```

## Verdict summary

| Point | Class | PASS | norm_dyn | notes |
|-------|-------|:----:|---------:|-------|
| Level U=1.5 | steady_translating_trim (level U=1.5) | PASS | 3.357e-16 | LTI=PASS |
| XZ z=0.4x | steady_translating_trim (climb z=0.4x) | PASS | 5.102e-16 | LTI=PASS |
| R10 helix | periodic_or_quasi_steady (NOT ordinary LTI trim) | FAIL | dyn=0.01128 rel=0.01999 | LTI=FAIL |

## Artifacts

- `suite_results/TRIM_OPERATING_POINTS.md`
- `suite_results/TRIM_OPERATING_POINTS.mat`
- `suite_results/TRIM_OPERATING_POINTS.png`
- `suite_results/STATE_SPACE_MODEL_AUDIT.md`
- `CODEX_VERTICAL_PLAN.md` untouched; controller/plant frozen.

## Next

Linearize only LTI-eligible points (level/climb; helix only if relative-eq PASS). Do not treat helix as ordinary inertial LTI trim if classified periodic/quasi-steady.
