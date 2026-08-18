# CLOSED_LOOP_ACTUATOR_HARNESS_FIX

**TASK_ID:** CLOSED_LOOP_ACTUATOR_HARNESS_FIX_001  
**Gate:** Gate 3 attempt 2  
**Verdict:** **FAIL**  
**Physical readiness:** **NOT_CERTIFIED** — all actuator values are **ASSUMED**.  
**Controller/guidance/plant edits or tuning:** NONE · **CODEX_VERTICAL_PLAN:** untouched

## Causal blocker

```
Error using assert
Required field not found: candidate

Error in run_closed_loop_actuator_realism_harness_fix>need_named (line 399)
[ok,v]=find_named(s,names,0); assert(ok,'Required field not found: %s',strjoin(names,', '));
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error in run_closed_loop_actuator_realism_harness_fix>accepted_r10 (line 129)
candidate=need_named(root,{'candidate'});
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error in run_closed_loop_actuator_realism_harness_fix>execute_harness (line 27)
A = accepted_r10('suite_results/ROLL_PRODUCTION_CLOSURE.mat');
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error in run_closed_loop_actuator_realism_harness_fix (line 7)
    Results = execute_harness(task);
              ^^^^^^^^^^^^^^^^^^^^^
```
