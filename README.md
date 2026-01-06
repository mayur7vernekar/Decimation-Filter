# 3-Stage Decimation Filter Chain

## Project Overview

This project implements a cascaded three-stage decimation filter architecture for high-speed signal decimation. The design includes RTL implementation in Verilog HDL with complete ASIC physical design flow from gate-level synthesis to placed-and-routed layout.

### Technical Specifications

- **Input Signal:** 1-bit stream at 81.92 kHz
- **Output Signal:** 24-bit decimated signal at 1.28 kHz
- **Total Decimation Factor:** 64x (8x, 2x, 4x cascaded)
- **Target Performance:** SNR > 100 dB, ENOB > 16 bits
- **Architecture:** Cascaded CIC filters with FIR polyphase decimator
- **Implementation:** Complete ASIC design flow from RTL to placed-and-routed physical design

---

## Project Directory Structure

```
Decimation-Filter/
├── README.md
├── MATLAB/
│   ├── DSM2_Final.m                    # 3rd-order DSM modulator implementation
│   └── DecimationFilter_final.m        # Filter chain with SNR/ENOB verification
├── RTL (HDL) Code and Simulation/
│   ├── README_RTL.md
│   ├── rtl/
│   │   └── dsm_decimation_chain.v      # Top-level hierarchical Verilog design
│   └── SIM/
│       ├── tb_filter.v                 # SystemVerilog testbench
│       ├── dsm_input.txt               # Simulation stimulus file
│       └── Verify_Output.m             # RTL output verification script
├── ASIC flow/
│   ├── dsm_decimation_chain.mapped.v   # Gate-level netlist (post-synthesis)
│   ├── dsm_decimation_chain_.def       # Design Exchange Format (layout)
│   ├── dsm_decimation_chain_.routed.v  # Routed netlist (post-P&R)
│   └── dsm_decimation_chain_.routed.sdc # Synopsys Design Constraints
└── Images/
    ├── RTL Schematic.png
    ├── Placement_Layout.png
    ├── Routing.png
    ├── Floorpan_View.png
    ├── Power_Plan.png
    ├── CTS.png
    └── Simulation Result.png
```

---

## System Architecture

### Signal Processing Pipeline

The system implements a three-stage cascade decimation architecture:

```
1-bit DSM Input @ 81.92 kHz
           ↓
    CIC Filter Stage 1 (R=8, N=7)
    81.92 kHz → 10.24 kHz, 32-bit output
           ↓
    CIC Filter Stage 2 (R=2, N=7)
    10.24 kHz → 5.12 kHz, 32-bit output
           ↓
    Bit-width Scaling (24-bit truncation)
           ↓
    FIR Filter Stage 3 (R=4, 120 taps)
    5.12 kHz → 1.28 kHz, 24-bit output
           ↓
24-bit PCM Output @ 1.28 kHz
```

### Module Hierarchy

The design employs a hierarchical modular architecture:

```
tb_filter (Testbench)
├── dsm_decimation_chain (Top-Level Module)
│   ├── cic_decimator_r8_n7 (Stage 1)
│   ├── cic_decimator_r2_n7 (Stage 2)
│   └── fir_decimator_r4 (Stage 3)
```

---

## Design Specifications

| Parameter | Value | Description |
|-----------|-------|-------------|
| Input Sample Rate | 81.92 kHz | 1-bit PDM from Delta-Sigma modulator |
| Output Sample Rate | 1.28 kHz | 24-bit PCM audio |
| Total Decimation Ratio | 64x | Product of individual stage decimations |
| Input Bit-Width | 1-bit | Delta-Sigma modulated single bit |
| Output Bit-Width | 24-bit | Two's complement signed integer |
| Target SNR | > 100 dB | Signal-to-Noise Ratio specification |
| Target ENOB | > 16 bits | Effective Number of Bits |
| Signal Frequency | 80 Hz | Baseband signal under test |
| Noise Integration Bandwidth | 80 Hz | Nyquist bandwidth of interest |

---

## Implementation Details

### Stage 1: CIC Decimator (Decimate by 8, Order 7)

**Input:** 81.92 kHz, 1-bit
**Output:** 10.24 kHz, 32-bit
**Function:** Coarse decimation with integrated noise filtering

### Stage 2: CIC Decimator (Decimate by 2, Order 7)

**Input:** 10.24 kHz, 32-bit
**Output:** 5.12 kHz, 32-bit
**Function:** Further decimation with anti-aliasing characteristics

### Stage 3: FIR Decimator (Decimate by 4, 120 Taps)

**Input:** 5.12 kHz, 24-bit (scaled from CIC output)
**Output:** 1.28 kHz, 24-bit
**Function:** Final anti-aliasing filter with polyphase decimation structure

---

## Implementation Methodology

### RTL Design (Verilog HDL)

The design provides synthesizable hardware description with complete simulation infrastructure:

**Simulator:** Synopsys VCS
**Debugging Tool:** Synopsys Verdi
**Language:** Verilog 2001

Compile and simulate:
```
vcs -full64 -sverilog -gui tb_filter.v dsm_decimation_chain.v
```

### ASIC Design Flow

The project includes complete ASIC implementation:

- **Logic Synthesis:** Gate-level netlist generation (`dsm_decimation_chain.mapped.v`)
- **Place & Route:** Physical cell placement and routing (`dsm_decimation_chain_.routed.v`)
- **Timing Closure:** SDC constraints for timing specifications (`dsm_decimation_chain_.routed.sdc`)
- **Layout Definition:** DEF format describing physical design

---

## Verification and Performance

### RTL Simulation Performance

- **Achieved SNR:** 105.42 dB
- **Achieved ENOB:** 17.14 bits
- Output successfully verified through simulation

### Verification Files

| File | Purpose |
|------|---------|
| `dsm_input.txt` | Simulation input stimulus |
| `pcm_verify_output.csv` | RTL output samples |
| `inter.fsdb` | Waveform database |

---

## File Inventory

**Verilog RTL:**
- `dsm_decimation_chain.v` - Top-level module with three filter stages
- `tb_filter.v` - Testbench for simulation

**ASIC Design:**
- `dsm_decimation_chain.mapped.v` - Gate-level netlist
- `dsm_decimation_chain_.routed.v` - Routed netlist
- `dsm_decimation_chain_.def` - Layout definition
- `dsm_decimation_chain_.routed.sdc` - Timing constraints

**Verification:**
- `dsm_input.txt` - Input stimulus
- `Verify_Output.m` - Output analysis

---