module wn_pdcchrx_modulationremoval_tb;

  // Parameters
  localparam  nRX = 2;
  localparam DW_OUT = 16;

  // Ports
  reg clk = 0;
  reg rstn = 0;
  reg [7:0] dmrs_in_tdata;
  reg dmrs_in_tvalid = 0;
  wire  dmrs_in_tready;
  reg [((nRX*32)-1):0] data_in_tdata;
  reg data_in_tvalid = 0;
  reg data_in_tlast = 0;
  wire  data_in_tready;
  wire [((nRX*32)-1):0] estm_out_tdata;
  wire  estm_out_tvalid;
  reg estm_out_tready = 0;
  wire  estm_out_tlast;

  reg [((nRX*32)-1):0] wr_data_in_tdata;
  reg [7:0] wr_dmrs_in_tdata;
  reg [15:0] real_ref,imag_ref;
  reg signed [15:0] data_real_act;
            reg signed [15:0] data_imag_act;
            reg signed [15:0] data_real_ref1;
            reg signed [15:0] data_imag_ref1;
            reg signed [15:0] data_real_ref2;
            reg signed [15:0] data_imag_ref2;
           
              reg signed [15:0] data_real_ref;
              reg signed [15:0] data_imag_ref;
  
            real    data_real_ref_r1;
            real    data_imag_ref_r1;
            real    data_real_act_r2;
            real    data_imag_act_r2;
          reg [5:0] count;
                int bounce,ounce;

          wn_pdcchrx_modulationremoval 
          #(
            .nRX (
                nRX )
          )
          wn_pdcchrx_modulationremoval_dut (
            .clk (clk ),
            .rstn (rstn ),
            .dmrs_in_tdata (dmrs_in_tdata ),
            .dmrs_in_tvalid (dmrs_in_tvalid ),
            .dmrs_in_tready (dmrs_in_tready ),
            .data_in_tdata (data_in_tdata ),
            .data_in_tvalid (data_in_tvalid ),
            .data_in_tlast (data_in_tlast ),
            .data_in_tready (data_in_tready ),
            .estm_out_tdata (estm_out_tdata ),
            .estm_out_tvalid (estm_out_tvalid ),
            .estm_out_tready (estm_out_tready ),
            .estm_out_tlast  ( estm_out_tlast)
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
          reg tlast;
         
          int fp,refer;
          string line;
          

          fp = $fopen("stimulus/modrem_out.csv", "r");
          refer = $fopen("stimulus/modrem_output_log.txt","w");
          if (fp == 0) begin
              $fatal(1, "ERROR: could not open config file");
          end else begin
              // reading the header (1st line)
              $fgets(line, fp);
              // $display("INFO: csv header: %s", line);
          end
          
          

          @(posedge clk);

          while ($fscanf(fp,"%h, %h, %h, %h, %d",data_real_ref1,data_imag_ref1,data_real_ref2,data_imag_ref2,tlast) == 5) begin
          
              estm_out_tready <= 1;
              
              @(posedge clk);
              //$display("task axis_read");
              while (!estm_out_tvalid) @(posedge clk);
              estm_out_tready <= 0;
              count <= count + 1;
              
              diff_real = data_real_ref1 - estm_out_tdata[15:0];
              diff_imag = data_imag_ref1 - estm_out_tdata[31:16];
              $display(" expected real: %h, value: %h. diff = %d", data_real_ref1,estm_out_tdata[15:0], wn_abs(diff_real));

              $display(" expected imag: %h, value: %h. diff = %d", data_imag_ref1,estm_out_tdata[31:16], wn_abs(diff_imag));
              if (wn_abs(diff_real) > 16'd16 ) begin // 16 may seem high but it is still 1e-3 in decimal
                bounce<=bounce+1;
                  $fdisplay(refer,"mismatch in test.no: %d, expected real: %h, value: %h. diff = %d",bounce, data_real_ref1,estm_out_tdata[15:0], wn_abs(diff_real));
                  $stop;
              end
               if (wn_abs(diff_imag) > 16'd16 ) begin // 16 may seem high but it is still 1e-3 in decimal
                ounce <=ounce+1;
                  $fdisplay(refer,"mismatch in test.no: %d, expected imag: %h, value: %h. diff = %d", ounce, data_imag_ref1,estm_out_tdata[31:16], wn_abs(diff_imag));
                  $stop;
              end
              wait_n = $urandom % backpr;
              repeat (wait_n) begin
                                    // $display("info: %t waiting ...", $time);
                  @(posedge clk);
              end
          end
           $fclose(fp);
           $fclose(refer);
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

          fp = $fopen("stimulus/modrem_dmrs_in.csv", "r");
          if (fp == 0) begin
              $fatal(1, "ERROR: could not open config file");
          end else begin
              // reading the header (1st line)
              $fgets(line, fp);
              //                $display("INFO: csv header: %s", line);
          end
           
          wait (rstn);
          @(posedge clk);
        
          while ($fscanf(fp,"%d",wr_dmrs_in_tdata[7:0]) == 1) begin
           
            dmrs_in_tvalid <= 1;
             
              dmrs_in_tdata <= wr_dmrs_in_tdata;
              @(posedge clk);
                //$display("task_param_write");
              while (!dmrs_in_tready) @(posedge clk);
              dmrs_in_tvalid <= 0;

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

      fp = $fopen("stimulus/modrem_datain.csv", "r");       
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

