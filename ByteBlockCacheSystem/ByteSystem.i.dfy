include "AsyncDiskModel.s.dfy"
include "ByteCache.i.dfy"
include "InterpretationDisk.i.dfy"
include "../BlockCacheSystem/BetreeJournalSystem.i.dfy"

module ByteSystem refines AsyncDiskModel {
  import M = ByteCache

  import opened AsyncSectorDiskModelTypes
  import opened Maps
  import BC = BlockCache
  import JC = JournalCache
  import BJC = BlockJournalCache
  import BJD = BlockJournalDisk
  import opened DiskLayout
  import opened JournalIntervals
  import opened InterpretationDisk
  import opened InterpretationDiskOps
  import opened SectorType
  import opened Options
  import opened JournalRanges
  import BetreeJournalSystem
  import BetreeSystem
  import JournalSystem

  ///// reqWrites are correct

  predicate ReqWriteNodeLocation(reqWrite: D.ReqWrite)
  {
    && |reqWrite.bytes| < 0x1_0000_0000_0000_0000
    && ValidNodeLocation(LocOfReqWrite(reqWrite))
  }

  predicate ReqWriteIndirectionTableLocation(reqWrite: D.ReqWrite)
  {
    && |reqWrite.bytes| < 0x1_0000_0000_0000_0000
    && ValidIndirectionTableLocation(LocOfReqWrite(reqWrite))
  }

  predicate ReqWriteJournalLocation(reqWrite: D.ReqWrite)
  {
    && |reqWrite.bytes| < 0x1_0000_0000_0000_0000
    && ValidJournalLocation(LocOfReqWrite(reqWrite))
  }

  predicate ReqWriteSuperblockLocation(reqWrite: D.ReqWrite)
  {
    && |reqWrite.bytes| < 0x1_0000_0000_0000_0000
    && ValidSuperblockLocation(LocOfReqWrite(reqWrite))
  }

  predicate reqWritesHaveValidNodes(reqWrites: map<D.ReqId, D.ReqWrite>)
  {
    forall id | id in reqWrites ::
        ReqWriteNodeLocation(reqWrites[id]) ==>
          ValidNodeBytes(reqWrites[id].bytes)
  }

  predicate reqWritesHaveValidIndirectionTables(reqWrites: map<D.ReqId, D.ReqWrite>)
  {
    forall id | id in reqWrites ::
        ReqWriteIndirectionTableLocation(reqWrites[id]) ==>
          ValidIndirectionTableBytes(reqWrites[id].bytes)
  }

  predicate reqWritesHaveValidJournals(reqWrites: map<D.ReqId, D.ReqWrite>)
  {
    forall id | id in reqWrites ::
        ReqWriteJournalLocation(reqWrites[id]) ==>
          ValidJournalBytes(reqWrites[id].bytes)
  }

  predicate reqWritesHaveValidSuperblocks(reqWrites: map<D.ReqId, D.ReqWrite>)
  {
    forall id | id in reqWrites ::
        ReqWriteSuperblockLocation(reqWrites[id]) ==>
          ValidSuperblockBytes(reqWrites[id].bytes)
  }

  predicate reqWritesHaveValidData(reqWrites: map<D.ReqId, D.ReqWrite>)
  {
    && reqWritesHaveValidNodes(reqWrites)
    && reqWritesHaveValidIndirectionTables(reqWrites)
    && reqWritesHaveValidJournals(reqWrites)
    && reqWritesHaveValidSuperblocks(reqWrites)
  }


  ///// get operation from Loc

  function ReqReadWithLoc(reqReads: map<D.ReqId, D.ReqRead>, loc: Location) : Option<D.ReqId>
  {
    if id :| id in reqReads && LocOfReqRead(reqReads[id]) == loc then
      Some(id)
    else
      None
  }

  function ReqWriteWithLoc(reqWrites: map<D.ReqId, D.ReqWrite>, loc: Location) : Option<D.ReqId>
  {
    if id :| id in reqWrites
        && |reqWrites[id].bytes| < 0x1_0000_0000_0000_0000
        && LocOfReqWrite(reqWrites[id]) == loc then
      Some(id)
    else
      None
  }

  function RespReadWithLoc(respReads: map<D.ReqId, D.RespRead>, loc: Location) : Option<D.ReqId>
  {
    if id :| id in respReads
        && |respReads[id].bytes| < 0x1_0000_0000_0000_0000
        && LocOfRespRead(respReads[id]) == loc then
      Some(id)
    else
      None
  }

  function RespWriteWithLoc(respWrites: map<D.ReqId, D.RespWrite>, loc: Location) : Option<D.ReqId>
  {
    if id :| id in respWrites && LocOfRespWrite(respWrites[id]) == loc then
      Some(id)
    else
      None
  }

  //// Superblocks

  predicate HasSuperblockAtLoc(disk: D.Variables, loc: Location)
  {
    && 0 <= loc.addr as int
      <= loc.addr as int + loc.len as int
      <= |disk.contents|
    && ValidSuperblockBytes(
        disk.contents[loc.addr .. loc.addr as int + loc.len as int])
  }

  function SuperblockAtLoc(disk: D.Variables, loc: Location) : Superblock
  requires HasSuperblockAtLoc(disk, loc)
  {
    SuperblockOfBytes(
        disk.contents[loc.addr .. loc.addr as int + loc.len as int])
  }

  function SuperblockAtLocOpt(disk: D.Variables, loc: Location) : Option<Superblock>
  {
    if HasSuperblockAtLoc(disk, loc) then
      Some(SuperblockAtLoc(disk,loc))
    else
      None
  }

  function ReqReadSuperblockAtLoc(disk: D.Variables, loc: Location) : Option<D.ReqId>
  {
    var id1 := ReqReadWithLoc(disk.reqReads, loc);
    var id2 := RespReadWithLoc(disk.respReads, loc);
    if id1.None? then id2 else id1
  }

  function ReqWriteSuperblockAtLoc(disk: D.Variables, loc: Location) : Option<JournalDisk.ReqWriteSuperblockId>
  requires ValidSuperblockLocation(loc)
  requires reqWritesHaveValidSuperblocks(disk.reqWrites)
  {
    var id := ReqWriteWithLoc(disk.reqWrites, loc);
    if id.Some? then
      Some(JournalDisk.ReqWriteSuperblockId(
        id.value,
        JournalDisk.ReqWriteSuperblock(SuperblockOfBytes(disk.reqWrites[id.value].bytes))
      ))
    else (
      var id2 := RespWriteWithLoc(disk.respWrites, loc);
      if id2.Some? && HasSuperblockAtLoc(disk, loc) then
        Some(JournalDisk.ReqWriteSuperblockId(
          id2.value,
          JournalDisk.ReqWriteSuperblock(SuperblockAtLoc(disk, loc))
        ))
      else
        None
    )
  }

  function Superblock1(disk: D.Variables) : Option<Superblock>
  {
    SuperblockAtLocOpt(disk, Superblock1Location())
  }

  function Superblock2(disk: D.Variables) : Option<Superblock>
  {
    SuperblockAtLocOpt(disk, Superblock2Location())
  }

  function ReqReadSuperblock1(disk: D.Variables) : Option<JournalDisk.ReqId>
  {
    ReqReadSuperblockAtLoc(disk, Superblock1Location())
  }

  function ReqReadSuperblock2(disk: D.Variables) : Option<JournalDisk.ReqId>
  {
    ReqReadSuperblockAtLoc(disk, Superblock2Location())
  }

  function ReqWriteSuperblock1(disk: D.Variables) : Option<JournalDisk.ReqWriteSuperblockId>
  requires reqWritesHaveValidSuperblocks(disk.reqWrites)
  {
    ReqWriteSuperblockAtLoc(disk, Superblock1Location())
  }

  function ReqWriteSuperblock2(disk: D.Variables) : Option<JournalDisk.ReqWriteSuperblockId>
  requires reqWritesHaveValidSuperblocks(disk.reqWrites)
  {
    ReqWriteSuperblockAtLoc(disk, Superblock2Location())
  }

  //// Journals

  function ReqReadJournals_of_reqs(disk: D.Variables) : map<D.ReqId, JournalInterval>
  {
    map id | id in disk.reqReads &&
        ValidJournalLocation(LocOfReqRead(disk.reqReads[id]))
      :: JournalIntervalOfLocation(LocOfReqRead(disk.reqReads[id]))
  }

  function ReqReadJournals_of_resps(disk: D.Variables) : map<D.ReqId, JournalInterval>
  {
    map id | id in disk.respReads
      && |disk.respReads[id].bytes| < 0x1_0000_0000_0000_0000
      && ValidJournalLocation(LocOfRespRead(disk.respReads[id]))
      :: JournalIntervalOfLocation(LocOfRespRead(disk.respReads[id]))
  }

  function ReqReadJournals(disk: D.Variables) : map<D.ReqId, JournalInterval>
  {
    MapUnion(
        ReqReadJournals_of_reqs(disk), 
        ReqReadJournals_of_resps(disk))
  }

  function ReqWriteJournals_of_reqs(disk: D.Variables) : map<D.ReqId, JournalInterval>
  {
    map id | id in disk.reqWrites
      && |disk.reqWrites[id].bytes| < 0x1_0000_0000_0000_0000
      && ValidJournalLocation(LocOfReqWrite(disk.reqWrites[id]))
      :: JournalIntervalOfLocation(LocOfReqWrite(disk.reqWrites[id]))
  }

  function ReqWriteJournals_of_resps(disk: D.Variables) : map<D.ReqId, JournalInterval>
  {
    map id | id in disk.respWrites
      && ValidJournalLocation(LocOfRespWrite(disk.respWrites[id]))
      :: JournalIntervalOfLocation(LocOfRespWrite(disk.respWrites[id]))
  }

  function ReqWriteJournals(disk: D.Variables) : map<D.ReqId, JournalInterval>
  {
    MapUnion(
        ReqWriteJournals_of_reqs(disk), 
        ReqWriteJournals_of_resps(disk))
  }

  //// IndirectionTables

  function ReqReadIndirectionTables_of_reqs(disk: D.Variables) : map<D.ReqId, Location>
  {
    map id | id in disk.reqReads &&
        ValidIndirectionTableLocation(LocOfReqRead(disk.reqReads[id]))
      :: LocOfReqRead(disk.reqReads[id])
  }

  function ReqReadIndirectionTables_of_resps(disk: D.Variables) : map<D.ReqId, Location>
  {
    map id | id in disk.respReads
      && |disk.respReads[id].bytes| < 0x1_0000_0000_0000_0000
      && ValidIndirectionTableLocation(LocOfRespRead(disk.respReads[id]))
      :: LocOfRespRead(disk.respReads[id])
  }

  function ReqReadIndirectionTables(disk: D.Variables) : map<D.ReqId, Location>
  {
    MapUnion(
        ReqReadIndirectionTables_of_reqs(disk), 
        ReqReadIndirectionTables_of_resps(disk))
  }

  function ReqWriteIndirectionTables_of_reqs(disk: D.Variables) : map<D.ReqId, Location>
  {
    map id | id in disk.reqWrites
      && |disk.reqWrites[id].bytes| < 0x1_0000_0000_0000_0000
      && ValidIndirectionTableLocation(LocOfReqWrite(disk.reqWrites[id]))
      :: LocOfReqWrite(disk.reqWrites[id])
  }

  function ReqWriteIndirectionTables_of_resps(disk: D.Variables) : map<D.ReqId, Location>
  {
    map id | id in disk.respWrites
      && ValidIndirectionTableLocation(LocOfRespWrite(disk.respWrites[id]))
      :: LocOfRespWrite(disk.respWrites[id])
  }

  function ReqWriteIndirectionTables(disk: D.Variables) : map<D.ReqId, Location>
  {
    MapUnion(
        ReqWriteIndirectionTables_of_reqs(disk), 
        ReqWriteIndirectionTables_of_resps(disk))
  }

  //// Nodes

  function ReqReadNodes_of_reqs(disk: D.Variables) : map<D.ReqId, Location>
  {
    map id | id in disk.reqReads &&
        ValidNodeLocation(LocOfReqRead(disk.reqReads[id]))
      :: LocOfReqRead(disk.reqReads[id])
  }

  function ReqReadNodes_of_resps(disk: D.Variables) : map<D.ReqId, Location>
  {
    map id | id in disk.respReads
      && |disk.respReads[id].bytes| < 0x1_0000_0000_0000_0000
      && ValidNodeLocation(LocOfRespRead(disk.respReads[id]))
      :: LocOfRespRead(disk.respReads[id])
  }

  function ReqReadNodes(disk: D.Variables) : map<D.ReqId, Location>
  {
    MapUnion(
        ReqReadNodes_of_reqs(disk), 
        ReqReadNodes_of_resps(disk))
  }

  function ReqWriteNodes_of_reqs(disk: D.Variables) : map<D.ReqId, Location>
  {
    map id | id in disk.reqWrites
      && |disk.reqWrites[id].bytes| < 0x1_0000_0000_0000_0000
      && ValidNodeLocation(LocOfReqWrite(disk.reqWrites[id]))
      :: LocOfReqWrite(disk.reqWrites[id])
  }

  function ReqWriteNodes_of_resps(disk: D.Variables) : map<D.ReqId, Location>
  {
    map id | id in disk.respWrites
      && ValidNodeLocation(LocOfRespWrite(disk.respWrites[id]))
      :: LocOfRespWrite(disk.respWrites[id])
  }

  function ReqWriteNodes(disk: D.Variables) : map<D.ReqId, Location>
  {
    MapUnion(
        ReqWriteNodes_of_reqs(disk), 
        ReqWriteNodes_of_resps(disk))
  }

  ///////// Interpretation of the disk

  predicate locInBounds(loc: Location, contents: seq<byte>)
  {
    && loc.addr as int + loc.len as int <= |contents|
  }

  function atLoc(loc: Location, contents: seq<byte>) : seq<byte>
  requires locInBounds(loc, contents)
  {
    contents[loc.addr .. loc.addr as int + loc.len as int]
  }

  function DiskNodesOfContents(contents: seq<byte>) : imap<Location, BC.Node>
  {
    imap loc |
      && ValidNodeLocation(loc)
      && locInBounds(loc, contents)
      && ValidNodeBytes(atLoc(loc, contents))
      :: NodeOfBytes(atLoc(loc, contents))
  }

  function DiskNodes(disk: D.Variables) : imap<Location, BC.Node>
  {
    DiskNodesOfContents(withWrites(disk.contents, disk.reqWrites))
  }

  function DiskIndirectionTablesOfContents(contents: seq<byte>) : imap<Location, IndirectionTable>
  {
    imap loc |
      && ValidIndirectionTableLocation(loc)
      && locInBounds(loc, contents)
      && ValidIndirectionTableBytes(atLoc(loc, contents))
      :: IndirectionTableOfBytes(atLoc(loc, contents))
  }

  function DiskIndirectionTables(disk: D.Variables) : imap<Location, IndirectionTable>
  {
    DiskIndirectionTablesOfContents(withWrites(disk.contents, disk.reqWrites))
  }

  predicate ValidJournalBlockBytes(bytes: seq<byte>)
  {
    && D.ChecksumChecksOut(bytes)
    && JournalBytes.JournalBlockOfByteSeq(bytes).Some?
  }

  function JournalBlockOfBytes(bytes: seq<byte>) : JournalBlock
  requires ValidJournalBlockBytes(bytes)
  {
    JournalBytes.JournalBlockOfByteSeq(bytes).value
  }

  function JournalBlockAt(contents: seq<byte>, i: int) : Option<JournalBlock>
  requires 0 <= i < NumJournalBlocks() as int
  {
    var loc := JournalRangeLocation(i as uint64, 1);
    if locInBounds(loc, contents)
      && ValidJournalBlockBytes(atLoc(loc, contents))
    then
      Some(JournalBlockOfBytes(atLoc(loc, contents)))
    else
      None
  }

  function {:opaque} DiskJournalOfContentsI(contents: seq<byte>, i: int) : (res : seq<Option<JournalBlock>>)
  requires 0 <= i <= NumJournalBlocks() as int
  ensures |res| == i
  ensures forall j | 0 <= j < i :: res[j] == JournalBlockAt(contents, j)
  {
    if i == 0 then [] else
      DiskJournalOfContentsI(contents, i-1) + [JournalBlockAt(contents, i-1)]
  }

  function DiskJournalOfContents(contents: seq<byte>) : seq<Option<JournalBlock>>
  {
    DiskJournalOfContentsI(contents, NumJournalBlocks() as int)
  }

  function DiskJournal(disk: D.Variables) : seq<Option<JournalBlock>>
  {
    DiskJournalOfContents(withWrites(disk.contents, disk.reqWrites))
  }

  function DiskSuperblockAtLoc(contents: seq<byte>, loc: Location) : Option<Superblock>
  requires ValidSuperblockLocation(loc)
  {
    if locInBounds(loc, contents)
      && ValidSuperblockBytes(atLoc(loc, contents))
    then Some(SuperblockOfBytes(atLoc(loc, contents)))
    else None
  }

  function DiskSuperblock1(disk: D.Variables) : Option<Superblock>
  {
    DiskSuperblockAtLoc(disk.contents, Superblock1Location())
  }

  function DiskSuperblock2(disk: D.Variables) : Option<Superblock>
  {
    DiskSuperblockAtLoc(disk.contents, Superblock2Location())
  }

  //// Putting stuff together

  function IBlockDisk(disk: D.Variables) : BlockDisk.Variables
  {
    BlockDisk.Variables(
      ReqReadIndirectionTables(disk),
      ReqReadNodes(disk),
      ReqWriteIndirectionTables(disk),
      ReqWriteNodes(disk),
      DiskIndirectionTables(disk),
      DiskNodes(disk)
    )
  }

  function IJournalDisk(disk: D.Variables) : JournalDisk.Variables
  requires reqWritesHaveValidSuperblocks(disk.reqWrites)
  {
    JournalDisk.Variables(
      ReqReadSuperblock1(disk),
      ReqReadSuperblock2(disk),
      ReqReadJournals(disk),
      ReqWriteSuperblock1(disk),
      ReqWriteSuperblock2(disk),
      ReqWriteJournals(disk),
      DiskSuperblock1(disk),
      DiskSuperblock2(disk),
      DiskJournal(disk)
    )
  }

  function Ik(k: Constants) : BetreeJournalSystem.Constants
  {
    BetreeJournalSystem.Constants(
      AsyncSectorDiskModelConstants(BC.Constants(), BlockDisk.Constants()),
      AsyncSectorDiskModelConstants(JC.Constants(), JournalDisk.Constants())
    )
  }

  function I(k: Constants, s: Variables) : BetreeJournalSystem.Variables
  requires reqWritesHaveValidSuperblocks(s.disk.reqWrites)
  {
    BetreeJournalSystem.Variables(
      AsyncSectorDiskModelVariables(s.machine.bc, IBlockDisk(s.disk)),
      AsyncSectorDiskModelVariables(s.machine.jc, IJournalDisk(s.disk))
    )
  }

  predicate Init(k: Constants, s: Variables)
  {
    && D.Init(k.disk, s.disk)
    && BetreeJournalSystem.Init(Ik(k), I(k, s))
  }

  //// Invariant stuff

  predicate reqWritesHaveValidLocations(reqWrites: map<D.ReqId, D.ReqWrite>)
  {
    forall id | id in reqWrites ::
        && |reqWrites[id].bytes| < 0x1_0000_0000_0000_0000
        && ValidLocation(LocOfReqWrite(reqWrites[id]))
  }

  predicate reqReadsHaveValidLocations(reqReads: map<D.ReqId, D.ReqRead>)
  {
    forall id | id in reqReads ::
        ValidLocation(LocOfReqRead(reqReads[id]))
  }

  predicate respWritesHaveValidLocations(respWrites: map<D.ReqId, D.RespWrite>)
  {
    forall id | id in respWrites ::
        ValidLocation(LocOfRespWrite(respWrites[id]))
  }

  predicate respReadsHaveValidLocations(respReads: map<D.ReqId, D.RespRead>)
  {
    forall id | id in respReads ::
        && |respReads[id].bytes| < 0x1_0000_0000_0000_0000
        && ValidLocation(LocOfRespRead(respReads[id]))
  }

  predicate respReadHasCorrectData(contents: seq<byte>, respRead: D.RespRead)
  {
    && |respRead.bytes| < 0x1_0000_0000_0000_0000
    && locInBounds(LocOfRespRead(respRead), contents)
    && atLoc(LocOfRespRead(respRead), contents)
        == respRead.bytes
  }

  predicate respReadsHaveCorrectData(contents: seq<byte>, respReads: map<D.ReqId, D.RespRead>)
  {
    forall id | id in respReads ::
        respReadHasCorrectData(contents, respReads[id])
  }

  predicate writesOverlap(r1: D.ReqWrite, r2: D.ReqWrite)
  requires |r1.bytes| < 0x1_0000_0000_0000_0000
  requires |r2.bytes| < 0x1_0000_0000_0000_0000
  {
    overlap(LocOfReqWrite(r1), LocOfReqWrite(r2))
  }

  predicate allWritesDontOverlap(reqWrites: map<D.ReqId, D.ReqWrite>)
  requires reqWritesHaveValidLocations(reqWrites)
  {
    forall id1, id2 ::
      id1 in reqWrites && id2 in reqWrites && id1 != id2
      ==> !writesOverlap(reqWrites[id1], reqWrites[id2])
  }

  predicate writeReqReadOverlap(r1: D.ReqWrite, r2: D.ReqRead)
  requires |r1.bytes| < 0x1_0000_0000_0000_0000
  {
    overlap(LocOfReqWrite(r1), LocOfReqRead(r2))
  }

  predicate allWritesReqReadsDontOverlap(reqWrites: map<D.ReqId, D.ReqWrite>, reqReads: map<D.ReqId, D.ReqRead>)
  requires reqWritesHaveValidLocations(reqWrites)
  {
    forall id1, id2 ::
      id1 in reqWrites && id2 in reqReads
      ==> !writeReqReadOverlap(reqWrites[id1], reqReads[id2])
  }

  predicate writeRespReadOverlap(r1: D.ReqWrite, r2: D.RespRead)
  requires |r1.bytes| < 0x1_0000_0000_0000_0000
  requires |r2.bytes| < 0x1_0000_0000_0000_0000
  {
    overlap(LocOfReqWrite(r1), LocOfRespRead(r2))
  }

  predicate allWritesRespReadsDontOverlap(reqWrites: map<D.ReqId, D.ReqWrite>, respReads: map<D.ReqId, D.RespRead>)
  requires reqWritesHaveValidLocations(reqWrites)
  requires respReadsHaveValidLocations(respReads)
  {
    forall id1, id2 ::
      id1 in reqWrites && id2 in respReads
      ==> !writeRespReadOverlap(reqWrites[id1], respReads[id2])
  }

  ///// respWrites are correct

  predicate respWritesHaveValidNodes(contents: seq<byte>, respWrites: map<D.ReqId, D.RespWrite>)
  {
    forall id | id in respWrites ::
        ValidNodeLocation(LocOfRespWrite(respWrites[id])) ==>
          && locInBounds(LocOfRespWrite(respWrites[id]), contents)
          && ValidNodeBytes(atLoc(LocOfRespWrite(respWrites[id]), contents))
  }

  predicate respWritesHaveValidIndirectionTables(contents: seq<byte>, respWrites: map<D.ReqId, D.RespWrite>)
  {
    forall id | id in respWrites ::
        ValidIndirectionTableLocation(LocOfRespWrite(respWrites[id])) ==>
          && locInBounds(LocOfRespWrite(respWrites[id]), contents)
          && ValidIndirectionTableBytes(atLoc(LocOfRespWrite(respWrites[id]), contents))
  }

  predicate respWritesHaveValidJournals(contents: seq<byte>, respWrites: map<D.ReqId, D.RespWrite>)
  {
    forall id | id in respWrites ::
        ValidJournalLocation(LocOfRespWrite(respWrites[id])) ==>
          && locInBounds(LocOfRespWrite(respWrites[id]), contents)
          && ValidJournalBytes(atLoc(LocOfRespWrite(respWrites[id]), contents))
  }

  predicate respWritesHaveValidSuperblocks(contents: seq<byte>, respWrites: map<D.ReqId, D.RespWrite>)
  {
    forall id | id in respWrites ::
        ValidSuperblockLocation(LocOfRespWrite(respWrites[id])) ==>
          && locInBounds(LocOfRespWrite(respWrites[id]), contents)
          && ValidSuperblockBytes(atLoc(LocOfRespWrite(respWrites[id]), contents))
  }

  predicate respWritesHaveValidData(contents: seq<byte>, respWrites: map<D.ReqId, D.RespWrite>)
  {
    && respWritesHaveValidNodes(contents, respWrites)
    && respWritesHaveValidIndirectionTables(contents, respWrites)
    && respWritesHaveValidJournals(contents, respWrites)
    && respWritesHaveValidSuperblocks(contents, respWrites)
  }

  ///// Define Inv

  predicate Inv(k: Constants, s: Variables)
  {
    && reqWritesHaveValidLocations(s.disk.reqWrites)
    && reqReadsHaveValidLocations(s.disk.reqReads)
    && respWritesHaveValidLocations(s.disk.respWrites)
    && respReadsHaveValidLocations(s.disk.respReads)
    && respReadsHaveCorrectData(s.disk.contents, s.disk.respReads)
    && reqWritesHaveValidData(s.disk.reqWrites)
    && respWritesHaveValidData(s.disk.contents, s.disk.respWrites)
    && allWritesDontOverlap(s.disk.reqWrites)
    && allWritesReqReadsDontOverlap(s.disk.reqWrites, s.disk.reqReads)
    && allWritesRespReadsDontOverlap(s.disk.reqWrites, s.disk.respReads)
    && BetreeJournalSystem.Inv(Ik(k), I(k, s))
  }
  
  lemma InitImpliesInv(k: Constants, s: Variables)
    // Inherited from abstract module:
    //requires Init(k, s)
    //ensures Inv(k, s)
  {
    BetreeJournalSystem.InitImpliesInv(Ik(k), I(k, s));
  }

  lemma ReqReadStepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp, dop: DiskOp)
    requires Inv(k, s)
    requires Machine(k, s, s', uiop, dop)
    requires dop.ReqReadOp?
    ensures Inv(k, s')
  {
  }

  lemma ReqWriteStepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp, dop: DiskOp)
    requires Inv(k, s)
    requires Machine(k, s, s', uiop, dop)
    requires dop.ReqWriteOp?
    ensures Inv(k, s')
  {
  }

  lemma ReqWrite2StepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp, dop: DiskOp)
    requires Inv(k, s)
    requires Machine(k, s, s', uiop, dop)
    requires dop.ReqWrite2Op?
    ensures Inv(k, s')
  {
  }

  lemma RespReadStepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp, dop: DiskOp)
    requires Inv(k, s)
    requires Machine(k, s, s', uiop, dop)
    requires dop.RespReadOp?
    ensures Inv(k, s')
  {
  }

  lemma RespWriteStepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp, dop: DiskOp)
    requires Inv(k, s)
    requires Machine(k, s, s', uiop, dop)
    requires dop.RespWriteOp?
    ensures Inv(k, s')
  {
  }

  lemma NoDiskOpStepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp, dop: DiskOp)
    requires Inv(k, s)
    requires Machine(k, s, s', uiop, dop)
    requires dop.NoDiskOp?
    ensures Inv(k, s')
  {
  }

  lemma MachineStepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp, dop: DiskOp)
    requires Inv(k, s)
    requires Machine(k, s, s', uiop, dop)
    ensures Inv(k, s')
  {
    match dop {
      case ReqReadOp(_, _) => ReqReadStepPreservesInv(k, s, s', uiop, dop);
      case ReqWriteOp(_, _) => ReqWriteStepPreservesInv(k, s, s', uiop, dop);
      case ReqWrite2Op(_, _, _, _) => ReqWrite2StepPreservesInv(k, s, s', uiop, dop);
      case RespReadOp(_, _) => RespReadStepPreservesInv(k, s, s', uiop, dop);
      case RespWriteOp(_, _) => RespWriteStepPreservesInv(k, s, s', uiop, dop);
      case NoDiskOp => NoDiskOpStepPreservesInv(k, s, s', uiop, dop);
    }
  }

  lemma DiskInternalStepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp, step: D.InternalStep)
    requires Inv(k, s)
    requires DiskInternal(k, s, s', uiop, step)
    ensures Inv(k, s')
  {
  }

  lemma CrashStepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp)
    requires Inv(k, s)
    requires Crash(k, s, s', uiop)
    ensures Inv(k, s')
  {
  }

  lemma NextStepPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp, step: Step)
    requires Inv(k, s)
    requires NextStep(k, s, s', uiop, step)
    ensures Inv(k, s')
  {
    match step {
      case MachineStep(dop) => MachineStepPreservesInv(k, s, s', uiop, dop);
      case DiskInternalStep(step) => DiskInternalStepPreservesInv(k, s, s', uiop, step);
      case CrashStep => CrashStepPreservesInv(k, s, s', uiop);
    }
  }

  lemma NextPreservesInv(k: Constants, s: Variables, s': Variables, uiop: UIOp)
    // Inherited from abstract module:
    //requires Inv(k, s)
    //requires Next(k, s, s', uiop)
    //ensures Inv(k, s')
  {
    var step :| NextStep(k, s, s', uiop, step);
    NextStepPreservesInv(k, s, s', uiop, step);
  }
}
