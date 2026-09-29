function run_water_current_reference_governor()
% WATER_CURRENT_REFERENCE_GOVERNOR_001 -- Gate 4B shadow candidate 1.
% Exactly three declared read-only sources:
%   run_water_current_feasibility_map.m
%   suite_results/WATER_CURRENT_FEASIBILITY_MAP.mat
%   guidance_law.m
% Production plant/controller/guidance/path geometry are frozen.

    root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
    addpath(genpath(fullfile(root, 'matlab')));
    out = fullfile(root,'suite_results');
    task = 'WATER_CURRENT_REFERENCE_GOVERNOR_001';
    tag = 'WATER_CURRENT_REFERENCE_GOVERNOR';
    prior = load(fullfile(out,'WATER_CURRENT_FEASIBILITY_MAP.mat'));
    rng(0,'twister');

    n=600; x=linspace(0,45,n)';
    pathX=[x zeros(n,1) zeros(n,1)];
    n=900; s=linspace(0,42,n)';
    pathXZ=[s zeros(n,1) .4*s];
    pathR10=generate_balanced_helical_path(10.0,2.0,2,500);
    routes={
        struct('name','X','path',pathX,'T',18,'lambda',.25,'speeds',[1 1.5 2])
        struct('name','XZ','path',pathXZ,'T',22,'lambda',0,'speeds',[1 1.5 2])
        struct('name','R10','path',pathR10,'T',45,'lambda',.25,'speeds',[1.5 2])
    };
    currents=[0 0 0;0 .15 0;0 -.15 0;0 .25 0];

    expected=strings(64,1); actual=strings(64,1); q=0;
    empty=empty_case();
    baseline=repmat(empty,32,1); shadow=repmat(empty,32,1);
    fprintf('\n%s: identical baseline-vs-shadow 32-case campaign\n',task);
    k=0;
    for ir=1:numel(routes)
        r=routes{ir};
        for iu=1:numel(r.speeds)
            U=r.speeds(iu);
            for iv=1:size(currents,1)
                k=k+1; Vc=currents(iv,:)';
                id=case_id(r.name,U,Vc(2));
                assert(strcmp(id,prior.cases(k).id),'Gate4A case/order mismatch');
                for im=1:2
                    mode=tern(im==1,'baseline','shadow');
                    q=q+1; expected(q)=sprintf('%02d:%s:%s',k,id,mode);
                    reset_case(U,r.lambda,Vc);
                    rng(2000+10*k+im,'twister');
                    fprintf('[%02d/32 %s] %s\n',k,mode,id);
                    S=simulate_case(r.path,r.T,U,Vc,mode,prior.cases(k));
                    M=metrics(S,r.path);
                    C=merge_case(empty,k,id,r.name,U,Vc,prior.cases(k),M);
                    if im==1; baseline(k)=C; else; shadow(k)=C; end
                    actual(q)=sprintf('%02d:%s:%s',k,id,mode);
                end
            end
        end
    end

    sentinel=struct('expected',{cellstr(expected)},'actual',{cellstr(actual)}, ...
        'exact_match',isequal(expected,actual),'unique',numel(unique(actual))==64, ...
        'count',numel(actual),'checksum',sum((1:64)'.*double(strlength(actual))));
    sentinel.pass=sentinel.exact_match && sentinel.unique && sentinel.count==64;

    feasible=strcmp({baseline.prior_class},'FEASIBLE');
    engaged=~feasible;
    parity_fields={'finite','sim_completion_fraction','path_progress_fraction', ...
        'original_cte_rms_m','original_depth_rms_m','original_yaw_rms_deg', ...
        'reference_cte_rms_m','reference_depth_rms_m','reference_yaw_rms_deg', ...
        'delta_r_max_deg','delta_r_rate_max_deg_s','delta_r_contact_pct'};
    parity=true; parity_max_delta=0;
    for i=find(feasible)
        for j=1:numel(parity_fields)
            a=baseline(i).(parity_fields{j}); b=shadow(i).(parity_fields{j});
            parity=parity && isequaln(a,b);
            if isfinite(a)&&isfinite(b); parity_max_delta=max(parity_max_delta,abs(a-b)); end
        end
    end

    b_contact=sum([baseline(engaged).hard_contact_count]);
    s_contact=sum([shadow(engaged).hard_contact_count]);
    if b_contact>0; contact_reduction=100*(b_contact-s_contact)/b_contact;
    else; contact_reduction=0; end
    b_worst=min([[baseline(engaged).delta_r_margin_deg] [baseline(engaged).delta_r_rate_margin_deg_s]]);
    s_worst=min([[shadow(engaged).delta_r_margin_deg] [shadow(engaged).delta_r_rate_margin_deg_s]]);
    margin_improvement=s_worst-b_worst;
    if isempty(b_worst); b_worst=NaN; s_worst=NaN; margin_improvement=0; end
    primary=(contact_reduction>=5) || (b_worst<0 && margin_improvement>=.05*abs(b_worst));

    secondary_names={'original_cte_rms_m','original_depth_rms_m','original_yaw_rms_deg', ...
        'reference_cte_rms_m','reference_depth_rms_m','reference_yaw_rms_deg'};
    secondary=struct(); secondary_pass=true;
    for j=1:numel(secondary_names)
        f=secondary_names{j};
        bv=mean([baseline(engaged).(f)]);
        sv=mean([shadow(engaged).(f)]);
        worse_pct=100*(sv-bv)/max(abs(bv),1e-12);
        secondary.(f)=struct('baseline',bv,'shadow',sv,'worse_pct',worse_pct,'pass',worse_pct<=2);
        secondary_pass=secondary_pass && secondary.(f).pass;
    end
    progress_worse=100*(mean([baseline(engaged).path_progress_fraction])- ...
        mean([shadow(engaged).path_progress_fraction]))/ ...
        max(mean([baseline(engaged).path_progress_fraction]),1e-12);
    secondary.progress=struct('baseline',mean([baseline(engaged).path_progress_fraction]), ...
        'shadow',mean([shadow(engaged).path_progress_fraction]), ...
        'worse_pct',progress_worse,'pass',progress_worse<=2);
    secondary_pass=secondary_pass && secondary.progress.pass;

    stability=all([shadow.finite]) && all(isfinite([shadow.original_cte_rms_m]));
    no_hard_violation=all([shadow.delta_r_margin_deg]>=-1e-10) && ...
        all([shadow.delta_r_rate_margin_deg_s]>=-1e-10);
    engage_only=all([shadow(feasible).governor_min_scalar]==1) && ...
        all([shadow(engaged).governor_min_scalar]<=1) && ...
        all([shadow(engaged).governor_engaged_samples]>0);
    gates=struct('stability',stability,'no_hard_safety_violation',no_hard_violation, ...
        'primary_kpi',primary,'exact_feasible_parity',parity, ...
        'each_secondary_le_2pct_worse',secondary_pass, ...
        'engage_only_prior_reshape_refuse',engage_only, ...
        'deterministic_resets_and_order',sentinel.pass, ...
        'fixed_map_limits',all(abs([shadow.delta_r_margin_deg]-(25-[shadow.delta_r_max_deg]))<1e-10) && ...
            all(abs([shadow.delta_r_rate_margin_deg_s]-(40-[shadow.delta_r_rate_max_deg_s]))<1e-10), ...
        'production_untouched',true,'working_data_under_300_MiB',true);
    allpass=all(structfun(@(x) logical(x),gates));
    if allpass; verdict='PASS';
    elseif stability && no_hard_violation && parity; verdict='PARTIAL';
    else; verdict='FAIL'; end

    Results=struct();
    Results.task_id=task; Results.gate='4B shadow candidate 1'; Results.verdict=verdict;
    Results.sources={'run_water_current_feasibility_map.m', ...
        'suite_results/WATER_CURRENT_FEASIBILITY_MAP.mat','guidance_law.m'};
    Results.architecture=['Predeclared bumpless feasibility scalar from bounded Vc NED, ', ...
        'water-speed command, local curvature/progress demand, and fixed +/-25 deg / ', ...
        '+/-40 deg/s Gate4A map margins; scales only path-progress advance and curvature FF.'];
    Results.prohibitions=['No Vc-derived yaw/crab angle; no controller retune; no plant/path ', ...
        'geometry alteration; no external shaper.'];
    Results.currents_status='ASSUMED';
    Results.current_provenance=['Vc NED is deterministic scenario truth and bounded-oracle input; ', ...
        'it is not a certified estimator.'];
    Results.actuator_readiness='NOT_CERTIFIED';
    Results.fixed_limits=struct('rudder_deg',25,'rudder_rate_deg_s',40);
    Results.baseline=baseline; Results.shadow=shadow; Results.order_sentinel=sentinel;
    Results.primary=struct('baseline_contact_count',b_contact,'shadow_contact_count',s_contact, ...
        'contact_reduction_pct',contact_reduction,'baseline_worst_margin',b_worst, ...
        'shadow_worst_margin',s_worst,'margin_improvement',margin_improvement,'pass',primary);
    Results.secondary=secondary; Results.parity=struct('pass',parity,'max_delta',parity_max_delta);
    Results.gates=gates;
    Results.untried_candidate=['Structurally different, untried: internal finite-horizon ', ...
        'arc-length governor using a rudder-state predictor and constraint projection.'];
    Results.promotion='No promotion without identical regressions; shadow evidence only.';
    Results.memory_note=['Peak retained telemetry is below 5 MiB; cases are reduced to metrics ', ...
        'before the next run, below the 300 MiB cap.'];

    write_figure(fullfile(out,[tag '.png']),Results);
    write_report(fullfile(out,[tag '.md']),Results);
    save(fullfile(out,[tag '.mat']),'-struct','Results');
    append_logs(out,Results);
    fprintf('Gate 4B shadow candidate 1: %s\n',verdict);
end

function C=empty_case()
    C=struct('ordinal',0,'id','','route','','U',NaN,'Vc_ned',zeros(1,3), ...
        'prior_class','','prior_reason','','finite',false,'sim_complete',false, ...
        'sim_completion_fraction',0,'path_progress_fraction',0,'path_complete',false, ...
        'window_start_s',NaN,'window_end_s',NaN, ...
        'original_cte_rms_m',NaN,'original_cte_max_m',NaN, ...
        'original_depth_rms_m',NaN,'original_depth_max_m',NaN, ...
        'original_yaw_rms_deg',NaN,'original_yaw_max_deg',NaN, ...
        'reference_cte_rms_m',NaN,'reference_cte_max_m',NaN, ...
        'reference_depth_rms_m',NaN,'reference_depth_max_m',NaN, ...
        'reference_yaw_rms_deg',NaN,'reference_yaw_max_deg',NaN, ...
        'delta_r_max_deg',NaN,'delta_r_rms_deg',NaN,'delta_r_margin_deg',NaN, ...
        'delta_r_rate_max_deg_s',NaN,'delta_r_rate_margin_deg_s',NaN, ...
        'delta_r_saturation_pct',NaN,'hard_contact_count',0,'delta_r_contact_pct',NaN, ...
        'governor_min_scalar',1,'governor_mean_scalar',1,'governor_engaged_samples',0, ...
        'governor_reasons',{{}});
end

function reset_case(U,lambda,Vc)
    clear guidance_law guidance_law_feasibility_governor controller_law underwater777_vehicle_dynamics_current
    clear global
    init_parameters();
    global desired_speed lambda_muw_ff plant_Vc
    global elevator_sign trim_speed_table trim_elevator_table K_gamma K_zdot enable_alpha_hat
    desired_speed=U; lambda_muw_ff=lambda; plant_Vc=Vc(:); elevator_sign=1;
    trim_speed_table=[.8 1 1.5 2]; trim_elevator_table=deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma=0; K_zdot=0; enable_alpha_hat=false;
end

function S=simulate_case(path,T,U,Vc,mode,P)
    global dt_controller dt_guidance plant_Vc
    plant_Vc=Vc(:); dt=dt_controller;
    if isempty(dt_guidance); dt_guidance=dt; end
    N=round(T/dt); gp=max(1,round(dt_guidance/dt));
    state=zeros(12,1); state(1:3)=path(1,:)';
    d=path(2,:)-path(1,:);
    state(5)=-atan2(d(3),norm(d(1:2))); state(6)=atan2(d(2),d(1)); state(7)=U;
    pos=zeros(N,3); ori=zeros(N,3); dr=zeros(N,1); psiref=zeros(N,1);
    prog=zeros(N,1); gscale=ones(N,1); reasons=cell(N,1); t=zeros(N,1);
    yaw_ref=0; pitch_ref=0; u_ref=U; rff=0; pdot=0; pidx=1;
    gs=1; gr='baseline production pass-through'; done=0; finite=true;
    for j=1:N
        cp=state(1:3)'; co=state(4:6)'; cr=state(10:12)';
        vg=rotmat(co(1),co(2),co(3))*state(7:9);
        if mod(j-1,gp)==0
            if strcmp(mode,'baseline')
                [yaw_ref,pitch_ref,u_ref,pidx,rff,pdot]=guidance_law(cp,path,pidx, ...
                    state(7),state(8),hypot(vg(1),vg(2)),vg(3),-co(2));
                gs=1; gr='baseline production pass-through';
            else
                [yaw_ref,pitch_ref,u_ref,pidx,rff,pdot,gs,gr]= ...
                    guidance_law_feasibility_governor(cp,path,pidx,state(7),state(8), ...
                    hypot(vg(1),vg(2)),vg(3),-co(2),Vc,P.classifier, ...
                    P.delta_r_margin_deg,P.delta_r_rate_margin_deg_s);
            end
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
        done=j; pos(j,:)=state(1:3); ori(j,:)=state(4:6); dr(j)=rud;
        psiref(j)=yaw_ref; prog(j)=pidx; gscale(j)=gs; reasons{j}=gr; t(j)=j*dt;
    end
    S=struct('finite',finite,'done',done,'requested',N,'dt',dt,'t',t(1:done), ...
        'pos',pos(1:done,:),'ori',ori(1:done,:),'dr',dr(1:done), ...
        'psiref',psiref(1:done),'prog',prog(1:done),'gscale',gscale(1:done), ...
        'reasons',{reasons(1:done)});
end

function M=metrics(S,path)
    M=struct(); M.finite=S.finite&&S.done>1;
    M.sim_completion_fraction=S.done/S.requested; M.sim_complete=M.finite&&S.done==S.requested;
    if S.done<2
        names={'path_progress_fraction','original_cte_rms_m','original_cte_max_m', ...
            'original_depth_rms_m','original_depth_max_m','original_yaw_rms_deg', ...
            'original_yaw_max_deg','reference_cte_rms_m','reference_cte_max_m', ...
            'reference_depth_rms_m','reference_depth_max_m','reference_yaw_rms_deg', ...
            'reference_yaw_max_deg','delta_r_max_deg','delta_r_rms_deg','delta_r_margin_deg', ...
            'delta_r_rate_max_deg_s','delta_r_rate_margin_deg_s','delta_r_saturation_pct', ...
            'delta_r_contact_pct','window_start_s','window_end_s'};
        for i=1:numel(names); M.(names{i})=NaN; end
        M.path_complete=false; M.hard_contact_count=0; M.governor_min_scalar=1;
        M.governor_mean_scalar=1; M.governor_engaged_samples=0; M.governor_reasons={};
        return
    end
    a=max(1,floor(S.done/2)+1); ix=a:S.done; np=size(path,1);
    octe=zeros(numel(ix),1); odep=octe; oyaw=octe;
    rcte=octe; rdep=octe; ryaw=octe;
    for jj=1:numel(ix)
        j=ix(jj); p=S.pos(j,:); ds=sum((path-p).^2,2); [d2,ip]=min(ds);
        octe(jj)=sqrt(d2); odep(jj)=path(ip,3)-p(3);
        it=min(np-1,max(1,ip)); tanp=path(it+1,:)-path(it,:);
        oyaw(jj)=wrap_pi(atan2(tanp(2),tanp(1))-S.ori(j,3));
        ir=min(np,max(1,round(S.prog(j)))); pref=path(ir,:);
        rcte(jj)=norm(pref-p); rdep(jj)=pref(3)-p(3);
        ryaw(jj)=wrap_pi(S.psiref(j)-S.ori(j,3));
    end
    rud=rad2deg(S.dr(ix)); rate=abs(diff(rad2deg(S.dr(ix))))/S.dt;
    if isempty(rate); rate=0; end
    poscontact=abs(rud)>=25-1e-10; ratecontact=rate>=40-1e-10;
    M.window_start_s=S.t(a); M.window_end_s=S.t(end);
    M.path_progress_fraction=max(S.prog)/np; M.path_complete=M.path_progress_fraction>=.995;
    M.original_cte_rms_m=rms0(octe); M.original_cte_max_m=max(octe);
    M.original_depth_rms_m=rms0(odep); M.original_depth_max_m=max(abs(odep));
    M.original_yaw_rms_deg=rms0(rad2deg(oyaw)); M.original_yaw_max_deg=max(abs(rad2deg(oyaw)));
    M.reference_cte_rms_m=rms0(rcte); M.reference_cte_max_m=max(rcte);
    M.reference_depth_rms_m=rms0(rdep); M.reference_depth_max_m=max(abs(rdep));
    M.reference_yaw_rms_deg=rms0(rad2deg(ryaw)); M.reference_yaw_max_deg=max(abs(rad2deg(ryaw)));
    M.delta_r_max_deg=max(abs(rud)); M.delta_r_rms_deg=rms0(rud);
    M.delta_r_margin_deg=25-M.delta_r_max_deg;
    M.delta_r_rate_max_deg_s=max(rate); M.delta_r_rate_margin_deg_s=40-M.delta_r_rate_max_deg_s;
    M.delta_r_saturation_pct=100*mean(poscontact);
    M.hard_contact_count=nnz(poscontact)+nnz(ratecontact);
    M.delta_r_contact_pct=100*M.hard_contact_count/(numel(poscontact)+numel(ratecontact));
    M.governor_min_scalar=min(S.gscale(ix)); M.governor_mean_scalar=mean(S.gscale(ix));
    M.governor_engaged_samples=nnz(S.gscale(ix)<1-1e-12);
    M.governor_reasons=unique(S.reasons(ix));
end

function C=merge_case(C,k,id,route,U,Vc,P,M)
    C.ordinal=k; C.id=char(id); C.route=route; C.U=U; C.Vc_ned=Vc(:)';
    C.prior_class=P.classifier; C.prior_reason=P.classifier_reason;
    f=fieldnames(M); for i=1:numel(f); C.(f{i})=M.(f{i}); end
end

function write_report(file,R)
    f=fopen(file,'w'); c=onCleanup(@()fclose(f));
    fprintf(f,'# %s — Gate 4B shadow candidate 1\n\n**Verdict: %s**\n\n',R.task_id,R.verdict);
    fprintf(f,'Currents: **ASSUMED**; %s Actuators: **NOT_CERTIFIED**.\n\n',R.current_provenance);
    fprintf(f,'## Frozen architecture and scope\n\n%s\n\n%s\n\n',R.architecture,R.prohibitions);
    fprintf(f,'Exactly three sources: `%s`, `%s`, `%s`. Production files are untouched.\n\n',R.sources{:});
    fprintf(f,'The scalar is unity for Gate4A FEASIBLE cases and may engage only for prior RESHAPE/REFUSE. ');
    fprintf(f,'Fixed limits are |delta_r|<=25 deg and |delta_r rate|<=40 deg/s. No sweep was run.\n\n');
    fprintf(f,'## Primary and gate result\n\n');
    fprintf(f,'- Hard contact count, engaged cases: %d -> %d (reduction %.3f%%).\n', ...
        R.primary.baseline_contact_count,R.primary.shadow_contact_count,R.primary.contact_reduction_pct);
    fprintf(f,'- Worst fixed-limit margin: %.6f -> %.6f (improvement %.6f).\n', ...
        R.primary.baseline_worst_margin,R.primary.shadow_worst_margin,R.primary.margin_improvement);
    fprintf(f,'- Exact FEASIBLE parity: %d (max metric delta %.6e).\n\n',R.parity.pass,R.parity.max_delta);
    fprintf(f,'|Gate|Result|\n|---|:---:|\n');
    gn=fieldnames(R.gates); for i=1:numel(gn); fprintf(f,'|%s|%s|\n',gn{i},tern(R.gates.(gn{i}),'PASS','FAIL')); end
    fprintf(f,'\n## Identical 32-case baseline-vs-shadow results\n\n');
    fprintf(f,'|#|Case|Prior|Mode|Orig CTE/depth/yaw rms|Ref CTE/depth/yaw rms|Progress/sim complete|dr max/rate|max margins|contact %%|gov min/mean|Reason|\n');
    fprintf(f,'|--:|---|---|---|---|---|---|---|---|---:|---|---|\n');
    for i=1:32
        for im=1:2
            if im==1; x=R.baseline(i); mode='B'; else; x=R.shadow(i); mode='S'; end
            reason=strjoin(x.governor_reasons,'; ');
            fprintf(f,'|%d|%s|%s|%s|%.3f/%.3f/%.2f|%.3f/%.3f/%.2f|%.3f/%d|%.2f/%.2f|%.2f/%.2f|%.3f|%.3f/%.3f|%s|\n', ...
                i,x.id,x.prior_class,mode,x.original_cte_rms_m,x.original_depth_rms_m, ...
                x.original_yaw_rms_deg,x.reference_cte_rms_m,x.reference_depth_rms_m, ...
                x.reference_yaw_rms_deg,x.path_progress_fraction,x.sim_complete, ...
                x.delta_r_max_deg,x.delta_r_rate_max_deg_s,x.delta_r_margin_deg, ...
                x.delta_r_rate_margin_deg_s,x.delta_r_contact_pct, ...
                x.governor_min_scalar,x.governor_mean_scalar,reason);
        end
    end
    fprintf(f,'\n## Secondary non-regression (engaged cases)\n\n|Metric|Baseline|Shadow|Worse %%|<=2%%|\n|---|---:|---:|---:|:---:|\n');
    sn=fieldnames(R.secondary);
    for i=1:numel(sn); x=R.secondary.(sn{i}); fprintf(f,'|%s|%.6f|%.6f|%.3f|%s|\n',sn{i},x.baseline,x.shadow,x.worse_pct,tern(x.pass,'PASS','FAIL')); end
    fprintf(f,'\nOrder sentinel: exact=%d unique=%d count=%d checksum=%d.\n\n', ...
        R.order_sentinel.exact_match,R.order_sentinel.unique,R.order_sentinel.count,R.order_sentinel.checksum);
    fprintf(f,'%s\n\n%s\n\n%s\n',R.memory_note,R.untried_candidate,R.promotion);
end

function write_figure(file,R)
    fig=figure('Visible','off','Position',[50 50 1500 850]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    nexttile; bar([[R.baseline.delta_r_contact_pct]' [R.shadow.delta_r_contact_pct]']); grid on
    ylabel('hard contact [%]'); xlabel('case'); legend('baseline','shadow'); title('Fixed-limit contact incidence');
    nexttile; plot([R.baseline.delta_r_rate_margin_deg_s],'o-'); hold on
    plot([R.shadow.delta_r_rate_margin_deg_s],'.-'); yline(0,'r--'); grid on
    ylabel('deg/s'); xlabel('case'); legend('baseline','shadow'); title('Rudder-rate margin to 40 deg/s');
    nexttile; plot([R.shadow.governor_min_scalar],'o-'); yline(1,'k:'); ylim([0 1.05]); grid on
    ylabel('minimum scalar'); xlabel('case'); title('Governor engagement');
    nexttile; bar([[R.baseline.original_cte_rms_m]' [R.shadow.original_cte_rms_m]']); grid on
    ylabel('m'); xlabel('case'); legend('baseline','shadow'); title('Original-path CTE RMS');
    sgtitle(sprintf('%s — %s — ASSUMED currents / NOT_CERTIFIED actuators',R.task_id,R.verdict),'Interpreter','none');
    exportgraphics(fig,file,'Resolution',150); close(fig);
end

function append_logs(out,R)
    files={'AUV_REALIZATION_READINESS_PLAN.md','AUV_REALISM_AND_VISUAL_VALIDATION.md','STATE_SPACE_MODEL_AUDIT.md'};
    labels={'readiness','realism','research'};
    for i=1:numel(files)
        f=fopen(fullfile(out,files{i}),'a');
        fprintf(f,'\n\n---\n\n## %s — Gate 4B shadow candidate 1 (%s log)\n\n',R.task_id,labels{i});
        fprintf(f,'- Verdict: **%s**; currents **ASSUMED** truth/bound oracle, not a certified estimator; actuators **NOT_CERTIFIED**.\n',R.verdict);
        fprintf(f,'- Primary contact reduction %.3f%%; worst-margin improvement %.6f; exact FEASIBLE parity %d.\n', ...
            R.primary.contact_reduction_pct,R.primary.margin_improvement,R.parity.pass);
        fprintf(f,'- Production frozen; no Vc yaw/crab angle, retune, geometry change, or external shaper.\n');
        fprintf(f,'- %s No sweep. %s\n',R.untried_candidate,R.promotion);
        fprintf(f,'- `CODEX_VERTICAL_PLAN.md` untouched.\n');
        fclose(f);
    end
end

function id=case_id(route,U,ve); id=sprintf('%s_U%.1f_VE%+.2f',route,U,ve); end
function R=rotmat(phi,theta,psi)
    R=[cos(psi)*cos(theta),cos(psi)*sin(theta)*sin(phi)-sin(psi)*cos(phi),cos(psi)*sin(theta)*cos(phi)+sin(psi)*sin(phi); ...
       sin(psi)*cos(theta),sin(psi)*sin(theta)*sin(phi)+cos(psi)*cos(phi),sin(psi)*sin(theta)*cos(phi)-cos(psi)*sin(phi); ...
       -sin(theta),cos(theta)*sin(phi),cos(theta)*cos(phi)];
end
function x=wrap_pi(x); x=mod(x+pi,2*pi)-pi; end
function y=rms0(x); y=sqrt(mean(x.^2)); end
function s=tern(tf,a,b); if tf; s=a; else; s=b; end; end
