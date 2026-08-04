function verify_tur25_trim()
% Quick post-2.5.1 acceptance check (pure level + X-line).
    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);
    clear functions; clear guidance_law controller_law
    % Force fresh globals so defaults + cal apply
    clear global trim_speed_table trim_elevator_table elevator_sign
    init_parameters();
    global elevator_sign trim_speed_table trim_elevator_table Ki_angle
    sign_rep = test_elevator_sign();
    elevator_sign = sign_rep.delta_e_sign;
    build_pitch_trim_table();
    fprintf('Trim after refine: u=[%s] de=[%s]\n', ...
        num2str(trim_speed_table,'%.1f '), num2str(rad2deg(trim_elevator_table),'%+.2f '));

    % Two pure-level runs at u=1.5 and u=2.0
    for u = [1.5 2.0]
        for run = 1:2
            clear controller_law
            r = diag_level_metrics(u, 0, 22, 10);
            fprintf('PURE u=%.1f run%d | e=%+.3f | |e|=%.3f | chatter=%.4f | sat=%.1f%% | Ipeg=%.2f | deRMS=%.3f | de_I=%+.3f\n', ...
                u, run, r.mean_e_theta_deg, r.mean_abs_e_deg, r.pitch_chatter_dps, ...
                r.pct_mag_sat, r.angle_I_pegged, r.rms_delta_e_deg, r.mean_delta_e_angle_I_deg);
        end
    end

    % X-line production
    clear controller_law guidance_law
    x = diag_xline_metrics(1.5, 18, 6);
    fprintf('XLINE | e=%+.3f | |e|=%.3f | chatter=%.4f | CTE=%.3f | depth_e=%.3f\n', ...
        x.mean_e_theta_deg, x.mean_abs_e_deg, x.pitch_chatter_dps, x.mean_cte, x.mean_depth_err);

    out = fullfile(project_dir, 'suite_results', 'T25_verify_trim.txt');
    fid = fopen(out, 'w');
    fprintf(fid, 'trim de_deg=[%s]\n', num2str(rad2deg(trim_elevator_table),'%+.3f '));
    fprintf(fid, 'Ki_angle=%.3f\n', Ki_angle);
    fclose(fid);
end

function m = diag_level_metrics(u, pref, T, tset)
    % Lightweight wrapper reusing diag_tur25_bias helpers via evalin would be hard;
    % duplicate minimal loop.
    global dt_controller
    dt = dt_controller; n = round(T/dt); i0 = max(1, round(tset/dt));
    state = zeros(12,1); state(7) = u;
    e = zeros(n,1); th = zeros(n,1); de = zeros(n,1); dI = zeros(n,1);
    ia = zeros(n,1); iam = zeros(n,1); sat = zeros(n,1); dth = zeros(n,1);
    for k = 1:n
        ori = state(4:6); rates = state(10:12);
        [dr, de_k, th_k, dbg] = controller_law(0, pref, u, ori(3), ori(2), rates(3), rates(2), state(7), 0, 0, ori(1)); %#ok<ASGLU>
        controls = struct('delta_r',dr,'delta_e',de_k,'thrust',th_k);
        [~,g] = ode45(@(t,x) underwater777_vehicle_dynamics(t,x,controls),[0 dt],state);
        state = g(end,:)';
        e(k)=dbg.e_theta; th(k)=dbg.theta_phys; de(k)=de_k; dI(k)=dbg.delta_e_angle_I;
        ia(k)=dbg.int_angle; iam(k)=dbg.int_angle_max; sat(k)=dbg.mag_sat;
        dth(k)=dbg.theta_phys_dot;
    end
    sl = i0:n;
    m.mean_e_theta_deg = rad2deg(mean(e(sl)));
    m.mean_abs_e_deg = rad2deg(mean(abs(e(sl))));
    m.rms_delta_e_deg = rad2deg(rms(de(sl)));
    m.mean_delta_e_angle_I_deg = rad2deg(mean(dI(sl)));
    m.pct_mag_sat = 100*mean(sat(sl)>0.5);
    m.angle_I_pegged = mean(abs(ia(sl)) >= 0.98*abs(iam(sl)));
    % chatter
    dthv = [0; diff(th(sl))]/dt;
    nwin = max(3, round(0.8/dt));
    lf = filter(ones(nwin,1)/nwin,1,detrend(dthv));
    hf = dthv - lf; hf(1:nwin)=0;
    m.pitch_chatter_dps = rad2deg(std(hf(nwin+1:end)));
end

function m = diag_xline_metrics(u0, T, tset)
    global dt_controller dt_guidance desired_speed
    dt = dt_controller; n = round(T/dt); i0 = max(1, round(tset/dt));
    xp = linspace(0,20,400)'; path = [xp, zeros(400,1), zeros(400,1)];
    state = zeros(12,1); state(1:3)=path(1,:)'; state(7)=u0;
    desired_speed = 1.5;
    gper = max(1, round(dt_guidance/dt));
    yaw_ref=0; pitch_ref=0; u_ref=u0; r_ff=0; pitch_ref_dot=0; pidx=1;
    e=zeros(n,1); th=zeros(n,1); cte=zeros(n,1); ze=zeros(n,1);
    for k=1:n
        pos=state(1:3)'; ori=state(4:6); rates=state(10:12);
        if mod(k-1,gper)==0
            [yaw_ref,pitch_ref,u_ref,pidx,r_ff,pitch_ref_dot]=guidance_law(pos,path,pidx,state(7),state(8));
        end
        [dr,de_k,th_k,dbg]=controller_law(yaw_ref,pitch_ref,u_ref,ori(3),ori(2),rates(3),rates(2),state(7),r_ff,pitch_ref_dot,ori(1));
        controls=struct('delta_r',dr,'delta_e',de_k,'thrust',th_k);
        [~,g]=ode45(@(t,x) underwater777_vehicle_dynamics(t,x,controls),[0 dt],state);
        state=g(end,:)';
        e(k)=dbg.e_theta; th(k)=dbg.theta_phys;
        d=vecnorm(path-state(1:3)',2,2); [cte(k),ix]=min(d); ze(k)=state(3)-path(ix,3);
    end
    sl=i0:n;
    m.mean_e_theta_deg=rad2deg(mean(e(sl)));
    m.mean_abs_e_deg=rad2deg(mean(abs(e(sl))));
    m.mean_cte=mean(cte(sl));
    m.mean_depth_err=mean(ze(sl));
    dthv=[0;diff(th(sl))]/dt;
    nwin=max(3,round(0.8/dt));
    lf=filter(ones(nwin,1)/nwin,1,detrend(dthv));
    hf=dthv-lf; hf(1:nwin)=0;
    m.pitch_chatter_dps=rad2deg(std(hf(nwin+1:end)));
end
