# Fir_Filter
Digital System Design Final Project

## **⚡ Overview :** 
This project involves the design and implementation of a digital FIR filter in Verilog, optimized for high-performance FHD(1920*1080) image processing.

## **🛠 Tools :** 
Verilog, Questa

## **🏛️ Architecture :**
The final architecture consists of a central **Core_FSM** that controls four parallel **Calc_block** module. <br>
This design allows the FHD image to be split into four section, with each PE processing a section concurrently, increasing throughput.

## **📜 Results :** 
