module alu#(parameter WIDTH=8,parameter CMD_WIDTH = 4)(CLK,RST,INP_VALID,MODE,CMD,CE,OPA,OPB,CIN,ERR,RES,OFLOW,COUT,G,L,E);
input wire CLK,RST,CIN,CE,MODE;
input wire [1:0] INP_VALID;
input wire [WIDTH-1:0] OPA,OPB;
input wire [CMD_WIDTH-1:0] CMD;
output reg [WIDTH*2-1:0]RES;
output reg ERR;
output reg OFLOW;
output reg COUT;
output reg G,L,E;

reg [WIDTH-1:0] temp_a, temp_b;
reg [(WIDTH*2)-1:0] mul;
reg [1:0] mul_state;
reg mul_err;

// Stage-1 pipeline registers
reg [WIDTH-1:0]     s_opa, s_opb;
reg [CMD_WIDTH-1:0] s_cmd;
reg                 s_mode, s_cin;
reg [1:0]           s_inp_valid;

always@(posedge CLK or posedge RST) begin
    if(RST) begin
        ERR        <= 1'b0;
        OFLOW      <= 1'b0;
        COUT       <= 1'b0;
        G          <= 1'b0;
        L          <= 1'b0;
        E          <= 1'b0;
        mul_state  <= 2'b00;
        mul_err    <= 1'b0;
        RES        <= {WIDTH*2{1'b0}};
        s_opa      <= {WIDTH{1'b0}};
        s_opb      <= {WIDTH{1'b0}};
        s_cmd      <= {CMD_WIDTH{1'b0}};
        s_mode     <= 1'b0;
        s_cin      <= 1'b0;
        s_inp_valid<= 2'b00;
    end
    else if(CE) begin

        // =====================================================
        // CYCLE 1: Sample all inputs into pipeline registers
        // =====================================================
        s_opa       <= OPA;
        s_opb       <= OPB;
        s_cmd       <= CMD;
        s_mode      <= MODE;
        s_cin       <= CIN;
        s_inp_valid <= INP_VALID;

        // =====================================================
        // CYCLE 1: Multiplication
        // =====================================================
        if (MODE == 1'b1 && INP_VALID == 2'b11 && mul_state == 2'd0) begin
            if (CMD == 4'b1001) begin
                temp_a <= OPA + 1;
                temp_b <= OPB + 1;
                mul_state <= 2'd1;
            end
            else if (CMD == 4'b1010) begin
                temp_a <= OPA << 1;
                temp_b <= OPB;
                mul_state <= 2'd1;
            end
        end

        // =====================================================
        // CYCLE 2 / CYCLE 3: Multiplication Pipeline
        // =====================================================
        if (mul_state == 2'd1) begin
            mul <= temp_a * temp_b; // Cycle 2: Execute multiply
            mul_state <= 2'd2;
        end
        else if (mul_state == 2'd2) begin
            mul_state <= 2'd0;      // Cycle 3: Free the pipeline
        end

        // =====================================================
        // CYCLE 2: Compute using SAMPLED inputs (s_*)
        // =====================================================
        if(s_mode) begin   // Arithmetic operations
            ERR   <= 1'b0;
            OFLOW <= 1'b0;
            COUT  <= 1'b0;
            G     <= 1'b0;
            L     <= 1'b0;
            E     <= 1'b0;
            RES   <= RES;
            if (s_cmd != 4'b1001 && s_cmd != 4'b1010) begin
                mul_err <= 1'b0;
            end
            case(s_cmd)
                4'b0000:begin            //ADD
                    if(s_inp_valid==2'b11) begin
                        RES  <= s_opa + s_opb;
                        COUT <= ({1'b0, s_opa} + {1'b0, s_opb}) >> WIDTH;
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0001:begin          //SUB
                    if(s_inp_valid==2'b11) begin
                        RES   <= s_opa - s_opb;
                        OFLOW <= (s_opa < s_opb) ? 1 : 0;
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0010:begin           //ADD_CIN
                    if(s_inp_valid==2'b11) begin
                        RES  <= s_opa + s_opb + s_cin;
                        COUT <= ({1'b0, s_opa} + {1'b0, s_opb} + s_cin) >> WIDTH;
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0011:begin         //SUB_CIN
                    if(s_inp_valid==2'b11) begin
                        OFLOW <= (s_opa < s_opb) | ((s_opa == s_opb) & s_cin);
                        RES   <= s_opa - s_opb - s_cin;
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0100:begin         //INC_A
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b01) begin
                        RES  <= s_opa + 1;
                        COUT <= ({1'b0, s_opa} + 1) >> WIDTH;
                    end
                    else if(s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0101:begin           //DEC_A
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b01) begin
                        RES <= s_opa - 1;
                    end
                    else if(s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0110:begin            //INC_B
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b10) begin
                        RES  <= s_opb + 1;
                        COUT <= ({1'b0, s_opb} + 1) >> WIDTH;
                    end
                    else if(s_inp_valid==2'b01) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0111:begin                  //DEC_B
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b10) begin
                        RES <= s_opb - 1;
                    end
                    else if(s_inp_valid==2'b01) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1000:begin              //COMP
                    if(s_inp_valid==2'b11) begin
                        ERR   <= 1'b0; OFLOW <= 1'b0; COUT  <= 1'b0; G <= 1'b0; L <= 1'b0; E <= 1'b0;
                        RES   <= {(WIDTH*2){1'b0}};
                        if(s_opa == s_opb) begin
                            G <= 1'b0; E <= 1'b1; L <= 1'b0;
                        end else if(s_opa > s_opb) begin
                            G <= 1'b1; E <= 1'b0; L <= 1'b0;
                        end else begin
                            G <= 1'b0; E <= 1'b0; L <= 1'b1;
                        end
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        ERR   <= 1'b1; OFLOW <= 1'b0; COUT  <= 1'b0; G <= 1'b0; L <= 1'b0; E <= 1'b0;
                        RES   <= {WIDTH*2{1'b0}};
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                // ----------------------------------------------------------
                // CMD 9 & 10:
                // ----------------------------------------------------------
                4'b1001:begin      // Increment and Multiply
                    if(s_inp_valid==2'b11) begin
                        mul_err <= 1'b0;
                        RES <= {(WIDTH*2){1'b0}};
                        ERR <= 1'b0;
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES     <= RES;
                        mul_err <= 1'b1;
                        ERR     <= 1'b1;
                    end else begin
                        mul_err <= 1'b1; ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1010:begin      // Left Shift A by 1 and Multiply
                    if(s_inp_valid==2'b11) begin
                        mul_err <= 1'b0;
                        RES <= {(WIDTH*2){1'b0}};
                        ERR <= 1'b0;
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES     <= RES;
                        mul_err <= 1'b1;
                        ERR     <= 1'b1;
                    end else begin
                        mul_err <= 1'b1; ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1011:begin   // Signed addition
                    if(s_inp_valid==2'b11) begin
                        RES   <= $signed(s_opa) + $signed(s_opb);
                        OFLOW <= (s_opa[WIDTH-1] == s_opb[WIDTH-1]) &&
                                 ((((s_opa + s_opb) >> (WIDTH-1)) & 1'b1) != s_opa[WIDTH-1]);
                        G <= ($signed(s_opa) > $signed(s_opb)) ? 1 : 0;
                        L <= ($signed(s_opa) < $signed(s_opb)) ? 1 : 0;
                        E <= ($signed(s_opa) == $signed(s_opb));
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1100:begin   // Signed subtraction
                    if(s_inp_valid==2'b11) begin
                        RES   <= $signed(s_opa) - $signed(s_opb);
                        OFLOW <= (s_opa[WIDTH-1] != s_opb[WIDTH-1]) &&
                                 ((((s_opa - s_opb) >> (WIDTH-1)) & 1'b1) != s_opa[WIDTH-1]);
                        G <= ($signed(s_opa) > $signed(s_opb)) ? 1 : 0;
                        L <= ($signed(s_opa) < $signed(s_opb)) ? 1 : 0;
                        E <= ($signed(s_opa) == $signed(s_opb));
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR   <= 1'b1; OFLOW <= OFLOW; COUT  <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                default:begin
                    RES   <= RES; ERR   <= 1'b1; OFLOW <= 1'b0; COUT  <= 1'b0; G <= 1'b0; L <= 1'b0; E <= 1'b0;
                end
            endcase
        end
        else begin   // Logical operations (MODE=0)
            ERR   <= 1'b0; OFLOW <= 1'b0; COUT  <= 1'b0; G <= 1'b0; L <= 1'b0; E <= 1'b0; RES <= RES;
            case(s_cmd)
                4'b0000:begin          //AND
                    if(s_inp_valid==2'b11)
                        RES <= s_opa & s_opb;
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0001:begin           //NAND
                    if(s_inp_valid==2'b11)
                        RES <= {{WIDTH{1'b0}}, ~(s_opa & s_opb)};
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0010:begin               //OR
                    if(s_inp_valid==2'b11)
                        RES <= {{WIDTH{1'b0}}, s_opa | s_opb};
                    else if(s_inp_valid==2'b10 || s_inp_valid==2'b01) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0011:begin                  //NOR
                    if(s_inp_valid==2'b11)
                        RES <= {{WIDTH{1'b0}}, ~(s_opa | s_opb)};
                    else if(s_inp_valid==2'b10 || s_inp_valid==2'b01) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0100:begin                 //XOR
                    if(s_inp_valid==2'b11)
                        RES <= {{WIDTH{1'b0}}, s_opa ^ s_opb};
                    else if(s_inp_valid==2'b10 || s_inp_valid==2'b01) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0101:begin                   //XNOR
                    if(s_inp_valid==2'b11)
                        RES <= {{WIDTH{1'b0}}, ~(s_opa ^ s_opb)};
                    else if(s_inp_valid==2'b10 || s_inp_valid==2'b01) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0110:begin                //NOT_A
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b01)
                        RES <= {{WIDTH{1'b0}}, ~s_opa};
                    else if(s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b0111:begin                   //NOT_B
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b10)
                        RES <= {{WIDTH{1'b0}}, ~s_opb};
                    else if(s_inp_valid==2'b01) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1000:begin                      //SHR1_A
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b01)
                        RES <= {{WIDTH{1'b0}}, (s_opa >> 1)};
                    else if(s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1001:begin                       //SHL1_A
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b01)
                        RES <= {{WIDTH{1'b0}}, (s_opa << 1)};
                    else if(s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1010:begin                        //SHR1_B
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b10)
                        RES <= {{WIDTH{1'b0}}, (s_opb >> 1)};
                    else if(s_inp_valid==2'b01) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1011:begin                          //SHL1_B
                    if(s_inp_valid==2'b11 || s_inp_valid==2'b10)
                        RES <= {{WIDTH{1'b0}}, (s_opb << 1)};
                    else if(s_inp_valid==2'b01) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1100:begin                           //ROL_A_B
                    if(s_inp_valid==2'b11) begin
                        if(|s_opb[WIDTH-1:4]) begin
                            ERR <= 1'b1;
                        end else begin
                            ERR <= 1'b0;
                        end
                        RES <= {{WIDTH{1'b0}}, (s_opa << s_opb[2:0]) | (s_opa >> (WIDTH - s_opb[2:0]))};
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                4'b1101:begin                           //ROR_A_B
                    if(s_inp_valid==2'b11) begin
                        if(|s_opb[WIDTH-1:4]) begin
                            ERR <= 1'b1;
                        end else begin
                            ERR <= 1'b0;
                        end
                        RES <= {{WIDTH{1'b0}}, (s_opa >> s_opb[2:0]) | (s_opa << (WIDTH - s_opb[2:0]))};
                    end
                    else if(s_inp_valid==2'b01 || s_inp_valid==2'b10) begin
                        RES <= RES; ERR <= 1'b1;
                    end else begin
                        ERR <= 1'b1; OFLOW <= OFLOW; COUT <= COUT; G <= G; L <= L; E <= E; RES <= RES;
                    end
                end
                default:begin
                    ERR   <= 1'b1; COUT  <= COUT; OFLOW <= OFLOW; G <= G; L <= L; E <= E; RES   <= RES;
                end
            endcase
        end

        if (mul_state == 2'd2) begin
            RES   <= mul;
            ERR   <= 1'b0;
            OFLOW <= 1'b0;
            COUT  <= 1'b0;
            G     <= 1'b0;
            L     <= 1'b0;
            E     <= 1'b0;
        end

    end
    else begin   // CE=0: hold all outputs
        ERR   <= ERR;
        COUT  <= COUT;
        OFLOW <= OFLOW;
        G     <= G;
        L     <= L;
        E     <= E;
        RES   <= RES;
    end
end
endmodule
