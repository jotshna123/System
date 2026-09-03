`timescale 1ns / 1ps
`include "config_fft.vh"

module radar_ai_top (
    input                             i_clk,
    input                             i_rst_n,
    input                             i_start_frame,
    
    // External Loading Interface
    input                             i_ext_we,
    input        [`ADDR_WIDTH-1:0]    i_ext_addr,
    input signed [`BIT_WIDTH-1:0]     i_ext_data_r,
    input signed [`BIT_WIDTH-1:0]     i_ext_data_i,
    
    // Threshold Control
    input        [`BIT_WIDTH-1:0]     i_threshold,
    
    // Output Vector
    output reg   [`FFT_POINTS-1:0]    o_feature_vector,
    output reg                        o_radar_ready,
    output                            o_busy
);

    wire signed [`BIT_WIDTH-1:0] w_fft_out_r;
    wire signed [`BIT_WIDTH-1:0] w_fft_out_i;
    wire                         w_fft_busy;
    wire                         w_fft_done;
    
    reg                          r_fft_start;
    reg  [`ADDR_WIDTH-1:0]       r_sweep_addr;
    reg                          r_sweeping;
    
    // Exact 2-cycle pipeline to match BRAM synchronous read + registration
    reg                          r_val_d1, r_val_d2;
    reg  [`ADDR_WIDTH-1:0]       r_idx_d1, r_idx_d2;

    localparam S_IDLE       = 3'd0;
    localparam S_FFT_RUN    = 3'd1;
    localparam S_STREAM_OUT = 3'd2;
    localparam S_FLUSH_PIPE = 3'd3;
    localparam S_DONE_HOLD  = 3'd4;

    reg [2:0] r_stream_state;
    reg [1:0] r_flush_cnt;

    // Bit-reversal function for Decimation-In-Frequency output
    function [`ADDR_WIDTH-1:0] bit_reverse;
        input [`ADDR_WIDTH-1:0] in_addr;
        integer j;
        begin
            for (j = 0; j < `ADDR_WIDTH; j = j + 1) begin
                bit_reverse[`ADDR_WIDTH-1 - j] = in_addr[j];
            end
        end
    endfunction

    wire [`ADDR_WIDTH-1:0] w_bram_addr = (r_sweeping) ? bit_reverse(r_sweep_addr) : i_ext_addr;

    fft_1024_top fft_core_inst (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_start(r_fft_start),
        .i_ext_we(i_ext_we),
        .i_ext_addr(w_bram_addr),
        .i_ext_data_r(i_ext_data_r),
        .i_ext_data_i(i_ext_data_i),
        .o_ext_data_r(w_fft_out_r),
        .o_ext_data_i(w_fft_out_i),
        .o_busy(w_fft_busy),
        .o_done(w_fft_done)
    );

    // Alpha Max + Beta Min Binarization Logic
    wire [`BIT_WIDTH-1:0] w_abs_r = (w_fft_out_r < 0) ? -w_fft_out_r : w_fft_out_r;
    wire [`BIT_WIDTH-1:0] w_abs_i = (w_fft_out_i < 0) ? -w_fft_out_i : w_fft_out_i;
    wire [`BIT_WIDTH-1:0] w_max   = (w_abs_r >= w_abs_i) ? w_abs_r : w_abs_i;
    wire [`BIT_WIDTH-1:0] w_min   = (w_abs_r >= w_abs_i) ? w_abs_i : w_abs_r;
    wire [`BIT_WIDTH-1:0] w_mag   = w_max + (w_min >> 1);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_stream_state   <= S_IDLE;
            r_fft_start      <= 1'b0;
            r_sweep_addr     <= 10'd0;
            r_sweeping       <= 1'b0;
            r_val_d1         <= 1'b0;
            r_val_d2         <= 1'b0;
            r_idx_d1         <= 10'd0;
            r_idx_d2         <= 10'd0;
            r_flush_cnt      <= 2'd0;
            o_feature_vector <= {`FFT_POINTS{1'b0}};
            o_radar_ready    <= 1'b0;
        end else begin
            // 1-cycle latency pipeline shift
            r_val_d1 <= r_sweeping;
            r_idx_d1 <= r_sweep_addr;
            
            // Latch output on data arrival
            if (r_val_d1) begin
                if (w_mag >= i_threshold)
                    o_feature_vector[r_idx_d1] <= 1'b1;
                else
                    o_feature_vector[r_idx_d1] <= 1'b0;
            end

            case (r_stream_state)
                S_IDLE: begin
                    o_radar_ready <= 1'b0;
                    r_sweeping    <= 1'b0;
                    if (i_start_frame) begin
                        r_fft_start      <= 1'b1;
                        o_feature_vector <= {`FFT_POINTS{1'b0}};
                        r_stream_state   <= S_FFT_RUN;
                    end
                end

                S_FFT_RUN: begin
                    r_fft_start <= 1'b0;
                    if (w_fft_done) begin
                        r_sweeping     <= 1'b1;
                        r_sweep_addr   <= 10'd0;
                        r_stream_state <= S_STREAM_OUT;
                    end
                end

                S_STREAM_OUT: begin
                    if (r_sweep_addr == (`FFT_POINTS - 1)) begin
                        r_sweeping     <= 1'b0;
                        r_flush_cnt    <= 2'd0;
                        r_stream_state <= S_FLUSH_PIPE;
                    end else begin
                        r_sweep_addr <= r_sweep_addr + 1'b1;
                    end
                end

                S_FLUSH_PIPE: begin
                    // Wait 2 extra cycles for last bin to flush from BRAM read pipeline
                    if (r_flush_cnt == 2'd2) begin
                        r_stream_state <= S_DONE_HOLD;
                    end else begin
                        r_flush_cnt <= r_flush_cnt + 1'b1;
                    end
                end

                S_DONE_HOLD: begin
                    o_radar_ready  <= 1'b1;
                    r_stream_state <= S_IDLE;
                end
            endcase
        end
    end

    assign o_busy = (r_stream_state != S_IDLE);

endmodule