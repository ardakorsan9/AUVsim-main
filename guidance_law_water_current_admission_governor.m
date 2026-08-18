function [u_ref, status] = guidance_law_water_current_admission_governor(route, requested_speed, Vc_ned, map_cases, reset)
% Isolated Gate-4B speed/admission governor. Production guidance is untouched.
% Contract: map_cases must be the 32-row Gate-4A map with route, U, Vc_ned,
% classifier, and actuator/tracking metrics. Only a FEASIBLE row having the
% identical route and current may authorize a speed.

    persistent keys held_speeds held_valid
    % Default-initialize persistents before any indexing (first-call / after clear).
    if isempty(keys)
        keys = {};
    end
    if isempty(held_speeds)
        held_speeds = zeros(0,1);
    end
    if isempty(held_valid)
        held_valid = false(0,1);
    end
    if nargin >= 5 && reset
        keys = {};
        held_speeds = zeros(0,1);
        held_valid = false(0,1);
        if isempty(route)
            u_ref = 0;
            status = struct('decision','RESET','reason','persistent hold state cleared', ...
                'requested_class','','requested_row',0,'source_row',0, ...
                'admitted',false,'tracking_success',false,'hold_valid',false, ...
                'route','','Vc_ned',zeros(1,3),'requested_speed',0,'output_speed',0);
            return
        end
    end

    validateattributes(requested_speed, {'numeric'}, {'scalar','finite','nonnegative'});
    validateattributes(Vc_ned, {'numeric'}, {'vector','numel',3,'finite'});
    required = {'route','U','Vc_ned','classifier'};
    assert(isstruct(map_cases) && numel(map_cases) == 32, ...
        'AdmissionGovernor:MapContract', 'Gate-4A map must contain exactly 32 rows.');
    assert(all(isfield(map_cases, required)), 'AdmissionGovernor:MapContract', ...
        'Gate-4A map schema is incomplete.');

    route = char(route);
    Vc_ned = Vc_ned(:)';
    % Force column masks: strcmp on 32x1 struct yields 1x32; arrayfun yields 32x1.
    % Mixing them without (:) expands to 32x32 and find() can exceed numel(map).
    same_route = strcmp({map_cases.route}, route);
    same_route = same_route(:);
    same_current = arrayfun(@(x) max(abs(x.Vc_ned(:)'-Vc_ned)) < 1e-12, map_cases);
    same_current = same_current(:);
    exact_speed = abs([map_cases.U] - requested_speed) < 1e-12;
    exact_speed = exact_speed(:);
    class_feasible = strcmp({map_cases.classifier}, 'FEASIBLE');
    class_feasible = class_feasible(:);
    requested_row = find(same_route & same_current & exact_speed, 1);
    assert(~isempty(requested_row), 'AdmissionGovernor:UnknownContract', ...
        'Requested route/current/speed is absent from the declared map.');

    key = sprintf('%s|%.12g|%.12g|%.12g', route, Vc_ned);
    ikey = find(strcmp(keys, key), 1);
    if isempty(ikey)
        keys{end+1} = key; %#ok<AGROW>
        held_speeds(end+1,1) = 0; %#ok<AGROW>
        held_valid(end+1,1) = false; %#ok<AGROW>
        ikey = numel(keys);
    end

    original_class = char(map_cases(requested_row).classifier);
    if strcmp(original_class, 'FEASIBLE')
        u_ref = requested_speed;
        decision = 'PASS_THROUGH';
        reason = 'exact Gate-4A FEASIBLE row; exact speed parity';
        source_row = requested_row;
        admitted = true;
    else
        candidates = find(same_route & same_current & class_feasible);
        if ~isempty(candidates)
            candidate_speeds = [map_cases(candidates).U];
            demand = inf(size(candidates));
            if isfield(map_cases, 'delta_r_saturation_pct')
                demand = [map_cases(candidates).delta_r_saturation_pct];
            end
            delta = abs(candidate_speeds(:)-requested_speed);
            [~, order] = sortrows([demand(:), delta(:), candidate_speeds(:)], [1 2 3]);
            source_row = candidates(order(1));
            u_ref = map_cases(source_row).U;
            decision = 'RESHAPE';
            reason = sprintf('same route/current FEASIBLE map row %s at %.3g m/s', ...
                map_cases(source_row).id, u_ref);
            admitted = true;
        else
            source_row = 0;
            if held_valid(ikey)
                u_ref = held_speeds(ikey);
                reason = 'no same-route/current FEASIBLE row; hold last validated speed';
            else
                u_ref = 0;
                reason = 'no same-route/current FEASIBLE row; bounded zero hold';
            end
            decision = 'REFUSE';
            admitted = false;
        end
    end

    map_speeds = [map_cases.U];
    u_ref = max(0, min(max(map_speeds), u_ref));
    if admitted
        held_speeds(ikey) = u_ref;
        held_valid(ikey) = true;
    end
    status = struct('decision',decision, 'reason',reason, ...
        'requested_class',original_class, 'requested_row',requested_row, ...
        'source_row',source_row, 'admitted',admitted, ...
        'tracking_success',false, 'hold_valid',held_valid(ikey), ...
        'route',route, 'Vc_ned',Vc_ned, 'requested_speed',requested_speed, ...
        'output_speed',u_ref);
end
