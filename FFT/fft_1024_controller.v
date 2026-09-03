`timescale 1ns / 1ps
`include "config_fft.vh"

module fft_1024_controller (
    input                             i_clk,
    input                             i_rst_n,
    input                             i_start,
    
    output reg                        o_busy,
    output reg                        o_done,
    output reg                        o_ping_pong_sel,
    output reg                        o_we,
    output reg [`ADDR_WIDTH-1:0]      o_rd_addr0,
    output reg [`ADDR_WIDTH-1:0]      o_rd_addr1,
    output reg [`ADDR_WIDTH-1:0]      o_wr_addr0,
    output reg [`ADDR_WIDTH-1:0]      o_wr_addr1,
    output reg [`ADDR_WIDTH-2:0]      o_twiddle_addr
);

    localparam S_IDLE    = 2'd0;
    localparam S_PROCESS = 2'd1;
    localparam S_WAIT    = 2'd2;
    localparam S_DONE    = 2'd3;

    reg [1:0] r_state;
    reg [3:0] r_stage;
    reg [`ADDR_WIDTH-2:0] r_pair_idx;
    
    reg [`ADDR_WIDTH-1:0] r_p0_d0, r_p0_d1, r_p0_d2;
    reg [`ADDR_WIDTH-1:0] r_p1_d0, r_p1_d1, r_p1_d2;
    reg                   r_val_d0, r_val_d1, r_val_d2;

    wire [`ADDR_WIDTH-1:0] w_stride = (10'd512 >> r_stage);
    wire [`ADDR_WIDTH-1:0] w_group  = (r_pair_idx / w_stride);
    wire [`ADDR_WIDTH-1:0] w_offset = (r_pair_idx % w_stride);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state          <= S_IDLE;
            o_busy           <= 1'b0;
            o_done           <= 1'b0;
            r_stage          <= 4'd0;
            r_pair_idx       <= 9'd0;
            o_ping_pong_sel  <= 1'b0;
            o_we             <= 1'b0;
            o_rd_addr0       <= 10'd0;
            o_rd_addr1       <= 10'd0;
            o_wr_addr0       <= 10'd0;
            o_wr_addr1       <= 10'd0;
            o_twiddle_addr   <= 9'd0;
            r_val_d0         <= 1'b0;
            r_val_d1         <= 1'b0;
            r_val_d2         <= 1'b0;
            r_p0_d0          <= 10'd0;
            r_p0_d1          <= 10'd0;
            r_p0_d2          <= 10'd0;
            r_p1_d0          <= 10'd0;
            r_p1_d1          <= 10'd0;
            r_p1_d2          <= 10'd0;
        end else begin
            r_p0_d1  <= r_p0_d0;
            r_p0_d2  <= r_p0_d1;
            
            r_p1_d1  <= r_p1_d0;
            r_p1_d2  <= r_p1_d1;
            
            r_val_d1 <= r_val_d0;
            r_val_d2 <= r_val_d1;
            
            o_wr_addr0 <= r_p0_d2;
            o_wr_addr1 <= r_p1_d2;
            o_we       <= r_val_d2;

            case (r_state)
                S_IDLE: begin
                    o_done   <= 1'b0;
                    r_val_d0 <= 1'b0;
                    if (i_start) begin
                        o_busy          <= 1'b1;
                        r_state         <= S_PROCESS;
                        r_stage         <= 4'd0;
                        r_pair_idx      <= 9'd0;
                        o_ping_pong_sel <= 1'b0;
                    end
                end

                S_PROCESS: begin
                    o_rd_addr0     <= (w_group * (w_stride << 1)) + w_offset;
                    o_rd_addr1     <= (w_group * (w_stride << 1)) + w_offset + w_stride;
                    o_twiddle_addr <= w_offset * (10'd512 / w_stride);

                    r_p0_d0  <= (w_group * (w_stride << 1)) + w_offset;
                    r_p1_d0  <= (w_group * (w_stride << 1)) + w_offset + w_stride;
                    r_val_d0 <= 1'b1;

                    if (r_pair_idx == 9'd511) begin
                        r_pair_idx <= 9'd0;
                        r_val_d0   <= 1'b0;
                        r_state    <= S_WAIT;
                    end else begin
                        r_pair_idx <= r_pair_idx + 1'b1;
                    end
                end

                S_WAIT: begin
                    if (!r_val_d2 && !r_val_d1 && !r_val_d0) begin
                        if (r_stage == 4'd9) begin
                            r_state <= S_DONE;
                        end else begin
                            r_stage         <= r_stage + 1'b1;
                            o_ping_pong_sel <= ~o_ping_pong_sel;
                            r_state         <= S_PROCESS;
                        end
                    end
                end

                S_DONE: begin
                    o_busy  <= 1'b0;
                    o_done  <= 1'b1;
                    if (i_start) begin
                        o_done  <= 1'b0;
                        r_state <= S_IDLE;
                    end
                end
            endcase
        end
    end

endmodule