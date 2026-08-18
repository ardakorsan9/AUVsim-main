function run_depth_gamma_speed_scheduled_id_extension()
% DEPTH_GAMMA_SPEED_SCHEDULED_ID_001
% Gate-1 isolated extension: speed-scheduled sagittal coupled plant ID.
% Sources (exactly 3; read-only provenance for this task):
%   suite_results/DEPTH_GAMMA_COUPLED_PLANT_ID.md
%   run_depth_gamma_coupled_plant_id.m
%   suite_results/AUV_REALIZATION_READINESS_PLAN.md
% Method: same trim refine + scale-aware FD Jacobian + NL vs LTI validation
% as LOCAL_SS_* / SS_VALIDATION / DEPTH_GAMMA_COUPLED_PLANT_ID.
% U_cmd={1.0,1.5,2.0} × {level,climb}; record commanded vs achieved BODY
% surge and total speed separately; never relabel approximate trim as exact.
% One MATLAB invocation. Production frozen. No retune. CODEX untouched.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'DEPTH_GAMMA_SPEED_SCHEDULED_ID';
    task_id = 'DEPTH_GAMMA_SPEED_SCHEDULED_ID_001';
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    clear functions
    init_parameters();

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Gate-1 isolated extension; production frozen; no retune.\n');
    fprintf('U_cmd family = {1.0, 1.5, 2.0} × {level, climb}\n');

    % Scales / tolerances from prior trim/SS validation method (IDENTIFIED/ASSUMED)
    x_scale = [10; 10; 10; 1; 1; 1; 1.5; 0.3; 0.3; 0.2; 0.2; 0.2];
    u_scale = [deg2rad(25); deg2rad(15); 50];
    nu_dot_scale = [1.0; 0.3; 0.3; 0.2; 0.2; 0.2];
    pass_tol_trim = 0.01;          % IDENTIFIED (TRIM_OPERATING_POINTS)
    eps_rel = 1e-4;                % IDENTIFIED (LOCAL_SS_*)
    climb_slope = 0.4;             % IDENTIFIED (XZ climb z=0.4x)

    tol = struct();
    tol.nrmse_rel_max = 0.20;      % ASSUMED declared (same as coupled ID / SS_VALIDATION)
    tol.corr_min = 0.95;           % ASSUMED declared
    tol.energy_floor = 1e-4;       % ASSUMED
    tol.T_horizon = 0.60;          % IDENTIFIED (SS_VALIDATION / coupled ID)
    tol.T_pulse = 0.20;
    tol.dt = 0.005;
    tol.amp_deg = 0.5;
    tol.pass_tol_trim = pass_tol_trim;
    tol.note = ['NRMSE_rel<=0.20 and corr>=0.95 on energetic sagittal channels; ', ...
                'near-zero energy excluded; elevator pulse + theta IC; T=0.60 s'];

    ix = [3, 5, 7, 9, 11];         % z, theta, u, w, q
    iu = [2, 3];                   % delta_e, thrust
    sag_names = {'z','theta','u','w','q'};
    in_names  = {'delta_e','thrust'};
    out_names = {'z','theta_phys','alpha','gamma','w','q'};

    signs = struct();
    signs.frame = 'NED inertial eta + BODY nu; Euler ZYX';
    signs.z = 'NED z positive down [m]; depth ≡ z (IMPLEMENTED)';
    signs.theta = 'Euler theta [rad] BODY pitch; theta_phys = -theta (IMPLEMENTED)';
    signs.alpha = 'BODY alpha = atan2(w,u) [rad] (DERIVED)';
    signs.gamma = 'gamma = theta_phys + alpha [rad] (DERIVED)';
    signs.u_w = 'BODY surge u, heave w [m/s]; record U_cmd vs u* vs U_total=hypot(u,w) separately';
    signs.q = 'BODY pitch rate q [rad/s]';
    signs.delta_e = 'elevator [rad]; delta_e>0 → +Z/+M via Zuuds/Muuds*u^2 (IMPLEMENTED)';
    signs.thrust = 'thrust = Xprop [N] (IMPLEMENTED)';
    signs.hydro = ['Hydro numeric coeffs not re-identified; A,B are IDENTIFIED local FD ', ...
        'Jacobians of underwater777_vehicle_dynamics at documented trims. ', ...
        'No invented hydro confidence.'];

    % Seed from validated U≈1.5-class trims (prior Gate-1 sources); NOT claimed exact U=1.5
    seed_level = struct( ...
        'u_body', 1.81718, 'w', -0.0413785, 'theta', -0.0227668, ...
        'de', -0.0824284, 'thrust', 5.46329, ...
        'label', 'LOCAL_SS_LEVEL / TRIM level_U15 refined (U≈1.82 BODY; not exact 1.5)');
    seed_climb = struct( ...
        'u_body', 1.75462, 'w', -0.066866, 'theta', -0.418597, ...
        'de', -0.0211301, 'thrust', 7.01987, ...
        'label', 'LOCAL_SS_CLIMB / TRIM XZ_slope_z0p4x refined (U≈1.75 BODY; not exact 1.5)');

    U_cmd_list = [1.0, 1.5, 2.0];
    modes = {'level', 'climb'};
    points = {};
    n_trim_pass = 0;
    n_jac_pass = 0;
    n_val_pass = 0;
    n_val_cases = 0;

    for im = 1:numel(modes)
        mode = modes{im};
        for iu_cmd = 1:numel(U_cmd_list)
            Ucmd = U_cmd_list(iu_cmd);
            fprintf('\n----- %s @ U_cmd=%.1f -----\n', upper(mode), Ucmd);
            if strcmp(mode, 'level')
                P = identify_point(mode, Ucmd, 0.0, seed_level, x_scale, u_scale, ...
                    nu_dot_scale, pass_tol_trim, eps_rel, ix, iu, sag_names, ...
                    in_names, out_names, tol);
            else
                P = identify_point(mode, Ucmd, climb_slope, seed_climb, x_scale, u_scale, ...
                    nu_dot_scale, pass_tol_trim, eps_rel, ix, iu, sag_names, ...
                    in_names, out_names, tol);
            end
            points{end+1} = P; %#ok<AGROW>
            n_trim_pass = n_trim_pass + double(P.trim_pass);
            n_jac_pass  = n_jac_pass  + double(P.jac_pass);
            n_val_pass  = n_val_pass  + P.val.n_pass;
            n_val_cases = n_val_cases + P.val.n_cases;
            fprintf('  trim=%s jac=%s val=%d/%d  u*=%.4f U_tot=%.4f resid=%.3e\n', ...
                tern(P.trim_pass,'PASS','FAIL'), tern(P.jac_pass,'PASS','FAIL'), ...
                P.val.n_pass, P.val.n_cases, P.u_body, P.U_total, P.norm_dyn);
        end
    end

    % Cross-speed LPV / interpolation consistency (DERIVED from IDENTIFIED A,B)
    lpv = analyze_lpv(points, U_cmd_list, modes);

    % Gate verdict
    all_trim = (n_trim_pass == 6);
    all_jac  = (n_jac_pass == 6);
    all_val  = (n_val_pass == n_val_cases) && (n_val_cases == 12); % 6 pts × 2 cases
    blockers = {};
    if ~all_trim
        blockers{end+1} = sprintf('trim_fail %d/6 (tol norm_dyn<=%.2g)', n_trim_pass, pass_tol_trim); %#ok<AGROW>
    end
    if ~all_jac
        blockers{end+1} = sprintf('jac_fail %d/6 (dA/dB<=1%% + eig structure)', n_jac_pass); %#ok<AGROW>
    end
    if ~all_val
        blockers{end+1} = sprintf('val_fail %d/%d (nrmse<=%.2f corr>=%.2f elev+theta_ic)', ...
            n_val_pass, n_val_cases, tol.nrmse_rel_max, tol.corr_min); %#ok<AGROW>
        for k = 1:numel(points)
            Pk = points{k};
            for c = 1:numel(Pk.val.cases)
                cc = Pk.val.cases{c};
                if ~cc.pass
                    blockers{end+1} = sprintf('%s_U%.1f/%s: %s', ...
                        Pk.mode, Pk.U_cmd, cc.channel, cc.why_fail); %#ok<AGROW>
                end
            end
            if ~Pk.trim_pass
                blockers{end+1} = sprintf('%s_U%.1f: trim resid=%.3g', Pk.mode, Pk.U_cmd, Pk.norm_dyn); %#ok<AGROW>
            elseif ~Pk.jac_pass
                blockers{end+1} = sprintf('%s_U%.1f: jac dA=%.3g dB=%.3g', ...
                    Pk.mode, Pk.U_cmd, Pk.dA_rel, Pk.dB_rel); %#ok<AGROW>
            end
        end
    end

    if all_trim && all_jac && all_val
        verdict = 'PASS';
        next_task = 'depth_gamma_structural_decoupling_governor_aw_gate';
        next_note = ['Gate-1 speed-scheduled family PASS → Gate 2 structural depth/γ ', ...
                     'decoupling + reference governor + anti-windup (no rejected methods).'];
    elseif all_trim && all_jac && n_val_pass > 0
        verdict = 'PARTIAL';
        next_task = 'depth_gamma_speed_scheduled_id_blocker_fix';
        next_note = sprintf('Fix exact blocker(s): %s', strjoin(unique(blockers), ' | '));
    else
        verdict = 'FAIL';
        next_task = 'depth_gamma_speed_scheduled_id_blocker_fix';
        next_note = sprintf('Fix exact blocker(s): %s', strjoin(unique(blockers), ' | '));
    end
    if isempty(blockers)
        blocker_str = 'none';
    else
        blocker_str = strjoin(unique(blockers), ' | ');
    end

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_md(md_path, task_id, stamp, verdict, points, lpv, tol, signs, ...
        next_task, next_note, blocker_str, n_trim_pass, n_jac_pass, ...
        n_val_pass, n_val_cases, md_path, mat_path, png_path, seed_level, seed_climb);

    S = struct();
    S.task_id = task_id;
    S.stamp = stamp;
    S.verdict = verdict;
    S.gate = 'depth_gamma_coupled_plant_identification_gate';
    S.extension = 'speed_scheduled_U_1p0_1p5_2p0';
    S.sources_task = { ...
        fullfile(out_dir, 'DEPTH_GAMMA_COUPLED_PLANT_ID.md'); ...
        fullfile(project_dir, 'run_depth_gamma_coupled_plant_id.m'); ...
        fullfile(out_dir, 'AUV_REALIZATION_READINESS_PLAN.md')};
    S.U_cmd_list = U_cmd_list;
    S.modes = modes;
    S.points = points;
    S.lpv = lpv;
    S.tol = tol;
    S.signs = signs;
    S.n_trim_pass = n_trim_pass;
    S.n_jac_pass = n_jac_pass;
    S.n_val_pass = n_val_pass;
    S.n_val_cases = n_val_cases;
    S.blockers = blockers;
    S.blocker_str = blocker_str;
    S.next_task = next_task;
    S.next_note = next_note;
    S.labels = struct( ...
        'A_B', 'IDENTIFIED (scale-aware FD Jacobian at each trim)', ...
        'theta_phys', 'IMPLEMENTED', ...
        'alpha_lin', 'DERIVED', ...
        'gamma', 'DERIVED', ...
        'tol', 'ASSUMED declared ID tolerances', ...
        'hydro_coeffs', 'TO_BE_IDENTIFIED (no invented hydro confidence)', ...
        'speed_family', 'IDENTIFIED if all 6 trims+vals PASS else TO_BE_IDENTIFIED/PARTIAL', ...
        'U_cmd_vs_achieved', 'IDENTIFIED separately; never relabel approx as exact');
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.production_untouched = true;
    S.seed_level = seed_level;
    S.seed_climb = seed_climb;
    save(mat_path, '-struct', 'S');

    try
        write_png(png_path, points, lpv, task_id, verdict, tol);
    catch ME
        warning('PNG export failed: %s', ME.message);
        png_path = '';
        S.paths.png = png_path;
        save(mat_path, '-struct', 'S');
    end

    append_docs(out_dir, S);

    fprintf('\nVERDICT: %s\n', verdict);
    fprintf('Blocker: %s\n', blocker_str);
    fprintf('Next: %s\n', next_task);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(S);
end

%% ===================== per-point ID =====================

function P = identify_point(mode, U_cmd, slope, seed, x_scale, u_scale, ...
        nu_dot_scale, pass_tol, eps_rel, ix, iu, sag_names, in_names, out_names, tol)

    % Initial guess: scale seed to commanded BODY surge (solver then fixes u=U_cmd)
    ratio = U_cmd / max(seed.u_body, 0.1);
    x0 = zeros(12, 1);
    x0(5) = seed.theta;                 % pitch seed (climb keeps climb attitude)
    x0(7) = U_cmd;                      % commanded BODY surge (exact by construction in refine)
    x0(9) = seed.w * ratio;             % rough heave scale
    u0 = [0; seed.de / max(ratio, 0.1)^2; seed.thrust * ratio^2];

    ref = refine_translating(x0, u0, slope, nu_dot_scale);
    x_star = ref.x_star(:);
    u_star = ref.u_star(:);
    % Enforce commanded BODY surge honesty: solver holds u=U_cmd
    x_star(7) = U_cmd;

    f0 = underwater777_vehicle_dynamics(0, x_star, ustruct(u_star));
    R = residual_pack(f0, nu_dot_scale);
    % Slope residual check (not in norm_dyn; report separately)
    xd = f0(1); zd = f0(3);
    if abs(slope) < 1e-12
        slope_err = zd;
    else
        slope_err = zd - slope * xd;
    end

    u_body = x_star(7);
    w_body = x_star(9);
    U_total = hypot(u_body, w_body);
    U_cmd_err_u = abs(u_body - U_cmd);
    % Honesty: BODY surge is exact by construction; total speed is NOT commanded
    speed_honesty = struct( ...
        'U_cmd_body_surge', U_cmd, ...
        'u_body_achieved', u_body, ...
        'U_total_achieved', U_total, ...
        'w_body', w_body, ...
        'U_cmd_equals_u_body', U_cmd_err_u < 1e-12, ...
        'note', ['U_cmd is commanded BODY surge fixed in trim solver. ', ...
                 'U_total=hypot(u,w) is achieved total BODY speed — NOT commanded. ', ...
                 'Do not relabel U_total or window-mean ≈1.8 as exact U=1.5.']);

    trim_pass = (R.norm_dyn <= pass_tol) && (abs(slope_err) <= 0.01 * max(1, abs(U_cmd)));

    % Jacobian (same LOCAL_SS method)
    u0s = ustruct(u_star);
    [A1, B1] = scale_aware_fd(x_star, u0s, x_scale, u_scale, eps_rel);
    [A2, B2] = scale_aware_fd(x_star, u0s, x_scale, u_scale, eps_rel / 2);
    dA_rel = norm(A2 - A1, 'fro') / max(norm(A1, 'fro'), eps);
    dB_rel = norm(B2 - B1, 'fro') / max(norm(B1, 'fro'), eps);
    A = A2; B = B2;
    [ev_dom_ok, ev_report] = eigenvalue_structure_stable(eig(A1), eig(A2), 8);
    jac_pass = (dA_rel <= 0.01) && (dB_rel <= 0.01) && ev_dom_ok;

    Av = A(ix, ix); Bv = B(ix, iu);

    % Sagittal output map
    th_b = x_star(5);
    alpha0 = atan2(w_body, u_body);
    theta_phys0 = -th_b;
    gamma0 = theta_phys0 + alpha0;
    den = u_body^2 + w_body^2;
    if den < 1e-12
        dalpha_du = NaN; dalpha_dw = NaN;
        C = nan(6, 5);
    else
        dalpha_du = -w_body / den;
        dalpha_dw =  u_body / den;
        C = zeros(6, 5);
        C(1,1) = 1;
        C(2,2) = -1;
        C(3,3) = dalpha_du; C(3,4) = dalpha_dw;
        C(4,2) = -1; C(4,3) = dalpha_du; C(4,4) = dalpha_dw;
        C(5,4) = 1;
        C(6,5) = 1;
    end
    D = zeros(6, 2);

    ev_full = sort_ev(eig(A));
    ev_red  = sort_ev(eig(Av));
    unstable_full = ev_full(real(ev_full) > 1e-8);
    unstable_red  = ev_red(real(ev_red) > 1e-8);

    % Ctrl / Obs conditioning (scaled)
    xs = x_scale(ix); us = u_scale(iu);
    ys = [x_scale(3); 1; 1; 1; x_scale(9); x_scale(11)];
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
    QoI = obsv(As, eye(5));
    [~, SoI, ~] = svd(QoI, 'econ');
    sigI = diag(SoI);
    [rk_I, tol_I, cond_I] = rank_from_sigma(sigI, size(QoI,1), size(QoI,2));

    [Gdc, Gfh, Gnote] = gain_maps(Av, Bv, C, D, tol.T_horizon);
    cross = cross_coupling(Gfh, out_names);

    % NL vs LTI validation (elev pulse + theta IC)
    val = validate_point(x_star, u_star, A, B, C, ix, x_scale, ys, out_names, tol);

    P = struct();
    P.mode = mode;
    P.U_cmd = U_cmd;
    P.slope = slope;
    P.name = sprintf('%s_U%.1f', mode, U_cmd);
    P.x0 = x_star; P.u0 = u_star; P.f0 = f0;
    P.seed_label = seed.label;
    P.refine_exitflag = ref.exitflag;
    P.norm_dyn = R.norm_dyn;
    P.slope_err = slope_err;
    P.trim_pass = trim_pass;
    P.trim_class = sprintf('steady_translating_trim (%s; BODY u*=U_cmd=%.1f exact-by-construction)', mode, U_cmd);
    P.speed = speed_honesty;
    P.u_body = u_body; P.U_total = U_total; P.w = w_body;
    P.A = Av; P.B = Bv; P.C = C; P.D = D;
    P.A_full = A; P.B_full = B;
    P.dA_rel = dA_rel; P.dB_rel = dB_rel;
    P.jac_pass = jac_pass;
    P.ev_dom_ok = ev_dom_ok; P.ev_report = ev_report;
    P.eig_full = ev_full; P.eig_red = ev_red;
    P.unstable_full = unstable_full; P.unstable_red = unstable_red;
    P.trim = struct('u', u_body, 'w', w_body, 'theta', th_b, ...
        'theta_phys', theta_phys0, 'alpha', alpha0, 'gamma', gamma0, ...
        'dalpha_du', dalpha_du, 'dalpha_dw', dalpha_dw, 'U_total', U_total);
    P.ctrl = struct('rank', rk_c, 'n', 5, 'tol', tol_c, 'cond', cond_c, ...
        'sigma', sigc, 'sigma_min', sigc(end), 'sigma_max', sigc(1));
    P.obs = struct('rank', rk_o, 'n', 5, 'tol', tol_o, 'cond', cond_o, ...
        'sigma', sigo, 'sigma_min', sigo(end), 'sigma_max', sigo(1));
    P.obs_state = struct('rank', rk_I, 'n', 5, 'tol', tol_I, 'cond', cond_I, ...
        'sigma', sigI);
    P.Gdc = Gdc; P.Gfh = Gfh; P.Gnote = Gnote; P.Tfh = tol.T_horizon;
    P.cross = cross;
    P.val = val;
    P.sag_names = sag_names; P.in_names = in_names; P.out_names = out_names;
    P.ix = ix; P.iu = iu;
    P.x_scale = xs; P.u_scale = us; P.y_scale = ys;
    P.label_A = 'IDENTIFIED';
    P.provenance = struct( ...
        'plant', 'underwater777_vehicle_dynamics (IMPLEMENTED; not edited)', ...
        'trim_method', 'refine_translating Gauss-Newton (IDENTIFIED method from TRIM_OPERATING_POINTS)', ...
        'jac_method', 'scale-aware central FD eps & eps/2 (IDENTIFIED method from LOCAL_SS_*)', ...
        'val_method', 'NL vs LTI elev_pulse+theta_ic (IDENTIFIED method from SS_VALIDATION)', ...
        'seed', seed.label, ...
        'U_cmd_note', speed_honesty.note);
end

%% ===================== trim / FD / val helpers =====================

function R = refine_translating(x0, u0, slope, nu_dot_scale)
    Udes = x0(7);
    z0 = [x0(5); x0(8); x0(9); x0(11); u0(2); u0(3)];
    [z, exitflag] = local_newton(@(zz) translating_cost(zz, Udes, slope, nu_dot_scale), z0, 80);
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Udes; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    u = [0; z(5); z(6)];
    R = struct('x_star', x, 'u_star', u, 'exitflag', exitflag, 'z0', z0, 'z', z);
end

function c = translating_cost(z, Udes, slope, nu_dot_scale)
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Udes; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    f = underwater777_vehicle_dynamics(0, x, ustruct([0; z(5); z(6)]));
    nd = f(7:12) ./ nu_dot_scale;
    ad = f(4:5);
    xd = f(1); zd = f(3);
    if abs(slope) < 1e-12
        slope_err = zd;
    else
        slope_err = zd - slope * xd;
    end
    c = [nd; ad / 0.05; slope_err / max(0.1, abs(Udes))];
end

function [z, exitflag] = local_newton(fun, z0, maxit)
    z = z0(:);
    exitflag = 0;
    for it = 1:maxit
        c = fun(z); c = c(:);
        nrm = norm(c);
        if nrm < 1e-10
            exitflag = 1; return;
        end
        m = numel(c); n = numel(z);
        J = zeros(m, n);
        for j = 1:n
            h = 1e-6 * max(1, abs(z(j)));
            zp = z; zp(j) = zp(j) + h;
            J(:, j) = (fun(zp) - c) / h;
        end
        step = -J \ c;
        if any(~isfinite(step)); step = -pinv(J) * c; end
        alpha = 1.0; accepted = false;
        for ls = 1:8
            ztry = z + alpha * step;
            if norm(fun(ztry)) < nrm
                z = ztry; accepted = true; break;
            end
            alpha = 0.5 * alpha;
        end
        if ~accepted; exitflag = -2; return; end
        if norm(alpha * step) < 1e-12; exitflag = 2; return; end
    end
    exitflag = -1;
end

function R = residual_pack(f, nu_dot_scale)
    R = struct();
    R.f = f;
    R.nu_dot = f(7:12);
    R.nu_dot_norm_comp = abs(R.nu_dot) ./ nu_dot_scale;
    R.norm_dyn = max(R.nu_dot_norm_comp);
end

function [A, B] = scale_aware_fd(x0, u0, x_scale, u_scale, eps_rel)
    n = 12; m = 3;
    A = zeros(n); B = zeros(n, m);
    dx = max(eps_rel * x_scale, 1e-9 * x_scale);
    du = max(eps_rel * u_scale, 1e-9 * u_scale);
    for i = 1:n
        xp = x0; xm = x0;
        xp(i) = xp(i) + dx(i); xm(i) = xm(i) - dx(i);
        A(:, i) = (underwater777_vehicle_dynamics(0, xp, u0) - ...
                   underwater777_vehicle_dynamics(0, xm, u0)) / (2 * dx(i));
    end
    for j = 1:m
        up = u0; um = u0;
        switch j
            case 1
                up.delta_r = up.delta_r + du(j); um.delta_r = um.delta_r - du(j);
            case 2
                up.delta_e = up.delta_e + du(j); um.delta_e = um.delta_e - du(j);
            case 3
                up.thrust = up.thrust + du(j); um.thrust = um.thrust - du(j);
        end
        B(:, j) = (underwater777_vehicle_dynamics(0, x0, up) - ...
                   underwater777_vehicle_dynamics(0, x0, um)) / (2 * du(j));
    end
end

function [ok, report] = eigenvalue_structure_stable(ev1, ev2, n_dom)
    e1 = sort_ev(ev1); e2 = sort_ev(ev2);
    n_dom = min([n_dom, numel(e1), numel(e2)]);
    s1 = sign(real(e1(1:n_dom))); s1(abs(real(e1(1:n_dom))) < 1e-8) = 0;
    s2 = sign(real(e2(1:n_dom))); s2(abs(real(e2(1:n_dom))) < 1e-8) = 0;
    sign_ok = isequal(s1, s2);
    re_err = 0;
    for k = 1:n_dom
        denom = max([abs(e1(k)), abs(e2(k)), 1e-8]);
        re_err = max(re_err, abs(e2(k) - e1(k)) / denom);
    end
    mag_ok = re_err <= 0.25;
    ok = sign_ok && mag_ok;
    report = struct('n_dom', n_dom, 'sign_ok', sign_ok, 'mag_ok', mag_ok, ...
        'max_rel_ev_change', re_err);
end

function val = validate_point(x0, u0, A, B, C, ix, x_scale, y_scale, out_names, tol)
    T = tol.T_horizon; Tp = tol.T_pulse; dt = tol.dt;
    t = (0:dt:T).';
    amp = deg2rad(tol.amp_deg);
    cases_in = { ...
        struct('channel','elev_pulse','kind','pulse','iu',2,'amp',amp,'dx0',zeros(12,1)); ...
        struct('channel','theta_ic','kind','ic','iu',0,'amp',0, ...
               'dx0',[0;0;0;0;amp;0;0;0;0;0;0;0])};
    cases = cell(numel(cases_in), 1);
    for k = 1:numel(cases_in)
        cases{k} = run_val_case(cases_in{k}, t, Tp, x0, u0, A, B, C, ix, ...
            x_scale, y_scale, out_names, tol);
    end
    val = struct();
    val.cases = cases;
    val.n_cases = numel(cases);
    val.n_pass = sum(cellfun(@(c) c.pass, cases));
    val.overall_pass = all(cellfun(@(c) c.pass, cases));
    val.tol = tol;
end

function c = run_val_case(cin, t, T_pulse, x0, u0, A, B, C, ix, x_scale, y_scale, out_names, tol)
    n = numel(t);
    du = zeros(n, 3);
    if strcmp(cin.kind, 'pulse')
        du(t <= T_pulse, cin.iu) = cin.amp;
    end
    Xn = zeros(n, 12); Xp = zeros(n, 12);
    Xn(1,:) = x0.'; Xp(1,:) = (x0 + cin.dx0).';
    for k = 1:n-1
        dtk = t(k+1) - t(k);
        un = ustruct(u0); up = ustruct(u0 + du(k,:).');
        Xn(k+1,:) = rk4(@(tt,g) underwater777_vehicle_dynamics(tt,g,un), t(k), Xn(k,:).', dtk).';
        Xp(k+1,:) = rk4(@(tt,g) underwater777_vehicle_dynamics(tt,g,up), t(k), Xp(k,:).', dtk).';
    end
    dx_nl = Xp - Xn;
    dx_lin = zeros(n, 12); dx_lin(1,:) = cin.dx0.';
    for k = 1:n-1
        dtk = t(k+1) - t(k);
        duv = du(k,:).';
        dx_lin(k+1,:) = rk4(@(tt,z) A*z + B*duv, t(k), dx_lin(k,:).', dtk).';
    end

    Ynl = transform_traj(x0, dx_nl);
    Ylin = transform_traj(x0, dx_lin);
    Ylin_C = dx_lin(:, ix) * C.';

    metrics = struct();
    pass_ch = true(1, 6);
    why = strings(1, 6);
    for i = 1:6
        yn = Ynl(:, i); yl = Ylin(:, i);
        e = yn - yl;
        rmse = sqrt(mean(e.^2));
        energy = sqrt(mean((yn / max(y_scale(i), eps)).^2));
        near0 = energy < tol.energy_floor;
        denom = max(sqrt(mean(yn.^2)), 0.05 * y_scale(i));
        nrmse_rel = rmse / denom;
        if near0 || std(yn) < 1e-12 || std(yl) < 1e-12
            corr = NaN;
        else
            R = corrcoef(yn, yl); corr = R(1, 2);
        end
        ok = true;
        if ~near0
            ok = (nrmse_rel <= tol.nrmse_rel_max);
            if ~isnan(corr); ok = ok && (corr >= tol.corr_min); end
        end
        pass_ch(i) = ok;
        if near0
            why(i) = "near-zero (excl)";
        elseif ok
            why(i) = "OK";
        else
            why(i) = sprintf("FAIL nrmse=%.3g corr=%.3g", nrmse_rel, corr);
        end
        metrics.(out_names{i}) = struct('nrmse_rel', nrmse_rel, 'corr', corr, ...
            'energy_n', energy, 'near0', near0, 'pass', ok, ...
            'nrmse_rel_linmap', sqrt(mean((yn - Ylin_C(:,i)).^2)) / denom);
    end

    c = struct();
    c.channel = cin.channel;
    c.t = t;
    c.Ynl = Ynl; c.Ylin = Ylin;
    c.metrics = metrics;
    c.pass_ch = pass_ch;
    c.pass = all(pass_ch);
    c.why = why;
    if c.pass
        c.why_fail = '';
    else
        bad = find(~pass_ch);
        bits = cell(numel(bad), 1);
        for ii = 1:numel(bad)
            bits{ii} = sprintf('%s:%s', out_names{bad(ii)}, why(bad(ii)));
        end
        c.why_fail = strjoin(bits, ',');
    end
    c.out_names = out_names;
end

function Y = transform_traj(x0, dx)
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
        Y(k, :) = [z, thp - (-th0), alp - a0, gam - (-th0 + a0), w - w0, q];
    end
end

function x1 = rk4(f, t, x, dt)
    k1 = f(t, x);
    k2 = f(t+0.5*dt, x+0.5*dt*k1);
    k3 = f(t+0.5*dt, x+0.5*dt*k2);
    k4 = f(t+dt, x+dt*k3);
    x1 = x + (dt/6)*(k1+2*k2+2*k3+k4);
end

function [Gdc, Gfh, note] = gain_maps(A, B, C, D, T)
    n = size(A, 1); m = size(B, 2); p = size(C, 1);
    Gfh = zeros(p, m);
    dt = min(0.005, T/100); t = (0:dt:T).';
    for j = 1:m
        x = zeros(n, 1); ej = zeros(m, 1); ej(j) = 1;
        for k = 1:numel(t)-1
            k1 = A*x + B*ej;
            k2 = A*(x+0.5*dt*k1) + B*ej;
            k3 = A*(x+0.5*dt*k2) + B*ej;
            k4 = A*(x+dt*k3) + B*ej;
            x = x + (dt/6)*(k1+2*k2+2*k3+k4);
        end
        Gfh(:, j) = C*x + D*ej;
    end
    eps_reg = 1e-4;
    Gdc = C * (-(A - eps_reg*eye(n)) \ B) + D;
    note = sprintf(['Gfh = reduced LTI step @ T=%.3fs (DERIVED); ', ...
        'Gdc = ridge-DC eps=%.0e (ASSUMED regularizer; z-integrator)'], T, eps_reg);
end

function cross = cross_coupling(Gfh, out_names)
    ge = abs(Gfh(:,1)); gt = abs(Gfh(:,2));
    cross = struct('abs_elev', ge, 'abs_thrust', gt, ...
        'ratio_elev_over_thrust', ge ./ max(gt, 1e-16), ...
        'elev_dominant', ge >= gt, 'out_names', {out_names});
end

%% ===================== LPV / envelope =====================

function lpv = analyze_lpv(points, U_cmd_list, modes)
    lpv = struct();
    lpv.U_cmd = U_cmd_list;
    lpv.modes = modes;
    lpv.note = ['Interpolation/LPV consistency DERIVED from IDENTIFIED A,B at discrete ', ...
                'U_cmd. Confidence proxy = residual-spread / pole-migration only; ', ...
                'NO invented hydro coefficient confidence.'];

    for im = 1:numel(modes)
        mode = modes{im};
        idx = find(cellfun(@(p) strcmp(p.mode, mode), points));
        [~, ord] = sort(arrayfun(@(i) points{i}.U_cmd, idx));
        idx = idx(ord);
        U = arrayfun(@(i) points{i}.U_cmd, idx);
        resid = arrayfun(@(i) points{i}.norm_dyn, idx);
        maxRe = arrayfun(@(i) max(real(points{i}.eig_red)), idx);
        Anorm = arrayfun(@(i) norm(points{i}.A, 'fro'), idx);
        Bnorm = arrayfun(@(i) norm(points{i}.B, 'fro'), idx);
        Gde_g = arrayfun(@(i) abs(points{i}.Gfh(4,1)), idx); % |gamma←de|

        % Mid-speed interp check at U=1.5 using U=1.0 and U=2.0 endpoints
        i0 = find(abs(U - 1.0) < 1e-9, 1);
        i1 = find(abs(U - 1.5) < 1e-9, 1);
        i2 = find(abs(U - 2.0) < 1e-9, 1);
        if ~isempty(i0) && ~isempty(i1) && ~isempty(i2) ...
                && points{idx(i0)}.trim_pass && points{idx(i2)}.trim_pass ...
                && points{idx(i1)}.trim_pass
            A_interp = 0.5 * (points{idx(i0)}.A + points{idx(i2)}.A);
            B_interp = 0.5 * (points{idx(i0)}.B + points{idx(i2)}.B);
            dA = norm(A_interp - points{idx(i1)}.A, 'fro') / max(norm(points{idx(i1)}.A, 'fro'), eps);
            dB = norm(B_interp - points{idx(i1)}.B, 'fro') / max(norm(points{idx(i1)}.B, 'fro'), eps);
            interp_ok = (dA <= 0.25) && (dB <= 0.25); % ASSUMED mild LPV smoothness gate
            interp = struct('dA_rel', dA, 'dB_rel', dB, 'ok_assumed_0p25', interp_ok, ...
                'label', 'ASSUMED smoothness gate 25% Frobenius vs linear U-interp');
        else
            interp = struct('dA_rel', NaN, 'dB_rel', NaN, 'ok_assumed_0p25', false, ...
                'label', 'interp unavailable (missing endpoint trim)');
        end

        M = struct();
        M.mode = mode;
        M.U = U;
        M.resid = resid;
        M.resid_spread = max(resid) - min(resid);
        M.resid_max = max(resid);
        M.maxRe_red = maxRe;
        M.Anorm = Anorm;
        M.Bnorm = Bnorm;
        M.Gfh_gamma_de = Gde_g;
        M.interp = interp;
        M.confidence_proxy = struct( ...
            'type', 'trim_residual_spread_across_U', ...
            'resid_spread', M.resid_spread, ...
            'resid_max', M.resid_max, ...
            'hydro_confidence', 'NOT_CLAIMED (TO_BE_IDENTIFIED; no invented hydro CI)', ...
            'note', 'Proxy only from trim residual spread; not a hydro coefficient CI');
        % Validity envelope: U where trim+jac+val all pass
        valid_U = [];
        for k = 1:numel(idx)
            Pk = points{idx(k)};
            if Pk.trim_pass && Pk.jac_pass && Pk.val.overall_pass
                valid_U(end+1) = Pk.U_cmd; %#ok<AGROW>
            end
        end
        M.valid_U = valid_U;
        if isempty(valid_U)
            M.envelope = 'empty — no fully valid speed in this mode';
        else
            M.envelope = sprintf('U_cmd in [%.1f, %.1f] with %d/%d valid', ...
                min(valid_U), max(valid_U), numel(valid_U), numel(idx));
        end
        lpv.(mode) = M;
    end
end

%% ===================== numerics =====================

function e = sort_ev(ev)
    [~, ix] = sort(real(ev), 'descend');
    e = ev(ix);
end

function [rk, tol, condn] = rank_from_sigma(sig, m, n)
    if isempty(sig); rk = 0; tol = 0; condn = Inf; return; end
    tol = max(m, n) * eps(max(sig));
    rk = nnz(sig > tol);
    if sig(end) <= 0; condn = Inf; else; condn = sig(1) / max(sig(end), eps); end
end

function u = ustruct(uv)
    uv = uv(:);
    u = struct('delta_r', uv(1), 'delta_e', uv(2), 'thrust', uv(3));
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end

%% ===================== artifacts =====================

function write_png(png_path, points, lpv, task_id, verdict, tol)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 1600 1100]);

    % Collect by mode
    lev = points(cellfun(@(p) strcmp(p.mode,'level'), points));
    clb = points(cellfun(@(p) strcmp(p.mode,'climb'), points));

    subplot(3, 3, 1);
    hold on;
    for k = 1:numel(lev)
        plot(real(lev{k}.eig_red), imag(lev{k}.eig_red), 'o', 'MarkerSize', 7);
    end
    xline(0,'k:'); yline(0,'k:'); grid on;
    xlabel('Re'); ylabel('Im'); title('LEVEL sagittal poles vs U');
    if ~isempty(lev)
        legend(arrayfun(@(k) sprintf('U=%.1f', lev{k}.U_cmd), 1:numel(lev), 'uni', 0), ...
            'Location', 'best');
    end

    subplot(3, 3, 2);
    hold on;
    for k = 1:numel(clb)
        plot(real(clb{k}.eig_red), imag(clb{k}.eig_red), 'x', 'MarkerSize', 8, 'LineWidth', 1.2);
    end
    xline(0,'k:'); yline(0,'k:'); grid on;
    xlabel('Re'); ylabel('Im'); title('CLIMB sagittal poles vs U');

    subplot(3, 3, 3);
    Ul = cellfun(@(p) p.U_cmd, lev); Uc = cellfun(@(p) p.U_cmd, clb);
    plot(Ul, cellfun(@(p) p.U_total, lev), 'bo-', 'LineWidth', 1.2); hold on;
    plot(Uc, cellfun(@(p) p.U_total, clb), 'rs-', 'LineWidth', 1.2);
    plot([1 2], [1 2], 'k--');
    grid on; xlabel('U_cmd BODY surge'); ylabel('achieved');
    legend('level U_{tot}','climb U_{tot}','U_{tot}=U_{cmd}', 'Location', 'best');
    title('U_{cmd} vs U_{total}=hypot(u,w)');

    subplot(3, 3, 4);
    bar([cellfun(@(p) p.ctrl.rank, points); cellfun(@(p) p.obs.rank, points)].');
    ylim([0 6]); grid on;
    set(gca, 'XTick', 1:numel(points), 'XTickLabel', ...
        cellfun(@(p) sprintf('%s%.1f', p.mode(1), p.U_cmd), points, 'uni', 0), ...
        'XTickLabelRotation', 40);
    legend('ctrl','obs'); title(sprintf('Ctrl/Obs ranks — %s', verdict));

    subplot(3, 3, 5);
    imagesc(cell2mat(cellfun(@(p) abs(p.Gfh(:,1)), points, 'uni', 0)));
    colorbar; axis tight;
    set(gca, 'YTick', 1:6, 'YTickLabel', points{1}.out_names, ...
        'XTick', 1:numel(points), 'XTickLabel', ...
        cellfun(@(p) sprintf('%s%.1f', p.mode(1), p.U_cmd), points, 'uni', 0), ...
        'XTickLabelRotation', 40);
    title('|Gfh| elev column @T');

    subplot(3, 3, 6);
    plot(lpv.level.U, lpv.level.Anorm, 'bo-', 'LineWidth', 1.2); hold on;
    plot(lpv.climb.U, lpv.climb.Anorm, 'rs-', 'LineWidth', 1.2);
    grid on; xlabel('U_cmd'); ylabel('||A_{sag}||_F');
    legend('level','climb'); title('A-norm schedule');

    % Validation nrmse bars
    subplot(3, 3, 7);
    names = {}; vals = [];
    for i = 1:numel(points)
        for j = 1:numel(points{i}.val.cases)
            cc = points{i}.val.cases{j};
            for k = 1:numel(cc.out_names)
                m = cc.metrics.(cc.out_names{k});
                if ~m.near0
                    names{end+1} = sprintf('%s%.0f/%s/%s', points{i}.mode(1), ...
                        10*points{i}.U_cmd, cc.channel(1:3), cc.out_names{k}(1:min(3,end))); %#ok<AGROW>
                    vals(end+1) = m.nrmse_rel; %#ok<AGROW>
                end
            end
        end
    end
    if ~isempty(vals)
        bar(vals); hold on; yline(tol.nrmse_rel_max, 'r--');
        set(gca, 'XTick', 1:numel(names), 'XTickLabel', names, 'XTickLabelRotation', 70);
        ylabel('nrmse_rel'); grid on;
        title('NL vs LTI energetic channels');
    else
        axis off; text(0.1, 0.5, 'no energetic channels');
    end

    % Example overlay: level U=1.5 elev gamma/alpha
    subplot(3, 3, 8);
    p15 = [];
    for i = 1:numel(points)
        if strcmp(points{i}.mode,'level') && abs(points{i}.U_cmd-1.5)<1e-9
            p15 = points{i}; break;
        end
    end
    if ~isempty(p15)
        cL = p15.val.cases{1};
        plot(cL.t, rad2deg(cL.Ynl(:,4)), 'k', 'LineWidth', 1.2); hold on;
        plot(cL.t, rad2deg(cL.Ylin(:,4)), 'r--', 'LineWidth', 1.1);
        plot(cL.t, rad2deg(cL.Ynl(:,3)), 'b');
        plot(cL.t, rad2deg(cL.Ylin(:,3)), 'c--');
        grid on; xlabel('t [s]'); ylabel('deg');
        title('level U=1.5 elev: \gamma,\alpha NL vs LTI');
        legend('\gamma_{NL}','\gamma_{LTI}','\alpha_{NL}','\alpha_{LTI}', 'Location', 'best');
    else
        axis off;
    end

    subplot(3, 3, 9);
    axis off;
    txt = {
        sprintf('VERDICT: %s', verdict)
        sprintf('trim %d/6  jac %d/6  val %d/%d', ...
            sum(cellfun(@(p) p.trim_pass, points)), ...
            sum(cellfun(@(p) p.jac_pass, points)), ...
            sum(cellfun(@(p) p.val.n_pass, points)), ...
            sum(cellfun(@(p) p.val.n_cases, points)))
        sprintf('level env: %s', lpv.level.envelope)
        sprintf('climb env: %s', lpv.climb.envelope)
        sprintf('level resid_spread=%.2e', lpv.level.resid_spread)
        sprintf('climb resid_spread=%.2e', lpv.climb.resid_spread)
        'hydro CI: NOT_CLAIMED'
        };
    text(0.02, 0.95, strjoin(txt, char(10)), 'FontName', 'FixedWidth', ...
        'FontSize', 10, 'VerticalAlignment', 'top', 'Interpreter', 'none');

    sgtitle(sprintf('%s — speed-scheduled sagittal ID [%s]', task_id, verdict), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, task_id, stamp, verdict, points, lpv, tol, signs, ...
        next_task, next_note, blocker_str, n_trim_pass, n_jac_pass, ...
        n_val_pass, n_val_cases, md_path_s, mat_path, png_path, seed_level, seed_climb)

    fid = fopen(md_path, 'w');
    assert(fid > 0);
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# %s — Depth/γ speed-scheduled sagittal plant ID\n\n', task_id);
    fprintf(fid, '**Gate-1 verdict: %s**  \n', verdict);
    fprintf(fid, '**Stamp:** %s  \n', stamp);
    fprintf(fid, '**Blocker:** %s  \n', blocker_str);
    fprintf(fid, '**Next exact task:** `%s`\n\n', next_task);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Task sources (exactly 3): `DEPTH_GAMMA_COUPLED_PLANT_ID.md`, ');
    fprintf(fid, '`run_depth_gamma_coupled_plant_id.m`, `AUV_REALIZATION_READINESS_PLAN.md`\n');
    fprintf(fid, '- Method sources (reused, not re-edited): TRIM refine + LOCAL_SS scale-aware FD + SS_VALIDATION NL/LTI\n');
    fprintf(fid, '- Driver: `run_depth_gamma_speed_scheduled_id_extension.m` (isolated; production untouched)\n');
    fprintf(fid, '- Plant RHS: `underwater777_vehicle_dynamics` (IMPLEMENTED; not re-edited)\n');
    fprintf(fid, '- Seeds: level `%s`; climb `%s`\n', seed_level.label, seed_climb.label);
    fprintf(fid, '- No controller/guidance/plant edits; no retune; CODEX_VERTICAL_PLAN untouched\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path_s, mat_path, png_path);

    fprintf(fid, '## Evidence labels\n\n');
    fprintf(fid, '| Item | Label |\n|---|---|\n');
    fprintf(fid, '| Local A,B per (mode,U) | IDENTIFIED |\n');
    fprintf(fid, '| theta_phys=-theta | IMPLEMENTED |\n');
    fprintf(fid, '| alpha/gamma maps | DERIVED |\n');
    fprintf(fid, '| ID tolerances | ASSUMED (declared) |\n');
    fprintf(fid, '| Hydro coeff provenance / CI | TO_BE_IDENTIFIED (not invented) |\n');
    fprintf(fid, '| Speed family U={1.0,1.5,2.0} | %s |\n\n', ...
        tern(strcmp(verdict,'PASS'),'IDENTIFIED','PARTIAL/FAIL — see blockers'));

    fprintf(fid, '## BODY / NED signs and speed honesty\n\n');
    fprintf(fid, '- Frame: %s\n', signs.frame);
    fprintf(fid, '- %s\n', signs.z);
    fprintf(fid, '- %s\n', signs.theta);
    fprintf(fid, '- %s\n', signs.alpha);
    fprintf(fid, '- %s\n', signs.gamma);
    fprintf(fid, '- %s\n', signs.u_w);
    fprintf(fid, '- %s\n', signs.q);
    fprintf(fid, '- %s\n', signs.delta_e);
    fprintf(fid, '- %s\n', signs.thrust);
    fprintf(fid, '- %s\n\n', signs.hydro);

    fprintf(fid, '### Commanded vs achieved speeds (never relabel approx as exact)\n\n');
    fprintf(fid, '| Point | U_cmd BODY surge | u* BODY | U_total=hypot(u,w) | u==U_cmd? | trim |\n');
    fprintf(fid, '|---|---:|---:|---:|:---:|:---:|\n');
    for i = 1:numel(points)
        P = points{i};
        fprintf(fid, '| %s | %.3f | %.6g | %.6g | %s | %s |\n', ...
            P.name, P.U_cmd, P.u_body, P.U_total, ...
            tern(P.speed.U_cmd_equals_u_body,'Y','N'), tern(P.trim_pass,'PASS','FAIL'));
    end
    fprintf(fid, '\nPrior Gate-1 LOCAL_SS level/climb used window BODY u*≈1.82/1.75 ');
    fprintf(fid, '(U=1.5-class, **not** exact 1.5). This extension fixes BODY surge ');
    fprintf(fid, 'to exact U_cmd in the trim solver; U_total remains distinct.\n\n');

    fprintf(fid, '## Rollup\n\n');
    fprintf(fid, '| Check | Score |\n|---|---:|\n');
    fprintf(fid, '| Trim PASS | %d/6 |\n', n_trim_pass);
    fprintf(fid, '| Jacobian PASS | %d/6 |\n', n_jac_pass);
    fprintf(fid, '| Validation PASS | %d/%d |\n', n_val_pass, n_val_cases);
    fprintf(fid, '| Verdict | **%s** |\n\n', verdict);

    fprintf(fid, '## Declared ID tolerances\n\n');
    fprintf(fid, '| Quantity | Value | Label |\n|---|---:|---|\n');
    fprintf(fid, '| trim norm_dyn max | %.2f | IDENTIFIED |\n', tol.pass_tol_trim);
    fprintf(fid, '| nrmse_rel max | %.2f | ASSUMED |\n', tol.nrmse_rel_max);
    fprintf(fid, '| corr min | %.2f | ASSUMED |\n', tol.corr_min);
    fprintf(fid, '| energy floor | %.1e | ASSUMED |\n', tol.energy_floor);
    fprintf(fid, '| horizon T | %.3f s | IDENTIFIED |\n\n', tol.T_horizon);
    fprintf(fid, '%s\n\n', tol.note);

    for i = 1:numel(points)
        write_op_md(fid, points{i});
    end

    fprintf(fid, '## Interpolation / LPV consistency\n\n');
    fprintf(fid, '%s\n\n', lpv.note);
    for mode = {'level','climb'}
        M = lpv.(mode{1});
        fprintf(fid, '### %s\n\n', upper(mode{1}));
        fprintf(fid, '- Validity envelope: %s\n', M.envelope);
        fprintf(fid, '- Residuals @ U=%s: [%s]\n', mat2str(M.U), num2str(M.resid, '%.3e '));
        fprintf(fid, '- Residual spread (confidence proxy): %.3e (max=%.3e)\n', ...
            M.resid_spread, M.resid_max);
        fprintf(fid, '- Hydro coefficient CI: **%s**\n', M.confidence_proxy.hydro_confidence);
        fprintf(fid, '- maxRe(reduced) @ U: [%s]\n', num2str(M.maxRe_red, '%.4g '));
        fprintf(fid, '- ||A||_F: [%s]; ||B||_F: [%s]\n', ...
            num2str(M.Anorm, '%.4g '), num2str(M.Bnorm, '%.4g '));
        fprintf(fid, '- Linear interp U=1.5 from {1.0,2.0}: dA_rel=%.4g dB_rel=%.4g (%s; %s)\n\n', ...
            M.interp.dA_rel, M.interp.dB_rel, ...
            tern(M.interp.ok_assumed_0p25,'OK','FAIL/NA'), M.interp.label);
    end

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '- Exact next task: `%s`\n', next_task);
    fprintf(fid, '- %s\n', next_note);
    fprintf(fid, '- Reusable artifacts: `suite_results/DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}`\n');
end

function write_op_md(fid, R)
    fprintf(fid, '### Operating point: %s\n\n', upper(R.name));
    fprintf(fid, '```\n');
    fprintf(fid, 'U_cmd(BODY surge)=%.3f  u*=%.6g  w*=%.6g  U_total=%.6g\n', ...
        R.U_cmd, R.u_body, R.w, R.U_total);
    fprintf(fid, 'x* = [%s]\nu* = [%s]\n', num2str(R.x0.', ' %.6g'), num2str(R.u0.', ' %.6g'));
    fprintf(fid, 'trim: θ=%.6g θ_phys=%.6g α=%.6g γ=%.6g\n', ...
        R.trim.theta, R.trim.theta_phys, R.trim.alpha, R.trim.gamma);
    fprintf(fid, 'dα/du=%.6g  dα/dw=%.6g\n', R.trim.dalpha_du, R.trim.dalpha_dw);
    fprintf(fid, 'norm_dyn=%.3e  slope_err=%.3e  trim=%s  jac=%s  exitflag=%d\n', ...
        R.norm_dyn, R.slope_err, tern(R.trim_pass,'PASS','FAIL'), ...
        tern(R.jac_pass,'PASS','FAIL'), R.refine_exitflag);
    fprintf(fid, 'dA_rel=%.4g  dB_rel=%.4g  (gate <=1%%)\n', R.dA_rel, R.dB_rel);
    fprintf(fid, 'class: %s\n', R.trim_class);
    fprintf(fid, '```\n\n');

    if ~(R.trim_pass && R.jac_pass)
        fprintf(fid, '_Point incomplete — matrices/validation may be non-authoritative._\n\n');
    end

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

    fprintf(fid, 'NL vs LTI validation (elev_pulse + theta_ic): **%s** (%d/%d)\n\n', ...
        tern(R.val.overall_pass,'PASS','FAIL'), R.val.n_pass, R.val.n_cases);
    fprintf(fid, '| Channel | PASS | z | θ_phys | α | γ | w | q |\n');
    fprintf(fid, '|---|:---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:numel(R.val.cases)
        c = R.val.cases{i};
        fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
            c.channel, tern(c.pass,'PASS','FAIL'), ...
            fmt_m(c.metrics.z), fmt_m(c.metrics.theta_phys), fmt_m(c.metrics.alpha), ...
            fmt_m(c.metrics.gamma), fmt_m(c.metrics.w), fmt_m(c.metrics.q));
    end
    fprintf(fid, '\nCells: `nrmse_rel / corr` (n0 = near-zero excluded).\n');
    if ~R.val.overall_pass
        for i = 1:numel(R.val.cases)
            if ~R.val.cases{i}.pass
                fprintf(fid, '- FAIL detail `%s`: %s\n', R.val.cases{i}.channel, R.val.cases{i}.why_fail);
            end
        end
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
    if isempty(ev); s = 'none'; return; end
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
    % AUV_REALIZATION_READINESS_PLAN
    plan = fullfile(out_dir, 'AUV_REALIZATION_READINESS_PLAN.md');
    fid = fopen(plan, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n---\n\n## Append — %s (%s)\n\n', S.task_id, S.stamp);
    fprintf(fid, '**Gate 1 result: %s**', S.verdict);
    if ~strcmp(S.verdict, 'PASS')
        fprintf(fid, ' — blocker: %s', S.blocker_str);
    end
    fprintf(fid, '.\n\n');
    fprintf(fid, '- Isolated speed-scheduled sagittal ID at U_cmd={1.0,1.5,2.0}×{level,climb}; production frozen.\n');
    fprintf(fid, '- Trim %d/6, jac %d/6, val %d/%d; BODY U_cmd vs u* vs U_total recorded separately.\n', ...
        S.n_trim_pass, S.n_jac_pass, S.n_val_pass, S.n_val_cases);
    fprintf(fid, '- Hydro CI: NOT_CLAIMED (TO_BE_IDENTIFIED). Artifacts: `suite_results/DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}`.\n');
    fprintf(fid, '- **Next exact task:** `%s`. CODEX_VERTICAL_PLAN untouched.\n', S.next_task);
    fclose(fid);

    % AUV_REALISM_AND_VISUAL_VALIDATION
    realism = fullfile(out_dir, 'AUV_REALISM_AND_VISUAL_VALIDATION.md');
    fid = fopen(realism, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n---\n\n## APPEND — %s — %s\n\n', S.task_id, S.stamp);
    fprintf(fid, '**Gate-1 speed-scheduled ID: %s**', S.verdict);
    if ~strcmp(S.verdict, 'PASS')
        fprintf(fid, ' — blocker: %s', S.blocker_str);
    end
    fprintf(fid, '.\n\n');
    fprintf(fid, '- Isolated extension only; production frozen; no retune; no plant/controller edits.\n');
    fprintf(fid, '- U_cmd={1.0,1.5,2.0} level+climb; trim/jac/val = %d/%d/%d of 6/6/%d.\n', ...
        S.n_trim_pass, S.n_jac_pass, S.n_val_pass, S.n_val_cases);
    fprintf(fid, '- Artifacts: `suite_results/DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}`.\n');
    fprintf(fid, '- Next: **`%s`**. CODEX_VERTICAL_PLAN untouched.\n', S.next_task);
    fclose(fid);

    % PITCH_CONTROL_RESEARCH_LOG
    logp = fullfile(out_dir, 'PITCH_CONTROL_RESEARCH_LOG.md');
    fid = fopen(logp, 'a');
    assert(fid > 0);
    fprintf(fid, '\n\n## %s — %s\n\n', S.task_id, S.stamp);
    fprintf(fid, '- Gate-1 speed-scheduled coupled plant ID: **%s**', S.verdict);
    if ~strcmp(S.verdict, 'PASS')
        fprintf(fid, ' — blocker: %s', S.blocker_str);
    end
    fprintf(fid, '.\n');
    fprintf(fid, '- U_cmd={1.0,1.5,2.0}×{level,climb}; BODY surge fixed exact-by-construction; U_total=hypot(u,w) reported separately.\n');
    fprintf(fid, '- Scores: trim %d/6, jac %d/6, val %d/%d (tol nrmse≤%.2f corr≥%.2f).\n', ...
        S.n_trim_pass, S.n_jac_pass, S.n_val_pass, S.n_val_cases, ...
        S.tol.nrmse_rel_max, S.tol.corr_min);
    fprintf(fid, '- LPV: level env `%s`; climb env `%s`; hydro CI NOT_CLAIMED.\n', ...
        S.lpv.level.envelope, S.lpv.climb.envelope);
    fprintf(fid, '- Artifacts: suite_results/DEPTH_GAMMA_SPEED_SCHEDULED_ID.{md,mat,png}; driver `run_depth_gamma_speed_scheduled_id_extension.m`.\n');
    fprintf(fid, '- Next: **`%s`**. CODEX_VERTICAL_PLAN untouched.\n', S.next_task);
    fclose(fid);
end

function print_feedback(S)
    fprintf('FEEDBACK: %s  trim=%d/6 jac=%d/6 val=%d/%d  next=%s\n', ...
        S.verdict, S.n_trim_pass, S.n_jac_pass, S.n_val_pass, S.n_val_cases, S.next_task);
    for i = 1:numel(S.points)
        P = S.points{i};
        fprintf('  %s: trim=%s jac=%s val=%d/%d u*=%.4f Utot=%.4f maxRe=%.4g\n', ...
            P.name, tern(P.trim_pass,'PASS','FAIL'), tern(P.jac_pass,'PASS','FAIL'), ...
            P.val.n_pass, P.val.n_cases, P.u_body, P.U_total, max(real(P.eig_red)));
    end
end
