function state = availability_codegen_reset(params) %#ok<INUSD>
%AVAILABILITY_CODEGEN_RESET Deterministic finite cold State (no persistent memory).
% DEPLOY_CANDIDATE / HEALTH_STATUS_ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Isolated explicit-state runtime. params retained for fixed ABI.
% State code 0 UNINITIALIZED. All timers/counters/accept times zero.
% All validity flags false.
%
% TASK_ID: AVAILABILITY_RUNTIME_001

    last_accept_t = zeros(7, 1);
    have_accept = false(7, 1);

    state = struct();
    state.code = uint8(0);
    state.deg_timer = 0.0;
    state.loss_timer = 0.0;
    state.posok_timer = 0.0;
    state.allok_timer = 0.0;
    state.last_accept_t = last_accept_t;
    state.have_accept = have_accept;
    state.init_time = 0.0;
    state.last_t = 0.0;
    state.have_init = false;
    state.have_t = false;
    state.trans_count = uint32(0);
    state.trans_from = uint8(0);
    state.trans_to = uint8(0);
end
