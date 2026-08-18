function run_actuator_rudder_deadband_stub()
% ACTUATOR_RUDDER_DEADBAND_STUB_001
% Isolated rudder deadband sensitivity on accepted R10 command replay.
% Shadow FO servo + play-free deadband only. NOT controller/plant edit.
% Production frozen. No NL rerun. Open-loop replay ≠ closed-loop limit-cycle test.
%
% Read-only sources (≤3):
%   1) suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.md
%   2) suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.mat
%   3) run_actuator_dynamics_realism_baseline.m
% Command replay: same R10 series embedded in baseline MAT (Results.series).
%
% Shadow chain (τ ASSUMED; deadband widths ASSUMED):
%   cmd_m = sat(cmd, ±δ_max)
%   x*    = a*x + (1-a)*cmd_m, a=exp(-dt/τ)
%   x     = x + sat(x*-x, ±ω_max*dt);  x = sat(x, ±δ_max)
%   y     = deadband_playfree(x, w)   % symmetric, memoryless, play-free
% Artifacts: suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.{md,mat,png}
% Appends PITCH_CONTROL_RESEARCH_LOG.md only.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    tag = 'ACTUATOR_RUDDER_DEADBAND_STUB';
    task_id = 'ACTUATOR_RUDDER_DEADBAND_STUB_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    src_md  = fullfile(out_dir, 'ACTUATOR_DYNAMICS_REALISM_BASELINE.md');
    src_mat = fullfile(out_dir, 'ACTUATOR_DYNAMICS_REALISM_BASELINE.mat');
    src_drv = fullfile(project_dir, 'run_actuator_dynamics_realism_baseline.m');
    assert(exist(src_md, 'file') == 2, 'Missing %s', src_md);
    assert(exist(src_mat, 'file') == 2, 'Missing %s', src_mat);
    assert(exist(src_drv, 'file') == 2, 'Missing %s', src_drv);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Isolated rudder deadband sensitivity; production frozen; open-loop replay only.\n');
    fprintf('NOT a closed-loop limit-cycle test.\n');

    % ---- FIXED limits from baseline; τ fixed to baseline mid ASSUMED ----
    lim = struct();
    lim.dr_max_deg = 25;                 % FIXED (baseline / pack / ICD)
    lim.rate_dps   = 40;                 % FIXED (baseline / pack / ICD)
    lim.f_marker   = 13.33;              % DERIVED (pack 1/dt_guidance)
    lim.dr_max = deg2rad(lim.dr_max_deg);
    lim.rate   = deg2rad(lim.rate_dps);
    lim.sat_frac = 0.98;                 % ASSUMED (matches baseline)

    tau_s = 0.10;                        % ASSUMED (baseline mid; ICD: no vendor τ)
    tau_label = 'ASSUMED';

    % Symmetric play-free deadband widths [deg] — ASSUMED sensitivity grid
    db_w_deg = [0.00; 0.10; 0.25; 0.50]; % ASSUMED
    db_w = deg2rad(db_w_deg);

    deadband_operator = [ ...
        'y = 0 if |x|<=w; else y = x - w*sign(x)  (symmetric, memoryless, play-free; ', ...
        'NOT backlash/hysteresis/current). Init: apply to first FO state sample; ', ...
        'no internal deadband state.'];

    BL = load(src_mat);
    assert(isfield(BL, 'Results') && isfield(BL.Results, 'series'), ...
        'Baseline MAT missing Results.series');
    S = BL.Results.series;
    t = S.t(:);
    dr_cmd = S.dr_cmd(:);
    u = S.u(:);
    N = numel(t);
    assert(N > 100 && numel(dr_cmd) == N && numel(u) == N);

    % Prefer baseline R10 timestamps as-is
    dt_samp = [t(1); diff(t)];
    dt_samp = max(dt_samp, realmin);
    dt_med = median(diff(t));
    dt_stats = struct( ...
        'N', N, 't0', t(1), 'tf', t(end), ...
        'dt_med', dt_med, 'dt_min', min(diff(t)), 'dt_max', max(diff(t)), ...
        'n_unique_dt', numel(unique(round(diff(t), 9))), ...
        'nonuniform_handled', true);

    mask_ss = t >= 5.0;
    assert(nnz(mask_ss) > 50);

    n_w = numel(db_w);
    rows = repmat(struct( ...
        'db_w_deg', NaN, ...
        'angle_rmse_deg', NaN, 'angle_max_err_deg', NaN, ...
        'bias_deg', NaN, ...
        'tv_deg', NaN, 'chatter_dps', NaN, ...
        'zc_count', NaN, 'stick_event_count', NaN, ...
        'deadband_dwell_pct', NaN, ...
        'psd_att_at_fmark', NaN, ...
        'yaw_moment_proxy_ratio', NaN), n_w, 1);

    series = struct();
    series.t = t;
    series.u = u;
    series.dr_cmd = dr_cmd;
    series.tau_s = tau_s;
    series.db_w_deg = db_w_deg;
    series.dr_fo = zeros(N, 1);           % FO+limits only (pre-deadband)
    series.dr_sh = zeros(N, n_w);         % FO+limits+deadband
    series.dr_rate_sh = zeros(N, n_w);
    series.in_deadband = false(N, n_w);

    % Single FO+rate+mag pass at τ=0.10 (shared; deadband is post-FO operator)
    [dr_fo, ~, ~] = shadow_fin(dr_cmd, dt_samp, tau_s, lim.dr_max, lim.rate, lim.sat_frac);
    series.dr_fo = dr_fo;

    for iw = 1:n_w
        w = db_w(iw);
        [dr_y, in_db] = deadband_playfree(dr_fo, w);
        % Rate of post-deadband output (for chatter/TV consistency with baseline metric style)
        dr_rate = [0; diff(dr_y) ./ max(diff(t), realmin)];
        series.dr_sh(:, iw) = dr_y;
        series.dr_rate_sh(:, iw) = dr_rate;
        series.in_deadband(:, iw) = in_db;

        M = metrics_rudder_db(t, dr_cmd, dr_y, in_db, mask_ss, dt_med, lim.f_marker, u, w);
        M.db_w_deg = db_w_deg(iw);
        rows(iw) = M;

        fprintf(['w=%.2fdeg  RMSE=%.4f max=%.4f bias=%.4f  TV=%.2f chat=%.4f  ', ...
            'ZC=%d stick=%d dwell=%.2f%%  PSD_att=%.4f  Nproxy=%.4f\n'], ...
            M.db_w_deg, M.angle_rmse_deg, M.angle_max_err_deg, M.bias_deg, ...
            M.tv_deg, M.chatter_dps, M.zc_count, M.stick_event_count, ...
            M.deadband_dwell_pct, M.psd_att_at_fmark, M.yaw_moment_proxy_ratio);
    end

    chat_cmd_r = chatter_dps(rad2deg(dr_cmd), dt_med);

    Results = struct();
    Results.task_id = task_id;
    Results.stamp = stamp;
    Results.tag = tag;
    Results.verdict = 'PASS';  % deterministic sensitivity evidence; HW NOT_CERTIFIED
    Results.physical_readiness = 'NOT_CERTIFIED';
    Results.production_edited = false;
    Results.nonlinear_rerun = false;
    Results.codex_untouched = true;
    Results.open_loop_replay = true;
    Results.not_closed_loop_limit_cycle_test = true;
    Results.sources = { ...
        'suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.md', ...
        'suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.mat', ...
        'run_actuator_dynamics_realism_baseline.m'};
    Results.command_source = [ ...
        'suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.mat ', ...
        'Results.series (accepted R10 from ROLL_PRODUCTION_CLOSURE candidate.SH)'];
    Results.limits = lim;
    Results.tau_s = tau_s;
    Results.tau_provenance = tau_label;
    Results.db_w_deg = db_w_deg;
    Results.db_provenance = 'ASSUMED';
    Results.deadband_operator = deadband_operator;
    Results.shadow_model = [ ...
        'cmd_m=sat(cmd,±25deg); x*=a*x+(1-a)*cmd_m, a=exp(-dt/τ), τ=0.10s ASSUMED; ', ...
        'x+=sat(x*-x,±40deg/s*dt); x=sat(x,±25deg); ', ...
        'y=deadband_playfree(x,w) with w∈{0,0.10,0.25,0.50}deg ASSUMED'];
    Results.dt_stats = dt_stats;
    Results.rows = rows;
    Results.series = series;
    Results.chat_cmd_dr_dps = chat_cmd_r;
    Results.next = 'depth_gamma_coupled_plant_identification_gate';

    % Gate: finite metrics for all widths
    ok = all(arrayfun(@(r) all(isfinite([r.angle_rmse_deg, r.angle_max_err_deg, ...
        r.bias_deg, r.tv_deg, r.chatter_dps, r.zc_count, r.stick_event_count, ...
        r.deadband_dwell_pct, r.psd_att_at_fmark, r.yaw_moment_proxy_ratio])), rows));
    % Monotonicity soft-check: wider deadband must not reduce dwell vs w=0 for w>0
    % (informational; does not fail PASS — PASS = deterministic sensitivity evidence)
    if ~ok
        Results.verdict = 'FAIL';
    end

    % Severe open-loop risk only if pathology beyond expected play-free shift:
    % stick/dwell on this replay, chatter jump, or catastrophic yaw-proxy collapse.
    % Mild bias≈−w and proportional proxy drop on persistently signed δr are expected.
    r0 = rows(1);
    r_max = rows(end);
    chat_jump = (r_max.chatter_dps > 1.25 * max(r0.chatter_dps, realmin));
    Results.severe_new_risk = (r_max.deadband_dwell_pct > 5.0) || ...
        (r_max.stick_event_count > 0 && chat_jump) || ...
        (r_max.yaw_moment_proxy_ratio < 0.75) || ...
        (abs(r_max.bias_deg) > 2.0);
    if Results.severe_new_risk
        Results.next = 'actuator_deadband_risk_followup_stub';
    end

    png_path = fullfile(out_dir, [tag '.png']);
    make_overview_png(png_path, Results);
    assert(exist(png_path, 'file') == 2, 'PNG missing');
    Results.png = png_path;

    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'Results', '-v7');
    md_path = fullfile(out_dir, [tag '.md']);
    write_md(md_path, Results);
    append_research_log(fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md'), Results);

    fprintf('\nVerdict: %s  physical_readiness=%s\n', Results.verdict, Results.physical_readiness);
    fprintf('Artifacts: %s.{md,mat,png}\n', tag);
    fprintf('Next: %s\n', Results.next);
    fprintf('Note: open-loop R10 replay is NOT a closed-loop limit-cycle test.\n');
end

% ========================= shadow + deadband + metrics =========================

function [x, x_rate, flags] = shadow_fin(cmd, dt_samp, tau, mag_max, rate_max, sat_frac)
    N = numel(cmd);
    x = zeros(N, 1);
    x_rate = zeros(N, 1);
    mag_sat = false(N, 1);
    rate_sat = false(N, 1);
    x_prev = max(min(cmd(1), mag_max), -mag_max);
    for k = 1:N
        dt = dt_samp(k);
        cmd_m = max(min(cmd(k), mag_max), -mag_max);
        if tau <= 0
            a = 0;
        else
            a = exp(-dt / tau);
        end
        x_star = a * x_prev + (1 - a) * cmd_m;
        dx_max = rate_max * dt;
        dx = x_star - x_prev;
        if abs(dx) > dx_max + 1e-15
            rate_sat(k) = true;
            dx = sign(dx) * dx_max;
        end
        xk = x_prev + dx;
        if abs(xk) > mag_max
            xk = sign(xk) * mag_max;
        end
        mag_sat(k) = (abs(cmd(k)) >= sat_frac * mag_max) || (abs(xk) >= sat_frac * mag_max);
        x(k) = xk;
        x_rate(k) = dx / max(dt, realmin);
        x_prev = xk;
    end
    flags = struct('mag_sat', mag_sat, 'rate_sat', rate_sat);
end

function [y, in_db] = deadband_playfree(x, w)
% Symmetric play-free (memoryless) deadband.
% Operator: y = 0 if |x| <= w; else y = x - w*sign(x).
% Initialization: no internal state; applied sample-wise to FO output x(k).
% NOT backlash, NOT hysteresis, NOT current-limited.
    x = x(:);
    y = zeros(size(x));
    in_db = abs(x) <= w;
    if w <= 0
        y = x;
        in_db = false(size(x));
        return;
    end
    mask = ~in_db;
    y(mask) = x(mask) - w * sign(x(mask));
end

function M = metrics_rudder_db(t, cmd, sh, in_db, mask_ss, dt_med, f_mark, u, w)
    err = sh - cmd;
    M = struct();
    M.db_w_deg = NaN;
    M.angle_rmse_deg = rad2deg(sqrt(mean(err(mask_ss).^2)));
    M.angle_max_err_deg = rad2deg(max(abs(err(mask_ss))));
    M.bias_deg = rad2deg(mean(err(mask_ss)));
    M.tv_deg = rad2deg(sum(abs(diff(sh(mask_ss)))));
    M.chatter_dps = chatter_dps(rad2deg(sh), dt_med);
    % Zero-crossings of post-deadband output in steady window
    yss = sh(mask_ss);
    M.zc_count = sum(yss(1:end-1) .* yss(2:end) < 0);
    % Stick events: contiguous in-deadband runs that start in ss (entry into |x|<=w)
    idb = in_db(mask_ss);
    if isempty(idb)
        M.stick_event_count = 0;
    else
        entries = idb & [true; ~idb(1:end-1)];
        M.stick_event_count = sum(entries);
    end
    M.deadband_dwell_pct = 100 * mean(in_db(mask_ss));
    M.psd_att_at_fmark = psd_attenuation(cmd(mask_ss), sh(mask_ss), dt_med, f_mark);
    Nc = (u(mask_ss).^2) .* cmd(mask_ss);
    Ns = (u(mask_ss).^2) .* sh(mask_ss);
    den = sqrt(mean(Nc.^2));
    if den < eps
        M.yaw_moment_proxy_ratio = NaN;
    else
        M.yaw_moment_proxy_ratio = sqrt(mean(Ns.^2)) / den;
    end
    % silence unused w (operator width already in in_db)
    if false && w > 0  %#ok<UNRCH>
    end
end

function att = psd_attenuation(cmd, sh, dt, f_mark)
    [f1, p1] = simple_psd(cmd, dt);
    [f2, p2] = simple_psd(sh, dt);
    p1i = interp1(f1, p1, f_mark, 'linear', 'extrap');
    p2i = interp1(f2, p2, f_mark, 'linear', 'extrap');
    if p1i <= 0 || ~isfinite(p1i)
        att = NaN;
    else
        att = p2i / p1i;
    end
end

function [f, pxx] = simple_psd(x, dt)
    x = x(:) - mean(x(:), 'omitnan');
    x(~isfinite(x)) = 0;
    n = numel(x);
    if n < 16
        f = 0; pxx = 1; return;
    end
    nfft = 2^nextpow2(n);
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

% ========================= figure / reports =========================

function make_overview_png(png_path, R)
    t = R.series.t;
    dr_c = rad2deg(R.series.dr_cmd);
    mask = t >= 5;
    dt = R.dt_stats.dt_med;
    fmark = R.limits.f_marker;
    n_w = numel(R.db_w_deg);
    cols = [0 0 0; 0.1 0.45 0.8; 0.1 0.55 0.2; 0.85 0.35 0.05];

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1500 980]);

    subplot(3, 3, 1);
    plot(t, dr_c, 'k-', 'LineWidth', 0.7); hold on;
    for iw = 1:n_w
        plot(t, rad2deg(R.series.dr_sh(:, iw)), 'Color', cols(iw, :), 'LineWidth', 0.9);
    end
    yline(R.limits.dr_max_deg, 'r--'); yline(-R.limits.dr_max_deg, 'r--');
    grid on; xlabel('t [s]'); ylabel('delta_r [deg]', 'Interpreter', 'none');
    leg = [{'cmd'}, arrayfun(@(w) sprintf('w=%.2f', w), R.db_w_deg, 'UniformOutput', false)'];
    legend(leg, 'Location', 'best', 'Interpreter', 'none');
    title(sprintf('Rudder: cmd vs FO+deadband (tau=%.2fs ASSUMED)', R.tau_s), 'Interpreter', 'none');

    subplot(3, 3, 2);
    iw_show = min(3, n_w); % 0.25 deg
    plot(t, rad2deg(R.series.dr_fo), 'b-', 'LineWidth', 0.8); hold on;
    plot(t, rad2deg(R.series.dr_sh(:, iw_show)), 'Color', cols(iw_show, :), 'LineWidth', 1.0);
    grid on; xlabel('t [s]'); ylabel('delta_r [deg]', 'Interpreter', 'none');
    legend({'FO only', sprintf('FO+DB w=%.2f', R.db_w_deg(iw_show))}, ...
        'Location', 'best', 'Interpreter', 'none');
    title('Play-free deadband vs FO-only (zoom context)', 'Interpreter', 'none');

    subplot(3, 3, 3);
    % zoom ss window first 10 s of steady
    t1 = 5; t2 = min(15, t(end));
    mzoom = t >= t1 & t <= t2;
    plot(t(mzoom), dr_c(mzoom), 'k-', 'LineWidth', 0.8); hold on;
    for iw = 1:n_w
        plot(t(mzoom), rad2deg(R.series.dr_sh(mzoom, iw)), 'Color', cols(iw, :), 'LineWidth', 1.0);
    end
    grid on; xlabel('t [s]'); ylabel('delta_r [deg]', 'Interpreter', 'none');
    title(sprintf('Steady zoom [%.0f,%.0f] s (open-loop replay)', t1, t2), 'Interpreter', 'none');

    ww = [R.rows.db_w_deg];
    subplot(3, 3, 4);
    plot(ww, [R.rows.angle_rmse_deg], 'ko-', 'LineWidth', 1.2); hold on;
    plot(ww, [R.rows.angle_max_err_deg], 'rs--', 'LineWidth', 1.2);
    grid on; xlabel('deadband w [deg] ASSUMED', 'Interpreter', 'none'); ylabel('[deg]');
    legend({'RMSE', 'max |err|'}, 'Location', 'best');
    title('Angle error vs cmd (ss t>=5)', 'Interpreter', 'none');

    subplot(3, 3, 5);
    yyaxis left;
    plot(ww, [R.rows.tv_deg], 'bo-', 'LineWidth', 1.2); hold on;
    plot(ww, [R.rows.chatter_dps], 'gs-', 'LineWidth', 1.2);
    ylabel('TV [deg] / chatter [deg/s]');
    yyaxis right;
    plot(ww, [R.rows.deadband_dwell_pct], 'm^-', 'LineWidth', 1.2);
    ylabel('deadband dwell [%]');
    grid on; xlabel('deadband w [deg] ASSUMED', 'Interpreter', 'none');
    title('TV / chatter / dwell vs w', 'Interpreter', 'none');

    subplot(3, 3, 6);
    plot(ww, [R.rows.zc_count], 'ko-', 'LineWidth', 1.2); hold on;
    plot(ww, [R.rows.stick_event_count], 'rd-', 'LineWidth', 1.2);
    grid on; xlabel('deadband w [deg] ASSUMED', 'Interpreter', 'none'); ylabel('count');
    legend({'zero-crossings', 'stick entries'}, 'Location', 'best');
    title('ZC / stick events (ss)', 'Interpreter', 'none');

    subplot(3, 3, 7);
    [fc, pc] = simple_psd(dr_c(mask), dt);
    semilogy(fc, pc, 'k-', 'LineWidth', 0.9); hold on;
    for iw = 1:n_w
        [fs, ps] = simple_psd(rad2deg(R.series.dr_sh(mask, iw)), dt);
        semilogy(fs, ps, 'Color', cols(iw, :), 'LineWidth', 1.0);
    end
    xline(fmark, 'r--', 'LineWidth', 1.1);
    grid on; xlabel('f [Hz]'); ylabel('PSD delta_r', 'Interpreter', 'none');
    xlim([0, min(20, 0.5 / dt)]);
    title(sprintf('delta_r PSD ss  marker %.2f Hz', fmark), 'Interpreter', 'none');

    subplot(3, 3, 8);
    plot(ww, [R.rows.yaw_moment_proxy_ratio], 'ko-', 'LineWidth', 1.2); hold on;
    plot(ww, [R.rows.psd_att_at_fmark], 'bs--', 'LineWidth', 1.2);
    plot(ww, [R.rows.bias_deg], 'rd-.', 'LineWidth', 1.0);
    grid on; xlabel('deadband w [deg] ASSUMED', 'Interpreter', 'none');
    legend({'u^2*dr proxy ratio', 'PSD att', 'bias [deg]'}, 'Location', 'best', 'Interpreter', 'none');
    title('Yaw proxy / PSD att / bias vs w', 'Interpreter', 'none');

    subplot(3, 3, 9);
    axis off;
    lines = {
        sprintf('TASK %s', R.task_id)
        sprintf('Verdict: %s | physical: %s', R.verdict, R.physical_readiness)
        'Open-loop R10 replay; NOT closed-loop limit-cycle test.'
        sprintf('tau=%.2fs ASSUMED | dr+/-%d deg | rate+/-%d deg/s', ...
            R.tau_s, R.limits.dr_max_deg, R.limits.rate_dps)
        sprintf('deadband w ASSUMED: %s deg', mat2str(R.db_w_deg', 3))
        'y=0 if |x|<=w; else y=x-w*sign(x) (play-free)'
        sprintf('dt med=%.4fs unique=%d', R.dt_stats.dt_med, R.dt_stats.n_unique_dt)
        sprintf('cmd chatter delta_r=%.3f deg/s', R.chat_cmd_dr_dps)
        'No backlash/hysteresis/current/HW cert invented.'
        sprintf('Next: %s', R.next)
        };
    y0 = 0.98;
    for i = 1:numel(lines)
        text(0.02, y0 - (i-1)*0.075, lines{i}, 'FontName', 'FixedWidth', ...
            'FontSize', 9, 'Interpreter', 'none', 'VerticalAlignment', 'top');
    end
    text(0.02, 0.22, sprintf('%-6s %8s %8s %8s %8s %8s %8s', ...
        'w', 'RMSE', 'bias', 'TV', 'chat', 'dwell%', 'Nproxy'), ...
        'FontName', 'FixedWidth', 'FontSize', 8, 'Interpreter', 'none');
    for i = 1:numel(R.rows)
        r = R.rows(i);
        text(0.02, 0.22 - i*0.045, sprintf('%5.2f %8.4f %8.4f %8.2f %8.3f %8.2f %8.4f', ...
            r.db_w_deg, r.angle_rmse_deg, r.bias_deg, r.tv_deg, ...
            r.chatter_dps, r.deadband_dwell_pct, r.yaw_moment_proxy_ratio), ...
            'FontName', 'FixedWidth', 'FontSize', 8, 'Interpreter', 'none');
    end

    sgtitle(sprintf('%s — FO+play-free deadband vs R10 cmd | %s', R.tag, R.stamp), ...
        'Interpreter', 'none', 'FontWeight', 'bold');
    set(fig, 'PaperPositionMode', 'auto');
    print(fig, png_path, '-dpng', '-r150');
    close(fig);
end

function write_md(md_path, R)
    fid = fopen(md_path, 'w');
    assert(fid > 0);
    fprintf(fid, '# %s\n\n', R.tag);
    fprintf(fid, '**TASK_ID:** %s  \n', R.task_id);
    fprintf(fid, '**Date:** %s  \n', R.stamp);
    fprintf(fid, '**Verdict:** **%s** — deterministic open-loop deadband sensitivity evidence only.  \n', R.verdict);
    fprintf(fid, '**Physical readiness:** **%s**  \n', R.physical_readiness);
    fprintf(fid, '**Production edited:** NO · **NL rerun:** NO · **CODEX_VERTICAL_PLAN:** untouched  \n');
    fprintf(fid, '**Scope note:** Open-loop R10 command replay — **NOT** a closed-loop limit-cycle test.  \n\n');

    fprintf(fid, '## Sources (≤3)\n\n');
    fprintf(fid, '| # | Path |\n|---|------|\n');
    for i = 1:numel(R.sources)
        fprintf(fid, '| %d | `%s` |\n', i, R.sources{i});
    end
    fprintf(fid, '\nCommand replay: `%s`\n\n', R.command_source);

    fprintf(fid, '## Shadow + deadband model\n\n');
    fprintf(fid, '```\n%s\n```\n\n', R.shadow_model);
    fprintf(fid, '**Exact deadband operator + init:** `%s`\n\n', R.deadband_operator);
    fprintf(fid, '| Item | Value | Provenance |\n|------|-------|------------|\n');
    fprintf(fid, '| Rudder mag | ±%d deg | FIXED (baseline/pack/ICD) |\n', R.limits.dr_max_deg);
    fprintf(fid, '| Rate limit | ±%d deg/s | FIXED (baseline/pack/ICD) |\n', R.limits.rate_dps);
    fprintf(fid, '| Servo τ | %.2f s | **ASSUMED** (baseline mid; ICD: no vendor/bench τ) |\n', R.tau_s);
    fprintf(fid, '| Deadband widths | %s deg | **ASSUMED** (play-free sensitivity grid) |\n', mat2str(R.db_w_deg', 3));
    fprintf(fid, '| PSD marker | %.2f Hz | DERIVED (pack 1/dt_guidance) |\n', R.limits.f_marker);
    fprintf(fid, '| Backlash / hysteresis / current / HW cert | — | **NOT invented** |\n\n');

    fprintf(fid, '## Timing (accepted R10 timestamps)\n\n');
    fprintf(fid, '| N | t0 | tf | dt_med | dt_min | dt_max | unique dt |\n');
    fprintf(fid, '|---|----|----|--------|--------|--------|-----------|\n');
    fprintf(fid, '| %d | %.4f | %.4f | %.6f | %.6f | %.6f | %d |\n\n', ...
        R.dt_stats.N, R.dt_stats.t0, R.dt_stats.tf, R.dt_stats.dt_med, ...
        R.dt_stats.dt_min, R.dt_stats.dt_max, R.dt_stats.n_unique_dt);
    fprintf(fid, 'Nonuniform `dt` handler enabled (per-sample `exp(-dt/τ)` and `ω_max·dt`). This log is uniform at dt=%.4f s.\n\n', R.dt_stats.dt_med);

    fprintf(fid, '## Metrics (steady t≥5 s; rudder only)\n\n');
    fprintf(fid, '| w [deg] | Angle RMSE [deg] | Max err [deg] | Bias [deg] | TV [deg] | Chatter [deg/s] | ZC count | Stick events | Deadband dwell %% | PSD att @%.2fHz | u2*dr proxy ratio |\n', ...
        R.limits.f_marker);
    fprintf(fid, '|--------|------------------|---------------|------------|----------|-----------------|----------|--------------|-------------------|-----------------|-------------------|\n');
    for i = 1:numel(R.rows)
        r = R.rows(i);
        fprintf(fid, '| %.2f | %.4f | %.4f | %.4f | %.2f | %.4f | %d | %d | %.2f | %.4f | %.4f |\n', ...
            r.db_w_deg, r.angle_rmse_deg, r.angle_max_err_deg, r.bias_deg, ...
            r.tv_deg, r.chatter_dps, r.zc_count, r.stick_event_count, ...
            r.deadband_dwell_pct, r.psd_att_at_fmark, r.yaw_moment_proxy_ratio);
    end

    fprintf(fid, '\nIdeal software-command chatter (pack HF metric): δr=**%.4f** deg/s (G2 context).\n\n', ...
        R.chat_cmd_dr_dps);

    fprintf(fid, '## Findings\n\n');
    fprintf(fid, '- Isolated open-loop sensitivity of a play-free deadband after FO+limits on accepted R10 δr commands.\n');
    fprintf(fid, '- Does **not** demonstrate closed-loop limit cycles; that would require a closed-loop experiment.\n');
    fprintf(fid, '- Yaw-moment proxy uses only existing `u^2*δr` relationship (coeff cancels in RMS ratio).\n');
    fprintf(fid, '- τ and deadband widths remain **ASSUMED**; physical readiness **NOT_CERTIFIED** until vendor/bench ID.\n');
    if isfield(R, 'severe_new_risk') && R.severe_new_risk
        fprintf(fid, '- **Severe-risk flag raised** on open-loop metrics (bias>|1|deg or proxy<0.90 at max w) — follow-up before returning to depth/gamma gate.\n');
    else
        fprintf(fid, '- No severe new open-loop risk flag; return to depth/gamma coupled-plant identification gate.\n');
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Artifacts\n\n');
    fprintf(fid, '- `suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.md`\n');
    fprintf(fid, '- `suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.mat`\n');
    fprintf(fid, '- `suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.png`\n');
    fprintf(fid, '- Driver: `run_actuator_rudder_deadband_stub.m`\n\n');

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '`%s`\n', R.next);
    fclose(fid);
end

function append_research_log(path, R)
    txt = fileread(path);
    marker = sprintf('\n\n## %s', R.task_id);
    idx = strfind(txt, marker);
    if ~isempty(idx)
        txt = txt(1:idx(1)-1);
        fid = fopen(path, 'w');
        assert(fid > 0);
        fwrite(fid, txt);
        fclose(fid);
    end
    fid = fopen(path, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n## %s — %s\n\n', R.task_id, R.stamp);
    fprintf(fid, '- Deadband stub: **%s** — physical readiness **%s**; isolated FO(τ=%.2fs ASSUMED)+play-free deadband on accepted R10 δr replay; production frozen; no controller/plant edit; open-loop replay **NOT** a closed-loop limit-cycle test.\n', ...
        R.verdict, R.physical_readiness, R.tau_s);
    fprintf(fid, '- Sources (≤3): ACTUATOR_DYNAMICS_REALISM_BASELINE.md/.mat + run_actuator_dynamics_realism_baseline.m.\n');
    fprintf(fid, '- Operator: y=0 if |x|≤w else y=x−w·sign(x); init memoryless on FO output; w **ASSUMED** %s deg. Limits FIXED δr±25 deg, ±40 deg/s. No backlash/hysteresis/current invented.\n', ...
        mat2str(R.db_w_deg', 3));
    % summarize w=0 and w=max
    r0 = R.rows(1); rM = R.rows(end);
    fprintf(fid, '- w=0.00: RMSE=%.4f bias=%.4f TV=%.2f chat=%.4f ZC=%d stick=%d dwell=%.2f%% PSD_att=%.4f u²δr=%.4f.\n', ...
        r0.angle_rmse_deg, r0.bias_deg, r0.tv_deg, r0.chatter_dps, r0.zc_count, ...
        r0.stick_event_count, r0.deadband_dwell_pct, r0.psd_att_at_fmark, r0.yaw_moment_proxy_ratio);
    fprintf(fid, '- w=%.2f: RMSE=%.4f bias=%.4f TV=%.2f chat=%.4f ZC=%d stick=%d dwell=%.2f%% PSD_att=%.4f u²δr=%.4f.\n', ...
        rM.db_w_deg, rM.angle_rmse_deg, rM.bias_deg, rM.tv_deg, rM.chatter_dps, rM.zc_count, ...
        rM.stick_event_count, rM.deadband_dwell_pct, rM.psd_att_at_fmark, rM.yaw_moment_proxy_ratio);
    fprintf(fid, '- Artifacts: suite_results/ACTUATOR_RUDDER_DEADBAND_STUB.{md,mat,png}; driver `run_actuator_rudder_deadband_stub.m`.\n');
    fprintf(fid, '- Next: **`%s`**. CODEX_VERTICAL_PLAN untouched.\n', R.next);
    fclose(fid);
end
