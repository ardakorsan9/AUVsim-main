function run_closed_loop_actuator_realism()
% CLOSED_LOOP_ACTUATOR_REALISM_001 -- isolated Gate 3 evidence.
% One invocation executes the complete predeclared matrix and writes artifacts.
rng(14081,'twister');
outdir = 'suite_results';
dt = 0.025;
jitter_s = 0.003; % ASSUMED deterministic bounded timing jitter

% Accepted geometry families, exercised at the requested commanded speeds.
x = linspace(0,60,301)';
paths.X = [x zeros(size(x)) zeros(size(x))];
paths.XZ = [x zeros(size(x)) 8*(0.5-0.5*cos(pi*x/max(x)))];
a = linspace(0,2*pi,401)';
paths.R10 = [10*sin(a) 10*(1-cos(a)) 3*a/(2*pi)];
ops = struct('name',{},'U',{});
for U=[1 1.5 2], ops(end+1)=struct('name','X','U',U); end %#ok<AGROW>
for U=[1 1.5 2], ops(end+1)=struct('name','XZ','U',U); end %#ok<AGROW>
for U=[1.5 2], ops(end+1)=struct('name','R10','U',U); end %#ok<AGROW>

% Exactly 48 declared cases: 8 ideal, 24 nominal delay grid, 16 endpoint corners.
cases = struct('id',{},'path',{},'U',{},'ideal',{},'tau_s',{}, ...
    'deadband_deg',{},'delay_s',{},'jitter_s',{});
for i=1:numel(ops)
    cases(end+1)=make_case(ops(i),'IDEAL',true,0,0,0,0); %#ok<AGROW>
    for d=[0 0.015 0.030]
        cases(end+1)=make_case(ops(i),sprintf('NOM_D%02d',round(1000*d)), ...
            false,0.10,0.25,d,jitter_s); %#ok<AGROW>
    end
    cases(end+1)=make_case(ops(i),'FAST_OPEN_D30',false,0.05,0,0.030,jitter_s); %#ok<AGROW>
    cases(end+1)=make_case(ops(i),'SLOW_WIDE_D30',false,0.20,0.50,0.030,jitter_s); %#ok<AGROW>
end

raw = cell(numel(cases),1);
metrics = repmat(empty_metrics(),numel(cases),1);
fprintf('CLOSED_LOOP_ACTUATOR_REALISM: %d declared cases\n',numel(cases));
for i=1:numel(cases)
    c=cases(i); p=paths.(c.path);
    state=zeros(12,1); state(1:3)=p(1,:)'; state(7)=c.U;
    T=30; if strcmp(c.path,'XZ'), T=35; elseif strcmp(c.path,'R10'), T=45; end
    cfg=rmfield(c,{'id','path','U'});
    raw{i}=closed_loop_actuator_realism_case(p,state,dt,T,c.U,cfg);
    metrics(i)=score_case(raw{i},c,dt);
    fprintf('%02d/%02d %-25s complete=%d hard=%d CTE=%.3f\n', ...
        i,numel(cases),c.id,metrics(i).complete,metrics(i).hard_pass,metrics(i).path_rmse_m);
end

is_act = ~[cases.ideal]';
complete_all = all([metrics.complete]);
stable_all = all([metrics.stable]);
enforce_all = all([metrics(is_act).exact_enforcement]);
hard_all = all([metrics.hard_pass]);
if complete_all && stable_all && enforce_all && hard_all
    verdict='PASS';
elseif complete_all && stable_all && enforce_all
    verdict='PARTIAL';
else
    verdict='FAIL';
end
failed = {cases(~[metrics.hard_pass]).id};
Results.task_id='CLOSED_LOOP_ACTUATOR_REALISM_001';
Results.generated=datestr(now,31);
Results.verdict=verdict;
Results.physical_readiness='NOT_CERTIFIED';
Results.assumptions=struct('fin_magnitude_deg',[15 25],'rate_deg_s',40, ...
    'tau_s',[0.05 0.10 0.20],'deadband_deg',[0 0.10 0.25 0.50], ...
    'delay_ms',[0 15 30],'jitter_bound_ms',3);
Results.hard_thresholds=struct('path_rmse_m_X_XZ_R10',[5 6 8], ...
    'depth_max_m',6,'yaw_max_deg',60,'speed_rmse_mps',0.75, ...
    'saturation_dwell_pct',25,'attitude_abs_deg',85);
Results.cases=cases; Results.metrics=metrics; Results.raw=raw;
Results.failed_cases=failed;
save(fullfile(outdir,'CLOSED_LOOP_ACTUATOR_REALISM.mat'),'Results','-v7');
write_figure(Results,fullfile(outdir,'CLOSED_LOOP_ACTUATOR_REALISM.png'));
write_report(Results,fullfile(outdir,'CLOSED_LOOP_ACTUATOR_REALISM.md'));
append_logs(Results);
fprintf('CLOSED_LOOP_ACTUATOR_REALISM verdict: %s (%d hard failures)\n',verdict,numel(failed));
end

function c=make_case(op,label,ideal,tau,db,delay,jitter)
c.id=sprintf('%s_U%.1f_%s',op.name,op.U,label);
c.path=op.name; c.U=op.U; c.ideal=ideal; c.tau_s=tau;
c.deadband_deg=db; c.delay_s=delay; c.jitter_s=jitter;
end

function m=empty_metrics()
m=struct('complete',false,'stable',false,'path_rmse_m',Inf,'path_max_m',Inf, ...
 'depth_max_m',Inf,'yaw_rmse_deg',Inf,'yaw_max_deg',Inf, ...
 'pitch_rmse_deg',Inf,'speed_rmse_mps',Inf,'actuator_rmse_deg',[Inf Inf], ...
 'delay_ms',[Inf Inf],'mag_dwell_pct',[Inf Inf],'rate_dwell_pct',[Inf Inf], ...
 'chatter_deg_s',[Inf Inf],'psd_13p33',[Inf Inf],'allocation_residual',Inf, ...
 'mag_violation_deg',Inf,'rate_violation_deg_s',Inf,'exact_enforcement',false, ...
 'hard_pass',false,'failure','incomplete');
end

function m=score_case(s,c,dt)
m=empty_metrics(); m.complete=s.complete;
if ~s.complete, m.failure=s.error; return; end
n=size(s.position,1); keep=max(1,round(5/dt)):n;
d2=inf(n,1); iz=zeros(n,1);
for k=1:n
    q=sum((s.path-s.position(k,:)).^2,2);
    [d2(k),iz(k)]=min(q);
end
cte=sqrt(d2);
zerr=s.position(:,3)-s.path(iz,3);
yawerr=wrap_pi(s.attitude(:,3)-s.reference(:,2));
pitcherr=wrap_pi(s.attitude(:,2)-s.reference(:,1));
speed=sqrt(sum(s.velocity.^2,2));
m.path_rmse_m=rms0(cte(keep)); m.path_max_m=max(cte(keep));
m.depth_max_m=max(abs(zerr(keep)));
m.yaw_rmse_deg=rad2deg(rms0(yawerr(keep)));
m.yaw_max_deg=rad2deg(max(abs(yawerr(keep))));
m.pitch_rmse_deg=rad2deg(rms0(pitcherr(keep)));
m.speed_rmse_mps=rms0(speed(keep)-c.U);
err=s.command(:,1:2)-s.applied(:,1:2);
m.actuator_rmse_deg=rad2deg(sqrt(mean(err(keep,:).^2,1)));
for j=1:2
    m.delay_ms(j)=1000*estimate_delay(s.command(keep,j),s.applied(keep,j),dt);
    mag=deg2rad([15 25]); rate=abs(diff(s.applied(:,j)))/dt;
    m.mag_dwell_pct(j)=100*mean(abs(s.applied(keep,j))>=mag(j)-1e-10);
    m.rate_dwell_pct(j)=100*mean(rate(max(1,keep(1)-1):end)>=deg2rad(40)-1e-8);
    m.chatter_deg_s(j)=rad2deg(rms0(diff(s.applied(keep,j))/dt));
    m.psd_13p33(j)=point_psd(s.applied(keep,j),dt,13.33);
end
m.allocation_residual=max(vecnorm(s.allocated-s.command,2,2));
m.mag_violation_deg=rad2deg(max(max(abs(s.applied(:,1:2))-deg2rad([15 25]))));
m.rate_violation_deg_s=rad2deg(max(max(abs(diff(s.applied(:,1:2),1,1))/dt-deg2rad(40))));
if c.ideal
    m.exact_enforcement=true;
else
    m.exact_enforcement=m.mag_violation_deg<=1e-8 && m.rate_violation_deg_s<=1e-8;
end
m.stable=all(isfinite(s.position(:))) && max(abs(rad2deg(s.attitude(:))))<85 && ...
    max(vecnorm(s.velocity,2,2))<5;
pth=5; if strcmp(c.path,'XZ'), pth=6; elseif strcmp(c.path,'R10'), pth=8; end
sat_ok=c.ideal || all(m.mag_dwell_pct<=25);
m.hard_pass=m.complete && m.stable && m.exact_enforcement && ...
    m.path_rmse_m<=pth && m.depth_max_m<=6 && m.yaw_max_deg<=60 && ...
    m.speed_rmse_mps<=0.75 && sat_ok && m.allocation_residual<=1e-12;
why={};
if ~m.stable, why{end+1}='stability'; end %#ok<AGROW>
if ~m.exact_enforcement, why{end+1}='mag/rate enforcement'; end %#ok<AGROW>
if m.path_rmse_m>pth, why{end+1}='path'; end %#ok<AGROW>
if m.depth_max_m>6, why{end+1}='depth'; end %#ok<AGROW>
if m.yaw_max_deg>60, why{end+1}='yaw'; end %#ok<AGROW>
if m.speed_rmse_mps>0.75, why{end+1}='speed'; end %#ok<AGROW>
if ~sat_ok, why{end+1}='saturation dwell'; end %#ok<AGROW>
if isempty(why), m.failure=''; else, m.failure=strjoin(why,', '); end
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
m=R.metrics; c=R.cases; act=find(~[c.ideal]);
f=figure('Visible','off','Color','w','Position',[100 100 1200 760]);
subplot(2,2,1); bar([m(act).path_rmse_m]); ylabel('Path RMSE [m]'); grid on
title(sprintf('Closed-loop actuator realism: %s',R.verdict));
subplot(2,2,2); A=vertcat(m(act).actuator_rmse_deg); plot(A,'LineWidth',1);
ylabel('Actuator RMSE [deg]'); legend('elevator','rudder'); grid on
subplot(2,2,3); D=vertcat(m(act).delay_ms); plot(D,'LineWidth',1);
ylabel('Estimated delay [ms]'); xlabel('Actuator case'); grid on
subplot(2,2,4); C=vertcat(m(act).chatter_deg_s); plot(C,'LineWidth',1);
ylabel('Chatter RMS [deg/s]'); xlabel('Actuator case'); grid on
print(f,file,'-dpng','-r140'); close(f);
end

function write_report(R,file)
fid=fopen(file,'w'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# CLOSED_LOOP_ACTUATOR_REALISM\n\n');
fprintf(fid,'**TASK_ID:** %s  \n**Verdict:** **%s**  \n',R.task_id,R.verdict);
fprintf(fid,'**Gate:** Gate 3 isolated; Gate 2 method CLOSED; production frozen.  \n');
fprintf(fid,'**Physical readiness:** **NOT_CERTIFIED**; all physical actuator values **ASSUMED**.  \n');
fprintf(fid,'**Production/controller/guidance/plant edits:** NO · **CODEX_VERTICAL_PLAN:** untouched\n\n');
fprintf(fid,'## Declared method\n\n');
fprintf(fid,'Exactly 48 no-cherry-pick cases: 8 identical ideal baselines; 24 nominal tau=0.10 s, deadband=0.25 deg over delay={0,15,30} ms; 16 endpoint corners (tau/db=0.05/0 and 0.20/0.50) at 30 ms. X/XZ U={1,1.5,2}; R10 U={1.5,2}. Deterministic jitter is 3 ms peak.\n\n');
fprintf(fid,'Logical `[delta_e,delta_r,thrust]` passes through explicit `eye(3)` allocation. Applied fins then use transport delay, play-free deadband, first-order lag, exact ±40 deg/s rate limit, and ±15/±25 deg magnitude limits. Command, applied, and non-control shadow-feedback are separate logs.\n\n');
fprintf(fid,'Hard thresholds (ASSUMED): path RMS X/XZ/R10 <=5/6/8 m; max depth error <=6 m; max yaw error <=60 deg; speed RMS <=0.75 m/s; actuator magnitude dwell <=25%%; attitude <85 deg; exact numerical magnitude/rate enforcement; zero allocation residual.\n\n');
fprintf(fid,'## Results\n\n');
fprintf(fid,'| Case | Complete/stable | Path RMS/max m | Depth max m | Yaw RMS/max deg | Pitch RMS deg | Speed RMS m/s | Act RMSE e/r deg | Delay e/r ms | Mag dwell e/r %% | Rate dwell e/r %% | Chatter e/r deg/s | PSD13.33 e/r | Alloc residual | Gate / reason |\n');
fprintf(fid,'|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n');
for i=1:numel(R.cases)
 c=R.cases(i); m=R.metrics(i);
 fprintf(fid,'| %s | %d/%d | %.3f/%.3f | %.3f | %.2f/%.2f | %.2f | %.3f | %.3f/%.3f | %.1f/%.1f | %.2f/%.2f | %.2f/%.2f | %.2f/%.2f | %.3g/%.3g | %.3g | %s / %s |\n', ...
 c.id,m.complete,m.stable,m.path_rmse_m,m.path_max_m,m.depth_max_m,m.yaw_rmse_deg,m.yaw_max_deg,m.pitch_rmse_deg,m.speed_rmse_mps, ...
 m.actuator_rmse_deg,m.delay_ms,m.mag_dwell_pct,m.rate_dwell_pct,m.chatter_deg_s,m.psd_13p33,m.allocation_residual,password(m.hard_pass),m.failure);
end
fprintf(fid,'\n## Gate accounting\n\n');
if isempty(R.failed_cases)
 fprintf(fid,'All declared cases completed, remained stable, enforced exact limits, and passed every hard gate.\n');
else
 fprintf(fid,'Exact hard-failing cases (%d): `%s`.\n',numel(R.failed_cases),strjoin(R.failed_cases,'`, `'));
end
fprintf(fid,'\nThis is SIL evidence only: no promotion, hardware certification, or production change.\n\n');
fprintf(fid,'## Artifacts\n\n- `closed_loop_actuator_realism_case.m`\n- `run_closed_loop_actuator_realism.m`\n- `suite_results/CLOSED_LOOP_ACTUATOR_REALISM.{md,mat,png}`\n\n');
fprintf(fid,'## Next\n\nBench-identify fin lag/deadband/delay before any promotion; retain the isolated Gate 3 harness for regression.\n');
end

function s=password(x), if x, s='PASS'; else, s='FAIL'; end, end

function append_logs(R)
files={'suite_results/AUV_REALIZATION_READINESS_PLAN.md', ...
 'suite_results/AUV_REALISM_AND_VISUAL_VALIDATION.md', ...
 'suite_results/PITCH_CONTROL_RESEARCH_LOG.md'};
entry=sprintf('\n\n## %s — %s\n\nResult: **%s** (%d/48 hard failures); isolated Gate 3 SIL, production frozen, physical values ASSUMED, NOT_CERTIFIED.  \nNext: bench-identify actuator lag/deadband/delay before promotion; retain isolated regression matrix.\n', ...
 R.task_id,R.generated,R.verdict,numel(R.failed_cases));
for i=1:numel(files)
 fid=fopen(files{i},'a');
 if fid<0, warning('Could not append %s',files{i}); else, fprintf(fid,'%s',entry); fclose(fid); end
end
end
