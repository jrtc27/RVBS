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

package RVBS;

import RVBS_Types :: *;
import RVBS_State :: *;
import RVBS_Trap :: *;
import RVBS_RVCommon :: *;
import RVBS_MemAccess :: *;

export RVBS_Types :: *;
export RVBS_State :: *;
export RVBS_Trap :: *;
export RVBS_RVCommon :: *;
export RVBS_MemAccess :: *;

import RVBS_Base_RV32I :: *;
export RVBS_Base_RV32I :: *;
`ifdef RVZICSR
import RVBS_Ext_Zicsr :: *;
export RVBS_Ext_Zicsr :: *;
`endif
`ifdef RVZIFENCEI
import RVBS_Ext_Zifencei :: *;
export RVBS_Ext_Zifencei :: *;
`endif
`ifdef RVM
import RVBS_Ext_32_M :: *;
export RVBS_Ext_32_M :: *;
`endif
`ifdef RVC
import RVBS_Ext_32_C :: *;
export RVBS_Ext_32_C :: *;
`endif
`ifdef RVXCHERI
import RVBS_Ext_Xcheri :: *;
export RVBS_Ext_Xcheri :: *;
`endif

`ifdef XLEN64
import RVBS_Base_RV64I :: *;
export RVBS_Base_RV64I :: *;
`ifdef RVM
import RVBS_Ext_64_M :: *;
export RVBS_Ext_64_M :: *;
`endif
`ifdef RVC
import RVBS_Ext_64_C :: *;
export RVBS_Ext_64_C :: *;
`endif
`endif

endpackage
