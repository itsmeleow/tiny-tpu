/*
 * FP8 Matrix Multiply Unit with a 2x2 systolic array.
 * Supports preloading weights when weight_load = 1 and step_en = 0
 */
     
module mxu #(
    parameter ARRAY_SIZE = 2,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  logic clk,
    input  logic rst_n,
    input  logic step_en,
    input  logic weight_load,

    input  logic [DATA_WIDTH-1:0] weight_in [ARRAY_SIZE][ARRAY_SIZE],

    input  logic                  activation_in_valid [ARRAY_SIZE],
    input  logic [DATA_WIDTH-1:0] activation_in       [ARRAY_SIZE],
    
    output logic                  result_valid [ARRAY_SIZE],
    output logic [ACC_WIDTH-1:0]  result       [ARRAY_SIZE]
);
    logic activation_valid_bus [ARRAY_SIZE][ARRAY_SIZE+1];

    logic [DATA_WIDTH-1:0] activation_bus [ARRAY_SIZE][ARRAY_SIZE+1];
    logic [ACC_WIDTH-1:0]  psum_bus       [ARRAY_SIZE+1][ARRAY_SIZE];

    generate
        for (genvar row = 0; row < ARRAY_SIZE; row++) begin : activation_load_loop
            assign activation_bus[row][0] = activation_in[row];
            assign activation_valid_bus[row][0] = activation_in_valid[row];
        end
    endgenerate

    generate
        for (genvar col = 0; col < ARRAY_SIZE; col++) begin: psum_edge_loop
            assign psum_bus[0][col] = '0;
            assign result[col] = psum_bus[ARRAY_SIZE][col];
            assign result_valid[col] = activation_valid_bus[ARRAY_SIZE-1][col+1];

        end
    endgenerate

    // systolic array of processing elements (PEs)
    generate
        for (genvar i = 0; i < ARRAY_SIZE; i++) begin : row_loop
            for (genvar j = 0; j < ARRAY_SIZE; j++) begin : col_loop
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .step_en(step_en),
                    .weight_load(weight_load),
                    .in_valid(activation_valid_bus[i][j]),
                    .out_valid(activation_valid_bus[i][j+1]),
                    .weight_in(weight_in[i][j]),
                    .activation_in(activation_bus[i][j]),
                    .activation_out(activation_bus[i][j+1]),
                    .psum_in(psum_bus[i][j]),
                    .psum_out(psum_bus[i+1][j])
                );
            end
        end
    endgenerate
endmodule
