#!/bin/bash

# Configuration
SIM_DIR="xdmac_sim_dir"
SIM_EXE="xdmac_sim"
LOG_FILE="sim.log"

# Create sim directory
mkdir -p $SIM_DIR

echo "[RUN_SIM] Compiling RTL and Testbench..."
iverilog -g2012 -o $SIM_DIR/$SIM_EXE src/*.v tb/*.v

if [ $? -eq 0 ]; then
    echo "[RUN_SIM] Compilation successful."
    echo "[RUN_SIM] Running simulation..."
    vvp $SIM_DIR/$SIM_EXE | tee $LOG_FILE
    echo "[RUN_SIM] Simulation finished. Log saved to $LOG_FILE."
    echo "[RUN_SIM] You can open the waveform with: gtkwave xdmac.vcd"
else
    echo "[RUN_SIM] Compilation failed!"
    exit 1
fi
