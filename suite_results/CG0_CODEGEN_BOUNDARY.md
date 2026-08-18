# CG0_CODEGEN_BOUNDARY

**TASK_ID:** `CG0_CODEGEN_BOUNDARY_INVENTORY_001`  
**Track:** MATLAB→C++ pretarget — codegen boundary inventory (CG0)  
**Executed:** 2026-08-10 02:12 (local) / 2026-08-09T23:12:00Z  
**MATLAB invocations:** **0**  
**Mode:** read-only source inventory · **no** MATLAB · **no** source edits · **no** executable codegen · **no** install/config  
**Hardware:** **NOT_CERTIFIED** · exact part/board ABSENT · STM32 packs MISSING (carried CG_PRE0)  
**Compiler:** MISSING (CG_PRE0 PARTIAL) — does **not** block static CG1  
**Preserved:** production fingerprints + `suite_results/CODEX_VERTICAL_PLAN.md` (**UNTOUCHED — not read, not written**)

**Prior docs read:** `suite_results/CG_PRE0_TOOLCHAIN_CAPABILITY.md`, `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`

---

## 1. Verdict

> ### CG0: **PASS**

Scope complete (root + first-level source dirs; excludes applied). Every scoped file classified (no UNKNOWN). Deploy call graph explicit. No algorithm/source changed. Compiler absence remains PARTIAL for executable codegen but does not block static CG1.

**Next exact task (exactly one):** `CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001`

---

## 2. Scope

| Rule | Result |
|------|--------|
| Extensions | `.m` / `.mlx` / `.slx` / `.sldd` |
| Roots | project root + first-level source directories |
| Excluded | `suite_results/`, `.git/`, codegen/slprj/generated/cache/temp, dot-dirs (`.gate8_*`, `.roll_closure_bak`, `.cursor`, …) |
| First-level source dirs found | `shadow_r10/` (0 matching sources) |
| Scoped files | **178** (all `.m` in project root) |
| `.mlx` / `.slx` / `.sldd` | **0** |
| Full source review (exception to 3-source rule) | 5 files below |
| Remainder | header/call classification only → secondary `NEEDS_CG1_REVIEW` |

### Classification counts

| Primary class | n |
|---------------|--:|
| DEPLOY | 2 |
| SHARED_SUPPORT | 2 |
| SIMULATION_ONLY | 156 |
| ARCHIVE_REJECTED | 18 |
| HARDWARE_BLOCKED | 0 |
| **Total** | **178** |

`HARDWARE_BLOCKED` file count is **0**: target/HW readiness is an **environment** label (CG_PRE0), not a scoped `.m` unit. Hardware remains **NOT_CERTIFIED**.

Full rows: `suite_results/CG0_CODEGEN_MANIFEST.csv`.

---

## 3. Fully reviewed units (5)

| Path | Primary | Role | Risk | Evidence |
|------|---------|------|------|----------|
| `continuous_path_tracking.m` | **SIMULATION_ONLY** | entry | HOST_ONLY_HIGH | continuous_path_tracking.m:6,71,84-101,228-244; Gate9B EG-06/23 |
| `controller_law.m` | **DEPLOY** | entry | HIGH | controller_law.m:1,12-30,23-25,61,222; Gate9B EG-08/EG-26 |
| `guidance_law.m` | **DEPLOY** | entry | HIGH | guidance_law.m:1,13-21,54,164,283-394; Gate9B §2 |
| `init_parameters.m` | **SHARED_SUPPORT** | helper | MED | init_parameters.m:1-18,50-58,74-93; called cpt:6 |
| `underwater777_vehicle_dynamics.m` | **SIMULATION_ONLY** | helper | HOST_ONLY_PLANT | underwater777_vehicle_dynamics.m:1,13-24,93-95; called cpt:101 |

**Colocated note:** `inertial_velocity_ned` (`continuous_path_tracking.m:228–244`) is a **DEPLOY helper candidate** living inside a **SIMULATION_ONLY** entry. File primary remains SIMULATION_ONLY; extract for STM32 in a later CG task.

---

## 4. Deploy call graph (production runtime)

```
[host caller: run_*/test_*]
        |
        v
continuous_path_tracking  (SIMULATION_ONLY entry)
        |-- init_parameters()                 SHARED_SUPPORT
        |-- inertial_velocity_ned()          DEPLOY helper (colocated)
        |-- guidance_law()                   DEPLOY entry
        |      + path_* helpers (same file)
        |-- controller_law()                 DEPLOY entry
        |      + lookup_elevator_trim()
        |-- ode45(@underwater777_vehicle_dynamics)   SIMULATION_ONLY plant
        +-- fprintf / suite_* global logs            SIMULATION_ONLY
```

**STM32 candidate core (inside codegen boundary):** `guidance_law` (+helpers) · `controller_law` (+`lookup_elevator_trim`) · `inertial_velocity_ned` (extract).  
**Outside boundary (host forever):** `continuous_path_tracking` driver · `ode45` · plant · plots · Monte Carlo · suite logging · research `run_*`.

Shared params: `init_parameters` (+ trim tables from `build_pitch_trim_table`) must become a **versioned const parameter block** before transfer (Gate9B B01/B10) — not an STM32 entry by itself.

---

## 5. Runtime units vs evidence/harnesses

| Layer | In production `continuous_path_tracking` graph? | What exists in scoped tree |
|-------|-----------------------------------------------|----------------------------|
| **Guidance** | **YES** — `guidance_law.m` | DEPLOY candidate (host-coupled; Gate9B non-transferable as-is) |
| **Controller** | **YES** — `controller_law.m` | DEPLOY candidate (same) |
| **Navigation / EKF** | **NO** — plant truth sliced at `cpt:72–77` (Gate9B EG-06) | Evidence/harness only: `navigation_multirate_*.m` + `run_nav_*` |
| **Mission** | **NO** — bare `path` arg (EG-07) | Evidence/harness only: `run_gate7_mission_manager_fail_silent_sim.m`, `run_guidance_mission_baseline.m` |
| **FDIR / watchdog** | **NO** (EG-59/EG-60) | Evidence/harness only: `run_gate7_fdir_*`, `isolated_online_rudder_residual_monitor.m`, `run_rudder_*` |
| **Control allocation** | **NO separate unit** — `controller_law` returns `delta_r,delta_e,thrust` directly (`controller_law.m:1`; `cpt:96–98`) | Harness-only “identity allocation” wording in `closed_loop_actuator_realism_case.m` |
| **Actuator feedback** | **NO** (EG-68) — open at actuator | Harness-only: `closed_loop_actuator_*`, `run_actuator_*`, `run_closed_loop_actuator_*` |

---

## 6. Exact codegen boundary

| Side | Contents |
|------|----------|
| **STM32 / MATLAB Coder candidates** | `guidance_law.m`; `controller_law.m`; extract `inertial_velocity_ned`; (future) bounded wrap primitive replacing `wrapToPi`; frozen trim tables as const data |
| **SHARED_SUPPORT (host+target params)** | `init_parameters.m`; `build_pitch_trim_table.m` |
| **SIMULATION_ONLY (never deploy)** | `continuous_path_tracking.m` (except extract above); `underwater777_vehicle_dynamics.m`; all `ode45`/integrator drivers; all `run_*` (incl. Monte Carlo `run_gate8_monte_carlo_*`); all `test_*`/`verify_*`/`diag_*`/`plot_*`/`compute_*`/`gate8_*` report helpers; nav/mission/FDIR/actuator evidence modules |
| **ARCHIVE_REJECTED** | All `guidance_law_*` isolated candidates; `controller_law_trimmed.m`; `_ref_github_underwater777_vehicle_dynamics.m`; propulsion/current plant clones; `gate8_shadow_plant_seam.m` |
| **HARDWARE_BLOCKED (files)** | none scoped — target bring-up remains env **HARDWARE_BLOCKED** / **NOT_CERTIFIED** |

---

## 7. DEPLOY / SHARED detail

### DEPLOY
| Path | Role | Risk | Evidence |
|------|------|------|----------|
| `controller_law.m` | entry | HIGH | controller_law.m:1,12-30,23-25,61,222; Gate9B EG-08/EG-26 |
| `guidance_law.m` | entry | HIGH | guidance_law.m:1,13-21,54,164,283-394; Gate9B §2 |

### SHARED_SUPPORT
| Path | Role | Risk | Evidence |
|------|------|------|----------|
| `build_pitch_trim_table.m` | helper | MED | build_pitch_trim_table.m:1-4; feeds trim_* globals |
| `init_parameters.m` | helper | MED | init_parameters.m:1-18,50-58,74-93; called cpt:6 |

### ARCHIVE_REJECTED (n=18)
`_ref_github_underwater777_vehicle_dynamics.m`, `continuous_path_tracking_propulsion.m`, `controller_law_trimmed.m`, `gate8_shadow_plant_seam.m`, `guidance_law_depth_gamma_structural.m`, `guidance_law_depth_gamma_structural_attempt3.m`, `guidance_law_depth_gamma_structural_blocker_fix.m`, `guidance_law_depth_i_ablation.m`, … (+10)

### SIMULATION_ONLY
n=156 — all remaining scoped `.m` (see CSV). Includes plant, harness entry, suite drivers, plots, metrics, Gate5–9 evidence.

---

## 8. Integrity

| File | Bytes | SHA-256 | State |
|------|------:|---------|-------|
| `continuous_path_tracking.m` | 10845 | `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b` | UNTOUCHED |
| `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` | UNTOUCHED |
| `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` | UNTOUCHED |
| `init_parameters.m` | 4205 | `09803f4956b64227403919229781086c367e620f5736cfd680d1b15081237a9a` | UNTOUCHED |
| `underwater777_vehicle_dynamics.m` | 6065 | `612e1009f7d65968109be1e8352d472730db65c08b0c15a17e6cde7a9f629558` | UNTOUCHED |
| `suite_results/CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` | UNTOUCHED — not read, not written |

**Installs:** none. **Source edits:** none. **MATLAB runs:** 0.  
Evidence writes (small text only): this file · `CG0_CODEGEN_MANIFEST.csv` · `CG_CODEGEN_STATUS.md` · compact appends.

---

*End of CG0_CODEGEN_BOUNDARY. Verdict: **PASS**. Next: `CG1A_CONTROLLER_STATIC_CODEGEN_COMPATIBILITY_001`. Hardware: **NOT_CERTIFIED**.*
