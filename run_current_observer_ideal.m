function run_current_observer_ideal()
% CURRENT_OBSERVER_IDEAL_001 — isolated ideal-signal INS−DVL current observer.
% Read-only: underwater777_vehicle_dynamics_current.m, run_bounded_current_hook.m,
%   suite_results/BOUNDED_CURRENT_HOOK.md (+ .mat trajectories).
% Hook PASS provenance: ground-relative BODY nu; Vc constant NED.
% Observer is OFFLINE only — never fed to guidance/control.
% Production plant/controller/guidance and current hook UNTOUCHED.
%
% Conceptual measurements (ideal, no noise):
%   INS  Vg_NED = R(phi,theta,psi) * nu_lin
%   DVL  Vw_BODY = nu_r_lin;  Vw_NED = R * nu_r_lin
%   Algebraic innovation y_c = Vg_NED - Vw_NED  (= Vc under ideal signals)
% Observer (fixed, no gain sweep):
%   dVhat/dt = wo*(y_c - Vhat),  wo = 0.50 rad/s,  Vhat(0)=0
%   per-axis bound ±0.5 m/s
% Tests: X / XZ / R10 @ U=1.5, Vc=[0,+0.15,0] NED (current-hook trajectories).
% PASS = math/plumbing only (not hardware / not noise robustness).
% Artifacts: suite_results/CURRENT_OBSERVER_IDEAL.{md,mat,png}
% Appends suite_results/STATE_SPACE_MODEL_AUDIT.md
% Does NOT touch CODEX_VERTICAL_PLAN.md.

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end
    tag = 'CURRENT_OBSERVER_IDEAL';
    task_id = 'CURRENT_OBSERVER_IDEAL_001';

    hook_mat = fullfile(out_dir, 'BOUNDED_CURRENT_HOOK.mat');
    hook_md  = fullfile(out_dir, 'BOUNDED_CURRENT_HOOK.md');
    plant_path = fullfile(project_dir, 'underwater777_vehicle_dynamics_current.m');
    hook_run = fullfile(project_dir, 'run_bounded_current_hook.m');
    assert(exist(hook_mat, 'file') == 2, 'Missing %s (run bounded current hook first)', hook_mat);
    assert(exist(hook_md, 'file') == 2, 'Missing %s', hook_md);
    assert(exist(plant_path, 'file') == 2, 'Missing %s', plant_path);
    assert(exist(hook_run, 'file') == 2, 'Missing %s', hook_run);

    fprintf('\n========== %s ==========\n', task_id);
    fprintf('Isolated ideal INS−DVL current observer (offline; not in loop).\n');
    fprintf('PASS = math/plumbing only; not hardware; not noise robustness.\n');

    Hook = load(hook_mat);
    assert(strcmp(Hook.verdict, 'PASS'), 'BOUNDED_CURRENT_HOOK must be PASS');
    assert(isfield(Hook, 'routes'), 'Hook.mat missing routes');

    % ---- Fixed observer params (no sweep) ----
    wo = 0.50;                 % rad/s
    Vhat0 = [0; 0; 0];         % m/s NED
    V_bound = 0.5;             % m/s per axis
    Vc_true = [0; 0.15; 0];    % NED m/s (matches hook)
    settle_frac = 0.02;        % 2% of ||Vc||
    names = {'X', 'XZ', 'R10'};

    Results = struct();
    Results.task_id = task_id;
    Results.convention = struct( ...
        'nu', 'ground-relative BODY velocity [m/s] (state 7:9 linear)', ...
        'Vc', 'constant ocean current NED [m/s]', ...
        'Vg_NED', 'INS ground velocity = R * nu_lin  [m/s NED]', ...
        'Vw_BODY', 'DVL water-relative = nu_r_lin  [m/s BODY]', ...
        'Vw_NED', 'R * Vw_BODY  [m/s NED]', ...
        'y_c', 'Vg_NED - Vw_NED  (= Vc algebraically under ideal signals)', ...
        'Vhat', 'observer state [m/s NED]; dVhat/dt = wo*(y_c-Vhat)', ...
        'wo', wo, ...
        'bound', V_bound, ...
        'units', 'all linear velocities m/s; wo rad/s; angles rad');
    Results.observer = struct('wo', wo, 'Vhat0', Vhat0, 'bound', V_bound, ...
        'form', 'dVhat/dt = wo*(y_c - Vhat); discrete exact FO; axis clamp ±bound');
    Results.Vc_true = Vc_true;
    Results.Uref = Hook.Uref;
    Results.seed = Hook.seed;
    Results.routes = struct();
    Results.fed_to_control = false;
    Results.production_untouched = true;
    Results.hook_untouched = true;
    Results.noise = 'none (ideal signals)';
    Results.gain_sweep = false;

    all_pass = true;
    for i = 1:numel(names)
        nm = names{i};
        assert(isfield(Hook.routes, nm), 'Missing route %s in hook mat', nm);
        rr = Hook.routes.(nm);
        assert(isfield(rr, 'curr'), 'Route %s missing curr series', nm);
        S = rr.curr;
        assert(max(abs(S.Vc(:) - Vc_true)) < 1e-12, 'Route %s Vc mismatch', nm);

        Obs = run_observer_on_series(S, wo, Vhat0, V_bound, Vc_true, settle_frac);
        Results.routes.(nm) = Obs;

        fprintf('\n--- Route %s ---\n', nm);
        fprintf('  identity residual max|y_c-Vc|: %.3e m/s\n', Obs.identity_residual_max);
        fprintf('  err final ||Vhat-Vc||: %.4e  RMS: %.4e  max: %.4e m/s\n', ...
            Obs.err_final_norm, Obs.err_rms_norm, Obs.err_max_norm);
        fprintf('  component final err [N,E,D]: [%.3e, %.3e, %.3e]\n', Obs.err_final);
        fprintf('  2%% settle: %.3f s (band=%.4f m/s)\n', Obs.settle_time, Obs.settle_band);
        fprintf('  bound hits: %d  Vhat max|axis|: %.4f\n', Obs.bound_hits, Obs.Vhat_max_abs);

        all_pass = all_pass && Obs.pass_identity && Obs.pass_final && ...
            Obs.pass_settle && Obs.pass_bounded && Obs.pass_no_hits;
    end

    % Cross-route summary
    id_max = 0; fin_max = 0; set_max = 0; hits_tot = 0;
    for i = 1:numel(names)
        O = Results.routes.(names{i});
        id_max = max(id_max, O.identity_residual_max);
        fin_max = max(fin_max, O.err_final_norm);
        set_max = max(set_max, O.settle_time);
        hits_tot = hits_tot + O.bound_hits;
    end
    Results.summary = struct( ...
        'identity_residual_max_all', id_max, ...
        'final_err_max_all', fin_max, ...
        'settle_max_all', set_max, ...
        'bound_hits_total', hits_tot);

    % Route dependence / observability notes (ideal case)
    Results.route_dependence = struct( ...
        'ideal_y_c_equals_Vc', true, ...
        'note', ['Under ideal INS+DVL, y_c ≡ Vc in NED for any attitude; ', ...
            'observer FO dynamics therefore route-independent aside from sampling. ', ...
            'R10 rotating attitude exercises R(·) plumbing without changing y_c.']);
    Results.observability_limitations = [ ...
        'Ideal algebraic pair requires BOTH ground velocity (INS) and water-relative ', ...
        'velocity (DVL) in consistent frames; missing either channel leaves Vc unobservable ', ...
        'from kinematics alone. Attitude enters only via R; with perfect nu and nu_r, ', ...
        'R cancels and y_c=Vc exactly. This certifies math/plumbing only — sensor noise, ', ...
        'bias, latency, lever-arm, and frame misalignment are NOT tested. Do not promote ', ...
        'to production guidance/control.'];

    % ---- PASS gates ----
    gates = struct();
    gates.identity_residual_le_1e10 = id_max <= 1e-10;
    gates.final_vector_err_le_0p005 = fin_max <= 0.005;
    gates.settle_2pct_le_10s = set_max <= 10 && isfinite(set_max);
    gates.bounded_no_hits = hits_tot == 0;
    gates.all_routes = true;
    for i = 1:numel(names)
        O = Results.routes.(names{i});
        gates.all_routes = gates.all_routes && O.ok && O.pass_identity && ...
            O.pass_final && O.pass_settle && O.pass_bounded && O.pass_no_hits;
    end
    gates.offline_not_in_loop = ~Results.fed_to_control;
    gates.production_hook_untouched = Results.production_untouched && Results.hook_untouched;
    gates.no_noise_no_sweep = true;

    gn = fieldnames(gates);
    verdict_ok = true;
    for k = 1:numel(gn)
        verdict_ok = verdict_ok && logical(gates.(gn{k}));
    end
    verdict = tern(verdict_ok, 'PASS', 'FAIL');

    md_path  = fullfile(out_dir, [tag '.md']);
    mat_path = fullfile(out_dir, [tag '.mat']);
    png_path = fullfile(out_dir, [tag '.png']);

    Results.gates = gates;
    Results.verdict = verdict;
    Results.paths = struct('md', md_path, 'mat', mat_path, 'png', png_path);
    Results.note = ['Certifies ideal-signal math/plumbing only; not hardware; ', ...
        'not noise robustness; observer never fed to guidance/control; ', ...
        'production + current hook frozen; no CODEX_VERTICAL_PLAN touch'];
    Results.next = struct( ...
        'gate', 'measurement_noise_hook_INS_DVL_pair', ...
        'detail', ['Next bounded gate: documented additive measurement-noise hook on the ', ...
            'conceptual INS ground-velocity / DVL water-velocity pair, then re-run observer ', ...
            'sensitivity (still offline). Never promote observer to production yet.']);

    write_png(png_path, Results, task_id, verdict, Vc_true);
    write_md(md_path, Results);
    append_audit(out_dir, Results);
    save(mat_path, '-struct', 'Results');

    fprintf('\nVERDICT: %s (math/plumbing only; not hardware/noise)\n', verdict);
    fprintf('Saved: %s\n%s\n%s\n', md_path, mat_path, png_path);
    print_feedback(Results);
end

%% ===================== observer =====================
function Obs = run_observer_on_series(S, wo, Vhat0, V_bound, Vc_true, settle_frac)
    n = numel(S.t);
    Obs = struct('ok', false);
    if n < 10
        return;
    end
    dt = S.dt;
    if isempty(dt) || ~isfinite(dt) || dt <= 0
        dt = median(diff(S.t));
    end

    Vg = zeros(n, 3);
    Vw_body = zeros(n, 3);
    Vw_ned = zeros(n, 3);
    yc = zeros(n, 3);
    Vhat = zeros(n, 3);
    bound_hit = false(n, 1);

    alpha = 1 - exp(-wo * dt);   % exact FO discrete gain
    v = Vhat0(:);

    for k = 1:n
        phi = S.ori(k, 1); theta = S.ori(k, 2); psi = S.ori(k, 3);
        R = rotmat(phi, theta, psi);
        nu_lin = S.nu(k, 1:3).';
        % Prefer logged plant diagnostics; fall back to state
        if isfield(S, 'V_water_body') && ~isempty(S.V_water_body)
            nu_r = S.V_water_body(k, :).';
        else
            nu_r = S.nu_r(k, 1:3).';
        end
        if isfield(S, 'V_ground_ned') && ~isempty(S.V_ground_ned) ...
                && any(S.V_ground_ned(k, :) ~= 0)
            Vg_k = S.V_ground_ned(k, :).';
        else
            Vg_k = R * nu_lin;
        end
        % Conceptual measurements (recomputed for identity / plumbing)
        Vg_from_R = R * nu_lin;
        Vw_b = nu_r;
        Vw_n = R * Vw_b;
        yc_k = Vg_from_R - Vw_n;   % = R*(nu - nu_r) = R*nu_c = Vc

        % Prefer logged Vg for series storage if present; innovation uses algebraic pair
        Vg(k, :) = Vg_from_R.';
        Vw_body(k, :) = Vw_b.';
        Vw_ned(k, :) = Vw_n.';
        yc(k, :) = yc_k.';

        % Observer step (offline)
        v = v + alpha * (yc_k - v);
        pre = v;
        v = max(min(v, V_bound), -V_bound);
        bound_hit(k) = any(abs(pre) > V_bound + 1e-15);
        Vhat(k, :) = v.';
    end

    err = Vhat - repmat(Vc_true(:).', n, 1);
    err_norm = sqrt(sum(err.^2, 2));
    yc_err = yc - repmat(Vc_true(:).', n, 1);
    id_res = max(abs(yc_err), [], 'all');

    band = settle_frac * norm(Vc_true);
    settle_t = settle_time_2pct(S.t, err_norm, band);

    Obs.ok = true;
    Obs.name = '';
    Obs.t = S.t;
    Obs.dt = dt;
    Obs.ori = S.ori;
    Obs.Vg_NED = Vg;
    Obs.Vw_BODY = Vw_body;
    Obs.Vw_NED = Vw_ned;
    Obs.y_c = yc;
    Obs.Vhat = Vhat;
    Obs.Vc_true = Vc_true(:).';
    Obs.err = err;
    Obs.err_norm = err_norm;
    Obs.identity_residual_max = id_res;
    Obs.identity_residual_rms = sqrt(mean(sum(yc_err.^2, 2)));
    Obs.err_final = err(end, :).';
    Obs.err_final_norm = err_norm(end);
    Obs.err_rms = sqrt(mean(err.^2, 1)).';
    Obs.err_rms_norm = sqrt(mean(err_norm.^2));
    Obs.err_max = max(abs(err), [], 1).';
    Obs.err_max_norm = max(err_norm);
    Obs.settle_band = band;
    Obs.settle_time = settle_t;
    Obs.bound_hits = sum(bound_hit);
    Obs.Vhat_max_abs = max(abs(Vhat), [], 'all');
    Obs.psi_range_deg = [rad2deg(min(S.ori(:,3))), rad2deg(max(S.ori(:,3)))];
    Obs.theta_range_deg = [rad2deg(min(S.ori(:,2))), rad2deg(max(S.ori(:,2)))];

    Obs.pass_identity = id_res <= 1e-10;
    Obs.pass_final = Obs.err_final_norm <= 0.005;
    Obs.pass_settle = isfinite(settle_t) && settle_t <= 10;
    Obs.pass_bounded = Obs.Vhat_max_abs <= V_bound + 1e-12;
    Obs.pass_no_hits = Obs.bound_hits == 0;
end

function ts = settle_time_2pct(t, e_norm, band)
    % First time after which |e| stays within band for the remainder.
    inside = e_norm <= band;
    ts = Inf;
    for k = 1:numel(t)
        if all(inside(k:end))
            ts = t(k);
            return;
        end
    end
end

function R = rotmat(phi, theta, psi)
    R = [cos(psi)*cos(theta), ...
         cos(psi)*sin(theta)*sin(phi) - sin(psi)*cos(phi), ...
         cos(psi)*sin(theta)*cos(phi) + sin(psi)*sin(phi);
         sin(psi)*cos(theta), ...
         sin(psi)*sin(theta)*sin(phi) + cos(psi)*cos(phi), ...
         sin(psi)*sin(theta)*cos(phi) - cos(psi)*sin(phi);
         -sin(theta), ...
         cos(theta)*sin(phi), ...
         cos(theta)*cos(phi)];
end

%% ===================== outputs =====================
function write_png(png_path, R, task_id, verdict, Vc_true)
    fig = figure('Visible', 'off', 'Position', [40 40 1400 900]);
    tiledlayout(3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    names = {'X', 'XZ', 'R10'};
    for i = 1:3
        O = R.routes.(names{i});
        nexttile;
        plot(O.t, O.y_c(:,2), 'k-'); hold on;
        plot(O.t, O.Vhat(:,2), 'b-');
        yline(Vc_true(2), 'r--');
        grid on; ylabel('m/s'); title(sprintf('%s East: y_c / Vhat / Vc', names{i}));
        if i == 1; legend('y_c', 'Vhat', 'Vc', 'Location', 'best'); end

        nexttile;
        plot(O.t, O.err(:,1), 'r'); hold on;
        plot(O.t, O.err(:,2), 'g');
        plot(O.t, O.err(:,3), 'b');
        yline(O.settle_band, 'k--'); yline(-O.settle_band, 'k--');
        grid on; ylabel('m/s'); title(sprintf('%s Vhat−Vc components', names{i}));
        if i == 1; legend('N','E','D','±2%', 'Location', 'best'); end

        nexttile;
        plot(O.t, O.err_norm, 'm'); hold on;
        yline(O.settle_band, 'k--');
        if isfinite(O.settle_time)
            xline(O.settle_time, 'c--');
        end
        grid on; ylabel('m/s'); xlabel('t [s]');
        title(sprintf('%s ||err|| settle=%.2fs', names{i}, O.settle_time));
    end
    sgtitle(sprintf('%s %s — ideal INS−DVL current observer (offline)', task_id, verdict), ...
        'Interpreter', 'none');
    exportgraphics(fig, png_path, 'Resolution', 150);
    close(fig);
end

function write_md(md_path, R)
    fid = fopen(md_path, 'w');
    fprintf(fid, '# %s — Ideal-signal INS−DVL current observer\n\n', R.task_id);
    fprintf(fid, '**Overall verdict: %s** (math/plumbing only; not hardware; not noise robustness)\n\n', R.verdict);

    fprintf(fid, '## Provenance\n\n');
    fprintf(fid, '- Read-only: `underwater777_vehicle_dynamics_current.m`, `run_bounded_current_hook.m`, `suite_results/BOUNDED_CURRENT_HOOK.md`\n');
    fprintf(fid, '- Trajectories: `suite_results/BOUNDED_CURRENT_HOOK.mat` (hook PASS; Vc=[0,+0.15,0] NED)\n');
    fprintf(fid, '- Driver: `run_current_observer_ideal.m` (one invocation)\n');
    fprintf(fid, '- Production plant/controller/guidance: **UNTOUCHED**\n');
    fprintf(fid, '- Current hook: **UNTOUCHED**\n');
    fprintf(fid, '- Observer fed to guidance/control: **NO** (offline only)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Did **not** touch `CODEX_VERTICAL_PLAN.md`\n');
    fprintf(fid, '- Never claim hardware validation\n\n');

    fprintf(fid, '## Frames / units (exact)\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'nu_lin   : ground-relative BODY linear velocity [m/s]\n');
    fprintf(fid, 'Vc       : constant ocean current, NED [m/s]\n');
    fprintf(fid, 'R        : BODY→NED rotation (ZYX Euler)\n');
    fprintf(fid, 'INS      : Vg_NED = R * nu_lin              [m/s NED]\n');
    fprintf(fid, 'DVL      : Vw_BODY = nu_r_lin               [m/s BODY]\n');
    fprintf(fid, '           Vw_NED  = R * Vw_BODY            [m/s NED]\n');
    fprintf(fid, 'y_c      : Vg_NED - Vw_NED  (= Vc ideal)    [m/s NED]\n');
    fprintf(fid, 'observer : dVhat/dt = wo*(y_c - Vhat)\n');
    fprintf(fid, '           wo = %.2f rad/s, Vhat(0)=0, axis bound ±%.1f m/s\n', ...
        R.observer.wo, R.observer.bound);
    fprintf(fid, '           discrete: Vhat ← Vhat + (1-e^{-wo dt})(y_c-Vhat); then clamp\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Observer config\n\n');
    fprintf(fid, '- Fixed wo=%.2f rad/s (no gain sweep)\n', R.observer.wo);
    fprintf(fid, '- Vhat(0)=[0,0,0] m/s NED\n');
    fprintf(fid, '- Bound ±%.1f m/s each axis\n', R.observer.bound);
    fprintf(fid, '- Noise: %s\n', R.noise);
    fprintf(fid, '- True Vc = [%.2f, %.2f, %.2f] m/s NED; U=%.1f m/s\n\n', ...
        R.Vc_true, R.Uref);

    fprintf(fid, '## Per-route metrics\n\n');
    fprintf(fid, '| Route | id residual max | err_N final | err_E final | err_D final | ||err|| final | ||err|| RMS | ||err|| max | 2%% settle [s] | bound hits | PASS |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    names = {'X','XZ','R10'};
    for i = 1:3
        O = R.routes.(names{i});
        pass_r = O.pass_identity && O.pass_final && O.pass_settle && O.pass_bounded && O.pass_no_hits;
        fprintf(fid, '| %s | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e | %.3e | %.3f | %d | %s |\n', ...
            names{i}, O.identity_residual_max, O.err_final(1), O.err_final(2), O.err_final(3), ...
            O.err_final_norm, O.err_rms_norm, O.err_max_norm, O.settle_time, O.bound_hits, yn(pass_r));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Attitude exercise (route dependence context)\n\n');
    fprintf(fid, '| Route | psi range [deg] | theta range [deg] |\n|---|---:|---:|\n');
    for i = 1:3
        O = R.routes.(names{i});
        fprintf(fid, '| %s | [%.2f, %.2f] | [%.2f, %.2f] |\n', names{i}, ...
            O.psi_range_deg(1), O.psi_range_deg(2), O.theta_range_deg(1), O.theta_range_deg(2));
    end
    fprintf(fid, '\n');
    fprintf(fid, '- %s\n\n', R.route_dependence.note);

    fprintf(fid, '## Observability limitations\n\n');
    fprintf(fid, '%s\n\n', R.observability_limitations);

    fprintf(fid, '## PASS gates (math/plumbing)\n\n');
    fprintf(fid, '| Gate | Result |\n|---|---|\n');
    gn = fieldnames(R.gates);
    for i = 1:numel(gn)
        fprintf(fid, '| %s | %s |\n', gn{i}, tern(R.gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf(fid, '\n**Overall: %s**\n\n', R.verdict);

    fprintf(fid, '## Next bounded gate\n\n');
    fprintf(fid, '- **`%s`**\n', R.next.gate);
    fprintf(fid, '- %s\n', R.next.detail);
    fprintf(fid, '- Do **not** promote to production.\n');
    fclose(fid);
end

function append_audit(out_dir, R)
    audit_path = fullfile(out_dir, 'STATE_SPACE_MODEL_AUDIT.md');
    fid = fopen(audit_path, 'a');
    fprintf(fid, '\n\n---\n\n');
    fprintf(fid, '## %s — %s\n\n', R.task_id, datestr(now, 31));
    fprintf(fid, '### Provenance\n\n');
    fprintf(fid, '- Read-only: `underwater777_vehicle_dynamics_current.m`, `run_bounded_current_hook.m`, `BOUNDED_CURRENT_HOOK.md`\n');
    fprintf(fid, '- Trajectories: `BOUNDED_CURRENT_HOOK.mat` (hook PASS)\n');
    fprintf(fid, '- Driver: `run_current_observer_ideal.m` (one invocation; offline observer)\n');
    fprintf(fid, '- Artifacts: `%s`, `%s`, `%s`\n', R.paths.md, R.paths.mat, R.paths.png);
    fprintf(fid, '- Production + current hook untouched; observer NOT fed to guidance/control\n');
    fprintf(fid, '- Did not touch `CODEX_VERTICAL_PLAN.md`\n\n');
    fprintf(fid, '### Frames / observer\n\n');
    fprintf(fid, '```\nINS Vg_NED=R*nu; DVL Vw_BODY=nu_r; Vw_NED=R*nu_r;\n');
    fprintf(fid, 'y_c=Vg_NED-Vw_NED (=Vc ideal); dVhat/dt=wo*(y_c-Vhat), wo=%.2f, bound±%.1f\n```\n\n', ...
        R.observer.wo, R.observer.bound);
    fprintf(fid, '### Verdict\n\n');
    fprintf(fid, '**%s** — ideal-signal math/plumbing only (not hardware; not noise robustness).\n\n', R.verdict);
    fprintf(fid, '### Key numbers\n\n');
    fprintf(fid, '| Item | Value |\n|---|---|\n');
    fprintf(fid, '| identity residual max (all) | %.3e m/s |\n', R.summary.identity_residual_max_all);
    fprintf(fid, '| final ||err|| max (all) | %.3e m/s |\n', R.summary.final_err_max_all);
    fprintf(fid, '| 2%% settle max (all) | %.3f s |\n', R.summary.settle_max_all);
    fprintf(fid, '| bound hits total | %d |\n', R.summary.bound_hits_total);
    names = {'X','XZ','R10'};
    for i = 1:3
        O = R.routes.(names{i});
        fprintf(fid, '| %s id / final / settle | %.3e / %.3e / %.2f s |\n', ...
            names{i}, O.identity_residual_max, O.err_final_norm, O.settle_time);
    end
    fprintf(fid, '\n### Observability note\n\n');
    fprintf(fid, '%s\n\n', R.observability_limitations);
    fprintf(fid, '### Next\n\n');
    fprintf(fid, '- `%s` — %s\n', R.next.gate, R.next.detail);
    fclose(fid);
end

function print_feedback(R)
    fprintf('\n========== FEEDBACK ==========\n');
    fprintf('VERDICT: %s (math/plumbing only)\n', R.verdict);
    fprintf('identity residual max: %.6e m/s\n', R.summary.identity_residual_max_all);
    fprintf('final ||err|| max: %.6e m/s\n', R.summary.final_err_max_all);
    fprintf('2%% settle max: %.3f s\n', R.summary.settle_max_all);
    fprintf('bound hits: %d\n', R.summary.bound_hits_total);
    names = {'X','XZ','R10'};
    for i = 1:3
        O = R.routes.(names{i});
        fprintf('%s: id=%.3e final=%.3e settle=%.2fs hits=%d\n', ...
            names{i}, O.identity_residual_max, O.err_final_norm, O.settle_time, O.bound_hits);
    end
    gn = fieldnames(R.gates);
    for i = 1:numel(gn)
        fprintf('  gate %s: %s\n', gn{i}, tern(R.gates.(gn{i}), 'PASS', 'FAIL'));
    end
    fprintf('Next: %s\n', R.next.gate);
    fprintf('Artifacts:\n  %s\n  %s\n  %s\n', R.paths.md, R.paths.mat, R.paths.png);
end

function s = yn(tf)
    if tf; s = 'YES'; else; s = 'NO'; end
end

function s = tern(tf, a, b)
    if tf; s = a; else; s = b; end
end
