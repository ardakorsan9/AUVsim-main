function run_pitch_yaw_closure()
% RUN_PITCH_YAW_CLOSURE  Lean Part A (pitch acq/steady + λ A/B) then Part B (yaw).
% One batch. No full suite, no LQI, no gain sweep.
% Writes: suite_results/PITCH_CLOSURE.md, YAW_START.md, updates AGENT_HANDOFF.md

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    clear global K_zdot K_gamma enable_alpha_hat

    init_parameters();
    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global K_zdot K_gamma enable_alpha_hat
    global dt_controller dt_guidance tau_rate Ki_angle Ki_rate
    global delta_e_max delta_r_max

    % Frozen production stack (do not retune pitch gains)
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma = 0;
    K_zdot = 0;
    enable_alpha_hat = false;
    lambda_muw_ff = 0.25;

    fprintf('\n========== PITCH CLOSURE + YAW START ==========\n');
    fprintf('Frozen: dt_c=%.4f dt_g=%.4f tau=%.4f Ki_r=%.3f Ki_a=%.3f\n', ...
        dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle);
    fprintf('Guidance: K_gamma=%g K_zdot=%g | Tur4A r_ff=U_h*k | T25 trim\n', ...
        K_gamma, K_zdot);

    sc_xz = make_xz();
    sc_x  = make_x();

    %% ----- Part A: XZ acq/steady @ λ=0.25, then λ=0 A/B -----
    fprintf('\n--- Part A: XZ λ=0.25 (production) ---\n');
    lambda_muw_ff = 0.25;
    xz25 = run_xz_pitch(sc_xz);

    fprintf('\n--- Part A: XZ λ=0 (same IC) ---\n');
    lambda_muw_ff = 0.0;
    xz00 = run_xz_pitch(sc_xz);

    fprintf('\n--- Part A: quick X check λ=0.25 ---\n');
    lambda_muw_ff = 0.25;
    x25 = run_x_pitch(sc_x);

    % Decide λ schedule note / tiny impl
    schedule_impl = false;
    schedule_note = 'document only';
    if xz00.mean_abs_eth_steady < xz25.mean_abs_eth_steady - 0.15 && ...
            xz00.acq_time_s <= xz25.acq_time_s + 1.0 && ...
            xz00.elev_fb_rms_steady <= xz25.elev_fb_rms_steady * 0.95
        schedule_note = ['λ=0 clearly better on XZ climb steady |eθ| ', ...
            sprintf('(%.3f vs %.3f°). NEXT: scheduled λ (level 0.25 / climb ~0).', ...
            xz00.mean_abs_eth_steady, xz25.mean_abs_eth_steady)];
        % Tiny schedule only if strongly warrants (<30 lines) — climb |pitch_ref|>8°
        if xz00.mean_abs_eth_steady <= 0.45 || ...
                (xz25.mean_abs_eth_steady - xz00.mean_abs_eth_steady) >= 0.35
            schedule_impl = apply_lambda_schedule_tiny();
            if schedule_impl
                schedule_note = [schedule_note, ' IMPLEMENTED: tiny climb schedule in controller_law.'];
                % Re-check XZ with schedule active (lambda global=0.25 base)
                lambda_muw_ff = 0.25;
                xz_sched = run_xz_pitch(sc_xz);
            else
                xz_sched = [];
            end
        else
            xz_sched = [];
        end
    else
        schedule_note = 'λ=0.25 kept for level; XZ A/B does not strongly force schedule now.';
        xz_sched = [];
    end

    freeze_yes = true; % always freeze gains per task
    write_pitch_closure(out_dir, xz25, xz00, x25, xz_sched, schedule_impl, ...
        schedule_note, freeze_yes, dt_controller, dt_guidance, tau_rate, Ki_angle, Ki_rate);

    %% ----- Part B: yaw on R=7.5 / 10 -----
    fprintf('\n--- Part B: yaw R=7.5 / R=10 ---\n');
    lambda_muw_ff = 0.25; % restore production base
    radii = [7.5, 10];
    yaw_rows = struct([]);
    for i = 1:numel(radii)
        clear guidance_law controller_law
        m = run_circle_yaw(radii(i), 40, 1.5);
        m.R = radii(i);
        if isempty(yaw_rows); yaw_rows = m; else; yaw_rows(end+1) = m; end %#ok<AGROW>
        fprintf(['R=%.1f  |eψ|=%.2f  signed=%.2f  lag_unw=%.2f  ', ...
            'slope_corr=%.3f  r/(Uhκ)=%.3f  dr_sat=%.1f%%  CTE_perp=%.3f  ', ...
            'mean_dr=%.2f°  Kr_emp=%.3f\n'], ...
            m.R, m.mean_abs_epsi, m.mean_signed_epsi, m.mean_lag_unwrapped_deg, ...
            m.slope_corr, m.ratio_r_Uh_kappa, m.pct_rudder_sat, m.cte_perp_ss, ...
            m.mean_rudder_deg, m.Kr_empirical);
    end

    % Cheap fix decision: if rate tracks (ratio~1) but persistent eψ for rudder → add δr_ff
    yaw_fix = 'none';
    yaw_fix_note = '';
    if all([yaw_rows.ratio_r_Uh_kappa] > 0.95) && ...
            mean([yaw_rows.mean_abs_epsi]) > 5 && ...
            mean(abs([yaw_rows.Kr_empirical])) > 0.05
        Kr = median([yaw_rows.Kr_empirical]);
        Kr = max(min(Kr, 2.5), -2.5);
        ok = apply_rudder_ff_tiny(Kr);
        if ok
            yaw_fix = sprintf('rudder_ff Kr=%.3f', Kr);
            yaw_fix_note = ['Steady turn required δr≈Kr*r_ff while r≈r_ff; ', ...
                'PD was carrying that via persistent eψ. Added δr += Kr*r_ff.'];
            % Re-run both radii
            yaw_after = struct([]);
            for i = 1:numel(radii)
                clear guidance_law controller_law
                m = run_circle_yaw(radii(i), 40, 1.5);
                m.R = radii(i);
                if isempty(yaw_after); yaw_after = m; else; yaw_after(end+1) = m; end %#ok<AGROW>
                fprintf('AFTER FF R=%.1f  |eψ|=%.2f  r/(Uhκ)=%.3f  sat=%.1f%% CTE=%.3f\n', ...
                    m.R, m.mean_abs_epsi, m.ratio_r_Uh_kappa, m.pct_rudder_sat, m.cte_perp_ss);
            end
        else
            yaw_after = [];
            yaw_fix_note = 'Rudder FF warranted but apply failed; document only.';
        end
    else
        yaw_after = [];
        if mean([yaw_rows.mean_abs_epsi]) <= 5
            yaw_fix_note = 'Feasible circles already have modest |eψ|; no controller change.';
        else
            yaw_fix_note = 'Diagnose logged; no cheap structural fix auto-applied.';
        end
    end

    write_yaw_start(out_dir, yaw_rows, yaw_after, yaw_fix, yaw_fix_note);
    write_handoff(out_dir, xz25, xz00, x25, yaw_rows, yaw_after, yaw_fix, ...
        schedule_impl, schedule_note, freeze_yes);

    save(fullfile(out_dir, 'pitch_yaw_closure.mat'), 'xz25', 'xz00', 'x25', ...
        'xz_sched', 'yaw_rows', 'yaw_after', 'yaw_fix', 'schedule_impl', 'schedule_note');

    fprintf('\nWrote PITCH_CLOSURE.md + YAW_START.md + AGENT_HANDOFF.md\n');
end

%% ===================== Part A runners =====================
function m = run_xz_pitch(sc)
    global dt_controller delta_e_max
    global suite_delta_e_log suite_de_fb_log suite_e_theta_log

    clear guidance_law controller_law
    dt = dt_controller;
    state0 = initial_state(sc.path, sc.u0);
    [vp, times, vel, ~, ori, ~, yaw_refs, pitch_refs, ~] = ...
        continuous_path_tracking(sc.path, state0, dt, sc.T_final); %#ok<ASGLU>
    pm = compute_path_following_metrics(sc.path, vp, vel, ori, yaw_refs, pitch_refs, dt, times);

    e_th = pitch_refs(:) - (-ori(:,2)); % pitch_ref - theta_phys
    t = times(:);
    s = pm.s_prog(:);
    s_total = pm.s_total;

    % Acquisition: enter and stay in ±0.5° band for 1.0 s, else first 6 s
    band = deg2rad(0.5);
    hold_n = max(1, round(1.0 / dt));
    acq_end = numel(t);
    in_band = abs(e_th) <= band;
    for k = 1:(numel(t) - hold_n)
        if all(in_band(k:k+hold_n-1))
            acq_end = k + hold_n - 1;
            break;
        end
    end
    % Cap acquisition if path pitch not yet near (startup)
    acq_cap = min(numel(t), round(6.0 / dt));
    if acq_end > acq_cap && ~any(in_band(1:acq_cap))
        acq_end = acq_cap;
    end
    mask_acq = (1:numel(t))' <= acq_end;

    mask_sbe = (t >= 5.0) & (s < 0.88 * s_total);
    mask_steady = mask_sbe & ~mask_acq;
    if ~any(mask_steady)
        % fallback: settled_before_end only
        mask_steady = mask_sbe;
    end

    de = suite_delta_e_log(:);
    de_fb = suite_de_fb_log(:);
    if isempty(de); de = zeros(size(t)); end
    if isempty(de_fb); de_fb = de; end

    % Chatter on steady window
    th_phys = -ori(:,2);
    dth = [0; diff(th_phys)] / dt;
    i0 = find(mask_steady, 1, 'first');
    if isempty(i0); i0 = max(1, round(2/dt)); end
    dth_ss = dth(mask_steady);
    if numel(dth_ss) < 5
        chatter = pm.pitch_chatter_dps;
    else
        chatter = rad2deg(std(hf_local(detrend(dth_ss), dt)));
    end

    m = struct();
    m.acq_time_s = t(acq_end);
    m.mean_abs_eth_acq = rad2deg(mean(abs(e_th(mask_acq))));
    m.mean_abs_eth_steady = rad2deg(mean(abs(e_th(mask_steady))));
    m.mean_signed_eth_steady = rad2deg(mean(e_th(mask_steady)));
    m.p95_abs_eth_steady = rad2deg(pctile95(abs(e_th(mask_steady))));
    m.chatter_steady = chatter;
    m.elev_sat_pct_steady = 100 * mean(abs(de(mask_steady)) >= 0.98 * delta_e_max);
    m.elev_fb_rms_steady = rad2deg(rms(de_fb(mask_steady)));
    m.elev_rms_steady = rad2deg(rms(de(mask_steady)));
    m.cte_perp_sbe = pm.mean_cte_perp;
    m.mean_pitch_err_full = pm.mean_pitch_err_deg;
    m.chatter_full = pm.pitch_chatter_dps;
    m.n_acq = nnz(mask_acq);
    m.n_steady = nnz(mask_steady);
    m.path_pitch_deg = rad2deg(atan2(0.4, 1));

    fprintf(['  acq_t=%.2fs |eθ|_acq=%.3f |eθ|_ss=%.3f signed_ss=%+.3f ', ...
        'p95=%.3f chat=%.4f sat=%.1f%% de_fb_rms=%.3f CTE_perp=%.3f\n'], ...
        m.acq_time_s, m.mean_abs_eth_acq, m.mean_abs_eth_steady, ...
        m.mean_signed_eth_steady, m.p95_abs_eth_steady, m.chatter_steady, ...
        m.elev_sat_pct_steady, m.elev_fb_rms_steady, m.cte_perp_sbe);
end

function m = run_x_pitch(sc)
    global dt_controller delta_e_max
    global suite_delta_e_log

    clear guidance_law controller_law
    dt = dt_controller;
    state0 = initial_state(sc.path, sc.u0);
    [vp, times, vel, ~, ori, ~, yaw_refs, pitch_refs, ~] = ...
        continuous_path_tracking(sc.path, state0, dt, sc.T_final); %#ok<ASGLU>
    pm = compute_path_following_metrics(sc.path, vp, vel, ori, yaw_refs, pitch_refs, dt, times);
    e_th = pitch_refs(:) - (-ori(:,2));
    t = times(:);
    mask = (t >= 5.0) & (pm.s_prog(:) < 0.88 * pm.s_total);
    de = suite_delta_e_log(:);
    if isempty(de); de = zeros(size(t)); end
    m = struct( ...
        'mean_abs_eth_sbe', rad2deg(mean(abs(e_th(mask)))), ...
        'mean_signed_eth_sbe', rad2deg(mean(e_th(mask))), ...
        'chatter', pm.pitch_chatter_dps, ...
        'elev_sat_pct', 100 * mean(abs(de(mask)) >= 0.98 * delta_e_max), ...
        'cte_perp_sbe', pm.mean_cte_perp);
    fprintf('  X |eθ|=%.3f signed=%+.3f chat=%.4f sat=%.1f%% CTE=%.3f\n', ...
        m.mean_abs_eth_sbe, m.mean_signed_eth_sbe, m.chatter, m.elev_sat_pct, m.cte_perp_sbe);
end

%% ===================== Part B circle yaw =====================
function m = run_circle_yaw(R, T_final, u0)
    global dt_controller dt_guidance delta_r_max
    global last_guidance_U_h last_guidance_kappa last_r_ff

    n = 600;
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

    yaw_refs = zeros(n_steps,1);
    psi_log = zeros(n_steps,1);
    r_log = zeros(n_steps,1);
    Uh_log = zeros(n_steps,1);
    kap_log = zeros(n_steps,1);
    rff_log = zeros(n_steps,1);
    dr_log = zeros(n_steps,1);
    vp = zeros(n_steps,3);
    times = zeros(n_steps,1);

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
            ori(3), ori(2), rates(3), rates(2), u, r_ff, pitch_ref_dot, ori(1), w); %#ok<ASGLU>
        controls = struct('delta_r', dr, 'delta_e', de, 'thrust', thr);
        [~, g] = ode45(@(tt, g) underwater777_vehicle_dynamics(tt, g, controls), [0 dt], state);
        state = g(end, :)';

        vp(k,:) = state(1:3);
        yaw_refs(k) = yaw_ref;
        psi_log(k) = state(6);
        r_log(k) = state(12);
        if isempty(last_guidance_U_h); last_guidance_U_h = Uh; end
        if isempty(last_guidance_kappa); last_guidance_kappa = 1/R; end
        if isempty(last_r_ff); last_r_ff = r_ff; end
        Uh_log(k) = last_guidance_U_h;
        kap_log(k) = last_guidance_kappa;
        rff_log(k) = last_r_ff;
        dr_log(k) = dr;
        times(k) = k * dt;
    end

    % Continuous unwrap both for lag diagnosis
    psi_u = unwrap(psi_log);
    yref_u = unwrap(yaw_refs);
    e_wrap = wrapToPi(yaw_refs - psi_log);
    e_unw = yref_u - psi_u;

    % Steady: t>=8 and last 60%
    i0 = max(1, round(8.0 / dt));
    i1 = max(i0, round(0.4 * n_steps));
    ss = i1:n_steps;

    % Slope tracking: corr of diff(psi) vs diff(yref) on ss
    dpsi = diff(psi_u(ss));
    dyref = diff(yref_u(ss));
    if std(dpsi) > 1e-9 && std(dyref) > 1e-9
        c = corrcoef(dpsi, dyref);
        slope_corr = c(1,2);
    else
        slope_corr = NaN;
    end

    Uh_k = Uh_log(ss) .* kap_log(ss);
    mean_Uh_k = mean(Uh_k);
    mean_r = mean(r_log(ss));
    if mean_Uh_k < 0
        mean_Uh_k = -mean_Uh_k;
        mean_r = -mean_r;
    end
    ratio = mean_r / max(abs(mean_Uh_k), 1e-9);

    % CTE_perp via shared metrics (closed path → settled window)
    vel_dummy = [u0*ones(n_steps,1), zeros(n_steps,2)];
    ori_mat = [zeros(n_steps,1), zeros(n_steps,1), psi_log];
    pitch_refs = zeros(n_steps,1);
    pm = compute_path_following_metrics(path, vp, vel_dummy, ori_mat, yaw_refs, pitch_refs, dt, times);

    mean_rff = mean(rff_log(ss));
    mean_dr = mean(dr_log(ss));
    % Empirical Kr = mean(δr)/mean(r_ff) — rudder needed per unit rate FF
    if abs(mean_rff) > 1e-6
        Kr_emp = mean_dr / mean_rff;
    else
        Kr_emp = NaN;
    end

    m = struct( ...
        'mean_abs_epsi', rad2deg(mean(abs(e_wrap(ss)))), ...
        'mean_signed_epsi', rad2deg(mean(e_wrap(ss))), ...
        'p95_abs_epsi', rad2deg(pctile95(abs(e_wrap(ss)))), ...
        'mean_lag_unwrapped_deg', rad2deg(mean(e_unw(ss))), ...
        'slope_corr', slope_corr, ...
        'ratio_r_Uh_kappa', ratio, ...
        'mean_r_dps', rad2deg(mean_r), ...
        'mean_Uh_kappa_dps', rad2deg(mean_Uh_k), ...
        'pct_rudder_sat', 100 * mean(abs(dr_log(ss)) >= 0.95 * delta_r_max), ...
        'mean_rudder_deg', rad2deg(mean_dr), ...
        'Kr_empirical', Kr_emp, ...
        'cte_perp_ss', pm.mean_cte_perp);
end

%% ===================== tiny patches =====================
function ok = apply_lambda_schedule_tiny()
% Climb schedule: reduce Muw λ when |pitch_ref| large. <30 lines patch.
    ok = false;
    f = which('controller_law');
    if isempty(f); return; end
    lines = read_lines(f);
    marker = '% PITCH_CLOSURE_LAMBDA_SCHED';
    if any(contains_cell(lines, marker)); ok = true; return; end
    i_if = find(contains_cell(lines, 'if abs(G_de) < 1e-9 || lambda_muw_ff == 0'), 1);
    i_ff = find(contains_cell(lines, 'de_uw_ff_raw = -lambda_muw_ff * M_uw / G_de;'), 1);
    if isempty(i_if) || isempty(i_ff)
        fprintf(2, 'lambda schedule: anchor not found; document only\n');
        return;
    end
    insert = { ...
        marker; ...
        '    lam_eff = lambda_muw_ff;'; ...
        '    if abs(pitch_ref) > deg2rad(8)'; ...
        '        lam_eff = 0; % climb: level-tuned Muw FF off'; ...
        '    end'};
    lines{i_if} = '    if abs(G_de) < 1e-9 || lam_eff == 0';
    lines{i_ff} = '        de_uw_ff_raw = -lam_eff * M_uw / G_de;';
    lines = [lines(1:i_if-1); insert(:); lines(i_if:end)];
    write_lines(f, lines);
    clear controller_law
    ok = true;
    fprintf('Applied tiny λ schedule (climb |pitch_ref|>8° → λ=0)\n');
end

function ok = apply_rudder_ff_tiny(Kr)
    ok = false;
    f = which('controller_law');
    if isempty(f); return; end
    lines = read_lines(f);
    marker = '% YAW_START_RUDDER_FF';
    if any(contains_cell(lines, marker)); ok = true; return; end
    i = find(contains_cell(lines, 'delta_r_cmd = Kp_psi * e_psi - Kd_psi * e_r;'), 1);
    if isempty(i)
        fprintf(2, 'rudder FF: anchor not found; document only\n');
        return;
    end
    insert = { ...
        ['    ' marker]; ...
        sprintf('    Kr_rff = %.6g; %% empirical dr / r_ff from feasible circles', Kr)};
    lines{i} = '    delta_r_cmd = Kp_psi * e_psi - Kd_psi * e_r + Kr_rff * r_ff;';
    lines = [lines(1:i-1); insert(:); lines(i:end)];
    write_lines(f, lines);
    clear controller_law
    ok = true;
    fprintf('Applied tiny rudder FF: delta_r += %.4f * r_ff\n', Kr);
end

function lines = read_lines(f)
    fid = fopen(f, 'r');
    lines = {};
    while true
        L = fgetl(fid);
        if ~ischar(L); break; end
        lines{end+1,1} = L; %#ok<AGROW>
    end
    fclose(fid);
end

function write_lines(f, lines)
    fid = fopen(f, 'w');
    for k = 1:numel(lines)
        fprintf(fid, '%s\n', lines{k});
    end
    fclose(fid);
end

function tf = contains_cell(lines, pat)
    tf = false(numel(lines),1);
    for k = 1:numel(lines)
        tf(k) = ~isempty(strfind(lines{k}, pat)); %#ok<STREMP>
    end
end

%% ===================== writers =====================
function write_pitch_closure(out_dir, xz25, xz00, x25, xz_sched, sched_impl, sched_note, freeze_yes, dtc, dtg, tau, Kia, Kir)
    fid = fopen(fullfile(out_dir, 'PITCH_CLOSURE.md'), 'w');
    fprintf(fid, '# PITCH_CLOSURE\n\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Scope:** XZ acquisition vs steady + λ A/B. No gain retune. No LQI.\n\n');

    fprintf(fid, '## Frozen stack\n\n');
    fprintf(fid, '| Param | Value |\n|-------|------:|\n');
    fprintf(fid, '| `lambda_muw_ff` (level / production base) | **0.25** |\n');
    fprintf(fid, '| Tur4A `r_ff=U_h*κ` / T25 trim | **kept** |\n');
    fprintf(fid, '| `K_gamma` / `K_zdot` | **0 / 0** |\n');
    fprintf(fid, '| `dt_c` / `dt_g` / `tau_rate` | %.4f / %.4f / %.4f |\n', dtc, dtg, tau);
    fprintf(fid, '| `Ki_angle` / `Ki_rate` | %.3f / %.3f |\n', Kia, Kir);
    fprintf(fid, '| Pitch gains | **FROZEN** |\n\n');

    fprintf(fid, '## Acquisition vs steady (XZ, λ=0.25)\n\n');
    fprintf(fid, 'Acquisition: first time `|eθ|` stays in ±0.5° for 1 s (cap 6 s).\n');
    fprintf(fid, 'Steady: after acquisition AND `settled_before_end` (t≥5 s, s<0.88 s_path).\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| acq time | %.2f s |\n', xz25.acq_time_s);
    fprintf(fid, '| mean\\|eθ\\| acq | %.3f° |\n', xz25.mean_abs_eth_acq);
    fprintf(fid, '| mean\\|eθ\\| steady | %.3f° |\n', xz25.mean_abs_eth_steady);
    fprintf(fid, '| mean signed eθ steady | %+.3f° |\n', xz25.mean_signed_eth_steady);
    fprintf(fid, '| p95\\|eθ\\| steady | %.3f° |\n', xz25.p95_abs_eth_steady);
    fprintf(fid, '| chatter steady | %.4f °/s |\n', xz25.chatter_steady);
    fprintf(fid, '| elev sat%% steady | %.1f |\n', xz25.elev_sat_pct_steady);
    fprintf(fid, '| elev fb RMS steady | %.3f° |\n', xz25.elev_fb_rms_steady);
    fprintf(fid, '| CTE_perp settled_before_end | %.3f m |\n', xz25.cte_perp_sbe);
    fprintf(fid, '| path pitch (geom) | %.2f° |\n\n', xz25.path_pitch_deg);

    fprintf(fid, '## λ A/B (same IC)\n\n');
    fprintf(fid, '| Metric | λ=0 | λ=0.25 |\n|--------|----:|-------:|\n');
    fprintf(fid, '| mean\\|eθ\\| steady | %.3f | %.3f |\n', xz00.mean_abs_eth_steady, xz25.mean_abs_eth_steady);
    fprintf(fid, '| signed eθ steady | %+.3f | %+.3f |\n', xz00.mean_signed_eth_steady, xz25.mean_signed_eth_steady);
    fprintf(fid, '| acq time (s) | %.2f | %.2f |\n', xz00.acq_time_s, xz25.acq_time_s);
    fprintf(fid, '| elev fb RMS steady | %.3f | %.3f |\n', xz00.elev_fb_rms_steady, xz25.elev_fb_rms_steady);
    fprintf(fid, '| chatter steady | %.4f | %.4f |\n', xz00.chatter_steady, xz25.chatter_steady);
    fprintf(fid, '| CTE_perp sbe | %.3f | %.3f |\n\n', xz00.cte_perp_sbe, xz25.cte_perp_sbe);

    if xz00.mean_abs_eth_steady < xz25.mean_abs_eth_steady
        winner = 'λ=0 on XZ climb';
    else
        winner = 'λ=0.25 on XZ climb';
    end
    fprintf(fid, '**A/B winner (XZ climb):** %s\n\n', winner);

    fprintf(fid, '## Quick X check (λ=0.25)\n\n');
    fprintf(fid, '| Metric | Value |\n|--------|------:|\n');
    fprintf(fid, '| mean\\|eθ\\| sbe | %.3f° |\n', x25.mean_abs_eth_sbe);
    fprintf(fid, '| signed eθ | %+.3f° |\n', x25.mean_signed_eth_sbe);
    fprintf(fid, '| chatter | %.4f °/s |\n', x25.chatter);
    fprintf(fid, '| elev sat%% | %.1f |\n', x25.elev_sat_pct);
    fprintf(fid, '| CTE_perp sbe | %.3f m |\n\n', x25.cte_perp_sbe);

    fprintf(fid, '## Freeze gates\n\n');
    g_x = x25.mean_abs_eth_sbe <= 0.15;
    g_ss = xz25.mean_abs_eth_steady <= 0.40;
    g_p95 = xz25.p95_abs_eth_steady <= 0.50;
    g_ch = xz25.chatter_steady <= 0.12;
    g_sat = xz25.elev_sat_pct_steady <= 0.01;
    fprintf(fid, '| Gate | Result | Detail |\n|------|:------:|--------|\n');
    fprintf(fid, '| X / cruise \\|eθ\\| ~0.11° | %s | %.3f° |\n', yn(g_x), x25.mean_abs_eth_sbe);
    fprintf(fid, '| XZ steady mean\\|eθ\\| ≤0.40° | %s | %.3f° |\n', yn(g_ss), xz25.mean_abs_eth_steady);
    fprintf(fid, '| XZ p95\\|eθ\\| ≤0.50° | %s | %.3f° |\n', yn(g_p95), xz25.p95_abs_eth_steady);
    fprintf(fid, '| chatter ≤0.12 °/s | %s | %.4f |\n', yn(g_ch), xz25.chatter_steady);
    fprintf(fid, '| elev sat 0%% | %s | %.1f%% |\n\n', yn(g_sat), xz25.elev_sat_pct_steady);

    fprintf(fid, '## Decision\n\n');
    fprintf(fid, '- **Pitch gains FROZEN:** %s\n', yn(freeze_yes));
    if ~g_ss
        fprintf(fid, '- XZ steady residual treated as **acquisition/ref-limit / FF schedule**, not LQI.\n');
    else
        fprintf(fid, '- XZ steady within gate — freeze and move on.\n');
    end
    fprintf(fid, '- **Scheduled λ:** %s\n', sched_note);
    fprintf(fid, '- Schedule implemented this turn: **%s**\n', yn(sched_impl));
    if ~isempty(xz_sched)
        fprintf(fid, '- Post-schedule XZ steady \\|eθ\\|=%.3f° CTE=%.3f\n', ...
            xz_sched.mean_abs_eth_steady, xz_sched.cte_perp_sbe);
    end
    fprintf(fid, '\n## Files\n\n- `run_pitch_yaw_closure.m`\n- `suite_results/pitch_yaw_closure.mat`\n');
    fclose(fid);
end

function write_yaw_start(out_dir, before, after, fix, note)
    fid = fopen(fullfile(out_dir, 'YAW_START.md'), 'w');
    fprintf(fid, '# YAW_START\n\n');
    fprintf(fid, '**Date:** %s\n', datestr(now, 31));
    fprintf(fid, '**Scope:** Feasible circles R=7.5 / R=10 only (not R=5). Lean diagnose + cheap fix if warranted.\n\n');

    fprintf(fid, '## Diagnosis\n\n');
    fprintf(fid, '%s\n\n', note);
    fprintf(fid, 'Checks:\n');
    fprintf(fid, '- Wrapped `eψ = wrapToPi(ψ_ref − ψ)` (same as controller)\n');
    fprintf(fid, '- Unwrapped lag `unwrap(ψ_ref) − unwrap(ψ)`\n');
    fprintf(fid, '- Slope corr of `Δψ` vs `Δψ_ref` (tracks rate?)\n');
    fprintf(fid, '- `r / (U_h κ)` and rudder sat%% (authority)\n');
    fprintf(fid, '- Empirical `Kr = mean(δr) / mean(r_ff)` (steady rudder for turn)\n\n');

    fprintf(fid, '## Before (production stack)\n\n');
    fprintf(fid, '| R | mean\\|eψ\\| | signed eψ | unw lag | slope corr | r/(Uhκ) | rudder sat%% | mean δr | Kr_emp | CTE_perp |\n');
    fprintf(fid, '|--:|----------:|----------:|--------:|-----------:|--------:|-------------:|--------:|-------:|---------:|\n');
    for i = 1:numel(before)
        b = before(i);
        fprintf(fid, '| %.1f | %.2f | %+.2f | %+.2f | %.3f | %.3f | %.1f | %+.2f | %.3f | %.3f |\n', ...
            b.R, b.mean_abs_epsi, b.mean_signed_epsi, b.mean_lag_unwrapped_deg, ...
            b.slope_corr, b.ratio_r_Uh_kappa, b.pct_rudder_sat, b.mean_rudder_deg, ...
            b.Kr_empirical, b.cte_perp_ss);
    end

    if ~isempty(after)
        fprintf(fid, '\n## After cheap fix (`%s`)\n\n', fix);
        fprintf(fid, '| R | mean\\|eψ\\| | signed eψ | r/(Uhκ) | rudder sat%% | CTE_perp |\n');
        fprintf(fid, '|--:|----------:|----------:|--------:|-------------:|---------:|\n');
        for i = 1:numel(after)
            a = after(i);
            fprintf(fid, '| %.1f | %.2f | %+.2f | %.3f | %.1f | %.3f |\n', ...
                a.R, a.mean_abs_epsi, a.mean_signed_epsi, a.ratio_r_Uh_kappa, ...
                a.pct_rudder_sat, a.cte_perp_ss);
        end
    else
        fprintf(fid, '\n## Cheap fix\n\n`%s` — %s\n', fix, note);
    end

    fprintf(fid, '\n## Finding\n\n');
    fprintf(fid, 'If slope_corr≈1 and r/(Uhκ)≈1 but \\|eψ\\| large: **not unwrap/metric bug** — PD needs heading error to hold steady rudder while rate FF zeros the D-term. Prefer `δr += Kr·r_ff` over gain thrash.\n');
    fprintf(fid, 'R=5 remains rudder-limited (prior Tur4A); deferred.\n\n');
    fprintf(fid, '## NEXT\n\n');
    fprintf(fid, '1. Confirm / refine Kr on R=7.5/10 (and helix) without retuning Kp_psi.\n');
    fprintf(fid, '2. R=5 curvature-aware speed or radial CTE only after feasible circles look clean.\n');
    fprintf(fid, '3. Do not open LQI for yaw.\n');
    fclose(fid);
end

function write_handoff(out_dir, xz25, xz00, x25, yaw_b, yaw_a, yaw_fix, sched_impl, sched_note, freeze_yes)
    fid = fopen(fullfile(out_dir, 'AGENT_HANDOFF.md'), 'w');
    fprintf(fid, '# AGENT_HANDOFF — AUV path following\n\n');
    fprintf(fid, '**Updated:** %s\n', datestr(now, 'yyyy-mm-dd HH:MM'));
    fprintf(fid, '**Owner now:** Cursor (pitch closure + yaw start done)\n');
    fprintf(fid, '**Paused / later:** R=5 speed, roll, LQI/SMC/NMPC, autonomy/AI\n\n');

    fprintf(fid, '## Production freeze (do not thrash)\n');
    fprintf(fid, '- `dt_c=0.025`, `dt_g=0.075`, `tau_rate=0.05`, `Ki_rate=0`, `Ki_angle=0.16`\n');
    fprintf(fid, '- `lambda_muw_ff=0.25` base, Tur4A `r_ff=U_h*κ`, T25 trim\n');
    fprintf(fid, '- Production guidance: `K_gamma=0`, `K_zdot=0`\n');
    fprintf(fid, '- **Pitch gains FROZEN** (%s) — do not retune\n', yn(freeze_yes));
    if sched_impl
        fprintf(fid, '- Tiny climb λ schedule ON (`|pitch_ref|>8° → λ=0`)\n');
    end
    if ~strcmp(yaw_fix, 'none')
        fprintf(fid, '- Yaw: `%s` in `controller_law`\n', yaw_fix);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## DONE (skip)\n');
    fprintf(fid, '- Tur1–5 / metric rescore / elevator pulse plant table\n');
    fprintf(fid, '- Pitch closure acq/steady + λ A/B → `PITCH_CLOSURE.md`\n');
    fprintf(fid, '- Yaw start R=7.5/10 → `YAW_START.md`\n\n');

    fprintf(fid, '## Pitch snapshot\n');
    fprintf(fid, '- X |eθ|≈%.2f° | XZ steady |eθ| λ=0.25: **%.3f°** | λ=0: **%.3f°**\n', ...
        x25.mean_abs_eth_sbe, xz25.mean_abs_eth_steady, xz00.mean_abs_eth_steady);
    fprintf(fid, '- %s\n\n', sched_note);

    fprintf(fid, '## Yaw snapshot (R=7.5 / 10)\n');
    for i = 1:numel(yaw_b)
        fprintf(fid, '- R=%.1f before: |eψ|=%.2f° r/(Uhκ)=%.3f sat=%.1f%% CTE=%.3f\n', ...
            yaw_b(i).R, yaw_b(i).mean_abs_epsi, yaw_b(i).ratio_r_Uh_kappa, ...
            yaw_b(i).pct_rudder_sat, yaw_b(i).cte_perp_ss);
    end
    if ~isempty(yaw_a)
        for i = 1:numel(yaw_a)
            fprintf(fid, '- R=%.1f after: |eψ|=%.2f° r/(Uhκ)=%.3f sat=%.1f%% CTE=%.3f\n', ...
                yaw_a(i).R, yaw_a(i).mean_abs_epsi, yaw_a(i).ratio_r_Uh_kappa, ...
                yaw_a(i).pct_rudder_sat, yaw_a(i).cte_perp_ss);
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## NOW\n');
    fprintf(fid, '1. Refine yaw rudder-FF / confirm helix if `%s` landed\n', yaw_fix);
    fprintf(fid, '2. Else continue yaw smoothness on feasible circles only\n');
    fprintf(fid, '3. R=5 speed scheduler only after R=7.5/10 clean\n\n');

    fprintf(fid, '## SKIP\n');
    fprintf(fid, '- Full 32 matrix, LQI/A,B ID, pitch gain sweep, Ki_rate reopen\n\n');

    fprintf(fid, '## Paths\n');
    fprintf(fid, '- Project: `C:\\Users\\ardak\\MATLAB\\Projects\\AUVsim-main`\n');
    fprintf(fid, '- Results: `...\\suite_results\\`\n');
    fprintf(fid, '- MATLAB: `D:\\ardak\\matlab\\bin\\matlab.exe`\n');
    fclose(fid);
end

%% ===================== helpers =====================
function sc = make_xz()
    n = 900;
    t = linspace(0, 42, n)';
    sc = struct('name', 'XZ', 'tag', 'xz_line', ...
        'path', [t, zeros(n,1), 0.4*t], 'T_final', 22, 'u0', 1.5);
end

function sc = make_x()
    n = 600;
    x = linspace(0, 45, n)';
    sc = struct('name', 'X', 'tag', 'x_line', ...
        'path', [x, zeros(n,1), zeros(n,1)], 'T_final', 18, 'u0', 1.5);
end

function state = initial_state(path, u0)
    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;
end

function Uh = inertial_Uh(ori, u, v, w)
    phi = ori(1); theta = ori(2); psi = ori(3);
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), cos(theta)*sin(phi), cos(theta)*cos(phi)];
    pd = R * [u; v; w];
    Uh = hypot(pd(1), pd(2));
end

function y = hf_local(x, dt)
    n = max(3, round(0.8 / dt));
    lf = filter(ones(n,1)/n, 1, x(:));
    y = x(:) - lf;
    y(1:min(n,numel(y))) = 0;
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function v = pctile95(x)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    k = max(1, min(numel(x), ceil(0.95 * numel(x))));
    v = x(k);
end
