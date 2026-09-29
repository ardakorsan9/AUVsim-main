function [yaw_ref, pitch_ref, u_ref, next_progress_index, r_ff, pitch_ref_dot] = guidance_law_depth_ndo(current_position, path, progress_index, u_body, v_body, U_h, zdot_inertial, theta_phys)
% ISOLATED CANDIDATE — DEPTH_NDO_CANDIDATE_001 (production guidance_law untouched).
% Depth-rate disturbance observer (NDO) → gamma_corr around frozen theta/q + climb FF.
% NED z down: e = z - z_ref (= cte(3) filtered z_e_f).
% Model: ė ≈ b0*gamma_corr + d,  b0 = U*Gdc = 1.5*0.9404 = 1.4106 m/(s·rad).
% FIXED (no sweep): kz=0.08 1/s, wo=0.30 rad/s, b0=1.4106.
%   d_meas = (zdot - zdot_ref) - b0*gamma_corr_prev
%   dhat_dot = wo*(d_meas - dhat)
%   gamma_corr_raw = (-kz*e - dhat)/b0; clamp ±9deg; rate ≤2deg/s
%   bumpless: dhat=0, gamma_corr=0; |dhat| bounded; filter on e/zdot; reset on init
%   pitch_raw = pitch_geom + gamma_corr

    global lookahead_distance desired_speed
    global pitch_ref_max pitch_ref_rate_max
    global dt_guidance dt_controller
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global K_zdot K_gamma enable_alpha_hat
    global last_gamma_actual last_gamma_path last_alpha_eff last_e_gamma
    global last_e_z last_e_zdot last_zdot_inertial last_alpha_hat
    global last_gamma_corr last_gamma_corr_raw
    global last_dhat last_d_meas last_d_resid last_ndo_reset
    global depth_ndo_b0 depth_ndo_kz depth_ndo_wo
    global depth_ndo_corr_max depth_ndo_rate_max depth_ndo_dhat_max

    persistent s_prog yaw_cont pitch_f z_e_f zd_e_f eg_f alpha_hat kappa_f chi_f yaw_out pitch_out initialized
    persistent dhat gamma_corr_prev d_meas_f
    if isempty(initialized); initialized = false; end
    if isempty(zd_e_f); zd_e_f = 0; end
    if isempty(eg_f); eg_f = 0; end
    if isempty(alpha_hat); alpha_hat = 0; end
    if isempty(dhat); dhat = 0; end                 % bumpless cold-start
    if isempty(gamma_corr_prev); gamma_corr_prev = 0; end
    if isempty(d_meas_f); d_meas_f = 0; end
    if isempty(pitch_ref_max); pitch_ref_max = deg2rad(25); end
    if isempty(pitch_ref_rate_max); pitch_ref_rate_max = deg2rad(5); end
    if isempty(K_zdot); K_zdot = 0; end
    if isempty(K_gamma); K_gamma = 0; end
    if isempty(enable_alpha_hat); enable_alpha_hat = false; end
    % Fixed NDO params (defaults if globals unset)
    if isempty(depth_ndo_b0); depth_ndo_b0 = 1.5 * 0.9404; end   % 1.4106 m/(s·rad)
    if isempty(depth_ndo_kz); depth_ndo_kz = 0.08; end            % 1/s
    if isempty(depth_ndo_wo); depth_ndo_wo = 0.30; end            % rad/s
    if isempty(depth_ndo_corr_max); depth_ndo_corr_max = deg2rad(9); end
    if isempty(depth_ndo_rate_max); depth_ndo_rate_max = deg2rad(2); end
    if isempty(depth_ndo_dhat_max); depth_ndo_dhat_max = 0.50; end % m/s vertical-rate bias bound
    if isempty(dt_guidance)
        if isempty(dt_controller); dt_controller = 0.0375; end
        dt_guidance = dt_controller;
    end
    dt_nom = dt_guidance;

    if nargin < 3 || isempty(progress_index)
        progress_index = 1;
    end
    if nargin < 4 || isempty(u_body); u_body = 1.0; end
    if nargin < 5 || isempty(v_body); v_body = 0.0; end
    if nargin < 6 || isempty(U_h)
        U_h = hypot(u_body, v_body); % body-horizontal fallback
    end
    if nargin < 7 || isempty(zdot_inertial)
        zdot_inertial = 0;
    end
    if nargin < 8 || isempty(theta_phys)
        theta_phys = 0;
    end
    U_h = max(U_h, 0);

    n = size(path, 1);
    if n < 2
        yaw_ref = 0; pitch_ref = 0; u_ref = desired_speed;
        next_progress_index = 1; r_ff = 0; pitch_ref_dot = 0;
        return;
    end

    % Arc-length table
    [s_nodes, s_total] = path_arclength(path);
    is_closed = norm(path(1,:) - path(end,:)) < 0.25;
    L = max(lookahead_distance, 1.0);

    % --- Nearest projection with monotonic progress ---
    s_prev = [];
    ndo_reset = false;
    if ~initialized
        [s_near, ~] = project_on_path(current_position, path, s_nodes, 0, s_total, is_closed);
        s_prog = s_near;
        yaw_cont = nan;
        pitch_f = nan;
        z_e_f = 0;
        zd_e_f = 0;
        eg_f = 0;
        alpha_hat = 0;
        kappa_f = 0;
        chi_f = nan;
        dhat = 0;                % bumpless dhat=0
        gamma_corr_prev = 0;     % bumpless corr=0
        d_meas_f = 0;
        ndo_reset = true;
        initialized = true;
    else
        s_prev = s_prog;
        s_lo = s_prog - 0.15;
        s_hi = s_prog + max(3.0, 2.5*L);
        if is_closed
            s_lo = mod(s_lo, s_total);
            s_hi = s_lo + max(3.0, 2.5*L);
        else
            s_lo = max(0, s_lo);
            s_hi = min(s_total, s_hi);
        end
        [s_near, ~] = project_on_path(current_position, path, s_nodes, s_lo, s_hi, is_closed);
        if is_closed
            ds = wrap_arc(s_near - s_prog, s_total);
            if ds < -0.25
                % ignore large backward snap
            else
                s_prog = mod(s_prog + max(ds, -0.05), s_total);
            end
        else
            s_prog = max(s_prog, s_near - 0.05);
            s_prog = min(s_prog, s_total);
        end
    end

    near_end = (~is_closed) && (s_prog >= s_total - 0.3);

    [p_path, t_hat] = sample_path(path, s_nodes, s_prog, is_closed);
    s_look = s_prog + L;
    if is_closed
        s_look = mod(s_look, s_total);
    else
        s_look = min(s_look, s_total);
    end
    [~, t_look] = sample_path(path, s_nodes, s_look, is_closed);

    if ~isempty(s_prev) && ~is_closed
        z_below = p_path(3) - current_position(3);
        if z_below > 2.5
            ds_max = max(0.05, 0.55 * max(u_body, 0.3) * dt_nom);
            s_prog = min(s_prog, s_prev + ds_max);
            [p_path, t_hat] = sample_path(path, s_nodes, s_prog, is_closed);
            s_look = min(s_total, s_prog + L);
            [~, t_look] = sample_path(path, s_nodes, s_look, is_closed);
        end
    end

    kappa_raw = path_curvature_at(path, s_nodes, s_prog, is_closed);
    kappa_f = 0.96 * kappa_f + 0.04 * kappa_raw;
    R_abs = 1 / max(abs(kappa_f), 1e-4);

    cte = current_position - p_path;
    t_h = t_hat(1:2);
    if norm(t_h) < 1e-9
        t_h = [1, 0];
    else
        t_h = t_h / norm(t_h);
    end
    n_h = [-t_h(2), t_h(1)];
    y_e = dot(cte(1:2), n_h);
    % Filter vertical error (same LPF as production)
    z_e_f = 0.93 * z_e_f + 0.07 * cte(3);

    u_ref = desired_speed * (R_abs / (R_abs + 2.5));
    u_ref = max(0.9, min(desired_speed, u_ref));
    if abs(z_e_f) > 3.0
        u_ref = min(u_ref, 1.15);
    end
    if near_end
        u_ref = 0.7 * desired_speed;
    end

    chi_path = atan2(t_look(2), t_look(1));
    if isnan(chi_f)
        chi_f = chi_path;
    else
        chi_f = chi_f + 0.28 * wrapToPi(chi_path - chi_f);
    end
    chi_los = atan2(-y_e, L + 0.6);
    beta = atan2(v_body, max(u_body, 0.35));
    k_beta = 1.35;
    if near_end
        yaw_raw = atan2(t_hat(2), t_hat(1));
    else
        yaw_raw = wrapToPi(chi_f + 0.75 * chi_los - k_beta * beta);
    end

    if isnan(yaw_cont)
        yaw_cont = yaw_raw;
    else
        yaw_cont = yaw_cont + wrapToPi(yaw_raw - yaw_cont);
    end

    pitch_path = atan2(t_look(3), max(norm(t_look(1:2)), 1e-6));
    pitch_now = atan2(t_hat(3), max(norm(t_hat(1:2)), 1e-6));
    if near_end
        pitch_geom = pitch_now;
    else
        pitch_geom = 0.65 * pitch_path + 0.35 * pitch_now;
    end

    % ---- Depth-rate NDO ----
    % e = z - z_ref (NED down) = cte(3) filtered
    e = z_e_f;
    U_along = max(hypot(U_h, zdot_inertial), 0.3);
    zdot_ref = t_hat(3) * U_along;           % path vertical rate [m/s]
    zd_e_raw = zdot_inertial - zdot_ref;     % (zdot - zdot_ref) [m/s]
    zd_e_f = 0.85 * zd_e_f + 0.15 * zd_e_raw;

    b0 = depth_ndo_b0;                       % m/(s·rad)
    kz = depth_ndo_kz;                       % 1/s
    wo = depth_ndo_wo;                       % rad/s (= 1/s)
    corr_max = depth_ndo_corr_max;
    rate_max = depth_ndo_rate_max;
    dhat_max = depth_ndo_dhat_max;

    % Soft reset if filtered depth error blows (keeps observer bounded)
    if abs(e) > 8.0 || ~isfinite(e) || ~isfinite(zd_e_f)
        dhat = 0;
        gamma_corr_prev = 0;
        d_meas_f = 0;
        ndo_reset = true;
    end

    % d_meas = (zdot - zdot_ref) - b0*gamma_corr_prev  [m/s]
    % Use filtered vertical-rate error for noise robustness (same α as prod zd filter)
    d_meas_raw = zd_e_f - b0 * gamma_corr_prev;
    d_meas_f = 0.85 * d_meas_f + 0.15 * d_meas_raw;
    d_meas = d_meas_f;

    % Observer: dhat_dot = wo*(d_meas - dhat)
    dhat = dhat + wo * (d_meas - dhat) * dt_nom;
    dhat = max(min(dhat, dhat_max), -dhat_max);   % bound |dhat| ≤ 0.50 m/s

    % gamma_corr_raw = (-kz*e - dhat)/b0  [rad]
    gamma_corr_raw = (-kz * e - dhat) / max(b0, 1e-9);
    gamma_mag = max(min(gamma_corr_raw, corr_max), -corr_max);
    dg_max = rate_max * dt_nom;
    gamma_corr = gamma_corr_prev + max(min(gamma_mag - gamma_corr_prev, dg_max), -dg_max);
    gamma_corr = max(min(gamma_corr, corr_max), -corr_max);
    gamma_corr_prev = gamma_corr;

    d_resid = d_meas - dhat;                  % observer residual [m/s]

    U_h_safe = max(U_h, 0.05);
    U_path_h = max(U_along * hypot(t_hat(1), t_hat(2)), 0.05);
    gamma_actual = atan2(zdot_inertial, U_h_safe);
    gamma_path = atan2(zdot_ref, U_path_h);
    e_gamma_raw = wrapToPi(gamma_path - gamma_actual);
    eg_f = 0.85 * eg_f + 0.15 * e_gamma_raw;
    alpha_eff = theta_phys - gamma_actual;
    e_z_log = -z_e_f;
    e_zdot_log = -zd_e_raw;

    gamma_cmd = pitch_geom + K_gamma * eg_f + gamma_corr;
    if enable_alpha_hat && u_body >= 0.50
        alpha_hat = 0.98 * alpha_hat + 0.02 * alpha_eff;
        alpha_hat = max(min(alpha_hat, deg2rad(8)), deg2rad(-8));
        pitch_raw = gamma_path + K_gamma * eg_f + gamma_corr + alpha_hat;
    else
        alpha_hat = 0.98 * alpha_hat;
        pitch_raw = gamma_cmd;
    end
    pitch_raw = max(min(pitch_raw, pitch_ref_max), -pitch_ref_max);

    last_gamma_actual = gamma_actual;
    last_gamma_path = gamma_path;
    last_alpha_eff = alpha_eff;
    last_e_gamma = eg_f;
    last_e_z = e_z_log;
    last_e_zdot = e_zdot_log;
    last_zdot_inertial = zdot_inertial;
    last_alpha_hat = alpha_hat;
    last_gamma_corr = gamma_corr;
    last_gamma_corr_raw = gamma_corr_raw;
    last_dhat = dhat;
    last_d_meas = d_meas;
    last_d_resid = d_resid;
    last_ndo_reset = double(ndo_reset);

    if isnan(pitch_f)
        pitch_f = pitch_raw;
        pitch_out = pitch_raw;
    else
        pitch_f = 0.90 * pitch_f + 0.10 * pitch_raw;
    end

    max_dyaw = deg2rad(40) * dt_nom;

    if isempty(yaw_out)
        yaw_out = yaw_cont;
        pitch_out = pitch_f;
    end
    dy = 0.35 * (yaw_cont - yaw_out);
    dy = max(min(dy, max_dyaw), -max_dyaw);
    yaw_out = yaw_out + dy;

    dp_des = pitch_f - pitch_out;
    dp_max = pitch_ref_rate_max * dt_nom;
    dp = max(min(dp_des, dp_max), -dp_max);
    pitch_out = pitch_out + dp;
    pitch_out = max(min(pitch_out, pitch_ref_max), -pitch_ref_max);

    yaw_ref = yaw_out;
    pitch_ref = pitch_out;
    pitch_ref_dot = dp / dt_nom;

    r_ff = U_h * kappa_f;
    r_ff = max(min(r_ff, deg2rad(40)), deg2rad(-40));
    last_guidance_U_h = U_h;
    last_guidance_kappa = kappa_f;
    last_r_ff = r_ff;

    next_progress_index = max(1, min(n, 1 + sum(s_nodes <= s_prog)));
    if ~is_closed
        next_progress_index = max(next_progress_index, progress_index);
    end
end

%% ===== helpers =====
function [s_nodes, s_total] = path_arclength(path)
    n = size(path, 1);
    s_nodes = zeros(n, 1);
    for i = 2:n
        s_nodes(i) = s_nodes(i-1) + norm(path(i,:) - path(i-1,:));
    end
    s_total = s_nodes(end);
    if s_total < 1e-9
        s_total = 1e-9;
    end
end

function d = wrap_arc(ds, s_total)
    d = mod(ds + 0.5*s_total, s_total) - 0.5*s_total;
end

function [s_best, d_best] = project_on_path(p, path, s_nodes, s_lo, s_hi, is_closed)
    n = size(path, 1);
    s_total = s_nodes(end);
    d_best = inf;
    s_best = s_lo;

    if is_closed && s_hi > s_total
        [s1, d1] = project_interval(p, path, s_nodes, s_lo, s_total);
        [s2, d2] = project_interval(p, path, s_nodes, 0, mod(s_hi, s_total));
        if d1 <= d2
            s_best = s1; d_best = d1;
        else
            s_best = s2; d_best = d2;
        end
    else
        [s_best, d_best] = project_interval(p, path, s_nodes, max(0,s_lo), min(s_total,s_hi));
    end
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
        if lab2 < 1e-12
            continue;
        end
        t = dot(p - a, ab) / lab2;
        t = max(0, min(1, t));
        proj = a + t * ab;
        d = norm(p - proj);
        s = s_nodes(i) + t * (s_nodes(i+1) - s_nodes(i));
        if s < s_lo - 1e-9 || s > s_hi + 1e-9
            continue;
        end
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
    if ds < 1e-12
        t = 0;
    else
        t = (s - s_nodes(i)) / ds;
    end
    p = path(i,:) + t * (path(i+1,:) - path(i,:));
    tang = path(i+1,:) - path(i,:);
    if norm(tang) < 1e-9
        if i > 1
            tang = path(i,:) - path(i-1,:);
        else
            tang = [1, 0, 0];
        end
    end
    t_hat = tang / norm(tang);
end

function kappa = path_curvature_at(path, s_nodes, s, is_closed)
    s_total = s_nodes(end);
    ds = max(0.4, 0.05 * s_total);
    [~, t1] = sample_path(path, s_nodes, s - ds, is_closed);
    [~, t2] = sample_path(path, s_nodes, s + ds, is_closed);
    a = t1(1:2); b = t2(1:2);
    if norm(a) < 1e-9 || norm(b) < 1e-9
        kappa = 0;
        return;
    end
    a = a / norm(a); b = b / norm(b);
    ang = atan2(a(1)*b(2) - a(2)*b(1), a(1)*b(1) + a(2)*b(2));
    kappa = ang / (2*ds);
end
