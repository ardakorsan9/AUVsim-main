function run_tur5a()
% RUN_TUR5A  Tur5A: add inertial zdot error to pitch_ref; sweep K_zdot on XZ;
%            then one full suite at best K + lambda=0.25.
% Writes suite_results/TUR5A_SUMMARY.md
%
% pitch_ref = pitch_path + Kz*e_z + Ki*int + K_zdot*e_zdot
%   e_z     = z_path - z        (implemented via existing -Kz*(z-z_path))
%   e_zdot  = zdot_path - zdot  (zdot_path = t_hat(3)*U_along)

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign K_zdot
    init_parameters();

    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global dt_controller dt_guidance tau_rate Ki_rate Ki_angle
    global K_zdot delta_e_max

    % Frozen stack — do not reopen pitch PID / depth-P/I / Tur4A
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    lambda_muw_ff = 0.25;

    fprintf('\n========== TUR5A  K_zdot sweep on XZ  lambda=%.2f ==========\n', lambda_muw_ff);
    fprintf('Frozen: dt_c=%.4f dt_g=%.4f tau=%.4f Ki_rate=%.3f Ki_angle=%.3f Kz/Ki_z unchanged\n', ...
        dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle);

    % Baseline XZ CTE from Tur4A / T3B-2
    xz_base_cte = 2.766;
    kzdot_list = [0, 0.2, 0.5, 1.0]; % rad/(m/s) — user set; clamp protects

    sweep = struct([]);
    for i = 1:numel(kzdot_list)
        K_zdot = kzdot_list(i);
        fprintf('\n----- XZ  K_zdot=%.2f -----\n', K_zdot);
        clear guidance_law controller_law
        m = run_xz_short();
        m.K_zdot = K_zdot;
        if isempty(sweep); sweep = m; else; sweep(end+1) = m; end %#ok<AGROW>
        fprintf('K=%.2f  CTE=%.3f  |e_th|=%.2f  chatter=%.4f  sat=%.1f%%  drop=%.1f%%\n', ...
            K_zdot, m.mean_cte, m.mean_pitch_err_deg, m.pitch_chatter_dps, ...
            m.pct_mag_sat, 100*(xz_base_cte - m.mean_cte)/xz_base_cte);
    end

    best = pick_best_kzdot(sweep, xz_base_cte);
    fprintf('\n*** Best K_zdot=%.2f  CTE=%.3f ***\n', best.K_zdot, best.mean_cte);

    % Optional short A/B lambda on XZ at best K
    fprintf('\n----- Optional A/B lambda @ best K=%.2f (XZ only) -----\n', best.K_zdot);
    ab = struct([]);
    for lam = [0, 0.25]
        K_zdot = best.K_zdot;
        lambda_muw_ff = lam;
        clear guidance_law controller_law
        m = run_xz_short();
        m.K_zdot = best.K_zdot;
        m.lambda = lam;
        if isempty(ab); ab = m; else; ab(end+1) = m; end %#ok<AGROW>
        fprintf('lam=%.2f  CTE=%.3f  |pitch|=%.2f  chatter=%.4f  sat=%.1f%%\n', ...
            lam, m.mean_cte, m.mean_pitch_err_deg, m.pitch_chatter_dps, m.pct_mag_sat);
    end
    lambda_muw_ff = 0.25; % restore freeze

    % Full suite once at best K + lambda=0.25
    K_zdot = best.K_zdot;
    fprintf('\n----- Full suite @ K_zdot=%.2f  lambda=0.25 -----\n', K_zdot);
    clear guidance_law controller_law
    suite = run_path_suite(false);

    write_tur5a_summary(out_dir, sweep, best, ab, suite, xz_base_cte, ...
        lambda_muw_ff, dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle);

    fprintf('\nWrote %s\n', fullfile(out_dir, 'TUR5A_SUMMARY.md'));
end

function best = pick_best_kzdot(sweep, xz_base)
% Prefer CTE drop >=15% (CTE<=2.35) with |e_th|<0.8, chatter<0.12, no elev sat.
% Else pick lowest CTE that still respects soft pitch gates if possible.
    target = xz_base * 0.85; % <=2.35 from 2.766
    ok = false(size(sweep));
    for i = 1:numel(sweep)
        ok(i) = sweep(i).mean_cte <= target ...
            && sweep(i).mean_pitch_err_deg < 0.8 ...
            && sweep(i).pitch_chatter_dps < 0.12 ...
            && sweep(i).pct_mag_sat < 1.0;
    end
    if any(ok)
        cands = sweep(ok);
        [~, j] = min([cands.mean_cte]);
        best = cands(j);
        return;
    end
    % Soft: chatter OK + sat OK, minimize CTE (even if |e_th| or CTE gate soft)
    soft = false(size(sweep));
    for i = 1:numel(sweep)
        soft(i) = sweep(i).pitch_chatter_dps < 0.12 && sweep(i).pct_mag_sat < 5.0;
    end
    if any(soft)
        cands = sweep(soft);
        [~, j] = min([cands.mean_cte]);
        best = cands(j);
        return;
    end
    [~, j] = min([sweep.mean_cte]);
    best = sweep(j);
end

function m = run_xz_short()
    global dt_controller delta_e_max
    global suite_delta_e_log suite_e_theta_log

    sc = make_xz();
    dt = dt_controller;
    state0 = initial_state(sc.path, sc.u0);
    [vp, times, vel, ~, ori, ~, yaw_refs, pitch_refs, ~] = ...
        continuous_path_tracking(sc.path, state0, dt, sc.T);

    pm = compute_path_following_metrics(sc.path, vp, vel, ori, yaw_refs, pitch_refs, dt, times);
    n = size(vp, 1);
    i0 = max(1, round(2.0/dt));
    pitch_err = pitch_refs(:) + ori(:,2);
    de = suite_delta_e_log(:);
    if isempty(de); de = zeros(n,1); end
    eth = suite_e_theta_log(:);
    if isempty(eth); eth = pitch_err; end
    pct_sat = 100 * mean(abs(de(i0:end)) >= 0.95 * delta_e_max);

    % Primary: CTE_perp settled_before_end; legacy waypoint kept separately
    m = struct( ...
        'mean_cte', pm.mean_cte_perp, ...
        'max_cte', pm.max_cte_perp, ...
        'cte_waypoint_legacy', pm.cte_waypoint_legacy_full, ...
        'mean_abs_ez', pm.mean_abs_ez, ...
        'mean_signed_ez', pm.mean_signed_ez, ...
        'mean_pitch_err_deg', pm.mean_pitch_err_deg, ...
        'mean_e_theta_deg', rad2deg(mean(eth(i0:end))), ...
        'pitch_chatter_dps', pm.pitch_chatter_dps, ...
        'pct_mag_sat', pct_sat, ...
        'elevator_rms_deg', rad2deg(rms(de)), ...
        'final_u', vel(end,1));
end

function y = hf_sig(x, dt)
    n = max(3, round(0.8/dt));
    lf = filter(ones(n,1)/n, 1, x(:));
    y = x(:) - lf; y(1:n) = 0;
end

function state = initial_state(path, u0)
    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;
end

function sc = make_xz()
    % Match suite: L=42 → s≈45 m > T_sim travel (~36 m)
    n = 900;
    t = linspace(0,42,n)';
    sc = struct('name','XZ-line','tag','xz_line','path',[t,zeros(n,1),0.4*t],'T',22,'u0',1.5);
end

function write_tur5a_summary(out_dir, sweep, best, ab, suite, xz_base, lam, dtc, dtg, tau, Kir, Kia)
    fid = fopen(fullfile(out_dir, 'TUR5A_SUMMARY.md'), 'w');
    fprintf(fid, '# TUR5A_SUMMARY — inertial ż error on pitch_ref\n\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '**Change:** `pitch_ref += K_zdot * (zdot_path - zdot_inertial)` (Kz / depth-I unchanged)\n\n');

    fprintf(fid, '## Definition\n\n');
    fprintf(fid, '- `zdot_inertial = (R(φ,θ,ψ)*[u;v;w])_z` passed from `continuous_path_tracking` (arg 7).\n');
    fprintf(fid, '- `zdot_path = t_hat(3) * U_along`, `U_along = max(hypot(U_h,zdot), 0.3)`.\n');
    fprintf(fid, '- Sign: same family as depth-P (`cte(3)=z-z_path`, corr `-= K*(·)` ≡ `+= K*(z_path-z)`).\n');
    fprintf(fid, '- Existing: `Kz=0.050`, `Ki_z=0.006` **untouched**. Rate-limit on pitch_ref kept.\n\n');

    fprintf(fid, '## Frozen\n\n');
    fprintf(fid, '| Param | Value |\n|-------|------:|\n');
    fprintf(fid, '| `lambda_muw_ff` | **%.2f** |\n', lam);
    fprintf(fid, '| `dt_controller` | %.4f |\n', dtc);
    fprintf(fid, '| `dt_guidance` | %.4f |\n', dtg);
    fprintf(fid, '| `tau_rate` | %.4f |\n', tau);
    fprintf(fid, '| `Ki_rate` | %.3f |\n', Kir);
    fprintf(fid, '| `Ki_angle` | %.3f |\n', Kia);
    fprintf(fid, '| `K_zdot` (selected) | **%.2f** |\n', best.K_zdot);
    fprintf(fid, '| Tur4A `r_ff=U_h*κ` / trim T25 / pitch PID | **kept** |\n');
    fprintf(fid, '| Tur4B radial FF | **SKIPPED** (per user) |\n\n');

    fprintf(fid, '## XZ K_zdot sweep\n\n');
    fprintf(fid, 'Baseline CTE = %.3f m (Tur4A / T3B-2). Target ≤%.3f m (≥15%%%% drop).\n\n', ...
        xz_base, xz_base*0.85);
    fprintf(fid, '| K_zdot | CTE (m) | Δ%%%% vs base | \\|e_θ\\| (°) | mean e_θ (°) | chatter (°/s) | elev sat%%%% |\n');
    fprintf(fid, '|-------:|--------:|-------------:|------------:|-------------:|--------------:|------------:|\n');
    for i = 1:numel(sweep)
        s = sweep(i);
        drop = 100 * (xz_base - s.mean_cte) / xz_base;
        mark = '';
        if abs(s.K_zdot - best.K_zdot) < 1e-9; mark = ' **best**'; end
        fprintf(fid, '| %.2f%s | %.3f | %+.1f | %.2f | %+.3f | %.4f | %.1f |\n', ...
            s.K_zdot, mark, s.mean_cte, drop, s.mean_pitch_err_deg, ...
            s.mean_e_theta_deg, s.pitch_chatter_dps, s.pct_mag_sat);
    end

    fprintf(fid, '\n## Optional λ A/B @ best K (XZ only)\n\n');
    fprintf(fid, '| λ | CTE | \\|pitch\\| | chatter | sat%%%% |\n');
    fprintf(fid, '|--:|----:|---------:|--------:|------:|\n');
    for i = 1:numel(ab)
        a = ab(i);
        fprintf(fid, '| %.2f | %.3f | %.2f | %.4f | %.1f |\n', ...
            a.lambda, a.mean_cte, a.mean_pitch_err_deg, a.pitch_chatter_dps, a.pct_mag_sat);
    end

    % Suite rows
    base = struct('x_cte', 2.116, 'xz_cte', xz_base, 'circle_cte', 1.516, 'helix_cte', 1.675);
    sx = find_suite(suite, 'x_line');
    sxz = find_suite(suite, 'xz_line');
    sc = find_suite(suite, 'circle');
    sh = find_suite(suite, 'helix');

    fprintf(fid, '\n## Full suite @ K_zdot=%.2f, λ=0.25\n\n', best.K_zdot);
    fprintf(fid, 'Regression baseline = Tur4A. Gate: X/circle/helix CTE ≤5%%%% worse; XZ target ≤2.35.\n\n');
    fprintf(fid, '| Scenario | CTE now | CTE base | Δ%%%% | \\|pitch\\| | chatter |\n');
    fprintf(fid, '|----------|--------:|---------:|----:|--------:|--------:|\n');
    print_suite_row(fid, 'X-line', sx, base.x_cte);
    print_suite_row(fid, 'XZ-line', sxz, base.xz_cte);
    print_suite_row(fid, 'Circle', sc, base.circle_cte);
    print_suite_row(fid, 'Helix', sh, base.helix_cte);

    % Gates
    xz_cte = nan; xz_pitch = nan; xz_ch = nan; xz_sat = best.pct_mag_sat;
    if ~isempty(sxz)
        xz_cte = sxz.mean_cross_track;
        xz_pitch = sxz.mean_pitch_err_deg;
        xz_ch = sxz.pitch_chatter_dps;
    end
    cte_ok = ~isnan(xz_cte) && xz_cte <= xz_base * 0.85;
    prefer_ok = ~isnan(xz_cte) && xz_cte < 2.0;
    pitch_ok = ~isnan(xz_pitch) && xz_pitch < 0.8;
    chat_ok = ~isnan(xz_ch) && xz_ch < 0.12;
    sat_ok = xz_sat < 1.0;
    reg_ok = true;
    if ~isempty(sx); reg_ok = reg_ok && (sx.mean_cross_track <= base.x_cte * 1.05); end
    if ~isempty(sc); reg_ok = reg_ok && (sc.mean_cross_track <= base.circle_cte * 1.05); end
    if ~isempty(sh); reg_ok = reg_ok && (sh.mean_cross_track <= base.helix_cte * 1.05); end

    xz_accept = cte_ok && pitch_ok && chat_ok && sat_ok;
    fprintf(fid, '\n## Acceptance (XZ)\n\n');
    fprintf(fid, '| Check | Result |\n|-------|--------|\n');
    fprintf(fid, '| XZ CTE ≤ %.3f (≥15%%%% drop) | %s (%.3f) |\n', xz_base*0.85, tern(cte_ok,'PASS','FAIL'), xz_cte);
    fprintf(fid, '| Prefer XZ CTE < 2.0 m | %s |\n', tern(prefer_ok,'PASS','FAIL'));
    fprintf(fid, '| \\|e_θ\\| < 0.8° | %s (%.2f) |\n', tern(pitch_ok,'PASS','FAIL'), xz_pitch);
    fprintf(fid, '| chatter < 0.12 °/s | %s (%.4f) |\n', tern(chat_ok,'PASS','FAIL'), xz_ch);
    fprintf(fid, '| no elevator sat (sweep best) | %s (%.1f%%%%) |\n', tern(sat_ok,'PASS','FAIL'), xz_sat);
    fprintf(fid, '| X/circle/helix CTE ≤5%%%% worse | %s |\n', tern(reg_ok,'PASS','FAIL'));
    fprintf(fid, '| **Overall T5A** | **%s** |\n', tern(xz_accept && reg_ok,'PASS','FAIL'));

    fprintf(fid, '\n## Verdict\n\n');
    if xz_accept && reg_ok
        fprintf(fid, '**T5A PASS** — keep `K_zdot=%.2f`. Tur5B γ-guidance **not needed** for CTE gate.\n', best.K_zdot);
    elseif cte_ok && reg_ok
        fprintf(fid, '**T5A PARTIAL** — CTE gate met but pitch/chatter/sat soft-fail. Document; prefer stop before T5B unless clearly insufficient.\n');
    else
        fprintf(fid, '**T5A FAIL / borderline** — STOP before Tur5B γ unless clearly insufficient and time remains.\n');
        fprintf(fid, 'Best CTE=%.3f (need ≤%.3f). T5B γ-guidance noted as next lever.\n', xz_cte, xz_base*0.85);
    end

    fprintf(fid, '\n## NEXT queue (do NOT implement in this task)\n\n');
    fprintf(fid, '1. **Tur5B γ-guidance** — if T5A insufficient for XZ CTE.\n');
    fprintf(fid, '2. **Yaw ref smoothness** — yaw rises steadily but some refs do not (queued after T5).\n');
    fprintf(fid, '3. **R=5 speed scheduler** — if rudder-authority limited circle still needs work (Tur4B radial SKIPPED).\n');
    fprintf(fid, '4. **LQI / SMC / NMPC** — only if T5 fails gates after γ attempt.\n\n');

    fprintf(fid, '## Files touched\n\n');
    fprintf(fid, '- `guidance_law.m` — `K_zdot * e_zdot` on pitch_raw\n');
    fprintf(fid, '- `continuous_path_tracking.m` — pass inertial zdot\n');
    fprintf(fid, '- `init_parameters.m` — `K_zdot` global default 0\n');
    fprintf(fid, '- `run_tur5a.m` — this runner\n');
    fclose(fid);
end

function print_suite_row(fid, name, s, base_cte)
    if isempty(s)
        fprintf(fid, '| %s | n/a | %.3f | n/a | n/a | n/a |\n', name, base_cte);
        return;
    end
    dlt = 100 * (s.mean_cross_track - base_cte) / max(base_cte, 1e-9);
    fprintf(fid, '| %s | %.3f | %.3f | %+.1f | %.2f | %.4f |\n', ...
        name, s.mean_cross_track, base_cte, dlt, s.mean_pitch_err_deg, s.pitch_chatter_dps);
end

function r = find_suite(suite, tag)
    r = [];
    if isempty(suite); return; end
    for i = 1:numel(suite)
        nm = suite(i).name;
        if strcmp(tag, 'x_line') && contains(nm, 'X cizgisi'); r = suite(i); return; end
        if strcmp(tag, 'xz_line') && contains(nm, 'XZ'); r = suite(i); return; end
        if strcmp(tag, 'circle') && contains(nm, 'daire'); r = suite(i); return; end
        if strcmp(tag, 'helix') && contains(lower(nm), 'heliks'); r = suite(i); return; end
    end
    % Fallback by run_path_suite order
    idx = struct('x_line',1,'xz_line',2,'circle',3,'helix',4);
    if isfield(idx, tag) && numel(suite) >= idx.(tag)
        r = suite(idx.(tag));
    end
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
