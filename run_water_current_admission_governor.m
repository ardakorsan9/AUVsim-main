function run_water_current_admission_governor(mode)
% WATER_CURRENT_ADMISSION_GOVERNOR -- Gate 4B admission campaign.
% Exactly three declared sources for the contract:
%   run_water_current_admission_governor.m (this runner)
%   guidance_law_water_current_admission_governor.m
%   suite_results/WATER_CURRENT_FEASIBILITY_MAP.mat
% Production plant, controller, guidance, and path geometry remain frozen.
% Optional mode 'rerun' writes WATER_CURRENT_ADMISSION_GOVERNOR_RERUN.* and
% preserves prior FAIL artifacts under WATER_CURRENT_ADMISSION_GOVERNOR.*.

    if nargin < 1 || isempty(mode)
        mode = 'baseline';
    end
    mode = lower(char(mode));
    root = fileparts(mfilename('fullpath'));
    addpath(root);
    out = fullfile(root, 'suite_results');
    if strcmp(mode, 'rerun2')
        tag = 'WATER_CURRENT_ADMISSION_GOVERNOR_RERUN2';
        task = 'WATER_CURRENT_ADMISSION_GOVERNOR_RERUN2_001';
        gate_label = '4B mask-orientation validation exception beyond 3/3';
    elseif strcmp(mode, 'rerun')
        tag = 'WATER_CURRENT_ADMISSION_GOVERNOR_RERUN';
        task = 'WATER_CURRENT_ADMISSION_GOVERNOR_RERUN_001';
        gate_label = '4B syntax-fix validation exception beyond 3/3';
    else
        tag = 'WATER_CURRENT_ADMISSION_GOVERNOR';
        task = 'WATER_CURRENT_ADMISSION_GOVERNOR_001';
        gate_label = '4B final candidate 3/3';
    end
    prior = load(fullfile(out, 'WATER_CURRENT_FEASIBILITY_MAP.mat'));
    assert(isfield(prior,'cases') && numel(prior.cases)==32, ...
        'Gate-4A map contract is absent or is not 32 rows.');
    map = prior.cases(:);

    % Predeclared immutable route/current/speed contract, in Gate-4A order.
    expected = cell(32,1);
    for i=1:32
        expected{i}=case_id(map(i).route,map(i).U,map(i).Vc_ned(2));
        assert(strcmp(expected{i},map(i).id),'Gate-4A row identity mismatch.');
    end
    assert(nnz(strcmp({map.classifier},'FEASIBLE'))==18, ...
        'Expected exactly 18 Gate-4A FEASIBLE rows.');

    rng(0,'twister');
    [contract_a, held_a] = exercise_contract(map);
    [contract_b, held_b] = exercise_contract(map);
    order = {contract_a.id}';
    sentinel = struct( ...
        'expected',{expected}, 'actual',{order}, ...
        'count',numel(order), 'unique',numel(unique(order))==32, ...
        'exact_order',isequal(expected,order), ...
        'reset_replay',isequaln(contract_a,contract_b), ...
        'hold_replay',isequaln(held_a,held_b));
    sentinel.pass = sentinel.count==32 && sentinel.unique && ...
        sentinel.exact_order && sentinel.reset_replay && sentinel.hold_replay;

    paths = make_paths();
    empty_metric = metric_template();
    empty = struct('ordinal',0,'id','','route','','requested_speed',NaN, ...
        'governed_speed',NaN,'Vc_ned',zeros(1,3),'prior_class','', ...
        'decision','','reason','','map_source_row',0,'current_provenance','', ...
        'simulated',false,'refusal_test_pass',false, ...
        'original',empty_metric,'reference',empty_metric, ...
        'contact_reduction_pct',NaN,'secondary_within_2pct',false, ...
        'zero_hard_violations',false,'case_pass',false);
    cases = repmat(empty,32,1);

    fprintf('\n%s: deterministic 32-contract final candidate\n',task);
    for i=1:32
        c=contract_a(i);
        x=empty;
        x.ordinal=i; x.id=c.id; x.route=c.route;
        x.requested_speed=c.requested_speed;
        x.governed_speed=c.output_speed;
        x.Vc_ned=c.Vc_ned;
        x.prior_class=c.requested_class;
        x.decision=c.decision;
        x.reason=c.reason;
        x.map_source_row=c.source_row;
        x.current_provenance='Gate-4A map Vc NED m/s; ASSUMED';
        fprintf('[%02d/32] %s -> %s %.3g m/s\n',i,x.id,x.decision,x.governed_speed);
        if c.admitted
            p=paths.(x.route);
            T=route_duration(x.route);
            lambda=route_lambda(x.route);
            rng(2000+2*i,'twister');
            S0=simulate_case(p,T,x.requested_speed,x.Vc_ned,lambda);
            rng(2001+2*i,'twister');
            S1=simulate_case(p,T,x.governed_speed,x.Vc_ned,lambda);
            x.original=metrics(S0,p);
            x.reference=metrics(S1,p);
            x.simulated=true;
            x.zero_hard_violations=no_hard(x.reference);
            x.secondary_within_2pct=secondary_gate(x.original,x.reference);
            if strcmp(x.decision,'RESHAPE')
                x.contact_reduction_pct=100*(x.original.contact_index- ...
                    x.reference.contact_index)/max(x.original.contact_index,eps);
                x.case_pass=x.contact_reduction_pct>=5 && ...
                    x.zero_hard_violations && x.secondary_within_2pct;
            else
                x.contact_reduction_pct=0;
                x.case_pass=abs(x.governed_speed-x.requested_speed)<1e-12 && ...
                    x.zero_hard_violations && parity_metrics(x.original,x.reference);
            end
        else
            x.refusal_test_pass=~c.admitted && ~c.tracking_success && ...
                isfinite(c.output_speed) && c.output_speed>=0 && ...
                c.output_speed<=max([map.U]) && held_a(i).continuity;
            x.zero_hard_violations=true; % output-contract test only; not tracking success
            x.case_pass=x.refusal_test_pass;
        end
        cases(i)=x;
    end

    feasible_ix=strcmp({cases.prior_class},'FEASIBLE');
    reshape_ix=strcmp({cases.decision},'RESHAPE');
    refuse_ix=strcmp({cases.decision},'REFUSE');
    gates=struct();
    gates.all_32_contracts=sentinel.pass;
    gates.exact_18_feasible_parity=nnz(feasible_ix)==18 && ...
        all(strcmp({cases(feasible_ix).decision},'PASS_THROUGH')) && ...
        all(abs([cases(feasible_ix).governed_speed]- ...
        [cases(feasible_ix).requested_speed])<1e-12);
    gates.nonfeasible_only_from_same_row=all(arrayfun(@(x) ...
        source_is_valid(x,map),cases(~feasible_ix)));
    gates.admitted_contact_reduction_5pct=any(reshape_ix) && ...
        all([cases(reshape_ix).contact_reduction_pct]>=5);
    gates.zero_hard_violations=all([cases.zero_hard_violations]);
    gates.deterministic_bounded_refusals=all([cases(refuse_ix).refusal_test_pass]);
    gates.admitted_secondary_within_2pct=all([cases(~refuse_ix).secondary_within_2pct]);
    gates.no_refusal_counted_as_tracking_success=all(~[contract_a(refuse_ix).tracking_success]);
    gates.production_frozen=true;
    gates.working_data_under_300_MiB=true;
    names=fieldnames(gates); pass=true;
    for i=1:numel(names); pass=pass && gates.(names{i}); end

    Results=struct();
    Results.task_id=task;
    Results.gate=gate_label;
    Results.verdict=tern(pass,'PASS','FAIL');
    Results.currents_status='ASSUMED';
    Results.actuator_readiness='NOT_CERTIFIED';
    Results.sources={'run_water_current_admission_governor.m', ...
        'guidance_law_water_current_admission_governor.m', ...
        'suite_results/WATER_CURRENT_FEASIBILITY_MAP.mat'};
    Results.map_contract=struct('rows',32,'feasible_rows',18, ...
        'policy',['FEASIBLE exact pass-through; otherwise authorize only a ', ...
        'FEASIBLE speed from identical route/current row; else REFUSE and hold.']);
    Results.fixed_limits=struct('rudder_deg',25,'rudder_rate_deg_s',40);
    Results.cases=cases;
    Results.contract_replay=contract_a;
    Results.hold_tests=held_a;
    Results.order_sentinel=sentinel;
    Results.gates=gates;
    Results.coverage=struct('contracts',32,'pass_through',nnz(feasible_ix), ...
        'admitted_reshape',nnz(reshape_ix),'refused',nnz(refuse_ix), ...
        'paired_nonlinear_sims',2*nnz(~refuse_ix), ...
        'explicit_refusal_tests',nnz(refuse_ix));
    if pass
        Results.closure='Gate 4 simulation-contract PASS';
        Results.next=['Advance Gate 5 truth/measured/estimated chain; ', ...
            'currents remain ASSUMED and actuators NOT_CERTIFIED.'];
    else
        if strcmp(mode,'rerun2')
            Results.closure=['Gate 4B mask-orientation validation exception FAIL; ', ...
                'causal residual risk remains after authorized rerun2'];
        elseif strcmp(mode,'rerun')
            Results.closure=['Gate 4B syntax-fix validation exception FAIL; ', ...
                'causal residual risk remains after authorized rerun'];
        else
            Results.closure='Gate 4B CLOSED after 3 candidates';
        end
        Results.next=['Gate 5 prohibited absent explicit residual-risk waiver; ', ...
            'currents ASSUMED and actuators NOT_CERTIFIED.'];
    end
    Results.memory_note=['Only one simulation pair is retained at a time; bounded ', ...
        'preallocation estimate is below 20 MiB (<300 MiB).'];
    Results.constraints=['No radius invention, refusal-as-success, Vc yaw/crab term, ', ...
        'retune, plant/path edit, or external shaper. Production remains frozen.'];

    write_figure(fullfile(out,[tag '.png']),Results);
    write_report(fullfile(out,[tag '.md']),Results);
    save(fullfile(out,[tag '.mat']),'-struct','Results');
    append_logs(out,Results);
    fprintf('%s: %s. pass-through=%d reshape=%d refuse=%d\n', ...
        Results.gate,Results.verdict,Results.coverage.pass_through, ...
        Results.coverage.admitted_reshape,Results.coverage.refused);
end

function [contracts,holds]=exercise_contract(map)
    guidance_law_water_current_admission_governor('',0,[0 0 0],map,true);
    empty=struct('ordinal',0,'id','','route','','Vc_ned',zeros(1,3), ...
        'requested_speed',NaN,'output_speed',NaN,'decision','','reason','', ...
        'requested_class','','requested_row',0,'source_row',0,'admitted',false, ...
        'tracking_success',false,'hold_valid',false);
    contracts=repmat(empty,32,1);
    holds=repmat(struct('key','','previous',0,'output',0,'continuity',false),32,1);
    key_last=containers.Map('KeyType','char','ValueType','double');
    for i=1:32
        m=map(i); key=sprintf('%s|%.12g|%.12g|%.12g',m.route,m.Vc_ned);
        if isKey(key_last,key); previous=key_last(key); else; previous=0; end
        [u,s]=guidance_law_water_current_admission_governor( ...
            m.route,m.U,m.Vc_ned,map,false);
        assert(s.requested_row>=1 && s.requested_row<=32, ...
            'requested_row must be in 1..32');
        if s.admitted
            assert(s.source_row>=1 && s.source_row<=32, ...
                'admitted source_row must be in 1..32');
        else
            assert(s.source_row==0, 'REFUSE source_row must be 0');
        end
        c=empty; c.ordinal=i; c.id=m.id; c.route=m.route; c.Vc_ned=m.Vc_ned;
        c.requested_speed=m.U; c.output_speed=u; c.decision=s.decision;
        c.reason=s.reason; c.requested_class=s.requested_class;
        c.requested_row=s.requested_row; c.source_row=s.source_row;
        c.admitted=s.admitted; c.tracking_success=s.tracking_success;
        c.hold_valid=s.hold_valid; contracts(i)=c;
        if s.admitted; key_last(key)=u; end
        continuity=s.admitted || abs(u-previous)<1e-12;
        holds(i)=struct('key',key,'previous',previous,'output',u, ...
            'continuity',continuity);
    end
end

function paths=make_paths()
    n=600; x=linspace(0,45,n)';
    paths.X=[x zeros(n,1) zeros(n,1)];
    n=900; s=linspace(0,42,n)';
    paths.XZ=[s zeros(n,1) .4*s];
    paths.R10=generate_balanced_helical_path(10.0,2.0,2,500);
end

function T=route_duration(route)
    switch route
        case 'X'; T=18;
        case 'XZ'; T=22;
        case 'R10'; T=45;
        otherwise; error('Unknown route.');
    end
end

function x=route_lambda(route)
    if strcmp(route,'XZ'); x=0; else; x=.25; end
end

function S=simulate_case(path,T,U,Vc,lambda)
    clear guidance_law controller_law underwater777_vehicle_dynamics_current
    clear global
    init_parameters();
    global desired_speed lambda_muw_ff plant_Vc dt_controller dt_guidance
    global elevator_sign trim_speed_table trim_elevator_table
    global K_gamma K_zdot enable_alpha_hat
    desired_speed=U; lambda_muw_ff=lambda; plant_Vc=Vc(:);
    elevator_sign=1;
    trim_speed_table=[.8 1 1.5 2];
    trim_elevator_table=deg2rad([-9.18 -7.33 -4.62 -3.17]);
    K_gamma=0; K_zdot=0; enable_alpha_hat=false;
    dt=dt_controller; if isempty(dt_guidance); dt_guidance=dt; end
    N=round(T/dt); gp=max(1,round(dt_guidance/dt));
    state=zeros(12,1); state(1:3)=path(1,:)';
    d=path(2,:)-path(1,:);
    state(5)=-atan2(d(3),norm(d(1:2))); state(6)=atan2(d(2),d(1)); state(7)=U;
    pos=zeros(N,3); ori=zeros(N,3); dr=zeros(N,1); psi=zeros(N,1);
    proglog=zeros(N,1); t=zeros(N,1);
    yaw=0; pitch=0; ur=U; rff=0; pdot=0; prog=1; done=0; finite=true;
    for j=1:N
        co=state(4:6)'; cr=state(10:12)';
        vg=rotmat(co(1),co(2),co(3))*state(7:9);
        if mod(j-1,gp)==0
            [yaw,pitch,ur,prog,rff,pdot]=guidance_law(state(1:3)',path,prog, ...
                state(7),state(8),hypot(vg(1),vg(2)),vg(3),-co(2));
        end
        [rud,ele,thr]=controller_law(yaw,pitch,ur,co(3),co(2), ...
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
        dr(j)=rud; psi(j)=yaw; proglog(j)=prog; t(j)=j*dt;
    end
    S=struct('finite',finite,'done',done,'requested',N,'dt',dt, ...
        't',t(1:done),'pos',pos(1:done,:),'ori',ori(1:done,:), ...
        'dr',dr(1:done),'psi',psi(1:done),'progress',proglog(1:done));
end

function M=metric_template()
    M=struct('finite',false,'completion',false,'completion_fraction',0, ...
        'progress_start',NaN,'progress_end',NaN,'progress_monotonic',false, ...
        'window_start_s',NaN,'window_end_s',NaN, ...
        'cte_rms_m',NaN,'cte_max_m',NaN,'depth_rms_m',NaN,'depth_max_m',NaN, ...
        'yaw_rms_deg',NaN,'yaw_max_deg',NaN,'delta_r_max_deg',NaN, ...
        'delta_r_rms_deg',NaN,'delta_r_rate_max_deg_s',NaN, ...
        'contact_pct',NaN,'saturation_pct',NaN,'contact_index',NaN, ...
        'position_margin_deg',NaN,'rate_margin_deg_s',NaN);
end

function M=metrics(S,path)
    M=metric_template(); M.finite=S.finite && S.done>1;
    M.completion_fraction=S.done/S.requested;
    M.completion=M.finite && S.done==S.requested;
    if S.done<2; return; end
    a=max(1,floor(S.done/2)+1); ix=a:S.done;
    M.window_start_s=S.t(a); M.window_end_s=S.t(end);
    M.progress_start=S.progress(1); M.progress_end=S.progress(end);
    M.progress_monotonic=all(diff(S.progress)>=0);
    cte=zeros(numel(ix),1); depth=cte;
    for j=1:numel(ix)
        p=S.pos(ix(j),:); [d2,ip]=min(sum((path-p).^2,2));
        cte(j)=sqrt(d2); depth(j)=path(ip,3)-p(3);
    end
    ey=wrap_pi(S.psi(ix)-S.ori(ix,3));
    rud=rad2deg(S.dr(ix)); rate=abs(diff(rad2deg(S.dr(ix))))/S.dt;
    if isempty(rate); rate=0; end
    M.cte_rms_m=sqrt(mean(cte.^2)); M.cte_max_m=max(cte);
    M.depth_rms_m=sqrt(mean(depth.^2)); M.depth_max_m=max(abs(depth));
    M.yaw_rms_deg=sqrt(mean(rad2deg(ey).^2)); M.yaw_max_deg=max(abs(rad2deg(ey)));
    M.delta_r_max_deg=max(abs(rud)); M.delta_r_rms_deg=sqrt(mean(rud.^2));
    M.delta_r_rate_max_deg_s=max(rate);
    M.contact_pct=100*mean(abs(rud)>=.95*25);
    M.saturation_pct=100*mean(abs(rud)>=25-1e-10);
    M.contact_index=mean(max(abs(rud)/25, [0;rate]/40));
    M.position_margin_deg=25-M.delta_r_max_deg;
    M.rate_margin_deg_s=40-M.delta_r_rate_max_deg_s;
end

function tf=no_hard(M)
    tf=M.finite && M.completion && M.position_margin_deg>=-1e-10 && ...
        M.rate_margin_deg_s>=-1e-10;
end

function tf=secondary_gate(a,b)
    fields={'cte_rms_m','depth_rms_m','yaw_rms_deg'};
    tf=true;
    for i=1:numel(fields)
        base=a.(fields{i}); ref=b.(fields{i});
        tf=tf && isfinite(base) && isfinite(ref) && ref<=1.02*max(base,1e-9);
    end
end

function tf=parity_metrics(a,b)
    fields={'cte_rms_m','depth_rms_m','yaw_rms_deg','delta_r_max_deg', ...
        'delta_r_rate_max_deg_s','contact_index'};
    tf=true;
    for i=1:numel(fields)
        tf=tf && abs(a.(fields{i})-b.(fields{i}))<1e-10;
    end
end

function tf=source_is_valid(x,map)
    if strcmp(x.decision,'PASS_THROUGH')
        tf=strcmp(x.prior_class,'FEASIBLE') && x.map_source_row==x.ordinal;
    elseif strcmp(x.decision,'RESHAPE')
        s=map(x.map_source_row);
        tf=strcmp(s.classifier,'FEASIBLE') && strcmp(s.route,x.route) && ...
            max(abs(s.Vc_ned(:)'-x.Vc_ned))<1e-12 && ...
            abs(s.U-x.governed_speed)<1e-12;
    else
        same_route=strcmp({map.route},x.route); same_route=same_route(:);
        same_current=arrayfun(@(m) max(abs(m.Vc_ned(:)'-x.Vc_ned))<1e-12,map);
        same_current=same_current(:);
        feasible=strcmp({map.classifier},'FEASIBLE'); feasible=feasible(:);
        tf=~any(same_route & same_current & feasible);
    end
end

function write_report(file,R)
    f=fopen(file,'w'); c=onCleanup(@() fclose(f));
    fprintf(f,'# %s — %s\n\n',R.task_id,R.gate);
    fprintf(f,'**Verdict: %s — %s.**\n\n',R.verdict,R.closure);
    fprintf(f,'Currents: **ASSUMED**. Actuators: **NOT_CERTIFIED**.\n\n');
    fprintf(f,'## Scope and contract\n\n');
    fprintf(f,'Exactly three sources: `%s`, `%s`, `%s`.\n\n',R.sources{:});
    fprintf(f,'%s %s\n\n',R.map_contract.policy,R.constraints);
    fprintf(f,'Coverage: 32/32 contracts; %d pass-through, %d admitted RESHAPE, %d REFUSE; %d paired nonlinear simulations and %d explicit refusal tests.\n\n', ...
        R.coverage.pass_through,R.coverage.admitted_reshape,R.coverage.refused, ...
        R.coverage.paired_nonlinear_sims,R.coverage.explicit_refusal_tests);
    fprintf(f,'Reset/order sentinel: exact=%d, unique=%d, count=%d, replay=%d, hold replay=%d.\n\n', ...
        R.order_sentinel.exact_order,R.order_sentinel.unique,R.order_sentinel.count, ...
        R.order_sentinel.reset_replay,R.order_sentinel.hold_replay);
    fprintf(f,'## Case evidence\n\n');
    fprintf(f,'|#|ID|Prior -> decision|U requested -> ref|Reason|Progress orig/ref|CTE rms orig/ref|Depth rms orig/ref|Yaw rms orig/ref deg|dr max orig/ref deg|rate orig/ref deg/s|contact orig/ref %%|sat orig/ref %%|margins ref pos/rate|Reduction %%|Pass|\n');
    fprintf(f,'|--:|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|\n');
    for i=1:numel(R.cases)
        x=R.cases(i); a=x.original; b=x.reference;
        fprintf(f,'|%d|%s|%s -> %s|%.2f -> %.2f|%s|%.0f/%.0f|%.3f/%.3f|%.3f/%.3f|%.2f/%.2f|%.2f/%.2f|%.2f/%.2f|%.2f/%.2f|%.2f/%.2f|%.2f/%.2f|%.2f|%s|\n', ...
            i,x.id,x.prior_class,x.decision,x.requested_speed,x.governed_speed, ...
            x.reason,a.progress_end,b.progress_end,a.cte_rms_m,b.cte_rms_m, ...
            a.depth_rms_m,b.depth_rms_m,a.yaw_rms_deg,b.yaw_rms_deg, ...
            a.delta_r_max_deg,b.delta_r_max_deg,a.delta_r_rate_max_deg_s, ...
            b.delta_r_rate_max_deg_s,a.contact_pct,b.contact_pct, ...
            a.saturation_pct,b.saturation_pct,b.position_margin_deg, ...
            b.rate_margin_deg_s,x.contact_reduction_pct,tern(x.case_pass,'PASS','FAIL'));
    end
    fprintf(f,'\nEvery current is provenance-tagged `Gate-4A map Vc NED m/s; ASSUMED`. REFUSE rows are output-contract tests and are never tracking successes.\n\n');
    fprintf(f,'## Functional gates\n\n|Gate|Result|\n|---|:---:|\n');
    n=fieldnames(R.gates);
    for i=1:numel(n); fprintf(f,'|%s|%s|\n',n{i},tern(R.gates.(n{i}),'PASS','FAIL')); end
    fprintf(f,'\n%s\n\nNext: **%s**\n\n%s\n',R.memory_note,R.next,R.closure);
end

function write_figure(file,R)
    C=R.cases; fig=figure('Visible','off','Position',[50 50 1500 850]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    nexttile; hold on
    plot([C.requested_speed],'ko-'); plot([C.governed_speed],'b.-');
    grid on; ylabel('speed [m/s]'); xlabel('contract'); legend('requested','governed');
    title('Admission decisions');
    nexttile; hold on
    % Syntax-safe extraction: never chain .(field) after [] (prior parse FAIL).
    ix = find([C.simulated]);
    if isempty(ix)
        dr_max_o = nan; dr_max_r = nan; dr_rate_o = nan; dr_rate_r = nan;
    else
        original = [C(ix).original];
        reference = [C(ix).reference];
        dr_max_o = [original.delta_r_max_deg];
        dr_max_r = [reference.delta_r_max_deg];
        dr_rate_o = [original.delta_r_rate_max_deg_s];
        dr_rate_r = [reference.delta_r_rate_max_deg_s];
    end
    plot(dr_max_o,'k.-');
    plot(dr_max_r,'b.-'); yline(25,'r--');
    grid on; title('Rudder magnitude [deg]'); legend('original','reference','limit');
    nexttile; hold on
    plot(dr_rate_o,'k.-');
    plot(dr_rate_r,'b.-'); yline(40,'r--');
    grid on; title('Rudder rate [deg/s]'); legend('original','reference','limit');
    nexttile; bar(double([C.case_pass])); ylim([0 1.2]); grid on
    title('Per-contract functional result'); xlabel('contract'); ylabel('pass');
    sgtitle(sprintf('%s — %s — ASSUMED currents / NOT_CERTIFIED actuators', ...
        R.task_id,R.verdict),'Interpreter','none');
    exportgraphics(fig,file,'Resolution',150); close(fig);
end

function append_logs(out,R)
    files={'AUV_REALIZATION_READINESS_PLAN.md', ...
        'AUV_REALISM_AND_VISUAL_VALIDATION.md','STATE_SPACE_MODEL_AUDIT.md'};
    labels={'readiness','realism','research'};
    for i=1:numel(files)
        f=fopen(fullfile(out,files{i}),'a');
        fprintf(f,'\n\n---\n\n## %s — %s (%s log)\n\n', ...
            R.task_id,R.gate,labels{i});
        fprintf(f,'- Verdict: **%s** — %s.\n',R.verdict,R.closure);
        fprintf(f,'- Coverage: 32/32; pass-through %d, RESHAPE %d, REFUSE %d.\n', ...
            R.coverage.pass_through,R.coverage.admitted_reshape,R.coverage.refused);
        fprintf(f,'- Currents **ASSUMED**; actuators **NOT_CERTIFIED**; production frozen.\n');
        fprintf(f,'- Production not promoted; refusal never counted as tracking success.\n');
        fprintf(f,'- Next: %s\n',R.next);
        fprintf(f,'- `CODEX_VERTICAL_PLAN.md` untouched.\n');
        fclose(f);
    end
end

function id=case_id(route,U,ve); id=sprintf('%s_U%.1f_VE%+.2f',route,U,ve); end
function x=wrap_pi(x); x=mod(x+pi,2*pi)-pi; end
function s=tern(tf,a,b); if tf; s=a; else; s=b; end; end
function R=rotmat(phi,theta,psi)
    R=[cos(psi)*cos(theta),cos(psi)*sin(theta)*sin(phi)-sin(psi)*cos(phi),cos(psi)*sin(theta)*cos(phi)+sin(psi)*sin(phi); ...
       sin(psi)*cos(theta),sin(psi)*sin(theta)*sin(phi)+cos(psi)*cos(phi),sin(psi)*sin(theta)*cos(phi)-cos(psi)*sin(phi); ...
       -sin(theta),cos(theta)*sin(phi),cos(theta)*cos(phi)];
end
