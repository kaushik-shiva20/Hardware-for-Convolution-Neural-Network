module MyDesign (
//---------------------------------------------------------------------------
//Control signals
  input   wire dut_run                    , 
  output  reg dut_busy                   ,
  input   wire reset_b                    ,  
  input   wire clk                        ,
 
//---------------------------------------------------------------------------
//Input SRAM interface
  output reg        input_sram_write_enable    ,
  output reg [11:0] input_sram_write_addresss  ,
  output reg [15:0] input_sram_write_data      ,
  output reg [11:0] input_sram_read_address    ,
  input wire [15:0] input_sram_read_data       ,

//---------------------------------------------------------------------------
//Output SRAM interface
  output reg        output_sram_write_enable    ,
  output reg [11:0] output_sram_write_addresss  ,
  output reg [15:0] output_sram_write_data      ,
  output reg [11:0] output_sram_read_address    ,
  input wire [15:0] output_sram_read_data       ,

//---------------------------------------------------------------------------
//Scratchpad SRAM interface
  output reg        scratchpad_sram_write_enable    ,
  output reg [11:0] scratchpad_sram_write_addresss  ,
  output reg [15:0] scratchpad_sram_write_data      ,
  output reg [11:0] scratchpad_sram_read_address    ,
  input wire [15:0] scratchpad_sram_read_data       ,

//---------------------------------------------------------------------------
//Weights SRAM interface                                                       
  output reg        weights_sram_write_enable    ,
  output reg [11:0] weights_sram_write_addresss  ,
  output reg [15:0] weights_sram_write_data      ,
  output reg [11:0] weights_sram_read_address    ,
  input wire [15:0] weights_sram_read_data       

);

  //Input SRAM address gen
  wire fetch_in_SRAM_addr_gen_enable;
  reg fetch_in_SRAM_addr_gen_reset;
  reg [11:0] fetch_in_SRAM_addr_gen_in_base;
  reg [7:0] N;
  
  wire [11:0] input_sram_read_address_gen_addr;
  wire fetch_in_SRAM_addr_gen_done;
  
  //Kernel SRAM address gen
  reg fetch_kernel_SRAM_addr_gen_enable;
  reg fetch_kernel_SRAM_addr_gen_reset;
  
  wire [11:0] kernel_sram_read_address_gen_addr;
  wire fetch_kernel_SRAM_addr_gen_done;
  
  //Output SRAM address gen
  wire [11:0] output_sram_write_address_gen_addr;
  wire output_sram_addr_gen_done;
  wire ouput_SRAM_addr_gen_enable;
  reg output_SRAM_addr_gen_reset;
  
  
  //Input Buffer
  reg fetch_in_buffer_enable;
  reg fetch_in_buffer_reset;
  
  wire [127:0] fetch_in_buffer_out_flattened;
  
  //Kernel Buffer
  reg fetch_kern_buffer_enable;
  reg fetch_kern_buffer_reset;
  
  wire [7:0] fetch_kern_buffer_out[9:0];
  wire [79:0] fetch_kern_buffer_out_flattened;
  
  //Output buffer
  wire output_buffer_enable;
  reg output_buffer_reset;
  
  wire [15:0]out_buffer_output;
  
  //Switch Sel Gen
  reg [3:0] switch_sel_gen_en;
  reg [3:0] switch_sel_gen_reset;

  wire [3:0] switch_sel_gen_I[3:0];
  wire [3:0] switch_sel_gen_K[3:0];

  wire [15:0] switch_sel_gen_I_f;
  wire [15:0] switch_sel_gen_K_f;

  //Switch
  wire [31:0] switch_I_out_f;
  wire [31:0] switch_K_out_f;
  
  //MAC
  wire MAC_en;
  wire MAC_reset;
  wire [79:0]MAC_out_f;
  
  //Max_pool_Relu
  wire [7:0] max_pool_output;

  //FSM
  reg fsm_in_addr_gen_en_enable;
  reg fsm_sel_gen_en_enable;
  reg fsm_in_addr_gen_en_reset;
  reg fsm_sel_gen_en_reset;
  
  wire fsm_sel_en;
  wire fsm_sel_part_change;
      
  //temp
  reg isDutRunReceived;
  reg temp_in_buf_enable;
  reg temp_in_buf_enable_1;
  
  reg temp_kern_buf_enable;
  reg temp_kern_buf_enable_1;
  reg isFirstBuf;
  
  reg tempMACdelay;
  
  reg tempOutputBufReset;
  reg tempSRAMwriteenable;
  reg tempSRAMwriteenable_1;
  
  /******************* Master FSM Start ************************************/
  
reg [11:0] prev_fetch_in_SRAM_addr_gen_in_base;
reg [3:0] current_state,next_state;
reg is_dut_run_received;
reg [1:0] is_N_read;
reg [11:0] output_addr_offset;
reg [11:0] temp_output_addr_offset;
reg perInputReset;
reg temps2changestate;


parameter
  s0 = 0,   //Reset - new DUT RUN
  s1 = 1,   //Reset - new image, load N
  s2 = 2,   //process image
  s3 = 3,   //output stored
  s4 = 4;   //N=FF

always @(posedge clk or negedge reset_b)
  begin
    if (!reset_b)
    begin
      current_state = s0;
    end
    else
    begin
      current_state = next_state;
    end
  end
 

always @(posedge clk)
  begin
    if(!reset_b)
      begin
        next_state = s0;
        temp_output_addr_offset = 0;
        is_dut_run_received = 0;
      end
    
    case(current_state)
      s0:
        begin
          N = 0;
          temp_output_addr_offset = 0;
          if(dut_run && !is_dut_run_received)
            begin
              is_dut_run_received = 1;
            end
          if(is_dut_run_received)
            next_state = s1;
        end
      s1:
        begin
          if(is_N_read == 2)
            begin
              N = input_sram_read_data[7:0];
              if(N == 8'hFF)
                begin
                  next_state = s4;
                end
              else
                begin
                  next_state = s2;
                end
            end
        end
      s2:
        begin
          if(temps2changestate)
            begin
              next_state = s3;
            end
        end
      s3:
        begin
          if(output_sram_addr_gen_done)
            begin
              next_state = s1;
              temp_output_addr_offset = temp_output_addr_offset + output_sram_write_address_gen_addr + 1;
            end
        end
      s4:
        begin
          next_state = s0;
          is_dut_run_received = 0;
        end
    endcase
  end

always @(posedge clk or negedge reset_b)
begin
  if(!reset_b)
    begin
    dut_busy = 0;
    fetch_in_SRAM_addr_gen_in_base = 0;
    prev_fetch_in_SRAM_addr_gen_in_base = 0;
    is_N_read = 0;
    output_addr_offset = 0;
    perInputReset <= 1;
    temps2changestate = 0;
    isFirstBuf <= 1;
  end
  else
    begin
      if(isFirstBuf && temp_in_buf_enable_1)
        isFirstBuf <= 0;
      if(current_state != s0)
        output_buffer_reset <= tempOutputBufReset;       
	    
      case(current_state)
      	s0:
          begin
            is_N_read = 0;
            prev_fetch_in_SRAM_addr_gen_in_base = 0;
            fetch_in_SRAM_addr_gen_in_base = 0;
            output_addr_offset = 0;
            dut_busy = 0;
            perInputReset <= 1;
            temps2changestate = 0;
            isFirstBuf <= 1;
            
            //reset input addr gen
            fetch_in_SRAM_addr_gen_reset <= 0;
            //reset kernel addr gen
            fetch_kernel_SRAM_addr_gen_reset <= 0;
            //reset output addr gen
            output_SRAM_addr_gen_reset <= 0;
            //reset input buffer
            fetch_in_buffer_reset <= 0;
            //reset kernel buffer
            fetch_kern_buffer_reset <= 0;
            //reset output buffer
            output_buffer_reset <= 0;
            //reset input select gen
            //reset kernel select gen
            switch_sel_gen_reset[0] <= 0;
            switch_sel_gen_reset[1] <= 0;
            switch_sel_gen_reset[2] <= 0;
            switch_sel_gen_reset[3] <= 0;
          end
        s1:
          begin
            if(is_N_read == 0)
              begin
                is_N_read = 1;
                input_sram_read_address = prev_fetch_in_SRAM_addr_gen_in_base;
                fetch_in_SRAM_addr_gen_in_base = input_sram_read_address + 1;
                //reset input addr gen
                fetch_in_SRAM_addr_gen_reset <= 1;
                //reset output addr gen
                output_SRAM_addr_gen_reset <= 0;
                //reset input buffer
                fetch_in_buffer_reset <= 0;

                //reset input select gen
                //reset kernel select gen
                switch_sel_gen_reset[0] <= 0;
                switch_sel_gen_reset[1] <= 0;
                switch_sel_gen_reset[2] <= 0;
                switch_sel_gen_reset[3] <= 0;
                //reset FSMs
                fsm_in_addr_gen_en_reset <= 0;
                fsm_sel_gen_en_reset <= 0;
                perInputReset <= 0;
                //assert dut_busy
                dut_busy = 1;
                isFirstBuf <= 1;
              end
            else
              begin
                is_N_read = 2;
                fetch_in_SRAM_addr_gen_reset <= 0;
                input_sram_read_address = prev_fetch_in_SRAM_addr_gen_in_base;
                output_addr_offset = temp_output_addr_offset;
              end
          end
        s2:
          begin
            input_sram_read_address = input_sram_read_address_gen_addr;
            is_N_read = 0;
            if(fetch_in_SRAM_addr_gen_done)
              begin
                temps2changestate = 1;
                fsm_in_addr_gen_en_enable = 0;       
              end
            else
              begin
                prev_fetch_in_SRAM_addr_gen_in_base = input_sram_read_address_gen_addr + 1;
                //reset input addr gen
                fetch_in_SRAM_addr_gen_reset <= 1;
                //reset kernel addr gen
                fetch_kernel_SRAM_addr_gen_reset <= 1;
                //reset output addr gen
                output_SRAM_addr_gen_reset <= 1;
                //reset input buffer
                fetch_in_buffer_reset <= 1;
                //reset kernel buffer
                fetch_kern_buffer_reset <= 1;

                //reset input select gen
                //reset kernel select gen
                switch_sel_gen_reset[0] <= 1;
                switch_sel_gen_reset[1] <= 1;
                switch_sel_gen_reset[2] <= 1;
                switch_sel_gen_reset[3] <= 1;
                perInputReset <= 1;
                //reset FSMs
                fsm_in_addr_gen_en_reset <= 1;
                fsm_sel_gen_en_reset <= 1;
                fsm_in_addr_gen_en_enable = 1;
                fsm_sel_gen_en_enable = 1;
              end
          end
        s3:
          begin
            //disable fsm_sel_gen
            temps2changestate = 0;
            if(output_sram_addr_gen_done)
              begin
                fetch_in_SRAM_addr_gen_in_base = prev_fetch_in_SRAM_addr_gen_in_base + 1;
                fsm_sel_gen_en_enable = 0;
              end 
          end
        s4:
          begin
          if(current_state == s4)
            dut_busy = 0;
          end
      endcase
    end
end
  
  /******************** Master FSM End ************************************/
      
always @(posedge perInputReset or posedge fetch_kernel_SRAM_addr_gen_done)
  begin
    if(fetch_kernel_SRAM_addr_gen_done)
      fetch_kernel_SRAM_addr_gen_enable <= 0;
    else
      fetch_kernel_SRAM_addr_gen_enable <= 1;
  end
            
always @(posedge clk or negedge reset_b)
  begin
    if(!reset_b)
      begin
        temp_in_buf_enable <= 0;
        temp_in_buf_enable_1 <= 0;
        temp_kern_buf_enable <= 0;
        temp_kern_buf_enable_1 <= 0;
        tempMACdelay <= 0;
        tempOutputBufReset <= 1;
        tempSRAMwriteenable <= 0;
      end
    else
      begin
        weights_sram_read_address <= kernel_sram_read_address_gen_addr;  
        temp_in_buf_enable <= fetch_in_SRAM_addr_gen_enable;
        temp_in_buf_enable_1 <= temp_in_buf_enable;
        
        if(isFirstBuf && temp_in_buf_enable_1)
          begin
            fetch_in_buffer_enable <= 1;
          end
        else if(isFirstBuf == 0)
          begin
            fetch_in_buffer_enable <= temp_in_buf_enable;
          end
       
        temp_kern_buf_enable <= fetch_kernel_SRAM_addr_gen_enable;
        temp_kern_buf_enable_1 <= temp_kern_buf_enable;
        fetch_kern_buffer_enable <= temp_kern_buf_enable_1;
        
        tempMACdelay <= fsm_sel_en;
        
        output_sram_write_addresss <= output_addr_offset + output_sram_write_address_gen_addr;
        output_sram_write_data <= out_buffer_output;
        tempSRAMwriteenable <= ouput_SRAM_addr_gen_enable;
        output_sram_write_enable <= tempSRAMwriteenable;
        
        if(current_state != s0)
        begin
          tempOutputBufReset <= ~(output_sram_write_enable);
        end
      end
   end
  
          
assign switch_sel_gen_I_f = {switch_sel_gen_I[0],switch_sel_gen_I[1],switch_sel_gen_I[2],switch_sel_gen_I[3]};
assign switch_sel_gen_K_f = {switch_sel_gen_K[0],switch_sel_gen_K[1],switch_sel_gen_K[2],switch_sel_gen_K[3]};        

//Input and Kernel SRAM address generators            
input_SRAM_addr_gen in_addr(fetch_in_SRAM_addr_gen_reset, clk, fetch_in_SRAM_addr_gen_enable, N, fetch_in_SRAM_addr_gen_in_base, input_sram_read_address_gen_addr, fetch_in_SRAM_addr_gen_done);
kernel_SRAM_addr_gen kern_addr(fetch_kernel_SRAM_addr_gen_reset, clk, fetch_kernel_SRAM_addr_gen_enable, kernel_sram_read_address_gen_addr, fetch_kernel_SRAM_addr_gen_done);

//Input and Kernel Buffers
input_buffer in_buf(fetch_in_buffer_reset, clk, fetch_in_buffer_enable, input_sram_read_data, fetch_in_buffer_out_flattened);
kernel_buffer kern_buf(fetch_kern_buffer_reset, clk, fetch_kern_buffer_enable, weights_sram_read_data, fetch_kern_buffer_out_flattened);

//Switch Input Select Line generators
switch_A_I_sel_gen switch_I_A_sel(switch_sel_gen_reset[0], clk, fsm_sel_en, N, switch_sel_gen_I[0]);
switch_B_I_sel_gen switch_I_B_sel(switch_sel_gen_reset[1], clk, fsm_sel_en, N, switch_sel_gen_I[1]);
switch_C_I_sel_gen switch_I_C_sel(switch_sel_gen_reset[2], clk, fsm_sel_en, N, switch_sel_gen_I[2]);
switch_D_I_sel_gen switch_I_D_sel(switch_sel_gen_reset[3], clk, fsm_sel_en, N, switch_sel_gen_I[3]);

//Switch Kernel Select Line generators
switch_A_C_K_sel_gen switch_K_A_sel(switch_sel_gen_reset[0], clk, fsm_sel_en, switch_sel_gen_K[0]);
switch_B_D_K_sel_gen switch_K_B_sel(switch_sel_gen_reset[1], clk, fsm_sel_en, switch_sel_gen_K[1]);
switch_A_C_K_sel_gen switch_K_C_sel(switch_sel_gen_reset[2], clk, fsm_sel_en, switch_sel_gen_K[2]);
switch_B_D_K_sel_gen switch_K_D_sel(switch_sel_gen_reset[3], clk, fsm_sel_en, switch_sel_gen_K[3]);

//Switch Interface
switch mSwitch(fetch_in_buffer_out_flattened,fetch_kern_buffer_out_flattened,switch_sel_gen_I_f,switch_sel_gen_K_f,switch_I_out_f,switch_K_out_f);

//MAC
MAC_A_4x MAC_A(MAC_reset, clk, MAC_en, switch_I_out_f, switch_K_out_f, MAC_out_f);

//Max Pool
max_pool_ReLu P_L(MAC_out_f,max_pool_output);

//output Buffer
output_buffer out_buf(output_buffer_reset,clk, output_buffer_enable, max_pool_output, out_buffer_output);

//output SRAM address generators 
output_SRAM_addr_gen out_addr(output_SRAM_addr_gen_reset, clk, ouput_SRAM_addr_gen_enable, N, output_sram_write_address_gen_addr, output_sram_addr_gen_done);

//FSMs
FSM_addr_gen_en fsm_in_addr_gen_en(fsm_in_addr_gen_en_reset, clk, fsm_in_addr_gen_en_enable, fsm_sel_part_change, fetch_in_SRAM_addr_gen_enable);
FSM_sel_gen_en fsm_sel_gen_en(fsm_sel_gen_en_reset, clk, fsm_sel_gen_en_enable, N, fsm_sel_part_change, fsm_sel_en, MAC_en, MAC_reset, output_buffer_enable, ouput_SRAM_addr_gen_enable);

endmodule

module input_SRAM_addr_gen(input reset,
                           input clock,
                           input enable,
                           input [7:0] N,
                           input [11:0] in_base,
                           output reg [11:0] gen_addr,
                           output reg done);

  reg [11:0] base_4_4;
  reg [7:0] head_row_4_4;
  reg [8:0] head_col_4_4;
  reg [7:0] max_row_4_4;
  reg [7:0] max_col_4_4;
  reg [2:0] el_ctr_4_4;  
  reg [1:0] row_ctr;
  reg [11:0] in_el_ctr;
  reg [11:0] addr;


always @(posedge clock or negedge reset)
  begin
    if(!reset)
      begin
        base_4_4 = in_base;
        head_row_4_4 <= 0;
        head_col_4_4 <= 0;
        addr <= in_base;
        gen_addr <= in_base;
        row_ctr <= 0;
        el_ctr_4_4 <= 0;
        in_el_ctr <= 0;
        max_row_4_4 <= ((N >> 1) - 2); 
        max_col_4_4 <= (N >> 2);
        done = 0;
      end
    else
      begin
        if(enable)
          begin
            gen_addr <= addr;
            base_4_4 = in_base + (head_row_4_4 * (N >> 1)) + (head_col_4_4 >> 1); 
            if(row_ctr == 2'b11)
              begin
                if(el_ctr_4_4 == 7)
                  begin
                    addr <= base_4_4;
                  end
                else
                  begin
                     addr <= base_4_4 + 1;
                  end     
              end
            else
              begin
                addr <= addr + (N >> 1);
              end
            row_ctr <= row_ctr + 1;
            el_ctr_4_4 <= el_ctr_4_4 + 1;
            in_el_ctr <= in_el_ctr + 1;
            if(el_ctr_4_4 == 6)
              begin
                if(head_col_4_4 < (N-4))
                  head_col_4_4 <= head_col_4_4 + 4;
                else
                  begin
                    head_col_4_4 <= 0;
                    if(head_row_4_4 < (N-4))
                        head_row_4_4 <= head_row_4_4 + 2;
                      else
                        head_row_4_4 <= 0;
                  end
              end

            if(in_el_ctr == (N * (N - 2)))
                done = 1;
              else
                done = 0;
          end
      end
  end
endmodule

module kernel_SRAM_addr_gen(input reset,
                           input clock,
                           input enable,
                           output reg [11:0] gen_addr,
                           output reg done);
  reg [11:0] addr;
  
  always @(posedge clock or negedge reset)
    begin
      if(!reset)
        begin
          addr <= 0;
          done <= 0;
        end
      else
        begin
          if(enable)
            begin
              gen_addr <= addr;
              if(addr < 4)
                begin
                	addr <= addr + 1;
                	done <= 0;
                end
              else
                begin
                	addr <= 0;
                	done <= 1;
                end
            end
        end

  end
endmodule

module input_buffer(input reset,
                    input clock,
                    input enable,
                    input [15:0] in,
                    output reg [127:0] out);

  reg [3:0] write_ptr;
  wire [3:0] next_write_ptr;
  integer i;
  reg [7:0] mout[15:0];
  always @(posedge clock or negedge reset) begin
    if(!reset)
      begin
        //clear write pointer and buffer on reset
        write_ptr <= 0;
        for(i=0;i<16;i=i+1)
          mout[i] <= 8'h00;
      end
    else
      begin
        if(enable)
          begin
            mout[write_ptr] <= in[15:8];
            mout[next_write_ptr] <= in[7:0];
            write_ptr <= write_ptr + 2;
          end
      end
  end

  assign next_write_ptr = write_ptr + 1;

  always @(*)
  begin
    if(!reset)
    begin
      out = 0;
    end
    else
    begin
      out = {mout[0],mout[1],mout[2],mout[3],
                mout[4],mout[5],mout[6],mout[7],
                mout[8],mout[9],mout[10],mout[11],
                mout[12],mout[13],mout[14],mout[15]};
    end
  end

endmodule

module kernel_buffer(input reset,
                    input clock,
                    input enable,
                    input [15:0] in,
                    output reg [79:0] mout);

  reg [3:0] write_ptr;
  wire [3:0] next_write_ptr;
  integer i;
  reg [7:0] out[9:0];
  
  always @(posedge clock or negedge reset) begin
    if(!reset)
      begin
        //clear write pointer and buffer on reset
        write_ptr <= 0;
        for(i=0;i<16;i=i+1)
          out[i] <= 8'h00;
      end
    else
      begin
        if(enable)
          begin
            out[write_ptr] <= in[15:8];
            out[next_write_ptr] <= in[7:0];
            begin
              if(write_ptr[3])
                write_ptr <= 0;
              else
                write_ptr <= write_ptr + 2;
            end
          end
      end
  end

  assign next_write_ptr = write_ptr + 1;

  always @(*)
  begin
    if(!reset)
    begin
      mout = 0;
    end
    else
    begin
      mout = {out[0],out[1],out[2],out[3],
            out[4],out[5],out[6],out[7],
            out[8],out[9]};
    end
  end

endmodule


module switch(input [127:0] img_in_f,
              input [79:0] ker_in_f,
              input [15:0] sel_in_f,
              input [15:0] sel_ker_f,
              output reg [31:0] img_out_f,
              output reg [31:0] ker_out_f);


reg [7:0] img_in [15:0];
reg [7:0] ker_in [9:0];
reg [3:0] sel_in [3:0];
reg [3:0] sel_ker [3:0];
reg [7:0] img_out [3:0];
reg [7:0] ker_out [3:0];


always @(*)
begin
  {img_in[0],img_in[1],img_in[2],img_in[3],
   img_in[4],img_in[5],img_in[6],img_in[7],
   img_in[8],img_in[9],img_in[10],img_in[11],
   img_in[12],img_in[13],img_in[14],img_in[15]} = img_in_f;

  {ker_in[0],ker_in[1],ker_in[2],ker_in[3],
   ker_in[4],ker_in[5],ker_in[6],ker_in[7],
   ker_in[8],ker_in[9]} = ker_in_f;

  {sel_in[0],sel_in[1],sel_in[2], sel_in[3]} = sel_in_f;

  {sel_ker[0],sel_ker[1],sel_ker[2], sel_ker[3]} = sel_ker_f;
  
  img_out[0] = img_in[sel_in[0]];
  img_out[1] = img_in[sel_in[1]];
  img_out[2] = img_in[sel_in[2]];
  img_out[3] = img_in[sel_in[3]];


  ker_out[0] = ker_in[sel_ker[0]];
  ker_out[1] = ker_in[sel_ker[1]];
  ker_out[2] = ker_in[sel_ker[2]];
  ker_out[3] = ker_in[sel_ker[3]];
  
  img_out_f = {img_out[0],img_out[1],img_out[2], img_out[3]};

  ker_out_f = {ker_out[0],ker_out[1],ker_out[2], ker_out[3]};

end

endmodule

module switch_A_I_sel_gen(input reset,
                          input clock,
                          input enable,
                          input [7:0] N,
                          output reg [3:0] sel_out);
reg isOdd;
reg [3:0] sel; 
reg [7:0] odd_count; 
always @(posedge clock or negedge reset)
begin
  if(!reset)
    begin
      isOdd = 1;
      sel <= 0;
      odd_count = 0;
    end
  else
    begin
      if(enable)
        begin
          sel_out <= sel;
          if(isOdd)
            begin
              case(sel)
                4'd0: sel <= 4'd1;
                4'd1: sel <= 4'd2;
                4'd2: sel <= 4'd3;
                4'd3: sel <= 4'd4;
                4'd4: sel <= 4'd5;
                4'd5: sel <= 4'd8;
                4'd8: sel <= 4'd10;
                4'd10: sel <= 4'd12;
                4'd12:
                  begin
                    
                    odd_count = odd_count + 1;
                    if(odd_count == ((N>>1)-1))
                      begin
                        $display(((N>>1)-1));
                        sel <= 4'd0;
                        isOdd = 1;
                        odd_count = 0;
                      end
                    else
                      begin
                        sel <= 4'd8;
                        isOdd = 0;
                      end  
                  end
                default: sel <= 4'd0;
              endcase
            end
          else
            begin
              case(sel)
                4'd8: sel <= 4'd9;
                4'd9: sel <= 4'd10;
                4'd10: sel <= 4'd11;
                4'd11: sel <= 4'd12;
                4'd12: sel <= 4'd13;
                4'd13: sel <= 4'd0;
                4'd0: sel <= 4'd2;
                4'd2: sel <= 4'd4;
                4'd4:
                  begin
                    sel <= 4'd0;
                    isOdd = 1;
                    odd_count = odd_count + 1;
                  end
                default: sel <= 4'd0;
              endcase          
            end
        end
    end
end

endmodule

module switch_B_I_sel_gen(input reset,
                          input clock,
                          input enable,
                          input [7:0] N,
                          output reg [3:0] sel_out);
reg isOdd;
reg [3:0] sel; 
reg [7:0] odd_count; 
always @(posedge clock or negedge reset)
begin
  if(!reset)
    begin
      isOdd = 1;
      sel <= 1;
      odd_count = 0;
    end
  else
    begin
      if(enable)
        begin
          sel_out <= sel;
          if(isOdd)
            begin
              case(sel)
                4'd1: sel <= 4'd3;
                4'd3: sel <= 4'd5;
                4'd5: sel <= 4'd8;
                4'd8: sel <= 4'd9;
                4'd9: sel <= 4'd10;
                4'd10: sel <= 4'd11;
                4'd11: sel <= 4'd12;
                4'd12: sel <= 4'd13;
                4'd13:
                  begin
                    
                    odd_count = odd_count + 1;
                    if(odd_count == ((N>>1)-1))
                      begin
                        $display(((N>>1)-1));
                        sel <= 4'd1;
                        isOdd = 1;
                        odd_count = 0;
                      end
                    else
                      begin
                        sel <= 4'd9;
                        isOdd = 0;
                      end  
                  end
                default: sel <= 4'd1;
              endcase
            end
          else
            begin
              case(sel)
                4'd9: sel <= 4'd11;
                4'd11: sel <= 4'd13;
                4'd13: sel <= 4'd0;
                4'd0: sel <= 4'd1;
                4'd1: sel <= 4'd2;
                4'd2: sel <= 4'd3;
                4'd3: sel <= 4'd4;
                4'd4: sel <= 4'd5;
                4'd5:
                  begin
                    sel <= 4'd1;
                    isOdd = 1;
                    odd_count = odd_count + 1;
                  end
                default: sel <= 4'd1;
              endcase          
            end
        end
    end
end

endmodule

module switch_C_I_sel_gen(input reset,
                          input clock,
                          input enable,
                          input [7:0] N,
                          output reg [3:0] sel_out);
reg isOdd;
reg [3:0] sel; 
reg [7:0] odd_count; 
always @(posedge clock or negedge reset)
begin
  if(!reset)
    begin
      isOdd = 1;
      sel <= 4'd2;
      odd_count = 0;
    end
  else
    begin
      if(enable)
        begin
          sel_out <= sel;
          if(isOdd)
            begin
              case(sel)
                4'd2: sel <= 4'd3;
                4'd3: sel <= 4'd4;
                4'd4: sel <= 4'd5;
                4'd5: sel <= 4'd6;
                4'd6: sel <= 4'd7;
                4'd7: sel <= 4'd10;
                4'd10: sel <= 4'd12;
                4'd12: sel <= 4'd14;
                4'd14:
                  begin
                    
                    odd_count = odd_count + 1;
                    if(odd_count == ((N>>1)-1))
                      begin
                        $display(((N>>1)-1));
                        sel <= 4'd2;
                        isOdd = 1;
                        odd_count = 0;
                      end
                    else
                      begin
                        sel <= 4'd10;
                        isOdd = 0;
                      end  
                  end
                default: sel <= 4'd2;
              endcase
            end
          else
            begin
              case(sel)
                4'd10: sel <= 4'd11;
                4'd11: sel <= 4'd12;
                4'd12: sel <= 4'd13;
                4'd13: sel <= 4'd14;
                4'd14: sel <= 4'd15;
                4'd15: sel <= 4'd2;
                4'd2: sel <= 4'd4;
                4'd4: sel <= 4'd6;
                4'd6:
                  begin
                    sel <= 4'd2;
                    isOdd = 1;
                    odd_count = odd_count + 1;
                  end
                default: sel <= 4'd2;
              endcase          
            end
        end
    end
end

endmodule

module switch_D_I_sel_gen(input reset,
                          input clock,
                          input enable,
                          input [7:0] N,
                          output reg [3:0] sel_out);
reg isOdd;
reg [3:0] sel; 
reg [7:0] odd_count; 
always @(posedge clock or negedge reset)
begin
  if(!reset)
    begin
      isOdd = 1;
      sel <= 4'd3;
      odd_count = 0;
    end
  else
    begin
      if(enable)
        begin
          sel_out <= sel;
          if(isOdd)
            begin
              case(sel)
                4'd3: sel <= 4'd5;
                4'd5: sel <= 4'd7;
                4'd7: sel <= 4'd10;
                4'd10: sel <= 4'd11;
                4'd11: sel <= 4'd12;
                4'd12: sel <= 4'd13;
                4'd13: sel <= 4'd14;
                4'd14: sel <= 4'd15;
                4'd15:
                  begin
                    
                    odd_count = odd_count + 1;
                    if(odd_count == ((N>>1)-1))
                      begin
                        $display(((N>>1)-1));
                        sel <= 4'd3;
                        isOdd = 1;
                        odd_count = 0;
                      end
                    else
                      begin
                        sel <= 4'd11;
                        isOdd = 0;
                      end  
                  end
                default: sel <= 4'd3;
              endcase
            end
          else
            begin
              case(sel)
                4'd11: sel <= 4'd13;
                4'd13: sel <= 4'd15;
                4'd15: sel <= 4'd2;
                4'd2: sel <= 4'd3;
                4'd3: sel <= 4'd4;
                4'd4: sel <= 4'd5;
                4'd5: sel <= 4'd6;
                4'd6: sel <= 4'd7;
                4'd7:
                  begin
                    sel <= 4'd3;
                    isOdd = 1;
                    odd_count = odd_count + 1;
                  end
                default: sel <= 4'd3;
              endcase          
            end
        end
    end
end

endmodule


module switch_A_C_K_sel_gen(input reset,
                            input clock,
                            input enable,
                            output reg [3:0] sel_out);
  reg [3:0] sel;
always @(posedge clock or negedge reset)
  begin
    if(!reset)
      begin
        sel <= 0;
      end
    else
      begin
        if(enable)
          begin
            sel_out <= sel;
            case(sel)
              4'd0: sel <= 4'd1;
              4'd1: sel <= 4'd3;
              4'd3: sel <= 4'd4;
              4'd4: sel <= 4'd6;
              4'd6: sel <= 4'd7;
              4'd7: sel <= 4'd2;
              4'd2: sel <= 4'd5;
              4'd5: sel <= 4'd8;
              4'd8: sel <= 4'd0;
              default: sel <= 0;
            endcase
          end
      end
  end

endmodule

module switch_B_D_K_sel_gen(input reset,
                            input clock,
                            input enable,
                            output reg [3:0] sel_out);
  reg [3:0] sel;
always @(posedge clock or negedge reset)
  begin
    if(!reset)
      begin
        sel <= 0;
      end
    else
      begin
        if(enable)
          begin
            sel_out <= sel;
            case(sel)
              4'd0: sel <= 4'd3;
              4'd3: sel <= 4'd6;
              4'd6: sel <= 4'd1;
              4'd1: sel <= 4'd2;
              4'd2: sel <= 4'd4;
              4'd4: sel <= 4'd5;
              4'd5: sel <= 4'd7;
              4'd7: sel <= 4'd8;
              4'd8: sel <= 4'd0;
              default: sel <= 0;
            endcase
          end
      end
  end

endmodule

module FSM_sel_gen_en(input reset,
                      input clock,
                      input enable,
                      input [7:0] N,
                      output reg sel_part_change,
                      output reg sel_en,
                      output reg MAC_en,
                      output reg MAC_reset, 
                      output reg output_buffer_enable,
                      output reg ouput_SRAM_addr_gen_enable);

reg [1:0] current_state, next_state;
reg [3:0] mcounter;
reg isFirst;
reg isFirst_s1;
reg [5:0] num_rows;
reg [5:0] num_cols;
reg isNewRow;
reg [1:0] isEven;
reg isLastElement;


parameter
  s0 = 0,
  s1 = 1,
  s2 = 2,
  s3 = 3;

always @(posedge clock or negedge reset)
  begin
  if (!reset)
    begin
      current_state = s0;
    end
  else
    begin
      if(enable)
        begin
          current_state = next_state;
        end
    end
  end

always @(negedge reset or posedge clock)
  begin
    if (!reset)
      begin
        next_state = s0;
        mcounter = 0;
        isFirst_s1 = 1;
        isNewRow = 0;
      end
    else if(enable)
      begin
        mcounter = mcounter + 1;
        case(current_state)
          s0:
            begin
              if(!isNewRow)
                begin
                  if(mcounter == 5)
                    begin
                      next_state = s1;
                      mcounter = 0;
                    end
                end
              else
                begin
                  if(mcounter == 1)
                    begin
                      isNewRow = 0;
                      next_state = s1;
                      mcounter = 0;
                    end
                end  
            end
          s1:
            begin
              if(isFirst_s1)
                begin
                  if(mcounter == 4)
                    begin
                      isFirst_s1 = 0;
                      next_state = s2;
                      mcounter = 0;
                    end
                end
              else
                begin
                  if(mcounter == 3)
                    begin
                      next_state = s2;
                      mcounter = 0;
                    end          
                end
            end
          s2:
            begin
              if(mcounter == 6)
                begin
                  next_state = s3;
                  mcounter = 0;
                end            
            end
          s3:
            begin
              if(mcounter == 3)
                begin
                  next_state = s1;
                  mcounter = 0;
                end      
            end
        endcase
      end
  end

always @(posedge clock /*current_state or enable or mcounter or reset*/)
  begin
    if (!reset)
      begin
        num_rows = 0;
        num_cols = 0;
        isEven = 0;
        sel_part_change = 0;
        sel_en = 0;
        isFirst = 1;
        isLastElement = 0;
        MAC_reset = 0;
      end
    else if(enable)
      begin
        case(current_state)
          s0:
            begin
              sel_en = 0;
              if(!isNewRow)
                begin
                  if(mcounter == 4)
                    begin
                      if(isFirst)
                        begin
                          sel_part_change = ~sel_part_change;
                        end
                    end
                end
            end
          s1:
            begin 
              sel_en = 1;
              if(mcounter == 1)
                begin 
                  num_cols = num_cols + 1;
                  isEven = isEven + 1;
                end
              if(isFirst)
                begin
                  if(mcounter == 2)
                    begin
                      MAC_en = 1;
                    end
                end
              else
                begin
                  MAC_en = 1;
                end
              MAC_reset = 1;
              ouput_SRAM_addr_gen_enable = 0;
              if(isFirst)
                begin
                  isFirst = 0;
                end
            end
        s2:
          begin
            sel_en = 1;
            if(mcounter == 1)
              sel_part_change = ~sel_part_change;
            if(mcounter == 3)
              begin
                if(num_cols == ((N >> 1) - 1))
                  begin
                    num_cols = 0;
                    num_rows = num_rows + 1;
                    if(num_rows == ((N >> 1) - 1))
                      begin
                        isLastElement = 1;
                      end
                    sel_part_change = ~sel_part_change;
                  end
              end            
          end
        s3:
          begin 
            sel_en = 0;
            MAC_en = 0;

            if(mcounter == 1)
              begin
                output_buffer_enable = 1;
                if(isEven == 2 || isLastElement)
                  begin
                    isEven = 0;
                    ouput_SRAM_addr_gen_enable = 1;
                  end
                else
                  begin
                    ouput_SRAM_addr_gen_enable = 0;
                  end
              end
            else
              begin
                output_buffer_enable = 0;
                ouput_SRAM_addr_gen_enable = 0;
              end

            if(mcounter == 2)
              begin
                MAC_reset = 0;
                isLastElement = 0;
              end
          end
      endcase
    end
  else
    begin
      sel_part_change = 0;
      sel_en = 0;
      MAC_en = 0;
      MAC_reset = 0;
      output_buffer_enable=0;
      ouput_SRAM_addr_gen_enable=0;
    end
end

endmodule

module FSM_addr_gen_en(input reset,
                        input clock,
                        input enable,
  						          input sel_part_change,
                        output reg in_addr_gen_en);


reg current_state, next_state;
reg prev_sel_part_change;
reg [2:0] mcounter;

parameter 
  s0 = 0,
  s1 = 1;

always @(posedge clock or negedge reset)
  begin
   if (!reset)
    begin
      current_state = s0;
    end
   else
    begin
      if(enable)
        begin
          current_state = next_state;
        end
    end
  end

always @(posedge clock or negedge reset)
  begin
    if(!reset)
    begin
      next_state = s0;
      prev_sel_part_change = 0;
      mcounter = 0;
    end
    else if(enable)
    begin
      mcounter = mcounter + 1;
      case(current_state)
        s0: 
         	begin
            if(mcounter == 4)
           	begin
             		mcounter = 0;
             		next_state = s1;
           	end
            end
        s1:
          begin
            if(prev_sel_part_change != sel_part_change)
              begin
                prev_sel_part_change = sel_part_change;
                next_state = s0;
                mcounter = 0;
              end
          end
      endcase
    end
  end

always @(current_state or enable or reset)
begin
  if(enable)
    begin
      if(current_state == s0)
        in_addr_gen_en = 1;
      else
        in_addr_gen_en = 0;
    end
  else
    begin
      in_addr_gen_en = 0;
    end
end

endmodule

module MAC_A_1(input reset,
               input clock,
               input MAC_en,
               input signed [7:0] MAC_In,
               input signed [7:0] MAC_Ker,
               output reg signed [19:0] MAC_out);

always @(posedge clock or negedge reset)
  begin
    if(!reset)
      begin
        MAC_out <= 20'b0;
      end
    else
      begin
        if(MAC_en)
          begin
            MAC_out <= MAC_out +  (MAC_In*MAC_Ker);
          end
      end
  end

endmodule


module MAC_A_4x(input reset,
               input clock,
               input MAC_en,
               input [31:0] MAC_In_f,
               input [31:0] MAC_Ker_f,
               output reg [79:0] MAC_out_f);

  reg signed [7:0] MAC_In [3:0];
  reg signed [7:0] MAC_Ker [3:0];
  wire [19:0] MAC_out [3:0];

  always@(*)
  begin
    {MAC_In[0],MAC_In[1],MAC_In[2],MAC_In[3]}  =  MAC_In_f;
    {MAC_Ker[0],MAC_Ker[1],MAC_Ker[2],MAC_Ker[3]}  =  MAC_Ker_f;
  end 

  always@(*)
  begin
    MAC_out_f = {MAC_out[0],MAC_out[1],MAC_out[2],MAC_out[3]};
  end
  
  MAC_A_1 outA(reset,clock,MAC_en,MAC_In[0],MAC_Ker[0],MAC_out[0]);
  MAC_A_1 outB(reset,clock,MAC_en,MAC_In[1],MAC_Ker[1],MAC_out[1]);
  MAC_A_1 outC(reset,clock,MAC_en,MAC_In[2],MAC_Ker[2],MAC_out[2]);
  MAC_A_1 outD(reset,clock,MAC_en,MAC_In[3],MAC_Ker[3],MAC_out[3]);

endmodule


module max_pool_ReLu(input [79:0] max_pool_in_f,
                     output reg [7:0] max_pool_output);

reg signed [19:0] max_pool_in [3:0];
reg signed [19:0] max_A_B;
reg signed [19:0] max_C_D;
reg signed [19:0] MAC_max_output;
reg is_MAC_max;
  
always@(*)
begin
  {max_pool_in[0],max_pool_in[1], max_pool_in[2],max_pool_in[3]} = max_pool_in_f;
end  
always @(*)
begin
  
  if(max_pool_in[0] > max_pool_in[1])
    max_A_B <= max_pool_in[0];
  else
    max_A_B <= max_pool_in[1];

  if(max_pool_in[2] > max_pool_in[3])
    max_C_D <= max_pool_in[2];
  else
    max_C_D <= max_pool_in[3];

  if(max_A_B > max_C_D)
    MAC_max_output <= max_A_B;
  else
    MAC_max_output <= max_C_D;

  if(MAC_max_output >= 20'sd127)
    is_MAC_max = 1;
  else
    is_MAC_max = 0;

  if(is_MAC_max)
    max_pool_output <= 127;
  else
    if(MAC_max_output[19])
      max_pool_output <= 0;
    else
      max_pool_output <= {1'b0,MAC_max_output[6:0]};
end
endmodule


module output_buffer(input reset,
                    input clock,
                    input enable,
                    input [7:0] in,
                    output reg [15:0] out);

  reg write_ptr;
  reg [7:0] mbuf[1:0];

  always @(posedge clock or negedge reset) begin
    if(!reset)
      begin
        //clear write pointer and buffer on reset
        write_ptr <= 0;
        mbuf[0] <= 8'h00;
        mbuf[1] <= 8'h00;
      end
    else
      begin
        if(enable)
          begin
            mbuf[write_ptr] <= in;
            write_ptr <= write_ptr + 1;
          end
      end
  end

  always @(*)
    begin
      out <= {mbuf[0],mbuf[1]};
    end
endmodule

module output_SRAM_addr_gen(input reset,
                           input clock,
                           input enable,
                            input [7:0] N,
                           output reg [11:0] gen_addr,
                           output reg done);
  reg [11:0] addr;
  reg [11:0] addr_count;
  always @(posedge clock or negedge reset)
    begin
      if(!reset)
        begin
          addr <= 0;
          done <= 0;
          addr_count <= 0;
        end
      else
        begin
          if(enable) 
            begin
              gen_addr <= addr;
              addr <= addr + 1;
              if(addr_count == ((((((N >> 1) - 1) * ((N >> 1) - 1)) + 1) >> 1) - 1))
                begin
                	addr_count <= 0;
                	done <= 1;
                end
              else
                begin
                  	addr_count <= addr_count + 1;
                	done <= 0;
                end
            end
        end

  end
endmodule