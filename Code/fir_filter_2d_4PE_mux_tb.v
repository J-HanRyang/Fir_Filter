`timescale 1ns / 1ns

module fir_filter_2d_4PE_mux_tb;
    parameter INPUT_IMAGE = "./image/florence.rgb";
    parameter INPUT_FILTER = "./image/filter_tap.dat";

    parameter OUTPUT_IMAGE = "./image/florence_dest_img_3840x1080_4PE_re_2.rgb";

    parameter INTEGER_SIZE = 32;  //integer
    parameter RGB_SIZE = 24;  //rgb total size
    parameter IMAGE_HEIGHT = 1080;
    parameter IMAGE_WIDTH = 1920;
    parameter FILTER_WIDTH = 3;
    parameter FILTER_HEIGHT = 3;
    parameter IMAGE_SIZE = IMAGE_WIDTH * IMAGE_HEIGHT;
    parameter ZEROPAD_IMAGE_SIZE = (IMAGE_WIDTH + 2) * (IMAGE_HEIGHT + 2);
    parameter FILTER_SIZE = FILTER_WIDTH * FILTER_HEIGHT;
    parameter OUTPUT_IMAGE_SIZE = (IMAGE_WIDTH * 2) * IMAGE_HEIGHT;
    parameter PE_HEIGHT = 270;
    parameter p = 20;  //200MHz
    parameter FILTERING_SIZE = 9;  //added for MAC

    reg clk;
    reg rst_n;

    reg valid_dmac;
    reg tc_set;
    reg [RGB_SIZE*FILTERING_SIZE-1:0] input_data_0;  //added for MAC
    reg [RGB_SIZE*FILTERING_SIZE-1:0] input_data_1;
    reg [RGB_SIZE*FILTERING_SIZE-1:0] input_data_2;
    reg [RGB_SIZE*FILTERING_SIZE-1:0] input_data_3;

    reg [INTEGER_SIZE-1:0] i, j;  //We can do it by just integer i; too
    reg [INTEGER_SIZE-1:0] input_fd, output_fd;
    reg [RGB_SIZE-1:0] filter_mem[FILTER_SIZE-1:0];
    reg [RGB_SIZE-1:0] image_mem[IMAGE_SIZE-1:0];
    reg [RGB_SIZE-1:0] zeropad_image_mem[ZEROPAD_IMAGE_SIZE-1:0];
    reg [RGB_SIZE-1:0] output_image_mem[OUTPUT_IMAGE_SIZE-1:0];

    reg [RGB_SIZE-1:0] output_image_pe0[(IMAGE_WIDTH*IMAGE_HEIGHT)-1:0];
    reg [RGB_SIZE-1:0] output_image_pe1[(IMAGE_WIDTH*IMAGE_HEIGHT)-1:0];
    reg [RGB_SIZE-1:0] output_image_pe2[(IMAGE_WIDTH*IMAGE_HEIGHT)-1:0];
    reg [RGB_SIZE-1:0] output_image_pe3[(IMAGE_WIDTH*IMAGE_HEIGHT)-1:0];


    wire valid_core;
    wire [RGB_SIZE-1:0] output_data_0;
    wire [RGB_SIZE-1:0] output_data_1;
    wire [RGB_SIZE-1:0] output_data_2;
    wire [RGB_SIZE-1:0] output_data_3;

    fir_filter_2d PE0 (
        .clk(clk),
        .rst_n(rst_n),
        .input_data(input_data_0),
        .valid_dmac(valid_dmac),
        .tc_set(tc_set),
        .output_data(output_data_0),
        .valid_core(valid_core)
    );
    fir_filter_2d PE1 (
        .clk(clk),
        .rst_n(rst_n),
        .input_data(input_data_1),
        .valid_dmac(valid_dmac),
        .tc_set(tc_set),
        .output_data(output_data_1),
        .valid_core(valid_core)
    );
    fir_filter_2d PE2 (
        .clk(clk),
        .rst_n(rst_n),
        .input_data(input_data_2),
        .valid_dmac(valid_dmac),
        .tc_set(tc_set),
        .output_data(output_data_2),
        .valid_core(valid_core)
    );
    fir_filter_2d PE3 (
        .clk(clk),
        .rst_n(rst_n),
        .input_data(input_data_3),
        .valid_dmac(valid_dmac),
        .tc_set(tc_set),
        .output_data(output_data_3),
        .valid_core(valid_core)
    );

    // Clock
    initial begin
        clk = 1'b0;
        forever #(p / 2) clk = ~clk;
    end

    initial begin
        rst_n = 0;
        tc_set = 0;
        valid_dmac = 0;

        #(3 * p);

        $readmemh(INPUT_FILTER, filter_mem);  //Just do it once


        input_fd = $fopen(INPUT_IMAGE, "rb");
        if (input_fd == 0) begin
            $display("Error: failed to open %s", INPUT_IMAGE);
            $finish;
        end


        $fread(image_mem[i], input_fd);  // i=0;
        $fclose(input_fd);


        output_fd = $fopen(OUTPUT_IMAGE, "wb");
        if (output_fd == 0) begin
            $display("Error: failed to open %s", OUTPUT_IMAGE);
            $finish;
        end


        //fill output_image_mem left half with original image.
        for (i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                output_image_mem[i*(IMAGE_WIDTH*2)+j] = image_mem[i*IMAGE_WIDTH+j];
            end
        end


        //fill zeropad image mem
        for (
            i = 0; i < ((IMAGE_HEIGHT + 2) * (IMAGE_WIDTH + 2)); i = i + 1
        ) begin
            zeropad_image_mem[i] = 0;
        end

        for (i = 0; i < (IMAGE_HEIGHT * IMAGE_WIDTH); i = i + 1) begin
            zeropad_image_mem[i+IMAGE_WIDTH+3+2*(i/IMAGE_WIDTH)] = image_mem[i];
        end

        //output_image_pe 초기화
        for (i = 0; i < IMAGE_WIDTH * IMAGE_HEIGHT; i = i + 1) begin
            output_image_pe0[i] = 0;
            output_image_pe1[i] = 0;
            output_image_pe2[i] = 0;
            output_image_pe3[i] = 0;
        end




        rst_n = 1;
        tc_set = 1;
        valid_dmac = 1;
        //load filter
        for (i = 0; i < FILTER_WIDTH * FILTER_HEIGHT; i = i + 1) begin
            input_data_0[RGB_SIZE-1:0] = {
                filter_mem[i][7:0], filter_mem[i][7:0], filter_mem[i][7:0]
            };
            input_data_1[RGB_SIZE-1:0] = {
                filter_mem[i][7:0], filter_mem[i][7:0], filter_mem[i][7:0]
            };
            input_data_2[RGB_SIZE-1:0] = {
                filter_mem[i][7:0], filter_mem[i][7:0], filter_mem[i][7:0]
            };
            input_data_3[RGB_SIZE-1:0] = {
                filter_mem[i][7:0], filter_mem[i][7:0], filter_mem[i][7:0]
            };
            #(p);
        end
        tc_set = 0;


        //fill input data with 3x3 crops of zeropad_image_mem
        // PE_0
        for (i = 0; i < (PE_HEIGHT); i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                input_data_0[RGB_SIZE*0+:RGB_SIZE] = zeropad_image_mem[i*(IMAGE_WIDTH+2) + j];
                input_data_0[RGB_SIZE*1+:RGB_SIZE] = zeropad_image_mem[i*(IMAGE_WIDTH+2) + (j+1)];
                input_data_0[RGB_SIZE*2+:RGB_SIZE] = zeropad_image_mem[i*(IMAGE_WIDTH+2) + (j+2)];
                input_data_0[RGB_SIZE*3+:RGB_SIZE] = zeropad_image_mem[(i+1)*(IMAGE_WIDTH+2) + j];
                input_data_0[RGB_SIZE*4+:RGB_SIZE] = zeropad_image_mem[(i+1)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_0[RGB_SIZE*5+:RGB_SIZE] = zeropad_image_mem[(i+1)*(IMAGE_WIDTH+2) + (j+2)];
                input_data_0[RGB_SIZE*6+:RGB_SIZE] = zeropad_image_mem[(i+2)*(IMAGE_WIDTH+2) + j];
                input_data_0[RGB_SIZE*7+:RGB_SIZE] = zeropad_image_mem[(i+2)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_0[RGB_SIZE*8+:RGB_SIZE] = zeropad_image_mem[(i+2)*(IMAGE_WIDTH+2) + (j+2)];

                input_data_1[RGB_SIZE*0+:RGB_SIZE] = zeropad_image_mem[(PE_HEIGHT+i)*(IMAGE_WIDTH+2) + j];
                input_data_1[RGB_SIZE*1+:RGB_SIZE] = zeropad_image_mem[(PE_HEIGHT+i)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_1[RGB_SIZE*2+:RGB_SIZE] = zeropad_image_mem[(PE_HEIGHT+i)*(IMAGE_WIDTH+2) + (j+2)];
                input_data_1[RGB_SIZE*3+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT+i)+1)*(IMAGE_WIDTH+2) + j];
                input_data_1[RGB_SIZE*4+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT+i)+1)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_1[RGB_SIZE*5+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT+i)+1)*(IMAGE_WIDTH+2) + (j+2)];
                input_data_1[RGB_SIZE*6+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT+i)+2)*(IMAGE_WIDTH+2) + j];
                input_data_1[RGB_SIZE*7+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT+i)+2)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_1[RGB_SIZE*8+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT+i)+2)*(IMAGE_WIDTH+2) + (j+2)];

                input_data_2[RGB_SIZE*0+:RGB_SIZE] = zeropad_image_mem[(PE_HEIGHT*2+i)*(IMAGE_WIDTH+2) + j];
                input_data_2[RGB_SIZE*1+:RGB_SIZE] = zeropad_image_mem[(PE_HEIGHT*2+i)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_2[RGB_SIZE*2+:RGB_SIZE] = zeropad_image_mem[(PE_HEIGHT*2+i)*(IMAGE_WIDTH+2) + (j+2)];
                input_data_2[RGB_SIZE*3+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*2+i)+1)*(IMAGE_WIDTH+2) + j];
                input_data_2[RGB_SIZE*4+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*2+i)+1)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_2[RGB_SIZE*5+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*2+i)+1)*(IMAGE_WIDTH+2) + (j+2)];
                input_data_2[RGB_SIZE*6+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*2+i)+2)*(IMAGE_WIDTH+2) + j];
                input_data_2[RGB_SIZE*7+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*2+i)+2)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_2[RGB_SIZE*8+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*2+i)+2)*(IMAGE_WIDTH+2) + (j+2)];

                input_data_3[RGB_SIZE*0+:RGB_SIZE] = zeropad_image_mem[(PE_HEIGHT*3+i)*(IMAGE_WIDTH+2) + j];
                input_data_3[RGB_SIZE*1+:RGB_SIZE] = zeropad_image_mem[(PE_HEIGHT*3+i)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_3[RGB_SIZE*2+:RGB_SIZE] = zeropad_image_mem[(PE_HEIGHT*3+i)*(IMAGE_WIDTH+2) + (j+2)];
                input_data_3[RGB_SIZE*3+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*3+i)+1)*(IMAGE_WIDTH+2) + j];
                input_data_3[RGB_SIZE*4+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*3+i)+1)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_3[RGB_SIZE*5+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*3+i)+1)*(IMAGE_WIDTH+2) + (j+2)];
                input_data_3[RGB_SIZE*6+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*3+i)+2)*(IMAGE_WIDTH+2) + j];
                input_data_3[RGB_SIZE*7+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*3+i)+2)*(IMAGE_WIDTH+2) + (j+1)];
                input_data_3[RGB_SIZE*8+:RGB_SIZE] = zeropad_image_mem[((PE_HEIGHT*3+i)+2)*(IMAGE_WIDTH+2) + (j+2)];

                #(p);
                valid_dmac = 0;

                #(p);
                output_image_mem[i*(IMAGE_WIDTH*2)+j+IMAGE_WIDTH] = output_data_0;
                output_image_mem[(PE_HEIGHT+i)*(IMAGE_WIDTH*2)+j+IMAGE_WIDTH] = output_data_1;
                output_image_mem[(2*PE_HEIGHT+i)*(IMAGE_WIDTH*2)+j+IMAGE_WIDTH] = output_data_2;
                output_image_mem[(3*PE_HEIGHT+i)*(IMAGE_WIDTH*2)+j+IMAGE_WIDTH] = output_data_3;

                #(p);
                valid_dmac = 1;
            end
        end


        #(p);
        // Read the input_fd into the 'image_mem' array
        for (i = 0; i < OUTPUT_IMAGE_SIZE; i = i + 1) begin
            $fwrite(output_fd, "%c%c%c", output_image_mem[i][16+:8],
                    output_image_mem[i][8+:8], output_image_mem[i][0+:8]);
        end
        $fclose(output_fd);

        #(4 * p);

        valid_dmac = 0;

        #(p);
        $finish;
    end


endmodule
