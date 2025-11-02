`timescale 1ns / 1ps
//==============================================================================
// Module: uart_rx_core
// 역할: UART 신호를 수신하여 8비트 데이터와 1클럭의 '수신 완료' 펄스를 출력합니다.
// (Project 6의 uart_rx에서 LED 로직을 제거하고 모듈화한 버전)
//==============================================================================
module uart_rx_core (
    input  wire       clk,            // 12MHz 시스템 클럭
    input  wire       uart_rx,        // PC로부터의 UART 수신 핀
    output reg [7:0]  o_received_data,// 수신된 8비트 데이터
    output reg        o_data_valid    // 1클럭 동안 켜지는 '수신 완료' 펄스
);

    // 1. Baud Rate 생성기용 상수
    parameter BAUD_TICK_COUNT = 1250;
    parameter HALF_TICK_COUNT = (BAUD_TICK_COUNT / 2) - 1;

    // 2. 입력 동기화기
    reg uart_rx_meta;
    reg uart_rx_sync;
    always @(posedge clk) begin
        uart_rx_meta <= uart_rx;
        uart_rx_sync <= uart_rx_meta;
    end

    // 3. 엣지 검출기
    reg uart_rx_sync_d1;
    wire start_pulse;
    always @(posedge clk) begin
        uart_rx_sync_d1 <= uart_rx_sync;
    end
    assign start_pulse = (uart_rx_sync_d1 == 1'b1) && (uart_rx_sync == 1'b0);

    // 4. UART 수신기 FSM
    parameter S_IDLE         = 2'b00;
    parameter S_CHECK_START  = 2'b01;
    parameter S_RECEIVE_DATA = 2'b10;
    parameter S_CHECK_STOP   = 2'b11;

    reg [1:0] state = S_IDLE;
    reg [11:0] baud_counter = 0;
    reg [2:0]  bit_index = 0;
    reg [7:0]  received_data_buffer = 0; // 내부 버퍼
    reg        counter_enable = 0;
    
    wire half_tick = (baud_counter == HALF_TICK_COUNT);
    wire full_tick = (baud_counter == (BAUD_TICK_COUNT - 1));

    // Baud 카운터 로직
    always @(posedge clk) begin
        if (counter_enable) begin
            if (full_tick)
                baud_counter <= 0;
            else
                baud_counter <= baud_counter + 1;
        end else begin
            baud_counter <= 0;
        end
    end

    // FSM 상태 머신
    always @(posedge clk) begin
        // o_data_valid는 기본적으로 0이고, 딱 1클럭만 1이 됩니다.
        //래치가 발생하는지 확인해보기!
        o_data_valid <= 0; 

        case (state)
            S_IDLE: begin
                counter_enable <= 0;
                bit_index <= 0;
                if (start_pulse) begin
                    counter_enable <= 1;
                    state <= S_CHECK_START;
                end
            end

            S_CHECK_START: begin
                if (half_tick) begin
                    if (uart_rx_sync == 1'b0) begin 
                        state <= S_RECEIVE_DATA;
                    end else begin
                        counter_enable <= 0;
                        state <= S_IDLE;
                    end
                end
            end

            S_RECEIVE_DATA: begin
                if (half_tick) begin 
                    received_data_buffer[bit_index] <= uart_rx_sync;
                    if (bit_index == 3'd7) begin
                        state <= S_CHECK_STOP;
                    end else begin
                        bit_index <= bit_index + 1;
                    end
                end
            end

            S_CHECK_STOP: begin
                if (half_tick) begin
                    counter_enable <= 0;
                    state <= S_IDLE;
                    
                    // Stop Bit가 '1'이면 (정상 수신)
                    if (uart_rx_sync == 1'b1) begin
                        o_received_data <= received_data_buffer; // 출력 업데이트
                        o_data_valid    <= 1'b1; // "수신 완료" 펄스 켜기
                    end
                    // (오류가 나면 data_valid가 0이므로 상위 모듈은 무시함)
                end
            end
            
            default: begin
                state <= S_IDLE;
                counter_enable <= 0;
            end
        endcase
    end
endmodule