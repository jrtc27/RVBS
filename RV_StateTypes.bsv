/*-
 * Copyright (c) 2018 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */

import Vector :: *;

import BID :: *;
import Recipe :: *;
import RV_Traces :: *;
import RV_BasicTypes :: *;
import RV_CSRTypes :: *;
`ifdef PMP
import RV_PMPTypes :: *;
`endif
`ifdef SUPERVISOR_MODE
import RV_VMTranslateTypes :: *;
`endif

////////////////////////////////
// RISC-V architectural state //
////////////////////////////////////////////////////////////////////////////////

// state type
typedef struct {
  Reg#(PrivLvl) currentPrivLvl;
  XLMode currentXLEN;

  PC#(VAddr) pc;
  Reg#(VAddr) instByteSz;
  Vector#(32,Reg#(Bit#(XLEN))) regFile;
  CSRs csrs;
  `ifdef PMP
  PMP pmp;
  `endif
  `ifdef SUPERVISOR_MODE
  VMTranslate vmTranslate;
  `endif
  RecipeFSM fetchInst;
  Mem#(PAddr, Bit#(InstSz)) imem;
  Mem#(PAddr, Bit#(XLEN)) dmem;
} RVState;

// State instance
instance State#(RVState);

  function Fmt lightReport (RVState s) = fullReport(s);
  function Fmt fullReport (RVState s);
    Fmt str = $format("regfile\n");
    for (Integer i = 0; i < 6; i = i + 1) begin
      for (Integer j = 0; j < 5; j = j + 1) begin
        Bit#(5) ridx = fromInteger(i*5+j);
        str = str + $format(rName(ridx),": 0x%8x\t", s.regFile[ridx]);
      end
      str = str + $format("\n");
    end
    str = str + $format(rName(5'd30),": 0x%8x\t", s.regFile[30]);
    str = str + $format(rName(5'd31),": 0x%8x", s.regFile[31]);
    str = str + $format("\npc = 0x%8x", s.pc);
    str = str + $format(" - privilege mode = ", fshow(s.currentPrivLvl));
    return str;
  endfunction
  function Action reqNextInst(RVState s) = s.fetchInst.start();
  function ActionValue#(Bit#(MaxInstSz)) getNextInst(RVState s) = actionvalue
    let rsp <- s.imem.getRsp();
    case (rsp) matches
      tagged ReadRsp .val: begin
        s.instByteSz <= (val[1:0] == 2'b11) ? 4 : 2;
        return val;
      end
      default: return ?;
    endcase
  endactionvalue;

endinstance