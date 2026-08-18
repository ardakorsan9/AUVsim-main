# PRETARGET_DEPLOY_BOUNDARY_V1

**Decision:** PASS  
**Scope:** one-time delta over accepted `CG0_CODEGEN_BOUNDARY` / `CG0_CODEGEN_MANIFEST.csv`  
**Target:** STM32F411CEU6 pretarget; hardware remains NOT_CERTIFIED  
**Protected:** accepted controller/guidance arithmetic and `CODEX_VERTICAL_PLAN.md` unchanged

The accepted 178-file CG0 inventory is reused without a repository rescan. Its
counts remain 2 DEPLOY, 2 SHARED_SUPPORT, 156 SIMULATION_ONLY and 18
ARCHIVE_REJECTED. This delta replaces only the deploy entry-point decision and
adds the six explicit-state files created after CG0.

## Effective deploy boundary

| Class | Files / rule | Decision |
|---|---|---|
| DEPLOY | `controller_codegen_init.m`, `controller_codegen_reset.m`, `controller_codegen_step.m` | Fixed API, explicit state; accepted CG2A exact golden parity. |
| DEPLOY | `guidance_codegen_init.m`, `guidance_codegen_reset.m`, `guidance_codegen_step.m` | Fixed API, explicit state; CG2B bounded repair approved with 102x6 exact golden parity. |
| SHARED_SUPPORT | Future fixed records/types, safety wrapper, generated interface and HAL contracts only | Must be reachable from a DEPLOY entry and pass its own gate before addition. |
| SIMULATION_ONLY | `controller_law.m`, `guidance_law.m` | Accepted MATLAB source-of-truth and golden oracle; globals/persistent/toolbox paths are not target entry points. |
| SIMULATION_ONLY | Existing plant, scenario, metrics, plotting, navigation/EKF and FDIR batch libraries | Evidence/reference only unless a new bounded explicit-state runtime core is separately approved. |
| ARCHIVE | Existing 18 `ARCHIVE_REJECTED` CG0 files | Closed; do not retry or place in target graph. |
| HARDWARE_BLOCKED | Real sensor drivers, actuator feedback mapping, board pinout and physical calibration | No deploy file promoted until hardware data/bench evidence exists. |

## Frozen fingerprints

| File | SHA-256 |
|---|---|
| `CG0_CODEGEN_MANIFEST.csv` | `6d639dc428d0bcc093d9212e3bc1510823a8b624389cd595fd60ba67610f786b` |
| `controller_codegen_init.m` | `85eeb0e182683933241558a7df5e80e61b4b27a1bcc28fd88be2f0f52576c153` |
| `controller_codegen_reset.m` | `8fb42aaf935d1a607d298cc4071b4de6de471a7e078d87412241ad09f24c4a01` |
| `controller_codegen_step.m` | `3cca4dc9c94bc3a9a5ec7c6524231b3716571e3156792a96828e88c02aef82f8` |
| `guidance_codegen_init.m` | `c9ca488840f9e59d9ec587ae61f2434206086c18a9f843f63b9e51cc2b9ec3df` |
| `guidance_codegen_reset.m` | `73fe16940cc508427a16a7bf8ba838289635042dfe96ccbeccd0d3da60109909` |
| `guidance_codegen_step.m` | `75aa5fd82194b12d1a3490e22b9ebc15f6146fc01a554bf91fe5db8e5f8a497f` |

## Gate consequence

Only the six explicit controller/guidance entry files enter the current
codegen graph. Navigation/FDIR, safety and STM32 support require new bounded
runtime units; simulation implementations are not copied wholesale. No
hardware-certification claim is made.
