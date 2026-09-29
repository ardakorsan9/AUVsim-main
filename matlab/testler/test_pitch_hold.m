function test_pitch_hold()
    % Initialize parameters and state for isolated pitch hold.
    init_parameters();
    dt = 0.075;
    T_final = 20;
    n_steps = round(T_final / dt);

    % Initial state [x y z phi theta psi u v w p q r]
    state = zeros(12, 1);
    state(7) = 0.5;   % initial surge speed
    state(5) = 0.0;   % initial pitch
    state(6) = 0.0;   % initial yaw

    pitch_ref = deg2rad(15); % ask for nose-up toward positive z
    yaw_ref = 0.0;
    u_ref = 1.5;

    times = zeros(n_steps, 1);
    theta_actual = zeros(n_steps, 1);
    q_actual = zeros(n_steps, 1);
    delta_e_hist = zeros(n_steps, 1);
    pitch_refs = zeros(n_steps, 1);
    u_actual = zeros(n_steps, 1);
    u_refs = zeros(n_steps, 1);
    thrust_hist = zeros(n_steps, 1);
    z_hist = zeros(n_steps, 1);

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

        times(idx) = idx * dt;
        theta_actual(idx) = state(5);
        q_actual(idx) = state(11);
        delta_e_hist(idx) = delta_e;
        pitch_refs(idx) = pitch_ref;
        u_actual(idx) = state(7);
        u_refs(idx) = u_ref;
        thrust_hist(idx) = thrust;
        z_hist(idx) = state(3);
    end

    figure('Name', 'Pitch and Speed Hold Diagnostics', 'NumberTitle', 'off');
    
    subplot(3, 2, 1);
    plot(times, rad2deg(theta_actual), 'b', 'LineWidth', 1.5);
    hold on;
    plot(times, rad2deg(pitch_refs), 'r--', 'LineWidth', 1.5);
    grid on;
    xlabel('Time (s)');
    ylabel('Pitch (deg)');
    title('Pitch Hold: Actual vs Reference');
    legend('Actual \theta', 'Reference \theta');

    subplot(3, 2, 2);
    plot(times, u_actual, 'b', 'LineWidth', 1.5);
    hold on;
    plot(times, u_refs, 'r--', 'LineWidth', 1.5);
    grid on;
    xlabel('Time (s)');
    ylabel('Speed (m/s)');
    title('Speed: Actual vs Reference');
    legend('Actual u', 'Reference u');

    subplot(3, 2, 3);
    plot(times, rad2deg(q_actual), 'k', 'LineWidth', 1.4);
    grid on;
    xlabel('Time (s)');
    ylabel('q (deg/s)');
    title('Pitch Rate q');

    subplot(3, 2, 4);
    plot(times, thrust_hist, 'm', 'LineWidth', 1.4);
    grid on;
    xlabel('Time (s)');
    ylabel('Thrust (N)');
    title('Thrust Command');

    subplot(3, 2, 5);
    plot(times, rad2deg(delta_e_hist), 'c', 'LineWidth', 1.4);
    grid on;
    xlabel('Time (s)');
    ylabel('delta_e (deg)');
    title('Elevator Command');

    subplot(3, 2, 6);
    plot(times, z_hist, 'b', 'LineWidth', 1.4);
    grid on;
    xlabel('Time (s)');
    ylabel('Z Position (m)');
    title('Z Position During Hold');
end