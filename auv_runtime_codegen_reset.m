function state = auv_runtime_codegen_reset(params)
%AUV_RUNTIME_CODEGEN_RESET Deterministic finite supervisor/component State.
% PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Nested states from approved reset entry points. FAULT_LATCHED clears here only.
%
% TASK_ID: SUPERVISOR_INIT_RESET_001

    state = struct();
    state.controller = controller_codegen_reset(params.controller);
    state.guidance = guidance_codegen_reset();
    state.navigation = nav_codegen_reset(params.navigation);
    state.availability = availability_codegen_reset(params.availability);
    state.fdir = rudder_fdir_codegen_reset(params.fdir);
    state.tick_count = uint32(0);
    state.have_tick = false;
    state.last_tick_seq = uint32(0);
    state.last_t = 0.0;
    state.progress_index = 1.0;
    state.yaw = 0.0;
    state.pitch = 0.0;
    state.u = 0.0;
    state.r_ff = 0.0;
    state.pitch_dot = 0.0;
    state.guidance_ready = false;
    state.arm_state = uint8(0);
    state.healthy_streak = uint32(0);
    state.fault_bits_latched = uint32(0);
end
