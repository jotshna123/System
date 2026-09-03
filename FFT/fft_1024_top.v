`timescale 1ns / 1ps
`include "config_fft.vh"

module fft_1024_top (
    input                             i_clk,
    input                             i_rst_n,
    input                             i_start,
    
    // External Loading/Unloading Interface
    input                             i_ext_we,
    input        [`ADDR_WIDTH-1:0]    i_ext_addr,
    input signed [`BIT_WIDTH-1:0]     i_ext_data_r,
    input signed [`BIT_WIDTH-1:0]     i_ext_data_i,
    
    output signed [`BIT_WIDTH-1:0]    o_ext_data_r,
    output signed [`BIT_WIDTH-1:0]    o_ext_data_i,
    output                            o_busy,
    output                            o_done
);

    wire                      w_ping_pong_sel;
    wire                      w_ctrl_we;
    wire [`ADDR_WIDTH-1:0]    w_rd_addr0, w_rd_addr1;
    wire [`ADDR_WIDTH-1:0]    w_wr_addr0, w_wr_addr1;
    wire [`ADDR_WIDTH-2:0]    w_twiddle_addr;

    wire signed [`BIT_WIDTH-1:0] w_w_r, w_w_i;

    wire signed [`BIT_WIDTH-1:0] w_pe_a_r, w_pe_a_i;
    wire signed [`BIT_WIDTH-1:0] w_pe_b_r, w_pe_b_i;
    wire signed [`BIT_WIDTH-1:0] w_pe_x_r, w_pe_x_i;
    wire signed [`BIT_WIDTH-1:0] w_pe_y_r, w_pe_y_i;

    wire signed [`BIT_WIDTH-1:0] w_bram_a0_r, w_bram_a0_i;
    wire signed [`BIT_WIDTH-1:0] w_bram_a1_r, w_bram_a1_i;
    wire signed [`BIT_WIDTH-1:0] w_bram_b0_r, w_bram_b0_i;
    wire signed [`BIT_WIDTH-1:0] w_bram_b1_r, w_bram_b1_i;

    fft_1024_controller ctrl_inst (
        .i_clk(i_clk),                   .i_rst_n(i_rst_n),
        .i_start(i_start),               .o_busy(o_busy),
        .o_done(o_done),                 .o_ping_pong_sel(w_ping_pong_sel),
        .o_we(w_ctrl_we),                .o_rd_addr0(w_rd_addr0),
        .o_rd_addr1(w_rd_addr1),         .o_wr_addr0(w_wr_addr0),
        .o_wr_addr1(w_wr_addr1),         .o_twiddle_addr(w_twiddle_addr)
    );

    twiddle_rom_1024 rom_inst (
        .i_clk(i_clk),                   .i_addr(w_twiddle_addr),
        .o_w_real(w_w_r),                .o_w_imag(w_w_i)
    );

    butterfly_pe pe_inst (
        .i_clk(i_clk),                   .i_rst_n(i_rst_n),
        .i_a_real(w_pe_a_r),             .i_a_imag(w_pe_a_i),
        .i_b_real(w_pe_b_r),             .i_b_imag(w_pe_b_i),
        .i_w_real(w_w_r),                .i_w_imag(w_w_i),
        .o_x_real(w_pe_x_r),             .o_x_imag(w_pe_x_i),
        .o_y_real(w_pe_y_r),             .o_y_imag(w_pe_y_i)
    );

    // Mux read inputs to Butterfly PE based on ping-pong bank state
    assign w_pe_a_r = (w_ping_pong_sel == 1'b0) ? w_bram_a0_r : w_bram_b0_r;
    assign w_pe_a_i = (w_ping_pong_sel == 1'b0) ? w_bram_a0_i : w_bram_b0_i;
    assign w_pe_b_r = (w_ping_pong_sel == 1'b0) ? w_bram_a1_r : w_bram_b1_r;
    assign w_pe_b_i = (w_ping_pong_sel == 1'b0) ? w_bram_a1_i : w_bram_b1_i;

    // Dual-Port BRAM Memory
    fft_bram_memory mem_inst (
        .i_clk(i_clk),
        
        // Bank A
        .i_we_a(i_ext_we | (w_ping_pong_sel & w_ctrl_we)),
        .i_addr_a0(i_ext_we ? i_ext_addr : (o_busy ? (w_ping_pong_sel ? w_wr_addr0 : w_rd_addr0) : i_ext_addr)),
        .i_data_a0_r(i_ext_we ? i_ext_data_r : w_pe_x_r),
        .i_data_a0_i(i_ext_we ? i_ext_data_i : w_pe_x_i),
        .o_data_a0_r(w_bram_a0_r),       .o_data_a0_i(w_bram_a0_i),
        .i_addr_a1(w_ping_pong_sel ? w_wr_addr1 : w_rd_addr1),
        .i_data_a1_r(w_pe_y_r),          .i_data_a1_i(w_pe_y_i),
        .o_data_a1_r(w_bram_a1_r),       .o_data_a1_i(w_bram_a1_i),
        
        // Bank B
        .i_we_b(~w_ping_pong_sel & w_ctrl_we & o_busy),
        .i_addr_b0(o_busy ? (~w_ping_pong_sel ? w_wr_addr0 : w_rd_addr0) : i_ext_addr),
        .i_data_b0_r(w_pe_x_r),          .i_data_b0_i(w_pe_x_i),
        .o_data_b0_r(w_bram_b0_r),       .o_data_b0_i(w_bram_b0_i),
        .i_addr_b1(~w_ping_pong_sel ? w_wr_addr1 : w_rd_addr1),
        .i_data_b1_r(w_pe_y_r),          .i_data_b1_i(w_pe_y_i),
        .o_data_b1_r(w_bram_b1_r),       .o_data_b1_i(w_bram_b1_i)
    );

    // After 10 stages (0 to 9), Bank A holds the final results
    assign o_ext_data_r = w_bram_a0_r;
    assign o_ext_data_i = w_bram_a0_i;

endmodule