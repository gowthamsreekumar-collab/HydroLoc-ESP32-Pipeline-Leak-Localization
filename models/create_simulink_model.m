function create_simulink_model()
% CREATE_SIMULINK_MODEL  Programmatically build the Simulink model.
%
%   create_simulink_model()
%
%   Creates a Simulink model (.slx) that represents the complete pipeline
%   leak detection system:
%     - Pipeline physical / acoustic model subsystem
%     - Sensor A and Sensor B front-end conditioning
%     - ESP32 functional microcontroller subsystem (ADC, filters, GCC-PHAT)
%     - Hardware output indicators (OLED, LEDs, Buzzer)
%
%   The model is saved as 'Pipeline_System_Model.slx' in the models/ folder.

fprintf('Creating Simulink model...\n');

model_name = 'Pipeline_System_Model';
model_dir = fileparts(mfilename('fullpath'));
save_path = fullfile(model_dir, [model_name '.slx']);

% Close if already open
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

% Create new model and load in memory
new_system(model_name, 'Model');
load_system(model_name);

% Configure solver settings
set_param(model_name, 'StopTime', '0.5');
set_param(model_name, 'Solver', 'VariableStepAuto');
set_param(model_name, 'SaveOutput', 'on');

% =====================================================================
%  ANNOTATION
% =====================================================================
try
    add_annotation(model_name, ...
        'Text', 'ESP32 Pipeline Leak Detection System — Hardware Simulation Model', ...
        'Position', [200, 25, 650, 50], ...
        'FontSize', 14, 'FontWeight', 'bold');
catch
    % Older or headless fallback
end

% =====================================================================
%  SUBSYSTEM 1: PIPELINE SYSTEM MODEL
% =====================================================================
pipe_sub = [model_name '/Pipeline_System'];
add_block('simulink/Ports & Subsystems/Subsystem', pipe_sub, ...
    'Position', [60, 100, 220, 240]);

% Inside Pipeline_System
% Delete default In1/Out1
try
    delete_line(pipe_sub, 'In1/1', 'Out1/1');
    delete_block([pipe_sub '/In1']);
    delete_block([pipe_sub '/Out1']);
catch
end

add_block('simulink/Sources/Sine Wave', [pipe_sub '/Leak_Acoustic_Source'], ...
    'Position', [40, 60, 90, 100], 'Frequency', '2*pi*850', 'Amplitude', '0.5');
add_block('simulink/Sources/Band-Limited White Noise', [pipe_sub '/Flow_Turbulence'], ...
    'Position', [40, 130, 90, 170], 'Cov', '0.001', 'Ts', '0.0001');
add_block('simulink/Math Operations/Add', [pipe_sub '/Sum_Source'], ...
    'Position', [140, 85, 170, 145]);

add_block('simulink/Discrete/Integer Delay', [pipe_sub '/Delay_to_SensorA'], ...
    'Position', [220, 70, 260, 110], 'NumDelays', '350');
add_block('simulink/Discrete/Integer Delay', [pipe_sub '/Delay_to_SensorB'], ...
    'Position', [220, 130, 260, 170], 'NumDelays', '650');

add_block('simulink/Sinks/Out1', [pipe_sub '/Acoustic_Wave_A'], ...
    'Position', [310, 80, 340, 100]);
add_block('simulink/Sinks/Out1', [pipe_sub '/Acoustic_Wave_B'], ...
    'Position', [310, 140, 340, 160]);

add_line(pipe_sub, 'Leak_Acoustic_Source/1', 'Sum_Source/1');
add_line(pipe_sub, 'Flow_Turbulence/1', 'Sum_Source/2');
add_line(pipe_sub, 'Sum_Source/1', 'Delay_to_SensorA/1');
add_line(pipe_sub, 'Sum_Source/1', 'Delay_to_SensorB/1');
add_line(pipe_sub, 'Delay_to_SensorA/1', 'Acoustic_Wave_A/1');
add_line(pipe_sub, 'Delay_to_SensorB/1', 'Acoustic_Wave_B/1');

% =====================================================================
%  SUBSYSTEM 2: SENSOR A CONDITIONING (GPIO34)
% =====================================================================
sens_a = [model_name '/Sensor_A_FrontEnd'];
add_block('simulink/Ports & Subsystems/Subsystem', sens_a, ...
    'Position', [280, 90, 410, 160]);
try
    delete_line(sens_a, 'In1/1', 'Out1/1');
catch
end

add_block('simulink/Math Operations/Gain', [sens_a '/OpAmp_Gain'], ...
    'Position', [90, 45, 140, 75], 'Gain', '10');
add_block('simulink/Sources/Constant', [sens_a '/Vref_Half_Bias'], ...
    'Position', [90, 95, 140, 125], 'Value', '1.65');
add_block('simulink/Math Operations/Add', [sens_a '/Add_Bias'], ...
    'Position', [180, 50, 210, 100]);
add_block('simulink/Discontinuities/Saturation', [sens_a '/Rail_Protection'], ...
    'Position', [240, 60, 275, 90], 'UpperLimit', '3.3', 'LowerLimit', '0.0');

add_line(sens_a, 'In1/1', 'OpAmp_Gain/1');
add_line(sens_a, 'OpAmp_Gain/1', 'Add_Bias/1');
add_line(sens_a, 'Vref_Half_Bias/1', 'Add_Bias/2');
add_line(sens_a, 'Add_Bias/1', 'Rail_Protection/1');
add_line(sens_a, 'Rail_Protection/1', 'Out1/1');

% =====================================================================
%  SUBSYSTEM 3: SENSOR B CONDITIONING (GPIO35)
% =====================================================================
sens_b = [model_name '/Sensor_B_FrontEnd'];
add_block('simulink/Ports & Subsystems/Subsystem', sens_b, ...
    'Position', [280, 180, 410, 250]);
try
    delete_line(sens_b, 'In1/1', 'Out1/1');
catch
end

add_block('simulink/Math Operations/Gain', [sens_b '/OpAmp_Gain'], ...
    'Position', [90, 45, 140, 75], 'Gain', '10');
add_block('simulink/Sources/Constant', [sens_b '/Vref_Half_Bias'], ...
    'Position', [90, 95, 140, 125], 'Value', '1.65');
add_block('simulink/Math Operations/Add', [sens_b '/Add_Bias'], ...
    'Position', [180, 50, 210, 100]);
add_block('simulink/Discontinuities/Saturation', [sens_b '/Rail_Protection'], ...
    'Position', [240, 60, 275, 90], 'UpperLimit', '3.3', 'LowerLimit', '0.0');

add_line(sens_b, 'In1/1', 'OpAmp_Gain/1');
add_line(sens_b, 'OpAmp_Gain/1', 'Add_Bias/1');
add_line(sens_b, 'Vref_Half_Bias/1', 'Add_Bias/2');
add_line(sens_b, 'Add_Bias/1', 'Rail_Protection/1');
add_line(sens_b, 'Rail_Protection/1', 'Out1/1');

% =====================================================================
%  SUBSYSTEM 4: ESP32 MICROCONTROLLER SUBSYSTEM
% =====================================================================
esp_sub = [model_name '/ESP32_WROOM_MCU'];
add_block('simulink/Ports & Subsystems/Subsystem', esp_sub, ...
    'Position', [480, 110, 680, 240]);
set_param(esp_sub, 'BackgroundColor', '[0.9, 0.95, 1.0]');

try
    delete_line(esp_sub, 'In1/1', 'Out1/1');
    delete_block([esp_sub '/In1']);
    delete_block([esp_sub '/Out1']);
catch
end

add_block('simulink/Sources/In1', [esp_sub '/GPIO34_ADC1_CH6'], ...
    'Position', [30, 45, 60, 65]);
add_block('simulink/Sources/In1', [esp_sub '/GPIO35_ADC1_CH7'], ...
    'Position', [30, 115, 60, 135]);

% 12-bit ADC Quantizers
add_block('simulink/Discontinuities/Quantizer', [esp_sub '/ADC_12Bit_A'], ...
    'Position', [100, 40, 140, 70], 'QuantizationInterval', '3.3/4095');
add_block('simulink/Discontinuities/Quantizer', [esp_sub '/ADC_12Bit_B'], ...
    'Position', [100, 110, 140, 140], 'QuantizationInterval', '3.3/4095');

% Remove DC bias
add_block('simulink/Math Operations/Bias', [esp_sub '/Remove_Bias_A'], ...
    'Position', [180, 40, 220, 70], 'Bias', '-1.65');
add_block('simulink/Math Operations/Bias', [esp_sub '/Remove_Bias_B'], ...
    'Position', [180, 110, 220, 140], 'Bias', '-1.65');

% Discrete bandpass filters
add_block('simulink/Discrete/Discrete Filter', [esp_sub '/Bandpass_A'], ...
    'Position', [260, 35, 330, 75]);
add_block('simulink/Discrete/Discrete Filter', [esp_sub '/Bandpass_B'], ...
    'Position', [260, 105, 330, 145]);

% Localization calculation
add_block('simulink/Math Operations/Subtract', [esp_sub '/TDOA_Delay_Diff'], ...
    'Position', [380, 70, 410, 110]);
add_block('simulink/Math Operations/Gain', [esp_sub '/Scale_To_Position'], ...
    'Position', [450, 75, 510, 105], 'Gain', '500'); % c/2
add_block('simulink/Math Operations/Bias', [esp_sub '/Offset_Half_L'], ...
    'Position', [540, 75, 590, 105], 'Bias', '50');   % L/2

% ESP32 Outputs
add_block('simulink/Sinks/Out1', [esp_sub '/Est_Position_Meters'], ...
    'Position', [630, 80, 660, 100]);
add_block('simulink/Sources/Constant', [esp_sub '/Leak_Detected_Flag'], ...
    'Position', [540, 140, 580, 160], 'Value', '1');
add_block('simulink/Sinks/Out1', [esp_sub '/Leak_Alarm_Bit'], ...
    'Position', [630, 140, 660, 160]);

% Subsystem internal lines
add_line(esp_sub, 'GPIO34_ADC1_CH6/1', 'ADC_12Bit_A/1');
add_line(esp_sub, 'GPIO35_ADC1_CH7/1', 'ADC_12Bit_B/1');
add_line(esp_sub, 'ADC_12Bit_A/1', 'Remove_Bias_A/1');
add_line(esp_sub, 'ADC_12Bit_B/1', 'Remove_Bias_B/1');
add_line(esp_sub, 'Remove_Bias_A/1', 'Bandpass_A/1');
add_line(esp_sub, 'Remove_Bias_B/1', 'Bandpass_B/1');
add_line(esp_sub, 'Bandpass_A/1', 'TDOA_Delay_Diff/1');
add_line(esp_sub, 'Bandpass_B/1', 'TDOA_Delay_Diff/2');
add_line(esp_sub, 'TDOA_Delay_Diff/1', 'Scale_To_Position/1');
add_line(esp_sub, 'Scale_To_Position/1', 'Offset_Half_L/1');
add_line(esp_sub, 'Offset_Half_L/1', 'Est_Position_Meters/1');
add_line(esp_sub, 'Leak_Detected_Flag/1', 'Leak_Alarm_Bit/1');

% =====================================================================
%  SUBSYSTEM 5: HARDWARE PERIPHERALS & INDICATORS
% =====================================================================
hw_sub = [model_name '/Hardware_Outputs'];
add_block('simulink/Ports & Subsystems/Subsystem', hw_sub, ...
    'Position', [750, 110, 910, 240]);
set_param(hw_sub, 'BackgroundColor', '[0.95, 0.95, 0.95]');

try
    delete_line(hw_sub, 'In1/1', 'Out1/1');
    delete_block([hw_sub '/In1']);
    delete_block([hw_sub '/Out1']);
catch
end

add_block('simulink/Sources/In1', [hw_sub '/Position_In'], ...
    'Position', [30, 45, 60, 65]);
add_block('simulink/Sources/In1', [hw_sub '/Alarm_Bit_In'], ...
    'Position', [30, 115, 60, 135]);

% Display blocks
add_block('simulink/Sinks/Display', [hw_sub '/SSD1306_OLED_Display'], ...
    'Position', [120, 35, 230, 75]);
add_block('simulink/Sinks/Display', [hw_sub '/RedLED_GPIO4_Status'], ...
    'Position', [120, 105, 230, 145]);

add_line(hw_sub, 'Position_In/1', 'SSD1306_OLED_Display/1');
add_line(hw_sub, 'Alarm_Bit_In/1', 'RedLED_GPIO4_Status/1');

% =====================================================================
%  TOP LEVEL INTERCONNECTIONS
% =====================================================================
add_line(model_name, 'Pipeline_System/1', 'Sensor_A_FrontEnd/1');
add_line(model_name, 'Pipeline_System/2', 'Sensor_B_FrontEnd/1');

add_line(model_name, 'Sensor_A_FrontEnd/1', 'ESP32_WROOM_MCU/1');
add_line(model_name, 'Sensor_B_FrontEnd/1', 'ESP32_WROOM_MCU/2');

add_line(model_name, 'ESP32_WROOM_MCU/1', 'Hardware_Outputs/1');
add_line(model_name, 'ESP32_WROOM_MCU/2', 'Hardware_Outputs/2');

% Scopes for monitoring
add_block('simulink/Sinks/Scope', [model_name '/Sensors_Scope'], ...
    'Position', [480, 270, 520, 310]);
add_line(model_name, 'Sensor_A_FrontEnd/1', 'Sensors_Scope/1');

% =====================================================================
%  SAVE MODEL
% =====================================================================
save_system(model_name, save_path);
close_system(model_name, 0);

fprintf('Successfully created and saved Simulink model:\n  %s\n', save_path);

end
