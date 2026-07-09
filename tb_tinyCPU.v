/***************************************************************************
 * Copyright (C) 2026 Intelligent System Architecture (ISA) Lab. All rights reserved. 
 * 
 * This file is written solely for academic use in 
 * Elementary Electrical and Electronics Design and Software Practice  
 * Or shortly, Electrical and Electronics Experiment I course lab session
 * School of Electrical and Electronics Engineering, Konkuk University 
 *
 * Unauthorized distribution is strictly prohibited.
 ***************************************************************************/

`timescale 1ns/1ps

module tb_tinyCPU;

    reg clk, rstn;
    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    tinyCPU U_cpu (
        .clk_i  (clk),
        .rstn_i (rstn)
    );

    // ================================================================
    //  Instruction Encoding Functions
    // ================================================================
    //  [15:12] type   [11:9] funct   [8:6] Rd   [5:3] Rs1   [2:0] Rs2
    //
    //  ADD Rd,Rs1,Rs2 : type=0000  funct=001
    //  SUB Rd,Rs1,Rs2 : type=0000  funct=010
    //  LD  Rd,Rs      : type=0001  funct=000  Rs2=000
    //  ST  Ra,Rd       : type=0010  funct=000  Rd field=000
    //  JZ  Roff,Rcond : type=1000  funct=000  Rd field=000
    //  NOP            : 16'h0000

    function [15:0] ADD;
        input [2:0] rd;
        input [2:0] rs1;
        input [2:0] rs2;
        ADD = {4'b0000, 3'b001, rd, rs1, rs2};
    endfunction

    function [15:0] SUB;
        input [2:0] rd;
        input [2:0] rs1;
        input [2:0] rs2;
        SUB = {4'b0000, 3'b010, rd, rs1, rs2};
    endfunction

    function [15:0] LD;
        input [2:0] rd;
        input [2:0] rs;
        LD = {4'b0001, 3'b000, rd, rs, 3'b000};
    endfunction

    function [15:0] ST;
        input [2:0] ra;
        input [2:0] rd;
        ST = {4'b0010, 3'b000, 3'b000, ra, rd};
    endfunction

    function [15:0] JZ;
        input [2:0] roff;
        input [2:0] rcond;
        JZ = {4'b1000, 3'b000, 3'b000, roff, rcond};
    endfunction

    localparam [15:0] NOP = 16'h0000;

    // ================================================================
    //  Test Infrastructure
    // ================================================================
    integer pass_cnt, fail_cnt, test_num;

    // ---- init : reset → IMEM clear → GPR initialization (R1=5, R2=3) ----
    task init;
        integer j;
        begin
            rstn = 1'b0;
            repeat (3) @(posedge clk);
            for (j = 0; j < 32; j = j + 1)
                U_cpu.U_imem.memory[j] = NOP;
            @(negedge clk);
            rstn = 1'b1;
            for (j = 0; j < 8; j = j + 1)
                U_cpu.GPR[j] = 16'd0;
            U_cpu.GPR[1] = 16'd5;
            U_cpu.GPR[2] = 16'd3;
        end
    endtask

    // ---- run N cycles ----
    task run;
        input integer n;
        begin
            repeat (n) @(posedge clk);
        end
    endtask

    // ---- GPR verification ----
    task check;
        input [2:0]       idx;
        input [15:0]      exp;
        input [8*80-1:0]  msg;
        begin
            test_num = test_num + 1;
            if (U_cpu.GPR[idx] === exp) begin
                $display("    [PASS] #%02d  R%0d = %-5d  (exp %-5d)  %0s",
                         test_num, idx, U_cpu.GPR[idx], exp, msg);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("    [FAIL] #%02d  R%0d = %-5d  (exp %-5d)  %0s",
                         test_num, idx, U_cpu.GPR[idx], exp, msg);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // ================================================================
    //  Pipeline Monitor  
    // ================================================================
    integer cyc;
    always @(posedge clk or negedge rstn)
        if (!rstn) cyc <= 0;
        else       cyc <= cyc + 1;

    always @(posedge clk) begin
        if (rstn) begin
            $display("  [%3d] PC=%04h | D=%04h E=%04h M=%04h W=%04h | R0-7: %0d %0d %0d %0d %0d %0d %0d %0d",
                cyc, U_cpu.F_PC,
                U_cpu.D_IR, U_cpu.E_IR, U_cpu.M_IR, U_cpu.W_IR,
                U_cpu.GPR[0], U_cpu.GPR[1], U_cpu.GPR[2], U_cpu.GPR[3],
                U_cpu.GPR[4], U_cpu.GPR[5], U_cpu.GPR[6], U_cpu.GPR[7]);
        end
    end

    // ================================================================
    //  Main Test Sequence
    //  GPR initial values : R1=5, R2=3, the others=0
    // ================================================================
    initial begin
        //$dumpfile("dump_fwd.vcd");
        //$dumpvars(0, tb_tinyCPU);

        clk       = 1'b0;
        rstn      = 1'b0;
        pass_cnt = 0;  fail_cnt = 0;  test_num = 0;

        // ============================================================
        //  A — Distance 1 (back-to-back)
        // ============================================================

        // ---- A1 : EX→EX , Rs1 ----
        $display("\n===== [A1] Dist-1 : EX->EX (Rs1) =====");
        $display("  [0] add R3,R1,R2  => R3 = 5+3 = 8");
        $display("  [1] add R4,R3,R1  => R4 = 8+5 = 13  (R3 fwd)");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = ADD(4, 3, 1);
        run(10);
        check(3, 16'd8,  "R3 = R1+R2");
        check(4, 16'd13, "R4 = R3+R1  EX->EX(Rs1)");

        // ---- A2 : EX→EX , Rs2 ----
        $display("\n===== [A2] Dist-1 : EX->EX (Rs2) =====");
        $display("  [0] add R3,R1,R2  => R3 = 8");
        $display("  [1] add R4,R1,R3  => R4 = 5+8 = 13  (R3 fwd)");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = ADD(4, 1, 3);
        run(10);
        check(4, 16'd13, "R4 = R1+R3  EX->EX(Rs2)");

        // ---- A3 : EX→EX , Rs1 & Rs2  ----
        $display("\n===== [A3] Dist-1 : EX->EX (Rs1 & Rs2 both) =====");
        $display("  [0] add R3,R1,R2  => R3 = 8");
        $display("  [1] sub R4,R3,R3  => R4 = 8-8 = 0   (R3 fwd both)");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = SUB(4, 3, 3);
        run(10);
        check(4, 16'd0, "R4 = R3-R3  EX->EX(both)");

        // ---- A4 : EX→EX , ST data forwarding ----
        $display("\n===== [A4] Dist-1 : EX->EX (ST data) =====");
        $display("  [0] add R3,R1,R2  => R3 = 8");
        $display("  [1] st  R0,R3     => MEM[0] = 8  (R3 fwd)");
        $display("  [2] ld  R4,R0     => R4 = MEM[0] = 8");
        $display("  [3] nop           (load-use gap)");
        $display("  [4] add R5,R4,R0  => R5 = 8");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = ST(0, 3);
        U_cpu.U_imem.memory[2] = LD(4, 0);
        U_cpu.U_imem.memory[3] = NOP;
        U_cpu.U_imem.memory[4] = ADD(5, 4, 0);
        run(12);
        check(5, 16'd8, "R5 = LD(ST(R3))  EX->EX(ST data)");

        // ---- A5 : EX→ID , JZ condition (dist 1 from JZ) ----
        //  JZ at word 5 (byte 10). target = 12 + R5 = 12 + 6 = 18 = word 9
        $display("\n===== [A5] Dist-1 : EX->ID (JZ condition) =====");
        $display("  [0] add R5,R2,R2  => R5 = 6 (byte offset)");
        $display("  [1] sub R3,R1,R1  => R3 = 0 (condition)");
        $display("  [2] jz  R5,R3     => taken -> word 6  (R3 fwd EX->ID)");
        $display("  [3] nop           => simple delay slot");
        $display("  [4] add R4,R1,R1  => must be skipped R4=10");
        $display("  [5] add R5,R1,R1  => must be skipped R5=10");
        $display("  [6] add R6,R1,R2  => R6 = 8 (branch target)");
        init;
        U_cpu.U_imem.memory[0]  = ADD(5, 2, 2);
        U_cpu.U_imem.memory[1]  = SUB(3, 1, 1);
        U_cpu.U_imem.memory[2]  = JZ(5, 3);
        U_cpu.U_imem.memory[3]  = NOP;
        U_cpu.U_imem.memory[4]  = ADD(4, 1, 1);
        U_cpu.U_imem.memory[5]  = ADD(5, 1, 1);
        U_cpu.U_imem.memory[6]  = ADD(6, 1, 2);
        run(15);
        check(6, 16'd8, "R6 = target reached  EX->ID(JZ)");
        check(5, 16'd6, "R5 = 6, must be skipped");
        check(4, 16'd0, "R4 = 0, must be skipped");
        
        

        // ============================================================
        //  B — Distance 2 (one-instruction gap)
        // ============================================================

        // ---- B1 : MEM→EX , Rs1 ----
        $display("\n===== [B1] Dist-2 : MEM->EX (Rs1) =====");
        $display("  [0] add R3,R1,R2  => R3 = 8");
        $display("  [1] nop");
        $display("  [2] add R4,R3,R1  => R4 = 13  (R3 fwd from MEM)");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = NOP;
        U_cpu.U_imem.memory[2] = ADD(4, 3, 1);
        run(10);
        check(4, 16'd13, "R4 = R3+R1  MEM->EX(Rs1)");

        // ---- B2 : MEM→EX , Rs2 ----
        $display("\n===== [B2] Dist-2 : MEM->EX (Rs2) =====");
        $display("  [0] add R3,R1,R2  => R3 = 8");
        $display("  [1] nop");
        $display("  [2] add R4,R1,R3  => R4 = 13  (R3 fwd from MEM)");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = NOP;
        U_cpu.U_imem.memory[2] = ADD(4, 1, 3);
        run(10);
        check(4, 16'd13, "R4 = R1+R3  MEM->EX(Rs2)");

        // ---- B3 : LD → ALU , distance 2 (WB→EX) ----
        $display("\n===== [B3] Dist-2 : LD -> ALU (WB->EX) =====");
        $display("  pre: DMEM[0] = 7");
        $display("  [0] ld  R3,R0     => R3 = MEM[0] = 7");
        $display("  [1] nop           (load-use gap)");
        $display("  [2] add R4,R3,R1  => R4 = 7+5 = 12  (R3 fwd)");
        init;
        U_cpu.U_dmem.memory[0]  = 16'd7;
        U_cpu.U_imem.memory[0]  = LD(3, 0);
        U_cpu.U_imem.memory[1]  = NOP;
        U_cpu.U_imem.memory[2]  = ADD(4, 3, 1);
        run(12);
        check(4, 16'd12, "R4 = R3+R1  LD WB->EX");

        // ---- B4 : MEM→ID , JZ condition (dist 2 from JZ) ----
        //  JZ at word 5 (byte 10). target = 12 + 6 = 18 = word 9
        $display("\n===== [B4] Dist-2 : MEM->ID (JZ condition) =====");
        $display("  [0] add R5,R2,R2  => R5 = 6");
        $display("  [1] sub R3,R1,R1  => R3 = 0");
        $display("  [2] nop           (gap → R3 in MEM when JZ in ID)");
        $display("  [3] jz  R5,R3     => taken -> word 7  (R3 fwd MEM->ID)");
        $display("  [4] nop (simple delay slot)");
        $display("  [5] add R4,R1,R1  => must be skipped R4=10");
        $display("  [7] add R6,R1,R2  => R6 = 8 (target)");
        init;
        U_cpu.U_imem.memory[0]  = ADD(5, 2, 2);
        U_cpu.U_imem.memory[1]  = SUB(3, 1, 1);
        U_cpu.U_imem.memory[2]  = NOP;
        U_cpu.U_imem.memory[3]  = JZ(5, 3);
        U_cpu.U_imem.memory[4]  = NOP;
        U_cpu.U_imem.memory[5]  = ADD(4, 1, 1);
        U_cpu.U_imem.memory[6]  = NOP;
        U_cpu.U_imem.memory[7]  = ADD(6, 1, 2);
        run(15);
        check(6, 16'd8, "R6 = target reached  MEM->ID(JZ)");
        check(4, 16'd0, "R4 = 0  must be skipped");



        // ============================================================
        //  C — Distance 3 (two-instruction gap)
        // ============================================================

        // ---- C1 : WB/RF , Rs1 ----
        $display("\n===== [C1] Dist-3 : WB/RF (Rs1) =====");
        $display("  [0] add R3,R1,R2  => R3 = 8");
        $display("  [1-2] nop x2");
        $display("  [3] add R4,R3,R1  => R4 = 13  (R3 via RF or WB bypass)");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = NOP;
        U_cpu.U_imem.memory[2] = NOP;
        U_cpu.U_imem.memory[3] = ADD(4, 3, 1);
        run(12);
        check(4, 16'd13, "R4 = R3+R1  WB/RF(Rs1)");

        // ---- C2 : WB/RF , Rs2 ----
        $display("\n===== [C2] Dist-3 : WB/RF (Rs2) =====");
        $display("  [0] add R3,R1,R2  => R3 = 8");
        $display("  [1-2] nop x2");
        $display("  [3] add R4,R1,R3  => R4 = 13");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = NOP;
        U_cpu.U_imem.memory[2] = NOP;
        U_cpu.U_imem.memory[3] = ADD(4, 1, 3);
        run(12);
        check(4, 16'd13, "R4 = R1+R3  WB/RF(Rs2)");

 

        // ============================================================
        //  D — Mixed / Priority
        // ============================================================

        // ---- D1 : Dist-1(Rs1) + Dist-2(Rs2)  ----
        $display("\n===== [D1] Dist-1(Rs1) + Dist-2(Rs2) =====");
        $display("  [0] add R3,R1,R2  => R3 = 8   (dist 2 from [2])");
        $display("  [1] add R4,R1,R1  => R4 = 10  (dist 1 from [2])");
        $display("  [2] sub R5,R4,R3  => R5 = 10-8 = 2");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = ADD(4, 1, 1);
        U_cpu.U_imem.memory[2] = SUB(5, 4, 3);
        run(10);
        check(5, 16'd2, "R5 = R4-R3  EX->EX(Rs1) + MEM->EX(Rs2)");

        // ---- D2 : Dist-2(Rs1) + Dist-1(Rs2)  ----
        $display("\n===== [D2] Dist-2(Rs1) + Dist-1(Rs2) =====");
        $display("  [0] add R3,R1,R2  => R3 = 8   (dist 2 from [2])");
        $display("  [1] add R4,R1,R1  => R4 = 10  (dist 1 from [2])");
        $display("  [2] add R5,R3,R4  => R5 = 8+10 = 18");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = ADD(4, 1, 1);
        U_cpu.U_imem.memory[2] = ADD(5, 3, 4);
        run(10);
        check(5, 16'd18, "R5 = R3+R4  MEM->EX(Rs1) + EX->EX(Rs2)");

        // ---- D3 : Repeatedly Rd write ----
        $display("\n===== [D3] Same Rd : Dist-1 priority over Dist-2 =====");
        $display("  [0] add R3,R1,R2  => R3 = 8   (dist 2, no effect)");
        $display("  [1] add R3,R1,R1  => R3 = 10  (dist 1, priority)");
        $display("  [2] add R4,R3,R0  => R4 = 10");
        init;
        U_cpu.U_imem.memory[0] = ADD(3, 1, 2);
        U_cpu.U_imem.memory[1] = ADD(3, 1, 1);
        U_cpu.U_imem.memory[2] = ADD(4, 3, 0);
        run(10);
        check(4, 16'd10, "R4 = R3(dist-1=10)  priority check");

        // ============================================================
        //  Summary
        // ============================================================
        $display("\n============================================================");
        $display("  Total : %0d", test_num);
        $display("  Pass  : %0d", pass_cnt);
        $display("  Fail  : %0d", fail_cnt);
        if (fail_cnt == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED <<<");
        $display("============================================================\n");

        #100;
        $stop;
    end

endmodule