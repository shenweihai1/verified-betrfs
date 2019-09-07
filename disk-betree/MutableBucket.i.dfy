include "../lib/tttree.i.dfy"
include "KVList.i.dfy"
include "Bounds.i.dfy"

module MutableBucket {
  import TTT = TwoThreeTree
  import KVList
  import opened ValueMessage`Internal
  import opened Lexicographic_Byte_Order
  import opened Sequences
  import opened Options
  import opened Maps
  import opened BucketsLib
  import opened Bounds
  import opened BucketWeights
  import opened NativeTypes
  import Native
  import Pivots = PivotsLib

  type Key = Element
  type Kvl = KVList.Kvl
  type TreeMap = TTT.Tree<Message>

  method tree_to_kvl(tree: TreeMap)
  returns (kvl : Kvl)
  requires TTT.TTTree(tree)
  ensures KVList.WF(kvl)
  ensures KVList.I(kvl) == TTT.I(tree)
  {
    assume false;
    var s := TTT.AsSeq(tree);
    kvl := KVList.KvlOfSeq(s, TTT.I(tree));
  }

  method kvl_to_tree(kvl : Kvl)
  returns (tree: TreeMap)
  requires KVList.WF(kvl)
  ensures TTT.TTTree(tree)
  ensures KVList.I(kvl) == TTT.I(tree)
  {
    assume false;
    if (|kvl.keys| as uint64 == 0) {
      return TTT.EmptyTree;
    }

    var ar := new (Key, TTT.Node)[|kvl.keys| as uint64];
    var j := 0;
    while j < |kvl.keys| as uint64 {
      ar[j] := (kvl.keys[j], TTT.Leaf(kvl.keys[j], kvl.values[j]));
      j := j + 1;
    }
    var len := |kvl.keys| as uint64;
    while len > 1 {
      var k := 0;
      var newlen := 0;
      while k < len - 4 {
        ar[newlen] := (ar[k].0, TTT.ThreeNode(ar[k].1, ar[k+1].0, ar[k+1].1, ar[k+2].0, ar[k+2].1));
        k := k + 3;
        newlen := newlen + 1;
      }
      if (k == len - 4) {
        ar[newlen] := (ar[k].0, TTT.TwoNode(ar[k].1, ar[k+1].0, ar[k+1].1));
        newlen := newlen + 1;
        ar[newlen] := (ar[k+2].0, TTT.TwoNode(ar[k+2].1, ar[k+3].0, ar[k+3].1));
        newlen := newlen + 1;
      } else if (k == len - 3) {
        ar[newlen] := (ar[k].0, TTT.ThreeNode(ar[k].1, ar[k+1].0, ar[k+1].1, ar[k+2].0, ar[k+2].1));
        newlen := newlen + 1;
      } else {
        ar[newlen] := (ar[k].0, TTT.TwoNode(ar[k].1, ar[k+1].0, ar[k+1].1));
        newlen := newlen + 1;
      }
      len := newlen;
    }
    tree := TTT.NonEmptyTree(ar[0].1);
  }

  class MutBucket {
    var is_tree: bool;

    var tree: TreeMap;
    var kvl: Kvl;

    var Weight: uint64;

    ghost var Repr: set<object>;
    ghost var Bucket: map<Key, Message>;

    protected predicate Inv()
    reads this, Repr
    ensures Inv() ==> this in Repr
    ensures Inv() ==> Weight as int == WeightBucket(Bucket)
    ensures Inv() ==> WFBucket(Bucket)
    {
      && Repr == {this}
      && (!is_tree ==> (
        && KVList.WF(kvl)
        && Weight as int == WeightBucket(KVList.I(kvl))
        && Bucket == KVList.I(kvl)
      ))
      && (is_tree ==> (
        && TTT.TTTree(tree)
        && Weight as int == WeightBucket(TTT.I(tree))
        && Bucket == TTT.I(tree)
      ))
      && WFBucket(Bucket)
    }

    constructor(kv: Kvl)
    requires KVList.WF(kv)
    requires WeightBucket(KVList.I(kv)) < 0x1_0000_0000_0000_0000
    ensures Bucket == KVList.I(kv)
    ensures Inv()
    {
      this.is_tree := false;
      this.kvl := kv;
      this.Repr := {this};
      var w := KVList.computeWeightKvl(kv);
      this.Weight := w;
      this.Bucket := KVList.I(kv);
      KVList.WFImpliesWFBucket(kv);
    }

    static function ReprSeq(s: seq<MutBucket>) : set<object>
    reads set i | 0 <= i < |s| :: s[i]
    {
      set i, o | 0 <= i < |s| && o in s[i].Repr :: o
    }

    static predicate InvSeq(s: seq<MutBucket>)
    reads set i | 0 <= i < |s| :: s[i]
    reads ReprSeq(s)
    {
      forall i | 0 <= i < |s| :: s[i].Inv()
    }

    static protected function I(s: MutBucket) : Bucket
    reads s
    {
      s.Bucket
    }

    static protected function ISeq(s: seq<MutBucket>) : (bs : seq<Bucket>)
    reads set i | 0 <= i < |s| :: s[i]
    reads ReprSeq(s)
    ensures |bs| == |s|
    ensures forall i | 0 <= i < |s| :: bs[i] == s[i].Bucket
    {
      if |s| == 0 then [] else ISeq(DropLast(s)) + [I(Last(s))]
    }

    static method PartialFlush(parent: MutBucket, children: seq<MutBucket>, pivots: seq<Key>)
    returns (newParent: MutBucket, newChildren: seq<MutBucket>)
    requires parent.Inv()
    requires InvSeq(children)
    requires WFBucketList(ISeq(children), pivots)
    requires WeightBucket(I(parent)) <= MaxTotalBucketWeight() as int
    requires WeightBucketList(ISeq(children)) <= MaxTotalBucketWeight() as int
    ensures newParent.Inv()
    ensures InvSeq(newChildren)
    ensures fresh(newParent.Repr)
    ensures forall i | 0 <= i < |newChildren| :: fresh(newChildren[i].Repr)

    method Insert(key: Key, value: Message)
    requires Inv()
    modifies Repr
    ensures Inv()
    ensures Bucket == BucketInsert(old(Bucket), key, value)
    ensures forall o | o in Repr :: o in old(Repr) || fresh(o)
    {
      if !is_tree {
        is_tree := true;
        tree := kvl_to_tree(kvl);
        kvl := KVList.Kvl([], []); // not strictly necessary, but frees memory
      }

      if value.Define? {
        cur_value := TTT.Que
        tree := TTT.Insert(tree, key, value);
      }
    }

    method Query(key: Key)
    returns (m: Option<Message>)
    requires Inv()
    ensures m.None? ==> key !in Bucket
    ensures m.Some? ==> key in Bucket && Bucket[key] == m.value
    {
      if is_tree {
        var res := TTT.Query(tree, key);
        if res.ValueForKey? {
          m := Some(res.value);
        } else {
          m := None;
        }
      } else {
        KVList.lenKeysLeWeightOver8(kvl);
        m := KVList.Query(kvl, key);
      }
    }

    method SplitLeft(pivot: Key)
    returns (left: MutBucket)
    requires Inv()
    ensures left.Inv()
    ensures left.Bucket == SplitBucketLeft(Bucket, pivot)
    ensures fresh(left.Repr)
    {
      var kv;
      if is_tree {
        kv := tree_to_kvl(tree);
      } else {
        kv := kvl;
      }

      KVList.splitLeftCorrect(kv, pivot);
      WeightSplitBucketLeft(Bucket, pivot);
      KVList.lenKeysLeWeightOver8(kv);
      var kvlLeft := KVList.SplitLeft(kv, pivot);
      left := new MutBucket(kvlLeft);
    }

    method SplitRight(pivot: Key)
    returns (right: MutBucket)
    requires Inv()
    ensures right.Inv()
    ensures right.Bucket == SplitBucketRight(Bucket, pivot)
    ensures fresh(right.Repr)
    {
      var kv;
      if is_tree {
        kv := tree_to_kvl(tree);
      } else {
        kv := kvl;
      }

      KVList.splitRightCorrect(kv, pivot);
      WeightSplitBucketRight(Bucket, pivot);
      KVList.lenKeysLeWeightOver8(kv);
      var kvlRight := KVList.SplitRight(kv, pivot);
      right := new MutBucket(kvlRight);
    }

    /*method SplitOneInList(buckets: seq<MutBucket>, slot: uint64, pivot: Key)
    returns (buckets' : seq<MutBucket>)
    requires splitKMTInList.requires(buckets, slot, pivot)
    ensures buckets' == splitKMTInList(buckets, slot, pivot)*/
  }
}
