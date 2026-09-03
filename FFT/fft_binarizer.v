`timescale 1ns / 1ps
`include "config_fft.vh"

module fft_binarizer (
    input  wire                          i_clk,
    input  wire                          i_rst_n,
    input  wire                          i_enable,
    input  wire [`ADDR_WIDTH-1:0]        i_bin_idx,
    input  wire signed [`BIT_WIDTH-1:0]  i_data_real,
    input  wire signed [`BIT_WIDTH-1:0]  i_data_imag,
    input  wire [`BIT_WIDTH-1:0]         i_threshold,
    
    output reg  [`FFT_POINTS-1:0]        o_feature_vector,
    output reg                           o_binarize_done
);

    wire [`BIT_WIDTH-1:0] w_abs_r = (i_data_real < 0) ? -i_data_real : i_data_real;
    wire [`BIT_WIDTH-1:0] w_abs_i = (i_data_imag < 0) ? -i_data_imag : i_data_imag;

    wire [`BIT_WIDTH-1:0] w_max = (w_abs_r >= w_abs_i) ? w_abs_r : w_abs_i;
    wire [`BIT_WIDTH-1:0] w_min = (w_abs_r >= w_abs_i) ? w_abs_i : w_abs_r;

    // Fast Alpha Max + Beta Min magnitude approximation: Max + Min/2
    wire [`BIT_WIDTH-1:0] w_magnitude = w_max + (w_min >> 1);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_feature_vector <= {`FFT_POINTS{1'b0}};
            o_binarize_done  <= 1'b0;
        end else begin
            if (i_enable) begin
                o_feature_vector[i_bin_idx] <= (w_magnitude >= i_threshold) ? 1'b1 : 1'b0;
                o_binarize_done <= (i_bin_idx == (`FFT_POINTS - 1)) ? 1'b1 : 1'b0;
            end else begin
                o_binarize_done <= 1'b0;
            end
        end
    end

endmodule