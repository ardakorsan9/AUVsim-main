function [vehicle_path, times, velocities, angular_velocities, orientations, total_time, yaw_refs, pitch_refs, u_refs] = continuous_path_tracking(path, state, dt, T_final)
    % State vector order:
    % x, y, z, phi, theta, psi, u, v, w, p, q, r
    % Multi-rate (T1B): plant+controller every dt_controller; guidance every
    % dt_guidance with zero-order hold of guidance outputs between ticks.
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
    % Optional 10th output via assignin not used; elevator logged for suite metrics
    global last_int_angle last_int_rate last_delta_e
    global last_rate_filt last_theta_phys_dot
    global last_de_uw_ff last_de_fb last_de_trim
    global last_M_uw last_M_elev last_M_e_ff last_G_de last_e_theta last_theta_phys
    delta_e_log = zeros(n_steps, 1);
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

        % Inertial horizontal speed for Tur4A r_ff = U_h * kappa
        U_h = inertial_horizontal_speed(current_orientation, current_u, current_v, current_w);

        % Guidance tick (integrators/filters advance only here, with dt_guidance)
        if mod(idx - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
                guidance_law(current_position, path, progress_index, current_u, current_v, U_h);
        end

        % Controller every plant step (dt_controller); pass heave w for Muw-FF
        [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            current_orientation(3), current_orientation(2), current_rates(3), current_rates(2), ...
            current_u, r_ff, pitch_ref_dot, current_orientation(1), current_w);

        controls.delta_r = delta_r;
        controls.delta_e = delta_e;
        controls.thrust = thrust;

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
            break;
        end

        vehicle_path(idx, :) = state(1:3);
        velocities(idx, :) = state(7:9);
        angular_velocities(idx, :) = state(10:12);
        orientations(idx, :) = state(4:6);
        yaw_refs(idx) = yaw_ref;
        pitch_refs(idx) = pitch_ref;
        u_refs(idx) = u_ref;
        if isempty(last_delta_e); last_delta_e = 0; end
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
        delta_e_log(idx) = last_delta_e;
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
        total_time = total_time + dt;
        times(idx) = total_time;

        if mod(idx, 100) == 0 || idx == n_steps
            fprintf('Simülasyon adımı: %d/%d, toplam süre = %.2f s, u=%.2f m/s, yaw=%.2f deg, pitch=%.2f deg\n', ...
                idx, n_steps, total_time, current_u, rad2deg(current_orientation(3)), rad2deg(current_orientation(2)));
        end
    end

    % Stash control diagnostics for suite metrics (caller reads globals)
    global suite_delta_e_log suite_int_angle_log suite_int_rate_log
    global suite_rate_filt_log suite_rate_raw_log
    global suite_de_uw_ff_log suite_de_fb_log suite_de_trim_log
    global suite_M_uw_log suite_M_elev_log suite_M_e_ff_log suite_G_de_log
    global suite_e_theta_log suite_theta_phys_log suite_u_log suite_w_log suite_pitch_refs_log
    suite_delta_e_log = delta_e_log;
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
end

function U_h = inertial_horizontal_speed(ori, u, v, w)
% INERTIAL_HORIZONTAL_SPEED  U_h = hypot(x_dot, y_dot) from body vel via R(phi,theta,psi).
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
end
