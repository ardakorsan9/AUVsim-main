function state = rudder_fdir_codegen_reset(params)
%RUDDER_FDIR_CODEGEN_RESET Deterministic cold State (no persistent memory).
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated explicit-state runtime.
% params retained in signature for fixed ABI; cold reset clears latch.
%
% TASK_ID: RUDDER_FDIR_RUNTIME_001

    state = struct();
    state.initialized = true;
    state.persist_count = 0.0;
    state.anomaly_latched = false;
    state.alarm_time_s = 0.0;
    state.alarm_time_valid = false;
    state.last_seq = uint32(0);
    state.have_seq = false;
end
