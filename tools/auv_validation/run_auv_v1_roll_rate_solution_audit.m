function run_auv_v1_roll_rate_solution_audit(mode)
%RUN_AUV_V1_ROLL_RATE_SOLUTION_AUDIT  SIM10 roll-rate risk + shadow solution audit.
%   Thin wrapper around auv_roll_validation_runner('roll_rate_solution_audit', mode).
%
%   mode: 'smoke' (subset) or 'full' (complete matrix + all shadows)

    if nargin < 1 || isempty(mode)
        mode = 'full';
    end
    auv_roll_validation_runner('roll_rate_solution_audit', mode);
end
