// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "Disk/GenericDisk.i.dfy"

module LikesMod
{
  import GenericDisk
  
  type Likes = multiset<GenericDisk.Address>
}
