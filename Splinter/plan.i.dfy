include "../lib/Lang/NativeTypes.s.dfy"
include "../lib/Base/sequences.i.dfy"
include "../lib/Base/Option.s.dfy"
include "../lib/Base/Maps.i.dfy"

module MessageMod {
  type Key(!new,==)
  type Value(!new)
  type Message(!new)

  function AllKeys() : iset<Key> {
    iset key:Key | true
  }

  function DefaultValue() : Value
    // TODO
}

module AllocationMod {
  type AU = nat
  datatype CU = CU(au: AU, offset: nat)
  type UninterpretedDiskPage

  function DiskSizeInAU() : (s:nat)
    ensures 1<=s

  function AUSizeInBlocks() : (s:nat)
    ensures 2<=s

  predicate ValidCU(cu: CU) {
    && 0 <= cu.au < DiskSizeInAU()
    && 0 <= cu.offset < AUSizeInBlocks()
  }

  type DiskView = map<CU, UninterpretedDiskPage>

  predicate FullView(dv: DiskView) {
    forall cu :: cu in dv.Keys <==> ValidCU(cu)
  }
}

module MsgSeqMod {
  import opened MessageMod

  type MsgSeq = seq<Message>

  function I(key:Key, msgseq: MsgSeq) : Value

  predicate Collapsed(m0: MsgSeq, m1:MsgSeq)
  {
    false
    // m0, m1 related by collapsing irrelevant messages
  }

  lemma ICollapse(m0: MsgSeq, m1:MsgSeq)
    requires Collapsed(m0, m1)
    ensures forall key :: I(key, m0) == I(key, m1)
  {
  }

  function Concat(m0: MsgSeq, m1:MsgSeq) : MsgSeq
  {
    m0 + m1
  }
}

module MsgMapMod {
  import opened MessageMod
  import opened MsgSeqMod
  import opened Sequences

  predicate FullImap<K(!new),V>(m: imap<K, V>) {  // TODO move to MapSpec
    forall k :: k in m
  }

  function method FullImapWitness<K(!new),V>(v: V) : (m: imap<K, V>)
    ensures FullImap(m)
    // Gaa "method" because Dafny considers 'witness' not a ghost context.
    // Can't actually give this a body.

  type MsgMap = m: imap<Key, MsgSeq> | FullImap(m) witness FullImapWitness([])

  function I(msgmap: MsgMap) : imap<Key, Value>
  {
    imap key | key in AllKeys() :: MsgSeqMod.I(key, msgmap[key])
  }

  function Concat(m0: MsgMap, m1: MsgMap) : MsgMap
  {
    imap key | key in AllKeys() :: MsgSeqMod.Concat(m0[key], m1[key])
  }

  function ConcatSeq(sm:seq<MsgMap>) : MsgMap
  {
    if |sm|==0
      then Empty()
      else Concat(ConcatSeq(DropLast(sm)), Last(sm))
  }

  function Empty() : MsgMap
  {
    imap key | key in AllKeys() :: []
  }
}

module JournalMod {
  import opened Options
  import opened Sequences
  import opened Maps
  import opened MsgMapMod
  import opened AllocationMod

  datatype Superblock = Superblock(firstCU: CU, firstValidSeq : nat)

  // Monoid-friendly (quantified-list) definition
  datatype JournalRecord = JournalRecord(
    messageMap: MsgMap,
    seqStart: nat,  // inclusive
    seqEnd: nat,  // exclusive
    nextCU: Option<CU>   // linked list pointer
  )
  type JournalChain = seq<JournalRecord>

  function parse(b: UninterpretedDiskPage) : Option<JournalRecord>
    // TODO marshalling

  predicate WFChainBasic(chain: JournalChain)
  {
    && 0 < |chain|
    && Last(chain).nextCU.None?
    && (forall i | 0<=i<|chain|-1 :: chain[i].nextCU.Some?)
  }

  predicate {:opaque} WFChainInner(chain: JournalChain)
    requires WFChainBasic(chain)
  {
    && (forall i | 0<=i<|chain|-1 ::
      chain[i].seqStart == chain[i+1].seqEnd)
  }

  predicate WFChain(chain: JournalChain)
  {
    && WFChainBasic(chain)
    && WFChainInner(chain)
  }

  function CUsForChain(firstCU: CU, chain: JournalChain) : (cus: seq<CU>)
    requires WFChain(chain)
    ensures |cus| == |chain|
  {
    [firstCU] + seq(|chain|-1,
      i requires 0<=i<|chain|-1 => chain[i].nextCU.value)
  }

  predicate RecordOnDisk(dv: DiskView, cu: CU, journalRecord: JournalRecord)
  {
    && cu in dv
    && parse(dv[cu]) == Some(journalRecord)
  }

  predicate {:opaque} ChainMatchesDiskView(dv: DiskView, firstCU: CU, chain: JournalChain)
    requires WFChain(chain)
  {
    // chain corresponds to stuff in the DiskView starting at firstCU.
    && var cus := CUsForChain(firstCU, chain);
    && (forall i | 0<=i<|chain| :: RecordOnDisk(dv, cus[i], chain[i]))
  }

  // Describe a valid chain with quantification.
  predicate ValidJournalChain(dv: DiskView, firstCU: CU, chain: JournalChain)
  {
    && WFChain(chain)
    && ChainMatchesDiskView(dv, firstCU, chain)
  }

  // Define reading a chain recursively. Returns None if any of the
  // CUs point to missing blocks from the dv, or if the block can't
  // be parsed.
  // Note that the firstCU.None? case is only here to clean up the recursive
  // definition; that's why firstCU.Some? is a prereq for the ensures.
  function ChainFromInner(dv: DiskView, firstCU: Option<CU>) : (chain:Option<JournalChain>)
    ensures firstCU.Some? && chain.Some?
      ==> ValidJournalChain(dv, firstCU.value, chain.value)
    decreases |dv.Keys|
  {
    if firstCU.None? then
      Some([])
    else if firstCU.value !in dv then
      None  // !RecordOnDisk
    else
      var firstRec := parse(dv[firstCU.value]);
      if firstRec.None? then
        None  // !RecordOnDisk
      else
        var rest := ChainFromInner(MapRemove1(dv, firstCU.value), firstRec.value.nextCU);
        if rest.None? // tail didn't decode or
          // tail decoded but head doesn't stitch to it (a cross-crash invariant)
          || (0<|rest.value| && firstRec.value.seqStart != rest.value[0].seqEnd)
        then
          None  // failure in recursive call
        else
          var chain := [firstRec.value] + rest.value;
          assert ValidJournalChain(dv, firstCU.value, chain) by {
            reveal_WFChainInner();
            reveal_ChainMatchesDiskView();
            forall i | 0<=i<|chain|-1
              ensures chain[i].seqStart == chain[i+1].seqEnd
            {
              if i==0 {
                calc {
                  chain[i].seqStart;
                  rest.value[0].seqEnd;
                  chain[i+1].seqEnd;
                }
                assert chain[i].seqStart == chain[i+1].seqEnd;
              } else {
                calc {
                  chain[i].seqStart;
                  rest.value[i-1].seqStart;
                  rest.value[i].seqEnd;
                  chain[i+1].seqEnd;
                }
              }
            }
            assert WFChain(chain);
            var cus := CUsForChain(firstCU.value, chain);
            forall i | 0<=i<|chain|
              ensures RecordOnDisk(dv, cus[i], chain[i])
            {
            }
          }
          Some(chain)
  }

  // Returns None if any of the CUs point to missing blocks from the dv, or if
  // the block can't be parsed.
  function ChainFrom(dv: DiskView, firstCU: CU) : (chain:Option<JournalChain>)
  {
    ChainFromInner(dv, Some(firstCU))
  }

  function MessageMaps(journalChain: JournalChain) : seq<MsgMap> {
    seq(|journalChain|,
      i requires 0<=i<|journalChain|
        => var mm := journalChain[i].messageMap; mm)
  }

  function IM(dv: DiskView, sb: Superblock) : MsgMap
  {
    var chain := ChainFrom(dv, sb.firstCU);
    if chain.Some?
    then
      MsgMapMod.ConcatSeq(MessageMaps(chain.value))
    else
      MsgMapMod.Empty()
  }

  function IReads(dv: DiskView, firstCU: CU) : set<AU>
  {
    var chain := ChainFrom(dv, firstCU);
    if chain.None?
    then {}
    else
      var cus := CUsForChain(firstCU, chain.value);
      set i | 0<=i<|chain.value| :: cus[i].au
  }

  predicate EqualAt(dv0: DiskView, dv1: DiskView, cu: CU)
    requires cu in dv0
    requires cu in dv1
  {
    dv0[cu]==dv1[cu]
  }

  predicate Member(dv: DiskView, cu: CU)
  {
    cu in dv
  }

  predicate DiskViewsEquivalentForSet(dv0: DiskView, dv1: DiskView, aus: set<AU>)
  {
    && (forall cu:CU :: cu.au in aus ==> Member(dv0, cu))
    && (forall cu:CU :: cu.au in aus ==> Member(dv1, cu))
    && (forall cu:CU :: cu.au in aus ==> EqualAt(dv0, dv1, cu))
  }

  lemma ValidTruncatedChain(dv: DiskView, firstCU: CU, c: JournalChain)
    requires ValidJournalChain(dv, firstCU, c)
    requires 1<|c|
    ensures c[0].nextCU.Some? // boilerplate for next line
    ensures ValidJournalChain(dv, c[0].nextCU.value, c[1..])
  {
    reveal_ChainMatchesDiskView();
    reveal_WFChainInner();
  }

  lemma UniqueChain(dv: DiskView, firstCU: CU, c0: JournalChain, c1: JournalChain)
    requires ValidJournalChain(dv, firstCU, c0)
    requires ValidJournalChain(dv, firstCU, c1)
    ensures c0 == c1
    decreases |c0|
  {
    reveal_ChainMatchesDiskView();
    if |c1|<|c0| {
      UniqueChain(dv, firstCU, c1, c0);
    } else {
      assert c0[0]==c1[0];
      if 1==|c0| {
        assert 1==|c1|;
      } else {
        ValidTruncatedChain(dv, firstCU, c0);
        ValidTruncatedChain(dv, firstCU, c1);
        UniqueChain(dv, c0[0].nextCU.value, c0[1..], c1[1..]);
      }
    }
  }

  lemma FrameOneChain(dv0: DiskView, dv1: DiskView, firstCU: Option<CU>, chain: Option<JournalChain>)
    requires chain == ChainFromInner(dv0, firstCU)
    requires firstCU.Some? ==> DiskViewsEquivalentForSet(dv0, dv1, IReads(dv0, firstCU.value))
    ensures chain == ChainFromInner(dv1, firstCU)
  {
    
    if firstCU.None? {
      assert chain == ChainFromInner(dv1, firstCU);
    } else if firstCU.value !in dv0 {
      assert IReads(dv0, firstCU.value) == {};
      assert firstCU.value !in dv1;
      assert chain == ChainFromInner(dv1, firstCU);
    } else {
      assert chain == ChainFromInner(dv1, firstCU);
//      var firstRec := parse(dv[firstCU.value]);
//      if firstRec.None? then
//        None  // !RecordOnDisk
//      else
//        var rest := ChainFromInner(MapRemove1(dv, firstCU.value), firstRec.value.nextCU);
//        if rest.None? // tail didn't decode or
//          // tail decoded but head doesn't stitch to it (a cross-crash invariant)
//          || (0<|rest.value| && firstRec.value.seqStart != rest.value[0].seqEnd)
//        then
//          None  // failure in recursive call
//        else
//          var chain := [firstRec.value] + rest.value;
//          assert ValidJournalChain(dv, firstCU.value, chain) by {
//            reveal_WFChainInner();
//            reveal_ChainMatchesDiskView();
//            forall i | 0<=i<|chain|-1
//              ensures chain[i].seqStart == chain[i+1].seqEnd
//            {
//              if i==0 {
//                calc {
//                  chain[i].seqStart;
//                  rest.value[0].seqEnd;
//                  chain[i+1].seqEnd;
//                }
//                assert chain[i].seqStart == chain[i+1].seqEnd;
//              } else {
//                calc {
//                  chain[i].seqStart;
//                  rest.value[i-1].seqStart;
//                  rest.value[i].seqEnd;
//                  chain[i+1].seqEnd;
//                }
//              }
//            }
//            assert WFChain(chain);
//            var cus := CUsForChain(firstCU.value, chain);
//            forall i | 0<=i<|chain|
//              ensures RecordOnDisk(dv, cus[i], chain[i])
//            {
//            }
//          }
//          Some(chain)
    }
  }

  lemma UniqueChainFrom(dv: DiskView, firstCU: CU, chain0: Option<JournalChain>, chain1: Option<JournalChain>)
    requires chain0 == ChainFrom(dv, firstCU);
    requires chain1 == ChainFrom(dv, firstCU);
    ensures chain0 == chain1
  {
  }

  lemma Framing(sb:Superblock, dv0: DiskView, dv1: DiskView)
    requires DiskViewsEquivalentForSet(dv0, dv1, IReads(dv0, sb.firstCU))
    ensures IM(dv0, sb) == IM(dv1, sb)
  {
    var chain0 := ChainFrom(dv0, sb.firstCU);
    var chain1 := ChainFrom(dv1, sb.firstCU);
    FrameOneChain(dv0, dv1, Some(sb.firstCU), chain0);
    assert chain0 == ChainFrom(dv1, sb.firstCU);
    UniqueChainFrom(dv0, sb.firstCU, chain0, chain1);
    if chain0.Some? {
      assert chain1.Some?;
//      FrameOneChain(dv0, dv1, sb.firstCU, chain0.value);
//      UniqueChain(dv1, sb.firstCU, chain0.value, chain1.value);
//      assert chain0 == chain1;
      calc {
        IM(dv0, sb);
        MsgMapMod.ConcatSeq(MessageMaps(chain0.value));
        MsgMapMod.ConcatSeq(MessageMaps(chain1.value));
        IM(dv1, sb);
      }
    } else {
      assert chain0.None?;
      assert chain1.None?;
      assert IM(dv0, sb) == IM(dv1, sb);
    }
  }
}

module MarshalledSnapshot {
  import opened AllocationMod
  import opened NativeTypes

  datatype SnapshotSuperblock = SnapshotSuperblock(firstCU: CU)

  datatype Block = Block()
  type Snapshot = seq<Block>

  predicate ValidSnapshot(dv: DiskView, snapshot: Snapshot) {
    false // TODO
  }

  function IBytes(dv: DiskView, sb: SnapshotSuperblock) : seq<byte> {
    if (exists snapshot :: ValidSnapshot(dv, snapshot))
    then
      // TODO decode all the blocks
      []
    else
      []
  }
}

module AllocationTableMod refines MarshalledSnapshot {
  import opened Options

  datatype Superblock = Superblock(snapshot: SnapshotSuperblock)

  type AllocationTable = set<AU>

  function parse(b: seq<byte>) : Option<AllocationTable>
    // TODO

  function I(dv: DiskView, sb: Superblock) : Option<AllocationTable> {
    parse(IBytes(dv, sb.snapshot))
  }
}

module IndirectionTableMod refines MarshalledSnapshot {
  import opened Options

  datatype Superblock = Superblock(snapshot: SnapshotSuperblock)

  type IndirectionTable = map<nat, AU>

  function parse(b: seq<byte>) : Option<IndirectionTable>

  function I(dv: DiskView, sb: Superblock) : Option<IndirectionTable> {
    parse(IBytes(dv, sb.snapshot))
  }
}

module BetreeMod {
  import opened Options
  import opened MessageMod
  import opened AllocationMod
  import opened MsgSeqMod
  import opened MsgMapMod
  import opened IndirectionTableMod

  datatype Superblock = Superblock(itbl: IndirectionTableMod.Superblock, rootIdx: IndirectionTableMod.IndirectionTable)

  datatype LookupRecord = LookupRecord(
    cu: CU
  )
  type Lookup = seq<LookupRecord>

  function LookupToMsgSeq(lookup: Lookup) : MsgSeq
    // TODO body

  predicate ValidLookup(dv: DiskView, itbl: IndirectionTable, key: Key, lookup: Lookup)
    // TODO

  function IMKey(dv: DiskView, sb: Superblock, key: Key) : MsgSeq
  {
    var itbl := IndirectionTableMod.I(dv, sb.itbl);
    if
      && itbl.Some?
      && exists lookup :: ValidLookup(dv, itbl.value, key, lookup)
    then
      var lookup :| ValidLookup(dv, itbl.value, key, lookup);
      LookupToMsgSeq(lookup)
    else
      []
  }

  function IM(dv: DiskView, sb: Superblock) : MsgMap
  {
    imap key | key in AllKeys() :: IMKey(dv, sb, key)
  }

  function IReadsKey(dv: DiskView, itbl: Option<IndirectionTable>, key: Key) : set<AU> {
    
    if
      && itbl.Some?
      && exists lookup :: ValidLookup(dv, itbl.value, key, lookup)
    then
      var lookup :| ValidLookup(dv, itbl.value, key, lookup);
      set i | 0<=i<|lookup| :: var lr:LookupRecord := lookup[i]; lr.cu.au
    else
      {}
  }

  function IReads(dv: DiskView, sb: Superblock) : set<AU> {
    var itbl := IndirectionTableMod.I(dv, sb.itbl);
    set au:AU |
      && au < AUSizeInBlocks()
      && exists key :: au in IReadsKey(dv, itbl, key)
  }

  lemma Framing(sb:Superblock, dv0: DiskView, dv1: DiskView)
    requires forall cu:CU :: cu.au in IReads(dv0, sb) ==>
      && cu in dv0
      && cu in dv1
      && dv0[cu]==dv1[cu]
    ensures IM(dv0, sb) == IM(dv1, sb)
  {
    // TODO I'm surprised this proof passes easily.
    forall key | key in AllKeys()
      ensures IMKey(dv0, sb, key) == IMKey(dv1, sb, key)
    {
      var itbl0 := IndirectionTableMod.I(dv0, sb.itbl);
      var itbl1 := IndirectionTableMod.I(dv1, sb.itbl);
      if itbl0.Some? && itbl1.Some?
      {
        var le0 := exists lookup0 :: ValidLookup(dv0, itbl0.value, key, lookup0);
        var le1 := exists lookup1 :: ValidLookup(dv1, itbl1.value, key, lookup1);
        if le0 {
          var lookup0 :| ValidLookup(dv0, itbl0.value, key, lookup0);
          assert ValidLookup(dv1, itbl1.value, key, lookup0);
        }
        if le1 {
          var lookup1 :| ValidLookup(dv1, itbl1.value, key, lookup1);
          assert ValidLookup(dv0, itbl1.value, key, lookup1);
        }
        assert le0 == le1;
      }
    }
  }
}

// It's funky that the allocation table is going to reserve its own
// blocks, but it's actually okay: we reserve them in the in-memory
// representation, then emit them once we've frozen a given view.

module System {
  import opened Options
  import opened MessageMod
  import opened AllocationMod
  import opened MsgSeqMod
  import opened MsgMapMod
  import AllocationTableMod
  import JournalMod
  import BetreeMod

  datatype Superblock = Superblock(
    serial: nat,
    journal: JournalMod.Superblock,
    allocation: AllocationTableMod.Superblock,
    betree: BetreeMod.Superblock)

  function parseSuperblock(b: UninterpretedDiskPage) : Option<Superblock>

  function ISuperblock(dv: DiskView) : Option<Superblock>
  {
    var bcu0 := CU(0, 0);
    var bcu1 := CU(0, 1);
    if bcu0 in dv && bcu1 in dv
    then
      var sb0 := parseSuperblock(dv[bcu0]);
      var sb1 := parseSuperblock(dv[bcu1]);
      if sb0.Some? && sb1.Some? && sb0.value.serial == sb1.value.serial
      then
        sb0
      else
        None  // Stop! Recovery should ... copy the newer one?
    else
      None  // silly expression: DV has holes in it
  }

  function ISuperblockReads(dv: DiskView) : set<AU>
  {
    {0}
  }
 
  // IM == Interpret as MsgSeq
  // Oh man we're gonna have a family of IReads predicates that capture the
  // heapiness of DiskView, aren't we?
  function IM(dv: DiskView) : MsgMap
  {
    var sb := ISuperblock(dv);
    if sb.Some?
    then
      JournalMod.IM(dv, sb.value.journal) + BetreeMod.IM(dv, sb.value.betree)
    else
      MsgMapMod.Empty()
  }

  function IMReads(dv: DiskView) : set<AU> {
      {}
      /*
    var sb := ISuperblock(dv);
    if sb.Some?
    then
      JournalMod.IReads(dv, sb.value.journal) + BetreeMod.IReads(dv, sb.value.betree)
    else
      set{}
      */
  }

  function I(dv: DiskView) : imap<Key, Value> {
    MsgMapMod.I(IM(dv))
  }

  function IReads(dv: DiskView) : set<AU> {
    IMReads(dv)
  }

  lemma Framing(dv0: DiskView, dv1: DiskView)
  /*
    requires forall cu:CU :: cu.au in IReads(dv0) ==>
      && cu in dv0
      && cu in dv1
      && dv0[cu]==dv1[cu]
      */
    ensures I(dv0) == I(dv1)
  {
    //assert forall k :: k !in I(dv0);
    assert forall k :: I(dv0)[k] == I(dv1)[k];
  }
}

/*
Okay, so the magic is going to be that
- most of the time when we change a block in RAM we'll prove that it's
  not in use in any other view
  - that'll depend on an invariant between the allocation table
    and the IReads functions
  - And we'll need a proof that, if IReads doesn't change, I doesn't
    change, of course.
- when we write a non-superblock back to disk, we inherit that no-change
  property; the persistent view doesn't change because the thing
  we wrote back was dirty and hence outside of the IReads of the
  persistent view.
- when we update the superblock, we're creating a frozen view.
- when we write a superblock back, it's easy again, because the persistent
  view just vanishes, replaced by the frozen view.
  The vanishing old persistent view implicitly creates some free nodes,
  which can be detected because the available nodes are computed at
  runtime by reading the active AllocationTables, and one just became
  empty.
  (that is, the union of allocationTables will cover the IReads sets.)
*/
