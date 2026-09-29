function verify_combined_parity(mode)
%VERIFY_COMBINED_PARITY MATLAB vs combined-codegen MEX numerical parity.
% PRETARGET / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Default mode builds a temporary MEX from auv_runtime_codegen_init/reset/step,
% executes fixed deterministic 0.025 s step sequences, and recursively compares
% every numeric/logical output field against the direct MATLAB facade.
% trust_v1 mode adds init/reset/step isolation, boundary cases, a fixed-seed
% long sequence, determinism rerun, and versioned corpus artifacts.

    if nargin < 1 || isempty(mode)
        local_run_combined_parity();
        return;
    end

    switch lower(string(mode))
        case "trust_v1"
            local_run_trust_v1();
        otherwise
            error('auv_parity:UnknownMode', 'Unsupported verify_combined_parity mode: %s.', char(mode));
    end
end

function local_run_combined_parity()
    tolerance = 1.0e-10;
    dt = 0.025;

    projRoot = local_project_root();
    addpath(genpath(fullfile(projRoot, 'matlab')));

    artifactDir = fullfile(projRoot, 'artifacts', 'parity');
    tmpMexDir = fullfile(artifactDir, 'tmp', 'mex');
    if exist(tmpMexDir, 'dir')
        rmdir(tmpMexDir, 's');
    end
    mkdir(tmpMexDir);
    local_remove_stray_mex(projRoot);

    local_build_combined_mex(projRoot, tmpMexDir);
    addpath(tmpMexDir);

    cases = local_test_cases();
    caseCount = numel(cases);
    stepCount = 0;
    maxAbsError = 0.0;

    cfg = local_example_cfg();

    for ic = 1:caseCount
        caseDef = cases{ic};
        navIn0 = local_example_nav_in();
        stepIn0 = local_example_step_in(navIn0);
        stepIn0 = local_apply_case_setup(stepIn0, caseDef);

        paramsRef = auv_runtime_codegen_init(cfg);
        stateRef = auv_runtime_codegen_reset(paramsRef);
        paramsMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_init', cfg);
        stateMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_reset', paramsMex);

        maxAbsError = max(maxAbsError, ...
            local_compare_structs(paramsRef, paramsMex, tolerance, sprintf('case%d.init.params', ic)));
        maxAbsError = max(maxAbsError, ...
            local_compare_structs(stateRef, stateMex, tolerance, sprintf('case%d.reset.state', ic)));

        for k = 1:caseDef.nSteps
            stepIn = local_step_input(stepIn0, k, dt, caseDef);
            [stateRef, outRef] = auv_runtime_codegen_step(paramsRef, stateRef, stepIn);
            [stateMex, outMex] = auv_runtime_codegen_init_mex( ...
                'auv_runtime_codegen_step', paramsMex, stateMex, stepIn);

            maxAbsError = max(maxAbsError, ...
                local_compare_structs(stateRef, stateMex, tolerance, ...
                sprintf('case%d.step%d.state', ic, k)));
            maxAbsError = max(maxAbsError, ...
                local_compare_structs(outRef, outMex, tolerance, ...
                sprintf('case%d.step%d.out', ic, k)));
        end

        stepCount = stepCount + caseDef.nSteps;
    end

    if ~exist(artifactDir, 'dir')
        mkdir(artifactDir);
    end
    local_write_pass_json(artifactDir, caseCount, stepCount, maxAbsError, tolerance);
end

function local_run_trust_v1()
    tolerance = 1.0e-10;
    dt = 0.025;
    seed = uint32(20260829);
    corpusVersion = 'v1';
    longSequenceSteps = 320;

    projRoot = local_project_root();
    addpath(genpath(fullfile(projRoot, 'matlab')));

    artifactDir = fullfile(projRoot, 'artifacts', 'parity', 'trust_v1');
    tmpMexDir = fullfile(artifactDir, 'tmp', 'mex');
    if exist(tmpMexDir, 'dir')
        rmdir(tmpMexDir, 's');
    end
    mkdir(tmpMexDir);
    local_remove_stray_mex(projRoot);

    local_build_combined_mex(projRoot, tmpMexDir);
    addpath(tmpMexDir);

    cfg = local_example_cfg();
    maxAbsError = 0.0;
    stepCount = 0;

    paramsRef = auv_runtime_codegen_init(cfg);
    paramsMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_init', cfg);
    maxAbsError = max(maxAbsError, ...
        local_compare_structs(paramsRef, paramsMex, tolerance, 'trust_v1.init.params'));
    initPass = true;

    stateRef = auv_runtime_codegen_reset(paramsRef);
    stateMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_reset', paramsMex);
    maxAbsError = max(maxAbsError, ...
        local_compare_structs(stateRef, stateMex, tolerance, 'trust_v1.reset.state'));
    resetPass = true;

    navIn0 = local_example_nav_in();
    stepIn0 = local_example_step_in(navIn0);
    trustCases = local_test_cases();
    stepIn = local_step_input(stepIn0, 1, dt, trustCases{1});
    [stateRefStep, outRef] = auv_runtime_codegen_step(paramsRef, stateRef, stepIn);
    [stateMexStep, outMex] = auv_runtime_codegen_init_mex( ...
        'auv_runtime_codegen_step', paramsMex, stateMex, stepIn);
    maxAbsError = max(maxAbsError, ...
        local_compare_structs(stateRefStep, stateMexStep, tolerance, 'trust_v1.step.state'));
    maxAbsError = max(maxAbsError, ...
        local_compare_structs(outRef, outMex, tolerance, 'trust_v1.step.out'));
    stepPass = true;
    stepCount = stepCount + 1;

    boundaryCases = local_trust_v1_boundary_cases();
    boundaryCaseCount = numel(boundaryCases);
    for ic = 1:boundaryCaseCount
        caseDef = boundaryCases{ic};
        navIn0 = local_example_nav_in();
        stepIn0 = local_example_step_in(navIn0);
        stepIn0 = local_apply_case_setup(stepIn0, caseDef);
        stepIn0 = local_apply_trust_boundary_setup(stepIn0, caseDef);

        paramsRef = auv_runtime_codegen_init(cfg);
        stateRef = auv_runtime_codegen_reset(paramsRef);
        paramsMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_init', cfg);
        stateMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_reset', paramsMex);

        maxAbsError = max(maxAbsError, ...
            local_compare_structs(paramsRef, paramsMex, tolerance, ...
            sprintf('trust_v1.boundary%d.init.params', ic)));
        maxAbsError = max(maxAbsError, ...
            local_compare_structs(stateRef, stateMex, tolerance, ...
            sprintf('trust_v1.boundary%d.reset.state', ic)));

        for k = 1:caseDef.nSteps
            stepIn = local_step_input(stepIn0, k, dt, caseDef);
            stepIn = local_apply_trust_boundary_step(stepIn, k, caseDef, seed);
            [stateRef, outRef] = auv_runtime_codegen_step(paramsRef, stateRef, stepIn);
            [stateMex, outMex] = auv_runtime_codegen_init_mex( ...
                'auv_runtime_codegen_step', paramsMex, stateMex, stepIn);

            maxAbsError = max(maxAbsError, ...
                local_compare_structs(stateRef, stateMex, tolerance, ...
                sprintf('trust_v1.boundary%d.step%d.state', ic, k)));
            maxAbsError = max(maxAbsError, ...
                local_compare_structs(outRef, outMex, tolerance, ...
                sprintf('trust_v1.boundary%d.step%d.out', ic, k)));
        end

        stepCount = stepCount + caseDef.nSteps;
    end

    [longMaxErr, longSnapshots] = local_run_trust_long_sequence( ...
        cfg, dt, seed, longSequenceSteps, tolerance, 'trust_v1.long');
    maxAbsError = max(maxAbsError, longMaxErr);
    stepCount = stepCount + longSequenceSteps;

    [detMaxErr, determinismPass] = local_run_trust_determinism( ...
        cfg, dt, seed, longSequenceSteps, tolerance, longSnapshots);
    maxAbsError = max(maxAbsError, detMaxErr);
    stepCount = stepCount + longSequenceSteps;

    caseCount = 1 + boundaryCaseCount + 2;

    if ~exist(artifactDir, 'dir')
        mkdir(artifactDir);
    end

    local_write_trust_v1_pass_json(artifactDir, struct( ...
        'corpus_version', corpusVersion, ...
        'seed', double(seed), ...
        'init_pass', initPass, ...
        'reset_pass', resetPass, ...
        'step_pass', stepPass, ...
        'boundary_case_count', boundaryCaseCount, ...
        'long_sequence_steps', longSequenceSteps, ...
        'determinism_pass', determinismPass, ...
        'case_count', caseCount, ...
        'step_count', stepCount, ...
        'max_abs_error', maxAbsError, ...
        'tolerance', tolerance));

    local_write_trust_v1_corpus(artifactDir, corpusVersion, seed, dt, tolerance, ...
        boundaryCases, longSequenceSteps, caseCount, stepCount, maxAbsError);
end

function [maxAbsError, snapshots] = local_run_trust_long_sequence(cfg, dt, seed, nSteps, tolerance, pathPrefix)
    navIn0 = local_example_nav_in();
    stepIn0 = local_example_step_in(navIn0);
    stepIn0 = local_apply_case_setup(stepIn0, struct('n_path', 4.0));

    paramsRef = auv_runtime_codegen_init(cfg);
    stateRef = auv_runtime_codegen_reset(paramsRef);
    paramsMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_init', cfg);
    stateMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_reset', paramsMex);

    maxAbsError = 0.0;
    snapshots = struct();
    snapshots.ref_states = cell(nSteps, 1);
    snapshots.ref_outs = cell(nSteps, 1);
    snapshots.mex_states = cell(nSteps, 1);
    snapshots.mex_outs = cell(nSteps, 1);

    for k = 1:nSteps
        stepIn = local_seeded_step_input(stepIn0, k, dt, seed);
        [stateRef, outRef] = auv_runtime_codegen_step(paramsRef, stateRef, stepIn);
        [stateMex, outMex] = auv_runtime_codegen_init_mex( ...
            'auv_runtime_codegen_step', paramsMex, stateMex, stepIn);

        maxAbsError = max(maxAbsError, ...
            local_compare_structs(stateRef, stateMex, tolerance, ...
            sprintf('%s.step%d.state', pathPrefix, k)));
        maxAbsError = max(maxAbsError, ...
            local_compare_structs(outRef, outMex, tolerance, ...
            sprintf('%s.step%d.out', pathPrefix, k)));

        snapshots.ref_states{k} = stateRef;
        snapshots.ref_outs{k} = outRef;
        snapshots.mex_states{k} = stateMex;
        snapshots.mex_outs{k} = outMex;
    end
end

function [maxAbsError, determinismPass] = local_run_trust_determinism(cfg, dt, seed, nSteps, tolerance, firstSnapshots)
    navIn0 = local_example_nav_in();
    stepIn0 = local_example_step_in(navIn0);
    stepIn0 = local_apply_case_setup(stepIn0, struct('n_path', 4.0));

    paramsRef = auv_runtime_codegen_init(cfg);
    stateRef = auv_runtime_codegen_reset(paramsRef);
    paramsMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_init', cfg);
    stateMex = auv_runtime_codegen_init_mex('auv_runtime_codegen_reset', paramsMex);

    maxAbsError = 0.0;
    determinismPass = true;

    for k = 1:nSteps
        stepIn = local_seeded_step_input(stepIn0, k, dt, seed);
        [stateRef, outRef] = auv_runtime_codegen_step(paramsRef, stateRef, stepIn);
        [stateMex, outMex] = auv_runtime_codegen_init_mex( ...
            'auv_runtime_codegen_step', paramsMex, stateMex, stepIn);

        maxAbsError = max(maxAbsError, ...
            local_compare_structs(stateRef, firstSnapshots.ref_states{k}, tolerance, ...
            sprintf('trust_v1.determinism.ref.state%d', k)));
        maxAbsError = max(maxAbsError, ...
            local_compare_structs(outRef, firstSnapshots.ref_outs{k}, tolerance, ...
            sprintf('trust_v1.determinism.ref.out%d', k)));
        maxAbsError = max(maxAbsError, ...
            local_compare_structs(stateMex, firstSnapshots.mex_states{k}, tolerance, ...
            sprintf('trust_v1.determinism.mex.state%d', k)));
        maxAbsError = max(maxAbsError, ...
            local_compare_structs(outMex, firstSnapshots.mex_outs{k}, tolerance, ...
            sprintf('trust_v1.determinism.mex.out%d', k)));
    end
end

function cases = local_trust_v1_boundary_cases()
    minPath = struct();
    minPath.name = 'min_path_n2';
    minPath.nSteps = 8;
    minPath.arm_request_at = 0;
    minPath.disarm_request_at = 0;
    minPath.kill_at = 0;
    minPath.n_path = 2.0;
    minPath.boundary_tag = 'min_path';

    maxPath = struct();
    maxPath.name = 'max_path_n32';
    maxPath.nSteps = 6;
    maxPath.arm_request_at = 0;
    maxPath.disarm_request_at = 0;
    maxPath.kill_at = 0;
    maxPath.n_path = 32.0;
    maxPath.boundary_tag = 'max_path';

    armThreshold = struct();
    armThreshold.name = 'arm_at_healthy_threshold';
    armThreshold.nSteps = 10;
    armThreshold.arm_request_at = 4;
    armThreshold.disarm_request_at = 0;
    armThreshold.kill_at = 0;
    armThreshold.n_path = 2.0;
    armThreshold.boundary_tag = 'arm_threshold';

    killCase = struct();
    killCase.name = 'kill_asserted';
    killCase.nSteps = 12;
    killCase.arm_request_at = 5;
    killCase.disarm_request_at = 0;
    killCase.kill_at = 9;
    killCase.n_path = 2.0;
    killCase.boundary_tag = 'kill';

    disarmEdge = struct();
    disarmEdge.name = 'disarm_immediately_after_arm';
    disarmEdge.nSteps = 14;
    disarmEdge.arm_request_at = 6;
    disarmEdge.disarm_request_at = 7;
    disarmEdge.kill_at = 0;
    disarmEdge.n_path = 2.0;
    disarmEdge.boundary_tag = 'disarm_edge';

    ratesZero = struct();
    ratesZero.name = 'zero_body_rates';
    ratesZero.nSteps = 5;
    ratesZero.arm_request_at = 0;
    ratesZero.disarm_request_at = 0;
    ratesZero.kill_at = 0;
    ratesZero.n_path = 2.0;
    ratesZero.boundary_tag = 'zero_rates';
    ratesZero.force_zero_rates = true;

    cases = {minPath, maxPath, armThreshold, killCase, disarmEdge, ratesZero};
end

function stepIn0 = local_apply_trust_boundary_setup(stepIn0, caseDef)
    if isfield(caseDef, 'n_path') && caseDef.n_path >= 32.0
        for i = 1:32
            stepIn0.path_pad(i) = double(i - 1);
            stepIn0.path_pad(32 + i) = sin(0.10 * double(i));
            stepIn0.path_pad(64 + i) = cos(0.10 * double(i));
        end
    end
end

function stepIn = local_apply_trust_boundary_step(stepIn, k, caseDef, seed)
    if isfield(caseDef, 'force_zero_rates') && caseDef.force_zero_rates
        stepIn.body_rates(:) = 0.0;
        stepIn.nav.gyro(:) = 0.0;
    end

    mix = local_seed_mix(seed, k, 17);
    stepIn.nav.quality = 0.5 + 0.5 * mix;
    stepIn.nav.stale_age = 0.001 * double(k);
end

function stepIn = local_seeded_step_input(stepIn0, k, dt, seed)
    caseDef = struct();
    caseDef.arm_request_at = 0;
    caseDef.disarm_request_at = 0;
    caseDef.kill_at = 0;
    stepIn = local_step_input(stepIn0, k, dt, caseDef);

    mixA = local_seed_mix(seed, k, 1);
    mixB = local_seed_mix(seed, k, 2);
    mixC = local_seed_mix(seed, k, 3);
    mixD = local_seed_mix(seed, k, 4);

    stepIn.arm_request = (mixA > 0.95) && (k > 20);
    stepIn.disarm_request = (mixB > 0.98) && (k > 40);
    if stepIn.disarm_request
        stepIn.arm_request = false;
    end
    stepIn.kill_asserted = (mixC > 0.995) && (k > 80);

    stepIn.nav.gyro(1) = 0.50 * mixA - 0.25;
    stepIn.nav.gyro(2) = 0.40 * mixB - 0.20;
    stepIn.nav.gyro(3) = 0.30 * mixC - 0.15;
    stepIn.nav.accel(1) = 0.20 * mixD - 0.10;
    stepIn.nav.accel(2) = 0.15 * mixA - 0.075;
    stepIn.nav.accel(3) = -9.81 + 0.10 * mixB;
    stepIn.nav.value(1) = 2.0 * mixC - 1.0;
    stepIn.nav.value(2) = 1.5 * mixD - 0.75;
    stepIn.nav.value(3) = -0.50 * mixA;

    stepIn.body_rates(1) = stepIn.nav.gyro(1);
    stepIn.body_rates(2) = stepIn.nav.gyro(2);
    stepIn.body_rates(3) = stepIn.nav.gyro(3);

    if mod(k, 7) == 0
        stepIn.accepted(:) = false;
        stepIn.accepted(1:4) = true;
    end
end

function mix = local_seed_mix(seed, k, lane)
    x = double(seed) * 1.0e-4 + double(k) * 0.013 + double(lane) * 0.071;
    mix = x - floor(x);
end

function local_write_trust_v1_pass_json(artifactDir, report)
    report.pass = true;
    jsonPath = fullfile(artifactDir, 'trust_v1_parity_pass.json');
    fid = fopen(jsonPath, 'w');
    if fid < 0
        error('auv_parity:WriteFailed', 'Unable to write %s.', jsonPath);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(report));
end

function local_write_trust_v1_corpus(artifactDir, corpusVersion, seed, dt, tolerance, ...
        boundaryCases, longSequenceSteps, caseCount, stepCount, maxAbsError)
    corpus = struct();
    corpus.corpus_version = corpusVersion;
    corpus.seed = double(seed);
    corpus.dt = dt;
    corpus.tolerance = tolerance;
    corpus.long_sequence_steps = longSequenceSteps;
    corpus.case_count = caseCount;
    corpus.step_count = stepCount;
    corpus.max_abs_error = maxAbsError;

    boundaryMeta = cell(numel(boundaryCases), 1);
    for i = 1:numel(boundaryCases)
        caseDef = boundaryCases{i};
        boundaryMeta{i} = struct( ...
            'name', caseDef.name, ...
            'boundary_tag', caseDef.boundary_tag, ...
            'n_steps', caseDef.nSteps, ...
            'n_path', caseDef.n_path, ...
            'arm_request_at', caseDef.arm_request_at, ...
            'disarm_request_at', caseDef.disarm_request_at, ...
            'kill_at', caseDef.kill_at);
    end
    corpus.boundary_cases = [boundaryMeta{:}];

    jsonPath = fullfile(artifactDir, sprintf('trust_v1_corpus_%s.json', corpusVersion));
    fid = fopen(jsonPath, 'w');
    if fid < 0
        error('auv_parity:WriteFailed', 'Unable to write %s.', jsonPath);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(corpus));
end

function projRoot = local_project_root()
    thisFile = mfilename('fullpath');
    projRoot = fileparts(fileparts(fileparts(thisFile)));
end

function local_remove_stray_mex(projRoot)
    stray = fullfile(projRoot, 'auv_runtime_codegen_init_mex.mexw64');
    if exist(stray, 'file')
        delete(stray);
    end
end

function local_build_combined_mex(projRoot, outDir)
    addpath(genpath(fullfile(projRoot, 'matlab')));

    cfg = local_example_cfg();
    params = auv_runtime_codegen_init(cfg);
    state = auv_runtime_codegen_reset(params);
    navIn = local_example_nav_in();
    stepIn = local_example_step_in(navIn);

    cfgType = coder.typeof(cfg);
    paramsType = coder.typeof(params);
    stateType = coder.typeof(state);
    stepInType = coder.typeof(stepIn);

    cfgGen = coder.config('mex');
    if isprop(cfgGen, 'SupportNonFinite')
        cfgGen.SupportNonFinite = true;
    end
    if isprop(cfgGen, 'EnableDynamicMemoryAllocation')
        cfgGen.EnableDynamicMemoryAllocation = false;
    elseif isprop(cfgGen, 'DynamicMemoryAllocation')
        cfgGen.DynamicMemoryAllocation = 'Off';
    else
        error('auv_parity:NoDynamicMemoryControl', ...
            'EmbeddedCodeConfig exposes neither DynamicMemoryAllocation nor EnableDynamicMemoryAllocation.');
    end

    prevDir = cd(outDir);
    restoreDir = onCleanup(@() cd(prevDir)); %#ok<NASGU>
    codegen('-config', cfgGen, '-d', outDir, ...
        'auv_runtime_codegen_init', '-args', {cfgType}, ...
        'auv_runtime_codegen_reset', '-args', {paramsType}, ...
        'auv_runtime_codegen_step', '-args', {paramsType, stateType, stepInType});
end

function cases = local_test_cases()
    baseline = struct();
    baseline.name = 'baseline_hold';
    baseline.nSteps = 12;
    baseline.arm_request_at = 0;
    baseline.disarm_request_at = 0;
    baseline.kill_at = 0;
    baseline.n_path = 2.0;

    armSeq = struct();
    armSeq.name = 'arm_after_healthy';
    armSeq.nSteps = 16;
    armSeq.arm_request_at = 6;
    armSeq.disarm_request_at = 0;
    armSeq.kill_at = 0;
    armSeq.n_path = 2.0;

    disarmSeq = struct();
    disarmSeq.name = 'arm_then_disarm';
    disarmSeq.nSteps = 18;
    disarmSeq.arm_request_at = 5;
    disarmSeq.disarm_request_at = 12;
    disarmSeq.kill_at = 0;
    disarmSeq.n_path = 2.0;

    pathCase = struct();
    pathCase.name = 'four_point_path';
    pathCase.nSteps = 15;
    pathCase.arm_request_at = 0;
    pathCase.disarm_request_at = 0;
    pathCase.kill_at = 0;
    pathCase.n_path = 4.0;

    cases = {baseline, armSeq, disarmSeq, pathCase};
end

function stepIn0 = local_apply_case_setup(stepIn0, caseDef)
    stepIn0.n_path = caseDef.n_path;
    if caseDef.n_path >= 4.0
        stepIn0.path_pad(1) = 0.0;
        stepIn0.path_pad(2) = 2.0;
        stepIn0.path_pad(3) = 0.0;
        stepIn0.path_pad(4) = 2.0;
        stepIn0.path_pad(5) = 4.0;
        stepIn0.path_pad(6) = 0.0;
        stepIn0.path_pad(7) = 6.0;
        stepIn0.path_pad(8) = -1.0;
        stepIn0.path_pad(9) = 0.0;
        stepIn0.path_pad(10) = 8.0;
        stepIn0.path_pad(11) = 1.0;
        stepIn0.path_pad(12) = 0.0;
    end
end

function stepIn = local_step_input(stepIn0, k, dt, caseDef)
    stepIn = stepIn0;
    t = (k - 1) * dt;

    stepIn.t = t;
    stepIn.tick_seq = uint32(k);
    stepIn.sample_valid = true;
    stepIn.arm_request = false;
    stepIn.disarm_request = false;
    stepIn.kill_asserted = false;

    if caseDef.arm_request_at > 0 && k >= caseDef.arm_request_at
        stepIn.arm_request = true;
    end
    if caseDef.disarm_request_at > 0 && k >= caseDef.disarm_request_at
        stepIn.disarm_request = true;
        stepIn.arm_request = false;
    end
    if caseDef.kill_at > 0 && k >= caseDef.kill_at
        stepIn.kill_asserted = true;
    end

    stepIn.nav.t = t;
    stepIn.nav.sample_valid = true;
    stepIn.nav.gyro_timestamp = t;
    stepIn.nav.accel_timestamp = t;
    stepIn.nav.timestamp = t;
    stepIn.nav.gyro_seq = uint32(k);
    stepIn.nav.accel_seq = uint32(k);
    stepIn.nav.seq = uint32(k);

    stepIn.nav.gyro(1) = 0.010 * sin(0.10 * k);
    stepIn.nav.gyro(2) = 0.020 * cos(0.10 * k);
    stepIn.nav.gyro(3) = 0.005 * sin(0.20 * k);
    stepIn.nav.accel(1) = 0.05 * sin(0.05 * k);
    stepIn.nav.accel(2) = 0.03 * cos(0.07 * k);
    stepIn.nav.accel(3) = -9.81 + 0.02 * sin(0.11 * k);
    stepIn.nav.value(1) = 0.10 * k;
    stepIn.nav.value(2) = 0.05 * k;
    stepIn.nav.value(3) = -0.20 * k;

    stepIn.body_rates(1) = stepIn.nav.gyro(1);
    stepIn.body_rates(2) = stepIn.nav.gyro(2);
    stepIn.body_rates(3) = stepIn.nav.gyro(3);

    stepIn.accepted(:) = true;
end

function maxAbsError = local_compare_structs(a, b, tolerance, path)
    if ~isstruct(a) || ~isstruct(b)
        error('auv_parity:TypeMismatch', 'Expected struct at %s.', path);
    end
    if ~strcmp(class(a), class(b))
        error('auv_parity:ClassMismatch', 'Class mismatch at %s: %s vs %s.', ...
            path, class(a), class(b));
    end

    fieldsA = fieldnames(a);
    fieldsB = fieldnames(b);
    if ~isequal(fieldsA, fieldsB)
        error('auv_parity:FieldMismatch', 'Field mismatch at %s.', path);
    end

    maxAbsError = 0.0;
    for i = 1:numel(fieldsA)
        name = fieldsA{i};
        childPath = sprintf('%s.%s', path, name);
        maxAbsError = max(maxAbsError, ...
            local_compare_values(a.(name), b.(name), tolerance, childPath));
    end
end

function maxAbsError = local_compare_values(a, b, tolerance, path)
    if isstruct(a)
        maxAbsError = local_compare_structs(a, b, tolerance, path);
        return;
    end

    if islogical(a) || ischar(a) || isstring(a)
        if ~isequal(a, b)
            error('auv_parity:ValueMismatch', 'Logical/char mismatch at %s.', path);
        end
        maxAbsError = 0.0;
        return;
    end

    if isnumeric(a)
        if ~isnumeric(b)
            error('auv_parity:TypeMismatch', 'Numeric type mismatch at %s.', path);
        end
        if ~isequal(size(a), size(b))
            error('auv_parity:SizeMismatch', 'Size mismatch at %s.', path);
        end
        if isinteger(a) || isinteger(b)
            if ~isequal(a, b)
                error('auv_parity:IntegerMismatch', 'Integer mismatch at %s.', path);
            end
            maxAbsError = 0.0;
            return;
        end

        aVec = double(a(:));
        bVec = double(b(:));
        if any(~isfinite(aVec))
            error('auv_parity:NonFiniteRef', 'Non-finite reference value at %s.', path);
        end
        if any(~isfinite(bVec))
            error('auv_parity:NonFiniteMex', 'Non-finite MEX value at %s.', path);
        end

        absErr = abs(aVec - bVec);
        maxAbsError = max(absErr);
        if maxAbsError > tolerance
            error('auv_parity:NumericMismatch', ...
                'Numeric mismatch at %s: max abs error %g > tolerance %g.', ...
                path, maxAbsError, tolerance);
        end
        return;
    end

    error('auv_parity:UnsupportedType', 'Unsupported type at %s: %s.', path, class(a));
end

function local_write_pass_json(artifactDir, caseCount, stepCount, maxAbsError, tolerance)
    report = struct();
    report.pass = true;
    report.case_count = caseCount;
    report.step_count = stepCount;
    report.max_abs_error = maxAbsError;
    report.tolerance = tolerance;

    jsonPath = fullfile(artifactDir, 'combined_parity_pass.json');
    fid = fopen(jsonPath, 'w');
    if fid < 0
        error('auv_parity:WriteFailed', 'Unable to write %s.', jsonPath);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonencode(report));
end

function cfg = local_example_cfg()
    cfg = struct();
    cfg.controller = local_example_controller_cfg();
    cfg.guidance = local_example_guidance_cfg();
    cfg.availability = local_example_availability_cfg();
    cfg.fdir = local_example_fdir_cfg();
    cfg.safe_thrust = 50.0;
end

function c = local_example_controller_cfg()
    c = struct();
    c.Kp_psi = 32.0;
    c.Kd_psi = 13.0;
    c.Kp_x = 25.0;
    c.Kp_roll = 2.0;
    c.Kp_angle = 1.5;
    c.Ki_angle = 0.5;
    c.Kp_rate = 2.0;
    c.Ki_rate = 0.3;
    c.Kaw_pitch = 1.0;
    c.Kd_rate = 0.1;
    c.Kd_damp = 0.05;
    c.delta_r_max = deg2rad(35.0);
    c.delta_e_max = deg2rad(25.0);
    c.thrust_max = 100.0;
    c.thrust_min = 0.0;
    c.thrust_trim = 50.0;
    c.trim_speed_table = [0.8, 1.0, 1.5, 2.0];
    c.trim_elevator_table = [0.0, 0.05, 0.10, 0.15];
    c.elevator_sign = 1.0;
    c.dt_controller = 0.025;
    c.tau_rate = 0.10;
    c.Muw = 0.0;
    c.Muuds = 0.0;
    c.lambda_muw_ff = 0.0;
    c.muw_ff_u_min = 0.1;
    c.muw_ff_u_lo = 0.5;
    c.muw_ff_u_hi = 1.5;
    c.muw_ff_clamp_deg = 5.0;
    c.delta_e_trim = 0.0;
    c.k_gamma_climb = 0.0;
    c.de_climb_lim = deg2rad(5.0);
    c.slew_max_rad_s = deg2rad(40.0);
end

function g = local_example_guidance_cfg()
    g = struct();
    g.MAX_PATH_POINTS = 32;
    g.lookahead_distance = 5.0;
    g.desired_speed = 1.5;
    g.pitch_ref_max = 0.60;
    g.pitch_ref_rate_max = 0.30;
    g.dt_guidance = 0.075;
    g.dt_controller = 0.025;
    g.K_zdot = 0.50;
    g.K_gamma = 0.50;
    g.enable_alpha_hat = false;
    g.k_beta = 1.0;
    g.closed_eps = 0.25;
    g.near_end_margin = 2.0;
    g.mono_back_max = 0.15;
    g.s_back_tol = 0.10;
    g.yaw_slew_max_rad_s = 0.80;
    g.r_ff_max_rad_s = 0.60;
    g.pitch_corr_max = 0.30;
    g.z_e_i_max = 1.0;
    g.alpha_hat_max = 0.50;
end

function a = local_example_availability_cfg()
    a = struct();
    a.present = true(7, 1);
    a.period = [0.025; 0.025; 0.100; 0.100; 0.100; 0.200; 1.000];
    a.stale_limit = [0.050; 0.050; 0.200; 0.200; 0.200; 0.400; 2.000];
end

function f = local_example_fdir_cfg()
    f = struct();
    f.G_nom = 0.05;
    f.thr_B2 = 0.25;
    f.eps_dr_rad = deg2rad(0.5);
    f.u_floor = 0.20;
    f.t_warmup_s = 2.0;
    f.Np = 5.0;
    f.persist_s = 0.125;
    f.dt = 0.025;
end

function navIn = local_example_nav_in()
    navIn = struct();
    navIn.op = uint8(0);
    navIn.sample_valid = true;
    navIn.t = 0.0;
    navIn.init_gyro = zeros(3, 1);
    navIn.init_accel = [0.0; 0.0; -9.81];
    navIn.init_depth = 0.0;
    navIn.init_heading = 0.0;
    navIn.init_ins_vel = zeros(3, 1);
    navIn.init_timestamp = zeros(5, 1);
    navIn.init_seq = ones(5, 1);
    navIn.abs_position_present = false;
    navIn.gyro = zeros(3, 1);
    navIn.accel = [0.0; 0.0; -9.81];
    navIn.gyro_timestamp = 0.0;
    navIn.accel_timestamp = 0.0;
    navIn.gyro_seq = uint32(1);
    navIn.accel_seq = uint32(1);
    navIn.channel = uint8(3);
    navIn.dim = uint8(1);
    navIn.present = true;
    navIn.packet_valid = true;
    navIn.status = uint8(2);
    navIn.value = zeros(3, 1);
    navIn.timestamp = 0.0;
    navIn.quality = 1.0;
    navIn.stale_age = 0.0;
    navIn.bound_lo = zeros(3, 1);
    navIn.bound_hi = ones(3, 1) * 1.0e6;
    navIn.q_nom = 1.0;
    navIn.stale_limit_s = 1.0;
    navIn.seq = uint32(1);
end

function stepIn = local_example_step_in(navIn)
    stepIn = struct();
    stepIn.t = 0.0;
    stepIn.tick_seq = uint32(1);
    stepIn.sample_valid = true;
    stepIn.arm_request = false;
    stepIn.disarm_request = false;
    stepIn.kill_asserted = false;
    stepIn.nav = navIn;
    stepIn.path_pad = zeros(96, 1);
    stepIn.path_pad(1) = 0.0;
    stepIn.path_pad(2) = 1.0;
    stepIn.path_pad(3) = 0.0;
    stepIn.path_pad(4) = 0.0;
    stepIn.path_pad(5) = 0.0;
    stepIn.path_pad(6) = 0.0;
    stepIn.n_path = 2.0;
    stepIn.body_rates = zeros(3, 1);
    stepIn.accepted = false(7, 1);
end
