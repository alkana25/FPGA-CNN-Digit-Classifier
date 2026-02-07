import numpy as np
import tensorflow as tf
import os
import random

# --- CONFIGURATION ---
# The directory where the .mem files will be saved.
OUTPUT_DIR = r"C:/EHB426/memory_files" 

# Set the target digit you want to test (0-9).
# The script will randomly select an image of this digit from the test set.
TARGET_DIGIT = 1

# Create the directory if it doesn't exist
if not os.path.exists(OUTPUT_DIR): 
    os.makedirs(OUTPUT_DIR)

print(f"--- OUTPUT DIRECTORY: {OUTPUT_DIR} ---")

# Fixed-point scaling factor (2^7 = 128).
# This matches the '>>> 7' shift used in the Verilog code.
SCALE = 128.0

def float_to_hex(val, bits=8):
    """
    Converts a floating-point number to a hex string for memory files.
    Applies scaling and handles saturation (clamping).
    """
    val = int(np.round(val * SCALE))
    
    if bits == 8: # For Weights (Signed 8-bit)
        # Clamp values between -128 and 127
        if val > 127: val = 127
        if val < -128: val = -128
        # Return 2-digit hex
        return f"{(val & 0xFF):02x}"
    else: # For Biases (Signed 32-bit)
        # Return 8-digit hex to prevent overflow
        return f"{(val & 0xFFFFFFFF):08x}"

def save_mem(filename, data, bits=8):
    """
    Writes a numpy array to a .mem file in hexadecimal format.
    """
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, 'w') as f:
        flat = data.flatten()
        for val in flat:
            if isinstance(val, (np.float32, float, np.float64)): 
                f.write(float_to_hex(val, bits) + "\n")
            else: 
                f.write(f"{int(val):02x}\n")
    print(f"Generated: {filename}")

# 1. Load the Trained Model
try:
    model = tf.keras.models.load_model("trained_model.keras")
    print("Model loaded successfully.")
except:
    print("ERROR: Could not find 'trained_model.keras'.")
    exit()

# 2. Extract and Convert Weights
for layer in model.layers:
    if not layer.weights: continue
    w, b = layer.get_weights()
    name = layer.name.lower()
    
    if 'conv' in name:
        # Conversion: Keras (H, W, In, Out) -> Hardware (Out, H, W, In)
        # This reorders the weights to match the Verilog iteration order.
        w = w.transpose(3, 0, 1, 2)
        save_mem("conv1_weights.mem", w)
        save_mem("conv1_bias.mem", b, bits=32) 
        
    elif 'dense' in name or 'fc' in name:
        if w.shape[0] == 676: # FC1 Layer (Flattened Input)
            print("Converting FC1 Weights to CHW Format...")
            
            # Keras flattens as H-W-C, but our FPGA hardware reads as C-H-W.
            # We must reshape and transpose the weights to match the hardware buffer.
            
            # Step 1: Recover original 4D shape (13x13 image, 4 filters, 32 neurons)
            w = w.reshape(13, 13, 4, 32)
            
            # Step 2: Transpose from (H, W, C, N) to (C, H, W, N)
            w = w.transpose(2, 0, 1, 3) 
            
            # Step 3: Flatten back to 2D
            w = w.reshape(676, 32)
            
            # Step 4: Transpose for matrix multiplication (N, Input)
            w = w.transpose()
            
            save_mem("fc1_weights.mem", w)
            save_mem("fc1_bias.mem", b, bits=32)
            
        elif w.shape[0] == 32: # FC2 Layer (Output)
            # Standard Transpose
            w = w.transpose() 
            save_mem("fc2_weights.mem", w)
            save_mem("fc2_bias.mem", b, bits=32)

# 3. Select a Test Image (RANDOM)
print("Loading MNIST Dataset...")
(_, _), (x_test, y_test) = tf.keras.datasets.mnist.load_data()

# Find all indices in the test set that match the TARGET_DIGIT
candidate_indices = np.where(y_test == TARGET_DIGIT)[0]

if len(candidate_indices) > 0:
    # Pick one random index from the candidates
    idx = np.random.choice(candidate_indices)
    print(f"Randomly Selected Index for Digit {TARGET_DIGIT}: {idx}")
else:
    print(f"ERROR: Digit {TARGET_DIGIT} not found in the test set!")
    exit()

# 4. Save the Image
path = os.path.join(OUTPUT_DIR, "test_image.mem")
with open(path, 'w') as f:
    flat = x_test[idx].flatten()
    for val in flat:
        # Ensure values are integers (0-255) before writing hex
        # (Handling cases where data might already be normalized)
        if np.max(x_test[idx]) <= 1.0: 
            val = val * 255.0
        f.write(f"{int(val):02x}\n")
