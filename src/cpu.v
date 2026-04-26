`timescale 1ns / 1ps

module cpu (
    input  wire        clk,
    input  wire        rst,
    // Instruction Memory Interface
    output wire [63:0] imem_addr,
    input  wire [31:0] imem_data,
    // Data Memory Interface
    output wire [63:0] dmem_addr,
    output wire [63:0] dmem_wdata,
    input  wire [63:0] dmem_rdata,
    output wire        dmem_we,
    output wire        dmem_re,
    // Power Management
    output reg         sleep_mode
);

    // PC Register
    reg [63:0] pc;
    wire [63:0] next_pc;

    // Instruction Decoder
    wire [31:0] inst   = imem_data;
    wire [5:0]  opcode = inst[5:0];
    wire [4:0]  rd     = inst[10:6];
    wire [4:0]  rs1    = inst[15:11];
    wire [4:0]  rs2    = inst[20:16];
    wire [10:0] funct  = inst[31:21];
    wire [15:0] imm16  = inst[31:16];
    wire [20:0] imm21  = inst[31:11];

    // Sign Extensions
    wire [63:0] imm16_sext = {{48{imm16[15]}}, imm16};
    wire [63:0] imm21_sext = {{43{imm21[20]}}, imm21};

    // Which Immediate depends on format. For simplicity we will assume I-type unless it's JAL.
    // For branching BEQ/BNE imm is offset in WORDS, so << 2.
    wire [63:0] branch_offset = imm16_sext << 2;
    wire [63:0] jump_offset   = imm21_sext << 2;

    // Determine if Rs2 or Immediate is used
    // R-Type uses funct. We can detect I-Type vs R-Type heuristically or let ALU take immediate.
    // Opcode bit 5=0, bit 4=0 usually ARITH. Let's make an explicit signal.
    // Actually, in our ISA we don't have separate opcodes for ADD vs ADDI, it says ADD(R/I).
    // Let's assume if it is R-type the user puts 0 in Imm and it's resolved? Wait, the ISA says R/I. Let's use `inst[21]` as a flag?
    // Let's simplify: Opcode ADD, if funct==0 it's R-type? Actually we can't tell without a bit.
    // Let's refine ISA: Imm is used if Rs2 is not, but how to tell? Let's assume ISA implies if Opcode uses Imm...
    // Wait, the easiest way is to say "if `inst[31]` is 1, it's I-Type" or just differentiate the opcodes.
    // Let's just say ADD uses Imm16, but if Rs2 != 0 in assembler, it generates a different opcode?
    // Let's re-interpret: We have 64 opcodes. Let's say:
    // 0x01: ADDI, 0x02: ADD ... oh, ISA has 01=ADD(R/I). I will look at the 16th bit (inst[16]). If 1 it's Immediate? 
    // Let's keep it simple: we pass `imm16_sext` to ALU in_b if it's not a purely R-type instruction.
    // Let's just create ADDI (0x12), ANDI (0x13), etc., if we need to. Since I only have 1 hour, I will
    // assume `alu_in_b_sel` flag based on some rules. Wait, to be ultra lightweight, we will check `funct[10]`. If 1, Immediate?
    // Let's use the standard RISC-V pattern: use a separate opcode for Immediate variants if needed. But I wrote ADD (R/I). 
    // Okay, I will say `alu_in_b = use_imm ? imm16_sext : rf_rd2;`.

    // For now, let's treat ADD(0x01) as ADD R-type and 0x21 as ADDI.
    // Wait, let's just make `use_imm` explicitly based on opcode logic.
    // 0x00=NOP
    // 0x01=ADD, 0x02=SUB, 0x03=AND, 0x04=OR, 0x05=XOR, 0x06=SHL, 0x07=SHR
    // 0x08=LD, 0x09=ST
    // 0x0A=BEQ, 0x0B=BNE
    // 0x0C=JAL, 0x0D=JALR, 0x0E=CSRR, 0x0F=CSRW
    // 0x10=SYSCALL, 0x11=RET, 0x3F=SLEEP
    
    // So ADD is just R-Type. I need to make ADDI etc available, I'll map them to upper opcodes here internally and in Assembler.
    // ADDI=0x21, ANDI=0x23, ORI=0x24, XORI=0x25, SHLI=0x26, SHRI=0x27.
    wire use_imm = (opcode >= 6'h21 && opcode <= 6'h27) || (opcode == 6'h08) || (opcode == 6'h09);

    // Register File Interface
    wire [63:0] rf_wd;
    reg         rf_we;
    wire [63:0] rf_rd1;
    wire [63:0] rf_rd2;
    wire [4:0]  rs2_sel = (opcode == 6'h0A || opcode == 6'h0B || opcode == 6'h09) ? rd : rs2;

    regfile rf (
        .clk(clk),
        .rst(rst),
        .rs1(rs1),
        .rs2(rs2_sel),
        .rd(rd),
        .wd(rf_wd),
        .we(rf_we),
        .rd1(rf_rd1),
        .rd2(rf_rd2),
        .r1_out(),
        .r2_out()
    );

    // CSR Interface
    reg [63:0] csr_wdata;
    reg        csr_we;
    wire [63:0] csr_rdata;
    
    reg        trap_req;
    reg [63:0] trap_cause;
    wire [63:0] epc_out;
    wire [63:0] mmu_ptb_out;
    wire        priv_mode;
    reg        eret_req;

    csr csr_inst (
        .clk(clk),
        .rst(rst),
        .csr_addr(imm16),
        .csr_wdata(csr_wdata),
        .csr_we(csr_we),
        .csr_rdata(csr_rdata),
        .trap_req(trap_req),
        .trap_pc(pc),
        .trap_cause(trap_cause),
        .trap_tval(64'd0),
        .eret_req(eret_req),
        .priv_mode(priv_mode),
        .epc_out(epc_out),
        .mmu_ptb_out(mmu_ptb_out)
    );

    // ALU Interface
    reg  [2:0]  alu_ctrl;
    wire [63:0] alu_result;
    wire        alu_zero;
    wire [63:0] alu_in_b = use_imm ? imm16_sext : rf_rd2;

    alu alu_inst (
        .a(rf_rd1),
        .b(alu_in_b),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero_flag(alu_zero)
    );

    // MMU for Data Memory
    wire [63:0] dmem_vaddr = rf_rd1 + imm16_sext;
    wire data_page_fault;
    
    mmu dmem_mmu (
        .virtual_addr(dmem_vaddr),
        .mmu_ptb(mmu_ptb_out),
        .mem_req(opcode == 6'h08 || opcode == 6'h09),
        .priv_mode(priv_mode),
        .physical_addr(dmem_addr),
        .page_fault(data_page_fault)
    );

    // MMU for Instruction Memory
    wire inst_page_fault;
    mmu imem_mmu (
        .virtual_addr(pc),
        .mmu_ptb(mmu_ptb_out),
        .mem_req(1'b1),
        .priv_mode(priv_mode),
        .physical_addr(imem_addr),
        .page_fault(inst_page_fault)
    );

    reg dmem_we_reg;
    reg dmem_re_reg;
    assign dmem_we = dmem_we_reg && !data_page_fault;
    assign dmem_re = dmem_re_reg && !data_page_fault;
    assign dmem_wdata = rf_rd2;

    // Control Signals
    reg [63:0] pc_calc;
    assign next_pc = pc_calc;
    
    reg [63:0] rf_wd_mux;
    assign rf_wd = rf_wd_mux;

    // Decoding & Control
    always @(*) begin
        rf_we       = 1'b0;
        rf_wd_mux   = 64'd0;
        alu_ctrl    = 3'b000;
        dmem_we_reg = 1'b0;
        dmem_re_reg = 1'b0;
        sleep_mode  = 1'b0;
        trap_req    = 1'b0;
        trap_cause  = 64'd0;
        eret_req    = 1'b0;
        csr_we      = 1'b0;
        csr_wdata   = 64'd0;
        pc_calc     = pc + 4;

        if (inst_page_fault) begin
            trap_req   = 1'b1;
            trap_cause = 64'd2; // Page Fault
            pc_calc    = 64'h0000_0000_0000_0000; // Trap vector
        end else if (data_page_fault) begin
            trap_req   = 1'b1;
            trap_cause = 64'd2; // Page Fault
            pc_calc    = 64'h0000_0000_0000_0000;
        end else begin
            case (opcode)
                6'h00: ; // NOP
                6'h01, 6'h21: begin // ADD / ADDI
                    rf_we     = 1'b1;
                    alu_ctrl  = 3'b000; // ADD
                    rf_wd_mux = alu_result;
                end
                6'h02: begin // SUB
                    rf_we     = 1'b1;
                    alu_ctrl  = 3'b001; // SUB
                    rf_wd_mux = alu_result;
                end
                6'h03, 6'h23: begin // AND / ANDI
                    rf_we     = 1'b1;
                    alu_ctrl  = 3'b010; // AND
                    rf_wd_mux = alu_result;
                end
                6'h04, 6'h24: begin // OR / ORI
                    rf_we     = 1'b1;
                    alu_ctrl  = 3'b011; // OR
                    rf_wd_mux = alu_result;
                end
                6'h05, 6'h25: begin // XOR / XORI
                    rf_we     = 1'b1;
                    alu_ctrl  = 3'b100; // XOR
                    rf_wd_mux = alu_result;
                end
                6'h06, 6'h26: begin // SHL / SHLI
                    rf_we     = 1'b1;
                    alu_ctrl  = 3'b101; // SHL
                    rf_wd_mux = alu_result;
                end
                6'h07, 6'h27: begin // SHR / SHRI
                    rf_we     = 1'b1;
                    alu_ctrl  = 3'b110; // SHR
                    rf_wd_mux = alu_result;
                end
                
                6'h08: begin // LD
                    rf_we       = 1'b1;
                    dmem_re_reg = 1'b1;
                    rf_wd_mux   = dmem_rdata;
                end
                
                6'h09: begin // ST
                    dmem_we_reg = 1'b1;
                end

                6'h0A: begin // BEQ
                    if (rf_rd1 == rf_rd2) pc_calc = pc + 4 + branch_offset;
                end
                
                6'h0B: begin // BNE
                    if (rf_rd1 != rf_rd2) pc_calc = pc + 4 + branch_offset;
                end

                6'h0C: begin // JAL
                    rf_we     = 1'b1;
                    rf_wd_mux = pc + 4;
                    pc_calc   = pc + 4 + jump_offset;
                end

                6'h0D: begin // JALR
                    rf_we     = 1'b1;
                    rf_wd_mux = pc + 4;
                    pc_calc   = rf_rd1 + imm16_sext;
                end

                6'h0E: begin // CSRR
                    rf_we     = 1'b1;
                    rf_wd_mux = csr_rdata;
                end

                6'h0F: begin // CSRW
                    csr_we    = 1'b1;
                    csr_wdata = rf_rd1;
                end

                6'h10: begin // SYSCALL
                    trap_req   = 1'b1;
                    trap_cause = 64'd1; // Syscall Cause
                    pc_calc    = 64'h0000_0000_0000_0000;
                end

                6'h11: begin // RET
                    eret_req   = 1'b1;
                    pc_calc    = epc_out; // Restore PC
                end

                6'h3F: begin // SLEEP
                    sleep_mode = 1'b1;
                    pc_calc    = pc; // Halt
                end

                default: ; // Unimplemented or NOP
            endcase
        end
    end

    // Sequential PC update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 64'd0;
        end else begin
            pc <= next_pc;
        end
    end

endmodule
