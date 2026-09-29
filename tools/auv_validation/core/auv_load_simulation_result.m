function loaded = auv_load_simulation_result(category_id, project_root)
%AUV_LOAD_SIMULATION_RESULT  Strict read-only loader for registered simulation artifacts.
%   loaded = auv_load_simulation_result(category_id)
%   loaded = auv_load_simulation_result(category_id, project_root)
%   Returns category metadata, normalized shared-contract result, raw JSON payload,
%   validation report, and artifact fingerprint. Fails closed on unknown categories,
%   missing files, malformed JSON, non-finite required values, or unit mismatches.

    if nargin < 2 || isempty(project_root)
        project_root = pwd;
    end

    entry = auv_simulation_category_registry('resolve', category_id);
    artifact_path = fullfile(project_root, entry.artifact_path);

    if ~isfile(artifact_path)
        error('auv_load_simulation_result:MissingArtifact', ...
            'missing artifact for category %s: %s', category_id, entry.artifact_path);
    end

    raw_text = fileread(artifact_path);
    try
        raw = jsondecode(raw_text);
    catch decode_err
        error('auv_load_simulation_result:MalformedJson', ...
            'malformed JSON for category %s: %s', category_id, decode_err.message);
    end

    if ~isstruct(raw)
        error('auv_load_simulation_result:MalformedJson', ...
            'artifact root must be a JSON object for category %s', category_id);
    end

    reject_uncertified_claims(raw, category_id);
    validate_declared_units(raw, entry);
    assert_required_metrics_finite(raw, entry);

    contract = auv_result_contract();
    result = normalize_to_contract(raw, entry, artifact_path, contract);
    [validate_ok, report] = auv_validate_result(result, contract);
    if ~validate_ok
        detail = strjoin(report.errors, '; ');
        error('auv_load_simulation_result:ContractValidationFailed', ...
            'contract validation failed for category %s: %s', category_id, detail);
    end

    loaded = struct();
    loaded.category = entry;
    loaded.result = result;
    loaded.raw = raw;
    loaded.validate_ok = validate_ok;
    loaded.validate_report = report;
    loaded.artifact_path = entry.artifact_path;
    loaded.artifact_sha256 = file_sha256(artifact_path);
    loaded.scenario_id = get_char_field(raw, 'scenario', '');
end

function reject_uncertified_claims(raw, category_id)
    if isfield(raw, 'certified') && logical(raw.certified)
        error('auv_load_simulation_result:UncertifiedClaimRejected', ...
            'certified claim rejected for category %s', category_id);
    end
    if isfield(raw, 'approved') && logical(raw.approved)
        error('auv_load_simulation_result:UncertifiedClaimRejected', ...
            'approved claim rejected for category %s', category_id);
    end
    if isfield(raw, 'meta') && isstruct(raw.meta)
        if isfield(raw.meta, 'certified') && logical(raw.meta.certified)
            error('auv_load_simulation_result:UncertifiedClaimRejected', ...
                'meta.certified claim rejected for category %s', category_id);
        end
        if isfield(raw.meta, 'approved') && logical(raw.meta.approved)
            error('auv_load_simulation_result:UncertifiedClaimRejected', ...
                'meta.approved claim rejected for category %s', category_id);
        end
    end
end

function validate_declared_units(raw, entry)
    errors = {};
    errors = [errors, check_field_unit(raw, 'duration_s', entry.units, 'duration_s')];
    errors = [errors, check_field_unit(raw, 'dt', entry.units, 'dt')];
    if isfield(raw, 'schema') && isfield(entry.units, 'peak_abs_roll_deg')
        if ~strcmp(raw.schema, entry.source_schema)
            errors{end + 1} = sprintf('schema mismatch: expected %s', entry.source_schema); %#ok<AGROW>
        end
    end
    if ~isempty(errors)
        error('auv_load_simulation_result:AmbiguousUnits', '%s', strjoin(errors, '; '));
    end
end

function errors = check_field_unit(s, field_name, unit_map, unit_key)
    errors = {};
    if ~isfield(s, field_name)
        return;
    end
    if ~isfield(unit_map, unit_key)
        errors{end + 1} = sprintf('missing declared unit for %s', field_name); %#ok<AGROW>
        return;
    end
    expected = unit_map.(unit_key);
    actual = infer_unit_from_field_name(field_name);
    if ~strcmp(actual, expected)
        errors{end + 1} = sprintf('ambiguous unit for %s (expected %s, inferred %s)', ...
            field_name, expected, actual); %#ok<AGROW>
    end
end

function unit = infer_unit_from_field_name(field_name)
    switch field_name
        case {'dt', 'nav_dt_base', 'settle_t', 'runtime_s', 'duration_s', 'seed'}
            if strcmp(field_name, 'seed')
                unit = 'unitless';
            else
                unit = 's';
            end
            return;
    end
    if endsWith(field_name, '_deg')
        unit = 'deg';
    elseif endsWith(field_name, '_dps')
        unit = 'deg/s';
    elseif endsWith(field_name, '_m') && ~endsWith(field_name, '_mps') && ~endsWith(field_name, '_mps2')
        unit = 'm';
    elseif endsWith(field_name, '_mps')
        unit = 'm/s';
    elseif endsWith(field_name, '_mps2')
        unit = 'm/s^2';
    elseif endsWith(field_name, '_rad')
        unit = 'rad';
    elseif endsWith(field_name, '_rad_s')
        unit = 'rad/s';
    elseif endsWith(field_name, '_s')
        unit = 's';
    elseif endsWith(field_name, '_pct')
        unit = 'percent';
    else
        unit = 'unknown';
    end
end

function assert_required_metrics_finite(raw, entry)
    switch entry.category_id
        case 'nominal'
            assert_finite_block(raw.metrics, 'metrics');
        case 'bounded_current'
            for i = 1:numel(raw.cases)
                assert_finite_block(raw.cases(i).metrics, sprintf('cases(%d).metrics', i));
            end
        case 'sensor_noise_dropout'
            assert_finite_block(raw.path_metrics, 'path_metrics');
            for i = 1:numel(raw.cases)
                assert_finite_block(raw.cases(i).metrics, sprintf('cases(%d).metrics', i));
            end
        case 'actuator_limits'
            for i = 1:numel(raw.cases)
                assert_finite_block(raw.cases(i).path_metrics, sprintf('cases(%d).path_metrics', i));
                assert_finite_block(raw.cases(i).actuator_metrics, sprintf('cases(%d).actuator_metrics', i));
            end
        case 'passive_roll_stress'
            for i = 1:numel(raw.cases)
                assert_finite_block(raw.cases(i).metrics, sprintf('cases(%d).metrics', i));
            end
            assert_finite_block(raw.screening_thresholds, 'screening_thresholds');
        case 'roll_rate_solution_audit'
            for i = 1:numel(raw.cases)
                shadows = raw.cases(i).shadows;
                for j = 1:numel(shadows)
                    assert_finite_block(shadows(j).metrics, ...
                        sprintf('cases(%d).shadows(%d).metrics', i, j));
                end
            end
            assert_finite_block(raw.screening_thresholds, 'screening_thresholds');
    end

    for fname = {'duration_s', 'dt', 'seed', 'runtime_s'}
        f = fname{1};
        if isfield(raw, f)
            assert_finite_block(raw.(f), f);
        end
    end
end

function assert_finite_block(x, path_label)
    if ~isnumeric(x)
        return;
    end
    if ~all(isfinite(x(:)))
        error('auv_load_simulation_result:NonFiniteValue', ...
            'non-finite numeric value at %s', path_label);
    end
end

function result = normalize_to_contract(raw, entry, artifact_path, contract)
    switch entry.category_id
        case {'passive_roll_stress', 'roll_rate_solution_audit'}
            result = normalize_roll_artifact(raw, entry, artifact_path, contract);
        otherwise
            result = normalize_robustness_v1_artifact(raw, entry, artifact_path, contract);
    end
end

function result = normalize_robustness_v1_artifact(raw, entry, artifact_path, contract)
    template = auv_result_contract('template');
    result = template;

    result.meta.schema = contract.schema;
    result.meta.contract_version = contract.version;
    result.meta.certified = false;
    result.meta.source_schema = entry.source_schema;
    result.meta.scenario = get_char_field(raw, 'scenario', '');
    result.meta.mode = 'baseline';
    result.meta.seed = get_numeric_field(raw, 'seed', NaN);
    result.meta.artifact_kind = entry.artifact_kind;

    result.metrics.cases = repmat(empty_metrics_case_row(), 0, 1);

    result.screening.execution_pass = true;
    result.screening.screening_pass = true;
    result.screening.thresholds = struct();

    result.provenance.source_path = entry.artifact_path;
    result.provenance.source_schema = entry.source_schema;
    result.provenance.normalized_utc = utc_now_iso();
    result.provenance.note = get_char_field(raw, 'note', ...
        'Normalized read-only rollup from frozen robustness artifact.');
end

function result = normalize_roll_artifact(raw, entry, artifact_path, contract)
    template = auv_result_contract('template');
    result = template;

    result.meta.schema = contract.schema;
    result.meta.contract_version = contract.version;
    result.meta.certified = false;
    result.meta.source_schema = entry.source_schema;
    result.meta.scenario = get_char_field(raw, 'scenario', '');
    result.meta.mode = get_char_field(raw, 'mode', 'full');
    result.meta.seed = get_numeric_field(raw, 'seed', NaN);
    result.meta.artifact_kind = entry.artifact_kind;

    if strcmp(entry.category_id, 'passive_roll_stress')
        result.metrics.cases = map_passive_roll_cases(raw.cases);
        result.screening.execution_pass = logical(raw.execution_pass);
        result.screening.screening_pass = logical(raw.screening_pass);
        result.screening.thresholds = raw.screening_thresholds;
    else
        result.metrics.cases = map_roll_audit_cases(raw.cases);
        result.screening.execution_pass = logical(raw.execution_pass);
        result.screening.screening_pass = logical(raw.screening_pass);
        result.screening.thresholds = raw.screening_thresholds;
    end

    result.provenance.source_path = entry.artifact_path;
    result.provenance.source_schema = entry.source_schema;
    result.provenance.normalized_utc = utc_now_iso();
    result.provenance.note = get_char_field(raw, 'note', ...
        'Normalized read-only rollup from frozen roll artifact.');
end

function cases = map_passive_roll_cases(raw_cases)
    if ~isstruct(raw_cases) || isempty(raw_cases)
        cases = repmat(empty_metrics_case_row(), 0, 1);
        return;
    end
    n = numel(raw_cases);
    cases = repmat(empty_metrics_case_row(), n, 1);
    for i = 1:n
        src = raw_cases(i);
        m = src.metrics;
        cases(i).case_id = get_char_field(src, 'case_id', sprintf('case_%d', i));
        cases(i).status = get_char_field(src, 'status', 'unknown');
        cases(i).shadow_id = '';
        cases(i).peak_abs_roll_deg = m.peak_abs_roll_deg;
        cases(i).peak_abs_roll_rate_dps = m.peak_abs_roll_rate_dps;
        cases(i).residual_roll_deg = m.residual_roll_deg;
        cases(i).all_finite = logical(m.all_finite);
    end
end

function cases = map_roll_audit_cases(raw_cases)
    if ~isstruct(raw_cases) || isempty(raw_cases)
        cases = repmat(empty_metrics_case_row(), 0, 1);
        return;
    end
    total = 0;
    for i = 1:numel(raw_cases)
        if isfield(raw_cases(i), 'shadows')
            total = total + numel(raw_cases(i).shadows);
        end
    end
    cases = repmat(empty_metrics_case_row(), total, 1);
    idx = 0;
    for i = 1:numel(raw_cases)
        src_case = raw_cases(i);
        if ~isfield(src_case, 'shadows')
            continue;
        end
        for j = 1:numel(src_case.shadows)
            idx = idx + 1;
            shadow = src_case.shadows(j);
            m = shadow.metrics;
            cases(idx).case_id = get_char_field(src_case, 'case_id', sprintf('case_%d', i));
            cases(idx).status = get_char_field(shadow, 'status', 'unknown');
            cases(idx).shadow_id = get_char_field(shadow, 'shadow_id', '');
            cases(idx).peak_abs_roll_deg = m.peak_abs_roll_deg;
            cases(idx).peak_abs_roll_rate_dps = m.peak_abs_roll_rate_dps;
            cases(idx).residual_roll_deg = m.residual_roll_deg;
            cases(idx).all_finite = logical(m.all_finite);
        end
    end
end

function row = empty_metrics_case_row()
    row = struct( ...
        'case_id', '', ...
        'status', '', ...
        'shadow_id', '', ...
        'peak_abs_roll_deg', NaN, ...
        'peak_abs_roll_rate_dps', NaN, ...
        'residual_roll_deg', NaN, ...
        'all_finite', false);
end

function value = get_char_field(s, field_name, default_value)
    if isfield(s, field_name) && (ischar(s.(field_name)) || isstring(s.(field_name)))
        value = char(string(s.(field_name)));
    else
        value = default_value;
    end
end

function value = get_numeric_field(s, field_name, default_value)
    if isfield(s, field_name) && isnumeric(s.(field_name)) && isscalar(s.(field_name))
        value = double(s.(field_name));
    else
        value = default_value;
    end
end

function stamp = utc_now_iso()
    stamp = datestr(datetime('now', 'TimeZone', 'UTC'), 'yyyy-mm-ddTHH:MM:SSZ');
end

function digest_hex = file_sha256(path)
    fid = fopen(path, 'rb');
    if fid < 0
        error('auv_load_simulation_result:MissingArtifact', 'cannot open %s', path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    bytes = fread(fid, inf, 'uint8=>uint8');
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(typecast(bytes, 'int8'));
    raw = typecast(md.digest(), 'uint8');
    digest_hex = lower(reshape(dec2hex(raw, 2), 1, []));
end
