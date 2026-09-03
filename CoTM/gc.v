`timescale 1ns/1ps
`include "cotm_params.vh"

module gc_full (
    input  wire clk,
    input  wire rst,

    input  wire                       mem_write_en,
    input  wire [`CLAUSE_BITS-1:0]    mem_write_clause,
    input  wire [`LITERAL_BITS-1:0]   mem_write_literal,
    input  wire [`MEM_BITS-1:0]       mem_write_data,

    output reg  [`TOTAL_ELEMENTS-1:0] A_flat
);

    reg [`MEM_BITS-1:0] C [`TOTAL_ELEMENTS-1:0];

    initial begin
        $readmemh("C_matrix.mem", C);
    end

    wire [`TOTAL_ELEMENTS-1:0] A_comb;
    
    genvar c, l;
    generate
        for (c = 0; c < `N_CLAUSES; c = c + 1) begin: clause_loop
            for (l = 0; l < `N_LITERALS; l = l + 1) begin: literal_loop
                assign A_comb[c * `N_LITERALS + l] = (C[c * `N_LITERALS + l] > `TA_THRESHOLD) ? 1'b1 : 1'b0;
            end
        end
    endgenerate

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            A_flat <= {`TOTAL_ELEMENTS{1'b0}};
        end else begin
            if (mem_write_en) begin
                C[mem_write_clause * `N_LITERALS + mem_write_literal] <= mem_write_data;
            end
            A_flat <= A_comb;
        end
    end

endmodule