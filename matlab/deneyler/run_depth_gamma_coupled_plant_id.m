function run_depth_gamma_coupled_plant_id()
% DEPTH_GAMMA_COUPLED_PLANT_ID_001
% Sagittal coupled depth–γ plant ID from validated local SS only.
% Sources (exactly 3): LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat, SS_VALIDATION.mat
% No production / controller / guidance / plant edits or retune.
% One MATLAB invocation. CODEX_VERTICAL_PLAN untouched.
%
% Labels: IMPLEMENTED / DERIVED / IDENTIFIED / ASSUMED / TO_BE_IDENTIFIED
% Gate honesty: level/climb U≈1.5 family only → Gate-1 verdict PARTIAL
% (not full PASS) unless a justified bounded speed family already exists
% (it does not in these three sources).

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    tag = 'DEPTH_GAMMA_COUPLED_PLANT_ID';
    task_id = 'DEPTH_GAMMA_COUPLED_PLANT_ID_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    src_level = fullfile(out_dir, 'LOCAL_SS_LEVEL.mat');
    src_climb = fullfile(out_dir, 'LOCAL_SS_CLIMB.mat');
    src_val   = fullfile(out_dir, 'SS_VALIDATION.mat');
    assert(exist(src_level, 'file') == 2, 'Missing %s', src_level);
    assert(exist(src_climb, 'file') == 2, 'Missing %s', src_climb);
    assert(exist(src_val, 'file') == 2, 'Missing %s', src_val);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources (exactly 3):\n  %s\n  %s\n  %s\n', src_level, src_climb, src_val);
    fprintf('Production frozen; no retune; plant-ID / transform only.\n');

    L = load(src_level);
    Cmb = load(src_climb);
    V = load(src_val);

    assert(isfield(L, 'jac_pass') && L.jac_pass, 'LEVEL jac not PASS');
    assert(isfield(Cmb, 'jac_pass') && Cmb.jac_pass, 'CLIMB jac not PASS');
    assert(isfield(V, 'level_pass') && V.level_pass, 'SS_VALIDATION level not PASS');
    assert(isfield(V, 'climb_pass') && V.climb_pass, 'SS_VALIDATION climb not PASS');

    % Declared ID tolerances (ASSUMED gate numbers; same spirit as SS_VALIDATION)
    tol = struct();
    tol.nrmse_rel_max = 0.20;          % ASSUMED declared
    tol.corr_min = 0.95;               % ASSUMED declared
    tol.energy_floor = 1e-4;           % ASSUMED near-zero exclusion (scale-norm)
    tol.T_horizon = V.T_end;           % IDENTIFIED from SS_VALIDATION
    tol.note = ['NRMSE_rel<=0.20 and corr>=0.95 on energetic sagittal ', ...
                'channels; near-zero energy excluded; horizon = SS_VALIDATION T_end'];

    state_full = {'x','y','z','phi','theta','psi','u','v','w','p','q','r'};
    % Sagittal reduced order matching LOCAL_SS vertical partition
    ix = [3, 5, 7, 9, 11];             % z, theta, u, w, q
    iu = [2, 3];                       % delta_e, thrust
    sag_names = {'z','theta','u','w','q'};
    in_names  = {'delta_e','thrust'};
    out_names = {'z','theta_phys','alpha','gamma','w','q'};
    units_x = {'m','rad','m/s','m/s','rad/s'};
    units_u = {'rad','N'};
    units_y = {'m','rad','rad','rad','m/s','rad/s'};

    signs = struct();
    signs.frame = 'NED inertial eta + BODY nu; Euler ZYX';
    signs.z = 'NED z positive down [m]; depth ≡ z (IMPLEMENTED plant/controller contract)';
    signs.theta = 'Euler theta [rad] BODY pitch in plant state; theta_phys = -theta (IMPLEMENTED)';
    signs.alpha = 'BODY alpha = atan2(w,u) [rad] (DERIVED kinematic AoA)';
    signs.gamma = 'gamma = theta_phys + alpha [rad] (DERIVED; equals NED flight-path when phi=v=0)';
    signs.u_w = 'BODY surge u, heave w [m/s]; w>0 heave +z_body';
    signs.q = 'BODY pitch rate q [rad/s]';
    signs.delta_e = 'elevator [rad]; delta_e>0 → +Z/+M via Zuuds/Muuds*u^2 (IMPLEMENTED plant signs)';
    signs.thrust = 'thrust = Xprop [N] (IMPLEMENTED)';
    signs.hydro_provenance = ['Hydro numeric coeffs not re-identified here; A,B are ', ...
        'IDENTIFIED local FD Jacobians of underwater777_vehicle_dynamics at documented trims. ', ...
        'No invented hydro provenance.'];

    level = build_sagittal('level', L, ix, iu, sag_names, in_names, out_names, ...
        units_x, units_u, units_y, state_full, tol);
    climb = build_sagittal('climb', Cmb, ix, iu, sag_names, in_names, out_names, ...
        units_x, units_u, units_y, state_full, tol);

    % Independent transform compare on SS_VALIDATION trajectories
    traj = compare_validation_traj(V, level, climb, tol, out_names);

    % Speed-family honesty check (only these three sources)
    speed_family = audit_speed_family(L, Cmb, V);
    id_quality_pass = traj.overall_pass && level.ctrl.rank == 5 && climb.ctrl.rank == 5 ...
        && level.obs.rank == 5 && climb.obs.rank == 5;

    if ~id_quality_pass
        verdict = 'FAIL';
    elseif ~speed_family.has_bounded_U_family
        verdict = 'PARTIAL';   % Gate-1 honesty: U=1.5 only
    else
        verdict = 'PASS';
    end

    next_task = 'depth_gamma_speed_scheduled_id_extension';
    next_note = ['Extend coupled sagittal ID to U={1.0,1.5,2.0} level+climb ', ...
                 '(bounded LTI/LPV family); no production retune.'];

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, level, climb, traj, task_id, verdict);
    write_md(md_path, task_id, stamp, verdict, level, climb, traj, tol, signs, ...
        speed_family, next_task, next_note, src_level, src_climb, src_val, ...
        md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.stamp = stamp;
    S.verdict = verdict;
    S.gate = 'depth_gamma_coupled_plant_identification_gate';
    S.sources = {src_level; src_climb; src_val};
    S.level = level;
    S.climb = climb;
    S.traj = traj;
    S.tol = tol;
    S.signs = signs;
    S.speed_family = speed_family;
    S.next_task = next_task;
    S.next_note = next_note;
    S.labels = struct( ...
        'A_B', 'IDENTIFIED (local FD Jacobian; LOCAL_SS_* PASS)', ...
        'theta_phys', 'IMPLEMENTED (controller/plant contract)', ...
        'alpha_lin', 'DERIVED (analytic d(atan2(w,u)) at trim)', ...
        'gamma', 'DERIVED (theta_phys+alpha)', ...
        'tol', 'ASSUMED declared ID tolerances', ...
        'hydro_coeffs', 'TO_BE_IDENTIFIED (no invented provenance; use plant RHS as-is)', ...
        'speed_family', 'TO_BE_IDENTIFIED (U=1.0/2.0 SS absent from sources)');
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.production_untouched = true;
    save(mat_path, '-struct', 'S');

    append_docs(out_dir, S);

    fprintf('\nVERDICT: %s\n', verdict);
    fprintf('Next: %s\n', next_task);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(S);
end

%% ===================== sagittal model =====================

function R = build_sagittal(name, M, ix, iu, sag_names, in_names, out_names, ...
        units_x, units_u, units_y, state_full, tol)

    x0 = M.x0(:); u0 = M.u0(:);
    A = M.A; B = M.B;
    Av = A(ix, ix); Bv = B(ix, iu);
    if isfield(M, 'A_vertical'); Av = M.A_vertical; end
    if isfield(M, 'B_vertical'); Bv = M.B_vertical; end

    u_b = x0(7); w_b = x0(9); th_b = x0(5);
    alpha0 = atan2(w_b, u_b);
    theta_phys0 = -th_b;
    gamma0 = theta_phys0 + alpha0;
    den = u_b^2 + w_b^2;
    assert(den > 1e-12, 'trim (u,w) too small for alpha linearization');
    dalpha_du = -w_b / den;   % DERIVED
    dalpha_dw =  u_b / den;   % DERIVED

    % Output map y = C x_r + D u_r; x_r=[z,theta,u,w,q]
    % y = [z, theta_phys, alpha, gamma, w, q]
    C = zeros(6, 5);
    C(1,1) = 1;                         % z
    C(2,2) = -1;                        % theta_phys = -theta
    C(3,3) = dalpha_du; C(3,4) = dalpha_dw;  % alpha
    C(4,2) = -1; C(4,3) = dalpha_du; C(4,4) = dalpha_dw; % gamma
    C(5,4) = 1;                         % w
    C(6,5) = 1;                         % q
    D = zeros(6, 2);

    % Poles
    ev_full = sort_ev(eig(A));
    ev_red  = sort_ev(eig(Av));
    unstable_full = ev_full(real(ev_full) > 1e-8);
    unstable_red  = ev_red(real(ev_red) > 1e-8);

    % Controllability / observability (scaled)
    xs = M.x_scale(ix); us = M.u_scale(iu);
    ys = [M.x_scale(3); 1; 1; 1; M.x_scale(9); M.x_scale(11)]; % z,ang,ang,ang,w,q
    Sx = diag(xs(:)); Su = diag(us(:)); Sy = diag(ys(:));
    As = Sx \ (Av * Sx);
    Bs = Sx \ (Bv * Su);
    Cs = Sy \ (C * Sx);

    Qc = ctrb(As, Bs);
    [~, Sc, ~] = svd(Qc, 'econ');
    sigc = diag(Sc);
    [rk_c, tol_c, cond_c] = rank_from_sigma(sigc, size(Qc,1), size(Qc,2));

    Qo = obsv(As, Cs);
    [~, So, ~] = svd(Qo, 'econ');
    sigo = diag(So);
    [rk_o, tol_o, cond_o] = rank_from_sigma(sigo, size(Qo,1), size(Qo,2));

    % Also state-only observability (C=I on reduced)
    QoI = obsv(As, eye(5));
    [~, SoI, ~] = svd(QoI, 'econ');
    sigI = diag(SoI);
    [rk_I, tol_I, cond_I] = rank_from_sigma(sigI, size(QoI,1), size(QoI,2));

    % Cross-coupling + DC / finite-horizon gains
    Tfh = tol.T_horizon;
    [Gdc, Gfh, Gnote] = gain_maps(Av, Bv, C, D, Tfh);
    cross = cross_coupling(Gfh, out_names, in_names);

    % Step / impulse response overlays (reduced LTI)
    resp = local_responses(Av, Bv, C, D, Tfh);

    R = struct();
    R.name = name;
    R.x0 = x0; R.u0 = u0;
    R.ix = ix; R.iu = iu;
    R.sag_names = sag_names; R.in_names = in_names; R.out_names = out_names;
    R.units_x = units_x; R.units_u = units_u; R.units_y = units_y;
    R.state_full = state_full;
    R.A_full = A; R.B_full = B;
    R.A = Av; R.B = Bv; R.C = C; R.D = D;
    R.trim = struct('u', u_b, 'w', w_b, 'theta', th_b, ...
        'theta_phys', theta_phys0, 'alpha', alpha0, 'gamma', gamma0, ...
        'dalpha_du', dalpha_du, 'dalpha_dw', dalpha_dw, ...
        'U_body', hypot(u_b, w_b));
    R.eig_full = ev_full;
    R.eig_red = ev_red;
    R.unstable_full = unstable_full;
    R.unstable_red = unstable_red;
    R.ctrl = struct('rank', rk_c, 'n', 5, 'tol', tol_c, 'cond', cond_c, ...
        'sigma', sigc, 'sigma_min', sigc(end), 'sigma_max', sigc(1));
    R.obs = struct('rank', rk_o, 'n', 5, 'ny', 6, 'tol', tol_o, 'cond', cond_o, ...
        'sigma', sigo, 'sigma_min', sigo(end), 'sigma_max', sigo(1), ...
        'map', 'C:[z,theta_phys,alpha,gamma,w,q]');
    R.obs_state = struct('rank', rk_I, 'n', 5, 'tol', tol_I, 'cond', cond_I, ...
        'sigma', sigI);
    R.Gdc = Gdc; R.Gfh = Gfh; R.Gnote = Gnote; R.Tfh = Tfh;
    R.cross = cross;
    R.resp = resp;
    R.x_scale = xs; R.u_scale = us; R.y_scale = ys;
    R.label_A = 'IDENTIFIED';
    R.label_Calpha = 'DERIVED';
end

function [Gdc, Gfh, note] = gain_maps(A, B, C, D, T)
    n = size(A, 1); m = size(B, 2); p = size(C, 1);
    % Finite-horizon step gain: y(T) for unit step on each input (DERIVED)
    Gfh = zeros(p, m);
    dt = min(0.005, T/100);
    t = (0:dt:T).';
    for j = 1:m
        x = zeros(n, 1);
        yT = zeros(p, 1);
        ej = zeros(m, 1); ej(j) = 1;
        for k = 1:numel(t)-1
            u = ej;
            k1 = A*x + B*u;
            k2 = A*(x+0.5*dt*k1) + B*u;
            k3 = A*(x+0.5*dt*k2) + B*u;
            k4 = A*(x+dt*k3) + B*u;
            x = x + (dt/6)*(k1+2*k2+2*k3+k4);
        end
        yT = C*x + D*ej;
        Gfh(:, j) = yT;
    end

    % Regularized DC: C*(-A)^{-1}*B with ridge on near-zero modes (ASSUMED eps)
    eps_reg = 1e-4;
    Gdc = C * (-(A - eps_reg*eye(n)) \ B) + D;
    note = sprintf(['Gfh = reduced LTI step response at T=%.3fs (DERIVED); ', ...
        'Gdc = C(-(A-%.0e I))^{-1}B ridge DC (ASSUMED regularizer; z-integrator)'], ...
        T, eps_reg);
end

function cross = cross_coupling(Gfh, out_names, in_names)
    % Relative elevator vs thrust influence on each output
    ge = abs(Gfh(:,1)); gt = abs(Gfh(:,2));
    ratio_e_over_t = ge ./ max(gt, 1e-16);
    cross = struct();
    cross.Gfh = Gfh;
    cross.out_names = out_names;
    cross.in_names = in_names;
    cross.abs_elev = ge;
    cross.abs_thrust = gt;
    cross.ratio_elev_over_thrust = ratio_e_over_t;
    cross.elev_dominant = ge >= gt;
    cross.note = ['|y_i(T)| from unit step δe vs thrust; ratio>1 => elevator-dominant ', ...
                  'on that channel at finite horizon (DERIVED from IDENTIFIED A,B)'];
end

function resp = local_responses(A, B, C, D, T)
    dt = 0.005;
    t = (0:dt:T).';
    n = size(A,1); m = size(B,2); p = size(C,1);
    Y = zeros(numel(t), p, m);
    for j = 1:m
        x = zeros(n,1);
        ej = zeros(m,1); ej(j) = 1;
        for k = 1:numel(t)
            Y(k,:,j) = (C*x + D*ej).';
            if k < numel(t)
                k1 = A*x + B*ej;
                k2 = A*(x+0.5*dt*k1) + B*ej;
                k3 = A*(x+0.5*dt*k2) + B*ej;
                k4 = A*(x+dt*k3) + B*ej;
                x = x + (dt/6)*(k1+2*k2+2*k3+k4);
            end
        end
    end
    resp = struct('t', t, 'Y', Y, 'dt', dt, 'T', T);
end

%% ===================== SS_VALIDATION transform compare =====================

function traj = compare_validation_traj(V, level, climb, tol, out_names)
    results = V.results(:);
    cases = {};
    for k = 1:numel(results)
        r = results{k};
        if ~(strcmp(r.trim, 'level') || strcmp(r.trim, 'climb')); continue; end
        if ~(strcmp(r.channel, 'elev_pulse') || strcmp(r.channel, 'theta_ic')); continue; end
        if strcmp(r.trim, 'level'); mdl = level; else; mdl = climb; end
        cases{end+1} = analyze_case(r, mdl, tol, out_names); %#ok<AGROW>
    end

    traj = struct();
    traj.cases = cases;
    traj.tol = tol;
    traj.overall_pass = all(cellfun(@(c) c.pass, cases));
    traj.n_cases = numel(cases);
    traj.n_pass = sum(cellfun(@(c) c.pass, cases));
    traj.channels_used = 'elev_pulse + theta_ic (sagittal); rudder excluded';
end

function c = analyze_case(r, mdl, tol, out_names)
    t = r.t(:);
    dx_nl = r.dx_nl;
    dx_lin = r.dx_lin;
    x0 = r.x0(:);

    Ynl = transform_traj(x0, dx_nl, mdl);
    Ylin_nlmap = transform_traj(x0, dx_lin, mdl);   % same nonlinear maps on LTI states
    Ylin_linmap = dx_lin(:, mdl.ix) * mdl.C.';      % analytic linear map [N x 6]

    scales = mdl.y_scale(:).';
    metrics = struct();
    pass_ch = true(1, 6);
    why = strings(1, 6);
    for i = 1:6
        yn = Ynl(:, i); yl = Ylin_nlmap(:, i);
        e = yn - yl;
        rmse = sqrt(mean(e.^2));
        nrmse_scale = rmse / max(scales(i), eps);
        energy = sqrt(mean((yn / max(scales(i), eps)).^2));
        near0 = energy < tol.energy_floor;
        denom = max(sqrt(mean(yn.^2)), 0.05 * scales(i));
        nrmse_rel = rmse / denom;
        if near0 || std(yn) < 1e-12 || std(yl) < 1e-12
            corr = NaN;
        else
            R = corrcoef(yn, yl);
            corr = R(1, 2);
        end
        % Also linear-map residual vs NL
        yl2 = Ylin_linmap(:, i);
        e2 = yn - yl2;
        rmse_lin = sqrt(mean(e2.^2));
        nrmse_rel_lin = rmse_lin / denom;

        ok = true;
        if ~near0
            ok = (nrmse_rel <= tol.nrmse_rel_max);
            if ~isnan(corr)
                ok = ok && (corr >= tol.corr_min);
            end
        end
        pass_ch(i) = ok;
        if near0
            why(i) = "near-zero (excl)";
        elseif ok
            why(i) = "OK";
        else
            why(i) = sprintf("FAIL nrmse=%.3g corr=%.3g", nrmse_rel, corr);
        end

        metrics.(out_names{i}) = struct( ...
            'rmse', rmse, 'nrmse_scale', nrmse_scale, 'nrmse_rel', nrmse_rel, ...
            'nrmse_rel_linmap', nrmse_rel_lin, 'corr', corr, ...
            'energy_n', energy, 'near0', near0, 'pass', ok);
    end

    c = struct();
    c.trim = r.trim;
    c.channel = r.channel;
    c.label = r.label;
    c.t = t;
    c.Ynl = Ynl;
    c.Ylin_nlmap = Ylin_nlmap;
    c.Ylin_linmap = Ylin_linmap;
    c.metrics = metrics;
    c.pass_ch = pass_ch;
    c.pass = all(pass_ch);
    c.why = why;
    c.out_names = out_names;
end

function Y = transform_traj(x0, dx, mdl)
    % Independent nonlinear transforms on absolute reconstructed states
    N = size(dx, 1);
    Y = zeros(N, 6);
    u0 = x0(7); w0 = x0(9); th0 = x0(5);
    a0 = atan2(w0, u0);
    for k = 1:N
        z  = dx(k, 3);
        th = th0 + dx(k, 5);
        u  = u0 + dx(k, 7);
        w  = w0 + dx(k, 9);
        q  = dx(k, 11);
        thp = -th;
        alp = atan2(w, u);
        gam = thp + alp;
        % perturbation form relative to trim
        Y(k, :) = [z, thp - (-th0), alp - a0, gam - (-th0 + a0), w - w0, q];
    end
end

function sf = audit_speed_family(L, Cmb, V) %#ok<INUSD>
    uL = L.x0(7); uC = Cmb.x0(7);
    sf = struct();
    sf.level_u_body = uL;
    sf.climb_u_body = uC;
    sf.claimed_trim_class = 'level/climb U=1.5 family (BODY u*≈1.82/1.75; not exact 1.5)';
    sf.has_U_1p0 = false;
    sf.has_U_1p5_exact = false;
    sf.has_U_2p0 = false;
    sf.has_bounded_U_family = false;  % no justified multi-speed SS in the 3 sources
    sf.note = ['Only LOCAL_SS_LEVEL + LOCAL_SS_CLIMB (+ SS_VALIDATION) available; ', ...
               'both are the TRIM U=1.5-class translating points. No U=1.0 or U=2.0 ', ...
               'validated A,B in sources → Gate-1 full PASS blocked; verdict PARTIAL.'];
end

%% ===================== numerics helpers =====================

function e = sort_ev(ev)
    [~, ix] = sort(real(ev), 'descend');
    e = ev(ix);
end

function [rk, tol, condn] = rank_from_sigma(sig, m, n)
    if isempty(sig)
        rk = 0; tol = 0; condn = Inf; return;
    end
    tol = max(m, n) * eps(max(sig)) * max(1, 1);
    rk = nnz(sig > tol);
    if sig(end) <= 0
        condn = Inf;
    else
        condn = sig(1) / max(sig(end), eps);
    end
end

%% ===================== artifacts =====================

function write_png(png_path, level, climb, traj, task_id, verdict)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1500 1050]);

    % 1 poles level
    subplot(3, 3, 1);
    plot(real(level.eig_full), imag(level.eig_full), 'ko', 'MarkerSize', 7); hold on;
    plot(real(level.eig_red), imag(level.eig_red), 'rx', 'MarkerSize', 9, 'LineWidth', 1.4);
    xline(0, 'k:'); yline(0, 'k:'); grid on;
    xlabel('Re'); ylabel('Im'); title('LEVEL poles: full(o) red(x)');
    legend('full','sagittal','Location','best');

    subplot(3, 3, 2);
    plot(real(climb.eig_full), imag(climb.eig_full), 'ko', 'MarkerSize', 7); hold on;
    plot(real(climb.eig_red), imag(climb.eig_red), 'rx', 'MarkerSize', 9, 'LineWidth', 1.4);
    xline(0, 'k:'); yline(0, 'k:'); grid on;
    xlabel('Re'); ylabel('Im'); title('CLIMB poles: full(o) red(x)');

    subplot(3, 3, 3);
    bar([level.ctrl.rank, climb.ctrl.rank, level.obs.rank, climb.obs.rank; ...
         5, 5, 5, 5].');
    set(gca, 'XTickLabel', {'ctrl L','ctrl C','obs L','obs C'});
    ylim([0 6]); grid on; legend('rank','n=5', 'Location', 'best');
    title(sprintf('Ctrl/Obs ranks — %s', verdict));

    % Cross-coupling finite-horizon |G|
    subplot(3, 3, 4);
    imagesc(abs(level.Gfh)); colorbar; axis tight;
    set(gca, 'XTick', 1:2, 'XTickLabel', {'de','th'}, ...
        'YTick', 1:6, 'YTickLabel', level.out_names);
    title('LEVEL |Gfh| step@T');

    subplot(3, 3, 5);
    imagesc(abs(climb.Gfh)); colorbar; axis tight;
    set(gca, 'XTick', 1:2, 'XTickLabel', {'de','th'}, ...
        'YTick', 1:6, 'YTickLabel', climb.out_names);
    title('CLIMB |Gfh| step@T');

    subplot(3, 3, 6);
    rr = [level.cross.ratio_elev_over_thrust(:), climb.cross.ratio_elev_over_thrust(:)];
    bar(rr); set(gca, 'XTickLabel', level.out_names, 'XTickLabelRotation', 30);
    ylabel('|de|/|thrust| @T'); grid on;
    legend('level','climb'); title('Elev/thrust cross-coupling');

    % Trajectory overlays: level elev_pulse gamma/alpha/w
    [cL, cC] = pick_cases(traj);
    subplot(3, 3, 7);
    if ~isempty(cL)
        plot(cL.t, rad2deg(cL.Ynl(:,4)), 'k', 'LineWidth', 1.2); hold on;
        plot(cL.t, rad2deg(cL.Ylin_nlmap(:,4)), 'r--', 'LineWidth', 1.1);
        plot(cL.t, rad2deg(cL.Ynl(:,3)), 'b', 'LineWidth', 1.0);
        plot(cL.t, rad2deg(cL.Ylin_nlmap(:,3)), 'c--', 'LineWidth', 1.0);
        grid on; xlabel('t [s]'); ylabel('deg');
        title('LEVEL elev: \gamma,\alpha NL vs LTI');
        legend('\gamma_{NL}','\gamma_{LTI}','\alpha_{NL}','\alpha_{LTI}', 'Location', 'best');
    else
        axis off; text(0.1, 0.5, 'no level elev case');
    end

    subplot(3, 3, 8);
    if ~isempty(cC)
        plot(cC.t, rad2deg(cC.Ynl(:,4)), 'k', 'LineWidth', 1.2); hold on;
        plot(cC.t, rad2deg(cC.Ylin_nlmap(:,4)), 'r--', 'LineWidth', 1.1);
        plot(cC.t, cC.Ynl(:,5), 'b', 'LineWidth', 1.0);
        plot(cC.t, cC.Ylin_nlmap(:,5), 'c--', 'LineWidth', 1.0);
        grid on; xlabel('t [s]'); ylabel('\gamma[deg], w[m/s]');
        title('CLIMB elev: \gamma,w NL vs LTI');
        legend('\gamma_{NL}','\gamma_{LTI}','w_{NL}','w_{LTI}', 'Location', 'best');
    else
        axis off; text(0.1, 0.5, 'no climb elev case');
    end

    subplot(3, 3, 9);
    names = {};
    vals = [];
    for i = 1:numel(traj.cases)
        cc = traj.cases{i};
        for j = 1:numel(cc.out_names)
            m = cc.metrics.(cc.out_names{j});
            if ~m.near0
                names{end+1} = sprintf('%s/%s/%s', cc.trim(1), cc.channel(1:3), cc.out_names{j}); %#ok<AGROW>
                vals(end+1) = m.nrmse_rel; %#ok<AGROW>
            end
        end
    end
    if ~isempty(vals)
        bar(vals); hold on; yline(traj.tol.nrmse_rel_max, 'r--', 'tol');
        set(gca, 'XTick', 1:numel(names), 'XTickLabel', names, 'XTickLabelRotation', 60);
        ylabel('nrmse_rel'); grid on;
        title(sprintf('Traj ID metrics (%d/%d PASS)', traj.n_pass, traj.n_cases));
    else
        axis off;
    end

    sgtitle(sprintf('%s — sagittal coupled plant ID [%s]', task_id, verdict), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function [cL, cC] = pick_cases(traj)
    cL = []; cC = [];
    for i = 1:numel(traj.cases)
        c = traj.cases{i};
        if strcmp(c.trim, 'level') && strcmp(c.channel, 'elev_pulse'); cL = c; end
        if strcmp(c.trim, 'climb') && strcmp(c.channel, 'elev_pulse'); cC = c; end
    end
end

function write_md(md_path, task_id, stamp, verdict, level, climb, traj, tol, signs, ...
        speed_family, next_task, next_note, src_level, src_climb, src_val, ...
        md_path_s, mat_path, png_path)

    fid = fopen(md_path, 'w');
    assert(fid > 0);
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# %s — Depth/γ coupled sagittal plant ID\n\n', task_id);
    fprintf(fid, '**Gate-1 verdict: %s**  \n', verdict);
    fprintf(fid, '**Stamp:** %s  \n', stamp);
    fprintf(fid, '**Next exact task:** `%s`\n\n', next_task);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Sources (exactly 3):\n');
    fprintf(fid, '  1. `%s` (IDENTIFIED A,B,x0,u0; jac PASS)\n', src_level);
    fprintf(fid, '  2. `%s` (IDENTIFIED A,B,x0,u0; jac PASS)\n', src_climb);
    fprintf(fid, '  3. `%s` (NL vs LTI traj; level/climb PASS)\n', src_val);
    fprintf(fid, '- Driver: `run_depth_gamma_coupled_plant_id.m` (isolated; production untouched)\n');
    fprintf(fid, '- Plant RHS underlying SS: `underwater777_vehicle_dynamics` (IMPLEMENTED; not re-edited)\n');
    fprintf(fid, '- No controller/guidance/plant edits; no retune; CODEX_VERTICAL_PLAN untouched\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path_s, mat_path, png_path);

    fprintf(fid, '## Evidence labels\n\n');
    fprintf(fid, '| Item | Label |\n|---|---|\n');
    fprintf(fid, '| Local A,B (level/climb) | IDENTIFIED |\n');
    fprintf(fid, '| theta_phys=-theta | IMPLEMENTED |\n');
    fprintf(fid, '| alpha=atan2(w,u) + analytic linearization | DERIVED |\n');
    fprintf(fid, '| gamma=theta_phys+alpha | DERIVED |\n');
    fprintf(fid, '| ID tolerances (nrmse/corr) | ASSUMED (declared) |\n');
    fprintf(fid, '| Hydro coeff provenance | TO_BE_IDENTIFIED (no invented values) |\n');
    fprintf(fid, '| Speed-scheduled family U=1.0/1.5/2.0 | TO_BE_IDENTIFIED |\n\n');

    fprintf(fid, '## BODY / NED signs and units\n\n');
    fprintf(fid, '- Frame: %s\n', signs.frame);
    fprintf(fid, '- %s\n', signs.z);
    fprintf(fid, '- %s\n', signs.theta);
    fprintf(fid, '- %s\n', signs.alpha);
    fprintf(fid, '- %s\n', signs.gamma);
    fprintf(fid, '- %s\n', signs.u_w);
    fprintf(fid, '- %s\n', signs.q);
    fprintf(fid, '- %s\n', signs.delta_e);
    fprintf(fid, '- %s\n', signs.thrust);
    fprintf(fid, '- %s\n\n', signs.hydro_provenance);

    fprintf(fid, '## Sagittal coupled model\n\n');
    fprintf(fid, 'States `x_r = [z, θ, u, w, q]^T` (sufficient for z,u,w,theta,q).  \n');
    fprintf(fid, 'Inputs `u_r = [δ_e, thrust]^T`.  \n');
    fprintf(fid, 'Outputs `y = [z, θ_phys, α, γ, w, q]^T` with\n\n');
    fprintf(fid, '```\nθ_phys = -θ\nα = atan2(w,u)\nδα = (∂α/∂u)δu + (∂α/∂w)δw,  ∂α/∂u=-w/(u²+w²), ∂α/∂w=u/(u²+w²)  (at trim)\nγ = θ_phys + α\n```\n\n');

    write_op_md(fid, level);
    write_op_md(fid, climb);

    fprintf(fid, '## Declared ID tolerances\n\n');
    fprintf(fid, '| Quantity | Value | Label |\n|---|---:|---|\n');
    fprintf(fid, '| nrmse_rel max | %.2f | ASSUMED |\n', tol.nrmse_rel_max);
    fprintf(fid, '| corr min | %.2f | ASSUMED |\n', tol.corr_min);
    fprintf(fid, '| energy floor (scale-norm) | %.1e | ASSUMED |\n', tol.energy_floor);
    fprintf(fid, '| horizon T | %.3f s | IDENTIFIED (SS_VALIDATION) |\n\n', tol.T_horizon);
    fprintf(fid, '%s\n\n', tol.note);

    fprintf(fid, '## SS_VALIDATION transform compare (independent)\n\n');
    fprintf(fid, 'Both NL and LTI state trajectories transformed with the same nonlinear maps; ');
    fprintf(fid, 'linear C·δx_r also reported. Cases: %s. Overall traj PASS: **%s** (%d/%d).\n\n', ...
        traj.channels_used, tern(traj.overall_pass,'YES','NO'), traj.n_pass, traj.n_cases);

    fprintf(fid, '| Trim | Channel | PASS | z | θ_phys | α | γ | w | q |\n');
    fprintf(fid, '|---|---|:---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:numel(traj.cases)
        c = traj.cases{i};
        fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
            c.trim, c.channel, tern(c.pass,'PASS','FAIL'), ...
            fmt_m(c.metrics.z), fmt_m(c.metrics.theta_phys), fmt_m(c.metrics.alpha), ...
            fmt_m(c.metrics.gamma), fmt_m(c.metrics.w), fmt_m(c.metrics.q));
    end
    fprintf(fid, '\nCells: `nrmse_rel / corr` (n0 = near-zero excluded).\n\n');

    fprintf(fid, '## Speed-family / Gate-1 honesty\n\n');
    fprintf(fid, '- Level BODY u* = %.5f m/s; climb BODY u* = %.5f m/s\n', ...
        speed_family.level_u_body, speed_family.climb_u_body);
    fprintf(fid, '- Class: %s\n', speed_family.claimed_trim_class);
    fprintf(fid, '- Bounded U={1.0,1.5,2.0} family in sources: **NO**\n');
    fprintf(fid, '- %s\n', speed_family.note);
    fprintf(fid, '- Therefore Gate-1 full PASS is **not** claimed; verdict = **%s**.\n\n', verdict);

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '- Exact next task: `%s`\n', next_task);
    fprintf(fid, '- %s\n', next_note);
end

function write_op_md(fid, R)
    fprintf(fid, '### Operating point: %s\n\n', upper(R.name));
    fprintf(fid, '```\nx* = [%s]\nu* = [%s]\n', num2str(R.x0.', ' %.6g'), num2str(R.u0.', ' %.6g'));
    fprintf(fid, 'trim: u=%.6g w=%.6g θ=%.6g θ_phys=%.6g α=%.6g γ=%.6g\n', ...
        R.trim.u, R.trim.w, R.trim.theta, R.trim.theta_phys, R.trim.alpha, R.trim.gamma);
    fprintf(fid, 'dα/du=%.6g  dα/dw=%.6g\n```\n\n', R.trim.dalpha_du, R.trim.dalpha_dw);

    fprintf(fid, 'A_sag (5×5) [z θ u w q]:\n```\n'); print_mat(fid, R.A); fprintf(fid, '```\n\n');
    fprintf(fid, 'B_sag (5×2) [δe thrust]:\n```\n'); print_mat(fid, R.B); fprintf(fid, '```\n\n');
    fprintf(fid, 'C_y (6×5):\n```\n'); print_mat(fid, R.C); fprintf(fid, '```\n\n');

    fprintf(fid, 'Full poles (Re↓):\n```\n');
    for k = 1:numel(R.eig_full)
        fprintf(fid, '%2d: %+.6e %+.6ei\n', k, real(R.eig_full(k)), imag(R.eig_full(k)));
    end
    fprintf(fid, '```\nReduced sagittal poles:\n```\n');
    for k = 1:numel(R.eig_red)
        fprintf(fid, '%2d: %+.6e %+.6ei\n', k, real(R.eig_red(k)), imag(R.eig_red(k)));
    end
    fprintf(fid, '```\n');
    fprintf(fid, 'Unstable full: %s\n', fmt_ev_list(R.unstable_full));
    fprintf(fid, 'Unstable reduced: %s\n\n', fmt_ev_list(R.unstable_red));

    fprintf(fid, '| Check | Rank | Cond(σmax/σmin) | σmin | Tol |\n|---|---:|---:|---:|---:|\n');
    fprintf(fid, '| Ctrl (scaled) | %d/5 | %.4g | %.4g | %.3e |\n', ...
        R.ctrl.rank, R.ctrl.cond, R.ctrl.sigma_min, R.ctrl.tol);
    fprintf(fid, '| Obs y-map (scaled) | %d/5 | %.4g | %.4g | %.3e |\n', ...
        R.obs.rank, R.obs.cond, R.obs.sigma_min, R.obs.tol);
    fprintf(fid, '| Obs state I5 (scaled) | %d/5 | %.4g | %.4g | %.3e |\n\n', ...
        R.obs_state.rank, R.obs_state.cond, R.obs_state.sigma(end), R.obs_state.tol);

    fprintf(fid, 'Finite-horizon gains Gfh=y(T=%.3fs) unit step (DERIVED):\n```\n', R.Tfh);
    print_mat(fid, R.Gfh);
    fprintf(fid, '```\nRidge-DC Gdc (ASSUMED regularizer):\n```\n');
    print_mat(fid, R.Gdc);
    fprintf(fid, '```\n%s\n\n', R.Gnote);

    fprintf(fid, 'Elevator/thrust cross-coupling (|Gfh| ratio δe/thrust):\n\n');
    fprintf(fid, '| Out | |G_de| | |G_th| | ratio | elev-dom? |\n|---|---:|---:|---:|:---:|\n');
    for i = 1:numel(R.out_names)
        fprintf(fid, '| %s | %.4g | %.4g | %.4g | %s |\n', R.out_names{i}, ...
            R.cross.abs_elev(i), R.cross.abs_thrust(i), ...
            R.cross.ratio_elev_over_thrust(i), tern(R.cross.elev_dominant(i),'Y','N'));
    end
    fprintf(fid, '\n');
end

function s = fmt_m(m)
    if m.near0
        s = 'n0';
    else
        s = sprintf('%.3g / %.3f', m.nrmse_rel, m.corr);
    end
end

function s = fmt_ev_list(ev)
    if isempty(ev)
        s = 'none';
        return;
    end
    parts = cell(numel(ev), 1);
    for k = 1:numel(ev)
        parts{k} = sprintf('%+.4g%+.4gi', real(ev(k)), imag(ev(k)));
    end
    s = strjoin(parts, '; ');
end

function print_mat(fid, M)
    for i = 1:size(M, 1)
        fprintf(fid, ' % .8e', M(i, 1));
        for j = 2:size(M, 2)
            fprintf(fid, '  % .8e', M(i, j));
        end
        fprintf(fid, '\n');
    end
end

function append_docs(out_dir, S)
    % STATE_SPACE_MODEL_AUDIT
    audit = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n---\n\n## %s — %s\n\n', S.task_id, S.stamp);
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Sources (exactly 3): LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat, SS_VALIDATION.mat\n');
    fprintf(fid, '- Driver: `run_depth_gamma_coupled_plant_id.m` (production untouched)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', S.paths.md, S.paths.mat, S.paths.png);
    fprintf(fid, '### Verdict\n\n');
    fprintf(fid, '**%s** — sagittal coupled depth/γ plant ID at level+climb U=1.5-class only.\n\n', S.verdict);
    fprintf(fid, '### Key\n\n');
    fprintf(fid, '- θ_phys=-θ (IMPLEMENTED); α=atan2(w,u) linearized (DERIVED); γ=θ_phys+α (DERIVED)\n');
    fprintf(fid, '- LEVEL unstable reduced: %s; CLIMB unstable reduced: %s\n', ...
        fmt_ev_list(S.level.unstable_red), fmt_ev_list(S.climb.unstable_red));
    fprintf(fid, '- Ctrl/Obs ranks level %d/%d, climb %d/%d (scaled sagittal)\n', ...
        S.level.ctrl.rank, S.level.obs.rank, S.climb.ctrl.rank, S.climb.obs.rank);
    fprintf(fid, '- Traj transform compare: %d/%d PASS (tol nrmse≤%.2f corr≥%.2f)\n', ...
        S.traj.n_pass, S.traj.n_cases, S.tol.nrmse_rel_max, S.tol.corr_min);
    fprintf(fid, '- Speed family U={1.0,1.5,2.0}: absent → Gate-1 full PASS not claimed\n');
    fprintf(fid, '- Hydro coeffs: TO_BE_IDENTIFIED (no invented provenance)\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- `%s`\n', S.next_task);
    fclose(fid);

    % PITCH_CONTROL_RESEARCH_LOG
    logp = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    fid = fopen(logp, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n## %s — %s\n\n', S.task_id, S.stamp);
    fprintf(fid, '- Gate-1 coupled plant ID: **%s** — level/climb sagittal model from validated SS; production frozen; no retune.\n', S.verdict);
    fprintf(fid, '- Sources (exactly 3): LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat, SS_VALIDATION.mat.\n');
    fprintf(fid, '- Model: x=[z,θ,u,w,q], u=[δe,thrust]; θ_phys=-θ; α=atan2(w,u) analytic lin; γ=θ_phys+α.\n');
    fprintf(fid, '- LEVEL u*=%.3f α*=%.4f deg; CLIMB u*=%.3f α*=%.4f deg.\n', ...
        S.level.trim.u, rad2deg(S.level.trim.alpha), S.climb.trim.u, rad2deg(S.climb.trim.alpha));
    fprintf(fid, '- Poles unstable (reduced): L=[%s] C=[%s]; ctrl/obs ranks L=%d/%d C=%d/%d.\n', ...
        fmt_ev_list(S.level.unstable_red), fmt_ev_list(S.climb.unstable_red), ...
        S.level.ctrl.rank, S.level.obs.rank, S.climb.ctrl.rank, S.climb.obs.rank);
    fprintf(fid, '- SS_VALIDATION transform RMSE/corr: %d/%d cases PASS (tol nrmse≤%.2f, corr≥%.2f).\n', ...
        S.traj.n_pass, S.traj.n_cases, S.tol.nrmse_rel_max, S.tol.corr_min);
    fprintf(fid, '- Honesty: U=1.5-class only; no bounded U=1.0/2.0 family in sources → not full Gate-1 PASS.\n');
    fprintf(fid, '- Artifacts: suite_results/DEPTH_GAMMA_COUPLED_PLANT_ID.{md,mat,png}; driver `run_depth_gamma_coupled_plant_id.m`.\n');
    fprintf(fid, '- Next: **`%s`** (U=1.0,1.5,2.0). CODEX_VERTICAL_PLAN untouched.\n', S.next_task);
    fclose(fid);

    % AUV_REALIZATION_READINESS_PLAN
    plan = fullfile(out_dir, 'AUV_REALIZATION_READINESS_PLAN.md');
    fid = fopen(plan, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n---\n\n## Append — %s (%s)\n\n', S.task_id, S.stamp);
    fprintf(fid, '**Gate 1 result: %s** (not full PASS — U=1.5 level/climb only).\n\n', S.verdict);
    fprintf(fid, '- Isolated ID from LOCAL_SS_LEVEL / LOCAL_SS_CLIMB / SS_VALIDATION; production frozen.\n');
    fprintf(fid, '- Sagittal coupled plant documented (z,u,w,θ,q)×(δe,thrust) with θ_phys/α/γ maps; traj compare %d/%d PASS.\n', ...
        S.traj.n_pass, S.traj.n_cases);
    fprintf(fid, '- Labels: A,B IDENTIFIED; θ_phys IMPLEMENTED; α/γ DERIVED; hydro coeffs TO_BE_IDENTIFIED; speed family TO_BE_IDENTIFIED.\n');
    fprintf(fid, '- Artifacts: `suite_results/DEPTH_GAMMA_COUPLED_PLANT_ID.{md,mat,png}`.\n');
    fprintf(fid, '- **Next exact task:** `%s` for U={1.0,1.5,2.0}. CODEX_VERTICAL_PLAN untouched.\n', S.next_task);
    fclose(fid);
end

function print_feedback(S)
    fprintf('FEEDBACK: %s  traj=%d/%d  next=%s\n', S.verdict, S.traj.n_pass, S.traj.n_cases, S.next_task);
    fprintf('  LEVEL: maxRe_red=%.4g ctrl=%d/5 obs=%d/5 cond_c=%.3g\n', ...
        max(real(S.level.eig_red)), S.level.ctrl.rank, S.level.obs.rank, S.level.ctrl.cond);
    fprintf('  CLIMB: maxRe_red=%.4g ctrl=%d/5 obs=%d/5 cond_c=%.3g\n', ...
        max(real(S.climb.eig_red)), S.climb.ctrl.rank, S.climb.obs.rank, S.climb.ctrl.cond);
    for i = 1:numel(S.traj.cases)
        c = S.traj.cases{i};
        fprintf('  %s/%s: %s\n', c.trim, c.channel, tern(c.pass,'PASS','FAIL'));
    end
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
