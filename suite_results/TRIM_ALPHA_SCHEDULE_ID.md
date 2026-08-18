# TRIM_ALPHA_SCHEDULE_ID_001 — Physics-informed trim alpha_ff schedule

**Overall verdict: PASS**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\THRUST_TRIM_U15_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_DEPTH_P_BACKOFF.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_AWARE_ROLL_COUPLING_AUDIT.mat`
- Driver: `run_trim_alpha_schedule_id.m` (one invocation)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.png`
- Production: untouched | No controller simulation/tuning
- Prior state: measured-alpha closed (3 fails). A04 clears speed/γ/CTE; roll audit **PASS/METRIC_MISMATCH** (own-eq ripple improves; frozen φ_eq invalid across speeds).
- Remaining prior concerns: alpha-LPF acquisition/settling, elevator-rate.

## Equation / coefficients / units

```
alpha_ff = c0 / max(u_ref, u_min)^2 + c_gamma * gamma_path   [rad]
clamp(alpha_ff, +/-8 deg)
c0      = +7.5013943801e-02  [rad*(m/s)^2]   provenance: DERIVED: alpha_L_hat * max(u_L,u_min)^2 from level exact-u trim
c_gamma = +4.7291247774e-02  [-]              provenance: DERIVED: (alpha_XZ_hat - c0/max(u_XZ,u_min)^2)/gamma_XZ from XZ exact-u trim
u_min   = 0.9                   provenance: FIXED=0.9
clamp   = +/-8 deg               provenance: FIXED=+/-8deg (alpha_hat scaffold)
alpha frame: alpha_hat (θ_phys−γ); replaces measured alpha_hat
```

### Trim anchors (fit only; no route labels)

| Point | u* [m/s] | γ_path [deg] | BODY α=atan2(w,u) [deg] | α_hat*=θ−γ [deg] | Treq [N] |
|-------|---------:|-------------:|------------------------:|-----------------:|---------:|
| level_exact_u15 | 1.500000 | 0.0000 | -1.9102 | +1.9102 | 3.811667 |
| XZ_exact_u15 | 1.500000 | 21.8014 | -2.9412 | +2.9412 | 5.737715 |

Cross-check recover: level err=0.000e+00 deg | XZ err=0.000e+00 deg | OK=YES

## Validation table (steady A04; R10 held-out — no fit leakage)

| Series | Truth | n | u_ref mean | γ mean° | signed mean° | MAE° | p95° | max° | sign | gate |
|--------|-------|--:|----------:|--------:|-------------:|-----:|-----:|-----:|:----:|:----:|
| X | logged -atan2(w,u) [alpha_hat frame] | 521 | 1.4996 | 0.000 | -0.0263 | 0.0263 | 0.0757 | 0.1005 | YES | YES |
| XZ | logged -atan2(w,u) [alpha_hat frame] | 744 | 1.4996 | 21.801 | -0.0607 | 0.0607 | 0.3770 | 0.4975 | YES | YES |
| R10 | theta_phys - gamma_act | 1685 | 1.2061 | 1.823 | -0.0892 | 0.0892 | 0.2663 | 0.2880 | YES | YES |

Gates: X/XZ MAE≤0.20 | R10 MAE≤0.35 & p95≤0.50 | correct sign | continuous/bounded | no R10 leakage.

## Sensitivity (±0.1 m/s on u_ref)

| Series | MAE base° | MAE@−du° | MAE@+du° | ΔMAE− | ΔMAE+ |
|--------|----------:|---------:|---------:|------:|------:|
| X | 0.0263 | 0.2566 | 0.2578 | +0.2303 | +0.2315 |
| XZ | 0.0607 | 0.2414 | 0.2922 | +0.1807 | +0.2315 |
| R10 | 0.0892 | 0.4700 | 0.5248 | +0.3807 | +0.4356 |

## Gate table

| Gate | Result | Detail |
|------|:------:|--------|
| X MAE ≤ 0.20 deg | YES | 0.0263 |
| XZ MAE ≤ 0.20 deg | YES | 0.0607 |
| R10 MAE ≤ 0.35 deg | YES | 0.0892 |
| R10 p95 ≤ 0.50 deg | YES | 0.2663 |
| Correct sign (X/XZ/R10) | YES | YES/YES/YES |
| Continuous / bounded | YES | clamp ±8 deg |
| No R10 leakage into fit | YES | level+XZ trims only |
| Trim cross-check | YES | recover α* |

## Decision

- Verdict: **PASS**
- Next: `integrate_trim_alpha_ff_replace_measured_ahat`
- Detail: PASS: X/XZ MAE=0.026/0.061<=0.20; R10 MAE=0.089<=0.35 p95=0.266<=0.50; sign OK; continuous/bounded; no R10 leakage. Next: replace measured alpha_hat with this alpha_ff schedule (no LPF); watch elevator-rate on acquisition.
- Production: untouched

## Feedback

- PASS/FAIL: **PASS**
- Equation: `alpha_ff=c0/max(u_ref,u_min)^2+c_gamma*gamma_path` [rad], clamp ±8°
- Coefficients: c0=+7.5013943801e-02 [rad*(m/s)^2] (DERIVED level); c_gamma=+4.7291247774e-02 (DERIVED XZ); u_min=0.9 FIXED
- Validation: X MAE=0.0263 signed=-0.0263 | XZ MAE=0.0607 signed=-0.0607 | R10 MAE=0.0892 p95=0.2663 max=0.2880
- Evidence: trim recover OK; R10 held-out; sens R10 ΔMAE@±0.1=+0.381/+0.436°
- Next: `integrate_trim_alpha_ff_replace_measured_ahat`
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_ALPHA_SCHEDULE_ID.png`
