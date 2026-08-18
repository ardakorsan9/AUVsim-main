%[SEAM-BEGIN]
function [gdot, info] = gate8_shadow_plant_seam(t, g, controls, seam)
% GATE8_SHADOW_PLANT_SEAM
% GATE8_FROZEN_CELL_PLANT_SEAM_CLOSURE_001 read-only shadow plant seam.
%
% WHAT THIS IS
%   A read-only WRAPPER around production underwater777_vehicle_dynamics.m that
%   exposes the seven HG11 plant priors:
%       cg_dx, cg_dy, cg_dz   [m]  independent CG offsets, +/-0.02 m
%       cb_dx, cb_dy, cb_dz   [m]  independent CB offsets, +/-0.02 m
%       buoyancy_frac         [-]  buoyancy scale, +/-3%
%   Production is never read as a reasoning source, never edited and never
%   copied here: it is CALLED. Every line of seam logic lives inside a marked
%   %[SEAM-BEGIN]/%[SEAM-END] region and the single unmarked statement is a
%   verbatim call to production.
%
% WHAT THIS IS NOT
%   It is NOT the source-level clone that source #1 (continuous_path_tracking_
%   propulsion.m) is for continuous_path_tracking.m. A true clone would require
%   reading underwater777_vehicle_dynamics.m, which is a fourth source and is
%   outside this task's declared 3-source budget. See R.hg11 in the driver.
%
% REDUCTION CONTRACT (both halves are checked by the driver before scoring)
%   M1 mechanical : with every %[SEAM-*] region deleted, the body is exactly
%                   "gdot = underwater777_vehicle_dynamics(t, g, controls);"
%                   i.e. an identity pass-through, and the zero-offset branch
%                   short-circuits with RETURN before any arithmetic executes.
%   M2 numerical  : seam inactive or all-zero offsets => gdot is bit-identical
%                   to production over the whole probe grid (isequaln on the
%                   raw doubles, not a tolerance compare).
%
% FRAMES / UNITS (frozen, INTERFACE_SPECIFIED, not re-derived here)
%   g      = [x y z phi theta psi u v w p q r]', NED position [m] with z DOWN,
%            Euler angles [rad], BODY velocities [m/s], BODY rates [rad/s].
%   gdot(7:12) are BODY accelerations [m/s^2, rad/s^2].
%   Offsets are BODY-frame [m]; buoyancy_frac is dimensionless.
%
% SCOREABILITY
%   seam.scoreable is FALSE unless seam.BG_source is 'IDENTIFIED'. The
%   hydrostatic response of the production plant is observable from the outside
%   only up to the unknown scalar BG = (z_g*W - z_b*B)/W, so a non-zero offset
%   cannot be injected at a KNOWN magnitude from a black-box seam. This wrapper
%   therefore exercises the mechanism and proves the reduction, but the driver
%   refuses to score any gate from its non-zero-offset output.
%[SEAM-ORIG] function gdot = underwater777_vehicle_dynamics(t, g, controls)
%[SEAM-END]

    gdot = underwater777_vehicle_dynamics(t, g, controls);

%[SEAM-BEGIN]
    info = struct('applied', false, 'scoreable', false, 'delta', zeros(6, 1), ...
        'reason', 'inactive');

    if nargin < 4 || isempty(seam) || ~isstruct(seam) || ~seam.active
        return
    end

    dp = [seam.cg_dx, seam.cg_dy, seam.cg_dz, ...
          seam.cb_dx, seam.cb_dy, seam.cb_dz, seam.buoyancy_frac];
    if all(dp == 0)
        % Exact zero-offset reduction: no arithmetic touches gdot at all.
        info.reason = 'zero_offset_exact_reduction';
        return
    end

    % --- Perturbation of the hydrostatic restoring wrench -------------------
    % Fossen restoring wrench, BODY frame, g_eta(eta) = G(eta)*p with
    %   p = [W-B ; x_g*W - x_b*B ; y_g*W - y_b*B ; z_g*W - z_b*B].
    % A CG/CB/buoyancy perturbation changes p by dpar and nothing else, so the
    % required correction to the BODY acceleration is  -M^{-1} * G(eta) * dpar.
    phi = g(4); th = g(5);
    s = sin(th); c1 = cos(th) * sin(phi); c2 = cos(th) * cos(phi);

    W = seam.W_assumed; B = seam.B_assumed;
    d0 = -seam.buoyancy_frac * B;                       % delta(W-B)
    dX =  W * seam.cg_dx - B * seam.cb_dx - seam.buoyancy_frac * B * seam.xb_assumed;
    dY =  W * seam.cg_dy - B * seam.cb_dy - seam.buoyancy_frac * B * seam.yb_assumed;
    dZ =  W * seam.cg_dz - B * seam.cb_dz - seam.buoyancy_frac * B * seam.zb_assumed;

    dg = [ d0 * s; -d0 * c1; -d0 * c2; ...
          -dY * c2 + dZ * c1; ...
           dX * c2 + dZ * s; ...
          -dX * c1 - dY * s ];

    % M^{-1} is NOT identifiable from outside the plant (see driver HG11 probe:
    % the hydrostatic wrench produces no yaw moment, so column 6 is structurally
    % unobservable, and the observable columns carry the unknown scale factor).
    % seam.Ninv is therefore a DECLARED, ASSUMED reconstruction, never fitted
    % to data and never promoted to IDENTIFIED.
    info.delta = -seam.Ninv * dg;
    gdot(7:12) = gdot(7:12) + reshape(info.delta, size(gdot(7:12)));
    info.applied = true;
    info.scoreable = strcmp(seam.BG_source, 'IDENTIFIED');
    info.reason = 'assumed_Ninv_not_identifiable_from_black_box_seam';
%[SEAM-END]
end
