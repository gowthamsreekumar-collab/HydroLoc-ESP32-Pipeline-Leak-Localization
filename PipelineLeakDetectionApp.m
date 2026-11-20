classdef PipelineLeakDetectionApp < handle
% PIPELINELEAKDETECTIONAPP  Interactive hardware-oriented simulation GUI.
%
%   app = PipelineLeakDetectionApp()
%
%   Launches a professional interactive simulation of the ESP32-based
%   pipeline leak detection and localization system. The GUI visually
%   represents all hardware components (sensors, ESP32, OLED, LEDs,
%   buzzer) and allows real-time parameter adjustment.
%
%   FEATURES:
%     - Pipeline visualization with adjustable leak position
%     - Sensor signal waveform display
%     - GCC-PHAT cross-correlation display
%     - Simulated OLED display (SSD1306)
%     - LED and buzzer status indicators
%     - 10 pre-defined test cases
%     - CSV export of test results
%
%   HARDWARE MODELLING CLASSIFICATION:
%     Physical model:      Pipeline hydraulic (Simscape Fluids, if run in Simulink)
%     Functional model:    ESP32, ADC, sensor response, signal processing
%     Visual simulation:   OLED, LEDs, buzzer
%     Algorithm model:     GCC-PHAT, TDOA localization
%
%   USAGE:
%     app = PipelineLeakDetectionApp();

    % =================================================================
    %  PROPERTIES
    % =================================================================
    properties (Access = public)
        % --- UI Figure ---
        UIFigure             matlab.ui.Figure

        % --- Layout panels ---
        MainGrid             matlab.ui.container.GridLayout
        ControlPanel         matlab.ui.container.Panel
        VizPanel             matlab.ui.container.Panel
        HardwarePanel        matlab.ui.container.Panel

        % --- Control widgets ---
        PipelineLengthSlider matlab.ui.control.Slider
        PipelineLengthLabel  matlab.ui.control.Label
        LeakPositionSlider   matlab.ui.control.Slider
        LeakPositionLabel    matlab.ui.control.Label
        LeakSeveritySlider   matlab.ui.control.Slider
        LeakSeverityLabel    matlab.ui.control.Label
        NoiseLevelSlider     matlab.ui.control.Slider
        NoiseLevelLabel      matlab.ui.control.Label
        PropSpeedSlider      matlab.ui.control.Slider
        PropSpeedLabel       matlab.ui.control.Label
        SensitivityASlider   matlab.ui.control.Slider
        SensitivityALabel    matlab.ui.control.Label
        SensitivityBSlider   matlab.ui.control.Slider
        SensitivityBLabel    matlab.ui.control.Label
        DetThresholdSlider   matlab.ui.control.Slider
        DetThresholdLabel    matlab.ui.control.Label

        RunButton            matlab.ui.control.Button
        RunAllTestsButton    matlab.ui.control.Button
        ResetButton          matlab.ui.control.Button
        ExportButton         matlab.ui.control.Button

        % --- Visualization axes ---
        PipelineAxes         matlab.ui.control.UIAxes
        SensorAAxes          matlab.ui.control.UIAxes
        SensorBAxes          matlab.ui.control.UIAxes
        GCCPHATAxes          matlab.ui.control.UIAxes

        % --- Hardware output elements ---
        OLEDAxes             matlab.ui.control.UIAxes
        GreenLEDLamp         matlab.ui.control.Lamp
        RedLEDLamp           matlab.ui.control.Lamp
        BuzzerLamp           matlab.ui.control.Lamp
        GreenLEDLabel        matlab.ui.control.Label
        RedLEDLabel          matlab.ui.control.Label
        BuzzerLabel          matlab.ui.control.Label

        % --- Results text ---
        ResultsArea          matlab.ui.control.TextArea
        ProcessingStepsArea  matlab.ui.control.TextArea
        SerialMonitorArea    matlab.ui.control.TextArea

        % --- Status bar ---
        StatusLabel          matlab.ui.control.Label

        % --- Data ---
        LastResults          struct
        TestResultsTable     table
        ProjectDir           char
    end

    % =================================================================
    %  PUBLIC METHODS
    % =================================================================
    methods (Access = public)

        function app = PipelineLeakDetectionApp()
            % Constructor — builds the entire UI
            app.ProjectDir = fileparts(mfilename('fullpath'));
            createUI(app);
            resetApp(app);
        end

    end

    % =================================================================
    %  APP METHODS & CALLBACKS
    % =================================================================
    methods (Access = public)

        % =============================================================
        %  UI CONSTRUCTION
        % =============================================================
        function createUI(app)
            % --- Main Figure ---
            app.UIFigure = uifigure('Name', ...
                'ESP32 Pipeline Leak Detection — Hardware Simulation', ...
                'Position', [30 30 1520 860], ...
                'Color', [0.94 0.94 0.96], ...
                'Resize', 'on');

            % --- Main 3-column grid ---
            app.MainGrid = uigridlayout(app.UIFigure, [1 3]);
            app.MainGrid.ColumnWidth = {'0.22x', '0.48x', '0.30x'};
            app.MainGrid.Padding = [5 5 5 5];
            app.MainGrid.ColumnSpacing = 5;

            % ==========================================================
            %  LEFT COLUMN: CONTROLS
            % ==========================================================
            app.ControlPanel = uipanel(app.MainGrid, ...
                'Title', 'SYSTEM PARAMETERS', ...
                'FontWeight', 'bold', ...
                'FontSize', 11, ...
                'BackgroundColor', [0.96 0.96 0.98]);
            app.ControlPanel.Layout.Column = 1;

            ctrl_grid = uigridlayout(app.ControlPanel, [22 2]);
            ctrl_grid.RowHeight = repmat({22}, 1, 22);
            ctrl_grid.ColumnWidth = {'1x', '0.5x'};
            ctrl_grid.Padding = [8 8 8 8];
            ctrl_grid.RowSpacing = 3;

            row = 1;

            % --- Pipeline Length ---
            uilabel(ctrl_grid, 'Text', 'Pipeline Length (m):', ...
                'FontWeight', 'bold', 'FontSize', 10);
            app.PipelineLengthLabel = uilabel(ctrl_grid, 'Text', '100.0 m', 'FontSize', 10);
            app.PipelineLengthLabel.Layout.Row = row; app.PipelineLengthLabel.Layout.Column = 2;
            row = row + 1;
            app.PipelineLengthSlider = uislider(ctrl_grid, ...
                'Limits', [10 500], 'Value', 100, ...
                'MajorTicks', [10 100 200 300 400 500], ...
                'ValueChangedFcn', @(~,~) app.onSliderChanged());
            app.PipelineLengthSlider.Layout.Row = row; app.PipelineLengthSlider.Layout.Column = [1 2];
            row = row + 1;

            % --- Leak Position ---
            uilabel(ctrl_grid, 'Text', 'Leak Position (m):', ...
                'FontWeight', 'bold', 'FontSize', 10);
            app.LeakPositionLabel = uilabel(ctrl_grid, 'Text', '35.0 m', 'FontSize', 10);
            app.LeakPositionLabel.Layout.Row = row; app.LeakPositionLabel.Layout.Column = 2;
            row = row + 1;
            app.LeakPositionSlider = uislider(ctrl_grid, ...
                'Limits', [0 100], 'Value', 35, ...
                'ValueChangedFcn', @(~,~) app.onSliderChanged());
            app.LeakPositionSlider.Layout.Row = row; app.LeakPositionSlider.Layout.Column = [1 2];
            row = row + 1;

            % --- Leak Severity ---
            uilabel(ctrl_grid, 'Text', 'Leak Severity (0–1):', ...
                'FontWeight', 'bold', 'FontSize', 10);
            app.LeakSeverityLabel = uilabel(ctrl_grid, 'Text', '0.50', 'FontSize', 10);
            app.LeakSeverityLabel.Layout.Row = row; app.LeakSeverityLabel.Layout.Column = 2;
            row = row + 1;
            app.LeakSeveritySlider = uislider(ctrl_grid, ...
                'Limits', [0 1], 'Value', 0.5, ...
                'MajorTicks', [0 0.25 0.5 0.75 1.0], ...
                'ValueChangedFcn', @(~,~) app.onSliderChanged());
            app.LeakSeveritySlider.Layout.Row = row; app.LeakSeveritySlider.Layout.Column = [1 2];
            row = row + 1;

            % --- Noise Level ---
            uilabel(ctrl_grid, 'Text', 'Noise Level:', ...
                'FontWeight', 'bold', 'FontSize', 10);
            app.NoiseLevelLabel = uilabel(ctrl_grid, 'Text', '0.020', 'FontSize', 10);
            app.NoiseLevelLabel.Layout.Row = row; app.NoiseLevelLabel.Layout.Column = 2;
            row = row + 1;
            app.NoiseLevelSlider = uislider(ctrl_grid, ...
                'Limits', [0 0.5], 'Value', 0.02, ...
                'MajorTicks', [0 0.1 0.2 0.3 0.4 0.5], ...
                'ValueChangedFcn', @(~,~) app.onSliderChanged());
            app.NoiseLevelSlider.Layout.Row = row; app.NoiseLevelSlider.Layout.Column = [1 2];
            row = row + 1;

            % --- Propagation Speed ---
            uilabel(ctrl_grid, 'Text', 'Prop. Speed (m/s):', ...
                'FontWeight', 'bold', 'FontSize', 10);
            app.PropSpeedLabel = uilabel(ctrl_grid, 'Text', '1000 m/s', 'FontSize', 10);
            app.PropSpeedLabel.Layout.Row = row; app.PropSpeedLabel.Layout.Column = 2;
            row = row + 1;
            app.PropSpeedSlider = uislider(ctrl_grid, ...
                'Limits', [300 1500], 'Value', 1000, ...
                'MajorTicks', [300 500 800 1000 1200 1500], ...
                'ValueChangedFcn', @(~,~) app.onSliderChanged());
            app.PropSpeedSlider.Layout.Row = row; app.PropSpeedSlider.Layout.Column = [1 2];
            row = row + 1;

            % --- Sensor A Sensitivity ---
            uilabel(ctrl_grid, 'Text', 'Sensor A Sensitivity:', ...
                'FontWeight', 'bold', 'FontSize', 10);
            app.SensitivityALabel = uilabel(ctrl_grid, 'Text', '1.00', 'FontSize', 10);
            app.SensitivityALabel.Layout.Row = row; app.SensitivityALabel.Layout.Column = 2;
            row = row + 1;
            app.SensitivityASlider = uislider(ctrl_grid, ...
                'Limits', [0.1 2.0], 'Value', 1.0, ...
                'ValueChangedFcn', @(~,~) app.onSliderChanged());
            app.SensitivityASlider.Layout.Row = row; app.SensitivityASlider.Layout.Column = [1 2];
            row = row + 1;

            % --- Sensor B Sensitivity ---
            uilabel(ctrl_grid, 'Text', 'Sensor B Sensitivity:', ...
                'FontWeight', 'bold', 'FontSize', 10);
            app.SensitivityBLabel = uilabel(ctrl_grid, 'Text', '1.00', 'FontSize', 10);
            app.SensitivityBLabel.Layout.Row = row; app.SensitivityBLabel.Layout.Column = 2;
            row = row + 1;
            app.SensitivityBSlider = uislider(ctrl_grid, ...
                'Limits', [0.1 2.0], 'Value', 1.0, ...
                'ValueChangedFcn', @(~,~) app.onSliderChanged());
            app.SensitivityBSlider.Layout.Row = row; app.SensitivityBSlider.Layout.Column = [1 2];
            row = row + 1;

            % --- Detection Threshold ---
            uilabel(ctrl_grid, 'Text', 'Detection Threshold:', ...
                'FontWeight', 'bold', 'FontSize', 10);
            app.DetThresholdLabel = uilabel(ctrl_grid, 'Text', '3.00', 'FontSize', 10);
            app.DetThresholdLabel.Layout.Row = row; app.DetThresholdLabel.Layout.Column = 2;
            row = row + 1;
            app.DetThresholdSlider = uislider(ctrl_grid, ...
                'Limits', [1 20], 'Value', 3.0, ...
                'MajorTicks', [1 5 10 15 20], ...
                'ValueChangedFcn', @(~,~) app.onSliderChanged());
            app.DetThresholdSlider.Layout.Row = row; app.DetThresholdSlider.Layout.Column = [1 2];
            row = row + 1;

            % --- BUTTONS ---
            row = row + 1;
            app.RunButton = uibutton(ctrl_grid, 'push', ...
                'Text', '▶  RUN SIMULATION', ...
                'FontWeight', 'bold', 'FontSize', 12, ...
                'BackgroundColor', [0.2 0.6 0.3], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.runSimulation());
            app.RunButton.Layout.Row = row; app.RunButton.Layout.Column = [1 2];
            row = row + 1;

            app.RunAllTestsButton = uibutton(ctrl_grid, 'push', ...
                'Text', '🧪  RUN ALL 10 TESTS', ...
                'FontWeight', 'bold', 'FontSize', 11, ...
                'BackgroundColor', [0.2 0.4 0.7], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.runAllTests());
            app.RunAllTestsButton.Layout.Row = row; app.RunAllTestsButton.Layout.Column = [1 2];
            row = row + 1;

            app.ExportButton = uibutton(ctrl_grid, 'push', ...
                'Text', '📊  EXPORT RESULTS', ...
                'FontSize', 10, ...
                'BackgroundColor', [0.5 0.4 0.6], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.exportResults());
            app.ExportButton.Layout.Row = row; app.ExportButton.Layout.Column = [1 2];
            row = row + 1;

            app.ResetButton = uibutton(ctrl_grid, 'push', ...
                'Text', '↺  RESET', ...
                'FontSize', 10, ...
                'BackgroundColor', [0.6 0.3 0.3], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.resetApp());
            app.ResetButton.Layout.Row = row; app.ResetButton.Layout.Column = [1 2];

            % ==========================================================
            %  CENTRE COLUMN: VISUALIZATION
            % ==========================================================
            app.VizPanel = uipanel(app.MainGrid, ...
                'Title', 'SIGNAL VISUALIZATION', ...
                'FontWeight', 'bold', ...
                'FontSize', 11, ...
                'BackgroundColor', [0.97 0.97 0.98]);
            app.VizPanel.Layout.Column = 2;

            viz_grid = uigridlayout(app.VizPanel, [4 1]);
            viz_grid.RowHeight = {'1x', '1x', '1x', '1x'};
            viz_grid.Padding = [5 5 5 5];
            viz_grid.RowSpacing = 5;

            % Pipeline diagram
            app.PipelineAxes = uiaxes(viz_grid);
            app.PipelineAxes.Layout.Row = 1;
            title(app.PipelineAxes, 'Pipeline Diagram');

            % Sensor A signal
            app.SensorAAxes = uiaxes(viz_grid);
            app.SensorAAxes.Layout.Row = 2;
            title(app.SensorAAxes, 'Sensor A Signal (GPIO34)');
            xlabel(app.SensorAAxes, 'Time (s)');
            ylabel(app.SensorAAxes, 'Amplitude');

            % Sensor B signal
            app.SensorBAxes = uiaxes(viz_grid);
            app.SensorBAxes.Layout.Row = 3;
            title(app.SensorBAxes, 'Sensor B Signal (GPIO35)');
            xlabel(app.SensorBAxes, 'Time (s)');
            ylabel(app.SensorBAxes, 'Amplitude');

            % GCC-PHAT
            app.GCCPHATAxes = uiaxes(viz_grid);
            app.GCCPHATAxes.Layout.Row = 4;
            title(app.GCCPHATAxes, 'GCC-PHAT Cross-Correlation');
            xlabel(app.GCCPHATAxes, 'Lag (s)');
            ylabel(app.GCCPHATAxes, 'Correlation');

            % ==========================================================
            %  RIGHT COLUMN: HARDWARE OUTPUT
            % ==========================================================
            app.HardwarePanel = uipanel(app.MainGrid, ...
                'Title', 'HARDWARE OUTPUT', ...
                'FontWeight', 'bold', ...
                'FontSize', 11, ...
                'BackgroundColor', [0.95 0.95 0.97]);
            app.HardwarePanel.Layout.Column = 3;

            hw_grid = uigridlayout(app.HardwarePanel, [7 1]);
            hw_grid.RowHeight = {'1.5x', 30, 30, 30, '1.2x', '1.8x', 18};
            hw_grid.Padding = [5 5 5 5];
            hw_grid.RowSpacing = 4;

            % --- OLED Display ---
            oled_panel = uipanel(hw_grid, 'Title', 'OLED Display (SSD1306)', ...
                'FontWeight', 'bold', 'FontSize', 9, ...
                'BackgroundColor', [0.1 0.1 0.12]);
            oled_panel.Layout.Row = 1;
            app.OLEDAxes = uiaxes(oled_panel);
            app.OLEDAxes.Position = [5 5 oled_panel.Position(3)-10 oled_panel.Position(4)-25];
            set(app.OLEDAxes, 'Color', [0 0 0], 'XTick', [], 'YTick', [], 'Box', 'on', ...
                'XColor', [0.3 0.3 0.3], 'YColor', [0.3 0.3 0.3]);

            % --- LED Indicators ---
            led_grid = uigridlayout(hw_grid, [1 4]);
            led_grid.Layout.Row = 2;
            led_grid.ColumnWidth = {'1x', '1x', '1x', '1x'};
            led_grid.Padding = [5 0 5 0];

            app.GreenLEDLabel = uilabel(led_grid, 'Text', 'NORMAL', ...
                'FontWeight', 'bold', 'FontSize', 9, ...
                'HorizontalAlignment', 'center');
            app.GreenLEDLamp = uilamp(led_grid, 'Color', [0.3 0.3 0.3]);
            app.RedLEDLabel = uilabel(led_grid, 'Text', 'LEAK', ...
                'FontWeight', 'bold', 'FontSize', 9, ...
                'HorizontalAlignment', 'center');
            app.RedLEDLamp = uilamp(led_grid, 'Color', [0.3 0.3 0.3]);

            % --- Buzzer ---
            buzzer_grid = uigridlayout(hw_grid, [1 2]);
            buzzer_grid.Layout.Row = 3;
            buzzer_grid.ColumnWidth = {'1x', '1x'};
            buzzer_grid.Padding = [5 0 5 0];

            app.BuzzerLabel = uilabel(buzzer_grid, 'Text', 'BUZZER (GPIO5)', ...
                'FontWeight', 'bold', 'FontSize', 9, ...
                'HorizontalAlignment', 'center');
            app.BuzzerLamp = uilamp(buzzer_grid, 'Color', [0.3 0.3 0.3]);

            % --- Results Panel ---
            results_panel = uipanel(hw_grid, 'Title', 'LOCALIZATION RESULTS', ...
                'FontWeight', 'bold', 'FontSize', 9, ...
                'BackgroundColor', [0.96 0.96 0.98]);
            results_panel.Layout.Row = 4;

            app.ResultsArea = uitextarea(results_panel, ...
                'Value', {'Awaiting simulation...'}, ...
                'Editable', 'off', ...
                'FontName', 'Consolas', ...
                'FontSize', 9);
            app.ResultsArea.Position = [5 2 results_panel.Position(3)-10 results_panel.Position(4)-20];

            % --- ESP32 Processing Log ---
            esp_panel = uipanel(hw_grid, 'Title', 'ESP32 Processing Steps', ...
                'FontWeight', 'bold', 'FontSize', 9, ...
                'BackgroundColor', [0.12 0.12 0.16]);
            esp_panel.Layout.Row = 5;

            app.ProcessingStepsArea = uitextarea(esp_panel, ...
                'Value', {'ESP32 subsystem idle...'}, ...
                'Editable', 'off', ...
                'FontName', 'Consolas', ...
                'FontSize', 8, ...
                'BackgroundColor', [0.1 0.1 0.14], ...
                'FontColor', [0 0.9 0.5]);

            % --- Serial Monitor ---
            serial_panel = uipanel(hw_grid, 'Title', 'Serial Monitor (115200 baud)', ...
                'FontWeight', 'bold', 'FontSize', 9, ...
                'BackgroundColor', [0.05 0.05 0.08]);
            serial_panel.Layout.Row = 6;

            app.SerialMonitorArea = uitextarea(serial_panel, ...
                'Value', {'[Serial] Waiting for data...'}, ...
                'Editable', 'off', ...
                'FontName', 'Consolas', ...
                'FontSize', 8, ...
                'BackgroundColor', [0 0 0.02], ...
                'FontColor', [0.3 1 0.3]);

            % --- Status Bar ---
            app.StatusLabel = uilabel(hw_grid, ...
                'Text', 'Ready. Adjust parameters and click RUN SIMULATION.', ...
                'FontSize', 9, ...
                'FontColor', [0.3 0.3 0.6]);
            app.StatusLabel.Layout.Row = 7;

        end

        % =============================================================
        %  SLIDER CHANGE CALLBACK
        % =============================================================
        function onSliderChanged(app)
            % Update labels when sliders change
            L = app.PipelineLengthSlider.Value;
            app.PipelineLengthLabel.Text = sprintf('%.1f m', L);

            % Clamp leak position to pipeline length
            if app.LeakPositionSlider.Value > L
                app.LeakPositionSlider.Value = L;
            end
            app.LeakPositionSlider.Limits = [0 L];
            app.LeakPositionLabel.Text = sprintf('%.1f m', app.LeakPositionSlider.Value);

            app.LeakSeverityLabel.Text = sprintf('%.2f', app.LeakSeveritySlider.Value);
            app.NoiseLevelLabel.Text = sprintf('%.3f', app.NoiseLevelSlider.Value);
            app.PropSpeedLabel.Text = sprintf('%.0f m/s', app.PropSpeedSlider.Value);
            app.SensitivityALabel.Text = sprintf('%.2f', app.SensitivityASlider.Value);
            app.SensitivityBLabel.Text = sprintf('%.2f', app.SensitivityBSlider.Value);
            app.DetThresholdLabel.Text = sprintf('%.2f', app.DetThresholdSlider.Value);

            % Update pipeline diagram with new position
            updatePipelineDiagram(app);
        end

        % =============================================================
        %  PIPELINE DIAGRAM UPDATE
        % =============================================================
        function updatePipelineDiagram(app, est_pos)
            ax = app.PipelineAxes;
            cla(ax);
            hold(ax, 'on');

            L = app.PipelineLengthSlider.Value;
            x_leak = app.LeakPositionSlider.Value;
            sev = app.LeakSeveritySlider.Value;

            % Pipeline body
            fill(ax, [0 L L 0], [-0.3 -0.3 0.3 0.3], [0.5 0.7 0.9], ...
                'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 1.5);

            % Water flow arrows
            for xi = L*0.15 : L*0.2 : L*0.85
                text(ax, xi, 0, '\rightarrow', 'FontSize', 14, ...
                    'Color', [0.2 0.4 0.8], 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle');
            end

            % Sensor A marker
            plot(ax, 0, 0.5, 'v', 'MarkerSize', 14, ...
                'MarkerFaceColor', [0 0.5 1], 'MarkerEdgeColor', [0 0.2 0.5], 'LineWidth', 2);
            text(ax, 0, 0.85, 'Sensor A', 'FontSize', 9, 'FontWeight', 'bold', ...
                'Color', [0 0.3 0.7], 'HorizontalAlignment', 'center');
            text(ax, 0, -0.65, 'x = 0', 'FontSize', 8, ...
                'Color', [0.3 0.3 0.3], 'HorizontalAlignment', 'center');

            % Sensor B marker
            plot(ax, L, 0.5, 'v', 'MarkerSize', 14, ...
                'MarkerFaceColor', [0 0.5 1], 'MarkerEdgeColor', [0 0.2 0.5], 'LineWidth', 2);
            text(ax, L, 0.85, 'Sensor B', 'FontSize', 9, 'FontWeight', 'bold', ...
                'Color', [0 0.3 0.7], 'HorizontalAlignment', 'center');
            text(ax, L, -0.65, sprintf('x = %.0fm', L), 'FontSize', 8, ...
                'Color', [0.3 0.3 0.3], 'HorizontalAlignment', 'center');

            % Leak marker (if severity > 0)
            if sev > 0
                % Leak spray visualization
                spray_h = sev * 0.6;
                for si = 1:5
                    plot(ax, x_leak + (rand-0.5)*sev*3, ...
                         -0.3 - rand*spray_h, '.', ...
                        'Color', [0.2 0.5 1 0.5], 'MarkerSize', 8 + randi(8));
                end
                plot(ax, x_leak, -0.5, '^', 'MarkerSize', 12 + sev*6, ...
                    'MarkerFaceColor', [1 0.2 0.2], 'MarkerEdgeColor', [0.6 0 0], ...
                    'LineWidth', 1.5);
                text(ax, x_leak, -0.95, sprintf('LEAK @ %.1fm', x_leak), ...
                    'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.8 0 0], ...
                    'HorizontalAlignment', 'center');
                text(ax, x_leak, -1.25, sprintf('Severity: %.0f%%', sev*100), ...
                    'FontSize', 7, 'Color', [0.6 0.2 0.2], ...
                    'HorizontalAlignment', 'center');
            else
                text(ax, L/2, -0.7, 'No Leak (severity = 0)', ...
                    'FontSize', 9, 'Color', [0 0.6 0.2], ...
                    'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            end

            % Estimated position marker (if provided)
            if nargin >= 2 && ~isempty(est_pos)
                plot(ax, est_pos, 0.5, 'p', 'MarkerSize', 16, ...
                    'MarkerFaceColor', [1 0.8 0], 'MarkerEdgeColor', [0.6 0.4 0], ...
                    'LineWidth', 1.5);
                text(ax, est_pos, 1.1, sprintf('Est: %.1fm', est_pos), ...
                    'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.7 0.5 0], ...
                    'HorizontalAlignment', 'center');
            end

            % Dimension line
            plot(ax, [0 L], [1.4 1.4], 'k-', 'LineWidth', 0.5);
            plot(ax, [0 0], [1.3 1.5], 'k-', 'LineWidth', 1);
            plot(ax, [L L], [1.3 1.5], 'k-', 'LineWidth', 1);
            text(ax, L/2, 1.6, sprintf('L = %.0f m', L), ...
                'FontSize', 9, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

            % Title
            title(ax, 'Pipeline Diagram — Sensor Positions & Leak Location', ...
                'FontSize', 10);

            set(ax, 'XLim', [-L*0.1, L*1.1], 'YLim', [-1.5 2]);
            set(ax, 'YTick', []);
            xlabel(ax, 'Position (m)');
            hold(ax, 'off');
        end

        % =============================================================
        %  RUN SINGLE SIMULATION
        % =============================================================
        function runSimulation(app)
            app.StatusLabel.Text = 'Running simulation...';
            app.StatusLabel.FontColor = [0.8 0.5 0];
            drawnow;

            try
                % Gather parameters from sliders
                params.pipeline_length     = app.PipelineLengthSlider.Value;
                params.leak_position       = app.LeakPositionSlider.Value;
                params.propagation_speed   = app.PropSpeedSlider.Value;
                params.sampling_rate       = 10000;   % 10 kHz
                params.duration            = 0.5;     % 0.5 seconds
                params.leak_severity       = app.LeakSeveritySlider.Value;
                params.noise_level         = app.NoiseLevelSlider.Value;
                params.sensor_sensitivity_A = app.SensitivityASlider.Value;
                params.sensor_sensitivity_B = app.SensitivityBSlider.Value;

                % Generate signals
                [sig_A, sig_B, t, true_tdoa, ~] = leak_signal_model(params);

                % Run ESP32 processing chain
                sys_params.pipeline_length     = params.pipeline_length;
                sys_params.propagation_speed   = params.propagation_speed;
                sys_params.sampling_rate       = params.sampling_rate;
                sys_params.detection_threshold = app.DetThresholdSlider.Value;
                sys_params.true_leak_position  = params.leak_position;
                sys_params.true_leak_severity  = params.leak_severity;

                results = esp32_subsystem(sig_A, sig_B, sys_params);
                results.true_tdoa = true_tdoa;
                app.LastResults = results;
                app.LastResults.time_vector = t;
                app.LastResults.sig_A_raw = sig_A;
                app.LastResults.sig_B_raw = sig_B;
                app.LastResults.true_tdoa = true_tdoa;

                % Update all visualizations
                updateSignalPlots(app, t, sig_A, sig_B, results);
                updateGCCPHATPlot(app, results);
                updatePipelineDiagram(app, results.estimated_position);
                updateOLEDDisplay(app, results);
                updateLEDs(app, results);
                updateResultsText(app, results, params);
                updateSerialMonitor(app, results);

                % Update processing steps
                app.ProcessingStepsArea.Value = results.processing_steps';

                app.StatusLabel.Text = sprintf('Simulation complete. Leak %s. Est. position: %.2f m', ...
                    ternary_str(results.leak_detected, 'DETECTED', 'not detected'), ...
                    results.estimated_position);
                app.StatusLabel.FontColor = ternary_color(results.leak_detected);

            catch ME
                app.StatusLabel.Text = sprintf('ERROR: %s', ME.message);
                app.StatusLabel.FontColor = [1 0 0];
                warning(getReport(ME));
            end
        end

        % =============================================================
        %  UPDATE SIGNAL PLOTS
        % =============================================================
        function updateSignalPlots(app, t, sig_A, sig_B, results)
            % Sensor A
            ax = app.SensorAAxes;
            cla(ax);
            plot(ax, t * 1000, sig_A, 'Color', [0 0.4 0.8], 'LineWidth', 0.5);
            title(ax, 'Sensor A Signal (GPIO34 → ADC1\_CH6)', 'FontSize', 9);
            xlabel(ax, 'Time (ms)'); ylabel(ax, 'Amplitude (V)');
            grid(ax, 'on');
            set(ax, 'GridAlpha', 0.15);

            % Sensor B
            ax = app.SensorBAxes;
            cla(ax);
            plot(ax, t * 1000, sig_B, 'Color', [0.8 0.3 0], 'LineWidth', 0.5);
            title(ax, 'Sensor B Signal (GPIO35 → ADC1\_CH7)', 'FontSize', 9);
            xlabel(ax, 'Time (ms)'); ylabel(ax, 'Amplitude (V)');
            grid(ax, 'on');
            set(ax, 'GridAlpha', 0.15);
        end

        % =============================================================
        %  UPDATE GCC-PHAT PLOT
        % =============================================================
        function updateGCCPHATPlot(app, results)
            ax = app.GCCPHATAxes;
            cla(ax); hold(ax, 'on');

            lags_ms = results.gcc_lags * 1000;
            plot(ax, lags_ms, results.gcc_correlation, ...
                'Color', [0.1 0.5 0.1], 'LineWidth', 1);

            % Mark the estimated peak
            [~, pk_idx] = max(results.gcc_correlation);
            peak_lag_ms = lags_ms(pk_idx);
            peak_val = results.gcc_correlation(pk_idx);
            plot(ax, peak_lag_ms, peak_val, 'rv', ...
                'MarkerSize', 12, 'MarkerFaceColor', [1 0.2 0.2], 'LineWidth', 1.5);
            text(ax, peak_lag_ms, peak_val * 1.1, ...
                sprintf('  \\Deltat = %.3f ms', results.estimated_tdoa * 1000), ...
                'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.7 0 0]);

            % Zero-lag reference
            xline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);

            title(ax, 'GCC-PHAT Cross-Correlation (ESP32 Algorithm Output)', 'FontSize', 9);
            xlabel(ax, 'Lag (ms)'); ylabel(ax, 'Normalized Correlation');
            grid(ax, 'on');
            set(ax, 'GridAlpha', 0.15);
            hold(ax, 'off');
        end

        % =============================================================
        %  UPDATE OLED DISPLAY
        % =============================================================
        function updateOLEDDisplay(app, results)
            try
                oled_display(app.OLEDAxes, results.oled_data);
            catch
                % Fallback: simple text on black background
                ax = app.OLEDAxes;
                cla(ax);
                set(ax, 'Color', [0 0 0], 'XLim', [0 1], 'YLim', [0 1], ...
                    'XTick', [], 'YTick', []);
                fields = fieldnames(results.oled_data);
                for i = 1:min(6, length(fields))
                    y = 0.9 - (i-1) * 0.14;
                    txt = results.oled_data.(fields{i});
                    if contains(lower(txt), 'leak')
                        c = [1 0.3 0.1];
                    else
                        c = [0 1 0.8];
                    end
                    text(ax, 0.05, y, txt, 'Color', c, ...
                        'FontSize', 8, 'FontName', 'Consolas', ...
                        'Interpreter', 'none');
                end
            end
        end

        % =============================================================
        %  UPDATE LEDs AND BUZZER
        % =============================================================
        function updateLEDs(app, results)
            if results.led_green
                app.GreenLEDLamp.Color = [0 1 0.2];
            else
                app.GreenLEDLamp.Color = [0.2 0.3 0.2];
            end

            if results.led_red
                app.RedLEDLamp.Color = [1 0 0];
            else
                app.RedLEDLamp.Color = [0.3 0.2 0.2];
            end

            if results.buzzer_active
                app.BuzzerLamp.Color = [1 0.6 0];
                app.BuzzerLabel.Text = 'BUZZER: ON ♪ (GPIO5)';
                % Optional audio beep
                try
                    Fs_beep = 8000;
                    t_beep = 0:1/Fs_beep:0.15;
                    beep_sig = 0.3 * sin(2*pi*2000*t_beep);
                    sound(beep_sig, Fs_beep);
                catch
                    % Silently skip if audio unavailable
                end
            else
                app.BuzzerLamp.Color = [0.3 0.3 0.2];
                app.BuzzerLabel.Text = 'BUZZER: OFF (GPIO5)';
            end
        end

        % =============================================================
        %  UPDATE RESULTS TEXT
        % =============================================================
        function updateResultsText(app, results, params)
            lines = {};
            lines{end+1} = '══════════════════════════════';
            lines{end+1} = '    LOCALIZATION RESULTS';
            lines{end+1} = '══════════════════════════════';
            if isfield(results, 'true_tdoa') && ~isempty(results.true_tdoa)
                lines{end+1} = sprintf('True TDOA:       %+.4f ms', results.true_tdoa * 1000);
                lines{end+1} = sprintf('Estimated TDOA:  %+.4f ms', results.estimated_tdoa * 1000);
                lines{end+1} = sprintf('TDOA Error:      %.4f ms', abs(results.estimated_tdoa - results.true_tdoa) * 1000);
            else
                lines{end+1} = sprintf('Estimated TDOA:  %+.4f ms', results.estimated_tdoa * 1000);
            end
            lines{end+1} = '──────────────────────────────';
            lines{end+1} = sprintf('True Position:   %.2f m', params.leak_position);
            lines{end+1} = sprintf('Est. Position:   %.2f m', results.estimated_position);
            if isfield(results, 'localization_error') && ~isnan(results.localization_error)
                lines{end+1} = sprintf('Loc. Error:      %.2f m', results.localization_error);
                lines{end+1} = sprintf('Error (%%L):       %.2f %%', results.localization_error / params.pipeline_length * 100);
            end
            lines{end+1} = '──────────────────────────────';
            lines{end+1} = sprintf('Detection:       %s', ternary_str(results.leak_detected, 'LEAK DETECTED', 'NORMAL'));
            lines{end+1} = sprintf('Energy Ratio:    %.2f', results.energy_ratio);
            lines{end+1} = sprintf('Signal RMS A:    %.6f', results.signal_energy_A);
            lines{end+1} = sprintf('Signal RMS B:    %.6f', results.signal_energy_B);
            lines{end+1} = '══════════════════════════════';

            % Update UI text area
            app.ResultsArea.Value = lines';

            % Store for export
            app.LastResults.results_text = lines;
        end

        % =============================================================
        %  UPDATE SERIAL MONITOR
        % =============================================================
        function updateSerialMonitor(app, results)
            app.SerialMonitorArea.Value = results.serial_log';
        end

        % =============================================================
        %  RUN ALL 10 TEST CASES
        % =============================================================
        function runAllTests(app)
            app.StatusLabel.Text = 'Running all 10 test cases...';
            app.StatusLabel.FontColor = [0.1 0.3 0.7];
            drawnow;

            L = app.PipelineLengthSlider.Value;
            c = app.PropSpeedSlider.Value;
            fs = 10000;
            duration = 0.5;

            % Define 10 test cases as cell array
            tests = {
                'No Leakage',               L/2,      0.0,  0.02, 1.0, 1.0
                'Leak near Sensor A',       L*0.05,   0.5,  0.02, 1.0, 1.0
                'Leak near Sensor B',       L*0.95,   0.5,  0.02, 1.0, 1.0
                'Leak at Midpoint',         L*0.50,   0.5,  0.02, 1.0, 1.0
                'Leak at Unknown Position', L*0.37,   0.5,  0.02, 1.0, 1.0
                'Small Leak',               L*0.40,   0.1,  0.02, 1.0, 1.0
                'Medium Leak',              L*0.40,   0.5,  0.02, 1.0, 1.0
                'Large Leak',               L*0.40,   1.0,  0.02, 1.0, 1.0
                'Leak with High Noise',     L*0.35,   0.5,  0.20, 1.0, 1.0
                'Sensor Mismatch',          L*0.35,   0.5,  0.05, 0.7, 1.3
            };

            % Results storage
            TestName     = cell(10,1);
            TruePos      = zeros(10,1);
            EstPos       = zeros(10,1);
            LocError     = zeros(10,1);
            ErrorPercent = zeros(10,1);
            TrueTDOA     = zeros(10,1);
            EstTDOA      = zeros(10,1);
            Detected     = false(10,1);
            EnergyRatio  = zeros(10,1);
            Severity     = zeros(10,1);
            NoiseLevel   = zeros(10,1);

            for i = 1:10
                tc_name  = tests{i, 1};
                tc_pos   = tests{i, 2};
                tc_sev   = tests{i, 3};
                tc_noi   = tests{i, 4};
                tc_sensA = tests{i, 5};
                tc_sensB = tests{i, 6};

                app.StatusLabel.Text = sprintf('Test %d/10: %s...', i, tc_name);
                drawnow;

                % Generate signals
                p.pipeline_length      = L;
                p.leak_position        = tc_pos;
                p.propagation_speed    = c;
                p.sampling_rate        = fs;
                p.duration             = duration;
                p.leak_severity        = tc_sev;
                p.noise_level          = tc_noi;
                p.sensor_sensitivity_A = tc_sensA;
                p.sensor_sensitivity_B = tc_sensB;
                p.random_seed          = i * 42;   % Reproducible

                [sig_A, sig_B, t, true_tdoa, ~] = leak_signal_model(p);

                % Process through ESP32
                sp.pipeline_length     = L;
                sp.propagation_speed   = c;
                sp.sampling_rate       = fs;
                sp.detection_threshold = app.DetThresholdSlider.Value;
                sp.true_leak_position  = tc_pos;

                res = esp32_subsystem(sig_A, sig_B, sp);
                res.true_tdoa = true_tdoa;

                % Store results
                TestName{i}     = tc_name;
                TruePos(i)      = tc_pos;
                EstPos(i)       = res.estimated_position;
                LocError(i)     = res.localization_error;
                ErrorPercent(i) = res.localization_error / L * 100;
                TrueTDOA(i)     = true_tdoa * 1000;  % ms
                EstTDOA(i)      = res.estimated_tdoa * 1000;  % ms
                Detected(i)     = res.leak_detected;
                EnergyRatio(i)  = res.energy_ratio;
                Severity(i)     = tc_sev;
                NoiseLevel(i)   = tc_noi;
            end

            % Build results table
            app.TestResultsTable = table(TestName, Severity, NoiseLevel, ...
                TruePos, EstPos, LocError, ErrorPercent, ...
                TrueTDOA, EstTDOA, Detected, EnergyRatio, ...
                'VariableNames', {'TestCase', 'Severity', 'Noise', ...
                'TruePosition_m', 'EstPosition_m', 'Error_m', 'ErrorPercent', ...
                'TrueTDOA_ms', 'EstTDOA_ms', 'LeakDetected', 'EnergyRatio'});

            % Display in serial monitor
            serial_lines = {};
            serial_lines{end+1} = '============================================';
            serial_lines{end+1} = '        ALL 10 TEST CASE RESULTS';
            serial_lines{end+1} = '============================================';
            for i = 1:10
                serial_lines{end+1} = sprintf('Test %2d: %-25s', i, TestName{i}); %#ok<AGROW>
                serial_lines{end+1} = sprintf('  True: %6.1fm  Est: %6.1fm  Err: %5.2fm (%4.1f%%)', ...
                    TruePos(i), EstPos(i), LocError(i), ErrorPercent(i)); %#ok<AGROW>
                if Detected(i)
                    serial_lines{end+1} = sprintf('  Status: LEAK DETECTED  (ratio: %.1f)', EnergyRatio(i)); %#ok<AGROW>
                else
                    serial_lines{end+1} = sprintf('  Status: Normal         (ratio: %.1f)', EnergyRatio(i)); %#ok<AGROW>
                end
                serial_lines{end+1} = '--------------------------------------------'; %#ok<AGROW>
            end
            serial_lines{end+1} = '============================================';
            app.SerialMonitorArea.Value = serial_lines';

            % Update GUI with last test
            updateSignalPlots(app, t, sig_A, sig_B, res);
            updateGCCPHATPlot(app, res);
            updateOLEDDisplay(app, res);
            updateLEDs(app, res);

            app.StatusLabel.Text = sprintf('All 10 tests complete. Click EXPORT to save CSV.');
            app.StatusLabel.FontColor = [0 0.5 0.2];
        end

        % =============================================================
        %  EXPORT RESULTS
        % =============================================================
        function exportResults(app)
            if isempty(app.TestResultsTable)
                app.StatusLabel.Text = 'No test results to export. Run tests first.';
                app.StatusLabel.FontColor = [0.8 0.3 0];
                return;
            end

            results_dir = fullfile(app.ProjectDir, 'results');
            if ~exist(results_dir, 'dir')
                mkdir(results_dir);
            end

            timestamp = datestr(now, 'yyyy-mm-dd_HHMMSS');
            csv_path = fullfile(results_dir, sprintf('test_results_%s.csv', timestamp));
            writetable(app.TestResultsTable, csv_path);

            app.StatusLabel.Text = sprintf('Results exported to: %s', csv_path);
            app.StatusLabel.FontColor = [0 0.5 0.2];
        end

        % =============================================================
        %  RESET
        % =============================================================
        function resetApp(app)
            % Reset sliders to defaults
            app.PipelineLengthSlider.Value = 100;
            app.LeakPositionSlider.Value = 35;
            app.LeakPositionSlider.Limits = [0 100];
            app.LeakSeveritySlider.Value = 0.5;
            app.NoiseLevelSlider.Value = 0.02;
            app.PropSpeedSlider.Value = 1000;
            app.SensitivityASlider.Value = 1.0;
            app.SensitivityBSlider.Value = 1.0;
            app.DetThresholdSlider.Value = 3.0;

            % Update labels
            onSliderChanged(app);

            % Clear plots
            cla(app.SensorAAxes);
            cla(app.SensorBAxes);
            cla(app.GCCPHATAxes);

            % Reset LEDs
            app.GreenLEDLamp.Color = [0.3 0.3 0.3];
            app.RedLEDLamp.Color = [0.3 0.3 0.3];
            app.BuzzerLamp.Color = [0.3 0.3 0.3];
            app.BuzzerLabel.Text = 'BUZZER: OFF (GPIO5)';

            % Reset text areas
            app.ResultsArea.Value = {'Awaiting simulation...'};
            app.ProcessingStepsArea.Value = {'ESP32 subsystem idle...'};
            app.SerialMonitorArea.Value = {'[Serial] Waiting for data...'};

            app.TestResultsTable = table();
            app.StatusLabel.Text = 'Reset complete. Adjust parameters and click RUN SIMULATION.';
            app.StatusLabel.FontColor = [0.3 0.3 0.6];

            % Draw initial pipeline
            updatePipelineDiagram(app);
        end

    end

end

% =====================================================================
%  STANDALONE HELPER FUNCTIONS
% =====================================================================
function s = ternary_str(cond, a, b)
    if cond, s = a; else, s = b; end
end

function c = ternary_color(cond)
    if cond, c = [0.8 0 0]; else, c = [0 0.6 0.2]; end
end
