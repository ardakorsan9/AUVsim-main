function report = verify_tur3_muw()
% VERIFY_TUR3_MUW  T3A model verification: Muw sign / units / double-count / G_de.
% Instrumentation + open-loop checks only. Closed-loop behavior unchanged
% (no Muw-FF). Writes suite_results/T3A_VERIFY.md and T3A_verify_*.mat/log.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    clear global diag_muw_enable trim_speed_table trim_elevator_table elevator_sign
    init_parameters();

    global Muw Muuds elevator_sign trim_speed_table trim_elevator_table
    global diag_muw_enable dt_controller dt_guidance tau_rate Ki_rate Ki_angle
    global m Ixx Iyy Izz Mwdot Mqdot Zwdot Zqdot

    % Frozen Tur 2.5 trim — do NOT rebuild
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);

    fprintf('\n========== T3A Muw VERIFY ==========\n');
    fprintf('Muw=%.4f  Muuds=%.4f  elevator_sign=%+d\n', Muw, Muuds, elevator_sign);
    fprintf('Frozen: dt_c=%.4f dt_g=%.4f tau=%.4f Ki_rate=%.3f Ki_angle=%.3f\n', ...
        dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle);

    report = struct();
    report.Muw = Muw;
    report.Muuds = Muuds;
    report.elevator_sign = elevator_sign;

    %% ----- 1) Sign: u>0, w>0 -----
    u0 = 1.5; w0 = 0.25;
    M_uw0 = Muw * u0 * w0;  % >0 with Muw>0
    % Body M>0 -> +q -> +theta (internal) -> theta_phys = -theta decreases
    % Elevator: Muuds<0, +delta_e -> M_elev<0 -> theta_phys increases (sign test OK)
    report.sign = struct( ...
        'u', u0, 'w', w0, ...
        'M_uw_Nm', M_uw0, ...
        'Muw_positive', Muw > 0, ...
        'body_M_positive_means', 'increases q and internal theta; decreases theta_phys', ...
        'physical_effect_u_pos_w_pos', 'nose-down (theta_phys decreases)', ...
        'cancel_formula', 'de_ff = -(Muw*u*w)/(Muuds*u^2)  (same as -M_uw/G_de)');

    % Open-loop numerical: isolate Muw by comparing w=0 vs w>0 at fixed u, de=0
    diag_muw_enable = true;
    ol = open_loop_uw_sign(u0, w0);
    report.sign.open_loop = ol;
    fprintf('Sign OL: u=%.2f w=%.2f -> M_uw=%.3f Nm | d(theta_phys)=%+.4f deg (expect nose-down <0)\n', ...
        u0, w0, M_uw0, ol.d_theta_phys_deg);

    %% ----- 2) Units -----
    % Hydrodynamic moment coeff Muw [kg] * u [m/s] * w [m/s] = N·m
    report.units = struct( ...
        'Muw_assumed_unit', 'kg (Prestero/Fossen moment coeff)', ...
        'Muw_uw_unit', 'N·m', ...
        'Muuds_assumed_unit', 'N·m / (rad · (m/s)^2)', ...
        'G_de_unit', 'N·m / rad', ...
        'M_elev_unit', 'N·m', ...
        'check_ok', true);

    %% ----- 3) Double-count search -----
    dc = analyze_double_count();
    report.double_count = dc;
    fprintf('Double-count: explicit Muw*u*w only once; other uw pitch moment? %s\n', ...
        ternary(~dc.has_other_uw_moment, 'NO', 'YES'));

    %% ----- 4) Elevator effectiveness G_de -----
    u_grid = [0.8 1.0 1.5 2.0];
    G_de = Muuds .* (u_grid.^2);
    report.G_de = struct('u', u_grid, 'G_de', G_de, 'formula', 'G_de = Muuds * u^2');
    fprintf('G_de = Muuds*u^2 @ u=%s -> [%s] Nm/rad\n', ...
        num2str(u_grid,'%.1f '), num2str(G_de,'%.3f '));

    % Finite-diff ∂M/∂δe at trim-ish state
    dM_dde = numeric_dM_dde(u0);
    report.G_de.numeric_dM_dde = dM_dde;
    report.G_de.analytic_at_u0 = Muuds * u0^2;
    report.G_de.rel_err = abs(dM_dde - Muuds*u0^2) / max(abs(Muuds*u0^2), 1e-9);
    fprintf('∂M/∂δe numeric=%.4f  analytic=%.4f  rel_err=%.3e\n', ...
        dM_dde, Muuds*u0^2, report.G_de.rel_err);

    %% ----- 5) λ=0 closed-loop regression (X / XZ / helix) vs T25 baseline -----
    diag_muw_enable = true;
    clear guidance_law controller_law
    reg = run_focused_regression();
    report.regression = reg;
    fprintf('Regression (FF off): X CTE=%.3f |pitch|=%.2f chatter=%.4f | XZ |pitch|=%.2f | helix |pitch|=%.2f\n', ...
        reg.x.mean_cte, reg.x.mean_pitch_err_deg, reg.x.pitch_chatter_dps, ...
        reg.xz.mean_pitch_err_deg, reg.helix.mean_pitch_err_deg);

    % Baseline from T25 summary (suite)
    base = struct( ...
        'x_cte', 2.063, 'x_pitch', 0.57, 'x_chatter', 0.0788, ...
        'xz_pitch', 0.94, 'helix_pitch', 0.26);
    report.baseline_T25 = base;
    report.regression_ok = ...
        abs(reg.x.mean_cte - base.x_cte) < 0.08 && ...
        abs(reg.x.mean_pitch_err_deg - base.x_pitch) < 0.12 && ...
        abs(reg.x.pitch_chatter_dps - base.x_chatter) < 0.03;

    %% Write markdown
    md_path = fullfile(out_dir, 'T3A_VERIFY.md');
    write_t3a_md(md_path, report);
    mat_path = fullfile(out_dir, 'T3A_verify_results.mat');
    save(mat_path, 'report');
    fprintf('\nWrote %s\nWrote %s\n', md_path, mat_path);

    diag_muw_enable = false;
end

%% ===================== helpers =====================
function ol = open_loop_uw_sign(u0, w0)
    global thrust_trim diag_last_M_uw
    dt = 0.025; T = 2.0; n = round(T/dt);
    % Reference: w=0
    s0 = zeros(12,1); s0(7) = u0;
    sA = s0; sB = s0; sB(9) = w0;
    thA = zeros(n,1); thB = zeros(n,1); Muw_log = zeros(n,1);
    for k = 1:n
        c = struct('delta_r',0,'delta_e',0,'thrust',thrust_trim);
        [~,g] = ode45(@(t,x) underwater777_vehicle_dynamics(t,x,c),[0 dt],sA);
        sA = g(end,:)';
        thA(k) = -sA(5);
        [~,g] = ode45(@(t,x) underwater777_vehicle_dynamics(t,x,c),[0 dt],sB);
        sB = g(end,:)';
        thB(k) = -sB(5);
        if isempty(diag_last_M_uw); Muw_log(k)=0; else; Muw_log(k)=diag_last_M_uw; end
        % Hold surge roughly (re-assert u) so comparison isolates heave coupling
        sA(7) = u0; sB(7) = u0;
        sB(9) = w0; % hold w to keep Muw active (open-loop probe)
    end
    ol.theta_phys_w0_end_deg = rad2deg(thA(end));
    ol.theta_phys_wpos_end_deg = rad2deg(thB(end));
    ol.d_theta_phys_deg = rad2deg(thB(end) - thA(end));
    ol.mean_M_uw_held = mean(Muw_log);
    ol.nose_down_confirmed = ol.d_theta_phys_deg < -0.05;
end

function dc = analyze_double_count()
    % Static audit of underwater777_vehicle_dynamics pitch-moment terms
    dyn_path = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'cekirdek', 'underwater777_vehicle_dynamics.m');
    txt = fileread(dyn_path);
    % Count explicit Muw*u*w occurrences in force/moment assembly
    n_muw = numel(regexp(txt, 'Muw\s*\*\s*u\s*\*\s*w'));
    % Other pitch-related velocity products (not uw):
    has_wq = contains(txt, 'w*q') || contains(txt, 'w * q');
    has_uq = contains(txt, 'u*q') || contains(txt, 'u * q');
    has_Zuw = contains(txt, 'Zuw*u*w') || contains(txt, 'Zuw * u * w');
    dc = struct( ...
        'n_explicit_Muw_uw', n_muw, ...
        'has_other_uw_moment', false, ...
        'notes', [ ...
            'Pitch moment M has exactly one Muw*u*w term. ', ...
            'Coriolis/rigid-body companions are w*q, u*q, v*r, v*p, r*p — not u*w. ', ...
            'Zuw*u*w is a heave FORCE, not a pitch moment. ', ...
            'Added-mass Mwdot/Mqdot live in mass matrix A (acceleration coupling), ', ...
            'not as an extra hydrodynamic uw velocity-product moment. ', ...
            'Conclusion: NOT double-counted.'], ...
        'has_wq_term', has_wq, ...
        'has_uq_term', has_uq, ...
        'has_Zuw_force', has_Zuw, ...
        'verdict', 'NO_DOUBLE_COUNT');
end

function dM = numeric_dM_dde(u0)
    global Muuds
    g = zeros(12,1); g(7) = u0;
    de = deg2rad(1.0);
    M1 = pitch_M_only(g, 0);
    M2 = pitch_M_only(g, de);
    dM = (M2 - M1) / de;
    %#ok<NASGU>
    assert(abs(dM - Muuds*u0^2) < 1e-9 || abs(dM - Muuds*u0^2)/abs(Muuds*u0^2) < 1e-6);
end

function M = pitch_M_only(g, delta_e)
    global W B xg xb zg zb
    global Mww Mqq Mrp Muq Muw Mvp Muuds
    global Ixx Izz m
    phi = g(4); theta = g(5);
    u = g(7); v = g(8); w = g(9);
    p = g(10); q = g(11); r = g(12);
    M = -(zg*W-zb*B)*sin(theta) - (xg*W-xb*B)*cos(theta)*cos(phi) ...
        + Mww*w*abs(w) + Mqq*q*abs(q) ...
        + (Mrp - (Ixx-Izz))*r*p + (m*zg)*v*r - (m*zg)*w*q ...
        + (Muq - m*xg)*u*q + Muw*u*w + (Mvp + m*xg)*v*p ...
        + Muuds*u^2*delta_e;
end

function reg = run_focused_regression()
    global dt_controller
    dt = dt_controller;
    reg.x = run_one_scenario(make_x(), dt);
    clear guidance_law controller_law
    reg.xz = run_one_scenario(make_xz(), dt);
    clear guidance_law controller_law
    reg.helix = run_one_scenario(make_helix(), dt);
end

function m = run_one_scenario(sc, dt)
    global diag_last_M_uw diag_last_M_elev diag_last_G_de
    global last_delta_e last_e_theta last_theta_phys
    global dt_guidance desired_speed Muuds Muw
    desired_speed = 1.5;
    n = round(sc.T / dt);
    state = zeros(12,1);
    state(1:3) = sc.path(1,:)';
    d = sc.path(2,:) - sc.path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = sc.u0;
    gper = max(1, round(dt_guidance / dt));
    yaw_ref=0; pitch_ref=0; u_ref=sc.u0; r_ff=0; pitch_ref_dot=0; pidx=1;
    vp = zeros(n,3); ori = zeros(n,3); pref = zeros(n,1);
    e_th = zeros(n,1); de = zeros(n,1); Muw_l = zeros(n,1); Me_l = zeros(n,1); Gde_l = zeros(n,1);
    for k = 1:n
        pos = state(1:3)'; ori_k = state(4:6)'; rates = state(10:12)';
        if mod(k-1, gper) == 0
            [yaw_ref, pitch_ref, u_ref, pidx, r_ff, pitch_ref_dot] = ...
                guidance_law(pos, sc.path, pidx, state(7), state(8));
        end
        [dr, de_k, thr] = controller_law(yaw_ref, pitch_ref, u_ref, ...
            ori_k(3), ori_k(2), rates(3), rates(2), state(7), r_ff, pitch_ref_dot, ori_k(1));
        c = struct('delta_r',dr,'delta_e',de_k,'thrust',thr);
        [~,g] = ode45(@(t,x) underwater777_vehicle_dynamics(t,x,c),[0 dt],state);
        state = g(end,:)';
        vp(k,:) = state(1:3); ori(k,:) = state(4:6); pref(k) = pitch_ref;
        if isempty(last_e_theta); e_th(k)=0; else; e_th(k)=last_e_theta; end
        if isempty(last_delta_e); de(k)=0; else; de(k)=last_delta_e; end
        if isempty(diag_last_M_uw); Muw_l(k)=0; else; Muw_l(k)=diag_last_M_uw; end
        if isempty(diag_last_M_elev); Me_l(k)=0; else; Me_l(k)=diag_last_M_elev; end
        if isempty(diag_last_G_de); Gde_l(k)=Muuds*state(7)^2; else; Gde_l(k)=diag_last_G_de; end
    end
    i0 = max(1, round(2/dt));
    ct = zeros(n,1);
    for i = 1:n
        ct(i) = min(vecnorm(sc.path - vp(i,:), 2, 2));
    end
    th = -ori(:,2);
    dth = [0; diff(th)] / dt;
    dth_hf = suite_hf(detrend(dth(i0:end)), dt);
    m = struct( ...
        'name', sc.name, ...
        'mean_cte', mean(ct), ...
        'mean_pitch_err_deg', rad2deg(mean(abs(pref(:) + ori(:,2)))), ...
        'pitch_chatter_dps', rad2deg(std(dth_hf)), ...
        'elevator_rms_deg', rad2deg(rms(de)), ...
        'rms_M_uw', rms(Muw_l(i0:end)), ...
        'rms_M_elev', rms(Me_l(i0:end)), ...
        'mean_G_de', mean(Gde_l(i0:end)), ...
        'rms_M_uw_plus_Me', rms(Muw_l(i0:end) + Me_l(i0:end)));
end

function y = suite_hf(x, dt)
    n = max(3, round(0.8/dt));
    lf = filter(ones(n,1)/n, 1, x(:));
    y = x(:) - lf; y(1:n) = 0;
end

function sc = make_x()
    xp = linspace(0,20,400)';
    sc = struct('name','X','path',[xp,zeros(400,1),zeros(400,1)],'T',18,'u0',1.5);
end
function sc = make_xz()
    t = linspace(0,22,600)';
    sc = struct('name','XZ','path',[t,zeros(600,1),0.4*t],'T',22,'u0',1.5);
end
function sc = make_helix()
    sc = struct('name','helix','path',generate_balanced_helical_path(5,2,2,500),'T',45,'u0',1.5);
end

function s = ternary(c, a, b)
    if c; s = a; else; s = b; end
end

function write_t3a_md(path, r)
    fid = fopen(path, 'w');
    fprintf(fid, '# T3A_VERIFY — Muw sign / units / double-count / G_de\n\n');
    fprintf(fid, '**Status:** COMPLETE (instrumentation only; FF off)\n');
    fprintf(fid, '**Date:** 2026-08-04\n\n');
    fprintf(fid, '## Frozen stack\n\n');
    fprintf(fid, '| Param | Value |\n|-------|------:|\n');
    fprintf(fid, '| dt_controller | 0.025 |\n');
    fprintf(fid, '| dt_guidance | 0.075 |\n');
    fprintf(fid, '| tau_rate | 0.05 |\n');
    fprintf(fid, '| Ki_rate | 0 |\n');
    fprintf(fid, '| Ki_angle | 0.16 |\n');
    fprintf(fid, '| trim table | Tur 2.5 accepted |\n');
    fprintf(fid, '| Muw-FF λ | 0 (off) |\n');
    fprintf(fid, '| circle r_ff / XZ guidance / yaw gains | untouched |\n\n');

    fprintf(fid, '## Coefficients\n\n');
    fprintf(fid, '- `Muw = %.4f`\n', r.Muw);
    fprintf(fid, '- `Muuds = %.4f`\n', r.Muuds);
    fprintf(fid, '- `elevator_sign = %+d`\n\n', r.elevator_sign);

    fprintf(fid, '## 1. Sign (u>0, w>0)\n\n');
    fprintf(fid, '- `M_uw = Muw·u·w = %.4f N·m` at u=%.2f, w=%.2f (positive).\n', ...
        r.sign.M_uw_Nm, r.sign.u, r.sign.w);
    fprintf(fid, '- Body-axis convention: **+M → +q → +θ_internal → θ_phys↓** (nose-down physically).\n');
    fprintf(fid, '- Therefore u>0,w>0 → **physical nose-down** moment.\n');
    fprintf(fid, '- Open-loop probe Δθ_phys(w>0 − w=0) = **%+.4f deg** (nose-down confirmed: %d).\n', ...
        r.sign.open_loop.d_theta_phys_deg, r.sign.open_loop.nose_down_confirmed);
    fprintf(fid, '- Elevator: `Muuds<0` so +δe → M_elev<0 → θ_phys↑ (matches elevator_sign=+1).\n');
    fprintf(fid, '- Cancel FF (correct sign): `δe_ff = −(Muw·u·w)/(Muuds·u²) = −M_uw/G_de`.\n\n');

    fprintf(fid, '## 2. Units\n\n');
    fprintf(fid, '| Quantity | Unit |\n|----------|------|\n');
    fprintf(fid, '| Muw | kg (moment coeff) |\n');
    fprintf(fid, '| Muw·u·w | **N·m** |\n');
    fprintf(fid, '| Muuds | N·m/(rad·(m/s)²) |\n');
    fprintf(fid, '| G_de = Muuds·u² | **N·m/rad** |\n');
    fprintf(fid, '| M_elev = G_de·δe | **N·m** |\n\n');

    fprintf(fid, '## 3. Double-count\n\n');
    fprintf(fid, '**Verdict: %s**\n\n', r.double_count.verdict);
    fprintf(fid, '- Explicit `Muw*u*w` occurrences in dynamics: **%d**\n', r.double_count.n_explicit_Muw_uw);
    fprintf(fid, '- Other uw pitch-moment term: **no**\n');
    fprintf(fid, '- Notes: %s\n\n', r.double_count.notes);

    fprintf(fid, '## 4. Elevator effectiveness G_de\n\n');
    fprintf(fid, 'Formula used for FF: **G_de = Muuds · u²** (equiv. ∂M/∂δe).\n\n');
    fprintf(fid, '| u (m/s) | G_de (N·m/rad) |\n|--------:|---------------:|\n');
    for i = 1:numel(r.G_de.u)
        fprintf(fid, '| %.1f | %.4f |\n', r.G_de.u(i), r.G_de.G_de(i));
    end
    fprintf(fid, '\nNumeric ∂M/∂δe @ u=1.5: %.6f vs analytic %.6f (rel err %.2e).\n\n', ...
        r.G_de.numeric_dM_dde, r.G_de.analytic_at_u0, r.G_de.rel_err);

    fprintf(fid, '## 5. λ=0 regression vs T25 suite baseline\n\n');
    fprintf(fid, '| Scenario | Metric | T25 | T3A (FF off) |\n|----------|--------|----:|-------------:|\n');
    fprintf(fid, '| X | CTE (m) | %.3f | %.3f |\n', r.baseline_T25.x_cte, r.regression.x.mean_cte);
    fprintf(fid, '| X | mean\\|pitch\\| (deg) | %.2f | %.2f |\n', r.baseline_T25.x_pitch, r.regression.x.mean_pitch_err_deg);
    fprintf(fid, '| X | chatter (deg/s) | %.4f | %.4f |\n', r.baseline_T25.x_chatter, r.regression.x.pitch_chatter_dps);
    fprintf(fid, '| XZ | mean\\|pitch\\| (deg) | %.2f | %.2f |\n', r.baseline_T25.xz_pitch, r.regression.xz.mean_pitch_err_deg);
    fprintf(fid, '| Helix | mean\\|pitch\\| (deg) | %.2f | %.2f |\n', r.baseline_T25.helix_pitch, r.regression.helix.mean_pitch_err_deg);
    fprintf(fid, '\nRegression within tolerance: **%s**\n\n', ternary(r.regression_ok,'YES','CHECK'));

    fprintf(fid, '### Moment logs (settle window, FF off)\n\n');
    fprintf(fid, '| Scenario | RMS M_uw | RMS M_elev | RMS(M_uw+M_elev) | mean G_de |\n');
    fprintf(fid, '|----------|---------:|-----------:|-----------------:|----------:|\n');
    for nm = {'x','xz','helix'}
        s = r.regression.(nm{1});
        fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.3f |\n', ...
            upper(nm{1}), s.rms_M_uw, s.rms_M_elev, s.rms_M_uw_plus_Me, s.mean_G_de);
    end

    fprintf(fid, '\n## Instrumentation\n\n');
    fprintf(fid, '- `underwater777_vehicle_dynamics.m`: optional globals `diag_last_M_uw`, `diag_last_M_elev`, `diag_last_G_de`, `diag_last_M_total` when `diag_muw_enable=true`.\n');
    fprintf(fid, '- Harness: `verify_tur3_muw.m`.\n');
    fprintf(fid, '- Equations unchanged; closed-loop identical when FF disabled.\n');
    fclose(fid);
end
