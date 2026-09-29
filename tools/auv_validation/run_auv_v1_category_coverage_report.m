function report = run_auv_v1_category_coverage_report(mode)
%RUN_AUV_V1_CATEGORY_COVERAGE_REPORT  Deterministic read-only category coverage report.
%   report = run_auv_v1_category_coverage_report('smoke')
%   report = run_auv_v1_category_coverage_report('full')
%   Uses only auv_simulation_category_registry, auv_load_simulation_result, and
%   auv_query_simulation_metric. Descriptive output only; certified remains false.

    if nargin < 1 || isempty(mode)
        mode = 'full';
    end
    mode = lower(char(mode));
    if ~any(strcmp(mode, {'smoke', 'full'}))
        error('run_auv_v1_category_coverage_report:InvalidMode', ...
            'mode must be smoke or full');
    end

    t_start = tic;
    project_root = pwd;

    registry = auv_simulation_category_registry();
    query_info = auv_query_simulation_metric();

    category_ids = sort(auv_query_simulation_metric('categories'));
    categories = struct();
    global_gaps = {};
    n_load_ok = 0;
    n_with_gaps = 0;
    total_missing_metrics = 0;

    for i = 1:numel(category_ids)
        category_id = category_ids{i};
        [cat_report, cat_gaps, missing_count] = build_category_report( ...
            category_id, mode, project_root);
        categories.(category_id) = cat_report;
        global_gaps = [global_gaps, cat_gaps]; %#ok<AGROW>
        if cat_report.load_ok
            n_load_ok = n_load_ok + 1;
        end
        if ~isempty(cat_gaps)
            n_with_gaps = n_with_gaps + 1;
        end
        total_missing_metrics = total_missing_metrics + missing_count;
    end

    report = struct();
    report.schema = 'auv_v1_category_coverage_report_v1';
    report.mode = mode;
    report.certified = false;
    report.registry_schema = registry.schema;
    report.registry_version = registry.version;
    report.query_api_schema = query_info.schema;
    report.query_api_version = query_info.version;
    report.contract_schema = registry.contract_schema;
    report.contract_version = registry.contract_version;
    report.categories = categories;
    report.summary = struct( ...
        'n_categories', numel(category_ids), ...
        'n_load_ok', n_load_ok, ...
        'n_with_gaps', n_with_gaps, ...
        'total_missing_metrics', total_missing_metrics);
    report.gaps = global_gaps;
    report.runtime_s = toc(t_start);
    report.note = ['Deterministic category coverage and gap report; certified=false. ', ...
        'Read-only unified APIs over frozen artifacts; no performance claims.'];

    out_path = fullfile(project_root, 'artifacts', 'robustness_v2', 'category_coverage_report.json');
    write_json_report(out_path, report);
end

function [cat_report, cat_gaps, missing_count] = build_category_report(category_id, mode, project_root)
    entry = auv_simulation_category_registry('resolve', category_id);
    declared_metrics = sort(auv_simulation_category_registry('declared_metrics', category_id));

    cat_report = struct();
    cat_report.category_id = entry.category_id;
    cat_report.label = entry.label;
    cat_report.family = entry.family;
    cat_report.artifact_kind = entry.artifact_kind;
    cat_report.source_schema = entry.source_schema;
    cat_report.artifact_path = entry.artifact_path;
    cat_report.declared_metrics = declared_metrics;
    cat_report.load_ok = false;
    cat_report.validate_ok = false;
    cat_report.scenario_id = '';
    cat_report.artifact_sha256 = '';
    cat_report.cases = {};
    cat_report.gaps = {};

    cat_gaps = {};
    missing_count = 0;

    try
        loaded = auv_load_simulation_result(category_id, project_root);
        cat_report.load_ok = true;
        cat_report.validate_ok = loaded.validate_ok;
        cat_report.scenario_id = loaded.scenario_id;
        cat_report.artifact_sha256 = loaded.artifact_sha256;
    catch load_err
        gap = make_gap(category_id, '', 'load_failed', load_err.message);
        cat_gaps{end + 1} = gap; %#ok<AGROW>
        cat_report.gaps{end + 1} = gap.detail; %#ok<AGROW>
        return;
    end

    try
        case_refs = auv_query_simulation_metric('cases', category_id, project_root);
    catch case_err
        gap = make_gap(category_id, '', 'case_enumeration_failed', case_err.message);
        cat_gaps{end + 1} = gap; %#ok<AGROW>
        cat_report.gaps{end + 1} = gap.detail; %#ok<AGROW>
        return;
    end

    case_refs = select_case_refs(category_id, case_refs, mode);
    case_rows = cell(1, numel(case_refs));

    for i = 1:numel(case_refs)
        case_ref = case_refs{i};
        [case_row, case_gaps, case_missing] = build_case_report( ...
            category_id, case_ref, declared_metrics, mode, project_root);
        case_rows{i} = case_row;
        cat_gaps = [cat_gaps, case_gaps]; %#ok<AGROW>
        missing_count = missing_count + case_missing;
        for g = 1:numel(case_gaps)
            cat_report.gaps{end + 1} = case_gaps{g}.detail; %#ok<AGROW>
        end
    end

    cat_report.cases = case_rows;
end

function case_refs = select_case_refs(category_id, case_refs, mode)
    case_refs = case_refs(:).';
    supports_root = supports_root_case_ref(category_id);
    if strcmp(mode, 'full')
        if supports_root
            case_refs = unique([{''}, case_refs], 'stable');
        end
        case_refs = sort_case_refs(case_refs);
        return;
    end

  % smoke: category-level plus one representative case when cases exist.
    if isempty(case_refs)
        case_refs = {''};
        return;
    end
    if supports_root
        case_refs = unique([{''}, case_refs(1)], 'stable');
    else
        case_refs = case_refs(1);
    end
end

function tf = supports_root_case_ref(category_id)
    tf = any(strcmp(category_id, { ...
        'nominal', ...
        'sensor_noise_dropout', ...
        'actuator_limits', ...
        'passive_roll_stress', ...
        'roll_rate_solution_audit'}));
end

function refs = sort_case_refs(refs)
    if isempty(refs)
        return;
    end
    empty_mask = cellfun(@(x) isempty(x), refs);
    non_empty = sort(refs(~empty_mask));
    if any(empty_mask)
        refs = [{''}, non_empty];
    else
        refs = non_empty;
    end
end

function [case_row, case_gaps, missing_count] = build_case_report( ...
        category_id, case_ref, declared_metrics, mode, project_root)

    case_row = struct();
    case_row.case_ref = case_ref;
    case_row.present_metrics = {};
    case_row.missing_metrics = {};
    case_row.metrics = {};
    case_gaps = {};
    missing_count = 0;

    try
        if isempty(case_ref)
            present_metrics = auv_query_simulation_metric('metrics', category_id, project_root);
        else
            present_metrics = auv_query_simulation_metric('metrics', category_id, case_ref, project_root);
        end
        present_metrics = sort(present_metrics);
    catch metric_err
        gap = make_gap(category_id, case_ref, 'metric_listing_failed', metric_err.message);
        case_gaps{end + 1} = gap; %#ok<AGROW>
        case_row.missing_metrics = declared_metrics;
        missing_count = numel(declared_metrics);
        return;
    end

    case_row.present_metrics = present_metrics;
    missing_metrics = setdiff(declared_metrics, present_metrics, 'stable');
    case_row.missing_metrics = missing_metrics;
    missing_count = numel(missing_metrics);

    for i = 1:numel(missing_metrics)
        metric_name = missing_metrics{i};
        detail = sprintf('declared metric %s not queryable for case %s', ...
            metric_name, display_case_ref(case_ref));
        gap = make_gap(category_id, case_ref, 'missing_metric', detail);
        case_gaps{end + 1} = gap; %#ok<AGROW>
    end

    if ~strcmp(mode, 'full')
        return;
    end

    metric_rows = cell(1, numel(present_metrics));
    for i = 1:numel(present_metrics)
        metric_name = present_metrics{i};
        try
            if isempty(case_ref)
                fetched = auv_query_simulation_metric('fetch', category_id, metric_name, project_root);
            else
                fetched = auv_query_simulation_metric('fetch', category_id, case_ref, metric_name, project_root);
            end
            metric_rows{i} = struct( ...
                'metric_name', fetched.metric_name, ...
                'unit', fetched.unit, ...
                'value', fetched.value, ...
                'shape', fetched.shape, ...
                'source_artifact', fetched.source_artifact, ...
                'scenario_id', fetched.scenario_id);
        catch fetch_err
            detail = sprintf('metric %s listed but fetch failed: %s', metric_name, fetch_err.message);
            gap = make_gap(category_id, case_ref, 'fetch_failed', detail);
            case_gaps{end + 1} = gap; %#ok<AGROW>
            metric_rows{i} = struct( ...
                'metric_name', metric_name, ...
                'unit', '', ...
                'value', [], ...
                'shape', 'unknown', ...
                'source_artifact', '', ...
                'scenario_id', '', ...
                'fetch_error', fetch_err.message);
        end
    end
    case_row.metrics = metric_rows;
end

function gap = make_gap(category_id, case_ref, gap_type, detail)
    gap = struct();
    gap.category_id = category_id;
    gap.case_ref = case_ref;
    gap.gap_type = gap_type;
    gap.detail = detail;
end

function label = display_case_ref(case_ref)
    if isempty(case_ref)
        label = '<root>';
    else
        label = case_ref;
    end
end

function write_json_report(path, report)
    out_dir = fileparts(path);
    if ~isfolder(out_dir)
        mkdir(out_dir);
    end
    text = jsonencode(report);
    fid = fopen(path, 'w');
    if fid < 0
        error('run_auv_v1_category_coverage_report:WriteFailed', ...
            'could not open %s for writing', path);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', text);
end
