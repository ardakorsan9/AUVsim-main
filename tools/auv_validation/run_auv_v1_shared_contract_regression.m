function run_auv_v1_shared_contract_regression(mode)
%RUN_AUV_V1_SHARED_CONTRACT_REGRESSION  Shared result-contract regression.
%   Normalizes existing SIM9/SIM10 roll JSON artifacts into the shared
%   contract, validates them, and exercises explicit negative tests.
%   mode: 'smoke' or 'full' (same contract code; full adds extra negatives).

    if nargin < 1 || isempty(mode)
        mode = 'full';
    end
    mode = lower(char(string(mode)));
    if ~any(strcmp(mode, {'smoke', 'full'}))
        error('run_auv_v1_shared_contract_regression:InvalidMode', ...
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
        error('run_auv_v1_shared_contract_regression:MissingSim9', ...
            'Required SIM9 artifact missing: %s', sim9_path);
    end
    if ~isfile(sim10_path)
        error('run_auv_v1_shared_contract_regression:MissingSim10', ...
            'Required SIM10 artifact missing: %s', sim10_path);
    end

    contract = auv_result_contract();
    sim9_hash_before = file_sha256(sim9_path);
    sim10_hash_before = file_sha256(sim10_path);

    [sim9_norm, sim9_info] = auv_normalize_roll_artifact(sim9_path);
    [sim10_norm, sim10_info] = auv_normalize_roll_artifact(sim10_path);

    [sim9_ok, sim9_report] = auv_validate_result(sim9_norm, contract);
    [sim10_ok, sim10_report] = auv_validate_result(sim10_norm, contract);

    negative_tests = run_negative_contract_tests(mode);

    sim9_hash_after = file_sha256(sim9_path);
    sim10_hash_after = file_sha256(sim10_path);
    sources_unchanged = strcmp(sim9_hash_before, sim9_hash_after) && ...
        strcmp(sim10_hash_before, sim10_hash_after);

    all_negative_rejected = all([negative_tests.pass]);
    regression_pass = sim9_ok && sim10_ok && all_negative_rejected && sources_unchanged;

    payload = struct();
    payload.schema = 'auv_v1_shared_contract_regression_v1';
    payload.mode = mode;
    payload.contract_schema = contract.schema;
    payload.contract_version = contract.version;
    payload.runtime_s = toc(t_start);
    payload.regression_pass = regression_pass;
    payload.sources_unchanged = sources_unchanged;
    payload.positive_tests = struct( ...
        'sim9', struct( ...
            'source_path', rel_path(sim9_path, proj_root), ...
            'normalize_ok', true, ...
            'validate_ok', sim9_ok, ...
            'n_cases', sim9_info.n_cases, ...
            'errors', {sim9_report.errors}), ...
        'sim10', struct( ...
            'source_path', rel_path(sim10_path, proj_root), ...
            'normalize_ok', true, ...
            'validate_ok', sim10_ok, ...
            'n_cases', sim10_info.n_cases, ...
            'errors', {sim10_report.errors}));
    payload.negative_tests = negative_tests;
    payload.note = ['Shared contract regression only; certified=false. ', ...
        'Source SIM9/SIM10 artifacts are read-only inputs.'];

    out_path = fullfile(artifact_dir, 'shared_contract_regression.json');
    write_json(out_path, payload);

    fprintf(['Wrote %s (mode=%s, regression_pass=%d, sim9_ok=%d, sim10_ok=%d, ', ...
        'negative_rejects=%d/%d, sources_unchanged=%d)\n'], ...
        out_path, mode, regression_pass, sim9_ok, sim10_ok, ...
        sum([negative_tests.pass]), numel(negative_tests), sources_unchanged);

    if ~regression_pass
        error('run_auv_v1_shared_contract_regression:Failed', ...
            'Shared contract regression failed (see %s).', out_path);
    end
end

function tests = run_negative_contract_tests(mode)
    contract = auv_result_contract();
    tests = struct('name', {}, 'class', {}, 'pass', {}, 'detail', {});

    tests(end + 1) = negative_test_struct_mismatch(contract); %#ok<AGROW>
    tests(end + 1) = negative_test_row_column_mismatch(contract); %#ok<AGROW>
    tests(end + 1) = negative_test_uncertified_claim(contract); %#ok<AGROW>

    if strcmp(mode, 'full')
        tests(end + 1) = negative_test_nonfinite_metrics(contract); %#ok<AGROW>
        tests(end + 1) = negative_test_missing_section(contract); %#ok<AGROW>
    end
end

function test = negative_test_struct_mismatch(contract)
    sample = auv_result_contract('template');
    sample.meta.schema = contract.schema;
    sample.meta.contract_version = contract.version;
    sample.meta.certified = false;
    sample.meta.source_schema = 'auv_v1_passive_roll_stress_v1';
    sample.meta.scenario = 'negative_test';
    sample.meta.mode = 'smoke';
    sample.meta.seed = 1;
    sample.meta.artifact_kind = 'passive_roll_stress_rollup';
    sample.time.dt_s = 0.025;
    sample.time.n_samples = 0;
    sample.screening.execution_pass = true;
    sample.screening.screening_pass = false;
    sample.screening.thresholds = struct('peak_abs_roll_rate_dps', 45);
    sample.provenance.source_path = 'synthetic';
    sample.provenance.source_schema = sample.meta.source_schema;
    sample.provenance.normalized_utc = '1970-01-01T00:00:00Z';
    sample.provenance.note = 'negative test';

    row_a = struct('case_id', 'a', 'status', 'ok', 'shadow_id', 'baseline', ...
        'peak_abs_roll_deg', 1.0, 'peak_abs_roll_rate_dps', 2.0, ...
        'residual_roll_deg', 0.1, 'all_finite', true);
    row_b = struct('case_id', 'b', 'status', 'ok', 'extra_field', 99);
    sample.metrics.cases = {row_a, row_b};

    [ok, report] = auv_validate_result(sample, contract);
    test = struct('name', 'heterogeneous_metrics_struct_array', ...
        'class', 'struct_mismatch', ...
        'pass', ~ok, ...
        'detail', strjoin(report.errors, '; '));
end

function test = negative_test_row_column_mismatch(contract)
    sample = auv_result_contract('template');
    sample.meta.schema = contract.schema;
    sample.meta.contract_version = contract.version;
    sample.meta.certified = false;
    sample.meta.source_schema = 'auv_v1_passive_roll_stress_v1';
    sample.meta.scenario = 'negative_test';
    sample.meta.mode = 'smoke';
    sample.meta.seed = 1;
    sample.meta.artifact_kind = 'timeseries';
    sample.time.t_s = (0:3)';
    sample.time.dt_s = 0.025;
    sample.time.n_samples = 4;
    sample.truth.position_ned_m = rand(4, 3);
    sample.truth.attitude_rad = rand(4, 3);
    sample.truth.velocity_body_mps = rand(4, 3);
    sample.truth.rates_body_rps = rand(4, 3);
    sample.sensors.attitude_rad = rand(4, 3);
    sample.sensors.angular_rate_body_rps = rand(4, 3);
    sample.sensors.depth_m = rand(4, 1);
    sample.commands.elevator_rad = rand(4, 1);
    sample.commands.rudder_rad = rand(4, 1);
    sample.commands.thrust_n = rand(4, 1);
    sample.actuators.applied_elevator_rad = rand(4, 1);
    sample.actuators.applied_rudder_rad = rand(1, 4);
    sample.metrics.cases = struct( ...
        'case_id', 'row_col', 'status', 'ok', 'shadow_id', 'baseline', ...
        'peak_abs_roll_deg', 1.0, 'peak_abs_roll_rate_dps', 2.0, ...
        'residual_roll_deg', 0.1, 'all_finite', true);
    sample.screening.execution_pass = true;
    sample.screening.screening_pass = true;
    sample.screening.thresholds = struct('peak_abs_roll_rate_dps', 45);
    sample.provenance.source_path = 'synthetic';
    sample.provenance.source_schema = sample.meta.source_schema;
    sample.provenance.normalized_utc = '1970-01-01T00:00:00Z';
    sample.provenance.note = 'negative test';

    [ok, report] = auv_validate_result(sample, contract);
    test = struct('name', 'actuator_row_column_orientation_mismatch', ...
        'class', 'row_column_mismatch', ...
        'pass', ~ok, ...
        'detail', strjoin(report.errors, '; '));
end

function test = negative_test_uncertified_claim(contract)
    sample = auv_result_contract('template');
    sample.meta.schema = contract.schema;
    sample.meta.contract_version = contract.version;
    sample.meta.certified = true;
    sample.meta.source_schema = 'auv_v1_passive_roll_stress_v1';
    sample.meta.scenario = 'negative_test';
    sample.meta.mode = 'smoke';
    sample.meta.seed = 1;
    sample.meta.artifact_kind = 'passive_roll_stress_rollup';
    sample.time.dt_s = 0.025;
    sample.time.n_samples = 0;
    sample.metrics.cases = struct( ...
        'case_id', 'claim', 'status', 'ok', 'shadow_id', 'baseline', ...
        'peak_abs_roll_deg', 1.0, 'peak_abs_roll_rate_dps', 2.0, ...
        'residual_roll_deg', 0.1, 'all_finite', true);
    sample.screening.execution_pass = true;
    sample.screening.screening_pass = true;
    sample.screening.thresholds = struct('peak_abs_roll_rate_dps', 45);
    sample.provenance.source_path = 'synthetic';
    sample.provenance.source_schema = sample.meta.source_schema;
    sample.provenance.normalized_utc = '1970-01-01T00:00:00Z';
    sample.provenance.note = 'negative test';

    [ok, report] = auv_validate_result(sample, contract);
    test = struct('name', 'uncertified_claim_rejected', ...
        'class', 'uncertified_claim', ...
        'pass', ~ok, ...
        'detail', strjoin(report.errors, '; '));
end

function test = negative_test_nonfinite_metrics(contract)
    sample = auv_result_contract('template');
    sample.meta.schema = contract.schema;
    sample.meta.contract_version = contract.version;
    sample.meta.certified = false;
    sample.meta.source_schema = 'auv_v1_passive_roll_stress_v1';
    sample.meta.scenario = 'negative_test';
    sample.meta.mode = 'full';
    sample.meta.seed = 1;
    sample.meta.artifact_kind = 'passive_roll_stress_rollup';
    sample.time.dt_s = 0.025;
    sample.time.n_samples = 0;
    sample.metrics.cases = struct( ...
        'case_id', 'nan', 'status', 'ok', 'shadow_id', 'baseline', ...
        'peak_abs_roll_deg', NaN, 'peak_abs_roll_rate_dps', 2.0, ...
        'residual_roll_deg', 0.1, 'all_finite', true);
    sample.screening.execution_pass = true;
    sample.screening.screening_pass = true;
    sample.screening.thresholds = struct('peak_abs_roll_rate_dps', 45);
    sample.provenance.source_path = 'synthetic';
    sample.provenance.source_schema = sample.meta.source_schema;
    sample.provenance.normalized_utc = '1970-01-01T00:00:00Z';
    sample.provenance.note = 'negative test';

    [ok, report] = auv_validate_result(sample, contract);
    test = struct('name', 'nonfinite_metric_rejected', ...
        'class', 'nonfinite', ...
        'pass', ~ok, ...
        'detail', strjoin(report.errors, '; '));
end

function test = negative_test_missing_section(contract)
    sample = auv_result_contract('template');
    sample = rmfield(sample, 'provenance');
    sample.meta.schema = contract.schema;
    sample.meta.contract_version = contract.version;
    sample.meta.certified = false;
    sample.meta.source_schema = 'auv_v1_passive_roll_stress_v1';
    sample.meta.scenario = 'negative_test';
    sample.meta.mode = 'full';
    sample.meta.seed = 1;
    sample.meta.artifact_kind = 'passive_roll_stress_rollup';
    sample.time.dt_s = 0.025;
    sample.time.n_samples = 0;
    sample.metrics.cases = struct( ...
        'case_id', 'missing', 'status', 'ok', 'shadow_id', 'baseline', ...
        'peak_abs_roll_deg', 1.0, 'peak_abs_roll_rate_dps', 2.0, ...
        'residual_roll_deg', 0.1, 'all_finite', true);
    sample.screening.execution_pass = true;
    sample.screening.screening_pass = true;
    sample.screening.thresholds = struct('peak_abs_roll_rate_dps', 45);

    [ok, report] = auv_validate_result(sample, contract);
    test = struct('name', 'missing_provenance_section_rejected', ...
        'class', 'missing_field', ...
        'pass', ~ok, ...
        'detail', strjoin(report.errors, '; '));
end

function digest = file_sha256(path)
    fid = fopen(path, 'rb');
    if fid < 0
        error('run_auv_v1_shared_contract_regression:ReadFailed', ...
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
        error('run_auv_v1_shared_contract_regression:WriteFailed', ...
            'Could not open %s for writing.', path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(sanitize_for_json(payload), 'PrettyPrint', true));
end

function s = sanitize_for_json(x)
    if isstruct(x)
        if numel(x) ~= 1
            parts = cell(1, numel(x));
            for ii = 1:numel(x)
                parts{ii} = sanitize_for_json(x(ii));
            end
            s = [parts{:}];
            return;
        end
        s = struct();
        names = fieldnames(x);
        for i = 1:numel(names)
            s.(names{i}) = sanitize_for_json(x.(names{i}));
        end
        return;
    end
    if iscell(x)
        s = cell(size(x));
        for i = 1:numel(x)
            s{i} = sanitize_for_json(x{i});
        end
        return;
    end
    if isnumeric(x)
        if isempty(x)
            s = x;
            return;
        end
        x2 = double(x);
        x2(~isfinite(x2)) = NaN;
        s = x2;
        return;
    end
    if islogical(x) || ischar(x) || isstring(x)
        s = x;
        return;
    end
    s = x;
end
