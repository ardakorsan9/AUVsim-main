# SS_VALIDATION_001 — Local LTI perturbation validation

**LEVEL model: PASS** | **CLIMB model: PASS**

## Provenance

- Plant RHS (exact): `underwater777_vehicle_dynamics.m`
- Level A,B: `suite_results/LOCAL_SS_LEVEL.mat` (jac PASS)
- Climb A,B: `suite_results/LOCAL_SS_CLIMB.mat` (jac PASS)
- Method: nominal translating trajectory + perturbed NL; compare `δx=x_pert−x_nom` to LTI `δẋ=Aδx+Bδu` (RK4)
- Horizons: T_end=0.600s, T_pulse=0.20s, dt=0.005s (maxRe(A)=1.242; short before OL divergence)
- Actuator Δ ≤ 0.5° (also 0.25° amplitude check); helix EXCLUDED
- Production controller/guidance untouched; driver `run_ss_validation.m` only
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SS_VALIDATION.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SS_VALIDATION.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SS_VALIDATION.png`

## PASS gates (per channel)

- Directly excited dynamic-state relative RMSE ≤ 20% (near-zero channels excluded)
- Correlation ≥ 0.95 where variance exists
- Initial derivative / control (Bδu) sign agrees on focus dynamics
- Reducing amplitude 0.5°→0.25° improves or does not worsen focus nrmse_rel

## Channel results

| Trim | Channel | Verdict | focus nrmse_rel | min corr | sign | amp0.25 | T_valid [s] | Why |
|---|---|:---:|---:|---:|:---:|:---:|---:|---|
| level | elev_pulse | **PASS** | 0.011 | 1.000 | OK | OK | 0.600 | all gates met |
| level | rudder_pulse | **PASS** | 0.003 | 1.000 | OK | OK | 0.600 | all gates met |
| level | theta_ic | **PASS** | 0.002 | 1.000 | OK | OK | 0.600 | all gates met |
| climb | elev_pulse | **PASS** | 0.009 | 1.000 | OK | OK | 0.600 | all gates met |
| climb | theta_ic | **PASS** | 0.002 | 1.000 | OK | OK | 0.600 | all gates met |

### level / elev_pulse — PASS

elevator +0.5deg pulse. Amp=0.50 deg. dyn_focus=[w,q]. T_valid=0.600s.

Ctrl sign: w:B=-3.58e-03 nl=-3.61e-03 OK; q:B=-2.05e-02 nl=-2.05e-02 OK

| State | nrmse_rel | nrmse/scale | max|err|/scale | corr | near0 | d0 sign | peak_nl | t_peak |
|---|---:|---:|---:|---:|:---:|:---:|---:|---:|
| w | 0.0007 | 3.33e-05 | 8.742e-05 | 1.000 | 0 | agree | -0.001778 | 0.600 |
| q | 0.0109 | 0.0005473 | 0.001152 | 1.000 | 0 | agree | -0.00557 | 0.600 |
| u | 0.0000 | 2.045e-06 | 3.667e-06 | n/a | 1 | agree | -0.000191 | 0.600 |
| theta | 0.0004 | 1.91e-05 | 4.916e-05 | 1.000 | 0 | agree | -0.002379 | 0.600 |

Amplitude check: nrmse_rel 0.5°=0.0109 → 0.25°=0.0028 (OK, Δ=-0.0082)

### level / rudder_pulse — PASS

rudder +0.5deg pulse. Amp=0.50 deg. dyn_focus=[v,p,r]. T_valid=0.600s.

Ctrl sign: v:B=+4.93e-03 nl=+4.88e-03 OK; p:B=+1.21e-02 nl=+1.23e-02 OK; r:B=+2.24e-02 nl=+2.23e-02 OK

| State | nrmse_rel | nrmse/scale | max|err|/scale | corr | near0 | d0 sign | peak_nl | t_peak |
|---|---:|---:|---:|---:|:---:|:---:|---:|---:|
| v | 0.0002 | 9.176e-06 | 2.467e-05 | 1.000 | 0 | agree | 0.0006241 | 0.205 |
| p | 0.0014 | 7.144e-05 | 0.0001241 | 1.000 | 0 | agree | 0.003015 | 0.230 |
| r | 0.0031 | 0.0001545 | 0.0002798 | 1.000 | 0 | agree | 0.003912 | 0.205 |
| phi | 0.0001 | 2.614e-06 | 6.361e-06 | 1.000 | 0 | agree | 0.0009398 | 0.540 |
| psi | 0.0001 | 6.227e-06 | 1.483e-05 | 1.000 | 0 | agree | 0.001699 | 0.600 |

Amplitude check: nrmse_rel 0.5°=0.0031 → 0.25°=0.0008 (OK, Δ=-0.0023)

### level / theta_ic — PASS

theta +0.5deg IC. Amp=0.50 deg. dyn_focus=[theta,w,q]. T_valid=0.600s.

Ctrl sign: n/a (IC)

| State | nrmse_rel | nrmse/scale | max|err|/scale | corr | near0 | d0 sign | peak_nl | t_peak |
|---|---:|---:|---:|---:|:---:|:---:|---:|---:|
| theta | 0.0001 | 2.874e-06 | 8.423e-06 | 1.000 | 0 | agree | 0.008727 | 0.000 |
| w | 0.0001 | 6.458e-06 | 1.687e-05 | 1.000 | 0 | agree | -0.0005446 | 0.600 |
| q | 0.0021 | 0.0001063 | 0.0002755 | 1.000 | 0 | agree | -0.003544 | 0.600 |
| u | 0.0000 | 2.173e-07 | 5.522e-07 | 1.000 | 0 | agree | 0.0007157 | 0.600 |

Amplitude check: nrmse_rel 0.5°=0.0021 → 0.25°=0.0005 (OK, Δ=-0.0016)

### climb / elev_pulse — PASS

elevator +0.5deg pulse. Amp=0.50 deg. dyn_focus=[w,q]. T_valid=0.600s.

Ctrl sign: w:B=-3.34e-03 nl=-3.36e-03 OK; q:B=-1.91e-02 nl=-1.91e-02 OK

| State | nrmse_rel | nrmse/scale | max|err|/scale | corr | near0 | d0 sign | peak_nl | t_peak |
|---|---:|---:|---:|---:|:---:|:---:|---:|---:|
| w | 0.0005 | 2.719e-05 | 7.116e-05 | 1.000 | 0 | agree | -0.00156 | 0.600 |
| q | 0.0094 | 0.0004707 | 0.0009845 | 1.000 | 0 | agree | -0.005091 | 0.600 |
| u | 0.0000 | 1.199e-06 | 1.753e-06 | n/a | 1 | agree | -0.0002825 | 0.600 |
| theta | 0.0003 | 1.651e-05 | 4.237e-05 | 1.000 | 0 | agree | -0.002201 | 0.600 |

Amplitude check: nrmse_rel 0.5°=0.0094 → 0.25°=0.0024 (OK, Δ=-0.0070)

### climb / theta_ic — PASS

theta +0.5deg IC. Amp=0.50 deg. dyn_focus=[theta,w,q]. T_valid=0.600s.

Ctrl sign: n/a (IC)

| State | nrmse_rel | nrmse/scale | max|err|/scale | corr | near0 | d0 sign | peak_nl | t_peak |
|---|---:|---:|---:|---:|:---:|:---:|---:|---:|
| theta | 0.0000 | 1.817e-06 | 5.823e-06 | 1.000 | 0 | agree | 0.008727 | 0.000 |
| w | 0.0001 | 4.34e-06 | 1.177e-05 | 1.000 | 0 | agree | -0.0006041 | 0.600 |
| q | 0.0016 | 8.142e-05 | 0.0002242 | 1.000 | 0 | agree | -0.003438 | 0.600 |
| u | 0.0000 | 3.175e-07 | 3.982e-07 | 1.000 | 0 | agree | 0.0006062 | 0.600 |

Amplitude check: nrmse_rel 0.5°=0.0016 → 0.25°=0.0004 (OK, Δ=-0.0012)

## Validity horizon / envelope

- Simulation window fixed at T_end=0.600s (unstable OL; maxRe≈1.242 ⇒ e^{σt}≈2.11 at T_end).
- Per-channel T_valid = last time running focus relative RMSE ≤ 20%.
  - level/elev_pulse: T_valid = **0.600 s** (within envelope)
  - level/rudder_pulse: T_valid = **0.600 s** (within envelope)
  - level/theta_ic: T_valid = **0.600 s** (within envelope)
  - climb/elev_pulse: T_valid = **0.600 s** (within envelope)
  - climb/theta_ic: T_valid = **0.600 s** (within envelope)
- **Recommended LTI validity envelope:** level ≥ [0, 0.600s], climb ≥ [0, 0.600s] for |δu|,|δθ| ≤ 0.5°.
- Beyond T_valid or |δ|≫0.5°: restrict/reject local LTI (unstable modes + nonlinear hydro).
- Helix: still EXCLUDED from ordinary inertial LTI.

## Scales

```
x_scale = [10           10           10            1            1            1          1.5          0.3          0.3          0.2          0.2          0.2]
```

## Next

- Both models PASS inside validity envelope → eligible for controllability / LQR about respective trims (with scheduling).
- Keep |δ| small and horizons ≤ T_valid; do not extrapolate through unstable OL divergence.
- Helix remains non-LTI inertial.
