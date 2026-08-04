function run_metric_rescore()
% RUN_METRIC_RESCORE  One batch: metric plumbing baseline full suite + T5 A/B focus.
% Frozen stack: lambda=0.25, Tur4A r_ff, T25 trim, timing.
% Configs (XZ+X focus for T5; full suite once for baseline):
%   Baseline: K_gamma=0, K_zdot=0
%   T5A:      K_gamma=0, K_zdot=0.50
%   T5B:      K_gamma=0.75, K_zdot=0
% Writes suite_results/METRIC_RESCORE.md

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    clear global K_zdot K_gamma enable_alpha_hat lambda_muw_ff
    clear global trim_speed_table trim_elevator_table elevator_sign

    init_parameters();
    global K_zdot K_gamma enable_alpha_hat lambda_muw_ff
    global elevator_sign trim_speed_table trim_elevator_table
    global dt_controller dt_guidance tau_rate

    % Frozen stack
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    lambda_muw_ff = 0.25;
    enable_alpha_hat = false;

    fprintf('\n========== METRIC RESCORE ==========\n');
    fprintf('lambda=%.2f  dt_c=%.4f dt_g=%.4f tau=%.4f\n', ...
        lambda_muw_ff, dt_controller, dt_guidance, tau_rate);
    fprintf('Paths: X->45m, XZ L=42 (s~45m). Primary: CTE_perp settled_before_end.\n');

    %% 1) Baseline full suite (calibrate once)
    fprintf('\n----- BASELINE full suite  K_gamma=0  K_zdot=0 -----\n');
    K_gamma = 0;
    K_zdot = 0;
    suite_base = run_path_suite(true);  % calibrate + full 4 scenarios
    copyfile(fullfile(out_dir, 'summary.txt'), fullfile(out_dir, 'summary_baseline_rescore.txt'));

    base_xz = extract_scenario(suite_base, 'xz_line');
    base_x  = extract_scenario(suite_base, 'x_line');

    %% 2) Focused XZ + X for T5A / T5B (no full suite)
    configs = { ...
        struct('name','Baseline','K_gamma',0,'K_zdot',0), ...
        struct('name','T5A','K_gamma',0,'K_zdot',0.50), ...
        struct('name','T5B','K_gamma',0.75,'K_zdot',0) ...
        };

    focus = struct([]);
    for ic = 1:numel(configs)
        cfg = configs{ic};
        fprintf('\n----- FOCUS %s  K_gamma=%.2f  K_zdot=%.2f -----\n', ...
            cfg.name, cfg.K_gamma, cfg.K_zdot);
        K_gamma = cfg.K_gamma;
        K_zdot = cfg.K_zdot;

        row = struct('name', cfg.name, 'K_gamma', cfg.K_gamma, 'K_zdot', cfg.K_zdot);
        % Reuse baseline suite metrics for Baseline config (already run)
        if strcmp(cfg.name, 'Baseline') && ~isempty(base_xz) && ~isempty(base_x)
            row.xz = pack_focus(base_xz);
            row.x  = pack_focus(base_x);
        else
            row.xz = run_focus_scenario(make_xz_sc());
            row.x  = run_focus_scenario(make_x_sc());
        end
        if isempty(focus); focus = row; else; focus(end+1) = row; end %#ok<AGROW>

        fprintf('  XZ: CTE_perp_sbe=%.3f  |ez|=%.3f  mean_ez=%+.3f  maxCTE=%.3f  |pitch|=%.2f  ch=%.4f  deRMS=%.3f\n', ...
            row.xz.cte_perp_sbe, row.xz.abs_ez, row.xz.signed_ez, row.xz.max_cte_perp, ...
            row.xz.pitch_err, row.xz.chatter, row.xz.elev_rms);
        fprintf('  X : CTE_perp_sbe=%.3f  |ez|=%.3f  mean_ez=%+.3f  maxCTE=%.3f  |pitch|=%.2f  ch=%.4f  deRMS=%.3f\n', ...
            row.x.cte_perp_sbe, row.x.abs_ez, row.x.signed_ez, row.x.max_cte_perp, ...
            row.x.pitch_err, row.x.chatter, row.x.elev_rms);
    end

    %% Production guidance
    mid = struct('cte', 0.50, 'ez', 0.45);
    prod = decide_production(focus, mid);

    write_metric_rescore_md(out_dir, focus, suite_base, prod, mid, ...
        lambda_muw_ff, dt_controller, dt_guidance, tau_rate);

    % Align init default with production decision (experimental flag comment kept)
    apply_production_defaults(project_dir, prod);

    fprintf('\n========== DONE -> %s ==========\n', fullfile(out_dir, 'METRIC_RESCORE.md'));
    fprintf('Production: %s (K_gamma=%.2f, K_zdot=%.2f)\n', ...
        prod.name, prod.K_gamma, prod.K_zdot);
end

%% --------- focus runners ---------
function m = run_focus_scenario(sc)
    global dt_controller
    global suite_delta_e_log

    clear guidance_law controller_law
    dt = dt_controller;
    state0 = initial_state(sc.path, sc.u0);
    [vp, times, vel, ~, ori, ~, yaw_refs, pitch_refs, ~] = ...
        continuous_path_tracking(sc.path, state0, dt, sc.T_final);
    pm = compute_path_following_metrics(sc.path, vp, vel, ori, yaw_refs, pitch_refs, dt, times);

    de = suite_delta_e_log(:);
    if isempty(de); elev_rms = NaN; else; elev_rms = rad2deg(rms(de)); end

    m = struct( ...
        'cte_perp_sbe', pm.mean_cte_perp, ...
        'abs_ez', pm.mean_abs_ez, ...
        'signed_ez', pm.mean_signed_ez, ...
        'max_cte_perp', pm.max_cte_perp, ...
        'pitch_err', pm.mean_pitch_err_deg, ...
        'chatter', pm.pitch_chatter_dps, ...
        'elev_rms', elev_rms, ...
        'legacy_full', pm.cte_waypoint_legacy_full, ...
        's_total', pm.s_total, ...
        'travel', pm.travel_est, ...
        'pct_overrun', pm.pct_samples_overrun);
end

function m = pack_focus(suite_row)
    de_rms = NaN;
    if isfield(suite_row, 'elevator_rms_deg'); de_rms = suite_row.elevator_rms_deg; end
    m = struct( ...
        'cte_perp_sbe', suite_row.mean_cte_perp, ...
        'abs_ez', suite_row.mean_abs_ez, ...
        'signed_ez', suite_row.mean_signed_ez, ...
        'max_cte_perp', suite_row.max_cte_perp, ...
        'pitch_err', suite_row.mean_pitch_err_deg, ...
        'chatter', suite_row.pitch_chatter_dps, ...
        'elev_rms', de_rms, ...
        'legacy_full', suite_row.cte_waypoint_legacy_full, ...
        's_total', suite_row.s_total, ...
        'travel', suite_row.travel_est, ...
        'pct_overrun', suite_row.pct_samples_overrun);
end

function prod = decide_production(focus, mid)
    % Prefer baseline unless a T5 config clearly hits mid-target on XZ
    % (CTE_perp<0.50 and |ez|<0.45) without chatter/pitch regression.
    base = focus(1);
    prod = struct('name', base.name, 'K_gamma', base.K_gamma, 'K_zdot', base.K_zdot, ...
        'reason', 'default production: K_gamma=0, K_zdot=0', 't5b_experimental', true);

    t5b = [];
    t5a = [];
    for i = 1:numel(focus)
        if strcmp(focus(i).name, 'T5B'); t5b = focus(i); end
        if strcmp(focus(i).name, 'T5A'); t5a = focus(i); end
    end

    if ~isempty(t5b)
        hits = (t5b.xz.cte_perp_sbe < mid.cte) && (t5b.xz.abs_ez < mid.ez);
        chat_ok = t5b.xz.chatter < 0.12;
        pitch_ok = t5b.xz.pitch_err < 0.8;
        if hits && chat_ok && pitch_ok
            prod.name = 'T5B';
            prod.K_gamma = t5b.K_gamma;
            prod.K_zdot = t5b.K_zdot;
            prod.reason = sprintf(['T5B clearly hits mid-target on XZ ', ...
                '(CTE_perp=%.3f<%.2f, |ez|=%.3f<%.2f) with chatter/pitch OK'], ...
                t5b.xz.cte_perp_sbe, mid.cte, t5b.xz.abs_ez, mid.ez);
            prod.t5b_experimental = false;
            return;
        end
    end

    if ~isempty(t5a)
        better = (t5a.xz.cte_perp_sbe < base.xz.cte_perp_sbe - 0.05) && ...
                 (t5a.xz.abs_ez < base.xz.abs_ez - 0.05) && ...
                 (t5a.xz.chatter < 0.12) && (t5a.xz.pitch_err < 0.8);
        hits = (t5a.xz.cte_perp_sbe < mid.cte) && (t5a.xz.abs_ez < mid.ez);
        if hits && better
            prod.name = 'T5A';
            prod.K_gamma = t5a.K_gamma;
            prod.K_zdot = t5a.K_zdot;
            prod.reason = sprintf('T5A clearly better on true metrics and near mid-target');
            prod.t5b_experimental = true;
            return;
        end
    end

    % Keep baseline; leave T5B experimental
    prod.reason = sprintf(['T5 does not clearly win mid-target ', ...
        '(need CTE_perp<%.2f and |ez|<%.2f on XZ settled_before_end). ', ...
        'Keep production K_gamma=0, K_zdot=0; T5B remains experimental.'], mid.cte, mid.ez);
end

function apply_production_defaults(project_dir, prod)
    % Soft-update init_parameters.m defaults to match production decision.
    f = fullfile(project_dir, 'init_parameters.m');
    txt = fileread(f);
    % K_zdot default
    txt2 = regexprep(txt, ...
        'if isempty\(K_zdot\); K_zdot = [^;]+;', ...
        sprintf('if isempty(K_zdot); K_zdot = %.2g;', prod.K_zdot));
    % K_gamma: production 0 unless T5B promoted
    if prod.t5b_experimental
        txt2 = regexprep(txt2, ...
            'if isempty\(K_gamma\); K_gamma = [^;]+;.*', ...
            'if isempty(K_gamma); K_gamma = 0; end  % production default; T5B 0.75 experimental');
    else
        txt2 = regexprep(txt2, ...
            'if isempty\(K_gamma\); K_gamma = [^;]+;.*', ...
            sprintf('if isempty(K_gamma); K_gamma = %.2g; end  % production (T5B promoted by metric rescore)', prod.K_gamma));
    end
    if ~strcmp(txt, txt2)
        fid = fopen(f, 'w');
        fwrite(fid, txt2);
        fclose(fid);
        fprintf('Updated init_parameters.m defaults -> K_gamma=%.2f K_zdot=%.2f\n', ...
            prod.K_gamma, prod.K_zdot);
    end
end

function write_metric_rescore_md(out_dir, focus, suite_base, prod, mid, lam, dtc, dtg, tau)
    fid = fopen(fullfile(out_dir, 'METRIC_RESCORE.md'), 'w');
    fprintf(fid, '# METRIC_RESCORE\n\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '**Scope:** Frenet path metrics + re-score T5 candidates (same plant).\n');
    fprintf(fid, '**Do NOT** start elevator/NMP audit here (NEXT).\n\n');

    fprintf(fid, '## Metric definition\n\n');
    fprintf(fid, '- Legacy kept: `cte_waypoint_legacy` = nearest discrete waypoint distance.\n');
    fprintf(fid, '- Primary: along-track `e_s`, `CTE_perp`, vertical/horizontal normal, depth `e_z`.\n');
    fprintf(fid, '- **Gate window `settled_before_end`:** `t ≥ 5 s` AND `s < 0.88 s_total` AND not `near_end` / past-end.\n');
    fprintf(fid, '- Paths extended: X-line → 45 m; XZ L=42 → s≈45 m (vehicle stays on path during T_sim).\n');
    fprintf(fid, '- Suite `mean_cross_track` now aliases `CTE_perp` (settled_before_end).\n\n');

    fprintf(fid, '## Frozen stack\n\n');
    fprintf(fid, '| Param | Value |\n|-------|------:|\n');
    fprintf(fid, '| `lambda_muw_ff` | **%.2f** |\n', lam);
    fprintf(fid, '| Tur4A `r_ff=U_h*κ` / T25 trim / timing | **kept** |\n');
    fprintf(fid, '| `dt_controller` / `dt_guidance` / `tau_rate` | %.4f / %.4f / %.4f |\n', dtc, dtg, tau);
    fprintf(fid, '| Mid-target (XZ) | CTE_perp < %.2f m, \\|e_z\\| < %.2f m |\n\n', mid.cte, mid.ez);

    fprintf(fid, '## Focus table (XZ) — settled_before_end\n\n');
    fprintf(fid, '| Config | K_γ | K_zdot | CTE_perp | \\|e_z\\| | mean e_z | max CTE_perp | \\|pitch\\| | chatter | elev RMS |\n');
    fprintf(fid, '|--------|----:|-------:|---------:|------:|---------:|-------------:|---------:|--------:|---------:|\n');
    for i = 1:numel(focus)
        r = focus(i); xz = r.xz;
        fprintf(fid, '| %s | %.2f | %.2f | %.3f | %.3f | %+.3f | %.3f | %.2f | %.4f | %.3f |\n', ...
            r.name, r.K_gamma, r.K_zdot, xz.cte_perp_sbe, xz.abs_ez, xz.signed_ez, ...
            xz.max_cte_perp, xz.pitch_err, xz.chatter, xz.elev_rms);
    end

    fprintf(fid, '\n## Focus table (X-line) — settled_before_end\n\n');
    fprintf(fid, '| Config | K_γ | K_zdot | CTE_perp | \\|e_z\\| | mean e_z | max CTE_perp | \\|pitch\\| | chatter | elev RMS |\n');
    fprintf(fid, '|--------|----:|-------:|---------:|------:|---------:|-------------:|---------:|--------:|---------:|\n');
    for i = 1:numel(focus)
        r = focus(i); x = r.x;
        fprintf(fid, '| %s | %.2f | %.2f | %.3f | %.3f | %+.3f | %.3f | %.2f | %.4f | %.3f |\n', ...
            r.name, r.K_gamma, r.K_zdot, x.cte_perp_sbe, x.abs_ez, x.signed_ez, ...
            x.max_cte_perp, x.pitch_err, x.chatter, x.elev_rms);
    end

    fprintf(fid, '\n## Path length check (Baseline)\n\n');
    for i = 1:numel(focus)
        if ~strcmp(focus(i).name, 'Baseline'); continue; end
        fprintf(fid, '| Scenario | s_total | travel_est | overrun %% |\n');
        fprintf(fid, '|----------|--------:|-----------:|----------:|\n');
        fprintf(fid, '| XZ | %.2f | %.2f | %.1f |\n', focus(i).xz.s_total, focus(i).xz.travel, focus(i).xz.pct_overrun);
        fprintf(fid, '| X | %.2f | %.2f | %.1f |\n\n', focus(i).x.s_total, focus(i).x.travel, focus(i).x.pct_overrun);
    end

    fprintf(fid, '## Baseline full suite (new primary metrics)\n\n');
    fprintf(fid, '| Scenario | CTE_perp sbe | \\|e_z\\| sbe | legacy wp full | \\|pitch\\| | chatter |\n');
    fprintf(fid, '|----------|-------------:|-----------:|---------------:|---------:|--------:|\n');
    for i = 1:numel(suite_base)
        s = suite_base(i);
        if ~s.ok
            fprintf(fid, '| %s | FAIL | | | | |\n', s.name);
            continue;
        end
        fprintf(fid, '| %s | %.3f | %.3f | %.3f | %.2f | %.4f |\n', ...
            s.name, s.mean_cte_perp, s.mean_abs_ez, s.cte_waypoint_legacy_full, ...
            s.mean_pitch_err_deg, s.pitch_chatter_dps);
    end

    fprintf(fid, '\n## Production guidance\n\n');
    fprintf(fid, '| Decision | Value |\n|----------|------:|\n');
    fprintf(fid, '| Keep as production | **%s** |\n', prod.name);
    fprintf(fid, '| `K_gamma` | **%.2f** |\n', prod.K_gamma);
    fprintf(fid, '| `K_zdot` | **%.2f** |\n', prod.K_zdot);
    fprintf(fid, '| T5B experimental | **%s** |\n', tern(prod.t5b_experimental,'YES','NO'));
    fprintf(fid, '\n%s\n\n', prod.reason);

    fprintf(fid, '## NEXT (do NOT implement in this task)\n\n');
    fprintf(fid, '1. Elevator / NMP audit (authority, sign, delay).\n');
    fprintf(fid, '2. Controller A/B or LQI on true `CTE_perp` / `|e_z|`.\n\n');

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `compute_path_following_metrics.m` — shared Frenet + legacy metrics\n');
    fprintf(fid, '- `run_path_suite.m` — extended X/XZ paths, summary windows, figure titles\n');
    fprintf(fid, '- `run_tur5a.m` / `run_tur5b.m` — short XZ uses primary CTE_perp\n');
    fprintf(fid, '- `run_metric_rescore.m` — this batch\n');
    fprintf(fid, '- `suite_results/METRIC_RESCORE.md` — this report\n');
    fprintf(fid, '- `suite_results/summary.txt` — baseline full-suite windows\n');
    fclose(fid);
end

%% --------- scenarios / helpers ---------
function sc = make_x_sc()
    n = 600;
    x = linspace(0, 45, n)';
    sc = struct('name','X-line','tag','x_line','path',[x,zeros(n,1),zeros(n,1)], ...
        'T_final',18,'u0',1.5);
end

function sc = make_xz_sc()
    n = 900;
    t = linspace(0, 42, n)';
    sc = struct('name','XZ-line','tag','xz_line','path',[t,zeros(n,1),0.4*t], ...
        'T_final',22,'u0',1.5);
end

function state = initial_state(path, u0)
    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;
end

function r = extract_scenario(suite, tag)
    r = [];
    if isempty(suite); return; end
    for i = 1:numel(suite)
        if isfield(suite(i), 'tag') && strcmp(suite(i).tag, tag)
            r = suite(i); return;
        end
    end
    idx = struct('x_line',1,'xz_line',2,'circle',3,'helix',4);
    if isfield(idx, tag) && numel(suite) >= idx.(tag)
        r = suite(idx.(tag));
    end
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
