function [yaw_ref, pitch_ref, u_ref, next_progress_index, r_ff, pitch_ref_dot] = guidance_law_depth_gamma_structural_attempt3(current_position, path, progress_index, u_body, v_body, U_h, zdot_inertial, theta_phys)
% ISOLATED Gate-2 final attempt 3/3 minimally-invasive governor (production guidance_law untouched).
% Keeps frozen production depth P+I (Kz=0.050, Ki=0.006) — no gain hunting.
% Adds DERIVED structural layers from DEPTH_GAMMA_SPEED_SCHEDULED_ID maps:
%   (1) trim-referenced incremental decoupling:
%         delta_alpha = alpha_sched(mode,U) - alpha_level(U)
%         theta_cmd = gamma_cmd - delta_alpha
%       so level elevator trim is not double-counted (absolute alpha injection removed)
%   (2) (z,gamma,theta) feasibility governor vs elevator ±15deg / ±40deg/s / climb-FF
%   (3) anti-windup driven by mag/rate elevator residual (globals)
%   (4) bumpless cold-start of pitch_out / alpha_sched / I=0
% Convention (Gate-1): gamma = theta_phys + alpha; alpha = gamma - theta_phys = atan2(w,u)
% Never: gamma INDI/PI/LADRC, depth PI/NDO replace, polyline shaper.

    global lookahead_distance desired_speed
    global pitch_ref_max pitch_ref_rate_max
    global dt_guidance dt_controller
    global last_guidance_U_h last_guidance_kappa last_r_ff
    global K_zdot K_gamma enable_alpha_hat
    global last_gamma_actual last_gamma_path last_alpha_eff last_e_gamma
    global last_e_z last_e_zdot last_zdot_inertial last_alpha_hat
    global struct_de_mag_res struct_de_rate_res
    global last_struct_alpha_sched last_struct_gamma_cmd last_struct_theta_cmd
    global last_struct_gov_clip last_struct_aw_event last_struct_bumpless
    global last_struct_gov_gamma_lim last_struct_gov_theta_lim
    global last_struct_theta_unconstrained last_struct_theta_governed
    global last_struct_intervention_reason last_struct_distortion last_struct_theta_tracking

    persistent s_prog yaw_cont pitch_f z_e_f z_e_i zd_e_f eg_f alpha_hat kappa_f chi_f yaw_out pitch_out initialized
    persistent alpha_sched_f theta_gov_prev bumpless_done
    if isempty(initialized); initialized = false; end
    if isempty(z_e_i); z_e_i = 0; end
    if isempty(zd_e_f); zd_e_f = 0; end
    if isempty(eg_f); eg_f = 0; end
    if isempty(alpha_hat); alpha_hat = 0; end
    if isempty(bumpless_done); bumpless_done = false; end
    if isempty(pitch_ref_max); pitch_ref_max = deg2rad(25); end
    if isempty(pitch_ref_rate_max); pitch_ref_rate_max = deg2rad(5); end
    if isempty(K_zdot); K_zdot = 0; end
    if isempty(K_gamma); K_gamma = 0; end
    if isempty(enable_alpha_hat); enable_alpha_hat = false; end
    if isempty(struct_de_mag_res); struct_de_mag_res = 0; end
    if isempty(struct_de_rate_res); struct_de_rate_res = 0; end
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
        zdot_inertial = 0; % no D term without inertial zdot
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
    L = max(lookahead_distance, 1.0); % too-small L amplifies projection chatter

    % --- Nearest projection with monotonic progress ---
    s_prev = [];
    if ~initialized
        [s_near, ~] = project_on_path(current_position, path, s_nodes, 0, s_total, is_closed);
        s_prog = s_near;
        yaw_cont = nan;
        pitch_f = nan;   % cold-start from path slope (critical for XZ)
        z_e_f = 0;
        z_e_i = 0;
        zd_e_f = 0;
        eg_f = 0;
        alpha_hat = 0;
        kappa_f = 0;
        chi_f = nan;
        initialized = true;
    else
        s_prev = s_prog;
        % Only search a forward window in arc-length (prevents back-jumps)
        s_lo = s_prog - 0.15;                 % tiny backward tolerance
        s_hi = s_prog + max(3.0, 2.5*L);      % forward window
        if is_closed
            s_lo = mod(s_lo, s_total);
            s_hi = s_lo + max(3.0, 2.5*L);
        else
            s_lo = max(0, s_lo);
            s_hi = min(s_total, s_hi);
        end
        [s_near, ~] = project_on_path(current_position, path, s_nodes, s_lo, s_hi, is_closed);
        % Monotonic blend: never fall back more than 5 cm on open paths
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

    % Path pose at progress and at lookahead
    [p_path, t_hat] = sample_path(path, s_nodes, s_prog, is_closed);
    s_look = s_prog + L;
    if is_closed
        s_look = mod(s_look, s_total);
    else
        s_look = min(s_look, s_total);
    end
    [~, t_look] = sample_path(path, s_nodes, s_look, is_closed);

    % Mild progress hold only for large depth lag (avoid depth-loop fight)
    if ~isempty(s_prev) && ~is_closed
        z_below = p_path(3) - current_position(3); % >0 => vehicle below path
        if z_below > 2.5
            ds_max = max(0.05, 0.55 * max(u_body, 0.3) * dt_nom);
            s_prog = min(s_prog, s_prev + ds_max);
            [p_path, t_hat] = sample_path(path, s_nodes, s_prog, is_closed);
            s_look = min(s_total, s_prog + L);
            [~, t_look] = sample_path(path, s_nodes, s_look, is_closed);
        end
    end

    % Curvature (smoothed)
    kappa_raw = path_curvature_at(path, s_nodes, s_prog, is_closed);
    kappa_f = 0.96 * kappa_f + 0.04 * kappa_raw; % heavy smooth — kappa chatter -> rudder chatter
    R_abs = 1 / max(abs(kappa_f), 1e-4);

    % Cross-track (vehicle - path), filter vertical error
    cte = current_position - p_path;
    t_h = t_hat(1:2);
    if norm(t_h) < 1e-9
        t_h = [1, 0];
    else
        t_h = t_h / norm(t_h);
    end
    n_h = [-t_h(2), t_h(1)];
    y_e = dot(cte(1:2), n_h);
    z_e_f = 0.93 * z_e_f + 0.07 * cte(3); % heavier filter — depth loop was oscillating

    % Speed schedule
    u_ref = desired_speed * (R_abs / (R_abs + 2.5));
    u_ref = max(0.9, min(desired_speed, u_ref));
    if abs(z_e_f) > 3.0
        u_ref = min(u_ref, 1.15);
    end
    if near_end
        u_ref = 0.7 * desired_speed;
    end

    % --- Yaw: filter COURSE first (before unwrap), then soft CTE ---
    chi_path = atan2(t_look(2), t_look(1));
    if isnan(chi_f)
        chi_f = chi_path;
    else
        chi_f = chi_f + 0.28 * wrapToPi(chi_path - chi_f); % faster course tracking
    end
    chi_los = atan2(-y_e, L + 0.6); % stronger lateral LOS for circle radius
    % Sideslip compensation: psi_ref = path + LOS - k_beta*beta (crab)
    beta = atan2(v_body, max(u_body, 0.35));
    k_beta = 1.35;
    if near_end
        yaw_raw = atan2(t_hat(2), t_hat(1));
    else
        yaw_raw = wrapToPi(chi_f + 0.75 * chi_los - k_beta * beta);
    end

    % Continuous unwrap (kills ±pi step impulses)
    if isnan(yaw_cont)
        yaw_cont = yaw_raw;
    else
        yaw_cont = yaw_cont + wrapToPi(yaw_raw - yaw_cont);
    end

    % --- Pitch ref: lookahead path slope + stronger depth catch-up ---
    pitch_path = atan2(t_look(3), max(norm(t_look(1:2)), 1e-6));
    % also blend current-segment slope so end-of-path doesn't zero pitch early
    pitch_now = atan2(t_hat(3), max(norm(t_hat(1:2)), 1e-6));
    if near_end
        pitch_geom = pitch_now;
    else
        pitch_geom = 0.65 * pitch_path + 0.35 * pitch_now;
    end
    % Soft depth P+I — FROZEN production gains (no hunting / no depth-PI replace)
    % Sign: cte(3)=z_veh-z_path; pitch_corr = -Kz*cte = +Kz*(z_path-z)  [preserved]
    z_e_i = z_e_i + z_e_f * dt_nom;
    z_e_i = max(min(z_e_i, 25), -25);

    % (3) Anti-windup from elevator mag/rate residual (structural; not new PI)
    de_res = struct_de_mag_res + struct_de_rate_res;
    aw_event = 0;
    Kaw_struct = 8.0;   % [1] residual→I bleed strength (TUNED isolated; not production)
    if abs(de_res) > 1e-4
        % Bleed depth-I when residual fights the depth error (same-sign family)
        if sign(z_e_f) == sign(de_res) || abs(de_res) > deg2rad(0.5)
            z_e_i = z_e_i - Kaw_struct * de_res * dt_nom;
            z_e_i = max(min(z_e_i, 25), -25);
            aw_event = 1;
        end
    end

    U_along = max(hypot(U_h, zdot_inertial), 0.3);
    zdot_path = t_hat(3) * U_along;
    zd_e_raw = zdot_inertial - zdot_path;
    zd_e_f = 0.85 * zd_e_f + 0.15 * zd_e_raw;
    pitch_corr = -0.050 * z_e_f - 0.006 * z_e_i - K_zdot * zd_e_f;
    pitch_corr = max(min(pitch_corr, deg2rad(9)), deg2rad(-9));

    U_h_safe = max(U_h, 0.05);
    U_path_h = max(U_along * hypot(t_hat(1), t_hat(2)), 0.05);
    gamma_actual = atan2(zdot_inertial, U_h_safe);
    gamma_path = atan2(zdot_path, U_path_h);
    e_gamma_raw = wrapToPi(gamma_path - gamma_actual);
    eg_f = 0.85 * eg_f + 0.15 * e_gamma_raw;
    % Gate-1 documented: gamma = theta_phys + alpha  =>  alpha = gamma - theta_phys
    % (equiv. BODY alpha = atan2(w,u); guidance has no raw w here)
    alpha_eff = gamma_actual - theta_phys;
    e_z_log = -z_e_f;
    e_zdot_log = -zd_e_raw;

    % Production gamma_cmd (K_gamma frozen at 0 in suite)
    gamma_cmd0 = pitch_geom + K_gamma * eg_f + pitch_corr;

    % (1) Trim-referenced incremental alpha decoupling — IDENTIFIED maps @ U={1,1.5,2}
    % Absolute alpha_sched injection double-counted controller de_trim level AoA.
    U_cmd = max(desired_speed, 0.5);
    w_climb = climb_blend(abs(gamma_path));   % DERIVED from climb gamma*≈0.3805
    alpha_L = alpha_sched_level(U_cmd);
    alpha_C = alpha_sched_climb(U_cmd);
    alpha_sched = (1 - w_climb) * alpha_L + w_climb * alpha_C;
    delta_alpha = alpha_sched - alpha_L;      %#ok<NASGU> % 0 at level; climb-only incremental
    if isempty(alpha_sched_f)
        alpha_sched_f = alpha_sched;           % (4) bumpless absolute-alpha state seed
    else
        alpha_sched_f = 0.92 * alpha_sched_f + 0.08 * alpha_sched;
    end
    delta_alpha_f = alpha_sched_f - alpha_L;  % filtered incremental (level-referenced)

    % (2) Final-attempt governor: production-equivalent theta target first, then intervene only
    % when the scheduled finite-horizon elevator magnitude/rate prediction is outside envelope.
    de_max = deg2rad(15); de_rate_max = deg2rad(40); de_ff_lim = deg2rad(2.8793);
    Gth = max(gfh_theta_de(U_cmd), 0.05);
    de_budget = max(0, de_max - abs(de_trim_sched(U_cmd)) - w_climb * de_ff_lim);
    theta_authority = Gth * de_budget;

    % Incremental alpha is climb/path-slope only and cannot consume more than scheduled authority.
    path_slope_nonzero = abs(gamma_path) > deg2rad(0.1);
    if path_slope_nonzero
        delta_alpha_used = max(min(delta_alpha_f, theta_authority), -theta_authority);
    else
        delta_alpha_used = 0;
    end
    theta_unconstrained = gamma_cmd0 - delta_alpha_used;

    if isempty(theta_gov_prev); theta_gov_prev = theta_phys; end
    mag_res_pred = max(0, abs(theta_unconstrained - theta_phys) / Gth - de_budget);
    rate_res_pred = max(0, abs(theta_unconstrained - theta_gov_prev) / (Gth * dt_nom) - de_rate_max);
    mag_threat = mag_res_pred > 1e-12;
    rate_threat = rate_res_pred > 1e-12;
    intervention_reason = double(mag_threat) + 2 * double(rate_threat); % 0 none,1 mag,2 rate,3 both

    theta_governed = theta_unconstrained; % exact pass-through inside both envelopes
    if intervention_reason ~= 0
        % Reachability tube is explicitly centered on measured physical theta.
        tube_half = theta_authority;
        if rate_threat
            tube_half = min(tube_half, Gth * de_rate_max * dt_nom);
        end
        theta_governed = max(min(theta_unconstrained, theta_phys + tube_half), theta_phys - tube_half);
    end

    % Final theta rate limit is applied after every decoupling/governor term.
    dtheta_max = min(pitch_ref_rate_max, Gth * de_rate_max);
    dtheta = max(min(theta_governed - theta_gov_prev, dtheta_max * dt_nom), -dtheta_max * dt_nom);
    theta_cmd = theta_gov_prev + dtheta;
    if abs(theta_cmd - theta_unconstrained) > 1e-12 && intervention_reason == 0
        intervention_reason = 2;
    end
    theta_gov_prev = theta_cmd;
    gov_clip = double(intervention_reason ~= 0);
    gamma_lim = NaN; theta_lim = theta_authority;

    % Disable production alpha_hat path; structural schedule replaces it
    alpha_hat = 0.98 * alpha_hat;
    pitch_raw = theta_cmd;
    pitch_raw = max(min(pitch_raw, pitch_ref_max), -pitch_ref_max);

    last_gamma_actual = gamma_actual;
    last_gamma_path = gamma_path;
    last_alpha_eff = alpha_eff;
    last_e_gamma = eg_f;
    last_e_z = e_z_log;
    last_e_zdot = e_zdot_log;
    last_zdot_inertial = zdot_inertial;
    last_alpha_hat = alpha_sched_f;   % absolute scheduled alpha (for residual scoring)
    last_struct_alpha_sched = alpha_sched_f;
    last_struct_gamma_cmd = gamma_cmd0;
    last_struct_theta_cmd = pitch_raw;
    last_struct_theta_unconstrained = theta_unconstrained;
    last_struct_theta_governed = theta_cmd;
    last_struct_intervention_reason = intervention_reason;
    last_struct_distortion = theta_cmd - theta_unconstrained;
    last_struct_theta_tracking = theta_phys - theta_cmd;
    last_struct_gov_clip = gov_clip;
    last_struct_aw_event = aw_event;
    last_struct_gov_gamma_lim = gamma_lim;
    last_struct_gov_theta_lim = theta_lim;
    last_struct_bumpless = double(~bumpless_done);

    if isnan(pitch_f) || ~bumpless_done
        % (4) Bumpless: cold-start pitch at feasible theta = gamma - delta_alpha
        pitch_f = pitch_raw;
        pitch_out = pitch_raw;
        bumpless_done = true;
        last_struct_bumpless = 1;
    else
        pitch_f = 0.90 * pitch_f + 0.10 * pitch_raw;
    end

    max_dyaw = deg2rad(40) * dt_nom; % allow tracking circle rate ~u/R

    if isempty(yaw_out)
        yaw_out = yaw_cont;
        pitch_out = pitch_f;
    end
    dy = 0.35 * (yaw_cont - yaw_out);
    dy = max(min(dy, max_dyaw), -max_dyaw);
    yaw_out = yaw_out + dy;

    % Explicit pitch ref rate limit
    dp_des = pitch_f - pitch_out;
    dp_max = pitch_ref_rate_max * dt_nom;
    dp = max(min(dp_des, dp_max), -dp_max);
    pitch_out = pitch_out + dp;
    pitch_out = max(min(pitch_out, pitch_ref_max), -pitch_ref_max);

    yaw_ref = yaw_out;
    pitch_ref = pitch_out;
    pitch_ref_dot = dp / dt_nom;

    % Tur4A: yaw-rate FF from inertial horizontal speed × path curvature
    % (replaces 1.15*u_ref*kappa — u_ref was speed-scheduled down on curves)
    r_ff = U_h * kappa_f;
    r_ff = max(min(r_ff, deg2rad(40)), deg2rad(-40));
    last_guidance_U_h = U_h;
    last_guidance_kappa = kappa_f;
    last_r_ff = r_ff;

    % Integer index for suite progress (display / legacy)
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

    % Map search to segment indices
    if is_closed && s_hi > s_total
        % two intervals: [s_lo, s_total] U [0, s_hi - s_total]
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

%% ===== Gate-2 structural maps (DERIVED from DEPTH_GAMMA_SPEED_SCHEDULED_ID) =====
function a = alpha_sched_level(U)
    % IDENTIFIED BODY alpha* at level U_cmd={1,1.5,2}
    Ugrid = [1.0, 1.5, 2.0];
    A = [-0.0742888, -0.0333395, -0.0188097];
    a = interp1(Ugrid, A, U, 'linear', 'extrap');
end

function a = alpha_sched_climb(U)
    % IDENTIFIED BODY alpha* at climb slope≈0.4, U_cmd={1,1.5,2}
    Ugrid = [1.0, 1.5, 2.0];
    A = [-0.10838, -0.0513342, -0.0296065];
    a = interp1(Ugrid, A, U, 'linear', 'extrap');
end

function w = climb_blend(abs_gamma)
    % Soft blend toward climb map using IDENTIFIED climb gamma*≈0.380506
    g_climb = 0.380506;
    w = max(0, min(1, abs_gamma / max(g_climb, 1e-6)));
end

function G = gfh_theta_de(U)
    % |Gfh theta_phys←δe| @ T=0.6s level (DERIVED Gate-1)
    Ugrid = [1.0, 1.5, 2.0];
    Gv = [0.133026846, 0.312771573, 0.585899527];
    G = interp1(Ugrid, Gv, U, 'linear', 'extrap');
end

function Gg = gfh_gamma_de(U)
    % |Gfh gamma←δe| @ T=0.6s level (DERIVED Gate-1)
    Ugrid = [1.0, 1.5, 2.0];
    Gv = [0.0275237943, 0.123227827, 0.289780440];
    Gg = interp1(Ugrid, Gv, U, 'linear', 'extrap');
end

function de_tr = de_trim_sched(U)
    % Production trim table (same as controller lookup)
    Us = [0.8, 1.0, 1.5, 2.0];
    De = deg2rad([-9.18, -7.33, -4.62, -3.17]);
    de_tr = interp1(Us, De, U, 'linear', 'extrap');
end

function [gamma_lim, theta_lim] = feasibility_limits(U, w_climb)
    % Elevator ±15deg, rate ±40deg/s (envelope), climb-FF ±2.8793deg accepted
    de_max = deg2rad(15);
    de_climb_ff_lim = deg2rad(2.8793);   % accepted climb-FF bound (IMPLEMENTED)
    de_tr = abs(de_trim_sched(U));
    de_fb_budget = max(0.05, de_max - de_tr - de_climb_ff_lim);
    Gth = gfh_theta_de(U);
    Gg = gfh_gamma_de(U);
    % Reachable delta about trim from elevator FB (finite-horizon DERIVED)
    dtheta_fb = Gth * de_fb_budget;
    dgamma_fb = Gg * de_fb_budget;
    % Mode-aware center: level theta≈-alpha_L; climb theta≈gamma*-alpha_C
    th_L = -alpha_sched_level(U);
    th_C = 0.380506 - alpha_sched_climb(U);
    th0 = (1 - w_climb) * th_L + w_climb * th_C;
    g0 = (1 - w_climb) * 0 + w_climb * 0.380506;
    theta_lim = abs(th0) + dtheta_fb + deg2rad(3);  % small ASSUMED margin
    gamma_lim = abs(g0) + dgamma_fb + deg2rad(3);
    % Hard envelope vs pitch_ref_max family
    theta_lim = min(theta_lim, deg2rad(25));
    gamma_lim = min(gamma_lim, deg2rad(25));
end
