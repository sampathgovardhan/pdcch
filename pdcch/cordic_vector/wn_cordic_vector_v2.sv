//! @copyright
//! Copyright (c) 2016-2022, WiSig Networks Pvt Ltd. All rights reserved. www.wisig.com
//! All information contained herein is property of WiSig Networks Pvt Ltd. unless otherwise
//! explicitly mentioned.
//! The intellectual and technical concepts in this file are proprietary to WiSig Networks and
//! may be covered by granted or in process national and international patents and are
//! protect by trade secrets and copyright law.
//! Redistribution and use in source and binary forms of the content in this file, with or
//! without modification are not permitted unless permission is explicitly granted by WiSig Networks.
//!
//! @author @nikhil-wisig
//! @version 1.0
//! @date 29-06-2022
//!
//! @brief module for cordic vector with output in unsigned Q0.16 format instead of
//! Q1.15 being used in cordic_vector_v2. This module will be merged with cordic_vector.sv once
//! the Q formats in PDCCH are taken care of.
//!
//! module to compute angle "t" from the input e^jt using cordic vector method. Note that the
//! magnitude of the input needs to be < 1. In other words the q format of the input has to be
//! in the form of signed Q1.(W - 1).

`timescale 1ns / 1ps

module wn_cordic_vector_v2 #(
    //! total number of bits for input including real and imaginary
    //! is typically 16x2 = 32 bits but 24x2 = 48 is required in some cases
    parameter int DW_IN = 32,
    //! number of bits for output angle
    parameter int DW_ANGLE = 16,
    //! number of bits to represent the sign of x & y a.k.a the quadrant in which the angle lies
    parameter int DW_SIGN = 2,
    //! total number of bits for output
    parameter int DW_OUT = DW_ANGLE + DW_SIGN,
    //! enable or disable input skid buffers
    parameter int ENABLE_IN_SKID = 1,
    //! enable or disable output skid buffers
    parameter int ENABLE_OUT_SKID = 1,
    //! enable or disable pipelining. Module does not support pipelining currently
    parameter int PIPELINING = 0
  ) (
    //! System Clock
    input clk,
    //! Reset - Negedge triggered
    input reset_n,

    //! @virtualbus data_in @dir in AXIS bus for input data
    //! input data - axis port
    input logic [DW_IN - 1:0] s_tdata,
    //! input valid - axis port
    input logic s_tvalid,
    //! input ready - axis port
    output logic s_tready,  //! @end

    //! @virtualbus data_out @dir out AXIS bus for output data
    //! data output - axis port
    output logic [DW_OUT - 1:0] m_tdata,
    //! valid output - axis port
    output logic m_tvalid,
    //! ready output axis port
    input logic m_tready  //! @end
  );
  //! number of iterations is equal to the number of fractional bits used to represent
  //! the output
  localparam NUM_ITERATIONS = 15;
  localparam int DW_REAL = DW_IN/2;

  //! The intermediate value of x can increase to upto sqrt(2) * A = 1.414 * 1.64676025 = 2.3289
  //! assuming input is Q1.15 or Q1.23, implies the intermediate x,y variables are Q3.15 or Q3.23
  localparam int DW_X = DW_REAL + 2;
  //! max value for saturation
  localparam int MAX_POS_VALUE = {1'b0, {(DW_X - 1) {1'b1}}};

  //! input data internal variables
  logic s_tvalid_i;
  logic [DW_IN - 1:0] s_tdata_i;
  logic s_tready_i;

  //! output data internal variable
  logic [DW_OUT - 1:0] m_tdata_i;
  logic m_tvalid_i;
  logic m_tready_i;

  //! register for storing sign
  logic [DW_SIGN - 1:0] sign_in;

  //! intemediate registers in the pipeline
  //! (x,y) here represent the real and imag values of the output
  //! z represents the angle
  logic signed [DW_ANGLE:0] z;
  logic signed [DW_X - 1:0] x, y;

  //! state variables
  enum reg [1:0] {
         RD_DATA,
         COMPUTE,
         WR_DATA
       } state, next;

  //! counter to count number of iterations
  logic [3:0] iteration;

  //! atan table in signed Q1.16 format.
  logic [DW_ANGLE:0] atan_table[16];
  initial
  begin
    //! atan table is in signed Q1.16 format and is using binary angles (i.e., 1/2 for pi/2)
    //! though the input is in [0, 0.5] range, the value of z can go negative so to maintain
    //! q formats across all additions, signed Q1.16 format is used
    atan_table = '{
                 'd16384,
                 'd9672,
                 'd5110,
                 'd2594,
                 'd1302,
                 'd652,
                 'd326,
                 'd163,
                 'd81,
                 'd41,
                 'd20,
                 'd10,
                 'd5,
                 'd3,
                 'd1,
                 'd1
               };

    if(DW_ANGLE != 16)
    begin
      $fatal("Only DW_ANGLE = 16 is supported. Change the atan table to add support for other widths");
    end
  end

  generate
    if (ENABLE_IN_SKID)
    begin
      //! skid buffer for input data
      halfbuffer #(
                   .DW(DW_IN)
                 ) inst_in (
                   .clk(clk),
                   .reset_n(reset_n),
                   .s_tvalid(s_tvalid),
                   .s_tready(s_tready),
                   .s_tdata(s_tdata),
                   .m_tvalid(s_tvalid_i),
                   .m_tready(s_tready_i),
                   .m_tdata(s_tdata_i)
                 );
    end
    else
    begin
      assign s_tvalid_i = s_tvalid;
      assign s_tdata_i  = s_tdata;
      assign s_tready   = s_tready_i;
    end

    if (ENABLE_OUT_SKID)
    begin
      //! skid buffer for data output
      halfbuffer #(
                   .DW(DW_OUT)
                 ) inst_out (
                   .clk(clk),
                   .reset_n(reset_n),
                   .s_tvalid(m_tvalid_i),
                   .s_tready(m_tready_i),
                   .s_tdata(m_tdata_i),
                   .m_tvalid(m_tvalid),
                   .m_tready(m_tready),
                   .m_tdata(m_tdata)
                 );
    end
    else
    begin
      assign m_tdata = m_tdata_i;
      assign m_tvalid = m_tvalid_i;
      assign m_tready_i = m_tready;
    end
  endgenerate

  //! Sequential block for present-state FSM logic
  always_ff @(posedge clk)
  begin : PRESENT_STATE_FSM
    if (!reset_n)
    begin
      state <= RD_DATA;
    end
    else
    begin
      state <= next;
    end
  end

  //! Combinational block for next-state FSM logic
  always_comb
  begin : next_FSM
    next = RD_DATA;
    case (state)
      RD_DATA:
      begin
        if (s_tvalid_i)
        begin
          next = COMPUTE;
        end
        else
        begin
          next = RD_DATA;
        end
      end
      COMPUTE:
      begin
        if (iteration == NUM_ITERATIONS - 1)
        begin
          next = WR_DATA;
        end
        else
        begin
          next = COMPUTE;
        end
      end
      WR_DATA:
      begin
        if (m_tready_i)
        begin
          next = RD_DATA;
        end
        else
        begin
          next = WR_DATA;
        end
      end
    endcase
  end

  always_ff @(posedge clk)
  begin
    if(!reset_n)
    begin
      iteration <= 0;
    end
    else
    begin
      case (state)
        RD_DATA:
        begin
          if(s_tvalid_i)
          begin
            //! taking abs of input based on sign and padding 2 additional
            //! 0 bits at the MSB to allow bitgrowth
            if(s_tdata_i[DW_REAL - 1])
            begin
              x <= {2'b0, -s_tdata_i[DW_REAL - 1:0]};
            end
            else
            begin
              x <= {2'b0, s_tdata_i[DW_REAL - 1:0]};
            end

            if(s_tdata_i[DW_IN - 1])
            begin
              y <= {2'b0, -s_tdata_i[DW_IN - 1:DW_REAL]};
            end
            else
            begin
              y <= {2'b0, s_tdata_i[DW_IN - 1:DW_REAL]};
            end

            //! picking sign bits of real and imag parts
            sign_in[0] <= s_tdata_i[DW_REAL - 1];
            sign_in[1] <= s_tdata_i[DW_IN - 1];
          end
          z <= 0;
          iteration <= 0;
        end
        COMPUTE:
        begin
          if(y[DW_REAL - 1])
          begin
            //! if negative
            x <= x - (y >>> iteration);
            y <= y + (x >>> iteration); // variable shift
            z <= z - atan_table[iteration];
          end
          else
          begin
            //! if y is positive
            x <= x + (y >>> iteration);
            y <= y - (x >>> iteration);
            z <= z + atan_table[iteration];
          end
          iteration <= iteration + 1'b1;
        end
      endcase
    end
  end

  assign m_tvalid_i = (state == WR_DATA);
  assign s_tready_i = (state == RD_DATA);

  assign m_tdata_i = {sign_in, z[0 +: DW_ANGLE]};
endmodule
