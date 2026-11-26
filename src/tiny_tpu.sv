module tiny_tpu #(
    parameter ARRAY_SIZE = 2,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic                  s_axis_tlast,

    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic                  m_axis_tlast
);
    // weight buffer -> MXU inputs
    logic                  mxu_weight_load;
    logic [DATA_WIDTH-1:0] mxu_weight_in [ARRAY_SIZE][ARRAY_SIZE];

    // activation buffer -> systolic_data_setup -> MXU inputs
    logic                  mxu_step_en;
    logic                  act_in_valid [ARRAY_SIZE];
    logic [DATA_WIDTH-1:0] act_in       [ARRAY_SIZE];

    // results <- MXU output
    logic                  mxu_res_valid [ARRAY_SIZE];
    logic [ACC_WIDTH-1:0]  mxu_res       [ARRAY_SIZE];

    // MXU -> VPU
    logic [ACC_WIDTH-1:0]  vpu_data;
    logic [2:0]            vpu_op;

    // Datapath control signals
    logic ser_done, ser_load, ser_last, ser_en, out_fmt; 

    // skew activations by 1 clock cycle using systolic_data_setup module
    logic                  skewed_act_valid [ARRAY_SIZE];
    logic [DATA_WIDTH-1:0] skewed_act       [ARRAY_SIZE];

    // vpu outputs
    logic [DATA_WIDTH-1:0] vpu_fp8_out;
    logic [ACC_WIDTH-1:0]  vpu_fp32_out;


    controller # (
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) controller_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .mxu_weight_load(mxu_weight_load),
        .mxu_weight_in(mxu_weight_in),
        .mxu_step_en(mxu_step_en),
        .act_in_valid(act_in_valid),
        .act_in(act_in),
        .mxu_res_valid(mxu_res_valid),
        .mxu_res(mxu_res),
        .vpu_data(vpu_data),
        .ser_done(ser_done),
        .ser_load(ser_load),
        .ser_last(ser_last),
        .ser_en(ser_en),
        .out_fmt(out_fmt),
        .vpu_op(vpu_op)
    );

    systolic_data_setup # (
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) skew_inst (
        .clk(clk),
        .rst_n(rst_n),
        .step_en(mxu_step_en),
        .act_in_valid(act_in_valid),
        .act_in(act_in),
        .act_out_valid(skewed_act_valid),
        .act_out(skewed_act)
    );

    mxu # (
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mxu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .step_en(mxu_step_en),
        .weight_load(mxu_weight_load),
        .weight_in(mxu_weight_in),
        .activation_in_valid(skewed_act_valid),
        .activation_in(skewed_act),
        .result_valid(mxu_res_valid),
        .result(mxu_res)
    );

    vpu vpu_inst (
        .fp32_in(vpu_data),
        .vpu_op(vpu_op),
        .fp8_out(vpu_fp8_out),
        .fp32_out(vpu_fp32_out)
    );

    axis_out_ser axis_out_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ser_load(ser_load),
        .ser_en(ser_en),
        .ser_last(ser_last),
        .out_fmt(out_fmt),
        .fp32_in(vpu_fp8_out),
        .fp8_in(vpu_fp32_out),
        .ser_done(ser_done),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

endmodule
