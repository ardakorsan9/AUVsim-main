# WATER_CURRENT_ADMISSION_GOVERNOR_001 — Gate 4B final candidate 3/3

**Verdict: FAIL — Gate 4B CLOSED after 3 candidates.**

Currents: **ASSUMED**. Actuators: **NOT_CERTIFIED**.

## Scope and execution evidence

Exactly three declared sources: `run_water_current_feasibility_map.m`, `suite_results/WATER_CURRENT_FEASIBILITY_MAP.mat`, and `guidance_law.m`.

Production plant/controller/guidance/path geometry remained frozen. No radius, Vc yaw/crab term, retune, plant/path edit, or external shaper was introduced.

Blocker: **Single authorized MATLAB call terminated before execution: run_water_current_admission_governor.m line 379 column 44, Invalid use of operator.** The plotting syntax was corrected after the failure, but the campaign was not rerun because the task allowed exactly one MATLAB call.

## Coverage

- Contract declarations: 32/32.
- Executed contracts: 0/32.
- Paired nonlinear simulations: 0.
- Explicit refusal-output tests: 0.
- Exact 18-case FEASIBLE parity: **NOT VERIFIED**.
- Admitted RESHAPE contact reduction: **NOT VERIFIED**.
- Hard violations, secondary metrics, hold continuity, and reset/order sentinel: **NOT VERIFIED**.
- Refusals counted as tracking success: 0 (no contract was executed).

## Predeclared contract order

|#|ID|Requested speed|Vc East|Decision/reason|Original/ref metrics|
|--:|---|--:|--:|---|---|
|1|X_U1.0_VE+0.00|1.0|+0.00|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|2|X_U1.0_VE+0.15|1.0|+0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|3|X_U1.0_VE-0.15|1.0|-0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|4|X_U1.0_VE+0.25|1.0|+0.25|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|5|X_U1.5_VE+0.00|1.5|+0.00|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|6|X_U1.5_VE+0.15|1.5|+0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|7|X_U1.5_VE-0.15|1.5|-0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|8|X_U1.5_VE+0.25|1.5|+0.25|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|9|X_U2.0_VE+0.00|2.0|+0.00|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|10|X_U2.0_VE+0.15|2.0|+0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|11|X_U2.0_VE-0.15|2.0|-0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|12|X_U2.0_VE+0.25|2.0|+0.25|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|13|XZ_U1.0_VE+0.00|1.0|+0.00|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|14|XZ_U1.0_VE+0.15|1.0|+0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|15|XZ_U1.0_VE-0.15|1.0|-0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|16|XZ_U1.0_VE+0.25|1.0|+0.25|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|17|XZ_U1.5_VE+0.00|1.5|+0.00|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|18|XZ_U1.5_VE+0.15|1.5|+0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|19|XZ_U1.5_VE-0.15|1.5|-0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|20|XZ_U1.5_VE+0.25|1.5|+0.25|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|21|XZ_U2.0_VE+0.00|2.0|+0.00|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|22|XZ_U2.0_VE+0.15|2.0|+0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|23|XZ_U2.0_VE-0.15|2.0|-0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|24|XZ_U2.0_VE+0.25|2.0|+0.25|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|25|R10_U1.5_VE+0.00|1.5|+0.00|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|26|R10_U1.5_VE+0.15|1.5|+0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|27|R10_U1.5_VE-0.15|1.5|-0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|28|R10_U1.5_VE+0.25|1.5|+0.25|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|29|R10_U2.0_VE+0.00|2.0|+0.00|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|30|R10_U2.0_VE+0.15|2.0|+0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|31|R10_U2.0_VE-0.15|2.0|-0.15|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|
|32|R10_U2.0_VE+0.25|2.0|+0.25|NOT EVALUATED — MATLAB parse blocker|CTE/depth/yaw/progress/rudder/contact/saturation margins unavailable|

Current provenance for every declared row: Gate-4A map `Vc` in NED m/s; **ASSUMED**.

## Closure

Functional PASS was not demonstrated. Gate 4B is closed after candidate 3/3. **Do not advance Gate 5 without an explicit residual-risk waiver.** If such a waiver is granted, Gate 5 must establish the truth/measured/estimated chain.

`CODEX_VERTICAL_PLAN.md` was untouched.
