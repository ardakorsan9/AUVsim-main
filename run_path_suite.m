function results = run_path_suite(do_calibrate)
% RUN_PATH_SUITE  Straight line -> incline -> circle -> helix, one stack.
% Uses: guidance_law -> controller_law -> underwater777_vehicle_dynamics
% do_calibrate (default true): run elevator sign + trim table. Pass false to
% reuse globals from a prior full calibration (faster tuning iters).

    if nargin < 1 || isempty(do_calibrate)
        do_calibrate = true;
    end

    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    % Reset guidance / controller persistent state
    clear functions
    clear guidance_law controller_law

    init_parameters();
    global dt_controller dt_guidance tau_rate

    % Aşama 1-2: elevator sign + speed trim table (once per suite)
    if do_calibrate
        fprintf('\n--- Calibration ---\n');
        sign_rep = test_elevator_sign();
        global elevator_sign
        elevator_sign = sign_rep.delta_e_sign;
        build_pitch_trim_table();
    else
        global elevator_sign trim_speed_table trim_elevator_table
        fprintf('\n--- Calibration SKIPPED (reusing globals) ---\n');
        if isempty(elevator_sign); elevator_sign = 1; end
        if isempty(trim_speed_table)
            fprintf(2, 'WARN: no trim table in globals; building now.\n');
            build_pitch_trim_table();
        else
            fprintf('elevator_sign=%+d | trim u=[%s] de_deg=[%s]\n', ...
                elevator_sign, num2str(trim_speed_table,'%.1f '), ...
                num2str(rad2deg(trim_elevator_table),'%+.2f '));
        end
    end

    % Plant / control sample period (same as controller; T1A single-rate)
    dt = dt_controller;
    fprintf('dt_controller=%.4f  dt_guidance=%.4f  tau_rate=%.4f s\n', ...
        dt_controller, dt_guidance, tau_rate);

    scenarios = { ...
        make_scenario_x_line(), ...
        make_scenario_xz_line(), ...
        make_scenario_circle(), ...
        make_scenario_helix() ...
    };

    results = struct([]);
    fprintf('\n========== AUV PATH SUITE ==========\n');
    fprintf('Project: %s\n', project_dir);
    fprintf('Output:  %s\n\n', out_dir);

    for k = 1:numel(scenarios)
        sc = scenarios{k};
        fprintf('----- [%d/%d] %s -----\n', k, numel(scenarios), sc.name);
        fprintf('Goal: %s\n', sc.description);

        % Fresh guidance filters / controller slew state each scenario
        clear guidance_law controller_law

        state0 = initial_state_from_path(sc.path, sc.u0);

        try
            [vehicle_path, times, velocities, angular_velocities, orientations, total_time, yaw_refs, pitch_refs, u_refs] = ...
                continuous_path_tracking(sc.path, state0, dt, sc.T_final);

            metrics = compute_path_following_metrics(sc.path, vehicle_path, velocities, ...
                orientations, yaw_refs, pitch_refs, dt, times);
            metrics.name = sc.name;
            metrics.tag = sc.tag;
            metrics.ok = true;
            metrics.error_msg = '';
            metrics.total_time = total_time;
            metrics.n_samples = size(vehicle_path, 1);
            metrics.dt = dt;
            % Elevator / integrator diagnostics from continuous_path_tracking
            global suite_delta_e_log suite_int_angle_log suite_int_rate_log
            global suite_rate_filt_log suite_rate_raw_log tau_rate
            if ~isempty(suite_delta_e_log)
                metrics.elevator_rms_deg = rad2deg(rms(suite_delta_e_log));
                metrics.elevator_std_deg = rad2deg(std(suite_delta_e_log));
                % Elevator jitter: HF RMS of delta_e (deg)
                de_hf = suite_hf_signal(detrend(suite_delta_e_log(:)), dt);
                metrics.elevator_jitter_deg = rad2deg(rms(de_hf(max(1,round(0.8/dt)):end)));
            else
                metrics.elevator_rms_deg = NaN;
                metrics.elevator_std_deg = NaN;
                metrics.elevator_jitter_deg = NaN;
            end
            if ~isempty(suite_int_angle_log)
                metrics.int_angle_min = min(suite_int_angle_log);
                metrics.int_angle_max = max(suite_int_angle_log);
            else
                metrics.int_angle_min = NaN;
                metrics.int_angle_max = NaN;
            end
            if ~isempty(suite_int_rate_log)
                metrics.int_rate_min = min(suite_int_rate_log);
                metrics.int_rate_max = max(suite_int_rate_log);
            else
                metrics.int_rate_min = NaN;
                metrics.int_rate_max = NaN;
            end
            metrics.tau_rate = tau_rate;
            if ~isempty(suite_rate_raw_log) && ~isempty(suite_rate_filt_log)
                i0 = max(1, round(2.0/dt));
                raw = suite_rate_raw_log(i0:end);
                fil = suite_rate_filt_log(i0:end);
                metrics.rate_filt_rms_err_dps = rad2deg(rms(raw - fil));
                if std(raw) > 1e-9 && std(fil) > 1e-9
                    c = corrcoef(raw, fil);
                    metrics.corr_rate_filt = c(1,2);
                else
                    metrics.corr_rate_filt = NaN;
                end
                metrics.rate_lag_est_s = suite_estimate_lag(raw, fil, dt);
            else
                metrics.rate_filt_rms_err_dps = NaN;
                metrics.corr_rate_filt = NaN;
                metrics.rate_lag_est_s = NaN;
            end

            fig_path = fullfile(out_dir, sprintf('%02d_%s.png', k, sc.tag));
            save_suite_figure(sc, vehicle_path, times, orientations, yaw_refs, pitch_refs, metrics, fig_path);

            fprintf('DONE  CTE_perp(sbe)=%.3f m | legacy=%.3f | chatter=%.4f | |pitch|=%.2f | de_jit=%.3f | lag=%.3fs | corr=%.3f | fig=%s\n\n', ...
                metrics.mean_cte_perp, metrics.cte_waypoint_legacy_full, metrics.pitch_chatter_dps, ...
                metrics.mean_pitch_err_deg, metrics.elevator_jitter_deg, ...
                metrics.rate_lag_est_s, metrics.corr_rate_filt, fig_path);

        catch ME
            metrics = struct( ...
                'name', sc.name, ...
                'ok', false, ...
                'error_msg', ME.message, ...
                'mean_cross_track', NaN, ...
                'max_cross_track', NaN, ...
                'final_u', NaN, ...
                'total_time', 0, ...
                'n_samples', 0);
            fprintf(2, 'FAILED: %s\n\n', ME.message);
            vehicle_path = []; %#ok<NASGU>
        end

        if isempty(results)
            results = metrics;
        else
            results(end+1) = metrics; %#ok<AGROW>
        end
    end

    summary_file = fullfile(out_dir, 'summary.txt');
    write_summary(results, summary_file);
    fprintf('========== SUMMARY -> %s ==========\n', summary_file);
    type(summary_file);
end

%% --------- scenarios ---------
function sc = make_scenario_x_line()
    % Extend path beyond T_sim travel (~1.5 m/s * 18 s ≈ 27 m) so endpoint
    % overrun does not dominate metrics. Path end fixed near 45 m.
    n = 600;
    x = linspace(0, 45, n)';
    path = [x, zeros(n,1), zeros(n,1)];
    sc = struct( ...
        'name', '1) Duz X cizgisi', ...
        'tag', 'x_line', ...
        'description', 'y=0,z=0 boyunca ileri git (en basit path following)', ...
        'path', path, ...
        'T_final', 18, ...
        'u0', 1.5);
end

function sc = make_scenario_xz_line()
    % Mild climb; arc length ≈ L*sqrt(1+0.16). L=42 → s≈45 m > T_sim travel
    % (~36 m at 22 s) so vehicle stays on-path for fair CTE_perp scoring.
    n = 900;
    t = linspace(0, 42, n)';
    path = [t, zeros(n,1), 0.4*t];
    sc = struct( ...
        'name', '2) Egik XZ cizgisi', ...
        'tag', 'xz_line', ...
        'description', 'x ve z birlikte artar; pitch hold / derinlik egimi', ...
        'path', path, ...
        'T_final', 22, ...
        'u0', 1.5);
end

function sc = make_scenario_circle()
    n = 500;
    R = 5;
    th = linspace(0, 2*pi, n)';
    path = [R*cos(th), R*sin(th), zeros(n,1)];
    sc = struct( ...
        'name', '3) Yatay daire', ...
        'tag', 'circle', ...
        'description', 'z=0 daire; yaw / rudder path following', ...
        'path', path, ...
        'T_final', 35, ...
        'u0', 1.5);
end

function sc = make_scenario_helix()
    path = generate_balanced_helical_path(5, 2, 2, 500);
    sc = struct( ...
        'name', '4) Heliks', ...
        'tag', 'helix', ...
        'description', 'yaw+pitch birlikte; tam path following', ...
        'path', path, ...
        'T_final', 45, ...
        'u0', 1.5);
end

%% --------- helpers ---------
function state = initial_state_from_path(path, u0)
    state = zeros(12, 1);
    state(1:3) = path(1, :)';
    d = path(2, :) - path(1, :);
    % Internal theta sign is opposite to physical pitch (see controller_law)
    physical_pitch = atan2(d(3), norm(d(1:2)));
    state(5) = -physical_pitch;
    state(6) = atan2(d(2), d(1));
    state(7) = u0;
end

function y = suite_hf_signal(x, dt)
    n = max(3, round(0.8 / dt));
    b = ones(n,1) / n;
    lf = filter(b, 1, x(:));
    y = x(:) - lf;
    y(1:n) = 0;
end

function save_suite_figure(sc, vehicle_path, times, orientations, yaw_refs, pitch_refs, metrics, fig_path)
    fig = figure('Name', sc.name, 'NumberTitle', 'off', 'Color', 'w', 'Position', [80 80 1100 700]);

    subplot(2,2,[1 3]);
    plot3(sc.path(:,1), sc.path(:,2), sc.path(:,3), 'k--', 'LineWidth', 1.6); hold on;
    plot3(vehicle_path(:,1), vehicle_path(:,2), vehicle_path(:,3), 'b-', 'LineWidth', 1.8);
    plot3(vehicle_path(1,1), vehicle_path(1,2), vehicle_path(1,3), 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
    plot3(vehicle_path(end,1), vehicle_path(end,2), vehicle_path(end,3), 'rs', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
    grid on; axis equal;
    xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
    title(sprintf(['%s\nCTE_perp (settled_before_end)=%.2fm  max=%.2fm\n', ...
        'legacy waypoint CTE=%.2fm  |ez|_sbe=%.2fm  s_tot=%.1fm'], ...
        sc.name, metrics.mean_cte_perp, metrics.max_cte_perp, ...
        metrics.cte_waypoint_legacy_full, metrics.mean_abs_ez, metrics.s_total));
    legend('Referans yol', 'Arac', 'Baslangic', 'Bitis', 'Location', 'best');
    view(35, 25);

    subplot(2,2,2);
    % Unwrap for fair lag view (guidance now emits continuous yaw_ref)
    psi_u = unwrap(orientations(:,3));
    yaw_u = unwrap(yaw_refs);
    plot(times, rad2deg(psi_u), 'b', 'LineWidth', 1.2); hold on;
    plot(times, rad2deg(yaw_u), 'r--', 'LineWidth', 1.2);
    grid on; xlabel('t (s)'); ylabel('deg');
    title('Yaw (unwrapped): actual vs ref');
    legend('\psi', '\psi_{ref}', 'Location', 'best');

    subplot(2,2,4);
    plot(times, rad2deg(-(orientations(:,2))), 'b', 'LineWidth', 1.2); hold on; % physical pitch
    plot(times, rad2deg(pitch_refs), 'r--', 'LineWidth', 1.2);
    grid on; xlabel('t (s)'); ylabel('deg');
    title('Pitch (physical): actual vs ref');
    legend('\theta_{phys}', '\theta_{ref}', 'Location', 'best');

    exportgraphics(fig, fig_path, 'Resolution', 150);
    % keep figures open for the user
end

function write_summary(results, summary_file)
    fid = fopen(summary_file, 'w');
    fprintf(fid, 'AUV Path Suite Summary\n');
    fprintf(fid, '======================\n');
    for i = 1:numel(results)
        r = results(i);
        fprintf(fid, '\n%s\n', r.name);
        if ~r.ok
            fprintf(fid, '  STATUS: FAILED - %s\n', r.error_msg);
            continue;
        end
        fprintf(fid, '  STATUS: OK\n');
        fprintf(fid, '  samples: %d, time: %.1f s\n', r.n_samples, r.total_time);
        fprintf(fid, '  path s_total / travel_est: %.2f / %.2f m\n', r.s_total, r.travel_est);
        fprintf(fid, '  PRIMARY gate window: settled_before_end (t>=%.1fs & s<0.88*s_total & ~near_end)\n', r.settle_t);
        fprintf(fid, '  CTE_perp (settled_before_end) mean/max: %.3f / %.3f m\n', ...
            r.mean_cte_perp, r.max_cte_perp);
        fprintf(fid, '  |e_z| / mean signed e_z (sbe): %.3f / %+.3f m\n', ...
            r.mean_abs_ez, r.mean_signed_ez);
        fprintf(fid, '  |e_s| / e_xy (sbe): %.3f / %.3f m\n', r.mean_abs_es, r.mean_e_xy);
        fprintf(fid, '  --- window table (CTE_perp / |e_z| / |e_s| / legacy_wp) ---\n');
        fprintf(fid, '  full:                 %.3f / %.3f / %.3f / %.3f\n', ...
            r.CTE_perp.mean, r.vertical_normal.mean, r.e_s.mean, r.cte_waypoint_legacy_full);
        fprintf(fid, '  settled:              %.3f / %.3f / %.3f / %.3f\n', ...
            r.CTE_perp_settled.mean, r.vertical_normal_settled.mean, ...
            r.e_s_settled.mean, r.cte_waypoint_legacy_settled);
        fprintf(fid, '  before_end:           %.3f / %.3f / %.3f / %.3f\n', ...
            r.CTE_perp_before_end.mean, r.vertical_normal_before_end.mean, ...
            r.e_s_before_end.mean, r.cte_waypoint_legacy_before_end);
        fprintf(fid, '  settled_before_end:   %.3f / %.3f / %.3f / %.3f\n', ...
            r.CTE_perp_settled_before_end.mean, r.vertical_normal_settled_before_end.mean, ...
            r.e_s_settled_before_end.mean, r.cte_waypoint_legacy_settled_before_end);
        fprintf(fid, '  overrun:              %.3f / %.3f / %.3f / %.3f\n', ...
            r.CTE_perp_overrun.mean, r.vertical_normal_overrun.mean, ...
            r.e_s_overrun.mean, r.cte_waypoint_legacy_overrun);
        fprintf(fid, '  cte_waypoint_legacy (full/max): %.3f / %.3f m\n', ...
            r.cte_waypoint_legacy_full, r.max_cte_waypoint_legacy);
        fprintf(fid, '  mean_cross_track alias (= CTE_perp sbe): %.3f m\n', r.mean_cross_track);
        fprintf(fid, '  final surge u: %.3f m/s\n', r.final_u);
        fprintf(fid, '  mean |yaw err|: %.2f deg\n', r.mean_yaw_err_deg);
        fprintf(fid, '  mean |pitch err|: %.2f deg\n', r.mean_pitch_err_deg);
        if isfield(r, 'pitch_chatter_dps')
            fprintf(fid, '  pitch chatter: %.4f deg/s\n', r.pitch_chatter_dps);
            fprintf(fid, '  theta pp (settle): %.3f deg\n', r.theta_pp_deg);
        end
        if isfield(r, 'elevator_rms_deg')
            fprintf(fid, '  elevator RMS: %.3f deg\n', r.elevator_rms_deg);
            fprintf(fid, '  elevator std: %.3f deg\n', r.elevator_std_deg);
            fprintf(fid, '  elevator jitter (HF RMS): %.3f deg\n', r.elevator_jitter_deg);
        end
        if isfield(r, 'int_angle_min')
            fprintf(fid, '  int_angle min/max: %.4f / %.4f rad\n', r.int_angle_min, r.int_angle_max);
            fprintf(fid, '  int_rate  min/max: %.4f / %.4f rad\n', r.int_rate_min, r.int_rate_max);
        end
        if isfield(r, 'tau_rate')
            fprintf(fid, '  tau_rate: %.4f s\n', r.tau_rate);
            fprintf(fid, '  rate filt RMS err: %.3f deg/s\n', r.rate_filt_rms_err_dps);
            fprintf(fid, '  corr(rate,filt): %.3f\n', r.corr_rate_filt);
            fprintf(fid, '  rate lag est: %.3f s\n', r.rate_lag_est_s);
        end
        if isfield(r, 'dt')
            fprintf(fid, '  dt: %.4f s\n', r.dt);
        end
    end
    fclose(fid);
end

function lag = suite_estimate_lag(a, b, dt)
    a = a(:) - mean(a); b = b(:) - mean(b);
    maxlag = min(40, floor(numel(a)/4));
    if maxlag < 2 || std(a) < 1e-12 || std(b) < 1e-12
        lag = NaN; return;
    end
    [c, lags] = xcorr(b, a, maxlag, 'coeff');
    [~, ix] = max(c);
    lag = lags(ix) * dt;
end
