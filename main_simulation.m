2% MAIN_SIMULATION  Master launch script for the ESP32 Pipeline Leak Detection project.
%
%   This script initialises the project, adds required directories to the
%   MATLAB path, verifies toolbox availability, and launches the
%   interactive simulation GUI.
%
%   USAGE:
%     >> main_simulation
%
%   MODES:
%     1. Interactive GUI        — Full hardware-oriented simulation
%     2. Command-line tests     — Run all 10 test cases
%     3. Circuit diagram        — Generate hardware connection diagram
%     4. Simulink model         — Build the Simulink/Simscape model
%
%   PROJECT STRUCTURE:
%     ESP32_Pipeline_Leak_Detection/
%     ├── main_simulation.m          ← THIS FILE
%     ├── PipelineLeakDetectionApp.m ← Interactive GUI
%     ├── algorithms/                ← Core signal processing
%     ├── hardware_model/            ← ESP32, OLED, GPIO models
%     ├── models/                    ← Simulink model
%     ├── diagrams/                  ← Circuit & block diagrams
%     ├── tests/                     ← Test cases
%     ├── results/                   ← Auto-generated outputs
%     └── docs/                      ← Documentation

clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                                                ║\n');
fprintf('║   ESP32 PIPELINE LEAK DETECTION AND LOCALIZATION SYSTEM       ║\n');
fprintf('║   Hardware-Level Simulation                                    ║\n');
fprintf('║                                                                ║\n');
fprintf('║   Algorithm:  GCC-PHAT + Two-Sensor TDOA                      ║\n');
fprintf('║   Target MCU: ESP32-WROOM-32 (Functional Model)               ║\n');
fprintf('║   Sensors:    2× Acoustic/Vibration (ADC1_CH6, ADC1_CH7)      ║\n');
fprintf('║   Outputs:    OLED (I2C), 2× LED, Piezo Buzzer, Serial       ║\n');
fprintf('║                                                                ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

% =====================================================================
%  PROJECT PATH SETUP
% =====================================================================
project_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(project_dir, 'algorithms'));
addpath(fullfile(project_dir, 'hardware_model'));
addpath(fullfile(project_dir, 'models'));
addpath(fullfile(project_dir, 'diagrams'));
addpath(fullfile(project_dir, 'tests'));

fprintf('Project directory: %s\n', project_dir);
fprintf('MATLAB paths added.\n\n');

% =====================================================================
%  TOOLBOX VERIFICATION
% =====================================================================
fprintf('Checking installed toolboxes...\n');
required = {'MATLAB', 'Simulink'};
recommended = {'Signal Processing Toolbox', 'DSP System Toolbox', ...
               'Simscape', 'Simscape Electrical', 'Simscape Fluids'};

v = ver;
installed_names = {v.Name};

fprintf('\n  Required:\n');
for i = 1:length(required)
    found = any(contains(installed_names, required{i}));
    if found
        fprintf('    ✓ %s\n', required{i});
    else
        fprintf('    ✗ %s  *** MISSING ***\n', required{i});
    end
end

fprintf('\n  Recommended:\n');
for i = 1:length(recommended)
    found = any(contains(installed_names, recommended{i}));
    if found
        fprintf('    ✓ %s\n', recommended{i});
    else
        fprintf('    ○ %s  (not installed — fallback will be used)\n', recommended{i});
    end
end

% =====================================================================
%  GPIO CONFIGURATION SUMMARY
% =====================================================================
fprintf('\n');
fprintf('ESP32 GPIO Pin Assignments:\n');
config = gpio_config();
disp(config.PinTable);

% =====================================================================
%  LAUNCH MODE SELECTION
% =====================================================================
fprintf('\n');
fprintf('══════════════════════════════════════════════\n');
fprintf('  Select Operation Mode:\n');
fprintf('══════════════════════════════════════════════\n');
fprintf('  1 — Launch Interactive GUI Simulation\n');
fprintf('  2 — Run All 10 Test Cases (command-line)\n');
fprintf('  3 — Generate Circuit Diagram\n');
fprintf('  4 — Build Simulink Model\n');
fprintf('  5 — Quick Single Test (command-line)\n');
fprintf('  0 — Exit\n');
fprintf('══════════════════════════════════════════════\n');
fprintf('\n');

mode = input('Enter mode (1–5, or 0 to exit): ');

switch mode
    case 1
        % --- INTERACTIVE GUI ---
        fprintf('\nLaunching interactive simulation GUI...\n');
        app = PipelineLeakDetectionApp();
        fprintf('GUI launched. Use the controls to run simulations.\n');
        
    case 2
        % --- ALL TEST CASES ---
        fprintf('\nRunning all 10 test cases...\n');
        run_all_tests(true);
        
    case 3
        % --- CIRCUIT DIAGRAM ---
        fprintf('\nGenerating circuit diagram...\n');
        save_path = fullfile(project_dir, 'results', 'circuit_diagram.png');
        circuit_diagram(save_path);
        fprintf('Circuit diagram saved.\n');
        
    case 4
        % --- SIMULINK MODEL ---
        fprintf('\nBuilding Simulink model...\n');
        cd(fullfile(project_dir, 'models'));
        create_simulink_model();
        cd(project_dir);
        fprintf('Simulink model created.\n');
        
    case 5
        % --- QUICK SINGLE TEST ---
        fprintf('\n--- Quick Single Test ---\n');
        fprintf('Using default parameters:\n');
        fprintf('  Pipeline: 100 m, Leak at 35 m, Severity 0.5\n');
        fprintf('  Speed: 1000 m/s, Noise: 0.02\n\n');
        
        params = struct();
        params.pipeline_length      = 100;
        params.leak_position        = 35;
        params.propagation_speed    = 1000;
        params.sampling_rate        = 10000;
        params.duration             = 0.5;
        params.leak_severity        = 0.5;
        params.noise_level          = 0.02;
        params.sensor_sensitivity_A = 1.0;
        params.sensor_sensitivity_B = 1.0;
        params.random_seed          = 42;
        
        [sig_A, sig_B, t, true_tdoa, ~] = leak_signal_model(params);
        
        sys_p = struct();
        sys_p.pipeline_length     = 100;
        sys_p.propagation_speed   = 1000;
        sys_p.sampling_rate       = 10000;
        sys_p.detection_threshold = 3.0;
        sys_p.true_leak_position  = 35;
        
        results = esp32_subsystem(sig_A, sig_B, sys_p);
        
        fprintf('\n--- RESULTS ---\n');
        for j = 1:length(results.serial_log)
            fprintf('%s\n', results.serial_log{j});
        end
        
        % Plot
        figure('Name', 'Quick Test Results', 'Position', [100 100 1000 700]);
        subplot(3,1,1);
        plot(t*1000, sig_A, 'b'); title('Sensor A (GPIO34)');
        xlabel('Time (ms)'); ylabel('Amplitude'); grid on;
        subplot(3,1,2);
        plot(t*1000, sig_B, 'r'); title('Sensor B (GPIO35)');
        xlabel('Time (ms)'); ylabel('Amplitude'); grid on;
        subplot(3,1,3);
        plot(results.gcc_lags*1000, results.gcc_correlation, 'g', 'LineWidth', 1.5);
        title('GCC-PHAT Cross-Correlation');
        xlabel('Lag (ms)'); ylabel('Correlation'); grid on;
        hold on;
        [~, pk] = max(results.gcc_correlation);
        plot(results.gcc_lags(pk)*1000, results.gcc_correlation(pk), 'rv', ...
            'MarkerSize', 12, 'MarkerFaceColor', 'r');
        legend('GCC-PHAT', sprintf('Peak: \\Deltat = %.3f ms', results.estimated_tdoa*1000));
        
    case 0
        fprintf('Exiting.\n');
        return;
        
    otherwise
        fprintf('Invalid selection.\n');
end

fprintf('\n✓ Done.\n');
