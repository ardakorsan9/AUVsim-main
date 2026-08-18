# CG_CODEGEN_STATUS

**Track:** MATLAB→C++ pretarget (codegen capability & boundary work)  
**Initialized by:** `CG_PRE0_TOOLCHAIN_CAPABILITY_001`  
**Last update:** 2026-08-10 03:29 (local) / `2026-08-10T00:29:14Z`  
**Hardware:** **NOT_CERTIFIED**  
**CODEX_VERTICAL_PLAN.md:** UNTOUCHED  

Label vocabulary (do not upgrade without new evidence):  
`PRESENT` · `LICENSE_AVAILABLE` · `CONFIGURED` · `MISSING` · `HARDWARE_BLOCKED` · `NOT_CERTIFIED`

---

## Current gate

| Field | Value |
|-------|-------|
| Last TASK_ID | `CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001` |
| Verdict | **PASS** |
| MATLAB invocations (this task) | **1** |
| Next TASK_ID | `CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001` |
| Executable codegen | **BLOCKED** (no C/C++ MEX compiler; CG_PRE0 PARTIAL carried) |
| Static boundary inventory (CG0) | **COMPLETE** |
| Static controller compat (CG1A) | **PARTIAL** — core math OK; architecture blockers prevent lift-as-is |
| Static guidance compat (CG1B) | **PARTIAL** — LOS/pitch algebra OK; path/globals/persistent/find/wrap blockers |
| Static CG1C (nav/FDIR boundary) | **PARTIAL** — reusable EKF/admit/Joseph/FSM/B2 cores; harness ≠ DEPLOY; step APIs spec only |
| Controller golden corpus (CG2A capture) | **PASS** — V1 deterministic MATLAB twin; C++ parity **NOT CLAIMED** |
| Controller explicit-state prototype (CG2A) | **PASS** — `DEPLOY_CANDIDATE/NOT_IN_PRODUCTION`; exact golden `isequaln`; dual reset OK |
| Guidance golden corpus (CG2B capture) | **PASS** — V1 deterministic MATLAB twin; C++ parity **NOT CLAIMED** |
| Target / STM32 adaptation | **FORBIDDEN** (part/board ABSENT + Gate 9B BLOCKERs open) |
| Guidance/Controller API refactor | prototype isolated (controller); guidance production call path **UNTOUCHED** |

Evidence: `suite_results/CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE.md` · `suite_results/CG2B_GUIDANCE_GOLDEN_V1.mat`  
Prior: `suite_results/CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE.md` · `suite_results/CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE.md` · `suite_results/CG1C_NAV_FDIR_RUNTIME_BOUNDARY.md` · `suite_results/CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY.md` · `suite_results/CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY.md` · `suite_results/CG0_CODEGEN_BOUNDARY.md` · `suite_results/CG_PRE0_TOOLCHAIN_CAPABILITY.md`

---

## CG2B guidance golden capture summary

| Item | Result |
|------|--------|
| Corpus | `CG2B_GUIDANCE_GOLDEN_V1` schema 1 · N=102 · 8-input calls · 6 outputs · 11 diagnostics · 16 cases · 8 paths |
| Path storage | padded `MAX_PATH_POINTS=32` ×3 + `n_path`/`path_id`; legacy calls use active rows |
| dt | forced accepted `0.075` s |
| Determinism | identical `reset_before` + `clear guidance_law` dual replay · `isequaln` Y+Diagnostics **PASS** |
| Finite / range / slew / progress | all finite; pitch/r_ff clamps OK; pitch slew OK; open progress nondecreasing |
| Accepted Tur4A/5A/5B | `K_zdot=0`, `K_gamma=0`, `enable_alpha_hat=false`; nonzero zdot/θ_phys/κ exercised |
| Source SHA-256 | `guidance_law.m` / `init_parameters.m` **UNTOUCHED** |
| C++ parity | **NOT CLAIMED** |
| Harness | `run_cg2b_guidance_golden_parity_capture.m` (**SIMULATION_ONLY**) |

---

## CG2A explicit-state prototype summary

| Item | Result |
|------|--------|
| API | `controller_codegen_init/reset/step` fixed Params/State/Input/Output/Debug |
| Params source | golden `params_snapshot` only |
| State reset | deterministic zeros |
| Golden parity | N=100 · exact `isequaln` Output+Debug **PASS** |
| Dual reset replay | A==B **PASS** |
| Bounds / 40°/s slew | **PASS** |
| Label | `DEPLOY_CANDIDATE/NOT_IN_PRODUCTION` |
| TEMPORARY_BLOCKER | `wrapToPi` · fixed-table `interp1` linear/extrap |
| Production | `controller_law.m` **UNTOUCHED** |
| C++ parity | **NOT CLAIMED** |
| Harness | `run_cg2a_controller_explicit_state_prototype.m` (**SIMULATION_ONLY**) |

---

## CG2A golden capture summary

| Item | Result |
|------|--------|
| Corpus | `CG2A_CONTROLLER_GOLDEN_V1` schema 1 · N=100 · 13 inputs · 30 Debug fields · 13 cases |
| dt | forced accepted `0.025` s |
| Determinism | `clear controller_law` + dual replay · `isequaln` Y+Debug **PASS** |
| Finite / bounds / slew | all finite; mag clamps OK; 40°/s slew OK |
| Source SHA-256 | `controller_law.m` / `init_parameters.m` **UNTOUCHED** |
| C++ parity | **NOT CLAIMED** |
| Harness | `run_cg2a_controller_golden_parity_capture.m` (**SIMULATION_ONLY**) |

---

## CG1C nav/FDIR summary

| Class | Result |
|-------|--------|
| Reusable math | 18-state propagate / Joseph update / admit order / USBL optional / availability FSM (health-only) / rudder B2 residual+latch |
| SIMULATION_ONLY | action-string dispatch, batch N-logs, innov/fused growth, metrics/gates/pack/injections, `eig`, truth scoring |
| Target blockers | dynamic structs/cells, NaN sentinels, `error`/`assert`, no nav step API, unbounded prop substeps |
| Future APIs | `nav_init/reset/propagate/update/output`, `availability_step`, `rudder_fdir_init/reset/step` + Params/State/Input/Output/Health — **spec only** |
| DEPLOY claim | **FORBIDDEN** — harness files do not DEPLOY as-is |
| Thresholds | ASSUMED / NOT_CERTIFIED |

---

## CG1B guidance summary

| Class | Result |
|-------|--------|
| Directly codegen-compatible | LOS/course/β/pitch/Tur4A–5B scalar math (after owned wrap) |
| Fixed types/sizes required | `MAX_PATH_POINTS`, cached `s_nodes`, bounded segment search, Debug record |
| Target-architecture blockers | globals, persistent/no-reset, nargin defaults, unbounded path+alloc, `find`/`sum`, `wrapToPi`, NaN sentinels, dt-global, no path validity/seq |
| Hardware-dependent | FP width, absolute WCET vs n — deferred |
| Future step API | specified (`Params`/`State`/`Input`/`Output`/`Debug` + path/angle/segment ownership); **not implemented** |
| Tuning / numerics | frozen accepted LOS guidance; rejected γ-structural/LADRC/INDI/crab-current-FF/polyline closed |
| Golden corpus | **PASS** (CG2B V1) — baseline before explicit-state prototype |

---

## CG1A controller summary

| Class | Result |
|-------|--------|
| Directly codegen-compatible | scalar cascade math `:59–179` (after wrap primitive) |
| Fixed types/sizes required | I/O, trim tables, Debug record, absolute I-limits |
| Target-architecture blockers | globals, persistent/no-reset, nargin/nargout, wrapToPi, interp1 extrap, empty/unguarded params, dt global |
| Hardware-dependent | FP width, `eps`, `exp` WCET, actuator HIL — deferred |
| Future step API | specified (`Params`/`State`/`Input`/`Output`/`Debug`); **prototype implemented CG2A (not production)** |
| Gains / numerics | frozen; rejected methods closed |

---

## CG0 inventory summary

| Primary class | n |
|---------------|--:|
| DEPLOY | 2 |
| SHARED_SUPPORT | 2 |
| SIMULATION_ONLY | 156 |
| ARCHIVE_REJECTED | 18 |
| HARDWARE_BLOCKED (files) | 0 |
| Scoped total | 178 (all `.m`; 0 `.mlx`/`.slx`/`.sldd`) |

**STM32 candidates:** `guidance_law.m`, `controller_law.m` (+ extract `inertial_velocity_ned` from harness).  
**Nav/EKF · Mission · FDIR · allocation · actuator feedback:** not in production runtime graph — evidence/harnesses only (see CG0 §5). **CG1C** mapped reusable cores + missing production units; files remain **non-DEPLOY**.

---

## Component status board

| Component | Status labels | Fingerprint / note |
|-----------|---------------|--------------------|
| MATLAB host | PRESENT · LICENSE_AVAILABLE · CONFIGURED | R2025b Update 5 · `PCWIN64` · `25.2.0.3177638` |
| MATLAB Coder | PRESENT · LICENSE_AVAILABLE · CONFIGURED (API) | `ver` 25.2 · `license('test','MATLAB_Coder')=1` |
| Simulink | PRESENT · LICENSE_AVAILABLE · CONFIGURED | `ver` 25.2 |
| Simulink Coder | LICENSE_AVAILABLE · MISSING (install) | `Real-Time_Workshop` test=1 · **not** in `ver` |
| Embedded Coder | LICENSE_AVAILABLE · MISSING (install) | `RTW_Embedded_Coder` test=1 · **not** in `ver` |
| `codegen` API | PRESENT · CONFIGURED | `...\matlabcoder\codegen.p` (`exist=6`) |
| `coder` API | PRESENT · CONFIGURED | `...\matlabcoder\coder.p` (`exist=6`) |
| C MEX compiler | MISSING | selected=0 · installed=0 |
| C++ MEX compiler | MISSING | selected=0 · installed=0 |
| Coder smoke (temp) | SKIPPED | reason: would require compiler setup (forbidden) |
| STM32 support packages | MISSING · HARDWARE_BLOCKED | add-on filter hits=0 |
| Exact MCU part/board | MISSING · HARDWARE_BLOCKED | carried `AWAIT_STM32_EXACT_PART_NUMBER` |
| Hardware certification | NOT_CERTIFIED | simulation ≠ certification |
| CG0 boundary inventory | PASS | 178/178 classified; deploy graph explicit |
| CG1A controller static compat | PARTIAL | lift-as-is FAIL; audit complete; API spec only |
| CG1B guidance static compat | PARTIAL | lift-as-is FAIL; audit complete; API spec only |
| CG1C nav/FDIR runtime boundary | PARTIAL | reusable cores mapped; harness ≠ DEPLOY; APIs spec only |
| CG2A controller golden capture | PASS | V1 corpus; deterministic; C++ parity not claimed |
| CG2A controller explicit-state prototype | PASS | DEPLOY_CANDIDATE/NOT_IN_PRODUCTION; exact golden parity |
| CG2B guidance golden capture | PASS | V1 corpus; deterministic; C++ parity not claimed |

---

## Production / plan fingerprints (preserved)

| File | Bytes | SHA-256 |
|------|------:|---------|
| `continuous_path_tracking.m` | 10845 | `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b` |
| `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` |
| `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` |
| `init_parameters.m` | 4205 | `09803f4956b64227403919229781086c367e620f5736cfd680d1b15081237a9a` |
| `suite_results/CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` |

---

## Disk (C: CAUTION)

| When | Avail bytes | Avail GiB |
|------|------------:|----------:|
| Before MATLAB (CG_PRE0) | 4565749760 | 4.2526 |
| After MATLAB (CG_PRE0) | 4554731520 | 4.2424 |
| After CG_PRE0 small text | 4553367552 | 4.2411 |
| CG0 (no MATLAB; text only) | ~4.59e9 | ~4.28 |
| CG1A (no MATLAB; text only) | text evidence only | — |
| CG1B (no MATLAB; text only) | ~4.59e9 / ~4.27 GiB free | CAUTION |
| CG1C (no MATLAB; text only) | text evidence only | CAUTION |
| CG2A (1 MATLAB; lean MAT+JSON+MD) | lean corpus under `suite_results/` | CAUTION |
| CG2A prototype (1 MATLAB; MD+txt) | small text under `suite_results/` | CAUTION |
| CG2B (1 MATLAB; lean MAT+JSON+MD) | lean corpus under `suite_results/` | CAUTION |

Only small evidence under `suite_results/`. No codegen trees / MEX on C:.

---

## History

| UTC / local | TASK_ID | Verdict | Note |
|-------------|---------|---------|------|
| 2026-08-09T22:58:39Z / 2026-08-10 01:59 | `CG_PRE0_TOOLCHAIN_CAPABILITY_001` | PARTIAL | Coder+API OK; compiler MISSING; STM32 packs MISSING; next CG0 inventory |
| 2026-08-09T23:12:00Z / 2026-08-10 02:12 | `CG0_CODEGEN_BOUNDARY_INVENTORY_001` | PASS | 178 classified; deploy graph; next CG1A static controller compat |
| 2026-08-09T23:22:26Z / 2026-08-10 02:22 | `CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001` | PARTIAL | controller core OK; arch blockers; step API spec only; next CG1B guidance |
| 2026-08-09T23:25:13Z / 2026-08-10 02:25 | `CG1B_GUIDANCE_STATIC_CODEGEN_COMPATIBILITY_001` | PARTIAL | guidance LOS OK; path/globals/persistent/find/wrap blockers; API spec only; next CG1C nav/FDIR boundary |
| 2026-08-09T23:42:23Z / 2026-08-10 02:42 | `CG1C_NAV_FDIR_RUNTIME_BOUNDARY_001` | PARTIAL | reusable nav/FSM/B2 cores; harness ≠ DEPLOY; APIs spec only; next golden parity capture |
| 2026-08-10T00:00:34Z / 2026-08-10 03:00 | `CG2A_CONTROLLER_GOLDEN_PARITY_CAPTURE_001` | PASS | V1 golden corpus N=100; det+finite+fingerprint PASS; next explicit-state prototype |
| 2026-08-10T00:14:37Z / 2026-08-10 03:14 | `CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001` | PASS | explicit-state prototype exact golden parity; next guidance golden capture |
| 2026-08-10T00:29:14Z / 2026-08-10 03:29 | `CG2B_GUIDANCE_GOLDEN_PARITY_CAPTURE_001` | PASS | V1 golden corpus N=102; det+finite+fingerprint PASS; next guidance explicit-state prototype |

---

*Append-only updates preferred for subsequent CG_* tasks.*
