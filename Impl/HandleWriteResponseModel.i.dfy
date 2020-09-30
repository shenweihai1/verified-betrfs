include "IOModel.i.dfy"
include "DiskOpImpl.i.dfy"
include "CommitterCommitModel.i.dfy"

module HandleWriteResponseModel {
  import opened NativeTypes
  import opened StateModel
  import opened DiskLayout
  import opened InterpretationDiskOps
  import opened ViewOp
  import opened Options
  import opened DiskOpModel
  import IOModel
  import CommitterCommitModel
  import CommitterModel
  import MarshallingModel

  function {:opaque} writeBackJournalResp(
      cm: CommitterModel.CM, io: IO) : CommitterModel.CM
  {
    cm.(outstandingJournalWrites :=
        cm.outstandingJournalWrites - {io.id})
  }

  lemma writeBackJournalRespCorrect(cm: CommitterModel.CM, io: IO)
  requires CommitterModel.Inv(cm)
  requires diskOp(io).RespWriteOp?
  requires ValidJournalLocation(LocOfRespWrite(diskOp(io).respWrite))
  requires cm.status.StatusReady?
  ensures var cm' := writeBackJournalResp(cm, io);
    && CommitterModel.WF(cm')
    && JC.Next(CommitterModel.I(cm), CommitterModel.I(cm'), 
        IDiskOp(diskOp(io)).jdop, JournalInternalOp)
  {
    reveal_writeBackJournalResp();
    var cm' := writeBackJournalResp(cm, io);
    if diskOp(io).id in cm.outstandingJournalWrites {
      assert JC.WriteBackJournalResp(
            CommitterModel.I(cm),
            CommitterModel.I(cm'),
            IDiskOp(diskOp(io)).jdop,
            JournalInternalOp);
      assert JC.NextStep(
            CommitterModel.I(cm),
            CommitterModel.I(cm'),
            IDiskOp(diskOp(io)).jdop,
            JournalInternalOp,
            JC.WriteBackJournalRespStep);
    } else {
      assert JC.NoOp(
            CommitterModel.I(cm),
            CommitterModel.I(cm'),
            IDiskOp(diskOp(io)).jdop,
            JournalInternalOp);
      assert JC.NextStep(
            CommitterModel.I(cm),
            CommitterModel.I(cm'),
            IDiskOp(diskOp(io)).jdop,
            JournalInternalOp,
            JC.NoOpStep);

      assert cm == cm';
    }
  }

  function {:opaque} writeResponse(s: Variables, io: IO)
      : Variables
  requires Inv(s)
  requires diskOp(io).RespWriteOp?
  {
    var loc := DiskLayout.Location(
        io.respWrite.addr,
        io.respWrite.len);

    if ValidNodeLocation(loc) &&
        s.bc.Ready? && io.id in s.bc.outstandingBlockWrites then (
      var bc' := IOModel.writeNodeResponse(s.bc, io);
      s.(bc := bc')
    ) else if ValidIndirectionTableLocation(loc)
        && s.bc.Ready?
        && s.bc.outstandingIndirectionTableWrite == Some(io.id) then (
      var (bc', frozen_loc) := IOModel.writeIndirectionTableResponse(s.bc, io);
      var jc' := CommitterCommitModel.receiveFrozenLoc(s.jc, frozen_loc);
      s.(bc := bc')
       .(jc := jc')
    ) else if s.jc.status.StatusReady? && ValidJournalLocation(loc) then (
      var jc' := writeBackJournalResp(s.jc, io);
      s.(jc := jc')
    ) else if ValidSuperblockLocation(loc) && Some(io.id) == s.jc.superblockWrite then (
      var bc' := if s.jc.status.StatusReady? && s.jc.commitStatus.CommitAdvanceLocation? then (
        IOModel.cleanUp(s.bc)
      ) else (
        s.bc
      );
      var jc' := CommitterCommitModel.writeBackSuperblockResp(s.jc);
      s.(jc := jc')
       .(bc := bc')
    ) else (
      s
    )
  }

  lemma writeResponseCorrect(s: Variables, io: IO)
  requires Inv(s)
  requires diskOp(io).RespWriteOp?
  ensures var s' := writeResponse(s, io);
    && WFVars(s')
    && M.Next(IVars(s), IVars(s'), UI.NoOp, diskOp(io))
  {
    var loc := DiskLayout.Location(
        io.respWrite.addr,
        io.respWrite.len);
    var s' := writeResponse(s, io);
    reveal_writeResponse();

    if ValidNodeLocation(loc) &&
        s.bc.Ready? && io.id in s.bc.outstandingBlockWrites {
      IOModel.writeNodeResponseCorrect(s.bc, io);
      assert JC.NextStep(CommitterModel.I(s.jc), CommitterModel.I(s'.jc), IDiskOp(diskOp(io)).jdop, StatesInternalOp, JC.NoOpStep);
      assert JC.Next(CommitterModel.I(s.jc), CommitterModel.I(s'.jc), IDiskOp(diskOp(io)).jdop, StatesInternalOp);
      assert BJC.NextStep(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)), StatesInternalOp);
      assert BJC.Next(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)));
      assert M.Next(IVars(s), IVars(s'), UI.NoOp, diskOp(io));
    } else if ValidIndirectionTableLocation(loc)
        && s.bc.Ready?
        && s.bc.outstandingIndirectionTableWrite == Some(io.id) {
      IOModel.writeIndirectionTableResponseCorrect(s.bc, io);
      var (bc', frozen_loc) := IOModel.writeIndirectionTableResponse(s.bc, io);
      CommitterCommitModel.receiveFrozenLocCorrect(s.jc, frozen_loc);
      assert s'.jc == CommitterCommitModel.receiveFrozenLoc(s.jc, frozen_loc);

      assert BJC.NextStep(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)), SendFrozenLocOp(frozen_loc));
      assert BJC.Next(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)));
      assert M.Next(IVars(s), IVars(s'), UI.NoOp, diskOp(io));
    } else if s.jc.status.StatusReady? && ValidJournalLocation(loc) {
      writeBackJournalRespCorrect(s.jc, io);

      assert BC.NextStep(IBlockCache(s.bc), IBlockCache(s'.bc), IDiskOp(diskOp(io)).bdop, JournalInternalOp, BC.NoOpStep);
      assert BBC.NextStep(IBlockCache(s.bc), IBlockCache(s'.bc), IDiskOp(diskOp(io)).bdop, JournalInternalOp, BBC.BlockCacheMoveStep(BC.NoOpStep));
      assert BBC.Next(IBlockCache(s.bc), IBlockCache(s'.bc), IDiskOp(diskOp(io)).bdop, JournalInternalOp);
      assert BJC.NextStep(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)), JournalInternalOp);
      assert BJC.Next(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)));
      assert M.Next(IVars(s), IVars(s'), UI.NoOp, diskOp(io));
    } else if ValidSuperblockLocation(loc) && Some(io.id) == s.jc.superblockWrite {
      CommitterCommitModel.writeBackSuperblockRespCorrect(s.jc, io);
      if s.jc.status.StatusReady? && s.jc.commitStatus.CommitAdvanceLocation? {
        IOModel.cleanUpCorrect(s.bc);
        assert BJC.NextStep(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)), CleanUpOp);
        assert BJC.Next(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)));
      } else {
        assert BC.NextStep(IBlockCache(s.bc), IBlockCache(s'.bc), IDiskOp(diskOp(io)).bdop, JournalInternalOp, BC.NoOpStep);
        assert BBC.NextStep(IBlockCache(s.bc), IBlockCache(s'.bc), IDiskOp(diskOp(io)).bdop, JournalInternalOp, BBC.BlockCacheMoveStep(BC.NoOpStep));
        assert BBC.Next(IBlockCache(s.bc), IBlockCache(s'.bc), IDiskOp(diskOp(io)).bdop, JournalInternalOp);

        assert BJC.NextStep(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)), JournalInternalOp);
        assert BJC.Next(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)));
      }
      assert M.Next(IVars(s), IVars(s'), UI.NoOp, diskOp(io));
    } else {
      if ValidDiskOp(diskOp(io)) {
        assert JC.NextStep(CommitterModel.I(s.jc), CommitterModel.I(s'.jc), IDiskOp(diskOp(io)).jdop, JournalInternalOp, JC.NoOpStep);
        assert JC.Next(CommitterModel.I(s.jc), CommitterModel.I(s'.jc), IDiskOp(diskOp(io)).jdop, JournalInternalOp);
        assert BC.NextStep(IBlockCache(s.bc), IBlockCache(s'.bc), IDiskOp(diskOp(io)).bdop, JournalInternalOp, BC.NoOpStep);
        assert BBC.NextStep(IBlockCache(s.bc), IBlockCache(s'.bc), IDiskOp(diskOp(io)).bdop, JournalInternalOp, BBC.BlockCacheMoveStep(BC.NoOpStep));
        assert BBC.Next(IBlockCache(s.bc), IBlockCache(s'.bc), IDiskOp(diskOp(io)).bdop, JournalInternalOp);

        assert BJC.NextStep(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)), JournalInternalOp);
        assert BJC.Next(IVars(s), IVars(s'), UI.NoOp, IDiskOp(diskOp(io)));
      }

      assert M.Next(IVars(s), IVars(s'), UI.NoOp, diskOp(io));
    }
  }

}
