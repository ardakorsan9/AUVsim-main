function C = propulsion_power_compute_case()
%PROPULSION_POWER_COMPUTE_CASE  Frozen declarations for PROPULSION_POWER_COMPUTE_BASELINE_001.
%
% Gate6 isolated propulsion / power / compute budget. NO PROMOTION.
% SIMULATION_ONLY / NOT_CERTIFIED. Gate4 evidence is shadow-only here.
%
% Everything in this file is PREDECLARED and FROZEN before any simulation:
%   - route/speed cases
%   - ASSUMED thruster variants (ideal, nominal lag/map, slow+low-authority,
%     high-authority)
%   - component-neutral energy model parameter RANGES
%   - gate thresholds (existing frozen gate set + thrust/battery/compute gates)
% No number here is tuned against a result. Every hardware quantity is
% ASSUMED or TO_BE_IDENTIFIED and is emitted as a RANGE; nothing selects,
% qualifies or endorses a vendor part.
%
% Read-only sources permitted for this task (exactly three):
%   run_speed_envelope_audit.m, controller_law.m, underwater777_vehicle_dynamics.m
%
% Driver: run_propulsion_power_compute_baseline.m

    C = struct();
    C.task_id      = 'PROPULSION_POWER_COMPUTE_BASELINE_001';
    C.gate         = 'GATE6_PROPULSION_POWER_COMPUTE';
    C.promotion    = 'NONE (isolated budget study; production untouched)';
    C.certification= 'SIMULATION_ONLY / NOT_CERTIFIED';
    C.gate4_status = 'SHADOW_ONLY (no gating authority in this task)';
    C.hardware     = 'ASSUMED / TO_BE_IDENTIFIED (ranges only; no vendor choice)';
    C.compute_scope= 'call rates/counts + host runtime ONLY. NOT WCET, NOT schedulability.';
    C.seed         = 0;

    %% ---------------- routes / speed cases (predeclared) ----------------
    R = struct('name', {}, 'kind', {}, 'T_final', {}, 'lambda_muw_ff', {}, ...
               'U', {}, 'R_helix', {}, 'slope', {}, 'gate_key', {});
    R(1).name = 'X';   R(1).kind = 'straight'; R(1).T_final = 18;
    R(1).lambda_muw_ff = 0.25; R(1).U = [1.0 1.5 2.0];
    R(1).R_helix = 0;  R(1).slope = 0.0;  R(1).gate_key = 'X';
    R(2).name = 'XZ';  R(2).kind = 'straight'; R(2).T_final = 22;
    R(2).lambda_muw_ff = 0.0;  R(2).U = [1.0 1.5 2.0];
    R(2).R_helix = 0;  R(2).slope = 0.4;  R(2).gate_key = 'XZ';
    R(3).name = 'R10'; R(3).kind = 'helix';    R(3).T_final = 45;
    R(3).lambda_muw_ff = 0.25; R(3).U = [1.5 2.0];
    R(3).R_helix = 10.0; R(3).slope = NaN;  R(3).gate_key = 'H';
    C.routes = R;
    C.helix_args = [10.0 2.0 2 500];   % generate_balanced_helical_path(R, pitch, turns, n)

    %% ---------------- ASSUMED thruster variants (predeclared) -----------
    % Applied to the THRUST channel only (fins keep the frozen production
    % magnitude/rate limits inside controller_law).
    %   gain        : thrust-map / authority scale  [-]   (realized = gain*cmd)
    %   tau_s       : first-order propulsion lag    [s]
    %   rate_max    : slew limit on realized thrust [N/s]
    %   deadband_N  : command hold band             [N]
    V = struct('name', {}, 'label', {}, 'gain', {}, 'tau_s', {}, ...
               'rate_max_Nps', {}, 'deadband_N', {}, 'provenance', {}, 'note', {});
    V(1).name='ideal';     V(1).label='ideal (identity)';
    V(1).gain=1.00; V(1).tau_s=0.00; V(1).rate_max_Nps=Inf; V(1).deadband_N=0.00;
    V(1).provenance='EXACT_IDENTITY'; V(1).note='parity reference: structural pass-through';
    V(2).name='nominal';   V(2).label='nominal lag/map';
    V(2).gain=1.00; V(2).tau_s=0.30; V(2).rate_max_Nps=8.0; V(2).deadband_N=0.02;
    V(2).provenance='ASSUMED'; V(2).note='mid-range brushless propulsor, TO_BE_IDENTIFIED';
    V(3).name='slow_low';  V(3).label='slow + low authority';
    V(3).gain=0.85; V(3).tau_s=0.60; V(3).rate_max_Nps=4.0; V(3).deadband_N=0.05;
    V(3).provenance='ASSUMED'; V(3).note='pessimistic corner (fouling / derate / heavy inertia)';
    V(4).name='fast_high'; V(4).label='high authority';
    V(4).gain=1.15; V(4).tau_s=0.15; V(4).rate_max_Nps=16.0; V(4).deadband_N=0.01;
    V(4).provenance='ASSUMED'; V(4).note='optimistic corner (oversized propulsor)';
    C.variants = V;
    C.parity_variant = 'ideal';

    %% ---------------- component-neutral energy model (RANGES) -----------
    E = struct();
    E.rho_kgm3         = 1025;          % seawater density (ASSUMED, fixed)
    E.disk_D_m         = [0.10 0.18];   % propulsor disk diameter        TO_BE_IDENTIFIED
    E.eta_prop         = [0.45 0.70];   % propeller/duct efficiency      TO_BE_IDENTIFIED
    E.eta_motor        = [0.75 0.90];   % motor efficiency               TO_BE_IDENTIFIED
    E.eta_esc          = [0.90 0.97];   % drive/ESC efficiency           TO_BE_IDENTIFIED
    E.P_avionics_W     = [8 25];        % compute + sensors + hotel load TO_BE_IDENTIFIED
    E.P_fin_hold_W     = [0.5 2.0];     % per-vehicle fin servo holding  TO_BE_IDENTIFIED
    E.P_fin_move_W     = [3.0 12.0];    % per-vehicle fin servo slewing  TO_BE_IDENTIFIED
    E.fin_move_frac    = 0.05;          % |rate| > 5% of rate limit == "moving"
    E.batt_usable_Wh   = [150 600];     % USABLE energy (after DoD/derate) TO_BE_IDENTIFIED
    E.V_bus_V          = [22.2 29.4];   % DC bus operating window         TO_BE_IDENTIFIED
    E.I_cont_max_A     = [15 40];       % continuous bus current limit    TO_BE_IDENTIFIED
    E.mission_km       = 1.0;           % reference mission distance for Wh scaling (ASSUMED)
    E.note = ['Actuator-disk momentum theory gives the ideal (lower-bound) ', ...
              'hydrodynamic power for the realized thrust; electrical power is ', ...
              'that bound divided by an efficiency-chain range, plus avionics ', ...
              'and fin-servo loads. Component-neutral: no vendor, no part number.'];
    C.energy = E;

    %% ---------------- compute-evidence declarations ---------------------
    K = struct();
    K.controller_rate_source = 'global dt_controller (frozen)';
    K.guidance_rate_source   = 'global dt_guidance (frozen)';
    K.counted = {'guidance_law calls', 'controller_law calls', ...
                 'underwater777_vehicle_dynamics RHS evaluations', ...
                 'integrator steps'};
    K.timing  = 'host wall-clock per control step (mean/p95/max). NOT WCET.';
    K.disclaimer = ['Host runtime on a general-purpose OS is NOT a worst-case ', ...
                    'execution time and carries no real-time guarantee. WCET ', ...
                    'remains TO_BE_IDENTIFIED on target hardware.'];
    C.compute = K;

    %% ---------------- gates (existing frozen set + Gate6 additions) -----
    % Existing tracking/actuator hard gates are copied verbatim from the frozen
    % SPEED_ENVELOPE_AUDIT_001 absolute set. No threshold is re-tuned here.
    HG = struct();
    HG.X.pitch_mae  = 0.10; HG.X.pitch_p95  = 0.50; HG.X.gamma_mae  = 0.50; HG.X.gamma_p95  = 1.00;
    HG.XZ.pitch_mae = 0.30; HG.XZ.pitch_p95 = 0.50; HG.XZ.gamma_mae = 1.00; HG.XZ.gamma_p95 = 1.50;
    HG.H.pitch_mae  = 0.30; HG.H.pitch_p95  = 0.50; HG.H.gamma_mae  = 1.50; HG.H.gamma_p95  = 2.50;
    HG.H.yaw_mae    = 1.0;  HG.H.yaw_p95    = 2.0;
    HG.XZ_yaw_mae   = 0.50; HG.X_yaw_mae    = 0.50;
    HG.elev_sat = 1.0; HG.rud_sat_ss = 1.0; HG.rud_sat_full = 1.0;
    HG.chatter = 0.20; HG.ratio_lo = 0.98; HG.ratio_hi = 1.02;
    HG.rate_util = 1.0; HG.thrust_sat = 1.0;
    HG.phi_eq = struct('X', 0.0, 'XZ', 0.0, 'H', 0.0255);
    HG.provenance = 'SPEED_ENVELOPE_AUDIT_001 absolute hard gates (verbatim, frozen)';
    C.HG = HG;

    G = struct();
    G.parity_tol      = 0.0;    % ideal variant must be BITWISE identical to bypass
    G.replay_tol      = 0.0;    % re-run of the same case must be BITWISE identical
    G.thrust_mag_tol  = 1e-9;   % realized thrust inside [thrust_min, thrust_max]
    G.thrust_rate_tol = 1e-6;   % realized |dT/dt| <= variant rate_max (relative)
    G.speed_gated     = false;  % NOTE: the frozen gate set contains NO speed-error
                                % gate; speed error is REPORTED, not gated.
    G.battery_conditional = true;   % battery envelope is CONDITIONAL on ASSUMED hw
    G.artifact_min_png_bytes = 20000;
    G.artifact_min_md_bytes  = 4000;
    C.gate_cfg = G;

    % Gate ledger: mandatory gates decide PASS/FAIL, conditional gates can only
    % downgrade PASS -> PARTIAL (they depend on ASSUMED hardware numbers).
    L = struct('id', {}, 'name', {}, 'class', {});
    L(end+1) = struct('id','G1','name','ideal parity (bitwise vs bypass)','class','MANDATORY');
    L(end+1) = struct('id','G2','name','finite / bounded states, all runs','class','MANDATORY');
    L(end+1) = struct('id','G3','name','existing pitch/gamma/yaw/actuator gates (ideal)','class','MANDATORY');
    L(end+1) = struct('id','G3C','name','existing gates under ASSUMED variants','class','CONDITIONAL');
    L(end+1) = struct('id','G4','name','thrust magnitude/rate limit compliance','class','MANDATORY');
    L(end+1) = struct('id','G5','name','battery/current envelope (worst corner)','class','CONDITIONAL');
    L(end+1) = struct('id','G6','name','deterministic replay (bitwise)','class','MANDATORY');
    L(end+1) = struct('id','G7','name','exact production / CODEX_VERTICAL_PLAN fingerprints','class','MANDATORY');
    L(end+1) = struct('id','G8','name','readable artifacts (md/mat/png)','class','MANDATORY');
    C.gate_ledger = L;

    %% ---------------- function handles (pure, no state) -----------------
    C.fn = struct( ...
        'actuator_init',    @actuator_init, ...
        'actuator_step',    @actuator_step, ...
        'disk_ideal_power', @disk_ideal_power, ...
        'energy_corners',   @energy_corners, ...
        'bus_power',        @bus_power);
end

%% ===================== thruster actuator model =====================
function A = actuator_init(V, thrust_min, thrust_max, T_init)
%ACTUATOR_INIT  Bind a predeclared variant to the FROZEN production thrust limits.
    A = struct();
    A.name        = V.name;
    A.label       = V.label;
    A.gain        = V.gain;
    A.tau_s       = V.tau_s;
    A.rate_max    = V.rate_max_Nps;
    A.deadband    = V.deadband_N;
    A.T_min       = thrust_min;
    A.T_max       = thrust_max;
    A.T_init      = T_init;          % ASSUMED: propulsor starts at production trim
    A.identity    = (V.gain == 1) && (V.tau_s == 0) && isinf(V.rate_max_Nps) && (V.deadband_N == 0);
    A.state       = struct('T', T_init);
end

function [T_out, A] = actuator_step(T_cmd, A, dt)
%ACTUATOR_STEP  Magnitude -> deadband -> rate -> first-order lag -> magnitude.
% The identity branch is STRUCTURAL: for the ideal variant the returned value is
% the (already production-clamped) command itself, with no arithmetic that could
% perturb the last bit. This is what makes the parity gate provable at tol = 0.
    Tc = A.gain * T_cmd;
    if Tc > A.T_max; Tc = A.T_max; end
    if Tc < A.T_min; Tc = A.T_min; end

    if A.identity
        T_out = Tc;
        A.state.T = Tc;
        return;
    end

    Tprev = A.state.T;
    if A.deadband > 0 && abs(Tc - Tprev) < A.deadband
        Tc = Tprev;                      % command hold band
    end
    if isinf(A.rate_max)
        T_rl = Tc;
    else
        dmax = A.rate_max * dt;
        dT = Tc - Tprev;
        if dT >  dmax; dT =  dmax; end
        if dT < -dmax; dT = -dmax; end
        T_rl = Tprev + dT;
    end
    if A.tau_s > 0
        a = exp(-dt / A.tau_s);
        T_new = a * Tprev + (1 - a) * T_rl;
    else
        T_new = T_rl;
    end
    if T_new > A.T_max; T_new = A.T_max; end
    if T_new < A.T_min; T_new = A.T_min; end
    A.state.T = T_new;
    T_out = T_new;
end

%% ===================== energy model =====================
function P = disk_ideal_power(T, U, rho, A_disk)
%DISK_IDEAL_POWER  Actuator-disk (momentum theory) ideal power LOWER BOUND [W].
%   w_i = 0.5*(-U + sqrt(U^2 + 2|T|/(rho*A))),  P = |T|*(U + w_i)
% Component-neutral: depends only on thrust, inflow speed, water density and
% disk area. Real propulsors need strictly more power than this bound.
    Tm = abs(T(:));
    Uv = max(U(:), 0);
    wi = 0.5 * (-Uv + sqrt(Uv.^2 + 2 * Tm ./ (rho * A_disk)));
    P  = Tm .* (Uv + wi);
end

function K = energy_corners(E)
%ENERGY_CORNERS  worst / nominal / best hardware corners from the declared RANGES.
    Alo = pi/4 * min(E.disk_D_m)^2;
    Ahi = pi/4 * max(E.disk_D_m)^2;
    Amd = pi/4 * mean(E.disk_D_m)^2;
    eta_lo = min(E.eta_prop) * min(E.eta_motor) * min(E.eta_esc);
    eta_hi = max(E.eta_prop) * max(E.eta_motor) * max(E.eta_esc);
    eta_md = mean(E.eta_prop) * mean(E.eta_motor) * mean(E.eta_esc);

    K = struct('name', {}, 'A_disk', {}, 'eta_tot', {}, 'P_avi', {}, ...
               'P_fin_hold', {}, 'P_fin_move', {}, 'V_bus', {}, ...
               'batt_Wh', {}, 'I_cont', {}, 'rho', {});
    K(1).name='worst'; K(1).A_disk=Alo; K(1).eta_tot=eta_lo;
    K(1).P_avi=max(E.P_avionics_W); K(1).P_fin_hold=max(E.P_fin_hold_W);
    K(1).P_fin_move=max(E.P_fin_move_W); K(1).V_bus=min(E.V_bus_V);
    K(1).batt_Wh=min(E.batt_usable_Wh); K(1).I_cont=min(E.I_cont_max_A); K(1).rho=E.rho_kgm3;
    K(2).name='nominal'; K(2).A_disk=Amd; K(2).eta_tot=eta_md;
    K(2).P_avi=mean(E.P_avionics_W); K(2).P_fin_hold=mean(E.P_fin_hold_W);
    K(2).P_fin_move=mean(E.P_fin_move_W); K(2).V_bus=mean(E.V_bus_V);
    K(2).batt_Wh=mean(E.batt_usable_Wh); K(2).I_cont=mean(E.I_cont_max_A); K(2).rho=E.rho_kgm3;
    K(3).name='best'; K(3).A_disk=Ahi; K(3).eta_tot=eta_hi;
    K(3).P_avi=min(E.P_avionics_W); K(3).P_fin_hold=min(E.P_fin_hold_W);
    K(3).P_fin_move=min(E.P_fin_move_W); K(3).V_bus=max(E.V_bus_V);
    K(3).batt_Wh=max(E.batt_usable_Wh); K(3).I_cont=max(E.I_cont_max_A); K(3).rho=E.rho_kgm3;
end

function P = bus_power(T, U, fin_moving, K)
%BUS_POWER  DC-bus electrical power [W] for one hardware corner.
    P = struct();
    P.P_hydro_ideal = disk_ideal_power(T, U, K.rho, K.A_disk);
    P.P_prop_elec   = P.P_hydro_ideal / K.eta_tot;
    P.P_fin         = K.P_fin_hold + double(fin_moving(:)) * (K.P_fin_move - K.P_fin_hold);
    P.P_avionics    = K.P_avi * ones(size(P.P_prop_elec));
    P.P_bus         = P.P_prop_elec + P.P_fin + P.P_avionics;
    P.I_bus         = P.P_bus / K.V_bus;
end
