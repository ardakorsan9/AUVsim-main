function generate_auv_runtime()
%GENERATE_AUV_RUNTIME Deterministic MATLAB Coder driver for runtime facade.
% PRETARGET / NOT_IN_PRODUCTION / NOT_CERTIFIED
% Emits C++ facade sources for auv_runtime_codegen_init/reset/step into
% stm32/embedded/generated/runtime/combined via one Coder project so
% all three entry points share one ABI and generated type system.

    projRoot = local_project_root();
    outRoot = fullfile(projRoot, 'stm32', 'embedded', 'generated', 'runtime');
    combinedDir = fullfile(outRoot, 'combined');

    local_fresh_output_dir(outRoot);
    mkdir(combinedDir);
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

    cfgGen = local_codegen_config();

    codegen('-config', cfgGen, '-d', combinedDir, ...
        'auv_runtime_codegen_init', '-args', {cfgType}, ...
        'auv_runtime_codegen_reset', '-args', {paramsType}, ...
        'auv_runtime_codegen_step', '-args', {paramsType, stateType, stepInType});
end

function projRoot = local_project_root()
    thisFile = mfilename('fullpath');
    projRoot = fileparts(fileparts(fileparts(thisFile)));
end

function local_fresh_output_dir(outDir)
    if exist(outDir, 'dir')
        rmdir(outDir, 's');
    end
    mkdir(outDir);
end

function cfgGen = local_codegen_config()
    cfgGen = coder.config('lib');
    cfgGen.TargetLang = 'C++';
    cfgGen.GenCodeOnly = true;
    cfgGen.FilePartitionMethod = 'SingleFile';
    cfgGen.SupportNonFinite = true;
    if isprop(cfgGen, 'EnableDynamicMemoryAllocation')
        cfgGen.EnableDynamicMemoryAllocation = false;
    elseif isprop(cfgGen, 'DynamicMemoryAllocation')
        cfgGen.DynamicMemoryAllocation = 'Off';
    else
        error('auv_codegen:NoDynamicMemoryControl', ...
            'EmbeddedCodeConfig exposes neither DynamicMemoryAllocation nor EnableDynamicMemoryAllocation.');
    end
    cfgGen.GenerateMakefile = false;
    if isprop(cfgGen, 'ReportGeneration')
        cfgGen.ReportGeneration = false;
    end
    cfgGen.HardwareImplementation.ProdHWDeviceType = 'ARM Compatible->ARM Cortex-M';
    cfgGen.HardwareImplementation.ProdBitPerChar = 8;
    cfgGen.HardwareImplementation.ProdBitPerShort = 16;
    cfgGen.HardwareImplementation.ProdBitPerInt = 32;
    cfgGen.HardwareImplementation.ProdBitPerLong = 32;
    cfgGen.HardwareImplementation.ProdBitPerPointer = 32;
    cfgGen.HardwareImplementation.ProdWordSize = 32;
    cfgGen.HardwareImplementation.ProdEndianess = 'LittleEndian';
    cfgGen.HardwareImplementation.ProdLargestAtomicInteger = 'Char';
    cfgGen.HardwareImplementation.ProdLargestAtomicFloat = 'Float';
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
