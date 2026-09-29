function report = run_auv_v1_unified_metric_query_regression(mode)
%RUN_AUV_V1_UNIFIED_METRIC_QUERY_REGRESSION  Deterministic metric-query API regression.
%   report = run_auv_v1_unified_metric_query_regression('smoke')
%   report = run_auv_v1_unified_metric_query_regression('full')

    if nargin < 1 || isempty(mode)
        mode = 'full';
    end
    mode = lower(char(mode));
    if ~any(strcmp(mode, {'smoke', 'full'}))
        error('run_auv_v1_unified_metric_query_regression:InvalidMode', ...
            'mode must be smoke or full');
    end

    project_root = pwd;
    t0 = tic;

    report = struct();
    report.schema = 'auv_v1_unified_metric_query_regression_v1';
    report.mode = mode;
    report.query_api_schema = 'auv_v1_simulation_metric_query_api_v1';
    report.query_api_version = '1.0.0';
    report.registry_schema = 'auv_v1_simulation_category_registry_v1';
    report.registry_version = '1.0.0';
    report.contract_schema = 'auv_v1_shared_result_contract_v1';
    report.contract_version = '1.0.0';
    report.positive_queries = {};
    report.negative_tests = {};
    report.listing_checks = {};
    report.regression_pass = true;

    report.listing_checks{end + 1} = run_listing_check(project_root); %#ok<AGROW>

    positive_specs = positive_query_specs(mode);
    for i = 1:numel(positive_specs)
        item = run_positive_query(positive_specs{i}, project_root);
        report.positive_queries{end + 1} = item; %#ok<AGROW>
        if ~item.pass
            report.regression_pass = false;
        end
    end

    negative_specs = negative_test_specs(mode);
    for i = 1:numel(negative_specs)
        item = run_negative_test(negative_specs{i}, project_root);
        report.negative_tests{end + 1} = item; %#ok<AGROW>
        if ~item.pass
            report.regression_pass = false;
        end
    end

    for i = 1:numel(report.listing_checks)
        if ~report.listing_checks{i}.pass
            report.regression_pass = false;
        end
    end

    report.runtime_s = toc(t0);
    report.note = 'Unified metric query regression; certified=false. Frozen artifacts are read-only inputs.';

    out_path = fullfile(project_root, 'artifacts', 'robustness_v2', 'unified_metric_query_regression.json');
    out_dir = fileparts(out_path);
    if ~isfolder(out_dir)
        mkdir(out_dir);
    end
    write_json(out_path, report);

    if ~report.regression_pass
        error('run_auv_v1_unified_metric_query_regression:RegressionFailed', ...
            'unified metric query regression failed');
    end
end

function specs = positive_query_specs(mode)
    specs = { ...
        struct('name', 'nominal_mean_cross_track', ...
            'category_id', 'nominal', 'case_ref', '', 'metric_name', 'mean_cross_track', ...
            'expected_unit', 'm'), ...
        struct('name', 'bounded_current_zero_mean_cross_track', ...
            'category_id', 'bounded_current', 'case_ref', 'zero', 'metric_name', 'mean_cross_track', ...
            'expected_unit', 'm'), ...
        struct('name', 'sensor_rmse_depth_m', ...
            'category_id', 'sensor_noise_dropout', 'case_ref', 'declared_finite_noise', ...
            'metric_name', 'rmse_depth_m', 'expected_unit', 'm'), ...
        struct('name', 'actuator_elevator_mag_sat_pct', ...
            'category_id', 'actuator_limits', 'case_ref', 'ideal', ...
            'metric_name', 'elevator_mag_sat_pct', 'expected_unit', 'percent'), ...
        struct('name', 'roll_stress_peak_abs_roll_deg', ...
            'category_id', 'passive_roll_stress', 'case_ref', 'heel_5_zero', ...
            'metric_name', 'peak_abs_roll_deg', 'expected_unit', 'deg'), ...
        struct('name', 'roll_audit_peak_abs_roll_deg', ...
            'category_id', 'roll_rate_solution_audit', ...
            'case_ref', 'heel_5_zero/baseline', 'metric_name', 'peak_abs_roll_deg', ...
            'expected_unit', 'deg')};

    if strcmp(mode, 'smoke')
        specs = specs([1, 5, 6]);
    end
end

function specs = negative_test_specs(mode)
    specs = { ...
        struct('name', 'unknown_category_rejected', ...
            'class', 'unknown_category', ...
            'fn', @() auv_query_simulation_metric('fetch', 'not_a_real_category', 'mean_cross_track')), ...
        struct('name', 'unknown_case_rejected', ...
            'class', 'unknown_case', ...
            'fn', @() auv_query_simulation_metric('fetch', 'bounded_current', 'missing_case', 'mean_cross_track')), ...
        struct('name', 'unknown_metric_rejected', ...
            'class', 'unknown_metric', ...
            'fn', @() auv_query_simulation_metric('fetch', 'nominal', 'not_a_real_metric')), ...
        struct('name', 'missing_unit_rejected', ...
            'class', 'missing_unit', ...
            'fn', @() auv_query_simulation_metric('fetch', 'nominal', 'travel_est')), ...
        struct('name', 'vector_shape_rejected', ...
            'class', 'shape_mismatch', ...
            'fn', @() auv_query_simulation_metric('fetch', 'bounded_current', 'zero', 'Vc_ned')), ...
        struct('name', 'missing_case_rejected', ...
            'class', 'missing_case', ...
            'fn', @() auv_query_simulation_metric('fetch', 'bounded_current', 'mean_cross_track'))};

    if strcmp(mode, 'smoke')
        specs = specs([1, 5]);
    end
end

function item = run_listing_check(project_root)
    item = struct('name', 'category_case_metric_listing', 'pass', true, 'errors', {{}});
    try
        cats = auv_query_simulation_metric('categories', project_root);
        expected = auv_simulation_category_registry('categories');
        if ~isequal(cats, expected)
            item.pass = false;
            item.errors{end + 1} = 'category listing mismatch'; %#ok<AGROW>
        end

        bounded_cases = auv_query_simulation_metric('cases', 'bounded_current', project_root);
        if ~isequal(bounded_cases, {'zero', 'cross_current', 'oblique_current'})
            item.pass = false;
            item.errors{end + 1} = 'bounded_current case listing mismatch'; %#ok<AGROW>
        end

        nominal_metrics = auv_query_simulation_metric('metrics', 'nominal', project_root);
        if ~any(strcmp(nominal_metrics, 'mean_cross_track'))
            item.pass = false;
            item.errors{end + 1} = 'nominal metrics missing mean_cross_track'; %#ok<AGROW>
        end
    catch err
        item.pass = false;
        item.errors{end + 1} = err.message; %#ok<AGROW>
    end
end

function item = run_positive_query(spec, project_root)
    item = struct();
    item.name = spec.name;
    item.category_id = spec.category_id;
    item.case_ref = spec.case_ref;
    item.metric_name = spec.metric_name;
    item.pass = false;
    item.errors = {};
    item.result = struct();

    try
        if isempty(spec.case_ref)
            result = auv_query_simulation_metric('fetch', spec.category_id, spec.metric_name, project_root);
        else
            result = auv_query_simulation_metric('fetch', spec.category_id, spec.case_ref, ...
                spec.metric_name, project_root);
        end

        checks = {};
        checks{end + 1} = isstruct(result); %#ok<AGROW>
        checks{end + 1} = isfield(result, 'value') && isscalar(result.value) && isfinite(result.value); %#ok<AGROW>
        checks{end + 1} = isfield(result, 'unit') && strcmp(result.unit, spec.expected_unit); %#ok<AGROW>
        checks{end + 1} = isfield(result, 'source_artifact') && ~isempty(result.source_artifact); %#ok<AGROW>
        checks{end + 1} = isfield(result, 'scenario_id') && ~isempty(result.scenario_id); %#ok<AGROW>
        checks{end + 1} = strcmp(result.shape, 'scalar'); %#ok<AGROW>

        item.result = sanitize_result(result);
        item.pass = all([checks{:}]);
        if ~item.pass
            item.errors{end + 1} = 'positive query validation failed'; %#ok<AGROW>
        end
    catch err
        item.errors{end + 1} = err.message; %#ok<AGROW>
    end
end

function item = run_negative_test(spec, ~)
    item = struct();
    item.name = spec.name;
    item.class = spec.class;
    item.pass = false;
    item.detail = '';

    try
        spec.fn();
        item.detail = 'expected error was not thrown';
    catch err
        item.pass = true;
        item.detail = err.message;
    end
end

function out = sanitize_result(result)
    out = struct();
    out.category_id = result.category_id;
    out.case_ref = result.case_ref;
    out.case_id = result.case_id;
    out.shadow_id = result.shadow_id;
    out.metric_name = result.metric_name;
    out.value = result.value;
    out.unit = result.unit;
    out.shape = result.shape;
    out.source_artifact = result.source_artifact;
    out.scenario_id = result.scenario_id;
end

function write_json(path, data)
    encoded = jsonencode(data);
    fid = fopen(path, 'w');
    if fid < 0
        error('run_auv_v1_unified_metric_query_regression:WriteFailed', ...
            'cannot write %s', path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fwrite(fid, encoded, 'char');
end
