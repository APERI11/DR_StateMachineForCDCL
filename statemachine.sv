module analyse #(
	parameter literals = 8,
	parameter clauses  = 16
) (
	input 		Start, 
	input		Clk, 
	input		Reset,
	
	//Outputs from BCP with Conflict Information
	input [$clog2(clauses) -1 : 0] 	BCP_CID,
	input [$clog2(literals)-1 : 0] 	CurDecLevel,

	//Outputs from CIT Search
	input [$clog2(literals) : 0] 	CIT_LID,

	//Outputs from AIT with Search/Push Operations Information
	input						 	AIT_Seen,
	input [$clog2(literals)-1 : 0] 	AIT_Declevel,
	input [$clog2(clauses) -1 : 0] 	AIT_Reason,
	input [$clog2(literals)   : 0]  AIT_LID,
	
	//Control Signal Outputs for CIT Module
	output reg						CIT_searchEn,

	//Control Signal Outputs for AIT Module
	//OPDCODES SEARCH: 01, WRITE SEEN 1: 10, POP: 11, Reset: 00
	output reg	[1:0]				AIT_opCode,
	output reg						AIT_enable
);

	parameter clause_bit 	= $clog2(clauses);
	parameter literals_bit	= $clog2(literals);
	
	reg [4:0] state, next_state;
	
	//Local Register Definition
	reg [literals_bit-1:0] 	LocalCurDecLevel;
	reg [literals_bit-1:0] 	LocalDecLevel; 
	reg [clause_bit-1:0] 	CIDCfg; 
	reg [3:0]				counter_delay;	
	reg						LocalSeen;
	reg						done;
	reg [literals_bit  :0]  learned_LID;
	reg [literals_bit  :0]  LocalLID;
	
	//Instantiating the FIFO Module
	reg						fifo_wren;
	reg						fifo_ren;
	wire					fifo_empty;
	wire					fifo_full;
	wire [literals_bit :0] fifo_out;	
	fifo #(.literals(literals)) fifo_module (
    	.clk		(Clk),
    	.rst		(Reset),
    	.wren		(fifo_wren),
		.ren		(fifo_ren),
		.data_in	(CIT_LID),
    	.empty		(fifo_empty),
		.full		(fifo_full),
		.data_out	(fifo_out)
    );

	//Instantiating the Counter Module
	reg							cnt_incr;
	reg							cnt_enable;
	wire	[literals_bit-1:0]	counter;
	counter #(.literals(literals)) counter_module (
    	.clk		(Clk),
		.rst		(Reset),
		.incr		(cnt_incr),
		.enable		(cnt_enable),
		.counter	(counter)      
	);

	//State Machine Encoding
	localparam INI			= 	5'b00001; // "Initial" state
	localparam CIT_SEARCH 	= 	5'b00010; // "CIT Search" state
	localparam AIT_SEARCH 	= 	5'b00100; // "input S Declevel and Reason" state
	localparam BFS 			= 	5'b01000; // "Compare Declevel" state
	localparam NEW_CID 		= 	5'b10000; // "assign new CID" state


	/**********************************

		STATE MEMORY

	*********************************/
	always @(posedge Clk ) begin
		if(!Reset) begin
			CIDCfg				<= 'b0;
			LocalSeen 			<= 'b0;
			LocalDecLevel 		<= 'b0;
			LocalCurDecLevel 	<= 'b0;
			LocalLID			<= 'b0;
			counter_delay		<= 'b0;
			done				<= 'b0;
			state				<= INI;
		end
		else begin
			if(next_state == CIT_SEARCH) begin  	              
				if(state == INI)
					CIDCfg			<= 	BCP_CID;
				else
					CIDCfg			<= 	AIT_Reason;

				LocalCurDecLevel 	<= 	CurDecLevel;
			end
			else if (next_state == BFS) begin
				LocalSeen			<=	AIT_Seen;
				LocalDecLevel		<=	AIT_Declevel;
			end
			else if (next_state == INI) begin
				done				<=  1'b1;
			end
			
			if(fifo_ren)
				LocalLID	<= fifo_out;

			if(state ==	CIT_SEARCH) begin
				counter_delay	<= counter_delay + 1'b1;
				if(counter_delay == 4'd9) begin
					counter_delay	<= 4'd0;
				end
			end
			else if(state == AIT_SEARCH || state == NEW_CID) begin
				counter_delay	<= counter_delay + 1'b1;
				if(counter_delay == 4'd1) begin
					counter_delay	<= 4'd0;
				end
			end
			
			if(state == INI)
				done	<=	1'b0;
			
			if ((state == BFS) && (AIT_Seen == 0) && (LocalDecLevel != 0))	begin
							if (LocalDecLevel != LocalCurDecLevel) begin
								learned_LID	<=	AIT_LID;
							end	
			end


			state <= next_state;
		end
	end


	/***************************************************

		NEXT STATE LOGIC

	****************************************************/
	always @(*) begin
		case (state)
			INI	: 
			begin
				// next_state transitions in the control unit
				if (Start)
					next_state = CIT_SEARCH;
				else
					next_state	= state;
			end
			CIT_SEARCH	:
			begin
				// next_state transitions in the control unit
				if (fifo_full)
					next_state 	= 	AIT_SEARCH; // Transit conditionally to the AIT_SEARCH next_state         
				else
					next_state	=	state;
			
			end
			
			AIT_SEARCH :
			begin 
				if(counter_delay == 1'b1)
					next_state 	= 	BFS;
				else
					next_state	=	state;		
			end
			BFS :
			begin
				// next_state transitions in the control unit 
				if (fifo_empty && (counter != 0))
					next_state 	= NEW_CID;		
				else if (fifo_empty && (counter == 0))
					next_state 	= INI;
				else
					next_state 	= AIT_SEARCH;	
			end
			NEW_CID :
			begin
				if (counter != 1'b1 && AIT_Seen == 1)
					next_state	= CIT_SEARCH;
				else if (counter == 1'b1 && AIT_Seen == 1)
					next_state 	= INI;
				else
					next_state	= state;						
			end
		endcase
	end


	/*********************************************************

			Output Function Logic

	*********************************************************/
	always	@(*)	begin
		case(state)
			INI:
				begin
					fifo_wren		= 	1'b0;
					fifo_ren		= 	1'b0;
					cnt_incr		= 	1'b0;
					cnt_enable		=	1'b0;
					CIT_searchEn	=	1'b0;
					AIT_opCode		= 	2'b00;
					AIT_enable		= 	1'b0;
				end
			CIT_SEARCH:
				begin
					if(counter_delay == 4'd4 || counter_delay == 4'd6 || counter_delay == 4'd8)
						fifo_wren	=	1'b1;
					else
						fifo_wren	=	1'b0;

					fifo_ren		= 	1'b0;
					cnt_incr		= 	1'b0;
					cnt_enable		=	1'b0;
					CIT_searchEn	=	1'b1;
					AIT_opCode		= 	2'b00;
					AIT_enable		= 	1'b0;
				end
			AIT_SEARCH:
				begin
					fifo_wren		=	1'b0;
					cnt_incr		= 	1'b0;
					cnt_enable		=	1'b0;
					CIT_searchEn	=	1'b0;

					if(!fifo_empty && counter_delay == 4'd0) begin
						fifo_ren	= 1'b1;
						AIT_opCode	= 2'b01;
						AIT_enable	= 1'b1;	
					end
					else begin
						fifo_ren	= 1'b0;
						AIT_opCode	= 2'b01;
						AIT_enable	= 1'b0;
					end
				end
			BFS:
				begin
					fifo_wren		=	1'b0;
					fifo_ren		=	1'b0;
					CIT_searchEn	=	1'b0;
				
					if (LocalSeen == 0 && LocalDecLevel != 0)	begin
						begin
							AIT_enable	=	1'b1;
							AIT_opCode 	=	2'b10;
							if (LocalDecLevel == LocalCurDecLevel) begin 
								cnt_incr 	=	1'b1;
								cnt_enable	=	1'b1;					
							end
							else begin
								cnt_incr 	=	1'b1;
								cnt_enable	=	1'b0;
							end	
						end
					end

				end
			NEW_CID:
				begin
					fifo_wren		=	1'b0;
					fifo_ren		=	1'b0;
					CIT_searchEn	=	1'b0;

					if(counter_delay == 4'd0) begin
						AIT_opCode	= 2'b11;
						AIT_enable	=  1'b1;	
					end
					else begin
						AIT_opCode	= 2'b11;
						AIT_enable	=  1'b0;
					end
					
					if(AIT_Seen == 1) begin
						cnt_incr	=	1'b0;
						cnt_enable	=	1'b1;
					end
					else begin
						cnt_incr	=   1'b0;
						cnt_enable	=	1'b1;			
					end
				end
		endcase
	end
endmodule
