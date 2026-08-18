# PITCH_CONTROL_RESEARCH_LOG

Running log of pitch-control experiments. Production stack unchanged unless noted.

## PITCH_CLIMB_FF_REGRESSION_001 — 2026-08-05 20:07:58

- Verdict: **PASS** — keep climb equilibrium FF in production `controller_law.m`.
- old→new: `de_unsat=de_trim+de_uw_ff+de_fb` → `+ de_climb_ff`; `de_climb_ff=sat(k_gamma*pitch_ref,±2.8793°)`, `k_gamma=0.1320695001`.
- X (first_hold): MAE 0.0637→0.0110 (−82.7%), RMS 0.0683→0.0164 (−75.9%), p95 0.0856→0.0419 (−51.1%); all gates PASS.
- XZ (persistent, λ=0): settle 14.08→6.18 s; acqMAE 1.0876→0.7549 (−30.6%); MAE 0.3502→0.1214; p95 0.4812→0.4039; sat 0%; chatter/OS ok.
- Artifacts: suite_results/PITCH_CLIMB_FF_REGRESSION.{md,mat,png}; driver `run_pitch_climb_ff_regression.m`.
- Next: freeze checklist / optional Muw schedule revisit with climb FF on.

## PITCH_XZ_WINDOW_AUDIT_001 — 2026-08-05 19:42:23

- Audit (defs+reproduce): **PASS**; climb-FF class under corrected windows: **PASS**.
- Metric: inline first_hold → `compute_pitch_window_metrics` persistent ±0.5° to end-excl (s<0.88 s_tot).
- BASE settle 15.05→14.08 s; CLIMB 3.35→6.18 s (old first-hold left band after 3.35 s).
- Rescored climb vs rescored base: dip -40.7%, acqMAE -30.6%, ssRMS -50.8%, ssp95 -16.0%.
- Artifacts: suite_results/PITCH_XZ_WINDOW_AUDIT.{md,mat,png}. Production unchanged.
- Next: optional controlled climb-FF promote after freeze checklist (prod still baseline).


## HELIX_YAW_PITCH_TRACK_001 — 2026-08-05 20:16:30

- Verdict: **FAIL** — combined yaw+pitch on canonical suite helix (R=5.0, not R=7.5).
- Driver only (`run_helix_yaw_pitch_track.m`); controller/gains/guidance/plant unchanged; X/XZ production untouched.
- Pitch ss (persistent): MAE=0.0579 RMS=0.0879 p95=0.1320 sat=0.00% chat=0.0240 settle=2.85s; acqMAE=0.6381.
- Yaw SBE: MAE=37.7423 RMS=42.4326 p95=59.3705 sat=95.00%; r/(U_hκ)=0.7970; CTE_perp=1.198 m; e_r MAE=1.760 m.
- Artifacts: suite_results/HELIX_YAW_PITCH_TRACK.{md,mat,png}.
- Next: R=7.5 helix (same pitch_h/u, driver-only) — R=5@1.5 is rudder-authority limited (sat 95%, known YAW_START/Tur4A); no gain change. CODEX_VERTICAL_PLAN untouched.

## HELIX_R75_YAW_PITCH_TRACK_001 — 2026-08-05 20:22:16

- Verdict: **FAIL** — combined yaw+pitch on R=7.5 helix (canonical geometry R 5.0->7.5 only; pitch_h=2, turns=2, u0=1.5).
- Driver only (`run_helix_r75_yaw_pitch_track.m`); controller/gains/guidance/plant unchanged; no retune; X/XZ production untouched.
- Pitch ss (persistent): MAE=0.0587 RMS=0.0885 p95=0.1764 sat=0.00% chat=0.0138 settle=2.40s; acqMAE=0.5559.
- Yaw SBE: MAE=0.3111 RMS=0.4462 p95=0.6441 sat=1.06%; r/(U_hκ)=1.0240; CTE_perp=0.354 m; e_r MAE=0.201 m.
- Artifacts: suite_results/HELIX_R75_YAW_PITCH_TRACK.{md,mat,png}.
- FAIL class: **yaw authority margin** (soft) — sat 1.06% / ratio 1.024 vs gates 1%/1.02; tracking OK (yaw≈circle baseline). Not metric; not controller. Contrast R5 hard-authority FAIL.
- Next: optional gate-tolerance review or mild R↑/u↓ envelope; no gain change; CODEX_VERTICAL_PLAN untouched.

## HELIX_R8_YAW_PITCH_ENVELOPE_001 — 2026-08-05 20:28:58

- Verdict: **FAIL** — R=8.0 helix envelope (R 7.5->8.0 only; pitch_h=2, turns=2, u0=1.5). Controllers frozen.
- Driver only (`run_helix_r8_yaw_pitch_envelope.m`); controller/gains/guidance/plant unchanged; no retune; X/XZ production untouched.
- Pitch ss (persistent): MAE=0.0546 RMS=0.0872 p95=0.2006 sat=0.00% chat=0.0143 settle=2.35s; acqMAE=0.5453.
- Yaw SBE: MAE=0.2467 RMS=0.2979 p95=0.5113; rudder sat acq/ss/full=75.53/0.00/6.67%; r/(U_hκ)=1.0236; CTE_perp=0.325 m; e_r MAE=0.201 m.
- Artifacts: suite_results/HELIX_R8_YAW_PITCH_ENVELOPE.{md,mat,png}.
- FAIL class: **yaw authority/envelope** — sat ss=0.00% full=6.67% ratio=1.0236 vs gates 1%/1%/[0.98,1.02].
- Next: mild R↑ or u↓ envelope step; no gain change; CODEX_VERTICAL_PLAN untouched.

## HELIX_R10_YAW_PITCH_ENVELOPE_001 — 2026-08-05 20:34:42

- Verdict: **PASS** — R=10.0 helix envelope (R 8.0->10.0 only; pitch_h=2, turns=2, u0=1.5). Controllers frozen.
- Driver only (`run_helix_r10_yaw_pitch_envelope.m`); controller/gains/guidance/plant unchanged; no retune; X/XZ production untouched.
- Pitch ss (persistent): MAE=0.0413 RMS=0.0712 p95=0.1004 sat=0.00% chat=0.0157 settle=2.23s; acqMAE=0.5243.
- Yaw SBE: MAE=0.1748 RMS=0.2041 p95=0.3493; rudder sat acq/ss/full=13.48/0.00/0.67%; r/(U_hκ)=1.0181; CTE_perp=0.230 m; e_r MAE=0.172 m.
- Startup: e0_wrap=+5.77° (|e0|=5.77°); t_to_|e|≤2°=3.43s; sat first/last=0.60/0.88s; sat_in_acq_frac=1.00.
- Artifacts: suite_results/HELIX_R10_YAW_PITCH_ENVELOPE.{md,mat,png}.
- R_min,verified ≤ 10.0 m (comfortable feasible; not exact minimum).
- Next: freeze R≤10 m as verified comfortable helix envelope; optional finer R bracket if exact R_min needed; CODEX_VERTICAL_PLAN untouched.

## PITCH_YAW_FINAL_CLOSURE_001 — 2026-08-05 20:47:33

- Verdict: **PASS** — two-repeat 6DOF closure X / XZ(λ=0) / R10 helix; production climb-FF frozen; no controller/guidance/plant edits.
- Determinism: rng seed=0 twister; X=deterministic identity (bit-match after clear persistent); XZ=deterministic identity (bit-match after clear persistent); H=deterministic identity (bit-match after clear persistent).
- X (first_hold): settle=2.65s acqMAE=0.3831 ssMAE=0.0110 ssp95=0.0419 sat=0.00% | gates PASS.
- XZ (persistent λ=0): settle=6.18s acqMAE=0.7549 ssMAE=0.1214 ssp95=0.4039 sat=0.00% | gates PASS.
- R10 helix: pitch ss MAE=0.0413 p95=0.1004 sat=0.00%; yaw MAE=0.1748 p95=0.3493 sat_full=0.67% ratio=1.0181 | gates PASS.
- Artifacts: suite_results/PITCH_YAW_CLOSURE.{md,mat}; FINAL_TRACKING_{X,XZ,HELIX_R10}.png; driver `run_pitch_yaw_final_closure.m`.
- Next: freeze production checklist; optional finer R_min if exact min needed; CODEX_VERTICAL_PLAN untouched.

## SPEED_ENVELOPE_AUDIT_001 — 2026-08-06 03:24:13

- Verdict (audit completeness): **PASS** — production cascade+climbFF frozen; no retune.
- Rejected gamma methods: INDI (`REJECT_DIRECT_INDI_SCAFFOLD`), outer PI (`REJECT_OUTER_GAMMA_PI_SCAFFOLD`), outer ADRC (`REJECT_OUTER_GAMMA_ADRC_SCAFFOLD`).
- Grid: Uref=[1 1.25 1.5 1.75 2] on X / XZ / R10; FEASIBLE cells=13/15.
- Certified contiguous: X=[1.00, 2.00] m/s (grid-contiguous; no extrapolate); XZ=[1.00, 2.00] m/s (grid-contiguous; no extrapolate); R10=[1.50, 2.00] m/s (grid-contiguous; no extrapolate); intersect=[1.50, 2.00] m/s; worst_margin=0.001756 (no extrapolate).
- Preserve: R5 hard yaw FAIL; R7.5 soft FAIL; R10@1.5 PASS.
- Artifacts: suite_results/SPEED_ENVELOPE_AUDIT.{md,mat,png}; driver `run_speed_envelope_audit.m`.
- Prioritized next decision: **`depth_outer_loop_baseline`** — Speed envelope adequate on certified contiguous multi-route range. Recommend depth outer-loop baseline next (production cascade frozen).
- CODEX_VERTICAL_PLAN untouched.

## DEPTH_OUTER_BASELINE_001 — 2026-08-06 03:33:29

- Verdict (audit completeness): **PASS** — nonlinear 6DOF depth/guidance baseline @ U=1.5; production cascade+climbFF frozen; no retune.
- Frames: NED z-positive-down; theta_phys=-theta; depth≡z; guidance pitch_corr=-0.050*z_e_f-0.006*z_e_i (Kγ=Kzdot=0).
- Scenarios: HOLD / STEP+2m / STEP-2m / XZ_ramp; level-trim IC; cosine L=15m steps; fixed acq/ss windows.
- Scenario gates: HOLD=NO(zMAE=0.2739); STEP_P2=YES(zMAE=0.0441); STEP_M2=NO(zMAE=0.4477); XZ_RAMP=NO(zMAE=0.3730) | all_pass=NO.
- Determinism: seed=0; no second run; prior PITCH_YAW_FINAL_CLOSURE bit-identity cited.
- Artifacts: suite_results/DEPTH_OUTER_BASELINE.{md,mat,png}; driver `run_depth_outer_baseline.m`.
- Next: **`derive_model_based_depth_to_gamma_outer`** — ≥1 scenario FAIL vs conservative gates; next bounded step = one model-based depth→gamma outer candidate with anti-windup + reference shaping (production cascade frozen; do not invent gains in this audit).
- CODEX_VERTICAL_PLAN untouched.

## DEPTH_TO_GAMMA_CANDIDATE_001 — 2026-08-06 03:44:36

- Verdict: **FAIL** — isolated model depth→gamma PI (wn=0.08 zeta=1 Gdc=0.9404); production cascade+climbFF+guidance frozen; no sweep.
- Gains: Kp=0.113427 rad/m Ki=0.00453708 rad/(m·s) Kaw=0.04 1/s; clamp±12deg rate≤3deg/s; poles -0.08,-0.08; bumpless I=0 + conditional I + back-calc.
- Eq: e_z=z−z_ref (NED↓); ė_z≈U·Gdc·γ_corr; γ_corr=−Kp e_z−Ki I; pitch_ref=pitch_geom+γ_corr.
- Before→after zMAE: HOLD 0.2739→0.1499; STEP_P2 0.0441→0.0721; STEP_M2 0.4477→0.2777; XZ_RAMP 0.3730→0.2239 | agg 0.2847→0.1809 (36.4%).
- Gates: all_depth=NO agg_improve=YES depth_reg=NO att_act=NO | first=`STEP_M2:settle(19.77>18.00 or NaN)`.
- Next: **`REJECT_DEPTH_TO_GAMMA_CANDIDATE`** — Reject/revert isolated candidate (production untouched). First fail: STEP_M2:settle(19.77>18.00 or NaN). Next bounded alternative (not a sweep): raised-cosine depth-reference soft-start / command shaping on z_ref before the same PI, or one NDO buoyancy-bias observer feeding gamma_corr (fixed b0 from Gdc).
- Alt (bounded, not sweep): **`bounded_zref_raised_cosine_softstart_or_NDO_buoyancy`** — Prefer one bounded depth-reference raised-cosine soft-start (shape z_ref transitions; keep FIXED Kp/Ki) OR one NDO estimating constant buoyancy/trim depth bias with b0=U*Gdc, feeding gamma_corr — no gain sweep.
- Artifacts: suite_results/DEPTH_TO_GAMMA_CANDIDATE.{md,mat,png}; helper `guidance_law_depth_to_gamma.m`; driver `run_depth_to_gamma_candidate.m`.
- CODEX_VERTICAL_PLAN untouched.

## DEPTH_NDO_CANDIDATE_001 — 2026-08-06 04:03:32

- Verdict: **FAIL** — isolated depth-rate NDO (b0=1.4106 kz=0.08 1/s wo=0.3 rad/s Gdc=0.9404); prior depth→gamma PI rejected; production cascade+climbFF+guidance frozen; no sweep.
- Law: d_meas=(zdot−zdot_ref)−b0·γ_prev; dhat_dot=wo(d_meas−dhat); γ_raw=(−kz·e−dhat)/b0; clamp±9deg rate≤2deg/s; |dhat|≤0.50 m/s; bumpless dhat=0/corr=0.
- Before→after zMAE: HOLD 0.2739→0.0650; STEP_P2 0.0441→0.2542; STEP_M2 0.4477→0.2154; XZ_RAMP 0.3730→0.0813 | agg 0.2847→0.1540 (45.9%).
- NDO resid/bounds: HOLD residRMS=0.0188 |dhat|max=0.0493 hit=NO; STEP_P2 residRMS=0.0865 |dhat|max=0.1546 hit=NO; STEP_M2 residRMS=0.0883 |dhat|max=0.1512 hit=NO; XZ_RAMP residRMS=0.0168 |dhat|max=0.0561 hit=NO.
- Gates: all_depth=NO agg_improve=YES depth_reg=NO att_act=NO | first=`STEP_P2:depth_OS(0.6689>0.6000)`.
- Next: **`REJECT_DEPTH_NDO_CANDIDATE`** — Reject depth redesign (production untouched). First fail: STEP_P2:depth_OS(0.6689>0.6000). Advance next to sensor/noise/current-estimator baseline (not another depth outer redesign).
- Alt (bounded, not sweep): **`sensor_noise_current_estimator_baseline`** — Reject further depth redesign. Next bounded step: sensor/noise/current-estimator baseline audit with production cascade+guidance frozen.
- Artifacts: suite_results/DEPTH_NDO_CANDIDATE.{md,mat,png}; helper `guidance_law_depth_ndo.m`; driver `run_depth_ndo_candidate.m`.
- CODEX_VERTICAL_PLAN untouched.


## COMBINED_6DOF_DISTURBANCE_BASELINE_001 — 2026-08-06 05:27:58

- Verdict: **FAIL** — PLANT-DISTURBANCE + ESTIMATOR baseline (offline observer; NOT sensor-in-loop); production frozen.
- Setup: U=1.5; Vc=[0,0.15,0] NED; X/XZ/R10; two repeats identity; controller uses plant truth only.
- X before→after: thMAE 0.0110→0.0247 yawMAE 0.0000→0.1036 CTE 0.247→0.256 ez 0.2426→0.2428 | FEAS_c=YES first=none
- XZ before→after: thMAE 0.1214→0.1431 yawMAE 0.0000→0.0784 CTE 0.372→0.352 ez 0.3521→0.3272 | FEAS_c=YES first=none
- R10 before→after: thMAE 0.0411→0.2046 yawMAE 0.1740→0.4046 CTE 0.269→0.238 ez 0.2240→0.2064 | FEAS_c=NO first=rudder_sat_full(6.06%>1.00%)
- Observer max bias/rmse/p95/final: 1.250e-02 / 1.736e-02 / 2.673e-02 / 1.859e-02 (hits=0)
- Identity: deterministic identity (bit-match after clear persistent/RNG)
- First limit: `R10_curr:rudder_sat_full(6.06%>1.00%)`
- Artifacts: suite_results/COMBINED_6DOF_DISTURBANCE_BASELINE.{md,mat,png}; driver `run_combined_6dof_disturbance_baseline.m`.
- Next: **`isolated_current_compensation_candidate`** — FAIL first=`R10_curr:rudder_sat_full(6.06%>1.00%)`. Plant tracking/actuator limit under Vc cross-current → next: ONE isolated crab/current feedforward compensation candidate (production frozen; observer stays offline).
- CODEX_VERTICAL_PLAN untouched.


## CRAB_CURRENT_FF_CANDIDATE_001 — 2026-08-06 05:42:59

- Verdict: **FAIL** — isolated crab-current yaw-ref FF (causal biased/noisy Vhat); production frozen; no sweep.
- Law: vw=Uref*th-Vhat_NE; dpsi=wrap(atan2(vw_E,vw_N)-atan2(th_E,th_N)); clamp±8deg rate≤3deg/s × half-cosine 0→1/5s; yaw_ref+=dpsi once; beta+r_ff preserved.
- Algebra: beta=body sideslip vs water; dpsi=water-track vs path from Vhat; r_ff=U_h*kappa rate FF — no double-count.
- X before→after: thMAE 0.0247→0.0245 yawMAE 0.1036→0.1816 CTE 0.256→0.390 drSatF 2.64→2.92 chat 0.2056→0.1979 | FEAS=YES first=none
- XZ before→after: thMAE 0.1431→0.1365 yawMAE 0.0784→0.1519 CTE 0.352→0.451 drSatF 2.39→2.50 chat 0.2078→0.2172 | FEAS=YES first=none
- R10 before→after: thMAE 0.2046→0.2026 yawMAE 0.4046→0.3922 CTE 0.238→0.282 drSatF 6.06→9.00 chat 0.1633→0.1665 | FEAS=NO first=rudder_sat_full(9.00%>1.00%)
- R10 sat improve=-48.6% smooth improve=0.5% (need>=10%); observer max bias/rmse/p95/final: 1.132e-02 / 1.726e-02 / 2.674e-02 / 1.446e-02 (hits=0)
- First limit: `X_reg:thP95(0.06639>0.06492=+2%)`
- Artifacts: suite_results/CRAB_CURRENT_FF_CANDIDATE.{md,mat,png}; driver `run_crab_current_ff_candidate.m`.
- Next: **`guidance_mission_baseline`** — REJECT crab-current FF candidate (production untouched). First fail=`X_reg:thP95(0.06639>0.06492=+2%)`. Advance to guidance/mission baseline.
- CODEX_VERTICAL_PLAN untouched.


## GUIDANCE_MISSION_BASELINE_001 — 2026-08-06 06:11:42

- Verdict (audit completeness): **PASS** — crab-current FF rejected; production cascade+guidance frozen; no retune.
- Mission class: NO first=`LEVEL:gamma_MAE(0.7356>0.5000)` | mono=YES complete=YES stall=NO bounded=YES
- Composite U=1.5: LEVEL→CLIMB→R10 TURN→EXIT; s_total=76.19m T=64.0s; C1 path external (guidance segment-unaware).
- Segments: LEVEL FEAS=NO(gamma_MAE(0.7356>0.5000)) | CLIMB FEAS=NO(pitch_MAE(1.6186>0.3000)) | TURN FEAS=NO(yaw_p95(2.3221>2.0000)) | EXIT FEAS=NO(gamma_MAE(0.6417>0.5000))
- Unsupported autonomy marked NOT_IMPLEMENTED (mission manager, faults, replan, timeouts, transition shaper).
- Artifacts: suite_results/GUIDANCE_MISSION_BASELINE.{md,mat,png}; driver `run_guidance_mission_baseline.m`.
- Next: **`transition_shaper`** — Mission classification FAIL first=`LEVEL:gamma_MAE(0.7356>0.5000)` → next transition shaper.
- CODEX_VERTICAL_PLAN untouched.


## GUIDANCE_TRANSITION_SHAPER_001 — 2026-08-06 06:26:55

- Verdict: **FAIL** — isolated geometry transition shaper; production cascade+guidance frozen; no retune; gates unrelaxed.
- Geometry: ACQ L=15.0 + LEVEL L=20.0 + C2 climb L=36.0 Δz=+4.0 + clothoid L=8.0 / R=10.0 / circ L=7.71 + EXIT; R_des=10.000m R_meas=10.000m; s_total=115.02m T=96.0s.
- Eq: quintic z=dz(10σ³-15σ⁴+6σ⁵); clothoid κ(s)=κ0+(κ1-κ0)s/L, Δψ=½κ_max L_c; circle κ=1/R.
- Candidate class: NO first=`CLIMB:pitch_MAE(0.6885>0.3000)` | mono=YES complete=YES stall=NO bounded=YES act_reg=NO
- Segments: ACQ(report) th=0.065 g=0.911 | LEVEL FEAS=YES(none) | CLIMB FEAS=NO(pitch_MAE(0.6885>0.3000)) | TURN FEAS=NO(yaw_ratio(1.2452)) | EXIT FEAS=NO(pitch_MAE(0.1071>0.1000))
- Artifacts: suite_results/GUIDANCE_TRANSITION_SHAPER.{md,mat,png}; driver `run_guidance_transition_shaper.m`.
- Next: **`CLOSE_MISSION_SHAPER_LINE`** — REJECT transition shaper (production untouched). First=`CLIMB:pitch_MAE(0.6885>0.3000)`. Close mission-shaper line after this single failure; document production mission limitations (no segment blender / clothoid in guidance; composite C1 polyline insufficient for SPEED_ENVELOPE hard gates on multi-segment mission).
- CODEX_VERTICAL_PLAN untouched.


## CLOSE_MISSION_SHAPER_LINE — 2026-08-06 06:57:09

- Verdict: **CLOSED / REJECTED** — mission-shaper line ended after GUIDANCE_TRANSITION_SHAPER_001 FAIL.
- First fail retained: `CLIMB:pitch_MAE(0.6885>0.3000)`; production untouched.
- Production mission limitations: no segment blender / clothoid in guidance; composite C1 polyline insufficient for SPEED_ENVELOPE hard gates on multi-segment mission.
- Unsupported autonomy remains NOT_IMPLEMENTED (mission manager, faults, replan, timeouts, transition shaper).
- Next: **`rudder_fault_baseline`** — first bounded fault gate on feasible R10@U=1.5 (this task).
- CODEX_VERTICAL_PLAN untouched.


## RUDDER_FAULT_BASELINE_001 — 2026-08-06 06:57:09

- Audit: **PASS** — Survivability: **PASS** — R10@U=1.5 mid-turn 50% rudder loss at plant-input; production frozen.
- Closed prior: mission-shaper line REJECTED (GUIDANCE_TRANSITION_SHAPER).
- Fault audit: FDI/isolation/safe-mode/health/effectiveness/residual/abort = NOT_IMPLEMENTED; plant-input boundary PRESENT.
- Nominal reuse: REUSED R=10.0 u0=1.50 T=45 PASS=YES.
- Injection: t_f=19.60s s_f=31.494m; η_r: 1→0.50; δr_app=η·δr_cmd; realized η=0.5000; hidden_reset=NO.
- Pre→post (±8s): yawMAE 0.176→0.191; pitchMAE 0.018→0.014; rollMAE 1.430→1.401; speedMAE 0.347→0.345; cmd−app 0.000→4.335.
- Fault-run SBE: yawMAE=0.1874 p95=0.4087 CTE=0.226; pitch ssMAE=0.0411; rollMAE=1.4196; uMAE=0.3477; drSat ss/full=0.00/0.67%; chat=37.8604; ratio=1.0180.
- Mission: progress=0.567 complete=YES bounded=YES.
- Signature measurable: YES (Δyaw=0.015 ΔCTE=-0.099 Δcmd−app=4.335).
- Artifacts: suite_results/RUDDER_FAULT_BASELINE.{md,mat,png}; driver `run_rudder_fault_baseline.m`.
- Next: **`residual_detector_feasibility`** — production remains frozen; CODEX_VERTICAL_PLAN untouched.


## RUDDER_RESIDUAL_DETECTOR_FEASIBILITY_001 — 2026-08-06 07:11:45

- Sensor-only (B): **PASS** — Hardware (A): **PASS_HARDWARE** — offline only; production frozen; no NL rerun.
- Sources: RUDDER_FAULT_BASELINE.mat + HELIX_R10_YAW_PITCH_ENVELOPE.mat + STATE_SPACE_MODEL_AUDIT.md.
- Terminology fix: prior baseline = **fixed-horizon survivability** (T_final ok, progress=56.7%), not mission-goal completion.
- A: |cmd−app| hardware residual delay=0.225s (forbidden as sensor-only).
- B1 phase-cmd: thr=2.180° FA_persist=0.000% delay=0.450s | B2 frac-loss: thr=0.277 FA=0.000% delay=0.375s.
- B OR: FA=0.000% (≤1%) delay=0.375s (≤3s) leakage=NO.
- Limits: single traj/fault; ASSUMED-direct sensors; noise NOT_IMPLEMENTED; phase template path-specific.
- Artifacts: suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.{md,mat,png}; driver `run_rudder_residual_detector_feasibility.m`.
- Next: **`isolated_online_rudder_residual_monitor`** — B PASS → next: isolated online monitor scaffold only; production still frozen; do not promote yet.
- CODEX_VERTICAL_PLAN untouched.


## ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR_001 — 2026-08-06 07:21:53

- Functional: **PASS** — Deployment: **NOT_CERTIFIED** — isolated online B2 monitor; production frozen; no NL rerun.
- Frozen from feasibility: G_nom=0.8519 thr=0.2771 gate=1.0° u_floor=0.30 Np=10 persist=0.25s (no retune).
- Inputs: δr_cmd + IMU r + DVL u only; app/η/labels forbidden in update; labels post-hoc scoring only.
- Replay: FA_B2=0.000% (≤1) delay=0.375s (offline 0.375s) before_fault=NO resid_parity_max|err|=0.000e+00.
- Cert blocked: noise/delay, other speeds/paths/currents, other fault magnitudes untested.
- Artifacts: suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.{md,mat,png}; `isolated_online_rudder_residual_monitor.m` + `run_isolated_online_rudder_residual_monitor.m`.
- Next: **`bounded_synthetic_noise_delay_robustness_stress`** — Functional PASS → next: bounded synthetic noise/delay robustness stress; deployment still NOT_CERTIFIED.
- CODEX_VERTICAL_PLAN untouched.


## RUDDER_MONITOR_NOISE_DELAY_STRESS_001 — 2026-08-06 07:31:24

- Robustness: **PASS** — Deployment: **NOT_CERTIFIED** — frozen B2 noise/delay stress; production frozen; no NL rerun; no retune.
- DVL reused: σ=0.010 m/s @ 5 Hz ZOH, bias=+0.005 m/s, lat=200 ms (CURRENT_OBSERVER).
- IMU ASSUMED: σ=0.20 deg/s @ 100 Hz ZOH, bias=+0.05 deg/s, lat=50 ms (not hardware).
- Seeds 1001:1040 (N=40): Pd=100.0% (40/40) delay_med/p95=0.375/0.387 s misses=0 FA_agg_latched=0.0000%.
- Gates: Pd>=95=YES p95delay<=3s=YES FA<=1%=YES.
- Artifacts: suite_results/RUDDER_MONITOR_NOISE_DELAY_STRESS.{md,mat,png}; driver `run_rudder_monitor_noise_delay_stress.m`.
- Next: **`fault_magnitude_speed_coverage`** — Robustness PASS → next: fault-magnitude/speed coverage; deployment still NOT_CERTIFIED.
- CODEX_VERTICAL_PLAN untouched.


## RUDDER_FAULT_MAG_SPEED_COVERAGE_001 — 2026-08-06 07:43:23

- Audit: **PASS** — Detectability/Coverage: **FAIL** — Fixed-horizon surv(all): **PASS** — clean-sensor R10 U×η matrix; production frozen; B2 frozen (no retune).
- Grid: U={1.5        1.75           2} ∩ SPEED_ENVELOPE intersect; η={0.75         0.5        0.25} (loss 25/50/75%); new NL runs=8 reused=1.
- Frozen B2: G_nom=0.8519 thr=0.2771 gate=1.0° Np=10 (from ISOLATED_ONLINE; retuned=NO).
- Detect: 7/9 within 3s no-preFA; misses=2 preFA=0.
- Delays: U1.50/η0.75:MISS; U1.50/η0.50:0.375s; U1.50/η0.25:0.375s; U1.75/η0.75:MISS; U1.75/η0.50:0.375s; U1.75/η0.25:0.325s; U2.00/η0.75:2.550s; U2.00/η0.50:0.375s; U2.00/η0.25:0.300s.
- Certified detect region: U=1.50/eta=0.50, U=1.50/eta=0.25, U=1.75/eta=0.50, U=1.75/eta=0.25, U=2.00/eta=0.75, U=2.00/eta=0.50, U=2.00/eta=0.25.
- Artifacts: suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.{md,mat,png}; driver `run_rudder_fault_mag_speed_coverage.m`.
- Next: **`distinct_detector_or_actuator_feedback_requirement`** — production remains frozen; CODEX_VERTICAL_PLAN untouched.


## RUDDER_CUSUM_DETECTOR_001 — 2026-08-06 07:57:24

- Coverage: **FAIL** — one-sided CUSUM on frozen B2 residual; production frozen; no NL rerun; B2/G_nom untouched.
- Seeds TRAIN=2101:2120 VAL=3101:3140 (disjoint); κ=0.000000 h=34.755105 frozen before fault open.
- Unseen-nominal FA_agg=0.0101% (gate≤1%=YES).
- Cells all Pd≥95 & p95≤3s: NO.
- U=1.50/η=0.75: CUSUM Pd=92.5% med/p95=0.175/0.225 miss=3 preFA=3 | B2 Pd=15.0% p95=8.850.
- U=1.50/η=0.50: CUSUM Pd=92.5% med/p95=0.125/0.175 miss=3 preFA=3 | B2 Pd=100.0% p95=0.375.
- U=1.50/η=0.25: CUSUM Pd=92.5% med/p95=0.125/0.175 miss=3 preFA=3 | B2 Pd=100.0% p95=0.375.
- U=1.75/η=0.75: CUSUM Pd=97.5% med/p95=0.125/0.200 miss=1 preFA=1 | B2 Pd=47.5% p95=23.894.
- U=1.75/η=0.50: CUSUM Pd=97.5% med/p95=0.100/0.175 miss=1 preFA=1 | B2 Pd=100.0% p95=0.375.
- U=1.75/η=0.25: CUSUM Pd=97.5% med/p95=0.100/0.164 miss=1 preFA=1 | B2 Pd=100.0% p95=0.375.
- U=2.00/η=0.75: CUSUM Pd=100.0% med/p95=1.075/1.175 miss=0 preFA=0 | B2 Pd=77.5% p95=2.550.
- U=2.00/η=0.50: CUSUM Pd=100.0% med/p95=0.525/0.588 miss=0 preFA=0 | B2 Pd=100.0% p95=0.375.
- U=2.00/η=0.25: CUSUM Pd=100.0% med/p95=0.450/0.475 miss=0 preFA=0 | B2 Pd=100.0% p95=0.375.
- Artifacts: suite_results/RUDDER_CUSUM_DETECTOR.{md,mat,png}; driver `run_rudder_cusum_detector.m`.
- Next: **`close_sensor_only_mild_loss_require_actuator_feedback_or_richer_ID`** — Coverage FAIL → close sensor-only mild-loss line; require actuator feedback and/or richer identification before further promotion.
- CODEX_VERTICAL_PLAN untouched.


## RUDDER_CUSUM_DETECTOR_001 — 2026-08-06 07:59:17

- Coverage: **FAIL** — one-sided CUSUM on frozen B2 residual; production frozen; no NL rerun; B2/G_nom untouched.
- Seeds TRAIN=2101:2120 VAL=3101:3140 (disjoint); κ=0.301285 h=0.066139 frozen before fault open.
- Unseen-nominal FA_agg=30.0130% (gate≤1%=NO).
- Cells all Pd≥95 & p95≤3s: NO.
- U=1.50/η=0.75: CUSUM Pd=95.0% med/p95=0.550/0.550 miss=2 preFA=2 | B2 Pd=15.0% p95=8.850.
- U=1.50/η=0.50: CUSUM Pd=95.0% med/p95=0.175/0.175 miss=2 preFA=2 | B2 Pd=100.0% p95=0.375.
- U=1.50/η=0.25: CUSUM Pd=95.0% med/p95=0.175/0.175 miss=2 preFA=2 | B2 Pd=100.0% p95=0.375.
- U=1.75/η=0.75: CUSUM Pd=12.5% med/p95=0.175/0.225 miss=35 preFA=35 | B2 Pd=47.5% p95=23.894.
- U=1.75/η=0.50: CUSUM Pd=12.5% med/p95=0.175/0.175 miss=35 preFA=35 | B2 Pd=100.0% p95=0.375.
- U=1.75/η=0.25: CUSUM Pd=12.5% med/p95=0.150/0.150 miss=35 preFA=35 | B2 Pd=100.0% p95=0.375.
- U=2.00/η=0.75: CUSUM Pd=2.5% med/p95=0.625/0.625 miss=39 preFA=39 | B2 Pd=77.5% p95=2.550.
- U=2.00/η=0.50: CUSUM Pd=2.5% med/p95=0.150/0.150 miss=39 preFA=39 | B2 Pd=100.0% p95=0.375.
- U=2.00/η=0.25: CUSUM Pd=2.5% med/p95=0.150/0.150 miss=39 preFA=39 | B2 Pd=100.0% p95=0.375.
- Artifacts: suite_results/RUDDER_CUSUM_DETECTOR.{md,mat,png}; driver `run_rudder_cusum_detector.m`.
- Next: **`close_sensor_only_mild_loss_require_actuator_feedback_or_richer_ID`** — Coverage FAIL → close sensor-only mild-loss line; require actuator feedback and/or richer identification before further promotion.
- CODEX_VERTICAL_PLAN untouched.


## RUDDER_CUSUM_DETECTOR_001 — 2026-08-06 08:02:30

- Coverage: **PASS** — one-sided CUSUM on frozen B2 residual; production frozen; no NL rerun; B2/G_nom untouched.
- Seeds TRAIN=2101:2120 VAL=3101:3140 (disjoint); κ=0.066156 h=11.066456 frozen before fault open.
- Unseen-nominal FA_agg=0.0000% (gate≤1%=YES).
- Cells all Pd≥95 & p95≤3s: YES.
- U=1.50/η=0.75: CUSUM Pd=100.0% med/p95=1.175/1.275 miss=0 preFA=0 | B2 Pd=15.0% p95=8.850.
- U=1.50/η=0.50: CUSUM Pd=100.0% med/p95=0.500/0.525 miss=0 preFA=0 | B2 Pd=100.0% p95=0.375.
- U=1.50/η=0.25: CUSUM Pd=100.0% med/p95=0.400/0.438 miss=0 preFA=0 | B2 Pd=100.0% p95=0.375.
- U=1.75/η=0.75: CUSUM Pd=100.0% med/p95=1.025/1.150 miss=0 preFA=0 | B2 Pd=47.5% p95=23.894.
- U=1.75/η=0.50: CUSUM Pd=100.0% med/p95=0.475/0.512 miss=0 preFA=0 | B2 Pd=100.0% p95=0.375.
- U=1.75/η=0.25: CUSUM Pd=100.0% med/p95=0.400/0.425 miss=0 preFA=0 | B2 Pd=100.0% p95=0.375.
- U=2.00/η=0.75: CUSUM Pd=100.0% med/p95=1.263/1.338 miss=0 preFA=0 | B2 Pd=77.5% p95=2.550.
- U=2.00/η=0.50: CUSUM Pd=100.0% med/p95=0.550/0.588 miss=0 preFA=0 | B2 Pd=100.0% p95=0.375.
- U=2.00/η=0.25: CUSUM Pd=100.0% med/p95=0.450/0.475 miss=0 preFA=0 | B2 Pd=100.0% p95=0.375.
- Artifacts: suite_results/RUDDER_CUSUM_DETECTOR.{md,mat,png}; driver `run_rudder_cusum_detector.m`.
- Next: **`fault_isolation_safe_mode_requirements_audit`** — Coverage PASS → next: fault-isolation / safe-mode requirements audit; production remains frozen.
- CODEX_VERTICAL_PLAN untouched.

## FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS_001 — 2026-08-06 08:07:40

- Audit: **PASS** (requirements only) — software-only rudder isolation **NOT supportable**; safe-mode trigger authority **NOT defensible**.
- Sources (≤3): RUDDER_CUSUM_DETECTOR.md (Coverage PASS), RUDDER_FAULT_MAG_SPEED_COVERAGE.md (B2 detect FAIL / survivability PASS), GUIDANCE_MISSION_BASELINE.md (mission FDI/safe-mode APIs NOT_IMPLEMENTED).
- Layers: detect=offline CUSUM scaffold; isolation/severity/accommodation/abort=NOT_IMPLEMENTED. CUSUM proves command×u² residual anomaly on R10×U∈{1.50,1.75,2.00}×η∈{0.75,0.50,0.25} under declared IMU/DVL corruption only — not rudder identity.
- Confounders: current, hydro G_nom mismatch, sensor faults, other actuators all share residual signature; δr position/current/health feedback unavailable.
- Criteria: measurable CUSUM entry/latch (κ=0.066156,h=11.066456); auto-recovery and auto-surface PROHIBITED until separate validation; mission_manager/watchdog/reset/abort APIs marked NOT_IMPLEMENTED.
- Cross-ref: STATE_SPACE_MODEL_AUDIT.md (commanded actuators; production truth sensing; sensor plumbing NOT_IMPLEMENTED).
- Artifact: suite_results/FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS.md. Production frozen; no MATLAB run.
- Next: **`actuator_feedback_telemetry_interface_specification`** — isolation authority not defensible → specify δr_meas/health ICD + ID protocol; do NOT start tangent-exit safe-mode baseline.
- CODEX_VERTICAL_PLAN untouched.

## ACTUATOR_FEEDBACK_TELEMETRY_ICD_001 — 2026-08-06 08:12:43

- Spec: **PASS** (ICD only) — rudder-minimum / elevator-optional actuator feedback+telemetry interface; no production edit; no MATLAB run; no vendor protocol.
- Sources (≤3): FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS.md, controller_law.m, continuous_path_tracking.m.
- Timing/range anchors: dt_controller=0.025 s (FIXED) → f_ctrl=40 Hz (DERIVED); δr ±25 deg, δe ±15 deg (FIXED); rate limit 40 deg/s (FIXED) → 1.0 deg/tick (DERIVED).
- Signals: cmd, meas/applied angle, current/torque proxy, supply V, temperature, health/BIT, sat mag/rate, timestamp, sequence, validity/quality, stale/dropout — every numeric labeled FIXED/DERIVED/ASSUMED/TO_BE_IDENTIFIED.
- Isolation predicates: P-TRACK, P-STALL, P-OPEN, P-SENS, P-HYDRO, P-INCONC; unvalidated thresholds TBD; residual-alone isolation still forbidden.
- State machine/messages, latch/reset (explicit only), fail-silent, cyber/integrity basics, bench/SIL/HIL AT-* included; sim L5 fault truth strictly separated from online monitor inputs.
- Artifact: suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md. Production frozen; CODEX_VERTICAL_PLAN untouched.
- Next: **`isolated_telemetry_emulator_and_fault_class_separability_study`** — emulator + class separability only; no accommodation/safe-mode wiring.
- CODEX_VERTICAL_PLAN untouched.

## ACTUATOR_TELEMETRY_SEPARABILITY_001 — 2026-08-06 08:25:43

- Logical SIL: **FAIL** — isolated telemetry emulator + fault-class separability; hardware/deployment **NOT_CERTIFIED**; production frozen; no NL rerun.
- Sources (≤3): ACTUATOR_FEEDBACK_TELEMETRY_ICD.md, RUDDER_FAULT_MAG_SPEED_COVERAGE.mat, RUDDER_CUSUM_DETECTOR.mat.
- Seeds TRAIN=6101:6120 VAL=7101:7140 (disjoint; disjoint from CUSUM); TBD thr frozen before VAL.
- ASSUMED models: τ=0.050s, σ_meas=0.050deg, current/BIT stubs; NOT hardware.
- VAL healthy FA_iso=0.0000%; STALE_iso=0 CONFLICT_iso=37; isolable P/R gate=FAIL.
- TRACK: P=100.00% R=100.00%
- STALL: P=100.00% R=100.00%
- OPEN: P=51.95% R=100.00%
- SENS: P=100.00% R=100.00%
- HYDRO: P=100.00% R=100.00%
- Artifacts: suite_results/ACTUATOR_TELEMETRY_SEPARABILITY.{md,mat,png}; driver `run_actuator_telemetry_separability.m`.
- Next: revise ICD predicates / TBD thresholds / emulator ASSUMED models; do NOT edit controller.
- CODEX_VERTICAL_PLAN untouched.

## ACTUATOR_TELEMETRY_SEPARABILITY_001 — 2026-08-06 08:27:40

- Logical SIL: **PASS** — isolated telemetry emulator + fault-class separability; hardware/deployment **NOT_CERTIFIED**; production frozen; no NL rerun.
- Sources (≤3): ACTUATOR_FEEDBACK_TELEMETRY_ICD.md, RUDDER_FAULT_MAG_SPEED_COVERAGE.mat, RUDDER_CUSUM_DETECTOR.mat.
- Seeds TRAIN=6101:6120 VAL=7101:7140 (disjoint; disjoint from CUSUM); TBD thr frozen before VAL.
- ASSUMED models: τ=0.050s, σ_meas=0.050deg, current/BIT stubs; NOT hardware.
- VAL healthy FA_iso=0.0000%; STALE_iso=0 CONFLICT_iso=0; isolable P/R gate=PASS.
- TRACK: P=100.00% R=100.00%
- STALL: P=100.00% R=100.00%
- OPEN: P=100.00% R=100.00%
- SENS: P=100.00% R=100.00%
- HYDRO: P=100.00% R=100.00%
- Artifacts: suite_results/ACTUATOR_TELEMETRY_SEPARABILITY.{md,mat,png}; driver `run_actuator_telemetry_separability.m`.
- Next: bench/HIL identification and acceptance-test plan (AT-B*/AT-H*); revise only if hardware disagrees — do not retune controller.
- CODEX_VERTICAL_PLAN untouched.

## ACTUATOR_BENCH_HIL_ACCEPTANCE_PLAN_001 — 2026-08-06 08:32:29

- Plan: **PASS** (bench/HIL ID + acceptance-test plan only) — no hardware action; no production edit; no MATLAB run; no safe-mode promotion.
- Sources (≤3): ACTUATOR_FEEDBACK_TELEMETRY_ICD.md, ACTUATOR_TELEMETRY_SEPARABILITY.md, FAULT_ISOLATION_SAFE_MODE_REQUIREMENTS.md.
- Content: equipment, dry-bench SAFE interlocks/E-stop/current limits, wiring/time-sync, CAL sequence, data schema, roles, preconditions/aborts, evidence retention; AT-B1–B9 and AT-H1–H7 stepwise; FIXED vs SIL ASSUMED vs TO_BE_IDENTIFIED registry.
- Split: HW-TRAIN 8101:8120 / HW-VAL 9101:9140 (disjoint from SIL 6101/7101 and CUSUM 2101/3101); freeze-before-VAL; gates G-ALIGN/POS/PR/FA/DELAY/FAILSIL/NOACC/AF/ID2.
- Traceability R-AF*/R-ID*/ICD AT-* + test record template; blockers: vendor ICD, encoder/current telem, bench.
- Artifact: suite_results/ACTUATOR_BENCH_HIL_ACCEPTANCE_PLAN.md. Production frozen; CODEX_VERTICAL_PLAN untouched.
- EXTERNAL-HARDWARE GATE: **BLOCKED** — awaiting user materials; hardware NOT_CERTIFIED; safe-mode not authorized.
- Next: supply vendor ICD + bench telem → execute AT-B*/AT-H* campaign; revise thr only if hardware disagrees — do not retune controller; do not promote safe-mode.
- CODEX_VERTICAL_PLAN untouched.


## AUV_VISUAL_EVIDENCE_PACK_001 — 2026-08-06 15:23:11

- Pack: **PASS** — panels PASS/FAIL/NA=6/0/0; raw-MAT evidence only; no NL rerun; production frozen.
- Sources: PITCH_YAW_CLOSURE.mat (prod X/XZ/R10 paths); ROLL_PRODUCTION_CLOSURE.mat (accepted roll-damp full traj; not previously indexed in this log); GUIDANCE_MISSION_BASELINE.mat; RUDDER_CUSUM_DETECTOR.mat (Coverage PASS).
- Panels: (1) 3D path+CTE/depth (2) θ/ψ/φ windows (3) U/α/θ/γ + identity resid (4) δe/δr limits/sat/PSD@13.33Hz (5) pqr + pRMS roll-damp (6) B2/CUSUM/latch/FA.
- Roll pRMS R10: 2.7611→2.1700 (21.4%); CUSUM ex U=1.50 η=0.75 delay=1.175s FA=0.0000%.
- Artifacts: suite_results/AUV_VISUAL_EVIDENCE_PACK.{md,mat,png} + _00_overview + _01.._06_*.png; driver `run_auv_visual_evidence_pack.m`.
- Next: **`realism_gap_audit`** — only after pack PASS.
- CODEX_VERTICAL_PLAN untouched.


## REALISM_GAP_AUDIT_001 — 2026-08-06

- Audit: **PASS** (completeness) — Physical realism: **NOT_CERTIFIED** — read-only plant/sensor/actuator/computation gap audit; production frozen; no MATLAB run; no model/controller edits.
- Sources (≤3): `AUV_VISUAL_EVIDENCE_PACK.md` (PASS 6/0/0), `underwater777_vehicle_dynamics.m`, `controller_law.m` (path from this log).
- Findings: hydro coeffs globals/`ASSUMED` provenance+uncertainty absent; no ρ schedule; CG/CB/W-B opaque; Vc≡0; thrust=`Xprop` force; actuators = mag+40deg/s software slew only (no lag/deadband/backlash/hysteresis/current/thermal/feedback); sensing = plant truth (IMU/DVL/depth/heading/INS chain `NOT_IMPLEMENTED`); guidance PSD 13.33 Hz; rudder chatter **37.738 deg/s** + ±40 deg/s rate contact = physical-realism concern despite panel PASS; CUSUM/visual = sim evidence ≠ HW cert.
- Artifact: suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md.
- Next: **`actuator_dynamics_realism_baseline`** — isolated fin dynamics baseline (τ/rate/mag); no retune; CODEX_VERTICAL_PLAN untouched.


## ACTUATOR_DYNAMICS_REALISM_BASELINE_001 — 2026-08-06 15:54:31

- Shadow baseline: **PASS** — physical readiness **NOT_CERTIFIED**; isolated FO+mag+rate fin shadow from accepted R10 raw MAT cmds; production frozen; no NL rerun; no controller/plant edit.
- Sources (≤3): AUV_REALISM_AND_VISUAL_VALIDATION.md, AUV_VISUAL_EVIDENCE_PACK.md, ACTUATOR_FEEDBACK_TELEMETRY_ICD.md; cmds: ROLL_PRODUCTION_CLOSURE.mat candidate.SH.
- τ **ASSUMED** [0.05 0.1 0.2] s (ICD lacks vendor/bench τ). Limits FIXED δe±15 / δr±25 deg, ±40 deg/s. Nonuniform-dt handler ON.
- τ=0.10s δr: RMSE=0.7063 deg delay=0.0750s rate_dwell=0.00% PSD_att@13.33Hz=0.0205 u²δr_proxy=0.9828; cmd chatter δr=37.738 deg/s.
- Artifacts: suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.{md,mat,png}; driver `run_actuator_dynamics_realism_baseline.m`.
- Next: **`actuator_nonlinearity_stub_deadband_backlash`** — isolated δr deadband/backlash stub vs this FO baseline; no retune; CODEX_VERTICAL_PLAN untouched.


## ACTUATOR_RUDDER_DEADBAND_STUB_001 — 2026-08-08 01:00:57

- Deadband stub: **PASS** — physical readiness **NOT_CERTIFIED**; isolated FO(τ=0.10s ASSUMED)+play-free deadband on accepted R10 δr replay; production frozen; no controller/plant edit; open-loop replay **NOT** a closed-loop limit-cycle test.
- Sources (≤3): ACTUATOR_DYNAMICS_REALISM_BASELINE.md/.mat + run_actuator_dynamics_realism_baseline.m.
- Operator: y=0 if |x|≤w else y=x−w·sign(x); init memoryless on FO output; w **ASSUMED** [0 0.1 0.25 0.5] deg. Limits FIXED δr±25 deg, ±40 deg/s. No backlash/hysteresis/current invented.
- w=0.00: RMSE=0.7063 bias=-0.0022 TV=261.99 chat=8.8048 ZC=0 stick=0 dwell=0.00% PSD_att=0.0205 u²δr=0.9828.
- w=0.50: RMSE=0.8666 bias=-0.5022 TV=261.99 chat=8.8048 ZC=0 stick=0 dwell=0.00% PSD_att=0.0205 u²δr=0.8710.
- Artifacts: suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.{md,mat,png}; driver `run_actuator_rudder_deadband_stub.m`.
- Next: **`depth_gamma_coupled_plant_identification_gate`**. CODEX_VERTICAL_PLAN untouched.


## DEPTH_GAMMA_COUPLED_PLANT_ID_001 — 2026-08-08 01:45:23

- Gate-1 coupled plant ID: **PARTIAL** — level/climb sagittal model from validated SS; production frozen; no retune.
- Sources (exactly 3): LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat, SS_VALIDATION.mat.
- Model: x=[z,θ,u,w,q], u=[δe,thrust]; θ_phys=-θ; α=atan2(w,u) analytic lin; γ=θ_phys+α.
- LEVEL u*=1.817 α*=-1.3044 deg; CLIMB u*=1.755 α*=-2.1824 deg.
- Poles unstable (reduced): L=[+0.735+0i; +0.2411+0i] C=[+0.4871+0.2493i; +0.4871-0.2493i]; ctrl/obs ranks L=5/5 C=5/5.
- SS_VALIDATION transform RMSE/corr: 4/4 cases PASS (tol nrmse≤0.20, corr≥0.95).
- Honesty: U=1.5-class only; no bounded U=1.0/2.0 family in sources → not full Gate-1 PASS.
- Artifacts: suite_results/DEPTH_GAMMA_COUPLED_PLANT_ID.{md,mat,png}; driver `run_depth_gamma_coupled_plant_id.m`.
- Next: **`depth_gamma_speed_scheduled_id_extension`** (U=1.0,1.5,2.0). CODEX_VERTICAL_PLAN untouched.


## DEPTH_GAMMA_SPEED_SCHEDULED_ID_001 — 2026-08-08 02:08:18

- Gate-1 speed-scheduled coupled plant ID: **PASS**.
- U_cmd={1.0,1.5,2.0}×{level,climb}; BODY surge fixed exact-by-construction; U_total=hypot(u,w) reported separately.
- Scores: trim 6/6, jac 6/6, val 12/12 (tol nrmse≤0.20 corr≥0.95).
- LPV: level env `U_cmd in [1.0, 2.0] with 3/3 valid`; climb env `U_cmd in [1.0, 2.0] with 3/3 valid`; hydro CI NOT_CLAIMED.
- Artifacts: suite_results/DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}; driver `run_depth_gamma_speed_scheduled_id_extension.m`.
- Next: **`depth_gamma_structural_decoupling_governor_aw_gate`**. CODEX_VERTICAL_PLAN untouched.


## DEPTH_GAMMA_STRUCTURAL_GATE_001 — 2026-08-08 02:38:40

- Gate-2 structural decoupling/governor/AW/bumpless: **PARTIAL**.
- Primary KPI (a priori) grid_mean_depth_MAE: 0.269528→0.232264 (Δ13.83%).
- Secondary worse% [th,g,a]=[28.25 -0.13 11.26]; Pareto track=13.83 act=0.00 safety=1.
- Blocker: `secondary_regression_max_28.25%`.
- Artifacts: suite_results/DEPTH_GAMMA_STRUCTURAL_GATE.{md,mat,png}; helper `guidance_law_depth_gamma_structural.m`; driver `run_depth_gamma_structural_gate.m`.
- Next: **`depth_gamma_structural_gate_blocker_fix`**. CODEX_VERTICAL_PLAN untouched.


## DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX_001 — 2026-08-08 03:02:03

- Gate-2 attempt 2/3 blocker-fix (delta_alpha, α residual about sched): **PARTIAL**.
- Old raw primary: 0.269528→0.232264 (Δ13.83%); corrected B→C: 0.269528→0.233640 (Δ13.32%).
- Secondary worse% [th,g,a]=[20.18  -6.13 -24.47]; Pareto track=13.32 act=0.00 safety=1.
- Blocker: `secondary_regression_max_20.18%`.
- Artifacts: suite_results/DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX.{md,mat,png}; helper `guidance_law_depth_gamma_structural_blocker_fix.m`; driver `run_depth_gamma_structural_blocker_fix.m`.
- Next: **`depth_gamma_structural_gate_blocker_fix_attempt3`**. CODEX_VERTICAL_PLAN untouched.


## DEPTH_GAMMA_STRUCTURAL_ATTEMPT3_001 — 2026-08-08 03:23:53

- Gate-2 attempt 3/3 blocker-fix (delta_alpha, α residual about sched): **FAIL**.
- Old raw primary: 0.269528→0.232264 (Δ13.83%); corrected B→C: 0.269528→0.454460 (Δ-68.61%).
- Secondary worse% [th,g,a]=[-19.21  89.67 -24.33]; Pareto track=-68.61 act=0.00 safety=1.
- Blocker: `primary_KPI_improve_-68.61%_lt_5.0%`.
- Artifacts: suite_results/DEPTH_GAMMA_STRUCTURAL_ATTEMPT3.{md,mat,png}; helper `guidance_law_depth_gamma_structural_attempt3.m`; driver `run_depth_gamma_structural_attempt3.m`.
- Method status: **CLOSED_AFTER_3_ATTEMPTS**; residual risk/waiver: Depth improvement remains structurally coupled to theta/gamma/alpha tracking; production stays frozen and any acceptance requires an explicit waiver.
- Next: **`closed_loop_actuator_realism_gate`**; no attempt4. CODEX_VERTICAL_PLAN untouched.


## CLOSED_LOOP_ACTUATOR_REALISM_001 — 2026-08-08 03:59:40

Result: **PARTIAL** (12/48 hard failures); isolated Gate 3 SIL, production frozen, physical values ASSUMED, NOT_CERTIFIED.  
Next: bench-identify actuator lag/deadband/delay before promotion; retain isolated regression matrix.


## CLOSED_LOOP_ACTUATOR_HARNESS_FIX_001 — 2026-08-08 04:16:05

Result: **FAIL**; Gate 3 attempt 2, 1 hard/blocking cases. R10 accepted-baseline parity and first/last order sentinel are mandatory; production frozen; all actuator values ASSUMED, NOT_CERTIFIED; CODEX_VERTICAL_PLAN untouched.  
Next: resolve the reported causal harness/parity blocker before drawing any actuator conclusion.


## CLOSED_LOOP_ACTUATOR_HARNESS_FINAL_001 — 2026-08-08 04:40:03

Result: **FAIL**; Gate 3 final attempt 3/3, disposition **CLOSED_AFTER_3_ATTEMPTS**, 1 hard/blocking cases. R10 accepted-baseline parity and first/last order sentinel are mandatory; production frozen; all actuator values ASSUMED, NOT_CERTIFIED; CODEX_VERTICAL_PLAN untouched.  
Next: Gate3 CLOSED_AFTER_3_ATTEMPTS; proceed to Gate4 water-relative-current/feasibility guidance; no attempt4.
Residual risk: Actuator values remain assumed and require bench/HIL identification; current-relative feasibility remains unevaluated.


## NAV_MULTIRATE_SENSOR_CHAIN_001 - 2026-08-08 13:28:55

Result: **PASS** (Gate 5A, isolated). A multirate TRUTH / MEASURED / ESTIMATED bus contract was defined and verified over 12 deterministic cases; 12/12 PASS. The finding that matters for later control work is that ground-relative and water-relative measurement channels are only distinguishable once a current is present: at Vc = 0 the DVL and INS channels are numerically interchangeable, so any controller or observer validated at Vc = 0 cannot have exercised the frame distinction it depends on.
Availability semantics (validity, quality, stale age, sequence) are now explicit, so a later estimator can reject a stale or bottom-lock-lost DVL sample instead of silently consuming a held value.
All sensor values ASSUMED and NOT identified; ESTIMATED bus deliberately INVALID; no navigation-performance claim; production frozen; Gate 4 remains FAIL / shadow-only; CUSUM / SIL simulation-only; CODEX_VERTICAL_PLAN untouched.
Next: **Gate 5B multirate EKF and availability manager** on this frozen bus.
Residual risk: sensor noise / bias / delay remain assumed and require bench or sea-trial identification; observability under sustained DVL outage is unevaluated.


## NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION_001 - 2026-08-08 14:12:31

Result: **PASS** (Gate 5A, independent process-compliant validation). The frozen 12-case multirate sensor-chain matrix was re-run inside a single MATLAB process; 12/12 cases and 16/16 declared gates PASS, with a maximum relative deviation of 0 from the prior artifact across seven parity categories including the full decimated showcase series. The methodological finding worth carrying forward is that process compliance and technical correctness are independent failure modes: the prior run was reproducible to the last bit yet could not formalize a gate, because four MATLAB starts left its provenance unverifiable. Publishing per-case pack checksums makes any future re-run comparable without re-deriving a single metric, which is the cheap fix for that class of problem.
No number was tuned, no model was added and no estimator was written; the ESTIMATED bus remains deliberately INVALID and USBL remains absent, so no navigation-performance claim is made or implied. All sensor numerics remain ASSUMED and require bench or sea-trial identification.
Gate 5A PASS is formalized on this compliant run. Next: **Gate 5B multirate EKF and availability manager** on the frozen bus contract.
Production frozen; Gate 4 waiver remains OPEN / shadow-only; CUSUM / SIL simulation-only; CODEX_VERTICAL_PLAN untouched.
Residual risk: sensor noise, bias and delay remain assumed; observability under sustained DVL outage is unevaluated until an estimator exists.

### 2026-08-08 15:18:11  NAV_MULTIRATE_EKF_BASELINE_001 (Gate 5B, PASS)

- Verdict PASS. Frozen Gate 5A cases 12/12 integrity-clean, hard gates 28/28.
- IMPLEMENTED: 18-state error-state EKF (p_NED, v_NED, quaternion, gyro/accel bias, NED current)
  with Joseph covariance update, error-state reset Jacobian, quaternion renormalization and
  wrapped heading innovation; deterministic timestamp-driven multirate scheduling; availability
  manager with explicit initialization, per-channel admission, DVL outage suppression, per-channel
  accepted/rejected counters and resume without reset; ESTIMATED bus exposing timestamp, sequence,
  covariance, status, source mask and health.
- DERIVED: process-noise densities sigma_a and sigma_g from the declared ASSUMED discrete sensor
  sigma and rate (sigma_cont = sigma_disc*sqrt(T)).
- ASSUMED: every R, every P0, the gyro/accel bias and current random walks, the quality/stale/
  sequence admission thresholds, the divergence-guard threshold and the latency inflation scales.
  Upstream sensor numerics were already ASSUMED at Gate 5A, so nothing here can be IDENTIFIED.
- Truth blindness proved empirically: the estimator consumes a sanitized MEASURED bus, and
  scrambling every truth-side bus field left the estimate bitwise unchanged.
- SIMULATION-ONLY BOUNDARY: TRUTH is a prescribed kinematic scenario, not a plant or closed-loop
  run. Production plant/controller/guidance were never invoked. Integrity and interface gates
  decide this baseline; accuracy is CHARACTERIZATION ONLY and NOT_CERTIFIED. No promotion is
  made. Gate 4 waiver remains OPEN / shadow-only.

- Research note: the interesting result is structural, not numeric. With USBL absent the NED
  current state is observable only through the DVL/INS pair, so while the DVL is suppressed it
  receives no correction and its covariance grows on the declared random walk. Because INS
  velocity stays available through the declared outage, the ground solution remains bounded, so
  these 12 cases exercise DVL suppression and recovery rather than a dead-reckoning collapse; the
  measured outage drift and reacquisition jump are recorded in the artifact as-is.
- NIS was reported exactly as measured and never absorbed into R. The unmodelled ASSUMED sensor
  biases and the latency approximation are the only mechanisms in this design that can inflate
  it, and both are declared rather than tuned away.
- Next untried structures, recorded and NOT attempted: (a) delay-compensated fusion replaying a
  buffered state/covariance to the packet timestamp; (b) explicit depth-bias and heading-bias
  states to make the declared sensor biases observable; (c) observability-aware current handling
  that freezes the current state while the DVL is suppressed.


### 2026-08-08 16:08:37  NAV_MULTIRATE_EKF_ARTIFACT_REPAIR_001 (Gate 5B EVIDENCE_REPAIR, PASS)

- EVIDENCE_REPAIR. Verdict PASS. Frozen Gate 5A cases 12/12 integrity-clean, frozen hard gates 28/28, repair gates 17/17.
- EVIDENCE_REPAIR scope: the Gate 5B result was correct; its Markdown rendering was not.
  Defect MD_INNOVATION_TABLE_FPRINTF_TYPE_MISMATCH: the innovation/NIS row applied the
  numeric conversion %.3f to hdeg(h), which returns a char array. MATLAB fprintf consumed
  the character codes, shifted every later argument and recycled the format, producing a
  table with displaced cells and merged case rows. Fix: %.3f -> %s for the heading cell.
  Report writer only; no estimator, gate, threshold, seed, tick count or metric was touched.
- DERIVED (this task): parity against the prior MAT is EXACT - 24/24 compared fields identical under
  isequaln at tolerance 0, all 12 per-case estimate checksums identical (YES), frozen production
  fingerprint byte counts identical (YES). The prior verdict PASS is reproduced, not re-decided.
- DERIVED (this task): the delivered MD is decoded from disk and its innovation table proved well
  formed - exactly 12 data rows, five cells each, frozen label order, type-correct heading/INS/DVL
  cells and every cell equal to the MAT metrics re-formatted: PASS.
- DERIVED (this task): cross-process reproduction. The same inputs run in a separate MATLAB
  process reproduce the prior results bitwise, which is stronger evidence than the prior
  run's same-process replay could give.
- The prior artifacts suite_results/NAV_MULTIRATE_EKF_BASELINE.{md,mat,png} are PRESERVED
  and were proved unchanged by byte count, timestamp and full-file content hash taken
  before and after every write.
- NO new engineering evidence, NO tuning, NO estimator change, NO gate change, NO promotion.
  Accuracy remains CHARACTERIZATION ONLY and NOT_CERTIFIED. Gate 4 waiver remains OPEN /
  shadow-only. Simulation-only.

- Research note: the transferable lesson is about verification coverage, not navigation.
  Every gate in the prior run inspected computed quantities; none inspected the rendered
  artifact. A format/argument type mismatch is invisible to that gate set because MATLAB
  fprintf does not raise on it - it silently reinterprets a char argument as character
  codes under a numeric conversion. The general defect class is "the evidence is wrong
  even though the result is right", and the general remedy applied here is to decode the
  written artifact and compare it back to the data structure it was generated from.
- Next untried structure for this defect class, recorded and NOT attempted: emit report
  tables through a typed column writer that formats each cell from a declared column type,
  so the mismatch becomes impossible by construction rather than caught by review.
- The estimator research questions are unchanged and untouched by this task: unmodelled
  ASSUMED sensor biases, the latency-inflated R approximation, and the unobservability of
  NED current while the DVL is suppressed.
- NEXT: GATE 5C (named, not attempted here): outage / optional-USBL stress. Extend the declared outage matrix (longer, repeated and overlapping DVL gaps, plus INS and heading dropouts) and admit the OPTIONAL USBL channel as an intermittent, latent, low-rate absolute fix, to test manager behaviour and observability recovery under combined aiding loss. Numerics remain ASSUMED and accuracy remains NOT_CERTIFIED.


### 2026-08-08 17:15:01  NAV_AVAILABILITY_OUTAGE_STRESS_001 (Gate 5C AVAILABILITY_OUTAGE_STRESS, PASS)

- ISOLATED Gate 5C stress, NO PROMOTION. Verdict PASS. Predeclared cases 24/24 integrity-clean, hard gates 32/32.
- IMPLEMENTED: a fork of the frozen Gate 5B estimator adding (a) an OPTIONAL USBL NED
  position update fused only when the bus declares the channel present and the packet
  passes the existing admission tests, and (b) a health-only availability state machine
  over NOMINAL / DEGRADED / POSITION_AID_LOST / RECOVERING with per-channel stale-age
  thresholds and asymmetric entry/exit dwell (hysteresis). The Gate 5B files were not
  modified; they were executed unchanged and their 12 per-case checksums reproduced
  exactly (12/12).
- IMPLEMENTED: a 24-case predeclared matrix, 3 routes x 2 currents x 4 outage profiles
  (DVL lock + USBL absent, long DVL outage + USBL absent, long DVL outage + intermittent
  USBL, simultaneous DVL and heading outage + intermittent USBL).
- ASSUMED: every outage window, USBL rate / delay / noise / bias / dropout schedule,
  every R, P0, dwell time and admission threshold. All predeclared before execution and
  never revisited; no tuning rerun.
- DERIVED: per-channel freshness horizon from the declared ICD period and stale limit;
  the USBL latency scale from the declared ground speed.
- DERIVED (this task): the health state is provably status-only. Disabling the state
  machine, and separately halving every dwell threshold, leaves the estimated state
  bitwise identical while the health timeline itself changes, so the ablation is not
  vacuous. No accommodation, no reconfiguration, no reset and no surface command exists.
- DERIVED (this task): the USBL simulator reads TRUTH to form MEASURED packets, and the
  estimator is still provably truth-blind - the truth-reference field is dropped by the
  sanitizer and scrambling the entire truth block leaves the estimate bitwise unchanged.
- Accuracy AND outage limits are CHARACTERIZATION and NOT_CERTIFIED. Only integrity and
  state-machine gates decide the verdict. Gate 4 waiver remains OPEN / shadow-only.
  Simulation-only.
- DECLARED PROCESS DEVIATION: 2 MATLAB starts, not one. The first start ran the whole
  computation and then aborted in the report writer before delivering any artifact; only
  the reporting layer was repaired between starts. No estimator code, gate, threshold,
  window, seed or filter constant changed, so no result was retuned.

- Research note: the transferable result is that a health state machine should be built
  as a pure function of the estimator output, evaluated after the estimate, so that
  "status only" is a structural property provable by ablation rather than a claim in a
  comment. The second transferable point is that the position-aid set must exclude aids
  that cannot bound the error being declared lost - counting INS velocity would have
  produced a state machine that never fires and gates that always pass.
- Next untried structure, recorded and NOT attempted: declare POSITION_AID_LOST from the
  predicted horizontal covariance crossing a declared bound instead of from message age,
  which turns the declaration into a statement about the estimate rather than the bus.
- Open estimator questions are unchanged: unmodelled sensor biases, the latency-inflated
  R approximation, and the unobservability of NED current while the DVL is suppressed.
- NEXT: GATE 6 (named because Gate 5C passed, NOT attempted here): PROPULSION / POWER / COMPUTE budget and margin. Take the actuator commands and the navigation duty cycle this vertical already produces and close them against a declared thruster and control-surface power model, an energy budget over the mission profile, and a compute-load / latency budget for the estimator and controller rates. Numerics remain ASSUMED and every result remains NOT_CERTIFIED until bench data exists.


### 2026-08-08 17:59:46  NAV_AVAILABILITY_OUTAGE_VALIDATION_001 (Gate 5C process-compliant validation, PASS)

- ISOLATED re-validation of Gate 5C, NO PROMOTION. Verdict PASS. ONE MATLAB start.
- VALIDATED: the frozen 24-case Gate 5C matrix re-executed clean 24/24, hard gates 32/32, validation
  gates 16/17, and 16/16 parity records identical to the prior evidence with 16
  bitwise exact and a largest observed difference of 0.000e+00.
- VALIDATED: labels, tick counts, seeds, packet counters, health transition sequences and
  declaration instants, decimated estimator and health series, characterization metrics,
  per-case estimated-state checksums and the verdict all reproduce exactly.
- VALIDATED: the frozen Gate 5B numeric fingerprint reproduced 12/12 in this process, and the
  Gate 5B files, the Gate 5C files, the prior Gate 5C artifacts, the frozen production
  files and CODEX_VERTICAL_PLAN.md are all byte-, timestamp- and Adler-32-identical
  after the run.
- VALIDATED: truth blindness, determinism under reverse-order replay, the status-only
  ablation of the health state machine and the manager negative test, all re-established
  inside this single process rather than inherited.
- ASSUMED (unchanged, transcribed verbatim, never revisited): every outage window, the
  USBL rate / delay / noise / bias / dropout schedule, every R, P0, dwell time and
  admission threshold. NO_TUNING_RERUN: the transcription is proved by literal-text
  markers on the frozen driver and by exact comparison against the recorded schedule.
- DERIVED (unchanged): per-channel freshness horizon from the declared ICD period and
  stale limit; the USBL latency scale from the declared ground speed.
- PROCESS: the prior run is recorded as TECHNICAL_PASS / PROCESS_NONCOMPLIANT. Its
  numbers stand and are now corroborated by an independent process-clean execution
  instead of by its own second start.
- Accuracy AND outage limits remain CHARACTERIZATION and NOT_CERTIFIED. This task adds
  reproducibility evidence, not physical evidence. Gate 4 waiver remains OPEN /
  shadow-only. Simulation-only.

- Research note: the transferable result is that reproducibility should be a first-class
  artifact, not an assumption. Archiving a per-case checksum of the full-rate state pack
  alongside decimated series made a full re-derivation diffable at sample level for a
  few kilobytes, and that is what let a process objection be settled without touching a
  single number.
- Next untried structure, recorded and NOT attempted: have the stress driver emit a
  signed manifest of every checksum, counter vector and transition instant, and add a
  standalone verifier that recomputes the verdict from the manifest without running the
  estimator, so a process repair never has to re-enter the numerics.
- Open estimator questions are unchanged: unmodelled sensor biases, the latency-inflated
  R approximation, and the unobservability of NED current while the DVL is suppressed.
- NEXT: GATE 6 (named because Gate 5C is now formalized, NOT attempted here): PROPULSION / POWER / COMPUTE budget and margin. Take the actuator commands and the navigation duty cycle this vertical already produces and close them against a declared thruster and control-surface power model, an energy budget over the mission profile, and a compute-load / latency budget for the estimator and controller rates. Numerics remain ASSUMED and every result remains NOT_CERTIFIED until bench data exists.


## PROPULSION_POWER_COMPUTE_BASELINE_001 — 2026-08-08 19:09:49 (research log)

- Verdict: **FAIL**. Gate6 isolated propulsion/power/compute budget, **no promotion**.
- Status: SIMULATION_ONLY / NOT_CERTIFIED; Gate4 evidence shadow-only; production untouched (fingerprints byte-identical pre/post).
- Ideal parity across 8 cases: bitwise exact (G1 PASS). Deterministic replay: bitwise identical (G6 PASS).
- Grid: X/XZ at U={1,1.5,2} m/s, R10 at U={1.5,2} m/s; ASSUMED thruster variants ideal / nominal lag-map / slow+low-authority / high-authority; no tuning.
- Worst-corner budget: <= 15.59 Wh/km, peak bus current <= 6.88 A, peak realized thrust 14.054 N, fin moving duty <= 99.7%.
- Energy margin +0.896 and current margin +0.541 at the pessimistic ASSUMED corner (hardware TO_BE_IDENTIFIED; ranges only, no vendor).
- Compute: controller 40 Hz, guidance 13.33 Hz, 42000 controller calls, 2564886 plant RHS evaluations, 31.919 ms/step host mean (NOT WCET).
- Pareto non-dominated ASSUMED variants: ideal, nominal, slow_low, fast_high.
- Limiting gate(s): G3,G3C | limiting case: XZ@2.00 / ideal (pitch_MAE(0.3665>0.30))
- Next: BLOCKED (Gate6B requires PASS) — Tracking, not propulsion, is limiting at the ideal actuator. The next bounded structure is a speed/route-scheduled reference governor for the frozen cascade, evaluated in its own isolated gate before any power budget is reopened. No rerun and no gain change in this task.
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_BASELINE.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_BASELINE.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_BASELINE.png`; driver `run_propulsion_power_compute_baseline.m`, declarations `propulsion_power_compute_case.m`.
- CODEX_VERTICAL_PLAN untouched.

## PROPULSION_POWER_COMPUTE_PARITY_FIX_RESUME_001 — 2026-08-08 23:07:01

- Marker: `PROPULSION_POWER_COMPUTE_PARITY_FIX_RESUME_001` (single append per log).
- Gate6 attempt2 **RESUMED** after host-power/bridge interruption; not attempt3. attempt1 FAIL (shadow-only) and the interrupted attempt2 record are preserved.
- Verdict: **PASS** (12/12 gates PASS). Simulation-only, **NOT_CERTIFIED**; Gate4 shadow-only.
- Ideal-hook parity vs frozen `SPEED_ENVELOPE_AUDIT`: 8/8 cells exact, tol 1e-12 declared.
- Method: marker clone of the accepted tracking loop inserts realized thrust between controller and plant; `prop.ideal` is an exact passthrough, which makes ideal-hook parity bit-identical and therefore a real falsification test of the harness.
- Pareto (speed MAE vs mid-bracket energy): 9 nondominated (variant, cell) points of 32.
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.png`.
- Production untouched; no gain, config or controller change.

<!-- REAL_TIME_POWER_INTEGRITY_CONTRACT_001 -->

## Gate 6B - REAL_TIME_POWER_INTEGRITY_CONTRACT (REAL_TIME_POWER_INTEGRITY_CONTRACT_001)

**Date:** 2026-08-08 - **Verdict:** **PASS** (13/13 declared hard gates) - **NOT_CERTIFIED** (simulation-only)

- Research finding: with the declared budgets, transport delay is **not** a CPU-schedulability stressor - 15/30 ms delay left controller deadline misses at 0/0 while pushing end-to-end guidance-to-actuator latency to 100.9 / 118.1 ms against declared bounds 145.0 / 160.0 ms. Delay is a *latency/authority* problem, not a *deadline* problem.
- Research finding: a controller that misses every deadline cannot command its own safe-hold. A **priority-above-controller safety watchdog** with an independent bounded emission path was required for the overload case to degrade safely (watchdog misses = 0 under the worst burst).
- Research finding: power and timing are **coupled** - undervoltage throttling stretches execution, so a brownout is simultaneously a power event and a schedulability event. Modelling them separately would understate risk.
- Discipline note: host wall-clock runtime is reported separately and is explicitly **not** WCET evidence; all WCET fields remain requirement budgets.
- Untried next task recorded in `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.md` Sec. 10.

---

## Append: GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_001 (PARTIAL)

**Date:** 2026-08-09 00:50:23 - **Class:** Gate 7 isolated mission-manager / FDIR **simulation** - **MATLAB runs:** 1 - **production:** byte-identical - **CODEX_VERTICAL_PLAN:** untouched  
**Verdict:** **PARTIAL** (14/15 hard gates) - **Physical / hardware readiness: NOT_CERTIFIED**

- Isolated harness (`run_gate7_mission_manager_fail_silent_sim.m`) exercises MissionCommand / WaypointSet / TrajectorySegment / Ack with the full ICD header (`schema_version`, mission/segment id, `seq`, `t_mono`, valid/quality/integrity, NED/SI tags, validity horizon, heartbeat) over 16 frozen ASSUMED scenarios, each replayed twice.
- 9 monitors (leak, undervoltage, watchdog overrun, actuator stuck/current, IMU/DVL/depth stale, bus timeout, mission stale) with declared precedence, latching and 1.0 s recovery hysteresis; response ladder hold-last-safe -> constrain -> safe-hold.
- Detected 17/17 injected faults inside declared bounds, 0 false alarms, 0 missed, 0 Ack-code mismatches, 0 surface / 0 accommodation / 0 direct-actuator commands issued.
- Labels unchanged: mission/nav/actuator-feedback rates `TO_BE_IDENTIFIED`; all fault numbers `ASSUMED`; message contract `INTERFACE_SPECIFIED`; harness `IMPLEMENTED` (simulation); hardware `NOT_CERTIFIED`.
- Evidence: `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.{md,mat,png}`.

**Research note:** fail-silent ladder and monitor precedence are now observable in an isolated harness; no pitch/depth controller was reopened, retuned, or promoted by this task.

---

<!-- APPEND_MARKER:GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001 -->

## Append: GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001 (PASS)

**Date:** 2026-08-09 01:18:18 - **Class:** Gate 7 attempt 2, acceptance-criterion repair + identical re-run (**simulation**) - **MATLAB runs:** 1 - **production:** byte-identical - **CODEX_VERTICAL_PLAN:** untouched - **attempt-1 artifacts:** preserved  
**Verdict:** **PASS** (17/17 hard gates) - **Physical / hardware readiness: NOT_CERTIFIED**

- Repaired exactly two acceptance definitions named by the attempt-1 report: the recovery expectation becomes three-valued (`must_recover` / `must_not_recover` / `not_applicable_no_degradation`, with `S01` and `S14` not applicable but still required to show zero trips, zero episodes and zero degraded dwell), and detect-to-action becomes the time until the active response severity reaches the severity the monitor requires, so an already-active higher-severity response counts as immediate.
- The identical frozen 16-case matrix was re-executed twice; no method, scenario, threshold, injection window, monitor or plant surrogate changed. Raw-behaviour parity against the attempt-1 MAT is asserted as a hard gate (HG16): per-case hashes, full log and Ack matrices, every unaffected metric, the scenario matrix and the configuration all compare exactly equal (YES).
- Criterion scope is itself gated (HG17): the only added fields are the three-valued class and the severity-based action-gap trio; nothing was removed.
- Repaired worst detect-to-action 0.0000 s against the unchanged 0.200 s bound; false alarms 0, missed detections 0, surface / accommodation / direct-actuator commands issued 0 / 0 / 0.
- Labels unchanged: mission/nav/actuator-feedback rates `TO_BE_IDENTIFIED`; all fault numbers `ASSUMED`; message contract `INTERFACE_SPECIFIED`; harness `IMPLEMENTED` (simulation); hardware `NOT_CERTIFIED`.
- Evidence: `suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.{md,mat,png}`.

**Research note:** the Gate 7 failure was an acceptance-criterion defect, not a monitor defect; correcting the criterion and re-running bit-identically separates "the test was wrong" from "the system was wrong". No pitch/depth controller was reopened, retuned or promoted by this task.


<!-- APPEND_MARKER:GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001 -->

## Append: GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001 (research log)

**Date:** 2026-08-09 02:02:08 | **Class:** Gate 8 isolated Monte Carlo campaign, shadow-only driver | **MATLAB runs:** 1 | **Production/CODEX:** untouched | **HW:** NOT_CERTIFIED

**Verdict: FAIL.** Failed hard gates: HG5, HG8, HG11, HG12, HG13.

- Campaign: seed `20260809`, 32 independent draw vectors x 8 production cells (X/XZ U={1,1.5,2}, R10 U={1.5,2}), dt=0.025 s, T=30 s.
- Pass probability 0.4023, Wilson 95% CI [0.3441, 0.4634] over 256 Monte Carlo runs.
- Pooled cte_max P5/P50/P95/worst = 0.110 / 0.342 / 0.565 / 0.826 m.
- Exact nominal parity (shadow hooks-off == unmodified `continuous_path_tracking`): 1. Deterministic reverse-order replay: 1.
- Honest gaps: CG/CB/buoyancy priors **UNSUPPORTED** (drawn, never injected - no shadow plant-parameter interface); power **PARTIAL** (thrust-authority derate only); estimator streams **NOT_IMPLEMENTED**; Gate 7 16-case FDIR matrix **not re-drawn**; X/XZ/R10 cell geometry is an **ASSUMED_RECONSTRUCTION**.
- All priors remain **ASSUMED**. Simulation result is not hardware certification (**NOT_CERTIFIED**).
- Evidence: `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.{md,mat,png}` plus 4 visual-QA panels.
- Gate 9 remains **locked** (unlocks only on Gate 8 PASS); Gate 9B remains post-Gate 9.
- Next exact task: `gate8_plant_parameter_shadow_interface` (shadow-only reducible clone of the plant giving CG/CB/buoyancy an injection seam; parity-first).


<!-- APPEND_MARKER:GATE8_ACTUATOR_ORDER_SCAN_REPAIR_001 -->

## Append: GATE8_ACTUATOR_ORDER_SCAN_REPAIR_001 (research log)

**Date:** 2026-08-09 04:30:20 | **Class:** Gate 8 attempt 2, isolated shadow-only harness defect repair | **MATLAB runs:** 1 | **Production/CODEX:** untouched | **HW:** NOT_CERTIFIED

**Verdict: FAIL.** Failed hard gates: HG5, HG11, HG12, HG13. Repairs: D1 limiter ordering REPAIRED, D2 token audit REPAIRED.

- **Frames and units.** Positions NED in m with z positive down (depth = +z); BODY rates p,q,r in rad/s and BODY velocity u,v,w in m/s; Euler angles in rad internally, deg only where a name says so; fin deflections in deg with the declared envelope elevator 15 deg, rudder 25 deg, rate 40 deg/s; bus voltage in pu; thrust in the native production thrust unit, which this task does not assume to be per-unit; rail and rate dwell are dimensionless fractions of a run.
- **Provenance.** Exactly 3 sources read: `run_gate8_monte_carlo_independent_priors.m`, `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.mat`, `suite_results/GATE8_MONTE_CARLO_INDEPENDENT_PRIORS.md`. The frozen sensor/power/monitor configuration is dereferenced by reference from the path attempt 1 recorded, not re-derived. Frame block carried verbatim from the Gate 7 chain. Cell geometry remains an ASSUMED_RECONSTRUCTION.
- **Campaign reused, not redefined.** Seed `20260809`, 32 independent draw vectors x 8 cells (X/XZ U={1.0,1.5,2.0}, R10 U={1.5,2.0}), dt 0.025 s, T_final 30 s, replay draws [1 16 32]. The regenerated draw matrix is bit-identical to the attempt-1 record (fingerprint `n=8960.s1=1128826.s2=716413287`).
- **Verification ran before comparison.** Nominal parity fingerprints matched attempt 1 in 8/8 cells for the production call and 8/8 for the hooks-off shadow; 32 replay runs reproduced within this run; 9 legacy-order A/B runs reproduced attempt-1 Monte Carlo hashes bit-for-bit, proving the limiter position is the only behavioural change. Metric comparison admitted: 1.
- **D1 result.** With the fin magnitude and rate limiters moved downstream of the transport-delay and jitter resampler, the maximum realized fin slew over all 256 Monte Carlo runs is 40.000 deg/s against the declared 40 deg/s, and the rate-violation population is 0 (attempt 1 recorded 151 of 256, which was manufactured by the ordering).
- **D2 result.** The forbidden-token audit assembles each token from fragments at run time and excludes its own fenced declaration, so it cannot self-match; hits including the declaration region = 0, excluding = 0, positive control detected 10/10 tokens. The substantive counters are retained and remain zero: surface 0, automatic accommodation 0, direct-actuator path 0.
- **Genuine evidence preserved.** The nominal R10 rudder still reaches the 25 deg rail with the dwell recorded in section 13; that measurement comes from the hooks-off path which is bit-identical to unmodified production, so it describes the frozen controller under a 0.1 per-metre curvature, not the priors and not the harness.
- **Pass probability** 0.8594, Wilson 95% CI [0.8115, 0.8967] over 256 Monte Carlo runs.
- **Honest, still-open failures.** HG11 CG/CB/buoyancy priors have no injection seam and are drawn but never applied; HG12 the Gate 7 16-case FDIR matrix was not re-drawn; HG13 the cell geometry is a reconstruction. This task could not and does not claim a Gate 8 PASS. Power is PARTIAL and partly unexercised: the brownout branch was never entered.
- **Evidence:** `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR.{md,mat,png}`, 7 figures, plus `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR_run.log`. Visual QA verdict VISUAL_QA_PASS.
- **Next exact task:** `gate8_frozen_cell_and_plant_seam_closure` - bind the frozen X/XZ/R10 cell definitions, re-drive the Gate 7 16-case matrix through this shadow loop under the same draws, and add a shadow-only reducible plant clone giving CG/CB/buoyancy an injection seam; parity-first acceptance against the nominal hashes recorded here.
- All priors remain **ASSUMED**. Simulation is not hardware certification (**NOT_CERTIFIED**). Gate 9 remains **locked**; Gate 9B remains post-Gate 9.


<!-- APPEND_MARKER:GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_001 -->

## Append: GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_001 (research log)

**Date:** 2026-08-09 06:35 | **Class:** Gate 8 attempt 3, isolated shadow-only structural closure | **MATLAB runs:** 1 | **Production/CODEX:** untouched | **HW:** NOT_CERTIFIED

**Verdict: FAIL.** Failed hard gates: HG1, HG2, HG5, HG11, HG12, HG13, HG18 (7 of 29). Gate 9 remains **locked**.

- **Frames and units.** Carried verbatim, not re-derived: NED positions in m with z positive down (depth = +z); BODY velocity u,v,w in m/s and BODY rates p,q,r in rad/s; Euler angles in rad internally, deg only where the name says so; fin deflections in deg with the declared envelope elevator 15 deg, rudder 25 deg, rate 40 deg/s; bus voltage in pu; rail and rate dwell dimensionless as a fraction of a run. CG/CB offsets are BODY-frame m; buoyancy_frac dimensionless.
- **Provenance.** Exactly 3 sources read, no repo scan: `continuous_path_tracking_propulsion.m`, `suite_results/GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.mat`, `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR.mat`. All 6 production/CODEX files are byte-identical to the accepted Gate 7 record before and after the run (6/6 against Gate 7, 6/6 against attempt 2). One MATLAB invocation, no retry, peak footprint 0.554 MiB against the 300 MiB ceiling, host runtime 52.6 s.
- **Campaign reused exactly.** Seed `20260809`, 32x35 draw matrix regenerated bit-identically (fingerprint `n=8960.s1=1128826.s2=716413287`), 8 cells, dt 0.025 s, T_final 30 s, and the D1-repaired delay -> magnitude/rate limiter order. Independent rescoring of all 256 Monte Carlo runs from the stored records reproduced attempt 2 with max absolute delta 0.0 on both the P50 and the worst-case KPI vectors; pass probability 0.8594, Wilson 95 percent CI [0.8115, 0.8967].
- **HG11 closed as a demonstrated blocker, not an assertion.** `gate8_shadow_plant_seam.m` is a read-only wrapper that calls production and exposes all 7 priors (CG xyz, CB xyz +/-0.02 m, buoyancy +/-3 percent). Both halves of the reduction contract pass: mechanically, deleting the marked seam regions leaves exactly the production call; numerically, the zero-offset path is `isequaln`-identical to production over the whole 243-point probe grid. Scoring is then refused, because a 243-point black-box probe shows the hydrostatic response spans an exactly 3-dimensional subspace (singular values 48.5, 1.51, 0.0394, then machine epsilon, reproduced at 3 surge speeds). 18 observed numbers cannot determine the 36 inverse-mass entries plus 4 nominal restoring parameters needed to inject a perturbation at a **known** magnitude, so **0 of 7 plant priors are injectable** and the seam declares `scoreable = false` rather than fabricate a magnitude. Identifying them needs `underwater777_vehicle_dynamics.m` as a 4th source, which is outside the declared budget.
- **HG12 and HG13 are budget blockers.** The Gate 7 FDIR simulator kernel is not contained in either `.mat`, so the 16-case schedule cannot be re-driven under the 32 draws from 3 sources; the report records which prior would couple to which monitor once the kernel is in budget. HG13 cannot be closed either: the X/XZ/R10 waypoints, initial state and speed schedule are **caller-supplied arguments** to the production entry point and are not resident in `continuous_path_tracking_propulsion.m`, whose own default horizon is T_final 15 s against the 30 s the campaign executed.
- **New defect D3 recorded.** Attempt 2 never persisted the cell geometry it actually ran, so HG1, HG2 and HG18 nominal parity and replay can only be **ATTESTED** from the prior record, not independently reproduced here. This is reported as a failure rather than counted as a pass.
- **Genuine evidence preserved.** 2 of 8 nominal cells still drive the production rudder onto the 25 deg magnitude rail (worst nominal dwell 28.2 percent of run, worst Monte Carlo dwell 50.6 percent, against the unchanged 25 percent gate line). HG5 therefore fails on real physics of the frozen controller under 0.1 per-metre curvature. No threshold was narrowed, no metric redefined, no gain touched.
- **Prior exercise.** 28 of 35 factors physically exercised; the 7 unexercised are exactly the CG/CB/buoyancy set above, so `all_priors_exercised = false` and PASS is not available on the task's own criterion.
- **Reporting-stage defects, disclosed.** The single MATLAB invocation errored while composing the overview figure and truncated the markdown; the 6 analysis panels had already been written and pass programmatic visual QA (7/7 checks, VISUAL_QA_PASS). The overview `GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE.png` (1500x980 px) and the tail of the markdown were completed afterwards from the stored `.mat` with a pure-Python renderer, using no second MATLAB call and no new computation. Section 12.1 of the report additionally corrects two over-strong justification strings baked into the `.mat` before the probe ran: the plant is measurably **not** neutrally buoyant and the hydrostatic force rows are **not** negligible. The rank argument is unaffected and every verdict stands.
- **Evidence:** `suite_results/GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE.{md,mat,png}`, 6 panels, `..._run.log`. All priors remain **ASSUMED**; truth/measured/estimated separation held; no surface, accommodation or direct-actuator path (audit counters 0/0/0).
- **Next exact task:** `GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_001` - bounded rail-aware yaw-feasibility envelope for the R10 family. Sweep commanded turn rate against surge on one fixed grid, solve the trim rudder each point requires from the production plant alone, and mark a point infeasible where the required deflection reaches the declared 25 deg envelope, yielding a declared `kappa_max(u)` a future guidance-side admission check could read. One horizon, one grid, no controller edit, no threshold change, no new priors. It explicitly does **not** retry the rejected guidance transition shapers or the rejected current feed-forward candidates, and proposes no compensator.


<!-- APPEND_MARKER:GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001 -->

## Append: GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001 (research log)

**Date:** 2026-08-09 08:40:33 | **Class:** bounded read-only closed-loop rail-origin diagnostic, one cell, one nominal horizon | **MATLAB runs:** 1 | **Production/CODEX:** untouched | **HW:** NOT_CERTIFIED | **Gate 9:** locked

**Verdict: PASS.**

- **Frames and units.** Positions NED in m with z positive down (depth = +z); BODY rates p,q,r and BODY velocities u,v,w; angles rad internally and deg only where a name says so; rudder deflection in deg against the declared 25.0000 deg envelope with a 40 deg/s rate limit; path curvature in 1/m and arc length in m; dwell is a dimensionless fraction of the 30 s horizon.
- **Provenance.** Exactly 3 sources read: `controller_law.m`, `guidance_law.m`, `run_gate8_actuator_order_scan_repair.m`. The frozen envelope, campaign constants and stored nominal fingerprints were dereferenced at run time from `suite_results/GATE8_ACTUATOR_ORDER_SCAN_REPAIR.mat`, the artifact path source #3 declares for itself; nothing in it was re-derived. Cell geometry remains an ASSUMED_RECONSTRUCTION carried byte-identically from that record. The 4.058 deg plant trim requirement is recorded evidence quoted for comparison only, never used as a threshold.
- **Scope.** Exactly one cell `R10_U1.5` and one 30 s nominal horizon at dt 0.0250 s (1200 ticks). No Monte Carlo draw, no sensor, actuator or power hook. Read-only: no gain, law, path, threshold, shaper or feedforward was added or changed, and nothing is promoted.
- **Reproduction before attribution.** Unmodified production, the hooks-off replica and the instrumented replica are bit-identical to each other (`n=153600.s1=19094896.s2=2901292177`), the instrumented run matches the stored nominal fingerprint (1) and the stored hooks-off fingerprint (1), and the replay reproduces both the external outputs (1) and the full 1200x43 diagnostic log (1). Attribution admitted: 1.
- **Rail measurement.** Raw rudder demand peaks at 466.6729 deg before any limiter; the plant input peaks at 25.0000 deg and sits at the declared envelope for 0.2817 of the horizon (8.450 s, 12 intervals, longest 2.300 s, first at t = 1.825 s). Magnitude-limiter dwell 0.8908, rate-limiter dwell 0.6917, peak realized slew 40.0000 deg/s. Against the recorded 4.058 deg plant trim requirement the peak demand is 115.00x and the peak plant input is 6.16x, reported as evidence only.
- **Attribution completeness.** The reconstructed sum of the existing contributions matches the logged raw command to 1.137e-13 deg over 1200 samples (tolerance 1.0e-09 deg); the recomputed magnitude and rate limits match the published post-limit values to 0.000e+00 and 0.000e+00 deg; the plant input equals the controller return value in 1200/1200 samples.
- **Origin.** Earliest stage that demands or creates the 25.0000 deg envelope: `S2_CTRL_TERM_P` (class CONTROLLER) at t = 1.200 s. Category determinations: reference transient EXCLUDED_AS_SOLE_CAUSE; controller term EVIDENCED; integrator windup EXCLUDED_STRUCTURALLY (no integral state on the rudder channel and the reconstruction closes without one); magnitude limit ENGAGED_AS_CONSEQUENCE; actuator dynamics NOT_PRESENT_IN_THIS_CELL.
- **Blocker.** BLOCKER. No single rail origin is evidenced, therefore no corrective candidate is stated. Reasons: 3 existing contributions reach the 25 deg envelope on their own, so the demand is not traceable to one term. A corrective candidate proposed on a multi-origin or unreproduced rail would be a guess presented as a finding.
- **Evidence:** `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION.{md,mat,png}`, 3 figures, plus `suite_results/GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_run.log`. Visual QA verdict VISUAL_QA_PASS. Artifact footprint 0.52 MiB.
- Nothing is promoted. All reconstructions remain **ASSUMED**. Simulation is not hardware certification (**NOT_CERTIFIED**). Gate 9 remains **locked**; Gate 9B remains post-Gate 9.


<!-- APPEND_MARKER:GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_RESUME_001 -->

## Append: GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_RESUME_001 (research log)

**Date:** 2026-08-09 10:19:21 | **Class:** Gate 8 isolated shadow-only scalar sweep, promotion forbidden | **MATLAB runs:** 1 | **Production/CODEX:** untouched | **HW:** NOT_CERTIFIED

**Verdict: PARTIAL. Outcome: SCALAR_METHOD_CLOSED.** Failed gates: PG7.

- **Resume, not retry.** RESUME of an unexecuted predeclared plan. The prior attempt terminated in the bridge with resource_exhausted before any MATLAB process was started and before any artifact was written, so there is no prior result to retry, contradict or reconcile. The plan below is the stored one, unaltered.
- **Frames and units.** Positions NED in m with z positive down; BODY rates p,q,r in rad/s; angles rad internally, deg only where named; rudder deg against a 25 deg magnitude and 40 deg/s rate envelope; dwell is a dimensionless fraction of the 30 s horizon; rudder energy in deg*s and deg^2*s; thrust in the native production unit.
- **Provenance.** Exactly 3 sources read: `controller_law.m`, `run_gate8_actuator_order_scan_repair.m`, `suite_results/GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT.mat`. No repo scan. The four anchors, the ten gate texts and every threshold were read back out of the stored plan rather than restated.
- **Experiment.** One frozen cell `R10_U1.5`, one nominal 30 s horizon at dt 0.025 s, hooks off. Common scale s on `(Kp_psi, Kd_psi) = (32 s, 13 s)`, `Td = 0.406250 s` held, feedforward tied to Kd_psi. Anchors s = [1 0.260416667 0.0535707175 0.0174532925]. Full state reset and reverse-order bitwise replay on every anchor (replay all matched: yes).
- **PG1 frozen control.** s = 1 hash `n=153600.s1=19094896.s2=2901292177` against frozen `n=153600.s1=19094896.s2=2901292177`: bit-for-bit equal. Independent metric parity 11/11 within 1e-06 relative. Sweep void: no.
- **Every anchor reported.** s=1.000000: raw absmax 466.673 deg, mag/rail/rate dwell 0.8908/0.2817/0.6917, median authority 15.000 deg, cte max/med 0.21262/0.10051 m, transmitted 0.1092, clears PG2-PG8 no. s=0.260417: raw absmax 76.911 deg, mag/rail/rate dwell 0.3933/0.0567/0.7733, median authority 8.823 deg, cte max/med 0.15010/0.05965 m, transmitted 0.6058, clears PG2-PG8 no. s=0.053571: raw absmax 22.770 deg, mag/rail/rate dwell 0.0000/0.0000/0.1600, median authority 5.718 deg, cte max/med 0.33374/0.06144 m, transmitted 0.9992, clears PG2-PG8 no. s=0.017453: raw absmax 15.275 deg, mag/rail/rate dwell 0.0000/0.0000/0.0367, median authority 4.455 deg, cte max/med 0.89243/0.21279 m, transmitted 0.9992, clears PG2-PG8 no. No interpolation between anchors and no anchor dropped.
- **Finding.** no stored anchor cleared PG1-PG9. The coordinated scalar rescaling of (Kp_psi, Kd_psi) at fixed Td is therefore CLOSED as a method for this failure: the rail is not removable by a common gain scale without losing something the gates protect.
- **No candidate named.** The coordinated scalar rescaling method is closed for this failure on this evidence.
- **Preserved.** No shaper, no current feedforward, no path change, no threshold change. Production, plant, metrics and CODEX_VERTICAL_PLAN fingerprints unchanged (7/7 identical to the audit record). One MATLAB invocation, no retry, footprint 0.481 MiB.
- **Evidence:** `suite_results/GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP.{md,mat,png}`, 2 figures, plus `suite_results/GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_run.log`. Visual QA verdict VISUAL_QA_PASS.
- All priors remain **ASSUMED**. Simulation is not hardware certification (**NOT_CERTIFIED**). Gate 9 remains **LOCKED**.


<!-- APPEND_MARKER:GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_001 -->

## Append: GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_001 (research log)

**Date:** 2026-08-09 11:32:09 | **Class:** Gate 8 R10 isolated read-only guidance signal logging | **MATLAB runs:** 1 | **Horizons:** 1 x 30 s nominal | **Production/CODEX:** untouched | **HW:** NOT_CERTIFIED | **Gate 9:** locked

**Verdict: CLOSED.**

- **Provenance.** Exactly 3 sources read, no repo scan: `guidance_law.m` (`n=14601.s1=1095745.s2=3464382495`), `controller_law.m` (`n=9402.s1=732890.s2=3334742186`), `run_gate8_actuator_order_scan_repair.m` (`n=121098.s1=9464134.s2=3103638627`). Frozen R10_U1.5 cell geometry, hooks-off tracking loop, fingerprint formula and artifact conventions carried verbatim from source 3; the cell label remains an ASSUMED_RECONSTRUCTION.
- **Frames and units.** Positions NED in m with z positive down; BODY u,v,w in m/s and p,q,r in rad/s; Euler angles rad, deg only where a name says so; course over ground chi = atan2(ydot,xdot) rad; signed cross-track y_e in m positive to starboard of the path; curvature rad/m; arc length and lookahead m; timestamps s. Every logged column carries its unit in its name.
- **Frozen parity first.** Production reproduce fingerprint `n=153600.s1=19094896.s2=2901292177` against the required `n=153600.s1=19094896.s2=2901292177` (match 1); the instrumented reproduce carries the same fingerprint (match 1) with array parity 1, which is the proof that the observer changes no cadence, no state and no call order. Production and CODEX_VERTICAL_PLAN fingerprints unchanged: 1.
- **Signal log.** 1200 controller ticks, 400 guidance updates, 52 named columns: yaw_ref (production and held), achieved psi, s_prog, kappa_f and kappa_raw, signed y_e, chi_f, chi_los, course tangent chi_now, lookahead course chi_path, beta, U_h, L, filter states, slew-limited output with desired and applied increments, and the held controller input with e_psi, e_r, dr_yaw and realized delta_r.
- **Closure.** Observer vs production yaw_ref 0.000e+00 rad; component sum vs logged yaw_raw 0.000e+00 rad; full recursion rebuilt from logged components vs production yaw_ref 0.000e+00 rad; e_psi = wrap(yaw_ref - psi) vs the controller's own e_psi 0.000e+00 rad. Tolerances declared before the run (1e-12 / 1e-9 rad).
- **Geometry identity.** Exact course chi = psi + beta closes to 8.882e-16 rad. The four-term course-offset identity wrap(chi_og - (chi_f + 0.75*chi_los)) = lag - e_psi - (k_beta-1)*beta + (beta_exact - beta) closes to 2.005e-15 rad, with steady-window means lag -1.2524 deg, -e_psi -3.8352 deg, structural over-crab 0.2764 deg, beta model residual 0.0417 deg, total -4.7693 deg.
- **Curvature lead.** measured lead 4.137 deg vs predicted 4.207 deg (effective dt_g 0.0750 s) and 4.207 deg (nominal dt_g 0.0750 s); mean residual -0.070 deg, rms 6.646 deg, peak 13.626 deg against the +-9.000 deg waypoint-quantisation envelope of the frozen 26-point polyline (max tangent step 18.000 deg); classification: CONSISTENT-IN-MEAN: the measured lead matches kappa*(L - U*dt_g*31/7) to within the waypoint-quantisation envelope of the frozen polyline. The instantaneous residual is a sawtooth at the waypoint rate, not a modelling error in the lead law.
- **Crab residual, classified not changed.** k_beta = 1.35 left unchanged; mean abs(beta) 0.790 deg, peak 2.417 deg; structural over-crab term -(k_beta-1)*beta mean 0.2764 deg, peak 0.8458 deg; sideslip model residual mean 0.0417 deg (clamp 0.0000 + roll/heave 0.0419 + pitch projection -0.0001, additive split closes to 4.34e-19 rad); total steady course offset mean -4.7693 deg, rms 7.6353 deg; dominant term: heading_tracking_error (3.8352 deg) Classification: structural and law-inherent, reproducible tick-for-tick from the log; it is not a current, a bias or an estimator error.
- **Bounded continuity.** max per-tick |d yaw_out| 4.599539e-02 rad against the implemented deg2rad(40)*dt_g bound 5.235988e-02 rad, limiter engaged on 0/400 ticks; 1 wrap events with the unwrap identity closing to 8.882e-16 rad; all logged signals finite.
- **Shadow reference candidate (exactly one, stated only because all four preconditions passed).** SHADOW_COURSE_REFERENCE_OFFSET_CANDIDATE_C1 C1: a shadow-only course reference that removes the identified structural over-crab term, i.e. evaluates chi_ref = chi_f + 0.75*chi_los - beta (k_beta = 1) as a LOGGED SHADOW SIGNAL ONLY, alongside the untouched production reference. Status: CANDIDATE_ONLY - NOT IMPLEMENTED, NOT EVALUATED, NOT PROMOTED.
- **Not done here.** No gain, law, path or threshold edit; no external shaper; no current feedforward; no promotion; k_beta stays 1.35. One cell, one nominal horizon, no disturbance, no sensor or actuator chain. No estimator on this path, so x and y are truth and that gap is declared, not faked.
- **Evidence:** `suite_results/GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE.{md,mat,png}`, 2 figures, plus `suite_results/GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_run.log`. Visual QA verdict VISUAL_QA_PASS. Artifact footprint 0.31 MiB.
- **Next exact task:** `gate8_r10_shadow_course_reference_offset_probe` - run the stated candidate as a logged shadow signal on the same frozen cell under the same external fingerprint, parity-first, without touching production.
- All labels remain **ASSUMED** where they were assumed. Simulation is not hardware certification (**NOT_CERTIFIED**). Gate 9 remains **locked**; Gate 9B remains post-Gate 9.


---

<!-- APPEND_MARKER:GATE8_RESIDUAL_RISK_WAIVER_AND_GATE9_ENTRY_001 -->

## Append: GATE8_RESIDUAL_RISK_WAIVER_AND_GATE9_ENTRY_001 (research log)

**Date:** 2026-08-09 12:21:58 | **Class:** doc-only Gate 8 disposition | **MATLAB runs:** 0 | **Source/runtime edits:** NONE | **Repo scan:** NONE | **Production/CODEX_VERTICAL_PLAN:** untouched | **HW:** **NOT_CERTIFIED**

**Gate 8 verdict: `WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT`. Gate 8 is NOT PASS.**

Sources read (exactly 3): `suite_results/AUV_REALIZATION_READINESS_PLAN.md`, `suite_results/AUTONOMOUS_EXECUTION_POLICY.md`, `suite_results/GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE.md`.

### Why this research line stops here

Three Monte Carlo closure attempts failed, and the diagnostic sub-line that was supposed to close the surviving failure closed itself instead:

| # | Record | Verdict | Surviving failure |
|---|--------|---------|-------------------|
| 1 | `GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001` | **FAIL** | HG5, HG8, HG11, HG12, HG13 |
| 2 | `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_001` | **FAIL** | HG5, HG11, HG12, HG13 (harness defects D1/D2 genuinely repaired) |
| 3 | R10 rail-closure line: rail-origin localisation (**BLOCKER**) → coordinated scalar sweep (**PARTIAL / SCALAR_METHOD_CLOSED**) → guidance signal-log closure (**CLOSED**) → C1 shadow probe (**REJECT_C1_METHOD_CLOSED**) | **not closed** | HG5, the R10 production rudder rail |

### Methods now CLOSED — never retry

- **Coordinated scalar rescaling** of `(Kp_psi, Kd_psi) = (32 s, 13 s)` at fixed `Td = 0.406250 s`. Anchors `s ∈ {1, 0.260416667, 0.0535707175, 0.0174532925}` were all reported, none dropped, no interpolation claimed. The rail vanishes only by buying it with tracking: at `s = 1` rail dwell 0.2817 and cte max 0.21262 m; at `s = 0.017453` rail dwell 0.0000 and cte max 0.89243 m. No anchor cleared PG1–PG9.
- **C1 shadow course reference**, `chi_raw_C1 = wrap(chi_f + 0.75*chi_los - 1.00*beta)`, i.e. `k_beta` 1.35 → 1.00, evaluated as a logged shadow signal only. PRIMARY-1 passed by construction (over-crab 0.335019 → 0.000000 deg, +100.0000%); the conjunctive PRIMARY-2 failed at +0.3806% sustained / +0.3138% full record against a declared +5% floor. Secondary metrics all stayed inside the 2% band (worst -1.4544%) and there was no slew or wrap violation, so the rejection is on **effect size alone**.
- Standing bans unchanged and reinforced: **gamma INDI / gamma PI / gamma LADRC · depth PI / depth NDO · crab-current FF · simple polyline shaper**.

### Why no closed method will be retried

The C1 rejection carries its own proof of futility: the over-crab term is worth 0.335019 deg of reference offset while the heading error it would have to move is 5.625664 deg, so even perfect removal can shift the P demand only by tenths of a per cent. The course-offset attribution identity closes to 1.14e-15 rad and shows the offset is **transferred** into the heading-error term under open-loop replay, not eliminated. Re-running cannot change that ratio. The scalar family is likewise exhausted at its own anchors, where the rail trades monotonically against cross-track error. Under the promotion policy a closure on a stated ratio is a closure, not a near-miss.

### Residual risk carried forward (OPEN)

R1 R10 production rudder rail unresolved (raw demand 466.6729 deg; plant input pinned at 25.0000 deg for 0.2817 of the 30 s horizon; magnitude dwell 0.8908, rate dwell 0.6917; multi-origin, earliest `S2_CTRL_TERM_P` at t = 1.200 s; windup EXCLUDED_STRUCTURALLY) · R2 CG/CB ±2 cm and buoyancy ±3% priors **drawn but never injected**, no plant-parameter seam (HG11) · R3 Gate 7 16-case FDIR matrix **not re-drawn** inside MC (HG12) · R4 X/XZ/R10 cell geometry `ASSUMED_RECONSTRUCTION` (HG13) · R5 estimator streams `NOT_IMPLEMENTED` on this path, truth `x`/`y` used · R6 power `PARTIAL`, thrust-authority derate only, brownout branch never entered · R7 hardware `NOT_CERTIFIED`, servo τ / deadband / thruster map / sensor σ all `TO_BE_IDENTIFIED` · R8 Gate 4 waiver still OPEN / shadow-only, Gate 3 `CLOSED_AFTER_3_ATTEMPTS`.

### Labels

`IMPLEMENTED` isolated shadow instruments only · `DERIVED` this disposition and its reasoning · `ASSUMED` every prior, threshold and cell reconstruction · `TO_BE_IDENTIFIED` hydro coefficients, speed family, actuator and sensor numerics, mission/nav/actuator-feedback rates · `NOT_IMPLEMENTED` estimator streams and the plant-parameter injection seam · `NOT_CERTIFIED` all hardware claims.

**Next exact task (exactly one):** `GATE9_SIMULATION_RC_ASSESSMENT_001` — bounded simulation RC assessment and evidence-range assembly only. Gate 9 PASS remains impossible unless every hard safety gate passes. No promotion, no label upgrade, no banned-method retry, no `CODEX_VERTICAL_PLAN.md` edit.


<!-- APPEND_MARKER:GATE9_SIMULATION_RC_ASSESSMENT_001 -->

## Append: GATE9_SIMULATION_RC_ASSESSMENT_001 (Gate 9 disposition)

**Date:** 2026-08-09 12:53:47 | **Class:** bounded read-only Gate 9 RC assessment and evidence-range assembly | **MATLAB runs:** 1 | **New campaign:** NONE | **Method retry:** NONE | **Repo scan:** NONE | **Production/CODEX:** byte-identical | **HW:** **NOT_CERTIFIED**

**Verdict: `FAIL` (`RC_NOT_GRANTED`). Gate 9 is NOT PASS and must never be transcribed as PASS.**

- **Zero tolerance applied.** zero tolerance applied: 2 declared gates are FAIL, 2 are WAIVED and not PASS, and 2 residual-risk items are OPEN at BLOCKER severity (R1 R10 rudder rail; R7 hardware NOT_CERTIFIED). HG11, HG12 and HG13 remain open, so Gate 9 PASS is unavailable by construction.
- **Sources read: exactly 3, no repo scan** - `suite_results/AUV_REALIZATION_READINESS_PLAN.md`, `suite_results/PROPULSION_POWER_COMPUTE_PARITY_FIX.mat`, `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.mat`. The two MAT records were loaded and introspected in this run; the plan supplied transcribed constants. Every other file named below is dereferenced from the plan record, not re-read and not re-run.
- **Verification matrix Gates 0-8 as declared:** Gate 0 PASS, Gate 1 PASS, Gate 2 FAIL (CLOSED_AFTER_3_ATTEMPTS), Gate 3 FAIL (CLOSED_AFTER_3_ATTEMPTS), Gate 4 WAIVED (4A PASS, 4B closed FAIL, shadow-only), Gate 5 PASS (interface and integrity only, accuracy CHARACTERIZATION), Gate 6 PASS, Gate 6B PASS, Gate 7 PASS (simulation scope), Gate 8 WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT and never PASS.
- **Residual risk R1-R8 published as a first-class output, all OPEN.** R1 R10 rudder rail (BLOCKER, raw demand 466.6729 deg, rail dwell 0.2817, magnitude dwell 0.8908, rate dwell 0.6917, peak slew 40.0000 deg/s) - R2 CG/CB and buoyancy priors drawn but never injected (HG11) - R3 Gate 7 FDIR matrix not re-drawn under MC (HG12) - R4 cell geometry ASSUMED_RECONSTRUCTION (HG13) - R5 estimator streams NOT_IMPLEMENTED on the Gate 8 path - R6 power coverage PARTIAL, brownout branch never entered - R7 hardware NOT_CERTIFIED, actuator and sensor numerics TO_BE_IDENTIFIED - R8 upstream gate debt (Gate 4 waiver open, Gates 2 and 3 closed after three attempts).
- **Pareto vector:** tracking ACCEPTABLE (pooled cte_max P50 0.342 m, P95 0.565 m) - actuator margin **CRITICAL, effectively zero** - energy ACCEPTABLE with coverage factors (15.59 Wh/km, 6.88 A peak) - estimation **OPEN, no accuracy claim** - timing PARTIAL (budgets declared, never measured on a target) - safety PASS in simulation scope only (17/17 FDIR, 0 false alarms, 0 surface, 0 accommodation).
- **ICD boundary Mission -> Guidance -> Navigation -> Controller -> Actuator** tabulated with version, timestamp, sequence, validity/quality/integrity, heartbeat, stale rule, frame, unit and twin-log key per boundary. Local magnitude, rate and safety authority overrides mission; stale mission means fail-silent, never auto-surface and never auto-accommodation.
- **Procurement-ready requirement RANGES: 31 rows**, covering servo tau / rate / deadband / resolution / envelope, thruster lag and thrust, bus current, energy per km, source impedance and hold-up, DVL and IMU error against an ASSUMED dead-reckoning horizon grid, sensor cadence, transport delay, dropout, depth sensing, and compute period / deadline / WCET / jitter / overrun / utilisation. Every row is `DERIVED` from an `ASSUMED` or `TO_BE_IDENTIFIED` parent and carries unit, frame, source and limiting risk. **No vendor, brand, part number or purchase claim appears anywhere.** Two rows publish no number on purpose: `RR-06` (thruster variant time constants are not quoted in the permitted sources) and `RR-25` (mission, navigation and actuator-feedback cadences are unconstrained by any permitted source).
- **Selected ranges, for the record.** Servo tau 0.0125..0.100 s - servo rate 80..160 deg/s with a 40 deg/s hard floor - deadband plus backlash 0..0.10 deg - continuous thrust >= 16.865 N, peak >= 21.081 N - bus current continuous >= 8.256 A, peak >= 10.320 A - energy 18.708..23.385 Wh/km - source impedance <= 0.01453 ohm per volt of nominal bus - hold-up >= 100 ms - controller WCET <= 12.50 ms, jitter <= 2.50 ms - guidance WCET <= 37.50 ms, jitter <= 7.50 ms - transport delay <= 30 ms hard.
- **Reproducibility is evidenced, physical validity is not.** Exact nominal parity in 8/8 cells, bitwise reverse-order replay everywhere it was tested, the R10 fingerprint `n=153600.s1=19094896.s2=2901292177` reproduced across three code paths, and cross-process reproduction of the Gate 5B estimator. That proves the twin computes the same thing twice; it says nothing about whether what it computes is physically right, which is precisely what R1-R8 leave open.
- **EXTERNAL stops recorded explicitly:** hull and mechanical CAD NOT STARTED; vendor purchase FORBIDDEN; bench and HIL REQUIRED to convert the actuator, propulsion and compute rows into identified facts; wet trials REQUIRED to close R1 honestly; real-data system identification REQUIRED before any `ASSUMED` or `TO_BE_IDENTIFIED` label can become `IDENTIFIED`.
- **Preserved.** Production `continuous_path_tracking.m`, `controller_law.m`, `guidance_law.m` and `CODEX_VERTICAL_PLAN.md` are byte- and SHA-256-identical before and after this run (YES). No accepted evidence artifact was deleted, overwritten or re-labelled. No gain, law, path, threshold, shaper or feedforward was touched. No closed method was retried.
- **Evidence:** `suite_results/GATE9_SIMULATION_RC_ASSESSMENT.{md,mat,png}` plus `suite_results/GATE9_SIMULATION_RC_ASSESSMENT_qa.png` and `suite_results/GATE9_SIMULATION_RC_ASSESSMENT_run.log`. Visual QA verdict VISUAL_QA_PASS.
- **Next exact task (exactly one):** `GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001` - read-only fast whole-code embedded-readiness gap audit over A1-A13, every finding classified BLOCKER / TARGET_DEPENDENT / EXTERNAL_HIL / COSMETIC, evidence read and never re-executed. Its PASS bar is unchanged, so an audit over a FAIL RC will normally report BLOCKERs and not PASS.
- **STM32 adaptation remains FORBIDDEN** pending both the exact part number and board and an explicit disposition of every unresolved blocker. No processor is selected, guessed, recommended or implied. Simulation is not hardware certification (**NOT_CERTIFIED**).


---

## GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001 — embedded-transfer gap audit

**Verdict: FAIL. RC_NOT_GRANTED sustained. State: `AWAIT_STM32_EXACT_PART_NUMBER`.**

Read-only, fast whole-code embedded-transfer audit. No MATLAB, no execution, no repo scan, no runtime edit, no source edit, no candidate retry, no promotion, no label upgrade.

**Sources read: exactly 3, no repo scan** — `continuous_path_tracking.m` (10845 B, sha256 `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b`), `guidance_law.m` (14601 B, `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3`), `controller_law.m` (9402 B, `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890`). Every line citation in the report refers to these three files. No other file was source-reviewed; `init_parameters`, `underwater777_vehicle_dynamics`, `wrapToPi` and `interp1` are named only as call-graph entries and their contents are TO_BE_IDENTIFIED.

**Carried Gate 9 disposition, not re-derived:** RC_NOT_GRANTED; residual risks R1–R8 all OPEN; exact target ABSENT.

**Gate 9B PASS criteria and result:** zero software/safety BLOCKER — **NOT MET (14 distinct blocker classes)**; complete embedded handoff manifest — **NOT MET (42 rows; 15 TO_BE_IDENTIFIED, 6 ASSUMED/partial, 4 required units absent)**.

**Deployable core vs simulation.** Only `inertial_velocity_ned` (`continuous_path_tracking.m:228–244`) is transferable as-is: pure, fixed-size, allocation-free. `controller_law.m:59–179` is straight-line and bounded-cost and is the most transfer-ready control unit. `guidance_law.m:52–279` plus helpers `:283–394` are the control law proper but are O(n) per tick in an unbounded `path`. `continuous_path_tracking.m:1–226` is simulation harness (fixed-horizon loop `:71`, host variable-step integrator `:101`, ~30 whole-mission log buffers `:20–63`, stdout in-loop `:104–106,183–184`, 28 export globals `:189–225`). `underwater777_vehicle_dynamics` is plant, not read. **The repository does not currently contain a separable deployable control core; the gap is architectural and is not closed by choosing a target.**

**Findings: 71 total** — 51 BLOCKER (14 distinct classes), 8 TARGET_DEPENDENT, 2 EXTERNAL_HIL, 10 COSMETIC (6 of them positive). Labels: 34 IMPLEMENTED, 34 DERIVED, 0 ASSUMED in findings, 11 TO_BE_IDENTIFIED.

**The 14 software/safety BLOCKER classes (all host-side, all target-independent):**
- **B01** no deterministic init/step/reset API; `persistent` survives across missions (`guidance_law.m:21,68–80`; `controller_law.m:23–25,151–154`).
- **B02** navigation layer absent — every control input is plant truth (`continuous_path_tracking.m:72–94`), including sideslip `beta` (`guidance_law.m:168–173`) and flight-path `gamma_actual` (`:210`); code-level form of carried R5.
- **B03** mission and actuator layers are not interfaces (`guidance_law.m:1`; `controller_law.m:1`; `continuous_path_tracking.m:96–98`).
- **B04** global parameter/diagnostic coupling; functions mutate their own configuration (`guidance_law.m:13–19,27–34`; `controller_law.m:12–30,38–57`; harness rewrites both rate globals at `continuous_path_tracking.m:9–17`); plant derivatives `Muw`/`Muuds` and fitted constants hard-coded in the controller (`controller_law.m:52–54,111–112`); not reentrant.
- **B05** dynamic/variable-size memory: run-length log allocation (`continuous_path_tracking.m:19–63`), reallocation on the fault path (`:107–114`), unbounded `path` with per-tick `zeros(n,1)` (`guidance_law.m:54,62,285`), `nargout`-dependent 27-field struct (`controller_law.m:181–213`).
- **B06** host-only step driver: `ode45` with anonymous handle (`continuous_path_tracking.m:101`), `try/catch` + `ME.message` (`:100–106`), in-loop `fprintf` (`:104–106,183–184`).
- **B07** non-base-language calls inside the core: `wrapToPi` (`guidance_law.m:164,173,180,212`; `controller_law.m:61`), `interp1(...,'extrap')` (`controller_law.m:222`), `find(...,1,'last'/'first')` (`guidance_law.m:324–327,361–362`).
- **B08** NaN used as control-flow sentinel (`guidance_law.m:71–73,79,161,177,239`); no floating-point format or mode policy anywhere.
- **B09** unbounded numeric ranges: never-rewrapped heading accumulator (`guidance_law.m:180,254,263`), gain-dependent integrator limits up to ~1.4e5 rad (`controller_law.m:83,102`), curvature reciprocal to 1e4 m (`guidance_law.m:135,150`).
- **B10** **highest severity** — no parameter validity check and no input validity check. Thirteen unguarded globals (`controller_law.m:12–17`) used at `:63,66,70,82–83,86,102,106,133,136,139,178–179`; if `init_parameters` has not run, `max(min(x,[]),[])` yields empty and an **empty actuator command propagates silently** instead of a fault or a safe state. No NaN/Inf/range check on any navigation input, and no reset to recover from a poisoned integrator. Unbounded trim extrapolation at `:222` can consume full elevator authority off-table.
- **B11** sample time owned by globals (`controller_law.m:56–58`; `guidance_law.m:32–36`); rate ratio rounded without check (`continuous_path_tracking.m:69,84`) which desynchronises `z_e_i` (`guidance_law.m:194`), the pitch rate limit (`:258`) and `pitch_ref_dot` (`:265`); unguarded ZOH with no hold-age (`continuous_path_tracking.m:68`); nine hard-coded filter alphas that bake in the tuning sample rate (`guidance_law.m:134,147,164,202,213,222,226,243,252`). The correct pattern already exists at `controller_law.m:57,76`.
- **B12** anti-windup computed before the rate limiter and therefore blind to rate saturation (`controller_law.m:133,140–142,149–152`) — with a 40 deg/s limit, rate saturation is the likely dominant limiter; guidance depth integrator has no anti-windup under three cascaded downstream saturations (`guidance_law.m:194–195,204,229,256–261`); no bumpless transfer; saturation flag exists only in the optional debug struct (`controller_law.m:202`), invisible to the production three-output call (`continuous_path_tracking.m:91`); rudder saturation never reported back to guidance (carried R1 visible as a missing feedback path).
- **B13** no FDIR interface, no watchdog kick, no deadline/overrun/jitter detection, no safe state, no timing instrumentation of any kind; the only fault-shaped construct prints, truncates and breaks (`continuous_path_tracking.m:100–116`); guidance absorbs implausible progress silently (`guidance_law.m:95–105`).
- **B14** no transport schema at any of the four existing boundaries — version, timestamp, sequence, validity, heartbeat and stale rule are absent everywhere; log keys are bare global names (`continuous_path_tracking.m:189–225`; `guidance_law.m:231–238`; `controller_law.m:156–176`); sign and frame conventions survive only in comments (`controller_law.m:3–4,73–74`, `elevator_sign` `:17,46,107,136`; `guidance_law.m:192–193,201`), and losing them is a pitch-divergence hazard. Twin equivalence is untestable: all four preconditions (identical initial state, identical timed inputs, identical parameters, stable log keys) fail.

**TARGET_DEPENDENT (8):** heap budget, in-loop `exp` (`controller_law.m:76`), curvature dynamic range, host `eps` as divisor guard (`:66`), intra-frame scheduling/jitter/phase, transport medium and encoding, stack budget (favourable: recursion-free, depth ≤ 3), absolute WCET/footprint/achievable rate. **EXTERNAL_HIL (2):** actuator dynamics absent from the read set (`continuous_path_tracking.m:96–98`); actuator and sensor numerics require a bench. **Positive findings:** control path is RNG-free and clock-free and therefore bit-reproducible on a fixed FP configuration; units are internally SI-consistent with no dimensional defect found; magnitude saturation, rate limiting and back-calculation anti-windup are all present; `controller_law` is recursion-free and straight-line.

**Recommended host-side fix order (recommendation only, not an authorisation to edit):** B10 → B01 → B04 → B11 → B14 → B12 → B13 → B05/B07/B08/B09 → B02/B03 → B06.

**Constraint restated.** Target work remains **FORBIDDEN** until the user supplies the **exact target part number and board** *and* each of B01–B14 is individually dispositioned (fixed, formally waived with recorded residual risk, or deferred with an owner). A part number alone does not unblock, because all 14 blockers are host-side. **No MCU family, vendor, brand, board or part number is named in this record.** Simulation is not hardware certification: **NOT_CERTIFIED**.

**Integrity.** Production sources verified **UNTOUCHED** (hashes above, identical before and after). `suite_results/CODEX_VERTICAL_PLAN.md` **UNTOUCHED — not read, not written** (43101 B, sha256 `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c`). No file deleted, renamed, moved, truncated or overwritten; all evidence preserved. Writes: created `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`; append-only to `suite_results/AUV_REALIZATION_READINESS_PLAN.md`, `suite_results/AUTONOMOUS_EXECUTION_POLICY.md`, `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md`, `suite_results/PITCH_CONTROL_RESEARCH_LOG.md`, `suite_results/STATE_SPACE_MODEL_AUDIT.md` — each appended without being read, each receiving this identical block.

Full report: `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`.

<!-- APPEND_MARKER:CG_PRE0_TOOLCHAIN_CAPABILITY_001 -->

## Append: CG_PRE0_TOOLCHAIN_CAPABILITY_001 — MATLAB→C++ pretarget capability gate

**Date:** 2026-08-10 01:59 | **Class:** read-only toolchain capability gate | **MATLAB runs:** 1 | **Install/config/source edits:** NONE | **Repo scan:** NONE | **Production/CODEX:** untouched | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** MATLAB R2025b PCWIN64 bridge OK. MATLAB Coder PRESENT+LICENSE_AVAILABLE with resolvable `codegen`/`coder` APIs. Simulink Coder / Embedded Coder classic license features test true (`Real-Time_Workshop`, `RTW_Embedded_Coder`) but products MISSING from `ver`. C/C++ MEX compiler selected=0 installed=0 → executable codegen BLOCKED. STM32-relevant add-ons=0 (MISSING/HARDWARE_BLOCKED). Tiny Coder smoke SKIPPED (exact reason: would require mex/compiler setup, forbidden). C: avail before 4565749760 B (4.25 GiB) → after MATLAB 4554731520 B; small text evidence only.

**Sources read: exactly 3** — `GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`, `AUTONOMOUS_EXECUTION_POLICY.md`, `AUV_REALIZATION_READINESS_PLAN.md`. Gate 9B FAIL / 14 BLOCKERs / `AWAIT_STM32_EXACT_PART_NUMBER` carried, not re-opened.

**Evidence:** `suite_results/CG_PRE0_TOOLCHAIN_CAPABILITY.md` · status board `suite_results/CG_CODEGEN_STATUS.md`.

**Next exact task (exactly one):** `CG0_CODEGEN_BOUNDARY_INVENTORY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG0_CODEGEN_BOUNDARY_INVENTORY_001 -->

## Append: CG0_CODEGEN_BOUNDARY_INVENTORY_001 — codegen boundary inventory

**Date:** 2026-08-10 02:12 | **Class:** read-only source inventory | **MATLAB runs:** 0 | **Source edits:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Scoped 178 root `.m` (0 `.mlx`/`.slx`/`.sldd`); first-level `shadow_r10/` empty of sources. Excluded `suite_results`/dot/git/cache. Classes: DEPLOY 2 · SHARED_SUPPORT 2 · SIMULATION_ONLY 156 · ARCHIVE_REJECTED 18 · HARDWARE_BLOCKED(files) 0. Full review: `controller_law.m`, `guidance_law.m`, `continuous_path_tracking.m`, `init_parameters.m`, `underwater777_vehicle_dynamics.m`; remainder header/call → `NEEDS_CG1_REVIEW`. Deploy graph: cpt → init_parameters / inertial_velocity_ned / guidance_law / controller_law / ode45(plant). Nav/EKF, Mission, FDIR, allocation, actuator feedback = evidence/harnesses only (not production runtime). Compiler MISSING remains PARTIAL; static CG1 allowed.

**Evidence:** `suite_results/CG0_CODEGEN_BOUNDARY.md` · `suite_results/CG0_CODEGEN_MANIFEST.csv` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001 -->

## Append: CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001 — static controller Coder compat

**Date:** 2026-08-10 02:22 | **Class:** bounded static MATLAB Coder audit (accepted controller only) | **MATLAB runs:** 0 | **Source edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** `controller_law.m` scalar core (`:59–179`) directly portable (sin/cos/exp/sign/clamps); lift-as-is blocked by globals + un-resettable persistent, variable nargin/nargout dbg, `wrapToPi`, unbounded `interp1` extrap/trim tables, empty-unguarded gains/limits, dt-from-global. Fixed-signature future API specified only (`Params`/`State`/`Input`/`Output`/`Debug` + init/reset ownership + finite/range guards); **not implemented**. Gains frozen; rejected methods closed. Compiler/tool install remains deferred.

**Sources read: exactly 3** — `controller_law.m`, `suite_results/CG0_CODEGEN_BOUNDARY.md`, `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`.

**Evidence:** `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001 -->

## Append: CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001 — static guidance Coder compat

**Date:** 2026-08-10 02:25 | **Class:** bounded static MATLAB Coder audit (accepted guidance only) | **MATLAB runs:** 0 | **Source edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** `guidance_law.m` LOS/course/β/pitch/Tur4A–5B scalar algebra portable after owned wrap; lift-as-is blocked by 19 globals + 13 un-resettable persistents, variable nargin defaults, unbounded `path` + per-tick `zeros(n,1)`, `find`/`sum` O(n) helpers, toolbox `wrapToPi`, NaN init sentinels, dt-from-global, no path validity/seq. Fixed-signature future API specified only (`Params`/`State`/`Input`/`Output`/`Debug` + bounded path capacity, segment/angle-wrap ownership, finite/range guards); **not implemented** — await golden parity. Accepted LOS tuning frozen; rejected γ-structural/LADRC/INDI/crab-current-FF/polyline closed. Compiler/tool install remains deferred.

**Sources read: exactly 3** — `guidance_law.m`, `suite_results/CG0_CODEGEN_BOUNDARY.md`, `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`.

**Evidence:** `suite_results/CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY.md` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001 -->

## Append: CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001 — nav/FDIR runtime boundary

**Date:** 2026-08-10 02:42 | **Class:** bounded static runtime-boundary audit (exactly 3 nav/FDIR sources) | **MATLAB runs:** 0 | **Source edits:** NONE | **Repo scan:** NONE | **Harness inspect:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PARTIAL.** Reusable cores: 18-state propagate/Joseph/admit order (baseline), optional USBL + health-only availability FSM (availability fork), rudder B2 residual+persistence latch (monitor). SIMULATION_ONLY: action-string dispatch, batch N-logs, cell/dynamic structs, innov growth, metrics/gates/truth scoring, `eig`/`error`/`assert`. Lift-as-is **FAIL** — files do **not** DEPLOY. Spec only: `nav_init/reset/propagate/update/output`, `availability_step`, `rudder_fdir_init/reset/step` + Params/State/Input/Output/Health; preserve truth firewall, Joseph form, deterministic order, FDIR latch; thresholds ASSUMED/NOT_CERTIFIED. Compiler/tool install deferred.

**Sources read: exactly 3** — `navigation_multirate_ekf_baseline.m`, `navigation_multirate_ekf_availability.m`, `isolated_online_rudder_residual_monitor.m`.

**Evidence:** `suite_results/CG1C_NAV_FDIR_RUNTIME_BOUNDARY.md` · `suite_results/CG_CODEGEN_STATUS.md`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001 -->

## Append: CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001 — controller golden corpus

**Date:** 2026-08-10 03:00 | **Class:** SIMULATION_ONLY MATLAB golden capture (accepted controller) | **MATLAB runs:** 1 | **Source edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Bounded deterministic corpus `CG2A_CONTROLLER_GOLDEN_V1` (schema 1): N=100 steps × 13 finite inputs × 30 Debug fields; 13 coverage cases (cold nominal; U={1,1.5,2}; yaw wrap ±π; climb/descent; rudder/elevator mag+40°/s slew; pitch I/AW; roll-rate damp; nonzero w @ accepted λ_muw_ff=0). Forced accepted `dt=0.025`. Dual replay with `clear controller_law` → `isequaln` outputs+Debug. Finite + mag/slew checks PASS. `controller_law.m` / `init_parameters.m` fingerprints UNTOUCHED. **C++ parity NOT CLAIMED.** Compiler/tool install deferred.

**Sources read: exactly 3** — `controller_law.m`, `init_parameters.m`, `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md`.

**Evidence:** `suite_results/CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE.md` · `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat` · `suite_results/CG2A_CONTROLLER_GOLDEN_V1.json` · `run_cg2a_controller_golden_parity_capture.m`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001 -->

## Append: CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001 — explicit-state controller prototype

**Date:** 2026-08-10 03:14 | **Class:** SIMULATION_ONLY MATLAB explicit-state prototype + golden parity | **MATLAB runs:** 1 | **Production edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Isolated fixed-ABI prototype `controller_codegen_init/reset/step` (Params from golden snapshot only; deterministic zero State). Replayed all 100 golden steps: exact `isequaln` on every Output+Debug field; dual reset replay A==B; mag/slew bounds OK (40°/s). Label `DEPLOY_CANDIDATE/NOT_IN_PRODUCTION`. TEMPORARY_BLOCKER retained: `wrapToPi`, fixed-table `interp1` linear/extrap. `controller_law.m` fingerprint UNTOUCHED. **C++ parity NOT CLAIMED.** Compiler/tool install deferred.

**Sources read: exactly 3** — `controller_law.m`, `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md`, `suite_results/CG2A_CONTROLLER_GOLDEN_V1.mat`.

**Evidence:** `suite_results/CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE.md` · `controller_codegen_{init,reset,step}.m` · `run_cg2a_controller_explicit_state_prototype.m`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

<!-- APPEND_MARKER:CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001 -->

## Append: CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001 — guidance golden corpus

**Date:** 2026-08-10 03:29 | **Class:** SIMULATION_ONLY MATLAB golden parity capture | **MATLAB runs:** 1 | **Production edits:** NONE | **Repo scan:** NONE | **HW:** **NOT_CERTIFIED**

**Verdict: PASS.** Bounded deterministic corpus `CG2B_GUIDANCE_GOLDEN_V1` (schema 1): N=102 steps × full 8-input `guidance_law` calls × 6 outputs × 11 `last_*` diagnostics; 16 coverage cases (cold/open straight; U_h∈{1,1.5,2}; ±CTE/±depth; multi-seg/curvature; closed seam; near-end slowdown; progress back-snap; yaw wrap ±π; sway β; Tur4A/5A/5B inputs @ accepted K_zdot=0,K_gamma=0,α̂ off). Paths stored padded MAX=32×3 + n_path/path_id; legacy calls use active rows. Forced accepted `dt_guidance=0.075`. Dual replay with identical `reset_before` + `clear guidance_law` → `isequaln` outputs+diagnostics. Finite + range/slew/progress checks PASS. `guidance_law.m` / `init_parameters.m` fingerprints UNTOUCHED. **C++ parity NOT CLAIMED.** Compiler/tool install deferred.

**Sources read: exactly 3** — `guidance_law.m`, `init_parameters.m`, `suite_results/CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY.md`.

**Evidence:** `suite_results/CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE.md` · `suite_results/CG2B_GUIDANCE_GOLDEN_V1.mat` · `suite_results/CG2B_GUIDANCE_GOLDEN_V1.json` · `run_cg2b_guidance_golden_parity_capture.m`. Production + `CODEX_VERTICAL_PLAN.md` fingerprints UNTOUCHED.

**Next exact task (exactly one):** `CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001`. Simulation is not hardware certification (**NOT_CERTIFIED**).

