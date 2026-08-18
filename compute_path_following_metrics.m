function m = compute_path_following_metrics(path, vehicle_path, velocities, orientations, yaw_refs, pitch_refs, dt, times)
% COMPUTE_PATH_FOLLOWING_METRICS  Frenet + legacy waypoint path metrics.
%
% Primary gate metric: CTE_perp on settled_before_endpoint window
%   (t >= settle_t AND s < 0.88*s_total AND not near_end / past_end).
% Legacy nearest-waypoint distance kept as cte_waypoint_legacy_* fields.
%
% mean_cross_track / max_cross_track alias the primary settled_before_end
% CTE_perp (and its max on that window) so suite/Tur gates retarget.

    if nargin < 7 || isempty(dt); dt = 0.0375; end
    if nargin < 8; times = []; end

    n = size(vehicle_path, 1);
    if n < 2
        m = empty_metrics();
        return;
    end

    if isempty(times) || numel(times) ~= n
        t = (1:n)' * dt;
    else
        t = times(:);
    end

    [s_nodes, s_total] = path_arclength(path);
    is_closed = norm(path(1,:) - path(end,:)) < 0.25;

    % Legacy: nearest discrete waypoint distance
    cte_wp = zeros(n, 1);
    for i = 1:n
        cte_wp(i) = min(vecnorm(path - vehicle_path(i,:), 2, 2));
    end

    % Progress-point projection (monotonic, guidance-like) + Frenet split
    e_s = zeros(n, 1);
    cte_perp = zeros(n, 1);
    e_z = zeros(n, 1);
    e_xy = zeros(n, 1);
    s_prog_log = zeros(n, 1);
    near_end_flag = false(n, 1);
    past_end_flag = false(n, 1);
    s_prog = 0;
    L = 1.25;
    [p_end, t_end] = sample_path(path, s_nodes, s_total, is_closed);

    for i = 1:n
        p = vehicle_path(i,:);
        if i == 1
            [s_near, ~] = project_on_path(p, path, s_nodes, 0, s_total, is_closed);
            s_prog = s_near;
            if is_closed
                s_prog = mod(s_prog, s_total);
            end
        else
            if is_closed
                % Periodic wrap: search forward window across seam; never clamp to s_total.
                win = max(3.0, 2.5*L);
                s_lo = mod(s_prog - 0.15, s_total);
                [s_near, ~] = project_wrapped(p, path, s_nodes, s_lo, win, s_total);
                ds = wrap_arc(s_near - s_prog, s_total);
                if ds >= -0.25
                    s_prog = mod(s_prog + max(ds, -0.05), s_total);
                end
            else
                % Open-path clamp (unchanged)
                s_lo = max(0, s_prog - 0.15);
                s_hi = min(s_total, s_prog + max(3.0, 2.5*L));
                [s_near, ~] = project_on_path(p, path, s_nodes, s_lo, s_hi, is_closed);
                if s_near >= s_total - 1e-6
                    s_prog = s_total;
                else
                    s_prog = max(s_prog, s_near - 0.05);
                    s_prog = min(s_prog, s_total);
                end
            end
        end
        [p_d, t_hat] = sample_path(path, s_nodes, s_prog, is_closed);
        dp = (p - p_d)';
        e_s(i) = dot(dp, t_hat(:));
        e_perp_vec = (eye(3) - (t_hat(:)*t_hat(:)')) * dp;
        cte_perp(i) = norm(e_perp_vec);
        e_z(i) = e_perp_vec(3);          % vertical normal component
        e_xy(i) = norm(e_perp_vec(1:2)); % horizontal normal component
        s_prog_log(i) = s_prog;
        near_end_flag(i) = (~is_closed) && (s_prog >= s_total - 0.3);
        past_end_flag(i) = (~is_closed) && (dot(p - p_end, t_end) > 0.05);
    end

    settle_t = 5.0;
    mask_full = true(n, 1);
    mask_settled = t >= settle_t;
    % Endpoint cut applies to open paths only (circle/helix closed: use settled)
    if is_closed
        mask_before_end = true(n, 1);
        mask_overrun = false(n, 1);
    else
        mask_before_end = (s_prog_log < 0.88 * s_total) & ~near_end_flag & ~past_end_flag;
        mask_overrun = past_end_flag | (s_prog_log >= 0.88 * s_total) | near_end_flag;
    end
    mask_settled_before_end = mask_settled & mask_before_end;

    % Attitude / chatter (unchanged suite style)
    yaw_err = wrapToPi(yaw_refs(:) - orientations(:,3));
    pitch_err = pitch_refs(:) + orientations(:,2);
    theta_phys = -orientations(:,2);
    i0 = max(1, round(2.0 / dt));
    th = theta_phys(i0:end);
    dth = [0; diff(th)] / dt;
    dth_hf = suite_hf_local(detrend(dth), dt);
    chatter = rad2deg(std(dth_hf));

    m = struct();
    m.s_total = s_total;
    m.travel_est = sum(vecnorm(diff(vehicle_path), 2, 2));
    m.settle_t = settle_t;
    m.n_samples = n;
    m.dt = dt;
    m.final_u = velocities(end,1);
    m.mean_yaw_err_deg = rad2deg(mean(abs(yaw_err)));
    m.mean_pitch_err_deg = rad2deg(mean(abs(pitch_err)));
    m.pitch_chatter_dps = chatter;
    m.theta_pp_deg = rad2deg(max(th) - min(th));
    m.pct_samples_overrun = 100 * mean(mask_overrun);
    m.pct_samples_past_end = 100 * mean(past_end_flag);

    % Legacy waypoint CTE (do not delete)
    m.cte_waypoint_legacy = win_stats(cte_wp, mask_full);
    m.cte_waypoint_legacy_full = m.cte_waypoint_legacy.mean;
    m.cte_waypoint_legacy_settled = win_stats(cte_wp, mask_settled).mean;
    m.cte_waypoint_legacy_before_end = win_stats(cte_wp, mask_before_end).mean;
    m.cte_waypoint_legacy_settled_before_end = win_stats(cte_wp, mask_settled_before_end).mean;
    m.cte_waypoint_legacy_overrun = win_stats(cte_wp, mask_overrun).mean;
    m.max_cte_waypoint_legacy = max(cte_wp);

    % Primary Frenet series windows
    m.e_s = win_stats(abs(e_s), mask_full);           % report |e_s|
    m.CTE_perp = win_stats(cte_perp, mask_full);
    m.vertical_normal = win_stats(abs(e_z), mask_full); % |e_z|
    m.horizontal_normal = win_stats(e_xy, mask_full);
    m.depth_error = win_stats(e_z, mask_full);          % signed e_z

    m.e_s_settled = win_stats(abs(e_s), mask_settled);
    m.CTE_perp_settled = win_stats(cte_perp, mask_settled);
    m.vertical_normal_settled = win_stats(abs(e_z), mask_settled);
    m.horizontal_normal_settled = win_stats(e_xy, mask_settled);
    m.depth_error_settled = win_stats(e_z, mask_settled);

    m.e_s_before_end = win_stats(abs(e_s), mask_before_end);
    m.CTE_perp_before_end = win_stats(cte_perp, mask_before_end);
    m.vertical_normal_before_end = win_stats(abs(e_z), mask_before_end);
    m.horizontal_normal_before_end = win_stats(e_xy, mask_before_end);
    m.depth_error_before_end = win_stats(e_z, mask_before_end);

    m.e_s_settled_before_end = win_stats(abs(e_s), mask_settled_before_end);
    m.CTE_perp_settled_before_end = win_stats(cte_perp, mask_settled_before_end);
    m.vertical_normal_settled_before_end = win_stats(abs(e_z), mask_settled_before_end);
    m.horizontal_normal_settled_before_end = win_stats(e_xy, mask_settled_before_end);
    m.depth_error_settled_before_end = win_stats(e_z, mask_settled_before_end);

    m.e_s_overrun = win_stats(abs(e_s), mask_overrun);
    m.CTE_perp_overrun = win_stats(cte_perp, mask_overrun);
    m.vertical_normal_overrun = win_stats(abs(e_z), mask_overrun);
    m.horizontal_normal_overrun = win_stats(e_xy, mask_overrun);
    m.depth_error_overrun = win_stats(e_z, mask_overrun);

    % Flat convenience fields (primary gate)
    m.mean_cte_perp = m.CTE_perp_settled_before_end.mean;
    m.max_cte_perp = m.CTE_perp_settled_before_end.max;
    m.mean_abs_ez = m.vertical_normal_settled_before_end.mean;
    m.mean_signed_ez = m.depth_error_settled_before_end.mean;
    m.mean_abs_es = m.e_s_settled_before_end.mean;
    m.mean_e_xy = m.horizontal_normal_settled_before_end.mean;

    % Gate aliases used by suite / Tur regression readers
    m.mean_cross_track = m.mean_cte_perp;
    m.max_cross_track = m.max_cte_perp;

    % Series (optional consumers)
    m.cte_perp_series = cte_perp;
    m.cte_waypoint_series = cte_wp;
    m.e_s_series = e_s;
    m.e_z_series = e_z;
    m.e_xy_series = e_xy;
    m.s_prog = s_prog_log;
    m.t = t;
end

function s = win_stats(x, mask)
    x = x(:);
    if nargin < 2 || isempty(mask)
        mask = true(size(x));
    end
    mask = mask(:);
    if ~any(mask)
        s = struct('mean', NaN, 'max', NaN, 'min', NaN, 'rms', NaN, 'n', 0);
        return;
    end
    v = x(mask);
    s = struct( ...
        'mean', mean(v), ...
        'max', max(v), ...
        'min', min(v), ...
        'rms', rms(v), ...
        'n', numel(v));
end

function m = empty_metrics()
    nanw = struct('mean', NaN, 'max', NaN, 'min', NaN, 'rms', NaN, 'n', 0);
    m = struct( ...
        'mean_cross_track', NaN, 'max_cross_track', NaN, ...
        'cte_waypoint_legacy_full', NaN, 'mean_cte_perp', NaN, ...
        'final_u', NaN, 'mean_yaw_err_deg', NaN, 'mean_pitch_err_deg', NaN, ...
        'pitch_chatter_dps', NaN, 'theta_pp_deg', NaN, ...
        'CTE_perp_settled_before_end', nanw);
end

function y = suite_hf_local(x, dt)
    n = max(3, round(0.8 / dt));
    b = ones(n,1) / n;
    lf = filter(b, 1, x(:));
    y = x(:) - lf;
    y(1:n) = 0;
end

function [s_nodes, s_total] = path_arclength(path)
    n = size(path, 1);
    s_nodes = zeros(n, 1);
    for i = 2:n
        s_nodes(i) = s_nodes(i-1) + norm(path(i,:) - path(i-1,:));
    end
    s_total = max(s_nodes(end), 1e-9);
end

function [s_best, d_best] = project_on_path(p, path, s_nodes, s_lo, s_hi, is_closed) %#ok<INUSD>
    [s_best, d_best] = project_interval(p, path, s_nodes, max(0,s_lo), min(s_nodes(end),s_hi));
end

function [s_best, d_best] = project_wrapped(p, path, s_nodes, s_lo, win, s_total)
    % Project onto segments covering [s_lo, s_lo+win] mod s_total (closed paths).
    s_hi = s_lo + win;
    if s_hi <= s_total
        [s_best, d_best] = project_interval(p, path, s_nodes, s_lo, min(s_total, s_hi));
    else
        [s1, d1] = project_interval(p, path, s_nodes, s_lo, s_total);
        [s2, d2] = project_interval(p, path, s_nodes, 0, mod(s_hi, s_total));
        if d1 <= d2
            s_best = s1; d_best = d1;
        else
            s_best = s2; d_best = d2;
        end
    end
end

function ds = wrap_arc(ds, s_total)
    ds = mod(ds + s_total/2, s_total) - s_total/2;
end

function [s_best, d_best] = project_interval(p, path, s_nodes, s_lo, s_hi)
    n = size(path, 1);
    d_best = inf;
    s_best = s_lo;
    i0 = max(1, find(s_nodes <= s_lo, 1, 'last'));
    i1 = min(n-1, find(s_nodes >= s_hi, 1, 'first'));
    if isempty(i0); i0 = 1; end
    if isempty(i1); i1 = n-1; end
    i0 = min(i0, n-1);
    i1 = max(i1, i0);
    for i = i0:i1
        a = path(i,:); b = path(i+1,:);
        ab = b - a;
        lab2 = sum(ab.^2);
        if lab2 < 1e-12; continue; end
        tt = max(0, min(1, dot(p - a, ab) / lab2));
        proj = a + tt * ab;
        d = norm(p - proj);
        s = s_nodes(i) + tt * (s_nodes(i+1) - s_nodes(i));
        if s < s_lo - 1e-9 || s > s_hi + 1e-9; continue; end
        if d < d_best
            d_best = d;
            s_best = s;
        end
    end
end

function [p, t_hat] = sample_path(path, s_nodes, s, is_closed)
    n = size(path, 1);
    s_total = s_nodes(end);
    if is_closed
        s = mod(s, s_total);
    else
        s = max(0, min(s_total, s));
    end
    i = max(1, min(n-1, find(s_nodes <= s, 1, 'last')));
    if isempty(i); i = 1; end
    ds = s_nodes(i+1) - s_nodes(i);
    if ds < 1e-12; tt = 0; else; tt = (s - s_nodes(i)) / ds; end
    p = path(i,:) + tt * (path(i+1,:) - path(i,:));
    tang = path(i+1,:) - path(i,:);
    if norm(tang) < 1e-9
        if i > 1; tang = path(i,:) - path(i-1,:); else; tang = [1,0,0]; end
    end
    t_hat = tang / norm(tang);
end
