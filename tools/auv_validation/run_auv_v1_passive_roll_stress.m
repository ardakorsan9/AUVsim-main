function run_auv_v1_passive_roll_stress(mode)
%RUN_AUV_V1_PASSIVE_ROLL_STRESS  Deterministic passive-roll screening harness.
%   Frozen V1 plant/controller: roll-rate damping only (no roll-angle loop).
%   Thin wrapper around auv_roll_validation_runner('passive_roll_stress', mode).
%
%   mode: 'smoke' (subset) or 'full' (complete matrix)

    if nargin < 1 || isempty(mode)
        mode = 'full';
    end
    auv_roll_validation_runner('passive_roll_stress', mode);
end
