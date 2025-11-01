`timescale 1ns / 1ps
//==============================================================================
// Top Module: uart_reg_bank_top
// 역할: UART 명령을 해석하여, 4개의 내부 레지스터(메모리)에 값을 쓰거나 읽습니다.
//==============================================================================
module uart_reg_bank_top (
    input  wire       clk,        // 12MHz 시스템 클럭
    input  wire       uart_rx,    // PC로부터의 UART 수신 핀
    output wire       uart_tx     // PC로의 UART 송신 핀
);

    // 1. RX/TX 모듈 연결용 신호
    wire [7:0] rx_data;
    wire       rx_data_valid;

    // 2. TX 모듈 제어용 신호 (FSM이 TX 모듈에게 보낼 명령)
    reg        tx_start = 0;
    reg  [7:0] tx_data = 0;

    // 3. 내부 메모리 (레지스터 뱅크)
    // TODO: 8비트 저장 공간 4개 (주소 0, 1, 2, 3)를 가진 배열 레지스터를 선언하세요.
    reg [7:0] register_bank [0:3];

    // 4. 모듈 인스턴스화
    uart_rx_core u_rx (
        .clk(clk),
        .uart_rx(uart_rx),
        .o_received_data(rx_data),
        .o_data_valid(rx_data_valid)
    );

    uart_tx_core u_tx (
        .clk(clk),
        .i_tx_start(tx_start),
        .i_data_to_send(tx_data),
        .o_uart_tx(uart_tx)
    );

    // 5. 명령어 해석 FSM (핵심)
    
    // FSM 상태 정의
    localparam S_IDLE       = 1'b0; // 명령 대기 (첫 바이트)
    localparam S_WAIT_DATA  = 1'b1; // 쓰기 명령 수신, 데이터 대기 (두 번째 바이트)

    reg state = S_IDLE;
    reg [1:0] write_addr_buffer; // 쓰기 주소를 임시 저장할 버퍼

    // FSM 로직
    always @(posedge clk) begin
        
        // TX 시작 펄스는 기본적으로 0 (1클럭만 1이 됨)
        tx_start <= 0;

        if (rx_data_valid) begin // UART로 1바이트가 수신되면
            
            case (state)
                
                // S_IDLE: 첫 번째 바이트(명령)를 기다리는 상태
                S_IDLE: begin
                    // TODO: rx_data[7] (MSB) 비트를 확인하여 '읽기'/'쓰기' 명령을 구분하세요.
                    
                    if (rx_data[7] == 1'b1) begin // '읽기' 명령 (예: 8'h81)
                        // TODO: (해답)
                        // 1. rx_data의 하위 2비트 (rx_data[1:0])를 주소로 사용합니다.
                        // 2. register_bank[주소]에서 데이터를 읽어옵니다.
                        // 3. tx_data에 읽어온 데이터를 할당합니다.
                        // 4. tx_start를 1로 설정하여 응답을 보냅니다.
                        // 5. state는 S_IDLE을 유지합니다. (다음 명령 대기)
                        tx_data <= register_bank[rx_data[1:0]];
                        tx_start <= 1'b1;
                        state <= S_IDLE;
                        
                    end else begin // '쓰기' 명령 (예: 8'h01)
                        // TODO: (해답)
                        // 1. rx_data의 하위 2비트 (rx_data[1:0])를 "쓰기 주소"로 저장합니다.
                        //    (write_addr_buffer 사용)
                        // 2. state를 S_WAIT_DATA로 변경합니다. (데이터 바이트 대기)
                        write_addr_buffer <= rx_data[1:0];
                        state <= S_WAIT_DATA;
                        
                    end
                end

                // S_WAIT_DATA: 두 번째 바이트(데이터)를 기다리는 상태
                S_WAIT_DATA: begin
                    // TODO: (해답)
                    // 1. 방금 수신된 rx_data(이것이 실제 데이터)를
                    //    이전에 저장해둔 write_addr_buffer[주소]에 씁니다.
                    //    (register_bank[write_addr_buffer] <= rx_data;)
                    // 2. 응답으로 "OK" (8'hF0)를 보냅니다.
                    //    (tx_data <= 8'hF0; tx_start <= 1'b1;)
                    // 3. state를 S_IDLE로 복귀시킵니다. (다음 명령 대기)
                    register_bank[write_addr_buffer] <= rx_data;
                    tx_data <= 8'hF0; // "OK" 응답
                    tx_start <= 1'b1;
                    state <= S_IDLE;
                    
                end

            endcase
        end
    end

endmodule