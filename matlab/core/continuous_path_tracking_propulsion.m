%[PROP-BEGIN]
function [vehicle_path, times, velocities, angular_velocities, orientations, total_time, yaw_refs, pitch_refs, u_refs, PROP] = continuous_path_tracking_propulsion(path, state, dt, T_final, prop)
% CONTINUOUS_PATH_TRACKING_PROPULSION
% PROPULSION_POWER_COMPUTE_PARITY_FIX_001 harness clone of continuous_path_tracking.m.
% The ONLY functional change is a realized-thrust actuator inserted between the
% controller command and the plant input. Every inserted or modified line lives in
% a marked region (BEGIN/END markers); each modified original line is preserved
% verbatim on an ORIG marker line, so the clone can be mechanically reduced back to
% continuous_path_tracking.m (verified by the driver, gate G_clone_minimal_diff).
% prop.ideal == true is an exact bit-identical passthrough (T_real = T_cmd).
% Production continuous_path_tracking.m is NOT modified by this file.
%
% Service call (single shared actuator implementation, used by the driver's
% cloned helix loop):
%   [T_real, act_state] = continuous_path_tracking_propulsion('actuator', ...
%                             act_state_prev, T_cmd, dt_step, prop)
%   positional mapping: path='actuator', state=act_state_prev, dt=T_cmd,
%                       T_final=dt_step, prop=prop
%[PROP-ORIG] function [vehicle_path, times, velocities, angular_velocities, orientations, total_time, yaw_refs, pitch_refs, u_refs] = continuous_path_tracking(path, state, dt, T_final)
%[PROP-END]
    % State vector order:
    % x, y, z, phi, theta, psi, u, v, w, p, q, r
    % Multi-rate (T1B): plant+controller every dt_controller; guidance every
    % dt_guidance with zero-order hold of guidance outputs between ticks.
%[PROP-BEGIN]
    if ischar(path) || isstring(path)
        assert(strcmp(char(path), 'actuator'), 'unknown service call');
        [vehicle_path, times] = prop_thrust_actuator(dt, state, T_final, prop);
        return
    end
    if nargin < 5 || isempty(prop)
        prop = struct('name', 'ideal', 'ideal', true, 'tau', 0, 'gain', 1, ...
            'slew', Inf, 'T_min', -Inf, 'T_max', Inf);
    end
    act_state = [];
%[PROP-END]
    init_parameters();
    global dt_controller dt_guidance
    if nargin < 3 || isempty(dt)
        dt = dt_controller;
    else
        % Caller may pass plant/control dt; keep it consistent with globals
        dt_controller = dt;
    end
    if nargin < 4 || isempty(T_final)
        T_final = 15; % default simulation time [s]
    end
    if isempty(dt_guidance); dt_guidance = dt; end

    n_steps = round(T_final / dt);
    vehicle_path = zeros(n_steps, 3);
    times = zeros(n_steps, 1);
    velocities = zeros(n_steps, 3);
    angular_velocities = zeros(n_steps, 3);
    orientations = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1);
    pitch_refs = zeros(n_steps, 1);
    u_refs = zeros(n_steps, 1);
%[PROP-BEGIN]
    T_cmd_log = zeros(n_steps, 1);
    T_real_log = zeros(n_steps, 1);
    slew_hit_log = false(n_steps, 1);
    sat_hit_log = false(n_steps, 1);
%[PROP-END]
    % Optional 10th output via assignin not used; elevator logged for suite metrics
    global last_int_angle last_int_rate last_delta_e
    global last_rate_filt last_theta_phys_dot
    global last_de_uw_ff last_de_fb last_de_trim
    global last_M_uw last_M_elev last_M_e_ff last_G_de last_e_theta last_theta_phys
    global last_gamma_actual last_gamma_path last_alpha_eff last_e_gamma
    global last_e_z last_e_zdot last_zdot_inertial last_alpha_hat
    global last_delta_r last_dr_yaw last_dr_p last_dr_damp last_g_ac
    delta_e_log = zeros(n_steps, 1);
    delta_r_log = zeros(n_steps, 1);
    dr_yaw_log = zeros(n_steps, 1);
    dr_p_log = zeros(n_steps, 1);
    dr_damp_log = zeros(n_steps, 1);
    g_ac_log = zeros(n_steps, 1);
    int_angle_log = zeros(n_steps, 1);
    int_rate_log = zeros(n_steps, 1);
    rate_filt_log = zeros(n_steps, 1);
    rate_raw_log = zeros(n_steps, 1);
    de_uw_ff_log = zeros(n_steps, 1);
    de_fb_log = zeros(n_steps, 1);
    de_trim_log = zeros(n_steps, 1);
    M_uw_log = zeros(n_steps, 1);
    M_elev_log = zeros(n_steps, 1);
    M_e_ff_log = zeros(n_steps, 1);
    G_de_log = zeros(n_steps, 1);
    e_theta_log = zeros(n_steps, 1);
    theta_phys_log = zeros(n_steps, 1);
    u_log = zeros(n_steps, 1);
    w_log = zeros(n_steps, 1);
    gamma_actual_log = zeros(n_steps, 1);
    gamma_path_log = zeros(n_steps, 1);
    alpha_eff_log = zeros(n_steps, 1);
    e_gamma_log = zeros(n_steps, 1);
    e_z_log = zeros(n_steps, 1);
    e_zdot_log = zeros(n_steps, 1);
    zdot_inertial_log = zeros(n_steps, 1);
    total_time = 0;
    progress_index = 1;

    % Guidance ZOH state — call guidance only every N controller steps
    yaw_ref = 0; pitch_ref = 0; u_ref = 0; r_ff = 0; pitch_ref_dot = 0;
    guidance_period = max(1, round(dt_guidance / dt)); % e.g. 0.075/0.025 = 3

    for idx = 1:n_steps
        current_position = state(1:3)';
        current_orientation = state(4:6)';
        current_rates = state(10:12)';
        current_u = state(7);
        current_v = state(8);
        current_w = state(9);

        % Inertial velocity for Tur4A (U_h) and Tur5A (zdot)
        [U_h, zdot_inertial] = inertial_velocity_ned(current_orientation, current_u, current_v, current_w);
        theta_phys_now = -current_orientation(2);

        % Guidance tick (integrators/filters advance only here, with dt_guidance)
        if mod(idx - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
                guidance_law(current_position, path, progress_index, current_u, current_v, ...
                U_h, zdot_inertial, theta_phys_now);
        end

        % Controller every plant step; pass heave w (Muw-FF) and BODY p=state(10)
        [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            current_orientation(3), current_orientation(2), current_rates(3), current_rates(2), ...
            current_u, r_ff, pitch_ref_dot, current_orientation(1), current_w, ...
            current_rates(1));

        controls.delta_r = delta_r;
        controls.delta_e = delta_e;
%[PROP-BEGIN]
        % Realized thrust: controller command -> propulsion actuator -> plant.
        T_cmd = thrust;
        [T_real, act_state] = prop_thrust_actuator(T_cmd, act_state, dt, prop);
        controls.thrust = T_real;
%[PROP-ORIG]         controls.thrust = thrust;
%[PROP-END]

        try
            [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
            state = g(end, :)';
        catch ME
            fprintf('Simulation failed at step %d: %s\n', idx, ME.message);
            fprintf('Current state: theta=%.2f°, q=%.2f°/s, delta_e=%.2f°\n', ...
                rad2deg(current_orientation(2)), rad2deg(current_rates(2)), rad2deg(delta_e));
            vehicle_path = vehicle_path(1:idx-1, :);
            times = times(1:idx-1);
            velocities = velocities(1:idx-1, :);
            angular_velocities = angular_velocities(1:idx-1, :);
            orientations = orientations(1:idx-1, :);
            yaw_refs = yaw_refs(1:idx-1);
            pitch_refs = pitch_refs(1:idx-1);
            u_refs = u_refs(1:idx-1);
%[PROP-BEGIN]
            T_cmd_log = T_cmd_log(1:idx-1);
            T_real_log = T_real_log(1:idx-1);
            slew_hit_log = slew_hit_log(1:idx-1);
            sat_hit_log = sat_hit_log(1:idx-1);
%[PROP-END]
            break;
        end

        vehicle_path(idx, :) = state(1:3);
        velocities(idx, :) = state(7:9);
        angular_velocities(idx, :) = state(10:12);
        orientations(idx, :) = state(4:6);
        yaw_refs(idx) = yaw_ref;
        pitch_refs(idx) = pitch_ref;
        u_refs(idx) = u_ref;
%[PROP-BEGIN]
        T_cmd_log(idx) = T_cmd;
        T_real_log(idx) = T_real;
        slew_hit_log(idx) = act_state.slew_hit;
        sat_hit_log(idx) = act_state.sat_hit;
%[PROP-END]
        if isempty(last_delta_e); last_delta_e = 0; end
        if isempty(last_delta_r); last_delta_r = delta_r; end
        if isempty(last_dr_yaw); last_dr_yaw = 0; end
        if isempty(last_dr_p); last_dr_p = 0; end
        if isempty(last_dr_damp); last_dr_damp = 0; end
        if isempty(last_g_ac); last_g_ac = 1; end
        if isempty(last_int_angle); last_int_angle = 0; end
        if isempty(last_int_rate); last_int_rate = 0; end
        if isempty(last_rate_filt); last_rate_filt = 0; end
        if isempty(last_theta_phys_dot); last_theta_phys_dot = 0; end
        if isempty(last_de_uw_ff); last_de_uw_ff = 0; end
        if isempty(last_de_fb); last_de_fb = 0; end
        if isempty(last_de_trim); last_de_trim = 0; end
        if isempty(last_M_uw); last_M_uw = 0; end
        if isempty(last_M_elev); last_M_elev = 0; end
        if isempty(last_M_e_ff); last_M_e_ff = 0; end
        if isempty(last_G_de); last_G_de = 0; end
        if isempty(last_e_theta); last_e_theta = 0; end
        if isempty(last_theta_phys); last_theta_phys = 0; end
        if isempty(last_gamma_actual); last_gamma_actual = 0; end
        if isempty(last_gamma_path); last_gamma_path = 0; end
        if isempty(last_alpha_eff); last_alpha_eff = 0; end
        if isempty(last_e_gamma); last_e_gamma = 0; end
        if isempty(last_e_z); last_e_z = 0; end
        if isempty(last_e_zdot); last_e_zdot = 0; end
        if isempty(last_zdot_inertial); last_zdot_inertial = 0; end
        delta_e_log(idx) = last_delta_e;
        delta_r_log(idx) = last_delta_r;
        dr_yaw_log(idx) = last_dr_yaw;
        dr_p_log(idx) = last_dr_p;
        dr_damp_log(idx) = last_dr_damp;
        g_ac_log(idx) = last_g_ac;
        int_angle_log(idx) = last_int_angle;
        int_rate_log(idx) = last_int_rate;
        rate_filt_log(idx) = last_rate_filt;
        rate_raw_log(idx) = last_theta_phys_dot;
        de_uw_ff_log(idx) = last_de_uw_ff;
        de_fb_log(idx) = last_de_fb;
        de_trim_log(idx) = last_de_trim;
        M_uw_log(idx) = last_M_uw;
        M_elev_log(idx) = last_M_elev;
        M_e_ff_log(idx) = last_M_e_ff;
        G_de_log(idx) = last_G_de;
        e_theta_log(idx) = last_e_theta;
        theta_phys_log(idx) = last_theta_phys;
        u_log(idx) = current_u;
        w_log(idx) = current_w;
        gamma_actual_log(idx) = last_gamma_actual;
        gamma_path_log(idx) = last_gamma_path;
        alpha_eff_log(idx) = last_alpha_eff;
        e_gamma_log(idx) = last_e_gamma;
        e_z_log(idx) = last_e_z;
        e_zdot_log(idx) = last_e_zdot;
        zdot_inertial_log(idx) = last_zdot_inertial;
        total_time = total_time + dt;
        times(idx) = total_time;

        if mod(idx, 100) == 0 || idx == n_steps
            fprintf('Simulation step: %d/%d, total time = %.2f s, u=%.2f m/s, yaw=%.2f deg, pitch=%.2f deg\n', ...
                idx, n_steps, total_time, current_u, rad2deg(current_orientation(3)), rad2deg(current_orientation(2)));
        end
    end

    % Stash control diagnostics for suite metrics (caller reads globals)
    global suite_delta_e_log suite_int_angle_log suite_int_rate_log
    global suite_rate_filt_log suite_rate_raw_log
    global suite_de_uw_ff_log suite_de_fb_log suite_de_trim_log
    global suite_M_uw_log suite_M_elev_log suite_M_e_ff_log suite_G_de_log
    global suite_e_theta_log suite_theta_phys_log suite_u_log suite_w_log suite_pitch_refs_log
    global suite_gamma_actual_log suite_gamma_path_log suite_alpha_eff_log suite_e_gamma_log
    global suite_e_z_log suite_e_zdot_log suite_zdot_inertial_log
    global suite_delta_r_log suite_dr_yaw_log suite_dr_p_log suite_dr_damp_log suite_g_ac_log
    suite_delta_e_log = delta_e_log;
    suite_delta_r_log = delta_r_log;
    suite_dr_yaw_log = dr_yaw_log;
    suite_dr_p_log = dr_p_log;
    suite_dr_damp_log = dr_damp_log;
    suite_g_ac_log = g_ac_log;
    suite_int_angle_log = int_angle_log;
    suite_int_rate_log = int_rate_log;
    suite_rate_filt_log = rate_filt_log;
    suite_rate_raw_log = rate_raw_log;
    suite_de_uw_ff_log = de_uw_ff_log;
    suite_de_fb_log = de_fb_log;
    suite_de_trim_log = de_trim_log;
    suite_M_uw_log = M_uw_log;
    suite_M_elev_log = M_elev_log;
    suite_M_e_ff_log = M_e_ff_log;
    suite_G_de_log = G_de_log;
    suite_e_theta_log = e_theta_log;
    suite_theta_phys_log = theta_phys_log;
    suite_u_log = u_log;
    suite_w_log = w_log;
    suite_pitch_refs_log = pitch_refs;
    suite_gamma_actual_log = gamma_actual_log;
    suite_gamma_path_log = gamma_path_log;
    suite_alpha_eff_log = alpha_eff_log;
    suite_e_gamma_log = e_gamma_log;
    suite_e_z_log = e_z_log;
    suite_e_zdot_log = e_zdot_log;
    suite_zdot_inertial_log = zdot_inertial_log;
%[PROP-BEGIN]
    PROP = struct();
    PROP.prop = prop;
    PROP.ideal = logical(prop.ideal);
    PROP.T_cmd = T_cmd_log;
    PROP.T_real = T_real_log;
    PROP.slew_hit = slew_hit_log;
    PROP.sat_hit = sat_hit_log;
    if isstruct(act_state)
        PROP.n_slew = act_state.n_slew;
        PROP.n_sat = act_state.n_sat;
        PROP.n_steps_act = act_state.n;
    else
        PROP.n_slew = 0; PROP.n_sat = 0; PROP.n_steps_act = 0;
    end
%[PROP-END]
end

function [U_h, zdot] = inertial_velocity_ned(ori, u, v, w)
% INERTIAL_VELOCITY_NED  [x_dot;y_dot;z_dot] = R(phi,theta,psi)*[u;v;w]
% U_h = hypot(x_dot,y_dot); zdot = z_dot (Tur4A / Tur5A).
    phi = ori(1); theta = ori(2); psi = ori(3);
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
    pos_dot = R * [u; v; w];
    U_h = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end
%[PROP-BEGIN]

function [T_real, st] = prop_thrust_actuator(T_cmd, st, dt, prop)
% PROP_THRUST_ACTUATOR  Realized thrust between controller command and plant.
% ASSUMED simulation-only model (declared, not identified from hardware):
%   gain error -> first-order lag (exact ZOH) -> slew-rate limit -> saturation.
% prop.ideal == true is an exact passthrough: T_real = T_cmd with no arithmetic,
% which is what makes ideal-hook parity against the accepted audit bit-identical.
    if isempty(st) || ~isstruct(st)
        st = struct('T_prev', [], 'n_slew', 0, 'n_sat', 0, 'n', 0, ...
            'slew_hit', false, 'sat_hit', false);
    end
    st.n = st.n + 1;
    if prop.ideal
        T_real = T_cmd;
        st.T_prev = T_real;
        st.slew_hit = false;
        st.sat_hit = false;
        return
    end
    T_tgt = prop.gain * T_cmd;
    if isempty(st.T_prev)
        % Actuator initialised at the command equilibrium (no startup transient).
        T_prev = T_tgt;
    else
        T_prev = st.T_prev;
    end
    if prop.tau > 0
        a = exp(-dt / prop.tau);
        T_lag = a * T_prev + (1 - a) * T_tgt;
    else
        T_lag = T_tgt;
    end
    dT = T_lag - T_prev;
    dmax = prop.slew * dt;
    slew_hit = false;
    if dT > dmax
        T_lag = T_prev + dmax; slew_hit = true;
    elseif dT < -dmax
        T_lag = T_prev - dmax; slew_hit = true;
    end
    T_real = min(max(T_lag, prop.T_min), prop.T_max);
    sat_hit = (T_real ~= T_lag);
    st.T_prev = T_real;
    st.slew_hit = slew_hit;
    st.sat_hit = sat_hit;
    st.n_slew = st.n_slew + double(slew_hit);
    st.n_sat = st.n_sat + double(sat_hit);
end
%[PROP-END]
