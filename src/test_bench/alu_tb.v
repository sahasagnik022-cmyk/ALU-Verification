`timescale 1ns/1ps
`include "alu_test.v"
`include "alu_ref.v"
//`include "alu.v"
module alu_tb;

parameter WIDTH = 8;
parameter CMD_WIDTH =4;

reg CLK, RST, CE, MODE, CIN;
reg [1:0] INP_VALID;
reg [3:0] CMD;
reg [WIDTH-1:0] OPA, OPB;

wire [(WIDTH*2)-1:0] RES;
wire ERR, OFLOW, COUT, G, L, E;
reg [(WIDTH*2)-1:0] last_valid_res;

//Test counters
integer pass_count, fail_count, test_count;
 // Reference model signals
 wire [(WIDTH*2)-1:0] exp_RES;
 wire exp_ERR,exp_OFLOW,exp_COUT,exp_G,exp_L,exp_E;

// ------- DUT Instantiation -----------------------------------------
/*alu #(.WIDTH(WIDTH),.CMD_WIDTH(4)) DUT (
    .CLK(CLK), .RST(RST), .CE(CE), .INP_VALID(INP_VALID),
    .MODE(MODE), .CMD(CMD), .OPA(OPA), .OPB(OPB), .CIN(CIN),
    .ERR(ERR), .RES(RES), .OFLOW(OFLOW), .COUT(COUT),
    .G(G), .L(L), .E(E)
);*/


// --- Test DUT Instantiation -----------------------------------

alu_test #(.DW(WIDTH),.C(4)) DUT(.clk(CLK),.rst(RST),.inp_valid(INP_VALID),.mode(MODE),.cmd(CMD),.ce(CE),.opA(OPA),.opB(OPB),.cin(CIN),.err(ERR),.res(RES),.oflow(OFLOW),.cout(COUT),.G(G),.L(L),.E(E));

//Golden reference
alu_ref #(.WIDTH(WIDTH),.CMD_WIDTH(4)) ref (.MODE(MODE),.OPA(OPA),.OPB(OPB),.CIN(CIN),.CMD(CMD),.INP_VALID(INP_VALID),.exp_RES(exp_RES),.exp_ERR(exp_ERR),.exp_OFLOW(exp_OFLOW),.exp_COUT(exp_COUT),.exp_G(exp_G),.exp_L(exp_L),.exp_E(exp_E));

initial begin
CLK = 0;
forever #5 CLK = ~CLK;
end

// ------ Standard Checker Task -----------------------------------
initial begin
RST = 1; CE = 1; CIN = 0;OPA = 0; OPB = 0; MODE = 0; CMD = 0;
pass_count=0;fail_count=0;test_count=0;
last_valid_res=0;
@(posedge CLK)RST=0;

// Test Arithmetic Operations
$display("\n=== Testing Arithmetic Operations (MODE=1) ===");
MODE = 1;
test_arithmetic();

// Test Logical Operations
$display("\n=== Testing Logical Operations (MODE=0) ===");
MODE = 0;
test_logical();

$display("\n=== Testing Hardware Interrupts ===");
test_async_reset();
test_ce_disable();

$display("-----------Invalid test cases-------");
test_invalid_cases();

$display("\n=== Testing Boundary Defenses ===");
test_out_of_bounds();

// Summary
$display("\n=== TEST SUMMARY ===");
$display("Total Tests: %0d", test_count);
$display("PASS: %0d", pass_count);
$display("FAIL: %0d", fail_count);

#100;
$finish;
end

task apply_test;
input [3:0] t_cmd;
input [WIDTH-1:0] t_opa, t_opb;
input t_cin;
input [1:0] t_valid;
input [8*30:0] test_name;

 begin
   @(negedge CLK);
   CMD = t_cmd;
   OPA = t_opa;
   OPB = t_opb;
   CIN = t_cin;
   INP_VALID = t_valid;

   // TIMING FIX: 3 Cycles for Multiplier, 2 Cycles for Pipelined Standard Math
   if(MODE==1'b1 && (t_cmd==4'd9 || t_cmd==4'd10)) begin
       repeat(3) @(posedge CLK);
   end
   else begin
       repeat(2) @(posedge CLK); // CHANGED FROM 1 TO 2
   end

#1;
   test_count=test_count+1;
   if (exp_ERR == 1'b1) begin
                if (MODE == 1'b0 && (t_cmd == 4'd12 || t_cmd == 4'd13) && t_valid == 2'b11) begin
                    if (RES !== exp_RES || ERR !== 1'b1) begin
                        $display("[FAIL] %s | CMD:%0d", test_name, t_cmd);
                        $display("       Expected: RES=%0d (Rotated Math) ERR=1", exp_RES);
                        $display("       Got     : RES=%0d ERR=%b", RES, ERR);
                        fail_count = fail_count + 1;
                    end else begin
                        $display("[PASS] %s", test_name);
                        pass_count = pass_count + 1;
                    end
                end
                else begin
                    if (RES !== last_valid_res || ERR !== 1'b1) begin
                        $display("[FAIL] %s | CMD:%0d", test_name, t_cmd);
                        $display("       Expected: RES=%0d (Held Value) ERR=1", last_valid_res);
                        $display("       Got     : RES=%0d ERR=%b", RES, ERR);
                        fail_count = fail_count + 1;
                    end else begin
                        $display("[PASS] %s", test_name);
                        pass_count = pass_count + 1;
                    end
                end
            end
   else begin
      if ( (RES !== exp_RES && !(MODE == 1'b1 && t_cmd == 4'd8)) ||
                     ERR !== 1'b0 || COUT !== exp_COUT ||
                     OFLOW !== exp_OFLOW || G !== exp_G || L !== exp_L || E !== exp_E) begin

                    $display("[FAIL] %s | CMD:%0d OPA:%0d OPB:%0d", test_name, t_cmd, t_opa, t_opb);
                    if (MODE == 1'b1 && t_cmd == 4'd8)
                        $display("       (Note: RES was ignored for COMP. Check flags!)");

                    $display("       Expected: RES=%0d ERR=0 COUT=%b OFLOW=%b G=%b L=%b E=%b",
                             exp_RES, exp_COUT, exp_OFLOW, exp_G, exp_L, exp_E);
                    $display("       Got     : RES=%0d ERR=%b COUT=%b OFLOW=%b G=%b L=%b E=%b",
                             RES, ERR, COUT, OFLOW, G, L, E);
                    fail_count = fail_count + 1;
       end
       else begin
           $display("[PASS] %s", test_name);
           pass_count = pass_count + 1;
       end
    end
    if (!(MODE == 1'b1 && t_cmd == 4'd8)) begin
        last_valid_res = RES;
    end
 end

endtask

task test_arithmetic;
    begin
        $display("-------- Run Arithmetic tests------------");
        $display("---------Direct Cases---------");
        apply_test(4'd0,8'd10,8'd20,0,2'b11,"ADD_no_carry");
        apply_test(4'd1,8'd10,8'd5,0,2'b11,"SUB_no_oflow");
        apply_test(4'd2,8'd10,8'd5,1,2'b11,"ADD_with_CIN");
        apply_test(4'd3,8'd10,8'd5,1,2'b11,"SUB_with_CIN");
        apply_test(4'd4,8'd10,8'd0,0,2'b01,"INC_A");
        apply_test(4'd5,8'd10,8'd0,0,2'b01,"DEC_A");
        apply_test(4'd6,8'd10,8'd0,0,2'b10,"INC_B");
        apply_test(4'd7,8'd10,8'd0,0,2'b10,"DEC_B");
        apply_test(4'd8,8'd10,8'd2,0,2'b11,"COMP_G");
        apply_test(4'd8,8'd10,8'd20,0,2'b11,"COMP_L");
        apply_test(4'd8,8'd10,8'd10,0,2'b11,"COMP_E");
        apply_test(4'd9,8'd3,8'd2,0,2'b11,"INC_MUL");
        apply_test(4'd9,8'd192,8'd200,0,2'b11,"INC_MUL");
        apply_test(4'd9,8'd251,8'd211,0,2'b11,"INC_MUL");
        apply_test(4'd10,8'd64,8'd211,0,2'b11,"SHL_MUL");
        apply_test(4'd10,8'd32,8'd255,0,2'b11,"SHL_MUL");
        apply_test(4'd10,8'd4,8'd3,0,2'b11,"SHL_MUL");
        apply_test(4'd11,8'd5,8'd4,0,2'b11,"SIG_ADD");
        apply_test(4'd11,8'd50,8'd50,0,2'b11,"SIG_ADD");
        apply_test(4'd11,8'd127,8'd2,0,2'b11,"SIG_ADD");
        apply_test(4'd11,-8'd50,-8'd50,0,2'b11,"SIG_ADD");
        apply_test(4'd11,-8'd50,8'd100,0,2'b11,"SIG_ADD");
        apply_test(4'd12,8'd100,8'd50,0,2'b11,"SIG_SUB");
        apply_test(4'd12,8'd50,8'd100,0,2'b11,"SIG_SUB");
        apply_test(4'd12,-8'd50,-8'd100,0,2'b11,"SIG_SUB");
        apply_test(4'd12,-8'd100,-8'd50,0,2'b11,"SIG_SUB");


        $display("---------Corner Cases---------");
        apply_test(4'd0,8'd10,8'd5,1,2'b11,"ADD_with_CIN");
        apply_test(4'd0,8'd255,8'd5,0,2'b11,"ADD_with_COUT");
        apply_test(4'd0,8'd50,8'd5,0,2'b00,"ADD_invalid");
        apply_test(4'd0,8'd50,8'd5,0,2'b01,"ADD_invalid");
        apply_test(4'd0,8'd50,8'd5,0,2'b10,"ADD_invalid");
        apply_test(4'd1,8'd5,8'd10,0,2'b11,"SUB_with_OFLOW");
        apply_test(4'd1,8'd5,8'd3,0,2'b01,"SUB_invalid");
        apply_test(4'd2,8'd255,8'd1,1,2'b11,"ADD_CIn_with_COUT");
        apply_test(4'd2,8'd25,8'd2,0,2'b00,"ADD_CIN_invalid");
        apply_test(4'd3,8'd0,8'd0,1,2'b11,"SUB_CIN_with_OFLOW");
        apply_test(4'd3,8'd2,8'd1,1,2'b00,"SUB_CIN_invalid");
        apply_test(4'd4,8'd255,8'd0,0,2'b01,"INC_A_COUT");
        apply_test(4'd4,8'd25,8'd0,0,2'b00,"INC_A_invalid");
        apply_test(4'd5,8'd0,8'd10,0,2'b01,"DEC_A_underflow");
        apply_test(4'd5,8'd10,8'd2,0,2'b00,"DEC_A_invalid");
        apply_test(4'd6,8'd0,8'd255,0,2'b10,"INC_B_COUT");
        apply_test(4'd6,8'd25,8'd0,0,2'b00,"INC_B_invalid");
        apply_test(4'd7,8'd10,8'd0,0,2'b10,"DEC_B_underflow");
        apply_test(4'd7,8'd10,8'd2,0,2'b00,"DEC_B_invalid");
        apply_test(4'd8,8'd1,8'd2,0,2'b00,"COMP_invalid");
        apply_test(4'd9,8'd3,8'd2,0,2'b00,"MUL_invalid");
        apply_test(4'd9,8'd255,8'd255,0,2'b11,"MUL_out_of_bounds");
        apply_test(4'd10,8'd4,8'd3,0,2'b00,"SHL_MUL_invalid");
        apply_test(4'd10,8'd128,8'd1,0,2'b11,"SHL_out_off_bounds");
        apply_test(4'd11,-8'd1,-8'd1,0,2'b11,"SIG_ADD_OFLOW");
        apply_test(4'd11,8'd127,8'd1,0,2'b11,"SIG_ADD_OFLOW");
        apply_test(4'd11,-8'd128,-8'd1,0,2'b11,"SIG_ADD_OFLOW");
        apply_test(4'd11,8'd127,8'd10,0,2'b00,"SIG_ADD_invalid");
        apply_test(4'd12,8'd127,-8'd1,0,2'b11,"SIG_SUB_OFLOW");
        apply_test(4'd12,8'd127,-8'd2,0,2'b11,"SIG_SUB_OFLOW");
        apply_test(4'd12,-8'd128,8'd1,0,2'b11,"SIG_SUB_OFLOW");
        apply_test(4'd12, 8'hCE, 8'h32, 0, 2'b11, "additional test");
        apply_test(4'd12, 8'h32, 8'hCE, 0, 2'b11, "additional test");
        apply_test(4'd3, 8'd25, 8'd25, 0, 2'b11, "additional tests");
        apply_test(4'd3, 8'd10, 8'd50, 0, 2'b11, "additional tests");


    end
endtask


task test_logical;
    begin
        $display("----------------Run Logical Cases----------------");
        $display("--------------Direct Cases-------------");
        apply_test(4'd0,8'd4,8'd0,0,2'b11,"AND");
        apply_test(4'd1,8'd4,8'd2,0,2'b11,"NAND");
        apply_test(4'd2,8'd8,8'd4,0,2'b11,"OR");
        apply_test(4'd3,8'd4,8'd2,0,2'b11,"NOR");
        apply_test(4'd4,8'd5,8'd3,0,2'b11,"XOR");
        apply_test(4'd5,8'd5,8'd3,0,2'b11,"XNOR");
        apply_test(4'd6,8'd10,8'd0,0,2'b01,"NOT_A");
        apply_test(4'd7,8'd10,8'd7,0,2'b10,"NOT_B");
        apply_test(4'd8,8'd4,8'd0,0,2'b01,"SHR1_A");
        apply_test(4'd9,8'd4,8'd0,0,2'b01,"SHL1_A");
        apply_test(4'd10,8'd0,8'd4,0,2'b10,"SHR1_B");
        apply_test(4'd11,8'd0,8'd4,0,2'b10,"SHL1_B");
        apply_test(4'd12,8'd7,8'd2,0,2'b11,"ROL_A_B");
        apply_test(4'd13,8'd7,8'd2,0,2'b11,"ROR_A_B");
        $display("------------Corner Cases-------------");
        apply_test(4'd0,8'd4,8'd2,0,2'b00,"AND_invalid");
        apply_test(4'd1,8'd4,8'd2,0,2'b00,"NAND_invalid");
        apply_test(4'd2,8'd16,8'd15,0,2'b00,"OR_invalid");
        apply_test(4'd3,8'd9,8'd6,0,2'b00,"NOR_invalid");
        apply_test(4'd4,8'd7,8'd3,0,2'b00,"XOR_invalid");
        apply_test(4'd5,8'd4,8'd2,0,2'b00,"XNOR_invalid");
        apply_test(4'd6,8'd4,8'd3,0,2'b00,"NOT_A_invalid");
        apply_test(4'd7,8'd4,8'd2,0,2'b00,"NOT_B_invalid");
        apply_test(4'd8,8'd1,8'd2,0,2'b01,"SHR1_A");
        apply_test(4'd9,8'd128,8'd10,0,2'b01,"SHL1_A");
        apply_test(4'd10,8'd4,8'd1,0,2'b10,"SHR1_B");
        apply_test(4'd11,8'd4,8'd128,0,2'b10,"SHL1_B");
        apply_test(4'd8,8'd4,8'd2,0,2'b00,"SHR1_A_invalid");
        apply_test(4'd9,8'd4,8'd2,0,2'b00,"SHL1_A_invalid");
        apply_test(4'd10,8'd4,8'd2,0,2'b00,"SHR1_B_invalid");
        apply_test(4'd11,8'd4,8'd2,0,2'b00,"SHL1_B_invalid");
        apply_test(4'd12,8'd15,8'd0,0,2'b11,"ROL_A_B_by_zero");
        apply_test(4'd12,8'd23,8'd17,0,2'b11,"ROL_A_B_4_ERR");
        apply_test(4'd12,8'd24,8'd34,0,2'b11,"ROL_A_B_5_ERR");
        apply_test(4'd12,8'd25,8'd68,0,2'b11,"ROL_A_B_6_ERR");
        apply_test(4'd12,8'd26,8'd132,0,2'b11,"ROL_A_B_7_ERR");
        apply_test(4'd12,8'd15,8'd8,0,2'b11,"ROL_A_B_3_X");
        apply_test(4'd12,8'd5,8'd2,0,2'b00,"ROL_A_B_invalid");
        apply_test(4'd13,8'd15,8'd0,0,2'b11,"ROR_A_B_by_zero");
        apply_test(4'd13,8'd23,8'd17,0,2'b11,"ROR_A_B_4_ERR");
        apply_test(4'd13,8'd24,8'd34,0,2'b11,"ROR_A_B_5_ERR");
        apply_test(4'd13,8'd25,8'd68,0,2'b11,"ROR_A_B_6_ERR");
        apply_test(4'd13,8'd26,8'd132,0,2'b11,"ROR_A_B_7_ERR");
        apply_test(4'd13,8'd15,8'd8,0,2'b11,"ROR_A_B_3_X");
        apply_test(4'd13,8'd5,8'd2,0,2'b00,"ROR_A_B_invalid");
    end
endtask


// ---- Clock Enable Check -------
    task test_ce_disable;
        begin
            $display("\n---CE Disable Check ---");

            @(negedge CLK);
            RST = 0; CE = 1; MODE = 1; CMD = 4'd0; OPA = 8'd10; OPB = 8'd10; INP_VALID = 2'b11;
            repeat(2) @(posedge CLK); // TIMING FIX: Wait 2 cycles for pipeline to resolve '20'
            #1;

            @(negedge CLK);
            CE = 0;                 //disable
            CMD = 4'd0; OPA = 8'd50; OPB = 8'd50; // Try to force 50+50

            repeat(2) @(posedge CLK); #1; // Wait the new pipeline duration

            test_count = test_count + 1;
            if (RES !== 16'd20) begin
                $display("[FAIL] ce_disable_add | Expected RES to hold 20, Got %0d", RES);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] ce_disable_add");
                pass_count = pass_count + 1;
            end

            // Case 2: CE Disable during pipelined MULT
            @(negedge CLK);
            CE = 0;                 // disable
            CMD = 4'd9; OPA = 8'd2; OPB = 8'd2; // Try to force a multiply

            repeat(3) @(posedge CLK); // Wait the normal 3-cycle pipeline duration
            #1;

            test_count = test_count + 1;
            if (RES !== 16'd20) begin
                $display("[FAIL] ce_disable_mult | Pipeline advanced while CE=0!");
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] ce_disable_mult");
                pass_count = pass_count + 1;
            end

            CE = 1; // Cleanup and re-enable chip for future tests
        end
    endtask

// --- Reset Check-------------------------------------
      task test_async_reset;
        begin
            $display("\n--- Rst check ---");

            @(negedge CLK);
            RST = 0; CE = 1; MODE = 1; CMD = 4'd0; OPA = 8'd10; OPB = 8'd20; INP_VALID = 2'b11;

            repeat(2) @(posedge CLK); // TIMING FIX: Let the pipeline finish to prove output is cleared
            #2;

            RST = 1;        // rst
            #1;

            test_count = test_count + 1;
            if (RES !== 0 || ERR !== 0 || COUT !== 0 || OFLOW !== 0) begin
                $display("[FAIL] async_reset_add | Outputs did not instantly clear!");
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] async_reset_add");
                pass_count = pass_count + 1;
            end
            RST = 0; // Cleanup for next test

            // 2. Reset during pipelined MULT (CMD 9)
            @(negedge CLK);
            MODE = 1; CMD = 4'd9; OPA = 8'd5; OPB = 8'd5; INP_VALID = 2'b11;

            @(posedge CLK); // Cycle 1 (Sampling)
            @(posedge CLK); // Cycle 2 (Computing)
            #2;             // Wait mid-pipeline

            RST = 1;        // rst
            #1;

            test_count = test_count + 1;
            if (RES !== 0 || ERR !== 0) begin
                $display("[FAIL] async_reset_mult | Pipeline did not instantly clear!");
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] async_reset_mult");
                pass_count = pass_count + 1;
            end
            RST = 0; // Cleanup
        end
    endtask


   task test_invalid_cases;
        integer m, c;
        begin
            for (m = 0; m <= 1; m = m + 1) begin
                MODE = m;
                for (c = 0; c <= 15; c = c + 1) begin

                    apply_test(c, 8'hAA, 8'h55, 0, 2'b01, "cov_inv_01");
                    apply_test(c, 8'hAA, 8'h55, 0, 2'b10, "cov_inv_10");
                    apply_test(c, 8'hAA, 8'h55, 0, 2'b00, "cov_inv_00");

                end
            end
            apply_test(4'd0, 8'd0, 8'd0, 0, 2'b11, "sync_tracker");
        end
    endtask

    task test_out_of_bounds;
        begin
            $display("\n--- Running Out of Bounds Check ---");

            // 1. Arithmetic Mode: Max valid CMD is 12. Let's test CMD 15.
            MODE = 1;
            apply_test(4'd0,8'd0,8'd0,0,2'b11,"clear res");

            apply_test(4'd15, 8'hFF, 8'hFF, 0, 2'b11, "arith_out_of_bounds_15");

            // 2. Logical Mode: Max valid CMD is 13. Let's test CMD 15.
            MODE = 0;
            apply_test(4'd15, 8'hAA, 8'h55, 0, 2'b11, "logic_out_of_bounds_15");
        end
    endtask

endmodule

module alu_ref#(parameter WIDTH = 8,parameter CMD_WIDTH = 4)(MODE,OPA,OPB,CIN,CMD,INP_VALID,exp_RES,exp_ERR,exp_OFLOW,exp_COUT,exp_G,exp_L,exp_E);
input wire CIN,MODE;
input wire [1:0] INP_VALID;
input wire [WIDTH-1:0] OPA,OPB;
input wire [CMD_WIDTH-1:0] CMD;
output reg [WIDTH*2-1:0]exp_RES;
output reg exp_ERR;
output reg exp_OFLOW;
output reg exp_COUT;
output reg exp_G,exp_L,exp_E;


always@(*) begin
        exp_RES   = {(WIDTH*2){1'b0}};
        exp_ERR   = 1'b0;
        exp_OFLOW = 1'b0;
        exp_COUT  = 1'b0;
        exp_G     = 1'b0;
        exp_L     = 1'b0;
        exp_E     = 1'b0;
        if (MODE == 1'b1) begin
            // --- ARITHMETIC MODE ---
            if (CMD == 4'd4 || CMD == 4'd5) begin
                // INC_A, DEC_A (Needs OPA)
                if (INP_VALID != 2'b01 && INP_VALID != 2'b11) exp_ERR = 1'b1;
            end
            else if (CMD == 4'd6 || CMD == 4'd7) begin
                // INC_B, DEC_B (Needs OPB)
                if (INP_VALID != 2'b10 && INP_VALID != 2'b11) exp_ERR = 1'b1;
            end
            else begin
                // ADD, SUB, MULT, etc. (Needs Both)
                if (INP_VALID != 2'b11) exp_ERR = 1'b1;
            end
        end
        else begin
            // --- LOGICAL MODE ---
            if (CMD == 4'd6 || CMD == 4'd8 || CMD == 4'd9) begin
                // NOT_A, SHR_A, SHL_A (Needs OPA)
                if (INP_VALID != 2'b01 && INP_VALID != 2'b11) exp_ERR = 1'b1;
            end
            else if (CMD == 4'd7 || CMD == 4'd10 || CMD == 4'd11) begin
                // NOT_B, SHR_B, SHL_B (Needs OPB)
                if (INP_VALID != 2'b10 && INP_VALID != 2'b11) exp_ERR = 1'b1;
            end
            else begin
                // AND, OR, ROL, etc. (Needs Both)
                if (INP_VALID != 2'b11) exp_ERR = 1'b1;
            end
        end
        if(exp_ERR==1'b0) begin
               if(MODE==1'b1) begin
                     case(CMD)
                         4'd0: begin // ADD
                         exp_RES = OPA + OPB;
                         if (exp_RES > {WIDTH{1'b1}}) exp_COUT = 1'b1;
                     end
                     4'd1: begin // SUB
                         if (OPA < OPB) exp_OFLOW = 1'b1; // Borrow flag
                         exp_RES = OPA - OPB;
                     end
                     4'd2: begin // ADD_CIN
                         exp_RES = OPA + OPB + CIN;
                         if (exp_RES > {WIDTH{1'b1}}) exp_COUT = 1'b1;
                     end
                     4'd3: begin // SUB_CIN
                         if (OPA < (OPB + CIN)) exp_OFLOW = 1'b1;
                         exp_RES = OPA - OPB - CIN;
                     end
                     4'd4: begin // INC_A
                         exp_RES = OPA + 1;
                         if (exp_RES > {WIDTH{1'b1}}) exp_COUT = 1'b1;
                     end
                     4'd5: begin // DEC_A
                         if (OPA == 0) exp_COUT = 1'b0; // Used as borrow out
                         exp_RES = OPA - 1;
                     end
                     4'd6: begin // INC_B
                         exp_RES = OPB + 1;
                         if (exp_RES > {WIDTH{1'b1}}) exp_COUT = 1'b1;
                     end
                     4'd7: begin // DEC_B
                         if (OPB == 0) exp_COUT = 1'b0;
                         exp_RES = OPB - 1;
                     end
                     4'd8: begin // COMP
                         if (OPA > OPB) exp_G = 1'b1;
                         else if (OPA < OPB) exp_L = 1'b1;
                         else exp_E = 1'b1;
                     end
                     4'd9: begin // MULTIPLY (Instant calculation)
                         exp_RES = (OPA + 1) * (OPB + 1);
                     end
                     4'd10: begin // MULTIPLY & SHIFT
                         exp_RES = ((OPA << 1) & 16'h00FF )* OPB;
                     end
                     4'd11: begin // SIGNED ADD
                         exp_RES =$signed(OPA) + $signed(OPB);
                         exp_G=($signed(OPA)>$signed(OPB));
                         exp_E=($signed(OPA)==$signed(OPB));
                         exp_L=($signed(OPA)<$signed(OPB));
                         // Overflow: If both inputs share a sign, but the result sign flips
                         if ((OPA[WIDTH-1] == OPB[WIDTH-1]) && (exp_RES[WIDTH-1] != OPA[WIDTH-1]))
                             exp_OFLOW = 1'b1;
                     end
                     4'd12: begin // SIGNED SUB
                         exp_RES = $signed(OPA) - $signed(OPB);
                         exp_G=($signed(OPA)>$signed(OPB));
                         exp_E=($signed(OPA)==$signed(OPB));
                         exp_L=($signed(OPA)<$signed(OPB));
                         // Overflow: If signs differ, and result sign matches the subtrahend (OPB)
                         if ((OPA[WIDTH-1] != OPB[WIDTH-1]) && (exp_RES[WIDTH-1] == OPB[WIDTH-1]))
                             exp_OFLOW = 1'b1;
                     end
                     default: exp_ERR = 1'b1; // Fallback for invalid arithmetic commands
                 endcase

               end
               else begin // --- LOGICAL MODE ---
                 case (CMD)
                     4'd0:  exp_RES ={{WIDTH{1'b0}},(OPA & OPB)};
                     4'd1:  exp_RES ={{WIDTH{1'b0}},~(OPA & OPB)};
                     4'd2:  exp_RES = {{WIDTH{1'b0}},(OPA | OPB)};
                     4'd3:  exp_RES = {{WIDTH{1'b0}},~(OPA | OPB)};
                     4'd4:  exp_RES ={{WIDTH{1'b0}},(OPA ^ OPB)};
                     4'd5:  exp_RES = {{WIDTH{1'b0}},~(OPA ^ OPB)};
                     4'd6:  exp_RES = {{WIDTH{1'b0}},~OPA};
                     4'd7:  exp_RES = {{WIDTH{1'b0}},~OPB};
                     4'd8:  exp_RES = {{WIDTH{1'b0}},OPA >> 1};
                     4'd9:  exp_RES = {{WIDTH{1'b0}},OPA << 1};
                     4'd10: exp_RES = {{WIDTH{1'b0}},OPB >> 1};
                     4'd11: exp_RES = {{WIDTH{1'b0}},OPB << 1};
                     4'd12: begin // ROL (Rotate Left)
                         if (|OPB[WIDTH-1:4]) begin
                             exp_ERR = 1'b1; // Error if shift amount is >= 8

                             exp_RES ={{WIDTH{1'b0}},(OPA << OPB[2:0]) | (OPA >> (WIDTH - OPB[2:0]))};
                         end
                         else begin
                             exp_RES ={{WIDTH{1'b0}},(OPA << OPB[2:0]) | (OPA >> (WIDTH - OPB[2:0]))};
                         end

                     end
                     4'd13: begin // ROR (Rotate Right)
                         if (|OPB[WIDTH-1:4]) begin
                             exp_ERR = 1'b1;

                             exp_RES ={{WIDTH{1'b0}}, (OPA >> OPB[2:0]) | (OPA << (WIDTH - OPB[2:0]))};
                         end else begin
                             exp_RES ={{WIDTH{1'b0}},(OPA >> OPB[2:0]) | (OPA << (WIDTH - OPB[2:0]))};
                         end

                     end
                     default: exp_ERR = 1'b1; // if command given is invalid
                 endcase
               end
            end
end
endmodule
