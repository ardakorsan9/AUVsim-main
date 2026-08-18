# PITCH_XZ_TRACK

**TASK_ID:** PITCH_XZ_TRACK_001
**Date:** 2026-08-05 18:42:19
**Verdict:** **PASS**
**A/B winner:** **λ=0** (acq + steady |eθ| + elev effort)
**Preferred closure MAE≤0.30°:** λ=.25 NOT MET (0.3876°); λ=0 NOT MET (0.3320°) — not applied

Production XZ-line, frozen gains, Tur4A/T25, K_γ=K_ż=0. No code/gain change.
Windows: acq = |eθ| in ±0.5° for 1 s (cap 6 s if never in-band); steady = post-acq ∩ settled_before_end (t≥5 s, s<0.88 s_path).

## A/B short table

| Metric | λ=0.25 | λ=0 |
|--------|-------:|----:|
| acq time [s] | 19.75 | 15.05 |
| steady MAE [°] | 0.3876 | 0.3320 |
| steady p95 [°] | 0.4370 | 0.4445 |
| steady signed [°] | +0.3876 | +0.3320 |
| elev fb RMS [°] | 5.133 | 2.877 |
| elev sat% | 0.00 | 0.00 |
| q ripple RMS [°/s] | 0.0037 | 0.0502 |
| CTE_perp sbe [m] | 0.751 | 0.572 |

## λ=0.25 (production baseline)

### Acquisition

| Metric | Value |
|--------|------:|
| acq / settling [s] | 19.75 |
| signed / MAE / RMS | +1.5557 / 1.5557 / 1.8009° |
| p95 / max\|e\| | 3.4213 / 3.5895° |
| dip (path−minθ) | 3.5196° |
| overshoot | 0.0000° |
| min θ_acq | 18.2818° |

### Steady

| Metric | Value |
|--------|------:|
| signed / MAE / RMS | +0.3876 / 0.3876 / 0.3888° |
| p95 / max\|e\| | 0.4370 / 0.4424° |
| lag mean / RMS | +0.3876 / 0.3888° |
| q ripple RMS | 0.0037 °/s |
| rate track MAE | 0.0471 °/s |
| chatter | 0.0001 °/s |
| elev mean / RMS / fbRMS | -0.952 / 0.952 / 5.133° |
| elev rate RMS | 0.012 °/s |
| elev near-limit% / sat% | 0.00 / 0.00 |
| CTE_perp settled_before_end | 0.7510 m |

## λ=0

### Acquisition

| Metric | Value |
|--------|------:|
| acq / settling [s] | 15.05 |
| signed / MAE / RMS | +1.0480 / 1.0480 / 1.2660° |
| p95 / max\|e\| | 2.8148 / 2.9868° |
| dip (path−minθ) | 2.9630° |
| overshoot | 0.0000° |
| min θ_acq | 18.8384° |

### Steady

| Metric | Value |
|--------|------:|
| signed / MAE / RMS | +0.3320 / 0.3320 / 0.3393° |
| p95 / max\|e\| | 0.4445 / 0.4596° |
| lag mean / RMS | +0.3320 / 0.3393° |
| q ripple RMS | 0.0502 °/s |
| rate track MAE | 0.1697 °/s |
| chatter | 0.0004 °/s |
| elev mean / RMS / fbRMS | -1.016 / 1.018 / 2.877° |
| elev rate RMS | 0.125 °/s |
| elev near-limit% / sat% | 0.00 / 0.00 |
| CTE_perp settled_before_end | 0.5723 m |

## PASS gates (baseline λ=0.25)

| Gate | Result | Detail |
|------|:------:|--------|
| steady MAE ≤0.40° | YES | 0.3876° |
| steady p95 ≤0.50° | YES | 0.4370° |
| elev sat ≤1% | YES | 0.00% |
| no >2% unexplained vs PITCH_CLOSURE | YES | see deltas |

## Open issue

none

## Root-cause hypothesis

XZ climb signed eθ bias from level-tuned Muw FF (λ=0.25); λ=0 reduces FF conflict → faster acq, lower |eθ| and elev effort. No schedule applied this task.

## MATHEMATICAL_DELTA

ΔMAE_ss(λ.25)=-0.0004° (-0.09% of 0.388); ΔMAE_ss(λ0)=-0.0000° (-0.01% of 0.332); Δacq(.25)=-0.00s Δacq(0)=+0.00s; e=θ_ref-θ_phys

## Files

- `suite_results/PITCH_XZ_TRACK.md`
- `suite_results/PITCH_XZ_TRACK.mat`
- `suite_results/PITCH_XZ_TRACK.png`
