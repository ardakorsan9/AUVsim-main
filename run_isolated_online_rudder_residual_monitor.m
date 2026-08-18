function run_isolated_online_rudder_residual_monitor()
% ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR_001
% Isolated causal online B2 rudder-health monitor scaffold.
% Sources ONLY (3):
%   suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.{md,mat}
%   suite_results/RUDDER_FAULT_BASELINE.mat
% Load frozen G_nom / thr / gate / u_floor / persistence from feasibility MAT.
% No retune. No applied-rudder / effectiveness / fault-label input to monitor.
% Replay nominal (feasibility R.TN) + fault (baseline) sample-by-sample.
% Fault labels used ONLY after replay for scoring.
% Functional PASS ≠ deployment certification (remains NOT_CERTIFIED).
% Production cascade+guidance+plant FROZEN. Does NOT touch CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR';
    task_id = 'ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    feas_mat = fullfile(out_dir, 'RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.mat');
    feas_md  = fullfile(out_dir, 'RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.md');
    fault_mat = fullfile(out_dir, 'RUDDER_FAULT_BASELINE.mat');
    assert(exist(feas_mat, 'file') == 2, 'Missing %s', feas_mat);
    assert(exist(feas_md, 'file') == 2, 'Missing %s', feas_md);
    assert(exist(fault_mat, 'file') == 2, 'Missing %s', fault_mat);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Isolated online B2 monitor; frozen params; production frozen.\n');

    Feas = load(feas_mat);
    Fault = load(fault_mat);
    assert(isfield(Feas, 'R') && isfield(Feas, 'thr') && isfield(Feas.R, 'cal'), ...
        'Feasibility MAT missing R/thr/cal');
    Roff = Feas.R;
    thr_off = Feas.thr;
    cal = Roff.cal;

    % ----- Frozen deployable B2 config (NO retune) -----
    frozen = struct();
    frozen.G_nom = cal.G_nom;
    frozen.thr_B2 = thr_off.B2_frac_loss;
    frozen.eps_dr_rad = cal.eps_dr_rad;
    frozen.u_floor = cal.u_floor;
    frozen.t_warmup_s = cal.t_warmup_s;
    frozen.Np = cal.Np;
    frozen.persist_s = cal.persist_s;
    frozen.dt = Roff.TF.dt;
    frozen.source = 'suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.mat';
    frozen.retuned = false;

    % ----- Build replay streams -----
    % Nominal: from feasibility R.TN (HELIX_R10 nominal embedded at feasibility time)
    TN = Roff.TN;
    nom = struct();
    nom.t = TN.t(:);
    nom.delta_r_cmd = TN.dr_cmd(:);
    nom.r = TN.r(:);
    nom.u = TN.u(:);
    nom.n = numel(nom.t);
    nom.source = 'feasibility.R.TN (HELIX_R10 nominal)';

    % Fault: from RUDDER_FAULT_BASELINE plant/controller logs (sensor-mapped ASSUMED-direct)
    SF = Fault.S;
    assert(isfield(SF, 't_fault_s') && ~isnan(SF.t_fault_s), 'Missing t_fault');
    fault = struct();
    fault.t = SF.t(:);
    fault.delta_r_cmd = SF.delta_r_cmd(:);
    fault.r = SF.rates(:, 3);
    fault.u = SF.vel(:, 1);
    fault.n = numel(fault.t);
    fault.t_fault_s = SF.t_fault_s;
    fault.dt = SF.dt;
    fault.source = 'suite_results/RUDDER_FAULT_BASELINE.mat';
    % Labels kept aside — NEVER passed into monitor update
    labels = struct();
    labels.t_fault_s = SF.t_fault_s;
    labels.eta_r = SF.eta_r(:);
    labels.delta_r_app = SF.delta_r_app(:);
    labels.fault_active = (fault.t >= labels.t_fault_s);

    assert(abs(fault.dt - frozen.dt) < 1e-12, 'dt mismatch baseline vs frozen');

    % =====================================================================
    % SAMPLE-BY-SAMPLE REPLAY (causal online)
    % =====================================================================
    monN = isolated_online_rudder_residual_monitor('init', frozen);
    [logN, monN] = replay_stream(monN, nom);

    monF = isolated_online_rudder_residual_monitor('init', frozen);
    [logF, monF] = replay_stream(monF, fault);

    % Reset API smoke check (does not affect scored logs)
    mon_rst = isolated_online_rudder_residual_monitor('reset', monF);
    assert(mon_rst.persist_count == 0 && ~mon_rst.alarm_latched && isnan(mon_rst.t_alarm_s), ...
        'reset API failed');
    reset_ok = true;

    % =====================================================================
    % SCORING (labels ONLY here)
    % =====================================================================
    score = struct();
    score.delay_limit_s = 3.0;
    score.FA_limit_pct = 1.0;

    % Nominal FA: latched-alarm duty after warmup (and gated-only for offline parity)
    mask_Nw = logN.t > frozen.t_warmup_s;
    gate_N = mask_Nw & (abs(nom.delta_r_cmd) > frozen.eps_dr_rad);
    score.FA_latched_pct = 100 * mean(logN.alarm(mask_Nw));
    score.FA_gated_latched_pct = 100 * mean(logN.alarm(gate_N));
    % Offline-parity FA: non-latching persist on gated samples (matches feas. detN.B2)
    detN_nl = persist_on((logN.residual > frozen.thr_B2) & gate_N, frozen.Np);
    score.FA_B2_persist_pct = 100 * mean(detN_nl(gate_N));
    score.FA_offline_B2_pct = Roff.FA.B2_persist_pct;

    % Fault detection
    tf = labels.t_fault_s;
    pre = logF.t < tf;
    post = logF.t >= tf;
    score.t_fault_s = tf;
    score.alarm_before_fault = any(logF.alarm(pre));
    if any(logF.alarm & post)
        i_det = find(logF.alarm & post, 1, 'first');
        score.detected = true;
        score.t_detect_s = logF.t(i_det);
        score.delay_s = score.t_detect_s - tf;
    else
        score.detected = false;
        score.t_detect_s = NaN;
        score.delay_s = Inf;
    end
    score.missed = ~score.detected;
    score.post_median_resid = median(logF.residual(post & logF.gated & isfinite(logF.residual)));

    % Offline parity (B2 channel from feasibility)
    score.offline_delay_B2_s = Roff.score.B2.delay_s;
    score.offline_detected_B2 = Roff.score.B2.detected;
    score.delay_parity_s = abs(score.delay_s - score.offline_delay_B2_s);
    score.delay_parity_ok = isfinite(score.delay_s) && ...
        (score.delay_parity_s <= frozen.dt + 1e-9);
    % Residual parity vs offline eF.B2 on overlapping finite gated samples
    eF_off = Roff.eF.B2(:);
    n_par = min(numel(eF_off), numel(logF.residual));
    both = isfinite(eF_off(1:n_par)) & isfinite(logF.residual(1:n_par));
    if any(both)
        score.resid_max_abs_err = max(abs(eF_off(both) - logF.residual(both)));
    else
        score.resid_max_abs_err = Inf;
    end
    score.resid_parity_ok = score.resid_max_abs_err < 1e-12;

    % Gates — functional
    G = struct();
    G.g_FA_le_1pct = (score.FA_B2_persist_pct <= score.FA_limit_pct) && ...
        (score.FA_latched_pct <= score.FA_limit_pct);
    G.g_detect_le_3s = score.detected && (score.delay_s <= score.delay_limit_s);
    G.g_no_alarm_before_fault = ~score.alarm_before_fault;
    G.g_parity_offline = score.delay_parity_ok && score.resid_parity_ok;
    G.g_reset_api = reset_ok;
    G.g_no_forbidden_inputs = true;  % by API construction
    G.functional_pass = G.g_FA_le_1pct && G.g_detect_le_3s && ...
        G.g_no_alarm_before_fault && G.g_parity_offline && G.g_reset_api;
    G.functional_verdict = tern(G.functional_pass, 'PASS', 'FAIL');

    % Deployment certification — deliberately NOT_CERTIFIED
    cert = struct();
    cert.status = 'NOT_CERTIFIED';
    cert.reasons = { ...
        'Sensor noise/delay NOT_IMPLEMENTED / untested on this monitor'; ...
        'Other speeds / paths / currents untested (single R10@U=1.5 traj)'; ...
        'Other fault magnitudes untested (only eta_r:1→0.50)'; ...
        'ASSUMED-direct plant truth mapped to IMU/DVL; not real sensors'};
    cert.note = ['Functional PASS (if any) is replay-parity only; ', ...
        'deployment remains NOT_CERTIFIED until robustness stress + broader coverage.'];

    if G.functional_pass
        G.next_priority = 'bounded_synthetic_noise_delay_robustness_stress';
        G.next_note = ['Functional PASS → next: bounded synthetic noise/delay ', ...
            'robustness stress; deployment still NOT_CERTIFIED.'];
    else
        G.next_priority = 'reject_monitor';
        G.next_note = 'Functional FAIL → reject monitor; do not promote; production untouched.';
    end

    % Bundle
    R = struct();
    R.task_id = task_id;
    R.stamp = stamp;
    R.tag = tag;
    R.sources = {feas_mat, feas_md, fault_mat};
    R.frozen = frozen;
    R.nom_meta = struct('n', nom.n, 'source', nom.source);
    R.fault_meta = struct('n', fault.n, 't_fault_s', fault.t_fault_s, ...
        'dt', fault.dt, 'source', fault.source);
    R.logN = logN;
    R.logF = logF;
    R.score = score;
    R.G = G;
    R.cert = cert;
    R.labels_used_only_for_scoring = true;
    R.monitor_api = {'init','update','reset','state'};
    R.equation = { ...
        'g_hat = r_IMU / (max(u_DVL,u_floor)^2 * delta_r_cmd)'; ...
        'r_B2 = max(0, 1 - g_hat/G_nom)  % dimensionless'; ...
        'alarm if r_B2>thr for Np consecutive gated samples → LATCH until reset'};
    R.verdict_functional = G.functional_verdict;
    R.verdict_deployment = cert.status;
    R.verdict = G.functional_verdict;

    write_png(out_dir, tag, task_id, R);
    write_md(out_dir, tag, task_id, stamp, R);
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'R', 'G', 'score', 'frozen', 'cert', 'logN', 'logF', '-v7.3');
    append_research_log(out_dir, tag, task_id, stamp, R);

    fprintf(['functional=%s deploy=%s | FA=%.3f%% (lim 1) | delay=%.3fs ', ...
        '(offline %.3fs) | before_fault=%s | parity=%s | next=%s\n'], ...
        R.verdict_functional, R.verdict_deployment, score.FA_B2_persist_pct, ...
        score.delay_s, score.offline_delay_B2_s, yn(score.alarm_before_fault), ...
        yn(G.g_parity_offline), G.next_priority);
    fprintf('Wrote suite_results/%s.{md,mat,png} + research log append\n', tag);
end

%% ===================== replay / helpers =====================
function [log, mon] = replay_stream(mon, stream)
    n = stream.n;
    log = struct();
    log.t = stream.t;
    log.residual = nan(n, 1);
    log.g_hat = nan(n, 1);
    log.valid = false(n, 1);
    log.warmed = false(n, 1);
    log.gated = false(n, 1);
    log.above = false(n, 1);
    log.persist_count = zeros(n, 1);
    log.alarm = false(n, 1);
    log.alarm_raw_persist = false(n, 1);
    log.newly_alarmed = false(n, 1);
    for k = 1:n
        sample = struct( ...
            't', stream.t(k), ...
            'delta_r_cmd', stream.delta_r_cmd(k), ...
            'r', stream.r(k), ...
            'u', stream.u(k));
        [mon, out] = isolated_online_rudder_residual_monitor('update', mon, sample);
        log.residual(k) = out.residual;
        log.g_hat(k) = out.g_hat;
        log.valid(k) = out.valid;
        log.warmed(k) = out.warmed;
        log.gated(k) = out.gated;
        log.above(k) = out.above;
        log.persist_count(k) = out.persist_count;
        log.alarm(k) = out.alarm;
        log.alarm_raw_persist(k) = out.alarm_raw_persist;
        log.newly_alarmed(k) = out.newly_alarmed;
    end
    log.t_alarm_s = mon.t_alarm_s;
    log.alarm_latched_final = mon.alarm_latched;
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

%% ===================== artifacts =====================
function write_png(out_dir, tag, task_id, R)
    fig = figure('Visible', 'off', 'Position', [80 80 1280 860]);
    tf = R.score.t_fault_s;

    subplot(2, 2, 1);
    plot(R.logN.t, R.logN.residual, 'Color', [0.55 0.55 0.55]); hold on;
    plot(R.logF.t, R.logF.residual, 'b');
    yline(R.frozen.thr_B2, 'k--');
    xline(tf, 'k-');
    grid on; ylabel('r_{B2} (frac)'); xlabel('t [s]');
    title(sprintf('B2 residual online | thr=%.4f G_{nom}=%.4f', ...
        R.frozen.thr_B2, R.frozen.G_nom));
    legend('nom', 'fault', 'Location', 'best');

    subplot(2, 2, 2);
    plot(R.logN.t, double(R.logN.alarm), 'Color', [0.55 0.55 0.55]); hold on;
    plot(R.logF.t, double(R.logF.alarm), 'r', 'LineWidth', 1.2);
    xline(tf, 'k-');
    ylim([-0.05 1.15]); grid on; ylabel('alarm (latched)'); xlabel('t [s]');
    title(sprintf('Latched alarm | delay=%.3fs FA=%.3f%%', ...
        R.score.delay_s, R.score.FA_B2_persist_pct));
    legend('nom', 'fault', 'Location', 'best');

    subplot(2, 2, 3);
    plot(R.logF.t, R.logF.persist_count, 'b'); hold on;
    yline(R.frozen.Np, 'k--');
    xline(tf, 'k-');
    grid on; ylabel('persist count'); xlabel('t [s]');
    title(sprintf('Persistence counter (Np=%d)', R.frozen.Np));

    subplot(2, 2, 4);
    axis off;
    txt = { ...
        sprintf('%s', task_id), ...
        sprintf('Functional: %s', R.verdict_functional), ...
        sprintf('Deployment: %s', R.verdict_deployment), ...
        sprintf('FA_B2 persist: %.3f%% (≤1%%)', R.score.FA_B2_persist_pct), ...
        sprintf('FA latched (warmup): %.3f%%', R.score.FA_latched_pct), ...
        sprintf('delay: %.3f s (offline %.3f s)', R.score.delay_s, R.score.offline_delay_B2_s), ...
        sprintf('alarm before fault: %s', yn(R.score.alarm_before_fault)), ...
        sprintf('resid max|err|: %.3e parity=%s', R.score.resid_max_abs_err, yn(R.G.g_parity_offline)), ...
        sprintf('G_nom=%.4f thr=%.4f (frozen)', R.frozen.G_nom, R.frozen.thr_B2), ...
        sprintf('Next: %s', R.G.next_priority)};
    text(0.02, 0.98, txt, 'VerticalAlignment', 'top', 'FontName', 'FixedWidth', 'FontSize', 10);

    sgtitle(sprintf('%s | functional=%s deploy=%s', tag, ...
        R.verdict_functional, R.verdict_deployment), 'Interpreter', 'none');
    exportgraphics(fig, fullfile(out_dir, [tag '.png']), 'Resolution', 150);
    close(fig);
end

function write_md(out_dir, tag, task_id, stamp, R)
    md = fullfile(out_dir, [tag '.md']);
    fid = fopen(md, 'w');
    fprintf(fid, '# %s\n\n', tag);
    fprintf(fid, '**TASK_ID:** %s\n', task_id);
    fprintf(fid, '**Date:** %s\n', stamp);
    fprintf(fid, '**Functional verdict:** **%s**\n', R.verdict_functional);
    fprintf(fid, '**Deployment certification:** **%s**\n\n', R.verdict_deployment);

    fprintf(fid, 'Isolated stateful causal online B2 rudder-health monitor. ');
    fprintf(fid, 'No nonlinear rerun. Production cascade+guidance+plant **frozen**.\n\n');

    fprintf(fid, '## Sources (3 only)\n\n');
    fprintf(fid, '1. `suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.md`\n');
    fprintf(fid, '2. `suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.mat` (frozen G_nom/thr/gate/persist)\n');
    fprintf(fid, '3. `suite_results/RUDDER_FAULT_BASELINE.mat` (fault replay log)\n\n');

    fprintf(fid, '## Monitor (B2 primary)\n\n');
    fprintf(fid, '```\n');
    for i = 1:numel(R.equation), fprintf(fid, '%s\n', R.equation{i}); end
    fprintf(fid, '```\n\n');
    fprintf(fid, '| Item | Value |\n|---|---:|\n');
    fprintf(fid, '| G_nom [1/(m^2·rad)] | %.6f |\n', R.frozen.G_nom);
    fprintf(fid, '| thr_B2 [frac] | %.6f |\n', R.frozen.thr_B2);
    fprintf(fid, '| \\|δr\\|_gate [deg] | %.1f |\n', rad2deg(R.frozen.eps_dr_rad));
    fprintf(fid, '| u_floor [m/s] | %.2f |\n', R.frozen.u_floor);
    fprintf(fid, '| Warmup | t > %.1f s |\n', R.frozen.t_warmup_s);
    fprintf(fid, '| Persistence | %.2f s (Np=%d @ dt=%.3f) |\n', ...
        R.frozen.persist_s, R.frozen.Np, R.frozen.dt);
    fprintf(fid, '| Retuned | NO |\n');
    fprintf(fid, '| Inputs | δr_cmd (known) + r (IMU) + u (DVL) only |\n');
    fprintf(fid, '| Forbidden | δr_app / η_r / fault labels / INS xy |\n\n');

    fprintf(fid, '## Online behavior\n\n');
    fprintf(fid, '- Sequential sample-by-sample `update`; causal (no future samples).\n');
    fprintf(fid, '- Warmup: t≤%.1fs → counter=0, no alarm.\n', R.frozen.t_warmup_s);
    fprintf(fid, '- Gate: |δr_cmd|≤%.1f° → counter reset.\n', rad2deg(R.frozen.eps_dr_rad));
    fprintf(fid, '- NaN/dropout on t/δr/r/u → residual=NaN, counter reset, no latch step.\n');
    fprintf(fid, '- Persistence counter increments only on gated exceedance; else resets.\n');
    fprintf(fid, '- Alarm latches on Np consecutive exceedances until `reset`.\n');
    fprintf(fid, '- Units: δr [rad], r [rad/s], u [m/s], residual dimensionless.\n');
    fprintf(fid, '- Reset API smoke: **%s**\n\n', yn(R.G.g_reset_api));

    fprintf(fid, '## Replay scoring (labels post-hoc only)\n\n');
    fprintf(fid, '| Gate | Result | Detail |\n|------|:------:|--------|\n');
    fprintf(fid, '| Nominal FA ≤1%% (B2 persist) | %s | %.3f%% (offline %.3f%%) |\n', ...
        yn(R.G.g_FA_le_1pct), R.score.FA_B2_persist_pct, R.score.FA_offline_B2_pct);
    fprintf(fid, '| Latched FA after warmup ≤1%% | %s | %.3f%% |\n', ...
        yn(R.score.FA_latched_pct <= 1.0), R.score.FA_latched_pct);
    fprintf(fid, '| Detection ≤3 s | %s | delay=%.3f s |\n', yn(R.G.g_detect_le_3s), R.score.delay_s);
    fprintf(fid, '| No alarm before fault | %s | — |\n', yn(R.G.g_no_alarm_before_fault));
    fprintf(fid, '| Parity with offline B2 | %s | Δdelay=%.3es max|resid|=%.3e |\n', ...
        yn(R.G.g_parity_offline), R.score.delay_parity_s, R.score.resid_max_abs_err);
    fprintf(fid, '| **Functional** | **%s** | — |\n', R.verdict_functional);
    fprintf(fid, '| **Deployment** | **%s** | see reasons |\n\n', R.verdict_deployment);

    fprintf(fid, '### Deployment NOT_CERTIFIED reasons\n\n');
    for i = 1:numel(R.cert.reasons)
        fprintf(fid, '- %s\n', R.cert.reasons{i});
    end
    fprintf(fid, '\n%s\n\n', R.cert.note);

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '- **`%s`** — %s\n\n', R.G.next_priority, R.G.next_note);

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `isolated_online_rudder_residual_monitor.m` (monitor)\n');
    fprintf(fid, '- `run_isolated_online_rudder_residual_monitor.m` (isolated runner)\n');
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
    fprintf(fid, '- Functional: **%s** — Deployment: **%s** — isolated online B2 monitor; production frozen; no NL rerun.\n', ...
        R.verdict_functional, R.verdict_deployment);
    fprintf(fid, '- Frozen from feasibility: G_nom=%.4f thr=%.4f gate=%.1f° u_floor=%.2f Np=%d persist=%.2fs (no retune).\n', ...
        R.frozen.G_nom, R.frozen.thr_B2, rad2deg(R.frozen.eps_dr_rad), ...
        R.frozen.u_floor, R.frozen.Np, R.frozen.persist_s);
    fprintf(fid, '- Inputs: δr_cmd + IMU r + DVL u only; app/η/labels forbidden in update; labels post-hoc scoring only.\n');
    fprintf(fid, '- Replay: FA_B2=%.3f%% (≤1) delay=%.3fs (offline %.3fs) before_fault=%s resid_parity_max|err|=%.3e.\n', ...
        R.score.FA_B2_persist_pct, R.score.delay_s, R.score.offline_delay_B2_s, ...
        yn(R.score.alarm_before_fault), R.score.resid_max_abs_err);
    fprintf(fid, '- Cert blocked: noise/delay, other speeds/paths/currents, other fault magnitudes untested.\n');
    fprintf(fid, '- Artifacts: suite_results/%s.{md,mat,png}; `isolated_online_rudder_residual_monitor.m` + `run_isolated_online_rudder_residual_monitor.m`.\n', tag);
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
