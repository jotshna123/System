`timescale 1ns / 1ps
`include "config_fft.vh"

module twiddle_rom_1024 (
    input                             i_clk,
    input        [`ADDR_WIDTH-2:0]    i_addr,   // 0 to 511 (9 bits)
    output reg signed [`BIT_WIDTH-1:0] o_w_real,
    output reg signed [`BIT_WIDTH-1:0] o_w_imag
);

    // Quarter-wave trigonometric calculation logic in Q8.8 (256 = 1.0)
    always @(posedge i_clk) begin
        case (i_addr)
            9'd0   : begin o_w_real <= 16'sd256;  o_w_imag <= 16'sd0;    end // 0 deg
            9'd32  : begin o_w_real <= 16'sd251;  o_w_imag <= -16'sd50;  end
            9'd64  : begin o_w_real <= 16'sd236;  o_w_imag <= -16'sd98;  end // 22.5 deg
            9'd96  : begin o_w_real <= 16'sd213;  o_w_imag <= -16'sd142; end
            9'd128 : begin o_w_real <= 16'sd181;  o_w_imag <= -16'sd181; end // 45 deg (0.7071)
            9'd160 : begin o_w_real <= 16'sd142;  o_w_imag <= -16'sd213; end
            9'd192 : begin o_w_real <= 16'sd98;   o_w_imag <= -16'sd236; end // 67.5 deg
            9'd224 : begin o_w_real <= 16'sd50;   o_w_imag <= -16'sd251; end
            9'd256 : begin o_w_real <= 16'sd0;    o_w_imag <= -16'sd256; end // 90 deg (-j)
            9'd288 : begin o_w_real <= -16'sd50;  o_w_imag <= -16'sd251; end
            9'd320 : begin o_w_real <= -16'sd98;  o_w_imag <= -16'sd236; end
            9'd352 : begin o_w_real <= -16'sd142; o_w_imag <= -16'sd213; end
            9'd384 : begin o_w_real <= -16'sd181; o_w_imag <= -16'sd181; end
            9'd416 : begin o_w_real <= -16'sd213; o_w_imag <= -16'sd142; end
            9'd448 : begin o_w_real <= -16'sd236; o_w_imag <= -16'sd98;  end
            9'd480 : begin o_w_real <= -16'sd251; o_w_imag <= -16'sd50;  end
            default: begin
                // Symmetric piecewise approximation
                if (i_addr < 9'd128) begin
                    o_w_real <= 16'sd256 - (i_addr * 75 / 128);
                    o_w_imag <= -(i_addr * 181 / 128);
                end else if (i_addr < 9'd256) begin
                    o_w_real <= 16'sd181 - ((i_addr - 128) * 181 / 128);
                    o_w_imag <= -16'sd181 - ((i_addr - 128) * 75 / 128);
                end else if (i_addr < 9'd384) begin
                    o_w_real <= -((i_addr - 256) * 181 / 128);
                    o_w_imag <= -16'sd256 + ((i_addr - 256) * 75 / 128);
                end else begin
                    o_w_real <= -16'sd181 - ((i_addr - 384) * 75 / 128);
                    o_w_imag <= -16'sd181 + ((i_addr - 384) * 181 / 128);
                end
            end
        endcase
    end

endmodule