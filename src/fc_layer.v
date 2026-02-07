`timescale 1ns / 1ps

module fc_layer #(
    parameter NUM_INPUTS = 676,     // Number of input features (e.g., 26x26 flattened)
    parameter NUM_OUTPUTS = 32,     // Number of neurons in this layer
    parameter RELU_EN = 1,          // 1: Enable ReLU, 0: Linear activation
    parameter WEIGHT_FILE = "fc1_weights.mem", 
    parameter BIAS_FILE = "fc1_bias.mem"
)(
    input wire clk, input wire rst, input wire start,
    
    // --- Input Memory Interface ---
    output reg [9:0] rd_addr,       // Address to read input data
    input wire [7:0] rd_data,       // Input data from previous layer
    
    // --- Output Memory Interface ---
    output reg [9:0] wr_addr,       // Address to write output data
    output reg [7:0] wr_data,       // Calculated neuron output
    output reg wr_en,               // Write enable signal
    output reg done                 // Operation finished flag
);

    // --- Weights & Biases Storage ---
    // Stored in FPGA Block RAM or Distributed RAM
    reg signed [7:0] weights [0 : NUM_INPUTS * NUM_OUTPUTS - 1]; 
    reg signed [7:0] biases [0 : NUM_OUTPUTS - 1];
    
    initial begin 
        $readmemh(WEIGHT_FILE, weights); 
        $readmemh(BIAS_FILE, biases);
    end

    // --- FSM States ---
    localparam IDLE=0, LOAD_ACC=1, READ_INPUT=2, WAIT_RAM=3, MAC=4, BIAS_ACT=5, FINISH=6;
    reg [2:0] state;
    
    // --- Internal Counters & Registers ---
    reg [9:0] in_cnt;   // Counter for inputs (0 to NUM_INPUTS-1)
    reg [9:0] out_cnt;  // Counter for outputs/neurons (0 to NUM_OUTPUTS-1)
    
    reg signed [31:0] acc;      // Accumulator for MAC operations
    reg [15:0] w_ptr;           // Pointer for the weight array
    reg signed [31:0] temp_val; // Temporary register for post-processing

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; done <= 0; wr_en <= 0; rd_addr <= 0; wr_addr <= 0;
            wr_data <= 0; out_cnt <= 0; in_cnt <= 0; acc <= 0; w_ptr <= 0; temp_val <= 0;
        end else begin
            case(state)
                // 1. Idle State
                IDLE: begin
                    done <= 0; wr_en <= 0;
                    if (start) begin 
                        out_cnt <= 0; 
                        w_ptr <= 0; 
                        state <= LOAD_ACC; 
                    end 
                end
                
                // 2. Initialize Accumulator for Current Neuron
                LOAD_ACC: begin
                    acc <= 0; 
                    in_cnt <= 0; 
                    wr_en <= 0; 
                    state <= READ_INPUT;
                end
                
                // 3. Request Input Data
                READ_INPUT: begin
                    rd_addr <= in_cnt; 
                    state <= WAIT_RAM;
                end
                
                // 4. Wait for Memory Latency
                WAIT_RAM: state <= MAC;
                
                // 5. Multiply-Accumulate (MAC)
                MAC: begin
                    // acc = acc + (input * weight)
                    acc <= acc + ($signed({1'b0, rd_data}) * weights[w_ptr]);
                    w_ptr <= w_ptr + 1; 
                    
                    if (in_cnt == NUM_INPUTS - 1) state <= BIAS_ACT; 
                    else begin in_cnt <= in_cnt + 1; state <= READ_INPUT; end
                end
                
                // 6. Bias Addition & Activation
                BIAS_ACT: begin 
                    // --- SCALING ADJUSTMENT ---
                    // Conv Layer used >>> 8 (divide by 256).
                    // FC Layer inputs are scaled differently (approx 128 range).
                    // Using >>> 7 (divide by 128) preserves signal integrity.
                    // Using >>> 8 here would result in signal loss (too close to 0).
                    
                    temp_val = (acc >>> 7) + biases[out_cnt];
                    
                    // DEBUG: Print scores if this is the final output layer (10 neurons)
                    if (NUM_OUTPUTS == 10) begin
                        $display("DEBUG [FC2]: Digit %0d -> Score: %d", out_cnt, temp_val);
                    end

                    // ReLU Activation (If enabled)
                    if (RELU_EN && temp_val < 0) temp_val = 0; 
                    
                    // Clipping (Saturate to 8-bit unsigned)
                    if (temp_val > 255) wr_data <= 255;
                    else if (temp_val < 0) wr_data <= 0; 
                    else wr_data <= temp_val[7:0];
                    
                    // Write Result
                    wr_addr <= out_cnt; 
                    wr_en <= 1; 
                    
                    // Check if all neurons are processed
                    if (out_cnt == NUM_OUTPUTS - 1) state <= FINISH;
                    else begin out_cnt <= out_cnt + 1; state <= LOAD_ACC; end
                end
                
                // 7. Finish
                FINISH: begin 
                    wr_en <= 0; done <= 1; 
                    if (!start) state <= IDLE; 
                end
            endcase
        end
    end
endmodule
