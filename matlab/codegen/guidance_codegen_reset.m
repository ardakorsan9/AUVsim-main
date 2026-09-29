function state = guidance_codegen_reset()
%GUIDANCE_CODEGEN_RESET Deterministic cold State (no persistent memory).
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated explicit-state prototype.
% Mirrors legacy persistent cold/empty semantics (logical have-flags; finite zeros).
%
% TASK_ID: CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001

    state = struct();
    state.initialized = false;
    state.s_prog = 0;
    state.yaw_cont = 0;
    state.pitch_f = 0;
    state.z_e_f = 0;
    state.z_e_i = 0;
    state.zd_e_f = 0;
    state.eg_f = 0;
    state.alpha_hat = 0;
    state.kappa_f = 0;
    state.chi_f = 0;
    state.yaw_out = 0;   % have_yaw_out=false <=> legacy isempty(yaw_out)
    state.pitch_out = 0;
    state.have_yaw_cont = false;
    state.have_pitch_f = false;
    state.have_chi_f = false;
    state.have_yaw_out = false;
end
