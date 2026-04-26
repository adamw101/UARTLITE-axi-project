# UARTLite AXI Project

-----
## Overview
SystemVerilog-based FPGA project integrating AXI UART Lite IP with a custom AXI master controller.

The design enables:
- bidirectional UART communication
- memory-mapped AXI transactions
- interrupt-driven data handling

The project includes a testbench with CSV-driven stimulus for reproducible UART RX/TX simulation.

Vivado project is fully generated from Tcl scripts, ensuring portability and build reproducibility.

-----
## Project Structure

```
├── ip/
│ └── axi_uartlite_0.xci
├── scripts/
│ └── uartlite_axi_project.tcl
├── sim/
│   ├── tb/
│   │   └── uartlite_axi_master_tb.sv
│   └── data/
│       ├── uart_input_data.csv
│       └── data_to_send_from_uart.csv
├── src/
│ └── uartlite_axi_master.sv
├── .gitignore
└── README.md
```
-----
## Requirements

- Vivado 2025.2 (or compatible)
- Windows environment

-----
## Setup Instructions
1. Pull project  
2. Open Tcl console in Vivado  
3. Navigate to project location  
4. Execute:

```tcl
source scripts/uartlite_axi_project.tcl
```

-----
## Features

- AXI4-Lite master implementation
- Integration with Xilinx AXI UART Lite IP
- Interrupt-driven communication
- CSV-based simulation stimulus
- Fully reproducible Tcl-based build flow
-----
## About
This repository is a portfolio project showcasing practical experience with the AXI protocol in an FPGA environment.  
It focuses on implementing and verifying an AXI-based design around a UART subsystem, demonstrating understanding of memory-mapped transactions, handshaking, and integration with vendor IP.