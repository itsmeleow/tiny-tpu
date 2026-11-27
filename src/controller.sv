/*
 * Controller using FSM
 * Manages the sequencing of operations and data flow.
 *
 * - (Future): Will implement double buffering using a active + shadow 
 *   weight register so that we can hide weight load latency. 
 *   This will be done by allowing LOAD_WEIGHT to run while in 
 *   the MATMUL stage as that takes the most # cycles.
 */

module controller #(
    parameter ARRAY_SIZE    = 2,
    parameter DATA_WIDTH    = 8,
    parameter ACC_WIDTH     = 32,
    parameter MATMUL_CYCLES = 3 * ARRAY_SIZE
) (
    input  logic                  clk, // TODO: FIX MATMUL_CYCLES and check timings
    input  logic                  rst_n,

    // AXI-Stream Slave (Host -> TPU)
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic                  s_axis_tlast,

    // weight buffer -> MXU inputs
    output logic                  mxu_weight_load,
    output logic [DATA_WIDTH-1:0] mxu_weight_in [ARRAY_SIZE][ARRAY_SIZE],

    // activation buffer -> systolic_data_setup -> MXU inputs
    output logic                  mxu_step_en,
    output logic                  act_in_valid  [ARRAY_SIZE],
    output logic [DATA_WIDTH-1:0] act_in        [ARRAY_SIZE],

    // results <- MXU output
    input  logic                  mxu_res_valid [ARRAY_SIZE],
    input  logic [ACC_WIDTH-1:0]  mxu_res       [ARRAY_SIZE],

    // MXU -> VPU
    output logic [ACC_WIDTH-1:0]  vpu_data,

    // Datapath control signals
    input  logic                  ser_done,
    output logic                  ser_load,
    output logic                  ser_last,
    output logic                  ser_en,
    output logic                  out_fmt, // 0 = FP32 (4B), 1 = FP8 (1B)
    output logic [2:0]            vpu_op
);

    // opcodes
    localparam logic [2:0] CMD_LD_WEIGHT = 3'b001;
    localparam logic [2:0] CMD_LD_ACT    = 3'b010;
    localparam logic [2:0] CMD_MATMUL    = 3'b011;

    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        LOAD_WEIGHT = 3'b001,
        LOAD_ACT    = 3'b010,
        MATMUL      = 3'b011,
        ACTIVATE    = 3'b100,
        WRITE_MEM   = 3'b101
    } state_t;

    state_t state, next_state;

    /* 8-bit command format:
     * cmd_reg[7:5] = opcode
     * cmd_reg[4]   = unused
     * cmd_reg[3]   = out_fmt | 0 = FP32 (4B), 1 = FP8 (1B)
     * cmd_reg[2:0] = vpu_op  | 000 = Bypass, 001 = ReLU
     */
    logic [DATA_WIDTH-1:0] cmd_reg;

    // minimal scratchpad buffers
    logic [DATA_WIDTH-1:0] weight_buffer [ARRAY_SIZE][ARRAY_SIZE];
    logic [DATA_WIDTH-1:0] act_buffer    [ARRAY_SIZE][ARRAY_SIZE];
    logic [ACC_WIDTH-1:0]  res_buffer    [ARRAY_SIZE][ARRAY_SIZE];

    // counters
    logic [3:0] count;
    logic       res_wr_row [ARRAY_SIZE];

    logic s_handshake;
    assign s_handshake   = s_axis_tvalid && s_axis_tready;
    assign mxu_weight_in = weight_buffer;
    assign out_fmt       = cmd_reg[3];
    assign vpu_op        = cmd_reg[2:0];
    assign vpu_data      = res_buffer[count[1]][count[0]];

    // handle registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            cmd_reg <= 8'd0;
            count   <= 4'd0;
            for (int i = 0; i < ARRAY_SIZE; i++) begin
                res_wr_row[i] <= 1'b0;
                for (int j = 0; j < ARRAY_SIZE; j++) begin
                    weight_buffer[i][j] <= '0;
                    act_buffer[i][j]    <= '0;
                    res_buffer[i][j]    <= '0;
                end
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    count <= 4'd0;
                    for (int c = 0; c < ARRAY_SIZE; c++)
                        res_wr_row[c] <= 1'b0;
                    if (s_handshake)
                        cmd_reg <= s_axis_tdata;
                end

                LOAD_WEIGHT: begin
                    if (count < 4'd4) begin
                        if (s_handshake) begin
                            weight_buffer[count[1]][count[0]] <= s_axis_tdata;
                            // jump to cycle 4 pulse if tlast fires early
                            count <= s_axis_tlast ? 4'd4 : count + 4'd1;
                        end
                    end else begin
                        count <= 4'd0;
                    end
                end

                LOAD_ACT: begin
                    if (s_handshake) begin
                        act_buffer[count[1]][count[0]] <= s_axis_tdata;
                        count <= (count == 4'd3 || s_axis_tlast) ? 4'd0 : count + 4'd1;
                    end
                end

                MATMUL: begin
                    count <= (count == MATMUL_CYCLES - 1) ? 4'd0 : count + 4'd1;
                    for (int c = 0; c < ARRAY_SIZE; c++) begin
                        if (mxu_res_valid[c]) begin
                            res_buffer[res_wr_row[c]][c] <= mxu_res[c];
                            res_wr_row[c]                <= res_wr_row[c] + 1'b1;
                        end
                    end
                end

                ACTIVATE: begin
                    // hold count while serializer latches res_buffer[count[1]][count[0]]
                end

                WRITE_MEM: begin
                    if (ser_done)
                        count <= (count == 4'd3) ? 4'd0 : count + 4'd1;
                end

                default: ;
            endcase
        end
    end

    // handle next state & control outputs
    always_comb begin
        next_state      = state;
        s_axis_tready   = 1'b0;
        mxu_weight_load = 1'b0;
        mxu_step_en     = 1'b0;
        ser_load        = 1'b0;
        ser_en          = 1'b0;
        ser_last        = (count == 4'd3);

        for (int r = 0; r < ARRAY_SIZE; r++) begin
            act_in[r]       = '0;
            act_in_valid[r] = 1'b0;
        end

        case (state)
            IDLE: begin
                s_axis_tready = 1'b1;
                if (s_handshake) begin
                    case (s_axis_tdata[7:5])
                        CMD_LD_WEIGHT: next_state = LOAD_WEIGHT;
                        CMD_LD_ACT:    next_state = LOAD_ACT;
                        CMD_MATMUL:    next_state = MATMUL;
                        default:       next_state = IDLE;
                    endcase
                end
            end

            LOAD_WEIGHT: begin
                if (count < 4'd4) begin
                    s_axis_tready = 1'b1;
                end else begin
                    // all 4 weights are in weight_buffer -> into MXU
                    mxu_weight_load = 1'b1;
                    next_state      = IDLE;
                end
            end

            LOAD_ACT: begin
                s_axis_tready = 1'b1;
                if (s_handshake && (count == 4'd3 || s_axis_tlast))
                    next_state = MATMUL;
            end

            MATMUL: begin
                mxu_step_en = 1'b1;
                if (count < ARRAY_SIZE) begin
                    for (int r = 0; r < ARRAY_SIZE; r++) begin
                        act_in[r]       = act_buffer[count[0]][r];
                        act_in_valid[r] = 1'b1;
                    end
                end
                if (count == MATMUL_CYCLES - 1)
                    next_state = ACTIVATE;
            end

            ACTIVATE: begin
                ser_load   = 1'b1;
                next_state = WRITE_MEM;
            end

            WRITE_MEM: begin
                ser_en = 1'b1;
                if (ser_done)
                    next_state = (count == 4'd3) ? IDLE : ACTIVATE;
            end

            default: next_state = IDLE;
        endcase
    end
endmodule
