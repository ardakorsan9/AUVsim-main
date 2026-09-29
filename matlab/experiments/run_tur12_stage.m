function run_tur12_stage(stage_tag, do_calibrate, n_repeat)
% RUN_TUR12_STAGE  Calibrate (optional), run path suite n_repeat times, save metrics.
% stage_tag e.g. 'T1A', 'T1B', 'T2A', 'T2B-1'
    if nargin < 2 || isempty(do_calibrate); do_calibrate = true; end
    if nargin < 3 || isempty(n_repeat); n_repeat = 2; end

    project_dir = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(project_dir, 'matlab')));
    out_dir = fullfile(project_dir, 'suite_results');
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    clear functions
    clear guidance_law controller_law
    init_parameters();
    global dt_controller dt_guidance tau_rate Ki_rate

    all_runs = cell(n_repeat, 1);
    for i = 1:n_repeat
        cal = do_calibrate && (i == 1);
        fprintf('\n######## %s RUN %d/%d  cal=%d ########\n', stage_tag, i, n_repeat, cal);
        clear functions
        clear guidance_law controller_law
        r = run_path_suite(cal);
        all_runs{i} = r;
        % Persist summary copy per run
        src = fullfile(out_dir, 'summary.txt');
        dst = fullfile(out_dir, sprintf('%s_run%d_summary.txt', stage_tag, i));
        copyfile(src, dst);
    end

    mat_path = fullfile(out_dir, sprintf('%s_runs.mat', stage_tag));
    save(mat_path, 'all_runs', 'stage_tag', 'dt_controller', 'dt_guidance', 'tau_rate', 'Ki_rate');
    fprintf('\nSaved %s\n', mat_path);
    fprintf('dt_controller=%.4f dt_guidance=%.4f tau_rate=%.4f Ki_rate=%.4f\n', ...
        dt_controller, dt_guidance, tau_rate, Ki_rate);
end
