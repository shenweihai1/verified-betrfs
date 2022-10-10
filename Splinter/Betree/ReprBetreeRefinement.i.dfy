// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

include "LinkedBetree.i.dfy"
include "LinkedBetreeRefinement.i.dfy"
include "ReprBetree.i.dfy"
include "../Disk/GenericDisk.i.dfy"
include "../../lib/Buckets/BoundedPivotsLib.i.dfy"
include "../../lib/Base/Sets.i.dfy"
include "../../lib/Base/Sequences.i.dfy"

module ReprBetreeRefinement
{
  import opened ReprBetree
  import opened Buffers
  import opened BoundedPivotsLib
  import opened SplitRequestMod
  import LB = LinkedBetreeMod
  import LBR = LinkedBetreeRefinement
  import GenericDisk
  import Sets
  import opened Sequences

  type Ranking = GenericDisk.Ranking

  function I(v: Variables) : (out: LB.Variables) {
    v.betree
  }

  // The representation of v.betree == v.repr
  predicate ValidRepr(v: Variables) 
    requires v.betree.linked.Acyclic()
  {
    v.repr == v.betree.linked.Representation()
  }

  predicate Inv(v: Variables) {
    // Note: ValidRepr and DiskIsTightWrtRepresentation together 
    // gives us diskView.entries.Keys == v.repr
    && v.WF()
    && LBR.Inv(v.betree)
    && ValidRepr(v)                                    // v.repr == Representation
    && v.betree.linked.DiskIsTightWrtRepresentation()  // diskView == Representation
    && v.betree.linked.diskView.DiskHasNoDags()
  }

  //******** PROVE INVARIANTS ********//

  predicate PathAddrsFresh(path: Path, replacement: LinkedBetree, pathAddrs: PathAddrs)
  {
    && SeqHasUniqueElems(pathAddrs)
    && path.linked.diskView.IsFresh(Set(pathAddrs))
    && replacement.diskView.IsFresh(Set(pathAddrs))
  }

  lemma InvInit(v: Variables, gcBetree: GCStampedBetree) 
    requires Init(v, gcBetree)
    requires LBR.InvLinkedBetree(gcBetree.I().value)
    ensures Inv(v)
  {
    LBR.InitRefines(I(v), gcBetree.I());
  }

  // Theorem: If t1.root = t2.root and their disks agree, then t1 and t2 have the same Representation
  lemma ReachableAddrsInAgreeingDisks(t1: LinkedBetree, t2: LinkedBetree, ranking: Ranking) 
    requires t1.WF()
    requires t2.WF()
    requires t1.ValidRanking(ranking)
    requires t2.ValidRanking(ranking)
    requires t1.diskView.AgreesWithDisk(t2.diskView)
    requires t1.root == t2.root
    ensures t1.ReachableAddrsUsingRanking(ranking) == t2.ReachableAddrsUsingRanking(ranking)
    decreases t1.GetRank(ranking)
  {
    if t1.HasRoot() {
      var numChildren := |t1.Root().children|;
      forall i | 0 <= i < numChildren 
      ensures t1.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking) == t2.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking)
      {
        LBR.ChildAtIdxAcyclic(t1, i);
        LBR.ChildAtIdxAcyclic(t2, i);
        ReachableAddrsInAgreeingDisks(t1.ChildAtIdx(i), t2.ChildAtIdx(i), ranking);
      }
      var t1SubAddrs := seq(numChildren, i requires 0 <= i < numChildren => t1.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
      var t2SubAddrs := seq(numChildren, i requires 0 <= i < numChildren => t2.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
      assert t1SubAddrs == t2SubAddrs;  // trigger
    }
  }

    // Theorem: Wrapper around ReachableAddrsInAgreeingDisks
  lemma RepresentationInAgreeingDisks(t1: LinkedBetree, t2: LinkedBetree, ranking: Ranking) 
    requires t1.WF()
    requires t2.WF()
    requires t1.ValidRanking(ranking)
    requires t2.ValidRanking(ranking)
    requires t1.diskView.AgreesWithDisk(t2.diskView)
    requires t1.root == t2.root
    ensures t1.Representation() == t2.Representation()
  {
    ReachableAddrsInAgreeingDisks(t1, t2, ranking);
    RepresentationSameAsReachable(t1, ranking);
    RepresentationSameAsReachable(t2, ranking);
  }

  lemma InternalGrowMaintainsRepr(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalGrowStep?
    requires v'.betree.linked.Acyclic()
    ensures ValidRepr(v')
  {
    var linked := v.betree.linked;
    var linked' := v'.betree.linked;
    var oldRanking := LBR.BuildTightRanking(linked, linked.TheRanking());
    var newRanking := LBR.InsertGrowReplacementNewRanking(linked, oldRanking, step.newRootAddr);
    if v.betree.linked.HasRoot() {
      RepresentationSameAsReachable(linked, oldRanking);
      LBR.ReachableAddrsIgnoresRanking(linked, oldRanking, newRanking);
      var numChildren := |linked'.Root().children|;
      var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked'.ChildAtIdx(i).ReachableAddrsUsingRanking(newRanking));
      Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
      ReachableAddrsInAgreeingDisks(linked, linked'.ChildAtIdx(0), newRanking);
      RepresentationSameAsReachable(linked', newRanking);
    }
  }

  // Theorem: All reachable addresses must have a lower smaller ranking than the root
  lemma ReachableAddressesHaveLowerRank(linked: LinkedBetree, topAddr: Address, topRank: nat, ranking: Ranking) 
    requires linked.WF()
    requires linked.ValidRanking(ranking)
    requires LBR.RankingIsTight(linked.diskView, ranking)
    requires topAddr in linked.diskView.entries
    requires topAddr in ranking
    requires ranking[topAddr] == topRank
    requires linked.HasRoot()
    requires ranking[linked.root.value] < topRank;
    ensures forall addr | addr in linked.ReachableAddrsUsingRanking(ranking)
      :: addr in ranking && ranking[addr] < topRank
    decreases linked.GetRank(ranking)
  {
    var numChildren := |linked.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    forall i | 0 <= i < numChildren 
    ensures forall addr | addr in linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking)
      :: addr in ranking && ranking[addr] < topRank
    {
      if linked.ChildAtIdx(i).HasRoot() {
        ReachableAddressesHaveLowerRank(linked.ChildAtIdx(i), topAddr, topRank, ranking);
      }
    }
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
  }

  // Theorem: A wrapper around ReachableAddressesHaveLowerRank
  lemma ChildrenRepresentationHaveLowerRank(linked: LinkedBetree, idx: nat, ranking: Ranking) 
    requires linked.Acyclic()
    requires linked.ValidRanking(ranking)
    requires LBR.RankingIsTight(linked.diskView, ranking)
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    ensures linked.ChildAtIdx(idx).Acyclic()  // prereq
    ensures forall addr | addr in linked.ChildAtIdx(idx).Representation()
      :: addr in ranking && ranking[addr] < ranking[linked.root.value]
  {
    LBR.ChildAtIdxAcyclic(linked, idx);
    var subRoot := linked.ChildAtIdx(idx);
    forall addr | addr in subRoot.Representation()
    ensures addr in ranking && ranking[addr] < ranking[linked.root.value]
    {
      var r1 := subRoot.TheRanking();
      LBR.ReachableAddrsIgnoresRanking(subRoot, r1, ranking);
      if addr != subRoot.root.value {
        var numChildren := |subRoot.Root().children|;
        var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => subRoot.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
        Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
        var i :| 0 <= i < numChildren && addr in subTreeAddrs[i];
        var topAddr := linked.root.value;
        ReachableAddressesHaveLowerRank(subRoot, topAddr, ranking[topAddr], ranking);
      }
    }
  }

  lemma InternalFlushMemtableDeletesOldRoot(linked: LinkedBetree, linked':LinkedBetree, newBuffer: Buffer, newRootAddr:Address)
    requires linked.Acyclic()
    requires linked'.Acyclic()
    requires linked.HasRoot()
    requires linked.diskView.IsFresh({newRootAddr})
    requires linked' == LB.InsertInternalFlushMemtableReplacement(linked, newBuffer, newRootAddr).BuildTightTree()
    ensures linked.root.value !in linked'.diskView.entries
  {
    var oldRootAddr := linked.root.value;
    var oldRanking := LBR.BuildTightRanking(linked, linked.TheRanking());
    var newRanking := oldRanking[newRootAddr := oldRanking[linked.root.value]];
    var untightLinked := LB.InsertInternalFlushMemtableReplacement(linked, newBuffer, newRootAddr);
    var numChildren := |untightLinked.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => untightLinked.ChildAtIdx(i).ReachableAddrsUsingRanking(newRanking));
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
    forall i | 0 <= i < numChildren 
    ensures oldRootAddr !in subTreeAddrs[i]
    {
      if untightLinked.ChildAtIdx(i).HasRoot() {
        if oldRootAddr in untightLinked.ChildAtIdx(i).ReachableAddrsUsingRanking(newRanking) {
          ReachableAddressesHaveLowerRank(untightLinked.ChildAtIdx(i), oldRootAddr, newRanking[oldRootAddr], newRanking);
          assert false;
        }
      }
    }
    RepresentationSameAsReachable(untightLinked, newRanking);
  }

  lemma InternalFlushMemtableMaintainsRepr(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalFlushMemtableStep?
    requires v'.betree.linked.Acyclic()
    ensures ValidRepr(v')
  {
    var linked := v.betree.linked;
    var linked' := v'.betree.linked;
    if linked.HasRoot() { 
      var oldRootAddr := linked.root.value;
      var oldRanking := LBR.BuildTightRanking(linked, linked.TheRanking());
      var newRanking := oldRanking[step.newRootAddr := oldRanking[linked.root.value]];
      RepresentationSameAsReachable(linked', newRanking);
      RepresentationSameAsReachable(linked, newRanking);
      calc {
        linked'.Representation();
        linked'.ReachableAddrsUsingRanking(newRanking);
          {
            var numChildren := |linked'.Root().children|;
            assert numChildren == |linked.Root().children|;
            var subTreeAddrs' := seq(numChildren, i requires 0 <= i < numChildren => linked'.ChildAtIdx(i).ReachableAddrsUsingRanking(newRanking));
            var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(newRanking));
            forall i | 0 <= i < numChildren 
            ensures subTreeAddrs'[i] ==  subTreeAddrs[i] {
              ReachableAddrsInAgreeingDisks(linked.ChildAtIdx(i), linked'.ChildAtIdx(i), newRanking);
            }
            Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
            Sets.UnionSeqOfSetsSoundness(subTreeAddrs');
            InternalFlushMemtableDeletesOldRoot(linked, linked', Buffer(v.betree.memtable.mapp), step.newRootAddr);
          }
        linked.ReachableAddrsUsingRanking(linked.TheRanking()) + {step.newRootAddr} - {oldRootAddr};
        v'.repr;
      }
    }
  }

  lemma ChildReachebleAddrsIsSubset(linked: LinkedBetree, ranking: Ranking, idx: nat) 
    requires linked.Acyclic()
    requires linked.ValidRanking(ranking)
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    ensures linked.ChildAtIdx(idx).ReachableAddrsUsingRanking(ranking) <= linked.ReachableAddrsUsingRanking(ranking)
  {
    var numChildren := |linked.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    // trigger
    assert subTreeAddrs[idx] == linked.ChildAtIdx(idx).ReachableAddrsUsingRanking(ranking); 
  }

  lemma {:timeLimitMultiplier 2} BuildTightRepresentationContainsDiskView(linked: LinkedBetree, ranking: Ranking) 
    requires linked.Acyclic()
    requires linked.ValidRanking(ranking)
    ensures linked.BuildTightTree().Acyclic()
    ensures forall addr | addr in linked.BuildTightTree().diskView.entries 
      :: addr in linked.BuildTightTree().Representation()
    decreases linked.GetRank(ranking)
  {
    LBR.BuildTightMaintainsRankingValidity(linked, ranking);
    forall addr | addr in linked.BuildTightTree().diskView.entries 
    ensures addr in linked.BuildTightTree().Representation()
    {
      if addr != linked.BuildTightTree().root.value {
        /* This proof is rather involved.
          - We have addr in linked.Representation(), and addr != linked.root.
          - Then, suppose addr in linked.ChildAtIdx(i).Representation().
          - Then addr in linked.ChildAtIdx(i).BuildTightTree().diskView.entries.
          - Then addr in linked.ChildAtIdx(i).BuildTightTree().Representation(), by induction.
          - Then addr in linked.BuildTightTree().ChildAtIdx(i).Representation(), since above is a subdisk.
            This is via lemma BuildTightRepresentationContainsDiskView.
          - Then addr in linked.BuildTightTree().Representation(), 
            via lemma ChildReachebleAddrsIsSubset */ 
        RepresentationSameAsReachable(linked, ranking);
        var numChildren := |linked.Root().children|;
        var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
        Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
        var idx :| 0 <= idx < numChildren && addr in subTreeAddrs[idx];
        LBR.ChildAtIdxAcyclic(linked, idx);
        RepresentationSameAsReachable(linked.ChildAtIdx(idx), ranking);
        BuildTightRepresentationContainsDiskView(linked.ChildAtIdx(idx), ranking);  // apply induction hypothesis
        LBR.BuildTightMaintainsRankingValidity(linked.ChildAtIdx(idx), ranking);
        RepresentationSameAsReachable(linked.ChildAtIdx(idx).BuildTightTree(), ranking);
        assert linked.BuildTightTree().ChildAtIdx(idx).ValidRanking(ranking);  // trigger
        ReachableAddrsInAgreeingDisks(linked.BuildTightTree().ChildAtIdx(idx), linked.ChildAtIdx(idx).BuildTightTree(), ranking);
        ChildReachebleAddrsIsSubset(linked.BuildTightTree(), ranking, idx);
        RepresentationSameAsReachable(linked.BuildTightTree(), ranking);
      }
    }
  }

  // Theorem: linked.BuildTightTree().diskView.entries.Keys == linked.BuildTightTree().Representation
  lemma BuildTightGivesTightWrtRepresentation(linked: LinkedBetree)
    requires linked.Acyclic()
    ensures linked.BuildTightTree().Acyclic()
    ensures linked.BuildTightTree().DiskIsTightWrtRepresentation();
    // i.e. linked.BuildTightTree().diskView.entries.Keys == Representation()
  {
    LBR.BuildTightMaintainsRankingValidity(linked, linked.TheRanking());
    BuildTightRepresentationContainsDiskView(linked, linked.TheRanking());
  }

  lemma InternalFlushMemtableMaintainsTightDisk(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalFlushMemtableStep?
    requires v'.betree.linked.Acyclic()
    ensures v'.betree.linked.DiskIsTightWrtRepresentation()
  {
    var newBuffer := Buffer(v.betree.memtable.mapp);
    var untightLinked :=  LB.InsertInternalFlushMemtableReplacement(v.betree.linked, newBuffer, step.newRootAddr);
    if v.betree.linked.HasRoot() {
      BuildTightGivesTightWrtRepresentation(untightLinked);
    }
  }
  
  lemma ChildAtIdxCommutesWithBuildTight(linked: LinkedBetree, idx: nat, ranking: Ranking) 
    requires linked.Acyclic()
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    requires linked.ValidRanking(ranking)

    ensures linked.ChildAtIdx(idx).BuildTightTree().WF()
    ensures linked.ChildAtIdx(idx).BuildTightTree().ValidRanking(ranking)
    ensures linked.BuildTightTree().WF()
    ensures linked.ChildAtIdx(idx).BuildTightTree().ReachableAddrsUsingRanking(ranking)
        == linked.BuildTightTree().ChildAtIdx(idx).ReachableAddrsUsingRanking(ranking)
  {
    LBR.BuildTightPreservesWF(linked, ranking);
    LBR.BuildTightPreservesWF(linked.ChildAtIdx(idx), ranking);
    assert linked.ChildAtIdx(idx).BuildTightTree().ValidRanking(ranking);  // trigger
    assert linked.BuildTightTree().ChildAtIdx(idx).ValidRanking(ranking);  // trigger
    ReachableAddrsInAgreeingDisks(linked.ChildAtIdx(idx).BuildTightTree(), linked.BuildTightTree().ChildAtIdx(idx), ranking);
  }

  // Wrapper around common use case of ReachableAddrsIgnoresRanking
  lemma RepresentationSameAsReachable(linked: LinkedBetree, ranking: Ranking)
    requires linked.Acyclic()
    requires linked.ValidRanking(ranking)
    ensures linked.Representation() == linked.ReachableAddrsUsingRanking(ranking)
    ensures linked.ReachableAddrsUsingRanking(ranking) == linked.ReachableAddrsUsingRanking(linked.TheRanking())
  {
    LBR.ReachableAddrsIgnoresRanking(linked, ranking, linked.TheRanking());
  }

  // Theorem: BuildTight does not change reachable set
  lemma ReachableAddrsIgnoresBuildTight(linked: LinkedBetree, ranking: Ranking)
    requires linked.Acyclic()
    requires linked.ValidRanking(ranking)
    ensures linked.BuildTightTree().WF()
    ensures linked.BuildTightTree().ValidRanking(ranking)
    ensures linked.BuildTightTree().ReachableAddrsUsingRanking(ranking)
      == linked.ReachableAddrsUsingRanking(ranking)
  {
    LBR.BuildTightMaintainsRankingValidity(linked, ranking);
    ReachableAddrsInAgreeingDisks(linked, linked.BuildTightTree(), ranking);
  }

  // Wrapper around ReachableAddrsIgnoresBuildTight
  lemma RepresentationIgnoresBuildTight(linked: LinkedBetree)
    requires linked.Acyclic()
    ensures linked.BuildTightTree().Acyclic()
    ensures linked.BuildTightTree().Representation()
      == linked.Representation()
  {
    var ranking := linked.TheRanking();
    LBR.BuildTightMaintainsRankingValidity(linked, ranking);
    RepresentationSameAsReachable(linked.BuildTightTree(), ranking);
    ReachableAddrsIgnoresBuildTight(linked, ranking);
  }

  // Theorem: The set of reachable addrs on path.Subpath().Substitute(..) is the same as
  // that on path.Substitute(..).ChildAtIdx(routeIdx)
  lemma ReachableAddrsOnSubpathRoute(path: Path, replacement: LinkedBetree, routeIdx: nat, pathAddrs: PathAddrs, ranking: Ranking)
    requires path.Valid()
    requires 0 < path.depth
    requires routeIdx == Route(path.linked.Root().pivotTable, path.key)
    requires path.CanSubstitute(replacement, pathAddrs);
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    // Requirements of SubstitutePreservesWF and ReplacementAcyclicImpliesSubstituteAcyclic
    requires PathAddrsFresh(path, replacement, pathAddrs)
    requires path.linked.root.value in ranking
    requires replacement.ValidRanking(ranking)

    ensures path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).Acyclic()  // prereq
    ensures path.Subpath().Substitute(replacement, pathAddrs[1..]).Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).Representation()
      == path.Subpath().Substitute(replacement, pathAddrs[1..]).Representation()
  {
    // First dispatch of the prereqs
    LBR.ChildAtIdxAcyclic(path.Substitute(replacement, pathAddrs), routeIdx);
    ReplacementAcyclicImpliesSubstituteAcyclic(path.Subpath(), replacement, pathAddrs[1..], ranking);
    LBR.SubstitutePreservesWF(replacement, path.Subpath(), pathAddrs[1..], path.Subpath().Substitute(replacement, pathAddrs[1..]));
    
    // Now prove the actual goal
    var r1 := path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).TheRanking();
    var r2 := path.Subpath().Substitute(replacement, pathAddrs[1..]).TheRanking();
    var node := path.linked.Root();
    var subtree := path.Subpath().Substitute(replacement, pathAddrs[1..]);
    var newChildren := node.children[Route(node.pivotTable, path.key) := subtree.root];
    var newNode := LB.BetreeNode(node.buffers, node.pivotTable, newChildren);
    var newDiskView := subtree.diskView.ModifyDisk(pathAddrs[0], newNode);
    var newLinked := LB.LinkedBetree(GenericDisk.Pointer.Some(pathAddrs[0]), newDiskView);
    var newLinkedChild := LB.LinkedBetree(subtree.root, newDiskView);
    ReachableAddrsInAgreeingDisks(newLinkedChild, subtree, r1);
    LBR.ReachableAddrsIgnoresRanking(path.Subpath().Substitute(replacement, pathAddrs[1..]), r1, r2);
  }

  // Theorem: Substitution does not change representation of subtrees not on the substitution path
  lemma ReachableAddrsNotOnSubpathRoute(path: Path, replacement: LinkedBetree, pathAddrs: PathAddrs, idx: nat, ranking: Ranking) 
    requires path.Valid()
    requires 0 < path.depth
    requires 0 <= idx < |path.linked.Root().children|
    requires idx != Route(path.linked.Root().pivotTable, path.key)
    requires path.CanSubstitute(replacement, pathAddrs);
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    // RankingAfterSubstitution requirements
    requires path.linked.root.value in ranking
    requires replacement.ValidRanking(ranking)
    requires Set(pathAddrs) !! ranking.Keys
    requires PathAddrsFresh(path, replacement, pathAddrs)

    ensures path.linked.ChildAtIdx(idx).Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).ChildAtIdx(idx).Acyclic()  // prereq
    ensures path.linked.ChildAtIdx(idx).Representation() ==
            path.Substitute(replacement, pathAddrs).ChildAtIdx(idx).Representation()
  { 
    // Dispatch the prereqs
    LBR.ChildAtIdxAcyclic(path.linked, idx);
    LBR.ChildAtIdxAcyclic(path.Substitute(replacement, pathAddrs), idx);

    // Now prove the main goal
    var r1 := path.linked.ChildAtIdx(idx).TheRanking();
    var r2 := LBR.RankingAfterSubstitution(replacement, ranking, path, pathAddrs);
    var node := path.linked.Root();
    path.CanSubstituteSubpath(replacement, pathAddrs);
    var subtree := path.Subpath().Substitute(replacement, pathAddrs[1..]);
    var newChildren := node.children[Route(node.pivotTable, path.key) := subtree.root];
    var newNode := LB.BetreeNode(node.buffers, node.pivotTable, newChildren);
    var newDiskView := subtree.diskView.ModifyDisk(pathAddrs[0], newNode);
    var newLinked := LB.LinkedBetree(GenericDisk.Pointer.Some(pathAddrs[0]), newDiskView);
    LBR.ReachableAddrsIgnoresRanking(path.linked.ChildAtIdx(idx), r1, r2);
    RepresentationSameAsReachable(path.Substitute(replacement, pathAddrs).ChildAtIdx(idx), r2);
    // SubstitutePreservesWF gives us path.linked.diskView.AgreesWithDisk(newLinked.diskView)
    LBR.SubstitutePreservesWF(replacement, path, pathAddrs, newLinked);
    ReachableAddrsInAgreeingDisks(path.linked.ChildAtIdx(idx), newLinked.ChildAtIdx(idx), r2);
  }

  // Theorem: Representation includes subpath representation
  lemma RootRepresentationContainsSubpathRepresentation(path: Path) 
    requires path.Valid()
    requires path.linked.Acyclic()
    requires 0 < path.depth
    ensures path.Subpath().linked.Acyclic()
    ensures path.Subpath().linked.Representation() <= path.linked.Representation();
  {
    var r1 := path.linked.TheRanking();
    var r2 := path.Subpath().linked.TheRanking();
    var routeIdx := Route(path.linked.Root().pivotTable, path.key);
    var numChildren := |path.linked.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => path.linked.ChildAtIdx(i).ReachableAddrsUsingRanking(r1));
    LBR.ReachableAddrsIgnoresRanking(path.linked.ChildAtIdx(routeIdx), r1, r2);
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
    forall addr | addr in path.Subpath().linked.Representation()
    ensures addr in path.linked.Representation()
    {
      assert addr in subTreeAddrs[routeIdx];  // trigger
    }
  }

  // Theorem path.linked.Representation() includes path.Target().Representation()
  lemma RootRepresentationContainsTargetRepresentation(path: Path)
    requires path.Valid()
    ensures path.Target().Acyclic()
    ensures path.Target().Representation() <= path.linked.Representation()
    decreases path.depth
  {
    if 0 < path.depth {
      RootRepresentationContainsTargetRepresentation(path.Subpath());
      RootRepresentationContainsSubpathRepresentation(path);
    }
  }

  // Theorem: Parent reacheable contains child reacheable
  lemma ParentReacheableContainsChildReacheable(linked:LinkedBetree, idx: nat, ranking: Ranking)
    requires linked.WF()
    requires linked.ValidRanking(ranking)
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    ensures linked.ChildAtIdx(idx).ValidRanking(ranking)  // prereq
    ensures linked.ChildAtIdx(idx).ReachableAddrsUsingRanking(ranking) <= linked.ReachableAddrsUsingRanking(ranking)
  {
    var numChildren := |linked.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
    forall addr | addr in linked.ChildAtIdx(idx).ReachableAddrsUsingRanking(ranking)
    ensures addr in linked.ReachableAddrsUsingRanking(ranking)
    {
      assert addr in subTreeAddrs[idx];  // trigger
    }
  }

  // Theorem: Representation contains child representation, wrapper around ParentReacheableContainsChildReacheable
  lemma ParentRepresentationContainsChildRepresentation(linked:LinkedBetree, idx: nat)
    requires linked.Acyclic()
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    ensures linked.ChildAtIdx(idx).Acyclic()  // prereq
    ensures linked.ChildAtIdx(idx).Representation() <= linked.Representation()
  {
    // LBR.ChildAtIdxAcyclic(linked, idx);
    var r1 := linked.TheRanking();
    LBR.ChildAtIdxAcyclic(linked, idx);
    var r2 :=linked.ChildAtIdx(idx).TheRanking();
    ParentReacheableContainsChildReacheable(linked, idx, r1);
    LBR.ReachableAddrsIgnoresRanking(linked.ChildAtIdx(idx), r1, r2);
  }

  // Theorem: path.AddrsOnPath() is either the current root, or in the subtree of path.Subpath
  lemma AddrsOnPathIsRootOrInRouteSubtree(path: Path, routeIdx: nat)
    requires path.Valid()
    requires routeIdx == Route(path.linked.Root().pivotTable, path.key)
    ensures path.linked.ChildAtIdx(routeIdx).Acyclic()
    ensures path.AddrsOnPath() <= {path.linked.root.value} + path.linked.ChildAtIdx(routeIdx).Representation()
    decreases path.depth
  {
    LBR.ChildAtIdxAcyclic(path.linked, routeIdx);
    if 0 < path.depth {
      var subRouteIdx := Route(path.Subpath().linked.Root().pivotTable, path.Subpath().key);
      AddrsOnPathIsRootOrInRouteSubtree(path.Subpath(), subRouteIdx);
      ParentRepresentationContainsChildRepresentation(path.Subpath().linked, subRouteIdx);
    }
  }

  // Theorem: Any address in a subtree's representation cannot be the root of the parent tree
  // Contrapositive of AddrInChildRepresentationImpliesNotRoot
  lemma AddrInChildRepresentationImpliesNotRoot(linked: LinkedBetree, idx: nat, addr: Address)
    requires linked.Acyclic()
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    requires linked.ChildAtIdx(idx).Acyclic()
    requires addr in linked.ChildAtIdx(idx).Representation()
    ensures addr != linked.root.value
  {
    RootAddrNotInChildRepresentation(linked, idx);
  }

  // Theorem: The root node is not in the representation of any child subtree
  lemma RootAddrNotInChildRepresentation(linked: LinkedBetree, idx: nat)
    requires linked.Acyclic()
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    ensures linked.ChildAtIdx(idx).Acyclic()  // prereq
    ensures linked.root.value !in linked.ChildAtIdx(idx).Representation()
  {
    LBR.ChildAtIdxAcyclic(linked, idx);
    assert linked.ChildAtIdx(idx).Acyclic();
    if linked.root.value in linked.ChildAtIdx(idx).Representation() {
      var tightRanking := LBR.BuildTightRanking(linked, linked.TheRanking());
      ChildrenRepresentationHaveLowerRank(linked, idx, tightRanking);
      assert false;
    }
  }

  // Theorem: Substituting an acyclic subtree into an acyclic tree produces an acyclic tree
  lemma ReplacementAcyclicImpliesSubstituteAcyclic(path: Path, replacement: LinkedBetree, pathAddrs: PathAddrs, ranking: Ranking)
    requires path.Valid()
    requires path.CanSubstitute(replacement, pathAddrs)
    requires replacement.ValidRanking(ranking)
    requires path.linked.root.value in ranking
    // Framing 
    requires SeqHasUniqueElems(pathAddrs)
    requires path.linked.diskView.IsSubDisk(replacement.diskView)
    requires PathAddrsFresh(path, replacement, pathAddrs)
    ensures path.Substitute(replacement, pathAddrs).Acyclic()
  {
    var tightRanking := LBR.BuildTightRanking(replacement, ranking);
    var newRanking := LBR.RankingAfterSubstitution(replacement, tightRanking, path, pathAddrs);
  }

  // Theorem: path.Addrs on path must be included in the root's representation
  lemma RepresentationContainsAddrsOnPath(path: Path) 
    requires path.Valid()
    ensures path.AddrsOnPath() <= path.linked.Representation()
    decreases path.depth
  {
    if 0 < path.depth {
      RepresentationContainsAddrsOnPath(path.Subpath());
      RootRepresentationContainsSubpathRepresentation(path);
    }
  }

  // Theorem: Rewriting ReachableAddrsUsingRanking as Representation
  lemma ParentRepresentationAsUnionOfChildren(linked: LinkedBetree) 
    requires linked.HasRoot()
    requires linked.Acyclic()
    ensures 
      && var n := |linked.Root().children|;
      && (forall i | 0 <= i < n :: linked.ChildAtIdx(i).Acyclic())
      && linked.Representation() == {linked.root.value} + Sets.UnionSeqOfSets(seq(n, i requires 0 <= i < n => linked.ChildAtIdx(i).Representation()))
  {
    var ranking := linked.TheRanking();
    var numChildren := |linked.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    forall idx | 0 <= idx < numChildren 
    ensures  
      && linked.ChildAtIdx(idx).Acyclic()
      && subTreeAddrs[idx] == linked.ChildAtIdx(idx).Representation()
    {
      LBR.ChildAtIdxAcyclic(linked, idx);
      RepresentationSameAsReachable(linked.ChildAtIdx(idx), ranking);
    }
    var subTreeAddrsRepr := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).Representation());
    assert subTreeAddrs == subTreeAddrsRepr;  // trigger
  }

  // Theorem: the old path root is deleted from the representation after substitution
  lemma SubstituteDeletesOldRoot(path: Path, oldRoot: Address, replacement: LinkedBetree, pathAddrs: PathAddrs, ranking: Ranking) 
    requires path.Valid()
    requires replacement.Acyclic()
    requires oldRoot !in replacement.Representation()
    requires oldRoot !in pathAddrs
    // oldRoot is not in any subtree of path.linked
    requires forall i | 0 <= i < |path.linked.Root().children|
      :: path.linked.ChildAtIdx(i).Acyclic() && oldRoot !in path.linked.ChildAtIdx(i).Representation()
    requires path.CanSubstitute(replacement, pathAddrs)
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    requires PathAddrsFresh(path, replacement, pathAddrs)
    requires replacement.ValidRanking(ranking)
    requires path.linked.root.value in ranking
    requires Set(pathAddrs) !! ranking.Keys

    ensures oldRoot !in path.Substitute(replacement, pathAddrs).Representation()
    decreases path.depth
  {
    if 0 < path.depth {
      path.CanSubstituteSubpath(replacement, pathAddrs);
      ReplacementAcyclicImpliesSubstituteAcyclic(path.Subpath(), replacement, pathAddrs[1..], ranking);

      var subpath := path.Subpath();
      var routeIdx := Route(path.linked.Root().pivotTable, path.key);
      forall i | 0 <= i < |subpath.linked.Root().children|
      ensures subpath.linked.ChildAtIdx(i).Acyclic() && oldRoot !in subpath.linked.ChildAtIdx(i).Representation()
      { 
        LBR.ChildAtIdxAcyclic(subpath.linked, i);
        // Prove that oldRoot !in subpath.linked.Representation()
        assert oldRoot !in path.linked.ChildAtIdx(routeIdx).Representation();  // trigger
        // Prove that oldRoot !in subpath.linked.ChildAtIdx(i).Representation();
        ParentRepresentationContainsChildRepresentation(subpath.linked, i);
      }
      SubstituteDeletesOldRoot(subpath, oldRoot, replacement, pathAddrs[1..], ranking);
      var numChildren := |path.Substitute(replacement, pathAddrs).Root().children|;
      forall idx | 0 <= idx < numChildren
      ensures oldRoot !in path.Substitute(replacement, pathAddrs).ChildAtIdx(idx).Representation()
      {
        if idx == routeIdx {
          ReachableAddrsOnSubpathRoute(path, replacement, routeIdx, pathAddrs, ranking);
        } else {
          ReachableAddrsNotOnSubpathRoute(path, replacement, pathAddrs, idx, ranking);
        }
      }
      ParentRepresentationAsUnionOfChildren(path.Substitute(replacement, pathAddrs));
      var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => path.Substitute(replacement, pathAddrs).ChildAtIdx(i).Representation());
      Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
    }
  }

  // Theorem: Any address in the representation after substitution could not have been on
  // on the substitution path
  lemma {:timeLimitMultiplier 3} SubstituteDeletesAddrsOnPath(path: Path, replacement: LinkedBetree, pathAddrs: PathAddrs, addr: Address, ranking: Ranking)
    requires path.Valid()
    requires path.linked.diskView.DiskHasNoDags()
    requires replacement.Acyclic()
    requires path.CanSubstitute(replacement, pathAddrs)
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    requires path.AddrsOnPath() !! replacement.Representation()
    requires Set(pathAddrs) !! ranking.Keys  // required by ReachableAddrsNotOnSubpathRoute
    requires addr in path.Substitute(replacement, pathAddrs).Representation()
    
    // Requirements of ReplacementAcyclicImpliesSubstituteAcyclic
    requires PathAddrsFresh(path, replacement, pathAddrs)
    requires path.linked.root.value in ranking
    requires replacement.ValidRanking(ranking)

    ensures addr !in path.AddrsOnPath()
    decreases path.depth
  { 
    if 0 < path.depth {
      var linked := path.linked;
      var linkedAftSubst := path.Substitute(replacement, pathAddrs);
      var r1 := linkedAftSubst.TheRanking();
      var numChildren := |linkedAftSubst.Root().children|;
      var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linkedAftSubst.ChildAtIdx(i).ReachableAddrsUsingRanking(r1));
      Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
      if addr == linkedAftSubst.root.value {
        // If addr is root after substitution
        RepresentationContainsAddrsOnPath(path);
      } else {
        // Else, addr must be in a subtree after substitution
        var idx :| 0 <= idx < numChildren && addr in subTreeAddrs[idx];
        var routeIdx := Route(linked.Root().pivotTable, path.key);
        if idx == routeIdx {
          // If addr is in the new subtree
          ReplacementAcyclicImpliesSubstituteAcyclic(path.Subpath(), replacement, pathAddrs[1..], ranking);
          LBR.ChildAtIdxAcyclic(linkedAftSubst, routeIdx);
          LBR.ReachableAddrsIgnoresRanking(
              linkedAftSubst.ChildAtIdx(routeIdx), 
              linkedAftSubst.ChildAtIdx(routeIdx).TheRanking(), r1);
          ReachableAddrsOnSubpathRoute(path, replacement, routeIdx, pathAddrs, ranking);
          SubstituteDeletesAddrsOnPath(path.Subpath(), replacement, pathAddrs[1..], addr, ranking);
          forall i | 0 <= i < |linked.Root().children|
          ensures linked.ChildAtIdx(i).Acyclic() && linked.root.value !in linked.ChildAtIdx(i).Representation()
          {
            RootAddrNotInChildRepresentation(linked, i);
          }
          SubstituteDeletesOldRoot(path, linked.root.value, replacement, pathAddrs, ranking);
        } else {
          // Else, addr is in an old legacy subtree, hence it is not in the substitution path
          LBR.ChildAtIdxAcyclic(linkedAftSubst, idx);
          RepresentationSameAsReachable(linkedAftSubst.ChildAtIdx(idx), r1);
          ReachableAddrsNotOnSubpathRoute(path, replacement, pathAddrs, idx, ranking); 
          assert linked.SubtreesAreDisjoint(idx, routeIdx); // trigger
          AddrsOnPathIsRootOrInRouteSubtree(path, routeIdx);
          forall i | 0 <= i < |linked.Root().children|
          ensures linked.ChildAtIdx(i).Acyclic() && linked.root.value !in linked.ChildAtIdx(i).Representation()
          {
            RootAddrNotInChildRepresentation(linked, i);
          }
          SubstituteDeletesOldRoot(path, linked.root.value, replacement, pathAddrs, ranking);
        }
      }      
    }
  }

  // Theorem: pathAddrs is a subset of path.Substitute(replacement, pathAddrs)
  lemma RepresentationAfterSubstituteContainsPathAddrs(path: Path, replacement: LinkedBetree, pathAddrs: PathAddrs, ranking: Ranking)
    requires path.Valid()
    requires path.CanSubstitute(replacement, pathAddrs)
    requires replacement.ValidRanking(ranking)
    requires path.linked.root.value in ranking
    // Framing 
    requires path.linked.diskView.IsSubDisk(replacement.diskView)
    requires PathAddrsFresh(path, replacement, pathAddrs)
    requires path.Substitute(replacement, pathAddrs).Acyclic()  // prereq
    ensures Set(pathAddrs) <= path.Substitute(replacement, pathAddrs).Representation()
    decreases path.depth
  {
    if 0 < path.depth {
      ReplacementAcyclicImpliesSubstituteAcyclic(path.Subpath(), replacement, pathAddrs[1..], ranking);
      RepresentationAfterSubstituteContainsPathAddrs(path.Subpath(), replacement, pathAddrs[1..], ranking);
      var routeIdx := Route(path.linked.Root().pivotTable, path.key);
      ReachableAddrsOnSubpathRoute(path, replacement, routeIdx, pathAddrs, ranking);
      ParentRepresentationContainsChildRepresentation(path.Substitute(replacement, pathAddrs), routeIdx);
    }
  }

  // Theorem: Representation of path.Substitute(..) includes that of replacement
  lemma RepresentationAfterSubstituteContainsReplacement(path: Path, replacement: LinkedBetree, pathAddrs: PathAddrs, ranking: Ranking)
    requires path.Valid()
    requires path.CanSubstitute(replacement, pathAddrs)
    requires replacement.Acyclic()
    // Requirements of ReplacementAcyclicImpliesSubstituteAcyclic
    requires replacement.ValidRanking(ranking)
    requires path.linked.root.value in ranking
    requires path.linked.diskView.IsSubDisk(replacement.diskView)
    requires PathAddrsFresh(path, replacement, pathAddrs)
    ensures path.Substitute(replacement, pathAddrs).Acyclic()  // prereq
    ensures replacement.Representation() <= path.Substitute(replacement, pathAddrs).Representation()
    decreases path.depth
  {
    ReplacementAcyclicImpliesSubstituteAcyclic(path, replacement, pathAddrs, ranking);
    if 0 < path.depth {
      RepresentationAfterSubstituteContainsReplacement(path.Subpath(), replacement, pathAddrs[1..], ranking);
      var routeIdx := Route(path.linked.Root().pivotTable, path.key);
      ReachableAddrsOnSubpathRoute(path, replacement, routeIdx, pathAddrs, ranking);
      ParentRepresentationContainsChildRepresentation(path.Substitute(replacement, pathAddrs), routeIdx);
    }
  }

  // Theorem: Child at Route(path.linked.Root().pivotTable, path.key) is same as path.Subpath()
  lemma SubpathEquivToChildAtRouteIdx(path: Path)
    requires path.Valid()
    requires 0 < path.depth
    ensures 
      && var routeIdx := Route(path.linked.Root().pivotTable, path.key);
      && path.linked.ChildAtIdx(routeIdx) == path.Subpath().linked
  {}

  // Theorem: path.AddrsOnPath() are valid diskview entries
  lemma AddrsOnPathInDiskView(path: Path) 
    requires path.Valid()
    ensures path.AddrsOnPath() <= path.linked.diskView.entries.Keys
    decreases path.depth
  {
    if 0 < path.depth {
      AddrsOnPathInDiskView(path.Subpath());
    }
  }

  // Theorem: Change in representation after switching out the root of the tree
  lemma RepresentationAfterSwitchingRoot(linked: LinkedBetree, linked': LinkedBetree, replacementAddr: Address, ranking: Ranking)
    requires linked.WF() && linked'.WF()
    requires linked.ValidRanking(ranking) && linked'.ValidRanking(ranking)
    requires linked.HasRoot() && linked'.HasRoot()
    requires linked'.root.value == replacementAddr
    requires linked'.Root().children == linked.Root().children
    requires linked'.diskView.AgreesWithDisk(linked.diskView)
    requires linked.diskView.IsFresh({replacementAddr})  // Framing
    ensures linked'.Representation() == linked.Representation() + {replacementAddr} - {linked.root.value}
  {
    var numChildren := |linked.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    var subTreeAddrs' := seq(numChildren, i requires 0 <= i < numChildren => linked'.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    forall i | 0 <= i < numChildren 
    ensures 
      && subTreeAddrs'[i] == subTreeAddrs[i] 
      && linked.root.value !in subTreeAddrs[i]
    {
      ReachableAddrsInAgreeingDisks(linked.ChildAtIdx(i), linked'.ChildAtIdx(i), ranking);
      LBR.ChildAtIdxAcyclic(linked, i);
      RootAddrNotInChildRepresentation(linked, i);
      RepresentationSameAsReachable(linked.ChildAtIdx(i), ranking);
    }
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs');
    RepresentationSameAsReachable(linked, ranking);
    RepresentationSameAsReachable(linked', ranking);
  }

  // Theorem: Valid ranking for root is also valid for any node in the Representation
  lemma RootRankingValidForAddrInRepresentation(rootLinked:LinkedBetree, addr:Address, ranking:Ranking) 
    requires rootLinked.WF()
    requires rootLinked.ValidRanking(ranking)
    requires addr in rootLinked.Representation()
    ensures rootLinked.diskView.GetEntryAsLinked(addr).ValidRanking(ranking)
    decreases rootLinked.GetRank(ranking)
  {
    if addr != rootLinked.root.value {
      var numChildren := |rootLinked.Root().children|;
      var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => rootLinked.ChildAtIdx(i).ReachableAddrsUsingRanking(rootLinked.TheRanking()));
      Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
      var idx :| 0 <= idx < numChildren && addr in subTreeAddrs[idx];
      LBR.ReachableAddrsIgnoresRanking(rootLinked.ChildAtIdx(idx), rootLinked.TheRanking(), ranking);
      assert rootLinked.ChildAtIdx(idx).ValidRanking(ranking);  // trigger
      RepresentationSameAsReachable(rootLinked.ChildAtIdx(idx), ranking);
      RootRankingValidForAddrInRepresentation(rootLinked.ChildAtIdx(idx), addr, ranking);
    }
  }

  // Theorem: Wrapper around RootRankingValidForAddrInRepresentation
  // If root is Acyclic, then any node in the Representation is Acyclic
  lemma NodesInRepresentationAreAcyclic(rootLinked:LinkedBetree, addr:Address) 
    requires rootLinked.Acyclic()
    requires addr in rootLinked.Representation()
    ensures rootLinked.diskView.GetEntryAsLinked(addr).Acyclic()
  {
    RootRankingValidForAddrInRepresentation(rootLinked, addr, rootLinked.TheRanking());
  }

  // Tony: this lemma is sprawling massive...
  lemma {:timeLimitMultiplier 2} ReprAfterSubstituteCompactReplacement(path: Path, compactedBuffers: BufferStack, replacement: LinkedBetree, replacementRanking: Ranking, pathAddrs: PathAddrs, replacementAddr: Address)
    requires path.Valid()
    requires path.linked.diskView.DiskHasNoDags()
    requires path.Target().Root().buffers.Equivalent(compactedBuffers)
    requires path.Target().diskView.IsFresh({replacementAddr})
    requires replacement == LB.InsertCompactReplacement(path.Target(), compactedBuffers, replacementAddr)
    requires replacement.ValidRanking(replacementRanking)
    requires replacement.Acyclic()
    requires path.AddrsOnPath() !! replacement.Representation()

    //RankingAfterSubstitution requirements
    requires path.linked.root.value in replacementRanking
    requires Set(pathAddrs) !! replacementRanking.Keys
    requires PathAddrsFresh(path, replacement, pathAddrs)

    requires path.CanSubstitute(replacement, pathAddrs)
    ensures path.Substitute(replacement, pathAddrs).Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Representation()
            == path.linked.Representation() + Set(pathAddrs) + {replacementAddr} - path.AddrsOnPath()
    decreases path.depth
  {
    var ranking := LBR.RankingAfterSubstitution(replacement, replacementRanking, path, pathAddrs);
    LBR.BuildTightMaintainsRankingValidity(path.Substitute(replacement, pathAddrs), ranking);
    if path.depth == 0 {
      RepresentationAfterSwitchingRoot(path.linked, replacement.BuildTightTree(), replacementAddr, ranking);
    } else {
      ReprAfterSubstituteCompactReplacement(path.Subpath(), compactedBuffers, replacement, replacementRanking, pathAddrs[1..], replacementAddr);
      /* Induction hypothesis:
        path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Representation()
        == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + {replacementAddr} - path.Subpath().AddrsOnPath();
      */
      var tightRanking := LBR.BuildTightRanking(path.linked, path.linked.TheRanking());  // trigger
      LBR.ValidRankingAllTheWayDown(tightRanking, path);
      ReprAfterSubstituteReplacementInduction1(path, replacement, pathAddrs, {replacementAddr}, {}, replacementRanking);
      ReprAfterSubstituteReplacementInduction2(path, replacement, pathAddrs, {replacementAddr}, {}, replacementRanking);
    }
  }

  // This juicy lemma requires a lot of juice
  lemma {:timeLimitMultiplier 4} ReprAfterSubstituteReplacementInduction1(path: Path, replacement: LinkedBetree, 
      pathAddrs: PathAddrs, additions: set<Address>, subtractions:set<Address>, ranking: Ranking)
    requires path.Valid()
    requires path.linked.diskView.DiskHasNoDags()
    requires 0 < path.depth
    requires path.CanSubstitute(replacement, pathAddrs)
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    requires path.Substitute(replacement, pathAddrs).BuildTightTree().Acyclic()
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Acyclic()
    requires replacement.Acyclic()
    // Requirements of Ranking. Would be the result of some lemma such as RankingAfterInsertCompactReplacement
    requires path.linked.root.value in ranking
    requires replacement.ValidRanking(ranking)
    // Framing
    requires PathAddrsFresh(path, replacement, pathAddrs)
    requires path.AddrsOnPath() !! replacement.Representation()
    requires Set(pathAddrs) !! ranking.Keys
    requires path.Target().diskView.IsFresh(additions)
    requires path.Target().Acyclic()
    requires subtractions <= path.Target().Representation()
    
    // Induction hypothesis
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Representation()
      == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + additions - path.Subpath().AddrsOnPath() - subtractions
    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Representation() 
        <= path.linked.Representation() + Set(pathAddrs) + additions - path.AddrsOnPath() - subtractions
  {
    var linkedAftSubst := path.Substitute(replacement, pathAddrs);
    forall addr | addr in linkedAftSubst.Representation() 
    ensures addr in path.linked.Representation() + Set(pathAddrs) + additions - path.AddrsOnPath() - subtractions
    {
      if addr != linkedAftSubst.root.value {
        // Here, addr is in one of the children subtrees of the new root. In this case, it
        // is either in one of the unchanged subtrees, or the one that is swapped in 
        // during substitution.
        var numChildren := |linkedAftSubst.Root().children|;
        var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linkedAftSubst.ChildAtIdx(i).ReachableAddrsUsingRanking(linkedAftSubst.TheRanking()));
        Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
        var idx :| 0 <= idx < numChildren && addr in subTreeAddrs[idx];
        LBR.ChildAtIdxAcyclic(linkedAftSubst, idx);
        var routeIdx := Route(path.linked.Root().pivotTable, path.key);
        if idx == routeIdx {
          // If addr is in the subtree that is swapped in during substitution
          RepresentationIgnoresBuildTight(path.Subpath().Substitute(replacement, pathAddrs[1..]));
          ReachableAddrsOnSubpathRoute(path, replacement, routeIdx, pathAddrs, ranking); 
          RepresentationSameAsReachable(path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx), linkedAftSubst.TheRanking());
          RootRepresentationContainsSubpathRepresentation(path);
          assert addr !in path.AddrsOnPath() by {  // trigger
            RepresentationSameAsReachable(linkedAftSubst.ChildAtIdx(routeIdx), linkedAftSubst.TheRanking());
            SubstituteDeletesAddrsOnPath(path, replacement, pathAddrs, addr, ranking);
            assert addr != path.linked.root.value;
          }
        } else {
          // Else addr is in one of the original subtrees
          // First, prove that addr in path.linked.Representation();
          RepresentationSameAsReachable(linkedAftSubst.ChildAtIdx(idx), linkedAftSubst.TheRanking());
          ReachableAddrsNotOnSubpathRoute(path, replacement, pathAddrs, idx, ranking);
          ParentRepresentationContainsChildRepresentation(path.linked, idx);

          // Next, prove that addr not in path.AddrsOnPath();
          AddrInChildRepresentationImpliesNotRoot(path.linked, idx, addr);
          AddrsOnPathIsRootOrInRouteSubtree(path, routeIdx);
          LBR.ChildAtIdxAcyclic(path.linked, idx);
          LBR.ChildAtIdxAcyclic(path.linked, routeIdx);
          assert path.linked.SubtreesAreDisjoint(idx, routeIdx);  // trigger

          // Finally, show addr not in subtractions
          if addr in subtractions {
            RootRepresentationContainsTargetRepresentation(path.Subpath());
            assert false;
          }
        }
      } else {
        AddrsOnPathInDiskView(path);
      }
    }
    RepresentationIgnoresBuildTight(linkedAftSubst);
  }

  // This juicy lemma requires a lot of juice
  lemma {:timeLimitMultiplier 3} ReprAfterSubstituteReplacementInduction2(path: Path, replacement: LinkedBetree, 
    pathAddrs: PathAddrs, additions: set<Address>, subtractions: set<Address>, ranking: Ranking)
    requires path.Valid()
    requires 0 < path.depth
    requires path.CanSubstitute(replacement, pathAddrs)
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    requires path.Substitute(replacement, pathAddrs).BuildTightTree().Acyclic()
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).Acyclic()
    requires replacement.Acyclic()
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Acyclic()
    // Requirements of Ranking. Would be the result of some lemma such as RankingAfterInsertCompactReplacement
    requires path.linked.root.value in ranking
    requires replacement.ValidRanking(ranking)
    // Framing
    requires PathAddrsFresh(path, replacement, pathAddrs)
    requires path.Target().diskView.IsFresh(additions)
    requires Set(pathAddrs) !! ranking.Keys
    requires additions <= replacement.Representation()

    // Induction hypothesis of ReprAfterSubstituteCompactReplacement
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Representation()
      == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + additions - path.Subpath().AddrsOnPath() - subtractions

    ensures path.linked.Representation() + Set(pathAddrs) + additions - path.AddrsOnPath() - subtractions
      <= path.Substitute(replacement, pathAddrs).BuildTightTree().Representation()
  {
    forall addr | addr in path.linked.Representation() + Set(pathAddrs) + additions - path.AddrsOnPath() - subtractions
    ensures addr in path.Substitute(replacement, pathAddrs).Representation()
    {
      if addr in Set(pathAddrs) {
        RepresentationAfterSubstituteContainsPathAddrs(path, replacement, pathAddrs, ranking);
      } else if addr in additions {
        RepresentationAfterSubstituteContainsReplacement(path, replacement, pathAddrs, ranking);
      } else if addr in path.linked.Representation() {
        /* This is the tricky case
        addr is not path.linked.root, because root is in path.AddrsOnPath().
        Hence, addr is in one of the children subtrees of path.linked.Root()
        If addr is not on substitution path, the addr in path.Substitute() by ReachableAddrsNotOnSubpathRoute
        Else, addr is in substitution path, and must be in path.Subpath().linked.Representation().
        Then by ReachableAddrsOnSubpathRoute, addr is in subTreeAddrs[routeIdx] of path.Substitute().Repr().
        Then addr is in path.Substitute(..).Representation() by definition of Representation
        */
        var numChildren := |path.linked.Root().children|;
        var oldSubTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => path.linked.ChildAtIdx(i).ReachableAddrsUsingRanking(path.linked.TheRanking()));
        Sets.UnionSeqOfSetsSoundness(oldSubTreeAddrs);
        var idx :| 0 <= idx < numChildren && addr in oldSubTreeAddrs[idx];
        var routeIdx := Route(path.linked.Root().pivotTable, path.key);
        LBR.ChildAtIdxAcyclic(path.linked, idx);
        RepresentationSameAsReachable(path.linked.ChildAtIdx(idx), path.linked.TheRanking());
        if idx != routeIdx {
          ReachableAddrsNotOnSubpathRoute(path, replacement, pathAddrs, idx, ranking); 
          ParentRepresentationContainsChildRepresentation(path.Substitute(replacement, pathAddrs), idx);
        } else {
          // Else addr is on substitution path
          SubpathEquivToChildAtRouteIdx(path);
          RepresentationIgnoresBuildTight(path.Subpath().Substitute(replacement, pathAddrs[1..]));
          ReachableAddrsOnSubpathRoute(path, replacement, routeIdx, pathAddrs, ranking); 
          ParentRepresentationContainsChildRepresentation(path.Substitute(replacement, pathAddrs), routeIdx);
        }
      }
    }
    RepresentationIgnoresBuildTight(path.Substitute(replacement, pathAddrs));
  }

  // Prove step.path.AddrsOnPath() !! replacement.Representation(); 
  lemma InsertCompactReplacementExcludesAddrsOnPath(path: Path, replacement: LinkedBetree, compactedBuffers: BufferStack, replacementAddr: Address)
    requires path.Valid()
    requires path.Target().Root().buffers.Equivalent(compactedBuffers)
    requires path.Target().diskView.IsFresh({replacementAddr})
    requires replacement == LB.InsertCompactReplacement(path.Target(), compactedBuffers, replacementAddr);
    requires replacement.Acyclic()
    ensures path.AddrsOnPath() !! replacement.Representation()
    decreases path.depth
  {
    var replacementRanking := replacement.TheRanking();
    var rootAddr := path.linked.root.value;
    var numChildren := |replacement.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => replacement.ChildAtIdx(i).ReachableAddrsUsingRanking(replacementRanking));
    if path.depth == 0 {
      // Base case
      forall idx | 0 <= idx < numChildren
      ensures rootAddr !in subTreeAddrs[idx]
      {
        if rootAddr in subTreeAddrs[idx] {
          LBR.ChildAtIdxAcyclic(path.Target(), idx);
          ReachableAddrsInAgreeingDisks(path.Target().ChildAtIdx(idx), replacement.ChildAtIdx(idx), replacementRanking);
          RepresentationSameAsReachable(path.linked.ChildAtIdx(idx), replacementRanking);
          RootAddrNotInChildRepresentation(path.linked, idx);
          assert false;
        }
      }
    } else {
      // Recursive case
      InsertCompactReplacementExcludesAddrsOnPath(path.Subpath(), replacement, compactedBuffers, replacementAddr);
      forall idx | 0 <= idx < numChildren
      ensures rootAddr !in subTreeAddrs[idx]
      {
        if rootAddr in subTreeAddrs[idx] {
          LBR.ValidRankingAllTheWayDown(path.linked.TheRanking(), path);
          LBR.ChildAtIdxAcyclic(path.Target(), idx);
          ReachableAddrsInAgreeingDisks(path.Target().ChildAtIdx(idx), replacement.ChildAtIdx(idx), replacementRanking);
          RepresentationSameAsReachable(path.Target().ChildAtIdx(idx), replacementRanking);
          ParentRepresentationContainsChildRepresentation(path.Target(), idx);
          RootRepresentationContainsTargetRepresentation(path.Subpath());
          var routeIdx := Route(path.linked.Root().pivotTable, path.key);
          RootAddrNotInChildRepresentation(path.linked, routeIdx);
          assert false;
        }
      }
    }
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
  }

  lemma InternalCompactMaintainsRepr(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalCompactStep?
    requires v'.betree.linked.Acyclic()
    ensures ValidRepr(v')
  {
    var linked := v.betree.linked;
    var replacement := LB.InsertCompactReplacement(step.path.Target(), step.compactedBuffers, step.targetAddr);
    var linkedRanking := LBR.BuildTightRanking(linked, linked.TheRanking());
    LBR.ValidRankingAllTheWayDown(linkedRanking, step.path);
    var replacementRanking := LBR.RankingAfterInsertCompactReplacement(step.path.Target(), step.compactedBuffers, linkedRanking, step.targetAddr);
    if linked.HasRoot() {
      InsertCompactReplacementExcludesAddrsOnPath(step.path, replacement, step.compactedBuffers, step.targetAddr);
      ReprAfterSubstituteCompactReplacement(step.path, step.compactedBuffers, replacement, replacementRanking, step.pathAddrs, step.targetAddr); 
    }
  }

  lemma InternalCompactMaintainsTightDisk(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalCompactStep?
    requires v'.betree.linked.Acyclic()
    ensures v'.betree.linked.DiskIsTightWrtRepresentation()
  {
    if v.betree.linked.HasRoot() {
      var untightLinked' := step.path.Substitute(
            LB.InsertCompactReplacement(step.path.Target(), step.compactedBuffers, step.targetAddr),
            step.pathAddrs
        );
      BuildTightGivesTightWrtRepresentation(untightLinked');
    }
  }

  lemma {:timeLimitMultiplier 2} ReprAfterSubstituteFlushReplacement(
    path: Path, replacement: LinkedBetree, childIdx: nat, replacementAddr: Address, replacementChildAddr: Address, 
    pathAddrs: PathAddrs, replacementRanking: Ranking)
    requires path.Valid()
    requires path.linked.diskView.DiskHasNoDags()
    requires path.Target().Root().OccupiedChildIndex(childIdx)
    requires replacement == LB.InsertFlushReplacement(path.Target(), childIdx, replacementAddr, replacementChildAddr)
    requires path.CanSubstitute(replacement, pathAddrs)
    requires replacement.Acyclic()
    requires replacement.ValidRanking(replacementRanking)

    // Framing
    requires replacementAddr != replacementChildAddr
    requires path.Target().diskView.IsFresh({replacementAddr, replacementChildAddr})
    requires path.AddrsOnPath() !! replacement.Representation()

    //RankingAfterSubstitution requirements
    requires path.linked.root.value in replacementRanking
    requires Set(pathAddrs) !! replacementRanking.Keys
    requires PathAddrsFresh(path, replacement, pathAddrs)

    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Representation()
            == path.linked.Representation() + Set(pathAddrs) + {replacementAddr, replacementChildAddr} 
              - path.AddrsOnPath() - {path.Target().ChildAtIdx(childIdx).root.value}
    decreases path.depth
  {
    var ranking := LBR.RankingAfterSubstitution(replacement, replacementRanking, path, pathAddrs);
    LBR.BuildTightMaintainsRankingValidity(path.Substitute(replacement, pathAddrs), ranking);
    if path.depth == 0 {
      ReprAfterSubstituteFlushReplacementBaseCase(path, replacement, childIdx, replacementAddr, replacementChildAddr, ranking);
    } else {
      ReprAfterSubstituteFlushReplacement(path.Subpath(), replacement, childIdx, replacementAddr, replacementChildAddr, pathAddrs[1..], replacementRanking);
      /* Induction hypothesis:
        path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Representation()
        == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + {replacementAddr, replacementChildAddr} 
           - path.Subpath().AddrsOnPath() - {path.Target().ChildAtIdx(childIdx).root.value};
      */
      var tightRanking := LBR.BuildTightRanking(path.linked, path.linked.TheRanking());  // trigger
      LBR.ValidRankingAllTheWayDown(tightRanking, path);
      var additions := {replacementAddr, replacementChildAddr};
      var subtractions := {path.Target().ChildAtIdx(childIdx).root.value};

      assert path.Target().ChildAtIdx(childIdx).root.value in path.Target().Representation() by {
        ParentRepresentationContainsChildRepresentation(path.Target(), childIdx);
      }
      assert replacementChildAddr in replacement.Representation() by {
        ParentRepresentationContainsChildRepresentation(replacement, childIdx);
      }
      ReprAfterSubstituteReplacementInduction1(path, replacement, pathAddrs, additions, subtractions, replacementRanking);
      ReprAfterSubstituteReplacementInduction2(path, replacement, pathAddrs, additions, subtractions, replacementRanking);
    }
  }

  lemma ReprAfterSubstituteFlushReplacementBaseCase(
    path: Path, replacement: LinkedBetree, childIdx: nat, replacementAddr: Address, replacementChildAddr: Address, ranking: Ranking)
    requires path.Valid()
    requires path.linked.diskView.DiskHasNoDags()
    requires path.depth == 0  // base case
    requires path.linked.Root().OccupiedChildIndex(childIdx)
    requires replacement == LB.InsertFlushReplacement(path.linked, childIdx, replacementAddr, replacementChildAddr)
    requires path.CanSubstitute(replacement, [])
    requires path.linked.ValidRanking(ranking)
    requires replacement.Acyclic()
    requires replacement.ValidRanking(ranking)
    requires replacement.BuildTightTree().Acyclic()
    // Framing
    requires replacementAddr != replacementChildAddr;
    requires path.linked.diskView.IsFresh({replacementAddr, replacementChildAddr})
    requires path.AddrsOnPath() !! replacement.Representation()

    ensures replacement.BuildTightTree().Representation()
            == path.linked.Representation() + {replacementAddr, replacementChildAddr} 
               - path.AddrsOnPath() - {path.linked.ChildAtIdx(childIdx).root.value}
  {
    var linked := path.linked;
    var numChildren := |replacement.Root().children|;
    var subTreeAddrs' := seq(numChildren, i requires 0 <= i < numChildren => replacement.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    
    forall idx | 
      && 0 <= idx < numChildren 
      && idx != childIdx
    ensures 
      && subTreeAddrs[idx] == subTreeAddrs'[idx]
      && linked.ChildAtIdx(childIdx).root.value !in subTreeAddrs[idx]
    {
      ReachableAddrsInAgreeingDisks(linked.ChildAtIdx(idx), replacement.ChildAtIdx(idx), ranking);
      assert linked.ChildAtIdx(childIdx).root.value !in subTreeAddrs[idx] by {
        LBR.ChildAtIdxAcyclic(linked, idx);
        LBR.ChildAtIdxAcyclic(linked, childIdx);
        assert linked.SubtreesAreDisjoint(childIdx, idx);  // trigger that makes verification fast, shaves 7secs
        RepresentationSameAsReachable(linked.ChildAtIdx(idx), ranking);
      }
    }

    assert subTreeAddrs'[childIdx] 
        == subTreeAddrs[childIdx] + {replacementChildAddr} - {linked.ChildAtIdx(childIdx).root.value}
    by {
      RepresentationAfterSwitchingRoot(linked.ChildAtIdx(childIdx), replacement.ChildAtIdx(childIdx), replacementChildAddr, ranking);
      RepresentationSameAsReachable(linked.ChildAtIdx(childIdx), ranking);
      RepresentationSameAsReachable(replacement.ChildAtIdx(childIdx), ranking);
    }
    Sets.SetSeqMath(subTreeAddrs, subTreeAddrs', childIdx, {replacementChildAddr}, {linked.ChildAtIdx(childIdx).root.value});
    RepresentationSameAsReachable(linked, ranking);
    RepresentationSameAsReachable(replacement, ranking);
    RepresentationIgnoresBuildTight(replacement);
  }

  // Prove step.path.AddrsOnPath() !! replacement.Representation(); 
  lemma InsertFlushReplacementExcludesAddrsOnPath(
    path: Path, replacement: LinkedBetree, childIdx: nat, replacementAddr: Address, replacementChildAddr: Address)
    requires path.Valid()
    requires path.Target().Root().OccupiedChildIndex(childIdx)
    requires replacement == LB.InsertFlushReplacement(path.Target(), childIdx, replacementAddr, replacementChildAddr)
    requires replacement.Acyclic()
    // Framing
    requires replacementAddr != replacementChildAddr;
    requires path.Target().diskView.IsFresh({replacementAddr, replacementChildAddr})

    ensures path.AddrsOnPath() !! replacement.Representation()
    decreases path.depth
  {
    LBR.ValidRankingAllTheWayDown(path.linked.TheRanking(), path);
    var replacementRanking := LBR.RankingAfterInsertFlushReplacement(path.Target(), path.Target().TheRanking(), childIdx, replacementAddr, replacementChildAddr);
    var rootAddr := path.linked.root.value;
    var numChildren := |replacement.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => replacement.ChildAtIdx(i).ReachableAddrsUsingRanking(replacement.TheRanking()));
    assert replacement.Root().children == path.Target().Root().children[childIdx := Pointer.Some(replacementChildAddr)];

    if path.depth == 0 {
      // Base case
      forall idx | 0 <= idx < numChildren
      ensures rootAddr !in subTreeAddrs[idx]
      {
        LBR.ChildAtIdxAcyclic(path.Target(), idx);
        LBR.ReachableAddrsIgnoresRanking(replacement.ChildAtIdx(idx), replacement.TheRanking(), replacementRanking);
        RepresentationSameAsReachable(path.linked.ChildAtIdx(idx), replacementRanking);
        if idx == childIdx {
          RepresentationAfterSwitchingRoot(path.linked.ChildAtIdx(childIdx), replacement.ChildAtIdx(childIdx), replacementChildAddr, replacementRanking);
          RootAddrNotInChildRepresentation(path.linked, childIdx);
          RepresentationSameAsReachable(replacement.ChildAtIdx(childIdx), replacementRanking);
        } else {
          if rootAddr in subTreeAddrs[idx] {
            ReachableAddrsInAgreeingDisks(path.linked.ChildAtIdx(idx), replacement.ChildAtIdx(idx), replacementRanking);
            RootAddrNotInChildRepresentation(path.linked, idx);
            assert false;
          }
        }
      }
    } else {
      // Recursive case
      InsertFlushReplacementExcludesAddrsOnPath(path.Subpath(), replacement, childIdx, replacementAddr, replacementChildAddr);
      forall idx | 0 <= idx < numChildren
      ensures rootAddr !in subTreeAddrs[idx]
      {
        LBR.ReachableAddrsIgnoresRanking(replacement.ChildAtIdx(idx), replacement.TheRanking(), replacementRanking);
        var routeIdx := Route(path.linked.Root().pivotTable, path.key);
        if idx == childIdx {
          if rootAddr in subTreeAddrs[idx] {
            RepresentationAfterSwitchingRoot(path.Target().ChildAtIdx(childIdx), replacement.ChildAtIdx(childIdx), replacementChildAddr, replacementRanking);
            RepresentationSameAsReachable(replacement.ChildAtIdx(idx), replacementRanking);
            ParentRepresentationContainsChildRepresentation(path.Target(), childIdx);
            RootRepresentationContainsTargetRepresentation(path.Subpath());
            RootAddrNotInChildRepresentation(path.linked, routeIdx);
            assert false;
          }
        } else {
          if rootAddr in subTreeAddrs[idx] {
            LBR.ValidRankingAllTheWayDown(path.linked.TheRanking(), path);
            LBR.ChildAtIdxAcyclic(path.Target(), idx);
            ReachableAddrsInAgreeingDisks(path.Target().ChildAtIdx(idx), replacement.ChildAtIdx(idx), replacementRanking);
            RepresentationSameAsReachable(path.Target().ChildAtIdx(idx), replacementRanking);
            ParentRepresentationContainsChildRepresentation(path.Target(), idx);
            RootRepresentationContainsTargetRepresentation(path.Subpath());
            RootAddrNotInChildRepresentation(path.linked, routeIdx);
            assert false;
          }
        }
      }
    }
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
  }

  lemma InternalFlushMaintainsRepr(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalFlushStep?
    requires v'.betree.linked.Acyclic()
    ensures ValidRepr(v')
  {
    var linked := v.betree.linked;
    var replacement := LB.InsertFlushReplacement(step.path.Target(), step.childIdx, step.targetAddr, step.targetChildAddr);
    var linkedRanking := LBR.BuildTightRanking(linked, linked.TheRanking());
    LBR.ValidRankingAllTheWayDown(step.path.linked.TheRanking(), step.path);
    var replacementRanking := LBR.RankingAfterInsertFlushReplacement(step.path.Target(), linkedRanking, step.childIdx, step.targetAddr, step.targetChildAddr);
    if v.betree.linked.HasRoot() {
      InsertFlushReplacementExcludesAddrsOnPath(step.path, replacement, step.childIdx, step.targetAddr, step.targetChildAddr);
      ReprAfterSubstituteFlushReplacement(step.path, replacement, step.childIdx, step.targetAddr, step.targetChildAddr, step.pathAddrs, replacementRanking);
    }
  }

  lemma InternalFlushMaintainsTightDisk(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalFlushStep?
    requires v'.betree.linked.Acyclic()
    ensures v'.betree.linked.DiskIsTightWrtRepresentation()
  {
    if v.betree.linked.HasRoot() {
      var untightLinked' := step.path.Substitute(
            LB.InsertFlushReplacement(step.path.Target(), step.childIdx, step.targetAddr, step.targetChildAddr),
            step.pathAddrs
        );
      BuildTightGivesTightWrtRepresentation(untightLinked');
    }
  }

  lemma {:timeLimitMultiplier 3} ReprAfterSubstituteSplitReplacement(
    path: Path, replacement: LinkedBetree, request: SplitRequest, newAddrs: SplitAddrs,
    pathAddrs: PathAddrs, replacementRanking: Ranking)
    requires path.Valid()
    requires path.linked.diskView.DiskHasNoDags()
    requires path.Target().CanSplitParent(request)
    requires replacement == path.Target().SplitParent(request, newAddrs)
    requires path.CanSubstitute(replacement, pathAddrs)
    requires replacement.Acyclic()
    requires replacement.ValidRanking(replacementRanking)

    // Framing
    requires path.Target().diskView.IsFresh(newAddrs.Repr())
    requires path.AddrsOnPath() !! replacement.Representation()

    //RankingAfterSubstitution requirements
    requires path.linked.root.value in replacementRanking
    requires Set(pathAddrs) !! replacementRanking.Keys
    requires PathAddrsFresh(path, replacement, pathAddrs)

    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Representation()
            == path.linked.Representation() + Set(pathAddrs) + newAddrs.Repr() 
              - path.AddrsOnPath() - {path.Target().ChildAtIdx(request.childIdx).root.value}
    decreases path.depth
  {
    var ranking := LBR.RankingAfterSubstitution(replacement, replacementRanking, path, pathAddrs);
    LBR.BuildTightMaintainsRankingValidity(path.Substitute(replacement, pathAddrs), ranking);
    if path.depth == 0 {
      ReprAfterSubstituteSplitReplacementBaseCase(path, replacement, request, newAddrs, ranking);
    } else {
      ReprAfterSubstituteSplitReplacement(path.Subpath(), replacement, request, newAddrs, pathAddrs[1..], replacementRanking);
      /* Induction hypothesis:
        path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Representation()
        == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + newAddrs.Repr()  
           - path.Subpath().AddrsOnPath() - {path.Subpath().Target().ChildAtIdx(request.childIdx).root.value};
      */
      var tightRanking := LBR.BuildTightRanking(path.linked, path.linked.TheRanking());  // trigger
      LBR.ValidRankingAllTheWayDown(tightRanking, path);
      assert path.Target().ChildAtIdx(request.childIdx).root.value in path.Target().Representation() by {
        ParentRepresentationContainsChildRepresentation(path.Target(), request.childIdx);
      }
      assert newAddrs.Repr() <= replacement.Representation() by {
        ParentRepresentationContainsChildRepresentation(replacement, request.childIdx);
        ParentRepresentationContainsChildRepresentation(replacement, request.childIdx + 1);
      }
      var additions := newAddrs.Repr();
      var subtractions := {path.Target().ChildAtIdx(request.childIdx).root.value};
      ReprAfterSubstituteReplacementInduction1(path, replacement, pathAddrs, additions, subtractions, replacementRanking);
      ReprAfterSubstituteReplacementInduction2(path, replacement, pathAddrs, additions, subtractions, replacementRanking);
    }
  }

  lemma ReprAfterSubstituteSplitReplacementBaseCase(
    path: Path, replacement: LinkedBetree, request: SplitRequest, newAddrs: SplitAddrs, ranking: Ranking)
    requires path.Valid()
    requires path.linked.diskView.DiskHasNoDags()
    requires path.depth == 0  // base case
    requires path.linked.CanSplitParent(request)
    requires replacement == path.linked.SplitParent(request, newAddrs);
    requires path.CanSubstitute(replacement, [])
    requires path.linked.ValidRanking(ranking)
    requires replacement.Acyclic()
    requires replacement.ValidRanking(ranking)
    requires replacement.BuildTightTree().Acyclic()
    // Framing
    requires path.linked.diskView.IsFresh(newAddrs.Repr())
    requires path.AddrsOnPath() !! replacement.Representation()

    ensures replacement.BuildTightTree().Representation()
            == path.linked.Representation() + newAddrs.Repr() 
              - path.AddrsOnPath() - {path.linked.ChildAtIdx(request.childIdx).root.value}
  {
    var linked := path.linked;
    var numChildren := |linked.Root().children|;
    assert |replacement.Root().children| == numChildren + 1;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    var subTreeAddrs' := seq(numChildren+1, i requires 0 <= i < numChildren+1 => replacement.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    var pivotIndex := request.childIdx;

    forall idx | 0 <= idx < pivotIndex 
    ensures 
      && subTreeAddrs[idx] == subTreeAddrs'[idx]
      && linked.ChildAtIdx(pivotIndex).root.value !in subTreeAddrs[idx]
    {
      ReachableAddrsInAgreeingDisks(linked.ChildAtIdx(idx), replacement.ChildAtIdx(idx), ranking);
      assert linked.ChildAtIdx(pivotIndex).root.value !in subTreeAddrs[idx] by {
        LBR.ChildAtIdxAcyclic(linked, idx);
        LBR.ChildAtIdxAcyclic(linked, pivotIndex);
        assert linked.SubtreesAreDisjoint(pivotIndex, idx);  // trigger
        RepresentationSameAsReachable(linked.ChildAtIdx(idx), ranking);
      }
    }

    forall idx | pivotIndex + 1 < idx < numChildren + 1 
    ensures 
      && subTreeAddrs[idx - 1] == subTreeAddrs'[idx]
      && linked.ChildAtIdx(pivotIndex).root.value !in subTreeAddrs[idx - 1]
    {
      var oldIdx := idx - 1;
      ReachableAddrsInAgreeingDisks(linked.ChildAtIdx(oldIdx), replacement.ChildAtIdx(idx), ranking);
      LBR.ChildAtIdxAcyclic(linked, oldIdx);
      LBR.ChildAtIdxAcyclic(linked, pivotIndex);
      assert linked.SubtreesAreDisjoint(pivotIndex, oldIdx);  // trigger
      RepresentationSameAsReachable(linked.ChildAtIdx(oldIdx), ranking);
    }

    var add := {newAddrs.left, newAddrs.right};
    var sub := {linked.ChildAtIdx(pivotIndex).root.value};
    assert subTreeAddrs'[pivotIndex] + subTreeAddrs'[pivotIndex+1] 
      == subTreeAddrs[pivotIndex] + add - sub
    by {
      SplittedChildRepresentation(linked, replacement, request, newAddrs, ranking);
    }
    Sets.SetSeqMath2(subTreeAddrs, subTreeAddrs', pivotIndex, add, sub);
    RepresentationSameAsReachable(linked, ranking);
    RepresentationSameAsReachable(replacement, ranking);
    RepresentationIgnoresBuildTight(replacement);
  }

  lemma {:timeLimitMultiplier 2} SplittedChildRepresentation(
    linked: LinkedBetree, replacement: LinkedBetree, request: SplitRequest, newAddrs: SplitAddrs, ranking: Ranking)
    requires linked.WF()
    requires replacement.WF()
    requires linked.ValidRanking(ranking)
    requires replacement.ValidRanking(ranking)
    requires linked.CanSplitParent(request)
    requires replacement == linked.SplitParent(request, newAddrs);
    // Framing
    requires linked.diskView.IsFresh(newAddrs.Repr())

    ensures replacement.ChildAtIdx(request.childIdx).ReachableAddrsUsingRanking(ranking) +  replacement.ChildAtIdx(request.childIdx+1).ReachableAddrsUsingRanking(ranking)
            == linked.ChildAtIdx(request.childIdx).ReachableAddrsUsingRanking(ranking) + {newAddrs.left, newAddrs.right} - {linked.ChildAtIdx(request.childIdx).root.value} 
  {
    var new1 := replacement.ChildAtIdx(request.childIdx);
    var new2 := replacement.ChildAtIdx(request.childIdx + 1);
    var old1 := linked.ChildAtIdx(request.childIdx);
    var numChildren1 := |new1.Root().children|;
    var subTreeAddrs1 := seq(numChildren1, i requires 0 <= i < numChildren1 => new1.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    var numChildren2 := |new2.Root().children|;
    var subTreeAddrs2 := seq(numChildren2, i requires 0 <= i < numChildren2 => new2.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));

    assert old1.root.value !in new1.ReachableAddrsUsingRanking(ranking) 
    by {
      forall idx | 0 <= idx < numChildren1
      ensures old1.root.value !in subTreeAddrs1[idx]
      {
        if old1.root.value in subTreeAddrs1[idx] {
          ReachableAddrsInAgreeingDisks(old1.ChildAtIdx(idx), new1.ChildAtIdx(idx), ranking);
          assert old1.ValidRanking(ranking);  // trigger
          assert old1.ChildAtIdx(idx).ValidRanking(ranking);  // trigger
          RepresentationSameAsReachable(old1.ChildAtIdx(idx), ranking);
          AddrInChildRepresentationImpliesNotRoot(old1, idx, old1.root.value);
          assert false;
        }
      }
      Sets.UnionSeqOfSetsSoundnessContrapositive(subTreeAddrs1, old1.root.value);
    }

    assert old1.root.value !in new2.ReachableAddrsUsingRanking(ranking) 
    by {
      forall idx | 0 <= idx < numChildren2
      ensures old1.root.value !in subTreeAddrs2[idx]
      {
        if old1.root.value in subTreeAddrs2[idx] {
          ReachableAddrsInAgreeingDisks(old1.ChildAtIdx(idx + request.childPivotIdx), new2.ChildAtIdx(idx), ranking);
          assert old1.ValidRanking(ranking);  // trigger
          assert old1.ChildAtIdx(idx + request.childPivotIdx).ValidRanking(ranking);  // trigger
          RepresentationSameAsReachable(old1.ChildAtIdx(idx + request.childPivotIdx), ranking);
          AddrInChildRepresentationImpliesNotRoot(old1, idx + request.childPivotIdx, old1.root.value);
          assert false;
        }
      }
      Sets.UnionSeqOfSetsSoundnessContrapositive(subTreeAddrs2, old1.root.value);
    }
    
    // assert LHS <= RHS
    forall x | x in new1.ReachableAddrsUsingRanking(ranking) + new2.ReachableAddrsUsingRanking(ranking)
    ensures x in old1.ReachableAddrsUsingRanking(ranking) + {newAddrs.left, newAddrs.right} - {old1.root.value} 
    {
      if x in new1.ReachableAddrsUsingRanking(ranking) {
        if x == new1.root.value {
          assert x == newAddrs.left;
        } else {
          Sets.UnionSeqOfSetsSoundness(subTreeAddrs1);
          var i :| 0 <= i < numChildren1 && x in subTreeAddrs1[i];
          ReachableAddrsInAgreeingDisks(old1.ChildAtIdx(i), new1.ChildAtIdx(i), ranking);
          ParentReacheableContainsChildReacheable(old1, i, ranking);
        }
      } else {
        // Case: x in new2.ReachableAddrsUsingRanking(ranking). 
        // Similar argument to above, with request.childPivotIdx offset
        if x == new2.root.value {
          assert x == newAddrs.right;
        } else {
          Sets.UnionSeqOfSetsSoundness(subTreeAddrs2);
          var i :| 0 <= i < numChildren2 && x in subTreeAddrs2[i];
          ReachableAddrsInAgreeingDisks(old1.ChildAtIdx(i + request.childPivotIdx), new2.ChildAtIdx(i), ranking);
          ParentReacheableContainsChildReacheable(old1, i + request.childPivotIdx, ranking);
        }
      }
    }

    // assert RHS <= LHS
    forall x | x in old1.ReachableAddrsUsingRanking(ranking) + {newAddrs.left, newAddrs.right} - {old1.root.value} 
    ensures x in new1.ReachableAddrsUsingRanking(ranking) + new2.ReachableAddrsUsingRanking(ranking) 
    {
      if x == newAddrs.left {
        assert x in new1.ReachableAddrsUsingRanking(ranking);
      } else if x == newAddrs.right {
        assert x in new2.ReachableAddrsUsingRanking(ranking);
      } else {
        // Case: x in old1.ReachableAddrsUsingRanking(ranking) - {old1.root.value}
        var numChildren := |old1.Root().children|;
        var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => old1.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
        if request.SplitLeaf? {
          Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
          assert false;  // in this case, old1.Representation() == {old1.root}, hence can't contain x
        } else {
          Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
          var i :| 0 <= i < numChildren && x in subTreeAddrs[i];
          if i < request.childPivotIdx {
            ReachableAddrsInAgreeingDisks(old1.ChildAtIdx(i), new1.ChildAtIdx(i), ranking);
            ParentReacheableContainsChildReacheable(new1, i, ranking);
          } else {
            ReachableAddrsInAgreeingDisks(old1.ChildAtIdx(i), new2.ChildAtIdx(i - request.childPivotIdx), ranking);
            ParentReacheableContainsChildReacheable(new2, i - request.childPivotIdx, ranking);
          }
        }
      }
    }
  }

  // Prove step.path.AddrsOnPath() !! replacement.Representation(); 
  lemma {:timeLimitMultiplier 2} InsertSplitReplacementExcludesAddrsOnPath(
    path: Path, replacement: LinkedBetree, request: SplitRequest, newAddrs: SplitAddrs)
    requires path.Valid()
    requires path.Target().CanSplitParent(request)
    requires replacement == path.Target().SplitParent(request, newAddrs)
    requires replacement.Acyclic()
    // Framing
    requires newAddrs.HasUniqueElems()
    requires path.Target().diskView.IsFresh(newAddrs.Repr())

    ensures path.AddrsOnPath() !! replacement.Representation()
    decreases path.depth
  {
    LBR.ValidRankingAllTheWayDown(path.linked.TheRanking(), path);
    var replacementRanking := LBR.RankingAfterSplitReplacement(path.Target(), path.Target().TheRanking(), request, newAddrs);
    var rootAddr := path.linked.root.value;
    var numChildren := |replacement.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => replacement.ChildAtIdx(i).ReachableAddrsUsingRanking(replacement.TheRanking()));
    var childIdx := request.childIdx;

    if path.depth == 0 {
      // Base case
      var linked := path.linked;
      forall idx | 0 <= idx < numChildren 
      ensures rootAddr !in subTreeAddrs[idx]
      {
        if idx < childIdx {
          ReachableAddrsInAgreeingDisks(linked.ChildAtIdx(idx), replacement.ChildAtIdx(idx), replacementRanking);
          LBR.ReachableAddrsIgnoresRanking(replacement.ChildAtIdx(idx), replacementRanking, replacement.TheRanking());
          RootAddrNotInChildRepresentation(linked, idx);
          RepresentationSameAsReachable(linked.ChildAtIdx(idx), replacementRanking);
        } else if childIdx + 1 < idx {
          ReachableAddrsInAgreeingDisks(linked.ChildAtIdx(idx-1), replacement.ChildAtIdx(idx), replacementRanking);
          LBR.ReachableAddrsIgnoresRanking(replacement.ChildAtIdx(idx), replacementRanking, replacement.TheRanking());
          RootAddrNotInChildRepresentation(linked, idx-1);
          RepresentationSameAsReachable(linked.ChildAtIdx(idx-1), replacementRanking);
        } else {
          assert idx == childIdx || idx == childIdx + 1;  // trigger
          SplittedChildRepresentation(linked, replacement, request, newAddrs, replacementRanking);
          LBR.ReachableAddrsIgnoresRanking(replacement.ChildAtIdx(childIdx), replacementRanking, replacement.TheRanking());
          LBR.ReachableAddrsIgnoresRanking(replacement.ChildAtIdx(childIdx+1), replacementRanking, replacement.TheRanking());
          RootAddrNotInChildRepresentation(linked, childIdx);
          RepresentationSameAsReachable(linked.ChildAtIdx(childIdx), replacementRanking);
        }
      }
      Sets.UnionSeqOfSetsSoundnessContrapositive(subTreeAddrs, rootAddr);
    } else {
      // Inductive case
      InsertSplitReplacementExcludesAddrsOnPath(path.Subpath(), replacement, request, newAddrs);
      var routeIdx := Route(path.linked.Root().pivotTable, path.key);
      assert path.Subpath().AddrsOnPath() !! replacement.Representation();
      forall idx | 0 <= idx < numChildren 
      ensures rootAddr !in subTreeAddrs[idx]
      {
        if rootAddr in subTreeAddrs[idx] {
          LBR.ReachableAddrsIgnoresRanking(replacement.ChildAtIdx(idx), replacementRanking, replacement.TheRanking());
          if idx < childIdx { 
            ReachableAddrsInAgreeingDisks(path.Target().ChildAtIdx(idx), replacement.ChildAtIdx(idx), replacementRanking);
            LBR.ValidRankingAllTheWayDown(path.linked.TheRanking(), path);
            LBR.ChildAtIdxAcyclic(path.Target(), idx);
            RepresentationSameAsReachable(path.Target().ChildAtIdx(idx), replacementRanking);
            ParentRepresentationContainsChildRepresentation(path.Target(), idx);
            RootRepresentationContainsTargetRepresentation(path.Subpath());
            RootAddrNotInChildRepresentation(path.linked, routeIdx);
            assert false;
          } else if childIdx + 1 < idx {
            ReachableAddrsInAgreeingDisks(path.Target().ChildAtIdx(idx-1), replacement.ChildAtIdx(idx), replacementRanking);
            LBR.ValidRankingAllTheWayDown(path.linked.TheRanking(), path);
            LBR.ChildAtIdxAcyclic(path.Target(), idx-1);
            RepresentationSameAsReachable(path.Target().ChildAtIdx(idx-1), replacementRanking);
            ParentRepresentationContainsChildRepresentation(path.Target(), idx-1);
            RootRepresentationContainsTargetRepresentation(path.Subpath());
            RootAddrNotInChildRepresentation(path.linked, routeIdx);
            assert false;
          } else {
            assert idx == childIdx || idx == childIdx + 1;  // trigger
            SplittedChildRepresentation(path.Target(), replacement, request, newAddrs, replacementRanking);
            LBR.ValidRankingAllTheWayDown(path.linked.TheRanking(), path);
            LBR.ChildAtIdxAcyclic(path.Target(), childIdx);
            RepresentationSameAsReachable(path.Target().ChildAtIdx(childIdx), replacementRanking);
            ParentRepresentationContainsChildRepresentation(path.Target(),childIdx);
            RootRepresentationContainsTargetRepresentation(path.Subpath());
            RootAddrNotInChildRepresentation(path.linked, routeIdx);
            assert false;
          }
        }      
      }
      Sets.UnionSeqOfSetsSoundnessContrapositive(subTreeAddrs, rootAddr);
    }
  }

  lemma InternalSplitMaintainsRepr(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalSplitStep?
    requires v'.betree.linked.Acyclic()
    ensures ValidRepr(v')
  {
    var linked := v.betree.linked;
    var replacement := step.path.Target().SplitParent(step.request, step.newAddrs);
    var linkedRanking := LBR.BuildTightRanking(linked, linked.TheRanking());
    LBR.ValidRankingAllTheWayDown(step.path.linked.TheRanking(), step.path);
    var replacementRanking := LBR.RankingAfterSplitReplacement(step.path.Target(), linkedRanking, step.request, step.newAddrs);
    if v.betree.linked.HasRoot() {
      InsertSplitReplacementExcludesAddrsOnPath(step.path, replacement, step.request, step.newAddrs);
      ReprAfterSubstituteSplitReplacement(step.path, replacement, step.request, step.newAddrs, step.pathAddrs, replacementRanking);
    }
    var newAddrs := Set(step.pathAddrs) + step.newAddrs.Repr();
    var discardAddrs := step.path.AddrsOnPath() + {step.path.Target().ChildAtIdx(step.request.childIdx).root.value};
    assert v'.betree.linked.Representation() == v.repr + newAddrs - discardAddrs;
  }

  lemma InternalSplitMaintainsTightDisk(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalSplitStep?
    requires v'.betree.linked.Acyclic()
    ensures v'.betree.linked.DiskIsTightWrtRepresentation()
  {
    if v.betree.linked.HasRoot() {
      var replacement := step.path.Target().SplitParent(step.request, step.newAddrs);
      step.path.Target().SplitParentCanSubstitute(step.request, step.newAddrs);
      var untightLinked' := step.path.Substitute(
            step.path.Target().SplitParent(step.request, step.newAddrs),
            step.pathAddrs
        );
      BuildTightGivesTightWrtRepresentation(untightLinked');
    }
  }

  lemma {:timeLimitMultiplier 2} InternalGrowMaintainsDagFree(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalGrowStep?
    requires v'.betree.linked.Acyclic()
    ensures v'.betree.linked.diskView.DiskHasNoDags();
  {
    var dv' := v'.betree.linked.diskView;
    forall addr | 
        && addr in dv'.entries 
        && var linked' := dv'.GetEntryAsLinked(addr);
        && var numChildren := |linked'.Root().children|;
        && linked'.HasRoot()
    ensures dv'.GetEntryAsLinked(addr).AllSubtreesAreDisjoint()
    {
      var linked' := dv'.GetEntryAsLinked(addr);
      var numChildren := |linked'.Root().children|;
      forall i, j |
          && i != j 
          && 0 <= i < numChildren
          && 0 <= j < numChildren
          && linked'.ChildAtIdx(i).Acyclic()
          && linked'.ChildAtIdx(j).Acyclic()
      ensures 
        linked'.SubtreesAreDisjoint(i, j)
      {
        if addr != step.newRootAddr {
          var ranking := LBR.BuildTightRanking(v.betree.linked, v.betree.linked.TheRanking());
          var ranking' := LBR.InsertGrowReplacementNewRanking(v.betree.linked, ranking, step.newRootAddr);
          var dv := v.betree.linked.diskView;
          var linked := dv.GetEntryAsLinked(addr);
          NodesInRepresentationAreAcyclic(v.betree.linked, addr);
          LBR.ChildAtIdxAcyclic(linked, i);
          LBR.ChildAtIdxAcyclic(linked, j);
          assert linked.ValidRanking(ranking') by {
            RootRankingValidForAddrInRepresentation(v.betree.linked, addr, ranking');
          }
          assert linked.ChildAtIdx(i).Representation() == linked'.ChildAtIdx(i).Representation() by {
            RepresentationInAgreeingDisks(linked.ChildAtIdx(i), linked'.ChildAtIdx(i), ranking');
          }
          assert linked.ChildAtIdx(j).Representation() == linked'.ChildAtIdx(j).Representation() by {
            RepresentationInAgreeingDisks(linked.ChildAtIdx(j), linked'.ChildAtIdx(j), ranking');
          }
        }
      }
    }
  }

  lemma InvNext(v: Variables, v': Variables, lbl: TransitionLabel) 
    requires Inv(v)
    requires Next(v, v', lbl)
    ensures Inv(v')
  {
    var step: Step :| NextStep(v, v', lbl, step);
    match step {
      case QueryStep(receipt) => {
        assert Inv(v');
      }
      case PutStep() => {
        assert Inv(v');
      }
      case QueryEndLsnStep() => {
        assert Inv(v');
      }
      case FreezeAsStep() => {
        assert Inv(v');
      }
      case InternalGrowStep(_) => {
        LBR.InvNextInternalGrowStep(I(v), I(v'), lbl.I(), step.I());
        InternalGrowMaintainsRepr(v, v', lbl, step);
        InternalGrowMaintainsDagFree(v, v', lbl, step);
        assert Inv(v');
      }
      case InternalSplitStep(_, _, _, _) => {
        LBR.InvNextInternalSplitStep(I(v), I(v'), lbl.I(), step.I());
        InternalSplitMaintainsRepr(v, v', lbl, step);
        InternalSplitMaintainsTightDisk(v, v', lbl, step);
        assume v'.betree.linked.diskView.DiskHasNoDags();
        assert Inv(v');
      }
      case InternalFlushStep(_, _, _, _, _) => {
        LBR.InvNextInternalFlushStep(I(v), I(v'), lbl.I(), step.I());
        InternalFlushMaintainsRepr(v, v', lbl, step);
        InternalFlushMaintainsTightDisk(v, v', lbl, step);
        assume v'.betree.linked.diskView.DiskHasNoDags();
        assert Inv(v');
      }
      case InternalFlushMemtableStep(_) => {
        LBR.InvNextInternalFlushMemtableStep(I(v), I(v'), lbl.I(), step.I());
        InternalFlushMemtableMaintainsRepr(v, v', lbl, step);
        InternalFlushMemtableMaintainsTightDisk(v, v', lbl, step);
        assume v'.betree.linked.diskView.DiskHasNoDags();
        assert Inv(v');
      }
      case InternalCompactStep(_, _, _, _) => {
        LBR.InvNextInternalCompactStep(I(v), I(v'), lbl.I(), step.I());
        InternalCompactMaintainsRepr(v, v', lbl, step);
        InternalCompactMaintainsTightDisk(v, v', lbl, step);
        assume v'.betree.linked.diskView.DiskHasNoDags();
        assert Inv(v');
      }
      case InternalMapReserveStep() => {
        assert Inv(v');
      }
      case InternalMapFreeStep() => {
        assert Inv(v');
      }
      case InternalNoOpStep() => {
        assert Inv(v');
      }
    }
  }


  //******** PROVE REFINEMENT ********//

  lemma InitRefines(v: Variables, gcBetree: GCStampedBetree)
    requires Init(v, gcBetree)
    requires LBR.InvLinkedBetree(gcBetree.I().value)
    ensures Inv(v)
    ensures LB.Init(I(v), gcBetree.I())
  {
    InvInit(v, gcBetree);
    LBR.InitRefines(I(v), gcBetree.I());
  }

  lemma NextRefines(v: Variables, v': Variables, lbl: TransitionLabel)
    requires Inv(v)
    requires Next(v, v', lbl)
    ensures v'.WF()
    ensures Inv(v')
    ensures LB.Next(I(v), I(v'), lbl.I())
  {
    InvNext(v, v', lbl);
    var step: Step :| NextStep(v, v', lbl, step);
    assert LB.NextStep(I(v), I(v'), lbl.I(), step.I());
  }
}
