function run_auv_v1_nominal_envelope()
%RUN_AUV_V1_NOMINAL_ENVELOPE  Deterministic heading/depth nominal-regression envelope.
%   Reuses the validated nominal path harness (continuous_path_tracking /
%   closed_loop_actuator_realism_case with ideal actuator). Runs a bounded
%   deterministic matrix: steady heading, heading steps, steady depth, depth
%   steps, combined commands, varied finite ICs, reset/restart, and one long run.
%   Computes rise time, settling time, overshoot, steady error, oscillation,
%   control effort, saturation fraction, and NaN/Inf status. Writes
%   artifacts/robustness_v2/nominal_envelope.json and bounded summary plots.
%   certified=false; no controller/guidance/plant edits; no acceptance gates.

    t_start = tic;
    proj_root = pwd;
    addpath(genpath(fullfile(proj_root, 'matlab')));

    artifact_dir = fullfile(proj_root, 'artifacts', 'robustness_v2');
    if ~exist(artifact_dir, 'dir')
        mkdir(artifact_dir);
    end

    scenario = 'nominal_envelope_heading_depth';
    seed = 20260829;
    dt = 0.025;
    duration_s = 30.0;
    long_duration_s = 120.0;
    settle_t = 5.0;
    max_runtime_s = 900.0;

    ideal_cfg = struct('ideal', true, 'tau_s', 0.0, 'delay_s', 0.0, ...
        'jitter_s', 0.0, 'deadband_deg', 0.0);
    limits = struct( ...
        'de_max_deg', 15, ...
        'dr_max_deg', 25, ...
        'rate_dps', 40, ...
        'sat_frac', 0.98);

    init_parameters();
    global desired_speed plant_Vc lambda_muw_ff
    plant_Vc = [0; 0; 0];
    lambda_muw_ff = 0.25;

    case_matrix = build_envelope_case_matrix(duration_s, long_duration_s);
    case_results = cell(1, numel(case_matrix));
    plot_specs = cell(0, 1);

    for ci = 1:numel(case_matrix)
        if toc(t_start) > max_runtime_s
            error('run_auv_v1_nominal_envelope:RuntimeCap', ...
                'Runtime cap %.0f s exceeded before case %d (%s).', ...
                max_runtime_s, ci, case_matrix{ci}.case_id);
        end

        cdef = case_matrix{ci};
        rng(seed, 'twister');

        entry = struct();
        entry.case_id = cdef.case_id;
        entry.domain = cdef.domain;
        entry.description = cdef.description;
        entry.duration_s = cdef.duration_s;
        entry.seed = seed;
        entry.dt = dt;
        entry.path_type = cdef.path_type;
        entry.initial_state = cdef.state0(:)';
        entry.step_time_s = cdef.step_time_s;
        entry.reset = cdef.reset;

        try
            if cdef.reset
                out = run_reset_restart_case(cdef.path, cdef.state0, dt, ...
                    cdef.duration_s, desired_speed, ideal_cfg, cdef.reset_time_s);
            else
                out = closed_loop_actuator_realism_case(cdef.path, cdef.state0, dt, ...
                    cdef.duration_s, desired_speed, ideal_cfg);
            end

            if ~isempty(out.error)
                error('run_auv_v1_nominal_envelope:CaseError', '%s', out.error);
            end
            if ~out.complete
                error('run_auv_v1_nominal_envelope:Incomplete', ...
                    'Incomplete (%d/%d steps).', nnz(isfinite(out.position(:, 1))), numel(out.t));
            end

            expected_steps = round(cdef.duration_s / dt);
            if size(out.position, 1) < expected_steps
                error('run_auv_v1_nominal_envelope:EarlyTermination', ...
                    'Early termination (%d/%d steps).', size(out.position, 1), expected_steps);
            end

            assert_all_finite(out.position, out.velocity, out.attitude, out.rates, ...
                out.reference, out.command, out.applied);

            actuator_metrics = compute_actuator_metrics_envelope(out, dt, limits, ideal_cfg);
            assert_all_finite(actuator_metrics);

            step_exp = get_step_expectations(cdef);
            [heading_cmd_ref, heading_step_levels] = build_time_sync_commanded_reference( ...
                out.path, out.t, cdef.step_time_s, cdef.duration_s, 'heading');
            heading_metrics = compute_channel_envelope_metrics( ...
                out.t, heading_cmd_ref, out.attitude(:, 3), ...
                out.command(:, 2), out.applied(:, 2), dt, settle_t, ...
                cdef.step_time_s, 'heading', step_exp.heading, heading_step_levels);
            depth_actual = -out.position(:, 3);
            [depth_cmd_ref, depth_step_levels] = build_time_sync_commanded_reference( ...
                out.path, out.t, cdef.step_time_s, cdef.duration_s, 'depth');
            depth_metrics = compute_channel_envelope_metrics( ...
                out.t, depth_cmd_ref, depth_actual, ...
                out.command(:, 1), out.applied(:, 1), dt, settle_t, ...
                cdef.step_time_s, 'depth', step_exp.depth, depth_step_levels);

            path_metrics = compute_path_following_metrics(cdef.path, out.position, out.velocity, ...
                out.attitude, out.reference(:, 2), out.reference(:, 1), dt, out.t);
            path_metrics_flat = flatten_numeric_metrics(path_metrics);
            assert_all_finite(path_metrics_flat);

            nan_inf = struct( ...
                'position', all(isfinite(out.position(:))), ...
                'velocity', all(isfinite(out.velocity(:))), ...
                'attitude', all(isfinite(out.attitude(:))), ...
                'reference', all(isfinite(out.reference(:))), ...
                'command', all(isfinite(out.command(:))), ...
                'applied', all(isfinite(out.applied(:))), ...
                'all_finite', true);

            metrics = struct();
            metrics.heading = heading_metrics;
            metrics.depth = depth_metrics;
            metrics.actuator = actuator_metrics;
            metrics.path = path_metrics_flat;
            metrics.nan_inf = nan_inf;
            assert_all_finite(metrics);

            entry.status = 'ok';
            entry.metrics = metrics;
            plot_specs{end + 1} = struct('case_id', cdef.case_id, 'out', out, ...
                'heading_metrics', heading_metrics, 'depth_metrics', depth_metrics); %#ok<AGROW>
        catch ME
            entry.status = 'failed';
            entry.error = ME.message;
        end

        case_results{ci} = entry;
    end

    runtime_s = toc(t_start);
    save_envelope_plots(artifact_dir, plot_specs, settle_t);

    [execution_pass, performance_acceptance, measurement_contract] = ...
        evaluate_envelope_measurement_contract(case_matrix, case_results);

    payload = struct();
    payload.certified = false;
    payload.schema = 'auv_v1_nominal_envelope_v1';
    payload.scenario = scenario;
    payload.seed = seed;
    payload.dt = dt;
    payload.settle_t = settle_t;
    payload.runtime_s = runtime_s;
    payload.parameters = struct( ...
        'ideal_actuator_cfg', ideal_cfg, ...
        'actuator_limits', limits, ...
        'plant_Vc_ned', plant_Vc(:)', ...
        'lambda_muw_ff', lambda_muw_ff, ...
        'desired_speed', desired_speed);
    payload.matrix_caps = struct( ...
        'n_cases', numel(case_matrix), ...
        'max_runtime_s', max_runtime_s, ...
        'standard_duration_s', duration_s, ...
        'long_duration_s', long_duration_s);
    payload.cases = [case_results{:}];
    payload.execution_pass = execution_pass;
    payload.performance_acceptance = performance_acceptance;
    payload.measurement_contract = measurement_contract;
    payload.note = ['Deterministic nominal heading/depth envelope for regression review only. ', ...
        'certified=false; no acceptance thresholds; controller/guidance/plant laws unchanged.'];

    json_path = fullfile(artifact_dir, 'nominal_envelope.json');
    fid = fopen(json_path, 'w');
    if fid < 0
        error('run_auv_v1_nominal_envelope:WriteFailed', ...
            'Could not open %s for writing.', json_path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(payload, 'PrettyPrint', true));

    fprintf('Wrote %s (%d cases, %.1f s, execution_pass=%d, performance_acceptance=%d)\n', ...
        json_path, numel(case_results), runtime_s, execution_pass, performance_acceptance);

    if ~execution_pass
        error('run_auv_v1_nominal_envelope:ExecutionFailed', ...
            'Execution contract failed: not all cases finite/ok.');
    end
    if ~performance_acceptance
        error('run_auv_v1_nominal_envelope:MeasurementFailed', ...
            'Measurement contract failed: declared step cases or response metrics invalid.');
    end
end

function case_matrix = build_envelope_case_matrix(duration_s, long_duration_s)
    depth_nom = 5.0;
    path_len = 60.0;
    npts = 120;

    case_matrix = {};

    path = build_straight_path(path_len, depth_nom, npts);
    case_matrix{end + 1} = make_case_def( ...
        'steady_heading', 'heading', 'Steady heading along +X at constant depth', ...
        path, default_state(path, depth_nom), duration_s, NaN, false, NaN); %#ok<AGROW>

    path = build_heading_step_path(30.0, 30.0, depth_nom, npts);
    case_matrix{end + 1} = make_case_def( ...
        'heading_step_l_turn', 'heading', 'Heading step via 90-deg L-turn (+X to +Y)', ...
        path, default_state(path, depth_nom), duration_s, 10.0, false, NaN); %#ok<AGROW>

    path = build_heading_step_path(30.0, -25.0, depth_nom, npts);
    case_matrix{end + 1} = make_case_def( ...
        'heading_step_right_turn', 'heading', 'Heading step via right turn (+X to -Y)', ...
        path, default_state(path, depth_nom), duration_s, 10.0, false, NaN); %#ok<AGROW>

    path = build_straight_path(path_len, depth_nom, npts);
    case_matrix{end + 1} = make_case_def( ...
        'steady_depth_5m', 'depth', 'Steady depth hold at 5 m on straight path', ...
        path, default_state(path, depth_nom), duration_s, NaN, false, NaN); %#ok<AGROW>

    path = build_depth_step_path(path_len, 3.0, 8.0, npts);
    state0 = default_state(path, 3.0);
    case_matrix{end + 1} = make_case_def( ...
        'depth_step_shallow_to_deep', 'depth', 'Depth step 3 m to 8 m mid-path', ...
        path, state0, duration_s, 10.0, false, NaN); %#ok<AGROW>

    path = build_depth_step_path(path_len, 8.0, 3.0, npts);
    state0 = default_state(path, 8.0);
    case_matrix{end + 1} = make_case_def( ...
        'depth_step_deep_to_shallow', 'depth', 'Depth step 8 m to 3 m mid-path', ...
        path, state0, duration_s, 10.0, false, NaN); %#ok<AGROW>

    path = build_combined_path(25.0, 25.0, 4.0, 9.0, npts);
    state0 = default_state(path, 4.0);
    case_matrix{end + 1} = make_case_def( ...
        'combined_turn_and_dive', 'combined', 'Combined heading turn and depth step', ...
        path, state0, duration_s, 10.0, false, NaN); %#ok<AGROW>

    path = build_straight_path(path_len, depth_nom, npts);
    state0 = default_state(path, depth_nom);
    state0(2) = 1.5;
    state0(6) = deg2rad(8.0);
    case_matrix{end + 1} = make_case_def( ...
        'ic_offset_yaw_and_y', 'initial_condition', ...
        'Finite IC offset: +1.5 m Y, +8 deg yaw misalignment', ...
        path, state0, duration_s, NaN, false, NaN); %#ok<AGROW>

    path = build_straight_path(path_len, depth_nom, npts);
    state0 = default_state(path, depth_nom);
    state0(3) = -3.2;
    state0(5) = deg2rad(3.0);
    case_matrix{end + 1} = make_case_def( ...
        'ic_offset_depth_and_pitch', 'initial_condition', ...
        'Finite IC offset: 3.2 m depth, +3 deg pitch', ...
        path, state0, duration_s, NaN, false, NaN); %#ok<AGROW>

    path = build_straight_path(path_len, depth_nom, npts);
    state0 = default_state(path, depth_nom);
    state0(7) = state0(7) * 0.85;
    case_matrix{end + 1} = make_case_def( ...
        'ic_offset_speed', 'initial_condition', ...
        'Finite IC offset: 85 percent nominal surge speed', ...
        path, state0, duration_s, NaN, false, NaN); %#ok<AGROW>

    path = build_depth_step_path(path_len, 4.0, 7.0, npts);
    state0 = default_state(path, 4.0);
    case_matrix{end + 1} = make_case_def( ...
        'reset_restart_mid_path', 'reset', ...
        'Reset/restart: 15 s run, state carry-over, 15 s continuation', ...
        path, state0, duration_s, 10.0, true, 15.0); %#ok<AGROW>

    path = build_straight_path(4.0 * path_len, depth_nom, 4 * npts);
    case_matrix{end + 1} = make_case_def( ...
        'long_run_straight', 'long', 'Long straight run at nominal depth', ...
        path, default_state(path, depth_nom), long_duration_s, NaN, false, NaN); %#ok<AGROW>
end

function c = make_case_def(case_id, domain, description, path, state0, duration_s, ...
    step_time_s, reset, reset_time_s)
    c = struct();
    c.case_id = case_id;
    c.domain = domain;
    c.description = description;
    c.path = path;
    c.state0 = state0;
    c.duration_s = duration_s;
    c.path_type = classify_path_type(path);
    c.step_time_s = step_time_s;
    c.reset = reset;
    c.reset_time_s = reset_time_s;
end

function ptype = classify_path_type(path)
    dz = max(path(:, 3)) - min(path(:, 3));
    dxy = max(vecnorm(diff(path(:, 1:2), 1, 1), 2, 2));
    if dz > 0.5 && dxy > 5.0
        ptype = 'combined_turn_depth';
    elseif dz > 0.5
        ptype = 'depth_step';
    elseif dxy > 5.0 && (abs(path(end, 1) - path(1, 1)) > 1.0 && abs(path(end, 2) - path(1, 2)) > 1.0)
        ptype = 'heading_step';
    else
        ptype = 'straight';
    end
end

function path = build_straight_path(length_m, depth_m, npts)
    path = [linspace(0, length_m, npts)', zeros(npts, 1), -depth_m * ones(npts, 1)];
end

function path = build_heading_step_path(leg1_m, leg2_m, depth_m, npts)
    n1 = max(2, round(npts / 2));
    n2 = max(2, npts - n1 + 1);
    p1 = [linspace(0, leg1_m, n1)', zeros(n1, 1), -depth_m * ones(n1, 1)];
    p2 = [leg1_m * ones(n2, 1), linspace(0, leg2_m, n2)', -depth_m * ones(n2, 1)];
    path = [p1; p2(2:end, :)];
end

function path = build_depth_step_path(length_m, depth1_m, depth2_m, npts)
    n1 = max(2, round(npts / 3));
    n2 = max(2, npts - n1 + 1);
    p1 = [linspace(0, length_m / 2, n1)', zeros(n1, 1), -depth1_m * ones(n1, 1)];
    p2 = [linspace(length_m / 2, length_m, n2)', zeros(n2, 1), ...
        linspace(-depth1_m, -depth2_m, n2)'];
    path = [p1; p2(2:end, :)];
end

function path = build_combined_path(leg1_m, leg2_m, depth1_m, depth2_m, npts)
    n1 = max(2, round(npts / 3));
    n2 = max(2, round(npts / 3));
    n3 = max(2, npts - n1 - n2 + 2);
    p1 = [linspace(0, leg1_m, n1)', zeros(n1, 1), -depth1_m * ones(n1, 1)];
    p2 = [leg1_m * ones(n2, 1), linspace(0, leg2_m, n2)', ...
        linspace(-depth1_m, -depth2_m, n2)'];
    p3 = [linspace(leg1_m, leg1_m + leg2_m, n3)', leg2_m * ones(n3, 1), ...
        -depth2_m * ones(n3, 1)];
    path = [p1; p2(2:end, :); p3(2:end, :)];
end

function state = default_state(path, depth_m)
    state = zeros(12, 1);
    state(1:3) = [path(1, 1); path(1, 2); -depth_m];
    d = path(2, :) - path(1, :);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    global desired_speed
    state(7) = desired_speed;
end

function out = run_reset_restart_case(path, state0, dt, duration_s, desired_speed, cfg, reset_time_s)
    t1 = reset_time_s;
    t2 = duration_s - reset_time_s;
    if t2 <= 0
        error('run_auv_v1_nominal_envelope:InvalidReset', ...
            'reset_time_s must be less than duration_s.');
    end

    out1 = closed_loop_actuator_realism_case(path, state0, dt, t1, desired_speed, cfg);
    if ~isempty(out1.error)
        out = out1;
        out.complete = false;
        return;
    end

    state1 = extract_state_from_out(out1);
    out2 = closed_loop_actuator_realism_case(path, state1, dt, t2, desired_speed, cfg);
    if ~isempty(out2.error)
        out = out2;
        out.complete = false;
        return;
    end

    out = stitch_segment_outputs(out1, out2, dt);
    out.error = '';
    out.complete = size(out.position, 1) >= round(duration_s / dt);
end

function state = extract_state_from_out(out)
    state = zeros(12, 1);
    state(1:3) = out.position(end, :)';
    state(4:6) = out.attitude(end, :)';
    state(7:9) = out.velocity(end, :)';
    state(10:12) = out.rates(end, :)';
end

function out = stitch_segment_outputs(out1, out2, dt)
    out = out1;
    fields = {'position', 'velocity', 'attitude', 'rates', 'reference', 'command', 'applied'};
    for i = 1:numel(fields)
        f = fields{i};
        if isfield(out2, f)
            out.(f) = [out1.(f); out2.(f)];
        end
    end
    n2 = size(out2.position, 1);
    out.t = [out1.t; out1.t(end) + (1:n2)' * dt];
    out.path = out1.path;
    if isfield(out1, 'allocated') && isfield(out2, 'allocated')
        out.allocated = [out1.allocated; out2.allocated];
    end
    out.complete = numel(out.t) >= numel(out1.t) + numel(out2.t);
end

function depth_ref = align_path_depth_reference(path, position)
%ALIGN_PATH_DEPTH_REFERENCE  Positive depth [m] at each vehicle sample.
    path = double(path);
    position = double(position);
    n_path = size(path, 1);
    n_pos = size(position, 1);
    depth_waypoints = -path(:, 3);

    s_nodes = zeros(n_path, 1);
    for i = 2:n_path
        s_nodes(i) = s_nodes(i-1) + norm(path(i, :) - path(i-1, :));
    end
    s_total = max(s_nodes(end), 1e-9);

    depth_ref = zeros(n_pos, 1);
    s_prog = 0;
    for i = 1:n_pos
        p = position(i, :);
        if i == 1
            [s_near, ~] = project_progress_on_path(p, path, s_nodes, 0, s_total);
            s_prog = s_near;
        else
            s_lo = max(0, s_prog - 0.15);
            s_hi = min(s_total, s_prog + max(3.0, 3.125));
            [s_near, ~] = project_progress_on_path(p, path, s_nodes, s_lo, s_hi);
            s_prog = max(s_prog, s_near - 0.05);
            s_prog = min(s_prog, s_total);
        end
        depth_ref(i) = interp1(s_nodes, depth_waypoints, s_prog, 'linear', 'extrap');
    end
end

function [s_best, d_best] = project_progress_on_path(p, path, s_nodes, s_lo, s_hi)
    n = size(path, 1);
    d_best = inf;
    s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n - 1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n - 1; end
    i0 = min(i0, n - 1);
    i1 = max(i1, i0);
    for i = i0:i1
        a = path(i, :);
        b = path(i + 1, :);
        ab = b - a;
        lab2 = sum(ab.^2);
        if lab2 < 1e-12
            continue;
        end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab;
        d = norm(p - proj);
        s = s_nodes(i) + tt * (s_nodes(i + 1) - s_nodes(i));
        if s < s_lo - 1e-9 || s > s_hi + 1e-9
            continue;
        end
        if d < d_best
            d_best = d;
            s_best = s;
        end
    end
end

function exp = get_step_expectations(cdef)
    exp = struct('heading', false, 'depth', false);
    if isnan(cdef.step_time_s) || ~isfinite(cdef.step_time_s)
        return;
    end
    switch cdef.domain
        case 'heading'
            exp.heading = true;
        case 'depth'
            exp.depth = true;
        case 'combined'
            exp.heading = true;
            exp.depth = true;
    end
end

function [ref_cmd, step_levels] = build_time_sync_commanded_reference(path, t, step_time_s, duration_s, channel_name)
%BUILD_TIME_SYNC_COMMANDED_REFERENCE  Commanded reference aligned to declared step_time_s.
%   For declared step cases (finite step_time_s), emits a hold-step-hold profile
%   from path geometry just before/after the dominant channel step so combined
%   turns are not collapsed to identical endpoint headings. Steady cases follow
%   path progress vs simulation time.
    t = t(:);
    n = numel(t);
    ref_cmd = zeros(n, 1);
    step_levels = struct('v0', NaN, 'vf', NaN, 'has_step', false);

    if isnan(step_time_s) || ~isfinite(step_time_s)
        duration_s = max(duration_s, 1e-9);
        for i = 1:n
            u = min(1.0, max(0.0, t(i) / duration_s));
            ref_cmd(i) = sample_path_channel_at_fraction(path, u, channel_name);
        end
    else
        frac = path_step_fraction(path, channel_name);
        eps_frac = 0.02;
        v0 = sample_path_channel_at_fraction(path, max(0.0, frac - eps_frac), channel_name);
        vf = sample_path_channel_at_fraction(path, min(1.0, frac + eps_frac), channel_name);
        if strcmp(channel_name, 'heading')
            vf = v0 + wrapToPi(vf - v0);
        end
        step_levels = struct('v0', v0, 'vf', vf, 'has_step', true);
        ref_cmd(t < step_time_s) = v0;
        ref_cmd(t >= step_time_s) = vf;
    end

    if strcmp(channel_name, 'heading')
        ref_cmd = unwrap(ref_cmd);
    end
end

function frac = path_step_fraction(path, channel_name)
    [s_nodes, s_total] = path_arclength_nodes(path);
    frac = 0.5;
    if s_total < 1e-9
        return;
    end

    if strcmp(channel_name, 'heading')
        headings = path_headings_along_nodes(path);
        dh = abs(wrapToPi(diff(headings)));
        [~, idx] = max(dh);
        if isempty(idx) || dh(idx) < deg2rad(3)
            frac = 0.5;
        else
            frac = s_nodes(idx + 1) / s_total;
        end
    else
        depths = -path(:, 3);
        d0 = depths(1);
        onset_idx = find(abs(depths - d0) > 0.20, 1, 'first');
        if isempty(onset_idx) || onset_idx < 2
            dd = abs(diff(depths));
            [~, idx] = max(dd);
            if isempty(idx) || dd(idx) < 1e-6
                frac = 0.5;
            else
                frac = s_nodes(idx + 1) / s_total;
            end
        else
            frac = s_nodes(onset_idx) / s_total;
        end
    end
    frac = min(1.0, max(0.0, frac));
end

function val = sample_path_channel_at_fraction(path, frac, channel_name)
    [s_nodes, s_total] = path_arclength_nodes(path);
    s = frac * s_total;
    if strcmp(channel_name, 'heading')
        val = sample_path_heading(path, s_nodes, s);
    else
        val = sample_path_depth(path, s_nodes, s);
    end
end

function headings = path_headings_along_nodes(path)
    n = size(path, 1);
    headings = zeros(n, 1);
    for i = 1:n - 1
        d = path(i + 1, 1:2) - path(i, 1:2);
        headings(i) = atan2(d(2), d(1));
    end
    headings(n) = headings(n - 1);
end

function h = sample_path_heading(path, s_nodes, s)
    n = size(path, 1);
    s = max(0, min(s_nodes(end), s));
    i = max(1, min(n - 1, find(s_nodes <= s, 1, 'last')));
    if isempty(i); i = 1; end
    ds = s_nodes(i + 1) - s_nodes(i);
    if ds < 1e-12
        tt = 0;
    else
        tt = (s - s_nodes(i)) / ds;
    end
    a = path(i, 1:2);
    b = path(i + 1, 1:2);
    tang = b - a;
    if norm(tang) < 1e-9
        if i > 1
            tang = path(i, 1:2) - path(i - 1, 1:2);
        else
            tang = [1, 0];
        end
    end
    h = atan2(tang(2), tang(1));
    if i < n - 1 && tt > 0.5
        tang2 = path(i + 2, 1:2) - path(i + 1, 1:2);
        if norm(tang2) > 1e-9
            h = atan2(tang2(2), tang2(1));
        end
    end
end

function d = sample_path_depth(path, s_nodes, s)
    depths = -path(:, 3);
    s = max(0, min(s_nodes(end), s));
    d = interp1(s_nodes, depths, s, 'linear', 'extrap');
end

function [s_nodes, s_total] = path_arclength_nodes(path)
    n = size(path, 1);
    s_nodes = zeros(n, 1);
    for i = 2:n
        s_nodes(i) = s_nodes(i - 1) + norm(path(i, :) - path(i - 1, :));
    end
    s_total = max(s_nodes(end), 1e-9);
end

function m = compute_channel_envelope_metrics(t, ref, actual, cmd, applied, dt, settle_t, ...
    step_time_s, channel_name, step_expected, step_levels)
    t = t(:);
    ref = ref(:);
    actual = actual(:);
    cmd = cmd(:);
    applied = applied(:);

    if strcmp(channel_name, 'heading')
        err = wrapToPi(ref - actual);
    else
        err = ref - actual;
    end

    m = struct();
    m.channel = channel_name;
    m.steady_error = mean(abs(err(t >= settle_t)));
    m.steady_error_signed = mean(err(t >= settle_t));
    m.oscillation = compute_oscillation_metric(err, dt, settle_t, t);
    m.control_effort_cmd_rms = rms(abs(cmd));
    m.control_effort_applied_rms = rms(abs(applied));

    if ~step_expected
        m.rise_time_s = 'not_applicable';
        m.settling_time_s = 'not_applicable';
        m.overshoot_pct = 'not_applicable';
        m.step_detected = false;
        return;
    end

    if strcmp(channel_name, 'heading')
        step_signal = unwrap(ref);
        step_actual = unwrap(actual);
    else
        step_signal = ref;
        step_actual = actual;
    end

    ref_detected = commanded_step_detected(step_levels, channel_name);
    [rise_s, settle_s, overshoot_pct, metrics_valid] = compute_step_response_metrics( ...
        t, step_signal, step_actual, step_time_s, channel_name, step_levels);
    m.step_detected = ref_detected;
    if ref_detected && metrics_valid
        m.rise_time_s = rise_s;
        m.settling_time_s = settle_s;
        m.overshoot_pct = overshoot_pct;
    else
        m.rise_time_s = 'not_applicable';
        m.settling_time_s = 'not_applicable';
        m.overshoot_pct = 'not_applicable';
    end
end

function detected = commanded_step_detected(step_levels, channel_name)
    detected = false;
    if ~isstruct(step_levels) || ~isfield(step_levels, 'has_step') || ~step_levels.has_step
        return;
    end
    v0 = step_levels.v0;
    vf = step_levels.vf;
    if ~isfinite(v0) || ~isfinite(vf)
        return;
    end
    if strcmp(channel_name, 'heading')
        step_mag = abs(wrapToPi(vf - v0));
        min_mag = deg2rad(3);
    else
        step_mag = abs(vf - v0);
        min_mag = 0.25;
    end
    detected = step_mag >= min_mag;
end

function osc = compute_oscillation_metric(err, dt, settle_t, t)
  mask = t >= settle_t;
  if ~any(mask)
      osc = 0.0;
      return;
  end
  e = err(mask);
  e = e - mean(e);
  n = max(3, round(0.8 / dt));
  b = ones(n, 1) / n;
  lf = filter(b, 1, e);
  hf = e - lf;
  hf(1:min(n, numel(hf))) = 0;
  osc = std(hf);
end

function [rise_s, settle_s, overshoot_pct, metrics_valid] = compute_step_response_metrics( ...
    t, ref_u, act_u, step_time_s, channel_name, step_levels)
    rise_s = NaN;
    settle_s = NaN;
    overshoot_pct = NaN;
    metrics_valid = false;

    if isnan(step_time_s) || ~isfinite(step_time_s)
        return;
    end
    if ~commanded_step_detected(step_levels, channel_name)
        return;
    end

    t = t(:);
    ref_u = ref_u(:);
    act_u = act_u(:);
    step_idx = find(t >= step_time_s - 1e-9, 1, 'first');
    if isempty(step_idx) || step_idx >= numel(t) - 5
        return;
    end

    pre_n = max(1, min(40, step_idx - 1));
    post_n = min(120, numel(ref_u) - step_idx);
    pre_lo = max(1, step_idx - pre_n);
    pre_hi = max(pre_lo, step_idx - 1);
    post_lo = min(numel(ref_u), step_idx + 1);
    post_hi = min(numel(ref_u), step_idx + post_n);
    y0 = mean(act_u(pre_lo:pre_hi));
    yf = step_levels.vf;
    step_span = yf - y0;
    if strcmp(channel_name, 'heading')
        step_span = wrapToPi(step_levels.vf - y0);
        yf = y0 + step_span;
    end
    if abs(step_span) < 1e-9
        return;
    end

    y10 = y0 + 0.10 * step_span;
    y90 = y0 + 0.90 * step_span;
    band = 0.05 * max(abs(step_span), 1e-6);

    seg_t = t(step_idx:end);
    seg_y = act_u(step_idx:end);
    rising = step_span >= 0;

    i10 = find((rising & seg_y >= y10) | (~rising & seg_y <= y10), 1, 'first');
    i90 = find((rising & seg_y >= y90) | (~rising & seg_y <= y90), 1, 'first');
    if ~isempty(i10) && ~isempty(i90) && i90 >= i10
        rise_s = max(0.0, seg_t(i90) - seg_t(i10));
    elseif ~isempty(i10)
        rise_s = max(0.0, seg_t(i10) - seg_t(1));
    else
        progress = abs(seg_y - y0) / max(abs(step_span), 1e-6);
        [max_progress, i_peak] = max(progress);
        if max_progress >= 0.05
            rise_s = max(0.0, seg_t(i_peak) - seg_t(1));
        else
            rise_s = max(0.0, seg_t(end) - seg_t(1));
        end
    end

    if rising
        overshoot_val = max(seg_y) - yf;
    else
        overshoot_val = yf - min(seg_y);
    end
    overshoot_pct = max(0.0, 100 * max(0, overshoot_val) / max(abs(step_span), 1e-6));

    inside = abs(seg_y - yf) <= band;
    settle_s = NaN;
    for k = 1:numel(inside)
        if all(inside(k:end))
            settle_s = max(0.0, seg_t(k) - seg_t(1));
            break;
        end
    end
    if ~isfinite(settle_s)
        err_seg = abs(seg_y - yf);
        [min_err, i_min] = min(err_seg);
        tail_n = max(5, round(1.0 / max(seg_t(2) - seg_t(1), 1e-6)));
        if i_min <= numel(err_seg) - tail_n + 1
            settle_s = max(0.0, seg_t(i_min) - seg_t(1));
        else
            settle_s = max(0.0, seg_t(end) - seg_t(1));
        end
        if min_err > 2.0 * band
            settle_s = max(settle_s, max(0.0, seg_t(end) - seg_t(1)));
        end
    end

    metrics_valid = isfinite_scalar_nonneg(rise_s) && ...
        isfinite_scalar_nonneg(settle_s) && ...
        isfinite_scalar_nonneg(overshoot_pct);
end

function [execution_pass, performance_acceptance, contract] = ...
        evaluate_envelope_measurement_contract(case_matrix, case_results)
    execution_pass = true;
    performance_acceptance = true;
    required = struct('case_id', {}, 'channel', {}, 'pass', {});

    for ci = 1:numel(case_results)
        cdef = case_matrix{ci};
        entry = case_results{ci};
        if ~strcmp(entry.status, 'ok')
            execution_pass = false;
            continue;
        end
        try
            assert_all_finite(entry.metrics);
        catch
            execution_pass = false;
        end

        step_exp = get_step_expectations(cdef);
        channels = {'heading', step_exp.heading; 'depth', step_exp.depth};
        for ch_i = 1:size(channels, 1)
            ch_name = channels{ch_i, 1};
            expected = channels{ch_i, 2};
            if ~expected
                continue;
            end
            m = entry.metrics.(ch_name);
            pass = m.step_detected && ...
                ~ischar(m.rise_time_s) && ~isstring(m.rise_time_s) && ...
                isfinite_scalar_nonneg(m.rise_time_s) && ...
                isfinite_scalar_nonneg(m.settling_time_s) && ...
                isfinite_scalar_nonneg(m.overshoot_pct);
            required(end + 1) = struct( ... %#ok<AGROW>
                'case_id', cdef.case_id, ...
                'channel', ch_name, ...
                'pass', pass);
            if ~pass
                performance_acceptance = false;
            end
        end
    end

    contract = struct();
    contract.required_step_cases = required;
    contract.all_declared_steps_detected = performance_acceptance;
    contract.all_applicable_metrics_valid = performance_acceptance;
end

function ok = isfinite_scalar_nonneg(x)
    ok = isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0;
end

function am = compute_actuator_metrics_envelope(out, dt, limits, cfg)
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

    am = struct();
    am.elevator_saturation_fraction_pct = 100 * mean(de_mag_sat(settle_mask));
    am.rudder_saturation_fraction_pct = 100 * mean(dr_mag_sat(settle_mask));
    am.combined_saturation_fraction_pct = 100 * mean(any_mag_sat(settle_mask));
    am.elevator_cmd_rmse_deg = rad2deg(rms(de_applied(settle_mask) - de_cmd(settle_mask)));
    am.rudder_cmd_rmse_deg = rad2deg(rms(dr_applied(settle_mask) - dr_cmd(settle_mask)));
    am.control_effort_elevator_rms_deg = rad2deg(rms(de_applied));
    am.control_effort_rudder_rms_deg = rad2deg(rms(dr_applied));

    deadband_rad = deg2rad(cfg.deadband_deg);
    if deadband_rad > 0
        am.elevator_deadband_reject_pct = 100 * mean((abs(de_cmd) > 0) & ...
            (abs(de_cmd) < deadband_rad) & (abs(de_applied) < 1e-8) & settle_mask);
        am.rudder_deadband_reject_pct = 100 * mean((abs(dr_cmd) > 0) & ...
            (abs(dr_cmd) < deadband_rad) & (abs(dr_applied) < 1e-8) & settle_mask);
    else
        am.elevator_deadband_reject_pct = 0.0;
        am.rudder_deadband_reject_pct = 0.0;
    end
end

function save_envelope_plots(artifact_dir, plot_specs, settle_t)
    if isempty(plot_specs)
        return;
    end

    n = min(numel(plot_specs), 6);
    fig = figure('Visible', 'off', 'Position', [60 60 1400 900]);
    tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

    for i = 1:n
        spec = plot_specs{i};
        out = spec.out;
        t = out.t;
        ax = nexttile;
        yyaxis(ax, 'left');
        plot(ax, t, rad2deg(wrapToPi(out.reference(:, 2) - out.attitude(:, 3))), 'b-', 'LineWidth', 0.9);
        ylabel(ax, 'yaw err [deg]');
        yyaxis(ax, 'right');
        depth_ref = align_path_depth_reference(out.path, out.position);
        plot(ax, t, depth_ref + out.position(:, 3), 'Color', [0.85 0.45 0.2], 'LineWidth', 0.9);
        ylabel(ax, 'depth err [m]');
        xline(ax, settle_t, '--', 'Color', [0.5 0.5 0.5]);
        grid(ax, 'on');
        xlabel(ax, 't [s]');
        title(ax, strrep(spec.case_id, '_', '\_'), 'Interpreter', 'tex');
    end

    sgtitle(fig, 'Nominal envelope: heading/depth tracking (certified=false)', 'FontWeight', 'bold');

    out_png = fullfile(artifact_dir, 'nominal_envelope_summary.png');
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, out_png, 'Resolution', 150);
    else
        saveas(fig, out_png);
    end
    close(fig);

    fig2 = figure('Visible', 'off', 'Position', [80 80 1200 700]);
    case_ids = cell(1, n);
    rise_h = zeros(1, n);
    settle_h = zeros(1, n);
    overshoot_h = zeros(1, n);
    for i = 1:n
        spec = plot_specs{i};
        case_ids{i} = spec.case_id;
        hm = spec.heading_metrics;
        rise_h(i) = metric_plot_scalar(hm.rise_time_s);
        settle_h(i) = metric_plot_scalar(hm.settling_time_s);
        overshoot_h(i) = metric_plot_scalar(hm.overshoot_pct);
    end

    subplot(2, 1, 1);
    bar_data = [rise_h; settle_h]';
    bar(bar_data);
    xticks(1:n);
    xticklabels(case_ids);
    xtickangle(45);
    ylabel('time [s]');
    legend({'rise', 'settling'}, 'Location', 'best');
    title('Heading step timing (non-step cases omitted)');
    grid on;

    subplot(2, 1, 2);
    overs = zeros(1, n);
    steady = zeros(1, n);
    for i = 1:n
        overs(i) = metric_plot_scalar(plot_specs{i}.heading_metrics.overshoot_pct);
        steady(i) = plot_specs{i}.heading_metrics.steady_error;
    end
    yyaxis left;
    bar(overs, 'FaceColor', [0.3 0.55 0.8]);
    ylabel('overshoot [%]');
    yyaxis right;
    plot(1:n, steady, 'o-', 'Color', [0.85 0.35 0.2], 'LineWidth', 1.2);
    ylabel('steady |yaw err| [rad]');
    xticks(1:n);
    xticklabels(case_ids);
    xtickangle(45);
    title('Overshoot and steady heading error');
    grid on;

    out_png2 = fullfile(artifact_dir, 'nominal_envelope_metrics.png');
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig2, out_png2, 'Resolution', 150);
    else
        saveas(fig2, out_png2);
    end
    close(fig2);
end

function v = metric_plot_scalar(x)
    if isnumeric(x) && isscalar(x) && isfinite(x)
        v = max(0, x);
    else
        v = 0;
    end
end

function assert_all_finite(varargin)
    for k = 1:nargin
        x = varargin{k};
        if isstruct(x)
            vals = struct2cell(x);
            for j = 1:numel(vals)
                v = vals{j};
                if islogical(v) || ischar(v) || isstring(v)
                    continue;
                end
                if ischar(v) && strcmp(v, 'not_applicable')
                    continue;
                end
                if isstring(v) && strcmp(v, 'not_applicable')
                    continue;
                end
                if isstruct(v)
                    assert_all_finite(v);
                elseif isnumeric(v) && any(~isfinite(v(:)))
                    error('run_auv_v1_nominal_envelope:NonFinite', ...
                        'Non-finite numeric values in argument %d.', k);
                end
            end
        elseif islogical(x) || ischar(x) || isstring(x)
            continue;
        elseif isnumeric(x) && any(~isfinite(x(:)))
            error('run_auv_v1_nominal_envelope:NonFinite', ...
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
