# FPGA-CNN-Digit-Classifier

This repository contains a hardware implementation of a **Convolutional Neural Network (CNN)** designed to classify handwritten digits from the MNIST dataset. The project is developed entirely in **Verilog HDL** and targets FPGA platforms to demonstrate high-speed, low-latency hardware inference.

## Features
* **Pure Verilog Design:** The entire RTL design is written in Verilog without relying on High-Level Synthesis (HLS).
* **Parallel Architecture:** Utilizes the parallel processing capabilities of FPGAs to optimize convolution and pooling operations.
* **MNIST Dataset:** Specifically architected to process $28 \times 28$ grayscale images for digit recognition (0-9).
* **Automated Preprocessing:** Includes a Python script (`mem_gen.py`) to convert trained weights and test images into FPGA-compatible memory files (`.mem`).
* **Verified Design:** Functionality is verified through extensive testbenches and simulation waveforms.

## Repository Structure

| File / Folder | Description |
| :--- | :--- |
| `src/` | Contains the source Verilog code for the CNN layers (Conv, Pool, FC, Activation). |
| `sim/` | Simulation files and testbenches used to verify the design logic. |
| `mem_gen.py` | Python utility script to generate memory initialization files for weights and inputs. |
| `DSDA Final Project.pdf` | Detailed technical report covering theoretical background, architecture, and resource utilization. |

## System Architecture
The hardware pipeline consists of the following stages:
1.  **Input Buffer:** Loads and stores the $28 \times 28$ pixel input image.
2.  **Convolutional Layer:** Performs feature extraction using trained kernels/filters.
3.  **Activation Function:** Applies non-linearity (e.g., ReLU) to the feature maps.
4.  **Pooling Layer:** Down-samples the data (Max Pooling) to reduce dimensionality.
5.  **Fully Connected Layer:** Flattens the data and computes the final classification scores.
6.  **Output Logic:** Determines the digit with the highest probability.

## Getting Started

### Prerequisites
* **Simulation:** Vivado, ModelSim, or Icarus Verilog.
* **Synthesis:** Xilinx Vivado or Intel Quartus (depending on your target FPGA).
* **Python:** Python 3.x (for running the memory generator script).

### Installation & Usage
1.  **Clone the Repository:**
    ```bash
    git clone [https://github.com/alkana25/FPGA-CNN-Digit-Classifier.git](https://github.com/alkana25/FPGA-CNN-Digit-Classifier.git)
    cd FPGA-CNN-Digit-Classifier
    ```

2.  **Generate Memory Files:**
    Run the script to prepare your weights and input data:
    ```bash
    python mem_gen.py
    ```

3.  **Run Simulation:**
    Open the project in your preferred simulator and run the testbenches located in the `sim/` directory to observe the classification process.

4.  **Synthesize on FPGA:**
    Add the `src/` files to your FPGA project, assign pin constraints, and generate the bitstream.

## Results & Performance
The design was evaluated based on resource usage and classification accuracy. Detailed analysis can be found in the **DSDA Final Project.pdf**.

* **Accuracy:** The hardware implementation matches the software model's accuracy on the test set.
* **Resource Utilization:** Optimized to fit within standard FPGA logic cells (LUTs) and block RAMs (BRAM).
* **Latency:** Achieves real-time classification with minimal clock cycles per image.

---
*This project was developed as a final project for the Digital System Design and Applications (DSDA) course.*
