function [sig_A, sig_B, t, true_tdoa, leak_source] = leak_signal_model(params)
% LEAK_SIGNAL_MODEL  Generate acoustic leak signals at two sensor positions.
%
%   [sig_A, sig_B, t, true_tdoa, leak_source] = leak_signal_model(params)
%
%   Simulates broadband acoustic emission from a pipeline leak and computes
%   the time-delayed, attenuated, and noise-corrupted signals received at
%   two sensors (A and B) mounted at opposite ends of the pipeline.
%
%   PHYSICAL MODEL:
%     - Leak generates broadband noise (turbulent flow through orifice).
%     - Spectral content is concentrated in 100–3000 Hz range.
%     - Acoustic waves propagate along the pipe wall at speed c.
%     - Geometric attenuation follows 1/sqrt(d) (cylindrical spreading).
%     - Frequency-dependent attenuation adds high-frequency roll-off.
%     - Leak severity controls source signal amplitude.
%     - Random burst transients model intermittent turbulence.
%
%   INPUTS:
%     params — structure with fields:
%       .pipeline_length      [m]    Distance between Sensor A and B
%       .leak_position        [m]    Leak distance from Sensor A (0 to L)
%       .propagation_speed    [m/s]  Acoustic propagation speed in pipe
%       .sampling_rate        [Hz]   Sampling frequency
%       .duration             [s]    Signal duration
%       .leak_severity        [0–1]  0 = no leak, 0.1 = small, 1 = large
%       .noise_level          [V]    Background noise std deviation
%       .sensor_sensitivity_A [–]    Sensor A gain factor (default 1.0)
%       .sensor_sensitivity_B [–]    Sensor B gain factor (default 1.0)
%       .random_seed          [int]  (Optional) Seed for reproducibility
%
%   OUTPUTS:
%     sig_A       — Signal received at Sensor A [1 x N]
%     sig_B       — Signal received at Sensor B [1 x N]
%     t           — Time vector [1 x N] (seconds)
%     true_tdoa   — True time difference of arrival (seconds)
%                    Positive ⇒ leak is closer to Sensor B
%     leak_source — Original leak source signal [1 x N]
%
%   COORDINATE CONVENTION:
%     Sensor A at x = 0, Sensor B at x = L.
%     TDOA = t_A − t_B = (2·x_leak − L) / c
%     Positive TDOA: signal reaches B before A (leak closer to B).
%     Negative TDOA: signal reaches A before B (leak closer to A).

% =====================================================================
%  PARAMETER EXTRACTION AND VALIDATION
% =====================================================================
L       = params.pipeline_length;
x_leak  = params.leak_position;
c       = params.propagation_speed;
fs      = params.sampling_rate;
T       = params.duration;
sev     = params.leak_severity;
noise_std = params.noise_level;

% Default sensor sensitivities
if isfield(params, 'sensor_sensitivity_A')
    sens_A = params.sensor_sensitivity_A;
else
    sens_A = 1.0;
end
if isfield(params, 'sensor_sensitivity_B')
    sens_B = params.sensor_sensitivity_B;
else
    sens_B = 1.0;
end

% Optional reproducibility
if isfield(params, 'random_seed') && ~isempty(params.random_seed)
    rng(params.random_seed);
end

% Validate
assert(x_leak >= 0 && x_leak <= L, ...
    'Leak position must be in [0, L]. Got x_leak = %.2f, L = %.2f', x_leak, L);
assert(sev >= 0 && sev <= 1, 'Leak severity must be in [0, 1].');
assert(fs > 0, 'Sampling rate must be positive.');
assert(c > 0, 'Propagation speed must be positive.');

% =====================================================================
%  TIME VECTOR AND TRUE TDOA
% =====================================================================
N = round(T * fs);
t = (0:N-1) / fs;

% Propagation delays from leak to each sensor
delay_A = x_leak / c;              % seconds, leak → Sensor A
delay_B = (L - x_leak) / c;        % seconds, leak → Sensor B
true_tdoa = delay_A - delay_B;      % seconds

% Delay in samples
delay_samples_A = round(delay_A * fs);
delay_samples_B = round(delay_B * fs);

% =====================================================================
%  LEAK SOURCE SIGNAL GENERATION
% =====================================================================
if sev > 0 && x_leak >= 0 && x_leak <= L
    % ----- Broadband turbulent noise (leak acoustic emission) -----
    leak_raw = randn(1, N);
    
    % Bandpass filter: 100–3000 Hz (typical leak acoustic range)
    f_lo = 100;
    f_hi = min(3000, fs/2 * 0.95);   % Stay below Nyquist
    
    if f_lo < f_hi
        [b_bp, a_bp] = butter(4, [f_lo, f_hi] / (fs/2), 'bandpass');
        leak_filtered = filtfilt(b_bp, a_bp, leak_raw);
    else
        leak_filtered = leak_raw;
    end
    
    % Normalize and scale by severity
    leak_filtered = leak_filtered / (max(abs(leak_filtered)) + eps);
    leak_source = sev * leak_filtered;
    
    % ----- Add intermittent burst transients -----
    % Leaks exhibit non-stationary turbulence bursts
    n_bursts = randi([3, 10]);
    for ib = 1:n_bursts
        burst_ctr   = randi([round(N * 0.05), round(N * 0.95)]);
        burst_width = randi([round(N * 0.01), round(N * 0.06)]);
        burst_env   = exp(-((1:N) - burst_ctr).^2 / (2 * burst_width^2));
        burst_noise = randn(1, N);
        if f_lo < f_hi
            burst_noise = filtfilt(b_bp, a_bp, burst_noise);
        end
        burst_noise = burst_noise / (max(abs(burst_noise)) + eps);
        leak_source = leak_source + sev * 0.4 * burst_noise .* burst_env;
    end
    
    % ----- Frequency-dependent pipe attenuation -----
    % Higher frequencies attenuate more with distance
    % Model as a gentle low-pass effect proportional to distance
    avg_dist = (x_leak + (L - x_leak)) / 2;
    cutoff_atten = max(500, 4000 - 15 * avg_dist);
    cutoff_atten = min(cutoff_atten, fs/2 * 0.95);
    if cutoff_atten > f_lo
        [b_lp, a_lp] = butter(2, cutoff_atten / (fs/2), 'low');
        leak_source = filtfilt(b_lp, a_lp, leak_source);
    end
    
else
    % No leak — source is silent
    leak_source = zeros(1, N);
end

% =====================================================================
%  PROPAGATION TO SENSORS (DELAY + ATTENUATION)
% =====================================================================
sig_A_clean = zeros(1, N);
sig_B_clean = zeros(1, N);

if sev > 0
    % --- Distance-based attenuation (cylindrical spreading: 1/sqrt(d)) ---
    d_A = max(x_leak, 0.01);          % Avoid division by zero
    d_B = max(L - x_leak, 0.01);
    atten_A = 1 / sqrt(d_A);
    atten_B = 1 / sqrt(d_B);
    
    % --- Apply propagation delay ---
    if delay_samples_A == 0
        sig_A_clean = atten_A * leak_source;
    elseif delay_samples_A < N
        sig_A_clean(delay_samples_A+1 : end) = ...
            atten_A * leak_source(1 : N - delay_samples_A);
    end
    
    if delay_samples_B == 0
        sig_B_clean = atten_B * leak_source;
    elseif delay_samples_B < N
        sig_B_clean(delay_samples_B+1 : end) = ...
            atten_B * leak_source(1 : N - delay_samples_B);
    end
    
    % --- Apply per-path high-frequency attenuation ---
    % Longer path → more HF loss
    for ch = 1:2
        if ch == 1
            d = d_A; sig_ch = sig_A_clean;
        else
            d = d_B; sig_ch = sig_B_clean;
        end
        fc_path = max(300, 4000 - 20 * d);
        fc_path = min(fc_path, fs/2 * 0.95);
        if fc_path > 100
            [b_path, a_path] = butter(2, fc_path / (fs/2), 'low');
            sig_ch = filtfilt(b_path, a_path, sig_ch);
        end
        if ch == 1
            sig_A_clean = sig_ch;
        else
            sig_B_clean = sig_ch;
        end
    end
end

% =====================================================================
%  SENSOR SENSITIVITY AND NOISE
% =====================================================================
% Apply sensor gain
sig_A_clean = sens_A * sig_A_clean;
sig_B_clean = sens_B * sig_B_clean;

% Add independent background noise at each sensor
noise_A = noise_std * randn(1, N);
noise_B = noise_std * randn(1, N);

sig_A = sig_A_clean + noise_A;
sig_B = sig_B_clean + noise_B;

end
