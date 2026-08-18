function params = controller_codegen_init(params_in)
%CONTROLLER_CODEGEN_INIT Build fixed Params from golden snapshot fields.
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated explicit-state prototype.
% Params are taken only from the golden snapshot (no isempty defaults).
%
% TASK_ID: CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001

    params = struct();
    params.Kp_psi = params_in.Kp_psi;
    params.Kd_psi = params_in.Kd_psi;
    params.Kp_x = params_in.Kp_x;
    params.Kp_roll = params_in.Kp_roll;
    params.Kp_angle = params_in.Kp_angle;
    params.Ki_angle = params_in.Ki_angle;
    params.Kp_rate = params_in.Kp_rate;
    params.Ki_rate = params_in.Ki_rate;
    params.Kaw_pitch = params_in.Kaw_pitch;
    params.Kd_rate = params_in.Kd_rate;
    params.Kd_damp = params_in.Kd_damp;
    params.delta_r_max = params_in.delta_r_max;
    params.delta_e_max = params_in.delta_e_max;
    params.thrust_max = params_in.thrust_max;
    params.thrust_min = params_in.thrust_min;
    params.thrust_trim = params_in.thrust_trim;
    params.trim_speed_table = params_in.trim_speed_table(:).';
    params.trim_elevator_table = params_in.trim_elevator_table(:).';
    params.elevator_sign = params_in.elevator_sign;
    params.dt_controller = params_in.dt_controller;
    params.tau_rate = params_in.tau_rate;
    params.Muw = params_in.Muw;
    params.Muuds = params_in.Muuds;
    params.lambda_muw_ff = params_in.lambda_muw_ff;
    params.muw_ff_u_min = params_in.muw_ff_u_min;
    params.muw_ff_u_lo = params_in.muw_ff_u_lo;
    params.muw_ff_u_hi = params_in.muw_ff_u_hi;
    params.muw_ff_clamp_deg = params_in.muw_ff_clamp_deg;
    params.delta_e_trim = params_in.delta_e_trim;
    params.k_gamma_climb = params_in.k_gamma_climb;
    params.de_climb_lim = params_in.de_climb_lim;
    params.slew_max_rad_s = params_in.slew_max_rad_s;
end
