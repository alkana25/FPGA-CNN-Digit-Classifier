`timescale 1ns / 1ps

module decision_unit(
    input wire clk,
    input wire rst,
    input wire start,
    
    // --- Memory Interface (Reading from FC2 Layer) ---
    // Reads the 10 final scores (corresponding to digits 0-9)
    output reg [9:0] rd_addr, // Address to read
    input wire [7:0] rd_data, // Score received from memory
    
    // --- Result Output ---
    // Returns the digit (index) with the highest score
    output reg [3:0] category_out, 
    output reg done
);

    // --- State Machine Definitions ---
    localparam IDLE     = 0, 
               READ_REQ = 1, 
               WAIT_MEM = 2, 
               COMPARE  = 3, 
               FINISH   = 4;
               
    reg [2:0] state;
    
    // --- Internal Registers ---
    reg [3:0] counter;      // Iterator for digits (0 to 9)
    reg [7:0] max_val;      // Stores the highest score found so far
    reg [3:0] max_idx;      // Stores the index (digit) of the highest score

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            max_val <= 0;
            max_idx <= 0;
            counter <= 0;
            category_out <= 0;
            rd_addr <= 0;
        end else begin
            case(state)
                // 1. Idle State
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        counter <= 0;
                        max_val <= 0; // Reset max value before starting
                        max_idx <= 0;
                        state <= READ_REQ;
                    end
                end
                
                // 2. Request Data
                // Set the address to the current counter value (e.g., 0, 1, ... 9)
                READ_REQ: begin
                    rd_addr <= counter;
                    state <= WAIT_MEM;
                end
                
                // 3. Memory Latency
                // Wait 1 cycle for the Block RAM to provide data
                WAIT_MEM: begin
                    state <= COMPARE;
                end
                
                // 4. Comparison Logic (Argmax)
                COMPARE: begin
                    // Check if this is the first value OR if the new value is larger than the current max
                    if (counter == 0 || rd_data > max_val) begin
                        max_val <= rd_data; // Update max score
                        max_idx <= counter; // Update the "winner" digit
                    end
                    
                    // Loop Control: Check all 10 digits (0 to 9)
                    if (counter == 9) begin
                        state <= FINISH;
                    end else begin
                        counter <= counter + 1; // Move to next digit
                        state <= READ_REQ;
                    end
                end
                
                // 5. Output Result
                FINISH: begin
                    category_out <= max_idx; // Output the predicted digit
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule
