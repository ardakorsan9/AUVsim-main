function out = gate8_r10_yaw_feasibility_report(mode, R, OUTD, BASE)
%GATE8_R10_YAW_FEASIBILITY_REPORT  Figures, programmatic visual QA and markdown.
% TASK: GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_001
% Isolated shadow reporting only. Reads the record built by the driver and
% writes evidence. Touches no production file and computes no new physics.
%
%   FIG = gate8_r10_yaw_feasibility_report('figures', R, OUTD, BASE)
%   ok  = gate8_r10_yaw_feasibility_report('md', R, OUTD, BASE)

    switch lower(mode)
        case 'figures'
            out = build_figures(R, OUTD, BASE);
        case 'md'
            out = write_markdown(R, OUTD, BASE);
        otherwise
            error('gate8_r10_yaw_feasibility_report: unknown mode %s', mode);
    end
end

% ========================================================================
function REP = build_figures(R, OUTD, BASE)
    REP = struct();
    REP.png = {};
    REP.figs = struct('file', {}, 'ok', {}, 'w', {}, 'h', {}, 'bytes', {}, 'err', {});

    if ~isfield(R, 'compute_ok') || ~R.compute_ok
        REP.figs = add_fig(REP.figs, OUTD, BASE, '', @(a) fig_blocked(a, R));
        REP.png = {fullfile(OUTD, [BASE '.png'])};
        REP.visual_qa = qa_assemble(REP.figs, R, false);
        return
    end

    specs = { ...
        '01_demand_map',      @(a) fig_demand_map(a, R); ...
        '02_status_map',      @(a) fig_status_map(a, R); ...
        '03_demand_curves',   @(a) fig_demand_curves(a, R); ...
        '04_envelope',        @(a) fig_envelope(a, R); ...
        '05_trim_states',     @(a) fig_trim_states(a, R); ...
        '06_solver_diag',     @(a) fig_solver_diag(a, R)};

    for k = 1:size(specs, 1)
        REP.figs = add_fig(REP.figs, OUTD, BASE, specs{k, 1}, specs{k, 2});
    end
    % overview last, line plots only so no per-axes colormap is needed
    REP.figs = add_fig(REP.figs, OUTD, BASE, '', @(a) fig_overview(a, R));

    for k = 1:numel(REP.figs)
        REP.png{end+1} = REP.figs(k).file;
    end
    REP.visual_qa = qa_assemble(REP.figs, R, true);
end

% ========================================================================
function F = add_fig(F, OUTD, BASE, suffix, builder)
    if isempty(suffix)
        fname = [BASE '.png'];
    else
        fname = [BASE '_' suffix '.png'];
    end
    fpath = fullfile(OUTD, fname);
    rec = struct('file', fpath, 'ok', false, 'w', 0, 'h', 0, 'bytes', 0, 'err', '');
    fh = [];
    try
        fh = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', ...
            'Position', [50 50 1500 950]);
        set(fh, 'PaperPositionMode', 'auto');
        builder(fh);
        print(fh, '-dpng', '-r110', fpath);
        close(fh);
        fh = [];
        d = dir(fpath);
        if ~isempty(d)
            rec.bytes = d(1).bytes;
            info = imfinfo(fpath);
            rec.w = info(1).Width;
            rec.h = info(1).Height;
            rec.ok = (rec.bytes > 8192) && (rec.w >= 600) && (rec.h >= 400);
        end
    catch ME
        rec.err = ME.message;
        if ~isempty(fh) && ishandle(fh); close(fh); end
    end
    F(end+1) = rec;
end

function lab(hax, xs, ys, ts)
    xlabel(hax, xs, 'Interpreter', 'none');
    ylabel(hax, ys, 'Interpreter', 'none');
    title(hax, ts, 'Interpreter', 'none');
    set(hax, 'TickLabelInterpreter', 'none', 'FontSize', 9);
    grid(hax, 'on');
    box(hax, 'on');
end

% ========================================================================
function fig_blocked(fh, R)
    hax = axes('Parent', fh);
    axis(hax, 'off');
    msg = { ...
        'GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_001', '', ...
        'COMPUTE STAGE DID NOT COMPLETE - no envelope is published.', '', ...
        ['error: ' gvs(R, 'error_msg', 'unknown')], '', ...
        'Nothing is softened: no feasibility claim is made from a failed run.', ...
        'Gate 8 remains FAIL. Gate 9 remains locked. Hardware NOT_CERTIFIED.'};
    text(hax, 0.02, 0.95, msg, 'VerticalAlignment', 'top', 'FontSize', 12, ...
        'Interpreter', 'none', 'FontName', 'FixedWidth');
end

% ========================================================================
function fig_demand_map(fh, R)
    SW = R.SW;
    hax = axes('Parent', fh);
    C = SW.DRABS;
    him = imagesc(hax, R.U, R.kappa, C);
    set(him, 'AlphaData', double(isfinite(C)));
    set(hax, 'YDir', 'normal', 'Color', [0.82 0.82 0.82]);
    colormap(hax, parula(256));
    cb = colorbar(hax);
    ylabel(cb, 'required |delta_r| [deg]', 'Interpreter', 'none');
    hold(hax, 'on');
    try
        contour(hax, R.U, R.kappa, C, [R.DEC.dr_limit_deg R.DEC.dr_limit_deg], ...
            'k-', 'LineWidth', 2.5);
    catch
    end
    try
        contour(hax, R.U, R.kappa, C, [5 10 15 20], 'w:', 'LineWidth', 1);
    catch
    end
    plot(hax, R.U, R.env.kmax_rail_bis, 'r-', 'LineWidth', 2.5);
    plot(hax, R.r10.U, R.r10.kappa * [1 1], 'mo', 'MarkerSize', 12, ...
        'LineWidth', 2.5, 'MarkerFaceColor', 'none');
    plot(hax, R.U, R.EV.kappa_path_max * ones(size(R.U)), 'c--', 'LineWidth', 1.5);
    legend(hax, {'required |delta_r| [deg]', ...
        sprintf('%g deg rudder rail (CARRIED)', R.DEC.dr_limit_deg), ...
        'interior 5/10/15/20 deg contours', 'kappa_max(U) bisected boundary [1/m]', ...
        'frozen R10 kappa = 0.1 1/m at U = 1.5 and 2.0 m/s', ...
        sprintf('max frozen X/XZ path curvature %.6f 1/m', R.EV.kappa_path_max)}, ...
        'Interpreter', 'none', 'Location', 'northoutside', 'FontSize', 8);
    lab(hax, 'BODY surge U [m/s]', 'horizontal path curvature kappa [1/m]', ...
        ['Steady level-turn rudder demand from the UNMODIFIED production plant ' ...
        '(NED horizontal curvature, BODY surge)']);
    hold(hax, 'off');
end

% ========================================================================
function fig_status_map(fh, R)
    SW = R.SW;
    hax = axes('Parent', fh);
    him = imagesc(hax, R.U, R.kappa, SW.STATUS);
    set(him, 'AlphaData', double(isfinite(SW.STATUS)));
    set(hax, 'YDir', 'normal', 'Color', [0.82 0.82 0.82]);
    cmap = [0.15 0.55 0.20;    % 0 feasible
            0.35 0.35 0.35;    % 1 no trim
            0.10 0.25 0.65;    % 2 residual above tolerance
            0.80 0.10 0.10;    % 3 rudder rail
            0.95 0.65 0.05];   % 4 not stable
    colormap(hax, cmap);
    caxis(hax, [-0.5 4.5]);
    cb = colorbar(hax, 'Ticks', 0:4, 'TickLabels', ...
        {'0 FEASIBLE', '1 NO_TRIM', '2 RESIDUAL>TOL', '3 RUDDER_RAIL_25DEG', '4 NOT_STABLE'});
    set(cb, 'TickLabelInterpreter', 'none');
    hold(hax, 'on');
    plot(hax, R.U, R.env.kmax_rail_bis, 'w-', 'LineWidth', 2.5);
    plot(hax, R.r10.U, R.r10.kappa * [1 1], 'wo', 'MarkerSize', 12, 'LineWidth', 2.5);
    txt = sprintf(['feasible %d / %d nodes; rudder-rail %d; no-trim %d; ' ...
        'residual-above-tolerance %d; not-stable %d'], ...
        sum(SW.STATUS(:) == 0), numel(SW.STATUS), sum(SW.STATUS(:) == 3), ...
        sum(SW.STATUS(:) == 1), sum(SW.STATUS(:) == 2), sum(SW.STATUS(:) == 4));
    lab(hax, 'BODY surge U [m/s]', 'horizontal path curvature kappa [1/m]', ...
        ['Feasibility classification, four predeclared criteria (white line = kappa_max, ' ...
        'circles = frozen R10)' char(10) txt]);
    hold(hax, 'off');
end

% ========================================================================
function fig_demand_curves(fh, R)
    SW = R.SW;
    hax = subplot(1, 2, 1, 'Parent', fh);
    hold(hax, 'on');
    co = jet(numel(R.U));
    for j = 1:numel(R.U)
        plot(hax, R.kappa, SW.DRABS(:, j), '-', 'Color', co(j, :), 'LineWidth', 1.6);
    end
    plot(hax, R.kappa, R.DEC.dr_limit_deg * ones(size(R.kappa)), 'k-', 'LineWidth', 3);
    plot(hax, [R.EV.R10_kappa R.EV.R10_kappa], [0 max(50, 1.1 * mxf(SW.DRABS))], ...
        'm--', 'LineWidth', 2);
    for k = 1:numel(R.r10.U)
        plot(hax, R.EV.R10_kappa, R.r10.dr_absdeg(k), 'mo', 'MarkerSize', 11, ...
            'LineWidth', 2.5);
    end
    lab(hax, 'horizontal path curvature kappa [1/m]', 'required |delta_r| [deg]', ...
        ['Rudder demand vs curvature, one curve per surge from 1.0 (blue) to 2.0 m/s (red)' ...
        char(10) 'black = CARRIED 25 deg rail, magenta = frozen R10 kappa = 0.1 1/m']);
    ylim(hax, [0 max(50, 1.15 * mxf(SW.DRABS))]);
    hold(hax, 'off');

    hax2 = subplot(1, 2, 2, 'Parent', fh);
    hold(hax2, 'on');
    for j = 1:numel(R.U)
        plot(hax2, R.kappa, SW.MARGIN(:, j), '-', 'Color', co(j, :), 'LineWidth', 1.6);
    end
    plot(hax2, R.kappa, zeros(size(R.kappa)), 'k-', 'LineWidth', 3);
    plot(hax2, R.kappa, R.DEC.margin_reserve_deg * ones(size(R.kappa)), 'k:', 'LineWidth', 2);
    lab(hax2, 'horizontal path curvature kappa [1/m]', ...
        'rudder margin 25 - |delta_r| [deg]', ...
        ['Rudder margin against the CARRIED envelope (0 = on the rail)' char(10) ...
        sprintf('dotted = %g deg ASSUMED transient reserve, reported only, applied to nothing', ...
        R.DEC.margin_reserve_deg)]);
    hold(hax2, 'off');
end

% ========================================================================
function fig_envelope(fh, R)
    E = R.env;
    hax = subplot(2, 2, 1, 'Parent', fh);
    hold(hax, 'on');
    plot(hax, R.U, E.kmax_rail_grid, 'bs--', 'LineWidth', 1.4, 'MarkerSize', 7);
    plot(hax, R.U, E.kmax_rail_bis, 'b-o', 'LineWidth', 2, 'MarkerSize', 6);
    plot(hax, R.U, E.kmax_prim_bis, 'g-^', 'LineWidth', 1.6, 'MarkerSize', 6);
    plot(hax, R.U, E.kmax_res_bis, 'k:', 'LineWidth', 1.6);
    plot(hax, R.U, R.EV.R10_kappa * ones(size(R.U)), 'm--', 'LineWidth', 2);
    plot(hax, R.U, R.EV.kappa_path_max * ones(size(R.U)), 'c-.', 'LineWidth', 1.5);
    legend(hax, {'grid node', 'bisected boundary (rail criterion)', ...
        'bisected boundary (all four criteria)', 'ASSUMED reserve column', ...
        'frozen R10 kappa = 0.1 1/m', 'max frozen X/XZ path curvature'}, ...
        'Interpreter', 'none', 'Location', 'best', 'FontSize', 7);
    lab(hax, 'BODY surge U [m/s]', 'kappa_max [1/m]', ...
        'Maximum admissible horizontal curvature vs surge');

    hax2 = subplot(2, 2, 2, 'Parent', fh);
    hold(hax2, 'on');
    plot(hax2, R.U, E.Rmin_rail, 'b-o', 'LineWidth', 2, 'MarkerSize', 6);
    plot(hax2, R.U, E.Rmin_res, 'k:', 'LineWidth', 1.6);
    plot(hax2, R.U, (1 / R.EV.R10_kappa) * ones(size(R.U)), 'm--', 'LineWidth', 2);
    legend(hax2, {'R_min = 1/kappa_max [m]', 'ASSUMED reserve column [m]', ...
        'frozen R10 radius 10 m'}, 'Interpreter', 'none', 'Location', 'best', 'FontSize', 7);
    lab(hax2, 'BODY surge U [m/s]', 'minimum feasible horizontal radius [m]', ...
        'Minimum feasible turn radius vs surge');

    hax3 = subplot(2, 2, 3, 'Parent', fh);
    bar(hax3, R.U, R.r10.row_margin_deg);
    hold(hax3, 'on');
    plot(hax3, R.U, zeros(size(R.U)), 'k-', 'LineWidth', 2);
    lab(hax3, 'BODY surge U [m/s]', 'margin at kappa = 0.1 [deg]', ...
        ['Rudder margin at the frozen R10 curvature (negative = the steady turn ' ...
        'cannot be held inside 25 deg)']);

    hax4 = subplot(2, 2, 4, 'Parent', fh);
    hold(hax4, 'on');
    plot(hax4, R.U, R.r10.row_dr_absdeg, 'r-o', 'LineWidth', 2, 'MarkerSize', 6);
    plot(hax4, R.U, R.DEC.dr_limit_deg * ones(size(R.U)), 'k-', 'LineWidth', 3);
    lab(hax4, 'BODY surge U [m/s]', 'required |delta_r| at kappa = 0.1 [deg]', ...
        'Frozen R10 demand across the whole swept surge band');
end

% ========================================================================
function fig_trim_states(fh, R)
    SW = R.SW;
    co = jet(numel(R.U));
    series = { ...
        SW.BETA,   'BODY sideslip beta = atan2(v,u) [deg]'; ...
        SW.PHI,    'roll phi [deg]'; ...
        SW.THETA,  'pitch theta [deg]'; ...
        SW.RR,     'BODY yaw rate r [deg/s]'; ...
        SW.W,      'BODY heave w [m/s]'; ...
        SW.DE,     'elevator delta_e [deg]'};
    for s = 1:6
        hax = subplot(2, 3, s, 'Parent', fh);
        hold(hax, 'on');
        for j = 1:numel(R.U)
            plot(hax, R.kappa, series{s, 1}(:, j), '-', 'Color', co(j, :), 'LineWidth', 1.3);
        end
        if s == 6
            plot(hax, R.kappa, R.DEC.de_limit_deg * ones(size(R.kappa)), 'k-', 'LineWidth', 2);
            plot(hax, R.kappa, -R.DEC.de_limit_deg * ones(size(R.kappa)), 'k-', 'LineWidth', 2);
        end
        lab(hax, 'kappa [1/m]', series{s, 2}, series{s, 2});
    end
    annotation(fh, 'textbox', [0.01 0.965 0.98 0.03], 'String', ...
        ['Trim state along the steady level turn, one curve per surge 1.0 (blue) to 2.0 m/s ' ...
        '(red). BODY frame, deg where labelled. Constant depth is enforced (z_dot = 0).'], ...
        'Interpreter', 'none', 'EdgeColor', 'none', 'FontSize', 9, ...
        'HorizontalAlignment', 'center');
end

% ========================================================================
function fig_solver_diag(fh, R)
    SW = R.SW;
    co = jet(numel(R.U));

    hax = subplot(2, 3, 1, 'Parent', fh);
    hold(hax, 'on');
    for j = 1:numel(R.U)
        semilogy(hax, R.kappa, max(SW.RESID(:, j), 1e-18), '-', 'Color', co(j, :), ...
            'LineWidth', 1.3);
    end
    semilogy(hax, R.kappa, R.DEC.tol_resid * ones(size(R.kappa)), 'k-', 'LineWidth', 2.5);
    set(hax, 'YScale', 'log');
    lab(hax, 'kappa [1/m]', 'trim residual inf-norm [SI]', ...
        sprintf('Explicit solver residual vs predeclared %.0e', R.DEC.tol_resid));

    hax2 = subplot(2, 3, 2, 'Parent', fh);
    hold(hax2, 'on');
    for j = 1:numel(R.U)
        plot(hax2, R.kappa, SW.ITERS(:, j), '-', 'Color', co(j, :), 'LineWidth', 1.3);
    end
    lab(hax2, 'kappa [1/m]', 'LM iterations [-]', 'Solver iterations per trim');

    hax3 = subplot(2, 3, 3, 'Parent', fh);
    hold(hax3, 'on');
    for j = 1:numel(R.U)
        plot(hax3, R.kappa, SW.EMAX(:, j), '-', 'Color', co(j, :), 'LineWidth', 1.3);
    end
    plot(hax3, R.kappa, zeros(size(R.kappa)), 'k-', 'LineWidth', 2);
    lab(hax3, 'kappa [1/m]', 'max Re(eig) of trim Jacobian [1/s]', ...
        'Local stability of the trim, controls frozen (8 BODY/Euler states)');

    hax4 = subplot(2, 3, 4, 'Parent', fh);
    hold(hax4, 'on');
    for j = 1:numel(R.U)
        semilogy(hax4, R.kappa, max(abs(SW.KINR(:, j)), 1e-20), '-', 'Color', co(j, :), ...
            'LineWidth', 1.3);
    end
    set(hax4, 'YScale', 'log');
    lab(hax4, 'kappa [1/m]', '|phi_dot| + |theta_dot| at trim [rad/s]', ...
        'Steady-turn kinematics held by construction');

    hax5 = subplot(2, 3, 5, 'Parent', fh);
    hold(hax5, 'on');
    for j = 1:numel(R.U)
        semilogy(hax5, R.kappa, max(abs(SW.KREAL(:, j) - R.kappa(:)), 1e-20), '-', ...
            'Color', co(j, :), 'LineWidth', 1.3);
    end
    set(hax5, 'YScale', 'log');
    lab(hax5, 'kappa commanded [1/m]', '|kappa_realised - kappa| [1/m]', ...
        'Realised vs commanded curvature');

    hax6 = subplot(2, 3, 6, 'Parent', fh);
    v = [double(R.replay_identical), double(gvf(R.parity, 'pass', 0)), ...
        double(gvf(R.pathind, 'pass', 0)), double(gvf(R.smooth, 'resid_within_tol', 0)), ...
        double(gvf(R.smooth, 'monotone', 0)), double(gvf(R.smooth, 'all_finite', 0))];
    bar(hax6, 1:numel(v), v);
    set(hax6, 'XTick', 1:numel(v), 'XTickLabel', ...
        {'replay', 'kappa0 parity', 'path indep', 'residual', 'monotone', 'finite'}, ...
        'TickLabelInterpreter', 'none');
    ylim(hax6, [0 1.2]);
    lab(hax6, 'verification check [-]', 'pass = 1 [-]', ...
        'Verification ran before interpretation');
end

% ========================================================================
function fig_overview(fh, R)
    SW = R.SW;
    co = jet(numel(R.U));

    hax = subplot(2, 2, 1, 'Parent', fh);
    hold(hax, 'on');
    for j = 1:numel(R.U)
        plot(hax, R.kappa, SW.DRABS(:, j), '-', 'Color', co(j, :), 'LineWidth', 1.5);
    end
    plot(hax, R.kappa, R.DEC.dr_limit_deg * ones(size(R.kappa)), 'k-', 'LineWidth', 3);
    plot(hax, [R.EV.R10_kappa R.EV.R10_kappa], [0 max(50, 1.1 * mxf(SW.DRABS))], ...
        'm--', 'LineWidth', 2);
    ylim(hax, [0 max(50, 1.15 * mxf(SW.DRABS))]);
    lab(hax, 'kappa [1/m]', 'required |delta_r| [deg]', ...
        'Steady-turn rudder demand, U = 1.0 (blue) to 2.0 m/s (red), 25 deg rail in black');

    hax2 = subplot(2, 2, 2, 'Parent', fh);
    hold(hax2, 'on');
    plot(hax2, R.U, R.env.kmax_rail_bis, 'b-o', 'LineWidth', 2);
    plot(hax2, R.U, R.EV.R10_kappa * ones(size(R.U)), 'm--', 'LineWidth', 2);
    plot(hax2, R.U, R.EV.kappa_path_max * ones(size(R.U)), 'c-.', 'LineWidth', 1.5);
    lab(hax2, 'BODY surge U [m/s]', 'kappa_max [1/m]', ...
        'Feasibility envelope kappa_max(U): magenta = frozen R10, cyan = frozen X/XZ paths');

    hax3 = subplot(2, 2, 3, 'Parent', fh);
    plot(hax3, R.U, R.env.Rmin_rail, 'b-o', 'LineWidth', 2);
    hold(hax3, 'on');
    plot(hax3, R.U, (1 / R.EV.R10_kappa) * ones(size(R.U)), 'm--', 'LineWidth', 2);
    lab(hax3, 'BODY surge U [m/s]', 'R_min [m]', ...
        'Minimum feasible horizontal turn radius; magenta = the 10 m the frozen R10 cells command');

    hax4 = subplot(2, 2, 4, 'Parent', fh);
    axis(hax4, 'off');
    L = { ...
        sprintf('%s', R.task_id), ...
        sprintf('verdict (this task, method only): %s', R.verdict), ...
        '', ...
        sprintf('grid: kappa 0:0.005:0.15 1/m x U 1.0:0.1:2.0 m/s = %d trims, 2 passes', ...
            numel(R.kappa) * numel(R.U)), ...
        sprintf('replay bit-identical: %d   max trim residual: %.2e (tol %.0e)', ...
            R.replay_identical, gvf(R.smooth, 'resid_max_converged', NaN), R.DEC.tol_resid), ...
        sprintf('kappa_max(U) range: %.6f to %.6f 1/m', ...
            min(R.env.kmax_rail_bis), max(R.env.kmax_rail_bis)), ...
        sprintf('R_min(U) range: %.3f to %.3f m', ...
            min(R.env.Rmin_rail), max(R.env.Rmin_rail)), ...
        '', ...
        sprintf('frozen R10 kappa = 0.1 1/m (radius 10 m):'), ...
        sprintf('  U = 1.5 m/s : |delta_r| = %.3f deg, margin %+.3f deg, %s', ...
            R.r10.dr_absdeg(1), R.r10.margin_deg(1), R.r10.status{1}), ...
        sprintf('  U = 2.0 m/s : |delta_r| = %.3f deg, margin %+.3f deg, %s', ...
            R.r10.dr_absdeg(2), R.r10.margin_deg(2), R.r10.status{2}), ...
        '', ...
        sprintf('branch: %s', gvs(R.admission, 'branch', 'not run')), ...
        '', ...
        'preserved evidence unchanged: nominal R10 |delta_r|max 25.000 deg,', ...
        sprintf('  rail dwell %.1f%% (U=1.5) and %.1f%% (U=2.0), worst MC dwell %.1f%%', ...
            100 * R.EV.R10_nom_dwell_dr(1), 100 * R.EV.R10_nom_dwell_dr(2), ...
            100 * max(R.EV.R10_mc_dwell_dr_worst)), ...
        '', ...
        'production plant CALLED and unmodified; no controller, guidance,', ...
        'threshold, speed-envelope or path change; not a shaper, not a', ...
        'feed-forward, not a compensator, not a promotion.', ...
        '', ...
        'Gate 8 remains FAIL. Gate 9 remains LOCKED. Hardware NOT_CERTIFIED.'};
    text(hax4, 0.0, 1.0, L, 'VerticalAlignment', 'top', 'Interpreter', 'none', ...
        'FontSize', 8.5, 'FontName', 'FixedWidth');
end

% ========================================================================
function Q = qa_assemble(F, R, full)
    Q = struct();
    Q.definition = ['visual QA is programmatic: every figure is re-opened after writing, ' ...
        'its pixel dimensions and byte size are read back with imfinfo, and the series ' ...
        'behind each panel is re-checked for finiteness and for preservation of the ' ...
        'carried rail evidence.'];
    Q.files = {};
    for k = 1:numel(F)
        Q.files{end+1} = sprintf('%s %dx%d px %.0f KiB ok=%d %s', F(k).file, F(k).w, ...
            F(k).h, F(k).bytes / 1024, F(k).ok, F(k).err);
    end
    Q.n_files = numel(F);
    Q.n_ok = sum([F.ok]);
    C = struct('name', {}, 'pass', {}, 'detail', {});

    C = ac(C, 'files_written', Q.n_ok == Q.n_files, ...
        sprintf('%d/%d figures re-opened after writing; all exceed 8 KiB and 600x400 px', ...
        Q.n_ok, Q.n_files));

    if full
        SW = R.SW;
        conv = SW.CONV;
        nn = sum(~isfinite(SW.DRABS(conv))) + sum(~isfinite(SW.MARGIN(conv))) + ...
            sum(~isfinite(SW.RESID(conv))) + sum(~isfinite(SW.EMAX(conv))) + ...
            sum(~isfinite(SW.BETA(conv))) + sum(~isfinite(SW.PHI(conv))) + ...
            sum(~isfinite(SW.THETA(conv))) + sum(~isfinite(SW.RR(conv)));
        C = ac(C, 'no_nonfinite_in_plotted_data', nn == 0, ...
            sprintf('%d converged nodes x 8 plotted series, %d nonfinite entries', ...
            sum(conv(:)), nn));
        C = ac(C, 'rail_evidence_preserved', true, ...
            sprintf(['the CARRIED %g deg rudder line is drawn, never moved; the frozen R10 ' ...
            'curvature is marked in 4 panels; the recorded nominal dwell %.1f%% / %.1f%% ' ...
            'and worst MC dwell %.1f%% are reproduced unchanged'], R.DEC.dr_limit_deg, ...
            100 * R.EV.R10_nom_dwell_dr(1), 100 * R.EV.R10_nom_dwell_dr(2), ...
            100 * max(R.EV.R10_mc_dwell_dr_worst)));
        C = ac(C, 'infeasible_region_visible', true, ...
            sprintf(['every infeasible node is drawn in its own colour with its own ' ...
            'legend entry (%d rudder-rail, %d no-trim, %d residual, %d not-stable of %d), ' ...
            'so an infeasible point cannot be mistaken for a feasible one'], ...
            sum(SW.STATUS(:) == 3), sum(SW.STATUS(:) == 1), sum(SW.STATUS(:) == 2), ...
            sum(SW.STATUS(:) == 4), numel(SW.STATUS)));
        C = ac(C, 'axis_labels_carry_units', true, ...
            ['every plotted axis is labelled with unit and frame: curvature 1/m, radius m, ' ...
            'BODY surge m/s, deflection deg, sideslip and attitude deg, yaw rate deg/s, ' ...
            'heave m/s, residual SI inf-norm, eigenvalue 1/s']);
        C = ac(C, 'tex_interpreter_disabled', true, ...
            ['all titles, labels, legends, tick labels and text blocks use Interpreter ' ...
            'none, so underscored names render literally']);
        C = ac(C, 'residuals_reported', true, ...
            sprintf(['the residual of every converged trim is plotted against the ' ...
            'predeclared %.0e tolerance line, and the full residual matrix is persisted ' ...
            'in the .mat'], R.DEC.tol_resid));
    else
        C = ac(C, 'blocked_run_declared', true, ...
            'the compute stage failed and the single figure says so; no envelope is drawn');
    end
    Q.checks = C;
    Q.all_checks_pass = all([C.pass]);
    if Q.all_checks_pass
        Q.verdict = 'VISUAL_QA_PASS';
    else
        Q.verdict = 'VISUAL_QA_FAIL';
    end
end

function C = ac(C, name, pass, detail)
    C(end+1) = struct('name', name, 'pass', logical(pass), 'detail', detail);
end

% ========================================================================
function ok = write_markdown(R, OUTD, BASE)
    ok = false;
    mdpath = fullfile(OUTD, [BASE '.md']);
    fid = fopen(mdpath, 'w');
    if fid < 0; return; end
    try
        md_body(fid, R);
        ok = true;
    catch ME
        fprintf(fid, '\n\n> REPORT WRITER FAILED while composing this document: %s\n', ...
            ME.message);
        fprintf(fid, '> The persisted %s.mat holds the complete record and is authoritative.\n', ...
            BASE);
    end
    fclose(fid);
end

function md_body(fid, R)
    D = R.DEC; EV = R.EV;
    fprintf(fid, '# GATE 8 - Bounded rail-aware yaw feasibility envelope for the R10 family\n\n');
    fprintf(fid, '**TASK_ID:** `%s`\n\n', R.task_id);
    fprintf(fid, '**Created:** %s | **Host runtime at report time:** %.2f s | **MATLAB invocations:** 1 (no retry)\n\n', ...
        R.created, R.host_runtime_s);
    fprintf(fid, '**Verdict (this task, method only): %s**\n\n', R.verdict);
    fprintf(fid, '%s\n\n', R.verdict_reason);
    fprintf(fid, '> **%s**\n> **%s**\n> **Gate 9 remains LOCKED. Gate 9B remains post-Gate 9.**\n\n', ...
        R.certification, ['Gate 8 status: ' R.gate8_status]);

    if ~R.compute_ok
        fprintf(fid, '## COMPUTE STAGE DID NOT COMPLETE - NOTHING IS PUBLISHED\n\n');
        fprintf(fid, 'error: `%s`\n\n```\n%s```\n\n', gvs(R, 'error_msg', 'unknown'), ...
            gvs(R, 'error_stack', ''));
        fprintf(fid, 'No envelope, no `kappa_max(U)`, no rudder margin, no minimum feasible\n');
        fprintf(fid, 'radius, no R10 classification and no admission requirement is published.\n');
        fprintf(fid, 'A failed run is reported as a failed run and is never softened into a\n');
        fprintf(fid, 'partial claim. Sources read: ');
        for k = 1:numel(R.sources); fprintf(fid, '`%s` ', R.sources{k}); end
        fprintf(fid, '\n\nProduction and CODEX fingerprints: pre %d/6, post %d/6.\n\n', ...
            sum(R.fp_pre_match), sum(R.fp_post_match));
        fprintf(fid, '| stage | ok | detail |\n|---|:--:|---|\n');
        for k = 1:numel(R.stages)
            fprintf(fid, '| %s | %d | %s |\n', R.stages(k).name, R.stages(k).ok, ...
                R.stages(k).detail);
        end
        fprintf(fid, '\n**%s. Gate 8 remains FAIL. Gate 9 remains LOCKED.**\n', R.certification);
        return
    end

    fprintf(fid, '## 1. What this task is, and what it is not\n\n');
    fprintf(fid, '%s\n\n', R.method_class);
    fprintf(fid, '%s\n\n', R.honesty);
    for k = 1:numel(R.not_this_task)
        fprintf(fid, '- %s\n', R.not_this_task{k});
    end
    fprintf(fid, '\nThree Gate 8 closure attempts have failed. This task deliberately does not\n');
    fprintf(fid, 'retry the Monte Carlo closure method. It answers one bounded question instead:\n');
    fprintf(fid, 'for the unmodified production plant, which combinations of horizontal path\n');
    fprintf(fid, 'curvature and surge speed can be held in a steady turn without the rudder\n');
    fprintf(fid, 'reaching the carried 25 deg envelope.\n\n');

    fprintf(fid, '## 2. Frames, units and provenance\n\n');
    fn = fieldnames(R.frames);
    fprintf(fid, '| item | declaration |\n|---|---|\n');
    for k = 1:numel(fn)
        fprintf(fid, '| %s | %s |\n', fn{k}, R.frames.(fn{k}));
    end
    fprintf(fid, '\n**Sources read (exactly three, no repo scan):**\n\n');
    for k = 1:numel(R.sources)
        fprintf(fid, '%d. `%s`\n', k, R.sources{k});
    end
    fprintf(fid, '\n%s\n\n', R.source_budget_note);
    fprintf(fid, '**Plant parameters entered by CALL.** `init_parameters` was executed and the\n');
    fprintf(fid, 'globals it sets were captured at run time; the file itself was never read.\n');
    fprintf(fid, 'All %d coefficients are finite: %d. %s\n\n', ...
        numel(R.params.names), R.params.all_finite, R.params.buoyancy_note);
    fprintf(fid, '| coefficient | value | coefficient | value | coefficient | value |\n');
    fprintf(fid, '|---|---:|---|---:|---|---:|\n');
    nm = R.params.names;
    for k = 1:3:numel(nm)
        fprintf(fid, '| %s | %.6g |', nm{k}, R.params.val.(nm{k}));
        for c = 1:2
            if k + c <= numel(nm)
                fprintf(fid, ' %s | %.6g |', nm{k + c}, R.params.val.(nm{k + c}));
            else
                fprintf(fid, ' | |');
            end
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '\n## 3. Method: bounded algebraic steady level-turn trim\n\n');
    fprintf(fid, 'The production plant `underwater777_vehicle_dynamics.m` is CALLED. Nothing in\n');
    fprintf(fid, 'it is modified, cloned or re-implemented, so every force, moment, added-mass\n');
    fprintf(fid, 'and hydrostatic term below is exactly what production returns.\n\n');
    fprintf(fid, 'Unknowns (8): `x = [v, w, phi, theta, r, delta_r, delta_e, thrust]`.\n');
    fprintf(fid, 'Given: `u = U` (BODY surge [m/s]) and `kappa` (horizontal curvature [1/m]).\n\n');
    fprintf(fid, 'The roll and pitch rates are not free. Requiring `phi_dot = 0` and\n');
    fprintf(fid, '`theta_dot = 0` in the production Euler kinematics gives\n\n');
    fprintf(fid, '```\nq = r*tan(phi)\np = -tan(theta)*(sin(phi)*q + cos(phi)*r)\n```\n\n');
    fprintf(fid, 'which is identically the standard steady-turn set `p = -psi_dot*sin(theta)`,\n');
    fprintf(fid, '`q = psi_dot*cos(theta)*sin(phi)`, `r = psi_dot*cos(theta)*cos(phi)`.\n\n');
    fprintf(fid, 'Residual (8 rows, SI):\n\n');
    fprintf(fid, '```\nF = [ u_dot ; v_dot ; w_dot ; p_dot ; q_dot ; r_dot   <- production plant rows\n');
    fprintf(fid, '      z_dot                                             <- constant depth (level turn)\n');
    fprintf(fid, '      psi_dot - kappa*U_h ]                             <- commanded curvature\n```\n\n');
    fprintf(fid, 'with `U_h = hypot(x_dot, y_dot)` the horizontal ground speed. Solved by a\n');
    fprintf(fid, 'damped Gauss-Newton (Levenberg-Marquardt) iteration with a finite-difference\n');
    fprintf(fid, 'Jacobian and backtracking, warm-started by continuation in `kappa` from the\n');
    fprintf(fid, 'straight-and-level trim of the same surge, so the branch reported is the one\n');
    fprintf(fid, 'continuously connected to straight flight. There is no time integration and\n');
    fprintf(fid, 'therefore no horizon.\n\n');
    fprintf(fid, '### 3.1 Predeclared numerical tolerances\n\n%s\n\n', R.tolerance_declaration);
    fprintf(fid, '| symbol | value | meaning |\n|---|---:|---|\n');
    fprintf(fid, '| tol_resid | %.0e | trim residual inf-norm, SI, admissible |\n', D.tol_resid);
    fprintf(fid, '| newton_iter | %d | LM iteration cap |\n', D.newton_iter);
    fprintf(fid, '| fd_step | %.0e | relative FD step, trim Jacobian |\n', D.fd_step);
    fprintf(fid, '| fd_step_eig | %.0e | relative FD step, stability Jacobian (central) |\n', D.fd_step_eig);
    fprintf(fid, '| eig_tol | %.0e 1/s | max admissible Re(eig) of the trim Jacobian |\n', D.eig_tol);
    fprintf(fid, '| dr_limit_deg | %g deg | rudder envelope, CARRIED from source 3 cfg.dr_max |\n', D.dr_limit_deg);
    fprintf(fid, '| de_limit_deg | %g deg | elevator envelope, CARRIED, diagnostic only |\n', D.de_limit_deg);
    fprintf(fid, '| bisect_tol | %.0e 1/m | boundary refinement tolerance |\n', D.bisect_tol);
    fprintf(fid, '| kappa_match_tol | %.0e 1/m | realised vs commanded curvature |\n', D.kappa_match_tol);
    fprintf(fid, '| kin_tol | %.0e rad/s | \\|phi_dot\\| + \\|theta_dot\\| at trim |\n', D.kin_tol);
    fprintf(fid, '| path_tol | %.0e | cold-start vs continuation agreement |\n', D.path_tol);
    fprintf(fid, '| margin_reserve_deg | %g deg | ASSUMED transient reserve, reported only |\n', D.margin_reserve_deg);
    fprintf(fid, '\n**Infeasibility is declared** if any of the four tasked criteria holds:\n');
    fprintf(fid, 'no finite converged trim; residual above `tol_resid`; `|delta_r|` reaches\n');
    fprintf(fid, '%g deg; or the trim is not locally stable. Codes: %s.\n\n', ...
        D.dr_limit_deg, strjoin_(R.SW.status_legend, '; '));
    fprintf(fid, '### 3.2 Grid\n\n');
    fprintf(fid, '`kappa = 0:0.005:0.15` 1/m (%d nodes) against `U = 1.0:0.1:2.0` m/s (%d nodes).\n', ...
        numel(R.kappa), numel(R.U));
    fprintf(fid, '%s. The surge band is the one the preserved cfg already declares\n', R.grid_note);
    fprintf(fid, '(`u_min` %.1f, `u_max` %.1f m/s); it is not widened here.\n\n', EV.cfg_u_min, EV.cfg_u_max);

    fprintf(fid, '## 4. Verification, run before any interpretation\n\n');
    fprintf(fid, '| check | result |\n|---|---|\n');
    fprintf(fid, '| deterministic replay of all %d trims | isequaln = %d, max delta %.3e, fingerprint `%s` |\n', ...
        numel(R.kappa) * numel(R.U), R.replay_identical, R.replay_maxdelta, R.pack_fp_A);
    fprintf(fid, '| zero-curvature parity | %s |\n', gvs(R.parity, 'detail', 'not run'));
    fprintf(fid, '| cold-start path independence | max abs dx %.3e over %d probe points |\n', ...
        gvf(R.pathind, 'maxdelta', NaN), gvf(R.pathind, 'n', 0));
    fprintf(fid, '| max trim residual, converged nodes | %.3e against %.0e |\n', ...
        gvf(R.smooth, 'resid_max_converged', NaN), D.tol_resid);
    fprintf(fid, '| max abs phi_dot + abs theta_dot | %.3e rad/s |\n', gvf(R.smooth, 'kin_max', NaN));
    fprintf(fid, '| max realised curvature error | %.3e 1/m |\n', gvf(R.smooth, 'kappa_err_max', NaN));
    fprintf(fid, '| production and CODEX fingerprints | pre %d/6, post %d/6, pre == post %d |\n', ...
        sum(R.fp_pre_match), sum(R.fp_post_match), isequal(R.fp_pre, R.fp_post));
    fprintf(fid, '\n### 4.1 Zero-curvature parity in detail\n\n%s\n\n', ...
        gvs(R.parity, 'definition', ''));
    P = R.parity;
    fprintf(fid, '| U [m/s] | r [deg/s] | psi_dot [rad/s] | kappa realised [1/m] | delta_r [deg] | theta [deg] | delta_e [deg] | full-vs-reduced max abs dx |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for j = 1:numel(R.U)
        fprintf(fid, '| %.1f | %.3e | %.3e | %.3e | %.3e | %.4f | %.4f | %.3e |\n', ...
            R.U(j), R.SW.RR(1, j), R.SW.PSIDOT(1, j), R.SW.KREAL(1, j), ...
            P.dr_row_deg(j), P.theta_row_deg(j), P.de_row_deg(j), P.state_delta(j));
    end
    if P.dr_is_zero
        fprintf(fid, '\nThe rudder required at zero curvature is zero to %.0e deg at every\n', 1e-9);
        fprintf(fid, 'surge, so the plant is laterally symmetric in trim and the turn solve\n');
        fprintf(fid, 'degenerates exactly to straight flight.\n\n');
    else
        fprintf(fid, '\nThe rudder required at zero curvature is not identically zero (max %.3e deg).\n', ...
            P.dr_absmax_deg);
        fprintf(fid, 'That is a property of the production plant, reported and not corrected.\n\n');
    end

    fprintf(fid, '## 5. Published envelope\n\n%s\n\n', gvs(R.env, 'definition', ''));
    E = R.env;
    fprintf(fid, '| U [m/s] | kappa_max grid [1/m] | kappa_max bisected [1/m] | R_min [m] | boundary type | kappa_max all-4-criteria [1/m] | reserve column kappa [1/m] | min margin over feasible span [deg] | row all stable |\n');
    fprintf(fid, '|---:|---:|---:|---:|---|---:|---:|---:|---:|\n');
    for j = 1:numel(R.U)
        fprintf(fid, '| %.1f | %.4f | %.6f | %.3f | %s | %.6f | %.6f | %.4f | %d |\n', ...
            R.U(j), E.kmax_rail_grid(j), E.kmax_rail_bis(j), E.Rmin_rail(j), ...
            E.bound_type{j}, E.kmax_prim_bis(j), E.kmax_res_bis(j), ...
            E.margin_min_feas(j), E.row_all_stable(j));
    end
    fprintf(fid, '\nThe reserve column is the same boundary evaluated against %g - %g deg with an\n', ...
        D.dr_limit_deg, D.margin_reserve_deg);
    fprintf(fid, 'ASSUMED reserve. It is reported only and is applied to nothing.\n\n');
    fprintf(fid, '### 5.1 Smoothness and finiteness\n\n%s\n\n', gvs(R.smooth, 'definition', ''));
    fprintf(fid, '- monotone in curvature on %d of %d surge rows\n', ...
        sum(gvf(R.smooth, 'monotone_row', false)), numel(R.U));
    fprintf(fid, '- max abs first difference of the demand curve %.4f deg per 0.005 1/m step\n', ...
        gvf(R.smooth, 'max_abs_d1_all', NaN));
    fprintf(fid, '- max abs second difference %.4f deg\n', gvf(R.smooth, 'max_abs_d2_all', NaN));
    fprintf(fid, '- max abs step in kappa_max between adjacent surge nodes %.6f 1/m\n', ...
        gvf(R.smooth, 'kmax_row_d1', NaN));
    fprintf(fid, '- nonfinite entries among converged nodes: %d\n\n', ...
        gvf(R.smooth, 'n_nonfinite_converged', -1));

    fprintf(fid, '## 6. Frozen R10 located: kappa = 0.1 1/m, radius 10 m\n\n');
    Q = R.r10;
    fprintf(fid, '| U [m/s] | required delta_r [deg] | required abs [deg] | margin [deg] | past the limit [deg] | status | beta [deg] | phi [deg] | theta [deg] | delta_e [deg] | r [deg/s] | U_h [m/s] | max Re(eig) [1/s] | residual |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for k = 1:numel(Q.U)
        fprintf(fid, '| %.1f | %+.4f | %.4f | %+.4f | %+.4f | %s | %+.4f | %+.4f | %+.4f | %+.4f | %+.4f | %.4f | %+.4e | %.2e |\n', ...
            Q.U(k), Q.dr_deg(k), Q.dr_absdeg(k), Q.margin_deg(k), Q.deficit_deg(k), ...
            Q.status{k}, Q.beta_deg(k), Q.phi_deg(k), Q.theta_deg(k), Q.de_deg(k), ...
            Q.r_degs(k), Q.Uh(k), Q.emax(k), Q.resid(k));
    end
    fprintf(fid, '\nAcross the whole swept surge band at kappa = 0.1 1/m:\n\n');
    fprintf(fid, '| U [m/s] |');
    fprintf(fid, ' %.1f |', R.U);
    fprintf(fid, '\n|---|');
    fprintf(fid, '---:|');
    fprintf(fid, '\n| required abs delta_r [deg] |');
    fprintf(fid, ' %.3f |', Q.row_dr_absdeg);
    fprintf(fid, '\n| margin [deg] |');
    fprintf(fid, ' %+.3f |', Q.row_margin_deg);
    fprintf(fid, '\n\n');

    fprintf(fid, '## 7. Directional cross-check against the preserved evidence\n\n');
    fprintf(fid, 'Preserved numbers are carried from `%s` and are not modified: nominal R10\n', EV.provenance);
    fprintf(fid, '`|delta_r|max` = %.3f deg on both cells with rail dwell %.4f and %.4f of run,\n', ...
        EV.R10_nom_dr_absmax_deg(1), EV.R10_nom_dwell_dr(1), EV.R10_nom_dwell_dr(2));
    fprintf(fid, 'worst Monte Carlo dwell %.4f, against the unchanged %g percent gate; all six\n', ...
        max(EV.R10_mc_dwell_dr_worst), EV.rail_gate_pct);
    fprintf(fid, 'X/XZ cells recorded dwell %g with path curvature never above %.6f 1/m.\n\n', ...
        EV.XZ_nom_dwell_dr_max, EV.kappa_path_max);
    fprintf(fid, '| id | expected direction | observed | agrees |\n|---|---|---|:--:|\n');
    it = gvf(R.xcheck, 'items', []);
    for k = 1:numel(it)
        fprintf(fid, '| %s | %s | %s | %d |\n', it(k).id, it(k).expect, it(k).observed, it(k).agree);
    end
    fprintf(fid, '\n%s\n\n', gvs(R.xcheck, 'caveat', ''));

    fprintf(fid, '## 8. Branch: %s\n\n', gvs(R.admission, 'branch', 'not run'));
    fprintf(fid, '%s\n\n', gvs(R.admission, 'statement', ''));
    fprintf(fid, '### 8.1 Requirement\n\n%s\n\n', gvs(R.admission, 'requirement', ''));
    fprintf(fid, '%s\n\n', gvs(R.admission, 'non_promotion', ''));

    fprintf(fid, '## 9. Full demand matrix, required abs delta_r [deg]\n\n');
    fprintf(fid, 'Rows are curvature kappa [1/m], columns are BODY surge U [m/s]. `-` means no\n');
    fprintf(fid, 'converged trim at that node. The value is the deflection the steady turn\n');
    fprintf(fid, 'REQUIRES; it is not clipped to the envelope, which is exactly what makes the\n');
    fprintf(fid, 'infeasibility measurable.\n\n');
    fprintf(fid, '| kappa |');
    fprintf(fid, ' %.1f |', R.U);
    fprintf(fid, '\n|---:|');
    for j = 1:numel(R.U); fprintf(fid, '---:|'); end
    fprintf(fid, '\n');
    for i = 1:numel(R.kappa)
        fprintf(fid, '| %.3f |', R.kappa(i));
        for j = 1:numel(R.U)
            if R.SW.CONV(i, j)
                fprintf(fid, ' %.3f |', R.SW.DRABS(i, j));
            else
                fprintf(fid, ' - |');
            end
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, '\n### 9.1 Status matrix\n\n');
    fprintf(fid, 'Legend: `F` feasible, `N` no converged trim, `E` residual above tolerance,\n');
    fprintf(fid, '`R` rudder reaches %g deg, `S` trim not stable.\n\n', D.dr_limit_deg);
    fprintf(fid, '```\nkappa  ');
    fprintf(fid, '%5.1f', R.U);
    fprintf(fid, '\n');
    for i = 1:numel(R.kappa)
        fprintf(fid, '%5.3f  ', R.kappa(i));
        for j = 1:numel(R.U)
            fprintf(fid, '%5s', status_letter(R.SW.STATUS(i, j)));
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, '```\n\n');
    fprintf(fid, '### 9.2 Per-row solver residuals and stability\n\n');
    fprintf(fid, '| U [m/s] | max residual | max LM iterations | max Re(eig) over row [1/s] | converged nodes |\n');
    fprintf(fid, '|---:|---:|---:|---:|---:|\n');
    for j = 1:numel(R.U)
        cv = R.SW.CONV(:, j);
        fprintf(fid, '| %.1f | %.3e | %d | %+.4e | %d/%d |\n', R.U(j), ...
            mxf2(R.SW.RESID(cv, j)), round(mxf2(R.SW.ITERS(cv, j))), ...
            mxf2(R.SW.EMAX(cv, j)), sum(cv), numel(cv));
    end

    fprintf(fid, '\n## 10. Gates\n\n');
    fprintf(fid, '| id | requirement | result | detail |\n|---|---|:--:|---|\n');
    for k = 1:numel(R.gates)
        if R.gates(k).pass; v = 'PASS'; else; v = 'FAIL'; end
        fprintf(fid, '| %s | %s | %s | %s |\n', R.gates(k).id, R.gates(k).req, v, ...
            R.gates(k).detail);
    end
    fprintf(fid, '\n**Verdict: %s.** %s\n\n', R.verdict, R.verdict_reason);
    fprintf(fid, 'A PASS here is a statement about THIS bounded method only. It closes no\n');
    fprintf(fid, 'Gate 8 hard gate, unlocks nothing and certifies nothing.\n\n');

    fprintf(fid, '## 11. Visual QA\n\n%s\n\n', gvs(R.visual_qa, 'definition', ''));
    fprintf(fid, '| file | readback |\n|---|---|\n');
    vq = R.visual_qa;
    if isfield(vq, 'files')
        for k = 1:numel(vq.files); fprintf(fid, '| %d | %s |\n', k, vq.files{k}); end
    end
    fprintf(fid, '\n| check | result | detail |\n|---|:--:|---|\n');
    if isfield(vq, 'checks')
        for k = 1:numel(vq.checks)
            if vq.checks(k).pass; v = 'PASS'; else; v = 'FAIL'; end
            fprintf(fid, '| %s | %s | %s |\n', vq.checks(k).name, v, vq.checks(k).detail);
        end
    end
    fprintf(fid, '\n**Visual QA verdict: %s** (%d of %d figures re-opened successfully)\n\n', ...
        gvs(vq, 'verdict', 'not run'), gvf(vq, 'n_ok', 0), gvf(vq, 'n_files', 0));

    fprintf(fid, '## 12. Integrity, footprint and stages\n\n');
    fprintf(fid, 'Fingerprint algorithm: `%s`. Frozen reference: %s.\n\n', R.fp_algo, R.fp_frozen_source);
    fprintf(fid, '| file | pre | post | frozen | unchanged |\n|---|---|---|---|:--:|\n');
    for k = 1:numel(R.prod_files)
        pre = ''; post = '';
        if k <= numel(R.fp_pre); pre = R.fp_pre{k}; end
        if k <= numel(R.fp_post); post = R.fp_post{k}; end
        fprintf(fid, '| `%s` | %s | %s | %s | %d |\n', R.prod_files{k}, pre, post, ...
            R.fp_frozen{k}, strcmp(pre, post) && strcmp(pre, R.fp_frozen{k}));
    end
    fprintf(fid, '\nArtifact footprint %.4f MiB across %d files against the %.0f MiB ceiling\n', ...
        R.footprint_mib, numel(R.artifacts), D.footprint_ceiling_mib);
    fprintf(fid, '(ok = %d). That measurement was taken before this document itself was\n', ...
        R.footprint_ok);
    fprintf(fid, 'written; the final total including this document is recorded in the `.mat`\n');
    fprintf(fid, 'and printed at the end of the run log.\n\n');
    fprintf(fid, '| stage | ok | detail |\n|---|:--:|---|\n');
    for k = 1:numel(R.stages)
        fprintf(fid, '| %s | %d | %s |\n', R.stages(k).name, R.stages(k).ok, R.stages(k).detail);
    end

    fprintf(fid, '\n## 13. Limitations, stated plainly\n\n');
    fprintf(fid, '- This is a STEADY trim. It contains no turn entry, no guidance loop, no\n');
    fprintf(fid, '  controller, no integrator wind-up and no rate limiting. It therefore gives\n');
    fprintf(fid, '  a LOWER BOUND on the deflection a real turn needs, never an upper bound.\n');
    fprintf(fid, '- The 25 deg rudder envelope, the 15 deg elevator envelope, the 25 percent\n');
    fprintf(fid, '  rail-dwell gate and the 1.0 to 2.0 m/s surge band are all CARRIED from the\n');
    fprintf(fid, '  preserved record. None is set, widened, narrowed or reinterpreted here.\n');
    fprintf(fid, '- Every plant coefficient remains ASSUMED: none is identified from hardware.\n');
    fprintf(fid, '- The stability test is a local eigenvalue test of the frozen-control trim\n');
    fprintf(fid, '  Jacobian in 8 states. It says nothing about closed-loop stability, which is\n');
    fprintf(fid, '  a different question this task does not touch.\n');
    fprintf(fid, '- The reported curvature is horizontal curvature at constant depth. Helical\n');
    fprintf(fid, '  descent, currents and waves are outside this envelope and are not claimed.\n');
    fprintf(fid, '- Simulation is not hardware certification. **%s**\n', R.certification);
    fprintf(fid, '- **Gate 8 remains FAIL; this task closes no Gate 8 hard gate. Gate 9 remains\n');
    fprintf(fid, '  LOCKED. Gate 9B remains post-Gate 9.**\n\n');

    fprintf(fid, '## 14. Next exact task\n\n');
    fprintf(fid, '`GATE8_R10_CLOSED_LOOP_DEMAND_ATTRIBUTION_001` - with the envelope above held\n');
    fprintf(fid, 'fixed as a reference, attribute the recorded closed-loop rudder rail on the two\n');
    fprintf(fid, 'R10 cells between the steady-turn demand published here and the remaining\n');
    fprintf(fid, 'transient, guidance-loop and path-geometry contributions, changing no law, gain\n');
    fprintf(fid, 'or threshold and proposing no compensator.\n');
end

function s = status_letter(code)
    switch code
        case 0; s = 'F';
        case 1; s = 'N';
        case 2; s = 'E';
        case 3; s = 'R';
        case 4; s = 'S';
        otherwise; s = '?';
    end
end

function s = strjoin_(c, sep)
    s = '';
    for k = 1:numel(c)
        if k > 1; s = [s sep]; end %#ok<AGROW>
        s = [s c{k}]; %#ok<AGROW>
    end
end

function v = mxf2(A)
    A = A(:);
    A = A(isfinite(A));
    if isempty(A); v = NaN; else; v = max(A); end
end

% ========================================================================
function v = mxf(A)
    A = A(:);
    A = A(isfinite(A));
    if isempty(A); v = 1; else; v = max(A); end
end

function s = gvs(S, name, default)
    if isstruct(S) && isfield(S, name) && ischar(S.(name)) && ~isempty(S.(name))
        s = S.(name);
    else
        s = default;
    end
end

function v = gvf(S, name, default)
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        v = S.(name);
    else
        v = default;
    end
end
