`timescale 1ns/1ps
`include "cotm_params.vh"

module cotm_top (
    input  wire clk,
    input  wire rst,

    // Memory write ports (kept for testbench compatibility)
    input  wire                                mem_write_en,
    input  wire [`CLAUSE_BITS-1:0]             mem_write_clause,
    input  wire [`LITERAL_BITS-1:0]            mem_write_literal,
    input  wire [`MEM_BITS-1:0]                mem_write_data,

    // Raw 1024-bit Feature Vector from FFT Binarizer
    input  wire [`N_FEATURES-1:0]              X,

    // Output Class Decision & Alerts
    output wire [`CLASS_BITS-1:0]              o_class_decision,
    output wire                                alert_clutter,
    output wire                                alert_drone,
    output wire                                alert_bird,
    output wire                                alert_missile,
    output wire                                alert_helicopter,
    output wire                                alert_jet
);

    // =========================================================================
    // Signal Aliases matching the generated header file conventions
    // =========================================================================
    wire [`N_FEATURES-1:0] i_feature_vector = X;
    wire [`N_FEATURES-1:0] pos = X;
    wire [`N_FEATURES-1:0] neg = ~X;

    // Clause Output Bus
    wire [`N_CLAUSES-1:0] Clause_out_comb;
    reg  [`N_CLAUSES-1:0] Clause_out_reg;

    // Include the generated rule equations
    `include "cotm_learned_rules.vh"

    always @(posedge clk or posedge rst) begin
        if (rst)
            Clause_out_reg <= {`N_CLAUSES{1'b0}};
        else
            Clause_out_reg <= Clause_out_comb;
    end

    // Score buses
    wire signed [`MEM_BITS-1:0] score_c0, score_c1, score_c2, score_c3, score_c4, score_c5;

    // Weighted Adder Block (reads C_matrix.mem)
    weighted_adder block4_weighted_adder (
        .Clause_out    (Clause_out_reg),
        .Class_decision(o_class_decision),
        .score_c0      (score_c0),
        .score_c1      (score_c1),
        .score_c2      (score_c2),
        .score_c3      (score_c3),
        .score_c4      (score_c4),
        .score_c5      (score_c5)
    );

    // Threshold Activation Block
    threshold_unit block5_threshold_unit (
        .score_c0        (score_c0),
        .score_c1        (score_c1),
        .score_c2        (score_c2),
        .score_c3        (score_c3),
        .score_c4        (score_c4),
        .score_c5        (score_c5),
        .alert_clutter   (alert_clutter),
        .alert_drone     (alert_drone),
        .alert_bird      (alert_bird),
        .alert_missile   (alert_missile),
        .alert_helicopter(alert_helicopter),
        .alert_jet       (alert_jet)
    );

endmodule