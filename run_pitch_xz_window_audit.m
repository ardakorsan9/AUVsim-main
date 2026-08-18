function run_pitch_xz_window_audit()
% PITCH_XZ_WINDOW_AUDIT_001 — correct pitch acq/steady windows; rescore MATs only.
% No controller / guidance / plant change. No new candidate run.
% Inputs:  suite_results/PITCH_XZ_TRACK.mat (λ=0), PITCH_XZ_CLIMB_TRIM_FF.mat
% Outputs: suite_results/PITCH_XZ_WINDOW_AUDIT.{md,mat,png}
% Metric:  compute_pitch_window_metrics.m  (first_hold -> persistent)

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    tag = 'PITCH_XZ_WINDOW_AUDIT';
    task_id = 'PITCH_XZ_WINDOW_AUDIT_001';

    B = load(fullfile(out_dir, 'PITCH_XZ_TRACK.mat'));
    C = load(fullfile(out_dir, 'PITCH_XZ_CLIMB_TRIM_FF.mat'));
    Lb = B.m00.logs;
    Lc = C.m.logs;
    sb = B.m00.pm.s_prog(:);
    sc = C.m.pm.s_prog(:);
    stb = B.m00.pm.s_total;
    stc = C.m.pm.s_total;
    path_pitch = atan2(0.4, 1);

    % ---- Old (first_hold) vs new (persistent) on both series ----
    Bold = compute_pitch_window_metrics(Lb.t, Lb.e_th, sb, stb, 'mode', 'first_hold');
    Bnew = compute_pitch_window_metrics(Lb.t, Lb.e_th, sb, stb, 'mode', 'persistent');
    Cold = compute_pitch_window_metrics(Lc.t, Lc.e_th, sc, stc, 'mode', 'first_hold');
    Cnew = compute_pitch_window_metrics(Lc.t, Lc.e_th, sc, stc, 'mode', 'persistent');

    % Dip on each acq mask (path_pitch - min theta_phys)
    dip = @(th, msk) rad2deg(path_pitch - min(th(msk)));
    Bold.dip_deg = dip(Lb.theta_phys, Bold.mask_acq);
    Bnew.dip_deg = dip(Lb.theta_phys, Bnew.mask_acq);
    Cold.dip_deg = dip(Lc.theta_phys, Cold.mask_acq);
    Cnew.dip_deg = dip(Lc.theta_phys, Cnew.mask_acq);

    % Elev sat / chatter from stored climb logs on new/old steady (climb only)
    dt = Lb.t(2) - Lb.t(1);
    lim = evalin_delta_e_max();
    [Cold.elev_sat_pct, Cold.chatter_dps] = elev_stats(Lc, Cold.mask_steady, dt, lim, C.m);
    [Cnew.elev_sat_pct, Cnew.chatter_dps] = elev_stats(Lc, Cnew.mask_steady, dt, lim, C.m);
    [Bold.elev_sat_pct, Bold.chatter_dps] = elev_stats(Lb, Bold.mask_steady, dt, lim, B.m00);
    [Bnew.elev_sat_pct, Bnew.chatter_dps] = elev_stats(Lb, Bnew.mask_steady, dt, lim, B.m00);

    overshoot = @(th, tr, m_acq, m_ss) local_os(th, tr, m_acq, m_ss);
    Bold.overshoot_deg = overshoot(Lb.theta_phys, Lb.theta_ref, Bold.mask_acq, Bold.mask_steady);
    Bnew.overshoot_deg = overshoot(Lb.theta_phys, Lb.theta_ref, Bnew.mask_acq, Bnew.mask_steady);
    Cold.overshoot_deg = overshoot(Lc.theta_phys, Lc.theta_ref, Cold.mask_acq, Cold.mask_steady);
    Cnew.overshoot_deg = overshoot(Lc.theta_phys, Lc.theta_ref, Cnew.mask_acq, Cnew.mask_steady);

    % Reproduce stored reported metrics from MAT (independent raw e_th)
    tol = 1e-3;
    repro = struct();
    repro.base_acq_s = abs(Bold.acq_time_s - B.m00.acq_time_s) <= tol;
    repro.base_ss_mae = abs(Bold.steady.mae_deg - B.m00.steady.mae_deg) <= tol;
    repro.base_ss_p95 = abs(Bold.steady.p95_deg - B.m00.steady.p95_deg) <= tol;
    repro.base_dip = abs(Bold.dip_deg - B.m00.dip_deg) <= tol;
    repro.climb_acq_s = abs(Cold.acq_time_s - C.m.acq_time_s) <= tol;
    repro.climb_ss_mae = abs(Cold.steady.mae_deg - C.m.steady.mae_deg) <= tol;
    repro.climb_ss_p95 = abs(Cold.steady.p95_deg - C.m.steady.p95_deg) <= tol;
    repro.climb_dip = abs(Cold.dip_deg - C.m.dip_deg) <= tol;
    repro.all = repro.base_acq_s && repro.base_ss_mae && repro.base_ss_p95 && ...
        repro.base_dip && repro.climb_acq_s && repro.climb_ss_mae && ...
        repro.climb_ss_p95 && repro.climb_dip;

    % Consistency: new steady max|e| <= band if persistent_ok
    band = 0.5;
    cons = struct();
    cons.base_persist = Bnew.persistent_ok;
    cons.climb_persist = Cnew.persistent_ok;
    if Bnew.persistent_ok
        cons.base_ss_inband = Bnew.steady.max_deg <= band + 1e-9;
    else
        cons.base_ss_inband = false;
    end
    if Cnew.persistent_ok
        cons.climb_ss_inband = Cnew.steady.max_deg <= band + 1e-9;
    else
        cons.climb_ss_inband = false;
    end
    cons.defs_ok = cons.base_persist && cons.climb_persist && ...
        cons.base_ss_inband && cons.climb_ss_inband && repro.all;

    % Original climb-FF gates, rescored baseline (new windows) as reference
    base_new = struct( ...
        'dip_deg', Bnew.dip_deg, ...
        'acq_mae_deg', Bnew.acq.mae_deg, ...
        'acq_s', Bnew.acq_time_s, ...
        'overshoot_deg', Bnew.overshoot_deg, ...
        'steady_rms_deg', Bnew.steady.rms_deg, ...
        'steady_p95_deg', Bnew.steady.p95_deg, ...
        'steady_mae_deg', Bnew.steady.mae_deg, ...
        'sat_pct', Bnew.elev_sat_pct, ...
        'chatter_dps', Bnew.chatter_dps);
    m_gate = struct( ...
        'dip_deg', Cnew.dip_deg, ...
        'acq', Cnew.acq, ...
        'acq_time_s', Cnew.acq_time_s, ...
        'overshoot_deg', Cnew.overshoot_deg, ...
        'steady', Cnew.steady, ...
        'elev_sat_pct', Cnew.elev_sat_pct, ...
        'chatter_dps', Cnew.chatter_dps, ...
        'persistent_ok', Cnew.persistent_ok);
    G = climb_gate(m_gate, base_new);

    % Also score vs published (old-window) baseline numbers for reference
    base_pub = C.base;
    G_pubwin = climb_gate(struct( ...
        'dip_deg', Cold.dip_deg, 'acq', Cold.acq, 'acq_time_s', Cold.acq_time_s, ...
        'overshoot_deg', Cold.overshoot_deg, 'steady', Cold.steady, ...
        'elev_sat_pct', Cold.elev_sat_pct, 'chatter_dps', Cold.chatter_dps, ...
        'persistent_ok', Cold.persistent_ok), base_pub);

    audit_pass = cons.defs_ok; % task PASS = consistent defs + reproduce raw errors
    climb_class = tern(G.pass, 'PASS', 'FAIL');

    % ---- PNG ----
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1100 720]);
    e_max = max(abs(rad2deg([Lb.e_th; Lc.e_th])));
    % Top: overlay errors
    subplot(3,1,1); hold on;
    plot(Lb.t, rad2deg(Lb.e_th), 'b-', 'LineWidth', 1.1);
    plot(Lc.t, rad2deg(Lc.e_th), 'r-', 'LineWidth', 1.1);
    yline(band, 'k--'); yline(-band, 'k--'); yline(0, 'k:');
    xline(Bold.acq_time_s, 'b:', 'LineWidth', 1.0);
    xline(Bnew.acq_time_s, 'b--', 'LineWidth', 1.4);
    xline(Cold.acq_time_s, 'r:', 'LineWidth', 1.0);
    xline(Cnew.acq_time_s, 'r--', 'LineWidth', 1.4);
    grid on;
    ylabel('e_\theta [°]');
    legend({'baseline \lambda=0', 'climb-FF', '+/-0.5°', '', '', ...
        'base old settle', 'base new settle', 'FF old settle', 'FF new settle'}, ...
        'Location', 'best', 'NumColumns', 2);
    title(sprintf(['%s | defs %s | climb-FF under corrected windows: %s'], ...
        task_id, tern(audit_pass,'PASS','FAIL'), climb_class));

    subplot(3,1,2); hold on;
    area_mask(Lb.t, Bold.mask_steady, e_max, [0.75 0.85 1.0], 0.35);
    area_mask(Lb.t, Bnew.mask_steady, e_max, [0.2 0.4 0.9], 0.25);
    plot(Lb.t, rad2deg(Lb.e_th), 'b-', 'LineWidth', 1.0);
    yline(band, 'k--'); yline(-band, 'k--');
    xline(Bold.acq_time_s, 'b:'); xline(Bnew.acq_time_s, 'b--', 'LineWidth', 1.3);
    grid on; ylabel('e_\theta [°]');
    title(sprintf(['BASE |e\\theta|  old settle=%.2fs (n_{ss}=%d)  new=%.2fs (n_{ss}=%d)  ' ...
        'MAE old/new=%.4f/%.4f°'], ...
        Bold.acq_time_s, Bold.n_steady, Bnew.acq_time_s, Bnew.n_steady, ...
        Bold.steady.mae_deg, Bnew.steady.mae_deg));
    legend({'old steady mask', 'new steady mask', 'e_\theta'}, 'Location', 'best');

    subplot(3,1,3); hold on;
    area_mask(Lc.t, Cold.mask_steady, e_max, [1.0 0.85 0.75], 0.35);
    area_mask(Lc.t, Cnew.mask_steady, e_max, [0.9 0.25 0.2], 0.25);
    plot(Lc.t, rad2deg(Lc.e_th), 'r-', 'LineWidth', 1.0);
    yline(band, 'k--'); yline(-band, 'k--');
    xline(Cold.acq_time_s, 'r:'); xline(Cnew.acq_time_s, 'r--', 'LineWidth', 1.3);
    grid on; xlabel('t [s]'); ylabel('e_\theta [°]');
    title(sprintf(['CLIMB-FF |e\\theta|  old settle=%.2fs (n_{ss}=%d)  new=%.2fs (n_{ss}=%d)  ' ...
        'p95 old/new=%.4f/%.4f°'], ...
        Cold.acq_time_s, Cold.n_steady, Cnew.acq_time_s, Cnew.n_steady, ...
        Cold.steady.p95_deg, Cnew.steady.p95_deg));
    legend({'old steady mask', 'new steady mask', 'e_\theta'}, 'Location', 'best');

    png_path = fullfile(out_dir, [tag '.png']);
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);

    % ---- MAT ----
    task = struct('id', task_id, 'date', datestr(now, 31), ...
        'metric_old', 'inline first_hold (±0.5° for 1s) in run_pitch_xz_*.m', ...
        'metric_new', 'compute_pitch_window_metrics.m mode=persistent', ...
        'audit_pass', audit_pass, 'climb_class', climb_class);
    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'task', 'Bold', 'Bnew', 'Cold', 'Cnew', 'G', 'G_pubwin', ...
        'base_new', 'repro', 'cons', 'Lb', 'Lc');

    % ---- MD ----
    md_path = fullfile(out_dir, [tag '.md']);
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s\n\n', tag);
    fprintf(fid, '**TASK_ID:** %s\n', task_id);
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Audit verdict:** **%s** (defs consistent + raw-error reproduce)\n', ...
        tern(audit_pass,'PASS','FAIL'));
    fprintf(fid, '**Climb-FF under corrected windows / original gates:** **%s**\n\n', climb_class);

    fprintf(fid, '## Metric file\n\n');
    fprintf(fid, '- **old:** inline `first_hold` in `run_pitch_xz_track.m` / `run_pitch_xz_climb_trim_ff.m`\n');
    fprintf(fid, '  (settling = end of first |eθ|≤±0.5° for 1.0 s; steady = (t≥5 ∧ s<0.88 s_tot)∖acq)\n');
    fprintf(fid, '- **new:** `compute_pitch_window_metrics.m` (`mode=''persistent''`)\n');
    fprintf(fid, '  (drivers updated to call this; production controller/guidance/plant untouched)\n\n');

    fprintf(fid, '## Equations / windows / units\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'e_theta [rad] = theta_ref - theta_phys,  theta_phys = -theta\n');
    fprintf(fid, 'band = 0.5 deg\n');
    fprintf(fid, 'valid = { k | s(k) < 0.88 * s_total }     %% end-exclusion\n');
    fprintf(fid, 'n_end = last index in valid\n');
    fprintf(fid, 'settle_idx = min { k <= n_end : all(|e_theta(k:n_end)| <= band) }\n');
    fprintf(fid, '           = empty => settling_s = NaN (FAIL)\n');
    fprintf(fid, 'settling_s [s] = t(settle_idx)\n');
    fprintf(fid, 'mask_acq     = 1:settle_idx                 %% [start, settle]\n');
    fprintf(fid, 'mask_steady  = settle_idx:n_end             %% [settle, end-excl]\n');
    fprintf(fid, 'MAE/RMS/p95 reported in degrees on those masks\n');
    fprintf(fid, 'dip [deg] = path_pitch - min(theta_phys on acq), path_pitch=atan2(0.4,1)\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Reproduce stored MAT scores (old first_hold on raw e_th)\n\n');
    fprintf(fid, '| Check | OK? | stored | recomputed |\n|------|:---:|-------:|-----------:|\n');
    fprintf(fid, '| base acq_s | %s | %.2f | %.2f |\n', yn(repro.base_acq_s), B.m00.acq_time_s, Bold.acq_time_s);
    fprintf(fid, '| base steady MAE | %s | %.4f | %.4f |\n', yn(repro.base_ss_mae), B.m00.steady.mae_deg, Bold.steady.mae_deg);
    fprintf(fid, '| base steady p95 | %s | %.4f | %.4f |\n', yn(repro.base_ss_p95), B.m00.steady.p95_deg, Bold.steady.p95_deg);
    fprintf(fid, '| base dip | %s | %.4f | %.4f |\n', yn(repro.base_dip), B.m00.dip_deg, Bold.dip_deg);
    fprintf(fid, '| climb acq_s | %s | %.2f | %.2f |\n', yn(repro.climb_acq_s), C.m.acq_time_s, Cold.acq_time_s);
    fprintf(fid, '| climb steady MAE | %s | %.4f | %.4f |\n', yn(repro.climb_ss_mae), C.m.steady.mae_deg, Cold.steady.mae_deg);
    fprintf(fid, '| climb steady p95 | %s | %.4f | %.4f |\n', yn(repro.climb_ss_p95), C.m.steady.p95_deg, Cold.steady.p95_deg);
    fprintf(fid, '| climb dip | %s | %.4f | %.4f |\n\n', yn(repro.climb_dip), C.m.dip_deg, Cold.dip_deg);

    fprintf(fid, '## Old vs new scores\n\n');
    fprintf(fid, '### Baseline λ=0 (PITCH_XZ_TRACK.mat m00)\n\n');
    fprintf(fid, '| Metric | old first_hold | new persistent | Δ |\n|--------|---------------:|---------------:|--:|\n');
    write_cmp(fid, 'settling [s]', Bold.acq_time_s, Bnew.acq_time_s);
    fprintf(fid, '| n_acq | %d | %d | |\n', Bold.n_acq, Bnew.n_acq);
    fprintf(fid, '| n_steady | %d | %d | |\n', Bold.n_steady, Bnew.n_steady);
    fprintf(fid, '| n_end (valid) | %d | %d | |\n', Bold.n_end, Bnew.n_end);
    write_cmp(fid, 'dip [°]', Bold.dip_deg, Bnew.dip_deg);
    write_cmp(fid, 'acq MAE [°]', Bold.acq.mae_deg, Bnew.acq.mae_deg);
    write_cmp(fid, 'steady MAE [°]', Bold.steady.mae_deg, Bnew.steady.mae_deg);
    write_cmp(fid, 'steady RMS [°]', Bold.steady.rms_deg, Bnew.steady.rms_deg);
    write_cmp(fid, 'steady p95 [°]', Bold.steady.p95_deg, Bnew.steady.p95_deg);
    write_cmp(fid, 'steady max\\|e\\| [°]', Bold.steady.max_deg, Bnew.steady.max_deg);
    fprintf(fid, '| persistent_ok | %s | %s | |\n\n', yn(Bold.persistent_ok), yn(Bnew.persistent_ok));

    fprintf(fid, '### Climb-FF (PITCH_XZ_CLIMB_TRIM_FF.mat)\n\n');
    fprintf(fid, '| Metric | old first_hold | new persistent | Δ |\n|--------|---------------:|---------------:|--:|\n');
    write_cmp(fid, 'settling [s]', Cold.acq_time_s, Cnew.acq_time_s);
    fprintf(fid, '| n_acq | %d | %d | |\n', Cold.n_acq, Cnew.n_acq);
    fprintf(fid, '| n_steady | %d | %d | |\n', Cold.n_steady, Cnew.n_steady);
    fprintf(fid, '| n_end (valid) | %d | %d | |\n', Cold.n_end, Cnew.n_end);
    write_cmp(fid, 'dip [°]', Cold.dip_deg, Cnew.dip_deg);
    write_cmp(fid, 'acq MAE [°]', Cold.acq.mae_deg, Cnew.acq.mae_deg);
    write_cmp(fid, 'steady MAE [°]', Cold.steady.mae_deg, Cnew.steady.mae_deg);
    write_cmp(fid, 'steady RMS [°]', Cold.steady.rms_deg, Cnew.steady.rms_deg);
    write_cmp(fid, 'steady p95 [°]', Cold.steady.p95_deg, Cnew.steady.p95_deg);
    write_cmp(fid, 'steady max\\|e\\| [°]', Cold.steady.max_deg, Cnew.steady.max_deg);
    fprintf(fid, '| persistent_ok | %s | %s | |\n\n', yn(Cold.persistent_ok), yn(Cnew.persistent_ok));

    fprintf(fid, '### Exact masks (new persistent)\n\n');
    fprintf(fid, '- BASE: settle_idx=%s t=%.4fs; mask_acq=1:%s (n=%d); mask_steady=%s:%d (n=%d); end_frac=0.88\n', ...
        mat2str(Bnew.settle_idx), Bnew.acq_time_s, mat2str(Bnew.settle_idx), Bnew.n_acq, ...
        mat2str(Bnew.settle_idx), Bnew.n_end, Bnew.n_steady);
    fprintf(fid, '- CLIMB: settle_idx=%s t=%.4fs; mask_acq=1:%s (n=%d); mask_steady=%s:%d (n=%d); end_frac=0.88\n\n', ...
        mat2str(Cnew.settle_idx), Cnew.acq_time_s, mat2str(Cnew.settle_idx), Cnew.n_acq, ...
        mat2str(Cnew.settle_idx), Cnew.n_end, Cnew.n_steady);

    fprintf(fid, '## Climb-FF gates (original) on corrected windows\n\n');
    fprintf(fid, 'Reference baseline = rescored λ=0 persistent windows (not published first_hold numbers).\n\n');
    fprintf(fid, '| Metric | baseline new | climb-FF new | Δ%% |\n|--------|-------------:|-------------:|---:|\n');
    fprintf(fid, '| dip [°] | %.4f | %.4f | %+.1f |\n', base_new.dip_deg, Cnew.dip_deg, -G.dip_improve_pct);
    fprintf(fid, '| acq MAE [°] | %.4f | %.4f | %+.1f |\n', base_new.acq_mae_deg, Cnew.acq.mae_deg, -G.acq_mae_improve_pct);
    fprintf(fid, '| settling [s] | %.2f | %.2f | %+.1f |\n', base_new.acq_s, Cnew.acq_time_s, ...
        100*(Cnew.acq_time_s-base_new.acq_s)/base_new.acq_s);
    fprintf(fid, '| steady RMS [°] | %.4f | %.4f | %+.1f |\n', base_new.steady_rms_deg, Cnew.steady.rms_deg, G.rms_reg_pct);
    fprintf(fid, '| steady p95 [°] | %.4f | %.4f | %+.1f |\n', base_new.steady_p95_deg, Cnew.steady.p95_deg, G.p95_reg_pct);
    fprintf(fid, '| steady MAE [°] | %.4f | %.4f | %+.1f |\n\n', base_new.steady_mae_deg, Cnew.steady.mae_deg, ...
        100*(Cnew.steady.mae_deg-base_new.steady_mae_deg)/base_new.steady_mae_deg);

    fprintf(fid, '| Gate | Result |\n|------|--------|\n');
    fprintf(fid, '| dip improve ≥30%% OR acq MAE ≥10%% | %s (dip %.1f%% / acqMAE %.1f%%) |\n', ...
        yn(G.g_improve), G.dip_improve_pct, G.acq_mae_improve_pct);
    fprintf(fid, '| steady RMS/p95 regression ≤2%% | %s (RMS %+.1f%% / p95 %+.1f%%) |\n', ...
        yn(G.g_steady), G.rms_reg_pct, G.p95_reg_pct);
    fprintf(fid, '| acq settling not worse | %s |\n', yn(G.g_acq));
    fprintf(fid, '| overshoot not worse | %s |\n', yn(G.g_os));
    fprintf(fid, '| sat ≤1%% | %s (%.2f%%) |\n', yn(G.g_sat), Cnew.elev_sat_pct);
    fprintf(fid, '| no new chatter | %s |\n', yn(G.g_chatter));
    fprintf(fid, '| **Overall climb-FF** | **%s** |\n\n', climb_class);

    fprintf(fid, 'Note: published climb-FF report used first_hold settle=3.35 s while |eθ| left ±0.5° at t≈3.52 s; ');
    fprintf(fid, 'persistent settle=%.2f s. Published-window gate recompute still %s (p95 reg %+0.1f%%).\n\n', ...
        Cnew.acq_time_s, tern(G_pubwin.pass,'PASS','FAIL'), G_pubwin.p95_reg_pct);

    fprintf(fid, '## Evidence\n\n');
    fprintf(fid, '- MATLAB: `run_pitch_xz_window_audit` (rescore only; no CPT)\n');
    fprintf(fid, '- %s\n- %s\n- %s\n', md_path, mat_path, png_path);
    fprintf(fid, '- inputs: suite_results/PITCH_XZ_TRACK.mat, PITCH_XZ_CLIMB_TRIM_FF.mat\n\n');

    fprintf(fid, '## Next target\n\n');
    if strcmp(climb_class, 'FAIL')
        fprintf(fid, 'Climb-FF remains FAIL under corrected persistent windows (steady p95/RMS gate). ');
        fprintf(fid, 'Next: fix late-climb |eθ| bias/overshoot that drives p95 above baseline, ');
        fprintf(fid, 'or a metric-gated trim/FF retune — without relaxing windows. Production stays baseline.\n');
    else
        fprintf(fid, 'Climb-FF PASS under corrected windows — consider controlled production promote after freeze checklist.\n');
    end
    fclose(fid);

    % Research log delta
    log_path = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    append_research_log(log_path, task_id, audit_pass, climb_class, Bold, Bnew, Cold, Cnew, G);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Audit=%s | climb-FF class=%s | repro_all=%s\n', ...
        tern(audit_pass,'PASS','FAIL'), climb_class, yn(repro.all));
    fprintf('BASE settle old/new = %.2f / %.2f s | CLIMB old/new = %.2f / %.2f s\n', ...
        Bold.acq_time_s, Bnew.acq_time_s, Cold.acq_time_s, Cnew.acq_time_s);
    fprintf('CLIMB new p95 reg = %+.1f%% | g_steady=%s\n', G.p95_reg_pct, yn(G.g_steady));
    fprintf('Wrote %s.{md,mat,png}\n', tag);
    assignin('base', 'PITCH_XZ_WINDOW_AUDIT_PASS', audit_pass);
end

function G = climb_gate(m, base)
    G = struct();
    G.dip_improve_pct = 100 * (base.dip_deg - m.dip_deg) / base.dip_deg;
    G.acq_mae_improve_pct = 100 * (base.acq_mae_deg - m.acq.mae_deg) / base.acq_mae_deg;
    G.g_improve = (G.dip_improve_pct >= 30) || (G.acq_mae_improve_pct >= 10);
    G.rms_reg_pct = 100 * (m.steady.rms_deg - base.steady_rms_deg) / base.steady_rms_deg;
    G.p95_reg_pct = 100 * (m.steady.p95_deg - base.steady_p95_deg) / base.steady_p95_deg;
    G.g_steady = (G.rms_reg_pct <= 2) && (G.p95_reg_pct <= 2);
    G.g_acq = ~isnan(m.acq_time_s) && ~isnan(base.acq_s) && (m.acq_time_s <= base.acq_s + 1e-9);
    G.g_os = ~isnan(m.overshoot_deg) && (m.overshoot_deg <= base.overshoot_deg + 1e-6);
    G.g_sat = ~isnan(m.elev_sat_pct) && (m.elev_sat_pct <= 1.0);
    G.g_chatter = ~isnan(m.chatter_dps) && ...
        (m.chatter_dps <= max(base.chatter_dps * 1.5, base.chatter_dps + 0.01));
    G.pass = G.g_improve && G.g_steady && G.g_acq && G.g_os && G.g_sat && G.g_chatter;
end

function [sat, chat] = elev_stats(L, mask, dt, lim, mref)
    if ~any(mask)
        sat = NaN; chat = NaN; return;
    end
    de = L.de(:);
    sat = 100 * mean(abs(de(mask)) >= 0.98 * lim);
    th = L.theta_phys(:);
    th_dot = [0; diff(th)] / dt;
    dth = th_dot(mask);
    if numel(dth) < 5
        if isfield(mref, 'chatter_dps')
            chat = mref.chatter_dps;
        elseif isfield(mref, 'pm') && isfield(mref.pm, 'pitch_chatter_dps')
            chat = mref.pm.pitch_chatter_dps;
        else
            chat = NaN;
        end
    else
        chat = rad2deg(std(hf_local(detrend(dth), dt)));
    end
end

function lim = evalin_delta_e_max()
    % Match init_parameters production elevator limit.
    lim = deg2rad(15);
end

function os = local_os(th, tr, m_acq, m_ss)
    if ~any(m_acq) || ~any(m_ss)
        os = NaN; return;
    end
    os = rad2deg(max(0, max(th(m_acq)) - mean(tr(m_ss))));
end

function area_mask(t, msk, e_max, col, a)
    if ~any(msk); return; end
    y = zeros(size(t));
    y(msk) = e_max;
    h = area(t, y, -e_max);
    h.FaceColor = col; h.FaceAlpha = a; h.EdgeColor = 'none';
end

function y = hf_local(x, dt)
    n = max(3, round(0.8 / dt));
    lf = filter(ones(n,1)/n, 1, x(:));
    y = x(:) - lf;
    y(1:min(n,numel(y))) = 0;
end

function write_cmp(fid, name, a, b)
    fprintf(fid, '| %s | %.4f | %.4f | %+.4f |\n', name, a, b, b - a);
end

function append_research_log(log_path, task_id, audit_pass, climb_class, Bold, Bnew, Cold, Cnew, G)
    if exist(log_path, 'file')
        fid = fopen(log_path, 'a');
    else
        fid = fopen(log_path, 'w');
        fprintf(fid, '# PITCH_CONTROL_RESEARCH_LOG\n\n');
        fprintf(fid, 'Running log of pitch-control experiments. Production stack unchanged unless noted.\n\n');
    end
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '- Audit (defs+reproduce): **%s**; climb-FF class under corrected windows: **%s**.\n', ...
        tern(audit_pass,'PASS','FAIL'), climb_class);
    fprintf(fid, '- Metric: inline first_hold → `compute_pitch_window_metrics` persistent ±0.5° to end-excl (s<0.88 s_tot).\n');
    fprintf(fid, '- BASE settle %.2f→%.2f s; CLIMB %.2f→%.2f s (old first-hold left band after 3.35 s).\n', ...
        Bold.acq_time_s, Bnew.acq_time_s, Cold.acq_time_s, Cnew.acq_time_s);
    fprintf(fid, '- Rescored climb vs rescored base: dip %+0.1f%%, acqMAE %+0.1f%%, ssRMS %+0.1f%%, ssp95 %+0.1f%%.\n', ...
        -G.dip_improve_pct, -G.acq_mae_improve_pct, G.rms_reg_pct, G.p95_reg_pct);
    fprintf(fid, '- Artifacts: suite_results/PITCH_XZ_WINDOW_AUDIT.{md,mat,png}. Production unchanged.\n');
    if strcmp(climb_class, 'PASS')
        fprintf(fid, '- Next: optional controlled climb-FF promote after freeze checklist (prod still baseline).\n\n');
    else
        fprintf(fid, '- Next: address late |eθ| that fails ss p95/RMS ≤2%% under persistent windows.\n\n');
    end
    fclose(fid);
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
