# AUV_REALIZATION_READINESS_PLAN — REALIZATION_READINESS_PLAN_001

**Date:** 2026-08-08  
**Class:** doc-only plan realignment  
**MATLAB run:** NO · **model/controller edits:** NO · **CODEX_VERTICAL_PLAN:** untouched  
**Physical / hardware readiness:** **NOT_CERTIFIED**  

## Sources (strict, ≤2)

| # | Path | Role |
|---|------|------|
| 1 | `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md` | Realism gap audit; plant/sensor/actuator gaps G1–G12; frozen production cascade anchors; actuator FO shadow append |
| 2 | `suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.md` | Open-loop rudder deadband sensitivity; return pointer to depth/gamma coupled-plant ID |

**Evidence labels** (never upgrade without new evidence):  
`IMPLEMENTED` · `IDENTIFIED` · `DERIVED` · `TUNED` · `FIXED` · `ASSUMED` · `NOT_IMPLEMENTED` · `NOT_CERTIFIED`

Simulation / visual-pack / shadow-actuator PASS ≠ hardware certification.

---

## 1. Verdict

**Realization readiness plan: CREATED.**  
The previous generic multi-phase roadmap is **reordered** so a **realizable digital twin** is gated before CAD, procurement, and wet tests. Visual evidence pack and actuator shadow/deadband work remain **simulation-only**, **NOT_CERTIFIED**. Production cascade metrics below stay **frozen accepted** until a later gate explicitly reopens them with new PASS criteria.

**Next gate (exactly one):** `depth_gamma_coupled_plant_identification_gate`  
**Plan ends at EXTERNAL gate:** only hull/mechanical CAD, vendor purchase, bench/HIL/wet tests, and real-data system ID remain.

---

## 2. Frozen accepted production metrics (do not reopen casually)

Preserved from allowed sources. Labels are as stated there; **do not treat as HW cert**.

### 2.1 Production cascade / visual-pack anchors (`AUV_REALISM_AND_VISUAL_VALIDATION.md`)

| Item | Frozen value | Provenance |
|------|--------------|------------|
| Visual evidence pack | **PASS** (6/0/0); production frozen | Pack antecedent; sim QA only → **NOT_CERTIFIED** |
| Climb FF gain \(k_\gamma\) | 0.1320695001 | `TUNED` |
| Climb FF magnitude bound | \(\lvert\delta_{e,\mathrm{climb}}\rvert\le 2.8793^\circ\) | `TUNED` |
| Roll damp \(K_{p,\mathrm{roll}}\) | 0.605072 (default) | `TUNED` |
| Elevator magnitude | ±15 deg | `FIXED` / pack |
| Rudder magnitude | ±25 deg | `FIXED` / pack |
| Software fin rate limit | ±40 deg/s | `FIXED` |
| Guidance PSD marker | 13.33 Hz \(=1/dt_{\mathrm{guidance}}\) ⇒ \(dt_{\mathrm{guidance}}=0.075\) s | `DERIVED` |
| Controller step default | \(dt_{\mathrm{controller}}=0.0375\) s if empty | `ASSUMED` default |
| Kinematic identity resid (pack traj) | ssRMS = 0.043 deg | `IDENTIFIED` on evidence traj |
| Ideal software rudder chatter (R10 pack) | **37.738** deg/s (deadband stub: **37.7381** deg/s) with repeated ±40 deg/s rate contact | Visual pack / G2; physics **concern**, panel PASS ≠ physics OK |

### 2.2 Actuator shadow / deadband evidence (simulation-only, **NOT_CERTIFIED**)

| Item | Value | Provenance |
|------|-------|------------|
| FO+mag+rate shadow baseline | **PASS** — physical readiness **NOT_CERTIFIED** | Append ACTUATOR_DYNAMICS_REALISM_BASELINE_001 |
| Assumed servo τ grid | {0.05, 0.1, 0.2} s | `ASSUMED` (ICD: no vendor τ) |
| Example τ = 0.10 s rudder | RMSE = 0.7063 deg; delay = 0.0750 s; rate_dwell = 0.00%; PSD_att@13.33 Hz = 0.0205; \(u^2\delta_r\) proxy = 0.9828 | Shadow replay of accepted R10 cmds |
| Rudder deadband stub | **PASS** — open-loop sensitivity only; **NOT** closed-loop limit-cycle | ACTUATOR_RUDDER_DEADBAND_STUB_001 |
| Deadband widths | {0, 0.10, 0.25, 0.50} deg | `ASSUMED` play-free grid |
| Deadband at w = 0 / 0.10 / 0.25 / 0.50 | RMSE 0.7063 / 0.7136 / 0.7499 / 0.8666 deg; bias ≈ −w; chatter 8.8048 deg/s (post-FO); PSD_att 0.0205 unchanged | Steady t≥5 s, rudder only |

**Hard claim boundary:** visual pack PASS, FO shadow PASS, and deadband stub PASS are **simulation evidence only**. They do **not** certify servo τ, deadband, hysteresis, current/thermal load, or hardware FDI.

---

## 3. Why the old generic 13-phase roadmap is reordered

The prior generic ordering treated “finish tracking loops → add sensors → add actuators → mission → hardware” as roughly sequential product phases. For a **realizable digital twin**, that order is inverted at several critical points:

1. **Coupled vertical plant ID before more vertical control structure.** Depth/γ loops on an unidentified coupled plant produce retunes that cannot be mapped to hydro/propulsion/restoring uncertainty. Gate 1 must freeze an identified (or bounded) vertical plant model before Gate 2 structural decoupling / reference governor / anti-windup.
2. **Structural guidance/control fixes before closed-loop actuator realism.** Open-loop FO+deadband stubs already exist (`ASSUMED` τ, play-free deadband). Closing the loop on actuators (Gate 3) without vertical structural hygiene risks attributing depth/γ failure to servo lag.
3. **Water-relative current + feasibility-aware guidance before navigation fusion theater.** Production plant effectively assumes \(V_c\equiv 0\) (G8). Current-aware guidance feasibility is a plant/guidance contract, not an EKF feature.
4. **Truth / measured / estimated multirate chain after plant+guidance contracts.** Ideal plant-truth sensing (G9–G10) must be replaced only once command paths and current frames are defined; otherwise EKF “fixes” mask guidance/plant errors.
5. **Propulsion / power / compute realism after navigation contracts.** Thrust-as-\(X_{\mathrm{prop}}\) (G7) and zero compute delay (G11) matter for margins once sensed rates and guidance clocks exist.
6. **Mission manager + fail-silent after physical envelopes exist.** Watchdogs need actuator, sensor, and power envelopes — not the reverse.
7. **Monte Carlo distribution regression before “release candidate.”** Point-trajectory PASS (visual pack) is not distributional robustness.
8. **Procurement requirement ranges are outputs of the twin, not inputs.** Component ranges (servo τ, deadband, DVL σ, thruster lag, compute latency) are Gate 9 deliverables for EXTERNAL CAD / purchase / HIL / wet ID.

**Rejected approaches — never retry** (structural / vertical / current FF dead-ends already closed as non-candidates):

- gamma INDI / gamma PI / gamma LADRC  
- depth PI / depth NDO  
- crab-current FF  
- simple polyline shaper  

`CODEX_VERTICAL_PLAN` remains **untouched** by this plan realignment.

---

## 4. Ordered realization gates

Gates are sequential. A gate may begin only when prior gates are PASS or explicitly waived with a written residual risk. All gates through Gate 9 are **simulation / digital-twin** work. Hardware lives only under **EXTERNAL**.

---

### Gate 1 — Depth / γ coupled-plant identification

**ID:** `depth_gamma_coupled_plant_identification_gate`  
**Priority:** **NEXT (exactly one)**

| Field | Content |
|-------|---------|
| **Intent** | Identify (or bound) the coupled depth–flight-path / pitch–heave plant used by production kinematics and hydro, so later structural work is model-referenced rather than retune-of-the-week. |
| **Inputs** | Frozen production cascade metrics (§2.1); plant structure from realism audit (mass/added-mass, restoring, \(u^2\delta_e\) control terms); pack kinematic identity \(\gamma_{\mathrm{act}}\approx\theta_{\mathrm{phys}}+\alpha\) (resid ssRMS 0.043 deg); climb-FF and elevator limits as **frozen** operating envelope |
| **Outputs** | Coupled vertical plant ID report: operating points, identified or bounded maps \(\delta_e\!\to\!\{q,\theta,w,\gamma,z\}\), residual norms, uncertainty envelopes; coefficient provenance table (at least depth/γ-relevant subset); gate PASS/FAIL record |
| **PASS criteria** | (a) Explicit coupled model or bounded LTI/LPV family documented with provenance labels; (b) residual vs accepted trajectories within declared ID tolerances; (c) uncertainty stated (not silent `ASSUMED` globals); (d) **no** production gain retune; (e) rejected gamma INDI/PI/LADRC and depth PI/NDO **not** reopened |
| **Evidence** | ID metrics, bode/step/trajectory overlays, provenance registry rows, reproducibility notes |
| **Provenance labels** | Structure `IMPLEMENTED`; numeric coeffs today `ASSUMED` until ID upgrades to `IDENTIFIED` / `DERIVED`; controller FF stubs remain non-plant-ID |
| **Dependencies** | Visual pack frozen; realism audit G5/G6 acknowledged; actuator open-loop stubs complete (do not block Gate 1) |
| **Blockers** | Missing hydro provenance; inability to separate trim/`W−B`/speed effects; any attempt to “fix” vertical tracking by retrying rejected depth/γ architectures |
| **Non-goals** | Controller retune; closed-loop actuator plant swap; current/EKF; `CODEX_VERTICAL_PLAN` edits |

---

### Gate 2 — Structural depth / γ decoupling + reference governor + anti-windup

**ID:** `depth_gamma_structural_decoupling_governor_aw_gate`

| Field | Content |
|-------|---------|
| **Intent** | Apply **structural** vertical architecture: decoupling informed by Gate 1, reference governor for feasible \((z,\gamma,\theta)\) commands, and anti-windup consistent with elevator saturations — **without** resurrecting rejected depth/γ controllers. |
| **Inputs** | Gate 1 PASS model + uncertainty; frozen climb-FF / elevator / rate limits; production cascade as baseline comparator |
| **Outputs** | Structural design note; governor feasibility set; AW policy; isolated sim comparison vs frozen baseline (metrics declared a priori) |
| **PASS criteria** | (a) Decoupling/governor/AW justified from Gate 1 plant; (b) saturation/windup behavior demonstrated; (c) no regression beyond agreed tolerances on frozen envelopes; (d) **never retry** gamma INDI/PI/LADRC, depth PI/NDO |
| **Evidence** | Time histories, saturation dwell, governor intervention counts, AW engagement logs |
| **Provenance** | Design `DERIVED` from Gate 1; gains if any newly introduced labeled `TUNED` only inside this gate’s isolated branch until promotion criteria exist |
| **Dependencies** | Gate 1 PASS |
| **Blockers** | Gate 1 FAIL; silent gain hunting; polyline shaper / crab-current FF reuse |

---

### Gate 3 — Closed-loop actuator realism

**ID:** `closed_loop_actuator_realism_gate`

| Field | Content |
|-------|---------|
| **Intent** | Move from open-loop FO+deadband **shadow** (PASS, NOT_CERTIFIED) to **closed-loop** actuator realism affecting fins in the control loop, documenting limit-cycle / phase / rate-rail behavior vs ideal slew. |
| **Inputs** | Frozen mag/rate limits (±15/±25 deg, ±40 deg/s); FO shadow metrics (τ `ASSUMED`); deadband stub open-loop table; G1–G4 gap statements; Gate 2 structural vertical path |
| **Outputs** | Closed-loop actuator model branch (lag ± optional play-free deadband); closed-loop chatter/limit-cycle report; updated G1/G2 residual risk |
| **PASS criteria** | (a) Closed-loop experiment (not cmd replay only); (b) τ/deadband remain labeled `ASSUMED` unless bench ID provided; (c) chatter vs ideal 37.738 deg/s contextualized; (d) production promotion optional and separate; (e) **NOT_CERTIFIED** explicit |
| **Evidence** | Closed-loop δr/δe tracking, rate-dwell, ZC/stick, PSD_att@13.33 Hz, CTE/attitude deltas |
| **Provenance** | Shadow/deadband antecedents `IMPLEMENTED` as offline evidence; closed-loop branch new |
| **Dependencies** | Gates 1–2 PASS (vertical structure stable enough to attribute actuator effects) |
| **Blockers** | Claiming HW cert from `ASSUMED` τ; backlash/hysteresis invention beyond declared stubs |

---

### Gate 4 — Water-relative current + feasibility-aware guidance

**ID:** `water_relative_current_feasibility_guidance_gate`

| Field | Content |
|-------|---------|
| **Intent** | Introduce \(\nu_r=\nu-R^\top V_c\) (or equivalent) into the twin and make guidance **feasibility-aware** under bounded current — not crab-current FF, not simple polyline shaper. |
| **Inputs** | Production calm-water assumption \(V_c\equiv 0\) (G8); Gate 2 governor feasibility language; frozen path-following envelopes |
| **Outputs** | Current frame contract; bounded-\(V_c\) scenarios; feasibility-aware guidance law/branch; CTE/yaw/depth metrics under current |
| **PASS criteria** | (a) Water-relative hydro/kinematics consistent; (b) guidance refuses or reshapes infeasible refs; (c) **no** crab-current FF; (d) **no** simple polyline shaper retry |
| **Evidence** | Current cases, feasibility rejection logs, CTE distributions |
| **Provenance** | Frame math `DERIVED`; current profiles `ASSUMED` until field data |
| **Dependencies** | Gates 1–3 (plant + structure + actuator CL attribution) |
| **Blockers** | Treating offline current-observer notes as production sensing cert |

---

### Gate 5 — Truth / measured / estimated multirate navigation chain + EKF interface

**ID:** `multirate_nav_truth_measured_estimated_ekf_gate`

| Field | Content |
|-------|---------|
| **Intent** | Replace ideal plant-truth control arguments with an explicit **truth → measured → estimated** chain (IMU/DVL/depth/heading schedules, noise/bias/delay/dropout) and a documented EKF (or equivalent) interface — without claiming HW. |
| **Inputs** | G9–G10; controller signature truth usage; Gate 4 current frame; rate clocks \(dt_{\mathrm{controller}}\), \(dt_{\mathrm{guidance}}\) |
| **Outputs** | Sensor ICD for sim; multirate schedule; EKF interface spec (states, updates, covariances); SIL results vs truth-feedback baseline |
| **PASS criteria** | (a) Every controlled channel labeled truth/measured/estimated; (b) multirate + delay modeled; (c) EKF interface frozen for later HIL; (d) **NOT_CERTIFIED** |
| **Evidence** | Noise tables, NEES/consistency checks (sim), dropout cases |
| **Provenance** | Sensor σ/bias `ASSUMED` until vendor/bench; structure `IMPLEMENTED` in twin |
| **Dependencies** | Gate 4 PASS |
| **Blockers** | Feeding EKF with undefined current frame; conflating CUSUM sim PASS with navigation cert (G12) |

---

### Gate 6 — Propulsion / power / compute realism

**ID:** `propulsion_power_compute_realism_gate`

| Field | Content |
|-------|---------|
| **Intent** | Replace pure \(X_{\mathrm{prop}}\) and zero compute delay with twin-faithful propulsion lag/map, power draw envelope, and sense→actuate compute delay/jitter/ZOH contract (G7, G11). |
| **Inputs** | Thrust law sat/PI structure; Gate 5 clocks; actuator closed-loop from Gate 3 |
| **Outputs** | Propulsion model branch; power budget envelope; compute-delay sensitivity + selected twin default |
| **PASS criteria** | (a) Speed-loop metrics under prop lag/map; (b) power envelope documented; (c) delay margins quantified on frozen attitude/path metrics; (d) labels honest (`ASSUMED` until bench) |
| **Evidence** | \(u\)-tracking, delay sweep, power time series |
| **Provenance** | Maps `ASSUMED`/`DERIVED`; no vendor RPM map required for gate PASS if uncertainty bounded |
| **Dependencies** | Gate 5 PASS |
| **Blockers** | Instant thrust retained as “good enough” without delay/power envelopes |

---

### Gate 7 — Constrained 3D mission manager + watchdog / fail-silent simulation

**ID:** `mission_manager_watchdog_fail_silent_gate`

| Field | Content |
|-------|---------|
| **Intent** | Add constrained 3D mission management with watchdogs and **fail-silent** simulation paths using envelopes from Gates 3–6 (actuators, sensors, power, compute). |
| **Inputs** | Feasibility governor (Gate 2/4); actuator health proxies; nav integrity flags; power/compute limits |
| **Outputs** | Mission manager spec; watchdog matrix; fail-silent scenarios and logs; safe-hold / silent behaviors in sim |
| **PASS criteria** | (a) Constraint set explicit (geo, depth, speed, actuator, nav integrity); (b) watchdog detection→response traced; (c) fail-silent does not claim HW safe-mode certification |
| **Evidence** | Injected fault/dropout cases; timing of silent responses |
| **Provenance** | Policies `DERIVED`; thresholds `ASSUMED`/`TUNED` in sim |
| **Dependencies** | Gates 3–6 PASS |
| **Blockers** | Promoting CUSUM/visual panels to operational safe-mode without this gate |

---

### Gate 8 — Monte Carlo distribution regression

**ID:** `monte_carlo_distribution_regression_gate`

| Field | Content |
|-------|---------|
| **Intent** | Replace single-trajectory visual PASS with distributional regression over twin uncertainties (hydro bounds, current, sensors, actuators, delay). |
| **Inputs** | Uncertainty registries from Gates 1, 3–6; mission set from Gate 7; frozen metric definitions |
| **Outputs** | MC campaign config; percentile tables for CTE/attitude/actuator; regression gate vs prior campaign |
| **PASS criteria** | (a) N and seed policy documented; (b) pass/fail on agreed percentiles (not means alone); (c) no silent narrowing of uncertainty to force PASS |
| **Evidence** | `.mat` ensembles, summary MD/PNG, failure-case gallery |
| **Provenance** | Distributions inherit labels from parent parameters |
| **Dependencies** | Gate 7 PASS |
| **Blockers** | Point-run cherry-picking; upgrading labels because MC “looked fine” |

---

### Gate 9 — Simulation release candidate + procurement-ready component requirement ranges

**ID:** `sim_release_candidate_procurement_ranges_gate`

| Field | Content |
|-------|---------|
| **Intent** | Declare a **simulation release candidate** digital twin and publish **procurement-ready component requirement ranges** (servo τ/rate/deadband, DVL/IMU specs, thruster lag/power, compute latency) derived from twin sensitivity — still **NOT_CERTIFIED** hardware. |
| **Inputs** | Gates 1–8 PASS evidence; frozen production metrics; shadow/deadband `ASSUMED` ranges as sensitivity priors |
| **Outputs** | Sim RC tag + reproducibility manifest; component requirement range tables for EXTERNAL purchase/HIL; residual risk register (G1–G12 status) |
| **PASS criteria** | (a) Twin RC bit-reproducible under stated seeds/solvers; (b) requirement ranges cover parameters that were `ASSUMED`; (c) explicit **EXTERNAL-only** remaining work list; (d) no HW certification claim |
| **Evidence** | RC checklist, requirement ICD tables, risk register |
| **Provenance** | Ranges `DERIVED` from sim sensitivity; vendor compliance awaits EXTERNAL |
| **Dependencies** | Gate 8 PASS |
| **Blockers** | Shipping RC without MC; writing purchase specs that invent cert |

---

### EXTERNAL — Hardware / CAD / wet ID (plan terminus)

**ID:** `external_cad_procurement_hil_wet_system_id_gate`

| Field | Content |
|-------|---------|
| **Intent** | Everything that **cannot** be closed inside the digital twin. |
| **Remaining work (only)** | Hull/mechanical CAD; vendor purchase against Gate 9 ranges; bench / HIL / wet tests; real-data system ID (hydro, servo τ, sensors, propulsion) |
| **PASS criteria** | Outside this simulation plan; each EXTERNAL sub-activity defines its own cert authority |
| **Evidence** | CAD packages, POs, bench reports, wet-trial datasets, updated `IDENTIFIED` coeffs |
| **Provenance** | Upgrades `ASSUMED`→`IDENTIFIED` only with real data |
| **Dependencies** | Gate 9 sim RC |
| **Blockers** | Starting CAD/purchase before Gate 9 ranges; treating sim PASS as wet cert |

After EXTERNAL entry, this readiness plan’s **simulation** sequence is complete.

---

## 5. Cross-gate dependency sketch

```text
Gate1 coupled depth/γ plant ID
  → Gate2 structural decoupling + ref governor + AW
    → Gate3 closed-loop actuator realism
      → Gate4 water-relative current + feasibility guidance
        → Gate5 truth/measured/estimated multirate + EKF interface
          → Gate6 propulsion / power / compute realism
            → Gate7 mission manager + watchdog / fail-silent
              → Gate8 Monte Carlo distribution regression
                → Gate9 sim RC + procurement requirement ranges
                  → EXTERNAL: CAD / purchase / bench-HIL-wet / real-data ID
```

Open-loop actuator FO shadow + rudder deadband stub sit **before** Gate 3 as completed **simulation-only** antecedents; they do **not** replace Gate 3.

---

## 6. Prioritized next task

### `depth_gamma_coupled_plant_identification_gate`

**Why now:** Deadband stub explicitly returns to this gate. Vertical coupled-plant uncertainty (G5/G6) dominates realizability of any further depth/γ structure. Actuator open-loop sensitivity is documented; closed-loop actuator work waits until the vertical plant is identified/bounded and structural Gate 2 is designed against that model.

**Scope:** identification / bounding / provenance only for the coupled depth–γ plant.  
**Non-goals:** MATLAB in this doc task (already satisfied); production retune; rejected controller retries; `CODEX_VERTICAL_PLAN` edits; HW certification claims.

---

## 7. Artifact / claim hygiene

| Claim class | Status |
|-------------|--------|
| Visual pack PASS | Sim QA complete; production frozen; **NOT_CERTIFIED** |
| Actuator FO shadow PASS | Isolated open-loop; **NOT_CERTIFIED** |
| Rudder deadband stub PASS | Isolated open-loop; **not** CL limit-cycle; **NOT_CERTIFIED** |
| Frozen climb-FF / roll damp / mag-rate limits | Accepted production metrics; preserve |
| This plan | Doc-only realignment; no MATLAB; no code edits; CODEX untouched |

---

## 8. Cross-references

- Antecedent audit: `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md` (REALISM_GAP_AUDIT_001 + actuator FO append)  
- Antecedent stub: `suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.md` (ACTUATOR_RUDDER_DEADBAND_STUB_001)  
- Visual pack (frozen, not re-audited here): `suite_results/AUV_VISUAL_EVIDENCE_PACK.md`  
- **Do not edit:** `suite_results/CODEX_VERTICAL_PLAN.md`


---

## Append — DEPTH_GAMMA_COUPLED_PLANT_ID_001 (2026-08-08 01:45:23)

**Gate 1 result: PARTIAL** (not full PASS — U=1.5 level/climb only).

- Isolated ID from LOCAL_SS_LEVEL / LOCAL_SS_CLIMB / SS_VALIDATION; production frozen.
- Sagittal coupled plant documented (z,u,w,θ,q)×(δe,thrust) with θ_phys/α/γ maps; traj compare 4/4 PASS.
- Labels: A,B IDENTIFIED; θ_phys IMPLEMENTED; α/γ DERIVED; hydro coeffs TO_BE_IDENTIFIED; speed family TO_BE_IDENTIFIED.
- Artifacts: `suite_results/DEPTH_GAMMA_COUPLED_PLANT_ID.{md,mat,png}`.
- **Next exact task:** `depth_gamma_speed_scheduled_id_extension` for U={1.0,1.5,2.0}. CODEX_VERTICAL_PLAN untouched.

---

## Append — OPS_MISSION_INTERFACE_PLAN_001 (Gate 0 + Gate 7 prep, 2026-08-08)

**Class:** doc-only · **MATLAB/code:** NO · **CODEX_VERTICAL_PLAN:** untouched · **HW:** NOT_CERTIFIED

### Gate 0 — Disk / artifact preflight (NEW hygiene gate)

**ID:** `artifact_disk_preflight_gate`  
**Applies:** every task (including heavy MATLAB suites), before start.

| Rule | Requirement |
|------|-------------|
| Volume | Preflight free space on **`C:`** (WSL/host artifact volume as used by the suite) |
| Heavy-run start threshold | **≥ 3 GiB free** required to start; **preferred reserve ≥ 5 GiB** |
| Budget | Estimate artifact budget (MD/MAT/PNG) before run |
| Preserve | Keep **accepted** MD/MAT/PNG; do not delete frozen evidence |
| Dedup | **No duplicate raw MAT** for the same accepted run tag |
| Failed scratch | Cleanup **only** when failure artifacts are **explicitly attributable** to the current failed attempt |
| Forbidden | **No OS/admin cleanup** (no global temp wipes, no system disk “optimization”) |

**PASS:** preflight checklist recorded for the task; start aborted if free < 3 GiB on heavy runs.  
**Label:** process `INTERFACE_SPECIFIED` / ops hygiene; not a physics gate.

### Gate 7 — Interface prep pointer (does not PASS Gate 7)

**ICD created:** `suite_results/AUV_MISSION_COMPUTER_INTERFACE_REQUIREMENTS.md`

- Preserve deterministic path-following core and layers **Mission→Guidance→Navigation→Controller→Actuator**.
- Versioned logical messages: MissionCommand / WaypointSet / TrajectorySegment; StateEstimate / VehicleHealth / ActuatorStatus / Ack (SI, NED/BODY, `t_mono`, `seq`, validity/quality, heartbeat/stale, `schema_version`, integrity).
- Clocks: controller **40 Hz FIXED**; guidance **13.33 Hz DERIVED**; mission rate **TO_BE_IDENTIFIED**.
- Local mag/rate/safety authority **overrides mission**; stale mission → **fail-silent**; **no** auto-surface/accommodate without HIL.
- Truth / measured / estimated separation + digital-twin log keys specified; maturity split IMPLEMENTED vs INTERFACE_SPECIFIED vs NOT_IMPLEMENTED/TO_BE_IDENTIFIED.
- **Gate 7 still blocked** until Gates 3–6 envelopes exist; this append is ICD prep only (**NOT_IMPLEMENTED** mission manager).

### Next technical task (unchanged)

**`depth_gamma_speed_scheduled_id_extension`** for U={1.0, 1.5, 2.0}.  
No brand/purchase. No CODEX_VERTICAL_PLAN edits.

---

## Append — PLAN_REFINEMENT_001 (autonomous execution policy, 2026-08-08)

**Class:** doc-only · **MATLAB/code:** NO · **CODEX_VERTICAL_PLAN:** untouched · **HW:** NOT_CERTIFIED  
**Gates:** not rewritten — additive policy only.

**Created:** `suite_results/AUTONOMOUS_EXECUTION_POLICY.md`

- Gate 0: freeze frames/signs = freeze vehicle **coordinate-frame and sign convention** (BODY/NED axes, Euler/rates, depth z-down, actuator signs) with units + source reference — **not** git/status snapshot or task signing; cleanup only verified inactive `slprj/` / `*.slxc` / generated caches — never accepted evidence/source.
- Gate 2: bumpless mode/estimator transfer.
- Gate 3: control-allocation abstraction; actuator/ESC delay {0,15,30} ms+jitter (`ASSUMED` until bench ID).
- Gate 5: availability matrix (DVL bottom-lock loss, pressure disagreement, optional USBL outage); DR duration + sim safe-hold trigger; no auto-surface.
- Gate 6B: real-time contract (period/deadline/WCET/jitter/overrun/priority) + power-integrity/brownout; rates `TO_BE_IDENTIFIED` unless evidenced.
- Gate 7 FDIR: stale IMU/DVL/depth, mission heartbeat, actuator stuck/current, bus timeout, undervoltage/leak — sim only **NOT_CERTIFIED**.
- Gate 8 MC priors: CG/CB ±2 cm, buoyancy ±3%, sensor bias/delay/dropout, actuator lag/delay, battery/power (`ASSUMED`).
- Promotion: primary KPI ≥5%; secondary non-safety ≤2% worse only if absolute gates PASS; zero tolerance instability / hard mag-rate-sat-depth-collision-watchdog-FDIR.
- Pareto: tracking, actuator margin, energy, estimation, timing, safety.
- Cursor prompts: default **≤1600 characters**; only bounded complex EKF/interface tasks **≤2400 characters**; max 3 sources / 1 MATLAB call.

**Next technical task (unchanged):** `depth_gamma_speed_scheduled_id_extension` for U={1.0, 1.5, 2.0}.

---

## Append — PLAN_REFINEMENT_002 (doc clarification, 2026-08-08)

**Class:** doc-only · **MATLAB/code:** NO · **CODEX_VERTICAL_PLAN:** untouched · **HW:** NOT_CERTIFIED  
**Scope:** wording correction only — gate order, next task, and all other PLAN_REFINEMENT_001 rules preserved.

| Clarification | Correct meaning |
|---------------|-----------------|
| Freeze frames / signs | Freeze vehicle coordinate-frame and sign convention (BODY/NED axes, Euler/rates, depth z-down, actuator signs) with units and source reference. **Not** git/status snapshot or task signing. |
| Prompt limits | **Characters**, not tokens/words: default **≤1600 characters**; only bounded complex EKF/interface tasks **≤2400 characters**. |

**Corrected paths:** `suite_results/AUTONOMOUS_EXECUTION_POLICY.md`, `suite_results/AUV_REALIZATION_READINESS_PLAN.md`.

**Next technical task (unchanged):** `depth_gamma_speed_scheduled_id_extension` for U={1.0, 1.5, 2.0}.


---

## Append — DEPTH_GAMMA_SPEED_SCHEDULED_ID_001 (2026-08-08 02:08:18)

**Gate 1 result: PASS**.

- Isolated speed-scheduled sagittal ID at U_cmd={1.0,1.5,2.0}×{level,climb}; production frozen.
- Trim 6/6, jac 6/6, val 12/12; BODY U_cmd vs u* vs U_total recorded separately.
- Hydro CI: NOT_CLAIMED (TO_BE_IDENTIFIED). Artifacts: `suite_results/DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}`.
- **Next exact task:** `depth_gamma_structural_decoupling_governor_aw_gate`. CODEX_VERTICAL_PLAN untouched.


---

## Append — DEPTH_GAMMA_STRUCTURAL_GATE_001 (2026-08-08 02:38:40)

**Gate 2 result: PARTIAL**.

- Isolated structural candidate only; production frozen; no rejected-method retry.
- Primary KPI grid_mean_depth_MAE: 0.269528→0.232264 (13.83%).
- Blocker: `secondary_regression_max_28.25%`. Artifacts: `suite_results/DEPTH_GAMMA_STRUCTURAL_GATE.{md,mat,png}`.
- **Next exact task:** `depth_gamma_structural_gate_blocker_fix`. CODEX_VERTICAL_PLAN untouched.


---

## Append — DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX_001 (2026-08-08 03:02:03)

**Gate 2 attempt 2/3 result: PARTIAL**.

- Isolated blocker-fix only (delta_alpha + corrected α residual); production frozen; originals preserved.
- Old raw primary: 0.269528→0.232264 (13.83%); corrected B→C: 0.269528→0.233640 (13.32%).
- Blocker: `secondary_regression_max_20.18%`. Artifacts: `suite_results/DEPTH_GAMMA_STRUCTURAL_BLOCKER_FIX.{md,mat,png}`.
- **Next exact task:** `depth_gamma_structural_gate_blocker_fix_attempt3`. CODEX_VERTICAL_PLAN untouched.


---

## Append — DEPTH_GAMMA_STRUCTURAL_ATTEMPT3_001 (2026-08-08 03:23:53)

**Gate 2 attempt 3/3 result: FAIL**.

- Isolated blocker-fix only (delta_alpha + corrected α residual); production frozen; originals preserved.
- Old raw primary: 0.269528→0.232264 (13.83%); corrected B→C: 0.269528→0.454460 (-68.61%).
- Blocker: `primary_KPI_improve_-68.61%_lt_5.0%`. Artifacts: `suite_results/DEPTH_GAMMA_STRUCTURAL_ATTEMPT3.{md,mat,png}`.
- Method status: **CLOSED_AFTER_3_ATTEMPTS**; residual risk/waiver: Depth improvement remains structurally coupled to theta/gamma/alpha tracking; production stays frozen and any acceptance requires an explicit waiver.
- **Next exact task:** `closed_loop_actuator_realism_gate`; no attempt4. CODEX_VERTICAL_PLAN untouched.


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

## WATER_CURRENT_REFERENCE_GOVERNOR_001 — Gate 4B shadow candidate 1 (readiness log)

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

## WATER_CURRENT_ADMISSION_GOVERNOR_RERUN_001 — 4B syntax-fix validation exception beyond 3/3 (readiness log)

- Verdict: **FAIL** — Gate 4B syntax-fix validation exception FAIL; causal residual risk remains after authorized rerun.
- Coverage: 32 declared / **0 executed**; pass-through n/a, RESHAPE n/a, REFUSE n/a.
- Causal FAIL: route/current logical-mask orientation (1x32 & 32x1 → 32x32) aborted governor before any contract.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen; not promoted.
- Prior `WATER_CURRENT_ADMISSION_GOVERNOR.*` FAIL artifacts preserved; RERUN artifacts written.
- Next: Gate 5 prohibited absent explicit residual-risk waiver; currents ASSUMED and actuators NOT_CERTIFIED.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_RERUN2_001 — 4B mask-orientation validation exception beyond 3/3 (readiness log)

- Verdict: **FAIL** — Gate 4B mask-orientation validation exception FAIL; causal residual risk remains after authorized rerun2.
- Coverage: 32/32; pass-through 18, RESHAPE 3, REFUSE 11.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen.
- Production not promoted; refusal never counted as tracking success.
- Next: Gate 5 prohibited absent explicit residual-risk waiver; currents ASSUMED and actuators NOT_CERTIFIED.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## WATER_CURRENT_ADMISSION_GOVERNOR_RERUN2_001 — causal residual clarification (readiness log)

- Mask orientation validated; campaign executed 32/32 (18 PASS_THROUGH / 3 RESHAPE / 11 REFUSE).
- Verdict remains **FAIL** on `admitted_secondary_within_2pct` for RESHAPE rows 22-24 (depth_rms).
- Contact reduction gate passed; hard violations zero; refusals deterministic and not counted as tracking success.
- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen; Gate 5 prohibited without waiver.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## NAV_MULTIRATE_SENSOR_CHAIN_001 - Gate 5A isolated multirate sensor chain (readiness log)

- Verdict: **PASS** - sensor-chain contract completeness and visual QA only; **no navigation-performance claim**.
- Executed under the user-approved residual-risk waiver. Gate 4 remains **FAIL / shadow-only** and is **not promoted**.
- Coverage: 12/12 cases PASS (X / XZ / R10 at U=1.5, Vc in {0, [0 0.15 0]} NED, bottom-lock vs declared DVL outage; USBL optional ABSENT).
- TRUTH / MEASURED / ESTIMATED buses declared with units, frames, timestamp, sample time, sequence, validity, quality and stale age.
- ESTIMATED bus is **INVALID / UNAVAILABLE** by construction; no estimator was implemented and no truth is leaked into it.
- All 7 channel numerics are **ASSUMED**; upstream declares sensor noise / delay / IMU-DVL models NOT_IMPLEMENTED, so nothing is IDENTIFIED.
- Determinism: reverse-order replay and first/last reset sentinels bitwise identical (YES / YES).
- Production plant / controller / guidance frozen and never called; frozen-artifact fingerprints unchanged (YES).
- CUSUM / SIL and this chain remain **simulation-only**.
- Next: **Gate 5B multirate EKF + availability manager** on this frozen bus contract; sensor numerics must be identified before any accuracy claim.
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN.png`.
- `CODEX_VERTICAL_PLAN.md` untouched.


---

## NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION_001 - Gate 5A independent process-compliant validation (readiness log)

- Verdict: **PASS** - sensor-chain contract evidence re-established inside **one MATLAB process**; **no navigation-performance claim**.
- Recorded process noncompliance: the prior task `NAV_MULTIRATE_SENSOR_CHAIN_001` used **four MATLAB starts**, so its TECHNICAL_PASS was process-invalid and could not formalize the gate.
- Coverage: 12/12 frozen cases PASS, 16/16 declared gates PASS, 22/22 validation gates PASS.
- Deterministic parity with the prior artifact: max relative deviation 0 against a declared tolerance of 1e-12 across case order, channel schema, event and rate counts, outage transitions, frame and sign residuals, core error metrics, and the full decimated showcase series.
- Nothing was tuned: config numerics are identical to the prior record and the 12-case matrix was replicated verbatim from the frozen driver source, which was never executed, so the prior artifacts stayed untouched (YES).
- ESTIMATED bus remains **INVALID / UNAVAILABLE**, USBL remains **absent**, truth leakage is zero, and all sensor numerics remain **ASSUMED**.
- Frozen production fingerprints exact and `CODEX_VERTICAL_PLAN.md` untouched (YES). Artifacts total 0.62 MiB against a 300 MiB budget.
- Final PNG readability was validated by decoding the written file (2407 x 1629 px, ink fraction 0.261): YES.
- **Gate 5A PASS is formalized** on this compliant run. Next: **Gate 5B multirate EKF + availability manager** on the frozen bus contract; sensor numerics must be identified before any accuracy claim.
- Gate 4 waiver remains **OPEN / shadow-only** and is not promoted. CUSUM / SIL remain simulation-only.
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN_VALIDATION.png`.
- `CODEX_VERTICAL_PLAN.md` untouched.

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

- Readiness impact: the navigation ESTIMATED bus now has a defined, gated interface (timestamp,
  sequence, covariance, status, source mask, health) that a mission computer can consume, and a
  manager that provably refuses stale, duplicated, out-of-order, out-of-bounds, low-quality and
  non-finite packets. What is still missing before any realization claim: bench or sea-trial
  identified sensor numerics, sensor bias states, real delay compensation, and an absolute
  position fix source. Readiness is therefore unchanged at the accuracy level and advanced only
  at the interface-integrity level.


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

- Readiness impact: none at the capability level, and that is the honest reading. What
  improved is the trustworthiness of the evidence trail: the Gate 5B navigation interface
  record is now machine-verified at the artifact level, not just at the computation level,
  so a reviewer reading the report sees the same numbers the MAT holds. What is still
  missing before any realization claim is unchanged: bench or sea-trial identified sensor
  numerics, sensor bias states, real delay compensation, and an absolute position fix
  source.
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

- Readiness impact: the navigation interface now has a declared degraded-mode vocabulary
  and a proved-inert health output, which is a prerequisite for any mission-computer
  contract that has to react to aiding loss. What is still missing before any realization
  claim is unchanged and now more visible: identified sensor numerics, sensor bias states,
  real delay compensation, an accommodation policy with its own gates, and a USBL model
  with geometry rather than a fixed bias.
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

- Readiness impact: the availability vocabulary the mission-computer contract depends on
  now rests on evidence that was produced once, cleanly, and diffed against an earlier
  independent run rather than on a single unreproduced execution. What is still missing
  before any realization claim is unchanged: identified sensor numerics, sensor bias
  states, real delay compensation, an accommodation policy with its own gates, and a
  USBL model with geometry rather than a fixed bias.
- NEXT: GATE 6 (named because Gate 5C is now formalized, NOT attempted here): PROPULSION / POWER / COMPUTE budget and margin. Take the actuator commands and the navigation duty cycle this vertical already produces and close them against a declared thruster and control-surface power model, an energy budget over the mission profile, and a compute-load / latency budget for the estimator and controller rates. Numerics remain ASSUMED and every result remains NOT_CERTIFIED until bench data exists.


## PROPULSION_POWER_COMPUTE_BASELINE_001 — 2026-08-08 19:09:49 (readiness log)

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
- Readiness impact: realized-thrust actuator is now an isolated, parity-verified harness layer. Production `continuous_path_tracking.m` and `CODEX_VERTICAL_PLAN.md` are byte-identical before/after (SHA-256 recorded).
- Propulsion power/energy is reported as component-neutral **ranges** under a declared ASSUMED efficiency interval; no propeller/motor/battery part is selected, so nothing here advances hardware certification.
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\PROPULSION_POWER_COMPUTE_PARITY_FIX.png`.
- Production untouched; no gain, config or controller change.

<!-- REAL_TIME_POWER_INTEGRITY_CONTRACT_001 -->

## Gate 6B - REAL_TIME_POWER_INTEGRITY_CONTRACT (REAL_TIME_POWER_INTEGRITY_CONTRACT_001)

**Date:** 2026-08-08 - **Verdict:** **PASS** (13/13 declared hard gates) - **NOT_CERTIFIED** (simulation-only)

- Gate 6B real-time / power-integrity contract executed in isolation: period / relative deadline / **WCET budget (requirement, not measured)** / jitter bound / priority / ZOH-buffer / overrun action declared for 5 tasks.
- Controller **25 ms / 40 Hz FIXED**, guidance **75 ms / 13.33 Hz DERIVED**; mission, navigation and actuator-feedback rates remain **TO_BE_IDENTIFIED** (sim placeholders ASSUMED).
- Legacy `dt_controller = 0.0375` s reconciled as **ASSUMED evidence-only** (case `L37`, informational): not promoted, and **no production file was edited** (byte fingerprints verified pre/post).
- Cases: nominal, 15/30 ms transport delay+jitter, overload burst, brownout+recovery, mission-stale fail-silent, legacy 37.5 ms. Controller misses under overload = 200, all accounted; safe-hold engaged 3 ms after the 3rd consecutive miss.
- Brownout: V_min 0.803 pu (< 0.85 pu trigger), health -> safe-hold in 79 ms, recovery observed, **zero auto-surface / auto-accommodation**.
- Gate 7 unlocked as the next gate (mission manager / fail-silent simulation), still NOT_CERTIFIED.

---

## Append: GATE7_MISSION_MANAGER_FAIL_SILENT_SIM_001 (PARTIAL)

**Date:** 2026-08-09 00:50:23 - **Class:** Gate 7 isolated mission-manager / FDIR **simulation** - **MATLAB runs:** 1 - **production:** byte-identical - **CODEX_VERTICAL_PLAN:** untouched  
**Verdict:** **PARTIAL** (14/15 hard gates) - **Physical / hardware readiness: NOT_CERTIFIED**

- Isolated harness (`run_gate7_mission_manager_fail_silent_sim.m`) exercises MissionCommand / WaypointSet / TrajectorySegment / Ack with the full ICD header (`schema_version`, mission/segment id, `seq`, `t_mono`, valid/quality/integrity, NED/SI tags, validity horizon, heartbeat) over 16 frozen ASSUMED scenarios, each replayed twice.
- 9 monitors (leak, undervoltage, watchdog overrun, actuator stuck/current, IMU/DVL/depth stale, bus timeout, mission stale) with declared precedence, latching and 1.0 s recovery hysteresis; response ladder hold-last-safe -> constrain -> safe-hold.
- Detected 17/17 injected faults inside declared bounds, 0 false alarms, 0 missed, 0 Ack-code mismatches, 0 surface / 0 accommodation / 0 direct-actuator commands issued.
- Labels unchanged: mission/nav/actuator-feedback rates `TO_BE_IDENTIFIED`; all fault numbers `ASSUMED`; message contract `INTERFACE_SPECIFIED`; harness `IMPLEMENTED` (simulation); hardware `NOT_CERTIFIED`.
- Evidence: `suite_results/GATE7_MISSION_MANAGER_FAIL_SILENT_SIM.{md,mat,png}`.

**Gate 7 status:** simulation-scope PARTIAL. Gate 8 unlocks only on Gate 7 PASS; hardware terminus unchanged (EXTERNAL after Gate 9).

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

**Gate 7 status:** simulation-scope PASS under corrected acceptance semantics with attempt-1 raw behaviour proven identical. Gate 8 unlocks only on Gate 7 PASS; hardware terminus unchanged (EXTERNAL after Gate 9).

---

<!-- APPEND_MARKER:EMBEDDED_HANDOFF_TRANSITION_PLAN_001 -->

## Append: EMBEDDED_HANDOFF_TRANSITION_PLAN_001 — Gate 9B `embedded_transfer_readiness_audit` (POST-GATE9)

**Date:** 2026-08-09 · **Class:** doc-only plan refinement · **MATLAB:** NO · **model/controller/source edits:** NO · **CODEX_VERTICAL_PLAN:** untouched · **Physical / hardware readiness:** **NOT_CERTIFIED**

**Non-disruptive:** gate order Gate 8 → Gate 9 → EXTERNAL is unchanged; no PASS table above is rewritten; all frozen metrics and all rejected/never-retry architectures stay closed. **Immediate next technical task remains Gate 8** (`gate8_monte_carlo_independent_priors_campaign`).

### Placement

Gate 9B sits **after Gate 9 PASS** and **before / alongside** EXTERNAL entry. It is a **bounded audit**, not a re-validation campaign: it revisits **all production/runtime code and all accepted-or-failed evidence** without rerunning every research candidate. Rejected and CLOSED_AFTER_3_ATTEMPTS branches are read as **evidence**, never re-executed.

### Gate 9B — `embedded_transfer_readiness_audit`

| Field | Content |
|-------|---------|
| **Intent** | Determine whether the frozen digital-twin software is **transferable to an embedded target** as source/codegen input — independent of which target is later chosen. |
| **Inputs** | Gate 9 sim RC + reproducibility manifest; every accepted evidence MD/MAT; every FAIL / PARTIAL / CLOSED record with its residual risk; frozen frames/signs (Gate 0); ICD clocks (controller 40 Hz FIXED, guidance 13.33 Hz DERIVED, mission/nav/actuator-feedback `TO_BE_IDENTIFIED`); Gate 6B timing/power contract; Gate 7 FDIR ladder. |
| **Outputs** | Audit register (one row per finding, classified); **embedded handoff manifest** (below); unresolved-risk list carried into the target-specific phase. |
| **Non-goals** | MCU/board selection; vendor or purchase claims; performance retune; reopening frozen metrics; re-running research candidates; `CODEX_VERTICAL_PLAN` edits. |

### Audit checklist (each item yields findings, each finding classified)

| # | Check | Scope |
|---|-------|-------|
| A1 | **Reachable runtime inventory** | Enumerate code actually on the Mission→Guidance→Navigation→Controller→Actuator runtime path; separate it from analysis/plot/harness/research-only code |
| A2 | **Static / analyzer / compile checks** | Language-level checks, code analyzer warnings, clean parse/compile (or codegen-readiness check) of the reachable set |
| A3 | **Unresolved TODO / dead branches** | Open TODO/FIXME, unreachable branches, stubs that silently return, placeholder constants |
| A4 | **Forbidden rejected methods** | Confirm no rejected architecture (gamma INDI/PI/LADRC, depth PI/NDO, crab-current FF, simple polyline shaper) survives anywhere on the runtime path |
| A5 | **Frames / units / signs** | Every runtime signal carries BODY/NED frame, SI unit and sign per the Gate 0 freeze; no implicit deg/rad or z-up/z-down mixing |
| A6 | **Rates / ZOH / timestamps** | Every task rate declared; ZOH/hold semantics explicit; `t_mono`, `seq`, validity and stale-age present and monotonic on every produced signal |
| A7 | **Truth / measured / estimated separation** | No truth leakage into runtime; estimator consumes only MEASURED; TRUTH-only code is provably absent from the reachable set |
| A8 | **Bounds / NaN / overflow** | Saturation and range checks on every input and output; NaN/Inf guards; no unbounded integrators or divisions without guards |
| A9 | **Deterministic state / reset / bumpless** | Explicit state list; defined reset/init values; bitwise deterministic replay; bumpless mode and estimator transitions |
| A10 | **Embedded-unsupported constructs** | Dynamic allocation / resizing, file I/O, printing, globals, `persistent` state, cell/struct-array growth, string handling, `try/catch`, toolbox-only or non-codegen-supported calls |
| A11 | **Layer ownership** | Mission→Guidance→Navigation→Controller→Actuator responsibilities are single-owner; safety/mag/rate authority is local and overrides mission |
| A12 | **FDIR / watchdog authority** | Monitor set, precedence, latching, hysteresis and response ladder are implemented in the runtime layer that owns them; no auto-surface, no auto-accommodation |
| A13 | **Test / evidence / provenance links** | Every runtime element maps to at least one accepted evidence artifact and to its provenance label; orphan code and orphan evidence are both findings |

### Finding classification (mandatory, one class per finding)

| Class | Meaning | Blocks Gate 9B PASS |
|-------|---------|---------------------|
| **BLOCKER** | Software or safety defect that must be fixed before any transfer | **YES** |
| **TARGET_DEPENDENT** | Resolvable only once the exact MCU/board is known (types, memory, WCET, peripherals) | NO — deferred to the target-specific phase |
| **EXTERNAL_HIL** | Resolvable only with bench / HIL / real hardware evidence | NO — deferred to EXTERNAL |
| **COSMETIC** | Plot, prose, formatting or report-rendering defect | NO — **tracked, never silently closed** |

### PASS criteria

(a) Audit register complete: every checklist item A1–A13 has an explicit result and every finding is classified.
(b) **No unresolved software or safety BLOCKER.**
(c) **Embedded handoff manifest complete:** reachable runtime file/function list; signal ICD with frames/units/signs/ranges; task and rate table with ZOH semantics; state and reset table; parameter table with provenance labels; FDIR monitor/response table; evidence-to-code traceability map; open TARGET_DEPENDENT and EXTERNAL_HIL lists.
(d) Gate 9B PASS **does not upgrade any `NOT_CERTIFIED` hardware claim** and asserts nothing about timing, memory or numerics on a real target.

### Cosmetics rule (recorded)

Minor plot and prose cosmetic defects — e.g. the truncated §1.2 sentence and the panel-6 framing note in `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR.md` — are **COSMETIC**: they **do not block embedded transfer**, but they remain **tracked** in the audit register until repaired by a regenerating run.

### Terminus of this plan refinement

On Gate 9B PASS the plan **stops** at:

**`AWAIT_STM32_EXACT_PART_NUMBER`** — no MCU is selected, guessed, recommended or implied now. No purchase, brand or vendor claim is made. Work resumes only when the user supplies the **exact STM32 part number and board**.

### Target-specific realization phase 1 (defined, NOT started)

Unlocked only after the exact part/board is supplied:

toolchain & codegen strategy · clock tree / FPU / cache / MPU configuration · RTOS task map against the Gate 6B timing contract · HAL/LL and peripheral map · DMA and interrupt design · memory, stack, Flash/RAM and WCET budgets · numeric type selection (float/fixed) with range and precision evidence · comms, bootloader and logging · **SIL → PIL → HIL** evidence ladder. Everything in this phase stays **NOT_CERTIFIED** until HIL evidence exists.

### Sequence (unchanged except for the additive terminus)

```text
... → Gate8 Monte Carlo → Gate9 sim RC + procurement ranges
        → Gate9B embedded_transfer_readiness_audit (NEW, additive)
          → AWAIT_STM32_EXACT_PART_NUMBER (stop)
            → target-specific realization phase 1 (after user supplies exact part/board)
              → EXTERNAL: CAD / purchase / bench-HIL-wet / real-data ID
```

**Next technical task (unchanged):** `gate8_monte_carlo_independent_priors_campaign`.


<!-- APPEND_MARKER:GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001 -->

## Append: GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001 (readiness log)

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

## Append: GATE8_ACTUATOR_ORDER_SCAN_REPAIR_001 (readiness log)

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

## Append: GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001 (readiness log)

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

## Append: GATE8_R10_YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_RESUME_001 (readiness log)

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

## Append: GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_001 (readiness log)

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


<!-- APPEND_MARKER:GATE8_RESIDUAL_RISK_WAIVER_AND_GATE9_ENTRY_001 -->

## Append: GATE8_RESIDUAL_RISK_WAIVER_AND_GATE9_ENTRY_001 (readiness log)

**Date:** 2026-08-09 12:21:58 | **Class:** doc-only Gate 8 disposition under the plan's explicit-waiver rule | **MATLAB runs:** 0 | **Source/runtime edits:** NONE | **Repo scan:** NONE | **Production/CODEX_VERTICAL_PLAN:** untouched | **HW:** **NOT_CERTIFIED**

**Verdict: `WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT`. Gate 8 is NOT PASS and is not recorded as PASS anywhere.**

### 1. Authority for this disposition

§4 of this plan states: *"A gate may begin only when prior gates are PASS **or explicitly waived with a written residual risk**."* This append is that written waiver, invoked on the user's direction to close out the simulation-readiness phase and to stop spending attempts on a method line that has stopped producing new evidence. The waiver is **narrow**: it unlocks a **bounded Gate 9 assessment only** (§5). It does not upgrade any label, does not promote any candidate, does not reopen any frozen metric, and does not convert any simulation result into a certification claim.

### 2. Sources read (exactly 3, no repo scan)

| # | Path | Role |
|---|------|------|
| 1 | `suite_results/AUV_REALIZATION_READINESS_PLAN.md` | Gate order, waiver rule, Gate 8/9/9B definitions, full Gate 8 attempt history |
| 2 | `suite_results/AUTONOMOUS_EXECUTION_POLICY.md` | Promotion policy, Pareto vector, Gate 8 prior table, Gate 9B trigger rule |
| 3 | `suite_results/GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE.md` | Terminal C1 shadow probe, verdict `REJECT_C1_METHOD_CLOSED` |

All other figures quoted below are dereferenced **verbatim from source #1's own appended records**, not re-derived and not re-run. `CODEX_VERTICAL_PLAN.md` and every accepted MD/MAT/PNG artifact are preserved untouched.

### 3. Attempt history that justifies stopping (three failed MC closure attempts)

| # | Record | Date | Verdict | Failed hard gates / blocker |
|---|--------|------|---------|------------------------------|
| 1 | `GATE8_MONTE_CARLO_INDEPENDENT_PRIORS_001` | 2026-08-09 02:02:08 | **FAIL** | HG5, HG8, HG11, HG12, HG13; pass probability 0.4023, Wilson 95% CI [0.3441, 0.4634] over 256 runs |
| 2 | `GATE8_ACTUATOR_ORDER_SCAN_REPAIR_001` | 2026-08-09 04:30:20 | **FAIL** | HG5, HG11, HG12, HG13; D1 limiter ordering and D2 token audit REPAIRED, pass probability 0.8594, Wilson 95% CI [0.8115, 0.8967] |
| 3 | R10 rail-closure line: `..._RAIL_ORIGIN_LOCALISATION_001` (**BLOCKER**, no single origin) → `..._YAW_AUTHORITY_COORDINATED_SHADOW_SWEEP_RESUME_001` (**PARTIAL / SCALAR_METHOD_CLOSED**, PG7) → `..._GUIDANCE_SIGNAL_LOG_CLOSURE_001` (**CLOSED**) → `..._SHADOW_COURSE_REFERENCE_OFFSET_PROBE_001` (**REJECT_C1_METHOD_CLOSED**) | 2026-08-09 08:40:33 → 12:05:11 | **not closed** | HG5 (R10 rudder rail) survives every branch of the line |

**Closed methods (never retry, added to the plan's standing ban list):**

- `SCALAR_METHOD_CLOSED` — coordinated scalar rescaling of `(Kp_psi, Kd_psi) = (32 s, 13 s)` at fixed `Td = 0.406250 s`. No stored anchor `s ∈ {1, 0.260416667, 0.0535707175, 0.0174532925}` cleared PG1–PG9: the rail is removed only by trading it for cross-track error (s = 0.017453 gives rail dwell 0.0000 but cte max 0.89243 m against 0.21262 m at s = 1).
- `REJECT_C1_METHOD_CLOSED` — C1 shadow course reference `chi_raw_C1 = wrap(chi_f + 0.75*chi_los - 1.00*beta)`, i.e. `k_beta` 1.35 → 1.00. PRIMARY-1 passed (+100.0000% over-crab removal, 0.335019 → 0.000000 deg) but the conjunctive PRIMARY-2 failed at +0.3806% against a declared +5% floor.
- Pre-existing bans unchanged: gamma INDI / gamma PI / gamma LADRC · depth PI / depth NDO · crab-current FF · simple polyline shaper.

### 4. Residual-risk ledger carried into Gate 9 (all items OPEN)

| # | Residual risk | Evidence anchor | Label |
|---|---------------|-----------------|-------|
| R1 | **R10 production rudder rail unresolved.** Raw rudder demand peaks 466.6729 deg pre-limiter; plant input pins at the 25.0000 deg envelope for 0.2817 of the 30 s horizon (8.450 s, 12 intervals, longest 2.300 s, first at t = 1.825 s); magnitude-limiter dwell 0.8908, rate-limiter dwell 0.6917, peak realized slew 40.0000 deg/s. Origin is **multi-source**: 3 existing contributions each reach the envelope alone, earliest `S2_CTRL_TERM_P` (CONTROLLER) at t = 1.200 s. Integrator windup EXCLUDED_STRUCTURALLY; actuator dynamics NOT_PRESENT_IN_THIS_CELL. | `GATE8_R10_CLOSED_LOOP_RAIL_ORIGIN_LOCALISATION_001` | `IMPLEMENTED` measurement / **BLOCKER** unresolved |
| R2 | **CG / CB / buoyancy priors drawn but unsupported.** CG/CB ±2 cm per axis and buoyancy ±3% are drawn into the campaign vector and **never injected** — no shadow plant-parameter seam exists, so the recorded pass probability does not exercise them at all. HG11 open. | HG11, attempts 1 and 2 | `ASSUMED` prior, **UNSUPPORTED** |
| R3 | **Gate 7 16-case FDIR matrix not re-drawn inside MC.** The mission-manager / fail-silent matrix that passed 17/17 hard gates at `GATE7_FDIR_ACCEPTANCE_CRITERION_REPAIR_001` was never re-driven through the Monte Carlo loop under the same draws, so FDIR behaviour under distributed uncertainty is unevidenced. HG12 open. | HG12, attempts 1 and 2 | `NOT_EVALUATED` under MC |
| R4 | **X / XZ / R10 cell geometry is an `ASSUMED_RECONSTRUCTION`.** The 8 production cells (X/XZ at U = {1.0, 1.5, 2.0}, R10 at U = {1.5, 2.0}) were reconstructed, not bound to the frozen cell definitions. HG13 open. | HG13, attempts 1 and 2 | `ASSUMED_RECONSTRUCTION` |
| R5 | **Estimator streams NOT_IMPLEMENTED on the Gate 8 path.** The MC and R10 diagnostic loops run on truth `x`, `y`; the Gate 5B/5C EKF and availability manager were never inserted, so no navigation error propagates into any distribution reported for Gate 8. | Attempts 1–3; `GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_001` | `NOT_IMPLEMENTED` |
| R6 | **Power coverage PARTIAL.** Thrust-authority derate only; the brownout branch was never entered in any Monte Carlo run, so the Gate 6B power-integrity contract is not distributionally exercised. | Attempt 2 | `PARTIAL` |
| R7 | **Hardware readiness NOT_CERTIFIED.** No bench, no HIL, no wet data anywhere in this chain. Servo τ, deadband, hysteresis, thruster map, sensor σ/bias/delay and every mission/nav/actuator-feedback rate stay `TO_BE_IDENTIFIED`. | Whole chain | `NOT_CERTIFIED` / `TO_BE_IDENTIFIED` |
| R8 | Gate 4 waiver remains **OPEN / shadow-only**; Gate 1 hydro coefficients and speed family remain `TO_BE_IDENTIFIED`; Gate 3 closed as `CLOSED_AFTER_3_ATTEMPTS` with actuator values `ASSUMED`. | Prior appends | carried forward |

### 5. Why plant feasibility passed even though Gate 8 did not

The Gate 8 failures are **coverage and injection failures, not plant failures**. What is positively evidenced:

- **Exact nominal parity.** The hooks-off shadow path is bit-identical to unmodified `continuous_path_tracking.m` in 8/8 cells (attempt 1 parity 1, attempt 2 8/8 production and 8/8 hooks-off), and the R10 cell reproduces fingerprint `n=153600.s1=19094896.s2=2901292177` across unmodified production, hooks-off replica and instrumented replica.
- **Determinism.** Reverse-order replay and first/last reset sentinels reproduce bitwise in every attempt; 9 legacy-order A/B runs reproduced attempt-1 Monte Carlo hashes bit-for-bit, proving the D1 limiter position was the only behavioural change.
- **Envelope respected after the harness defect was repaired.** Maximum realized fin slew over all 256 runs is 40.000 deg/s against the declared 40 deg/s with a rate-violation population of **0** (attempt 1's 151/256 was manufactured by limiter ordering, not by the plant).
- **Closure of the signal chain to numerical noise.** Contribution sum vs logged raw command 1.137e-13 deg over 1200 samples; guidance observer closure, component sum, full recursion rebuild and `e_psi` identity all 0.000e+00 rad; the course-offset identity closes to 2.005e-15 rad; C1's production reconstruction worst residual 1.332e-15 rad against a 1e-9 gate.
- **Distributional behaviour is bounded, not divergent.** Pooled `cte_max` P5/P50/P95/worst = 0.110 / 0.342 / 0.565 / 0.826 m; pass probability rose 0.4023 → 0.8594 once the harness defect was removed, with **zero** hard violations and zero surface / automatic-accommodation / direct-actuator commands.

So the twin integrates, reproduces and stays inside its declared envelopes: **plant feasibility is evidenced**. What is missing is that three uncertainty families (R2, R3, R4) never entered the distribution, one actuator-authority rail (R1) is unresolved, and two subsystems (R5, R6) are absent or partial. That is exactly why the verdict is a waiver and **not** a PASS.

### 6. Why no banned or rejected method will be retried

- **Policy.** §4 of `AUTONOMOUS_EXECUTION_POLICY.md` forbids retrying closed dead-ends, and this plan's §3 lists them as never-retry. That ban is not relaxed by this waiver — it is reinforced.
- **Structural, not marginal, failure.** C1's rejection is an effect-size result with an explicit ratio: the over-crab term is worth 0.335019 deg of reference offset while the heading error it would have to move is 5.625664 deg, so even perfect removal can only shift the P demand by a few tenths of a per cent. Re-running the probe cannot change that ratio. The attribution identity shows the offset is **transferred** into the heading-error term, not eliminated.
- **The scalar family is exhausted at its own anchors.** Every stored anchor was reported, none dropped, no interpolation claimed; the rail trades against cross-track error monotonically across the anchors, so no intermediate scale can clear the conjunctive gate set.
- **Attempt budget.** Three closure attempts is the plan's standing limit (`CLOSED_AFTER_3_ATTEMPTS` precedent at Gates 2, 3 and 4B). A fourth attempt on the same evidence would be a guess presented as a finding, which the rail-origin record already refused to make.

### 7. What this waiver unlocks — bounded Gate 9 entry

**Unlocked (only this):** `GATE9_SIMULATION_RC_ASSESSMENT_001` — a **bounded simulation release-candidate assessment and evidence-range assembly**:

- assess reproducibility of the twin under stated seeds/solvers from **existing accepted evidence**;
- assemble **component requirement ranges** (servo τ / rate / deadband, DVL / IMU specs, thruster lag / power, compute latency) as **`DERIVED`-from-`ASSUMED`-parent ranges**, each range carrying its parent label and the residual-risk item that limits it;
- publish the residual-risk register R1–R8 as a first-class Gate 9 output.

**Explicitly still forbidden inside Gate 9:** new MATLAB campaigns to manufacture a PASS; any retry of a banned or closed method; any production gain, law, path, threshold, shaper or feedforward edit; any label upgrade; any `CODEX_VERTICAL_PLAN.md` edit; any vendor, brand, part or purchase claim.

**Gate 9 PASS remains impossible** while any hard safety gate is unresolved. Concretely, Gate 9 **cannot** be recorded PASS unless **every** hard safety gate passes — which today requires at minimum R1 resolved (R10 rudder rail), R2/R3/R4 closed (HG11 injection seam, HG12 FDIR matrix re-drawn under MC, HG13 geometry bound to frozen cells), and Gate 8 itself re-disposed on evidence rather than on this waiver. The expected honest outcome of `GATE9_SIMULATION_RC_ASSESSMENT_001` is therefore **PARTIAL or FAIL**, and that is acceptable: the task is to record the true evidence range, not to reach PASS.

### 8. Post-Gate-9 permission — fast whole-code embedded-readiness gap audit

After a Gate 9 disposition of **any** kind (PASS, PARTIAL or FAIL), the user-requested **fast whole-code embedded-readiness gap audit** is permitted. This is an additive relaxation of the Gate 9B trigger and nothing else:

| Item | Rule |
|------|------|
| Trigger | Gate 9 **disposition recorded** (not Gate 9 PASS). RC may be PARTIAL or FAIL. |
| Mode | **Read-only gap audit** over checklist A1–A13; evidence is read, never re-executed; closed dead-ends read as evidence only |
| Output | Audit register with every finding classified **BLOCKER** / **TARGET_DEPENDENT** / **EXTERNAL_HIL** / **COSMETIC**, plus the embedded handoff manifest |
| Gate 9B PASS | Unchanged and **not** relaxed: still requires no unresolved software/safety BLOCKER **and** a complete manifest. A gap audit run against a PARTIAL/FAIL RC will normally report BLOCKERs and therefore **not** PASS Gate 9B |
| Certification | Gate 9B never upgrades a `NOT_CERTIFIED` claim; no timing, memory or numeric claim on real silicon |

**STM32 adaptation remains FORBIDDEN.** The terminus `AWAIT_STM32_EXACT_PART_NUMBER` is hardened: target-specific work may begin only when **both** conditions hold — (a) the user supplies the **exact STM32 part number and board**, and (b) every unresolved blocker in the register (R1–R8 plus any Gate 9B BLOCKER) is **explicitly dispositioned** as fixed, waived-with-written-residual-risk, `TARGET_DEPENDENT` or `EXTERNAL_HIL`. No MCU is selected, guessed, recommended or implied now.

### 9. Label ledger for this append

| Label | Applies to |
|-------|-----------|
| `IMPLEMENTED` | The MC harness, the R10 diagnostics, the guidance signal log, the C1 shadow replay — as isolated simulation instruments only |
| `DERIVED` | This disposition; the attempt tally; the Gate 9 requirement ranges to be assembled next; the reasoning in §5 and §6 |
| `ASSUMED` | Every prior (CG/CB ±2 cm, buoyancy ±3%, sensor and actuator lag/delay/dropout, power envelope), every cell reconstruction, every threshold and dwell |
| `TO_BE_IDENTIFIED` | Hydro coefficients, speed family, servo τ / deadband / hysteresis, thruster map, sensor σ / bias / delay, mission / nav / actuator-feedback rates |
| `NOT_IMPLEMENTED` | Estimator streams on the Gate 8 path; plant-parameter injection seam; mission manager on the runtime path |
| `NOT_CERTIFIED` | All hardware, physical and timing-on-silicon claims, without exception |

### 10. Next exact task (exactly one)

**`GATE9_SIMULATION_RC_ASSESSMENT_001`** — bounded simulation RC assessment and evidence-range assembly under the residual-risk register R1–R8. No promotion, no label upgrade, no banned-method retry, no `CODEX_VERTICAL_PLAN.md` edit, no purchase or vendor claim. Gate 8 remains **`WAIVED_WITH_RESIDUAL_RISK_FOR_GATE9_ASSESSMENT`**, never PASS. Simulation is not hardware certification (**NOT_CERTIFIED**).


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

