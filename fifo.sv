module fifo #(
    parameter literals = 8
) (
    input                                   clk,
    input                                   rst,
    input                                   wren,
    input                                   ren,
    input   [$clog2(literals) : 0]          data_in,
    output                                  empty,
    output                                  full,
    output  [$clog2(literals) : 0]          data_out
);

reg     [$clog2(literals) :0]  fifo_reg    [3:0];
reg     [2:0]                   wrptr, rdptr;
wire    [2:0]                   depth;
wire                            wenq, renq;
integer                         i;

assign depth    = wrptr - rdptr;
assign full     = ((depth == 3'd3) || (depth == 3'd5)) ? 1'b1 : 1'b0; 
assign empty    = (depth == 2'd0); 

assign wenq     = (~full)  & wren;
assign renq     = (~empty) & ren;

assign data_out = fifo_reg[rdptr[1:0]];

always @(posedge clk) begin
    if(!rst) begin
        wrptr       <= 3'd0;
        rdptr       <= 3'd0;

        for (i=0; i<4; i=i+1) begin
            fifo_reg[i] <= 'b0; 
        end       
    end
    else begin
        if(wenq) begin
            fifo_reg[wrptr[1:0]] <= data_in;
            wrptr   <=  wrptr + 1'b1;
        end
        if(renq) begin
            rdptr   <=  rdptr + 1'b1;
        end
    end
end
endmodule
