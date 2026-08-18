function run_outer_gamma_pi_scaffold()
% OUTER_GAMMA_PI_SCAFFOLD_001 — isolated outer gamma-PI on production theta/q cascade.
% Read-only: OUTER_GAMMA_INDI_AUDIT.mat, controller_law.m, underwater777_vehicle_dynamics.m
% Direct gamma-INDI rejected (NMP/RHP-zero sign conflict). Production untouched.
% One MATLAB invocation. Fixed Kp/Ki from validated closed-inner LTI (no gain sweep).

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'OUTER_GAMMA_PI_SCAFFOLD';
    task_id = 'OUTER_GAMMA_PI_SCAFFOLD_001';

    audit_mat = fullfile(out_dir, 'OUTER_GAMMA_INDI_AUDIT.mat');
    ctrl_path = fullfile(project_dir, 'controller_law.m');
    plant_path = fullfile(project_dir, 'underwater777_vehicle_dynamics.m');
    A = load(audit_mat);

    % ---- Fixed outer PI from validated closed-inner model (SIMC / FO of T_gamma) ----
    des = derive_outer_pi(A);
    P = struct();
    P.Kp = des.Kp;                      % [rad_theta / rad_gamma] dimensionless
    P.Ki = des.Ki;                      % [1/s]
    P.Kaw = des.Kaw;                    % [1/s] back-calculation
    P.corr_max = deg2rad(4);            % theta correction clamp
    P.I_max = deg2rad(2);               % I contribution clamp
    P.de_max = deg2rad(15);
    P.de_rate_max = deg2rad(40);
    P.dt = 0.025;
    P.T_settle = 5.0;
    P.T_hold = 18.0;                    % >=20s total with settle
    P.amp = deg2rad(1);
    P.improve_frac = 0.05;
    P.worsen_frac = 0.02;
    P.band_frac = 0.05;
    P.os_max_frac = 0.35;               % |OS| <= 35% of |step| (no overshoot gate)
    P.chatter_xc_max = 12;              % post-step de-rate zero-crossings
    P.design = des;

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources (read-only): OUTER_GAMMA_INDI_AUDIT.mat | controller_law.m | underwater777_vehicle_dynamics.m\n');
    fprintf('Outer PI: Kp=%.6g  Ki=%.6g 1/s  (wo=%.3g, bwi=%.4g, Gdc=%.5g, sep=%.3g)\n', ...
        P.Kp, P.Ki, des.wo, des.bwi, des.Gdc, des.sep);
    fprintf('Clamps: dtheta +/-%.0fdeg, I +/-%.0fdeg; actuator +/-%.0fdeg @ %.0fdeg/s\n', ...
        rad2deg(P.corr_max), rad2deg(P.I_max), rad2deg(P.de_max), rad2deg(P.de_rate_max));
    fprintf('Production cascade untouched.\n');

    ops = {pack_op('level', A.level), pack_op('climb', A.climb)};
    signs = [+1, -1];

    rows = {};
    for io = 1:numel(ops)
        op = ops{io};
        for is = 1:numel(signs)
            amp = signs(is) * P.amp;
            B = sim_case(op, amp, false, P);
            S = sim_case(op, amp, true, P);
            R = score_pair(op.name, amp, B, S, P);
            rows{end+1} = R; %#ok<AGROW>
            fprintf('  %s step%+.0fdeg: base MAE=%.4f p95=%.4f set=%.2fs | pi MAE=%.4f p95=%.4f set=%.2fs | %s\n', ...
                op.name, rad2deg(amp), R.mae_base_deg, R.p95_base_deg, R.settle_base_s, ...
                R.mae_scaf_deg, R.p95_scaf_deg, R.settle_scaf_s, tern(R.pass_case, 'PASS', 'FAIL'));
        end
    end

    gate = rollup_gates(rows, P);
    if gate.pass
        verdict = 'PASS';
        decision = 'ACCEPT_OUTER_GAMMA_PI_SCAFFOLD';
        next_step = 'path_benchmark_outer_gamma_PI';
        reason = ['Outer gamma-PI scaffold accepted: stable/correct sign, aggregate MAE or ' ...
            'persistent settle improved >=5%, no case MAE/p95 worsened >2%, sat=0, rates OK, ' ...
            'no chatter/overshoot, internals bounded.'];
    else
        verdict = 'FAIL';
        decision = 'REJECT_OUTER_GAMMA_PI_SCAFFOLD';
        next_step = 'ADRC_outer_gamma_audit_candidate';
        reason = ['Outer gamma-PI scaffold rejected: ' gate.fail_detail ...
            ' Next: one ADRC audit/candidate on theta/q cascade.'];
    end

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, rows, ops, P, task_id, verdict);
    write_md(md_path, task_id, verdict, decision, reason, next_step, gate, rows, P, ...
        audit_mat, ctrl_path, plant_path, md_path, mat_path, png_path);
    append_ss_audit(out_dir, task_id, verdict, decision, reason, next_step, gate, rows, P, ...
        md_path, mat_path, png_path);

    Out = struct();
    Out.task_id = task_id;
    Out.verdict = verdict;
    Out.decision = decision;
    Out.reason = reason;
    Out.next = next_step;
    Out.params = P;
    Out.design = des;
    Out.gate = gate;
    Out.rows = rows;
    Out.sources = {audit_mat; ctrl_path; plant_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Out.note = ['Isolated outer gamma-PI vs production cascade; ' ...
        'fixed SIMC gains from closed-inner T_gamma; production untouched'];
    save(mat_path, '-struct', 'Out');

    fprintf('\nVERDICT: %s\n', verdict);
    fprintf('DECISION: %s\n', decision);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, decision, reason, next_step, gate, rows, P, md_path, mat_path, png_path);
end

%% ===================== gain derivation (no sweep) =====================
function des = derive_outer_pi(A)
    % Validated closed-inner T_gamma ~ Gdc / (tau s + 1), tau=1/bwi.
    % SIMC PI for overdamped outer bw wo = min(0.30, bwi/3).
    % Kp = tau/(Gdc*tc), Ki = 1/(Gdc*tc), tc=1/wo. Units: Kp [-], Ki [1/s].
    Gdc = 0.5 * (A.level.Gdc_gamma_from_theta + A.climb.Gdc_gamma_from_theta);
    bwi = 0.5 * (A.level.bw_theta_cl + A.climb.bw_theta_cl);
    wo_cap = 0.30;
    wo_sep = bwi / 3.0;
    wo = min(wo_cap, wo_sep);
    tau = 1.0 / bwi;
    tc = 1.0 / wo;
    Kp = tau / (Gdc * tc);
    Ki = 1.0 / (Gdc * tc);
    Kaw = Ki / max(Kp, 1e-9);   % back-calc ~ 1/tau_I = bwi

    % FO characteristic: tau s^2 + (1+Gdc*Kp) s + Gdc*Ki = 0
    a = tau; b = 1 + Gdc * Kp; c = Gdc * Ki;
    disc = b^2 - 4 * a * c;
    r1 = (-b + sqrt(max(disc, 0))) / (2 * a);
    r2 = (-b - sqrt(max(disc, 0))) / (2 * a);
    zeta = b / (2 * sqrt(a * c));

    des = struct();
    des.Gdc = Gdc;
    des.bwi = bwi;
    des.bwi_ref = 1.39;
    des.wo = wo;
    des.wo_cap = wo_cap;
    des.tau = tau;
    des.tc = tc;
    des.Kp = Kp;
    des.Ki = Ki;
    des.Kaw = Kaw;
    des.zeta_fo = zeta;
    des.poles_fo = [r1; r2];
    des.sep = bwi / wo;
    des.method = ['SIMC FO of validated T_gamma(closed-inner): ' ...
        'Kp=tau/(Gdc*tc), Ki=1/(Gdc*tc), wo=min(0.30,bwi/3), overdamped zeta>1'];
    des.provenance = sprintf(['level Gdc=%.6g bw_th=%.6g | climb Gdc=%.6g bw_th=%.6g | ' ...
        'mean Gdc=%.6g bwi=%.6g | FO poles=%.5g, %.5g zeta=%.4f | sep=%.3f'], ...
        A.level.Gdc_gamma_from_theta, A.level.bw_theta_cl, ...
        A.climb.Gdc_gamma_from_theta, A.climb.bw_theta_cl, ...
        Gdc, bwi, r1, r2, zeta, bwi / wo);
end

%% ===================== OP pack / sim =====================
function op = pack_op(name, S)
    op = struct();
    op.name = name;
    op.x0 = S.x0(:);
    op.u0 = S.u0(:);
    th = op.x0(5); u = op.x0(7); w = op.x0(9);
    op.theta_phys = -th;
    op.alpha = atan2(w, u);
    op.gamma = op.theta_phys + op.alpha;
    op.de_trim = op.u0(2);
    op.thrust_trim = op.u0(3);
    op.u_trim = u;
end

function L = sim_case(op, amp, use_pi, P)
    clear functions
    clear controller_law
    init_parameters();

    global thrust_trim elevator_sign lambda_muw_ff K_gamma enable_alpha_hat
    global trim_speed_table trim_elevator_table dt_controller delta_e_max
    global last_int_angle last_int_rate last_rate_filt

    elevator_sign = 1;
    lambda_muw_ff = 0;
    K_gamma = 0;
    enable_alpha_hat = false;
    thrust_trim = op.thrust_trim;
    dt_controller = P.dt;
    delta_e_max = P.de_max;
    trim_speed_table = [op.u_trim - 0.05, op.u_trim, op.u_trim + 0.05];
    trim_elevator_table = [op.de_trim, op.de_trim, op.de_trim];

    dt = P.dt;
    t_end = P.T_settle + P.T_hold;
    t = (0:dt:t_end).';
    n = numel(t);
    t_step = P.T_settle;

    x = op.x0;
    gamma_star = op.gamma;
    th_star = op.theta_phys;

    % Bumpless trim init of outer PI
    int_e = 0;
    dth_prev = 0;

    yaw_ref = 0;
    u_ref = op.u_trim;
    r_ff = 0;
    pitch_ref_dot = 0;

    L = init_log(n, use_pi, amp, op);
    L.t = t;
    L.t_step = t_step;

    for k = 1:n
        tk = t(k);
        if tk < t_step
            gamma_ref = gamma_star;
        else
            gamma_ref = gamma_star + amp;
        end

        phi = x(4); theta = x(5); psi = x(6);
        uu = x(7); ww = x(9);
        pp = x(10); qq = x(11); rr = x(12);

        theta_phys = -theta;
        gamma = theta_phys + atan2(ww, uu);
        e_gamma = wrapToPi(gamma_ref - gamma);

        % Kinematic path (production baseline pitch command about trim)
        theta_path = th_star + (gamma_ref - gamma_star);

        if use_pi
            % Outer PI: bounded theta-command correction about path/trim
            u_i = P.Ki * int_e;
            u_i = max(min(u_i, P.I_max), -P.I_max);
            u_p = P.Kp * e_gamma;
            u_unsat = u_p + u_i;
            dth = max(min(u_unsat, P.corr_max), -P.corr_max);

            % Conditional integration + back-calculation
            aw = dth - u_unsat;
            integrate = true;
            if abs(aw) > 1e-12 && sign(e_gamma) == sign(aw)
                integrate = false;  % freeze when sat against error
            end
            if integrate
                int_e = int_e + e_gamma * dt;
            end
            int_e = int_e + P.Kaw * aw * dt;
            int_max = P.I_max / max(P.Ki, 1e-9);
            int_e = max(min(int_e, int_max), -int_max);

            pitch_ref = theta_path + dth;
            dth_prev = dth;
        else
            dth = 0;
            u_unsat = 0;
            u_i = 0;
            pitch_ref = theta_path;
        end

        [dr, de, thr, dbg] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            psi, theta, rr, qq, uu, r_ff, pitch_ref_dot, phi, ww, pp);

        ia = safe_num(last_int_angle);
        ir = safe_num(last_int_rate);
        rf = safe_num(last_rate_filt);
        n_int = norm([ia; ir; rf; int_e; dth]);

        L.gamma(k) = gamma;
        L.gamma_ref(k) = gamma_ref;
        L.e_gamma(k) = e_gamma;
        L.theta_phys(k) = theta_phys;
        L.theta_path(k) = theta_path;
        L.pitch_ref(k) = pitch_ref;
        L.dth(k) = dth;
        L.u_i(k) = u_i;
        L.u_unsat(k) = u_unsat;
        L.int_e(k) = int_e;
        L.w(k) = ww;
        L.q(k) = qq;
        L.u(k) = uu;
        L.de_applied(k) = de;
        L.n_int(k) = n_int;
        L.int_angle(k) = ia;
        L.int_rate(k) = ir;
        L.mag_sat(k) = dbg.mag_sat;
        L.x_dev(k) = norm([theta_phys - th_star; uu - op.u_trim; ww - op.x0(9); qq]);

        if k < n
            controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);
            x = rk4_step(@(tt, g) underwater777_vehicle_dynamics(tt, g, controls), tk, x, dt);
            if any(~isfinite(x))
                L.diverged = true;
                L.finite_n = k;
                L = trim_log(L, k);
                return;
            end
        end
    end
    L.diverged = false;
    L.finite_n = n;
    L.x_final = x;
    L.dth_final = dth_prev;
end

function L = init_log(n, use_pi, amp, op)
    z = zeros(n, 1);
    L = struct();
    L.use_pi = use_pi;
    L.amp = amp;
    L.op = op.name;
    L.gamma_star = op.gamma;
    L.gamma = z; L.gamma_ref = z; L.e_gamma = z;
    L.theta_phys = z; L.theta_path = z; L.pitch_ref = z;
    L.dth = z; L.u_i = z; L.u_unsat = z; L.int_e = z;
    L.w = z; L.q = z; L.u = z;
    L.de_applied = z; L.n_int = z; L.int_angle = z; L.int_rate = z;
    L.mag_sat = z; L.x_dev = z;
end

function L = trim_log(L, k)
    f = fieldnames(L);
    for i = 1:numel(f)
        v = L.(f{i});
        if isnumeric(v) && isvector(v) && numel(v) >= k
            L.(f{i}) = v(1:k);
        end
    end
    L.t = L.t(1:k);
end

%% ===================== metrics / gates =====================
function R = score_pair(op_name, amp, B, S, P)
    mb = metrics_one(B, P);
    ms = metrics_one(S, P);
    R = struct();
    R.op = op_name;
    R.amp_deg = rad2deg(amp);
    R.base = mb;
    R.scaf = ms;
    R.B = B;
    R.S = S;

    R.mae_base_deg = mb.mae_deg;
    R.mae_scaf_deg = ms.mae_deg;
    R.p95_base_deg = mb.p95_deg;
    R.p95_scaf_deg = ms.p95_deg;
    R.settle_base_s = mb.settle_s;
    R.settle_scaf_s = ms.settle_s;
    R.os_base_deg = mb.os_deg;
    R.os_scaf_deg = ms.os_deg;

    R.mae_improve = improve_frac(mb.mae_deg, ms.mae_deg);
    R.settle_improve = improve_frac(mb.settle_s, ms.settle_s);
    R.mae_worsen = (ms.mae_deg - mb.mae_deg) / max(abs(mb.mae_deg), 1e-9);
    R.p95_worsen = (ms.p95_deg - mb.p95_deg) / max(abs(mb.p95_deg), 1e-9);
    R.no_worsen = (R.mae_worsen <= P.worsen_frac + 1e-12) && ...
        (R.p95_worsen <= P.worsen_frac + 1e-12);

    R.stable = (~B.diverged) && (~S.diverged) && mb.bounded && ms.bounded;
    R.sign_ok = mb.sign_ok && ms.sign_ok;
    R.sat_ok = (mb.sat_count == 0) && (ms.sat_count == 0);
    R.rate_ok = mb.rate_ok && ms.rate_ok;
    R.int_ok = mb.int_ok && ms.int_ok;
    R.chatter_ok = ms.chatter_ok;          % scaffold must not chatter
    R.os_ok = ms.os_ok && (ms.os_deg <= mb.os_deg + 0.05 * rad2deg(abs(amp)) + 1e-9);

    R.pass_case = R.stable && R.sign_ok && R.no_worsen && R.sat_ok && R.rate_ok ...
        && R.int_ok && R.chatter_ok && R.os_ok;
    R.fail_reasons = {};
    if ~R.stable; R.fail_reasons{end+1} = 'unstable/unbounded'; end
    if ~R.sign_ok; R.fail_reasons{end+1} = 'wrong gamma sign'; end
    if ~R.no_worsen; R.fail_reasons{end+1} = 'MAE/p95 worsen>2%'; end
    if ~R.sat_ok; R.fail_reasons{end+1} = 'sat>0'; end
    if ~R.rate_ok; R.fail_reasons{end+1} = 'rate limit exceeded'; end
    if ~R.int_ok; R.fail_reasons{end+1} = 'internal-state diverge'; end
    if ~R.chatter_ok; R.fail_reasons{end+1} = 'chatter'; end
    if ~R.os_ok; R.fail_reasons{end+1} = 'overshoot'; end
end

function m = metrics_one(L, P)
    t = L.t(:);
    mask = t >= L.t_step;
    eg = L.e_gamma(:);
    g = L.gamma(:);
    gref = L.gamma_ref(:);
    amp = L.amp;
    band = P.band_frac * abs(amp);

    mask_mae = mask & (t >= L.t_step + 1.0);
    if ~any(mask_mae); mask_mae = mask; end
    eg_m = abs(eg(mask_mae));
    m.mae_deg = rad2deg(mean(eg_m));
    m.p95_deg = rad2deg(prctile_local(eg_m, 95));

    idx = find(mask);
    settle = Inf;
    for ii = 1:numel(idx)
        k = idx(ii);
        if all(abs(eg(k:end)) <= band)
            settle = t(k) - L.t_step;
            break;
        end
    end
    m.settle_s = settle;

    g_final = mean(gref(mask_mae));
    if amp >= 0
        m.os_deg = rad2deg(max(0, max(g(mask)) - g_final));
    else
        m.os_deg = rad2deg(max(0, g_final - min(g(mask))));
    end
    m.os_ok = m.os_deg <= P.os_max_frac * rad2deg(abs(amp)) + 1e-9;

    dg = mean(g(mask_mae)) - L.gamma_star;
    if abs(amp) < 1e-12
        m.sign_ok = true;
    else
        m.sign_ok = (sign(dg) == sign(amp)) && (abs(dg) > 0.1 * abs(amp));
    end

    de = L.de_applied(:);
    if numel(de) >= 2
        dde = diff(de) / P.dt;
        m.de_rate_max_deg = rad2deg(max(abs(dde)));
    else
        dde = 0;
        m.de_rate_max_deg = 0;
    end
    m.rate_ok = m.de_rate_max_deg <= rad2deg(P.de_rate_max) + 0.05;
    m.sat_count = sum(L.mag_sat(:) > 0);
    m.de_max_deg = rad2deg(max(abs(de)));

    % Chatter: post-step zero-crossings of elevator rate (after 2s)
    mask_ch = t(1:end-1) >= (L.t_step + 2.0);
    if any(mask_ch) && numel(dde) > 1
        s = sign(dde(mask_ch));
        s(s == 0) = 1;
        m.chatter_xc = sum(abs(diff(s)) > 0);
    else
        m.chatter_xc = 0;
    end
    m.chatter_ok = m.chatter_xc <= P.chatter_xc_max;

    m.max_x_dev = max(L.x_dev(:));
    m.max_n_int = max(L.n_int(:));
    n_end = mean(L.n_int(max(1, end-40):end));
    n_mid = mean(L.n_int(max(1, round(0.4*numel(L.n_int))):max(1, round(0.6*numel(L.n_int)))));
    m.int_ok = isfinite(m.max_n_int) && (m.max_n_int < 50) ...
        && (n_end < max(5 * max(n_mid, 1e-3), 5));
    m.bounded = (~L.diverged) && all(isfinite(g)) && all(isfinite(de)) ...
        && (m.max_x_dev < 5) && (max(abs(L.theta_phys)) < deg2rad(60));
    if isfield(L, 'dth')
        m.dth_max_deg = rad2deg(max(abs(L.dth(:))));
        m.ui_max_deg = rad2deg(max(abs(L.u_i(:))));
    else
        m.dth_max_deg = 0;
        m.ui_max_deg = 0;
    end
end

function f = improve_frac(base, scaf)
    if ~isfinite(base) && ~isfinite(scaf)
        f = 0;
    elseif ~isfinite(base) && isfinite(scaf)
        f = 1;
    elseif isfinite(base) && ~isfinite(scaf)
        f = -1;
    else
        f = (base - scaf) / max(abs(base), 1e-9);
    end
end

function G = rollup_gates(rows, P)
    G = struct();
    G.n = numel(rows);
    G.pass_cases = cellfun(@(r) r.pass_case, rows);
    G.all_stable = all(cellfun(@(r) r.stable, rows));
    G.all_sign = all(cellfun(@(r) r.sign_ok, rows));
    G.all_sat = all(cellfun(@(r) r.sat_ok, rows));
    G.all_rate = all(cellfun(@(r) r.rate_ok, rows));
    G.all_int = all(cellfun(@(r) r.int_ok, rows));
    G.all_no_worsen = all(cellfun(@(r) r.no_worsen, rows));
    G.all_chatter = all(cellfun(@(r) r.chatter_ok, rows));
    G.all_os = all(cellfun(@(r) r.os_ok, rows));

    mae_b = cellfun(@(r) r.mae_base_deg, rows);
    mae_s = cellfun(@(r) r.mae_scaf_deg, rows);
    set_b = cellfun(@(r) r.settle_base_s, rows);
    set_s = cellfun(@(r) r.settle_scaf_s, rows);
    G.mae_agg_base = mean(mae_b);
    G.mae_agg_scaf = mean(mae_s);
    G.mae_agg_improve = improve_frac(G.mae_agg_base, G.mae_agg_scaf);
    % Persistent settle aggregate: mean of finite; Inf counts as T_hold penalty
    G.settle_agg_base = mean(min(set_b, P.T_hold));
    G.settle_agg_scaf = mean(min(set_s, P.T_hold));
    G.settle_agg_improve = improve_frac(G.settle_agg_base, G.settle_agg_scaf);
    G.agg_improve = (G.mae_agg_improve >= P.improve_frac) || ...
        (G.settle_agg_improve >= P.improve_frac);

    ops = unique(cellfun(@(r) r.op, rows, 'Uniform', false));
    G.op_pass = true(numel(ops), 1);
    G.op_names = ops;
    for i = 1:numel(ops)
        ix = find(cellfun(@(r) strcmp(r.op, ops{i}), rows));
        G.op_pass(i) = all(cellfun(@(j) rows{j}.pass_case, num2cell(ix)));
    end
    G.both_ops = all(G.op_pass);
    G.pass = G.both_ops && G.all_stable && G.all_sign && G.all_sat ...
        && G.all_rate && G.all_int && G.all_no_worsen && G.all_chatter ...
        && G.all_os && G.agg_improve;

    fails = {};
    if ~G.agg_improve
        fails{end+1} = sprintf('agg MAEΔ=%.1f%% settleΔ=%.1f%% <5%%', ...
            100*G.mae_agg_improve, 100*G.settle_agg_improve);
    end
    for i = 1:numel(rows)
        if ~rows{i}.pass_case
            fails{end+1} = sprintf('%s%+.0fdeg[%s]', rows{i}.op, rows{i}.amp_deg, ...
                strjoin(rows{i}.fail_reasons, ',')); %#ok<AGROW>
        end
    end
    if isempty(fails)
        G.fail_detail = '';
    else
        G.fail_detail = strjoin(fails, '; ');
    end
end

%% ===================== io =====================
function write_png(png_path, rows, ops, P, task_id, verdict)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 900]);
    picks = {};
    for i = 1:numel(ops)
        name = ops{i}.name;
        for k = 1:numel(rows)
            if strcmp(rows{k}.op, name) && rows{k}.amp_deg > 0
                picks{end+1} = rows{k}; %#ok<AGROW>
                break;
            end
        end
    end
    if numel(picks) < 2
        picks = rows(1:min(2, numel(rows)));
    end

    for col = 1:numel(picks)
        R = picks{col};
        B = R.B; S = R.S;
        subplot(3, 2, col); hold on; grid on;
        plot(B.t, rad2deg(B.gamma_ref), 'k--', 'LineWidth', 1.2);
        plot(B.t, rad2deg(B.gamma), 'b-', 'LineWidth', 1.1);
        plot(S.t, rad2deg(S.gamma), 'r-', 'LineWidth', 1.1);
        xline(B.t_step, 'k:', 'step');
        ylabel('\gamma [deg]'); xlabel('t [s]');
        title(sprintf('%s +1deg \\gamma  (%s)', R.op, verdict));
        if col == 1; legend('ref', 'cascade', 'outer-PI', 'Location', 'best'); end

        subplot(3, 2, 2 + col); hold on; grid on;
        plot(B.t, rad2deg(B.theta_phys), 'b-', 'LineWidth', 1.0);
        plot(S.t, rad2deg(S.theta_phys), 'r-', 'LineWidth', 1.0);
        plot(S.t, rad2deg(S.dth), 'k-', 'LineWidth', 1.0);
        plot(S.t, rad2deg(S.u_i), 'm--', 'LineWidth', 0.9);
        yline(rad2deg(P.corr_max), 'k:'); yline(-rad2deg(P.corr_max), 'k:');
        ylabel('\theta_p / d\theta / I [deg]'); xlabel('t [s]');
        title(sprintf('%s attitude / PI', R.op));
        if col == 1; legend('\theta_p base', '\theta_p PI', 'd\theta', 'I', 'Location', 'best'); end

        subplot(3, 2, 4 + col); hold on; grid on;
        plot(B.t, rad2deg(B.de_applied), 'b-', 'LineWidth', 1.0);
        plot(S.t, rad2deg(S.de_applied), 'r-', 'LineWidth', 1.0);
        plot(S.t, S.n_int, 'm--', 'LineWidth', 0.9);
        ylabel('de [deg], ||\xi||'); xlabel('t [s]');
        title(sprintf('%s elevator / internal', R.op));
        if col == 1; legend('de base', 'de PI', '||\xi||', 'Location', 'best'); end
    end
    sgtitle(sprintf('%s — cascade vs outer gamma-PI', task_id), 'FontWeight', 'bold');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, task_id, verdict, decision, reason, next_step, gate, rows, P, ...
        audit_mat, ctrl_path, plant_path, md_p, mat_p, png_p)
    des = P.design;
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Outer gamma-PI scaffold on theta/q cascade\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '**Decision: `%s`**\n\n', decision);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', audit_mat, ctrl_path, plant_path);
    fprintf(fid, '- Driver: `run_outer_gamma_pi_scaffold.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Prior: GAMMA_INDI_SCAFFOLD FAIL (NMP/RHP-zero sign conflict)\n');
    fprintf(fid, '- No gain sweep; FIXED SIMC Kp/Ki from closed-inner T_gamma\n\n');

    fprintf(fid, '## Equations / units (FACT)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'gamma = -theta + atan2(w,u)                 [rad]  (phi=0,v=0)\n');
    fprintf(fid, 'e_gamma = wrap(gamma_ref - gamma)           [rad]\n');
    fprintf(fid, 'theta_path = theta* + (gamma_ref - gamma*)  [rad]\n');
    fprintf(fid, 'u_i = sat(Ki * int_e, +/-%.0f deg)          [rad]\n', rad2deg(P.I_max));
    fprintf(fid, 'dtheta = sat(Kp*e_gamma + u_i, +/-%.0f deg) [rad]\n', rad2deg(P.corr_max));
    fprintf(fid, 'pitch_ref = theta_path + dtheta             [rad]  (PI on; else path only)\n');
    fprintf(fid, 'int_e += e_gamma*dt  (freeze if sat against e); int_e += Kaw*(dtheta-u_unsat)*dt\n');
    fprintf(fid, '|int_e| <= I_max/Ki; bumpless: int_e(0)=0\n');
    fprintf(fid, 'Inner: production controller_law theta/q cascade; de mag +/-%.0fdeg rate %.0fdeg/s\n', ...
        rad2deg(P.de_max), rad2deg(P.de_rate_max));
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Gains / poles / provenance\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'Gdc = mean(T_gamma DC) = %.8g  [rad/rad]\n', des.Gdc);
    fprintf(fid, 'bwi = mean(bw_theta_cl) = %.8g  [rad/s]  (ref 1.39)\n', des.bwi);
    fprintf(fid, 'tau = 1/bwi = %.8g  [s]\n', des.tau);
    fprintf(fid, 'wo  = min(0.30, bwi/3) = %.8g  [rad/s]\n', des.wo);
    fprintf(fid, 'tc  = 1/wo = %.8g  [s]\n', des.tc);
    fprintf(fid, 'Kp  = tau/(Gdc*tc) = %.8g  [-]\n', des.Kp);
    fprintf(fid, 'Ki  = 1/(Gdc*tc)   = %.8g  [1/s]\n', des.Ki);
    fprintf(fid, 'Kaw = Ki/Kp       = %.8g  [1/s]\n', des.Kaw);
    fprintf(fid, 'FO poles = %.6g, %.6g ; zeta=%.4f (overdamped); sep=bwi/wo=%.3f\n', ...
        des.poles_fo(1), des.poles_fo(2), des.zeta_fo, des.sep);
    fprintf(fid, '%s\n', des.provenance);
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Test\n\n');
    fprintf(fid, '- Exact level / XZ-climb trims at U=1.5 from OUTER_GAMMA_INDI_AUDIT (LOCAL_SS)\n');
    fprintf(fid, '- Noise-free +/-%.0f deg gamma steps; settle %.1fs + hold %.1fs; dt=%.3fs\n', ...
        rad2deg(P.amp), P.T_settle, P.T_hold, P.dt);
    fprintf(fid, '- Baseline = production cascade path-only; scaffold = path + outer PI\n');
    fprintf(fid, '- PASS: stable/sign OK; agg MAE or settle >=%.0f%%; no case MAE/p95 worsen >%.0f%%; sat=0; rate; no chatter/OS\n\n', ...
        100*P.improve_frac, 100*P.worsen_frac);

    fprintf(fid, '## Results table\n\n');
    fprintf(fid, '| OP | step | MAE_b° | MAE_s° | MAEΔ%% | p95_b° | p95_s° | set_b | set_s | OS_b° | OS_s° | sat | rate | sign | chat | PASS |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|:---:|:---:|:---:|\n');
    for i = 1:numel(rows)
        r = rows{i};
        fprintf(fid, '| %s | %+.0f | %.4f | %.4f | %+.1f | %.4f | %.4f | %.2f | %.2f | %.3f | %.3f | %d/%d | %s | %s | %s | %s |\n', ...
            r.op, r.amp_deg, r.mae_base_deg, r.mae_scaf_deg, 100*r.mae_improve, ...
            r.p95_base_deg, r.p95_scaf_deg, r.settle_base_s, r.settle_scaf_s, ...
            r.os_base_deg, r.os_scaf_deg, r.base.sat_count, r.scaf.sat_count, ...
            yn(r.rate_ok), yn(r.sign_ok), yn(r.chatter_ok), yn(r.pass_case));
    end
    fprintf(fid, '\n');
    fprintf(fid, 'Aggregate: MAE_b=%.4f MAE_s=%.4f (Δ%+.1f%%) | settle_b=%.2f settle_s=%.2f (Δ%+.1f%%)\n\n', ...
        gate.mae_agg_base, gate.mae_agg_scaf, 100*gate.mae_agg_improve, ...
        gate.settle_agg_base, gate.settle_agg_scaf, 100*gate.settle_agg_improve);

    fprintf(fid, '## Gates\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|---|:---:|---|\n');
    fprintf(fid, '| Stable/bounded | %s | all cases |\n', yn(gate.all_stable));
    fprintf(fid, '| Correct gamma sign | %s | both steps/OPs |\n', yn(gate.all_sign));
    fprintf(fid, '| Agg MAE or settle >=5%% | %s | MAEΔ=%+.1f%% settleΔ=%+.1f%% |\n', ...
        yn(gate.agg_improve), 100*gate.mae_agg_improve, 100*gate.settle_agg_improve);
    fprintf(fid, '| No case MAE/p95 worsen >2%% | %s | per-case guard |\n', yn(gate.all_no_worsen));
    fprintf(fid, '| Internal states bounded | %s | ||xi|| |\n', yn(gate.all_int));
    fprintf(fid, '| sat=0 | %s | mag sat |\n', yn(gate.all_sat));
    fprintf(fid, '| rates within limits | %s | <=40 deg/s |\n', yn(gate.all_rate));
    fprintf(fid, '| No chatter/overshoot | %s | xc/OS gates |\n', yn(gate.all_chatter && gate.all_os));
    fprintf(fid, '| Both OPs PASS | %s | %s |\n\n', yn(gate.both_ops), ...
        tern(isempty(gate.fail_detail), '—', gate.fail_detail));

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Choice: **`%s`**\n', decision);
    fprintf(fid, '- Reason: %s\n', reason);
    fprintf(fid, '- Next: `%s`\n', next_step);
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Decision: **%s**\n', decision);
    fprintf(fid, '- Evidence: %s\n', evidence_str(rows, gate, P));
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Next: `%s`\n', next_step);
    fclose(fid);
end

function append_ss_audit(out_dir, task_id, verdict, decision, reason, next_step, gate, rows, P, ...
        md_p, mat_p, png_p)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    des = P.design;
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `OUTER_GAMMA_INDI_AUDIT.mat`, `controller_law.m`, `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Driver: `run_outer_gamma_pi_scaffold.m` (one invocation; no production edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Prior FAIL: direct gamma-INDI (NMP/RHP-zero sign conflict)\n\n');
    fprintf(fid, '### Equations\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'gamma=-theta+atan2(w,u); e=wrap(gamma_ref-gamma)\n');
    fprintf(fid, 'theta_path=theta*+(gamma_ref-gamma*)\n');
    fprintf(fid, 'dtheta=sat(Kp*e+sat(Ki*int,+/-2deg),+/-4deg)\n');
    fprintf(fid, 'pitch_ref=theta_path+dtheta; conditional-I + Kaw back-calc; bumpless int(0)=0\n');
    fprintf(fid, 'Kp=%.6g [-]; Ki=%.6g [1/s]; wo=%.3g; FO poles %.4g,%.4g zeta=%.3f\n', ...
        des.Kp, des.Ki, des.wo, des.poles_fo(1), des.poles_fo(2), des.zeta_fo);
    fprintf(fid, '```\n\n');
    fprintf(fid, '### Key numbers\n\n');
    fprintf(fid, '| OP/step | MAE_b° | MAE_s° | p95_b° | p95_s° | set_b | set_s | PASS |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|:---:|\n');
    for i = 1:numel(rows)
        r = rows{i};
        fprintf(fid, '| %s %+.0f | %.4f | %.4f | %.4f | %.4f | %.2f | %.2f | %s |\n', ...
            r.op, r.amp_deg, r.mae_base_deg, r.mae_scaf_deg, ...
            r.p95_base_deg, r.p95_scaf_deg, r.settle_base_s, r.settle_scaf_s, yn(r.pass_case));
    end
    fprintf(fid, '\nAgg MAEΔ=%+.1f%% settleΔ=%+.1f%%\n\n', ...
        100*gate.mae_agg_improve, 100*gate.settle_agg_improve);
    fprintf(fid, '### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s** | Decision: **`%s`**\n', verdict, decision);
    fprintf(fid, '- Reason: %s\n', reason);
    fprintf(fid, '- Next: `%s`\n', next_step);
    fprintf(fid, '- Production: untouched\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- %s\n', next_step);
    fclose(fid);
end

function print_feedback(verdict, decision, reason, next_step, gate, rows, P, md_p, mat_p, png_p)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('decision: %s\n', decision);
    fprintf('equations: dtheta=sat(Kp*e+I,+/-4deg); I=sat(Ki*int,+/-2deg); Kp=%.5g Ki=%.5g 1/s\n', ...
        P.Kp, P.Ki);
    fprintf('evidence: %s\n', evidence_str(rows, gate, P));
    fprintf('reason: %s\n', reason);
    fprintf('next: %s\n', next_step);
    fprintf('files: %s | %s | %s\n', md_p, mat_p, png_p);
end

function s = evidence_str(rows, gate, P)
    parts = cell(numel(rows), 1);
    for i = 1:numel(rows)
        r = rows{i};
        parts{i} = sprintf('%s%+.0f:MAEb=%.3f/s=%.3f(Δ%.0f%%),p95b=%.3f/s=%.3f,setb=%.2f/s=%.2f', ...
            r.op, r.amp_deg, r.mae_base_deg, r.mae_scaf_deg, 100*r.mae_improve, ...
            r.p95_base_deg, r.p95_scaf_deg, r.settle_base_s, r.settle_scaf_s);
    end
    s = [strjoin(parts, ' | ') sprintf([' | aggMAEΔ=%.1f%% aggSetΔ=%.1f%% | ' ...
        'gates stable=%d sign=%d agg=%d noworse=%d sat=%d rate=%d int=%d chat=%d os=%d | Kp=%.4g Ki=%.4g'], ...
        100*gate.mae_agg_improve, 100*gate.settle_agg_improve, ...
        gate.all_stable, gate.all_sign, gate.agg_improve, gate.all_no_worsen, ...
        gate.all_sat, gate.all_rate, gate.all_int, gate.all_chatter, gate.all_os, ...
        P.Kp, P.Ki)];
end

function x1 = rk4_step(f, t, x, dt)
    k1 = f(t, x);
    k2 = f(t + 0.5*dt, x + 0.5*dt*k1);
    k3 = f(t + 0.5*dt, x + 0.5*dt*k2);
    k4 = f(t + dt, x + dt*k3);
    x1 = x + (dt/6) * (k1 + 2*k2 + 2*k3 + k4);
end

function y = safe_num(v)
    if isempty(v) || ~isfinite(v); y = 0; else; y = v; end
end

function y = prctile_local(v, p)
    v = sort(v(:));
    if isempty(v); y = NaN; return; end
    n = numel(v);
    r = 1 + (p/100) * (n - 1);
    lo = floor(r); hi = ceil(r);
    if lo == hi
        y = v(lo);
    else
        y = v(lo) + (r - lo) * (v(hi) - v(lo));
    end
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
