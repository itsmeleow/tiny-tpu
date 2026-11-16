/*
 * Copyright (c) 2026 Leo Wang (itsmeleow)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_itsmeleow_tiny_tpu (
    input  logic [7:0] ui_in,
    output logic [7:0] uo_out,
    input  logic [7:0] uio_in,
    output logic [7:0] uio_out,
    output logic [7:0] uio_oe,
    input  logic       ena,
    input  logic       clk,
    input  logic       rst_n
);
    localparam logic [2:0] CMD_WRITE_WEIGHT = 3'd1;
    localparam logic [2:0] CMD_LOAD_WEIGHTS = 3'd2;
    localparam logic [2:0] CMD_STAGE_A0     = 3'd3;
    localparam logic [2:0] CMD_PUSH_ROW     = 3'd4;
    localparam logic [2:0] CMD_DRAIN        = 3'd5;
    localparam logic [2:0] CMD_READ_STATUS  = 3'd6;

    logic [2:0] cmd;
    logic step_en;
    logic weight_load;
    logic push_row;

    logic [7:0] weight_regs [2][2];
    logic [7:0] staged_a0;
    logic [7:0] delayed_a1;
    logic       delayed_a1_valid;

    logic [7:0]  activation_in       [2];
    logic        activation_in_valid [2];
    logic [31:0] result              [2];
    logic        result_valid        [2];
    logic [31:0] selected_result;

    assign cmd         = uio_in[2:0];
    assign push_row    = ena && (cmd == CMD_PUSH_ROW);
    assign step_en     = push_row || (ena && (cmd == CMD_DRAIN));
    assign weight_load = ena && (cmd == CMD_LOAD_WEIGHTS);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int row = 0; row < 2; row++) begin
                for (int col = 0; col < 2; col++) begin
                    weight_regs[row][col] <= '0;
                end
            end
            staged_a0        <= '0;
            delayed_a1       <= '0;
            delayed_a1_valid <= 1'b0;
        end else if (ena) begin
            if (cmd == CMD_WRITE_WEIGHT)
                weight_regs[uio_in[4]][uio_in[3]] <= ui_in;

            if (cmd == CMD_STAGE_A0)
                staged_a0 <= ui_in;

            if (step_en) begin
                delayed_a1_valid <= push_row;
                if (push_row)
                    delayed_a1 <= ui_in;
            end
        end
    end

    assign activation_in[0]       = staged_a0;
    assign activation_in_valid[0] = push_row;
    assign activation_in[1]       = delayed_a1;
    assign activation_in_valid[1] = delayed_a1_valid;

    mxu mxu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .step_en(step_en),
        .weight_load(weight_load),
        .weight_in(weight_regs),
        .activation_in_valid(activation_in_valid),
        .activation_in(activation_in),
        .result_valid(result_valid),
        .result(result)
    );

    assign selected_result = result[uio_in[5]];
    assign uo_out = (cmd == CMD_READ_STATUS)
                  ? {6'b0, result_valid[1], result_valid[0]}
                  : selected_result[8 * uio_in[7:6] +: 8];

    assign uio_out = '0;
    assign uio_oe  = '0;
endmodule
