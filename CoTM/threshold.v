`timescale 1ns/1ps
`include "cotm_params.vh"

module threshold_unit (
    input  wire signed [`MEM_BITS-1:0] score_c0,
    input  wire signed [`MEM_BITS-1:0] score_c1,
    input  wire signed [`MEM_BITS-1:0] score_c2,
    input  wire signed [`MEM_BITS-1:0] score_c3,
    input  wire signed [`MEM_BITS-1:0] score_c4,
    input  wire signed [`MEM_BITS-1:0] score_c5,

    output reg alert_clutter,
    output reg alert_drone,
    output reg alert_bird,
    output reg alert_missile,
    output reg alert_helicopter,
    output reg alert_jet
);

    always @(*) begin
        alert_clutter    = (score_c0 >= `THRESHOLD_VAL) ? 1'b1 : 1'b0;
        alert_drone      = (score_c1 >= `THRESHOLD_VAL) ? 1'b1 : 1'b0;
        alert_bird       = (score_c2 >= `THRESHOLD_VAL) ? 1'b1 : 1'b0;
        alert_missile    = (score_c3 >= `THRESHOLD_VAL) ? 1'b1 : 1'b0;
        alert_helicopter = (score_c4 >= `THRESHOLD_VAL) ? 1'b1 : 1'b0;
        alert_jet        = (score_c5 >= `THRESHOLD_VAL) ? 1'b1 : 1'b0;
    end

endmodule