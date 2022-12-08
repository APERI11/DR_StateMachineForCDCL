module counter #(
    parameter literals = 8
) (
    input                                   clk,
    input                                   rst,
    input                                   incr,
    input                                   enable,
    output  reg [$clog2(literals)-1 : 0]    counter      
);

always @(posedge clk ) begin
    if(!rst) begin
        counter <= 'b0;
    end
    else begin
        if(enable) begin
            if(incr)
                counter <= counter + 1'b1;
            else
                counter <= counter - 1'b1;   
        end
    end
end

endmodule
