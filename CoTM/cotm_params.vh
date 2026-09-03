// =============================================================================
// GLOBAL RADAR CoTM HARDWARE PARAMETERS
// =============================================================================
`ifndef COTM_PARAMS_VH
`define COTM_PARAMS_VH

`define N_FEATURES       1024       // 1024 FFT Doppler bins
`define N_LITERALS       2048       // 2 * 1024 (Original + Negated literals)
`define N_CLAUSES        120        // CoTM single shared clause bank
`define N_CLASSES        6          // 0:Clutter, 1:Drone, 2:Bird, 3:Missile, 4:Heli, 5:Jet
`define MEM_BITS         8          // 8-bit resolution for weights and automata
`define TA_THRESHOLD     128        // Automata decision state boundary (N)
`define THRESHOLD_VAL    8'sd25     // System voting threshold (T = 25)
`define TOTAL_ELEMENTS   (`N_CLAUSES * `N_LITERALS)
`define CLAUSE_BITS      7          // $clog2(120) = 7
`define LITERAL_BITS     11         // $clog2(2048) = 11
`define CLASS_BITS       3          // $clog2(6) = 3

`endif