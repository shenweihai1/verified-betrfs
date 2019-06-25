include "../lib/Maps.dfy"
include "../lib/sequences.dfy"
include "MapSpec.dfy"
include "Betree.dfy"
  
module BetreeInv {
  import opened DB = Betree
  import opened Maps
  import opened Sequences
  import opened BetreeSpec`Internal
  import opened G = BetreeSpec.G

  predicate KeyHasSatisfyingLookup(k: Constants, view: BI.View, key: Key)
  {
    exists lookup, value :: IsSatisfyingLookup(k, view, key, value, lookup)
  }

  predicate LookupIsAcyclic(lookup: Lookup) {
    forall i, j :: 0 <= i < |lookup| && 0 <= j < |lookup| && i != j ==> lookup[i].ref != lookup[j].ref
  }
  
  predicate Acyclic(k: Constants, s: Variables) {
    forall key, lookup ::
      IsPathFromRootLookup(k, s.bcv.view, key, lookup) ==>
      LookupIsAcyclic(lookup)
  }

  predicate Inv(k: Constants, s: Variables)
  {
    && BI.Inv(k.bck, s.bcv)
    && Acyclic(k, s)
    && (forall key | MS.InDomain(key) :: KeyHasSatisfyingLookup(k, s.bcv.view, key))
  }

  //// Definitions for lookup preservation

  // One-way preservation

  predicate PreservesLookups(k: Constants, s: Variables, s': Variables)
  {
    forall lookup, key, value :: IsSatisfyingLookup(k, s.bcv.view, key, value, lookup) ==>
      exists lookup' :: IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
  }

  predicate PreservesLookupsExcept(k: Constants, s: Variables, s': Variables, exceptQuery: Key)
  {
    forall lookup, key, value :: key != exceptQuery && IsSatisfyingLookup(k, s.bcv.view, key, value, lookup) ==>
      exists lookup' :: IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
  }

  // Two-way preservation

  predicate EquivalentLookups(k: Constants, s: Variables, s': Variables)
  {
    && PreservesLookups(k, s, s')
    && PreservesLookups(k, s', s)
  }

  predicate EquivalentLookupsWithPut(k: Constants, s: Variables, s': Variables, key: Key, value: Value)
  {
    && PreservesLookupsExcept(k, s, s', key)
    && PreservesLookupsExcept(k, s', s, key)
    && exists lookup :: IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup)
  }

  // CantEquivocate
  // It's a lemma here (follows from structure of Lookups) - not an invariant!

  lemma SatisfyingLookupsForKeyAgree(k: Constants, s: Variables, key: Key, value: Value, value': Value, lookup: Lookup, lookup': Lookup, idx: int)
  requires IsSatisfyingLookup(k, s.bcv.view, key, value, lookup);
  requires IsSatisfyingLookup(k, s.bcv.view, key, value', lookup');
  requires 0 <= idx < |lookup|;
  requires 0 <= idx < |lookup'|;
  ensures lookup[idx] == lookup'[idx];
  {
    if (idx == 0) {
    } else {
      SatisfyingLookupsForKeyAgree(k, s, key, value, value', lookup, lookup', idx - 1);
    }
  }

  lemma CantEquivocateWlog(k: Constants, s: Variables, key: Key, value: Value, value': Value, lookup: Lookup, lookup': Lookup)
  requires IsSatisfyingLookup(k, s.bcv.view, key, value, lookup);
  requires IsSatisfyingLookup(k, s.bcv.view, key, value', lookup');
  requires |lookup| <= |lookup'|
  ensures value == value';
  {
    var i := 0;

    while i < |lookup|
    invariant i <= |lookup|
    invariant LookupVisitsWFNodes(lookup[..i]);
    invariant LookupVisitsWFNodes(lookup'[..i]);
    invariant TotalLog(lookup[..i], key) == TotalLog(lookup'[..i], key)
    {
      SatisfyingLookupsForKeyAgree(k, s, key, value, value', lookup, lookup', i);
      assert lookup[..i] == lookup[..i+1][..i];
      assert lookup'[..i] == lookup'[..i+1][..i];
      i := i + 1;
    }

    reveal_IsPrefix();
    assert lookup == lookup[..i];

    var j := i;
    while j < |lookup'|
    invariant j <= |lookup'|
    invariant IsPrefix(TotalLog(lookup, key), TotalLog(lookup'[..j], key))
    {
      assert lookup'[..j] == lookup'[..j+1][..j];
      j := j + 1;
    }

    assert lookup' == lookup'[..j];
    assert IsPrefix(TotalLog(lookup, key), TotalLog(lookup', key));
  }

  lemma CantEquivocate(k: Constants, s: Variables, key: Key, value: Value, value': Value, lookup: Lookup, lookup': Lookup)
  requires IsSatisfyingLookup(k, s.bcv.view, key, value, lookup);
  requires IsSatisfyingLookup(k, s.bcv.view, key, value', lookup');
  ensures value == value';
  {
    if (|lookup| <= |lookup'|) {
      CantEquivocateWlog(k, s, key, value, value', lookup, lookup');
    } else {
      CantEquivocateWlog(k, s, key, value', value, lookup', lookup);
    }
  }

  // Old definitions
  // TODO clean these up; remove them or change them to use BetreeStep objects instead

  predicate Grow(k: BI.Constants, s: BI.Variables, s': BI.Variables, oldroot: Node, newchildref: Reference)
  {
    && ValidGrow(RootGrowth(oldroot, newchildref))
    && BI.Reads(k, s, GrowReads(RootGrowth(oldroot, newchildref)))
    && BI.OpTransaction(k, s, s', GrowOps(RootGrowth(oldroot, newchildref)))
  }

  predicate Flush(k: BI.Constants, s: BI.Variables, s': BI.Variables, parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference)
  {
    && ValidFlush(NodeFlush(parentref, parent, childref, child, newchildref))
    && BI.Reads(k, s, FlushReads(NodeFlush(parentref, parent, childref, child, newchildref)))
    && BI.OpTransaction(k, s, s', FlushOps(NodeFlush(parentref, parent, childref, child, newchildref)))
  }

  predicate Split(k: BI.Constants, s: BI.Variables, s': BI.Variables, fusion: NodeFusion)
  {
    && ValidSplit(fusion)
    && BI.Reads(k, s, SplitReads(fusion))
    && BI.OpTransaction(k, s, s', SplitOps(fusion))
  }

  predicate Merge(k: BI.Constants, s: BI.Variables, s': BI.Variables, fusion: NodeFusion)
  {
    && ValidMerge(fusion)
    && BI.Reads(k, s, MergeReads(fusion))
    && BI.OpTransaction(k, s, s', MergeOps(fusion))
  }

  predicate InsertMessage(k: BI.Constants, s: BI.Variables, s': BI.Variables, key: Key, msg: BufferEntry, oldroot: Node)
  {
    && ValidInsertion(MessageInsertion(key, msg, oldroot))
    && BI.Reads(k, s, InsertionReads(MessageInsertion(key, msg, oldroot)))
    && BI.OpTransaction(k, s, s', InsertionOps(MessageInsertion(key, msg, oldroot)))
  }


  ////////
  //////// Grow
  ////////

  // Acyclicity proofs

  lemma GrowPreservesAcyclic(k: Constants, s: Variables, s': Variables, oldroot: Node, newchildref: Reference)
    requires Inv(k, s)
    requires Grow(k.bck, s.bcv, s'.bcv, oldroot, newchildref)
    ensures Acyclic(k, s')
  {
    forall key1, lookup': Lookup | IsPathFromRootLookup(k, s'.bcv.view, key1, lookup')
      ensures LookupIsAcyclic(lookup')
    {
      if |lookup'| > 1 {
        var tmplookup := Apply((x: Layer) => x.(ref := if x.ref == newchildref then Root() else x.ref), lookup'[1..]);
        var lookup := Apply((x: Layer) => x.(node := if x.ref in s.bcv.view then s.bcv.view[x.ref] else EmptyNode()), tmplookup);
        var i := 1;
        while i < |lookup|
          invariant 1 <= i <= |lookup|
          invariant LookupIsAcyclic(lookup'[..i+1])
          invariant IsPathFromRootLookup(k, s.bcv.view, key1, lookup[..i])
        {
          assert lookup'[i].node == lookup[i-1].node;
          assert IMapsTo(s.bcv.view, lookup[i].ref, lookup[i].node);
          assert IsPathFromRootLookup(k, s.bcv.view, key1, lookup[..i+1]);
          assert lookup'[i+1].ref != Root();
          assert lookup'[i+1].node == lookup[i].node;
          i := i + 1;
        }
      }
    }
  }

  // Preservation proofs

  lemma TotalLogAdditive(a: Lookup, b: Lookup, key: Key)
  requires LookupVisitsWFNodes(a);
  requires LookupVisitsWFNodes(b);
  ensures TotalLog(a + b, key) == TotalLog(a, key) + TotalLog(b, key);
  {
    if (|b| == 0) {
      assert a + b == a;
    } else {
      TotalLogAdditive(a, b[..|b|-1], key);
      assert (a + b)[..|a+b|-1] == a + b[..|b|-1];
      assert (a + b)[|a+b|-1] == b[|b|-1];
      assert TotalLog(a + b, key)
          == TotalLog((a + b)[..|a+b|-1], key) + (a+b)[|a+b|-1].node.buffer[key]
          == TotalLog(a + b[..|b|-1], key) + b[|b|-1].node.buffer[key]
          == TotalLog(a, key) + TotalLog(b[..|b|-1], key) + b[|b|-1].node.buffer[key]
          == TotalLog(a, key) + TotalLog(b, key);
    }
  }
  
  lemma GrowEquivalentLookups(k: Constants, s: Variables, s': Variables, oldroot: Node, newchildref: Reference)
  requires Inv(k, s)
  requires Grow(k.bck, s.bcv, s'.bcv, oldroot, newchildref)
  ensures EquivalentLookups(k, s, s')
  {
    forall lookup:Lookup, key, value | IsSatisfyingLookup(k, s.bcv.view, key, value, lookup)
    ensures exists lookup' :: IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
    {
      // Add one for the new root
      var rootref := Root();

      var newroot := s'.bcv.view[rootref];

      //assert LookupIsAcyclic(lookup);

      var lookup' := [
        Layer(rootref, newroot),
        Layer(newchildref, oldroot)
      ] + lookup[1..];

      TotalLogAdditive([ Layer(rootref, newroot), Layer(newchildref, oldroot) ], lookup[1..], key);
      TotalLogAdditive([lookup[0]], lookup[1..], key);
      assert [lookup[0]] + lookup[1..] == lookup;

      assert IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup');
    }

    GrowPreservesAcyclic(k, s, s', oldroot, newchildref);
    
    forall lookup': Lookup, key, value | IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
    ensures exists lookup :: IsSatisfyingLookup(k, s.bcv.view, key, value, lookup)
    {
      if (|lookup'| == 1) {
        assert TotalLog(lookup', key) == [];
        assert false;
      }

      // Remove one for the root
      assert |lookup'| >= 2;
      var lookup := [Layer(Root(), lookup'[1].node)] + lookup'[2..];

      TotalLogAdditive([Layer(Root(), lookup'[1].node)], lookup'[2..], key);
      TotalLogAdditive(lookup'[..2], lookup'[2..], key);
      assert lookup'[..2] + lookup'[2..] == lookup';

      assert IsSatisfyingLookup(k, s.bcv.view, key, value, lookup);
    }
  }

  ////////
  //////// Flush
  ////////

  // Definitions of Flush lookup transformations:

  function transformLookup(lookup: Lookup, key: Key, oldref: Reference, newref: Reference, newnode: Node) : Lookup
  ensures |transformLookup(lookup, key, oldref, newref, newnode)| == |lookup|;
  ensures forall i :: 0 <= i < |lookup| ==>
      transformLookup(lookup, key, oldref, newref, newnode)[i].ref ==
        (if lookup[i].ref == oldref then newref else lookup[i].ref);
  ensures forall i :: 0 <= i < |lookup| ==>
      transformLookup(lookup, key, oldref, newref, newnode)[i].node ==
        (if lookup[i].ref == oldref then newnode else lookup[i].node);
  decreases lookup
  {
    if |lookup| == 0 then
      []
    else
      var pref := transformLookup(lookup[.. |lookup| - 1], key, oldref, newref, newnode);
      pref +
        [if lookup[|lookup| - 1].ref == oldref then
          Layer(newref, newnode)
         else
          Layer(lookup[|lookup| - 1].ref, lookup[|lookup| - 1].node)
        ]
  }

  // Change every parentref in lookup to the newparent, and likewise for the child.
  // However, when changing the child, we check first that it actually came from the parent
  // (since there might be other pointers to child)
  function transformLookupParentAndChild(lookup: Lookup, key: Key, parentref: Reference, newparent: Node, movedKeys: iset<Key>, oldchildref: Reference, newchildref: Reference, newchild: Node) : Lookup
  requires |lookup| > 0
  ensures |transformLookupParentAndChild(lookup, key, parentref, newparent, movedKeys, oldchildref, newchildref, newchild)| == |lookup|;
  decreases lookup
  {
    var pref := if |lookup| > 1 then transformLookupParentAndChild(lookup[.. |lookup| - 1], key, parentref, newparent, movedKeys, oldchildref, newchildref, newchild) else [];

    var lastLayer := Last(lookup);
    var ref := 
      (if lastLayer.ref == parentref then parentref else
       if lastLayer.ref == oldchildref && |lookup| > 1 && lookup[|lookup|-2].ref == parentref && key in movedKeys then newchildref else
       lastLayer.ref);
    var node :=
      (if lastLayer.ref == parentref then newparent else
       if lastLayer.ref == oldchildref && |lookup| > 1 && lookup[|lookup|-2].ref == parentref && key in movedKeys then newchild else

       lastLayer.node);
    pref + [Layer(ref, node)]
  }

  lemma transformLookupParentAndChildLemma(lookup: Lookup, lookup': Lookup, key: Key, parentref: Reference, newparent: Node, movedKeys: iset<Key>, oldchildref: Reference, newchildref: Reference, newchild: Node, i: int)
  requires 0 <= i < |lookup|
  requires lookup' == transformLookupParentAndChild(lookup, key, parentref, newparent, movedKeys, oldchildref, newchildref, newchild)
  ensures
    lookup'[i].ref ==
        (if lookup[i].ref == parentref then parentref else
         if lookup[i].ref == oldchildref && i > 0 && lookup[i-1].ref == parentref && key in movedKeys then newchildref else
         lookup[i].ref)
  ensures
    lookup'[i].node ==
        (if lookup[i].ref == parentref then newparent else
         if lookup[i].ref == oldchildref && i > 0 && lookup[i-1].ref == parentref && key in movedKeys then newchild else
         lookup[i].node)
  decreases |lookup|
  {
    if (i == |lookup| - 1) {
    } else {
      transformLookupParentAndChildLemma(lookup[..|lookup|-1], lookup'[..|lookup|-1],
          key, parentref, newparent, movedKeys, oldchildref, newchildref, newchild, i);
    }
  }

  lemma transformLookupParentAndChildPreservesAccumulatedLog(
    k: Constants,
    s: Variables,
    s': Variables,
    lookup: Lookup,
    lookup': Lookup,
    key: Key,
    parent: Node,
    child: Node,
    parentref: Reference,
    newparent: Node,
    movedKeys: iset<Key>,
    childref: Reference,
    newchildref: Reference,
    newchild: Node,
    newbuffer: Buffer,
    newparentbuffer: Buffer,
    newparentchildren: imap<Key, Reference>)
  requires IsPathFromRootLookup(k, s.bcv.view, key, lookup);
  requires Flush(k.bck, s.bcv, s'.bcv, parentref, parent, childref, child, newchildref)
  requires LookupVisitsWFNodes(lookup)
  requires LookupVisitsWFNodes(lookup')
  requires movedKeys == iset k | k in parent.children && parent.children[k] == childref;
  requires newbuffer == imap k :: (if k in movedKeys then parent.buffer[k] + child.buffer[k] else child.buffer[k]);
  requires newchild == Node(child.children, newbuffer);
  requires newparentbuffer == imap k :: (if k in movedKeys then [] else parent.buffer[k]);
  requires newparentchildren == imap k | k in parent.children :: (if k in movedKeys then newchildref else parent.children[k]);
  requires newparent == Node(newparentchildren, newparentbuffer);

  requires |lookup| > 0
  requires key in movedKeys ==> IMapsTo(parent.children, key, childref);
  requires key in movedKeys ==> Last(lookup).ref != parentref

  requires lookup' == transformLookupParentAndChild(lookup, key, parentref, newparent, movedKeys, childref, newchildref, newchild)

  ensures TotalLog(lookup', key) == TotalLog(lookup, key);
  {
    if (|lookup| == 1) {
      if (lookup[0].ref == parentref) {
        /*
        assert !(key in movedKeys);
        assert Last(lookup').accumulatedBuffer
            == lookup'[0].node.buffer[key]
            == lookup[0].node.buffer[key]
            == Last(lookup).accumulatedBuffer;
            */
      } else {
        /*
        assert Last(lookup').accumulatedBuffer
            == lookup'[0].node.buffer[key]
            == lookup[0].node.buffer[key]
            == Last(lookup).accumulatedBuffer;
        */
      }
    } else {
      if (key in movedKeys && lookup[|lookup|-2].ref == parentref) {
        if (|lookup| == 2) {
          //assert Last(lookup').accumulatedBuffer == Last(lookup).accumulatedBuffer;
        } else {
          assert lookup[|lookup|-2].node == parent;
          assert lookup[|lookup|-1].ref == childref;

          assert lookup[..|lookup|-1][..|lookup|-2] == lookup[..|lookup|-2];
          assert lookup'[..|lookup|-2]
              == transformLookupParentAndChild(lookup[..|lookup|-1], key, parentref, newparent, movedKeys, childref, newchildref, newchild)[..|lookup|-2]
              == transformLookupParentAndChild(lookup[..|lookup|-1][..|lookup|-2], key, parentref, newparent, movedKeys, childref, newchildref, newchild)
              == transformLookupParentAndChild(lookup[..|lookup|-2], key, parentref, newparent, movedKeys, childref, newchildref, newchild);

          transformLookupParentAndChildPreservesAccumulatedLog(k, s, s', lookup[..|lookup|-2], lookup'[..|lookup|-2], key, parent, child, parentref, newparent, movedKeys, childref, newchildref, newchild, newbuffer, newparentbuffer, newparentchildren);
          //assert Last(lookup').accumulatedBuffer == Last(lookup).accumulatedBuffer;
        }
      } else {
        transformLookupParentAndChildPreservesAccumulatedLog(k, s, s', lookup[..|lookup|-1], lookup'[..|lookup|-1], key, parent, child, parentref, newparent, movedKeys, childref, newchildref, newchild, newbuffer, newparentbuffer, newparentchildren);
        //assert Last(lookup').accumulatedBuffer == Last(lookup).accumulatedBuffer;
      }
    }
  }

  function flushTransformLookup(lookup: Lookup, key: Key, parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference) : Lookup
  requires |lookup| > 0
  requires WFNode(parent)
  requires WFNode(child)
  {
    var movedKeys := iset k | k in parent.children && parent.children[k] == childref;
    var newbuffer := imap k :: (if k in movedKeys then parent.buffer[k] + child.buffer[k] else child.buffer[k]);
    var newchild := Node(child.children, newbuffer);
    var newparentbuffer := imap k :: (if k in movedKeys then [] else parent.buffer[k]);
    var newparentchildren := imap k | k in parent.children :: (if k in movedKeys then newchildref else parent.children[k]);
    var newparent := Node(newparentchildren, newparentbuffer);
    var lookup1 := if Last(lookup).ref == parentref && key in movedKeys then lookup + [Layer(newchildref, newchild)] else lookup;
    transformLookupParentAndChild(lookup1, key, parentref, newparent, movedKeys, childref, newchildref, newchild)
  }

  function flushTransformLookupRev(lookup': Lookup, key: Key, parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference) : Lookup
  {
    // TODO Use transformLookupParentAndChild instead?
    // This works fine, but only because newchildref is fresh.
    // This pattern doesn't work going the other way, so might as well change this one too
    // for more symmetry.
    transformLookup(transformLookup(lookup', key, newchildref, childref, child), key, parentref, parentref, parent)
  }

  lemma FlushPreservesIsPathFromLookupRev(k: Constants, s: Variables, s': Variables, parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference, lookup: Lookup, lookup': Lookup, key: Key)
  requires Inv(k, s)
  requires Flush(k.bck, s.bcv, s'.bcv, parentref, parent, childref, child, newchildref)
  requires IsPathFromRootLookup(k, s'.bcv.view, key, lookup')
  requires lookup == flushTransformLookupRev(lookup', key, parentref, parent, childref, child, newchildref);
  ensures IsPathFromRootLookup(k, s.bcv.view, key, lookup);
  // These follow immediately from IsPathFromRootLookup:
  //ensures LookupIsAcyclic(lookup);
  //ensures key in Last(lookup).node.children ==> Last(lookup).node.children[key] in s.bcv.view;
  decreases lookup'
  {
    if (|lookup'| == 0) {
    } else if (|lookup'| == 1) {
      assert Root() in s.bcv.view;
      assert lookup[0].node == s.bcv.view[Root()];
      assert IsPathFromRootLookup(k, s.bcv.view, key, lookup);
    } else {
      FlushPreservesIsPathFromLookupRev(k, s, s', parentref, parent, childref, child, newchildref,
        flushTransformLookupRev(lookup'[.. |lookup'| - 1], key, parentref, parent, childref, child, newchildref),
        lookup'[.. |lookup'| - 1], key);

      assert IsPathFromRootLookup(k, s.bcv.view, key, lookup);
    }
  }

  lemma FlushPreservesAcyclicLookup(k: Constants, s: Variables, s': Variables, parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference, lookup': Lookup, key: Key)
  requires Inv(k, s)
  requires Flush(k.bck, s.bcv, s'.bcv, parentref, parent, childref, child, newchildref)
  requires IsPathFromRootLookup(k, s'.bcv.view, key, lookup')
  ensures LookupIsAcyclic(lookup')
  {
    var movedKeys := iset k | k in parent.children && parent.children[k] == childref;
    var newbuffer := imap k :: (if k in movedKeys then parent.buffer[k] + child.buffer[k] else child.buffer[k]);
    var newparentbuffer := imap k :: (if k in movedKeys then [] else parent.buffer[k]);
    var newparentchildren := imap k | k in parent.children :: (if k in movedKeys then newchildref else parent.children[k]);
    var newparent := Node(newparentchildren, newparentbuffer);

    if (|lookup'| <= 1) {
    } else {
      var lookup := flushTransformLookupRev(lookup', key, parentref, parent, childref, child, newchildref);
      FlushPreservesIsPathFromLookupRev(k, s, s', parentref, parent, childref, child, newchildref, lookup, lookup', key);
    }
  }

  lemma FlushPreservesAcyclic(k: Constants, s: Variables, s': Variables, parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference)
    requires Inv(k, s)
    requires Flush(k.bck, s.bcv, s'.bcv, parentref, parent, childref, child, newchildref)
    ensures Acyclic(k, s')
  {
    forall key, lookup':Lookup | IsPathFromRootLookup(k, s'.bcv.view, key, lookup')
    ensures LookupIsAcyclic(lookup')
    {
      FlushPreservesAcyclicLookup(k, s, s', parentref, parent, childref, child, newchildref, lookup', key);
    }
  }


  lemma transformLookupParentAndChildPreservesAccumulatedLogRev(
    k: Constants,
    s: Variables,
    s': Variables,
    parentref: Reference,
    parent: Node,
    childref: Reference,
    child: Node,
    newchildref: Reference,
    movedKeys: iset<Key>,
    lookup: Lookup,
    lookup': Lookup,
    key: Key
  )
  requires Inv(k, s)
  requires IsPathFromRootLookup(k, s.bcv.view, key, lookup);
  requires IsPathFromRootLookup(k, s'.bcv.view, key, lookup');
  requires LookupVisitsWFNodes(lookup);
  requires LookupVisitsWFNodes(lookup');
  requires Flush(k.bck, s.bcv, s'.bcv, parentref, parent, childref, child, newchildref)
  requires lookup == flushTransformLookupRev(lookup', key, parentref, parent, childref, child, newchildref)
  requires movedKeys == iset k | k in parent.children && parent.children[k] == childref;
  requires key in movedKeys ==> Last(lookup').ref != parentref
  ensures TotalLog(lookup', key) == TotalLog(lookup, key);
  {
    var newbuffer := imap k :: (if k in movedKeys then parent.buffer[k] + child.buffer[k] else child.buffer[k]);
    var newchild := Node(child.children, newbuffer);
    var newparentbuffer := imap k :: (if k in movedKeys then [] else parent.buffer[k]);
    var newparentchildren := imap k | k in parent.children :: (if k in movedKeys then newchildref else parent.children[k]);
    var newparent := Node(newparentchildren, newparentbuffer);

    if (|lookup| == 1) {
      //assert Last(lookup').accumulatedBuffer == Last(lookup).accumulatedBuffer;
    } else {
      if (key in movedKeys && Last(lookup').ref == newchildref) {
        if (|lookup| == 2) {
          assert lookup'[1].node == newchild;
          assert lookup'[0].ref == parentref;
          assert lookup'[0].node == newparent;
          //assert Last(lookup').accumulatedBuffer
          //    == lookup[0].node.buffer[key] + lookup[1].node.buffer[key]
          //    == Last(lookup).accumulatedBuffer;
        } else {
          assert lookup'[..|lookup|-1][..|lookup|-2] == lookup'[..|lookup|-2];
          assert lookup[..|lookup|-2]
              == flushTransformLookupRev(lookup'[..|lookup|-1], key, parentref, parent, childref, child, newchildref)[..|lookup|-2]
              == flushTransformLookupRev(lookup'[..|lookup|-1][..|lookup|-2], key, parentref, parent, childref, child, newchildref)
              == flushTransformLookupRev(lookup'[..|lookup|-2], key, parentref, parent, childref, child, newchildref);

          transformLookupParentAndChildPreservesAccumulatedLogRev(k, s, s', parentref, parent, childref, child, newchildref, movedKeys, lookup[..|lookup|-2], lookup'[..|lookup|-2], key);
          //assert Last(lookup').accumulatedBuffer == Last(lookup).accumulatedBuffer;
        }
      } else {
        transformLookupParentAndChildPreservesAccumulatedLogRev(k, s, s', parentref, parent, childref, child, newchildref, movedKeys, lookup[..|lookup|-1], lookup'[..|lookup|-1], key);
        //assert Last(lookup').accumulatedBuffer == Last(lookup).accumulatedBuffer;
      }
    }
  }

  lemma transformLookupParentAndChildPreservesAccumulatedLogRevPrefix(
    k: Constants,
    s: Variables,
    s': Variables,
    parentref: Reference,
    parent: Node,
    childref: Reference,
    child: Node,
    newchildref: Reference,
    movedKeys: iset<Key>,
    lookup: Lookup,
    lookup': Lookup,
    key: Key
  )
  requires Inv(k, s)
  requires IsPathFromRootLookup(k, s.bcv.view, key, lookup);
  requires IsPathFromRootLookup(k, s'.bcv.view, key, lookup');
  requires LookupVisitsWFNodes(lookup);
  requires LookupVisitsWFNodes(lookup');
  requires Flush(k.bck, s.bcv, s'.bcv, parentref, parent, childref, child, newchildref)
  requires lookup == flushTransformLookupRev(lookup', key, parentref, parent, childref, child, newchildref)
  requires movedKeys == iset k | k in parent.children && parent.children[k] == childref;
  ensures IsPrefix(TotalLog(lookup', key), TotalLog(lookup, key));
  {
    if (key in movedKeys && Last(lookup').ref == parentref) {
      var newbuffer := imap k :: (if k in movedKeys then parent.buffer[k] + child.buffer[k] else child.buffer[k]);
      var newchild := Node(child.children, newbuffer);

      var lookup1 := lookup + [Layer(childref, child)];
      var lookup1' := lookup' + [Layer(newchildref, newchild)];

      assert IsPathFromRootLookup(k, s.bcv.view, key, lookup1);
      assert IsPathFromRootLookup(k, s'.bcv.view, key, lookup1');

      transformLookupParentAndChildPreservesAccumulatedLogRev(
          k, s, s', parentref, parent, childref, child, newchildref, movedKeys, lookup1, lookup1', key);


      //assert Last(lookup).accumulatedBuffer + child.buffer[key] == Last(lookup').accumulatedBuffer + newchild.buffer[key];

      reveal_IsSuffix();
      assert IsSuffix(child.buffer[key], newchild.buffer[key]);
      IsPrefixFromEqSums(TotalLog(lookup, key), child.buffer[key], TotalLog(lookup', key), newchild.buffer[key]);
    } else {
      transformLookupParentAndChildPreservesAccumulatedLogRev(
          k, s, s', parentref, parent, childref, child, newchildref, movedKeys, lookup, lookup', key);
      SelfIsPrefix(TotalLog(lookup', key));
    }
  }

  lemma FlushEquivalentLookups(k: Constants, s: Variables, s': Variables, parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference)
  requires Inv(k, s)
  requires Flush(k.bck, s.bcv, s'.bcv, parentref, parent, childref, child, newchildref)
  ensures EquivalentLookups(k, s, s')
  {
    var movedKeys := iset k | k in parent.children && parent.children[k] == childref;
    var newbuffer := imap k :: (if k in movedKeys then parent.buffer[k] + child.buffer[k] else child.buffer[k]);
    var newchild := Node(child.children, newbuffer);
    var newparentbuffer := imap k :: (if k in movedKeys then [] else parent.buffer[k]);
    var newparentchildren := imap k | k in parent.children :: (if k in movedKeys then newchildref else parent.children[k]);
    var newparent := Node(newparentchildren, newparentbuffer);

    forall lookup:Lookup, key, value | IsSatisfyingLookup(k, s.bcv.view, key, value, lookup)
    ensures exists lookup' :: IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
    {
      var lookup1 := if Last(lookup).ref == parentref && key in movedKeys then lookup + [Layer(childref, child)] else lookup;

      assert IsPathFromRootLookup(k, s.bcv.view, key, lookup1);

      var lookup' := flushTransformLookup(lookup, key, parentref, parent, childref, child, newchildref);

      transformLookupParentAndChildLemma(lookup1, lookup', key, parentref, newparent, movedKeys, childref, newchildref, newchild, 0);

      assert lookup'[0].ref == Root();

      forall i | 0 <= i < |lookup'|
      ensures IMapsTo(s'.bcv.view, lookup'[i].ref, lookup'[i].node)
      ensures WFNode(lookup'[i].node)
      {
        transformLookupParentAndChildLemma(lookup1, lookup', key, parentref, newparent, movedKeys, childref, newchildref, newchild, i);
      }

      forall i | 0 <= i < |lookup'| - 1
      ensures key in lookup'[i].node.children
      ensures lookup'[i].node.children[key] == lookup'[i+1].ref
      {
        transformLookupParentAndChildLemma(lookup1, lookup', key, parentref, newparent, movedKeys, childref, newchildref, newchild, i);
        transformLookupParentAndChildLemma(lookup1, lookup', key, parentref, newparent, movedKeys, childref, newchildref, newchild, i+1);
      }

      transformLookupParentAndChildPreservesAccumulatedLog(k, s, s', lookup1, lookup',
          key, parent, child, parentref, newparent, movedKeys, childref, newchildref,
          newchild, newbuffer, newparentbuffer, newparentchildren);

      assert IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup');
    }

    forall lookup': Lookup, key, value | IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
    ensures exists lookup :: IsSatisfyingLookup(k, s.bcv.view, key, value, lookup)
    {
      var lookup := flushTransformLookupRev(lookup', key, parentref, parent, childref, child, newchildref);
      FlushPreservesIsPathFromLookupRev(k, s, s', parentref, parent, childref, child, newchildref, lookup, lookup', key);

      transformLookupParentAndChildPreservesAccumulatedLogRevPrefix(k, s, s', parentref, parent, childref, child, newchildref, movedKeys, lookup, lookup', key);
      reveal_IsPrefix();

      assert IsSatisfyingLookup(k, s.bcv.view, key, value, lookup);
    }
  }

  ////////
  //////// Split
  ////////

  // Define the transformations for splits:

  // These are the relations we should get out between lookup and lookup' if we obtain lookup'
  // by taking lookup and doing the following:
  //  - replace each instance of parentref/fused_parent with parentref/split_parent
  //  - replace each instance of fused_child with left_child (for left keys only, and only when directly after the parent in the lookup)
  //  - replace each instance of fused_child with left_child (for left keys only, and only when directly after the parent in the lookup)
  //  - leave everything else the same
  predicate SplitLookups(fusion: NodeFusion, lookup: Lookup, lookup': Lookup, key: Key)
  {
    && |lookup| == |lookup'|
    && |lookup| > 0

    // the lookup[i].ref == fusion.fused_childref condition is redundant for well-formed lookups
    && (key in fusion.left_keys ==> (
      && (forall i :: 0 < i < |lookup| && lookup[i-1].ref == fusion.parentref ==>
          lookup'[i].ref == fusion.left_childref)
      && (forall i :: 0 < i < |lookup| && lookup[i-1].ref == fusion.parentref ==>
          lookup'[i].node == fusion.left_child)
    ))

    && (key in fusion.right_keys ==> (
      && (forall i :: 0 < i < |lookup| && lookup[i-1].ref == fusion.parentref ==>
          lookup'[i].ref == fusion.right_childref)
      && (forall i :: 0 < i < |lookup| && lookup[i-1].ref == fusion.parentref ==>
          lookup'[i].node == fusion.right_child)
    ))

    && lookup'[0].ref == lookup[0].ref
    && (lookup[0].ref != fusion.parentref ==> lookup'[0].node == lookup[0].node)
    && (lookup[0].ref == fusion.parentref ==> lookup'[0].node == fusion.split_parent)

    && (forall i :: 0 < i < |lookup| && lookup[i-1].ref != fusion.parentref ==> lookup'[i].ref == lookup[i].ref)
    && (forall i :: 0 < i < |lookup| && lookup[i].ref != fusion.parentref && lookup[i-1].ref != fusion.parentref ==> lookup'[i].node == lookup[i].node)
    && (forall i :: 0 < i < |lookup| && lookup[i].ref == fusion.parentref && lookup[i-1].ref != fusion.parentref ==> lookup'[i].node == fusion.split_parent)

    && ((key !in fusion.left_keys && key !in fusion.right_keys) ==> (
      && (forall i :: 0 <= i < |lookup| ==> lookup'[i].ref == lookup[i].ref)
      && (forall i :: 0 <= i < |lookup| ==> lookup'[i].ref != fusion.parentref ==> lookup'[i].node == lookup[i].node)
      && (forall i :: 0 <= i < |lookup| ==> lookup'[i].ref == fusion.parentref ==> lookup'[i].node == fusion.split_parent)
    ))
  }

  function {:opaque} splitLookup(fusion: NodeFusion, lookup: Lookup, key: Key) : Lookup
  requires |lookup| > 0
  ensures |splitLookup(fusion, lookup, key)| == |lookup|
  {
    if (|lookup| == 1) then (
      var node := if lookup[0].ref == fusion.parentref then fusion.split_parent else lookup[0].node;
      [Layer(lookup[0].ref, node)]
    ) else (
      var pref := splitLookup(fusion, lookup[..|lookup|-1], key);
      var prevRef := lookup[|lookup| - 2].ref;
      var curRef := lookup[|lookup| - 1].ref;
      var curNode := lookup[|lookup| - 1].node;
      var ref := (if key in fusion.left_keys && prevRef == fusion.parentref then fusion.left_childref else
                 (if key in fusion.right_keys && prevRef == fusion.parentref then fusion.right_childref else
                 curRef));
      var node := (if key in fusion.left_keys && prevRef == fusion.parentref then fusion.left_child else
                 (if key in fusion.right_keys && prevRef == fusion.parentref then fusion.right_child else
                 (if ref == fusion.parentref then fusion.split_parent else
                 curNode)));
      pref + [Layer(ref, node)]
    )
  }

  lemma splitLookupProperties(fusion: NodeFusion, lookup: Lookup, lookup': Lookup, key: Key)
  requires |lookup| > 0
  requires ValidFusion(fusion);
  requires lookup' == splitLookup(fusion, lookup, key);
  ensures SplitLookups(fusion, lookup, lookup', key);
  {
    reveal_splitLookup();
    if (|lookup| == 1) {
      assert SplitLookups(fusion, lookup, lookup', key);
    } else {
      assert lookup'[..|lookup|-1] == splitLookup(fusion, lookup[..|lookup|-1], key);
      splitLookupProperties(fusion, lookup[..|lookup|-1], lookup'[..|lookup|-1], key);
      assert SplitLookups(fusion, lookup, lookup', key);
    }
  }

  lemma SplitLookupPreservesAccumulatedBuffer(k: Constants, s: Variables, s': Variables, fusion: NodeFusion, key: Key, lookup: Lookup, lookup': Lookup)
  requires |lookup| > 0;
  requires SplitLookups(fusion, lookup, lookup', key);
  requires Split(k.bck, s.bcv, s'.bcv, fusion);
  requires ValidFusion(fusion);
  requires IsPathFromRootLookup(k, s.bcv.view, key, lookup);
  requires IsPathFromRootLookup(k, s'.bcv.view, key, lookup');
  requires LookupVisitsWFNodes(lookup);
  requires LookupVisitsWFNodes(lookup');
  ensures TotalLog(lookup, key) == TotalLog(lookup', key);
  {
    if (|lookup| == 1) {
    } else {
      SplitLookupPreservesAccumulatedBuffer(k, s, s', fusion, key, lookup[..|lookup|-1], lookup'[..|lookup|-1]);
      assert Last(lookup).node.buffer[key] == Last(lookup').node.buffer[key];
    }
  }

  lemma SplitPreservesIsPathFromRootLookup(k: Constants, s: Variables, s': Variables, fusion: NodeFusion, lookup: Lookup, lookup': Lookup, key: Key)
  requires Inv(k, s);
  requires Split(k.bck, s.bcv, s'.bcv, fusion);
  requires SplitLookups(fusion, lookup, lookup', key)
  requires IsPathFromRootLookup(k, s.bcv.view, key, lookup);
  ensures IsPathFromRootLookup(k, s'.bcv.view, key, lookup');
  {
    /*
    var view' := s'.bcv.view;
    forall i | 0 <= i < |lookup'|
    ensures IMapsTo(view', lookup'[i].ref, lookup'[i].node)
    {
      if (i == 0) {
        if (lookup[i].ref == fusion.parentref) {
          assert IMapsTo(view', lookup'[i].ref, lookup'[i].node);
        } else {
          assert IMapsTo(view', lookup'[i].ref, lookup'[i].node);
        }
      } else {
        if (lookup[i-1].ref == fusion.parentref && key in fusion.left_keys) {
          assert IMapsTo(view', lookup'[i].ref, lookup'[i].node);
        }
        else if (lookup[i-1].ref == fusion.parentref && key in fusion.right_keys) {
          assert IMapsTo(view', lookup'[i].ref, lookup'[i].node);
        }
        else if (lookup[i].ref == fusion.parentref) {
          assert IMapsTo(view', lookup'[i].ref, lookup'[i].node);
        }
        else {
          assert IMapsTo(view', lookup'[i].ref, lookup'[i].node);
        }
      }
    }
    */
  }

  // Define the transformations for merges (reverse splits):

  // These are the relations we should get out between lookup and lookup' if we obtain lookup'
  // by taking lookup' and doing the following:
  //  - replace each instance of parentref/split_parent with parentref/fused_parent
  //  - replace each instance of left_child with fused_child (for left keys only, and only when directly after the parent in the lookup)
  //  - replace each instance of right_child with fused_child (for right keys only, and only when directly after the parent in the lookup)
  //  - leave everything else the same
  predicate MergeLookups(fusion: NodeFusion, lookup: Lookup, lookup': Lookup, key: Key)
  {
    && |lookup| == |lookup'|
    && |lookup'| > 0

    && (key in fusion.left_keys ==> (
      && (forall i :: 0 < i < |lookup'| && lookup'[i-1].ref == fusion.parentref ==>
          lookup[i].ref == fusion.fused_childref)
      && (forall i :: 0 < i < |lookup'| && lookup'[i-1].ref == fusion.parentref ==>
          lookup[i].node == fusion.fused_child)
    ))

    && (key in fusion.right_keys ==> (
      && (forall i :: 0 < i < |lookup'| && lookup'[i-1].ref == fusion.parentref ==>
          lookup[i].ref == fusion.fused_childref)
      && (forall i :: 0 < i < |lookup'| && lookup'[i-1].ref == fusion.parentref ==>
          lookup[i].node == fusion.fused_child)
    ))

    && lookup[0].ref == lookup'[0].ref
    && (lookup'[0].ref != fusion.parentref ==> lookup[0].node == lookup'[0].node)
    && (lookup'[0].ref == fusion.parentref ==> lookup[0].node == fusion.fused_parent)

    && (forall i :: 0 < i < |lookup'| && lookup'[i-1].ref != fusion.parentref ==> lookup[i].ref == lookup'[i].ref)
    && (forall i :: 0 < i < |lookup'| && lookup'[i].ref != fusion.parentref && lookup'[i-1].ref != fusion.parentref ==> lookup[i].node == lookup'[i].node)
    && (forall i :: 0 < i < |lookup'| && lookup'[i].ref == fusion.parentref && lookup'[i-1].ref != fusion.parentref ==> lookup[i].node == fusion.fused_parent)

    && ((key !in fusion.left_keys && key !in fusion.right_keys) ==> (
      && (forall i :: 0 <= i < |lookup'| ==> lookup[i].ref == lookup'[i].ref)
      && (forall i :: 0 <= i < |lookup'| ==> lookup[i].ref != fusion.parentref ==> lookup[i].node == lookup'[i].node)
      && (forall i :: 0 <= i < |lookup'| ==> lookup[i].ref == fusion.parentref ==> lookup[i].node == fusion.fused_parent)
    ))
  }

  function {:opaque} mergeLookup(fusion: NodeFusion, lookup': Lookup, key: Key) : Lookup
  requires |lookup'| > 0
  ensures |mergeLookup(fusion, lookup', key)| == |lookup'|
  {
    if (|lookup'| == 1) then (
      var node := if lookup'[0].ref == fusion.parentref then fusion.fused_parent else lookup'[0].node;
      [Layer(lookup'[0].ref, node)]
    ) else (
      var pref := mergeLookup(fusion, lookup'[..|lookup'|-1], key);
      var prevRef := lookup'[|lookup'| - 2].ref;
      var curRef := lookup'[|lookup'| - 1].ref;
      var curNode := lookup'[|lookup'| - 1].node;
      var ref := (if key in fusion.left_keys && prevRef == fusion.parentref then fusion.fused_childref else
                 (if key in fusion.right_keys && prevRef == fusion.parentref then fusion.fused_childref else
                 curRef));
      var node := (if key in fusion.left_keys && prevRef == fusion.parentref then fusion.fused_child else
                 (if key in fusion.right_keys && prevRef == fusion.parentref then fusion.fused_child else
                 (if ref == fusion.parentref then fusion.fused_parent else
                 curNode)));
      pref + [Layer(ref, node)]
    )
  }

  lemma mergeLookupProperties(fusion: NodeFusion, lookup: Lookup, lookup': Lookup, key: Key)
  requires |lookup'| > 0
  requires ValidFusion(fusion);
  requires lookup == mergeLookup(fusion, lookup', key);
  ensures MergeLookups(fusion, lookup, lookup', key);
  {
    reveal_mergeLookup();
    if (|lookup'| == 1) {
      assert MergeLookups(fusion, lookup, lookup', key);
    } else {
      assert lookup[..|lookup|-1] == mergeLookup(fusion, lookup'[..|lookup|-1], key);
      mergeLookupProperties(fusion, lookup[..|lookup|-1], lookup'[..|lookup|-1], key);
      assert MergeLookups(fusion, lookup, lookup', key);
    }
  }

  lemma MergeLookupPreservesAccumulatedBuffer(k: Constants, s: Variables, s': Variables, fusion: NodeFusion, key: Key, lookup: Lookup, lookup': Lookup)
    requires |lookup'| > 0;
    requires MergeLookups(fusion, lookup, lookup', key);
    requires Split(k.bck, s.bcv, s'.bcv, fusion);
    requires ValidFusion(fusion);
    requires IsPathFromRootLookup(k, s.bcv.view, key, lookup);
    requires IsPathFromRootLookup(k, s'.bcv.view, key, lookup');
    requires LookupVisitsWFNodes(lookup);
    requires LookupVisitsWFNodes(lookup');
    ensures TotalLog(lookup, key) == TotalLog(lookup', key);
    {
      if (|lookup'| == 1) {
      } else {
        MergeLookupPreservesAccumulatedBuffer(k, s, s', fusion, key, lookup[..|lookup|-1], lookup'[..|lookup|-1]);
        assert Last(lookup).node.buffer[key] == Last(lookup').node.buffer[key];
      }
    }

  lemma SplitPreservesIsPathFromRootLookupRev(k: Constants, s: Variables, s': Variables, fusion: NodeFusion, lookup: Lookup, lookup': Lookup, key: Key)
  requires Inv(k, s);
  requires Split(k.bck, s.bcv, s'.bcv, fusion);
  requires MergeLookups(fusion, lookup, lookup', key)
  requires IsPathFromRootLookup(k, s'.bcv.view, key, lookup');
  ensures IsPathFromRootLookup(k, s.bcv.view, key, lookup);
  {
    var view := s.bcv.view;

    if (|lookup'| == 0) {
    } else if (|lookup'| == 1) {
      if (lookup'[0].ref == fusion.parentref) {
        assert IMapsTo(view, lookup[0].ref, lookup[0].node);
      } else {
        assert lookup[0].ref == Root();
        assert lookup[0].node == lookup'[0].node;
        assert IMapsTo(view, lookup[0].ref, lookup[0].node);
      }

      assert IsPathFromRootLookup(k, s.bcv.view, key, lookup);
    } else {
      SplitPreservesIsPathFromRootLookupRev(k, s, s', fusion, lookup[..|lookup|-1], lookup'[..|lookup|-1], key);

      forall i | 0 <= i < |lookup|
      ensures IMapsTo(view, lookup[i].ref, lookup[i].node)
      {
        if (i == |lookup| - 1) {
          if (lookup'[i-1].ref == fusion.parentref && key in fusion.left_keys) {
            assert IMapsTo(view, lookup[i].ref, lookup[i].node);
          }
          else if (lookup'[i-1].ref == fusion.parentref && key in fusion.right_keys) {
            assert IMapsTo(view, lookup[i].ref, lookup[i].node);
          }
          else if (lookup'[i].ref == fusion.parentref) {
            assert IMapsTo(view, lookup[i].ref, lookup[i].node);
          }
          else {
            assert IMapsTo(view, lookup[i].ref, lookup[i].node);
          }
        } else {
          assert IMapsTo(view, lookup[i].ref, lookup[i].node);
        }
      }

      forall i | 0 <= i < |lookup| - 1
      ensures key in lookup[i].node.children
      ensures lookup[i].node.children[key] == lookup[i+1].ref
      {
        if (i == |lookup| - 2) {
          if (i > 0 && lookup'[i-1].ref == fusion.parentref && key in fusion.left_keys) {
            assert lookup[i].node.children[key] == lookup[i+1].ref;
          }
          else if (i > 0 && lookup'[i-1].ref == fusion.parentref && key in fusion.right_keys) {
            assert lookup[i].node.children[key] == lookup[i+1].ref;
          }
          else if (lookup'[i].ref == fusion.parentref) {
            assert lookup[i].node.children[key] == lookup[i+1].ref;
          }
          else {
            assert lookup[i].node.children[key] == lookup[i+1].ref;
          }
        } else {
          assert lookup[i].node.children[key] == lookup[i+1].ref;
        }
      }

      assert IsPathFromRootLookup(k, s.bcv.view, key, lookup);
    }
  }

  lemma SplitPreservesAcyclicLookup(k: Constants, s: Variables, s': Variables, fusion: NodeFusion, lookup': Lookup, key: Key)
  requires Inv(k, s)
  requires Split(k.bck, s.bcv, s'.bcv, fusion);
  requires IsPathFromRootLookup(k, s'.bcv.view, key, lookup')
  ensures LookupIsAcyclic(lookup')
  {
    var lookup := mergeLookup(fusion, lookup', key);
    mergeLookupProperties(fusion, lookup, lookup', key);
    SplitPreservesIsPathFromRootLookupRev(k, s, s', fusion, lookup, lookup', key);
    assert LookupIsAcyclic(lookup);
    forall i, j | 0 <= i < |lookup'| && 0 <= j < |lookup'| && i != j
    ensures lookup'[i].ref != lookup'[j].ref
    {
      if (lookup'[i].ref == lookup'[j].ref) {
        if (lookup'[i].ref == fusion.left_childref && key in fusion.left_keys) {
          assert i > 0;
          assert lookup'[i-1].ref == fusion.parentref;

          assert j > 0;
          assert lookup'[j-1].ref == fusion.parentref;

          assert lookup[i].ref == fusion.fused_childref;
          assert lookup[j].ref == fusion.fused_childref;
          assert false;
        } else if (lookup'[i].ref == fusion.right_childref && key in fusion.right_keys) {
          assert i > 0;
          assert lookup'[i-1].ref == fusion.parentref;

          assert j > 0;
          assert lookup'[j-1].ref == fusion.parentref;

          assert lookup[i].ref == fusion.fused_childref;
          assert lookup[j].ref == fusion.fused_childref;
          assert false;
        } else {
          assert lookup[i].ref == lookup'[i].ref;
          assert lookup[j].ref == lookup'[j].ref;
          assert false;
        }
      }
    }
  }

  lemma SplitPreservesAcyclic(k: Constants, s: Variables, s': Variables, fusion: NodeFusion)
  requires Inv(k, s);
  requires Split(k.bck, s.bcv, s'.bcv, fusion);
  ensures Acyclic(k, s');
  {
    forall key, lookup':Lookup | IsPathFromRootLookup(k, s'.bcv.view, key, lookup')
    ensures LookupIsAcyclic(lookup')
    {
      SplitPreservesAcyclicLookup(k, s, s', fusion, lookup', key);
    }
  }

  lemma SplitPreservesIsSatisfyingLookup(k: Constants, s: Variables, s': Variables, fusion: NodeFusion, lookup: Lookup, lookup': Lookup, key: Key, value: Value)
  requires Inv(k, s);
  requires Split(k.bck, s.bcv, s'.bcv, fusion);
  requires |lookup| > 0;
  requires lookup' == splitLookup(fusion, lookup, key)
  requires IsSatisfyingLookup(k, s.bcv.view, key, value, lookup);
  ensures IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup');
  {
    splitLookupProperties(fusion, lookup, lookup', key);
    SplitPreservesIsPathFromRootLookup(k, s, s', fusion, lookup, lookup', key);

    forall k | k !in fusion.split_parent.children
    ensures BufferIsDefining(fusion.split_parent.buffer[k])
    {
      assert k !in fusion.left_keys;
      assert k !in fusion.right_keys;
      assert k !in fusion.fused_parent.children;
    }
    assert WFNode(fusion.split_parent);

    assert WFNode(fusion.left_child);
    assert WFNode(fusion.right_child);
    
    SplitLookupPreservesAccumulatedBuffer(k, s, s', fusion, key, lookup, lookup');
  }

  lemma SplitPreservesIsSatisfyingLookupRev(k: Constants, s: Variables, s': Variables, fusion: NodeFusion, lookup: Lookup, lookup': Lookup, key: Key, value: Value)
  requires Inv(k, s);
  requires Split(k.bck, s.bcv, s'.bcv, fusion);
  requires |lookup'| > 0;
  requires lookup == mergeLookup(fusion, lookup', key)
  requires IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup');
  ensures IsSatisfyingLookup(k, s.bcv.view, key, value, lookup);
  {
    mergeLookupProperties(fusion, lookup, lookup', key);
    SplitPreservesIsPathFromRootLookupRev(k, s, s', fusion, lookup, lookup', key);

    MergeLookupPreservesAccumulatedBuffer(k, s, s', fusion, key, lookup, lookup');
  }

  lemma SplitEquivalentLookups(k: Constants, s: Variables, s': Variables, fusion: NodeFusion)
  requires Inv(k, s)
  requires Split(k.bck, s.bcv, s'.bcv, fusion);
  ensures EquivalentLookups(k, s, s');
  {
    forall lookup:Lookup, key, value | IsSatisfyingLookup(k, s.bcv.view, key, value, lookup)
    ensures exists lookup' :: IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
    {
      var lookup' := splitLookup(fusion, lookup, key);
      SplitPreservesIsSatisfyingLookup(k, s, s', fusion, lookup, lookup', key, value);
    }

    forall lookup': Lookup, key, value | IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
    ensures exists lookup :: IsSatisfyingLookup(k, s.bcv.view, key, value, lookup)
    {
      var lookup := mergeLookup(fusion, lookup', key);
      SplitPreservesIsSatisfyingLookupRev(k, s, s', fusion, lookup, lookup', key, value);
    }
  }

  // lemma SplitPreservesReachablePointersValid(k: Constants, s: Variables, s': Variables, fusion: NodeFusion)
  // requires Inv(k, s)
  // requires Split(k.bck, s.bcv, s'.bcv, fusion)
  // ensures ReachablePointersValid(k, s')
  // {
  //   forall key, lookup': Lookup | IsPathFromRootLookup(k, s'.bcv.view, key, lookup') && key in lookup'[|lookup'|-1].node.children
  //   ensures 
  //     lookup'[|lookup'|-1].node.children[key] in s'.bcv.view
  //   {
  //     var lookup := mergeLookup(fusion, lookup', key);
  //     mergeLookupProperties(fusion, lookup, lookup', key);
  //     SplitPreservesIsPathFromRootLookupRev(k, s, s', fusion, lookup, lookup', key);
  //   }
  // }

  ////////
  //////// Invariant proofs
  ////////

  lemma InitImpliesInv(k: Constants, s: Variables)
    requires Init(k, s)
    ensures Inv(k, s)
  {
    forall key | MS.InDomain(key)
    ensures IsSatisfyingLookup(k, s.bcv.view, key, MS.EmptyValue(), [Layer(Root(), EmptyNode())]);
    {
    }
  }

  lemma QueryStepPreservesInvariant(k: Constants, s: Variables, s': Variables, key: Key, value: Value, lookup: Lookup)
    requires Inv(k, s)
    requires Query(k, s, s', key, value, lookup)
    ensures Inv(k, s')
  {
  }

  lemma InsertMessagePreservesAcyclicAndReachablePointersValid(k: Constants, s: Variables, s': Variables, key: Key, msg: BufferEntry, oldroot: Node)
    requires Inv(k, s)
    requires InsertMessage(k.bck, s.bcv, s'.bcv, key, msg, oldroot)
    ensures Acyclic(k, s')
  {
    forall key1, lookup': Lookup | IsPathFromRootLookup(k, s'.bcv.view, key1, lookup')
      ensures LookupIsAcyclic(lookup')
      ensures key1 in Last(lookup').node.children ==> Last(lookup').node.children[key1] in s'.bcv.view
    {
      var lookup := Apply((x: Layer) => x.(node := if x.ref in s.bcv.view then s.bcv.view[x.ref] else EmptyNode()), lookup');
      assert IsPathFromRootLookup(k, s.bcv.view, key1, lookup);
    }
  }

  lemma InsertMessagePreservesTotality(k: Constants, s: Variables, s': Variables, key: Key, msg: BufferEntry, oldroot: Node)
    requires Inv(k, s)
    requires InsertMessage(k.bck, s.bcv, s'.bcv, key, msg, oldroot)
    ensures forall key1 | MS.InDomain(key1) :: KeyHasSatisfyingLookup(k, s'.bcv.view, key1)
  {
    forall key1 | MS.InDomain(key1)
      ensures KeyHasSatisfyingLookup(k, s'.bcv.view, key1)
    {
      var value, lookup :| IsSatisfyingLookup(k, s.bcv.view, key1, value, lookup);
      var lookup' := Apply((x: Layer) => x.(node := if x.ref in s'.bcv.view then s'.bcv.view[x.ref] else EmptyNode()),
                           lookup);
      if key1 != key {
        var i := 1;
        while i < |lookup|
        invariant i <= |lookup|
        invariant TotalLog(lookup'[..i], key1) == TotalLog(lookup[..i], key1);
        {
          assert lookup[..i] == lookup[..i+1][..i];
          assert lookup'[..i] == lookup'[..i+1][..i];
          i := i + 1;
        }
        assert lookup == lookup[..i];
        assert lookup' == lookup'[..i];
        assert TotalLog(lookup', key1) == TotalLog(lookup, key1);

        assert BufferDefinesValue(TotalLog(lookup', key1), value);
        assert IsSatisfyingLookup(k, s'.bcv.view, key1, value, lookup');
      } else {
        reveal_IsPrefix();

        var i := 1;
        while i < |lookup|
        invariant i <= |lookup|
        invariant IsPrefix([msg], TotalLog(lookup'[..i], key1))
        {
          assert lookup'[..i] == lookup'[..i+1][..i];
          i := i + 1;
        }
        assert lookup' == lookup'[..i];
        assert IsPrefix([msg], TotalLog(lookup', key1));

        assert BufferDefinesValue(TotalLog(lookup', key1), msg.value);
        assert IsSatisfyingLookup(k, s'.bcv.view, key1, msg.value, lookup');
      }
    }
  }
    
  lemma InsertMessageStepPreservesInvariant(k: Constants, s: Variables, s': Variables, key: Key, msg: BufferEntry, oldroot: Node)
    requires Inv(k, s)
    requires InsertMessage(k.bck, s.bcv, s'.bcv, key, msg, oldroot)
    ensures Inv(k, s')
  {
    InsertMessagePreservesAcyclicAndReachablePointersValid(k, s, s', key, msg, oldroot);
    InsertMessagePreservesTotality(k, s, s', key, msg, oldroot);
  }

  lemma FlushStepPreservesInvariant(k: Constants, s: Variables, s': Variables,
                                           parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference)
    requires Inv(k, s)
    requires Flush(k.bck, s.bcv, s'.bcv, parentref, parent, childref, child, newchildref)
    ensures Inv(k, s')
  {
    FlushPreservesAcyclic(k, s, s', parentref, parent, childref, child, newchildref);
    FlushEquivalentLookups(k, s, s', parentref, parent, childref, child, newchildref);
  }
  
  lemma GrowStepPreservesInvariant(k: Constants, s: Variables, s': Variables, oldroot: Node, newchildref: Reference)
    requires Inv(k, s)
    requires Grow(k.bck, s.bcv, s'.bcv, oldroot, newchildref)
    ensures Inv(k, s')
  {
    GrowPreservesAcyclic(k, s, s', oldroot, newchildref);
    GrowEquivalentLookups(k, s, s', oldroot, newchildref);
  }
 
  lemma SplitStepPreservesInvariant(k: Constants, s: Variables, s': Variables, fusion: NodeFusion)
    requires Inv(k, s)
    requires Split(k.bck, s.bcv, s'.bcv, fusion)
    ensures Inv(k, s')
  {
    SplitPreservesAcyclic(k, s, s', fusion);
    SplitEquivalentLookups(k, s, s', fusion);
    //SplitPreservesReachablePointersValid(k, s, s', fusion);
  }

  lemma MergeStepPreservesInvariant(k: Constants, s: Variables, s': Variables, fusion: NodeFusion)
    requires Inv(k, s)
    requires Merge(k.bck, s.bcv, s'.bcv, fusion)
    ensures Inv(k, s')
  {
  }

  // GC Step

  lemma IsPathFromRootLookupImpliesReachable(k: Constants, s: Variables, key: Key, lookup: Lookup, i: int)
    requires Inv(k, s)
    requires IsPathFromRootLookup(k, s.bcv.view, key, lookup)
    requires 0 <= i < |lookup|
    ensures BI.ReachableReference(k.bck, s.bcv, lookup[i].ref);
  {
    if (i == 0) {
      var l := [lookup[0].ref];
      assert BI.LookupIsValid(k.bck, s.bcv, l) && Last(l) == lookup[0].ref;
      assert BI.ReachableReference(k.bck, s.bcv, lookup[0].ref);
    } else {
      IsPathFromRootLookupImpliesReachable(k, s, key, lookup, i-1);
      var l: BI.Lookup :| BI.LookupIsValid(k.bck, s.bcv, l) && Last(l) == lookup[i-1].ref;
      var l' := l + [lookup[i].ref];
      assert BI.LookupIsValid(k.bck, s.bcv, l') && Last(l') == lookup[i].ref;
      assert BI.ReachableReference(k.bck, s.bcv, lookup[i].ref);
    }
  }

  lemma GCStepPreservesIsPathFromRootLookup(k: Constants, s: Variables, s': Variables, refs: iset<Reference>, lookup: Lookup, key: Key)
    requires Inv(k, s)
    requires GC(k, s, s', refs)
    requires IsPathFromRootLookup(k, s.bcv.view, key, lookup);
    ensures IsPathFromRootLookup(k, s'.bcv.view, key, lookup);
  {
    forall i | 0 <= i < |lookup|
    ensures IMapsTo(s'.bcv.view, lookup[i].ref, lookup[i].node)
    {
      assert IMapsTo(s.bcv.view, lookup[i].ref, lookup[i].node);
      IsPathFromRootLookupImpliesReachable(k, s, key, lookup, i);
      assert BI.ReachableReference(k.bck, s.bcv, lookup[i].ref);
      assert lookup[i].ref !in refs;
    }
  }

  lemma GCStepPreservesIsPathFromRootLookupRev(k: Constants, s: Variables, s': Variables, refs: iset<Reference>, lookup: Lookup, key: Key)
    requires Inv(k, s)
    requires GC(k, s, s', refs)
    requires IsPathFromRootLookup(k, s'.bcv.view, key, lookup);
    ensures IsPathFromRootLookup(k, s.bcv.view, key, lookup);
  {
  }

  lemma GCStepPreservesAcyclicity(k: Constants, s: Variables, s': Variables, refs: iset<Reference>)
    requires Inv(k, s)
    requires GC(k, s, s', refs)
    ensures Acyclic(k, s')
  {
    forall key, lookup | IsPathFromRootLookup(k, s'.bcv.view, key, lookup)
    ensures LookupIsAcyclic(lookup)
    {
      GCStepPreservesIsPathFromRootLookupRev(k, s, s', refs, lookup, key);
    }
  }

  lemma GCStepEquivalentLookups(k: Constants, s: Variables, s': Variables, refs: iset<Reference>)
    requires Inv(k, s)
    requires GC(k, s, s', refs)
    ensures EquivalentLookups(k, s, s')
  {
    forall lookup:Lookup, key, value | IsSatisfyingLookup(k, s.bcv.view, key, value, lookup)
    ensures exists lookup' :: IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
    {
      GCStepPreservesIsPathFromRootLookup(k, s, s', refs, lookup, key);
      assert IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup);
    }

    forall lookup': Lookup, key, value | IsSatisfyingLookup(k, s'.bcv.view, key, value, lookup')
    ensures exists lookup :: IsSatisfyingLookup(k, s.bcv.view, key, value, lookup)
    {
      GCStepPreservesIsPathFromRootLookupRev(k, s, s', refs, lookup', key);
      assert IsSatisfyingLookup(k, s.bcv.view, key, value, lookup');
    }
  }

  lemma GCStepPreservesInvariant(k: Constants, s: Variables, s': Variables, refs: iset<Reference>)
    requires Inv(k, s)
    requires GC(k, s, s', refs)
    ensures Inv(k, s')
  {
    BI.GCPreservesInv(k.bck, s.bcv, s'.bcv, refs);
    GCStepPreservesAcyclicity(k, s, s', refs);
    GCStepEquivalentLookups(k, s, s', refs);
  }

  // Putting it all together

  lemma BetreeStepPreservesInvariant(k: Constants, s: Variables, s': Variables, betreeStep: BetreeStep)
    requires Inv(k, s)
    requires Betree(k, s, s', betreeStep)
    ensures Inv(k, s')
  {
    match betreeStep {
      case BetreeInsert(ins) => InsertMessageStepPreservesInvariant(k, s, s', ins.key, ins.msg, ins.oldroot);
      case BetreeFlush(flush) => FlushStepPreservesInvariant(k, s, s', flush.parentref, flush.parent, flush.childref, flush.child, flush.newchildref);
      case BetreeGrow(growth) => GrowStepPreservesInvariant(k, s, s', growth.oldroot, growth.newchildref);
      case BetreeSplit(fusion) => SplitStepPreservesInvariant(k, s, s', fusion);
      case BetreeMerge(fusion) => MergeStepPreservesInvariant(k, s, s', fusion);
    }
  }

  lemma NextStepPreservesInvariant(k: Constants, s: Variables, s': Variables, step: Step)
    requires Inv(k, s)
    requires NextStep(k, s, s', step)
    ensures Inv(k, s')
  {
    match step {
      case QueryStep(key, value, lookup) => QueryStepPreservesInvariant(k, s, s', key, value, lookup);
      case GCStep(refs) => GCStepPreservesInvariant(k, s, s', refs);
      case BetreeStep(betreeStep) => BetreeStepPreservesInvariant(k, s, s', betreeStep);
    }
  }
  
  lemma NextPreservesInv(k: Constants, s: Variables, s': Variables)
    requires Inv(k, s)
    requires Next(k, s, s')
    ensures Inv(k, s')
  {
    var step :| NextStep(k, s, s', step);
    NextStepPreservesInvariant(k, s, s', step);
  }
    

}
