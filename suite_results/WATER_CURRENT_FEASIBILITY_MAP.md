# WATER_CURRENT_FEASIBILITY_MAP_001 — Gate 4A

**Verdict: PASS**

Currents: **ASSUMED**. Actuator readiness: **NOT_CERTIFIED**.

## Scope and provenance

Exactly three read-only sources: `underwater777_vehicle_dynamics_current.m`, `run_bounded_current_hook.m`, `suite_results/BOUNDED_CURRENT_HOOK.mat`.

Production/controller/guidance/references frozen. No crab-current feedforward; no simple external shaper; no retune; no reference alteration; CODEX_VERTICAL_PLAN untouched.

Tracking window: last 50% of completed simulation samples, with exact start/end recorded per case.

Classifier: REFUSE: nonfinite/incomplete, reserve<=0, or fixed actuator limit exceeded; FEASIBLE: reserve>=0.15 and all actuator/tracking gates pass; RESHAPE: otherwise (offline label only; no command/reference alteration).

Hard fixed limits: |delta_r| <= 25 deg and |delta_r rate| <= 40 deg/s. Margins are exact limit minus measured maximum.

## Frame and identity reverification

- Vc NED; nu_c=R'*Vc BODY; nu_r=nu-nu_c; eta_dot=R*nu ground.
- Vc=0 RHS max delta: 0.000000e+00
- nu relation / ground kinematics max delta: 0.000000e+00 / 0.000000e+00
- drag max water-relative power: -0.000000e+00 (must be <=0)

## Deterministic 32-case map

|#|Route|U|Vc E|Finite/complete|Reserve|CTE rms/max|Yaw rms/max deg|Depth rms/max|dr max/rms deg|margin deg|rate max|rate margin|sat %|Window s|Class|
|--:|---|--:|--:|:---:|--:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
|1|X|1.0|+0.00|1/1|1.000|0.349/0.371|0.00/0.00|0.349/0.369|0.00/0.00|25.00|0.00|40.00|0.00|9.0-18.0|FEASIBLE|
|2|X|1.0|+0.15|1/1|0.850|0.358/0.378|0.10/0.39|0.348/0.367|3.75/1.55|21.25|36.78|3.22|0.00|9.0-18.0|FEASIBLE|
|3|X|1.0|-0.15|1/1|0.850|0.358/0.378|0.10/0.39|0.348/0.367|3.75/1.55|21.25|36.78|3.22|0.00|9.0-18.0|FEASIBLE|
|4|X|1.0|+0.25|1/1|0.750|0.381/0.400|0.23/0.82|0.349/0.365|3.51/1.59|21.49|40.00|-0.00|0.00|9.0-18.0|REFUSE|
|5|X|1.5|+0.00|1/1|1.000|0.256/0.272|0.00/0.00|0.256/0.270|0.00/0.00|25.00|0.00|40.00|0.00|9.0-18.0|FEASIBLE|
|6|X|1.5|+0.15|1/1|0.900|0.263/0.281|0.05/0.17|0.254/0.270|2.11/1.38|22.89|21.76|18.24|0.00|9.0-18.0|FEASIBLE|
|7|X|1.5|-0.15|1/1|0.900|0.263/0.281|0.05/0.17|0.254/0.270|2.11/1.38|22.89|21.76|18.24|0.00|9.0-18.0|FEASIBLE|
|8|X|1.5|+0.25|1/1|0.833|0.282/0.302|0.10/0.28|0.253/0.272|3.37/1.46|21.63|40.00|-0.00|0.00|9.0-18.0|REFUSE|
|9|X|2.0|+0.00|1/1|1.000|0.171/0.201|0.00/0.00|0.170/0.197|0.00/0.00|25.00|0.00|40.00|0.00|9.0-18.0|FEASIBLE|
|10|X|2.0|+0.15|1/1|0.925|0.177/0.208|0.05/0.10|0.167/0.198|2.08/1.41|22.92|38.57|1.43|0.00|9.0-18.0|FEASIBLE|
|11|X|2.0|-0.15|1/1|0.925|0.177/0.208|0.05/0.10|0.167/0.198|2.08/1.41|22.92|38.57|1.43|0.00|9.0-18.0|FEASIBLE|
|12|X|2.0|+0.25|1/1|0.875|0.196/0.228|0.09/0.29|0.165/0.202|2.76/1.36|22.24|40.00|-0.00|0.00|9.0-18.0|REFUSE|
|13|XZ|1.0|+0.00|1/1|1.000|0.751/0.767|0.00/0.00|0.697/0.719|0.00/0.00|25.00|0.00|40.00|0.00|11.0-22.0|FEASIBLE|
|14|XZ|1.0|+0.15|1/1|0.850|0.705/0.727|0.05/0.09|0.653/0.679|1.99/1.45|23.01|11.93|28.07|0.00|11.0-22.0|FEASIBLE|
|15|XZ|1.0|-0.15|1/1|0.850|0.705/0.727|0.05/0.09|0.653/0.679|1.99/1.45|23.01|11.93|28.07|0.00|11.0-22.0|FEASIBLE|
|16|XZ|1.0|+0.25|1/1|0.750|0.620/0.645|0.11/0.31|0.563/0.594|4.81/2.03|20.19|40.00|0.00|0.00|11.0-22.0|FEASIBLE|
|17|XZ|1.5|+0.00|1/1|1.000|0.407/0.436|0.00/0.00|0.378/0.413|0.00/0.00|25.00|0.00|40.00|0.00|11.0-22.0|FEASIBLE|
|18|XZ|1.5|+0.15|1/1|0.900|0.389/0.416|0.05/0.09|0.358/0.392|1.93/1.49|23.07|13.91|26.09|0.00|11.0-22.0|FEASIBLE|
|19|XZ|1.5|-0.15|1/1|0.900|0.389/0.416|0.05/0.09|0.358/0.392|1.93/1.49|23.07|13.91|26.09|0.00|11.0-22.0|FEASIBLE|
|20|XZ|1.5|+0.25|1/1|0.833|0.356/0.378|0.06/0.19|0.317/0.347|2.24/1.36|22.76|28.22|11.78|0.00|11.0-22.0|FEASIBLE|
|21|XZ|2.0|+0.00|1/1|1.000|0.409/1.895|0.00/0.00|0.227/0.483|0.00/0.00|25.00|0.00|40.00|0.00|11.0-22.0|FEASIBLE|
|22|XZ|2.0|+0.15|1/1|0.925|0.411/1.925|0.49/2.74|0.216/0.500|15.64/2.95|9.36|40.00|-0.00|0.00|11.0-22.0|REFUSE|
|23|XZ|2.0|-0.15|1/1|0.925|0.411/1.925|0.49/2.74|0.216/0.500|15.64/2.95|9.36|40.00|-0.00|0.00|11.0-22.0|REFUSE|
|24|XZ|2.0|+0.25|1/1|0.875|0.422/2.012|1.09/5.48|0.197/0.551|19.91/3.48|5.09|40.00|-0.00|0.00|11.0-22.0|REFUSE|
|25|R10|1.5|+0.00|1/1|1.000|0.226/0.328|0.20/0.37|0.122/0.255|6.26/4.43|18.74|40.00|-0.00|0.00|22.5-45.0|REFUSE|
|26|R10|1.5|+0.15|1/1|0.900|0.170/0.314|0.47/1.06|0.090/0.223|18.31/10.33|6.69|40.00|-0.00|0.00|22.5-45.0|REFUSE|
|27|R10|1.5|-0.15|1/1|0.900|0.275/0.331|0.49/1.04|0.153/0.285|18.65/7.48|6.35|40.00|-0.00|0.00|22.5-45.0|REFUSE|
|28|R10|1.5|+0.25|1/1|0.833|0.142/0.304|3.52/10.61|0.074/0.205|25.00/15.80|0.00|40.00|-0.00|28.67|22.5-45.0|REFUSE|
|29|R10|2.0|+0.00|1/1|1.000|0.182/0.224|0.23/0.46|0.077/0.130|6.88/4.42|18.12|40.00|-0.00|0.00|22.5-45.0|REFUSE|
|30|R10|2.0|+0.15|1/1|0.925|0.172/0.273|0.41/0.96|0.070/0.127|14.30/8.17|10.70|40.00|-0.00|0.00|22.5-45.0|REFUSE|
|31|R10|2.0|-0.15|1/1|0.925|0.206/0.255|0.40/0.85|0.090/0.129|9.15/3.43|15.85|40.00|-0.00|0.00|22.5-45.0|REFUSE|
|32|R10|2.0|+0.25|1/1|0.875|0.171/0.318|0.71/1.68|0.076/0.127|25.00/14.06|0.00|40.00|-0.00|4.44|22.5-45.0|REFUSE|

## Gate audit

|Gate|Result|
|---|:---:|
|frames_and_units|PASS|
|vc0_rhs_identity|PASS|
|ground_kinematics|PASS|
|drag_sign|PASS|
|all_32_reported|PASS|
|deterministic_order|PASS|
|exact_fixed_margins|PASS|
|classifier_audit|PASS|
|tracking_window_provenance|PASS|
|production_controller_guidance_frozen|PASS|
|working_data_under_300_MiB|PASS|

Order sentinel: exact=1 unique=1 count=32 checksum=8070.

Robustness failures remain explicit map labels and do not get hidden: 14 non-FEASIBLE cases.

Per-case arrays are released before the next case; largest preallocated working data estimate <10 MiB, below the 300 MiB task cap.

Next: **Gate 4B feasibility-aware guidance/reference-governor SHADOW candidate**. This is a shadow candidate only.
