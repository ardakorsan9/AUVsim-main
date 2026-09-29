function setup_auv_path()
%SETUP_AUV_PATH  MATLAB klasorlerini path'e ekler (repo kokunden bir kez calistirin).
%
%   >> setup_auv_path
%   >> underwater777_vehicle_simulation
%
% Duzen:
%   matlab/cekirdek     - dinamik, guidance, kontrol, ana sim
%   matlab/testler      - test_*.m
%   matlab/yol_ve_cizim - yol uretimi, metrik, plot
%   matlab/codegen      - codegen sarmalayicilar
%   matlab/deneyler     - run_* / gate / audit denemeleri

    root = fileparts(mfilename('fullpath'));
    matlabRoot = fullfile(root, 'matlab');
    if ~exist(matlabRoot, 'dir')
        error('matlab/ klasoru bulunamadi: %s', matlabRoot);
    end
    addpath(genpath(matlabRoot));
    fprintf('AUV MATLAB path eklendi: %s\n', matlabRoot);
end
