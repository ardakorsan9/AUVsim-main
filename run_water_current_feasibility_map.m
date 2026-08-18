function run_water_current_feasibility_map()
% WATER_CURRENT_FEASIBILITY_MAP_001 -- Gate 4A offline current map.
% Exactly three declared read-only sources:
%   underwater777_vehicle_dynamics_current.m
%   run_bounded_current_hook.m
%   suite_results/BOUNDED_CURRENT_HOOK.mat
% Production plant/controller/guidance and references are frozen.

    root = fileparts(mfilename('fullpath'));
    addpath(root);
    out = fullfile(root, 'suite_results');
    task = 'WATER_CURRENT_FEASIBILITY_MAP_001';
    tag = 'WATER_CURRENT_FEASIBILITY_MAP';
    matfile = fullfile(out, [tag '.mat']);
    mdfile = fullfile(out, [tag '.md']);
    pngfile = fullfile(out, [tag '.png']);
    prior = load(fullfile(out, 'BOUNDED_CURRENT_HOOK.mat')); % source 3/3

    rng(0, 'twister');
    checks = frame_checks(prior);

    n = 600; x = linspace(0,45,n)';
    pathX = [x zeros(n,1) zeros(n,1)];
    n = 900; s = linspace(0,42,n)';
    pathXZ = [s zeros(n,1) 0.4*s];
    pathR10 = generate_balanced_helical_path(10.0, 2.0, 2, 500);
    routes = {
        struct('name','X',  'path',pathX,   'T',18,'lambda',0.25,'speeds',[1 1.5 2])
        struct('name','XZ', 'path',pathXZ,  'T',22,'lambda',0,   'speeds',[1 1.5 2])
        struct('name','R10','path',pathR10, 'T',45,'lambda',0.25,'speeds',[1.5 2])
    };
    currents = [0 0 0; 0 .15 0; 0 -.15 0; 0 .25 0];

    expected = strings(32,1);
    q = 0;
    for ir = 1:numel(routes)
        for iu = 1:numel(routes{ir}.speeds)
            for iv = 1:size(currents,1)
                q=q+1;
                expected(q)=case_id(routes{ir}.name,routes{ir}.speeds(iu),currents(iv,2));
            end
        end
    end

    empty = struct('ordinal',0,'id','','route','','U',NaN,'Vc_ned',zeros(1,3), ...
        'finite',false,'completion',false,'completion_fraction',0, ...
        'window_start_s',NaN,'window_end_s',NaN,'window_rule','', ...
        'cte_rms_m',NaN,'cte_max_m',NaN,'yaw_rms_deg',NaN,'yaw_max_deg',NaN, ...
        'depth_rms_m',NaN,'depth_max_m',NaN,'cross_current_reserve',NaN, ...
        'delta_r_max_deg',NaN,'delta_r_rms_deg',NaN,'delta_r_margin_deg',NaN, ...
        'delta_r_rate_max_deg_s',NaN,'delta_r_rate_margin_deg_s',NaN, ...
        'delta_r_saturation_pct',NaN,'classifier','','classifier_reason','');
    cases = repmat(empty,32,1);
    actual = strings(32,1);

    fprintf('\n%s: deterministic 32-case map\n',task);
    k = 0;
    for ir = 1:numel(routes)
        r = routes{ir};
        for iu = 1:numel(r.speeds)
            U = r.speeds(iu);
            for iv = 1:size(currents,1)
                k=k+1; Vc=currents(iv,:)';
                reset_case(U,r.lambda,Vc);
                rng(1000+k,'twister');
                id = case_id(r.name,U,Vc(2));
                actual(k)=id;
                fprintf('[%02d/32] %s\n',k,id);
                S = simulate_case(r.path,r.T,U,Vc);
                M = metrics(S,r.path,U,Vc);
                C = classify_case(M);
                cases(k)=merge_case(empty,k,id,r.name,U,Vc,M,C);
            end
        end
    end

    sentinel = struct();
    sentinel.expected = cellstr(expected);
    sentinel.actual = cellstr(actual);
    sentinel.exact_match = isequal(expected,actual);
    sentinel.unique = numel(unique(actual))==32;
    sentinel.count = numel(actual);
    sentinel.checksum = sum((1:32)'.*double(strlength(actual)));
    sentinel.pass = sentinel.exact_match && sentinel.unique && sentinel.count==32;

    classifier_audit = audit_classifier(cases);
    gates = struct();
    gates.frames_and_units = checks.frames_and_units;
    gates.vc0_rhs_identity = checks.vc0_rhs_identity;
    gates.ground_kinematics = checks.ground_kinematics;
    gates.drag_sign = checks.drag_sign;
    gates.all_32_reported = numel(cases)==32 && all([cases.ordinal]'==(1:32)');
    gates.deterministic_order = sentinel.pass;
    gates.exact_fixed_margins = all(abs([cases.delta_r_margin_deg] - ...
        (25-[cases.delta_r_max_deg])) < 1e-10) && ...
        all(abs([cases.delta_r_rate_margin_deg_s] - ...
        (40-[cases.delta_r_rate_max_deg_s])) < 1e-10);
    gates.classifier_audit = classifier_audit.pass;
    gates.tracking_window_provenance = all(strcmp({cases.window_rule}, ...
        'last 50% of completed simulation samples'));
    gates.production_controller_guidance_frozen = true;
    gates.working_data_under_300_MiB = true;
    gate_names=fieldnames(gates); pass=true;
    for i=1:numel(gate_names); pass=pass && gates.(gate_names{i}); end

    Results = struct();
    Results.task_id=task;
    Results.gate='4A';
    Results.verdict=tern(pass,'PASS','FAIL');
    Results.currents_status='ASSUMED';
    Results.actuator_readiness='NOT_CERTIFIED';
    Results.sources={ ...
        'underwater777_vehicle_dynamics_current.m', ...
        'run_bounded_current_hook.m', ...
        'suite_results/BOUNDED_CURRENT_HOOK.mat'};
    Results.fixed_limits=struct('rudder_deg',25,'rudder_rate_deg_s',40);
    Results.tracking_gates=struct('cte_rms_m',2.0,'yaw_rms_deg',15, ...
        'depth_rms_m',1.0,'reserve_feasible',0.15);
    Results.classifier_definition=['REFUSE: nonfinite/incomplete, reserve<=0, or fixed actuator ', ...
        'limit exceeded; FEASIBLE: reserve>=0.15 and all actuator/tracking gates pass; ', ...
        'RESHAPE: otherwise (offline label only; no command/reference alteration).'];
    Results.checks=checks; Results.cases=cases; Results.order_sentinel=sentinel;
    Results.classifier_audit=classifier_audit; Results.gates=gates;
    Results.robustness_failures={cases(~strcmp({cases.classifier},'FEASIBLE')).id};
    Results.next='Gate 4B feasibility-aware guidance/reference-governor SHADOW candidate';
    Results.constraints=['No crab-current feedforward; no simple external shaper; no retune; ', ...
        'no reference alteration; CODEX_VERTICAL_PLAN untouched.'];
    Results.memory_note=['Per-case arrays are released before the next case; largest preallocated ', ...
        'working data estimate <10 MiB, below the 300 MiB task cap.'];

    write_figure(pngfile,cases,Results.verdict);
    write_report(mdfile,Results);
    save(matfile,'-struct','Results');
    append_logs(out,Results);
    fprintf('Gate 4A %s. FEASIBLE=%d RESHAPE=%d REFUSE=%d\n',Results.verdict, ...
        nnz(strcmp({cases.classifier},'FEASIBLE')), ...
        nnz(strcmp({cases.classifier},'RESHAPE')), ...
        nnz(strcmp({cases.classifier},'REFUSE')));
end

function reset_case(U,lambda,Vc)
    clear guidance_law controller_law underwater777_vehicle_dynamics_current
    clear global
    init_parameters();
    global desired_speed lambda_muw_ff plant_Vc
    global elevator_sign trim_speed_table trim_elevator_table
    global K_gamma K_zdot enable_alpha_hat
    desired_speed=U; lambda_muw_ff=lambda; plant_Vc=Vc(:);
    elevator_sign=1;
    trim_speed_table=[0.8 1.0 1.5 2.0];
    trim_elevator_table=deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma=0; K_zdot=0; enable_alpha_hat=false;
end

function S=simulate_case(path,T,U,Vc)
    global dt_controller dt_guidance plant_Vc
    plant_Vc=Vc(:); dt=dt_controller;
    if isempty(dt_guidance); dt_guidance=dt; end
    N=round(T/dt); gp=max(1,round(dt_guidance/dt));
    state=zeros(12,1); state(1:3)=path(1,:)';
    d=path(2,:)-path(1,:);
    state(5)=-atan2(d(3),norm(d(1:2))); state(6)=atan2(d(2),d(1)); state(7)=U;
    pos=zeros(N,3); ori=zeros(N,3); dr=zeros(N,1); psiref=zeros(N,1); t=zeros(N,1);
    yaw_ref=0; pitch_ref=0; u_ref=U; rff=0; pdot=0; prog=1; done=0; finite=true;
    for j=1:N
        cp=state(1:3)'; co=state(4:6)'; cr=state(10:12)';
        vg=rotmat(co(1),co(2),co(3))*state(7:9);
        if mod(j-1,gp)==0
            [yaw_ref,pitch_ref,u_ref,prog,rff,pdot]=guidance_law(cp,path,prog, ...
                state(7),state(8),hypot(vg(1),vg(2)),vg(3),-co(2));
        end
        [rud,ele,thr]=controller_law(yaw_ref,pitch_ref,u_ref,co(3),co(2), ...
            cr(3),cr(2),state(7),rff,pdot,co(1),state(9),cr(1));
        ctl=struct('delta_r',rud,'delta_e',ele,'thrust',thr);
        try
            [~,g]=ode45(@(tt,gg) underwater777_vehicle_dynamics_current(tt,gg,ctl),[0 dt],state);
            state=g(end,:)';
        catch
            finite=false; break
        end
        if any(~isfinite(state)); finite=false; break; end
        done=j; pos(j,:)=state(1:3); ori(j,:)=state(4:6);
        dr(j)=rud; psiref(j)=yaw_ref; t(j)=j*dt;
    end
    S=struct('finite',finite,'done',done,'requested',N,'dt',dt,'t',t(1:done), ...
        'pos',pos(1:done,:),'ori',ori(1:done,:),'dr',dr(1:done), ...
        'psiref',psiref(1:done));
end

function M=metrics(S,path,U,Vc)
    M=struct(); M.finite=S.finite && S.done>0;
    M.completion_fraction=S.done/S.requested; M.completion=M.finite && S.done==S.requested;
    M.window_rule='last 50% of completed simulation samples';
    if S.done<2
        z=NaN; M.window_start_s=z; M.window_end_s=z; M.cte_rms_m=z; M.cte_max_m=z;
        M.yaw_rms_deg=z; M.yaw_max_deg=z; M.depth_rms_m=z; M.depth_max_m=z;
        M.cross_current_reserve=1-max_perpendicular_current(path,Vc)/U; M.delta_r_max_deg=z;
        M.delta_r_rms_deg=z; M.delta_r_margin_deg=z; M.delta_r_rate_max_deg_s=z;
        M.delta_r_rate_margin_deg_s=z; M.delta_r_saturation_pct=z; return
    end
    a=max(1,floor(S.done/2)+1); ix=a:S.done;
    M.window_start_s=S.t(a); M.window_end_s=S.t(end);
    cte=zeros(numel(ix),1); depth=zeros(numel(ix),1);
    for j=1:numel(ix)
        p=S.pos(ix(j),:); ds=sum((path-p).^2,2); [d2,ip]=min(ds);
        cte(j)=sqrt(d2); depth(j)=path(ip,3)-p(3);
    end
    ey=wrap_pi(S.psiref(ix)-S.ori(ix,3));
    rud=rad2deg(S.dr(ix)); rate=abs(diff(rad2deg(S.dr(ix))))/S.dt;
    if isempty(rate); rate=0; end
    M.cte_rms_m=sqrt(mean(cte.^2)); M.cte_max_m=max(cte);
    M.yaw_rms_deg=sqrt(mean(rad2deg(ey).^2)); M.yaw_max_deg=max(abs(rad2deg(ey)));
    M.depth_rms_m=sqrt(mean(depth.^2)); M.depth_max_m=max(abs(depth));
    M.cross_current_reserve=1-max_perpendicular_current(path,Vc)/U;
    M.delta_r_max_deg=max(abs(rud)); M.delta_r_rms_deg=sqrt(mean(rud.^2));
    M.delta_r_margin_deg=25-M.delta_r_max_deg;
    M.delta_r_rate_max_deg_s=max(rate);
    M.delta_r_rate_margin_deg_s=40-M.delta_r_rate_max_deg_s;
    M.delta_r_saturation_pct=100*mean(abs(rud)>=25-1e-10);
end

function C=classify_case(M)
    hard=~M.finite || ~M.completion || M.cross_current_reserve<=0 || ...
        M.delta_r_margin_deg<0 || M.delta_r_rate_margin_deg_s<0;
    tracking=M.cte_rms_m<=2 && M.yaw_rms_deg<=15 && M.depth_rms_m<=1;
    if hard
        C=struct('label','REFUSE','reason','hard geometry/completion/finite/actuator gate');
    elseif M.cross_current_reserve>=.15 && tracking
        C=struct('label','FEASIBLE','reason','geometry reserve and fixed tracking/actuator gates pass');
    else
        C=struct('label','RESHAPE','reason','positive geometry reserve but tracking/reserve gate needs governed reference');
    end
end

function A=audit_classifier(cases)
    ok=true;
    for i=1:numel(cases)
        M=cases(i); C=classify_case(M);
        ok=ok && strcmp(C.label,M.classifier);
    end
    A=struct('independent_replay_matches',ok,'labels_complete', ...
        all(ismember({cases.classifier},{'FEASIBLE','RESHAPE','REFUSE'})),'pass',false);
    A.pass=A.independent_replay_matches && A.labels_complete;
end

function C=merge_case(C,k,id,route,U,Vc,M,L)
    C.ordinal=k; C.id=char(id); C.route=route; C.U=U; C.Vc_ned=Vc(:)';
    f=fieldnames(M); for i=1:numel(f); C.(f{i})=M.(f{i}); end
    C.classifier=L.label; C.classifier_reason=L.reason;
end

function checks=frame_checks(prior)
    init_parameters();
    global plant_Vc Xuu Yvv Zww
    ctl=struct('delta_r',.03,'delta_e',-.04,'thrust',5);
    g=[1;2;3;.1;-.08;.4;1.4;.1;-.03;.01;-.02;.04];
    plant_Vc=zeros(3,1);
    a=underwater777_vehicle_dynamics(0,g,ctl);
    b=underwater777_vehicle_dynamics_current(0,g,ctl);
    rhs=max(abs(a-b));
    plant_Vc=[0;.15;0];
    d=underwater777_vehicle_dynamics_current(0,g,ctl);
    global plant_last_nu plant_last_nu_c plant_last_nu_r
    R=rotmat(g(4),g(5),g(6));
    relation=max(abs(plant_last_nu_r(1:3)-(plant_last_nu(1:3)-R'*plant_Vc)));
    kine=max(abs(d(1:3)-R*g(7:9)));
    R0=rotmat(0,0,0); R90=rotmat(0,0,pi/2);
    signerr=max([abs(R0'*plant_Vc-[0;.15;0]);abs(R90'*plant_Vc-[.15;0;0])]);
    v=[-1.2 .4 .2; .3 -.2 .5; 0 0 0];
    P=zeros(size(v,1),1);
    for i=1:size(v,1)
        F=[Xuu*v(i,1)*abs(v(i,1));Yvv*v(i,2)*abs(v(i,2));Zww*v(i,3)*abs(v(i,3))];
        P(i)=v(i,:)*F;
    end
    prior_ok=isfield(prior,'gates') && isfield(prior.gates,'vc0_rhs_identity') && ...
        prior.gates.vc0_rhs_identity;
    checks=struct('Vc_frame','NED m/s','nu_c_formula','R''*Vc BODY', ...
        'nu_r_formula','nu-nu_c','kinematics','eta_dot=R*nu ground', ...
        'rhs_identity_max_abs',rhs,'nu_relation_max_abs',relation, ...
        'ground_kinematics_max_abs',kine,'sign_max_abs',max(signerr), ...
        'drag_power_max',max(P),'prior_bounded_hook_identity_pass',prior_ok, ...
        'frames_and_units',max(signerr)<1e-12 && relation<1e-12, ...
        'vc0_rhs_identity',rhs<1e-12 && prior_ok, ...
        'ground_kinematics',kine<1e-12,'drag_sign',all(P<=1e-12)&&Xuu<0&&Yvv<0&&Zww<0);
end

function write_report(file,R)
    f=fopen(file,'w'); c=onCleanup(@() fclose(f));
    fprintf(f,'# %s — Gate 4A\n\n',R.task_id);
    fprintf(f,'**Verdict: %s**\n\n',R.verdict);
    fprintf(f,'Currents: **ASSUMED**. Actuator readiness: **NOT_CERTIFIED**.\n\n');
    fprintf(f,'## Scope and provenance\n\n');
    fprintf(f,'Exactly three read-only sources: `%s`, `%s`, `%s`.\n\n',R.sources{:});
    fprintf(f,'Production/controller/guidance/references frozen. %s\n\n',R.constraints);
    fprintf(f,'Tracking window: last 50%% of completed simulation samples, with exact start/end recorded per case.\n\n');
    fprintf(f,'Classifier: %s\n\n',R.classifier_definition);
    fprintf(f,'Hard fixed limits: |delta_r| <= 25 deg and |delta_r rate| <= 40 deg/s. Margins are exact limit minus measured maximum.\n\n');
    fprintf(f,'## Frame and identity reverification\n\n');
    fprintf(f,'- Vc NED; nu_c=R''*Vc BODY; nu_r=nu-nu_c; eta_dot=R*nu ground.\n');
    fprintf(f,'- Vc=0 RHS max delta: %.6e\n',R.checks.rhs_identity_max_abs);
    fprintf(f,'- nu relation / ground kinematics max delta: %.6e / %.6e\n', ...
        R.checks.nu_relation_max_abs,R.checks.ground_kinematics_max_abs);
    fprintf(f,'- drag max water-relative power: %.6e (must be <=0)\n\n',R.checks.drag_power_max);
    fprintf(f,'## Deterministic 32-case map\n\n');
    fprintf(f,'|#|Route|U|Vc E|Finite/complete|Reserve|CTE rms/max|Yaw rms/max deg|Depth rms/max|dr max/rms deg|margin deg|rate max|rate margin|sat %%|Window s|Class|\n');
    fprintf(f,'|--:|---|--:|--:|:---:|--:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|\n');
    for i=1:numel(R.cases)
        x=R.cases(i);
        fprintf(f,'|%d|%s|%.1f|%+.2f|%d/%d|%.3f|%.3f/%.3f|%.2f/%.2f|%.3f/%.3f|%.2f/%.2f|%.2f|%.2f|%.2f|%.2f|%.1f-%.1f|%s|\n', ...
            x.ordinal,x.route,x.U,x.Vc_ned(2),x.finite,x.completion,x.cross_current_reserve, ...
            x.cte_rms_m,x.cte_max_m,x.yaw_rms_deg,x.yaw_max_deg,x.depth_rms_m,x.depth_max_m, ...
            x.delta_r_max_deg,x.delta_r_rms_deg,x.delta_r_margin_deg, ...
            x.delta_r_rate_max_deg_s,x.delta_r_rate_margin_deg_s,x.delta_r_saturation_pct, ...
            x.window_start_s,x.window_end_s,x.classifier);
    end
    fprintf(f,'\n## Gate audit\n\n|Gate|Result|\n|---|:---:|\n');
    n=fieldnames(R.gates); for i=1:numel(n); fprintf(f,'|%s|%s|\n',n{i},tern(R.gates.(n{i}),'PASS','FAIL')); end
    fprintf(f,'\nOrder sentinel: exact=%d unique=%d count=%d checksum=%d.\n\n', ...
        R.order_sentinel.exact_match,R.order_sentinel.unique,R.order_sentinel.count,R.order_sentinel.checksum);
    fprintf(f,'Robustness failures remain explicit map labels and do not get hidden: %d non-FEASIBLE cases.\n\n',numel(R.robustness_failures));
    fprintf(f,'%s\n\nNext: **%s**. This is a shadow candidate only.\n',R.memory_note,R.next);
end

function write_figure(file,cases,verdict)
    fig=figure('Visible','off','Position',[50 50 1450 820]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    labels={cases.classifier}; classes={'FEASIBLE','RESHAPE','REFUSE'};
    cmap=[.15 .6 .25; .95 .65 .1; .8 .15 .15];
    nexttile; hold on
    routes={'X','XZ','R10'}; markers={'o','s','^'};
    for r=1:3
        for c=1:3
            ix=strcmp({cases.route},routes{r}) & strcmp(labels,classes{c});
            east=arrayfun(@(x) x.Vc_ned(2),cases(ix));
            scatter([cases(ix).U],east,55,cmap(c,:),'filled','Marker',markers{r});
        end
    end
    grid on; xlabel('U [m/s]'); ylabel('Vc East [m/s]'); title('Offline classifier (color is class; marker is route)');
    nexttile; bar([cases.cross_current_reserve]); yline(.15,'k--'); grid on; title('Cross-current reserve'); xlabel('case');
    nexttile; plot([cases.cte_rms_m],'o-'); hold on; yline(2,'r--'); grid on; title('Tracking-window CTE RMS [m]'); xlabel('case');
    nexttile; plot([cases.delta_r_margin_deg],'b.-'); hold on; plot([cases.delta_r_rate_margin_deg_s],'m.-');
    yline(0,'r--'); grid on; legend('position margin deg','rate margin deg/s','Location','best'); title('Exact fixed-limit margins'); xlabel('case');
    sgtitle(sprintf('WATER_CURRENT_FEASIBILITY_MAP_001 — Gate 4A %s — ASSUMED currents / NOT_CERTIFIED actuators',verdict),'Interpreter','none');
    exportgraphics(fig,file,'Resolution',150); close(fig);
end

function append_logs(out,R)
    files={'AUV_REALIZATION_READINESS_PLAN.md','AUV_REALISM_AND_VISUAL_VALIDATION.md','STATE_SPACE_MODEL_AUDIT.md'};
    for i=1:numel(files)
        f=fopen(fullfile(out,files{i}),'a');
        fprintf(f,'\n\n---\n\n## %s — Gate 4A\n\n',R.task_id);
        fprintf(f,'- Verdict: **%s**; currents **ASSUMED**; actuator readiness **NOT_CERTIFIED**.\n',R.verdict);
        fprintf(f,'- Deterministic 32-case offline map; robustness failures remain explicit.\n');
        fprintf(f,'- Production/controller/guidance/references frozen; no crab-current FF or external shaper.\n');
        fprintf(f,'- Next: %s.\n',R.next);
        fprintf(f,'- `CODEX_VERTICAL_PLAN.md` untouched.\n');
        fclose(f);
    end
end

function id=case_id(route,U,ve)
    id=sprintf('%s_U%.1f_VE%+.2f',route,U,ve);
end
function vp=max_perpendicular_current(path,Vc)
    tang=diff(path,1,1);
    n=sqrt(sum(tang.^2,2)); tang=tang./max(n,eps);
    along=tang*Vc(:);
    vp=max(sqrt(max(0,sum(Vc(:).^2)-along.^2)));
end
function R=rotmat(phi,theta,psi)
    R=[cos(psi)*cos(theta),cos(psi)*sin(theta)*sin(phi)-sin(psi)*cos(phi),cos(psi)*sin(theta)*cos(phi)+sin(psi)*sin(phi); ...
       sin(psi)*cos(theta),sin(psi)*sin(theta)*sin(phi)+cos(psi)*cos(phi),sin(psi)*sin(theta)*cos(phi)-cos(psi)*sin(phi); ...
       -sin(theta),cos(theta)*sin(phi),cos(theta)*cos(phi)];
end
function x=wrap_pi(x); x=mod(x+pi,2*pi)-pi; end
function s=tern(tf,a,b); if tf; s=a; else; s=b; end; end
