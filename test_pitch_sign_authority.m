function test_pitch_sign_and_authority()
    % Test 1: Small constant elevator to verify pitch authority and sign
    % Goal: confirm positive elevator creates reasonable pitch response
    init_parameters();
    dt = 0.075;
    T_final = 15;
    n_steps = round(T_final / dt);

    % Fixed thrust for steady speed
    thrust_trim = 40;
    
    % Small elevator deflections for sign verification
    elevator_degs = [-2, 0, 2];  % very small
    
    fprintf('\n=== PITCH SIGN AND AUTHORITY TEST ===\n');
    fprintf('Testing with constant thrust = %d N\n\n', thrust_trim);
    
    figure('Name', 'Pitch Sign and Authority Test', 'NumberTitle', 'off');
    
    for idx_elev = 1:length(elevator_degs)
        elevator_deg = elevator_degs(idx_elev);
        state = zeros(12, 1);
        state(7) = 1.0;  % steady surge
        
        times = zeros(n_steps, 1);
        theta_hist = zeros(n_steps, 1);
        q_hist = zeros(n_steps, 1);
        delta_e_rad = deg2rad(elevator_deg);
        
        for step = 1:n_steps
            controls.delta_r = 0;
            controls.delta_e = delta_e_rad;
            controls.thrust = thrust_trim;
            
            [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
            state = g(end, :)';
            
            times(step) = step * dt;
            theta_hist(step) = state(5);
            q_hist(step) = state(11);
        end
        
        final_theta = rad2deg(theta_hist(end));
        final_q = rad2deg(q_hist(end));
        
        fprintf('Elevator = %+3d deg  -->  Final theta = %+8.2f deg, Final q = %+8.2f deg/s\n', ...
            elevator_deg, final_theta, final_q);
        
        subplot(1, 3, idx_elev);
        plot(times, rad2deg(theta_hist), 'LineWidth', 1.5);
        grid on;
        xlabel('Time (s)');
        ylabel('Pitch theta (deg)');
        title(sprintf('delta_e = %+d deg', elevator_deg));
    end
    
    fprintf('\n');
end
