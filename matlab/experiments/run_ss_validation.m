function run_ss_validation()
% SS_VALIDATION_001 — validate level/climb local LTI vs exact nonlinear plant.
% Plant-only perturbation compare; production controller/guidance untouched.
% One MATLAB invocation. Helix excluded.

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'SS_VALIDATION';
    task_id = 'SS_VALIDATION_001';

    clear functions
    init_parameters();

    L = load(fullfile(out_dir, 'LOCAL_SS_LEVEL.mat'));
    C = load(fullfile(out_dir, 'LOCAL_SS_CLIMB.mat'));

    state_names = {'x','y','z','phi','theta','psi','u','v','w','p','q','r'};
    if isfield(L, 'x_scale'); x_scale = L.x_scale(:); else
        x_scale = [10;10;10;1;1;1;1.5;0.3;0.3;0.2;0.2;0.2];
    end

    % Short horizon before open-loop unstable divergence (maxRe≈1.24)
    maxRe = max([max(real(eig(L.A))), max(real(eig(C.A)))]);
    T_end = min(0.60, 0.75 / max(maxRe, 0.5));   % ~0.60 s
    T_pulse = 0.20;
    dt = 0.005;
    t = (0:dt:T_end).';
    amp05 = deg2rad(0.5);
    amp025 = deg2rad(0.25);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Plant: underwater777_vehicle_dynamics (exact)\n');
    fprintf('Horizon T_end=%.3fs  pulse=%.2fs  dt=%.3fs  maxRe=%.4g\n', ...
        T_end, T_pulse, dt, maxRe);
    fprintf('Actuator amp <= 0.5 deg (check also 0.25 deg); IC theta <= 0.5 deg\n');

    cases = { ...
        case_def('level', 'elev_pulse', L, 'de', amp05, [], [7 9 11 5], [9 11], 'elevator +0.5deg pulse'); ...
        case_def('level', 'rudder_pulse', L, 'dr', amp05, [], [8 10 12 4 6], [8 10 12], 'rudder +0.5deg pulse'); ...
        case_def('level', 'theta_ic', L, '', 0, [0;0;0;0;amp05;0;0;0;0;0;0;0], [5 7 9 11], [5 9 11], 'theta +0.5deg IC'); ...
        case_def('climb', 'elev_pulse', C, 'de', amp05, [], [7 9 11 5], [9 11], 'elevator +0.5deg pulse'); ...
        case_def('climb', 'theta_ic', C, '', 0, [0;0;0;0;amp05;0;0;0;0;0;0;0], [5 7 9 11], [5 9 11], 'theta +0.5deg IC'); ...
        };

    results = cell(numel(cases), 1);
    for k = 1:numel(cases)
        c = cases{k};
        fprintf('\n--- [%s / %s] %s ---\n', c.trim, c.channel, c.label);
        r05 = run_one(c, t, T_pulse, x_scale, state_names, 1.0);
        % Amplitude reduction check (same type, 0.25 deg)
        c25 = c;
        if strcmp(c.kind, 'pulse')
            c25.amp = amp025;
            c25.label = strrep(c.label, '0.5', '0.25');
        else
            c25.dx0 = c.dx0 * (0.25/0.5);
            c25.label = strrep(c.label, '0.5', '0.25');
        end
        r25 = run_one(c25, t, T_pulse, x_scale, state_names, 0.25/0.5);
        r05.amp_check = compare_amp(r05, r25);
        r05.r25 = r25;
        r05.pass = gate_pass(r05);
        r05.T_valid = validity_horizon(r05, x_scale);
        results{k} = r05;
        print_case(r05, state_names);
    end

    % Model-level rollup
    level_ix = find(cellfun(@(r) strcmp(r.trim,'level'), results));
    climb_ix = find(cellfun(@(r) strcmp(r.trim,'climb'), results));
    level_pass = all(cellfun(@(i) results{i}.pass.overall, num2cell(level_ix)));
    climb_pass = all(cellfun(@(i) results{i}.pass.overall, num2cell(climb_ix)));

    png_path = fullfile(out_dir, [tag '.png']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    md_path  = fullfile(out_dir, [tag '.md']);

    write_png(png_path, results, state_names, task_id, T_end);
    write_md(md_path, task_id, results, level_pass, climb_pass, ...
        T_end, T_pulse, dt, maxRe, x_scale, state_names, png_path, mat_path, L, C);
    append_audit(out_dir, results, level_pass, climb_pass, T_end, maxRe, ...
        md_path, mat_path, png_path);

    S = struct();
    S.task_id = task_id;
    S.T_end = T_end; S.T_pulse = T_pulse; S.dt = dt; S.t = t;
    S.maxRe = maxRe; S.x_scale = x_scale; S.state_names = state_names;
    S.results = results;
    S.level_pass = level_pass; S.climb_pass = climb_pass;
    S.verdict_level = ternary(level_pass,'PASS','FAIL');
    S.verdict_climb = ternary(climb_pass,'PASS','FAIL');
    S.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    S.plant = 'underwater777_vehicle_dynamics';
    S.note = 'Perturbation validate: delta_x=x_pert-x_nom vs LTI; helix excluded';
    save(mat_path, '-struct', 'S');

    fprintf('\nSaved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    fprintf('FEEDBACK: LEVEL=%s  CLIMB=%s\n', S.verdict_level, S.verdict_climb);
    for k = 1:numel(results)
        r = results{k};
        fprintf('  %s/%s: %s  focus_nrmse_rel=%.3f  corr_min=%.3f  T_valid=%.3fs\n', ...
            r.trim, r.channel, ternary(r.pass.overall,'PASS','FAIL'), ...
            r.metrics.focus_nrmse_rel_max, r.metrics.corr_min_var, r.T_valid);
    end
end

%% ===================== case / sim =====================

function c = case_def(trim, channel, M, inp, amp, dx0, focus, dyn_focus, label)
    c = struct();
    c.trim = trim; c.channel = channel; c.label = label;
    c.A = M.A; c.B = M.B; c.x0 = M.x0(:); c.u0 = M.u0(:);
    c.amp = amp;
    if isempty(dx0); c.dx0 = zeros(12,1); else; c.dx0 = dx0(:); end
    c.focus = focus(:)';           % report / peak states
    c.dyn_focus = dyn_focus(:)';   % gate on these dynamic states
    if strcmp(inp, 'de')
        c.kind = 'pulse'; c.iu = 2;
    elseif strcmp(inp, 'dr')
        c.kind = 'pulse'; c.iu = 1;
    else
        c.kind = 'ic'; c.iu = 0;
    end
end

function r = run_one(c, t, T_pulse, x_scale, state_names, amp_scale) %#ok<INUSD>
    x0 = c.x0; u0 = c.u0; A = c.A; B = c.B;
    n = numel(t);
    du_sched = zeros(n, 3);
    if strcmp(c.kind, 'pulse')
        du_sched(t <= T_pulse, c.iu) = c.amp;
    end

    % Nominal + perturbed nonlinear (fixed-step RK4 for identical grids)
    Xn = zeros(n, 12); Xp = zeros(n, 12);
    Xn(1,:) = x0.'; Xp(1,:) = (x0 + c.dx0).';
    for k = 1:n-1
        dt = t(k+1) - t(k);
        un = u_struct(u0);
        up = u_struct(u0 + du_sched(k,:).');
        Xn(k+1,:) = rk4_step(@(tt,g) underwater777_vehicle_dynamics(tt,g,un), t(k), Xn(k,:).', dt).';
        Xp(k+1,:) = rk4_step(@(tt,g) underwater777_vehicle_dynamics(tt,g,up), t(k), Xp(k,:).', dt).';
    end
    dx_nl = Xp - Xn;

    % LTI perturbation: δẋ = A δx + B δu
    dx_lin = zeros(n, 12);
    dx_lin(1,:) = c.dx0.';
    for k = 1:n-1
        dt = t(k+1) - t(k);
        du = du_sched(k,:).';
        dx_lin(k+1,:) = rk4_step(@(tt,z) A*z + B*du, t(k), dx_lin(k,:).', dt).';
    end

    % Metrics
    m = compute_metrics(t, dx_nl, dx_lin, du_sched, c, x_scale, A, B, state_names);
    r = c;
    r.t = t; r.dx_nl = dx_nl; r.dx_lin = dx_lin; r.du = du_sched;
    r.Xn = Xn; r.Xp = Xp;
    r.metrics = m;
    r.state_names = state_names;
    r.amp_deg = rad2deg(max(abs(c.amp), max(abs(c.dx0(5)))));
end

function u = u_struct(uv)
    u = struct('delta_r', uv(1), 'delta_e', uv(2), 'thrust', uv(3));
end

function x1 = rk4_step(f, t, x, dt)
    k1 = f(t, x);
    k2 = f(t+0.5*dt, x+0.5*dt*k1);
    k3 = f(t+0.5*dt, x+0.5*dt*k2);
    k4 = f(t+dt, x+dt*k3);
    x1 = x + (dt/6)*(k1+2*k2+2*k3+k4);
end

%% ===================== metrics / gates =====================

function m = compute_metrics(t, dx_nl, dx_lin, du, c, x_scale, A, B, state_names)
    n = size(dx_nl, 1);
    err = dx_nl - dx_lin;
    m = struct();
    m.rmse = zeros(12,1);
    m.nrmse_scale = zeros(12,1);   % rms(err)/scale
    m.nrmse_rel = zeros(12,1);     % rms(err)/rms(nl)
    m.max_abs_err_n = zeros(12,1); % max|err|/scale
    m.corr = nan(12,1);
    m.near_zero = false(12,1);
    m.energy_n = zeros(12,1);
    nz_floor = 1e-4;  % scale-normalized energy floor

    for i = 1:12
        e = err(:,i); yn = dx_nl(:,i); yl = dx_lin(:,i);
        m.rmse(i) = sqrt(mean(e.^2));
        m.nrmse_scale(i) = m.rmse(i) / max(x_scale(i), eps);
        m.energy_n(i) = sqrt(mean((yn / x_scale(i)).^2));
        m.near_zero(i) = m.energy_n(i) < nz_floor;
        denom = max(sqrt(mean(yn.^2)), 0.05 * x_scale(i));
        m.nrmse_rel(i) = m.rmse(i) / denom;
        m.max_abs_err_n(i) = max(abs(e)) / max(x_scale(i), eps);
        if ~m.near_zero(i) && std(yn) > 1e-12 * x_scale(i)
            cc = corrcoef(yn, yl);
            m.corr(i) = cc(1,2);
        else
            m.corr(i) = NaN;  % near-zero / no variance
        end
    end

    % Initial derivative signs (t=0+)
    dt0 = t(2) - t(1);
    dnl0 = (dx_nl(2,:) - dx_nl(1,:)).' / dt0;
    dli0 = (dx_lin(2,:) - dx_lin(1,:)).' / dt0;
    % Analytic LTI initial: A*dx0 + B*du(0)
    du0 = du(1,:).';
    dli0_an = A * dx_nl(1,:).' + B * du0;  % dx_nl(1)=dx0 for IC; 0 for pulse
    % Prefer finite-diff on lin traj for consistency
    m.dnl0 = dnl0; m.dli0 = dli0; m.dli0_an = dli0_an;

    m.sign_agree = false(12,1);
    m.sign_note = cell(12,1);
    for i = 1:12
        a = dnl0(i); b = dli0(i);
        if m.near_zero(i) && abs(a) < 1e-6 * x_scale(i) && abs(b) < 1e-6 * x_scale(i)
            m.sign_agree(i) = true;
            m.sign_note{i} = 'near-zero';
        elseif abs(a) < 1e-8 * x_scale(i) && abs(b) < 1e-8 * x_scale(i)
            m.sign_agree(i) = true;
            m.sign_note{i} = 'both~0';
        else
            m.sign_agree(i) = sign_nz(a) == sign_nz(b);
            m.sign_note{i} = ternary(m.sign_agree(i), 'agree', 'DISAGREE');
        end
    end

    % Control-effect initial sign: B(:,iu)*amp vs NL d(dyn)/dt for pulse
    m.ctrl_sign_ok = true;
    m.ctrl_sign_detail = 'n/a (IC)';
    if strcmp(c.kind, 'pulse') && c.iu > 0
        bcol = B(:, c.iu) * c.amp;
        okc = true; bits = {};
        for ii = 1:numel(c.dyn_focus)
            i = c.dyn_focus(ii);
            if abs(bcol(i)) < 1e-10; continue; end
            ag = sign_nz(bcol(i)) == sign_nz(dnl0(i));
            okc = okc && ag;
            bits{end+1} = sprintf('%s:B=%+.2e nl=%+.2e %s', ...
                state_names{i}, bcol(i), dnl0(i), ternary(ag,'OK','BAD')); %#ok<AGROW>
        end
        m.ctrl_sign_ok = okc;
        m.ctrl_sign_detail = strjoin(bits, '; ');
    end

    % Peak sign/time for focus states
    m.peak = struct('ix', c.focus, 't_nl', [], 't_lin', [], 'v_nl', [], 'v_lin', [], 'sign_ok', []);
    for ii = 1:numel(c.focus)
        i = c.focus(ii);
        [m.peak.v_nl(ii), k1] = max(abs(dx_nl(:,i)));
        [m.peak.v_lin(ii), k2] = max(abs(dx_lin(:,i)));
        m.peak.t_nl(ii) = t(k1); m.peak.t_lin(ii) = t(k2);
        sn = sign_nz(dx_nl(k1,i)); sl = sign_nz(dx_lin(k2,i));
        if m.near_zero(i)
            m.peak.sign_ok(ii) = true;
        else
            m.peak.sign_ok(ii) = (sn == sl);
        end
    end

    % Aggregate over dyn_focus (non-near-zero)
    df = c.dyn_focus;
    active = df(~m.near_zero(df));
    if isempty(active)
        m.focus_nrmse_rel_max = 0;
        m.corr_min_var = 1;
        m.sign_dyn_ok = true;
        m.peak_dyn_ok = true;
        m.all_near_zero = true;
    else
        m.focus_nrmse_rel_max = max(m.nrmse_rel(active));
        cc = m.corr(active);
        m.corr_min_var = min(cc(~isnan(cc)));
        if isempty(m.corr_min_var); m.corr_min_var = 1; end
        m.sign_dyn_ok = all(m.sign_agree(active));
        pk_ix = ismember(c.focus(:), active);
        m.peak_dyn_ok = all(m.peak.sign_ok(pk_ix));
        m.all_near_zero = false;
    end
    m.active_dyn = active;
end

function s = sign_nz(v)
    if abs(v) < 1e-14; s = 0; else; s = sign(v); end
end

function ac = compare_amp(r05, r25)
    % Normalized error should improve or not worsen at smaller amp
    ac = struct();
    ac.nrmse05 = r05.metrics.focus_nrmse_rel_max;
    ac.nrmse25 = r25.metrics.focus_nrmse_rel_max;
    % Allow tiny numerical noise (~2% relative / 0.005 abs)
    ac.ok = (ac.nrmse25 <= ac.nrmse05 * 1.02 + 0.005);
    ac.delta = ac.nrmse25 - ac.nrmse05;
end

function p = gate_pass(r)
    m = r.metrics; ac = r.amp_check;
    p = struct();
    p.nrmse_ok = (m.focus_nrmse_rel_max <= 0.20) || m.all_near_zero;
    if isnan(m.corr_min_var)
        p.corr_ok = true;
    else
        p.corr_ok = (m.corr_min_var >= 0.95) || m.all_near_zero;
    end
    p.sign_ok = m.sign_dyn_ok && m.ctrl_sign_ok;
    p.peak_ok = m.peak_dyn_ok;
    p.amp_ok = ac.ok;
    p.overall = p.nrmse_ok && p.corr_ok && p.sign_ok && p.amp_ok;
    reasons = {};
    if ~p.nrmse_ok; reasons{end+1} = sprintf('nrmse_rel=%.3f>0.20', m.focus_nrmse_rel_max); end
    if ~p.corr_ok; reasons{end+1} = sprintf('corr=%.3f<0.95', m.corr_min_var); end
    if ~p.sign_ok; reasons{end+1} = 'initial/control sign disagree'; end
    if ~p.amp_ok; reasons{end+1} = sprintf('0.25deg nrmse worsened (%.3f->%.3f)', ac.nrmse05, ac.nrmse25); end
    if isempty(reasons); p.why = 'all gates met'; else; p.why = strjoin(reasons, '; '); end
end

function Tv = validity_horizon(r, x_scale)
    % Largest t where running focus nrmse_rel stays <= 0.20
    t = r.t; dx_nl = r.dx_nl; dx_lin = r.dx_lin;
    df = r.dyn_focus;
    Tv = t(1);
    for k = 2:numel(t)
        ok = true;
        for ii = 1:numel(df)
            i = df(ii);
            yn = dx_nl(1:k, i); e = yn - dx_lin(1:k, i);
            en = sqrt(mean((yn / x_scale(i)).^2));
            if en < 1e-4; continue; end
            denom = max(sqrt(mean(yn.^2)), 0.05 * x_scale(i));
            if sqrt(mean(e.^2)) / denom > 0.20
                ok = false; break;
            end
        end
        if ok; Tv = t(k); else; break; end
    end
end

function print_case(r, state_names)
    m = r.metrics; p = r.pass;
    fprintf('  verdict=%s  why: %s\n', ternary(p.overall,'PASS','FAIL'), p.why);
    fprintf('  focus dyn:');
    for i = r.dyn_focus(:).'
        fprintf(' %s[nrmse_rel=%.3f scale=%.3g corr=%s nz=%d]', ...
            state_names{i}, m.nrmse_rel(i), m.nrmse_scale(i), ...
            nanstr(m.corr(i)), m.near_zero(i));
    end
    fprintf('\n  ctrl_sign: %s | amp_check 0.5->0.25 nrmse %.3f->%.3f (%s)\n', ...
        m.ctrl_sign_detail, r.amp_check.nrmse05, r.amp_check.nrmse25, ...
        ternary(r.amp_check.ok,'OK','WORSE'));
    fprintf('  T_valid=%.3fs\n', r.T_valid);
end

function s = nanstr(v)
    if isnan(v); s = 'n/a'; else; s = sprintf('%.3f', v); end
end

function s = ternary(c, a, b)
    if c; s = a; else; s = b; end
end

%% ===================== artifacts =====================

function write_png(png_path, results, state_names, task_id, T_end)
    n = numel(results);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 900]);
    for k = 1:n
        r = results{k};
        % Pick up to 3 dyn_focus states
        ix = r.dyn_focus(:).';
        if numel(ix) > 3; ix = ix(1:3); end
        for j = 1:numel(ix)
            subplot(n, 3, (k-1)*3 + j);
            i = ix(j);
            plot(r.t, r.dx_nl(:,i), 'b-', 'LineWidth', 1.2); hold on;
            plot(r.t, r.dx_lin(:,i), 'r--', 'LineWidth', 1.1);
            grid on;
            title(sprintf('%s/%s: %s (%s)', r.trim, r.channel, state_names{i}, ...
                ternary(r.pass.overall,'PASS','FAIL')), 'Interpreter', 'none');
            if k == n; xlabel('t [s]'); end
            if j == 1; ylabel('\delta x'); end
            if j == 1 && k == 1
                legend({'\delta nl','\delta LTI'}, 'Location', 'best');
            end
            xlim([0 T_end]);
        end
    end
    sgtitle(sprintf('%s — NL vs LTI perturbation overlays', task_id), 'Interpreter', 'none');
    try
        exportgraphics(fig, png_path, 'Resolution', 150);
    catch
        saveas(fig, png_path);
    end
    close(fig);
end

function write_md(md_path, task_id, results, level_pass, climb_pass, ...
        T_end, T_pulse, dt, maxRe, x_scale, state_names, png_path, mat_path, L, C)

    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Local LTI perturbation validation\n\n', task_id);
    fprintf(fid, '**LEVEL model: %s** | **CLIMB model: %s**\n\n', ...
        ternary(level_pass,'PASS','FAIL'), ternary(climb_pass,'PASS','FAIL'));

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Plant RHS (exact): `underwater777_vehicle_dynamics.m`\n');
    fprintf(fid, '- Level A,B: `suite_results/LOCAL_SS_LEVEL.mat` (jac %s)\n', L.verdict);
    fprintf(fid, '- Climb A,B: `suite_results/LOCAL_SS_CLIMB.mat` (jac %s)\n', C.verdict);
    fprintf(fid, '- Method: nominal translating trajectory + perturbed NL; compare `δx=x_pert−x_nom` to LTI `δẋ=Aδx+Bδu` (RK4)\n');
    fprintf(fid, '- Horizons: T_end=%.3fs, T_pulse=%.2fs, dt=%.3fs (maxRe(A)=%.4g; short before OL divergence)\n', ...
        T_end, T_pulse, dt, maxRe);
    fprintf(fid, '- Actuator Δ ≤ 0.5° (also 0.25° amplitude check); helix EXCLUDED\n');
    fprintf(fid, '- Production controller/guidance untouched; driver `run_ss_validation.m` only\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);

    fprintf(fid, '## PASS gates (per channel)\n\n');
    fprintf(fid, '- Directly excited dynamic-state relative RMSE ≤ 20%% (near-zero channels excluded)\n');
    fprintf(fid, '- Correlation ≥ 0.95 where variance exists\n');
    fprintf(fid, '- Initial derivative / control (Bδu) sign agrees on focus dynamics\n');
    fprintf(fid, '- Reducing amplitude 0.5°→0.25° improves or does not worsen focus nrmse_rel\n\n');

    fprintf(fid, '## Channel results\n\n');
    fprintf(fid, '| Trim | Channel | Verdict | focus nrmse_rel | min corr | sign | amp0.25 | T_valid [s] | Why |\n');
    fprintf(fid, '|---|---|:---:|---:|---:|:---:|:---:|---:|---|\n');
    for k = 1:numel(results)
        r = results{k}; m = r.metrics; p = r.pass;
        fprintf(fid, '| %s | %s | **%s** | %.3f | %s | %s | %s | %.3f | %s |\n', ...
            r.trim, r.channel, ternary(p.overall,'PASS','FAIL'), ...
            m.focus_nrmse_rel_max, nanstr(m.corr_min_var), ...
            ternary(p.sign_ok,'OK','FAIL'), ternary(p.amp_ok,'OK','FAIL'), ...
            r.T_valid, p.why);
    end
    fprintf(fid, '\n');

    for k = 1:numel(results)
        r = results{k}; m = r.metrics;
        fprintf(fid, '### %s / %s — %s\n\n', r.trim, r.channel, ternary(r.pass.overall,'PASS','FAIL'));
        fprintf(fid, '%s. Amp=%.2f deg. dyn_focus=[%s]. T_valid=%.3fs.\n\n', ...
            r.label, r.amp_deg, strjoin(state_names(r.dyn_focus), ','), r.T_valid);
        fprintf(fid, 'Ctrl sign: %s\n\n', m.ctrl_sign_detail);
        fprintf(fid, '| State | nrmse_rel | nrmse/scale | max|err|/scale | corr | near0 | d0 sign | peak_nl | t_peak |\n');
        fprintf(fid, '|---|---:|---:|---:|---:|:---:|:---:|---:|---:|\n');
        show = unique([r.dyn_focus(:); r.focus(:)], 'stable');
        for ii = 1:numel(show)
            i = show(ii);
            pk = find(r.focus == i, 1);
            if isempty(pk)
                pkn = NaN; tpk = NaN;
            else
                sgn = sign_nz(r.dx_nl(find(abs(r.dx_nl(:,i))==m.peak.v_nl(pk),1), i));
                pkn = sgn * m.peak.v_nl(pk); tpk = m.peak.t_nl(pk);
            end
            fprintf(fid, '| %s | %.4f | %.4g | %.4g | %s | %d | %s | %.4g | %.3f |\n', ...
                state_names{i}, m.nrmse_rel(i), m.nrmse_scale(i), m.max_abs_err_n(i), ...
                nanstr(m.corr(i)), m.near_zero(i), m.sign_note{i}, pkn, tpk);
        end
        fprintf(fid, '\nAmplitude check: nrmse_rel 0.5°=%.4f → 0.25°=%.4f (%s, Δ=%+.4f)\n\n', ...
            r.amp_check.nrmse05, r.amp_check.nrmse25, ...
            ternary(r.amp_check.ok,'OK','WORSE'), r.amp_check.delta);
    end

    fprintf(fid, '## Validity horizon / envelope\n\n');
    fprintf(fid, '- Simulation window fixed at T_end=%.3fs (unstable OL; maxRe≈%.3f ⇒ e^{σt}≈%.2f at T_end).\n', ...
        T_end, maxRe, exp(maxRe*T_end));
    fprintf(fid, '- Per-channel T_valid = last time running focus relative RMSE ≤ 20%%.\n');
    for k = 1:numel(results)
        r = results{k};
        fprintf(fid, '  - %s/%s: T_valid = **%.3f s** (%s)\n', ...
            r.trim, r.channel, r.T_valid, ternary(r.pass.overall,'within envelope','restricted'));
    end
    Tv_level = min(cellfun(@(r) r.T_valid, results(strcmp(cellfun(@(r)r.trim,results,'uni',0),'level'))));
    Tv_climb = min(cellfun(@(r) r.T_valid, results(strcmp(cellfun(@(r)r.trim,results,'uni',0),'climb'))));
    fprintf(fid, '- **Recommended LTI validity envelope:** level ≥ [0, %.3fs], climb ≥ [0, %.3fs] for |δu|,|δθ| ≤ 0.5°.\n', ...
        Tv_level, Tv_climb);
    fprintf(fid, '- Beyond T_valid or |δ|≫0.5°: restrict/reject local LTI (unstable modes + nonlinear hydro).\n');
    fprintf(fid, '- Helix: still EXCLUDED from ordinary inertial LTI.\n\n');

    fprintf(fid, '## Scales\n\n```\nx_scale = [%s]\n```\n\n', num2str(x_scale.'));

    fprintf(fid, '## Next\n\n');
    if level_pass && climb_pass
        fprintf(fid, '- Both models PASS inside validity envelope → eligible for controllability / LQR about respective trims (with scheduling).\n');
        fprintf(fid, '- Keep |δ| small and horizons ≤ T_valid; do not extrapolate through unstable OL divergence.\n');
    else
        fprintf(fid, '- Restrict failed trim/channel models; do not use for LQR/controllability without repair.\n');
        fprintf(fid, '- Inspect failing channels above; consider shorter T_valid or reduced-order vertical/lateral blocks only.\n');
    end
    fprintf(fid, '- Helix remains non-LTI inertial.\n');
    fclose(fid);
end

function append_audit(out_dir, results, level_pass, climb_pass, T_end, maxRe, md_path, mat_path, png_path)
    audit = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## SS_VALIDATION_001 — %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Plant: `underwater777_vehicle_dynamics.m` (exact)\n');
    fprintf(fid, '- Models: `LOCAL_SS_LEVEL.mat`, `LOCAL_SS_CLIMB.mat`\n');
    fprintf(fid, '- Driver: `run_ss_validation.m` (production untouched)\n');
    fprintf(fid, '- Compare: NL `δx=x_pert−x_nom` vs LTI `δẋ=Aδx+Bδu`\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n\n', md_path, mat_path, png_path);

    fprintf(fid, '### Verdicts\n\n');
    fprintf(fid, '| Trim | Model validity | Notes |\n|------|:--------------:|-------|\n');
    fprintf(fid, '| Level | **%s** | all level channels |\n', ternary(level_pass,'PASS','FAIL/RESTRICT'));
    fprintf(fid, '| Climb | **%s** | all climb channels |\n', ternary(climb_pass,'PASS','FAIL/RESTRICT'));
    fprintf(fid, '| Helix | EXCLUDED | carry-forward |\n\n');

    fprintf(fid, '### Per-channel\n\n');
    fprintf(fid, '| Trim/Channel | PASS | nrmse_rel | corr | T_valid [s] |\n');
    fprintf(fid, '|---|:---:|---:|---:|---:|\n');
    for k = 1:numel(results)
        r = results{k};
        fprintf(fid, '| %s/%s | %s | %.3f | %s | %.3f |\n', ...
            r.trim, r.channel, ternary(r.pass.overall,'PASS','FAIL'), ...
            r.metrics.focus_nrmse_rel_max, nanstr(r.metrics.corr_min_var), r.T_valid);
    end

    Tv_level = min(cellfun(@(r) r.T_valid, results(strcmp(cellfun(@(r)r.trim,results,'uni',0),'level'))));
    Tv_climb = min(cellfun(@(r) r.T_valid, results(strcmp(cellfun(@(r)r.trim,results,'uni',0),'climb'))));
    fprintf(fid, '\n### Validity horizon / envelope\n\n');
    fprintf(fid, '- Sim window T_end=%.3fs (OL maxRe≈%.3f).\n', T_end, maxRe);
    fprintf(fid, '- **Level LTI envelope:** t ∈ [0, %.3fs], |δu|,|δθ| ≤ 0.5°.\n', Tv_level);
    fprintf(fid, '- **Climb LTI envelope:** t ∈ [0, %.3fs], |δu|,|δθ| ≤ 0.5°.\n', Tv_climb);
    fprintf(fid, '- Outside envelope / larger δ: restrict local LTI (unstable modes + nonlinear).\n');
    fprintf(fid, '- Amplitude linearity: 0.25° check required per channel (see SS_VALIDATION.md).\n\n');

    fprintf(fid, '### Next\n\n');
    if level_pass && climb_pass
        fprintf(fid, '- Controllability / LQR may proceed on validated level & climb models inside envelopes; schedule gains (ΔA≈9%%, ΔB≈7%%).\n');
    else
        fprintf(fid, '- Do not open controllability/LQR on failed channels; repair or restrict model use first.\n');
    end
    fprintf(fid, '- Helix remains excluded from ordinary inertial LTI.\n');
    fclose(fid);
end
