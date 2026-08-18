# GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_RESUME_001

Gate 8 : R10 rail-aware yaw feasibility envelope (resume after pre-MATLAB bridge failure)

- created: 2026-08-09 07:59:06
- certification: **NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)**
- Gate 9: **LOCKED** (Gate 9 remains LOCKED. No feasibility envelope can unlock it; only hardware evidence could, and none exists.)
- invocation: single MATLAB invocation, no retry
- verdict: **PASS**

## What this run is

RESUME, not a method retry. The previous bridge attempt died with resource_exhausted before MATLAB was invoked and before any artifact was written, so no partial result from it exists, is reused, or is repaired here. This run is the first execution of the method.

IMPLEMENTED = this isolated shadow driver only. The plant is exercised by CALL of the unmodified production equations, never by re-implementing them. No controller, guidance, threshold, speed or path is changed. This is not a shaper, not a current feed-forward, and not a promotion. A failed or blocked check is reported as such and is never softened into a pass. Simulation is never hardware certification.

Explicitly NOT: the rejected guidance transition shapers, the rejected current feed-forward candidates, any gain change, any compensator proposal, any promotion.

## Headline

The production plant can hold the R10 turn in steady trim at both speeds. kappa = 0.100 1/m needs 4.06 deg of rudder at U = 1.5 m/s and 4.06 deg at U = 2.0 m/s, against a 25 deg rail, so the steady requirement uses only 16.3 percent of the available deflection.

### Discrepancy

DISCREPANCY IDENTIFIED. The plant is not the binding constraint at R10. Steady-turn feasibility leaves roughly 21 deg of rudder margin, yet the stored closed-loop nominal runs pin the rudder at exactly 25.000 deg for 28.2 percent of the horizon. A rail that the steady physics does not require, that appears at both speeds, and whose dwell does not follow the (essentially speed-invariant) trim requirement, is produced between the reference and the plant, not by the plant. It is a transient / command-shape effect of the closed loop on this geometry, not a feasibility limit of the vehicle.

BOUNDED CLAIM: this run localises the rail to the guidance-to-plant path by elimination (the plant admits the trim with margin). It does NOT identify which element of that path produces it, because no controller or guidance source was read or executed here. Naming the element requires a separate, differently scoped task.

### Open-loop stability, reported separately

Open-loop local stability of the trim, reported separately and not folded into the headline: the fixed-control trim is locally stable at zero curvature at 0 of 11 speeds, and at the R10 point the max real eigenvalue is 3.1431e-01 1/s at U = 1.5 and 6.0253e-01 1/s at U = 2.0 (stable flags 0 and 0 against a tolerance of 1e-06 1/s). An open-loop eigenvalue test on a vehicle that exists to be closed-loop stabilised is a property of the bare hull, not a statement about rudder authority, which is why the two envelopes are published separately.

## Frames, units and provenance

| item | value |
|---|---|
| position | NED inertial [m]; z positive DOWN (depth = +z) |
| rates | BODY angular rates p,q,r [rad/s]; BODY velocity u,v,w [m/s] |
| euler | phi,theta,psi [rad] internally (deg only where a name says _deg) |
| actuators | delta_r, delta_e are plant-input deflections in rad (production convention, source 2 prints them via rad2deg); reported here in deg |
| curvature | kappa [1/m], commanded steady horizontal path curvature; radius = 1/kappa [m] |
| surge | U = BODY surge u [m/s], pinned; Xprop = plant-input surge force [N] |
| eigenvalues | [1/s], continuous time |
| envelope limits | dr_max 25 deg / de_max 15 deg / rate_max 40 deg/s are the ASSUMED declared envelope carried verbatim from source #3 R.cfg_used; NEITHER the envelope NOR the rail definition is modified by this task. |
| plant parameters | obtained by CALL of init_parameters(), never by reading its text |

### Sources (exactly three, read for reasoning)

1. `underwater777_vehicle_dynamics.m`  fingerprint `n=6065.s1=426918.s2=1254438441`
2. `continuous_path_tracking_propulsion.m`  fingerprint `n=15861.s1=1261880.s2=1306658324`
3. `suite_results\GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE.mat`  fingerprint `n=33143.s1=4326992.s2=3168228009`

Exactly three sources were read for reasoning: the production plant equations, the production tracking-loop clone (for the frame / actuator / U_h conventions), and the frozen Gate 8 record (for the declared envelope, the rail evidence and the R10 cell definitions). Production files were opened byte-wise for integrity fingerprinting only and were not read as reasoning sources; the plant is exercised by CALL, not by reading its text.

> DECLARED DEVIATION, reported rather than hidden: the predecessor driver run_gate8_frozen_cell_plant_seam_closure.m was opened for its artifact / log / append-once scaffolding convention only (output naming, sentinel append, footprint accounting). No physics, no evidence value and no numeric result in this report is taken from it. All physics comes from the three sources above.

### Production integrity

| file | fingerprint before | unchanged after | identical to the Gate 8 record |
|---|---|---|---|
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | 1 | 1 |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | 1 | 1 |
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | 1 | 1 |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | 1 | 1 |
| `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990739` | 1 | 1 |
| `suite_results\CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | 1 | 1 |

Fingerprint algorithm: `n=<bytes>.s1=<sum(byte)>.s2=<mod(sum(byte_i*i),2^32)>, i 1-based`. Production and CODEX_VERTICAL_PLAN were opened byte-wise only.

### Plant parameters observed by CALL

Read from the globals that init_parameters() sets, by CALL; listed for provenance only and never modified. W minus B is the net hydrostatic imbalance in N. These coefficients are whatever the production initialiser declares; this task does not validate them against any vehicle.

| parameter | value |
|---|---|
| m | 31.0907 |
| W | 305 |
| B | 310 |
| W_minus_B | -5 |
| xg | 0 |
| yg | 0 |
| zg | 0.0196 |
| xb | 0 |
| yb | 0 |
| zb | 0 |
| Yuudr | 9.64 |
| Nuudr | 6.15 |
| Izz | 3.45 |

## Method

Steady level turn of the autonomous 8-state subsystem [u v w p q r phi theta] (psi and position are ignorable in the production equations). Unknowns x = [v w phi theta delta_r delta_e Xprop]; u is pinned at U. Turn kinematics phidot = thetadot = 0 and psidot = Omega give p = -Omega*sin(theta), q = Omega*cos(theta)*sin(phi), r = Omega*cos(theta)*cos(phi). Omega = kappa*U_h with U_h the horizontal inertial speed computed exactly as source #2 computes it. Residuals = [udot vdot wdot pdot qdot rdot ; zdot], 7 equations, 7 unknowns; zdot = 0 selects the level (constant depth) member of the trim family.

The trim is a genuine equilibrium of an autonomous system, not an approximation: in the production
equations the body accelerations depend only on `[u v w p q r phi theta]`, so with the controls held
fixed that eight-state subsystem is autonomous, `phi_dot = theta_dot = 0` and all six accelerations
vanish at the solution. Only the heading integrates, at the commanded turn rate. This is what makes
the eigenvalue test below well posed.

Solver: deterministic damped Gauss-Newton (Levenberg-Marquardt) with central-difference Jacobians,
warm-started along increasing curvature at each speed. No random numbers are drawn anywhere in this run.

### Predeclared feasibility criteria

A grid point is INFEASIBLE if any of the following holds. These were fixed before the sweep ran.

- 0 = feasible
- 1 = no finite converged bounded trim (solver diverged, plant threw, or box exceeded)
- 2 = max-abs trim residual exceeds the predeclared tolerance
- 3 = required |delta_r| reaches the 25 deg rudder rail
- 4 = trim is not locally stable (max real eigenvalue above the predeclared tolerance)

Tolerances: residual `1e-08` (max-abs over the seven residuals), stability `1e-06` 1/s,
zero-curvature parity `1e-10`.

Two envelopes are published side by side and neither is hidden. kappa_max_all applies all four predeclared criteria. kappa_max_rudder applies only criteria 1 to 3, that is, a bounded converged trim whose required rudder stays off the 25 deg rail; it drops the open-loop eigenvalue test. Both are declared BEFORE the sweep, because an open-loop eigenvalue test on a vehicle that is designed to be closed-loop stabilised can be binding for reasons that have nothing to do with rudder authority, and collapsing that distinction after seeing the numbers would be dishonest.

## Results

### Feasibility envelope

Published basis: criteria 1 to 3 only (bounded converged trim off the 25 deg rail). The all-criteria envelope is NOT finite at every speed because the open-loop eigenvalue test is binding independently of rudder authority; both envelopes are tabulated and neither is suppressed.

| U [m/s] | kappa_max published [1/m] | minimum radius [m] | limiting mode | inside the mandated grid | rudder at kappa_max [deg] | kappa_max all four criteria [1/m] | kappa_max rudder only [1/m] | open-loop stable at kappa = 0 |
|---|---|---|---|---|---|---|---|---|
| 1.0 | 0.160331 | 6.237 | residual above tolerance | 0 | 24.707 | NaN | 0.160331 | 0 |
| 1.1 | 0.159517 | 6.269 | residual above tolerance | 0 | 24.466 | NaN | 0.159517 | 0 |
| 1.2 | 0.159006 | 6.289 | residual above tolerance | 0 | 24.313 | NaN | 0.159006 | 0 |
| 1.3 | 0.158676 | 6.302 | residual above tolerance | 0 | 24.212 | NaN | 0.158676 | 0 |
| 1.4 | 0.158460 | 6.311 | residual above tolerance | 0 | 24.144 | NaN | 0.158460 | 0 |
| 1.5 | 0.158322 | 6.316 | residual above tolerance | 0 | 24.097 | NaN | 0.158322 | 0 |
| 1.6 | 0.158236 | 6.320 | residual above tolerance | 0 | 24.063 | NaN | 0.158236 | 0 |
| 1.7 | 0.158189 | 6.322 | residual above tolerance | 0 | 24.039 | NaN | 0.158189 | 0 |
| 1.8 | 0.158172 | 6.322 | residual above tolerance | 0 | 24.021 | NaN | 0.158172 | 0 |
| 1.9 | 0.158179 | 6.322 | residual above tolerance | 0 | 24.008 | NaN | 0.158179 | 0 |
| 2.0 | 0.158208 | 6.321 | residual above tolerance | 0 | 23.999 | NaN | 0.158208 | 0 |

Envelope is finite at every speed: 1. Max absolute second difference 3.016e-04 1/m against a declared
bound of 2.000e-02, so the published envelope is smooth: 1. Spread across the whole speed grid: 2.159e-03 1/m.

The mandated sweep grid stops at kappa = 0.15 1/m. Where the rail is not reached inside it, the
crossing was located on a declared bounded extension up to 0.60 1/m, used for LOCATION ONLY; every
published per-point quantity still comes from the mandated grid.

### Required rudder on the mandated grid (deg, signed)

| kappa [1/m] | U=1.0 | U=1.1 | U=1.2 | U=1.3 | U=1.4 | U=1.5 | U=1.6 | U=1.7 | U=1.8 | U=1.9 | U=2.0 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| 0.005 | -2.896 | -2.890 | -2.887 | -2.884 | -2.883 | -2.882 | -2.881 | -2.880 | -2.880 | -2.880 | -2.879 |
| 0.010 | -3.522 | -3.514 | -3.509 | -3.506 | -3.503 | -3.502 | -3.501 | -3.500 | -3.499 | -3.499 | -3.498 |
| 0.015 | -3.901 | -3.891 | -3.884 | -3.880 | -3.877 | -3.875 | -3.873 | -3.872 | -3.871 | -3.871 | -3.870 |
| 0.020 | -4.120 | -4.108 | -4.100 | -4.095 | -4.091 | -4.089 | -4.087 | -4.086 | -4.085 | -4.084 | -4.083 |
| 0.025 | -4.215 | -4.201 | -4.192 | -4.186 | -4.182 | -4.180 | -4.177 | -4.176 | -4.175 | -4.174 | -4.173 |
| 0.030 | -4.206 | -4.191 | -4.181 | -4.174 | -4.169 | -4.166 | -4.164 | -4.162 | -4.161 | -4.160 | -4.159 |
| 0.035 | -4.105 | -4.087 | -4.076 | -4.069 | -4.064 | -4.060 | -4.058 | -4.056 | -4.055 | -4.054 | -4.053 |
| 0.040 | -3.918 | -3.899 | -3.887 | -3.879 | -3.873 | -3.869 | -3.867 | -3.865 | -3.863 | -3.862 | -3.861 |
| 0.045 | -3.652 | -3.631 | -3.618 | -3.609 | -3.603 | -3.599 | -3.596 | -3.594 | -3.592 | -3.591 | -3.590 |
| 0.050 | -3.309 | -3.287 | -3.272 | -3.263 | -3.256 | -3.252 | -3.249 | -3.246 | -3.245 | -3.244 | -3.243 |
| 0.055 | -2.893 | -2.869 | -2.854 | -2.844 | -2.837 | -2.832 | -2.828 | -2.826 | -2.824 | -2.823 | -2.822 |
| 0.060 | -2.406 | -2.380 | -2.364 | -2.353 | -2.345 | -2.340 | -2.337 | -2.334 | -2.332 | -2.331 | -2.330 |
| 0.065 | -1.849 | -1.821 | -1.804 | -1.792 | -1.784 | -1.779 | -1.775 | -1.773 | -1.771 | -1.770 | -1.769 |
| 0.070 | -1.223 | -1.194 | -1.175 | -1.163 | -1.155 | -1.149 | -1.145 | -1.142 | -1.140 | -1.139 | -1.139 |
| 0.075 | -0.530 | -0.499 | -0.479 | -0.466 | -0.457 | -0.451 | -0.447 | -0.444 | -0.442 | -0.441 | -0.440 |
| 0.080 | 0.231 | 0.265 | 0.286 | 0.300 | 0.309 | 0.315 | 0.319 | 0.322 | 0.324 | 0.325 | 0.325 |
| 0.085 | 1.060 | 1.095 | 1.118 | 1.132 | 1.142 | 1.149 | 1.153 | 1.156 | 1.158 | 1.158 | 1.158 |
| 0.090 | 1.956 | 1.993 | 2.017 | 2.033 | 2.043 | 2.050 | 2.054 | 2.057 | 2.059 | 2.059 | 2.059 |
| 0.095 | 2.920 | 2.960 | 2.985 | 3.002 | 3.012 | 3.020 | 3.024 | 3.027 | 3.028 | 3.028 | 3.027 |
| 0.100 | 3.952 | 3.995 | 4.022 | 4.039 | 4.051 | 4.058 | 4.063 | 4.065 | 4.066 | 4.066 | 4.065 |
| 0.105 | 5.055 | 5.100 | 5.129 | 5.147 | 5.159 | 5.167 | 5.172 | 5.174 | 5.175 | 5.174 | 5.172 |
| 0.110 | 6.228 | 6.277 | 6.307 | 6.327 | 6.340 | 6.348 | 6.353 | 6.355 | 6.355 | 6.354 | 6.351 |
| 0.115 | 7.475 | 7.527 | 7.560 | 7.581 | 7.594 | 7.603 | 7.608 | 7.610 | 7.609 | 7.607 | 7.604 |
| 0.120 | 8.798 | 8.854 | 8.889 | 8.912 | 8.926 | 8.935 | 8.940 | 8.941 | 8.941 | 8.938 | 8.933 |
| 0.125 | 10.200 | 10.261 | 10.300 | 10.324 | 10.340 | 10.349 | 10.353 | 10.355 | 10.353 | 10.350 | 10.344 |
| 0.130 | 11.688 | 11.755 | 11.797 | 11.824 | 11.840 | 11.850 | 11.855 | 11.856 | 11.854 | 11.849 | 11.841 |
| 0.135 | 13.269 | 13.343 | 13.390 | 13.419 | 13.438 | 13.448 | 13.453 | 13.454 | 13.451 | 13.444 | 13.435 |
| 0.140 | 14.954 | 15.038 | 15.091 | 15.125 | 15.145 | 15.157 | 15.163 | 15.163 | 15.159 | 15.151 | 15.140 |
| 0.145 | 16.764 | 16.863 | 16.925 | 16.964 | 16.988 | 17.002 | 17.008 | 17.008 | 17.003 | 16.994 | 16.980 |
| 0.150 | 18.737 | 18.859 | 18.937 | 18.987 | 19.018 | 19.036 | 19.044 | 19.044 | 19.038 | 19.027 | 19.010 |

### Rudder margin on the mandated grid (deg, 25 - |delta r|)

| kappa [1/m] | U=1.0 | U=1.1 | U=1.2 | U=1.3 | U=1.4 | U=1.5 | U=1.6 | U=1.7 | U=1.8 | U=1.9 | U=2.0 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.000 | 25.000 | 25.000 | 25.000 | 25.000 | 25.000 | 25.000 | 25.000 | 25.000 | 25.000 | 25.000 | 25.000 |
| 0.005 | 22.104 | 22.110 | 22.113 | 22.116 | 22.117 | 22.118 | 22.119 | 22.120 | 22.120 | 22.120 | 22.121 |
| 0.010 | 21.478 | 21.486 | 21.491 | 21.494 | 21.497 | 21.498 | 21.499 | 21.500 | 21.501 | 21.501 | 21.502 |
| 0.015 | 21.099 | 21.109 | 21.116 | 21.120 | 21.123 | 21.125 | 21.127 | 21.128 | 21.129 | 21.129 | 21.130 |
| 0.020 | 20.880 | 20.892 | 20.900 | 20.905 | 20.909 | 20.911 | 20.913 | 20.914 | 20.915 | 20.916 | 20.917 |
| 0.025 | 20.785 | 20.799 | 20.808 | 20.814 | 20.818 | 20.820 | 20.823 | 20.824 | 20.825 | 20.826 | 20.827 |
| 0.030 | 20.794 | 20.809 | 20.819 | 20.826 | 20.831 | 20.834 | 20.836 | 20.838 | 20.839 | 20.840 | 20.841 |
| 0.035 | 20.895 | 20.913 | 20.924 | 20.931 | 20.936 | 20.940 | 20.942 | 20.944 | 20.945 | 20.946 | 20.947 |
| 0.040 | 21.082 | 21.101 | 21.113 | 21.121 | 21.127 | 21.131 | 21.133 | 21.135 | 21.137 | 21.138 | 21.139 |
| 0.045 | 21.348 | 21.369 | 21.382 | 21.391 | 21.397 | 21.401 | 21.404 | 21.406 | 21.408 | 21.409 | 21.410 |
| 0.050 | 21.691 | 21.713 | 21.728 | 21.737 | 21.744 | 21.748 | 21.751 | 21.754 | 21.755 | 21.756 | 21.757 |
| 0.055 | 22.107 | 22.131 | 22.146 | 22.156 | 22.163 | 22.168 | 22.172 | 22.174 | 22.176 | 22.177 | 22.178 |
| 0.060 | 22.594 | 22.620 | 22.636 | 22.647 | 22.655 | 22.660 | 22.663 | 22.666 | 22.668 | 22.669 | 22.670 |
| 0.065 | 23.151 | 23.179 | 23.196 | 23.208 | 23.216 | 23.221 | 23.225 | 23.227 | 23.229 | 23.230 | 23.231 |
| 0.070 | 23.777 | 23.806 | 23.825 | 23.837 | 23.845 | 23.851 | 23.855 | 23.858 | 23.860 | 23.861 | 23.861 |
| 0.075 | 24.470 | 24.501 | 24.521 | 24.534 | 24.543 | 24.549 | 24.553 | 24.556 | 24.558 | 24.559 | 24.560 |
| 0.080 | 24.769 | 24.735 | 24.714 | 24.700 | 24.691 | 24.685 | 24.681 | 24.678 | 24.676 | 24.675 | 24.675 |
| 0.085 | 23.940 | 23.905 | 23.882 | 23.868 | 23.858 | 23.851 | 23.847 | 23.844 | 23.842 | 23.842 | 23.842 |
| 0.090 | 23.044 | 23.007 | 22.983 | 22.967 | 22.957 | 22.950 | 22.946 | 22.943 | 22.941 | 22.941 | 22.941 |
| 0.095 | 22.080 | 22.040 | 22.015 | 21.998 | 21.988 | 21.980 | 21.976 | 21.973 | 21.972 | 21.972 | 21.973 |
| 0.100 | 21.048 | 21.005 | 20.978 | 20.961 | 20.949 | 20.942 | 20.937 | 20.935 | 20.934 | 20.934 | 20.935 |
| 0.105 | 19.945 | 19.900 | 19.871 | 19.853 | 19.841 | 19.833 | 19.828 | 19.826 | 19.825 | 19.826 | 19.828 |
| 0.110 | 18.772 | 18.723 | 18.693 | 18.673 | 18.660 | 18.652 | 18.647 | 18.645 | 18.645 | 18.646 | 18.649 |
| 0.115 | 17.525 | 17.473 | 17.440 | 17.419 | 17.406 | 17.397 | 17.392 | 17.390 | 17.391 | 17.393 | 17.396 |
| 0.120 | 16.202 | 16.146 | 16.111 | 16.088 | 16.074 | 16.065 | 16.060 | 16.059 | 16.059 | 16.062 | 16.067 |
| 0.125 | 14.800 | 14.739 | 14.700 | 14.676 | 14.660 | 14.651 | 14.647 | 14.645 | 14.647 | 14.650 | 14.656 |
| 0.130 | 13.312 | 13.245 | 13.203 | 13.176 | 13.160 | 13.150 | 13.145 | 13.144 | 13.146 | 13.151 | 13.159 |
| 0.135 | 11.731 | 11.657 | 11.610 | 11.581 | 11.562 | 11.552 | 11.547 | 11.546 | 11.549 | 11.556 | 11.565 |
| 0.140 | 10.046 | 9.962 | 9.909 | 9.875 | 9.855 | 9.843 | 9.837 | 9.837 | 9.841 | 9.849 | 9.860 |
| 0.145 | 8.236 | 8.137 | 8.075 | 8.036 | 8.012 | 7.998 | 7.992 | 7.992 | 7.997 | 8.006 | 8.020 |
| 0.150 | 6.263 | 6.141 | 6.063 | 6.013 | 5.982 | 5.964 | 5.956 | 5.956 | 5.962 | 5.973 | 5.990 |

### R10 located: kappa = 0.100 1/m (radius 10 m)

| quantity | U = 1.5 m/s | U = 2.0 m/s |
|---|---|---|
| required rudder [deg, signed] | 4.0582 | 4.0648 |
| rudder margin [deg] | 20.9418 | 20.9352 |
| fraction of the 25 deg rail used [percent] | 16.23 | 16.26 |
| sideslip beta [deg] | 1.6750 | 1.6709 |
| roll phi [deg] | 1.3165 | 2.3370 |
| pitch theta [deg] | -1.8907 | -1.0404 |
| elevator [deg] | -6.4885 | -3.6600 |
| yaw rate r [rad/s] | 0.15002 | 0.19991 |
| max-abs trim residual | 8.530e-17 | 5.375e-17 |
| max real eigenvalue [1/s] | 3.1431e-01 | 6.0253e-01 |
| locally stable (open loop, fixed controls) | 0 | 0 |
| feasible on rudder authority (criteria 1 to 3) | 1 | 1 |
| feasible on all four criteria | 0 | 0 |
| kappa_max at this speed [1/m] | 0.158322 | 0.158208 |
| minimum radius at this speed [m] | 6.316 | 6.321 |
| curvature utilisation kappa / kappa_max | 0.6316 | 0.6321 |
| stored closed-loop nominal max rudder [deg] | 25.0 | 25.0 |
| stored nominal rail dwell [percent] | 28.2 | 19.7 |
| stored worst Monte Carlo dwell [percent] | 50.6 | 45.8 |

### Deterministic replay and zero-curvature parity

- replay: the identical grid was solved twice in the same session and compared with `isequaln` on raw
  doubles across 12 fields. Bitwise identical: **1**, maximum absolute difference 0.000e+00.
- zero-curvature parity: at kappa = 0, across every speed, `|delta r| <= 0.00e+00` rad, `|v| <= 0.00e+00` m/s,
  `|phi| <= 0.00e+00` rad, `|r| <= 0.00e+00` rad/s against a tolerance of 1e-10. Pass: **1**.
- worst converged residual anywhere on the mandated grid: 9.859e-12 against the predeclared 1e-08.

## Directional cross-check against the stored rail and dwell evidence

Directional only. The open-loop steady-turn trim requirement is compared in DIRECTION, not in magnitude, against the stored closed-loop rail and dwell evidence of source #3. No stored number is recomputed, re-run or overwritten.

1. **X and XZ families sit far inside the envelope.** stored X / XZ path curvature peaks at 0.02489 1/m; the trim requirement there is 4.178 deg of rudder against a 25.0 deg rail, and the stored evidence records exactly 0.0 deg of rudder and no rail contact for all six X / XZ cells. Same direction: far inside.
2. **R10 speed ordering.** the trim rudder requirement changes by only +0.0066 deg between U = 1.5 and U = 2.0 m/s (essentially speed-invariant, because every hydrodynamic term in the production yaw and sway equations scales with u^2 at fixed kappa), while the stored nominal rail dwell changes by -8.5 percentage points. The dwell ordering is therefore NOT explained by a speed-dependent trim requirement.
3. **rail contact at the R10 operating point.** steady trim reaches the rail at R10: 0. Stored closed-loop evidence reaches the rail at R10: 1. Agreement: 0.

Stored evidence used, unchanged:

| cell | stored nominal max rudder [deg] | stored nominal dwell [percent] | stored worst MC dwell [percent] | at rail |
|---|---|---|---|---|
| X_U1.0 | 0.0 | 0.00 | 0.33 | 0 |
| X_U1.5 | 0.0 | 0.00 | 0.08 | 0 |
| X_U2.0 | 0.0 | 0.00 | 0.42 | 0 |
| XZ_U1.0 | 0.0 | 0.00 | 0.33 | 0 |
| XZ_U1.5 | 0.0 | 0.00 | 0.25 | 0 |
| XZ_U2.0 | 0.0 | 0.00 | 0.42 | 0 |
| R10_U1.5 | 25.0 | 28.17 | 50.58 | 1 |
| R10_U2.0 | 25.0 | 19.67 | 45.75 | 1 |

Rail definition, carried verbatim and NOT modified: dwell = fraction of run samples with |channel| >= 99.9 percent of its magnitude limit; declared envelope de 15 deg / dr 25 deg / rate 40 deg/s (ASSUMED, carried from the Gate 7 record). NEITHER the definition NOR the 25 percent gate threshold is modified by this task.

## Admission requirement for a future internal guidance contract

This is a **declared fact only**. Nothing here is implemented, wired or promoted by this task.

- name: plant-side steady-turn admission requirement (DECLARED, NOT IMPLEMENTED)
- predicate: `admit a commanded (kappa, u) pair only if kappa <= kappa_max(u) - kappa_reserve`
- conservative bound over the whole speed grid: `kappa <= 0.158172` 1/m, i.e. radius at least 6.322 m
- basis of the tabulated kappa_max: criteria 1 to 3 only (bounded converged trim off the 25 deg rail). The all-criteria envelope is NOT finite at every speed because the open-loop eigenvalue test is binding independently of rudder authority; both envelopes are tabulated and neither is suppressed.
- units and frames: kappa [1/m], u [m/s], radius [m]; NED frame, BODY surge
- reserve: kappa_reserve is NOT set by this task. It must cover the transient overshoot above the steady requirement, which this steady analysis cannot bound. Setting it needs closed-loop evidence that this task is not scoped to produce.
- validity: Valid only for steady, level, current-free turns of the unmodified plant with the ASSUMED 25 deg rudder envelope. NOT valid for transients, not valid with current, and not hardware-validated. NOT_CERTIFIED.
- status: DECLARED FACT ONLY. No guidance contract is created, edited or promoted here.

NOT the operative branch. Recorded for completeness only: if a future internal guidance contract wants a plant-side admission check, the feasibility fact published here is kappa <= kappa_max(u) with kappa_max as tabulated below. At R10 that test PASSES, so an admission check alone would not have prevented the observed rail.

## Hard gates

| id | gate | pass | detail |
|---|---|---|---|
| HG1 | Exactly three reasoning sources; production untouched and fingerprint-identical pre/post | PASS | pre==post 6/6 ; identical to the Gate 8 record 6/6 |
| HG2 | Deterministic replay: the identical grid solved twice is bitwise identical | PASS | max abs delta 0.000e+00 over 12 fields |
| HG3 | Zero-curvature parity: kappa = 0 collapses to the straight-line trim at every speed | PASS | |dr|<=0.00e+00 rad, |v|<=0.00e+00 m/s, |phi|<=0.00e+00 rad, |r|<=0.00e+00 rad/s, tol 1e-10 |
| HG4 | Solver residuals are published and every converged point meets the predeclared tolerance | PASS | 341/341 converged points within tol 1e-08; worst converged residual 9.859e-12 |
| HG5 | Envelope kappa_max(U) is finite and smooth over the whole speed grid | PASS | basis = criteria 1 to 3 ; all finite=1, max |second difference| 3.016e-04 (bound 2.000e-02) |
| HG6 | Every grid point is classified by a predeclared reason code, none left unlabelled | PASS | reason histogram over 341 points (codes 0..4): [0 0 0 0 341] |
| HG7 | R10 kappa = 0.1 located at U = 1.5 and 2.0 m/s with margin and stability reported | PASS | |dr| = 4.0582 deg and 4.0648 deg; margins 20.9418 deg and 20.9352 deg |
| HG8 | Directional cross-check against the stored rail / dwell evidence is reported, both agreements and disagreements | PASS | X/XZ direction consistent=1 ; R10 rail agreement=0 ; speed-ordering same direction=0 |
| HG9 | Trim uses the unmodified production equations by CALL, never a re-implementation | PASS | underwater777_vehicle_dynamics is invoked directly; residuals are its own gdot outputs |
| HG10 | No controller, guidance, threshold, speed or path is changed | PASS | this driver writes only to suite_results artifacts; no production file is opened for writing |
| HG11 | Single MATLAB invocation, no retry, artifact footprint under 200 MiB | PASS | single invocation, no retry; artifacts 0.394 MiB (limit 200) |
| HG12 | Hardware remains NOT_CERTIFIED and Gate 9 remains locked | PASS | no hardware, HIL or bench evidence exists or is claimed |

Verdict: **PASS**. Every hard gate of this bounded feasibility task passed. The result is a published plant fact, not a promotion: hardware stays NOT_CERTIFIED and Gate 9 stays locked by construction.

## Visual QA

VISUAL_QA_PASS

- suite_results\GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE.png : 1771x1042 px, 93 KiB, ok=1
- suite_results\GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_01_trim_states.png : 1459x938 px, 83 KiB, ok=1
- suite_results\GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_02_feasibility_map.png : 1459x730 px, 26 KiB, ok=1
- suite_results\GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_03_solver_quality.png : 1459x730 px, 98 KiB, ok=1
- suite_results\GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_04_evidence_cross_check.png : 1459x730 px, 28 KiB, ok=1

- all panels exceed 400x400 px : 1
- no NaN in plotted envelope data : 1
- rudder rail line at 25.0 deg drawn on every rudder axis : 1
- axis labels carry unit and frame : 1
- tex interpreter disabled so underscored names render literally : 1
- solver residuals plotted on a log axis so convergence quality is visible : 1
- R10 kappa = 0.1 marked explicitly on the envelope panels : 1

## Limits of this result

- Steady, level, current-free trim only. Transient overshoot above the steady requirement is NOT bounded here.
- The 25 deg rudder envelope, the 15 deg elevator envelope and the rail definition are ASSUMED values
  carried from the Gate 8 record; none was identified from hardware.
- Plant coefficients are whatever `init_parameters()` sets. They are not validated against a vehicle.
- No controller or guidance source was read or executed, so this run can localise the R10 rail to the
  guidance-to-plant path by elimination but cannot name the element that produces it.
- **NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware)** Gate 9 stays locked.

## Next task

- id: GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001
- title: Localise the R10 rudder rail inside the guidance-to-plant path
- objective: This task proved the plant admits the R10 turn with large steady margin, so the rail is produced between the reference and the plant. The next bounded step names WHICH element produces it, by instrumenting the existing closed-loop R10 run and attributing the commanded deflection to its already-logged components, with no gain or law change.
- bounded by: one existing cell, one horizon, read-only instrumentation, no controller edit
- excludes: no shaper, no feed-forward, no gain change, no threshold change, no promotion
