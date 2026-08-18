# GATE8\_R10\_GUIDANCE\_COURSE\_REFERENCE\_OFFSET\_IDENTIFICATION\_001

- **Verdict**: `BLOCKER`
- **Outcome**: `BLOCKER_STORED_YAW_REF_NOT_IDENTIFIABLE`
- **Created**: 2026-08-09 11:02:40
- **Certification**: NOT_CERTIFIED (simulation-only; no HIL, no bench, no hardware). Gate9 LOCKED.
- **Gate9**: LOCKED  **Hardware**: NOT_CERTIFIED  **Promotion claimed**: 0
- **MATLAB invocations**: 1 (single invocation, no retry)

## 0. Headline

The yaw-reference chain of the frozen R10_U1.5 cell carries a **sustained, curvature-proportional course lead**. It is an exact consequence of taking the path tangent at the lookahead point rather than at the projection point: on constant curvature the lead is `kappa*L` by identity, reduced to `kappa*L_eff` by the two guidance-rate blends. The yaw loop has no integrator, so the lead appears one-for-one in `e_psi` and is amplified by `Kp_psi = 32` into the raw rudder command.

**The mandated precondition fails.** Component-sum closure against the *stored* `yaw_ref` is impossible: the frozen control log in the permitted evidence stores ten signals and `yaw_ref` is not one of them, nor is `psi`. The only column containing `yaw_ref` is `e_psi = wrapToPi(yaw_ref - psi)`, which is rank 1 in two unknowns. Per the task rule, **no shadow reference candidate is stated** and the result is a blocker.

## 1. Sources and attestation

| # | path | role | fingerprint |
|---|---|---|---|
| 1 | `guidance_law.m` | READ. The complete yaw-reference construction: projection, lookahead tangent, course LPF, LOS cross-track term, curvature estimator, crab term, unwrap, blend/slew limiter, multirate hold | `n=14601.s1=1095745.s2=3464382495` |
| 2 | `controller_law.m` | READ. The consumer of yaw_ref: e_psi = wrapToPi(yaw_ref - psi), Kp_psi, Kd_psi, r_ff entry, limiter order - fixes what a reference offset does downstream | `n=9402.s1=732890.s2=3334742186` |
| 3 | `suite_results\GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP.mat` | READ. Frozen R10_U1.5 cell geometry, frozen gains, frozen nominal hash, recorded PG thresholds and the stored per-tick control log of the frozen control anchor | `n=169819.s1=21872822.s2=3194115190` |

CONFIRMED: exactly three paths were opened for content. init_parameters.m was EXECUTED to recover the production lookahead_distance and was never opened for content; it is fingerprinted pre and post. No directory listing, no search, no other file read.

**Fingerprint algorithm (recovered, not redefined)**: fp(file) = sprintf('n=%d.s1=%d.s2=%d', n, sum(double(b)), mod(sum((1:n)'.*double(b)), 2^32)) over the raw byte stream b of length n. Recovered by exact reproduction of the recorded fingerprints of permitted sources #1 and #2, so this attestation reuses the frozen scheme and does not redefine it.

- frozen nominal hash `n=153600.s1=19094896.s2=2901292177`
- anchor-1 (frozen control, s = 1) hash `n=153600.s1=19094896.s2=2901292177`
- recorded PG1 hash now / frozen `n=153600.s1=19094896.s2=2901292177` / `n=153600.s1=19094896.s2=2901292177`
- hash chain equal: **1**; recorded PG1 pass: **1**; anchor 1 is the control (s = 1): **1**

| protected file | recorded fingerprint | fingerprint now | match |
|---|---|---|---|
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | `n=10845.s1=886194.s2=515073390` | 1 |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | `n=9402.s1=732890.s2=3334742186` | 1 |
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | `n=14601.s1=1095745.s2=3464382495` | 1 |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | `n=6065.s1=426918.s2=1254438441` | 1 |
| `compute_path_following_metrics.m` | `n=11604.s1=883372.s2=792990739` | `n=11604.s1=883372.s2=792990739` | 1 |
| `suite_results\CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | `n=43101.s1=4310210.s2=3268810005` | 1 |
| `suite_results\GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.mat` | `n=271512.s1=35429352.s2=2569622525` | `n=271512.s1=35429352.s2=2569622525` | 1 |

Gate A frozen-hash attestation: **PASS**

`lookahead_distance` provenance: init_parameters() was EXECUTED and the production global lookahead_distance read out of the workspace. The file was never opened for content. Result `L = 1.25` m. `init_parameters.m` fingerprint unchanged pre/post: **1**. Executed environment cross-attested against the frozen record (Kp_psi, Kd_psi, Kp_roll, delta_r_max): **0**.

## 2. Reference component inventory (units and frames)

| id | component | expression | units | frame | role |
|---|---|---|---|---|---|
| R1 | path tangent at the projection point | `t_hat = (path(i+1,:) - path(i,:))/norm(...)` | unit vector, dimensionless | 3-D inertial NED, z positive down | used by the near_end branch and to build the cross-track normal; on a chord polyline it is piecewise constant and steps by dtheta at every node |
| R2 | lookahead course (the LOS course lead) | `chi_path = atan2(t_look(2), t_look(1)), t_look sampled at s_prog + L` | rad | horizontal inertial course, NED x-y | THE geometric lead. Equals chi(s_prog) + kappa*L exactly on constant curvature. Taken from the TANGENT at the lookahead point rather than the chord bearing to it, hence twice the inscribed-angle pure-pursuit lead |
| R3 | course low-pass | `chi_f = chi_f + 0.28*wrapToPi(chi_path - chi_f)` | rad | horizontal inertial course | filters the 18 deg staircase before unwrap; on a ramp it retards the course by (1-0.28)/0.28 guidance ticks, i.e. subtracts U_h*dt_g*2.571429 m of effective lookahead |
| R4 | signed cross-track term | `chi_los = atan2(-y_e, L + 0.6), weighted 0.75; y_e = dot(cte(1:2), n_h), n_h = [-t_h(2), t_h(1)]` | rad | horizontal inertial course increment; y_e in m, positive to port of the tangent | the only sustained reference term besides the lead and the crab term. Zero when the vehicle is on the path, so it contributes nothing to the on-path geometric bias |
| R5 | curvature estimate | `kappa_raw = ang(t(s-ds), t(s+ds))/(2*ds), ds = max(0.4, 0.05*s_total); kappa_f = 0.96*kappa_f + 0.04*kappa_raw` | rad/m | horizontal inertial | on a chord polyline the window spans a non-integer number of segments so kappa_raw is a two-level staircase; the heavy 0.04 blend averages it to dtheta/seg_len, i.e. 1/R inflated by dtheta^2/24. Feeds r_ff = U_h*kappa_f only, NOT the course reference |
| R6 | crab / sideslip compensation | `yaw_raw includes -k_beta*beta with k_beta = 1.35, beta = atan2(v_body, max(u_body, 0.35))` | rad | body sideslip subtracted from an inertial course to form a heading | the exact horizontal kinematics are course = psi + beta, i.e. k_beta = 1. The extra 0.35*beta is a second sustained reference bias, driven by the same turn |
| R7 | wrapping | `yaw_raw = wrapToPi(...); yaw_cont = yaw_cont + wrapToPi(yaw_raw - yaw_cont)` | rad | horizontal inertial yaw | yaw_raw is folded to (-pi, pi] then re-unwrapped into a continuous yaw_cont. The returned yaw_ref is UNWRAPPED and grows past pi over 1.25 turns; the controller re-wraps it in e_psi = wrapToPi(yaw_ref - psi) |
| R8 | blend and slew limit | `dy = clamp(0.35*(yaw_cont - yaw_out), +/- deg2rad(40)*dt_nom); yaw_out = yaw_out + dy` | rad | horizontal inertial yaw | the 0.35 blend is a second first-order lag retarding the ramp by (1-0.35)/0.35 guidance ticks; the 3 deg per guidance tick clamp is the slew limit, a hard nonlinearity that engages only on large steps |
| R9 | multirate hold | `yaw_ref is produced on dt_guidance = 0.075 s and consumed on dt_controller = 0.025 s` | s | n/a | zero-order hold across 3 controller ticks. Both guidance blends advance at dt_guidance, so the lag constants are in guidance ticks, which is what makes L_eff depend on dt_guidance and not dt_controller |
| R10 | downstream consumption | `e_psi = wrapToPi(yaw_ref - psi); dr_yaw = Kp_psi*e_psi - Kd_psi*(r - r_ff)` | rad into rudder command | inertial yaw error | no integrator anywhere in the yaw loop, so any sustained reference bias appears one-for-one in e_psi and is amplified by Kp_psi = 32 into the raw rudder command |

Multirate hold: `yaw_ref` is produced at `dt_guidance = 0.0750 s` and held zero-order across `3` controller ticks of `dt_controller = 0.0250 s`. yaw_ref is recomputed once per guidance tick and held zero-order across dt_guidance/dt_controller controller ticks. Every guidance-side filter and the yaw_out blend/slew limiter therefore advance at dt_guidance, not dt_controller. This is the multirate hold and it is what sets the lag constants below.

Two blocks of `guidance_law.m` are inactive on this cell and are therefore not part of the reconstruction: the closed-path branch (`is_closed` is false, the endpoints are 14.4 m apart) and the depth progress hold (`z_below > 2.5` never occurs).

## 3. Exact chord geometry of the frozen cell

| quantity | value | units |
|---|---|---|
| waypoints | 26 | - |
| fitted circle centre | (-0.000000, 10.000000) | m |
| fitted radius R | 10.000000 (max node residual 5.329e-15) | m |
| turn per segment dtheta | 18.000000 (spread 1.018e-13) | deg |
| segment length, 3-D | 3.130990 (spread 2.531e-14) | m |
| segment length, horizontal chord | 3.128689 | m |
| depth ramp per segment | 0.120000 | m |
| total path length | 78.274743 | m |
| total tangent turn | 432.0000 | deg |
| kappa_true = 1/R | 0.10000000 | 1/m |
| kappa_chord = dtheta/seg_len | 0.10033864 | 1/m |
| chord excess over 1/R | +0.3386 | % |
| curvature window 2ds | 7.827474 (= 2.5000 segments) | m |

kappa_chord = dtheta/seg_len = 1/(R*sinc(dtheta/2)) for a planar chord, with leading term (1/R)*(1 + dtheta^2/24); the 3-D segment length also carries the depth ramp, which lengthens the segment and slightly lowers kappa_chord

Because the curvature window spans a non-integer number of segments, `kappa_raw` is a two-level staircase alternating between 2 and 3 node crossings; the 0.96/0.04 blend is what turns it into the mean `kappa_chord`.

## 4. Geometric derivation of the steady course lead

1. STEP 1 (exact, circle). On a path of constant curvature kappa the course angle is chi(s) = chi(0) + kappa*s. The law samples the unit tangent at s_prog + L, so its raw course command leads the tangent at the projection point by exactly kappa*L [rad]. This is an identity, not a fit.
2. STEP 2 (exact, chord). The frozen path is a chord polyline, not a circle. Each segment tangent equals the chord direction, which is the mean of the circle tangent over that segment, so the staircase chi(s) has the same mean slope as the circle. That slope is kappa_chord = dtheta/seg_len = 1/(R*sinc(dtheta/2)), exceeding 1/R by dtheta^2/24 to leading order. path_curvature_at averages over 2*ds = 0.1*s_total and returns exactly this mean, so kappa_f converges to kappa_chord and NOT to 1/R.
3. STEP 3 (inscribed angle, chord). Aiming at the point L ahead ON the circle would give a lead of kappa*L/2 by the inscribed-angle theorem, because the chord from the projection point to the lookahead point subtends half the enclosed arc. The law instead uses the TANGENT at that point, so it leads by kappa*L: exactly twice the pure-pursuit chord bearing, and a full kappa*L above the on-path steady requirement of zero lead.
4. STEP 4 (multirate lag). The course LPF and the yaw_out blend both advance once per guidance tick. A first-order blend y += a*(x - y) driven by a ramp of slope m per tick settles with a lag of m*(1-a)/a. With m = kappa*U*dt_g this is a pure arclength retardation, so the two blends subtract U*dt_g*((1-a_chi)/a_chi + (1-a_yaw)/a_yaw) metres of effective lookahead.
5. STEP 5 (identity). L_eff = L - U*dt_g*((1-a_chi)/a_chi + (1-a_yaw)/a_yaw) and the sustained geometric course lead is chi_lead = kappa_chord*L_eff [rad]. The yaw loop has NO integrator, so this lead appears one-for-one as a sustained e_psi and is multiplied by Kp_psi into the raw rudder command.

`L_lag = U*dt_g*((1-0.28)/0.28 + (1-0.35)/0.35) = 1.5000 * 0.0750 * 4.428571 = 0.498214 m`

**Parametric identity, independent of any repository value of `lookahead_distance`:**

| L [m] | L_eff [m] | steady lead [deg] | implied raw P demand at Kp = 32 [deg] |
|---|---|---|---|
| 1.00 | 0.5018 | 2.8848 | 92.31 |
| 1.50 | 1.0018 | 5.7592 | 184.30 |
| 2.00 | 1.5018 | 8.6337 | 276.28 |
| 2.50 | 2.0018 | 11.5082 | 368.26 |
| 3.00 | 2.5018 | 14.3827 | 460.25 |
| 4.00 | 3.5018 | 20.1317 | 644.21 |
| 5.00 | 4.5018 | 25.8807 | 828.18 |

Closed-form identity evaluated without any repository-specific value of lookahead_distance, so the result stands even if the executed value is disputed. P demand is the raw pre-limiter proportional rudder command Kp_psi*chi_lead, in degrees of commanded deflection.

**Numeric verification at the executed production lookahead:**

| quantity | value | units |
|---|---|---|
| L, executed | 1.250000 | m |
| L_lag | 0.498214 | m |
| L_eff | 0.751786 | m |
| derived lead kappa_chord*L_eff | 4.322002 | deg |
| inscribed-angle chord bearing kappa_chord*L_eff/2 (what pure pursuit would command) | 2.161001 | deg |
| measured lead, on-path march over 11 whole segment periods | 4.352388 | deg |
| identity residual | +0.030386 (tol 0.35) | deg |
| lead ripple, peak to peak | 17.936702 | deg |
| kappa_f steady mean | 0.10000598 (-0.3315% vs kappa_chord) | 1/m |
| kappa_f steady ripple, peak to peak | 1.475e-02 | 1/m |
| on-path residual cross-track (projection resolution) | 1.270e-02 | m |
| production vs reconstruction residual | 0.000e+00 (tol 1e-12) | rad |

The reconstruction is a verbatim transcription of the yaw chain of `guidance_law.m`, and the unmodified production function was called directly on the same on-path march for parity. The identity is therefore confirmed against the production code and not merely against a model of it.

The peak-to-peak figure above is a property of the *reference frame of the measurement*, not of `yaw_ref`. The lead is measured against the projection-point tangent, which on a chord polyline is a staircase stepping by the full 18.00 deg at every node, so the lead necessarily carries a sawtooth of about that amplitude. `yaw_ref` itself is smooth: its largest change is 2.4866 deg per guidance tick.

> **Scope marker.** This march is a geometry reference on the frozen path with the vehicle held exactly on the polyline. It is **not** the stored closed-loop trajectory, it carries no hash attestation against the frozen nominal, and it is never used as a substitute for one.

## 5. Log closure against the stored trajectory (the blocker)

Stored columns of the frozen control anchor (1200 rows x 10 columns, single precision, dt = 0.025 s):

`t, e_psi_deg, term_P_deg, term_RATE_ERR_deg, dr_damp_deg, dr_raw_deg, dr_postmag_deg, dr_plant_deg, g_ac, cte3_m`

**The closure method itself is sound.** Applied to the controller side of the same stored log it closes exactly:

| closure | residual [deg] |
|---|---|
| `term_P - Kp_psi*e_psi` | 0.000e+00 |
| `dr_raw - (term_P + term_RATE_ERR + dr_damp)` | 3.231e-05 |
| `dr_postmag - clamp(dr_raw, +/- 25 deg)` | 0.000e+00 |
| `dr_plant - ratelimit(dr_postmag, 40 deg/s)` | 1.788e-07 |

Tolerance 1e-03 deg (the stored log is single precision).

**The guidance side cannot close.**

- `yaw_ref` present in the stored log: **0**
- `psi` present in the stored log: **0**
- The only stored signal containing yaw_ref is e_psi = wrapToPi(yaw_ref - psi). psi is not stored and no stored column is a function of psi alone, so the map (yaw_ref, psi) -> e_psi is rank 1 in a two-dimensional unknown and cannot be inverted. Every individual reference component (chi_f, chi_los, k_beta*beta, the unwrap state and the yaw_out blend state) is likewise absent and none is a function of the ten stored columns. Component-sum closure against the stored yaw_ref is therefore not merely unmeasured, it is unidentifiable from the permitted evidence. This is a missing-signal failure and not a method failure: the identical closure applied to the controller side of the same log closes to 3e-5 deg.

Signals required for the mandated closure and absent from the permitted evidence:

- `yaw_ref [rad, inertial NED yaw]`
- `psi [rad, inertial NED yaw]`
- `s_prog [m, path arclength]`
- `kappa_f [rad/m, horizontal path curvature]`
- `y_e [m, signed horizontal path-normal cross-track]`
- `chi_f [rad, filtered course]`
- `chi_los [rad, lookahead cross-track course term]`
- `beta [rad, body sideslip]`
- `U_h [m/s, inertial horizontal speed]`

**Refused substitution.** re-simulating the cell would produce a NEW trajectory that cannot be hash-attested against the frozen nominal, so it would not be the stored trajectory the task names. That substitution was refused; the on-path march used here is labelled a geometry reference and is never presented as the stored trajectory.

## 6. The formula placed under test (NOT a stated candidate)

```
yaw_raw = wrapToPi( chi_f + 0.75*chi_los - k_beta*beta - kappa_f*L_eff ),   L_eff = max( L - U_h*dt_nom*((1-0.28)/0.28 + (1-0.35)/0.35), 0 )
```

- **Units and frames**: kappa_f [rad/m] * L_eff [m] = [rad]; horizontal inertial course frame (NED x-y), identical to the frame of chi_f, chi_los and yaw_raw. No new signal: kappa_f, L, U_h and dt_nom are already local to guidance_law.m and 0.28 / 0.35 are the two blend literals already in the file.
- **Zero-curvature parity**: kappa_f == 0 implies the added term is exactly 0.0, so yaw_raw is bit-for-bit the existing expression. Verified empirically on a zero-curvature twin of the frozen path.
- **What it does not do**:
  - it does not address the -0.35*beta crab excess, which is a separate sustained reference bias
  - it does not add an integrator, so it cannot by itself supply the standing turn rudder
  - it is not applied to the near_end branch, which already uses the projection-point tangent and therefore already carries zero lead

| property | value | units |
|---|---|---|
| zero-curvature `kappa_f` absmax on the straight twin | 4.065e-17 | 1/m |
| zero-curvature offset absmax | 3.056e-17 | rad |
| zero-curvature `yaw_ref` residual | 5.551e-17 (bit-exact = 0) | rad |
| offset absmax on the frozen path | 4.5769 (algebraic bound 5.1864) | deg |
| per-tick offset change absmax | 0.1002 (bound 0.3905) | deg/tick |
| yaw_out slew cap | 3.0000 | deg/tick |
| per-tick `yaw_ref` change, production / with offset | 2.4866 / 2.5167 | deg/tick |
| slew-limiter engagements, production / with offset | 0 / 0 | ticks |
| unwrap step absmax, production / with offset | 5.0407 / 5.0713 | deg |
| unwrap branch margin | 174.9287 | deg |
| total unwrapped course travel (yaw_ref exceeds pi = 1) | 251.96 | deg |
| residual steady lead after the offset | +0.046153 | deg |

The slew limiter never engages on the on-path geometric reference, with or without the offset: the 18 deg course staircase is attenuated to a first-tick step of 0.28 x 18 deg by the course low-pass and then to 0.35 of that by the yaw_out blend, which stays under the 3 deg per guidance tick clamp. The offset adds at most the per-tick change listed above, so it cannot newly engage the limiter, and it does not move the unwrap branch: the largest unwrap step stays far below the 180 deg boundary.

## 7. Frozen-trajectory algebra (no closed-loop claim)

FROZEN_TRAJECTORY_ALGEBRA: the stored trajectory is held fixed and only the reference is displaced by the derived steady offset. This is exact algebra on the recorded signals. It is NOT a re-simulation and NOT a closed-loop claim.

| quantity | value | units |
|---|---|---|
| steady window | 7.0394 to 30.0000 s = 11 whole segment periods, 918 samples | s |
| stored `e_psi` sustained mean | +3.982830 | deg |
| stored `e_psi` sustained median | +4.703980 | deg |
| stored `e_psi` absmax | 13.579300 | deg |
| fraction of horizon with `e_psi > 0` | 0.6992 | - |
| recorded `e_psi_median_sus_deg` (source #3 window) | 6.655967 | deg |
| implied sustained P demand `Kp*e_psi`, mean / median | +127.4506 / +150.5274 | deg |
| stored `term_P` absmax | 434.5376 | deg |
| rudder envelope | 25.00 | deg |
| recorded plant steady-turn requirement | 4.0580 | deg |
| `e_psi` needed to hold it at Kp = 32 | 0.126812 | deg |
| derived geometric lead removed by the formula | 4.322002 | deg |
| raw P demand removed, `Kp*lead` | 138.3041 | deg |
| residual sustained bias, mean / median | -0.339172 / +0.381979 | deg |
| residual sustained P demand, mean / median | -10.8535 / +12.2233 | deg |
| chord-vs-circle over-subtraction | +0.014587 | deg |

**Residual attribution.** what remains after the geometric lead is removed is NOT identifiable from the stored log. It is the sum of 0.75*chi_los (signed cross-track term, y_e not stored), -(k_beta - 1)*beta (the crab term over-compensates because course = psi + beta exactly, i.e. k_beta = 1, while the law subtracts 1.35*beta), the chord-vs-circle curvature excess, and the rail limit-cycle contribution. None of these is separable without the missing signals listed in Gate B.

**Crab term.** yaw_raw subtracts k_beta*beta with k_beta = 1.35 while the exact horizontal kinematic relation is course = psi + beta, i.e. k_beta = 1. The residual -0.35*beta is a SECOND sustained reference bias of the same family, driven by the same turn, and it is NOT addressed by the curvature offset under test.

**`e_psi` is load-bearing.** the sustained heading error a pure-P yaw loop must hold to produce the recorded plant steady-turn rudder requirement, since the yaw loop has no integrator and the rate term carries r_ff = U_h*kappa_f so its steady contribution is the small r_ff mismatch only.

### PG4 / PG5 algebra

- PG4 requires median |delta_r| >= 4.058 deg. With the geometric lead removed the sustained P contribution collapses by Kp_psi*chi_lead, so the standing rudder must be regenerated by the only other sustained reference term, 0.75*chi_los.
- required `chi_los` = `e_psi_trim / 0.75` = **0.169083 deg**
- implied steady cross-track `y_e = -(L + 0.6)*tan(chi_los)` = **-0.005459 m**
- recorded PG5 thresholds: `|cte| absmax <= 0.212619 m`, `|cte| median <= 0.100242 m`
- implied `|y_e|` as a fraction of the PG5 median / absmax threshold: **0.0545** / **0.0257**

ALGEBRA ONLY. It states the cross-track offset that would have to exist for the LOS term alone to hold the PG4 standing rudder once the geometric lead is gone, and compares its magnitude with the PG5 thresholds. It does NOT state that the closed loop would reach that equilibrium, and no closed-loop improvement is claimed anywhere in this artifact.

## 8. Gates

| id | requirement | pass | evidence |
|---|---|---|---|
| PG1 | Exact frozen-hash attestation: the stored frozen nominal hash, the anchor-1 hash and the recorded PG1 hash agree, and every protected production file is byte-identical to its recorded fingerprint. | **1** | hash chain equal=1, all 7 protected fingerprints match=1 |
| PG2 | Component-sum closure against the STORED yaw_ref within tolerance. | **0** | yaw_ref stored=0, psi stored=0; controller-side closure residual 3.231e-05 deg proves the method, guidance-side closure is unidentifiable |
| PG3 | Geometry identity: the measured steady course lead equals kappa_chord*L_eff derived from circle/chord geometry, within 0.35 deg, and the reconstruction matches the unmodified production guidance_law. | **1** | pred 4.32200 deg, meas 4.35239 deg, resid +0.03039 deg; production-vs-reconstruction residual 0.000e+00 rad |
| PG4 | Zero-curvature parity: at kappa=0 the offset reference is bit-for-bit the existing reference. | **0** | kappa_f absmax 4.065e-17 1/m, offset absmax 3.056e-17 rad, isequal=0 |
| PG5 | Bounded continuity: the offset is bounded, its per-tick change is below the 3 deg/tick yaw_out slew cap, and it engages the slew limiter no more often than the existing reference. | **1** | offset absmax 4.5769 deg (bound 5.1864), max per-tick change 0.1002 deg (cap 3.00), slew engagements 0 then 0 |
| PG6 | Wrap behaviour unchanged: the unwrap branch margin stays above 90 deg with the offset applied. | **1** | unwrap step absmax 5.0407 deg production / 5.0713 deg with offset, branch margin 174.9287 deg; yaw_ref is intentionally unwrapped and exceeds pi = 1 |
| PG7 | No production edit, no gain change, no path change, no threshold change, no external polyline shaper, no current feedforward, no promotion. | **1** | verified by pre/post fingerprints of every protected file |

All hard gates pass: **0**. Failed: `PG2, PG4`.

## 9. Verdict, blocker and what would unblock it

- **Verdict** `BLOCKER`, **outcome** `BLOCKER_STORED_YAW_REF_NOT_IDENTIFIABLE`.
- **Candidate stated**: none. A shadow reference candidate may be stated only if geometry identity, log closure, zero-curvature parity AND bounded continuity all pass. Log closure against the stored yaw_ref cannot pass: yaw_ref and psi are not in the permitted evidence and are not reconstructible from it. The formula recorded above is therefore UNDER TEST only. It is not a candidate, it is not promoted, and nothing here licenses a law edit.
- **Blocker**: component-sum closure against the stored yaw_ref of the frozen R10_U1.5 control trajectory
- **Why**: the stored per-tick log of the frozen control anchor carries ten columns (t, e_psi, term_P, term_RATE_ERR, dr_damp, dr_raw, dr_postmag, dr_plant, g_ac, cte3) and none of them is yaw_ref, psi, s_prog, kappa_f, signed y_e, chi_f, chi_los, beta or U_h. e_psi = wrapToPi(yaw_ref - psi) is rank 1 in two unknowns.
- **Unblock**: one guidance-side per-tick log on the frozen cell carrying yaw_ref [rad, inertial NED yaw], psi [rad, inertial NED yaw], s_prog [m], kappa_f [rad/m], signed y_e [m, horizontal path-normal], chi_f [rad], chi_los [rad], beta [rad] and U_h [m/s], written under the same frozen hash discipline.
- **Closed-loop claim**: NONE. Every quantified statement in this artifact is either an exact geometric identity or exact algebra on the frozen recorded signals. No closed-loop improvement is claimed, predicted or implied.
- **Change declaration**: NO production edit, NO gain change, NO path or waypoint change, NO threshold change, NO external polyline shaper, NO current feedforward, NO new signal and NO promotion. The only files written are the artifacts listed below.

## 10. Visual QA

- P1 frozen R10 chord polyline in the horizontal plane with the fitted circle, the projection point, the lookahead point and the chord that realises the inscribed-angle half-lead. Axes in metres, inertial NED x-y, equal aspect.
- P2 course angles against arclength: the staircase lookahead course, the filtered course, the production yaw reference, the offset reference and the projection-point tangent, all unwrapped, degrees.
- P3 course lead over the projection-point tangent against time, with the derived kappa_chord*L_eff identity line and the steady window marker, degrees.
- P4 curvature estimator: raw estimate, filtered estimate, the chord curvature and 1/R, in 1/m against arclength.
- P5 stored frozen-control heading error against time in degrees, with the offset-displaced algebra trace and the heading error required for the recorded standing-rudder threshold.
- P6 stored raw rudder command and its proportional part against time in degrees, with the 25 deg envelope and the offset-displaced proportional part.

- Q1 production minus reconstruction yaw reference residual, radians, log scale, against tolerance.
- Q2 zero-curvature parity residual on the straight twin path, radians.
- Q3 per-tick change of the yaw reference and of the offset against the 3 deg per tick slew cap, degrees.
- Q4 controller-side closure residuals of the stored log, degrees, log scale, against tolerance.

| check | pass |
|---|---|
| `recon_residual_below_tol` | 1 |
| `zero_curvature_residual_zero` | 0 |
| `identity_line_within_tol` | 1 |
| `all_traces_finite` | 1 |
| `stored_log_finite` | 1 |
| `png_written` | 1 |
| `png_qa_written` | 1 |

Visual QA overall: **0**. Figures written without error: **1**.

## 11. Appended logs (units, frames, provenance)

**Stored control log (permitted source #3, anchor 1).**

| column | units | frame |
|---|---|---|
| `t` | s | sim clock |
| `e_psi_deg` | deg | inertial yaw error, wrapped |
| `term_P_deg` | deg | rudder command |
| `term_RATE_ERR_deg` | deg | rudder command |
| `dr_damp_deg` | deg | rudder command |
| `dr_raw_deg` | deg | rudder command |
| `dr_postmag_deg` | deg | rudder command |
| `dr_plant_deg` | deg | plant rudder deflection |
| `g_ac` | - | dimensionless |
| `cte3_m` | m | 3-D Euclidean distance to the waypoint polyline |

Provenance: anchor 1 (s = 1, frozen control) of permitted source #3, single precision, 1200 controller ticks at dt = 0.025 s, hash-attested in Gate A.

**Guidance component log (this task, geometry reference).**

| column | units | frame |
|---|---|---|
| `t` | s | sim clock |
| `s_prog` | m | path arclength, 3-D polyline |
| `kappa_raw` | rad/m | horizontal inertial NED x-y |
| `kappa_f` | rad/m | horizontal inertial NED x-y |
| `chi_look` | rad | horizontal inertial course |
| `chi_f` | rad | horizontal inertial course |
| `chi_tan_proj` | rad | horizontal inertial course |
| `y_e` | m | horizontal path-normal, signed positive to port of the tangent |
| `chi_los` | rad | horizontal inertial course increment |
| `yaw_raw` | rad | horizontal inertial yaw |
| `yaw_cont` | rad | horizontal inertial yaw, unwrapped |
| `yaw_ref_prod` | rad | horizontal inertial yaw, unwrapped |
| `yaw_ref_recon` | rad | horizontal inertial yaw, unwrapped |
| `yaw_ref_shadow` | rad | horizontal inertial yaw, unwrapped |
| `chi_off` | rad | horizontal inertial course increment |
| `lead_prod` | rad | course lead over the projection-point tangent |
| `lead_shadow` | rad | course lead over the projection-point tangent |

Provenance: generated by an on-path march of the frozen R10_U1.5 chord polyline at U = 1.5 m/s on the guidance tick dt_guidance = 0.075 s. yaw_ref_prod is the output of the UNMODIFIED production guidance_law.m called directly; yaw_ref_recon is an independent verbatim reconstruction of its yaw chain; yaw_ref_shadow adds the offset under test outside the production file. GEOMETRY REFERENCE ONLY - this is not the stored closed-loop trajectory and is never used as one.

Both logs are appended exactly once, to `...IDENTIFICATION.mat`, and are not duplicated elsewhere.

## 12. Artifacts and footprint

- `suite_results\GATE8_R10_GUIDANCE_COURSE_REFERENCE_OFFSET_IDENTIFICATION.md`
- `suite_results\GATE8_R10_GUIDANCE_COURSE_REFERENCE_OFFSET_IDENTIFICATION.mat`
- `suite_results\GATE8_R10_GUIDANCE_COURSE_REFERENCE_OFFSET_IDENTIFICATION.png`
- `suite_results\GATE8_R10_GUIDANCE_COURSE_REFERENCE_OFFSET_IDENTIFICATION_QA.png`
- `suite_results\GATE8_R10_GUIDANCE_COURSE_REFERENCE_OFFSET_IDENTIFICATION_run.log`

Post-write fingerprints of every protected file unchanged: **1**. Permitted sources unchanged: **1**.


## 13. Post-run addendum (host-written, after the single MATLAB invocation)

This section was written by the analysis host after the one permitted MATLAB
invocation had already completed. It adds **no new computation**: every number
quoted below is read back out of `GATE8_R10_GUIDANCE_COURSE_REFERENCE_OFFSET_IDENTIFICATION.mat`
exactly as the driver stored it. The `.mat` retains the raw machine values and
has not been altered. No second invocation was made and no gate result was
rewritten.

### 13.1 PG4 fails on the test fixture, not on the formula

The driver recorded PG4 (zero-curvature parity) as **FAIL** with:

| quantity | stored value |
|---|---|
| `zero_curv_kappa_absmax` | 4.065e-17 1/m |
| `zero_curv_offset_absmax` | 3.056e-17 rad |
| `zero_curv_resid_rad` | 5.551e-17 rad |
| `zero_curv_bitexact` | 0 |

The parity claim being tested is algebraic and remains exactly true: if
`kappa_f == 0` then `kappa_f*L_eff` is exactly `+0.0`, and `y - 0.0 == y` for
every finite `y` in IEEE-754, so the offset expression reduces bit-for-bit to
the existing one.

What actually failed is the fixture. The zero-curvature twin is built as
`x_k = x_0 + k*seg*cos(chi0)`, `y_k = y_0 + k*seg*sin(chi0)`. Those nodes are
not exactly collinear in double precision, so successive segment difference
vectors are not bit-identical, the normalised tangents differ in the last bits,
and `path_curvature_at` returns `kappa_raw` of order 1e-17 instead of exactly
zero. The filtered `kappa_f` inherits it, the offset becomes 3.056e-17 rad
instead of exactly zero, and the resulting `yaw_ref` difference is 5.551e-17 rad
(3.2e-15 deg), which is two units in the last place of a double at the fixture's
`yaw_ref` of about 0.157 rad. Panel Q2 shows this directly: the residual is
identically zero over most of the horizon and takes single-ulp excursions
elsewhere.

The gate as coded therefore tested a stronger proposition than the one claimed,
namely "bit-inert on a *nominally* straight path", and that stronger
proposition is false at the last bit. A fixture whose successive node
differences are bit-identical by construction would drive `kappa_raw` to exactly
zero and make the recorded parity bit-exact. That is the corrected test for any
future run; it is stated here rather than executed, because the
single-invocation budget for this task is spent.

`visual_qa.pass` is recorded as 0 for the same single reason: its
`zero_curvature_residual_zero` check is the same bit-equality test. The other
visual QA checks all pass.

### 13.2 This changes no conclusion

PG2 fails independently and is the binding blocker: `yaw_ref` and `psi` are
absent from the permitted evidence, so component-sum closure against the stored
`yaw_ref` is unidentifiable. Under the task rule a shadow reference candidate
may be stated only if log closure passes among the others, so **the verdict is
`BLOCKER` and no candidate is stated whether PG4 is read as PASS or FAIL**. The
fixture artifact is reported here for completeness and does not license any
different reading of the result.

### 13.3 `kappa_f` sits 0.33 per cent below `kappa_chord` in the measured window

Section 4 records `kappa_f` steady mean 0.10000598 1/m against
`kappa_chord` 0.10033864 1/m, a shortfall of 0.3315 per cent, while derivation
STEP 2 states that `kappa_f` converges to `kappa_chord`. Both are correct and
the difference is the startup transient of the curvature filter, not a defect in
the derivation. The `0.96 / 0.04` blend has a time constant of 25 guidance ticks
(1.875 s); it starts from zero and is still roughly two per cent unsettled at
the start of the steady window, which is visible as the rise in panel P4 over
the first 12 m of arclength. Averaged across the window that residual transient
accounts for a shortfall of the observed order. The convergence claim is
asymptotic and the measurement is over a finite 30 s horizon.

Two consequences worth recording:

- The PG3 geometry identity is unaffected. The course lead comes from
  `chi_look`, the tangent sampled at `s_prog + L`, and never passes through
  `kappa_f`. `kappa_f` enters only `r_ff = U_h*kappa_f` and, in the formula
  under test, the offset itself.
- The same transient makes the offset under test start soft: because `kappa_f`
  rises from zero over the first ~2 s, the offset does too, which is consistent
  with the bounded-continuity result in PG5 (max change 0.1002 deg per tick
  against the 3 deg per tick slew cap) rather than in tension with it.
