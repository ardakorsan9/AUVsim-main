function underwater777_vehicle_simulation()
    % Load parameters
    init_parameters();

    % Time step
    dt = 0.075;

    % Initial conditions
    % State vector order: [x y z phi theta psi u v w p q r]
    f_0 = zeros(12, 1);

    % Path generation - 3D straight line with equal speed components
    num_points = 1000;
    t = linspace(0, 10, num_points)';
    x_path = t;
    y_path = t;
    z_path = t;
    path = [x_path, y_path, z_path];

    % Set initial position and orientation
    delta_pos = path(2, :) - path(1, :);
    initial_theta = atan2(-delta_pos(3), norm(delta_pos(1:2))); % Pitch angle (negative for upward z in model convention)
    initial_psi = atan2(delta_pos(2), delta_pos(1));          % Yaw angle

    f_0(1:3) = path(1, :)'; % Initial position
    f_0(5) = initial_theta; % Theta (pitch)
    f_0(6) = initial_psi;    % Psi (yaw)

    % Collect path-generation parameters
    path_params = struct( ...
        'type', '3d_straight_line', ...
        'description', '3D straight line from (0,0,0) to (10,10,10) with equal speed in x,y,z', ...
        'radius', NaN, ...
        'pitch', NaN, ...
        'num_turns', NaN, ...
        'num_points', num_points, ...
        'lookahead_distance', NaN);

    % Continuous path tracking (numerics first; plotting later)
    [vehicle_path, times, velocities, angular_velocities, orientations, total_time, yaw_refs, pitch_refs, u_refs] = ...
        continuous_path_tracking(path, f_0, dt);

    % Plot results once
    sim_params = struct('dt', dt, 'total_time', total_time, ...
                        'start_position', path(1, :), ...
                        'reference_path_type', '3D Straight Line Path');
    plot_simulation_results(path, vehicle_path, times, velocities, angular_velocities, orientations, path_params, sim_params, yaw_refs, pitch_refs, u_refs);
end
