module morse #(
    parameter DOT_TIME   = 25_000_000,   // 0.5 секунды
    parameter DASH_TIME  = 75_000_000,   // 1.5 секунды
    parameter SYMBOL_GAP = 25_000_000,   // 0.5 секунды между точками/тире
    parameter LETTER_GAP = 125_000_000   // 2.5 секунды между буквами
)(
    input clk,
    input reset_stable,
    input morse_stable,
    output reg [7:0] output_buffer
);

    // ------------------------------
    // Счетчики и флаги
    // ------------------------------
    reg [31:0] press_counter;
    reg [31:0] release_counter;
    reg [4:0] morse_pattern;     // 5 бит для паттерна
    reg [2:0] morse_length;      // длина символа до 5
    reg decoding;
    reg morse_prev_stable;

    // ------------------------------
    // Память Морзе
    // ------------------------------
    reg [7:0] morse_memory [0:31];
    reg [7:0] current_char;

    // ------------------------------
    // Детектор отпускания кнопки
    // ------------------------------
    wire morse_released = ~morse_prev_stable & morse_stable;

    // ------------------------------
    // Инициализация таблицы Морзе
    // ------------------------------
    initial begin
        // Цифры
        morse_memory[5'b11111] = "0"; // -----
        morse_memory[5'b01111] = "1"; // .----
        morse_memory[5'b00111] = "2"; // ..---
        morse_memory[5'b00011] = "3"; // ...--
        morse_memory[5'b00001] = "4"; // ....-
        morse_memory[5'b00000] = "5"; // .....
        morse_memory[5'b10000] = "6"; // -....
        morse_memory[5'b11000] = "7"; // --...
        morse_memory[5'b11100] = "8"; // ---..
        morse_memory[5'b11110] = "9"; // ----.

        // Пробел
        morse_memory[5'b00000] = " ";
    end

    // ------------------------------
    // Основной процесс декодирования
    // ------------------------------
    always @(posedge clk) begin
        morse_prev_stable <= morse_stable;

        // Сброс
        if (reset_stable) begin
            press_counter <= 0;
            release_counter <= 0;
            morse_pattern <= 0;
            morse_length <= 0;
            current_char <= " ";
            output_buffer <= " ";
            decoding <= 0;
        end else begin
            // Счётчик нажатия/отпускания
            if (~morse_stable) begin
                press_counter <= press_counter + 1;
                release_counter <= 0;
            end else begin
                release_counter <= release_counter + 1;
                press_counter <= 0;
            end

            // Определение точки или тире
            if (morse_released && press_counter > 0) begin
                if (press_counter < DASH_TIME)
                    morse_pattern <= (morse_pattern << 1);       // точка
                else
                    morse_pattern <= (morse_pattern << 1) | 1;   // тире
                morse_length <= morse_length + 1;
                decoding <= 1;
            end

            // Декодирование символа после паузы между буквами
            if (morse_stable && release_counter > LETTER_GAP && decoding) begin
                // Индекс формируется как комбинация длины и паттерна
                case (morse_length)
                    3'd1: current_char <= morse_memory[morse_pattern];
                    3'd2: current_char <= morse_memory[morse_pattern];
                    3'd3: current_char <= morse_memory[morse_pattern];
                    3'd4: current_char <= morse_memory[morse_pattern];
                    3'd5: current_char <= morse_memory[morse_pattern];
                    default: current_char <= "?";
                endcase

                output_buffer <= (current_char != 0) ? current_char : "?";

                // Сброс для следующего символа
                morse_pattern <= 0;
                morse_length <= 0;
                decoding <= 0;
            end
        end
    end
endmodule
