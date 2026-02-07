`timescale 1ns / 1ps

module tb_conv_layer;

    // --- Signals ---
    reg clk;                    // System Clock
    reg rst;                    // Reset signal
    reg start;                  // Signal to start the operation
    reg [1:0] filter_select;    // Selects which filter to use (0, 1, 2, or 3)
    
    // --- Outputs from the Design (DUT) ---
    wire [9:0] img_addr;        // Address requested by the convolution module
    wire [7:0] data_out;        // Result of the convolution (pixel value)
    wire valid_out;             // Flag indicating 'data_out' is valid
    wire done;                  // Flag indicating the process is finished
    
    // --- Memory Simulation Signals ---
    reg [7:0] tb_img_data;      // Data read from the simulated memory
    reg [7:0] test_image [0:783]; // Simulated Block RAM (Holds the 28x28 image)

    // --- Instantiate the Unit Under Test (UUT) ---
    // Here we connect our 'conv_layer' module to this testbench
    conv_layer uut (
        .clk(clk), 
        .rst(rst), 
        .start(start),
        .filter_select(filter_select), 
        .img_addr(img_addr), 
        .img_data(tb_img_data), 
        .data_out(data_out), 
        .valid_out(valid_out), 
        .done(done)
    );
    
    // --- Clock Generation ---
    // Generates a 100MHz clock (Period = 10ns)
    always #5 clk = ~clk; 

    // --- Memory Read Logic ---
    // Simulates the behavior of FPGA Block RAM.
    // When the module asks for an address (img_addr), 
    // the data is provided on the next clock cycle.
    always @(posedge clk) begin
        tb_img_data <= test_image[img_addr];
    end

    // --- 4-STAGE TEST SCENARIO ---
    initial begin
        // 1. Initialize Signals
        clk = 0; rst = 1; start = 0; filter_select = 0; tb_img_data = 0;
        
        // 2. Load the Image File into Memory
        // Ensure "test_image.mem" is in your simulation folder
        $readmemh("test_image.mem", test_image); 
        
        $display("--- STARTING FULL 4-FILTER TEST ---");
        
        // 3. Apply Reset
        #100; rst = 0; #20;
        
        // --- TEST FILTER 0 ---
        $display("[Time: %t] Running Filter 0 (Kernel 1)...", $time);
        filter_select = 2'b00;      // Select 1st Filter
        start = 1; #10; start = 0;  // Send a 1-clock pulse to START
        
        wait(done);                 // Wait until the module finishes
        $display("-> Filter 0 Completed.");
        #50;                        // Short delay before next filter
        
        // --- TEST FILTER 1 ---
        $display("[Time: %t] Running Filter 1 (Kernel 2)...", $time);
        filter_select = 2'b01;      // Select 2nd Filter
        start = 1; #10; start = 0;
        
        wait(done);
        $display("-> Filter 1 Completed.");
        #50;

        // --- TEST FILTER 2 ---
        $display("[Time: %t] Running Filter 2 (Kernel 3)...", $time);
        filter_select = 2'b10;      // Select 3rd Filter
        start = 1; #10; start = 0;
        
        wait(done);
        $display("-> Filter 2 Completed.");
        #50;

        // --- TEST FILTER 3 ---
        $display("[Time: %t] Running Filter 3 (Kernel 4)...", $time);
        filter_select = 2'b11;      // Select 4th Filter
        start = 1; #10; start = 0;
        
        wait(done);
        $display("-> Filter 3 Completed.");
        
        // End of Test
        $display("--- ALL FILTERS COMPLETED SUCCESSFULLY ---");
        $stop; // Stop the simulation
    end

endmodule