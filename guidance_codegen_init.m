function cfg = guidance_codegen_init(params)
%GUIDANCE_CODEGEN_INIT Build fixed cfg from golden params_snapshot fields.
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated explicit-state prototype.
% Params are taken only from the golden snapshot (no isempty defaults).
%
% TASK_ID: CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001

    cfg = struct();
    cfg.MAX_PATH_POINTS = params.MAX_PATH_POINTS;
    cfg.lookahead_distance = params.lookahead_distance;
    cfg.desired_speed = params.desired_speed;
    cfg.pitch_ref_max = params.pitch_ref_max;
    cfg.pitch_ref_rate_max = params.pitch_ref_rate_max;
    cfg.dt_guidance = params.dt_guidance;
    cfg.dt_controller = params.dt_controller;
    cfg.K_zdot = params.K_zdot;
    cfg.K_gamma = params.K_gamma;
    cfg.enable_alpha_hat = params.enable_alpha_hat;
    cfg.k_beta = params.k_beta;
    cfg.closed_eps = params.closed_eps;
    cfg.near_end_margin = params.near_end_margin;
    cfg.mono_back_max = params.mono_back_max;
    cfg.s_back_tol = params.s_back_tol;
    cfg.yaw_slew_max_rad_s = params.yaw_slew_max_rad_s;
    cfg.r_ff_max_rad_s = params.r_ff_max_rad_s;
    cfg.pitch_corr_max = params.pitch_corr_max;
    cfg.z_e_i_max = params.z_e_i_max;
    cfg.alpha_hat_max = params.alpha_hat_max;
end
