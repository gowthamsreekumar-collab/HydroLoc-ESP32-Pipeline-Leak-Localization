function [est_pos, loc_info] = tdoa_localization(tdoa, pipeline_length, prop_speed)
% TDOA_LOCALIZATION  Estimate leak position from TDOA measurement.
%
%   [est_pos, loc_info] = tdoa_localization(tdoa, pipeline_length, prop_speed)
%
%   Computes the estimated leak position along a straight pipeline with
%   two sensors at each end, using the time difference of arrival (TDOA)
%   between the leak acoustic signals received at the two sensors.
%
%   DERIVATION:
%     Sensor A at x = 0, Sensor B at x = L.
%     Leak at unknown position x_leak.
%
%     Travel time to Sensor A:  t_A = x_leak / c
%     Travel time to Sensor B:  t_B = (L − x_leak) / c
%     TDOA:  Δt = t_A − t_B = (2·x_leak − L) / c
%
%     Solving for x_leak:
%       x_leak = (L + c · Δt) / 2
%
%   BOUNDARY HANDLING:
%     If the estimated position falls outside [0, L] due to noise, it is
%     clamped to the valid range and flagged in loc_info.
%
%   INPUTS:
%     tdoa            — Measured TDOA in seconds (t_A − t_B)
%     pipeline_length — Distance between Sensor A and B (metres)
%     prop_speed      — Acoustic propagation speed in pipe (m/s)
%
%   OUTPUTS:
%     est_pos  — Estimated leak distance from Sensor A (metres)
%     loc_info — Structure with diagnostic fields:
%       .raw_estimate     — Unclamped estimate (m)
%       .clamped          — true if estimate was clamped to [0, L]
%       .max_tdoa         — Maximum physically possible |TDOA| (s)
%       .tdoa_valid       — true if |TDOA| ≤ L/c
%       .resolution_m     — Spatial resolution limit (m)
%       .equation_used    — String describing the formula

% =====================================================================
%  VALIDATION
% =====================================================================
L = pipeline_length;
c = prop_speed;
assert(L > 0,  'Pipeline length must be positive.');
assert(c > 0,  'Propagation speed must be positive.');

% =====================================================================
%  LOCALIZATION EQUATION
% =====================================================================
%   x_est = (L + c * Δt) / 2

raw_estimate = (L + c * tdoa) / 2;

% =====================================================================
%  BOUNDARY CHECK AND CLAMPING
% =====================================================================
max_tdoa = L / c;    % Maximum physically possible |TDOA|
tdoa_valid = abs(tdoa) <= max_tdoa * 1.1;   % Allow 10% tolerance for noise

clamped = false;
est_pos = raw_estimate;
if est_pos < 0
    est_pos = 0;
    clamped = true;
elseif est_pos > L
    est_pos = L;
    clamped = true;
end

% =====================================================================
%  DIAGNOSTIC INFORMATION
% =====================================================================
loc_info.raw_estimate   = raw_estimate;
loc_info.clamped        = clamped;
loc_info.max_tdoa       = max_tdoa;
loc_info.tdoa_valid     = tdoa_valid;
loc_info.equation_used  = 'x = (L + c * dt) / 2';

% Spatial resolution depends on sampling rate (if known)
% For now, report based on propagation speed
loc_info.resolution_note = sprintf( ...
    'Spatial resolution ≈ c / (2·fs). At c = %.0f m/s and fs = 10000 Hz → %.3f m', ...
    c, c / (2 * 10000));

end
