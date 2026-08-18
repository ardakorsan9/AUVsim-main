# YAW_CLOSED_METRIC_WRAP

**TASK_ID:** YAW_CLOSED_METRIC_WRAP_001
**Date:** 2026-08-05 17:35:57
**Verdict:** PASS

## Summary

Closed-path s_prog seam-freeze fixed (periodic wrap) in compute_path_following_metrics.m. Re-scored existing YAW_R75_RADIAL_DIAG.mat (R=7.5, u=1.5, T=120). Metric-only; no controller change.

## Before / After CTE (steady, >=3 turns)

| Metric | before (3D CTE) | after 3D CTE | after e_xy (horiz) | analytic |e_r| |
|---|---:|---:|---:|---:|
| mean | 7.1694 | 0.2468 | 0.2275 | 0.2276 |
| RMS  | 8.9751 | 0.2482 | 0.2275 | 0.2276 |
| p95  | 14.6831 | 0.3059 | 0.2282 | 0.2282 |
| max  | 14.7730 | 0.3646 | 0.2286 | 0.2287 |

- Gate2: e_xy vs |e_r| mean_diff=0.00007 m, p95_diff=0.00005 m (gate <=0.01)
- 3D CTE vs |e_r| residual mean_diff=0.01921 p95_diff=0.07767 from mean|z|=0.07824 (CTE_3D=hypot(e_xy,e_z); seam freeze was horizontal O(R))
- s_prog after == prior wrap-OK series (max abs delta = 0)

## Seam / turn evidence

- n_turns=3, n_seam_pass=3, n_wraps_full_run=3, s_total=47.1237 m
- turn 1: unwrap_advance=47.09 (s_total=47.12) -> OK
- turn 2: unwrap_advance=47.09 (s_total=47.12) -> OK
- turn 3: unwrap_advance=47.09 (s_total=47.12) -> OK

## Yaw baseline delta (same MAT time series; metric-only)

| | baseline | now | delta |
|---|---:|---:|---:|
| mean|e_psi| [deg] | 0.3065 | 0.3065 | +0.000011 |
| RMS | 0.3864 | 0.3864 | -0.000005 |
| p95 | 0.6303 | 0.6303 | +0.000048 |
| max | 0.6641 | 0.6641 | +0.000042 |

- yaw series self-delta vs stored A.e_psi: 0
- rudder sat (prior diag): 0.00%%

## Open-path branch unchanged

Closed-only branch added (project_wrapped + wrap_arc + mod). Open else retains:

    s_lo = max(0, s_prog - 0.15);
    s_hi = min(s_total, s_prog + max(3.0, 2.5*L));
    [s_near, ~] = project_on_path(...);
    if s_near >= s_total - 1e-6
        s_prog = s_total;
    else
        s_prog = max(s_prog, s_near - 0.05);
        s_prog = min(s_prog, s_total);
    end

## PASS gates

| Gate | Result |
|---|---|
| 1 s_prog wraps >=3 steady turns | PASS |
| 2 horiz CTE e_xy vs |e_r| mean and p95 <=0.01 m | PASS |
| 3 steady 3D CTE mean <=0.30 m | PASS |
| 4 yaw baseline unchanged | PASS |
| 5 open-path branch unchanged | PASS |

**Overall: PASS**

## Evidence paths

- src: suite_results/YAW_R75_RADIAL_DIAG.mat
- suite_results/YAW_CLOSED_METRIC_WRAP.mat
- suite_results/YAW_CLOSED_METRIC_WRAP.csv
- suite_results/YAW_CLOSED_METRIC_WRAP.png
- suite_results/YAW_CLOSED_METRIC_WRAP.md

## MATHEMATICAL_RECORD (delta)

```
MATHEMATICAL_RECORD = {
  equations: {
    s_prog_closed <- mod(s_prog + max(wrap_arc(s_near-s_prog,S), -0.05), S),
    wrap_arc(ds,S) = mod(ds+S/2,S)-S/2,
    project_wrapped: search [s_lo, s_lo+win] mod S,
    CTE_perp_3D = ||(I-tt^T)(p-p_d)|| = hypot(e_xy, e_z),
    e_xy = ||e_perp(1:2)||, e_r = rho - R
  },
  variables_units_frames: {
    s_prog [m] periodic on [0,S); CTE [m]; e_r [m] horizontal radial;
    e_z [m] equals vehicle z on flat z=0 path
  },
  assumptions: {
    is_closed iff ||path(1)-path(end)|| < 0.25; open clamp unchanged;
    gate2 compares planar e_xy to |e_r| (seam bug was horizontal O(R))
  },
  parameter_provenance: {
    DERIVED: wrap_arc, project_wrapped win=max(3,2.5L),
    IDENTIFIED: CTE after, e_xy vs |e_r| from rescore,
    TUNED: none,
    FIXED: L=1.25, ds<-0.25 reject, open clamp logic
  },
  design_reason: 'Periodic s_prog so closed CTE tracks geometry past seam.',
  rejected_alternatives: {
    redefine_CTE_perp_as_e_xy: rejected (keep 3D; e_xy already separate),
    controller_z_trim: rejected (out of scope),
    alter_open_clamp: rejected
  },
  evidence: { suite_results/YAW_CLOSED_METRIC_WRAP.*, src YAW_R75_RADIAL_DIAG.mat },
  conclusion: 'PASS: wrap restores e_xy~=|e_r|; 3D CTE residual is |z|',
  open_questions: { inward e_r~-0.23m within 0.30; depth |z|~0.08m not this task }
}
```
