function test_open_loop_elevator()
    % Open-loop elevator test: apply constant elevator and observe pitch response
    init_parameters();
    dt = 0.075;
    T_final = 20;
    n_steps = round(T_final / dt);

    % Steady surge for test
    thrust_trim = 50;
    
    % Test with different constant elevator deflections
    elevator_degs = [-10, -5, 0, 5, 10];
    
    figure('Name', 'Open-Loop Elevator Response', 'NumberTitle', 'off');
    
    for elevator_deg = elevator_degs
        state = zeros(12, 1);
        state(7) = 1.0;  % steady surge
        
        times = zeros(n_steps, 1);
        theta_hist = zeros(n_steps, 1);
        q_hist = zeros(n_steps, 1);
        
        delta_e_rad = deg2rad(elevator_deg);
        
        for idx = 1:n_steps
            controls.delta_r = 0;
            controls.delta_e = delta_e_rad;
            controls.thrust = thrust_trim;
            
            [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
            state = g(end, :)';
            
            times(idx) = idx * dt;
            theta_hist(idx) = state(5);
            q_hist(idx) = state(11);
        end
        
        fprintf('Elevator = %d deg  -->  Final theta ≈ %.2f deg, Final q ≈ %.2f deg/s\n', ...
            elevator_deg, rad2deg(theta_hist(end)), rad2deg(q_hist(end)));
        
        plot(times, rad2deg(theta_hist), 'LineWidth', 1.5);
        hold on;
    end
    
    grid on;
    xlabel('Time (s)');
    ylabel('Pitch theta (deg)');
    title(sprintf('Open-Loop Elevator Response (Constant Thrust = %d N)', thrust_trim));
    legend('-10°', '-5°', '0°', '+5°', '+10°', 'Location', 'best');
end
