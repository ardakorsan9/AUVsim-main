# LOCAL_SS_CLIMB_TURN_001 — Local state-space at XZ climb trim

**Verdict: PASS**

## Provenance

- Plant RHS (exact): `underwater777_vehicle_dynamics.m`
- Trim: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_OPERATING_POINTS.mat` (OP.climb)
- Level compare: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.mat`
- Method: scale-aware central finite difference; steps `eps_rel` and `eps_rel/2` (same as LOCAL_SS_LEVEL)
- eps_rel = 0.0001; x_scale / u_scale from TRIM audit
- No controller/guidance changes; production frozen
- Helix: EXCLUDED (periodic/quasi-steady); no ordinary helix LTI fabricated
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_CLIMB.png`

## Operating point

```
x* = [0            0            0            0   -0.4185965            0      1.75462            0 -0.066866031            0 -1.12262e-27            0]
u* = [delta_r=0, delta_e=-0.021130121, thrust=7.0198724]
f(x*,u*) = [1.630e+00  0.000e+00  6.521e-01  0.000e+00 -1.123e-27  0.000e+00 -2.968e-17  0.000e+00 -1.147e-16  0.000e+00  1.020e-16  0.000e+00]
||f||_2=1.756e+00  ||nu_dot||_2=1.563e-16
```

## Perturbation dynamics (translating nominal)

Absolute plant at climb trim satisfies `ẋ* = f(x*,u*) ≠ 0` (steady translation along slope: ż* ≈ 0.4 ẋ*, ν̇* ≈ 0). The local LTI is the **perturbation** model:

```
δẋ = A δx + B δu
```

with δx = x − x*, δu = u − u*. Ideal C = I₁₂, D = 0.

## Units / frame / input signs

- State x=[x y z φ θ ψ u v w p q r]: NED position [m], Euler ZYX [rad], BODY velocities [m/s], BODY rates [rad/s]
- Input u=[δr δe thrust]: rudder [rad], elevator [rad], Xprop [N]
- Ideal C=I_12, D=0 (full-state)
- Signs: δr>0 → +Y/+N (Yuudr/Nuudr·u²); δe>0 → +Z/+M (Zuuds/Muuds·u²); thrust = +Xprop
- State units: m, m, m, rad, rad, rad, m/s, m/s, m/s, rad/s, rad/s, rad/s
- Input units: rad, rad, N

## Jacobian convergence gate

| Quantity | Value | Gate |
|---|---:|:---:|
| ||A_half-A_eps||_F / ||A_eps||_F | 3.46337e-05 (0.003%) | ≤1% |
| ||B_half-B_eps||_F / ||B_eps||_F | 1.56801e-15 (0.000%) | ≤1% |
| Dominant eig sign/structure stable | YES (max rel Δ=0.000218) | required |
| **PASS** | **PASS** | |

Reported A,B use **half-step** (eps_rel/2=5e-05).

## A (12×12)

```
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   6.52122507e-01   0.00000000e+00   9.13660333e-01   0.00000000e+00  -4.06478532e-01   0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   6.68660310e-02   0.00000000e+00   1.63030627e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00  -1.63030627e+00   0.00000000e+00   4.06478532e-01   0.00000000e+00   9.13660333e-01   0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   4.99442660e-28   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00  -4.44890204e-01
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00  -1.22870612e-27   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.09449865e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.55311779e-01   0.00000000e+00  -1.74968196e-01   0.00000000e+00  -1.02491953e-01   0.00000000e+00   1.50274161e-01   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00  -2.78787955e-01   0.00000000e+00   0.00000000e+00   0.00000000e+00  -9.27539940e-01   0.00000000e+00  -6.68660806e-02   0.00000000e+00  -6.74059122e-01
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00  -1.12632455e-02   0.00000000e+00   4.33698519e-02   0.00000000e+00  -1.17276450e+00   0.00000000e+00   6.98761321e-01   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00  -2.27637379e+01   0.00000000e+00   0.00000000e+00   0.00000000e+00  -2.28465079e+00   0.00000000e+00  -5.37665937e-06   0.00000000e+00   2.66156106e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00  -6.64437817e-01   0.00000000e+00  -1.35154882e-01   0.00000000e+00   5.38559892e+00   0.00000000e+00  -5.89502566e-01   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00  -6.45931277e-02   0.00000000e+00   0.00000000e+00   0.00000000e+00  -5.27023757e+00   0.00000000e+00  -1.14768892e-08   0.00000000e+00  -5.77564710e-01
```

## B (12×3)

```
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   4.16289044e-02   3.12736081e-02
 5.26981464e-01   0.00000000e+00   0.00000000e+00
 0.00000000e+00  -3.82287396e-01   6.67559000e-05
 1.29802348e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00  -2.18745548e+00  -2.30327653e-03
 2.39508106e+00   0.00000000e+00   0.00000000e+00
```

## C = I_12, D = 0_{12×3}

## Eigenvalues of A (sorted by Re descending)

```
 1: +1.235072e+00 +0.000000e+00i
 2: +4.870644e-01 +2.493178e-01i
 3: +4.870644e-01 -2.493178e-01i
 4: +0.000000e+00 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: -1.891401e-02 +4.779879e+00i
 9: -1.891401e-02 -4.779879e+00i
10: -1.685441e-01 +0.000000e+00i
11: -2.702354e+00 +0.000000e+00i
12: -2.742820e+00 +0.000000e+00i
```

## Vertical reduced model

States [z θ u w q], inputs [δe thrust]. **Coupling to lateral omitted.**

A_v (5×5):
```
 0.00000000e+00  -1.63030627e+00   4.06478532e-01   9.13660333e-01   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
 0.00000000e+00   1.55311779e-01  -1.74968196e-01  -1.02491953e-01   1.50274161e-01
 0.00000000e+00  -1.12632455e-02   4.33698519e-02  -1.17276450e+00   6.98761321e-01
 0.00000000e+00  -6.64437817e-01  -1.35154882e-01   5.38559892e+00  -5.89502566e-01
```

B_v (5×2):
```
 0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00
 4.16289044e-02   3.12736081e-02
-3.82287396e-01   6.67559000e-05
-2.18745548e+00  -2.30327653e-03
```

## Lateral reduced model

States [y φ ψ v p r], input [δr]. **Coupling to vertical omitted.**

A_l (6×6):
```
 0.00000000e+00   6.68660310e-02   1.63030627e+00   1.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   4.99442660e-28   0.00000000e+00   0.00000000e+00   1.00000000e+00  -4.44890204e-01
 0.00000000e+00  -1.22870612e-27   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.09449865e+00
 0.00000000e+00  -2.78787955e-01   0.00000000e+00  -9.27539940e-01  -6.68660806e-02  -6.74059122e-01
 0.00000000e+00  -2.27637379e+01   0.00000000e+00  -2.28465079e+00  -5.37665937e-06   2.66156106e+00
 0.00000000e+00  -6.45931277e-02   0.00000000e+00  -5.27023757e+00  -1.14768892e-08  -5.77564710e-01
```

B_l (6×1):
```
 0.00000000e+00
 0.00000000e+00
 0.00000000e+00
 5.26981464e-01
 1.29802348e+00
 2.39508106e+00
```

## Off-block coupling quantification

| Block | Frobenius norm | Relative |
|---|---:|---:|
| A_vertical | 6.03517 | 1 |
| A_lateral | 23.792 | 1 |
| A(vert←lat) | 0 | 0 vs Av |
| A(lat←vert) | 0 | 0 vs Al |
| B(vert←δr) | 0 | |
| B(lat←[δe,thrust]) | 0 | |

Decoupled vertical [z,theta,u,w,q] w/ [de,thrust] and lateral [y,phi,psi,v,p,r] w/ [dr]; omitted: x-channel + cross V↔L blocks

## Climb vs level comparison (scheduling)

| Quantity | Value |
|---|---:|
| ||A_climb−A_level||_F / ||A_level||_F | 0.0898265 (8.983%) |
| ||B_climb−B_level||_F / ||B_level||_F | 0.0676648 (6.766%) |
| ||ΔA_v||_F / ||A_v,level||_F | 0.0854254 (8.543%) |
| ||ΔB_v||_F / ||B_v,level||_F | 0.0676612 (6.766%) |

**Scheduling need:** YES — gain/model scheduling recommended (climb≠level)

Dominant eigenvalues (Re↓), level vs climb:

```
 1: level +1.242290e+00+0.000000e+00i | climb +1.235072e+00+0.000000e+00i | Δ -7.2178e-03+0.0000e+00i
 2: level +7.350478e-01+0.000000e+00i | climb +4.870644e-01+2.493178e-01i | Δ -2.4798e-01+2.4932e-01i
 3: level +2.410699e-01+0.000000e+00i | climb +4.870644e-01-2.493178e-01i | Δ +2.4599e-01-2.4932e-01i
 4: level +0.000000e+00+0.000000e+00i | climb +0.000000e+00+0.000000e+00i | Δ +0.0000e+00+0.0000e+00i
 5: level +0.000000e+00+0.000000e+00i | climb +0.000000e+00+0.000000e+00i | Δ +0.0000e+00+0.0000e+00i
 6: level +0.000000e+00+0.000000e+00i | climb +0.000000e+00+0.000000e+00i | Δ +0.0000e+00+0.0000e+00i
```

ΔA_v = A_v,climb − A_v,level:
```
 0.00000000e+00   1.87343129e-01   3.83713671e-01  -8.60805144e-02   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00  -1.47735586e-02   1.08444910e-02   2.75844001e-03   5.26465382e-02
 0.00000000e+00  -3.08402040e-02  -1.48113623e-02  -6.92109508e-02  -2.48487499e-02
 0.00000000e+00   7.00016318e-02  -2.37224269e-01  -1.44946517e-01   1.87904829e-02
```

ΔB_v:
```
 0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00
-3.02135169e-03   0.00000000e+00
 2.77457379e-02  -1.35525272e-20
 1.58761620e-01   0.00000000e+00
```

## Translating-trim kinematic integrators / zero modes

Translating-trim kinematic integrators: plant forces/moments depend on attitude+body rates/speeds, not on inertial x,y,z (no current/density gradient). Columns of A for x,y,z are ~0 (pure kinematic integrators → near-zero eigenvalues). Yaw psi enters only through NED kinematics R(phi,theta,psi); at climb trim with v≈0 rates≈0, psi is a free heading integrator (zero mode). Perturbation dynamics about translating nominal: δẋ = A δx + B δu (absolute ẋ* = f(x*,u*) ≠ 0 is kinematics of the steady climb; linear model is about δ). Column Frobenius norms A(:,x,y,z,psi)=[0.000e+00 0.000e+00 0.000e+00 1.630e+00].

## Helix (carry-forward)

Helix (TRIM OP.helix): EXCLUDED from ordinary inertial LTI — classified periodic/quasi-steady (rel residual ~0.02 > 1%). No fabricated rotating-frame A,B matrix in this task. Carry-forward only.

## Scales

```
x_scale = [10  10  10   1   1   1 1.5 0.3 0.3 0.2 0.2 0.2]
u_scale = [0.4363 0.2618     50]
state = [x y z phi theta psi u v w p q r]
input = [delta_r delta_e thrust]
```

## Next

- If PASS: use climb A,B for LTI vertical design about XZ trim; schedule vs level if needed.
- Helix remains EXCLUDED from ordinary inertial LTI (periodic/quasi-steady).
