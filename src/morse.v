module morse(
    input wire reset,
    input wire morse_in,
    output reg [6:0] segment
);

// Параметры временных интервалов (в тактах)
parameter DOT_TIME       = 1000000;
parameter DASH_TIME      = 3 * DOT_TIME;
parameter SYMBOL_SPACE   = 3 * DOT_TIME;
parameter WORD_SPACE     = 7 * DOT_TIME;

// Регистры для приёма
reg [4:0] received_pattern;
reg [2:0] received_length;

// Таймеры
reg [31:0] timer;
reg [31:0] space_timer;

// Регистры для управления состоянием
reg last_morse_in;
reg [7:0] current_ascii;

function [6:0] decode_7seg;
    input [3:0] digit;
    begin
        case (digit)
            4'h0: decode_7seg = 7'b1000000; // 0
            4'h1: decode_7seg = 7'b1111001; // 1
            4'h2: decode_7seg = 7'b0100100; // 2
            4'h3: decode_7seg = 7'b0110000; // 3
            4'h4: decode_7seg = 7'b0011001; // 4
            4'h5: decode_7seg = 7'b0010010; // 5
            4'h6: decode_7seg = 7'b0000010; // 6
            4'h7: decode_7seg = 7'b1111001; // 7
            4'h8: decode_7seg = 7'b0000000; // 8
            4'h9: decode_7seg = 7'b0010000; // 9
            4'ha: decode_7seg = 7'b0001000; // A
            4'hb: decode_7seg = 7'b0000011; // b
            4'hc: decode_7seg = 7'b1000110; // C
            4'hd: decode_7seg = 7'b0100001; // d
            4'he: decode_7seg = 7'b0000110; // E
            4'hf: decode_7seg = 7'b0001110; // F
            default: decode_7seg = 7'b1111111;
        endcase
    end
endfunction

/*  Память для хранения кодов Морзе (1 = тире, 0 = точка)
 *  
 *  Адрес: 6 бит (64 символа)
 *  Данные: 3 бита длины + 5 битов паттерн
 *
 */
reg [7:0] morse_rom [0:36];

initial begin
    morse_rom[0]	= {3'd2, 5'b00101}; // A .-
    morse_rom[1]  = {3'd4, 5'b11000}; // B -...
    morse_rom[2]  = {3'd4, 5'b11010}; // C -.-.
    morse_rom[3]  = {3'd3, 5'b01100}; // D -..
    morse_rom[4]  = {3'd1, 5'b00010}; // E .
    morse_rom[5]  = {3'd4, 5'b10010}; // F ..-.
    morse_rom[6]  = {3'd3, 5'b01110}; // G --.
    morse_rom[7]  = {3'd4, 5'b10000}; // H ....
    morse_rom[8]  = {3'd2, 5'b00100}; // I ..
    morse_rom[9]  = {3'd4, 5'b10111}; // J .---
    morse_rom[10] = {3'd3, 5'b01101}; // K -.-
    morse_rom[11] = {3'd4, 5'b10100}; // L .-..
    morse_rom[12] = {3'd2, 5'b00111}; // M --
    morse_rom[13] = {3'd2, 5'b00110}; // N -.
    morse_rom[14] = {3'd3, 5'b01111}; // O ---
    morse_rom[15] = {3'd4, 5'b10110}; // P .--.
    morse_rom[16] = {3'd4, 5'b11011}; // Q --.-
    morse_rom[17] = {3'd3, 5'b01010}; // R .-.
    morse_rom[18] = {3'd3, 5'b01000}; // S ...
    morse_rom[19] = {3'd1, 5'b00011}; // T -
    morse_rom[20] = {3'd3, 5'b01001}; // U ..-
    morse_rom[21] = {3'd4, 5'b10001}; // V ...-
    morse_rom[22] = {3'd3, 5'b01011}; // W .--
    morse_rom[23] = {3'd4, 5'b11001}; // X -..-
    morse_rom[24] = {3'd4, 5'b11101}; // Y -.--
    morse_rom[25] = {3'd4, 5'b11010}; // Z --..

    morse_rom[26] = {3'd5, 5'b11111};  // 0 -----
    morse_rom[27] = {3'd5, 5'b01111};  // 1 .----
    morse_rom[28] = {3'd5, 5'b00111};  // 2 ..---
    morse_rom[29] = {3'd5, 5'b00011};  // 3 ...--
    morse_rom[30] = {3'd5, 5'b00001};  // 4 ....-
    morse_rom[31] = {3'd5, 5'b00000};  // 5 .....
    morse_rom[32] = {3'd5, 5'b10000};  // 6 -....
    morse_rom[33] = {3'd5, 5'b11000};  // 7 --...
    morse_rom[34] = {3'd5, 5'b11100};  // 8 ---..
    morse_rom[35] = {3'd5, 5'b11110};  // 9 ----.
end

function [7:0] find_ascii_symbol;
    input [4:0] pattern;
    input [2:0] length;
    integer i;
    reg found;
    begin
        find_ascii_symbol = "?";
        found = 0;
        for (i = 0; i < 36 && !found; i = i + 1) begin
            if ((morse_rom[i][7:5] == length) && (morse_rom[i][4:0] >> (5 - length) == pattern)) begin
                found = 1;
                if (i < 26) begin
                    find_ascii_symbol = "A" + i;
                end else begin
                    find_ascii_symbol = "0" + (i - 26);
                end
            end
        end
    end
endfunction

// Автомат состояний
reg [2:0] state;
localparam IDLE           = 3'd0;
localparam RECEIVING      = 3'd1;
localparam SYMBOL_END     = 3'd2;
localparam LETTER_END     = 3'd3;
localparam WORD_END       = 3'd4; 

always @(*) begin
    if (reset) begin
        state <= IDLE;
        timer <= 0;
        space_timer <= 0;
        received_pattern <= 5'b0;
        received_length <= 3'b0;
        segment <= 7'b1111111;
        last_morse_in <= 0;
        current_ascii <= " ";
    end else begin
        last_morse_in <= morse_in;
        
        case(state)
            IDLE: begin
                timer <= 0;
                space_timer <= 0;
                if (morse_in && !last_morse_in) begin
                    // Начало приема символа
                    state <= RECEIVING;
                    received_pattern <= 5'b0;
                    received_length <= 3'b0;
                end else if (!morse_in) begin
                    space_timer <= space_timer + 1;
                    if (space_timer >= WORD_SPACE) begin
                        // Длинная пауза - конец слова
                        segment <= 7'b1111111; // Гасим индикатор
                    end
                end
            end
            
            RECEIVING: begin
                timer <= timer + 1;
                space_timer <= 0;
                
                if (!morse_in && last_morse_in) begin
                    // Конец точки/тире
                    if (timer >= DASH_TIME) begin
                        // Тире
                        received_pattern <= {received_pattern[3:0], 1'b1};
                    end else begin
                        // Точка
                        received_pattern <= {received_pattern[3:0], 1'b0};
                    end
                    received_length <= received_length + 1;
                    state <= SYMBOL_END;
                    timer <= 0;
                end
            end
            
            SYMBOL_END: begin
                timer <= 0;
                space_timer <= space_timer + 1;
                
                if (morse_in && !last_morse_in) begin
                    // Начало следующего элемента символа
                    state <= RECEIVING;
                end else if (space_timer >= SYMBOL_SPACE) begin
                    // Пауза достаточна для конца символа
                    state <= LETTER_END;
                end
            end
            
            LETTER_END: begin
                // Декодируем символ
                current_ascii <= find_ascii_symbol(received_pattern, received_length);
                
                // Отображаем на 7-сегментном индикаторе
                if (current_ascii >= "0" && current_ascii <= "9") begin
                    segment <= decode_7seg(current_ascii - "0");
                end else if (current_ascii >= "A" && current_ascii <= "F") begin
                    segment <= decode_7seg(current_ascii - "A" + 4'ha);
                end else begin
                    segment <= 7'b1111111; // Неизвестный символ
                end
                
                state <= IDLE;
                space_timer <= 0;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule