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

// static parameters
Bool static_HAS_M_MODE = True;

`ifdef SUPERVISOR_MODE
Bool static_HAS_S_MODE = True;
`else
Bool static_HAS_S_MODE = False;
`endif

`ifdef USER_MODE
Bool static_HAS_U_MODE = True;
`else
Bool static_HAS_U_MODE = False;
`endif

Bool static_HAS_I_EXT  = True;

`ifdef RVM
Bool static_HAS_M_EXT  = True;
`else
Bool static_HAS_M_EXT  = False;
`endif

`ifdef RVC
Bool static_HAS_C_EXT  = True;
`else
Bool static_HAS_C_EXT  = False;
`endif

`ifdef RVN
Bool static_HAS_N_EXT  = True;
`else
Bool static_HAS_N_EXT  = False;
`endif

///////////////////////////////////
// Utility modules and functions //
////////////////////////////////////////////////////////////////////////////////

`ifdef XLEN64
typedef 64 XLEN;
`else
typedef 32 XLEN;
`endif

//TODO for SLL instruction, use something like this:
// typedef TSub#(TLog#(XLEN), 1) BitShAmnt;

// casts between types in the same Bits class
function a cast (b x) provisos (Bits#(a,n), Bits#(b,n)) = unpack(pack(x));

// alignment test
`ifdef RVC
function Bool isInstAligned(Bit#(sz) x) provisos (Add#(1, a__, sz)) = x[0] == 0;
`else
function Bool isInstAligned(Bit#(sz) x) provisos (Add#(2, a__, sz)) = x[1:0] == 0;
`endif

// privilege levels
typedef enum {U = 2'b00, S = 2'b01, Res = 2'b10, M = 2'b11} PrivLvl deriving (Bits, Eq, FShow);
function PrivLvl toPrivLvl(Bit#(2) x) = unpack(x);
instance Ord#(PrivLvl);
  function Ordering compare(PrivLvl a, PrivLvl b);
    if (a == b) return EQ;
    else if (a == Res) return LT;
    else if (b == Res) return GT;
    else return compare(pack(a), pack(b));
  endfunction
endinstance

// effective XLEN mode
typedef enum {XLUNK = 2'b00, XL32 = 2'b01, XL64 = 2'b10, XL128 = 2'b11} XLMode deriving (Bits, Eq, FShow);
instance Literal#(XLMode);
  function fromInteger (x) = case (x)
    32: XL32;
    64: XL64;
    128: XL128;
    default: XLUNK;
  endcase;
  function inLiteralRange (x, i);
    return (i == 32 || x == 64 || x == 128);
  endfunction
endinstance
`ifdef XLEN64
XLMode nativeXLEN = XL64;
`else
XLMode nativeXLEN = XL32;
`endif

// machine interrupt/exception codes
typedef enum {
  USoftInt = 0, SSoftInt = 1, MSoftInt = 3,
  UTimerInt = 4, STimerInt = 5, MTimerInt = 7,
  UExtInt = 8, SExtInt = 9, MExtInt = 11
} IntCode deriving (Bits, Eq, FShow);
typedef enum {
  InstAddrAlign = 0, InstAccessFault = 1, IllegalInst = 2,
  Breakpoint = 3, LoadAddrAlign = 4, LoadAccessFault = 5,
  StrAMOAddrAlign = 6, StrAMOAccessFault = 7,
  ECallFromU = 8, ECallFromS = 9, ECallFromM = 11,
  InstPgFault = 12, LoadPgFault = 13, StrAMOPgFault = 15
  `ifdef RVXCHERI
  , CHERIFault = 32
  `endif
} ExcCode deriving (Bits, Eq, FShow);
typedef union tagged {
  IntCode Interrupt;
  ExcCode Exception;
} TrapCode deriving (Eq);
instance Bits#(TrapCode, XLEN);
  function Bit#(XLEN) pack (TrapCode c) = case (c) matches // n must be at least 4 + 1
    tagged Interrupt .i: {1'b1, zeroExtend(pack(i))};
    tagged Exception .e: {1'b0, zeroExtend(pack(e))};
  endcase;
  function TrapCode unpack (Bit#(XLEN) c) = (c[valueOf(XLEN)-1] == 1'b1) ?
    tagged Interrupt unpack(truncate(c)) :
    tagged Exception unpack(truncate(c));
endinstance
instance FShow#(TrapCode);
  function Fmt fshow(TrapCode cause) = case (cause) matches
    tagged Interrupt .i: $format(fshow(i) + $format(" (interrupt %0d)", pack(i)));
    tagged Exception .e: $format(fshow(e) + $format(" (exception %0d)", pack(e)));
  endcase;
endinstance
//function Bool isValidTrapCode(TrapCode c) = case (c) matches
function Bool isValidTrapCode(Bit#(XLEN) c) = case (unpack(c)) matches
  tagged Interrupt .i: case (i)
    USoftInt, SSoftInt, MSoftInt,
    UTimerInt, STimerInt, MTimerInt,
    UExtInt, SExtInt, MExtInt: True;
    default: False;
  endcase
  tagged Exception .e: case (e)
    InstAddrAlign, InstAccessFault, IllegalInst,
    Breakpoint, LoadAddrAlign, LoadAccessFault,
    StrAMOAddrAlign, StrAMOAccessFault,
    ECallFromU, ECallFromS, ECallFromM,
    InstPgFault, LoadPgFault, StrAMOPgFault
    `ifdef RVXCHERI
    , CHERIFault
    `endif
    : True;
    default: False;
  endcase
endcase;
`ifdef RVXCHERI
// RVXCHERI exception codes
typedef enum {
  CapExcNone              = 'h00, // None
  CapExcLength            = 'h01, // Length Violation
  CapExcTag               = 'h02, // Tag Violation
  CapExcSeal              = 'h03, // Seal Violation
  CapExcType              = 'h04, // Type Violation
  CapExcCall              = 'h05, // Call Trap
  CapExcRet               = 'h06, // Return Trap
  CapExcUnderflowTSS      = 'h07, // Underflow of trusted system stack
  CapExcUser              = 'h08, // User-defined Permision Violation
  CapExcTLBNoStore        = 'h09, // TLB prohibits store capability
  CapExcInexact           = 'h0a, // Requested bounds cannot be represented exactly
  CapExcGlobal            = 'h10, // Global Violation
  CapExcPermExe           = 'h11, // Permit_Execute Violation
  CapExcPermLoad          = 'h12, // Permit_Load Violation
  CapExcPermStore         = 'h13, // Permit_Store Violation
  CapExcPermLoadCap       = 'h14, // Permit_Load_Capability Violation
  CapExcPermStoreCap      = 'h15, // Permit_Store_Capability Violation
  CapExcPermStoreLocalCap = 'h16, // Permit_Store_Local_Capability Violation
  CapExcPermSeal          = 'h17, // Permit_Seal Violation
  CapExcAccessSysReg      = 'h18, // Access_System_Registers Violation
  CapExcPermCCall         = 'h19, // Premit_CCall Violation
  CapExcPermCCallIDC      = 'h1a, // Premit_CCall IDC Violation
  CapExcPermUnseal        = 'h1c  // Premit_Unseal Violation
} CapExcCode deriving (Bits, Eq, FShow);
function Fmt showCapCause(CapExcCode cause) = $format(fshow(cause)," (%0d)", pack(cause));
`endif
typedef struct {
  ExcCode excCode;
  Bit#(XLEN) tval;
  `ifdef RVXCHERI
  CapExcCode capExcCode;
  Bit#(6) capIdx;
  `endif
} ExcToken deriving (Bits, Eq, FShow);
function ExcToken craftExcToken(ExcCode code, Bit#(XLEN) val) = ExcToken {
    excCode: code
  , tval: val
  `ifdef RVXCHERI
  , capExcCode: ?
  , capIdx: ?
  `endif
};
`ifdef RVXCHERI
function ExcToken craftCapExcToken(CapExcCode code, Bit#(6) idx, Bit#(XLEN) val) = ExcToken {
  excCode: CHERIFault,
  tval: val,
  capExcCode: code,
  capIdx: idx
};
`endif
