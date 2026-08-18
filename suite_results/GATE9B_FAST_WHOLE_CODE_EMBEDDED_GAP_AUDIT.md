# GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT

**TASK_ID:** `GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT_001`
**Mode:** fast, read-only, whole-code embedded-transfer gap audit.
**Executed:** no MATLAB, no simulation, no execution, no repo scan, no runtime edit, no source edit, no candidate retry, no method retry, no promotion, no label upgrade.
**Terminal state:** `AWAIT_STM32_EXACT_PART_NUMBER`.
**Naming constraint honoured:** no MCU family, vendor, brand, board, part number or purchase claim appears anywhere in this document.

---

## 0. Scope, sources and evidentiary limits

### 0.1 Sources actually read in this task (exactly three)

| # | File | Bytes | SHA-256 (pre-audit == post-audit) |
|---|------|-------|-----------------------------------|
| 1 | `continuous_path_tracking.m` | 10845 | `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b` |
| 2 | `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` |
| 3 | `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` |

These three files were read in full, line by line. **Every line number cited in this document refers to one of these three files and to no other file.**

### 0.2 Files explicitly NOT source-reviewed

No claim in this document asserts that any file other than the three above was read. In particular the following are referenced **only as call-graph names appearing inside the three read files**, and their contents are `TO_BE_IDENTIFIED` for the purposes of this audit:

- `init_parameters` — called at `continuous_path_tracking.m:6`; contents not read.
- `underwater777_vehicle_dynamics` — called at `continuous_path_tracking.m:101`; contents not read.
- `wrapToPi` — called at `guidance_law.m:164,173,180,212` and `controller_law.m:61`; resolution (toolbox vs local shadow) not read and therefore `TO_BE_IDENTIFIED`.
- `interp1` — called at `controller_law.m:222`.
- Every `suite_results/*` artefact, every `run_*.m` driver, every candidate `guidance_law_*.m` / `controller_law_*.m` variant, and every backup under `.roll_closure_bak/`.

A directory listing was consulted solely to resolve the filenames of the append targets required by the task. **A filename listing is not a source review and no behavioural claim in this document derives from it.**

### 0.3 Carried Gate 9 disposition (context only, not re-derived here)

Carried forward verbatim as context, not re-verified in this task:

- **RC_NOT_GRANTED.**
- **Residual risks R1–R8 all OPEN.**
- **Exact target part/board ABSENT.**

Gate 9B does not change, upgrade, downgrade or re-litigate any of the above.

---

## 1. Verdict

> ### GATE 9B: **FAIL** — RC_NOT_GRANTED sustained.

Gate 9B PASS requires (a) zero software/safety `BLOCKER` and (b) a complete embedded handoff manifest.

| PASS condition | Required | Observed | Met? |
|---|---|---|---|
| Software/safety BLOCKERs | 0 | **14** | **NO** |
| Embedded handoff manifest complete | all rows `IMPLEMENTED` or `DERIVED` with a bounded numeric contract | 9 of 34 manifest rows `IMPLEMENTED`; 4 `DERIVED`; 6 `ASSUMED`; **15 `TO_BE_IDENTIFIED`** | **NO** |

Honest reading: **the repository does not currently contain a separable deployable control core.** It contains a MATLAB simulation in which the control law happens to live. Three code units are *candidates* for a deployable core (`guidance_law` main body, `controller_law` main body, `inertial_velocity_ned`), but all three are structurally fused to the host by global-variable parameter/diagnostic coupling, un-resettable `persistent` state, host-owned sample time, and absence of any transport, validity, health or timing contract. The gap is architectural, not cosmetic, and it is not closed by choosing a target.

**No amount of target selection closes any of the 14 BLOCKERs.** They are all host-side software/safety defects that must be dispositioned in MATLAB-space first.

---

## 2. Deployable control core vs simulation plant/harness

Boundary as it actually exists in the three read files.

| Code unit | Lines | Classification | Justification (line-specific) |
|---|---|---|---|
| `continuous_path_tracking` main | `continuous_path_tracking.m:1–226` | **SIMULATION HARNESS — not deployable** | Owns the fixed-horizon loop `1:n_steps` (`:71`), calls a variable-step host integrator (`:101`), pre-allocates ~30 whole-mission log vectors (`:20–63`), prints to stdout inside the loop (`:104–106`, `:183–184`), and exports results by writing 28 globals (`:189–225`). |
| `inertial_velocity_ned` | `continuous_path_tracking.m:228–244` | **DEPLOYABLE CORE CANDIDATE** | Pure, fixed-size, side-effect free: 3×3 NED rotation of body velocity, `hypot`. No globals, no persistent, no allocation. The single cleanest transfer candidate in the entire read set. |
| `guidance_law` main | `guidance_law.m:1–280` | **DEPLOYABLE CORE CANDIDATE — currently non-transferable** | Contains the actual path-following law, but reads/writes 19 globals (`:13–19`), holds 13 un-resettable `persistent` states (`:21`), takes a variable-size `path` (`:54`), and owns no sample time of its own (`:36`). |
| `guidance_law` helpers | `guidance_law.m:283–394` | **DEPLOYABLE CORE CANDIDATE — WCET-unbounded** | `path_arclength` (`:283–293`), `project_on_path` (`:299–318`), `project_interval` (`:320–351`), `sample_path` (`:353–379`), `path_curvature_at` (`:381–394`). Pure functions, but all are O(n) or O(segments-in-window) in the path array and are re-executed every guidance tick. |
| `controller_law` main | `controller_law.m:1–214` | **DEPLOYABLE CORE CANDIDATE — currently non-transferable** | The attitude/speed control law proper, but reads/writes ~30 globals (`:12–30`), holds 6 un-resettable `persistent` states (`:23–25`), derives `dt` from a global (`:56–58`), and emits an `nargout`-dependent 27-field debug struct (`:181–213`). |
| `lookup_elevator_trim` | `controller_law.m:216–223` | **DEPLOYABLE CORE CANDIDATE — unbounded** | Table lookup, but reads three globals and extrapolates without limit (`:222`). |
| `underwater777_vehicle_dynamics` | called `continuous_path_tracking.m:101` | **SIMULATION PLANT — never deployable** | Not read. Named only. |

**Deployable-core line budget observed:** roughly 500 of the ~860 lines in the read set are candidate control code; the remaining ~360 lines are harness, logging and diagnostics. **Not one line of the candidate core is currently free of host coupling except `inertial_velocity_ned` (`continuous_path_tracking.m:228–244`).**

---

## 3. Checklist A1–A13 — line-specific findings

Every finding carries a **classification** (`BLOCKER` / `TARGET_DEPENDENT` / `EXTERNAL_HIL` / `COSMETIC`) and a **label** (`IMPLEMENTED` / `DERIVED` / `ASSUMED` / `TO_BE_IDENTIFIED`).

Classification semantics used here:
- **BLOCKER** — a software or safety defect that prevents a correct, deterministic, safe embedded transfer, and that must be fixed in host code regardless of target.
- **TARGET_DEPENDENT** — cannot be resolved or numerically bounded until the exact part and board are supplied.
- **EXTERNAL_HIL** — resolvable only against physical hardware or a hardware-in-the-loop bench.
- **COSMETIC** — hygiene; no safety or determinism consequence.

Label semantics used here:
- **IMPLEMENTED** — the property is present in the read code.
- **DERIVED** — established by reasoning directly over the read lines.
- **ASSUMED** — stated as an assumption; not provable from the three sources.
- **TO_BE_IDENTIFIED** — not determinable from the three sources and not assumed.

---

### A1 — Deterministic step / reset APIs

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-01** | **No reset API exists anywhere in the read set.** `guidance_law` holds `persistent s_prog yaw_cont pitch_f z_e_f z_e_i zd_e_f eg_f alpha_hat kappa_f chi_f yaw_out pitch_out initialized` and gates cold-start solely on the `initialized` flag (`guidance_law.m:21–22, 68–80`). Nothing in any of the three files ever clears it. A second mission in the same process therefore starts with the previous mission's arc-length progress `s_prog`, unwrapped heading `yaw_cont`, depth integrator `z_e_i` and AoA estimate `alpha_hat`. | `guidance_law.m:21,22,68–80` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-02** | Same defect in the controller: `persistent prev_delta_e prev_delta_r`, `int_angle int_rate`, `rate_filt prev_e_rate` (`controller_law.m:23–25`) are initialised once by `isempty` guards (`:32–37`) and never cleared. `prev_delta_e/prev_delta_r` seed the rate limiter at `:151–152`, so a re-armed mission begins with the *previous* mission's final surface deflection as its rate-limit anchor. | `controller_law.m:23–25,32–37,151–154` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-03** | **No step API.** There is no `guidance_step(dt, in) -> out` / `controller_step(dt, in) -> out` signature. Step cadence is implied by the harness loop index (`continuous_path_tracking.m:71`) and the modulo tick (`:84`). Both laws advance their integrators as a side effect of being called, with no explicit tick, no step counter and no missed-step detection. | `continuous_path_tracking.m:71,84`; `guidance_law.m:194`; `controller_law.m:82,97` | **BLOCKER** | DERIVED |
| **EG-04** | `init_parameters()` is invoked from inside the harness body (`continuous_path_tracking.m:6`) rather than being a separate, idempotent, verifiable init phase. The control core cannot be initialised without running the harness. | `continuous_path_tracking.m:6` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-05** | Determinism is otherwise favourable: the control path itself contains no random number generation, no time-of-day query and no data-dependent iteration count in `controller_law`. Given identical inputs and identical state, `controller_law` is bit-reproducible on a fixed FP configuration. | `controller_law.m:59–179` | **COSMETIC** (positive finding) | DERIVED |

---

### A2 — Mission → Guidance → Navigation → Controller → Actuator boundaries

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-06** | **The Navigation layer does not exist in the read set.** `continuous_path_tracking.m:72–77` slices the *integrator output* `state` directly into position, orientation, body rates and body velocities, then passes them to guidance (`:85–87`) and controller (`:91–94`). There is no estimator, no filter, no sensor model and no measurement-to-estimate transformation anywhere between plant and control. | `continuous_path_tracking.m:72–77,80,85–87,91–94` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-07** | **The Mission layer does not exist in the read set.** The `path` array is a bare function argument (`continuous_path_tracking.m:1`, `guidance_law.m:1`). There is no mission object, no waypoint acceptance criterion, no mission ID, no mission version, no abort/hold/resume command, and no mission-validity input. `near_end` (`guidance_law.m:108`) is the only mission-phase concept and it is a bare arc-length threshold `s_total - 0.3`. | `continuous_path_tracking.m:1`; `guidance_law.m:1,108` | **BLOCKER** | DERIVED |
| **EG-08** | **The Actuator layer is a return value, not an interface.** `controller_law` returns three bare doubles `delta_r, delta_e, thrust` (`controller_law.m:1`), assembled into an ad-hoc struct at `continuous_path_tracking.m:96–98` and handed straight to the plant. No command frame, no command ID, no arm state, no enable/disable, no fail-safe command, no surface-position feedback. | `controller_law.m:1`; `continuous_path_tracking.m:96–98` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-09** | The Guidance→Controller boundary is the only boundary with an explicit, typed signature: six outputs (`guidance_law.m:1`) consumed as six inputs plus state at `continuous_path_tracking.m:85–94`. It carries values only — no timestamp, no sequence, no validity. | `guidance_law.m:1`; `continuous_path_tracking.m:85–94` | **BLOCKER** | DERIVED |
| **EG-10** | Boundary coupling is additionally *implicit* through globals: guidance writes `last_gamma_actual … last_alpha_hat` (`guidance_law.m:231–238`) which the harness reads at `continuous_path_tracking.m:172–178`; the controller writes 20 globals at `controller_law.m:156–176` read at `continuous_path_tracking.m:151–178`. This is a second, undeclared data path that parallels the declared one. | `guidance_law.m:231–238`; `controller_law.m:156–176`; `continuous_path_tracking.m:151–178` | **BLOCKER** | IMPLEMENTED (defect) |

---

### A3 — Globals / persistent hidden state

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-11** | **Global count in the read set is extreme.** `continuous_path_tracking.m` declares globals at `:7, 29–35, 189–196` (2 timing + 26 diagnostic + 28 suite-export). `guidance_law.m` declares 19 at `:13–19`. `controller_law.m` declares ~30 at `:12–30`. There is no parameter struct, no const-qualified parameter block, no versioned parameter set. | `continuous_path_tracking.m:7,29–35,189–196`; `guidance_law.m:13–19`; `controller_law.m:12–30` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-12** | **Control functions mutate their own configuration.** `guidance_law.m:27–34` writes defaults into the globals `pitch_ref_max`, `pitch_ref_rate_max`, `K_zdot`, `K_gamma`, `enable_alpha_hat`, `dt_controller`, `dt_guidance`. `controller_law.m:38–39,46–57` writes defaults into `Kd_rate`, `Kd_damp`, `elevator_sign`, `lambda_muw_ff`, `muw_ff_u_min/lo/hi`, `muw_ff_clamp_deg`, `Muw`, `Muuds`, `Kp_roll`, `dt_controller`, `tau_rate`. The first call therefore silently changes system-wide configuration; a later reader of those globals cannot tell whether a value was commanded or self-assigned. | `guidance_law.m:27–34`; `controller_law.m:38–39,46–57` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-13** | **Harness mutates the timing globals from a caller argument.** `continuous_path_tracking.m:12` assigns `dt_controller = dt` and `:17` assigns `dt_guidance = dt`, so the plant step silently redefines both control rates for every subsequent call in the process. | `continuous_path_tracking.m:9–17` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-14** | **Plant/model coefficients are hard-coded inside the control law.** `Muw = 24` and `Muuds = -6.15` (`controller_law.m:52–53`) are hydrodynamic derivatives living in the controller as fallback defaults. `Kp_roll = 0.605072` (`:54`) and `k_gamma_climb = 0.1320695001`, `de_climb_lim = deg2rad(2.8793)` (`:111–112`) are campaign-fitted constants with 7–10 significant digits and no provenance in code. | `controller_law.m:52–54,111–112` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-15** | **Not reentrant, single-instance only.** `persistent` + `global` state means two concurrent instances (e.g. a monitor lane and a command lane, or a shadow law) cannot coexist in one address space. Any redundant-lane or shadow-compare architecture is structurally impossible without refactor. | `guidance_law.m:21`; `controller_law.m:23–25` | **BLOCKER** | DERIVED |
| **EG-16** | Diagnostic globals are lazily defaulted *inside the harness loop* at `continuous_path_tracking.m:125–150` — 26 `isempty` guards executed every single step, purely to protect logging. This is hidden state repair in the hot path. | `continuous_path_tracking.m:125–150` | **COSMETIC** | IMPLEMENTED (defect) |

---

### A4 — Dynamic / variable-size memory

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-17** | **Whole-mission log buffers are allocated proportional to run length.** `n_steps = round(T_final/dt)` (`continuous_path_tracking.m:19`) then ~30 arrays `zeros(n_steps,1)` / `zeros(n_steps,3)` (`:20–63`). At the code's own default `dt_controller = 0.0375 s` (`controller_law.m:56`) a 15 s default run (`continuous_path_tracking.m:15`) is 400 steps, but the allocation scales linearly and without bound with `T_final`. Harness-only, but it means the current "run" entry point can never be the embedded entry point. | `continuous_path_tracking.m:19–63` | **BLOCKER** (for transfer of this entry point) | DERIVED |
| **EG-18** | **Arrays are dynamically re-sized on the failure path.** `continuous_path_tracking.m:107–114` truncates eight arrays via `x = x(1:idx-1,:)` inside the `catch`. Reallocation during a fault response is exactly the wrong behaviour for a deterministic system. | `continuous_path_tracking.m:107–114` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-19** | **`path` is an unbounded variable-size input.** `n = size(path,1)` (`guidance_law.m:54`) with no maximum. `path_arclength` allocates `zeros(n,1)` **on every guidance tick** (`guidance_law.m:62,285`). There is no `MAX_WAYPOINTS` constant anywhere in the read set. | `guidance_law.m:54,62,285` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-20** | `controls` struct is built by dynamic field assignment each step (`continuous_path_tracking.m:96–98`), and the `dbg` struct with 27 fields is constructed conditionally on `nargout` (`controller_law.m:181–213`). A variable output arity is not a fixed ABI. | `continuous_path_tracking.m:96–98`; `controller_law.m:181–213` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-21** | `interp1(trim_speed_table, trim_elevator_table, …)` (`controller_law.m:222`) operates on two globals of unknown, unbounded length. Table size is `TO_BE_IDENTIFIED` from the read set. | `controller_law.m:217–222` | **BLOCKER** | TO_BE_IDENTIFIED |
| **EG-22** | Heap behaviour on the target is `TO_BE_IDENTIFIED`; no allocation budget, no static-allocation policy and no `malloc`-free guarantee exists in the read set. | — | **TARGET_DEPENDENT** | TO_BE_IDENTIFIED |

---

### A5 — Host-only / codegen-unsupported calls

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-23** | **`ode45` — variable-step host integrator with an anonymous function handle**, called once per control step over `[0 dt]` (`continuous_path_tracking.m:101`). Non-deterministic step count, non-deterministic execution time, function-handle closure, host solver. Not transferable under any circumstance. Correctly located in the **simulation plant/harness**, so it does not by itself block the *core*; it does block treating `continuous_path_tracking` as the step driver. | `continuous_path_tracking.m:101` | **BLOCKER** (harness); plant/harness-scoped | IMPLEMENTED (defect) |
| **EG-24** | **`try`/`catch` with exception object** (`continuous_path_tracking.m:100,103`) and `ME.message` string formatting (`:104`). Exception handling and dynamic strings are host constructs. | `continuous_path_tracking.m:100–106` | **BLOCKER** (harness) | IMPLEMENTED (defect) |
| **EG-25** | **`fprintf` inside the control loop** at `continuous_path_tracking.m:104–106` (fault path) and `:183–184` (every 100 steps). Blocking console I/O in a control loop. | `continuous_path_tracking.m:104–106,183–184` | **BLOCKER** (harness) | IMPLEMENTED (defect) |
| **EG-26** | **`wrapToPi` is not a base-language function.** Used at `guidance_law.m:164,173,180,212` and `controller_law.m:61` — i.e. in the *core* candidates, not the harness. Whether it resolves to a toolbox function or a local shadow is `TO_BE_IDENTIFIED` (that file was not read). Either way the deployable core must carry its own bounded angle-wrap primitive. | `guidance_law.m:164,173,180,212`; `controller_law.m:61` | **BLOCKER** | TO_BE_IDENTIFIED |
| **EG-27** | `interp1(..., 'linear', 'extrap')` (`controller_law.m:222`) — supported in restricted forms only, and see EG-40 for the unbounded-extrapolation safety defect. | `controller_law.m:222` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-28** | `find(..., 1, 'last')` / `find(..., 1, 'first')` returning possibly-empty results, then repaired by `isempty` (`guidance_law.m:324–327,361–362`). Variable-size intermediates in the core. | `guidance_law.m:324–327,361–362` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-29** | `deg2rad` / `rad2deg` are used pervasively **inside the hot path** to express constants: `guidance_law.m:27,28,204,223,229,246,258,261,270`; `controller_law.m:64,65,83,87,94,101,112,127,149,150`. These are trivially constant-foldable but presently evaluated per step. | as listed | **COSMETIC** | IMPLEMENTED |
| **EG-30** | `exp()` evaluated every controller step at `controller_law.m:76` (`a_rate = exp(-dt/tau_rate)`) with both operands constant between reconfigurations. A transcendental in the inner loop that should be precomputed. | `controller_law.m:57,76` | **TARGET_DEPENDENT** | DERIVED |
| **EG-31** | Positive finding: the core candidates otherwise use only `sin, cos, atan2, hypot, norm, dot, mod, sqrt`-class operations and scalar arithmetic — all straightforwardly portable. `inertial_velocity_ned` (`continuous_path_tracking.m:228–244`) is pure and fixed-size. | `continuous_path_tracking.m:228–244` | **COSMETIC** (positive) | DERIVED |
| **EG-32** | Non-ASCII, non-English console string at `continuous_path_tracking.m:183` ("Simülasyon adımı"). Encoding hazard in any toolchain that assumes ASCII source; also a language-consistency defect in a deliverable. | `continuous_path_tracking.m:183` | **COSMETIC** | IMPLEMENTED (defect) |

---

### A6 — Floating-point and numeric range assumptions

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-33** | **The entire read set assumes IEEE-754 binary64 implicitly.** No type is declared anywhere; every literal is a MATLAB double. There is no single/double policy, no fixed-point candidate, no scaling analysis. Whether the target executes binary64 natively, in software, or must be re-scoped to binary32 is `TO_BE_IDENTIFIED`. | whole read set | **BLOCKER** (policy absent) + **TARGET_DEPENDENT** (resolution) | TO_BE_IDENTIFIED |
| **EG-34** | **NaN is used as a control-flow sentinel.** `guidance_law.m:71–73,79` set `yaw_cont = nan`, `pitch_f = nan`, `chi_f = nan` as "uninitialised" markers, then branch on `isnan` at `:161,177,239`. Under any flush-to-zero / fast-math / abrupt-underflow configuration, or on a reduced-precision path, NaN semantics and NaN propagation are exactly the properties least safe to depend on. A boolean init flag costs nothing and is already the pattern used for `initialized` at `:22`. | `guidance_law.m:71–73,79,161,177,239` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-35** | **Unbounded heading accumulator.** `yaw_cont = yaw_cont + wrapToPi(yaw_raw - yaw_cont)` (`guidance_law.m:180`) and `yaw_out = yaw_out + dy` (`:254`) are deliberately unwrapped and never re-wrapped before being returned as `yaw_ref` (`:263`). On a long or repeatedly-circling mission these grow without bound; absolute angular resolution degrades monotonically with accumulated turns, and the value is then differenced against a wrapped measurement at `controller_law.m:61`. The `wrapToPi` at `:61` rescues correctness, but the magnitude growth itself is unbounded and unmonitored. | `guidance_law.m:180,254,263`; `controller_law.m:61` | **BLOCKER** | DERIVED |
| **EG-36** | **Integrator limits can become effectively infinite.** `int_angle_max = deg2rad(8)/max(Ki_angle,1e-6)` (`controller_law.m:83`) and `int_rate_max = delta_e_I_max/max(Ki_rate,1e-6)` (`:102`). If a gain is set small — or left empty and thus not defaulted, see EG-38 — the guard evaluates to up to `1.4e5` rad and `8.7e4` rad respectively. The clamp is present but its bound is a function of a tunable, so the *state range* is not bounded by design. | `controller_law.m:83,102` | **BLOCKER** | DERIVED |
| **EG-37** | **Curvature reciprocal.** `R_abs = 1/max(abs(kappa_f),1e-4)` (`guidance_law.m:135`) admits `R_abs` up to `1e4` m, which then feeds the speed schedule at `:150`. Guarded against division by zero, but the resulting dynamic range across `:150` is four decades on a value used in a ratio. | `guidance_law.m:133–135,150` | **TARGET_DEPENDENT** | DERIVED |
| **EG-38** | **No parameter-validity check, and empty globals propagate silently.** `delta_r_max`, `delta_e_max`, `thrust_max`, `thrust_min`, `thrust_trim`, `Kp_psi`, `Kd_psi`, `Kp_x`, `Kp_angle`, `Ki_angle`, `Kp_rate`, `Ki_rate`, `Kaw_pitch` are declared at `controller_law.m:12–17` and used at `:63,66,70,82–83,86,102,106,133,136,139,178–179` **with no `isempty` guard**, unlike their neighbours at `:38–57`. If `init_parameters` has not run, MATLAB's `max(min(x,[]),[])` yields empty, so `delta_e_cmd` at `:133` becomes empty and an empty actuator command propagates outward instead of raising a fault or commanding a safe state. Silent degradation to "no command" is the single most dangerous pattern in the read set. | `controller_law.m:12–17,63,66,70,82,83,86,102,106,133,136,139,178,179`; `:217–220` (same pattern for `delta_e_trim`) | **BLOCKER** | DERIVED |
| **EG-39** | **No input finiteness/plausibility validation.** Neither `guidance_law` nor `controller_law` checks any input for NaN, Inf or range. `current_position` (`guidance_law.m:1`), and `psi, theta, r, q, u, phi, w, p` (`controller_law.m:1`) are consumed unchecked. A single non-finite navigation sample poisons `s_prog`, `z_e_i`, `int_angle`, `int_rate` and `rate_filt` permanently, because there is no reset (EG-01/EG-02). | `guidance_law.m:1`; `controller_law.m:1` | **BLOCKER** | DERIVED |
| **EG-40** | **Unbounded table extrapolation.** `interp1(trim_speed_table, trim_elevator_table, u, 'linear','extrap')` (`controller_law.m:222`) extrapolates linearly and without limit outside the trim-speed table. `de_trim` then enters `delta_e_unsat` at `:132`. The outer magnitude clamp at `:133` catches the result, but the *trim* term can consume the whole authority budget at an off-table speed, starving feedback. `'clip'`-style saturation to the table endpoints is the correct behaviour. | `controller_law.m:99,132–133,222` | **BLOCKER** | DERIVED |
| **EG-41** | `eps` is used as a divisor guard at `controller_law.m:66` (`max(e_psi0,eps)`). `eps` is host-double epsilon; under a different working precision the guard changes magnitude by ~9 orders. Constant guards should be explicit literals. | `controller_law.m:66` | **TARGET_DEPENDENT** | DERIVED |
| **EG-42** | Time is accumulated rather than indexed: `total_time = total_time + dt` (`continuous_path_tracking.m:179`). Accumulated rounding versus `idx*dt`. Harness-only, but the same pattern must not survive into the target time base. | `continuous_path_tracking.m:179` | **COSMETIC** | IMPLEMENTED (defect) |

---

### A7 — Sample-time ownership and multirate handoff

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-43** | **No function owns its sample time.** `controller_law` reads `dt = dt_controller` from a global (`controller_law.m:56–58`); `guidance_law` reads `dt_nom = dt_guidance` from a global (`guidance_law.m:32–36`). Neither accepts `dt` as an argument, neither receives a timestamp, and neither can detect that a step was late, early, missed or duplicated. | `controller_law.m:56–58`; `guidance_law.m:32–36` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-44** | **Multirate handoff is an index-modulo in the harness.** `guidance_period = max(1, round(dt_guidance/dt))` (`continuous_path_tracking.m:69`) and `if mod(idx-1, guidance_period) == 0` (`:84`). The rate ratio is rounded, so a non-integer ratio silently becomes an integer one and the guidance loop then integrates with `dt_nom = dt_guidance` (`guidance_law.m:36,194,258,265`) that no longer matches its true call interval. Under a rounded ratio, `z_e_i` (`guidance_law.m:194`), the pitch rate limit (`:258`) and `pitch_ref_dot = dp/dt_nom` (`:265`) are all wrong by the rounding factor. | `continuous_path_tracking.m:69,84`; `guidance_law.m:36,194,258,265` | **BLOCKER** | DERIVED |
| **EG-45** | **Zero-order hold across the rate boundary is implicit and unguarded.** `yaw_ref, pitch_ref, u_ref, r_ff, pitch_ref_dot` are initialised to zero at `continuous_path_tracking.m:68` and simply retained between guidance ticks. There is no hold-age, no freshness stamp, and no maximum-hold-count. If guidance overruns and skips a tick, the controller silently tracks a stale reference forever with no indication. | `continuous_path_tracking.m:68,84–88` | **BLOCKER** | DERIVED |
| **EG-46** | **Filter coefficients are hard-coded rather than derived from `dt`.** Fixed alphas: `0.96/0.04` (`guidance_law.m:134`), `0.93/0.07` (`:147`), `0.28` (`:164`), `0.85/0.15` (`:202`), `0.85/0.15` (`:213`), `0.98/0.02` (`:222`), `0.98` (`:226`), `0.90/0.10` (`:243`), `0.35` (`:252`). Each encodes a bandwidth *only* at the sample rate they were tuned at. Change `dt_guidance` and every guidance bandwidth silently moves, with no warning and no re-derivation. | `guidance_law.m:134,147,164,202,213,222,226,243,252` | **BLOCKER** | DERIVED |
| **EG-47** | Positive finding, and the correct pattern: `controller_law.m:57,76` derive the rate-filter pole from a *physical* time constant, `tau_rate = -0.075/log(0.90)`, then `a_rate = exp(-dt/tau_rate)`. This filter is sample-rate-invariant. Guidance should be reworked to match this pattern. | `controller_law.m:57,76–77` | **COSMETIC** (positive) | IMPLEMENTED |
| **EG-48** | Two different default periods appear in the read set: `controller_law.m:56` and `guidance_law.m:33` both default `dt_controller = 0.0375`, whereas the comment at `continuous_path_tracking.m:69` gives the worked example `0.075/0.025 = 3`. The authoritative rate pair is `TO_BE_IDENTIFIED` from these three files alone. | `continuous_path_tracking.m:69`; `guidance_law.m:33`; `controller_law.m:56` | **BLOCKER** | TO_BE_IDENTIFIED |
| **EG-49** | Jitter, phase offset between the two rates, and guidance/controller execution ordering within a frame are entirely unspecified; the harness enforces "guidance first, same tick" (`continuous_path_tracking.m:84–94`) which is a zero-latency handoff no real scheduler provides. | `continuous_path_tracking.m:84–94` | **TARGET_DEPENDENT** | DERIVED |

---

### A8 — Saturation / rate limiting / anti-windup / bumpless behaviour

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-50** | Magnitude saturation **is** implemented: rudder at `controller_law.m:70`, elevator at `:133`, thrust at `:179`, pitch reference at `guidance_law.m:229,261`, pitch correction at `guidance_law.m:204`, FF clamp at `controller_law.m:128`, climb FF clamp at `:114`, rate command clamp at `:87`, `r_ff` clamp at `guidance_law.m:270`. | as listed | **COSMETIC** (positive) | IMPLEMENTED |
| **EG-51** | Rate limiting **is** implemented: 40 deg/s on both surfaces (`controller_law.m:149–152`), 40 deg/s equivalent on yaw reference (`guidance_law.m:246,252–254`), explicit pitch-reference rate limit (`guidance_law.m:256–261`). | as listed | **COSMETIC** (positive) | IMPLEMENTED |
| **EG-52** | Back-calculation anti-windup on the rate integrator **is** implemented (`controller_law.m:139–142`) plus a soft outer-loop integrator bleed (`:145–147`). | `controller_law.m:139–147` | **COSMETIC** (positive) | IMPLEMENTED |
| **EG-53** | **Anti-windup is applied against magnitude saturation only, not rate saturation.** `aw_err = delta_e_cmd - delta_e_unsat` (`controller_law.m:140`) is computed *before* the rate limiter at `:152`. When the command is rate-limited but not magnitude-limited, `aw_err == 0`, the integrator sees no saturation, and it winds up against a limit the anti-windup cannot see. Given the tight 40 deg/s rate limit, rate saturation is the *likely* dominant limiter. | `controller_law.m:133,140–142,149–152` | **BLOCKER** | DERIVED |
| **EG-54** | **The rudder channel has no integrator and no anti-windup, but the yaw path does saturate** (`controller_law.m:70`) and then rate-limits (`:151`). No windup risk, but also no saturation indication to guidance — guidance keeps commanding `yaw_ref` (`guidance_law.m:263`) with no knowledge that rudder authority is exhausted. This is precisely the carried R1 rudder-rail concern, visible here as a missing feedback path. | `controller_law.m:63–70,151`; `guidance_law.m:263` | **BLOCKER** | DERIVED |
| **EG-55** | **The guidance depth integrator has no anti-windup at all.** `z_e_i = z_e_i + z_e_f*dt_nom` clamped to ±25 (`guidance_law.m:194–195`), feeding `pitch_corr` which is itself clamped to ±9° (`:204`) and then `pitch_raw` clamped to `pitch_ref_max` (`:229`) and rate-limited at `:256–261`. Three cascaded saturations downstream of an integrator with no back-calculation. Classic windup topology. | `guidance_law.m:194–195,203–204,229,256–261` | **BLOCKER** | DERIVED |
| **EG-56** | **No bumpless transfer anywhere.** There is no mode concept, therefore no mode transition, therefore no state pre-loading on engage. Because `prev_delta_e/prev_delta_r` and all integrators persist un-reset (EG-01/EG-02), re-engagement after any interruption resumes from stale state — the worst of both worlds: neither bumpless nor reset. | `controller_law.m:23–25,151–154`; `guidance_law.m:21` | **BLOCKER** | DERIVED |
| **EG-57** | **Saturation state is not exported except into the optional debug struct.** `mag_sat` exists only at `controller_law.m:202` and only when `nargout >= 4`. Production three-output callers — which is exactly what `continuous_path_tracking.m:91` is — obtain no saturation flag at all. | `controller_law.m:181,202`; `continuous_path_tracking.m:91–94` | **BLOCKER** | DERIVED |
| **EG-58** | Rate-limit and magnitude-limit constants are duplicated as literals rather than shared: `deg2rad(40)` appears at `controller_law.m:149,150` and `guidance_law.m:246,270`; `delta_r_max`/`delta_e_max` are globals. Two sources of truth for actuator authority. | `controller_law.m:149,150`; `guidance_law.m:246,270` | **COSMETIC** | IMPLEMENTED (defect) |

---

### A9 — FDIR / watchdog integration

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-59** | **There is no FDIR interface in the read set.** No fault input, no fault output, no health word, no degraded-mode input, no safe-state command, no `fail_silent` output. The only fault-shaped construct in all three files is the harness `try/catch` at `continuous_path_tracking.m:100–116`, whose entire fault response is: print two lines (`:104–106`), truncate the log arrays (`:107–114`), and `break` (`:115`). | `continuous_path_tracking.m:100–116` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-60** | **No watchdog kick, no deadline check, no overrun detection, no liveness counter** anywhere in the three files. The carried Gate 7 FDIR result (simulation scope) is not represented in this code path at all — nothing in these three files consumes or produces an FDIR signal. | whole read set | **BLOCKER** | DERIVED |
| **EG-61** | **No safe-state definition.** On any abnormality the code has no defined output vector. Combined with EG-38 (empty propagation) the current de facto failure mode is "emit empty/garbage and continue", not "emit a defined safe command". | `controller_law.m:133,151–152,178–179` | **BLOCKER** | DERIVED |
| **EG-62** | The guidance monotonic-progress logic contains implicit plausibility rejection — a large backward arc-length snap is ignored (`guidance_law.m:96–101`) and backward motion is limited to 5 cm (`:103`). This is a *behavioural* reasonableness check with no fault reporting: an anomaly is absorbed silently rather than annunciated. | `guidance_law.m:95–105` | **BLOCKER** | DERIVED |

---

### A10 — Estimator-vs-truth inputs

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-63** | **Every control input is plant truth.** `continuous_path_tracking.m:72–77` reads position, orientation, body rates and body velocities straight from the ode45 state vector `state`, and `:80` computes inertial velocity from the same truth. Guidance receives truth position/velocity (`:85–87`); the controller receives truth attitude and rates (`:91–94`). There is no noise, no bias, no latency, no dropout, no quantisation and no estimator between plant and law. **All closed-loop performance evidence carried from earlier gates is therefore truth-fed, and the achievable performance with a real estimator is `TO_BE_IDENTIFIED`.** This is the code-level manifestation of carried risk R5. | `continuous_path_tracking.m:72–77,80,85–94` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-64** | **Sideslip is computed from truth body velocities.** `beta = atan2(v_body, max(u_body,0.35))` (`guidance_law.m:168`) with `k_beta = 1.35` (`:169`) applied directly into the yaw reference (`:173`). Lateral velocity `v` is among the hardest quantities to estimate on a vehicle of this class; a gain of 1.35 on a truth-fed `beta` is an unquantified sensitivity. | `guidance_law.m:168–173`; `continuous_path_tracking.m:76,86` | **BLOCKER** | DERIVED |
| **EG-65** | **Flight-path angle feedback is truth-fed.** `gamma_actual = atan2(zdot_inertial, U_h_safe)` (`guidance_law.m:210`) where `zdot_inertial` and `U_h` come from the exact rotation of truth body velocity (`continuous_path_tracking.m:80,228–244`). The alpha estimator `alpha_hat = 0.98*alpha_hat + 0.02*alpha_eff` (`guidance_law.m:222`) is a filter over a truth difference, not an observer. | `guidance_law.m:199–222`; `continuous_path_tracking.m:80,228–244` | **BLOCKER** | DERIVED |
| **EG-66** | **No input carries a covariance, quality, validity or age field.** Guidance and controller signatures (`guidance_law.m:1`, `controller_law.m:1`) are bare doubles. There is no mechanism by which degraded navigation could cause the law to soften gains, hold, or hand over. | `guidance_law.m:1`; `controller_law.m:1` | **BLOCKER** | DERIVED |
| **EG-67** | The `nargin` fallbacks in `guidance_law.m:41–51` substitute `u_body = 1.0`, `v_body = 0.0`, `zdot_inertial = 0`, `theta_phys = 0` when arguments are absent. On a target, "argument absent" and "sensor dead" are indistinguishable, and the defaults are *plausible values*, not safe values — a dead surge sensor yields a confident 1.0 m/s. | `guidance_law.m:41–51`; `controller_law.m:41–45` | **BLOCKER** | DERIVED |

---

### A11 — Actuator feedback

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-68** | **No actuator feedback exists.** `controller_law` has no input for measured surface position, measured thrust, motor current, temperature, servo health or actuator saturation status; its full input list is `yaw_ref, pitch_ref, u_ref, psi, theta, r, q, u, r_ff, pitch_ref_dot, phi, w, p` (`controller_law.m:1`). The control loop is open at the actuator. | `controller_law.m:1` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-69** | **The rate limiter is a *model* of the actuator, not a *response* from it.** `delta_e = prev_delta_e + clamp(delta_e_cmd - prev_delta_e, ±40°/s·dt)` (`controller_law.m:149–152`) advances an internal belief of surface position. If the physical surface stalls, jams, or slews slower than 40 deg/s, `prev_delta_e` diverges from reality permanently and every subsequent command is anchored to a fiction. | `controller_law.m:149–154` | **BLOCKER** | DERIVED |
| **EG-70** | Actuator dynamics are absent from the read set entirely: `continuous_path_tracking.m:96–98` passes commanded deflections directly to the plant. Any actuator lag, deadband, backlash, resolution or hysteresis is outside these three files and its effect on the carried results is `TO_BE_IDENTIFIED` here. | `continuous_path_tracking.m:96–98,101` | **EXTERNAL_HIL** | TO_BE_IDENTIFIED |
| **EG-71** | Numeric actuator characteristics — servo time constant, achievable slew, deadband, position-sensor resolution, thrust curve, current draw — are all `TO_BE_IDENTIFIED` and require a bench. | — | **EXTERNAL_HIL** | TO_BE_IDENTIFIED |

---

### A12 — Transport schema: version / timestamp / sequence / validity / heartbeat / stale / frame / unit / log keys

Assessed per boundary. **Not one boundary in the read set carries any of the nine required fields.**

| Boundary | Version | Timestamp | Sequence | Validity | Heartbeat | Stale rule | Frame | Unit | Log key |
|---|---|---|---|---|---|---|---|---|---|
| Mission → Guidance (`path` arg, `guidance_law.m:1`) | absent | absent | absent | absent | absent | absent | implied NED, undeclared | implied m, undeclared | absent |
| Guidance → Controller (`continuous_path_tracking.m:85–94`) | absent | absent | absent | absent | absent | absent | mixed, see EG-74 | rad, rad/s, m/s — comment-only | globals only |
| Navigation → Guidance/Controller (`continuous_path_tracking.m:72–94`) | absent | absent | absent | absent | absent | absent | body vs NED, comment-only | comment-only | absent |
| Controller → Actuator (`controller_law.m:1` returns; `continuous_path_tracking.m:96–98`) | absent | absent | absent | absent | absent | absent | surface-fixed, undeclared | rad, N (assumed) | globals only |
| Actuator → Controller | **boundary does not exist** (EG-68) | — | — | — | — | — | — | — | — |

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-72** | **No schema, no version field, no timestamp, no sequence number, no validity/quality bit, no heartbeat and no stale rule at any of the four existing boundaries.** All inter-module data is passed as positional bare doubles or via globals. This is the largest single block of missing work for embedded transfer. | `guidance_law.m:1`; `controller_law.m:1`; `continuous_path_tracking.m:85–98` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-73** | **Log keys exist only as global variable names.** 28 `suite_*` globals (`continuous_path_tracking.m:189–225`) and ~26 `last_*` globals (`guidance_law.m:231–238`; `controller_law.m:156–176`). Names are the schema. There is no key registry, no type, no unit, no scaling, no ID, and no stable ordering — so no twin-log key set can be guaranteed identical between host and target. | `continuous_path_tracking.m:189–225`; `guidance_law.m:231–238`; `controller_law.m:156–176` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-74** | **Frame and sign conventions are carried in comments only, and they are non-trivial.** `theta_phys = -theta` (`controller_law.m:73`, documented `:3`); `theta_phys_dot = -q*cos(phi) + r*sin(phi)` (`:74`, documented `:4`); `cte(3) = z_veh - z_path` with the sign argument spelled out at `guidance_law.m:192–193`; `zd_e_raw = zdot_inertial - zdot_path` "vehicle-minus-path (like cte)" (`:201`); `elevator_sign` as a ±1 global from an open-loop test (`controller_law.m:17,46,107,136`). Every one of these is a sign convention that a transfer will get wrong if the comment is lost. **A sign error in `theta_phys` or `elevator_sign` is a positive-feedback pitch divergence.** | `controller_law.m:3,4,17,46,73,74,107,136`; `guidance_law.m:192–193,201` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-75** | Units are consistent internally (SI, radians, seconds) as far as can be checked, with `deg2rad` used at every degree-valued literal. `r_ff` is a rate clamped as `deg2rad(40)` rad/s (`guidance_law.m:270`) and consumed as a rate at `controller_law.m:62` — dimensionally consistent. No unit defect found. | `guidance_law.m:270`; `controller_law.m:62` | **COSMETIC** (positive) | DERIVED |
| **EG-76** | Transport medium, bus, payload encoding, endianness, alignment, CRC and transport-delay budget are all `TO_BE_IDENTIFIED` and cannot be defined before the target and board are known. | — | **TARGET_DEPENDENT** | TO_BE_IDENTIFIED |

---

### A13 — WCET / stack / heap observability

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-77** | **Guidance execution time is data-dependent and unbounded in the path length.** Every guidance tick re-executes: `path_arclength` — full O(n) loop plus an O(n) allocation (`guidance_law.m:62,283–293`); `project_on_path`/`project_interval` — a segment loop whose bounds come from `find` over the whole node table (`:299–351`); `sample_path` ×4 (`:111,118,126,128` plus 2 inside `path_curvature_at` at `:384–385`); and `sum(s_nodes <= s_prog)` — another O(n) reduction (`:276`). None of this is cached between ticks even though `s_nodes` cannot change unless `path` changes. **WCET therefore scales with waypoint count, which is itself unbounded (EG-19).** | `guidance_law.m:62,111,118,126,128,276,283–293,299–351,384–385` | **BLOCKER** | DERIVED |
| **EG-78** | The `project_interval` inner loop (`guidance_law.m:331–350`) has an early-`continue` at `:335` and `:343`, so iteration cost varies with geometry; worst case is the full window `i0:i1` which under the `s_hi = s_prog + max(3.0, 2.5*L)` window (`:85`) grows with the lookahead parameter. Worst-case window size is `TO_BE_IDENTIFIED`. | `guidance_law.m:85,331–350` | **BLOCKER** | DERIVED |
| **EG-79** | **Controller execution time is, by contrast, straight-line and bounded.** `controller_law.m:59–179` has exactly two data-dependent branches (`:92` on `Kd_rate>0`, `:122` on `G_de`/`lambda`) and one call with unknown cost (`lookup_elevator_trim` → `interp1`, `:99,222`). Excluding `interp1` and `exp` (`:76`), the controller is a fixed-cost block. **This is the single most transfer-ready control unit in the read set.** | `controller_law.m:59–179` | **COSMETIC** (positive) | DERIVED |
| **EG-80** | **No timing instrumentation of any kind.** No cycle counter, no execution-time measurement, no deadline flag, no overrun counter, no jitter measurement, no CPU-utilisation output. Nothing in the three files can report how long it took to run. | whole read set | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-81** | **No stack observability.** Call depth is shallow and bounded (`guidance_law` → `project_on_path` → `project_interval`, depth 3; `path_curvature_at` → `sample_path`, depth 2), and no recursion exists — a genuinely favourable property. But no stack budget, high-water mark or guard is defined. | `guidance_law.m:299–318,320–351,381–394` | **TARGET_DEPENDENT** | DERIVED |
| **EG-82** | **No heap observability and no static-allocation guarantee** (see EG-17, EG-19, EG-20, EG-21). | — | **BLOCKER** | DERIVED |
| **EG-83** | Absolute WCET numbers, stack sizes, heap footprint, cache behaviour, FPU throughput and achievable control frequency are all `TO_BE_IDENTIFIED` pending the exact part and board. | — | **TARGET_DEPENDENT** | TO_BE_IDENTIFIED |

---

### Test seams and twin equivalence (cross-cutting, A1/A12/A13)

| ID | Finding | Lines | Class | Label |
|---|---|---|---|---|
| **EG-84** | **The only test seam that exists is the `nargout>=4` debug struct** (`controller_law.m:181–213`, 27 fields). It is opt-in, changes the function's output arity, and is not available to the production three-output call at `continuous_path_tracking.m:91`. Guidance has no equivalent seam at all — its internals are observable only by reading globals (`guidance_law.m:231–238`). | `controller_law.m:181–213`; `guidance_law.m:231–238`; `continuous_path_tracking.m:91` | **BLOCKER** | IMPLEMENTED (defect) |
| **EG-85** | **Host/target twin equivalence is currently untestable.** Equivalence requires: identical initial state (blocked by EG-01/EG-02, no reset), identical inputs at identical times (blocked by EG-43/EG-45, no timestamps), identical parameters (blocked by EG-11/EG-12, self-mutating globals), and a stable comparable log key set (blocked by EG-73). **All four preconditions fail.** No twin-equivalence criterion, tolerance band or comparison harness exists in the read set. | see referenced findings | **BLOCKER** | DERIVED |
| **EG-86** | No unit-test entry point, no golden-vector file, no injectable clock, no injectable parameter set, and no seam for forcing saturation, fault or stale conditions appears in any of the three files. | whole read set | **BLOCKER** | DERIVED |

---

## 4. Finding roll-up

### 4.1 By classification

| Classification | Count | Finding IDs |
|---|---|---|
| **BLOCKER** | **51 findings**, of which **14 are distinct software/safety blocker classes** (see 4.2) | EG-01,02,03,04,06,07,08,09,10,11,12,13,14,15,17,18,19,20,21,23,24,25,26,27,28,33,34,35,36,38,39,40,43,44,45,46,48,53,54,55,56,57,59,60,61,62,63,64,65,66,67,68,69,72,73,74,77,78,80,82,84,85,86 |
| **TARGET_DEPENDENT** | 8 | EG-22,30,37,41,49,76,81,83 |
| **EXTERNAL_HIL** | 2 | EG-70,71 |
| **COSMETIC** | 10 | EG-05,16,29,31,32,42,47,50,51,52,58,75 (6 of these are positive findings) |

### 4.2 The 14 distinct software/safety BLOCKER classes

Every one of these is host-side and target-independent. **None is closed by supplying a part number.**

| # | Blocker class | Representative findings | Why it is safety-relevant |
|---|---|---|---|
| **B01** | No deterministic init/step/reset API; `persistent` state survives across missions | EG-01, EG-02, EG-03, EG-04 | Second mission starts with first mission's integrators and last surface command. |
| **B02** | Navigation layer absent; all control inputs are plant truth | EG-06, EG-63, EG-64, EG-65 | All carried performance evidence is truth-fed; real-estimator performance unknown. |
| **B03** | Mission and Actuator layers are not interfaces | EG-07, EG-08, EG-68 | No arm/abort/hold; no actuator feedback; loop open at the actuator. |
| **B04** | Global-variable parameter and diagnostic coupling; functions mutate their own config | EG-11, EG-12, EG-13, EG-14, EG-15 | Configuration is unverifiable and non-reproducible; no redundant lanes possible. |
| **B05** | Dynamic/variable-size memory; unbounded `path`; per-tick allocation | EG-17, EG-18, EG-19, EG-20, EG-21, EG-82 | No static allocation guarantee; fault path reallocates. |
| **B06** | Host-only constructs in the harness step driver (`ode45`, `try/catch`, `fprintf`) | EG-23, EG-24, EG-25 | Current entry point is structurally non-transferable. |
| **B07** | Non-base-language / restricted calls inside the *core* (`wrapToPi`, `interp1`, `find`) | EG-26, EG-27, EG-28 | Core cannot be lifted as-is even after harness removal. |
| **B08** | NaN used as control-flow sentinel; no FP policy | EG-33, EG-34 | Depends on the least-portable FP semantics; init logic can silently break. |
| **B09** | Unbounded numeric ranges: heading accumulator, gain-dependent integrator limits | EG-35, EG-36, EG-37 | State magnitude not bounded by design. |
| **B10** | No parameter validity check, no input validity check; empty/non-finite values propagate to actuator commands | EG-38, EG-39, EG-61 | **Highest-severity item.** Silent degradation to empty/poisoned commands with no fault. |
| **B11** | Sample time owned by globals; rounded multirate ratio; unguarded ZOH; dt-baked filter coefficients | EG-43, EG-44, EG-45, EG-46, EG-48 | Change the rate and every guidance bandwidth and integrator silently changes. |
| **B12** | Anti-windup blind to rate saturation; guidance depth integrator has no anti-windup; no bumpless transfer; saturation not exported | EG-53, EG-54, EG-55, EG-56, EG-57 | Windup against the dominant limiter; re-engagement transients. |
| **B13** | No FDIR interface, no watchdog, no deadline/overrun detection, no safe state; anomalies absorbed silently | EG-59, EG-60, EG-61, EG-62, EG-80 | No fault is detectable, annunciable or accommodatable in this code path. |
| **B14** | No transport schema at any boundary (version/timestamp/sequence/validity/heartbeat/stale/frame/unit/log key); sign conventions comment-only; twin equivalence untestable | EG-72, EG-73, EG-74, EG-84, EG-85, EG-86 | Sign-convention loss is a divergence hazard; host/target equivalence cannot be demonstrated. |

### 4.3 Label distribution

| Label | Count | Meaning in this audit |
|---|---|---|
| IMPLEMENTED | 34 | Property or defect directly present in read lines. |
| DERIVED | 34 | Established by reasoning over read lines. |
| ASSUMED | 0 in findings; 6 in the manifest | No behavioural finding rests on an assumption. |
| TO_BE_IDENTIFIED | 11 in findings; 15 in the manifest | Not determinable from the three sources. |

---

## 5. Embedded handoff manifest

Contract that a transfer would have to satisfy. **Status column is the honest current state, from the three read sources only.**

### 5.1 Software units

| M-ID | Unit | Source lines | Deploy? | Status | Class | Label |
|---|---|---|---|---|---|---|
| M-01 | `inertial_velocity_ned` | `continuous_path_tracking.m:228–244` | YES | Pure, fixed-size, transferable as-is | — | IMPLEMENTED |
| M-02 | `controller_law` core math | `controller_law.m:59–179` | YES | Straight-line, bounded cost; blocked only by B04/B07/B10/B11/B12 | BLOCKER | IMPLEMENTED |
| M-03 | `lookup_elevator_trim` | `controller_law.m:216–223` | YES | Must replace `'extrap'` with endpoint clamp; bound table size | BLOCKER | IMPLEMENTED |
| M-04 | `guidance_law` core math | `guidance_law.m:52–279` | YES | Blocked by B04/B05/B07/B08/B09/B11/B12 and WCET (EG-77) | BLOCKER | IMPLEMENTED |
| M-05 | Path geometry helpers | `guidance_law.m:283–394` | YES | Pure but O(n) per tick; needs cached arc-length table | BLOCKER | IMPLEMENTED |
| M-06 | `controller_law` debug struct | `controller_law.m:181–213` | NO (as-is) | Convert to a fixed, always-emitted telemetry record | BLOCKER | IMPLEMENTED |
| M-07 | Harness loop | `continuous_path_tracking.m:1–226` | NO | Simulation only | — | IMPLEMENTED |
| M-08 | Plant `underwater777_vehicle_dynamics` | called `:101` | NO | Simulation plant; not read | — | TO_BE_IDENTIFIED |
| M-09 | Estimator / navigation unit | — | REQUIRED | **Does not exist** | BLOCKER | TO_BE_IDENTIFIED |
| M-10 | Mission manager unit | — | REQUIRED | **Does not exist in read set** | BLOCKER | TO_BE_IDENTIFIED |
| M-11 | FDIR / watchdog unit | — | REQUIRED | **Does not exist in read set** | BLOCKER | TO_BE_IDENTIFIED |
| M-12 | Actuator driver + feedback unit | — | REQUIRED | **Does not exist** | BLOCKER | TO_BE_IDENTIFIED |

### 5.2 Interface contract

| M-ID | Item | Current state | Required | Class | Label |
|---|---|---|---|---|---|
| M-13 | Mission→Guidance signal set | bare `path` array, `guidance_law.m:1` | typed record + 9 transport fields | BLOCKER | IMPLEMENTED |
| M-14 | Guidance→Controller signal set | 6 bare doubles, `guidance_law.m:1` / `continuous_path_tracking.m:85–94` | typed record + 9 transport fields | BLOCKER | IMPLEMENTED |
| M-15 | Nav→Guidance/Controller signal set | truth slices, `continuous_path_tracking.m:72–77` | estimate + covariance/quality + age | BLOCKER | IMPLEMENTED |
| M-16 | Controller→Actuator signal set | 3 bare doubles, `controller_law.m:1` | command record + arm + safe-state | BLOCKER | IMPLEMENTED |
| M-17 | Actuator→Controller feedback | **absent** | position, current, health, saturation | BLOCKER | TO_BE_IDENTIFIED |
| M-18 | Version field, all boundaries | absent | present | BLOCKER | TO_BE_IDENTIFIED |
| M-19 | Timestamp field, all boundaries | absent | present, common time base | BLOCKER | TO_BE_IDENTIFIED |
| M-20 | Sequence field, all boundaries | absent | present, gap-detecting | BLOCKER | TO_BE_IDENTIFIED |
| M-21 | Validity/quality field | absent | present | BLOCKER | TO_BE_IDENTIFIED |
| M-22 | Heartbeat | absent | present per producer | BLOCKER | TO_BE_IDENTIFIED |
| M-23 | Stale rule + hold-age limit | implicit ZOH, `continuous_path_tracking.m:68,84` | explicit max-hold, fail-silent on expiry | BLOCKER | DERIVED |
| M-24 | Frame declarations | comments only, `controller_law.m:3–4`; `guidance_law.m:192–193,201` | machine-checkable | BLOCKER | IMPLEMENTED |
| M-25 | Unit declarations | comments only | machine-checkable | BLOCKER | IMPLEMENTED |
| M-26 | Log key registry | global names, `continuous_path_tracking.m:189–225` | stable IDs, types, units, scaling | BLOCKER | IMPLEMENTED |

### 5.3 Timing, memory and numerics

| M-ID | Item | Current state | Class | Label |
|---|---|---|---|---|
| M-27 | Controller period | global `dt_controller`, default 0.0375 s (`controller_law.m:56`) | BLOCKER (ownership) | IMPLEMENTED |
| M-28 | Guidance period | global `dt_guidance` (`guidance_law.m:32–36`); harness example implies 3:1 (`continuous_path_tracking.m:69`) | BLOCKER (ambiguous, EG-48) | ASSUMED |
| M-29 | Rate-ratio integrality | rounded, unchecked (`continuous_path_tracking.m:69`) | BLOCKER | IMPLEMENTED |
| M-30 | Controller WCET | not measured, not measurable | TARGET_DEPENDENT | TO_BE_IDENTIFIED |
| M-31 | Guidance WCET | data-dependent, unbounded in `n` (EG-77) | BLOCKER + TARGET_DEPENDENT | DERIVED |
| M-32 | Max waypoint count | **undefined** | BLOCKER | TO_BE_IDENTIFIED |
| M-33 | Stack budget / high-water | undefined; recursion-free, depth ≤ 3 | TARGET_DEPENDENT | DERIVED |
| M-34 | Heap policy | none; per-tick allocation present | BLOCKER | DERIVED |
| M-35 | FP format policy | implicit binary64, undeclared | BLOCKER + TARGET_DEPENDENT | ASSUMED |
| M-36 | FP mode (rounding, FTZ/DAZ, fast-math) | undeclared; NaN-sentinel logic is sensitive to it (EG-34) | TARGET_DEPENDENT | TO_BE_IDENTIFIED |
| M-37 | Actuator authority limits | `delta_r_max`, `delta_e_max` globals, values not in read set; rate 40 deg/s literal (`controller_law.m:149–150`) | BLOCKER (dual source of truth) | ASSUMED |
| M-38 | Thrust limits | `thrust_max`, `thrust_min`, `thrust_trim` globals, values not in read set | BLOCKER | TO_BE_IDENTIFIED |
| M-39 | Transport medium / encoding / CRC | undefined | TARGET_DEPENDENT | TO_BE_IDENTIFIED |
| M-40 | Twin-equivalence criterion + tolerance | undefined; four preconditions fail (EG-85) | BLOCKER | TO_BE_IDENTIFIED |
| M-41 | Actuator bench characteristics | undefined | EXTERNAL_HIL | TO_BE_IDENTIFIED |
| M-42 | Sensor bench characteristics | undefined | EXTERNAL_HIL | TO_BE_IDENTIFIED |

**Manifest completeness: INCOMPLETE.** 42 rows; 15 `TO_BE_IDENTIFIED`, 6 `ASSUMED`-or-partial, 4 units that must exist and do not (M-09 through M-12).

---

## 6. Fix-order recommendation (host-side, no target needed)

Ordered by safety leverage, not by effort. **This is a recommendation, not an authorisation to edit.**

1. **B10** — parameter and input validity checks; define and emit a safe-state command. Removes the silent-empty-command path (EG-38) and the poisoned-state path (EG-39).
2. **B01** — explicit `init` / `reset` / `step` APIs for both laws; eliminate `persistent`.
3. **B04** — replace all globals with an explicit, versioned parameter struct passed in; stop functions mutating their own config.
4. **B11** — pass `dt` as an argument; re-derive every guidance filter coefficient from `dt` and a physical time constant, following the pattern already correct at `controller_law.m:57,76`; reject non-integral rate ratios.
5. **B14** — define the transport schema and the sign/frame/unit contract; make `elevator_sign` and `theta_phys` conventions machine-checkable.
6. **B12** — move anti-windup after the rate limiter; add back-calculation to the guidance depth integrator; export saturation flags on the production interface.
7. **B13** — define the FDIR interface, watchdog kick, deadline/overrun counters and the safe state.
8. **B05 / B07 / B08 / B09** — bound `path`, cache the arc-length table, replace `wrapToPi`/`interp1`/`find`, replace NaN sentinels with boolean flags, bound the heading accumulator and the integrator limits.
9. **B02 / B03** — introduce the navigation, mission and actuator-feedback interfaces; re-run all closed-loop evidence estimator-fed rather than truth-fed.
10. **B06** — build a fixed-step, allocation-free step driver to replace the `ode45` harness as the equivalence reference.

Only after items 1–10 are dispositioned does target selection become the next meaningful question.

---

## 7. Terminal state and constraints

**State: `AWAIT_STM32_EXACT_PART_NUMBER`.**

Explicitly, and without exception:

- **Target work remains FORBIDDEN.** No target adaptation, no toolchain selection, no codegen configuration, no board bring-up, no pin/peripheral mapping, no RTOS choice, no driver work, no timing budget allocation and no procurement action may begin until **both** of the following hold:
  1. the user supplies the **exact target part number and the exact board**; and
  2. **each of the 14 BLOCKER classes B01–B14 has been individually dispositioned** (fixed, formally waived with recorded residual risk, or explicitly deferred with an owner).
- Supplying a part number alone does **not** unblock. The 14 blockers are host-side and target-independent.
- **No MCU family, vendor, brand, board, part number or supplier is named in this document**, and none may be inferred from it.
- Gate 9 disposition is unchanged: **RC_NOT_GRANTED, R1–R8 OPEN, exact target ABSENT.** Gate 9B adds a fifteenth open item in substance: the deployable control core is not yet separable from the simulation.
- **Simulation is not hardware certification. NOT_CERTIFIED.**

---

## 8. Integrity and fingerprints

### 8.1 Production sources — verified UNTOUCHED

Read-only access; identical SHA-256 before and after this task.

| File | Bytes | SHA-256 | State |
|---|---|---|---|
| `continuous_path_tracking.m` | 10845 | `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b` | **UNTOUCHED** |
| `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` | **UNTOUCHED** |
| `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` | **UNTOUCHED** |

### 8.2 CODEX plan — verified UNTOUCHED

| File | Bytes | SHA-256 | State |
|---|---|---|---|
| `suite_results/CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` | **UNTOUCHED — not read, not written** |

### 8.3 Evidence preservation

No file was deleted, renamed, moved, truncated or overwritten in this task. All writes were **append-only** except the creation of this report. All prior `suite_results/*` evidence is preserved.

### 8.4 Changed files in this task

Post-write fingerprints for the five append targets are recorded in §8.5. This report's own fingerprint is published in the executing session summary, since it cannot self-reference its own hash.

| File | Action |
|---|---|
| `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md` | **created** (this report) |
| `suite_results/AUV_REALIZATION_READINESS_PLAN.md` | **appended** (plan) |
| `suite_results/AUTONOMOUS_EXECUTION_POLICY.md` | **appended** (policy) |
| `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md` | **appended** (realism log) |
| `suite_results/PITCH_CONTROL_RESEARCH_LOG.md` | **appended** (research log) |
| `suite_results/STATE_SPACE_MODEL_AUDIT.md` | **appended** (model/state log) |

Append targets were written **without being read**; each received the identical summary block. No other file was modified.

### 8.5 Append-target fingerprints, before and after

Each target grew by exactly **9472 bytes** — the size of the shared summary block — which is itself the append-only proof.

| File | Bytes before | Bytes after | Δ | SHA-256 before | SHA-256 after |
|---|---|---|---|---|---|
| `suite_results/AUV_REALIZATION_READINESS_PLAN.md` | 106683 | 116155 | +9472 | `211ce5c8ed28b28885a3d629d8b6bfd1897ed9d8692e40ae212285c1c6c925ec` | `24cee350c9bb76460d8e8b3d949158d93392a92f31fd8ce528a7bc6caf151f22` |
| `suite_results/AUTONOMOUS_EXECUTION_POLICY.md` | 25450 | 34922 | +9472 | `0d8996a4d91d5e051e687d4c9d120f8ee7f4e89b8279d188961fb589961b8684` | `93f1f83717720e43e296aff141de09a93fde015637b3815f92c7d6d1d4641255` |
| `suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md` | 77517 | 86989 | +9472 | `2093c1dc58024330324c46eef54a309edaac2dc157b8ccbb06468ddede3abe51` | `02923eb2aee0a83d6b1f8f277fc2b4e4d665f34d8cbd6544c72761e6c080022a` |
| `suite_results/PITCH_CONTROL_RESEARCH_LOG.md` | 102542 | 112014 | +9472 | `50191dd056f0b97069be2a8fcffa15d4f513f0bf7ba21e4807a2d5c7630952d6` | `f53e6d4adce14a71cea20363dd5737e0a35bfdb5abe78adb66f0dcbf144fbc97` |
| `suite_results/STATE_SPACE_MODEL_AUDIT.md` | 79455 | 88927 | +9472 | `076573633fb296858a314f474dc9e735515e31bcc4d941e46cd7aafb7fd39354` | `d14718bea61dc3ba43f72aa794a6220e6e2282a07cb800ed240c83b07878d4e3` |

---

*End of GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT. Verdict: **FAIL**, 14 software/safety BLOCKER classes open, manifest INCOMPLETE, RC_NOT_GRANTED sustained, state `AWAIT_STM32_EXACT_PART_NUMBER`.*
