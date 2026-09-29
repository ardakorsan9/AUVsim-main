function setup_auv_path()
%SETUP_AUV_PATH  Add MATLAB folders to the path (run once from repo root).
%
%   >> setup_auv_path
%   >> underwater777_vehicle_simulation
%
% Layout:
%   matlab/core         - dynamics, guidance, control, main sim
%   matlab/tests        - test_*.m
%   matlab/path_plot    - path generation, metrics, plots
%   matlab/codegen      - codegen wrappers
%   matlab/experiments  - run_* / gate / audit experiments

    root = fileparts(mfilename('fullpath'));
    matlabRoot = fullfile(root, 'matlab');
    if ~exist(matlabRoot, 'dir')
        error('matlab/ folder not found: %s', matlabRoot);
    end
    addpath(genpath(matlabRoot));
    fprintf('AUV MATLAB path added: %s\n', matlabRoot);
end
