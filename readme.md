# RVBS - RISC-V Bluespec SystemVerilog Specification

**RVBS** (pronounced *"rubs"*) is an ISA level description of the RISC-V instruction set in [Bluespec SystemVerilog](http://wiki.bluespec.com/bluespec-systemverilog-and-compiler). It uses the [BID library](https://github.com/CTSRD-CHERI/BID) to describe the instructions, providing a readable, executable and synthesizeable specification, with an AXI interface, that could be used as a golden model.

**RVBS** is **not** a heavily pipelined, superscalar or optimised RISC-V core. It is however capable to boot small embedded operating systems.

RVBS currently supports:

- 32-bit and 64-bit RISC-V **I** base integer instructions
- RISC-V **M** integer multiply/divide instructions
- RISC-V **C** compressed instructions
- RISC-V **Zicsr** control and status registers manipulation instructions
- **Machine/Supervisor/User** privilege modes
- **Sv32** virtual memory translation mechanism **without Sv32 memory protection features**
- **PMP** physical memory protection mechanism
- *RISC-V **Zifencei** the fence.i instruction, currently a nop*

RVBS supports traps between privilege modes, but **Supervisor mode** is not fully implemented.

## Building RVBS

In order to build a RVBS Bluesim simulator, you will need a valid installation of [Bluespec SystemVerilog](http://wiki.bluespec.com/bluespec-systemverilog-and-compiler) on your machine. RVBS relies on the following three Bluespec libraries:

- [Recipe](https://github.com/CTSRD-CHERI/Recipe)
- [BitPat](https://github.com/CTSRD-CHERI/BitPat)
- [BlueStuff](https://github.com/CTSRD-CHERI/BlueStuff)
- [BID](https://github.com/CTSRD-CHERI/BID)

[BID](https://github.com/CTSRD-CHERI/BID) is a submodule of the [RVBS](https://github.com/CTSRD-CHERI/RVBS.git) repository. [Recipe](https://github.com/CTSRD-CHERI/Recipe), [BitPat](https://github.com/CTSRD-CHERI/BitPat) and [BlueStuff](https://github.com/CTSRD-CHERI/BlueStuff) are themselves submodules of the [BID](https://github.com/CTSRD-CHERI/BID) repository. In order to checkout all of them, you need to run:
```sh
$ git submodule update --init --recursive
```

Once the libraries are available, you can build RVBS and specify a number of build options as environment variables. The `XLEN` environment variable must be set to one of `32` or `64` to specify the XLEN to build with. The following optional environment variables are available:

- `USER_MODE` can be set to enable *User mode* support
- `SUPERVISOR_MODE` can be set to enable *Supervisor mode* support (implies *User mode*)
- `PMP` can be set to enable the Physical Memory Protection unit
- `RVM` can be set to enable the *M* integer multiply/divide instructions extention
- `RVC` can be set to enable the *C* compressed instructions extention
- `RVZICSR` can be set to enable the *Zicsr* control and status registers manipulation instructions extention
- `RVZIFENCEI` can be set to enable the *Zifencei* fence.i instruction extention
- `NO_LOGS` can be set to skip print statements (accelerates simulation)
- `PRINT_ABI_REG_NAME` can be set to use ABI names for registers instead of their index

### Bluesim

Several Bluesim build targets are available:

- `isa-test` to get a simulator that can be used for running the ISA tests from [riscv-tests](https://github.com/riscv/riscv-tests)
- `rfvi-dii` to get a rvfi-dii server to be used with a [TestRIG](https://github.com/CTSRD-CHERI/TestRIG) configuration
- `sim` to get the default simulator. It can be further configured using:
  * `MEM_SIZE` can be used to specify the size of the memory in bytes
  * `MEM_IMG` can be used to specify the memory image used to initialize the memory
  * `MEM_DELAY` can be set to enable artificial memory delay

The generated simulator is found under the `output/` folder, and when run, will execute the program found in `test-prog.hex`.

#### Examples

- To build a 64-bit bluesim simulator with support for multiply/divide instructions and 32KB of memory, you can run:

```sh
$ make RVM=1 XLEN=64 MEM_SIZE=32768 sim
```

- To build a 32-bit bluesim simulator with support for compressed instructions and as an rvfi-dii server, you can run:

```sh
$ make RVC=1 rvfi-dii
```

- To build a 32-bit bluesim simulator capable of running the ISA tests, you can run:

```sh
$ make isa-test
```

#### Run time flags

The `+itrace` flag can be specified on the command line when running the simulator to get an instruction trace in `stdout` as follows:

```sh
$ output/rvbs-rv64IM +itrace
```

### Verilog

To build a 32-bit verilog module with support for compressed instructions, you can run:
```sh
$ make RVC=1 XLEN=32 verilog
```
The generated verilog can be found in the `output/rvbs-rv32IC-vdir/` folder. Specifically, the `rvbs` verilog module with an AXI4Lite interface can be found in `output/rvbs-rv32IC-vdir/rvbs.v`.

### TODOs, upcoming features and experimentations...

- sv39/sv48 memory virtualisation
- N extention for User mode interrupt and exception support
- CHERI extension

## References

- [l3riscv](https://github.com/SRI-CSL/l3riscv)
- [sail-riscv](https://github.com/rems-project/sail-riscv)
- [Nikhil's initial RISC-V spec in Bluespec](https://github.com/rsnikhil/RISCV_ISA_Formal_Spec_in_BSV)
