function out = closed_loop_actuator_realism_harness_fix_case(path,state,clock,T_final,U_cmd,cfg,seed)
% Gate-3 harness-only case. Production guidance/controller/plant are unchanged.
% Every invocation resets task globals and persistent controller/guidance state.
clear guidance_law controller_law
clear global
rng(seed,'twister');
init_parameters();
global dt_controller dt_guidance
dt_controller = clock.controller;
dt_guidance = clock.guidance;
dt = clock.sim;
n = round(T_final/dt);

out.t = (1:n)'*dt;
out.position = nan(n,3); out.velocity = nan(n,3);
out.attitude = nan(n,3); out.rates = nan(n,3);
out.reference = nan(n,3);
out.command = nan(n,3); out.allocated = nan(n,3);
out.applied = nan(n,3); out.feedback = nan(n,3);
out.progress_index = nan(n,1); out.progress_s = nan(n,1);
out.complete = false; out.error = '';

ds = [0;cumsum(vecnorm(diff(path,1,1),2,2))];
progress_index = 1;
yaw_ref = 0; pitch_ref = 0; r_ff = 0; pitch_ref_dot = 0;
guidance_period = max(1,round(dt_guidance/dt));
act = [0 0]; feedback = [0 0];
hist_t = zeros(n+1,1); hist_u = zeros(n+1,2); hist_n = 1;
hist_t(1) = -dt;

for k = 1:n
    pos = state(1:3)'; ori = state(4:6)'; rates = state(10:12)';
    [Uh,zdot] = local_inertial_velocity(ori,state(7),state(8),state(9));
    if mod(k-1,guidance_period) == 0
        [yaw_ref,pitch_ref,~,progress_index,r_ff,pitch_ref_dot] = ...
            guidance_law(pos,path,progress_index,state(7),state(8),Uh,zdot,-ori(2));
    end
    [dr,de,thrust] = controller_law(yaw_ref,pitch_ref,U_cmd, ...
        ori(3),ori(2),rates(3),rates(2),state(7),r_ff,pitch_ref_dot, ...
        ori(1),state(9),rates(1));

    logical = [de dr thrust];                 % [elevator rudder thrust]
    allocated = (eye(3)*logical')';
    hist_n = hist_n + 1;
    hist_t(hist_n) = (k-1)*dt;
    hist_u(hist_n,:) = allocated(1:2);

    if cfg.ideal
        act = allocated(1:2);
    else
        jitter = cfg.jitter_s*sin(2*pi*(k-1)/17 + [0 pi/3]);
        query_t = (k-1)*dt - cfg.delay_s - jitter;
        delayed = zeros(1,2);
        for j = 1:2
            delayed(j) = interp1(hist_t(1:hist_n),hist_u(1:hist_n,j), ...
                max(0,query_t(j)),'previous','extrap');
        end
        mag = deg2rad([15 25]);
        delayed = max(-mag,min(mag,delayed));
        target = sign(delayed).*max(abs(delayed)-deg2rad(cfg.deadband_deg),0);
        alpha = 1-exp(-dt/cfg.tau_s);
        lagged = act + alpha*(target-act);
        step = max(-deg2rad(40)*dt,min(deg2rad(40)*dt,lagged-act));
        act = max(-mag,min(mag,act+step));
    end
    feedback = act; % telemetry only; never fed to controller
    controls.delta_e = act(1);
    controls.delta_r = act(2);
    controls.thrust = allocated(3);
    try
        [~,g] = ode45(@(t,x) underwater777_vehicle_dynamics(t,x,controls),[0 dt],state);
        state = g(end,:)';
    catch ME
        out.error = sprintf('step %d: %s',k,ME.message);
        break
    end
    if any(~isfinite(state))
        out.error = sprintf('nonfinite state at step %d',k);
        break
    end
    out.position(k,:) = state(1:3);
    out.velocity(k,:) = state(7:9);
    out.attitude(k,:) = state(4:6);
    out.rates(k,:) = state(10:12);
    out.reference(k,:) = [pitch_ref yaw_ref U_cmd];
    out.command(k,:) = logical;
    out.allocated(k,:) = allocated;
    out.applied(k,:) = [act allocated(3)];
    out.feedback(k,:) = [feedback allocated(3)];
    out.progress_index(k) = progress_index;
    out.progress_s(k) = ds(min(max(1,progress_index),numel(ds)));
end
out.complete = all(isfinite(out.position(:,1)));
out.path = path;
out.cfg = cfg;
end

function [Uh,zdot] = local_inertial_velocity(o,u,v,w)
phi=o(1); theta=o(2); psi=o(3);
R=[cos(psi)*cos(theta),cos(psi)*sin(theta)*sin(phi)-sin(psi)*cos(phi),cos(psi)*sin(theta)*cos(phi)+sin(psi)*sin(phi); ...
   sin(psi)*cos(theta),sin(psi)*sin(theta)*sin(phi)+cos(psi)*cos(phi),sin(psi)*sin(theta)*cos(phi)-cos(psi)*sin(phi); ...
   -sin(theta),cos(theta)*sin(phi),cos(theta)*cos(phi)];
q=R*[u;v;w]; Uh=hypot(q(1),q(2)); zdot=q(3);
end
