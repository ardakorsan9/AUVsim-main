function run_tur4a()
% RUN_TUR4A  Circle-focused Tur4A: r_ff = U_h*kappa; then one full suite regression.
% Writes suite_results/TUR4A_SUMMARY.md
%
% U_h definition: inertial horizontal speed hypot(x_dot,y_dot) via R*[u;v;w]
%                 (same as continuous_path_tracking / plant kinematics).

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    init_parameters();

    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global dt_controller dt_guidance tau_rate Ki_rate Ki_angle
    global delta_r_max

    % Frozen Tur3 stack — do not reopen
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    lambda_muw_ff = 0.25;

    fprintf('\n========== TUR4A  r_ff = U_h * kappa  lambda=%.2f ==========\n', lambda_muw_ff);
    fprintf('Frozen: dt_c=%.4f dt_g=%.4f tau=%.4f Ki_rate=%.3f Ki_angle=%.3f\n', ...
        dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle);

    radii = [5, 7.5, 10];
    circle_rows = struct([]);
    for i = 1:numel(radii)
        R = radii(i);
        fprintf('\n----- Circle R=%.1f -----\n', R);
        clear guidance_law controller_law
        m = run_circle_instrumented(R, 35, 1.5);
        m.R = R;
        if isempty(circle_rows); circle_rows = m; else; circle_rows(end+1) = m; end %#ok<AGROW>
        fprintf('R=%.1f  CTE=%.3f  r/(Uh*k)=%.3f  rudder_sat=%.1f%%  |pitch|=%.2f chatter=%.4f\n', ...
            R, m.mean_cte, m.ratio_r_over_Uh_kappa, m.pct_rudder_sat, ...
            m.mean_pitch_err_deg, m.pitch_chatter_dps);
    end

    % Full suite once for X/XZ/helix regression (reuse frozen trim)
    fprintf('\n----- Full suite regression (calibrate=false) -----\n');
    clear guidance_law controller_law
    suite = run_path_suite(false);

    write_tur4a_summary(out_dir, circle_rows, suite, lambda_muw_ff, ...
        dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle);

    fprintf('\nWrote %s\n', fullfile(out_dir, 'TUR4A_SUMMARY.md'));
end

function m = run_circle_instrumented(R, T_final, u0)
    global dt_controller dt_guidance delta_r_max
    global last_guidance_U_h last_guidance_kappa last_r_ff

    n = 500;
    th = linspace(0, 2*pi, n)';
    path = [R*cos(th), R*sin(th), zeros(n,1)];
    dt = dt_controller;
    n_steps = round(T_final / dt);
    guidance_period = max(1, round(dt_guidance / dt));

    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;

    yaw_ref = 0; pitch_ref = 0; u_ref = u0; r_ff = 0; pitch_ref_dot = 0; pidx = 1;

    cte = zeros(n_steps,1);
    r_log = zeros(n_steps,1);
    Uh_log = zeros(n_steps,1);
    kap_log = zeros(n_steps,1);
    rff_log = zeros(n_steps,1);
    dr_log = zeros(n_steps,1);
    pitch_refs = zeros(n_steps,1);
    theta_log = zeros(n_steps,1);
    vp = zeros(n_steps,3);

    for k = 1:n_steps
        pos = state(1:3)';
        ori = state(4:6)';
        rates = state(10:12)';
        u = state(7); v = state(8); w = state(9);
        Uh = inertial_Uh(ori, u, v, w);

        if mod(k - 1, guidance_period) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, path, pidx, u, v, Uh);
        end

        [dr, de, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w);
        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);
        [~, g] = ode45(@(t, g) underwater777_vehicle_dynamics(t, g, controls), [0 dt], state);
        state = g(end, :)';

        vp(k,:) = state(1:3);
        cte(k) = min(vecnorm(path - vp(k,:), 2, 2));
        r_log(k) = state(12);
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa); last_guidance_kappa = 0; end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        Uh_log(k) = last_guidance_U_h;
        kap_log(k) = last_guidance_kappa;
        rff_log(k) = last_r_ff;
        dr_log(k) = dr;
        pitch_refs(k) = pitch_ref;
        theta_log(k) = state(5);
    end

    % Steady window: last 60% after t>=8 s
    i0 = max(1, round(8.0 / dt));
    i1 = max(i0, round(0.4 * n_steps));
    ss = i1:n_steps;

    Uh_k = Uh_log(ss) .* kap_log(ss);
    mean_Uh_k = mean(Uh_k);
    mean_r = mean(r_log(ss));
    % Align signs for ratio (CCW circle → positive kappa typically)
    if mean_Uh_k < 0
        mean_Uh_k = -mean_Uh_k;
        mean_r = -mean_r;
    end
    ratio = mean_r / max(abs(mean_Uh_k), 1e-9);

    pitch_err = pitch_refs(:) + theta_log(:);
    th_phys = -theta_log;
    dth = [0; diff(th_phys)] / dt;
    dth_hf = hf_sig(detrend(dth(max(1,round(2/dt)):end)), dt);

    m = struct( ...
        'mean_cte', mean(cte), ...
        'mean_cte_ss', mean(cte(ss)), ...
        'ratio_r_over_Uh_kappa', ratio, ...
        'mean_r_dps', rad2deg(mean_r), ...
        'mean_Uh_kappa_dps', rad2deg(mean_Uh_k), ...
        'mean_r_ff_dps', rad2deg(mean(rff_log(ss))), ...
        'pct_rudder_sat', 100 * mean(abs(dr_log(ss)) >= 0.95 * delta_r_max), ...
        'max_abs_rudder_deg', rad2deg(max(abs(dr_log))), ...
        'mean_pitch_err_deg', rad2deg(mean(abs(pitch_err))), ...
        'pitch_chatter_dps', rad2deg(std(dth_hf)), ...
        'mean_Uh', mean(Uh_log(ss)), ...
        'mean_kappa', mean(kap_log(ss)));
end

function Uh = inertial_Uh(ori, u, v, w)
    phi = ori(1); theta = ori(2); psi = ori(3);
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
    pd = R * [u; v; w];
    Uh = hypot(pd(1), pd(2));
end

function y = hf_sig(x, dt)
    n = max(3, round(0.8/dt));
    lf = filter(ones(n,1)/n, 1, x(:));
    y = x(:) - lf; y(1:n) = 0;
end

function write_tur4a_summary(out_dir, circles, suite, lam, dtc, dtg, tau, Kir, Kia)
    % Tur3 λ=0.25 baselines (T3B-2)
    base = struct( ...
        'x_cte', 2.116, 'xz_cte', 2.766, 'circle_cte', 1.516, 'helix_cte', 1.666, ...
        'x_chatter', 0.0506, 'xz_pitch', 1.55, 'helix_pitch', 0.21, 'circle_pitch', 0.14);

    fid = fopen(fullfile(out_dir, 'TUR4A_SUMMARY.md'), 'w');
    fprintf(fid, '# TUR4A_SUMMARY — r_ff = U_h · κ\n\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Change:** `r_ff = U_h * kappa` (was `1.15 * u_ref * kappa`)\n\n');

    fprintf(fid, '## U_h definition\n\n');
    fprintf(fid, '**Inertial horizontal speed:** `U_h = hypot(x_dot, y_dot)` where\n');
    fprintf(fid, '`[x_dot; y_dot; z_dot] = R(φ,θ,ψ) * [u; v; w]` (same R as plant).\n');
    fprintf(fid, 'Passed from `continuous_path_tracking` into `guidance_law` as arg 6.\n');
    fprintf(fid, 'Fallback if omitted: `hypot(u_body, v_body)`.\n\n');

    fprintf(fid, '## Frozen (untouched)\n\n');
    fprintf(fid, '| Param | Value |\n|-------|------:|\n');
    fprintf(fid, '| `lambda_muw_ff` | **%.2f** |\n', lam);
    fprintf(fid, '| `dt_controller` | %.4f |\n', dtc);
    fprintf(fid, '| `dt_guidance` | %.4f |\n', dtg);
    fprintf(fid, '| `tau_rate` | %.4f |\n', tau);
    fprintf(fid, '| `Ki_rate` | %.3f |\n', Kir);
    fprintf(fid, '| `Ki_angle` | %.3f |\n', Kia);
    fprintf(fid, '| yaw gains / radial CTE FB / pitch/Muw/surge/XZ | **untouched** |\n\n');

    fprintf(fid, '## Circle table (instrumented)\n\n');
    fprintf(fid, '| R (m) | CTE (m) | CTE_ss | r / (U_h κ) | mean r (°/s) | mean U_hκ (°/s) | rudder sat%% | |pitch| | chatter |\n');
    fprintf(fid, '|------:|-------:|-------:|------------:|-------------:|----------------:|------------:|--------:|--------:|\n');
    for i = 1:numel(circles)
        c = circles(i);
        fprintf(fid, '| %.1f | %.3f | %.3f | **%.3f** | %.2f | %.2f | %.1f | %.2f | %.4f |\n', ...
            c.R, c.mean_cte, c.mean_cte_ss, c.ratio_r_over_Uh_kappa, ...
            c.mean_r_dps, c.mean_Uh_kappa_dps, c.pct_rudder_sat, ...
            c.mean_pitch_err_deg, c.pitch_chatter_dps);
    end

    % Map suite results by tag-ish name
    sx = find_suite(suite, 'x_line');
    sxz = find_suite(suite, 'xz_line');
    sc = find_suite(suite, 'circle');
    sh = find_suite(suite, 'helix');

    fprintf(fid, '\n## Full suite regression (`run_path_suite(false)`)\n\n');
    fprintf(fid, 'Baseline = T3B-2 (λ=0.25, old r_ff). Gate: X/XZ/helix CTE ≤5%% worse.\n\n');
    fprintf(fid, '| Scenario | CTE now | CTE base | Δ%% | |pitch| | chatter |\n');
    fprintf(fid, '|----------|--------:|---------:|---:|--------:|--------:|\n');
    print_suite_row(fid, 'X-line', sx, base.x_cte);
    print_suite_row(fid, 'XZ-line', sxz, base.xz_cte);
    print_suite_row(fid, 'Circle', sc, base.circle_cte);
    print_suite_row(fid, 'Helix', sh, base.helix_cte);

    % Acceptance
    c5 = circles(1);
    ratio_ok = c5.ratio_r_over_Uh_kappa >= 0.95;
    cte_down = c5.mean_cte < base.circle_cte - 0.05; % clearly down vs ~1.51
    rudder_ok = c5.pct_rudder_sat < 1.0;
    reg_ok = true;
    if ~isempty(sx); reg_ok = reg_ok && (sx.mean_cross_track <= base.x_cte * 1.05); end
    if ~isempty(sxz); reg_ok = reg_ok && (sxz.mean_cross_track <= base.xz_cte * 1.05); end
    if ~isempty(sh); reg_ok = reg_ok && (sh.mean_cross_track <= base.helix_cte * 1.05); end

    need_4b = ratio_ok && ~cte_down;

    fprintf(fid, '\n## Acceptance\n\n');
    fprintf(fid, '| Check | Result |\n|-------|--------|\n');
    fprintf(fid, '| mean(r)/mean(U_h κ) ≥ 0.95 (R=5 ss) | %s (%.3f) |\n', tern(ratio_ok,'PASS','FAIL'), c5.ratio_r_over_Uh_kappa);
    fprintf(fid, '| Circle CTE clearly down vs %.3f | %s (now %.3f) |\n', base.circle_cte, tern(cte_down,'PASS','FAIL'), c5.mean_cte);
    fprintf(fid, '| No rudder sat (R=5) | %s (%.1f%%) |\n', tern(rudder_ok,'PASS','FAIL'), c5.pct_rudder_sat);
    fprintf(fid, '| X/XZ/helix CTE ≤5%% worse | %s |\n', tern(reg_ok,'PASS','FAIL'));
    fprintf(fid, '| λ=0.25 untouched | **YES** |\n\n');

    fprintf(fid, '## Tur 4B needed?\n\n');
    if need_4b
        fprintf(fid, '**YES** — ratio ≥0.95 but circle CTE still high; radial CTE feedback (Tur 4B) deferred (not implemented).\n');
    elseif ~cte_down
        fprintf(fid, '**MAYBE** — CTE not clearly improved; diagnose before 4B.\n');
    else
        fprintf(fid, '**NO** — Tur4A alone improves circle CTE with ratio gate met (or ratio shortfall is separate).\n');
    end
    if ~ratio_ok
        fprintf(fid, '\nNote: ratio gate failed — yaw-rate still lags U_h·κ; 4B may still help CTE but root cause may be authority/lag.\n');
    end

    fprintf(fid, '\n## Files touched\n\n');
    fprintf(fid, '- `guidance_law.m` — `r_ff = U_h * kappa_f`\n');
    fprintf(fid, '- `continuous_path_tracking.m` — pass inertial U_h\n');
    fprintf(fid, '- `run_tur4a.m` — this runner\n');
    fclose(fid);
end

function r = find_suite(suite, tag)
    r = [];
    for i = 1:numel(suite)
        if isfield(suite(i), 'name') && contains(lower(suite(i).name), lower(strrep(tag,'_',' ')))
            r = suite(i); return;
        end
        % Turkish tags from run_path_suite
        if strcmp(tag, 'x_line') && contains(suite(i).name, 'X cizgisi'); r = suite(i); return; end
        if strcmp(tag, 'xz_line') && contains(suite(i).name, 'XZ'); r = suite(i); return; end
        if strcmp(tag, 'circle') && contains(suite(i).name, 'daire'); r = suite(i); return; end
        if strcmp(tag, 'helix') && contains(lower(suite(i).name), 'heliks'); r = suite(i); return; end
    end
end

function print_suite_row(fid, name, r, base_cte)
    if isempty(r) || ~r.ok
        fprintf(fid, '| %s | — | %.3f | — | — | — |\n', name, base_cte);
        return;
    end
    dlt = 100 * (r.mean_cross_track - base_cte) / max(base_cte, 1e-9);
    fprintf(fid, '| %s | %.3f | %.3f | %+.1f | %.2f | %.4f |\n', ...
        name, r.mean_cross_track, base_cte, dlt, r.mean_pitch_err_deg, r.pitch_chatter_dps);
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
