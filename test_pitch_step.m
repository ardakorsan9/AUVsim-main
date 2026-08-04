function test_pitch_step()
    % Test pitch control with step reference
    init_parameters();
    dt = 0.075;
    T_final = 10; % short test
    n_steps = round(T_final / dt);
    
    % Initial state
    state = zeros(12, 1);
    state(7) = 1.0; % initial u
    
    % Test positive pitch ref
    pitch_ref = deg2rad(10);
    yaw_ref = 0;
    u_ref = 1.0;
    
    vehicle_path = zeros(n_steps, 3);
    times = zeros(n_steps, 1);
    orientations = zeros(n_steps, 3);
    total_time = 0;
    
    for idx = 1:n_steps
        current_orientation = state(4:6)';
        current_rates = state(10:12)';
        current_u = state(7);
        
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
        times(idx) = total_time;
        
        if mod(idx, 50) == 0
            fprintf('Step %d: theta=%.2f deg, delta_e=%.2f deg\n', idx, rad2deg(state(5)), rad2deg(delta_e));
        end
    end
    
    figure;
    plot(times, rad2deg(orientations(:, 2)), 'b', 'LineWidth', 1.5);
    hold on;
    plot(times, ones(size(times))*rad2deg(pitch_ref), 'r--', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Pitch (deg)');
    title('Pitch Step Response: Ref = +10 deg');
    legend('Actual Pitch', 'Reference');
    grid on;
end