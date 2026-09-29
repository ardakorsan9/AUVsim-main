function run_auv_v1_shared_roll_runner_regression(mode)
%RUN_AUV_V1_SHARED_ROLL_RUNNER_REGRESSION  Shared roll-runner migration regression.
%   Runs SIM9/SIM10 via auv_roll_validation_runner and proves metric/decision
%   equivalence against frozen pre-migration artifacts. Does not modify frozen JSON.
%   mode: 'smoke' or 'full'

    if nargin < 1 || isempty(mode)
        mode = 'full';
    end
    mode = lower(char(string(mode)));
    if ~any(strcmp(mode, {'smoke', 'full'}))
        error('run_auv_v1_shared_roll_runner_regression:InvalidMode', ...
            'mode must be ''smoke'' or ''full''.');
    end

    t_start = tic;
    proj_root = pwd;
    artifact_dir = fullfile(proj_root, 'artifacts', 'robustness_v2');
    if ~exist(artifact_dir, 'dir')
        mkdir(artifact_dir);
    end

    sim9_path = fullfile(artifact_dir, 'passive_roll_stress.json');
    sim10_path = fullfile(artifact_dir, 'roll_rate_solution_audit.json');
    if ~isfile(sim9_path)
        error('run_auv_v1_shared_roll_runner_regression:MissingSim9', ...
            'Required SIM9 artifact missing: %s', sim9_path);
    end
    if ~isfile(sim10_path)
        error('run_auv_v1_shared_roll_runner_regression:MissingSim10', ...
            'Required SIM10 artifact missing: %s', sim10_path);
    end

    registry = auv_roll_metric_registry('registry');
    abs_tol = registry.metric_abs_tol;
    rel_tol = registry.metric_rel_tol;

    sim9_hash_before = file_sha256(sim9_path);
    sim10_hash_before = file_sha256(sim10_path);

    frozen_sim9 = jsondecode(fileread(sim9_path));
    frozen_sim10 = jsondecode(fileread(sim10_path));

    run_opts = struct('write_artifact', false, 'write_plots', false, ...
        'fail_on_execution', false);

    fresh_sim9 = auv_roll_validation_runner('passive_roll_stress', mode, run_opts);
    fresh_sim10 = auv_roll_validation_runner('roll_rate_solution_audit', mode, run_opts);

    sim9_hash_after = file_sha256(sim9_path);
    sim10_hash_after = file_sha256(sim10_path);
    sources_unchanged = strcmp(sim9_hash_before, sim9_hash_after) && ...
        strcmp(sim10_hash_before, sim10_hash_after);

    sim9_cmp = compare_passive_roll_payload(fresh_sim9, frozen_sim9, mode, abs_tol, rel_tol);
    sim10_cmp = compare_audit_payload(fresh_sim10, frozen_sim10, mode, abs_tol, rel_tol);

    regression_pass = sources_unchanged && sim9_cmp.pass && sim10_cmp.pass && ...
        fresh_sim9.execution_pass && fresh_sim10.execution_pass;

    payload = struct();
    payload.schema = 'auv_v1_shared_roll_runner_regression_v1';
    payload.mode = mode;
    payload.runtime_s = toc(t_start);
    payload.regression_pass = regression_pass;
    payload.sources_unchanged = sources_unchanged;
    payload.tolerances = struct('metric_abs_tol', abs_tol, 'metric_rel_tol', rel_tol);
    payload.sim9 = struct( ...
        'frozen_path', rel_path(sim9_path, proj_root), ...
        'comparison_pass', sim9_cmp.pass, ...
        'execution_pass', fresh_sim9.execution_pass, ...
        'screening_pass', fresh_sim9.screening_pass, ...
        'frozen_execution_pass', logical(frozen_sim9.execution_pass), ...
        'frozen_screening_pass', logical(frozen_sim9.screening_pass), ...
        'recommendation_match', sim9_cmp.recommendation_match, ...
        'n_cases_compared', sim9_cmp.n_cases_compared, ...
        'errors', {sim9_cmp.errors});
    payload.sim10 = struct( ...
        'frozen_path', rel_path(sim10_path, proj_root), ...
        'comparison_pass', sim10_cmp.pass, ...
        'execution_pass', fresh_sim10.execution_pass, ...
        'screening_pass', fresh_sim10.screening_pass, ...
        'frozen_execution_pass', logical(frozen_sim10.execution_pass), ...
        'frozen_screening_pass', logical(frozen_sim10.screening_pass), ...
        'decision_match', sim10_cmp.decision_match, ...
        'n_case_shadow_pairs_compared', sim10_cmp.n_pairs_compared, ...
        'errors', {sim10_cmp.errors});
    payload.note = ['Shared roll-runner regression; certified=false. ', ...
        'Frozen SIM9/SIM10 artifacts are read-only baselines.'];

    out_path = fullfile(artifact_dir, 'shared_roll_runner_regression.json');
    write_json(out_path, payload);

    fprintf(['Wrote %s (mode=%s, regression_pass=%d, sim9_cmp=%d, sim10_cmp=%d, ', ...
        'sources_unchanged=%d)\n'], out_path, mode, regression_pass, ...
        sim9_cmp.pass, sim10_cmp.pass, sources_unchanged);

    if ~regression_pass
        error('run_auv_v1_shared_roll_runner_regression:Failed', ...
            'Shared roll-runner regression failed (see %s).', out_path);
    end
end

function cmp = compare_passive_roll_payload(fresh, frozen, mode, abs_tol, rel_tol)
    cmp = struct('pass', true, 'errors', {{}}, 'n_cases_compared', 0, ...
        'recommendation_match', false);

    cmp.errors = [cmp.errors, compare_thresholds(fresh.screening_thresholds, ...
        frozen.screening_thresholds, 'screening_thresholds', abs_tol, rel_tol)];

    if strcmp(mode, 'full')
        if logical(fresh.execution_pass) ~= logical(frozen.execution_pass)
            cmp.errors{end + 1} = sprintf('execution_pass mismatch: fresh=%d frozen=%d', ...
                logical(fresh.execution_pass), logical(frozen.execution_pass)); %#ok<AGROW>
        end
        if logical(fresh.screening_pass) ~= logical(frozen.screening_pass)
            cmp.errors{end + 1} = sprintf('screening_pass mismatch: fresh=%d frozen=%d', ...
                logical(fresh.screening_pass), logical(frozen.screening_pass)); %#ok<AGROW>
        end
    end

    cmp.recommendation_match = strcmp(char(string(fresh.recommendation)), ...
        char(string(frozen.recommendation)));
    if strcmp(mode, 'full') && ~cmp.recommendation_match
        cmp.errors{end + 1} = sprintf('recommendation mismatch: fresh=%s frozen=%s', ...
            char(string(fresh.recommendation)), char(string(frozen.recommendation))); %#ok<AGROW>
    end

    fresh_ids = {fresh.cases.case_id};
    for i = 1:numel(fresh.cases)
        case_id = fresh.cases(i).case_id;
        frozen_idx = find(strcmp({frozen.cases.case_id}, case_id), 1);
        if isempty(frozen_idx)
            cmp.errors{end + 1} = sprintf('missing frozen case_id: %s', case_id); %#ok<AGROW>
            continue;
        end
        fc = fresh.cases(i);
        zc = frozen.cases(frozen_idx);
        cmp.n_cases_compared = cmp.n_cases_compared + 1;

        if ~strcmp(fc.status, zc.status)
            cmp.errors{end + 1} = sprintf('%s status mismatch: fresh=%s frozen=%s', ...
                case_id, fc.status, zc.status); %#ok<AGROW>
        end

        if strcmp(fc.status, 'ok') && isfield(fc, 'metrics') && isfield(zc, 'metrics')
            metric_fields = passive_metric_fields();
            if strcmp(mode, 'smoke')
                % Smoke runs a shorter horizon; compare transient peaks only.
                metric_fields = {'peak_abs_roll_deg', 'peak_abs_roll_rate_dps', ...
                    'all_finite', 'instability_flag', 'screening_band_deg'};
            end
            cmp.errors = [cmp.errors, compare_metric_struct( ...
                fc.metrics, zc.metrics, sprintf('cases(%s).metrics', case_id), ...
                metric_fields, abs_tol, rel_tol)]; %#ok<AGROW>
        end
    end

    if strcmp(mode, 'full') && numel(fresh_ids) ~= numel(frozen.cases)
        cmp.errors{end + 1} = sprintf('case count mismatch: fresh=%d frozen=%d', ...
            numel(fresh_ids), numel(frozen.cases)); %#ok<AGROW>
    end

    if strcmp(mode, 'smoke')
        cmp.pass = isempty(cmp.errors);
    else
        cmp.pass = isempty(cmp.errors) && cmp.recommendation_match;
    end
end

function cmp = compare_audit_payload(fresh, frozen, mode, abs_tol, rel_tol)
    cmp = struct('pass', true, 'errors', {{}}, 'n_pairs_compared', 0, ...
        'decision_match', false);

    cmp.errors = [cmp.errors, compare_thresholds(fresh.screening_thresholds, ...
        frozen.screening_thresholds, 'screening_thresholds', abs_tol, rel_tol)];

    if strcmp(mode, 'full')
        if logical(fresh.execution_pass) ~= logical(frozen.execution_pass)
            cmp.errors{end + 1} = sprintf('execution_pass mismatch: fresh=%d frozen=%d', ...
                logical(fresh.execution_pass), logical(frozen.execution_pass)); %#ok<AGROW>
        end
        if logical(fresh.screening_pass) ~= logical(frozen.screening_pass)
            cmp.errors{end + 1} = sprintf('screening_pass mismatch: fresh=%d frozen=%d', ...
                logical(fresh.screening_pass), logical(frozen.screening_pass)); %#ok<AGROW>
        end
    end

    cmp.decision_match = strcmp(char(string(fresh.decision)), char(string(frozen.decision)));
    if strcmp(mode, 'full') && ~cmp.decision_match
        cmp.errors{end + 1} = sprintf('decision mismatch: fresh=%s frozen=%s', ...
            char(string(fresh.decision)), char(string(frozen.decision))); %#ok<AGROW>
    end

    if strcmp(mode, 'full')
        cmp.errors = [cmp.errors, compare_struct_fields( ...
            fresh.risk_classification, frozen.risk_classification, ...
            {'pattern', 'n_cases', 'n_angle_pass', 'n_rate_pass', 'n_angle_rate_split', ...
            'max_rate_overshoot_dps', 'max_angle_overshoot_deg', 'is_real_v1_safety_concern'}, ...
            'risk_classification', abs_tol, rel_tol)];
    end

    for i = 1:numel(fresh.cases)
        case_id = fresh.cases(i).case_id;
        frozen_idx = find(strcmp({frozen.cases.case_id}, case_id), 1);
        if isempty(frozen_idx)
            cmp.errors{end + 1} = sprintf('missing frozen case_id: %s', case_id); %#ok<AGROW>
            continue;
        end

        fresh_shadows = fresh.cases(i).shadows;
        frozen_shadows = frozen.cases(frozen_idx).shadows;
        for j = 1:numel(fresh_shadows)
            sid = fresh_shadows(j).shadow_id;
            fz = find(strcmp({frozen_shadows.shadow_id}, sid), 1);
            if isempty(fz)
                cmp.errors{end + 1} = sprintf('%s missing frozen shadow_id: %s', ...
                    case_id, sid); %#ok<AGROW>
                continue;
            end
            fs = fresh_shadows(j);
            zs = frozen_shadows(fz);
            cmp.n_pairs_compared = cmp.n_pairs_compared + 1;

            if ~strcmp(fs.status, zs.status)
                cmp.errors{end + 1} = sprintf('%s/%s status mismatch: fresh=%s frozen=%s', ...
                    case_id, sid, fs.status, zs.status); %#ok<AGROW>
            end

            if strcmp(fs.status, 'ok') && isfield(fs, 'metrics') && isfield(zs, 'metrics')
                prefix = sprintf('cases(%s).shadows(%s).metrics', case_id, sid);
                metric_fields = audit_metric_fields();
                if strcmp(mode, 'smoke')
                    metric_fields = {'peak_abs_roll_deg', 'peak_abs_roll_rate_dps', ...
                        'all_finite', 'instability_flag', 'screening_band_deg', ...
                        'rate_threshold_dps', 'rate_screening_pass'};
                end
                cmp.errors = [cmp.errors, compare_metric_struct( ...
                    fs.metrics, zs.metrics, prefix, metric_fields, abs_tol, rel_tol)]; %#ok<AGROW>
            end
        end
    end

    if strcmp(mode, 'full')
        cmp.errors = [cmp.errors, compare_shadow_comparison_summary( ...
            fresh.shadow_comparison, frozen.shadow_comparison, abs_tol, rel_tol)];
    end

    if strcmp(mode, 'smoke')
        cmp.pass = isempty(cmp.errors);
    else
        cmp.pass = isempty(cmp.errors) && cmp.decision_match;
    end
end

function errors = compare_shadow_comparison_summary(fresh, frozen, abs_tol, rel_tol)
    errors = {};
    summary_fields = {'rate_threshold_dps', 'passive_or_damping_sufficient', ...
        'ideal_upper_bound_rate_pass_fraction', 'baseline_shadow_id'};
    errors = [errors, compare_struct_fields(fresh, frozen, summary_fields, ...
        'shadow_comparison', abs_tol, rel_tol)];

    if numel(fresh.per_shadow) ~= numel(frozen.per_shadow)
        errors{end + 1} = sprintf('shadow_comparison.per_shadow count mismatch: %d vs %d', ...
            numel(fresh.per_shadow), numel(frozen.per_shadow)); %#ok<AGROW>
        return;
    end

    per_fields = {'shadow_id', 'n_ok', 'n_rate_pass', 'mean_peak_rate_dps', ...
        'max_peak_rate_dps', 'acceptable_tradeoff', ...
        'reduces_rate_without_coupling_regression'};
    for i = 1:numel(fresh.per_shadow)
        sid = fresh.per_shadow(i).shadow_id;
        j = find(strcmp({frozen.per_shadow.shadow_id}, sid), 1);
        if isempty(j)
            errors{end + 1} = sprintf('missing frozen per_shadow: %s', sid); %#ok<AGROW>
            continue;
        end
        errors = [errors, compare_struct_fields(fresh.per_shadow(i), ...
            frozen.per_shadow(j), per_fields, ...
            sprintf('shadow_comparison.per_shadow(%s)', sid), abs_tol, rel_tol)]; %#ok<AGROW>
    end
end

function errors = compare_thresholds(fresh, frozen, label, abs_tol, rel_tol)
    errors = {};
    if ~isstruct(fresh) || ~isstruct(frozen)
        errors{end + 1} = sprintf('%s must be struct', label); %#ok<AGROW>
        return;
    end
    names = fieldnames(frozen);
    for i = 1:numel(names)
        fname = names{i};
        if ~isfield(fresh, fname)
            errors{end + 1} = sprintf('%s missing field %s', label, fname); %#ok<AGROW>
            continue;
        end
        if ~values_equivalent(fresh.(fname), frozen.(fname), abs_tol, rel_tol)
            errors{end + 1} = sprintf('%s.%s mismatch: fresh=%g frozen=%g', ...
                label, fname, double(fresh.(fname)), double(frozen.(fname))); %#ok<AGROW>
        end
    end
end

function errors = compare_metric_struct(fresh, frozen, prefix, fields, abs_tol, rel_tol)
    errors = {};
    for i = 1:numel(fields)
        fname = fields{i};
        if ~isfield(frozen, fname)
            errors{end + 1} = sprintf('%s missing frozen metric %s', prefix, fname); %#ok<AGROW>
            continue;
        end
        if ~isfield(fresh, fname)
            errors{end + 1} = sprintf('%s missing fresh metric %s', prefix, fname); %#ok<AGROW>
            continue;
        end
        fv = fresh.(fname);
        zv = frozen.(fname);
        if islogical(fv) || islogical(zv)
            if logical(fv) ~= logical(zv)
                errors{end + 1} = sprintf('%s.%s logical mismatch', prefix, fname); %#ok<AGROW>
            end
        elseif isnumeric(fv)
            if ~values_equivalent(fv, zv, abs_tol, rel_tol)
                errors{end + 1} = sprintf('%s.%s numeric mismatch: fresh=%g frozen=%g', ...
                    prefix, fname, double(fv), double(zv)); %#ok<AGROW>
            end
        end
    end
end

function errors = compare_struct_fields(fresh, frozen, fields, label, abs_tol, rel_tol)
    errors = {};
    for i = 1:numel(fields)
        fname = fields{i};
        if ~isfield(frozen, fname)
            continue;
        end
        if ~isfield(fresh, fname)
            errors{end + 1} = sprintf('%s missing field %s', label, fname); %#ok<AGROW>
            continue;
        end
        fv = fresh.(fname);
        zv = frozen.(fname);
        if ischar(fv) || isstring(fv)
            if ~strcmp(char(string(fv)), char(string(zv)))
                errors{end + 1} = sprintf('%s.%s string mismatch', label, fname); %#ok<AGROW>
            end
        elseif islogical(fv) || (isnumeric(fv) && isscalar(fv) && (fv == 0 || fv == 1))
            if logical(fv) ~= logical(zv)
                errors{end + 1} = sprintf('%s.%s logical mismatch', label, fname); %#ok<AGROW>
            end
        elseif isnumeric(fv)
            if ~values_equivalent(fv, zv, abs_tol, rel_tol)
                errors{end + 1} = sprintf('%s.%s numeric mismatch', label, fname); %#ok<AGROW>
            end
        end
    end
end

function ok = values_equivalent(a, b, abs_tol, rel_tol)
    if islogical(a) || islogical(b)
        ok = logical(a) == logical(b);
        return;
    end
    a = double(a);
    b = double(b);
    if ~isfinite(a) && ~isfinite(b)
        ok = true;
        return;
    end
    if xor(~isfinite(a), ~isfinite(b))
        ok = false;
        return;
    end
    scale = max([abs(a), abs(b), 1.0]);
    ok = abs(a - b) <= max(abs_tol, rel_tol * scale);
end

function fields = passive_metric_fields()
    fields = {'peak_abs_roll_deg', 'peak_abs_roll_rate_dps', 'residual_roll_deg', ...
        'all_finite', 'recovery_time_s', 'time_outside_band_s', ...
        'max_heading_error_deg', 'max_depth_error_m', 'mean_heading_error_deg', ...
        'mean_depth_error_m', 'rudder_saturation_pct', 'instability_flag', ...
        'screening_band_deg'};
end

function fields = audit_metric_fields()
    fields = [passive_metric_fields(), {'time_above_rate_threshold_s', ...
        'excursion_during_rate_exceedance_deg', 'peak_rate_during_exceedance_dps', ...
        'rotational_ke_proxy_peak', 'rotational_ke_proxy_integral', ...
        'rate_threshold_dps', 'rate_screening_pass'}];
end

function digest = file_sha256(path)
    fid = fopen(path, 'rb');
    if fid < 0
        error('run_auv_v1_shared_roll_runner_regression:ReadFailed', ...
            'Could not read %s', path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    bytes = fread(fid, inf, 'uint8=>uint8');
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(typecast(bytes, 'int8'));
    raw = typecast(md.digest(), 'uint8');
    digest = lower(reshape(dec2hex(raw, 2), 1, []));
end

function rel = rel_path(abs_path, root)
    abs_path = char(string(abs_path));
    root = char(string(root));
    if startsWith(abs_path, [root filesep])
        rel = abs_path(numel(root) + 2:end);
    else
        rel = abs_path;
    end
    rel = strrep(rel, '\', '/');
end

function write_json(path, payload)
    fid = fopen(path, 'w');
    if fid < 0
        error('run_auv_v1_shared_roll_runner_regression:WriteFailed', ...
            'Could not open %s for writing.', path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    sanitized = auv_roll_metric_registry('sanitize_json', payload);
    fprintf(fid, '%s', jsonencode(sanitized, 'PrettyPrint', true));
end
