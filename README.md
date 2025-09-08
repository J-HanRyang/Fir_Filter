# Fir_Filter
Digital System Design Final Project

## **⚡ Overview :** 
This project involves the design and implementation of a digital FIR filter in Verilog, optimized for high-performance FHD(1920*1080) image processing. <br>
This primary goal was to overcome the performance bottleneks fo high-resolution filtering by applying a parallel architecture and enhancing the core MAC units.

## **🛠 Tools :** 
Verilog, Questa

## **🏛️ Architecture :**
The final architecture consists of a central **Core_FSM** that controls four parallel **Calc_block** module. <br>
This design allows the FHD image to be split into four section, with each PE processing a section concurrently, increasing throughput.

## **📜 Results :** 
14.64x performance improvement in FHD image filtering by implementing a parallel architecture(4PE) and an enhanced MAC unit, confirmed through testbench simulation.
