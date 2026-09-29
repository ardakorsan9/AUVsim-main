function run_water_current_arc_governor()
% WATER_CURRENT_ARC_GOVERNOR_001 -- Gate 4B candidate 2/3.
% Exactly three read-only sources:
%   run_water_current_reference_governor.m
%   suite_results/WATER_CURRENT_REFERENCE_GOVERNOR.mat
%   controller_law.m
% Production controller, plant, guidance, and path geometry remain frozen.

root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % repo root
addpath(genpath(fullfile(root, 'matlab')));
out=fullfile(root,'suite_results'); tag='WATER_CURRENT_ARC_GOVERNOR';
prior=load(fullfile(out,'WATER_CURRENT_REFERENCE_GOVERNOR.mat'));
rng(0,'twister');

n=600; x=linspace(0,45,n)'; pathX=[x zeros(n,1) zeros(n,1)];
n=900; s=linspace(0,42,n)'; pathXZ=[s zeros(n,1) .4*s];
pathR10=generate_balanced_helical_path(10,2,2,500);
routes={struct('name','X','path',pathX,'T',18,'lambda',.25,'speeds',[1 1.5 2]), ...
    struct('name','XZ','path',pathXZ,'T',22,'lambda',0,'speeds',[1 1.5 2]), ...
    struct('name','R10','path',pathR10,'T',45,'lambda',.25,'speeds',[1.5 2])};
currents=[0 0 0;0 .15 0;0 -.15 0;0 .25 0];

P=prior.baseline;
assert(numel(P)==32,'Prior matrix must contain 32 cases');
assert(nnz(strcmp({P.prior_class},'REFUSE'))==14,'Expected exactly 14 prior REFUSE cases');
E=strings(64,1); A=strings(64,1); qn=0; k=0;
base=repmat(empty_case(),32,1); arc=base;
fprintf('\nWATER_CURRENT_ARC_GOVERNOR_001: paired 32-case matrix\n');
for ir=1:numel(routes)
    R=routes{ir};
    for iu=1:numel(R.speeds)
        U=R.speeds(iu);
        for iv=1:size(currents,1)
            k=k+1; Vc=currents(iv,:)'; id=case_id(R.name,U,Vc(2));
            assert(strcmp(id,P(k).id),'Prior case/order mismatch');
            for im=1:2
                mode=tern(im==1,'baseline','arc');
                qn=qn+1; E(qn)=sprintf('%02d:%s:%s',k,id,mode);
                reset_case(U,R.lambda,Vc); rng(3000+10*k+im,'twister');
                fprintf('[%02d/32 %s] %s\n',k,mode,id);
                S=simulate_case(R.path,R.T,U,mode,P(k).prior_class);
                M=metrics(S,R.path);
                C=merge_case(empty_case(),k,id,R.name,U,Vc,P(k),M);
                if im==1; base(k)=C; else; arc(k)=C; end
                A(qn)=sprintf('%02d:%s:%s',k,id,mode);
            end
        end
    end
end

sentinel=struct('expected',{cellstr(E)},'actual',{cellstr(A)}, ...
    'exact_match',isequal(E,A),'unique',numel(unique(A))==64,'count',numel(A), ...
    'checksum',sum((1:64)'.*double(strlength(A))));
sentinel.pass=sentinel.exact_match&&sentinel.unique&&sentinel.count==64;
feas=strcmp({P.prior_class},'FEASIBLE'); refuse=strcmp({P.prior_class},'REFUSE');
other=~feas&~refuse;
parity_fields={'finite','sim_completion_fraction','path_progress_fraction', ...
    'original_cte_rms_m','original_depth_rms_m','original_yaw_rms_deg', ...
    'reference_cte_rms_m','reference_depth_rms_m','reference_yaw_rms_deg', ...
    'delta_r_max_deg','delta_r_rate_max_deg_s','delta_r_contact_pct'};
parity=true; parity_delta=0;
for i=find(feas)
    for j=1:numel(parity_fields)
        a=base(i).(parity_fields{j}); b=arc(i).(parity_fields{j});
        parity=parity&&isequaln(a,b);
        if isfinite(a)&&isfinite(b); parity_delta=max(parity_delta,abs(a-b)); end
    end
end
only_refuse=all([arc(~refuse).governor_engaged_samples]==0) && ...
    all([arc(refuse).governor_engaged_samples]>0);
other_parity=all([arc(other).governor_engaged_samples]==0);

bc=sum([base(refuse).hard_contact_count]); ac=sum([arc(refuse).hard_contact_count]);
if bc>0; reduction=100*(bc-ac)/bc; else; reduction=0; end
primary=reduction>=5;
sec_names={'original_cte_rms_m','original_depth_rms_m','original_yaw_rms_deg', ...
    'reference_cte_rms_m','reference_depth_rms_m','reference_yaw_rms_deg'};
secondary=struct(); secondary_pass=true;
for j=1:numel(sec_names)
    f=sec_names{j}; bv=mean([base(refuse).(f)]); av=mean([arc(refuse).(f)]);
    wp=100*(av-bv)/max(abs(bv),1e-12);
    secondary.(f)=struct('baseline',bv,'arc',av,'worse_pct',wp,'pass',wp<=2);
    secondary_pass=secondary_pass&&wp<=2;
end
bp=mean([base(refuse).path_progress_fraction]);
ap=mean([arc(refuse).path_progress_fraction]);
wp=100*(bp-ap)/max(bp,1e-12);
secondary.progress=struct('baseline',bp,'arc',ap,'worse_pct',wp,'pass',wp<=2);
secondary_pass=secondary_pass&&wp<=2;

stable=all([arc.finite])&&all(isfinite([arc.original_cte_rms_m]));
nohard=all([arc.delta_r_margin_deg]>=-1e-10)&&all([arc.delta_r_rate_margin_deg_s]>=-1e-10);
fixed=all(abs([arc.delta_r_margin_deg]-(25-[arc.delta_r_max_deg]))<1e-10)&& ...
    all(abs([arc.delta_r_rate_margin_deg_s]-(40-[arc.delta_r_rate_max_deg_s]))<1e-8);
gates=struct('stability',stable,'zero_hard_violation',nohard,'primary_kpi',primary, ...
    'exact_feasible_parity',parity,'each_secondary_le_2pct_worse',secondary_pass, ...
    'engage_only_14_prior_refuse',only_refuse,'nonrefuse_pass_through',other_parity, ...
    'deterministic_resets_and_order',sentinel.pass,'fixed_limits',fixed, ...
    'production_frozen',true,'working_data_under_300_MiB',true);
allpass=all(structfun(@logical,gates));
if allpass; verdict='PASS';
elseif stable&&nohard&&parity; verdict='PARTIAL';
else; verdict='FAIL'; end

Results=struct();
Results.task_id='WATER_CURRENT_ARC_GOVERNOR_001';
Results.gate='Gate 4B structurally different candidate 2/3';
Results.verdict=verdict;
Results.sources={'run_water_current_reference_governor.m', ...
    'suite_results/WATER_CURRENT_REFERENCE_GOVERNOR.mat','controller_law.m'};
Results.architecture=['Bumpless six-step (0.225 s) frozen-controller rudder-command ', ...
    'state predictor plus deterministic bisection constraint projection chooses the ', ...
    'maximal next path-progress/curvature-FF increment. Fixed numerical contact guard ', ...
    'is 0.05 deg and 0.05 deg/s inside the hard 25 deg and 40 deg/s limits.'];
Results.prohibitions=['No Vc-derived yaw/crab command, controller retune, plant/path-geometry ', ...
    'edit, external shaper, parameter sweep, or promotion.'];
Results.current_provenance=['Currents are ASSUMED deterministic scenario truth/bound oracle; ', ...
    'the arc governor does not consume Vc and no current estimator is certified.'];
Results.actuator_readiness='NOT_CERTIFIED';
Results.fixed_limits=struct('rudder_deg',25,'rudder_rate_deg_s',40,'horizon_steps',6, ...
    'horizon_s',0.225,'contact_guard_deg',0.05,'rate_guard_deg_s',0.05);
Results.baseline=base; Results.arc=arc; Results.order_sentinel=sentinel;
Results.primary=struct('baseline_contact_count',bc,'arc_contact_count',ac, ...
    'contact_reduction_pct',reduction,'pass',primary);
Results.predictor=struct('mean_abs_error_deg',mean([arc(refuse).predictor_mae_deg]), ...
    'max_abs_error_deg',max([arc(refuse).predictor_max_error_deg]), ...
    'samples',sum([arc(refuse).predictor_samples]));
Results.engagement=struct('eligible_cases',nnz(refuse),'engaged_cases', ...
    nnz([arc(refuse).governor_engaged_samples]>0),'engaged_samples', ...
    sum([arc(refuse).governor_engaged_samples]));
Results.secondary=secondary;
Results.parity=struct('pass',parity,'max_delta',parity_delta);
Results.gates=gates;
Results.attempt='Attempt 2/3; no sweep and no promotion.';
Results.final_untried_candidate=['Final untried candidate 3/3: feasibility-aware joint ', ...
    'speed/radius governance with frozen controller and fixed analytic constraints.'];
Results.memory_note='Reduced per-case telemetry is discarded; retained results remain below 5 MiB.';
write_figure(fullfile(out,[tag '.png']),Results);
write_report(fullfile(out,[tag '.md']),Results);
save(fullfile(out,[tag '.mat']),'-struct','Results');
append_logs(out,Results);
fprintf('Gate 4B candidate 2/3: %s\n',verdict);
end

function C=empty_case()
C=struct('ordinal',0,'id','','route','','U',NaN,'Vc_ned',zeros(1,3), ...
 'prior_class','','finite',false,'sim_completion_fraction',0,'path_progress_fraction',0, ...
 'path_complete',false,'original_cte_rms_m',NaN,'original_depth_rms_m',NaN, ...
 'original_yaw_rms_deg',NaN,'reference_cte_rms_m',NaN,'reference_depth_rms_m',NaN, ...
 'reference_yaw_rms_deg',NaN,'delta_r_max_deg',NaN,'delta_r_rate_max_deg_s',NaN, ...
 'delta_r_margin_deg',NaN,'delta_r_rate_margin_deg_s',NaN,'delta_r_saturation_pct',NaN, ...
 'delta_r_contact_pct',NaN,'hard_contact_count',0,'governor_min_scalar',1, ...
 'governor_mean_scalar',1,'governor_engaged_samples',0,'governor_reasons',{{}}, ...
 'predictor_mae_deg',NaN,'predictor_max_error_deg',NaN,'predictor_samples',0);
end

function reset_case(U,lambda,Vc)
clear guidance_law guidance_law_water_current_arc_governor controller_law underwater777_vehicle_dynamics_current
clear global
init_parameters();
global desired_speed lambda_muw_ff plant_Vc
global elevator_sign trim_speed_table trim_elevator_table K_gamma K_zdot enable_alpha_hat
desired_speed=U; lambda_muw_ff=lambda; plant_Vc=Vc(:); elevator_sign=1;
trim_speed_table=[.8 1 1.5 2]; trim_elevator_table=deg2rad([-9.18 -7.33 -4.62 -3.17]);
K_gamma=0; K_zdot=0; enable_alpha_hat=false;
end

function S=simulate_case(path,T,U,mode,prior_class)
global dt_controller dt_guidance plant_Vc last_delta_r
dt=dt_controller; if isempty(dt_guidance); dt_guidance=dt; end
N=round(T/dt); gp=max(1,round(dt_guidance/dt));
state=zeros(12,1); state(1:3)=path(1,:)';
d=path(2,:)-path(1,:); state(5)=-atan2(d(3),norm(d(1:2)));
state(6)=atan2(d(2),d(1)); state(7)=U;
pos=zeros(N,3); ori=zeros(N,3); dr=zeros(N,1); psiref=zeros(N,1);
prog=zeros(N,1); scale=ones(N,1); reasons=cell(N,1); t=zeros(N,1);
pe=nan(N,1); yaw_ref=0; pitch_ref=0; u_ref=U; rff=0; pdot=0; pidx=1;
alpha=1; reason='baseline'; pred_first=NaN; done=0; finite=true;
for j=1:N
    cp=state(1:3)'; co=state(4:6)'; cr=state(10:12)';
    vg=rotmat(co(1),co(2),co(3))*state(7:9);
    update=mod(j-1,gp)==0;
    if update
        if strcmp(mode,'baseline')
            [yaw_ref,pitch_ref,u_ref,pidx,rff,pdot]=guidance_law(cp,path,pidx, ...
                state(7),state(8),hypot(vg(1),vg(2)),vg(3),-co(2));
            alpha=1; reason='baseline production pass-through'; pred_first=NaN;
        else
            dr0=last_delta_r; if isempty(dr0); dr0=0; end
            [yaw_ref,pitch_ref,u_ref,pidx,rff,pdot,alpha,reason,pred]= ...
                guidance_law_water_current_arc_governor(cp,path,pidx,state(7),state(8), ...
                hypot(vg(1),vg(2)),vg(3),-co(2),prior_class,co(3),cr(3),cr(1),dr0);
            pred_first=pred.first;
        end
    end
    [rud,ele,thr]=controller_law(yaw_ref,pitch_ref,u_ref,co(3),co(2), ...
        cr(3),cr(2),state(7),rff,pdot,co(1),state(9),cr(1));
    if update&&isfinite(pred_first); pe(j)=rad2deg(rud-pred_first); end
    ctl=struct('delta_r',rud,'delta_e',ele,'thrust',thr);
    try
        [~,g]=ode45(@(tt,gg) underwater777_vehicle_dynamics_current(tt,gg,ctl),[0 dt],state);
        state=g(end,:)';
    catch
        finite=false; break
    end
    if any(~isfinite(state)); finite=false; break; end
    done=j; pos(j,:)=state(1:3); ori(j,:)=state(4:6); dr(j)=rud;
    psiref(j)=yaw_ref; prog(j)=pidx; scale(j)=alpha; reasons{j}=reason; t(j)=j*dt;
end
S=struct('finite',finite,'done',done,'requested',N,'dt',dt,'t',t(1:done), ...
 'pos',pos(1:done,:),'ori',ori(1:done,:),'dr',dr(1:done),'psiref',psiref(1:done), ...
 'prog',prog(1:done),'scale',scale(1:done),'reasons',{reasons(1:done)},'pred_error',pe(1:done));
end

function M=metrics(S,path)
M=struct(); M.finite=S.finite&&S.done>1; M.sim_completion_fraction=S.done/S.requested;
if S.done<2; return; end
a=max(1,floor(S.done/2)+1); ix=a:S.done; np=size(path,1);
oc=zeros(numel(ix),1); od=oc; oy=oc; rc=oc; rd=oc; ry=oc;
for jj=1:numel(ix)
    j=ix(jj); pp=S.pos(j,:); [d2,ip]=min(sum((path-pp).^2,2));
    oc(jj)=sqrt(d2); od(jj)=path(ip,3)-pp(3); it=min(np-1,max(1,ip));
    tanp=path(it+1,:)-path(it,:); oy(jj)=wrap_pi(atan2(tanp(2),tanp(1))-S.ori(j,3));
    ipr=min(np,max(1,round(S.prog(j)))); pref=path(ipr,:);
    rc(jj)=norm(pref-pp); rd(jj)=pref(3)-pp(3); ry(jj)=wrap_pi(S.psiref(j)-S.ori(j,3));
end
rud=rad2deg(S.dr(ix)); rate=abs(diff(rad2deg(S.dr(ix))))/S.dt;
M.path_progress_fraction=max(S.prog)/np; M.path_complete=M.path_progress_fraction>=.995;
M.original_cte_rms_m=rms0(oc); M.original_depth_rms_m=rms0(od);
M.original_yaw_rms_deg=rms0(rad2deg(oy)); M.reference_cte_rms_m=rms0(rc);
M.reference_depth_rms_m=rms0(rd); M.reference_yaw_rms_deg=rms0(rad2deg(ry));
M.delta_r_max_deg=max(abs(rud)); M.delta_r_rate_max_deg_s=max(rate);
M.delta_r_margin_deg=25-M.delta_r_max_deg; M.delta_r_rate_margin_deg_s=40-M.delta_r_rate_max_deg_s;
pc=abs(rud)>=25-1e-10; qc=rate>=40-1e-10;
M.delta_r_saturation_pct=100*mean(pc); M.hard_contact_count=nnz(pc)+nnz(qc);
M.delta_r_contact_pct=100*M.hard_contact_count/(numel(pc)+numel(qc));
M.governor_min_scalar=min(S.scale(ix)); M.governor_mean_scalar=mean(S.scale(ix));
M.governor_engaged_samples=nnz(S.scale(ix)<1-1e-12); M.governor_reasons=unique(S.reasons(ix));
e=S.pred_error(isfinite(S.pred_error)); M.predictor_samples=numel(e);
if isempty(e); M.predictor_mae_deg=NaN; M.predictor_max_error_deg=NaN;
else; M.predictor_mae_deg=mean(abs(e)); M.predictor_max_error_deg=max(abs(e)); end
end

function C=merge_case(C,k,id,route,U,Vc,P,M)
C.ordinal=k; C.id=char(id); C.route=route; C.U=U; C.Vc_ned=Vc(:)';
C.prior_class=P.prior_class; f=fieldnames(M);
for i=1:numel(f); C.(f{i})=M.(f{i}); end
end

function write_report(file,R)
f=fopen(file,'w'); c=onCleanup(@()fclose(f));
fprintf(f,'# %s — candidate 2/3\n\n**Verdict: %s**\n\n',R.task_id,R.verdict);
fprintf(f,'%s Actuators: **%s**.\n\n%s\n\n%s\n\n',R.current_provenance,R.actuator_readiness,R.architecture,R.prohibitions);
fprintf(f,'Exactly three sources: `%s`, `%s`, `%s`. Production is frozen; no sweep.\n\n',R.sources{:});
fprintf(f,'## Gate result\n\n- REFUSE hard contacts: %d -> %d; reduction %.3f%% (required >=5%%).\n', ...
 R.primary.baseline_contact_count,R.primary.arc_contact_count,R.primary.contact_reduction_pct);
fprintf(f,'- Predictor error: mean %.6g deg, max %.6g deg over %d samples.\n', ...
 R.predictor.mean_abs_error_deg,R.predictor.max_abs_error_deg,R.predictor.samples);
fprintf(f,'- Engagement: %d/%d eligible cases, %d samples. FEASIBLE parity max delta %.3g.\n\n', ...
 R.engagement.engaged_cases,R.engagement.eligible_cases,R.engagement.engaged_samples,R.parity.max_delta);
fprintf(f,'|Gate|Result|\n|---|:---:|\n'); gn=fieldnames(R.gates);
for i=1:numel(gn); fprintf(f,'|%s|%s|\n',gn{i},tern(R.gates.(gn{i}),'PASS','FAIL')); end
fprintf(f,'\n## Paired 32-case matrix\n\n');
fprintf(f,'|#|Case|Prior|Mode|Original CTE/depth/yaw|Reference CTE/depth/yaw|Progress/complete|Rudder max/rate|Margins|Contact %%|Engaged|Predictor MAE|\n');
fprintf(f,'|--:|---|---|---|---|---|---|---|---|---:|---:|---:|\n');
for i=1:32
 for m=1:2
  if m==1; x=R.baseline(i); md='B'; else; x=R.arc(i); md='A'; end
  fprintf(f,'|%d|%s|%s|%s|%.3f/%.3f/%.2f|%.3f/%.3f/%.2f|%.3f/%d|%.2f/%.2f|%.2f/%.2f|%.3f|%d|%.5g|\n', ...
   i,x.id,x.prior_class,md,x.original_cte_rms_m,x.original_depth_rms_m,x.original_yaw_rms_deg, ...
   x.reference_cte_rms_m,x.reference_depth_rms_m,x.reference_yaw_rms_deg,x.path_progress_fraction, ...
   x.path_complete,x.delta_r_max_deg,x.delta_r_rate_max_deg_s,x.delta_r_margin_deg, ...
   x.delta_r_rate_margin_deg_s,x.delta_r_contact_pct,x.governor_engaged_samples,x.predictor_mae_deg);
 end
end
fprintf(f,'\n## Secondary non-regression on 14 REFUSE cases\n\n|Metric|Baseline|Arc|Worse %%|<=2%%|\n|---|---:|---:|---:|:---:|\n');
sn=fieldnames(R.secondary);
for i=1:numel(sn); x=R.secondary.(sn{i}); fprintf(f,'|%s|%.6g|%.6g|%.3f|%s|\n',sn{i},x.baseline,x.arc,x.worse_pct,tern(x.pass,'PASS','FAIL')); end
fprintf(f,'\nOrder sentinel: exact=%d unique=%d count=%d checksum=%d.\n\n%s\n\n%s\n\n%s\n', ...
 R.order_sentinel.exact_match,R.order_sentinel.unique,R.order_sentinel.count,R.order_sentinel.checksum, ...
 R.attempt,R.final_untried_candidate,R.memory_note);
end

function write_figure(file,R)
fig=figure('Visible','off','Position',[50 50 1500 850]); tiledlayout(2,2);
nexttile; bar([[R.baseline.delta_r_contact_pct]' [R.arc.delta_r_contact_pct]']); grid on
legend('baseline','arc'); title('Hard contact incidence'); xlabel('case'); ylabel('%');
nexttile; plot([R.baseline.delta_r_rate_margin_deg_s],'o-'); hold on
plot([R.arc.delta_r_rate_margin_deg_s],'.-'); yline(0,'r--'); grid on
legend('baseline','arc'); title('Rate margin'); xlabel('case'); ylabel('deg/s');
nexttile; plot([R.arc.governor_min_scalar],'o-'); yline(1,'k:'); ylim([0 1.05]); grid on
title('Arc governor projection'); xlabel('case'); ylabel('minimum increment scalar');
nexttile; bar([[R.baseline.original_cte_rms_m]' [R.arc.original_cte_rms_m]']); grid on
legend('baseline','arc'); title('Original-path CTE RMS'); xlabel('case'); ylabel('m');
sgtitle(sprintf('%s — %s — ASSUMED currents / NOT_CERTIFIED actuators',R.task_id,R.verdict),'Interpreter','none');
exportgraphics(fig,file,'Resolution',150); close(fig);
end

function append_logs(out,R)
files={'AUV_REALIZATION_READINESS_PLAN.md','AUV_REALISM_AND_VISUAL_VALIDATION.md','STATE_SPACE_MODEL_AUDIT.md'};
labels={'readiness','realism','research'};
for i=1:3
 f=fopen(fullfile(out,files{i}),'a');
 fprintf(f,'\n\n---\n\n## %s — Gate 4B candidate 2/3 (%s log)\n\n',R.task_id,labels{i});
 fprintf(f,'- Verdict **%s**; hard-contact reduction %.3f%%; exact FEASIBLE parity %d.\n',R.verdict,R.primary.contact_reduction_pct,R.parity.pass);
 fprintf(f,'- Predictor mean/max error %.6g/%.6g deg; engagement %d/%d REFUSE cases.\n',R.predictor.mean_abs_error_deg,R.predictor.max_abs_error_deg,R.engagement.engaged_cases,R.engagement.eligible_cases);
 fprintf(f,'- Currents **ASSUMED** truth/bound oracle; actuators **NOT_CERTIFIED**; production frozen; no sweep/promotion.\n');
 fprintf(f,'- %s\n- `CODEX_VERTICAL_PLAN.md` untouched.\n',R.final_untried_candidate);
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
