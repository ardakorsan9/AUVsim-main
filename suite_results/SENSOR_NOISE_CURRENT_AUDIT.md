# SENSOR_NOISE_CURRENT_AUDIT_001 — Sensor / noise / current interface audit

**Overall verdict: PASS** (audit completeness, not robustness)

## Provenance

- Read-only: `controller_law.m`, `continuous_path_tracking.m`, `underwater777_vehicle_dynamics.m`
- Driver: `run_sensor_noise_current_audit.m` (one invocation; no production edit)
- Prior obs set: `CTRL_OBS_AUDIT` IMU+DVL+depth+heading/INS (assumed direct)
- Depth PI/NDO: rejected; production cascade+guidance frozen
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SENSOR_NOISE_CURRENT_AUDIT.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SENSOR_NOISE_CURRENT_AUDIT.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\SENSOR_NOISE_CURRENT_AUDIT.png`
- Did **not** touch `CODEX_VERTICAL_PLAN.md`

## Sample rates / filters (documented)

| Qty | Value | Source |
|---|---|---|
| dt_controller | 0.0250 s | init_parameters (plant+controller) |
| dt_guidance | 0.0750 s | init_parameters (ZOH guidance) |
| tau_rate | 0.0500 s | controller rate LPF on theta_phys_dot |

## Hooks inventory

| Hook | Status |
|---|---|
| Ocean current / Vc / nu_r | **NOT_IMPLEMENTED** |
| Sensor / meas noise | **NOT_IMPLEMENTED** |
| Sensor delay | **NOT_IMPLEMENTED** |
| IMU/DVL/INS sensor model | **NOT_IMPLEMENTED** |

Search limited to the three production files named in task. Guidance filters exist but are software LPFs on plant truth, not sensors.

## Current / nu_r / ground vs water

```
Vc modeled: NO
Vc: NOT_IMPLEMENTED (implicit Vc=0)
nu_r: NOT_IMPLEMENTED — damping/control forces use body nu=[u;v;w] directly
kinematics: pos_dot = R(phi,theta,psi)*[u;v;w] (ground kinematics with nu as body velocity)
damping: Xuu*u*|u|, Yvv*v*|v|, ... use nu not nu-nu_c
plant: Vc≡0; ground-relative ≡ water-relative body velocity
controller sees: BODY nu and NED eta plant truth (ground≡water under Vc=0)
```

## Signal map (production feedback / guidance)

| Signal | Frame | Units | Provenance | Sample | Filter | Delay | Bias | Noise | Notes |
|---|---|---|---|---|---|---|---|---|---|
| x | NED | m | plant_truth | dt_controller | none | 0 | 0 | none | state(1) → guidance path projection only |
| y | NED | m | plant_truth | dt_controller | none | 0 | 0 | none | state(2) → guidance path projection only |
| z | NED | m | plant_truth | dt_controller | none | 0 | 0 | none | state(3) → guidance CTE/depth; NOT a depth-sensor model |
| phi | Euler ZYX | rad | plant_truth | dt_controller | none | 0 | 0 | none | state(4) → controller_law(phi) for theta_phys_dot & roll |
| theta | Euler ZYX / BODY pitch | rad | plant_truth | dt_controller | none | 0 | 0 | none | state(5); controller uses theta_phys=-theta |
| psi | Euler ZYX | rad | plant_truth | dt_controller | none | 0 | 0 | none | state(6) → controller yaw error |
| u | BODY | m/s | plant_truth | dt_controller | none | 0 | 0 | none | state(7) → speed loop + guidance + Muw FF |
| v | BODY | m/s | plant_truth | dt_controller | none | 0 | 0 | none | state(8) → guidance beta=atan2(v,u) |
| w | BODY | m/s | plant_truth | dt_controller | none | 0 | 0 | none | state(9) → controller Muw FF |
| p | BODY | rad/s | plant_truth | dt_controller | none | 0 | 0 | none | state(10) → roll-rate rudder damp |
| q | BODY | rad/s | plant_truth | dt_controller | none | 0 | 0 | none | state(11) → pitch rate via theta_phys_dot |
| r | BODY | rad/s | plant_truth | dt_controller | none | 0 | 0 | none | state(12) → yaw rate + theta_phys_dot |
| U_h | NED horiz | m/s | derived | dt_controller | none | 0 | 0 | none | hypot(xdot,ydot) from R*nu; guidance r_ff=U_h*kappa |
| zdot_inertial | NED | m/s | derived | dt_controller | none | 0 | 0 | none | (R*nu)_z; guidance depth-D / gamma (K_zdot=0 prod) |
| theta_phys | phys pitch | rad | derived | dt_controller | none | 0 | 0 | none | -theta; controller + guidance |
| theta_phys_dot | phys pitch rate | rad/s | derived | dt_controller | LPF tau=0.050s (a=exp(-dt/tau)) | 0 | 0 | none | -q*cos(phi)+r*sin(phi); rate_filt in controller_law |
| beta | BODY sideslip | rad | derived | dt_guidance | none | 0 | 0 | none | atan2(v,u) in guidance_law (crab compensation) |
| z_e_f | NED depth err | m | derived | dt_guidance | LPF 0.93/0.07 on cte(3) | 0 | 0 | none | guidance depth P+I on plant truth CTE |
| yaw_ref/pitch_ref/u_ref/r_ff | cmd | rad|m/s|rad/s | derived | dt_guidance ZOH | guidance internal LPFs | 0 | 0 | none | guidance_law outputs held between ticks in continuous_path_tracking |

guidance_law.m is production guidance called by continuous_path_tracking (filters on truth); not modified; listed for signal provenance.

## vs CTRL_OBS realistic set

- Realistic (ASSUMED): IMU+DVL+depth+heading/INS (CTRL_OBS_AUDIT case B/C)
- y_B = [z, phi, theta, psi, u, v, w, p, q, r] — ASSUMED direct outputs in CTRL_OBS; NOT implemented as sensors here
- y_C = full 12 with INS xy — B + INS absolute x,y — ASSUMED; NOT implemented
- Production actual: Ideal full-state plant truth (closer to case A C=I12) including absolute x,y for guidance
- Gap: Production has no IMU/DVL/depth/heading sensor models; feeds plant truth. Absolute x,y used by guidance despite realistic y_B omitting them.

## Zero-perturbation plumbing (sensitivity DEFERRED)

- Mode: `zero_perturbation`
- Sensitivity injection: **DEFERRED**
- Reason: No already-supported bounded current/noise hooks in controller_law / continuous_path_tracking / underwater777_vehicle_dynamics

| Route | n | T [s] | sensor_innov≡0 | e_theta RMS [deg] | e_psi RMS [deg] | e_z RMS [m] |
|---|---:|---:|:---:|---:|---:|---:|
| X | 720 | 18.00 | YES | 0.1651 | 0.0000 | 0.2110 |
| XZ | 880 | 22.00 | YES | 0.4928 | 0.0000 | 0.3106 |
| R10 | 1800 | 45.00 | YES | 0.1430 | 1.1324 | 0.2185 |

Raw channel / innovation-proxy statistics stored in MAT (`plumbing.*.channel_stats`, `innovation_proxy`).

## Estimator readiness

- Measured y (conceptual): y = [z; phi; theta; psi; u; v; w; p; q; r] — estimator-ready ONLY as conceptual map to IMU+DVL+depth+heading; hardware/sensor models NOT_IMPLEMENTED. Production currently feeds full plant truth including x,y.
- Status: **CONCEPTUAL_ASSUMED — no implemented C*x sensor layer**
- Missing absolute modes: absolute x,y kinematic integrators unobservable under realistic y_B (CTRL_OBS)
- Process disturbance vector: NOT_IMPLEMENTED (would be Vc or nu_c in NED/BODY) / NOT_IMPLEMENTED
- Measurement disturbance vector: NOT_IMPLEMENTED
- Next estimator candidate: **DEFER_ESTIMATOR — no justified current-observer/Kalman/complementary yet**
- Reason: Plant has no Vc/nu_r; no sensor noise/bias/delay models; controller already has complementary-like rate LPF on truth. A current observer requires a current process model; a Kalman requires C/R measurement models; neither exists without fabricating hardware. First justify by adding one bounded hook.

## PASS gates

| Gate | Result |
|---|---|
| signal_map_complete | PASS |
| hooks_classified | PASS |
| current_nu_r_traced | PASS |
| obs_compare_stated | PASS |
| baselines_ran | PASS |
| zero_pert_documented | PASS |
| residuals_saved | PASS |
| no_production_edit | PASS |

**Overall: PASS**

## Next bounded gate

- **`bounded_plant_current_OR_measurement_noise_hook`**
- Single next bounded gate: introduce ONE explicit hook — either (a) constant/bounded NED current Vc with nu_r=nu-R'*Vc in plant damping+kinematics, OR (b) additive measurement noise on one realistic channel (e.g. depth or DVL u) with documented sigma — then re-run plumbing sensitivity. Do NOT design estimator yet. Production cascade+guidance remain frozen.
- Production remains frozen; no estimator design until a real hook exists.
