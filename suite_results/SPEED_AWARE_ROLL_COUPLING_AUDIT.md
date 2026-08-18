# SPEED_AWARE_ROLL_COUPLING_AUDIT_001 — Speed-aware R10 roll/yaw residual attribution

**Overall verdict: PASS** | class: **METRIC_MISMATCH**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_PRODUCTION_CLOSURE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\underwater777_vehicle_dynamics.m`
- Driver: `run_speed_aware_roll_coupling_audit.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.png`
- Production: untouched | No gain tuning
- Helix caveat: **empirical / time-varying — NOT an LTI trim**

## Equations / units / frame

```
tilde_frozen = phi - phi_eq_frozen   [phi_eq_frozen=1.4610 deg from ROLL/ALPHA freeze]
tilde_own    = phi - phi_eq_own      [own = steady mean (report med/robust too)]
ripple       = phi - mean(phi_ss)    [detrended]
K roll moment [N*m] =
  (yg*W-yb*B)*cos(th)*cos(phi) - (zg*W-zb*B)*cos(th)*sin(phi)
  + Kpp*p*|p| - (Izz-Iyy)*q*r - (m*zg)*w*p + (m*zg)*u*r
  Kpp=-0.13 (neg => damping) | m*zg=0.6094
Rudder authority: Y = Yuudr*u^2*dr [N]; N = Nuudr*u^2*dr [N*m]
  Yuudr=9.64  Nuudr=6.15  (scales as u^2; no direct K(dr))
dr_cmd = sat(dr_yaw + g_ac*(-Kp_roll*p)); BODY p; g_ac in [0,1]
```

## Speed / bank equilibrium (R10 steady)

| Case | u_mean | u_ref | Uh | phi mean | med | robust turn | estimator | valid_ss |
|------|-------:|------:|---:|---------:|----:|------------:|-----------|---------:|
| P prod-speed | 1.5565 | 1.2072 | 1.5568 | 1.4420 | 1.4277 | 1.4446 | steady_mean | 100.0% |
| A04 u-hold | 1.2023 | 1.2061 | 1.2038 | 0.8600 | 0.8646 | 0.8600 | steady_mean | 100.0% |
| ROLL closure | 1.5565 | — | 1.5565 | 1.4420 | 1.4277 | 1.4446 | steady_mean | 100.0% |

u_A04/u_P = 0.7724 | (u_A04/u_P)^2 = 0.5967 | Δphi_eq_mean = -0.5820 deg

## Mean / ripple decomposition (own equilibrium)

| Metric | P | A04 | Δ% |
|--------|--:|----:|---:|
| frozen tilde RMS [deg] | 0.4376 | 0.6642 | +51.79 |
| own-eq tilde MAE [deg] | 0.3407 | 0.2006 | -41.12 |
| own-eq tilde RMS [deg] | 0.4372 | 0.2827 | -35.34 |
| own-eq tilde p95 [deg] | 0.8885 | 0.6272 | -29.41 |
| detrended ripple RMS [deg] | 0.4372 | 0.2827 | -35.34 |
| pRMS [deg/s] | 2.1700 | 1.4980 | -30.97 |
| yaw MAE [deg] | 0.2634 | 0.1885 | -28.45 |
| p spectrum peak [Hz] | 0.781 | 0.781 | — |

Frozen-metric bias on A04: |phi_mean_A04 - frozen| = 0.6010 deg

## Rudder / g_ac / authority (u^2)

| Qty | P | A04 |
|-----|--:|----:|
| dr_yaw RMS [deg] | 8.2238 | 7.1218 |
| dr_damp RMS [deg] | 1.2288 | 0.8570 |
| g_ac mean | 0.9671 | 0.9796 |
| dr rate RMS [deg/s] | 38.4817 | 37.3768 |
| de rate RMS [rad/s] (pitch ch.) | 0.00404 | 0.00568 |
| u^2 mean | 2.4235 | 1.4458 |
| G_N = Nuudr*u^2 [N·m/rad] | 14.9044 | 8.8918 |
| authority ratio | — | 0.5966 |

## Roll-moment terms (steady mean / RMS) [N·m]

| Term | P mean | A04 mean | P RMS | A04 RMS |
|------|-------:|---------:|------:|--------:|
| K_grav | -1.5007e-01 | -8.9364e-02 | 1.5682e-01 | 9.4074e-02 |
| Kpp*p|p| | -6.8236e-05 | -5.0559e-05 | 3.1078e-04 | 1.7082e-04 |
| -(Izz-Iyy)qr | 0.0000e+00 | 0.0000e+00 | 0.0000e+00 | 0.0000e+00 |
| -(m zg)wp | 3.1116e-04 | 4.4497e-04 | 1.1292e-03 | 1.0401e-03 |
| +(m zg)ur | 1.5004e-01 | 8.9381e-02 | 1.5043e-01 | 8.9541e-02 |
| K_sum | 2.1433e-04 | 4.1152e-04 | 4.3879e-02 | 2.9062e-02 |

## Gate table (classification support)

| Gate | Result | Detail |
|------|:------:|--------|
| valid steady samples >=95% | YES | P=100.0% A04=100.0% |
| mean/ripple decomp consistent | YES | frozen bias=0.601 deg |
| own-eq ripple holds/improves | YES | d_own=-35.34% d_rip=-35.34% |
| pRMS holds/improves | YES | d_p=-30.97% |
| rudder actuator holds | YES | dr_rate/damp |
| frozen metric worsens | YES | d_frozen=+51.79% |
| term signs/units OK | YES | Kpp<0, u^2 auth |
| METRIC_MISMATCH | YES | |
| SPEED_DAMPING_SHORTFALL | NO | |

## Decision

- Verdict: **PASS**
- Class: **METRIC_MISMATCH**
- Next: `speed_scheduled_phi_eq_or_roll_metric`
- Detail: PASS METRIC_MISMATCH: frozen phi_eq=1.461 deg (prod-speed bank) makes A04 tildeRMS 0.438->0.664 look worse, but own-eq/detrend ripple 0.437->0.283 and pRMS 2.170->1.498 improve. Bank mean 1.442->0.860 deg tracks u 1.556->1.202 (u^2 auth ratio=0.597). Next: schedule phi_eq or report own-eq tilde; do not retune roll for false regression.
- Production: untouched

## Feedback

- PASS/FAIL: **PASS**
- Class: **METRIC_MISMATCH**
- Evidence: frozen tilde 0.4376->0.6642 vs own-eq 0.4372->0.2827; pRMS 2.1700->1.4980; phi_eq 1.442->0.860 deg; u 1.556->1.202; u^2 auth ratio=0.597
- Next: `speed_scheduled_phi_eq_or_roll_metric`
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.png`
