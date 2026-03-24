# Cognitive-Assistive Hearing Device
### Speech Enhancement and Sound Isolation for ADHD

A complete **end-to-end FPGA implementation** of a 4-microphone MVDR beamformer with adaptive post-processing for individuals with ADHD and sensorineural hearing loss.

---

## Overview

Standard hearing aids amplify all sounds indiscriminately. This project implements a **Minimum Variance Distortionless Response (MVDR)** spatial filter with a full DSP post-processing chain, achieving **+14.1 dB SNR improvement** over a single microphone — more than 3× better than conventional delay-and-sum beamforming.

The entire pipeline runs on a **DE10-Lite FPGA** (Intel MAX 10) with no external DSP processors.

---

## System Architecture

```
4× INMP441 I2S MEMS Microphones (2cm spacing)
              │
    ┌─────────▼─────────┐
    │  i2s_master_clk   │  BCLK + WS generation
    │  i2s_rx (×2)      │  4-channel 24-bit capture
    │  cic_decimator(×4)│  3.072MHz → 16kHz, R=192
    │  fft_r2dit (×4)   │  256-point FFT, Hann window
    │  covariance_est   │  R(k) = α·R(k) + x(k)·x(k)ᴴ
    │  mvdr_weights     │  w = R⁻¹·d / (dᴴ·R⁻¹·d)
    │  beamformer_apply │  Y(k) = wᴴ·X(k)
    │  ifft_r2dit       │  Inverse FFT
    │  overlap_add      │  50% overlap-add reconstruction
    ├───────────────────┤
    │  vad              │  Voice Activity Detection
    │  lms_filter       │  32-tap LMS adaptive filter
    │  spectral_sub     │  Spectral subtraction
    │  compressor       │  Dynamic range compression
    │  freq_shaper      │  1–5 kHz FIR boost (16-tap)
    │  i2s_tx           │  I2S output to PAM8403
    └─────────▼─────────┘
         PAM8403 Amplifier → Speaker/Bone Conduction
```

---

## Performance Results

| Configuration | SNR Improvement |
|---|---|
| Raw microphone (baseline) | 0.0 dB |
| 2-mic Delay-and-Sum | +2.2 dB |
| 4-mic Delay-and-Sum | +3.9 dB |
| 2-mic MVDR | +6.0 dB |
| **4-mic MVDR (this project)** | **+14.1 dB** |

Beam pattern: deep nulls (~55 dB) at noise source angles (−45° and +60°), 0 dB at target (0°).

---

## Design Parameters

| Parameter | Value |
|---|---|
| Sample rate | 16 kHz |
| FFT size | 256 points (8 ms frame) |
| Hop size | 128 samples (50% overlap) |
| Window | Periodic Hann |
| Data format | 16-bit Q1.15 fixed-point |
| Mic spacing | 2 cm |
| Forgetting factor α | 0.95 |
| Diagonal loading δ | 0.5 |
| Target direction | 0° (broadside) |
| Null directions | −45°, +60° |
| LMS filter taps | 32 |
| LMS step size μ | 0.001 |
| FIR boost band | 1–5 kHz (+6 dB) |

---

## Repository Structure

```
cognitive-assistive-hearing-device/
│
├── VERILOG/                        # FPGA Verilog Implementation
│   │
│   ├── ── Front End ──
│   ├── i2s_master_clk.v            # BCLK + WS clock generation
│   ├── i2s_rx.v                    # 4-channel I2S receiver
│   ├── cic_decimator.v             # CIC decimation filter R=192
│   │
│   ├── ── Frequency Domain ──
│   ├── butterfly.v                 # Radix-2 DIT butterfly unit
│   ├── twiddle_rom.v               # FFT twiddle factor ROM
│   ├── fft_r2dit.v                 # 256-point FFT
│   ├── ifft_r2dit.v                # 256-point IFFT
│   │
│   ├── ── MVDR Beamformer ──
│   ├── covariance_est.v            # 4×4 spatial covariance estimator
│   ├── mvdr_weights.v              # Gauss-Jordan MVDR weight solver
│   ├── beamformer_apply.v          # Apply weights: Y(k) = wᴴ·X(k)
│   ├── overlap_add.v               # 50% overlap-add reconstruction
│   │
│   ├── ── Post-Processing ──
│   ├── vad.v                       # Voice Activity Detection
│   ├── lms_filter.v                # 32-tap LMS adaptive filter
│   ├── spectral_sub.v              # Spectral subtraction
│   ├── compressor.v                # Dynamic range compressor
│   ├── freq_shaper.v               # 16-tap FIR 1-5kHz boost
│   ├── i2s_tx.v                    # I2S transmitter to PAM8403
│   │
│   ├── ── Integration ──
│   └── top_level.v                 # Full system top level
│
├── MATLAB/                         # Algorithm Simulation
│   ├── vad_lms/
│   │   ├── fixed_lms.m             # LMS adaptive filter simulation
│   │   └── vad_detection.m         # VAD algorithm simulation
│   └── spectral_drc_fir/
│       ├── spectral_sub.m          # Spectral subtraction simulation
│       └── compression_freqshape.m # DRC + FIR frequency shaping
│
└── README.md
```

---

## Verification Status

All 15 Verilog modules are individually verified with dedicated testbenches.

| Module | Tests | Status |
|---|---|---|
| `i2s_rx.v` | 4/4 | ✅ PASS |
| `cic_decimator.v` | 2/2 | ✅ PASS |
| `butterfly.v` | 3/3 | ✅ PASS |
| `fft_r2dit.v` | 2/2 | ✅ PASS |
| `covariance_est.v` | 7/7 | ✅ PASS |
| `mvdr_weights.v` | 9/9 | ✅ PASS |
| `beamformer_apply.v` | 7/7 | ✅ PASS |
| `ifft_r2dit.v` | 4/4 | ✅ PASS |
| `overlap_add.v` | 5/5 | ✅ PASS |
| `vad.v` | 2/2 | ✅ PASS |
| `lms_filter.v` | 3/3 | ✅ PASS |
| `spectral_sub.v` | 3/3 | ✅ PASS |
| `compressor.v` | 4/4 | ✅ PASS |
| `freq_shaper.v` | 3/3 | ✅ PASS |
| `i2s_tx.v` | 3/3 | ✅ PASS |

---

## How to Simulate

### Requirements
- [Icarus Verilog](http://iverilog.icarus.com/) (iverilog)
- [GTKWave](http://gtkwave.sourceforge.net/) (waveform viewer)
- MATLAB R2020+ with Signal Processing Toolbox (for MATLAB scripts)

### Compile and Run Any Testbench

```powershell
cd VERILOG

# Example — FFT
iverilog -o a.out fft_r2dit_tb.v fft_r2dit.v && vvp a.out

# Example — MVDR weights
iverilog -o a.out mvdr_weights_tb.v mvdr_weights.v && vvp a.out

# Example — Full post-processing chain
iverilog -o a.out vad_tb.v vad.v && vvp a.out
iverilog -o a.out lms_filter_tb.v lms_filter.v && vvp a.out
iverilog -o a.out spectral_sub_tb.v spectral_sub.v && vvp a.out
iverilog -o a.out compressor_tb.v compressor.v && vvp a.out
iverilog -o a.out freq_shaper_tb.v freq_shaper.v && vvp a.out
iverilog -o a.out i2s_tx_tb.v i2s_tx.v && vvp a.out
```

### View Waveforms
```powershell
gtkwave fft_r2dit.vcd
```

### CIC Decimator (uses `include)
```powershell
iverilog -o a.out cic_decimator_tb.v && vvp a.out
```

---

## Hardware

### Target Platform
- **FPGA:** Intel MAX 10 (DE10-Lite development board)
- **Tool:** Quartus Prime Lite

### Bill of Materials

| Component | Part | Qty | Purpose |
|---|---|---|---|
| MEMS Microphone | INMP441 (I2S) | 4 | Audio capture |
| Audio Amplifier | PAM8403 | 1 | Drive speaker |
| Speaker | 4Ω / 8Ω | 1 | Audio output |
| FPGA Board | DE10-Lite | 1 | Signal processing |
| Jumper Wires | M-F | 1 pack | Connections |
| Breadboard | — | 1 | Prototyping |

### Key Hardware Facts
- INMP441 runs at 3.3V — direct connect to DE10-Lite GPIO (no level shifting)
- PAM8403 powered from 5V pin on GPIO header
- 4 mics spaced 2 cm apart in linear array

---

## Novel Contributions

1. **Complete FPGA pipeline** — full chain from raw I2S mic capture to processed audio output, all in synthesizable Verilog-2001, no IP cores
2. **4-mic MVDR on student hardware** — runs on DE10-Lite (MAX 10), not expensive RF-SoC or Xilinx dev boards
3. **Cognitive-assistive application** — MVDR spatial filtering targeted specifically for ADHD users with sensorineural hearing loss
4. **Zero multiplier CIC decimation** — pure adder-based sample rate conversion (3.072 MHz → 16 kHz)
5. **Portable implementation** — no vendor IP, no HDL Coder, compiles with open-source iverilog

---

## Authors

| Name | Contribution |
|---|---|
| **Daksh Razdan** | FPGA Verilog pipeline — I2S, CIC, FFT, MVDR, IFFT, OLA, VAD, LMS, Spectral Sub, DRC, FIR, I2S TX |
| **Deekshith Balaji** | MATLAB algorithm simulation — VAD, LMS adaptive filtering |
| **S. Kavin Pragash** | MATLAB algorithm simulation — Spectral subtraction, DRC, frequency shaping |

---

## References

1. J. Capon, "High-resolution frequency-wavenumber spectrum analysis," *Proceedings of the IEEE*, vol. 57, pp. 1408–1418, 1969.
2. G. Jayawardena et al., "Audiovisual Speech-In-Noise (SIN) Performance of Young Adults with ADHD," *ETRA '20*, ACM, 2020.
3. R. A. Barkley, "Behavioral inhibition, sustained attention, and executive functions," *Psychological Bulletin*, vol. 121, no. 1, pp. 65–94, 1997.
4. V. Duhan, R. Boora, and M. Jangra, "Speech Enhancement Filters: A Comparative Study," *IJERT*, vol. 14, no. 11, 2025.
5. B. Widrow and F.-L. Luo, "Microphone arrays for hearing aids: An overview," *Speech Communication*, vol. 39, pp. 139–146, 2003.
