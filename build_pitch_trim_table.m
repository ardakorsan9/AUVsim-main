function table = build_pitch_trim_table()
% Find elevator trim for theta_phys≈0 at several surge speeds.
% Coarse-then-fine search; if level flight impossible, clamp/extrap + warn.
    init_parameters();
    global delta_e_max

    speeds = [0.8, 1.0, 1.5, 2.0];
    dt = 0.05;
    T = 14;
    n = round(T/dt);
    n_avg = round(2.5/dt);

    trim_de = zeros(size(speeds));
    trim_th = zeros(size(speeds));
    trim_ok = false(size(speeds));
    level_tol = deg2rad(3);

    fprintf('\n=== PITCH TRIM TABLE (theta_phys -> 0) ===\n');
    for is = 1:numel(speeds)
        u_des = speeds(is);
        thrust = max(5, 1.9 * abs(u_des) * u_des + 8);

        % Coarse then fine around best
        de_coarse = deg2rad(-15:1:5);
        [best_de, best_th, best_err] = search_de_grid(u_des, thrust, de_coarse, dt, n, n_avg);

        de_fine = unique([best_de + deg2rad(-1.5:0.25:1.5), best_de]);
        de_fine = de_fine(de_fine >= -delta_e_max & de_fine <= delta_e_max);
        [best_de2, best_th2, best_err2] = search_de_grid(u_des, thrust, de_fine, dt, n, n_avg);
        if best_err2 < best_err
            best_de = best_de2;
            best_th = best_th2;
        end

        if abs(best_th) > level_tol
            % Extrapolate ~1/u^2 from last good lower-speed trim
            for j = is-1:-1:1
                if trim_ok(j)
                    u_j = speeds(j);
                    de_extrap = trim_de(j) * (u_j / max(u_des, 0.3))^2;
                    de_extrap = max(min(de_extrap, delta_e_max), -delta_e_max);
                    th_ex = settled_theta(u_des, de_extrap, thrust, dt, n, n_avg);
                    if abs(th_ex) < abs(best_th)
                        best_de = de_extrap;
                        best_th = th_ex;
                    end
                    break;
                end
            end
            % Prefer actuator-limit nose-down if still floating positive
            if best_th > level_tol
                th_lim = settled_theta(u_des, -delta_e_max, thrust, dt, n, n_avg);
                if abs(th_lim) < abs(best_th)
                    best_de = -delta_e_max;
                    best_th = th_lim;
                end
            end
            fprintf('u=%.1f -> de_trim=%+5.2f deg (theta_phys=%+5.2f deg) [CLAMP/EXTRAP]\n', ...
                u_des, rad2deg(best_de), rad2deg(best_th));
            trim_ok(is) = abs(best_th) <= level_tol;
        else
            fprintf('u=%.1f -> de_trim=%+5.2f deg (theta_phys=%+5.2f deg)\n', ...
                u_des, rad2deg(best_de), rad2deg(best_th));
            trim_ok(is) = true;
        end
        trim_de(is) = best_de;
        trim_th(is) = best_th;
    end

    table.speed = speeds;
    table.delta_e = trim_de;
    table.theta_phys = trim_th;
    table.ok = trim_ok;

    global trim_speed_table trim_elevator_table
    trim_speed_table = speeds;
    trim_elevator_table = trim_de;
end

function [best_de, best_th, best_err] = search_de_grid(u_des, thrust, de_grid, dt, n, n_avg)
    best_err = inf;
    best_de = 0;
    best_th = 0;
    for de = de_grid
        [th_m, th_rms, q_end, u_end, ok] = settled_metrics(u_des, de, thrust, dt, n, n_avg);
        if ~ok; continue; end
        err = th_rms + 0.15*abs(th_m) + 0.25*q_end + 0.04*abs(u_end - u_des);
        if err < best_err
            best_err = err;
            best_de = de;
            best_th = th_m;
        end
    end
end

function th_m = settled_theta(u_des, de, thrust, dt, n, n_avg)
    [th_m, ~, ~, ~, ok] = settled_metrics(u_des, de, thrust, dt, n, n_avg);
    if ~ok; th_m = deg2rad(90); end
end

function [th_m, th_rms, q_end, u_end, ok] = settled_metrics(u_des, de, thrust, dt, n, n_avg)
    state = zeros(12,1);
    state(7) = u_des;
    c = struct('delta_r',0,'delta_e',de,'thrust',thrust);
    th_hist = zeros(n,1);
    ok = true;
    for k = 1:n
        try
            [~,g] = ode45(@(t,x) underwater777_vehicle_dynamics(t,x,c),[0 dt],state);
            state = g(end,:)';
        catch
            ok = false; break;
        end
        if abs(state(5)) > deg2rad(80); ok = false; break; end
        th_hist(k) = -state(5);
    end
    if ~ok
        th_m = deg2rad(90); th_rms = deg2rad(90); q_end = 0; u_end = u_des;
        return;
    end
    i0 = max(1, n - n_avg + 1);
    th_m = mean(th_hist(i0:n));
    th_rms = sqrt(mean(th_hist(i0:n).^2));
    q_end = abs(state(11));
    u_end = state(7);
end
