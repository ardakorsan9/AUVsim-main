function state = nav_codegen_reset(params) %#ok<INUSD>
%NAV_CODEGEN_RESET Deterministic finite cold State (no persistent memory).
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Isolated explicit-state runtime. params retained for fixed ABI.
%
% TASK_ID: NAV_RUNTIME_001

    q0 = zeros(4, 1);
    q0(1) = 1.0;

    seq0 = uint32(zeros(7, 1));

    state = struct();
    state.initialized = false;
    state.p = zeros(3, 1);
    state.v = zeros(3, 1);
    state.q = q0;
    state.bg = zeros(3, 1);
    state.ba = zeros(3, 1);
    state.c = zeros(3, 1);
    state.P = zeros(18, 18);
    state.last_seq = seq0;
    state.have_seq = false(7, 1);
    state.last_ts = zeros(7, 1);
    state.have_ts = false(7, 1);
    state.last_accept_t = zeros(7, 1);
    state.have_accept_t = false(7, 1);
    state.est_seq = uint32(0);
end
