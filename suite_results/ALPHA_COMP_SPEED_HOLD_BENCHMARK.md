# ALPHA_COMP_SPEED_HOLD_001 — Alpha compensation + speed PI+FF hold benchmark

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SPEED_PI_FF_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PITCH_FLIGHTPATH_SEMANTICS_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\guidance_law.m`
- Driver: `run_alpha_comp_speed_hold_benchmark.m` (one invocation; production untouched)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.png`
- Seed: 0

## Exact toggles / equations / frames / units

```
Toggles: K_gamma=0; enable_alpha_hat=true (existing scaffold UNCHANGED)
Speed:   identical SPEED_PI_FF candidate
  Tff = kD * u_ref_eff * |u_ref_eff|     [N], BODY u [m/s]
  Tunsat = Tff + Kp*e + I; T=sat(Tunsat); e=u_ref_eff-u
  I += Ki*e*dt + Kaw*(T-Tunsat)*dt  (freeze e-int if sat against e); I(0)=0
  kD=1.6940741214  Kp=25  Ki=13.83617834  Kaw=0.55344713
Alpha:   alpha_eff = theta_phys - gamma_actual   [rad]
         (= -atan2(w,u) when phi=0,v=0 exact identity)
         alpha_hat = 0.98*alpha_hat + 0.02*alpha_eff; clamp +/-8 deg
         pitch_raw = gamma_path + K_gamma*e_gamma + depth_corr + alpha_hat
Frames:  gamma_act = atan2(V_D, Uh) NED; alpha BODY=atan2(w,u)
         X/XZ: gamma = theta_phys + atan2(w,u) EXACT (phi=v=0)
         R10: BODY alpha APPROX (monitor resid=gamma_act-(theta+alpha))
Units:   angles rad internally / deg in tables; CTE m; u m/s; T N
```

## Before / after (P=production, U=uncorrected speed, A=alpha_comp)

| Route | uMAE P/U/A | uP95 A | γMAE° P/U/A | γΔ% U→A | CTE P/U/A | CTEΔ% | yaw° P→A | tildeRMS P→A | pRMS P→A |
|-------|-----------:|-------:|------------:|--------:|----------:|------:|---------:|-------------:|---------:|
| X | 0.3176/0.0008/0.0009 | 0.0035 | 0.331/0.394/0.609 | -54.6 | 0.2467/0.2903/0.0747 | +74.3 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| XZ | 0.2550/0.0010/0.0031 | 0.0212 | 0.418/0.669/1.011 | -51.2 | 0.4002/0.5582/0.1806 | +67.6 | 0.0000→0.0000 | 0.0000→0.0000 | 0.0000→0.0000 |
| R10 | 0.3494/0.0012/0.0043 | 0.0291 | 0.657/1.028/0.653 | +36.5 | 0.2690/0.4012/0.2517 | +37.3 | 0.1747→0.1351 | 0.4376→0.6657 | 2.1700→1.5466 |

## Actuator / saturation / chatter (steady)

| Route | deSat% P→A | drSat% P→A | thrSat% A | deRate A/P | acq deRate A/P | I chatter | ahat vs -α MAE° |
|-------|-----------:|-----------:|----------:|-----------:|---------------:|----------:|----------------:|
| X | 0.00→0.00 | 0.00→0.00 | 0.00 | 0.0034/0.0035 | 0.1205/0.1273 | YES | 0.157 |
| XZ | 0.00→0.00 | 0.00→0.00 | 0.00 | 0.0076/0.0040 | 0.1135/0.0813 | YES | 0.266 |
| R10 | 0.00→0.00 | 0.00→0.00 | 0.00 | 0.0067/0.0040 | 0.1238/0.1369 | YES | 0.211 |

## Helix BODY-alpha approximation

- X/XZ: kinematic identity exact (resid RMS ≈ 0).
- R10: alpha=atan2(w,u) ignores v/roll; resid RMS P/U/A = 0.0434 / 0.0267 / 0.0270 deg.

## Gate table

| Gate | Result | Detail |
|------|:------:|--------|
| Comp u MAE≤0.07 p95≤0.10 | YES | X=YES XZ=YES H=YES |
| γ MAE improve ≥10% vs U | NO | X=-54.6% XZ=-51.2% H=+36.5% |
| CTE improve ≥10% vs U | YES | X=+74.3% XZ=+67.6% H=+37.3% |
| Yaw/roll ≤2% vs production | NO | |
| Actuator ≤2% vs production | NO | |
| No sat/chatter/transient reg | YES | |

## Decision

- Verdict: **FAIL**
- Next: `reject_alpha_hat_or_retune_guidance_base`
- Detail: FAIL leave production unchanged. Fail: gamma MAE <10% improve, yaw/roll >2% vs prod, actuator >2% vs prod. Scaffold alpha_hat ON with speed PI+FF did not clear gates; consider trim-scheduled alpha or helix roll/v correction next.
- Production: untouched

## Feedback

- PASS/FAIL: **FAIL**
- Toggles: K_gamma=0, enable_alpha_hat=true; speed kD=1.69407412 Kp=25 Ki=13.836178 Kaw=0.553447
- γMAE° U→A: X 0.394→0.609 | XZ 0.669→1.011 | R10 1.028→0.653
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ALPHA_COMP_SPEED_HOLD_BENCHMARK.png`
- Next: `reject_alpha_hat_or_retune_guidance_base`
