module uart_tx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE  = 9600
)(
    input        clk,
    input        rst,
    input  [7:0] data_in,
    input        send,
    output reg   tx,
    output reg   busy
);

    localparam BIT_PERIOD = CLOCK_FREQ / BAUD_RATE;

    reg [15:0] counter;
    reg [3:0] bit_index;
    reg [9:0] shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx <= 1'b1;
            busy <= 0;
            counter <= 0;
            bit_index <= 0;
            shift_reg <= 10'b1111111111;
        end else begin
            if (send && !busy) begin
                shift_reg <= {1'b1, data_in, 1'b0};
                busy <= 1;
                counter <= 0;
                bit_index <= 0;
            end

            if (busy) begin
                if (counter < BIT_PERIOD-1)
                    counter <= counter + 1;
                else begin
                    counter <= 0;
                    tx <= shift_reg[bit_index];
                    bit_index <= bit_index + 1;
                    if (bit_index == 9)
                        busy <= 0;
                end
            end
        end
    end
endmodule
