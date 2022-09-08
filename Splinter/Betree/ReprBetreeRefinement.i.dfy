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
  import LinkedBetreeMod
  import LinkedBetreeRefinement
  import GenericDisk
  import Sets
  import opened Sequences

  type Ranking = GenericDisk.Ranking

  function I(v: Variables) : (out: LinkedBetreeMod.Variables) {
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
    && LinkedBetreeRefinement.Inv(v.betree)
    && ValidRepr(v)                                    // v.repr == Representation
    && v.betree.linked.DiskIsTightWrtRepresentation()  // diskView == Representation
  }

  //******** PROVE INVARIANTS ********//

  lemma InvInit(v: Variables, gcBetree: GCStampedBetree) 
    requires Init(v, gcBetree)
    requires LinkedBetreeRefinement.InvLinkedBetree(gcBetree.I().value)
    ensures Inv(v)
  {
    LinkedBetreeRefinement.InitRefines(I(v), gcBetree.I());
  }

  // Theorem: If t1.root = t2.root and their disks agree, then t1 and t2 have the same Representation
  lemma ReachableAddrsInAgreeingDisks(t1: LinkedBetree, t2: LinkedBetree, ranking: Ranking) 
    requires t1.Acyclic()
    requires t2.Acyclic()
    requires t1.diskView.AgreesWithDisk(t2.diskView)
    requires t1.root == t2.root
    requires t1.ValidRanking(ranking)
    requires t2.ValidRanking(ranking)
    ensures t1.ReachableAddrsUsingRanking(ranking) == t2.ReachableAddrsUsingRanking(ranking)
    decreases t1.GetRank(ranking)
  {
    if t1.HasRoot() {
      var numChildren := |t1.Root().children|;
      forall i | 0 <= i < numChildren 
      ensures t1.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking) == t2.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking)
      {
        LinkedBetreeRefinement.ChildAtIdxAcyclic(t1, i);
        LinkedBetreeRefinement.ChildAtIdxAcyclic(t2, i);
        ReachableAddrsInAgreeingDisks(t1.ChildAtIdx(i), t2.ChildAtIdx(i), ranking);
      }
      var t1SubAddrs := seq(numChildren, i requires 0 <= i < numChildren => t1.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
      var t2SubAddrs := seq(numChildren, i requires 0 <= i < numChildren => t2.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
      assert t1SubAddrs == t2SubAddrs;  // trigger
    }
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
    var oldRanking := LinkedBetreeRefinement.BuildTightRanking(linked, linked.TheRanking());
    var newRanking := LinkedBetreeRefinement.InsertGrowReplacementNewRanking(linked, oldRanking, step.newRootAddr);
    if v.betree.linked.HasRoot() {
      LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked, linked.TheRanking(), oldRanking);
      LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked, oldRanking, newRanking);
      var numChildren := |linked'.Root().children|;
      var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked'.ChildAtIdx(i).ReachableAddrsUsingRanking(newRanking));
      Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
      LinkedBetreeRefinement.ChildAtIdxAcyclic(linked', 0);
      ReachableAddrsInAgreeingDisks(linked, linked'.ChildAtIdx(0), newRanking);
      LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked', linked'.TheRanking(), newRanking);
      assert v'.repr == v'.betree.linked.Representation();
    }
  }

  // Theorem: All reachable addresses must have a lower smaller ranking than the root
  lemma ReachableAddressesHaveLowerRank(linked: LinkedBetree, topAddr: Address, topRank: nat, ranking: Ranking) 
    requires linked.WF()
    requires linked.ValidRanking(ranking)
    requires LinkedBetreeRefinement.RankingIsTight(linked.diskView, ranking)
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

  lemma InternalFlushMemtableDeletesOldRoot(linked: LinkedBetree, linked':LinkedBetree, newBuffer: Buffer, newRootAddr:Address)
    requires linked.Acyclic()
    requires linked'.Acyclic()
    requires linked.HasRoot()
    requires linked.diskView.IsFresh({newRootAddr})
    requires linked' == LinkedBetreeMod.InsertInternalFlushMemtableReplacement(linked, newBuffer, newRootAddr).BuildTightTree()
    ensures linked.root.value !in linked'.diskView.entries
  {
    var oldRootAddr := linked.root.value;
    var oldRanking := LinkedBetreeRefinement.BuildTightRanking(linked, linked.TheRanking());
    var newRanking := oldRanking[newRootAddr := oldRanking[linked.root.value]];
    var untightLinked := LinkedBetreeMod.InsertInternalFlushMemtableReplacement(linked, newBuffer, newRootAddr);
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
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(untightLinked, untightLinked.TheRanking(), newRanking);
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
      var oldRanking := LinkedBetreeRefinement.BuildTightRanking(linked, linked.TheRanking());
      var newRanking := oldRanking[step.newRootAddr := oldRanking[linked.root.value]];
      LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked', linked'.TheRanking(), newRanking);
      LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked, linked.TheRanking(), newRanking);
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
              LinkedBetreeRefinement.ChildAtIdxAcyclic(linked, i);
              LinkedBetreeRefinement.ChildAtIdxAcyclic(linked', i);
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
    LinkedBetreeRefinement.BuildTightMaintainsRankingValidity(linked, ranking);
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
        LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked, linked.TheRanking(), ranking);
        var numChildren := |linked.Root().children|;
        var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
        Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
        var idx :| 0 <= idx < numChildren && addr in subTreeAddrs[idx];
        LinkedBetreeRefinement.ChildAtIdxAcyclic(linked, idx);
        LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked.ChildAtIdx(idx), ranking, linked.ChildAtIdx(idx).TheRanking());
        BuildTightRepresentationContainsDiskView(linked.ChildAtIdx(idx), ranking);  // apply induction hypothesis
        LinkedBetreeRefinement.BuildTightMaintainsRankingValidity(linked.ChildAtIdx(idx), ranking);
        LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked.ChildAtIdx(idx).BuildTightTree(), ranking, linked.ChildAtIdx(idx).BuildTightTree().TheRanking());
        assert linked.BuildTightTree().ChildAtIdx(idx).ValidRanking(ranking);  // trigger
        ReachableAddrsInAgreeingDisks(linked.BuildTightTree().ChildAtIdx(idx), linked.ChildAtIdx(idx).BuildTightTree(), ranking);
        ChildReachebleAddrsIsSubset(linked.BuildTightTree(), ranking, idx);  
        LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked.BuildTightTree(), ranking, linked.BuildTightTree().TheRanking());
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
    LinkedBetreeRefinement.BuildTightMaintainsRankingValidity(linked, linked.TheRanking());
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
    var untightLinked :=  LinkedBetreeMod.InsertInternalFlushMemtableReplacement(v.betree.linked, newBuffer, step.newRootAddr);
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
    LinkedBetreeRefinement.BuildTightPreservesWF(linked, ranking);
    LinkedBetreeRefinement.BuildTightPreservesWF(linked.ChildAtIdx(idx), ranking);
    assert linked.ChildAtIdx(idx).BuildTightTree().ValidRanking(ranking);  // trigger
    assert linked.BuildTightTree().ChildAtIdx(idx).ValidRanking(ranking);  // trigger
    ReachableAddrsInAgreeingDisks(linked.ChildAtIdx(idx).BuildTightTree(), linked.BuildTightTree().ChildAtIdx(idx), ranking);
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
    LinkedBetreeRefinement.BuildTightMaintainsRankingValidity(linked, ranking);
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
    LinkedBetreeRefinement.BuildTightMaintainsRankingValidity(linked, ranking);
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked.BuildTightTree(), linked.BuildTightTree().TheRanking(), ranking);
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
    // Requirements of SubstitutePreservesWF
    requires SeqHasUniqueElems(pathAddrs)
    requires path.linked.diskView.IsFresh(Set(pathAddrs))
    requires replacement.diskView.IsFresh(Set(pathAddrs))
    // Requirements of RankingAfterSubstitution
    requires path.linked.root.value in ranking
    requires replacement.ValidRanking(ranking)
    requires Set(pathAddrs) !! ranking.Keys

    ensures path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).Acyclic()  // prereq
    ensures path.Subpath().Substitute(replacement, pathAddrs[1..]).Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).Representation()
      == path.Subpath().Substitute(replacement, pathAddrs[1..]).Representation()
  {
    // First dispatch of the prereqs
    LinkedBetreeRefinement.ChildAtIdxAcyclic(path.Substitute(replacement, pathAddrs), routeIdx);
    LinkedBetreeRefinement.SubstitutePreservesWF(replacement, path.Subpath(), pathAddrs[1..], path.Subpath().Substitute(replacement, pathAddrs[1..]));
    var subpathSubstRanking := LinkedBetreeRefinement.RankingAfterSubstitution(replacement, ranking, path.Subpath(), pathAddrs[1..]);
    
    // Now prove the actual goal
    var r1 := path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).TheRanking();
    var r2 := path.Subpath().Substitute(replacement, pathAddrs[1..]).TheRanking();
    var node := path.linked.Root();
    var subtree := path.Subpath().Substitute(replacement, pathAddrs[1..]);
    var newChildren := node.children[Route(node.pivotTable, path.key) := subtree.root];
    var newNode := LinkedBetreeMod.BetreeNode(node.buffers, node.pivotTable, newChildren);
    var newDiskView := subtree.diskView.ModifyDisk(pathAddrs[0], newNode);
    var newLinked := LinkedBetreeMod.LinkedBetree(GenericDisk.Pointer.Some(pathAddrs[0]), newDiskView);
    var newLinkedChild := LinkedBetreeMod.LinkedBetree(subtree.root, newDiskView);
    ReachableAddrsInAgreeingDisks(newLinkedChild, subtree, r1);
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(path.Subpath().Substitute(replacement, pathAddrs[1..]), r1, r2);
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
    requires SeqHasUniqueElems(pathAddrs)
    requires Set(pathAddrs) !! ranking.Keys
    requires SeqHasUniqueElems(pathAddrs)
    requires path.linked.diskView.IsFresh(Set(pathAddrs))
    requires replacement.diskView.IsFresh(Set(pathAddrs))

    ensures path.linked.ChildAtIdx(idx).Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).ChildAtIdx(idx).Acyclic()  // prereq
    ensures path.linked.ChildAtIdx(idx).Representation() ==
            path.Substitute(replacement, pathAddrs).ChildAtIdx(idx).Representation()
  { 
    // Dispatch the prereqs
    LinkedBetreeRefinement.ChildAtIdxAcyclic(path.linked, idx);
    LinkedBetreeRefinement.ChildAtIdxAcyclic(path.Substitute(replacement, pathAddrs), idx);

    // Now prove the main goal
    var r1 := path.linked.ChildAtIdx(idx).TheRanking();
    var r2 := LinkedBetreeRefinement.RankingAfterSubstitution(replacement, ranking, path, pathAddrs);
    var node := path.linked.Root();
    path.CanSubstituteSubpath(replacement, pathAddrs);
    var subtree := path.Subpath().Substitute(replacement, pathAddrs[1..]);
    var newChildren := node.children[Route(node.pivotTable, path.key) := subtree.root];
    var newNode := LinkedBetreeMod.BetreeNode(node.buffers, node.pivotTable, newChildren);
    var newDiskView := subtree.diskView.ModifyDisk(pathAddrs[0], newNode);
    var newLinked := LinkedBetreeMod.LinkedBetree(GenericDisk.Pointer.Some(pathAddrs[0]), newDiskView);
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(path.linked.ChildAtIdx(idx), r1, r2);
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(path.Substitute(replacement, pathAddrs).ChildAtIdx(idx), path.Substitute(replacement, pathAddrs).ChildAtIdx(idx).TheRanking(), r2);
    // SubstitutePreservesWF gives us path.linked.diskView.AgreesWithDisk(newLinked.diskView)
    LinkedBetreeRefinement.SubstitutePreservesWF(replacement, path, pathAddrs, newLinked);
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
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(path.linked.ChildAtIdx(routeIdx), r1, r2);
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
    forall addr | addr in path.Subpath().linked.Representation()
    ensures addr in path.linked.Representation()
    {
      assert addr in subTreeAddrs[routeIdx];  // trigger
    }
  }

  // Theorem: Representation contains child representation
  lemma ParentRepresentationContainsChildRepresentation(linked:LinkedBetree, idx: nat)
    requires linked.Acyclic()
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    ensures linked.ChildAtIdx(idx).Acyclic()  // prereq
    ensures linked.ChildAtIdx(idx).Representation() <= linked.Representation()
  {
    LinkedBetreeRefinement.ChildAtIdxAcyclic(linked, idx);
    var r1 := linked.TheRanking();
    var r2 :=linked.ChildAtIdx(idx).TheRanking();
    var numChildren := |linked.Root().children|;
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linked.ChildAtIdx(i).ReachableAddrsUsingRanking(r1));
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked.ChildAtIdx(idx), r1, r2);
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
    forall addr | addr in linked.ChildAtIdx(idx).Representation()
    ensures addr in linked.Representation()
    {
      assert addr in subTreeAddrs[idx];  // trigger
    }
  }

  // Theorem: Subtree representations have null intersections
  lemma SubtreeRepresentationsAreDisjoint(linked: LinkedBetree, i: nat, j: nat) 
    requires linked.Acyclic()
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(i)
    requires linked.Root().ValidChildIndex(j)
    requires i != j
    ensures linked.ChildAtIdx(i).Acyclic()  // prereq
    ensures linked.ChildAtIdx(j).Acyclic()  // prereq
    ensures linked.ChildAtIdx(i).Representation() !! linked.ChildAtIdx(j).Representation()
  {
    // Dispatch the prereqs
    LinkedBetreeRefinement.ChildAtIdxAcyclic(linked, i);
    LinkedBetreeRefinement.ChildAtIdxAcyclic(linked, j);

    // TODO(tony): We don't actually know that our tree is not a DAG?
    // Copy on write will introduce DAGs into the disk, but the representation of 
    // should any pair of children of any node should not have overlaps, I think.
    assume false;

    // Now prove the actual goal
    forall addr | addr in linked.ChildAtIdx(i).Representation() 
    ensures addr !in linked.ChildAtIdx(j).Representation()
    {}
  }

  // Theorem: path.AddrsOnPath() is either the current root, or in the subtree of path.Subpath
  lemma AddrsOnPathIsRootOrInRouteSubtree(path: Path, routeIdx: nat)
    requires path.Valid()
    requires routeIdx == Route(path.linked.Root().pivotTable, path.key)
    ensures path.linked.ChildAtIdx(routeIdx).Acyclic()
    ensures path.AddrsOnPath() <= {path.linked.root.value} + path.linked.ChildAtIdx(routeIdx).Representation()
    decreases path.depth
  {
    LinkedBetreeRefinement.ChildAtIdxAcyclic(path.linked, routeIdx);
    if 0 < path.depth {
      var subRouteIdx := Route(path.Subpath().linked.Root().pivotTable, path.Subpath().key);
      AddrsOnPathIsRootOrInRouteSubtree(path.Subpath(), subRouteIdx);
      ParentRepresentationContainsChildRepresentation(path.Subpath().linked, subRouteIdx);
    }
  }

  // Theorem: Any address in a subtree's representation cannot be the root of the parent tree
  lemma AddrInChildRepresentationImpliesNotRoot(linked: LinkedBetree, idx: nat, addr: Address)
    requires linked.Acyclic()
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    requires linked.ChildAtIdx(idx).Acyclic()
    requires addr in linked.ChildAtIdx(idx).Representation()
    ensures addr != linked.root.value
  {
    var ranking := LinkedBetreeRefinement.BuildTightRanking(linked, linked.TheRanking());
    var rootAddr := linked.root.value;
    ReachableAddressesHaveLowerRank(linked.ChildAtIdx(idx), rootAddr, ranking[rootAddr], ranking);
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linked.ChildAtIdx(idx), linked.ChildAtIdx(idx).TheRanking(), ranking);
  }

  // Theorem: Contrapositive of AddrInChildRepresentationImpliesNotRoot
  lemma RootAddrNotInChildRepresentation(linked: LinkedBetree, idx: nat)
    requires linked.Acyclic()
    requires linked.HasRoot()
    requires linked.Root().ValidChildIndex(idx)
    requires linked.ChildAtIdx(idx).Acyclic()
    ensures linked.root.value !in linked.ChildAtIdx(idx).Representation()
  {
    forall addr | addr in linked.ChildAtIdx(idx).Representation() 
    ensures addr != linked.root.value
    {
      AddrInChildRepresentationImpliesNotRoot(linked, idx, addr);
    }
  }

  // Theorem: Any address in a substituted subtree's representation cannot be the root 
  // of the old parent tree
  lemma AddrInSubstituteSubtreeCannotBeOldRoot(path: Path, replacement: LinkedBetree, pathAddrs: PathAddrs, routeIdx:nat, addr: Address)
    requires path.Valid()
    requires 0 < path.depth
    requires routeIdx == Route(path.linked.Root().pivotTable, path.key)
    requires path.CanSubstitute(replacement, pathAddrs)
    requires path.Substitute(replacement, pathAddrs).WF()
    requires path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).Acyclic()
    requires addr in path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).Representation()
    ensures addr != path.linked.root.value
  {
    assume false;
  }

  // Theorem: pathAddrs is a subset of path.Substitute(replacement, pathAddrs)
  lemma RepresentationAfterSubstituteIncludesPathAddrs(path: Path, replacement: LinkedBetree, pathAddrs: PathAddrs)
    requires path.Valid()
    requires path.CanSubstitute(replacement, pathAddrs)
    ensures path.Substitute(replacement, pathAddrs).Acyclic()  // prereq
    ensures Set(pathAddrs) <= path.Substitute(replacement, pathAddrs).Representation()
  {
    assume false;
  }

  // Theorem: Representation of path.Substitute(..) includes that of replacement
  lemma RepresentationAfterSubstituteIncludesReplacement(path: Path, replacement: LinkedBetree, pathAddrs: PathAddrs)
    requires path.Valid()
    requires path.CanSubstitute(replacement, pathAddrs)
    requires replacement.Acyclic()
    ensures path.Substitute(replacement, pathAddrs).Acyclic()  // prereq
    ensures replacement.Representation() <= path.Substitute(replacement, pathAddrs).Representation()
  {
    assume false;
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

  // Expands path.Substitute().ChildAtIdx(routeIdx).Representation into its components
  lemma SubstitutedBranchRepresentation(path: Path, replacement: LinkedBetree, 
    pathAddrs: PathAddrs, replacementAddr: Address, routeIdx: nat, ranking: Ranking)
    requires path.Valid()
    requires 0 < path.depth
    requires routeIdx == Route(path.linked.Root().pivotTable, path.key);
    requires replacement.Acyclic()
    requires path.CanSubstitute(replacement, pathAddrs)
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).Acyclic()
    // Requirements of RankingAfterSubstitution. Would be the result of some lemma such as RankingAfterInsertCompactReplacement
    requires SeqHasUniqueElems(pathAddrs)
    requires path.linked.diskView.IsFresh(Set(pathAddrs))
    requires replacement.diskView.IsFresh(Set(pathAddrs))
    requires path.linked.root.value in ranking
    requires replacement.ValidRanking(ranking)
    requires Set(pathAddrs) !! ranking.Keys

    // Induction hypothesis of ReprAfterSubstituteCompactReplacement
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).Representation()
            == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + {replacementAddr} - path.Subpath().AddrsOnPath()  
    ensures path.Subpath().linked.Acyclic()
    ensures path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).Acyclic()
    ensures path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).Representation()
      == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + {replacementAddr} - path.Subpath().AddrsOnPath()
  {
    var newRanking := LinkedBetreeRefinement.RankingAfterSubstitution(replacement, ranking, path, pathAddrs);
    LinkedBetreeRefinement.ChildAtIdxAcyclic(path.Substitute(replacement, pathAddrs), routeIdx);    
    LinkedBetreeRefinement.ChildAtIdxAcyclic(path.Substitute(replacement, pathAddrs), routeIdx);
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx), path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).TheRanking(), newRanking);
    ReachableAddrsOnSubpathRoute(path, replacement, routeIdx, pathAddrs, ranking); 
  }

  // Tony: this lemma is sprawling massive...
  lemma {:timeLimitMultiplier 2} ReprAfterSubstituteCompactReplacement(path: Path, compactedBuffers: BufferStack, replacement: LinkedBetree, replacementRanking: Ranking, pathAddrs: PathAddrs, replacementAddr: Address)
    requires path.Valid()
    requires path.Target().Root().buffers.Equivalent(compactedBuffers)
    requires path.Target().diskView.IsFresh({replacementAddr})
    requires replacement == LinkedBetreeMod.InsertCompactReplacement(path.Target(), compactedBuffers, replacementAddr)
    requires replacement.ValidRanking(replacementRanking)

    //RankingAfterSubstitution requirements
    requires path.linked.root.value in replacementRanking
    requires SeqHasUniqueElems(pathAddrs)
    requires Set(pathAddrs) !! replacementRanking.Keys
    requires path.linked.diskView.IsFresh(Set(pathAddrs))
    requires replacement.diskView.IsFresh(Set(pathAddrs))

    requires path.CanSubstitute(replacement, pathAddrs)
    ensures path.Substitute(replacement, pathAddrs).Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Acyclic()  // prereq
    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Representation()
            == path.linked.Representation() + Set(pathAddrs) + {replacementAddr} - path.AddrsOnPath()
    decreases path.depth
  {
    var ranking := LinkedBetreeRefinement.RankingAfterSubstitution(replacement, replacementRanking, path, pathAddrs);
    LinkedBetreeRefinement.BuildTightMaintainsRankingValidity(path.Substitute(replacement, pathAddrs), ranking);
    if path.depth == 0 {
      ReprAfterSubstituteCompactReplacementBaseCase(path, compactedBuffers, replacement, pathAddrs, replacementAddr, ranking);
    } else {
      ReprAfterSubstituteCompactReplacement(path.Subpath(), compactedBuffers, replacement, replacementRanking, pathAddrs[1..], replacementAddr);
      // Induction hypothesis:
      // assert path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Representation()
      //       == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + {replacementAddr} - path.Subpath().AddrsOnPath();
      var node := path.linked.Root();
      var routeIdx := Route(node.pivotTable, path.key);
      var numChildren := |path.Substitute(replacement, pathAddrs).BuildTightTree().Root().children|;
      var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => path.Substitute(replacement, pathAddrs).BuildTightTree().ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
      Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
      var tightRanking := LinkedBetreeRefinement.BuildTightRanking(path.linked, path.linked.TheRanking());
      LinkedBetreeRefinement.ValidRankingAllTheWayDown(tightRanking, path);
      var replacementRanking := 
        LinkedBetreeRefinement.RankingAfterInsertCompactReplacement(path.Target(), compactedBuffers, tightRanking, replacementAddr);
      ReprAfterSubstituteCompactReplacementInduction1(path, replacement, pathAddrs, replacementAddr, replacementRanking);
      ReprAfterSubstituteCompactReplacementInduction2(path, replacement, pathAddrs, replacementAddr, replacementRanking);
    }
  }

  // This juicy lemma requires a lot of juice
  lemma {:timeLimitMultiplier 2} ReprAfterSubstituteCompactReplacementInduction1(path: Path, replacement: LinkedBetree, 
      pathAddrs: PathAddrs, replacementAddr: Address, ranking: Ranking)
    requires path.Valid()
    requires 0 < path.depth
    requires path.Target().diskView.IsFresh({replacementAddr})
    requires SeqHasUniqueElems(pathAddrs)
    requires path.linked.diskView.IsFresh(Set(pathAddrs))
    requires replacement.diskView.IsFresh(Set(pathAddrs))
    requires path.CanSubstitute(replacement, pathAddrs)
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    requires path.Substitute(replacement, pathAddrs).BuildTightTree().Acyclic()
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Acyclic()
    // Requirements of Ranking. Would be the result of some lemma such as RankingAfterInsertCompactReplacement
    requires path.linked.root.value in ranking
    requires replacement.ValidRanking(ranking)
    requires Set(pathAddrs) !! ranking.Keys

    // Induction hypothesis
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Representation()
      == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + {replacementAddr} - path.Subpath().AddrsOnPath()
    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Representation() 
        <= path.linked.Representation() + Set(pathAddrs) + {replacementAddr} - path.AddrsOnPath()
  {
    var linkedAftSubst := path.Substitute(replacement, pathAddrs);
    forall addr | addr in linkedAftSubst.BuildTightTree().Representation() 
    ensures addr in path.linked.Representation() + Set(pathAddrs) + {replacementAddr} - path.AddrsOnPath()
    {
      RepresentationIgnoresBuildTight(linkedAftSubst);
      if addr != linkedAftSubst.root.value {
        // Here, addr is in one of the children subtrees of the new root. In this case, it
        // is either in one of the unchanged subtrees, or the one that is swapped in 
        // during substitution.
        var numChildren := |linkedAftSubst.Root().children|;
        var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => linkedAftSubst.ChildAtIdx(i).ReachableAddrsUsingRanking(linkedAftSubst.TheRanking()));
        Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
        var idx :| 0 <= idx < numChildren && addr in subTreeAddrs[idx];
        LinkedBetreeRefinement.ChildAtIdxAcyclic(linkedAftSubst, idx);
        var routeIdx := Route(path.linked.Root().pivotTable, path.key);
        if idx == routeIdx {  
          // If addr is in the subtree that is swapped in during substitution
          RepresentationIgnoresBuildTight(path.Subpath().Substitute(replacement, pathAddrs[1..]));
          SubstitutedBranchRepresentation(path, replacement, pathAddrs, replacementAddr, routeIdx, ranking);
          LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx), path.Substitute(replacement, pathAddrs).ChildAtIdx(routeIdx).TheRanking(), linkedAftSubst.TheRanking());
          RootRepresentationContainsSubpathRepresentation(path);
          assert addr !in path.AddrsOnPath() by {  // trigger
            LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linkedAftSubst.ChildAtIdx(routeIdx), linkedAftSubst.ChildAtIdx(routeIdx).TheRanking(), linkedAftSubst.TheRanking());
            AddrInSubstituteSubtreeCannotBeOldRoot(path, replacement, pathAddrs, routeIdx, addr);
            assert addr != path.linked.root.value;
          }
        } else {  
          // Else addr is in one of the original subtrees
          // First, prove that addr in path.linked.Representation();
          LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(linkedAftSubst.ChildAtIdx(idx), linkedAftSubst.ChildAtIdx(idx).TheRanking(), linkedAftSubst.TheRanking());
          ReachableAddrsNotOnSubpathRoute(path, replacement, pathAddrs, idx, ranking);
          ParentRepresentationContainsChildRepresentation(path.linked, idx);

          // Next, Prove that addr not in path.AddrsOnPath();
          AddrInChildRepresentationImpliesNotRoot(path.linked, idx, addr);
          AddrsOnPathIsRootOrInRouteSubtree(path, routeIdx);
          SubtreeRepresentationsAreDisjoint(path.linked, idx, routeIdx);
        }
      } else {
        AddrsOnPathInDiskView(path);
      }
    }
  }

  // This juicy lemma requires a lot of juice
  lemma {:timeLimitMultiplier 2} ReprAfterSubstituteCompactReplacementInduction2(path: Path, replacement: LinkedBetree, 
    pathAddrs: PathAddrs, replacementAddr: Address, ranking: Ranking)
    requires path.Valid()
    requires 0 < path.depth
    requires path.Target().diskView.IsFresh({replacementAddr})
    requires SeqHasUniqueElems(pathAddrs)
    requires path.linked.diskView.IsFresh(Set(pathAddrs))
    requires replacement.diskView.IsFresh(Set(pathAddrs))
    requires path.CanSubstitute(replacement, pathAddrs)
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    requires path.Substitute(replacement, pathAddrs).BuildTightTree().Acyclic()
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).Acyclic()
    requires replacement.Acyclic()
    requires replacementAddr in replacement.Representation()
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Acyclic()
    // Requirements of Ranking. Would be the result of some lemma such as RankingAfterInsertCompactReplacement
    requires path.linked.root.value in ranking
    requires replacement.ValidRanking(ranking)
    requires Set(pathAddrs) !! ranking.Keys

    // Induction hypothesis of ReprAfterSubstituteCompactReplacement
    requires path.Subpath().Substitute(replacement, pathAddrs[1..]).BuildTightTree().Representation()
      == path.Subpath().linked.Representation() + Set(pathAddrs[1..]) + {replacementAddr} - path.Subpath().AddrsOnPath()

    ensures path.linked.Representation() + Set(pathAddrs) + {replacementAddr} - path.AddrsOnPath()
      <= path.Substitute(replacement, pathAddrs).BuildTightTree().Representation()
  {
    forall addr | addr in path.linked.Representation() + Set(pathAddrs) + {replacementAddr} - path.AddrsOnPath()
    ensures addr in path.Substitute(replacement, pathAddrs).Representation()
    {
      if addr in Set(pathAddrs) {
        RepresentationAfterSubstituteIncludesPathAddrs(path, replacement, pathAddrs);
      } else if addr == replacementAddr {
        RepresentationAfterSubstituteIncludesReplacement(path, replacement, pathAddrs);
      } else if addr in path.linked.Representation() {
        /* This is the tricky case
        addr is not path.linked.root, because root is in path.AddrsOnPath().
        Hence, addr is in one of the children subtrees of path.linked.Root()
        If addr is not on substitution path, the addr in path.Substitute() by ReachableAddrsNotOnSubpathRoute
        Else, addr is in substitution path, and must be in path.Subpath().linked.Representation().
        Then by SubstitutedBranchRepresentation, addr is in subTreeAddrs[routeIdx] of path.Substitute().Repr().
        Then addr is in path.Substitute(..).Representation() by definition of Representation
        */
        var numChildren := |path.linked.Root().children|;
        var oldSubTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => path.linked.ChildAtIdx(i).ReachableAddrsUsingRanking(path.linked.TheRanking()));
        Sets.UnionSeqOfSetsSoundness(oldSubTreeAddrs);
        var idx :| 0 <= idx < numChildren && addr in oldSubTreeAddrs[idx];
        var routeIdx := Route(path.linked.Root().pivotTable, path.key);
        LinkedBetreeRefinement.ChildAtIdxAcyclic(path.linked, idx);
        LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(path.linked.ChildAtIdx(idx), path.linked.ChildAtIdx(idx).TheRanking(), path.linked.TheRanking());
        if idx != routeIdx {
          ReachableAddrsNotOnSubpathRoute(path, replacement, pathAddrs, idx, ranking); 
          ParentRepresentationContainsChildRepresentation(path.Substitute(replacement, pathAddrs), idx);
        } else {
          // Else addr is on substitution path
          SubpathEquivToChildAtRouteIdx(path);
          RepresentationIgnoresBuildTight(path.Subpath().Substitute(replacement, pathAddrs[1..]));
          SubstitutedBranchRepresentation(path, replacement, pathAddrs, replacementAddr, routeIdx, ranking);
          ParentRepresentationContainsChildRepresentation(path.Substitute(replacement, pathAddrs), routeIdx);
        }
      }
    }
    RepresentationIgnoresBuildTight(path.Substitute(replacement, pathAddrs));
  }

  lemma ReprAfterSubstituteCompactReplacementBaseCase(path: Path, compactedBuffers: BufferStack, replacement: LinkedBetree, pathAddrs: PathAddrs, replacementAddr: Address, ranking: Ranking)
    requires path.Valid()
    requires path.depth == 0  // base case
    requires path.Target().Root().buffers.Equivalent(compactedBuffers)
    requires path.Target().diskView.IsFresh({replacementAddr})
    requires replacement == LinkedBetreeMod.InsertCompactReplacement(path.Target(), compactedBuffers, replacementAddr)
    requires path.CanSubstitute(replacement, pathAddrs)
    requires path.linked.ValidRanking(ranking)
    requires path.Substitute(replacement, pathAddrs).Acyclic()
    requires path.Substitute(replacement, pathAddrs).ValidRanking(ranking)
    requires path.Substitute(replacement, pathAddrs).BuildTightTree().Acyclic()
    ensures path.Substitute(replacement, pathAddrs).BuildTightTree().Representation()
            == path.linked.Representation() + Set(pathAddrs) + {replacementAddr} - path.AddrsOnPath()
  {
    var numChildren := |replacement.BuildTightTree().Root().children|;
    var subTreeAddrs' := seq(numChildren, i requires 0 <= i < numChildren => replacement.BuildTightTree().ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    var subTreeAddrs := seq(numChildren, i requires 0 <= i < numChildren => path.linked.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking));
    forall i | 0 <= i < numChildren 
    ensures subTreeAddrs'[i] ==  subTreeAddrs[i] {
      LinkedBetreeRefinement.ChildAtIdxAcyclic(path.linked, i);
      LinkedBetreeRefinement.ChildAtIdxAcyclic(replacement.BuildTightTree(), i);
      ReachableAddrsInAgreeingDisks(path.linked.ChildAtIdx(i), replacement.BuildTightTree().ChildAtIdx(i), ranking);
    }
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs);
    Sets.UnionSeqOfSetsSoundness(subTreeAddrs');
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(path.linked, ranking, path.linked.TheRanking());
    LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(replacement.BuildTightTree(), ranking, replacement.BuildTightTree().TheRanking());
    assert path.Target().root.value !in path.Substitute(replacement, pathAddrs).Representation() 
    by {
      RepresentationIgnoresBuildTight(path.Substitute(replacement, pathAddrs));
      var subs := seq(numChildren, i requires 0 <= i < numChildren => replacement.ChildAtIdx(i).ReachableAddrsUsingRanking(replacement.TheRanking()));
      forall i | 0 <= i < numChildren 
      ensures path.Target().root.value !in subs[i] {
        ChildAtIdxCommutesWithBuildTight(replacement, i , ranking);
        ReachableAddrsIgnoresBuildTight(replacement.ChildAtIdx(i), ranking);
        assert subTreeAddrs'[i] == replacement.ChildAtIdx(i).ReachableAddrsUsingRanking(ranking);  // trigger
        LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(replacement.ChildAtIdx(i), ranking, replacement.TheRanking());
        assert subs[i] == subTreeAddrs[i];  // trigger
        LinkedBetreeRefinement.ChildAtIdxAcyclic(path.linked, i);
        RootAddrNotInChildRepresentation(path.linked, i);
        LinkedBetreeRefinement.ReachableAddrsIgnoresRanking(path.linked.ChildAtIdx(i), ranking, path.linked.ChildAtIdx(i).TheRanking());
      }
      Sets.UnionSeqOfSetsSoundness(subs);
      assert path.Target().root.value !in replacement.Representation();  // trigger
    }
    RepresentationIgnoresBuildTight(path.Substitute(replacement, pathAddrs));
  }

  lemma InternalCompactMaintainsRepr(v: Variables, v': Variables, lbl: TransitionLabel, step: Step)
    requires Inv(v)
    requires NextStep(v, v', lbl, step)
    requires step.InternalCompactStep?
    requires v'.betree.linked.Acyclic()
    ensures ValidRepr(v')
  {
    var linked := v.betree.linked;
    var linked' := v'.betree.linked;
    var newAddrs := Set(step.pathAddrs) + {step.targetAddr};
    var discardAddrs := step.path.AddrsOnPath();
    var replacement := LinkedBetreeMod.InsertCompactReplacement(step.path.Target(), step.compactedBuffers, step.targetAddr);
    var linkedRanking := LinkedBetreeRefinement.BuildTightRanking(linked, linked.TheRanking());
    LinkedBetreeRefinement.ValidRankingAllTheWayDown(linkedRanking, step.path);
    var replacementRanking := LinkedBetreeRefinement.RankingAfterInsertCompactReplacement(step.path.Target(), step.compactedBuffers, linkedRanking, step.targetAddr);
    if linked.HasRoot() {
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
    var untightLinked := LinkedBetreeMod.InsertCompactReplacement(step.path.Target(), step.compactedBuffers, step.targetAddr);
    if v.betree.linked.HasRoot() {
      // var newRanking := RankingAfterInsertCompactReplacement(step.path.Target(), step.compactedBuffers, linked.TheRanking(), step.targetAddr);
      // TODO
      assume untightLinked.Acyclic();
      BuildTightGivesTightWrtRepresentation(untightLinked);
      assume false;
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
        LinkedBetreeRefinement.InvNextInternalGrowStep(I(v), I(v'), lbl.I(), step.I());
        InternalGrowMaintainsRepr(v, v', lbl, step);
        assert Inv(v');
      }
      case InternalSplitStep(_, _, _, _) => {
        // TODO(tony)
        assume false;
        assert Inv(v');
      }
      case InternalFlushStep(_, _, _, _, _) => {
        // TODO(tony)
        assume false;
        assert Inv(v');
      }
      case InternalFlushMemtableStep(_) => {
        LinkedBetreeRefinement.InvNextInternalFlushMemtableStep(I(v), I(v'), lbl.I(), step.I());
        InternalFlushMemtableMaintainsRepr(v, v', lbl, step);
        InternalFlushMemtableMaintainsTightDisk(v, v', lbl, step);
        assert Inv(v');
      }
      case InternalCompactStep(_, _, _, _) => {
        LinkedBetreeRefinement.InvNextInternalCompactStep(I(v), I(v'), lbl.I(), step.I());
        InternalCompactMaintainsRepr(v, v', lbl, step);
        InternalCompactMaintainsTightDisk(v, v', lbl, step);
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
    requires LinkedBetreeRefinement.InvLinkedBetree(gcBetree.I().value)
    ensures Inv(v)
    ensures LinkedBetreeMod.Init(I(v), gcBetree.I())
  {
    InvInit(v, gcBetree);
    LinkedBetreeRefinement.InitRefines(I(v), gcBetree.I());
  }

  lemma NextRefines(v: Variables, v': Variables, lbl: TransitionLabel)
    requires Inv(v)
    requires Next(v, v', lbl)
    ensures v'.WF()
    ensures Inv(v')
    ensures LinkedBetreeMod.Next(I(v), I(v'), lbl.I())
  {
    InvNext(v, v', lbl);
    var step: Step :| NextStep(v, v', lbl, step);
    assert LinkedBetreeMod.NextStep(I(v), I(v'), lbl.I(), step.I());
  }
}
