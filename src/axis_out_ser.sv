/* 
 * AXI4-Stream output serializer
 *
 */

module axis_out_ser #(
    parameter DATA_WIDTH    = 8,
    parameter ACC_WIDTH     = 32,
) (
    input  logic        clk,
    input  logic        rst_n,

    // From controller + VPU/downcast
    input  logic        ser_load,
    input  logic        ser_en,
    input  logic        ser_last,
    input  logic        out_fmt, // 0 = FP32 (4B), 1 = FP8 (1B)
    input  logic [31:0] fp32_in,
    input  logic [7:0]  fp8_in,
    output logic        ser_done,

    // AXI-Stream Master (TPU -> Host)
    output logic [7:0]  m_axis_tdata,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    output logic        m_axis_tlast
);

    logic [31:0] shift_reg;
    logic [1:0]  bytes_left;

    assign m_axis_tvalid = ser_en;
    assign m_axis_tdata  = shift_reg[7:0];
    assign m_axis_tlast  = ser_en && ser_last && (bytes_left == 2'd0);
    assign ser_done      = ser_en && m_axis_tready && (bytes_left == 2'd0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= 32'd0;
            bytes_left <= 2'd0;
        end else if (ser_load) begin
            shift_reg  <= out_fmt ? {24'd0, fp8_in} : fp32_in;
            bytes_left <= out_fmt ? 2'd0 : 2'd3;
        end else if (ser_en && m_axis_tready && (bytes_left != 2'd0)) begin
            shift_reg  <= {8'd0, shift_reg[31:8]};
            bytes_left <= bytes_left - 2'd1;
        end
    end

endmodule