include "BoundedPivotsLib.i.dfy"
include "TranslationLib.i.dfy"
include "BucketImpl.i.dfy"

include "../Base/KeyType.s.dfy"
include "../Lang/LinearSequence.i.dfy"
include "../Lang/LinearSequence.s.dfy"

//
// Provides definitions and libraries for edge table and 
// other translation related methods and lemma
//

module TranslationImpl {
  import opened NativeTypes
  import opened BoundedPivotsLib
  import opened Translations = TranslationLib
  import opened Sequences
  import opened Options
  import opened KeyType
  import opened BucketImpl
  import opened LinearSequence_i
  import opened LinearSequence_s

  method ComputeSplitLeftEdges(et: EdgeTable, pt: PivotTable, pt': PivotTable, pivot: Key, cLeft: uint64) returns (et': EdgeTable)
  requires WFPivots(pt)
  requires WFEdges(et, pt)
  requires ValidLeftCutOffKey(pt, pivot)
  requires |pt| < 0x4000_0000_0000_0000
  requires cLeft as int == CutoffForLeft(pt, pivot)
  requires pt' == SplitLeft(pt, pivot)
  ensures et' == SplitLeftEdges(et, pt, pivot)
  {
    if (pt[cLeft + 1].Element? && pt[ cLeft+1 ].e == pivot) || et[cLeft].None? {
      return et[..cLeft + 1];
    } else {
      var oldlcp : Key := ComputePivotLcp(pt[cLeft], pt[cLeft+1]);
      var newlcp : Key := ComputePivotLcp(pt'[cLeft], pt'[cLeft+1]);
      PivotLcpSubRangeLeft(pt[cLeft], pt[cLeft+1], pt'[cLeft+1]);

      assume |et[cLeft].value + newlcp[|oldlcp|..]| <= 1024;
      var translation : Key := et[cLeft].value + newlcp[|oldlcp|..];
      return et[..cLeft] +  [Some(translation)];
    }
  }

  method ComputeSplitRightEdges(et: EdgeTable, pt: PivotTable, pt': PivotTable, pivot: Key, cRight: uint64) returns (et': EdgeTable)
  requires WFPivots(pt)
  requires WFEdges(et, pt)
  requires BoundedKey(pt, pivot)
  requires |pt| < 0x4000_0000_0000_0000
  requires cRight as int == CutoffForRight(pt, pivot)
  requires pt' == SplitRight(pt, pivot)
  ensures et' == SplitRightEdges(et, pt, pivot)
  {
    if pt[cRight].e == pivot || et[cRight].None? {
      return et[cRight..];
    } else {
      var oldlcp : Key := ComputePivotLcp(pt[cRight], pt[cRight+1]);
      var newlcp : Key := ComputePivotLcp(pt'[0], pt'[1]);
      PivotLcpSubRangeRight(pt[cRight], pt'[0], pt'[1]);

      assume |et[cRight].value + newlcp[|oldlcp|..]| <= 1024;
      var translation : Key := et[cRight].value + newlcp[|oldlcp|..];
      return [Some(translation)] + et[cRight+1..];
    }
  }

  lemma lcprightCondition(s: Key, len: nat)
    requires len <= |s|
    requires forall j | 0 <= j < len :: s[j] == 255
    requires len == |s| || s[len] < 255
    ensures s[..len] == lcpright(s)
  {
    if |s| == 0 || s[0] < 255 {
    } else {
      lcprightCondition(s[1..], len-1);
    }
  }

  method ComputelcprightLen(left: Key) returns (len: uint64)
  ensures len as nat == |lcpright(left)|
  {
    var i: uint64 := 0;
    var llen := |left| as uint64;

    while i < llen && left[i] == 255
      invariant 0 <= i <= llen
      invariant forall j | 0 <= j < i :: left[j] as int == Uint8UpperBound() - 1
    {
      i := i + 1;
    }
    lcprightCondition(left, i as nat);
    return i;
  }

  method Computelcpright(left: Key) returns (prefix: Key)
  ensures prefix == lcpright(left)
  {
    var len := ComputelcprightLen(left);
    return left[..len];
  }

  lemma lcpCondition(left: Key, right: Key, common_len: nat)
    requires common_len <= |left|
    requires common_len <= |right|
    requires forall j | 0 <= j < common_len :: left[j] == right[j]
    requires common_len == |left| || common_len == |right| || left[common_len] != right[common_len]
    ensures lcp(left, right) ==
      if common_len < |left| && common_len + 1 == |right| && left[common_len] as nat + 1 == right[common_len] as nat then
        left[..common_len + 1] + lcpright(left[common_len + 1..])
      else
        left[..common_len]
  {
    if 0 < common_len {
      lcpCondition(left[1..], right[1..], common_len-1);
    }
  }

  method ComputelcpLen(left: Key, right: Key) returns (len: uint64)
  ensures len as nat == |lcp(left, right)|
  {
    var i: uint64 := 0;
    while
      && i < |left| as uint64
      && i < |right| as uint64
      && left[i] == right[i]
      invariant i as nat <= |left|
      invariant i as nat <= |right|
      invariant forall j | j < i :: left[j] == right[j]
    {
      i := i + 1;
    }
    lcpCondition(left, right, i as nat);

    if
      && i < |left| as uint64
      && i + 1 == |right| as uint64
      && left[i] < right[i]
      && left[i] + 1 == right[i] {
        i := i + 1;
        ghost var s := i;
        while
          && i < |left| as uint64
          && left[i] == 255
          invariant s as nat <= i as nat <= |left|
          invariant forall j | s <= j < i :: left[j] == 255
        {
          i := i + 1;
        }
        lcprightCondition(left[s..], i as nat - s as nat);
    }
    len := i;
  }

  method Computelcp(left: Key, right: Key) returns (prefix: Key)
  ensures prefix == lcp(left, right)
  {
    var len := ComputelcpLen(left, right);
    prefix := left[..len];
  }

  method ComputePivotLcpLen(left: Element, right: Element) returns (len: uint64)
  requires ElementIsKey(left)
  requires right.Element? ==> ElementIsKey(right)
  ensures len as nat == |PivotLcp(left, right)|
  {
    if right.Max_Element? {
      len := ComputelcprightLen(left.e);
    } else {
      len := ComputelcpLen(left.e, right.e);
    }
  }

  method ComputePivotLcp(left: Element, right: Element) returns (prefix: Key)
  requires ElementIsKey(left)
  requires right.Element? ==> ElementIsKey(right)
  ensures prefix == PivotLcp(left, right)
  {
    var len := ComputePivotLcpLen(left, right);
    prefix := left.e[..len];
  }

  method ComputeTranslateKey(pt: PivotTable, et: EdgeTable, key: Key, r: uint64) returns (k: Key)
  requires |pt| < 0x4000_0000_0000_0000
  requires WFPivots(pt)
  requires BoundedKey(pt, key)
  requires WFEdges(et, pt)
  requires r as int == Route(pt, key)
  ensures k == TranslateKey(pt, et, key)
  {
    var r := ComputeRoute(pt, key);
    if et[r].Some? {
      var prefixlen := ComputePivotLcpLen(pt[r], pt[r+1]);
      PrefixOfLcpIsPrefixOfKey(pt[r], pt[r+1], pt[r].e[..prefixlen], key);
      assume |et[r].value| + |key| - prefixlen as nat <= 1024;
      k := et[r].value + key[prefixlen..];
    } else {
      k := key;
    }
  }

  method ComputeApplyPrefixSet(pset: Option<PrefixSet>, key: Key) returns (k: Key)
  requires pset.Some? ==> IsPrefix(pset.value.prefix, key)
  ensures k == ApplyPrefixSet(pset, key)
  {
    if pset.None? {
      k := key;
    } else {
      assume |pset.value.newPrefix| + |key| - |pset.value.prefix| <= 1024;
      k := pset.value.newPrefix + key[|pset.value.prefix| as uint64..];
    }
  }

  method ComputeComposePrefixSet(a: Option<PrefixSet>, b: Option<PrefixSet>) returns (c: Option<PrefixSet>)
  requires a.Some? && b.Some? ==>
    ( IsPrefix(a.value.newPrefix, b.value.prefix)
    || IsPrefix(b.value.prefix, a.value.newPrefix))
  ensures c == ComposePrefixSet(a, b)
  {
    if a.None? {
      c := b;
    } else if b.None? {
      c := a;
    } else if |a.value.newPrefix| as uint64 <= |b.value.prefix| as uint64 {
      reveal_IsPrefix();
      var prefix := ComputeApplyPrefixSet(Some(PrefixSet(a.value.newPrefix, a.value.prefix)), b.value.prefix);
      c := Some(PrefixSet(prefix, b.value.newPrefix));
    } else {
      var newPrefix := ComputeApplyPrefixSet(b, a.value.newPrefix);
      c := Some(PrefixSet(a.value.prefix, newPrefix));
    }
  }

  method ComputeShortestUncommonPrefix(prefix: Key) returns (upper: Element)
  ensures upper == ShortestUncommonPrefix(prefix, |prefix|)
  {
    reveal_ShortestUncommonPrefix();
    var i: int64 := |prefix| as int64 - 1;
    while 0 <= i && prefix[i] == 255
      invariant -1 <= i as int < |prefix|
      invariant forall j | i as int < j < |prefix| :: prefix[j] == 255
      invariant ShortestUncommonPrefix(prefix, |prefix|) == ShortestUncommonPrefix(prefix, i as int + 1)
    {
      i := i - 1;
    }
    if i == -1 {
      upper := Keyspace.Max_Element;
    } else {
      upper := Keyspace.Element(prefix[..i] + [prefix[i] + 1]);
    }
  }

  // TODO: implement
  method ComputeTranslateElement(e: Element, prefix: Key, newPrefix: Key) returns (e': Element)
  requires ElementIsKey(e)
  requires IsPrefix(prefix, e.e)
  ensures e' == TranslateElement(e, prefix, newPrefix)
  {
    assume false;
    e' := Keyspace.Element([]);
  }

  // TODO: impelement
  method ComputeTranslatePivotPair(left: Element, right: Element, prefix: Key, newPrefix: Key)
  returns (left': Element, right': Element)
  requires ElementIsKey(left)
  requires right.Element? ==> ElementIsKey(right)
  requires IsPrefix(prefix, left.e)
  requires Keyspace.lt(left, right)
  ensures var (l, r) := TranslatePivotPairInternal(left, right, prefix, newPrefix);
    && l == left'
    && r == right'
  {
    assume false;
    left' := Keyspace.Element([]);
    right' := Keyspace.Max_Element;
  }

  // TODO: implement
  method ComputeTranslatePivots(pt: PivotTable, prefix: Key, newPrefix: Key, end: Element) returns (pt': PivotTable)
  requires WFPivots(pt)
  requires forall i | 0 <= i < NumBuckets(pt) :: IsPrefix(prefix, pt[i].e)
  requires end.Element? ==> ElementIsKey(end)
  requires Keyspace.lt(TranslateElement(pt[|pt|-2], prefix, newPrefix), end)
  ensures pt' == TranslatePivots(pt, prefix, newPrefix, end, 0)
  {
    assume false;
    pt' := [];
  }

  // TODO: implement
  method ComputeTranslateEdges(et: EdgeTable, pt: PivotTable) returns (et': EdgeTable)
  requires WFPivots(pt)
  requires WFEdges(et, pt)
  ensures et' == TranslateEdges(et, pt, 0)
  {
    assume false;
    et' := [];
  }

  // TODO: implement
  method ComputeTranslateBucket(shared bucket: MutBucket, prefix: Key, newPrefix: Key) returns (linear bucket': MutBucket)
  requires bucket.Inv()
  ensures bucket'.Inv()
  ensures bucket'.I() == TranslateBucket(bucket.I(), prefix ,newPrefix)
  {
    assume false;
    bucket' := MutBucket.Alloc();
  }

  // TODO: implement
  method ComputeTranslateBuckets(shared blist: lseq<MutBucket>, prefix: Key, newPrefix: Key) returns (linear blist': lseq<MutBucket>)
  requires MutBucket.InvLseq(blist)
  ensures MutBucket.InvLseq(blist')
  ensures MutBucket.ILseq(blist') == TranslateBuckets(MutBucket.ILseq(blist), prefix, newPrefix)
  {
    blist' := lseq_alloc(0);
    assume false;
  }

  // TODO: Implement
  method ComputeParentKeysInChildRange(parentpivots: PivotTable, parentedges: EdgeTable, childpivots: PivotTable, slot: uint64)
  returns (b: bool)
  requires WFPivots(parentpivots)
  requires WFPivots(childpivots)
  requires WFEdges(parentedges, parentpivots)
  requires 0 <= slot as int < |parentedges|
  ensures b == ParentKeysInChildRange(parentpivots, parentedges, childpivots, slot as int)
  {
    assume false;
    b := true;
    // if parentedges[slot].None? {
    //   ComputeContainsRange();
    // }
    // Keyspace.reveal_IsStrictlySorted();
    // && (parentedges[slot].None? ==> 
    //     ContainsRange(childpivots, parentpivots[slot], parentpivots[slot+1]))
    // && (parentedges[slot].Some? ==> 
    //     && var (left, right) := TranslatePivotPair(parentpivots, parentedges, slot);
    //     && ContainsRange(childpivots, left, right))
  }
}
