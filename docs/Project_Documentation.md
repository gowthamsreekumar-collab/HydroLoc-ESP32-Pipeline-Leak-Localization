# Project Documentation: ESP32 Water Pipeline Leak Detection and Exact Localization System

**Academic Project Title:**  
*Intelligent Water Pipeline Leakage Detection and Exact Leak Localization Using ESP32 and Two-Sensor TDOA Technique*

---

## 1. Executive Summary & Hardware Project Philosophy

This project provides a hardware-level simulation and embedded algorithm prototype for detecting and localizing fluid leaks along pressurized water transport pipelines. 

Unlike purely mathematical demonstrations or synthetic curve fittings, this project models:
1. **The physical acoustic wave emission and propagation** caused by turbulent fluid ejection at an orifice.
2. **Piezoelectric / acoustic emission sensor front-ends** with frequency response, acoustic attenuation, and analog conditioning (gain, DC bias, anti-aliasing).
3. **ESP32 microcontroller embedded peripherals** (12-bit successive-approximation ADC, input pin multiplexing, I2C master bus, GPIO digital outputs, and PWM timer peripheral).
4. **On-chip digital signal processing algorithms** (DC removal, Butterworth bandpass filtering, Hanning windowing, and Generalized Cross-Correlation with Phase Transform — GCC-PHAT).
5. **Exact time difference of arrival (TDOA) geometry** yielding leak position in meters from a reference datum.
6. **Hardware output indication** including a SSD1306 128×64 OLED display, dual-color LED status indicators, a piezo buzzer audio alarm, and 115200 baud UART serial telemetry.

---

## 2. Hardware Architecture & Electronic Component Specifications

### 2.1 Microcontroller: ESP32-WROOM-32
- **Core Architecture:** Tensilica Xtensa Dual-Core 32-bit LX6 microprocessor @ 240 MHz.
- **Memory:** 520 KB SRAM, 4 MB SPI Flash.
- **ADC Subsystem:** ADC1 peripheral chosen deliberately. ADC2 is shared with the Wi-Fi subsystem and would suffer from channel contention or dropping during RF transmissions.
- **Operating Voltage:** 3.3 V DC logic level.

### 2.2 Transducers: Acoustic Emission / Piezoelectric Sensors
- **Placement:** Sensor A at $x = 0$ m (upstream anchor); Sensor B at $x = L$ m (downstream anchor).
- **Measurement Mode:** High-frequency vibration and pressure wave transients propagating longitudinally along the pipe wall and water column.
- **Analog Conditioning:** Piezoelectric crystal output is conditioned via low-noise operational amplifier (charge amplifier / instrumentation stage) with $V_{ref}/2$ (1.65 V) DC offset bias and bandpass filtering (100 Hz – 3000 Hz) to fit comfortably within the 0 to 3.3 V ADC input span.

### 2.3 Peripheral Display & Indicators
- **OLED Display:** 0.96-inch SSD1306 monochrome OLED (128×64 pixels) over I2C bus (`0x3C` 7-bit slave address).
- **Visual Alert:** 5 mm Green LED (Normal state, GPIO2) and Red LED (Leak detected state, GPIO4) powered through 220 $\Omega$ current-limiting resistors ($\approx 5.9$ mA drive current).
- **Auditory Alarm:** 5 V / 3.3 V Piezo buzzer driven through GPIO5 using LEDC PWM timer modulation at 2.0 kHz resonant frequency.
- **UART Diagnostic Telemetry:** UART0 operating at 115,200 baud, 8-N-1 formatting for continuous serial telemetry to SCADA or host computer.

---

## 3. GPIO Assignment & Electrical Interconnection Table

| ESP32 Pin | Subsystem / Hardware | Signal Direction | Electrical Standard | Function / Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **GPIO 34** | Sensor A Front-End | Input Only | Analog (0 – 3.3 V) | Connected to ADC1_CH6; samples upstream acoustic signal. |
| **GPIO 35** | Sensor B Front-End | Input Only | Analog (0 – 3.3 V) | Connected to ADC1_CH7; samples downstream acoustic signal. |
| **GPIO 21** | SSD1306 OLED Display | Bidirectional | I2C Data (SDA, 3.3 V) | Carries display telemetry frames (I2C bus, 4.7 k$\Omega$ pull-ups). |
| **GPIO 22** | SSD1306 OLED Display | Output | I2C Clock (SCL, 3.3 V) | Synchronous clock line up to 400 kHz Fast-Mode. |
| **GPIO 2** | Green Status LED | Output | Digital Push-Pull (3.3 V) | High when pipeline pressure is steady and no leak detected. |
| **GPIO 4** | Red Alert LED | Output | Digital Push-Pull (3.3 V) | High during leak event detection. |
| **GPIO 5** | Piezo Buzzer | Output | PWM / LEDC (3.3 V) | Generates 2.0 kHz alarm tone upon threshold breach. |
| **GPIO 1** | USB-UART Bridge | Output | Digital (TXD0) | Serial telemetry transmitter at 115,200 baud. |
| **GPIO 3** | USB-UART Bridge | Input | Digital (RXD0) | Serial command receiver. |
| **3V3** | Power Distribution | Power Rail | 3.3 V DC ($\pm 5\%$) | Regulated supply from AMS1117-3.3 LDO to OLED & sensor op-amps. |
| **GND** | Ground Plane | Common Return | 0 V Reference | Star ground uniting digital MCU, analog sensor, and display return. |
| **VIN** | External DC Source | Power In | 5.0 V DC | USB bus voltage or external 5 V power pack feeding onboard regulator. |

---

## 4. Mathematical Derivation of the Two-Sensor TDOA Localization Equation

Let the straight pipeline segment bounded by Sensor A and Sensor B have length $L$ meters.
We establish a one-dimensional coordinate frame with:
- **Sensor A positioned at origin:** $x_A = 0$
- **Sensor B positioned at terminal:** $x_B = L$
- **Acoustic wave propagation velocity:** $c$ (m/s)

Suppose a turbulent leak occurs at an unknown coordinate $x_{leak}$ where $0 \le x_{leak} \le L$.

### 4.1 Acoustic Arrival Times
The distance from the leak source to Sensor A is:
$$d_A = x_{leak}$$
The distance from the leak source to Sensor B is:
$$d_B = L - x_{leak}$$

Assuming constant effective wave speed $c$ through the pipe fluid-structure coupled system, the acoustic propagation travel times are:
$$t_A = \frac{d_A}{c} = \frac{x_{leak}}{c}$$
$$t_B = \frac{d_B}{c} = \frac{L - x_{leak}}{c}$$

### 4.2 Time Difference of Arrival ($\Delta t$) Definition
We define the TDOA ($\Delta t$) as the difference in arrival times:
$$\Delta t \triangleq t_A - t_B$$

Substituting the travel time expressions:
$$\Delta t = \frac{x_{leak}}{c} - \frac{L - x_{leak}}{c} = \frac{2 x_{leak} - L}{c}$$

### 4.3 Solving for the Unknown Leak Coordinate ($x_{leak}$)
Multiplying both sides by propagation velocity $c$:
$$c \cdot \Delta t = 2 x_{leak} - L$$
$$2 x_{leak} = L + c \cdot \Delta t$$
$$\boxed{x_{leak} = \frac{L + c \cdot \Delta t}{2}}$$

### 4.4 Boundary Physical Limits and Sign Convention Verification
1. **Leak directly at Sensor A ($x_{leak} = 0$):**
   $$\Delta t = \frac{0 - L}{c} = -\frac{L}{c} \implies x = \frac{L + c(-L/c)}{2} = 0 \quad \text{[Consistent]}$$
2. **Leak exactly at Midpoint ($x_{leak} = L/2$):**
   $$\Delta t = \frac{2(L/2) - L}{c} = 0 \implies x = \frac{L + 0}{2} = \frac{L}{2} \quad \text{[Consistent]}$$
3. **Leak directly at Sensor B ($x_{leak} = L$):**
   $$\Delta t = \frac{2L - L}{c} = +\frac{L}{c} \implies x = \frac{L + c(+L/c)}{2} = L \quad \text{[Consistent]}$$

---

## 5. Generalized Cross-Correlation with Phase Transform (GCC-PHAT) Algorithm

Standard cross-correlation suffers from peak broadening and false local maxima due to reverberation, pipe resonance, and dispersive wave modes. GCC-PHAT solves this by whitening the cross-power spectrum:

1. **Windowed Fast Fourier Transforms:**
   Compute discrete spectra $X_A(f) = \mathcal{F}\{x_A[n] \cdot w[n]\}$ and $X_B(f) = \mathcal{F}\{x_B[n] \cdot w[n]\}$ using a Hanning window $w[n]$ to prevent spectral leakage.
2. **Cross-Power Spectral Density:**
   $$G_{AB}(f) = X_A(f) \cdot X_B^*(f)$$
3. **PHAT Normalization (Phase Transform):**
   $$\Psi_{PHAT}(f) = \frac{1}{|G_{AB}(f)| + \epsilon}$$
   $$G_{PHAT}(f) = \frac{G_{AB}(f)}{|G_{AB}(f)| + \epsilon} = e^{j(\theta_A(f) - \theta_B(f))}$$
4. **Inverse Fourier Transformation:**
   $$R_{AB}^{PHAT}[\tau] = \mathcal{F}^{-1}\left\{ e^{j(\theta_A(f) - \theta_B(f))} \right\}$$
5. **Peak Detection & Sub-Sample Parabolic Interpolation:**
   Locate coarse integer sample lag $k^* = \arg\max_k R_{AB}^{PHAT}[k]$.
   Refine using 3-point parabolic peak interpolation:
   $$\delta = \frac{R[k^*-1] - R[k^*+1]}{2(R[k^*-1] - 2R[k^*] + R[k^*+1])}$$
   $$\hat{\Delta t} = \frac{k^* + \delta}{f_s}$$

---

## 6. Implementation and Execution Guide

### 6.1 Interactive App Designer Mode
Run the master GUI from MATLAB command prompt:
```matlab
main_simulation
% Choose Option 1 (or type: app = PipelineLeakDetectionApp;)
```
The application provides real-time slider controls for:
- Pipeline Length (10 – 500 m)
- Leak Position (0 – L m)
- Leak Severity (0.0 to 1.0)
- Noise Level & Sensor Sensitivities
- Real-time updates to virtual OLED, LEDs, buzzer, waveform axes, and serial terminal.

### 6.2 Automated Test Suite Execution
To run all 10 standard test scenarios and generate CSV tables and summary plots:
```matlab
run_all_tests(true)
```

### 6.3 Hardware Circuit Diagram Generation
```matlab
circuit_diagram('results/circuit_diagram.png')
```

### 6.4 Simulink Model Generation
```matlab
create_simulink_model()
```

---

## 7. Model Classification and Academic Defense Rigor

To satisfy academic project defense requirements, the simulation components are rigorously classified:

| Component | Simulation Type | Technical Realization |
| :--- | :--- | :--- |
| **Water Pipe & Leak Dynamics** | Physics / Hydraulics | Simscape Fluids orifice model + continuous 1D acoustic wave dispersion. |
| **Piezoelectric Transducers** | Functional Model | Charge amp transfer function, 100–3000 Hz Butterworth bandpass, distance-dependent $1/\sqrt{d}$ attenuation, independent Gaussian noise. |
| **ESP32 ADC & Sampling** | Functional Model | 12-bit quantizer ($3.3/4095$ V/step), 0–3.3V rail clamping, and 10 kHz discrete-time sampler. |
| **Embedded DSP Firmware** | Algorithm Exact Model | Integer-reproducible Butterworth IIR filtering, zero-padded radix-2 FFT, GCC-PHAT spectral division, sub-sample parabolic estimator. |
| **OLED & Alert Devices** | Visual & Auditory Emulation | Virtual SSD1306 framebuffer renderer, digital logic states for LEDs, and audio tone synthesizer. |

---
*Developed for Academic Embedded Systems Evaluation — ESP32 Pipeline Leak Detection.*
