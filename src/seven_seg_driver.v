module seven_seg_driver (
    input clk,
    input reset_btn,
    input [6:0] hex_in,   // код сегментов от morse_to_hex
    output reg [6:0] hex0 // выход на физический дисплей
);
    always @(posedge clk) begin
        if (!reset_btn)
            hex0 <= 7'b1111111; // очистка при сбросе
        else
            hex0 <= hex_in;
    end
endmodule
