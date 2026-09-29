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

    % Tur 2.5.1: fold closed-loop steady angle-I elevator into trim so
    % Ki_rate=0 level flight does not need a large outer-I offset.
    table = refine_trim_closedloop(table);
    trim_speed_table = table.speed;
    trim_elevator_table = table.delta_e;
end

function table = refine_trim_closedloop(table)
% Run brief level-flight (pitch_ref=0) and absorb angle-I elevator into trim.
    global dt_controller delta_e_max
    fprintf('\n--- Closed-loop trim refine (Tur 2.5.1) ---\n');
    dt = dt_controller;
    if isempty(dt); dt = 0.025; end
    T = 22;
    t_settle = 10;
    n = round(T / dt);
    i0 = max(1, round(t_settle / dt));

    for pass = 1:2
        for is = 1:numel(table.speed)
            u_des = table.speed(is);
            clear controller_law
            [de_new, th_m, de_I_m, e_m] = closedloop_trim_sample(u_des, dt, n, i0);
            de_new = max(min(de_new, delta_e_max), -delta_e_max);
            fprintf('  pass%d u=%.1f -> de_trim=%+5.2f deg (was %+5.2f) eθ=%+.2f° de_I=%+.2f° θ=%+.2f°\n', ...
                pass, u_des, rad2deg(de_new), rad2deg(table.delta_e(is)), ...
                rad2deg(e_m), rad2deg(de_I_m), rad2deg(th_m));
            table.delta_e(is) = de_new;
            table.theta_phys(is) = th_m;
            table.ok(is) = abs(th_m) <= deg2rad(3);
        end
        global trim_speed_table trim_elevator_table
        trim_speed_table = table.speed;
        trim_elevator_table = table.delta_e;
    end
    clear controller_law
end

function [de_fold, th_m, de_I_m, e_m] = closedloop_trim_sample(u_des, dt, n, i0)
    global trim_speed_table trim_elevator_table
    state = zeros(12, 1);
    state(7) = u_des;
    yaw_ref = 0; pitch_ref = 0; u_ref = u_des;
    de_hist = zeros(n,1); deI_hist = zeros(n,1);
    th_hist = zeros(n,1); e_hist = zeros(n,1);
    for k = 1:n
        ori = state(4:6);
        rates = state(10:12);
        u = state(7);
        [delta_r, delta_e, thrust, dbg] = controller_law( ...
            yaw_ref, pitch_ref, u_ref, ori(3), ori(2), rates(3), rates(2), ...
            u, 0, 0, ori(1));
        controls = struct('delta_r', delta_r, 'delta_e', delta_e, 'thrust', thrust);
        try
            [~, g] = ode45(@(t, x) underwater777_vehicle_dynamics(t, x, controls), [0 dt], state);
            state = g(end, :)';
        catch
            de_fold = interp1(trim_speed_table, trim_elevator_table, u_des, 'linear', 'extrap');
            th_m = deg2rad(90); de_I_m = 0; e_m = deg2rad(90);
            return;
        end
        de_hist(k) = dbg.de_trim;
        deI_hist(k) = dbg.delta_e_angle_I;
        th_hist(k) = dbg.theta_phys;
        e_hist(k) = dbg.e_theta;
    end
    sl = i0:n;
    de_fold = mean(de_hist(sl) + deI_hist(sl));
    th_m = mean(th_hist(sl));
    de_I_m = mean(deI_hist(sl));
    e_m = mean(e_hist(sl));
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
