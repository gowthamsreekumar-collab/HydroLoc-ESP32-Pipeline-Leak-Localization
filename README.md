# Intelligent Water Pipeline Leakage Detection and Exact Localization System
### Embedded Systems Hardware Simulation using ESP32 and Two-Sensor TDOA (GCC-PHAT)

Developed for MATLAB R2025b with Simulink, Simscape, and DSP System Toolbox.

---

## Quick Start Instructions

1. **Launch MATLAB R2025b**.
2. Set the current directory to:
   ```matlab
   cd('c:\Users\Gowtham\OneDrive\Dokumen\New folder\ESP32_Pipeline_Leak_Detection')
   ```
3. Run the master launcher script:
   ```matlab
   main_simulation
   ```
4. Choose an option from the menu:
   - **`1`**: Launch the full interactive App Designer simulation (`PipelineLeakDetectionApp`).
   - **`2`**: Run all 10 standard test scenarios and generate reports.
   - **`3`**: Generate the hardware circuit diagram (`circuit_diagram.png`).
   - **`4`**: Build the Simulink/Simscape model (`Pipeline_System_Model.slx`).
   - **`5`**: Run a quick command-line single test with plots.

---

## Project Structure

```
ESP32_Pipeline_Leak_Detection/
├── main_simulation.m              # Master interactive CLI entry point
├── PipelineLeakDetectionApp.m     # Full App Designer interactive GUI
│
├── algorithms/                    # Core mathematical and DSP models
│   ├── gcc_phat.m                 # Generalized Cross-Correlation with Phase Transform
│   ├── tdoa_localization.m        # Geometry equation: x = (L + c*dt) / 2
│   ├── leak_signal_model.m        # Acoustic wave propagation & turbulence model
│   └── sensor_model.m             # Piezo transducer front-end & 12-bit ADC quantization
│
├── hardware_model/                # ESP32 and peripheral models
│   ├── esp32_subsystem.m          # ESP32 dual-core functional processing chain
│   ├── gpio_config.m              # ESP32-WROOM-32 pin mapping table & electrical parameters
│   └── oled_display.m             # SSD1306 128x64 I2C virtual OLED display driver
│
├── diagrams/                      # Circuit & hardware schematic tools
│   └── circuit_diagram.m          # Programmatic hardware wiring & schematic renderer
│
├── models/                        # Simulink & physical modeling
│   └── create_simulink_model.m    # Script to build Pipeline_System_Model.slx
│
├── tests/                         # Comprehensive validation suite
│   └── run_all_tests.m            # 10 benchmark test cases covering noise, position & severity
│
├── results/                       # Auto-generated CSVs, logs, and plots
│   ├── test_results.csv           # Benchmark results table
│   ├── test_results_summary.png   # 4-panel test performance dashboard
│   └── circuit_diagram.png        # High-resolution hardware wiring diagram
│
└── docs/                          # Academic documentation & derivations
    └── Project_Documentation.md   # Complete system report, equations & hardware analysis
```

---

## Hardware Pin Connections (ESP32-WROOM-32)

| ESP32 Pin | Function | Peripheral | Notes |
|:---|:---|:---|:---|
| **GPIO 34** | ADC1_CH6 | Sensor A (Upstream) | Input-only analog pin, 0–3.3V |
| **GPIO 35** | ADC1_CH7 | Sensor B (Downstream) | Input-only analog pin, 0–3.3V |
| **GPIO 21** | I2C SDA | SSD1306 OLED Display | 3.3V data line, 4.7kΩ pull-up |
| **GPIO 22** | I2C SCL | SSD1306 OLED Display | 3.3V clock line, 4.7kΩ pull-up |
| **GPIO 2** | Digital Out | Green LED | Normal status indicator (220Ω resistor) |
| **GPIO 4** | Digital Out | Red Alert LED | Leak alarm indicator (220Ω resistor) |
| **GPIO 5** | PWM / LEDC | Piezo Buzzer | 2.0 kHz acoustic alarm tone |
| **GPIO 1 / 3**| UART0 | Serial Terminal | 115,200 baud diagnostic monitor |

---

## Academic Verification Summary

- **Equation:** $x_{leak} = \frac{L + c \cdot \Delta t}{2}$
- **Coordinate Datum:** Sensor A is at $0.0$ m; Sensor B is at $L$ m.
- **TDOA Convention:** $\Delta t = t_A - t_B = \frac{2 x_{leak} - L}{c}$.
- **GCC-PHAT Weighting:** $W(f) = \frac{1}{|X_A(f) X_B^*(f)| + \epsilon}$.
