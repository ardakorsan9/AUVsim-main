function [state, out, dbg] = controller_codegen_step(params, state, in)
%CONTROLLER_CODEGEN_STEP Explicit-state one-step controller (fixed ABI).
% DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated prototype; not production path.
% Translates accepted controller_law arithmetic/order exactly.
% TEMPORARY_BLOCKER: wrapToPi (yaw wrap) and fixed-table interp1 linear/extrap
% remain for bit parity; ownership replacement is a later gate.
%
% Constraints: no global/persistent/nargin/nargout/isempty defaults/dynamic
% fields/allocation/logging/error/assert. Fixed Params/State/Input/Output/Debug.
%
% TASK_ID: CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001

    dt = params.dt_controller;

    yaw_ref = in.yaw_ref;
    pitch_ref = in.pitch_ref;
    u_ref = in.u_ref;
    psi = in.psi;
    theta = in.theta;
    r = in.r;
    q = in.q;
    u = in.u;
    r_ff = in.r_ff;
    pitch_ref_dot = in.pitch_ref_dot;
    phi = in.phi;
    w = in.w;
    p = in.p;

    prev_delta_r = state.prev_delta_r;
    prev_delta_e = state.prev_delta_e;
    int_angle = state.int_angle;
    int_rate = state.int_rate;
    rate_filt = state.rate_filt;
    prev_e_rate = state.prev_e_rate;

    Kp_psi = params.Kp_psi;
    Kd_psi = params.Kd_psi;
    Kp_x = params.Kp_x;
    Kp_roll = params.Kp_roll;
    Kp_angle = params.Kp_angle;
    Ki_angle = params.Ki_angle;
    Kp_rate = params.Kp_rate;
    Ki_rate = params.Ki_rate;
    Kaw_pitch = params.Kaw_pitch;
    Kd_rate = params.Kd_rate;
    Kd_damp = params.Kd_damp;
    delta_r_max = params.delta_r_max;
    delta_e_max = params.delta_e_max;
    thrust_max = params.thrust_max;
    thrust_min = params.thrust_min;
    thrust_trim = params.thrust_trim;
    elevator_sign = params.elevator_sign;
    tau_rate = params.tau_rate;
    Muw = params.Muw;
    Muuds = params.Muuds;
    lambda_muw_ff = params.lambda_muw_ff;
    muw_ff_u_min = params.muw_ff_u_min;
    muw_ff_u_lo = params.muw_ff_u_lo;
    muw_ff_u_hi = params.muw_ff_u_hi;
    muw_ff_clamp_deg = params.muw_ff_clamp_deg;
    k_gamma_climb = params.k_gamma_climb;
    de_climb_lim = params.de_climb_lim;

    % ----- Yaw + roll-rate damp (sum BEFORE mag/rate limit; Kphi=0) -----
    % TEMPORARY_BLOCKER: wrapToPi retained for golden bit parity.
    e_psi = wrapToPi(yaw_ref - psi);
    e_r = r - r_ff;
    dr_yaw = Kp_psi * e_psi - Kd_psi * e_r;
    e_psi0 = deg2rad(3);
    e_r0 = deg2rad(8);
    g_ac = 1 / (1 + (e_psi / max(e_psi0, eps))^2 + (e_r / max(e_r0, eps))^2);
    dr_p = -Kp_roll * p;
    dr_damp = g_ac * dr_p;
    delta_r_cmd = dr_yaw + dr_damp;
    delta_r_cmd = max(min(delta_r_cmd, delta_r_max), -delta_r_max);

    % ----- Physical pitch kinematics -----
    theta_phys = -theta;
    theta_phys_dot = -q * cos(phi) + r * sin(phi);
    a_rate = exp(-dt / tau_rate);
    rate_filt = a_rate * rate_filt + (1 - a_rate) * theta_phys_dot;

    e_theta = pitch_ref - theta_phys;

    % Outer loop: angle -> rate command
    int_angle = int_angle + e_theta * dt;
    int_angle_max = deg2rad(8) / max(Ki_angle, 1e-6);
    int_angle = max(min(int_angle, int_angle_max), -int_angle_max);

    theta_rate_cmd = 0.8 * pitch_ref_dot + Kp_angle * e_theta + Ki_angle * int_angle;
    theta_rate_cmd = max(min(theta_rate_cmd, deg2rad(14)), deg2rad(-14));

    % Inner loop: rate -> elevator (+ damping on measured rate)
    e_rate = theta_rate_cmd - rate_filt;
    de_rate = 0;
    if Kd_rate > 0
        de_rate = (e_rate - prev_e_rate) / dt;
        de_rate = max(min(de_rate, deg2rad(25)), deg2rad(-25));
    end
    prev_e_rate = e_rate;
    int_rate = int_rate + e_rate * dt;

    % TEMPORARY_BLOCKER: fixed-table interp1 linear/extrap retained for parity.
    de_trim = interp1(params.trim_speed_table, params.trim_elevator_table, abs(u), 'linear', 'extrap');

    delta_e_I_max = deg2rad(5);
    int_rate_max = delta_e_I_max / max(Ki_rate, 1e-6);
    int_rate = max(min(int_rate, int_rate_max), -int_rate_max);

    u_el = Kp_rate * e_rate + Ki_rate * int_rate + Kd_rate * de_rate - Kd_damp * rate_filt;
    de_fb = elevator_sign * u_el;

    % Climb equilibrium FF (scheduled on physical pitch_ref; not I memory)
    gamma_ref = pitch_ref;
    de_climb_ff = max(min(k_gamma_climb * gamma_ref, de_climb_lim), -de_climb_lim);

    % Tur 3: graduated Muw feedforward (additive; λ=0 => identically zero)
    u_abs = abs(u);
    b_u = max(0, min(1, (u_abs - muw_ff_u_lo) / max(muw_ff_u_hi - muw_ff_u_lo, 1e-6)));
    u_eff2 = max(u * u, muw_ff_u_min * muw_ff_u_min);
    G_de = Muuds * u_eff2;
    M_uw = Muw * u * w;
    if abs(G_de) < 1e-9 || lambda_muw_ff == 0
        de_uw_ff_raw = 0;
    else
        de_uw_ff_raw = -lambda_muw_ff * M_uw / G_de;
    end
    de_ff_lim = deg2rad(muw_ff_clamp_deg);
    de_uw_ff = b_u * max(min(de_uw_ff_raw, de_ff_lim), -de_ff_lim);
    M_e_ff = G_de * de_uw_ff;
    M_elev = G_de * (de_trim + de_uw_ff + de_climb_ff + de_fb);

    delta_e_unsat = de_trim + de_uw_ff + de_climb_ff + de_fb;
    delta_e_cmd = max(min(delta_e_unsat, delta_e_max), -delta_e_max);

    delta_e_angle_I = elevator_sign * Kp_rate * Ki_angle * int_angle;

    % Back-calculation anti-windup on rate integrator
    Kaw = Kaw_pitch;
    aw_err = delta_e_cmd - delta_e_unsat;
    int_rate = int_rate + Kaw * aw_err * dt;
    int_rate = max(min(int_rate, int_rate_max), -int_rate_max);

    % Soft freeze outer I if persistently saturated against error
    if abs(aw_err) > 1e-4 && sign(e_theta) == sign(elevator_sign * aw_err)
        int_angle = int_angle - 0.5 * e_theta * dt;
    end

    max_dr = deg2rad(40) * dt;
    max_de = deg2rad(40) * dt;
    delta_r = prev_delta_r + max(min(delta_r_cmd - prev_delta_r, max_dr), -max_dr);
    delta_e = prev_delta_e + max(min(delta_e_cmd - prev_delta_e, max_de), -max_de);
    prev_delta_r = delta_r;
    prev_delta_e = delta_e;

    thrust = thrust_trim + Kp_x * (u_ref - u);
    thrust = max(min(thrust, thrust_max), thrust_min);

    % ----- write-back State (fixed fields) -----
    state.prev_delta_r = prev_delta_r;
    state.prev_delta_e = prev_delta_e;
    state.int_angle = int_angle;
    state.int_rate = int_rate;
    state.rate_filt = rate_filt;
    state.prev_e_rate = prev_e_rate;
    state.initialized = 1;

    % ----- Output (fixed fields) -----
    out = struct();
    out.delta_r = delta_r;
    out.delta_e = delta_e;
    out.thrust = thrust;

    % ----- Debug (fixed fields; always emitted) -----
    dbg = struct();
    dbg.e_theta = e_theta;
    dbg.theta_phys = theta_phys;
    dbg.theta_phys_dot = theta_phys_dot;
    dbg.int_angle = int_angle;
    dbg.int_angle_max = int_angle_max;
    dbg.int_rate = int_rate;
    dbg.de_trim = de_trim;
    dbg.de_uw_ff = de_uw_ff;
    dbg.de_fb = de_fb;
    dbg.delta_e_angle_I = delta_e_angle_I;
    dbg.delta_e_cmd = delta_e_cmd;
    dbg.delta_e_unsat = delta_e_unsat;
    dbg.M_uw = M_uw;
    dbg.M_elev = M_elev;
    dbg.M_e_ff = M_e_ff;
    dbg.G_de = G_de;
    dbg.b_u = b_u;
    dbg.rate_filt = rate_filt;
    dbg.theta_rate_cmd = theta_rate_cmd;
    dbg.mag_sat = double(abs(delta_e_unsat) > delta_e_max + 1e-9);
    dbg.p = p;
    dbg.e_psi = e_psi;
    dbg.e_r = e_r;
    dbg.dr_yaw = dr_yaw;
    dbg.dr_p = dr_p;
    dbg.dr_damp = dr_damp;
    dbg.g_ac = g_ac;
    dbg.delta_r_cmd = delta_r_cmd;
    dbg.delta_r = delta_r;
    dbg.Kp_roll = Kp_roll;
end
