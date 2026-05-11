# Parameterized 8-Bit Pipelined ALU with Golden Model Verification

A robust, synthesizable, and fully parameterized Arithmetic Logic Unit (ALU) designed in Verilog. This project features a dual-mode datapath (Arithmetic and Logical), a multi-cycle execution pipeline, and a highly rigorous verification environment utilizing a Golden Reference Model that achieved **>96% Statement and Branch Coverage**.

## 🚀 Key Architectural Features
* **Parameterized Datapath:** Built with `WIDTH=8` and `CMD_WIDTH=4` by default, but seamlessly scalable to 16, 32, or 64 bits.
* **16-Bit Result Bus:** Prevents data loss during large addition or multiplication operations natively.
* **Multi-Cycle Pipeline:**
  * **2-Cycle Standard Latency:** Stage-1 registers sample inputs to prevent combinational race conditions; Stage-2 executes logic and math.
  * **3-Cycle Multiplier Latency:** Parallel pipeline for complex multiplication commands (Increment-and-Multiply, Shift-and-Multiply).
* **Strict State Retention:** Implements a 2-bit Handshake protocol (`INP_VALID`). Invalid handshakes or unregistered opcodes immediately halt the pipeline, flag an `ERR`, and trigger a strict `RES <= RES` feedback loop to prevent memory corruption.
* **Hardware Sign-Extension:** Bypasses Verilog's native `$signed()` LHS context limitations by utilizing manual sign-bit concatenation for mathematically perfect signed addition and subtraction.

## 🧮 Supported Operations

The ALU supports 27 distinct operations controlled by a `MODE` bit.

### Arithmetic Mode (`MODE = 1`)
| CMD | Operation | Latency | Description |
| :---: | :--- | :---: | :--- |
| `0000` | ADD | 2 Cycles | Standard unsigned addition |
| `0001` | SUB | 2 Cycles | Standard unsigned subtraction |
| `0010` | ADD_CIN | 2 Cycles | Addition with Carry-In |
| `0011` | SUB_CIN | 2 Cycles | Subtraction with Borrow |
| `1000` | COMP | 2 Cycles | Hardware Comparator (Generates `G`, `L`, `E` flags) |
| `1001` | INC_MUL | 3 Cycles | Increment both operands and multiply |
| `1010` | SHL_MUL | 3 Cycles | Left shift OPA by 1 and multiply with OPB |
| `1011` | SIG_ADD | 2 Cycles | Signed Addition (Manual Sign-Extension) |
| `1100` | SIG_SUB | 2 Cycles | Signed Subtraction (Manual Sign-Extension) |
*(Also supports Increment/Decrement commands for both OPA and OPB).*

### Logical Mode (`MODE = 0`)
| CMD | Operation | Latency | Description |
| :---: | :--- | :---: | :--- |
| `0000`-`0101` | Bitwise | 2 Cycles | AND, NAND, OR, NOR, XOR, XNOR |
| `0110`-`0111` | Inversion | 2 Cycles | NOT A, NOT B |
| `1000`-`1011` | Shifting | 2 Cycles | Logical Right/Left shifts for OPA and OPB |
| `1100`-`1101` | Rotation | 2 Cycles | ROL and ROR (Includes out-of-bounds >7 shift protections) |

## 🛡️ Verification Environment
The testbench (`alu_tb.v`) is designed to industry sign-off standards, testing the physical DUT against a zero-time behavioral Golden Model (`alu_ref.v`).

* **Dynamic Driver:** The `apply_test` task automatically synchronizes wait states based on the opcode (2-cycle vs. 3-cycle).
* **State Sync Tracking:** The testbench maintains a `last_valid_res` memory tracker to prove the hardware successfully freezes its state during an invalid handshake without wiping the registers to zero.
* **Interrupt Testing:** Explicit verification of Asynchronous Reset (`RST`) and Synchronous Clock Enable (`CE`) disabling mid-pipeline computation.

### Coverage Metrics (Questa SIM)
The verification suite utilizes directed corner-cases and bounded attacks, achieving exceptionally high coverage across the design instance:
* **Statement Coverage:** 97.99%
* **Branch Coverage:** 97.38%
* **FEC Expression Coverage:** 100.00%
* **Toggle Coverage:** 98.21%
* **FSM State Coverage:** 100.00% *(Multiplier Pipeline)*

## 🛠️ Tools & Simulation
* **Languages:** Verilog (IEEE 1364-2001)
* **Simulators:** Questa SIM, Xilinx Vivado

### How to Run (Vivado / Questa)
1. Add `alu.v` (Design), `alu_ref.v` (Golden Model), and `alu_tb.v` (Testbench) to your simulation sources.
2. Set `alu_tb.v` as the top-level simulation module.
3. **Important for Vivado:** Because the testbench runs over 200+ mathematical edge cases across pipelined latency, the default simulation time of `1000ns` is not long enough. Run the simulation and click the **Run All** button, or type `run -all` in the Tcl console to see the final Pass/Fail summary.

## 📂 File Structure
```text
├── src/
│   ├── alu.v         # Main RTL Design (DUT)
│   └── alu_ref.v     # Golden Reference Model
├── sim/
│   └── alu_tb.v      # Self-Checking Verification Environment
└── README.md

