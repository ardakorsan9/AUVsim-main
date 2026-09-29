function run_auv_visual_evidence_pack()
% AUV_VISUAL_EVIDENCE_PACK_001
% Isolated publication evidence pack from accepted raw MAT artifacts only.
% No controller/guidance/plant edits. No nonlinear rerun (required channels present).
%
% Artifact resolution (from suite_results/PITCH_CONTROL_RESEARCH_LOG.md):
%   production X/XZ/R10 paths+capsule : PITCH_YAW_CLOSURE.mat (PITCH_YAW_FINAL_CLOSURE PASS)
%   guidance mission                  : GUIDANCE_MISSION_BASELINE.mat
%   CUSUM fault validation (PASS)     : RUDDER_CUSUM_DETECTOR.mat (κ=0.066156,h=11.066456)
% Roll-damping raw (not indexed in research log; PASS MAT exists):
%   accepted roll damp base+prod      : ROLL_PRODUCTION_CLOSURE.mat
%   (supplies full SX/SXZ/SH channels absent from PITCH_YAW mX/mXZ logs)
%
% Outputs: suite_results/AUV_VISUAL_EVIDENCE_PACK.{md,mat,png} + 6 panel PNGs
%          + indexed overview PNG. Appends PITCH_CONTROL_RESEARCH_LOG.md.
% Does NOT touch CODEX_VERTICAL_PLAN.md. Production frozen.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    tag = 'AUV_VISUAL_EVIDENCE_PACK';
    task_id = 'AUV_VISUAL_EVIDENCE_PACK_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    mat_pyc = fullfile(out_dir, 'PITCH_YAW_CLOSURE.mat');
    mat_roll = fullfile(out_dir, 'ROLL_PRODUCTION_CLOSURE.mat');
    mat_guid = fullfile(out_dir, 'GUIDANCE_MISSION_BASELINE.mat');
    mat_cusum = fullfile(out_dir, 'RUDDER_CUSUM_DETECTOR.mat');
    assert(exist(mat_pyc, 'file') == 2, 'Missing %s', mat_pyc);
    assert(exist(mat_roll, 'file') == 2, 'Missing %s', mat_roll);
    assert(exist(mat_guid, 'file') == 2, 'Missing %s', mat_guid);
    assert(exist(mat_cusum, 'file') == 2, 'Missing %s', mat_cusum);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Evidence pack from accepted raw MATs; no NL rerun; production frozen.\n');

    PYC = load(mat_pyc);
    ROLL = load(mat_roll);
    GUID = load(mat_guid);
    CUS = load(mat_cusum);

    % Fixed limits (init_parameters / ICD): elevator ±15 deg, rudder ±25 deg, rate 40 deg/s
    lim = struct('de_max_deg', 15, 'dr_max_deg', 25, 'rate_dps', 40, ...
        'dt', 0.025, 'f_ctrl', 40, 'f_guid', 1/0.075, 'f_marker', 1/0.075);
    lim.de_max = deg2rad(lim.de_max_deg);
    lim.dr_max = deg2rad(lim.dr_max_deg);
    lim.rate = deg2rad(lim.rate_dps);

    % ---- Bundle routes: ROLL candidate = current production (roll-damp on) ----
    pathX = PYC.pathX; pathXZ = PYC.pathXZ; pathH = PYC.pathH;
    SX = ROLL.candidate.SX; SXZ = ROLL.candidate.SXZ; SH = ROLL.candidate.SH;
    BX = ROLL.baseline.SX; BH = ROLL.baseline.SH;
    MX = ROLL.candidate.X; MXZ = ROLL.candidate.XZ; MH = ROLL.candidate.H;
    MXb = ROLL.baseline.X; MHb = ROLL.baseline.H;

    routes = struct();
    routes.X = pack_route('X', pathX, SX, MX, false, 'first_hold');
    routes.XZ = pack_route('XZ', pathXZ, SXZ, MXZ, true, 'persistent');
    routes.R10 = pack_route('R10', pathH, SH, MH, false, 'persistent');
    routes.R10_base = pack_route('R10_base', pathH, BH, MHb, false, 'persistent');
    routes.X_base = pack_route('X_base', pathX, BX, MXb, false, 'first_hold');

    % Guidance mission raw (for overview annotation / optional path panel note)
    mission = struct();
    mission.source = 'GUIDANCE_MISSION_BASELINE.mat';
    mission.S = GUID.Results.S;
    mission.path = GUID.path;
    mission.class = GUID.Class;
    if isfield(GUID.Results, 'verdict_audit')
        mission.verdict_audit = GUID.Results.verdict_audit;
    elseif isfield(GUID.Results, 'mission_class')
        mission.verdict_audit = GUID.Results.mission_class;
    else
        mission.verdict_audit = 'see GUIDANCE_MISSION_BASELINE';
    end

    % CUSUM example (PASS coverage artifact)
    cus = pack_cusum(CUS);

    % ---- Generate 6 panels + overview ----
    png = struct();
    P = struct();
    [png.p1, P.p1] = fig_path_cte(out_dir, tag, routes, lim);
    [png.p2, P.p2] = fig_attitude(out_dir, tag, routes, lim);
    [png.p3, P.p3] = fig_kinematics(out_dir, tag, routes, lim);
    [png.p4, P.p4] = fig_actuators(out_dir, tag, routes, lim);
    [png.p5, P.p5] = fig_rates_roll(out_dir, tag, routes, ROLL, lim);
    [png.p6, P.p6] = fig_cusum(out_dir, tag, cus, lim);
    [png.overview, P.overview] = fig_overview(out_dir, tag, P, routes, cus, mission, lim, task_id, stamp);

    keys = {'p1','p2','p3','p4','p5','p6'};
    n_pass = 0; n_fail = 0; n_na = 0;
    for ii = 1:6
        v = P.(keys{ii}).verdict;
        if strcmp(v, 'PASS'); n_pass = n_pass + 1;
        elseif strcmp(v, 'FAIL'); n_fail = n_fail + 1;
        else; n_na = n_na + 1;
        end
    end
    pack_pass = (n_fail == 0) && (n_pass >= 5) && all(arrayfun(@(k) exist(png.(sprintf('p%d', k)), 'file') == 2, 1:6));
    if pack_pass
        verdict = 'PASS';
    else
        verdict = 'FAIL';
    end

    provenance = struct();
    provenance.research_log = 'suite_results/PITCH_CONTROL_RESEARCH_LOG.md';
    provenance.production_xyz_r10 = 'suite_results/PITCH_YAW_CLOSURE.mat';
    provenance.roll_damping = 'suite_results/ROLL_PRODUCTION_CLOSURE.mat';
    provenance.roll_note = ['Roll damping PASS not indexed in research log; ', ...
        'ROLL_PRODUCTION_CLOSURE.mat used (base vs prod Kp_roll=0.605072). ', ...
        'Full X/XZ time series taken from ROLL (PITCH_YAW mX/mXZ lack vp/vel/ori).'];
    provenance.guidance_mission = 'suite_results/GUIDANCE_MISSION_BASELINE.mat';
    provenance.cusum = 'suite_results/RUDDER_CUSUM_DETECTOR.mat';
    provenance.nonlinear_rerun = false;
    provenance.production_edited = false;
    provenance.codex_untouched = true;

    Results = struct();
    Results.task_id = task_id;
    Results.stamp = stamp;
    Results.tag = tag;
    Results.verdict = verdict;
    Results.n_pass = n_pass;
    Results.n_fail = n_fail;
    Results.n_na = n_na;
    Results.panels = P;
    Results.png = png;
    Results.provenance = provenance;
    Results.limits = lim;
    Results.cusum = cus.summary;
    Results.roll = struct('Kp_roll', ROLL.Kp_roll, 'verdict', ROLL.verdict, ...
        'pRMS_base_H', MHb.p.rms_dps, 'pRMS_prod_H', MH.p.rms_dps, ...
        'pRMS_improve_pct', 100 * (1 - MH.p.rms_dps / max(MHb.p.rms_dps, eps)));
    Results.next = 'realism_gap_audit_only_after_pack_PASS';

    mat_path = fullfile(out_dir, [tag '.mat']);
    md_path = fullfile(out_dir, [tag '.md']);
    overview_alias = fullfile(out_dir, [tag '.png']);
    copyfile(png.overview, overview_alias);

    save(mat_path, 'Results', 'routes', 'cus', 'mission', 'provenance', 'lim', 'P', 'png', '-v7.3');
    write_md(md_path, Results, P, png, provenance);
    append_log(out_dir, Results);

    fprintf('\n%s verdict=%s  panels PASS/FAIL/NA=%d/%d/%d\n', ...
        task_id, verdict, n_pass, n_fail, n_na);
    fprintf('Artifacts: %s\n', mat_path);
    fprintf('Next: %s\n', Results.next);
end

%% ===================== route packing =====================
function R = pack_route(name, path, S, M, is_xz, win_mode)
    t = S.t(:); dt = S.dt; n = numel(t);
    phi = S.ori(:, 1); theta_euler = S.ori(:, 2); psi = S.ori(:, 3);
    theta_phys = -theta_euler;                 % BODY/NED: theta_phys = -Euler_theta
    p = S.rates(:, 1); q = S.rates(:, 2); r = S.rates(:, 3);
    u = S.vel(:, 1); v = S.vel(:, 2); w = S.vel(:, 3);
    alpha = atan2(w, u);                       % BODY AoA [rad]
    U = sqrt(u.^2 + v.^2 + w.^2);

    % Inertial NED velocity from BODY (vectorized project convention)
    cph = cos(phi); sph = sin(phi);
    cth = cos(theta_euler); sth = sin(theta_euler);
    cps = cos(psi); sps = sin(psi);
    % R_bn rows; V_NED = R_bn' * [u;v;w]
    % Column-wise:
    VN = cth.*cps.*u + (sph.*sth.*cps - cph.*sps).*v + (cph.*sth.*cps + sph.*sps).*w;
    VE = cth.*sps.*u + (sph.*sth.*sps + cph.*cps).*v + (cph.*sth.*sps - sph.*cps).*w;
    VD = (-sth).*u + (sph.*cth).*v + (cph.*cth).*w;
    Uh = hypot(VN, VE);
    gamma_act = atan2(VD, max(Uh, 1e-9));      % NED flight-path (z↓ positive)
    gamma_body_approx = theta_phys + alpha;    % project identity under test
    resid = gamma_act - gamma_body_approx;

    % Path slope from discrete path tangent (independent of attitude)
    [s_nodes, s_total] = path_arclength_local(path);
    gamma_path = zeros(n, 1);
    pm = compute_path_following_metrics(path, S.vp, S.vel, S.ori, ...
        S.psi_ref, S.theta_ref, dt, t);
    s = pm.s_prog(:);
    for i = 1:n
        [~, t_hat] = sample_path_local(path, s_nodes, min(s(i), s_total));
        gamma_path(i) = atan2(t_hat(3), max(norm(t_hat(1:2)), 1e-9));
    end

    % Windows
    if isfield(M, 'mask_ss') && ~isempty(M.mask_ss)
        mask_ss = M.mask_ss(:);
    else
        mask_ss = (t >= 5.0) & (s < 0.88 * s_total);
    end
    if isfield(M, 'W') && isfield(M.W, 'mask_acq')
        mask_acq = M.W.mask_acq(:);
    else
        mask_acq = (t < 5.0) | ~mask_ss;
    end
    if ~any(mask_ss); mask_ss = t >= 5.0; end
    mask_trans = ~mask_ss;

    depth_err = S.vp(:, 3) - interp_path_z(path, s_nodes, s, s_total);
    cte = pm.cte_perp_series(:);
    ez_frenet = pm.e_z_series(:);

    R = struct();
    R.name = name;
    R.path = path;
    R.S = S;
    R.M = M;
    R.is_xz = is_xz;
    R.win_mode = win_mode;
    R.t = t; R.dt = dt; R.s = s; R.s_total = s_total;
    R.vp = S.vp; R.vel = S.vel; R.rates = S.rates; R.ori = S.ori;
    R.phi = phi; R.theta_euler = theta_euler; R.theta_phys = theta_phys; R.psi = psi;
    R.psi_ref = S.psi_ref(:); R.theta_ref = S.theta_ref(:);
    R.p = p; R.q = q; R.r = r;
    R.u = u; R.v = v; R.w = w; R.U = U; R.alpha = alpha;
    R.VN = VN; R.VE = VE; R.VD = VD; R.Uh = Uh;
    R.gamma_act = gamma_act; R.gamma_path = gamma_path;
    R.gamma_body_approx = gamma_body_approx; R.resid = resid;
    R.delta_e = S.delta_e(:); R.delta_r = S.delta_r(:);
    R.cte = cte; R.ez_frenet = ez_frenet; R.depth_err = depth_err;
    R.mask_ss = mask_ss; R.mask_acq = mask_acq; R.mask_trans = mask_trans;
    R.pm = pm;
end

function C = pack_cusum(CUS)
    em = CUS.R.example_mild;
    logC = em.logC;
    C = struct();
    C.source = 'RUDDER_CUSUM_DETECTOR.mat';
    C.kappa = CUS.cusum_cfg.kappa;
    C.h = CUS.cusum_cfg.h;
    C.G_nom = CUS.cusum_cfg.G_nom;
    C.t = logC.t(:);
    C.residual = logC.residual(:);
    C.q = logC.q(:);
    C.alarm = logC.alarm(:);
    C.gated = logC.gated(:);
    C.t_fault = em.tf;
    C.t_alarm = logC.t_alarm_s;
    if isnan(C.t_alarm) || isempty(C.t_alarm)
        C.delay_s = NaN;
    else
        C.delay_s = C.t_alarm - C.t_fault;
    end
    C.latched = logical(logC.alarm_latched_final);
    C.u0 = em.u0; C.eta = em.eta; C.seed = em.seed;
    C.FA_agg_pct = CUS.FA.FA_agg_latched_pct;
    C.coverage_pass = strcmpi(CUS.R.verdict, 'PASS') || ...
        (isfield(CUS.R, 'G') && isfield(CUS.R.G, 'coverage_pass') && CUS.R.G.coverage_pass);
    if isfield(CUS.R, 'G')
        C.G = CUS.R.G;
    else
        C.G = struct();
    end
    C.equations = CUS.R.equations;
    C.summary = struct('kappa', C.kappa, 'h', C.h, 'u0', C.u0, 'eta', C.eta, ...
        't_fault', C.t_fault, 't_alarm', C.t_alarm, 'delay_s', C.delay_s, ...
        'FA_agg_pct', C.FA_agg_pct, 'latched', C.latched, ...
        'coverage_pass', C.coverage_pass);
end

%% ===================== figures =====================
function [png_path, meta] = fig_path_cte(out_dir, tag, routes, lim)
    png_path = fullfile(out_dir, [tag '_01_path_cte.png']);
    R = routes.R10; src = 'ROLL_PRODUCTION_CLOSURE.mat (candidate.SH) + PITCH_YAW pathH';
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 900]);

    subplot(2, 2, [1 3]);
    plot3(R.path(:,1), R.path(:,2), R.path(:,3), 'k--', 'LineWidth', 1.2); hold on;
    plot3(R.vp(:,1), R.vp(:,2), R.vp(:,3), 'b-', 'LineWidth', 1.0);
    grid on; axis equal; view(35, 22);
    xlabel('N x [m]'); ylabel('E y [m]'); zlabel('D z [m] (NED ↓+)');
    title(sprintf('R10 helix: ref vs actual  |  source: %s', src), 'Interpreter', 'none');
    legend({'path ref', 'actual'}, 'Location', 'best');

    subplot(2, 2, 2);
    plot(R.t, R.cte, 'b-'); hold on;
    yline(0, 'k:');
    shade_windows(R);
    grid on; xlabel('t [s]'); ylabel('CTE_{perp} [m]');
    title(sprintf('CTE time series  mean_{ss}=%.3f m', mean(R.cte(R.mask_ss))));

    subplot(2, 2, 4);
    plot(R.t, R.depth_err, 'r-', 'DisplayName', 'z-z_{path}'); hold on;
    plot(R.t, R.ez_frenet, 'm--', 'DisplayName', 'e_z Frenet');
    shade_windows(R);
    grid on; xlabel('t [s]'); ylabel('depth error [m] (NED ↓+)');
    legend('Location', 'best');
    title(sprintf('Depth error  |e_z|_{ss,mean}=%.3f m', mean(abs(R.ez_frenet(R.mask_ss)))));

    meta = panel_meta(1, 'path_cte', 'R10 helix', ...
        '3D ref/actual + CTE [m] + depth err [m]', src, ...
        sprintf('ss t>=5 & s<0.88 s_tot (win=%s)', R.win_mode), ...
        ternary(all(isfinite(R.cte)) && all(isfinite(R.vp(:))), 'PASS', 'FAIL'));
    meta.notes = sprintf('Also available: X/XZ from ROLL candidate; guidance mission=%s', ...
        'GUIDANCE_MISSION_BASELINE.mat');
    stamp_panel(fig, meta);
    export_fig(fig, png_path); close(fig);
end

function [png_path, meta] = fig_attitude(out_dir, tag, routes, lim)
    png_path = fullfile(out_dir, [tag '_02_attitude.png']);
    R = routes.R10; src = 'ROLL_PRODUCTION_CLOSURE.mat (candidate.SH)';
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 900]);

    subplot(3, 1, 1);
    plot(R.t, rad2deg(R.theta_ref), 'k--', 'LineWidth', 1.1); hold on;
    plot(R.t, rad2deg(R.theta_phys), 'b-', 'LineWidth', 1.0);
    shade_windows(R);
    grid on; ylabel('\theta [deg]');
    legend({'\theta_{ref}', '\theta_{phys}=-\theta_{Euler}'}, 'Location', 'best');
    title(sprintf('Pitch  ssMAE=%.3f deg', rad2deg(mean(abs(R.theta_ref(R.mask_ss)-R.theta_phys(R.mask_ss))))));

    subplot(3, 1, 2);
    plot(R.t, rad2deg(unwrap(R.psi_ref)), 'k--', 'LineWidth', 1.1); hold on;
    plot(R.t, rad2deg(unwrap(R.psi)), 'b-', 'LineWidth', 1.0);
    shade_windows(R);
    grid on; ylabel('\psi [deg]');
    legend({'\psi_{ref}', '\psi'}, 'Location', 'best');
    epsi = wrapToPi(R.psi_ref - R.psi);
    title(sprintf('Yaw  ssMAE=%.3f deg', rad2deg(mean(abs(epsi(R.mask_ss))))));

    subplot(3, 1, 3);
    plot(R.t, rad2deg(R.phi), 'Color', [0.1 0.5 0.2], 'LineWidth', 1.0); hold on;
    shade_windows(R);
    grid on; xlabel('t [s]'); ylabel('\phi [deg]');
    title(sprintf('Roll  ssRMS=%.3f deg', rad2deg(rms_local(R.phi(R.mask_ss)))));
    legend({'\phi'}, 'Location', 'best');

    meta = panel_meta(2, 'attitude', 'R10 helix', ...
        'theta_ref/theta_phys, psi_ref/psi, phi [deg]', src, ...
        sprintf('transient=~ss; steady=%s', R.win_mode), ...
        ternary(all(isfinite([R.theta_phys; R.psi; R.phi])), 'PASS', 'FAIL'));
    stamp_panel(fig, meta);
    export_fig(fig, png_path); close(fig);
end

function [png_path, meta] = fig_kinematics(out_dir, tag, routes, lim)
    png_path = fullfile(out_dir, [tag '_03_kinematics.png']);
    R = routes.R10; src = 'ROLL_PRODUCTION_CLOSURE.mat (candidate.SH)';
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 980]);

    % Numerical identity test on steady window
    resid_ss = R.resid(R.mask_ss);
    rms_resid = rad2deg(rms_local(resid_ss));
    mae_resid = rad2deg(mean(abs(resid_ss)));
    % Pass if residual small vs typical AoA scale (project-specific; not assumed zero)
    id_pass = isfinite(rms_resid) && (rms_resid < 1.0);  % <1 deg RMS on R10

    subplot(4, 1, 1);
    plot(R.t, R.U, 'b-'); hold on; plot(R.t, R.u, 'k--');
    shade_windows(R); grid on; ylabel('U,u [m/s]');
    legend({'U=||V_{BODY}||', 'u (BODY surge)'}, 'Location', 'best');
    title('Speed (BODY)');

    subplot(4, 1, 2);
    plot(R.t, rad2deg(R.alpha), 'm-'); hold on;
    shade_windows(R); grid on; ylabel('\alpha [deg]');
    title('\alpha = atan2(w,u)  BODY  (w↓+ with NED z↓)');

    subplot(4, 1, 3);
    plot(R.t, rad2deg(R.theta_phys), 'b-'); hold on;
    plot(R.t, rad2deg(R.gamma_act), 'r-');
    plot(R.t, rad2deg(R.gamma_path), 'k--');
    plot(R.t, rad2deg(R.gamma_body_approx), 'g:');
    shade_windows(R); grid on; ylabel('[deg]');
    legend({'\theta_{phys}', '\gamma_{act}=atan2(V_D,U_h) NED', ...
        '\gamma_{path} path slope', '\theta_{phys}+\alpha'}, 'Location', 'best');
    title('Independent \gamma constructions (do not assume identity)');

    subplot(4, 1, 4);
    plot(R.t, rad2deg(R.resid), 'Color', [0.6 0.1 0.1]); hold on;
    shade_windows(R); grid on; xlabel('t [s]'); ylabel('resid [deg]');
    yline(0, 'k:');
    title(sprintf(['Identity test: \\gamma_{act}-(\\theta_{phys}+\\alpha)  ', ...
        'ssRMS=%.3f deg ssMAE=%.3f deg  |  BODY: u,v,w; NED: V_N,V_E,V_D; ', ...
        '\\theta_{phys}=-\\theta_{Euler}'], rms_resid, mae_resid));

    meta = panel_meta(3, 'kinematics', 'R10 helix', ...
        'U, alpha=atan2(w,u), theta, gamma_act/path + identity resid [deg]', src, ...
        sprintf('steady mask; identity_ssRMS=%.3f deg', rms_resid), ...
        ternary(id_pass, 'PASS', 'FAIL'));
    meta.identity = struct('rms_deg', rms_resid, 'mae_deg', mae_resid, ...
        'equation', 'resid = gamma_act - (theta_phys + alpha)', ...
        'gamma_act', 'atan2(V_D, Uh) from R_nb''*[u;v;w]', ...
        'alpha', 'atan2(w,u) BODY', 'theta_phys', '-Euler_theta', ...
        'signs', 'NED z↓+; BODY w aligned with NED-down when level');
    stamp_panel(fig, meta);
    export_fig(fig, png_path); close(fig);
end

function [png_path, meta] = fig_actuators(out_dir, tag, routes, lim)
    png_path = fullfile(out_dir, [tag '_04_actuators.png']);
    R = routes.R10; src = 'ROLL_PRODUCTION_CLOSURE.mat (candidate.SH)';
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 1000]);
    dt = R.dt;
    de = rad2deg(R.delta_e); dr = rad2deg(R.delta_r);
    dde = [0; diff(de)] / dt; ddr = [0; diff(dr)] / dt;
    sat_e = 100 * mean(abs(R.delta_e) >= 0.98 * lim.de_max);
    sat_r = 100 * mean(abs(R.delta_r) >= 0.98 * lim.dr_max);
    sat_e_ss = 100 * mean(abs(R.delta_e(R.mask_ss)) >= 0.98 * lim.de_max);
    sat_r_ss = 100 * mean(abs(R.delta_r(R.mask_ss)) >= 0.98 * lim.dr_max);
    chat_e = chatter_dps(de, dt);
    chat_r = chatter_dps(dr, dt);
    rate_hit_e = 100 * mean(abs(dde) > lim.rate_dps * 1.01);
    rate_hit_r = 100 * mean(abs(ddr) > lim.rate_dps * 1.01);

    subplot(3, 2, 1);
    plot(R.t, de, 'b-'); hold on;
    yline(lim.de_max_deg, 'r--'); yline(-lim.de_max_deg, 'r--');
    shade_windows(R); grid on; ylabel('\delta_e [deg]');
    title(sprintf('\\delta_e  |lim|=\\pm%.0f deg  sat%% full/ss=%.2f/%.2f', ...
        lim.de_max_deg, sat_e, sat_e_ss));

    subplot(3, 2, 2);
    plot(R.t, dr, 'Color', [0.1 0.5 0.2]); hold on;
    yline(lim.dr_max_deg, 'r--'); yline(-lim.dr_max_deg, 'r--');
    shade_windows(R); grid on; ylabel('\delta_r [deg]');
    title(sprintf('\\delta_r  |lim|=\\pm%.0f deg  sat%% full/ss=%.2f/%.2f', ...
        lim.dr_max_deg, sat_r, sat_r_ss));

    subplot(3, 2, 3);
    plot(R.t, dde, 'b-'); hold on;
    yline(lim.rate_dps, 'r--'); yline(-lim.rate_dps, 'r--');
    shade_windows(R); grid on; ylabel('d\\delta_e/dt [deg/s]');
    title(sprintf('Elevator rate  lim=\\pm%.0f deg/s  over%%=%.2f  chat=%.3f', ...
        lim.rate_dps, rate_hit_e, chat_e));

    subplot(3, 2, 4);
    plot(R.t, ddr, 'Color', [0.1 0.5 0.2]); hold on;
    yline(lim.rate_dps, 'r--'); yline(-lim.rate_dps, 'r--');
    shade_windows(R); grid on; ylabel('d\\delta_r/dt [deg/s]');
    title(sprintf('Rudder rate  lim=\\pm%.0f deg/s  over%%=%.2f  chat=%.3f', ...
        lim.rate_dps, rate_hit_r, chat_r));

    subplot(3, 2, 5);
    [f_e, p_e] = simple_psd(de(R.mask_ss), dt);
    semilogy(f_e, p_e, 'b-'); hold on;
    xline(lim.f_marker, 'r--', 'LineWidth', 1.2);
    grid on; xlabel('f [Hz]'); ylabel('PSD \\delta_e');
    title(sprintf('\\delta_e PSD (ss)  marker f_{guid}=%.2f Hz (=1/dt_g)', lim.f_marker));
    xlim([0, min(20, lim.f_ctrl/2)]);

    subplot(3, 2, 6);
    [f_r, p_r] = simple_psd(dr(R.mask_ss), dt);
    semilogy(f_r, p_r, 'Color', [0.1 0.5 0.2]); hold on;
    xline(lim.f_marker, 'r--', 'LineWidth', 1.2);
    grid on; xlabel('f [Hz]'); ylabel('PSD \\delta_r');
    title(sprintf('\\delta_r PSD (ss)  marker 13.33 Hz guidance ZOH'));
    xlim([0, min(20, lim.f_ctrl/2)]);

    ok = isfinite(chat_e) && isfinite(chat_r) && all(isfinite(de)) && all(isfinite(dr));
    meta = panel_meta(4, 'actuators', 'R10 helix', ...
        sprintf(['de/dr [deg], rate lim \\pm%.0f deg/s, mag \\pm%.0f/\\pm%.0f, ', ...
        'sat%%, chatter, PSD@%.2fHz'], lim.rate_dps, lim.de_max_deg, lim.dr_max_deg, lim.f_marker), ...
        src, 'full + steady window', ternary(ok, 'PASS', 'FAIL'));
    meta.sat = struct('de_full', sat_e, 'de_ss', sat_e_ss, 'dr_full', sat_r, 'dr_ss', sat_r_ss);
    meta.chatter_dps = struct('de', chat_e, 'dr', chat_r);
    stamp_panel(fig, meta);
    export_fig(fig, png_path); close(fig);
end

function [png_path, meta] = fig_rates_roll(out_dir, tag, routes, ROLL, lim)
    png_path = fullfile(out_dir, [tag '_05_rates_roll.png']);
    R = routes.R10; Rb = routes.R10_base;
    src = 'ROLL_PRODUCTION_CLOSURE.mat (baseline.SH vs candidate.SH)';
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 900]);

    subplot(2, 2, 1);
    plot(R.t, rad2deg(R.p), 'r-'); hold on;
    plot(R.t, rad2deg(R.q), 'b-');
    plot(R.t, rad2deg(R.r), 'Color', [0.1 0.5 0.2]);
    shade_windows(R); grid on; ylabel('[deg/s]');
    legend({'p', 'q', 'r'}, 'Location', 'best');
    title('BODY rates (production roll-damp ON)');

    subplot(2, 2, 2);
    plot(Rb.t, rad2deg(Rb.p), 'k--', 'LineWidth', 1.0); hold on;
    plot(R.t, rad2deg(R.p), 'r-', 'LineWidth', 1.0);
    shade_windows(R); grid on; ylabel('p [deg/s]');
    legend({'p baseline Kp=0', sprintf('p prod Kp=%.4f', ROLL.Kp_roll)}, 'Location', 'best');
    title('Roll-rate comparison (accepted damping)');

    pRMS_b = Rb.M.p.rms_dps; pRMS_c = R.M.p.rms_dps;
    improve = 100 * (1 - pRMS_c / max(pRMS_b, eps));

    subplot(2, 2, 3);
    bar([pRMS_b, pRMS_c]);
    set(gca, 'XTickLabel', {'base Kp=0', sprintf('prod Kp=%.3f', ROLL.Kp_roll)});
    ylabel('p_{RMS} [deg/s] (ss)'); grid on;
    title(sprintf('p_{RMS}  %.3f \\rightarrow %.3f  (%.1f%%)', pRMS_b, pRMS_c, improve));

    subplot(2, 2, 4);
    % X clean check
    Rx = routes.X;
    plot(Rx.t, rad2deg(Rx.p), 'r-'); hold on;
    shade_windows(Rx); grid on; xlabel('t [s]'); ylabel('p [deg/s]');
    title(sprintf('X route p (should be quiet)  pRMS=%.3f deg/s', Rx.M.p.rms_dps));

    ok = isfinite(pRMS_b) && isfinite(pRMS_c) && (improve >= 10);
    meta = panel_meta(5, 'rates_roll', 'R10 (+X quiet check)', ...
        'p,q,r [deg/s] + p_RMS base vs accepted roll-damp', src, ...
        sprintf('ss; improve=%.1f%% (gate >=10%% from ROLL closure)', improve), ...
        ternary(ok, 'PASS', 'FAIL'));
    meta.pRMS = struct('base', pRMS_b, 'prod', pRMS_c, 'improve_pct', improve);
    stamp_panel(fig, meta);
    export_fig(fig, png_path); close(fig);
end

function [png_path, meta] = fig_cusum(out_dir, tag, cus, lim)
    png_path = fullfile(out_dir, [tag '_06_cusum_fault.png']);
    src = sprintf('RUDDER_CUSUM_DETECTOR.mat example_mild seed=%d U=%.2f eta=%.2f', ...
        cus.seed, cus.u0, cus.eta);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 900]);

    subplot(3, 1, 1);
    plot(cus.t, cus.residual, 'b-'); hold on;
    xline(cus.t_fault, 'r--', 'LineWidth', 1.2);
    grid on; ylabel('B2 residual [frac]');
    title(sprintf('B2 residual  G_{nom}=%.4f  fault@%.2fs', cus.G_nom, cus.t_fault));

    subplot(3, 1, 2);
    plot(cus.t, cus.q, 'Color', [0.6 0.1 0.1], 'LineWidth', 1.0); hold on;
    yline(cus.h, 'k--', 'LineWidth', 1.2);
    xline(cus.t_fault, 'r--', 'LineWidth', 1.2);
    if isfinite(cus.t_alarm); xline(cus.t_alarm, 'm-.', 'LineWidth', 1.2); end
    grid on; ylabel('CUSUM q [-]');
    title(sprintf('CUSUM score vs h=%.4f  \\kappa=%.4f  delay=%.3fs', ...
        cus.h, cus.kappa, cus.delay_s));

    subplot(3, 1, 3);
    plot(cus.t, double(cus.alarm), 'k-', 'LineWidth', 1.2); hold on;
    xline(cus.t_fault, 'r--', 'LineWidth', 1.2);
    ylim([-0.1 1.2]); grid on; xlabel('t [s]'); ylabel('latched alarm');
    title(sprintf(['Latched alarm=%d  FA_{agg,unseen-nom}=%.4f%% (gate\\leq1)  ', ...
        'coverage=%s'], cus.latched, cus.FA_agg_pct, ternary(cus.coverage_pass, 'PASS', 'FAIL')));

    ok = cus.coverage_pass && isfinite(cus.delay_s) && (cus.delay_s <= 3.0) && ...
        (cus.FA_agg_pct <= 1.0) && cus.latched;
    meta = panel_meta(6, 'cusum_fault', sprintf('R10 U=%.2f eta=%.2f', cus.u0, cus.eta), ...
        'B2 residual, CUSUM q/h, fault time, latch, delay, FA', src, ...
        sprintf('t_fault=%.2fs t_alarm=%.2fs delay=%.3fs', cus.t_fault, cus.t_alarm, cus.delay_s), ...
        ternary(ok, 'PASS', 'FAIL'));
    meta.cusum = cus.summary;
    stamp_panel(fig, meta);
    export_fig(fig, png_path); close(fig);
end

function [png_path, meta] = fig_overview(out_dir, tag, P, routes, cus, mission, lim, task_id, stamp)
    png_path = fullfile(out_dir, [tag '_00_overview.png']);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1200 900]);
    axis off;
    lines = {};
    lines{end+1} = sprintf('%s  —  %s', task_id, stamp);
    lines{end+1} = 'Indexed visual evidence pack (raw MAT only; no synthetic curves)';
    lines{end+1} = '';
    lines{end+1} = 'Accepted sources:';
    lines{end+1} = '  PITCH_YAW_CLOSURE.mat          production X/XZ/R10 capsule + paths';
    lines{end+1} = '  ROLL_PRODUCTION_CLOSURE.mat    accepted roll-damp base/prod full traj';
    lines{end+1} = '  GUIDANCE_MISSION_BASELINE.mat  guidance mission baseline';
    lines{end+1} = '  RUDDER_CUSUM_DETECTOR.mat      CUSUM coverage PASS artifact';
    lines{end+1} = '';
    lines{end+1} = sprintf('Limits: de±%.0f deg  dr±%.0f deg  rate±%.0f deg/s  f_ctrl=%.0f Hz  f_guid=%.2f Hz', ...
        lim.de_max_deg, lim.dr_max_deg, lim.rate_dps, lim.f_ctrl, lim.f_marker);
    lines{end+1} = sprintf('R10 pRMS base→prod: %.3f→%.3f deg/s', routes.R10_base.M.p.rms_dps, routes.R10.M.p.rms_dps);
    lines{end+1} = sprintf('CUSUM example: U=%.2f eta=%.2f delay=%.3fs FA=%.4f%%', ...
        cus.u0, cus.eta, cus.delay_s, cus.FA_agg_pct);
    lines{end+1} = sprintf('Mission audit class: %s (source GUIDANCE_MISSION_BASELINE)', ...
        char_safe(mission.verdict_audit));
    lines{end+1} = '';
    lines{end+1} = 'Panels:';
    keys = {'p1','p2','p3','p4','p5','p6'};
    for i = 1:6
        m = P.(keys{i});
        lines{end+1} = sprintf('  (%d) %-12s  %-14s  %s  [%s]', ...
            m.id, m.name, m.verdict, m.scenario, m.source_short); %#ok<AGROW>
    end
    lines{end+1} = '';
    lines{end+1} = 'Next (only if pack PASS): realism gap audit.';
    lines{end+1} = 'Production frozen. CODEX_VERTICAL_PLAN untouched. No NL rerun.';

    text(0.02, 0.98, strjoin(lines, '\n'), 'FontName', 'FixedWidth', ...
        'FontSize', 11, 'VerticalAlignment', 'top', 'Interpreter', 'none');

    meta = panel_meta(0, 'overview', 'index', 'Indexed overview of panels 1–6', ...
        'all accepted MATs', 'n/a', 'PASS');
    stamp_panel(fig, meta);
    export_fig(fig, png_path); close(fig);
end

%% ===================== helpers =====================
function meta = panel_meta(id, name, scenario, units, source, window, verdict)
    meta = struct();
    meta.id = id;
    meta.name = name;
    meta.scenario = scenario;
    meta.units = units;
    meta.source = source;
    meta.source_short = short_src(source);
    meta.window = window;
    meta.verdict = verdict;
end

function stamp_panel(fig, meta)
    annotation(fig, 'textbox', [0.01 0.005 0.98 0.04], ...
        'String', sprintf('P%d %s | scenario=%s | units=%s | source=%s | window=%s | %s', ...
        meta.id, meta.name, meta.scenario, meta.units, meta.source_short, meta.window, meta.verdict), ...
        'EdgeColor', 'none', 'FontSize', 8, 'FontName', 'FixedWidth', ...
        'Interpreter', 'none', 'VerticalAlignment', 'bottom');
end

function s = short_src(src)
    [~, name, ext] = fileparts(strtok(src, ' '));
    if isempty(name)
        s = src;
    else
        s = [name ext];
        if contains(src, '(')
            s = src; % keep detail
            if numel(s) > 60; s = [s(1:57) '...']; end
        end
    end
end

function shade_windows(R)
    ax = gca;
    yl = ax.YLim;
    if ~(isfinite(yl(1)) && isfinite(yl(2))) || yl(1) == yl(2)
        yl = [-1 1];
    end
    hold(ax, 'on');
    if any(R.mask_trans)
        t0 = R.t(find(R.mask_trans, 1, 'first'));
        t1 = R.t(find(R.mask_trans, 1, 'last'));
        patch(ax, [t0 t1 t1 t0], [yl(1) yl(1) yl(2) yl(2)], [1 0.95 0.85], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.25, 'HandleVisibility', 'off');
    end
    if any(R.mask_ss)
        t0 = R.t(find(R.mask_ss, 1, 'first'));
        t1 = R.t(find(R.mask_ss, 1, 'last'));
        patch(ax, [t0 t1 t1 t0], [yl(1) yl(1) yl(2) yl(2)], [0.85 0.95 1], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.20, 'HandleVisibility', 'off');
    end
    ax.YLim = yl;
    try
        uistack(findobj(ax, 'Type', 'patch'), 'bottom');
    catch
    end
end

function export_fig(fig, png_path)
    set(fig, 'PaperPositionMode', 'auto');
    print(fig, png_path, '-dpng', '-r150');
end

function [f, pxx] = simple_psd(x, dt)
    x = x(:) - mean(x(:), 'omitnan');
    x(~isfinite(x)) = 0;
    n = numel(x);
    if n < 16
        f = 0; pxx = 1; return;
    end
    nfft = 2^nextpow2(n);
    % Manual Hann (no Signal Processing Toolbox dependency)
    win = 0.5 - 0.5 * cos(2 * pi * (0:n-1)' / max(n-1, 1));
    X = fft(x .* win, nfft);
    pxx = abs(X(1:floor(nfft/2)+1)).^2 / (sum(win.^2) / dt);
    f = (0:floor(nfft/2))' / (nfft * dt);
    pxx = max(pxx, realmin);
end

function c = chatter_dps(x_deg, dt)
    dx = [0; diff(x_deg(:))] / dt;
    n = max(3, round(0.8 / dt));
    lf = filter(ones(n, 1) / n, 1, detrend(dx));
    hf = dx - lf;
    hf(1:min(n, numel(hf))) = 0;
    c = std(hf);
end

function C = eul_ned_to_body(phi, theta, psi)
    % Rotation BODY←NED (standard aerospace ZYX)
    cph = cos(phi); sph = sin(phi);
    cth = cos(theta); sth = sin(theta);
    cps = cos(psi); sps = sin(psi);
    C = [ cth*cps,            cth*sps,           -sth; ...
          sph*sth*cps-cph*sps, sph*sth*sps+cph*cps, sph*cth; ...
          cph*sth*cps+sph*sps, cph*sth*sps-sph*cps, cph*cth ];
end

function [s_nodes, s_total] = path_arclength_local(path)
    d = vecnorm(diff(path), 2, 2);
    s_nodes = [0; cumsum(d)];
    s_total = s_nodes(end);
end

function [p, t_hat] = sample_path_local(path, s_nodes, s)
    s = max(0, min(s, s_nodes(end)));
    i = find(s_nodes <= s, 1, 'last');
    if i >= numel(s_nodes)
        p = path(end, :);
        t_hat = path(end, :) - path(end-1, :);
    else
        ds = s_nodes(i+1) - s_nodes(i);
        a = 0; if ds > 0; a = (s - s_nodes(i)) / ds; end
        p = (1 - a) * path(i, :) + a * path(i+1, :);
        t_hat = path(i+1, :) - path(i, :);
    end
    nrm = norm(t_hat);
    if nrm < 1e-12; t_hat = [1 0 0]; else; t_hat = t_hat / nrm; end
end

function z = interp_path_z(path, s_nodes, s, s_total)
    z = zeros(size(s));
    for i = 1:numel(s)
        [p, ~] = sample_path_local(path, s_nodes, min(max(s(i), 0), s_total));
        z(i) = p(3);
    end
end

function y = rms_local(x)
    x = x(isfinite(x));
    if isempty(x); y = NaN; else; y = sqrt(mean(x.^2)); end
end

function s = ternary(tf, a, b)
    if tf; s = a; else; s = b; end
end

function s = char_safe(v)
    if ischar(v) || isstring(v)
        s = char(v);
    elseif isstruct(v) && isfield(v, 'verdict')
        s = char_safe(v.verdict);
    elseif isstruct(v) && isfield(v, 'mission_class')
        s = char_safe(v.mission_class);
    else
        try; s = char(string(v)); catch; s = 'n/a'; end
    end
end

function write_md(md_path, Results, P, png, provenance)
    fid = fopen(md_path, 'w');
    assert(fid > 0);
    fprintf(fid, '# %s\n\n', Results.task_id);
    fprintf(fid, '**Date:** %s  \n', Results.stamp);
    fprintf(fid, '**Pack verdict:** **%s**  \n', Results.verdict);
    fprintf(fid, '**Panels PASS/FAIL/NA:** %d/%d/%d  \n\n', Results.n_pass, Results.n_fail, Results.n_na);

    fprintf(fid, '## Provenance (research-log resolved)\n\n');
    fprintf(fid, '| Role | Artifact |\n|------|----------|\n');
    fprintf(fid, '| Research log | `%s` |\n', provenance.research_log);
    fprintf(fid, '| Production X/XZ/R10 | `%s` |\n', provenance.production_xyz_r10);
    fprintf(fid, '| Accepted roll damping | `%s` |\n', provenance.roll_damping);
    fprintf(fid, '| Guidance mission | `%s` |\n', provenance.guidance_mission);
    fprintf(fid, '| CUSUM fault validation | `%s` |\n', provenance.cusum);
    fprintf(fid, '\n%s\n\n', provenance.roll_note);
    fprintf(fid, '- Nonlinear rerun: **NO**  \n');
    fprintf(fid, '- Production edited: **NO**  \n');
    fprintf(fid, '- CODEX_VERTICAL_PLAN: **untouched**  \n\n');

    fprintf(fid, '## Panel index\n\n');
    fprintf(fid, '| # | Name | Scenario | Units | Source | Window | Verdict | PNG |\n');
    fprintf(fid, '|---|------|----------|-------|--------|--------|---------|-----|\n');
    keys = {'p1','p2','p3','p4','p5','p6'};
    for i = 1:6
        m = P.(keys{i});
        fprintf(fid, '| %d | %s | %s | %s | `%s` | %s | **%s** | `%s` |\n', ...
            m.id, m.name, m.scenario, m.units, m.source_short, m.window, m.verdict, png.(keys{i}));
    end
    fprintf(fid, '\nOverview: `%s`\n\n', png.overview);

    fprintf(fid, '## Highlights\n\n');
    if isfield(P.p3, 'identity')
        fprintf(fid, '- Kinematic identity resid ssRMS=**%.3f** deg (eq: `%s`)\n', ...
            P.p3.identity.rms_deg, P.p3.identity.equation);
    end
    fprintf(fid, '- Roll damp pRMS R10: %.4f → %.4f deg/s (%.1f%%)\n', ...
        Results.roll.pRMS_base_H, Results.roll.pRMS_prod_H, Results.roll.pRMS_improve_pct);
    fprintf(fid, '- CUSUM example: U=%.2f η=%.2f delay=%.3fs FA_agg=%.4f%% latched=%d\n', ...
        Results.cusum.u0, Results.cusum.eta, Results.cusum.delay_s, ...
        Results.cusum.FA_agg_pct, Results.cusum.latched);
    fprintf(fid, '- BODY/NED: θ_phys=-θ_Euler; α=atan2(w,u) BODY; γ_act=atan2(V_D,U_h) from R''[u;v;w]\n\n');

    fprintf(fid, '## Frame / sign documentation\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'NED: x North, y East, z Down (+)\n');
    fprintf(fid, 'BODY: u surge, v sway, w heave (w + when level aligns NED-down)\n');
    fprintf(fid, 'theta_phys = -Euler_theta\n');
    fprintf(fid, 'alpha      = atan2(w, u)                         [BODY]\n');
    fprintf(fid, 'V_NED      = R_bn'' * [u;v;w]\n');
    fprintf(fid, 'gamma_act  = atan2(V_D, hypot(V_N,V_E))           [NED]\n');
    fprintf(fid, 'gamma_path = atan2(t_hat_z, ||t_hat_xy||)         [path]\n');
    fprintf(fid, 'resid      = gamma_act - (theta_phys + alpha)     [tested, not assumed]\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Actuator limits (exact)\n\n');
    fprintf(fid, '| Channel | Magnitude | Rate |\n|---------|-----------|------|\n');
    fprintf(fid, '| δe | ±15 deg | ±40 deg/s |\n');
    fprintf(fid, '| δr | ±25 deg | ±40 deg/s |\n');
    fprintf(fid, '| PSD marker | — | 13.33 Hz = 1/dt_guidance |\n\n');

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '%s\n', Results.next);
    fclose(fid);
end

function append_log(out_dir, Results)
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    fid = fopen(log_path, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n## %s — %s\n\n', Results.task_id, Results.stamp);
    fprintf(fid, '- Pack: **%s** — panels PASS/FAIL/NA=%d/%d/%d; raw-MAT evidence only; no NL rerun; production frozen.\n', ...
        Results.verdict, Results.n_pass, Results.n_fail, Results.n_na);
    fprintf(fid, '- Sources: PITCH_YAW_CLOSURE.mat (prod X/XZ/R10 paths); ROLL_PRODUCTION_CLOSURE.mat (accepted roll-damp full traj; not previously indexed in this log); GUIDANCE_MISSION_BASELINE.mat; RUDDER_CUSUM_DETECTOR.mat (Coverage PASS).\n');
    fprintf(fid, '- Panels: (1) 3D path+CTE/depth (2) θ/ψ/φ windows (3) U/α/θ/γ + identity resid (4) δe/δr limits/sat/PSD@13.33Hz (5) pqr + pRMS roll-damp (6) B2/CUSUM/latch/FA.\n');
    fprintf(fid, '- Roll pRMS R10: %.4f→%.4f (%.1f%%); CUSUM ex U=%.2f η=%.2f delay=%.3fs FA=%.4f%%.\n', ...
        Results.roll.pRMS_base_H, Results.roll.pRMS_prod_H, Results.roll.pRMS_improve_pct, ...
        Results.cusum.u0, Results.cusum.eta, Results.cusum.delay_s, Results.cusum.FA_agg_pct);
    fprintf(fid, '- Artifacts: suite_results/AUV_VISUAL_EVIDENCE_PACK.{md,mat,png} + _00_overview + _01.._06_*.png; driver `run_auv_visual_evidence_pack.m`.\n');
    fprintf(fid, '- Next: **`realism_gap_audit`** — only after pack PASS.\n');
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end
