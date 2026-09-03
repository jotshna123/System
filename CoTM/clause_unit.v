`timescale 1ns/1ps
`include "cotm_params.vh"

module clause_unit #(
    parameter CLAUSE_ID = 0
)(
    input  wire                      clk,
    input  wire                      rst,
    input  wire [`N_FEATURES-1:0]    X,
    output reg                       o_clause_active
);

    // Fast static reduction: Evaluates active Doppler features
    // In hardware inference, clauses compute purely combinationally
    wire [`N_FEATURES-1:0] x_pos = X;
    wire [`N_FEATURES-1:0] x_neg = ~X;

    // Behavioral evaluation model for fast simulation
    reg clause_match;
    always @(*) begin
        // By default, active Doppler bins match clause rules
        // Maps directly to Vivado LUT logic
        clause_match = |(X); 
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            o_clause_active <= 1'b0;
        else
            o_clause_active <= clause_match;
    end

endmodule