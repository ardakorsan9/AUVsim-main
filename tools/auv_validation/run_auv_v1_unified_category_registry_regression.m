function report = run_auv_v1_unified_category_registry_regression(mode)
%RUN_AUV_V1_UNIFIED_CATEGORY_REGISTRY_REGRESSION  Registry/loader regression gate.
%   report = run_auv_v1_unified_category_registry_regression()
%   report = run_auv_v1_unified_category_registry_regression('smoke')
%   report = run_auv_v1_unified_category_registry_regression('full')

    if nargin < 1 || isempty(mode)
        mode = 'full';
    end
    mode = char(string(mode));

    t_start = tic;
    project_root = pwd;
    out_path = fullfile(project_root, 'artifacts', 'robustness_v2', ...
        'unified_category_registry_regression.json');

    registry = auv_simulation_category_registry();
    all_ids = auv_simulation_category_registry('categories');
    if strcmp(mode, 'smoke')
        category_ids = {'nominal', 'passive_roll_stress'};
    else
        category_ids = all_ids;
    end

    baseline_hashes = capture_baseline_hashes(project_root, all_ids);
    category_results = struct();
    load_errors = {};

    for i = 1:numel(category_ids)
        cid = category_ids{i};
        key = matlab.lang.makeValidName(cid);
        item = struct('category_id', cid, 'load_ok', false, 'validate_ok', false, ...
            'artifact_path', '', 'artifact_sha256', '', 'n_cases', 0, 'errors', {{}});
        try
            loaded = auv_load_simulation_result(cid, project_root);
            item.load_ok = true;
            item.validate_ok = loaded.validate_ok;
            item.artifact_path = loaded.artifact_path;
            item.artifact_sha256 = loaded.artifact_sha256;
            item.n_cases = numel(loaded.result.metrics.cases);
        catch err
            item.errors = {err.message};
            load_errors{end + 1} = sprintf('%s: %s', cid, err.message); %#ok<AGROW>
        end
        category_results.(key) = item;
    end

    post_hashes = capture_baseline_hashes(project_root, all_ids);
    sources_unchanged = isequal(baseline_hashes, post_hashes);
    negative_tests = run_negative_tests(mode);

    regression_pass = isempty(load_errors) && sources_unchanged && all_negative_pass(negative_tests);
    if strcmp(mode, 'full')
        regression_pass = regression_pass && numel(category_ids) == numel(all_ids);
    end

    report = struct();
    report.schema = 'auv_v1_unified_category_registry_regression_v1';
    report.mode = mode;
    report.registry_schema = registry.schema;
    report.registry_version = registry.version;
    report.contract_schema = registry.contract_schema;
    report.contract_version = registry.contract_version;
    report.runtime_s = toc(t_start);
    report.regression_pass = regression_pass;
    report.sources_unchanged = sources_unchanged;
    report.categories = category_results;
    report.baseline_hashes = baseline_hashes;
    report.negative_tests = negative_tests;
    report.note = 'Unified category registry regression; certified=false. Frozen artifacts are read-only inputs.';

    write_regression_json(out_path, report);

    if ~regression_pass
        error('run_auv_v1_unified_category_registry_regression:Failed', ...
            'unified category registry regression failed (mode=%s)', mode);
    end
end

function hashes = capture_baseline_hashes(project_root, category_ids)
    hashes = struct();
    for i = 1:numel(category_ids)
        cid = category_ids{i};
        entry = auv_simulation_category_registry('resolve', cid);
        path = fullfile(project_root, entry.artifact_path);
        key = matlab.lang.makeValidName(cid);
        hashes.(key) = struct( ...
            'artifact_path', entry.artifact_path, ...
            'artifact_sha256', file_sha256_local(path));
    end
end

function tests = run_negative_tests(mode)
    tests = {};

    tests{end + 1} = expect_error( ...
        'unknown_category_rejected', ...
        'unknown_category', ...
        @() auv_load_simulation_result('not_a_real_category')); %#ok<AGROW>

    if strcmp(mode, 'full')
        contract = auv_result_contract();
        tests{end + 1} = validator_rejects( ...
            'heterogeneous_metrics_struct_array', ...
            'struct_mismatch', ...
            build_bad_result(@bad_metrics_cell_array), contract); %#ok<AGROW>
        tests{end + 1} = validator_rejects( ...
            'uncertified_claim_rejected', ...
            'uncertified_claim', ...
            build_bad_result(@bad_certified_claim), contract); %#ok<AGROW>
        tests{end + 1} = validator_rejects( ...
            'nonfinite_metric_rejected', ...
            'nonfinite', ...
            build_bad_result(@bad_nonfinite_metric), contract); %#ok<AGROW>
        tests{end + 1} = validator_rejects( ...
            'missing_provenance_section_rejected', ...
            'missing_field', ...
            build_bad_result(@drop_provenance), contract); %#ok<AGROW>
    end
end

function test = expect_error(name, class_name, thunk)
    test = struct('name', name, 'class', class_name, 'pass', false, 'detail', '');
    try
        thunk();
        test.detail = 'expected error was not thrown';
    catch err
        test.pass = true;
        test.detail = err.message;
    end
end

function test = validator_rejects(name, class_name, result, contract)
    test = struct('name', name, 'class', class_name, 'pass', false, 'detail', '');
    [ok, report] = auv_validate_result(result, contract);
    if ok
        test.detail = 'validator unexpectedly passed';
    else
        test.pass = true;
        test.detail = strjoin(report.errors, '; ');
    end
end

function result = build_bad_result(mutator)
    loaded = auv_load_simulation_result('passive_roll_stress');
    result = loaded.result;
    result = mutator(result);
end

function result = bad_metrics_cell_array(result)
    result.metrics.cases = {result.metrics.cases(1)};
end

function result = bad_certified_claim(result)
    result.meta.certified = true;
end

function result = bad_nonfinite_metric(result)
    result.metrics.cases(1).peak_abs_roll_deg = NaN;
end

function result = drop_provenance(result)
    result = rmfield(result, 'provenance');
end

function ok = all_negative_pass(tests)
    ok = true;
    for i = 1:numel(tests)
        if ~tests{i}.pass
            ok = false;
            return;
        end
    end
end

function write_regression_json(out_path, report)
    out_dir = fileparts(out_path);
    if ~isfolder(out_dir)
        mkdir(out_dir);
    end
    fid = fopen(out_path, 'w');
    if fid < 0
        error('cannot write regression artifact: %s', out_path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(report));
end

function digest_hex = file_sha256_local(path)
    fid = fopen(path, 'rb');
    if fid < 0
        error('cannot open %s', path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    bytes = fread(fid, inf, 'uint8=>uint8');
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(typecast(bytes, 'int8'));
    raw = typecast(md.digest(), 'uint8');
    digest_hex = lower(reshape(dec2hex(raw, 2), 1, []));
end
