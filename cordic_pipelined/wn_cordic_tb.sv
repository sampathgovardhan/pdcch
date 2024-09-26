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
//! @brief testbench for cordic modules, works with both wn_cordic.sv and wn_cordic_pipelined.sv
//! 

`timescale 1ns / 1ps

module wn_cordic_tb;

    //! localparameters
    localparam int DW_ANGLE = 16;    
    localparam int DW_SIGN = 2;
    localparam int DW_IN = DW_ANGLE + DW_SIGN;
    localparam int DW_OUT = 32;
    localparam int CLOCK_PERIOD = 4;
    localparam int ENABLE_IN_SKID = 1;
    localparam int ENABLE_OUT_SKID = 1;

    // Ports
    reg clk = 0;
    reg reset_n = 0;

    reg [DW_IN - 1:0] s_tdata = 0;
    reg s_tvalid = 0;
    wire s_tready;
    logic [DW_ANGLE - 1:0] rd_data;

    wire [DW_OUT - 1:0] m_tdata;
    wire m_tvalid;
    reg m_tready = 0;
    
    wire overflow;

  wn_cordic_pipelined
  #(
    .DW_ANGLE(DW_ANGLE ),
    .DW_SIGN(DW_SIGN ),
    .DW_IN(DW_IN ),
    .DW_OUT(DW_OUT ),
    .ENABLE_IN_SKID(ENABLE_IN_SKID ),
    .ENABLE_OUT_SKID (ENABLE_OUT_SKID )
  )
  wn_cordic_dut (
    .clk (clk ),
    .reset_n (reset_n ),
    
    .s_tdata (s_tdata ),
    .s_tvalid (s_tvalid ),
    .s_tready (s_tready ),
    
    .m_tdata (m_tdata ),
    .m_tvalid (m_tvalid ),
    .m_tready (m_tready ),
    
    .error  ( overflow)
  );
  
    assign rd_data = s_tdata[0 +: DW_ANGLE];

    initial begin
        $timeformat(-9, 2, " ns", 20);
        reset_task();
        m_tready = 0;
        fork  // full throughput test
            begin
                axis_write(1);
                $display("info: end of data write ");
            end
            begin
                axis_read(1);
                $display("info: end of data read ");
            end
        join
        $display("info: end of full tput test");   
        fork  // full throughput test
            begin
                axis_write(20);
                $display("info: end of data write ");
            end
            begin
                axis_read(1);
                $display("info: end of data read ");
            end
        join
        $display("info: end of input throttling");  
        fork  // full throughput test
            begin
                axis_write(1);
                $display("info: end of data write ");
            end
            begin
                axis_read(20);
                $display("info: end of data read ");
            end
        join
        $display("info: end of output throttling");  
        fork  // full throughput test
            begin
                axis_write(25);
                $display("info: end of data write ");
            end
            begin
                axis_read(20);
                $display("info: end of data read ");
            end
        join
        $display("info: end of both throttling"); 
        $finish;                              
    end

    always #(CLOCK_PERIOD / 2) clk = !clk;

    // reset task
    task automatic reset_task;
        begin
            repeat (3) @(posedge clk);
            reset_n = ~reset_n;
        end
    endtask
    
    function logic [DW_OUT/2:0] wn_abs(input logic signed [DW_OUT/2:0] in);
        if(in > 0)
            wn_abs = in;
        else 
            wn_abs = -1 * in;
    endfunction

    task automatic axis_read;
        input int backpr;
        begin
            int wait_n;
            logic [DW_OUT - 1:0] data;
            logic signed [DW_OUT/2:0] diff_r, diff_i;
            
            logic signed [DW_OUT/2 - 1:0] out_real;
            logic signed [DW_OUT/2 - 1:0] out_imag;
             
            int fp;
            string line;

            fp = $fopen("stimulus/cordic_out.csv", "r");
            if (fp == 0) begin
                $fatal(1, "ERROR: could not open output file");
            end else begin
                // reading the header (1st line)
                    $fgets(line, fp);
                // $display("INFO: csv header: %s", line);
            end

            @(posedge clk);

            while ($fscanf(fp, "%h", data) == 1) begin
                m_tready <= 1;
                @(posedge clk);
                while (!m_tvalid) @(posedge clk);
                m_tready <= 0;
                diff_r = data[15:0] - m_tdata[15:0];
                diff_i = data[31:16] - m_tdata[31:16];
                
                if (wn_abs(diff_r) > 7 || wn_abs(diff_i) > 7) begin
                    $display("mismatch! expected: %h, value: %h, %d + i%d", data, m_tdata, diff_r, diff_i);
                    $stop;
                end

                wait_n = $urandom % backpr;
                repeat (wait_n) begin
                    //!                   $display("info: %t waiting ...", $time);
                    @(posedge clk);
                end
            end
        end
    endtask

    // param write task
    task automatic axis_write;
        input int throttle;
        begin
            int fp;
            int wait_n;  // for throttling

            logic [DW_ANGLE - 1:0] data;
            logic [DW_SIGN - 1:0] sign;
            int status;
            string line;

            fp = $fopen("stimulus/cordic_in.csv", "r");
            if (fp == 0) begin
                $fatal(1, "ERROR: could not open input file");
            end else begin
                // reading the header (1st line)
                $fgets(line, fp);
                // $display("INFO: csv header: %s", line);
            end

            wait (reset_n);
            @(posedge clk);
            while ($fscanf(fp, "%h, %h", data, sign) == 2) begin
                s_tvalid <= 1;
                s_tdata  <= {sign,data};
                @(posedge clk);
                //! assuming a single tready for both the signals
                while (!s_tready) @(posedge clk);
                s_tvalid <= 0;

                wait_n = $urandom % throttle;
                repeat (wait_n) begin
                    @(posedge clk);
                end
            end  // end of while loop
            $fclose(fp);
        end  // end of task begin
    endtask

endmodule
