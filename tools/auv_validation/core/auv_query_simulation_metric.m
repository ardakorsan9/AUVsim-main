function out = auv_query_simulation_metric(request, varargin)
%AUV_QUERY_SIMULATION_METRIC  Strict read-only metric query API over the unified registry.
%   ids = auv_query_simulation_metric('categories')
%   cases = auv_query_simulation_metric('cases', category_id)
%   names = auv_query_simulation_metric('metrics', category_id)
%   names = auv_query_simulation_metric('metrics', category_id, case_ref)
%   result = auv_query_simulation_metric('fetch', category_id, metric_name)
%   result = auv_query_simulation_metric('fetch', category_id, case_ref, metric_name)
%   Optional trailing project_root string selects the artifact root directory.
%   Fetch results include value, unit, source_artifact, scenario_id, and shape.
%   Rejects unknown categories, cases, or metrics, ambiguous metric locations,
%   vector/scalar shape mismatches, and metrics without declared units.

    [args, project_root] = parse_args(varargin);

    if nargin < 1 || isempty(request)
        out = api_info();
        return;
    end

    request = char(request);

    switch lower(request)
        case 'categories'
            out = auv_simulation_category_registry('categories');
        case 'cases'
            require_min_args(args, 1, 'cases');
            out = list_cases(args{1}, project_root);
        case 'metrics'
            require_min_args(args, 1, 'metrics');
            if numel(args) >= 2
                out = list_metrics(args{1}, args{2}, project_root);
            else
                out = list_metrics(args{1}, '', project_root);
            end
        case 'fetch'
            require_min_args(args, 2, 'fetch');
            if numel(args) == 2
                out = fetch_metric(args{1}, '', args{2}, project_root);
            else
                out = fetch_metric(args{1}, args{2}, args{3}, project_root);
            end
        otherwise
            error('auv_query_simulation_metric:InvalidRequest', ...
                'unknown request: %s', request);
    end
end

function info = api_info()
    info = struct();
    info.schema = 'auv_v1_simulation_metric_query_api_v1';
    info.version = '1.0.0';
    info.requests = {'categories', 'cases', 'metrics', 'fetch'};
end

function [args, project_root] = parse_args(varargin_cell)
    args = varargin_cell;
    project_root = pwd;
    if isempty(args)
        return;
    end
    last = args{end};
    if ischar(last) || isstring(last)
        candidate = char(last);
        if isfolder(candidate)
            project_root = candidate;
            args = args(1:end - 1);
        end
    end
end

function require_min_args(args, n, label)
    if numel(args) < n
        error('auv_query_simulation_metric:InvalidRequest', ...
            '%s requires at least %d argument(s)', label, n);
    end
end

function cases = list_cases(category_id, project_root)
    entry = auv_simulation_category_registry('resolve', category_id);
    loaded = auv_load_simulation_result(category_id, project_root);
    raw = loaded.raw;
    cases = enumerate_cases(entry, raw);
end

function names = list_metrics(category_id, case_ref, project_root)
    entry = auv_simulation_category_registry('resolve', category_id);
    loaded = auv_load_simulation_result(category_id, project_root);
    raw = loaded.raw;
    case_ref = normalize_case_ref(case_ref);
    validate_case_ref(entry, raw, case_ref);
    names = discover_metric_names(entry, raw, case_ref);
    names = names(:).';
end

function out = fetch_metric(category_id, case_ref, metric_name, project_root)
    entry = auv_simulation_category_registry('resolve', category_id);
    loaded = auv_load_simulation_result(category_id, project_root);
    raw = loaded.raw;
    case_ref = normalize_case_ref(case_ref);
    metric_name = char(metric_name);

    if isempty(metric_name)
        error('auv_query_simulation_metric:InvalidMetric', ...
            'metric_name must be a non-empty string');
    end

    validate_case_ref(entry, raw, case_ref);

    if ~isfield(entry.units, metric_name)
        error('auv_query_simulation_metric:MissingUnit', ...
            'missing declared unit for metric %s in category %s', ...
            metric_name, category_id);
    end

    [value, hit_count] = resolve_metric_value(entry, raw, case_ref, metric_name);
    if hit_count == 0
        error('auv_query_simulation_metric:UnknownMetric', ...
            'unknown metric %s for category %s', metric_name, category_id);
    end
    if hit_count > 1
        error('auv_query_simulation_metric:AmbiguousMetric', ...
            'ambiguous metric %s for category %s', metric_name, category_id);
    end

    shape = classify_shape(value);
    if strcmp(shape, 'vector')
        error('auv_query_simulation_metric:ShapeMismatch', ...
            'metric %s is a vector; scalar fetch rejected', metric_name);
    end
    if strcmp(shape, 'non_numeric')
        error('auv_query_simulation_metric:ShapeMismatch', ...
            'metric %s is non-numeric; scalar fetch rejected', metric_name);
    end
    if ~isscalar(value) || ~isfinite(value)
        error('auv_query_simulation_metric:ShapeMismatch', ...
            'metric %s must be a finite scalar', metric_name);
    end

    out = struct();
    out.schema = 'auv_v1_simulation_metric_query_result_v1';
    out.category_id = entry.category_id;
    out.case_ref = case_ref;
    out.metric_name = metric_name;
    out.value = double(value);
    out.unit = entry.units.(metric_name);
    out.shape = 'scalar';
    out.source_artifact = entry.artifact_path;
    out.scenario_id = scenario_id_from_raw(raw);
    [out.case_id, out.shadow_id] = split_case_ref(case_ref);
end

function case_ref = normalize_case_ref(case_ref)
    if nargin < 1 || isempty(case_ref)
        case_ref = '';
        return;
    end
    if isstring(case_ref)
        case_ref = char(case_ref);
    end
    if ~ischar(case_ref)
        error('auv_query_simulation_metric:InvalidCase', ...
            'case_ref must be a string');
    end
end

function validate_case_ref(entry, raw, case_ref)
    cases = enumerate_cases(entry, raw);
    if isempty(case_ref)
        if strcmp(entry.category_id, 'bounded_current')
            error('auv_query_simulation_metric:MissingCase', ...
                'category %s requires a case_ref', entry.category_id);
        end
        return;
    end
    if ~any(strcmp(cases, case_ref))
        error('auv_query_simulation_metric:UnknownCase', ...
            'unknown case %s for category %s', case_ref, entry.category_id);
    end
end

function cases = enumerate_cases(entry, raw)
    switch entry.category_id
        case 'nominal'
            cases = {};
        case {'bounded_current', 'sensor_noise_dropout', 'actuator_limits'}
            cases = case_names_from_field(raw.cases, 'name');
        case 'passive_roll_stress'
            cases = case_names_from_field(raw.cases, 'case_id');
        case 'roll_rate_solution_audit'
            cases = roll_audit_case_refs(raw.cases);
        otherwise
            error('auv_query_simulation_metric:UnsupportedCategory', ...
                'unsupported category %s', entry.category_id);
    end
end

function names = case_names_from_field(cases, field_name)
    names = {};
    if ~isstruct(cases) || isempty(cases)
        return;
    end
    for i = 1:numel(cases)
        if isfield(cases(i), field_name)
            names{end + 1} = char(string(cases(i).(field_name))); %#ok<AGROW>
        end
    end
end

function refs = roll_audit_case_refs(cases)
    refs = {};
    if ~isstruct(cases) || isempty(cases)
        return;
    end
    for i = 1:numel(cases)
        case_id = char(string(cases(i).case_id));
        if ~isfield(cases(i), 'shadows') || ~isstruct(cases(i).shadows)
            continue;
        end
        for j = 1:numel(cases(i).shadows)
            shadow_id = char(string(cases(i).shadows(j).shadow_id));
            refs{end + 1} = compose_case_ref(case_id, shadow_id); %#ok<AGROW>
        end
    end
end

function ref = compose_case_ref(case_id, shadow_id)
    ref = sprintf('%s/%s', case_id, shadow_id);
end

function [case_id, shadow_id] = split_case_ref(case_ref)
    case_id = '';
    shadow_id = '';
    if isempty(case_ref)
        return;
    end
    parts = strsplit(case_ref, '/');
    case_id = parts{1};
    if numel(parts) > 1
        shadow_id = parts{2};
    end
end

function names = discover_metric_names(entry, raw, case_ref)
    unit_fields = sort(fieldnames(entry.units));
    names = {};
    for i = 1:numel(unit_fields)
        metric_name = unit_fields{i};
        [value, hit_count] = resolve_metric_value(entry, raw, case_ref, metric_name);
        if hit_count == 1
            shape = classify_shape(value);
            if strcmp(shape, 'scalar')
                names{end + 1} = metric_name; %#ok<AGROW>
            end
        end
    end
    names = sort(names);
end

function [value, hit_count] = resolve_metric_value(entry, raw, case_ref, metric_name)
    hits = {};
    blocks = metric_search_blocks(entry, raw, case_ref);
    for i = 1:numel(blocks)
        block = blocks{i};
        if isstruct(block) && isfield(block, metric_name)
            hits{end + 1} = block.(metric_name); %#ok<AGROW>
        end
    end
    hit_count = numel(hits);
    if hit_count == 0
        value = [];
        return;
    end
    if hit_count > 1
        value = [];
        return;
    end
    value = hits{1};
end

function blocks = metric_search_blocks(entry, raw, case_ref)
    blocks = {};
    switch entry.category_id
        case 'nominal'
            blocks = {raw, raw.metrics};
        case 'bounded_current'
            case_row = find_named_case(raw.cases, 'name', case_ref);
            blocks = {case_row, case_row.metrics};
        case 'sensor_noise_dropout'
            if isempty(case_ref)
                blocks = {raw, raw.path_metrics};
            else
                case_row = find_named_case(raw.cases, 'name', case_ref);
                blocks = {case_row, case_row.metrics};
            end
        case 'actuator_limits'
            if isempty(case_ref)
                blocks = {raw, raw.limits};
            else
                case_row = find_named_case(raw.cases, 'name', case_ref);
                blocks = {case_row, case_row.path_metrics, case_row.actuator_metrics};
            end
        case 'passive_roll_stress'
            if isempty(case_ref)
                blocks = {raw, raw.screening_thresholds};
            else
                case_row = find_named_case(raw.cases, 'case_id', case_ref);
                blocks = {case_row, case_row.metrics};
            end
        case 'roll_rate_solution_audit'
            if isempty(case_ref)
                blocks = {raw, raw.screening_thresholds};
            else
                [case_id, shadow_id] = split_case_ref(case_ref);
                case_row = find_named_case(raw.cases, 'case_id', case_id);
                shadow_row = find_named_shadow(case_row.shadows, shadow_id);
                blocks = {shadow_row, shadow_row.metrics};
            end
        otherwise
            error('auv_query_simulation_metric:UnsupportedCategory', ...
                'unsupported category %s', entry.category_id);
    end
end

function row = find_named_case(cases, field_name, case_name)
    if ~isstruct(cases) || isempty(cases)
        error('auv_query_simulation_metric:UnknownCase', ...
            'unknown case %s', case_name);
    end
    for i = 1:numel(cases)
        if isfield(cases(i), field_name) && strcmp(char(string(cases(i).(field_name))), case_name)
            row = cases(i);
            return;
        end
    end
    error('auv_query_simulation_metric:UnknownCase', ...
        'unknown case %s', case_name);
end

function row = find_named_shadow(shadows, shadow_id)
    if ~isstruct(shadows) || isempty(shadows)
        error('auv_query_simulation_metric:UnknownCase', ...
            'unknown shadow %s', shadow_id);
    end
    for i = 1:numel(shadows)
        if isfield(shadows(i), 'shadow_id') && strcmp(char(string(shadows(i).shadow_id)), shadow_id)
            row = shadows(i);
            return;
        end
    end
    error('auv_query_simulation_metric:UnknownCase', ...
        'unknown shadow %s', shadow_id);
end

function shape = classify_shape(value)
    if isnumeric(value) || islogical(value)
        if isscalar(value)
            shape = 'scalar';
        elseif isvector(value)
            shape = 'vector';
        else
            shape = 'matrix';
        end
        return;
    end
    shape = 'non_numeric';
end

function scenario_id = scenario_id_from_raw(raw)
    if isfield(raw, 'scenario')
        scenario_id = char(string(raw.scenario));
    else
        scenario_id = '';
    end
end
