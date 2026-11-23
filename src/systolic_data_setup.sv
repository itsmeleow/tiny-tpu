/*
 * Systolic Data Setup (Activation Skew Unit)
 * - Delays row `r` by `r` clock cycles (both data and valid) so activations
 *   arrive offset, as expected by a weight-stationary MXU.
 * - Gated by `step_en` to stay locked in phase with `mxu` during stalls.
 */

module systolic_data_setup #(
    parameter ARRAY_SIZE = 2,
    parameter DATA_WIDTH = 8
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  step_en,

    input  logic                  act_in_valid  [ARRAY_SIZE],
    input  logic [DATA_WIDTH-1:0] act_in        [ARRAY_SIZE],

    output logic                  act_out_valid [ARRAY_SIZE],
    output logic [DATA_WIDTH-1:0] act_out       [ARRAY_SIZE]
);

    generate
        for (genvar row = 0; row < ARRAY_SIZE; row++) begin : gen_row
            if (row == 0) begin : passthrough
                // Row 0: 0-cycle delay
                assign act_out[0]       = act_in[0];
                assign act_out_valid[0] = act_in_valid[0];
            end else begin : skew_pipe
                // Row r: r-cycle shift register
                logic [DATA_WIDTH-1:0] data_pipe  [row];
                logic                  valid_pipe [row];

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (int k = 0; k < row; k++) begin
                            data_pipe[k]  <= '0;
                            valid_pipe[k] <= 1'b0;
                        end
                    end else if (step_en) begin
                        data_pipe[0]  <= act_in[row];
                        valid_pipe[0] <= act_in_valid[row];
                        for (int k = 1; k < row; k++) begin
                            data_pipe[k]  <= data_pipe[k-1];
                            valid_pipe[k] <= valid_pipe[k-1];
                        end
                    end
                end

                assign act_out[row]       = data_pipe[row-1];
                assign act_out_valid[row] = valid_pipe[row-1];
            end
        end
    endgenerate
endmodule
