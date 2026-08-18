# LQR_LQI_PITCH_BENCHMARK_001 — Elevator-only pitch LQR vs LQI

**Verdict: PASS**

**Selected for NL test: `none`** (not a production promotion)

## Provenance

- Read-only models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`
- Actuator limits from `controller_law.m` / `init_parameters.m` (read-only): |de|<=15deg, |dde/dt|<=40deg/s, dt=0.025s
- Driver: `run_lqr_lqi_pitch_benchmark.m` (one invocation; no production edit)
- Envelope: T_end=0.60s, |dtheta|<=0.5deg (SS_VALIDATION)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LQR_LQI_PITCH_BENCHMARK.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LQR_LQI_PITCH_BENCHMARK.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LQR_LQI_PITCH_BENCHMARK.png`

## Subsystem (smallest defensible elevator-only)

Physical pitch: `theta_phys = -theta`. Input: elevator `delta_e` only.
Equilibrium trim `de_trim` held separately; feedback on `delta_de = de - de_trim`.

### LEVEL

- States: [theta_phys, w, q] (n=3)
- u omitted: PBH stabilizable elevator-only on [theta_phys,w,q]; surge held at trim (separate thrust). Coupling A(q,u)/A(w,u) frozen at delta_u=0.
- de_trim = -4.7228 deg
- PBH stabilizable: YES (rank 3/3, cond(Qc_s)=16.7)
- Cand3 stabilizable=YES; Cand4 stabilizable=YES
- Sign: Plant: theta_phys=-theta; de>0 -> +Z/+M; Bp_q after T. LQR K_th=3.708 (u=-Kx => +th_phys -> de_fb=-3.708)

A (3x3):
```
   0.000000e+00  0.000000e+00 -1.000000e+00
  -1.957696e-02 -1.103554e+00  7.236101e-01
   7.344394e-01  5.530545e+00 -6.082930e-01
```
B (3x1):
```
  -0.000000e+00 -4.100331e-01 -2.346217e+00
```

### CLIMB

- States: [theta_phys, w, q] (n=3)
- u omitted: PBH stabilizable elevator-only on [theta_phys,w,q]; surge held at trim (separate thrust). Coupling A(q,u)/A(w,u) frozen at delta_u=0.
- de_trim = -1.2107 deg
- PBH stabilizable: YES (rank 3/3, cond(Qc_s)=15.7)
- Cand3 stabilizable=YES; Cand4 stabilizable=YES
- Sign: Plant: theta_phys=-theta; de>0 -> +Z/+M; Bp_q after T. LQR K_th=3.716 (u=-Kx => +th_phys -> de_fb=-3.716)

A (3x3):
```
   0.000000e+00  0.000000e+00 -1.000000e+00
   1.126325e-02 -1.172765e+00  6.987613e-01
   6.644378e-01  5.385599e+00 -5.895026e-01
```
B (3x1):
```
  -0.000000e+00 -3.822874e-01 -2.187455e+00
```

## Bryson weights (explicit allowed deviations)

| qty | allowed | Q or R |
|---|---:|---:|
| theta_phys | 0.5000 deg | 1/th_max^2 |
| w | 0.050 m/s | 1/w_max^2 |
| q | 5.00 deg/s | 1/q_max^2 |
| xi (LQI) | 0.250 deg | 1/xi_max^2 |
| delta_de | 2.00 deg (design) | R=1/de_des^2 |

Moment-equivalent disturbance: `Bd*de_dist` with de_dist=0.25 deg.

## Gains and closed-loop poles

### LEVEL

LQR K = [ 3.70765 -2.10866 -1.83362]
LQR poles: -2.2102e+00, -2.3342e+00+1.8298e+00j, -2.3342e+00-1.8298e+00j
LQI Kx = [ 7.38317 -2.22593 -2.48032], Ki = -8
LQI poles: -1.7696e+00, -2.1081e+00+2.1186e+00j, -2.1081e+00-2.1186e+00j, -2.4582e+00

### CLIMB

LQR K = [ 3.71563 -2.15744 -1.89342]
LQR poles: -2.2227e+00+1.7801e+00j, -2.2227e+00-1.7801e+00j, -2.2835e+00
LQI Kx = [ 7.49625 -2.29927 -2.58092], Ki = -8
LQI poles: -1.7577e+00, -2.0118e+00+2.0863e+00j, -2.0118e+00-2.0863e+00j, -2.5057e+00

## Key metrics (envelope window)

### LEVEL

| Arch | cases pass | ess_max [deg] | os_max [deg] | de_peak [deg] | de_rms [deg] | |de_rate|_pk [deg/s] | sat_mag_max | chatter |
|---|---:|---:|---:|---:|---:|---:|---:|:---:|
| LQR | 9/9 | 0.2074 | 0.0403 | 1.725 | 0.745 | 28.99 | 0.00 | NO |
| LQI | 9/9 | 0.3775 | 0.0270 | 3.000 | 1.438 | 40.00 | 0.00 | NO |

Representative ref=+0.5deg / dist:

| Arch | case | ts [s] | ess [deg] | os [deg] | de_peak [deg] | pass |
|---|---|---:|---:|---:|---:|:---:|
| LQR | ref_+0.50deg | Inf | 0.2074 | 0.0000 | 1.725 | Y |
| LQR | dist_moment | Inf | 0.0403 | 0.0403 | 0.325 | Y |
| LQI | ref_+0.50deg | Inf | 0.3775 | 0.0000 | 0.407 | Y |
| LQI | dist_moment | Inf | 0.0270 | 0.0270 | 0.338 | Y |

LQR all-pass=YES; LQI all-pass=YES

### CLIMB

| Arch | cases pass | ess_max [deg] | os_max [deg] | de_peak [deg] | de_rms [deg] | |de_rate|_pk [deg/s] | sat_mag_max | chatter |
|---|---:|---:|---:|---:|---:|---:|---:|:---:|
| LQR | 9/9 | 0.2167 | 0.0389 | 1.734 | 0.747 | 29.35 | 0.00 | NO |
| LQI | 9/9 | 0.3826 | 0.0263 | 3.000 | 1.458 | 40.00 | 0.00 | NO |

Representative ref=+0.5deg / dist:

| Arch | case | ts [s] | ess [deg] | os [deg] | de_peak [deg] | pass |
|---|---|---:|---:|---:|---:|:---:|
| LQR | ref_+0.50deg | Inf | 0.2167 | 0.0000 | 1.734 | Y |
| LQR | dist_moment | Inf | 0.0389 | 0.0389 | 0.322 | Y |
| LQI | ref_+0.50deg | Inf | 0.3826 | 0.0000 | 0.419 | Y |
| LQI | dist_moment | Inf | 0.0263 | 0.0263 | 0.337 | Y |

LQR all-pass=YES; LQI all-pass=YES

## Selection

- Selected: `none`
- Reason: Both LQR and LQI pass all cases, but no clear single-architecture advantage for NL test.
- Rejected: No candidate selected (at most one, and only with clear reason). LQR ess_max=0.217 deg dist=0.040; LQI ess_max=0.383 dist=0.027.

Production cascade remains baseline. This benchmark does **not** change `controller_law.m`.

## Next

- No NL candidate; optionally revisit weights or retain cascade.
- Helix remains excluded from ordinary inertial LTI.
