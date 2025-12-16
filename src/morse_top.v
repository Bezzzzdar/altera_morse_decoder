module morse_top (
    input clk,
    input reset_btn,
    input morse_btn,
    output [6:0] hex0,
    output [7:0] leds
);
    wire [7:0] output_buffer;
    wire [6:0] seg_code;

    // Модуль приёма и декодирования
    morse_input u_input (
        .clk(clk),
        .reset_btn(reset_btn),
        .morse_btn(morse_btn),
        .output_buffer(output_buffer),
        .leds(leds)
    );

    // Модуль преобразования символа в 7-битный код
    morse_to_hex u_hex (
        .input_char(output_buffer),
        .hex0(seg_code)
    );

    // Модуль управления семисегментным индикатором
    seven_seg_driver u_driver (
        .clk(clk),
		  .reset_btn(reset_btn),
		  .hex_in(seg_code),
        .hex0(hex0)
    );
endmodule
