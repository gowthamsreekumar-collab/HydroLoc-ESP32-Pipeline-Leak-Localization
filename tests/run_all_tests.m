function run_all_tests(save_results)
% RUN_ALL_TESTS  Execute all 10 test cases for the leak detection system.
%
%   run_all_tests()
%   run_all_tests(true)   % Save results to CSV
%
%   Runs 10 pre-defined test scenarios, processes signals through the
%   complete ESP32 subsystem model, and reports detection accuracy,
%   localization errors, and algorithm performance.
%
%   TEST CASES:
%     1.  No leakage (baseline)
%     2.  Leak near Sensor A (5% of L)
%     3.  Leak near Sensor B (95% of L)
%     4.  Leak at pipeline midpoint (50% of L)
%     5.  Leak at unknown intermediate position (37% of L)
%     6.  Small leak (severity = 0.1)
%     7.  Medium leak (severity = 0.5)
%     8.  Large leak (severity = 1.0)
%     9.  Leak with high background noise
%     10. Leak with sensor sensitivity mismatch
%
%   For every test, the function reports:
%     - Sensor A and B signals (generated, not hardcoded)
%     - Estimated TDOA from GCC-PHAT
%     - Estimated leak position from TDOA localization
%     - True leak position
%     - Localization error (absolute and percentage)
%     - Detection status (leak / no leak)

if nargin < 1
    save_results = true;
end

% Add algorithm directories to path
project_dir = fileparts(mfilename('fullpath'));
parent_dir  = fileparts(project_dir);
addpath(fullfile(parent_dir, 'algorithms'));
addpath(fullfile(parent_dir, 'hardware_model'));

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║   ESP32 PIPELINE LEAK DETECTION — COMPREHENSIVE TEST SUITE  ║\n');
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║   Algorithm: GCC-PHAT with TDOA Localization               ║\n');
fprintf('║   Equation:  x = (L + c·Δt) / 2                           ║\n');
fprintf('║   Date:      %s                              ║\n', datestr(now, 'yyyy-mm-dd HH:MM'));
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

% =====================================================================
%  SYSTEM PARAMETERS
% =====================================================================
L   = 100;      % Pipeline length (m)
c   = 1000;     % Propagation speed (m/s)
fs  = 10000;    % Sampling rate (Hz)
T   = 0.5;      % Signal duration (s)
det_thresh = 3.0; % Detection threshold

fprintf('System Parameters:\n');
fprintf('  Pipeline Length:     %.0f m\n', L);
fprintf('  Propagation Speed:  %.0f m/s\n', c);
fprintf('  Sampling Rate:      %d Hz\n', fs);
fprintf('  Signal Duration:    %.1f s\n', T);
fprintf('  Detection Threshold: %.1f (energy ratio)\n', det_thresh);
fprintf('  Spatial Resolution:  ~%.3f m (Nyquist limit)\n', c / (2*fs));
fprintf('\n');

% =====================================================================
%  DEFINE TEST CASES
% =====================================================================
tests = {
%   Name                          leak_pos   severity  noise   sensA  sensB  seed
    'No Leakage (baseline)'       L*0.50     0.00      0.02    1.0    1.0    101
    'Leak near Sensor A'          L*0.05     0.50      0.02    1.0    1.0    102
    'Leak near Sensor B'          L*0.95     0.50      0.02    1.0    1.0    103
    'Leak at Midpoint'            L*0.50     0.50      0.02    1.0    1.0    104
    'Leak at Unknown Position'    L*0.37     0.50      0.02    1.0    1.0    105
    'Small Leak'                  L*0.40     0.10      0.02    1.0    1.0    106
    'Medium Leak'                 L*0.40     0.50      0.02    1.0    1.0    107
    'Large Leak'                  L*0.40     1.00      0.02    1.0    1.0    108
    'Leak with High Noise'        L*0.35     0.50      0.20    1.0    1.0    109
    'Sensor Sensitivity Mismatch' L*0.35     0.50      0.05    0.7    1.3    110
};

n_tests = size(tests, 1);

% =====================================================================
%  RESULTS STORAGE
% =====================================================================
TestCase       = cell(n_tests, 1);
TruePosition   = zeros(n_tests, 1);
EstPosition    = zeros(n_tests, 1);
AbsError       = zeros(n_tests, 1);
ErrorPercent   = zeros(n_tests, 1);
TrueTDOA_ms    = zeros(n_tests, 1);
EstTDOA_ms     = zeros(n_tests, 1);
TDOAError_ms   = zeros(n_tests, 1);
LeakDetected   = false(n_tests, 1);
CorrectDetect  = false(n_tests, 1);
EnergyRatio    = zeros(n_tests, 1);
Severity       = zeros(n_tests, 1);
NoiseLevel     = zeros(n_tests, 1);

% =====================================================================
%  RUN TESTS
% =====================================================================
fprintf('Running %d test cases...\n\n', n_tests);

for i = 1:n_tests
    tc_name = tests{i, 1};
    tc_pos  = tests{i, 2};
    tc_sev  = tests{i, 3};
    tc_noi  = tests{i, 4};
    tc_sA   = tests{i, 5};
    tc_sB   = tests{i, 6};
    tc_seed = tests{i, 7};
    
    fprintf('── Test %2d: %s ──\n', i, tc_name);
    
    % --- Generate signals ---
    params = struct();
    params.pipeline_length      = L;
    params.leak_position        = tc_pos;
    params.propagation_speed    = c;
    params.sampling_rate        = fs;
    params.duration             = T;
    params.leak_severity        = tc_sev;
    params.noise_level          = tc_noi;
    params.sensor_sensitivity_A = tc_sA;
    params.sensor_sensitivity_B = tc_sB;
    params.random_seed          = tc_seed;
    
    [sig_A, sig_B, t, true_tdoa, ~] = leak_signal_model(params);
    
    % --- Process through ESP32 subsystem ---
    sys_params = struct();
    sys_params.pipeline_length     = L;
    sys_params.propagation_speed   = c;
    sys_params.sampling_rate       = fs;
    sys_params.detection_threshold = det_thresh;
    sys_params.true_leak_position  = tc_pos;
    
    results = esp32_subsystem(sig_A, sig_B, sys_params);
    
    % --- Determine ground truth detection ---
    should_detect = tc_sev > 0;
    
    % --- Store results ---
    TestCase{i}       = tc_name;
    TruePosition(i)   = tc_pos;
    EstPosition(i)    = results.estimated_position;
    AbsError(i)       = results.localization_error;
    ErrorPercent(i)   = results.localization_error / L * 100;
    TrueTDOA_ms(i)    = true_tdoa * 1000;
    EstTDOA_ms(i)     = results.estimated_tdoa * 1000;
    TDOAError_ms(i)   = abs(results.estimated_tdoa - true_tdoa) * 1000;
    LeakDetected(i)   = results.leak_detected;
    CorrectDetect(i)  = (results.leak_detected == should_detect);
    EnergyRatio(i)    = results.energy_ratio;
    Severity(i)       = tc_sev;
    NoiseLevel(i)     = tc_noi;
    
    % --- Print individual test result ---
    fprintf('  Severity:     %.2f   |  Noise: %.3f\n', tc_sev, tc_noi);
    fprintf('  True TDOA:    %+.4f ms\n', TrueTDOA_ms(i));
    fprintf('  Est. TDOA:    %+.4f ms\n', EstTDOA_ms(i));
    fprintf('  TDOA Error:   %.4f ms\n', TDOAError_ms(i));
    fprintf('  True Pos:     %.2f m\n', TruePosition(i));
    fprintf('  Est. Pos:     %.2f m\n', EstPosition(i));
    fprintf('  Loc. Error:   %.2f m (%.2f%%)\n', AbsError(i), ErrorPercent(i));
    
    if CorrectDetect(i)
        fprintf('  Detection:    %s ✓ (correct)\n', ...
            ternary(LeakDetected(i), 'LEAK', 'NORMAL'));
    else
        fprintf('  Detection:    %s ✗ (INCORRECT — expected %s)\n', ...
            ternary(LeakDetected(i), 'LEAK', 'NORMAL'), ...
            ternary(should_detect, 'LEAK', 'NORMAL'));
    end
    fprintf('\n');
end

% =====================================================================
%  SUMMARY TABLE
% =====================================================================
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                SUMMARY OF ALL TEST RESULTS                              ║\n');
fprintf('╠════╤═══════════════════════════════╤═════════╤═════════╤════════╤═════════╤═════════════╣\n');
fprintf('║ #  │ Test Case                     │ True(m) │ Est(m)  │ Err(m) │ Err(%%)  │ Detected    ║\n');
fprintf('╠════╪═══════════════════════════════╪═════════╪═════════╪════════╪═════════╪═════════════╣\n');

for i = 1:n_tests
    det_str = ternary(LeakDetected(i), 'YES', 'NO ');
    correct_str = ternary(CorrectDetect(i), ' ✓', ' ✗');
    fprintf('║ %2d │ %-29s │ %6.1f  │ %6.1f  │ %5.2f  │ %5.1f%%  │ %s%s       ║\n', ...
        i, TestCase{i}, TruePosition(i), EstPosition(i), ...
        AbsError(i), ErrorPercent(i), det_str, correct_str);
end

fprintf('╠════╧═══════════════════════════════╧═════════╧═════════╧════════╧═════════╧═════════════╣\n');

% Statistics (exclude no-leak test for localization metrics)
leak_tests = Severity > 0;
if any(leak_tests)
    mean_err = mean(AbsError(leak_tests));
    max_err  = max(AbsError(leak_tests));
    median_err = median(AbsError(leak_tests));
    correct_rate = sum(CorrectDetect) / n_tests * 100;
    
    fprintf('║  Mean Loc. Error (leak tests):  %.2f m  (%.2f%%)                                     ║\n', ...
        mean_err, mean_err/L*100);
    fprintf('║  Max Loc. Error:                %.2f m  (%.2f%%)                                     ║\n', ...
        max_err, max_err/L*100);
    fprintf('║  Median Loc. Error:             %.2f m  (%.2f%%)                                     ║\n', ...
        median_err, median_err/L*100);
    fprintf('║  Detection Accuracy:            %.0f%% (%d/%d correct)                                ║\n', ...
        correct_rate, sum(CorrectDetect), n_tests);
end
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════╝\n');

% =====================================================================
%  SAVE RESULTS TO CSV
% =====================================================================
if save_results
    results_table = table(TestCase, Severity, NoiseLevel, ...
        TruePosition, EstPosition, AbsError, ErrorPercent, ...
        TrueTDOA_ms, EstTDOA_ms, TDOAError_ms, ...
        LeakDetected, CorrectDetect, EnergyRatio, ...
        'VariableNames', {'TestCase', 'Severity', 'Noise', ...
        'TruePosition_m', 'EstPosition_m', 'AbsError_m', 'ErrorPercent', ...
        'TrueTDOA_ms', 'EstTDOA_ms', 'TDOAError_ms', ...
        'LeakDetected', 'CorrectDetection', 'EnergyRatio'});
    
    results_dir = fullfile(parent_dir, 'results');
    if ~exist(results_dir, 'dir')
        mkdir(results_dir);
    end
    csv_path = fullfile(results_dir, 'test_results.csv');
    writetable(results_table, csv_path);
    fprintf('\nResults saved to: %s\n', csv_path);
    
    % Also display the table
    fprintf('\nMATLAB Table:\n');
    disp(results_table);
end

% =====================================================================
%  GENERATE SUMMARY FIGURE
% =====================================================================
fig = figure('Name', 'Test Results Summary', ...
    'Position', [100 100 1200 800], 'Color', 'white');

% Localization error bar chart
subplot(2,2,1);
bar_colors = zeros(n_tests, 3);
for i = 1:n_tests
    if CorrectDetect(i)
        bar_colors(i,:) = [0.2 0.7 0.3];
    else
        bar_colors(i,:) = [0.9 0.2 0.2];
    end
end
b = bar(AbsError);
b.FaceColor = 'flat';
b.CData = bar_colors;
xlabel('Test Case #');
ylabel('Localization Error (m)');
title('Localization Error by Test Case');
set(gca, 'XTick', 1:n_tests);
grid on;

% True vs Estimated position scatter
subplot(2,2,2);
scatter(TruePosition, EstPosition, 80, Severity, 'filled');
hold on;
plot([0 L], [0 L], 'r--', 'LineWidth', 1.5);
xlabel('True Position (m)');
ylabel('Estimated Position (m)');
title('True vs Estimated Leak Position');
colorbar; colormap(gca, 'parula');
c_label = ylabel(colorbar, 'Severity');
legend('Test points', 'Perfect accuracy', 'Location', 'northwest');
grid on;
axis equal;
xlim([0 L]); ylim([0 L]);

% Error vs Severity
subplot(2,2,3);
scatter(Severity(leak_tests), AbsError(leak_tests), 80, ...
    NoiseLevel(leak_tests), 'filled', 'MarkerEdgeColor', 'k');
xlabel('Leak Severity');
ylabel('Localization Error (m)');
title('Error vs Leak Severity');
colorbar; ylabel(colorbar, 'Noise Level');
grid on;

% Energy ratio vs detection threshold
subplot(2,2,4);
bar(EnergyRatio);
hold on;
yline(det_thresh, 'r--', 'LineWidth', 2, 'Label', 'Threshold');
xlabel('Test Case #');
ylabel('Energy Ratio');
title('Energy Ratio vs Detection Threshold');
set(gca, 'XTick', 1:n_tests);
grid on;

sgtitle('ESP32 Pipeline Leak Detection — Test Results Summary', 'FontSize', 14, 'FontWeight', 'bold');

% Save figure
fig_path = fullfile(parent_dir, 'results', 'test_results_summary.png');
exportgraphics(fig, fig_path, 'Resolution', 150);
fprintf('Summary figure saved to: %s\n', fig_path);

end

% =====================================================================
%  HELPER
% =====================================================================
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
