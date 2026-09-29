function run_auv_v1_nominal_baseline()
%RUN_AUV_V1_NOMINAL_BASELINE  Deterministic nominal path-tracking measurement harness.
%   Runs one open-path straight-line case at dt=0.025 s, computes path-following
%   metrics, rejects non-finite values, writes artifacts/robustness/nominal.json
%   and saves summary plots alongside it.

    proj_root = pwd;
    addpath(genpath(fullfile(proj_root, 'matlab')));

    artifact_dir = fullfile(proj_root, 'artifacts', 'robustness');
    if ~exist(artifact_dir, 'dir')
        mkdir(artifact_dir);
    end

    scenario = 'nominal_3d_straight_line';
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

    try
        [vehicle_path, times, velocities, angular_velocities, orientations, total_time, ...
            yaw_refs, pitch_refs, u_refs] = continuous_path_tracking(path, state, dt, duration_s);
    catch ME
        error('run_auv_v1_nominal_baseline:SimulationFailed', ...
            'continuous_path_tracking failed: %s', ME.message);
    end

    expected_steps = round(duration_s / dt);
    if size(vehicle_path, 1) < expected_steps
        error('run_auv_v1_nominal_baseline:EarlyTermination', ...
            'Simulation ended early (%d/%d steps).', size(vehicle_path, 1), expected_steps);
    end

    assert_all_finite(vehicle_path, times, velocities, angular_velocities, orientations, ...
        yaw_refs, pitch_refs, u_refs);

    metrics = compute_path_following_metrics(path, vehicle_path, velocities, orientations, ...
        yaw_refs, pitch_refs, dt, times);
    metric_values = flatten_numeric_metrics(metrics);
    assert_all_finite(struct2array(metric_values));

    path_params = struct( ...
        'type', '3d_straight_line', ...
        'description', 'Nominal baseline open straight line (+X at constant depth)', ...
        'num_points', num_points);

    sim_params = struct( ...
        'start_position', state(1:3)', ...
        'reference_path_type', '3d_straight_line', ...
        'dt', dt, ...
        'total_time', total_time);

    plot_simulation_results(path, vehicle_path, times, velocities, angular_velocities, ...
        orientations, path_params, sim_params, yaw_refs, pitch_refs, u_refs);
    save_nominal_plots(artifact_dir);

    payload = struct();
    payload.certified = false;
    payload.scenario = scenario;
    payload.duration_s = duration_s;
    payload.seed = seed;
    payload.dt = dt;
    payload.metrics = metric_values;

    json_path = fullfile(artifact_dir, 'nominal.json');
    fid = fopen(json_path, 'w');
    if fid < 0
        error('run_auv_v1_nominal_baseline:WriteFailed', 'Could not open %s for writing.', json_path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(payload, 'PrettyPrint', true));

    fprintf('Wrote %s (%d metrics)\n', json_path, numel(fieldnames(metric_values)));
end

function assert_all_finite(varargin)
    for k = 1:nargin
        x = varargin{k};
        if isstruct(x)
            vals = struct2cell(x);
            for j = 1:numel(vals)
                v = vals{j};
                if isnumeric(v) && any(~isfinite(v(:)))
                    error('run_auv_v1_nominal_baseline:NonFinite', ...
                        'Non-finite numeric values in argument %d.', k);
                end
            end
        elseif isnumeric(x) && any(~isfinite(x(:)))
            error('run_auv_v1_nominal_baseline:NonFinite', ...
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

function save_nominal_plots(artifact_dir)
    figs = findall(0, 'Type', 'figure');
    figs = flipud(figs);
    plot_names = {'path_3d', 'path_2d_summary', 'motion_overview'};
    for i = 1:numel(figs)
        if i <= numel(plot_names)
            base = plot_names{i};
        else
            base = sprintf('figure_%d', i);
        end
        out_png = fullfile(artifact_dir, ['nominal_' base '.png']);
        if exist('exportgraphics', 'file') == 2
            exportgraphics(figs(i), out_png, 'Resolution', 150);
        else
            saveas(figs(i), out_png);
        end
    end
    close(figs);
end
