# METRIC_RESCORE

**Date:** 2026-08-04 19:09:46
**Scope:** Frenet path metrics + re-score T5 candidates (same plant).
**Do NOT** start elevator/NMP audit here (NEXT).

## Metric definition

- Legacy kept: `cte_waypoint_legacy` = nearest discrete waypoint distance.
- Primary: along-track `e_s`, `CTE_perp`, vertical/horizontal normal, depth `e_z`.
- **Gate window `settled_before_end`:** open paths: `t ≥ 5 s` AND `s < 0.88 s_total` AND not `near_end` / past-end; closed paths (circle): settled only (`t ≥ 5 s`).
- Paths extended: X-line → 45 m; XZ L=42 → s≈45 m (vehicle stays on path during T_sim; overrun 0%).
- Suite `mean_cross_track` now aliases `CTE_perp` (settled_before_end).

## Frozen stack

| Param | Value |
|-------|------:|
| `lambda_muw_ff` | **0.25** |
| Tur4A `r_ff=U_h*κ` / T25 trim / timing | **kept** |
| `dt_controller` / `dt_guidance` / `tau_rate` | 0.0250 / 0.0750 / 0.0500 |
| Mid-target (XZ) | CTE_perp < 0.50 m, \|e_z\| < 0.45 m |

## Focus table (XZ) — settled_before_end

| Config | K_γ | K_zdot | CTE_perp | \|e_z\| | mean e_z | max CTE_perp | \|pitch\| | chatter | elev RMS |
|--------|----:|-------:|---------:|------:|---------:|-------------:|---------:|--------:|---------:|
| Baseline | 0.00 | 0.00 | 0.751 | 0.697 | -0.697 | 0.889 | 1.44 | 0.0286 | 1.576 |
| T5A | 0.00 | 0.50 | 0.549 | 0.510 | -0.510 | 0.607 | 1.40 | 0.1017 | 1.600 |
| T5B | 0.75 | 0.00 | 0.559 | 0.519 | -0.519 | 0.620 | 1.40 | 0.0920 | 1.598 |

## Focus table (X-line) — settled_before_end

| Config | K_γ | K_zdot | CTE_perp | \|e_z\| | mean e_z | max CTE_perp | \|pitch\| | chatter | elev RMS |
|--------|----:|-------:|---------:|------:|---------:|-------------:|---------:|--------:|---------:|
| Baseline | 0.00 | 0.00 | 0.257 | 0.257 | -0.257 | 0.281 | 0.11 | 0.0179 | 4.798 |
| T5A | 0.00 | 0.50 | 0.181 | 0.181 | -0.181 | 0.207 | 0.12 | 0.0670 | 4.779 |
| T5B | 0.75 | 0.00 | 0.190 | 0.190 | -0.190 | 0.215 | 0.12 | 0.0589 | 4.782 |

## Path length check (Baseline)

| Scenario | s_total | travel_est | overrun % |
|----------|--------:|-----------:|----------:|
| XZ | 45.24 | 38.36 | 0.0 |
| X | 45.00 | 32.37 | 0.0 |

## Baseline full suite (new primary metrics)

| Scenario | CTE_perp sbe | \|e_z\| sbe | legacy wp full | \|pitch\| | chatter |
|----------|-------------:|-----------:|---------------:|---------:|--------:|
| 1) Duz X cizgisi | 0.257 | 0.257 | 0.215 | 0.11 | 0.0179 |
| 2) Egik XZ cizgisi | 0.751 | 0.697 | 0.647 | 1.44 | 0.0286 |
| 3) Yatay daire | 2.038† | 0.316 | 1.516 | 0.14 | 0.0253 |
| 4) Heliks | 1.200 | 0.205 | 1.675 | 0.21 | 0.0243 |

† Circle row from this batch still applied the open-path 0.88 cut; post-fix closed paths use settled-only. X/XZ focus numbers above are unaffected.

## Production guidance

| Decision | Value |
|----------|------:|
| Keep as production | **Baseline** |
| `K_gamma` | **0.00** |
| `K_zdot` | **0.00** |
| T5B experimental | **YES** |

T5A/T5B improve true XZ `CTE_perp` (~0.75 → ~0.55) but **do not** hit mid-target (`CTE_perp<0.50`, `|ez|<0.45`). T5A chatter rises to 0.10 °/s. Keep production `K_gamma=0`, `K_zdot=0`; leave T5B `K_gamma=0.75` experimental.

## NEXT (do NOT implement in this task)

1. Elevator / NMP audit (authority, sign, delay).
2. Controller A/B or LQI on true `CTE_perp` / `|e_z|`.

## Files

- `compute_path_following_metrics.m` — shared Frenet + legacy metrics
- `run_path_suite.m` — extended X/XZ paths, summary windows, figure titles
- `run_tur5a.m` / `run_tur5b.m` — short XZ uses primary CTE_perp
- `run_metric_rescore.m` — this batch
- `suite_results/METRIC_RESCORE.md` — this report
- `suite_results/summary.txt` — baseline full-suite windows
