# FIR filter
## **fir_filter_2e : **
This is the baseline FIR filter module developed as an individual project. <br>
It establishes the fundamental structure and functionality for image filtering, serving as the foundation for all subsequent optimization.

## **fir_filter_2d_MAC :**
An Enhanced module where the MAC unit is redesigned for higher performance. <br>
By processing all 9 pixels required for a 3x3 filter operation in a single cycle., this module significantly improves the core calculation speed compared th toe baseline.

## **fir_filter_2d_4PE_mux_tb :**
A top-level testbench. <br>
it instantiates four FIR filter PEs to operate inparallel, processing different sections of image simulataneously. <br>
This structure increases the overall throughput and reduces the total simulation time for image filtering.
