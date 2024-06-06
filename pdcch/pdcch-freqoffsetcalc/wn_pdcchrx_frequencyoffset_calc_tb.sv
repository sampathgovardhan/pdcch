`timescale 1ns/1ps
module wn_pdcchrx_frequencyoffset_calc_tb();

  // Parameters
  localparam  nRx = 2;
  localparam DW_OUT = 24;

  // Ports
  reg clk = 0;
  reg rstn = 0;
  
  reg [12:0] config_in_tdata;
  reg config_in_tvalid = 0;
  wire config_in_tready;
  reg [((nRx * 32) - 1) : 0] data_in_tdata;
  reg data_in_tvalid = 0;
  wire data_in_tready;
  reg data_in_tlast = 0;
  wire [47 : 0] data_out_tdata;
  wire data_out_tvalid;
  reg data_out_tready = 0;
  logic [((nRx * 32) - 1) : 0] wr_data_in_tdata;
  logic [12:0] wr_config_in_tdata;
  logic [23:0] real_ref,imag_ref;
  reg signed [23:0] data_real_act;
	        reg signed [23:0] data_imag_act;
	        reg signed [23:0] data_real_ref;
	        reg signed [23:0] data_imag_ref;

	        real    data_real_ref_r;
	        real    data_imag_ref_r;
	        real    data_real_act_r;
	        real    data_imag_act_r;

            wn_pdcchrx_frequencyoffset_calc 
            #(
              .nRx (
                  nRx )
            )
            wn_pdcchrx_frequencyoffset_calc_dut (
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
                param_write(10);
            end
            begin
                data_write(100);
            end
        join
        $display("info: end of input config throttling");
        fork  // all throttling
            begin
               // count = 0;
                axis_read(100);
                $display("finished axis_read");
            end
            begin
                param_write(10);
                $display("finished param");
            end
            begin
                data_write(10);
                $display("finished data_in");
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
            

            fp = $fopen("stimulus/frequencyoffset_out.csv", "r");
            if (fp == 0) begin
                $fatal(1, "ERROR: could not open config file");
            end else begin
                // reading the header (1st line)
                $fgets(line, fp);
                // $display("INFO: csv header: %s", line);
            end
            
            

            @(posedge clk);

            while ($fscanf(fp,"%h, %h",data_real_ref,data_imag_ref) == 2) begin
            
                data_out_tready <= 1;
                @(posedge clk);
                //$display("task axis_read");
                while (!data_out_tvalid) @(posedge clk);
                data_out_tready <= 0;
                
               
				diff_real = data_real_ref - data_out_tdata[23:0];
				diff_imag = data_imag_ref - data_out_tdata[47:24];
				$display("expected: %h, value: %h. diff = %d", data_real_ref,data_out_tdata[23:0], wn_abs(diff_real));
				 $display("expected: %h, value: %h. diff = %d", data_imag_ref,data_out_tdata[47:24], wn_abs(diff_imag));
                if (wn_abs(diff_real) > 24'd8388 ) begin // 8388 may seem high but it is still 1e-3 in decimal
                    $display("expected: %h, value: %h. diff = %d", data_real_ref,data_out_tdata[23:0], wn_abs(diff_real));
                    $stop;
                end
                 if (wn_abs(diff_imag) > 24'd8388 ) begin // 8388 may seem high but it is still 1e-3 in decima
                    $display("expected: %h, value: %h. diff = %d", data_imag_ref,data_out_tdata[47:24], wn_abs(diff_imag));
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

            fp = $fopen("stimulus/frequencyoffset_config.csv", "r");
            if (fp == 0) begin
                $fatal(1, "ERROR: could not open config file");
            end else begin
                // reading the header (1st line)
                $fgets(line, fp);
                //                $display("INFO: csv header: %s", line);
            end
             
            wait (rstn);
            @(posedge clk);
          
            while ($fscanf(fp,"%d, %d, %d, %d",wr_config_in_tdata[0],wr_config_in_tdata[2:1],wr_config_in_tdata[3],wr_config_in_tdata[12:4]) == 4) begin
             
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

    task automatic data_write;
    input int throttle;
    begin
        int fp;
        int wait_n;  // for throttling
        
        logic tlast;
       
        int status;
        string line;

        fp = $fopen("stimulus/frequencyoffset_datain.csv", "r");
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

