// 2018, Alexandre Joannou, University of Cambridge

import BitPat :: *;
import BID :: *;

import RV_BasicTypes :: *;
import RV_CSRTypes :: *;
import RV_State :: *;

////////////////
// Trap logic //
////////////////////////////////////////////////////////////////////////////////

function Action general_trap(PrivLvl toLvl, MCause cause, RVState s, Action specific_behaviour) = action
  specific_behaviour;
  // TODO latch current priv in mstatus
  s.csrs.mcause <= cause;
  s.csrs.mepc <= unpack(s.pc);
  s.currentPrivLvl <= M;
  printTLogPlusArgs("itrace", $format(">>> TRAP <<< -- mcause <= ", fshow(cause), ", mepc <= 0x%0x, pc <= 0x%0x", s.pc, s.csrs.mtvec));
endaction;

typeclass Trap#(type a);
  a trap;
endtypeclass

instance Trap#(function Action f(RVState s, ExcCode code));
  function Action trap(RVState s, ExcCode code) =
    general_trap(M, Exception(code), s, action
      if (s.csrs.mtvec.mode >= 2) begin
        printTLog($format("Unknown mtvec mode 0x%0x", pack(s.csrs.mtvec.mode)));
        $finish(1);
      end else s.pc <= {s.csrs.mtvec.base, 2'b00};
    endaction);
endinstance

instance Trap#(function Action f(RVState s, ExcCode code, Action side_effect));
  function Action trap(RVState s, ExcCode code, Action side_effect) = action
    side_effect;
    trap(s, code);
  endaction;
endinstance

/*
instance Trap#(function Action f(RVState s, IntCode code));
  function Action trap(RVState s, IntCode code) =
    general_trap(M, Interrupt(code), s, action
      Bit#(XLEN) tgt = {s.csrs.mtvec.base, 2'b00};
      case (s.csrs.mtvec.mode)
        Direct: s.pc <= tgt;
        Vectored: s.pc <= tgt + zeroExtend({pack(code),2'b00});
        default: begin
          printTLog($format("Unknown mtvec mode 0x%0x", pack(s.csrs.mtvec.mode)));
          $finish(1);
        end
      endcase
    endaction);
endinstance
*/

module [InstrDefModule] mkRVTrap#(RVState s) ();
/*
  I-type

   31                                 20 19    15 14    12 11     7 6        0
  +-------------------------------------+--------+--------+--------+----------+
  |                funct12              |   rs1  | funct3 |   rd   |  opcode  |
  +-------------------------------------+--------+--------+--------+----------+
*/

  // funct12 = MRET = 001100000010
  // rs1 = 00000
  // funct3 = PRIV = 000
  // rd = 00000
  // opcode = SYSTEM = 1110011
  function Action instrMRET () = action
    // current privilege update
    s.currentPrivLvl <= s.csrs.mstatus.mpp;
    // pc update
    s.pc <= pack(s.csrs.mepc);
    // mstatus CSR manipulation
    let val = s.csrs.mstatus;
    val.mie = val.mpie;
    val.mpie = True;
    val.mpp = M; // change to U when user mode is supported
    s.csrs.mstatus <= val;
    // trace
    printTLogPlusArgs("itrace", $format("pc: 0x%0x -- mret", s.pc));
  endaction;
  defineInstr("mret", pat(n(12'b001100000010), n(5'b00000), n(3'b000), n(5'b00000), n(7'b1110011)), instrMRET);

  // funct12 = WFI = 000100000101
  // rs1 = 00000
  // funct3 = PRIV = 000
  // rd = 00000
  // opcode = SYSTEM = 1110011
  function Action instrWFI () = action
    printTLogPlusArgs("itrace", $format("pc: 0x%0x -- wfi -- IMPLEMENTED AS NOP", s.pc));
  endaction;
  defineInstr("wfi", pat(n(12'b000100000101), n(5'b00000), n(3'b000), n(5'b00000), n(7'b1110011)), instrWFI);

endmodule
