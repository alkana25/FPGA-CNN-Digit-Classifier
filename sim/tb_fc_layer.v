`timescale 1ns / 1ps

module tb_fc_layer;

    // --- Signals ---
    reg clk, rst, start;
    
    // Memory Interfaces
    wire [9:0] rd_addr;     // Address FC layer asks for
    reg [7:0] rd_data;      // Data we give back
    wire [9:0] wr_addr;     // Address FC layer writes to
    wire [7:0] wr_data;     // Result data
    wire wr_en, done;       // Control signals

    // --- Instantiate UUT with Reduced Parameters ---
    // We reduce the size to speed up simulation time for functional verification.
    // Inputs: 5 (instead of 676)
    // Outputs: 2 (instead of 32)
    fc_layer #(
        .NUM_INPUTS(5), 
        .NUM_OUTPUTS(2),
        .RELU_EN(1),
        // Ensure these files exist in your simulation directory!
        // For this test, they can be dummy files with just a few lines.
        .WEIGHT_FILE("fc1_weights.mem"), 
        .BIAS_FILE("fc1_bias.mem")
    ) uut (
        .clk(clk), 
        .rst(rst), 
        .start(start),
        .rd_addr(rd_addr), 
        .rd_data(rd_data),
        .wr_addr(wr_addr), 
        .wr_data(wr_data),
        .wr_en(wr_en), 
        .done(done)
    );

    // --- Clock Generation (100 MHz) ---
    always #5 clk = ~clk;

    // --- Memory Simulation (Dummy Data Source) ---
    // Instead of a real RAM, we just return the address as data.
    // e.g., Request Addr 3 -> Return Data 3.
    always @(posedge clk) begin
        rd_data <= rd_addr[7:0]; 
    end

    // --- Output Monitor ---
    // Print the results to the console when the layer writes to memory.
    always @(posedge clk) begin
        if (wr_en) begin
            $display("[Time: %t] FC Output Generated -> Neuron: %d, Value: %d", $time, wr_addr, wr_data);
        end
    end

    // --- Test Scenario ---
    initial begin
        // 1. Initialize
        clk = 0; rst = 1; start = 0;
        
        $display("--- STARTING FC LAYER SIMULATION (REDUCED SIZE) ---");
        
        // 2. Reset Sequence
        #100; rst = 0;
        
        // 3. Start Pulse
        #20; start = 1;
        #10; start = 0;
        
        // 4. Wait for Completion
        wait(done);
        
        #50;
        $display("--- SIMULATION COMPLETED SUCCESSFULLY ---");
        $finish;
    end

endmodule
