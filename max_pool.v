`timescale 1ns / 1ps

module max_pool(
    input wire clk,
    input wire rst,
    input wire start,
    
    // --- GİRİŞ (Conv Katmanından Okuma) ---
    output reg [9:0] rd_addr, 
    input wire [7:0] rd_data, 
    
    // --- ÇIKIŞ (Bir sonraki Flatten/FC1 belleğine yazma) ---
    output reg [7:0] data_out,
    output reg valid_out,
    output reg done
);

    parameter IN_DIM = 26;
    parameter OUT_DIM = 13;

    localparam IDLE=0, READ_0=1, WAIT_1=2, READ_1=3, WAIT_2=4, READ_2=5, WAIT_3=6, READ_3=7, SAVE_LAST=8, FIND_MAX=9, OUTPUT=10, NEXT=11, FINISH=12;
    reg [3:0] state;
    
    reg [4:0] row, col; 
    reg [7:0] val0, val1, val2, val3; 
    reg [7:0] max_val;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            row <= 0; col <= 0;
            valid_out <= 0; done <= 0;
            rd_addr <= 0; val0<=0; val1<=0; val2<=0; val3<=0; max_val<=0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0; valid_out <= 0;
                    if (start) begin
                        // --- KRİTİK DÜZELTME: SAYAÇLARI SIFIRLA ---
                        // Bunu yapmazsan sadece ilk filtre çalışır, diğerleri çöp olur!
                        row <= 0; col <= 0; 
                        state <= READ_0;
                    end
                end
                
                // --- 1. Pikseli İste (Sol Üst) ---
                READ_0: begin
                    rd_addr <= (row * 2) * IN_DIM + (col * 2);
                    state <= WAIT_1; 
                end
                WAIT_1: state <= READ_1; 
                
                // --- 2. Pikseli İste (Sağ Üst) ---
                READ_1: begin
                    val0 <= rd_data; 
                    rd_addr <= (row * 2) * IN_DIM + (col * 2 + 1);
                    state <= WAIT_2;
                end
                WAIT_2: state <= READ_2;

                // --- 3. Pikseli İste (Sol Alt) ---
                READ_2: begin
                    val1 <= rd_data; 
                    rd_addr <= (row * 2 + 1) * IN_DIM + (col * 2);
                    state <= WAIT_3;
                end
                WAIT_3: state <= READ_3;

                // --- 4. Pikseli İste (Sağ Alt) ---
                READ_3: begin
                    val2 <= rd_data; 
                    rd_addr <= (row * 2 + 1) * IN_DIM + (col * 2 + 1);
                    state <= SAVE_LAST;
                end

                SAVE_LAST: begin
                    val3 <= rd_data; 
                    state <= FIND_MAX;
                end
                
                FIND_MAX: begin
                    if (val0 >= val1 && val0 >= val2 && val0 >= val3) max_val <= val0;
                    else if (val1 >= val0 && val1 >= val2 && val1 >= val3) max_val <= val1;
                    else if (val2 >= val0 && val2 >= val1 && val2 >= val3) max_val <= val2;
                    else max_val <= val3;
                    
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    data_out <= max_val; 
                    valid_out <= 1;
                    state <= NEXT;
                end

                NEXT: begin
                    valid_out <= 0;
                    if (col == OUT_DIM - 1) begin
                        col <= 0;
                        if (row == OUT_DIM - 1) begin
                            state <= FINISH;
                        end else begin
                            row <= row + 1;
                            state <= READ_0;
                        end
                    end else begin
                        col <= col + 1;
                        state <= READ_0;
                    end
                end

                FINISH: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule