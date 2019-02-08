/*-
 * Copyright (c) 2018-2019 Alexandre Joannou
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

import FIFOF :: *;

import BID :: *;
import BlueBasics :: *;
import BlueUtils :: *;
import BitPat :: *;
import Recipe :: *;
import RVBS_Trap :: *;
import RVBS_Types :: *;
import RVBS_MemAccess :: *;

`ifdef RVFI_DII
import RVFI_DII_Bridge :: *;
import FIFO :: *;
import ClientServer :: *;
import GetPut :: *;
`endif

module [ISADefModule] mkRVCommon#(RVState s) (Empty);

  // Memory commons
  `ifdef RVXCHERI
  match {.rHandle, .rDest, .rNumBytes, .rSgnExt, .rCapAccess} = s.readMem.first;
  match {.rCapIdx, .rCap, .rVaddr} = unpackHandle(s.ddc, s.pcc, rHandle);
  match {.wHandle, .wNumBytes, .wData, .wCapAccess} = s.writeMem.first;
  match {.wCapIdx, .wCap, .wVaddr} = unpackHandle(s.ddc, s.pcc, wHandle);
  `else
  match {.rVaddr, .rDest, .rNumBytes, .rSgnExt} = s.readMem.first;
  match {.wVaddr, .wNumBytes, .wData} = s.writeMem.first;
  `endif
  // call back for read responses
  function Action readCallBack(RVMemRsp rsp) = action
    case (rsp) matches
      tagged RVReadRsp .r: begin
        `ifdef RVXCHERI
        match {.captag, .data} = r;
        RawCap newCap = unpack(truncate(data));
        `else
        let data = r;
        `endif
        let topIdx = {readBitPO(rNumBytes), 3'b000};
        Bool isNeg = unpack(data[topIdx-1]);
        Bit#(XLEN) mask = (~0) << topIdx;
        `ifdef RVXCHERI
        let newData = Data(pack(newCap));
        if (captag == 1) newData = Cap(newCap);
        if (rCapAccess) s.wCR(rDest, newData);
        else
        `endif
        s.wGPR(rDest, (rSgnExt && isNeg) ? truncate(data) | mask : truncate(data) & ~mask);
      end
      tagged RVBusError: action raiseMemException(s, LoadAccessFault); endaction
    endcase
  endaction;
  // handle mem requests on epilogue
  defineEpiEntry(rOneMatch(list(s.readMem.notEmpty, s.writeMem.notEmpty),
                           list(
                             // handle reads
                             rFastSeq(rBlock(
                               `ifdef RVXCHERI
                               capChecks(READ, rCapIdx, rCap, rVaddr, rNumBytes, rCapAccess, s,
                               `endif
                               doReadMem(readCallBack, s, rVaddr, rNumBytes)
                               `ifdef RVXCHERI
                               )
                               `endif
                               , s.readMem.deq
                             )),
                             // handle writes
                             rFastSeq(rBlock(
                               `ifdef RVXCHERI
                               doWriteMem(s, wHandle, wNumBytes, wData, wCapAccess),
                               `else
                               doWriteMem(s, wVaddr, wNumBytes, wData),
                               `endif
                               s.writeMem.deq
                             ))
                           ),
                           rAct(noAction)));

endmodule

// Instruction fetch
////////////////////////////////////////////////////////////////////////////////
module [ISADefModule] mkRVIFetch#(RVState s) ();
  function Recipe instFetch(RVState s, Sink#(Bit#(InstWidth)) snk);
    // call back for ifetch responses
    function Action ifetchCallBack(RVMemRsp rsp) = action
      case (rsp) matches
        tagged RVReadRsp .val: begin
          `ifdef RVXCHERI
          match {.captag, .data} = val;
          `else
          let data = val;
          `endif
          let newInstSz = (data[1:0] == 2'b11) ? 4 : 2;
          asIfc(s.pc.early) <= s.pc + newInstSz;
          s.instByteSz <= newInstSz;
          snk.put(truncate(data));
        end
        default: begin
          snk.put(?);
          raiseIFetchException(s, InstAccessFault);
        end
      endcase
    endaction;
    return
      `ifdef RVXCHERI
      //XXX capChecks(IFETCH, 6'b100000, s.pcc, s.pc, 4, False, s,
      `endif
      doIFetchMem(ifetchCallBack, s, s.pc.late, 4)
      `ifdef RVXCHERI
      //XXX )
      `endif
    ;
  endfunction
  // instruction fetching definition
  defineFetchInstEntry(instFetch(s));
endmodule

`ifdef RVFI_DII
// RVFI-DII Instruction fetch
////////////////////////////////////////////////////////////////////////////////
module [ISADefModule] mkRVIFetch_RVFI_DII#(RVState s) ();
  function Recipe instFetch(RVState s, Sink#(Bit#(InstWidth)) snk) =
  rPipe(rBlock(action
      let inst <- s.rvfi_dii_bridge.client.getInst(0);
      s.iFF.enq(inst);
    endaction, action
      asIfc(s.pc.early) <= s.pc + 4;
      s.instByteSz <= 4;
      snk.put(s.iFF.first);
    endaction
  ));
  // instruction fetching definition
  defineFetchInstEntry(instFetch(s));
endmodule
`endif
