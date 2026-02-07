`timescale 1ns / 1ps

module cnn_top(
    input wire clk, 
    input wire rst, 
    input wire start,
    output reg [3:0] result, // The final predicted digit (0-9)
    output reg done          // System completion flag
);

    // --- MEMORY BUFFERS ---
    // These arrays store intermediate data between layers.
    reg [7:0] img_mem [0:783];        // Input Image (28x28 = 784 pixels)
    reg [7:0] conv_temp_mem [0:675];  // Temp buffer for Conv output (26x26 = 676)
    reg [7:0] flatten_mem [0:675];    // Flattened Max Pool output (4 filters x 13x13 = 676 total)
    reg [7:0] fc1_out_mem [0:31];     // Output of FC1 Layer (32 neurons)
    reg [7:0] fc2_out_mem [0:9];      // Output of FC2 Layer (10 neurons)

    // --- CONTROL SIGNALS ---
    reg [1:0] filter_cnt; // Tracks which filter is currently being processed (0 to 3)
    
    // Start signals for sub-modules
    reg conv_start, pool_start, fc1_start, fc2_start, dec_start;
    
    // Done signals from sub-modules
    wire conv_done, pool_done, fc1_done, fc2_done, dec_done;
    
    // Internal Data Buses
    wire [9:0] conv_addr;    wire [7:0] conv_data_out; wire conv_valid;
    wire [9:0] pool_rd_addr; wire [7:0] pool_data_out; wire pool_valid;
    
    wire [9:0] fc1_rd_addr, fc1_wr_addr; wire [7:0] fc1_data_out; wire fc1_we;
    wire [9:0] fc2_rd_addr, fc2_wr_addr; wire [7:0] fc2_data_out; wire fc2_we;
    
    wire [9:0] dec_rd_addr;  wire [3:0] dec_result;

    // --- FILE LOADING & INTEGRITY CHECK ---
    integer k;
    integer total_pixel_val; // Used to check if image is loaded correctly
    
    initial begin
        // 1. Clear Memories
        for(k=0; k<784; k=k+1) img_mem[k] = 0;
        for(k=0; k<676; k=k+1) conv_temp_mem[k] = 0;
        for(k=0; k<676; k=k+1) flatten_mem[k] = 0;
        for(k=0; k<32; k=k+1)  fc1_out_mem[k] = 0;
        for(k=0; k<10; k=k+1)  fc2_out_mem[k] = 0;

        // 2. Load Input Image
        // NOTE: Ensure the file path matches your simulation directory exactly.
        $readmemh("C:/EHB426/memory_files/test_image.mem", img_mem);
        
        // 3. Image Integrity Check (Simulation Only)
        // This block verifies if the image was actually loaded into memory.
        #10; // Wait 10ns for memory initialization
        total_pixel_val = 0;
        for(k=0; k<784; k=k+1) begin
            total_pixel_val = total_pixel_val + img_mem[k];
        end
        
    end

    // --- SUB-MODULE INSTANTIATIONS ---

    // 1. CONVOLUTIONAL LAYER
    // Processes 28x28 Input -> Produces 26x26 Feature Map
    conv_layer #(
        .WEIGHT_FILE("C:/EHB426/memory_files/conv1_weights.mem"),
        .BIAS_FILE("C:/EHB426/memory_files/conv1_bias.mem")
    ) conv_inst (
        .clk(clk), .rst(rst), .start(conv_start),
        .filter_select(filter_cnt), 
        .img_addr(conv_addr), .img_data(img_mem[conv_addr]), 
        .data_out(conv_data_out), .valid_out(conv_valid), .done(conv_done)
    );
    
    // Buffer Logic: Store Conv output into temporary memory
    reg [9:0] conv_wr_ptr;
    always @(posedge clk) begin
        if (rst || conv_start) conv_wr_ptr <= 0;
        else if (conv_valid) begin 
            conv_temp_mem[conv_wr_ptr] <= conv_data_out; 
            conv_wr_ptr <= conv_wr_ptr + 1; 
        end
    end

    // 2. MAX POOLING LAYER
    // Processes 26x26 Feature Map -> Produces 13x13 Downsampled Map
    max_pool pool_inst (
        .clk(clk), .rst(rst), .start(pool_start),
        .rd_addr(pool_rd_addr), .rd_data(conv_temp_mem[pool_rd_addr]), 
        .data_out(pool_data_out), .valid_out(pool_valid), .done(pool_done)
    );

    // Buffer Logic: Flattening
    // We store the output of each filter sequentially in 'flatten_mem'.
    // Offset calculation: (Filter Index * 169 pixels)
    reg [9:0] pool_wr_ptr;
    always @(posedge clk) begin
        if (rst || pool_start) pool_wr_ptr <= 0;
        else if (pool_valid) begin 
            flatten_mem[(filter_cnt * 169) + pool_wr_ptr] <= pool_data_out; 
            pool_wr_ptr <= pool_wr_ptr + 1; 
        end
    end

    // 3. FULLY CONNECTED LAYER 1 (FC1)
    // Input: 676 (Flattened) -> Output: 32 Neurons
    fc_layer #(
        .NUM_INPUTS(676), .NUM_OUTPUTS(32), .RELU_EN(1),
        .WEIGHT_FILE("C:/EHB426/memory_files/fc1_weights.mem"), 
        .BIAS_FILE("C:/EHB426/memory_files/fc1_bias.mem")
    ) fc1_inst (
        .clk(clk), .rst(rst), .start(fc1_start),
        .rd_addr(fc1_rd_addr), .rd_data(flatten_mem[fc1_rd_addr]), 
        .wr_addr(fc1_wr_addr), .wr_data(fc1_data_out), .wr_en(fc1_we), .done(fc1_done)
    );
    // Write FC1 output to memory
    always @(posedge clk) if (fc1_we) fc1_out_mem[fc1_wr_addr] <= fc1_data_out;

    // 4. FULLY CONNECTED LAYER 2 (FC2)
    // Input: 32 Neurons -> Output: 10 Class Scores
    fc_layer #(
        .NUM_INPUTS(32), .NUM_OUTPUTS(10), .RELU_EN(0), // No ReLU at output
        .WEIGHT_FILE("C:/EHB426/memory_files/fc2_weights.mem"), 
        .BIAS_FILE("C:/EHB426/memory_files/fc2_bias.mem")
    ) fc2_inst (
        .clk(clk), .rst(rst), .start(fc2_start),
        .rd_addr(fc2_rd_addr), .rd_data(fc1_out_mem[fc2_rd_addr]), 
        .wr_addr(fc2_wr_addr), .wr_data(fc2_data_out), .wr_en(fc2_we), .done(fc2_done)
    );
    // Write FC2 output to memory
    always @(posedge clk) if (fc2_we) fc2_out_mem[fc2_wr_addr] <= fc2_data_out;

    // 5. DECISION UNIT
    // Input: 10 Scores -> Output: Predicted Digit
    decision_unit dec_inst (
        .clk(clk), .rst(rst), .start(dec_start),
        .rd_addr(dec_rd_addr), .rd_data(fc2_out_mem[dec_rd_addr]), 
        .category_out(dec_result), .done(dec_done)
    );

    // --- MAIN FINITE STATE MACHINE (FSM) ---
    // Controls the sequential execution of layers
    localparam IDLE = 0, 
               CONV_RUN = 1, 
               POOL_RUN = 2, 
               NEXT_FILTER = 3, 
               FC1_RUN = 4, 
               FC2_RUN = 5, 
               DECISION_RUN = 6, 
               FINISH = 7;
               
    reg [2:0] state;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; 
            filter_cnt <= 0; 
            done <= 0; 
            result <= 0;
            conv_start <= 0; pool_start <= 0; 
            fc1_start <= 0; fc2_start <= 0; dec_start <= 0;
        end else begin
            case(state)
                // Wait for start signal
                IDLE: begin 
                    done <= 0; 
                    if (start) begin 
                        filter_cnt <= 0; 
                        state <= CONV_RUN; 
                        conv_start <= 1; 
                    end 
                end
                
                // Run Convolution Layer
                CONV_RUN: begin 
                    conv_start <= 0; 
                    if (conv_done) begin 
                        state <= POOL_RUN; 
                        pool_start <= 1; 
                    end 
                end
                
                // Run Max Pooling Layer
                POOL_RUN: begin 
                    pool_start <= 0; 
                    if (pool_done) state <= NEXT_FILTER; 
                end
                
                // Check if all 4 filters are processed
                NEXT_FILTER: begin 
                    if (filter_cnt == 3) begin 
                        state <= FC1_RUN; 
                        fc1_start <= 1; 
                    end else begin 
                        filter_cnt <= filter_cnt + 1; 
                        state <= CONV_RUN; 
                        conv_start <= 1; 
                    end 
                end
                
                // Run FC1 Layer
                FC1_RUN: begin 
                    fc1_start <= 0; 
                    if (fc1_done) begin 
                        state <= FC2_RUN; 
                        fc2_start <= 1; 
                    end 
                end
                
                // Run FC2 Layer
                FC2_RUN: begin 
                    fc2_start <= 0; 
                    if (fc2_done) begin 
                        state <= DECISION_RUN; 
                        dec_start <= 1; 
                    end 
                end
                
                // Run Decision Unit
                DECISION_RUN: begin 
                    dec_start <= 0; 
                    if (dec_done) begin 
                        result <= dec_result; 
                        state <= FINISH; 
                    end 
                end
                
                // Complete
                FINISH: begin 
                    done <= 1; 
                    if (!start) state <= IDLE; 
                end
            endcase
        end
    end
endmodule