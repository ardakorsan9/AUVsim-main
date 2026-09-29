function run_auv_v1_bounded_current()
%RUN_AUV_V1_BOUNDED_CURRENT  Deterministic bounded water-current path metrics.
%   Reuses the nominal open-path harness at dt=0.025 s with the isolated
%   constant-current plant hook (global plant_Vc). Runs zero, cross-current,
%   and oblique bounded-current cases, rejects non-finite values, writes
%   artifacts/robustness/bounded_current.json and summary plots.
%   No PASS thresholds; certified=false.

    proj_root = pwd;
    addpath(genpath(fullfile(proj_root, 'matlab')));

    artifact_dir = fullfile(proj_root, 'artifacts', 'robustness');
    if ~exist(artifact_dir, 'dir')
        mkdir(artifact_dir);
    end

    scenario = 'bounded_current_3d_straight_line';
    seed = 20260828;
    dt = 0.025;
    duration_s = 30.0;

    num_points = 120;
    path_length_m = 60.0;
    depth_m = 5.0;
    path = [linspace(0, path_length_m, num_points)', zeros(num_points, 1), ...
        -depth_m * ones(num_points, 1)];

    cross_speed_mps = 0.15;
    oblique_component = cross_speed_mps / sqrt(2);

    cases = {
        struct('name', 'zero', 'Vc_ned', [0; 0; 0])
        struct('name', 'cross_current', 'Vc_ned', [0; cross_speed_mps; 0])
        struct('name', 'oblique_current', 'Vc_ned', [oblique_component; oblique_component; 0])
    };

    init_parameters();
    global desired_speed plant_Vc lambda_muw_ff

    lambda_muw_ff = 0.25;

    case_results = cell(1, numel(cases));

    for ci = 1:numel(cases)
        case_def = cases{ci};
        rng(seed, 'twister');

        state = zeros(12, 1);
        state(1:3) = [0; 0; -depth_m];
        d = path(2, :) - path(1, :);
        state(5) = -atan2(d(3), norm(d(1:2)));
        state(6) = atan2(d(2), d(1));
        state(7) = desired_speed;

        plant_Vc = case_def.Vc_ned(:);

        try
            [vehicle_path, times, velocities, angular_velocities, orientations, total_time, ...
                yaw_refs, pitch_refs, u_refs] = simulate_path_with_current(path, state, dt, duration_s);
        catch ME
            error('run_auv_v1_bounded_current:SimulationFailed', ...
                'Case "%s" failed: %s', case_def.name, ME.message);
        end

        expected_steps = round(duration_s / dt);
        if size(vehicle_path, 1) < expected_steps
            error('run_auv_v1_bounded_current:EarlyTermination', ...
                'Case "%s" ended early (%d/%d steps).', case_def.name, ...
                size(vehicle_path, 1), expected_steps);
        end

        assert_all_finite(vehicle_path, times, velocities, angular_velocities, orientations, ...
            yaw_refs, pitch_refs, u_refs);

        metrics = compute_path_following_metrics(path, vehicle_path, velocities, orientations, ...
            yaw_refs, pitch_refs, dt, times);
        metric_values = flatten_numeric_metrics(metrics);
        assert_all_finite(struct2array(metric_values));

        case_out = struct();
        case_out.name = case_def.name;
        case_out.Vc_ned = plant_Vc(:)';
        case_out.seed = seed;
        case_out.metrics = metric_values;
        case_results{ci} = case_out;

        path_params = struct( ...
            'type', '3d_straight_line', ...
            'description', sprintf('Bounded current case: %s', case_def.name), ...
            'num_points', num_points);

        sim_params = struct( ...
            'start_position', state(1:3)', ...
            'reference_path_type', '3d_straight_line', ...
            'dt', dt, ...
            'total_time', total_time, ...
            'Vc_ned', plant_Vc(:)');

        plot_simulation_results(path, vehicle_path, times, velocities, angular_velocities, ...
            orientations, path_params, sim_params, yaw_refs, pitch_refs, u_refs);
        save_bounded_current_plots(artifact_dir, case_def.name);
    end

    payload = struct();
    payload.certified = false;
    payload.scenario = scenario;
    payload.duration_s = duration_s;
    payload.seed = seed;
    payload.dt = dt;
    payload.cases = [case_results{:}];

    json_path = fullfile(artifact_dir, 'bounded_current.json');
    fid = fopen(json_path, 'w');
    if fid < 0
        error('run_auv_v1_bounded_current:WriteFailed', 'Could not open %s for writing.', json_path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(payload, 'PrettyPrint', true));

    fprintf('Wrote %s (%d cases)\n', json_path, numel(cases));
end

function [vehicle_path, times, velocities, angular_velocities, orientations, total_time, ...
    yaw_refs, pitch_refs, u_refs] = simulate_path_with_current(path, state, dt, duration_s)

    global dt_guidance plant_Vc

    plant_fn = @underwater777_vehicle_dynamics_current;
    n_steps = round(duration_s / dt);
    if isempty(dt_guidance)
        dt_guidance = dt;
    end
    guidance_period = max(1, round(dt_guidance / dt));

    yaw_ref = 0;
    pitch_ref = 0;
    u_ref = 0;
    r_ff = 0;
    pitch_ref_dot = 0;
    progress_index = 1;

    vehicle_path = zeros(n_steps, 3);
    times = zeros(n_steps, 1);
    velocities = zeros(n_steps, 3);
    angular_velocities = zeros(n_steps, 3);
    orientations = zeros(n_steps, 3);
    yaw_refs = zeros(n_steps, 1);
    pitch_refs = zeros(n_steps, 1);
    u_refs = zeros(n_steps, 1);

    for idx = 1:n_steps
        cur_pos = state(1:3)';
        cur_ori = state(4:6)';
        cur_rates = state(10:12)';
        cur_u = state(7);
        cur_v = state(8);
        cur_w = state(9);

        [U_h, zdot_inertial] = inertial_velocity_ned(cur_ori, cur_u, cur_v, cur_w);
        theta_phys_now = -cur_ori(2);

        if mod(idx - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, progress_index, r_ff, pitch_ref_dot] = ...
                guidance_law(cur_pos, path, progress_index, cur_u, cur_v, ...
                U_h, zdot_inertial, theta_phys_now);
        end

        [delta_r, delta_e, thrust] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            cur_ori(3), cur_ori(2), cur_rates(3), cur_rates(2), ...
            cur_u, r_ff, pitch_ref_dot, cur_ori(1), cur_w, cur_rates(1));

        controls.delta_r = delta_r;
        controls.delta_e = delta_e;
        controls.thrust = thrust;

        [~, g] = ode45(@(t, g) plant_fn(t, g, controls), [0 dt], state);
        state = g(end, :)';

        if any(~isfinite(state))
            error('simulate_path_with_current:NonFiniteState', ...
                'Non-finite state at step %d (Vc=[%.4f %.4f %.4f]).', ...
                idx, plant_Vc(1), plant_Vc(2), plant_Vc(3));
        end

        vehicle_path(idx, :) = state(1:3);
        velocities(idx, :) = state(7:9);
        angular_velocities(idx, :) = state(10:12);
        orientations(idx, :) = state(4:6);
        yaw_refs(idx) = yaw_ref;
        pitch_refs(idx) = pitch_ref;
        u_refs(idx) = u_ref;
        times(idx) = idx * dt;
    end

    total_time = times(end);
end

function [U_h, zdot] = inertial_velocity_ned(ori, u, v, w)
    R = rotmat_ned(ori(1), ori(2), ori(3));
    pos_dot = R * [u; v; w];
    U_h = hypot(pos_dot(1), pos_dot(2));
    zdot = pos_dot(3);
end

function R = rotmat_ned(phi, theta, psi)
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
end

function assert_all_finite(varargin)
    for k = 1:nargin
        x = varargin{k};
        if isstruct(x)
            vals = struct2cell(x);
            for j = 1:numel(vals)
                v = vals{j};
                if isnumeric(v) && any(~isfinite(v(:)))
                    error('run_auv_v1_bounded_current:NonFinite', ...
                        'Non-finite numeric values in argument %d.', k);
                end
            end
        elseif isnumeric(x) && any(~isfinite(x(:)))
            error('run_auv_v1_bounded_current:NonFinite', ...
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

function save_bounded_current_plots(artifact_dir, case_name)
    figs = findall(0, 'Type', 'figure');
    figs = flipud(figs);
    plot_names = {'path_3d', 'path_2d_summary', 'motion_overview'};
    prefix = ['bounded_current_' case_name '_'];
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
