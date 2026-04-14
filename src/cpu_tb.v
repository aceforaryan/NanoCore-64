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

    // Memory reads/writes (imem_addr is in bytes, so shift by 2 for word indexing)
    assign imem_data  = imem[imem_addr[12:2]];
    
    // dmem_addr might be in bytes as well if byte addressable, shift by 3 (64-bit = 8 bytes)
    assign dmem_rdata = dmem[dmem_addr[13:3]];

    always @(posedge clk) begin
        if (dmem_we) begin
            dmem[dmem_addr[13:3]] <= dmem_wdata;
        end
    end

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize memory
        $readmemh("fibonacci.hex", imem);
        
        // Setup GTKWave dump
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);

        clk = 0;
        rst = 1;

        #20;
        rst = 0;

        // Run until sleep or timeout
        wait(sleep_mode == 1'b1);
        #20;

        $display("Simulation finished. CPU entered SLEEP mode.");
        $display("Register Dump:");
        $display("R1 : %d", dut.rf.registers[1]);
        $display("R2 : %d", dut.rf.registers[2]);
        $display("Cycles complete.");
        
        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000;
        $display("Simulation Timeout due to infinite loop or missing SLEEP.");
        $finish;
    end

endmodule
