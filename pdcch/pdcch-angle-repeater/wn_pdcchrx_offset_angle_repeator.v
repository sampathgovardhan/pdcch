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
    This Module generates repetitive offset angle values for offset correction module
I/O Information:
------------------
	1.	Configuration Input from Controller
	2.	Q1.23 for both real and imaginary input from TOE or FOE Module
	3.	Q1.23 for both real and imaginary Output to offset correction module
--------------
Date (dd/mm/yy)    	  Author 		        Description of Change
------------------------------------------------------------------
24-06-2022               Yeshpal                 Initial Version
 */
//************************************************************************************************//
 module wn_pdcchrx_offset_angle_repeator
 #(
    parameter nRx = 2
  )
  (
    //System clock
    input clk,
    //System reset
    input rstn,
    //AXIS input configuration
    input [8:0] config_in_tdata,//1-bit interleaver flag, 2 bits - number of symbols,6 bits - frequency domain resource
    input config_in_tvalid,
    output wire config_in_tready,
    //AXIS input data from modulation removal module
    input [47:0] data_in_tdata,//Q1.23 for both real and imaginary values
    input data_in_tvalid,
    output wire data_in_tready,
    input data_in_tlast,
    //AXIS output - tdata,tready , tvalid , tlast
    output wire [47:0] data_out_tdata, //  Q1.23 format for each real and imag value
    output wire data_out_tvalid,
    input data_out_tready,
    output wire data_out_tlast


  );

 //Registering input and output port
 wire [8:0] config_in_tdata_reg;
 wire config_in_tvalid_reg;
 wire config_in_tready_reg;
 reg [8:0] rd_config_in_tdata_reg;

 wire data_in_tvalid_reg;
 wire data_in_tready_reg;
 wire data_in_tlast_reg;
 wire [47:0] data_in_tdata_reg;
 reg [47:0] rd_data_in_tdata_reg;

 wire data_out_tvalid_reg;
 wire data_out_tready_reg;
 wire data_out_tlast_reg;
 wire [47:0] data_out_tdata_reg;
 reg [47:0] data_out;
 reg data_valid;
 reg data_last;

  //Number of pdcch symbols
 wire [1:0] num_symbols;
 //Number of PDCCH PRB
 wire [5:0] num_prb;
 //Interleaver flag
 wire [0:0] interleaver_flag;
//Variable which tells how much data you have to store
 reg [8:0] store_max;
//Some local counters
 reg [8:0] count;
 reg [8:0] count_max,count2;
//Symbol index counter
 reg [1:0] sym_index;

 //BRAM to store incoming values
 // size of BRAM(max) = (45 * 6) = 270 , we will 1 value per prb for interleaving case 
 reg [47:0] mem [0:271];
 //Memory address variable
 reg [8:0] addr;

 //Skid buffer for input config port

 skidbuffer #(
              .DW(9)
            ) inst_in1 (
              .clock(clk),
              .reset(~rstn),
              .input_tvalid(config_in_tvalid),
              .input_tready(config_in_tready),
              .input_tdata(config_in_tdata),
              .output_tvalid(config_in_tvalid_reg),
              .output_tready(config_in_tready_reg),
              .output_tdata(config_in_tdata_reg)
            );


 //skid buffer for input data port

 wn_skid_buffer
   #(
     .DW (
       48 )
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
       48 )
   )
   inst_out (
     .clock (clk ),
     .reset (~rstn ),
     .input_tvalid (data_out_tvalid_reg ),
     .input_tready (data_out_tready_reg ),
     .input_tdata (data_out_tdata_reg ),
     .input_tlast (data_out_tlast_reg ),
     .output_tvalid (data_out_tvalid ),
     .output_tready (data_out_tready ),
     .output_tdata (data_out_tdata ),
     .output_tlast  ( data_out_tlast)
   );

 //storing some parameter values
 assign num_symbols = rd_config_in_tdata_reg[1:0];
 assign num_prb = rd_config_in_tdata_reg[7:2];
 assign interleaver_flag = rd_config_in_tdata_reg[8];

 localparam RD_CONFIG = 0, WAIT = 1, STORE = 2, WR_DATA = 3, WAIT1 = 4,WR_LAST = 5;
 //state varaiable
 reg [2:0] state,next_state;


 always @(posedge clk)
 begin
   if(!rstn)
     state <= RD_CONFIG;
   else
     state <= next_state;

 end

 //Storing incoming data in BRAM
 always @(posedge clk)
 begin

   if(state == STORE || state == WAIT1 )
     mem[addr] <= rd_data_in_tdata_reg;
 end

 //Combinational block
 always @(*)
 begin
   next_state = RD_CONFIG;
   case(state)

     RD_CONFIG:
     begin
       if(config_in_tvalid_reg && config_in_tready_reg)
         next_state = WAIT;
       else
         next_state = RD_CONFIG;

     end

     WAIT:
     begin
       next_state = STORE;

     end


     STORE:
     begin
       if(data_in_tlast_reg)

         next_state = WAIT1;
       else
         next_state = STORE;

     end

     WAIT1:
     begin

       next_state = WR_DATA;



     end



     WR_DATA:
     begin
       if( sym_index == 1 && count2 == count_max - 1 && addr == store_max && data_out_tready_reg)
         next_state = WR_LAST;
       else
         next_state = WR_DATA;

     end





     WR_LAST:
     begin
       if(data_out_tready_reg)
         next_state = RD_CONFIG;
       else
         next_state = WR_LAST;
     end





   endcase
 end

 always @(posedge clk)
 begin
   case(state)

     RD_CONFIG:
     begin
       if(config_in_tvalid_reg && config_in_tready_reg)
         rd_config_in_tdata_reg <= config_in_tdata_reg;
       data_valid <= 0;
       data_last <= 0;

     end

     WAIT:
     begin
       //Wait state to initialise some counters and parameter
       sym_index <= num_symbols;
       

       addr <= 0;

       count <= 1;
       count2 <= 0;
       /*
         The TOE or FOE modules will give one data per CCE.
         But we need 1 value per PRB for performing offset correction

       */

       if(interleaver_flag)
       begin
         
         store_max <= num_prb * 6;
         count_max <= 1;//we will get 1 value per prb from TOE or FOE module 


       end
       else
         begin
       if(num_symbols == 1)
       begin
         store_max <= num_prb;
         count_max <= 6;//we will get 1 value per CCE from TOE or FOE module , so will repeat each value 6 times to get 1 value per prb as number of symbols is 1
       end

       else if (num_symbols == 2)
       begin
         store_max <= num_prb * 2;
         count_max <= 3;//we will get 1 value per CCE from TOE or FOE module , so will repeat each value 3 times to get 1 value per prb as number of symbols is 2
       end
       else
       begin
         store_max <= num_prb * 3;
         count_max <= 2;//we will get 1 value per CCE from TOE or FOE module , so will repeat each value 2 times to get 1 value per prb as number of symbols is 1
       end

     end
   end


     STORE:
     begin
       if(data_in_tvalid_reg && data_in_tready_reg)
       begin
         rd_data_in_tdata_reg <= data_in_tdata_reg;
         addr <= addr + 1'b1;
       end


     end

     WAIT1:
     begin
       //resetting BRAM address after storing
       addr <= 1;


     end

     WR_DATA:
     begin

       if(data_out_tready_reg)
       begin
       if(interleaver_flag)
       begin
       if(count2 == count_max -1)
       begin
       count2 <= 0;
        if(addr == store_max)
           begin
             addr <= 1;
             data_last <= 1;
             sym_index <= sym_index - 2'd1;
             
           end
       else
            begin
              addr <= addr + 1'b1;
              count <= count + 1'b1;
              data_last <= 0;
            end
       
       end
       else
       begin
       addr <= addr + 1'b1;
             data_last <= 0;
             count2 <= count2 + 1'b1;
       
       end
       
       
       end
       else
       begin
         if(count2 == count_max - 1)
         begin
           count2 <= count2 + 1'b1;

           if(addr == store_max)
           begin
             addr <= 1;
             data_last <= 1;
             sym_index <= sym_index - 2'd1;
             count <= 1;
           end
           else
           begin
             addr <= addr + 1'b1;
             count <= count + 1'b1;
             data_last <= 0;
           end

         end
         else if (count2 == count_max)
         begin

           count2 <= 1;
           data_last <= 0;

         end
         else
         begin
           count2 <= count2 + 1'b1;
           data_last <= 0;
         end
         end




         data_out <= mem[addr];
         data_valid <= 1;
       

     end

     end




     WR_LAST:
     begin
       //writing last data
       if(data_out_tready_reg)
       begin
         data_valid <= 0;
         data_last <= 0;
       end

     end






   endcase

 end

 //Writing Output

 assign data_out_tdata_reg = data_out;
 assign data_out_tvalid_reg = data_valid;
 //asserting input tready
 assign data_in_tready_reg = ((state == STORE )  && rstn == 1) ? 1 : 0;
 assign config_in_tready_reg = (state == RD_CONFIG && rstn == 1) ? 1 : 0;
 assign data_out_tlast_reg = data_last;




endmodule
