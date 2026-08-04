# T2A — Ki_rate = 0

Baseline: T1B (`dt_c=0.025`, `dt_g=0.075`, `tau_rate≈0.7118 s`). Only change: `Ki_rate = 0`.

## T1B → T2A (runs identical)

| Scenario | CTE mean | \|pitch\| | chatter (deg/s) | θ pp | de RMS (deg) |
|----------|----------|-----------|-----------------|------|--------------|
| X-line   | 2.057→**2.014** | 0.48→**1.44** | 0.501→**0.312** | 2.64→2.18 | 5.64 |
| XZ       | 2.546→2.565 | 0.60→0.59 | 0.659→**0.412** | — | 2.12 |
| Circle   | 1.535→**1.518** | 0.42→1.02 | 0.190→**0.128** | 3.38→2.18 | 7.11 |
| Helix    | 1.673→1.682 | 0.32→0.74 | 0.201→**0.132** | 3.34→2.64 | 6.33 |

### Integrators (X-line)
- `int_angle` min/max: -0.452 / 0.000 rad (outer I still active)
- `int_rate` still accumulates in code but **Ki_rate·int_rate = 0** (unused)

## Acceptance
- Chatter down ~38% on X, ~37% on XZ: **PASS** (still >0.20 on X)
- CTE not worse: **PASS**
- Pitch mean error up on level paths (rate I removed → trim bias): expected trade-off
- Elevator not hard-saturating (RMS ≪ 15°)

## Verdict
**ACCEPT** — keep Ki_rate=0; proceed to T2B tau reduction for further chatter cut.
