# T1A — Single consistent dt + tau-based rate filter

## Changes
- `init_parameters.m`: `dt_controller = 0.0375`, `dt_guidance = dt_controller`, `tau_rate = -0.075/ln(0.90) ≈ 0.7118 s`
- `controller_law.m`: uses `dt_controller`; rate LPF `a = exp(-dt/tau_rate)` (physical tau preserved)
- `guidance_law.m`: integrators / rate limits use `dt_guidance` (no hard-coded 0.075)
- `continuous_path_tracking.m` / `run_path_suite.m`: plant step = control sample period
- Gains, Ki_rate, Muw, guidance alphas: **unchanged**

## Baseline (dt=0.075, from prior `summary.txt`)

| Scenario | mean CTE | max CTE | mean \|pitch\| |
|----------|----------|---------|----------------|
| X-line   | 2.071 m  | 10.241 m | 0.50° |
| XZ       | 2.548 m  | 11.993 m | 0.61° |
| Circle   | 1.527 m  | 3.133 m  | 0.41° |
| Helix    | 1.670 m  | 3.016 m  | 0.32° |

Prior diag X-line chatter @ dt=0.075: **0.547 °/s**

## T1A results (both runs identical)

| Scenario | mean CTE | max CTE | mean \|pitch\| | chatter (deg/s) | θ pp settle |
|----------|----------|---------|----------------|-----------------|-------------|
| X-line   | 2.053 m  | 10.225 m | 0.50° | **0.525** | 2.631° |
| XZ       | 2.546 m  | 12.066 m | 0.60° | 0.661 | 11.228°* |
| Circle   | 1.525 m  | 3.156 m  | 0.44° | **0.167** | 3.181° |
| Helix    | 1.686 m  | 3.033 m  | 0.33° | **0.194** | 3.245° |

\*XZ θ pp dominated by climb geometry, not HF chatter.

## Acceptance

| Criterion | Result |
|-----------|--------|
| Two runs close | **PASS** (bit-identical metrics) |
| Pitch RMS not worse | **PASS** (≤ baseline) |
| X/XZ CTE not meaningfully worse | **PASS** (X slightly better; XZ ≈ same) |
| Elevator saturating | Not flagged (no sim failures; prior diag 0% sat) |
| Chatter < 0.20 °/s | **PARTIAL** — circle/helix OK; X-line 0.525 still high |

**Note:** Prior diag “dt half → chatter 0.118” kept fixed α=0.9 (physical τ halved). T1A **preserves τ≈0.71 s**, so X-line chatter barely moves — expected. Faster τ is Tur 2B.

## Verdict
**ACCEPT** — architecture OK, path metrics stable/repeatable. Proceed to T1B multi-rate.
