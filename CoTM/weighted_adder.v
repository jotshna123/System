`timescale 1ns/1ps
`include "cotm_params.vh"

module weighted_adder (
    input  wire [`N_CLAUSES-1:0]          Clause_out,
    output reg  [`CLASS_BITS-1:0]         Class_decision,
    output reg  signed [`MEM_BITS-1:0]    score_c0,
    output reg  signed [`MEM_BITS-1:0]    score_c1,
    output reg  signed [`MEM_BITS-1:0]    score_c2,
    output reg  signed [`MEM_BITS-1:0]    score_c3,
    output reg  signed [`MEM_BITS-1:0]    score_c4,
    output reg  signed [`MEM_BITS-1:0]    score_c5
);

    reg signed [`MEM_BITS-1:0] W_BANK [0:(`N_CLASSES * `N_CLAUSES)-1];

    initial begin
        $readmemh("C_matrix.mem", W_BANK);
    end

    integer j;
    reg signed [`MEM_BITS-1:0] s0, s1, s2, s3, s4, s5;

    always @(*) begin
        s0 = `MEM_BITS'sd0;
        s1 = `MEM_BITS'sd0;
        s2 = `MEM_BITS'sd0;
        s3 = `MEM_BITS'sd0;
        s4 = `MEM_BITS'sd0;
        s5 = `MEM_BITS'sd0;

        for (j = 0; j < `N_CLAUSES; j = j + 1) begin
            if (Clause_out[j]) begin
                s0 = s0 + W_BANK[0 * `N_CLAUSES + j];
                s1 = s1 + W_BANK[1 * `N_CLAUSES + j];
                s2 = s2 + W_BANK[2 * `N_CLAUSES + j];
                s3 = s3 + W_BANK[3 * `N_CLAUSES + j];
                s4 = s4 + W_BANK[4 * `N_CLAUSES + j];
                s5 = s5 + W_BANK[5 * `N_CLAUSES + j];
            end
        end

        score_c0 = s0;
        score_c1 = s1;
        score_c2 = s2;
        score_c3 = s3;
        score_c4 = s4;
        score_c5 = s5;

        // ArgMax Comparator Logic
        Class_decision = 3'd0;
        if (s1 > s0) Class_decision = 3'd1;
        if (s2 > s1 && s2 > s0) Class_decision = 3'd2;
        if (s3 > s2 && s3 > s1 && s3 > s0) Class_decision = 3'd3;
        if (s4 > s3 && s4 > s2 && s4 > s1 && s4 > s0) Class_decision = 3'd4;
        if (s5 > s4 && s5 > s3 && s5 > s2 && s5 > s1 && s5 > s0) Class_decision = 3'd5;
    end

endmodule