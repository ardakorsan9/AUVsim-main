# AUV_REALISM_AND_VISUAL_VALIDATION — REALISM_GAP_AUDIT_001

**Date:** 2026-08-06  
**Audit class:** read-only plant / sensor / actuator / computation realism  
**Pack antecedent:** `AUV_VISUAL_EVIDENCE_PACK_001` **PASS** (6/0/0) — visual QA complete; **production frozen**  
**MATLAB run:** NO · **model/controller edits:** NO · **CODEX_VERTICAL_PLAN:** untouched  

## Sources (strict, ≤3)

| # | Path | Role |
|---|------|------|
| 1 | `suite_results/AUV_VISUAL_EVIDENCE_PACK.md` | Visual/completeness evidence; frames; actuator limit display; CUSUM panel |
| 2 | `underwater777_vehicle_dynamics.m` | Exact production plant RHS |
| 3 | `controller_law.m` | Production actuator law / cascade (path recorded in `PITCH_CONTROL_RESEARCH_LOG.md`: climb-FF, ICD, fault ICD sources) |

**Evidence labels** (never upgrade):  
`IMPLEMENTED` · `IDENTIFIED` · `DERIVED` · `TUNED` · `FIXED` · `ASSUMED`  
Simulation / CUSUM / visual-pack PASS ≠ hardware certification.

---

## 1. Verdict

**Realism gap audit: COMPLETE.**  
Visual evidence pack remains **PASS** for completeness/plot QA. Physical realism is **NOT certified**: production plant applies commanded fin angles with **no servo dynamics**; controller applies **software magnitude + slew only**; feedback is **plant-truth** (no IMU/DVL/depth/heading/INS measurement chain). Rudder command chatter **37.738 deg/s** with repeated **±40 deg/s** rate contact is a **physical-realism concern** despite panel-4 PASS.

**Next isolated task (exactly one):** `actuator_dynamics_realism_baseline`

---

## 2. Plant equations (exact structure)

State and inputs (`IMPLEMENTED` in `underwater777_vehicle_dynamics.m`):

\[
g = [\eta^\top,\nu^\top]^\top,\quad
\eta=[x,y,z,\phi,\theta,\psi]^\top\ (\mathrm{NED,\;Euler\;ZYX}),\quad
\nu=[u,v,w,p,q,r]^\top\ (\mathrm{BODY})
\]

\[
u_{\mathrm{act}}=\{\delta_r,\delta_e,X_{\mathrm{prop}}\}
\]

Kinematics (`IMPLEMENTED`):

\[
\dot{r}_{\mathrm{pos}}=R(\phi,\theta,\psi)\,[u;v;w],\qquad
[\dot\phi;\dot\theta;\dot\psi]=J(\phi,\theta)\,[p;q;r]
\]

Dynamics (`IMPLEMENTED`):

\[
A_{\mathrm{rb+am}}\,\dot\nu = \tau(\eta,\nu,u_{\mathrm{act}})=[X;Y;Z;K;M;N]
\]

with restoring, quadratic/cross hydro, rigid-body coupling, and control terms of the form
\(Y_{uu\delta_r}u^2\delta_r\), \(Z_{uu\delta_e}u^2\delta_e\), \(M_{uu\delta_e}u^2\delta_e\), \(N_{uu\delta_r}u^2\delta_r\), \(+X_{\mathrm{prop}}\).

Mass/added-mass (`IMPLEMENTED` structure; coefficient **values** not in these three sources):

\[
A_{\mathrm{rb+am}}=
\begin{bmatrix}
m-X_{\dot u}&0&0&0&m z_g&-m y_g\\
0&m-Y_{\dot v}&0&-m z_g&0&m x_g-Y_{\dot r}\\
0&0&m-Z_{\dot w}&m y_g&-m x_g-Z_{\dot q}&0\\
0&-m z_g&m y_g&I_{xx}-K_{\dot p}&0&0\\
m z_g&0&-m x_g-M_{\dot w}&0&I_{yy}-M_{\dot q}&0\\
-m y_g&m x_g-N_{\dot v}&0&0&0&I_{zz}-N_{\dot r}
\end{bmatrix}
\]

Restoring excerpts (`IMPLEMENTED`):

\[
X\supset -(W-B)\sin\theta,\quad
Z\supset (W-B)\cos\theta\cos\phi,\quad
M\supset -(z_g W-z_b B)\sin\theta-(x_g W-x_b B)\cos\theta\cos\phi
\]

**Density ρ:** not an explicit state or parameter in the plant RHS; buoyancy/weight appear only as globals \(W,B\) (`ASSUMED` external assignment; no ρ(T,S,z) model).  
**Current / water-relative velocity:** production RHS uses body \(\nu\) in hydro + kinematics; no \(V_c\), no \(\nu_r=\nu-R^\top V_c\) (`NOT_IMPLEMENTED` / effectively \(V_c\equiv 0\) `ASSUMED`).  
**Propulsion:** \(X_{\mathrm{prop}}\) is a pure surge force input (`ASSUMED` instantaneous thrust; no shaft, propeller map, advance ratio, or torque).

### Hydrodynamic coefficient provenance and uncertainty

| Item | Status |
|------|--------|
| Symbol set \(X_{uu},Y_{vv},\ldots,M_{uw},\ldots\) as globals | `IMPLEMENTED` (consumed) |
| Numeric provenance (tank ID, CFD, literature, vehicle serial) | **Absent** in allowed sources → treat values as `ASSUMED` / externally loaded |
| Uncertainty (±%, covariance, speed envelopes) | **Absent** → `NOT_IMPLEMENTED` |
| Controller copies `Muw`,`Muuds` defaults 24, −6.15 when empty | `ASSUMED` FF model stubs in `controller_law.m` (not plant ID evidence) |

---

## 3. Actuator law (exact software limits)

From `controller_law.m` (`IMPLEMENTED`):

\[
\delta_{r,\mathrm{cmd}}=\mathrm{sat}(d_{r,\mathrm{yaw}}+g_{ac}(-K_{p,\mathrm{roll}}p),\;\pm\delta_{r,\max})
\]

\[
\delta_{e,\mathrm{unsat}}=\delta_{e,\mathrm{trim}}+\delta_{e,\mathrm{uw\_ff}}+\delta_{e,\mathrm{climb\_ff}}+\delta_{e,\mathrm{fb}},\quad
\delta_{e,\mathrm{cmd}}=\mathrm{sat}(\delta_{e,\mathrm{unsat}},\;\pm\delta_{e,\max})
\]

Software slew (`FIXED` rate constant 40 deg/s in code; applied each `dt_controller`):

\[
\Delta\delta_{\max}=40^\circ/\mathrm{s}\cdot dt,\qquad
\delta\leftarrow\delta_{\mathrm{prev}}+\mathrm{sat}(\delta_{\mathrm{cmd}}-\delta_{\mathrm{prev}},\;\pm\Delta\delta_{\max})
\]

Thrust (`IMPLEMENTED` PI-like surge; no actuator dynamics):

\[
T=\mathrm{sat}\big(T_{\mathrm{trim}}+K_{p,x}(u_{\mathrm{ref}}-u),\;[T_{\min},T_{\max}]\big)
\]

Climb FF (`TUNED`): \(k_\gamma=0.1320695001\), \(|\delta_{e,\mathrm{climb}}|\le 2.8793^\circ\).  
Roll damp (`TUNED`): \(K_{p,\mathrm{roll}}=0.605072\) (default).

### Visual-pack actuator anchors (`AUV_VISUAL_EVIDENCE_PACK.md`)

| Channel | Magnitude | Rate |
|---------|-----------|------|
| δe | ±15 deg | ±40 deg/s |
| δr | ±25 deg | ±40 deg/s |
| PSD marker | — | 13.33 Hz \(=1/dt_{\mathrm{guidance}}\) (`DERIVED` from pack text) |

**Physical-realism flag (panel PASS ≠ physics OK):** rudder command chatter **37.738 deg/s** with repeated contact of the **±40 deg/s** software rate limit on R10 evidence. That is near the full software slew budget → command is rate-rail dominated; without servo lag/bandwidth/load, the closed-loop “actuator” is an ideal ZOH + clip, not a fin.

| Actuator effect | In plant+controller sources? | Label |
|-----------------|------------------------------|-------|
| Magnitude limits | Yes (globals + pack table) | `FIXED` / `IMPLEMENTED` |
| Software rate limit 40 deg/s | Yes | `FIXED` / `IMPLEMENTED` |
| First-order lag / bandwidth | No | `NOT_IMPLEMENTED` |
| Deadband | No | `NOT_IMPLEMENTED` |
| Backlash | No | `NOT_IMPLEMENTED` |
| Hysteresis | No | `NOT_IMPLEMENTED` |
| Motor current / thermal / load | No | `NOT_IMPLEMENTED` |
| Position/current/health feedback | No (cmd→plant angle) | `NOT_IMPLEMENTED` |
| Fin aero/hydro hinge moment → motor | No | `ASSUMED` none |

---

## 4. Sensors: truth / measured / estimated

Controller signature (`IMPLEMENTED`):

```text
controller_law(yaw_ref, pitch_ref, u_ref, psi, theta, r, q, u, r_ff, pitch_ref_dot, phi, w, p)
```

All attitude/rate/speed arguments are used as **direct plant-truth** quantities. Physical pitch map (`IMPLEMENTED` / pack-tested):

\[
\theta_{\mathrm{phys}}=-\theta,\qquad
\dot\theta_{\mathrm{phys}}=-q\cos\phi+r\sin\phi
\]

Pack kinematic identity (`IDENTIFIED` on evidence traj, resid ssRMS = 0.043 deg):

\[
\alpha=\mathrm{atan2}(w,u),\quad
\gamma_{\mathrm{act}}=\mathrm{atan2}(V_D,\|V_{NE}\|),\quad
\mathrm{resid}=\gamma_{\mathrm{act}}-(\theta_{\mathrm{phys}}+\alpha)
\]

| Channel | Truth in plant | Measured model | Estimated / fusion | Multirate / noise / bias / delay / dropout |
|---------|----------------|----------------|--------------------|--------------------------------------------|
| IMU (p,q,r,φ,θ) | Yes | No | No | `NOT_IMPLEMENTED` for control |
| DVL (u,v,w water) | Body ν as truth | No | No | `NOT_IMPLEMENTED` for control |
| Depth (z) | Yes (state) | No | No | `NOT_IMPLEMENTED` |
| Heading (ψ) | Yes | No | No | `NOT_IMPLEMENTED` |
| INS (NED V) | Via \(R\nu\) if logged | No | No | `NOT_IMPLEMENTED` |

Pack CUSUM panel: **simulation** detection evidence (`PASS` panel) under declared offline residual/CUSUM path — **not** hardware certification (`ASSUMED` sensor corruption only where used offline; production sensing remains ideal truth).

Rate filter in controller (`IMPLEMENTED` first-order LPF on \(\dot\theta_{\mathrm{phys}}\), not an IMU model):

\[
a=e^{-dt/\tau_{\mathrm{rate}}},\quad
r_f\leftarrow a\,r_f+(1-a)\,\dot\theta_{\mathrm{phys}}
\]

Default \(\tau_{\mathrm{rate}}=-0.075/\log(0.90)\) if unset (`ASSUMED` / `DERIVED` from that formula).

---

## 5. Water-relative velocity / current frames

Pack / plant frames (`IMPLEMENTED` documentation + RHS):

```text
NED: x North, y East, z Down (+)
BODY: u,v,w ; rates p,q,r
V_NED = R' * [u;v;w]     (pack; R body→NED as coded)
```

Production hydro forces use \(\nu\) directly. There is **no** split:

\[
\nu_r=\nu-\nu_c,\quad \nu_c=R^\top V_c^{\mathrm{NED}}
\]

inside `underwater777_vehicle_dynamics.m`. Therefore water-relative damping/lift under current is **`ASSUMED` \(V_c=0\)** for production. Any offline current/observer work cited elsewhere is **out of this three-source plant** and does not certify production sensing.

---

## 6. Solver / controller / ZOH / compute

| Quantity | Evidence in allowed sources | Label |
|----------|----------------------------|-------|
| Controller step `dt_controller` | Default `0.0375` s if empty in `controller_law.m` | `ASSUMED` default / caller may override |
| Guidance PSD marker | 13.33 Hz \(=1/dt_{\mathrm{guidance}}\) ⇒ \(dt_{\mathrm{guidance}}=0.075\) s | `DERIVED` (pack) |
| Plant ODE solver step / RelTol | Not in three sources | `ASSUMED` / unspecified here |
| ZOH of actuators into continuous plant | Implied: held commands between controller ticks | `ASSUMED` integration contract |
| Compute delay (sense→actuate) | None modeled | `NOT_IMPLEMENTED` (\(d=0\) `ASSUMED`) |
| Determinism | Visual pack: raw-MAT replay, no NL rerun; prior closure bit-identity not re-proven here | Pack: deterministic **replay**; plant RHS itself is deterministic given \((t,g,u)\) |

No explicit multi-rate sensor schedule, bus delay, or jitter model (`NOT_IMPLEMENTED`).

---

## 7. Gap / risk / evidence table

| ID | Gap | Risk if ignored | Evidence (source) | Label |
|----|-----|-----------------|-------------------|-------|
| G1 | No fin servo lag/bandwidth; cmd angle ≡ plant input | Bandwidth/phase of closed loop unrealistically high; rate-rail chatter not load-limited | Dynamics: `controls.delta_*` enter \(u^2\delta\) immediately; controller: slew-only | `IMPLEMENTED` ideal; dynamics `NOT_IMPLEMENTED` |
| G2 | Rudder chatter 37.738 deg/s + ±40 deg/s rate contact | Commands ride software rate limit; hardware would hit current/thermal/hinge limits first | Visual pack panel 4 PASS + stated chatter metric | Visual `PASS`; physics **concern** |
| G3 | No deadband / backlash / hysteresis | Limit-cycle and tracking bias understated | Absent in plant+controller | `NOT_IMPLEMENTED` |
| G4 | No actuator current/thermal/load or meas feedback | FDI isolation / stall / open-circuit not plant-realizable | Cmd-only interface | `NOT_IMPLEMENTED` |
| G5 | Hydro coeff provenance + uncertainty missing | Robustness and HIL model fidelity unknown | Globals only in dynamics | Values `ASSUMED` |
| G6 | ρ, CG/CB, \(W\!-\!B\) as opaque globals | Trim/depth bias sensitivity unquantified | Restoring uses \(W,B,x_g,\ldots\) | Structure `IMPLEMENTED`; values `ASSUMED` |
| G7 | Propulsion = force `Xprop` | Speed loop ignores prop map / RPM lag | Dynamics + thrust law | `ASSUMED` |
| G8 | \(V_c\equiv 0\) in production plant | Path/CTE/yaw under current optimistic | Dynamics uses \(\nu\) only | `ASSUMED` calm water |
| G9 | Sensors = plant truth | Noise/bias/delay/dropout effects on control untested in production | `controller_law` args | `IMPLEMENTED` ideal sensing |
| G10 | Multirate IMU/DVL/INS/depth not in control path | Aliasing / latency phase margin unknown | Absent | `NOT_IMPLEMENTED` |
| G11 | Compute delay = 0 | Digital delay margins uncredited | Absent | `ASSUMED` |
| G12 | CUSUM / visual pack sim PASS | Over-claim as HW cert | Pack panels 4–6 PASS | **Sim evidence only** |

---

## 8. Prioritized bounded untried work

Ordered for **isolated**, production-frozen next steps (do not retune controller; do not claim HW):

1. **`actuator_dynamics_realism_baseline`** (recommended next) — Add **isolated** (non-production) first-order or rate+lag fin model with documented τ, rate, mag; replay R10 commands; report phase lag, rate-rail dwell, and chatter vs ideal slew. Gate: document gap vs G1–G2; **no** gain change.  
2. `actuator_nonlinearity_stub_deadband_backlash` — One bounded deadband **or** backlash stub on δr only; compare chatter/limit-cycle.  
3. `hydro_coeff_provenance_registry` — Register source/uncertainty for each global coeff (doc-only or ID table); no dynamics rewrite.  
4. `production_sensor_chain_stub_one_channel` — One channel (e.g. DVL \(u\) or rate gyro) with σ/bias/delay ZOH **offline**; control still frozen.  
5. `propulsion_map_or_lag_baseline` — Replace pure \(X_{\mathrm{prop}}\) with lag or simple \(n\to T\) map in isolated plant fork.  
6. `compute_delay_ZOH_sensitivity` — Insert fixed \(N\)-tick cmd delay; measure pitch/yaw margin on frozen gains.

---

## 9. Recommended next task (exactly one)

### `actuator_dynamics_realism_baseline`

**Why this one:** Visual-pack actuator panel already shows software rate limits exercised (chatter **37.738 deg/s**, ±40 deg/s contact) while the plant applies angles with **zero** servo dynamics. Prior telemetry ICD/SIL work assumed actuator τ without a production-plant dynamics baseline. Closing G1–G2 is the highest-leverage realism gate before any further controller work, and it stays isolated from frozen production cascade.

**Scope (bounded):** isolated actuator-dynamics baseline only; no controller retune; no CODEX_VERTICAL_PLAN edit; no hardware certification claim.

**Non-goals:** safe-mode promotion; CUSUM retune; hydro ID campaign; sensor-in-the-loop control.

---

## 10. Cross-references

- Append: `suite_results/PITCH_CONTROL_RESEARCH_LOG.md` → `REALISM_GAP_AUDIT_001`  
- Append: `suite_results/STATE_SPACE_MODEL_AUDIT.md` → `REALISM_GAP_AUDIT_001`  
- Antecedent: `suite_results/AUV_VISUAL_EVIDENCE_PACK.md` (PASS)  
- Plant: `underwater777_vehicle_dynamics.m` · Actuator law: `controller_law.m`


---

## APPEND — ACTUATOR_DYNAMICS_REALISM_BASELINE_001 — 2026-08-06 15:54:31

**Shadow baseline:** **PASS** — physical readiness **NOT_CERTIFIED**. Isolated FO+mag+rate fin shadow on accepted R10 commands; production frozen; no plant/controller edit.

- Sources: AUV_VISUAL_EVIDENCE_PACK.md, ACTUATOR_FEEDBACK_TELEMETRY_ICD.md, this audit; cmds from ROLL_PRODUCTION_CLOSURE.mat `candidate.SH`.
- τ **ASSUMED** {[0.05 0.1 0.2]} s (ICD: no vendor servo τ). Limits FIXED ±15/±25 deg, ±40 deg/s.
- Example τ=0.10 s rudder: RMSE=0.7063 deg, delay=0.0750 s, rate_dwell=0.00%, PSD_att@13.33Hz=0.0205, u²δr proxy=0.9828.
- Artifacts: `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.{md,mat,png}`; driver `run_actuator_dynamics_realism_baseline.m`.
- G1 partial closure (documented shadow only). G2 (chatter/rate-rail) remains a physics concern under ideal software cmd; shadow FO attenuates HF (PSD_att≪1) with **0%** additional rate-dwell on already-limited cmds.
- Next: **`actuator_nonlinearity_stub_deadband_backlash`**.
- CODEX_VERTICAL_PLAN untouched.


---

## APPEND — DEPTH_GAMMA_SPEED_SCHEDULED_ID_001 — 2026-08-08 02:08:18

**Gate-1 speed-scheduled ID: PASS**.

- Isolated extension only; production frozen; no retune; no plant/controller edits.
- U_cmd={1.0,1.5,2.0} level+climb; trim/jac/val = 6/6/12 of 6/6/12.
- Artifacts: `suite_results/DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}`.
- Next: **`depth_gamma_structural_decoupling_governor_aw_gate`**. CODEX_VERTICAL_PLAN untouched.


---

## APPEND — DEPTH_GAMMA_STRUCTURAL_GATE_001 — 2026-08-08 02:38:40

**Gate-2 structural depth/γ: PARTIAL**.

- Scheduled alpha decoupling + feasibility governor + residual AW + bumpless; production frozen.
- Primary improve 13.83%; abs_gates=YES; blocker=`secondary_regression_max_28.25%`.
- Artifacts: `suite_results/DEPTH_GAMMA_STRUCTURAL_GATE.{md,mat,png}`.
- Next: **`depth_gamma_structural_gate_blocker_fix`**. CODEX_VERTICAL_PLAN untouched.


---

## APPEND — DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX_001 — 2026-08-08 03:02:03

**Gate-2 attempt 2/3 blocker-fix: PARTIAL**.

- Trim-referenced delta_alpha decoupling + corrected alpha residual; governor/AW/bumpless preserved; production frozen.
- Primary improve 13.32% (old raw 13.83%); abs_gates=YES; secondary=[20.18  -6.13 -24.47]; blocker=`secondary_regression_max_20.18%`.
- Artifacts: `suite_results/DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX.{md,mat,png}`.
- Next: **`depth_gamma_structural_gate_blocker_fix_attempt3`**. CODEX_VERTICAL_PLAN untouched.


---

## APPEND — DEPTH_GAMMA_STRUCTURAL_ATTEMPT3_001 — 2026-08-08 03:23:53

**Gate-2 attempt 3/3 blocker-fix: FAIL**.

- Trim-referenced delta_alpha decoupling + corrected alpha residual; governor/AW/bumpless preserved; production frozen.
- Primary improve -68.61% (old raw 13.83%); abs_gates=YES; secondary=[-19.21  89.67 -24.33]; blocker=`primary_KPI_improve_-68.61%_lt_5.0%`.
- Artifacts: `suite_results/DEPTH_GAMMA_STRUCTURAL_ATTEMPT3.{md,mat,png}`.
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


---

## WATER_CURRENT_FEASIBILITY_MAP_001 — Gate 4A

- Verdict: **PASS**; currents **ASSUMED**; actuator readiness **NOT_CERTIFIED**.
- Deterministic 32-case offline map; robustness failures remain explicit.
- Production/controller/guidance/references frozen; no crab-current FF or external shaper.
- Next: Gate 4B feasibility-aware guidance/reference-governor SHADOW candidate.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_REFERENCE_GOVERNOR_001 — Gate 4B shadow candidate 1 (realism log)

- Verdict: **PARTIAL**; currents **ASSUMED** truth/bound oracle, not a certified estimator; actuators **NOT_CERTIFIED**.
- Primary contact reduction -0.360%; worst-margin improvement 0.000000; exact FEASIBLE parity 1.
- Production frozen; no Vc yaw/crab angle, retune, geometry change, or external shaper.
- Structurally different, untried: internal finite-horizon arc-length governor using a rudder-state predictor and constraint projection. No sweep. No promotion without identical regressions; shadow evidence only.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_001 — Gate 4B final candidate 3/3

- Verdict: **FAIL**; Gate 4B **CLOSED after 3 candidates**.
- Single authorized MATLAB call stopped at a pre-execution parse blocker; 32 declared, 0 executed.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen.
- Gate 5 is prohibited absent an explicit residual-risk waiver.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_RERUN_001 — 4B syntax-fix validation exception beyond 3/3 (realism log)

- Verdict: **FAIL** — Gate 4B syntax-fix validation exception FAIL; causal residual risk remains after authorized rerun.
- Coverage: 32 declared / **0 executed**; pass-through n/a, RESHAPE n/a, REFUSE n/a.
- Causal FAIL: route/current logical-mask orientation (1x32 & 32x1 → 32x32) aborted governor before any contract.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen; not promoted.
- Prior `WATER_CURRENT_ADMISSION_GOVERNOR.*` FAIL artifacts preserved; RERUN artifacts written.
- Next: Gate 5 prohibited absent explicit residual-risk waiver; currents ASSUMED and actuators NOT_CERTIFIED.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_RERUN2_001 — 4B mask-orientation validation exception beyond 3/3 (realism log)

- Verdict: **FAIL** — Gate 4B mask-orientation validation exception FAIL; causal residual risk remains after authorized rerun2.
- Coverage: 32/32; pass-through 18, RESHAPE 3, REFUSE 11.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen.
- Production not promoted; refusal never counted as tracking success.
- Next: Gate 5 prohibited absent explicit residual-risk waiver; currents ASSUMED and actuators NOT_CERTIFIED.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_RERUN2_001 — causal residual clarification (realism log)

- Mask orientation validated; campaign executed 32/32 (18 PASS_THROUGH / 3 RESHAPE / 11 REFUSE).
- Verdict remains **FAIL** on `admitted_secondary_within_2pct` for RESHAPE rows 22-24 (depth_rms).
- Contact reduction gate passed; hard violations zero; refusals deterministic and not counted as tracking success.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen; Gate 5 prohibited without waiver.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## NAV_MULTIRATE_SENSOR_CHAIN_001 - Gate 5A multirate sensor realism and visual validation (realism log)

- Verdict: **PASS**; realism scope is sensor-interface realism only, not navigation accuracy.
- Realism added: per-channel clocks (IMU 100 Hz, INS 50 Hz, heading 20 Hz, depth 10 Hz, DVL 5 Hz, USBL absent) on a 0.005 s base tick, ZOH plus transport-delay queues, sequence counters, validity, quality and stale age.
- Frame realism: DVL reports water-relative BODY velocity and INS reports ground-relative NED velocity, so under Vc = [0 0.15 0] they separate by |Vc| while coinciding at Vc = 0; depth is NED-down positive; the IMU reports specific force including gravity, not acceleration.
- Failure realism: declared DVL bottom-lock outage drives the full INIT_WAIT -> OK -> DROPOUT -> OK sequence (6394 dropout ticks aggregated), with quality collapsing to zero, stale age growing monotonically and a ramped reacquire.
- Visual QA: 9-panel figure (multirate staircases vs truth, status raster, stale age, quality, declared vs achieved rate, per-case truth-vs-measured error, bottom-lock vs availability). Reviewed and accepted.
- Honesty guards: no truth leakage into any measured channel, ESTIMATED bus all NaN / UNAVAILABLE, and all sensor numerics flagged ASSUMED in the artifact tables.
- Simulation-only; production frozen; Gate 4 remains FAIL / shadow-only and unpromoted.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION_001 - Gate 5A validation realism and visual re-validation (realism log)

- Verdict: **PASS**; the realism scope is unchanged sensor-interface realism, re-executed rather than extended. No navigation accuracy is claimed.
- Realism re-exercised without modification: per-channel clocks (IMU 100 Hz, INS 50 Hz, heading 20 Hz, depth 10 Hz, DVL 5 Hz, USBL absent) on the 0.005 s base tick, ZOH plus transport-delay queues, sequence counters, validity, quality and stale age.
- Frame realism reproduced bit-for-bit: the DVL water-relative BODY channel and the INS ground-relative NED channel separate by |Vc| under Vc = [0 0.15 0] and coincide at Vc = 0; depth is NED-down positive; the IMU reports specific force including gravity.
- Failure realism reproduced bit-for-bit: the declared DVL bottom-lock outage drives INIT_WAIT -> OK -> STALE -> DROPOUT -> OK with quality collapse, monotonic stale growth and a ramped reacquire, and the stale and dropout tick counts match the prior run exactly.
- Visual validation: a new 9-panel figure (declared gates, validation gates, per-case gate raster, showcase DVL prior-vs-now overlay, status raster, error-metric parity scatter on y = x, per-category deviation against tolerance, declared vs achieved rate, and a process / honesty / isolation record). The final PNG was **decoded after writing** (2407 x 1629 px, ink fraction 0.261) so readability is validated rather than assumed: YES.
- The prior-vs-now overlay is the load-bearing visual: the prior measured trace is drawn thick and grey underneath this run's red dashed trace, so any divergence would show up as grey bleeding through.
- Honesty guards intact: no truth leakage, ESTIMATED bus all NaN / UNAVAILABLE, USBL absent, every sensor numeric flagged ASSUMED.
- Process note: this validation ran in **one** MATLAB process; the prior task's **four** starts are recorded as noncompliance.
- Simulation-only; production frozen; Gate 4 remains FAIL / shadow-only and unpromoted. `CODEX_VERTICAL_PLAN.md` untouched.

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

- Realism impact: the sensor chain remains the Gate 5A ASSUMED model. This task adds no new
  physics and no new plant behaviour; it adds an estimator on top of an already-declared bus.
  The visible realism gain is behavioural rather than physical: DVL bottom-lock loss now produces
  an observable degradation of the navigation solution (current state unobservable, covariance
  growth, reacquisition transient) instead of a silent flag. Visual validation: 12-panel overview
  decoded from disk after writing and checked for size, ink fraction and contrast.


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

- Realism impact: none. No physics, no plant behaviour and no sensor model was touched.
  The visual validation record is reproduced: the 12-panel overview is rendered, decoded
  from disk with imread and checked for size, ink fraction and contrast, and the repair
  figure is annotated as an evidence repair so it can never be mistaken for a new result.
  One genuine gain in validation practice: rendered-artifact correctness is now itself
  gated, so a report that reads as garbage can no longer pass alongside a clean run.
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

- Realism impact: the sensor picture is more honest than Gate 5B in one specific way -
  an optional acoustic position aid now exists, with latency, fixed bias, noise, a long
  dropout burst and malformed packets, and the filter has to live with all of it. It is
  still not a realistic USBL: no ray bending, no slant-range geometry, no lever arm, no
  multipath, no range-dependent noise. The 12-panel figure is decoded from disk after
  writing and checked for size, ink and contrast, and the per-case table in the report is
  decoded and compared back to the MAT.
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

- Realism impact: none, deliberately. No model, sensor, disturbance or scenario changed.
  What improved is the trustworthiness of the existing realism evidence: the 12-panel
  validation figure is decoded from disk after writing and checked for size, ink and
  contrast, and both 24-row tables in the report are decoded and compared back to the
  MAT, so a correct result cannot ship behind a garbled report.
- NEXT: GATE 6 (named because Gate 5C is now formalized, NOT attempted here): PROPULSION / POWER / COMPUTE budget and margin. Take the actuator commands and the navigation duty cycle this vertical already produces and close them against a declared thruster and control-surface power model, an energy budget over the mission profile, and a compute-load / latency budget for the estimator and controller rates. Numerics remain ASSUMED and every result remains NOT_CERTIFIED until bench data exists.


## PROPULSION_POWER_COMPUTE_BASELINE_001 — 2026-08-08 19:09:49 (realism log)

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
- Realism scope: ASSUMED thrust lag/gain/slew/saturation only (gain, exact-ZOH lag, slew, saturation). Not identified from hardware; no sensor, current or thermal realism is claimed.
- Variant cells that lost the frozen FEASIBLE gates are recorded as results, not as retunes: 24 of 24 variant runs FEASIBLE.
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.png`.
- Production untouched; no gain, config or controller change.

<!-- REAL_TIME_POWER_INTEGRITY_CONTRACT_001 -->

## Gate 6B - REAL_TIME_POWER_INTEGRITY_CONTRACT (REAL_TIME_POWER_INTEGRITY_CONTRACT_001)

**Date:** 2026-08-08 - **Verdict:** **PASS** (13/13 declared hard gates) - **NOT_CERTIFIED** (simulation-only)

- Realism added at the **compute/power layer**, not the hydrodynamic layer: fixed-priority preemptive scheduling, release jitter, transport delay + jitter with in-order delivery, ISR/DMA interference bursts, bus sag from load current, and compute throttling below the undervoltage warning.
- Honest limits: the plant inside this harness is an explicit **first-order surrogate placeholder**; the Pareto **Tracking** and **Estimation** axes are reported **N/A** rather than fabricated.
- Visual QA: `suite_results/REAL_TIME_POWER_INTEGRITY_CONTRACT.png` (6 panels: response vs deadline, miss accounting, brownout/safe-hold trace, end-to-end latency vs bound, timing/safety Pareto, gate table).
- **Carried cosmetic QA debt:** the accepted Gate 6 PNG `PROPULSION_POWER_COMPUTE_PARITY_FIX.png` has a minor **overlapping parity annotation**. Recorded only; the accepted Gate 6 artifacts were **not** rerun or altered.
- Disk preflight at start: 4.34 GiB free (>= 3 GiB minimum, below the preferred 5 GiB) - disk-pressure debt.

---

## Append: GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_001 (PARTIAL)

**Date:** 2026-08-09 00:50:23 - **Class:** Gate 7 isolated mission-manager / FDIR **simulation** - **MATLAB runs:** 1 - **production:** byte-identical - **CODEX_VERTICAL_PLAN:** untouched  
**Verdict:** **PARTIAL** (14/15 hard gates) - **Physical / hardware readiness: NOT_CERTIFIED**

- Isolated harness (`run_gate7_mission_manager_fail_silent_sim.m`) exercises MissionCommand / WaypointSet / TrajectorySegment / Ack with the full ICD header (`schema_version`, mission/segment id, `seq`, `t_mono`, valid/quality/integrity, NED/SI tags, validity horizon, heartbeat) over 16 frozen ASSUMED scenarios, each replayed twice.
- 9 monitors (leak, undervoltage, watchdog overrun, actuator stuck/current, IMU/DVL/depth stale, bus timeout, mission stale) with declared precedence, latching and 1.0 s recovery hysteresis; response ladder hold-last-safe -> constrain -> safe-hold.
- Detected 17/17 injected faults inside declared bounds, 0 false alarms, 0 missed, 0 Ack-code mismatches, 0 surface / 0 accommodation / 0 direct-actuator commands issued.
- Labels unchanged: mission/nav/actuator-feedback rates `TO_BE_IDENTIFIED`; all fault numbers `ASSUMED`; message contract `INTERFACE_SPECIFIED`; harness `IMPLEMENTED` (simulation); hardware `NOT_CERTIFIED`.
- Evidence: `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.{md,mat,png}`.

**Visual QA:** 9-panel `GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.png` (response-ladder matrix, precedence detail, latency-vs-bound, bumpless refs, depth/no-auto-surface, waypoint set, Ack histogram, ladder dwell, gate summary). Rendered from simulation logs only.

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

**Visual QA:** 9-panel `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.png`. Two attempt-1 cosmetic defects fixed without touching data: the banner is now drawn with the TeX interpreter disabled so underscores render literally, and the 3D geometry panel is framed to the traversed extent instead of the full waypoint bounding box. Panel 3 additionally shows the repaired severity-based action gap next to the detection latency, and panel 8 annotates each case with its three-valued recovery class.


<!-- APPEND_MARKER:GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001 -->

## Append: GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001 (realism log)

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

## Append: GATE8_ACTUATOR_ORDER_SCAN_REPAIR_001 (realism log)

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


<!-- APPEND_MARKER:GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001 -->

## Append: GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001 (realism log)

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

## Append: GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_RESUME_001 (realism log)

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

## Append: GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_001 (realism log)

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

## Append: GATE8_RESIDUAL_RISK_WAIVER_AND_GATE9_ENTRY_001 (realism / validation log)

**Date:** 2026-08-09 12:21:58 | **Class:** doc-only Gate 8 disposition | **MATLAB runs:** 0 | **Source/runtime edits:** NONE | **Repo scan:** NONE | **Production/CODEX_VERTICAL_PLAN:** untouched | **Physical / hardware readiness:** **NOT_CERTIFIED**

**Gate 8 verdict: `WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT`. Gate 8 is NOT PASS and must not be transcribed as PASS.** Issued under the readiness-plan rule allowing a prior gate to be explicitly waived with a written residual risk, on the user's direction to finish this simulation-readiness phase after three failed Monte Carlo closure attempts and with the scalar-rescaling and C1 course-reference methods closed.

Sources read (exactly 3): `suite_results/AUV_REALIZATION_READINESS_PLAN.md`, `suite_results/AUTONOMOUS_EXECUTION_POLICY.md`, `suite_results/GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE.md`. All previously accepted evidence in this document — the visual evidence pack PASS (6/0/0), the frozen production cascade anchors, the actuator FO shadow and rudder-deadband appends — is **preserved unchanged**; nothing above is reopened, re-audited or re-labelled.

### Realism gaps that this waiver carries forward (all OPEN)

| # | Gap | Why it matters for realism | Label |
|---|-----|----------------------------|-------|
| R1 | **R10 production rudder rail unresolved.** Raw demand peaks 466.6729 deg before any limiter; the plant input sits at the 25.0000 deg envelope for 0.2817 of a 30 s horizon (8.450 s, 12 intervals, longest 2.300 s, first at t = 1.825 s); magnitude-limiter dwell 0.8908, rate-limiter dwell 0.6917, peak realized slew 40.0000 deg/s. Multi-origin: 3 contributions each reach the envelope alone. | A control surface that spends most of a run against its magnitude and rate rails has no authority margin left for disturbance, current, sensor noise or servo lag — precisely the effects a realistic vehicle adds. Panel PASS never covered this. | **BLOCKER** |
| R2 | **CG / CB ±2 cm and buoyancy ±3% priors drawn but never injected** — no plant-parameter seam exists (HG11). | Restoring, trim and buoyancy are the physical realism knobs most likely to move depth and pitch behaviour; the distribution never touched them. | `ASSUMED`, **UNSUPPORTED** |
| R3 | **Gate 7 16-case FDIR matrix not re-drawn inside the Monte Carlo loop** (HG12). | Fault detection, latching, hysteresis and the hold-last-safe / constrain / safe-hold ladder are unevidenced under distributed uncertainty. | **NOT_EVALUATED** |
| R4 | **X / XZ / R10 cell geometry is an `ASSUMED_RECONSTRUCTION`** (HG13). | The mission geometry the realism claims rest on is reconstructed, not bound to the frozen definitions. | `ASSUMED_RECONSTRUCTION` |
| R5 | **Estimator streams absent on this path**; the loop uses truth `x`, `y`. | Ideal plant-truth sensing is exactly the G9–G10 realism gap this document raised; it is still open at Gate 8. | `NOT_IMPLEMENTED` |
| R6 | **Power coverage PARTIAL** — thrust-authority derate only, brownout branch never entered. | The Gate 6B power-integrity contract is not distributionally exercised. | `PARTIAL` |
| R7 | **Hardware NOT_CERTIFIED.** No bench, HIL or wet data; servo τ, deadband, hysteresis, thruster map and sensor σ / bias / delay remain unidentified. | Unchanged hard claim boundary of this document. | `NOT_CERTIFIED` / `TO_BE_IDENTIFIED` |

Note on continuity with §2.1 of this document: the ideal software rudder chatter figure of 37.738 deg/s with repeated ±40 deg/s rate contact was flagged there as a **physics concern despite panel PASS**. The R10 rail measurement above is the closed-loop confirmation of that concern, now quantified. The earlier flag stands; it is corroborated, not contradicted.

### Why plant feasibility is nevertheless judged evidenced

Exact nominal parity (hooks-off shadow bit-identical to unmodified `continuous_path_tracking.m`, 8/8 cells; R10 fingerprint `n=153600.s1=19094896.s2=2901292177` reproduced across production, replica and instrumented replica), bitwise deterministic reverse-order replay, contribution reconstruction closing to 1.137e-13 deg over 1200 samples, guidance closure and geometry identities at 0.000e+00 to 2.005e-15 rad, zero rate violations against the 40 deg/s envelope after the limiter-ordering defect was repaired, and pooled `cte_max` P5/P50/P95/worst = 0.110 / 0.342 / 0.565 / 0.826 m with pass probability 0.8594 (Wilson 95% CI [0.8115, 0.8967]). The twin integrates, reproduces and respects its declared envelopes. What failed is coverage, injection and one unresolved authority rail — not plant viability.

### No banned or rejected method will be retried

`SCALAR_METHOD_CLOSED` (coordinated `(Kp_psi, Kd_psi)` rescaling at fixed `Td`: the rail falls only by trading cross-track error, 0.21262 → 0.89243 m across the anchors) and `REJECT_C1_METHOD_CLOSED` (`k_beta` 1.35 → 1.00: over-crab removed 100% but implied P demand improved only +0.3806% against a +5% floor, a ratio fixed by the 0.335019 deg term versus the 5.625664 deg heading error) are closed on structure, not on marginal numbers. gamma INDI / PI / LADRC, depth PI / NDO, crab-current FF and the simple polyline shaper remain permanently banned. No visual panel, pack PASS or shadow result is upgraded by this append.

### What is unlocked, and what is not

Unlocked: **`GATE9_SIMULATION_RC_ASSESSMENT_001`** only — a bounded simulation release-candidate assessment and evidence-range assembly, with every component requirement range `DERIVED` and carrying its `ASSUMED` / `TO_BE_IDENTIFIED` parent label and its limiting residual-risk item. **Gate 9 PASS remains impossible unless every hard safety gate passes**, so PARTIAL or FAIL is the expected honest outcome. After the Gate 9 disposition — of any kind — a fast, read-only whole-code embedded-readiness gap audit is permitted; its own PASS bar is unchanged. **STM32 adaptation stays forbidden** until the exact part and board are supplied **and** every unresolved blocker is explicitly dispositioned. Simulation, visual-pack and shadow PASS are never hardware certification.


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

