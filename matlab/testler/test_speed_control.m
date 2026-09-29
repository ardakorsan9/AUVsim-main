function test_speed_control()
    % Test speed control independently
    init_parameters();

    dt = 0.075;
    total_time = 10;
    n_steps = round(total_time / dt);

    % Initial state: at origin, u = 0
    state = zeros(12, 1);
    u_ref = 1.5;

    times = zeros(n_steps, 1);
    us = zeros(n_steps, 1);
    thrusts = zeros(n_steps, 1);

    for idx = 1:n_steps
        current_u = state(7);

        % Controller: only speed
        e_u = u_ref - current_u;
        thrust = 17 * e_u - 4 * current_u; % Kp_x, Kd_x
        thrust = max(min(thrust, 300), -100);

        controls.delta_r = 0;
        controls.delta_e = 0;
        controls.thrust = thrust;

        % Dynamics
        [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
        state = g(end, :)';

        times(idx) = (idx-1)*dt;
        us(idx) = current_u;
        thrusts(idx) = thrust;
    end

    % Plot
    figure;
    subplot(2,1,1);
    plot(times, us, 'b', times, ones(size(times))*u_ref, 'r--');
    title('Speed Response');
    ylabel('u (m/s)');
    legend('Actual', 'Reference');

    subplot(2,1,2);
    plot(times, thrusts);
    title('Thrust');
    ylabel('Thrust (N)');
    xlabel('Time (s)');
end