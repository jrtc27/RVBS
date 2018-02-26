// 2018, Alexandre Joannou, University of Cambridge

import Vector :: *;
import FIFO :: *;
import SpecialFIFOs :: *;
import DefaultValue :: *;
import BID :: *;

import RV_BasicTypes :: *;

typedef enum {
  OFF = 2'b00, TOR = 2'b01, NA4 = 2'b10, NAPOT = 2'b11
} AddrMatchMode deriving (Bits, Eq, FShow);

typedef struct {
  Bool l;
  Bit#(2) wiri;
  AddrMatchMode a;
  Bool x;
  Bool w;
  Bool r;
} PMPCfg deriving (Bits, FShow);
instance DefaultValue#(PMPCfg);
  function defaultValue = PMPCfg {
    l: False, wiri: 2'b00, a: OFF, x: True, w: True, r: True
  };
endinstance
typedef Vector#(n, PMPCfg) PMPCfgIfc#(numeric type n);
instance CSR#(PMPCfgIfc#(n));
  function Action updateCSR(Reg#(PMPCfgIfc#(n)) csr, PMPCfgIfc#(n) val) = action
    csr <= val;
  endaction;
endinstance
module mkPMPCfgIfcReg (Reg#(PMPCfgIfc#(n)));
  Vector#(n, Reg#(PMPCfg)) cfgs <- replicateM(mkReg(defaultValue));
  method Action _write(PMPCfgIfc#(n) vals) = action
    function Action doWrite(Reg#(PMPCfg) r, PMPCfg v) = action
      if (!r.l) r <= v;
    endaction;
    joinActions(zipWith(doWrite, cfgs, vals));
  endaction;
  method PMPCfgIfc#(n) _read() = readVReg(cfgs);
endmodule

typedef TSub#(PAddrSz, 2) SmallPASz;
typedef struct {
  `ifdef XLEN64
  Bit#(10) wiri;
  `endif
  Bit#(SmallPASz) address;
} PMPAddr deriving (Bits, FShow);
instance DefaultValue#(PMPAddr);
  function defaultValue = PMPAddr {
    `ifdef XLEN64
    wiri: 0,
    `endif
    address: 0
  };
endinstance
instance CSR#(PMPAddr);
  function Action updateCSR(Reg#(PMPAddr) csr, PMPAddr val) = action
    csr.address <= val.address;
  endaction;
endinstance

typedef enum {READ, WRITE, IFETCH} PMPReqType deriving (Eq, FShow);
typedef struct
{
  PAddr addr;
  BitPO#(TLog#(XLEN)) numBytes;
  PMPReqType reqType;
} PMPReq deriving (FShow);
typedef struct {
  Bool matched;
  Bool authorized;
  PAddr addr;
} PMPRsp deriving (Bits, FShow);
instance DefaultValue#(PMPRsp);
  function defaultValue = PMPRsp {matched: False, authorized: False, addr: 0};
endinstance

typedef struct {
  `ifdef XLEN64
  Vector#(2, Reg#(PMPCfgIfc#(8))) cfg;
  `else
  Vector#(4, Reg#(PMPCfgIfc#(4))) cfg;
  `endif
  Vector#(16, Reg#(PMPAddr)) addr;
  function Action doLookup (PMPReq req) lookup;
  function ActionValue#(PMPRsp) getLookup () getMatch;
} PMP;

module mkPMP#(PrivLvl plvl) (PMP);

  PMP pmp;
  FIFO#(PMPRsp) rsp <- mkBypassFIFO;
  // mapped CSRs
  pmp.cfg <- replicateM(mkPMPCfgIfcReg);
  pmp.addr <- replicateM(mkReg(defaultValue));
  // lookup method
  function Action lookup (PMPReq req) = action
    // inner helper for zipwith
    function PMPRsp doLookup (PMPCfg cfg1, Bit#(SmallPASz) a1, Bit#(SmallPASz) a0);
      // authorisation after match
      Bool auth = (!cfg1.l && plvl == M) ? True :
        (case (req.reqType)
          READ: return cfg1.r;
          WRITE: return cfg1.w;
          IFETCH: return cfg1.x;
          default: return False;
        endcase);
      // prepare match entry
      PMPRsp matchRsp = PMPRsp {matched: True, authorized: auth, addr: req.addr};
      // matching
      PAddr mask = ((~0) << 3) << countZerosLSB(~a0); // 3 because bottom 2 bits + 1 terminating 0
      PAddr baseAddr = req.addr;
      PAddr topAddr = req.addr + zeroExtend(readBitPO(req.numBytes));
      case (cfg1.a)
        // Top Of Range mode
        TOR: return ({a0,2'b00} <= baseAddr && topAddr <= {a1,2'b00}) ? matchRsp : defaultValue;
        // Naturally Aligned Power Of Two region (4-bytes region)
        NA4: return (a0 == truncateLSB(baseAddr) && a0 == truncateLSB(topAddr)) ? matchRsp : defaultValue;
        // Naturally Aligned Power Of Two region (>= 8-bytes region)
        NAPOT: return (({a0,2'b00} & mask) == (baseAddr & mask) && ({a0,2'b00} & mask) == (topAddr & mask)) ? matchRsp : defaultValue;
        default: return defaultValue; // OFF
      endcase
    endfunction
    // return first match or default response
    function isMatch(x) = x.matched;
    function Bit#(SmallPASz) getAddr(Reg#(PMPAddr) x) = x.address;
    Vector#(16, Bit#(SmallPASz)) addrs = map(getAddr, pmp.addr);
    PMPRsp noMatchRsp = PMPRsp {matched: False, authorized: (plvl == M), addr: req.addr};
    rsp.enq(fromMaybe(
      noMatchRsp,
      find(isMatch, zipWith3(doLookup, concat(readVReg(pmp.cfg)), addrs, shiftInAt0(addrs,0)))
    ));
  endaction;
  pmp.lookup = lookup;
  pmp.getMatch = actionvalue rsp.deq(); return rsp.first(); endactionvalue;
  // returning PMP interface
  return pmp;

endmodule
