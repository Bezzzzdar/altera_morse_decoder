module debounce(
    input clk,
    input btn,
    output reg btn_stable
);
    reg [19:0] counter;
    reg btn_prev;

    always @(posedge clk) begin
        if (btn != btn_prev) begin
            counter <= 0;
            btn_prev <= btn;
        end else if (counter < 20'd1_000_000)
            counter <= counter + 1;
        else
            btn_stable <= btn_prev;
    end
endmodule
