function results = run_tur3_stage(stage_tag, lambda_val)
% RUN_TUR3_STAGE  Focused Tur3 regression: X + XZ + helix (+ circle check).
% Uses frozen Tur 2.5 trim (no recalibration). Sets lambda_muw_ff = lambda_val.
% Writes suite_results/<stage>_RESULTS.md and .mat

    if nargin < 1 || isempty(stage_tag); stage_tag = 'T3B-1'; end
    if nargin < 2 || isempty(lambda_val); lambda_val = 0; end

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    clear global lambda_muw_ff trim_speed_table trim_elevator_table elevator_sign
    init_parameters();

    global lambda_muw_ff elevator_sign trim_speed_table trim_elevator_table
    global dt_controller dt_guidance tau_rate Ki_rate Ki_angle
    global delta_e_max

    % Frozen Tur 2.5 trim — never rebuild in Tur3
    elevator_sign = 1;
    trim_speed_table = [0.8 1.0 1.5 2.0];
    trim_elevator_table = deg2rad([-9.18 -7.33 -4.62 -3.17]);
    lambda_muw_ff = lambda_val;

    fprintf('\n========== %s  lambda_muw_ff=%.2f ==========\n', stage_tag, lambda_muw_ff);
    fprintf('Frozen: dt_c=%.4f dt_g=%.4f tau=%.4f Ki_rate=%.3f Ki_angle=%.3f\n', ...
        dt_controller, dt_guidance, tau_rate, Ki_rate, Ki_angle);
    fprintf('trim de_deg=[%s]\n', num2str(rad2deg(trim_elevator_table),'%+.2f '));

    scenarios = {make_x(), make_xz(), make_circle(), make_helix()};
    results = struct([]);
    dt = dt_controller;

    for k = 1:numel(scenarios)
        sc = scenarios{k};
        fprintf('\n----- [%d/%d] %s -----\n', k, numel(scenarios), sc.name);
        clear guidance_law controller_law
        state0 = initial_state(sc.path, sc.u0);
        [vp, times, vel, ~, ori, ~, yaw_refs, pitch_refs, ~] = ...
            continuous_path_tracking(sc.path, state0, dt, sc.T);
        m = metrics_from_run(sc, vp, vel, ori, yaw_refs, pitch_refs, dt);
        m.name = sc.name;
        m.tag = sc.tag;
        m.ok = true;
        m.lambda = lambda_muw_ff;
        if isempty(results); results = m; else; results(end+1) = m; end %#ok<AGROW>
        fprintf('CTE=%.3f |pitch|=%.2f chatter=%.4f deRMS=%.3f de_fbRMS=%.3f sat=%.1f%% resid=%.3f\n', ...
            m.mean_cte, m.mean_pitch_err_deg, m.pitch_chatter_dps, ...
            m.elevator_rms_deg, m.de_fb_rms_deg, m.pct_mag_sat, m.rms_M_uw_plus_Me_ff);
    end

    mat_path = fullfile(out_dir, sprintf('%s_results.mat', stage_tag));
    save(mat_path, 'results', 'stage_tag', 'lambda_val', 'dt_controller', 'dt_guidance', 'tau_rate');
    md_path = fullfile(out_dir, sprintf('%s_RESULTS.md', stage_tag));
    write_stage_md(md_path, stage_tag, lambda_val, results);
    fprintf('\nWrote %s\nWrote %s\n', md_path, mat_path);
end

function m = metrics_from_run(sc, vp, vel, ori, yaw_refs, pitch_refs, dt)
    global suite_delta_e_log suite_de_uw_ff_log suite_de_fb_log suite_de_trim_log
    global suite_M_uw_log suite_M_elev_log suite_M_e_ff_log suite_G_de_log
    global suite_e_theta_log suite_u_log suite_w_log delta_e_max

    n = size(vp, 1);
    i0 = max(1, round(2.0/dt));
    ct = zeros(n,1);
    for i = 1:n
        ct(i) = min(vecnorm(sc.path - vp(i,:), 2, 2));
    end
    pitch_err = pitch_refs(:) + ori(:,2);
    th = -ori(:,2);
    dth = [0; diff(th)] / dt;
    dth_hf = hf_sig(detrend(dth(i0:end)), dt);

    de = suite_delta_e_log(:);
    de_ff = suite_de_uw_ff_log(:);
    de_fb = suite_de_fb_log(:);
    Muw = suite_M_uw_log(:);
    Me = suite_M_elev_log(:);
    Meff = suite_M_e_ff_log(:);
    Gde = suite_G_de_log(:);
    eth = suite_e_theta_log(:);

    pct_sat = 100 * mean(abs(de(i0:end)) >= 0.95 * delta_e_max);

    m = struct( ...
        'mean_cte', mean(ct), ...
        'max_cte', max(ct), ...
        'mean_pitch_err_deg', rad2deg(mean(abs(pitch_err))), ...
        'mean_e_theta_deg', rad2deg(mean(eth(i0:end))), ...
        'pitch_chatter_dps', rad2deg(std(dth_hf)), ...
        'theta_pp_deg', rad2deg(max(th(i0:end)) - min(th(i0:end))), ...
        'elevator_rms_deg', rad2deg(rms(de)), ...
        'de_fb_rms_deg', rad2deg(rms(de_fb)), ...
        'de_ff_rms_deg', rad2deg(rms(de_ff)), ...
        'de_trim_mean_deg', rad2deg(mean(suite_de_trim_log)), ...
        'pct_mag_sat', pct_sat, ...
        'rms_M_uw', rms(Muw(i0:end)), ...
        'rms_M_elev', rms(Me(i0:end)), ...
        'rms_M_e_ff', rms(Meff(i0:end)), ...
        'rms_M_uw_plus_Me_ff', rms(Muw(i0:end) + Meff(i0:end)), ...
        'mean_G_de', mean(Gde(i0:end)), ...
        'mean_u', mean(suite_u_log(i0:end)), ...
        'rms_w', rms(suite_w_log(i0:end)), ...
        'final_u', vel(end,1), ...
        'n_samples', n, ...
        'dt', dt);
end

function y = hf_sig(x, dt)
    n = max(3, round(0.8/dt));
    lf = filter(ones(n,1)/n, 1, x(:));
    y = x(:) - lf; y(1:n) = 0;
end

function state = initial_state(path, u0)
    state = zeros(12,1);
    state(1:3) = path(1,:)';
    d = path(2,:) - path(1,:);
    state(5) = -atan2(d(3), norm(d(1:2)));
    state(6) = atan2(d(2), d(1));
    state(7) = u0;
end

function sc = make_x()
    xp = linspace(0,20,400)';
    sc = struct('name','X-line','tag','x_line','path',[xp,zeros(400,1),zeros(400,1)],'T',18,'u0',1.5);
end
function sc = make_xz()
    t = linspace(0,22,600)';
    sc = struct('name','XZ-line','tag','xz_line','path',[t,zeros(600,1),0.4*t],'T',22,'u0',1.5);
end
function sc = make_circle()
    n = 500; R = 5; th = linspace(0,2*pi,n)';
    sc = struct('name','Circle','tag','circle','path',[R*cos(th),R*sin(th),zeros(n,1)],'T',35,'u0',1.5);
end
function sc = make_helix()
    sc = struct('name','Helix','tag','helix','path',generate_balanced_helical_path(5,2,2,500),'T',45,'u0',1.5);
end

function write_stage_md(path, tag, lam, results)
    fid = fopen(path, 'w');
    fprintf(fid, '# %s — Muw feedforward λ=%.2f\n\n', tag, lam);
    fprintf(fid, 'Frozen: dt_c=0.025, dt_g=0.075, tau=0.05, Ki_rate=0, Ki_angle=0.16, Tur2.5 trim.\n');
    fprintf(fid, 'Circle r_ff / XZ guidance / yaw gains: **untouched**.\n\n');
    fprintf(fid, '| Scenario | CTE | \\|pitch\\| | chatter | de RMS | de_fb RMS | de_ff RMS | sat%% | RMS(Muw+Me_ff) |\n');
    fprintf(fid, '|----------|----:|----------:|--------:|-------:|----------:|----------:|-----:|---------------:|\n');
    for i = 1:numel(results)
        r = results(i);
        fprintf(fid, '| %s | %.3f | %.2f | %.4f | %.3f | %.3f | %.3f | %.1f | %.4f |\n', ...
            r.name, r.mean_cte, r.mean_pitch_err_deg, r.pitch_chatter_dps, ...
            r.elevator_rms_deg, r.de_fb_rms_deg, r.de_ff_rms_deg, r.pct_mag_sat, ...
            r.rms_M_uw_plus_Me_ff);
    end
    fprintf(fid, '\n### Extra\n\n');
    fprintf(fid, '| Scenario | RMS M_uw | RMS M_elev | mean G_de | rms w | mean eθ |\n');
    fprintf(fid, '|----------|---------:|-----------:|----------:|------:|---------:|\n');
    for i = 1:numel(results)
        r = results(i);
        fprintf(fid, '| %s | %.4f | %.4f | %.3f | %.4f | %+.3f |\n', ...
            r.name, r.rms_M_uw, r.rms_M_elev, r.mean_G_de, r.rms_w, r.mean_e_theta_deg);
    end
    fclose(fid);
end
