function oled_handle = oled_display(parent_axes, oled_data, options)
% OLED_DISPLAY  Render a simulated SSD1306 OLED display on MATLAB axes.
%
%   oled_handle = oled_display(parent_axes, oled_data)
%   oled_handle = oled_display(parent_axes, oled_data, options)
%
%   Draws a visual representation of a 128×64 pixel SSD1306 OLED display
%   on the specified axes, showing the data that the ESP32 firmware would
%   send to the physical display over I2C (GPIO21/GPIO22).
%
%   INPUTS:
%     parent_axes — Handle to MATLAB axes or uiaxes
%     oled_data   — Structure with display lines:
%       .line1    — Header text (e.g. 'Pipeline Monitor')
%       .line2    — Status text (e.g. 'LEAK DETECTED!')
%       .line3    — Position text
%       .line4    — Error text
%       .line5    — Sensor A reading
%       .line6    — Sensor B reading
%     options     — (Optional) structure:
%       .background_color  [R G B]  OLED background (default [0 0 0])
%       .text_color        [R G B]  Text color (default [0 1 0.8])
%       .alert_color       [R G B]  Alert text color (default [1 0.2 0.2])
%       .border_color      [R G B]  Frame color (default [0.3 0.3 0.3])
%       .font_size         [int]    Font size (default 9)
%
%   OUTPUT:
%     oled_handle — Structure of graphics handles for later updating

% =====================================================================
%  DEFAULT OPTIONS
% =====================================================================
if nargin < 3
    options = struct();
end
if ~isfield(options, 'background_color')
    options.background_color = [0 0 0];         % Black (OLED off)
end
if ~isfield(options, 'text_color')
    options.text_color = [0 1 0.8];             % Cyan-green (OLED typical)
end
if ~isfield(options, 'alert_color')
    options.alert_color = [1 0.3 0.1];          % Red-orange for alerts
end
if ~isfield(options, 'border_color')
    options.border_color = [0.4 0.4 0.4];
end
if ~isfield(options, 'font_size')
    options.font_size = 9;
end

% =====================================================================
%  CLEAR AND CONFIGURE AXES
% =====================================================================
cla(parent_axes);
set(parent_axes, 'Color', [0.15 0.15 0.15]);   % PCB background
set(parent_axes, 'XLim', [0 1], 'YLim', [0 1]);
set(parent_axes, 'XTick', [], 'YTick', []);
axis(parent_axes, 'equal');
hold(parent_axes, 'on');

% =====================================================================
%  DRAW OLED FRAME (physical display bezel)
% =====================================================================
% Outer bezel
rectangle(parent_axes, 'Position', [0.03 0.03 0.94 0.94], ...
    'Curvature', 0.05, ...
    'FaceColor', [0.08 0.08 0.08], ...
    'EdgeColor', options.border_color, ...
    'LineWidth', 2);

% Inner display area
rectangle(parent_axes, 'Position', [0.08 0.08 0.84 0.84], ...
    'Curvature', 0.02, ...
    'FaceColor', options.background_color, ...
    'EdgeColor', [0.2 0.2 0.2], ...
    'LineWidth', 1);

% =====================================================================
%  DISPLAY LABEL (physical marking on PCB)
% =====================================================================
text(parent_axes, 0.5, 0.98, 'SSD1306 OLED (I2C: 0x3C)', ...
    'Color', [0.5 0.5 0.5], ...
    'FontSize', 7, ...
    'FontName', 'Consolas', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top');

text(parent_axes, 0.5, 0.02, 'GPIO21(SDA) / GPIO22(SCL)', ...
    'Color', [0.4 0.4 0.4], ...
    'FontSize', 6, ...
    'FontName', 'Consolas', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom');

% =====================================================================
%  RENDER TEXT LINES
% =====================================================================
% Display area boundaries
x_left  = 0.12;
y_top   = 0.86;
y_bottom = 0.12;
line_height = (y_top - y_bottom) / 7;

lines = {oled_data.line1, oled_data.line2, oled_data.line3, ...
         oled_data.line4, oled_data.line5, oled_data.line6};

oled_handle.text_handles = gobjects(1, 6);

for i = 1:6
    y_pos = y_top - (i - 0.3) * line_height;
    
    % Determine color based on content
    if i == 1
        % Header — slightly brighter
        tc = options.text_color * 1.1;
        tc = min(tc, 1);
        fs = options.font_size + 1;
        fw = 'bold';
    elseif contains(lower(lines{i}), 'leak') || contains(lower(lines{i}), 'detected')
        % Alert condition
        tc = options.alert_color;
        fs = options.font_size;
        fw = 'bold';
    elseif contains(lower(lines{i}), 'normal')
        tc = [0.2 1 0.3];   % Green for normal
        fs = options.font_size;
        fw = 'bold';
    else
        tc = options.text_color;
        fs = options.font_size;
        fw = 'normal';
    end
    
    oled_handle.text_handles(i) = text(parent_axes, x_left, y_pos, lines{i}, ...
        'Color', tc, ...
        'FontSize', fs, ...
        'FontWeight', fw, ...
        'FontName', 'Consolas', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', ...
        'Interpreter', 'none');
end

% =====================================================================
%  SEPARATOR LINE (visual divider after header)
% =====================================================================
y_sep = y_top - 0.8 * line_height;
plot(parent_axes, [x_left, 0.88], [y_sep, y_sep], ...
    'Color', [0.2 0.5 0.4], 'LineWidth', 0.5);

hold(parent_axes, 'off');

% Store options for potential updates
oled_handle.options = options;
oled_handle.parent_axes = parent_axes;

end
