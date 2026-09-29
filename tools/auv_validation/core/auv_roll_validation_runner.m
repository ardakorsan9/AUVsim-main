function payload = auv_roll_validation_runner(harness, mode, opts)
%AUV_ROLL_VALIDATION_RUNNER  Shared deterministic roll-validation runner (SIM9/SIM10).
%   payload = auv_roll_validation_runner('passive_roll_stress', mode)
%   payload = auv_roll_validation_runner('roll_rate_solution_audit', mode, opts)
%   opts.write_artifact (default true), opts.write_plots (default true),
%   opts.artifact_path (optional override), opts.fail_on_execution (default true)

    if nargin < 1 || isempty(harness)
        error('auv_roll_validation_runner:MissingHarness', 'harness is required.');
    end
    harness = lower(char(string(harness)));
    if nargin < 2 || isempty(mode)
        mode = 'full';
    end
    mode = lower(char(string(mode)));
    if ~any(strcmp(mode, {'smoke', 'full'}))
        error('auv_roll_validation_runner:InvalidMode', ...
            'mode must be ''smoke'' or ''full''.');
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end
    write_artifact = get_opt(opts, 'write_artifact', true);
    write_plots = get_opt(opts, 'write_plots', true);
    fail_on_execution = get_opt(opts, 'fail_on_execution', true);

    t_start = tic;
    proj_root = pwd;
    addpath(proj_root);

    catalog = auv_roll_scenario_catalog('catalog');
    registry = auv_roll_metric_registry('registry');
    hspec = catalog.harnesses.(harness);

    artifact_dir = fullfile(proj_root, 'artifacts', 'robustness_v2');
    if write_artifact && ~exist(artifact_dir, 'dir')
        mkdir(artifact_dir);
    end

    switch mode
        case 'smoke'
            duration_s = hspec.smoke_duration_s;
            max_runtime_s = hspec.smoke_max_runtime_s;
        otherwise
            duration_s = hspec.full_duration_s;
            max_runtime_s = hspec.full_max_runtime_s;
    end

    seed = catalog.seed;
    dt = catalog.dt;
    settle_t = catalog.settle_t;
    screening_band_deg = catalog.screening_band_deg;
    rate_threshold_dps = catalog.rate_threshold_dps;

    ideal_cfg = struct('ideal', true, 'tau_s', 0.0, 'delay_s', 0.0, ...
        'jitter_s', 0.0, 'deadband_deg', 0.0);
    limits = registry.actuator_limits;
    screening_thresholds = registry.screening_thresholds;

    init_parameters();
    global desired_speed plant_Vc lambda_muw_ff dt_guidance dt_controller Kp_roll Ixx
    lambda_muw_ff = 0.25;
    nominal_speed = desired_speed;
    baseline_kp_roll = 0.605072;

    switch harness
        case 'passive_roll_stress'
            payload = run_passive_roll_stress(harness, hspec, mode, t_start, ...
                duration_s, max_runtime_s, seed, dt, settle_t, screening_band_deg, ...
                ideal_cfg, limits, screening_thresholds, nominal_speed, ...
                write_plots, artifact_dir);
        case 'roll_rate_solution_audit'
            payload = run_roll_rate_solution_audit(harness, hspec, mode, t_start, ...
                duration_s, max_runtime_s, seed, dt, settle_t, screening_band_deg, ...
                rate_threshold_dps, ideal_cfg, limits, screening_thresholds, ...
                nominal_speed, baseline_kp_roll, write_plots, artifact_dir);
        otherwise
            error('auv_roll_validation_runner:UnknownHarness', ...
                'Unknown harness: %s', harness);
    end

    desired_speed = nominal_speed;
    plant_Vc = [0; 0; 0];
    Kp_roll = baseline_kp_roll;

    if write_artifact
        if isfield(opts, 'artifact_path') && ~isempty(opts.artifact_path)
            json_path = opts.artifact_path;
        else
            json_path = fullfile(artifact_dir, hspec.artifact_name);
        end
        write_json_payload(json_path, payload);
        log_runner_write(harness, json_path, payload);
    end

    if fail_on_execution && ~payload.execution_pass
        error('auv_roll_validation_runner:ExecutionFailed', ...
            '%s execution contract failed.', harness);
    end
end

function payload = run_passive_roll_stress(~, hspec, mode, t_start, ...
        duration_s, max_runtime_s, seed, dt, settle_t, screening_band_deg, ...
        ideal_cfg, limits, screening_thresholds, nominal_speed, ...
        write_plots, artifact_dir)

    case_matrix = auv_roll_scenario_catalog('case_matrix', ...
        'passive_roll_stress', mode, duration_s, nominal_speed);
    case_results = cell(1, numel(case_matrix));
    plot_specs = cell(0, 1);

    for ci = 1:numel(case_matrix)
        if toc(t_start) > max_runtime_s
            error('auv_roll_validation_runner:RuntimeCap', ...
                'Runtime cap %.0f s exceeded before case %d (%s).', ...
                max_runtime_s, ci, case_matrix{ci}.case_id);
        end

        cdef = case_matrix{ci};
        rng(seed, 'twister');
        clear guidance_law controller_law

        entry = struct();
        entry.case_id = cdef.case_id;
        entry.domain = cdef.domain;
        entry.description = cdef.description;
        entry.duration_s = cdef.duration_s;
        entry.seed = seed;
        entry.dt = dt;
        entry.heel_deg = cdef.heel_deg;
        entry.speed_mps = cdef.speed_mps;
        entry.Vc_ned = cdef.Vc_ned(:)';
        entry.restoring_scale = cdef.restoring_scale;
        entry.roll_pulse = cdef.roll_pulse;

        restoring_snap = [];
        try
            global desired_speed plant_Vc
            plant_Vc = cdef.Vc_ned(:);
            desired_speed = cdef.speed_mps;

            [out, restoring_snap] = run_passive_roll_closed_loop(cdef.path, cdef.state0, dt, ...
                cdef.duration_s, cdef.speed_mps, ideal_cfg, cdef.roll_pulse, ...
                cdef.restoring_scale);

            validate_sim_output(out, dt, cdef.duration_s, harness_label('passive_roll_stress'));

            roll_metrics = auv_roll_metric_registry('compute_passive', out, dt, settle_t, ...
                screening_band_deg, limits, ideal_cfg);
            auv_roll_metric_registry('assert_finite', roll_metrics);

            entry.status = 'ok';
            entry.metrics = roll_metrics;
            plot_specs{end + 1} = struct('case_id', cdef.case_id, 'out', out, ...
                'metrics', roll_metrics); %#ok<AGROW>
            if ~isempty(restoring_snap)
                restore_restoring_params(restoring_snap);
                restoring_snap = [];
            end
        catch ME
            if ~isempty(restoring_snap)
                restore_restoring_params(restoring_snap);
            end
            entry.status = 'failed';
            entry.error = ME.message;
        end

        global desired_speed plant_Vc
        desired_speed = nominal_speed;
        plant_Vc = [0; 0; 0];
        case_results{ci} = entry;
    end

    runtime_s = toc(t_start);

    if write_plots
        save_passive_roll_plots(artifact_dir, plot_specs, screening_band_deg);
    end

    execution_pass = auv_roll_metric_registry('evaluate_execution', ...
        'passive_roll_stress', case_results);
    [screening_pass, screening_detail] = auv_roll_metric_registry('evaluate_screening', ...
        case_results, screening_thresholds);
    recommendation = auv_roll_metric_registry('recommendation', ...
        execution_pass, screening_pass, case_results);

    global dt_guidance dt_controller lambda_muw_ff desired_speed
    payload = struct();
    payload.certified = false;
    payload.schema = hspec.schema;
    payload.scenario = hspec.scenario;
    payload.mode = mode;
    payload.seed = seed;
    payload.dt = dt;
    payload.duration_s = duration_s;
    payload.settle_t = settle_t;
    payload.runtime_s = runtime_s;
    payload.parameters = struct( ...
        'ideal_actuator_cfg', ideal_cfg, ...
        'actuator_limits', limits, ...
        'lambda_muw_ff', lambda_muw_ff, ...
        'nominal_speed_mps', nominal_speed, ...
        'dt_guidance', dt_guidance, ...
        'dt_controller', dt_controller, ...
        'passive_roll_control', struct( ...
            'roll_angle_loop', false, ...
            'roll_rate_damping', true, ...
            'active_roll_hardware', false));
    payload.screening_thresholds = screening_thresholds;
    payload.matrix_caps = struct( ...
        'n_cases', numel(case_matrix), ...
        'max_runtime_s', max_runtime_s);
    payload.cases = [case_results{:}];
    payload.execution_pass = execution_pass;
    payload.screening_pass = screening_pass;
    payload.screening_detail = screening_detail;
    payload.recommendation = recommendation;
    payload.parameters_assumed_note = ['Restoring and hydrodynamic parameters are ', ...
        'assumed from init_parameters until hardware identification; ', ...
        'screening thresholds are declared measurement gates only.'];
    payload.note = ['Deterministic passive-roll stress measurement only. ', ...
        'certified=false; controller/guidance/plant laws unchanged; no gain tuning. ', ...
        'Roll-moment pulses are applied as impulse-equivalent roll-rate kicks at pulse time.'];
end

function payload = run_roll_rate_solution_audit(~, hspec, mode, t_start, ...
        duration_s, max_runtime_s, seed, dt, settle_t, screening_band_deg, ...
        rate_threshold_dps, ideal_cfg, limits, screening_thresholds, ...
        nominal_speed, baseline_kp_roll, write_plots, artifact_dir)

    sim9_json = fullfile(pwd, 'artifacts', 'robustness_v2', 'passive_roll_stress.json');
    if ~isfile(sim9_json)
        error('auv_roll_validation_runner:MissingSim9', ...
            'Required SIM9 artifact missing: %s', sim9_json);
    end
    sim9 = jsondecode(fileread(sim9_json));

    metric_verification = auv_roll_metric_registry('metric_verification', ...
        sim9, dt, rate_threshold_dps, limits);
    risk_classification = auv_roll_metric_registry('risk_classification', ...
        sim9, screening_thresholds);

    shadow_catalog = auv_roll_scenario_catalog('shadow_catalog', mode, baseline_kp_roll);
    case_matrix = auv_roll_scenario_catalog('case_matrix', ...
        'roll_rate_solution_audit', mode, duration_s, nominal_speed);
    case_results = cell(1, numel(case_matrix));

    for ci = 1:numel(case_matrix)
        if toc(t_start) > max_runtime_s
            error('auv_roll_validation_runner:RuntimeCap', ...
                'Runtime cap %.0f s exceeded before case %d (%s).', ...
                max_runtime_s, ci, case_matrix{ci}.case_id);
        end

        cdef = case_matrix{ci};
        entry = struct();
        entry.case_id = cdef.case_id;
        entry.domain = cdef.domain;
        entry.description = cdef.description;
        entry.shadows = cell(1, numel(shadow_catalog));

        for si = 1:numel(shadow_catalog)
            shadow = shadow_catalog{si};
            rng(seed, 'twister');
            clear guidance_law controller_law

            restoring_snap = [];
            shadow_entry = struct();
            shadow_entry.shadow_id = shadow.shadow_id;
            shadow_entry.label = shadow.label;
            shadow_entry.kind = shadow.kind;
            shadow_entry.params = shadow.params;

            try
                global desired_speed plant_Vc Kp_roll Ixx
                plant_Vc = cdef.Vc_ned(:);
                desired_speed = cdef.speed_mps;

                kp_save = Kp_roll;
                Kp_roll = shadow.params.Kp_roll;

                [out, restoring_snap] = run_audit_closed_loop(cdef.path, cdef.state0, dt, ...
                    cdef.duration_s, cdef.speed_mps, ideal_cfg, cdef.roll_pulse, ...
                    cdef.restoring_scale, shadow, mode);

                Kp_roll = kp_save;

                validate_sim_output(out, dt, cdef.duration_s, harness_label('roll_rate_solution_audit'));

                metrics = auv_roll_metric_registry('compute_audit', out, dt, settle_t, ...
                    screening_band_deg, limits, rate_threshold_dps, Ixx);
                auv_roll_metric_registry('assert_finite', metrics);

                shadow_entry.status = 'ok';
                shadow_entry.metrics = metrics;
            catch ME
                shadow_entry.status = 'failed';
                shadow_entry.error = ME.message;
            end

            if ~isempty(restoring_snap)
                restore_restoring_params(restoring_snap);
            end
            entry.shadows{si} = shadow_entry;
        end

        global desired_speed plant_Vc
        desired_speed = nominal_speed;
        plant_Vc = [0; 0; 0];
        case_results{ci} = entry;
    end

    runtime_s = toc(t_start);

    shadow_comparison = auv_roll_metric_registry('shadow_comparison', ...
        case_results, shadow_catalog, rate_threshold_dps);
    decision = auv_roll_metric_registry('audit_decision', ...
        risk_classification, shadow_comparison, case_results);
    execution_pass = auv_roll_metric_registry('audit_execution', case_results);
    screening_pass = auv_roll_metric_registry('baseline_rate_screening', ...
        case_results, rate_threshold_dps);

    if write_plots && ~strcmp(mode, 'smoke')
        save_roll_rate_audit_plots(artifact_dir, case_results, shadow_catalog, rate_threshold_dps);
    end

    flat_cases = flatten_case_results_for_json(case_results);

    global dt_guidance dt_controller lambda_muw_ff Ixx
    payload = struct();
    payload.certified = false;
    payload.schema = hspec.schema;
    payload.scenario = hspec.scenario;
    payload.mode = mode;
    payload.seed = seed;
    payload.dt = dt;
    payload.duration_s = duration_s;
    payload.settle_t = settle_t;
    payload.runtime_s = runtime_s;
    payload.sim9_source = hspec.sim9_source;
    payload.parameters = struct( ...
        'ideal_actuator_cfg', ideal_cfg, ...
        'actuator_limits', limits, ...
        'lambda_muw_ff', lambda_muw_ff, ...
        'nominal_speed_mps', nominal_speed, ...
        'dt_guidance', dt_guidance, ...
        'dt_controller', dt_controller, ...
        'baseline_Kp_roll', baseline_kp_roll, ...
        'Ixx_kgm2', Ixx, ...
        'passive_roll_control', struct( ...
            'roll_angle_loop', false, ...
            'roll_rate_damping', true, ...
            'active_roll_hardware', false));
    payload.screening_thresholds = screening_thresholds;
    payload.metric_verification = metric_verification;
    payload.risk_classification = risk_classification;
    payload.shadow_catalog = [shadow_catalog{:}];
    payload.shadow_comparison = shadow_comparison;
    payload.decision = decision;
    payload.execution_pass = execution_pass;
    payload.screening_pass = screening_pass;
    payload.cases = flat_cases;
    payload.matrix_caps = struct( ...
        'n_cases', numel(case_matrix), ...
        'n_shadows', numel(shadow_catalog), ...
        'max_runtime_s', max_runtime_s);
    payload.parameters_assumed_note = ['Restoring and hydrodynamic parameters are ', ...
        'assumed from init_parameters until hardware identification; ', ...
        'shadow solutions are audit-only and do not change production gains.'];
    payload.note = ['Deterministic roll-rate solution audit. certified=false; ', ...
        'production controller/guidance/plant unchanged. Shadow Kp_roll uses ', ...
        'existing rudder roll-rate damping path. Active-roll ideal applies ', ...
        'audit-only perfect rate damping as an upper-bound comparator.'];
end

function validate_sim_output(out, dt, duration_s, label)
    if ~isempty(out.error)
        error('auv_roll_validation_runner:CaseError', '%s: %s', label, out.error);
    end
    if ~out.complete
        error('auv_roll_validation_runner:Incomplete', ...
            '%s: Incomplete (%d/%d steps).', label, ...
            nnz(isfinite(out.position(:, 1))), numel(out.t));
    end
    expected_steps = round(duration_s / dt);
    if size(out.position, 1) < expected_steps
        error('auv_roll_validation_runner:EarlyTermination', ...
            '%s: Early termination (%d/%d steps).', label, ...
            size(out.position, 1), expected_steps);
    end
    assert_all_finite(out.position, out.velocity, out.attitude, out.rates, ...
        out.reference, out.command, out.applied);
end

function label = harness_label(harness)
    label = ['auv_roll_validation_runner:' harness];
end

function flat_cases = flatten_case_results_for_json(case_results)
    flat_cases = struct('case_id', {}, 'domain', {}, 'description', {}, 'shadows', {});
    for ci = 1:numel(case_results)
        entry = case_results{ci};
        flat_cases(end + 1) = struct( ...
            'case_id', entry.case_id, ...
            'domain', entry.domain, ...
            'description', entry.description, ...
            'shadows', normalize_shadow_rows_for_json(entry.shadows)); %#ok<AGROW>
    end
end

function rows = normalize_shadow_rows_for_json(shadows)
    rows = repmat(struct('shadow_id', '', 'label', '', 'kind', '', 'params', struct(), ...
        'status', '', 'metrics', struct(), 'error', ''), 0, 1);
    for si = 1:numel(shadows)
        sh = shadows{si};
        row = struct();
        row.shadow_id = sh.shadow_id;
        row.label = sh.label;
        row.kind = sh.kind;
        row.params = sh.params;
        row.status = sh.status;
        if isfield(sh, 'metrics') && ~isempty(sh.metrics)
            row.metrics = sh.metrics;
        else
            row.metrics = struct();
        end
        if isfield(sh, 'error') && ~isempty(sh.error)
            row.error = sh.error;
        else
            row.error = '';
        end
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
end

function [out, restoring_snap] = run_audit_closed_loop(path, state0, dt, duration_s, ...
        speed_mps, cfg, roll_pulse, case_restoring_scale, shadow, mode)
    restoring_snap = [];
    eff_restoring = case_restoring_scale;
    if isfield(shadow.params, 'restoring_scale') && strcmp(shadow.kind, 'restoring_enhanced')
        eff_restoring = shadow.params.restoring_scale;
    end

    if strcmp(shadow.kind, 'active_roll_ideal')
        [out, restoring_snap] = run_ideal_active_roll_closed_loop(path, state0, dt, ...
            duration_s, speed_mps, cfg, roll_pulse, eff_restoring, ...
            shadow.params.ideal_rate_gain, mode);
        return;
    end

    [out, restoring_snap] = run_passive_roll_closed_loop(path, state0, dt, duration_s, ...
        speed_mps, cfg, roll_pulse, eff_restoring);
end

function chunk_s = ideal_active_roll_chunk_s(mode, duration_s, dt)
    switch mode
        case 'smoke'
            chunk_s = duration_s;
        otherwise
            chunk_s = max(dt, min(2.0, duration_s / 10));
    end
end

function [out, restoring_snap] = run_ideal_active_roll_closed_loop(path, state0, dt, ...
        duration_s, speed_mps, cfg, roll_pulse, restoring_scale, ideal_rate_gain, mode)
    global Ixx
    restoring_snap = [];
    if abs(restoring_scale - 1.0) > 1e-9
        restoring_snap = apply_restoring_scale(restoring_scale);
    end

    pulse = normalize_roll_pulse(roll_pulse);
    chunk_s = ideal_active_roll_chunk_s(mode, duration_s, dt);
    n_chunks = max(1, ceil(duration_s / chunk_s));
    chunk_s = duration_s / n_chunks;

    state = state0;
    outs = cell(n_chunks, 1);
    t_elapsed = 0.0;
    pulse_applied = false;

    for k = 1:n_chunks
        if pulse.enabled && ~pulse_applied && t_elapsed >= pulse.start_s - 1e-9
            delta_p = pulse.K_Nm * pulse.duration_s / Ixx;
            state(10) = state(10) + delta_p;
            pulse_applied = true;
        end

        seg = closed_loop_actuator_realism_case(path, state, dt, chunk_s, speed_mps, cfg);
        if ~isempty(seg.error)
            out = seg;
            out.complete = false;
            return;
        end

        state = extract_state_from_out(seg);
        state(10) = state(10) * exp(-ideal_rate_gain * chunk_s);

        outs{k} = seg;
        t_elapsed = t_elapsed + chunk_s;
    end

    out = outs{1};
    for k = 2:n_chunks
        out = stitch_segment_outputs(out, outs{k}, dt);
    end
    out.error = '';
    out.complete = size(out.position, 1) >= round(duration_s / dt);
end

function [out, restoring_snap] = run_passive_roll_closed_loop(path, state0, dt, ...
        duration_s, speed_mps, cfg, roll_pulse, restoring_scale)
    restoring_snap = [];
    if abs(restoring_scale - 1.0) > 1e-9
        restoring_snap = apply_restoring_scale(restoring_scale);
    end

    pulse = normalize_roll_pulse(roll_pulse);
    if pulse.enabled && pulse.start_s > 1e-9 && pulse.start_s < duration_s - dt
        t_pre = pulse.start_s;
        t_post = duration_s - t_pre;
        out1 = closed_loop_actuator_realism_case(path, state0, dt, t_pre, speed_mps, cfg);
        if ~isempty(out1.error)
            out = out1;
            out.complete = false;
            return;
        end
        state_mid = extract_state_from_out(out1);
        global Ixx
        delta_p = pulse.K_Nm * pulse.duration_s / Ixx;
        state_mid(10) = state_mid(10) + delta_p;
        out2 = closed_loop_actuator_realism_case(path, state_mid, dt, t_post, speed_mps, cfg);
        if ~isempty(out2.error)
            out = out2;
            out.complete = false;
            return;
        end
        out = stitch_segment_outputs(out1, out2, dt);
        out.error = '';
        out.complete = size(out.position, 1) >= round(duration_s / dt);
        return;
    end

    out = closed_loop_actuator_realism_case(path, state0, dt, duration_s, speed_mps, cfg);
end

function pulse = normalize_roll_pulse(roll_pulse)
    pulse = struct('enabled', false, 'K_Nm', 0.0, 'start_s', 0.0, 'duration_s', 0.0);
    if isempty(roll_pulse) || ~isstruct(roll_pulse)
        return;
    end
    if isfield(roll_pulse, 'enabled')
        pulse.enabled = logical(roll_pulse.enabled);
    end
    if isfield(roll_pulse, 'K_Nm')
        pulse.K_Nm = double(roll_pulse.K_Nm);
    end
    if isfield(roll_pulse, 'start_s')
        pulse.start_s = double(roll_pulse.start_s);
    end
    if isfield(roll_pulse, 'duration_s')
        pulse.duration_s = double(roll_pulse.duration_s);
    end
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
end

function snap = apply_restoring_scale(scale)
    global W B g_m m
    snap = struct('W', W, 'B', B, 'm', m);
    if abs(scale - 1.0) < 1e-12
        return;
    end
    delta_wb = W - B;
    B = W - scale * delta_wb;
    m = W / g_m;
end

function restore_restoring_params(snap)
    global W B m
    W = snap.W;
    B = snap.B;
    m = snap.m;
end

function save_passive_roll_plots(artifact_dir, plot_specs, screening_band_deg)
    if isempty(plot_specs)
        return;
    end

    n = numel(plot_specs);
    fig = figure('Visible', 'off', 'Position', [60 60 1400 900]);
    tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    case_ids = cell(1, n);
    peak_roll = zeros(1, n);
    peak_p = zeros(1, n);
    residual = zeros(1, n);
    rudder_sat = zeros(1, n);

    for i = 1:n
        spec = plot_specs{i};
        case_ids{i} = spec.case_id;
        peak_roll(i) = spec.metrics.peak_abs_roll_deg;
        peak_p(i) = spec.metrics.peak_abs_roll_rate_dps;
        residual(i) = spec.metrics.residual_roll_deg;
        rudder_sat(i) = spec.metrics.rudder_saturation_pct;
    end

    ax1 = nexttile;
    bar(ax1, peak_roll, 'FaceColor', [0.25 0.45 0.75]);
    ylabel(ax1, 'peak |roll| [deg]');
    title(ax1, 'Peak roll angle');
    grid(ax1, 'on');

    ax2 = nexttile;
    bar(ax2, peak_p, 'FaceColor', [0.85 0.45 0.2]);
    ylabel(ax2, 'peak |p| [deg/s]');
    title(ax2, 'Peak roll rate');
    grid(ax2, 'on');

    ax3 = nexttile;
    bar(ax3, residual, 'FaceColor', [0.35 0.65 0.45]);
    yline(ax3, screening_band_deg, 'r--', 'LineWidth', 1.1);
    ylabel(ax3, 'residual |roll| [deg]');
    title(ax3, 'Residual roll (last settle window)');
    grid(ax3, 'on');

    ax4 = nexttile;
    bar(ax4, rudder_sat, 'FaceColor', [0.55 0.35 0.65]);
    ylabel(ax4, 'rudder sat [%]');
    title(ax4, 'Rudder saturation (settled)');
    grid(ax4, 'on');

    for ax = [ax1, ax2, ax3, ax4]
        xticks(ax, 1:n);
        xticklabels(ax, case_ids);
        xtickangle(ax, 45);
    end

    sgtitle(fig, 'Passive roll stress (certified=false)', 'FontWeight', 'bold');

    out_png = fullfile(artifact_dir, 'passive_roll_stress.png');
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, out_png, 'Resolution', 150);
    else
        saveas(fig, out_png);
    end
    close(fig);
end

function save_roll_rate_audit_plots(artifact_dir, case_results, shadow_catalog, rate_threshold_dps)
    shadow_ids = cellfun(@(s) s.shadow_id, shadow_catalog, 'UniformOutput', false);
    n_cases = numel(case_results);
    n_shadows = numel(shadow_ids);

    peak_rate = nan(n_cases, n_shadows);
    case_ids = cell(n_cases, 1);

    for ci = 1:n_cases
        case_ids{ci} = case_results{ci}.case_id;
        for si = 1:n_shadows
            for k = 1:numel(case_results{ci}.shadows)
                sh = case_results{ci}.shadows{k};
                if strcmp(sh.shadow_id, shadow_ids{si}) && strcmp(sh.status, 'ok')
                    peak_rate(ci, si) = sh.metrics.peak_abs_roll_rate_dps;
                end
            end
        end
    end

    fig = figure('Visible', 'off', 'Position', [60 60 1400 900]);
    tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

    ax1 = nexttile;
    bar(ax1, peak_rate, 'grouped');
    yline(ax1, rate_threshold_dps, 'r--', 'LineWidth', 1.2, 'Label', '45 deg/s gate');
    ylabel(ax1, 'peak |p| [deg/s]');
    title(ax1, 'Shadow solution peak roll rate by case');
    legend(ax1, shadow_ids, 'Location', 'northeast', 'FontSize', 7);
    grid(ax1, 'on');
    xticks(ax1, 1:n_cases);
    xticklabels(ax1, case_ids);
    xtickangle(ax1, 45);

    ax2 = nexttile;
    mean_rate = mean(peak_rate, 1, 'omitnan');
    bar(ax2, mean_rate, 'FaceColor', [0.35 0.55 0.75]);
    yline(ax2, rate_threshold_dps, 'r--', 'LineWidth', 1.2);
    ylabel(ax2, 'mean peak |p| [deg/s]');
    title(ax2, 'Mean peak roll rate per shadow solution');
    grid(ax2, 'on');
    xticks(ax2, 1:n_shadows);
    xticklabels(ax2, shadow_ids);
    xtickangle(ax2, 45);

    sgtitle(fig, 'Roll-rate solution audit (certified=false)', 'FontWeight', 'bold');

    out_png = fullfile(artifact_dir, 'roll_rate_solution_audit.png');
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, out_png, 'Resolution', 150);
    else
        saveas(fig, out_png);
    end
    close(fig);
end

function write_json_payload(json_path, payload)
    fid = fopen(json_path, 'w');
    if fid < 0
        error('auv_roll_validation_runner:WriteFailed', ...
            'Could not open %s for writing.', json_path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    sanitized = auv_roll_metric_registry('sanitize_json', payload);
    fprintf(fid, '%s', jsonencode(sanitized, 'PrettyPrint', true));
end

function log_runner_write(harness, json_path, payload)
    switch harness
        case 'passive_roll_stress'
            fprintf(['Wrote %s (%d cases, %.1f s, execution_pass=%d, screening_pass=%d, ', ...
                'recommendation=%s)\n'], json_path, numel(payload.cases), payload.runtime_s, ...
                payload.execution_pass, payload.screening_pass, payload.recommendation);
        case 'roll_rate_solution_audit'
            n_shadows = payload.matrix_caps.n_shadows;
            fprintf(['Wrote %s (%d cases, %d shadows, %.1f s, execution_pass=%d, ', ...
                'decision=%s)\n'], json_path, numel(payload.cases), n_shadows, ...
                payload.runtime_s, payload.execution_pass, payload.decision);
    end
end

function v = get_opt(opts, name, default_value)
    if isfield(opts, name) && ~isempty(opts.(name))
        v = opts.(name);
    else
        v = default_value;
    end
end

function assert_all_finite(varargin)
    auv_roll_metric_registry('assert_finite', varargin{:});
end
