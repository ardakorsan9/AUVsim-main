function [yaw_ref,pitch_ref,u_ref,path_idx,r_ff,pitch_ref_dot,alpha,reason,pred] = ...
    guidance_law_water_current_arc_governor(current_pos,path,path_idx,u,v,ug,wg,theta_phys, ...
    prior_class,psi,r,p,delta_r_state)
% Gate 4B candidate 2: finite-horizon arc-length/curvature-FF governor.
% Production guidance and controller parameters are frozen. The current vector
% is deliberately not an input. Projection is enabled only for prior REFUSE.

    global Kp_psi Kd_psi Kp_roll delta_r_max dt_controller
    persistent last_idx last_yaw last_rff
    if isempty(Kp_roll); Kp_roll=0.605072; end
    if isempty(dt_controller); dt_controller=0.0375; end
    if isempty(delta_r_max); delta_r_max=deg2rad(25); end

    [yaw_c,pitch_ref,u_ref,idx_c,rff_c,pitch_ref_dot] = ...
        guidance_law(current_pos,path,path_idx,u,v,ug,wg,theta_phys);

    if isempty(last_idx) || path_idx < last_idx || path_idx == 1
        last_idx=path_idx; last_yaw=yaw_c; last_rff=0;
    end
    if ~strcmp(prior_class,'REFUSE')
        yaw_ref=yaw_c; path_idx=idx_c; r_ff=rff_c; alpha=1;
        pred=struct('first',NaN,'sequence',nan(6,1),'rates',nan(6,1), ...
            'max_mag_deg',NaN,'max_rate_deg_s',NaN);
        reason='exact pass-through: prior case is not REFUSE';
    else
        % Deterministic constraint projection: maximal alpha on the proposed
        % arc-progress and curvature-feedforward increment. The 0.05-degree
        % interior is a fixed numerical contact guard, not a tuned limit.
        feasible=@(a) is_feasible(a,last_yaw,yaw_c,last_rff,rff_c,psi,r,p, ...
            delta_r_state,Kp_psi,Kd_psi,Kp_roll,delta_r_max,dt_controller);
        if feasible(1)
            alpha=1;
        else
            lo=0; hi=1;
            for k=1:18
                mid=(lo+hi)/2;
                if feasible(mid); lo=mid; else; hi=mid; end
            end
            alpha=lo;
        end
        path_idx=max(1,round(last_idx+alpha*(idx_c-last_idx)));
        yaw_ref=last_yaw+alpha*wrap_pi(yaw_c-last_yaw);
        r_ff=last_rff+alpha*(rff_c-last_rff);
        pred=predict_rudder(yaw_ref,r_ff,psi,r,p,delta_r_state, ...
            Kp_psi,Kd_psi,Kp_roll,delta_r_max,dt_controller);
        if alpha < 1-1e-12
            reason='REFUSE: finite-horizon arc/curvature projection';
        else
            reason='REFUSE: full increment predicted feasible';
        end
    end
    last_idx=path_idx; last_yaw=yaw_ref; last_rff=r_ff;
end

function ok=is_feasible(a,y0,y1,f0,f1,psi,r,p,dr0,Kp,Kd,Kroll,drmax,dt)
    y=y0+a*wrap_pi(y1-y0); ff=f0+a*(f1-f0);
    z=predict_rudder(y,ff,psi,r,p,dr0,Kp,Kd,Kroll,drmax,dt);
    mag_guard=rad2deg(drmax)-0.05;
    ok=all(abs(rad2deg(z.sequence))<=mag_guard+1e-12) && ...
       all(abs(rad2deg(z.rates))<=39.95+1e-12);
end

function z=predict_rudder(yaw_ref,rff,psi,r,p,dr0,Kp,Kd,Kroll,drmax,dt)
    H=6; seq=zeros(H,1); rates=zeros(H,1); dr=dr0;
    for h=1:H
        ep=wrap_pi(yaw_ref-psi); er=r-rff;
        gac=1/(1+(ep/deg2rad(3))^2+(er/deg2rad(8))^2);
        cmd=Kp*ep-Kd*er+gac*(-Kroll*p);
        cmd=max(min(cmd,drmax),-drmax);
        step=max(min(cmd-dr,deg2rad(40)*dt),-deg2rad(40)*dt);
        seq(h)=dr+step; rates(h)=step/dt; dr=seq(h);
        psi=psi+r*dt; % frozen measured yaw-rate predictor
    end
    z=struct('first',seq(1),'sequence',seq,'rates',rates, ...
        'max_mag_deg',max(abs(rad2deg(seq))), ...
        'max_rate_deg_s',max(abs(rad2deg(rates))));
end

function x=wrap_pi(x)
    x=mod(x+pi,2*pi)-pi;
end
