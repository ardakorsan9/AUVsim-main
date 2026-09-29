function [ok, report] = auv_validate_result(result, contract)
%AUV_VALIDATE_RESULT  Fail-closed validator for AUV shared result contract.
%   [ok, report] = auv_validate_result(result)
%   Rejects missing fields, shape/orientation mismatches, non-finite values in
%   required numeric slots, invalid units metadata, heterogeneous struct arrays,
%   and uncertified certification claims.

    if nargin < 2 || isempty(contract)
        contract = auv_result_contract();
    end

    report = struct('ok', true, 'errors', {{}}, 'warnings', {{}});
    errors = {};

    if ~isstruct(result)
        errors{end + 1} = 'result must be a struct'; %#ok<AGROW>
        ok = false;
        report.ok = false;
        report.errors = errors;
        return;
    end

    errors = [errors, require_sections(result, contract.required_sections)];

    if isfield(result, 'meta')
        errors = [errors, validate_meta(result.meta, contract.meta)];
    end

    if isfield(result, 'time')
        errors = [errors, validate_time_series_section( ...
            result.time, contract.time, 'time')];
    end

    if isfield(result, 'truth')
        errors = [errors, validate_matrix_section( ...
            result.truth, contract.truth, 'truth')];
    end

    if isfield(result, 'sensors')
        errors = [errors, validate_matrix_section( ...
            result.sensors, contract.sensors, 'sensors')];
    end

    if isfield(result, 'commands')
        errors = [errors, validate_matrix_section( ...
            result.commands, contract.commands, 'commands')];
    end

    if isfield(result, 'actuators')
        errors = [errors, validate_matrix_section( ...
            result.actuators, contract.actuators, 'actuators')];
    end

    if isfield(result, 'metrics')
        errors = [errors, validate_metrics(result.metrics, contract.metrics)];
    end

    if isfield(result, 'screening')
        errors = [errors, validate_screening(result.screening, contract.screening)];
    end

    if isfield(result, 'provenance')
        errors = [errors, validate_provenance(result.provenance, contract.provenance)];
    end

    errors = [errors, validate_cross_section_lengths(result)];

    ok = isempty(errors);
    report.ok = ok;
    report.errors = errors;
end

function errors = require_sections(result, required_sections)
    errors = {};
    for i = 1:numel(required_sections)
        name = required_sections{i};
        if ~isfield(result, name)
            errors{end + 1} = sprintf('missing top-level section: %s', name); %#ok<AGROW>
        end
    end
end

function errors = validate_meta(meta, spec)
    errors = {};
    if ~isstruct(meta) || numel(meta) ~= 1
        errors{end + 1} = 'meta must be a scalar struct'; %#ok<AGROW>
        return;
    end

    errors = [errors, require_fields(meta, spec.required_fields, 'meta')];

    if isfield(meta, 'certified')
        if ~islogical(meta.certified) && ~(isnumeric(meta.certified) && isscalar(meta.certified))
            errors{end + 1} = 'meta.certified must be logical scalar'; %#ok<AGROW>
        elseif logical(meta.certified) ~= spec.certified_must_be
            errors{end + 1} = 'meta.certified must remain false (uncertified claim rejected)'; %#ok<AGROW>
        end
    end

    if isfield(meta, 'schema') && ~strcmp(meta.schema, 'auv_v1_shared_result_contract_v1')
        errors{end + 1} = sprintf('meta.schema mismatch: %s', char(string(meta.schema))); %#ok<AGROW>
    end

    if isfield(meta, 'approved')
        errors{end + 1} = 'meta.approved is forbidden (uncertified claim rejected)'; %#ok<AGROW>
    end
end

function errors = validate_time_series_section(section, spec, label)
    errors = {};
    if ~isstruct(section) || numel(section) ~= 1
        errors{end + 1} = sprintf('%s must be a scalar struct', label); %#ok<AGROW>
        return;
    end

    errors = [errors, require_fields(section, spec.required_fields, label)];

    if isfield(section, 't_s')
        t = section.t_s;
        if ~isnumeric(t) || ~isvector(t) || size(t, 2) ~= 1
            errors{end + 1} = sprintf('%s.t_s must be a column vector', label); %#ok<AGROW>
        elseif ~all(isfinite(t))
            errors{end + 1} = sprintf('%s.t_s contains non-finite values', label); %#ok<AGROW>
        elseif isfield(section, 'n_samples') && ~isempty(t) && section.n_samples ~= numel(t)
            errors{end + 1} = sprintf('%s.n_samples inconsistent with t_s length', label); %#ok<AGROW>
        end
    end

    if isfield(section, 'dt_s') && (~isnumeric(section.dt_s) || ~isscalar(section.dt_s) || ~isfinite(section.dt_s) || section.dt_s <= 0)
        if ~(spec.allow_empty_series && isfield(section, 'n_samples') && section.n_samples == 0)
            errors{end + 1} = sprintf('%s.dt_s must be a positive finite scalar', label); %#ok<AGROW>
        end
    end

    if isfield(section, 'n_samples')
        if ~isnumeric(section.n_samples) || ~isscalar(section.n_samples) || section.n_samples < 0 || mod(section.n_samples, 1) ~= 0
            errors{end + 1} = sprintf('%s.n_samples must be a non-negative integer scalar', label); %#ok<AGROW>
        end
    end
end

function errors = validate_matrix_section(section, spec, label)
    errors = {};
    if ~isstruct(section) || numel(section) ~= 1
        errors{end + 1} = sprintf('%s must be a scalar struct', label); %#ok<AGROW>
        return;
    end

    errors = [errors, require_fields(section, spec.required_fields, label)];

    n_rows = [];
    for i = 1:numel(spec.required_fields)
        fname = spec.required_fields{i};
        if ~isfield(section, fname)
            continue;
        end
        x = section.(fname);
        if ~isnumeric(x) || ndims(x) > 2 %#ok<ISMAT>
            errors{end + 1} = sprintf('%s.%s must be numeric 2-D', label, fname); %#ok<AGROW>
            continue;
        end
        if isempty(x)
            continue;
        end
        expected_cols = spec.column_counts.(fname);
        if size(x, 2) ~= expected_cols
            errors{end + 1} = sprintf('%s.%s column count must be %d (got %d)', ...
                label, fname, expected_cols, size(x, 2)); %#ok<AGROW>
        end
        if ~all(isfinite(x(:)))
            errors{end + 1} = sprintf('%s.%s contains non-finite values', label, fname); %#ok<AGROW>
        end
        if isempty(n_rows)
            n_rows = size(x, 1);
        elseif size(x, 1) ~= n_rows
            errors{end + 1} = sprintf('%s.%s row count mismatch (%d vs %d)', ...
                label, fname, size(x, 1), n_rows); %#ok<AGROW>
        end
    end
end

function errors = validate_metrics(metrics, spec)
    errors = {};
    if ~isstruct(metrics) || numel(metrics) ~= 1
        errors{end + 1} = 'metrics must be a scalar struct'; %#ok<AGROW>
        return;
    end

    errors = [errors, require_fields(metrics, spec.required_fields, 'metrics')];

    if ~isfield(metrics, 'cases')
        return;
    end

    cases = metrics.cases;
    if ~isstruct(cases)
        errors{end + 1} = 'metrics.cases must be a struct array'; %#ok<AGROW>
        return;
    end

    if iscell(cases)
        errors{end + 1} = 'metrics.cases struct mismatch (cell array of structs not allowed)'; %#ok<AGROW>
        return;
    end

    if isempty(cases)
        return;
    end

    [homogeneous, homo_err] = is_homogeneous_struct_array(cases);
    if ~homogeneous
        errors{end + 1} = homo_err; %#ok<AGROW>
    end

    for i = 1:numel(cases)
        prefix = sprintf('metrics.cases(%d)', i);
        errors = [errors, require_fields(cases(i), spec.case_required_fields, prefix)];

        if isfield(cases(i), 'peak_abs_roll_deg') && (~isnumeric(cases(i).peak_abs_roll_deg) || ~isfinite(cases(i).peak_abs_roll_deg))
            errors{end + 1} = sprintf('%s.peak_abs_roll_deg must be finite', prefix); %#ok<AGROW>
        end
        if isfield(cases(i), 'peak_abs_roll_rate_dps') && (~isnumeric(cases(i).peak_abs_roll_rate_dps) || ~isfinite(cases(i).peak_abs_roll_rate_dps))
            errors{end + 1} = sprintf('%s.peak_abs_roll_rate_dps must be finite', prefix); %#ok<AGROW>
        end
        if isfield(cases(i), 'all_finite') && ~islogical(cases(i).all_finite) && ~(isnumeric(cases(i).all_finite) && isscalar(cases(i).all_finite))
            errors{end + 1} = sprintf('%s.all_finite must be logical scalar', prefix); %#ok<AGROW>
        end
    end
end

function errors = validate_screening(screening, spec)
    errors = {};
    if ~isstruct(screening) || numel(screening) ~= 1
        errors{end + 1} = 'screening must be a scalar struct'; %#ok<AGROW>
        return;
    end

    errors = [errors, require_fields(screening, spec.required_fields, 'screening')];

    for fname = {'execution_pass', 'screening_pass'}
        f = fname{1};
        if isfield(screening, f) && ~islogical(screening.(f)) && ~(isnumeric(screening.(f)) && isscalar(screening.(f)))
            errors{end + 1} = sprintf('screening.%s must be logical scalar', f); %#ok<AGROW>
        end
    end

    if isfield(screening, 'thresholds')
        thr = screening.thresholds;
        if ~isstruct(thr) || numel(thr) ~= 1
            errors{end + 1} = 'screening.thresholds must be a scalar struct'; %#ok<AGROW>
        end
    end
end

function errors = validate_provenance(provenance, spec)
    errors = {};
    if ~isstruct(provenance) || numel(provenance) ~= 1
        errors{end + 1} = 'provenance must be a scalar struct'; %#ok<AGROW>
        return;
    end

    errors = [errors, require_fields(provenance, spec.required_fields, 'provenance')];

    for i = 1:numel(spec.forbidden_claim_fields)
        fname = spec.forbidden_claim_fields{i};
        if isfield(provenance, fname) && logical(provenance.(fname))
            errors{end + 1} = sprintf('provenance.%s=true is forbidden', fname); %#ok<AGROW>
        end
    end
end

function errors = validate_cross_section_lengths(result)
    errors = {};
    if ~all(isfield(result, {'time', 'truth'}))
        return;
    end

    n_time = result.time.n_samples;
    if ~isnumeric(n_time) || ~isscalar(n_time)
        return;
    end

    series_sections = {'truth', 'sensors', 'commands', 'actuators'};
    for si = 1:numel(series_sections)
        sec_name = series_sections{si};
        if ~isfield(result, sec_name)
            continue;
        end
        sec = result.(sec_name);
        if ~isstruct(sec)
            continue;
        end
        fields = fieldnames(sec);
        for fi = 1:numel(fields)
            x = sec.(fields{fi});
            if isnumeric(x) && ~isempty(x) && size(x, 1) ~= n_time
                errors{end + 1} = sprintf('%s.%s row count (%d) != time.n_samples (%d)', ...
                    sec_name, fields{fi}, size(x, 1), n_time); %#ok<AGROW>
            end
        end
    end
end

function errors = require_fields(s, required_fields, prefix)
    errors = {};
    for i = 1:numel(required_fields)
        fname = required_fields{i};
        if ~isfield(s, fname)
            errors{end + 1} = sprintf('%s missing field: %s', prefix, fname); %#ok<AGROW>
        end
    end
end

function [ok, err_msg] = is_homogeneous_struct_array(s)
    ok = true;
    err_msg = '';
    if ~isstruct(s)
        ok = false;
        err_msg = 'expected struct array';
        return;
    end
    if numel(s) <= 1
        return;
    end
    base_fields = sort(fieldnames(s(1)));
    for i = 2:numel(s)
        fields_i = sort(fieldnames(s(i)));
        if ~isequal(base_fields, fields_i)
            ok = false;
            err_msg = sprintf('heterogeneous struct array at index %d (field mismatch)', i);
            return;
        end
    end
end
