# GATE8 R10 YAW AUTHORITY COORDINATED SHADOW SWEEP

**TASK_ID:** `GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_RESUME_001`

**Created:** 2026-08-09 10:19:21 | **Verdict:** **PARTIAL** | **Outcome:** `SCALAR_METHOD_CLOSED`

**Certification:** NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware). Gate9 LOCKED.

> RESUME of an unexecuted predeclared plan. The prior attempt terminated in the bridge with resource_exhausted before any MATLAB process was started and before any artifact was written, so there is no prior result to retry, contradict or reconcile. The plan below is the stored one, unaltered.

> IMPLEMENTED = this isolated shadow driver only. The scale is applied by rebinding two production globals inside a shadow loop; no production file is edited. All priors remain ASSUMED. PG10 forbids promotion on this evidence.

## 1. Question and method

Kd_psi/Kp_psi = 0.40625 s is the only dimensionally meaningful invariant recoverable without external provenance, and the feedforward gain is structurally equal to Kd_psi. Scaling either gain alone therefore changes the derivative time constant and the feedforward authority at the same time, which would confound the result. The sweep must scale the pair together at fixed Td.

- **Scope.** exactly one cell, the frozen R10_U1.5 (index 7 of 8), exactly one nominal horizon of 30 s at dt = 0.025 s, hooks off, no Monte Carlo, no second family. Shadow only: the sweep runs against a shadow copy of the law with production files fingerprinted unchanged.
- **Factor.** s, a single common scale applied to (Kp_psi, Kd_psi) as (s*32, s*13), Td held at 0.40625 s
- **Anchor provenance.** every anchor is derived from stored evidence or from a constant already present in the two permitted source files. No anchor is invented and none is a tuned guess.
- **Open-loop caveat.** the headroom anchor is algebra on the stored raw command. Changing the gains changes the trajectory, so it is an entry bracket, NOT a prediction of the closed-loop result. The sweep exists precisely because the saturated log cannot identify the right scale: the heading error that sets the command is itself produced by the saturated loop.
- **Smallest argument.** this is the smallest experiment that can settle the question: one cell, one horizon, one scalar factor, four predeclared points, no new law, no new signal, no shaper, no current feedforward, and every gate computable from the same instrumentation that already exists in the frozen record.

NO shaper, NO current feedforward, NO path or waypoint change, NO threshold change, NO guidance change, NO limiter change and NO new signal were introduced. The only quantity varied across the sweep is the single scalar s multiplying the coordinated pair.

## 2. Sources, frames and protected set

Exactly three paths were opened for content.

| # | source | role | fingerprint |
|---|---|---|---|
| 1 | `controller_law.m` | READ | production yaw command equation: the two coefficients being scaled, g_ac schedule, limiter order, sample time | `n=9402.s1=732890.s2=3334742186` |
| 2 | `run_gate8_actuator_order_scan_repair.m` | READ | frozen shadow reduction of the production tracking loop, frozen R10 cell geometry, hash and fingerprint primitives | `n=121098.s1=9464134.s2=3103638627` |
| 3 | `suite_results/GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT.mat` | READ | predeclared shadow plan: anchors, gate texts, recorded thresholds, frozen nominal hash, protected file list | `n=194818.s1=25262169.s2=116376547` |

CONFIRMED: exactly three paths were opened for content. Production files are EXECUTED and FINGERPRINTED but not read for reasoning, which is the same treatment the permitted source #2 gives them.

**Frames and units.** Positions NED in metres with z positive down (depth = +z); BODY rates p,q,r in rad/s and BODY velocity u,v,w in m/s; Euler angles in rad internally and deg only where a name says so; rudder deflection in deg with a 25 deg magnitude envelope and a 40 deg/s rate envelope; curvature in 1/m; dwell fractions are dimensionless fractions of the 30 s horizon; rudder energy proxies are deg*s and deg^2*s; thrust energy is in the native production thrust unit, which this task does not assume to be per-unit.

| # | protected file | fingerprint pre | unchanged post | identical to audit record |
|---|---|---|---|---|
| 1 | `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | yes | yes |
| 2 | `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | yes | yes |
| 3 | `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | yes | yes |
| 4 | `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | yes | yes |
| 5 | `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990739` | yes | yes |
| 6 | `suite_results/CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | yes | yes |
| 7 | `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.mat` | `n=271512.s1=35429352.s2=2569622525` | yes | yes |

production tracker, controller, guidance, plant, path metrics, CODEX_VERTICAL_PLAN and the frozen evidence mat are byte-identical pre and post. The scale enters only by rebinding the Kp_psi / Kd_psi globals inside the shadow loop after init_parameters(), which leaves no residue on disk.

## 3. Experiment definition

- Cell `R10_U1.5`, family R10, U = 1.50 m/s, 26 waypoints, one nominal horizon of 30 s at dt = 0.025 s (guidance 0.075 s), hooks off, no Monte Carlo, no disturbance.
- Coordinated pair `(Kp_psi, Kd_psi) = (32*s, 13*s)`; derivative time constant `Td = Kd_psi/Kp_psi = 0.406250 s` held at every anchor by construction; the yaw-rate feedforward enters as `+Kd_psi*r_ff` and is therefore tied to Kd_psi with no separate knob.
- byte-identical copy of the R10 branch of g9_cells() in permitted source #2 (radius 10 m, 1.25 turns, 26 waypoints, 5->8 m depth ramp, U = 1.5 m/s, initial heading from the first waypoint pair). It remains an ASSUMED_RECONSTRUCTION of the frozen cell; the s = 1 hash parity check in PG1 is what makes that assumption falsifiable rather than convenient.
- every run calls the same reset used by permitted source #2 (clear global, then clear of guidance_law / controller_law / init_parameters / the plant and the production tracker) before init_parameters(), so no persistent integrator, no filter state and no limiter memory crosses an anchor boundary. The reverse-order replay is the proof, not the claim.
- rail dwell = fraction of samples with |delta_r_plant| >= 25 deg - 1e-9. magnitude dwell = fraction with |dr_raw| > 25 deg. rate dwell = fraction of samples on which the magnitude-limited target moved further than one rate tick (40 deg/s * dt = 1.0 deg) from the previous PLANT deflection, i.e. the second limiter stage actually clipped. All three are dimensionless fractions of the 30 s horizon and are computed identically for the stored record and for every anchor.

**Anchors evaluated (exactly the four stored, nothing between them):**

1. `s = 1.000000000` - s = 1.000000 : frozen control, must reproduce the stored nominal hash n=153600.s1=19094896.s2=2901292177 bit-for-bit
2. `s = 0.260416667` - s = 0.260417 : design-point anchor, makes Kp_psi*e_psi0 equal the 25 deg envelope at the g_ac corner the code declares
3. `s = 0.053570717` - s = 0.053571 : headroom anchor, the algebraic scale at which the STORED raw command peak fits the envelope
4. `s = 0.017453293` - s = 0.017453 : unit-conversion anchor, a single rad->deg de-scaling, admissible but unproved

## 4. PG1 frozen-control parity

| item | value |
|---|---|
| s = 1 hash this run | `n=153600.s1=19094896.s2=2901292177` |
| frozen recorded hash | `n=153600.s1=19094896.s2=2901292177` |
| bit-for-bit equal | **yes** |
| sweep void | **no** |

Independent metric parity of the s = 1 anchor against the stored derived log, same estimators:

| metric | this run | stored record | abs diff | within 1e-06 rel |
|---|---|---|---|---|
| raw_absmax_deg | 466.672861 | 466.672861 | 0.000e+00 | yes |
| raw_medabs_deg | 129.806576 | 129.806576 | 0.000e+00 | yes |
| P_absmax_deg | 434.537584 | 434.537584 | 0.000e+00 | yes |
| RATE_absmax_deg | 189.290573 | 189.290573 | 0.000e+00 | yes |
| rolldamp_absmax | 6.24324816 | 6.24324816 | 0.000e+00 | yes |
| magsat_dwell | 0.890833333 | 0.890833333 | 0.000e+00 | yes |
| rail_dwell | 0.281666667 | 0.281666667 | 0.000e+00 | yes |
| rate_dwell | 0.691666667 | 0.691666667 | 0.000e+00 | yes |
| transmitted_frac | 0.109166667 | 0.109166667 | 0.000e+00 | yes |
| e_psi_absmax_deg | 13.5792995 | 13.5792995 | 0.000e+00 | yes |
| g_ac_median | 0.244040718 | 0.244040718 | 0.000e+00 | yes |

**Cross-track definition.** CTE3D = minimum Euclidean distance from the vehicle position to the 3-D waypoint polyline; CTE_HORIZ = the same distance taken in the horizontal (x,y) plane only. Both are reported for every anchor. The primary is the one that reproduces the frozen record at s = 1. Primary definition selected on the control point: `CTE_HORIZ` (s = 1 residual against the frozen record 2.690e-04, matches record: no).

## 5. Every anchor, in full

No anchor is dropped, re-ordered by outcome or summarised away.

### 5.1 Command, limiter and authority

| s | Kp_psi | Kd_psi | Td [s] | raw absmax [deg] | raw med [deg] | mag dwell | rail dwell | rate dwell | slew [deg/s] | med abs delta_r [deg] | transmitted |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1.000000000 | 32.00000 | 13.00000 | 0.406250 | 466.6729 | 129.8066 | 0.890833 | 0.281667 | 0.691667 | 40.0000 | 15.0000 | 0.109167 |
| 0.260416667 | 8.33333 | 3.38542 | 0.406250 | 76.9106 | 14.2004 | 0.393333 | 0.056667 | 0.773333 | 40.0000 | 8.8231 | 0.605833 |
| 0.053570717 | 1.71426 | 0.69642 | 0.406250 | 22.7698 | 5.9205 | 0.000000 | 0.000000 | 0.160000 | 40.0000 | 5.7177 | 0.999167 |
| 0.017453293 | 0.55851 | 0.22689 | 0.406250 | 15.2751 | 4.4547 | 0.000000 | 0.000000 | 0.036667 | 40.0000 | 4.4547 | 0.999167 |

### 5.2 Grouped term decomposition (PG8)

| s | P absmax | RATE_ERR absmax | ROLLDAMP absmax | P median | RATE median | completeness resid |
|---|---|---|---|---|---|---|
| 1.000000000 | 434.5376 | 189.2906 | 6.2432 | 156.0755 | 54.6439 | 1.137e-13 |
| 0.260416667 | 94.0775 | 34.6427 | 3.4411 | 24.9213 | 10.1814 | 2.132e-14 |
| 0.053570717 | 28.0956 | 5.5381 | 1.4827 | 6.1275 | 0.7614 | 7.105e-15 |
| 0.017453293 | 16.3107 | 1.2624 | 0.5780 | 4.5493 | 0.2272 | 3.553e-15 |

### 5.3 Tracking, geometry and safety

| s | cte absmax [m] | cte median [m] | cte horiz absmax | cte horiz med | e_psi sustained median [deg] | e_psi absmax [deg] | depth band [m] | phi absmax [deg] | r absmax [deg/s] | stable |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.000000000 | 0.285654 | 0.220764 | 0.212619 | 0.100511 | 6.6560 | 13.5793 | 4.970..6.702 | 5.1150 | 15.2094 | yes |
| 0.260416667 | 0.260426 | 0.210884 | 0.150100 | 0.059647 | 2.8574 | 11.2893 | 4.970..6.679 | 3.7256 | 15.3911 | yes |
| 0.053570717 | 0.376191 | 0.221359 | 0.333742 | 0.061437 | 3.2957 | 16.3893 | 4.970..6.665 | 2.7569 | 14.5474 | yes |
| 0.017453293 | 0.907949 | 0.291600 | 0.892433 | 0.212789 | 7.6739 | 29.2042 | 4.970..6.615 | 2.3458 | 12.7125 | yes |

### 5.4 Energy and timing

| s | rudder abs [deg*s] | rudder sq [deg^2*s] | elevator abs [deg*s] | thrust abs [native*s] | reversals | mean u [m/s] | runtime [s] |
|---|---|---|---|---|---|---|---|
| 1.000000000 | 446.904 | 8970.884 | 161.881 | 138.022 | 40 | 1.5788 | 18.04 |
| 0.260416667 | 323.435 | 5258.012 | 162.642 | 142.490 | 32 | 1.5729 | 15.89 |
| 0.053570717 | 184.452 | 1780.432 | 163.551 | 144.919 | 24 | 1.5700 | 16.25 |
| 0.017453293 | 154.546 | 1262.758 | 164.238 | 144.801 | 12 | 1.5689 | 16.23 |

### 5.5 Per-anchor gate matrix

| s | PG2 | PG3 | PG4 | PG5 | PG6 | PG7 | PG8 | stable | clears PG2-PG8 | candidate eligible |
|---|---|---|---|---|---|---|---|---|---|---|
| 1.000000000 | **FAIL** | **FAIL** | PASS | **FAIL** | **FAIL** | **FAIL** | **FAIL** | PASS | **FAIL** | control (excluded by definition) |
| 0.260416667 | **FAIL** | **FAIL** | PASS | PASS | **FAIL** | **FAIL** | **FAIL** | PASS | **FAIL** | **FAIL** |
| 0.053570717 | PASS | PASS | PASS | **FAIL** | PASS | **FAIL** | **FAIL** | PASS | **FAIL** | **FAIL** |
| 0.017453293 | PASS | PASS | PASS | **FAIL** | PASS | **FAIL** | PASS | PASS | **FAIL** | **FAIL** |

## 6. Bitwise replay

Every anchor was re-executed after a full state reset, in reverse anchor order.

| anchor | s | replay hash | matches forward pass |
|---|---|---|---|
| 4 | 0.017453293 | `n=153600.s1=19061687.s2=2310856108` | yes |
| 3 | 0.053570717 | `n=153600.s1=19041590.s2=3117087358` | yes |
| 2 | 0.260416667 | `n=153600.s1=19126824.s2=732619342` | yes |
| 1 | 1.000000000 | `n=153600.s1=19094896.s2=2901292177` | yes |

Replay all matched: **yes** over 4 runs.

## 7. Pareto view

Pareto is reported over five axes with no scalarisation and no weighting: tracking (cross-track absmax and median, sustained heading error), actuator (raw command absmax, magnitude dwell, rail dwell, rate dwell, realized slew, median standing authority, reversals), energy (rudder absolute and squared deflection integrals, elevator and thrust integrals in native units), timing (wall-clock per anchor and per step) and safety (depth band, attitude and rate extrema, finiteness). No axis is traded against another by this driver; the trade is left visible.

front computed over minimised {cte absmax, cte median, raw command absmax, rail dwell, rate dwell, rudder absolute effort} plus maximised median standing authority. It is descriptive: no anchor is selected by it, and PG scoring is not derived from it.

| s | cte_absmax_m | cte_medabs_m | e_psi_median_sus_deg | raw_absmax_deg | magsat_dwell | rail_dwell | rate_dwell | slew_max_degs | dr_plant_medabs | n_reversals | E_rudder_abs | E_rudder_sq | E_elevator_abs | E_thrust_abs | runtime_s | depth_min | depth_max | phi_absmax_deg | r_absmax_degs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---||
| 1 | 0.212619 | 0.100511 | 6.65597 | 466.673 | 0.890833 | 0.281667 | 0.691667 | 40 | 15 | 40 | 446.904 | 8970.88 | 161.881 | 138.022 | 18.0431 | 4.96982 | 6.70197 | 5.11497 | 15.2094 |
| 0.260417 | 0.1501 | 0.0596474 | 2.85742 | 76.9106 | 0.393333 | 0.0566667 | 0.773333 | 40 | 8.82315 | 32 | 323.435 | 5258.01 | 162.642 | 142.49 | 15.8949 | 4.96982 | 6.6794 | 3.72563 | 15.3911 |
| 0.0535707 | 0.333742 | 0.0614366 | 3.2957 | 22.7698 | 0 | 0 | 0.16 | 40 | 5.71767 | 24 | 184.452 | 1780.43 | 163.551 | 144.919 | 16.2474 | 4.96983 | 6.66525 | 2.7569 | 14.5474 |
| 0.0174533 | 0.892433 | 0.212789 | 7.67392 | 15.2751 | 0 | 0 | 0.0366667 | 40 | 4.45466 | 12 | 154.546 | 1262.76 | 164.238 | 144.801 | 16.227 | 4.9698 | 6.61455 | 2.34583 | 12.7125 |

Non-dominated anchor indices: [1 2 3 4].

## 8. Gates

| id | pass | requirement | evidence |
|---|---|---|---|
| PG1 | PASS | at s = 1 the shadow reproduces the frozen nominal cell bit-for-bit against hash n=153600.s1=19094896.s2=2901292177. Any mismatch voids the whole sweep. | s=1 hash n=153600.s1=19094896.s2=2901292177 vs frozen n=153600.s1=19094896.s2=2901292177 (equal=1); independent metric parity against the stored derived log 11/11 within 1e-06 relative (worst /diff/ 0.000e+00 on raw_absmax_deg) |
| PG2 | PASS | the candidate scale drives /dr_raw/ absmax <= 25 deg over the full horizon, i.e. the magnitude limiter never engages, measured not assumed. | raw_absmax_deg vs threshold 25.000000 / s=1.000000:466.6729deg[PG2=0] s=0.260417:76.9106deg[PG2=0] s=0.053571:22.7698deg[PG2=1] s=0.017453:15.2751deg[PG2=1] |
| PG3 | PASS | magnitude-limiter dwell = 0 and rail dwell = 0, against the recorded 0.890833 and 0.281667. | magsat_dwell/rail_dwell vs 0.890833/0.281667 / s=1.000000:0.890833/0.281667[PG3=0] s=0.260417:0.393333/0.056667[PG3=0] s=0.053571:0.000000/0.000000[PG3=1] s=0.017453:0.000000/0.000000[PG3=1] |
| PG4 | PASS | standing authority preserved: median /delta_r/ >= the recorded plant steady-turn requirement of 4.058 deg, so the de-scaled loop can still hold the R10 circle. This gate is what refutes the unit-conversion anchor if it fails. | dr_plant_medabs vs threshold 4.058000 / s=1.000000:15.0000deg[PG4=1] s=0.260417:8.8231deg[PG4=1] s=0.053571:5.7177deg[PG4=1] s=0.017453:4.4547deg[PG4=1] |
| PG5 | PASS | path following no worse than the frozen record: /cte/ absmax <= 0.212619 m and median <= 0.100242 m. Declared in advance as a gate, not claimed in advance as a result. | cte_absmax_m/cte_medabs_m vs 0.212619/0.100242 / s=1.000000:0.212619/0.100511[PG5=0] s=0.260417:0.150100/0.059647[PG5=1] s=0.053571:0.333742/0.061437[PG5=0] s=0.017453:0.892433/0.212789[PG5=0] |
| PG6 | PASS | roll-damp authority restored: the roll damp is transmitted to the plant on >= 0.95 of the horizon, against 0.109167 now. | transmitted_frac vs threshold 0.950000 / s=1.000000:0.1092-[PG6=0] s=0.260417:0.6058-[PG6=0] s=0.053571:0.9992-[PG6=1] s=0.017453:0.9992-[PG6=1] |
| PG7 | **FAIL** | rate-limiter dwell strictly below the recorded value and realized slew strictly below the 40 deg/s envelope. | rate_dwell/slew_max_degs vs 0.691667/40.000000 / s=1.000000:0.691667/40.000000[PG7=0] s=0.260417:0.773333/40.000000[PG7=0] s=0.053571:0.160000/40.000000[PG7=0] s=0.017453:0.036667/40.000000[PG7=0] |
| PG8 | PASS | the rail must not merely migrate: at the candidate scale no single term of the grouped decomposition {P, -Kd*(r-r_ff), g_ac*(-Kp_roll*p)} may reach the envelope alone. | grouped term absmax vs 25 deg envelope / s=1.000000: P=434.538 RATE=189.291 ROLL=6.243 [PG8=0] s=0.260417: P=94.077 RATE=34.643 ROLL=3.441 [PG8=0] s=0.053571: P=28.096 RATE=5.538 ROLL=1.483 [PG8=0] s=0.017453: P=16.311 RATE=1.262 ROLL=0.578 [PG8=1] |
| PG9 | PASS | production, plant, metrics and CODEX_VERTICAL_PLAN fingerprints unchanged pre and post; footprint < 100 MiB; one MATLAB invocation; no retry. | protected set unchanged=1, identical to the audit record 7/7, MATLAB invocations=1 (pid 23828, prior lock 0), no retry. Footprint checked after artifact write. Footprint 0.481 MiB < 100 MiB = 1; fingerprints still unchanged after artifact write = 1. |
| PG10 | PASS | NO promotion on this sweep even if every gate passes. Promotion additionally requires a second independent cell family and a disturbance case, and Gate9 stays locked with hardware NOT_CERTIFIED. | promotion is FORBIDDEN on this evidence and none is claimed: 0 anchor(s) cleared PG1-PG9 and the result is carried as a shadow candidate for independent-cell plus disturbance validation only. Gate 9 stays LOCKED, hardware NOT_CERTIFIED. |

Hard gates all pass: **no**. Failed: PG7.

## 9. Predeclared falsifiers

| id | triggered | falsifier | evidence |
|---|---|---|---|
| F1 | no | if PG2 passes but PG4 fails at every anchor, the gain scale is not the binding constraint and the finding is that the guidance geometric offset must be reduced instead, which is a different and larger change | PG2 cleared at 2/3 candidate anchors, PG4 cleared at 3/3 |
| F2 | no | if PG2 and PG4 both pass only at the unit-conversion anchor, that is the first real evidence for a units defect and the provenance question must then be reopened with the parameter-setting file in scope | unit anchor (index 4) PG2=1 PG4=1; other candidate anchors clearing both = 1 |
| F3 | no | if PG8 fails, the rail is genuinely multi-term and no scalar rescaling can be the answer | PG8 cleared at 1/3 candidate anchors |

## 10. Finding, candidate status and next method

**Outcome: `SCALAR_METHOD_CLOSED`.** no stored anchor cleared PG1-PG9. The coordinated scalar rescaling of (Kp_psi, Kd_psi) at fixed Td is therefore CLOSED as a method for this failure: the rail is not removable by a common gain scale without losing something the gates protect.

**No candidate is named.**

**Promotion claimed:** no. **Gate 9:** LOCKED. **Hardware:** NOT_CERTIFIED.

### 10.1 Evidenced next method (POST-RUN ADDENDUM)

> **Provenance of this subsection.** It was written after the single MATLAB
> invocation completed and MATLAB was NOT re-run to produce it. The driver's
> `SCALAR_METHOD_CLOSED` branch left `R.next_method` empty, so
> `GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP.mat` and the three appended
> logs carry the closure but not this statement. Every number quoted below is
> read out of the tables above or out of the stored audit; nothing here was
> re-measured, re-simulated or re-scored, and no gate verdict is changed by it.

**Why the scalar method is closed, stated as the measurement rather than as an opinion.**
The four anchors move the two things the gates protect in opposite directions,
monotonically, with no crossing point:

- the magnitude rail and the roll-damp starvation are removable by scale: at
  `s = 0.053571` and `s = 0.017453` the magnitude dwell and rail dwell are exactly
  0 and the roll damp is transmitted on 0.9992 of the horizon against 0.1092 at
  the frozen control (PG2, PG3, PG6 all clear);
- but path following degrades across exactly those anchors: cross-track absmax
  goes 0.2126 -> 0.1501 -> 0.3337 -> 0.8924 m and sustained heading error goes
  6.66 -> 2.86 -> 3.30 -> 7.67 deg, so PG5 fails at both anchors that clear PG2;
- the only anchor that clears PG8, `s = 0.017453`, is the worst PG5 anchor of the
  four.

PG4 held at every anchor (median authority 15.00, 8.82, 5.72, 4.45 deg against
the 4.058 deg requirement), so the standing-turn requirement is *not* the binding
constraint and falsifier F1 did not fire. The binding constraint is path
accuracy, and it is what the scale cannot buy.

**What the residual PG7 failure identifies.** PG7 failed at all four anchors on
the same clause: realized slew is 40.0000 deg/s exactly everywhere, including at
`s = 0.017453` where the gain is 57x smaller than the frozen control. Rate dwell
does collapse with scale (0.6917 -> 0.1600 -> 0.0367), so the *sustained* rate
clipping is gain-driven, but at least one tick still saturates the rate rail at
every scale. A quantity that survives a 57x gain reduction is not produced by
gain. The stored audit records the mechanism directly: the yaw reference is
updated on the 0.075 s guidance grid and held on the 0.025 s controller grid,
with a maximum per-call increment of 2.6353 deg. Even at the smallest anchor,
`Kp_psi * 2.6353 deg = 0.5585 * 2.6353 = 1.47 deg` of commanded step against a
one-tick rate allowance of `40 deg/s * 0.025 s = 1.00 deg`. The rate rail is a
multirate reference-staircase artefact, not a yaw-authority artefact.

**Why the proportional term is not a gain problem either.** The stored audit
records `P_from_geometry = P_observed_median = 166.0697 deg` - the median
proportional command is *entirely* accounted for by the geometric lookahead lead
`L_eff * kappa` (recovered `L_eff = 0.9158 m` on a 0.1002 1/m path, i.e. about
5.25 deg of standing heading offset that the rudder channel carries no integral
state to null). A term whose median is fully explained by a geometric reference
offset is corrected by removing the offset, not by shrinking the coefficient that
multiplies it - and this sweep is the direct confirmation, because shrinking that
coefficient is exactly what pushed cross-track from 0.2126 m to 0.8924 m.

**Evidenced next method, in priority order.**

1. `gate8_r10_guidance_course_reference_offset_identification` - an isolated,
   shadow-only, read-first identification of the standing `L_eff * kappa` course
   lead on the same frozen R10_U1.5 cell: establish whether the lookahead course
   reference can be made curvature-consistent so that the sustained heading error
   goes to zero on a constant-curvature path, which removes the *demand* for the
   166 deg median proportional command instead of removing the authority to
   deliver it. Acceptance must keep PG4 and PG5 as they are written here and add
   a parity gate against the same frozen hash. This is the method the evidence
   points at, and it is a guidance change, so it is out of scope of the present
   task by construction.
2. `gate8_r10_yaw_reference_multirate_seam` - a separate, smaller task for the
   residual PG7 clause: quantify, on the frozen cell, how much of the 40 deg/s
   slew rail is the 0.075 s / 0.025 s reference staircase, by measuring the
   commanded step distribution against the one-tick allowance. This is
   deliberately kept separate from item 1 so that a guidance change and a
   multirate change are never argued from the same run.

Neither item may be started as a tuning exercise: both are identification tasks
first, with the frozen-hash parity gate as the entry condition, exactly as PG1
was used here. Gate 9 stays **LOCKED** and hardware stays **NOT_CERTIFIED**
regardless of their outcome.

## 11. Artifacts, resources and visual QA

- Wall-clock runtime 165.8 s; MATLAB invocations 1 (pid 23828, prior lock present 0); no retry.
- Artifact footprint 0.481 MiB, PG9 limit 100 MiB (met), task budget 150 MiB (met).
- Free disk at start 4.43 GiB.
- Visual QA verdict **VISUAL_QA_PASS** (6/6 checks pass, 2/2 files ok).
- `suite_results/GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP.md`
- `suite_results/GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP.mat`
- `suite_results/GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP.png`
- `suite_results/GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_02_visual_qa.png`
- `suite_results/GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_run.log`

All priors remain **ASSUMED**. Simulation is never hardware certification (**NOT_CERTIFIED**). Gate 9 remains **LOCKED**.
