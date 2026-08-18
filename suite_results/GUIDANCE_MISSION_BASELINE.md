# GUIDANCE_MISSION_BASELINE_001 — Guidance / mission readiness baseline

**Audit completeness verdict: PASS**

**Mission execution classification: NO** (first=`LEVEL:gamma_MAE(0.7356>0.5000)`)

**Prioritized next gate: `transition_shaper`** — Mission classification FAIL first=`LEVEL:gamma_MAE(0.7356>0.5000)` → next transition shaper.

## Provenance

- Read-only audit sources: `run_path_suite.m`, `continuous_path_tracking.m`, `guidance_law.m`
- Prior: CRAB_CURRENT_FF_CANDIDATE **REJECTED** (R10 rudder sat 6.06→9.00%); production FROZEN
- Driver: `run_guidance_mission_baseline.m` (one MATLAB invocation)
- Production plant/controller/guidance: **UNTOUCHED / FROZEN** (no tuning)
- Hard gates: SPEED_ENVELOPE / COMBINED absolutes (LEVEL≈X, CLIMB≈XZ, TURN≈R10/H, EXIT≈X)
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GUIDANCE_MISSION_BASELINE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GUIDANCE_MISSION_BASELINE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\GUIDANCE_MISSION_BASELINE.png`
- Did **not** touch `CODEX_VERTICAL_PLAN.md`
- Stamp: 2026-08-06 06:11:42 | seed=0 | U=1.50 | T_final=64.0s | s_total=76.19m

## Path input contract

- Shape: Nx3 numeric waypoints [x y z] NED (z positive down in plant; suite paths often z>=0 climb)
- Min N: 2 | Closed if norm(path(1,:)-path(end,:)) < 0.25 (guidance_law.m L63)
- Speed: global desired_speed (init_parameters=1.5); schedule u_ref=desired_speed*R/(R+2.5) clamped
- IC: run_path_suite initial_state_from_path: pos=path(1,:), theta_int=-physical_pitch, psi=atan2(dy,dx), u=u0
- Mission fields: **NOT_IMPLEMENTED — suite passes raw path + T_final only; no segment IDs, waypoints-as-mission, or mode flags**
- Provenance: continuous_path_tracking.m L1 + guidance_law.m L54-59; run_path_suite make_scenario_*

## Projection / progress state

- State: persistent s_prog (arc-length m); legacy next_progress_index integer
- Monotonic: open: s_prog=max(s_prog,s_near-0.05); closed: wrap with ignore ds<-0.25, blend max(ds,-0.05)
- Window: forward search [s_prog-0.15, s_prog+max(3,2.5*L)]
- Depth hold: if z_below>2.5 m, clamp ds_max=0.55*u*dt (L120-129)
- Provenance: guidance_law.m L61-106, L275-279; helpers path_arclength/project_on_path/sample_path

## Lookahead

- L: max(lookahead_distance, 1.0) m (runtime L=1.25 m)
- Use: s_look=s_prog+L → t_look for chi_path / pitch_path; LOS atan2(-y_e, L+0.6)
- Provenance: guidance_law.m L14,L64,L112-118; init_parameters lookahead_distance=1.25

## Command filters / limits

- Yaw: chi_f LPF a=0.28; unwrap yaw_cont; yaw_out slew max 40deg/s *0.35 blend
- Pitch: z_e_f a=0.07; pitch_f a=0.10; pitch_out rate-limited by pitch_ref_rate_max; clamp ±pitch_ref_max
- kappa/r_ff: kappa_f = 0.96*prev + 0.04*raw / U_h*kappa_f clamp ±40 deg/s
- Multi-rate: dt_controller=0.025, dt_guidance=0.075; guidance ZOH between ticks (continuous_path_tracking)
- Runtime: pitch_ref_max=26.0deg rate_max=6.0deg/s δe_max=15.0 δr_max=25.0
- Provenance: guidance_law.m yaw/pitch filters L132-265; continuous_path_tracking ZOH L67-88

## Termination / completion

- Sim stop: Fixed-horizon T_final only — no goal event stop
- near_end: s_prog >= s_total-0.3 → u_ref=0.7*desired_speed; yaw/pitch use local tangent
- Mission complete flag: **NOT_IMPLEMENTED**
- Success criteria API: **NOT_IMPLEMENTED — metrics computed offline by suite helpers**
- Provenance: continuous_path_tracking.m L14-16,L19 (fixed T_final); guidance_law near_end L108,L155-157,L170-174,L187-191

## Transition handling

- Segment blender: **NOT_IMPLEMENTED**
- Clothoid/shaper: **NOT_IMPLEMENTED**
- Mode switch: **NOT_IMPLEMENTED — single open path only**
- Note: Composite continuity must be baked into the waypoint polyline; guidance has no segment awareness
- Provenance: run_path_suite: separate scenarios, clear guidance_law between (L66-67); no multi-segment mission

## Resets / timeouts / replanning

- Mid-mission reset: **NOT_IMPLEMENTED** | bumpless handoff: **NOT_IMPLEMENTED for mission handoff (cold start only)**
- Mission watchdog / stall / acq timeout: **NOT_IMPLEMENTED** / **NOT_IMPLEMENTED** / **NOT_IMPLEMENTED**
- Online repath / avoid / dynamic replan: **NOT_IMPLEMENTED** / **NOT_IMPLEMENTED** / **NOT_IMPLEMENTED**
- Provenance resets: run_path_suite.m L16-18,L66-67 clear guidance_law controller_law; guidance_law persistent initialized
- Provenance replan: absent from run_path_suite / continuous_path_tracking / guidance_law

## Missing mission / fault functions

| Function | Status |
|---|---|
| mission_manager | **NOT_IMPLEMENTED** |
| fault_detection | **NOT_IMPLEMENTED** |
| fault_isolation | **NOT_IMPLEMENTED** |
| safe_mode | **NOT_IMPLEMENTED** |
| abort_recover | **NOT_IMPLEMENTED** |
| sensor_outage_handler | **NOT_IMPLEMENTED** |
| actuator_fail_handler | **NOT_IMPLEMENTED** |

Provenance: no APIs in the three audited sources; ode45 catch in continuous_path_tracking L100-115 is sim abort only

## Composite mission geometry

- Design: LEVEL → CLIMB (raised-cosine) → TURN R10 90° → EXIT
- Continuity: C0 position + C1 unit tangent at junctions; curvature discontinuous at turn entry/exit (no clothoid — NOT_IMPLEMENTED). | pos_ok=YES tang_ok=YES
- Max climb slope=0.3142 (γ≈17.44 deg)

| Segment | s0 [m] | s1 [m] | L [m] | Description |
|---|---:|---:|---:|---|
| LEVEL | 0.00 | 20.00 | 20.00 | Level straight +X z=0.0 L=20.0m |
| CLIMB | 20.00 | 40.00 | 20.00 | Raised-cosine climb Δz=+4.0m over L=20.0m (C1 slope ends) |
| TURN | 40.00 | 55.71 | 15.71 | Horizontal left turn R=10.0 ang=90deg L=15.71m at z=4.0 |
| EXIT | 55.71 | 76.19 | 20.48 | Level exit +Y L=20.0m at z=4.0 |

## Whole-mission metrics

- Progress: mono=YES n_back=0 min_ds=0.0000 final_s=76.14/76.19 (99.9%) complete=YES
- Stall: run=0.00s (lim 2.00s) stalled=NO | mean ds/dt=1.745 m/s
- Bounded states: YES
- Steady window: thMAE=0.8000 gMAE=1.9594 yawMAE=0.5178 CTE=0.380 |e_z|=0.3608 uMAE=0.3161
- Actuators: deSat=0.00% drSatF=0.00% thrSat=0.00% chat=0.2367 deRateU=0.098 drRateU=0.609
- Roll MAE=0.482 deg | φ p_rms=0.844 deg/s | |de|_max=7.40 |dr|_max=12.55 deg

## Per-segment hard gates

| Seg | FEAS | First | thMAE | gMAE | yawMAE | CTE | |ez| | deSat | drSatF | chat | mono |
|---|:---:|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| LEVEL | NO | gamma_MAE(0.7356>0.5000) | 0.0483 | 0.7356 | 0.0000 | 0.199 | 0.1709 | 0.00 | 0.00 | 0.0271 | YES |
| CLIMB | NO | pitch_MAE(1.6186>0.3000) | 1.6186 | 3.4535 | 0.0004 | 0.673 | 0.6473 | 0.00 | 0.00 | 0.0941 | YES |
| TURN | NO | yaw_p95(2.3221>2.0000) | 0.1673 | 0.5478 | 0.6161 | 0.364 | 0.3069 | 0.00 | 0.00 | 0.0833 | YES |
| EXIT | NO | gamma_MAE(0.6417>0.5000) | 0.0988 | 0.6417 | 0.5267 | 0.225 | 0.2369 | 0.00 | 0.00 | 0.0106 | YES |

## Transitions

| Transition | n | max CTE | max |ez| | mono | OK | lim CTE=1.50 |ez|=1.00 |
|---|---:|---:|---:|:---:|:---:|---|
| LEVEL_CLIMB | 88 | 0.337 | 0.285 | YES | YES | |
| CLIMB_TURN | 92 | 0.341 | 0.511 | YES | YES | |
| TURN_EXIT | 100 | 0.373 | 0.340 | YES | YES | |

## PASS gates (audit completeness)

| Gate | Status |
|---|:---:|
| audit_sources_read | PASS |
| contract_documented | PASS |
| NOT_IMPLEMENTED_marked | PASS |
| production_untouched | PASS |
| no_tuning | PASS |
| composite_path_C1 | YES |
| one_6dof_run | YES |
| artifacts_written | PASS |

**Overall audit: PASS**

## Next bounded roadmap gate

- **`transition_shaper`** — Mission classification FAIL first=`LEVEL:gamma_MAE(0.7356>0.5000)` → next transition shaper.
- CODEX_VERTICAL_PLAN untouched.
