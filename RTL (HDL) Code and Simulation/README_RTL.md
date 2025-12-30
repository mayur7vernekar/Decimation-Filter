# 3-Stage Decimation Filter Chain - RTL Simulation

## Project Overview
This project implements a **3-Stage Decimation Filter Chain** (CIC-CIC-FIR) in Verilog HDL. The system converts a high-speed **1-bit Delta-Sigma Modulated (DSM)** input into a high-precision **24-bit PCM audio** output. 

The simulation verifies the bit-true performance of the filter using **Synopsys VCS** for compilation and **Verdi** for waveform debugging.

### Design Specifications
*   **Input:** 1-bit PDM Stream @ 81.92 kHz
*   **Output:** 24-bit PCM Audio @ 1.28 kHz
*   **Decimation Factor:** 64x (8x -> 2x -> 4x)
*   **Target Performance:** SNR > 100 dB, ENOB > 16 bits

---

## Module Hierarchy
The design is structured hierarchically under the top-level testbench.

tb_filter (Testbench)
├── u_dut (dsm_decimation_chain) [Top Level Design]
│ ├── u_cic1 (cic_decimator_r8_n7) [Stage 1: Decimate by 8]
│ ├── u_cic2 (cic_decimator_r2_n7) [Stage 2: Decimate by 2]
│ └── u_fir (fir_decimator_r4) [Stage 3: Decimate by 4]

## Simulation Environment
*   **Simulator:** Synopsys VCS (Verilog Compiler Simulator)
*   **Debugger/Viewer:** Synopsys Verdi
*   **Shell:** C-Shell (`csh`)
*   **Language:** SystemVerilog / Verilog 2001

---

## Simulation Files
### 1. Source Code
*   `dsm_decimation_chain.v`: Top-level filter chain logic.
*   `tb_filter.v`: Testbench that reads input file, drives DUT, and logs output.

### 2. Input Data
*   `dsm_input.txt`: Input stimulus file containing the 1-bit DSM stream (generated via MATLAB).

### 3. Output Data
*   `pcm_verify_output.csv`: Simulation log containing the 24-bit output samples for verification.
*   `inter.fsdb`: Waveform database created by VCS/Verdi.

---

## Simulation Steps

### Step 1: Environment Setup
Open a terminal and switch to C-Shell (if required by your environment setup script).

csh
source /home/synopsys/cshrc

### Step 2: Compile and Run (Interactive GUI Mode)
Use the following VCS command to compile the design and immediately launch the Verdi GUI for debugging.

**Command Breakdown:**
*   `-R`: Run simulation executable immediately after compilation.
*   `-kdb`: Generate Knowledge Database (required for Verdi debugging features).
*   `-full64`: Run in 64-bit mode.
*   `+lint=all`: Enable all linting checks (detects synthesis/logic warnings).
*   `-sverilog`: Enable SystemVerilog support.
*   `-gui`: Launch Verdi GUI upon execution.

### Step 3: Waveform Debugging in Verdi
1.  Once Verdi opens, locate the signal hierarchy pane on the left.
2.  Expand `tb_filter` -> `u_dut`.
3.  Drag signals (`dsm_in`, `pcm_out`, `pcm_valid`) to the **nWave** window.
4.  Right-click `pcm_out` -> **Radix** -> **Decimal (2's Complement)**.
5.  Right-click `pcm_out` -> **Analog Waveform** to visualize the sine wave.
6.  Press **Run** (F5) to start the simulation.

---

## Verification
To verify the output quality:
1.  Run the simulation until completion.
2.  Locate the generated `pcm_verify_output.csv`.
3.  Import this CSV into MATLAB using the verification script (`Verify_Output.m`) to calculate the final SNR and ENOB.

**Expected Results:**
*   **SNR:** ~105.42 dB
*   **ENOB:** ~17.14 bits