`timescale 1ns / 1ps

module csr (
    input  wire        clk,
    input  wire        rst,
    
    // Software CSR Access
    input  wire [15:0] csr_addr,
    input  wire [63:0] csr_wdata,
    input  wire        csr_we,
    output reg  [63:0] csr_rdata,

    // Hardware Trap Interface
    input  wire        trap_req,
    input  wire [63:0] trap_pc,
    input  wire [63:0] trap_cause,
    input  wire [63:0] trap_tval,
    input  wire        eret_req, // Return from exception
    
    // Timer & Interrupts Interface
    input  wire        timer_interrupt_in,
    input  wire [63:0] mtime_in,
    output wire [63:0] timecmp_out,
    output wire        interrupt_req_out,
    
    // State Outputs
    output reg         priv_mode, // 0: User, 1: Machine
    output wire [63:0] epc_out,
    output wire [63:0] mmu_ptb_out
);

    // CSR Addresses
    localparam CSR_STATUS  = 16'h0000;
    localparam CSR_EPC     = 16'h0001;
    localparam CSR_CAUSE   = 16'h0002;
    localparam CSR_MMU_PTB = 16'h0003;
    localparam CSR_TVAL    = 16'h0004;
    localparam CSR_TIME    = 16'h0005; // Read-only from core's perspective, reflects mtime
    localparam CSR_TIMECMP = 16'h0006;

    // Registers
    reg [63:0] status;
    reg [63:0] epc;
    reg [63:0] cause;
    reg [63:0] mmu_ptb;
    reg [63:0] tval;
    reg [63:0] timecmp;

    assign epc_out = epc;
    assign mmu_ptb_out = mmu_ptb;
    assign timecmp_out = timecmp;
    assign interrupt_req_out = status[1] & timer_interrupt_in;

    // CSR Read
    always @(*) begin
        case (csr_addr)
            CSR_STATUS:  csr_rdata = status;
            CSR_EPC:     csr_rdata = epc;
            CSR_CAUSE:   csr_rdata = cause;
            CSR_MMU_PTB: csr_rdata = mmu_ptb;
            CSR_TVAL:    csr_rdata = tval;
            CSR_TIME:    csr_rdata = mtime_in;
            CSR_TIMECMP: csr_rdata = timecmp;
            default:     csr_rdata = 64'd0;
        endcase
    end

    // CSR Write and Hardware Updates
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            status    <= 64'd1; // Default to Machine Mode (bit 0 = 1)
            epc       <= 64'd0;
            cause     <= 64'd0;
            mmu_ptb   <= 64'd0;
            tval      <= 64'd0;
            timecmp   <= 64'hFFFF_FFFF_FFFF_FFFF; // Disable timer interrupt on reset
            priv_mode <= 1'b1;
        end else if (trap_req) begin
            // Hardware automatically saves state on trap
            epc       <= trap_pc;
            cause     <= trap_cause;
            tval      <= trap_tval;
            priv_mode <= 1'b1;      // Enter Machine Mode
            status[0] <= 1'b1;
            status[1] <= 1'b0;      // Disable interrupts on trap entry
        end else if (eret_req) begin
            // Return from exception
            priv_mode <= 1'b0;      // Drop to User Mode (Wait, maybe restore from status. Keep simple 0 for now)
            status[0] <= 1'b0;
            status[1] <= 1'b1;      // Re-enable interrupts roughly

        end else if (csr_we && priv_mode == 1'b1) begin
            case (csr_addr)
                CSR_STATUS:  begin status <= csr_wdata; priv_mode <= csr_wdata[0]; end
                CSR_EPC:     epc <= csr_wdata;
                CSR_CAUSE:   cause <= csr_wdata;
                CSR_MMU_PTB: mmu_ptb <= csr_wdata;
                CSR_TVAL:    tval <= csr_wdata;
                CSR_TIMECMP: timecmp <= csr_wdata;
                default: ;
            endcase
        end
    end

endmodule
