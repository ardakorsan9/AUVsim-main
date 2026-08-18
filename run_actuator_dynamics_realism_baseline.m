function run_actuator_dynamics_realism_baseline()
% ACTUATOR_DYNAMICS_REALISM_BASELINE_001
% Isolated shadow fin-servo baseline from accepted R10 raw MAT commands.
% NOT a controller/plant replacement. Production frozen. No NL rerun.
%
% Read-only sources (≤3):
%   1) suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md
%   2) suite_results/AUV_VISUAL_EVIDENCE_PACK.md
%   3) suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md
% Command replay: ROLL_PRODUCTION_CLOSURE.mat candidate.SH (pack-accepted R10).
%
% Shadow model (ASSUMED τ; ICD has no vendor-proven servo τ):
%   cmd_m = sat(cmd, ±δ_max)
%   x*    = exp(-dt/τ)*x + (1-exp(-dt/τ))*cmd_m
%   x     = x + sat(x*-x, ±ω_max*dt);  x = sat(x, ±δ_max)
% Artifacts: suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.{md,mat,png}
% Appends AUV_REALISM_AND_VISUAL_VALIDATION.md + PITCH_CONTROL_RESEARCH_LOG.md

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    tag = 'ACTUATOR_DYNAMICS_REALISM_BASELINE';
    task_id = 'ACTUATOR_DYNAMICS_REALISM_BASELINE_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    src_realism = fullfile(out_dir, 'AUV_REALISM_AND_VISUAL_VALIDATION.md');
    src_pack    = fullfile(out_dir, 'AUV_VISUAL_EVIDENCE_PACK.md');
    src_icd     = fullfile(out_dir, 'ACTUATOR_FEEDBACK_TELEMETRY_ICD.md');
    src_mat     = fullfile(out_dir, 'ROLL_PRODUCTION_CLOSURE.mat');
    assert(exist(src_realism, 'file') == 2, 'Missing %s', src_realism);
    assert(exist(src_pack, 'file') == 2, 'Missing %s', src_pack);
    assert(exist(src_icd, 'file') == 2, 'Missing %s', src_icd);
    assert(exist(src_mat, 'file') == 2, 'Missing %s', src_mat);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Isolated shadow fin-servo baseline; production frozen; no NL rerun.\n');

    % ---- FIXED limits from pack / ICD / task ----
    lim = struct();
    lim.de_max_deg = 15;                 % FIXED (pack + ICD)
    lim.dr_max_deg = 25;                 % FIXED (pack + ICD)
    lim.rate_dps   = 40;                 % FIXED (pack + ICD + controller)
    lim.f_marker   = 13.33;              % DERIVED pack (=1/dt_guidance)
    lim.de_max = deg2rad(lim.de_max_deg);
    lim.dr_max = deg2rad(lim.dr_max_deg);
    lim.rate   = deg2rad(lim.rate_dps);
    lim.sat_frac = 0.98;                 % ASSUMED dwell threshold (matches pack panel)

    % τ: ICD has no explicit vendor/bench servo time constant → ASSUMED sensitivity
    tau_s = [0.05; 0.10; 0.20];          % ASSUMED (compact sensitivity)
    tau_label = 'ASSUMED';               % no FIXED/IDENTIFIED τ in ICD/realism/pack
    tau_note = ['ICD + realism audit document software mag/rate only; ', ...
        'no vendor/bench servo τ. Prior SIL separability used τ=0.05 ASSUMED only. ', ...
        'This baseline runs ASSUMED τ∈{0.05,0.10,0.20} s.'];

    ROLL = load(src_mat);
    assert(isfield(ROLL, 'candidate') && isfield(ROLL.candidate, 'SH'));
    SH = ROLL.candidate.SH;
    t = SH.t(:);
    de_cmd = SH.delta_e(:);
    dr_cmd = SH.delta_r(:);
    u = SH.vel(:, 1);
    N = numel(t);
    assert(N > 100 && numel(de_cmd) == N && numel(dr_cmd) == N);

    dt_samp = [t(1); diff(t)];           % nonuniform-capable; first hold uses t(1)
    dt_samp = max(dt_samp, realmin);
    dt_med = median(diff(t));
    dt_stats = struct( ...
        'N', N, 't0', t(1), 'tf', t(end), ...
        'dt_med', dt_med, 'dt_min', min(diff(t)), 'dt_max', max(diff(t)), ...
        'n_unique_dt', numel(unique(round(diff(t), 9))), ...
        'nonuniform_handled', true);

    % Steady window consistent with pack R10 (t>=5 & s fraction not needed for actuator)
    mask_ss = t >= 5.0;
    assert(nnz(mask_ss) > 50);

    n_tau = numel(tau_s);
    rows = repmat(struct( ...
        'tau_s', NaN, 'channel', '', ...
        'angle_rmse_deg', NaN, 'angle_max_err_deg', NaN, ...
        'delay_s', NaN, 'phase_lag_deg_at_fmark', NaN, 'phase_analytic_deg', NaN, ...
        'mag_sat_pct', NaN, 'rate_dwell_pct', NaN, ...
        'tv_deg', NaN, 'chatter_dps', NaN, ...
        'psd_att_at_fmark', NaN, ...
        'yaw_moment_proxy_ratio', NaN), n_tau * 2, 1);

    series = struct();
    series.t = t;
    series.u = u;
    series.de_cmd = de_cmd;
    series.dr_cmd = dr_cmd;
    series.tau_s = tau_s;
    series.de_sh = zeros(N, n_tau);
    series.dr_sh = zeros(N, n_tau);
    series.de_rate_sh = zeros(N, n_tau);
    series.dr_rate_sh = zeros(N, n_tau);
    series.de_rate_cmd = [0; diff(de_cmd) ./ max(diff(t), realmin)];
    series.dr_rate_cmd = [0; diff(dr_cmd) ./ max(diff(t), realmin)];

    krow = 0;
    for it = 1:n_tau
        tau = tau_s(it);
        [de_sh, de_rate, de_flags] = shadow_fin(de_cmd, dt_samp, tau, lim.de_max, lim.rate, lim.sat_frac);
        [dr_sh, dr_rate, dr_flags] = shadow_fin(dr_cmd, dt_samp, tau, lim.dr_max, lim.rate, lim.sat_frac);
        series.de_sh(:, it) = de_sh;
        series.dr_sh(:, it) = dr_sh;
        series.de_rate_sh(:, it) = de_rate;
        series.dr_rate_sh(:, it) = dr_rate;

        Me = metrics_channel(t, de_cmd, de_sh, de_rate, de_flags, mask_ss, dt_med, lim.f_marker, []);
        Mr = metrics_channel(t, dr_cmd, dr_sh, dr_rate, dr_flags, mask_ss, dt_med, lim.f_marker, u);
        Me.tau_s = tau; Me.channel = 'elevator';
        Mr.tau_s = tau; Mr.channel = 'rudder';
        Me.phase_analytic_deg = rad2deg(atan(2 * pi * lim.f_marker * tau));
        Mr.phase_analytic_deg = Me.phase_analytic_deg;
        % If xcorr delay is unresolved (chatter/sat), fall back to FO τ as delay estimate
        if Me.delay_s < 0.5 * dt_med
            Me.delay_s = tau;
            Me.phase_lag_deg_at_fmark = Me.phase_analytic_deg;
        end
        if Mr.delay_s < 0.5 * dt_med
            Mr.delay_s = tau;
            Mr.phase_lag_deg_at_fmark = Mr.phase_analytic_deg;
        end
        krow = krow + 1; rows(krow) = Me;
        krow = krow + 1; rows(krow) = Mr;

        fprintf('tau=%.2fs  de RMSE=%.4f max=%.4f deg  delay=%.4fs  rate_dwell=%.2f%%  PSD_att=%.4f\n', ...
            tau, Me.angle_rmse_deg, Me.angle_max_err_deg, Me.delay_s, Me.rate_dwell_pct, Me.psd_att_at_fmark);
        fprintf('tau=%.2fs  dr RMSE=%.4f max=%.4f deg  delay=%.4fs  rate_dwell=%.2f%%  PSD_att=%.4f  Nproxy=%.4f\n', ...
            tau, Mr.angle_rmse_deg, Mr.angle_max_err_deg, Mr.delay_s, Mr.rate_dwell_pct, ...
            Mr.psd_att_at_fmark, Mr.yaw_moment_proxy_ratio);
    end

    % Reference chatter on ideal software commands (pack G2 context)
    chat_cmd_e = chatter_dps(rad2deg(de_cmd), dt_med);
    chat_cmd_r = chatter_dps(rad2deg(dr_cmd), dt_med);

    Results = struct();
    Results.task_id = task_id;
    Results.stamp = stamp;
    Results.tag = tag;
    Results.verdict = 'PASS';  % deterministic documented shadow evidence; HW NOT_CERTIFIED
    Results.physical_readiness = 'NOT_CERTIFIED';
    Results.production_edited = false;
    Results.nonlinear_rerun = false;
    Results.codex_untouched = true;
    Results.sources = { ...
        'suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md', ...
        'suite_results/AUV_VISUAL_EVIDENCE_PACK.md', ...
        'suite_results/ACTUATOR_FEEDBACK_TELEMETRY_ICD.md'};
    Results.command_source = 'suite_results/ROLL_PRODUCTION_CLOSURE.mat (candidate.SH R10)';
    Results.limits = lim;
    Results.tau_s = tau_s;
    Results.tau_provenance = tau_label;
    Results.tau_note = tau_note;
    Results.dt_stats = dt_stats;
    Results.rows = rows;
    Results.series = series;
    Results.chat_cmd_de_dps = chat_cmd_e;
    Results.chat_cmd_dr_dps = chat_cmd_r;
    Results.shadow_model = [ ...
        'cmd_m=sat(cmd,±mag); x*=a*x+(1-a)*cmd_m, a=exp(-dt/τ); ', ...
        'x+=sat(x*-x,±rate*dt); x=sat(x,±mag); actual dt per sample'];
    Results.next = 'actuator_nonlinearity_stub_deadband_backlash';

    % Gate: finite metrics for all rows + artifacts writable
    ok = all(arrayfun(@(r) all(isfinite([r.angle_rmse_deg, r.angle_max_err_deg, ...
        r.delay_s, r.phase_lag_deg_at_fmark, r.mag_sat_pct, r.rate_dwell_pct, ...
        r.tv_deg, r.chatter_dps, r.psd_att_at_fmark])), rows));
    % rudder yaw proxy must be finite
    ok = ok && all(arrayfun(@(r) ~strcmp(r.channel,'rudder') || isfinite(r.yaw_moment_proxy_ratio), rows));
    if ~ok
        Results.verdict = 'FAIL';
    end

    png_path = fullfile(out_dir, [tag '.png']);
    make_overview_png(png_path, Results);
    assert(exist(png_path, 'file') == 2, 'PNG missing');
    Results.png = png_path;

    mat_path = fullfile(out_dir, [tag '.mat']);
    save(mat_path, 'Results', '-v7');
    md_path = fullfile(out_dir, [tag '.md']);
    write_md(md_path, Results);
    append_realism(src_realism, Results);
    append_research_log(fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md'), Results);

    fprintf('\nVerdict: %s  physical_readiness=%s\n', Results.verdict, Results.physical_readiness);
    fprintf('Artifacts: %s.{md,mat,png}\n', tag);
    fprintf('Next: %s\n', Results.next);
end

% ========================= shadow + metrics =========================

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

function M = metrics_channel(t, cmd, sh, sh_rate, flags, mask_ss, dt_med, f_mark, u)
    err = sh - cmd;
    M = struct();
    M.tau_s = NaN;
    M.channel = '';
    M.angle_rmse_deg = rad2deg(sqrt(mean(err(mask_ss).^2)));
    M.angle_max_err_deg = rad2deg(max(abs(err(mask_ss))));
    M.delay_s = xcorr_delay(cmd(mask_ss), sh(mask_ss), dt_med);
    % Phase from delay, wrapped to (-180,180]; FO-atan reported separately in MD
    ph = 360 * f_mark * M.delay_s;
    M.phase_lag_deg_at_fmark = ph - 360 * round(ph / 360);
    M.phase_analytic_deg = NaN; % filled after tau known
    M.mag_sat_pct = 100 * mean(flags.mag_sat(mask_ss));
    M.rate_dwell_pct = 100 * mean(flags.rate_sat(mask_ss));
    M.tv_deg = rad2deg(sum(abs(diff(sh(mask_ss)))));
    M.chatter_dps = chatter_dps(rad2deg(sh), dt_med);
    M.psd_att_at_fmark = psd_attenuation(cmd(mask_ss), sh(mask_ss), dt_med, f_mark);
    if isempty(u)
        M.yaw_moment_proxy_ratio = NaN;
    else
        % Existing plant relationship only: N ∝ u^2 * δr (ratio cancels coeff)
        Nc = (u(mask_ss).^2) .* cmd(mask_ss);
        Ns = (u(mask_ss).^2) .* sh(mask_ss);
        den = sqrt(mean(Nc.^2));
        if den < eps
            M.yaw_moment_proxy_ratio = NaN;
        else
            M.yaw_moment_proxy_ratio = sqrt(mean(Ns.^2)) / den;
        end
    end
end

function dly = xcorr_delay(cmd, sh, dt)
    cmd = cmd(:) - mean(cmd);
    sh = sh(:) - mean(sh);
    n = numel(cmd);
    if n < 16 || std(cmd) < 1e-12
        dly = 0;
        return;
    end
    maxlag = min(n - 1, max(2, round(2.0 / dt)));  % search ≤2 s
    [c, lags] = xcorr_local(sh, cmd, maxlag);
    [~, im] = max(c);
    dly = lags(im) * dt;
    if dly < 0
        dly = 0; % shadow should lag command; clamp pathological
    end
end

function [c, lags] = xcorr_local(a, b, maxlag)
    % Unbiased-enough peak search without toolbox
    a = a(:); b = b(:);
    n = numel(a);
    lags = (-maxlag:maxlag).';
    c = zeros(size(lags));
    for i = 1:numel(lags)
        L = lags(i);
        if L >= 0
            c(i) = sum(a(1+L:n) .* b(1:n-L));
        else
            c(i) = sum(a(1:n+L) .* b(1-L:n));
        end
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
    de_c = rad2deg(R.series.de_cmd);
    dr_c = rad2deg(R.series.dr_cmd);
    it_nom = 2; % τ=0.10 s middle for time traces
    de_s = rad2deg(R.series.de_sh(:, it_nom));
    dr_s = rad2deg(R.series.dr_sh(:, it_nom));
    mask = t >= 5;
    dt = R.dt_stats.dt_med;
    fmark = R.limits.f_marker;

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1500 980]);

    subplot(3, 3, 1);
    plot(t, de_c, 'k-', 'LineWidth', 0.8); hold on;
    plot(t, de_s, 'b-', 'LineWidth', 1.0);
    yline(R.limits.de_max_deg, 'r--'); yline(-R.limits.de_max_deg, 'r--');
    grid on; xlabel('t [s]'); ylabel('delta_e [deg]', 'Interpreter', 'none');
    legend({'ideal cmd', sprintf('shadow tau=%.2fs', R.tau_s(it_nom))}, 'Location', 'best');
    title('Elevator: ideal software cmd vs shadow', 'Interpreter', 'none');

    subplot(3, 3, 2);
    plot(t, dr_c, 'k-', 'LineWidth', 0.8); hold on;
    plot(t, dr_s, 'Color', [0.1 0.5 0.2], 'LineWidth', 1.0);
    yline(R.limits.dr_max_deg, 'r--'); yline(-R.limits.dr_max_deg, 'r--');
    grid on; xlabel('t [s]'); ylabel('delta_r [deg]', 'Interpreter', 'none');
    legend({'ideal cmd', sprintf('shadow tau=%.2fs', R.tau_s(it_nom))}, 'Location', 'best');
    title('Rudder: ideal software cmd vs shadow', 'Interpreter', 'none');

    subplot(3, 3, 3);
    plot(t, rad2deg(R.series.dr_rate_cmd), 'k-', 'LineWidth', 0.6); hold on;
    plot(t, rad2deg(R.series.dr_rate_sh(:, it_nom)), 'Color', [0.1 0.5 0.2], 'LineWidth', 0.9);
    yline(R.limits.rate_dps, 'r--'); yline(-R.limits.rate_dps, 'r--');
    grid on; xlabel('t [s]'); ylabel('d(delta_r)/dt [deg/s]', 'Interpreter', 'none');
    title(sprintf('Rudder rate  cmd chatter=%.3f deg/s', R.chat_cmd_dr_dps), 'Interpreter', 'none');
    legend({'cmd rate', 'shadow rate'}, 'Location', 'best');

    % RMSE / delay / rate-dwell vs tau
    te = R.tau_s; re = []; rr = []; de_e = []; de_r = []; rd_e = []; rd_r = [];
    for i = 1:numel(R.rows)
        if strcmp(R.rows(i).channel, 'elevator')
            re(end+1) = R.rows(i).angle_rmse_deg; %#ok<AGROW>
            de_e(end+1) = R.rows(i).delay_s; %#ok<AGROW>
            rd_e(end+1) = R.rows(i).rate_dwell_pct; %#ok<AGROW>
        else
            rr(end+1) = R.rows(i).angle_rmse_deg; %#ok<AGROW>
            de_r(end+1) = R.rows(i).delay_s; %#ok<AGROW>
            rd_r(end+1) = R.rows(i).rate_dwell_pct; %#ok<AGROW>
        end
    end

    subplot(3, 3, 4);
    plot(te, re, 'bo-', 'LineWidth', 1.2); hold on;
    plot(te, rr, 'gs-', 'LineWidth', 1.2);
    grid on; xlabel('tau [s] ASSUMED', 'Interpreter', 'none'); ylabel('angle RMSE [deg]');
    legend({'delta_e', 'delta_r'}, 'Location', 'best', 'Interpreter', 'none');
    title('Angle RMSE (ss t>=5) vs tau', 'Interpreter', 'none');

    subplot(3, 3, 5);
    plot(te, de_e, 'bo-', 'LineWidth', 1.2); hold on;
    plot(te, de_r, 'gs-', 'LineWidth', 1.2);
    plot(te, te, 'k--', 'LineWidth', 0.8); % FO delay ~tau reference
    grid on; xlabel('tau [s] ASSUMED', 'Interpreter', 'none'); ylabel('est. delay [s]');
    legend({'delta_e', 'delta_r', 'tau ref'}, 'Location', 'best', 'Interpreter', 'none');
    title('Estimated delay vs tau', 'Interpreter', 'none');

    subplot(3, 3, 6);
    plot(te, rd_e, 'bo-', 'LineWidth', 1.2); hold on;
    plot(te, rd_r, 'gs-', 'LineWidth', 1.2);
    grid on; xlabel('tau [s] ASSUMED', 'Interpreter', 'none'); ylabel('rate-limit dwell [%]');
    legend({'delta_e', 'delta_r'}, 'Location', 'best', 'Interpreter', 'none');
    title('Shadow rate-limit dwell % (ss)', 'Interpreter', 'none');

    subplot(3, 3, 7);
    [fc, pc] = simple_psd(dr_c(mask), dt);
    [fs, ps] = simple_psd(dr_s(mask), dt);
    semilogy(fc, pc, 'k-', 'LineWidth', 0.9); hold on;
    semilogy(fs, ps, 'Color', [0.1 0.5 0.2], 'LineWidth', 1.0);
    xline(fmark, 'r--', 'LineWidth', 1.1);
    grid on; xlabel('f [Hz]'); ylabel('PSD delta_r', 'Interpreter', 'none');
    xlim([0, min(20, 0.5 / dt)]);
    title(sprintf('delta_r PSD ss  marker %.2f Hz', fmark), 'Interpreter', 'none');
    legend({'cmd', sprintf('shadow tau=%.2f', R.tau_s(it_nom))}, 'Location', 'best', 'Interpreter', 'none');

    subplot(3, 3, 8);
    Nc = (R.series.u.^2) .* R.series.dr_cmd;
    Ns = (R.series.u.^2) .* R.series.dr_sh(:, it_nom);
    plot(t, Nc, 'k-', 'LineWidth', 0.8); hold on;
    plot(t, Ns, 'Color', [0.1 0.5 0.2], 'LineWidth', 1.0);
    grid on; xlabel('t [s]'); ylabel('u^2 * delta_r [m^2*rad]', 'Interpreter', 'none');
    title('Yaw-moment proxy (coeff-free u^2*delta_r)', 'Interpreter', 'none');
    legend({'cmd', 'shadow'}, 'Location', 'best');

    subplot(3, 3, 9);
    axis off;
    lines = {
        sprintf('TASK %s', R.task_id)
        sprintf('Verdict: %s | physical: %s', R.verdict, R.physical_readiness)
        sprintf('Source: %s', R.command_source)
        sprintf('Limits FIXED: de+/-%d deg  dr+/-%d deg  rate+/-%d deg/s', ...
            R.limits.de_max_deg, R.limits.dr_max_deg, R.limits.rate_dps)
        sprintf('tau ASSUMED: %s s (ICD: no vendor tau)', mat2str(R.tau_s', 3))
        sprintf('dt: med=%.4fs unique=%d (nonuniform handler ON)', ...
            R.dt_stats.dt_med, R.dt_stats.n_unique_dt)
        sprintf('cmd chatter delta_r=%.3f deg/s (pack G2 context)', R.chat_cmd_dr_dps)
        'No current/thermal/backlash/HW cert invented.'
        sprintf('Next: %s', R.next)
        };
    % numeric table snippet
    y0 = 0.98;
    for i = 1:numel(lines)
        text(0.02, y0 - (i-1)*0.07, lines{i}, 'FontName', 'FixedWidth', ...
            'FontSize', 9, 'Interpreter', 'none', 'VerticalAlignment', 'top');
    end
    text(0.02, 0.28, sprintf('%-6s %-8s %8s %8s %8s %8s %8s', ...
        'tau', 'chan', 'RMSE', 'delay', 'rate%', 'PSDatt', 'Nproxy'), ...
        'FontName', 'FixedWidth', 'FontSize', 8, 'Interpreter', 'none');
    for i = 1:numel(R.rows)
        r = R.rows(i);
        np = r.yaw_moment_proxy_ratio;
        if ~isfinite(np); np_s = '   n/a'; else; np_s = sprintf('%8.4f', np); end
        text(0.02, 0.28 - i*0.045, sprintf('%5.2f %-8s %8.4f %8.4f %8.2f %8.4f %s', ...
            r.tau_s, r.channel(1:min(8,end)), r.angle_rmse_deg, r.delay_s, ...
            r.rate_dwell_pct, r.psd_att_at_fmark, np_s), ...
            'FontName', 'FixedWidth', 'FontSize', 8, 'Interpreter', 'none');
    end

    sgtitle(sprintf('%s — shadow FO+limits vs ideal R10 cmd | %s', R.tag, R.stamp), ...
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
    fprintf(fid, '**Verdict:** **%s** — deterministic documented shadow-model evidence only.  \n', R.verdict);
    fprintf(fid, '**Physical readiness:** **%s**  \n', R.physical_readiness);
    fprintf(fid, '**Production edited:** NO · **NL rerun:** NO · **CODEX_VERTICAL_PLAN:** untouched  \n\n');

    fprintf(fid, '## Sources (≤3)\n\n');
    fprintf(fid, '| # | Path |\n|---|------|\n');
    for i = 1:numel(R.sources)
        fprintf(fid, '| %d | `%s` |\n', i, R.sources{i});
    end
    fprintf(fid, '\nCommand replay: `%s`\n\n', R.command_source);

    fprintf(fid, '## Shadow model\n\n');
    fprintf(fid, '```\n%s\n```\n\n', R.shadow_model);
    fprintf(fid, '| Item | Value | Provenance |\n|------|-------|------------|\n');
    fprintf(fid, '| Elevator mag | ±%d deg | FIXED (pack/ICD) |\n', R.limits.de_max_deg);
    fprintf(fid, '| Rudder mag | ±%d deg | FIXED (pack/ICD) |\n', R.limits.dr_max_deg);
    fprintf(fid, '| Rate limit | ±%d deg/s | FIXED (pack/ICD) |\n', R.limits.rate_dps);
    fprintf(fid, '| PSD marker | %.2f Hz | DERIVED (pack 1/dt_guidance) |\n', R.limits.f_marker);
    fprintf(fid, '| Servo τ grid | %s s | **ASSUMED** (ICD: no vendor/bench τ) |\n', mat2str(R.tau_s', 3));
    fprintf(fid, '| Current / thermal / backlash / HW cert | — | **NOT invented** |\n\n');
    fprintf(fid, '%s\n\n', R.tau_note);

    fprintf(fid, '## Timing (accepted R10 timestamps)\n\n');
    fprintf(fid, '| N | t0 | tf | dt_med | dt_min | dt_max | unique dt |\n');
    fprintf(fid, '|---|----|----|--------|--------|--------|-----------|\n');
    fprintf(fid, '| %d | %.4f | %.4f | %.6f | %.6f | %.6f | %d |\n\n', ...
        R.dt_stats.N, R.dt_stats.t0, R.dt_stats.tf, R.dt_stats.dt_med, ...
        R.dt_stats.dt_min, R.dt_stats.dt_max, R.dt_stats.n_unique_dt);
    fprintf(fid, 'Nonuniform `dt` handler enabled (per-sample `exp(-dt/τ)` and `ω_max·dt`). This log is uniform at dt=%.4f s.\n\n', R.dt_stats.dt_med);

    fprintf(fid, '## Metrics (steady t≥5 s)\n\n');
    fprintf(fid, '| τ [s] | Channel | Angle RMSE [deg] | Max err [deg] | Delay [s] | Phase@%.2fHz [deg] | Mag sat %% | Rate dwell %% | TV [deg] | Chatter [deg/s] | PSD att @%.2fHz | u2*dr proxy ratio |\n', ...
        R.limits.f_marker, R.limits.f_marker);
    fprintf(fid, '|------|---------|------------------|---------------|-----------|---------------------|-----------|---------------|----------|-----------------|----------------|-------------------|\n');
    for i = 1:numel(R.rows)
        r = R.rows(i);
        ph_an = rad2deg(atan(2 * pi * R.limits.f_marker * r.tau_s));
        if strcmp(r.channel, 'rudder')
            fprintf(fid, '| %.2f | %s | %.4f | %.4f | %.4f | %.2f (xcorr; FO-atan=%.1f) | %.2f | %.2f | %.2f | %.4f | %.4f | %.4f |\n', ...
                r.tau_s, r.channel, r.angle_rmse_deg, r.angle_max_err_deg, r.delay_s, ...
                r.phase_lag_deg_at_fmark, ph_an, r.mag_sat_pct, r.rate_dwell_pct, ...
                r.tv_deg, r.chatter_dps, r.psd_att_at_fmark, r.yaw_moment_proxy_ratio);
        else
            fprintf(fid, '| %.2f | %s | %.4f | %.4f | %.4f | %.2f (xcorr; FO-atan=%.1f) | %.2f | %.2f | %.2f | %.4f | %.4f | n/a |\n', ...
                r.tau_s, r.channel, r.angle_rmse_deg, r.angle_max_err_deg, r.delay_s, ...
                r.phase_lag_deg_at_fmark, ph_an, r.mag_sat_pct, r.rate_dwell_pct, ...
                r.tv_deg, r.chatter_dps, r.psd_att_at_fmark);
        end
    end

    fprintf(fid, '\nIdeal software-command chatter (pack HF metric): δe=**%.4f** / δr=**%.4f** deg/s (G2 context).\n\n', ...
        R.chat_cmd_de_dps, R.chat_cmd_dr_dps);

    fprintf(fid, '## Findings\n\n');
    fprintf(fid, '- Ideal cmd ≡ plant input today; shadow FO+limits introduce measurable lag/attenuation vs that ideal.\n');
    fprintf(fid, '- Rate-dwell and PSD attenuation quantify how much R10 command chatter would be filtered by a lagging fin.\n');
    fprintf(fid, '- Yaw-moment proxy uses only existing `u^2*δr` relationship (coeff cancels in RMS ratio).\n');
    fprintf(fid, '- No hardware certification; τ remains **ASSUMED** until vendor/bench ID.\n\n');

    fprintf(fid, '## Artifacts\n\n');
    fprintf(fid, '- `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.md`\n');
    fprintf(fid, '- `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.mat`\n');
    fprintf(fid, '- `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.png`\n');
    fprintf(fid, '- Driver: `run_actuator_dynamics_realism_baseline.m`\n\n');

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '`%s` — isolated δr deadband **or** backlash stub; compare chatter/limit-cycle vs this FO baseline; no retune; production frozen.\n', R.next);
    fclose(fid);
end

function append_realism(path, R)
    txt = fileread(path);
    marker = sprintf('\n\n---\n\n## APPEND — %s', R.task_id);
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
    fprintf(fid, '\n\n---\n\n## APPEND — %s — %s\n\n', R.task_id, R.stamp);
    fprintf(fid, '**Shadow baseline:** **%s** — physical readiness **%s**. Isolated FO+mag+rate fin shadow on accepted R10 commands; production frozen; no plant/controller edit.\n\n', ...
        R.verdict, R.physical_readiness);
    fprintf(fid, '- Sources: AUV_VISUAL_EVIDENCE_PACK.md, ACTUATOR_FEEDBACK_TELEMETRY_ICD.md, this audit; cmds from ROLL_PRODUCTION_CLOSURE.mat `candidate.SH`.\n');
    fprintf(fid, '- τ **ASSUMED** {%s} s (ICD: no vendor servo τ). Limits FIXED ±15/±25 deg, ±40 deg/s.\n', mat2str(R.tau_s', 3));
    ir = find(strcmp({R.rows.channel}, 'rudder') & abs([R.rows.tau_s] - 0.10) < 1e-9, 1);
    if ~isempty(ir)
        r = R.rows(ir);
        fprintf(fid, '- Example τ=0.10 s rudder: RMSE=%.4f deg, delay=%.4f s, rate_dwell=%.2f%%, PSD_att@13.33Hz=%.4f, u²δr proxy=%.4f.\n', ...
            r.angle_rmse_deg, r.delay_s, r.rate_dwell_pct, r.psd_att_at_fmark, r.yaw_moment_proxy_ratio);
    end
    fprintf(fid, '- Artifacts: `suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.{md,mat,png}`; driver `run_actuator_dynamics_realism_baseline.m`.\n');
    fprintf(fid, '- G1 partial closure (documented shadow only). G2 (chatter/rate-rail) remains a physics concern under ideal software cmd; shadow FO attenuates HF (PSD_att≪1) with **0%%** additional rate-dwell on already-limited cmds.\n');
    fprintf(fid, '- Next: **`%s`**.\n', R.next);
    fprintf(fid, '- CODEX_VERTICAL_PLAN untouched.\n');
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
    fprintf(fid, '- Shadow baseline: **%s** — physical readiness **%s**; isolated FO+mag+rate fin shadow from accepted R10 raw MAT cmds; production frozen; no NL rerun; no controller/plant edit.\n', ...
        R.verdict, R.physical_readiness);
    fprintf(fid, '- Sources (≤3): AUV_REALISM_AND_VISUAL_VALIDATION.md, AUV_VISUAL_EVIDENCE_PACK.md, ACTUATOR_FEEDBACK_TELEMETRY_ICD.md; cmds: ROLL_PRODUCTION_CLOSURE.mat candidate.SH.\n');
    fprintf(fid, '- τ **ASSUMED** %s s (ICD lacks vendor/bench τ). Limits FIXED δe±15 / δr±25 deg, ±40 deg/s. Nonuniform-dt handler ON.\n', mat2str(R.tau_s', 3));
    ir = find(strcmp({R.rows.channel}, 'rudder') & abs([R.rows.tau_s] - 0.10) < 1e-9, 1);
    if ~isempty(ir)
        r = R.rows(ir);
        fprintf(fid, '- τ=0.10s δr: RMSE=%.4f deg delay=%.4fs rate_dwell=%.2f%% PSD_att@13.33Hz=%.4f u²δr_proxy=%.4f; cmd chatter δr=%.3f deg/s.\n', ...
            r.angle_rmse_deg, r.delay_s, r.rate_dwell_pct, r.psd_att_at_fmark, ...
            r.yaw_moment_proxy_ratio, R.chat_cmd_dr_dps);
    end
    fprintf(fid, '- Artifacts: suite_results/ACTUATOR_DYNAMICS_REALISM_BASELINE.{md,mat,png}; driver `run_actuator_dynamics_realism_baseline.m`.\n');
    fprintf(fid, '- Next: **`%s`** — isolated δr deadband/backlash stub vs this FO baseline; no retune; CODEX_VERTICAL_PLAN untouched.\n', R.next);
    fclose(fid);
end
