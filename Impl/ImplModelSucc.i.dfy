include "ImplModel.i.dfy"
include "ImplModelCache.i.dfy"
include "../lib/Base/Option.s.dfy"
include "../lib/Base/Sets.i.dfy"
include "../PivotBetree/PivotBetreeSpec.i.dfy"
include "ModelBucket.i.dfy"

// See dependency graph in MainImpl.dfy

module ImplModelSucc { 
  import opened ImplModel
  import opened ImplModelIO
  import opened ImplModelCache

  import opened Options
  import opened Maps
  import opened Sets
  import opened Sequences
  import opened NativeTypes

  import opened BucketsLib
  import opened BucketWeights
  import opened Bounds
  import PivotsLib

  import opened ModelBucket
  import opened Lexicographic_Byte_Order

  import PBS = PivotBetreeSpec`Internal

  datatype PathResult =
      | Path(buckets: seq<Bucket>, upTo: Option<Key>)
      | Fetch(ref: BT.G.Reference)
      | Failure

  // TODO update lru queue when traversing

  function {:opaque} getPath(k: Constants, s: Variables, key: Key, acc: seq<Bucket>, upTo: Option<Key>, ref: BT.G.Reference, counter: uint64) : (pr : PathResult)
  requires Inv(k, s)
  requires s.Ready?
  decreases counter
  {
    if ref in s.cache then (
      var node := s.cache[ref];
      var r := Pivots.Route(node.pivotTable, key);
      var bucket := node.buckets[r];
      var acc' := acc + [bucket];
      var upTo' := 
        if r == |node.pivotTable| then (
          upTo
        ) else (
          var ub := node.pivotTable[r];
          if upTo.Some? then (
            var k: Key := if lt(upTo.value, ub) then upTo.value else ub;
            Some(k)
          ) else (
            Some(ub)
          )
        );

      if node.children.Some? then (
        if counter == 0 then (
          Failure
        ) else (
          getPath(k, s, key, acc', upTo', node.children.value[r], counter - 1)
        )
      ) else (
        Path(acc', upTo')
      )
    ) else (
      Fetch(ref)
    )
  }

  ////////////////
  //// getMinKey

  function getMinKeyIter(iters: seq<Iterator>, i: int, cur: Option<Key>) : (res : Option<Key>)
  requires 0 <= i <= |iters|
  decreases |iters| - i
  {
    if i == |iters| then (
      cur
    ) else (
      var it := iters[i];
      if it.next.Some? then (
        if cur.Some? then (
          var minK := if lt(cur.value, it.next.value.key) then Some(cur.value) else Some(it.next.value.key);
          getMinKeyIter(iters, i+1, minK)
        ) else (
          getMinKeyIter(iters, i+1, Some(it.next.value.key))
        )
      ) else (
        getMinKeyIter(iters, i+1, cur)
      )
    )
  }

  function {:opaque} getMinKey(iters: seq<Iterator>) : Option<Key>
  {
    getMinKeyIter(iters, 0, None)
  }

  ////////////////
  //// evalKeyIter

  function evalKeyIter(buckets: seq<Bucket>, iters: seq<Iterator>, key: Key, m: Message, i: int) : Message
  requires |buckets| == |iters|
  requires forall j | 0 <= j < |iters| :: WFIter(buckets[j], iters[j])
  requires 0 <= i <= |buckets|
  decreases |buckets| - i
  {
    if i == |iters| then (
      m
    ) else (
      var m' :=
        if iters[i].next.Some? && iters[i].next.value.key == key then (
          Messages.Merge(m, iters[i].next.value.msg)
        ) else (
          m
        );
      evalKeyIter(buckets, iters, key, m', i+1)
    )
  }

  function {:opaque} evalKey(buckets: seq<Bucket>, iters: seq<Iterator>, key: Key) : Message
  requires |buckets| == |iters|
  requires forall j | 0 <= j < |iters| :: WFIter(buckets[j], iters[j])
  {
    evalKeyIter(buckets, iters, key, Messages.Update(Messages.NopDelta()), 0)
  }

  ////////////////
  //// advance

  function advanceIter(buckets: seq<Bucket>, iters: seq<Iterator>, key: Key, upTo: Option<Key>, i: int, res: seq<Iterator>) : (iters' : seq<Iterator>)
  requires |buckets| == |iters|
  requires forall j | 0 <= j < |iters| :: WFIter(buckets[j], iters[j])
  requires 0 <= i <= |buckets|
  requires |res| == i
  requires forall j | 0 <= j < |res| :: WFIter(buckets[j], res[j])
  ensures |iters'| == |iters|
  ensures forall j | 0 <= j < |iters'| :: WFIter(buckets[j], iters'[j])
  decreases |buckets| - i
  {
    if i == |iters| then (
      res
    ) else (
      var newIter := 
        if iters[i].next.Some? && iters[i].next.value.key == key then (
          var next := IterInc(buckets[i], iters[i]);
          if next.next.Some? && (upTo.Some? ==> lt(next.next.value.key, upTo.value)) then (
            next
          ) else (
            IterEnd(buckets[i])
          )
        ) else (
          iters[i]
        );
      advanceIter(buckets, iters, key, upTo, i+1, res + [newIter])
    )
  }

  function {:opaque} advance(buckets: seq<Bucket>, iters: seq<Iterator>, key: Key, upTo: Option<Key>) : (iters' : seq<Iterator>)
  requires |buckets| == |iters|
  requires forall j | 0 <= j < |iters| :: WFIter(buckets[j], iters[j])
  ensures |iters'| == |iters|
  ensures forall j | 0 <= j < |iters'| :: WFIter(buckets[j], iters'[j])
  {
    advanceIter(buckets, iters, key, upTo, 0, [])
  }

  ////////////////
  //// initQueue

  function initQueueIter(buckets: seq<Bucket>, start: UI.RangeStart, i: int, acc: seq<Iterator>) : (its : seq<Iterator>)
  requires |acc| == i
  requires 0 <= i <= |buckets|
  requires forall i | 0 <= i < |acc| :: WFIter(buckets[i], acc[i])
  ensures |its| == |buckets|
  ensures forall i | 0 <= i < |its| :: WFIter(buckets[i], its[i])
  decreases |buckets| - i
  {
    if i == |buckets| then (
      acc
    ) else (
      var bucket := buckets[i];
      var it := match start {
        case SInclusive(key) => IterFindFirstGe(bucket, key)
        case SExclusive(key) => IterFindFirstGt(bucket, key)
        case NegativeInf => IterStart(bucket)
      };
      initQueueIter(buckets, start, i+1, acc + [it])
    )
  }

  function {:opaque} initQueue(buckets: seq<Bucket>, start: UI.RangeStart) : (its : seq<Iterator>)
  ensures |its| == |buckets|
  ensures forall i | 0 <= i < |its| :: WFIter(buckets[i], its[i])
  {
    initQueueIter(buckets, start, 0, [])
  }

  ////////////////
  //// collectSuccessors

  datatype SuccCollectionResult =
      SuccCollectionResult(results: seq<UI.SuccResult>, end: UI.RangeEnd)

  function collectSuccessorsIter(buckets: seq<Bucket>, iters: seq<Iterator>, upTo: Option<Key>, maxToFind: int, acc: seq<UI.SuccResult>) : SuccCollectionResult
  requires |buckets| == |iters|
  requires forall j | 0 <= j < |iters| :: WFIter(buckets[j], iters[j])
  requires |acc| <= maxToFind
  requires maxToFind >= 1

  decreases decreaserSum(iters)
  {
    if |acc| == maxToFind then (
      SuccCollectionResult(acc, UI.EInclusive(Last(acc).key))
    ) else (
      var keyOpt := getMinKey(iters);
      if keyOpt.Some? then (
        var key := keyOpt.value;
        var m := evalKey(buckets, iters, key);
        var def := Messages.Merge(m, Messages.DefineDefault()).value;
        var acc' :=
          if def == Messages.DefaultValue() then (
            acc
          ) else (
            acc + [UI.SuccResult(key, def)]
          );

        lemmaAdvanceDecreases(buckets, iters, upTo);
        var iters' := advance(buckets, iters, key, upTo);

        collectSuccessorsIter(buckets, iters', upTo, maxToFind, acc')
      ) else (
        var end := if upTo.Some? then UI.EExclusive(upTo.value) else UI.PositiveInf;
        SuccCollectionResult(acc, end)
      )
    )
  }

  function collectSuccessors(buckets: seq<Bucket>, start: UI.RangeStart, upTo: Option<Key>, maxToFind: int) : SuccCollectionResult
  requires maxToFind >= 1
  {
    var iters := initQueue(buckets, start);
    collectSuccessorsIter(buckets, iters, upTo, maxToFind, [])
  }

  ////////////////
  //// doSucc

  function doSucc(k: Constants, s: Variables, io: IO, start: UI.RangeStart, maxToFind: int)
    : (Variables, IO, Option<SuccCollectionResult>)
  requires Inv(k, s)
  requires io.IOInit?
  requires maxToFind >= 1
  {
    if (s.Unready?) then (
      var (s', io') := PageInIndirectionTableReq(k, s, io);
      (s', io', None)
    ) else (
      var startKey := if start.NegativeInf? then [] else start.key;

      lemmaGetPathValidFetch(k, s, startKey, 40);
      var pr := getPath(k, s, startKey, [], None, BT.G.Root(), 40);

      match pr {
        case Path(buckets, upTo) => (
          var res := collectSuccessors(buckets, start, upTo, maxToFind);
          (s, io, Some(res))
        )
        case Fetch(ref) => (
          var (s', io') := PageInReq(k, s, io, ref);
          (s', io', None)
        )
        case Failure => (
          (s, io, None)
        )
      }
    )
  }

  /////////////////////////////////
  /////////////////////////////////
  ///////////////////////////////// Proof stuff
  /////////////////////////////////
  /////////////////////////////////

  ////////////////
  //// some lemmas for termination

  lemma getMinKeyExistsIter(iters: seq<Iterator>, i: int, cur: Option<Key>, j0: int) returns (j : int)
  requires 0 <= i <= |iters|
  requires
      cur.Some? ==> 0 <= j0 < |iters| && iters[j0].next.Some? && iters[j0].next.value.key == cur.value
  ensures var key := getMinKeyIter(iters, i, cur);
      key.Some? ==> 0 <= j < |iters| && iters[j].next.Some? && iters[j].next.value.key == key.value
  decreases |iters| - i
  {
    if i == |iters| {
      j := j0;
    } else {
      var it := iters[i];
      if it.next.Some? {
        if cur.Some? {
          var minK := if lt(cur.value, it.next.value.key) then Some(cur.value) else Some(it.next.value.key);
          j := getMinKeyExistsIter(iters, i+1, minK, if lt(cur.value, it.next.value.key) then j0 else i);
        } else {
          j := getMinKeyExistsIter(iters, i+1, Some(it.next.value.key), i);
        }
      } else {
        j := getMinKeyExistsIter(iters, i+1, cur, j0);
      }
    }
  }

  lemma getMinKeyExists(iters: seq<Iterator>) returns (j : int)
  ensures var key := getMinKey(iters);
      key.Some? ==> 0 <= j < |iters| && iters[j].next.Some? && iters[j].next.value.key == key.value
  {
    reveal_getMinKey();
    j := getMinKeyExistsIter(iters, 0, None, 0);
  }

  lemma lemmaAdvanceDecreasesIter(buckets: seq<Bucket>, iters: seq<Iterator>, key: Key, upTo: Option<Key>, i: int, res: seq<Iterator>, j: int)
  requires advanceIter.requires(buckets, iters, key, upTo, i, res)
  requires 0 <= j < |iters| && iters[j].next.Some? && iters[j].next.value.key == key

  requires j < i ==> decreaserSum(res) < decreaserSum(iters[..i])
  requires decreaserSum(res) <= decreaserSum(iters[..i])

  ensures decreaserSum(advanceIter(buckets, iters, key, upTo, i, res))
      < decreaserSum(iters)
  decreases |buckets| - i
  {
    if i == |iters| {
      assert iters[..i] == iters;
    } else {
      //assert WFIter(buckets[i], iters[i]);

      //assert IterEnd(buckets[i]).decreaser == 0
      //    <= iters[i].decreaser;

      var newIter := 
        if iters[i].next.Some? && iters[i].next.value.key == key then (
          var next := IterInc(buckets[i], iters[i]);
          if next.next.Some? && (upTo.Some? ==> lt(next.next.value.key, upTo.value)) then (
            next
          ) else (
            IterEnd(buckets[i])
          )
        ) else (
          iters[i]
        );
      //assert newIter.decreaser <= iters[i].decreaser;
      //assert j == i ==> newIter.decreaser < iters[i].decreaser;
      assert DropLast(iters[..i+1]) == iters[..i];
      assert Last(iters[..i+1]) == iters[i];
      assert DropLast(res + [newIter]) == res;
      assert Last(res + [newIter]) == newIter;
      lemmaAdvanceDecreasesIter(buckets, iters, key, upTo, i+1, res + [newIter], j);
    }
  }

  lemma lemmaAdvanceDecreases(buckets: seq<Bucket>, iters: seq<Iterator>, upTo: Option<Key>)
  requires |buckets| == |iters|
  requires forall j | 0 <= j < |iters| :: WFIter(buckets[j], iters[j])
  requires getMinKey(iters).Some?
  ensures decreaserSum(advance(buckets, iters, getMinKey(iters).value, upTo))
      < decreaserSum(iters)
  {
    reveal_advance();
    var j := getMinKeyExists(iters);
    lemmaAdvanceDecreasesIter(buckets, iters, getMinKey(iters).value, upTo, 0, [], j);
  }

  ////////////////
  //// some more lemmas

  predicate LookupBucketsProps(lookup: PBS.Lookup, buckets: seq<Bucket>, upTo: Option<Key>, startKey: Key)
  {
    && PBS.WFLookupForKey(lookup, startKey)
    && upTo == PBS.LookupUpperBound(lookup, startKey)
    && Last(lookup).node.children.None?
    && |lookup| == |buckets|
    && (forall i | 0 <= i < |lookup| :: buckets[i] == lookup[i].node.buckets[Pivots.Route(lookup[i].node.pivotTable, startKey)])
  }

  lemma lemmaGetPathResult(k: Constants, s: Variables, startKey: Key, acc: seq<Bucket>, lookup: PBS.Lookup, upTo: Option<Key>, ref: BT.G.Reference, counter: uint64)
  returns (lookup' : PBS.Lookup)
  requires Inv(k, s)
  requires s.Ready?
  requires ref in s.ephemeralIndirectionTable.graph
  requires |lookup| > 0 ==> PBS.WFLookupForKey(lookup, startKey)
  requires |lookup| > 0 ==> Last(lookup).node.children.Some?
  requires |lookup| > 0 ==> ref == Last(lookup).node.children.value[Pivots.Route(Last(lookup).node.pivotTable, startKey)]
  requires |lookup| == 0 ==> ref == BT.G.Root()
  requires upTo == PBS.LookupUpperBound(lookup, startKey)
  requires |lookup| == |acc|
  requires forall i | 0 <= i < |lookup| :: acc[i] == lookup[i].node.buckets[Pivots.Route(lookup[i].node.pivotTable, startKey)]
  requires forall i | 0 <= i < |lookup| :: lookup[i].ref in s.cache && lookup[i].node == INode(s.cache[lookup[i].ref])
  decreases counter
  ensures var pr := getPath(k, s, startKey, acc, upTo, ref, counter);
      && (pr.Fetch? ==> pr.ref in s.ephemeralIndirectionTable.locs)
      && (pr.Path? ==> LookupBucketsProps(lookup', pr.buckets, pr.upTo, startKey))
  {
    reveal_getPath();

    if ref in s.cache {
      var node := s.cache[ref];
      var r := Pivots.Route(node.pivotTable, startKey);
      var bucket := node.buckets[r];
      var acc1 := acc + [bucket];
      var lookup1 := lookup + [BT.G.ReadOp(ref, INode(node))];

      forall idx | PBS.ValidLayerIndex(lookup1, idx) && idx < |lookup1| - 1
      ensures PBS.LookupFollowsChildRefAtLayer(startKey, lookup1, idx)
      {
        if idx == |lookup1| - 2 {
          assert PBS.LookupFollowsChildRefAtLayer(startKey, lookup1, idx);
        } else {
          assert PBS.LookupFollowsChildRefAtLayer(startKey, lookup, idx);
          assert PBS.LookupFollowsChildRefAtLayer(startKey, lookup1, idx);
        }
      }

      var upTo' := 
        if r == |node.pivotTable| then (
          upTo
        ) else (
          var ub := node.pivotTable[r];
          if upTo.Some? then (
            var k: Key := if lt(upTo.value, ub) then upTo.value else ub;
            Some(k)
          ) else (
            Some(ub)
          )
        );

      PBS.reveal_LookupUpperBound();

      if node.children.Some? {
        if counter == 0 {
        } else {
          lemmaChildInGraph(k, s, ref, node.children.value[r]);

          lookup' := lemmaGetPathResult(k, s, startKey, acc1, lookup1, upTo', node.children.value[r], counter - 1);
        }
      } else {
        lookup' := lookup1;
      }
    } else {
    }
  }

  lemma lemmaGetPathValidFetch(k: Constants, s: Variables, startKey: Key, counter: uint64)
  requires Inv(k, s)
  requires s.Ready?
  decreases counter
  ensures var pr := getPath(k, s, startKey, [], None, BT.G.Root(), counter);
      && (pr.Fetch? ==> pr.ref in s.ephemeralIndirectionTable.locs)
  {
    PBS.reveal_LookupUpperBound();
    var _ := lemmaGetPathResult(k, s, startKey, [], [], None, BT.G.Root(), counter);
  }
}
