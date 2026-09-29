function run_auv_v1_combined_robustness()
%RUN_AUV_V1_COMBINED_ROBUSTNESS  Bounded combined stress sweep and consolidation.
%   Consumes prior harness artifacts (nominal, bounded_current, sensor_noise_dropout,
%   actuator_limits), runs a capped deterministic matrix combining water current,
%   actuator limits, and navigation noise/dropout stresses. Rejects errors and
%   non-finite values. Writes artifacts/robustness/combined_summary.json and
%   summary plots. certified=false; no acceptance thresholds.

    t_start = tic;
    proj_root = pwd;
    addpath(proj_root);

    artifact_dir = fullfile(proj_root, 'artifacts', 'robustness');
    if ~exist(artifact_dir, 'dir')
        mkdir(artifact_dir);
    end

    scenario = 'combined_robustness_3d_straight_line';
    seed = 20260828;
    dt = 0.025;
    duration_s = 30.0;
    max_path_cases = 10;
    max_nav_cases = 3;
    max_runtime_s = 600.0;

    prior = load_prior_artifacts(artifact_dir);

    num_points = 120;
    path_length_m = 60.0;
    depth_m = 5.0;
    path = [linspace(0, path_length_m, num_points)', zeros(num_points, 1), ...
        -depth_m * ones(num_points, 1)];

    path_matrix = build_bounded_path_matrix(prior, max_path_cases);
    nav_matrix = build_bounded_nav_matrix(prior, max_nav_cases);

    init_parameters();
    global desired_speed plant_Vc lambda_muw_ff
    lambda_muw_ff = 0.25;

    path_results = cell(1, numel(path_matrix));
    failing_executions = {};
    n_path_ok = 0;

    for ci = 1:numel(path_matrix)
        if toc(t_start) > max_runtime_s
            failing_executions{end + 1} = struct( ...
                'case_id', path_matrix{ci}.case_id, ...
                'domain', 'path', ...
                'reason', sprintf('runtime_cap_exceeded_before_case_%d', ci)); %#ok<AGROW>
            break;
        end

        case_def = path_matrix{ci};
        rng(seed, 'twister');

        state = zeros(12, 1);
        state(1:3) = [0; 0; -depth_m];
        d = path(2, :) - path(1, :);
        state(5) = -atan2(d(3), norm(d(1:2)));
        state(6) = atan2(d(2), d(1));
        state(7) = desired_speed;

        plant_Vc = case_def.Vc_ned(:);

        entry = struct();
        entry.case_id = case_def.case_id;
        entry.current_name = case_def.current_name;
        entry.actuator_name = case_def.actuator_name;
        entry.Vc_ned = plant_Vc(:)';
        entry.actuator_cfg = case_def.actuator_cfg;
        entry.seed = seed;

        try
            out = closed_loop_actuator_realism_case(path, state, dt, duration_s, ...
                desired_speed, case_def.actuator_cfg);

            if ~isempty(out.error)
                error('run_auv_v1_combined_robustness:CaseError', '%s', out.error);
            end
            if ~out.complete
                error('run_auv_v1_combined_robustness:Incomplete', ...
                    'Incomplete (%d/%d steps).', nnz(isfinite(out.position(:, 1))), numel(out.t));
            end

            expected_steps = round(duration_s / dt);
            if size(out.position, 1) < expected_steps
                error('run_auv_v1_combined_robustness:EarlyTermination', ...
                    'Early termination (%d/%d steps).', size(out.position, 1), expected_steps);
            end

            assert_all_finite(out.position, out.velocity, out.attitude, out.rates, ...
                out.reference, out.command, out.applied);

            actuator_metrics = compute_actuator_metrics_local(out, dt, prior.actuator.limits, ...
                case_def.actuator_cfg);
            assert_all_finite(actuator_metrics);

            path_metrics = compute_path_following_metrics(path, out.position, out.velocity, ...
                out.attitude, out.reference(:, 2), out.reference(:, 1), dt, out.t);
            path_metrics_flat = flatten_numeric_metrics(path_metrics);
            assert_all_finite(path_metrics_flat);

            entry.status = 'ok';
            entry.actuator_metrics = actuator_metrics;
            entry.path_metrics = path_metrics_flat;
            n_path_ok = n_path_ok + 1;
        catch ME
            entry.status = 'failed';
            entry.error = ME.message;
            failing_executions{end + 1} = struct( ...
                'case_id', case_def.case_id, ...
                'domain', 'path', ...
                'reason', ME.message); %#ok<AGROW>
        end

        path_results{ci} = entry;

        if toc(t_start) > max_runtime_s
            for sj = ci + 1:numel(path_matrix)
                failing_executions{end + 1} = struct( ...
                    'case_id', path_matrix{sj}.case_id, ...
                    'domain', 'path', ...
                    'reason', sprintf('runtime_cap_exceeded_before_case_%d', sj)); %#ok<AGROW>
            end
            break;
        end
    end

    nav_results = cell(1, numel(nav_matrix));
    n_nav_ok = 0;

    if toc(t_start) > max_runtime_s
        for ni = 1:numel(nav_matrix)
            failing_executions{end + 1} = struct( ...
                'case_id', nav_matrix{ni}.case_id, ...
                'domain', 'nav', ...
                'reason', 'runtime_cap_exceeded_before_nav_block'); %#ok<AGROW>
        end
    elseif toc(t_start) <= max_runtime_s
        rng(seed, 'twister');
        cfgc = navigation_multirate_sensor_chain('config');
        cfga = navigation_multirate_ekf_availability('config');
        cfgc = normalize_sensor_chain_cfg_local(cfgc);
        cfgc = apply_finite_noise_local(cfgc, prior.sensor.noise_params);
        nav_route = 'X';
        Vc_ned = normalize_finite_row3([0, 0, 0], 'Vc_ned');

        T = navigation_multirate_sensor_chain('truth', nav_route, Vc_ned, cfgc, ...
            struct('dvl_outage', false, 'label', 'combined_robustness_X'));
        cfgc = normalize_sensor_chain_cfg_local(cfgc);
        B0 = navigation_multirate_sensor_chain('run', T, cfgc, seed);

        for ni = 1:numel(nav_matrix)
            if toc(t_start) > max_runtime_s
                failing_executions{end + 1} = struct( ...
                    'case_id', nav_matrix{ni}.case_id, ...
                    'domain', 'nav', ...
                    'reason', sprintf('runtime_cap_exceeded_before_nav_case_%d', ni)); %#ok<AGROW>
                break;
            end

            nav_def = nav_matrix{ni};
            entry = struct();
            entry.case_id = nav_def.case_id;
            entry.name = nav_def.name;
            entry.seed = seed;
            entry.route = nav_route;
            entry.Vc_ned = Vc_ned;
            entry.noise = prior.sensor.noise_params;
            entry.dropout = nav_def.dropout;

            try
                B = B0;
                sched = struct('depth_window_s', nav_def.dropout.depth, ...
                    'imu_window_s', nav_def.dropout.imu);

                if all(isfinite(nav_def.dropout.depth))
                    [B.meas.depth_pressure, sched.depth] = suppress_channel_local( ...
                        B.meas.depth_pressure, B.t, nav_def.dropout.depth);
                else
                    sched.depth = struct('window_s', [NaN NaN], 'n_suppressed_messages', 0, ...
                        'n_delivered', sum([B.meas.depth_pressure.seq(1); ...
                        diff(B.meas.depth_pressure.seq(:))] > 0));
                end

                if all(isfinite(nav_def.dropout.imu))
                    [B.meas.imu_gyro, sched.imu_gyro] = suppress_channel_local( ...
                        B.meas.imu_gyro, B.t, nav_def.dropout.imu);
                    [B.meas.imu_accel, sched.imu_accel] = suppress_channel_local( ...
                        B.meas.imu_accel, B.t, nav_def.dropout.imu);
                else
                    sgy = B.meas.imu_gyro.seq(:);
                    sag = B.meas.imu_accel.seq(:);
                    sched.imu_gyro = struct('window_s', [NaN NaN], 'n_suppressed_messages', 0, ...
                        'n_delivered', sum([sgy(1); diff(sgy)] > 0));
                    sched.imu_accel = struct('window_s', [NaN NaN], 'n_suppressed_messages', 0, ...
                        'n_delivered', sum([sag(1); diff(sag)] > 0));
                end

                prof = build_nav_profile_local(nav_def.name, T, nav_def.dropout, ...
                    prior.sensor.dropout_params, seed);
                E = navigation_multirate_ekf_availability('run', B, cfga, struct('tag', nav_def.name));
                G = navigation_multirate_ekf_availability('gates', E, cfga);
                M = navigation_multirate_ekf_availability('metrics', T, E, cfga, prof);

                assert_all_finite(M.rmse_pos_abs_norm, M.rmse_depth_m, M.rmse_yaw_deg, ...
                    M.rmse_vel_norm, M.avail_pct, E.init_time);

                nav_metrics = flatten_nav_metrics_local(M, G, E, sched, nav_def.dropout);
                assert_all_finite(nav_metrics);

                entry.status = 'ok';
                entry.schedule = sched;
                entry.metrics = nav_metrics;
                n_nav_ok = n_nav_ok + 1;
            catch ME
                entry.status = 'failed';
                entry.error = ME.message;
                failing_executions{end + 1} = struct( ...
                    'case_id', nav_def.case_id, ...
                    'domain', 'nav', ...
                    'reason', ME.message); %#ok<AGROW>
            end

            nav_results{ni} = entry;
        end
    end

    runtime_s = toc(t_start);
    path_cases_ok = {};
    for pi = 1:numel(path_results)
        if ~isempty(path_results{pi}) && isfield(path_results{pi}, 'status') && ...
                strcmp(path_results{pi}.status, 'ok')
            path_cases_ok{end + 1} = path_results{pi}; %#ok<AGROW>
        end
    end
    nav_cases_ok = {};
    for ni = 1:numel(nav_results)
        if ~isempty(nav_results{ni}) && isfield(nav_results{ni}, 'status') && ...
                strcmp(nav_results{ni}.status, 'ok')
            nav_cases_ok{end + 1} = nav_results{ni}; %#ok<AGROW>
        end
    end

    worst_case = compute_worst_case_metrics(path_cases_ok, nav_cases_ok, prior);

    if ~isempty(failing_executions)
        reasons = cell(1, numel(failing_executions));
        for fi = 1:numel(failing_executions)
            reasons{fi} = sprintf('%s (%s): %s', failing_executions{fi}.case_id, ...
                failing_executions{fi}.domain, failing_executions{fi}.reason);
        end
        error('run_auv_v1_combined_robustness:FailedExecutions', ...
            '%d combined case execution(s) failed: %s', numel(failing_executions), ...
            strjoin(reasons, '; '));
    end

    for pi = 1:numel(path_results)
        if ~isempty(path_results{pi}) && isfield(path_results{pi}, 'status') && ...
                strcmp(path_results{pi}.status, 'failed')
            error('run_auv_v1_combined_robustness:FailedCase', ...
                'Path case %s failed.', path_results{pi}.case_id);
        end
    end
    for ni = 1:numel(nav_results)
        if ~isempty(nav_results{ni}) && isfield(nav_results{ni}, 'status') && ...
                strcmp(nav_results{ni}.status, 'failed')
            error('run_auv_v1_combined_robustness:FailedCase', ...
                'Nav case %s failed.', nav_results{ni}.case_id);
        end
    end

    save_combined_summary_plots(artifact_dir, path_cases_ok, nav_cases_ok, prior);

    payload = struct();
    payload.certified = false;
    payload.scenario = scenario;
    payload.duration_s = duration_s;
    payload.seed = seed;
    payload.dt = dt;
    payload.runtime_s = runtime_s;
    payload.matrix_caps = struct( ...
        'max_path_cases', max_path_cases, ...
        'max_nav_cases', max_nav_cases, ...
        'max_runtime_s', max_runtime_s, ...
        'n_path_cases_scheduled', numel(path_matrix), ...
        'n_nav_cases_scheduled', numel(nav_matrix), ...
        'n_path_cases_ok', n_path_ok, ...
        'n_nav_cases_ok', n_nav_ok);
    payload.parameters = struct( ...
        'current', prior.current, ...
        'actuator_limits', prior.actuator.limits, ...
        'actuator_provisional', prior.actuator.provisional, ...
        'noise_params', prior.sensor.noise_params, ...
        'dropout_params', prior.sensor.dropout_params);
    payload.prior_artifacts = prior.sources;
    payload.nominal_metrics = prior.nominal.metrics;
    payload.path_cases = concat_nonempty_cells(path_results);
    payload.nav_cases = concat_nonempty_cells(nav_results);
    payload.worst_case = worst_case;
    payload.failing_executions = [failing_executions{:}];
    payload.note = ['Bounded combined stress sweep for human threshold review only. ', ...
        'certified=false; no acceptance thresholds; laws not tuned.'];

    json_path = fullfile(artifact_dir, 'combined_summary.json');
    fid = fopen(json_path, 'w');
    if fid < 0
        error('run_auv_v1_combined_robustness:WriteFailed', ...
            'Could not open %s for writing.', json_path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(payload, 'PrettyPrint', true));

    fprintf('Wrote %s (%d path ok, %d nav ok, %d failures, %.1f s)\n', ...
        json_path, n_path_ok, n_nav_ok, numel(failing_executions), runtime_s);
end

function out = concat_nonempty_cells(cells_in)
    items = {};
    for i = 1:numel(cells_in)
        if ~isempty(cells_in{i})
            items{end + 1} = cells_in{i}; %#ok<AGROW>
        end
    end
    if isempty(items)
        out = struct([]);
        return;
    end

    all_fields = {};
    for i = 1:numel(items)
        all_fields = union(all_fields, fieldnames(items{i}), 'stable');
    end

    for i = 1:numel(items)
        for j = 1:numel(all_fields)
            f = all_fields{j};
            if ~isfield(items{i}, f)
                items{i}.(f) = empty_field_value_local(items, f);
            end
        end
    end

    out = [items{:}];
end

function empty_val = empty_field_value_local(items, field)
    for i = 1:numel(items)
        if isfield(items{i}, field)
            ref = items{i}.(field);
            if ischar(ref)
                empty_val = '';
                return;
            end
            if isstring(ref)
                empty_val = "";
                return;
            end
            if isstruct(ref)
                empty_val = struct([]);
                return;
            end
            if islogical(ref)
                empty_val = false;
                return;
            end
            if isnumeric(ref)
                empty_val = [];
                return;
            end
            if iscell(ref)
                empty_val = {};
                return;
            end
        end
    end
    empty_val = [];
end

function prior = load_prior_artifacts(artifact_dir)
    sources = {
        fullfile(artifact_dir, 'nominal.json')
        fullfile(artifact_dir, 'bounded_current.json')
        fullfile(artifact_dir, 'sensor_noise_dropout.json')
        fullfile(artifact_dir, 'actuator_limits.json')
    };

    for i = 1:numel(sources)
        if ~isfile(sources{i})
            error('run_auv_v1_combined_robustness:MissingArtifact', ...
                'Required prior artifact missing: %s', sources{i});
        end
    end

    nominal = jsondecode(fileread(sources{1}));
    bounded = jsondecode(fileread(sources{2}));
    sensor = jsondecode(fileread(sources{3}));
    actuator = jsondecode(fileread(sources{4}));

    prior = struct();
    prior.sources = sources;
    prior.nominal = nominal;
    prior.bounded = bounded;
    prior.sensor = sensor;
    prior.actuator = actuator;
    prior.sensor.noise_params = normalize_noise_params_local(prior.sensor.noise_params);

    current_levels = struct('name', {}, 'Vc_ned', {});
    for i = 1:numel(bounded.cases)
        current_levels(i).name = bounded.cases(i).name; %#ok<AGROW>
        current_levels(i).Vc_ned = bounded.cases(i).Vc_ned(:)';
    end
    prior.current = current_levels;

    actuator_cfgs = struct('name', {}, 'cfg', {});
    for i = 1:numel(actuator.cases)
        actuator_cfgs(i).name = actuator.cases(i).name; %#ok<AGROW>
        actuator_cfgs(i).cfg = actuator.cases(i).cfg;
    end
    prior.actuator_cfgs = actuator_cfgs;
end

function path_matrix = build_bounded_path_matrix(prior, max_path_cases)
    current_names = {'zero', 'cross_current', 'oblique_current'};
    actuator_names = {'ideal', 'saturation', 'deadband', 'rate_limit'};

    path_matrix = {};
    case_id = 0;

    for ai = 1:numel(actuator_names)
        aname = actuator_names{ai};
        acfg = find_actuator_cfg(prior.actuator_cfgs, aname);
        for ci = 1:numel(current_names)
            cname = current_names{ci};
            clevel = find_current_level(prior.current, cname);
            case_id = case_id + 1;
            if case_id > max_path_cases
                return;
            end
            entry = struct();
            entry.case_id = sprintf('path_%s_%s', cname, aname);
            entry.current_name = cname;
            entry.actuator_name = aname;
            entry.Vc_ned = clevel.Vc_ned;
            entry.actuator_cfg = acfg;
            path_matrix{end + 1} = entry; %#ok<AGROW>
        end
    end
end

function nav_matrix = build_bounded_nav_matrix(prior, max_nav_cases)
    nav_names = {'declared_finite_noise', 'short_depth_dropout', 'short_imu_dropout'};
    nav_matrix = {};

    for i = 1:min(numel(nav_names), max_nav_cases)
        name = nav_names{i};
        src = find_nav_case(prior.sensor.cases, name);
        entry = struct();
        entry.case_id = sprintf('nav_%s', name);
        entry.name = name;
        entry.dropout = src.dropout;
        nav_matrix{end + 1} = entry; %#ok<AGROW>
    end
end

function cfg = find_actuator_cfg(cfgs, name)
    for i = 1:numel(cfgs)
        if strcmp(cfgs(i).name, name)
            cfg = cfgs(i).cfg;
            return;
        end
    end
    error('run_auv_v1_combined_robustness:UnknownActuator', 'Actuator case "%s" not found.', name);
end

function level = find_current_level(levels, name)
    for i = 1:numel(levels)
        if strcmp(levels(i).name, name)
            level = levels(i);
            return;
        end
    end
    error('run_auv_v1_combined_robustness:UnknownCurrent', 'Current case "%s" not found.', name);
end

function src = find_nav_case(cases, name)
    for i = 1:numel(cases)
        if strcmp(cases(i).name, name)
            src = cases(i);
            return;
        end
    end
    error('run_auv_v1_combined_robustness:UnknownNav', 'Nav case "%s" not found.', name);
end

function worst = compute_worst_case_metrics(path_cases_ok, nav_cases_ok, prior)
    worst = struct();
    worst.note = 'Descriptive maxima across successful combined cases; not pass/fail gates.';

    path_keys = {'mean_cte_perp', 'max_cte_perp', 'mean_yaw_err_deg', 'pitch_chatter_dps', ...
        'elevator_mag_sat_pct', 'rudder_mag_sat_pct', 'elevator_cmd_rmse_deg'};
    for ki = 1:numel(path_keys)
        key = path_keys{ki};
        best_val = -inf;
        best_case = '';
        for i = 1:numel(path_cases_ok)
            c = path_cases_ok{i};
            if isfield(c.path_metrics, key)
                val = c.path_metrics.(key);
            elseif isfield(c.actuator_metrics, key)
                val = c.actuator_metrics.(key);
            else
                continue;
            end
            if val > best_val
                best_val = val;
                best_case = c.case_id;
            end
        end
        if isfinite(best_val)
            worst.(key) = struct('value', best_val, 'case_id', best_case);
        end
    end

    if isfield(prior.nominal, 'metrics')
        worst.nominal_mean_cte_perp = prior.nominal.metrics.mean_cte_perp;
    end

    nav_keys = {'rmse_pos_abs_norm_m', 'rmse_depth_m', 'rmse_yaw_deg', 'max_pos_rel_norm_m'};
    for ki = 1:numel(nav_keys)
        key = nav_keys{ki};
        best_val = -inf;
        best_case = '';
        for i = 1:numel(nav_cases_ok)
            c = nav_cases_ok{i};
            if isfield(c.metrics, key)
                val = c.metrics.(key);
                if val > best_val
                    best_val = val;
                    best_case = c.case_id;
                end
            end
        end
        if isfinite(best_val)
            worst.(['nav_' key]) = struct('value', best_val, 'case_id', best_case);
        end
    end
end

function save_combined_summary_plots(artifact_dir, path_cases_ok, nav_cases_ok, prior)
    fig = figure('Visible', 'off', 'Position', [80 80 1200 900]);
    tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    ax1 = nexttile;
    labels = {};
    if ~isempty(path_cases_ok)
        labels = cell(1, numel(path_cases_ok));
        cte_vals = zeros(1, numel(path_cases_ok));
        for i = 1:numel(path_cases_ok)
            labels{i} = strrep(path_cases_ok{i}.case_id, 'path_', '');
            cte_vals(i) = path_cases_ok{i}.path_metrics.mean_cte_perp;
        end
        bar(ax1, cte_vals, 'FaceColor', [0.2 0.45 0.75]);
        xticks(ax1, 1:numel(labels));
        xticklabels(ax1, labels);
        xtickangle(ax1, 45);
        hold(ax1, 'on');
        if isfield(prior.nominal, 'metrics')
            yline(ax1, prior.nominal.metrics.mean_cte_perp, 'r--', 'LineWidth', 1.2, ...
                'DisplayName', 'nominal baseline');
        end
        ylabel(ax1, 'mean CTE_{perp} [m]');
        title(ax1, 'Path tracking: settled-before-end CTE');
        grid(ax1, 'on');
    end

    ax2 = nexttile;
    if ~isempty(path_cases_ok) && ~isempty(labels)
        max_cte = zeros(1, numel(path_cases_ok));
        for i = 1:numel(path_cases_ok)
            max_cte(i) = path_cases_ok{i}.path_metrics.max_cte_perp;
        end
        bar(ax2, max_cte, 'FaceColor', [0.85 0.45 0.2]);
        xticks(ax2, 1:numel(labels));
        xticklabels(ax2, labels);
        xtickangle(ax2, 45);
        ylabel(ax2, 'max CTE_{perp} [m]');
        title(ax2, 'Path tracking: max settled-before-end CTE');
        grid(ax2, 'on');
    end

    ax3 = nexttile;
    if ~isempty(nav_cases_ok)
        nav_labels = cell(1, numel(nav_cases_ok));
        rmse_pos = zeros(1, numel(nav_cases_ok));
        for i = 1:numel(nav_cases_ok)
            nav_labels{i} = strrep(nav_cases_ok{i}.case_id, 'nav_', '');
            rmse_pos(i) = nav_cases_ok{i}.metrics.rmse_pos_abs_norm_m;
        end
        bar(ax3, rmse_pos, 'FaceColor', [0.35 0.65 0.45]);
        xticks(ax3, 1:numel(nav_labels));
        xticklabels(ax3, nav_labels);
        xtickangle(ax3, 30);
        ylabel(ax3, 'RMSE |pos| [m]');
        title(ax3, 'Navigation position RMSE');
        grid(ax3, 'on');
    end

    ax4 = nexttile;
    if ~isempty(nav_cases_ok)
        max_pos = zeros(1, numel(nav_cases_ok));
        for i = 1:numel(nav_cases_ok)
            max_pos(i) = nav_cases_ok{i}.metrics.max_pos_rel_norm_m;
        end
        bar(ax4, max_pos, 'FaceColor', [0.55 0.35 0.65]);
        xticks(ax4, 1:numel(nav_labels));
        xticklabels(ax4, nav_labels);
        xtickangle(ax4, 30);
        ylabel(ax4, 'max |pos err| [m]');
        title(ax4, 'Navigation max relative position error');
        grid(ax4, 'on');
    end

    sgtitle(fig, 'Combined robustness sweep (certified=false)', 'FontWeight', 'bold');

    out_png = fullfile(artifact_dir, 'combined_summary.png');
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, out_png, 'Resolution', 150);
    else
        saveas(fig, out_png);
    end
    close(fig);
end

function am = compute_actuator_metrics_local(out, dt, limits, cfg)
    t = out.t(:);
    n = numel(t);
    de_cmd = out.command(:, 1);
    dr_cmd = out.command(:, 2);
    de_applied = out.applied(:, 1);
    dr_applied = out.applied(:, 2);

    de_max = deg2rad(limits.de_max_deg);
    dr_max = deg2rad(limits.dr_max_deg);
    rate_max = deg2rad(limits.rate_dps);
    sat_frac = limits.sat_frac;

    settle_mask = t >= 5.0;
    if ~any(settle_mask)
        settle_mask = true(n, 1);
    end

    de_mag_sat = abs(de_applied) >= sat_frac * de_max;
    dr_mag_sat = abs(dr_applied) >= sat_frac * dr_max;
    any_mag_sat = de_mag_sat | dr_mag_sat;

    de_rate = [0; diff(de_applied)] / dt;
    dr_rate = [0; diff(dr_applied)] / dt;
    de_rate_sat = abs(de_rate) >= sat_frac * rate_max;
    dr_rate_sat = abs(dr_rate) >= sat_frac * rate_max;

    deadband_rad = deg2rad(cfg.deadband_deg);
    if deadband_rad > 0
        de_db_reject = (abs(de_cmd) > 0) & (abs(de_cmd) < deadband_rad) & (abs(de_applied) < 1e-8);
        dr_db_reject = (abs(dr_cmd) > 0) & (abs(dr_cmd) < deadband_rad) & (abs(dr_applied) < 1e-8);
    else
        de_db_reject = false(n, 1);
        dr_db_reject = false(n, 1);
    end

    am = struct();
    am.elevator_mag_sat_pct = 100 * mean(de_mag_sat(settle_mask));
    am.rudder_mag_sat_pct = 100 * mean(dr_mag_sat(settle_mask));
    am.elevator_rate_dwell_pct = 100 * mean(de_rate_sat(settle_mask));
    am.rudder_rate_dwell_pct = 100 * mean(dr_rate_sat(settle_mask));
    am.elevator_deadband_reject_pct = 100 * mean(de_db_reject(settle_mask));
    am.rudder_deadband_reject_pct = 100 * mean(dr_db_reject(settle_mask));

    if any(any_mag_sat)
        am.first_mag_sat_time_s = t(find(any_mag_sat, 1, 'first'));
        am.total_mag_sat_time_s = nnz(any_mag_sat) * dt;
    else
        am.first_mag_sat_time_s = -1.0;
        am.total_mag_sat_time_s = 0;
    end

    am.elevator_cmd_rmse_deg = rad2deg(rms(de_applied(settle_mask) - de_cmd(settle_mask)));
    am.rudder_cmd_rmse_deg = rad2deg(rms(dr_applied(settle_mask) - dr_cmd(settle_mask)));
end

function np = normalize_noise_params_local(np)
    np.imu_gyro_sigma_rad_s = normalize_finite_row3( ...
        np.imu_gyro_sigma_rad_s, 'noise_params.imu_gyro_sigma_rad_s');
    np.imu_accel_sigma_mps2 = normalize_finite_row3( ...
        np.imu_accel_sigma_mps2, 'noise_params.imu_accel_sigma_mps2');
    depth_sigma = double(np.depth_sigma_m);
    if ~isscalar(depth_sigma) || ~isfinite(depth_sigma)
        error('run_auv_v1_combined_robustness:InvalidDepthSigma', ...
            'noise_params.depth_sigma_m must be a finite scalar.');
    end
    np.depth_sigma_m = depth_sigma;
end

function cfg = normalize_sensor_chain_cfg_local(cfg)
    for i = 1:numel(cfg.channels)
        ch = cfg.channels(i);
        if isfield(ch, 'sigma') && isnumeric(ch.sigma) && numel(ch.sigma) == 3
            cfg.channels(i).sigma = normalize_finite_row3(ch.sigma, ...
                sprintf('cfg.channels(%d).sigma', i));
        end
        if isfield(ch, 'bias') && isnumeric(ch.bias) && numel(ch.bias) == 3
            cfg.channels(i).bias = normalize_finite_row3(ch.bias, ...
                sprintf('cfg.channels(%d).bias', i));
        end
        if isfield(ch, 'offset') && isnumeric(ch.offset) && numel(ch.offset) == 3
            cfg.channels(i).offset = normalize_finite_row3(ch.offset, ...
                sprintf('cfg.channels(%d).offset', i));
        end
    end
end

function row = normalize_finite_row3(x, name)
    v = double(x(:)');
    if numel(v) ~= 3
        error('run_auv_v1_combined_robustness:InvalidRow3', ...
            '%s must have exactly 3 elements (got %d).', name, numel(v));
    end
    if any(~isfinite(v))
        error('run_auv_v1_combined_robustness:NonFiniteRow3', ...
            '%s must be finite.', name);
    end
    row = v;
end

function cfg = apply_finite_noise_local(cfg, noise_params)
    noise_params = normalize_noise_params_local(noise_params);
    gyro_sigma = noise_params.imu_gyro_sigma_rad_s * noise_params.scale;
    accel_sigma = noise_params.imu_accel_sigma_mps2 * noise_params.scale;
    depth_sigma = noise_params.depth_sigma_m * noise_params.scale;
    for i = 1:numel(cfg.channels)
        switch cfg.channels(i).name
            case 'imu_gyro'
                cfg.channels(i).sigma = normalize_finite_row3(gyro_sigma, 'imu_gyro_sigma');
            case 'imu_accel'
                cfg.channels(i).sigma = normalize_finite_row3(accel_sigma, 'imu_accel_sigma');
            case 'depth_pressure'
                if ~isscalar(depth_sigma) || ~isfinite(depth_sigma)
                    error('run_auv_v1_combined_robustness:InvalidDepthSigma', ...
                        'depth_pressure sigma must be a finite scalar.');
                end
                cfg.channels(i).sigma = depth_sigma;
        end
    end
    cfg = normalize_sensor_chain_cfg_local(cfg);
end

function prof = build_nav_profile_local(name, T, dropout, dropout_params, seed)
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
    prof.usbl_cfg = struct();
    prof.dropout_params = dropout_params;
end

function hold_val = extract_hold_value_local(M, idx)
    row = M.value(idx, :);
    if size(row, 2) == 1
        hold_val = double(row(1));
        if ~isfinite(hold_val)
            error('run_auv_v1_combined_robustness:InvalidHoldScalar', ...
                'suppress_channel.hold_val must be a finite scalar.');
        end
        return;
    end
    hold_val = normalize_finite_row3(row, 'suppress_channel.hold_val');
end

function [M, rec] = suppress_channel_local(M, t, win)
    s = M.seq(:);
    d = [s(1); diff(s)];
    rec = struct('window_s', win, 'n_suppressed_messages', 0, 'n_delivered', 0, ...
        'first_after_gap_t', NaN);
    if all(isfinite(win))
        in = t >= win(1) - 1e-12 & t <= win(2) + 1e-12;
        k0 = find(in, 1, 'first');
        if ~isempty(k0)
            hold_idx = max(k0 - 1, 1);
            hold_seq = s(hold_idx);
            hold_val = extract_hold_value_local(M, hold_idx);
            hold_ts = M.timestamp(hold_idx);
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

function flat = flatten_nav_metrics_local(M, G, E, sched, dropout)
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
                    error('run_auv_v1_combined_robustness:NonFinite', ...
                        'Non-finite numeric values in argument %d.', k);
                end
            end
        elseif isnumeric(x) && any(~isfinite(x(:)))
            error('run_auv_v1_combined_robustness:NonFinite', ...
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
