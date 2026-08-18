function run_lqr_lqi_pitch_benchmark()
% LQR_LQI_PITCH_BENCHMARK_001 — isolated elevator-only pitch LQR vs LQI.
% Read-only: LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat, controller_law.m (limits).
% One MATLAB invocation. No controller / plant / guidance production edits.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    tag = 'LQR_LQI_PITCH_BENCHMARK';
    task_id = 'LQR_LQI_PITCH_BENCHMARK_001';

    L = load(fullfile(out_dir, 'LOCAL_SS_LEVEL.mat'));
    Cmb = load(fullfile(out_dir, 'LOCAL_SS_CLIMB.mat'));

    % Production actuator limits (init_parameters / controller_law; not edited)
    delta_e_max = deg2rad(15);          % magnitude
    de_rate_max = deg2rad(40);          % rad/s
    dt = 0.025;                         % production dt_controller
    T_end = 0.60;                       % SS_VALIDATION envelope
    t = (0:dt:T_end).';
    N = numel(t);

    % Bryson allowed deviations (stated; not a gain sweep)
    th_max = deg2rad(0.5);              % validated |δθ| envelope
    q_max  = deg2rad(5);                % rate peak budget for 0.5° in ~0.1–0.2 s
    w_max  = 0.05;                      % heave budget [m/s] at U~1.8, α~0.5°
    u_max  = 0.10;                      % surge deviation budget if u retained [m/s]
    de_des = deg2rad(2);                % design |δde_fb| for Bryson R (<< 15°)
    xi_max = deg2rad(0.25);             % integral state budget (LQI)
    de_dist_eq = deg2rad(0.25);         % moment-equivalent elevator disturbance

    state_full = {'x','y','z','phi','theta','psi','u','v','w','p','q','r'};
    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Envelope: T=%.2fs, |dtheta|<=0.5deg; de_max=+/-%.0fdeg, rate=%.0fdeg/s\n', ...
        T_end, rad2deg(delta_e_max), rad2deg(de_rate_max));

    level = design_and_sim('level', L.A, L.B, L.x0(:), L.u0(:), L.x_scale(:), ...
        L.u_scale(:), th_max, q_max, w_max, u_max, de_des, xi_max, ...
        de_dist_eq, delta_e_max, de_rate_max, t, dt, state_full);
    climb = design_and_sim('climb', Cmb.A, Cmb.B, Cmb.x0(:), Cmb.u0(:), Cmb.x_scale(:), ...
        Cmb.u_scale(:), th_max, q_max, w_max, u_max, de_des, xi_max, ...
        de_dist_eq, delta_e_max, de_rate_max, t, dt, state_full);

    [verdict, select, select_reason, reject_reason] = score_benchmark(level, climb);

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, level, climb, task_id, select);
    write_md(md_path, task_id, verdict, level, climb, select, select_reason, ...
        reject_reason, th_max, q_max, w_max, u_max, de_des, xi_max, ...
        de_dist_eq, delta_e_max, de_rate_max, T_end, dt, md_path, mat_path, png_path);
    append_audit(out_dir, task_id, verdict, level, climb, select, select_reason, ...
        reject_reason, md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.select = select;
    S.select_reason = select_reason;
    S.reject_reason = reject_reason;
    S.level = level;
    S.climb = climb;
    S.limits = struct('delta_e_max', delta_e_max, 'de_rate_max', de_rate_max, ...
        'dt', dt, 'T_end', T_end);
    S.bryson = struct('th_max', th_max, 'q_max', q_max, 'w_max', w_max, ...
        'u_max', u_max, 'de_des', de_des, 'xi_max', xi_max, 'de_dist_eq', de_dist_eq);
    S.sources = {fullfile(out_dir,'LOCAL_SS_LEVEL.mat'); ...
                 fullfile(out_dir,'LOCAL_SS_CLIMB.mat'); ...
                 fullfile(project_dir,'controller_law.m')};
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.note = ['Isolated elevator-only pitch LQR/LQI benchmark; production cascade unchanged; ' ...
              'not a production promotion'];
    save(mat_path, '-struct', 'S');

    fprintf('\nVERDICT: %s\n', verdict);
    fprintf('SELECT: %s\n', select);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, level, climb, select, select_reason, reject_reason, ...
        md_path, mat_path, png_path);
end

%% ===================== design + simulate one trim =====================
function R = design_and_sim(name, A, B, x0, u0, x_scale, u_scale, ...
        th_max, q_max, w_max, u_max, de_des, xi_max, de_dist_eq, ...
        delta_e_max, de_rate_max, t, dt, state_full)

    R.name = name;
    R.x0 = x0; R.u0 = u0;
    R.de_trim = u0(2);
    R.note_trim = sprintf('de_trim=%.4fdeg held separately; LQR/LQI on delta_de', rad2deg(R.de_trim));

    % Candidate plant indices in full state: theta,u,w,q  (elevator col=2)
    ix4 = [5, 7, 9, 11];
    ix3 = [5, 9, 11];          % omit u
    iu  = 2;

    A4 = A(ix4, ix4); B4 = B(ix4, iu);
    A3 = A(ix3, ix3); B3 = B(ix3, iu);

    % Physical pitch: theta_phys = -theta  (path/controller convention)
    % Transform plant [theta,u,w,q] -> [th_phys,u,w,q] and [theta,w,q] -> [th_phys,w,q]
    T4 = diag([-1, 1, 1, 1]);
    T3 = diag([-1, 1, 1]);
    Ap4 = T4 * A4 * inv(T4);  Bp4 = T4 * B4; %#ok<MINV>
    Ap3 = T3 * A3 * inv(T3);  Bp3 = T3 * B3; %#ok<MINV>

    names4 = {'theta_phys','u','w','q'};
    names3 = {'theta_phys','w','q'};
    sc4 = [th_max; u_max; w_max; q_max];
    sc3 = [th_max; w_max; q_max];

    pbh4 = pbh_stabilizable(Ap4, Bp4, sc4, u_scale(iu));
    pbh3 = pbh_stabilizable(Ap3, Bp3, sc3, u_scale(iu));

    R.cand4 = pack_cand(names4, ix4, Ap4, Bp4, pbh4, sc4, 'include u');
    R.cand3 = pack_cand(names3, ix3, Ap3, Bp3, pbh3, sc3, 'omit u');

    % Prefer smallest defensible: 3-state if stabilizable; else 4-state
    if pbh3.stabilizable
        use_u = false;
        Ap = Ap3; Bp = Bp3; sn = names3; ix = ix3; xsc = sc3;
        omit_doc = ['u omitted: PBH stabilizable elevator-only on [theta_phys,w,q]; ' ...
            'surge held at trim (separate thrust). Coupling A(q,u)/A(w,u) frozen at delta_u=0.'];
    elseif pbh4.stabilizable
        use_u = true;
        Ap = Ap4; Bp = Bp4; sn = names4; ix = ix4; xsc = sc4;
        omit_doc = 'u INCLUDED: 3-state [theta_phys,w,q] failed PBH stabilizability; retain surge.';
    else
        use_u = true;
        Ap = Ap4; Bp = Bp4; sn = names4; ix = ix4; xsc = sc4;
        omit_doc = 'FAIL: neither 3- nor 4-state elevator-only subsystem PBH-stabilizable.';
    end

    R.use_u = use_u;
    R.omit_doc = omit_doc;
    R.state_names = sn;
    R.ix = ix;
    R.A = Ap; R.B = Bp;
    R.n = size(Ap, 1);
    R.pbh = tern(use_u, pbh4, pbh3);

    % Moment-equivalent disturbance channel: Bd * de_dist injects same as B*de
    R.Bd = Bp;   % delta_xdot += Bd * de_dist_eq
    R.de_dist_eq = de_dist_eq;

    % ---------- LQR (regulation / tracking without integral) ----------
    Q = diag(1 ./ (xsc.^2));
    RR = 1 / (de_des^2);
    [K_lqr, ~, ~] = lqr(Ap, Bp, Q, RR);
    R.lqr = struct();
    R.lqr.Q = Q; R.lqr.R = RR; R.lqr.K = K_lqr;
    R.lqr.poles = eig(Ap - Bp * K_lqr);
    R.lqr.bryson = struct('x_max', xsc, 'de_des', de_des, 'names', {sn});

    % ---------- LQI: xi_dot = e = th_ref - th_phys ----------
    Cth = zeros(1, R.n); Cth(1) = 1;   % y = theta_phys
    Aa = [Ap, zeros(R.n, 1); -Cth, 0];
    Ba = [Bp; 0];
    Qa = blkdiag(Q, 1 / (xi_max^2));
    [K_lqi, ~, ~] = lqr(Aa, Ba, Qa, RR);
    R.lqi = struct();
    R.lqi.Q = Qa; R.lqi.R = RR; R.lqi.K = K_lqi;
    R.lqi.Kx = K_lqi(1:R.n); R.lqi.Ki = K_lqi(R.n+1);
    R.lqi.poles = eig(Aa - Ba * K_lqi);
    R.lqi.Cth = Cth;
    R.lqi.bryson = struct('x_max', [xsc; xi_max], 'de_des', de_des, ...
        'names', {{sn{:}, 'xi_pitch'}}); %#ok<CCAT>

    % Sign/frame sanity on gains: +theta_phys error should command -de under u=-Kx
    % (since +de -> +theta_phys from B: Bp(1) kinematics 0, but Bp(q)<0 plant-frame
    % after T: check closed-loop DC / step direction in sims)
    R.sign_note = sprintf(['Plant: theta_phys=-theta; de>0 -> +Z/+M; Bp_q after T. ' ...
        'LQR K_th=%.4g (u=-Kx => +th_phys -> de_fb=%+.4g)'], ...
        K_lqr(1), -K_lqr(1));

    % ---------- Cases ----------
    amps = [0.25, 0.5, -0.25, -0.5];  % deg
    cases = {};
    for a = amps
        cases{end+1} = struct('id', sprintf('ic_%+.2fdeg', a), 'type', 'ic', ...
            'th0_deg', a, 'thref_deg', 0, 'dist', false); %#ok<AGROW>
    end
    for a = amps
        cases{end+1} = struct('id', sprintf('ref_%+.2fdeg', a), 'type', 'ref', ...
            'th0_deg', 0, 'thref_deg', a, 'dist', false); %#ok<AGROW>
    end
    cases{end+1} = struct('id', 'dist_moment', 'type', 'dist', ...
        'th0_deg', 0, 'thref_deg', 0, 'dist', true);

    R.cases_lqr = cell(size(cases));
    R.cases_lqi = cell(size(cases));
    for k = 1:numel(cases)
        R.cases_lqr{k} = simulate_case(cases{k}, 'LQR', Ap, Bp, R.Bd, ...
            K_lqr, [], R.de_trim, delta_e_max, de_rate_max, de_dist_eq, t, dt);
        R.cases_lqi{k} = simulate_case(cases{k}, 'LQI', Ap, Bp, R.Bd, ...
            K_lqi(1:R.n), K_lqi(R.n+1), R.de_trim, delta_e_max, de_rate_max, ...
            de_dist_eq, t, dt);
    end

    R.lqr_pass = all(cellfun(@(c) c.pass, R.cases_lqr)) && all(real(R.lqr.poles) < -1e-6);
    R.lqi_pass = all(cellfun(@(c) c.pass, R.cases_lqi)) && all(real(R.lqi.poles) < -1e-6);
    R.pass = R.lqr_pass || R.lqi_pass;

    R.summary_lqr = summarize_cases(R.cases_lqr);
    R.summary_lqi = summarize_cases(R.cases_lqi);
end

function C = pack_cand(names, ix, A, B, pbh, xsc, tag)
    C = struct('names', {names}, 'ix', ix, 'A', A, 'B', B, 'pbh', pbh, ...
        'x_scale_design', xsc, 'tag', tag);
end

%% ===================== PBH stabilizability (scaled) =====================
function P = pbh_stabilizable(A, B, xsc, usc)
    n = size(A, 1);
    Sx = diag(xsc(:));
    Su = usc;
    As = Sx \ A * Sx;
    Bs = Sx \ B * Su;
    ev = eig(A);
    P.eig = ev;
    P.sigma_min = zeros(n, 1);
    P.uncontrollable = false(n, 1);
    for k = 1:n
        M = [ev(k) * eye(n) - As, Bs];
        s = svd(M);
        P.sigma_min(k) = s(end);
        tol = 10 * max(size(M)) * eps(s(1));
        P.uncontrollable(k) = (s(end) <= tol);
    end
    % Stabilizable iff every unstable/jω mode is controllable
    bad = false;
    for k = 1:n
        if real(ev(k)) >= -1e-9 && P.uncontrollable(k)
            bad = true;
        end
    end
    Qc = ctrb(As, Bs);
    sQ = svd(Qc);
    tolQ = max(size(Qc)) * eps(sQ(1));
    P.rank = nnz(sQ > tolQ);
    P.cond = sQ(1) / max(sQ(end), eps);
    P.stabilizable = ~bad && (P.rank == n);
    P.tol_note = 'scaled PBH; unc if sigma_min<=10*max(size)*eps(sigma_max)';
end

%% ===================== discrete sim with actuator =====================
function C = simulate_case(spec, arch, A, B, Bd, Kx, Ki, de_trim, ...
        de_max, de_rate_max, de_dist_eq, t, dt)

    n = size(A, 1);
    N = numel(t);
    x = zeros(n, N);
    xi = zeros(1, N);
    de_fb = zeros(1, N);
    de_abs = zeros(1, N);
    de_cmd = zeros(1, N);
    th_ref = deg2rad(spec.thref_deg) * ones(1, N);
    x(1, 1) = deg2rad(spec.th0_deg);   % theta_phys IC
    dist = 0;
    if spec.dist
        dist = de_dist_eq;
    end

    de_prev = de_trim;   % start at trim (bumpless absolute)
    sat_mag = false(1, N);
    sat_rate = false(1, N);

    for k = 1:N-1
        th = x(1, k);
        e = th_ref(k) - th;
        if strcmp(arch, 'LQR')
            % Error-state LQR: regulate (x - x_ref_approx); x_ref=[th_ref;0;...]
            xref = zeros(n, 1); xref(1) = th_ref(k);
            u_fb = -Kx * (x(:, k) - xref);
        else
            u_fb = -Kx * x(:, k) - Ki * xi(k);
        end
        de_cmd(k) = de_trim + u_fb;
        % Magnitude sat
        de_sat = max(min(de_cmd(k), de_max), -de_max);
        sat_mag(k) = abs(de_cmd(k) - de_sat) > 1e-12;
        % Rate sat (production: max_de = deg2rad(40)*dt)
        dmax = de_rate_max * dt;
        de_k = de_prev + max(min(de_sat - de_prev, dmax), -dmax);
        sat_rate(k) = abs(de_sat - de_prev) > dmax + 1e-12;
        de_abs(k) = de_k;
        de_fb(k) = de_k - de_trim;
        de_prev = de_k;

        % Plant: delta about trim; input is delta_de; + moment-eq disturbance
        xdot = A * x(:, k) + B * de_fb(k) + Bd * dist;
        x(:, k+1) = x(:, k) + dt * xdot;
        if strcmp(arch, 'LQI')
            xi(k+1) = xi(k) + dt * e;
        end
    end
    % last sample hold
    de_cmd(N) = de_cmd(N-1);
    de_abs(N) = de_prev;
    de_fb(N) = de_prev - de_trim;
    sat_mag(N) = sat_mag(N-1);
    sat_rate(N) = sat_rate(N-1);

    th = x(1, :);
    e = th_ref - th;
    de_rate = [0, diff(de_abs) / dt];

    C = struct();
    C.spec = spec; C.arch = arch;
    C.t = t; C.th = th; C.th_ref = th_ref; C.e = e;
    C.x = x; C.xi = xi; C.de_fb = de_fb; C.de_abs = de_abs;
    C.de_cmd = de_cmd; C.de_rate = de_rate;
    C.sat_mag_frac = mean(sat_mag);
    C.sat_rate_frac = mean(sat_rate);
    C.de_peak = max(abs(de_fb));
    C.de_rms = sqrt(mean(de_fb.^2));
    C.de_rate_peak = max(abs(de_rate));
    C.de_rate_rms = sqrt(mean(de_rate.^2));

    % Metrics
    amp = max(abs(deg2rad(spec.th0_deg)), abs(deg2rad(spec.thref_deg)));
    if amp < 1e-12 && ~spec.dist
        amp = deg2rad(0.25);
    end
    if spec.dist
        amp = max(amp, deg2rad(0.1));
    end
    band = 0.05 * max(amp, deg2rad(0.1));   % 5% band
    C.ess = abs(e(end));
    C.ess_deg = rad2deg(C.ess);
    % settling: first time |e| stays in band to end
    C.ts = Inf;
    for k = 1:N
        if all(abs(e(k:end)) <= band)
            C.ts = t(k);
            break;
        end
    end
    % overshoot vs step/IC
    if strcmp(spec.type, 'ic')
        % return to 0: overshoot = excursion opposite to IC
        if spec.th0_deg > 0
            C.os = max(0, -min(th));
        else
            C.os = max(0, max(th));
        end
    else
        % ref step from 0
        if spec.thref_deg > 0
            C.os = max(0, max(th) - deg2rad(spec.thref_deg));
        elseif spec.thref_deg < 0
            C.os = max(0, deg2rad(spec.thref_deg) - min(th));
        else
            C.os = max(abs(th));
        end
    end
    C.os_deg = rad2deg(C.os);
    C.os_pct = 100 * C.os / max(amp, eps);

    % Direction / sign check for nonzero IC or ref
    C.sign_ok = true;
    if abs(spec.th0_deg) > 0
        % should move toward 0 initially
        if abs(th(min(3, N))) > abs(th(1)) + deg2rad(0.02)
            C.sign_ok = false;
        end
    elseif abs(spec.thref_deg) > 0
        % should move toward ref
        move = th(min(5, N)) - th(1);
        if sign(move) ~= sign(spec.thref_deg) && abs(move) > deg2rad(0.01)
            C.sign_ok = false;
        end
    end

    % Chatter: excessive rate-sat toggling
    dsign = diff(sign(de_rate + 1e-15));
    C.chatter_count = nnz(dsign ~= 0);
    C.chatter = (C.chatter_count > 12) && (C.sat_rate_frac > 0.3);

    % Divergence
    C.divergent = any(~isfinite(th)) || (max(abs(th)) > deg2rad(5));

    % Pole-free case pass
    C.unstable_traj = (C.ess > deg2rad(2)) && (C.ts == Inf) && (abs(e(end)) > abs(e(1)));

    C.pass = C.sign_ok && ~C.chatter && ~C.divergent && ~C.unstable_traj ...
        && (C.sat_mag_frac < 0.95) && (C.de_peak <= de_max + 1e-9);

    % For disturbance: LQR may have ess; still "pass" if bounded & no chatter
    if spec.dist
        C.pass = C.sign_ok && ~C.chatter && ~C.divergent && ~C.unstable_traj ...
            && (max(abs(th)) < deg2rad(2));
    end
end

function S = summarize_cases(cases)
    S.n = numel(cases);
    S.n_pass = sum(cellfun(@(c) c.pass, cases));
    S.ts_med = median(cellfun(@(c) tern(isfinite(c.ts), c.ts, Tnan()), cases));
    S.ess_max_deg = max(cellfun(@(c) c.ess_deg, cases));
    S.os_max_deg = max(cellfun(@(c) c.os_deg, cases));
    S.de_peak_max = max(cellfun(@(c) c.de_peak, cases));
    S.de_rms_max = max(cellfun(@(c) c.de_rms, cases));
    S.de_rate_peak_max = max(cellfun(@(c) c.de_rate_peak, cases));
    S.sat_mag_max = max(cellfun(@(c) c.sat_mag_frac, cases));
    S.chatter_any = any(cellfun(@(c) c.chatter, cases));
    S.sign_fail = any(cellfun(@(c) ~c.sign_ok, cases));
    % pick representative 0.5deg ref and dist for tables
    S.rep_ref = find_case(cases, 'ref_+0.50deg');
    S.rep_ic  = find_case(cases, 'ic_+0.50deg');
    S.rep_dist = find_case(cases, 'dist_moment');
end

function v = Tnan(), v = NaN; end

function c = find_case(cases, id)
    c = [];
    for k = 1:numel(cases)
        if strcmp(cases{k}.spec.id, id)
            c = cases{k};
            return;
        end
    end
end

%% ===================== score / select =====================
function [verdict, select, sel_r, rej_r] = score_benchmark(level, climb)
    sub_ok = level.pbh.stabilizable && climb.pbh.stabilizable;
    lqr_all = level.lqr_pass && climb.lqr_pass;
    lqi_all = level.lqi_pass && climb.lqi_pass;

    if ~sub_ok
        verdict = 'FAIL';
        select = 'none';
        sel_r = 'none';
        rej_r = 'Subsystem PBH stabilizability failed at level and/or climb.';
        return;
    end

    % Compare disturbance rejection and ess on ref steps
    lqr_ess = max([level.summary_lqr.ess_max_deg, climb.summary_lqr.ess_max_deg]);
    lqi_ess = max([level.summary_lqi.ess_max_deg, climb.summary_lqi.ess_max_deg]);
    lqr_dist = max(level.summary_lqr.rep_dist.ess_deg, climb.summary_lqr.rep_dist.ess_deg);
    lqi_dist = max(level.summary_lqi.rep_dist.ess_deg, climb.summary_lqi.rep_dist.ess_deg);
    lqr_de = max([level.summary_lqr.de_peak_max, climb.summary_lqr.de_peak_max]);
    lqi_de = max([level.summary_lqi.de_peak_max, climb.summary_lqi.de_peak_max]);

    if lqr_all && lqi_all
        verdict = 'PASS';
        % Clear reason required for selection
        if (lqi_dist < 0.5 * lqr_dist) && (lqi_ess < lqr_ess) && (lqi_de < 1.5 * lqr_de)
            select = 'LQI_scheduled';
            sel_r = sprintf(['LQI: clear disturbance/ess advantage (dist ess %.3f vs %.3f deg) ', ...
                'with comparable actuator (de_peak %.3f vs %.3f deg); schedule level/climb gains.'], ...
                lqi_dist, lqr_dist, rad2deg(lqi_de), rad2deg(lqr_de));
            rej_r = 'LQR rejected for promotion-to-NL-test: nonzero disturbance bias, no integral.';
        elseif (lqr_de < 0.7 * lqi_de) && (lqr_ess < 0.1) && (lqi_dist > 2 * max(lqr_dist, 1e-6))
            select = 'LQR_scheduled';
            sel_r = 'LQR: lower actuator peak with adequate ess on IC/ref; LQI over-actuates.';
            rej_r = 'LQI rejected: higher de without needed ess benefit on these cases.';
        else
            select = 'none';
            sel_r = 'Both LQR and LQI pass all cases, but no clear single-architecture advantage for NL test.';
            rej_r = ['No candidate selected (at most one, and only with clear reason). ', ...
                sprintf('LQR ess_max=%.3f deg dist=%.3f; LQI ess_max=%.3f dist=%.3f.', ...
                lqr_ess, lqr_dist, lqi_ess, lqi_dist)];
        end
    elseif lqi_all && ~lqr_all
        verdict = 'PASS';
        select = 'LQI_scheduled';
        sel_r = 'Only LQI passed all level+climb cases; LQR failed at least one gate.';
        rej_r = 'LQR rejected: failed pass gates (poles/sign/chatter/sat/divergence).';
    elseif lqr_all && ~lqi_all
        verdict = 'PASS';
        select = 'LQR_scheduled';
        sel_r = 'Only LQR passed all level+climb cases; LQI failed at least one gate.';
        rej_r = 'LQI rejected: failed pass gates.';
    else
        verdict = 'FAIL';
        select = 'none';
        sel_r = 'none';
        rej_r = 'Both LQR and LQI failed one or more level/climb cases; no NL candidate.';
    end
end

%% ===================== writers =====================
function write_png(png_path, level, climb, task_id, select)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1280 900]);
    tl = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s — select=%s', task_id, select), 'Interpreter', 'none');

    plot_pair(nexttile, level, 'ref_+0.50deg', 'LEVEL ref +0.5deg');
    plot_pair(nexttile, climb, 'ref_+0.50deg', 'CLIMB ref +0.5deg');
    plot_pair(nexttile, level, 'ic_+0.50deg', 'LEVEL IC +0.5deg');
    plot_pair(nexttile, climb, 'ic_+0.50deg', 'CLIMB IC +0.5deg');
    plot_pair(nexttile, level, 'dist_moment', 'LEVEL disturbance');
    plot_pair(nexttile, climb, 'dist_moment', 'CLIMB disturbance');

    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function plot_pair(ax, R, id, ttl)
    clqr = find_case(R.cases_lqr, id);
    clqi = find_case(R.cases_lqi, id);
    hold(ax, 'on'); grid(ax, 'on');
    if ~isempty(clqr)
        plot(ax, clqr.t, rad2deg(clqr.th), 'b-', 'LineWidth', 1.2);
        plot(ax, clqr.t, rad2deg(clqr.th_ref), 'k--', 'LineWidth', 0.8);
    end
    if ~isempty(clqi)
        plot(ax, clqi.t, rad2deg(clqi.th), 'r-', 'LineWidth', 1.2);
    end
    ylabel(ax, '\theta_{phys} [deg]'); xlabel(ax, 't [s]');
    title(ax, ttl, 'Interpreter', 'none');
    legend(ax, {'LQR','ref','LQI'}, 'Location', 'best');
end

function write_md(md_path, task_id, verdict, level, climb, select, sel_r, rej_r, ...
        th_max, q_max, w_max, u_max, de_des, xi_max, de_dist_eq, ...
        de_max, de_rate_max, T_end, dt, md_p, mat_p, png_p)

    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Elevator-only pitch LQR vs LQI\n\n', task_id);
    fprintf(fid, '**Verdict: %s**\n\n', verdict);
    fprintf(fid, '**Selected for NL test: `%s`** (not a production promotion)\n\n', select);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`\n');
    fprintf(fid, '- Actuator limits from `controller_law.m` / `init_parameters.m` (read-only): ');
    fprintf(fid, '|de|<=%.0fdeg, |dde/dt|<=%.0fdeg/s, dt=%.3fs\n', rad2deg(de_max), rad2deg(de_rate_max), dt);
    fprintf(fid, '- Driver: `run_lqr_lqi_pitch_benchmark.m` (one invocation; no production edit)\n');
    fprintf(fid, '- Envelope: T_end=%.2fs, |dtheta|<=0.5deg (SS_VALIDATION)\n', T_end);
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_p, mat_p, png_p);

    fprintf(fid, '## Subsystem (smallest defensible elevator-only)\n\n');
    fprintf(fid, 'Physical pitch: `theta_phys = -theta`. Input: elevator `delta_e` only.\n');
    fprintf(fid, 'Equilibrium trim `de_trim` held separately; feedback on `delta_de = de - de_trim`.\n\n');
    write_subsys_md(fid, 'LEVEL', level);
    write_subsys_md(fid, 'CLIMB', climb);

    fprintf(fid, '## Bryson weights (explicit allowed deviations)\n\n');
    fprintf(fid, '| qty | allowed | Q or R |\n|---|---:|---:|\n');
    fprintf(fid, '| theta_phys | %.4f deg | 1/th_max^2 |\n', rad2deg(th_max));
    fprintf(fid, '| w | %.3f m/s | 1/w_max^2 |\n', w_max);
    fprintf(fid, '| q | %.2f deg/s | 1/q_max^2 |\n', rad2deg(q_max));
    if level.use_u || climb.use_u
        fprintf(fid, '| u | %.3f m/s | 1/u_max^2 |\n', u_max);
    end
    fprintf(fid, '| xi (LQI) | %.3f deg | 1/xi_max^2 |\n', rad2deg(xi_max));
    fprintf(fid, '| delta_de | %.2f deg (design) | R=1/de_des^2 |\n\n', rad2deg(de_des));
    fprintf(fid, 'Moment-equivalent disturbance: `Bd*de_dist` with de_dist=%.2f deg.\n\n', rad2deg(de_dist_eq));

    fprintf(fid, '## Gains and closed-loop poles\n\n');
    write_gains_md(fid, 'LEVEL', level);
    write_gains_md(fid, 'CLIMB', climb);

    fprintf(fid, '## Key metrics (envelope window)\n\n');
    write_metrics_md(fid, 'LEVEL', level);
    write_metrics_md(fid, 'CLIMB', climb);

    fprintf(fid, '## Selection\n\n');
    fprintf(fid, '- Selected: `%s`\n', select);
    fprintf(fid, '- Reason: %s\n', sel_r);
    fprintf(fid, '- Rejected: %s\n\n', rej_r);
    fprintf(fid, 'Production cascade remains baseline. This benchmark does **not** change `controller_law.m`.\n\n');

    fprintf(fid, '## Next\n\n');
    if strcmp(select, 'none')
        fprintf(fid, '- No NL candidate; optionally revisit weights or retain cascade.\n');
    else
        fprintf(fid, '- Optional nonlinear smoke test of **%s** only (still not production).\n', select);
    end
    fprintf(fid, '- Helix remains excluded from ordinary inertial LTI.\n');
    fclose(fid);
end

function write_subsys_md(fid, label, R)
    fprintf(fid, '### %s\n\n', label);
    fprintf(fid, '- States: [%s] (n=%d)\n', strjoin(R.state_names, ', '), R.n);
    fprintf(fid, '- %s\n', R.omit_doc);
    fprintf(fid, '- de_trim = %.4f deg\n', rad2deg(R.de_trim));
    fprintf(fid, '- PBH stabilizable: %s (rank %d/%d, cond(Qc_s)=%.3g)\n', ...
        tern(R.pbh.stabilizable, 'YES', 'NO'), R.pbh.rank, R.n, R.pbh.cond);
    fprintf(fid, '- Cand3 stabilizable=%s; Cand4 stabilizable=%s\n', ...
        tern(R.cand3.pbh.stabilizable, 'YES', 'NO'), tern(R.cand4.pbh.stabilizable, 'YES', 'NO'));
    fprintf(fid, '- Sign: %s\n\n', R.sign_note);
    fprintf(fid, 'A (%dx%d):\n```\n', R.n, R.n);
    for i = 1:R.n
        fprintf(fid, ' %s\n', sprintf(' % .6e', R.A(i, :)));
    end
    fprintf(fid, '```\nB (%dx1):\n```\n', R.n);
    fprintf(fid, ' %s\n```\n\n', sprintf(' % .6e', R.B(:)'));
end

function write_gains_md(fid, label, R)
    fprintf(fid, '### %s\n\n', label);
    fprintf(fid, 'LQR K = [%s]\n', sprintf(' %.6g', R.lqr.K));
    fprintf(fid, 'LQR poles: %s\n', fmt_poles(R.lqr.poles));
    fprintf(fid, 'LQI Kx = [%s], Ki = %.6g\n', sprintf(' %.6g', R.lqi.Kx), R.lqi.Ki);
    fprintf(fid, 'LQI poles: %s\n\n', fmt_poles(R.lqi.poles));
end

function write_metrics_md(fid, label, R)
    fprintf(fid, '### %s\n\n', label);
    fprintf(fid, '| Arch | cases pass | ess_max [deg] | os_max [deg] | de_peak [deg] | de_rms [deg] | |de_rate|_pk [deg/s] | sat_mag_max | chatter |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    for arch = {'lqr','lqi'}
        S = R.(['summary_' arch{1}]);
        fprintf(fid, '| %s | %d/%d | %.4f | %.4f | %.3f | %.3f | %.2f | %.2f | %s |\n', ...
            upper(arch{1}), S.n_pass, S.n, S.ess_max_deg, S.os_max_deg, ...
            rad2deg(S.de_peak_max), rad2deg(S.de_rms_max), rad2deg(S.de_rate_peak_max), ...
            S.sat_mag_max, tern(S.chatter_any, 'YES', 'NO'));
    end
    fprintf(fid, '\nRepresentative ref=+0.5deg / dist:\n\n');
    fprintf(fid, '| Arch | case | ts [s] | ess [deg] | os [deg] | de_peak [deg] | pass |\n');
    fprintf(fid, '|---|---|---:|---:|---:|---:|:---:|\n');
    for arch = {'lqr','lqi'}
        S = R.(['summary_' arch{1}]);
        for fld = {'rep_ref','rep_dist'}
            c = S.(fld{1});
            if isempty(c), continue; end
            fprintf(fid, '| %s | %s | %s | %.4f | %.4f | %.3f | %s |\n', ...
                upper(arch{1}), c.spec.id, tern(isfinite(c.ts), sprintf('%.3f', c.ts), 'Inf'), ...
                c.ess_deg, c.os_deg, rad2deg(c.de_peak), tern(c.pass, 'Y', 'N'));
        end
    end
    fprintf(fid, '\nLQR all-pass=%s; LQI all-pass=%s\n\n', ...
        tern(R.lqr_pass, 'YES', 'NO'), tern(R.lqi_pass, 'YES', 'NO'));
end

function s = fmt_poles(p)
    p = p(:);
    [~, o] = sort(real(p), 'descend');
    p = p(o);
    parts = cell(numel(p), 1);
    for i = 1:numel(p)
        if abs(imag(p(i))) < 1e-12
            parts{i} = sprintf('%+.4e', real(p(i)));
        else
            parts{i} = sprintf('%+.4e%+.4ej', real(p(i)), imag(p(i)));
        end
    end
    s = strjoin(parts, ', ');
end

function append_audit(out_dir, task_id, verdict, level, climb, select, sel_r, rej_r, md_p, mat_p, png_p)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat` (SS_VALIDATION PASS; CTRL_OBS PASS)\n');
    fprintf(fid, '- Actuator limits read from `controller_law.m` (no edit): |de|<=15deg, rate 40deg/s\n');
    fprintf(fid, '- Driver: `run_lqr_lqi_pitch_benchmark.m` (read-only; no production edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_p, mat_p, png_p);
    fprintf(fid, '### Verdict\n\n**%s** — isolated elevator-only LQR vs LQI pitch benchmark (level & climb).\n\n', verdict);
    fprintf(fid, '### Subsystem\n\n');
    fprintf(fid, '- Level: [%s], PBH stab=%s, %s\n', strjoin(level.state_names, ','), ...
        tern(level.pbh.stabilizable, 'YES', 'NO'), level.omit_doc);
    fprintf(fid, '- Climb: [%s], PBH stab=%s, %s\n\n', strjoin(climb.state_names, ','), ...
        tern(climb.pbh.stabilizable, 'YES', 'NO'), climb.omit_doc);
    fprintf(fid, '### Selection\n\n');
    fprintf(fid, '- Selected for optional NL test: `%s`\n', select);
    fprintf(fid, '- Reason: %s\n', sel_r);
    fprintf(fid, '- Rejected: %s\n', rej_r);
    fprintf(fid, '- Production cascade unchanged (baseline X/XZ/helix metrics stand).\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- No controller change. Optional NL smoke only if selected≠none; helix still excluded from LTI.\n');
    fclose(fid);
end

function print_feedback(verdict, level, climb, select, sel_r, rej_r, md_p, mat_p, png_p)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('PASS/FAIL: %s\n', verdict);
    fprintf('Subsystem LEVEL: [%s] | %s\n', strjoin(level.state_names, ','), level.omit_doc);
    fprintf('Subsystem CLIMB: [%s] | %s\n', strjoin(climb.state_names, ','), climb.omit_doc);
    fprintf('LEVEL LQR poles: %s\n', fmt_poles(level.lqr.poles));
    fprintf('LEVEL LQI poles: %s\n', fmt_poles(level.lqi.poles));
    fprintf('CLIMB LQR poles: %s\n', fmt_poles(climb.lqr.poles));
    fprintf('CLIMB LQI poles: %s\n', fmt_poles(climb.lqi.poles));
    fprintf('LEVEL LQR K=[%s]\n', sprintf(' %.4g', level.lqr.K));
    fprintf('LEVEL LQI Kx=[%s] Ki=%.4g\n', sprintf(' %.4g', level.lqi.Kx), level.lqi.Ki);
    fprintf('CLIMB LQR K=[%s]\n', sprintf(' %.4g', climb.lqr.K));
    fprintf('CLIMB LQI Kx=[%s] Ki=%.4g\n', sprintf(' %.4g', climb.lqi.Kx), climb.lqi.Ki);
    fprintf('Key LEVEL LQR/LQI ess_max=%.4f/%.4f deg; de_peak=%.3f/%.3f deg\n', ...
        level.summary_lqr.ess_max_deg, level.summary_lqi.ess_max_deg, ...
        rad2deg(level.summary_lqr.de_peak_max), rad2deg(level.summary_lqi.de_peak_max));
    fprintf('Key CLIMB LQR/LQI ess_max=%.4f/%.4f deg; de_peak=%.3f/%.3f deg\n', ...
        climb.summary_lqr.ess_max_deg, climb.summary_lqi.ess_max_deg, ...
        rad2deg(climb.summary_lqr.de_peak_max), rad2deg(climb.summary_lqi.de_peak_max));
    fprintf('SELECTED: %s\n  reason: %s\n', select, sel_r);
    fprintf('REJECTED: %s\n', rej_r);
    fprintf('Files: %s | %s | %s\n', md_p, mat_p, png_p);
    fprintf('Next: no controller change');
    if strcmp(select, 'none')
        fprintf('; no NL candidate selected.\n');
    else
        fprintf('; optional NL smoke of %s only.\n', select);
    end
end

function y = tern(c, a, b)
    if c, y = a; else, y = b; end
end
