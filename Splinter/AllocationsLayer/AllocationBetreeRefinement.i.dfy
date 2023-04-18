// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "AllocationBetree.i.dfy"

// a conditional refinement where it only refines if newly allocated AUs are fresh
module AllocationBetreeRefinement {
  import opened AllocationBetreeMod
  import LikesBetreeMod

  function I(v: Variables) : LikesBetreeMod.Variables
  {
    v.likesVars
  }

  predicate Inv(v: Variables)
  {
    // placeholder
    && true
  }

  predicate IsFresh(v: Variables, aus: set<AU>)
  {
    && M.Set(v.betreeAULikes) !! aus
    // && M.Set(branchAULikes) !! aus
    && v.compactor.AUs() !! aus
    && G.ToAUs(v.allocBranchDiskView.Representation()) !! aus 
  }

  lemma InvNext(v: Variables, v': Variables, lbl: TransitionLabel)
    requires Inv(v)
    requires Next(v, v', lbl)
    ensures Inv(v')
  {
  }

  lemma NextRefines(v: Variables, v': Variables, lbl: TransitionLabel)
    requires Inv(v)
    requires Next(v, v', lbl)
    requires lbl.InternalAllocationsLabel? ==> IsFresh(v, lbl.allocs)
    ensures Inv(v')
    ensures LikesBetreeMod.Next(I(v), I(v'), lbl.I())
  {
    InvNext(v, v', lbl);
    assume false;
  }
}