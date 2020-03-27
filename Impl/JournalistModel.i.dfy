include "../ByteBlockCacheSystem/JournalBytes.i.dfy"
include "../BlockCacheSystem/DiskLayout.i.dfy"
include "JournalistMarshallingModel.i.dfy"

module JournalistModel {
  import opened DiskLayout
  import opened NativeTypes
  import opened Options

  import opened JournalRanges`Internal
  import opened JournalBytes
  import opened Journal
  import opened JournalistMarshallingModel

  datatype JournalInfo = JournalInfo(
    inMemoryJournalFrozen: seq<JournalEntry>,
    inMemoryJournal: seq<JournalEntry>,
    replayJournal: seq<JournalEntry>,

    journalFrontRead: Option<JournalRange>,
    journalBackRead: Option<JournalRange>,

    ghost writtenLen: int
  )

  datatype JournalistModel = JournalistModel(
    journalEntries: seq<JournalEntry>,
    start: uint64,
    len1: uint64,
    len2: uint64,

    replayJournal: seq<JournalEntry>,
    replayIdx: uint64,

    journalFrontRead: Option<seq<byte>>,
    journalBackRead: Option<seq<byte>>,
    
    // number of blocks already written on disk:
    writtenJournalBlocks: uint64,
    // number of *blocks* of inMemoryJournalFrozen:
    frozenJournalBlocks: uint64,
    // number of *bytes* of inMemoryJournal:
    inMemoryWeight: uint64
  )

  function method Len() : uint64 { 1048576 }

  function method basic_mod(x: uint64) : uint64
  {
    if x >= Len() then x - Len() else x
  }

  predicate WF(jm: JournalistModel)
  {
    && |jm.journalEntries| == Len() as int
    && 0 <= jm.start < Len()
    && 0 <= jm.len1 <= Len()
    && 0 <= jm.len2 <= Len()
    && 0 <= jm.len1 + jm.len2 <= Len()
    && 0 <= jm.replayIdx as int <= |jm.replayJournal|
    && (jm.journalFrontRead.Some? ==>
        JournalRangeOfByteSeq(jm.journalFrontRead.value).Some?)
    && (jm.journalBackRead.Some? ==>
        JournalRangeOfByteSeq(jm.journalBackRead.value).Some?)
    && 0 <= jm.writtenJournalBlocks <= NumJournalBlocks()
    && 0 <= jm.frozenJournalBlocks <= NumJournalBlocks()
    && 0 <= jm.inMemoryWeight <= NumJournalBlocks() * 4096
  }

  function IJournalRead(j: Option<seq<byte>>) : Option<JournalRange>
  requires j.Some? ==> JournalRangeOfByteSeq(j.value).Some?
  {
    if j.Some? then JournalRangeOfByteSeq(j.value) else None
  }

  function start(jm: JournalistModel) : uint64
  {
    jm.start
  }

  function mid(jm: JournalistModel) : uint64
  requires jm.start < Len()
  requires jm.len1 <= Len()
  {
    basic_mod(jm.start + jm.len1)
  }

  function end(jm: JournalistModel) : uint64
  requires jm.start < Len()
  requires jm.len1 <= Len()
  requires jm.len2 <= Len()
  {
    basic_mod(jm.start + jm.len1 + jm.len2)
  }

  function InMemoryJournalFrozen(jm: JournalistModel) : seq<JournalEntry>
  requires WF(jm)
  {
    cyclicSlice(jm.journalEntries, start(jm), jm.len1)
  }

  function InMemoryJournal(jm: JournalistModel) : seq<JournalEntry>
  requires WF(jm)
  {
    cyclicSlice(jm.journalEntries, mid(jm), jm.len2)
  }

  function ReplayJournal(jm: JournalistModel) : seq<JournalEntry>
  requires 0 <= jm.replayIdx as int <= |jm.replayJournal|
  {
    jm.replayJournal[jm.replayIdx..]
  }

  function JournalFrontRead(jm: JournalistModel) : Option<JournalRange>
  requires WF(jm)
  {
    IJournalRead(jm.journalFrontRead)
  }

  function JournalBackRead(jm: JournalistModel) : Option<JournalRange>
  requires WF(jm)
  {
    IJournalRead(jm.journalBackRead)
  }

  function WrittenJournalLen(jm: JournalistModel) : int
  {
    jm.writtenJournalBlocks as int
  }

  protected function I(jm: JournalistModel) : JournalInfo
  requires WF(jm)
  {
    JournalInfo(
      InMemoryJournalFrozen(jm),
      InMemoryJournal(jm),
      ReplayJournal(jm),
      JournalFrontRead(jm),
      JournalBackRead(jm),
      WrittenJournalLen(jm)
    )
  }

  predicate Inv(jm: JournalistModel)
  {
    && WF(jm)
    && (jm.writtenJournalBlocks + jm.frozenJournalBlocks) * 4064 +
        jm.inMemoryWeight <= 4064 * NumJournalBlocks()
    && WeightJournalEntries(InMemoryJournalFrozen(jm)) <= jm.frozenJournalBlocks as int * 4064
    && WeightJournalEntries(InMemoryJournal(jm)) == jm.inMemoryWeight as int
  }

  ///// Steps you can take

  function {:opaque} hasFrozenJournal(jm: JournalistModel) : (b: bool)
  requires Inv(jm)
  ensures b == (I(jm).inMemoryJournalFrozen == [])
  {
    jm.len1 == 0    
  }

  function {:opaque} packageFrozenJournal(jm: JournalistModel)
      : (res : (JournalistModel, seq<byte>))
  requires Inv(jm)
  requires I(jm).inMemoryJournalFrozen != []
  ensures var (jm', s) := res;
    && Inv(jm')
    && JournalRangeOfByteSeq(s).Some?
    && parseJournalRange(JournalRangeOfByteSeq(s).value) == Some(I(jm).inMemoryJournalFrozen)
    && I(jm') == I(jm)
          .(inMemoryJournalFrozen := [])
          .(writtenLen := I(jm).writtenLen
                + |JournalRangeOfByteSeq(s).value|)
  {
    var s := marshallJournalEntries(jm.journalEntries, jm.start, jm.len1, jm.frozenJournalBlocks);
    var jm' := jm.(start := basic_mod(jm.start + jm.len1))
                 .(len1 := 0)
                 .(frozenJournalBlocks := 0)
                 .(writtenJournalBlocks := jm.writtenJournalBlocks + jm.frozenJournalBlocks);
    (jm', s)
  }

  function {:opaque} packageInMemoryJournal(jm: JournalistModel)
      : (res : (JournalistModel, seq<byte>))
  requires Inv(jm)
  requires I(jm).inMemoryJournalFrozen == []
  requires I(jm).inMemoryJournal != []
  ensures var (jm', s) := res;
    && Inv(jm')
    && JournalRangeOfByteSeq(s).Some?
    && parseJournalRange(JournalRangeOfByteSeq(s).value) == Some(I(jm).inMemoryJournal)
    && I(jm') == I(jm)
          .(inMemoryJournal := [])
          .(writtenLen := I(jm).writtenLen
                + |JournalRangeOfByteSeq(s).value|)
  {
    var numBlocks := (jm.inMemoryWeight + 4064 - 1) / 4064;
    var s := marshallJournalEntries(jm.journalEntries, jm.start, jm.len2, numBlocks);
    var jm' := jm.(start := 0)
                 .(len2 := 0)
                 .(inMemoryWeight := 0)
                 .(writtenJournalBlocks := jm.writtenJournalBlocks + numBlocks);
    (jm', s)
  }

  function getWrittenJournalLen(jm: JournalistModel)
      : (len : uint64)
  requires Inv(jm)
  ensures len as int == I(jm).writtenLen
  {
    jm.writtenJournalBlocks    
  }

  /*lemma roundUpOkay(a: int, b: int)
  requires a <= 4064 * b
  ensures ((a + 4064 - 1) / 4064) * 4064 <= 4064 * b
  {
  }*/

  function {:opaque} freeze(jm: JournalistModel) : (jm' : JournalistModel)
  requires Inv(jm)
  requires I(jm).inMemoryJournalFrozen == []
  requires I(jm).inMemoryJournal != []
  ensures
    && Inv(jm')
    && I(jm') == I(jm)
          .(inMemoryJournal := [])
          .(inMemoryJournalFrozen :=
              I(jm).inMemoryJournalFrozen + I(jm).inMemoryJournal)
  {
    jm.(len1 := jm.len1 + jm.len2)
      .(len2 := 0)
      .(frozenJournalBlocks := jm.frozenJournalBlocks + (jm.inMemoryWeight + 4064 - 1) / 4064)
      .(inMemoryWeight := 0)
  }
}
