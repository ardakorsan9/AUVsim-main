# GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE

**TASK_ID** `GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE_001`  
**Verdict** `REJECT_C1_METHOD_CLOSED`  
**Created** 2026-08-09 12:05:11  
**Certification** NOT_CERTIFIED (simulation-only log replay; no HIL, no bench, no hardware). Gate 9 locked.

## 1. Scope

C1 is evaluated as a **logged shadow reference only**. The candidate is the production
yaw-reference arithmetic with a single symbol changed, `k_beta` 1.35 -> 1.00:

```
chi_raw_C1 = wrap(chi_f + 0.75*chi_los - 1.00*beta)
```

and is then pushed through the identical unwrap, 0.35 blend, +-40 deg/s slew clip and
3:1 zero-order hold. Production guidance, controller and plant were never called and
never edited. The replay is open loop against the recorded R10_U1.5 signal log, so
**no closed-loop or tracking claim is made**.

Sources read (exactly three):
1. `guidance_law.m` `n=14601.s1=1095745.s2=3464382495`
2. `controller_law.m` `n=9402.s1=732890.s2=3334742186`
3. `suite_results/GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE.mat` `n=305645.s1=39747278.s2=960859068`

## 2. Provenance and preconditions

| item | value |
|---|---|
| source record | `GATE8_R10_GUIDANCE_SIGNAL_LOG_CLOSURE_001` (verdict `CLOSED`) |
| cell | `R10_U1.5`, U = 1.50 m/s, 26 waypoints |
| state0 | `[0 0 5 0 0 0.15708 1.5 0 0 0 0 0]` |
| cadence | dt_ctrl 0.0250 s, dt_guidance 0.075000 s, 3:1 hold, T = 30 s |
| ticks | 1200 controller, 400 guidance, 240 sustained-window |
| lookahead | L = 1.25 m |
| slew bound | deg2rad(40)*dt_g = 0.052360 rad = 3.000000 deg/tick |
| production fingerprint | frozen hash held pre **and** post (all 6 files) |
| observer closure | closure 1, geometry 1, continuity 1, parity 1, trajectory hash frozen 1 |

Production file fingerprints (pre = post = frozen):

| file | fingerprint | pre | post |
|---|---|---|---|
| `guidance_law.m` | `n=14601.s1=1095745.s2=3464382495` | yes | yes |
| `controller_law.m` | `n=9402.s1=732890.s2=3334742186` | yes | yes |
| `continuous_path_tracking.m` | `n=10845.s1=886194.s2=515073390` | yes | yes |
| `init_parameters.m` | `n=4205.s1=309116.s2=664235741` | yes | yes |
| `underwater777_vehicle_dynamics.m` | `n=6065.s1=426918.s2=1254438441` | yes | yes |
| `suite_results\CODEX_VERTICAL_PLAN.md` | `n=43101.s1=4310210.s2=3268810005` | yes | yes |

## 3. Production reference reconstructed exactly

The production pipeline was rebuilt from the logged `chi_f`, `chi_los` and `beta` and
checked against every recorded stage before C1 was evaluated.

| stage | max abs residual [rad] |
|---|---|
| `yaw_raw` | 1.110e-15 |
| `yaw_cont` (unwrap) | 1.332e-15 |
| `yaw_out` (0.35 blend + slew) | 8.882e-16 |
| `yaw_ref` | 8.882e-16 |
| held reference (3:1) | 8.882e-16 |
| `dy_des` / `dy_app` | 4.684e-16 / 4.684e-16 |
| `e_psi` | 9.159e-16 |

Worst residual **1.332e-15 rad**, gate 1e-9: **PASS**. The shadow arithmetic is therefore the
production arithmetic with one coefficient changed and nothing else.

## 4. Production vs C1

Sustained window = the recorded analysis window, 240 guidance ticks.

| quantity | production | C1 | change |
|---|---|---|---|
| yaw reference, window mean delta [deg] | - | - | -0.278590 |
| yaw reference, peak delta [deg] | - | - | 0.801563 |
| mean\|e_psi\| window [deg] | 5.625664 | 5.604251 | +0.3806% |
| rms e_psi window [deg] | 6.647897 | 6.608190 | +0.5973% |
| peak\|e_psi\| window [deg] | 13.428359 | 13.587194 | -1.1828% |
| mean\|P demand\| Kp=32 window [rad] | 3.141964 | 3.130004 | +0.3806% |
| rms P demand window [rad] | 3.712886 | 3.690709 | +0.5973% |
| mean\|e_psi\| full record [deg] | 5.266891 | 5.250366 | +0.3138% |
| mean\|P demand\| full record [rad] | 2.941587 | 2.932357 | +0.3138% |

Positive change = magnitude reduced by C1. The P demand is the **algebraic**
`Kp*e_psi` pre-saturation demand, not a commanded rudder angle.

## 5. Structural over-crab removal

The over-crab term is `-(k_beta-1)*beta`, the part of the reference offset that exists
only because the law crabs harder than the exact course kinematics `chi = psi + beta`
require. Production window mean 0.276416 deg (recorded value 0.276416 deg, reproduced to 0.00e+00),
mean magnitude 0.335019 deg, peak 0.845820 deg. Under C1 the term is **identically zero**:
100.0% removal, exactly, by construction rather than by tuning.

### Zero-curvature reduction

With `kappa = 0` the lead law returns identically zero (recorded `zero_kappa_lead_max`
= 0.0e+00) and `chi_los -> 0`, so the pipeline reduces to a pure constant-course problem.
Iterating the same unwrap/blend/slew recursion to steady state at the window-mean
sideslip -0.789759 deg gives:

| k_beta | steady offset from path course [deg] | closed form `-k_beta*beta` | residual |
|---|---|---|---|
| 1.35 (production) | 1.066175 | 1.066175 | 2.44e-15 |
| 1.00 (C1) | 0.789759 | 0.789759 | 6.66e-16 |

a 25.926% reduction of the zero-curvature reference offset. The residual 0.789759 deg under
C1 is the exact `-1.0*beta` crab the course kinematics demand, so it is correct, not error.

## 6. Wrap, slew and continuity

| quantity | production | C1 | bound |
|---|---|---|---|
| wrap events | 1 | 1 | must match |
| wrap identity residual [rad] | 4.44e-16 | 4.44e-16 | <= 1e-9 |
| slew clips engaged | 0 | 0 | 0 |
| max \|dy_des\| [deg/tick] | 2.635342 | 2.633014 | 3.000000 |
| max \|d yaw_out\| [deg/tick] | 2.635342 | 2.633014 | 3.000000 |
| max \|d yaw_cont\| [deg/tick] | 5.207016 | 5.202326 | - |
| total unwrapped turn [rad] | 4.774625 | 4.776775 | - |
| finite | 1 | 1 | 1 |

No 3 deg/tick slew or wrap violation in either pipeline.

## 7. Course-offset attribution identity

Datum: chi_og - chi_now (course over ground minus path course at s_prog). Window means in deg.

| term | production | C1 |
|---|---|---|
| lead/lag (course filter + LOS + output filter) | +3.579577 | +3.577403 |
| heading error `-e_psi` | -3.835154 | -3.556564 |
| structural over-crab | +0.276416 | +0.000000 |
| sideslip-model residual | +0.041743 | +0.041743 |
| **sum** | **+0.062582** | **+0.062582** |
| measured `chi_og - chi_now` | +0.062582 | +0.062582 |
| identity residual | 1.14e-15 | 1.14e-15 |

**This is the load-bearing caveat.** the achieved course chi_og is a recorded plant output, so under open-loop shadow replay the total course offset is invariant by construction; C1 removes the crab term and the identity transfers it into the heading-error term.
Removing the over-crab term therefore does not remove course offset in this replay; it
relabels 100% of it, and the algebraic heading-error demand barely moves. Whether the
removal buys anything can only be answered in closed loop, which this probe does not do.

## 8. Gate ledger

Thresholds were declared before any metric was computed: both primary legs must improve
by >= 5%, no secondary logged metric may worsen by more than 2%, and no 3 deg/tick
slew or wrap violation is allowed.

| gate | production | C1 | change | required | result |
|---|---|---|---|---|---|
| PRIMARY-1 sustained mean abs over-crab contribution [deg] | 0.335019 | 0.000000 | +100.0000% | >= +5% | **PASS** |
| PRIMARY-2 sustained mean abs implied P demand Kp=32 [rad] | 3.141964 | 3.130004 | +0.3806% | >= +5% | **FAIL** |
| SECONDARY sustained mean abs e_psi [deg] | 5.625664 | 5.604251 | +0.3806% | >= -2% | PASS |
| SECONDARY sustained rms e_psi [deg] | 6.647897 | 6.608190 | +0.5973% | >= -2% | PASS |
| SECONDARY sustained peak abs e_psi [deg] | 13.428359 | 13.587194 | -1.1828% | >= -2% | PASS |
| SECONDARY sustained rms P demand [rad] | 3.712886 | 3.690709 | +0.5973% | >= -2% | PASS |
| SECONDARY sustained peak abs P demand [rad] | 7.499810 | 7.588521 | -1.1828% | >= -2% | PASS |
| SECONDARY full mean abs e_psi [deg] | 5.266891 | 5.250366 | +0.3138% | >= -2% | PASS |
| SECONDARY full rms e_psi [deg] | 6.337674 | 6.322996 | +0.2316% | >= -2% | PASS |
| SECONDARY full peak abs e_psi [deg] | 13.579300 | 13.776792 | -1.4544% | >= -2% | PASS |
| SECONDARY full mean abs P demand [rad] | 2.941587 | 2.932357 | +0.3138% | >= -2% | PASS |
| SECONDARY full rms P demand [rad] | 3.539625 | 3.531427 | +0.2316% | >= -2% | PASS |
| SECONDARY full mean abs over-crab [deg] | 0.318725 | 0.000000 | +100.0000% | >= -2% | PASS |
| SECONDARY max abs d yaw_out [deg/tick] | 2.635342 | 2.633014 | +0.0883% | >= -2% | PASS |
| SECONDARY max abs dy_des [deg/tick] | 2.635342 | 2.633014 | +0.0883% | >= -2% | PASS |
| SECONDARY max abs d yaw_cont [deg/tick] | 5.207016 | 5.202326 | +0.0901% | >= -2% | PASS |
| SECONDARY abs yaw_cont total turn [rad] | 4.774625 | 4.776775 | -0.0450% | >= -2% | PASS |
| STRUCTURAL slew / wrap / finite / identity | - | - | - | all | PASS |
| Production reconstruction <= 1e-9 rad | - | - | 1.33e-15 | <= 1e-9 | PASS |
| Observer closure held before comparison | - | - | - | required | PASS |
| Production fingerprint frozen pre and post | - | - | - | required | PASS |

## 9. Verdict

**REJECT C1. Method closed at the shadow stage.**

The primary KPI is conjunctive and C1 fails one leg of it. The structural over-crab
contribution is removed completely (0.335019 -> 0.000000 deg, 100%), but the implied
P demand improves only +0.3806% over the sustained window (+0.3138% over the full
record) against a declared floor of 5%, roughly one thirteenth of what was required.

The reason is structural, not marginal. The over-crab term is worth 0.3350 deg of
reference offset while the heading error it would have to move is 5.6257 deg, so even
perfect removal of the term can only shift the P demand by a few tenths of a per cent.
No amount of re-running this probe changes that ratio, and the attribution identity in
section 7 shows the offset is transferred rather than eliminated. No follow-on
closed-loop shadow validation is named, because the gate that would have earned one
did not pass.

Secondary metrics stayed inside the 2% band (worst -1.4544% on peak heading error),
and there was no slew or wrap violation, so the rejection is on effect size alone,
not on a safety or continuity breach.

## 10. Honesty and negative scope

IMPLEMENTED = this isolated shadow probe only. C1 is a LOGGED SHADOW REFERENCE. Production guidance, controller and plant were never called and never edited; their fingerprints are the frozen hashes pre and post. CODEX_VERTICAL_PLAN untouched. The replay is open loop: the recorded psi, beta and course are production outputs, so NO closed-loop or tracking claim is made and no promotion is implied. Simulation is never hardware certification.

- no closed-loop claim
- no tracking claim
- no production edit
- no gain / path / threshold change
- no external shaper
- no current feedforward
- no promotion
- hardware NOT_CERTIFIED
- Gate 9 locked

Artefacts: `suite_results\GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE.png`, `suite_results\GATE8_R10_SHADOW_COURSE_REFERENCE_OFFSET_PROBE_qa.png`.
