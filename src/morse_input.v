module morse_input (
    input clk,
    input reset_btn,
    input morse_btn,
    output reg [7:0] output_buffer, // Выход для верхнего модуля
    output reg [7:0] leds
);

    // Параметры таймингов Морзе
    parameter DOT_TIME = 25_000_000;
    parameter DASH_TIME = 75_000_000;
    parameter SYMBOL_GAP = 25_000_000;
    parameter LETTER_GAP = 125_000_000;

    // Регистры для антидребезга
    reg [19:0] debounce_counter_reset = 20'd0;
    reg [19:0] debounce_counter_morse = 20'd0;
    reg reset_prev = 1'b1, morse_prev = 1'b1;
    reg reset_stable = 1'b1, morse_stable = 1'b1;

    // Счетчики и паттерны
    reg [31:0] press_counter = 0, release_counter = 0;
    reg [15:0] morse_pattern = 16'd0;
    reg [3:0] morse_length = 4'd0;
    reg decoding = 1'b0;

    reg reset_stable_prev, morse_stable_prev;
    wire reset_pressed = reset_stable_prev & ~reset_stable;
    wire morse_released = ~morse_stable_prev & morse_stable;

    // Память для Морзе (цифры и пробел)
    reg [7:0] morse_memory [0:63];

    initial begin
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
        morse_memory[8'b000000] = " ";
    end

    // Антидребезг
    always @(posedge clk) begin
        if (reset_btn != reset_prev) begin 
            debounce_counter_reset <= 20'd0; 
            reset_prev <= reset_btn; 
        end else if (debounce_counter_reset < 20'd1_000_000) 
            debounce_counter_reset <= debounce_counter_reset + 20'd1;
        else 
            reset_stable <= reset_prev;
    end

    always @(posedge clk) begin
        if (morse_btn != morse_prev) begin 
            debounce_counter_morse <= 20'd0; 
            morse_prev <= morse_btn; 
        end else if (debounce_counter_morse < 20'd1_000_000) 
            debounce_counter_morse <= debounce_counter_morse + 20'd1;
        else 
            morse_stable <= morse_prev;
    end

    always @(posedge clk) begin
        reset_stable_prev <= reset_stable;
        morse_stable_prev <= morse_stable;
    end

    // Основной автомат
    always @(posedge clk) begin
        if (reset_pressed) begin
            press_counter <= 32'd0;
            release_counter <= 32'd0;
            morse_pattern <= 16'd1;
            morse_length <= 4'd0;
            output_buffer <= " ";
            decoding <= 1'b0;
            leds <= 8'b00000001;
        end else begin
            // Нажатие кнопки
            if (morse_stable == 0) begin
                press_counter <= press_counter + 1;
                release_counter <= 32'd0;
                leds[0] <= 1;
            end else begin
                release_counter <= release_counter + 1;
                press_counter <= 32'd0;
                leds[0] <= 0;
            end

            // Определение точки/тире
            if (morse_stable_prev & ~morse_stable && press_counter > 0) begin
                if (press_counter < DASH_TIME) begin
                    morse_pattern <= (morse_pattern << 1);
                    morse_length <= morse_length + 4'd1;
                    leds[1] <= 1;
                end else begin
                    morse_pattern <= (morse_pattern << 1) | 16'd1;
                    morse_length <= morse_length + 4'd1;
                    leds[2] <= 1;
                end
                decoding <= 1'b1;
            end

            // Декодирование символа
            if (morse_stable && release_counter > LETTER_GAP && decoding) begin
                // Записываем символ в output_buffer
                if (morse_memory[{morse_length, morse_pattern}] != 0)
                    output_buffer <= morse_memory[{morse_length, morse_pattern}];
                else
                    output_buffer <= "?";

                morse_pattern <= 16'd0;
                morse_length <= 4'd0;
                decoding <= 1'b0;
                leds[1] <= 0;
                leds[2] <= 0;
            end

            // Сброс индикации точки/тире
            if (release_counter > SYMBOL_GAP) begin
                leds[1] <= 0;
                leds[2] <= 0;
            end
        end
    end
endmodule
