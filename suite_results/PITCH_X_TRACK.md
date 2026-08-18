# PITCH_X_TRACK

**TASK_ID:** PITCH_X_TRACK_001
**Date:** 2026-08-05 18:14:29
**Verdict:** **PASS**

Production X-line, λ=0.25, yaw frozen, no gain/FF change.
Acquisition: |eθ| in ±0.5° for 1 s (cap 6 s).
Steady: post-acq AND settled_before_end (t≥5 s, s<0.88 s_path).

## Headline metrics

| # | Metric | Value |
|---|--------|------:|
| 1 | steady MAE \|eθ\| | 0.0637° |
| 2 | steady p95 \|eθ\| | 0.0856° |
| 3 | steady signed eθ | +0.0622° |
| 4 | elev sat% steady | 0.00 |
| 5 | sbe MAE (vs baseline 0.064°) | 0.0637° |
| 6 | CTE_perp sbe | 0.2566 m |

## Acquisition

| Metric | Value |
|--------|------:|
| acq time | 2.65 s |
| MAE | 0.3839° |
| RMS | 0.4261° |
| signed | +0.3839° |
| p95 | 0.6158° |
| max\|e\| | 0.6200° |
| overshoot proxy | 0.7948° |

## Steady

| Metric | Value |
|--------|------:|
| MAE | 0.0637° |
| RMS | 0.0683° |
| signed | +0.0622° |
| p95 | 0.0856° |
| max\|e\| | 0.0864° |
| lag mean / RMS | +0.0622 / 0.0683° |
| q ripple RMS | 0.0190 °/s |
| rate track MAE \|q_ref-q\| | 0.2127 °/s |
| chatter | 0.0017 °/s |
| elev mean / RMS | -4.799 / 4.800° |
| elev rate RMS | 0.189 °/s |
| elev near-limit% / sat% | 0.00 / 0.00 |
| visible oscillation | NO |

## PASS gates

| Gate | Result | Detail |
|------|:------:|--------|
| steady MAE ≤0.10° | YES | 0.0637° |
| steady p95 ≤0.20° | YES | 0.0856° |
| elev sat ≤1% | YES | 0.00% |
| no visible ss oscillation | YES | chat=0.0017 zc/s=0.54 |
| no >2% regression vs 0.064° | YES | sbe MAE=0.0637° lim=0.0653° |

## Open issue

none

## MATHEMATICAL_DELTA

ΔMAE_sbe=-0.0003° (-0.44% of 0.064°); steady MAE=0.0637°; signed_ss=+0.0622°; e=θ_ref-θ_phys

## Files

- `suite_results/PITCH_X_TRACK.md`
- `suite_results/PITCH_X_TRACK.mat`
- `suite_results/PITCH_X_TRACK.png`
