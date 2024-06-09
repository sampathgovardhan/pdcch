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
    This Module Averages the Tones based on the Tone Average Factor
I/O Information:
------------------
	1.	Configuration Input from Controller
	2.	Q2.14*nRX input from Time Offset Correction Module
	3.	Q2.14*nRX Output to Equalizer, LLR Scaling
--------------
Date (dd/mm/yy)    	  Author 		        Description of Change
------------------------------------------------------------------
23-05-2022                  Yeshpal                 Initial Version
 */
//************************************************************************************************//
module wn_pdcchrx_freq_toneaverage
 #(
     parameter nRx = 2
 )
 (    
     //System clock
     input clk,
     //System reset
     input rstn,
     //AXIS input configuration
     input [4:0] config_in_tdata,// 3 bit - tone average factor,2 bits - number of symbols
     input config_in_tvalid,
     output reg config_in_tready,
     //AXIS input data from Frequency offset estimation module
     input [((nRx * 32) - 1) : 0] data_in_tdata,
     input data_in_tvalid,
     output reg data_in_tready,
     input data_in_tlast,
     //AXIS output - tdata,tready , tvalid , tlast
     output reg [((nRx * 32) - 1) : 0] data_out_tdata, //  Q2.14 format for each real and imag value
     output reg data_out_tvalid,
     input data_out_tready,
     output reg data_out_tlast
 
 
 );
 
 //Registering input and output port
 reg [4:0] config_in_tdata_reg;
 reg config_in_tvalid_reg;
 reg config_in_tready_reg;
 
 
 reg [((nRx * 32) - 1) : 0] data_in_tdata_reg;
 
 reg data_in_tvalid_reg;
 reg data_in_tready_reg;
 reg data_in_tlast_reg;
 
 wire [((nRx * 32) - 1) : 0] data_out;
 reg [((nRx * 32) - 1) : 0] data_out_tdata_reg; 
 reg data_out_tvalid_reg;
 reg data_out_tready_reg;
 reg data_out_tlast_reg;

//variables to store parameter values
 wire [2:0] avg_factor;
 wire [1:0] num_symbols;
 //Scaling variable
 reg [16:0] scaling_factor;


 reg [3:0] count , count_max;

 //Signed Variable for storing input data
 reg signed [15:0] data_in1 [0 : ((2 * nRx) - 1)];
 //variable for storing sum
 reg signed [19:0] sum [0 : ((2 * nRx) - 1)];

 //Scaling variable
 wire signed [17:0] scale_wire;
 reg [2:0] scale_count;
 
 
//Flag
 reg sum_flag;
 reg [1:0] sym_index;

 //storing some parameter values
 assign avg_factor = config_in_tdata_reg[2:0];
 assign num_symbols = config_in_tdata_reg[4:3];

 //Variable for storing scaled sum
 reg signed [36:0] scaled_sum[0 : ((2 * nRx) - 1)];//Q7.30


 localparam RD_CONFIG = 0,WR_DATA = 1,WAIT = 2,RD_DATA = 3,RD_DATA1 = 4,SCALE = 5,WAIT1 = 6;
//state variable
 reg [2:0] state,next_state;

 //Sequential block for Registering all inputs
 always @(posedge clk)
 begin
     config_in_tvalid_reg <= config_in_tvalid;
     data_in_tvalid_reg <= data_in_tvalid;
     data_out_tready_reg <= data_out_tready;
     data_in_tready_reg <= data_in_tready;
 end

 assign scale_wire = {1'd0,scaling_factor};

 //Performing scaling
 genvar g1;

 generate
    for(g1 = 0;g1 < (2 * nRx); g1 = g1 +2)
    begin : for_loop8
        always @(posedge clk)
        begin
            
        
        scaled_sum[g1] <= sum[g1] * scale_wire;
        scaled_sum[g1 + 1] <= sum[g1 + 1] * scale_wire;
        end
    end


 endgenerate

//Storing input values in signed variables
 genvar g2;
 generate 
 
  for(g2 = 0;g2 < (2 * nRx); g2 = g2 +2)
  begin : for_loop9
      always @(posedge clk)
      begin
          
          if(data_in_tvalid_reg && data_in_tready_reg )
          begin
              
             data_in1[g2] <= data_in_tdata_reg[((g2 * 16) + 15):(g2 * 16 )] ;//Real value
             data_in1[g2 + 1] <= data_in_tdata_reg[(((g2 + 1) * 16) + 15):((g2 + 1)* 16 )] ;//Imag value 
          
             sum_flag <= 1;
 
 
          end
          else
            sum_flag <= 0;
 
 
 
      end
  end
 endgenerate

 //Accumulatimg the sum
  genvar g3;

  generate
    for(g3=0; g3 < (2 * nRx) ; g3 = g3 + 2)
    begin : for_loop10
        always @(posedge clk)
        begin

            if(state == RD_CONFIG || count == 0)
            begin
             sum[g3] <= 0;
             sum[g3 + 1] <= 0;
            end

            else
                begin
            if(sum_flag == 1)
            begin
                sum[g3] <= sum[g3] + data_in1[g3];//Q6.14
                sum[g3 + 1] <= sum[g3 + 1] + data_in1[g3 + 1];
            end
            else
                begin 
                    if(state == RD_DATA1)
                    begin
                        sum[g3] <= data_in1[g3];
                        sum[g3 + 1] <= data_in1[g3 + 1];
                    end
                    else
                        begin
                    sum[g3] <= sum[g3];
                    sum[g3 + 1] <= sum[g3 + 1];
                        end
                end

            end


        end
    end

  endgenerate


  //Writing data
genvar g4;
generate
  for(g4 = 0;g4 < (2*nRx) ; g4 = g4 + 1)
  begin : for_loop11
   assign  data_out[(16*g4) + (15):((16*g4) + 0)] = scaled_sum[g4][31:16];//Changing format from 7.30 to 2.14
  end

endgenerate
 
 always @(posedge clk)
 begin
     if(!rstn)
     state <= RD_CONFIG;
     else
         state <= next_state;
 end


//Combinational block 
 always @(*)
 begin
     next_state = RD_CONFIG;

     case(state)

     RD_CONFIG: begin
                 if(config_in_tready && config_in_tvalid)
                  next_state = WAIT;
                  else
                    next_state = RD_CONFIG;
                end


    WAIT:    begin
                 next_state = RD_DATA;
               end

     RD_DATA:begin
                 if(data_in_tvalid && data_in_tready)
                 begin
                    if(count == count_max - 1)
                     next_state = SCALE;
                     else
                        next_state = RD_DATA;
                 end
                 else
                    next_state = RD_DATA;

                   
               end

     SCALE:begin
                if(scale_count > 2)
                begin
                 next_state = WAIT1;
                  end
                  else
                    next_state = SCALE;
                  end

     WAIT1:begin
             next_state = WR_DATA;
         
              end

    WR_DATA:begin
               if(data_out_tready)
               begin
                
                   if(count == 2)
                   next_state = RD_DATA1;
                   else
                    begin
                        if(data_in_tlast_reg)
                        begin
                        if(sym_index < 1)
                        next_state = RD_CONFIG;
                        else
                    next_state = RD_DATA;
                        end
                        else
                            next_state = RD_DATA;

                    end
               end

               else
                next_state = WR_DATA;
             end


    RD_DATA1:begin
               if(data_in_tready && data_in_tvalid)
                 next_state = SCALE;
                 else
                    next_state = RD_DATA1;
                   
               end


     endcase

 end

//Sequential block
 always @(posedge clk)
 begin
     data_out_tvalid_reg <= 0;
     data_out_tlast_reg <= 0;
     case(state)
       RD_CONFIG:begin
           //Reading input configuration
                  if(config_in_tready && config_in_tvalid)
                    config_in_tdata_reg <= config_in_tdata;
                      count <= 0;
                  end

        WAIT:   begin
                //Intializing counters and some other variables based on input config
                 sym_index <= num_symbols;
                     if(avg_factor == 2)
                     begin
                         count_max = 2;
                         scaling_factor <= 17'd23167;//(0.5*0.707) in 1.16 format
                     end
                     else if(avg_factor == 3)
                        begin
                            count_max = 3;
                            scaling_factor <= 17'd15443;//(1/3)*0.707 in 1.16 format

                        end
                        else
                            begin
                            count_max = 6;
                            scaling_factor <= 17'd7722;//(1/6)*0.707 in 1.16 format

                            end
                 end


       RD_DATA:begin
           //Reading input data from TOC module
                  if(data_in_tvalid && data_in_tready)
                  begin
                      data_in_tdata_reg <= data_in_tdata;
                      data_in_tlast_reg <= data_in_tlast;
                      count <= count + 1'b1;
                  end
                  else 
                    begin

                     count <= count;

                    end
                     scale_count <= 0;

                 end

                 SCALE:begin
         
                    scale_count <= scale_count + 1'b1;
                   end

        WAIT1:begin
            //Wait till we Averaged all the symbols 
              if(data_in_tlast_reg)
              sym_index <= sym_index - 2'd1;
              else
                sym_index <= sym_index;
            
               end

        WR_DATA:begin
            //Write state
                if(data_out_tready)
                begin
                    data_out_tdata_reg <= data_out;
                    data_out_tvalid_reg <= 1;
                    data_out_tlast_reg <= data_in_tlast_reg;
                    if(count ==2)
                     count <= count;
                     else
                        count <= 0;
                end

                else
                    begin
                        
                    end
                 end
        RD_DATA1:begin
                //State for reading third input ,in case of avgfactor =2
                 if(data_in_tready && data_in_tvalid)
                   begin
                       data_in_tdata_reg <= data_in_tdata;
                        data_in_tlast_reg <= data_in_tlast;
                       count <= count + 1'b1;
                   end
                   else
                    begin
                        count <= count;
                    end
                     scale_count <= 0;
                  end


     endcase



 end


 //Writing Output
 always @(*)
 begin
     data_out_tdata = data_out_tdata_reg;
     data_out_tvalid = data_out_tvalid_reg;
     data_in_tready = ((state == RD_DATA || state == RD_DATA1) && rstn == 1) ? 1 : 0;
     config_in_tready = (state == RD_CONFIG && rstn == 1) ? 1 : 0;
     data_out_tlast = data_out_tlast_reg;
 end
 

endmodule