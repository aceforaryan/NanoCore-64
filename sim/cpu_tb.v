`timescale 1ns / 1ps

module cpu_tb;

    reg clk;
    reg rst;

    // Memory arrays (64-bit words)
    reg [31:0] imem [0:2047];
    reg [63:0] dmem [0:2047];

    // CPU Connections
    wire [63:0] imem_addr;
    wire [31:0] imem_data;
    wire [63:0] dmem_addr;
    wire [63:0] dmem_wdata;
    wire [63:0] dmem_rdata;
    wire        dmem_we;
    wire        dmem_re;
    wire        sleep_mode;

    // Instantiate CPU
    cpu dut (
        .clk(clk),
        .rst(rst),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_re(dmem_re),
        .sleep_mode(sleep_mode)
    );

    // Memory reads/writes
    assign imem_data  = imem[imem_addr[12:2]];
    assign dmem_rdata = dmem[dmem_addr[13:3]];

    integer cycle_count;
    
    always @(posedge clk) begin
        if (!rst) cycle_count = cycle_count + 1;
    end

    // Diagnostic Task
    task print_diagnostics;
        input [63:0] status_code;
        integer i;
        begin
            $display("====================================");
            $display("DIAGNOSTICS");
            $display("====================================");
            $display("Cycle               : %0d", cycle_count);
            $display("Simulation Time     : %0t", $time);
            $display("PC                  : %016X", dut.pc);
            $display("Current Instruction : %08X", dut.imem_data);
            $display("Decoded Opcode      : %02X", dut.imem_data[5:0]);
            $display("Memory Address      : %016X", dmem_addr);
            $display("Exception Cause     : %0d", dut.csr_inst.cause);
            $display("Status Code         : %02X", status_code);
            
            $display("--- CSR State ---");
            $display("STATUS : %016X", dut.csr_inst.status);
            $display("EPC    : %016X", dut.csr_inst.epc);
            $display("CAUSE  : %016X", dut.csr_inst.cause);
            $display("MMU_PTB: %016X", dut.csr_inst.mmu_ptb);
            $display("TVAL   : %016X", dut.csr_inst.tval);
            
            $display("--- Register File ---");
            for (i = 0; i < 32; i = i + 4) begin
                $display("R%02d:%016X  R%02d:%016X  R%02d:%016X  R%02d:%016X", 
                         i, dut.rf.registers[i], 
                         i+1, dut.rf.registers[i+1], 
                         i+2, dut.rf.registers[i+2], 
                         i+3, dut.rf.registers[i+3]);
            end
        end
    endtask

    always @(posedge clk) begin
        if (dmem_we) begin
            if (dmem_addr == 64'h10000000) begin
                $write("%c", dmem_wdata[7:0]);
            end else if (dmem_addr == 64'h20000000) begin
                if (dmem_wdata == 64'h00) begin
                    $display("\nTEST_RESULT: PASS");
                    $finish;
                end else begin
                    $display("\nTEST_RESULT: FAIL");
                    print_diagnostics(dmem_wdata);
                    $finish;
                end
            end else begin
                dmem[dmem_addr[13:3]] <= dmem_wdata;
            end
        end
    end

    // Clock generation
    always #5 clk = ~clk;

    parameter MAX_SIM_CYCLES = 50000;

    reg [2047:0] hex_file;
    initial begin
        cycle_count = 0;
        
        if ($value$plusargs("HEX_FILE=%s", hex_file)) begin
            $readmemh(hex_file, imem);
        end else begin
            $readmemh("timer_test.hex", imem);
        end
        
        if ($test$plusargs("DUMP_VCD")) begin
            $dumpfile("cpu_tb.vcd");
            $dumpvars(0, cpu_tb);
        end

        clk = 0;
        rst = 1;

        #20;
        rst = 0;
        
        // Timeout watchdog
        wait(cycle_count == MAX_SIM_CYCLES);
        $display("\nTEST_RESULT: TIMEOUT");
        print_diagnostics(64'h03); // TIMEOUT code
        $finish;
    end
endmodule
