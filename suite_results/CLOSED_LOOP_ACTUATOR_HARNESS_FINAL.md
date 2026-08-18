# CLOSED_LOOP_ACTUATOR_HARNESS_FINAL

**TASK_ID:** CLOSED_LOOP_ACTUATOR_HARNESS_FINAL_001  
**Gate:** Gate 3 final attempt 3/3  
**Verdict:** **FAIL**  
**Gate 3 disposition:** **CLOSED_AFTER_3_ATTEMPTS**  
**Physical readiness:** **NOT_CERTIFIED** — all actuator values are **ASSUMED**.  
**Controller/guidance/plant edits or tuning:** NONE · **CODEX_VERTICAL_PLAN:** untouched

## Causal blocker

```
Error using assert
Required vector not found: initial_state, state0, x0, initialState

Error in run_closed_loop_actuator_realism_harness_final_attempt3>need_vector_any (line 451)
assert(ok && (isnumeric(v)||islogical(v)) && isvector(v),'Required vector not found: %s',strjoin(names,', '));
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error in run_closed_loop_actuator_realism_harness_final_attempt3>need_vector (line 446)
v=need_vector_any(a,b,names); assert(numel(v)==n,'Required vector has wrong length: %s',strjoin(names,', '));
  ^^^^^^^^^^^^^^^^^^^^^^^^^^
Error in run_closed_loop_actuator_realism_harness_final_attempt3>accepted_r10 (line 152)
A.state0=need_vector(SH,candidate,{'initial_state','state0','x0','initialState'},12);
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error in run_closed_loop_actuator_realism_harness_final_attempt3>execute_harness (line 30)
A = accepted_r10('suite_results/ROLL_PRODUCTION_CLOSURE.mat', ...
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error in run_closed_loop_actuator_realism_harness_final_attempt3 (line 7)
    Results = execute_harness(task);
              ^^^^^^^^^^^^^^^^^^^^^
```
