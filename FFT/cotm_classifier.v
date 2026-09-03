`timescale 1ns / 1ps
`include "config_fft.vh"

module cotm_classifier (
    input                             i_clk,
    input                             i_rst_n,
    input                             i_feature_valid,   // Connected to o_radar_ready
    input        [`FFT_POINTS-1:0]    i_feature_vector,  // 1024-bit Boolean radar spectrum
    
    output reg   [1:0]                o_class_label,     // 2'b01: Target (Drone), 2'b00: Clutter/Noise
    output reg   signed [7:0]         o_confidence_score,
    output reg                        o_class_valid
);

    // Micro-Doppler Feature Clauses for Drone Identification
    // Clause 0 (+): Checks for symmetric blade harmonics (Bin 256 AND Bin 768)
    wire w_clause_pos_0 = i_feature_vector[256] & i_feature_vector[768];
    
    // Clause 1 (+): Checks for primary rotor fundamental
    wire w_clause_pos_1 = i_feature_vector[256] | i_feature_vector[768];
    
    // Clause 2 (-): Checks for broadband noise clutter in empty channels
    wire w_clause_neg_0 = i_feature_vector[1] & i_feature_vector[10];

    // Signed Summation Logic
    wire signed [7:0] w_pos_sum = (w_clause_pos_0 ? 8'sd2 : 8'sd0) + (w_clause_pos_1 ? 8'sd1 : 8'sd0);
    wire signed [7:0] w_neg_sum = (w_clause_neg_0 ? 8'sd2 : 8'sd0);
    wire signed [7:0] w_net_score = w_pos_sum - w_neg_sum;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_class_label      <= 2'b00;
            o_confidence_score <= 8'sd0;
            o_class_valid      <= 1'b0;
        end else begin
            if (i_feature_valid) begin
                o_confidence_score <= w_net_score;
                
                // Target decision: Score > 0 -> Drone detected
                if (w_net_score > 8'sd0) begin
                    o_class_label <= 2'b01; // Class 1: Drone Detected
                end else begin
                    o_class_label <= 2'b00; // Class 0: Clutter / Noise
                end
                
                o_class_valid <= 1'b1;
            end else begin
                o_class_valid <= 1'b0;
            end
        end
    end

endmodule