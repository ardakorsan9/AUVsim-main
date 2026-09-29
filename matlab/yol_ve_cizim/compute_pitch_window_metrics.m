function W = compute_pitch_window_metrics(t, e_th, s, s_total, varargin)
%COMPUTE_PITCH_WINDOW_METRICS Pitch acquisition / steady window metrics.
%
%   W = compute_pitch_window_metrics(t, e_th, s, s_total)
%   W = compute_pitch_window_metrics(..., 'mode', MODE)
%
% Modes
%   'persistent' (default)
%       Settling = earliest time after which |e_theta| stays inside
%       +/- band_deg for the remainder of the valid tracking interval
%       (samples with s < end_frac*s_total). If absent: settling_s=NaN.
%       acquisition = [start, persistent settle]  (indices 1:settle_idx)
%       steady      = [settle, end-exclusion]     (settle_idx:n_end)
%
%   'first_hold' (legacy PITCH_CLOSURE / prior XZ drivers)
%       First stretch with |e| in-band for hold_s seconds; settling reported
%       at end of that hold (cap hold_cap_s if never in-band).
%       steady = (t>=settle_t0 & s<end_frac*s_total) & ~acq, with fallback.
%
% Units: t [s], e_th [rad], s [m], s_total [m]; reported angle stats [deg].

    p = inputParser;
    addParameter(p, 'mode', 'persistent', @(x) ischar(x) || isstring(x));
    addParameter(p, 'band_deg', 0.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'hold_s', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'hold_cap_s', 6.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'end_frac', 0.88, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
    addParameter(p, 'settle_t0', 5.0, @(x) isnumeric(x) && isscalar(x));
    parse(p, varargin{:});
    opt = p.Results;
    mode = lower(string(opt.mode));

    t = t(:);
    e_th = e_th(:);
    s = s(:);
    N = numel(t);
    if numel(e_th) ~= N || numel(s) ~= N
        error('compute_pitch_window_metrics:LengthMismatch', ...
            't, e_th, s must be equal length.');
    end
    if N < 2
        error('compute_pitch_window_metrics:TooShort', 'Need >=2 samples.');
    end
    dt = t(2) - t(1);
    band = deg2rad(opt.band_deg);
    in_band = abs(e_th) <= band;
    mask_before_end = s < opt.end_frac * s_total;
    n_end = find(mask_before_end, 1, 'last');
    if isempty(n_end)
        n_end = 0;
    end

    W = struct();
    W.mode = char(mode);
    W.band_deg = opt.band_deg;
    W.end_frac = opt.end_frac;
    W.n_total = N;
    W.n_end = n_end;
    W.mask_before_end = mask_before_end;
    W.in_band = in_band;

    if mode == "persistent"
        settle_idx = NaN;
        if n_end >= 1
            for k = 1:n_end
                if all(in_band(k:n_end))
                    settle_idx = k;
                    break;
                end
            end
        end
        W.settle_idx = settle_idx;
        if isnan(settle_idx)
            W.settling_s = NaN;
            W.acq_time_s = NaN;
            W.persistent_ok = false;
            mask_acq = false(N, 1);
            mask_steady = false(N, 1);
        else
            W.settling_s = t(settle_idx);
            W.acq_time_s = W.settling_s;
            W.persistent_ok = true;
            mask_acq = (1:N)' <= settle_idx;
            mask_steady = ((1:N)' >= settle_idx) & mask_before_end;
        end
        W.hold_s = NaN;
        W.hold_cap_s = NaN;
        W.settle_t0 = NaN;
    elseif mode == "first_hold"
        hold_n = max(1, round(opt.hold_s / dt));
        acq_end = N;
        for k = 1:(N - hold_n)
            if all(in_band(k:k + hold_n - 1))
                acq_end = k + hold_n - 1;
                break;
            end
        end
        acq_cap = min(N, round(opt.hold_cap_s / dt));
        if acq_end > acq_cap && ~any(in_band(1:acq_cap))
            acq_end = acq_cap;
        end
        W.settle_idx = acq_end;
        W.settling_s = t(acq_end);
        W.acq_time_s = W.settling_s;
        W.persistent_ok = all(in_band(acq_end:max(acq_end, n_end)));
        mask_acq = (1:N)' <= acq_end;
        mask_sbe = (t >= opt.settle_t0) & mask_before_end;
        mask_steady = mask_sbe & ~mask_acq;
        if ~any(mask_steady)
            mask_steady = mask_sbe;
        end
        W.hold_s = opt.hold_s;
        W.hold_cap_s = opt.hold_cap_s;
        W.settle_t0 = opt.settle_t0;
        W.mask_sbe = mask_sbe;
    else
        error('compute_pitch_window_metrics:BadMode', ...
            'mode must be ''persistent'' or ''first_hold''.');
    end

    W.mask_acq = mask_acq;
    W.mask_steady = mask_steady;
    W.n_acq = nnz(mask_acq);
    W.n_steady = nnz(mask_steady);
    W.acq = local_eth_stats(e_th(mask_acq));
    W.steady = local_eth_stats(e_th(mask_steady));
end

function s = local_eth_stats(e)
    if isempty(e)
        s = struct('mae_deg', NaN, 'rms_deg', NaN, 'signed_deg', NaN, ...
            'p95_deg', NaN, 'max_deg', NaN);
        return;
    end
    s = struct( ...
        'mae_deg', rad2deg(mean(abs(e))), ...
        'rms_deg', rad2deg(rms(e)), ...
        'signed_deg', rad2deg(mean(e)), ...
        'p95_deg', rad2deg(local_pctile95(abs(e))), ...
        'max_deg', rad2deg(max(abs(e))));
end

function v = local_pctile95(x)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    k = max(1, min(numel(x), ceil(0.95 * numel(x))));
    v = x(k);
end
