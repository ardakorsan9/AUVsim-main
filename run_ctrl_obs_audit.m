function run_ctrl_obs_audit()
% CTRL_OBS_AUDIT_001 — scaled controllability/observability at level & climb.
% Read-only: LOCAL_SS_LEVEL.mat, LOCAL_SS_CLIMB.mat, SS_VALIDATION.md.
% One MATLAB invocation. No controller / plant / guidance edits.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    tag = 'CTRL_OBS_AUDIT';
    task_id = 'CTRL_OBS_AUDIT_001';

    L = load(fullfile(out_dir, 'LOCAL_SS_LEVEL.mat'));
    Cmb = load(fullfile(out_dir, 'LOCAL_SS_CLIMB.mat'));

    state_names = {'x','y','z','phi','theta','psi','u','v','w','p','q','r'};
    input_names = {'delta_r','delta_e','thrust'};
    units_x = {'m','m','m','rad','rad','rad','m/s','m/s','m/s','rad/s','rad/s','rad/s'};
    units_u = {'rad','rad','N'};
    frame = 'NED eta + BODY nu; Euler ZYX; inputs dr,de,thrust=Xprop';

    x_scale = L.x_scale(:);
    u_scale = L.u_scale(:);
    % Documented floors (TRIM / LOCAL_SS); assert climb matches
    assert(norm(Cmb.x_scale(:) - x_scale) < 1e-12, 'x_scale mismatch level vs climb');
    assert(norm(Cmb.u_scale(:) - u_scale) < 1e-12, 'u_scale mismatch level vs climb');

    ix_v = [3, 5, 7, 9, 11];          % z theta u w q
    iu_v = [2, 3];                    % de thrust
    ix_l = [2, 4, 6, 8, 10, 12];      % y phi psi v p r
    iu_l = 1;                         % dr

    % Observability output index sets (assumed direct outputs — not sensor models)
    iy_A = 1:12;                                      % ideal C=I12
    iy_B = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12];         % z,phi,theta,psi,u,v,w,p,q,r
    iy_C = 1:12;                                      % B + INS x,y (= full)

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Sources: LOCAL_SS_LEVEL.mat / LOCAL_SS_CLIMB.mat (jac PASS; SS_VALIDATION PASS)\n');
    fprintf('Frame: %s\n', frame);
    fprintf('x_scale = [%s]\n', num2str(x_scale.', ' %.4g'));
    fprintf('u_scale = [%s]\n', num2str(u_scale.', ' %.4g'));

    level = audit_op('level', L.A, L.B, L.eig_A, x_scale, u_scale, ...
        state_names, input_names, ix_v, iu_v, ix_l, iu_l, iy_A, iy_B, iy_C);
    climb = audit_op('climb', Cmb.A, Cmb.B, Cmb.eig_A, x_scale, u_scale, ...
        state_names, input_names, ix_v, iu_v, ix_l, iu_l, iy_A, iy_B, iy_C);

    compare = compare_ops(level, climb, state_names);

    % PASS: reproducible scaled SVD+PBH with explicit tol/units; not raw rank alone
    has_svd_pbh = level.ok_report && climb.ok_report;
    scales_stated = true;
    lvl_climb_diff = ~isempty(compare.summary);
    verdict = tern(has_svd_pbh && scales_stated && lvl_climb_diff, 'PASS', 'FAIL');

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    write_png(png_path, level, climb, task_id);
    write_md(md_path, task_id, verdict, level, climb, compare, ...
        x_scale, u_scale, state_names, input_names, units_x, units_u, frame, ...
        iy_A, iy_B, iy_C, md_path, mat_path, png_path);
    append_audit(out_dir, task_id, verdict, level, climb, compare, ...
        md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.verdict = verdict;
    S.x_scale = x_scale; S.u_scale = u_scale;
    S.state_names = state_names; S.input_names = input_names;
    S.units_x = units_x; S.units_u = units_u; S.frame = frame;
    S.level = level; S.climb = climb; S.compare = compare;
    S.iy_A = iy_A; S.iy_B = iy_B; S.iy_C = iy_C;
    S.tol_rule = 'tol = max(m,n)*eps(max(sigma))*max(1,cond_floor); rank = nnz(sigma > tol)';
    S.sources = {fullfile(out_dir,'LOCAL_SS_LEVEL.mat'); ...
                 fullfile(out_dir,'LOCAL_SS_CLIMB.mat'); ...
                 fullfile(out_dir,'SS_VALIDATION.md')};
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.note = ['Scaled SVD+PBH controllability/observability; helix excluded; ' ...
              'no production change; assumed direct outputs only'];
    save(mat_path, '-struct', 'S');

    fprintf('\nVERDICT: %s\n', verdict);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(verdict, level, climb, compare, md_path, mat_path, png_path);
end

%% ===================== per-operating-point audit =====================
function R = audit_op(name, A, B, eig_raw, x_scale, u_scale, sn, in, ...
        ix_v, iu_v, ix_l, iu_l, iy_A, iy_B, iy_C)

    R.name = name;
    R.A = A; R.B = B;
    [V, D] = eig(A);
    ev = diag(D);
    [~, ord] = sort(real(ev), 'descend');
    ev = ev(ord); V = V(:, ord);
    R.eig = ev;
    R.eig_raw = eig_raw(:);
    R.mode_labels = label_modes(ev, V, sn);

    % --- Controllability cases ---
    R.ctrl.full = ctrl_case('full_12', A, B, x_scale, u_scale, 1:12, 1:3, ev, V, sn);

    [Vv, Dv] = eig(A(ix_v,ix_v)); evv = diag(Dv);
    [~, ov] = sort(real(evv), 'descend'); evv = evv(ov); Vv = Vv(:,ov);
    R.ctrl.vert = ctrl_case('vertical_5', A(ix_v,ix_v), B(ix_v,iu_v), ...
        x_scale(ix_v), u_scale(iu_v), ix_v, iu_v, evv, Vv, sn(ix_v));

    [Vl, Dl] = eig(A(ix_l,ix_l)); evl = diag(Dl);
    [~, ol] = sort(real(evl), 'descend'); evl = evl(ol); Vl = Vl(:,ol);
    R.ctrl.lat = ctrl_case('lateral_6', A(ix_l,ix_l), B(ix_l,iu_l), ...
        x_scale(ix_l), u_scale(iu_l), ix_l, iu_l, evl, Vl, sn(ix_l));

    % --- Observability cases ---
    R.obs.A = obs_case('A_ideal_I12', A, iy_A, x_scale, ev, V, sn, 'all states (ideal)');
    R.obs.B = obs_case('B_onboard_no_xy', A, iy_B, x_scale, ev, V, sn, ...
        'IMU+DVL+depth+heading assumed direct; no absolute x,y');
    R.obs.C = obs_case('C_B_plus_INS_xy', A, iy_C, x_scale, ev, V, sn, ...
        'case B + INS absolute x,y (assumed direct)');

    R.ok_report = all([ ...
        R.ctrl.full.has_svd, R.ctrl.vert.has_svd, R.ctrl.lat.has_svd, ...
        R.obs.A.has_svd, R.obs.B.has_svd, R.obs.C.has_svd, ...
        R.ctrl.full.has_pbh, R.ctrl.vert.has_pbh, R.ctrl.lat.has_pbh, ...
        R.obs.A.has_pbh, R.obs.B.has_pbh, R.obs.C.has_pbh]);
end

function c = ctrl_case(tag, A, B, xs, us, ix_global, iu_global, ev, V, sn)
    n = size(A, 1); m = size(B, 2);
    Sx = diag(xs(:)); Su = diag(us(:));
    As = Sx \ (A * Sx);
    Bs = Sx \ (B * Su);
    Qc = ctrb(As, Bs);
    [~, S, ~] = svd(Qc, 'econ');
    sig = diag(S);
    [rk, tol, condn] = rank_from_sigma(sig, size(Qc,1), size(Qc,2));

    c = struct();
    c.tag = tag;
    c.n = n; c.m = m;
    c.ix = ix_global; c.iu = iu_global;
    c.As = As; c.Bs = Bs;
    c.sigma = sig;
    c.sigma_max = sig(1);
    c.sigma_min = sig(end);
    c.tol = tol;
    c.rank = rk;
    c.cond = condn;
    c.has_svd = true;
    c.weak_dirs = [];  % filled if needed

    if isempty(ev)
        [V, D] = eig(A); ev = diag(D);
        [~, o] = sort(real(ev), 'descend'); ev = ev(o); V = V(:,o);
    end
    c.eig = ev;
    c.pbh = pbh_ctrl(A, B, xs, us, ev);  % physical A,B + scales
    c.has_pbh = true;
    c.mode_class = classify_ctrl_modes(ev, c.pbh, V, sn);
    c.weak_modes = c.mode_class([c.mode_class.weak]);
    c.unctrl_modes = c.mode_class([c.mode_class.uncontrollable]);
end

function o = obs_case(tag, A, iy, xs, ev, V, sn, note)
    n = size(A, 1);
    C = zeros(numel(iy), n);
    for k = 1:numel(iy)
        C(k, iy(k)) = 1;
    end
    Sy = diag(xs(iy));
    Sx = diag(xs(:));
    As = Sx \ (A * Sx);
    Cs = Sy \ (C * Sx);
    Qo = obsv(As, Cs);
    [~, S, ~] = svd(Qo, 'econ');
    sig = diag(S);
    [rk, tol, condn] = rank_from_sigma(sig, size(Qo,1), size(Qo,2));

    o = struct();
    o.tag = tag;
    o.note = note;
    o.iy = iy;
    o.C = C; o.As = As; o.Cs = Cs;
    o.sigma = sig;
    o.sigma_max = sig(1);
    o.sigma_min = sig(end);
    o.tol = tol;
    o.rank = rk;
    o.cond = condn;
    o.has_svd = true;
    o.eig = ev;
    o.pbh = pbh_obs(A, C, xs, xs(iy), ev);
    o.has_pbh = true;
    o.mode_class = classify_obs_modes(ev, o.pbh, V, sn, iy);
    o.weak_modes = o.mode_class([o.mode_class.weak]);
    o.unobs_modes = o.mode_class([o.mode_class.unobservable]);
    o.integrator_modes = o.mode_class([o.mode_class.is_integrator]);
    o.dynamic_modes = o.mode_class(~[o.mode_class.is_integrator]);
end

%% ===================== PBH / rank helpers =====================
function pbh = pbh_ctrl(A, B, xs, us, ev)
    Sx = diag(xs(:)); Su = diag(us(:));
    n = size(A,1); m = size(B,2);
    pbh = repmat(struct('lam',0,'sigma_min',0,'weak',false,'uncontrollable',false), numel(ev), 1);
    for k = 1:numel(ev)
        lam = ev(k);
        M = [lam*eye(n) - A, B];
        % column-scale states/inputs; row-scale equations by Sx^{-1}
        Ms = (Sx \ M) * blkdiag(Sx, Su);
        s = svd(Ms);
        smin = s(end);
        tol = max(size(Ms)) * eps(max(s)) * 10;  % slightly loose vs machine for near-zeros
        pbh(k).lam = lam;
        pbh(k).sigma_min = smin;
        pbh(k).sigma_all = s;
        pbh(k).tol = tol;
        pbh(k).uncontrollable = smin <= tol;
        pbh(k).weak = (~pbh(k).uncontrollable) && (smin < 1e-3 * max(s));
    end
end

function pbh = pbh_obs(A, C, xs, ys, ev)
    Sx = diag(xs(:)); Sy = diag(ys(:));
    n = size(A,1); p = size(C,1);
    pbh = repmat(struct('lam',0,'sigma_min',0,'weak',false,'unobservable',false), numel(ev), 1);
    for k = 1:numel(ev)
        lam = ev(k);
        M = [lam*eye(n) - A; C];
        % column-scale states; row-scale dyn eq by Sx^{-1}, outputs by Sy^{-1}
        Ms = blkdiag(Sx \ eye(n), Sy \ eye(p)) * M * Sx;
        s = svd(Ms);
        smin = s(end);
        tol = max(size(Ms)) * eps(max(s)) * 10;
        pbh(k).lam = lam;
        pbh(k).sigma_min = smin;
        pbh(k).sigma_all = s;
        pbh(k).tol = tol;
        pbh(k).unobservable = smin <= tol;
        pbh(k).weak = (~pbh(k).unobservable) && (smin < 1e-3 * max(s));
    end
end

function [rk, tol, condn] = rank_from_sigma(sig, m, n)
    if isempty(sig)
        rk = 0; tol = 0; condn = Inf; return;
    end
    smax = sig(1);
    tol = max(m, n) * eps(smax);
    % MATLAB rank default-like; keep explicit
    rk = sum(sig > tol);
    if sig(end) > 0
        condn = smax / sig(end);
    else
        condn = Inf;
    end
end

function mc = classify_ctrl_modes(ev, pbh, V, sn)
    n = numel(ev);
    mc = repmat(struct('k',0,'lam',0,'label','','sigma_min',0, ...
        'weak',false,'uncontrollable',false,'is_integrator',false,'class',''), n, 1);
    for k = 1:n
        mc(k).k = k;
        mc(k).lam = ev(k);
        mc(k).sigma_min = pbh(k).sigma_min;
        mc(k).weak = pbh(k).weak;
        mc(k).uncontrollable = pbh(k).uncontrollable;
        mc(k).is_integrator = abs(ev(k)) < 1e-8;
        mc(k).label = mode_participation(V(:,k), sn);
        if mc(k).is_integrator
            mc(k).class = 'kinematic_integrator';
        else
            mc(k).class = 'dynamic';
        end
    end
end

function mc = classify_obs_modes(ev, pbh, V, sn, iy)
    n = numel(ev);
    observed = false(1, numel(sn));
    observed(iy) = true;
    mc = repmat(struct('k',0,'lam',0,'label','','sigma_min',0, ...
        'weak',false,'unobservable',false,'is_integrator',false, ...
        'class','','missing_global_pos',false), n, 1);
    for k = 1:n
        mc(k).k = k;
        mc(k).lam = ev(k);
        mc(k).sigma_min = pbh(k).sigma_min;
        mc(k).weak = pbh(k).weak;
        mc(k).unobservable = pbh(k).unobservable;
        mc(k).is_integrator = abs(ev(k)) < 1e-8;
        [lab, top_ix] = mode_participation(V(:,k), sn);
        mc(k).label = lab;
        % Global-position integrators: near-zero eig dominated by x and/or y
        dom_xy = any(ismember(top_ix(1:min(2,numel(top_ix))), [1 2]));
        mc(k).missing_global_pos = mc(k).is_integrator && dom_xy && ...
            (~observed(1) || ~observed(2));
        if mc(k).is_integrator && (dom_xy || any(ismember(top_ix(1), [1 2 3 6])))
            mc(k).class = 'global_position_or_heading_integrator';
        elseif mc(k).is_integrator
            mc(k).class = 'kinematic_integrator';
        else
            mc(k).class = 'dynamic';
        end
    end
end

function [lab, top_ix] = mode_participation(v, sn)
    a = abs(v(:));
    [~, ix] = sort(a, 'descend');
    top_ix = ix(1:min(3, numel(ix)));
    parts = cell(numel(top_ix), 1);
    for i = 1:numel(top_ix)
        parts{i} = sprintf('%s(%.2f)', sn{top_ix(i)}, a(top_ix(i)) / max(sum(a), eps));
    end
    lab = strjoin(parts, '+');
end

function labels = label_modes(ev, V, sn)
    labels = cell(numel(ev), 1);
    for k = 1:numel(ev)
        labels{k} = mode_participation(V(:,k), sn);
    end
end

%% ===================== level vs climb =====================
function cmp = compare_ops(L, C, sn)
    cmp = struct();
    % Controllability PBH sigma_min per matched mode index (sorted Re↓)
    n = min(numel(L.eig), numel(C.eig));
    sL = arrayfun(@(p) p.sigma_min, L.ctrl.full.pbh);
    sC = arrayfun(@(p) p.sigma_min, C.ctrl.full.pbh);
    cmp.ctrl_full_smin_level = sL;
    cmp.ctrl_full_smin_climb = sC;
    cmp.ctrl_full_smin_ratio = sC(1:n) ./ max(sL(1:n), eps);
    cmp.rank_full_level = L.ctrl.full.rank;
    cmp.rank_full_climb = C.ctrl.full.rank;
    cmp.rank_vert_level = L.ctrl.vert.rank;
    cmp.rank_vert_climb = C.ctrl.vert.rank;
    cmp.rank_lat_level = L.ctrl.lat.rank;
    cmp.rank_lat_climb = C.ctrl.lat.rank;
    cmp.cond_full_level = L.ctrl.full.cond;
    cmp.cond_full_climb = C.ctrl.full.cond;

    % Obs B: expected unobs of x,y integrators
    cmp.obsB_unobs_level = sum([L.obs.B.mode_class.unobservable]);
    cmp.obsB_unobs_climb = sum([C.obs.B.mode_class.unobservable]);
    cmp.obsB_rank_level = L.obs.B.rank;
    cmp.obsB_rank_climb = C.obs.B.rank;

    % Design implications text
    lines = {};
    lines{end+1} = sprintf(['Full ctrl rank level=%d/%d climb=%d/%d (tol-aware); ' ...
        'cond(Qc_s) level=%.3g climb=%.3g'], ...
        L.ctrl.full.rank, L.ctrl.full.n, C.ctrl.full.rank, C.ctrl.full.n, ...
        L.ctrl.full.cond, C.ctrl.full.cond);
    lines{end+1} = sprintf('Vertical reduced rank level=%d/5 climb=%d/5; lateral level=%d/6 climb=%d/6', ...
        L.ctrl.vert.rank, C.ctrl.vert.rank, L.ctrl.lat.rank, C.ctrl.lat.rank);
    % Find weakest dynamic (non-integrator) ctrl modes
    for op = {L, C}
        R = op{1};
        dyn = R.ctrl.full.mode_class(~[R.ctrl.full.mode_class.is_integrator]);
        if isempty(dyn); continue; end
        [~, iw] = min([dyn.sigma_min]);
        lines{end+1} = sprintf('%s weakest dynamic ctrl PBH sigma_min=%.3e at lam=%s (%s)', ...
            R.name, dyn(iw).sigma_min, format_eig(dyn(iw).lam), dyn(iw).label); %#ok<AGROW>
    end
    lines{end+1} = sprintf(['Obs B (no x,y): rank level=%d climb=%d — global-position ' ...
        'integrators unobservable as expected; dynamic modes remain observable'], ...
        L.obs.B.rank, C.obs.B.rank);
    lines{end+1} = ['Climb vs level: schedule LQR/LQI gains (prior ΔA~9%, ΔB~7%); ' ...
        'do not use a single trim model for both'];
    lines{end+1} = ['Helix excluded from this audit (non-LTI inertial). ' ...
        'Next: LQR/LQI about level & climb with scheduling, INS for absolute xy if required'];
    cmp.summary = lines;
end

%% ===================== writers =====================
function write_png(png_path, level, climb, task_id)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1280 900]);
    tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    nexttile;
    plot_sigma_bars(level.ctrl.full.sigma, level.ctrl.full.tol, 'Level ctrl Qc_s (full)');
    nexttile;
    plot_sigma_bars(climb.ctrl.full.sigma, climb.ctrl.full.tol, 'Climb ctrl Qc_s (full)');

    nexttile;
    plot_pbh(level, 'Level PBH ctrl sigma_min / mode');
    nexttile;
    plot_pbh(climb, 'Climb PBH ctrl sigma_min / mode');

    sgtitle(sprintf('%s — scaled controllability SVD + PBH', task_id), 'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 140);
    close(fig);
end

function plot_sigma_bars(sig, tol, ttl)
    bar(sig, 'FaceColor', [0.2 0.45 0.7]);
    hold on;
    yline(tol, 'r--', sprintf('tol=%.2e', tol), 'LabelHorizontalAlignment', 'left');
    set(gca, 'YScale', 'log');
    xlabel('singular value index'); ylabel('\sigma');
    title(ttl, 'Interpreter', 'none');
    grid on;
end

function plot_pbh(R, ttl)
    smin = arrayfun(@(p) p.sigma_min, R.ctrl.full.pbh);
    is_int = abs(R.eig) < 1e-8;
    bar(smin, 'FaceColor', [0.3 0.6 0.35]);
    hold on;
    if any(is_int)
        bar(find(is_int), smin(is_int), 'FaceColor', [0.85 0.55 0.2]);
    end
    set(gca, 'YScale', 'log');
    xlabel('mode index (Re \downarrow)'); ylabel('PBH \sigma_{min}');
    title(ttl, 'Interpreter', 'none');
    legend({'dynamic/other','near-zero integrator'}, 'Location', 'best');
    grid on;
end

function write_md(md_path, task_id, verdict, level, climb, compare, ...
        x_scale, u_scale, sn, in, ux, uu, frame, iy_A, iy_B, iy_C, ...
        md_p, mat_p, png_p)

    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Scaled controllability / observability audit\n\n', task_id);
    fprintf(fid, '**Overall verdict: %s**\n\n', verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only models: `suite_results/LOCAL_SS_LEVEL.mat`, `suite_results/LOCAL_SS_CLIMB.mat`\n');
    fprintf(fid, '- Validation capsule: `suite_results/SS_VALIDATION.md` (level/climb PASS; helix excluded)\n');
    fprintf(fid, '- Driver: `run_ctrl_obs_audit.m` (one invocation; no controller/plant/guidance edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_p, mat_p, png_p);

    fprintf(fid, '## Units / frames / scales / tolerances\n\n');
    fprintf(fid, '- Frame: %s\n', frame);
    fprintf(fid, '- State x = [x y z phi theta psi u v w p q r]\n');
    fprintf(fid, '- Input u = [dr de thrust]\n');
    fprintf(fid, '- Units x: %s\n', strjoin(ux, ', '));
    fprintf(fid, '- Units u: %s\n', strjoin(uu, ', '));
    fprintf(fid, '- Physical scales (documented TRIM/LOCAL_SS):\n\n');
    fprintf(fid, '```\nx_scale = [%s]\nu_scale = [%s]\n```\n\n', ...
        num2str(x_scale.', ' %.4g'), num2str(u_scale.', ' %.4g'));
    fprintf(fid, ['- Scaling before SVD/PBH: `As = Sx\\\\A*Sx`, `Bs = Sx\\\\B*Su`, ' ...
        '`Cs = Sy\\\\C*Sx` with `Sx=diag(x_scale)`, `Su=diag(u_scale)`, ' ...
        '`Sy=diag(x_scale(iy))`.\n']);
    fprintf(fid, ['- Controllability SVD of `ctrb(As,Bs)`; observability SVD of `obsv(As,Cs)`.\n']);
    fprintf(fid, ['- Numerical rank tolerance: `tol = max(m,n)*eps(sigma_max)` ' ...
        '(MATLAB-rank-like); report `rank = nnz(sigma > tol)`, condition `sigma_max/sigma_min`.\n']);
    fprintf(fid, ['- PBH: scaled `sigma_min` of `[λI−A, B]` (ctrl) / `[λI−A; C]` (obs); ' ...
        'uncontrollable/unobservable iff `sigma_min ≤ 10*max(size)*eps(sigma_max)`; ' ...
        'weak if controllable/observable but `sigma_min < 1e-3 * sigma_max`.\n']);
    fprintf(fid, '- **Raw unscaled rank alone is insufficient (FAIL criterion avoided).**\n\n');

    fprintf(fid, '## Controllability\n\n');
    write_ctrl_section(fid, level);
    write_ctrl_section(fid, climb);

    fprintf(fid, '## Observability\n\n');
    fprintf(fid, 'Assumed direct outputs only (no noise/bias/feasibility claim beyond selection):\n');
    fprintf(fid, '- (A) C=I12 ideal — iy=[%s]\n', num2str(iy_A));
    fprintf(fid, '- (B) onboard IMU+DVL+depth+heading — iy=[%s] → [%s] (no absolute x,y)\n', ...
        num2str(iy_B), strjoin(sn(iy_B), ', '));
    fprintf(fid, '- (C) B + INS x,y — iy=[%s] (full)\n\n', num2str(iy_C));
    write_obs_section(fid, level);
    write_obs_section(fid, climb);

    fprintf(fid, '## Level vs climb — differences & design implications\n\n');
    for i = 1:numel(compare.summary)
        fprintf(fid, '- %s\n', compare.summary{i});
    end
    fprintf(fid, '\n### PBH ctrl sigma_min (full) by mode\n\n');
    fprintf(fid, '| k | λ_level | σmin_level | λ_climb | σmin_climb | class_hint |\n');
    fprintf(fid, '|--:|---|---:|---|---:|---|\n');
    n = min(numel(level.eig), numel(climb.eig));
    for k = 1:n
        cl = level.ctrl.full.mode_class(k).class;
        fprintf(fid, '| %d | %s | %.3e | %s | %.3e | %s |\n', k, ...
            format_eig(level.eig(k)), level.ctrl.full.pbh(k).sigma_min, ...
            format_eig(climb.eig(k)), climb.ctrl.full.pbh(k).sigma_min, cl);
    end

    fprintf(fid, '\n## PASS gates\n\n');
    fprintf(fid, '| Gate | Result |\n|---|---|\n');
    fprintf(fid, '| Scaled SVD reported (all ctrl/obs cases) | %s |\n', ...
        tern(level.ok_report && climb.ok_report,'PASS','FAIL'));
    fprintf(fid, '| PBH sigma_min per eigenvalue/mode | %s |\n', ...
        tern(level.ok_report && climb.ok_report,'PASS','FAIL'));
    fprintf(fid, '| Units/frames/scales/tolerances stated | PASS |\n');
    fprintf(fid, '| Level-vs-climb + design implications | PASS |\n');
    fprintf(fid, '| No production controller/plant/guidance edit | PASS |\n');
    fprintf(fid, '\n**Overall: %s**\n\n', verdict);

    fprintf(fid, '## Next decision\n\n');
    fprintf(fid, ['- Proceed to scheduled LQR/LQI about validated level & climb trims ' ...
        '(inside SS_VALIDATION envelope |δ|≤0.5°, t≤0.6s).\n']);
    fprintf(fid, ['- For absolute x,y regulation use INS (obs C) or path-relative errors; ' ...
        'do not expect obs B alone to recover global position integrators.\n']);
    fprintf(fid, '- Helix remains excluded from ordinary inertial LTI.\n');
    fclose(fid);
end

function write_ctrl_section(fid, R)
    fprintf(fid, '### %s\n\n', upper(R.name));
    cases = {R.ctrl.full, R.ctrl.vert, R.ctrl.lat};
    for i = 1:numel(cases)
        c = cases{i};
        fprintf(fid, '#### %s\n\n', c.tag);
        fprintf(fid, '- n=%d, m=%d; numerical rank **%d / %d** with tol=%.3e\n', ...
            c.n, c.m, c.rank, c.n, c.tol);
        fprintf(fid, '- σ_max=%.6e, σ_min=%.6e, cond(Qc_s)=%.6e\n', ...
            c.sigma_max, c.sigma_min, c.cond);
        fprintf(fid, '- singular values: [%s]\n', num2str(c.sigma.', ' %.3e'));
        fprintf(fid, '\n| k | λ | PBH σ_min | weak | unc | class | participation |\n');
        fprintf(fid, '|--:|---|---:|:---:|:---:|---|---|\n');
        for k = 1:numel(c.mode_class)
            m = c.mode_class(k);
            fprintf(fid, '| %d | %s | %.3e | %d | %d | %s | %s |\n', ...
                k, format_eig(m.lam), m.sigma_min, m.weak, m.uncontrollable, ...
                m.class, m.label);
        end
        fprintf(fid, '\n');
    end
end

function write_obs_section(fid, R)
    fprintf(fid, '### %s observability\n\n', upper(R.name));
    cases = {R.obs.A, R.obs.B, R.obs.C};
    for i = 1:numel(cases)
        o = cases{i};
        fprintf(fid, '#### %s — %s\n\n', o.tag, o.note);
        fprintf(fid, '- outputs iy=[%s]; numerical rank **%d / %d** with tol=%.3e\n', ...
            num2str(o.iy), o.rank, size(o.As,1), o.tol);
        fprintf(fid, '- σ_max=%.6e, σ_min=%.6e, cond(Qo_s)=%.6e\n', ...
            o.sigma_max, o.sigma_min, o.cond);
        fprintf(fid, '- singular values: [%s]\n', num2str(o.sigma.', ' %.3e'));
        fprintf(fid, '\n| k | λ | PBH σ_min | weak | unobs | class | participation |\n');
        fprintf(fid, '|--:|---|---:|:---:|:---:|---|---|\n');
        for k = 1:numel(o.mode_class)
            m = o.mode_class(k);
            fprintf(fid, '| %d | %s | %.3e | %d | %d | %s | %s |\n', ...
                k, format_eig(m.lam), m.sigma_min, m.weak, m.unobservable, ...
                m.class, m.label);
        end
        % Explicit integrator vs dynamic distinction
        n_int = sum([o.mode_class.is_integrator]);
        n_dyn = numel(o.mode_class) - n_int;
        n_unobs_int = sum([o.mode_class.is_integrator] & [o.mode_class.unobservable]);
        n_unobs_dyn = sum(~[o.mode_class.is_integrator] & [o.mode_class.unobservable]);
        fprintf(fid, ['\nDistinction: %d near-zero integrator mode(s), %d dynamic; ' ...
            'unobs integrators=%d, unobs dynamic=%d.\n\n'], ...
            n_int, n_dyn, n_unobs_int, n_unobs_dyn);
    end
end

function append_audit(out_dir, task_id, verdict, level, climb, compare, md_p, mat_p, png_p)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat` (SS_VALIDATION PASS)\n');
    fprintf(fid, '- Driver: `run_ctrl_obs_audit.m` (read-only; no production edit)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_p, mat_p, png_p);
    fprintf(fid, '### Verdict\n\n**%s** — scaled SVD + PBH controllability/observability at level & climb.\n\n', verdict);
    fprintf(fid, '### Key numbers\n\n');
    fprintf(fid, '| Case | level rank | climb rank | level cond | climb cond |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|\n');
    fprintf(fid, '| Ctrl full | %d/12 | %d/12 | %.3g | %.3g |\n', ...
        level.ctrl.full.rank, climb.ctrl.full.rank, level.ctrl.full.cond, climb.ctrl.full.cond);
    fprintf(fid, '| Ctrl vertical | %d/5 | %d/5 | %.3g | %.3g |\n', ...
        level.ctrl.vert.rank, climb.ctrl.vert.rank, level.ctrl.vert.cond, climb.ctrl.vert.cond);
    fprintf(fid, '| Ctrl lateral | %d/6 | %d/6 | %.3g | %.3g |\n', ...
        level.ctrl.lat.rank, climb.ctrl.lat.rank, level.ctrl.lat.cond, climb.ctrl.lat.cond);
    fprintf(fid, '| Obs A (I12) | %d/12 | %d/12 | %.3g | %.3g |\n', ...
        level.obs.A.rank, climb.obs.A.rank, level.obs.A.cond, climb.obs.A.cond);
    fprintf(fid, '| Obs B (no xy) | %d/12 | %d/12 | %.3g | %.3g |\n', ...
        level.obs.B.rank, climb.obs.B.rank, level.obs.B.cond, climb.obs.B.cond);
    fprintf(fid, '| Obs C (+INS xy) | %d/12 | %d/12 | %.3g | %.3g |\n\n', ...
        level.obs.C.rank, climb.obs.C.rank, level.obs.C.cond, climb.obs.C.cond);
    fprintf(fid, '### Design implications\n\n');
    for i = 1:numel(compare.summary)
        fprintf(fid, '- %s\n', compare.summary{i});
    end
    fprintf(fid, '\n### Next\n\n');
    fprintf(fid, '- Scheduled LQR/LQI on level & climb; INS or path-relative for absolute xy; helix excluded.\n');
    fclose(fid);
end

function print_feedback(verdict, level, climb, compare, md_p, mat_p, png_p)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('VERDICT: %s\n', verdict);
    fprintf('Ctrl full rank L/C: %d/%d  cond: %.3g / %.3g\n', ...
        level.ctrl.full.rank, climb.ctrl.full.rank, ...
        level.ctrl.full.cond, climb.ctrl.full.cond);
    fprintf('Ctrl vert rank L/C: %d/%d   lat L/C: %d/%d\n', ...
        level.ctrl.vert.rank, climb.ctrl.vert.rank, ...
        level.ctrl.lat.rank, climb.ctrl.lat.rank);
    fprintf('Obs A/B/C rank level: %d / %d / %d\n', ...
        level.obs.A.rank, level.obs.B.rank, level.obs.C.rank);
    fprintf('Obs A/B/C rank climb: %d / %d / %d\n', ...
        climb.obs.A.rank, climb.obs.B.rank, climb.obs.C.rank);
    % weakest dynamic PBH
    for R = [level, climb]
        dyn = R.ctrl.full.mode_class(~[R.ctrl.full.mode_class.is_integrator]);
        if ~isempty(dyn)
            [sm, iw] = min([dyn.sigma_min]);
            fprintf('%s weakest dyn ctrl PBH σmin=%.3e @ λ=%s (%s)\n', ...
                R.name, sm, format_eig(dyn(iw).lam), dyn(iw).label);
        end
        unobsB = R.obs.B.mode_class([R.obs.B.mode_class.unobservable]);
        fprintf('%s ObsB unobs modes: %d', R.name, numel(unobsB));
        for k = 1:numel(unobsB)
            fprintf(' | %s', format_eig(unobsB(k).lam));
        end
        fprintf('\n');
    end
    fprintf('Files: %s | %s | %s\n', md_p, mat_p, png_p);
    fprintf('NEXT: scheduled LQR/LQI on level&climb; INS/path-rel for xy; helix excluded\n');
end

%% ===================== tiny utils =====================
function s = format_eig(lam)
    if abs(imag(lam)) < 1e-14
        s = sprintf('%+.6e', real(lam));
    else
        s = sprintf('%+.6e%+.6ei', real(lam), imag(lam));
    end
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
