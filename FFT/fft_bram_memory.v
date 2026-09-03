`timescale 1ns / 1ps
`include "config_fft.vh"

module fft_bram_memory (
    input                             i_clk,
    
    // Bank A Interface
    input                             i_we_a,
    input        [`ADDR_WIDTH-1:0]    i_addr_a0,
    input signed [`BIT_WIDTH-1:0]     i_data_a0_r, i_data_a0_i,
    output reg signed [`BIT_WIDTH-1:0] o_data_a0_r, o_data_a0_i,
    
    input        [`ADDR_WIDTH-1:0]    i_addr_a1,
    input signed [`BIT_WIDTH-1:0]     i_data_a1_r, i_data_a1_i,
    output reg signed [`BIT_WIDTH-1:0] o_data_a1_r, o_data_a1_i,
    
    // Bank B Interface
    input                             i_we_b,
    input        [`ADDR_WIDTH-1:0]    i_addr_b0,
    input signed [`BIT_WIDTH-1:0]     i_data_b0_r, i_data_b0_i,
    output reg signed [`BIT_WIDTH-1:0] o_data_b0_r, o_data_b0_i,
    
    input        [`ADDR_WIDTH-1:0]    i_addr_b1,
    input signed [`BIT_WIDTH-1:0]     i_data_b1_r, i_data_b1_i,
    output reg signed [`BIT_WIDTH-1:0] o_data_b1_r, o_data_b1_i
);

    reg signed [`BIT_WIDTH-1:0] r_ram_a_real [0:`FFT_POINTS-1];
    reg signed [`BIT_WIDTH-1:0] r_ram_a_imag [0:`FFT_POINTS-1];
    reg signed [`BIT_WIDTH-1:0] r_ram_b_real [0:`FFT_POINTS-1];
    reg signed [`BIT_WIDTH-1:0] r_ram_b_imag [0:`FFT_POINTS-1];

    integer k;
    initial begin
        for (k = 0; k < `FFT_POINTS; k = k + 1) begin
            r_ram_a_real[k] = 16'sd0;
            r_ram_a_imag[k] = 16'sd0;
            r_ram_b_real[k] = 16'sd0;
            r_ram_b_imag[k] = 16'sd0;
        end
    end

    // Bank A Synchronous Access
    always @(posedge i_clk) begin
        if (i_we_a) begin
            r_ram_a_real[i_addr_a0] <= i_data_a0_r;
            r_ram_a_imag[i_addr_a0] <= i_data_a0_i;
            r_ram_a_real[i_addr_a1] <= i_data_a1_r;
            r_ram_a_imag[i_addr_a1] <= i_data_a1_i;
        end
        o_data_a0_r <= r_ram_a_real[i_addr_a0];
        o_data_a0_i <= r_ram_a_imag[i_addr_a0];
        o_data_a1_r <= r_ram_a_real[i_addr_a1];
        o_data_a1_i <= r_ram_a_imag[i_addr_a1];
    end

    // Bank B Synchronous Access
    always @(posedge i_clk) begin
        if (i_we_b) begin
            r_ram_b_real[i_addr_b0] <= i_data_b0_r;
            r_ram_b_imag[i_addr_b0] <= i_data_b0_i;
            r_ram_b_real[i_addr_b1] <= i_data_b1_r;
            r_ram_b_imag[i_addr_b1] <= i_data_b1_i;
        end
        o_data_b0_r <= r_ram_b_real[i_addr_b0];
        o_data_b0_i <= r_ram_b_imag[i_addr_b0];
        o_data_b1_r <= r_ram_b_real[i_addr_b1];
        o_data_b1_i <= r_ram_b_imag[i_addr_b1];
    end

endmodule