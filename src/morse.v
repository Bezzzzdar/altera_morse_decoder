module morse(
    input wire clk,              // Тактовый сигнал
    input wire reset,            // Сброс
    input wire morse_in,         // Ввод
    output reg [7:0] ascii_char, // Декодированный ASCII символ
    output reg char_valid,       // Флаг валидности символа
    output reg button_pressed    // Индикация нажатия кнопки
);

/* Параметры временных интервалов (в тактах)
 * 
 * Настройка длительности точки, тире и пробелов
 *      между символами и словами
 *  
 * 1 такт = 20 нс при тактовой частоте 50 МГц
 *
 */
parameter DOT_TIME       = 50000000;   // 1 секунда
parameter DASH_TIME      = 2 * DOT_TIME;  // 2 секунды
parameter SYMBOL_SPACE   = 2 * DOT_TIME;  // 2 секунды
parameter WORD_SPACE     = 4 * DOT_TIME;  // 4 секунды

// Регистры для приёма
reg [4:0] received_pattern;
reg [2:0] received_length;

// Таймеры
reg [31:0] timer;
reg [31:0] space_timer;

// Регистры для управления состоянием
reg last_morse_in;

/*  Память для хранения кодов Морзе (1 = тире, 0 = точка)
 *  
 *  Адрес: 6 бит (64 символа)
 *  Данные: 3 бита длины + 5 битов паттерн
 *
 */
reg [7:0] morse_rom [0:36];

initial begin
    // БУКВЫ (A-Z)
    morse_rom[0]  = {3'd2, 5'b00001}; // A .-  
    morse_rom[1]  = {3'd4, 5'b10000}; // B -...
    morse_rom[2]  = {3'd4, 5'b10100}; // C -.-.
    morse_rom[3]  = {3'd3, 5'b10000}; // D -.. 
    morse_rom[4]  = {3'd1, 5'b00000}; // E .   
    morse_rom[5]  = {3'd4, 5'b00100}; // F ..-.
    morse_rom[6]  = {3'd3, 5'b11000}; // G --. 
    morse_rom[7]  = {3'd4, 5'b00000}; // H ....
    morse_rom[8]  = {3'd2, 5'b00000}; // I ..  
    morse_rom[9]  = {3'd4, 5'b01111}; // J .---
    morse_rom[10] = {3'd3, 5'b10100}; // K -.- 
    morse_rom[11] = {3'd4, 5'b01000}; // L .-..
    morse_rom[12] = {3'd2, 5'b11000}; // M --  
    morse_rom[13] = {3'd2, 5'b10000}; // N -.  
    morse_rom[14] = {3'd3, 5'b11100}; // O --- 
    morse_rom[15] = {3'd4, 5'b01100}; // P .--.
    morse_rom[16] = {3'd4, 5'b11011}; // Q --.-
    morse_rom[17] = {3'd3, 5'b01000}; // R .-. 
    morse_rom[18] = {3'd3, 5'b00000}; // S ... 
    morse_rom[19] = {3'd1, 5'b10000}; // T -   
    morse_rom[20] = {3'd3, 5'b00100}; // U ..- 
    morse_rom[21] = {3'd4, 5'b00001}; // V ...-
    morse_rom[22] = {3'd3, 5'b01100}; // W .-- 
    morse_rom[23] = {3'd4, 5'b10011}; // X -..-
    morse_rom[24] = {3'd4, 5'b10111}; // Y -.--
    morse_rom[25] = {3'd4, 5'b11000}; // Z --..

    // ЦИФРЫ (0-9)
    morse_rom[26] = {3'd5, 5'b11111}; // 0 -----
    morse_rom[27] = {3'd5, 5'b01111}; // 1 .----
    morse_rom[28] = {3'd5, 5'b00111}; // 2 ..---
    morse_rom[29] = {3'd5, 5'b00011}; // 3 ...--
    morse_rom[30] = {3'd5, 5'b00001}; // 4 ....-
    morse_rom[31] = {3'd5, 5'b00000}; // 5 .....
    morse_rom[32] = {3'd5, 5'b10000}; // 6 -....
    morse_rom[33] = {3'd5, 5'b11000}; // 7 --...
    morse_rom[34] = {3'd5, 5'b11100}; // 8 ---..
    morse_rom[35] = {3'd5, 5'b11110}; // 9 ----.
end

function [7:0] find_ascii_symbol;
    input [4:0] pattern;
    input [2:0] length;
    integer i;
    reg found;
    begin
        find_ascii_symbol = "?"; // По умолчанию - неизвестный символ
        found = 0;
        for (i = 0; i < 36 && !found; i = i + 1) begin
            if ((morse_rom[i][7:5] == length) && 
                (morse_rom[i][4:0] == (pattern << (5 - length)))) begin
                found = 1;
                if (i < 26) begin
                    find_ascii_symbol = "A" + i; // Буквы A-Z
                end else begin
                    find_ascii_symbol = "0" + (i - 26); // Цифры 0-9
                end
            end
        end
    end
endfunction

// Автомат состояний
reg [2:0] state;
localparam IDLE       = 3'd0;
localparam RECEIVING  = 3'd1;
localparam SYMBOL_END = 3'd2;
localparam LETTER_END = 3'd3;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        timer <= 0;
        space_timer <= 0;
        received_pattern <= 5'b0;
        received_length <= 3'b0;
        last_morse_in <= 0;
        ascii_char <= " ";
        char_valid <= 0;
        button_pressed <= 0;
    end else begin
        last_morse_in <= morse_in;
        char_valid <= 0; // По умолчанию флаг сброшен
        
        // Индикация нажатия кнопки (активна, когда morse_in = 1)
        button_pressed <= morse_in;
        
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
                ascii_char <= find_ascii_symbol(received_pattern, received_length);
                char_valid <= 1'b1; // Устанавливаем флаг валидности
                
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