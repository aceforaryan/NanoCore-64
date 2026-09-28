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
        if (!rst) cycle_count <= cycle_count + 1;
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

    integer trace_fd;
    reg trace_enabled;
    reg [2047:0] trace_path;

    // Data memory write handling (MMIO and normal)
    always @(posedge clk) begin
        if (dmem_we) begin
            if (dmem_addr == 64'h10000000) begin
                $write("%c", dmem_wdata[7:0]);
            end else if (dmem_addr == 64'h20000000) begin
                if (dmem_wdata == 64'h00) begin
                    $display("\nTEST_RESULT: PASS");
                    if (trace_enabled) $fclose(trace_fd);
                    $finish;
                end else begin
                    $display("\nTEST_RESULT: FAIL");
                    print_diagnostics(dmem_wdata);
                    if (trace_enabled) $fclose(trace_fd);
                    $finish;
                end
            end else begin
                dmem[dmem_addr[13:3]] <= dmem_wdata;
            end
        end
    end

    // =========================================================================
    // Architectural Trace Output
    // =========================================================================
    // Emits per-cycle trace records matching ISS trace format.
    // Enabled via +TRACE_FILE=<path> plusarg.
    //
    // Trace format per cycle:
    //   CYCLE <n>
    //   PC <hex16>
    //   INST <hex8>
    //   PRIV <M|U>
    //   REG <rd> <hex16>       (if register writeback)
    //   MEM_RD <addr> <hex16>  (if data memory read)
    //   MEM_WR <addr> <hex16>  (if data memory write)
    //   CSR_WR <addr> <hex16>  (if CSR write)
    //   TRAP <cause>           (if synchronous trap)
    //   INTERRUPT <cause>      (if timer interrupt)
    //   ---
    // =========================================================================

    // =========================================================================

    // Registered snapshot of combinational trace signals
    // Captured at posedge clk (same edge that latches new PC),
    // these reflect the instruction that JUST EXECUTED during this cycle.
    reg [63:0] trace_pc;
    reg [31:0] trace_inst;
    reg        trace_priv;
    reg        trace_rf_we;
    reg [4:0]  trace_rf_rd;
    reg [63:0] trace_rf_wd;
    reg        trace_dmem_re;
    reg        trace_dmem_we;
    reg [63:0] trace_dmem_addr;
    reg [63:0] trace_dmem_rdata;
    reg [63:0] trace_dmem_wdata;
    reg        trace_csr_we;
    reg [15:0] trace_csr_addr;
    reg [63:0] trace_csr_wdata;
    reg        trace_trap_req;
    reg [63:0] trace_trap_cause;
    reg        trace_valid;

    // Capture combinational signals at posedge (just before they change)
    always @(posedge clk) begin
        if (rst) begin
            trace_valid <= 1'b0;
        end else begin
            trace_valid    <= 1'b1;
            trace_pc       <= dut.pc;
            trace_inst     <= imem_data;
            trace_priv     <= dut.csr_inst.priv_mode;
            trace_rf_we    <= dut.rf.we;
            trace_rf_rd    <= dut.rf.rd;
            trace_rf_wd    <= dut.rf.wd;
            trace_dmem_re  <= dut.dmem_re;
            trace_dmem_we  <= dut.dmem_we;
            trace_dmem_addr  <= dmem_addr;
            trace_dmem_rdata <= dmem_rdata;
            trace_dmem_wdata <= dmem_wdata;
            trace_csr_we     <= dut.csr_we;
            trace_csr_addr   <= dut.csr_inst.csr_addr;
            trace_csr_wdata  <= dut.csr_wdata;
            trace_trap_req   <= dut.trap_req;
            trace_trap_cause <= dut.trap_cause;
        end
    end

    // Emit trace at negedge from captured snapshot
    always @(negedge clk) begin
        if (!rst && trace_enabled && trace_valid) begin
            $fwrite(trace_fd, "CYCLE %0d\n", cycle_count);
            $fwrite(trace_fd, "PC %016H\n", trace_pc);
            $fwrite(trace_fd, "INST %08H\n", trace_inst);
            $fwrite(trace_fd, "PRIV %s\n", trace_priv ? "M" : "U");

            if (trace_rf_we && trace_rf_rd != 5'd0) begin
                $fwrite(trace_fd, "REG %0d %016H\n", trace_rf_rd, trace_rf_wd);
            end

            if (trace_dmem_re) begin
                $fwrite(trace_fd, "MEM_RD %016H %016H\n", trace_dmem_addr, trace_dmem_rdata);
            end

            if (trace_dmem_we) begin
                $fwrite(trace_fd, "MEM_WR %016H %016H\n", trace_dmem_addr, trace_dmem_wdata);
            end

            if (trace_csr_we && trace_priv) begin
                $fwrite(trace_fd, "CSR_WR %04H %016H\n", trace_csr_addr, trace_csr_wdata);
            end

            if (trace_trap_req) begin
                if (trace_trap_cause == 64'd3) begin
                    $fwrite(trace_fd, "INTERRUPT 3\n");
                end else begin
                    $fwrite(trace_fd, "TRAP %0d\n", trace_trap_cause);
                end
            end

            $fwrite(trace_fd, "---\n");
            $fflush(trace_fd);
        end
    end

    // Clock generation
    always #5 clk = ~clk;

    parameter MAX_SIM_CYCLES = 50000;

    reg [2047:0] hex_file;
    integer j;
    initial begin
        cycle_count = 0;
        trace_enabled = 0;
        trace_fd = 0;
        for (j = 0; j < 2048; j = j + 1) begin
            imem[j] = 32'd0;
            dmem[j] = 64'd0;
        end
        
        if ($value$plusargs("HEX_FILE=%s", hex_file)) begin
            $readmemh(hex_file, imem);
        end else begin
            $readmemh("timer_test.hex", imem);
        end

        if ($value$plusargs("TRACE_FILE=%s", trace_path)) begin
            trace_fd = $fopen(trace_path, "w");
            if (trace_fd != 0) begin
                trace_enabled = 1;
            end else begin
                $display("WARNING: Could not open trace file");
            end
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
        if (trace_enabled) $fclose(trace_fd);
        $finish;
    end
endmodule
