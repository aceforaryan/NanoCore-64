`timescale 1ns / 1ps

module mmu (
    input  wire [63:0] virtual_addr,
    input  wire [63:0] mmu_ptb,     // Page Table Base from CSR
    input  wire        mem_req,     // Is memory being accessed?
    input  wire        priv_mode,   // 0: User, 1: Machine
    
    output wire [63:0] physical_addr,
    output wire        page_fault
);

    // Ultra-lightweight MMU behavior:
    // If mmu_ptb == 0 (typically M-Mode or early boot), 1:1 physical mapping.
    // If mmu_ptb != 0, simple simulated translation for OS app sandboxes.
    // In a real device, this would contain a 4-entry or 8-entry TLB.
    
    wire vmem_enabled = (mmu_ptb != 64'd0) && (priv_mode == 1'b0);
    
    // Page size 4KB -> offset is [11:0]
    wire [11:0] page_offset = virtual_addr[11:0];
    wire [51:0] vpn         = virtual_addr[63:12];
    
    // mmu_ptb[31:0]:  Physical Base Page Number
    // mmu_ptb[63:32]: Virtual Page Limit (Max VPN allowed)
    wire [31:0] base_ppn    = mmu_ptb[31:0];
    wire [31:0] vpn_limit    = mmu_ptb[63:32];
    
    wire is_uart       = (physical_addr == 64'h0000_0000_1000_0000);
    wire out_of_bounds = (vpn >= vpn_limit) && !is_uart;
    wire [51:0] ppn    = vpn + {20'd0, base_ppn};
    
    assign physical_addr = vmem_enabled ? (is_uart ? virtual_addr : {ppn, page_offset}) : virtual_addr;
    
    // Page fault if:
    // 1. Out of bounds (VPN >= Limit) AND not UART
    assign page_fault = mem_req && vmem_enabled && out_of_bounds;

endmodule
