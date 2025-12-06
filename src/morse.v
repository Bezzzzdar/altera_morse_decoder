module morse (
    input clk,               // Тактовый сигнал 50 МГц
    input reset_btn,         // Кнопка сброса (активный низкий)
    input morse_btn,         // Кнопка ввода Морзе (активный низкий)
    output wire uart_tx_out  // UART TX
);

    // Параметры таймингов Морзе (в тактах 50 МГц)
    parameter DOT_TIME     = 25_000_000;    // 0.5 секунды
    parameter DASH_TIME    = 75_000_000;    // 1.5 секунды
    parameter SYMBOL_GAP   = 25_000_000;    // 0.5 секунды между символами
    parameter LETTER_GAP   = 125_000_000;   // 2.5 секунды между буквами

    // ------------------------------
    // Регистры антидребезга
    // ------------------------------
    reg [19:0] debounce_counter_reset;
    reg [19:0] debounce_counter_morse;
    reg reset_prev, morse_prev;
    reg reset_stable, morse_stable;

    // ------------------------------
    // Регистры декодера Морзе
    // ------------------------------
    reg [31:0] press_counter;
    reg [31:0] release_counter;
    reg [15:0] morse_pattern;
    reg [3:0]  morse_length;
    reg morse_prev_stable;
    reg decoding;

    // ------------------------------
    // Детекторы фронтов
    // ------------------------------
    reg reset_stable_prev;
    wire reset_pressed;
    reg morse_stable_prev;
    wire morse_pressed;
    wire morse_released;

    // ------------------------------
    // Память Морзе
    // ------------------------------
    reg [7:0] morse_memory [0:63];
    reg [7:0] current_char;
    reg [7:0] output_buffer;

    // ------------------------------
    // UART
    // ------------------------------
    reg uart_send;
    wire uart_busy;
    reg [7:0] uart_data;

    // ------------------------------
    // Инициализация памяти Морзе
    // ------------------------------
    initial begin
        // Цифры
        morse_memory[8'b111111] = "0"; // -----
        morse_memory[8'b101111] = "1"; // .----
        morse_memory[8'b100111] = "2"; // ..---
        morse_memory[8'b100011] = "3"; // ...--
        morse_memory[8'b100001] = "4"; // ....-
        morse_memory[8'b100000] = "5"; // .....
        morse_memory[8'b110000] = "6"; // -....
        morse_memory[8'b111000] = "7"; // --...
        morse_memory[8'b111100] = "8"; // ---..
        morse_memory[8'b111110] = "9"; // ----.

        // Пробел
        morse_memory[8'b000000] = " "; // Пробел (длинная пауза)
    end

    // ------------------------------
    // Антидребезг кнопок
    // ------------------------------
    always @(posedge clk) begin
        // Сброс
        if (reset_btn != reset_prev) begin
            debounce_counter_reset <= 0;
            reset_prev <= reset_btn;
        end else if (debounce_counter_reset < 20'd1_000_000)
            debounce_counter_reset <= debounce_counter_reset + 1;
        else
            reset_stable <= reset_prev;

        // Кнопка Морзе
        if (morse_btn != morse_prev) begin
            debounce_counter_morse <= 0;
            morse_prev <= morse_btn;
        end else if (debounce_counter_morse < 20'd1_000_000)
            debounce_counter_morse <= debounce_counter_morse + 1;
        else
            morse_stable <= morse_prev;
    end

    // ------------------------------
    // Детекторы фронтов
    // ------------------------------
    always @(posedge clk) begin
        reset_stable_prev <= reset_stable;
        morse_stable_prev <= morse_stable;
        morse_prev_stable <= morse_stable;
    end

    assign reset_pressed = reset_stable_prev & ~reset_stable;
    assign morse_pressed = morse_stable_prev & ~morse_stable;
    assign morse_released = ~morse_stable_prev & morse_stable;

    // ------------------------------
    // Основной автомат декодера Морзе
    // ------------------------------
    always @(posedge clk) begin
        if (reset_pressed) begin
            press_counter <= 0;
            release_counter <= 0;
            morse_pattern <= 1;
            morse_length <= 0;
            current_char <= " ";
            output_buffer <= " ";
            decoding <= 0;
        end else begin
            // Отслеживание нажатия
            if (morse_stable == 0) begin
                press_counter <= press_counter + 1;
                release_counter <= 0;
            end else begin
                release_counter <= release_counter + 1;
                press_counter <= 0;
            end

            // Определение точки/тире
            if (morse_released && press_counter > 0) begin
                if (press_counter < DASH_TIME) begin
                    morse_pattern <= (morse_pattern << 1); // точка
                    morse_length <= morse_length + 1;
                end else begin
                    morse_pattern <= (morse_pattern << 1) | 1; // тире
                    morse_length <= morse_length + 1;
                end
                decoding <= 1;
            end

            // Декодирование символа при длинной паузе
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

    // ------------------------------
    // Управление UART
    // ------------------------------
    always @(posedge clk) begin
        if (!uart_busy) begin
            uart_data <= output_buffer;
            uart_send <= 1'b1; // старт передачи
        end else begin
            uart_send <= 1'b0;
        end
    end

    // ------------------------------
    // Инстанс UART
    // ------------------------------
    uart_tx #(
        .CLOCK_FREQ(50_000_000),
        .BAUD_RATE(9600)
    ) uart_inst (
        .clk(clk),
        .rst(reset_btn),
        .data_in(uart_data),
        .send(uart_send),
        .tx(uart_tx_out),
        .busy(uart_busy)
    );

endmodule
