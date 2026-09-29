function varargout = auv_roll_metric_registry(request, varargin)
%AUV_ROLL_METRIC_REGISTRY  Roll metric definitions, computation, and screening.
%   registry = auv_roll_metric_registry()
%   metrics = auv_roll_metric_registry('compute_passive', out, ctx)
%   metrics = auv_roll_metric_registry('compute_audit', out, ctx)
%   execution_pass = auv_roll_metric_registry('evaluate_execution', harness, case_results)
%   [screening_pass, detail] = auv_roll_metric_registry('evaluate_screening', case_results, thr)
%   recommendation = auv_roll_metric_registry('recommendation', execution_pass, screening_pass, cases)
%   decision = auv_roll_metric_registry('audit_decision', risk, comparison, case_results)

    if nargin < 1 || isempty(request)
        request = 'registry';
    end
    request = lower(char(string(request)));

    switch request
        case 'registry'
            out = build_registry();
        case 'compute_passive'
            out = compute_passive_roll_metrics(varargin{:});
        case 'compute_audit'
            out = compute_roll_rate_audit_metrics(varargin{:});
        case 'evaluate_execution'
            out = evaluate_execution_contract(varargin{:});
        case 'evaluate_screening'
            [screening_pass, screening_detail] = evaluate_screening_contract(varargin{:});
            varargout{1} = screening_pass;
            if nargout > 1
                varargout{2} = screening_detail;
            end
            return;
        case 'recommendation'
            out = decide_recommendation(varargin{:});
        case 'audit_execution'
            out = evaluate_audit_execution_contract(varargin{:});
        case 'baseline_rate_screening'
            out = evaluate_baseline_rate_screening(varargin{:});
        case 'metric_verification'
            out = build_metric_verification(varargin{:});
        case 'risk_classification'
            out = classify_sim9_roll_rate_risk(varargin{:});
        case 'shadow_comparison'
            out = compare_shadow_solutions(varargin{:});
        case 'audit_decision'
            out = decide_roll_rate_audit_decision(varargin{:});
        case 'collect_violations'
            out = collect_threshold_violations(varargin{:});
        case 'assert_finite'
            assert_all_finite(varargin{:});
            out = true;
        case 'sanitize_json'
            out = sanitize_for_json(varargin{1});
        otherwise
            error('auv_roll_metric_registry:UnknownRequest', ...
                'Unknown request: %s', request);
    end

    varargout = {out};
end

function registry = build_registry()
    registry = struct();
    registry.schema = 'auv_v1_roll_metric_registry_v1';
    registry.metric_abs_tol = 1.0e-9;
    registry.metric_rel_tol = 1.0e-12;

    registry.passive_metrics = {
        'peak_abs_roll_deg', 'deg';
        'peak_abs_roll_rate_dps', 'deg/s';
        'residual_roll_deg', 'deg';
        'recovery_time_s', 's';
        'time_outside_band_s', 's';
        'max_heading_error_deg', 'deg';
        'max_depth_error_m', 'm';
        'mean_heading_error_deg', 'deg';
        'mean_depth_error_m', 'm';
        'rudder_saturation_pct', 'percent';
        'screening_band_deg', 'deg';
    };

    registry.audit_extra_metrics = {
        'time_above_rate_threshold_s', 's';
        'excursion_during_rate_exceedance_deg', 'deg';
        'peak_rate_during_exceedance_dps', 'deg/s';
        'rotational_ke_proxy_peak', 'J';
        'rotational_ke_proxy_integral', 'J*s';
        'rate_threshold_dps', 'deg/s';
    };

    registry.screening_thresholds = struct( ...
        'peak_abs_roll_deg', 35.0, ...
        'peak_abs_roll_rate_dps', 45.0, ...
        'residual_roll_deg', 8.0, ...
        'recovery_time_s', 20.0, ...
        'time_outside_band_s', 12.0, ...
        'rudder_saturation_pct', 40.0, ...
        'max_heading_error_deg', 15.0, ...
        'max_depth_error_m', 2.0, ...
        'screening_band_deg', 5.0);

    registry.actuator_limits = struct( ...
        'de_max_deg', 15, ...
        'dr_max_deg', 25, ...
        'rate_dps', 40, ...
        'sat_frac', 0.98);
end

function m = compute_passive_roll_metrics(out, dt, settle_t, screening_band_deg, limits, ~)
    t = out.t(:);
    phi = out.attitude(:, 1);
    p_rate = out.rates(:, 1);
    psi = out.attitude(:, 3);
    yaw_ref = out.reference(:, 2);
    depth_actual = -out.position(:, 3);
    depth_ref = align_path_depth_reference(out.path, out.position);

    roll_deg = rad2deg(phi);
    p_dps = rad2deg(p_rate);
    band_rad = deg2rad(screening_band_deg);

    m = struct();
    m.peak_abs_roll_deg = max(abs(roll_deg));
    m.peak_abs_roll_rate_dps = max(abs(p_dps));
    m.residual_roll_deg = mean(abs(roll_deg(t >= max(t(end) - settle_t, 0))));
    m.all_finite = all(isfinite([roll_deg; p_dps; psi; depth_actual; depth_ref]));

    [recovery_s, outside_s] = compute_roll_band_metrics(t, phi, band_rad, settle_t);
    m.recovery_time_s = recovery_s;
    m.time_outside_band_s = outside_s;

    yaw_err_deg = rad2deg(wrapToPi(yaw_ref - psi));
    depth_err_m = depth_ref - depth_actual;
    m.max_heading_error_deg = max(abs(yaw_err_deg));
    m.max_depth_error_m = max(abs(depth_err_m));
    m.mean_heading_error_deg = mean(abs(yaw_err_deg(t >= settle_t)));
    m.mean_depth_error_m = mean(abs(depth_err_m(t >= settle_t)));

    dr_applied = out.applied(:, 2);
    dr_max = deg2rad(limits.dr_max_deg);
    sat_frac = limits.sat_frac;
    settle_mask = t >= settle_t;
    if ~any(settle_mask)
        settle_mask = true(numel(t), 1);
    end
    m.rudder_saturation_pct = 100 * mean(abs(dr_applied(settle_mask)) >= sat_frac * dr_max);

    m.instability_flag = ~m.all_finite || any(abs(roll_deg) > 89.0);
    m.screening_band_deg = screening_band_deg;
end

function m = compute_roll_rate_audit_metrics(out, dt, settle_t, screening_band_deg, ...
        limits, rate_threshold_dps, Ixx)
    m = compute_passive_roll_metrics(out, dt, settle_t, screening_band_deg, limits, []);

    t = out.t(:);
    phi = out.attitude(:, 1);
    p_rate = out.rates(:, 1);
    roll_deg = rad2deg(phi);
    p_dps = rad2deg(p_rate);
    rate_thr_rad = deg2rad(rate_threshold_dps);

    exceed_mask = abs(p_rate) > rate_thr_rad;
    m.time_above_rate_threshold_s = sum(exceed_mask) * dt;
    if any(exceed_mask)
        m.excursion_during_rate_exceedance_deg = max(abs(roll_deg(exceed_mask)));
        m.peak_rate_during_exceedance_dps = max(abs(p_dps(exceed_mask)));
    else
        m.excursion_during_rate_exceedance_deg = 0.0;
        m.peak_rate_during_exceedance_dps = 0.0;
    end

    ke_proxy = 0.5 * Ixx * (p_rate .^ 2);
    m.rotational_ke_proxy_peak = max(ke_proxy);
    m.rotational_ke_proxy_integral = sum(ke_proxy) * dt;

    m.rate_threshold_dps = rate_threshold_dps;
    m.rate_screening_pass = m.peak_abs_roll_rate_dps <= rate_threshold_dps;
end

function execution_pass = evaluate_execution_contract(harness, case_results)
    harness = lower(char(string(harness)));
    if strcmp(harness, 'roll_rate_solution_audit')
        execution_pass = evaluate_audit_execution_contract(case_results);
        return;
    end

    execution_pass = true;
    for i = 1:numel(case_results)
        entry = case_results{i};
        if ~strcmp(entry.status, 'ok')
            execution_pass = false;
            return;
        end
        try
            assert_all_finite(entry.metrics);
        catch
            execution_pass = false;
            return;
        end
        if ~entry.metrics.all_finite
            execution_pass = false;
            return;
        end
        if entry.metrics.instability_flag
            execution_pass = false;
            return;
        end
    end
end

function execution_pass = evaluate_audit_execution_contract(case_results)
    execution_pass = true;
    for ci = 1:numel(case_results)
        shadows = case_results{ci}.shadows;
        found = false;
        for si = 1:numel(shadows)
            if strcmp(shadows{si}.shadow_id, 'baseline')
                found = true;
                if ~strcmp(shadows{si}.status, 'ok')
                    execution_pass = false;
                    return;
                end
                if shadows{si}.metrics.instability_flag || ~shadows{si}.metrics.all_finite
                    execution_pass = false;
                    return;
                end
            end
        end
        if ~found
            execution_pass = false;
            return;
        end
    end
end

function screening_pass = evaluate_baseline_rate_screening(case_results, rate_threshold_dps)
    screening_pass = true;
    for ci = 1:numel(case_results)
        shadows = case_results{ci}.shadows;
        for si = 1:numel(shadows)
            if strcmp(shadows{si}.shadow_id, 'baseline') && strcmp(shadows{si}.status, 'ok')
                if shadows{si}.metrics.peak_abs_roll_rate_dps > rate_threshold_dps
                    screening_pass = false;
                    return;
                end
            end
        end
    end
end

function [screening_pass, detail] = evaluate_screening_contract(case_results, thr)
    detail = struct('case_id', {}, 'pass', {}, 'violations', {});
    screening_pass = true;

    for i = 1:numel(case_results)
        entry = case_results{i};
        violations = {};
        if ~strcmp(entry.status, 'ok')
            violations{end + 1} = 'execution_not_ok'; %#ok<AGROW>
        else
            violations = collect_threshold_violations(entry.metrics, thr);
        end
        pass = isempty(violations);
        detail(i) = struct('case_id', entry.case_id, 'pass', pass, ...
            'violations', {violations}); %#ok<AGROW>
        if ~pass
            screening_pass = false;
        end
    end
end

function violations = collect_threshold_violations(m, thr)
    violations = {};
    checks = {
        'peak_abs_roll_deg', m.peak_abs_roll_deg, thr.peak_abs_roll_deg;
        'peak_abs_roll_rate_dps', m.peak_abs_roll_rate_dps, thr.peak_abs_roll_rate_dps;
        'residual_roll_deg', m.residual_roll_deg, thr.residual_roll_deg;
        'recovery_time_s', m.recovery_time_s, thr.recovery_time_s;
        'time_outside_band_s', m.time_outside_band_s, thr.time_outside_band_s;
        'rudder_saturation_pct', m.rudder_saturation_pct, thr.rudder_saturation_pct;
        'max_heading_error_deg', m.max_heading_error_deg, thr.max_heading_error_deg;
        'max_depth_error_m', m.max_depth_error_m, thr.max_depth_error_m;
    };
    for i = 1:size(checks, 1)
        if checks{i, 2} > checks{i, 3}
            violations{end + 1} = sprintf('%s=%.4g > %.4g', ...
                checks{i, 1}, checks{i, 2}, checks{i, 3}); %#ok<AGROW>
        end
    end
    if m.instability_flag
        violations{end + 1} = 'instability_flag'; %#ok<AGROW>
    end
end

function recommendation = decide_recommendation(execution_pass, screening_pass, case_results)
    if ~execution_pass
        recommendation = 'INCONCLUSIVE';
        return;
    end
    if isempty(case_results)
        recommendation = 'INCONCLUSIVE';
        return;
    end
    if screening_pass
        recommendation = 'PASSIVE_ROLL_SCREENING_SUFFICIENT';
    else
        recommendation = 'ACTIVE_ROLL_MODEL_STUDY_REQUIRED';
    end
end

function metric_verification = build_metric_verification(sim9, dt, rate_threshold_dps, limits)
    metric_verification = struct();
    metric_verification.roll_angle_unit = 'rad in state g(4); reported as deg via rad2deg(phi)';
    metric_verification.roll_rate_unit = 'rad/s body roll rate p in state g(10); reported as deg/s via rad2deg(p)';
    metric_verification.derivative_method = 'direct_body_rate_state';
    metric_verification.numerical_phi_derivative_checked = false;
    metric_verification.sampling_dt_s = dt;
    metric_verification.controller_dt_s = sim9.parameters.dt_controller;
    metric_verification.guidance_dt_s = sim9.parameters.dt_guidance;
    metric_verification.transient_settle_window_s = sim9.settle_t;
    metric_verification.screening_rate_threshold_dps = rate_threshold_dps;
    metric_verification.actuator_rate_limit_dps = limits.rate_dps;
    metric_verification.threshold_provenance = struct( ...
        'declared_in', 'SIM9 passive_roll_stress screening_thresholds.peak_abs_roll_rate_dps', ...
        'value_dps', rate_threshold_dps, ...
        'actuator_rate_limit_dps', limits.rate_dps, ...
        'margin_above_actuator_rate_dps', rate_threshold_dps - limits.rate_dps, ...
        'note', ['Threshold is a declared screening gate (not hardware-certified). ', ...
        'It sits 5 deg/s above the 40 deg/s rudder/elevator rate limit used in ', ...
        'actuator realism cases, providing a small margin without relaxing the ', ...
        'actuator envelope. No independent human-factors or IMU bandwidth ', ...
        'provenance was found in-repo; threshold provenance is therefore ', ...
        'engineering-declared and may warrant review if rate peaks occur with ', ...
        'acceptable roll angles.'], ...
        'threshold_relaxed', false);
    metric_verification.sim9_execution_pass = logical(sim9.execution_pass);
    metric_verification.sim9_screening_pass = logical(sim9.screening_pass);
end

function risk = classify_sim9_roll_rate_risk(sim9, thr)
    cases = sim9.cases;
    n = numel(cases);
    angle_ok = true(n, 1);
    rate_ok = true(n, 1);
    rate_viol = zeros(n, 1);
    angle_viol = zeros(n, 1);

    for i = 1:n
        if ~strcmp(cases(i).status, 'ok')
            angle_ok(i) = false;
            rate_ok(i) = false;
            continue;
        end
        m = cases(i).metrics;
        angle_ok(i) = m.peak_abs_roll_deg <= thr.peak_abs_roll_deg;
        rate_ok(i) = m.peak_abs_roll_rate_dps <= thr.peak_abs_roll_rate_dps;
        rate_viol(i) = max(0, m.peak_abs_roll_rate_dps - thr.peak_abs_roll_rate_dps);
        angle_viol(i) = max(0, m.peak_abs_roll_deg - thr.peak_abs_roll_deg);
    end

    risk = struct();
    risk.pattern = 'acceptable_roll_angle_excessive_roll_rate';
    risk.n_cases = n;
    risk.n_angle_pass = sum(angle_ok);
    risk.n_rate_pass = sum(rate_ok);
    risk.n_angle_rate_split = sum(angle_ok & ~rate_ok);
    risk.max_rate_overshoot_dps = max(rate_viol);
    risk.max_angle_overshoot_deg = max(angle_viol);
    risk.is_real_v1_safety_concern = risk.n_angle_rate_split >= 3 && risk.max_rate_overshoot_dps > 0.5;
    risk.rationale = ['SIM9 shows roll angle within screening limits while roll rate ', ...
        'exceeds 45 deg/s in initial-heel transients. This is a measurement/classification ', ...
        'risk (transient rate) rather than a sustained heel instability when residual ', ...
        'roll remains small.'];
end

function comparison = compare_shadow_solutions(case_results, shadow_catalog, rate_threshold_dps)
    shadow_ids = cellfun(@(s) s.shadow_id, shadow_catalog, 'UniformOutput', false);
    baseline_id = 'baseline';
    baseline_idx = find(strcmp(shadow_ids, baseline_id), 1);

    per_shadow = struct('shadow_id', {}, 'label', {}, 'kind', {}, 'n_ok', {}, ...
        'n_rate_pass', {}, 'mean_peak_rate_dps', {}, 'max_peak_rate_dps', {}, ...
        'mean_heading_error_deg', {}, 'max_heading_error_deg', {}, ...
        'mean_depth_error_m', {}, 'max_depth_error_m', {}, ...
        'mean_rudder_sat_pct', {}, 'max_rudder_sat_pct', {}, ...
        'rate_improvement_vs_baseline_cases', {}, 'heading_regression_cases', {}, ...
        'depth_regression_cases', {}, 'saturation_regression_cases', {}, ...
        'acceptable_tradeoff', {}, 'reduces_rate_without_coupling_regression', {});

    for si = 1:numel(shadow_catalog)
        sid = shadow_catalog{si}.shadow_id;
        peak_rates = [];
        headings = [];
        depths = [];
        sats = [];
        n_ok = 0;
        n_rate_pass = 0;
        rate_improve = 0;
        heading_reg = 0;
        depth_reg = 0;
        sat_reg = 0;

        for ci = 1:numel(case_results)
            shadows = case_results{ci}.shadows;
            base_m = [];
            cur_m = [];
            for k = 1:numel(shadows)
                if strcmp(shadows{k}.shadow_id, baseline_id) && strcmp(shadows{k}.status, 'ok')
                    base_m = shadows{k}.metrics;
                end
                if strcmp(shadows{k}.shadow_id, sid) && strcmp(shadows{k}.status, 'ok')
                    cur_m = shadows{k}.metrics;
                end
            end
            if isempty(cur_m)
                continue;
            end
            n_ok = n_ok + 1;
            peak_rates(end + 1) = cur_m.peak_abs_roll_rate_dps; %#ok<AGROW>
            headings(end + 1) = cur_m.max_heading_error_deg; %#ok<AGROW>
            depths(end + 1) = cur_m.max_depth_error_m; %#ok<AGROW>
            sats(end + 1) = cur_m.rudder_saturation_pct; %#ok<AGROW>
            if cur_m.rate_screening_pass
                n_rate_pass = n_rate_pass + 1;
            end
            if ~isempty(base_m)
                if cur_m.peak_abs_roll_rate_dps < base_m.peak_abs_roll_rate_dps - 0.25
                    rate_improve = rate_improve + 1;
                end
                if cur_m.max_heading_error_deg > base_m.max_heading_error_deg + 0.5
                    heading_reg = heading_reg + 1;
                end
                if cur_m.max_depth_error_m > base_m.max_depth_error_m + 0.15
                    depth_reg = depth_reg + 1;
                end
                if cur_m.rudder_saturation_pct > base_m.rudder_saturation_pct + 5.0
                    sat_reg = sat_reg + 1;
                end
            end
        end

        acceptable = n_ok > 0 && heading_reg == 0 && depth_reg == 0 && sat_reg == 0;
        per_shadow(si) = struct( ...
            'shadow_id', sid, ...
            'label', shadow_catalog{si}.label, ...
            'kind', shadow_catalog{si}.kind, ...
            'n_ok', n_ok, ...
            'n_rate_pass', n_rate_pass, ...
            'mean_peak_rate_dps', mean_or_nan(peak_rates), ...
            'max_peak_rate_dps', max_or_nan(peak_rates), ...
            'mean_heading_error_deg', mean_or_nan(headings), ...
            'max_heading_error_deg', max_or_nan(headings), ...
            'mean_depth_error_m', mean_or_nan(depths), ...
            'max_depth_error_m', max_or_nan(depths), ...
            'mean_rudder_sat_pct', mean_or_nan(sats), ...
            'max_rudder_sat_pct', max_or_nan(sats), ...
            'rate_improvement_vs_baseline_cases', rate_improve, ...
            'heading_regression_cases', heading_reg, ...
            'depth_regression_cases', depth_reg, ...
            'saturation_regression_cases', sat_reg, ...
            'acceptable_tradeoff', acceptable, ...
            'reduces_rate_without_coupling_regression', acceptable && rate_improve > 0);
    end

    comparison = struct();
    comparison.rate_threshold_dps = rate_threshold_dps;
    comparison.per_shadow = per_shadow;
    comparison.baseline_shadow_id = baseline_id;
    comparison.baseline_idx = baseline_idx;

    passive_kinds = {'kp_roll_sweep', 'restoring_enhanced'};
    passive_ids = shadow_ids(cellfun(@(s) any(strcmp(s.kind, passive_kinds)), shadow_catalog));
    passive_ok = false;
    for i = 1:numel(per_shadow)
        if any(strcmp(per_shadow(i).shadow_id, passive_ids)) && ...
                per_shadow(i).reduces_rate_without_coupling_regression && ...
                per_shadow(i).n_rate_pass >= max(1, floor(per_shadow(i).n_ok * 0.6))
            passive_ok = true;
            break;
        end
    end
    comparison.passive_or_damping_sufficient = passive_ok;

    ideal_idx = find(strcmp(shadow_ids, 'active_roll_ideal'), 1);
    if ~isempty(ideal_idx)
        comparison.ideal_upper_bound_rate_pass_fraction = ...
            per_shadow(ideal_idx).n_rate_pass / max(per_shadow(ideal_idx).n_ok, 1);
    else
        comparison.ideal_upper_bound_rate_pass_fraction = NaN;
    end
end

function decision = decide_roll_rate_audit_decision(risk, comparison, case_results)
    execution_ok = true;
    for ci = 1:numel(case_results)
        for si = 1:numel(case_results{ci}.shadows)
            if strcmp(case_results{ci}.shadows{si}.shadow_id, 'baseline') && ...
                    ~strcmp(case_results{ci}.shadows{si}.status, 'ok')
                execution_ok = false;
            end
        end
    end
    if ~execution_ok
        decision = 'INCONCLUSIVE';
        return;
    end

    if ~risk.is_real_v1_safety_concern
        decision = 'THRESHOLD_OR_METRIC_REVIEW_NEEDED';
        return;
    end

    if comparison.passive_or_damping_sufficient
        decision = 'PASSIVE_OR_DAMPING_SOLUTION_SUFFICIENT';
        return;
    end

    ideal_frac = comparison.ideal_upper_bound_rate_pass_fraction;
    if isfinite(ideal_frac) && ideal_frac >= 0.8
        decision = 'ACTIVE_ROLL_AUTHORITY_REQUIRED';
        return;
    end

    if risk.max_rate_overshoot_dps < 2.0 && risk.n_angle_rate_split >= 1
        decision = 'THRESHOLD_OR_METRIC_REVIEW_NEEDED';
        return;
    end

    decision = 'INCONCLUSIVE';
end

function [recovery_s, outside_s] = compute_roll_band_metrics(t, phi, band_rad, settle_t)
    inside = abs(phi) <= band_rad;
    outside_s = sum(~inside) * (t(2) - t(1));
    recovery_s = NaN;

    post_mask = t >= settle_t;
    if any(post_mask)
        idx_post = find(post_mask);
        for k = 1:numel(idx_post)
            if all(inside(idx_post(k):end))
                recovery_s = t(idx_post(k)) - settle_t;
                break;
            end
        end
    end

    if ~isfinite(recovery_s)
        idx_enter = find(inside, 1, 'first');
        if ~isempty(idx_enter)
            recovery_s = max(0.0, t(idx_enter) - settle_t);
        else
            recovery_s = max(0.0, t(end) - settle_t);
        end
    end
    recovery_s = max(0.0, recovery_s);
end

function depth_ref = align_path_depth_reference(path, position)
    path = double(path);
    position = double(position);
    n_path = size(path, 1);
    n_pos = size(position, 1);
    depth_waypoints = -path(:, 3);

    s_nodes = zeros(n_path, 1);
    for i = 2:n_path
        s_nodes(i) = s_nodes(i - 1) + norm(path(i, :) - path(i - 1, :));
    end
    s_total = max(s_nodes(end), 1e-9);

    depth_ref = zeros(n_pos, 1);
    s_prog = 0;
    for i = 1:n_pos
        p = position(i, :);
        if i == 1
            [s_near, ~] = project_progress_on_path(p, path, s_nodes, 0, s_total);
            s_prog = s_near;
        else
            s_lo = max(0, s_prog - 0.15);
            s_hi = min(s_total, s_prog + max(3.0, 3.125));
            [s_near, ~] = project_progress_on_path(p, path, s_nodes, s_lo, s_hi);
            s_prog = max(s_prog, s_near - 0.05);
            s_prog = min(s_prog, s_total);
        end
        depth_ref(i) = interp1(s_nodes, depth_waypoints, s_prog, 'linear', 'extrap');
    end
end

function [s_best, d_best] = project_progress_on_path(p, path, s_nodes, s_lo, s_hi)
    n = size(path, 1);
    d_best = inf;
    s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n - 1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n - 1; end
    i0 = min(i0, n - 1);
    i1 = max(i1, i0);
    for i = i0:i1
        a = path(i, :);
        b = path(i + 1, :);
        ab = b - a;
        lab2 = sum(ab .^ 2);
        if lab2 < 1e-12
            continue;
        end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab;
        d = norm(p - proj);
        s = s_nodes(i) + tt * (s_nodes(i + 1) - s_nodes(i));
        if s < s_lo - 1e-9 || s > s_hi + 1e-9
            continue;
        end
        if d < d_best
            d_best = d;
            s_best = s;
        end
    end
end

function v = mean_or_nan(x)
    if isempty(x)
        v = NaN;
    else
        v = mean(x);
    end
end

function v = max_or_nan(x)
    if isempty(x)
        v = NaN;
    else
        v = max(x);
    end
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
            if isstruct(x{i}) || iscell(x{i})
                s{i} = sanitize_for_json(x{i});
            else
                s{i} = x{i};
            end
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

function assert_all_finite(varargin)
    for k = 1:nargin
        x = varargin{k};
        if isstruct(x)
            vals = struct2cell(x);
            for j = 1:numel(vals)
                v = vals{j};
                if islogical(v) || ischar(v) || isstring(v)
                    continue;
                end
                if isstruct(v)
                    assert_all_finite(v);
                elseif isnumeric(v) && any(~isfinite(v(:)))
                    error('auv_roll_metric_registry:NonFinite', ...
                        'Non-finite numeric values in argument %d.', k);
                end
            end
        elseif islogical(x) || ischar(x) || isstring(x)
            continue;
        elseif isnumeric(x) && any(~isfinite(x(:)))
            error('auv_roll_metric_registry:NonFinite', ...
                'Non-finite numeric values in argument %d.', k);
        end
    end
end
