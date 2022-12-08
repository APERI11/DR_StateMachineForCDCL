`timescale 1ns/1ps

module analyse_tb;

parameter clauses   = 16;
parameter literals  = 16;


reg                             clk, reset;
reg                             conflict;

reg [$clog2(clauses) -1 : 0]    BCP_CID;
reg [$clog2(literals)-1 : 0]    CurDecLevel;
reg [$clog2(literals)-1 : 0]    AIT_VID;
reg [$clog2(literals)-1 : 0]    CIT_LID;
reg                             AIT_Polarity;
reg                             CIT_Polarity;
reg                             AIT_Seen;
reg [$clog2(literals)-1 : 0]    AIT_Declevel;
reg [$clog2(clauses) -1 : 0]    AIT_Reason;

wire                            CIT_searchEn;
wire [1:0]	                    AIT_opCode;
wire			                AIT_enable;

analyse #(
	.literals(16),
    .clauses(16)
) anly (
    .Start          (conflict),
    .Clk            (clk),
    .Reset          (reset),
    .BCP_CID        (BCP_CID),
    .CurDecLevel    (CurDecLevel),
	.CIT_LID        ({CIT_Polarity, CIT_LID}),
	.AIT_Seen       (AIT_Seen),
    .AIT_Declevel   (AIT_Declevel),
	.AIT_Reason     (AIT_Reason),
    .CIT_searchEn   (CIT_searchEn),
    .AIT_opCode     (AIT_opCode),
	.AIT_enable     (AIT_enable),
    .AIT_LID        ({AIT_Polarity, AIT_VID})    
);

integer fileptr_CIT, fileptr_AIT, fileptr_lcl;
reg[255:0]  line, line1;

initial begin
    fileptr_lcl    =   $fopen("Learned_Clause.txt","w");
    fileptr_CIT    =   $fopen("CIT_info.txt","r");
    fileptr_AIT    =   $fopen("AIT_info.txt","r");
    $fmonitor   (fileptr_lcl, "%b %d", ~anly.learned_LID[4], anly.learned_LID[3:0]);
    clk            =   1'b1;
    reset          =   1'b0;
    BCP_CID        =   4'd6;
    CurDecLevel    =   4'd4;
end

initial begin
    #14 reset       =   1'b1;
    #8  conflict    =   1'b1;
    wait(anly.done);
    $fdisplay(fileptr_lcl,"%b %d", ~AIT_Polarity, AIT_VID[3:0]);
    $fclose(fileptr_CIT);
    $fclose(fileptr_AIT);
    $finish;
end

always  #2 clk = ~clk;


//Mimicking the CIT Module
always @(*) begin
    if(CIT_searchEn && (anly.counter_delay == 4'd4 || anly.counter_delay == 4'd6 || anly.counter_delay == 4'd8))
	$fgets(line, fileptr_CIT);
    $sscanf(line, "%4b %b", CIT_LID, CIT_Polarity);
end

//Mimicking the AIT Module
always  @(*) begin
    if(AIT_enable && (AIT_opCode == 2'b01 || AIT_opCode == 2'b11)) begin
        $fgets(line1, fileptr_AIT);
        //$display("\n\n %d \n\n", line);
        $sscanf(line1, "%4b %4b %4b %b %b", AIT_VID, AIT_Declevel, AIT_Reason, AIT_Seen, AIT_Polarity);
    end
end


endmodule
