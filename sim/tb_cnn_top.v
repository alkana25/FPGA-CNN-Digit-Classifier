`timescale 1ns / 1ps

module tb_cnn_top;

    // --- Signals ---
    reg clk;
    reg rst;
    reg start;
    
    // --- Outputs from the System ---
    wire [3:0] result; // The final predicted digit (0-9)
    wire done;         // System completion flag

    // --- Instantiate the Unit Under Test (UUT) ---
    cnn_top uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .result(result), 
        .done(done)
    );

    // --- Clock Generation ---
    // 100 MHz System Clock (Period = 10ns)
    always #10 clk = ~clk;

    // --- TEST SCENARIO ---
    initial begin
        // 1. Initialize Signals
        clk = 0;
        rst = 1;
        start = 0;
        
        $display("---------------------------------------");
        $display("--- FULL SYSTEM SIMULATION STARTED ---");
        $display("---------------------------------------");
       
        // 2. FPGA'in uyanmasını bekle (Global Set/Reset için 100ns şarttır)
        #2000; 
        
        // 3. Reset'i SAĞLAM bir şekilde bırak
        // Clock'un "Düşen Kenarında" (negedge) reset bırakmak en güvenlisidir.
        // Böylece yükselen kenar geldiğinde sinyal çoktan oturmuş olur.
        @(negedge clk); 
        rst = 0;      // Reset'i çek
        
        // 4. Biraz dinlen (Sistemin kendine gelmesi için)
        #500; 
        
        // 5. Start'ı SENKRON ver (Daha önce yaptığımız gibi)
        @(posedge clk); // Clock yükselsin
        start = 1;      // Start ver
        
        #2000;
        start = 0;      // Start çek

        // 4. Wait for Completion
        // The simulation will pause here until the 'done' signal goes high.
        // This covers Conv -> Pool -> FC1 -> FC2 -> Decision stages.
        wait(done);
        
        #50; // Wait a bit for stability

        // 5. Verify and Report Results
        $display("---------------------------------------");
        $display("--- PROCESSING COMPLETE ---");
        $display("Final Prediction: %d", result);
        
        // Check against the expected label 
        if (result == 1) begin
            $display(">>> TEST STATUS: PASSED [SUCCESS] <<<");
            $display("The accelerator correctly classified the image as 1.");
        end else begin
            $display(">>> TEST STATUS: FAILED [ERROR] <<<");
            $display("Expected: 1, But Got: %d", result);
        end
        $display("---------------------------------------");
        
        $stop; // End simulation
    end
endmodule
