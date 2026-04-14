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
    
    wire vmem_enabled = (mmu_ptb != 64'd0);
    
    // Page size 4KB -> offset is [11:0]
    wire [11:0] page_offset = virtual_addr[11:0];
    wire [51:0] vpn         = virtual_addr[63:12];
    
    // Simplistic simulation of translation: Physical Page Number = VPN + PTB[51:0]
    // In actual implementation, we would query a small SRAM TLB here.
    wire [51:0] ppn         = vpn + mmu_ptb[51:0];
    
    assign physical_addr = vmem_enabled ? {ppn, page_offset} : virtual_addr;
    
    // Simple protection: Trigger page fault if trying to access physical address < 64KB in User Mode
    // (Protecting OS kernel space).
    assign page_fault = mem_req && vmem_enabled && (priv_mode == 1'b0) && (physical_addr < 64'h0000_0000_0001_0000);

endmodule
