function result = simulate_open_loop_constant_input(state0, controls, dt, T_final, limits)
% Açık çevrim sabit giriş simülasyonu
%
% limits.theta_max_deg
% limits.q_max_deg
% limits.u_max

    if nargin < 5 || isempty(limits)
        limits.theta_max_deg = 70;
        limits.q_max_deg = 80;
        limits.u_max = 20;
    end

    n_steps = round(T_final / dt);

    x_hist = zeros(n_steps, 12);
    t_hist = zeros(n_steps, 1);

    state = state0(:);
    valid = true;
    fail_reason = '';

    for k = 1:n_steps
        try
            [~, g] = ode45(@(t, x) underwater777_vehicle_dynamics(t, x, controls), [0 dt], state);
            state = g(end, :)';
        catch ME
            valid = false;
            fail_reason = ME.message;

            x_hist = x_hist(1:max(k-1,1), :);
            t_hist = t_hist(1:max(k-1,1));
            break;
        end

        x_hist(k, :) = state';
        t_hist(k) = k * dt;

        theta_deg = rad2deg(state(5));
        q_deg = rad2deg(state(11));
        u_val = state(7);

        if abs(theta_deg) > limits.theta_max_deg
            valid = false;
            fail_reason = sprintf('theta exceeded %.1f deg', limits.theta_max_deg);
            x_hist = x_hist(1:k, :);
            t_hist = t_hist(1:k);
            break;
        end

        if abs(q_deg) > limits.q_max_deg
            valid = false;
            fail_reason = sprintf('q exceeded %.1f deg/s', limits.q_max_deg);
            x_hist = x_hist(1:k, :);
            t_hist = t_hist(1:k);
            break;
        end

        if abs(u_val) > limits.u_max
            valid = false;
            fail_reason = sprintf('u exceeded %.1f m/s', limits.u_max);
            x_hist = x_hist(1:k, :);
            t_hist = t_hist(1:k);
            break;
        end
    end

    result.t = t_hist;
    result.x = x_hist;
    result.final_state = state;
    result.valid = valid;
    result.fail_reason = fail_reason;
end
