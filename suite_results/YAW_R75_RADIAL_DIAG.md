# YAW_R75_RADIAL_DIAG

**TASK_ID:** YAW_RADIAL_R75_DIAG_001  
**Date:** 2026-08-05 16:47:34  
**Verdict:** DIAGNOSTIC_PASS  
**Root class:** A  

## Hypothesis

Reported `CTE_perp≈1.315 m` on R=7.5 is one of: (A) closed-path metric/projection error, (B) real guidance radial offset, (C) rudder/speed-radius authority limit. Yaw gains/FF unchanged; classify from raw time series.

## Run config

| Item | Value |
|---|---|
| Stack | production freeze (dt_c=0.0250, dt_g=0.0750, λ=0.25, Kγ=0, Tur4A r_ff=U_hκ, T25 trim) |
| R | 7.5 m |
| T_final | 120 s |
| u0 | 1.50 m/s |
| desired_speed / lookahead | 1.50 m/s / 1.25 m |
| delta_r_max | 25.00 deg (`init_parameters.m`) |
| Deterministic | YES (no RNG; no seed) |
| Endpoint mask | none (closed path) |

## Windows

- **Acquisition:** |e_psi|<=2deg for >=1.0s → t_acq = 5.83 s (samples 1…acq).
- **Settled start:** t_ss0 = acq + 0.5·T_lap = 21.62 s (T_lap_est=31.6 s from mean U_h=1.492).
- **Steady:** 3 complete geometric turns after t_ss0; turn times: 21.6 52.3 82.9 113.6 s.
- Turn boundaries from unwrap(atan2(y,x)) + 2π k (analytic circle angle).

## Metrics — acquisition

- **e_r:** signed_mean=0.1546, mean_abs=0.1546, RMS=0.1707, p95_abs=0.2351, max_abs=0.2357 (n=233)
- **e_n:** signed_mean=-0.1547, mean_abs=0.1547, RMS=0.1708, p95_abs=0.2352, max_abs=0.2358 (n=233)
- **CTE_perp report:** signed_mean=0.1971, mean_abs=0.1971, RMS=0.2156, p95_abs=0.2771, max_abs=0.2778 (n=233)

## Metrics — steady (all complete turns)

| Signal | signed mean | mean abs | RMS | p95 abs | max abs |
|---|---:|---:|---:|---:|---:|
| e_r [m] | -0.2276 | 0.2276 | 0.2276 | 0.2282 | 0.2287 |
| e_n Frenet [m] | +0.2275 | 0.2275 | 0.2275 | 0.2282 | 0.2286 |
| e_n analytic [m] | -0.2276 | 0.2276 | 0.2276 | 0.2282 | 0.2287 |
| CTE_perp report [m] | +7.1694 | 7.1694 | 8.9751 | 14.6831 | 14.7730 |
| (−e_n)−e_r outward-aligned [m] | +0.0001 | 0.0001 | 0.0001 | 0.0001 | 0.0001 |
| CTE_report − \|e_r\| [m] | +6.9418 | 6.9418 | 8.7944 | 14.4558 | 14.5454 |

- corr(e_n, e_r) = −0.9977 (left-normal inward ⇒ opposite sign); corr(−e_n, e_r) ≈ +1; sign agreement (outward) = 100.0%
- legacy `pm.mean_cte_perp` (settled t≥5, closed) = 6.059 m on this T=120 s run
- YAW_START `CTE_perp=1.315 m` was the same bug on shorter T=40 s (only ~9 s after first seam freeze)
- mean ρ = 7.272 m → mean(ρ−R) = −0.228 m (slightly **inside** circle; |e_r| still ≤0.30 m gate)

### Metric failure mode (class A mechanism)

`compute_path_following_metrics.m` detects `is_closed` for the endpoint mask, but progress update still clamps `s_prog = min(s_prog, s_total)` **without arc wrap**. After the first lap, `s_prog` freezes at the seam; `p_d` stays fixed while the vehicle continues → unsigned `CTE_perp` grows toward O(R) (here p95≈14.7 m). Analytic `e_r` and wrap-correct Frenet `e_n` stay ~0.23 m.

### Attitude / rate / sideslip (steady)

| Signal | signed mean | mean abs | RMS | p95 abs | max abs |
|---|---:|---:|---:|---:|---:|
| e_ψ [deg] | +0.3016 | 0.3065 | 0.3864 | 0.6303 | 0.6641 |
| |e_ψ| [deg] | +0.3065 | 0.3065 | 0.3864 | 0.6303 | 0.6641 |
| χ−ψ_path [deg] | -0.1477 | 0.1832 | 0.2258 | 0.3936 | 0.4529 |
| β=wrap(χ−ψ) [deg] | -1.3213 | 1.3213 | 1.3213 | 1.3364 | 1.3480 |
| β_body=atan2(v,u) [deg] | -1.2328 | 1.2328 | 1.2329 | 1.2530 | 1.2733 |
| r − U_hκ [rad/s] | +0.0059 | 0.0059 | 0.0060 | 0.0077 | 0.0088 |

- mean(r) = 0.20481 rad/s (11.734 deg/s)
- mean(U_h·κ) = 0.19890 rad/s (11.396 deg/s)
- mean(r)/mean(U_h·κ) = **1.0297**
- mean U_h = 1.491 m/s; mean κ = 0.13339 1/m; mean |R_act|=U_h/|r| = 7.281 m
- kinematic radial bias mean(|R_act|−R) = -0.219 m

### Rudder (steady)

| Item | Value |
|---|---:|
| delta_r_max | 25.00 deg (init_parameters.m: delta_r_max = deg2rad(25)) |
| signed mean | 14.28 deg |
| mean abs | 14.28 deg |
| RMS | 14.30 deg |
| p95 abs | 15.41 deg |
| max abs | 15.69 deg |
| rate RMS | 38.366 deg/s |
| saturation (|δr|≥0.95 δmax) | 0.00 % (0.00 s) |
| near-limit (|δr|≥0.90 δmax) | 0.00 % (0.00 s) |

### Per-turn steady

| Turn | t0–t1 | mean e_r | mean\|e_r\| | mean e_n | mean\|e_n\| | CTE_rep | \|eψ\| | U_h | δr | near% | r/(Uhκ) |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 21.6–52.3 | -0.228 | 0.228 | +0.228 | 0.228 | 6.505 | 0.30 | 1.490 | +14.3 | 0.0 | 1.029 |
| 2 | 52.3–82.9 | -0.227 | 0.227 | +0.227 | 0.227 | 7.503 | 0.31 | 1.492 | +14.3 | 0.0 | 1.030 |
| 3 | 82.9–113.6 | -0.228 | 0.228 | +0.228 | 0.228 | 7.501 | 0.31 | 1.491 | +14.3 | 0.0 | 1.030 |

## Classification

- Analytic |e_r| mean=0.228 <=0.30 while reported CTE_perp mean=7.169; metric/projection inflation (bias CTE-|e_r|=6.942).

**Root class: A** — **DIAGNOSTIC_PASS**

## Evidence paths

- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_R75_RADIAL_DIAG.mat`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_R75_RADIAL_DIAG_timeseries.csv`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_R75_RADIAL_DIAG_timeseries.png`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\YAW_R75_RADIAL_DIAG.md`

## Frames / signs / units

- Position NED-like: x,y horizontal [m]; path `(R cos θ, R sin θ)` CCW.
- `e_r = √((x−x_c)²+(y−y_c)²) − R` [m], + outward; (x_c,y_c)=(0,0).
- `e_n = (p−p_ref)·n_hat` [m]; `n_hat = [-t_y, t_x]` left-normal of path tangent; + to left of travel.
- CCW circle: left-normal `n_hat` points **inward**. Vehicle slightly inside ⇒ `e_r<0`, `e_n>0`, so `e_n ≈ −e_r`. Outward-aligned check uses `(−e_n)−e_r`.
- `ψ_path = atan2(t_y, t_x)` [rad]; `χ = atan2(ẏ,ẋ)` [rad]; `ψ` = body yaw [rad]; `β = wrap(χ−ψ)` [rad→deg in tables].
- `CTE_perp` report = `‖(I−ttᵀ)(p−p_d)‖` unsigned from `compute_path_following_metrics` (closed-path `s_prog` freeze).

## MATHEMATICAL_RECORD

```
MATHEMATICAL_RECORD = {
  equations: {
    e_r = sqrt((x-xc)^2+(y-yc)^2) - R,
    e_n = (p - p_ref)^T n_hat,  n_hat = [-t_y; t_x], t = path tangent at s_prog,
    CTE_perp_report = ||(I - t t^T)(p - p_d)||  (unsigned),
    chi = atan2(ydot, xdot),  beta = wrapToPi(chi - psi),
    r_ff = U_h * kappa_f (Tur4A),
    ratio = mean(r)/mean(U_h*kappa)
  },
  variables_units_frames: {
    x,y,z [m] body-to-NED path frame of sim; psi,chi,psi_path [rad] yaw about Down;
    r [rad/s] body yaw rate; U_h [m/s] inertial horizontal speed; kappa [1/m];
    delta_r [rad] rudder, + per plant convention; R=7.5[m]
  },
  assumptions: {
    circle center (0,0); flat z=0 path; closed path seam at th=0;
    geometric turn count via unwrap(atan2(y,x));
    acquisition |e_psi|<=2deg hold 1s; settled = complete turns after acq+0.5 lap;
    no sensor noise; truth state for metrics only
  },
  parameter_provenance: {
    DERIVED: e_r, e_n, chi, beta, R_act=U_h/|r|, T_lap=2*pi*R/mean(U_h),
    IDENTIFIED: mean e_r/e_n/CTE, ratio r/(Uh kappa), rudder near-limit fractions from this run,
    TUNED: none this task (gains/FF frozen),
    FIXED_FROM_CODE: delta_r_max=25deg (init_parameters), L=1.25, U_des=1.5,
      dt_c=0.025, dt_g=0.075, Kp_psi=32, Kd_psi=13, r_ff=U_h*kappa
  },
  design_reason: 'Separate metric artifact from physical radial offset without touching yaw gains.',
  rejected_alternatives: {
    yaw_gain_retune: rejected (feasible |e_psi| already ~0.3deg),
    rudder_FF: rejected (out of scope; would confound class),
    open_path_0.88_endpoint_mask: rejected (circle is closed)
  },
  evidence: {
    mat: suite_results/YAW_R75_RADIAL_DIAG.mat,
    csv: suite_results/YAW_R75_RADIAL_DIAG_timeseries.csv,
    png: suite_results/YAW_R75_RADIAL_DIAG_timeseries.png,
    prior_report_CTE: YAW_START CTE_perp=1.315m on T=40s window
  },
  conclusion: 'CLASS A: reported CTE_perp inflated by closed-path s_prog freeze; analytic |e_r|~0.23m <=0.30m gate. corr(e_n,e_r)~-1 is Frenet sign identity, not causation.',
  open_questions: {
    next: fix closed-path s_prog wrap in compute_path_following_metrics and re-score,
    residual: inward bias e_r~-0.23m is within gate; not classified B/C this task,
    note: mean rudder~14deg of 25deg max is mid-range (near-limit 0%%); not authority-limited
  }
}
```

## Next bounded task (one)

Fix **closed-path `s_prog` wrap** in `compute_path_following_metrics.m` only; re-score R=7.5 with analytic `e_r` gate ≤0.30 m (no controller change).

## Changed files

- `run_yaw_r75_radial_diag.m` (new analysis driver)
- `suite_results/YAW_R75_RADIAL_DIAG.md` (+ mat/csv/png)
- Controller/guidance/plant: **untouched**
