# T25_DIAG — Tur 2.5 Pitch Bias Decision Tree

Frozen: dt_c=0.0250, dt_g=0.0750, tau_rate=0.0500, Ki_rate=0.000, NO Muw-FF / circle r_ff / XZ redesign.

Current trim u=[0.8 1.0 1.5 2.0] de_deg=[-2.75 -2.50 -1.75 -1.25]  elevator_sign=+1  Ki_angle=0.160

## Test A — Pure level (guidance OFF, pitch_ref=0)

| u | mean eθ | mean\|e\| | RMS e | θ_phys | de_trim | de_angle_I | I min/max | w | chatter | suggested trim |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1.0 | -1.143 | 1.143 | 1.228 | +1.143 | -1.894 | -4.607 | -0.622 / -0.383 | -0.0511 | 0.0034 | -6.501 |
| 1.5 | -0.638 | 0.638 | 0.696 | +0.638 | -1.431 | -2.708 | -0.361 / -0.228 | -0.0400 | 0.0015 | -4.138 |
| 2.0 | -0.427 | 0.427 | 0.470 | +0.427 | -1.034 | -1.830 | -0.243 / -0.154 | -0.0331 | 0.0013 | -2.864 |

## Test B — Pitch ref symmetry @ u=2.0

| pref | mean e | settle s | OS | I_ss | mean de | chatter |
|---:|---:|---:|---:|---:|---:|---:|
| -10.0 | -0.212 | 6.12 | 0.15 | -0.327 | -4.060 | 0.0010 |
| -5.0 | -0.364 | 10.28 | 0.26 | -0.266 | -3.679 | 0.0015 |
| +5.0 | -0.566 | 13.53 | 1.34 | -0.140 | -2.803 | 0.0035 |
| +10.0 | -0.711 | 15.23 | 1.60 | -0.065 | -2.297 | 0.0051 |

## Test C — Ki_angle ablation (level, u=2.0)

| case | Ki | mean e | mean\|e\| | chatter | \|I\|_max | de_I |
|---|---:|---:|---:|---:|---:|---:|
| C0_current | 0.160 | -0.427 | 0.427 | 0.0013 | 0.243 | -1.830 |
| C1_0p5x | 0.080 | -0.895 | 0.895 | 0.0003 | 0.365 | -1.233 |
| C2_1p5x | 0.240 | -0.192 | 0.192 | 0.0025 | 0.174 | -2.110 |

## Test D — Pure level vs production X-line

| | mean eθ | mean\|e\| | chatter | de_I | notes |
|---|---:|---:|---:|---:|---|
| D1 pure level | -0.826 | 0.826 | 0.0058 | -2.487 | depth-I OFF |
| D2 X-line | -1.317 | 1.317 | 0.0945 | -2.682 | CTE=3.005 depth_e=0.006 pitch_ref_pp=0.39° |

## Decision tree conclusion

**Branch taken: `2.5.1_trim_recalibrate`**

Level flight shows signed bias (u1.5=-0.64°, u2=-0.43°) with steady angle-I elevator (-2.71° / -1.83°). Fold angle-I into trim table, reset angle I, retest. Chatter OK=1. Do NOT re-enable Ki_rate.

Next: Apply new trim from suggested_de_trim at 1.0/1.5/2.0 (keep 0.8 via extrap/search).

Suggested trim table (deg) for 2.5.1:

| u | current | suggested |
|---:|---:|---:|
| 0.8 | -2.750 | -6.751 |
| 1.0 | -2.500 | -6.501 |
| 1.5 | -1.750 | -4.138 |
| 2.0 | -1.250 | -2.864 |

### Acceptance targets

- Pure level after settle: |mean eθ|<0.3°, mean|e|<0.5°, chatter≤0.15 °/s, no sat, I not pegged
- X-line: mean|eθ|<0.7°, CTE worsen ≤5%, chatter≤0.15
- If pure OK but X bad → guidance depth-I cause; do NOT thrash pitch gains

### Plots

- `T25_testA_level.png`
- `T25_testB_symmetry.png`
- `T25_testC_Ki_ablation.png`
- `T25_testD_compare.png`
