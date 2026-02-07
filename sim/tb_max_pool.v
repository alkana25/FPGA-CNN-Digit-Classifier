`timescale 1ns / 1ps

module tb_max_pool;

    // --- Signals ---
    reg clk;
    reg rst;
    reg start;
    
    // --- Requests from the Design ---
    wire [9:0] rd_addr;  // Address requested by the max_pool module
    reg [7:0] rd_data;   // Data provided by the testbench (simulated memory)
    
    // --- Outputs from the Design ---
    wire [7:0] data_out; // The resulting maximum value
    wire valid_out;      // Valid flag for the output
    wire done;           // Operation finished flag
    
    // --- Test Memory ---
    // Simulates the output of the previous Conv Layer.
    // Dimensions: 26x26 = 676 pixels required.
    reg [7:0] test_mem [0:1023]; 

    // --- Instantiate the Unit Under Test (UUT) ---
    max_pool uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .rd_addr(rd_addr), 
        .rd_data(rd_data), 
        .data_out(data_out), 
        .valid_out(valid_out), 
        .done(done)
    );

    // --- Clock Generation ---
    // 100 MHz System Clock
    always #5 clk = ~clk; 

    // --- Memory Read Logic (BRAM Simulation) ---
    // Simulates the 1-cycle latency of FPGA Block RAM.
    // When the module requests 'rd_addr', data appears on the next rising edge.
    always @(posedge clk) begin
        rd_data <= test_mem[rd_addr];
    end

    // --- TEST SCENARIO ---
    integer i;
    initial begin
        // 1. Initialize Signals
        clk = 0;
        rst = 1;
        start = 0;
        
        // 2. Initialize Memory with Default Values
        // Fill memory with a background value (e.g., 16)
        for (i=0; i<1024; i=i+1) test_mem[i] = 8'h10; 
        
        // 3. Create Specific Test Patterns
        // We manually set values for the first two 2x2 windows to verify logic.
        // Assuming Input Width = 26 pixels.
        
        // --- Window 1 (Top-Left) ---
        // Coordinates: (0,0), (0,1) and (1,0), (1,1)
        // Addresses: 0, 1 and (0+26)=26, (1+26)=27
        test_mem[0]  = 8'd10; 
        test_mem[1]  = 8'd50; 
        test_mem[26] = 8'd99; // <--- TARGET MAX VALUE (Expected: 99)
        test_mem[27] = 8'd20;
        
        // --- Window 2 (Top-Right of Window 1) ---
        // Coordinates: (0,2), (0,3) and (1,2), (1,3)
        // Addresses: 2, 3 and (2+26)=28, (3+26)=29
        test_mem[2]  = 8'd55; // <--- TARGET MAX VALUE (Expected: 55)
        test_mem[3]  = 8'd12;
        test_mem[28] = 8'd05;
        test_mem[29] = 8'd01;

        $display("--- STARTING MAX POOL SIMULATION ---");
        
        // 4. Reset and Start
        #100;
        rst = 0;
        #20;
        start = 1;
        #10;
        start = 0;
        
        // 5. Wait for Completion
        wait(done);
        
        #50;
        $display("--- SIMULATION COMPLETED SUCCESSFULLY ---");
        $finish;
    end
    
    // --- Output Monitor ---
    // Prints the result whenever the module outputs a valid pixel.
    always @(posedge clk) begin
        if (valid_out) begin
            $display("[Time: %t] Max Pool Output: %d (Hex: %h)", $time, data_out, data_out);
        end
    end

endmodule
