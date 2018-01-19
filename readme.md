#RVBS - RISC-V Bluespec Specification
RVBS uses the BID library to describe the RISC-V instructions and provide a readable, executable and synthesizeable specification, that could ideally be used as a golden model for fuzz testing in simulation or on FPGA.

#ideas / todos
- make a struct for each instruction that has a pattern field and a semantic function field
- update BitPat to take a list of those

#usefull references
- [Nikhil's initial RISC-V spec in Bluespec](https://github.com/rsnikhil/RISCV_ISA_Formal_Spec_in_BSV)
- [RISC-V in Sail](https://bitbucket.org/Peter_Sewell/sail/src/f0963618ba927492b0724383040b9922ab41f1dd/risc-v/?at=master)