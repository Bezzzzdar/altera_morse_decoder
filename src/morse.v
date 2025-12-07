module morse #(
    parameter DOT_TIME   = 25_000_000,    // 0.5 секунды
    parameter DASH_TIME  = 75_000_000,    // 1.5 секунды
    parameter SYMBOL_GAP = 25_000_000,    // 0.5 секунды между точками/тире
    parameter LETTER_GAP = 125_000_000    // 2.5 секунды между буквами
)(
    input clk,
    input reset_stable,
    input morse_stable,
    output reg [7:0] output_buffer
);

    // ------------------------------
    // Счётчики и флаги
    // ------------------------------
    reg [31:0] press_counter;
    reg [31:0] release_counter;
    reg [15:0] morse_pattern;
    reg [3:0]  morse_length;
    reg decoding;
    reg morse_prev_stable;

    // ------------------------------
    // Память Морзе
    // ------------------------------
    reg [7:0] morse_memory [0:63];
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
        morse_memory[8'b111111] = "0"; 
        morse_memory[8'b101111] = "1";
        morse_memory[8'b100111] = "2";
        morse_memory[8'b100011] = "3";
        morse_memory[8'b100001] = "4";
        morse_memory[8'b100000] = "5";
        morse_memory[8'b110000] = "6";
        morse_memory[8'b111000] = "7";
        morse_memory[8'b111100] = "8";
        morse_memory[8'b111110] = "9";

        // Пробел
        morse_memory[8'b000000] = " ";
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
            morse_pattern <= 1;
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
                    morse_pattern <= (morse_pattern << 1); // точка
                else
                    morse_pattern <= (morse_pattern << 1) | 1; // тире
                morse_length <= morse_length + 1;
                decoding <= 1;
            end

            // Декодирование символа после паузы между буквами
            if (morse_stable && release_counter > LETTER_GAP && decoding) begin
                current_char <= morse_memory[{morse_length, morse_pattern}];
                if (current_char != 0)
                    output_buffer <= current_char;
                else
                    output_buffer <= "?";

                // Сброс для следующего символа
                morse_pattern <= 0;
                morse_length <= 0;
                decoding <= 0;
            end
        end
    end
endmodule
