# AUV_VISUAL_EVIDENCE_PACK_001

**Date:** 2026-08-06 15:23:11  
**Pack verdict:** **PASS**  
**Panels PASS/FAIL/NA:** 6/0/0  

## Provenance (research-log resolved)

| Role | Artifact |
|------|----------|
| Research log | `suite_results/PITCH_CONTROL_RESEARCH_LOG.md` |
| Production X/XZ/R10 | `suite_results/PITCH_YAW_CLOSURE.mat` |
| Accepted roll damping | `suite_results/ROLL_PRODUCTION_CLOSURE.mat` |
| Guidance mission | `suite_results/GUIDANCE_MISSION_BASELINE.mat` |
| CUSUM fault validation | `suite_results/RUDDER_CUSUM_DETECTOR.mat` |

Roll damping PASS not indexed in research log; ROLL_PRODUCTION_CLOSURE.mat used (base vs prod Kp_roll=0.605072). Full X/XZ time series taken from ROLL (PITCH_YAW mX/mXZ lack vp/vel/ori).

- Nonlinear rerun: **NO**  
- Production edited: **NO**  
- CODEX_VERTICAL_PLAN: **untouched**  

## Panel index

| # | Name | Scenario | Units | Source | Window | Verdict | PNG |
|---|------|----------|-------|--------|--------|---------|-----|
| 1 | path_cte | R10 helix | 3D ref/actual + CTE [m] + depth err [m] | `ROLL_PRODUCTION_CLOSURE.mat (candidate.SH) + PITCH_YAW pathH` | ss t>=5 & s<0.88 s_tot (win=persistent) | **PASS** | `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\AUV_VISUAL_EVIDENCE_PACK_01_path_cte.png` |
| 2 | attitude | R10 helix | theta_ref/theta_phys, psi_ref/psi, phi [deg] | `ROLL_PRODUCTION_CLOSURE.mat (candidate.SH)` | transient=~ss; steady=persistent | **PASS** | `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\AUV_VISUAL_EVIDENCE_PACK_02_attitude.png` |
| 3 | kinematics | R10 helix | U, alpha=atan2(w,u), theta, gamma_act/path + identity resid [deg] | `ROLL_PRODUCTION_CLOSURE.mat (candidate.SH)` | steady mask; identity_ssRMS=0.043 deg | **PASS** | `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\AUV_VISUAL_EVIDENCE_PACK_03_kinematics.png` |
| 4 | actuators | R10 helix | de/dr [deg], rate lim \pm40 deg/s, mag \pm15/\pm25, sat%, chatter, PSD@13.33Hz | `ROLL_PRODUCTION_CLOSURE.mat (candidate.SH)` | full + steady window | **PASS** | `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\AUV_VISUAL_EVIDENCE_PACK_04_actuators.png` |
| 5 | rates_roll | R10 (+X quiet check) | p,q,r [deg/s] + p_RMS base vs accepted roll-damp | `ROLL_PRODUCTION_CLOSURE.mat (baseline.SH vs candidate.SH)` | ss; improve=21.4% (gate >=10% from ROLL closure) | **PASS** | `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\AUV_VISUAL_EVIDENCE_PACK_05_rates_roll.png` |
| 6 | cusum_fault | R10 U=1.50 eta=0.75 | B2 residual, CUSUM q/h, fault time, latch, delay, FA | `RUDDER_CUSUM_DETECTOR.mat` | t_fault=19.60s t_alarm=20.78s delay=1.175s | **PASS** | `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\AUV_VISUAL_EVIDENCE_PACK_06_cusum_fault.png` |

Overview: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\AUV_VISUAL_EVIDENCE_PACK_00_overview.png`

## Highlights

- Kinematic identity resid ssRMS=**0.043** deg (eq: `resid = gamma_act - (theta_phys + alpha)`)
- Roll damp pRMS R10: 2.7611 → 2.1700 deg/s (21.4%)
- CUSUM example: U=1.50 η=0.75 delay=1.175s FA_agg=0.0000% latched=1
- BODY/NED: θ_phys=-θ_Euler; α=atan2(w,u) BODY; γ_act=atan2(V_D,U_h) from R'[u;v;w]

## Frame / sign documentation

```
NED: x North, y East, z Down (+)
BODY: u surge, v sway, w heave (w + when level aligns NED-down)
theta_phys = -Euler_theta
alpha      = atan2(w, u)                         [BODY]
V_NED      = R_bn' * [u;v;w]
gamma_act  = atan2(V_D, hypot(V_N,V_E))           [NED]
gamma_path = atan2(t_hat_z, ||t_hat_xy||)         [path]
resid      = gamma_act - (theta_phys + alpha)     [tested, not assumed]
```

## Actuator limits (exact)

| Channel | Magnitude | Rate |
|---------|-----------|------|
| δe | ±15 deg | ±40 deg/s |
| δr | ±25 deg | ±40 deg/s |
| PSD marker | — | 13.33 Hz = 1/dt_guidance |

## Next

realism_gap_audit_only_after_pack_PASS
