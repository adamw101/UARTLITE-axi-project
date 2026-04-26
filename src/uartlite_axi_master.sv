`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Adam Wodzyński
// 
// Create Date: 26.04.2026 10:26:12
// Design Name: 
// Module Name: uarlite_axi_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//this module funcions as a Axi Master for LogiCORE IP AXI UART Lite
//UART Lite IP is configured to generate an interrupt when receive FIFO is not empty 
//IP is used as botr receiver and transmitter but receiving data has precedence
module uartlite_axi_master
 #(
    parameter integer AXI_ADDR_WIDTH = 4,
    parameter integer AXI_DATA_WIDTH = 32
    )
    (   

        input wire                          M_AXI_ACLK,
        input wire                          M_AXI_ARESETN,

        //rx data
        input wire                          uart_fifo_ready_i,
        output wire [7:0]                   received_rx_data_o,
        output wire                         rx_int_o,
        //tx data
        input wire  [7:0]                   tx_data_to_send_i,
        input wire                          tx_int_i,

        //AR
        output wire [AXI_ADDR_WIDTH-1:0]    M_AXI_ARADDR,
        input  wire                         M_AXI_ARREADY,
        output wire                         M_AXI_ARVALID,

        //AW
        output wire [AXI_ADDR_WIDTH-1:0]    M_AXI_AWADDR,
        input  wire                         M_AXI_AWREADY,
        output wire                         M_AXI_AWVALID,

        //BR
        output wire                         M_AXI_BREADY,
        input  wire [1:0]                   M_AXI_BRESP,
        input  wire                         M_AXI_BVALID,

        //R
        input  wire [AXI_DATA_WIDTH-1:0]    M_AXI_RDATA,
        output wire                         M_AXI_RREADY,
        input  wire [1:0]                   M_AXI_RRESP,
        input  wire                         M_AXI_RVALID,

        //W
        output wire [AXI_DATA_WIDTH-1:0]    M_AXI_WDATA,
        input  wire                         M_AXI_WREADY,
        output wire [3:0]                   M_AXI_WSTRB,
        output wire                         M_AXI_WVALID 
    );

    
    logic [7:0]                   received_rx_data = 8'b0;
    assign received_rx_data_o   =   received_rx_data;
    logic                         rx_int = 0;
    assign rx_int_o             =   rx_int;
    //AXI variables
    //AR
    logic [AXI_ADDR_WIDTH-1:0]    axi_araddr;
    logic                         axi_arvalid;

    assign M_AXI_ARADDR       =   axi_araddr;
    assign M_AXI_ARVALID      =   axi_arvalid;

    //AW
    logic [AXI_ADDR_WIDTH-1:0]    axi_awaddr = 4'b0;
    logic                         axi_awvalid = 1'b0;

    assign M_AXI_AWADDR       =   axi_awaddr;
    assign M_AXI_AWVALID      =   axi_awvalid;

    //BR
    logic                         axi_bready = 0;
    logic                         axi_berror;
    assign M_AXI_BREADY       =   axi_bready;

    //R
    logic                         axi_rready = 0;
    logic                         axi_rerror;
    assign M_AXI_RREADY       =   axi_rready;

    //W
    logic [AXI_DATA_WIDTH-1:0]    axi_wdata = 32'b0;
    logic [3:0]                   axi_wstrb = 4'b0;
    logic                         axi_wvalid = 1'b0;

    assign M_AXI_WDATA        =   axi_wdata;
    assign M_AXI_WSTRB        =   axi_wstrb;
    assign M_AXI_WVALID       =   axi_wvalid;

    //variables and logic for signalling arrrival of the new rx data byte
    logic uart_fifo_ready;

    always_ff @( posedge M_AXI_ACLK ) 
    begin
        uart_fifo_ready <= uart_fifo_ready_i;    
    end

    logic uart_interrupt_detected;

    assign uart_interrupt_detected =(uart_fifo_ready_i & ~uart_fifo_ready) ? 1:0;

    //variables and logic for signalling arrrival of the new byte to be sent
    logic tx_int;
    logic tx_interrupt_detected;
    always_ff @( posedge M_AXI_ACLK ) 
    begin 
        tx_int<= tx_int_i;
    end
    assign tx_interrupt_detected = (!tx_int & tx_int_i) ? 1 : 0;

    //fsm variables
    typedef enum  {IDLE,READ_RECEIVE_FIFO, ENABLE_INTERRUPTS,READ_STAT_REG,WRITE_TRANSMIT_FIFO} my_state;

    logic valid;
    logic [31:0] state_counter;

    my_state next_state_fsm = IDLE;
    my_state current_state_fsm = IDLE;

    //variables for axi read and write process
    logic        start_write;
    logic        start_read;

    logic        read_complete;
    assign read_complete = M_AXI_RVALID & axi_rready;
    
    logic        write_complete;
    assign write_complete = M_AXI_BVALID & axi_bready;

    logic        are_interrupts_enabled=0;

    //clocked current state logic
    always_ff @(posedge M_AXI_ACLK or negedge M_AXI_ARESETN)
    begin
        if (!M_AXI_ARESETN) 
            current_state_fsm <= IDLE;    
        else begin
            current_state_fsm <= next_state_fsm;
        end
    end

    //logic for counting clock cycles in current state
    always_ff @(posedge M_AXI_ACLK or negedge M_AXI_ARESETN)
    begin
        if (!M_AXI_ARESETN) 
            state_counter <= '0;
        else begin
            if(current_state_fsm != next_state_fsm)
                state_counter <= '0;
            else begin
                state_counter <= state_counter +1'b1;
            end
        end
    end

    //next state logic
    always_comb 
    begin 
        next_state_fsm = current_state_fsm;
        start_read = 0;
        start_write = 0;
        case (current_state_fsm)
            IDLE:
                if (!are_interrupts_enabled) begin
                    next_state_fsm = ENABLE_INTERRUPTS;
                    start_write=1;
                end
                else
                begin
                    if (uart_interrupt_detected) begin
                        next_state_fsm = READ_RECEIVE_FIFO;
                        start_read = 1;
                    end
                    else if (tx_interrupt_detected) begin
                        next_state_fsm = WRITE_TRANSMIT_FIFO;
                        start_write = 1;
                    end
                end
            ENABLE_INTERRUPTS:
                if (write_complete) begin
                    next_state_fsm = READ_STAT_REG;
                    start_read =1;
                end
            READ_STAT_REG:
                if (read_complete) begin
                    next_state_fsm = IDLE;
                    
                end
            READ_RECEIVE_FIFO:
                if (read_complete) begin
                    next_state_fsm = IDLE;
                end
            WRITE_TRANSMIT_FIFO: 
                if (write_complete) begin
                    next_state_fsm = IDLE;
                end
        endcase
    end



    //AW
    always_comb
    begin
        axi_awaddr <= 4'h0;
        case (current_state_fsm)
            ENABLE_INTERRUPTS:
                axi_awaddr <= 4'hC;
            WRITE_TRANSMIT_FIFO:
                axi_awaddr <= 4'h4;
            default:
            axi_awaddr <= 4'h0; 
        endcase 
    end

    //W
    always_comb
    begin
        axi_wdata <= 32'h00000000;
        case (current_state_fsm)
            ENABLE_INTERRUPTS:
                axi_wdata <= 32'h00000010;
            WRITE_TRANSMIT_FIFO:
                axi_wdata <= tx_data_to_send_i;
            default:
            axi_wdata <= 32'h00000000; 
        endcase
    end


    //AR
    always_comb
    begin
        axi_araddr <= 'hF;
        case(current_state_fsm)
            READ_RECEIVE_FIFO:
                axi_araddr <= 'h0;
            READ_STAT_REG:
                axi_araddr <= 'h8;
            default :
                axi_araddr <= 'hF;
        endcase
    end



    // Address read interface
    always_ff @(posedge M_AXI_ACLK or negedge M_AXI_ARESETN )
    begin
        if (!M_AXI_ARESETN) begin
            axi_arvalid <= 1'b0;
        end else begin
            if (start_read) begin
                axi_arvalid <= 1'b1;
            end

            if (M_AXI_ARREADY & axi_arvalid) begin
                axi_arvalid <= 1'b0;
            end
        end
    end
    // DATA read interface
    always_ff @(posedge M_AXI_ACLK or negedge M_AXI_ARESETN)
    begin
        if (!M_AXI_ARESETN) begin
            axi_rready <= 1'b0;
            axi_rerror <= 1'b0;
            received_rx_data<= 8'b0;
            rx_int <= 0;
        end else begin
                rx_int <= 0;
                axi_rready <= 1'b1;

            if (M_AXI_RVALID & axi_rready) begin
                if (M_AXI_RRESP > 0)
                    begin
                        axi_rerror <= 1;
                    end
                    else
                    begin
                        axi_rerror<= 0;
                        
                        if (are_interrupts_enabled) begin
                            rx_int <= 1;
                            received_rx_data <= M_AXI_RDATA[7:0];  
                        end
                        else begin
                            if (M_AXI_RDATA[4]==1) begin
                                are_interrupts_enabled <=  1;
                            end
                            else begin
                                are_interrupts_enabled <= 0;
                            end
                            
                        end
                        
                    end
            end
        end
    end

    //Address write interface
    always_ff @( posedge M_AXI_ACLK or negedge M_AXI_ARESETN) 
    begin
        if (!M_AXI_ARESETN) begin
            axi_awvalid <= 1'b0;
        end else begin
            if (start_write) begin
                axi_awvalid <= 1'b1;
            end

            if(M_AXI_AWREADY && axi_awvalid)
            begin
                axi_awvalid <= 1'b0;
            end
        end    
    end

    //Data write interface
    always_ff @( posedge M_AXI_ACLK or negedge M_AXI_ARESETN) 
    begin
        if (!M_AXI_ARESETN) begin
             axi_wvalid<= 1'b0;
        end else begin
            if (start_write) begin
                axi_wvalid<= 1'b1;
                axi_wstrb<= 4'b1111;
            end

            if(M_AXI_WREADY && axi_wvalid)
            begin
                axi_wvalid<= 1'b0;
            end
        end    
    end
    //Response channel interface
    always_ff @( posedge M_AXI_ACLK or negedge M_AXI_ARESETN) 
    begin
        if (!M_AXI_ARESETN) begin
             axi_bready<= 1'b0;
             axi_berror<=1'b0;
        end else begin
            axi_bready<= 1'b1;

            if(M_AXI_BVALID && axi_bready)
            begin
                if (M_AXI_BRESP >0) begin
                    axi_berror <= 1'b1;
                end else begin
                    axi_berror <= 1'b0;
                end
            end
        end

    end
endmodule

