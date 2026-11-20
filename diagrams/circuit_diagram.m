function circuit_diagram(save_path)
% CIRCUIT_DIAGRAM  Generate a detailed hardware connection diagram.
%
%   circuit_diagram()
%   circuit_diagram(save_path)
%
%   Draws a professional circuit/wiring diagram showing all connections
%   between the ESP32 development board and peripheral components:
%     - Sensor A (acoustic/vibration) → GPIO34
%     - Sensor B (acoustic/vibration) → GPIO35
%     - SSD1306 OLED Display (I2C)    → GPIO21, GPIO22
%     - Green LED + 220Ω resistor     → GPIO2
%     - Red LED + 220Ω resistor       → GPIO4
%     - Piezo Buzzer (PWM)            → GPIO5
%     - Power and ground connections
%
%   Each connection is labelled with the GPIO pin, signal type, and
%   voltage level. Components are drawn as simplified schematics.
%
%   INPUTS:
%     save_path — (Optional) File path to save the diagram as PNG.
%                 If omitted, the diagram is displayed on screen.

% =====================================================================
%  FIGURE SETUP
% =====================================================================
fig = figure('Name', 'ESP32 Pipeline Leak Detection — Circuit Diagram', ...
    'NumberTitle', 'off', ...
    'Color', 'white', ...
    'Position', [50 50 1400 900], ...
    'MenuBar', 'none', ...
    'ToolBar', 'none');

ax = axes(fig, 'Position', [0 0 1 1]);
hold(ax, 'on');
set(ax, 'XLim', [0 140], 'YLim', [0 90], ...
    'XTick', [], 'YTick', [], ...
    'Color', 'white', 'Box', 'off');
axis(ax, 'equal');

% =====================================================================
%  TITLE
% =====================================================================
text(ax, 70, 88, 'ESP32 Pipeline Leak Detection System — Hardware Connection Diagram', ...
    'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
    'Color', [0.1 0.1 0.4]);
text(ax, 70, 85.5, 'All connections at 3.3V logic level  |  Power: 5V USB or external supply', ...
    'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.4 0.4 0.4]);

% =====================================================================
%  ESP32 DEVELOPMENT BOARD (centre)
% =====================================================================
esp_x = 50; esp_y = 30; esp_w = 30; esp_h = 40;
rectangle(ax, 'Position', [esp_x, esp_y, esp_w, esp_h], ...
    'Curvature', 0.05, 'FaceColor', [0.2 0.3 0.5], ...
    'EdgeColor', [0.1 0.1 0.3], 'LineWidth', 2);

% ESP32 label
text(ax, esp_x + esp_w/2, esp_y + esp_h - 4, 'ESP32-WROOM-32', ...
    'FontSize', 12, 'FontWeight', 'bold', 'Color', 'white', ...
    'HorizontalAlignment', 'center');
text(ax, esp_x + esp_w/2, esp_y + esp_h - 7.5, 'DevKit V1', ...
    'FontSize', 9, 'Color', [0.7 0.8 1], 'HorizontalAlignment', 'center');

% USB connector at bottom
rectangle(ax, 'Position', [esp_x + esp_w/2 - 3, esp_y - 2, 6, 3], ...
    'Curvature', 0.2, 'FaceColor', [0.6 0.6 0.6], ...
    'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 1.5);
text(ax, esp_x + esp_w/2, esp_y - 0.5, 'USB', ...
    'FontSize', 7, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% Antenna
rectangle(ax, 'Position', [esp_x + esp_w/2 - 5, esp_y + esp_h, 10, 3], ...
    'Curvature', 0.3, 'FaceColor', [0.85 0.75 0.5], ...
    'EdgeColor', [0.5 0.4 0.2], 'LineWidth', 1);
text(ax, esp_x + esp_w/2, esp_y + esp_h + 1.5, 'ANTENNA', ...
    'FontSize', 6, 'HorizontalAlignment', 'center', 'Color', [0.3 0.2 0.1]);

% ---- Pin labels on ESP32 (Left side) ----
left_pins = {'3V3', 'GND', 'GPIO34', 'GPIO35', 'GPIO21', 'GPIO22'};
left_y_positions = [esp_y + 33, esp_y + 29, esp_y + 23, esp_y + 19, esp_y + 13, esp_y + 9];
for i = 1:length(left_pins)
    % Pin dot
    plot(ax, esp_x, left_y_positions(i), 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', [1 0.8 0.2], 'MarkerEdgeColor', [0.4 0.3 0]);
    % Pin label inside board
    text(ax, esp_x + 1.5, left_y_positions(i), left_pins{i}, ...
        'FontSize', 7, 'FontName', 'Consolas', 'Color', [0.9 0.9 1], ...
        'VerticalAlignment', 'middle');
end

% ---- Pin labels on ESP32 (Right side) ----
right_pins = {'VIN(5V)', 'GND', 'GPIO2', 'GPIO4', 'GPIO5', 'TX0'};
right_y_positions = [esp_y + 33, esp_y + 29, esp_y + 23, esp_y + 19, esp_y + 13, esp_y + 9];
for i = 1:length(right_pins)
    plot(ax, esp_x + esp_w, right_y_positions(i), 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', [1 0.8 0.2], 'MarkerEdgeColor', [0.4 0.3 0]);
    text(ax, esp_x + esp_w - 1.5, right_y_positions(i), right_pins{i}, ...
        'FontSize', 7, 'FontName', 'Consolas', 'Color', [0.9 0.9 1], ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
end

% =====================================================================
%  SENSOR A (Left side, top)
% =====================================================================
sa_x = 8; sa_y = 58;
draw_sensor(ax, sa_x, sa_y, 'SENSOR A', 'Acoustic/Vibration', 'GPIO34 (ADC1_CH6)');
% Wire from Sensor A to GPIO34
draw_wire(ax, [sa_x + 18, esp_x], [sa_y + 2, left_y_positions(3)], [0.2 0.6 1], 'Analog Signal');

% =====================================================================
%  SENSOR B (Left side, bottom)
% =====================================================================
sb_x = 8; sb_y = 42;
draw_sensor(ax, sb_x, sb_y, 'SENSOR B', 'Acoustic/Vibration', 'GPIO35 (ADC1_CH7)');
% Wire from Sensor B to GPIO35
draw_wire(ax, [sb_x + 18, esp_x], [sb_y + 2, left_y_positions(4)], [0.2 0.6 1], 'Analog Signal');

% =====================================================================
%  OLED DISPLAY (Left side, bottom)
% =====================================================================
oled_x = 8; oled_y = 18;
rectangle(ax, 'Position', [oled_x, oled_y, 18, 14], ...
    'Curvature', 0.05, 'FaceColor', [0.05 0.05 0.05], ...
    'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 1.5);
% Display screen area
rectangle(ax, 'Position', [oled_x + 2, oled_y + 3, 14, 9], ...
    'Curvature', 0.02, 'FaceColor', [0 0.05 0.08], ...
    'EdgeColor', [0.15 0.15 0.15], 'LineWidth', 1);
text(ax, oled_x + 9, oled_y + 7.5, 'OLED', ...
    'FontSize', 8, 'FontWeight', 'bold', 'Color', [0 0.8 0.7], ...
    'HorizontalAlignment', 'center');
text(ax, oled_x + 9, oled_y + 5, '128×64 SSD1306', ...
    'FontSize', 6, 'Color', [0 0.6 0.5], 'HorizontalAlignment', 'center');
text(ax, oled_x + 9, oled_y + 1, 'I2C Addr: 0x3C', ...
    'FontSize', 6, 'Color', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');

% I2C wires
draw_wire(ax, [oled_x + 18, esp_x], [oled_y + 9, left_y_positions(5)], [0.8 0.4 1], 'SDA');
draw_wire(ax, [oled_x + 18, esp_x], [oled_y + 6, left_y_positions(6)], [0.9 0.5 1], 'SCL');

% =====================================================================
%  GREEN LED (Right side, top)
% =====================================================================
led_g_x = 105; led_g_y = 56;
draw_led(ax, led_g_x, led_g_y, [0 0.8 0.2], 'GREEN LED', 'Normal Op.', 'GPIO2');
% Wire: GPIO2 → resistor → LED
draw_wire_with_resistor(ax, [esp_x + esp_w, led_g_x], ...
    [right_y_positions(3), led_g_y + 3], [0 0.7 0.2], '220\Omega');

% =====================================================================
%  RED LED (Right side, middle)
% =====================================================================
led_r_x = 105; led_r_y = 44;
draw_led(ax, led_r_x, led_r_y, [1 0.1 0.1], 'RED LED', 'Leak Alert', 'GPIO4');
draw_wire_with_resistor(ax, [esp_x + esp_w, led_r_x], ...
    [right_y_positions(4), led_r_y + 3], [0.9 0.1 0.1], '220\Omega');

% =====================================================================
%  BUZZER (Right side, bottom)
% =====================================================================
buz_x = 105; buz_y = 30;
draw_buzzer(ax, buz_x, buz_y, 'PIEZO BUZZER', 'Alarm 2kHz', 'GPIO5 (PWM)');
draw_wire(ax, [esp_x + esp_w, buz_x], [right_y_positions(5), buz_y + 3], [1 0.6 0], 'PWM Signal');

% =====================================================================
%  SERIAL MONITOR (Right side, bottom-right)
% =====================================================================
ser_x = 105; ser_y = 14;
rectangle(ax, 'Position', [ser_x, ser_y, 22, 10], ...
    'Curvature', 0.05, 'FaceColor', [0.15 0.15 0.2], ...
    'EdgeColor', [0.3 0.3 0.5], 'LineWidth', 1.5);
text(ax, ser_x + 11, ser_y + 7, 'Serial Monitor', ...
    'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.7 0.9 0.7], ...
    'HorizontalAlignment', 'center');
text(ax, ser_x + 11, ser_y + 4, '115200 baud', ...
    'FontSize', 7, 'Color', [0.5 0.7 0.5], 'HorizontalAlignment', 'center');
text(ax, ser_x + 11, ser_y + 1.5, 'USB UART (TX0/RX0)', ...
    'FontSize', 6, 'Color', [0.4 0.5 0.4], 'HorizontalAlignment', 'center');
draw_wire(ax, [esp_x + esp_w, ser_x], [right_y_positions(6), ser_y + 5], [0.5 0.8 0.5], 'UART TX');

% =====================================================================
%  POWER CONNECTIONS
% =====================================================================
% 3.3V rail label
text(ax, esp_x - 2, left_y_positions(1), '3V3 →', ...
    'FontSize', 7, 'Color', [0.8 0 0], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
plot(ax, [esp_x - 12, esp_x], [left_y_positions(1), left_y_positions(1)], ...
    'Color', [0.8 0 0], 'LineWidth', 2);
text(ax, esp_x - 12, left_y_positions(1) + 1.5, 'VCC 3.3V Rail', ...
    'FontSize', 7, 'Color', [0.8 0 0], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');

% GND rail
text(ax, esp_x - 2, left_y_positions(2), 'GND →', ...
    'FontSize', 7, 'Color', [0.2 0.2 0.2], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
plot(ax, [esp_x - 12, esp_x], [left_y_positions(2), left_y_positions(2)], ...
    'Color', [0.1 0.1 0.1], 'LineWidth', 2);
text(ax, esp_x - 12, left_y_positions(2) + 1.5, 'GND Rail', ...
    'FontSize', 7, 'Color', [0.2 0.2 0.2], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');

% Power supply box
ps_x = 2; ps_y = 2;
rectangle(ax, 'Position', [ps_x, ps_y, 20, 10], ...
    'Curvature', 0.05, 'FaceColor', [1 0.95 0.85], ...
    'EdgeColor', [0.6 0.3 0], 'LineWidth', 1.5);
text(ax, ps_x + 10, ps_y + 7, 'Power Supply', ...
    'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.5 0.2 0], ...
    'HorizontalAlignment', 'center');
text(ax, ps_x + 10, ps_y + 4, '5V USB / Adapter', ...
    'FontSize', 7, 'Color', [0.4 0.2 0], 'HorizontalAlignment', 'center');
text(ax, ps_x + 10, ps_y + 1.5, 'ESP32 onboard 3.3V LDO', ...
    'FontSize', 6, 'Color', [0.5 0.3 0.1], 'HorizontalAlignment', 'center');

% =====================================================================
%  LEGEND
% =====================================================================
legend_x = 100; legend_y = 75;
rectangle(ax, 'Position', [legend_x, legend_y, 35, 12], ...
    'Curvature', 0.03, 'FaceColor', [0.97 0.97 1], ...
    'EdgeColor', [0.6 0.6 0.8], 'LineWidth', 1);
text(ax, legend_x + 17.5, legend_y + 10.5, 'CONNECTION LEGEND', ...
    'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

leg_items = {
    [0.2 0.6 1],   'Analog Signal (ADC)'
    [0.8 0.4 1],   'I2C Bus (SDA/SCL)'
    [0 0.7 0.2],   'Digital Output (LED)'
    [1 0.6 0],     'PWM Output (Buzzer)'
    [0.5 0.8 0.5], 'UART (Serial)'
    [0.8 0 0],     'Power (3.3V / 5V)'
};
for i = 1:size(leg_items, 1)
    yi = legend_y + 9 - i * 1.4;
    plot(ax, [legend_x + 2, legend_x + 6], [yi, yi], ...
        'Color', leg_items{i,1}, 'LineWidth', 2);
    text(ax, legend_x + 7, yi, leg_items{i,2}, ...
        'FontSize', 7, 'VerticalAlignment', 'middle');
end

% =====================================================================
%  PIPELINE CONTEXT (top area)
% =====================================================================
pipe_y = 78;
% Draw pipeline
plot(ax, [10 60], [pipe_y pipe_y], 'Color', [0.3 0.5 0.7], 'LineWidth', 6);
plot(ax, [10 60], [pipe_y+0.8 pipe_y+0.8], 'Color', [0.4 0.6 0.8], 'LineWidth', 2);
plot(ax, [10 60], [pipe_y-0.8 pipe_y-0.8], 'Color', [0.2 0.4 0.6], 'LineWidth', 2);

% Water flow arrow
text(ax, 35, pipe_y, '→ Water Flow →', ...
    'FontSize', 8, 'Color', [0.1 0.3 0.6], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'BackgroundColor', [0.85 0.9 1]);

% Sensor A on pipe
plot(ax, 15, pipe_y, 'v', 'MarkerSize', 12, ...
    'MarkerFaceColor', [0 0.6 1], 'MarkerEdgeColor', [0 0.3 0.6], 'LineWidth', 1.5);
text(ax, 15, pipe_y + 2.5, 'Sensor A', ...
    'FontSize', 8, 'FontWeight', 'bold', 'Color', [0 0.4 0.8], ...
    'HorizontalAlignment', 'center');

% Sensor B on pipe
plot(ax, 55, pipe_y, 'v', 'MarkerSize', 12, ...
    'MarkerFaceColor', [0 0.6 1], 'MarkerEdgeColor', [0 0.3 0.6], 'LineWidth', 1.5);
text(ax, 55, pipe_y + 2.5, 'Sensor B', ...
    'FontSize', 8, 'FontWeight', 'bold', 'Color', [0 0.4 0.8], ...
    'HorizontalAlignment', 'center');

% Leak point
plot(ax, 38, pipe_y - 2, '^', 'MarkerSize', 10, ...
    'MarkerFaceColor', [1 0.2 0.2], 'MarkerEdgeColor', [0.6 0 0], 'LineWidth', 1.5);
text(ax, 38, pipe_y - 4, 'LEAK', ...
    'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.8 0 0], ...
    'HorizontalAlignment', 'center');

% Pipeline dimension
plot(ax, [10 60], [pipe_y + 5, pipe_y + 5], 'k-', 'LineWidth', 0.5);
plot(ax, [10 10], [pipe_y + 4, pipe_y + 6], 'k-', 'LineWidth', 1);
plot(ax, [60 60], [pipe_y + 4, pipe_y + 6], 'k-', 'LineWidth', 1);
text(ax, 35, pipe_y + 6.5, 'L = Pipeline Length (adjustable)', ...
    'FontSize', 7, 'HorizontalAlignment', 'center');

hold(ax, 'off');

% =====================================================================
%  SAVE
% =====================================================================
if nargin >= 1 && ~isempty(save_path)
    exportgraphics(fig, save_path, 'Resolution', 200);
    fprintf('Circuit diagram saved to: %s\n', save_path);
end

end

% =======================================================================
%  LOCAL DRAWING HELPER FUNCTIONS
% =======================================================================

function draw_sensor(ax, x, y, name, type_str, pin_str)
    % Draw a sensor component box
    rectangle(ax, 'Position', [x, y, 18, 10], ...
        'Curvature', 0.08, 'FaceColor', [0.85 0.92 1], ...
        'EdgeColor', [0.2 0.4 0.7], 'LineWidth', 1.5);
    text(ax, x + 9, y + 7.5, name, ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.1 0.2 0.5], ...
        'HorizontalAlignment', 'center');
    text(ax, x + 9, y + 4.5, type_str, ...
        'FontSize', 7, 'Color', [0.3 0.3 0.5], 'HorizontalAlignment', 'center');
    text(ax, x + 9, y + 1.5, pin_str, ...
        'FontSize', 6, 'Color', [0.4 0.4 0.6], 'HorizontalAlignment', 'center');
end

function draw_led(ax, x, y, color, name, label, pin_str)
    % Draw an LED component
    % LED body (circle)
    theta = linspace(0, 2*pi, 50);
    r = 3;
    fill(ax, x + r + r*cos(theta), y + 3 + r*sin(theta), color, ...
        'EdgeColor', color * 0.6, 'LineWidth', 1.5, 'FaceAlpha', 0.7);
    text(ax, x + r, y + 3, name, ...
        'FontSize', 7, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1], ...
        'HorizontalAlignment', 'center');
    text(ax, x + r, y - 1, label, ...
        'FontSize', 6, 'Color', [0.3 0.3 0.3], 'HorizontalAlignment', 'center');
    text(ax, x + r, y - 2.8, pin_str, ...
        'FontSize', 6, 'Color', [0.4 0.4 0.6], 'HorizontalAlignment', 'center');
end

function draw_buzzer(ax, x, y, name, label, pin_str)
    % Draw a buzzer component
    rectangle(ax, 'Position', [x, y, 16, 10], ...
        'Curvature', 0.1, 'FaceColor', [1 0.92 0.8], ...
        'EdgeColor', [0.6 0.4 0.1], 'LineWidth', 1.5);
    text(ax, x + 8, y + 7, name, ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.4 0.2 0], ...
        'HorizontalAlignment', 'center');
    text(ax, x + 8, y + 4, label, ...
        'FontSize', 7, 'Color', [0.5 0.3 0.1], 'HorizontalAlignment', 'center');
    text(ax, x + 8, y + 1.5, pin_str, ...
        'FontSize', 6, 'Color', [0.4 0.3 0.2], 'HorizontalAlignment', 'center');
end

function draw_wire(ax, x_pts, y_pts, color, label)
    % Draw a connection wire with optional label
    % Simple two-point wire with mid-route bend
    x_mid = mean(x_pts);
    plot(ax, [x_pts(1), x_mid, x_mid, x_pts(2)], ...
             [y_pts(1), y_pts(1), y_pts(2), y_pts(2)], ...
        'Color', color, 'LineWidth', 1.5);
    % Junction dots
    plot(ax, x_pts(1), y_pts(1), '.', 'Color', color, 'MarkerSize', 10);
    plot(ax, x_pts(2), y_pts(2), '.', 'Color', color, 'MarkerSize', 10);
    % Label at midpoint
    if nargin >= 5 && ~isempty(label)
        text(ax, x_mid + 1, mean(y_pts), label, ...
            'FontSize', 6, 'Color', color * 0.7, ...
            'Rotation', 90, 'HorizontalAlignment', 'center');
    end
end

function draw_wire_with_resistor(ax, x_pts, y_pts, color, res_label)
    % Draw a wire with a resistor symbol in the middle
    x_mid = mean(x_pts);
    
    % Wire segments
    plot(ax, [x_pts(1), x_mid - 3], [y_pts(1), y_pts(1)], ...
        'Color', color, 'LineWidth', 1.5);
    plot(ax, [x_mid + 3, x_mid + 3, x_pts(2)], ...
             [y_pts(1), y_pts(2), y_pts(2)], ...
        'Color', color, 'LineWidth', 1.5);
    
    % Resistor zigzag
    rx = x_mid - 3;
    ry = y_pts(1);
    n_zig = 4;
    zx = linspace(rx, rx + 6, n_zig * 4 + 1);
    zy = ry + 0.8 * repmat([0 1 0 -1], 1, n_zig);
    zy = [zy, ry]; %#ok<AGROW>
    plot(ax, zx, zy, 'Color', color * 0.7, 'LineWidth', 1.5);
    
    % Resistor label
    text(ax, x_mid, ry + 2, res_label, ...
        'FontSize', 7, 'FontWeight', 'bold', 'Color', color * 0.6, ...
        'HorizontalAlignment', 'center', 'Interpreter', 'tex');
    
    % Junction dots
    plot(ax, x_pts(1), y_pts(1), '.', 'Color', color, 'MarkerSize', 10);
    plot(ax, x_pts(2), y_pts(2), '.', 'Color', color, 'MarkerSize', 10);
end
