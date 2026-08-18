# CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY

**TASK_ID:** `CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001`  
**Track:** MATLAB→C++ pretarget — static MATLAB Coder compatibility (controller only)  
**Executed:** 2026-08-10 02:22 (local) / 2026-08-09T23:22:26Z  
**MATLAB invocations:** **0**  
**Mode:** bounded static audit · **no** MATLAB · **no** production/source algorithm edits · **no** executable codegen · **no** install/config · **no** repo rescan  
**Hardware:** **NOT_CERTIFIED** · exact part/board ABSENT (carried)  
**Compiler:** MISSING (CG_PRE0 PARTIAL) — does **not** block this static audit  
**Preserved:** frozen controller gains / numerical behaviour (spec only) · rejected methods remain closed · `suite_results/CODEX_VERTICAL_PLAN.md` (**UNTOUCHED — not read, not written**)

**Sources read (exactly three):**
| # | Path | Bytes | SHA-256 |
|---|------|------:|---------|
| 1 | `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` |
| 2 | `suite_results/CG0_CODEGEN_BOUNDARY.md` | (CG0 evidence) | carried |
| 3 | `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md` | (Gate9B evidence) | carried |

All line citations below refer to `controller_law.m` unless noted. Gate9B EG-/B- IDs are cross-references only.

---

## 1. Verdict

> ### CG1A: **PARTIAL**

The accepted controller’s **scalar arithmetic core** (`controller_law.m:59–179`) is the most transfer-ready DEPLOY unit in the CG0 boundary (Gate9B EG-79): recursion-free, RNG-free, fixed branch count, and bit-reproducible given identical inputs/state/FP mode. It is **not** liftable as-is into MATLAB Coder / STM32 because of **target-architecture blockers** (globals, un-resettable `persistent`, variable `nargin`/`nargout`, toolbox `wrapToPi`, unbounded `interp1` extrap, empty-parameter silent path). No critical ambiguity remains on the controller unit itself; next static audit is guidance.

| PASS condition | Required | Observed | Met? |
|---|---|---|---|
| Core math portable (sin/cos/exp/sign/clamp) | yes | yes (`:59–179`) | YES |
| Fixed types/sizes / fixed ABI as written | yes | no (globals, optional args, dbg struct, trim tables) | NO |
| Zero CRITICAL/HIGH architecture blockers for lift-as-is | 0 | **9 HIGH** + **2 CRITICAL** (see §5) | NO |
| Hardware / compiler resolved | n/a for static | NOT_CERTIFIED · compiler MISSING | n/a (deferred) |

**Next exact task (exactly one):** `CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001`

---

## 2. Scope and non-goals

| In scope | Out of scope |
|----------|--------------|
| Accepted production `controller_law.m` (+ local helper `lookup_elevator_trim`) | `guidance_law.m`, harness, plant, `run_*` |
| Static MATLAB Coder compatibility classification | Executable `codegen`, mex, compiler install |
| Spec of future fixed-signature step API / records | Implementing that API |
| Preserve current numerical behaviour & frozen gains | Any gain retune / candidate reopen |

**CG0 role reminder:** DEPLOY entry, risk HIGH (`CG0_CODEGEN_BOUNDARY.md` §3, §7).

---

## 3. Full I/O / state / dependency trace

### 3.1 Function signature (variable arity)

```
[delta_r, delta_e, thrust, dbg] = controller_law(
    yaw_ref, pitch_ref, u_ref, psi, theta, r, q, u,
    r_ff, pitch_ref_dot, phi, w, p)
```

| Port | Lines | Role | Unit / frame (comment-derived) | Codegen note |
|------|------:|------|--------------------------------|--------------|
| `yaw_ref` | 1 | heading reference | rad (unwrapped may arrive from guidance) | required scalar double |
| `pitch_ref` | 1 | physical pitch / climb-path ref | rad, physical | required |
| `u_ref` | 1 | surge speed reference | m/s | required |
| `psi` | 1 | measured yaw | rad | required |
| `theta` | 1 | measured pitch (sim convention) | rad; `theta_phys=-theta` (`:3,:73`) | required |
| `r` | 1 | BODY yaw rate | rad/s | required |
| `q` | 1 | BODY pitch rate | rad/s | required |
| `u` | 1 | BODY surge | m/s | required |
| `r_ff` | 1,41 | yaw-rate feedforward | rad/s; default 0 if `nargin<9` or empty | optional → ABI hazard |
| `pitch_ref_dot` | 1,42 | pitch-ref rate | rad/s; default 0 | optional → ABI hazard |
| `phi` | 1,43 | roll angle | rad; default 0 | optional → ABI hazard |
| `w` | 1,44 | BODY heave (Muw FF) | m/s; default 0; λ=0 ⇒ FF off | optional → ABI hazard |
| `p` | 1,45 | BODY roll rate | rad/s; default 0 | optional → ABI hazard |
| `delta_r` | 1,151–154 | rudder command | rad | always |
| `delta_e` | 1,151–154 | elevator command | rad | always |
| `thrust` | 1,178–179 | thrust command | N (assumed SI) | always |
| `dbg` | 1,181–213 | 27-field diagnostic struct | mixed | **only if `nargout>=4`** |

### 3.2 Globals — parameters (read; some self-defaulted)

| Global | Decl | Default / use | Guarded? | Severity if empty |
|--------|-----:|---------------|----------|-------------------|
| `Kp_psi`, `Kd_psi`, `Kp_x` | 12 | yaw PD + speed P (`:63,:178`) | **NO** | CRITICAL — empty clamps (Gate9B EG-38) |
| `Kp_roll` | 13,54 | roll-rate damp 0.605072 (`:67`) | yes `:54` | HIGH (self-mutates config) |
| `Kp_angle`,`Ki_angle`,`Kp_rate`,`Ki_rate`,`Kaw_pitch`,`Kd_rate`,`Kd_damp` | 14 | cascaded pitch (`:82–106,:139`) | only `Kd_rate`,`Kd_damp` (`:38–39`) | CRITICAL for unguarded gains |
| `delta_r_max`,`delta_e_max`,`thrust_max`,`thrust_min` | 15 | authority (`:70,:133,:179`) | **NO** | CRITICAL |
| `thrust_trim` | 16 | bias (`:178`) | **NO** | CRITICAL |
| `trim_speed_table`,`trim_elevator_table` | 17 | trim LUT (`:217–222`) | empty → fallback | HIGH (size unbounded) |
| `elevator_sign` | 18,46 | ±1 open-loop (`:107,:136,:145`) | yes `:46` | HIGH (sign convention) |
| `dt_controller`,`tau_rate` | 19,56–57 | sample time / LPF tau | yes | HIGH (dt ownership) |
| `Muw`,`Muuds` | 20,52–53 | hydro coeffs in controller | yes | HIGH (B04/EG-14) |
| `lambda_muw_ff`,`muw_ff_u_min/lo/hi`,`muw_ff_clamp_deg` | 21,47–51 | Tur-3 FF schedule | yes | MED (λ=0 identity) |

### 3.3 Globals — diagnostics (write-only side channel)

Written `:156–176`:  
`last_int_angle`, `last_int_rate`, `last_delta_e`, `last_delta_r`, `last_dr_yaw`, `last_dr_p`, `last_dr_damp`, `last_g_ac`, `last_rate_filt`, `last_theta_phys_dot`, `last_de_trim`, `last_delta_e_angle_I`, `last_e_theta`, `last_theta_phys`, `last_de_uw_ff`, `last_de_fb`, `last_M_uw`, `last_M_elev`, `last_M_e_ff`, `last_G_de`, `last_M_total_pitch`.

**Codegen:** must **not** be STM32 ABI; fold into fixed `Debug` / telemetry record (Gate9B EG-10, EG-73).

### 3.4 Persistent state (no reset API)

| State | Decl / init | Use | Reset? |
|-------|-------------|-----|--------|
| `prev_delta_e`, `prev_delta_r` | 23,32–33 | rate-limit anchors `:151–154` | **never** (EG-02) |
| `int_angle`, `int_rate` | 24,34–35 | outer/inner I `:82,:97,:141–147` | **never** |
| `rate_filt`, `prev_e_rate` | 25,36–37 | LPF + D on e_rate `:77,:93–96` | **never** |

Cold-start: `isempty` once (`:32–37`). Mission re-arm continues prior surface commands and integrators → **CRITICAL architecture**.

### 3.5 Local helper

| Helper | Lines | Deps | Issue |
|--------|------:|------|-------|
| `lookup_elevator_trim(u)` | 216–223 | globals `trim_*`, `delta_e_trim`; `interp1(...,'linear','extrap')` | unbounded table + unbounded extrap (EG-21, EG-40) |

### 3.6 External / toolbox / language dependencies

| Symbol | Line(s) | Class | Notes |
|--------|---------|-------|-------|
| `wrapToPi` | 61 | **toolbox / non-base** | Gate9B EG-26; resolution not in this file → must replace with local bounded wrap |
| `deg2rad` | 64–65,83,87,94,101,112,127,149–150 | base; **fixed-type OK** | prefer const-fold literals |
| `interp1` | 222 | **restricted codegen** | linear+extrap; needs fixed-size tables + endpoint clamp |
| `struct(...)` | 182–212 | codegen OK **if fixed fields** | blocked by `nargout` optional emit |
| `isempty` on globals/persistent | 32–57,218 | host pattern | replace with typed Params/State init |
| `nargin` / `nargout` | 41–45,181 | variable ABI | **architecture blocker** |
| `eps` | 66 | host double epsilon | TARGET_DEPENDENT (EG-41) |
| `sign` | 145 | base | **directly OK** |
| `exp` | 76 | base | OK; precompute `a_rate` when dt fixed (EG-30) |
| `sin`,`cos` | 74 | base | **directly OK** |
| `max`/`min`/`abs` | many | base | **directly OK** |
| `double(...)` | 202 | cast | OK for fixed double policy |

**No** `ode45`, `fprintf`, `try/catch`, random, file I/O, or handle graphics in this unit.

---

## 4. Compatibility classification (controller only)

### 4.1 Directly codegen-compatible (with scalar double policy)

| Item | Evidence | Note |
|------|----------|------|
| Yaw PD + roll damp algebra | `:61–69` | after `wrapToPi` replacement |
| Physical pitch kinematics | `:73–74` | preserve sign comments as machine fields |
| Rate LPF recurrence | `:76–77` | `a_rate=exp(-dt/tau)` pattern is correct (EG-47) |
| Cascaded angle→rate→elevator | `:79–107` | clamps present |
| Climb FF + Muw FF algebra | `:109–130` | λ=0 path identical zero |
| Mag sat + rate limit + Kaw AW | `:133–154` | AW blind to rate sat remains **logic** defect (EG-53), not a codegen syntax issue |
| Speed thrust law | `:178–179` | |
| `sign`, `sin`, `cos`, `exp`, `max`/`min` | as cited | |

### 4.2 Codegen-compatible only with fixed types / sizes

| Item | Evidence | Required fix (spec) |
|------|----------|---------------------|
| All I/O | `:1` | `coder.typeof` / fixed `1x1 double` (or single policy later) |
| Trim tables | `:217–222` | `coder.Constant` or fixed `Nx1` with compile-time `N=N_TRIM` |
| `deg2rad` literals | listed | fold to `double` radians constants |
| `dbg` fields | `:182–212` | always-emitted fixed struct, never optional |
| `interp1` | `:222` | fixed-size linear interp **or** hand-written 1-D lerp; **no** `'extrap'` |
| Integrator limits vs gains | `:83,:102` | fixed absolute state caps independent of tiny Ki (EG-36) |

### 4.3 Target-architecture blockers (host-side; not cured by MCU choice)

| ID | Item | Lines | Maps to |
|----|------|------:|---------|
| CA-01 | No `init`/`reset`/`step`; `persistent` survives missions | 23–25,32–37,151–154 | B01 / EG-02 |
| CA-02 | Globals for gains/limits/tables; self-default writes | 12–21,38–57 | B04 / EG-11–14 |
| CA-03 | Variable `nargin` defaults (plausible, not safe) | 41–45 | EG-67 |
| CA-04 | Variable `nargout` debug struct | 181–213 | EG-20 / EG-84 |
| CA-05 | `wrapToPi` non-owned primitive | 61 | B07 / EG-26 |
| CA-06 | `interp1` + unbounded extrap + unknown table length | 216–223 | B05/B07 / EG-21,40 |
| CA-07 | Unguarded empty gains/limits → empty actuator cmds | 12–17,63–179 | B10 / EG-38 |
| CA-08 | No input finite/range guards | 1,59–179 | B10 / EG-39 |
| CA-09 | `dt` from global, not step arg | 56–58 | B11 / EG-43 |
| CA-10 | Diagnostic globals as second ABI | 26–30,156–176 | B14 / EG-10,73 |
| CA-11 | Rate-limiter models actuator; no feedback ports | 149–154; inputs `:1` | B03 / EG-68–69 |
| CA-12 | Saturation not on production 3-output path | 181,202 | B12 / EG-57 |

### 4.4 Hardware-dependent (deferred; do not block static CG1B)

| Item | Lines | Note |
|------|------:|------|
| Native f64 vs f32 / soft-float | whole file | EG-33; policy absent |
| `eps` magnitude | 66 | EG-41 |
| In-loop `exp` WCET | 76 | EG-30; precompute when dt fixed |
| Absolute WCET / stack / FPU | — | EG-83; controller otherwise straight-line |
| Actuator true slew / feedback | — | EXTERNAL_HIL EG-70–71 |
| Compiler / STM32 packs | — | CG_PRE0 MISSING; install deferred |

---

## 5. Focused assessments (task-required)

| Topic | Finding | Severity | Remediation gate |
|-------|---------|----------|------------------|
| **`wrapToPi`** | Single call `:61` on `yaw_ref-psi`. Not defined in this file; toolbox/local `TO_BE_IDENTIFIED` (EG-26). Core cannot own an unresolved external. | **HIGH** | **GATE_CG_WRAP:** replace with local `wrap_pi_local(x)` (atan2/sin-cos or rem-based), unit-tested vs host `wrapToPi` on golden vectors; no toolbox link. |
| **`deg2rad`** | Hot-path constant conversion. Codegen-supported; wasteful. | **LOW** | **GATE_CG_CONST:** replace with frozen radian literals; gains unchanged. |
| **`interp1` linear/extrap** | `:222` + empty fallback `:218–220` to `delta_e_trim` (also unguarded). Extrap can consume full elevator authority before FB (EG-40). Table length unknown here. | **HIGH** | **GATE_CG_TRIM:** fixed `N_TRIM`, monotonic speed breakpoints, **endpoint clamp** (no extrap); tables in `Params` const block from `build_pitch_trim_table` (CG0 SHARED_SUPPORT). |
| **`struct dbg`** | 27 fields only if `nargout>=4` (`:181–213`). Production ABI is 3 outputs → twin logs impossible (EG-84). | **HIGH** | **GATE_CG_DBG:** always return fixed `Debug` record (or separate `controller_step` out-arg); field set frozen. |
| **Globals (params)** | `:12–21`; function writes defaults `:38–57`. | **CRITICAL** | **GATE_CG_PARAMS:** versioned `Params` in; **no** global read/write; init owns defaults once. |
| **Globals (diagnostics)** | `:26–30,:156–176`. | **HIGH** | **GATE_CG_TELEM:** move to `Debug` / optional telem sink; strip from step hot path on target. |
| **`persistent` init/reset** | `:23–25,:32–37`; never cleared. | **CRITICAL** | **GATE_CG_STATE:** explicit `State`; `controller_init` / `controller_reset` ownership; no `persistent`. |
| **Empty defaults** | Optional inputs `:41–45`; param `isempty` mixed; critical limits **unguarded** (EG-38). | **CRITICAL** | **GATE_CG_VALID:** reject empty/NaN/Inf; emit defined safe command + fault bit. |
| **`eps`** | `:66` divisor floor. | **MED** | **GATE_CG_EPS:** literal e.g. `1e-12` (double policy) or typed `eps_angle`. |
| **`sign`** | `:145` AW bleed. | **OK** | none (keep behaviour). |
| **`exp`/`sin`/`cos`** | `:74,:76`. | **OK** / WCET **MED** | precompute `a_rate` in init when `dt` fixed; keep math. |
| **Trim tables** | `:17,:99,:216–223`. | **HIGH** | same as **GATE_CG_TRIM**. |
| **Diagnostic globals** | as above | **HIGH** | **GATE_CG_TELEM**. |

**Frozen gains (must preserve numerically):**  
`Kp_roll=0.605072` (`:54`), `k_gamma_climb=0.1320695001` (`:111`), `de_climb_lim=deg2rad(2.8793)` (`:112`), `Kd_damp` default 0.55 (`:39`), `tau_rate=-0.075/log(0.90)` (`:57`), Muw/Muuds defaults (`:52–53`), rate limit 40 deg/s (`:149–150`), all production Kp/Ki/Kaw from `init_parameters` (values not in this file — must be snapshotted into versioned Params without change).

---

## 6. Future fixed-signature API (specification only — **do not implement yet**)

### 6.1 Entry points

```text
Params  = controller_params_default()           % host/build-time; frozen gains
State   = controller_init(Params)               % zeros / bumpless seeds
State   = controller_reset(State, Params, mode) % mode: COLD | HOLD_SURFACES | ENGAGE
Output  = controller_step(Params, State, Input) % State updated by reference/value return
% Optional host twin:
[Output, Debug] = controller_step(Params, State, Input)
```

Ownership:
- **Init/reset:** caller / mission manager (not the plant harness). `controller_step` never invents Params defaults.
- **Step:** owns one control period; `Input.dt` is the sole sample-time source (replaces `dt_controller` global).
- **No** `persistent`, **no** `global`, **no** `nargin`/`nargout` behaviour change.

### 6.2 Records (units / frames / ranges)

**`Params` (const after init; versioned)**  
| Field | Unit | Range / note |
|-------|------|--------------|
| `version` | — | uint32 schema ID |
| `Kp_psi`,`Kd_psi`,`Kp_x` | 1/rad, s, N/(m/s) | frozen production |
| `Kp_roll` | s | **0.605072** frozen |
| `Kp_angle`,`Ki_angle`,`Kp_rate`,`Ki_rate`,`Kaw_pitch`,`Kd_rate`,`Kd_damp` | SI | frozen |
| `delta_r_max`,`delta_e_max` | rad | >0 |
| `thrust_min`,`thrust_max`,`thrust_trim` | N | min≤trim≤max |
| `elevator_sign` | — | exactly ±1 |
| `tau_rate` | s | physical LPF tau |
| `slew_r_max`,`slew_e_max` | rad/s | today `deg2rad(40)` |
| `Muw`,`Muuds` | SI | frozen defaults / ID’d |
| `lambda_muw_ff`, `muw_ff_*` | — | λ∈[0,1] |
| `k_gamma_climb`,`de_climb_lim` | 1, rad | **0.1320695001**, **deg2rad(2.8793)** |
| `trim_u[N]`,`trim_de[N]` | m/s, rad | fixed N, monotonic u |
| `int_angle_abs_max`,`int_rate_abs_max` | rad, rad | **absolute** caps (not Ki-derived alone) |
| `eps_angle` | rad | replaces `eps` |

**`State`**  
`prev_delta_r`, `prev_delta_e`, `int_angle`, `int_rate`, `rate_filt`, `prev_e_rate`, `a_rate` (optional cached), `initialized` (boolean — **no NaN sentinels**).

**`Input`**  
| Field | Unit / frame | Guard |
|-------|--------------|-------|
| `dt` | s | finite, `(0,dt_max]` |
| `yaw_ref`,`psi` | rad | finite; wrap error only inside step |
| `pitch_ref`,`pitch_ref_dot` | rad, rad/s physical | finite |
| `u_ref`,`u`,`w` | m/s BODY | finite; u plausibility band |
| `theta` | rad sim convention | finite; convert via `theta_phys=-theta` |
| `phi` | rad | finite |
| `r`,`q`,`p` | rad/s BODY | finite |
| `r_ff` | rad/s | finite |
| `valid` | bool | if false → safe output, no state integrate |
| `seq`,`t_stamp` | — | transport (B14); required on target path |

**`Output`**  
`delta_r`,`delta_e` [rad], `thrust` [N], `mag_sat_r`,`mag_sat_e`,`rate_sat_r`,`rate_sat_e` [bool], `fault` [bitfield], `safe_latched` [bool].

**`Debug`** (fixed; superset of today’s `:182–212` plus sat flags) — host/twin only; may be compiled out on target.

### 6.3 Required finite / range guards (before integrate)

1. All `Input` numeric fields finite; else `fault|=IN_NONFINITE`, hold `State`, emit **safe command** (spec: last valid rate-limited surfaces + `thrust_trim` or mission-defined zero-thrust — choose one and freeze in Params).  
2. `Params` limits/gains finite and `delta_*_max>0`, `thrust_min<=thrust_max`, `|elevator_sign|==1`.  
3. `|u|`,`|w|`,`|p|`,`|q|`,`|r|` within Params plausibility; soft-clamp or fault per policy (policy TBD in remediation, default: fault+safe).  
4. Trim lookup: clamp `u` to `[trim_u(1),trim_u(N)]` before lerp.  
5. After step: outputs finite and within mag limits; assert rate step ≤ slew·dt.

### 6.4 Behaviour preservation constraints

- Same cascade structure, same clamp constants, same AW/bleed formulas, same roll-damp scheduling `g_ac`, same climb/Muw FF equations.  
- Rejected methods remain closed (no ADRC/INDI/etc. reopen).  
- Numerical twin: host `controller_law` vs `controller_step` golden vectors within agreed ulp/tolerance **after** wrap/trim primitives match.

---

## 7. Blocker severity roll-up (controller)

| Severity | Count | IDs |
|----------|------:|-----|
| CRITICAL | 3 | CA-01 (persistent/reset), CA-02/CA-07 (globals+empty cmds) — counted as CA-01, CA-07, CA-02 |
| HIGH | 9 | CA-03,04,05,06,08,09,10,11,12 |
| MED | 2 | `eps`; in-loop `exp` WCET |
| LOW / OK | — | `sign`,`sin`,`cos`, core clamps, thrust law |

**Lift-as-is:** **FAIL**. **Static audit completeness:** **PASS**. **Overall task verdict:** **PARTIAL**.

---

## 8. Integrity

| File | Bytes | SHA-256 | State |
|------|------:|---------|-------|
| `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` | **UNTOUCHED** (read-only) |
| `suite_results/CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` | **UNTOUCHED — not read, not written** |

**Installs:** none. **Source edits:** none. **MATLAB runs:** 0.  
**Evidence writes:** this file · `CG_CODEGEN_STATUS.md` · compact appends to master plan, execution policy, pitch research log, state-space audit, realism log.

**Hardware:** **NOT_CERTIFIED**. Compiler/tool installation remains **deferred**.

---

*End of CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY. Verdict: **PARTIAL**. Next: `CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001`.*
