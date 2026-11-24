/*
 * Controller using FSM
 * Manages the sequencing of operations and data flow.
 *
 * - Will implement double buffering using a active + shadow 
 *   weight register so that we can hide weight load latency. 
 * - This will be done by allowing LOAD_WEIGHT to run while in 
 *   the MATMUL stage as that takes the most # cycles.
 */

module controller #(
    parameter DATA_W = 8,
    parameter CNT_W = 4
) (
    input  logic              clk,
    input  logic              rst_n,

    // AXI4-Stream Slave (Host -> TPU)
    input  logic [DATA_W-1:0] s_axis_tdata,
    input  logic              s_axis_tvalid,
    output logic              s_axis_tready,
    input  logic              s_axis_tlast,
    
    // AXI4-Stream Master (TPU -> Host)
    output logic              m_axis_tvalid,
    input  logic              m_axis_tready,
    output logic              m_axis_tlast,

    // Datapath control signals
    input  logic              ser_done,
    output logic              mxu_en,
    output logic              weight_load,
    output logic [1:0]        out_fmt,
    output logic [2:0]        vpu_op
);

    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        LOAD_WEIGHT = 3'b001,
        LOAD_ACT    = 3'b010,
        MATMUL      = 3'b011,
        ACTIVATE    = 3'b100,
        WRITE_MEM   = 3'b101
    } state_t;

    state_t state, next_state;

    logic s_handshake;
    assign s_handshake = s_axis_tvalid && s_axis_tlast;

    logic [DATA_W-1:0] cmd_reg;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cmd_reg <= 8'b0;
        end else 
            state <= next_state;

            case (state)
                IDLE: begin
                    if (s_handshake) begin
                        cmd_reg <= s_axis_tdata;
                    end
                end

                LOAD_WEIGHT, LOAD_ACT: begin
                    if (s_handshake) begin
                        
                    end
                end

                MATMUL: begin

                end

                ACTIVATE: begin

                end

                WRITE_MEM: begin

                end

                default: ;
            endcase
    end

    always_comb begin
        next_state = state;
        s_axis_tready = 1'b0;
    end
endmodule
