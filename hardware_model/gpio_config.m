function config = gpio_config()
% GPIO_CONFIG  ESP32-WROOM-32 GPIO pin assignment configuration.
%
%   config = gpio_config()
%
%   Returns a structure containing all GPIO pin assignments, electrical
%   parameters, and interface specifications for the ESP32-based pipeline
%   leak detection system.
%
%   Pin Selection Rationale:
%     - GPIO34/35: Input-only pins with dedicated ADC1 channels.
%       Chosen for sensor analog inputs to avoid conflicts with
%       boot-strapping pins and to use the more stable ADC1 peripheral.
%     - GPIO21/22: Default I2C (SDA/SCL) for SSD1306 OLED display.
%     - GPIO2/4/5: Safe digital output pins that do not affect boot
%       sequence. GPIO5 supports LEDC PWM for buzzer tone generation.
%
%   Voltage Compatibility:
%     - ESP32 operates at 3.3 V logic. All sensors and the OLED must be
%       3.3 V compatible or use level shifters.
%     - LEDs require 220-ohm current-limiting resistors at 3.3 V.
%     - Piezo buzzer driven via PWM (LEDC) at 2 kHz, 3.3 V output.
%
%   Reference: ESP32-WROOM-32 Technical Reference Manual (Espressif)

% =========================================================================
%  SENSOR INPUT PINS (ADC)
% =========================================================================
config.SENSOR_A_PIN       = 34;          % GPIO34 — ADC1_CH6 (input only)
config.SENSOR_A_ADC_CH    = 'ADC1_CH6';
config.SENSOR_B_PIN       = 35;          % GPIO35 — ADC1_CH7 (input only)
config.SENSOR_B_ADC_CH    = 'ADC1_CH7';

% =========================================================================
%  I2C — OLED DISPLAY (SSD1306, 128x64 px)
% =========================================================================
config.I2C_SDA            = 21;          % GPIO21 — I2C Data
config.I2C_SCL            = 22;          % GPIO22 — I2C Clock
config.OLED_I2C_ADDR      = '0x3C';      % Default I2C address for SSD1306
config.OLED_WIDTH_PX      = 128;
config.OLED_HEIGHT_PX     = 64;

% =========================================================================
%  LED INDICATORS
% =========================================================================
config.LED_GREEN_PIN      = 2;           % GPIO2  — Normal-operation LED
config.LED_RED_PIN        = 4;           % GPIO4  — Leak-detected LED

% =========================================================================
%  PIEZO BUZZER
% =========================================================================
config.BUZZER_PIN         = 5;           % GPIO5  — PWM output to buzzer
config.BUZZER_FREQ_HZ     = 2000;        % Alarm tone frequency (Hz)
config.BUZZER_LEDC_CH     = 0;           % LEDC PWM channel number

% =========================================================================
%  ADC CONFIGURATION
% =========================================================================
config.ADC_RESOLUTION_BITS = 12;         % 12-bit resolution
config.ADC_MAX_CODE        = 4095;       % 2^12 − 1
config.ADC_VREF_V          = 3.3;        % ADC reference voltage (V)
config.ADC_ATTENUATION     = '11dB';     % 0–3.6 V input range

% =========================================================================
%  SAMPLING
% =========================================================================
config.SAMPLING_RATE_HZ   = 10000;       % 10 kHz per channel
config.SAMPLES_PER_FRAME  = 4096;        % Samples per acquisition frame

% =========================================================================
%  SERIAL / UART (USB Monitor)
% =========================================================================
config.SERIAL_BAUD        = 115200;
config.SERIAL_TX_PIN      = 1;           % GPIO1  — UART0 TX
config.SERIAL_RX_PIN      = 3;           % GPIO3  — UART0 RX

% =========================================================================
%  POWER SUPPLY
% =========================================================================
config.VCC_V              = 3.3;         % ESP32 operating voltage
config.VIN_V              = 5.0;         % USB / external supply input
config.LED_RESISTOR_OHM   = 220;         % Current-limiting for LEDs
config.LED_CURRENT_MA      = (3.3 - 2.0) / 220 * 1000;  % ~5.9 mA typical

% =========================================================================
%  PIN DESCRIPTION TABLE (for documentation and diagram labels)
% =========================================================================
config.PinTable = table( ...
    [34; 35; 21; 22; 2; 4; 5; 1; 3], ...
    {'GPIO34'; 'GPIO35'; 'GPIO21'; 'GPIO22'; ...
     'GPIO2'; 'GPIO4'; 'GPIO5'; 'GPIO1'; 'GPIO3'}, ...
    {'Sensor A Analog In (ADC1_CH6)'; ...
     'Sensor B Analog In (ADC1_CH7)'; ...
     'I2C SDA — OLED Display'; ...
     'I2C SCL — OLED Display'; ...
     'Green LED — Normal Operation'; ...
     'Red LED — Leak Detected'; ...
     'Piezo Buzzer — PWM Alarm'; ...
     'UART TX — Serial Monitor'; ...
     'UART RX — Serial Monitor'}, ...
    {'Input'; 'Input'; 'I2C'; 'I2C'; ...
     'Output'; 'Output'; 'PWM Out'; 'Output'; 'Input'}, ...
    {'Analog'; 'Analog'; 'Digital'; 'Digital'; ...
     'Digital'; 'Digital'; 'Digital'; 'Digital'; 'Digital'}, ...
    'VariableNames', {'PinNumber', 'PinName', 'Description', ...
                      'Direction', 'SignalType'});

end
