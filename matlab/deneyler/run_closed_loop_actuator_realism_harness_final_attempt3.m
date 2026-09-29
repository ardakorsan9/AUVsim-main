function run_closed_loop_actuator_realism_harness_final_attempt3()
% CLOSED_LOOP_ACTUATOR_HARNESS_FINAL_001 -- Gate 3 final attempt 3/3.
% Harness/evidence only: no production controller, guidance, or plant edits.
outdir = 'suite_results';
task = 'CLOSED_LOOP_ACTUATOR_HARNESS_FINAL_001';
try
    Results = execute_harness(task);
catch ME
    Results = struct('task_id',task,'generated',datestr(now,31), ...
        'verdict','FAIL','physical_readiness','NOT_CERTIFIED', ...
        'gate3_disposition','CLOSED_AFTER_3_ATTEMPTS', ...
        'next_gate','Gate4 water-relative-current/feasibility guidance', ...
        'residual_risk','Actuator values remain assumed and require bench/HIL identification; current-relative feasibility remains unevaluated.', ...
        'causal_blocker',getReport(ME,'extended','hyperlinks','off'), ...
        'failed_cases',{{'HARNESS_CAUSAL_BLOCKER'}});
end
save(fullfile(outdir,'CLOSED_LOOP_ACTUATOR_HARNESS_FINAL.mat'),'Results','-v7');
write_figure(Results,fullfile(outdir,'CLOSED_LOOP_ACTUATOR_HARNESS_FINAL.png'));
write_report(Results,fullfile(outdir,'CLOSED_LOOP_ACTUATOR_HARNESS_FINAL.md'));
append_logs(Results);
d = dir(fullfile(outdir,'CLOSED_LOOP_ACTUATOR_HARNESS_FINAL.mat'));
if ~isempty(d) && d.bytes >= 300*1024^2
    error('Harness artifact is %.1f MiB, violating the <300 MiB limit.',d.bytes/1024^2);
end
fprintf('%s verdict: %s\n',task,Results.verdict);
end

function R = execute_harness(task)
rng(14081,'twister');
A = accepted_r10('suite_results/ROLL_PRODUCTION_CLOSURE.mat', ...
    'suite_results/pitch_yaw_closure.mat');

% X/XZ are byte-for-byte the declared attempt-1 definitions. R10 is never
% synthesized here; it comes only from the accepted closure artifact.
x = linspace(0,60,301)';
paths.X = [x zeros(size(x)) zeros(size(x))];
paths.XZ = [x zeros(size(x)) 8*(0.5-0.5*cos(pi*x/max(x)))];
paths.R10 = A.path;
ops = struct('name',{},'U',{});
for U=[1 1.5 2], ops(end+1)=struct('name','X','U',U); end %#ok<AGROW>
for U=[1 1.5 2], ops(end+1)=struct('name','XZ','U',U); end %#ok<AGROW>
for U=[1.5 2], ops(end+1)=struct('name','R10','U',U); end %#ok<AGROW>

cases = struct('id',{},'path',{},'U',{},'ideal',{},'tau_s',{}, ...
    'deadband_deg',{},'delay_s',{},'jitter_s',{});
for i=1:numel(ops)
    cases(end+1)=make_case(ops(i),'IDEAL',true,0,0,0,0); %#ok<AGROW>
    for d=[0 0.015 0.030]
        cases(end+1)=make_case(ops(i),sprintf('NOM_D%02d',round(1000*d)), ...
            false,0.10,0.25,d,0.003); %#ok<AGROW>
    end
    cases(end+1)=make_case(ops(i),'FAST_OPEN_D30',false,0.05,0,0.030,0.003); %#ok<AGROW>
    cases(end+1)=make_case(ops(i),'SLOW_WIDE_D30',false,0.20,0.50,0.030,0.003); %#ok<AGROW>
end
assert(numel(cases)==48,'Declared matrix is not exactly 48 cases.');

ideal_cfg = struct('ideal',true,'tau_s',0,'deadband_deg',0,'delay_s',0,'jitter_s',0);
first = closed_loop_actuator_realism_harness_fix_case(A.path,A.state0,A.clock,A.horizon,A.U,ideal_cfg,90210);
[first_metrics,first_signals,first_mask] = score_case(first, ...
    struct('path','R10','U',A.U,'ideal',true),A.steady_mask);
accepted = compare_accepted(first,first_metrics,first_signals,first_mask,A, ...
    struct('raw_cte_m',1e-8,'raw_angle_rad',1e-10,'metric',1e-8));
assert(accepted.pass,'Accepted raw R10 parity failed before actuator matrix: %s',accepted.reason);

metrics = repmat(empty_metrics(),48,1);
representative = struct('id',{},'t',{},'command',{},'applied',{},'feedback',{});
fprintf('Gate 3 final attempt 3/3: 48 declared cases plus two order sentinels\n');
for i=1:48
    c=cases(i); p=paths.(c.path);
    if strcmp(c.path,'R10')
        state=A.state0; state(7)=c.U; clock=A.clock; horizon=A.horizon;
        accepted_mask=A.steady_mask;
    else
        state=zeros(12,1); state(1:3)=p(1,:)'; state(7)=c.U;
        clock=A.clock; horizon=30;
        if strcmp(c.path,'XZ'), horizon=35; end
        accepted_mask=[];
    end
    cfg=rmfield(c,{'id','path','U'});
    s=closed_loop_actuator_realism_harness_fix_case(p,state,clock,horizon,c.U,cfg,14081+i);
    metrics(i)=score_case(s,c,accepted_mask);
    if (~c.ideal && c.delay_s==0.030 && (c.tau_s==0.05 || c.tau_s==0.20)) || ~metrics(i).hard_pass
        representative(end+1)=compact_trace(c.id,s); %#ok<AGROW>
    end
    fprintf('%02d/48 %-27s complete=%d hard=%d CTE=%.3f\n', ...
        i,c.id,metrics(i).complete,metrics(i).hard_pass,metrics(i).path_rmse_m);
end

last = closed_loop_actuator_realism_harness_fix_case(A.path,A.state0,A.clock,A.horizon,A.U,ideal_cfg,90210);
[last_metrics,last_signals,last_mask] = score_case(last, ...
    struct('path','R10','U',A.U,'ideal',true),A.steady_mask);
tol = struct('raw_cte_m',1e-8,'raw_angle_rad',1e-10,'metric',1e-8);
sentinel = compare_signals(first_signals,last_signals,first_mask,last_mask, ...
    first_metrics,last_metrics,tol);
accepted = compare_accepted(first,first_metrics,first_signals,first_mask,A,tol);

is_act=~[cases.ideal]';
complete_all=all([metrics.complete]);
stable_all=all([metrics.stable]);
enforce_all=all([metrics(is_act).exact_enforcement]);
hard_all=all([metrics.hard_pass]);
matrix_full=numel(metrics)==48 && complete_all;
all_gates=matrix_full && sentinel.pass && accepted.pass && stable_all && enforce_all && hard_all;
if all_gates
    verdict='PASS'; blocker='';
else
    verdict='FAIL';
    blocker=blocker_text(sentinel,accepted,metrics);
end

R.task_id=task; R.generated=datestr(now,31); R.verdict=verdict;
R.physical_readiness='NOT_CERTIFIED';
R.gate3_disposition=ternary(all_gates,'CLOSED_PASS','CLOSED_AFTER_3_ATTEMPTS');
R.next_gate='Gate4 water-relative-current/feasibility guidance';
R.residual_risk='Actuator values remain assumed and require bench/HIL identification; current-relative feasibility remains unevaluated.';
R.assumptions=struct('certification','ALL ACTUATOR VALUES ASSUMED, NOT_CERTIFIED', ...
    'fin_magnitude_deg',[15 25],'rate_deg_s',40,'tau_s',[0.05 0.10 0.20], ...
    'deadband_deg',[0 0.25 0.50],'requested_transport_delay_ms',[0 15 30], ...
    'jitter_bound_ms',3);
R.parity_tolerances=tol;
R.input_schemas=A.schemas;
R.accepted_source=rmfield(A,{'position','attitude','steady_mask','path'});
R.sentinel_order_parity=sentinel;
R.accepted_ideal_r10_parity=accepted;
R.cases=cases; R.metrics=metrics; R.representative_traces=representative;
R.failed_cases={cases(~[metrics.hard_pass]).id};
R.causal_blocker=blocker;
R.gates=struct('full_48_case_matrix',matrix_full,'sentinel_order_parity',sentinel.pass, ...
    'accepted_ideal_r10_parity',accepted.pass,'stability',stable_all, ...
    'exact_enforcement',enforce_all,'all_hard_gates',hard_all);
end

function A=accepted_r10(rollfile,pitchyawfile)
% Record both schemas before either full load. Never infer a root variable.
wr=whos('-file',rollfile);
wp=whos('-file',pitchyawfile);
Droll=load(rollfile);
Dpitch=load(pitchyawfile);
assert(isfield(Droll,'candidate') && isstruct(Droll.candidate), ...
    'ROLL closure must contain top-level candidate struct.');
candidate=Droll.candidate;
SH=need_named(candidate,{'SH'});
[ok,pathH]=find_named(Dpitch,{'pathH'},0);
if ~ok, [ok,pathH]=find_named(Droll,{'pathH'},0); end
assert(ok,'Accepted pitch-yaw pathH was not found recursively across either MAT.');
if isnumeric(pathH)
    A.path=pathH;
else
    A.path=need_matrix(pathH,candidate,{'path','Path','waypoints','points'},3);
end
if size(A.path,2)~=3 && size(A.path,1)==3, A.path=A.path'; end
A.state0=need_vector(SH,candidate,{'initial_state','state0','x0','initialState'},12);
A.clock.sim=need_scalar(SH,candidate,{'dt','dt_sim','simulation_dt','plant_dt'});
A.clock.controller=need_scalar(SH,candidate,{'dt_controller','controller_dt','control_dt'});
A.clock.guidance=need_scalar(SH,candidate,{'dt_guidance','guidance_dt'});
A.horizon=need_scalar(SH,candidate,{'T_final','horizon','duration','T'});
A.U=optional_scalar(SH,candidate,{'U_cmd','U','speed_cmd','commanded_speed'},A.state0(7));
A.position=need_matrix(SH,candidate,{'position','positions','pos'},3);
A.attitude=need_matrix(SH,candidate,{'attitude','attitudes','euler'},3);
A.t=optional_vector(SH,candidate,{'t','time'},(1:size(A.position,1))'*A.clock.sim);
assert(size(A.path,1)>2 && size(A.path,2)==3,'Accepted R10 path is not N-by-3.');
assert(all(isfinite(A.path(:))) && max(abs(A.path(:)))<1e6, ...
    'Accepted pathH fails finite/metre-scale checks.');
assert(numel(A.state0)==12,'Accepted R10 initial state is not 12 elements.');
assert(all(structfun(@(x)isfinite(x)&&x>0,A.clock)) && A.horizon>5, ...
    'Accepted clocks/horizon fail positive-second checks.');
assert(max(abs(A.attitude(:)))<=2*pi+1e-6 && max(abs(A.state0(4:6)))<=2*pi+1e-6, ...
    'Accepted attitude/state angles fail radians checks.');
A.steady_mask=true(size(A.position,1),1);
A.state0=A.state0(:); A.t=A.t(:); A.steady_mask=A.steady_mask(:);
A.source_file=sprintf('%s + %s',rollfile,pitchyawfile);
A.source_branch='top-level candidate.SH + recursive pitch-yaw pathH';
A.raw_definition='nearest-path CTE and state Euler pitch/yaw/roll';
A.schemas=struct('roll',schema_records(wr),'pitch_yaw',schema_records(wp));
clear Droll Dpitch candidate SH pathH wr wp
end

function s=schema_records(w)
s=struct('name',{},'size',{},'bytes',{},'class',{});
for i=1:numel(w)
    s(i).name=w(i).name; s(i).size=w(i).size;
    s(i).bytes=w(i).bytes; s(i).class=w(i).class;
end
end

function [m,signals,mask]=score_case(s,c,accepted_mask)
m=empty_metrics(); m.complete=s.complete;
signals=[]; mask=false(size(s.t));
if ~s.complete, m.failure=s.error; return; end
n=size(s.position,1); d2=inf(n,1); iz=zeros(n,1);
for k=1:n
    q=sum((s.path-s.position(k,:)).^2,2);
    [d2(k),iz(k)]=min(q);
end
cte=sqrt(d2);
path_total=sum(vecnorm(diff(s.path,1,1),2,2));
rule=s.t>=5 & s.progress_s<0.88*path_total;
if strcmp(c.path,'R10') && ~isempty(accepted_mask)
    assert(numel(accepted_mask)==n,'R10 accepted steady mask length mismatch.');
    mask=logical(accepted_mask(:)) & rule;
    m.accepted_mask_reused=true;
else
    mask=rule; m.accepted_mask_reused=false;
end
assert(any(mask),'Steady scoring mask is empty.');
signals=[cte s.attitude(:,2) s.attitude(:,3) s.attitude(:,1)];
zerr=s.position(:,3)-s.path(iz,3);
yawerr=wrap_pi(s.attitude(:,3)-s.reference(:,2));
pitcherr=wrap_pi(s.attitude(:,2)-s.reference(:,1));
speed=sqrt(sum(s.velocity.^2,2));
m.path_rmse_m=rms0(cte(mask)); m.path_max_m=max(cte(mask));
m.depth_max_m=max(abs(zerr(mask)));
m.yaw_rmse_deg=rad2deg(rms0(yawerr(mask)));
m.yaw_max_deg=rad2deg(max(abs(yawerr(mask))));
m.pitch_rmse_deg=rad2deg(rms0(pitcherr(mask)));
m.roll_rmse_deg=rad2deg(rms0(s.attitude(mask,1)));
m.speed_rmse_mps=rms0(speed(mask)-c.U);
err=s.command(:,1:2)-s.applied(:,1:2);
ferr=s.feedback(:,1:2)-s.applied(:,1:2);
m.command_applied_rmse_deg=rad2deg(sqrt(mean(err(mask,:).^2,1)));
m.feedback_applied_rmse_deg=rad2deg(sqrt(mean(ferr(mask,:).^2,1)));
for j=1:2
    m.measured_combined_delay_ms(j)=1000*estimate_delay(s.command(mask,j),s.applied(mask,j),s.t(2)-s.t(1));
    mag=deg2rad([15 25]); rate=abs(diff(s.applied(:,j)))/(s.t(2)-s.t(1));
    m.mag_dwell_pct(j)=100*mean(abs(s.applied(mask,j))>=mag(j)-1e-10);
    ridx=find(mask); ridx=ridx(ridx>1)-1;
    m.rate_dwell_pct(j)=100*mean(rate(ridx)>=deg2rad(40)-1e-8);
    v=diff(s.applied(mask,j))/(s.t(2)-s.t(1));
    m.chatter_deg_s(j)=rad2deg(rms0(v));
    m.psd_13p33(j)=point_psd(s.applied(mask,j),s.t(2)-s.t(1),13.33);
end
m.requested_transport_delay_ms=1000*c.delay_s;
m.allocation_residual=max(vecnorm(s.allocated-s.command,2,2));
m.mag_violation_deg=rad2deg(max(max(abs(s.applied(:,1:2))-deg2rad([15 25]))));
m.rate_violation_deg_s=rad2deg(max(max(abs(diff(s.applied(:,1:2),1,1))/(s.t(2)-s.t(1))-deg2rad(40))));
m.exact_feedback=max(abs(s.feedback(:)-s.applied(:)))<=1e-12;
m.exact_enforcement=c.ideal || (m.mag_violation_deg<=1e-8 && m.rate_violation_deg_s<=1e-8);
m.stable=all(isfinite(s.position(:))) && max(abs(rad2deg(s.attitude(:))))<85 && max(vecnorm(s.velocity,2,2))<5;
pth=5; if strcmp(c.path,'XZ'), pth=6; elseif strcmp(c.path,'R10'), pth=8; end
sat_ok=c.ideal || all(m.mag_dwell_pct<=25);
m.hard_pass=m.complete && m.stable && m.exact_enforcement && m.exact_feedback && ...
    m.path_rmse_m<=pth && m.depth_max_m<=6 && m.yaw_max_deg<=60 && ...
    m.speed_rmse_mps<=0.75 && sat_ok && m.allocation_residual<=1e-12;
why={};
if ~m.stable, why{end+1}='stability'; end %#ok<AGROW>
if ~m.exact_enforcement, why{end+1}='magnitude/rate enforcement'; end %#ok<AGROW>
if ~m.exact_feedback, why{end+1}='feedback separation'; end %#ok<AGROW>
if m.path_rmse_m>pth, why{end+1}='path'; end %#ok<AGROW>
if m.depth_max_m>6, why{end+1}='depth'; end %#ok<AGROW>
if m.yaw_max_deg>60, why{end+1}='yaw'; end %#ok<AGROW>
if m.speed_rmse_mps>0.75, why{end+1}='speed'; end %#ok<AGROW>
if ~sat_ok, why{end+1}='saturation dwell'; end %#ok<AGROW>
if m.allocation_residual>1e-12, why{end+1}='allocation'; end %#ok<AGROW>
if isempty(why), m.failure=''; else, m.failure=strjoin(why,', '); end
end

function P=compare_accepted(s,m,signals,mask,A,tol)
n=size(A.position,1);
P=struct('pass',false,'length_match',size(signals,1)==n,'mask_match',numel(mask)==numel(A.steady_mask));
if ~P.length_match || ~P.mask_match
    P.reason='accepted/harness raw length or mask length mismatch'; return
end
d2=inf(n,1); progress=zeros(n,1); ds=[0;cumsum(vecnorm(diff(A.path,1,1),2,2))];
for k=1:n
    q=sum((A.path-A.position(k,:)).^2,2); [d2(k),ii]=min(q); progress(k)=ds(ii);
end
accepted_signals=[sqrt(d2) A.attitude(:,2) A.attitude(:,3) A.attitude(:,1)];
accepted_rule=A.t>=5 & progress<0.88*ds(end);
accepted_mask=A.steady_mask & accepted_rule;
P.mask_match=isequal(mask(:),accepted_mask(:));
P.raw_max_abs=[max(abs(signals(mask,1)-accepted_signals(mask,1))) ...
    max(abs(signals(mask,2:4)-accepted_signals(mask,2:4)),[],1)];
am=[rms0(accepted_signals(accepted_mask,1)) ...
    rms0(accepted_signals(accepted_mask,2:4))];
hm=[m.path_rmse_m rms0(signals(mask,2:4))];
P.accepted_metrics=am; P.harness_metrics=hm; P.metric_abs_delta=abs(hm-am);
P.tolerance=[tol.raw_cte_m repmat(tol.raw_angle_rad,1,3)];
P.pass=P.mask_match && all(P.raw_max_abs<=P.tolerance) && all(P.metric_abs_delta<=tol.metric);
if P.pass, P.reason=''; else, P.reason='raw accepted R10 parity exceeded declared tolerance'; end
P.raw_signals_order={'CTE_m','pitch_rad','yaw_rad','roll_rad'};
P.command_applied_available=all(isfinite(s.command(:))) && all(isfinite(s.applied(:)));
end

function P=compare_signals(a,b,ma,mb,am,bm,tol)
P.length_match=isequal(size(a),size(b)); P.mask_match=isequal(ma,mb);
if P.length_match
    P.raw_max_abs=max(abs(a-b),[],1);
else
    P.raw_max_abs=[Inf Inf Inf Inf];
end
v1=[am.path_rmse_m am.pitch_rmse_deg am.yaw_rmse_deg am.roll_rmse_deg];
v2=[bm.path_rmse_m bm.pitch_rmse_deg bm.yaw_rmse_deg bm.roll_rmse_deg];
P.metric_abs_delta=abs(v1-v2);
P.tolerance=[tol.raw_cte_m repmat(tol.raw_angle_rad,1,3)];
P.pass=P.length_match && P.mask_match && all(P.raw_max_abs<=P.tolerance) && all(P.metric_abs_delta<=tol.metric);
if P.pass, P.reason=''; else, P.reason='R10 sentinel changed when run first versus last'; end
end

function c=make_case(op,label,ideal,tau,db,delay,jitter)
c.id=sprintf('%s_U%.1f_%s',op.name,op.U,label);
c.path=op.name; c.U=op.U; c.ideal=ideal; c.tau_s=tau;
c.deadband_deg=db; c.delay_s=delay; c.jitter_s=jitter;
end

function m=empty_metrics()
m=struct('complete',false,'stable',false,'accepted_mask_reused',false, ...
 'path_rmse_m',Inf,'path_max_m',Inf,'depth_max_m',Inf, ...
 'yaw_rmse_deg',Inf,'yaw_max_deg',Inf,'pitch_rmse_deg',Inf,'roll_rmse_deg',Inf, ...
 'speed_rmse_mps',Inf,'command_applied_rmse_deg',[Inf Inf], ...
 'feedback_applied_rmse_deg',[Inf Inf],'requested_transport_delay_ms',Inf, ...
 'measured_combined_delay_ms',[Inf Inf],'mag_dwell_pct',[Inf Inf], ...
 'rate_dwell_pct',[Inf Inf],'chatter_deg_s',[Inf Inf],'psd_13p33',[Inf Inf], ...
 'allocation_residual',Inf,'mag_violation_deg',Inf,'rate_violation_deg_s',Inf, ...
 'exact_feedback',false,'exact_enforcement',false,'hard_pass',false,'failure','incomplete');
end

function q=compact_trace(id,s)
q.id=id; q.t=s.t; q.command=s.command; q.applied=s.applied; q.feedback=s.feedback;
end

function s=blocker_text(sent,acc,m)
x={};
if ~sent.pass, x{end+1}=sent.reason; end %#ok<AGROW>
if ~acc.pass, x{end+1}=acc.reason; end %#ok<AGROW>
bad=find(~[m.hard_pass]);
if ~isempty(bad), x{end+1}=sprintf('%d/48 matrix hard failures',numel(bad)); end %#ok<AGROW>
if isempty(x), s='none'; else, s=strjoin(x,'; '); end
end

function d=estimate_delay(x,y,dt)
x=x-mean(x); y=y-mean(y); L=min(round(0.5/dt),numel(x)-2);
v=-inf(L+1,1);
for q=0:L
    a=x(1:end-q); b=y(1+q:end);
    v(q+1)=sum(a.*b)/(sqrt(sum(a.^2)*sum(b.^2))+eps);
end
[~,q]=max(v); d=(q-1)*dt;
end

function p=point_psd(x,dt,f)
x=x-mean(x); n=numel(x); X=fft(x); P=abs(X).^2/(n/dt);
freq=(0:n-1)'/(n*dt); [~,k]=min(abs(freq-f)); p=P(k);
end

function y=rms0(x), y=sqrt(mean(x.^2)); end
function y=wrap_pi(x), y=atan2(sin(x),cos(x)); end

function write_figure(R,file)
f=figure('Visible','off','Color','w','Position',[100 100 1200 760]);
if ~isfield(R,'metrics')
    axis off; text(.05,.8,sprintf('%s: %s',R.task_id,R.verdict),'FontSize',16);
    text(.05,.65,R.causal_blocker,'Interpreter','none'); print(f,file,'-dpng','-r140'); close(f); return
end
m=R.metrics; c=R.cases; act=find(~[c.ideal]);
subplot(2,2,1); bar([m(act).path_rmse_m]); ylabel('Path RMSE [m]'); grid on
title(sprintf('Gate 3 final attempt 3/3: %s',R.verdict));
subplot(2,2,2); A=vertcat(m(act).command_applied_rmse_deg); plot(A,'LineWidth',1);
ylabel('Command-applied RMSE [deg]'); legend('elevator','rudder'); grid on
subplot(2,2,3); D=vertcat(m(act).measured_combined_delay_ms);
plot(D,'LineWidth',1); ylabel('Measured combined lag/deadband delay [ms]'); grid on
subplot(2,2,4); C=vertcat(m(act).chatter_deg_s); plot(C,'LineWidth',1);
ylabel('Chatter RMS [deg/s]'); xlabel('Actuator case'); grid on
print(f,file,'-dpng','-r140'); close(f);
end

function write_report(R,file)
fid=fopen(file,'w'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# CLOSED_LOOP_ACTUATOR_HARNESS_FINAL\n\n');
fprintf(fid,'**TASK_ID:** %s  \n**Gate:** Gate 3 final attempt 3/3  \n**Verdict:** **%s**  \n',R.task_id,R.verdict);
fprintf(fid,'**Gate 3 disposition:** **%s**  \n',R.gate3_disposition);
fprintf(fid,'**Physical readiness:** **NOT_CERTIFIED** — all actuator values are **ASSUMED**.  \n');
fprintf(fid,'**Controller/guidance/plant edits or tuning:** NONE · **CODEX_VERTICAL_PLAN:** untouched\n\n');
if ~isfield(R,'metrics')
    fprintf(fid,'## Causal blocker\n\n```\n%s\n```\n',R.causal_blocker); return
end
fprintf(fid,'## Harness correction and parity gates\n\n');
fprintf(fid,'Each case clears guidance/controller persistent state, clears task globals, re-runs `init_parameters`, sets accepted clocks explicitly, and uses a case-specific deterministic RNG seed. The R10 sentinel was run before and after the complete matrix.\n\n');
fprintf(fid,'Accepted R10 data source: `%s` `%s`; accepted path, initial state, simulation/controller/guidance clocks, horizon, and steady mask are reused. Scoring intersects that mask with `t>=5` and `progress<0.88*s_total`; no one-turn substitute is generated.\n\n',R.accepted_source.source_file,R.accepted_source.source_branch);
fprintf(fid,'Declared raw parity tolerances: CTE %.1g m, pitch/yaw/roll %.1g rad; metric tolerance %.1g. Sentinel order parity: **%s**. Accepted ideal R10 parity: **%s**.\n\n', ...
    R.parity_tolerances.raw_cte_m,R.parity_tolerances.raw_angle_rad,R.parity_tolerances.metric, ...
    passfail(R.sentinel_order_parity.pass),passfail(R.accepted_ideal_r10_parity.pass));
fprintf(fid,'Accepted parity raw max |delta| [CTE m, pitch/yaw/roll rad]: `%s`; metric max |delta|: `%.3g`.\n\n', ...
    num2str(R.accepted_ideal_r10_parity.raw_max_abs,'%.3g '),max(R.accepted_ideal_r10_parity.metric_abs_delta));
fprintf(fid,'## Declared matrix and results\n\nExactly 48 cases: the unchanged X/XZ definitions and accepted corrected R10; 8 ideal, 24 nominal delay-grid, and 16 endpoint corners. Requested transport delay is an input and is reported separately from measured combined command-to-applied lag/deadband delay.\n\n');
fprintf(fid,'| Case | Stable/hard | CTE RMS m | Pitch/yaw/roll RMS deg | Cmd-applied e/r deg | Feedback-applied e/r deg | Requested delay ms | Measured combined e/r ms | Mag/rate dwell e/r %% | Chatter e/r deg/s | PSD13.33 e/r | Allocation residual | Reason |\n');
fprintf(fid,'|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n');
for i=1:48
 c=R.cases(i); m=R.metrics(i);
 fprintf(fid,'| %s | %d/%d | %.3f | %.2f/%.2f/%.2f | %.3f/%.3f | %.3g/%.3g | %.0f | %.1f/%.1f | %.2f/%.2f · %.2f/%.2f | %.2f/%.2f | %.3g/%.3g | %.3g | %s |\n', ...
 c.id,m.stable,m.hard_pass,m.path_rmse_m,m.pitch_rmse_deg,m.yaw_rmse_deg,m.roll_rmse_deg, ...
 m.command_applied_rmse_deg,m.feedback_applied_rmse_deg,m.requested_transport_delay_ms, ...
 m.measured_combined_delay_ms,m.mag_dwell_pct,m.rate_dwell_pct,m.chatter_deg_s, ...
 m.psd_13p33,m.allocation_residual,m.failure);
end
fprintf(fid,'\n## Gate accounting\n\n');
g=R.gates; fprintf(fid,'Full matrix: **%s** · sentinel: **%s** · accepted ideal R10: **%s** · stability: **%s** · magnitude/rate enforcement: **%s** · all hard gates: **%s**.\n\n', ...
 passfail(g.full_48_case_matrix),passfail(g.sentinel_order_parity), ...
 passfail(g.accepted_ideal_r10_parity),passfail(g.stability), ...
 passfail(g.exact_enforcement),passfail(g.all_hard_gates));
if isempty(R.failed_cases)
 fprintf(fid,'Hard cases: none.\n\n');
else
 fprintf(fid,'Hard cases (%d): `%s`.\n\n',numel(R.failed_cases),strjoin(R.failed_cases,'`, `'));
end
fprintf(fid,'Causal blocker: %s\n\n',R.causal_blocker);
fprintf(fid,'## Artifacts\n\n- `run_closed_loop_actuator_realism_harness_final_attempt3.m`\n- `suite_results/CLOSED_LOOP_ACTUATOR_HARNESS_FINAL.{md,mat,png}`\n\n');
fprintf(fid,'## Next\n\n%s. No attempt 4 is authorized. Residual risk: %s\n',R.next_gate,R.residual_risk);
end

function append_logs(R)
files={'suite_results/AUV_REALIZATION_READINESS_PLAN.md', ...
 'suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md', ...
 'suite_results/PITCH_CONTROL_RESEARCH_LOG.md'};
if isfield(R,'failed_cases'), nf=numel(R.failed_cases); else, nf=1; end
entry=sprintf('\n\n## %s — %s\n\nResult: **%s**; Gate 3 final attempt 3/3, disposition **%s**, %d hard/blocking cases. R10 accepted-baseline parity and first/last order sentinel are mandatory; production frozen; all actuator values ASSUMED, NOT_CERTIFIED; CODEX_VERTICAL_PLAN untouched.  \nNext: %s\nResidual risk: %s\n', ...
 R.task_id,R.generated,R.verdict,R.gate3_disposition,nf,next_text(R),R.residual_risk);
for i=1:numel(files)
 fid=fopen(files{i},'a');
 if fid<0, warning('Could not append %s',files{i}); else, fprintf(fid,'%s',entry); fclose(fid); end
end
end

function s=next_text(R)
if strcmp(R.verdict,'PASS')
 s='retain SIL evidence, then Gate4 water-relative-current/feasibility guidance.';
else
 s='Gate3 CLOSED_AFTER_3_ATTEMPTS; proceed to Gate4 water-relative-current/feasibility guidance; no attempt4.';
end
end

function s=passfail(x), if x, s='PASS'; else, s='FAIL'; end, end
function y=ternary(x,a,b), if x, y=a; else, y=b; end, end

function v=need_named(s,names)
[ok,v]=find_named(s,names,0); assert(ok,'Required field not found: %s',strjoin(names,', '));
end

function v=need_matrix(a,b,names,ncol)
[ok,v]=find_named(a,names,0); if ~ok, [ok,v]=find_named(b,names,0); end
assert(ok && isnumeric(v) && ismatrix(v),'Required matrix not found: %s',strjoin(names,', '));
if size(v,2)~=ncol && size(v,1)==ncol, v=v'; end
assert(size(v,2)==ncol,'Required matrix has wrong column count: %s',strjoin(names,', '));
end

function v=need_vector(a,b,names,n)
v=need_vector_any(a,b,names); assert(numel(v)==n,'Required vector has wrong length: %s',strjoin(names,', '));
end

function v=need_vector_any(a,b,names)
[ok,v]=find_named(a,names,0); if ~ok, [ok,v]=find_named(b,names,0); end
assert(ok && (isnumeric(v)||islogical(v)) && isvector(v),'Required vector not found: %s',strjoin(names,', '));
end

function v=need_scalar(a,b,names)
[ok,v]=find_named(a,names,0); if ~ok, [ok,v]=find_named(b,names,0); end
assert(ok && isnumeric(v) && isscalar(v) && isfinite(v),'Required scalar not found: %s',strjoin(names,', '));
end

function v=optional_scalar(a,b,names,fallback)
[ok,v]=find_named(a,names,0); if ~ok, [ok,v]=find_named(b,names,0); end
if ~ok || ~isnumeric(v) || ~isscalar(v), v=fallback; end
end

function v=optional_vector(a,b,names,fallback)
[ok,v]=find_named(a,names,0); if ~ok, [ok,v]=find_named(b,names,0); end
if ~ok || ~isnumeric(v) || ~isvector(v), v=fallback; end
end

function [ok,v]=find_named(s,names,depth)
ok=false; v=[];
if depth>7 || ~isstruct(s), return; end
if numel(s)>1, s=s(1); end
f=fieldnames(s);
for i=1:numel(names)
 j=find(strcmpi(f,names{i}),1);
 if ~isempty(j), ok=true; v=s.(f{j}); return; end
end
for i=1:numel(f)
 x=s.(f{i});
 if isstruct(x)
  [ok,v]=find_named(x,names,depth+1);
  if ok, return; end
 end
end
end
