function test_helix()
    % Test helix path following
    init_parameters();

    dt = 0.075;
    total_time = 50;
    n_steps = round(total_time / dt);

    % Generate helix path
    radius = 5;
    pitch_h = 2;
    num_turns = 2;
    num_points = 400;
    t = linspace(0, num_turns*2*pi, num_points)';
    x_path = radius * cos(t);
    y_path = radius * sin(t);
    z_path = (pitch_h / (2*pi)) * t;
    path = [x_path, y_path, z_path];

    % Initial state
    state = zeros(12, 1);
    state(1:3) = path(1, :)';
    state(7) = 1.5;
    delta_pos = path(2,:) - path(1,:);
    state(6) = atan2(delta_pos(2), delta_pos(1));
    state(5) = atan2(delta_pos(3), norm(delta_pos(1:2)));

    vehicle_path = zeros(n_steps, 3);
    times = zeros(n_steps, 1);

    for idx = 1:n_steps
        current_position = state(1:3)';

        % Guidance
        [yaw_ref, pitch_ref, u_ref] = guidance_law(current_position, path);

        % Controller
        [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            state(6), state(5), state(12), state(11), state(7));

        controls.delta_r = delta_r;
        controls.delta_e = delta_e;
        controls.thrust = thrust;

        % Dynamics
        [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
        state = g(end, :)';

        vehicle_path(idx, :) = state(1:3);
        times(idx) = (idx-1)*dt;

        if mod(idx, 50) == 0
            fprintf('Step %d, position: [%.2f, %.2f, %.2f]\n', idx, state(1), state(2), state(3));
        end
    end

    % Plot
    figure;
    plot3(path(:,1), path(:,2), path(:,3), 'k--', 'LineWidth', 2);
    hold on;
    plot3(vehicle_path(:,1), vehicle_path(:,2), vehicle_path(:,3), 'b-', 'LineWidth', 1.5);
    grid on;
    axis equal;
    xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
    title('Helix Path Following');
    legend('Reference Path', 'Vehicle Path');
end