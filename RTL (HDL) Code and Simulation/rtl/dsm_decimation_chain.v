// ============================================================================
// FILE: dsm_decimation_chain.v
// SYSTEM: 1-bit DSM Input (81.92 kHz) -> 24-bit PCM Output (1.28 kHz)
// ARCHITECTURE: CIC (8x) -> CIC (2x) -> FIR (4x)
// ============================================================================

`timescale 1ns / 1ps

module dsm_decimation_chain (
    input  wire        clk,        // System Clock (e.g., 50-100 MHz)
    input  wire        rst_n,      // Active Low Reset
    input  wire        dsm_in,     // 1-bit DSM Input Data
    input  wire        dsm_en,     // Data Enable Pulse (active for 1 cycle @ 81.92 kHz)
    output reg [23:0]  pcm_out,    // Final 24-bit Data (1.28 kHz)
    output reg         pcm_valid   // Valid pulse for output data
);

    // ------------------------------------------------------------------------
    // INTERCONNECT WIRES
    // ------------------------------------------------------------------------
    wire [31:0] cic1_data;
    wire        cic1_valid;
    
    wire [31:0] cic2_data;
    wire        cic2_valid;
    
    wire [23:0] fir_in;
    wire [23:0] fir_data;
    wire        fir_valid;

    // ------------------------------------------------------------------------
    // STAGE 1: CIC FILTER (Decimate by 8, Order 7)
    // 81.92 kHz -> 10.24 kHz
    // ------------------------------------------------------------------------
    cic_decimator_r8_n7 u_cic1 (
        .clk        (clk),
        .rst_n      (rst_n),
        // FORCE 0 INPUT DURING RESET to prevent X-propagation
        .din_1bit   (rst_n ? dsm_in : 1'b0),
        .din_en     (dsm_en),
        .dout       (cic1_data),
        .dout_valid (cic1_valid)
    );

    // ------------------------------------------------------------------------
    // STAGE 2: CIC FILTER (Decimate by 2, Order 7)
    // 10.24 kHz -> 5.12 kHz
    // ------------------------------------------------------------------------
    cic_decimator_r2_n7 u_cic2 (
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (cic1_data),
        .din_valid  (cic1_valid),
        .dout       (cic2_data),
        .dout_valid (cic2_valid)
    );

    // ------------------------------------------------------------------------
    // SCALING / TRUNCATION
    // We select the top 24 meaningful bits [31:8]
    // ------------------------------------------------------------------------
    assign fir_in = cic2_data[31:8];

    // ------------------------------------------------------------------------
    // STAGE 3: FIR FILTER (Decimate by 4, 120 Taps)
    // 5.12 kHz -> 1.28 kHz
    // ------------------------------------------------------------------------
    fir_decimator_r4 u_fir (
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (fir_in),
        .din_valid  (cic2_valid),
        .dout       (fir_data),
        .dout_valid (fir_valid)
    );

    // ------------------------------------------------------------------------
    // OUTPUT REGISTER
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcm_out   <= 24'd0;
            pcm_valid <= 1'b0;
        end else begin
            pcm_out   <= fir_data;
            pcm_valid <= fir_valid;
        end
    end

endmodule


// ============================================================================
// SUBMODULE: CIC DECIMATOR (R=8, N=7)
// Input: 1-bit (+1/-1) | Output: 32-bit Signed
// ============================================================================
module cic_decimator_r8_n7 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        din_1bit,
    input  wire        din_en,
    output reg  [31:0] dout,
    output reg         dout_valid
);
    reg signed [31:0] i1, i2, i3, i4, i5, i6, i7;
    reg signed [31:0] c1, c2, c3, c4, c5, c6, c7;
    reg signed [31:0] c1_d, c2_d, c3_d, c4_d, c5_d, c6_d, c7_d;
    
    // Input Expansion: 0 -> -1, 1 -> +1
    wire signed [31:0] din_ext = (din_1bit) ? 32'sd1 : -32'sd1;
    
    reg [2:0] count;
    reg       dec_pulse;

    // INTEGRATOR SECTION (Input Rate)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i1 <= 0; i2 <= 0; i3 <= 0; i4 <= 0; i5 <= 0; i6 <= 0; i7 <= 0;
            count <= 0; dec_pulse <= 0;
        end else if (din_en) begin
            i1 <= i1 + din_ext;
            i2 <= i2 + i1;
            i3 <= i3 + i2;
            i4 <= i4 + i3;
            i5 <= i5 + i4;
            i6 <= i6 + i5;
            i7 <= i7 + i6;
            
            if (count == 3'd7) begin
                count <= 3'd0;
                dec_pulse <= 1'b1;
            end else begin
                count <= count + 1'b1;
                dec_pulse <= 1'b0;
            end
        end else begin
            dec_pulse <= 1'b0;
        end
    end

    // COMB SECTION (Output Rate)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c1_d<=0; c2_d<=0; c3_d<=0; c4_d<=0; c5_d<=0; c6_d<=0; c7_d<=0;
            c1<=0; c2<=0; c3<=0; c4<=0; c5<=0; c6<=0; c7<=0;
            dout <= 0; dout_valid <= 0;
        end else if (dec_pulse) begin
            c1   <= i7 - c1_d; c1_d <= i7;
            c2   <= c1 - c2_d; c2_d <= c1;
            c3   <= c2 - c3_d; c3_d <= c2;
            c4   <= c3 - c4_d; c4_d <= c3;
            c5   <= c4 - c5_d; c5_d <= c4;
            c6   <= c5 - c6_d; c6_d <= c5;
            c7   <= c6 - c7_d; c7_d <= c6;
            dout <= c7;
            dout_valid <= 1'b1;
        end else begin
            dout_valid <= 1'b0;
        end
    end
endmodule


// ============================================================================
// SUBMODULE: CIC DECIMATOR (R=2, N=7)
// Input: 32-bit Signed | Output: 32-bit Signed
// ============================================================================
module cic_decimator_r2_n7 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire signed [31:0] din,
    input  wire        din_valid,
    output reg  [31:0] dout,
    output reg         dout_valid
);
    reg signed [31:0] i1, i2, i3, i4, i5, i6, i7;
    reg signed [31:0] c1, c2, c3, c4, c5, c6, c7;
    reg signed [31:0] c1_d, c2_d, c3_d, c4_d, c5_d, c6_d, c7_d;
    
    reg dec_toggle;
    reg dec_pulse;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i1 <= 0; i2 <= 0; i3 <= 0; i4 <= 0; i5 <= 0; i6 <= 0; i7 <= 0;
            dec_toggle <= 0; dec_pulse <= 0;
        end else if (din_valid) begin
            i1 <= i1 + din;
            i2 <= i2 + i1;
            i3 <= i3 + i2;
            i4 <= i4 + i3;
            i5 <= i5 + i4;
            i6 <= i6 + i5;
            i7 <= i7 + i6;
            dec_toggle <= ~dec_toggle;
            dec_pulse  <= dec_toggle; 
        end else begin
            dec_pulse <= 0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c1_d<=0; c2_d<=0; c3_d<=0; c4_d<=0; c5_d<=0; c6_d<=0; c7_d<=0;
            dout <= 0; dout_valid <= 0;
        end else if (dec_pulse) begin
            c1 <= i7 - c1_d; c1_d <= i7;
            c2 <= c1 - c2_d; c2_d <= c1;
            c3 <= c2 - c3_d; c3_d <= c2;
            c4 <= c3 - c4_d; c4_d <= c3;
            c5 <= c4 - c5_d; c5_d <= c4;
            c6 <= c5 - c6_d; c6_d <= c5;
            c7 <= c6 - c7_d; c7_d <= c6;
            dout <= c7;
            dout_valid <= 1'b1;
        end else begin
            dout_valid <= 1'b0;
        end
    end
endmodule


// ============================================================================
// SUBMODULE: SERIAL FIR FILTER (120 Taps, R=4)
// Coefficients Updated for >100 dB SNDR (Cutoff 0.1, Beta 19)
// ============================================================================
module fir_decimator_r4 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire signed [23:0] din,
    input  wire        din_valid,
    output reg  [23:0] dout,
    output reg         dout_valid
);

    reg signed [15:0] coeff;
    reg [6:0] rom_addr;
    
    always @(*) begin
        case (rom_addr)
            7'd0  : coeff = 16'd3;
            7'd1  : coeff = -16'd4;
            7'd2  : coeff = -16'd7;
            7'd3  : coeff = -16'd6;
            7'd4  : coeff = -16'd1;
            7'd5  : coeff = 16'd5;
            7'd6  : coeff = 16'd10;
            7'd7  : coeff = 16'd10;
            7'd8  : coeff = 16'd6;
            7'd9  : coeff = -16'd3;
            7'd10 : coeff = -16'd13;
            7'd11 : coeff = -16'd18;
            7'd12 : coeff = -16'd13;
            7'd13 : coeff = 16'd0;
            7'd14 : coeff = 16'd17;
            7'd15 : coeff = 16'd29;
            7'd16 : coeff = 16'd26;
            7'd17 : coeff = 16'd8;
            7'd18 : coeff = -16'd19;
            7'd19 : coeff = -16'd43;
            7'd20 : coeff = -16'd45;
            7'd21 : coeff = -16'd20;
            7'd22 : coeff = 16'd22;
            7'd23 : coeff = 16'd60;
            7'd24 : coeff = 16'd71;
            7'd25 : coeff = 16'd41;
            7'd26 : coeff = -16'd19;
            7'd27 : coeff = -16'd81;
            7'd28 : coeff = -16'd107;
            7'd29 : coeff = -16'd72;
            7'd30 : coeff = 16'd9;
            7'd31 : coeff = 16'd105;
            7'd32 : coeff = 16'd156;
            7'd33 : coeff = 16'd118;
            7'd34 : coeff = 16'd10;
            7'd35 : coeff = -16'd129;
            7'd36 : coeff = -16'd219;
            7'd37 : coeff = -16'd185;
            7'd38 : coeff = -16'd41;
            7'd39 : coeff = 16'd150;
            7'd40 : coeff = 16'd300;
            7'd41 : coeff = 16'd283;
            7'd42 : coeff = 16'd94;
            7'd43 : coeff = -16'd162;
            7'd44 : coeff = -16'd399;
            7'd45 : coeff = -16'd432;
            7'd46 : coeff = -16'd188;
            7'd47 : coeff = 16'd157;
            7'd48 : coeff = 16'd520;
            7'd49 : coeff = 16'd666;
            7'd50 : coeff = 16'd373;
            7'd51 : coeff = -16'd118;
            7'd52 : coeff = -16'd680;
            7'd53 : coeff = -16'd1097;
            7'd54 : coeff = -16'd880;
            7'd55 : coeff = 16'd56;
            7'd56 : coeff = 16'd1380;
            7'd57 : coeff = 16'd2563;
            7'd58 : coeff = 16'd3266;
            7'd59 : coeff = 16'd3266;
            7'd60 : coeff = 16'd2563;
            7'd61 : coeff = 16'd1380;
            7'd62 : coeff = 16'd56;
            7'd63 : coeff = -16'd880;
            7'd64 : coeff = -16'd1097;
            7'd65 : coeff = -16'd680;
            7'd66 : coeff = -16'd118;
            7'd67 : coeff = 16'd373;
            7'd68 : coeff = 16'd666;
            7'd69 : coeff = 16'd520;
            7'd70 : coeff = 16'd157;
            7'd71 : coeff = -16'd188;
            7'd72 : coeff = -16'd432;
            7'd73 : coeff = -16'd399;
            7'd74 : coeff = -16'd162;
            7'd75 : coeff = 16'd94;
            7'd76 : coeff = 16'd283;
            7'd77 : coeff = 16'd300;
            7'd78 : coeff = 16'd150;
            7'd79 : coeff = -16'd41;
            7'd80 : coeff = -16'd185;
            7'd81 : coeff = -16'd219;
            7'd82 : coeff = -16'd129;
            7'd83 : coeff = 16'd10;
            7'd84 : coeff = 16'd118;
            7'd85 : coeff = 16'd156;
            7'd86 : coeff = 16'd105;
            7'd87 : coeff = 16'd9;
            7'd88 : coeff = -16'd72;
            7'd89 : coeff = -16'd107;
            7'd90 : coeff = -16'd81;
            7'd91 : coeff = -16'd19;
            7'd92 : coeff = 16'd41;
            7'd93 : coeff = 16'd71;
            7'd94 : coeff = 16'd60;
            7'd95 : coeff = 16'd22;
            7'd96 : coeff = -16'd20;
            7'd97 : coeff = -16'd45;
            7'd98 : coeff = -16'd43;
            7'd99 : coeff = -16'd19;
            7'd100: coeff = 16'd8;
            7'd101: coeff = 16'd26;
            7'd102: coeff = 16'd29;
            7'd103: coeff = 16'd17;
            7'd104: coeff = 16'd0;
            7'd105: coeff = -16'd13;
            7'd106: coeff = -16'd18;
            7'd107: coeff = -16'd13;
            7'd108: coeff = -16'd3;
            7'd109: coeff = 16'd6;
            7'd110: coeff = 16'd10;
            7'd111: coeff = 16'd10;
            7'd112: coeff = 16'd5;
            7'd113: coeff = -16'd1;
            7'd114: coeff = -16'd6;
            7'd115: coeff = -16'd7;
            7'd116: coeff = -16'd4;
            7'd117: coeff = 16'd3;
            7'd118: coeff = -16'd2;
            7'd119: coeff = 16'd1;
            // Safe Default to avoid X
            default: coeff = 16'd0;
        endcase
    end

    // ------------------------------------------------------------------------
    // DATA PATH
    // ------------------------------------------------------------------------
    reg signed [23:0] delay_line [0:119];
    reg signed [47:0] acc;
    reg [6:0]         tap_idx;
    reg [1:0]         dec_count;
    reg               state; 
    integer           i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_count  <= 0; state <= 0; tap_idx <= 0; acc <= 0;
            dout <= 0; dout_valid <= 0;
            for (i=0; i<120; i=i+1) delay_line[i] <= 24'd0;
        end else begin
            dout_valid <= 1'b0;
            
            // 1. INPUT HANDLING
            if (din_valid) begin
                for (i=119; i>0; i=i-1) delay_line[i] <= delay_line[i-1];
                delay_line[0] <= din;

                if (dec_count == 2'd3) begin
                    dec_count <= 2'd0;
                    state     <= 1'b1; // Start
                    tap_idx   <= 7'd0;
                    acc       <= 48'd0;
                end else begin
                    dec_count <= dec_count + 1'b1;
                end
            end

            // 2. COMPUTATION ENGINE
            if (state == 1'b1) begin
                rom_addr = tap_idx;
                acc <= acc + (delay_line[tap_idx] * coeff);
                
                if (tap_idx == 7'd119) begin
                    state      <= 1'b0; 
                    dout       <= acc[38:15]; // Scaling
                    dout_valid <= 1'b1;
                end else begin
                    tap_idx <= tap_idx + 1'b1;
                end
            end
        end
    end
endmodule
