`timescale 1ns / 1ps
`include "config_fft.vh"

module butterfly_pe (
    input i_clk,
    input i_rst_n,
    
    // Input Port A
    input signed [`BIT_WIDTH-1:0] i_a_real,
    input signed [`BIT_WIDTH-1:0] i_a_imag,
    
    // Input Port B
    input signed [`BIT_WIDTH-1:0] i_b_real,
    input signed [`BIT_WIDTH-1:0] i_b_imag,
    
    // Twiddle Factor Multiplier W
    input signed [`BIT_WIDTH-1:0] i_w_real,
    input signed [`BIT_WIDTH-1:0] i_w_imag,
    
    // Output Port X
    output reg signed [`BIT_WIDTH-1:0] o_x_real,
    output reg signed [`BIT_WIDTH-1:0] o_x_imag,
    
    // Output Port Y
    output reg signed [`BIT_WIDTH-1:0] o_y_real,
    output reg signed [`BIT_WIDTH-1:0] o_y_imag
);

    // Internal pipeline registers (scaled by 1/2 to prevent overflow)
    reg signed [`BIT_WIDTH-1:0] r_sub_real;
    reg signed [`BIT_WIDTH-1:0] r_sub_imag;
    
    // Combinational wires with double bit-width for multiplication
    wire signed [(2*`BIT_WIDTH)-1:0] w_mult_rr;
    wire signed [(2*`BIT_WIDTH)-1:0] w_mult_ii;
    wire signed [(2*`BIT_WIDTH)-1:0] w_mult_ri;
    wire signed [(2*`BIT_WIDTH)-1:0] w_mult_ir;

    // ─── STAGE 1: ADD / SUB WITH 1/2 SCALING ─────────────────────────────────
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_x_real   <= 0;
            o_x_imag   <= 0;
            r_sub_real <= 0;
            r_sub_imag <= 0;
        end else begin
            // Divide by 2 (shift right arithmetic by 1) prevents stage overflow
            o_x_real   <= (i_a_real + i_b_real) >>> 1;
            o_x_imag   <= (i_a_imag + i_b_imag) >>> 1;
            
            r_sub_real <= (i_a_real - i_b_real) >>> 1;
            r_sub_imag <= (i_a_imag - i_b_imag) >>> 1;
        end
    end

    // ─── STAGE 2: COMPLEX MULTIPLICATION ─────────────────────────────────────
    assign w_mult_rr = r_sub_real * i_w_real; 
    assign w_mult_ii = r_sub_imag * i_w_imag; 
    assign w_mult_ri = r_sub_real * i_w_imag; 
    assign w_mult_ir = r_sub_imag * i_w_real; 

    // ─── STAGE 3: OUTPUT REGISTRATION & FIXED-POINT RESCALING ────────────────
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_y_real <= 0;
            o_y_imag <= 0;
        end else begin
            o_y_real <= (w_mult_rr - w_mult_ii) >>> `SHIFT_BITS;
            o_y_imag <= (w_mult_ri + w_mult_ir) >>> `SHIFT_BITS;
        end
    end

endmodule