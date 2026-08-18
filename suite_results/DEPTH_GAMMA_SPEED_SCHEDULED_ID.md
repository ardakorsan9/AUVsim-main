# DEPTH_GAMMA_SPEED_SCHEDULED_ID_001 — Depth/γ speed-scheduled sagittal plant ID

**Gate-1 verdict: PASS**  
**Stamp:** 2026-08-08 02:08:18  
**Blocker:** none  
**Next exact task:** `depth_gamma_structural_decoupling_governor_aw_gate`

## Provenance

- Task sources (exactly 3): `DEPTH_GAMMA_COUPLED_PLANT_ID.md`, `run_depth_gamma_coupled_plant_id.m`, `AUV_REALIZATION_READINESS_PLAN.md`
- Method sources (reused, not re-edited): TRIM refine + LOCAL_SS scale-aware FD + SS_VALIDATION NL/LTI
- Driver: `run_depth_gamma_speed_scheduled_id_extension.m` (isolated; production untouched)
- Plant RHS: `underwater777_vehicle_dynamics` (IMPLEMENTED; not re-edited)
- Seeds: level `LOCAL_SS_LEVEL / TRIM level_U15 refined (U≈1.82 BODY; not exact 1.5)`; climb `LOCAL_SS_CLIMB / TRIM XZ_slope_z0p4x refined (U≈1.75 BODY; not exact 1.5)`
- No controller/guidance/plant edits; no retune; CODEX_VERTICAL_PLAN untouched
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_SPEED_SCHEDULED_ID.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_SPEED_SCHEDULED_ID.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\DEPTH_GAMMA_SPEED_SCHEDULED_ID.png`

## Evidence labels

| Item | Label |
|---|---|
| Local A,B per (mode,U) | IDENTIFIED |
| theta_phys=-theta | IMPLEMENTED |
| alpha/gamma maps | DERIVED |
| ID tolerances | ASSUMED (declared) |
| Hydro coeff provenance / CI | TO_BE_IDENTIFIED (not invented) |
| Speed family U={1.0,1.5,2.0} | IDENTIFIED |

## BODY / NED signs and speed honesty

- Frame: NED inertial eta + BODY nu; Euler ZYX
- NED z positive down [m]; depth ≡ z (IMPLEMENTED)
- Euler theta [rad] BODY pitch; theta_phys = -theta (IMPLEMENTED)
- BODY alpha = atan2(w,u) [rad] (DERIVED)
- gamma = theta_phys + alpha [rad] (DERIVED)
- BODY surge u, heave w [m/s]; record U_cmd vs u* vs U_total=hypot(u,w) separately
- BODY pitch rate q [rad/s]
- elevator [rad]; delta_e>0 → +Z/+M via Zuuds/Muuds*u^2 (IMPLEMENTED)
- thrust = Xprop [N] (IMPLEMENTED)
- Hydro numeric coeffs not re-identified; A,B are IDENTIFIED local FD Jacobians of underwater777_vehicle_dynamics at documented trims. No invented hydro confidence.

### Commanded vs achieved speeds (never relabel approx as exact)

| Point | U_cmd BODY surge | u* BODY | U_total=hypot(u,w) | u==U_cmd? | trim |
|---|---:|---:|---:|:---:|:---:|
| level_U1.0 | 1.000 | 1 | 1.00277 | Y | PASS |
| level_U1.5 | 1.500 | 1.5 | 1.50083 | Y | PASS |
| level_U2.0 | 2.000 | 2 | 2.00035 | Y | PASS |
| climb_U1.0 | 1.000 | 1 | 1.0059 | Y | PASS |
| climb_U1.5 | 1.500 | 1.5 | 1.50198 | Y | PASS |
| climb_U2.0 | 2.000 | 2 | 2.00088 | Y | PASS |

Prior Gate-1 LOCAL_SS level/climb used window BODY u*≈1.82/1.75 (U=1.5-class, **not** exact 1.5). This extension fixes BODY surge to exact U_cmd in the trim solver; U_total remains distinct.

## Rollup

| Check | Score |
|---|---:|
| Trim PASS | 6/6 |
| Jacobian PASS | 6/6 |
| Validation PASS | 12/12 |
| Verdict | **PASS** |

## Declared ID tolerances

| Quantity | Value | Label |
|---|---:|---|
| trim norm_dyn max | 0.01 | IDENTIFIED |
| nrmse_rel max | 0.20 | ASSUMED |
| corr min | 0.95 | ASSUMED |
| energy floor | 1.0e-04 | ASSUMED |
| horizon T | 0.600 s | IDENTIFIED |

NRMSE_rel<=0.20 and corr>=0.95 on energetic sagittal channels; near-zero energy excluded; elevator pulse + theta IC; T=0.60 s

### Operating point: LEVEL_U1.0

```
U_cmd(BODY surge)=1.000  u*=1  w*=-0.0744258  U_total=1.00277
x* = [0            0            0            0   -0.0742888            0            1            0   -0.0744258            0 -2.28198e-25            0]
u* = [0 -0.221162    1.9911]
trim: θ=-0.0742888 θ_phys=0.0742888 α=-0.0742888 γ=1.38778e-17
dα/du=0.0740158  dα/dw=0.994491
norm_dyn=4.408e-14  slope_err=1.388e-17  trim=PASS  jac=PASS  exitflag=1
dA_rel=3.337e-05  dB_rel=8.602e-13  (gate <=1%)
class: steady_translating_trim (level; BODY u*=U_cmd=1.0 exact-by-construction)
```

A_sag (5×5) [z θ u w q]:
```
  0.00000000e+00  -1.00276577e+00   7.42205077e-02   9.97241854e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
  0.00000000e+00   1.69642992e-01  -1.03051165e-01  -5.95798171e-02   1.61227538e-01
  0.00000000e+00   1.56339903e-02   9.31550307e-02  -8.13053692e-01   3.98327441e-01
  0.00000000e+00  -7.31700137e-01   9.80883150e-02   3.13071408e+00  -3.38961231e-01
```

B_sag (5×2) [δe thrust]:
```
  0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00
  1.35216238e-02   3.12736081e-02
 -1.24172048e-01   6.67559000e-05
 -7.10514733e-01  -2.30327653e-03
```

C_y (6×5):
```
  1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   7.40157967e-02   9.94491316e-01   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   7.40157967e-02   9.94491316e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
```

Full poles (Re↓):
```
 1: +6.911023e-01 +0.000000e+00i
 2: +1.358762e-01 +5.234541e-01i
 3: +1.358762e-01 -5.234541e-01i
 4: +5.776787e-03 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: +0.000000e+00 +0.000000e+00i
 9: -1.077485e-02 +4.980131e+00i
10: -1.077485e-02 -4.980131e+00i
11: -1.527533e+00 +0.000000e+00i
12: -1.532595e+00 +0.000000e+00i
```
Reduced sagittal poles:
```
 1: +1.358762e-01 +5.234541e-01i
 2: +1.358762e-01 -5.234541e-01i
 3: +5.776787e-03 +0.000000e+00i
 4: +0.000000e+00 +0.000000e+00i
 5: -1.532595e+00 +0.000000e+00i
```
Unstable full: +0.6911+0i; +0.1359+0.5235i; +0.1359-0.5235i; +0.005777+0i
Unstable reduced: +0.1359+0.5235i; +0.1359-0.5235i; +0.005777+0i

| Check | Rank | Cond(σmax/σmin) | σmin | Tol |
|---|---:|---:|---:|---:|
| Ctrl (scaled) | 5/5 | 105.9 | 0.03018 | 4.441e-15 |
| Obs y-map (scaled) | 5/5 | 22.01 | 0.864 | 1.066e-13 |
| Obs state I5 (scaled) | 5/5 | 18.91 | 1 | 8.882e-14 |

Finite-horizon gains Gfh=y(T=0.600s) unit step (DERIVED):
```
 -2.18279448e-03   5.47526154e-04
  1.33026846e-01   2.39464806e-04
 -1.05503052e-01   1.73083812e-03
  2.75237943e-02   1.97030292e-03
 -1.04905188e-01   3.90059274e-04
 -4.51467799e-01  -4.63266023e-04
```
Ridge-DC Gdc (ASSUMED regularizer):
```
 -2.68432054e+05   3.17474165e+04
 -3.84726959e+01   4.49224062e+00
  1.17035279e+01  -1.32625537e+00
 -2.67691680e+01   3.16598526e+00
  7.36569047e+00  -8.42475465e-01
  3.84726959e-03  -4.49224062e-04
```
Gfh = reduced LTI step @ T=0.600s (DERIVED); Gdc = ridge-DC eps=1e-04 (ASSUMED regularizer; z-integrator)

Elevator/thrust cross-coupling (|Gfh| ratio δe/thrust):

| Out | |G_de| | |G_th| | ratio | elev-dom? |
|---|---:|---:|---:|:---:|
| z | 0.002183 | 0.0005475 | 3.987 | Y |
| theta_phys | 0.133 | 0.0002395 | 555.5 | Y |
| alpha | 0.1055 | 0.001731 | 60.95 | Y |
| gamma | 0.02752 | 0.00197 | 13.97 | Y |
| w | 0.1049 | 0.0003901 | 268.9 | Y |
| q | 0.4515 | 0.0004633 | 974.5 | Y |

NL vs LTI validation (elev_pulse + theta_ic): **PASS** (2/2)

| Channel | PASS | z | θ_phys | α | γ | w | q |
|---|:---:|---:|---:|---:|---:|---:|---:|
| elev_pulse | PASS | n0 | 3.18e-05 / 1.000 | 7.65e-06 / 1.000 | 2.43e-05 / 1.000 | 2.6e-05 / 1.000 | 0.000869 / 1.000 |
| theta_ic | PASS | 1.78e-06 / 1.000 | 5.51e-05 / 1.000 | n0 | 3.43e-05 / 1.000 | 7.62e-05 / 1.000 | 0.00205 / 1.000 |

Cells: `nrmse_rel / corr` (n0 = near-zero excluded).

### Operating point: LEVEL_U1.5

```
U_cmd(BODY surge)=1.500  u*=1.5  w*=-0.0500278  U_total=1.50083
x* = [0            0            0            0   -0.0333395            0          1.5            0   -0.0500278            0 -1.42497e-24            0]
u* = [0 -0.116328   3.81167]
trim: θ=-0.0333395 θ_phys=0.0333395 α=-0.0333395 γ=3.19189e-16
dα/du=0.0222099  dα/dw=0.665926
norm_dyn=8.387e-13  slope_err=4.718e-16  trim=PASS  jac=PASS  exitflag=1
dA_rel=3.253e-05  dB_rel=1.979e-13  (gate <=1%)
class: steady_translating_trim (level; BODY u*=U_cmd=1.5 exact-by-construction)
```

A_sag (5×5) [z θ u w q]:
```
  0.00000000e+00  -1.50083403e+00   3.33333546e-02   9.99444289e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
  0.00000000e+00   1.70031355e-01  -1.53847597e-01  -8.73896218e-02   1.13619050e-01
  0.00000000e+00   1.87717275e-02   6.88533429e-02  -9.74158170e-01   5.97345730e-01
  0.00000000e+00  -7.34036109e-01   1.08818146e-01   4.59202348e+00  -5.03422372e-01
```

B_sag (5×2) [δe thrust]:
```
  0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00
  3.04236535e-02   3.12736081e-02
 -2.79387109e-01   6.67559000e-05
 -1.59865815e+00  -2.30327653e-03
```

C_y (6×5):
```
  1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   2.22098873e-02   6.65925925e-01   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   2.22098873e-02   6.65925925e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
```

Full poles (Re↓):
```
 1: +1.027367e+00 +0.000000e+00i
 2: +3.518770e-01 +2.594455e-01i
 3: +3.518770e-01 -2.594455e-01i
 4: +0.000000e+00 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: -1.733075e-02 +4.989431e+00i
 9: -1.733075e-02 -4.989431e+00i
10: -6.822512e-02 +0.000000e+00i
11: -2.266957e+00 +0.000000e+00i
12: -2.279464e+00 +0.000000e+00i
```
Reduced sagittal poles:
```
 1: +3.518770e-01 +2.594455e-01i
 2: +3.518770e-01 -2.594455e-01i
 3: +0.000000e+00 +0.000000e+00i
 4: -6.822512e-02 +0.000000e+00i
 5: -2.266957e+00 +0.000000e+00i
```
Unstable full: +1.027+0i; +0.3519+0.2594i; +0.3519-0.2594i
Unstable reduced: +0.3519+0.2594i; +0.3519-0.2594i

| Check | Rank | Cond(σmax/σmin) | σmin | Tol |
|---|---:|---:|---:|---:|
| Ctrl (scaled) | 5/5 | 173.5 | 0.05995 | 1.776e-14 |
| Obs y-map (scaled) | 5/5 | 92.15 | 0.7816 | 4.263e-13 |
| Obs state I5 (scaled) | 5/5 | 71.87 | 1 | 3.553e-13 |

Finite-horizon gains Gfh=y(T=0.600s) unit step (DERIVED):
```
  1.79578391e-02   3.11798663e-04
  3.12771573e-01   2.26484659e-04
 -1.89543746e-01   5.52382275e-04
  1.23227827e-01   7.78866934e-04
 -2.83933213e-01   2.32956905e-04
 -1.09556683e+00  -4.16743222e-04
```
Ridge-DC Gdc (ASSUMED regularizer):
```
  1.97521016e+05  -5.77334621e+03
  1.45770340e+01  -4.35579701e-01
 -1.41628389e+00   5.09038410e-02
  1.31607501e+01  -3.84675860e-01
 -1.62718618e+00   5.46539408e-02
 -1.45770340e-03   4.35579701e-05
```
Gfh = reduced LTI step @ T=0.600s (DERIVED); Gdc = ridge-DC eps=1e-04 (ASSUMED regularizer; z-integrator)

Elevator/thrust cross-coupling (|Gfh| ratio δe/thrust):

| Out | |G_de| | |G_th| | ratio | elev-dom? |
|---|---:|---:|---:|:---:|
| z | 0.01796 | 0.0003118 | 57.59 | Y |
| theta_phys | 0.3128 | 0.0002265 | 1381 | Y |
| alpha | 0.1895 | 0.0005524 | 343.1 | Y |
| gamma | 0.1232 | 0.0007789 | 158.2 | Y |
| w | 0.2839 | 0.000233 | 1219 | Y |
| q | 1.096 | 0.0004167 | 2629 | Y |

NL vs LTI validation (elev_pulse + theta_ic): **PASS** (2/2)

| Channel | PASS | z | θ_phys | α | γ | w | q |
|---|:---:|---:|---:|---:|---:|---:|---:|
| elev_pulse | PASS | n0 | 0.00017 / 1.000 | 4.69e-05 / 1.000 | 0.000123 / 1.000 | 0.000237 / 1.000 | 0.00477 / 1.000 |
| theta_ic | PASS | 2.03e-06 / 1.000 | 5.65e-05 / 1.000 | 2.16e-05 / 1.000 | 3.58e-05 / 1.000 | 0.000109 / 1.000 | 0.00208 / 1.000 |

Cells: `nrmse_rel / corr` (n0 = near-zero excluded).

### Operating point: LEVEL_U2.0

```
U_cmd(BODY surge)=2.000  u*=2  w*=-0.0376238  U_total=2.00035
x* = [0            0            0            0   -0.0188097            0            2            0   -0.0376238            0 -9.28939e-26            0]
u* = [0 -0.0690247    6.57404]
trim: θ=-0.0188097 θ_phys=0.0188097 α=-0.0188097 γ=0
dα/du=0.00940263  dα/dw=0.499823
norm_dyn=2.431e-14  slope_err=6.939e-18  trim=PASS  jac=PASS  exitflag=1
dA_rel=3.153e-05  dB_rel=3.239e-13  (gate <=1%)
class: steady_translating_trim (level; BODY u*=U_cmd=2.0 exact-by-construction)
```

A_sag (5×5) [z θ u w q]:
```
  0.00000000e+00  -2.00035386e+00   1.88085970e-02   9.99823103e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
  0.00000000e+00   1.70100653e-01  -2.04234659e-01  -1.15584899e-01   9.09715534e-02
  0.00000000e+00   1.98777800e-02   5.32870681e-02  -1.18303976e+00   7.96391698e-01
  0.00000000e+00  -7.34569297e-01   9.80369945e-02   6.07358816e+00  -6.68838524e-01
```

B_sag (5×2) [δe thrust]:
```
  0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00
  5.40864950e-02   3.12736081e-02
 -4.96688193e-01   6.67559000e-05
 -2.84205893e+00  -2.30327653e-03
```

C_y (6×5):
```
  1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   9.40263492e-03   4.99823118e-01   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   9.40263492e-03   4.99823118e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
```

Full poles (Re↓):
```
 1: +1.366144e+00 +0.000000e+00i
 2: +9.387228e-01 +0.000000e+00i
 3: +1.871711e-01 +0.000000e+00i
 4: +0.000000e+00 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: -2.368576e-02 +4.995734e+00i
 9: -2.368576e-02 -4.995734e+00i
10: -1.557137e-01 +0.000000e+00i
11: -3.026293e+00 +0.000000e+00i
12: -3.034310e+00 +0.000000e+00i
```
Reduced sagittal poles:
```
 1: +9.387228e-01 +0.000000e+00i
 2: +1.871711e-01 +0.000000e+00i
 3: +0.000000e+00 +0.000000e+00i
 4: -1.557137e-01 +0.000000e+00i
 5: -3.026293e+00 +0.000000e+00i
```
Unstable full: +1.366+0i; +0.9387+0i; +0.1872+0i
Unstable reduced: +0.9387+0i; +0.1872+0i

| Check | Rank | Cond(σmax/σmin) | σmin | Tol |
|---|---:|---:|---:|---:|
| Ctrl (scaled) | 5/5 | 699.3 | 0.09593 | 1.421e-13 |
| Obs y-map (scaled) | 5/5 | 338.7 | 0.6104 | 8.527e-13 |
| Obs state I5 (scaled) | 5/5 | 206.5 | 1 | 7.105e-13 |

Finite-horizon gains Gfh=y(T=0.600s) unit step (DERIVED):
```
  7.72804826e-02   2.36463272e-04
  5.85899527e-01   2.42965250e-04
 -2.96119087e-01   2.20062082e-04
  2.89780440e-01   4.63027332e-04
 -5.92018192e-01   1.08677530e-04
 -2.12843126e+00  -5.22631438e-04
```
Ridge-DC Gdc (ASSUMED regularizer):
```
  2.97528993e+05  -2.99861105e+03
  1.55990521e+01  -1.60146165e-01
 -7.25234066e-01   1.02421345e-02
  1.48738181e+01  -1.49904030e-01
 -1.22469589e+00   1.52667383e-02
 -1.55990521e-03   1.60146165e-05
```
Gfh = reduced LTI step @ T=0.600s (DERIVED); Gdc = ridge-DC eps=1e-04 (ASSUMED regularizer; z-integrator)

Elevator/thrust cross-coupling (|Gfh| ratio δe/thrust):

| Out | |G_de| | |G_th| | ratio | elev-dom? |
|---|---:|---:|---:|:---:|
| z | 0.07728 | 0.0002365 | 326.8 | Y |
| theta_phys | 0.5859 | 0.000243 | 2411 | Y |
| alpha | 0.2961 | 0.0002201 | 1346 | Y |
| gamma | 0.2898 | 0.000463 | 625.8 | Y |
| w | 0.592 | 0.0001087 | 5447 | Y |
| q | 2.128 | 0.0005226 | 4073 | Y |

NL vs LTI validation (elev_pulse + theta_ic): **PASS** (2/2)

| Channel | PASS | z | θ_phys | α | γ | w | q |
|---|:---:|---:|---:|---:|---:|---:|---:|
| elev_pulse | PASS | n0 | 0.000575 / 1.000 | 0.000167 / 1.000 | 0.000409 / 1.000 | 0.00112 / 1.000 | 0.0167 / 0.999 |
| theta_ic | PASS | 2.24e-06 / 1.000 | 5.82e-05 / 1.000 | 2.11e-05 / 1.000 | 3.75e-05 / 1.000 | 0.000141 / 1.000 | 0.00216 / 1.000 |

Cells: `nrmse_rel / corr` (n0 = near-zero excluded).

### Operating point: CLIMB_U1.0

```
U_cmd(BODY surge)=1.000  u*=1  w*=-0.108807  U_total=1.0059
x* = [0         0         0         0 -0.488887         0         1         0 -0.108807         0 -2.13e-25         0]
u* = [0 0.0257758   3.96822]
trim: θ=-0.488887 θ_phys=0.488887 α=-0.10838 γ=0.380506
dα/du=0.107534  dα/dw=0.9883
norm_dyn=2.396e-13  slope_err=2.220e-16  trim=PASS  jac=PASS  exitflag=1
dA_rel=3.74e-05  dB_rel=5.785e-14  (gate <=1%)
class: steady_translating_trim (climb; BODY u*=U_cmd=1.0 exact-by-construction)
```

A_sag (5×5) [z θ u w q]:
```
  0.00000000e+00  -9.33956578e-01   4.69643211e-01   8.82856305e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
  0.00000000e+00   1.50049790e-01  -9.44070125e-02  -6.06847776e-02   2.32778406e-01
  0.00000000e+00  -1.66943372e-02   4.95901647e-02  -9.50007137e-01   3.98406784e-01
  0.00000000e+00  -6.40688113e-01  -3.56132101e-01   3.18877595e+00  -3.41698777e-01
```

B_sag (5×2) [δe thrust]:
```
  0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00
  1.35216238e-02   3.12736081e-02
 -1.24172048e-01   6.67559000e-05
 -7.10514733e-01  -2.30327653e-03
```

C_y (6×5):
```
  1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   1.07533509e-01   9.88299646e-01   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   1.07533509e-01   9.88299646e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
```

Full poles (Re↓):
```
 1: +7.569139e-01 +0.000000e+00i
 2: +2.080454e-01 +6.356908e-01i
 3: +2.080454e-01 -6.356908e-01i
 4: +0.000000e+00 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: -9.015667e-03 +4.694144e+00i
 9: -9.015667e-03 -4.694144e+00i
10: -1.221539e-01 +0.000000e+00i
11: -1.596863e+00 +0.000000e+00i
12: -1.680050e+00 +0.000000e+00i
```
Reduced sagittal poles:
```
 1: +2.080454e-01 +6.356908e-01i
 2: +2.080454e-01 -6.356908e-01i
 3: +0.000000e+00 +0.000000e+00i
 4: -1.221539e-01 +0.000000e+00i
 5: -1.680050e+00 +0.000000e+00i
```
Unstable full: +0.7569+0i; +0.208+0.6357i; +0.208-0.6357i
Unstable reduced: +0.208+0.6357i; +0.208-0.6357i

| Check | Rank | Cond(σmax/σmin) | σmin | Tol |
|---|---:|---:|---:|---:|
| Ctrl (scaled) | 5/5 | 138.6 | 0.0545 | 8.882e-15 |
| Obs y-map (scaled) | 5/5 | 35.34 | 0.6979 | 1.066e-13 |
| Obs state I5 (scaled) | 5/5 | 24.53 | 1 | 8.882e-14 |

Finite-horizon gains Gfh=y(T=0.600s) unit step (DERIVED):
```
 -1.73889076e-03   2.71312559e-03
  1.33096069e-01   7.41802699e-04
 -1.02373537e-01   1.94933350e-03
  3.07225320e-02   2.69113620e-03
 -1.00890415e-01   8.18613057e-06
 -4.51122214e-01  -2.96235504e-03
```
Ridge-DC Gdc (ASSUMED regularizer):
```
  1.76655787e+03   1.74770405e+03
  1.18056196e+00   6.34333957e-02
 -3.64430474e-01   3.64899175e-02
  8.16131484e-01   9.99233132e-02
 -1.93880577e-01   1.27685221e-02
 -1.18056196e-04  -6.34333957e-06
```
Gfh = reduced LTI step @ T=0.600s (DERIVED); Gdc = ridge-DC eps=1e-04 (ASSUMED regularizer; z-integrator)

Elevator/thrust cross-coupling (|Gfh| ratio δe/thrust):

| Out | |G_de| | |G_th| | ratio | elev-dom? |
|---|---:|---:|---:|:---:|
| z | 0.001739 | 0.002713 | 0.6409 | N |
| theta_phys | 0.1331 | 0.0007418 | 179.4 | Y |
| alpha | 0.1024 | 0.001949 | 52.52 | Y |
| gamma | 0.03072 | 0.002691 | 11.42 | Y |
| w | 0.1009 | 8.186e-06 | 1.232e+04 | Y |
| q | 0.4511 | 0.002962 | 152.3 | Y |

NL vs LTI validation (elev_pulse + theta_ic): **PASS** (2/2)

| Channel | PASS | z | θ_phys | α | γ | w | q |
|---|:---:|---:|---:|---:|---:|---:|---:|
| elev_pulse | PASS | n0 | 3.2e-05 / 1.000 | 7.66e-06 / 1.000 | 2.44e-05 / 1.000 | 2.55e-05 / 1.000 | 0.000873 / 1.000 |
| theta_ic | PASS | 1.06e-05 / 1.000 | 3e-05 / 1.000 | 1.7e-05 / 1.000 | 1.82e-05 / 1.000 | 5.2e-05 / 1.000 | 0.00142 / 1.000 |

Cells: `nrmse_rel / corr` (n0 = near-zero excluded).

### Operating point: CLIMB_U1.5

```
U_cmd(BODY surge)=1.500  u*=1.5  w*=-0.0770689  U_total=1.50198
x* = [0            0            0            0    -0.431841            0          1.5            0   -0.0770689            0 -2.34823e-24            0]
u* = [0 -0.0210529    5.73772]
trim: θ=-0.431841 θ_phys=0.431841 α=-0.0513342 γ=0.380506
dα/du=0.0341627  dα/dw=0.664911
norm_dyn=1.388e-12  slope_err=3.220e-15  trim=PASS  jac=PASS  exitflag=1
dA_rel=3.543e-05  dB_rel=4.948e-14  (gate <=1%)
class: steady_translating_trim (climb; BODY u*=U_cmd=1.5 exact-by-construction)
```

A_sag (5×5) [z θ u w q]:
```
  0.00000000e+00  -1.39455209e+00   4.18543073e-01   9.08196948e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
  0.00000000e+00   1.54378228e-01  -1.48436336e-01  -8.82586927e-02   1.69895066e-01
  0.00000000e+00  -1.22916393e-02   4.73306786e-02  -1.08187446e+00   5.97408134e-01
  0.00000000e+00  -6.60210470e-01  -1.75524992e-01   4.63769017e+00  -5.05575500e-01
```

B_sag (5×2) [δe thrust]:
```
  0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00
  3.04236535e-02   3.12736081e-02
 -2.79387109e-01   6.67559000e-05
 -1.59865815e+00  -2.30327653e-03
```

C_y (6×5):
```
  1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   3.41626772e-02   6.64911413e-01   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   3.41626772e-02   6.64911413e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
```

Full poles (Re↓):
```
 1: +1.069547e+00 +0.000000e+00i
 2: +3.905341e-01 +4.179490e-01i
 3: +3.905341e-01 -4.179490e-01i
 4: +0.000000e+00 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: -1.565515e-02 +4.763396e+00i
 9: -1.565515e-02 -4.763396e+00i
10: -1.454494e-01 +0.000000e+00i
11: -2.324995e+00 +0.000000e+00i
12: -2.371505e+00 +0.000000e+00i
```
Reduced sagittal poles:
```
 1: +3.905341e-01 +4.179490e-01i
 2: +3.905341e-01 -4.179490e-01i
 3: +0.000000e+00 +0.000000e+00i
 4: -1.454494e-01 +0.000000e+00i
 5: -2.371505e+00 +0.000000e+00i
```
Unstable full: +1.07+0i; +0.3905+0.4179i; +0.3905-0.4179i
Unstable reduced: +0.3905+0.4179i; +0.3905-0.4179i

| Check | Rank | Cond(σmax/σmin) | σmin | Tol |
|---|---:|---:|---:|---:|
| Ctrl (scaled) | 5/5 | 207.9 | 0.06732 | 1.776e-14 |
| Obs y-map (scaled) | 5/5 | 315.2 | 0.2624 | 4.263e-13 |
| Obs state I5 (scaled) | 5/5 | 82.55 | 1 | 3.553e-13 |

Finite-horizon gains Gfh=y(T=0.600s) unit step (DERIVED):
```
  1.75190839e-02   2.42384531e-03
  3.12869507e-01   5.40519780e-04
 -1.84706037e-01   5.92576939e-04
  1.28163471e-01   1.13309672e-03
 -2.75878587e-01  -2.58023981e-05
 -1.09478992e+00  -1.98865178e-03
```
Ridge-DC Gdc (ASSUMED regularizer):
```
  3.74060275e+04   8.91613510e+02
  4.06926980e+00  -5.24866781e-03
 -3.81456532e-01   1.33172210e-02
  3.68781326e+00   8.06855322e-03
 -3.78449604e-01   9.21182076e-03
 -4.06926980e-04   5.24866781e-07
```
Gfh = reduced LTI step @ T=0.600s (DERIVED); Gdc = ridge-DC eps=1e-04 (ASSUMED regularizer; z-integrator)

Elevator/thrust cross-coupling (|Gfh| ratio δe/thrust):

| Out | |G_de| | |G_th| | ratio | elev-dom? |
|---|---:|---:|---:|:---:|
| z | 0.01752 | 0.002424 | 7.228 | Y |
| theta_phys | 0.3129 | 0.0005405 | 578.8 | Y |
| alpha | 0.1847 | 0.0005926 | 311.7 | Y |
| gamma | 0.1282 | 0.001133 | 113.1 | Y |
| w | 0.2759 | 2.58e-05 | 1.069e+04 | Y |
| q | 1.095 | 0.001989 | 550.5 | Y |

NL vs LTI validation (elev_pulse + theta_ic): **PASS** (2/2)

| Channel | PASS | z | θ_phys | α | γ | w | q |
|---|:---:|---:|---:|---:|---:|---:|---:|
| elev_pulse | PASS | n0 | 0.000171 / 1.000 | 4.62e-05 / 1.000 | 0.000125 / 1.000 | 0.000233 / 1.000 | 0.00479 / 1.000 |
| theta_ic | PASS | 1.55e-05 / 1.000 | 3.47e-05 / 1.000 | 1.52e-05 / 1.000 | 2.13e-05 / 1.000 | 7.48e-05 / 1.000 | 0.00157 / 1.000 |

Cells: `nrmse_rel / corr` (n0 = near-zero excluded).

### Operating point: CLIMB_U2.0

```
U_cmd(BODY surge)=2.000  u*=2  w*=-0.0592303  U_total=2.00088
x* = [0           0           0           0   -0.410113           0           2           0  -0.0592303           0 2.45148e-25           0]
u* = [0 -0.0191344    8.47356]
trim: θ=-0.410113 θ_phys=0.410113 α=-0.0296065 γ=0.380506
dα/du=0.0147946  dα/dw=0.499562
norm_dyn=4.101e-13  slope_err=1.110e-16  trim=PASS  jac=PASS  exitflag=1
dA_rel=3.389e-05  dB_rel=7.535e-15  (gate <=1%)
class: steady_translating_trim (climb; BODY u*=U_cmd=2.0 exact-by-construction)
```

A_sag (5×5) [z θ u w q]:
```
  0.00000000e+00  -1.85776753e+00   3.98712867e-01   9.17075815e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
  0.00000000e+00   1.55895471e-01  -2.00300639e-01  -1.16279308e-01   1.35937460e-01
  0.00000000e+00  -1.06034477e-02   3.96687237e-02  -1.26910770e+00   7.96441560e-01
  0.00000000e+00  -6.67084497e-01  -1.08682201e-01   6.11007695e+00  -6.70558926e-01
```

B_sag (5×2) [δe thrust]:
```
  0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00
  5.40864950e-02   3.12736081e-02
 -4.96688193e-01   6.67559000e-05
 -2.84205893e+00  -2.30327653e-03
```

C_y (6×5):
```
  1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   1.47946117e-02   4.99561855e-01   0.00000000e+00
  0.00000000e+00  -1.00000000e+00   1.47946117e-02   4.99561855e-01   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
  0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
```

Full poles (Re↓):
```
 1: +1.396199e+00 +0.000000e+00i
 2: +8.101968e-01 +0.000000e+00i
 3: +3.486419e-01 +0.000000e+00i
 4: +0.000000e+00 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: -2.197281e-02 +4.791261e+00i
 9: -2.197281e-02 -4.791261e+00i
10: -1.931973e-01 +0.000000e+00i
11: -3.067791e+00 +0.000000e+00i
12: -3.105609e+00 +0.000000e+00i
```
Reduced sagittal poles:
```
 1: +8.101968e-01 +0.000000e+00i
 2: +3.486419e-01 +0.000000e+00i
 3: +0.000000e+00 +0.000000e+00i
 4: -1.931973e-01 +0.000000e+00i
 5: -3.105609e+00 +0.000000e+00i
```
Unstable full: +1.396+0i; +0.8102+0i; +0.3486+0i
Unstable reduced: +0.8102+0i; +0.3486+0i

| Check | Rank | Cond(σmax/σmin) | σmin | Tol |
|---|---:|---:|---:|---:|
| Ctrl (scaled) | 5/5 | 728.7 | 0.09424 | 1.421e-13 |
| Obs y-map (scaled) | 5/5 | 1025 | 0.2187 | 8.527e-13 |
| Obs state I5 (scaled) | 5/5 | 224 | 1 | 7.105e-13 |

Finite-horizon gains Gfh=y(T=0.600s) unit step (DERIVED):
```
  7.36451733e-02   2.30741004e-03
  5.85824526e-01   4.72702202e-04
 -2.89922095e-01   2.09571745e-04
  2.95902431e-01   6.82273947e-04
 -5.78966693e-01  -1.01909379e-04
 -2.12567010e+00  -1.68426895e-03
```
Ridge-DC Gdc (ASSUMED regularizer):
```
  1.20421067e+05   4.05884401e+02
  7.93371468e+00  -1.62374003e-02
 -3.33278388e-01   4.99858009e-03
  7.60043629e+00  -1.12388202e-02
 -5.00947928e-01   5.09780553e-03
 -7.93371468e-04   1.62374003e-06
```
Gfh = reduced LTI step @ T=0.600s (DERIVED); Gdc = ridge-DC eps=1e-04 (ASSUMED regularizer; z-integrator)

Elevator/thrust cross-coupling (|Gfh| ratio δe/thrust):

| Out | |G_de| | |G_th| | ratio | elev-dom? |
|---|---:|---:|---:|:---:|
| z | 0.07365 | 0.002307 | 31.92 | Y |
| theta_phys | 0.5858 | 0.0004727 | 1239 | Y |
| alpha | 0.2899 | 0.0002096 | 1383 | Y |
| gamma | 0.2959 | 0.0006823 | 433.7 | Y |
| w | 0.579 | 0.0001019 | 5681 | Y |
| q | 2.126 | 0.001684 | 1262 | Y |

NL vs LTI validation (elev_pulse + theta_ic): **PASS** (2/2)

| Channel | PASS | z | θ_phys | α | γ | w | q |
|---|:---:|---:|---:|---:|---:|---:|---:|
| elev_pulse | PASS | n0 | 0.000577 / 1.000 | 0.000164 / 1.000 | 0.000413 / 1.000 | 0.0011 / 1.000 | 0.0167 / 0.999 |
| theta_ic | PASS | 2.03e-05 / 1.000 | 3.78e-05 / 1.000 | 1.49e-05 / 1.000 | 2.38e-05 / 1.000 | 9.89e-05 / 1.000 | 0.00169 / 1.000 |

Cells: `nrmse_rel / corr` (n0 = near-zero excluded).

## Interpolation / LPV consistency

Interpolation/LPV consistency DERIVED from IDENTIFIED A,B at discrete U_cmd. Confidence proxy = residual-spread / pole-migration only; NO invented hydro coefficient confidence.

### LEVEL

- Validity envelope: U_cmd in [1.0, 2.0] with 3/3 valid
- Residuals @ U=[1 1.5 2]: [4.408e-14 8.387e-13 2.431e-14]
- Residual spread (confidence proxy): 8.144e-13 (max=8.387e-13)
- Hydro coefficient CI: **NOT_CLAIMED (TO_BE_IDENTIFIED; no invented hydro CI)**
- maxRe(reduced) @ U: [0.1359 0.3519 0.9387]
- ||A||_F: [3.79 5.247 6.783]; ||B||_F: [0.7221  1.623  2.886]
- Linear interp U=1.5 from {1.0,2.0}: dA_rel=0.006438 dB_rel=0.1111 (OK; ASSUMED smoothness gate 25% Frobenius vs linear U-interp)

### CLIMB

- Validity envelope: U_cmd in [1.0, 2.0] with 3/3 valid
- Residuals @ U=[1 1.5 2]: [2.396e-13 1.388e-12 4.101e-13]
- Residual spread (confidence proxy): 1.149e-12 (max=1.388e-12)
- Hydro coefficient CI: **NOT_CLAIMED (TO_BE_IDENTIFIED; no invented hydro CI)**
- maxRe(reduced) @ U: [0.208 0.3905 0.8102]
- ||A||_F: [3.853 5.271 6.785]; ||B||_F: [0.7221  1.623  2.886]
- Linear interp U=1.5 from {1.0,2.0}: dA_rel=0.01303 dB_rel=0.1111 (OK; ASSUMED smoothness gate 25% Frobenius vs linear U-interp)

## Next

- Exact next task: `depth_gamma_structural_decoupling_governor_aw_gate`
- Gate-1 speed-scheduled family PASS → Gate 2 structural depth/γ decoupling + reference governor + anti-windup (no rejected methods).
- Reusable artifacts: `suite_results/DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}`
