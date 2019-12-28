include "MutableBtree.i.dfy"
  include "../Base/mathematics.i.dfy"
  
abstract module MutableBtreeBulkOperations {
  import opened NativeTypes
  import opened NativeArrays
  import opened Sequences
  import opened MB : MutableBtree`All
  import Mathematics
  
  method NumElements(node: Node) returns (count: uint64)
    requires WFShape(node)
    requires Spec.WF(I(node))
    requires Spec.NumElements(I(node)) < Uint64UpperBound()
    ensures count as nat == Spec.NumElements(I(node))
    decreases node.height
  {
    reveal_I();
    if node.contents.Leaf? {
      count := node.contents.nkeys;
    } else {
      ghost var inode := I(node);
      count := 0;
      ghost var icount: int := 0;
      
      var i: uint64 := 0;
      while i < node.contents.nchildren
        invariant i <= node.contents.nchildren
        invariant icount == Spec.NumElementsOfChildren(inode.children[..i])
        invariant icount < Uint64UpperBound()
        invariant count == icount as uint64
      {
        ghost var ichildcount := Spec.NumElements(inode.children[i]);
        assert inode.children[..i+1][..i] == inode.children[..i];
        Spec.NumElementsOfChildrenNotZero(inode);
        Spec.NumElementsOfChildrenDecreases(inode.children, (i+1) as int);
        icount := icount + ichildcount;

        IOfChild(node, i as int);
        var childcount: uint64 := NumElements(node.contents.children[i]);
        count := count + childcount;
        i := i + 1;
      }
      assert inode.children[..node.contents.nchildren] == inode.children;
    }
  }

  method ToSeqSubtree(node: Node, keys: array<Key>, values: array<Value>, start: uint64) returns (nextstart: uint64)
    requires WF(node)
    requires !Arrays.Aliases(keys, values)
    requires keys.Length == values.Length
    requires keys !in node.repr
    requires values !in node.repr
    requires start as nat + Spec.NumElements(I(node)) <= keys.Length
    requires start as nat + Spec.NumElements(I(node)) < Uint64UpperBound()
    ensures nextstart as nat == start as nat + Spec.NumElements(I(node))
    ensures keys[..start] == old(keys[..start])
    ensures keys[start..nextstart] == Spec.ToSeq(I(node)).0
    ensures keys[nextstart..] == old(keys[nextstart..]);
    ensures values[..start] == old(values[..start]);
    ensures values[start..nextstart] == Spec.ToSeq(I(node)).1
    ensures values[nextstart..] == old(values[nextstart..])
    modifies keys, values
    decreases node.height
  {
    if node.contents.Leaf? {
      Arrays.Memcpy(keys, start, node.contents.keys[..node.contents.nkeys]); // FIXME: remove conversion to seq
      Arrays.Memcpy(values, start, node.contents.values[..node.contents.nkeys]); // FIXME: remove conversion to seq
      nextstart := start + node.contents.nkeys;
      forall
        ensures keys[start..nextstart] == Spec.ToSeq(I(node)).0
        ensures values[start..nextstart] == Spec.ToSeq(I(node)).1
      {
        reveal_I();
        Spec.reveal_ToSeq();
      }
    } else {
      nextstart := start;
      var i: uint64 := 0;
      while i < node.contents.nchildren
        invariant 0 <= i <= node.contents.nchildren
        invariant nextstart as nat == start as nat + Spec.NumElementsOfChildren(I(node).children[..i])
        invariant nextstart as nat <= keys.Length
        invariant keys[..start] == old(keys[..start])
        invariant keys[start..nextstart] == Spec.Seq.Flatten(Spec.ToSeqChildren(I(node).children[..i]).0)
        invariant keys[nextstart..] == old(keys[nextstart..]);
        invariant values[..start] == old(values[..start]);
        invariant values[start..nextstart] == Spec.Seq.Flatten(Spec.ToSeqChildren(I(node).children[..i]).1)
        invariant values[nextstart..] == old(values[nextstart..])
      {
        assert WFShapeChildren(node.contents.children[..node.contents.nchildren], node.repr, node.height);
        assert I(node).children[..i+1][..i] == I(node).children[..i];
        Spec.NumElementsOfChildrenDecreases(I(node).children, (i + 1) as int);
        Spec.ToSeqChildrenDecomposition(I(node).children[..i+1]);
        IOfChild(node, i as int);

        nextstart := ToSeqSubtree(node.contents.children[i], keys, values, nextstart);
        i := i + 1;
        Spec.reveal_ToSeq();
      }
      assert I(node).children[..node.contents.nchildren] == I(node).children;
      Spec.reveal_ToSeq();
    }
  }

  method ToSeq(node: Node) returns (kvlists: (array<Key>, array<Value>))
    requires WFShape(node)
    requires Spec.WF(I(node))
    requires Spec.NumElements(I(node)) < Uint64UpperBound()
    ensures (kvlists.0[..], kvlists.1[..]) == Spec.ToSeq(I(node))
    ensures fresh(kvlists.0)
    ensures fresh(kvlists.1)
  {
    var count := NumElements(node);
    var keys := newArrayFill(count, DefaultKey());
    var values := newArrayFill(count, DefaultValue());
    var end := ToSeqSubtree(node, keys, values, 0);
    assert keys[..] == keys[0..end];
    assert values[..] == values[0..end];
    return (keys, values);
  }

  function method DivCeilUint64(x: uint64, d: uint64) : (y: uint64)
    requires 0 < d
    requires x as int + d as int < Uint64UpperBound()
    ensures d as int *(y as int - 1) < x as int <= d as int * y as int
  {
    (x + d - 1) / d
  }

  lemma PosMulPosIsPos(x: int, y: int)
    requires 0 < x
    requires 0 < y
    ensures 0 < x * y
  {
  }
  
  lemma DivCeilLT(x: int, d: int)
    requires 1 < d
    requires 1 < x
    ensures (x + d - 1) / d < x
  {
    PosMulPosIsPos(d-1, x-1);
  }

  lemma PosMulPreservesOrder(x: nat, y: nat, m: nat)
    requires x <= y
    ensures x * m <= y * m
  {
  }

  // lemma WFShapeChildrenExtend(children: seq<Node?>, parentHeight: int, child: Node)
  //   requires forall i :: 0 <= i < |children| ==> children[i] != null
  //   requires MB.WFShapeChildren(children, MB.SeqRepr(children), parentHeight)
  //   requires MB.WFShape(child)
  //   requires child.height < parentHeight
  //   requires forall i :: 0 <= i < |children| ==> children[i].repr !! child.repr
  //   ensures MB.WFShapeChildren(children + [child], MB.SeqRepr(children + [child]), parentHeight)
  // {
  //   assume false;
  // }
  
  // lemma LeavesMatchBoundariesExtension(keys: seq<Key>, values: seq<Value>, boundaries: seq<nat>, leaves: seq<Spec.Node>, leaf: Spec.Node)
  //   requires |keys| == |values|
  //   requires leaf.Leaf?
  //   requires Spec.ValidBoundariesForKeys(|keys|, boundaries)
  //   requires Spec.LeavesMatchBoundaries(keys, values, boundaries, leaves)
  //   ensures Spec.ValidBoundariesForKeys(|keys| + |leaf.keys|, boundaries + [Last(boundaries) + |leaf.keys|])
  //   ensures Spec.LeavesMatchBoundaries(keys + leaf.keys, values + leaf.values, boundaries + [Last(boundaries) + |leaf.keys|], leaves + [leaf])
  // {
  //   assume false;
  // }
  
  method FromSeqLeaves(keys: seq<Key>, values: seq<Value>) returns (leaves: array<Node?>, ghost boundaries: seq<nat>)
    requires 0 < |keys| == |values| < Uint64UpperBound() / 2
    ensures leaves.Length <= |keys|
    ensures fresh(leaves)
    ensures forall i :: 0 <= i < leaves.Length ==> leaves[i] != null
    ensures forall i :: 0 <= i < leaves.Length ==> fresh(leaves[i].repr)
    ensures forall i :: 0 <= i < leaves.Length ==> leaves !in leaves[i].repr
    ensures WFShapeChildren(leaves[..], MB.SeqRepr(leaves[..]), 1)
    ensures forall i :: 0 <= i < leaves.Length ==> MB.WFShape(leaves[i])
    ensures forall i :: 0 <= i < leaves.Length ==> leaves[i].contents.Leaf?
    ensures Spec.ValidBoundariesForKeys(|keys|, boundaries)
    ensures |boundaries| == leaves.Length + 1
    ensures forall i :: 0 <= i < leaves.Length ==> Spec.LeafMatchesBoundary(keys, values, boundaries, I(leaves[i]), i)
  {
    var keysperleaf: uint64 := 3 * MB.MaxKeysPerLeaf() / 4;
    var numleaves: uint64 := DivCeilUint64(|keys| as uint64, keysperleaf);
    if |keys| == 1 {
    } else {
      DivCeilLT(|keys|, keysperleaf as int);
    }
    
    leaves := newArrayFill(numleaves, null);
    
    boundaries := seq(numleaves, i => i * keysperleaf as int) + [|keys|];
    Spec.RegularBoundaryIsValid(|keys|, keysperleaf as int);

    var leafidx: uint64 := 0;
    var keyidx: uint64 := 0;
    while leafidx < numleaves-1
      invariant leafidx <= numleaves-1
      invariant keyidx == leafidx * keysperleaf
      invariant keyidx < |keys| as uint64
      invariant fresh(leaves)
      invariant forall i :: 0 <= i < leafidx ==> leaves[i] != null
      invariant forall i :: 0 <= i < leafidx ==> fresh(leaves[i].repr)
      invariant forall i :: 0 <= i < leafidx ==> leaves !in leaves[i].repr
      invariant forall i :: 0 <= i < leafidx ==> leaves[i].contents.Leaf?
      invariant WFShapeChildren(leaves[..leafidx], SeqRepr(leaves[..leafidx]), 1)
      invariant forall i :: 0 <= i < leafidx ==> Spec.LeafMatchesBoundary(keys, values, boundaries, I(leaves[i]), i as nat)
    {
      assert (leafidx + 1) as nat <= (numleaves - 1) as nat;
      PosMulPreservesOrder((leafidx + 1) as nat, (numleaves - 1) as nat, keysperleaf as nat);
      calc <= {
        keyidx as nat + keysperleaf as nat;
        (leafidx + 1) as nat * keysperleaf as nat;
        (numleaves - 1) as nat * keysperleaf as nat;
        |keys|;
      }
      var nextkeyidx := keyidx + keysperleaf;
      calc {
        nextkeyidx;
        keyidx + keysperleaf;
        leafidx * keysperleaf + keysperleaf;
        (leafidx+1) * keysperleaf;
      }
      leaves[leafidx] := LeafFromSeqs(keys[keyidx..nextkeyidx], values[keyidx..nextkeyidx]);

      leafidx := leafidx + 1;
      keyidx := nextkeyidx;
    }
    if |keys| == 1 {
      assert |keys[keyidx..]| as uint64 < keysperleaf;
    } else {
      calc <= {
        |keys[keyidx..]|;
        |keys| - keyidx as int;
        |keys| - leafidx as int * keysperleaf as int;
        |keys| - (numleaves-1) as int * keysperleaf as int;
        |keys| - numleaves as int * keysperleaf as int + keysperleaf as int;
        |keys| - |keys| + keysperleaf as int;
        keysperleaf as int;
      }
      assert |keys[keyidx..]| as uint64 <= keysperleaf;
    }
    leaves[leafidx] := LeafFromSeqs(keys[keyidx..|keys|], values[keyidx..|keys|]);
    assert keyidx == boundaries[leafidx] as uint64;
    assert |keys| == boundaries[leafidx+1];
    assert Spec.LeafMatchesBoundary(keys, values, boundaries, I(leaves[leafidx]), leafidx as nat);
    
    assert leaves[..leafidx+1] == leaves[..];
  }

  function MaxHeight(nodes: seq<Node>) : int
    ensures forall i :: 0 <= i < |nodes| ==> nodes[i].height <= MaxHeight(nodes)
    reads Set(nodes)
  {
    if |nodes| == 0 then 0
    else
      var h1 := MaxHeight(DropLast(nodes));
      var h2 := Last(nodes).height;
      Mathematics.max(h1, h2)
  }
  
  method IndexFromChildren(pivots: seq<Key>, children: seq<Node>) returns (node: Node)
    requires 0 < |children| <= MB.MaxChildren() as int
    requires |pivots| == |children|-1
    ensures WFShape(node)
    ensures node.contents.Index?
    ensures node.contents.nchildren == |children| as uint64
    ensures node.contents.pivots[..node.contents.nchildren-1] == pivots
    ensures node.contents.children[..node.contents.nchildren] == children
    ensures fresh(node)
    ensures fresh(node.contents.pivots)
    ensures fresh(node.contents.children)
    ensures node.repr == {node, node.contents.pivots, node.contents.children} + MB.SeqRepr(children)
  {
    var pivotarray := newArrayFill(MB.MaxChildren()-1, MB.DefaultKey());
    var childarray := newArrayFill(MB.MaxChildren(), null);
    Arrays.Memcpy(pivotarray, 0, pivots);
    Arrays.Memcpy(childarray, 0, children);
    node := new Node;
    node.contents := MB.Index(|children| as uint64, pivotarray, childarray);
    node.repr := {node, node.contents.pivots, node.contents.children} + MB.SeqRepr(children);
    node.height := MaxHeight(children) + 1;
  }

  method FromSeqIndexLayer(pivots: seq<Key>, children: seq<Node>) returns (newpivots: array<Key>, parents: array<Node?>)
    requires 1 < |children| < Uint64UpperBound() / 2
    requires |children| == |pivots| + 1
    ensures parents.Length == newpivots.Length + 1
    ensures parents.Length < |children|
    ensures forall i :: 0 <= i < parents.Length ==> parents[i] != null
  {
    var childrenperparent: uint64 := 3 * MB.MaxChildren() / 4;
    var numparents: uint64 := DivCeilUint64(|children| as uint64, childrenperparent); //(|children| as uint64 + childrenperparent - 1) / childrenperparent;
    DivCeilLT(|children|, childrenperparent as int);
    assert numparents as int < |children|;

    newpivots := newArrayFill(numparents-1, DefaultKey());
    parents := newArrayFill(numparents, null);

    var i: uint64 := 0;
    while i < numparents - 1
      invariant i <= numparents - 1
    {
      calc <= {
        (i+1) * childrenperparent - 1;
        (numparents - 1) * childrenperparent - 1;
        |children| as uint64 - 2;
        |pivots| as uint64 - 1;
      }
      assert (i+1) * childrenperparent <= |children| as uint64;
      
      var parentpivots   :=   pivots[i * childrenperparent..(i+1) * childrenperparent - 1];
      var parentchildren := children[i * childrenperparent..(i+1) * childrenperparent];
      parents[i] := IndexFromChildren(parentpivots, parentchildren);
      assert 0 <=  (i+1) * childrenperparent - 1;
      newpivots[i] := pivots[(i+1) * childrenperparent - 1];
      i := i + 1;
    }
    var parentpivots   :=   pivots[i * childrenperparent..];
    var parentchildren := children[i * childrenperparent..];
    parents[i] := IndexFromChildren(parentpivots, parentchildren);
  }

  // method FromSeq(keys: seq<Key>, values: seq<Value>) returns (node: Node)
  //   requires 0 < |keys| == |values| < Uint64UpperBound() / 2
  // {
  //   var nodes: array<Node?>, boundaries, inodes := FromSeqLeaves(keys, values);
  //   while 1 < nodes.Length
  //     invariant nodes.Length < Uint64UpperBound() / 2
  //     invariant forall i :: 0 <= i < nodes.Length ==> nodes[i] != null
  //     invariant nodes.Length == pivots.Length + 1
  //   {
  //     pivots, nodes := FromSeqIndexLayer(pivots[..], nodes[..]);
  //   }
  //   node := nodes[0];
  // }
  
  // method SplitLeafOfIndexAtKey(node: Node, childidx: uint64, pivot: Key, nleft: uint64)  returns (ghost wit: Key)
  //   requires WFShape(node)
  //   requires Spec.WF(I(node))
  //   requires node.contents.Index?
  //   requires !Full(node)
  //   requires 0 <= childidx < node.contents.nchildren
  //   requires node.contents.children[childidx].contents.Leaf?
  //   requires WFShape(node.contents.children[childidx])
  //   requires Spec.Keys.lt(node.contents.children[childidx].contents.keys[0], pivot)
  //   requires Spec.Keys.lte(pivot, node.contents.children[childidx].contents.keys[node.contents.children[childidx].contents.nkeys-1])
  //   requires Spec.Keys.IsSorted(node.contents.children[childidx].contents.keys[..node.contents.children[childidx].contents.nkeys])
  //   requires nleft as int == Spec.Keys.LargestLt(node.contents.children[childidx].contents.keys[..node.contents.children[childidx].contents.nkeys], pivot) + 1
  //   ensures WFShape(node)
  //   ensures node.contents.Index?
  //   ensures fresh(node.repr - old(node.repr))
  //   ensures node.height == old(node.height)
  //   ensures Spec.SplitChildOfIndex(old(I(node)), I(node), childidx as int, wit)
  //   ensures !Full(node.contents.children[childidx])
  //   ensures !Full(node.contents.children[childidx+1])
  //   ensures node.contents.pivots[childidx] == pivot
  //   modifies node, node.contents.pivots, node.contents.children, node.contents.children[childidx]
  // {
  //   ChildrenAreDistinct(node);
    
  //   ghost var ioldnode := I(node);
  //   var child := node.contents.children[childidx];
  //   //assert 0 < nleft;
  //   var right, wit' := SplitLeaf(node.contents.children[childidx], nleft, pivot);
  //   ghost var ileft := I(node.contents.children[childidx]);
  //   ghost var iright := I(right);

  //   Arrays.Insert(node.contents.pivots, node.contents.nchildren-1, pivot, childidx);
  //   Arrays.Insert(node.contents.children, node.contents.nchildren, right, childidx + 1);
  //   node.contents := node.contents.(nchildren := node.contents.nchildren + 1);
  //   node.repr := node.repr + right.repr;
  //   wit := wit';

  //   forall i | 0 <= i < node.contents.nchildren
  //     ensures node.contents.children[i] != null
  //     ensures node.contents.children[i] in node.repr
  //     ensures node.contents.children[i].repr < node.repr
  //     ensures node !in node.contents.children[i].repr
  //     ensures node.contents.pivots !in node.contents.children[i].repr
  //     ensures node.contents.children !in node.contents.children[i].repr
  //     ensures node.contents.children[i].height < node.height
  //     ensures WFShape(node.contents.children[i])
  //   {
  //     if i < childidx {
  //       assert old(DisjointSubtrees(node.contents, i as int, childidx as int));
  //     } else if i == childidx {
  //     } else if i == childidx + 1 {
  //     } else {
  //       assert node.contents.children[i] == old(node.contents.children[i-1]);
  //       assert old(DisjointSubtrees(node.contents, childidx as int, (i-1) as int));
  //     }
  //   }

  //   forall i: uint64, j: uint64 | 0 <= i < j < node.contents.nchildren
  //     ensures DisjointSubtrees(node.contents, i as int, j as int)
  //   {
  //     if                           j <  childidx       {
  //       assert old(DisjointSubtrees(node.contents, i as int, j as int));
  //     } else if                    j == childidx       {
  //       assert old(DisjointSubtrees(node.contents, i as int, j as int));
  //     } else if i < childidx     && j == childidx+1     {
  //       assert old(DisjointSubtrees(node.contents, i as int, j as int - 1));
  //     } else if i == childidx    && j == childidx+1     {
  //       assert node.contents.children[childidx+1] == right;
  //       //assert node.contents.children[childidx].repr !! right.repr;
  //       assert DisjointSubtrees(node.contents, childidx as int, (childidx + 1) as int);
  //     } else if i < childidx     &&      childidx+1 < j {
  //       assert node.contents.children[j] == old(node.contents.children[j-1]);
  //       assert old(DisjointSubtrees(node.contents, i as int, (j-1) as int));
  //     } else if i == childidx    &&      childidx+1 < j {
  //       assert node.contents.children[j] == old(node.contents.children[j-1]);
  //       assert old(DisjointSubtrees(node.contents, i as int, (j-1) as int));
  //     } else if i == childidx+1  &&      childidx+1 < j {
  //       assert node.contents.children[j] == old(node.contents.children[j-1]);
  //       assert old(DisjointSubtrees(node.contents, (i-1) as int, (j-1) as int));
  //     } else {
  //       assert node.contents.children[i] == old(node.contents.children[i-1]);
  //       assert node.contents.children[j] == old(node.contents.children[j-1]);
  //       assert old(DisjointSubtrees(node.contents, (i-1) as int, (j-1) as int));
  //     }
  //   }
      
  //   ghost var inode := I(node);

  //   ghost var target := Seq.replace1with2(ioldnode.children, inode.children[childidx], iright, childidx as int);
  //   forall i | 0 <= i < |inode.children|
  //     ensures inode.children[i] == target[i]
  //   {
  //     if i < childidx as int {
  //       assert old(DisjointSubtrees(node.contents, i as int, childidx as int));
  //       assert inode.children[i] == ioldnode.children[i] == target[i];
  //     } else if i == childidx as int {
  //       assert inode.children[i] == ileft == target[i];
  //     } else if i == (childidx + 1) as int {
  //       assert inode.children[i] == iright == target[i];
  //     } else {
  //       assert old(DisjointSubtrees(node.contents, childidx as int, (i-1) as int));      
  //       assert inode.children[i] == ioldnode.children[i-1] == target[i];
  //     }
  //   }
  //   assert inode.children == Seq.replace1with2(ioldnode.children, inode.children[childidx], iright, childidx as int);
  // }


  // method EnsurePivotNotFullParentOfLeaf(node: Node, pivot: Key, childidx: uint64) returns (pos: int64)
  //   requires WFShape(node)
  //   requires Spec.WF(I(node))
  //   requires Spec.NumElements(I(node)) < Uint64UpperBound()
  //   requires node.contents.Index?
  //   requires !Full(node)
  //   requires childidx as int == Spec.Keys.LargestLte(node.contents.pivots[..node.contents.nchildren-1], pivot) + 1
  //   requires node.contents.children[childidx].contents.Leaf?
  //   ensures WFShape(node)
  //   ensures Spec.WF(I(node))
  //   ensures node.contents.Index?
  //   ensures node.height == old(node.height)
  //   ensures fresh(node.repr - old(node.repr))
  //   ensures -1 <= pos as int < node.contents.nchildren as int
  //   ensures 0 <= pos as int < node.contents.nchildren as int - 1 ==> node.contents.pivots[pos] == pivot
  //   ensures Spec.Interpretation(I(node)) == Spec.Interpretation(old(I(node)))
  //   ensures Spec.AllKeys(I(node)) <= Spec.AllKeys(old(I(node))) + {pivot}
  //   modifies node, node.contents.pivots, node.contents.children, node.contents.children[childidx]
  // {
  //   var child := node.contents.children[childidx];
  //   assert child.contents.keys[0..child.contents.nkeys] == child.contents.keys[..child.contents.nkeys];
  //   var nleft := Spec.Keys.ArrayLargestLtPlus1(child.contents.keys, 0, child.contents.nkeys, pivot);

  //   if 0 == nleft {
  //     if 0 < childidx {
  //       node.contents.pivots[childidx-1] := pivot;
  //       assert I(node) == Spec.ReplacePivot(old(I(node)), childidx as int - 1, pivot);
  //       Spec.IncreasePivotIsCorrect(old(I(node)), childidx as int - 1, pivot);
  //       pos := childidx as int64 - 1;
  //     } else {
  //       pos := -1;
  //     }
  //   } else if nleft == child.contents.nkeys {
  //     if childidx < node.contents.nchildren-1 {
  //       node.contents.pivots[childidx] := pivot;
  //       assert I(node) == Spec.ReplacePivot(old(I(node)), childidx as int, pivot);
  //       Spec.DecreasePivotIsCorrect(old(I(node)), childidx as int, pivot);
  //       pos := childidx as int64;
  //     } else {
  //       pos := node.contents.nchildren as int64 - 1;
  //     }
  //   } else {
  //     ghost var wit := SplitLeafOfIndexAtKey(node, childidx, pivot, nleft);
  //     pos := childidx as int64;
  //     Spec.SplitChildOfIndexPreservesWF(old(I(node)), I(node), childidx as int, wit);
  //     Spec.SplitChildOfIndexPreservesInterpretation(old(I(node)), I(node), childidx as int, wit);
  //     Spec.SplitChildOfIndexPreservesAllKeys(old(I(node)), I(node), childidx as int, wit);
  //   }
  // }

  // method EnsurePivotNotFull(node: Node, pivot: Key) returns (pos: int64)
  //   requires WFShape(node)
  //   requires Spec.WF(I(node))
  //   requires Spec.NumElements(I(node)) < Uint64UpperBound()
  //   requires node.contents.Index?
  //   requires !Full(node)
  //   ensures WFShape(node)
  //   ensures Spec.WF(I(node))
  //   ensures -1 <= pos as int < node.contents.nchildren as int
  //   ensures 0 <= pos as int < node.contents.nchildren as int - 1 ==> node.contents.pivots[pos] == pivot
  // {
  //   var childidx := Spec.Keys.ArrayLargestLtePlus1(node.contents.pivots, 0, node.contents.nchildren-1, pivot);
  //   if 0 < childidx && node.contents.pivots[childidx-1] == pivot {
  //     pos := childidx as int64 - 1;
  //   } else {
  //     var childpos := EnsurePivot(node.contents.children[pos], pivot);
  //   }
  // }

  // method EnsurePivot(node: Node, pivot: Key) returns (pos: int64)
  //   requires WFShape(node)
  //   requires Spec.WF(I(node))
  //   requires Spec.NumElements(I(node)) < Uint64UpperBound()
  //   requires node.contents.Index?
  //   requires !Full(node)
  //   ensures WFShape(node)
  //   ensures Spec.WF(I(node))
  //   ensures -1 <= pos as int < node.contents.nchildren as int
  //   ensures 0 <= pos as int < node.contents.nchildren as int - 1 ==> node.contents.pivots[pos] == pivot

}
