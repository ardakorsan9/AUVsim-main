function run_water_current_admission_governor_rerun()
% WATER_CURRENT_ADMISSION_GOVERNOR_RERUN_001
% Authorized syntax-fix validation exception beyond Gate 4B 3/3 closure.
% Preserves suite_results/WATER_CURRENT_ADMISSION_GOVERNOR.* FAIL artifacts.
% Writes suite_results/WATER_CURRENT_ADMISSION_GOVERNOR_RERUN.{md,mat,png}.
% Declared sources only:
%   run_water_current_admission_governor.m
%   guidance_law_water_current_admission_governor.m
%   suite_results/WATER_CURRENT_FEASIBILITY_MAP.mat

    run_water_current_admission_governor('rerun');
end
