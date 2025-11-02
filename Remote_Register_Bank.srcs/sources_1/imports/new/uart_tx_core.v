`timescale 1ns / 1ps
//==============================================================================
// Module: uart_tx_core
// 역할: 'i_tx_start' 펄스가 켜지면, 'i_data_to_send'의 8비트 데이터를 UART로 송신합니다.
//==============================================================================
module uart_tx_core (
    input  wire       clk,            // 12MHz 시스템 클럭
    input  wire       i_tx_start,     // 1클럭의 '전송 시작' 펄스
    input  wire [7:0] i_data_to_send, // 전송할 8비트 데이터
    output wire       o_uart_tx       // UART 송신(Tx) 핀
);

    // 1. Baud Rate 생성기용 상수
    parameter BAUD_TICK_COUNT = 1250; // 12MHz / 9600

    // 2. FSM 상태 정의
    localparam S_IDLE      = 2'b00;
    localparam S_START_BIT = 2'b01;
    localparam S_DATA_BITS = 2'b10;
    localparam S_STOP_BIT  = 2'b11;

    reg [1:0] state = S_IDLE;

    // 3. 내부 레지스터
    reg [11:0] baud_counter = 0; // 0 ~ 1249
    reg [2:0]  bit_index = 0;    // 0 ~ 7
    reg [7:0]  tx_data_buffer = 0; // 전송할 데이터를 저장할 버퍼
    reg        tx_active = 0; // 전송 중 신호 (IDLE=0, 전송=1)
    reg        o_uart_tx_reg = 1'b1; // Tx 핀 출력 레지스터 (IDLE=1)

    assign o_uart_tx = o_uart_tx_reg;

    // 4. Baud 카운터 로직
    always @(posedge clk) begin
        if (tx_active) begin
            if (baud_counter == (BAUD_TICK_COUNT - 1))
                baud_counter <= 0;
            else
                baud_counter <= baud_counter + 1;
        end else begin
            baud_counter <= 0;
        end
    end

    // 1 baud tick 감지
    wire baud_tick = (baud_counter == (BAUD_TICK_COUNT - 1));

    // 5. FSM 상태 머신
    always @(posedge clk) begin
        case (state)
            S_IDLE: begin
                o_uart_tx_reg <= 1'b1; // IDLE은 '1'
                tx_active <= 0;
                bit_index <= 0;
                
                // 'i_tx_start' 펄스를 감지하면
                if (i_tx_start) begin
                    tx_data_buffer <= i_data_to_send; // 전송할 데이터 *저장*
                    tx_active <= 1;
                    state <= S_START_BIT;
                end
            end

            S_START_BIT: begin
                o_uart_tx_reg <= 1'b0; // Start Bit는 '0'
                if (baud_tick) begin
                    state <= S_DATA_BITS;
                end
            end

            S_DATA_BITS: begin
                o_uart_tx_reg <= tx_data_buffer[bit_index]; // LSB부터 전송
                if (baud_tick) begin
                    if (bit_index == 3'd7) begin
                        state <= S_STOP_BIT;
                    end else begin
                        bit_index <= bit_index + 1;
                    end
                end
            end

            S_STOP_BIT: begin
                o_uart_tx_reg <= 1'b1; // Stop Bit는 '1'
                if (baud_tick) begin
                    state <= S_IDLE;
                end
            end
            
            default:
                state <= S_IDLE;
        endcase
    end

endmodule