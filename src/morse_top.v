module morse_top(
    input wire clk,              // Тактовый сигнал
    input wire reset,            // Сброс (активный низкий)
    input wire morse_in,         // Ввод Морзе-кода
    output wire [6:0] hex0,      // 7-сегментный индикатор 0
    output wire [6:0] hex1,      // 7-сегментный индикатор 1
    output wire [6:0] hex2,      // 7-сегментный индикатор 2
    output wire [6:0] hex3,      // 7-сегментный индикатор 3
    output wire [6:0] hex4,      // 7-сегментный индикатор 4
    output wire [6:0] hex5,      // 7-сегментный индикатор 5
    output wire button_led       // Индикатор нажатия кнопки
);

// Проводники для соединения модулей
wire [7:0] ascii_char;
wire char_valid;
wire button_pressed;

// Декодер Морзе
morse morse_decoder(
    .clk(clk),
    .reset(reset),
    .morse_in(morse_in),
    .ascii_char(ascii_char),
    .char_valid(char_valid),
    .button_pressed(button_pressed)
);

// Дисплейный модуль
display display_unit(
    .clk(clk),
    .reset(reset),
    .ascii_char(ascii_char),
    .char_valid(char_valid),
    .HEX0(hex0),
    .HEX1(hex1),
    .HEX2(hex2),
    .HEX3(hex3),
    .HEX4(hex4),
    .HEX5(hex5)
);

// Индикация нажатия кнопки
assign button_led = button_pressed;

endmodule