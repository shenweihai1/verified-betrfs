include "ImplModelCache.i.dfy"
include "ImplModelIO.i.dfy"
include "ImplModelFlushRootBucket.i.dfy"
include "AsyncDiskModel.s.dfy"

module ImplModelFlush { 
  import opened ImplModel
  import opened ImplModelIO
  import opened ImplModelCache
  import opened ImplModelFlushRootBucket

  import opened Options
  import opened Maps
  import opened Sequences
  import opened Sets

  import opened BucketsLib
  import opened BucketWeights
  import opened Bounds

  import opened NativeTypes
  import D = AsyncDisk

  function flush(k: Constants, s: Variables, io: IO, parentref: BT.G.Reference, slot: int, childref: BT.G.Reference, child: Node)
  : (Variables, IO)
  requires Inv(k, s)
  requires io.IOInit?
  requires s.Ready?

  requires parentref in s.ephemeralIndirectionTable
  requires parentref in s.cache

  requires s.cache[parentref].children.Some?
  requires 0 <= slot < |s.cache[parentref].buckets|
  requires s.cache[parentref].children.value[slot] == childref

  requires childref in s.ephemeralIndirectionTable
  requires childref in s.cache
  requires s.cache[childref] == child
  {
    if (
      && s.frozenIndirectionTable.Some?
      && parentref in s.frozenIndirectionTable.value
      && var entry := s.frozenIndirectionTable.value[parentref];
      && var (loc, _) := entry;
      && loc.None?
    ) then (
      (s, io)
    ) else (
      var s1 := if parentref == BT.G.Root() then (
        flushRootBucketCorrect(k, s);
        flushRootBucket(k, s)
      ) else (
        s
      );

      var parent := s1.cache[parentref];

      var newbuckets := KMTable.flush(parent.buckets[slot], child.buckets, child.pivotTable);
      var newchild := child.(buckets := newbuckets);
      var (s2, newchildref) := alloc(k, s1, newchild);
      if newchildref.None? then (
        (s2, io)
      ) else (
        var newparent := Node(
          parent.pivotTable,
          Some(parent.children.value[slot := newchildref.value]),
          parent.buckets[slot := KMTable.Empty()]
        );
        var s' := write(k, s2, parentref, newparent);
        (s', io)
      )
    )
  }

  lemma flushCorrect(k: Constants, s: Variables, io: IO, parentref: BT.G.Reference, slot: int, childref: BT.G.Reference, child: Node)
  requires flush.requires(k, s, io, parentref, slot, childref, child)
  requires WeightBucketList(KMTable.ISeq(child.buckets)) +
      WeightBucket(KMTable.I(s.cache[parentref].buckets[slot])) <= MaxTotalBucketWeight()
  requires parentref == BT.G.Root() ==>
      WeightBucket(s.rootBucket) +
      WeightBucketList(KMTable.ISeq(child.buckets)) +
      WeightBucket(KMTable.I(s.cache[parentref].buckets[slot])) <= MaxTotalBucketWeight()
  ensures
      var (s', io') := flush(k, s, io, parentref, slot, childref, child);
      && WFVars(s')
      && M.Next(Ik(k), I(k, s), I(k, s'), UI.NoOp, diskOp(io'))
  {
    if (
      && s.frozenIndirectionTable.Some?
      && parentref in s.frozenIndirectionTable.value
      && var entry := s.frozenIndirectionTable.value[parentref];
      && var (loc, _) := entry;
      && loc.None?
    ) {
      assert noop(k, IVars(s), IVars(s));
    } else {
      var s1 := if parentref == BT.G.Root() then flushRootBucket(k, s) else s;
      if parentref == BT.G.Root() {
        flushRootBucketWeight(k, s, slot);
        flushRootBucketFrozen(k, s);
      }
      var parent := s1.cache[parentref];

      INodeRootEqINodeForEmptyRootBucket(parent);
      INodeRootEqINodeForEmptyRootBucket(child);

      var newbuckets := KMTable.flush(parent.buckets[slot], child.buckets, child.pivotTable);
      KMTable.flushRes(parent.buckets[slot], child.buckets, child.pivotTable);
      assume WFBuckets(newbuckets); // at the moment, only the KMTable.Flush method proves this.
      WFBucketListFlush(KMTable.I(parent.buckets[slot]), KMTable.ISeq(child.buckets), child.pivotTable);

      // TODO these are actually kind of annoying right now
      assume childref in s1.cache;
      assume childref in s1.ephemeralIndirectionTable;
      assume child == s1.cache[childref];
      assume childref != BT.G.Root();

      assert parentref in s1.cache;
      assert parentref in s1.ephemeralIndirectionTable;
      assert parent == s1.cache[parentref];

      assert INodeForRef(s1.cache, childref, s1.rootBucket) == INode(child);
      assert INodeForRef(s1.cache, parentref, s1.rootBucket) == INode(parent);
      
      var newchild := child.(buckets := newbuckets);
      var (s2, newchildref) := alloc(k, s1, newchild);
      reveal_alloc();
      if newchildref.None? {
        assert noop(k, IVars(s), IVars(s2));
      } else {
        var newparent := Node(
          parent.pivotTable,
          Some(parent.children.value[slot := newchildref.value]),
          parent.buckets[slot := KMTable.Empty()]
        );
        INodeRootEqINodeForEmptyRootBucket(newparent);

        var s' := write(k, s2, parentref, newparent);
        reveal_write();

        forall ref | ref in BT.G.Successors(INode(newparent)) ensures ref in IIndirectionTable(s2.ephemeralIndirectionTable).graph {
          if (ref == newchildref.value) {
          } else {
            assert ref in BT.G.Successors(INode(parent));
            lemmaChildInGraph(k, s, parentref, ref);
            assert ref in IIndirectionTable(s2.ephemeralIndirectionTable).graph;
          }
        }
        assert BC.BlockPointsToValidReferences(INode(newparent), IIndirectionTable(s2.ephemeralIndirectionTable).graph);

        forall ref | ref in BT.G.Successors(INode(newchild)) ensures ref in IIndirectionTable(s.ephemeralIndirectionTable).graph {
          lemmaChildInGraph(k, s, childref, ref);
        }

        WeightBucketListFlush(KMTable.I(parent.buckets[slot]), KMTable.ISeq(child.buckets), child.pivotTable);
        WeightBucketListClearEntry(KMTable.ISeq(parent.buckets), slot);

        assume KMTable.ISeq(parent.buckets[slot := KMTable.Empty()])
            == KMTable.ISeq(parent.buckets)[slot := map[]];

        allocCorrect(k, s1, newchild);
        writeCorrect(k, s2, parentref, newparent);

        var flushStep := BT.NodeFlush(parentref, INode(parent), childref, INode(child), newchildref.value, INode(newchild), slot);
        assert BT.ValidFlush(flushStep);
        var step := BT.BetreeFlush(flushStep);
        assert INode(newparent) == BT.FlushOps(flushStep)[1].node;
        assert BC.Alloc(Ik(k), IVars(s1), IVars(s2), newchildref.value, INode(newchild));
        assert BC.Dirty(Ik(k), IVars(s2), IVars(s'), parentref, INode(newparent));
        BC.MakeTransaction2(Ik(k), IVars(s1), IVars(s2), IVars(s'), BT.BetreeStepOps(step));
        assert BBC.BetreeMove(Ik(k), IVars(s1), IVars(s'), UI.NoOp, M.IDiskOp(D.NoDiskOp), step);
        assert stepsBetree(k, IVars(s1), IVars(s'), UI.NoOp, step);
        assert stepsBetree(k, IVars(s), IVars(s'), UI.NoOp, step);
      }
    }
  }
}
