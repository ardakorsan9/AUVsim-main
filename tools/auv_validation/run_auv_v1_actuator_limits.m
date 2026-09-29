function run_auv_v1_actuator_limits()
%RUN_AUV_V1_ACTUATOR_LIMITS  Deterministic actuator limit stress harness.
%   Reuses the nominal straight-line setup and closed_loop_actuator_realism_case.
%   Runs ideal, saturation, rate-limit and deadband cases with provisional cfg
%   values (certified=false). Rejects errors and non-finite outputs; writes
%   artifacts/robustness/actuator_limits.json and summary plots.

    proj_root = pwd;
    addpath(genpath(fullfile(proj_root, 'matlab')));

    artifact_dir = fullfile(proj_root, 'artifacts', 'robustness');
    if ~exist(artifact_dir, 'dir')
        mkdir(artifact_dir);
    end

    scenario = 'actuator_limits_3d_straight_line';
    seed = 20260828;
    dt = 0.025;
    duration_s = 30.0;

    rng(seed, 'twister');

    init_parameters();
    global desired_speed

    num_points = 120;
    path_length_m = 60.0;
    depth_m = 5.0;
    path = [linspace(0, path_length_m, num_points)', zeros(num_points, 1), -depth_m * ones(num_points, 1)];

    state = zeros(12, 1);
    state(1:3) = [0; 0; -depth_m];
    state(7) = desired_speed;

    limits = struct( ...
        'de_max_deg', 15, ...
        'dr_max_deg', 25, ...
        'rate_dps', 40, ...
        'sat_frac', 0.98, ...
        'note', 'FIXED magnitude/rate limits from pack/ICD; sat_frac ASSUMED dwell threshold.');

    provisional = struct( ...
        'tau_s', 0.10, ...
        'delay_s', 0.0, ...
        'jitter_s', 0.0, ...
        'deadband_deg', 0.50, ...
        'note', 'ASSUMED provisional servo/deadband values; not hardware certified.');

    case_defs = {
        struct('name', 'ideal', 'cfg', struct( ...
            'ideal', true, 'tau_s', 0.0, 'delay_s', 0.0, 'jitter_s', 0.0, 'deadband_deg', 0.0))
        struct('name', 'saturation', 'cfg', struct( ...
            'ideal', false, 'tau_s', provisional.tau_s, 'delay_s', provisional.delay_s, ...
            'jitter_s', provisional.jitter_s, 'deadband_deg', 0.0))
        struct('name', 'rate_limit', 'cfg', struct( ...
            'ideal', false, 'tau_s', 0.01, 'delay_s', 0.0, 'jitter_s', 0.0, 'deadband_deg', 0.0))
        struct('name', 'deadband', 'cfg', struct( ...
            'ideal', false, 'tau_s', provisional.tau_s, 'delay_s', provisional.delay_s, ...
            'jitter_s', provisional.jitter_s, 'deadband_deg', provisional.deadband_deg))
    };

    case_results = cell(1, numel(case_defs));
    plot_handles = gobjects(0);

    for ic = 1:numel(case_defs)
        cdef = case_defs{ic};
        try
            out = closed_loop_actuator_realism_case(path, state, dt, duration_s, desired_speed, cdef.cfg);
        catch ME
            error('run_auv_v1_actuator_limits:SimulationFailed', ...
                'closed_loop_actuator_realism_case failed for case %s: %s', cdef.name, ME.message);
        end

        if ~isempty(out.error)
            error('run_auv_v1_actuator_limits:CaseError', ...
                'Case %s reported error: %s', cdef.name, out.error);
        end
        if ~out.complete
            error('run_auv_v1_actuator_limits:Incomplete', ...
                'Case %s did not complete (%d/%d steps).', cdef.name, ...
                nnz(isfinite(out.position(:, 1))), numel(out.t));
        end

        expected_steps = round(duration_s / dt);
        if size(out.position, 1) < expected_steps
            error('run_auv_v1_actuator_limits:EarlyTermination', ...
                'Case %s ended early (%d/%d steps).', cdef.name, size(out.position, 1), expected_steps);
        end

        assert_all_finite(out.position, out.velocity, out.attitude, out.rates, ...
            out.reference, out.command, out.allocated, out.applied);

        actuator_metrics = compute_actuator_metrics(out, dt, limits, cdef.cfg);
        assert_all_finite(actuator_metrics);

        path_metrics = compute_path_following_metrics(path, out.position, out.velocity, out.attitude, ...
            out.reference(:, 2), out.reference(:, 1), dt, out.t);
        path_metrics_flat = flatten_numeric_metrics(path_metrics);
        assert_all_finite(path_metrics_flat);

        entry = struct();
        entry.name = cdef.name;
        entry.cfg = cdef.cfg;
        entry.actuator_metrics = actuator_metrics;
        entry.path_metrics = path_metrics_flat;
        case_results{ic} = entry;

        fig = make_case_plot(out, limits, cdef.name, dt);
        plot_handles(end + 1) = fig; %#ok<AGROW>
    end

    save_actuator_limit_plots(artifact_dir, plot_handles, case_defs);

    payload = struct();
    payload.certified = false;
    payload.scenario = scenario;
    payload.duration_s = duration_s;
    payload.seed = seed;
    payload.dt = dt;
    payload.limits = limits;
    payload.provisional = provisional;
    payload.cases = [case_results{:}];

    json_path = fullfile(artifact_dir, 'actuator_limits.json');
    fid = fopen(json_path, 'w');
    if fid < 0
        error('run_auv_v1_actuator_limits:WriteFailed', 'Could not open %s for writing.', json_path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(payload, 'PrettyPrint', true));

    fprintf('Wrote %s (%d cases)\n', json_path, numel(case_results));
end

function am = compute_actuator_metrics(out, dt, limits, cfg)
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
        am.elevator_mag_sat_time_s = nnz(de_mag_sat) * dt;
        am.rudder_mag_sat_time_s = nnz(dr_mag_sat) * dt;
    else
        am.first_mag_sat_time_s = -1.0;
        am.total_mag_sat_time_s = 0;
        am.elevator_mag_sat_time_s = 0;
        am.rudder_mag_sat_time_s = 0;
    end

    am.elevator_cmd_rmse_deg = rad2deg(rms(de_applied(settle_mask) - de_cmd(settle_mask)));
    am.rudder_cmd_rmse_deg = rad2deg(rms(dr_applied(settle_mask) - dr_cmd(settle_mask)));
end

function fig = make_case_plot(out, limits, case_name, dt)
    t = out.t;
    de_cmd = rad2deg(out.command(:, 1));
    dr_cmd = rad2deg(out.command(:, 2));
    de_app = rad2deg(out.applied(:, 1));
    dr_app = rad2deg(out.applied(:, 2));

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1200 820]);

    subplot(2, 2, 1);
    plot(t, de_cmd, 'k--', 'LineWidth', 0.8); hold on;
    plot(t, de_app, 'b-', 'LineWidth', 1.0);
    yline(limits.de_max_deg, 'r--'); yline(-limits.de_max_deg, 'r--');
    grid on; xlabel('t [s]'); ylabel('delta_e [deg]', 'Interpreter', 'none');
    legend({'cmd', 'applied'}, 'Location', 'best');
    title(sprintf('%s: elevator', case_name), 'Interpreter', 'none');

    subplot(2, 2, 2);
    plot(t, dr_cmd, 'k--', 'LineWidth', 0.8); hold on;
    plot(t, dr_app, 'Color', [0.1 0.5 0.2], 'LineWidth', 1.0);
    yline(limits.dr_max_deg, 'r--'); yline(-limits.dr_max_deg, 'r--');
    grid on; xlabel('t [s]'); ylabel('delta_r [deg]', 'Interpreter', 'none');
    legend({'cmd', 'applied'}, 'Location', 'best');
    title(sprintf('%s: rudder', case_name), 'Interpreter', 'none');

    subplot(2, 2, 3);
    de_rate = [0; diff(de_app)] / dt;
    dr_rate = [0; diff(dr_app)] / dt;
    plot(t, de_rate, 'b-', 'LineWidth', 0.8); hold on;
    plot(t, dr_rate, 'Color', [0.1 0.5 0.2], 'LineWidth', 0.8);
    yline(limits.rate_dps, 'r--'); yline(-limits.rate_dps, 'r--');
    grid on; xlabel('t [s]'); ylabel('rate [deg/s]');
    legend({'delta_e', 'delta_r'}, 'Location', 'best', 'Interpreter', 'none');
    title(sprintf('%s: fin rates', case_name), 'Interpreter', 'none');

    subplot(2, 2, 4);
    plot3(out.position(:, 1), out.position(:, 2), out.position(:, 3), 'b-', 'LineWidth', 1.0); hold on;
    plot3(out.path(:, 1), out.path(:, 2), out.path(:, 3), 'k--', 'LineWidth', 0.8);
    grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
    title(sprintf('%s: path', case_name), 'Interpreter', 'none');
    axis equal;

    sgtitle(sprintf('Actuator limits case: %s', case_name), 'Interpreter', 'none', 'FontWeight', 'bold');
end

function save_actuator_limit_plots(artifact_dir, figs, case_defs)
    for i = 1:numel(figs)
        if i <= numel(case_defs)
            base = case_defs{i}.name;
        else
            base = sprintf('figure_%d', i);
        end
        out_png = fullfile(artifact_dir, ['actuator_limits_' base '.png']);
        if exist('exportgraphics', 'file') == 2
            exportgraphics(figs(i), out_png, 'Resolution', 150);
        else
            saveas(figs(i), out_png);
        end
        close(figs(i));
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
                    error('run_auv_v1_actuator_limits:NonFinite', ...
                        'Non-finite numeric values in argument %d.', k);
                end
            end
        elseif isnumeric(x) && any(~isfinite(x(:)))
            error('run_auv_v1_actuator_limits:NonFinite', ...
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
