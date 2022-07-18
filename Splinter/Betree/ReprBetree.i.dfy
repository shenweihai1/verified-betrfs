// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "LinkedBetree.i.dfy"
include "../../lib/Buckets/BoundedPivotsLib.i.dfy"
include "../Journal/GenericDisk.i.dfy"
include "Domain.i.dfy"

module ReprBetree
{
  import opened BoundedPivotsLib
  import opened Buffers
  import opened DomainMod
  import opened GenericDisk
  import opened KeyType
  import LinkedBetreeMod
//  import opened Lexicographic_Byte_Order
//   import opened LSNMod
  import opened MemtableMod
//   import opened MsgHistoryMod
//   import opened Options
  import opened Sequences
//   import opened StampedMod
//   import opened Upperbounded_Lexicographic_Byte_Order_Impl
//   import opened Upperbounded_Lexicographic_Byte_Order_Impl.Ord
//   import opened ValueMessage
//   import opened Maps
//   import TotalKMMapMod

  type Pointer = GenericDisk.Pointer
  type Address = GenericDisk.Address

  type StampedBetree = LinkedBetreeMod.StampedBetree
  type LinkedBetree = LinkedBetreeMod.LinkedBetree
  type TransitionLabel = LinkedBetreeMod.TransitionLabel
  type Step = LinkedBetreeMod.Step
  type QueryReceipt = LinkedBetreeMod.QueryReceipt

  datatype Variables = Variables(
    betree: LinkedBetreeMod.Variables,
    // maps each in-repr node n to the representation of the subtree with that node as root
    repr: set<Address>)
  {
    predicate WF() {
      betree.WF()
    }
  }

  predicate Query(v: Variables, v': Variables, lbl: TransitionLabel, receipt: QueryReceipt)
  {
    && LinkedBetreeMod.Query(v.betree, v'.betree, lbl, receipt)
    && v' == v.(
      betree := v'.betree
    )
  }

  predicate Put(v: Variables, v': Variables, lbl: TransitionLabel)
  {
    && LinkedBetreeMod.Put(v.betree, v'.betree, lbl)
    && v' == v.(
      betree := v'.betree
    )
  }

  predicate QueryEndLsn(v: Variables, v': Variables, lbl: TransitionLabel)
  {
    && LinkedBetreeMod.QueryEndLsn(v.betree, v'.betree, lbl)
    && v' == v.(
      betree := v'.betree
    )
  }

  predicate FreezeAs(v: Variables, v': Variables, lbl: TransitionLabel)
  {
    && LinkedBetreeMod.FreezeAs(v.betree, v'.betree, lbl)
    && v' == v.(
      betree := v'.betree
    )
  }

  predicate InternalGrow(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
  {
    && LinkedBetreeMod.InternalGrow(v.betree, v'.betree, lbl, step)
    && v' == v.(
      betree := v'.betree,
      repr := v.repr + {step.newRootAddr}
    )
  }

  predicate InternalSplit(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
  {
    // TODO
    false
  }

  predicate InternalFlush(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
  {
    // TODO
    false
  }

  predicate InternalCompact(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
  {
    // TODO
    false
  }

  predicate Init(v: Variables, stampedBetree: StampedBetree)
  {
    && v.betree.linked.Acyclic()
    && v == Variables(
      LinkedBetreeMod.Variables(EmptyMemtable(stampedBetree.seqEnd), stampedBetree.value),
      v.betree.linked.ReachableAddrs()
    )
  }

  predicate NextStep(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
  {
    match step {
      case QueryStep(receipt) => Query(v, v', lbl, receipt)
      case PutStep() => Put(v, v', lbl)
      case QueryEndLsnStep() => QueryEndLsn(v, v', lbl)
      case FreezeAsStep() => FreezeAs(v, v', lbl)
      case InternalGrowStep(_) => InternalGrow(v, v', lbl, step)
      case InternalSplitStep(_, _, _, _) => InternalSplit(v, v', lbl, step)
      case InternalFlushStep(_, _, _, _, _) => InternalFlush(v, v', lbl, step)
      case InternalCompactStep(_, _, _, _) => InternalCompact(v, v', lbl, step)
    }
  }

  predicate Next(v: Variables, v': Variables, lbl: TransitionLabel) {
    exists step: Step :: NextStep(v, v', lbl, step)
  }

}
