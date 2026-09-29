function out = auv_roll_scenario_catalog(request, varargin)
%AUV_ROLL_SCENARIO_CATALOG  Deterministic roll-validation scenario catalog.
%   catalog = auv_roll_scenario_catalog()
%   cases = auv_roll_scenario_catalog('case_matrix', harness, mode, duration_s, speed)
%   shadows = auv_roll_scenario_catalog('shadow_catalog', mode, baseline_kp_roll)
%   path = auv_roll_scenario_catalog('straight_path', length_m, depth_m, npts)
%   state = auv_roll_scenario_catalog('default_state', path, depth_m, speed, heel_deg)

    if nargin < 1 || isempty(request)
        request = 'catalog';
    end
    request = lower(char(string(request)));

    switch request
        case 'catalog'
            out = build_catalog();
        case 'case_matrix'
            out = build_case_matrix(varargin{:});
        case 'shadow_catalog'
            out = build_shadow_catalog(varargin{:});
        case 'straight_path'
            out = build_straight_path(varargin{:});
        case 'default_state'
            out = default_straight_state(varargin{:});
        otherwise
            error('auv_roll_scenario_catalog:UnknownRequest', ...
                'Unknown request: %s', request);
    end
end

function catalog = build_catalog()
    catalog = struct();
    catalog.schema = 'auv_v1_roll_scenario_catalog_v1';
    catalog.seed = 20260830;
    catalog.dt = 0.025;
    catalog.settle_t = 5.0;
    catalog.screening_band_deg = 5.0;
    catalog.rate_threshold_dps = 45.0;

    catalog.harnesses = struct( ...
        'passive_roll_stress', struct( ...
            'scenario', 'passive_roll_stress_deterministic', ...
            'schema', 'auv_v1_passive_roll_stress_v1', ...
            'artifact_name', 'passive_roll_stress.json', ...
            'smoke_case_ids', {{'heel_10_zero', 'heel_15_zero', 'heel_10_pulse_mild'}}, ...
            'smoke_duration_s', 20.0, ...
            'smoke_max_runtime_s', 180.0, ...
            'full_duration_s', 30.0, ...
            'full_max_runtime_s', 900.0), ...
        'roll_rate_solution_audit', struct( ...
            'scenario', 'roll_rate_solution_audit_deterministic', ...
            'schema', 'auv_v1_roll_rate_solution_audit_v1', ...
            'artifact_name', 'roll_rate_solution_audit.json', ...
            'sim9_source', 'artifacts/robustness_v2/passive_roll_stress.json', ...
            'smoke_case_ids', {{'heel_10_zero', 'heel_15_zero'}}, ...
            'smoke_shadow_ids', {{'baseline', 'kp_roll_120', 'restoring_enhanced'}}, ...
            'smoke_duration_s', 12.0, ...
            'smoke_max_runtime_s', 90.0, ...
            'full_duration_s', 30.0, ...
            'full_max_runtime_s', 1200.0));

    catalog.case_specs = {
        'heel_5_zero', 'initial_heel', 'Initial heel 5 deg, zero current', ...
            5.0, NaN, [0; 0; 0], 1.0, struct('enabled', false);
        'heel_10_zero', 'initial_heel', 'Initial heel 10 deg, zero current', ...
            10.0, NaN, [0; 0; 0], 1.0, struct('enabled', false);
        'heel_15_zero', 'initial_heel', 'Initial heel 15 deg, zero current', ...
            15.0, NaN, [0; 0; 0], 1.0, struct('enabled', false);
        'heel_20_zero', 'initial_heel', 'Initial heel 20 deg, zero current', ...
            20.0, NaN, [0; 0; 0], 1.0, struct('enabled', false);
        'heel_10_low_speed', 'speed', 'Initial heel 10 deg at low speed', ...
            10.0, 0.8, [0; 0; 0], 1.0, struct('enabled', false);
        'heel_10_cross_current', 'current', 'Initial heel 10 deg with bounded cross-current', ...
            10.0, NaN, [0; 0.25; 0], 1.0, struct('enabled', false);
        'heel_10_restoring_reduced', 'restoring', 'Initial heel 10 deg, reduced restoring strength', ...
            10.0, NaN, [0; 0; 0], 0.75, struct('enabled', false);
        'heel_10_pulse_mild', 'roll_pulse', 'Initial heel 10 deg with mild roll-moment pulse', ...
            10.0, NaN, [0; 0; 0], 1.0, struct('enabled', true, 'K_Nm', 0.05, ...
            'start_s', 5.0, 'duration_s', 0.5);
        'heel_10_pulse_strong', 'roll_pulse', 'Initial heel 10 deg with strong roll-moment pulse', ...
            10.0, NaN, [0; 0; 0], 1.0, struct('enabled', true, 'K_Nm', 0.10, ...
            'start_s', 5.0, 'duration_s', 0.5);
    };

    catalog.shadow_specs = {
        struct('shadow_id', 'baseline', 'label', 'Frozen production Kp_roll', ...
            'kind', 'baseline', 'params', struct('Kp_roll', NaN, ...
            'restoring_scale', 1.0, 'ideal_rate_gain', 0.0));
        struct('shadow_id', 'kp_roll_090', 'label', 'Bounded Kp_roll sweep low', ...
            'kind', 'kp_roll_sweep', 'params', struct('Kp_roll', 0.90, ...
            'restoring_scale', 1.0, 'ideal_rate_gain', 0.0));
        struct('shadow_id', 'kp_roll_120', 'label', 'Bounded Kp_roll sweep mid', ...
            'kind', 'kp_roll_sweep', 'params', struct('Kp_roll', 1.20, ...
            'restoring_scale', 1.0, 'ideal_rate_gain', 0.0));
        struct('shadow_id', 'kp_roll_150', 'label', 'Bounded Kp_roll sweep high', ...
            'kind', 'kp_roll_sweep', 'params', struct('Kp_roll', 1.50, ...
            'restoring_scale', 1.0, 'ideal_rate_gain', 0.0));
        struct('shadow_id', 'restoring_enhanced', 'label', 'Stronger passive restoring', ...
            'kind', 'restoring_enhanced', 'params', struct('Kp_roll', NaN, ...
            'restoring_scale', 1.25, 'ideal_rate_gain', 0.0));
        struct('shadow_id', 'active_roll_ideal', 'label', ...
            'Idealized active roll authority (upper bound)', ...
            'kind', 'active_roll_ideal', 'params', struct('Kp_roll', NaN, ...
            'restoring_scale', 1.0, 'ideal_rate_gain', 8.0));
    };
end

function case_matrix = build_case_matrix(harness, mode, duration_s, nominal_speed)
    if nargin < 1 || isempty(harness)
        error('auv_roll_scenario_catalog:MissingHarness', 'harness is required.');
    end
    harness = lower(char(string(harness)));
    if nargin < 2 || isempty(mode)
        mode = 'full';
    end
    mode = lower(char(string(mode)));

    catalog = build_catalog();
    hspec = catalog.harnesses.(harness);
    smoke_ids = hspec.smoke_case_ids;

    depth_m = 5.0;
    path_len = 60.0;
    npts = 120;
    path = build_straight_path(path_len, depth_m, npts);
    specs = catalog.case_specs;

    case_matrix = {};
    for i = 1:size(specs, 1)
        case_id = specs{i, 1};
        if strcmp(mode, 'smoke') && ~any(strcmp(case_id, smoke_ids))
            continue;
        end

        heel_deg = specs{i, 4};
        speed_mps = specs{i, 5};
        if isnan(speed_mps)
            speed_mps = nominal_speed;
        end
        state0 = default_straight_state(path, depth_m, speed_mps, heel_deg);

        c = struct();
        c.case_id = case_id;
        c.domain = specs{i, 2};
        c.description = specs{i, 3};
        c.path = path;
        c.state0 = state0;
        c.duration_s = duration_s;
        c.heel_deg = heel_deg;
        c.speed_mps = speed_mps;
        c.Vc_ned = specs{i, 6};
        c.restoring_scale = specs{i, 7};
        c.roll_pulse = specs{i, 8};
        case_matrix{end + 1} = c; %#ok<AGROW>
    end
end

function catalog = build_shadow_catalog(mode, baseline_kp_roll)
    if nargin < 1 || isempty(mode)
        mode = 'full';
    end
    mode = lower(char(string(mode)));
    if nargin < 2 || isempty(baseline_kp_roll)
        baseline_kp_roll = 0.605072;
    end

    meta = build_catalog();
    catalog = meta.shadow_specs;
    for i = 1:numel(catalog)
        if isfield(catalog{i}.params, 'Kp_roll') && isnan(catalog{i}.params.Kp_roll)
            catalog{i}.params.Kp_roll = baseline_kp_roll;
        end
    end

    if strcmp(mode, 'smoke')
        keep = meta.harnesses.roll_rate_solution_audit.smoke_shadow_ids;
        catalog = catalog(cellfun(@(s) any(strcmp(s.shadow_id, keep)), catalog));
    end
end

function path = build_straight_path(length_m, depth_m, npts)
    if nargin < 1 || isempty(length_m); length_m = 60.0; end
    if nargin < 2 || isempty(depth_m); depth_m = 5.0; end
    if nargin < 3 || isempty(npts); npts = 120; end
    path = [linspace(0, length_m, npts)', zeros(npts, 1), -depth_m * ones(npts, 1)];
end

function state = default_straight_state(path, depth_m, speed_mps, heel_deg)
    state = zeros(12, 1);
    state(1:3) = [path(1, 1); path(1, 2); -depth_m];
    d = path(2, :) - path(1, :);
    state(4) = deg2rad(heel_deg);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = speed_mps;
end
