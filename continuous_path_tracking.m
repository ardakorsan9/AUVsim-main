function [vehicle_path, times, velocities, angular_velocities, orientations, total_time, yaw_refs, pitch_refs, u_refs] = continuous_path_tracking(path, state, dt, T_final)
    % State vector order:
    % x, y, z, phi, theta, psi, u, v, w, p, q, r
    % dt = control/plant sample period (same as dt_controller for T1A single-rate)
    init_parameters();
    global dt_controller
    if nargin < 3 || isempty(dt)
        dt = dt_controller;
    end
    if nargin < 4 || isempty(T_final)
        T_final = 15; % default simulation time [s]
    end
    n_steps = round(T_final / dt);
    vehicle_path = zeros(n_steps, 3);
    times = zeros(n_steps, 1);
    velocities = zeros(n_steps, 3);
    angular_velocities = zeros(n_steps, 3);
    orientations = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1);
    pitch_refs = zeros(n_steps, 1);
    u_refs = zeros(n_steps, 1);
    total_time = 0;
    progress_index = 1; % start from first point

    for idx = 1:n_steps
        current_position = state(1:3)';
        current_orientation = state(4:6)';
        current_rates = state(10:12)';
        current_u = state(7);
        current_v = state(8);

        % Guidance: refs + r_ff + pitch_ref_dot + beta(u,v)
        [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
            guidance_law(current_position, path, progress_index, current_u, current_v);

        % Controller: cascaded pitch + yaw
        [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            current_orientation(3), current_orientation(2), current_rates(3), current_rates(2), ...
            current_u, r_ff, pitch_ref_dot, current_orientation(1));

        controls.delta_r = delta_r;
        controls.delta_e = delta_e;
        controls.thrust = thrust;

        % Dynamics: integrate one simulation step with current control inputs
        try
            [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
            state = g(end, :)';
        catch ME
            fprintf('Simulation failed at step %d: %s\n', idx, ME.message);
            fprintf('Current state: theta=%.2f°, q=%.2f°/s, delta_e=%.2f°\n', ...
                rad2deg(current_orientation(2)), rad2deg(current_rates(2)), rad2deg(delta_e));
            % Stop simulation
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
        total_time = total_time + dt;
        times(idx) = total_time;

        if mod(idx, 100) == 0 || idx == n_steps
            fprintf('Simülasyon adımı: %d/%d, toplam süre = %.2f s, u=%.2f m/s, yaw=%.2f deg, pitch=%.2f deg\n', ...
                idx, n_steps, total_time, current_u, rad2deg(current_orientation(3)), rad2deg(current_orientation(2)));
        end
    end
end
