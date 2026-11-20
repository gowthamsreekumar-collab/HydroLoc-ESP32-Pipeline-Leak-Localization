function [estimated_tdoa, gcc_corr, lags_sec] = gcc_phat(sig_A, sig_B, fs, max_delay_sec)
% GCC_PHAT  Generalized Cross-Correlation with Phase Transform.
%
%   [estimated_tdoa, gcc_corr, lags_sec] = gcc_phat(sig_A, sig_B, fs)
%   [estimated_tdoa, gcc_corr, lags_sec] = gcc_phat(sig_A, sig_B, fs, max_delay_sec)
%
%   Estimates the time difference of arrival (TDOA) between two signals
%   using the GCC-PHAT algorithm. GCC-PHAT whitens the cross-power
%   spectrum before computing the inverse FFT, yielding a sharp peak at
%   the true delay even in the presence of noise and reverberation.
%
%   ALGORITHM:
%     1. Compute FFTs of both signals:  X_A(f), X_B(f)
%     2. Cross-power spectrum:          G_AB(f) = X_A(f) · X_B*(f)
%     3. PHAT weighting:                W(f) = 1 / |G_AB(f)|
%     4. GCC-PHAT:  R(τ) = IFFT{ G_AB(f) · W(f) }
%     5. Estimate:  Δt = argmax_τ R(τ)
%
%   Sub-sample interpolation is applied using parabolic peak fitting
%   to improve accuracy beyond the sampling period resolution.
%
%   INPUTS:
%     sig_A         — Signal from Sensor A [1 x N]
%     sig_B         — Signal from Sensor B [1 x N]
%     fs            — Sampling frequency (Hz)
%     max_delay_sec — (Optional) Maximum expected delay (seconds).
%                     Limits the search range. Default: N/(2·fs).
%
%   OUTPUTS:
%     estimated_tdoa — Estimated TDOA in seconds.
%                      Positive ⇒ sig_A is delayed relative to sig_B
%                      (leak closer to Sensor B).
%     gcc_corr       — GCC-PHAT correlation function [1 x M]
%     lags_sec       — Corresponding lag values in seconds [1 x M]
%
%   SIGN CONVENTION:
%     TDOA = t_A − t_B
%     If leak is at position x from Sensor A on a pipeline of length L:
%       TDOA = (2x − L) / c
%     Positive TDOA ⇒ signal arrives at B first (leak closer to B).
%
%   REFERENCES:
%     C. Knapp and G. Carter, "The generalized correlation method for
%     estimation of time delay," IEEE Trans. ASSP, 1976.

% =====================================================================
%  INPUT VALIDATION
% =====================================================================
sig_A = sig_A(:).';   % Ensure row vector
sig_B = sig_B(:).';
N = length(sig_A);
assert(length(sig_B) == N, 'sig_A and sig_B must have the same length.');
assert(fs > 0, 'Sampling rate must be positive.');

if nargin < 4 || isempty(max_delay_sec)
    max_delay_sec = (N/2) / fs;
end
max_delay_samples = round(max_delay_sec * fs);

% =====================================================================
%  FFT (zero-padded for efficiency)
% =====================================================================
N_fft = 2^nextpow2(2 * N);   % Zero-pad to avoid circular correlation

X_A = fft(sig_A, N_fft);
X_B = fft(sig_B, N_fft);

% =====================================================================
%  CROSS-POWER SPECTRUM WITH PHAT WEIGHTING
% =====================================================================
G_AB = X_A .* conj(X_B);                    % Cross-power spectrum
magnitude = abs(G_AB);
magnitude(magnitude < 1e-12) = 1e-12;       % Avoid division by zero
G_phat = G_AB ./ magnitude;                 % Phase-only (PHAT)

% =====================================================================
%  INVERSE FFT → GCC-PHAT CORRELATION
% =====================================================================
gcc_full = real(ifft(G_phat));
gcc_full = fftshift(gcc_full);               % Centre zero-lag

% Lag vector (samples)
lags_samples = (-N_fft/2 : N_fft/2 - 1);
lags_sec_full = lags_samples / fs;

% =====================================================================
%  RESTRICT SEARCH RANGE
% =====================================================================
valid_mask = abs(lags_samples) <= max_delay_samples;
gcc_corr   = gcc_full(valid_mask);
lags_sec   = lags_sec_full(valid_mask);

% =====================================================================
%  PEAK DETECTION
% =====================================================================
[~, peak_idx] = max(gcc_corr);
estimated_tdoa_coarse = lags_sec(peak_idx);

% =====================================================================
%  SUB-SAMPLE PARABOLIC INTERPOLATION
% =====================================================================
% Fit a parabola to the peak and its two neighbours to refine the
% TDOA estimate to sub-sample accuracy.
if peak_idx > 1 && peak_idx < length(gcc_corr)
    alpha = gcc_corr(peak_idx - 1);
    beta  = gcc_corr(peak_idx);
    gamma = gcc_corr(peak_idx + 1);
    
    denom = alpha - 2*beta + gamma;
    if abs(denom) > 1e-15
        delta = 0.5 * (alpha - gamma) / denom;  % Fractional sample offset
    else
        delta = 0;
    end
    
    estimated_tdoa = estimated_tdoa_coarse + delta / fs;
else
    estimated_tdoa = estimated_tdoa_coarse;
end

end
