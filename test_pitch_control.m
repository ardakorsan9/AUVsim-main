function test_pitch_control()
    % Test pitch PD control independently
    init_parameters();

    dt = 0.075;
    total_time = 10;
    n_steps = round(total_time / dt);

    % Initial state: at origin, theta = 0, u = 1.5
    state = zeros(12, 1);
    state(7) = 1.5;
    theta_ref = deg2rad(15); % step to 15 deg

    times = zeros(n_steps, 1);
    thetas = zeros(n_steps, 1);
    qs = zeros(n_steps, 1);
    delta_es = zeros(n_steps, 1);

    for idx = 1:n_steps
        current_theta = state(5);
        current_q = state(11);
        current_u = state(7);

        % Controller: only pitch
        e_theta = theta_ref - current_theta;
        delta_e = 100 * e_theta - 15 * current_q; % Kp_theta, Kd_theta
        delta_e = max(min(delta_e, deg2rad(15)), -deg2rad(15));

        controls.delta_r = 0; % no yaw
        controls.delta_e = delta_e;
        controls.thrust = 17 * (1.5 - current_u) - 4 * current_u;

        % Dynamics
        [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
        state = g(end, :)';

        times(idx) = (idx-1)*dt;
        thetas(idx) = rad2deg(current_theta);
        qs(idx) = rad2deg(current_q);
        delta_es(idx) = rad2deg(delta_e);
    end

    % Plot
    figure;
    subplot(3,1,1);
    plot(times, thetas, 'g', times, ones(size(times))*rad2deg(theta_ref), 'r--');
    title('Pitch Response');
    ylabel('Pitch (deg)');
    legend('Actual', 'Reference');

    subplot(3,1,2);
    plot(times, qs);
    title('Pitch Rate');
    ylabel('q (deg/s)');

    subplot(3,1,3);
    plot(times, delta_es);
    title('Elevator Deflection');
    ylabel('delta_e (deg)');
    xlabel('Time (s)');
end