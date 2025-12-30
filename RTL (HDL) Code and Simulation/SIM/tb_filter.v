`timescale 1ns / 1ps

module tb_dsm_from_file;

    // ========================================================================
    // PARAMETERS
    // ========================================================================
    parameter CLK_FREQ_MHZ    = 100;          // 100 MHz System Clock
    parameter CLK_PERIOD_NS   = 1000.0 / CLK_FREQ_MHZ;
    
    // Input Settings (matches your MATLAB generation)
    parameter DSM_RATE_HZ     = 81920;        
    parameter CLKS_PER_SAMPLE = 1221;         
    parameter FILE_NAME       = "dsm_input.txt";
    // Adjust this if you generated more/less samples in MATLAB
    parameter MAX_SAMPLES     = 1048576;      

    // ========================================================================
    // SIGNALS
    // ========================================================================
    reg         clk;
    reg         rst_n;
    reg         dsm_in;
    reg         dsm_en;
    wire [23:0] pcm_out;
    wire        pcm_valid;

    reg [0:0]   dsm_memory [0:MAX_SAMPLES-1];
    integer     sample_ptr;
    integer     clk_counter;
    integer     outfile;

    // ========================================================================
    // DUT INSTANTIATION
    // ========================================================================
    dsm_decimation_chain u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .dsm_in     (dsm_in),
        .dsm_en     (dsm_en),
        .pcm_out    (pcm_out),
        .pcm_valid  (pcm_valid)
    );

    // ========================================================================
    // CLOCK
    // ========================================================================
    initial clk = 0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // ========================================================================
    // MAIN TEST
    // ========================================================================
    initial begin
        // 1. Init
        rst_n = 0;
        dsm_in = 0;
        dsm_en = 0;
        sample_ptr = 0;
        clk_counter = 0;

        // 2. Dump Waves (Standard VCD for broad compatibility)
        // If using Verdi, this file can be opened with 'verdi -ssf dsm_waves.vcd'
        $dumpfile("dsm_waves.vcd");
        $dumpvars(0, tb_dsm_from_file);

        // 3. Load File
        $display("-----------------------------------------------------------");
        $display(" Loading DSM Data from: %s", FILE_NAME);
        $readmemb(FILE_NAME, dsm_memory);
        $display(" Data Loaded. Starting Simulation...");
        $display("-----------------------------------------------------------");

        // 4. Output File
        outfile = $fopen("pcm_verify_output.csv", "w");
        $fwrite(outfile, "Time_ns, PCM_Value\n");

        // 5. Reset Release
        #2000;
        rst_n = 1;
        
        // 6. Wait loop
        wait(sample_ptr >= MAX_SAMPLES);
        
        // 7. Finish
        #50000; 
        $display("-----------------------------------------------------------");
        $display(" Simulation Complete.");
        $display(" Processed %d samples.", sample_ptr);
        $display(" Check 'pcm_verify_output.csv' for data.");
        $display("-----------------------------------------------------------");
        $fclose(outfile);
        $finish;
    end

    // ========================================================================
    // DATA DRIVER
    // ========================================================================
    always @(posedge clk) begin
        if (rst_n) begin
            if (clk_counter >= CLKS_PER_SAMPLE - 1) begin
                clk_counter <= 0;
                
                if (sample_ptr < MAX_SAMPLES) begin
                    dsm_en <= 1'b1;
                    dsm_in <= dsm_memory[sample_ptr];
                    sample_ptr <= sample_ptr + 1;
                    
                    // Status Update
                    if (sample_ptr % 50000 == 0)
                         $display("Progress: %0d samples processed", sample_ptr);
                end else begin
                    dsm_en <= 1'b0;
                end
            end else begin
                dsm_en <= 1'b0;
                clk_counter <= clk_counter + 1;
            end
        end
    end

    // ========================================================================
    // OUTPUT LOGGER
    // ========================================================================
    always @(posedge clk) begin
        if (pcm_valid) begin
            $fwrite(outfile, "%0t, %d\n", $time, $signed(pcm_out));
        end
    end

endmodule