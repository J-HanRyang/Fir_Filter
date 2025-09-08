module fir_filter_2d (
    clk,
    rst_n,
    input_data,
    valid_dmac,
    tc_set,
    output_data,
    valid_core
);
    parameter IDLE_S = 2'b00, TC_SET_S = 2'b01, CALC_S = 2'b10, WAIT_S =2'b11, MAC_W = 21, N = 24;

    input clk, rst_n;
    input valid_dmac, tc_set;
    input [N-1:0] input_data;
    output reg [N-1:0] output_data;
    output reg valid_core;

    // Reg
    reg [1:0] p_state, n_state;
    reg tc_write, tc_en, mac_en, output_en, mac_clr;

    reg [N-1:0] demux_img, demux_tc;
    reg [3:0] rear_ptr, front_ptr;
    reg [7:0] filter_tc_r[8:0];
    reg [7:0] filter_tc_g[8:0];
    reg [7:0] filter_tc_b[8:0];
    reg [7:0] filter_tc_out_r, filter_tc_out_g, filter_tc_out_b;
    reg [MAC_W-1:0] mac_r, mac_g, mac_b;

    // Core_FSM
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            p_state <= IDLE_S;
            output_data <= 0;
        end else p_state <= n_state;
    end

    always @(*) begin
        case (p_state)
            IDLE_S:
            if (tc_set == 1 && valid_dmac == 1) n_state <= TC_SET_S;
            else if (tc_set == 0 && valid_dmac == 1) n_state <= CALC_S;
            else if (valid_dmac == 0) n_state <= IDLE_S;
            else n_state <= IDLE_S;

            TC_SET_S:
            if (tc_set == 1 && valid_dmac == 1) n_state <= TC_SET_S;
            else if (tc_set == 0 && valid_dmac == 1) n_state <= CALC_S;
            else if (valid_dmac == 0) n_state <= TC_SET_S;

            CALC_S:
            if (tc_set == 0 && valid_dmac == 1) n_state <= CALC_S;
            else if (tc_set == 1 && valid_dmac == 1) n_state <= CALC_S;
            else if (valid_dmac == 0) n_state <= WAIT_S;

            WAIT_S: n_state <= IDLE_S;


        endcase
    end

    always @(*) begin
        case (p_state)
            IDLE_S:
            if (tc_set == 1 && valid_dmac == 1) begin
                mac_en = 0;
                mac_clr = 0;
                tc_en = 1;
                tc_write = 1;
                output_en = 0;
                valid_core = 0;
            end else if (tc_set == 0 && valid_dmac == 1) begin
                mac_en = 1;
                mac_clr = 0;
                tc_en = 1;
                tc_write = 0;
                output_en = 0;
                valid_core = 0;
            end else if (valid_dmac == 1) begin
                mac_en = 0;
                mac_clr = 1;
                tc_en = 0;
                tc_write = 0;
                output_en = 0;
                valid_core = 0;
            end

            TC_SET_S:
            if (tc_set == 1 && valid_dmac == 1) begin
                mac_en = 0;
                mac_clr = 0;
                tc_en = 1;
                tc_write = 1;
                output_en = 0;
                valid_core = 0;
            end else if (tc_set == 0 && valid_dmac == 1) begin
                mac_en = 1;
                mac_clr = 0;
                tc_en = 1;
                tc_write = 0;
                output_en = 0;
                valid_core = 0;
            end else if (valid_dmac == 0) begin
                mac_en = 0;
                mac_clr = 0;
                tc_en = 0;
                tc_write = 0;
                output_en = 0;
                valid_core = 0;
            end

            CALC_S:
            if (tc_set == 0 && valid_dmac == 1) begin
                mac_en = 1;
                mac_clr = 0;
                tc_en = 1;
                tc_write = 0;
                output_en = 0;
                valid_core = 0;
            end else if (tc_set == 1 && valid_dmac == 1) begin
                mac_en = 0;
                mac_clr = 0;
                tc_en = 0;
                tc_write = 0;
                output_en = 0;
                valid_core = 0;
            end else if (valid_dmac == 0) begin
                mac_en = 0;
                mac_clr = 0;
                tc_en = 0;
                tc_write = 0;
                output_en = 1;
                valid_core = 0;
            end

            WAIT_S: begin
                mac_en = 0;
                mac_clr = 1;
                tc_en = 0;
                tc_write = 0;
                output_en = 0;
                valid_core = 1;
            end
        endcase
    end


    // 2x1 mux
    always @(*) begin
        if (tc_write == 0) begin
            demux_img <= input_data;
            demux_tc  <= {N{1'bx}};
        end else begin
            demux_img <= {N{1'bx}};
            demux_tc  <= input_data;
        end
    end


    //TC_FIFO
    initial begin
        rear_ptr  = 0;
        front_ptr = 0;
    end

    always @(posedge clk) begin
        if (tc_en == 1 && tc_write == 1) begin
            if (rear_ptr >= 4'b1000) begin
                rear_ptr <= 4'b0;
            end else begin
                front_ptr <= front_ptr;
                rear_ptr  <= rear_ptr + 1;
            end

            filter_tc_r[rear_ptr] <= $signed(demux_tc[7:0]);
            filter_tc_g[rear_ptr] <= $signed(demux_tc[15:8]);
            filter_tc_b[rear_ptr] <= $signed(demux_tc[23:16]);
        end else if (tc_en == 1 && tc_write == 0) begin
            if (front_ptr < 4'b1000) begin
                front_ptr <= front_ptr + 1;
                rear_ptr  <= rear_ptr;
            end else front_ptr <= 0;
        end else begin
            front_ptr <= front_ptr;
            rear_ptr  <= rear_ptr;
        end
    end

    always @(*) begin
        filter_tc_out_r <= filter_tc_r[front_ptr];
        filter_tc_out_g <= filter_tc_g[front_ptr];
        filter_tc_out_b <= filter_tc_b[front_ptr];
    end


    // MAC
    initial begin
        mac_r = 0;
        mac_g = 0;
        mac_b = 0;
    end

    always @(posedge clk) begin
        if (mac_clr == 1) begin
            mac_r <= 0;
            mac_g <= 0;
            mac_b <= 0;
        end else if (mac_clr == 0 && mac_en == 1) begin
            mac_r[7:0] <= mac_r + filter_tc_out_r * $signed(
                {1'b0, demux_img[7:0]}
            );
            mac_g[7:0] <= mac_g + filter_tc_out_g * $signed(
                {1'b0, demux_img[15:8]}
            );
            mac_b[7:0] <= mac_b + filter_tc_out_b * $signed(
                {1'b0, demux_img[23:16]}
            );
        end else begin
            mac_r <= mac_r;
            mac_g <= mac_g;
            mac_b <= mac_b;
        end
    end


    // sat & output
    always @(posedge clk) begin
        if (output_en == 1) begin
            // Red
            if (mac_r[MAC_W] == 1) output_data[7:0] <= 0;
            else if (mac_r[MAC_W-2:0] > 255) output_data[7:0] <= 8'b11111111;
            else output_data[7:0] <= mac_r[7:0];

            // Green
            if (mac_g[MAC_W] == 1) output_data[15:8] <= 0;
            else if (mac_g[MAC_W-2:0] > 255) output_data[15:8] <= 8'b11111111;
            else output_data[15:8] <= mac_g[7:0];

            // Blue
            if (mac_b[MAC_W] == 1) output_data[23:16] <= 0;
            else if (mac_b[MAC_W-2:0] > 255) output_data[23:16] <= 8'b11111111;
            else output_data[23:16] <= mac_b[7:0];
        end else output_data <= output_data;
    end
endmodule
