function run_gamma_indi_scaffold()
% GAMMA_INDI_SCAFFOLD_001 — isolated incremental gamma-INDI scaffold feasibility.
% Read-only: OUTER_GAMMA_INDI_AUDIT.mat, controller_law.m, underwater777_vehicle_dynamics.m
% Production theta/q cascade untouched; INDI is an additive bounded elevator correction.
% One MATLAB invocation. No gain sweep. Noise-free +/-1deg gamma steps at level/climb trims.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'GAMMA_INDI_SCAFFOLD';
    task_id = 'GAMMA_INDI_SCAFFOLD_001';

    audit_mat = fullfile(out_dir, 'OUTER_GAMMA_INDI_AUDIT.mat');
    ctrl_path = fullfile(project_dir, 'controller_law.m');
    plant_path = fullfile(project_dir, 'underwater777_vehicle_dynamics.m');
    A = load(audit_mat);

    % Fixed scaffold (no sweep) — from OUTER_GAMMA_INDI_AUDIT architecture decision
    P = struct();
    P.Gdelta = -0.2208;                 % [(rad/s)/rad] fixed mid OP
    P.Kw = 0.46;                        % [1/s] outer target bw
    P.nu_clip = deg2rad(6);             % [rad/s]
    P.corr_max = deg2rad(2);            % [rad] correction vs baseline
    P.de_max = deg2rad(15);             % production mag limit
    P.de_rate_max = deg2rad(40);        % [rad/s] production rate limit
    P.tau_f = 0.15;                     % [s] synchronized FO filters
    P.dt = 0.025;                       % production dt_controller
    P.T_settle = 5.0;                   % [s] trim hold before step
    P.T_hold = 18.0;                    % [s] post-step window
    P.amp = deg2rad(1);                 % [rad] +/-1deg gamma steps
    P.improve_frac = 0.05;              % >=5% MAE or settle improvement
    P.band_frac = 0.05;                 % settle band = 5% of |step|

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources (read-only): OUTER_GAMMA_INDI_AUDIT.mat | controller_law.m | underwater777_vehicle_dynamics.m\n');
    fprintf('Scaffold: nu=gdot_ref+%.2f*e_g clip+/-%.0fdeg/s; Gdelta=%.4f; tau=%.2fs; corr+/-%.0fdeg\n', ...
        P.Kw, rad2deg(P.nu_clip), P.Gdelta, P.tau_f, rad2deg(P.corr_max));
    fprintf('Production cascade untouched (stabilizing baseline).\n');

    ops = { ...
        pack_op('level', A.level), ...
        pack_op('climb', A.climb)};
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
            fprintf('  %s step%+.0fdeg: base MAE=%.4f settle=%.2fs | scaf MAE=%.4f settle=%.2fs | %s\n', ...
                op.name, rad2deg(amp), R.mae_base_deg, R.settle_base_s, ...
                R.mae_scaf_deg, R.settle_scaf_s, tern(R.pass_case, 'PASS', 'FAIL'));
        end
    end

    gate = rollup_gates(rows, P);
    if gate.pass
        verdict = 'PASS';
        decision = 'ACCEPT_INDI_SCAFFOLD';
        next_step = 'tune_gamma_INDI_filters_or_schedule_Gdelta';
        reason = ['Both OPs stable/bounded, correct sign, gamma MAE or settle improved >=5%, ' ...
            'internal states bounded, sat=0 and rates within limits.'];
    else
        verdict = 'FAIL';
        decision = 'REJECT_DIRECT_INDI_SCAFFOLD';
        next_step = 'implement_outer_gamma_PI_or_ADRC';
        reason = ['Direct incremental gamma-INDI scaffold rejected: ' gate.fail_detail ...
            ' Prefer outer gamma PI/ADRC on theta/q cascade.'];
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
    Out.gate = gate;
    Out.rows = rows;
    Out.sources = {audit_mat; ctrl_path; plant_path};
    Out.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Out.note = ['Isolated gamma-INDI scaffold vs production cascade; ' ...
        'small-signal +/-1deg at level/climb; production untouched'];
    save(mat_path, '-struct', 'Out');

    fprintf('\nVERDICT: %s\n', verdict);
    fprintf('DECISION: %s\n', decision);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, decision, reason, next_step, gate, rows, md_path, mat_path, png_path);
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
    if isfield(S, 'G_delta'); op.G_delta_op = S.G_delta; else; op.G_delta_op = NaN; end
end

function L = sim_case(op, amp, use_indi, P)
    % Isolated closed-loop: production cascade +/- optional INDI correction.
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
    % Point trim table through OP so cascade starts near de*
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

    % Scaffold filter / rate-limit state
    de_f = op.de_trim;
    gdot_f = 0;
    gamma_prev = gamma_star;
    de_applied = op.de_trim;
    a_f = exp(-dt / P.tau_f);

    % Warm-start cascade persistents by calling once at trim (prev=0 -> rate climb)
    % Long settle absorbs rate-limit catch-up from 0 -> de*.

    yaw_ref = 0;
    u_ref = op.u_trim;
    r_ff = 0;
    pitch_ref_dot = 0;

    L = init_log(n, use_indi, amp, op);
    L.t = t;
    L.t_step = t_step;

    for k = 1:n
        tk = t(k);
        if tk < t_step
            gamma_ref = gamma_star;
            gamma_ref_dot = 0;
        else
            gamma_ref = gamma_star + amp;
            gamma_ref_dot = 0;  % pure step (noise-free)
        end
        % Attitude command that achieves gamma_ref if alpha frozen at trim
        pitch_ref = th_star + (gamma_ref - gamma_star);

        phi = x(4); theta = x(5); psi = x(6);
        uu = x(7); vv = x(8); ww = x(9); %#ok<NASGU>
        pp = x(10); qq = x(11); rr = x(12);

        theta_phys = -theta;
        gamma = theta_phys + atan2(ww, uu);
        e_gamma = wrapToPi(gamma_ref - gamma);

        % Differentiated gamma + synchronized FO filter
        if k == 1
            gdot_raw = 0;
        else
            gdot_raw = (gamma - gamma_prev) / dt;
        end
        gdot_f = a_f * gdot_f + (1 - a_f) * gdot_raw;
        gamma_prev = gamma;

        % Production cascade (stabilizing baseline)
        [dr, de_base, thr, dbg] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            psi, theta, rr, qq, uu, r_ff, pitch_ref_dot, phi, ww, pp);

        % INDI virtual control and elevator reconstruction
        nu = gamma_ref_dot + P.Kw * e_gamma;
        nu = max(min(nu, P.nu_clip), -P.nu_clip);
        de_indi = de_f + (nu - gdot_f) / P.Gdelta;
        if use_indi
            de_corr = max(min(de_indi - de_base, P.corr_max), -P.corr_max);
            de_unsat = de_base + de_corr;
            de_cmd = max(min(de_unsat, P.de_max), -P.de_max);
            % Final rate limit (production 40 deg/s) on applied elevator
            max_step = P.de_rate_max * dt;
            de_applied = de_applied + max(min(de_cmd - de_applied, max_step), -max_step);
        else
            de_corr = 0;
            de_unsat = de_base;
            de_cmd = de_base;
            de_applied = de_base;  % true cascade baseline (already mag/rate limited)
        end
        de_f = a_f * de_f + (1 - a_f) * de_applied;

        controls = struct('delta_r', dr, 'delta_e', de_applied, 'thrust', thr);

        % Internal-state norm (controller + scaffold filters)
        ia = safe_num(last_int_angle);
        ir = safe_num(last_int_rate);
        rf = safe_num(last_rate_filt);
        n_int = norm([ia; ir; rf; de_f; gdot_f]);

        L.gamma(k) = gamma;
        L.gamma_ref(k) = gamma_ref;
        L.e_gamma(k) = e_gamma;
        L.theta_phys(k) = theta_phys;
        L.w(k) = ww;
        L.q(k) = qq;
        L.u(k) = uu;
        L.de_base(k) = de_base;
        L.de_corr(k) = de_corr;
        L.de_indi(k) = de_indi;
        L.de_applied(k) = de_applied;
        L.de_f(k) = de_f;
        L.nu(k) = nu;
        L.gdot_f(k) = gdot_f;
        L.gdot_raw(k) = gdot_raw;
        L.n_int(k) = n_int;
        L.int_angle(k) = ia;
        L.int_rate(k) = ir;
        L.mag_sat(k) = double(abs(de_unsat) > P.de_max + 1e-9);
        L.x_dev(k) = norm([theta_phys - th_star; uu - op.u_trim; ww - op.x0(9); qq]);
        L.dbg_mag_sat(k) = dbg.mag_sat;

        if k < n
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
end

function L = init_log(n, use_indi, amp, op)
    z = zeros(n, 1);
    L = struct();
    L.use_indi = use_indi;
    L.amp = amp;
    L.op = op.name;
    L.gamma_star = op.gamma;
    L.gamma = z; L.gamma_ref = z; L.e_gamma = z;
    L.theta_phys = z; L.w = z; L.q = z; L.u = z;
    L.de_base = z; L.de_corr = z; L.de_indi = z; L.de_applied = z; L.de_f = z;
    L.nu = z; L.gdot_f = z; L.gdot_raw = z;
    L.n_int = z; L.int_angle = z; L.int_rate = z;
    L.mag_sat = z; L.dbg_mag_sat = z; L.x_dev = z;
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
    R.settle_base_s = mb.settle_s;
    R.settle_scaf_s = ms.settle_s;
    R.os_base_deg = mb.os_deg;
    R.os_scaf_deg = ms.os_deg;

    R.mae_improve = improve_frac(mb.mae_deg, ms.mae_deg);
    R.settle_improve = improve_frac(mb.settle_s, ms.settle_s);
    R.track_improve = (R.mae_improve >= P.improve_frac) || (R.settle_improve >= P.improve_frac);

    R.stable = (~B.diverged) && (~S.diverged) && mb.bounded && ms.bounded;
    R.sign_ok = mb.sign_ok && ms.sign_ok;
    R.sat_ok = (mb.sat_count == 0) && (ms.sat_count == 0);
    R.rate_ok = mb.rate_ok && ms.rate_ok;
    R.int_ok = mb.int_ok && ms.int_ok;

    R.pass_case = R.stable && R.sign_ok && R.track_improve && R.sat_ok && R.rate_ok && R.int_ok;
    R.fail_reasons = {};
    if ~R.stable; R.fail_reasons{end+1} = 'unstable/unbounded'; end
    if ~R.sign_ok; R.fail_reasons{end+1} = 'wrong gamma sign'; end
    if ~R.track_improve; R.fail_reasons{end+1} = 'MAE/settle not improved >=5%'; end
    if ~R.sat_ok; R.fail_reasons{end+1} = 'sat>0'; end
    if ~R.rate_ok; R.fail_reasons{end+1} = 'rate limit exceeded'; end
    if ~R.int_ok; R.fail_reasons{end+1} = 'internal-state diverge'; end
end

function m = metrics_one(L, P)
    t = L.t(:);
    mask = t >= L.t_step;
    eg = L.e_gamma(:);
    g = L.gamma(:);
    gref = L.gamma_ref(:);
    amp = L.amp;
    band = P.band_frac * abs(amp);

    % Post-step MAE (exclude first 1s transient after step)
    mask_mae = mask & (t >= L.t_step + 1.0);
    if ~any(mask_mae); mask_mae = mask; end
    m.mae_deg = rad2deg(mean(abs(eg(mask_mae))));

    % Settling: first time |e| stays in band to end (relative to t_step)
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

    % Overshoot of gamma past final ref
    g_final = mean(gref(mask_mae));
    if amp >= 0
        m.os_deg = rad2deg(max(0, max(g(mask)) - g_final));
    else
        m.os_deg = rad2deg(max(0, g_final - min(g(mask))));
    end

    % Sign: mean (gamma - gamma*) after step should match amp sign
    dg = mean(g(mask_mae)) - L.gamma_star;
    if abs(amp) < 1e-12
        m.sign_ok = true;
    else
        m.sign_ok = (sign(dg) == sign(amp)) && (abs(dg) > 0.1 * abs(amp));
    end

    % Actuator
    de = L.de_applied(:);
    if numel(de) >= 2
        dde = diff(de) / P.dt;
        m.de_rate_max_deg = rad2deg(max(abs(dde)));
    else
        m.de_rate_max_deg = 0;
    end
    m.rate_ok = m.de_rate_max_deg <= rad2deg(P.de_rate_max) + 0.05;
    m.sat_count = sum(L.mag_sat(:) > 0);
    m.de_max_deg = rad2deg(max(abs(de)));
    m.corr_max_deg = rad2deg(max(abs(L.de_corr(:))));

    % Boundedness / internal states
    m.max_x_dev = max(L.x_dev(:));
    m.max_n_int = max(L.n_int(:));
    n_end = mean(L.n_int(max(1, end-40):end));
    n_mid = mean(L.n_int(max(1, round(0.4*numel(L.n_int))):max(1, round(0.6*numel(L.n_int)))));
    m.int_ok = isfinite(m.max_n_int) && (m.max_n_int < 50) ...
        && (n_end < max(5 * max(n_mid, 1e-3), 5));
    m.bounded = (~L.diverged) && all(isfinite(g)) && all(isfinite(de)) ...
        && (m.max_x_dev < 5) && (max(abs(L.theta_phys)) < deg2rad(60));
    m.mean_nu_deg = rad2deg(mean(L.nu(mask_mae)));
end

function f = improve_frac(base, scaf)
    % Positive => scaffold better (lower MAE / settle). Inf settle => no improve.
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
    G.all_improve = all(cellfun(@(r) r.track_improve, rows));

    % Per-OP: both step signs must pass
    ops = unique(cellfun(@(r) r.op, rows, 'Uniform', false));
    G.op_pass = true(numel(ops), 1);
    G.op_names = ops;
    for i = 1:numel(ops)
        ix = find(cellfun(@(r) strcmp(r.op, ops{i}), rows));
        G.op_pass(i) = all(cellfun(@(j) rows{j}.pass_case, num2cell(ix)));
    end
    G.both_ops = all(G.op_pass);
    G.pass = G.both_ops && G.all_stable && G.all_sign && G.all_sat ...
        && G.all_rate && G.all_int && G.all_improve;

    fails = {};
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
    G.improve_frac_req = P.improve_frac;
end

%% ===================== io =====================
function write_png(png_path, rows, ops, P, task_id, verdict)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 900]);
    % Prefer +1deg cases for level and climb
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
        if col == 1; legend('ref', 'cascade', 'INDI', 'Location', 'best'); end

        subplot(3, 2, 2 + col); hold on; grid on;
        plot(B.t, rad2deg(B.theta_phys), 'b-', 'LineWidth', 1.0);
        plot(S.t, rad2deg(S.theta_phys), 'r-', 'LineWidth', 1.0);
        plot(S.t, S.w, 'm-', 'LineWidth', 0.9);
        plot(S.t, rad2deg(S.q), 'g-', 'LineWidth', 0.9);
        ylabel('\theta_p [deg], w, q[deg/s]'); xlabel('t [s]');
        title(sprintf('%s states (INDI colored)', R.op));
        if col == 1; legend('\theta_p base', '\theta_p INDI', 'w', 'q', 'Location', 'best'); end

        subplot(3, 2, 4 + col); hold on; grid on;
        plot(B.t, rad2deg(B.de_applied), 'b-', 'LineWidth', 1.0);
        plot(S.t, rad2deg(S.de_applied), 'r-', 'LineWidth', 1.0);
        plot(S.t, rad2deg(S.de_corr), 'k-', 'LineWidth', 1.0);
        plot(S.t, S.n_int, 'm--', 'LineWidth', 0.9);
        yline(rad2deg(P.corr_max), 'k:'); yline(-rad2deg(P.corr_max), 'k:');
        ylabel('de/corr [deg], ||\xi||'); xlabel('t [s]');
        title(sprintf('%s elevator / internal', R.op));
        if col == 1; legend('de base', 'de INDI', 'corr', '||\xi||', 'Location', 'best'); end
    end
    sgtitle(sprintf('%s — cascade vs gamma-INDI scaffold', task_id), 'FontWeight', 'bold');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, task_id, verdict, decision, reason, next_step, gate, rows, P, ...
        audit_mat, ctrl_path, plant_path, md_p, mat_p, png_p)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Incremental gamma-INDI scaffold feasibility\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);
    fprintf(fid, '**Decision: `%s`**\n\n', decision);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `%s`, `%s`, `%s`\n', audit_mat, ctrl_path, plant_path);
    fprintf(fid, '- Driver: `run_gamma_indi_scaffold.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- No gain sweep; FIXED scaffold\n\n');

    fprintf(fid, '## Equations / units (FACT)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'gamma = -theta + atan2(w,u)           [rad]  (phi=0,v=0)\n');
    fprintf(fid, 'e_gamma = wrap(gamma_ref - gamma)     [rad]\n');
    fprintf(fid, 'nu = gamma_ref_dot + %.2f*e_gamma     [rad/s], clip +/-%.0f deg/s\n', ...
        P.Kw, rad2deg(P.nu_clip));
    fprintf(fid, 'de_f, gamma_dot_f: FO LPF tau=%.2fs on applied de and d(gamma)/dt\n', P.tau_f);
    fprintf(fid, 'de_indi = de_f + (nu - gamma_dot_f)/Gdelta\n');
    fprintf(fid, 'Gdelta = %.4f  [(rad/s)/rad] fixed\n', P.Gdelta);
    fprintf(fid, 'de_corr = sat(de_indi - de_base, +/-%.0f deg)\n', rad2deg(P.corr_max));
    fprintf(fid, 'de = rate_limit(sat(de_base+de_corr, +/-%.0f deg), %.0f deg/s)\n', ...
        rad2deg(P.de_max), rad2deg(P.de_rate_max));
    fprintf(fid, 'Baseline: production theta/q cascade (controller_law); pitch_ref = theta* + (gamma_ref-gamma*)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Test\n\n');
    fprintf(fid, '- Noise-free +/-%.0f deg gamma steps about exact level/climb trims\n', rad2deg(P.amp));
    fprintf(fid, '- Settle hold %.1fs then hold %.1fs; dt=%.3fs\n', P.T_settle, P.T_hold, P.dt);
    fprintf(fid, '- Compare baseline cascade vs scaffold INDI correction\n');
    fprintf(fid, '- PASS if both OPs: stable/bounded, correct sign, MAE or settle improves >=%.0f%%, internal bounded, sat=0, rates OK\n\n', ...
        100*P.improve_frac);

    fprintf(fid, '## Results table\n\n');
    fprintf(fid, '| OP | step | MAE_base° | MAE_scaf° | MAEΔ%% | settle_b[s] | settle_s[s] | setΔ%% | OS_b° | OS_s° | sat | rateOK | sign | intOK | PASS |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|:---:|:---:|:---:|\n');
    for i = 1:numel(rows)
        r = rows{i};
        fprintf(fid, '| %s | %+.0f | %.4f | %.4f | %+.1f | %.2f | %.2f | %+.1f | %.3f | %.3f | %d/%d | %s | %s | %s | %s |\n', ...
            r.op, r.amp_deg, r.mae_base_deg, r.mae_scaf_deg, 100*r.mae_improve, ...
            r.settle_base_s, r.settle_scaf_s, 100*r.settle_improve, ...
            r.os_base_deg, r.os_scaf_deg, r.base.sat_count, r.scaf.sat_count, ...
            yn(r.rate_ok), yn(r.sign_ok), yn(r.int_ok), yn(r.pass_case));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Gates\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|---|:---:|---|\n');
    fprintf(fid, '| Both OPs stable/bounded | %s | %s |\n', yn(gate.all_stable), tern(gate.all_stable,'finite states','diverged/unbounded'));
    fprintf(fid, '| Correct gamma sign | %s | both steps |\n', yn(gate.all_sign));
    fprintf(fid, '| MAE or settle improve >=5%% | %s | per case |\n', yn(gate.all_improve));
    fprintf(fid, '| Internal states bounded | %s | ||xi|| gate |\n', yn(gate.all_int));
    fprintf(fid, '| sat=0 | %s | mag sat count |\n', yn(gate.all_sat));
    fprintf(fid, '| rates within limits | %s | <=40 deg/s |\n', yn(gate.all_rate));
    fprintf(fid, '| Both OPs PASS | %s | %s |\n\n', yn(gate.both_ops), tern(isempty(gate.fail_detail), '—', gate.fail_detail));

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- Verdict: **%s**\n', verdict);
    fprintf(fid, '- Choice: **`%s`**\n', decision);
    fprintf(fid, '- Reason: %s\n', reason);
    fprintf(fid, '- Next: `%s`\n', next_step);
    fprintf(fid, '- Production: untouched\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', verdict);
    fprintf(fid, '- Decision: **%s**\n', decision);
    fprintf(fid, '- Evidence: %s\n', evidence_str(rows, gate));
    fprintf(fid, '- Files: `%s` `%s` `%s`\n', md_p, mat_p, png_p);
    fprintf(fid, '- Next: `%s`\n', next_step);
    fclose(fid);
end

function append_ss_audit(out_dir, task_id, verdict, decision, reason, next_step, gate, rows, P, ...
        md_p, mat_p, png_p)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `OUTER_GAMMA_INDI_AUDIT.mat`, `controller_law.m`, `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Driver: `run_gamma_indi_scaffold.m` (one invocation; no production edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_p, mat_p, png_p);
    fprintf(fid, '### Equations\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'nu = gamma_ref_dot + %.2f*e_gamma  clip +/-%.0fdeg/s\n', P.Kw, rad2deg(P.nu_clip));
    fprintf(fid, 'de_indi = de_f + (nu - gamma_dot_f)/Gdelta, Gdelta=%.4f\n', P.Gdelta);
    fprintf(fid, 'de_corr = sat(de_indi-de_base,+/-%.0fdeg); tau_f=%.2fs\n', rad2deg(P.corr_max), P.tau_f);
    fprintf(fid, '```\n\n');
    fprintf(fid, '### Key numbers\n\n');
    fprintf(fid, '| OP/step | MAE_b° | MAE_s° | set_b | set_s | PASS |\n|---|---:|---:|---:|---:|:---:|\n');
    for i = 1:numel(rows)
        r = rows{i};
        fprintf(fid, '| %s %+.0f | %.4f | %.4f | %.2f | %.2f | %s |\n', ...
            r.op, r.amp_deg, r.mae_base_deg, r.mae_scaf_deg, ...
            r.settle_base_s, r.settle_scaf_s, yn(r.pass_case));
    end
    fprintf(fid, '\n### Verdict / next\n\n');
    fprintf(fid, '- Verdict: **%s** | Decision: **`%s`**\n', verdict, decision);
    fprintf(fid, '- Reason: %s\n', reason);
    fprintf(fid, '- Next: `%s`\n', next_step);
    fprintf(fid, '- Production: untouched\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- %s\n', next_step);
    fclose(fid);
end

function print_feedback(verdict, decision, reason, next_step, gate, rows, md_p, mat_p, png_p)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('decision: %s\n', decision);
    fprintf('equations: nu=gdot_ref+0.46*e_g; de_indi=de_f+(nu-gdot_f)/Gdelta; Gdelta=-0.2208; tau=0.15s\n');
    fprintf('evidence: %s\n', evidence_str(rows, gate));
    fprintf('reason: %s\n', reason);
    fprintf('next: %s\n', next_step);
    fprintf('files: %s | %s | %s\n', md_p, mat_p, png_p);
end

function s = evidence_str(rows, gate)
    parts = cell(numel(rows), 1);
    for i = 1:numel(rows)
        r = rows{i};
        parts{i} = sprintf('%s%+.0f:MAEb=%.3f/s=%.3f(Δ%.0f%%),setb=%.2f/s=%.2f', ...
            r.op, r.amp_deg, r.mae_base_deg, r.mae_scaf_deg, 100*r.mae_improve, ...
            r.settle_base_s, r.settle_scaf_s);
    end
    s = [strjoin(parts, ' | ') sprintf(' | gates stable=%d sign=%d improve=%d sat=%d rate=%d int=%d', ...
        gate.all_stable, gate.all_sign, gate.all_improve, gate.all_sat, gate.all_rate, gate.all_int)];
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

function s = yn(c)
    if c; s = 'YES'; else; s = 'NO'; end
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
