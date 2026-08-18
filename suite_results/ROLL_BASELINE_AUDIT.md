# ROLL_BASELINE_AUDIT_001 — Roll baseline audit

**Overall verdict: FAIL**

## Provenance

- Read-only: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\pitch_yaw_closure.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.mat`
- Driver: `run_roll_baseline_audit.m` (one invocation; no controller/plant/guidance edit)
- Diagnostic re-sim of accepted closure: **YES** (MAT lacked phi/p/rudder on X/XZ logs)
- Frozen stack: climb-FF k_gamma=0.1320695001; X λ=0.25; XZ λ=0; helix λ=0.25; seed=0
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.png`

## Units / frame

- Frame: NED eta + BODY nu; Euler ZYX; lateral [y phi psi v p r] w/ [dr]
- phi [rad] Euler roll, p [rad/s] body roll rate, delta_r [rad]; reports in deg / deg/s
- phi_ref = 0; e_phi = 0 - phi; e_psi = wrapToPi(psi_ref - psi)
- Windows: X first_hold (pitch); XZ/helix persistent pitch; report acq + steady

## Plant roll mode (LOCAL_SS)

| Op | λ | f [Hz] | ζ | T [s] |
|----|---|-------:|--:|------:|
| Level | -2.1388e-02±j4.9934 | 0.7947 | 0.0043 | 1.258 |
| Climb | -1.8914e-02±j4.7799 | 0.7607 | 0.0040 | 1.315 |

Lateral controllable; cond(Qc_s)~6.4e5 (CTRL_OBS). Controller has **no** roll feedback (rudder = yaw PD only).

## Closure channel inventory

| Route | phi | p | delta_r | r | ok |
|-------|:---:|:-:|:-------:|:-:|:--:|
| X | 0 | 0 | 0 | 0 | 0 |
| XZ | 0 | 0 | 0 | 0 | 0 |
| H | 1 | 1 | 1 | 1 | 1 |

## Roll metrics (phi ref=0)

### X

Settle (pitch window)=2.65 s | win=first_hold

| Window | φ signed_mean [°] | φ MAE | φ RMS | φ p95 | φ max | p MAE [°/s] | p RMS | p p95 | p max |
|--------|------------------:|------:|------:|------:|------:|------------:|------:|------:|------:|
| acq | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 |
| steady | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 |

Rudder: acq RMS=0.000° rateRMS=0.000°/s sat=0.00% | ss RMS=0.000° rateRMS=0.000°/s sat=0.00%
Yaw wrap ss: MAE=0.0000 RMS=0.0000 p95=0.0000 max=0.0000
Spectrum ss: φ peak f=0.078 Hz | p peak f=0.078 Hz | damp_proxy φ/p=2.0000/2.0000 | vs plant Δf=0.717 Hz match=0
Coupling ss: corr(φ,dr)=NaN corr(p,dr)=NaN corr(φ,r)=NaN corr(p,r)=NaN
Phase/lag: φ↔dr 0.0° / -2.000s | p↔dr 0.0° / -2.000s | φ↔r 0.0° | p↔r 0.0°
Transient ratio RMS_acq/RMS_ss: φ=0.00 p=0.00

### XZ

Settle (pitch window)=6.18 s | win=persistent

| Window | φ signed_mean [°] | φ MAE | φ RMS | φ p95 | φ max | p MAE [°/s] | p RMS | p p95 | p max |
|--------|------------------:|------:|------:|------:|------:|------------:|------:|------:|------:|
| acq | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 |
| steady | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 |

Rudder: acq RMS=0.000° rateRMS=0.000°/s sat=0.00% | ss RMS=0.000° rateRMS=0.000°/s sat=0.00%
Yaw wrap ss: MAE=0.0000 RMS=0.0000 p95=0.0000 max=0.0000
Spectrum ss: φ peak f=0.078 Hz | p peak f=0.078 Hz | damp_proxy φ/p=2.0000/2.0000 | vs plant Δf=0.683 Hz match=0
Coupling ss: corr(φ,dr)=NaN corr(p,dr)=NaN corr(φ,r)=NaN corr(p,r)=NaN
Phase/lag: φ↔dr 0.0° / -2.000s | p↔dr 0.0° / -2.000s | φ↔r 0.0° | p↔r 0.0°
Transient ratio RMS_acq/RMS_ss: φ=0.00 p=0.00

### R10 helix

Settle (pitch window)=2.23 s | win=persistent

| Window | φ signed_mean [°] | φ MAE | φ RMS | φ p95 | φ max | p MAE [°/s] | p RMS | p p95 | p max |
|--------|------------------:|------:|------:|------:|------:|------------:|------:|------:|------:|
| acq | 1.5916 | 1.5916 | 1.9425 | 3.2273 | 3.2830 | 4.1004 | 4.6918 | 7.1771 | 7.3143 |
| steady | 1.4427 | 1.4427 | 1.5453 | 2.3038 | 3.2443 | 2.3090 | 2.7611 | 5.1521 | 6.4867 |

Rudder: acq RMS=16.946° rateRMS=36.626°/s sat=13.48% | ss RMS=4.710° rateRMS=38.361°/s sat=0.00%
Yaw wrap (helix SBE): MAE=0.1748 RMS=0.2041 p95=0.3493 | rud sat acq/ss/full=13.48/0.00/0.67% | ratio=1.0181
Spectrum ss: φ peak f=0.781 Hz | p peak f=0.781 Hz | damp_proxy φ/p=0.0071/0.0071 | vs plant Δf=0.013 Hz match=1
Coupling ss: corr(φ,dr)=0.143 corr(p,dr)=-0.002 corr(φ,r)=0.210 corr(p,r)=-0.101
Phase/lag: φ↔dr -22.8° / 0.050s | p↔dr 68.0° / 1.825s | φ↔r 29.6° | p↔r 120.4°
Transient ratio RMS_acq/RMS_ss: φ=1.26 p=1.70

## Pitch/yaw preservation vs capsule

| Route | metric | value | capsule | ok |
|-------|--------|------:|--------:|:--:|
| X | pitch ss MAE [°] | 0.0110 | 0.0110 | YES |
| XZ | pitch ss MAE [°] | 0.1214 | 0.1214 | YES |
| H | pitch ss MAE [°] | 0.0413 | 0.0413 | YES |
| H | yaw wrap MAE [°] | 0.1748 | 0.1748 | YES |

## Gates

Preferred: ss φ MAE≤0.5°, p95≤1°. Hard: MAE≤1°, p95≤2°, max≤5°, rudder sat≤1%, pitch/yaw preserved.

| Route | MAE | p95 | max | sat% | pref | hard |
|-------|----:|----:|----:|-----:|:----:|:----:|
| X | 0.0000 | 0.0000 | 0.0000 | 0.00 | YES | YES |
| XZ | 0.0000 | 0.0000 | 0.0000 | 0.00 | YES | YES |
| H | 1.4427 | 2.3038 | 3.2443 | 0.00 | NO | NO |

- Preferred all routes: **FAIL**
- Hard + pitch/yaw: **FAIL**

## Root-cause class

- **Class:** `yaw_command_induced_coupling`
- **Next (one bounded option, not implemented):** `scheduled_lateral_LQR_benchmark`
- Detail: Helix-only FAIL: steady φ mean≈MAE=1.443° (≈HELIX trim bank φ*≈1.44°); AC rms≈0.553° at plant roll f=0.781 Hz (match=1, ζ_proxy=0.0071). X/XZ φ≡0 (no yaw). Root: yaw-command-induced coupling (quasi-steady bank + light plant-mode ripple). Cross-damping alone will not remove mean bank. Next: scheduled lateral LQR benchmark on [y φ ψ v p r] (not implement now).

## Feedback

- Verdict: **FAIL**
- Key ss φ MAE [°]: X=0.0000, XZ=0.0000, H=1.4427
- Key ss φ p95 [°]: X=0.0000, XZ=0.0000, H=2.3038
- Root: yaw_command_induced_coupling | Next: scheduled_lateral_LQR_benchmark
- Files: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.md` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.mat` `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\ROLL_BASELINE_AUDIT.png`
