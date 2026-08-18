# LOCAL_SS_LEVEL_001 — Local state-space at level trim

**Verdict: PASS**

## Provenance

- Plant RHS (exact): `underwater777_vehicle_dynamics.m`
- Trim: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\TRIM_OPERATING_POINTS.mat` (OP.level)
- Method: scale-aware central finite difference; steps `eps_rel` and `eps_rel/2`
- eps_rel = 0.0001; x_scale / u_scale from TRIM audit
- No controller/guidance changes; production frozen
- Artifacts: `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.md`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.mat`, `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\LOCAL_SS_LEVEL.png`

## Operating point

```
x* = [0              0              0              0   -0.022766828              0      1.8171783              0   -0.041378536              0 -3.3105035e-29              0]
u* = [delta_r=0, delta_e=-0.082428446, thrust=5.4632865]
f(x*,u*) = [1.818e+00  0.000e+00  0.000e+00  0.000e+00 -3.311e-29  0.000e+00 -4.447e-19  0.000e+00 -1.007e-16  0.000e+00  2.337e-17  0.000e+00]
||f||_2=1.818e+00  ||nu_dot||_2=1.034e-16
```

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
| ||A_half-A_eps||_F / ||A_eps||_F | 3.19138e-05 (0.003%) | ≤1% |
| ||B_half-B_eps||_F / ||B_eps||_F | 1.47636e-13 (0.000%) | ≤1% |
| Dominant eig sign/structure stable | YES (max rel Δ=0.000237) | required |
| **PASS** | **PASS** | |

Reported A,B use **half-step** (eps_rel/2=5e-05).

## A (12×12)

```
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   2.22044605e-12   0.00000000e+00   9.99740847e-01   0.00000000e+00  -2.27648609e-02   0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   4.13785356e-02   0.00000000e+00   1.81764940e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00  -1.81764940e+00   0.00000000e+00   2.27648609e-02   0.00000000e+00   9.99740847e-01   0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   7.53826866e-31   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00  -2.27707620e-02
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00  -3.31136162e-29   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00025922e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.70085338e-01   0.00000000e+00  -1.85812687e-01   0.00000000e+00  -1.05250393e-01   0.00000000e+00   9.76276231e-02   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00  -3.05053964e-01   0.00000000e+00   0.00000000e+00   0.00000000e+00  -9.60599162e-01   0.00000000e+00  -4.13785852e-02   0.00000000e+00  -6.98091587e-01
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.95769584e-02   0.00000000e+00   5.81812142e-02   0.00000000e+00  -1.10355355e+00   0.00000000e+00   7.23610071e-01   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00  -2.49084237e+01   0.00000000e+00   0.00000000e+00   0.00000000e+00  -2.36607993e+00   0.00000000e+00  -5.37665937e-06   0.00000000e+00   2.75645538e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00  -7.34439448e-01   0.00000000e+00   1.02069387e-01   0.00000000e+00   5.53054544e+00   0.00000000e+00  -6.08293049e-01   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00  -7.06787696e-02   0.00000000e+00   0.00000000e+00   0.00000000e+00  -5.45813739e+00   0.00000000e+00  -1.14768892e-08   0.00000000e+00  -5.98152876e-01
```

## B (12×3)

```
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   4.46502561e-02   3.12736081e-02
 5.65228839e-01   0.00000000e+00   0.00000000e+00
 0.00000000e+00  -4.10033133e-01   6.67559000e-05
 1.39223171e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00  -2.34621710e+00  -2.30327653e-03
 2.56891178e+00   0.00000000e+00   0.00000000e+00
```

## C = I_12, D = 0_{12×3}

## Eigenvalues of A (sorted by Re descending)

```
 1: +1.242290e+00 +0.000000e+00i
 2: +7.350478e-01 +0.000000e+00i
 3: +2.410699e-01 +0.000000e+00i
 4: +0.000000e+00 +0.000000e+00i
 5: +0.000000e+00 +0.000000e+00i
 6: +0.000000e+00 +0.000000e+00i
 7: +0.000000e+00 +0.000000e+00i
 8: -2.138805e-02 +4.993445e+00i
 9: -2.138805e-02 -4.993445e+00i
10: -1.258984e-01 +0.000000e+00i
11: -2.747879e+00 +0.000000e+00i
12: -2.758271e+00 +0.000000e+00i
```

## Vertical reduced model

States [z θ u w q], inputs [δe thrust]. **Coupling to lateral omitted.**

A_v (5×5):
```
 0.00000000e+00  -1.81764940e+00   2.27648609e-02   9.99740847e-01   0.00000000e+00
 0.00000000e+00   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00000000e+00
 0.00000000e+00   1.70085338e-01  -1.85812687e-01  -1.05250393e-01   9.76276231e-02
 0.00000000e+00   1.95769584e-02   5.81812142e-02  -1.10355355e+00   7.23610071e-01
 0.00000000e+00  -7.34439448e-01   1.02069387e-01   5.53054544e+00  -6.08293049e-01
```

B_v (5×2):
```
 0.00000000e+00   0.00000000e+00
 0.00000000e+00   0.00000000e+00
 4.46502561e-02   3.12736081e-02
-4.10033133e-01   6.67559000e-05
-2.34621710e+00  -2.30327653e-03
```

## Lateral reduced model

States [y φ ψ v p r], input [δr]. **Coupling to vertical omitted.**

A_l (6×6):
```
 0.00000000e+00   4.13785356e-02   1.81764940e+00   1.00000000e+00   0.00000000e+00   0.00000000e+00
 0.00000000e+00   7.53826866e-31   0.00000000e+00   0.00000000e+00   1.00000000e+00  -2.27707620e-02
 0.00000000e+00  -3.31136162e-29   0.00000000e+00   0.00000000e+00   0.00000000e+00   1.00025922e+00
 0.00000000e+00  -3.05053964e-01   0.00000000e+00  -9.60599162e-01  -4.13785852e-02  -6.98091587e-01
 0.00000000e+00  -2.49084237e+01   0.00000000e+00  -2.36607993e+00  -5.37665937e-06   2.75645538e+00
 0.00000000e+00  -7.06787696e-02   0.00000000e+00  -5.45813739e+00  -1.14768892e-08  -5.98152876e-01
```

B_l (6×1):
```
 0.00000000e+00
 0.00000000e+00
 0.00000000e+00
 5.65228839e-01
 1.39223171e+00
 2.56891178e+00
```

## Off-block coupling quantification

| Block | Frobenius norm | Relative |
|---|---:|---:|
| A_vertical | 6.2161 | 1 |
| A_lateral | 25.9151 | 1 |
| A(vert←lat) | 0 | 0 vs Av |
| A(lat←vert) | 0 | 0 vs Al |
| B(vert←δr) | 0 | |
| B(lat←[δe,thrust]) | 0 | |

Decoupled vertical [z,theta,u,w,q] w/ [de,thrust] and lateral [y,phi,psi,v,p,r] w/ [dr]; omitted: x-channel + cross V↔L blocks

## Translating-trim kinematic integrators / zero modes

Translating-trim kinematic integrators: plant forces/moments depend on attitude+body rates/speeds, not on inertial x,y,z (no current/density gradient). Columns of A for x,y,z are ~0 (pure kinematic integrators → near-zero eigenvalues). Yaw psi enters only through NED kinematics R(phi,theta,psi); at level trim with v=w≈0 rates≈0, psi is a free heading integrator (zero mode). Column Frobenius norms A(:,x,y,z,psi)=[0.000e+00 0.000e+00 0.000e+00 1.818e+00].

## Scales

```
x_scale = [10  10  10   1   1   1 1.5 0.3 0.3 0.2 0.2 0.2]
u_scale = [0.4363 0.2618     50]
state = [x y z phi theta psi u v w p q r]
input = [delta_r delta_e thrust]
```

## Next

- If PASS: reuse A,B for LTI vertical/lateral design about level trim.
- Climb trim linearization as separate LOCAL_SS_CLIMB task.
- Helix excluded from ordinary inertial LTI (periodic/quasi-steady).
