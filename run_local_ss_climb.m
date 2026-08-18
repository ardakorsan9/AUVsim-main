function run_local_ss_climb()
% LOCAL_SS_CLIMB_TURN_001 — plant-only local state-space at XZ climb trim.
% Same verified scale-aware central FD as LOCAL_SS_LEVEL_001.
% Explicitly does NOT fabricate an ordinary helix inertial LTI model.
% No controller / guidance / plant edits.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'LOCAL_SS_CLIMB';
    task_id = 'LOCAL_SS_CLIMB_TURN_001';

    clear functions
    init_parameters();

    trim_mat = fullfile(out_dir, 'TRIM_OPERATING_POINTS.mat');
    level_mat = fullfile(out_dir, 'LOCAL_SS_LEVEL.mat');
    T = load(trim_mat);
    [x0, u0_vec, u0, trim_meta] = extract_climb_trim(T);

    if isfield(T, 'x_scale'); x_scale = T.x_scale(:); else
        x_scale = [10; 10; 10; 1; 1; 1; 1.5; 0.3; 0.3; 0.2; 0.2; 0.2];
    end
    if isfield(T, 'u_scale'); u_scale = T.u_scale(:); else
        u_scale = [deg2rad(25); deg2rad(15); 50];
    end
    eps_rel = 1e-4;

    state_names = {'x','y','z','phi','theta','psi','u','v','w','p','q','r'};
    input_names = {'delta_r','delta_e','thrust'};
    units_x = {'m','m','m','rad','rad','rad','m/s','m/s','m/s','rad/s','rad/s','rad/s'};
    units_u = {'rad','rad','N'};

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Trim source: %s\n', trim_mat);
    fprintf('Plant RHS: underwater777_vehicle_dynamics (exact)\n');
    fprintf('x0 = [%s]\n', num2str(x0.', ' %.6g'));
    fprintf('u0 = [dr=%.6g de=%.6g thrust=%.6g]\n', u0_vec(1), u0_vec(2), u0_vec(3));

    f0 = underwater777_vehicle_dynamics(0, x0, u0);
    fprintf('||f0||_2 = %.3e  (nu-dot part ||.||_2=%.3e)\n', norm(f0), norm(f0(7:12)));

    [A1, B1] = scale_aware_fd(x0, u0, x_scale, u_scale, eps_rel);
    [A2, B2] = scale_aware_fd(x0, u0, x_scale, u_scale, eps_rel / 2);

    dA_rel = norm(A2 - A1, 'fro') / max(norm(A1, 'fro'), eps);
    dB_rel = norm(B2 - B1, 'fro') / max(norm(B1, 'fro'), eps);

    A = A2; B = B2;
    C = eye(12);
    D = zeros(12, 3);

    ev1 = eig(A1); ev2 = eig(A2);
    [ev_dom_ok, ev_report] = eigenvalue_structure_stable(ev1, ev2, 8);

    jac_pass = (dA_rel <= 0.01) && (dB_rel <= 0.01) && ev_dom_ok;
    verdict = ternary(jac_pass, 'PASS', 'FAIL');

    fprintf('FD step convergence: dA_rel=%.4g  dB_rel=%.4g  (gate <=1%%)\n', dA_rel, dB_rel);
    fprintf('Dominant eig structure stable: %s\n', ternary(ev_dom_ok, 'YES', 'NO'));
    fprintf('JACOBIAN VERDICT: %s\n', verdict);

    ev = eig(A);
    [~, ord] = sort(real(ev), 'descend');
    ev = ev(ord);

    ix_v = [3, 5, 7, 9, 11];          % z theta u w q
    iu_v = [2, 3];                    % delta_e thrust
    ix_l = [2, 4, 6, 8, 10, 12];      % y phi psi v p r
    iu_l = 1;                         % delta_r

    Av = A(ix_v, ix_v); Bv = B(ix_v, iu_v);
    Al = A(ix_l, ix_l); Bl = B(ix_l, iu_l);

    A_vl = A(ix_v, ix_l); A_lv = A(ix_l, ix_v);
    B_v_from_dr = B(ix_v, 1);
    B_l_from_v = B(ix_l, iu_v);
    coup = struct();
    coup.norm_A_vl = norm(A_vl, 'fro');
    coup.norm_A_lv = norm(A_lv, 'fro');
    coup.norm_A_vv = norm(Av, 'fro');
    coup.norm_A_ll = norm(Al, 'fro');
    coup.rel_vl = coup.norm_A_vl / max(coup.norm_A_vv, eps);
    coup.rel_lv = coup.norm_A_lv / max(coup.norm_A_ll, eps);
    coup.norm_B_v_dr = norm(B_v_from_dr);
    coup.norm_B_l_de_th = norm(B_l_from_v, 'fro');
    coup.label = ['Decoupled vertical [z,theta,u,w,q] w/ [de,thrust] and ' ...
                  'lateral [y,phi,psi,v,p,r] w/ [dr]; ' ...
                  'omitted: x-channel + cross V↔L blocks'];

    col_norms = sqrt(sum(A.^2, 1)).';
    zero_mode_note = [ ...
        'Translating-trim kinematic integrators: plant forces/moments depend on ', ...
        'attitude+body rates/speeds, not on inertial x,y,z (no current/density gradient). ', ...
        'Columns of A for x,y,z are ~0 (pure kinematic integrators → near-zero eigenvalues). ', ...
        'Yaw psi enters only through NED kinematics R(phi,theta,psi); at climb trim with ', ...
        'v≈0 rates≈0, psi is a free heading integrator (zero mode). ', ...
        'Perturbation dynamics about translating nominal: δẋ = A δx + B δu ', ...
        '(absolute ẋ* = f(x*,u*) ≠ 0 is kinematics of the steady climb; linear model is about δ). ', ...
        sprintf('Column Frobenius norms A(:,x,y,z,psi)=[%.3e %.3e %.3e %.3e].', ...
            col_norms(1), col_norms(2), col_norms(3), col_norms(6))];

    % --- Level vs climb comparison (scheduling need) ---
    cmp = compare_to_level(level_mat, A, B, Av, Bv, ev);

    helix_note = [ ...
        'Helix (TRIM OP.helix): EXCLUDED from ordinary inertial LTI — classified ', ...
        'periodic/quasi-steady (rel residual ~0.02 > 1%). No fabricated rotating-frame ', ...
        'A,B matrix in this task. Carry-forward only.'];

    png_path = fullfile(out_dir, [tag '.png']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    md_path  = fullfile(out_dir, [tag '.md']);
    write_png(png_path, A, B, ev1, ev2, dA_rel, dB_rel, jac_pass, task_id, cmp);
    write_md(md_path, task_id, trim_mat, level_mat, x0, u0_vec, f0, A, B, C, D, ...
        A1, B1, A2, B2, dA_rel, dB_rel, ev, ev_report, ev_dom_ok, jac_pass, ...
        Av, Bv, Al, Bl, coup, zero_mode_note, helix_note, cmp, ...
        state_names, input_names, units_x, units_u, x_scale, u_scale, eps_rel, ...
        trim_meta, png_path, mat_path);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.jac_pass = jac_pass;
    S.plant = 'underwater777_vehicle_dynamics';
    S.trim_mat = trim_mat;
    S.level_mat = level_mat;
    S.x0 = x0; S.u0 = u0_vec; S.u0_struct = u0; S.f0 = f0;
    S.A = A; S.B = B; S.C = C; S.D = D;
    S.A_eps = A1; S.B_eps = B1; S.A_half = A2; S.B_half = B2;
    S.dA_rel = dA_rel; S.dB_rel = dB_rel;
    S.eig_A = ev; S.eig_eps = ev1; S.eig_half = ev2;
    S.ev_dom_ok = ev_dom_ok; S.ev_report = ev_report;
    S.x_scale = x_scale; S.u_scale = u_scale; S.eps_rel = eps_rel;
    S.state_names = state_names; S.input_names = input_names;
    S.units_x = units_x; S.units_u = units_u;
    S.ix_vertical = ix_v; S.iu_vertical = iu_v;
    S.ix_lateral = ix_l; S.iu_lateral = iu_l;
    S.A_vertical = Av; S.B_vertical = Bv;
    S.A_lateral = Al; S.B_lateral = Bl;
    S.coupling = coup;
    S.zero_mode_note = zero_mode_note;
    S.helix_note = helix_note;
    S.compare_level = cmp;
    S.perturbation_form = 'delta_xdot = A*delta_x + B*delta_u about translating climb (x*,u*)';
    S.trim_meta = trim_meta;
    S.frame = 'NED inertial η + BODY ν; Euler ZYX; inputs delta_r,delta_e,thrust=Xprop';
    S.input_signs = 'delta_r>0 → +Y/+N via Yuudr/Nuudr*u^2; delta_e>0 → +Z/+M via Zuuds/Muuds*u^2; thrust=+Xprop';
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    save(mat_path, '-struct', 'S');

    append_audit(out_dir, S);

    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    fprintf('FEEDBACK: %s  dA=%.3g%% dB=%.3g%%  maxRe(eig)=%.4g\n', ...
        verdict, 100*dA_rel, 100*dB_rel, max(real(ev)));
    if cmp.ok
        fprintf('vs LEVEL: ||ΔA||_F/||A_L||=%.4g  ||ΔB||_F/||B_L||=%.4g  schedule=%s\n', ...
            cmp.dA_norm, cmp.dB_norm, cmp.schedule_need);
    end
end

%% ===================== helpers =====================

function [x0, u0_vec, u0, meta] = extract_climb_trim(T)
    meta = struct('source', 'TRIM_OPERATING_POINTS.mat', 'point', 'climb');
    x0 = [];
    u0_vec = [];
    cands = {};
    if isfield(T, 'OP'); cands{end+1} = T.OP; end %#ok<*AGROW>
    if isfield(T, 'op'); cands{end+1} = T.op; end
    if isfield(T, 'results'); cands{end+1} = T.results; end
    if isfield(T, 'task'); cands{end+1} = T.task; end
    for k = 1:numel(cands)
        C = cands{k};
        if isstruct(C) && isfield(C, 'climb')
            L = C.climb;
            x0 = get_field_vec(L, {'x_star','x0','x','x_trim'});
            u0_vec = get_field_vec(L, {'u_star','u0','u','u_trim'});
            if ~isempty(x0); meta.branch = 'OP.climb'; break; end
        end
        if isstruct(C) && isfield(C, 'xz')
            L = C.xz;
            x0 = get_field_vec(L, {'x_star','x0','x','x_trim'});
            u0_vec = get_field_vec(L, {'u_star','u0','u','u_trim'});
            if ~isempty(x0); meta.branch = 'OP.xz'; break; end
        end
    end
    if isempty(x0) && isfield(T, 'climb')
        L = T.climb;
        x0 = get_field_vec(L, {'x_star','x0','x','x_trim'});
        u0_vec = get_field_vec(L, {'u_star','u0','u','u_trim'});
        meta.branch = 'climb';
    end
    if isempty(x0) && isfield(T, 'x_climb'); x0 = T.x_climb(:); meta.branch = 'x_climb'; end
    if isempty(u0_vec) && isfield(T, 'u_climb'); u0_vec = T.u_climb(:); end
    if isempty(x0) || numel(x0) ~= 12 || isempty(u0_vec) || numel(u0_vec) ~= 3
        x0 = [0; 0; 0; 0; -0.418597; 0; 1.75462; 0; -0.066866; 0; -1.12262e-27; 0];
        u0_vec = [0; -0.0211301; 7.01987];
        meta.branch = 'STATE_SPACE_MODEL_AUDIT canonical CLIMB';
        warning('Climb trim vectors not found in MAT; using audit-canonical CLIMB x*,u*.');
    end
    x0 = x0(:); u0_vec = u0_vec(:);
    u0 = struct('delta_r', u0_vec(1), 'delta_e', u0_vec(2), 'thrust', u0_vec(3));
end

function v = get_field_vec(S, names)
    v = [];
    if ~isstruct(S); return; end
    for i = 1:numel(names)
        if isfield(S, names{i})
            raw = S.(names{i});
            if isnumeric(raw) && ~isempty(raw)
                v = raw(:);
                return;
            end
        end
    end
end

function [A, B] = scale_aware_fd(x0, u0, x_scale, u_scale, eps_rel)
    n = 12; m = 3;
    A = zeros(n); B = zeros(n, m);
    dx = eps_rel * x_scale;
    du = eps_rel * u_scale;
    dx = max(dx, 1e-9 * x_scale);
    du = max(du, 1e-9 * u_scale);

    for i = 1:n
        xp = x0; xm = x0;
        xp(i) = xp(i) + dx(i);
        xm(i) = xm(i) - dx(i);
        fp = underwater777_vehicle_dynamics(0, xp, u0);
        fm = underwater777_vehicle_dynamics(0, xm, u0);
        A(:, i) = (fp - fm) / (2 * dx(i));
    end

    for j = 1:m
        up = u0; um = u0;
        switch j
            case 1
                up.delta_r = up.delta_r + du(j);
                um.delta_r = um.delta_r - du(j);
            case 2
                up.delta_e = up.delta_e + du(j);
                um.delta_e = um.delta_e - du(j);
            case 3
                up.thrust = up.thrust + du(j);
                um.thrust = um.thrust - du(j);
        end
        fp = underwater777_vehicle_dynamics(0, x0, up);
        fm = underwater777_vehicle_dynamics(0, x0, um);
        B(:, j) = (fp - fm) / (2 * du(j));
    end
end

function [ok, report] = eigenvalue_structure_stable(ev1, ev2, n_dom)
    e1 = sort_ev(ev1); e2 = sort_ev(ev2);
    n_dom = min([n_dom, numel(e1), numel(e2)]);
    s1 = sign_nz(real(e1(1:n_dom)));
    s2 = sign_nz(real(e2(1:n_dom)));
    sign_ok = isequal(s1, s2);

    re_err = 0;
    for k = 1:n_dom
        denom = max(abs(e1(k)), abs(e2(k)));
        denom = max(denom, 1e-8);
        re_err = max(re_err, abs(e2(k) - e1(k)) / denom);
    end
    mag_ok = re_err <= 0.25;
    ok = sign_ok && mag_ok;

    report = struct();
    report.n_dom = n_dom;
    report.sign_ok = sign_ok;
    report.mag_ok = mag_ok;
    report.max_rel_ev_change = re_err;
    report.signs_eps = s1;
    report.signs_half = s2;
    report.ev_eps_dom = e1(1:n_dom);
    report.ev_half_dom = e2(1:n_dom);
end

function e = sort_ev(ev)
    [~, ix] = sort(real(ev), 'descend');
    e = ev(ix);
end

function s = sign_nz(re)
    s = sign(re);
    s(abs(re) < 1e-8) = 0;
end

function cmp = compare_to_level(level_mat, A, B, Av, Bv, ev_climb)
    cmp = struct('ok', false, 'note', '');
    if ~exist(level_mat, 'file')
        cmp.note = sprintf('LEVEL mat missing: %s', level_mat);
        warning(cmp.note);
        return;
    end
    L = load(level_mat);
    if ~isfield(L, 'A') || ~isfield(L, 'B')
        cmp.note = 'LEVEL mat lacks A/B';
        warning(cmp.note);
        return;
    end
    AL = L.A; BL = L.B;
    nA = max(norm(AL, 'fro'), eps);
    nB = max(norm(BL, 'fro'), eps);
    dA = A - AL; dB = B - BL;
    cmp.ok = true;
    cmp.level_mat = level_mat;
    cmp.dA_norm = norm(dA, 'fro') / nA;
    cmp.dB_norm = norm(dB, 'fro') / nB;
    cmp.norm_A_level = nA;
    cmp.norm_A_climb = norm(A, 'fro');
    cmp.norm_B_level = nB;
    cmp.norm_B_climb = norm(B, 'fro');
    cmp.dA = dA; cmp.dB = dB;

    if isfield(L, 'A_vertical'); AvL = L.A_vertical; else
        AvL = AL([3 5 7 9 11], [3 5 7 9 11]);
    end
    if isfield(L, 'B_vertical'); BvL = L.B_vertical; else
        BvL = BL([3 5 7 9 11], [2 3]);
    end
    cmp.dAv_norm = norm(Av - AvL, 'fro') / max(norm(AvL, 'fro'), eps);
    cmp.dBv_norm = norm(Bv - BvL, 'fro') / max(norm(BvL, 'fro'), eps);
    cmp.A_vertical_level = AvL;
    cmp.B_vertical_level = BvL;
    cmp.dA_vertical = Av - AvL;
    cmp.dB_vertical = Bv - BvL;

    if isfield(L, 'eig_A'); evL = L.eig_A(:); else; evL = eig(AL); end
    [~, oL] = sort(real(evL), 'descend'); evL = evL(oL);
    [~, oC] = sort(real(ev_climb), 'descend'); evC = ev_climb(oC);
    n_dom = min(6, min(numel(evL), numel(evC)));
    cmp.eig_level_dom = evL(1:n_dom);
    cmp.eig_climb_dom = evC(1:n_dom);
    cmp.eig_dom_delta = evC(1:n_dom) - evL(1:n_dom);

    % Scheduling heuristic: material if normalized ΔA or ΔB > 5%, or vertical > 10%
    need = (cmp.dA_norm > 0.05) || (cmp.dB_norm > 0.05) || ...
           (cmp.dAv_norm > 0.10) || (cmp.dBv_norm > 0.10);
    if need
        cmp.schedule_need = 'YES — gain/model scheduling recommended (climb≠level)';
    else
        cmp.schedule_need = 'MILD — single-trim LTI may suffice; monitor climb vertical';
    end
    cmp.note = sprintf(['Normalized ||ΔA||_F/||A_level||=%.4g, ||ΔB||_F/||B_level||=%.4g; ', ...
        'vertical ||ΔAv||=%.4g, ||ΔBv||=%.4g. %s'], ...
        cmp.dA_norm, cmp.dB_norm, cmp.dAv_norm, cmp.dBv_norm, cmp.schedule_need);
end

function write_png(png_path, A, B, ev1, ev2, dA_rel, dB_rel, jac_pass, task_id, cmp)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 60 1400 1000]);

    subplot(2, 3, 1);
    imagesc(log10(abs(A) + 1e-16));
    axis equal tight; colorbar;
    title('log10|A| climb sparsity');
    xlabel('state j'); ylabel('state i');
    set(gca, 'XTick', 1:12, 'YTick', 1:12);

    subplot(2, 3, 2);
    imagesc(log10(abs(B) + 1e-16));
    axis equal tight; colorbar;
    title('log10|B| climb sparsity');
    xlabel('input [dr de thrust]'); ylabel('state i');
    set(gca, 'XTick', 1:3, 'YTick', 1:12);

    subplot(2, 3, 3);
    plot(real(ev1), imag(ev1), 'o', 'MarkerSize', 8); hold on;
    plot(real(ev2), imag(ev2), 'x', 'MarkerSize', 8, 'LineWidth', 1.4);
    grid on; axis equal;
    xlabel('Re'); ylabel('Im');
    title('Eigenvalues: eps (o) vs eps/2 (x)');
    legend('eps', 'eps/2', 'Location', 'best');
    xline(0, 'k:'); yline(0, 'k:');

    subplot(2, 3, 4);
    bar([100*dA_rel, 100*dB_rel]);
    hold on; yline(1, 'r--', '1% gate');
    set(gca, 'XTickLabel', {'||\DeltaA||_F / ||A||_F', '||\Delta B||_F / ||B||_F'});
    ylabel('%'); ylim([0, max(2, 1.2*100*max(dA_rel, dB_rel))]);
    title(sprintf('Step convergence — %s', ternary(jac_pass, 'PASS', 'FAIL')));
    grid on;

    subplot(2, 3, 5);
    if cmp.ok
        imagesc(log10(abs(cmp.dA) + 1e-16));
        axis equal tight; colorbar;
        title(sprintf('log10|A_climb-A_level| (norm=%.3g)', cmp.dA_norm));
        xlabel('state j'); ylabel('state i');
        set(gca, 'XTick', 1:12, 'YTick', 1:12);
    else
        text(0.1, 0.5, cmp.note, 'Interpreter', 'none');
        axis off; title('Level delta unavailable');
    end

    subplot(2, 3, 6);
    if cmp.ok
        bar([100*cmp.dA_norm, 100*cmp.dB_norm, 100*cmp.dAv_norm, 100*cmp.dBv_norm]);
        set(gca, 'XTickLabel', {'||\DeltaA||', '||\DeltaB||', '||\DeltaAv||', '||\DeltaBv||'});
        ylabel('% of level');
        title('Climb vs level normalized deltas');
        grid on;
        hold on; yline(5, 'r--', '5%');
    else
        text(0.1, 0.5, 'no level compare', 'Interpreter', 'none');
        axis off;
    end

    sgtitle(sprintf('%s — plant-only XZ climb trim SS', task_id), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, task_id, trim_mat, level_mat, x0, u0_vec, f0, A, B, C, D, ...
        A1, B1, A2, B2, dA_rel, dB_rel, ev, ev_report, ev_dom_ok, jac_pass, ...
        Av, Bv, Al, Bl, coup, zero_mode_note, helix_note, cmp, ...
        state_names, input_names, units_x, units_u, x_scale, u_scale, eps_rel, ...
        trim_meta, png_path, mat_path) %#ok<INUSL>

    fid = fopen(md_path, 'w');
    assert(fid > 0, 'Cannot write %s', md_path);
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# %s — Local state-space at XZ climb trim\n\n', task_id);
    fprintf(fid, '**Verdict: %s**\n\n', ternary(jac_pass, 'PASS', 'FAIL'));
    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Plant RHS (exact): `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Trim: `%s` (%s)\n', trim_mat, trim_meta.branch);
    fprintf(fid, '- Level compare: `%s`\n', level_mat);
    fprintf(fid, '- Method: scale-aware central finite difference; steps `eps_rel` and `eps_rel/2` (same as LOCAL_SS_LEVEL)\n');
    fprintf(fid, '- eps_rel = %.3g; x_scale / u_scale from TRIM audit\n', eps_rel);
    fprintf(fid, '- No controller/guidance changes; production frozen\n');
    fprintf(fid, '- Helix: EXCLUDED (periodic/quasi-steady); no ordinary helix LTI fabricated\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);

    fprintf(fid, '## Operating point\n\n');
    fprintf(fid, '```\nx* = [%s]\nu* = [delta_r=%.8g, delta_e=%.8g, thrust=%.8g]\n', ...
        num2str(x0.', ' %.8g'), u0_vec(1), u0_vec(2), u0_vec(3));
    fprintf(fid, 'f(x*,u*) = [%s]\n||f||_2=%.3e  ||nu_dot||_2=%.3e\n```\n\n', ...
        num2str(f0.', ' %.3e'), norm(f0), norm(f0(7:12)));

    fprintf(fid, '## Perturbation dynamics (translating nominal)\n\n');
    fprintf(fid, ['Absolute plant at climb trim satisfies `ẋ* = f(x*,u*) ≠ 0` (steady ', ...
        'translation along slope: ż* ≈ 0.4 ẋ*, ν̇* ≈ 0). The local LTI is the ', ...
        '**perturbation** model:\n\n']);
    fprintf(fid, '```\nδẋ = A δx + B δu\n```\n\n');
    fprintf(fid, 'with δx = x − x*, δu = u − u*. Ideal C = I₁₂, D = 0.\n\n');

    fprintf(fid, '## Units / frame / input signs\n\n');
    fprintf(fid, '- State x=[x y z φ θ ψ u v w p q r]: NED position [m], Euler ZYX [rad], BODY velocities [m/s], BODY rates [rad/s]\n');
    fprintf(fid, '- Input u=[δr δe thrust]: rudder [rad], elevator [rad], Xprop [N]\n');
    fprintf(fid, '- Ideal C=I_12, D=0 (full-state)\n');
    fprintf(fid, '- Signs: δr>0 → +Y/+N (Yuudr/Nuudr·u²); δe>0 → +Z/+M (Zuuds/Muuds·u²); thrust = +Xprop\n');
    fprintf(fid, '- State units: %s\n', strjoin(units_x, ', '));
    fprintf(fid, '- Input units: %s\n\n', strjoin(units_u, ', '));

    fprintf(fid, '## Jacobian convergence gate\n\n');
    fprintf(fid, '| Quantity | Value | Gate |\n|---|---:|:---:|\n');
    fprintf(fid, '| ||A_half-A_eps||_F / ||A_eps||_F | %.6g (%.3f%%) | ≤1%% |\n', dA_rel, 100*dA_rel);
    fprintf(fid, '| ||B_half-B_eps||_F / ||B_eps||_F | %.6g (%.3f%%) | ≤1%% |\n', dB_rel, 100*dB_rel);
    fprintf(fid, '| Dominant eig sign/structure stable | %s (max rel Δ=%.3g) | required |\n', ...
        ternary(ev_dom_ok, 'YES', 'NO'), ev_report.max_rel_ev_change);
    fprintf(fid, '| **PASS** | **%s** | |\n\n', ternary(jac_pass, 'PASS', 'FAIL'));

    fprintf(fid, 'Reported A,B use **half-step** (eps_rel/2=%.3g).\n\n', eps_rel/2);

    fprintf(fid, '## A (12×12)\n\n```\n');
    print_mat(fid, A);
    fprintf(fid, '```\n\n## B (12×3)\n\n```\n');
    print_mat(fid, B);
    fprintf(fid, '```\n\n## C = I_12, D = 0_{12×3}\n\n');

    fprintf(fid, '## Eigenvalues of A (sorted by Re descending)\n\n```\n');
    for k = 1:numel(ev)
        fprintf(fid, '%2d: %+ .6e %+ .6ei\n', k, real(ev(k)), imag(ev(k)));
    end
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Vertical reduced model\n\n');
    fprintf(fid, 'States [z θ u w q], inputs [δe thrust]. **Coupling to lateral omitted.**\n\n');
    fprintf(fid, 'A_v (5×5):\n```\n'); print_mat(fid, Av); fprintf(fid, '```\n\n');
    fprintf(fid, 'B_v (5×2):\n```\n'); print_mat(fid, Bv); fprintf(fid, '```\n\n');

    fprintf(fid, '## Lateral reduced model\n\n');
    fprintf(fid, 'States [y φ ψ v p r], input [δr]. **Coupling to vertical omitted.**\n\n');
    fprintf(fid, 'A_l (6×6):\n```\n'); print_mat(fid, Al); fprintf(fid, '```\n\n');
    fprintf(fid, 'B_l (6×1):\n```\n'); print_mat(fid, Bl); fprintf(fid, '```\n\n');

    fprintf(fid, '## Off-block coupling quantification\n\n');
    fprintf(fid, '| Block | Frobenius norm | Relative |\n|---|---:|---:|\n');
    fprintf(fid, '| A_vertical | %.6g | 1 |\n', coup.norm_A_vv);
    fprintf(fid, '| A_lateral | %.6g | 1 |\n', coup.norm_A_ll);
    fprintf(fid, '| A(vert←lat) | %.6g | %.4g vs Av |\n', coup.norm_A_vl, coup.rel_vl);
    fprintf(fid, '| A(lat←vert) | %.6g | %.4g vs Al |\n', coup.norm_A_lv, coup.rel_lv);
    fprintf(fid, '| B(vert←δr) | %.6g | |\n', coup.norm_B_v_dr);
    fprintf(fid, '| B(lat←[δe,thrust]) | %.6g | |\n\n', coup.norm_B_l_de_th);
    fprintf(fid, '%s\n\n', coup.label);

    fprintf(fid, '## Climb vs level comparison (scheduling)\n\n');
    if cmp.ok
        fprintf(fid, '| Quantity | Value |\n|---|---:|\n');
        fprintf(fid, '| ||A_climb−A_level||_F / ||A_level||_F | %.6g (%.3f%%) |\n', ...
            cmp.dA_norm, 100*cmp.dA_norm);
        fprintf(fid, '| ||B_climb−B_level||_F / ||B_level||_F | %.6g (%.3f%%) |\n', ...
            cmp.dB_norm, 100*cmp.dB_norm);
        fprintf(fid, '| ||ΔA_v||_F / ||A_v,level||_F | %.6g (%.3f%%) |\n', ...
            cmp.dAv_norm, 100*cmp.dAv_norm);
        fprintf(fid, '| ||ΔB_v||_F / ||B_v,level||_F | %.6g (%.3f%%) |\n', ...
            cmp.dBv_norm, 100*cmp.dBv_norm);
        fprintf(fid, '\n**Scheduling need:** %s\n\n', cmp.schedule_need);
        fprintf(fid, 'Dominant eigenvalues (Re↓), level vs climb:\n\n```\n');
        for k = 1:numel(cmp.eig_level_dom)
            fprintf(fid, '%2d: level %+ .6e%+.6ei | climb %+ .6e%+.6ei | Δ %+ .4e%+.4ei\n', ...
                k, real(cmp.eig_level_dom(k)), imag(cmp.eig_level_dom(k)), ...
                real(cmp.eig_climb_dom(k)), imag(cmp.eig_climb_dom(k)), ...
                real(cmp.eig_dom_delta(k)), imag(cmp.eig_dom_delta(k)));
        end
        fprintf(fid, '```\n\n');
        fprintf(fid, 'ΔA_v = A_v,climb − A_v,level:\n```\n');
        print_mat(fid, cmp.dA_vertical);
        fprintf(fid, '```\n\nΔB_v:\n```\n');
        print_mat(fid, cmp.dB_vertical);
        fprintf(fid, '```\n\n');
    else
        fprintf(fid, '%s\n\n', cmp.note);
    end

    fprintf(fid, '## Translating-trim kinematic integrators / zero modes\n\n');
    fprintf(fid, '%s\n\n', zero_mode_note);

    fprintf(fid, '## Helix (carry-forward)\n\n');
    fprintf(fid, '%s\n\n', helix_note);

    fprintf(fid, '## Scales\n\n');
    fprintf(fid, '```\nx_scale = [%s]\nu_scale = [%s]\nstate = [%s]\ninput = [%s]\n```\n\n', ...
        num2str(x_scale.', ' %.4g'), num2str(u_scale.', ' %.4g'), ...
        strjoin(state_names, ' '), strjoin(input_names, ' '));

    fprintf(fid, '## Next\n\n');
    fprintf(fid, '- If PASS: use climb A,B for LTI vertical design about XZ trim; schedule vs level if needed.\n');
    fprintf(fid, '- Helix remains EXCLUDED from ordinary inertial LTI (periodic/quasi-steady).\n');
end

function print_mat(fid, M)
    for i = 1:size(M, 1)
        fprintf(fid, '% .8e', M(i, 1));
        for j = 2:size(M, 2)
            fprintf(fid, '  % .8e', M(i, j));
        end
        fprintf(fid, '\n');
    end
end

function append_audit(out_dir, S)
    audit = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit, 'a');
    assert(fid > 0);
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    ts = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    fprintf(fid, '\n\n---\n\n## %s — %s\n\n', S.task_id, ts);
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Plant RHS: `underwater777_vehicle_dynamics.m` (exact; no controller/guidance edits)\n');
    fprintf(fid, '- Trim source: `%s` (%s)\n', S.trim_mat, S.trim_meta.branch);
    fprintf(fid, '- Level compare: `%s`\n', S.level_mat);
    fprintf(fid, '- Driver: `run_local_ss_climb.m`\n');
    fprintf(fid, '- Method: scale-aware central FD, eps_rel=%.3g and half-step; report half-step A,B\n', S.eps_rel);
    fprintf(fid, '- Perturbation form: `%s`\n', S.perturbation_form);
    fprintf(fid, '- Helix: EXCLUDED (periodic/quasi-steady); no fabricated rotating-frame LTI\n');
    fprintf(fid, '- Full matrix paths:\n');
    fprintf(fid, '  - `%s`\n', S.paths.md);
    fprintf(fid, '  - `%s`\n', S.paths.mat);
    fprintf(fid, '  - `%s`\n', S.paths.png);
    fprintf(fid, '\n### Assumptions\n\n');
    fprintf(fid, '- XZ climb is LTI-eligible steady translating trim (ν̇≈0; ż≈0.4ẋ)\n');
    fprintf(fid, '- Linearization is plant-only about (x*,u*); C=I, D=0\n');
    fprintf(fid, '- Same FD scales/eps as LOCAL_SS_LEVEL_001\n');
    fprintf(fid, '- Reduced vertical/lateral blocks omit V↔L cross-coupling and x-channel\n\n');
    fprintf(fid, '### Gate\n\n');
    fprintf(fid, '- dA_rel=%.6g (%.3f%%), dB_rel=%.6g (%.3f%%), eig_structure_stable=%s\n', ...
        S.dA_rel, 100*S.dA_rel, S.dB_rel, 100*S.dB_rel, ternary(S.ev_dom_ok, 'YES', 'NO'));
    fprintf(fid, '- **Jacobian verdict: %s**\n\n', S.verdict);
    fprintf(fid, '### x*, u*\n\n```\nx*=[%s]\nu*=[%s]\n```\n\n', ...
        num2str(S.x0.', ' %.8g'), num2str(S.u0.', ' %.8g'));
    fprintf(fid, '### Frame / signs\n\n');
    fprintf(fid, '- %s\n- %s\n- Ideal C=I12, D=0\n\n', S.frame, S.input_signs);
    fprintf(fid, '### Coupling (omitted in reduced models)\n\n');
    fprintf(fid, '- ||A_vl||_F=%.6g (rel %.4g), ||A_lv||_F=%.6g (rel %.4g)\n', ...
        S.coupling.norm_A_vl, S.coupling.rel_vl, S.coupling.norm_A_lv, S.coupling.rel_lv);
    fprintf(fid, '- %s\n\n', S.coupling.label);
    if S.compare_level.ok
        fprintf(fid, '### Climb vs level\n\n');
        fprintf(fid, '- %s\n', S.compare_level.note);
        fprintf(fid, '- Scheduling: %s\n\n', S.compare_level.schedule_need);
    end
    fprintf(fid, '### Zero modes\n\n%s\n\n', S.zero_mode_note);
    fprintf(fid, '### Helix\n\n%s\n\n', S.helix_note);
    fprintf(fid, '### Eigenvalues (Re↓)\n\n```\n');
    for k = 1:numel(S.eig_A)
        fprintf(fid, '%2d: %+ .6e %+ .6ei\n', k, real(S.eig_A(k)), imag(S.eig_A(k)));
    end
    fprintf(fid, '```\n\n');
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- Use climb A,B for vertical LTI about XZ trim; schedule vs level if indicated.\n');
    fprintf(fid, '- Helix remains non-LTI inertial (excluded).\n');
end

function s = ternary(c, a, b)
    if c; s = a; else; s = b; end
end
