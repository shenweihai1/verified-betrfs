include "../BlockCacheSystem/JournalCache.i.dfy"
include "JournalistModel.i.dfy"
include "../lib/DataStructures/MutableMapModel.i.dfy"

// for when you have commitment issues

module CommitterModel {
  import JournalistModel
  import MutableMapModel
  import JC = JournalCache
  import opened SectorType
  import opened DiskLayout
  import opened Options
  import opened NativeTypes

  datatype Status =
    | StatusLoadingSuperblock
    | StatusLoadingOther
    | StatusReady

  datatype CommitterModel = CommitterModel(
    status: Status,

    journalist: JournalistModel.JournalistModel,
    frozenLoc: Option<Location>,
    isFrozen: bool,

    frozenJournalPosition: uint64,
    superblockWrite: Option<JC.ReqId>,

    outstandingJournalWrites: set<JC.ReqId>,

    superblock: Superblock,
    newSuperblock: Option<Superblock>,
    whichSuperblock: uint64,
    commitStatus: JC.CommitStatus,

    journalFrontRead: Option<JC.ReqId>,
    journalBackRead: Option<JC.ReqId>,
    superblock1Read: Option<JC.ReqId>,
    superblock2Read: Option<JC.ReqId>,
    superblock1: JC.SuperblockReadResult,
    superblock2: JC.SuperblockReadResult,

    syncReqs: MutableMapModel.LinearHashMap<JC.SyncReqStatus>
  )

  predicate WF(cm: CommitterModel)
  {
    && MutableMapModel.Inv(cm.syncReqs)
    && JournalistModel.Inv(cm.journalist)
  }

  function I(cm: CommitterModel) : JC.Variables
  requires WF(cm)
  {
    match cm.status {
      case StatusLoadingSuperblock =>
        JC.LoadingSuperblock(
          cm.superblock1Read,
          cm.superblock2Read,
          cm.superblock1,
          cm.superblock2,
          cm.syncReqs.contents
        )
      case StatusLoadingOther =>
        JC.LoadingOther(
          cm.superblock,
          cm.whichSuperblock as int,
          cm.journalFrontRead,
          cm.journalBackRead,
          JournalistModel.I(cm.journalist).journalFront,
          JournalistModel.I(cm.journalist).journalBack,
          cm.syncReqs.contents
        )
      case StatusReady =>
        JC.Ready(
          cm.frozenLoc,
          cm.isFrozen,
          cm.frozenJournalPosition as int,
          cm.superblockWrite,
          JournalistModel.I(cm.journalist).inMemoryJournalFrozen,
          JournalistModel.I(cm.journalist).inMemoryJournal,
          cm.outstandingJournalWrites,
          JournalistModel.I(cm.journalist).writtenJournalLen,
          JournalistModel.I(cm.journalist).replayJournal,
          cm.superblock,
          cm.whichSuperblock as int,
          cm.commitStatus,
          cm.newSuperblock,
          cm.syncReqs.contents
        )
    }
  }
}
