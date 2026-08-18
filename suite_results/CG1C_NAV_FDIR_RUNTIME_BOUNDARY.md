# CG1C_NAV_FDIR_RUNTIME_BOUNDARY

**TASK_ID:** `CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001`  
**Track:** MATLAB→C++ pretarget — Nav / availability / FDIR **runtime boundary** (static)  
**Executed:** 2026-08-10 02:42 (local) / 2026-08-09T23:42:23Z  
**MATLAB invocations:** **0**  
**Mode:** bounded static runtime-boundary audit · **no** MATLAB · **no** algorithm/source edits · **no** executable codegen · **no** install/config · **no** repo rescan · **no** harness inspection  
**Hardware:** **NOT_CERTIFIED** · exact part/board ABSENT (carried)  
**Compiler:** MISSING (CG_PRE0 PARTIAL) — does **not** block this static audit  
**Preserved contracts (spec):** truth firewall · Joseph covariance update · deterministic admission/update ordering · accepted FDIR persistence latch · sensor/noise thresholds remain **ASSUMED / NOT_CERTIFIED**  
**`suite_results/CODEX_VERTICAL_PLAN.md`:** **UNTOUCHED — not read, not written**

**Claim limit:** These three files are **SIMULATION_ONLY / evidence libraries**. They do **not** DEPLOY as-is. They are **not** in the CG0 production runtime graph. This audit extracts reusable math and defines missing production units — it does **not** promote harness code to DEPLOY.

**Sources read (exactly three):**
| # | Path | Bytes | SHA-256 |
|---|------|------:|---------|
| 1 | `navigation_multirate_ekf_baseline.m` | 54872 | `e853ff6527bd1e5d00f94474bcf9cb808d582ecc981e77f56cbb446d5f8c5606` |
| 2 | `navigation_multirate_ekf_availability.m` | 72784 | `248d723a2141ecd067b8d768549febb471d3878636622504ada261d8516b1c20` |
| 3 | `isolated_online_rudder_residual_monitor.m` | 6475 | `c002a7dc1a8b70cfcebbd24e859acfacd467a25a819587651b718261ea610afb` |

Line citations use file-local line numbers. Baseline = Gate 5B file; availability = Gate 5C fork; rudder = B2 monitor.

---

## 1. Verdict

> ### CG1C: **PARTIAL**

Reusable **estimator / admission / Joseph-update / availability FSM / rudder B2 residual** math exists inside these files, but each file is a **batch host library** (string action dispatch, dynamic structs/cells, variable-length logs, NaN control-flow, `error`/`assert`, truth-side metrics). Lift-as-is to a deterministic STM32 runtime: **FAIL**. Static boundary audit completeness: **PASS**. Overall: **PARTIAL**.

| PASS condition | Required | Observed | Met? |
|---|---|---|---|
| Reusable-core map with line evidence | yes | §4 | YES |
| SIMULATION_ONLY / DEPLOY claim discipline | harness ≠ DEPLOY | explicit non-DEPLOY | YES |
| Fixed step API + Params/State/Input/Output/Health | yes | §6 (spec only) | YES (spec) |
| Zero CRITICAL/HIGH blockers for lift-as-is | 0 | many CRITICAL/HIGH (§5) | NO |
| Hardware / compiler resolved | n/a for static | NOT_CERTIFIED · compiler MISSING | n/a (deferred) |

**Do not claim DEPLOY.** CG0 already places Nav/EKF · FDIR outside the production call graph; this audit confirms that classification with runtime-boundary detail.

**Next exact task (exactly one):** `CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001`  
*(Prerequisite to `CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001`. Golden-equivalence sequencing is **not** yet safe: CG1A/CG1B APIs remain spec-only with no frozen golden vectors; implementing an explicit-state prototype without capture would break the parity gate.)*

---

## 2. Scope and non-goals

| In scope | Out of scope |
|----------|--------------|
| Exact three sources above | Repo rescan, harness `run_*`, plant, guidance, controller, Gate9B re-read |
| Classify reusable math vs SIMULATION_ONLY | Executable codegen, mex, compiler/tool install |
| Spec minimum production units + fixed APIs | Implementing those units or editing sources |
| Preserve truth firewall, Joseph form, order, FDIR latch | Certifying Q/R/NIS/thresholds (remain ASSUMED) |

---

## 3. File roles (as written)

| File | Self-declared role | Runtime graph |
|------|--------------------|---------------|
| `navigation_multirate_ekf_baseline.m` | Isolated Gate 5B library; “Simulation-only”; no globals/persistent; measured-bus only in `'run'` (`:7–49`) | **SIMULATION_ONLY** evidence |
| `navigation_multirate_ekf_availability.m` | Fork of 5B + optional USBL + health-only FSM (`:1–64`) | **SIMULATION_ONLY** evidence |
| `isolated_online_rudder_residual_monitor.m` | Causal stateful B2 monitor; sensor-only inputs (`:1–25`) | **SIMULATION_ONLY** evidence (closest API shape) |

---

## 4. Reusable-core map vs SIMULATION_ONLY

### 4.1 `navigation_multirate_ekf_baseline.m`

| Class | Items | Line evidence |
|-------|-------|---------------|
| **REUSABLE_MATH** (extract into production nav units) | 18-state layout NED/BODY; Q/R/P0/lat_scale constants (as Params, still ASSUMED); `sanitize` whitelist idea; `admit_reason` ordered tests; `commit`/`reject_iface`; IMU pair + aiding **order**; `propagate` (Φ,Qd,symmetrize); `measurement_model` depth/heading/INS/DVL; Joseph `IKH*P*IKH'+K*Rm*K'` + tilt reset `Gr`; quat helpers; `wrap_pi`; explicit init from admitted packets; est status OK/DEGRADED/DEAD_RECKONING from source window | `:78–168`, `:201–234`, `:783–824`, `:905–978`, `:507–523`, `:576–594`, `:1221–1281`, `:616–635` |
| **SIMULATION_ONLY** | Top-level `switch lower(action)`; `'gates'`/`'metrics'`/`'pack'`/`'injections'`; batch `N`-tick logs `L.*`; growing `innov`/`fused`/`reacq` via `end+1`; injection harness; `eig` PSD probe; counter/audit assembly; truth RMSE/`chi2_95`; `error(...)` unknown action / missing channel / non-fusible | `:58–69`, `:316–343`, `:491–498`, `:541–572`, `:610–612`, `:832–903`, `:980–1199`, `:71`, `:974` |
| **ARCHITECTURE_BLOCKER** (blocks STM32 lift of this file) | Dynamic `mgr.(chans{i})`, `innov.(nm)`, `reject.(reason)`; `cell` MC/plist/inj_result; `strcmp`/`find` channel index; variable `N`; NaN nominal state / null packets; `-Inf` last_ts; string reject reasons; `clear B` host idiom | `:255–305`, `:333–337`, `:437`, `:308–310`, `:777–780`, `:213` |

### 4.2 `navigation_multirate_ekf_availability.m`

| Class | Items | Line evidence |
|-------|-------|---------------|
| **REUSABLE_MATH** | Entire 5B core carried over; **USBL** `h=p_NED` update; `P0.p_abs` when abs channel present; **`availability_fsm`** hysteretic health-only machine (NOMINAL/DEGRADED/POSITION_AID_LOST/RECOVERING); freshness `tau` DERIVED from ICD period/stale; FSM after tick / pure of accept log | `:113–178`, `:1268–1275`, `:676–681`, `:737–748`, `:826–963` |
| **SIMULATION_ONLY** | Same action dispatch + metrics/gates/pack/injections; FSM transition log growth; dwell/sequence reporting; window-drift / lin_slope truth scoring; pack excludes health (ablation evidence) | `:74–87`, `:937–942`, `:1378–1520`, `:1602–1623` |
| **ARCHITECTURE_BLOCKER** | Same dynamic structs/cells/NaN/`eig` as 5B; plus dynamic FSM `trans` growth; string channel names in FSM input | `:328–384`, `:566–573`, `:702–704`, `:866–872` |
| **PRESERVE** | Health **status only** — no accommodation/gain/cov/reset (`:23–31`, `:225–228`); truth firewall (`:268–301`); USBL never required for init (`:120–121`) | |

### 4.3 `isolated_online_rudder_residual_monitor.m`

| Class | Items | Line evidence |
|-------|-------|---------------|
| **REUSABLE_MATH** | B2 residual `g_hat`, `r_B2`; warmup / `|δr|` gate; NaN→break persistence; **Np consecutive then LATCH until reset**; fixed cfg fields; forbidden-input list | `:119–161`, `:55–72`, `:4–9` |
| **NEAR_PRODUCTION_SHAPE** | Explicit `'init'|'update'|'reset'|'state'` already (`:12–15`, `:27–42`) — best of three for STM32 mapping | |
| **SIMULATION_ONLY / BLOCKER** | `string(op)` + `switch`; `assert` on missing fields; NaN residual/state sentinels; counters as debug; no Health bitfield / seq / stale on sample | `:27`, `:48–53`, `:106–109`, `:79–90`, `:123–136` |
| **PRESERVE** | Accepted persistence latch semantics (`:153–161`); sensor-only inputs; no applied-rudder / fault labels (`:8–9`, `:72`) | |

---

## 5. Focused traces (task-required)

### 5.1 Action / string dispatch

| Site | Evidence | Severity | Ownership |
|------|----------|----------|-----------|
| Baseline top dispatch | `:58–69` `switch lower(action)` + `error` | **CRITICAL** | **GATE_CG_N_ABI** — replace with typed `nav_*` / `availability_step` / `rudder_fdir_*` symbols |
| Availability + `'fsm'` | `:74–87` | **CRITICAL** | same |
| Rudder `string(op)` | `:27–41` | **HIGH** | **GATE_CG_F_ABI** — C symbols, no string ops |

### 5.2 Dynamic structs / fields / cells

| Pattern | Evidence | Severity |
|---------|----------|----------|
| Dynamic channel manager `mgr.(name)` | baseline `:304`, avail `:383` | **CRITICAL** |
| Dynamic reject counters `m.reject.(reason)` | `:301–303`, `:821–823` | **HIGH** |
| Dynamic innov / fused / reacq growth | baseline `:335–337`, `:491–498`, `:527–533` | **CRITICAL** (heap) |
| `cell` MC, plist, inj_result | `:261`, `:437`, `:356` | **CRITICAL** |
| Est bus `eb.(field)` + cell cov | `:729–750` | **HIGH** |

**Remediation:** fixed `N_CH` arrays; reject reason as `uint8` enum index; no `end+1` in step path.

### 5.3 Variable logs / matrix sizes

| Item | Evidence | Note |
|------|----------|------|
| Batch horizon `N = bus.N` | baseline `:247–248` | host batch; runtime is 1-step |
| Logs `NaN(3,N)`, `NaN(nx,N)` | `:317–331` | SIMULATION_ONLY |
| Covariance `P` fixed **18×18** | `:78`, `:310` | **OK** if `N_ERR=18` compile-time |
| Measurement dims 1 or 3 | `:945–972` | fix max `M_MAX=3` workspace |
| Rudder state scalars | monitor `:77–91` | **OK** fixed |

### 5.4 NaN / Inf sentinels

| Use | Evidence | Severity |
|-----|----------|----------|
| Uninitialized nominal `S` / `P` | baseline `:308–310` | **HIGH** — use `initialized` bool + zero/`P0` only after init |
| `null_packet` NaN/Inf | `:777–780` | **HIGH** — invalid flag, do not feed math |
| Pre-init `last_ts=-Inf` | `:291` | **MED** — use bool `have_ts` |
| Rudder residual NaN on invalid | `:123–136` | **HIGH** for control-flow; prefer `valid=false` + hold last finite |
| FSM age `NaN` pre-accept | avail `:866` | **MED** |

### 5.5 State / reset

| Unit | As written | Gap |
|------|------------|-----|
| EKF | Local `S,P,mgr,initialized` inside `'run'` batch; **no** exported init/reset/step | **CRITICAL** — need `nav_init/reset/propagate/update/output` |
| Availability FSM | Pure post-batch in `'run'` (`:737–748`); also callable `'fsm'` | Need incremental `availability_step` with dwell timers in State |
| Rudder | `local_init` / `local_reset` / `local_update` present (`:46–91`, `:105`) | Closest; still host asserts + string API |

### 5.6 Packet validity / timestamp / seq / stale

| Check | Order (deterministic) | Evidence |
|-------|----------------------|----------|
| is_new → present → valid/status==2 → finite → bounds → quality → stale_age → seq↑ → timestamp↑ | Fixed early-return order | baseline `:783–812`, avail `:1071–1102` |
| IMU pair `|tg-ta|≤tol_pair` | after both admit empty | `:386–387`, `:459–460` |
| Latency age `max(0,t_imu_last-pkt.ts)` into R | after init | `:482–483` |
| USBL absent → `channel_absent` before payload | avail `:1079–1080` | PRESERVE |
| Rudder sample | finite t/dr/r/u; no seq/stale | monitor `:119–121` | **add** optional seq/stale at Health layer |

**PRESERVE** admission order and never-fuse / optional-present policy.

### 5.7 Covariance operations

| Op | Evidence | Runtime note |
|----|----------|--------------|
| Propagate `P=ΦPΦ'+Qd` + symmetrize | `:927–937` | REUSABLE; fixed 18 |
| Joseph update + symmetrize | `:508–512`, `:585–588` | **PRESERVE** form |
| Attitude reset Jacobian `Gr` | `:520–523` | PRESERVE |
| `Sm\nu` / `(P H')/Sm` | `:487–508` | need fixed-size Cholesky/solve; no dynamic `\` sizing |
| `eig` min for gate | `:610–612` | **SIMULATION_ONLY** — not on target hot path |
| Output diag / Euler / body-water Jacobians | `:702–722` | on `nav_output` only |

### 5.8 Loops

| Loop | Evidence | Bound for STM32 |
|------|----------|-----------------|
| Tick `for k=1:N` | `:364` | replace with single step call |
| Prop substeps `ceil(dtp/dt_prop_sub)` | `:395–403` | **HIGH** — cap `N_SUB_MAX` |
| Aiding `for u=1:nup` fixed order | `:431` | `N_UP≤5` fixed |
| FSM `for k=k0:N` | avail `:889` | incremental step |
| Rudder | none beyond scalar | OK |

### 5.9 Error / assert paths

| Site | Evidence | Target policy |
|------|----------|---------------|
| Unknown action / channel / measurement | baseline `:71`, `:215`, `:974` | **no** `error` in step — return `Health.fault` |
| Rudder `assert` init/fields/G_nom | `:49–53`, `:106–109` | init-time check once; step returns fault bits |
| Host `clear B` | `:244` | N/A on target |

---

## 6. Minimum missing production units (specification only)

**Do not implement in this task.** Do **not** treat the three `.m` files as DEPLOY sources.

### 6.1 Entry points

```text
% Navigation (18-state error-state EKF) — extract from baseline/availability core
Params = nav_params_default()                 % ASSUMED Q/R/P0/gates; versioned
State  = nav_init(Params)                     % zeros + flags; NOT NaN control-flow
State  = nav_reset(State, Params, mode)       % COLD | HOLD_OUTPUT | REINIT_FROM_PACKETS
State  = nav_propagate(Params, State, ImuIn)  % paired gyro+accel only
State  = nav_update(Params, State, AidIn)     % one aiding channel enum + packet
[State, Output, Health] = nav_output(Params, State)

% Availability (health-only; must not write nav State.P / gains)
AState = availability_init(Params)
[AState, HealthAvail] = availability_step(Params, AState, AcceptIn)
% PRESERVE: status only — no accommodation (availability.m :23–31, :225–228)

% Rudder FDIR B2 (from monitor; preserve latch)
FParams = rudder_fdir_params_from_frozen(frozen)  % G_nom, thr, Np, … ASSUMED/NOT_CERTIFIED
FState  = rudder_fdir_init(FParams)
FState  = rudder_fdir_reset(FState)
[FState, FOut, FHealth] = rudder_fdir_step(FParams, FState, FInput)
```

### 6.2 Fixed dimensions / frames / units

| Symbol | Value | Frame / unit |
|--------|------:|--------------|
| `N_ERR` | **18** | dp,dv NED; dθ,dbg,dba BODY; dc NED |
| `N_CH` | **7** | imu_gyro, imu_accel, depth, heading, ins_vel, dvl, usbl (usbl optional) |
| `N_UP` | **5** | fixed update order (baseline `:93–94`; USBL fuse policy per Params) |
| `M_MAX` | **3** | max measurement dim |
| `N_SUB_MAX` | compile-time | cap prop substeps |
| Position / velocity / current | m, m/s | **NED**, z down |
| Attitude error / biases / rates | rad, rad/s, m/s² | **BODY** |
| DVL | m/s | **BODY** water-relative `R'(v−c)` |
| Depth | m | NED down (`p_D`) |
| Heading | rad | wrap innovation |
| Rudder δr, r, u | rad, rad/s, m/s | BODY / surge; residual dimensionless |
| g | 9.81 m/s² | NED down (**ASSUMED**) |

### 6.3 Records (minimum fields)

**`NavParams`** — `version`, `N_ERR`, channel enums, `g_ned`, `Q.*`, `R.*`, `lat_scale.*`, `P0.*` (+ `p_abs`), `q_min_frac`, `q_floor`, `nis_scale`, `dt_prop_max/sub`, `tol_pair/time`, `source_window_s`, `reacq_gap_s`, `never_fuse_mask`, `optional_mask`, `init_required_mask`. All sensor/noise thresholds **ASSUMED/NOT_CERTIFIED**.

**`NavState`** — `initialized` (bool), `p[3]`, `v[3]`, `q[4]`, `bg[3]`, `ba[3]`, `c[3]`, `P[18][18]`, `t_imu_last`, per-channel `last_seq`, `last_ts_valid`, `last_ts`, `last_accept_t`, `src_last_t[N_CH]`, `init_buf` (gyro/accel/depth/heading/ins), counters (fixed arrays), `est_seq`.

**`NavInput` (propagate)** — `gyro[3]`, `accel[3]`, `timestamp`, `t_rx`, `seq`, `valid`, `quality`, `stale_age`, `status`, `spec` (present, bounds, q_nom, stale_limit).

**`NavInput` (update)** — `channel` enum + same packet fields + `value[M_MAX]` + `dim`.

**`NavOutput`** — `pos_ned`, `vel_ned`, `vel_body_water`, `euler`, `gyro_bias`, `accel_bias`, `current_ned` (+ optional diag cov); `timestamp`, `sequence`, `source_mask`, `status` enum, `valid`.

**`Health`** — bitfield: `NONFINITE`, `ADMIT_*`, `INNOV_GATE`, `IMU_PAIR`, `NOT_INIT`, `COV_NONFINITE`, `SUBSTEP_CAP`; no string reasons on target.

**`AvailabilityState`** — `state` enum 0…4, dwell timers (`deg`,`loss`,`posok`,`allok`), `last_acc_t[N_CH]`, `tau_fresh[N_CH]`.

**`AcceptIn`** — `t`, `chan_accept[N_CH]`, `present[N_CH]`, `period_s`, `stale_limit_s`, `init_done`.

**`RudderFdirParams/State/Input/Output/Health`** — mirror monitor cfg/state/out; add `sample_valid`, optional `seq`; **PRESERVE** latch until `rudder_fdir_reset`.

### 6.4 Safe behaviour (required)

1. Truth firewall: production nav sees **MEASURED** whitelist only — never truth fields (`baseline :183–194`, `:242–245`).  
2. Joseph update + symmetrize + `Gr` reset preserved.  
3. Fixed channel update order; USBL policy via Params mask (5B never-fuse vs 5C optional).  
4. Invalid/stale/seq/timestamp failures admit-reject only; **no** throw.  
5. Before init: `Output.valid=false`, status INIT_WAIT/UNAVAILABLE.  
6. After init: loss of aiding degrades Health/availability — **does not** auto-reset filter (5C policy `:236–238`).  
7. Prop substeps clamped; excess → Health fault + hold last P/S policy (declare).  
8. Rudder: warmup/ungated/NaN breaks streak; alarm latches until reset (**PRESERVE**).  
9. Availability FSM: status only; never writes `P`/gains (**PRESERVE**).

### 6.5 Ownership (CG2 remediation)

| Gate ID | Owns | Notes |
|---------|------|-------|
| **GATE_CG_N_ABI** | nav_init/reset/propagate/update/output | Replace action strings; fixed records |
| **GATE_CG_N_MEM** | static buffers | Kill cells/`end+1`/batch `N` logs on target |
| **GATE_CG_N_ADMIT** | enum reject + ordered tests | Bitwise twin vs host admit_reason |
| **GATE_CG_N_COV** | Joseph + fixed solve | No `eig` on target |
| **GATE_CG_N_FIREWALL** | whitelist sanitize | Twin vs `'sanitize'` |
| **GATE_CG_A_FSM** | availability_step | Incremental; health-only |
| **GATE_CG_F_ABI** | rudder_fdir_* | Drop string/assert; keep latch |
| **GATE_CG_THRESH** | Params provenance | Remain ASSUMED/NOT_CERTIFIED — no silent “certify” |
| **GATE_CG2A_CTRL** | controller explicit state | **Blocked** until golden capture (next task) |

---

## 7. Blocker severity roll-up

| Severity | Count (approx) | Topics |
|----------|---------------:|--------|
| CRITICAL | 6 | Action/string dispatch (NA-01); dynamic mgr/innov/cells + growing logs (NA-02); no nav step API / batch-only (NA-03); variable-N heap logs (NA-04); error-throw control path (NA-05); unbounded prop substeps without cap (NA-06) |
| HIGH | 8 | NaN null/init sentinels; `strcmp`/`find` dispatch; `Sm\` dynamic solve host form; availability post-batch only; rudder `string`+`assert`; metrics/gates coupling risk if mis-wired; missing packet seq on rudder; est bus cell/string status |
| MED | 3 | `-Inf` timestamps; FSM age NaN; host `clear` |
| LOW / OK | — | Fixed 18-state algebra; owned `wrap_pi`/`quat_*`/`skew`; Joseph form; deterministic admit order; rudder scalar recurrence |

**Lift-as-is (all three files):** **FAIL**  
**Static boundary audit completeness:** **PASS**  
**Overall task verdict:** **PARTIAL**

---

## 8. Integrity

| File | Bytes | SHA-256 | State |
|------|------:|---------|-------|
| `navigation_multirate_ekf_baseline.m` | 54872 | `e853ff6527bd1e5d00f94474bcf9cb808d582ecc981e77f56cbb446d5f8c5606` | **UNTOUCHED** |
| `navigation_multirate_ekf_availability.m` | 72784 | `248d723a2141ecd067b8d768549febb471d3878636622504ada261d8516b1c20` | **UNTOUCHED** |
| `isolated_online_rudder_residual_monitor.m` | 6475 | `c002a7dc1a8b70cfcebbd24e859acfacd467a25a819587651b718261ea610afb` | **UNTOUCHED** |
| `suite_results/CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` | **UNTOUCHED — not read, not written** |

**Installs:** none. **Source edits:** none. **MATLAB runs:** 0. **Harness inspection:** none. **Repo rescan:** none.  
**Evidence writes:** this file · `CG_CODEGEN_STATUS.md` · compact appends to master plan, execution policy, pitch research log, state-space audit, realism log.

**Hardware:** **NOT_CERTIFIED**. Compiler/tool installation remains **deferred**.  
**Thresholds:** Q/R/NIS/admission/FSM dwell/B2 `G_nom`/`thr_B2` — **ASSUMED / NOT_CERTIFIED**.

---

*End of CG1C_NAV_FDIR_RUNTIME_BOUNDARY. Verdict: **PARTIAL**. Next: `CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001`.*
