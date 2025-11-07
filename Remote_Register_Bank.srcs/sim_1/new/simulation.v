`timescale 1ns / 1ps

module tb_uart_reg_bank_top;

    // 12MHz 클럭 (83.333ns)
    localparam CLK_PERIOD = 83.333;
    
    // 9600 Baud (104,167ns 또는 104.167us)
    localparam BIT_PERIOD = 104167; 
    
    // DUT 신호
    reg  clk = 0;
    reg  uart_rx_tb = 1'b1; // TB가 DUT로 보내는 신호 (IDLE=1)
    wire uart_tx_tb;       // DUT가 TB로 보내는 신호

    // DUT (Device Under Test) 인스턴스화
    uart_reg_bank_top u_dut (
        .clk(clk),
        .uart_rx(uart_rx_tb),
        .uart_tx(uart_tx_tb)
    );
    
    // 1. 클럭 생성기
    always #(CLK_PERIOD / 2) clk = ~clk;

    // 2. UART 바이트 전송 태스크 (Tera Term 시뮬레이션)
    //    지정된 8비트 데이터를 직렬로 쏴줍니다.
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start Bit (1비트 시간)
            uart_rx_tb <= 1'b0;
            #(BIT_PERIOD);
            
            // 8 Data Bits (LSB부터 전송)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_tb <= data[i];
                #(BIT_PERIOD);
            end
            
            // Stop Bit (1비트 시간)
            uart_rx_tb <= 1'b1;
            #(BIT_PERIOD);
            
            // IDLE
            uart_rx_tb <= 1'b1;
        end
    endtask

    // 3. 테스트 시퀀스
    initial begin
        $display("------------------------------------");
        $display("시뮬레이션 시작: 레지스터 뱅크 테스트");
        
        #(BIT_PERIOD * 5); // 시스템 안정화 대기
        
        // 테스트 1: 주소 1번에 0xAA 쓰기
        $display("[%0t ns] 테스트 1: 주소 1번에 0xAA 쓰기", $time);
        send_byte(8'h01); // 주소 (쓰기)
        send_byte(8'hAA); // 데이터
        
        // 응답(0xF0)을 기다리고, 다음 명령을 위해 잠시 대기
        #(BIT_PERIOD * 20); 
        
        // 테스트 2: 주소 1번에서 읽기
        $display("[%0t ns] 테스트 2: 주소 1번 읽기", $time);
        send_byte(8'h81); // 주소 (읽기)
        
        // 응답(0xAA)을 기다리고, 다음 명령을 위해 잠시 대기
        #(BIT_PERIOD * 20);
        
        // 테스트 3: 주소 3번에 0x12 쓰기
        $display("[%0t ns] 테스트 3: 주소 3번에 0x12 쓰기", $time);
        send_byte(8'h03); // 주소 (쓰기)
        send_byte(8'h12); // 데이터

        #(BIT_PERIOD * 20); 
        
        // 테스트 4: 주소 3번에서 읽기
        $display("[%0t ns] 테스트 4: 주소 3번 읽기", $time);
        send_byte(8'h83); // 주소 (읽기)

        #(BIT_PERIOD * 20);
        
        $display("[%0t ns] 테스트 완료. 웨이브폼을 확인하세요.", $time);
        $stop;
    end

endmodule