module morse_to_hex (
    input [7:0] input_char,
    output reg [6:0] hex0
);
    always @(*) begin
        case(input_char)
            "0": hex0 = 7'b1000000;
            "1": hex0 = 7'b1111001;
            "2": hex0 = 7'b0100100;
            "3": hex0 = 7'b0110000;
            "4": hex0 = 7'b0011001;
            "5": hex0 = 7'b0010010;
            "6": hex0 = 7'b0000010;
            "7": hex0 = 7'b1111000;
            "8": hex0 = 7'b0000000;
            "9": hex0 = 7'b0010000;
            " ": hex0 = 7'b1111111;
            "?": hex0 = 7'b0011100;
            default: hex0 = 7'b0111111;
        endcase
    end
endmodule
