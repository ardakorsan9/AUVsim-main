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

            metrics = compute_path_metrics(sc.path, vehicle_path, velocities, orientations, yaw_refs, pitch_refs, dt);
            metrics.name = sc.name;
            metrics.ok = true;
            metrics.error_msg = '';
            metrics.total_time = total_time;
            metrics.n_samples = size(vehicle_path, 1);
            metrics.dt = dt;

            fig_path = fullfile(out_dir, sprintf('%02d_%s.png', k, sc.tag));
            save_suite_figure(sc, vehicle_path, times, orientations, yaw_refs, pitch_refs, metrics, fig_path);

            fprintf('DONE  mean_cross_track=%.3f m | max=%.3f m | pitch_chatter=%.4f deg/s | mean|pitch|=%.2f deg | fig=%s\n\n', ...
                metrics.mean_cross_track, metrics.max_cross_track, metrics.pitch_chatter_dps, ...
                metrics.mean_pitch_err_deg, fig_path);

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
    n = 400;
    x = linspace(0, 20, n)';
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
    n = 600;
    t = linspace(0, 22, n)';
    path = [t, zeros(n,1), 0.4*t]; % mild climb (longer so CTE isn't end-point dominated)
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

function m = compute_path_metrics(path, vehicle_path, velocities, orientations, yaw_refs, pitch_refs, dt)
    if nargin < 7 || isempty(dt); dt = 0.0375; end
    n = size(vehicle_path, 1);
    if n < 2
        m = struct('mean_cross_track', NaN, 'max_cross_track', NaN, ...
            'final_u', NaN, 'mean_yaw_err_deg', NaN, 'mean_pitch_err_deg', NaN, ...
            'pitch_chatter_dps', NaN, 'theta_pp_deg', NaN);
        return;
    end
    ct = zeros(n, 1);
    for i = 1:n
        d = vecnorm(path - vehicle_path(i, :), 2, 2);
        ct(i) = min(d);
    end
    % pitch_ref is physical; internal theta opposite -> err = pitch_ref + theta
    yaw_err = wrapToPi(yaw_refs(:) - orientations(:,3));
    pitch_err = pitch_refs(:) + orientations(:,2);
    theta_phys = -orientations(:,2);
    % Chatter like diag: HF std of d(theta_phys)/dt after settle (~2 s)
    i0 = max(1, round(2.0 / dt));
    th = theta_phys(i0:end);
    dth = [0; diff(th)] / dt;
    dth_hf = suite_hf_signal(detrend(dth), dt);
    chatter = rad2deg(std(dth_hf));
    m = struct( ...
        'mean_cross_track', mean(ct), ...
        'max_cross_track', max(ct), ...
        'final_u', velocities(end,1), ...
        'mean_yaw_err_deg', rad2deg(mean(abs(yaw_err))), ...
        'mean_pitch_err_deg', rad2deg(mean(abs(pitch_err))), ...
        'pitch_chatter_dps', chatter, ...
        'theta_pp_deg', rad2deg(max(th) - min(th)));
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
    title(sprintf('%s\nmean CTE=%.2fm  max=%.2fm', sc.name, metrics.mean_cross_track, metrics.max_cross_track));
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
        fprintf(fid, '  mean cross-track error: %.3f m\n', r.mean_cross_track);
        fprintf(fid, '  max  cross-track error: %.3f m\n', r.max_cross_track);
        fprintf(fid, '  final surge u: %.3f m/s\n', r.final_u);
        fprintf(fid, '  mean |yaw err|: %.2f deg\n', r.mean_yaw_err_deg);
        fprintf(fid, '  mean |pitch err|: %.2f deg\n', r.mean_pitch_err_deg);
        if isfield(r, 'pitch_chatter_dps')
            fprintf(fid, '  pitch chatter: %.4f deg/s\n', r.pitch_chatter_dps);
            fprintf(fid, '  theta pp (settle): %.3f deg\n', r.theta_pp_deg);
        end
        if isfield(r, 'dt')
            fprintf(fid, '  dt: %.4f s\n', r.dt);
        end
    end
    fclose(fid);
end
