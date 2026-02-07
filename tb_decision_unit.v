`timescale 1ns / 1ps

module tb_decision_unit;

    // --- Signals ---
    reg clk;
    reg rst;
    reg start;
    
    // --- Interface with Design ---
    wire [9:0] rd_addr;     // Address requested by the decision unit
    reg [7:0] rd_data;      // Data provided by the testbench
    
    // --- Outputs ---
    wire [3:0] category_out; // The predicted digit
    wire done;               // Process completion flag

    // --- Instantiate the Unit Under Test (UUT) ---
    decision_unit uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .rd_addr(rd_addr), 
        .rd_data(rd_data), 
        .category_out(category_out), 
        .done(done)
    );

    // --- Clock Generation (100 MHz) ---
    always #5 clk = ~clk;

    // --- Memory Simulation (FC2 Output) ---
    // Simulates the array holding the final 10 scores.
    reg [7:0] fake_fc2_mem [0:9];

    // Read Logic: Provides data with 1-cycle latency (Standard BRAM behavior)
    always @(posedge clk) begin
        rd_data <= fake_fc2_mem[rd_addr];
    end

    // --- TEST SCENARIO ---
    integer i;
    initial begin
        // 1. Initialize
        clk = 0; rst = 1; start = 0;
        
        // 2. Populate Memory
        // Fill all with a low base score (e.g., 10)
        for (i=0; i<10; i=i+1) fake_fc2_mem[i] = 8'd10; 
        
        // Inject a clear winner and a runner-up
        // We expect Digit 7 to win with score 200.
        fake_fc2_mem[3] = 8'd150; // Runner-up
        fake_fc2_mem[7] = 8'd200; // Winner (Max Value)

        $display("--- STARTING DECISION UNIT SIMULATION ---");
        
        // 3. Reset Sequence
        #100; rst = 0;
        
        // 4. Start Pulse
        #20; start = 1;
        #10; start = 0;
        
        // 5. Wait for Completion
        wait(done);
        
        // 6. Verify Result
        $display("--- SIMULATION FINISHED ---");
        $display("Expected Result: 7");
        $display("Actual Result:   %d", category_out);
        
        if (category_out == 7) 
            $display("-> TEST PASSED [OK]");
        else 
            $display("-> TEST FAILED [ERROR]");
        
        #50;
        $finish;
    end
    
    // --- Live Monitor ---
    // Prints the internal state to the console as it runs.
    // This helps visualize the "scanning" process.
    always @(posedge clk) begin
        if (!rst && !done && start == 0) begin
            // When the module requests an address, show what it will get.
            // Note: Data arrives 1 cycle later, but this gives a good idea of flow.
            $display("[Time: %t] Scanning Index: %d", $time, rd_addr);
        end
    end

endmodule