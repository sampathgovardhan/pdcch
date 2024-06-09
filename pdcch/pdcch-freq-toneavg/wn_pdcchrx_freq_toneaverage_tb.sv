`timescale 1ns/1ps
module wn_pdcchrx_freq_toneaverage_tb();

  // Parameters
  localparam  nRx = 2;
  localparam DW_OUT = 16;

  // Ports
  reg clk = 0;
  reg rstn = 0;
  
  reg [4:0] config_in_tdata;
  reg config_in_tvalid = 0;
  wire config_in_tready;
  reg [((nRx * 32) - 1) : 0] data_in_tdata;
  reg data_in_tvalid = 0;
  wire data_in_tready;
  reg data_in_tlast = 0;
  wire [((nRx * 32) - 1) : 0] data_out_tdata;
  wire data_out_tvalid;
  wire data_out_tlast;
  reg data_out_tready = 0;
  logic [((nRx * 32) - 1) : 0] wr_data_in_tdata;
  logic [4:0] wr_config_in_tdata;
  logic [23:0] real_ref,imag_ref;
  reg signed [23:0] data_real_act;
	        reg signed [23:0] data_imag_act;
	        reg signed [15:0] data_real_ref1;
	        reg signed [15:0] data_imag_ref1;
            reg signed [15:0] data_real_ref2;
	        reg signed [15:0] data_imag_ref2;

	        real    data_real_ref_r1;
	        real    data_imag_ref_r1;
	        real    data_real_act_r2;
	        real    data_imag_act_r2;
	        int count;

            wn_pdcchrx_freq_toneaverage 
            #(
              .nRx (
                  nRx )
            )
            wn_pdcchrx_freq_toneaverage_dut (
              .clk (clk ),
              .rstn (rstn ),
              .config_in_tdata (config_in_tdata ),
              .config_in_tvalid (config_in_tvalid ),
              .config_in_tready (config_in_tready ),
              .data_in_tdata (data_in_tdata ),
              .data_in_tvalid (data_in_tvalid ),
              .data_in_tready (data_in_tready ),
              .data_in_tlast (data_in_tlast ),
              .data_out_tdata (data_out_tdata ),
              .data_out_tvalid (data_out_tvalid ),
              .data_out_tready (data_out_tready ),
              .data_out_tlast  ( data_out_tlast)
            );

  initial begin
    begin
      //$finish;
        $timeformat(-9, 2, " ns", 20);
        reset_task();
        fork  // full throughput test
            begin
           // count = 0;
                axis_read(1);
                $display("info: end of data read ");
            end
            begin
                param_write(1);
                $display("info: end of param write ");
            end
            begin
                data_write(1);
            end
        join
        $display("info: end of full tput test");
        fork  // input config throttling
            begin
           // count = 0;
                axis_read(1);
            end
            begin
                param_write(100);
            end
            begin
                data_write(1);
            end
        join
        $display("info: end of input config throttling");
        fork  // all throttling
            begin
               // count = 0;
                axis_read(10);
            end
            begin
                param_write(10);
            end
            begin
                count = 0;
                data_write(10);
            end
        join
        $display("info: end of all throttling");
        $finish;
    end
  end

  always
    #5  clk = ! clk ;


     // reset task
    task automatic reset_task;
        begin
            repeat (3) @(posedge clk);
            rstn = ~rstn;
        end
    endtask

function logic [DW_OUT - 1:0] wn_abs(input logic signed [DW_OUT - 1:0] in);
        if(in > 0)
            wn_abs = in;
        else 
            wn_abs = -1 * in;
    endfunction
    
    
    task automatic axis_read;
        input int backpr;
        begin
            int wait_n;
            logic [DW_OUT - 1:0] diff_real, diff_imag;
           
            int fp;
            string line;
            

            fp = $fopen("./stimulus/freq_toneaverage_out.csv", "r");
            if (fp == 0) begin
                $fatal(1, "ERROR: could not open config file");
            end else begin
                // reading the header (1st line)
                $fgets(line, fp);
                // $display("INFO: csv header: %s", line);
            end
            
            

            @(posedge clk);

            while ($fscanf(fp,"%h, %h, %h, %h",data_real_ref1,data_imag_ref1,data_real_ref2,data_imag_ref2) == 4) begin
            
                data_out_tready <= 1;
                
                @(posedge clk);
                //$display("task axis_read");
                while (!data_out_tvalid) @(posedge clk);
                data_out_tready <= 0;
                count <= count + 1;
                //count <= count  + 1;
               // $display("expected: %d, value: %d,count=%d ",data,dmrs_out_tdata[1:0],count);
               // diff = data - dmrs_out_tdata[1:0];
                /*if (data != dmrs_out_tdata[1:0] ) begin 
                    $display("expected: %d, value: %d,count=%d ",data,dmrs_out_tdata[1:0],count);
                    $stop;
                end*/
               /* data_real_ref_r = data_real_ref;
				data_imag_ref_r = data_imag_ref;
				
                 data_real_act = data_out_tdata[23:0];
				data_imag_act = data_out_tdata[47:24];
                 //data_real_ref = real_ref;
                 //data_imag_ref = imag_ref;
                 data_real_act_r = data_real_act;
				data_imag_act_r = data_imag_act;*/
				
				
				
				/*data_real_act_r = data_real_act_r/(1<<23);
				data_imag_act_r = data_imag_act_r/(1<<23);
				
				data_imag_ref_r = data_imag_ref_r/(1<<23);
				data_imag_ref_r = data_imag_ref_r/(1<<23);

				// $display("-------ACTU----------Real : %0f \t Imag : %0f", data_real_act_r,data_imag_act_r);
				// $display("-------REF----------Real : %0f \t Imag : %0f", data_real_ref_r,data_imag_ref_r);
				if (((data_real_act_r - data_real_ref_r) > 0.001) || ((data_real_act_r - data_real_ref_r) < -0.001)) begin
					$display("-------FAILED REAL----------REF : %0f \t ACT : %0f \t SUB  : %0f", data_real_ref_r,data_real_act_r,data_real_act_r - data_real_ref_r);
					//$error("Testcase : %0d DATA : %0d",test_count,count_data);
					$stop;
				end

				if (((data_imag_act_r - data_imag_ref_r) > 0.001) || ((data_imag_act_r - data_imag_ref_r) < -0.001)) begin
					$display("-------FAILED IMAG----------REF : %0f \t ACT : %0f \t SUB  : %0f", data_imag_ref_r,data_imag_act_r,data_imag_act_r - data_imag_ref_r);
					//$error("Testcase : %0d DATA : %0d",test_count,count_data);
					$stop;
				end*/
				diff_real = data_real_ref1 - data_out_tdata[15:0];
				diff_imag = data_imag_ref1 - data_out_tdata[31:16];
				$display("expected: %h, value: %h. diff = %d", data_real_ref1,data_out_tdata[15:0], wn_abs(diff_real));
				 $display("expected: %h, value: %h. diff = %d", data_imag_ref1,data_out_tdata[31:16], wn_abs(diff_imag));
                if (wn_abs(diff_real) > 16'd16 ) begin // 8388 may seem high but it is still 1e-3 in decimal
                    $display("expected: %h, value: %h. diff = %d", data_real_ref1,data_out_tdata[15:0], wn_abs(diff_real));
                    $stop;
                end
                 if (wn_abs(diff_imag) > 16'd16 ) begin // 8388 may seem high but it is still 1e-3 in decima
                    $display("expected: %h, value: %h. diff = %d", data_imag_ref1,data_out_tdata[31:16], wn_abs(diff_imag));
                    $stop;
                end
                wait_n = $urandom % backpr;
                repeat (wait_n) begin
                    //!                   $display("info: %t waiting ...", $time);
                    @(posedge clk);
                end
            end
             $fclose(fp);
        end
    endtask

    // param write task
    task automatic param_write;
        input int throttle;
        begin
            int fp;
            int wait_n;  // for throttling
            
           
            int status;
            string line;

            fp = $fopen("./stimulus/freq_toneaverage_config.csv", "r");
            if (fp == 0) begin
                $fatal(1, "ERROR: could not open config file");
            end else begin
                // reading the header (1st line)
                $fgets(line, fp);
                //                $display("INFO: csv header: %s", line);
            end
             
            wait (rstn);
            @(posedge clk);
          
            while ($fscanf(fp,"%d, %d",wr_config_in_tdata[4:3],wr_config_in_tdata[2:0]) == 2) begin
             
                config_in_tvalid <= 1;
               
                 config_in_tdata <= wr_config_in_tdata;
                @(posedge clk);
                  //$display("task_param_write");
                while (!config_in_tready) @(posedge clk);
                config_in_tvalid <= 0;

                wait_n = $urandom % throttle;
                if (wait_n > 0) begin
                    //$display("waiting for %d cycles", wait_n);
                end
                repeat (wait_n) begin
                    @(posedge clk);
                end
            end  // end of while loop
          
           
        end  // end of task begin
    endtask
//home/shobhit/Desktop/yashpal/wnKyocera/channels/pdcch/test/
    task automatic data_write;
    input int throttle;
    begin
        int fp;
        int wait_n;  // for throttling
        
        logic tlast;
       
        int status;
        string line;

        fp = $fopen("./stimulus/freq_toneaverage_datain.csv", "r");
        if (fp == 0) begin
            $fatal(1, "ERROR: could not open config file");
        end else begin
            // reading the header (1st line)
            $fgets(line, fp);
            //                $display("INFO: csv header: %s", line);
        end
         
        wait (rstn);
        @(posedge clk);
      
        while ($fscanf(fp,"%h, %h, %h, %h, %d",wr_data_in_tdata[15:0],wr_data_in_tdata[31:16],wr_data_in_tdata[47:32],wr_data_in_tdata[63:48],tlast) == 5) begin
         
            data_in_tvalid <= 1;
             data_in_tlast <= tlast;
             data_in_tdata <= wr_data_in_tdata;
            @(posedge clk);
              //$display("task_data_write");
            while (!data_in_tready) @(posedge clk);
            data_in_tvalid <= 0;

            wait_n = $urandom % throttle;
            if (wait_n > 0) begin
                //$display("waiting for %d cycles", wait_n);
            end
            repeat (wait_n) begin
                @(posedge clk);
            end
        end  // end of while loop
      
       
    end  // end of task begin


    endtask


endmodule





