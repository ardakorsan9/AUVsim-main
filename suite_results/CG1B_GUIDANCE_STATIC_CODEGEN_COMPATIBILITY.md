# CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY

**TASK_ID:** `CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001`  
**Track:** MATLAB→C++ pretarget — static MATLAB Coder compatibility (accepted guidance only)  
**Executed:** 2026-08-10 02:25 (local) / 2026-08-09T23:25:13Z  
**MATLAB invocations:** **0**  
**Mode:** bounded static audit · **no** MATLAB · **no** production/source algorithm edits · **no** executable codegen · **no** install/config · **no** repo rescan  
**Hardware:** **NOT_CERTIFIED** · exact part/board ABSENT (carried)  
**Compiler:** MISSING (CG_PRE0 PARTIAL) — does **not** block this static audit  
**Preserved:** accepted LOS / beta / Tur4A–Tur5B behaviour & frozen tuning (spec only) · rejected gamma-structural / depth-γ PI scaffolds / LADRC / INDI / crab-current-FF / simple-polyline candidates remain **closed** · `suite_results/CODEX_VERTICAL_PLAN.md` (**UNTOUCHED — not read, not written**)

**Sources read (exactly three):**
| # | Path | Bytes | SHA-256 |
|---|------|------:|---------|
| 1 | `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` |
| 2 | `suite_results/CG0_CODEGEN_BOUNDARY.md` | (CG0 evidence) | carried |
| 3 | `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md` | (Gate9B evidence) | carried |

All line citations below refer to `guidance_law.m` unless noted. Gate9B EG-/B- and CG0 IDs are cross-references only.

---

## 1. Verdict

> ### CG1B: **PARTIAL**

The accepted guidance unit is a **DEPLOY** entry (CG0 §3/§7) whose **scalar LOS / course / pitch / speed / r_ff algebra** is portable arithmetic (`atan2`, `hypot`, `mod`, clamps, fixed-α filters). It is **not** liftable as-is into MATLAB Coder / STM32 because of **target-architecture blockers**: 19 globals, 13 un-resettable `persistent`s, variable `nargin`, unbounded `path` + per-tick `zeros(n,1)`, `find`/`sum` search loops, toolbox `wrapToPi`, NaN control-flow sentinels, and host-owned `dt_guidance`. Static audit of this unit is complete; no critical ambiguity remains on guidance itself. Next bounded task is the missing Nav/FDIR runtime boundary (not in production graph — CG0 §5).

| PASS condition | Required | Observed | Met? |
|---|---|---|---|
| Core LOS/pitch/yaw math portable | yes | yes (`:132–273` after wrap ownership) | YES |
| Fixed types/sizes / fixed ABI as written | yes | no (variable path, globals, optional args, persistents) | NO |
| Zero CRITICAL/HIGH architecture blockers for lift-as-is | 0 | **4 CRITICAL** + **10 HIGH** (see §5–§7) | NO |
| Hardware / compiler resolved | n/a for static | NOT_CERTIFIED · compiler MISSING | n/a (deferred) |

**Next exact task (exactly one):** `CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001`

---

## 2. Scope and non-goals

| In scope | Out of scope |
|----------|--------------|
| Accepted production `guidance_law.m` (+ colocated local helpers `:283–394`) | `controller_law.m`, harness, plant, `run_*`, ARCHIVE `guidance_law_*` |
| Static MATLAB Coder compatibility classification | Executable `codegen`, mex, compiler install |
| Spec of future fixed-signature init/reset/step + records | Implementing that API or refactoring production |
| Preserve accepted LOS / β / Tur4A–Tur5B numerics | Gain retune; reopen rejected γ-structural / LADRC / INDI / crab-current-FF / polyline methods |

**CG0 role reminder:** DEPLOY entry, risk HIGH (`CG0_CODEGEN_BOUNDARY.md` §3, §7). Helpers are DEPLOY candidates but WCET-unbounded (Gate9B M-04/M-05, EG-77).

**Closed (do not reopen):** ARCHIVE_REJECTED guidance candidates (`guidance_law_depth_gamma_structural*`, depth-I ablation / NDO / depth-to-gamma / PI–LADRC–INDI scaffolds, crab-current FF, water-current governors as guidance replacements, simple-polyline substitutes). Production `K_gamma` / sideslip `k_beta` / Tur5A zdot terms in **this** file remain the accepted frozen behaviour — not those rejected forks.

---

## 3. Full I/O / state / dependency trace

### 3.1 Function signature (variable arity)

```
[yaw_ref, pitch_ref, u_ref, next_progress_index, r_ff, pitch_ref_dot] = guidance_law(
    current_position, path, progress_index, u_body, v_body, U_h, zdot_inertial, theta_phys)
```

| Port | Lines | Role | Unit / frame (comment-derived) | Codegen note |
|------|------:|------|--------------------------------|--------------|
| `current_position` | 1,68+ | vehicle position | m, **NED** (implied; undeclared) | required `1×3` |
| `path` | 1,54+ | waypoint table | m NED; **`n×3` unbounded** | **ABI / memory blocker** |
| `progress_index` | 1,38–40,276–278 | legacy integer progress | 1-based index; default 1 | optional → ABI hazard |
| `u_body` | 1,41,168 | BODY surge | m/s; default **1.0** if absent | optional; plausible≠safe (EG-67) |
| `v_body` | 1,42,168 | BODY sway | m/s; default 0 | optional |
| `U_h` | 1,4–5,43–45,52 | inertial horizontal speed | m/s NED horiz.; default `hypot(u,v)` | optional |
| `zdot_inertial` | 1,6–7,46–48 | inertial vertical vel. | m/s NED down-ish; default 0 | optional; Tur5A |
| `theta_phys` | 1,8,49–51,214 | physical pitch | rad; default 0 | optional; Tur5B α |
| `yaw_ref` | 1,263 | heading reference | rad, **unwrapped continuous** | always |
| `pitch_ref` | 1,264 | pitch reference | rad, rate-limited | always |
| `u_ref` | 1,150–157 | speed schedule | m/s | always |
| `next_progress_index` | 1,275–278 | suite/legacy index | integer in `[1,n]` | always |
| `r_ff` | 1,267–270 | yaw-rate FF | rad/s = `U_h*κ` (Tur4A) | always |
| `pitch_ref_dot` | 1,2,265 | pitch-ref rate | rad/s | always |

**No** debug out-arg (diagnostics via globals only — EG-84 contrast to controller).

### 3.2 Path representation

| Aspect | Evidence | Issue |
|--------|----------|-------|
| Shape | `n = size(path,1)` (`:54`); rows are waypoints; columns used as `path(i,:)` 3-vectors (`:287,332,369`) | implied `n×3` double; **no `MAX_WAYPOINTS`** (EG-19) |
| Closed-loop detect | `norm(path(1,:)-path(end,:)) < 0.25` (`:63`) | geometry heuristic; capacity still unbounded |
| Arc-length | `path_arclength` builds `s_nodes = zeros(n,1)` **every call** (`:62,285`) | per-tick heap / variable size (EG-19, EG-77) |
| Progress state | continuous `s_prog` [m] in `persistent` (`:21,70–105`); integer `progress_index` is display/legacy only (`:275–278`) | dual progress models; segment ownership implicit |
| Segment ownership | `sample_path` / `project_interval` use `find(s_nodes <= s, 1, 'last')` (`:324–327,361–362`) | empty-`find` repair; variable-size intermediates (EG-28) |

### 3.3 Globals — parameters (read; some self-defaulted)

| Global | Decl | Default / use | Guarded? | Severity if empty / wrong |
|--------|-----:|---------------|----------|---------------------------|
| `lookahead_distance` | 13 | `L = max(lookahead_distance, 1.0)` (`:64`) | **NO** `isempty` | **CRITICAL** — empty → empty `L` / empty schedule |
| `desired_speed` | 13 | `u_ref` base (`:56,150–156`) | **NO** | **CRITICAL** |
| `pitch_ref_max` | 14,27 | default `deg2rad(25)` (`:229,261`) | yes | HIGH (self-mutates config) |
| `pitch_ref_rate_max` | 14,28 | default `deg2rad(5)` (`:258`) | yes | HIGH |
| `dt_guidance` | 15,32–36 | integrator / rate-limit dt | yes; may copy `dt_controller` | HIGH (B11) |
| `dt_controller` | 15,33–34 | fallback if `dt_guidance` empty | yes | HIGH |
| `K_zdot` | 17,29 | Tur5A zdot gain (`:203`) | yes → 0 | MED (identity off) |
| `K_gamma` | 17,30 | Tur5B γ FB (`:218,224`) | yes → 0 | MED |
| `enable_alpha_hat` | 17,31 | AoA path (`:219`) | yes → false | MED |

### 3.4 Globals — diagnostics / side-channel ABI (write)

| Global | Lines | Content |
|--------|------:|---------|
| `last_guidance_U_h`, `last_guidance_kappa`, `last_r_ff` | 16,271–273 | Tur4A observability |
| `last_gamma_actual`, `last_gamma_path`, `last_alpha_eff`, `last_e_gamma` | 18,231–234 | Tur5B |
| `last_e_z`, `last_e_zdot`, `last_zdot_inertial`, `last_alpha_hat` | 19,235–238 | depth / α logs |

**Codegen:** must **not** be STM32 ABI; fold into fixed `Debug` record (Gate9B EG-10, EG-73).

### 3.5 Persistent state (no reset API)

| State | Decl / cold | Use | Reset? |
|-------|-------------|-----|--------|
| `initialized` | 21–22,68–80 | cold-start gate | **never** cleared (EG-01) |
| `s_prog` | 21,70–105 | monotonic arc progress [m] | **never** |
| `yaw_cont` | 21,71,177–180 | continuous unwrap heading | **never**; seeded **NaN** |
| `pitch_f`, `pitch_out` | 21,72,239–260 | filtered / rate-limited pitch | **never**; `pitch_f` seeded **NaN** |
| `z_e_f`, `z_e_i` | 21,23,73–74,147,194–195 | depth P filter + I (±25) | **never** |
| `zd_e_f` | 21,24,75,202 | zdot error filter | **never** |
| `eg_f` | 21,25,76,213 | e_γ filter | **never** |
| `alpha_hat` | 21,26,77,222–226 | AoA LPF | **never** |
| `kappa_f` | 21,78,134 | curvature LPF | **never** |
| `chi_f` | 21,79,161–164 | course filter; seeded **NaN** | **never** |
| `yaw_out` | 21,248–254 | soft yaw output | **never** (`isempty` once) |

Mission re-arm in same process keeps prior `s_prog`, `z_e_i`, unwraps, α → **CRITICAL architecture** (B01).

### 3.6 Local helpers (same file)

| Helper | Lines | Complexity | Codegen issue |
|--------|------:|------------|---------------|
| `path_arclength` | 283–293 | O(n) + `zeros(n,1)` | dynamic alloc every tick |
| `wrap_arc` | 295–297 | O(1) `mod` | **directly OK** |
| `project_on_path` | 299–318 | may split closed window | calls interval search |
| `project_interval` | 320–351 | O(segments in window); `find` | empty-find; variable `i0:i1` (EG-28, EG-78) |
| `sample_path` | 353–379 | O(find) + lerp | empty-find |
| `path_curvature_at` | 381–394 | 2× `sample_path` | OK if path bounded/cached |

No recursion (EG-81 positive). Call depth ≤ 3.

### 3.7 Search / index loops

| Site | Lines | Pattern |
|------|------:|---------|
| Arc-length build | 286–288 | `for i = 2:n` |
| Projection window | 331–350 | `for i = i0:i1` with early `continue` |
| Segment locate | 324–325,361 | `find(...,1,'last'|'first')` + `isempty` repair |
| Legacy index | 276 | `sum(s_nodes <= s_prog)` — another O(n) |

Window size grows with `L`: `s_hi = s_prog + max(3.0, 2.5*L)` (`:85`) → WCET data-dependent (EG-77/78).

### 3.8 External / toolbox / language dependencies

| Symbol | Line(s) | Class | Notes |
|--------|---------|-------|-------|
| `wrapToPi` | 164,173,180,212 | **toolbox / non-base** | EG-26; must own local wrap |
| `deg2rad` | 27–28,204,223,229,246,258,261,270 | base; fixed-type OK | prefer const-fold |
| `hypot` | 44,199,209 | base | **directly OK** |
| `atan2` | 160,166,168,171,184–186,210–211,392 | base | **directly OK** |
| `norm`,`dot`,`mod`,`max`,`min`,`abs` | many | base | **directly OK** |
| `isnan` / `nan` | 71–73,79,161,177,239 | FP sentinel control flow | **architecture blocker** (EG-34) |
| `find` | 324–325,361 | restricted / variable size | **architecture blocker** (EG-28) |
| `sum` logical | 276 | O(n) | replace with cached segment index |
| `size`,`zeros`,`isempty`,`nargin` | 22–51,54,285,324–327 | host patterns | Params/State/fixed ABI |
| `global` / `persistent` | 13–21 | non-reentrant ABI | **architecture blocker** |

**No** `ode45`, `fprintf`, `try/catch`, `interp1`, random, file I/O, or Handle Graphics in this unit.

---

## 4. Compatibility classification (guidance only)

### 4.1 Directly codegen-compatible (with scalar double policy + owned wrap)

| Item | Evidence | Note |
|------|----------|------|
| Closed/open path flags & near-end | `:63,108` | after fixed path buffer |
| Cross-track `y_e`, filtered `z_e_f` | `:138–147` | |
| Speed schedule + near-end slowdown | `:149–157` | needs finite `desired_speed` |
| Course filter + LOS + β compensation | `:159–174` | after `wrapToPi` → local |
| Continuous yaw unwrap + soft `yaw_out` | `:176–180,246–254` | bound accumulator in State policy |
| Pitch geometry blend + depth P+I + Tur5A/B | `:183–228` | preserve signs `:192–201` |
| Pitch mag/rate limits + `pitch_ref_dot` | `:229–265` | |
| Tur4A `r_ff = U_h * kappa_f` clamp | `:267–270` | |
| `wrap_arc` | `:295–297` | |
| Pure sample/lerp math (fixed indices) | `:363–378` | after replacing `find` |

### 4.2 Codegen-compatible only with fixed types / sizes

| Item | Evidence | Required fix (spec) |
|------|----------|---------------------|
| All scalar I/O | `:1` | fixed `1×1` / `1×3` doubles |
| `path` | `:54` | `coder.typeof` **or** fixed `MAX_PATH_POINTS×3` + `n_path` |
| `s_nodes` | `:62,285` | static buffer, rebuild only on path version change |
| Projection window loops | `:331–350` | bounded `MAX_SEG_SEARCH` from Params |
| `deg2rad` literals | listed | frozen radian constants |
| Filter alphas | `:134,147,164,202,213,222,226,243,252` | either freeze dt + alphas **or** re-derive from physical τ (EG-46/47) |
| `next_progress_index` | `:276–278` | computed from cached segment id, not `sum` |

### 4.3 Target-architecture blockers (host-side; not cured by MCU choice)

| ID | Item | Lines | Maps to |
|----|------|------:|---------|
| GA-01 | No `init`/`reset`/`step`; `persistent` survives missions | 21–22,68–80 | B01 / EG-01 |
| GA-02 | Globals for params; self-default writes | 13–19,27–35 | B04 / EG-11–12 |
| GA-03 | Variable `nargin` defaults (plausible, not safe) | 38–51 | EG-67 |
| GA-04 | Unbounded `path` + per-tick `zeros(n,1)` | 54,62,285 | B05 / EG-19 |
| GA-05 | `find` / `sum` / O(n) helpers every tick | 276,283–351,361 | B05/B07 / EG-28,77 |
| GA-06 | `wrapToPi` non-owned primitive | 164,173,180,212 | B07 / EG-26 |
| GA-07 | NaN used as init sentinel (`yaw_cont`,`pitch_f`,`chi_f`) | 71–73,79,161,177,239 | B08 / EG-34 |
| GA-08 | No input finite/range guards; empty `lookahead`/`desired_speed` | 1,13,54–157 | B10 / EG-38–39 |
| GA-09 | `dt` from global, not step arg; alphas baked for one rate | 32–36,134,… | B11 / EG-43,46 |
| GA-10 | Diagnostic globals as second ABI; no Debug out | 16–19,231–238 | B14 / EG-10,73,84 |
| GA-11 | Unbounded heading accumulator `yaw_cont`/`yaw_out` | 180,254,263 | B09 / EG-35 |
| GA-12 | Depth I without AW vs cascaded pitch sats | 194–195,203–204,229,256–261 | B12 / EG-55 |
| GA-13 | Silent anomaly absorb (backward snap) w/o fault bit | 95–105 | B13 / EG-62 |
| GA-14 | No path version / validity / seq / timestamp on mission path | 1,54 | B03/B14 / EG-07,72 |

### 4.4 Hardware-dependent (deferred; do not block CG1C static/boundary work)

| Item | Lines | Note |
|------|------:|------|
| Native f64 vs f32 / soft-float | whole file | EG-33 |
| Absolute WCET vs `n`, window, FPU | helpers | EG-77,83; needs part |
| Stack high-water (depth ≤3 favourable) | helpers | EG-81 |
| Compiler / STM32 packs | — | CG_PRE0 MISSING; install deferred |
| Estimator-fed β / γ performance | `:168–222` | EG-64–65; Nav layer absent (CG0 §5) |

---

## 5. Focused assessments (task-required)

| Topic | Finding | Severity | Remediation gate |
|-------|---------|----------|------------------|
| **I/O & optional arity** | 8-arg variable `nargin`; defaults `u_body=1.0`, `zdot=0`, `theta_phys=0` (`:38–51`). Six bare outputs; no validity. | **HIGH** | **GATE_CG_G_ABI:** fixed `guidance_step(Params,State,Input)→(State,Output[,Debug])`; no `nargin` behaviour. |
| **Path representation** | Unbounded `n×3`; closed if ends &lt;0.25 m (`:54,63`). | **CRITICAL** | **GATE_CG_G_PATH:** `MAX_PATH_POINTS` (compile-time), `n_path`, `path_version`, `is_closed` flag (mission-owned, not re-inferred every tick unless intentional). |
| **Globals (params)** | `:13–17`; self-writes `:27–35`. Unguarded `lookahead_distance`,`desired_speed`. | **CRITICAL** | **GATE_CG_G_PARAMS:** versioned `Params` in; init owns defaults once; **no** global R/W. |
| **Globals (diagnostics)** | `:16–19,:231–238`. | **HIGH** | **GATE_CG_G_TELEM:** fixed `Debug` record; strip from target hot path. |
| **`persistent` / reset** | 13 states `:21`; cold NaNs `:71–79`; never cleared. | **CRITICAL** | **GATE_CG_G_STATE:** explicit `State`; `guidance_init`/`guidance_reset`; boolean init flags **only**. |
| **`wrapToPi`** | Four calls `:164,173,180,212`. Not defined here. | **HIGH** | **GATE_CG_WRAP:** same owned `wrap_pi_local` as controller (CG1A); golden parity vs host. |
| **`find` / search loops** | `:324–327,361–362,331–350,276`. | **HIGH** | **GATE_CG_G_SEG:** deterministic segment index in State; binary/linear scan with **fixed max iterations**; no empty dynamic arrays. |
| **Dynamic sizing** | `zeros(n,1)` per tick `:285`. | **CRITICAL** | **GATE_CG_G_MEM:** static `s_nodes[MAX]`; rebuild on `path_version` change only. |
| **NaN sentinels** | `:71–73,79,161,177,239`. | **HIGH** | **GATE_CG_G_INIT:** `initialized` / per-channel boolean; never NaN as control flow. |
| **Angle-wrap ownership** | Continuous unwrap in guidance (`:176–180,254`); controller re-wraps error (EG-35). Dual ownership undocumented in ABI. | **HIGH** | **GATE_CG_G_ANGLE:** document: guidance may emit unwrapped `yaw_ref` **or** wrap to (−π,π] + turn count; controller owns measurement wrap; twin contract freezes one. Prefer bounded `yaw_ref` + `yaw_ref_unwrapped` debug. |
| **Segment / progress ownership** | Continuous `s_prog` owns geometry; `progress_index` monotonic display (`:275–278`). | **HIGH** | **GATE_CG_G_PROG:** State owns `s_prog` + `i_seg`; mission may seed; harness must not dual-write. |
| **Finite / range guards** | None on position/path/speeds (`:1`). Depth I ±25 only (`:195`). | **CRITICAL** | **GATE_CG_G_VALID:** reject non-finite; path `n_path∈[2,MAX]`; emit safe hold + fault bits; no integrate on invalid. |
| **Sample time / filters** | `dt_nom` global `:32–36`; fixed alphas EG-46. | **HIGH** | **GATE_CG_G_DT:** `Input.dt` sole rate; freeze alphas with frozen dt **or** τ-scheduled (preserve bandwidth at accepted rate). |
| **Depth I anti-windup** | I then three saturations (`:194–261`). | **HIGH** (logic; not syntax) | **GATE_CG_G_AW:** back-calc after pitch mag/rate sat; preserve ±25 unless Params absolute cap supersedes. |
| **`deg2rad` / `hypot` / `atan2`/`mod`** | listed | **OK** / LOW const-fold | **GATE_CG_CONST** (shared with CG1A). |
| **WCET** | O(n) every tick EG-77 | **HIGH** + HW | bound n + cache; measure on target later |

**Frozen tuning / behaviour (must preserve numerically after API wrap):**  
`L` floor 1.0 (`:64`); closed threshold 0.25 m (`:63`); forward window `max(3,2.5*L)` / back 0.15 (`:84–85`); mono blend −0.05 m (`:100,103`); near_end `s_total-0.3` (`:108`); κ filter 0.96/0.04 (`:134`); κ floor 1e-4 (`:135`); `z_e` 0.93/0.07 (`:147`); speed `R/(R+2.5)` with floors (`:150–156`); course α 0.28 (`:164`); LOS `atan2(-y_e,L+0.6)` (`:166`); **`k_beta=1.35`** (`:169`); LOS mix 0.75 (`:173`); pitch geom 0.65/0.35 (`:190`); depth **P=0.050, I=0.006**, I clamp ±25 (`:194–203`); pitch_corr ±9° (`:204`); γ/α filters 0.85/0.15 & 0.98/0.02, α ±8° (`:213–223`); pitch filter 0.90/0.10 (`:243`); yaw soft 0.35 & 40°/s (`:246–253`); `r_ff` ±40°/s (`:270`); defaults `pitch_ref_max=25°`, rate 5°/s (`:27–28`).  
Tur4A: `r_ff=U_h*κ` (not `1.15*u_ref*κ`). Tur5A/B equations as commented `:196–228`.

---

## 6. Future fixed-signature API (specification only — **do not implement yet**)

### 6.1 Entry points

```text
Params  = guidance_params_default()            % host/build-time; frozen tuning
State   = guidance_init(Params)                % zeros; booleans; no NaN sentinels
State   = guidance_reset(State, Params, mode)  % COLD | HOLD_REFS | SEED_PATH
[State, Output] = guidance_step(Params, State, Input)
% Optional host twin:
[State, Output, Debug] = guidance_step(Params, State, Input)
```

Ownership:
- **Init/reset:** mission / supervisor (not plant harness). Step **never** invents Params defaults or writes globals.
- **Step:** one guidance period; `Input.dt` sole sample-time source (replaces `dt_guidance` global).
- **Path capacity:** `Params.MAX_PATH_POINTS` compile-time; `Input.n_path` runtime `2…MAX`.
- **Segment ownership:** `State.s_prog`, `State.i_seg` updated only inside `guidance_step` / `guidance_reset(SEED_PATH)`.
- **Angle-wrap ownership:** freeze per **GATE_CG_G_ANGLE**; document in Params.schema.
- **No** `persistent`, **no** `global`, **no** `nargin`-dependent defaults.

**Do not implement or refactor production `guidance_law.m` until golden parity vectors exist** (host law vs step twin).

### 6.2 Records (units / frames / bounds)

**`Params` (const after init; versioned)**  
| Field | Unit | Range / note |
|-------|------|--------------|
| `version` | — | uint32 schema ID |
| `MAX_PATH_POINTS` | — | compile-time capacity |
| `lookahead_distance` | m | ≥1.0 effective floor preserved |
| `desired_speed` | m/s | >0 |
| `pitch_ref_max`, `pitch_ref_rate_max` | rad, rad/s | frozen defaults 25° / 5° |
| `K_zdot`, `K_gamma` | — | frozen campaign values (often 0) |
| `enable_alpha_hat` | bool | frozen |
| `k_beta` | — | **1.35** frozen |
| `closed_eps` | m | 0.25 |
| `s_back_tol`, `s_fwd_k`, `s_fwd_min` | m, —, m | 0.15, 2.5, 3.0 |
| `mono_back_max` | m | 0.05 |
| `near_end_margin` | m | 0.3 |
| filter alphas **or** physical τ’s | — | matched to accepted `dt` |
| `z_e_i_max`, `pitch_corr_max`, `alpha_hat_max`, `r_ff_max`, `yaw_slew_max` | SI | absolute caps (±25, 9°, 8°, 40°/s, 40°/s) |
| `u_ref` schedule constants | — | `R+2.5`, floors 0.9 / 1.15 / 0.7·U |
| `eps_tang`, `kappa_min` | — | 1e-9 / 1e-4 class literals |
| `yaw_emit_mode` | enum | `UNWRAPPED` \| `WRAPPED_PI` (ownership freeze) |

**`State`**  
`initialized` (bool), `s_prog` [m], `i_seg` [1…MAX-1], `s_nodes[MAX]`, `s_total`, `path_version_loaded`,  
`yaw_cont`, `yaw_out`, `pitch_f`, `pitch_out`, `chi_f`,  
`z_e_f`, `z_e_i`, `zd_e_f`, `eg_f`, `alpha_hat`, `kappa_f`,  
`chi_valid`, `yaw_valid`, `pitch_valid` (bools — **replace NaN**),  
optional `hold_age` / `fault_latched`.

**`Input`**  
| Field | Unit / frame | Guard |
|-------|--------------|-------|
| `dt` | s | finite, `(0,dt_max]` |
| `position` | m **NED** `1×3` | finite |
| `path` | m NED `MAX×3` | finite; unused rows ignored |
| `n_path` | — | integer `2…MAX` |
| `path_version` | — | change ⇒ rebuild arc table |
| `is_closed` | bool | mission-declared (may mirror `:63` at load) |
| `u_body`,`v_body` | m/s **BODY** | finite; plausibility band |
| `U_h` | m/s NED horiz. | finite ≥0 |
| `zdot_inertial` | m/s NED | finite |
| `theta_phys` | rad physical | finite |
| `valid` | bool | false → hold refs, no I integrate |
| `seq`,`t_stamp` | — | transport (B14) |
| `progress_index_hint` | — | optional seed only on reset |

**`Output`**  
`yaw_ref` [rad], `pitch_ref` [rad], `u_ref` [m/s], `r_ff` [rad/s], `pitch_ref_dot` [rad/s],  
`next_progress_index` [int], `s_prog` [m], `near_end` [bool],  
`mag_sat_pitch`, `rate_sat_pitch`, `rate_sat_yaw` [bool],  
`fault` [bitfield], `safe_latched` [bool], `path_valid` [bool].

**`Debug`** (fixed; host/twin) — supersede `last_*` globals: `kappa_f`, `U_h`, `y_e`, `z_e_f`, `gamma_actual`, `gamma_path`, `e_gamma`, `alpha_eff`, `alpha_hat`, `e_z`, `e_zdot`, `chi_f`, `i_seg`, `R_abs`, etc.

### 6.3 Required finite / range / sequence guards (before integrate)

1. `Input.valid` and all numerics finite; else `fault|=IN_NONFINITE`, hold `State`, emit last rate-limited refs (or Params safe pitch/yaw/u).  
2. `n_path∈[2,MAX]`, `path_version` consistent; else `fault|=PATH_INVALID`.  
3. `Params` speeds/limits finite and `desired_speed>0`, `lookahead_distance` finite.  
4. `|u_body|`,`|v_body|`,`|U_h|`,`|zdot|` within Params plausibility.  
5. Sequence gap / stale `t_stamp` → fault + hold (supervisor).  
6. After step: outputs finite; `|dp|≤pitch_ref_rate_max·dt`; `|dyaw|≤yaw_slew_max·dt`.

### 6.4 Behaviour preservation constraints

- Same LOS + β, same Tur4A `r_ff`, same Tur5A/B structure, same clamps/filters at accepted `dt`.  
- Rejected forks remain closed (no structural-γ / LADRC / INDI / crab-current-FF / polyline substitute).  
- Numerical twin: host `guidance_law` vs `guidance_step` golden vectors within agreed tolerance **after** wrap/segment primitives match.  
- **Specification only until golden parity exists — no production edit in this task.**

---

## 7. Blocker severity roll-up (guidance)

| Severity | Count | IDs / topics |
|----------|------:|--------------|
| CRITICAL | 4 | GA-01 (persistent/reset), GA-02/GA-08 (globals + empty/unguarded params/inputs), GA-04 (unbounded path/alloc) — tracked as GA-01, GA-02, GA-04, GA-08 |
| HIGH | 10 | GA-03,05,06,07,09,10,11,12,13,14 |
| MED | — | K_zdot/K_gamma default-off; HW WCET measure |
| LOW / OK | — | `atan2`,`hypot`,`mod`,`wrap_arc`, core clamps, recursion-free helpers |

**Lift-as-is:** **FAIL**. **Static audit completeness:** **PASS**. **Overall task verdict:** **PARTIAL**.

---

## 8. Integrity

| File | Bytes | SHA-256 | State |
|------|------:|---------|-------|
| `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` | **UNTOUCHED** (read-only) |
| `suite_results/CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` | **UNTOUCHED — not read, not written** |

**Installs:** none. **Source edits:** none. **MATLAB runs:** 0.  
**Evidence writes:** this file · `CG_CODEGEN_STATUS.md` · compact appends to master plan, execution policy, pitch research log, state-space audit, realism log.

**Hardware:** **NOT_CERTIFIED**. Compiler/tool installation remains **deferred**.

---

*End of CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY. Verdict: **PARTIAL**. Next: `CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001`.*
