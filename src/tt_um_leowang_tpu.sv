/*
 * Copyright (c) 2026 Leo Wang
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_leowang_tpu (
    input  logic [7:0] ui_in,
    output logic [7:0] uo_out,
    input  logic [7:0] uio_in,
    output logic [7:0] uio_out,
    output logic [7:0] uio_oe,
    input  logic       ena,
    input  logic       clk,
    input  logic       rst_n
);

    localparam int DATA_WIDTH = 8;

    // set bidirectional pin's DIR based on pinout shown in info.yaml
    // 1 = output (bits 6, 4, 1), 0 = input (bits 7, 5, 3, 2, 0)
    assign uio_oe = 8'b0101_0010;

    logic s_axis_tvalid, s_axis_tready, s_axis_tlast;
    logic m_axis_tvalid, m_axis_tready, m_axis_tlast;

    assign s_axis_tvalid = uio_in[0];
    assign s_axis_tlast = uio_in[2];
    assign m_axis_tready = uio_in[5];
    assign uio_out = {1'b0, m_axis_tlast, 1'b0, m_axis_tvalid, 2'b00, s_axis_tready, 1'b0};


    logic [DATA_WIDTH-1:0] s_axis_tdata, m_axis_tdata;
    assign s_axis_tdata = ui_in[7:0];
    assign uo_out[7:0] = m_axis_tdata;

    tiny_tpu tpu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );
    
    wire _unused = &{ena, uio_in[7:6], uio_in[4:3], uio_in[1], 1'b0};
endmodule
