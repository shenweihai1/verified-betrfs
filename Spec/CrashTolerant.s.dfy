include "../lib/Base/SequencesLite.s.dfy"
include "../lib/Base/MapRemove.s.dfy"
include "Async.s.dfy"

// Collect the entire history of possible snapshots, with a pointer to the persistent one.
// Sync requests begin at the head of the list (the ephemeral state).
// Once the persistent pointer reaches that same index, the sync may be acknowledged as complete.
// We don't do anything with old snapshots (indeed, no implementation could); I just wrote it
// this way for greatest simplicity.
module CrashTolerantMod(atomic: AtomicStateMachineMod) {
  import opened MapRemove_s
  import opened SequencesLite // Last, DropLast
  import async = AsyncMod(atomic) // Crash tolerance adds asynchrony whether you like it or not.

  type SyncReqId = nat
  datatype Version =
    | Forgotten
      // jonh apology: The spec exposes the implementation-specific idea
      // of log truncation to keep the interpretation functions easy to
      // build. This way, when we truncate in the implementation, we
      // can just map that to a Forgotten version in this spec version
      // sequence. This is lame, because we're asking the spec inspector
      // to understand impl details. An alternative would be to add
      // a "write-only ghost state" mechanism to the bottom bread, into
      // which Program.i could tuck away old ghost versions going back
      // to the dawn of time, and then the interpretation function
      // could peek at those to construct the version seq. This is a way
      // to add Lamport's history variable while respecting the .v/.i
      // split. But I'm too lazy to do that now, so please judge away.
    | Version(asyncState: async.PersistentState)

  datatype Variables = Variables(
    versions: seq<Version>,
    asyncEphemeral: async.EphemeralState,

    // Request id points at the number of LSNs that must be persisted.
    // So if the client ReqSyncs after 3 writes (seqEnd==3), the value
    // in the map is 3.
    syncRequests: map<SyncReqId, nat>,

    // The index of the last persistent version. Notice that, since we
    // never delete versions, that index is also the count of writes
    // and thus also the "NextLSN" value when that version was created.
    stableIdx: nat)
  {
    predicate WF() {
      // There is always some persistent version, even if just a view of the
      // mkfs state
      && 0 < |versions|

      // All versions beginning with the stableIdx aren't truncated,
      // so that crashing can't take us to a Forgotten version.
      && (forall i | stableIdx<=i<|versions| :: versions[i].Version?)

      && stableIdx < |versions|
    }
  }


  function InitState() : Variables {
    Variables([Version(async.InitPersistentState())], async.InitEphemeralState(), map[], 0)
  }

  // This isn't a transition, just a partial action for readibility.
  predicate OptionallyAppendVersion(v: Variables, v': Variables)
  {
    // new versions list is either some new thing appended to the old one,
    || (0<|v'.versions| && DropLast(v'.versions) == v.versions)
    // or unchanged. We allow unchanged in the trusted spec so that
    // implementations don't have to account for number of read-only (query) ops.
    || v'.versions == v.versions
  }

  predicate Operate(v: Variables, v': Variables, op: async.UIOp)
  {
    && v.WF()
    && v'.WF()
    && OptionallyAppendVersion(v, v')
    && async.NextStep(
        async.Variables(Last(v.versions).asyncState, v.asyncEphemeral),
        async.Variables(Last(v'.versions).asyncState, v'.asyncEphemeral),
        op)
    && v'.syncRequests == v.syncRequests  // unchanged
    && v'.stableIdx == v.stableIdx    // unchanged
  }

  // Uh oh, anything not flushed (past stableIdx) is gone. But you still get a consistent version
  // at least as new as every version synced before the crash.
  predicate Crash(v: Variables, v': Variables)
  {
    && v.WF()
    && v'.versions == v.versions[..v.stableIdx+1]
    // Crash forgets ephemeral stuff -- requests and syncRequests submitted but not answered.
    && v'.asyncEphemeral == async.InitEphemeralState()
    && v'.syncRequests == map[]
    && v'.stableIdx == v.stableIdx
  }

  // The implementation may push some stuff out to the disk without getting
  // all the way up to date with the ephemeral state.
  predicate SpontaneousCommit(v: Variables, v': Variables)
  {
    && v.WF()
    && |v'.versions| == |v.versions|
    // Commit can truncate old versions (see apology at definition of Forgotten)
    && (forall i | 0<=i<|v.versions| ::
      || v'.versions[i] == v.versions[i]
      || (i < v'.stableIdx && v'.versions[i].Forgotten?)
      )
    && v'.WF()  // But it can't truncate things after stableIdx
    && v'.asyncEphemeral == v.asyncEphemeral
    && v'.syncRequests == v.syncRequests
    // stableIdx advances towards, possibly all the way to, ephemeral state.
    // (It's okay to not advance if you're just, say, truncating your journal
    // instead. Note that we don't require either truncating or
    // persistification, so this step can also admit a Noop. No biggie until we
    // care about proving liveness.)
    && v.stableIdx <= v'.stableIdx < |v.versions|
  }

  // sync api contract to the end user
  // NB it's a very little bit funky. For all normal requests, three atomic
  // actions occur: the request arrives, it's executed (serialized), the reply
  // is delivered. For Syncs, we don't bother explicitly recording the serialization
  // point; CompleteSync just gets enabled at some point before it occurs. Sorry?
  predicate ReqSync(v: Variables, v': Variables, syncReqId: SyncReqId)
  {
    && v.WF()
    && v' == v.(syncRequests := v.syncRequests[syncReqId := |v.versions|-1])
  }

  // When your syncReqId gets flushed all the way to the persistent version slot,
  // the sync is complete and that version is stable.
  predicate CompleteSync(v: Variables, v': Variables, syncReqId: SyncReqId)
  {
    && v.WF()
    && syncReqId in v.syncRequests
    && v.syncRequests[syncReqId] <= v.stableIdx
    && v' == v.(syncRequests := MapRemove1(v.syncRequests, syncReqId))
  }

  datatype UIOp =
    | OperateOp(baseOp: async.UIOp) // Put or Query Internally
    | CrashOp
    | SpontaneousCommitOp // Check with Jon
    | ReqSyncOp(syncReqId: SyncReqId)
    | CompleteSyncOp(syncReqId: SyncReqId)
    | NoopOp

  predicate NextStep(v: Variables, v': Variables, uiop: UIOp)
  {
    match uiop {
      case OperateOp(baseOp) => Operate(v, v', baseOp)
      case CrashOp => Crash(v, v')
      case SpontaneousCommitOp => SpontaneousCommit(v, v')
      case ReqSyncOp(syncReqId) => ReqSync(v, v', syncReqId)
      case CompleteSyncOp(syncReqId) => CompleteSync(v, v', syncReqId)
      case NoopOp => v' == v
    }
  }

  predicate Next(v: Variables, v': Variables, uiop: UIOp)
  {
    exists uiop :: NextStep(v, v', uiop)
  }
}
