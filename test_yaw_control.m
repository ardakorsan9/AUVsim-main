function test_yaw_control()
    % Test yaw PD control independently
    init_parameters();

    dt = 0.075;
    total_time = 10; % short test
    n_steps = round(total_time / dt);

    % Initial state: at origin, psi = 0, u = 1.5
    state = zeros(12, 1);
    state(7) = 1.5; % u
    psi_ref = deg2rad(30); % step to 30 deg

    times = zeros(n_steps, 1);
    psis = zeros(n_steps, 1);
    rs = zeros(n_steps, 1);
    delta_rs = zeros(n_steps, 1);

    for idx = 1:n_steps
        current_psi = state(6);
        current_r = state(12);
        current_u = state(7);

        % Controller: only yaw
        e_psi = wrapToPi(psi_ref - current_psi);
        delta_r = 25 * e_psi - 7 * current_r; % Kp_psi, Kd_psi
        delta_r = max(min(delta_r, deg2rad(20)), -deg2rad(20));

        controls.delta_r = delta_r;
        controls.delta_e = 0; % no pitch
        controls.thrust = 17 * (1.5 - current_u) - 4 * current_u; % speed control

        % Dynamics
        [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
        state = g(end, :)';

        times(idx) = (idx-1)*dt;
        psis(idx) = rad2deg(current_psi);
        rs(idx) = rad2deg(current_r);
        delta_rs(idx) = rad2deg(delta_r);
    end

    % Plot
    figure;
    subplot(3,1,1);
    plot(times, psis, 'b', times, ones(size(times))*rad2deg(psi_ref), 'r--');
    title('Yaw Response');
    ylabel('Yaw (deg)');
    legend('Actual', 'Reference');

    subplot(3,1,2);
    plot(times, rs);
    title('Yaw Rate');
    ylabel('r (deg/s)');

    subplot(3,1,3);
    plot(times, delta_rs);
    title('Rudder Deflection');
    ylabel('delta_r (deg)');
    xlabel('Time (s)');
end