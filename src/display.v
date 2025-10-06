module display(
    input wire clk,                    // Тактовый сигнал
    input wire reset,                  // Сброс
    input wire [7:0] ascii_char,       // ASCII символ из модуля morse
    input wire char_valid,             // Флаг валидности символа
    output reg [6:0] HEX0,             // 7-сегментный индикатор 0
    output reg [6:0] HEX1,             // 7-сегментный индикатор 1
    output reg [6:0] HEX2,             // 7-сегментный индикатор 2
    output reg [6:0] HEX3,             // 7-сегментный индикатор 3
    output reg [6:0] HEX4,             // 7-сегментный индикатор 4
    output reg [6:0] HEX5              // 7-сегментный индикатор 5
);

// Регистры для хранения символов (буфер на 6 символов)
reg [7:0] display_buffer [0:5];
reg [2:0] buffer_index;

// Функция для преобразования символа в 7-сегментный код
function [6:0] ascii_to_7seg;
    input [7:0] ascii;
    begin
        case (ascii)
            // Цифры
            "0": ascii_to_7seg = 7'b1000000;
            "1": ascii_to_7seg = 7'b1111001;
            "2": ascii_to_7seg = 7'b0100100;
            "3": ascii_to_7seg = 7'b0110000;
            "4": ascii_to_7seg = 7'b0011001;
            "5": ascii_to_7seg = 7'b0010010;
            "6": ascii_to_7seg = 7'b0000010;
            "7": ascii_to_7seg = 7'b1111000;
            "8": ascii_to_7seg = 7'b0000000;
            "9": ascii_to_7seg = 7'b0010000;
            
            // Буквы A-Z
            "A": ascii_to_7seg = 7'b0001000;
            "B": ascii_to_7seg = 7'b0000011;
            "C": ascii_to_7seg = 7'b1000110;
            "D": ascii_to_7seg = 7'b0100001;
            "E": ascii_to_7seg = 7'b0000110;
            "F": ascii_to_7seg = 7'b0001110;
            "G": ascii_to_7seg = 7'b1000010;
            "H": ascii_to_7seg = 7'b0001011;
            "I": ascii_to_7seg = 7'b1001111;
            "J": ascii_to_7seg = 7'b1100001;
            "K": ascii_to_7seg = 7'b0001010;
            "L": ascii_to_7seg = 7'b1000111;
            "M": ascii_to_7seg = 7'b0101010;
            "N": ascii_to_7seg = 7'b0101011;
            "O": ascii_to_7seg = 7'b0100011;
            "P": ascii_to_7seg = 7'b0001100;
            "Q": ascii_to_7seg = 7'b0011000;
            "R": ascii_to_7seg = 7'b0101111;
            "S": ascii_to_7seg = 7'b0010010;
            "T": ascii_to_7seg = 7'b0000111;
            "U": ascii_to_7seg = 7'b1000001;
            "V": ascii_to_7seg = 7'b1001001;
            "W": ascii_to_7seg = 7'b1010101;
            "X": ascii_to_7seg = 7'b0001001;
            "Y": ascii_to_7seg = 7'b0010001;
            "Z": ascii_to_7seg = 7'b0100100;
            
            // Пробел и специальные символы
            " ": ascii_to_7seg = 7'b1111111;  // Выключен
            "?": ascii_to_7seg = 7'b1010010;  // Вопросительный знак
            "!": ascii_to_7seg = 7'b1110001;  // Восклицательный знак
            "-": ascii_to_7seg = 7'b1111110;  // Дефис
            ".": ascii_to_7seg = 7'b1101110;  // Точка
            
            default: ascii_to_7seg = 7'b0111111;  // Тире для неизвестных
        endcase
    end
endfunction

// Инициализация
initial begin
    buffer_index = 0;
    HEX0 = 7'b1111111;
    HEX1 = 7'b1111111;
    HEX2 = 7'b1111111;
    HEX3 = 7'b1111111;
    HEX4 = 7'b1111111;
    HEX5 = 7'b1111111;
    
    // Инициализация буфера пробелами
    display_buffer[0] = " ";
    display_buffer[1] = " ";
    display_buffer[2] = " ";
    display_buffer[3] = " ";
    display_buffer[4] = " ";
    display_buffer[5] = " ";
end

// Основной процесс отображения
always @(posedge clk or posedge reset) begin
    if (reset) begin
        // Сброс буфера и индикаторов
        buffer_index 	  <= 0;
        display_buffer[0] <= " ";
        display_buffer[1] <= " ";
        display_buffer[2] <= " ";
        display_buffer[3] <= " ";
        display_buffer[4] <= " ";
        display_buffer[5] <= " ";
        
        HEX0 <= 7'b1111111;
        HEX1 <= 7'b1111111;
        HEX2 <= 7'b1111111;
        HEX3 <= 7'b1111111;
        HEX4 <= 7'b1111111;
        HEX5 <= 7'b1111111;
    end else begin
        // Обработка нового символа
        if (char_valid) begin
            // Добавляем символ в буфер
            display_buffer[buffer_index] <= ascii_char;
            
            // Увеличиваем индекс (с циклическим переполнением)
            if (buffer_index == 3'd5)
                buffer_index <= 0;
            else
                buffer_index <= buffer_index + 1;
        end
        
        // Постоянное обновление дисплея
        HEX0 <= ascii_to_7seg(display_buffer[0]);
        HEX1 <= ascii_to_7seg(display_buffer[1]);
        HEX2 <= ascii_to_7seg(display_buffer[2]);
        HEX3 <= ascii_to_7seg(display_buffer[3]);
        HEX4 <= ascii_to_7seg(display_buffer[4]);
        HEX5 <= ascii_to_7seg(display_buffer[5]);
    end
end

endmodule