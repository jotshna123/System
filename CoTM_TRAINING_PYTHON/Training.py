"""
Radar Micro-Doppler Target Classification Pipeline
Model: Coalesced Tsetlin Machine (CoTM)
Features: 1024 Doppler frequency bins from FFT magnitude
Classes (6): 0:Clutter, 1:Drone, 2:Bird, 3:Missile, 4:Helicopter, 5:Jet
Exports:
  - C_matrix.mem            : 720 signed weight bytes (6 classes x 120 clauses)
  - cotm_learned_rules.vh   : Verilog Boolean equations for all 120 clauses
  - test_vectors.mem        : Unseen test frames for Vivado simulation
  - test_labels.txt         : Expected class labels for automated testbench
"""

import numpy as np
from tmu.models.classification.coalesced_classifier import TMCoalescedClassifier

# ==============================================================================
# 1. RADAR MICRO-DOPPLER SYNTHETIC DATASET GENERATION
# ==============================================================================
print("[INFO] Generating synthetic radar micro-Doppler dataset...")
np.random.seed(42)

N_FEATURES = 1024
N_CLASSES = 6
N_CLAUSES = 120
N_SAMPLES_PER_CLASS = 200

X_list = []
y_list = []

# Base center Doppler bins for each radar target class
target_spectral_profiles = {
    0: {"peaks": [10, 15, 20],       "spread": 3,  "noise_density": 0.02}, # Ground Clutter
    1: {"peaks": [120, 128, 136],    "spread": 6,  "noise_density": 0.04}, # Micro-Drone (Rotors)
    2: {"peaks": [45, 60],           "spread": 5,  "noise_density": 0.03}, # Bird (Wing Flapping)
    3: {"peaks": [450, 480],         "spread": 4,  "noise_density": 0.02}, # Fast Missile
    4: {"peaks": [200, 220, 240, 260],"spread": 8, "noise_density": 0.05}, # Helicopter (Main + Tail)
    5: {"peaks": [350, 380, 410],    "spread": 7,  "noise_density": 0.03}  # Jet Aircraft (Turbine)
}

for class_id, profile in target_spectral_profiles.items():
    for _ in range(N_SAMPLES_PER_CLASS):
        frame = np.zeros(N_FEATURES, dtype=np.uint8)
        
        # Add primary micro-Doppler spectral signatures
        for peak in profile["peaks"]:
            jitter = np.random.randint(-profile["spread"], profile["spread"] + 1)
            idx = np.clip(peak + jitter, 0, N_FEATURES - 1)
            frame[idx] = 1
            if idx > 0 and np.random.rand() > 0.4:
                frame[idx - 1] = 1
            if idx < N_FEATURES - 1 and np.random.rand() > 0.4:
                frame[idx + 1] = 1

        # Add background thermal receiver noise
        noise_idx = np.random.choice(N_FEATURES, size=int(N_FEATURES * profile["noise_density"]), replace=False)
        frame[noise_idx] = 1

        X_list.append(frame)
        y_list.append(class_id)

X_data = np.array(X_list, dtype=np.uint8)
y_data = np.array(y_list, dtype=np.uint32)

# Shuffle & Split into 80% Train, 20% Test
indices = np.arange(len(y_data))
np.random.shuffle(indices)

split_idx = int(0.8 * len(y_data))
train_idx, test_idx = indices[:split_idx], indices[split_idx:]

X_train, y_train = X_data[train_idx], y_data[train_idx]
X_test,  y_test  = X_data[test_idx],  y_data[test_idx]

print(f"[INFO] Dataset ready: {X_train.shape[0]} training samples, {X_test.shape[0]} test samples.")

# ==============================================================================
# 2. INSTANTIATE & TRAIN COALESCED TSETLIN MACHINE (CoTM)
# ==============================================================================
print("[INFO] Initializing Coalesced Tsetlin Machine model...")
tm = TMCoalescedClassifier(
    number_of_clauses=N_CLAUSES,
    T=25,
    s=3.0,
    platform="CPU",
    weighted_clauses=True
)

print("[INFO] Training CoTM over 25 epochs...")
for epoch in range(25):
    tm.fit(X_train, y_train)
    train_acc = 100 * (tm.predict(X_train) == y_train).mean()
    test_acc  = 100 * (tm.predict(X_test) == y_test).mean()
    if (epoch + 1) % 5 == 0 or epoch == 0:
        print(f"  Epoch {epoch+1:02d}/25 | Train Acc: {train_acc:.2f}% | Test Acc: {test_acc:.2f}%")

final_acc = 100 * (tm.predict(X_test) == y_test).mean()
print(f"\n[INFO] Final CoTM Test Accuracy: {final_acc:.2f}%")

# ==============================================================================
# 3. EXPORT `C_matrix.mem` (720 Signed Weight Bytes for Vivado)
# ==============================================================================
print("[INFO] Exporting weight bank to 'C_matrix.mem'...")
with open("C_matrix.mem", "w") as f_mem:
    for c in range(N_CLASSES):
        weights = tm.get_weights(c)
        for w in weights:
            # Format as signed 8-bit hexadecimal byte
            f_mem.write(f"{int(w) & 0xFF:02X}\n")

# ==============================================================================
# 4. EXPORT `cotm_learned_rules.vh` (Synthesizable Boolean Clause Equations)
# ==============================================================================
print("[INFO] Generating Verilog rules header 'cotm_learned_rules.vh'...")
with open("cotm_learned_rules.vh", "w") as f_vh:
    f_vh.write("// =============================================================================\n")
    f_vh.write("// AUTO-GENERATED CoTM HARDWIRED BOOLEAN RULES FOR VIVADO\n")
    f_vh.write(f"// Features: {N_FEATURES} | Literals: {2*N_FEATURES} | Clauses: {N_CLAUSES}\n")
    f_vh.write("// =============================================================================\n\n")

    for j in range(N_CLAUSES):
        literals = []
        for feat in range(N_FEATURES):
            # Check positive literal inclusion (Automaton state > N)
            if tm.get_ta_action(j, feat) == 1:
                literals.append(f"i_feature_vector[{feat}]")
            # Check negated literal inclusion
            if tm.get_ta_action(j, feat + N_FEATURES) == 1:
                literals.append(f"(~i_feature_vector[{feat}])")

        if len(literals) == 0:
            rule_str = "1'b1"  # Vacuously true if unconstrained
        else:
            rule_str = " & ".join(literals)

        f_vh.write(f"assign Clause_out_comb[{j}] = {rule_str};\n")

# ==============================================================================
# 5. EXPORT TEST VECTORS AND LABELS FOR VIVADO SIMULATION
# ==============================================================================
print("[INFO] Exporting test vectors to 'test_vectors.mem' and 'test_labels.txt'...")
with open("test_vectors.mem", "w") as f_tv, open("test_labels.txt", "w") as f_lbl:
    for i in range(10):
        # Reverse bit order for standard Verilog bus indexing [1023:0]
        bin_str = "".join(str(int(b)) for b in X_test[i][::-1])
        hex_val = f"{int(bin_str, 2):0256X}"
        f_tv.write(f"{hex_val}\n")
        f_lbl.write(f"{y_test[i]}\n")

# ==============================================================================
# 6. PRINT EXACT SAMPLE 0 STRING FOR QUICK MANUAL SIMULATION
# ==============================================================================
sample0_bits = "".join(str(int(b)) for b in X_test[0][::-1])
print("\n" + "="*70)
print("             HARDWARE VERIFICATION EXPORT SUMMARY")
print("="*70)
print(f" Target Class of Sample 0 : {y_test[0]}")
print(f" Sample 0 Vector Length  : {len(sample0_bits)} bits")
print("\nPaste this line directly into `cotm_top_tb.v` if needed:")
print(f"X = 1024'b{sample0_bits};")
print("="*70 + "\n")