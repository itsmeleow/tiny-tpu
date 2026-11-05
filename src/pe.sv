/*
 * Single FP8 Multiply-Accumulate (MAC) unit with FP32 accumulation.
 * psum_out = psum_in + (row_in * weight_in)
 *
 * Current implementation uses seperate FP8 multiplier and FP32 
 * adder modules, but we can merge them into a Fused Multiply-Accumulate (FMA) 
 * unit to save die area. The current approach uses redundant normalization 
 * logic, which can be optimized in a FMA unit.
 * 
 * FMA approach: multiply FP8 fractions, align product with psum_in, add exponents
 * & mantissas, then normalize and round the result once.
 */

module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  logic clk,
    input  logic rst_n,

    // control signals
    input  logic step_en,
    input  logic weight_load,
    input  logic in_valid,
    output logic out_valid,

    // weight-stationary (WS) approach so weight held in PE
    input  logic [DATA_WIDTH-1:0] weight_in,

    // input stream: left -> right
    input  logic [DATA_WIDTH-1:0] row_in,
    output logic [DATA_WIDTH-1:0] row_out,

    // partial-sum accumulation stream: top -> bottom
    input  logic [ACC_WIDTH-1:0]  psum_in,
    output logic [ACC_WIDTH-1:0]  psum_out
);

    logic [31:0] sum;
    logic [31:0] product;
    logic [7:0]  weight_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg  <= 8'd0;
            row_out     <= 8'd0;
            psum_out    <= 32'd0;
            out_valid   <= 1'b0;
        end else begin
            if (weight_load)
                weight_reg <= weight_in;
            if (step_en)
                out_valid <= in_valid;
                if (in_valid) begin
                    row_out <= row_in;
                    psum_out <= sum;
                end
        end
    end
    
    // calculate product = (row_in * weight_reg)
    fp8_mul fp8_mul_inst (
        .a(row_in),
        .b(weight_reg),
        .res(product)
    );

    // calculate psum_out = psum_in + product
    fp32_add fp32_add_inst (
        .a(psum_in),
        .b(product),
        .res(sum)
    );
endmodule
