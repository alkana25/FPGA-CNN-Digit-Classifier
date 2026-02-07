`timescale 1ns / 1ps

module conv_layer #(
    parameter WEIGHT_FILE = "conv1_weights.mem",
    parameter BIAS_FILE = "conv1_bias.mem"
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [1:0] filter_select, 
    output reg [9:0] img_addr,       
    input wire [7:0] img_data,       
    output reg [7:0] data_out,
    output reg valid_out,
    output reg done
);

    // --- Memories ---
    reg signed [7:0] weights [0:35]; 
    reg signed [7:0] biases [0:3];
    
    initial begin
        $readmemh(WEIGHT_FILE, weights);
        $readmemh(BIAS_FILE, biases);
    end

    localparam IDLE=0, LOAD_PIXEL=1, WAIT_MEM=2, MAC_OP=3, BIAS_RELU=4, OUTPUT_DATA=5, FINISHED=6;
    reg [2:0] state;
    
    reg [4:0] row, col;       
    reg [1:0] k_row, k_col;   
    
    // 32-bit Accumulator
    reg signed [31:0] acc;    
    reg signed [31:0] temp_val;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            row <= 0; col <= 0;
            k_row <= 0; k_col <= 0;
            acc <= 0;
            img_addr <= 0;
            valid_out <= 0;
            done <= 0;
        end else begin
            case(state)
                IDLE: begin 
                    done <= 0; 
                    valid_out <= 0; 
                    
                    if (start) begin
                        // --- CRITICAL FIX HERE ---
                        // Reset counters on every 'start' signal!
                        // Otherwise, subsequent filters (e.g., filter 2) won't run.
                        row <= 0; col <= 0;
                        k_row <= 0; k_col <= 0;
                        acc <= 0;
                        state <= LOAD_PIXEL; 
                    end
                end
                
                LOAD_PIXEL: begin
                    valid_out <= 0;
                    img_addr <= (row + k_row) * 28 + (col + k_col);
                    state <= WAIT_MEM; 
                end
                
                WAIT_MEM: state <= MAC_OP; 
                
                MAC_OP: begin
                    acc <= acc + ($signed({1'b0, img_data}) * weights[(filter_select * 9) + (k_row * 3) + k_col]);
                    
                    if (k_col == 2) begin
                        k_col <= 0;
                        if (k_row == 2) begin
                            k_row <= 0;
                            state <= BIAS_RELU; 
                        end else begin
                            k_row <= k_row + 1;
                            state <= LOAD_PIXEL;
                        end
                    end else begin
                        k_col <= k_col + 1;
                        state <= LOAD_PIXEL;
                    end
                end
                
                BIAS_RELU: begin
                    // Math: Scaling and Bias
                    acc <= (acc >>> 8) + biases[filter_select]; 
                    
                    // DEBUG: Check center pixel
                    if (row == 13 && col == 13) begin
                       $display("DEBUG [Conv]: Filter %0d (Center Pixel) -> Raw Value: %d", filter_select, acc);
                    end
                    
                    state <= OUTPUT_DATA;
                end
                
                OUTPUT_DATA: begin
                    // ReLU
                    if (acc < 0) temp_val = 0;
                    else temp_val = acc; 
                    
                    // Clipping
                    if (temp_val > 255) data_out <= 255;
                    else data_out <= temp_val[7:0];
                    
                    valid_out <= 1; 
                    acc <= 0;        
                    
                    if (col == 25) begin 
                        col <= 0;
                        if (row == 25) state <= FINISHED;
                        else begin row <= row + 1; state <= LOAD_PIXEL; end
                    end else begin
                        col <= col + 1;
                        state <= LOAD_PIXEL;
                    end
                end
                
                FINISHED: begin 
                    valid_out <= 0; done <= 1; 
                    if (!start) state <= IDLE; 
                end
            endcase
        end
    end
endmodule
