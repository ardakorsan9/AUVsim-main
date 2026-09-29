function run_auv_v1_sensor_noise_dropout()
%RUN_AUV_V1_SENSOR_NOISE_DROPOUT  Deterministic IMU/depth noise and short-dropout metrics.
%   Reuses the nominal open-path harness (dt=0.025 s) and the isolated
%   navigation_multirate_sensor_chain / navigation_multirate_ekf_availability
%   interfaces. Runs fixed-seed finite IMU/depth noise and bounded short
%   dropout cases, rejects non-finite values, writes
%   artifacts/robustness/sensor_noise_dropout.json and summary plots.
%   Simulation-only characterization; certified=false.

    proj_root = pwd;
    addpath(proj_root);

    artifact_dir = fullfile(proj_root, 'artifacts', 'robustness');
    if ~exist(artifact_dir, 'dir')
        mkdir(artifact_dir);
    end

    scenario = 'sensor_noise_dropout_3d_straight_line';
    seed = 20260828;
    dt = 0.025;
    duration_s = 30.0;
    nav_route = 'X';
    Vc_ned = [0, 0, 0];

    % Predeclared finite noise (ASSUMED chain sigmas, not fitted).
    noise_params = struct();
    noise_params.imu_gyro_sigma_rad_s = [0.0035, 0.0035, 0.0035];
    noise_params.imu_accel_sigma_mps2 = [0.020, 0.020, 0.020];
    noise_params.depth_sigma_m = 0.020;
    noise_params.scale = 1.0;
    noise_params.note = 'ASSUMED declared sensor-chain sigmas; scale=1.0, not calibrated.';

    % Predeclared bounded short dropout windows on the nav bus clock [s].
    dropout_params = struct();
    dropout_params.depth_window_s = [8.0, 9.0];
    dropout_params.imu_window_s = [10.0, 11.0];
    dropout_params.note = 'Explicit short message gaps; duration <= 1.0 s each.';

    num_points = 120;
    path_length_m = 60.0;
    depth_m = 5.0;
    path = [linspace(0, path_length_m, num_points)', zeros(num_points, 1), ...
        -depth_m * ones(num_points, 1)];

    rng(seed, 'twister');
    init_parameters();
    global desired_speed

    state = zeros(12, 1);
    state(1:3) = [0; 0; -depth_m];
    state(7) = desired_speed;

    try
        [vehicle_path, times, velocities, angular_velocities, orientations, total_time, ...
            yaw_refs, pitch_refs, u_refs] = continuous_path_tracking(path, state, dt, duration_s);
    catch ME
        error('run_auv_v1_sensor_noise_dropout:SimulationFailed', ...
            'continuous_path_tracking failed: %s', ME.message);
    end

    expected_steps = round(duration_s / dt);
    if size(vehicle_path, 1) < expected_steps
        error('run_auv_v1_sensor_noise_dropout:EarlyTermination', ...
            'Simulation ended early (%d/%d steps).', size(vehicle_path, 1), expected_steps);
    end

    assert_all_finite(vehicle_path, times, velocities, angular_velocities, orientations, ...
        yaw_refs, pitch_refs, u_refs);

    path_metrics = compute_path_following_metrics(path, vehicle_path, velocities, orientations, ...
        yaw_refs, pitch_refs, dt, times);
    path_metric_values = flatten_numeric_metrics(path_metrics);
    assert_all_finite(struct2array(path_metric_values));

    path_params = struct( ...
        'type', '3d_straight_line', ...
        'description', 'Nominal harness open straight line (+X at constant depth)', ...
        'num_points', num_points);
    sim_params = struct( ...
        'start_position', state(1:3)', ...
        'reference_path_type', '3d_straight_line', ...
        'dt', dt, ...
        'total_time', total_time);
    plot_simulation_results(path, vehicle_path, times, velocities, angular_velocities, ...
        orientations, path_params, sim_params, yaw_refs, pitch_refs, u_refs);
    save_sensor_plots(artifact_dir, 'path_nominal');

    cfgc = navigation_multirate_sensor_chain('config');
    cfga = navigation_multirate_ekf_availability('config');
    cfgc = apply_finite_noise(cfgc, noise_params);

    T = navigation_multirate_sensor_chain('truth', nav_route, Vc_ned, cfgc, ...
        struct('dvl_outage', false, 'label', 'sensor_noise_dropout_X'));
    B0 = navigation_multirate_sensor_chain('run', T, cfgc, seed);

    nav_case_defs = {
        struct('name', 'declared_finite_noise', ...
            'dropout', struct('depth', [NaN NaN], 'imu', [NaN NaN]))
        struct('name', 'short_depth_dropout', ...
            'dropout', struct('depth', dropout_params.depth_window_s, 'imu', [NaN NaN]))
        struct('name', 'short_imu_dropout', ...
            'dropout', struct('depth', [NaN NaN], 'imu', dropout_params.imu_window_s))
    };

    nav_results = cell(1, numel(nav_case_defs));
    nav_plot_data = cell(1, numel(nav_case_defs));

    for ci = 1:numel(nav_case_defs)
        case_def = nav_case_defs{ci};
        B = B0;
        sched = struct('depth_window_s', case_def.dropout.depth, ...
            'imu_window_s', case_def.dropout.imu);

        if all(isfinite(case_def.dropout.depth))
            [B.meas.depth_pressure, sched.depth] = suppress_channel( ...
                B.meas.depth_pressure, B.t, case_def.dropout.depth);
        else
            sched.depth = struct('window_s', [NaN NaN], 'n_suppressed_messages', 0, ...
                'n_delivered', sum([B.meas.depth_pressure.seq(1); diff(B.meas.depth_pressure.seq(:))] > 0));
        end

        if all(isfinite(case_def.dropout.imu))
            [B.meas.imu_gyro, sched.imu_gyro] = suppress_channel( ...
                B.meas.imu_gyro, B.t, case_def.dropout.imu);
            [B.meas.imu_accel, sched.imu_accel] = suppress_channel( ...
                B.meas.imu_accel, B.t, case_def.dropout.imu);
        else
            sgy = B.meas.imu_gyro.seq(:);
            sag = B.meas.imu_accel.seq(:);
            sched.imu_gyro = struct('window_s', [NaN NaN], 'n_suppressed_messages', 0, ...
                'n_delivered', sum([sgy(1); diff(sgy)] > 0));
            sched.imu_accel = struct('window_s', [NaN NaN], 'n_suppressed_messages', 0, ...
                'n_delivered', sum([sag(1); diff(sag)] > 0));
        end

        prof = build_nav_profile(case_def.name, T, case_def.dropout, dropout_params, seed);
        E = navigation_multirate_ekf_availability('run', B, cfga, struct('tag', case_def.name));
        G = navigation_multirate_ekf_availability('gates', E, cfga);
        M = navigation_multirate_ekf_availability('metrics', T, E, cfga, prof);

        assert_all_finite(M.rmse_pos_abs_norm, M.rmse_depth_m, M.rmse_yaw_deg, ...
            M.rmse_vel_norm, M.avail_pct, E.init_time);

        nav_metrics = flatten_nav_metrics(M, G, E, sched, case_def.dropout);
        assert_all_finite(nav_metrics);

        case_out = struct();
        case_out.name = case_def.name;
        case_out.seed = seed;
        case_out.route = nav_route;
        case_out.Vc_ned = Vc_ned;
        case_out.noise = noise_params;
        case_out.dropout = case_def.dropout;
        case_out.schedule = sched;
        case_out.metrics = nav_metrics;
        nav_results{ci} = case_out;

        nav_plot_data{ci} = struct( ...
            'name', case_def.name, ...
            't', T.t, ...
            'depth_err', abs(E.log.p(3, :) - T.eta_ned(:, 3)'), ...
            'pos_err_norm', sqrt(sum((E.log.p - T.eta_ned').^2, 1)), ...
            'health', E.avail.state, ...
            'dropout', case_def.dropout);
    end

    save_nav_summary_plot(artifact_dir, nav_plot_data, dropout_params);

    payload = struct();
    payload.certified = false;
    payload.scenario = scenario;
    payload.duration_s = duration_s;
    payload.seed = seed;
    payload.dt = dt;
    payload.nav_dt_base = cfgc.dt_base;
    payload.noise_params = noise_params;
    payload.dropout_params = dropout_params;
    payload.path_metrics = path_metric_values;
    payload.cases = [nav_results{:}];
    payload.note = ['Deterministic sensor-noise and short-dropout characterization only. ', ...
        'No hardware validation; ASSUMED sensor parameters; not certified.'];

    json_path = fullfile(artifact_dir, 'sensor_noise_dropout.json');
    fid = fopen(json_path, 'w');
    if fid < 0
        error('run_auv_v1_sensor_noise_dropout:WriteFailed', ...
            'Could not open %s for writing.', json_path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(payload, 'PrettyPrint', true));

    fprintf('Wrote %s (%d nav cases, path metrics included)\n', json_path, numel(nav_case_defs));
end

function cfg = apply_finite_noise(cfg, noise_params)
    for i = 1:numel(cfg.channels)
        switch cfg.channels(i).name
            case 'imu_gyro'
                cfg.channels(i).sigma = noise_params.imu_gyro_sigma_rad_s * noise_params.scale;
            case 'imu_accel'
                cfg.channels(i).sigma = noise_params.imu_accel_sigma_mps2 * noise_params.scale;
            case 'depth_pressure'
                cfg.channels(i).sigma = noise_params.depth_sigma_m * noise_params.scale;
        end
    end
end

function prof = build_nav_profile(name, T, dropout, dropout_params, seed)
    prof = struct();
    prof.label = name;
    prof.route = T.route;
    prof.profile = name;
    prof.seed = seed;
    prof.T_final = T.T_final;
    prof.dvl_gap = [NaN NaN];
    prof.hdg_gap = [NaN NaN];
    prof.usbl_present = false;
    prof.usbl_burst = [NaN NaN];
    prof.depth_gap = dropout.depth;
    prof.imu_gap = dropout.imu;
    prof.timing_bound_s = 0.010;
    if all(isfinite(dropout.depth))
        prof.desc = sprintf('short depth dropout [%.1f %.1f] s', dropout.depth(1), dropout.depth(2));
    elseif all(isfinite(dropout.imu))
        prof.desc = sprintf('short IMU dropout [%.1f %.1f] s', dropout.imu(1), dropout.imu(2));
    else
        prof.desc = 'declared finite IMU/depth noise, no dropout';
    end
    prof.usbl_cfg = struct();
    prof.dropout_params = dropout_params;
end

function [M, rec] = suppress_channel(M, t, win)
    s = M.seq(:);
    d = [s(1); diff(s)];
    rec = struct('window_s', win, 'n_suppressed_messages', 0, 'n_delivered', 0, ...
        'first_after_gap_t', NaN);
    if all(isfinite(win))
        in = t >= win(1) - 1e-12 & t <= win(2) + 1e-12;
        k0 = find(in, 1, 'first');
        if ~isempty(k0)
            hold_seq = s(max(k0 - 1, 1));
            hold_val = M.value(max(k0 - 1, 1), :);
            hold_ts = M.timestamp(max(k0 - 1, 1));
            rec.n_suppressed_messages = sum(d(in) > 0);
            s(in) = hold_seq;
            for k = find(in)'
                M.value(k, :) = hold_val;
                M.timestamp(k) = hold_ts;
                M.t_rx(k) = hold_ts;
                M.valid(k) = false;
                M.quality(k) = 0;
                M.stale_age(k) = t(k) - hold_ts;
                M.status(k) = 4;
            end
            M.seq = reshape(s, size(M.seq));
            ka = find(t > win(2) + 1e-12, 1, 'first');
            if ~isempty(ka)
                rec.first_after_gap_t = t(ka);
            end
        end
    end
    s2 = M.seq(:);
    rec.n_delivered = sum([s2(1); diff(s2)] > 0);
end

function flat = flatten_nav_metrics(M, G, E, sched, dropout)
    flat = struct();
    flat.rmse_pos_abs_norm_m = M.rmse_pos_abs_norm;
    flat.rmse_pos_rel_norm_m = M.rmse_pos_rel_norm;
    flat.rmse_depth_m = M.rmse_depth_m;
    flat.rmse_yaw_deg = M.rmse_yaw_deg;
    flat.rmse_vel_norm_mps = M.rmse_vel_norm;
    flat.max_pos_rel_norm_m = M.max_pos_rel_norm;
    flat.max_depth_err_m = M.max_depth_err_m;
    flat.avail_pct = M.avail_pct;
    flat.init_time_s = E.init_time;
    flat.n_fused_total = E.audit.n_fused_total;
    flat.integrity_pass = G.pass;
    flat.n_health_transitions = E.avail.n_transitions;
    if isfield(sched, 'depth')
        flat.depth_n_suppressed = sched.depth.n_suppressed_messages;
        flat.depth_n_delivered = sched.depth.n_delivered;
    end
    if isfield(sched, 'imu_gyro')
        flat.imu_n_suppressed = sched.imu_gyro.n_suppressed_messages;
        flat.imu_n_delivered = sched.imu_gyro.n_delivered;
    end
    if all(isfinite(dropout.depth))
        flat.dropout_window_s = dropout.depth;
    elseif all(isfinite(dropout.imu))
        flat.dropout_window_s = dropout.imu;
    end
end

function assert_all_finite(varargin)
    for k = 1:nargin
        x = varargin{k};
        if isstruct(x)
            vals = struct2cell(x);
            for j = 1:numel(vals)
                v = vals{j};
                if isnumeric(v) && any(~isfinite(v(:)))
                    error('run_auv_v1_sensor_noise_dropout:NonFinite', ...
                        'Non-finite numeric values in argument %d.', k);
                end
            end
        elseif isnumeric(x) && any(~isfinite(x(:)))
            error('run_auv_v1_sensor_noise_dropout:NonFinite', ...
                'Non-finite numeric values in argument %d.', k);
        end
    end
end

function flat = flatten_numeric_metrics(m)
    flat = struct();
    names = fieldnames(m);
    for i = 1:numel(names)
        key = names{i};
        val = m.(key);
        if isnumeric(val) && isscalar(val)
            flat.(key) = double(val);
        elseif isstruct(val) && isscalar(val)
            subnames = fieldnames(val);
            for j = 1:numel(subnames)
                subkey = subnames{j};
                subval = val.(subkey);
                if isnumeric(subval) && isscalar(subval)
                    flat.(sprintf('%s_%s', key, subkey)) = double(subval);
                end
            end
        end
    end
end

function save_sensor_plots(artifact_dir, case_name)
    figs = findall(0, 'Type', 'figure');
    figs = flipud(figs);
    plot_names = {'path_3d', 'path_2d_summary', 'motion_overview'};
    prefix = ['sensor_noise_dropout_' case_name '_'];
    for i = 1:numel(figs)
        if i <= numel(plot_names)
            base = plot_names{i};
        else
            base = sprintf('figure_%d', i);
        end
        out_png = fullfile(artifact_dir, [prefix base '.png']);
        if exist('exportgraphics', 'file') == 2
            exportgraphics(figs(i), out_png, 'Resolution', 150);
        else
            saveas(figs(i), out_png);
        end
    end
    close(figs);
end

function save_nav_summary_plot(artifact_dir, nav_plot_data, dropout_params)
    fig = figure('Visible', 'off', 'Position', [100 100 1100 700]);
    tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

    ax1 = nexttile;
    hold(ax1, 'on');
    colors = lines(numel(nav_plot_data));
    for i = 1:numel(nav_plot_data)
        d = nav_plot_data{i};
        plot(ax1, d.t, d.depth_err, 'Color', colors(i, :), 'LineWidth', 1.0, ...
            'DisplayName', strrep(d.name, '_', ' '));
    end
    yl1 = ylim(ax1);
    patch(ax1, [dropout_params.depth_window_s(1) dropout_params.depth_window_s(2) ...
        dropout_params.depth_window_s(2) dropout_params.depth_window_s(1)], ...
        [yl1(1) yl1(1) yl1(2) yl1(2)], [0.9 0.7 0.7], 'FaceAlpha', 0.15, ...
        'EdgeColor', 'none', 'DisplayName', 'depth dropout');
    ylabel(ax1, '|depth error| [m]');
    title(ax1, 'Navigation depth error (finite noise cases)');
    legend(ax1, 'Location', 'best');
    grid(ax1, 'on');
    hold(ax1, 'off');

    ax2 = nexttile;
    hold(ax2, 'on');
    for i = 1:numel(nav_plot_data)
        d = nav_plot_data{i};
        plot(ax2, d.t, d.pos_err_norm, 'Color', colors(i, :), 'LineWidth', 1.0, ...
            'DisplayName', strrep(d.name, '_', ' '));
    end
    yl2 = ylim(ax2);
    patch(ax2, [dropout_params.imu_window_s(1) dropout_params.imu_window_s(2) ...
        dropout_params.imu_window_s(2) dropout_params.imu_window_s(1)], ...
        [yl2(1) yl2(1) yl2(2) yl2(2)], [0.7 0.8 0.9], 'FaceAlpha', 0.15, ...
        'EdgeColor', 'none', 'DisplayName', 'IMU dropout');
    ylabel(ax2, '|position error| [m]');
    xlabel(ax2, 'time [s]');
    title(ax2, sprintf('Position error; short dropout windows depth [%.1f %.1f] IMU [%.1f %.1f] s', ...
        dropout_params.depth_window_s(1), dropout_params.depth_window_s(2), ...
        dropout_params.imu_window_s(1), dropout_params.imu_window_s(2)));
    legend(ax2, 'Location', 'best');
    grid(ax2, 'on');
    hold(ax2, 'off');

    out_png = fullfile(artifact_dir, 'sensor_noise_dropout_nav_summary.png');
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, out_png, 'Resolution', 150);
    else
        saveas(fig, out_png);
    end
    close(fig);
end
