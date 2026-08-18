function run_rudder_residual_detector_feasibility()
% RUDDER_RESIDUAL_DETECTOR_FEASIBILITY_001 — offline residual-detector study.
% Sources ONLY (max 3): suite_results/RUDDER_FAULT_BASELINE.mat,
%   suite_results/HELIX_R10_YAW_PITCH_ENVELOPE.mat,
%   suite_results/STATE_SPACE_MODEL_AUDIT.md (realistic sensor definition).
% No new nonlinear run. Production cascade+guidance+plant FROZEN.
%
% (A) Direct cmd−applied residual — HARDWARE-DEPENDENT (rudder position /
%     effectiveness feedback). Forbidden as sensor-only result.
% (B) Implementable current-stack residual(s): known δr_cmd + realistic
%     IMU/DVL/depth/heading/INS signals (CTRL_OBS / SENSOR_NOISE audit set).
%     Never uses applied-rudder truth or fault labels inside residual B.
%
% Thresholds calibrated on NOMINAL data only, then FROZEN before fault eval.
% PASS sensor-only feasibility iff B detects within 3 s after t_fault with
%   ≤1% nominal false alarms and no data leakage.
% Terminology: prior RUDDER_FAULT_BASELINE reached fixed T_final at 56.7%
%   path progress → fixed-horizon survivability (NOT mission-goal completion).
% Artifacts: suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.{md,mat,png}
% Appends suite_results/PITCH_CONTROL_RESEARCH_LOG.md
% Does NOT touch CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'RUDDER_RESIDUAL_DETECTOR_FEASIBILITY';
    task_id = 'RUDDER_RESIDUAL_DETECTOR_FEASIBILITY_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    fault_mat = fullfile(out_dir, 'RUDDER_FAULT_BASELINE.mat');
    nom_mat   = fullfile(out_dir, 'HELIX_R10_YAW_PITCH_ENVELOPE.mat');
    audit_md  = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    assert(exist(fault_mat, 'file') == 2, 'Missing %s', fault_mat);
    assert(exist(nom_mat, 'file') == 2, 'Missing %s', nom_mat);
    assert(exist(audit_md, 'file') == 2, 'Missing %s', audit_md);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Offline residual feasibility; no nonlinear rerun; production frozen.\n');

    Fault = load(fault_mat);
    Nom   = load(nom_mat);
    sens  = parse_sensor_definition(audit_md);

    SF = Fault.S;
    SN = Nom.S;
    MF = Fault.M;
    assert(isfield(SF, 't_fault_s') && ~isnan(SF.t_fault_s), 'Missing t_fault');
    t_fault = SF.t_fault_s;
    dt = SF.dt;
    assert(abs(dt - SN.dt) < 1e-12, 'dt mismatch fault vs nominal');

    % ----- Extract trajectories -----
    TF = extract_traj(SF, true);
    TN = extract_traj(SN, false);

    % =====================================================================
    % CALIBRATION ON NOMINAL ONLY (frozen before fault evaluation)
    % =====================================================================
    cal = struct();
    cal.t_warmup_s = 5.0;
    cal.eps_dr_rad = deg2rad(1.0);          % gate |δr_cmd|
    cal.u_floor = 0.3;                       % m/s
    cal.pctl = 99.0;                         % raw exceedance target ~1%
    cal.persist_s = 0.25;                    % persistence
    cal.Np = max(1, round(cal.persist_s / dt));
    cal.phi_grid_n = 400;
    cal.tpl_smooth = 5;
    cal.mask_N = TN.t > cal.t_warmup_s;
    cal.gate_N = cal.mask_N & (abs(TN.dr_cmd) > cal.eps_dr_rad);

    % Phase key: INS absolute xy → helix geometric phase (CTRL_OBS case C)
    phi_grid = linspace(min(TN.phi_ins), max(TN.phi_ins), cal.phi_grid_n)';
    dr_raw = interp1(TN.phi_ins, TN.dr_cmd, phi_grid, 'linear');
    cal.dr_tpl = movmean(dr_raw, cal.tpl_smooth);
    cal.phi_grid = phi_grid;

    % Nominal yaw-rate / (u^2 δr) gain (rudder effectiveness proxy)
    gN = TN.r ./ (max(TN.u, cal.u_floor).^2 .* TN.dr_cmd);
    cal.G_nom = median(gN(cal.gate_N));

    % Nominal residuals for threshold selection
    eN = compute_residuals_B(TN, cal);
    % A on nominal: app≡cmd ⇒ residual ≡ 0 (healthy actuator feedback)
    eA_N = abs(rad2deg(TN.dr_cmd - TN.dr_app));

    thr = struct();
    thr.B1_cmd_phase_deg = prctile(eN.B1(cal.mask_N), cal.pctl);
    thr.B2_frac_loss     = prctile(eN.B2(cal.gate_N), cal.pctl);
    thr.A_cmd_app_deg    = 0.25;   % hardware floor; nominal ≡ 0
    thr.frozen = true;
    thr.note = ['All B thresholds from HELIX_R10 nominal only; ', ...
        'frozen before any fault residual evaluation.'];

    % Nominal FA (persisted detector rate) — must use frozen thr only
    detN = detect_from_residuals(eN, cal.mask_N, cal.gate_N, thr, cal.Np);
    FA = struct();
    FA.B1_raw_pct = 100 * mean(eN.B1(cal.mask_N) > thr.B1_cmd_phase_deg);
    FA.B2_raw_pct = 100 * mean(eN.B2(cal.gate_N) > thr.B2_frac_loss);
    FA.B1_persist_pct = 100 * mean(detN.B1(cal.mask_N));
    FA.B2_persist_pct = 100 * mean(detN.B2(cal.gate_N));
    FA.B_or_persist_pct = 100 * mean(detN.B_or(cal.mask_N));
    FA.A_persist_pct = 0.0;  % by construction on nominal (app=cmd)
    FA.limit_pct = 1.0;

    % =====================================================================
    % FAULT EVALUATION (thresholds frozen; B never sees app / fault labels)
    % =====================================================================
    eF = compute_residuals_B(TF, cal);   % no SF.delta_r_app / eta / fault flags
    eA_F = abs(rad2deg(TF.dr_cmd - TF.dr_app));  % A only (hardware path)

    mask_F = TF.t > cal.t_warmup_s;
    gate_F = mask_F & (abs(TF.dr_cmd) > cal.eps_dr_rad);
    detF = detect_from_residuals(eF, mask_F, gate_F, thr, cal.Np);
    detA_F = persist_on(eA_F > thr.A_cmd_app_deg, cal.Np);

    % Scoring may use t_fault / labels; detector B itself did not
    score = struct();
    score.t_fault_s = t_fault;
    score.delay_limit_s = 3.0;
    score.A = score_channel(detA_F, TF.t, t_fault, eA_F);
    score.B1 = score_channel(detF.B1, TF.t, t_fault, eF.B1);
    score.B2 = score_channel(detF.B2, TF.t, t_fault, eF.B2);
    score.B  = score_channel(detF.B_or, TF.t, t_fault, max(eF.B1, eF.B2));
    score.missed_A = isinf(score.A.delay_s);
    score.missed_B = isinf(score.B.delay_s);
    score.leakage_B = false;  % enforced by construction (no app/labels in B)

    % Gates
    G = struct();
    G.g_A_detect_3s = ~score.missed_A && (score.A.delay_s <= score.delay_limit_s);
    G.g_B_detect_3s = ~score.missed_B && (score.B.delay_s <= score.delay_limit_s);
    G.g_B_FA_le_1pct = (FA.B_or_persist_pct <= FA.limit_pct);
    G.g_no_leakage = ~score.leakage_B;
    G.A_hardware_pass = G.g_A_detect_3s;   % not sensor-only
    G.B_sensor_only_pass = G.g_B_detect_3s && G.g_B_FA_le_1pct && G.g_no_leakage;
    G.sensor_only_feasibility = tern(G.B_sensor_only_pass, 'PASS', 'FAIL');
    if G.B_sensor_only_pass
        G.next_priority = 'isolated_online_rudder_residual_monitor';
        G.next_note = ['B PASS → next: isolated online monitor scaffold only; ', ...
            'production still frozen; do not promote yet.'];
    else
        G.next_priority = 'require_actuator_feedback_OR_richer_ID';
        G.next_note = ['B FAIL → sensor-only residual not feasible under this ', ...
            'single-trajectory evidence; require rudder position/effectiveness ', ...
            'feedback and/or richer system ID before FDI.'];
    end

    % Prior-run terminology correction
    prior = struct();
    prior.source = 'suite_results/RUDDER_FAULT_BASELINE.mat';
    prior.T_final = SF.T_final;
    prior.progress_frac = MF.mission.progress_frac;
    prior.completed_to_T_final = MF.mission.completed_T;
    prior.correct_term = 'fixed_horizon_survivability';
    prior.incorrect_term = 'mission_goal_completion';
    prior.note = sprintf([ ...
        'Prior run reached fixed T_final=%.0fs but only %.1f%% path progress ', ...
        '(s_final/s_total). Call this fixed-horizon survivability, NOT ', ...
        'mission-goal completion.'], prior.T_final, 100 * prior.progress_frac);

    % Equations / provenance package
    eq = equations_package(cal, thr, sens);

    % Robustness / limitations
    lim = struct();
    lim.single_trajectory = true;
    lim.single_fault_case = 'eta_r: 1→0.50 at mid-first-turn on R10@U=1.5 only';
    lim.sensor_noise = ['Production sensor noise/delay NOT_IMPLEMENTED ', ...
        '(STATE_SPACE_MODEL_AUDIT SENSOR_NOISE_CURRENT_AUDIT). Residuals use ', ...
        'ASSUMED-direct plant truth mapped to IMU/DVL/depth/heading/INS. ', ...
        'Noise robustness NOT certified.'];
    lim.phase_alignment = ['Helix phase from INS xy (atan2); template is ', ...
        'trajectory-specific. Other paths/speeds/currents untested.'];
    lim.closed_loop_masking = ['Tracking errors stay small post-fault (controller ', ...
        'raises δr_cmd). B1 exploits demand inflation; B2 exploits gain drop ', ...
        'r/(u^2 δr_cmd). Pure yaw-error residual alone is weak.'];
    lim.A_forbidden_as_sensor_only = true;

    % Bundle
    R = struct();
    R.task_id = task_id;
    R.stamp = stamp;
    R.tag = tag;
    R.sources = {fault_mat, nom_mat, audit_md};
    R.sensor = sens;
    R.cal = cal;
    R.thr = thr;
    R.FA = FA;
    R.score = score;
    R.G = G;
    R.prior_terminology = prior;
    R.equations = eq;
    R.limitations = lim;
    R.eN = eN;
    R.eF = eF;
    R.eA_N = eA_N;
    R.eA_F = eA_F;
    R.detN = detN;
    R.detF = detF;
    R.detA_F = detA_F;
    R.TF = TF;
    R.TN = TN;
    R.verdict_A = tern(G.A_hardware_pass, 'PASS_HARDWARE', 'FAIL');
    R.verdict_B = G.sensor_only_feasibility;
    R.verdict = G.sensor_only_feasibility;

    write_png(out_dir, tag, task_id, R);
    write_md(out_dir, tag, task_id, stamp, R);
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'R', 'G', 'thr', 'FA', 'score', 'prior', 'sens', 'eq', 'lim', '-v7.3');
    append_research_log(out_dir, tag, task_id, stamp, R);

    fprintf(['A=%s (hardware) | B_sensor_only=%s | FA_B=%.3f%% | ', ...
        'delay_A=%.3fs delay_B=%.3fs | next=%s\n'], ...
        R.verdict_A, R.verdict_B, FA.B_or_persist_pct, ...
        score.A.delay_s, score.B.delay_s, G.next_priority);
    fprintf('Wrote suite_results/%s.{md,mat,png} + research log append\n', tag);
end

%% ===================== extract / residuals =====================
function T = extract_traj(S, is_fault)
    T = struct();
    T.t = S.t(:);
    T.dt = S.dt;
    T.vp = S.vp;
    T.u = S.vel(:, 1);
    T.v = S.vel(:, 2);
    T.w = S.vel(:, 3);
    T.p = S.rates(:, 1);
    T.q = S.rates(:, 2);
    T.r = S.rates(:, 3);
    T.phi = S.ori(:, 1);
    T.theta = S.ori(:, 2);
    T.psi = S.ori(:, 3);
    T.z = S.vp(:, 3);
    % INS helix phase from absolute xy (realistic stack case C)
    T.phi_ins = unwrap(atan2(S.vp(:, 2), S.vp(:, 1)));
    if is_fault
        T.dr_cmd = S.delta_r_cmd(:);
        T.dr_app = S.delta_r_app(:);   % A only / scoring; NEVER fed to residual B
        T.eta_r = S.eta_r(:);          % label; NEVER fed to residual B
    else
        T.dr_cmd = S.delta_r(:);
        T.dr_app = S.delta_r(:);       % healthy: app≡cmd
        T.eta_r = ones(size(T.t));
    end
    T.is_fault = is_fault;
end

function e = compute_residuals_B(T, cal)
% Sensor-only residuals. Uses: known δr_cmd, IMU r, DVL u, INS xy phase.
% FORBIDDEN inputs: delta_r_app, eta_r, fault_active, t_fault.
    u = max(T.u, cal.u_floor);
    dr_nom = interp1(cal.phi_grid, cal.dr_tpl, T.phi_ins, 'linear', 'extrap');
    e = struct();
    % B1: phase-aligned command demand residual [deg]
    e.B1 = abs(rad2deg(T.dr_cmd - dr_nom));
    % B2: fractional effectiveness-loss proxy from yaw-rate vs command
    %     η_hat = r / (u^2 δr_cmd) / G_nom ;  e = max(0, 1 - η_hat)
    g = T.r ./ (u.^2 .* T.dr_cmd);
    e.B2 = max(0, 1 - g ./ cal.G_nom);
    e.B2(~isfinite(e.B2)) = 0;
    e.signals_used = {'delta_r_cmd(known)', 'r(IMU)', 'u(DVL)', 'phi_ins=atan2(y,x)(INS)'};
    e.forbidden_used = {};  % enforced
end

function det = detect_from_residuals(e, mask, gate, thr, Np)
    det = struct();
    det.B1 = persist_on((e.B1 > thr.B1_cmd_phase_deg) & mask, Np);
    det.B2 = persist_on((e.B2 > thr.B2_frac_loss) & gate, Np);
    det.B_or = det.B1 | det.B2;
end

function d = persist_on(above, Np)
    d = false(size(above));
    c = 0;
    for i = 1:numel(above)
        if above(i)
            c = c + 1;
        else
            c = 0;
        end
        if c >= Np
            d(i) = true;
        end
    end
end

function s = score_channel(det, t, t_fault, e)
    s = struct();
    ii = find(det & (t >= t_fault), 1);
    if isempty(ii)
        s.detected = false;
        s.delay_s = Inf;
        s.t_detect_s = NaN;
    else
        s.detected = true;
        s.delay_s = t(ii) - t_fault;
        s.t_detect_s = t(ii);
    end
    post = t >= t_fault;
    if any(post)
        s.post_median = median(e(post));
        s.post_p95 = prctile(e(post), 95);
    else
        s.post_median = NaN;
        s.post_p95 = NaN;
    end
end

%% ===================== sensor definition from audit =====================
function sens = parse_sensor_definition(audit_md)
% Realistic sensor stack as documented in STATE_SPACE_MODEL_AUDIT.md
% (CTRL_OBS_AUDIT + SENSOR_NOISE_CURRENT_AUDIT). Read-only text parse.
    txt = fileread(audit_md);
    sens = struct();
    sens.source = 'suite_results/STATE_SPACE_MODEL_AUDIT.md';
    sens.refs = {'CTRL_OBS_AUDIT_001', 'SENSOR_NOISE_CURRENT_AUDIT_001'};
    sens.y_B = {'z','phi','theta','psi','u','v','w','p','q','r'};
    sens.y_B_note = ['IMU+DVL+depth+heading assumed direct; no absolute x,y ', ...
        '(CTRL_OBS case B)'];
    sens.y_C = {'x','y','z','phi','theta','psi','u','v','w','p','q','r'};
    sens.y_C_note = 'B + INS absolute x,y (CTRL_OBS case C)';
    sens.production = ['Production feeds plant truth; realistic sensors ASSUMED ', ...
        'only; sensor noise/delay NOT_IMPLEMENTED'];
    sens.used_in_B = struct( ...
        'delta_r_cmd', 'known controller command (not a sensor)', ...
        'r', 'IMU body yaw-rate (y_B)', ...
        'u', 'DVL surge (y_B)', ...
        'phi_ins', 'INS absolute xy → atan2(y,x) helix phase (y_C)', ...
        'optional_unused', 'depth z / heading psi / DVL v,w available but unused here');
    sens.noise_status = 'NOT_IMPLEMENTED in production stack (audit)';
    % Confirm audit mentions the realistic set
    sens.audit_mentions_IMU_DVL = contains(txt, 'IMU+DVL+depth+heading');
    sens.audit_mentions_yB = contains(txt, 'Conceptual y = [z phi theta psi u v w p q r]');
    sens.audit_noise_not_impl = contains(txt, 'Sensor noise / delay / IMU-DVL');
end

function eq = equations_package(cal, thr, sens)
    eq = struct();
    eq.A = { ...
        'r_A(t) = |δr_cmd(t) − δr_app(t)|  [rad→deg]', ...
        'Requires rudder position or effectiveness feedback (hardware).', ...
        'FORBIDDEN as sensor-only feasibility evidence.'};
    eq.B1 = { ...
        'φ(t) = unwrap(atan2(y_INS(t), x_INS(t)))', ...
        'δr_nom(φ) = smooth template from nominal HELIX_R10 only', ...
        'r_B1(t) = |δr_cmd(t) − δr_nom(φ(t))|  [deg]'};
    eq.B2 = { ...
        'G_nom = median[ r_nom / (u_nom^2 · δr_cmd_nom) ]  on gated nominal', ...
        'ĝ(t) = r_IMU(t) / (max(u_DVL,u_floor)^2 · δr_cmd(t))', ...
        'r_B2(t) = max(0, 1 − ĝ(t)/G_nom)   % fractional effectiveness-loss proxy'};
    eq.detector = sprintf([ ...
        'alarm if residual > thr for Np=%d samples (persist=%.2fs); ', ...
        'B = B1 OR B2; thr from nominal pctl=%.1f only.'], ...
        cal.Np, cal.persist_s, cal.pctl);
    eq.scaling = sprintf([ ...
        'angles deg for B1/A; B2 dimensionless; u_floor=%.2f m/s; ', ...
        '|δr|_gate=%.1f deg; warmup t>%.1fs; G_nom frozen=%.4f 1/(m^2·rad)'], ...
        cal.u_floor, rad2deg(cal.eps_dr_rad), cal.t_warmup_s, cal.G_nom);
    eq.thresholds = thr;
    eq.sensor = sens;
end

%% ===================== artifacts =====================
function write_png(out_dir, tag, task_id, R)
    fig = figure('Visible', 'off', 'Position', [80 80 1280 900]);
    tF = R.TF.t; tN = R.TN.t; tf = R.score.t_fault_s;

    subplot(3, 2, 1);
    plot(tF, rad2deg(R.TF.dr_cmd), 'b'); hold on;
    plot(tF, rad2deg(R.TF.dr_app), 'r--');
    xline(tf, 'k-');
    grid on; ylabel('deg');
    title(sprintf('A inputs (hardware) | delay=%.2fs', R.score.A.delay_s));
    legend('\delta_r^{cmd}', '\delta_r^{app}', 'Location', 'best');

    subplot(3, 2, 2);
    plot(tF, R.eA_F, 'm'); hold on;
    yline(R.thr.A_cmd_app_deg, 'k--');
    xline(tf, 'k-');
    grid on; ylabel('deg');
    title(sprintf('A: |cmd-app|  FA_{nom}=%.2f%% (not sensor-only)', R.FA.A_persist_pct));

    subplot(3, 2, 3);
    plot(tN, R.eN.B1, 'Color', [0.6 0.6 0.6]); hold on;
    plot(tF, R.eF.B1, 'b');
    yline(R.thr.B1_cmd_phase_deg, 'k--');
    xline(tf, 'k-');
    grid on; ylabel('deg');
    title(sprintf('B1 phase-cmd resid | thr=%.2f° FA=%.2f%% dly=%.2fs', ...
        R.thr.B1_cmd_phase_deg, R.FA.B1_persist_pct, R.score.B1.delay_s));
    legend('nom', 'fault', 'Location', 'best');

    subplot(3, 2, 4);
    plot(tN, R.eN.B2, 'Color', [0.6 0.6 0.6]); hold on;
    plot(tF, R.eF.B2, 'b');
    yline(R.thr.B2_frac_loss, 'k--');
    xline(tf, 'k-');
    grid on; ylabel('frac');
    title(sprintf('B2 frac loss proxy | thr=%.3f FA=%.2f%% dly=%.2fs', ...
        R.thr.B2_frac_loss, R.FA.B2_persist_pct, R.score.B2.delay_s));
    legend('nom', 'fault', 'Location', 'best');

    subplot(3, 2, 5);
    plot(tF, double(R.detF.B_or), 'b'); hold on;
    plot(tF, double(R.detA_F) * 0.9, 'm--');
    xline(tf, 'k-');
    ylim([-0.05 1.15]); grid on; ylabel('alarm');
    title(sprintf('Detectors | B=%s A_{hw}=%s', R.verdict_B, R.verdict_A));
    legend('B (OR)', 'A (hw)', 'Location', 'best');

    subplot(3, 2, 6);
    axis off;
    txt = { ...
        sprintf('%s', task_id), ...
        sprintf('B sensor-only: %s', R.verdict_B), ...
        sprintf('A hardware: %s', R.verdict_A), ...
        sprintf('FA_B persist: %.3f%% (limit 1%%)', R.FA.B_or_persist_pct), ...
        sprintf('delay_B: %.3f s (limit 3 s)', R.score.B.delay_s), ...
        sprintf('delay_A: %.3f s', R.score.A.delay_s), ...
        sprintf('leakage_B: %s', tern(R.score.leakage_B, 'YES', 'NO')), ...
        'Prior: fixed-horizon survivability', ...
        sprintf('  (T_final ok, progress=%.1f%%)', 100 * R.prior_terminology.progress_frac), ...
        sprintf('Next: %s', R.G.next_priority)};
    text(0.02, 0.98, txt, 'VerticalAlignment', 'top', 'FontName', 'FixedWidth', 'FontSize', 10);

    sgtitle(sprintf('%s | B=%s (sensor-only)', tag, R.verdict_B), 'Interpreter', 'none');
    exportgraphics(fig, fullfile(out_dir, [tag '.png']), 'Resolution', 150);
    close(fig);
end

function write_md(out_dir, tag, task_id, stamp, R)
    md = fullfile(out_dir, [tag '.md']);
    fid = fopen(md, 'w');
    fprintf(fid, '# %s\n\n', tag);
    fprintf(fid, '**TASK_ID:** %s\n', task_id);
    fprintf(fid, '**Date:** %s\n', stamp);
    fprintf(fid, '**Sensor-only feasibility (B):** **%s**\n', R.verdict_B);
    fprintf(fid, '**Hardware residual (A):** **%s** (not sensor-only)\n\n', R.verdict_A);

    fprintf(fid, 'Offline study only. No new nonlinear run. Production cascade+guidance+plant **frozen**.\n\n');

    fprintf(fid, '## Sources (3 only)\n\n');
    fprintf(fid, '1. `suite_results/RUDDER_FAULT_BASELINE.mat`\n');
    fprintf(fid, '2. `suite_results/HELIX_R10_YAW_PITCH_ENVELOPE.mat`\n');
    fprintf(fid, '3. `suite_results/STATE_SPACE_MODEL_AUDIT.md` (realistic sensor definition)\n\n');

    fprintf(fid, '## Terminology correction (prior run)\n\n');
    fprintf(fid, '- Prior `RUDDER_FAULT_BASELINE` reached fixed `T_final=%.0f` s with path progress **%.1f%%**.\n', ...
        R.prior_terminology.T_final, 100 * R.prior_terminology.progress_frac);
    fprintf(fid, '- Correct term: **fixed-horizon survivability**.\n');
    fprintf(fid, '- Incorrect term (avoid): mission-goal completion.\n');
    fprintf(fid, '- %s\n\n', R.prior_terminology.note);

    fprintf(fid, '## Realistic sensor stack (from audit)\n\n');
    fprintf(fid, '- Refs: %s / %s\n', R.sensor.refs{1}, R.sensor.refs{2});
    fprintf(fid, '- y_B (IMU+DVL+depth+heading): `[z φ θ ψ u v w p q r]` — %s\n', R.sensor.y_B_note);
    fprintf(fid, '- y_C (+INS xy): full 12 — %s\n', R.sensor.y_C_note);
    fprintf(fid, '- Production: %s\n', R.sensor.production);
    fprintf(fid, '- Noise: %s\n\n', R.sensor.noise_status);

    fprintf(fid, '## Separation A vs B\n\n');
    fprintf(fid, '| Class | Residual | Uses | Sensor-only? |\n|---|---|---|:---:|\n');
    fprintf(fid, '| **A** | \\|δr_cmd − δr_app\\| | applied rudder / effectiveness feedback | **NO** (hardware) |\n');
    fprintf(fid, '| **B1** | phase-aligned \\|δr_cmd − δr_nom(φ)\\| | known cmd + INS xy phase | YES |\n');
    fprintf(fid, '| **B2** | max(0, 1 − [r/(u²δr_cmd)]/G_nom) | known cmd + IMU r + DVL u | YES |\n');
    fprintf(fid, '| **B** | B1 OR B2 | union | YES |\n\n');
    fprintf(fid, 'A is reported for comparison only and is **forbidden** as the sensor-only PASS basis.\n\n');

    fprintf(fid, '## Equations\n\n');
    fprintf(fid, '### A (hardware-dependent)\n```\n');
    for i = 1:numel(R.equations.A), fprintf(fid, '%s\n', R.equations.A{i}); end
    fprintf(fid, '```\n\n### B1 (command vs phase-aligned nominal demand)\n```\n');
    for i = 1:numel(R.equations.B1), fprintf(fid, '%s\n', R.equations.B1{i}); end
    fprintf(fid, '```\n\n### B2 (yaw-rate response / command gain)\n```\n');
    for i = 1:numel(R.equations.B2), fprintf(fid, '%s\n', R.equations.B2{i}); end
    fprintf(fid, '```\n\n');
    fprintf(fid, '- Detector: %s\n', R.equations.detector);
    fprintf(fid, '- Scaling: %s\n\n', R.equations.scaling);

    fprintf(fid, '## Signal provenance (B)\n\n');
    fprintf(fid, '| Signal | Provenance |\n|---|---|\n');
    fprintf(fid, '| δr_cmd | known controller command log |\n');
    fprintf(fid, '| r | IMU body yaw-rate (ASSUMED-direct plant truth) |\n');
    fprintf(fid, '| u | DVL surge (ASSUMED-direct) |\n');
    fprintf(fid, '| φ_ins | INS absolute xy → unwrap(atan2(y,x)) |\n');
    fprintf(fid, '| δr_nom(φ), G_nom | frozen from HELIX_R10 nominal only |\n');
    fprintf(fid, '| δr_app, η_r, fault flags | **NOT used in B** |\n\n');

    fprintf(fid, '## Threshold / persistence selection (nominal only → frozen)\n\n');
    fprintf(fid, '| Item | Value |\n|---|---:|\n');
    fprintf(fid, '| Warmup | t > %.1f s |\n', R.cal.t_warmup_s);
    fprintf(fid, '| \\|δr\\|_gate | %.1f deg |\n', rad2deg(R.cal.eps_dr_rad));
    fprintf(fid, '| Percentile | %.1f (raw ~1%% exceedance target) |\n', R.cal.pctl);
    fprintf(fid, '| Persistence | %.2f s (%d samples @ dt=%.3f) |\n', ...
        R.cal.persist_s, R.cal.Np, R.TF.dt);
    fprintf(fid, '| thr B1 [deg] | %.4f |\n', R.thr.B1_cmd_phase_deg);
    fprintf(fid, '| thr B2 [frac] | %.4f |\n', R.thr.B2_frac_loss);
    fprintf(fid, '| thr A [deg] | %.2f (hardware floor) |\n', R.thr.A_cmd_app_deg);
    fprintf(fid, '| G_nom | %.4f |\n', R.cal.G_nom);
    fprintf(fid, '| Frozen before fault eval | YES |\n\n');

    fprintf(fid, '## Nominal false-alarm rates\n\n');
    fprintf(fid, '| Channel | Raw exceed %% | Persisted detector %% | Limit |\n|---|---:|---:|---:|\n');
    fprintf(fid, '| B1 | %.3f | %.3f | ≤1 |\n', R.FA.B1_raw_pct, R.FA.B1_persist_pct);
    fprintf(fid, '| B2 | %.3f | %.3f | ≤1 |\n', R.FA.B2_raw_pct, R.FA.B2_persist_pct);
    fprintf(fid, '| B (OR) | — | %.3f | ≤1 |\n', R.FA.B_or_persist_pct);
    fprintf(fid, '| A | 0 (app≡cmd) | %.3f | n/a |\n\n', R.FA.A_persist_pct);

    fprintf(fid, '## Fault detection (thresholds frozen)\n\n');
    fprintf(fid, '| Channel | Detected | Delay [s] | Missed | Post median | Limit delay |\n|---|:---:|---:|:---:|---:|---:|\n');
    fprintf(fid, '| A (hw) | %s | %.3f | %s | %.3f deg | 3 |\n', ...
        yn(R.score.A.detected), R.score.A.delay_s, yn(R.score.missed_A), R.score.A.post_median);
    fprintf(fid, '| B1 | %s | %.3f | %s | %.3f deg | 3 |\n', ...
        yn(R.score.B1.detected), R.score.B1.delay_s, yn(isinf(R.score.B1.delay_s)), R.score.B1.post_median);
    fprintf(fid, '| B2 | %s | %.3f | %s | %.3f | 3 |\n', ...
        yn(R.score.B2.detected), R.score.B2.delay_s, yn(isinf(R.score.B2.delay_s)), R.score.B2.post_median);
    fprintf(fid, '| **B (OR)** | %s | **%.3f** | %s | — | 3 |\n\n', ...
        yn(R.score.B.detected), R.score.B.delay_s, yn(R.score.missed_B));

    fprintf(fid, '## Gates\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|------|:------:|--------|\n');
    fprintf(fid, '| A detect ≤3 s (hardware) | %s | delay=%.3f |\n', yn(R.G.g_A_detect_3s), R.score.A.delay_s);
    fprintf(fid, '| B detect ≤3 s | %s | delay=%.3f |\n', yn(R.G.g_B_detect_3s), R.score.B.delay_s);
    fprintf(fid, '| B nominal FA ≤1%% | %s | %.3f%% |\n', yn(R.G.g_B_FA_le_1pct), R.FA.B_or_persist_pct);
    fprintf(fid, '| No B data leakage | %s | app/η/labels unused in B |\n', yn(R.G.g_no_leakage));
    fprintf(fid, '| **B sensor-only feasibility** | **%s** | — |\n\n', R.verdict_B);

    fprintf(fid, '## Robustness limitations\n\n');
    fprintf(fid, '- Single trajectory / single fault case: %s\n', R.limitations.single_fault_case);
    fprintf(fid, '- %s\n', R.limitations.sensor_noise);
    fprintf(fid, '- %s\n', R.limitations.phase_alignment);
    fprintf(fid, '- %s\n', R.limitations.closed_loop_masking);
    fprintf(fid, '- A must not be cited as sensor-only evidence.\n\n');

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '- **`%s`** — %s\n\n', R.G.next_priority, R.G.next_note);

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `run_rudder_residual_detector_feasibility.m` (isolated driver only)\n');
    fprintf(fid, '- `suite_results/%s.md`\n', tag);
    fprintf(fid, '- `suite_results/%s.mat`\n', tag);
    fprintf(fid, '- `suite_results/%s.png`\n', tag);
    fprintf(fid, '- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function append_research_log(out_dir, tag, task_id, stamp, R)
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    fid = fopen(log_path, 'a');
    fprintf(fid, '\n\n## %s — %s\n\n', task_id, stamp);
    fprintf(fid, '- Sensor-only (B): **%s** — Hardware (A): **%s** — offline only; production frozen; no NL rerun.\n', ...
        R.verdict_B, R.verdict_A);
    fprintf(fid, '- Sources: RUDDER_FAULT_BASELINE.mat + HELIX_R10_YAW_PITCH_ENVELOPE.mat + STATE_SPACE_MODEL_AUDIT.md.\n');
    fprintf(fid, '- Terminology fix: prior baseline = **fixed-horizon survivability** (T_final ok, progress=%.1f%%), not mission-goal completion.\n', ...
        100 * R.prior_terminology.progress_frac);
    fprintf(fid, '- A: |cmd−app| hardware residual delay=%.3fs (forbidden as sensor-only).\n', R.score.A.delay_s);
    fprintf(fid, '- B1 phase-cmd: thr=%.3f° FA_persist=%.3f%% delay=%.3fs | B2 frac-loss: thr=%.3f FA=%.3f%% delay=%.3fs.\n', ...
        R.thr.B1_cmd_phase_deg, R.FA.B1_persist_pct, R.score.B1.delay_s, ...
        R.thr.B2_frac_loss, R.FA.B2_persist_pct, R.score.B2.delay_s);
    fprintf(fid, '- B OR: FA=%.3f%% (≤1%%) delay=%.3fs (≤3s) leakage=NO.\n', ...
        R.FA.B_or_persist_pct, R.score.B.delay_s);
    fprintf(fid, '- Limits: single traj/fault; ASSUMED-direct sensors; noise NOT_IMPLEMENTED; phase template path-specific.\n');
    fprintf(fid, '- Artifacts: suite_results/%s.{md,mat,png}; driver `run_rudder_residual_detector_feasibility.m`.\n', tag);
    fprintf(fid, '- Next: **`%s`** — %s\n', R.G.next_priority, R.G.next_note);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
    fclose(fid);
end

function s = yn(tf)
    if tf, s = 'YES'; else, s = 'NO'; end
end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end
