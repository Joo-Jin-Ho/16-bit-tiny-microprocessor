`timescale 1ns/1ps

module tinyCPU # (
    parameter FIRMWARE = ""
)(
    input clk_i,
    input rstn_i
);

    localparam IMSZ = 6;
    localparam DMSZ = 6;
    localparam [6:0] OP_ADD = 7'b000_0001;
    localparam [6:0] OP_SUB = 7'b000_0010;
    localparam [6:0] OP_XOR = 7'b000_0100;
    localparam [6:0] OP_LD  = 7'b000_1000;
    localparam [6:0] OP_ST  = 7'b001_0000;
    localparam [6:0] OP_JMP = 7'b010_0000;
    localparam [6:0] OP_JZ  = 7'b100_0000;
    localparam [15:0] NOP = 16'd0;

    // ============================================================
    // IF stage
    // ============================================================
    reg [15:0] F_PC;
    wire       branch_taken;
    wire [15:0] branch_target;

    always @(posedge clk_i or negedge rstn_i) begin
        if (~rstn_i) F_PC <= 16'hFFFE;
        else         F_PC <= branch_taken ? branch_target : (F_PC + 16'd2);
    end

    wire [15:0] D_IR;

    mem_behavior #(
        .firmware   (FIRMWARE),
        .bitline    (16),
        .bitaddr    (IMSZ),
        .binary     (1),
        .turnaround (1)
    ) U_imem (
        .clk     (clk_i),
        .en      (1'b1),
        .we      (1'b0),
        .addr    (F_PC[IMSZ:1]),
        .din     (),
        .dout    (D_IR),
        .rd_done (),
        .wr_done ()
    );

    // ============================================================
    // ID stage
    // ============================================================
    reg [15:0] D_PC;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) D_PC <= 16'd0;
        else        D_PC <= F_PC;
    end

    reg D_valid;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) D_valid <= 1'b0;
        else        D_valid <= 1'b1;
    end

    reg [15:0] GPR [0:7];
    integer k;

    wire        W_WEN;
    wire [2:0]  W_WA;
    wire [15:0] W_WD;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            for(k = 0; k < 8; k = k + 1)
                GPR[k] <= 16'd0;
        end
        else begin
            if(W_WEN && W_WA != 3'd0) 
                GPR[W_WA] <= W_WD;
        end
    end

    wire [6:0] D_OP = D_IR[15:9];
    wire [2:0] D_R1 = D_IR[5:3];
    wire [2:0] D_R2 = D_IR[2:0];


    wire [15:0] gpr_rd1 = (W_WEN && (W_WA == D_R1) && (D_R1 != 3'd0)) ? W_WD : GPR[D_R1];
    wire [15:0] gpr_rd2 = (W_WEN && (W_WA == D_R2) && (D_R2 != 3'd0)) ? W_WD : GPR[D_R2];

    wire [8:0]  d_imm9     = D_IR[8:0];
    wire [15:0] jmp_offset = {{6{d_imm9[8]}}, d_imm9, 1'b0};

    wire [6:0]  E_OP;
    wire [2:0]  E_Rd;
    wire        E_WEN_gpr;
    wire [6:0]  M_OP;
    wire [2:0]  M_Rd;
    wire        M_WEN_gpr;
    reg  [15:0] alu_out;
    reg  [15:0] M_ALUD;
    reg  [15:0] P_WD;

    reg [1:0] mD_JZ, mD_condz;

    always @(*) begin
        if      (E_WEN_gpr && (E_Rd == D_R1) && (D_R1 != 3'd0)) mD_JZ = 2'd1;
        else if (M_WEN_gpr && (M_Rd == D_R1) && (D_R1 != 3'd0)) mD_JZ = 2'd2;
        else if (W_WEN     && (W_WA == D_R1) && (D_R1 != 3'd0)) mD_JZ = 2'd3;
        else                                                    mD_JZ = 2'd0;
    end

    always @(*) begin
        if      (E_WEN_gpr && (E_Rd == D_R2) && (D_R2 != 3'd0)) mD_condz = 2'd1;
        else if (M_WEN_gpr && (M_Rd == D_R2) && (D_R2 != 3'd0)) mD_condz = 2'd2;
        else if (W_WEN     && (W_WA == D_R2) && (D_R2 != 3'd0)) mD_condz = 2'd3;
        else                                                    mD_condz = 2'd0;
    end

    wire [15:0] fwd_r1, fwd_r2;
    wire condz ;

    assign fwd_r1 = (mD_JZ == 2'd1) ? alu_out :
                    (mD_JZ == 2'd2) ? M_ALUD :
                    (mD_JZ == 2'd3) ? W_WD : gpr_rd1;

    assign fwd_r2 = (mD_condz == 2'd1) ? alu_out :
                    (mD_condz == 2'd2) ? M_ALUD :
                    (mD_condz == 2'd3) ? W_WD : gpr_rd2;

    assign condz = (fwd_r2 == 16'd0);

    assign branch_taken = D_valid && ((D_OP == OP_JMP) || ((D_OP == OP_JZ) && condz));

    assign branch_target = (D_OP == OP_JMP) ? (D_PC + 16'd2 + jmp_offset) :
                           (D_OP == OP_JZ)  ? (D_PC + 16'd2 + fwd_r1) : 16'd0;

    // ============================================================
    // EX stage
    // ============================================================
    reg [15:0] E_X;
    reg [15:0] E_Y;
    reg [9:0]  E_IR;
    reg [2:0]  E_R1;
    reg [2:0]  E_R2;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            E_X  <= 16'd0; E_Y  <= 16'd0; E_IR <= 10'd0; E_R1 <= 3'd0; E_R2 <= 3'd0;
        end
        else begin
            E_X <= gpr_rd1;
            E_Y <= gpr_rd2;

            if(!D_valid) begin
                E_IR <= 10'd0; E_R1 <= 3'd0; E_R2 <= 3'd0;
            end
            else begin
                E_IR <= {D_IR[15:9], D_IR[8:6]};
                E_R1 <= D_R1;
                E_R2 <= D_R2;
            end
        end
    end

    assign E_OP = E_IR[9:3];
    assign E_Rd = E_IR[2:0];
    assign E_WEN_gpr = (E_OP == OP_ADD) || (E_OP == OP_SUB) || (E_OP == OP_XOR) || (E_OP == OP_LD);

    reg [1:0] mE_X, mE_Y;

    always @(*) begin
        // ALU Input X (R1) Forwarding
        if      (M_WEN_gpr && (M_Rd == E_R1) && (E_R1 != 3'd0)) mE_X = 2'd1;
        else if (W_WEN     && (W_WA == E_R1) && (E_R1 != 3'd0)) mE_X = 2'd2;
        else                                                    mE_X = 2'd0;
    end

    always @(*) begin
        if      (M_WEN_gpr && (M_Rd == E_R2) && (E_R2 != 3'd0)) mE_Y = 2'd1;
        else if (W_WEN     && (W_WA == E_R2) && (E_R2 != 3'd0)) mE_Y = 2'd2;
        else                                                    mE_Y = 2'd0;
    end

    wire [15:0] alu_in_x = (mE_X == 2'd1) ? M_ALUD : (mE_X == 2'd2) ? W_WD : E_X;
    wire [15:0] alu_in_y = (mE_Y == 2'd1) ? M_ALUD : (mE_Y == 2'd2) ? W_WD : E_Y;

    always @(*) begin
        case(E_OP)
            OP_ADD:  alu_out = alu_in_x + alu_in_y;
            OP_SUB:  alu_out = alu_in_x - alu_in_y;
            OP_XOR:  alu_out = alu_in_x ^ alu_in_y;
            OP_LD:   alu_out = alu_in_x;
            OP_ST:   alu_out = alu_in_x;
            default: alu_out = 16'd0;
        endcase
    end

    // ============================================================
    // MEM stage
    // ============================================================
    reg [15:0] M_STD;
    reg [9:0]  M_IR;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            M_ALUD <= 16'd0; M_STD  <= 16'd0; M_IR   <= 10'd0;
        end
        else begin
            M_ALUD <= alu_out;
            M_STD  <= alu_in_y;
            M_IR   <= E_IR;
        end
    end

    assign M_OP = M_IR[9:3];
    assign M_Rd = M_IR[2:0];
    assign M_WEN_gpr = (M_OP == OP_ADD) || (M_OP == OP_SUB) || (M_OP == OP_XOR) || (M_OP == OP_LD);

    wire [15:0] dm_rdata;

    mem_behavior #(
        .firmware   (""),
        .bitline    (16),
        .bitaddr    (DMSZ),
        .binary     (1),
        .turnaround (1)
    ) U_dmem (
        .clk     (clk_i),
        .en      ((M_OP == OP_LD) || (M_OP == OP_ST)),
        .we      (M_OP == OP_ST),
        .addr    (M_ALUD[DMSZ-1:0]),
        .din     (M_STD),
        .dout    (dm_rdata),
        .rd_done (),
        .wr_done ()
    );

    // ============================================================
    // WB stage
    // ============================================================
    reg [15:0] W_ALUD;
    reg [9:0]  W_IR;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            W_ALUD <= 16'd0; W_IR   <= 10'd0; P_WD   <= 16'd0;
        end
        else begin
            W_ALUD <= M_ALUD;
            W_IR   <= M_IR;
            P_WD   <= W_WD;
        end
    end

    wire [6:0] W_OP = W_IR[9:3];
    assign W_WA = W_IR[2:0];

    assign W_WD = (W_OP == OP_LD) ? dm_rdata : W_ALUD;

    assign W_WEN = (W_OP == OP_ADD) ||
                   (W_OP == OP_SUB) ||
                   (W_OP == OP_XOR) ||
                   (W_OP == OP_LD);

endmodule
