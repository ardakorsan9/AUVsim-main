function test_xz_line()
    % Test x-z inclined line following
    init_parameters();
    dt = 0.075;
    T_final = 15;
    n_steps = round(T_final / dt);
    
    % Path: x increasing, z increasing, y=0
    num_points = 1000;
    t = linspace(0, 10, num_points)';
    path = [t, zeros(size(t)), t]; % x=t, y=0, z=t
    
    % Initial state
    state = zeros(12, 1);
    state(1:3) = path(1, :)'; % start at (0,0,0)
    delta_pos = path(2, :) - path(1, :);
    initial_theta = atan2(-delta_pos(3), norm(delta_pos(1:2))); % corrected sign
    initial_psi = atan2(delta_pos(2), delta_pos(1));
    state(5) = initial_theta;
    state(6) = initial_psi;
    
    vehicle_path = zeros(n_steps, 3);
    times = zeros(n_steps, 1);
    orientations = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1);
    pitch_refs = zeros(n_steps, 1);
    total_time = 0;
    progress_index = 1;
    
    for idx = 1:n_steps
        current_position = state(1:3)';
        current_orientation = state(4:6)';
        current_rates = state(10:12)';
        current_u = state(7);
        
        [yaw_ref, pitch_ref, u_ref, progress_index] = guidance_law(current_position, path, progress_index);
        
        [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            current_orientation(3), current_orientation(2), current_rates(3), current_rates(2), current_u);
        
        controls.delta_r = delta_r;
        controls.delta_e = delta_e;
        controls.thrust = thrust;
        
        [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
        state = g(end, :)';
        total_time = total_time + dt;
        
        vehicle_path(idx, :) = state(1:3);
        orientations(idx, :) = state(4:6);
        yaw_refs(idx) = yaw_ref;
        pitch_refs(idx) = pitch_ref;
        times(idx) = total_time;
        
        if mod(idx, 100) == 0
            fprintf('Step %d: x=%.2f, z=%.2f, theta=%.2f deg, pitch_ref=%.2f deg\n', ...
                idx, state(1), state(3), rad2deg(state(5)), rad2deg(pitch_ref));
        end
    end
    
    figure;
    subplot(2,1,1);
    plot(path(:,1), path(:,3), 'r--', 'LineWidth', 2);
    hold on;
    plot(vehicle_path(:,1), vehicle_path(:,3), 'b', 'LineWidth', 1.5);
    xlabel('X (m)');
    ylabel('Z (m)');
    title('X-Z Path Following');
    legend('Reference', 'Vehicle');
    grid on;
    axis equal;
    
    subplot(2,1,2);
    plot(times, rad2deg(orientations(:,2)), 'b', times, rad2deg(pitch_refs), 'r--');
    xlabel('Time (s)');
    ylabel('Pitch (deg)');
    title('Pitch Response');
    legend('Actual', 'Reference');
    grid on;
end