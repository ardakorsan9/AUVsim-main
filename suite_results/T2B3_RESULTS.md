# T2B-3 — rate filter tau = 0.05 s (tens-of-ms)

## X-line sweep

| Stage | tau (s) | chatter | de jitter | corr | lag | CTE |
|-------|--------:|--------:|----------:|-----:|----:|----:|
| T2A   | 0.712 | 0.312 | — | — | — | 2.014 |
| T2B-1 | 0.356 | 0.109 | 0.469 | 0.894 | 0.075 | 2.017 |
| T2B-2 | 0.178 | 0.108 | 0.401 | 0.984 | 0.000 | 2.018 |
| T2B-3 | **0.050** | 0.113 | **0.352** | **0.999** | 0.000 | 2.020 |

Two T2B-3 runs identical. No elevator jitter explosion. Chatter floor ~0.11 °/s after T2B-1.

## Verdict
**KEEP tau_rate = 0.05 s** as final Tur-2 filter setting (best tracking lag/corr; chatter already < 0.20).
