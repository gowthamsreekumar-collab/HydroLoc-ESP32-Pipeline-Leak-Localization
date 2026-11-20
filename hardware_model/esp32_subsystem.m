function results = esp32_subsystem(sig_A_raw, sig_B_raw, sys_params)
% ESP32_SUBSYSTEM  Functional model of ESP32 embedded processing chain.
%
%   results = esp32_subsystem(sig_A_raw, sig_B_raw, sys_params)
%
%   Models the complete signal processing pipeline as it would execute
%   on an ESP32 microcontroller. This is a FUNCTIONAL MODEL — it
%   replicates the algorithmic behaviour of the embedded firmware, not
%   the chip-level hardware.
%
%   PROCESSING CHAIN (mirrors actual ESP32 firmware flow):
%     1. ADC Acquisition   — 12-bit quantization, voltage clamping
%     2. DC Removal        — Subtract mean (high-pass)
%     3. Bandpass Filtering — 100–3000 Hz (IIR, realisable on ESP32)
%     4. Windowing          — Hanning window to reduce spectral leakage
%     5. GCC-PHAT           — Cross-correlation for TDOA estimation
%     6. TDOA Calculation   — Peak detection with sub-sample interpolation
%     7. Leak Localization  — Position estimate: x = (L + c·Δt) / 2
%     8. Detection Decision — Energy-based leak/no-leak threshold test
%     9. Output Generation  — OLED data, LED states, buzzer, serial log
%
%   INPUTS:
%     sig_A_raw  — Raw analog signal from Sensor A [1 x N]
%     sig_B_raw  — Raw analog signal from Sensor B [1 x N]
%     sys_params — Structure with system parameters:
%       .pipeline_length    [m]    Distance between sensors
%       .propagation_speed  [m/s]  Acoustic speed in pipe
%       .sampling_rate      [Hz]   ADC sampling rate
%       .detection_threshold [–]   Energy ratio threshold for detection
%       .true_leak_position [m]    (Optional) For error calculation
%       .true_leak_severity [0–1]  (Optional) For reference
%
%   OUTPUTS:
%     results — Structure with all processing results:
%       .leak_detected       — Boolean: leak detected
%       .estimated_position  — Estimated leak distance from Sensor A (m)
%       .estimated_tdoa      — Estimated TDOA (seconds)
%       .localization_error  — |estimated − true| if true pos given (m)
%       .signal_energy_A     — RMS energy of processed Sensor A signal
%       .signal_energy_B     — RMS energy of processed Sensor B signal
%       .energy_ratio        — Signal energy / noise floor estimate
%       .gcc_correlation     — GCC-PHAT correlation function
%       .gcc_lags            — Corresponding lag vector (seconds)
%       .sig_A_processed     — Signal A after preprocessing
%       .sig_B_processed     — Signal B after preprocessing
%       .sig_A_adc           — Signal A after ADC model
%       .sig_B_adc           — Signal B after ADC model
%       .oled_data           — Structure for OLED display
%       .led_green           — Green LED state (boolean)
%       .led_red             — Red LED state (boolean)
%       .buzzer_active       — Buzzer state (boolean)
%       .serial_log          — Cell array of serial output strings
%       .processing_steps    — Cell array describing each step

% =====================================================================
%  PARAMETER SETUP
% =====================================================================
L   = sys_params.pipeline_length;
c   = sys_params.propagation_speed;
fs  = sys_params.sampling_rate;

if isfield(sys_params, 'detection_threshold')
    det_thresh = sys_params.detection_threshold;
else
    det_thresh = 3.0;   % Energy ratio threshold
end

N = length(sig_A_raw);
results.processing_steps = {};
serial_log = {};

serial_log{end+1} = '=== ESP32 Pipeline Leak Detection System ===';
serial_log{end+1} = sprintf('Pipeline Length: %.1f m', L);
serial_log{end+1} = sprintf('Propagation Speed: %.0f m/s', c);
serial_log{end+1} = sprintf('Sampling Rate: %d Hz', fs);
serial_log{end+1} = sprintf('Frame Size: %d samples', N);
serial_log{end+1} = '-------------------------------------------';

% =====================================================================
%  STEP 1: ADC MODEL (12-bit quantization)
% =====================================================================
adc_params.sampling_rate     = fs;
adc_params.adc_bits          = 12;
adc_params.adc_vref          = 3.3;
adc_params.sensor_bandwidth  = 4000;
adc_params.amplifier_gain    = 10;
adc_params.dc_bias           = 1.65;   % Centre at Vref/2
adc_params.enable_quantization = true;

[sig_A_adc, adc_info_A] = sensor_model(sig_A_raw, adc_params);
[sig_B_adc, adc_info_B] = sensor_model(sig_B_raw, adc_params);

results.sig_A_adc = sig_A_adc;
results.sig_B_adc = sig_B_adc;
results.processing_steps{end+1} = 'STEP 1: ADC digitization (12-bit, 3.3V ref)';

serial_log{end+1} = sprintf('ADC Ch6 (SensorA) clipping: %.1f%%', adc_info_A.clipping_ratio*100);
serial_log{end+1} = sprintf('ADC Ch7 (SensorB) clipping: %.1f%%', adc_info_B.clipping_ratio*100);

% =====================================================================
%  STEP 2: DC REMOVAL
% =====================================================================
sig_A_dc = sig_A_adc - mean(sig_A_adc);
sig_B_dc = sig_B_adc - mean(sig_B_adc);
results.processing_steps{end+1} = 'STEP 2: DC offset removal (subtract mean)';

% =====================================================================
%  STEP 3: BANDPASS FILTERING (100–3000 Hz)
% =====================================================================
f_lo = 100;
f_hi = min(3000, fs/2 * 0.95);

if f_lo < f_hi
    [b_bp, a_bp] = butter(3, [f_lo f_hi] / (fs/2), 'bandpass');
    sig_A_filt = filtfilt(b_bp, a_bp, sig_A_dc);
    sig_B_filt = filtfilt(b_bp, a_bp, sig_B_dc);
else
    sig_A_filt = sig_A_dc;
    sig_B_filt = sig_B_dc;
end
results.processing_steps{end+1} = sprintf('STEP 3: Bandpass filter %d–%d Hz (Butterworth 3rd)', f_lo, round(f_hi));

% =====================================================================
%  STEP 4: WINDOWING (Hanning)
% =====================================================================
win = hanning(N)';
sig_A_win = sig_A_filt .* win;
sig_B_win = sig_B_filt .* win;
results.sig_A_processed = sig_A_win;
results.sig_B_processed = sig_B_win;
results.processing_steps{end+1} = 'STEP 4: Hanning window applied';

% =====================================================================
%  STEP 5: SIGNAL ENERGY AND RMS CALCULATION
% =====================================================================
energy_A = rms(sig_A_filt);
energy_B = rms(sig_B_filt);
results.signal_energy_A = energy_A;
results.signal_energy_B = energy_B;

% Calibrated quiescent noise floor at ADC output (sensor front-end noise after gain)
% With 10x gain and typical sensor noise (std ~0.02V), quiescent RMS is ~0.15V
baseline_quiescent_rms = 0.16;
energy_ratio = max(energy_A, energy_B) / baseline_quiescent_rms;
results.energy_ratio = energy_ratio;

% =====================================================================
%  STEP 6: GCC-PHAT CROSS-CORRELATION
% =====================================================================
max_delay = L / c;   % Maximum physically possible delay
[est_tdoa, gcc_corr, gcc_lags] = gcc_phat(sig_A_win, sig_B_win, fs, max_delay * 1.2);

results.estimated_tdoa   = est_tdoa;
results.gcc_correlation  = gcc_corr;
results.gcc_lags         = gcc_lags;
results.processing_steps{end+1} = sprintf('STEP 6: GCC-PHAT -> TDOA = %.6f s', est_tdoa);

% GCC-PHAT peak prominence: ratio of peak to mean noise floor
max_peak = max(gcc_corr);
mean_corr = mean(abs(gcc_corr));
peak_prominence = max_peak / (mean_corr + eps);
results.peak_prominence = peak_prominence;

serial_log{end+1} = sprintf('GCC-PHAT TDOA:   %.6f s', est_tdoa);
serial_log{end+1} = sprintf('Peak Prominence: %.2f', peak_prominence);

% =====================================================================
%  STEP 7: LEAK LOCALIZATION
% =====================================================================
[est_pos, loc_info] = tdoa_localization(est_tdoa, L, c);
results.estimated_position = est_pos;
results.localization_info  = loc_info;
results.processing_steps{end+1} = sprintf('STEP 7: Position estimate = %.2f m (from Sensor A)', est_pos);

serial_log{end+1} = sprintf('Estimated pos:   %.2f m from Sensor A', est_pos);

% =====================================================================
%  STEP 8: DETECTION DECISION
% =====================================================================
% A true leak produces:
%   1) Elevated acoustic energy significantly above baseline (energy_ratio >= 1.25), AND
%   2) Strong cross-channel coherence peak in GCC-PHAT (peak_prominence >= 4.0),
% OR massive elevated acoustic energy (energy_ratio >= det_thresh).
leak_detected = (energy_ratio >= det_thresh) || (peak_prominence >= 4.0 && energy_ratio >= 1.25);
results.leak_detected = leak_detected;
results.processing_steps{end+1} = sprintf('STEP 8: Detection = %s (energy_ratio %.2f vs threshold %.2f)', ...
    mat2str(leak_detected), energy_ratio, det_thresh);

if leak_detected
    serial_log{end+1} = '*** LEAK DETECTED ***';
    serial_log{end+1} = sprintf('*** Estimated position: %.2f m from Sensor A ***', est_pos);
else
    serial_log{end+1} = 'Status: Normal — No leak detected';
end

% =====================================================================
%  STEP 9: COMPUTE LOCALIZATION ERROR (if true position known)
% =====================================================================
if isfield(sys_params, 'true_leak_position') && ~isempty(sys_params.true_leak_position)
    true_pos = sys_params.true_leak_position;
    loc_error = abs(est_pos - true_pos);
    results.localization_error = loc_error;
    results.true_leak_position = true_pos;
    serial_log{end+1} = sprintf('True position:   %.2f m', true_pos);
    serial_log{end+1} = sprintf('Absolute error:  %.2f m', loc_error);
    results.processing_steps{end+1} = sprintf('STEP 9: Error = %.2f m (true = %.2f m)', loc_error, true_pos);
else
    results.localization_error = NaN;
    results.true_leak_position = NaN;
    results.processing_steps{end+1} = 'STEP 9: True position unknown — error not computed';
end

% =====================================================================
%  STEP 10: OUTPUT STATES (LEDs, Buzzer, OLED)
% =====================================================================
results.led_green     = ~leak_detected;
results.led_red       = leak_detected;
results.buzzer_active = leak_detected;

% OLED display data structure
oled = struct();
oled.line1 = 'Pipeline Monitor';
if leak_detected
    oled.line2 = 'LEAK DETECTED!';
    oled.line3 = sprintf('Position: %.1fm', est_pos);
    if ~isnan(results.localization_error)
        oled.line4 = sprintf('Error: %.2fm', results.localization_error);
    else
        oled.line4 = 'Error: N/A';
    end
else
    oled.line2 = 'Status: NORMAL';
    oled.line3 = 'No leak detected';
    oled.line4 = '';
end
oled.line5 = sprintf('SigA: %.4f', energy_A);
oled.line6 = sprintf('SigB: %.4f', energy_B);
results.oled_data = oled;

serial_log{end+1} = '-------------------------------------------';
serial_log{end+1} = sprintf('Green LED: %s', ternary(results.led_green, 'ON', 'OFF'));
serial_log{end+1} = sprintf('Red LED:   %s', ternary(results.led_red,   'ON', 'OFF'));
serial_log{end+1} = sprintf('Buzzer:    %s', ternary(results.buzzer_active, 'ON', 'OFF'));
serial_log{end+1} = '===========================================';

results.serial_log = serial_log;
results.processing_steps{end+1} = 'STEP 10: Output states generated';

end

% =====================================================================
%  HELPER
% =====================================================================
function s = ternary(cond, a, b)
    if cond
        s = a;
    else
        s = b;
    end
end
