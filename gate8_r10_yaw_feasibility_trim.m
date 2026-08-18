function out = gate8_r10_yaw_feasibility_trim(op, varargin)
%GATE8_R10_YAW_FEASIBILITY_TRIM  Isolated shadow steady-turn trim engine.
%
% TASK: GATE8_R10_RAIL_AWARE_YAW_FEASIBILITY_ENVELOPE_001
%
% READ-ONLY with respect to production. The production plant
% underwater777_vehicle_dynamics.m is CALLED, never modified and never
% re-implemented here: every force, moment, added-mass and hydrostatic term
% used below is whatever the production file returns.
%
% No controller, guidance, threshold, speed envelope or path datum is read,
% written or modified by this file. There is no time integration: the
% analysis is a purely algebraic steady-turn trim, so no horizon is consumed.
%
% FRAMES / UNITS (carried verbatim from the frozen chain, not re-derived):
%   position  NED inertial [m], z positive DOWN (depth = +z)
%   velocity  BODY u,v,w [m/s];  rates BODY p,q,r [rad/s]
%   Euler     phi,theta,psi [rad] internally; deg only where a name says _deg
%   actuators delta_r, delta_e [rad] internally, production sign convention
%   thrust    native production thrust unit (Xprop, entered into the BODY X row)
%   curvature kappa [1/m] = horizontal path curvature = psi_dot / U_h
%
% STEADY LEVEL TURN DEFINITION (declared, exact):
%   unknowns x = [v; w; phi; theta; r; delta_r; delta_e; thrust]      (8)
%   given    u = U (BODY surge [m/s]), kappa (horizontal curvature [1/m])
%   the remaining body rates are NOT free; they follow from requiring
%   phi_dot = 0 and theta_dot = 0 in the production Euler kinematics:
%       q = r*tan(phi)
%       p = -tan(theta)*(sin(phi)*q + cos(phi)*r)
%   which is identically the standard steady-turn set
%       p = -psi_dot*sin(theta), q = psi_dot*cos(theta)*sin(phi),
%       r =  psi_dot*cos(theta)*cos(phi).
%   residual F (8 rows, SI) =
%       [ u_dot; v_dot; w_dot; p_dot; q_dot; r_dot;   <- production plant rows
%         z_dot;                                      <- level turn (constant depth)
%         psi_dot - kappa*U_h ]                       <- commanded curvature
%   with U_h = hypot(x_dot, y_dot) the horizontal ground speed [m/s].
%   phi_dot = 0 and theta_dot = 0 hold by construction and are verified.
%
% Operations:
%   'residual'  F = ...('residual', x, U, kappa, reduced)
%   'solve'     S = ...('solve', x0, U, kappa, reduced, DEC)
%   'stability' [emax, ev, A] = ...('stability', x, U, DEC)   (struct out)
%   'guess'     x0 = ...('guess', U, kappa)

    switch lower(op)
        case 'residual'
            [F, ok] = local_residual(varargin{1}, varargin{2}, varargin{3}, varargin{4});
            out = struct('F', F, 'ok', ok);
        case 'solve'
            out = local_solve(varargin{1}, varargin{2}, varargin{3}, varargin{4}, varargin{5});
        case 'stability'
            out = local_stability(varargin{1}, varargin{2}, varargin{3});
        case 'guess'
            out = local_guess(varargin{1}, varargin{2});
        otherwise
            error('gate8_r10_yaw_feasibility_trim: unknown op %s', op);
    end
end

% ------------------------------------------------------------------------
function x0 = local_guess(U, kappa)
% Cold analytic guess. Surge drag balance only; everything else zero.
    global Xuu
    T0 = -Xuu * U * abs(U);           % Xprop that cancels Xuu*u*|u| at v=w=0
    if ~isfinite(T0); T0 = 0; end
    x0 = [0; 0; 0; 0; kappa * U; 0; 0; T0];
end

% ------------------------------------------------------------------------
function [F, ok] = local_residual(x, U, kappa, reduced)
% Assemble the steady-turn residual by CALLING the production plant.
    if reduced
        nF = 7;
        v = x(1); w = x(2); phi = x(3); th = x(4); dr = x(5); de = x(6); T = x(7);
        r = 0;
    else
        nF = 8;
        v = x(1); w = x(2); phi = x(3); th = x(4); r = x(5); dr = x(6); de = x(7); T = x(8);
    end
    F = 1e6 * ones(nF, 1);
    ok = false;
    if any(~isfinite(x)); return; end
    % Reject region guard: keep well inside the production Euler singularity
    % guard (|cos(theta)| < 1e-3) and inside a physically meaningful attitude.
    if abs(phi) > 1.2 || abs(th) > 1.2; return; end
    if abs(dr) > 1.5 || abs(de) > 1.5; return; end

    q = r * tan(phi);
    p = -tan(th) * (sin(phi) * q + cos(phi) * r);
    g = [0; 0; 0; phi; th; 0; U; v; w; p; q; r];
    controls = struct('delta_r', dr, 'delta_e', de, 'thrust', T);
    try
        gd = underwater777_vehicle_dynamics(0, g, controls);
    catch
        return
    end
    if numel(gd) ~= 12 || any(~isfinite(gd)); return; end

    zdot   = gd(3);                      % [m/s] NED, positive DOWN
    psidot = gd(6);                      % [rad/s]
    Uh     = hypot(gd(1), gd(2));        % [m/s] horizontal ground speed
    base   = [gd(7); gd(8); gd(9); gd(10); gd(11); gd(12); zdot];
    if reduced
        F = base;
    else
        F = [base; psidot - kappa * Uh];
    end
    ok = all(isfinite(F));
    if ~ok; F = 1e6 * ones(nF, 1); end
end

% ------------------------------------------------------------------------
function S = local_solve(x0, U, kappa, reduced, DEC)
% Damped Gauss-Newton (Levenberg-Marquardt) with backtracking.
% Deterministic: no randomness, fixed iteration and step schedule.
    n = numel(x0);
    x = x0(:);
    [F, ok] = local_residual(x, U, kappa, reduced);
    nrm = norm(F, inf);
    lam = DEC.lm_lambda0;
    it = 0;
    why = 'converged';
    if ~ok
        why = 'initial_guess_rejected';
    end
    while it < DEC.newton_iter && nrm > DEC.tol_resid
        it = it + 1;
        J = zeros(numel(F), n);
        Jok = true;
        for k = 1:n
            h = DEC.fd_step * max(1, abs(x(k)));
            xp = x; xp(k) = xp(k) + h;
            [Fp, okp] = local_residual(xp, U, kappa, reduced);
            if ~okp; Jok = false; break; end
            J(:, k) = (Fp - F) / h;
        end
        if ~Jok || any(~isfinite(J(:)))
            why = 'jacobian_failed';
            break
        end
        H = J' * J;
        gv = J' * F;
        dH = diag(H);
        dH(dH < 1e-14) = 1e-14;
        accepted = false;
        for trial = 1:DEC.lm_trials
            Am = H + lam * diag(dH);
            if ~all(isfinite(Am(:))) || rcond(Am) < 1e-15
                lam = lam * 10;
                if lam > DEC.lm_lambda_max; break; end
                continue
            end
            dx = -(Am \ gv);
            if any(~isfinite(dx))
                lam = lam * 10;
                if lam > DEC.lm_lambda_max; break; end
                continue
            end
            for bt = 0:DEC.bt_steps
                xt = x + dx / (2 ^ bt);
                [Ft, okt] = local_residual(xt, U, kappa, reduced);
                if okt && norm(Ft, inf) < nrm
                    x = xt; F = Ft; nrm = norm(Ft, inf);
                    accepted = true;
                    break
                end
            end
            if accepted
                lam = max(lam / 10, DEC.lm_lambda_min);
                break
            end
            lam = lam * 10;
            if lam > DEC.lm_lambda_max; break; end
        end
        if ~accepted
            why = 'no_descent_step';
            break
        end
    end
    if nrm > DEC.tol_resid && strcmp(why, 'converged')
        why = 'iteration_limit';
    end
    S = struct();
    S.x = x;
    S.F = F;
    S.resid = nrm;
    S.iters = it;
    S.conv = (nrm <= DEC.tol_resid) && all(isfinite(x));
    S.why = why;
    S.reduced = logical(reduced);
    S.U = U;
    S.kappa = kappa;
    if reduced
        S.v = x(1); S.w = x(2); S.phi = x(3); S.theta = x(4);
        S.r = 0;    S.dr = x(5); S.de = x(6); S.thrust = x(7);
    else
        S.v = x(1); S.w = x(2); S.phi = x(3); S.theta = x(4);
        S.r = x(5); S.dr = x(6); S.de = x(7); S.thrust = x(8);
    end
    S.q = S.r * tan(S.phi);
    S.p = -tan(S.theta) * (sin(S.phi) * S.q + cos(S.phi) * S.r);
    S.dr_deg = rad2deg(S.dr);
    S.de_deg = rad2deg(S.de);
    S.beta_deg = rad2deg(atan2(S.v, U));            % BODY sideslip [deg]
    % Verified-by-construction kinematics and realised curvature.
    S.psidot = (sin(S.phi) * S.q + cos(S.phi) * S.r) / cos(S.theta);
    S.kin_resid = local_kin_check(S, U);
    S.Uh = local_uh(S, U);
    if S.Uh > 0
        S.kappa_realised = S.psidot / S.Uh;
    else
        S.kappa_realised = NaN;
    end
end

% ------------------------------------------------------------------------
function kr = local_kin_check(S, U)
% |phi_dot| + |theta_dot| at the returned trim; must be ~0 by construction.
    g = [0; 0; 0; S.phi; S.theta; 0; U; S.v; S.w; S.p; S.q; S.r];
    controls = struct('delta_r', S.dr, 'delta_e', S.de, 'thrust', S.thrust);
    try
        gd = underwater777_vehicle_dynamics(0, g, controls);
        kr = abs(gd(4)) + abs(gd(5));
    catch
        kr = NaN;
    end
end

% ------------------------------------------------------------------------
function Uh = local_uh(S, U)
    g = [0; 0; 0; S.phi; S.theta; 0; U; S.v; S.w; S.p; S.q; S.r];
    controls = struct('delta_r', S.dr, 'delta_e', S.de, 'thrust', S.thrust);
    try
        gd = underwater777_vehicle_dynamics(0, g, controls);
        Uh = hypot(gd(1), gd(2));
    catch
        Uh = NaN;
    end
end

% ------------------------------------------------------------------------
function ST = local_stability(S, U, DEC)
% Local stability of the trim in the autonomous reduced state set
%   xs = [phi theta u v w p q r]  ( = g([4 5 7 8 9 10 11 12]) )
% with the controls frozen at their trim values. Position and psi are
% excluded because the production force/moment rows do not depend on them,
% so the reduced set is genuinely autonomous and the trim is a fixed point.
    idx = [4 5 7 8 9 10 11 12];
    g0 = [0; 0; 0; S.phi; S.theta; 0; U; S.v; S.w; S.p; S.q; S.r];
    controls = struct('delta_r', S.dr, 'delta_e', S.de, 'thrust', S.thrust);
    A = zeros(8, 8);
    ok = true;
    for k = 1:8
        h = DEC.fd_step_eig * max(1, abs(g0(idx(k))));
        gp = g0; gp(idx(k)) = gp(idx(k)) + h;
        gm = g0; gm(idx(k)) = gm(idx(k)) - h;
        try
            fp = underwater777_vehicle_dynamics(0, gp, controls);
            fm = underwater777_vehicle_dynamics(0, gm, controls);
        catch
            ok = false; break
        end
        if any(~isfinite(fp)) || any(~isfinite(fm)); ok = false; break; end
        A(:, k) = (fp(idx) - fm(idx)) / (2 * h);
    end
    ST = struct();
    if ~ok || any(~isfinite(A(:)))
        ST.ok = false; ST.emax = NaN; ST.ev = nan(8, 1); ST.A = nan(8, 8);
        ST.stable = false;
        return
    end
    ev = eig(A);
    ST.ok = true;
    ST.A = A;
    ST.ev = ev;
    ST.emax = max(real(ev));
    ST.stable = (ST.emax <= DEC.eig_tol);
end
