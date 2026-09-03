`timescale 1ns/1ps
`include "cotm_params.vh"

module and_tree (
    input  wire clk,
    input  wire rst,

    input  wire [`TOTAL_ELEMENTS-1:0] Imply_out,
    output reg  [`N_CLAUSES-1:0]      Clause_out
);

    wire [`N_CLAUSES-1:0] clause_comb;

    genvar c;
    generate
        for (c = 0; c < `N_CLAUSES; c = c + 1) begin: and_loop
            wire [`N_LITERALS-1:0] chunk = Imply_out[c * `N_LITERALS +: `N_LITERALS];
            assign clause_comb[c] = &chunk;
        end
    endgenerate

    always @(posedge clk or posedge rst) begin
        if (rst)
            Clause_out <= {`N_CLAUSES{1'b0}};
        else
            Clause_out <= clause_comb;
    end

endmodule