# CTRL_OBS_AUDIT_001 — Scaled controllability / observability audit

**Overall verdict: PASS**

## Provenance

- Read-only models: `suite_results/LOCAL_SS_LEVEL.mat`, `suite_results/LOCAL_SS_CLIMB.mat`
- Validation capsule: `suite_results/SS_VALIDATION.md` (level/climb PASS; helix excluded)
- Driver: `run_ctrl_obs_audit.m` (one invocation; no controller/plant/guidance edit)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CTRL_OBS_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CTRL_OBS_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\CTRL_OBS_AUDIT.png`

## Units / frames / scales / tolerances

- Frame: NED eta + BODY nu; Euler ZYX; inputs dr,de,thrust=Xprop
- State x = [x y z phi theta psi u v w p q r]
- Input u = [dr de thrust]
- Units x: m, m, m, rad, rad, rad, m/s, m/s, m/s, rad/s, rad/s, rad/s
- Units u: rad, rad, N
- Physical scales (documented TRIM/LOCAL_SS):

```
x_scale = [10  10  10   1   1   1 1.5 0.3 0.3 0.2 0.2 0.2]
u_scale = [0.4363 0.2618     50]
```

- Scaling before SVD/PBH: `As = Sx\\A*Sx`, `Bs = Sx\\B*Su`, `Cs = Sy\\C*Sx` with `Sx=diag(x_scale)`, `Su=diag(u_scale)`, `Sy=diag(x_scale(iy))`.
- Controllability SVD of `ctrb(As,Bs)`; observability SVD of `obsv(As,Cs)`.
- Numerical rank tolerance: `tol = max(m,n)*eps(sigma_max)` (MATLAB-rank-like); report `rank = nnz(sigma > tol)`, condition `sigma_max/sigma_min`.
- PBH: scaled `sigma_min` of `[λI−A, B]` (ctrl) / `[λI−A; C]` (obs); uncontrollable/unobservable iff `sigma_min ≤ 10*max(size)*eps(sigma_max)`; weak if controllable/observable but `sigma_min < 1e-3 * sigma_max`.
- **Raw unscaled rank alone is insufficient (FAIL criterion avoided).**

## Controllability

### LEVEL

#### full_12

- n=12, m=3; numerical rank **12 / 12** with tol=5.364e-07
- σ_max=1.011166e+08, σ_min=1.223050e-02, cond(Qc_s)=8.267574e+09
- singular values: [1.011e+08 2.972e+06 5.501e+04 4.211e+04 8.144e+00 2.820e+00 1.072e+00 4.249e-01 1.494e-01 8.241e-02 7.675e-02 1.223e-02]

| k | λ | PBH σ_min | weak | unc | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.242290e+00 | 2.160e-01 | 0 | 0 | dynamic | r(0.30)+y(0.27)+psi(0.24) |
| 2 | +7.350478e-01 | 2.056e-01 | 0 | 0 | dynamic | z(0.44)+theta(0.22)+q(0.16) |
| 3 | +2.410699e-01 | 1.489e-01 | 0 | 0 | dynamic | z(0.66)+x(0.16)+theta(0.10) |
| 4 | +0.000000e+00 | 5.510e-02 | 1 | 0 | kinematic_integrator | x(1.00)+y(0.00)+z(0.00) |
| 5 | +0.000000e+00 | 5.510e-02 | 1 | 0 | kinematic_integrator | y(1.00)+x(0.00)+z(0.00) |
| 6 | +0.000000e+00 | 5.510e-02 | 1 | 0 | kinematic_integrator | z(1.00)+x(0.00)+y(0.00) |
| 7 | +0.000000e+00 | 5.510e-02 | 1 | 0 | kinematic_integrator | y(1.00)+psi(0.00)+x(0.00) |
| 8 | -2.138805e-02+4.993445e+00i | 1.143e-01 | 1 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 9 | -2.138805e-02-4.993445e+00i | 1.143e-01 | 1 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 10 | -1.258984e-01 | 8.776e-02 | 1 | 0 | dynamic | x(0.54)+z(0.36)+u(0.07) |
| 11 | -2.747879e+00 | 2.300e-01 | 0 | 0 | dynamic | q(0.52)+w(0.23)+theta(0.19) |
| 12 | -2.758271e+00 | 2.332e-01 | 0 | 0 | dynamic | r(0.49)+v(0.19)+psi(0.18) |

#### vertical_5

- n=5, m=2; numerical rank **5 / 5** with tol=7.105e-14
- σ_max=3.637851e+01, σ_min=8.216948e-02, cond(Qc_s)=4.427253e+02
- singular values: [3.638e+01 2.600e+00 1.070e+00 4.082e-01 8.217e-02]

| k | λ | PBH σ_min | weak | unc | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +7.350478e-01 | 5.629e-01 | 0 | 0 | dynamic | z(0.47)+theta(0.23)+q(0.17) |
| 2 | +2.410699e-01 | 2.106e-01 | 0 | 0 | dynamic | z(0.79)+theta(0.12)+u(0.05) |
| 3 | +0.000000e+00 | 1.500e-01 | 0 | 0 | kinematic_integrator | z(1.00)+theta(0.00)+u(0.00) |
| 4 | -1.258984e-01 | 1.533e-01 | 0 | 0 | dynamic | z(0.78)+u(0.15)+theta(0.06) |
| 5 | -2.747879e+00 | 2.300e-01 | 0 | 0 | dynamic | q(0.52)+w(0.23)+theta(0.19) |

#### lateral_6

- n=6, m=1; numerical rank **6 / 6** with tol=5.457e-12
- σ_max=6.886231e+03, σ_min=1.080848e-02, cond(Qc_s)=6.371140e+05
- singular values: [6.886e+03 5.344e+02 4.179e+01 2.041e+00 7.176e-02 1.081e-02]

| k | λ | PBH σ_min | weak | unc | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.242290e+00 | 2.160e-01 | 0 | 0 | dynamic | r(0.30)+y(0.27)+psi(0.24) |
| 2 | +0.000000e+00 | 5.510e-02 | 1 | 0 | kinematic_integrator | y(1.00)+phi(0.00)+psi(0.00) |
| 3 | +0.000000e+00 | 5.510e-02 | 1 | 0 | kinematic_integrator | y(1.00)+psi(0.00)+phi(0.00) |
| 4 | -2.138805e-02+4.993445e+00i | 1.143e-01 | 1 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 5 | -2.138805e-02-4.993445e+00i | 1.143e-01 | 1 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 6 | -2.758271e+00 | 2.634e-01 | 0 | 0 | dynamic | r(0.49)+v(0.19)+psi(0.18) |

### CLIMB

#### full_12

- n=12, m=3; numerical rank **12 / 12** with tol=5.364e-07
- σ_max=7.497802e+07, σ_min=1.120426e-02, cond(Qc_s)=6.691920e+09
- singular values: [7.498e+07 8.879e+05 4.363e+04 3.551e+04 7.660e+00 2.120e+00 1.066e+00 3.928e-01 1.578e-01 7.494e-02 7.336e-02 1.120e-02]

| k | λ | PBH σ_min | weak | unc | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.235072e+00 | 2.462e-01 | 0 | 0 | dynamic | r(0.26)+y(0.23)+psi(0.23) |
| 2 | +4.870644e-01+2.493178e-01i | 2.114e-01 | 0 | 0 | dynamic | z(0.40)+x(0.25)+theta(0.17) |
| 3 | +4.870644e-01-2.493178e-01i | 2.114e-01 | 0 | 0 | dynamic | z(0.40)+x(0.25)+theta(0.17) |
| 4 | +0.000000e+00 | 5.487e-02 | 1 | 0 | kinematic_integrator | x(1.00)+y(0.00)+z(0.00) |
| 5 | +0.000000e+00 | 5.487e-02 | 1 | 0 | kinematic_integrator | y(1.00)+x(0.00)+z(0.00) |
| 6 | +0.000000e+00 | 5.487e-02 | 1 | 0 | kinematic_integrator | z(1.00)+x(0.00)+y(0.00) |
| 7 | +0.000000e+00 | 5.487e-02 | 1 | 0 | kinematic_integrator | y(1.00)+psi(0.00)+x(0.00) |
| 8 | -1.891401e-02+4.779879e+00i | 8.865e-02 | 1 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 9 | -1.891401e-02-4.779879e+00i | 8.865e-02 | 1 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 10 | -1.685441e-01 | 1.190e-01 | 0 | 0 | dynamic | x(0.65)+z(0.22)+u(0.12) |
| 11 | -2.702354e+00 | 1.957e-01 | 0 | 0 | dynamic | r(0.46)+psi(0.19)+v(0.18) |
| 12 | -2.742820e+00 | 2.052e-01 | 0 | 0 | dynamic | q(0.51)+w(0.23)+theta(0.19) |

#### vertical_5

- n=5, m=2; numerical rank **5 / 5** with tol=3.553e-14
- σ_max=3.071781e+01, σ_min=7.870996e-02, cond(Qc_s)=3.902658e+02
- singular values: [3.072e+01 2.090e+00 1.065e+00 3.879e-01 7.871e-02]

| k | λ | PBH σ_min | weak | unc | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +4.870644e-01+2.493178e-01i | 4.080e-01 | 0 | 0 | dynamic | z(0.54)+theta(0.22)+q(0.12) |
| 2 | +4.870644e-01-2.493178e-01i | 4.080e-01 | 0 | 0 | dynamic | z(0.54)+theta(0.22)+q(0.12) |
| 3 | +0.000000e+00 | 1.379e-01 | 0 | 0 | kinematic_integrator | z(1.00)+theta(0.00)+u(0.00) |
| 4 | -1.685441e-01 | 1.752e-01 | 0 | 0 | dynamic | z(0.62)+u(0.34)+theta(0.03) |
| 5 | -2.742820e+00 | 2.052e-01 | 0 | 0 | dynamic | q(0.52)+w(0.23)+theta(0.19) |

#### lateral_6

- n=6, m=1; numerical rank **6 / 6** with tol=5.457e-12
- σ_max=6.303216e+03, σ_min=9.923677e-03, cond(Qc_s)=6.351694e+05
- singular values: [6.303e+03 3.274e+02 2.491e+01 1.991e+00 6.987e-02 9.924e-03]

| k | λ | PBH σ_min | weak | unc | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.235072e+00 | 2.462e-01 | 0 | 0 | dynamic | r(0.26)+y(0.23)+psi(0.23) |
| 2 | +0.000000e+00 | 5.487e-02 | 1 | 0 | kinematic_integrator | y(1.00)+phi(0.00)+psi(0.00) |
| 3 | +0.000000e+00 | 5.487e-02 | 1 | 0 | kinematic_integrator | y(1.00)+psi(0.00)+phi(0.00) |
| 4 | -1.891401e-02+4.779879e+00i | 8.865e-02 | 1 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 5 | -1.891401e-02-4.779879e+00i | 8.865e-02 | 1 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 6 | -2.702354e+00 | 2.685e-01 | 0 | 0 | dynamic | r(0.46)+psi(0.19)+v(0.18) |

## Observability

Assumed direct outputs only (no noise/bias/feasibility claim beyond selection):
- (A) C=I12 ideal — iy=[1   2   3   4   5   6   7   8   9  10  11  12]
- (B) onboard IMU+DVL+depth+heading — iy=[3   4   5   6   7   8   9  10  11  12] → [z, phi, theta, psi, u, v, w, p, q, r] (no absolute x,y)
- (C) B + INS x,y — iy=[1   2   3   4   5   6   7   8   9  10  11  12] (full)

### LEVEL observability

#### A_ideal_I12 — all states (ideal)

- outputs iy=[1   2   3   4   5   6   7   8   9  10  11  12]; numerical rank **12 / 12** with tol=3.433e-05
- σ_max=1.202402e+09, σ_min=1.000000e+00, cond(Qo_s)=1.202402e+09
- singular values: [1.202e+09 1.180e+07 1.716e+05 1.387e+05 1.707e+01 3.750e+00 1.030e+00 1.017e+00 1.016e+00 1.000e+00 1.000e+00 1.000e+00]

| k | λ | PBH σ_min | weak | unobs | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.242290e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.30)+y(0.27)+psi(0.24) |
| 2 | +7.350478e-01 | 1.000e+00 | 0 | 0 | dynamic | z(0.44)+theta(0.22)+q(0.16) |
| 3 | +2.410699e-01 | 1.000e+00 | 0 | 0 | dynamic | z(0.66)+x(0.16)+theta(0.10) |
| 4 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | x(1.00)+y(0.00)+z(0.00) |
| 5 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | y(1.00)+x(0.00)+z(0.00) |
| 6 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | z(1.00)+x(0.00)+y(0.00) |
| 7 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | y(1.00)+psi(0.00)+x(0.00) |
| 8 | -2.138805e-02+4.993445e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 9 | -2.138805e-02-4.993445e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 10 | -1.258984e-01 | 1.000e+00 | 0 | 0 | dynamic | x(0.54)+z(0.36)+u(0.07) |
| 11 | -2.747879e+00 | 1.000e+00 | 0 | 0 | dynamic | q(0.52)+w(0.23)+theta(0.19) |
| 12 | -2.758271e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.49)+v(0.19)+psi(0.18) |

Distinction: 4 near-zero integrator mode(s), 8 dynamic; unobs integrators=0, unobs dynamic=0.

#### B_onboard_no_xy — IMU+DVL+depth+heading assumed direct; no absolute x,y

- outputs iy=[3   4   5   6   7   8   9  10  11  12]; numerical rank **10 / 12** with tol=2.861e-05
- σ_max=1.202402e+09, σ_min=0.000000e+00, cond(Qo_s)=Inf
- singular values: [1.202e+09 1.180e+07 1.716e+05 1.387e+05 1.707e+01 3.748e+00 1.029e+00 1.010e+00 1.000e+00 1.000e+00 8.865e-11 0.000e+00]

| k | λ | PBH σ_min | weak | unobs | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.242290e+00 | 9.996e-01 | 0 | 0 | dynamic | r(0.30)+y(0.27)+psi(0.24) |
| 2 | +7.350478e-01 | 7.231e-01 | 0 | 0 | dynamic | z(0.44)+theta(0.22)+q(0.16) |
| 3 | +2.410699e-01 | 2.372e-01 | 0 | 0 | dynamic | z(0.66)+x(0.16)+theta(0.10) |
| 4 | +0.000000e+00 | 0.000e+00 | 0 | 1 | global_position_or_heading_integrator | x(1.00)+y(0.00)+z(0.00) |
| 5 | +0.000000e+00 | 0.000e+00 | 0 | 1 | global_position_or_heading_integrator | y(1.00)+x(0.00)+z(0.00) |
| 6 | +0.000000e+00 | 0.000e+00 | 0 | 1 | global_position_or_heading_integrator | z(1.00)+x(0.00)+y(0.00) |
| 7 | +0.000000e+00 | 0.000e+00 | 0 | 1 | global_position_or_heading_integrator | y(1.00)+psi(0.00)+x(0.00) |
| 8 | -2.138805e-02+4.993445e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 9 | -2.138805e-02-4.993445e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 10 | -1.258984e-01 | 1.239e-01 | 1 | 0 | dynamic | x(0.54)+z(0.36)+u(0.07) |
| 11 | -2.747879e+00 | 1.000e+00 | 0 | 0 | dynamic | q(0.52)+w(0.23)+theta(0.19) |
| 12 | -2.758271e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.49)+v(0.19)+psi(0.18) |

Distinction: 4 near-zero integrator mode(s), 8 dynamic; unobs integrators=4, unobs dynamic=0.

#### C_B_plus_INS_xy — case B + INS absolute x,y (assumed direct)

- outputs iy=[1   2   3   4   5   6   7   8   9  10  11  12]; numerical rank **12 / 12** with tol=3.433e-05
- σ_max=1.202402e+09, σ_min=1.000000e+00, cond(Qo_s)=1.202402e+09
- singular values: [1.202e+09 1.180e+07 1.716e+05 1.387e+05 1.707e+01 3.750e+00 1.030e+00 1.017e+00 1.016e+00 1.000e+00 1.000e+00 1.000e+00]

| k | λ | PBH σ_min | weak | unobs | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.242290e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.30)+y(0.27)+psi(0.24) |
| 2 | +7.350478e-01 | 1.000e+00 | 0 | 0 | dynamic | z(0.44)+theta(0.22)+q(0.16) |
| 3 | +2.410699e-01 | 1.000e+00 | 0 | 0 | dynamic | z(0.66)+x(0.16)+theta(0.10) |
| 4 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | x(1.00)+y(0.00)+z(0.00) |
| 5 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | y(1.00)+x(0.00)+z(0.00) |
| 6 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | z(1.00)+x(0.00)+y(0.00) |
| 7 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | y(1.00)+psi(0.00)+x(0.00) |
| 8 | -2.138805e-02+4.993445e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 9 | -2.138805e-02-4.993445e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.81)+phi(0.16)+v(0.01) |
| 10 | -1.258984e-01 | 1.000e+00 | 0 | 0 | dynamic | x(0.54)+z(0.36)+u(0.07) |
| 11 | -2.747879e+00 | 1.000e+00 | 0 | 0 | dynamic | q(0.52)+w(0.23)+theta(0.19) |
| 12 | -2.758271e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.49)+v(0.19)+psi(0.18) |

Distinction: 4 near-zero integrator mode(s), 8 dynamic; unobs integrators=0, unobs dynamic=0.

### CLIMB observability

#### A_ideal_I12 — all states (ideal)

- outputs iy=[1   2   3   4   5   6   7   8   9  10  11  12]; numerical rank **12 / 12** with tol=1.717e-05
- σ_max=7.060123e+08, σ_min=1.000000e+00, cond(Qo_s)=7.060123e+08
- singular values: [7.060e+08 8.565e+06 1.646e+05 1.099e+05 1.541e+01 3.087e+00 1.060e+00 1.024e+00 1.013e+00 1.000e+00 1.000e+00 1.000e+00]

| k | λ | PBH σ_min | weak | unobs | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.235072e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.26)+y(0.23)+psi(0.23) |
| 2 | +4.870644e-01+2.493178e-01i | 1.000e+00 | 0 | 0 | dynamic | z(0.40)+x(0.25)+theta(0.17) |
| 3 | +4.870644e-01-2.493178e-01i | 1.000e+00 | 0 | 0 | dynamic | z(0.40)+x(0.25)+theta(0.17) |
| 4 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | x(1.00)+y(0.00)+z(0.00) |
| 5 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | y(1.00)+x(0.00)+z(0.00) |
| 6 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | z(1.00)+x(0.00)+y(0.00) |
| 7 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | y(1.00)+psi(0.00)+x(0.00) |
| 8 | -1.891401e-02+4.779879e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 9 | -1.891401e-02-4.779879e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 10 | -1.685441e-01 | 1.000e+00 | 0 | 0 | dynamic | x(0.65)+z(0.22)+u(0.12) |
| 11 | -2.702354e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.46)+psi(0.19)+v(0.18) |
| 12 | -2.742820e+00 | 1.000e+00 | 0 | 0 | dynamic | q(0.51)+w(0.23)+theta(0.19) |

Distinction: 4 near-zero integrator mode(s), 8 dynamic; unobs integrators=0, unobs dynamic=0.

#### B_onboard_no_xy — IMU+DVL+depth+heading assumed direct; no absolute x,y

- outputs iy=[3   4   5   6   7   8   9  10  11  12]; numerical rank **10 / 12** with tol=1.431e-05
- σ_max=7.060123e+08, σ_min=0.000000e+00, cond(Qo_s)=Inf
- singular values: [7.060e+08 8.565e+06 1.646e+05 1.099e+05 1.541e+01 3.086e+00 1.060e+00 1.014e+00 1.000e+00 1.000e+00 4.623e-11 0.000e+00]

| k | λ | PBH σ_min | weak | unobs | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.235072e+00 | 9.997e-01 | 0 | 0 | dynamic | r(0.26)+y(0.23)+psi(0.23) |
| 2 | +4.870644e-01+2.493178e-01i | 5.400e-01 | 0 | 0 | dynamic | z(0.40)+x(0.25)+theta(0.17) |
| 3 | +4.870644e-01-2.493178e-01i | 5.400e-01 | 0 | 0 | dynamic | z(0.40)+x(0.25)+theta(0.17) |
| 4 | +0.000000e+00 | 0.000e+00 | 0 | 1 | global_position_or_heading_integrator | x(1.00)+y(0.00)+z(0.00) |
| 5 | +0.000000e+00 | 0.000e+00 | 0 | 1 | global_position_or_heading_integrator | y(1.00)+x(0.00)+z(0.00) |
| 6 | +0.000000e+00 | 0.000e+00 | 0 | 1 | global_position_or_heading_integrator | z(1.00)+x(0.00)+y(0.00) |
| 7 | +0.000000e+00 | 0.000e+00 | 0 | 1 | global_position_or_heading_integrator | y(1.00)+psi(0.00)+x(0.00) |
| 8 | -1.891401e-02+4.779879e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 9 | -1.891401e-02-4.779879e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 10 | -1.685441e-01 | 1.663e-01 | 0 | 0 | dynamic | x(0.65)+z(0.22)+u(0.12) |
| 11 | -2.702354e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.46)+psi(0.19)+v(0.18) |
| 12 | -2.742820e+00 | 1.000e+00 | 0 | 0 | dynamic | q(0.51)+w(0.23)+theta(0.19) |

Distinction: 4 near-zero integrator mode(s), 8 dynamic; unobs integrators=4, unobs dynamic=0.

#### C_B_plus_INS_xy — case B + INS absolute x,y (assumed direct)

- outputs iy=[1   2   3   4   5   6   7   8   9  10  11  12]; numerical rank **12 / 12** with tol=1.717e-05
- σ_max=7.060123e+08, σ_min=1.000000e+00, cond(Qo_s)=7.060123e+08
- singular values: [7.060e+08 8.565e+06 1.646e+05 1.099e+05 1.541e+01 3.087e+00 1.060e+00 1.024e+00 1.013e+00 1.000e+00 1.000e+00 1.000e+00]

| k | λ | PBH σ_min | weak | unobs | class | participation |
|--:|---|---:|:---:|:---:|---|---|
| 1 | +1.235072e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.26)+y(0.23)+psi(0.23) |
| 2 | +4.870644e-01+2.493178e-01i | 1.000e+00 | 0 | 0 | dynamic | z(0.40)+x(0.25)+theta(0.17) |
| 3 | +4.870644e-01-2.493178e-01i | 1.000e+00 | 0 | 0 | dynamic | z(0.40)+x(0.25)+theta(0.17) |
| 4 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | x(1.00)+y(0.00)+z(0.00) |
| 5 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | y(1.00)+x(0.00)+z(0.00) |
| 6 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | z(1.00)+x(0.00)+y(0.00) |
| 7 | +0.000000e+00 | 1.000e+00 | 0 | 0 | global_position_or_heading_integrator | y(1.00)+psi(0.00)+x(0.00) |
| 8 | -1.891401e-02+4.779879e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 9 | -1.891401e-02-4.779879e+00i | 1.000e+00 | 0 | 0 | dynamic | p(0.80)+phi(0.17)+v(0.01) |
| 10 | -1.685441e-01 | 1.000e+00 | 0 | 0 | dynamic | x(0.65)+z(0.22)+u(0.12) |
| 11 | -2.702354e+00 | 1.000e+00 | 0 | 0 | dynamic | r(0.46)+psi(0.19)+v(0.18) |
| 12 | -2.742820e+00 | 1.000e+00 | 0 | 0 | dynamic | q(0.51)+w(0.23)+theta(0.19) |

Distinction: 4 near-zero integrator mode(s), 8 dynamic; unobs integrators=0, unobs dynamic=0.

## Level vs climb — differences & design implications

- Full ctrl rank level=12/12 climb=12/12 (tol-aware); cond(Qc_s) level=8.27e+09 climb=6.69e+09
- Vertical reduced rank level=5/5 climb=5/5; lateral level=6/6 climb=6/6
- level weakest dynamic ctrl PBH sigma_min=8.776e-02 at lam=-1.258984e-01 (x(0.54)+z(0.36)+u(0.07))
- climb weakest dynamic ctrl PBH sigma_min=8.865e-02 at lam=-1.891401e-02+4.779879e+00i (p(0.80)+phi(0.17)+v(0.01))
- Obs B (no x,y): scaled SVD rank **10/12** at both trims → unobservable subspace dim=2 = absolute **x,y** integrators. Depth `z` and heading `psi` remain observable via assumed direct outputs. PBH at repeated λ=0 reports σ_min≈0 for every listed zero eigenvalue (property of λ, not each eigenvector); use rank deficit for unobs dimension. All dynamic modes stay observable under B.
- Climb vs level: schedule LQR/LQI gains (prior ΔA~9%, ΔB~7%); do not use a single trim model for both. Full Qc_s is ill-conditioned (~1e9) at both ops — prefer reduced vertical/lateral designs or careful LQR weighting; vertical cond~400 is benign.
- Helix excluded from this audit (non-LTI inertial). Next: LQR/LQI about level & climb with scheduling, INS for absolute xy if required

### PBH ctrl sigma_min (full) by mode

| k | λ_level | σmin_level | λ_climb | σmin_climb | class_hint |
|--:|---|---:|---|---:|---|
| 1 | +1.242290e+00 | 2.160e-01 | +1.235072e+00 | 2.462e-01 | dynamic |
| 2 | +7.350478e-01 | 2.056e-01 | +4.870644e-01+2.493178e-01i | 2.114e-01 | dynamic |
| 3 | +2.410699e-01 | 1.489e-01 | +4.870644e-01-2.493178e-01i | 2.114e-01 | dynamic |
| 4 | +0.000000e+00 | 5.510e-02 | +0.000000e+00 | 5.487e-02 | kinematic_integrator |
| 5 | +0.000000e+00 | 5.510e-02 | +0.000000e+00 | 5.487e-02 | kinematic_integrator |
| 6 | +0.000000e+00 | 5.510e-02 | +0.000000e+00 | 5.487e-02 | kinematic_integrator |
| 7 | +0.000000e+00 | 5.510e-02 | +0.000000e+00 | 5.487e-02 | kinematic_integrator |
| 8 | -2.138805e-02+4.993445e+00i | 1.143e-01 | -1.891401e-02+4.779879e+00i | 8.865e-02 | dynamic |
| 9 | -2.138805e-02-4.993445e+00i | 1.143e-01 | -1.891401e-02-4.779879e+00i | 8.865e-02 | dynamic |
| 10 | -1.258984e-01 | 8.776e-02 | -1.685441e-01 | 1.190e-01 | dynamic |
| 11 | -2.747879e+00 | 2.300e-01 | -2.702354e+00 | 1.957e-01 | dynamic |
| 12 | -2.758271e+00 | 2.332e-01 | -2.742820e+00 | 2.052e-01 | dynamic |

## PASS gates

| Gate | Result |
|---|---|
| Scaled SVD reported (all ctrl/obs cases) | PASS |
| PBH sigma_min per eigenvalue/mode | PASS |
| Units/frames/scales/tolerances stated | PASS |
| Level-vs-climb + design implications | PASS |
| No production controller/plant/guidance edit | PASS |

**Overall: PASS**

## Next decision

- Proceed to scheduled LQR/LQI about validated level & climb trims (inside SS_VALIDATION envelope |δ|≤0.5°, t≤0.6s).
- For absolute x,y regulation use INS (obs C) or path-relative errors; do not expect obs B alone to recover global position integrators.
- Helix remains excluded from ordinary inertial LTI.
