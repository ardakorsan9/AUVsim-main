function [normalized, info] = auv_normalize_roll_artifact(source_path, artifact)
%AUV_NORMALIZE_ROLL_ARTIFACT  Map SIM9/SIM10 roll JSON into shared contract.
%   [normalized, info] = auv_normalize_roll_artifact(source_path)
%   [normalized, info] = auv_normalize_roll_artifact('', artifact_struct)
%   Does not modify the source artifact file.

    if nargin < 2
        artifact = [];
    end

    if nargin < 1 || isempty(source_path)
        source_path = '';
    end

    if isempty(artifact)
        if isempty(source_path) || ~isfile(source_path)
            error('auv_normalize_roll_artifact:MissingSource', ...
                'source_path must reference an existing JSON artifact.');
        end
        artifact = jsondecode(fileread(source_path));
    end

    if ~isstruct(artifact) || numel(artifact) ~= 1
        error('auv_normalize_roll_artifact:InvalidArtifact', ...
            'artifact must be a scalar struct decoded from roll JSON.');
    end

    if ~isfield(artifact, 'schema')
        error('auv_normalize_roll_artifact:MissingSchema', ...
            'artifact.schema is required.');
    end

    contract = auv_result_contract();
    normalized = auv_result_contract('template');

    normalized.meta.schema = contract.schema;
    normalized.meta.contract_version = contract.version;
    normalized.meta.certified = false;
    normalized.meta.source_schema = char(string(artifact.schema));
    normalized.meta.scenario = get_char_field(artifact, 'scenario', '');
    normalized.meta.mode = get_char_field(artifact, 'mode', '');
    normalized.meta.seed = get_numeric_scalar(artifact, 'seed', NaN);

    switch normalized.meta.source_schema
        case 'auv_v1_passive_roll_stress_v1'
            normalized.meta.artifact_kind = 'passive_roll_stress_rollup';
            normalized = fill_from_passive_roll_stress(normalized, artifact);
        case 'auv_v1_roll_rate_solution_audit_v1'
            normalized.meta.artifact_kind = 'roll_rate_solution_audit_rollup';
            normalized = fill_from_roll_rate_audit(normalized, artifact);
        otherwise
            error('auv_normalize_roll_artifact:UnsupportedSchema', ...
                'Unsupported artifact schema: %s', normalized.meta.source_schema);
    end

    normalized.provenance.source_path = char(string(source_path));
    normalized.provenance.source_schema = normalized.meta.source_schema;
    normalized.provenance.normalized_utc = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    normalized.provenance.note = get_char_field(artifact, 'note', '');

    info = struct();
    info.source_schema = normalized.meta.source_schema;
    info.n_cases = numel(normalized.metrics.cases);
    info.has_timeseries = normalized.time.n_samples > 0;
end

function result = fill_from_passive_roll_stress(result, artifact)
    result.time.t_s = zeros(0, 1);
    result.time.dt_s = get_numeric_scalar(artifact, 'dt', NaN);
    result.time.n_samples = 0;

    result.screening.execution_pass = logical(get_field_or(artifact, 'execution_pass', false));
    result.screening.screening_pass = logical(get_field_or(artifact, 'screening_pass', false));
    if isfield(artifact, 'screening_thresholds')
        result.screening.thresholds = artifact.screening_thresholds;
    end

    if ~isfield(artifact, 'cases')
        error('auv_normalize_roll_artifact:MissingCases', 'SIM9 artifact missing cases.');
    end

    rows = repmat(empty_case_row(), 0, 1);
    for i = 1:numel(artifact.cases)
        c = artifact.cases(i);
        row = empty_case_row();
        row.case_id = get_char_field(c, 'case_id', sprintf('case_%d', i));
        row.status = get_char_field(c, 'status', 'unknown');
        row.shadow_id = 'baseline';
        row.domain = get_char_field(c, 'domain', '');
        if isfield(c, 'metrics') && isstruct(c.metrics)
            row = merge_metrics_row(row, c.metrics);
        end
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
    result.metrics.cases = rows;
end

function result = fill_from_roll_rate_audit(result, artifact)
    result.time.t_s = zeros(0, 1);
    result.time.dt_s = get_numeric_scalar(artifact, 'dt', NaN);
    result.time.n_samples = 0;

    result.screening.execution_pass = logical(get_field_or(artifact, 'execution_pass', false));
    result.screening.screening_pass = logical(get_field_or(artifact, 'screening_pass', false));
    if isfield(artifact, 'screening_thresholds')
        result.screening.thresholds = artifact.screening_thresholds;
    end

    if ~isfield(artifact, 'cases')
        error('auv_normalize_roll_artifact:MissingCases', 'SIM10 artifact missing cases.');
    end

    rows = repmat(empty_case_row(), 0, 1);
    for i = 1:numel(artifact.cases)
        c = artifact.cases(i);
        if ~isfield(c, 'shadows')
            continue;
        end
        shadows = c.shadows;
        if isstruct(shadows) && numel(shadows) > 0
            for j = 1:numel(shadows)
                sh = shadows(j);
                row = empty_case_row();
                row.case_id = get_char_field(c, 'case_id', sprintf('case_%d', i));
                row.status = get_char_field(sh, 'status', 'unknown');
                row.shadow_id = get_char_field(sh, 'shadow_id', '');
                row.domain = get_char_field(c, 'domain', '');
                if isfield(sh, 'metrics') && isstruct(sh.metrics)
                    row = merge_metrics_row(row, sh.metrics);
                end
                rows(end + 1, 1) = row; %#ok<AGROW>
            end
        end
    end
    result.metrics.cases = rows;
end

function row = empty_case_row()
    row = struct( ...
        'case_id', '', ...
        'status', '', ...
        'shadow_id', '', ...
        'domain', '', ...
        'peak_abs_roll_deg', NaN, ...
        'peak_abs_roll_rate_dps', NaN, ...
        'residual_roll_deg', NaN, ...
        'all_finite', false, ...
        'recovery_time_s', NaN, ...
        'time_outside_band_s', NaN, ...
        'max_heading_error_deg', NaN, ...
        'max_depth_error_m', NaN, ...
        'rudder_saturation_pct', NaN, ...
        'instability_flag', false, ...
        'rate_screening_pass', false);
end

function row = merge_metrics_row(row, metrics)
    fields = fieldnames(metrics);
    for i = 1:numel(fields)
        fname = fields{i};
        if isfield(row, fname)
            row.(fname) = metrics.(fname);
        end
    end
end

function v = get_field_or(s, fname, default_value)
    if isfield(s, fname)
        v = s.(fname);
    else
        v = default_value;
    end
end

function v = get_char_field(s, fname, default_value)
    if isfield(s, fname)
        v = char(string(s.(fname)));
    else
        v = default_value;
    end
end

function v = get_numeric_scalar(s, fname, default_value)
    if isfield(s, fname)
        v = double(s.(fname));
        if ~isscalar(v)
            v = v(1);
        end
    else
        v = default_value;
    end
end
