function test_open_loop_thrust()
    % Open-loop thrust test: apply constant thrust and observe u response
    init_parameters();
    dt = 0.075;
    T_final = 30;
    n_steps = round(T_final / dt);

    % Test with different constant thrust values
    thrust_values = [10, 20, 40, 60, 80, 100];
    
    for thrust_test = thrust_values
        state = zeros(12, 1);
        state(7) = 0.1;  % very small initial u
        
        times = zeros(n_steps, 1);
        u_hist = zeros(n_steps, 1);
        
        for idx = 1:n_steps
            controls.delta_r = 0;
            controls.delta_e = 0;
            controls.thrust = thrust_test;
            
            [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
            state = g(end, :)';
            
            times(idx) = idx * dt;
            u_hist(idx) = state(7);
        end
        
        fprintf('Thrust = %d N  -->  Steady u ≈ %.2f m/s\n', thrust_test, u_hist(end));
    end
    
    % Plot one example: thrust = 60 N
    state = zeros(12, 1);
    state(7) = 0.1;
    thrust_test = 60;
    times = zeros(n_steps, 1);
    u_hist = zeros(n_steps, 1);
    
    for idx = 1:n_steps
        controls.delta_r = 0;
        controls.delta_e = 0;
        controls.thrust = thrust_test;
        
        [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
        state = g(end, :)';
        
        times(idx) = idx * dt;
        u_hist(idx) = state(7);
    end
    
    figure('Name', 'Open-Loop Thrust Response', 'NumberTitle', 'off');
    plot(times, u_hist, 'b', 'LineWidth', 2);
    grid on;
    xlabel('Time (s)');
    ylabel('Surge Speed u (m/s)');
    title(sprintf('Open-Loop Response: Constant Thrust = %d N', thrust_test));
end
