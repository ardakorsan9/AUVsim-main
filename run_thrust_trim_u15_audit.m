function run_thrust_trim_u15_audit()
% THRUST_TRIM_U15_AUDIT_001 — plant-only thrust feedforward at exact BODY u=1.5
% Read-only evidence: SPEED_BASELINE_AUDIT.mat, TRIM_OPERATING_POINTS.mat,
% underwater777_vehicle_dynamics.m. One MATLAB invocation; no production edit.
% Solves level + XZ gamma=atan(0.4) translating trims with u fixed 1.5.
% R10 helix: EMPIRICAL cycle-mean only; exact-u LTI not fabricated → UNKNOWN.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'THRUST_TRIM_U15_AUDIT';
    task_id = 'THRUST_TRIM_U15_AUDIT_001';

    speed_path = fullfile(out_dir, 'SPEED_BASELINE_AUDIT.mat');
    trim_path  = fullfile(out_dir, 'TRIM_OPERATING_POINTS.mat');
    plant_path = fullfile(project_dir, 'underwater777_vehicle_dynamics.m');
    assert(exist(speed_path, 'file') == 2, 'Missing %s', speed_path);
    assert(exist(trim_path, 'file') == 2, 'Missing %s', trim_path);
    assert(exist(plant_path, 'file') == 2, 'Missing %s', plant_path);

    Sp = load(speed_path);
    Tr = load(trim_path);
    assert(isfield(Sp, 'law') && isfield(Sp, 'SH') && isfield(Sp, 'H'), ...
        'SPEED_BASELINE_AUDIT.mat missing law/SH/H');
    assert(isfield(Tr, 'OP') && isfield(Tr.OP, 'level') && isfield(Tr.OP, 'climb'), ...
        'TRIM_OPERATING_POINTS.mat missing OP.level/climb');

    % Plant globals required by RHS (not an evidence source; coeffs only)
    clear functions
    init_parameters();
    global Kp_x thrust_trim

    Ufix = 1.5;
    Kpx = Sp.law.Kp_x;
    Ttrim_cur = Sp.law.thrust_trim;
    e_tol = 0.03;                       % m/s target band
    dT_tol = e_tol * Kpx;               % |Treq-Ttrim| max for |e_ss|<=e_tol
    gamma = atan(0.4);                  % climb flight-path angle
    slope = tan(gamma);                 % = 0.4
    pass_tol = 0.01;
    x_scale = [10; 10; 10; 1; 1; 1; 1.5; 0.3; 0.3; 0.2; 0.2; 0.2];
    nu_dot_scale = [1.0; 0.3; 0.3; 0.2; 0.2; 0.2];

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Evidence: SPEED_BASELINE_AUDIT.mat | TRIM_OPERATING_POINTS.mat | underwater777_vehicle_dynamics.m\n');
    fprintf('Target: exact BODY u=%.3f | current Ttrim=%.4f N | Kp_x=%.4g | e_tol=%.3f m/s\n', ...
        Ufix, Ttrim_cur, Kpx, e_tol);
    fprintf('PRIOR LABEL FLAG: TRIM level/climb "U=1.5" actually u*=%.4f / %.4f — do NOT relabel history.\n', ...
        Tr.OP.level.x_star(7), Tr.OP.climb.x_star(7));

    %% ---- Plant-only exact-u translating trims (level + XZ) ----
    % Seed from prior OP (different u) — solver forces u=Ufix
    level = solve_translating(Ufix, 0.0, Tr.OP.level, nu_dot_scale, x_scale, pass_tol, 'level_exact_u15');
    climb = solve_translating(Ufix, slope, Tr.OP.climb, nu_dot_scale, x_scale, pass_tol, 'XZ_exact_u15_gamma_atan0p4');

    fprintf('\nLEVEL u=%.6f  Treq=%.6f N  de=%.4f deg  theta=%.4f deg  w=%.5f  norm_dyn=%.3g  %s\n', ...
        level.x_star(7), level.Treq, rad2deg(level.u_star(2)), rad2deg(level.x_star(5)), ...
        level.x_star(9), level.norm_dyn, yn(level.pass));
    fprintf('CLIMB u=%.6f  Treq=%.6f N  de=%.4f deg  theta=%.4f deg  w=%.5f  norm_dyn=%.3g  %s  slope=%.4f (gamma=%.4f deg)\n', ...
        climb.x_star(7), climb.Treq, rad2deg(climb.u_star(2)), rad2deg(climb.x_star(5)), ...
        climb.x_star(9), climb.norm_dyn, yn(climb.pass), slope, rad2deg(gamma));

    %% ---- R10 helix: EMPIRICAL only; exact-u UNKNOWN ----
    helix = empirical_helix(Sp, Tr, Ufix, Kpx, Ttrim_cur);
    fprintf('HELIX EMPIRICAL cycle-mean T=%.4f N at u_mean=%.4f (not exact u=1.5); Treq_exact_u=%s\n', ...
        helix.T_cycle_mean, helix.u_mean, helix.Treq_exact_u_label);

    %% ---- Common Ttrim feasibility via e_ss = (Treq - Ttrim)/Kpx ----
    feas = common_trim_feasibility(level, climb, helix, Ttrim_cur, Kpx, e_tol, dT_tol);

    %% ---- Audit gate ----
    solvers_ok = level.pass && climb.pass;
    helix_ok = strcmp(helix.provenance, 'EMPIRICAL') && strcmp(helix.Treq_exact_u_label, 'UNKNOWN');
    decision_ok = ~isempty(feas.decision) && ~isempty(feas.architecture_or_range);
    audit_pass = solvers_ok && helix_ok && decision_ok;

    task = struct();
    task.task_id = task_id;
    task.date = datestr(now, 31);
    task.Ufix = Ufix;
    task.Kpx = Kpx;
    task.Ttrim_current = Ttrim_cur;
    task.e_tol = e_tol;
    task.dT_tol = dT_tol;
    task.gamma = gamma;
    task.slope = slope;
    task.pass_tol = pass_tol;
    task.verdict = tern(audit_pass, 'PASS', 'FAIL');
    task.sources = {speed_path, trim_path, plant_path};
    task.production_edited = false;
    task.prior_label_correction = sprintf([ ...
        'TRIM_OPERATING_POINTS / LOCAL_SS "U=1.5" / "level_U15" / "climb" points have ' ...
        'BODY u*=%.6g / %.6g (not exact 1.5). Do not relabel those artifacts; ' ...
        'this audit introduces separate exact-u=1.5 plant trims.'], ...
        Tr.OP.level.x_star(7), Tr.OP.climb.x_star(7));

    Result = struct('level', level, 'climb', climb, 'helix', helix, ...
        'feasibility', feas, 'task', task, 'x_scale', x_scale, ...
        'nu_dot_scale', nu_dot_scale, 'Sp_summary', summarize_speed(Sp), ...
        'prior_OP_u', [Tr.OP.level.x_star(7); Tr.OP.climb.x_star(7); Tr.OP.helix.x_star(7)], ...
        'prior_OP_T', [Tr.OP.level.u_star(3); Tr.OP.climb.u_star(3); Tr.OP.helix.u_star(3)]);

    write_png(out_dir, tag, Result);
    write_md(out_dir, tag, Result);
    append_audit(out_dir, Result);

    save(fullfile(out_dir, [tag '.mat']), 'Result', 'task', 'level', 'climb', ...
        'helix', 'feas', '-v7.3');

    fprintf('\nVERDICT: %s | common_trim=%s | next=%s\n', task.verdict, ...
        feas.common_feasible_label, feas.next);
    fprintf('Wrote suite_results/%s.{md,mat,png} + append STATE_SPACE_MODEL_AUDIT.md\n', tag);
end

%% ===================== plant translating trim @ exact u =====================
function P = solve_translating(Ufix, slope, OP_seed, nu_dot_scale, x_scale, pass_tol, name)
    % Free z = [theta; v; w; q; delta_e; thrust]; fixed u=Ufix, phi=p=r=0, dr=0
    z0 = [OP_seed.x_star(5); OP_seed.x_star(8); OP_seed.x_star(9); ...
          OP_seed.x_star(11); OP_seed.u_star(2); OP_seed.u_star(3)];
    % Mild seed scale toward lower speed (drag ~ u^2)
    u_seed = max(OP_seed.x_star(7), 0.5);
    z0(6) = z0(6) * (Ufix / u_seed)^2;

    [z, exitflag, hist] = local_newton(@(zz) translating_cost(zz, Ufix, slope, nu_dot_scale), z0, 120);

    x = zeros(12, 1);
    x(5) = z(1); x(7) = Ufix; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    u = [0; z(5); z(6)];
    ctr = ustruct(u);
    f = underwater777_vehicle_dynamics(0, x, ctr);
    R = residual_pack(f, x_scale, nu_dot_scale, slope);

    P = struct();
    P.name = name;
    P.class = 'steady_translating_trim';
    P.provenance = 'PLANT_SOLVE';
    P.Ufix = Ufix;
    P.slope = slope;
    P.x_star = x;
    P.u_star = u;
    P.Treq = u(3);
    P.delta_e = u(2);
    P.theta = x(5);
    P.w = x(9);
    P.v = x(8);
    P.q = x(11);
    P.f = f;
    P.residual = R;
    P.norm_dyn = R.norm_dyn;
    P.att_rate = f(4:6);
    P.eta_dot = f(1:6);
    P.nu_dot = f(7:12);
    P.pass = (R.norm_dyn <= pass_tol) && (abs(x(7) - Ufix) < 1e-12);
    P.exitflag = exitflag;
    P.solver_hist = hist;
    P.z0 = z0;
    P.z = z;
    P.seed_u = OP_seed.x_star(7);
    P.seed_T = OP_seed.u_star(3);
    P.frames = frames_struct();
    % Constraints satisfied?
    xd = f(1); zd = f(3);
    if abs(slope) < 1e-12
        P.slope_err = zd;
        P.constraint = 'level: nu_dot~0, phi_dot~0, theta_dot~0, zdot~0, u=Ufix fixed, dr=0';
    else
        P.slope_err = zd - slope * xd;
        P.constraint = sprintf(['climb: nu_dot~0, att_rates~0, zdot=%.4g*xdot ', ...
            '(gamma=atan(%.4g)), u=Ufix fixed, dr=0'], slope, slope);
    end
    P.constraints_ok = abs(P.slope_err) < 1e-4 && max(abs(f(4:5))) < 1e-4;
end

function c = translating_cost(z, Ufix, slope, nu_dot_scale)
    x = zeros(12, 1);
    x(5) = z(1); x(7) = Ufix; x(8) = z(2); x(9) = z(3); x(11) = z(4);
    ctr = ustruct([0; z(5); z(6)]);
    f = underwater777_vehicle_dynamics(0, x, ctr);
    nd = f(7:12) ./ nu_dot_scale;
    ad = f(4:5) / 0.05;
    xd = f(1); zd = f(3);
    if abs(slope) < 1e-12
        slope_err = zd;
    else
        slope_err = zd - slope * xd;
    end
    c = [nd; ad; slope_err / max(0.1, abs(Ufix))];
end

%% ===================== helix EMPIRICAL =====================
function H = empirical_helix(Sp, Tr, Ufix, Kpx, Ttrim_cur)
    mask = Sp.H.mask_hold(:);
    if ~any(mask)
        mask = Sp.H.mask_ss(:);
    end
    if ~any(mask)
        mask = true(size(Sp.SH.t));
    end
    n = numel(Sp.SH.t);
    if numel(mask) ~= n
        mask = Sp.SH.t >= 5 & Sp.SH.t <= 0.88 * Sp.SH.t(end);
    end

    u_w = Sp.SH.u_body(mask);
    thr_w = Sp.SH.thrust(mask);
    uref_w = Sp.SH.u_ref(mask);
    de_w = Sp.SH.delta_e(mask);
    dr_w = Sp.SH.delta_r(mask);

    H = struct();
    H.name = 'helix_R10';
    H.class = 'periodic_or_quasi_steady (NOT ordinary LTI trim)';
    H.provenance = 'EMPIRICAL';
    H.Treq_exact_u_label = 'UNKNOWN';
    H.Treq_exact_u = NaN;
    H.reason_unknown = [ ...
        'Observed cycle-mean thrust balances BODY u at u_mean≠Ufix under P-only law; ', ...
        'helix failed rotating-frame relative-eq (TRIM_OPERATING_POINTS); ', ...
        'quadratic-drag rescale from off-trim u is not a valid exact-u equilibrium. ', ...
        'No fabricated LTI helix trim.'];
    H.u_mean = mean(u_w);
    H.u_std = std(u_w);
    H.uref_mean = mean(uref_w);
    H.T_cycle_mean = mean(thr_w);
    H.T_cycle_std = std(thr_w);
    H.T_cycle_rms = rms(thr_w);
    H.delta_e_mean = mean(de_w);
    H.delta_r_mean = mean(dr_w);
    H.n_window = nnz(mask);
    H.t_window = [Sp.SH.t(find(mask,1,'first')), Sp.SH.t(find(mask,1,'last'))];
    H.source = 'SPEED_BASELINE_AUDIT.mat SH + H.mask_hold';
    H.prior_trim_u = Tr.OP.helix.x_star(7);
    H.prior_trim_T = Tr.OP.helix.u_star(3);
    H.prior_class = Tr.OP.helix.class;
    H.prior_lti = Tr.OP.helix.lti_eligible;
    % Consistency check: reconstructed P-law mean
    H.T_reconstruct = Ttrim_cur + Kpx * mean(uref_w - u_w);
    H.u_gap_from_Ufix = H.u_mean - Ufix;
    H.frames = frames_struct();
    H.pass = false;  % not an exact-u plant trim
    H.note = sprintf(['EMPIRICAL cycle-mean thrust=%.4f N at BODY u_mean=%.4f ', ...
        '(gap from Ufix: %+.4f m/s). Exact-u Treq = UNKNOWN.'], ...
        H.T_cycle_mean, H.u_mean, H.u_gap_from_Ufix);
end

%% ===================== common trim feasibility =====================
function F = common_trim_feasibility(level, climb, helix, Ttrim_cur, Kpx, e_tol, dT_tol)
    F = struct();
    F.Kpx = Kpx;
    F.e_tol = e_tol;
    F.dT_tol = dT_tol;
    F.Ttrim_current = Ttrim_cur;
    F.formula = 'e_ss = (Treq - Ttrim) / Kp_x';

    % Known plant Treq (level + climb only)
    T_known = [level.Treq; climb.Treq];
    names_known = {'level'; 'XZ'};
    F.Treq_level = level.Treq;
    F.Treq_XZ = climb.Treq;
    F.Treq_R10 = helix.Treq_exact_u;  % NaN / UNKNOWN
    F.Treq_R10_label = helix.Treq_exact_u_label;
    F.T_emp_R10 = helix.T_cycle_mean;

    F.e_ss_level_at_current = (level.Treq - Ttrim_cur) / Kpx;
    F.e_ss_XZ_at_current = (climb.Treq - Ttrim_cur) / Kpx;
    F.e_ss_R10_at_current = NaN;  % UNKNOWN exact Treq

    % At current Ttrim, predicted P-only steady offsets (plant)
    F.pred_table = {
        'X/level', level.Treq, F.e_ss_level_at_current, abs(F.e_ss_level_at_current) <= e_tol;
        'XZ',      climb.Treq, F.e_ss_XZ_at_current,    abs(F.e_ss_XZ_at_current) <= e_tol;
        'R10',     NaN,        NaN,                     false};

    Tspan = max(T_known) - min(T_known);
    F.Treq_span_level_XZ = Tspan;
    F.Treq_mid = 0.5 * (min(T_known) + max(T_known));
    % Common Ttrim exists for known routes iff every Treq within dT_tol of some T*
    % Equivalent: span <= 2*dT_tol, then any T* in [max-dT, min+dT] works
    F.common_band_lo = max(T_known) - dT_tol;
    F.common_band_hi = min(T_known) + dT_tol;
    known_common_ok = (F.common_band_lo <= F.common_band_hi);

    % Helix UNKNOWN → cannot certify all three routes
    all_routes_certifiable = known_common_ok && ~isnan(helix.Treq_exact_u);
    F.known_routes_common_ok = known_common_ok;
    F.all_routes_certifiable = all_routes_certifiable;

    if known_common_ok
        F.derived_Ttrim_range = [F.common_band_lo, F.common_band_hi];
        F.derived_Ttrim_value = mean(F.derived_Ttrim_range);
    else
        F.derived_Ttrim_range = [NaN NaN];
        F.derived_Ttrim_value = NaN;
    end

    % Evaluate e_ss at mid / derived for known routes
    if known_common_ok
        Tt = F.derived_Ttrim_value;
        F.e_ss_at_derived = struct( ...
            'level', (level.Treq - Tt) / Kpx, ...
            'XZ', (climb.Treq - Tt) / Kpx, ...
            'R10', NaN);
    else
        F.e_ss_at_derived = struct('level', NaN, 'XZ', NaN, 'R10', NaN);
    end

    % Decision (exactly one architecture if common trim not feasible for all routes)
    if all_routes_certifiable
        F.common_feasible = true;
        F.common_feasible_label = 'YES';
        F.decision = sprintf(['Common constant Ttrim feasible for all routes in [%.4f, %.4f] N ', ...
            '(derived center %.4f N).'], F.derived_Ttrim_range(1), F.derived_Ttrim_range(2), ...
            F.derived_Ttrim_value);
        F.architecture_or_range = sprintf('Ttrim_range=[%.4f, %.4f] N', ...
            F.derived_Ttrim_range(1), F.derived_Ttrim_range(2));
        F.next = 'set_thrust_trim_from_exact_u15_band';
    elseif known_common_ok
        % Level+XZ share a band, but R10 exact-u UNKNOWN → cannot certify all routes
        F.common_feasible = false;
        F.common_feasible_label = 'NO (R10 exact-u UNKNOWN; level+XZ band exists but insufficient)';
        F.decision = sprintf([ ...
            'Level+XZ admit Ttrim band [%.4f, %.4f] N (center %.4f), but R10 exact-u Treq is UNKNOWN ', ...
            '(EMPIRICAL only at u_mean=%.3f). A single constant Ttrim cannot be certified for all routes.'], ...
            F.derived_Ttrim_range(1), F.derived_Ttrim_range(2), F.derived_Ttrim_value, helix.u_mean);
        F.architecture_or_range = 'speed-reference drag feedforward + anti-windup PI';
        F.architecture_justify = sprintf([ ...
            'Route Treq at exact u=1.5 already differs (level=%.3f N vs XZ=%.3f N, span=%.3f N); ', ...
            'helix is periodic/EMPIRICAL with unknown exact-u thrust. Minimal fix: drag FF from u_ref ', ...
            '(corrects bulk surge bias vs wrong 13.4 N) plus anti-windup PI to wipe residual ', ...
            'route/period-mean offset without Kp retune. Prefer over route schedule alone because ', ...
            'Uref steps and continuous paths need continuous FF, and I-action covers helix cycle-mean.'], ...
            level.Treq, climb.Treq, Tspan);
        F.next = 'implement_speed_drag_ff_plus_aw_PI';
    else
        F.common_feasible = false;
        F.common_feasible_label = 'NO';
        F.decision = sprintf([ ...
            'Level/XZ Treq span=%.4f N exceeds 2*dT_tol=%.4f N (dT_tol=e_tol*Kpx=%.4f). ', ...
            'No constant Ttrim meets |e_ss|<=%.3f on both known routes; R10 exact-u also UNKNOWN.'], ...
            Tspan, 2*dT_tol, dT_tol, e_tol);
        F.architecture_or_range = 'speed-reference drag feedforward + anti-windup PI';
        F.architecture_justify = sprintf([ ...
            'Plant-required thrust at exact BODY u=1.5 differs by route (level=%.3f vs XZ=%.3f N). ', ...
            'Constant Ttrim cannot null both within ±%.3f m/s under P-only Kpx=%.4g. ', ...
            'Recommend speed-reference drag feedforward (T_ff(u_ref)) plus anti-windup PI to absorb ', ...
            'path-dependent residual (climb restoring / helix cycle-mean) — not a static route schedule ', ...
            'alone, which fails under Uref steps and continuous envelopes.'], ...
            level.Treq, climb.Treq, e_tol, Kpx);
        F.next = 'implement_speed_drag_ff_plus_aw_PI';
    end

    % Current trim vs plant
    F.current_vs_plant = struct( ...
        'Ttrim', Ttrim_cur, ...
        'level_Treq', level.Treq, ...
        'XZ_Treq', climb.Treq, ...
        'level_dT', level.Treq - Ttrim_cur, ...
        'XZ_dT', climb.Treq - Ttrim_cur, ...
        'note', sprintf('Current Ttrim=%.2f N is %.2f / %.2f N ABOVE plant level/XZ Treq at u=1.5', ...
            Ttrim_cur, Ttrim_cur - level.Treq, Ttrim_cur - climb.Treq));
end

%% ===================== helpers =====================
function [z, exitflag, hist] = local_newton(fun, z0, maxit)
    z = z0(:);
    exitflag = 0;
    hist = struct('nrm', zeros(maxit,1), 'alpha', zeros(maxit,1));
    for it = 1:maxit
        c = fun(z); c = c(:);
        nrm = norm(c);
        hist.nrm(it) = nrm;
        if nrm < 1e-10
            exitflag = 1;
            hist.nrm = hist.nrm(1:it);
            hist.alpha = hist.alpha(1:it);
            return;
        end
        m = numel(c); n = numel(z);
        J = zeros(m, n);
        for j = 1:n
            h = 1e-6 * max(1, abs(z(j)));
            zp = z; zp(j) = zp(j) + h;
            J(:, j) = (fun(zp) - c) / h;
        end
        step = -J \ c;
        if any(~isfinite(step))
            step = -pinv(J) * c;
        end
        alpha = 1.0;
        accepted = false;
        for ls = 1:10
            ztry = z + alpha * step;
            ctry = fun(ztry);
            if norm(ctry) < nrm
                z = ztry;
                accepted = true;
                hist.alpha(it) = alpha;
                break;
            end
            alpha = 0.5 * alpha;
        end
        if ~accepted
            exitflag = -2;
            hist.nrm = hist.nrm(1:it);
            hist.alpha = hist.alpha(1:it);
            return;
        end
        if norm(alpha * step) < 1e-12
            exitflag = 2;
            hist.nrm = hist.nrm(1:it);
            hist.alpha = hist.alpha(1:it);
            return;
        end
    end
    exitflag = -1;
end

function R = residual_pack(f, x_scale, nu_dot_scale, slope)
    R = struct();
    R.f = f;
    R.eta_dot = f(1:6);
    R.nu_dot = f(7:12);
    R.nu_dot_norm_comp = abs(R.nu_dot) ./ nu_dot_scale;
    R.norm_dyn = max(R.nu_dot_norm_comp);
    R.att_rate = f(4:6);
    xd = f(1); zd = f(3);
    if abs(slope) < 1e-12
        R.slope_err = zd;
    else
        R.slope_err = zd - slope * xd;
    end
    R.eta_dot_norm_comp = abs(R.eta_dot) ./ x_scale(1:6);
end

function ctr = ustruct(u)
    u = u(:);
    ctr = struct('delta_r', u(1), 'delta_e', u(2), 'thrust', u(3));
end

function F = frames_struct()
    F = struct( ...
        'state', '[x y z phi theta psi u v w p q r] NED + BODY', ...
        'eta', 'NED position [m], Euler ZYX [rad]', ...
        'nu', 'BODY linear [m/s], BODY rates [rad/s]', ...
        'u_controller', 'BODY surge u [m/s] (exact target here)', ...
        'theta_phys', 'theta_phys = -theta', ...
        'inputs', 'u*=[delta_r; delta_e; thrust] rad/rad/N', ...
        'thrust', 'Xprop [N] in BODY X', ...
        'signs', 'elevator_sign=+1; +delta_e via Zuuds/Muuds as in plant RHS');
end

function S = summarize_speed(Sp)
    S = struct();
    S.verdict = Sp.verdict;
    S.root_class = Sp.root_class;
    S.X_mae = Sp.X.speed.steady.mae;
    S.XZ_mae = Sp.XZ.speed.steady.mae;
    S.H_mae = Sp.H.speed.steady.mae;
    S.X_thr = Sp.X.thrust.steady.mean;
    S.XZ_thr = Sp.XZ.thrust.steady.mean;
    S.H_thr = Sp.H.thrust.steady.mean;
    S.Ttrim = Sp.law.thrust_trim;
    S.Kpx = Sp.law.Kp_x;
end

function s = yn(tf)
    if tf; s = 'PASS'; else; s = 'FAIL'; end
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end

%% ===================== PNG =====================
function write_png(out_dir, tag, R)
    fig = figure('Visible', 'off', 'Position', [40 40 1400 860]);

    subplot(2, 3, 1);
    names = {'Level', 'XZ', 'R10 emp'};
    Tvals = [R.level.Treq, R.climb.Treq, R.helix.T_cycle_mean];
    bar(Tvals, 0.6); hold on;
    yline(R.task.Ttrim_current, 'r--', 'LineWidth', 1.5);
    if R.feasibility.known_routes_common_ok
        yline(R.feasibility.derived_Ttrim_value, 'g-.', 'LineWidth', 1.2);
    end
    set(gca, 'XTick', 1:3, 'XTickLabel', names);
    ylabel('Thrust [N]'); grid on;
    title(sprintf('Treq @ u=1.5 (R10=EMPIRICAL@u=%.2f)', R.helix.u_mean));
    if R.feasibility.known_routes_common_ok
        legend({'Treq/emp', 'Ttrim=13.4', 'derived mid'}, 'Location', 'best');
    else
        legend({'Treq/emp', 'Ttrim=13.4'}, 'Location', 'best');
    end

    subplot(2, 3, 2);
    ess = [R.feasibility.e_ss_level_at_current, R.feasibility.e_ss_XZ_at_current];
    bar(ess, 0.6); hold on;
    yline(R.task.e_tol, 'k--'); yline(-R.task.e_tol, 'k--');
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Level', 'XZ'});
    ylabel('e_{ss}=(Treq-Ttrim)/Kp_x [m/s]'); grid on;
    title('P-only offset at current Ttrim=13.4 N');

    subplot(2, 3, 3);
    labs = {'u','w','\theta_{deg}','\delta e_{deg}','T'};
    Lrow = [R.level.x_star(7), R.level.x_star(9), rad2deg(R.level.x_star(5)), ...
        rad2deg(R.level.u_star(2)), R.level.Treq];
    Crow = [R.climb.x_star(7), R.climb.x_star(9), rad2deg(R.climb.x_star(5)), ...
        rad2deg(R.climb.u_star(2)), R.climb.Treq];
    % normalize for display
    scale = [1.5, 0.3, 30, 15, 15];
    bar([Lrow./scale; Crow./scale]');
    set(gca, 'XTick', 1:5, 'XTickLabel', labs);
    legend({'Level', 'XZ'}); grid on;
    title('Exact-u trim states (scaled)'); ylabel('value / scale');

    subplot(2, 3, 4);
    bar(1:12, R.level.f); grid on;
    ylabel('f(x*,u*)'); title(sprintf('Level resid norm_{dyn}=%.2g', R.level.norm_dyn));
    set(gca, 'XTick', 1:12, 'XTickLabel', ...
        {'ẋ','ẏ','ż','φ̇','θ̇','ψ̇','u̇','v̇','ẇ','ṗ','q̇','ṙ'}, 'XTickLabelRotation', 45);

    subplot(2, 3, 5);
    bar(1:12, R.climb.f); grid on;
    ylabel('f(x*,u*)'); title(sprintf('XZ resid norm_{dyn}=%.2g', R.climb.norm_dyn));
    set(gca, 'XTick', 1:12, 'XTickLabel', ...
        {'ẋ','ẏ','ż','φ̇','θ̇','ψ̇','u̇','v̇','ẇ','ṗ','q̇','ṙ'}, 'XTickLabelRotation', 45);

    subplot(2, 3, 6);
    axis off;
    txt = {sprintf('VERDICT: %s', R.task.verdict), ...
        sprintf('Level Treq=%.4f N  (%s)', R.level.Treq, yn(R.level.pass)), ...
        sprintf('XZ    Treq=%.4f N  (%s)', R.climb.Treq, yn(R.climb.pass)), ...
        sprintf('R10   EMPIRICAL T=%.4f N @ u=%.3f', R.helix.T_cycle_mean, R.helix.u_mean), ...
        sprintf('R10   exact-u Treq: %s', R.helix.Treq_exact_u_label), ...
        sprintf('Treq span L/XZ=%.4f N (2 dT_{tol}=%.4f)', ...
            R.feasibility.Treq_span_level_XZ, 2*R.task.dT_tol), ...
        sprintf('Common Ttrim: %s', R.feasibility.common_feasible_label), ...
        sprintf('Arch/range: %s', R.feasibility.architecture_or_range), ...
        sprintf('Next: %s', R.feasibility.next), ...
        'Prior U=1.5 labels: u~1.82/1.75 — not overwritten'};
    text(0.02, 0.95, txt, 'FontName', 'FixedWidth', 'FontSize', 10, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');

    sgtitle(sprintf('%s | exact BODY u=1.5 plant thrust audit', tag), 'Interpreter', 'none');
    exportgraphics(fig, fullfile(out_dir, [tag '.png']), 'Resolution', 140);
    close(fig);
end

%% ===================== Markdown =====================
function write_md(out_dir, tag, R)
    fid = fopen(fullfile(out_dir, [tag '.md']), 'w');
    fprintf(fid, '# THRUST_TRIM_U15_AUDIT\n\n');
    fprintf(fid, '**TASK_ID:** %s\n', R.task.task_id);
    fprintf(fid, '**Date:** %s\n', R.task.date);
    fprintf(fid, '**Overall verdict:** **%s**\n\n', R.task.verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `SPEED_BASELINE_AUDIT.mat`, `TRIM_OPERATING_POINTS.mat`, `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Driver: `run_thrust_trim_u15_audit.m` (one invocation; no production edit)\n');
    fprintf(fid, '- Artifacts: `suite_results/THRUST_TRIM_U15_AUDIT.{md,mat,png}`\n');
    fprintf(fid, '- Current law (from SPEED baseline): Ttrim=%.4f N, Kp_x=%.4g, e_tol=±%.3f m/s\n', ...
        R.task.Ttrim_current, R.task.Kpx, R.task.e_tol);
    fprintf(fid, '- Formula: `e_ss = (Treq - Ttrim) / Kp_x`\n\n');

    fprintf(fid, '## Prior label correction (history NOT overwritten)\n\n');
    fprintf(fid, '%s\n\n', R.task.prior_label_correction);
    fprintf(fid, '| Prior artifact | Labeled | Actual BODY u* | Actual T* |\n');
    fprintf(fid, '|----------------|---------|---------------:|----------:|\n');
    fprintf(fid, '| TRIM level_U15 | U=1.5 | %.6g | %.6g N |\n', R.prior_OP_u(1), R.prior_OP_T(1));
    fprintf(fid, '| TRIM XZ_slope | U≈1.5 climb | %.6g | %.6g N |\n', R.prior_OP_u(2), R.prior_OP_T(2));
    fprintf(fid, '| TRIM helix_R10 | (periodic) | %.6g | %.6g N |\n\n', R.prior_OP_u(3), R.prior_OP_T(3));

    fprintf(fid, '## Frames / units / signs\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'State: NED η + BODY ν; u controller variable = BODY surge [m/s]\n');
    fprintf(fid, 'Inputs: delta_r, delta_e [rad], thrust=Xprop [N]\n');
    fprintf(fid, 'theta_phys = -theta; elevator_sign=+1\n');
    fprintf(fid, 'Climb: gamma=atan(0.4)=%.6f rad (%.4f deg); slope dz/dx=%.4f\n', ...
        R.task.gamma, rad2deg(R.task.gamma), R.task.slope);
    fprintf(fid, '```\n\n');

    write_trim_md(fid, R.level, R.task.pass_tol);
    write_trim_md(fid, R.climb, R.task.pass_tol);

    fprintf(fid, '## R10 helix — EMPIRICAL (exact-u UNKNOWN)\n\n');
    fprintf(fid, '- **Class:** %s\n', R.helix.class);
    fprintf(fid, '- **Provenance:** %s\n', R.helix.provenance);
    fprintf(fid, '- **Exact-u Treq:** **%s**\n', R.helix.Treq_exact_u_label);
    fprintf(fid, '- **Reason:** %s\n', R.helix.reason_unknown);
    fprintf(fid, '- **Source window:** %s (n=%d, t=[%.2f,%.2f])\n', ...
        R.helix.source, R.helix.n_window, R.helix.t_window(1), R.helix.t_window(2));
    fprintf(fid, '\n```\n');
    fprintf(fid, 'u_mean=%.6g  u_std=%.4g  uref_mean=%.6g  gap_from_Ufix=%+.4g m/s\n', ...
        R.helix.u_mean, R.helix.u_std, R.helix.uref_mean, R.helix.u_gap_from_Ufix);
    fprintf(fid, 'T_cycle_mean=%.6g N  T_std=%.4g  T_rms=%.6g\n', ...
        R.helix.T_cycle_mean, R.helix.T_cycle_std, R.helix.T_cycle_rms);
    fprintf(fid, 'delta_e_mean=%.6g rad  delta_r_mean=%.6g rad\n', ...
        R.helix.delta_e_mean, R.helix.delta_r_mean);
    fprintf(fid, 'T_reconstruct(P-law)=%.6g N (consistency)\n', R.helix.T_reconstruct);
    fprintf(fid, 'prior helix u*/T*=%.6g / %.6g (periodic; LTI=%s)\n', ...
        R.helix.prior_trim_u, R.helix.prior_trim_T, tern(R.helix.prior_lti,'YES','NO'));
    fprintf(fid, '```\n\n');

    F = R.feasibility;
    fprintf(fid, '## Required thrust comparison\n\n');
    fprintf(fid, '| Route | Treq [N] | Provenance | e_ss @ Ttrim=%.2f | |e_ss|≤%.2f? |\n', ...
        R.task.Ttrim_current, R.task.e_tol);
    fprintf(fid, '|-------|---------:|------------|------------------:|:-----------:|\n');
    fprintf(fid, '| Level (exact u=1.5) | %.6f | PLANT_SOLVE | %+.4f | %s |\n', ...
        F.Treq_level, F.e_ss_level_at_current, tern(abs(F.e_ss_level_at_current)<=R.task.e_tol,'YES','NO'));
    fprintf(fid, '| XZ γ=atan(0.4) | %.6f | PLANT_SOLVE | %+.4f | %s |\n', ...
        F.Treq_XZ, F.e_ss_XZ_at_current, tern(abs(F.e_ss_XZ_at_current)<=R.task.e_tol,'YES','NO'));
    fprintf(fid, '| R10 helix | %s | EMPIRICAL cycle-mean=%.4f N @ u≠1.5 | UNKNOWN | NO |\n\n', ...
        F.Treq_R10_label, F.T_emp_R10);

    fprintf(fid, 'Current Ttrim=%.2f N vs plant: level ΔT=%+.3f N, XZ ΔT=%+.3f N.\n\n', ...
        R.task.Ttrim_current, F.current_vs_plant.level_dT, F.current_vs_plant.XZ_dT);

    fprintf(fid, '## Common constant Ttrim feasibility\n\n');
    fprintf(fid, '- dT_tol = e_tol × Kp_x = %.4f × %.4g = **%.4f N**\n', ...
        R.task.e_tol, R.task.Kpx, R.task.dT_tol);
    fprintf(fid, '- Level/XZ Treq span = **%.4f N** (need ≤ %.4f N for a common band)\n', ...
        F.Treq_span_level_XZ, 2*R.task.dT_tol);
    fprintf(fid, '- Level+XZ common band: ');
    if F.known_routes_common_ok
        fprintf(fid, '[%.4f, %.4f] N (center %.4f N)\n', ...
            F.derived_Ttrim_range(1), F.derived_Ttrim_range(2), F.derived_Ttrim_value);
    else
        fprintf(fid, '**empty** (span too large)\n');
    end
    fprintf(fid, '- All-routes certifiable (incl. R10 exact-u): **%s**\n', ...
        tern(F.all_routes_certifiable, 'YES', 'NO'));
    fprintf(fid, '- **Common Ttrim feasible:** **%s**\n\n', F.common_feasible_label);

    fprintf(fid, '### Decision\n\n');
    fprintf(fid, '%s\n\n', F.decision);
    if isfield(F, 'architecture_justify') && ~isempty(F.architecture_justify)
        fprintf(fid, '**Recommended next architecture (exactly one):** `%s`\n\n', F.architecture_or_range);
        fprintf(fid, 'Justification: %s\n\n', F.architecture_justify);
    else
        fprintf(fid, '**Derived Ttrim:** %s\n\n', F.architecture_or_range);
    end
    fprintf(fid, 'No Kp change. No production implementation in this task.\n\n');

    fprintf(fid, '## Feedback\n\n');
    fprintf(fid, '- PASS/FAIL: **%s**\n', R.task.verdict);
    fprintf(fid, '- Level: u*=%.6g Treq=%.6g N de=%.4f deg θ=%.4f deg w=%.5g norm_dyn=%.3g (%s)\n', ...
        R.level.x_star(7), R.level.Treq, rad2deg(R.level.delta_e), rad2deg(R.level.theta), ...
        R.level.w, R.level.norm_dyn, yn(R.level.pass));
    fprintf(fid, '- XZ: u*=%.6g Treq=%.6g N de=%.4f deg θ=%.4f deg w=%.5g norm_dyn=%.3g (%s)\n', ...
        R.climb.x_star(7), R.climb.Treq, rad2deg(R.climb.delta_e), rad2deg(R.climb.theta), ...
        R.climb.w, R.climb.norm_dyn, yn(R.climb.pass));
    fprintf(fid, '- R10: EMPIRICAL T_cycle=%.4f N @ u_mean=%.4f; exact-u=%s\n', ...
        R.helix.T_cycle_mean, R.helix.u_mean, R.helix.Treq_exact_u_label);
    fprintf(fid, '- Common trim: %s\n', F.common_feasible_label);
    fprintf(fid, '- Files: `suite_results/THRUST_TRIM_U15_AUDIT.md` `.mat` `.png`; append `STATE_SPACE_MODEL_AUDIT.md`\n');
    fprintf(fid, '- Next: `%s`\n', F.next);
    fclose(fid);
end

function write_trim_md(fid, P, pass_tol)
    fprintf(fid, '## %s — **%s**\n\n', P.name, yn(P.pass));
    fprintf(fid, '- **Class:** %s\n', P.class);
    fprintf(fid, '- **Provenance:** %s (u fixed = %.3f)\n', P.provenance, P.Ufix);
    fprintf(fid, '- **Constraint:** %s\n', P.constraint);
    fprintf(fid, '- **Frames:** NED+BODY SI; thrust=Xprop [N]; θ_phys=-θ\n');
    fprintf(fid, '- **Seed (prior OP, different u):** u_seed=%.6g, T_seed=%.6g → exitflag=%d\n\n', ...
        P.seed_u, P.seed_T, P.exitflag);
    fprintf(fid, '### x*, u*\n\n```\n');
    fprintf(fid, 'x* = [%s]\n', sprintf('%.6g ', P.x_star));
    fprintf(fid, 'u* = [dr=%.6g, de=%.6g rad (%.4f deg), thrust=%.6g N]\n', ...
        P.u_star(1), P.u_star(2), rad2deg(P.u_star(2)), P.u_star(3));
    fprintf(fid, 'necessary: w=%.6g, theta=%.6g rad (%.4f deg), de=%.6g, thrust=%.6g\n', ...
        P.w, P.theta, rad2deg(P.theta), P.delta_e, P.Treq);
    fprintf(fid, '```\n\n### Residuals\n\n```\n');
    fprintf(fid, 'eta_dot = [%s]\n', sprintf('%.6g ', P.eta_dot));
    fprintf(fid, 'nu_dot  = [%s]\n', sprintf('%.6g ', P.nu_dot));
    fprintf(fid, 'nu_dot_norm_comp = [%s]\n', sprintf('%.4g ', P.residual.nu_dot_norm_comp));
    fprintf(fid, 'norm_dyn = %.6g  (PASS if <= %.2g)\n', P.norm_dyn, pass_tol);
    fprintf(fid, 'slope_err = %.6g  att_rates(φ̇,θ̇,ψ̇)=[%s]\n', ...
        P.residual.slope_err, sprintf('%.3g ', P.att_rate));
    fprintf(fid, '```\n\n');
end

%% ===================== append STATE_SPACE_MODEL_AUDIT =====================
function append_audit(out_dir, R)
    path_audit = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    exists = exist(path_audit, 'file') == 2;
    fid = fopen(path_audit, tern(exists, 'a', 'w'));
    if ~exists
        fprintf(fid, '# STATE_SPACE_MODEL_AUDIT\n\n');
        fprintf(fid, 'Living audit of plant equations, trim operating points, and linearization provenance.\n\n');
    end

    fprintf(fid, '\n---\n\n## THRUST_TRIM_U15_AUDIT_001 — %s\n\n', R.task.date);
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `SPEED_BASELINE_AUDIT.mat`, `TRIM_OPERATING_POINTS.mat`, `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Driver: `run_thrust_trim_u15_audit.m` (one invocation; production untouched)\n');
    fprintf(fid, '- Artifacts: `suite_results/THRUST_TRIM_U15_AUDIT.{md,mat,png}`\n\n');

    fprintf(fid, '### Prior label flag (not overwritten)\n\n');
    fprintf(fid, '%s\n\n', R.task.prior_label_correction);

    fprintf(fid, '### Exact BODY u=1.5 plant trims\n\n');
    fprintf(fid, '| Point | PASS | u* | Treq [N] | de [deg] | θ [deg] | w | norm_dyn |\n');
    fprintf(fid, '|-------|:----:|---:|---------:|---------:|--------:|--:|---------:|\n');
    fprintf(fid, '| Level | %s | %.6g | %.6g | %.4f | %.4f | %.5g | %.3g |\n', ...
        yn(R.level.pass), R.level.x_star(7), R.level.Treq, rad2deg(R.level.delta_e), ...
        rad2deg(R.level.theta), R.level.w, R.level.norm_dyn);
    fprintf(fid, '| XZ γ=atan(0.4) | %s | %.6g | %.6g | %.4f | %.4f | %.5g | %.3g |\n', ...
        yn(R.climb.pass), R.climb.x_star(7), R.climb.Treq, rad2deg(R.climb.delta_e), ...
        rad2deg(R.climb.theta), R.climb.w, R.climb.norm_dyn);
    fprintf(fid, '| R10 | EMPIRICAL | u_mean=%.4f | T_cycle=%.4f (exact-u **UNKNOWN**) | — | — | — | n/a |\n\n', ...
        R.helix.u_mean, R.helix.T_cycle_mean);

    F = R.feasibility;
    fprintf(fid, '### Common Ttrim / decision\n\n');
    fprintf(fid, '```\ne_ss=(Treq-Ttrim)/Kp_x; Kp_x=%.4g; e_tol=±%.3f; dT_tol=%.4f N\n', ...
        R.task.Kpx, R.task.e_tol, R.task.dT_tol);
    fprintf(fid, 'Current Ttrim=%.2f N → e_ss level/XZ = %+.4f / %+.4f m/s\n', ...
        R.task.Ttrim_current, F.e_ss_level_at_current, F.e_ss_XZ_at_current);
    fprintf(fid, 'Treq span level/XZ=%.4f N; common_feasible=%s\n', ...
        F.Treq_span_level_XZ, F.common_feasible_label);
    fprintf(fid, 'Architecture/range: %s\n```\n\n', F.architecture_or_range);
    fprintf(fid, '%s\n\n', F.decision);

    fprintf(fid, '### Verdict / next\n\n');
    fprintf(fid, '- Audit verdict: **%s**\n', R.task.verdict);
    fprintf(fid, '- Next: `%s`\n', F.next);
    fprintf(fid, '- Production: untouched (no Kp / no law edit)\n');
    fclose(fid);
end
