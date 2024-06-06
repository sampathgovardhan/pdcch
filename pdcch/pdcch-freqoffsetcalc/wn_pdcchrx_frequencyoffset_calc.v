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
This Module Estimates the Frequency Offset Phasor and sends it to CORDIC Vector Module
for Angle calculation
 
I/O Information:
------------------
1. configuration Input from the Controller
2. Q2.14 * nRX input to from Time Offset module
3. Q1.23 complex data Output to CORDIC Vector
--------------
Date (dd/mm/yy)    	  Author 		        Description of Change
------------------------------------------------------------------
  01-06-2022         Yeshpal                  Initial Version
 */
//******************************************************************************************
 module wn_pdcchrx_frequencyoffset_calc
 #(
    parameter nRx = 2
  )
  (
    //System clock
    input clk,
    //System reset
    input rstn,
    //AXIS input configuration
    input [12:0] config_in_tdata,// 1 bit - frequency offset flag,2 bits - number of symbols,1 bit - interleaver flag, 9 bits - frequency domain resource
    input config_in_tvalid,
    output wire config_in_tready,
    //AXIS input data from time offset correction module
    input [((nRx * 32) - 1) : 0] data_in_tdata,
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
 wire [12:0] config_in_tdata_reg;
 reg [12:0] rd_config_in_tdata_reg;
 wire config_in_tvalid_reg;
 wire config_in_tready_reg;


 wire [((nRx * 32) - 1) : 0] data_in_tdata_reg;
 reg [((nRx * 32) - 1) : 0] rd_data_in_tdata_reg;
 reg rd_data_in_tvalid_reg,rd_data_in_tready_reg;
 wire data_in_tvalid_reg;
 wire data_in_tready_reg;
 wire data_in_tlast_reg;

 wire data_out_tvalid_reg;
 reg r_valid,r_last;
 wire data_out_tready_reg;
 wire data_out_tlast_reg;
 wire [47:0] data_out_tdata_reg;

 // frequency offset flag -> 1 - frequency offset ON , 0 - frequency offset OFF
 wire frequencyoffset_flag;
 // interleaver flag
 wire intleaver_flag;
 // number of pdcch symbols
 wire [1:0] num_symbols;
 // number of PRBs
 wire [8:0] num_prb;
 reg [16:0] scaling_factor;




 //Flag for stalling pipeline, when pipeline is full and output tready is zero
 reg stall_flag;

 //Variable for storing intermediate value just before final complex multiplication
 reg signed [31:0] mul_1[0 : ((2 * nRx) - 1)];
 reg signed [31:0] mul_2[0 : ((2 * nRx) - 1)];
 reg signed [31:0] mul_3[0 : ((2 * nRx) - 1)];
 reg signed [31:0] mul_4[0 : ((2 * nRx) - 1)];

 //The result of mul_1,mul_2,mul_3,mul_3 registered fist time
 //This is done to avoid any timing violations during synthesis.
 reg signed [31:0] mul_d1[0 : ((2 * nRx) - 1)];
 reg signed [31:0] mul_d2[0 : ((2 * nRx) - 1)];
 reg signed [31:0] mul_d3[0 : ((2 * nRx) - 1)];
 reg signed [31:0] mul_d4[0 : ((2 * nRx) - 1)];
 //The result of mul_1,mul_2,mul_3,mul_3 registered second time
 reg signed [31:0] mul_dd1[0 : ((2 * nRx) - 1)];
 reg signed [31:0] mul_dd2[0 : ((2 * nRx) - 1)];
 reg signed [31:0] mul_dd3[0 : ((2 * nRx) - 1)];
 reg signed [31:0] mul_dd4[0 : ((2 * nRx) - 1)];

 //Variables for storing complex multiplication result
 reg signed [34:0] mul[0 : ((2 * nRx) - 1)];
 reg signed [32:0] mul_d[0 : ((2 * nRx) - 1)];
 reg signed [32:0] mul_dd[0 : ((2 * nRx) - 1)];



 //Variable to store sum of real and imag values for each antenna
 reg signed [38:0] sum[0 : ((2 * nRx) - 1)];

 //Variable to store final real and imaginary sum of complex multiplication
 reg signed [39:0] real_sum,imag_sum;

 reg signed [23:0] real_out_reg,imag_out_reg,real_out_reg1,imag_out_reg1,real_out_reg2,imag_out_reg2;


 localparam RD_CONFIG = 0,WAIT = 1,RD_DATA = 2,NO_OFFSET=3,COMPUTE = 4,STORE = 5,NO_OFFSET_LAST = 6,WAIT_LAST =7,STORE_LAST = 8;
 //Signed Variable to store input data for signed operations
 reg signed [15:0] data_in1 [0 : ((2 * nRx) - 1)];
 reg signed [15:0] data_in2 [0 : ((2 * nRx) - 1)];
 reg signed [15:0] data_in3 [0 : ((2 * nRx) - 1)];
 //Some counters
 reg [8:0] count_max;
 reg [8:0] count_0;

 reg [8:0] wait_count;//How long to wait in a particular wait state

 reg [8:0] count;//Used for resetting sum register after first time
 reg [8:0] out_count;
 reg [8:0] last_count;//indicate last output valid data
 reg [1:0] sym_index;

 reg mul_1d,mul_2d,mul_3d,mul_4d,mul_5d;
 reg scale_1d,scale_2d,scale_3d,scale_4d,scale_5d,scale_6d,scale_7d,scale_8d,scale_9d;
 reg [4:0] sum_count,mul_count,acc_count;
 reg [3:0] state,next_state;
 //Variable to store final sum of real and imag value
 reg signed [34:0] real_sum_reg,imag_sum_reg;

 //Scaling variable
 wire signed [17:0] scale_wire;

 //Variable to store final scaled real and imag values
 reg signed [52:0] out_r,out_i;
 //The result of out_r,out_i registered two times
 //This is done to avoid any timing violations during synthesis.
 reg signed [52:0] out_r_d,out_i_d;
 reg signed [52:0] out_r_dd,out_i_dd;
 wire almost_full;


 assign scale_wire = {1'd0,scaling_factor};


 //Skid buffer for input config port

 skidbuffer #(
              .DW(13)
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
       (nRx * 32) )
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


 //Storing some paramters
 assign frequencyoffset_flag = rd_config_in_tdata_reg[0];
 assign num_symbols = rd_config_in_tdata_reg[2:1];
 assign intleaver_flag = rd_config_in_tdata_reg[3];
 assign num_prb = rd_config_in_tdata_reg[12:4];

 //! if number of symbol > 1, in that case we have to store incoming data
 // size of BRAM(max) = 270 * 3 = 810
 localparam ADDR_WIDTH = 10;

 reg en1,en2;
 reg we1,we2;
 reg [9:0] addr1,addr2;
 wire [((nRx * 32 ) - 1):0] din;
 wire [((nRx * 32 ) - 1):0] dout1,dout2;


 assign din = rd_data_in_tdata_reg;

 //BRAM1 for storing
 singleport_bram
   #(
     .DEPTH(811 ),
     .ADDR_WIDTH(ADDR_WIDTH ),
     .DATA_WIDTH ((nRx * 32) )
   )
   singleport_bram_1 (
     .clk (clk ),
     .en (en1 ),
     .we (we1 ),
     .addr (addr1),
     .din (din ),
     .dout (dout1 )
   );




 //BRAM2 for storing
 singleport_bram
   #(
     .DEPTH(811 ),
     .ADDR_WIDTH(ADDR_WIDTH ),
     .DATA_WIDTH ((nRx * 32) )//16 bits for each real and imaginary
   )
   singleport_bram_2 (
     .clk (clk ),
     .en (en2 ),
     .we (we2 ),
     .addr (addr2),
     .din (din ),
     .dout (dout2 )
   );


 always @(posedge clk)
 begin
   if(!rstn)
     state <= RD_CONFIG;
   else
     state <= next_state;
 end


 //Combinational block for next state logic
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
     WAIT    ://Setting some parameter and next state based on the configuration
     begin
       if(frequencyoffset_flag == 1)
       begin
         if(num_symbols > 1)
           next_state = STORE;//We have to store data for 2 and 3 symbols
         else
           next_state = RD_DATA;//No offset for single symbol,just read the incimg data
       end
       else
         next_state = RD_DATA;//NO ffset case

     end

     STORE://Storing incoming data
     begin
       if(data_in_tvalid_reg && data_in_tready_reg)
       begin
         if(data_in_tlast_reg && sym_index == 2)
         begin

           next_state = STORE_LAST;//once storing is done start with calculating offset
         end
         else
           next_state = STORE;

       end
       else
         next_state = STORE;
     end

     STORE_LAST:begin
          
          next_state = COMPUTE;
     
     end

     COMPUTE:
     begin
       if(data_in_tvalid_reg && data_in_tready_reg)
       begin
         if(data_in_tlast_reg )
         begin

           next_state = WAIT_LAST;
         end
         else
           next_state = COMPUTE;


       end
       else
         next_state = COMPUTE;

     end



 
     RD_DATA:
     begin
         //Reading input data , when we donot have to  calculate frequency offset
       if( data_in_tvalid_reg && data_in_tready_reg)
       begin
         if(data_in_tlast_reg && sym_index == 1)


           next_state = NO_OFFSET;
         else
           next_state = RD_DATA;



       end
       else
         next_state = RD_DATA;

     end
     NO_OFFSET://NO offset state, real = 1 and imag =0
     begin
       if(data_out_tready_reg && !almost_full)
       begin
         
           if(count_0 == 1)
            next_state = RD_CONFIG;
            else
            begin
           
           if(out_count < count_0 - 2)
           next_state = NO_OFFSET;
           else
           next_state = NO_OFFSET_LAST;
         
         
         
           end
           
          
          
       end

       else
         next_state = NO_OFFSET;

     end

     NO_OFFSET_LAST:begin
       if(data_out_tready_reg && !almost_full)
       next_state = RD_CONFIG;
       else
       next_state = NO_OFFSET_LAST;
  
  
  end


     WAIT_LAST:
     begin
      
       
             if(last_count == 13)
                next_state = RD_CONFIG;
              else
                next_state = WAIT_LAST;
       
            end



     

   endcase

 end


 always @(posedge clk)
 begin
   
   case(state)
     RD_CONFIG:
     begin
       if(config_in_tvalid_reg && config_in_tvalid_reg) //valid instead of ready
         rd_config_in_tdata_reg <= config_in_tdata_reg;
      //Resetting counters
       wait_count <= 0;
       
       out_count <= 0;
       last_count <= 0;
       
      
       //Resetting BRAM inputs
       en1 <= 0;
       we1 <= 0;
       en2 <= 0;
       we2 <= 0;
       addr1 <= 0;
       addr2 <= 0;
       
       

     end

     WAIT:
     begin
         //Intialising counter and some other variables
       sym_index <= num_symbols;
       if(frequencyoffset_flag)
       begin
       
       if(intleaver_flag)
       begin
       count_0 <= num_prb * 3'd6;
       count_max <= 3;
       
       if(num_symbols == 2)
       begin
       if(nRx == 1)
             scaling_factor <= 17'd5461;// 1 / 3*4 in Q1.16 format
           else
             scaling_factor <= 17'd2731;// 1 / 3*2*4 in Q1.16 format
         
       end
       
       else
       begin
        if(nRx == 1)
             scaling_factor <= 17'd2731;// 1 / 6*4 in Q1.16 format
           else
             scaling_factor <= 17'd1365;// 1 / 6*2*4 in Q1.16 format
       end
       
       
       end
       else
       begin
       count_0 <= num_prb;
       
       if(num_symbols == 2)
       begin
       count_max <= 9;
        if(nRx == 1)
           scaling_factor <= 17'd1820;// 1 / 9*4 in Q1.16 format
         else
           scaling_factor <= 17'd910;// 1 / 9*2*4 in Q1.16 format
       end
       
       else
       begin
       count_max <= 6;
       if(nRx == 1)
           scaling_factor <= 17'd1365;// 1 / 6*2*4 in Q1.16 format
         else
           scaling_factor <= 17'd683;// 1 / 6*2*4*2 in Q1.16 format
       end
       
       
       end
       
       
       
       end
       else
       begin
       if(intleaver_flag)
       begin
       count_0 <= num_prb * 3'd6;
       end
       else
       begin
        if(num_symbols == 1)
        begin
          count_0 <= num_prb;
        end

        else if(num_symbols == 2)
        begin
          
          count_0 <= num_prb << 1;
        end


        else
        begin
         
          count_0 <= num_prb * 3'd3;

        end
       
       end
       
       
       end
       
       


     end

     STORE:
     begin
         //Storing input data from time offset module
             /* if symbols = 2 -> we will store data for first symbol
                if symbols = 3 -> we will store data for first and second symbol
       */
       if( data_in_tvalid_reg && data_in_tready_reg)
       begin

         rd_data_in_tdata_reg <= data_in_tdata_reg;
         
         if(data_in_tlast_reg)
           sym_index <= sym_index - 2'd1;

         if(sym_index == 2)
         begin
          
           en1 <= 1;
           we2 <= 0;
           we1 <= 1;
           addr1 <= addr1 + 1'b1;
           

         end
         else if(sym_index == 3)
         begin
           en2 <= 1;
           we1 <= 0;
           we2 <= 1;
           addr2 <= addr2 + 1'b1;



         end
         else
         begin

           we1 <= 0;
           we2 <= 0;
           addr1 <= 1;
           addr2 <= 1;
           en1 <= 1;
           en2 <= 1;

         end
       end
     end
     
    STORE_LAST:begin
    we1 <= 0;
    we2 <= 0;
    addr1 <= 1;
    addr2 <= 1;
    
    end
     COMPUTE:
     begin
     if(data_in_tvalid_reg && data_in_tready_reg)
     begin
     addr1 <= addr1 + 1'b1;
     addr2 <= addr2 + 1'b1;

         rd_data_in_tdata_reg <= data_in_tdata_reg;
     end
       
       
     end
   
     



     RD_DATA:
     begin
         //Reading Data when there is no frequency offset calculation
       if(data_in_tvalid_reg && data_in_tready_reg)
       begin
         rd_data_in_tdata_reg <= data_in_tdata_reg;
         
         if(data_in_tlast_reg)
         begin
           sym_index <= sym_index - 2'd1;
         end
       end
       else
       begin
         sym_index <= sym_index;
        
         rd_data_in_tdata_reg <= data_in_tdata_reg;
       end

     end

     NO_OFFSET:
     begin
       if(data_out_tready_reg && !almost_full)
       begin
         out_count <= out_count + 1'b1;
       end
       else
         out_count <= out_count;

     end

     WAIT_LAST:
     begin

    if(data_in_tvalid_reg && data_in_tready_reg)
     begin

         rd_data_in_tdata_reg <= data_in_tdata_reg;
     end
       last_count <= last_count + 1;


     end

   endcase
 end







 //Storing input values in signed variables
 genvar g2;
 generate

   for(g2 = 0;g2 < (2 * nRx); g2 = g2 +2)
   begin : for_loop12
     always @(posedge clk)
     begin
        if(state == RD_CONFIG)
        begin
         data_in1[g2] <=  0;//Real value
         data_in1[g2 + 1] <=  0;//Imag value


        end
        else
         begin
          
             if(mul_1d) 
             begin

              data_in1[g2] <= rd_data_in_tdata_reg[((g2 * 16) + 15):(g2 * 16 )] ;//Real value
            data_in1[g2 + 1] <= rd_data_in_tdata_reg[(((g2 + 1) * 16) + 15):((g2 + 1)* 16 )];//Imag value
         
               end

          
         end
     end
   end

 endgenerate
 
 //Fetching data from BRAM
 genvar g1;
 generate

   for(g1 = 0;g1 < (2 * nRx); g1 = g1 +2)
   begin : for_loop13
     always @(posedge clk)
     begin
      if(state == RD_CONFIG)
        begin
         data_in2[g1] <= 0;
             data_in2[g1 +1] <= 0;
             data_in3[g1] <= 0;
             data_in3[g1 +1] <= 0;


        end
        else
        begin

            if(mul_1d )
            begin
             data_in2[g1] <= dout1[((g1 * 16) + 15):(g1 * 16 )] ;
             data_in2[g1 +1] <= dout1[(((g1 + 1) * 16) + 15):((g1 + 1)* 16 )];
             data_in3[g1] <= dout2[((g1 * 16) + 15):(g1 * 16 )] ;
             data_in3[g1 +1] <= dout2[(((g1 + 1) * 16) + 15):((g1 + 1)* 16 )];
             end

      end
     end
   end

 endgenerate

 always @(posedge clk)
begin
   if(state == RD_CONFIG)
   mul_1d <= 0;
   else if(state == COMPUTE)
   mul_1d <= (data_in_tvalid_reg && data_in_tready_reg );
   else
   mul_1d <= 0;

   if(state == RD_CONFIG)
   begin
       mul_2d <= 0;
   mul_3d <= 0;
   mul_4d <= 0;
   mul_5d <= 0;


   end
   else
       begin
   mul_2d <= mul_1d;
   mul_3d <= mul_2d;
   mul_4d <= mul_3d;
   mul_5d <= mul_4d;
       end
end


//Intermediate result of Complex Multiplication
 /*
  let's say two complex number 
  (r1 + j i1) + (r2 - j i2) = (r1 * r2 + i1 * i2) + j (r1 * i2 - i1 * r2)
 */
 genvar g3;
 generate

   for(g3 = 0;g3 < (2 * nRx); g3 = g3 +2)
   begin : for_loop14

     always @(posedge clk)
     begin
      
       mul_1[g3] <= data_in1[g3] * data_in2[g3];//Q2.14 * Q2.14 = Q4.28  -> (r1 * r2)
       mul_1[g3+1] <= data_in1[g3 + 1] * data_in2[g3 + 1];//Q2.14 * Q2.14 = Q4.28 -> (i1 *i2)
       mul_2[g3] <= data_in1[g3] * data_in2[g3 + 1];//Q2.14 * Q2.14 = Q4.28 -> (r1 * i2)
       mul_2[g3 + 1] <= data_in2[g3] * data_in1[g3 + 1];//Q2.14 * Q2.14 = Q4.28 -> (r2 * i1)
       mul_3[g3] <= data_in2[g3] * data_in3[g3];//Q2.14 * Q2.14 = Q4.28
       mul_3[g3+1] <= data_in2[g3 + 1] * data_in3[g3 + 1];//Q2.14 * Q2.14 = Q4.28
       mul_4[g3] <= data_in2[g3] * data_in3[g3 + 1];//Q2.14 * Q2.14 = Q4.28
       mul_4[g3 + 1] <= data_in3[g3] * data_in2[g3 + 1];//Q2.14 * Q2.14 = Q4.28
     

     end
   end



 endgenerate

 //complex multiplication
 genvar g5;
 generate

   for(g5 = 0;g5 < (2 * nRx); g5 = g5 +2)
   begin : for_loop15
     always @(posedge clk)
     begin
       //if(mul_flag2)
       if(state == RD_CONFIG)
       begin
       
        mul[g5] <= 0;
        mul[g5 + 1] <= 0;
       end
       
      else
      begin
       if(mul_3d)
       begin
         if(num_symbols == 2)
         begin
           mul[g5] <= mul_1[g5] + mul_1[g5 + 1];//Q4.28 + Q4.28 = Q5.28  -> (r1 * r2 + i1 * i2)
           mul[g5 + 1] <=  mul_2[g5 + 1] - mul_2[g5];//Q4.28 + Q4.28 = Q5.28 -> (r1 * i2 - i1 * r2)
         end
         else
         begin
           mul[g5] <= mul_1[g5] + mul_1[g5 + 1] + mul_3[g5] + mul_3[g5 + 1];//Q4.28 + Q4.28+Q4.28 + Q4.28 = Q7.28
           mul[g5 + 1] <=  mul_2[g5 + 1] - mul_2[g5] + mul_4[g5 + 1] - mul_4[g5];//Q4.28 + Q4.28 + Q4.28 + Q4.28= Q7.28

         end

       end
       else
       begin
         mul[g5] <= mul[g5];
         mul[g5 + 1] <= mul[g5 + 1];

       end
     end
     end
   end




 endgenerate

 always @(posedge clk)
 begin
 
 if(state == RD_CONFIG)
 
 sum_count <= 0;
 
 else
 begin
 if(mul_4d)
 begin
     if(sum_count == count_max)
     begin
 
     sum_count <= 1;
     end
     else
 sum_count <= sum_count + 1'b1;
 end
 else
 sum_count <= sum_count;
 
 
 end
 end

 always @(posedge clk)
begin
if(state == RD_CONFIG)

acc_count <= 0;

else
begin
if(mul_5d)
begin
   if(acc_count == count_max - 1)
   begin

   acc_count <= 0;
   end
   else
acc_count <= acc_count + 1'b1;
end
else
acc_count <= acc_count;


end
end

 

 //Accumulating real and imag values after complex multiplication for each antenna
 genvar g4;
 generate
   //begin
   for(g4 = 0;g4 < (2 * nRx); g4 = g4 +2)
   begin : for_loop18
     always @(posedge clk)
     begin

       //Reset accumulator
       if(state == RD_CONFIG )
       begin
         sum[g4] <= 0;
         sum[g4 + 1] <= 0;
       end

       else
       begin
        
         if(mul_4d)
         begin//Accumulating
           if(sum_count == count_max)
           begin
             sum[g4] <= mul[g4];//Q11.28
             sum[g4 + 1] <= mul[g4 + 1];//Q11.28
           end
           else
           begin
            
               sum[g4] <= sum[g4] + mul[g4];//Q11.28
               sum[g4 + 1] <= sum[g4 + 1] + mul[g4 + 1];//Q11.28
             end
            
         end

         
         else
         begin

           sum[g4] <= sum[g4];
           sum[g4 + 1] <= sum[g4 + 1];
         end
       end

     end
   end

 endgenerate
   







 //Registering multiplier output
 always @(posedge clk)
 begin
   
   if(scale_1d)
   begin
     imag_sum_reg <= imag_sum[39:5];//Changing format from Q11.28 to Q11.23
     real_sum_reg <= real_sum[39:5];//Changing format from Q11.28 to Q11.23
   end

   scale_2d <= scale_1d;
   
 end

 //Performing Scaling
 always @(posedge clk)
 begin
   
   out_r <= scale_wire * real_sum_reg;//Q1.16 * Q11.23 = Q12.39
   out_i <= scale_wire * imag_sum_reg;//Q1.16 * Q11.23 = Q12.39
   scale_3d <= scale_2d;
  scale_4d <= scale_3d;
  scale_5d <= scale_4d;
  
   //Registering two times
   out_r_d <=  out_r;
   out_i_d <=  out_i;
   out_r_dd <=  out_r_d;
   out_i_dd <=  out_i_d;

  

 end

 always @(posedge clk)
 begin

   scale_6d <= scale_5d;
   scale_7d <= scale_6d;
   if(scale_5d )
   begin
     real_out_reg2 <= out_r_dd[39:16];//Changing format from Q12.39 to Q1.23
     imag_out_reg2 <= out_i_dd[39:16];//Changing format from Q12.39 to Q1.23
    
   end
   else
   begin
     if(state == NO_OFFSET )
     begin
       real_out_reg <= 24'b011111111111111111111111;//0.999999 in Q1.23 format  //real_out_reg2? and is not used in output.
       imag_out_reg <= 0;//0
     end

   end

    //Adding one more stage of registers to meet the fmax requirements
   real_out_reg <= real_out_reg2;
   imag_out_reg <= imag_out_reg2;


 end

 //Accumulating final sum
 always @(posedge clk)
 begin

   if(nRx == 2)
   begin
     if( mul_5d && acc_count == count_max - 1)
     begin
       real_sum <= sum[0] + sum[2];
       imag_sum <= sum[1] + sum[3];

       scale_1d <= 1;
     end
     else
       begin
         real_sum <= real_sum;
         imag_sum <= imag_sum;
         scale_1d <= 0;

       end
   end
   else
   begin
     if( mul_5d && acc_count == count_max - 1)
     begin
       real_sum <= sum[0];
       imag_sum <= sum[1];
     end

     begin
       real_sum <= real_sum;
       imag_sum <= imag_sum;
       scale_1d <= 0;

   end
   end


 end



 //Writing Output
 
 assign data_out_tdata_reg = (state == NO_OFFSET || state == NO_OFFSET_LAST )? {24'd0,24'b011111111111111111111111} : {imag_out_reg,real_out_reg};
 assign data_out_tvalid_reg = (scale_7d && ( state == COMPUTE || state == WAIT_LAST)) || ((state == NO_OFFSET || state == NO_OFFSET_LAST) && !almost_full );
 assign data_in_tready_reg = (!almost_full && state == COMPUTE) || (state == STORE) || (state == RD_DATA);
 assign config_in_tready_reg = (state == RD_CONFIG ) ? 1 : 0;
 assign data_out_tlast_reg = (scale_7d && last_count == 11)||( state == NO_OFFSET_LAST || (state == NO_OFFSET && count_0 == 1) );

 


 // Parameters
localparam  DATA_WIDTH = 49;
localparam  FIFO_DEPTH = 16;
localparam  ALMOST_FULL_FLAG_DEPTH = 3;

// Ports

//  reg [DATA_WIDTH-1:0] s_axis_tdata;
//  reg s_axis_tvalid;
//  reg s_axis_tready;
 
//  wire [DATA_WIDTH-1:0] m_axis_tdata;
//  wire m_axis_tvalid;
//  reg m_axis_tready;

wn_axis_fifo_mlab 
#(
  .DATA_WIDTH(DATA_WIDTH ),
  .FIFO_DEPTH(FIFO_DEPTH ),
  .ALMOST_FULL_FLAG_DEPTH (
      ALMOST_FULL_FLAG_DEPTH )
)
wn_axis_fifo_mlab_dut (
  .clock (clk ),
  .reset_n (rstn ),
  .s_axis_tdata ({data_out_tlast_reg,data_out_tdata_reg} ),
  .s_axis_tvalid (data_out_tvalid_reg ),
  .s_axis_tready (data_out_tready_reg ),
  .almost_full (almost_full ),
  .m_axis_tdata ({data_out_tlast,data_out_tdata} ),
  .m_axis_tvalid (data_out_tvalid ),
  .m_axis_tready  ( data_out_tready)
);

endmodule
