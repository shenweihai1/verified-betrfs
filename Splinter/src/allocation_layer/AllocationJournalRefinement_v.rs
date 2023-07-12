// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause
//
#![allow(unused_imports)]
use builtin::*;

use builtin_macros::*;
use state_machines_macros::state_machine;

use vstd::prelude::*;
use crate::coordination_layer::StampedMap_v::LSN;
use crate::coordination_layer::MsgHistory_v::*;
use crate::disk::GenericDisk_v::*;
use crate::journal::LikesJournal_v;
// use crate::journal::LikesJournal_v::LikesJournal;
use crate::journal::AllocationJournal_v;
use crate::journal::AllocationJournal_v::*;

verus!{

} // verus!
