function state = controller_codegen_reset(params) %#ok<INUSD>
%CONTROLLER_CODEGEN_RESET Deterministic cold zero State (no persistent memory).
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated explicit-state prototype.
% params retained in signature for fixed ABI; cold reset is gain-independent.
%
% TASK_ID: CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001

    state = struct();
    state.prev_delta_r = 0;
    state.prev_delta_e = 0;
    state.int_angle = 0;
    state.int_rate = 0;
    state.rate_filt = 0;
    state.prev_e_rate = 0;
    state.initialized = 1;
end
