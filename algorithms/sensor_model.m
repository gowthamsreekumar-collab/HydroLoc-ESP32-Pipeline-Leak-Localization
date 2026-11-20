function [sig_out, sig_info] = sensor_model(sig_in, params)
% SENSOR_MODEL  Model sensor analog front-end and ESP32 ADC digitization.
%
%   [sig_out, sig_info] = sensor_model(sig_in, params)
%
%   Simulates the signal conditioning chain from the raw acoustic sensor
%   through the ESP32 ADC, including:
%     1. Sensor bandwidth limiting (anti-aliasing)
%     2. Signal amplification / gain
%     3. DC bias addition (to centre signal in ADC range)
%     4. ADC voltage clamping (0 to Vref)
%     5. 12-bit quantization
%     6. Conversion back to voltage for processing
%
%   This models the physical signal path:
%     Acoustic sensor → Op-amp gain stage → ESP32 ADC pin
%
%   INPUTS:
%     sig_in — Raw analog signal from leak_signal_model [1 x N]
%     params — structure with fields:
%       .sampling_rate     [Hz]   Sampling frequency
%       .adc_bits          [int]  ADC resolution (default 12)
%       .adc_vref          [V]    ADC reference voltage (default 3.3)
%       .sensor_bandwidth  [Hz]   Sensor -3dB bandwidth (default 4000)
%       .amplifier_gain    [–]    Pre-ADC amplifier gain (default 10)
%       .dc_bias           [V]    DC offset to centre in ADC range (default Vref/2)
%       .enable_quantization [bool]  Apply ADC quantization (default true)
%
%   OUTPUTS:
%     sig_out  — Digitized signal (in volts, after ADC) [1 x N]
%     sig_info — Structure with diagnostic fields:
%       .sig_amplified    — Signal after gain stage
%       .sig_biased       — Signal after DC bias
%       .sig_clamped      — Signal after voltage clamping
%       .sig_quantized    — Signal after quantization (ADC codes)
%       .clipping_ratio   — Fraction of samples that clipped
%       .snr_estimate_dB  — Estimated SNR after digitization
%       .adc_lsb_voltage  — Voltage per ADC least-significant bit

% =====================================================================
%  DEFAULT PARAMETERS
% =====================================================================
fs = params.sampling_rate;

if isfield(params, 'adc_bits')
    adc_bits = params.adc_bits;
else
    adc_bits = 12;
end
if isfield(params, 'adc_vref')
    adc_vref = params.adc_vref;
else
    adc_vref = 3.3;
end
if isfield(params, 'sensor_bandwidth')
    sensor_bw = params.sensor_bandwidth;
else
    sensor_bw = 4000;
end
if isfield(params, 'amplifier_gain')
    amp_gain = params.amplifier_gain;
else
    amp_gain = 10;
end
if isfield(params, 'dc_bias')
    dc_bias = params.dc_bias;
else
    dc_bias = adc_vref / 2;   % Centre in ADC range
end
if isfield(params, 'enable_quantization')
    do_quant = params.enable_quantization;
else
    do_quant = true;
end

N = length(sig_in);

% =====================================================================
%  STEP 1: SENSOR BANDWIDTH LIMITING
% =====================================================================
% The physical sensor has a finite bandwidth (e.g., piezo element).
% Model as a low-pass filter.
f_cutoff = min(sensor_bw, fs/2 * 0.95);
if f_cutoff > 10
    [b_sens, a_sens] = butter(3, f_cutoff / (fs/2), 'low');
    sig_bw = filtfilt(b_sens, a_sens, sig_in);
else
    sig_bw = sig_in;
end

% =====================================================================
%  STEP 2: AMPLIFICATION (OP-AMP GAIN STAGE)
% =====================================================================
sig_amplified = amp_gain * sig_bw;

% =====================================================================
%  STEP 3: DC BIAS (CENTRE IN ADC INPUT RANGE)
% =====================================================================
sig_biased = sig_amplified + dc_bias;

% =====================================================================
%  STEP 4: VOLTAGE CLAMPING (PROTECTION DIODES)
% =====================================================================
sig_clamped = sig_biased;
clip_low  = sig_clamped < 0;
clip_high = sig_clamped > adc_vref;
sig_clamped(clip_low)  = 0;
sig_clamped(clip_high) = adc_vref;
clipping_ratio = sum(clip_low | clip_high) / N;

% =====================================================================
%  STEP 5: ADC QUANTIZATION (12-bit)
% =====================================================================
adc_max_code = 2^adc_bits - 1;
adc_lsb = adc_vref / adc_max_code;

if do_quant
    % Convert to ADC codes (integer)
    adc_codes = round(sig_clamped / adc_vref * adc_max_code);
    adc_codes = max(0, min(adc_max_code, adc_codes));
    
    % Convert back to voltage (as the ESP32 firmware would read)
    sig_quantized = adc_codes * adc_lsb;
else
    adc_codes = sig_clamped / adc_lsb;
    sig_quantized = sig_clamped;
end

% Remove DC bias for processing (ESP32 firmware subtracts known bias)
sig_out = sig_quantized - dc_bias;

% =====================================================================
%  DIAGNOSTICS
% =====================================================================
% Estimate SNR
sig_power   = mean(sig_amplified.^2);
quant_noise = mean((sig_quantized - dc_bias - sig_amplified).^2);
if quant_noise > 0
    snr_db = 10 * log10(sig_power / quant_noise);
else
    snr_db = Inf;
end

sig_info.sig_amplified    = sig_amplified;
sig_info.sig_biased       = sig_biased;
sig_info.sig_clamped      = sig_clamped;
sig_info.sig_quantized    = sig_quantized;
sig_info.adc_codes        = adc_codes;
sig_info.clipping_ratio   = clipping_ratio;
sig_info.snr_estimate_dB  = snr_db;
sig_info.adc_lsb_voltage  = adc_lsb;

end
