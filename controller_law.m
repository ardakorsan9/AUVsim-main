function [delta_r, delta_e, thrust, dbg] = controller_law(yaw_ref, pitch_ref, u_ref, psi, theta, r, q, u, r_ff, pitch_ref_dot, phi, w)
% Cascaded pitch: angle outer loop -> rate inner loop -> elevator
% Physical pitch: theta_phys = -theta
% Physical pitch rate: theta_phys_dot = -q*cos(phi) + r*sin(phi)
% Optional 4th output `dbg` (Tur 2.5): angle-I / trim components; production
% callers using 3 outputs are unchanged.
% Optional 12th input `w`: heave for Muw feedforward (Tur 3). λ=0 => FF off.

    global Kp_psi Kd_psi Kp_x
    global Kp_angle Ki_angle Kp_rate Ki_rate Kaw_pitch Kd_rate Kd_damp
    global delta_r_max delta_e_max thrust_max thrust_min
    global thrust_trim
    global trim_speed_table trim_elevator_table
    global elevator_sign   % +1 or -1 from open-loop test
    global dt_controller tau_rate
    global Muw Muuds
    global lambda_muw_ff muw_ff_u_min muw_ff_u_lo muw_ff_u_hi muw_ff_clamp_deg

    persistent prev_delta_e prev_delta_r
    persistent int_angle int_rate
    persistent rate_filt prev_e_rate
    global last_int_angle last_int_rate last_delta_e  % diagnostics (T2)
    global last_rate_filt last_theta_phys_dot
    global last_de_trim last_delta_e_angle_I last_e_theta last_theta_phys
    global last_de_uw_ff last_de_fb last_M_uw last_M_elev last_M_e_ff last_G_de last_M_total_pitch

    if isempty(prev_delta_e); prev_delta_e = 0; end
    if isempty(prev_delta_r); prev_delta_r = 0; end
    if isempty(int_angle); int_angle = 0; end
    if isempty(int_rate); int_rate = 0; end
    if isempty(rate_filt); rate_filt = 0; end
    if isempty(prev_e_rate); prev_e_rate = 0; end
    if isempty(Kd_rate); Kd_rate = 0; end
    if isempty(Kd_damp); Kd_damp = 0.55; end

    if nargin < 9 || isempty(r_ff); r_ff = 0; end
    if nargin < 10 || isempty(pitch_ref_dot); pitch_ref_dot = 0; end
    if nargin < 11 || isempty(phi); phi = 0; end
    if nargin < 12 || isempty(w); w = 0; end
    if isempty(elevator_sign); elevator_sign = 1; end
    if isempty(lambda_muw_ff); lambda_muw_ff = 0; end
    if isempty(muw_ff_u_min); muw_ff_u_min = 0.50; end
    if isempty(muw_ff_u_lo); muw_ff_u_lo = 0.70; end
    if isempty(muw_ff_u_hi); muw_ff_u_hi = 1.20; end
    if isempty(muw_ff_clamp_deg); muw_ff_clamp_deg = 4.0; end
    if isempty(Muw); Muw = 24; end
    if isempty(Muuds); Muuds = -6.15; end

    if isempty(dt_controller); dt_controller = 0.0375; end
    if isempty(tau_rate); tau_rate = -0.075 / log(0.90); end
    dt = dt_controller;

    % ----- Yaw (unchanged structure) -----
    e_psi = wrapToPi(yaw_ref - psi);
    e_r = r - r_ff;
    delta_r_cmd = Kp_psi * e_psi - Kd_psi * e_r;
    delta_r_cmd = max(min(delta_r_cmd, delta_r_max), -delta_r_max);

    % ----- Physical pitch kinematics -----
    theta_phys = -theta;
    theta_phys_dot = -q * cos(phi) + r * sin(phi);
    % First-order LPF with fixed physical tau: a = exp(-dt/tau)
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

    de_trim = lookup_elevator_trim(abs(u));

    delta_e_I_max = deg2rad(5);
    int_rate_max = delta_e_I_max / max(Ki_rate, 1e-6);
    int_rate = max(min(int_rate, int_rate_max), -int_rate_max);

    % Kd_damp * rate_filt resists pitch rate (stabilizes phugoid/porpoise)
    u_el = Kp_rate * e_rate + Ki_rate * int_rate + Kd_rate * de_rate - Kd_damp * rate_filt;
    de_fb = elevator_sign * u_el;

    % Tur 3: graduated Muw feedforward (additive; λ=0 => identically zero)
    u_abs = abs(u);
    b_u = max(0, min(1, (u_abs - muw_ff_u_lo) / max(muw_ff_u_hi - muw_ff_u_lo, 1e-6)));
    u_eff2 = max(u * u, muw_ff_u_min * muw_ff_u_min);
    G_de = Muuds * u_eff2;                 % [N·m/rad] = ∂M/∂δe
    M_uw = Muw * u * w;                    % [N·m]
    if abs(G_de) < 1e-9 || lambda_muw_ff == 0
        de_uw_ff_raw = 0;
    else
        de_uw_ff_raw = -lambda_muw_ff * M_uw / G_de;
    end
    de_ff_lim = deg2rad(muw_ff_clamp_deg);
    de_uw_ff = b_u * max(min(de_uw_ff_raw, de_ff_lim), -de_ff_lim);
    M_e_ff = G_de * de_uw_ff;              % elevator moment from FF only
    M_elev = G_de * (de_trim + de_uw_ff + de_fb);  % approx total elevator moment cmd

    delta_e_unsat = de_trim + de_uw_ff + de_fb;
    delta_e_cmd = max(min(delta_e_unsat, delta_e_max), -delta_e_max);

    % Steady-state angle-I elevator contribution (rate~0): sign*Kp_rate*Ki*int
    delta_e_angle_I = elevator_sign * Kp_rate * Ki_angle * int_angle;

    % Back-calculation anti-windup on rate integrator
    Kaw = Kaw_pitch;
    aw_err = delta_e_cmd - delta_e_unsat;
    int_rate = int_rate + Kaw * aw_err * dt;
    int_rate = max(min(int_rate, int_rate_max), -int_rate_max);

    % Soft freeze outer I if persistently saturated against error
    if abs(aw_err) > 1e-4 && sign(e_theta) == sign(elevator_sign * aw_err)
        int_angle = int_angle - 0.5 * e_theta * dt; % bleed
    end

    max_dr = deg2rad(40) * dt;
    max_de = deg2rad(40) * dt;
    delta_r = prev_delta_r + max(min(delta_r_cmd - prev_delta_r, max_dr), -max_dr);
    delta_e = prev_delta_e + max(min(delta_e_cmd - prev_delta_e, max_de), -max_de);
    prev_delta_r = delta_r;
    prev_delta_e = delta_e;

    last_int_angle = int_angle;
    last_int_rate = int_rate;
    last_delta_e = delta_e;
    last_rate_filt = rate_filt;
    last_theta_phys_dot = theta_phys_dot;
    last_de_trim = de_trim;
    last_delta_e_angle_I = delta_e_angle_I;
    last_e_theta = e_theta;
    last_theta_phys = theta_phys;
    last_de_uw_ff = de_uw_ff;
    last_de_fb = de_fb;
    last_M_uw = M_uw;
    last_M_elev = M_elev;
    last_M_e_ff = M_e_ff;
    last_G_de = G_de;
    last_M_total_pitch = M_uw + M_elev;

    thrust = thrust_trim + Kp_x * (u_ref - u);
    thrust = max(min(thrust, thrust_max), thrust_min);

    if nargout >= 4
        dbg = struct( ...
            'e_theta', e_theta, ...
            'theta_phys', theta_phys, ...
            'theta_phys_dot', theta_phys_dot, ...
            'int_angle', int_angle, ...
            'int_angle_max', int_angle_max, ...
            'int_rate', int_rate, ...
            'de_trim', de_trim, ...
            'de_uw_ff', de_uw_ff, ...
            'de_fb', de_fb, ...
            'delta_e_angle_I', delta_e_angle_I, ...
            'delta_e_cmd', delta_e_cmd, ...
            'delta_e_unsat', delta_e_unsat, ...
            'M_uw', M_uw, ...
            'M_elev', M_elev, ...
            'M_e_ff', M_e_ff, ...
            'G_de', G_de, ...
            'b_u', b_u, ...
            'rate_filt', rate_filt, ...
            'theta_rate_cmd', theta_rate_cmd, ...
            'mag_sat', double(abs(delta_e_unsat) > delta_e_max + 1e-9));
    end
end

function de = lookup_elevator_trim(u)
    global trim_speed_table trim_elevator_table delta_e_trim
    if isempty(trim_speed_table) || isempty(trim_elevator_table)
        de = delta_e_trim;
        return;
    end
    de = interp1(trim_speed_table, trim_elevator_table, u, 'linear', 'extrap');
end
