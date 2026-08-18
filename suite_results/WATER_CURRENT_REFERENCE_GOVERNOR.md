# WATER_CURRENT_REFERENCE_GOVERNOR_001 — Gate 4B shadow candidate 1

**Verdict: PARTIAL**

Currents: **ASSUMED**; Vc NED is deterministic scenario truth and bounded-oracle input; it is not a certified estimator. Actuators: **NOT_CERTIFIED**.

## Frozen architecture and scope

Predeclared bumpless feasibility scalar from bounded Vc NED, water-speed command, local curvature/progress demand, and fixed +/-25 deg / +/-40 deg/s Gate4A map margins; scales only path-progress advance and curvature FF.

No Vc-derived yaw/crab angle; no controller retune; no plant/path geometry alteration; no external shaper.

Exactly three sources: `run_water_current_feasibility_map.m`, `suite_results/WATER_CURRENT_FEASIBILITY_MAP.mat`, `guidance_law.m`. Production files are untouched.

The scalar is unity for Gate4A FEASIBLE cases and may engage only for prior RESHAPE/REFUSE. Fixed limits are |delta_r|<=25 deg and |delta_r rate|<=40 deg/s. No sweep was run.

## Primary and gate result

- Hard contact count, engaged cases: 6673 -> 6697 (reduction -0.360%).
- Worst fixed-limit margin: -0.000000 -> -0.000000 (improvement 0.000000).
- Exact FEASIBLE parity: 1 (max metric delta 0.000000e+00).

|Gate|Result|
|---|:---:|
|stability|PASS|
|no_hard_safety_violation|PASS|
|primary_kpi|FAIL|
|exact_feasible_parity|PASS|
|each_secondary_le_2pct_worse|PASS|
|engage_only_prior_reshape_refuse|FAIL|
|deterministic_resets_and_order|PASS|
|fixed_map_limits|PASS|
|production_untouched|PASS|
|working_data_under_300_MiB|PASS|

## Identical 32-case baseline-vs-shadow results

|#|Case|Prior|Mode|Orig CTE/depth/yaw rms|Ref CTE/depth/yaw rms|Progress/sim complete|dr max/rate|max margins|contact %|gov min/mean|Reason|
|--:|---|---|---|---|---|---|---|---|---:|---|---|
|1|X_U1.0_VE+0.00|FEASIBLE|B|0.349/0.349/0.00|0.361/0.349/0.00|0.550/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|baseline production pass-through|
|1|X_U1.0_VE+0.00|FEASIBLE|S|0.349/0.349/0.00|0.361/0.349/0.00|0.550/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|2|X_U1.0_VE+0.15|FEASIBLE|B|0.358/0.348/5.77|0.369/0.348/0.10|0.552/1|3.75/36.78|21.25/3.22|0.000|1.000/1.000|baseline production pass-through|
|2|X_U1.0_VE+0.15|FEASIBLE|S|0.358/0.348/5.77|0.369/0.348/0.10|0.552/1|3.75/36.78|21.25/3.22|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|3|X_U1.0_VE-0.15|FEASIBLE|B|0.358/0.348/5.77|0.369/0.348/0.10|0.552/1|3.75/36.78|21.25/3.22|0.000|1.000/1.000|baseline production pass-through|
|3|X_U1.0_VE-0.15|FEASIBLE|S|0.358/0.348/5.77|0.369/0.348/0.10|0.552/1|3.75/36.78|21.25/3.22|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|4|X_U1.0_VE+0.25|REFUSE|B|0.381/0.349/10.38|0.391/0.349/0.23|0.553/1|3.51/40.00|21.49/-0.00|3.060|1.000/1.000|baseline production pass-through|
|4|X_U1.0_VE+0.25|REFUSE|S|0.381/0.349/10.38|0.391/0.349/0.23|0.553/1|3.51/40.00|21.49/-0.00|3.060|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|5|X_U1.5_VE+0.00|FEASIBLE|B|0.256/0.256/0.00|0.279/0.256/0.00|0.717/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|baseline production pass-through|
|5|X_U1.5_VE+0.00|FEASIBLE|S|0.256/0.256/0.00|0.279/0.256/0.00|0.717/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|6|X_U1.5_VE+0.15|FEASIBLE|B|0.263/0.254/4.40|0.285/0.254/0.05|0.718/1|2.11/21.76|22.89/18.24|0.000|1.000/1.000|baseline production pass-through|
|6|X_U1.5_VE+0.15|FEASIBLE|S|0.263/0.254/4.40|0.285/0.254/0.05|0.718/1|2.11/21.76|22.89/18.24|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|7|X_U1.5_VE-0.15|FEASIBLE|B|0.263/0.254/4.40|0.285/0.254/0.05|0.718/1|2.11/21.76|22.89/18.24|0.000|1.000/1.000|baseline production pass-through|
|7|X_U1.5_VE-0.15|FEASIBLE|S|0.263/0.254/4.40|0.285/0.254/0.05|0.718/1|2.11/21.76|22.89/18.24|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|8|X_U1.5_VE+0.25|REFUSE|B|0.282/0.253/8.20|0.303/0.253/0.10|0.720/1|3.37/40.00|21.63/-0.00|1.808|1.000/1.000|baseline production pass-through|
|8|X_U1.5_VE+0.25|REFUSE|S|0.282/0.253/8.20|0.303/0.253/0.10|0.720/1|3.37/40.00|21.63/-0.00|1.808|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|9|X_U2.0_VE+0.00|FEASIBLE|B|0.171/0.170/0.00|0.215/0.170/0.00|0.878/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|baseline production pass-through|
|9|X_U2.0_VE+0.00|FEASIBLE|S|0.171/0.170/0.00|0.215/0.170/0.00|0.878/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|10|X_U2.0_VE+0.15|FEASIBLE|B|0.177/0.167/3.53|0.220/0.167/0.05|0.878/1|2.08/38.57|22.92/1.43|0.000|1.000/1.000|baseline production pass-through|
|10|X_U2.0_VE+0.15|FEASIBLE|S|0.177/0.167/3.53|0.220/0.167/0.05|0.878/1|2.08/38.57|22.92/1.43|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|11|X_U2.0_VE-0.15|FEASIBLE|B|0.177/0.167/3.53|0.220/0.167/0.05|0.878/1|2.08/38.57|22.92/1.43|0.000|1.000/1.000|baseline production pass-through|
|11|X_U2.0_VE-0.15|FEASIBLE|S|0.177/0.167/3.53|0.220/0.167/0.05|0.878/1|2.08/38.57|22.92/1.43|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|12|X_U2.0_VE+0.25|REFUSE|B|0.196/0.165/6.75|0.237/0.165/0.09|0.880/1|2.76/40.00|22.24/-0.00|1.530|1.000/1.000|baseline production pass-through|
|12|X_U2.0_VE+0.25|REFUSE|S|0.196/0.165/6.75|0.237/0.165/0.09|0.880/1|2.76/40.00|22.24/-0.00|1.530|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|13|XZ_U1.0_VE+0.00|FEASIBLE|B|0.751/0.697/0.00|0.757/0.663/0.00|0.642/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|baseline production pass-through|
|13|XZ_U1.0_VE+0.00|FEASIBLE|S|0.751/0.697/0.00|0.757/0.663/0.00|0.642/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|14|XZ_U1.0_VE+0.15|FEASIBLE|B|0.705/0.653/6.49|0.712/0.616/0.05|0.644/1|1.99/11.93|23.01/28.07|0.000|1.000/1.000|baseline production pass-through|
|14|XZ_U1.0_VE+0.15|FEASIBLE|S|0.705/0.653/6.49|0.712/0.616/0.05|0.644/1|1.99/11.93|23.01/28.07|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|15|XZ_U1.0_VE-0.15|FEASIBLE|B|0.705/0.653/6.49|0.712/0.616/0.05|0.644/1|1.99/11.93|23.01/28.07|0.000|1.000/1.000|baseline production pass-through|
|15|XZ_U1.0_VE-0.15|FEASIBLE|S|0.705/0.653/6.49|0.712/0.616/0.05|0.644/1|1.99/11.93|23.01/28.07|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|16|XZ_U1.0_VE+0.25|FEASIBLE|B|0.620/0.563/11.79|0.628/0.529/0.11|0.647/1|4.81/40.00|20.19/0.00|0.796|1.000/1.000|baseline production pass-through|
|16|XZ_U1.0_VE+0.25|FEASIBLE|S|0.620/0.563/11.79|0.628/0.529/0.11|0.647/1|4.81/40.00|20.19/0.00|0.796|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|17|XZ_U1.5_VE+0.00|FEASIBLE|B|0.407/0.378/0.00|0.424/0.337/0.00|0.847/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|baseline production pass-through|
|17|XZ_U1.5_VE+0.00|FEASIBLE|S|0.407/0.378/0.00|0.424/0.337/0.00|0.847/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|18|XZ_U1.5_VE+0.15|FEASIBLE|B|0.389/0.358/4.85|0.406/0.316/0.05|0.849/1|1.93/13.91|23.07/26.09|0.000|1.000/1.000|baseline production pass-through|
|18|XZ_U1.5_VE+0.15|FEASIBLE|S|0.389/0.358/4.85|0.406/0.316/0.05|0.849/1|1.93/13.91|23.07/26.09|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|19|XZ_U1.5_VE-0.15|FEASIBLE|B|0.389/0.358/4.85|0.406/0.316/0.05|0.849/1|1.93/13.91|23.07/26.09|0.000|1.000/1.000|baseline production pass-through|
|19|XZ_U1.5_VE-0.15|FEASIBLE|S|0.389/0.358/4.85|0.406/0.316/0.05|0.849/1|1.93/13.91|23.07/26.09|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|20|XZ_U1.5_VE+0.25|FEASIBLE|B|0.356/0.317/9.04|0.375/0.276/0.06|0.851/1|2.24/28.22|22.76/11.78|0.000|1.000/1.000|baseline production pass-through|
|20|XZ_U1.5_VE+0.25|FEASIBLE|S|0.356/0.317/9.04|0.375/0.276/0.06|0.851/1|2.24/28.22|22.76/11.78|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|21|XZ_U2.0_VE+0.00|FEASIBLE|B|0.409/0.227/0.00|0.431/0.183/0.00|1.000/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|baseline production pass-through|
|21|XZ_U2.0_VE+0.00|FEASIBLE|S|0.409/0.227/0.00|0.431/0.183/0.00|1.000/1|0.00/0.00|25.00/40.00|0.000|1.000/1.000|Gate4A-FEASIBLE exact pass-through|
|22|XZ_U2.0_VE+0.15|REFUSE|B|0.411/0.216/3.74|0.432/0.173/0.49|1.000/1|15.64/40.00|9.36/-0.00|4.892|1.000/1.000|baseline production pass-through|
|22|XZ_U2.0_VE+0.15|REFUSE|S|0.411/0.216/3.74|0.432/0.173/0.49|1.000/1|15.64/40.00|9.36/-0.00|4.892|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|23|XZ_U2.0_VE-0.15|REFUSE|B|0.411/0.216/3.74|0.432/0.173/0.49|1.000/1|15.64/40.00|9.36/-0.00|4.892|1.000/1.000|baseline production pass-through|
|23|XZ_U2.0_VE-0.15|REFUSE|S|0.411/0.216/3.74|0.432/0.173/0.49|1.000/1|15.64/40.00|9.36/-0.00|4.892|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|24|XZ_U2.0_VE+0.25|REFUSE|B|0.422/0.197/6.88|0.442/0.157/1.09|1.000/1|19.91/40.00|5.09/-0.00|4.892|1.000/1.000|baseline production pass-through|
|24|XZ_U2.0_VE+0.25|REFUSE|S|0.422/0.197/6.88|0.442/0.157/1.09|1.000/1|19.91/40.00|5.09/-0.00|4.892|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|25|R10_U1.5_VE+0.00|REFUSE|B|0.226/0.122/1.01|0.228/0.122/0.20|0.568/1|6.26/40.00|18.74/-0.00|44.136|1.000/1.000|baseline production pass-through|
|25|R10_U1.5_VE+0.00|REFUSE|S|0.226/0.122/1.01|0.228/0.122/0.20|0.568/1|6.26/40.00|18.74/-0.00|44.136|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|26|R10_U1.5_VE+0.15|REFUSE|B|0.170/0.090/3.39|0.173/0.090/0.47|0.570/1|18.31/40.00|6.69/-0.00|43.802|1.000/1.000|baseline production pass-through|
|26|R10_U1.5_VE+0.15|REFUSE|S|0.170/0.090/3.39|0.173/0.090/0.47|0.570/1|18.45/40.00|6.55/-0.00|43.469|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|27|R10_U1.5_VE-0.15|REFUSE|B|0.275/0.153/4.42|0.277/0.153/0.49|0.568/1|18.65/40.00|6.35/-0.00|43.969|1.000/1.000|baseline production pass-through|
|27|R10_U1.5_VE-0.15|REFUSE|S|0.275/0.153/4.42|0.277/0.153/0.49|0.568/1|18.65/40.00|6.35/-0.00|44.080|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|28|R10_U1.5_VE+0.25|REFUSE|B|0.142/0.074/6.07|0.146/0.074/3.52|0.568/1|25.00/40.00|0.00/-0.00|46.526|1.000/1.000|baseline production pass-through|
|28|R10_U1.5_VE+0.25|REFUSE|S|0.142/0.074/6.07|0.146/0.074/3.52|0.568/1|25.00/40.00|0.00/-0.00|46.415|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|29|R10_U2.0_VE+0.00|REFUSE|B|0.182/0.077/0.99|0.186/0.077/0.23|0.686/1|6.88/40.00|18.12/-0.00|45.525|1.000/1.000|baseline production pass-through|
|29|R10_U2.0_VE+0.00|REFUSE|S|0.182/0.077/0.99|0.186/0.077/0.23|0.686/1|6.88/40.00|18.12/-0.00|45.525|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|30|R10_U2.0_VE+0.15|REFUSE|B|0.172/0.070/3.93|0.177/0.070/0.41|0.688/1|14.30/40.00|10.70/-0.00|45.247|1.000/1.000|baseline production pass-through|
|30|R10_U2.0_VE+0.15|REFUSE|S|0.172/0.070/3.93|0.177/0.070/0.41|0.688/1|14.79/40.00|10.21/-0.00|45.970|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|31|R10_U2.0_VE-0.15|REFUSE|B|0.206/0.090/3.79|0.210/0.090/0.40|0.684/1|9.15/40.00|15.85/-0.00|45.636|1.000/1.000|baseline production pass-through|
|31|R10_U2.0_VE-0.15|REFUSE|S|0.206/0.090/3.78|0.210/0.090/0.39|0.684/1|9.44/40.00|15.56/-0.00|45.247|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|
|32|R10_U2.0_VE+0.25|REFUSE|B|0.171/0.076/6.19|0.176/0.076/0.71|0.690/1|25.00/40.00|0.00/-0.00|46.359|1.000/1.000|baseline production pass-through|
|32|R10_U2.0_VE+0.25|REFUSE|S|0.171/0.076/6.19|0.176/0.076/0.71|0.690/1|25.00/40.00|0.00/-0.00|47.693|1.000/1.000|fixed +/-40 deg/s map/local-curvature margin|

## Secondary non-regression (engaged cases)

|Metric|Baseline|Shadow|Worse %|<=2%|
|---|---:|---:|---:|:---:|
|original_cte_rms_m|0.260442|0.260435|-0.003|PASS|
|original_depth_rms_m|0.153446|0.153448|0.001|PASS|
|original_yaw_rms_deg|4.962049|4.961679|-0.007|PASS|
|reference_cte_rms_m|0.272234|0.272235|0.001|PASS|
|reference_depth_rms_m|0.144599|0.144598|-0.001|PASS|
|reference_yaw_rms_deg|0.637775|0.637063|-0.112|PASS|
|progress|0.726810|0.726810|0.000|PASS|

Order sentinel: exact=1 unique=1 count=64 checksum=54652.

Peak retained telemetry is below 5 MiB; cases are reduced to metrics before the next run, below the 300 MiB cap.

Structurally different, untried: internal finite-horizon arc-length governor using a rudder-state predictor and constraint projection.

No promotion without identical regressions; shadow evidence only.
