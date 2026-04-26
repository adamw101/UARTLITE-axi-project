`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.03.2026 17:57:35
// Design Name: 
// Module Name: uartlite_axi_master_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - file_in1 Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//`include "vivado_interfaces.svh"

module uartlite_axi_master_tb#(
    parameter integer AXI_ADDR_WIDTH = 4,
    parameter integer AXI_DATA_WIDTH = 32
    )(
);
    logic                          CLK_tb;
    logic                          reset_tb;
    logic                          uart_tx_tb;
    logic                          uart_rx_tb;
    
    localparam clk_freq              = 100000000;
    localparam clk_period            = 1000000000/clk_freq;//ns
    localparam baudrate              = 9600;
    localparam uart_period = clk_period*clk_freq/baudrate;//104166; 

    logic [7:0]                   received_rx_data_tb;
    logic                         rx_int_tb;

    //AR
    logic [AXI_ADDR_WIDTH-1:0]    axi_araddr_tb;
    logic                         axi_arvalid_tb;
    logic                         axi_arready_tb;


    //AW
    logic [AXI_ADDR_WIDTH-1:0]    axi_awaddr_tb;
    logic                         axi_awvalid_tb;
    logic                         axi_awready_tb;

    //BR
    logic                         axi_bready_tb;
    logic [1:0]                   axi_bresp_tb;
    logic                         axi_bvalid_tb;

    //R
    logic                         axi_rready_tb;
    logic                         axi_rvalid_tb;
    logic [AXI_DATA_WIDTH-1:0]    axi_rdata_tb;
    logic [1:0]                   axi_rresp_tb;

    //W
    logic [AXI_DATA_WIDTH-1:0]    axi_wdata_tb;
    logic [3:0]                   axi_wstrb_tb;
    logic                         axi_wvalid_tb;
    logic                         axi_wready_tb;

    logic                         uart_interrupt;

    logic [7:0]                   tx_data_to_send_tb;
    logic                         tx_int_tb;

    //variables for file operations
    integer file_in1,file_in2, data_byte1,data_byte2,status1,status2;

    //this task sends byte to uartlite_axi_master to be send by UARTLITE IP via tx pin
    task automatic transmit_data_from_uart(input integer data_byte, input time clk_period, ref logic [7:0] rx, ref logic intr);
        rx= data_byte[7:0];
        intr= 1;
        #clk_period;
        intr= 0;
         #(11*uart_period);
        $display("time=%0t byte %d sent from uart", $time, data_byte);
    endtask //automatic

    //this task generates uart signal to be received by uartlite
    task automatic transmit_data_to_uart(input integer data_byte, input time delay, ref logic tx );
        int paritycheck = $countones(data_byte);
        //start bit
        tx = 0;
        #(delay);
        //B0
        tx = data_byte[0];
        #(delay);
        //B1
        tx = data_byte[1];
        #(delay);
        //B2
        tx = data_byte[2];
        #(delay);
        //B3
        tx = data_byte[3];
        #(delay);
        //B4
        tx = data_byte[4];
        #(delay);
        //B5
        tx = data_byte[5];
        #(delay);
        //B6
        tx = data_byte[6];
        #(delay);
        //B7
        tx = data_byte[7];
        #(delay);
        // Parity
        tx = (paritycheck[0] == 1) ? 1 : 0;
        #(delay);   
        // Stop bit
        tx = 1;
        #(delay);
        $display("time=%0t byte %d sent to uart", $time, data_byte);
    endtask 

    //100MHZ clk generation
    always 
    begin
        CLK_tb=0;
        #(clk_period/2);
        CLK_tb=1;
        #(clk_period/2);
    end

    //reset process
    initial begin
        reset_tb=0;
        #50;
        reset_tb=1;
    end

    //main tb process
    initial begin
        uart_tx_tb=1;
        tx_data_to_send_tb=8'h00;
        tx_int_tb= 0;

        
        file_in1 = $fopen("uart_input_data.csv", "r");
        if (file_in1 == 0)
            $fatal("Nie można otworzyć uart_input_data.csv");

       
        #300;
        $display("Start sending data to uart");
        //generate uart signal as long as input file is not empty
        while (! $feof(file_in1)) begin
            status1 = $fscanf(file_in1," %d,",data_byte1);
            $display("status: %d",status1);
            transmit_data_to_uart(data_byte1,uart_period,uart_tx_tb);
            
        end
        

        #(uart_period);
        $fclose(file_in1);

        //generate uart bytes to be sent out as long as input file is not empty
        file_in2 = $fopen("data_to_send_from_uart.csv", "r");
        if (file_in2 == 0)
            $fatal("Nie można otworzyć data_to_send_from_uart.csv");
        $display("Start sending data from uart");
        while (! $feof(file_in2)) begin
            status2 = $fscanf(file_in2," %d,",data_byte2);
            $display("status: %d, data byte: %d",status2,data_byte2);
            transmit_data_from_uart(data_byte2,clk_period,tx_data_to_send_tb,tx_int_tb);
           
        end
        
        #10ms;
        $fclose(file_in2);
        $finish();
         
    end

    axi_uartlite_0 uartlite_inst (
        .s_axi_aclk(CLK_tb),
        .s_axi_aresetn(reset_tb),
        .interrupt(uart_interrupt),
        .s_axi_awaddr(axi_awaddr_tb),
        .s_axi_awvalid(axi_awvalid_tb),
        .s_axi_awready(axi_awready_tb),
        .s_axi_wdata(axi_wdata_tb),
        .s_axi_wstrb(axi_wstrb_tb),
        .s_axi_wvalid(axi_wvalid_tb),
        .s_axi_wready(axi_wready_tb),
        .s_axi_bresp(axi_bresp_tb),
        .s_axi_bvalid(axi_bvalid_tb),
        .s_axi_bready(axi_bready_tb),
        .s_axi_araddr(axi_araddr_tb),
        .s_axi_arvalid(axi_arvalid_tb),
        .s_axi_arready(axi_arready_tb),
        .s_axi_rdata(axi_rdata_tb),
        .s_axi_rresp(axi_rresp_tb),
        .s_axi_rvalid(axi_rvalid_tb),
        .s_axi_rready(axi_rready_tb),
        .rx(uart_tx_tb),
        .tx(uart_rx_tb)
    );

    uartlite_axi_master axi_master_inst(
        .M_AXI_ACLK(CLK_tb),
        .M_AXI_ARESETN(reset_tb),
        .uart_fifo_ready_i(uart_interrupt),
        .received_rx_data_o(received_rx_data_tb),
        .rx_int_o(rx_int_tb),
        .tx_data_to_send_i(tx_data_to_send_tb),
        .tx_int_i(tx_int_tb),
        .M_AXI_ARADDR(axi_araddr_tb),
        .M_AXI_ARREADY(axi_arready_tb),
        .M_AXI_ARVALID(axi_arvalid_tb),
        .M_AXI_AWADDR(axi_awaddr_tb),
        .M_AXI_AWREADY(axi_awready_tb),
        .M_AXI_AWVALID(axi_awvalid_tb),
        .M_AXI_BREADY(axi_bready_tb),
        .M_AXI_BRESP(axi_bresp_tb),
        .M_AXI_BVALID(axi_bvalid_tb),
        .M_AXI_RDATA(axi_rdata_tb),
        .M_AXI_RREADY(axi_rready_tb),
        .M_AXI_RRESP(axi_rresp_tb),
        .M_AXI_RVALID(axi_rvalid_tb),
        .M_AXI_WDATA(axi_wdata_tb),
        .M_AXI_WREADY(axi_wready_tb),
        .M_AXI_WSTRB(axi_wstrb_tb),
        .M_AXI_WVALID(axi_wvalid_tb) 
        );

    
endmodule
