//************************************************************************************************//
/*
% Copyright (c) 2016-2022, WiSig Networks Pvt Ltd. All rights reserved.
% www.wisig.com
%
% All information contained herein is property of WiSig Networks Pvt Ltd.
% unless otherwise explicitly mentioned.
%
% The intellectual and technical concepts in this file are proprietary
% to WiSig Networks and may be covered by granted or in process national
% and international patents and are protect by trade secrets and
% copyright law.
%
% Redistribution and use in source and binary forms of the content in
% this file, with or without modification are not permitted unless
% permission is explicitly granted by WiSig Networks.
General Information:
----------------------
	dataIn = a + ib;
	DMRS = +- 1 +- 1i; No scaling is applied in DMRS
	data out = (+-a +-b) + (+-a+-b)i
	Note that the output of tihs module and matlab differ by DMRS scaling
I/O Information:
------------------
	1. 2-bit DMRS input from DMRSgen
	2. Q1.15 * nRX input from RB De-mapper.
	3. Q2.14 * nRX output to Time Offset Estimation
--------------
Date (dd/mm/yy)    	  Author 		        Description of Change
------------------------------------------------------------------
  26-03-2022         Yeshpal                 Initial Version
 */
//************************************************************************************************//
 module wn_pdcchrx_modulationremoval
 #(
    // nRX is the number of Reciever Antennas
    parameter nRX = 2
  )
  (   //System clock
    input clk,
    //System reset
    input rstn,
    //SAXIS DMRS input data
    input [7:0] dmrs_in_tdata,
    input dmrs_in_tvalid,
    output wire dmrs_in_tready,
    //SAXIS data from RB De-mapper
    input [((nRX*32)-1):0] data_in_tdata,
    input data_in_tvalid,
    input data_in_tlast,
    output wire data_in_tready,
    //SAXIS output data
    output wire [((nRX*32)-1):0] estm_out_tdata,
    output wire estm_out_tvalid,
    input estm_out_tready,
    output wire estm_out_tlast


  );
 localparam DW = (nRX)*32;
 localparam DW_DMRS = 8;

 //Registering input and output ports
 wire [7:0] dmrs_in_tdata_reg;
 wire dmrs_in_tvalid_reg;
 wire [(DW - 1):0] data_in_tdata_reg;
 wire data_in_tvalid_reg;
 wire data_in_tready_reg;
 wire data_in_tlast_reg;
 wire [(DW - 1):0] estm_out_tdata_reg;
 wire estm_out_tvalid_reg;
 wire estm_out_tready_reg;
 wire estm_out_tlast_reg;

 reg signed [16:0] estm_out[0:(2 * nRX - 1)];


 //Skid buffer for input dmrs port

 skidbuffer #(
              .DW(DW_DMRS)
            ) inst_in1 (
              .clock(clk),
              .reset(~rstn),
              .input_tvalid(dmrs_in_tvalid),
              .input_tready(dmrs_in_tready),
              .input_tdata(dmrs_in_tdata),
              .output_tvalid(dmrs_in_tvalid_reg),
              .output_tready(dmrs_in_tready_reg),
              .output_tdata(dmrs_in_tdata_reg)
            );


 //skid buffer for input data port

 wn_skid_buffer
   #(
     .DW (
       (nRX * 32) )
   )
   inst_in2 (
     .clock (clk ),
     .reset (~rstn ),
     .input_tvalid (data_in_tvalid ),
     .input_tready (data_in_tready ),
     .input_tdata (data_in_tdata ),
     .input_tlast (data_in_tlast ),
     .output_tvalid (data_in_tvalid_reg ),
     .output_tready (data_in_tready_reg ),
     .output_tdata (data_in_tdata_reg ),
     .output_tlast  ( data_in_tlast_reg)
   );

 //skid buffer for output data port

 wn_skid_buffer
   #(
     .DW (
       (nRX * 32) )
   )
   inst_out (
     .clock (clk ),
     .reset (~rstn ),
     .input_tvalid (estm_out_tvalid_reg ),
     .input_tready (estm_out_tready_reg ),
     .input_tdata (estm_out_tdata_reg ),
     .input_tlast (estm_out_tlast_reg ),
     .output_tvalid (estm_out_tvalid ),
     .output_tready (estm_out_tready ),
     .output_tdata (estm_out_tdata ),
     .output_tlast  ( estm_out_tlast)
   );


 //state variables
 reg [1:0] state,next_state;
 //Some temperory variables to store intermediate results of computation
 wire signed [15:0] data_in[0:(2 * nRX - 1)];


 localparam RD_DATA1 = 0,RD_DATA2 = 1,COMPUTE = 2,WR_DATA = 3;

 

 assign data_in_tready_reg = (data_in_tvalid_reg && dmrs_in_tvalid_reg && estm_out_tready_reg && rstn) ? 1 : 0;
 assign estm_out_tvalid_reg = (data_in_tvalid_reg && dmrs_in_tvalid_reg && rstn) ? 1 : 0;
 assign estm_out_tlast_reg = data_in_tlast_reg;
 assign  dmrs_in_tready_reg = data_in_tready_reg;

 

 //Logic for storing input De-mapper data into signed variables ,to perform signed computation on this data
 genvar g2;
 generate
   for(g2 = 0; g2 < (2 * nRX);g2 = g2 + 2)
   begin : for_loop35

     assign data_in[g2] = data_in_tdata_reg[((g2 * 16) + 15):(g2 * 16 )];
     assign data_in[g2 + 1] = data_in_tdata_reg[(((g2 + 1) * 16) + 15):((g2 + 1)* 16 )];




   end


 endgenerate


 //Computation logic
 /*
 The DE-mapper data is multiplied with the conjugate of DMRS data for 
 all the DMRS locations  in a PRB

 */
 genvar g1;
 generate

   for(g1 = 0 ; g1 < (2 * nRX);g1 = g1 + 2)
   begin : for_loop19


     always @(*)
     begin

       case(dmrs_in_tdata_reg[1:0])

         2'b00:
         begin
           // This case is when dmrs is (1 + i).. So we have to multiply by conjugate.. i.e (a + ib) * (1 - i). where (a + ib) is the rdata
           // So real = a + b ; imag = -a + b;

           estm_out[g1] = data_in[g1]  + data_in[g1 + 1] ;
           estm_out[g1 + 1] = data_in[g1 + 1] - data_in[g1];


         end

         2'b01:
         begin
           // This case is when dmrs is (-1 + i).. So we have to multiply by conjugate.. i.e (a + ib) * (-1 - i). where (a + ib) is the rdata
           // So real = -a + b ; imag = -a - b;
           estm_out[g1] =  data_in[g1 + 1] - data_in[g1];
           estm_out[g1 + 1]  = 17'd0 - {data_in[g1][15],data_in[g1]} - {data_in[g1+1][15],data_in[g1 + 1]} ;
         end

         2'b10:
         begin
           // This case is when dmrs is (1 - i).. So we have to multiply by conjugate.. i.e (a + ib) * (1 + i). where (a + ib) is the rdata
           // So real = a - b ; imag = a + b;

           estm_out[g1]  = data_in[g1]  - data_in[g1 + 1] ;
           estm_out[g1 + 1]  = data_in[g1]  + data_in[g1 + 1] ;
         end

         2'b11:
         begin
           // This case is when dmrs is (1 - i).. So we have to multiply by conjugate.. i.e (a + ib) * (1 + i). where (a + ib) is the rdata
           // So real = -a - b ; imag = a - b;
           estm_out[g1] = 17'd0 - {data_in[g1][15],data_in[g1]} - {data_in[g1+1][15],data_in[g1 + 1]} ;
           estm_out[g1 + 1] = data_in[g1] - data_in[g1 + 1] ;
         end

       endcase

     end
   end

 endgenerate

 //Writing data to outpurt port
 genvar g3;
 generate
   for(g3 = 0;g3 < (2*nRX) ; g3 = g3 + 1)
   begin : for_loop20
     assign  estm_out_tdata_reg[(16*g3) + (15):((16*g3) + 0)] = estm_out[g3][16:1];
   end

 endgenerate

 


endmodule
