# CG_PRE0_TOOLCHAIN_CAPABILITY

**TASK_ID:** `CG_PRE0_TOOLCHAIN_CAPABILITY_001`  
**Track:** MATLAB→C++ pretarget — read-only capability gate (CG_PRE0)  
**Executed:** 2026-08-10 01:58–01:59 (local) / probe UTC `2026-08-09T22:58:39Z`  
**MATLAB invocations:** **1** (`/mnt/d/ardak/matlab/bin/matlab.exe` → `D:\ardak\matlab\bin\matlab.exe`)  
**Mode:** read-only capability probe · no `mex -setup` · no compiler install/config change · no project codegen · no source edit · no install · no retained build products  
**Hardware:** **NOT_CERTIFIED** · exact target part/board still ABSENT (carried Gate 9B terminus)  
**Sources read (exactly 3, no repo scan):**  
1. `suite_results/GATE9B_FAST_WHOLE_CODE_EMBEDDED_GAP_AUDIT.md`  
2. `suite_results/AUTONOMOUS_EXECUTION_POLICY.md`  
3. `suite_results/AUV_REALIZATION_READINESS_PLAN.md`  

**Preserved:** production `continuous_path_tracking.m`, `guidance_law.m`, `controller_law.m`; all prior evidence; `suite_results/CODEX_VERTICAL_PLAN.md` (**UNTOUCHED — not read, not written**).

---

## 1. Verdict

> ### CG_PRE0: **PARTIAL**

MATLAB host/bridge is healthy. MATLAB Coder is **PRESENT** + **LICENSE_AVAILABLE** with resolvable `codegen`/`coder` APIs. Classic Simulink Coder / Embedded Coder **license features** test true (`Real-Time_Workshop`, `RTW_Embedded_Coder`), but those products are **not** listed by `ver` (install **MISSING**). **No** selected or installed C/C++ MEX compiler configuration exists, so executable / linkable codegen is blocked without a forbidden setup change. No STM32-relevant support package / add-on is installed (**MISSING** / **HARDWARE_BLOCKED** for target bring-up).

| Outcome | Meaning | Applies? |
|---------|---------|----------|
| **PASS** | Toolchain sufficient to start CG0/CG1 **including** executable codegen path | **NO** — compiler absent |
| **PARTIAL** | Independent **static** boundary work may continue; executable codegen blocked | **YES** |
| **FAIL** | Broken MATLAB / bridge | **NO** — R2025b PCWIN64 responded cleanly |

**Carried context (not re-litigated):** Gate 9 `RC_NOT_GRANTED`; Gate 9B **FAIL** with 14 host-side BLOCKER classes; target work remains forbidden until exact part/board **and** blocker disposition. This gate does **not** authorize target adaptation, codegen of production laws, or label upgrades on B01–B14.

**Next exact task (exactly one):** `CG0_CODEGEN_BOUNDARY_INVENTORY_001`

---

## 2. Disk discipline (C: CAUTION)

| Metric | Bytes | GiB |
|--------|------:|----:|
| C: avail **before** MATLAB | 4565749760 | 4.2526 |
| C: avail **after** MATLAB (pre-suite_results write) | 4554731520 | 4.2424 |
| Δ during MATLAB | −11018240 | −0.0103 |
| C: avail **after** small text evidence writes | 4553367552 | 4.2411 |

Probe script + raw transcript lived on **D:** (`D:\ardak\Documents\cg_pre0_toolchain_probe\`) — not on C:. Suite evidence on C: is **small text only** (this MD + `CG_CODEGEN_STATUS.md` + compact appends). No MAT/PNG/build cache / codegen output retained on C:.

---

## 3. MATLAB release / platform

| Field | Value | Label |
|-------|-------|-------|
| Release | **R2025b** (`matlabRelease`) | PRESENT |
| Version string | `25.2.0.3177638 (R2025b) Update 5` | PRESENT |
| Stage | release | PRESENT |
| `computer` | `PCWIN64` | PRESENT |
| Endian / maxsize | L / 2.81475e+14 | PRESENT |
| `ispc` | 1 | PRESENT |

Bridge: **OK** (single `-batch` invocation exit 0, `PROBE_COMPLETE=1`).

---

## 4. Installed products (`ver`, n=14)

| Product | Version | Release | Label |
|---------|---------|---------|-------|
| MATLAB | 25.2 | (R2025b) | PRESENT |
| MATLAB Coder | 25.2 | (R2025b) | PRESENT |
| Simulink | 25.2 | (R2025b) | PRESENT |
| MATLAB Compiler | 25.2 | (R2025b) | PRESENT |
| MATLAB Compiler SDK | 25.2 | (R2025b) | PRESENT |
| MATLAB Test | 25.2 | (R2025b) | PRESENT |
| MATLAB Report Generator | 25.2 | (R2025b) | PRESENT |
| Control System Toolbox | 25.2 | (R2025b) | PRESENT |
| Deep Learning Toolbox | 25.2 | (R2025b) | PRESENT |
| Deep Learning HDL Toolbox | 25.2 | (R2025b) | PRESENT |
| Image Processing Toolbox | 25.2 | (R2025b) | PRESENT |
| Computer Vision Toolbox | 25.2 | (R2025b) | PRESENT |
| Reinforcement Learning Toolbox | 25.2 | (R2025b) | PRESENT |
| Robotics Toolbox for MATLAB | 10.4 | (empty release field) | PRESENT |

**Not in `ver`:** Simulink Coder, Embedded Coder, Fixed-Point Designer (as named products), any STM32 Embedded Coder Support Package.

---

## 5. Non-checkout license tests (`license('test', feature)`)

| Feature | Result | Interpretation | Label |
|---------|-------:|----------------|-------|
| `MATLAB` | 1 | OK | LICENSE_AVAILABLE |
| `MATLAB_Coder` | 1 | OK | LICENSE_AVAILABLE |
| `Real-Time_Workshop` | 1 | Classic **Simulink Coder** feature name | LICENSE_AVAILABLE |
| `RTW_Embedded_Coder` | 1 | Classic **Embedded Coder** feature name | LICENSE_AVAILABLE |
| `Simulink_Coder` | 0 | Alternate name — not a valid feature token here | MISSING (alias) |
| `Embedded_Coder` | 0 | Alternate name — not a valid feature token here | MISSING (alias) |
| `Simulink` | 1 | OK | LICENSE_AVAILABLE |
| `Fixed_Point_Toolbox` | 1 | Feature tests true; product **not** in `ver` | LICENSE_AVAILABLE / install MISSING |
| `Signal_Blocks` | 1 | Feature tests true; product **not** in `ver` | LICENSE_AVAILABLE / install MISSING |
| `Stateflow` | 1 | Feature tests true; product **not** in `ver` | LICENSE_AVAILABLE / install MISSING |

No license checkout was performed beyond normal `license('test',…)`.

---

## 6. codegen / coder API existence & resolution

| API | `exist` | `which` | Label |
|-----|--------:|--------|-------|
| `codegen` | 6 | `D:\ardak\matlab\toolbox\coder\matlabcoder\codegen.p` | PRESENT |
| `coder` | 6 | `D:\ardak\matlab\toolbox\coder\matlabcoder\coder.p` | PRESENT |
| `coder.config` | 0 (package method) | `...\+coder\config.p` resolved by `which` | PRESENT |
| `coder.typeof` | 0 (package method) | `...\+coder\typeof.p` resolved by `which` | PRESENT |
| `emlcoder` | 0 | (empty) | MISSING |
| `embeddedcoder` | 0 | (empty) | MISSING |

---

## 7. C/C++ MEX compiler configurations (read-only; setup unchanged)

| Query | C | C++ | Label |
|-------|--:|---:|-------|
| `mex.getCompilerConfigurations(lang,'Selected')` count | **0** | **0** | MISSING |
| `mex.getCompilerConfigurations(lang,'Installed')` count | **0** | **0** | MISSING |

**No** `mex -setup`, **no** compiler install, **no** configuration mutation.

---

## 8. Add-ons / STM32-relevant support packages

`matlab.addons.installedAddons` → **17** entries (see raw probe). Filter for `stm32` / `stmicro` / `nucleo` / Embedded Coder Support Package / ARM Cortex-M target packs:

| Item | Count / result | Label |
|------|----------------|-------|
| STM32-relevant add-ons | **0** | MISSING |
| Target hardware readiness | exact part/board ABSENT | HARDWARE_BLOCKED |
| Certification | — | **NOT_CERTIFIED** |

---

## 9. Tiny MATLAB Coder smoke (conditional)

| Precheck | Value |
|----------|-------|
| `license('test','MATLAB_Coder')` | 1 |
| `codegen` present | 1 |
| Selected C or C++ compiler | **0** |

**SMOKE_STATUS:** `SKIPPED`  
**Exact reason:** No selected C/C++ MEX compiler configuration; smoke would require `mex -setup` / compiler configuration change (**forbidden** by this task).

No temp codegen products retained.

---

## 10. Capability matrix (gate labels)

| Component | PRESENT | LICENSE_AVAILABLE | CONFIGURED | MISSING | HARDWARE_BLOCKED |
|-----------|:-------:|:-----------------:|:----------:|:-------:|:----------------:|
| MATLAB R2025b host | ● | ● | ● | | |
| MATLAB Coder product | ● | ● | ● (API) | | |
| Simulink product | ● | ● | ● | | |
| Simulink Coder product (`ver`) | | ● (`Real-Time_Workshop`) | | ● (not in `ver`) | |
| Embedded Coder product (`ver`) | | ● (`RTW_Embedded_Coder`) | | ● (not in `ver`) | |
| `codegen` / `coder` APIs | ● | ● | ● | | |
| C MEX compiler selected/installed | | | | ● | |
| C++ MEX compiler selected/installed | | | | ● | |
| Executable codegen path | | | | ● | |
| STM32 support package / target pack | | | | ● | ● |
| Exact MCU part/board | | | | ● | ● |

---

## 11. Implications for CG0 / CG1

- **Allowed next:** `CG0_CODEGEN_BOUNDARY_INVENTORY_001` — static inventory of codegen boundaries / host-vs-core seams (doc/analysis; no executable codegen required).
- **Blocked until compiler configured by a future authorized task:** any executable / mex / PIL smoke; retaining generated C/C++ build trees.
- **Blocked until part/board + Gate 9B blocker disposition:** target-specific Embedded Coder packs, STM32 mapping, hardware claims (**NOT_CERTIFIED**).

---

## 12. Integrity

| Artifact | Bytes | SHA-256 | State |
|----------|------:|---------|-------|
| `continuous_path_tracking.m` | 10845 | `e490453b094f2049dcdabe9a31c3eb628e3740fc8c6137b4fa86add7cdf0641b` | UNTOUCHED |
| `guidance_law.m` | 14601 | `2d70cea916107649132ea80eba13cd2c5a3730163f10ebc3fdafb1026513eec3` | UNTOUCHED |
| `controller_law.m` | 9402 | `16b7c20a14f1a1afcc3479351edee66eadecf4d134ed7d17e9e1d6986d9df890` | UNTOUCHED |
| `suite_results/CODEX_VERTICAL_PLAN.md` | 43101 | `000ba87721bb75846690d0f4325aad6c58070c0831cb9c199e240b53b6e7931c` | UNTOUCHED — not read, not written |

**Installs:** none. **Source edits:** none. **MATLAB runs:** 1.

| Evidence / append target | Bytes (post-write) | SHA-256 (post-write) |
|--------------------------|-------------------:|----------------------|
| `suite_results/CG_PRE0_TOOLCHAIN_CAPABILITY.md` | (this file) | published in session / status board after final save |
| `suite_results/CG_CODEGEN_STATUS.md` | 3487 | `f52ee91241fe92acb4d0382f4fa5cef5d9c6297581ec547571798d5c40130740` |

Raw probe transcript (D:, not C: evidence): `D:\ardak\Documents\cg_pre0_toolchain_probe\cg_pre0_raw.txt`.

---

*End of CG_PRE0_TOOLCHAIN_CAPABILITY. Verdict: **PARTIAL**. Next: `CG0_CODEGEN_BOUNDARY_INVENTORY_001`. Hardware: **NOT_CERTIFIED**.*
