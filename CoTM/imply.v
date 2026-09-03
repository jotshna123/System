`timescale 1ns/1ps
`include "cotm_params.vh"

module imply_block (
    input  wire [`N_FEATURES-1:0]         X,
    input  wire [`TOTAL_ELEMENTS-1:0]     A_flat,
    output wire [`TOTAL_ELEMENTS-1:0]     Imply_out
);

    wire [`N_LITERALS-1:0] literals;

    genvar i;
    generate
        for (i = 0; i < `N_FEATURES; i = i + 1) begin: lit_gen
            assign literals[2*i]   = X[i];
            assign literals[2*i+1] = ~X[i];
        end
    endgenerate

    genvar c, l;
    generate
        for (c = 0; c < `N_CLAUSES; c = c + 1) begin: clause_loop
            for (l = 0; l < `N_LITERALS; l = l + 1) begin: literal_loop
                wire inc   = A_flat[c * `N_LITERALS + l];
                wire x_bit = literals[l];
                assign Imply_out[c * `N_LITERALS + l] = (~inc) | x_bit;
            end
        end
    endgenerate

endmodule