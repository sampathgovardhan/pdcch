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
//! @date 13-04-2022
//! @brief module for cordic with pipelining
//! 
//! This module computes e^jt of the input angle "t" using the cordic rotation method.
//! It uses binary angles to represent the angle i.e., pi is replaced with 1 and the 
//! module that is driving the angle to this has to ensure that the pi factor is removed
//! from the equation. 
//! The latency of the operation is expected to be between 14 and 16 cycles based on
//! the skid buffers used on the input and output side. 

//! Input(angle t) is unsigned Q0.16
//! Output is signed Q1.X format

`timescale 1ns / 1ps

module wn_cordic_pipelined #(
    parameter int DW_ANGLE = 16,
    parameter int DW_SIGN = 2,
    parameter int DW_IN = DW_ANGLE + DW_SIGN,
    parameter int DW_OUT = 32,
    parameter int ENABLE_IN_SKID = 0,
    parameter int ENABLE_OUT_SKID = 0
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
    input logic m_tready,  //! @end

    //! signal to indicate throttling on any of the data interfaces
    output reg error
);
    //! number of iterations is equal to the number of fractional bits used to represent
    //! the output
    localparam NUM_ITERATIONS = 15;

    //! input data internal variables
    logic s_tvalid_i;
    logic [DW_IN - 1:0] s_tdata_i;
    logic s_tready_i;

    //! output data internal variable
    logic [DW_OUT - 1:0] m_tdata_i;
    logic m_tvalid_i;
    logic m_tready_i;

    //! clock/chip enable, used for shifting the pipeline/shift registers
    logic CE;
    //! shift register for valid. this is declared as a register to initialise this with 0
    //! It is important to ensure that the valid signals are always known (not unknown)
    reg [NUM_ITERATIONS - 1:0] tvalid_shr = 0;
    //! shift register for sign
    logic [DW_SIGN - 1:0] sign_shr[NUM_ITERATIONS];
    //! intemediate registers in the pipeline
    //! (x,y) here represent the real and imag values of the output
    //! z represents the angle
    logic signed [DW_ANGLE:0] z[NUM_ITERATIONS];
    logic signed [DW_OUT/2 - 1:0] x[NUM_ITERATIONS], y[NUM_ITERATIONS];
    //! flags to check if there is any overflow in the computation
    logic [NUM_ITERATIONS - 1:0] x_overflow, y_overflow;
    
    //! temporary wires for x,y,z called x_next, y_next and z_next
    logic signed [DW_OUT/2 - 1:0] x_next[NUM_ITERATIONS], y_next[NUM_ITERATIONS];
    logic signed [DW_ANGLE - 1:0] z_next[NUM_ITERATIONS];

    //! atan table
    logic [DW_ANGLE - 1:0] atan_table[15];
    initial begin
        //! atan table is in signed Q1.15 format and is using binary angles (i.e., 1/2 for pi/2)
        //! though the input is in [0, 0.5] range, the value of z can go negative so to maintain
        //! q formats across all additions, signed Q1.15 format is used
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
            'd1};
    end

    generate
        if (ENABLE_IN_SKID) begin
            //! skid buffer for input data
            skidbuffer #(
                .DW(DW_IN)
            ) inst_in (
                .clock(clk),
                .reset(~reset_n),
                .input_tvalid(s_tvalid),
                .input_tready(s_tready),
                .input_tdata(s_tdata),
                .output_tvalid(s_tvalid_i),
                .output_tready(s_tready_i),
                .output_tdata(s_tdata_i)
            );
        end else begin
            assign s_tvalid_i = s_tvalid;
            assign s_tdata_i  = s_tdata;
            assign s_tready   = s_tready_i;
        end

        if (ENABLE_OUT_SKID) begin
            //! skid buffer for data output
            skidbuffer #(
                .DW(DW_OUT)
            ) inst_out (
                .clock(clk),
                .reset(~reset_n),
                .input_tvalid(m_tvalid_i),
                .input_tready(m_tready_i),
                .input_tdata(m_tdata_i),
                .output_tvalid(m_tvalid),
                .output_tready(m_tready),
                .output_tdata(m_tdata)
            );
        end else begin
            assign m_tdata = m_tdata_i;
            assign m_tvalid = m_tvalid_i;
            assign m_tready_i = m_tready;
        end
    endgenerate

    //! combinational block for assigning the output
    //! the x and y values in the first quadrant are rotated to the other quadrants based
    //! on the sign signal
    always_comb begin
        case (sign_shr[NUM_ITERATIONS - 1])
            // both real and imag are +ve
            0: m_tdata_i = {y[NUM_ITERATIONS-1], x[NUM_ITERATIONS-1]};
            // real is -ve, imag is +ve
            1: m_tdata_i = {y[NUM_ITERATIONS-1], -x[NUM_ITERATIONS-1]};
            // real is +ve, imag is -ve
            2: m_tdata_i = {-y[NUM_ITERATIONS-1], x[NUM_ITERATIONS-1]};
            // both real and imag are -ve
            3: m_tdata_i = {-y[NUM_ITERATIONS-1], -x[NUM_ITERATIONS-1]};
            default: m_tdata_i = {y[NUM_ITERATIONS-1], x[NUM_ITERATIONS-1]};
        endcase
    end

    //! CE - shift the pipeline when there is valid data
    assign CE = (s_tready_i && s_tvalid_i);
    //! set tready to high when the output tready is high or when the pipeline is not full
    assign s_tready_i = !m_tvalid_i || m_tready_i;
    //! assign m_tvalid_i based on the tvalid shift register
    assign m_tvalid_i = tvalid_shr[NUM_ITERATIONS - 1];
    
    //! flush mode shift register
    always_ff @(posedge clk) begin
        //! for flush mode, all the registers in the pipeline are shifted every cycle
        for (int i = 1; i < NUM_ITERATIONS; i++) begin
            if(s_tready_i) begin
                x[i] <= x_next[i - 1];
                y[i] <= y_next[i - 1];
                
                z[i] <= z_next[i - 1];
                sign_shr[i] <= sign_shr[i-1];
                tvalid_shr[i] <= tvalid_shr[i - 1];            
            end
        end

        //! the input is loaded when there is valid data
        if (CE) begin
            x[0] <= 19898;
            y[0] <= 0;
            z[0] <= {1'b0,s_tdata_i[DW_ANGLE-1:0]};
            sign_shr[0] <= s_tdata_i[DW_ANGLE+:DW_SIGN];
        end
        
        if(s_tready_i) begin
            tvalid_shr[0] <= s_tvalid_i;
        end
    end
    
    always_ff @(posedge clk) begin
        if(!reset_n) begin
            error <= 0;
        end else begin
            if(|x_overflow || |y_overflow) begin
                error <= 1;
            end
        end
    end

    /* condition for overflow */
    /*
    for addition (a + b),
    if both a and b have same sign, an overflow can occur when the result of a + b has
    a different sign
    for subtraction (a - b), 
    if both a and -b have same sign, an overflow can occur when the result of a - b has 
    a different sign
    */
    //! computing the next x,y,z values
    always_comb begin
        for (int i = 0; i < NUM_ITERATIONS; i++) begin
            if (z[i][DW_ANGLE-1]) begin
                //! if z is -ve
                x_next[i] = x[i] + (y[i] >>> i);
                y_next[i] = y[i] - (x[i] >>> i);
                z_next[i] = z[i] + atan_table[i];

                // checking if there is any overflow
                x_overflow[i] = ~(x[i][15] ^ y[i][15]) & (y[i][15] ^ x_next[i][15]);
                y_overflow[i] = (x[i][15] ^ y[i][15]) & (y[i][15] ^ y_next[i][15]);                                                                  
            end else begin
                //! if z is +ve
                x_next[i] = x[i] - (y[i] >>> i);
                y_next[i] = y[i] + (x[i] >>> i);
                z_next[i] = z[i] - atan_table[i];

                // checking if there is any overflow
                x_overflow[i] = (x[i][15] ^ y[i][15]) & (x[i][15] ^ x_next[i][15]);
                y_overflow[i] = ~(x[i][15] ^ y[i][15]) & (y[i][15] ^ y_next[i][15]);
            end
            if(x_overflow[i])
                x_next[i] = 16'h7fff;
          
            if(y_overflow[i])
                y_next[i] = 16'h7fff;

//            $display("%t: %d: z = %d; x,y = %d,%d; x_n, y_n = %d,%d; x_o,y_o = %d,%d", $time, i, z[i], x[i], y[i], x_next[i], y_next[i], x_overflow[i], y_overflow[i]);
        end
    end

endmodule
