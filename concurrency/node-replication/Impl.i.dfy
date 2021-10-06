include "InfiniteLogTokens.i.dfy"
include "NRSpec.s.dfy"
include "../../lib/Lang/LinearSequence.i.dfy"
include "rwlock/Impl.i.dfy"
include "../framework/Atomic.s.dfy"
include "../framework/ThreadUtils.s.dfy"
include "../framework/Ptrs.s.dfy"
include "../framework/GlinearMap.s.dfy"
include "Runtime.s.dfy"
include "CyclicBufferTokens.i.dfy"

module Impl(nrifc: NRIfc) {
  import opened RequestIds
  import opened Atomics
  import opened ILT = InfiniteLogTokens(nrifc)
  import opened IL = InfiniteLogSSM(nrifc)
  import opened CBT = CyclicBufferTokens(nrifc)
  import opened LinearSequence_i
  import opened LinearSequence_s
  import opened NativeTypes
  import opened RwLockImpl
  import opened Runtime
  import opened ThreadUtils
  import opened Ptrs
  import opened GlinearMap
  import opened GlinearOption
  import opened Cells

  type Tid = uint64

  // TODO fill in reasonable constants for these
  const GC_FROM_HEAD: uint64 := 9999;
  const WARN_THRESHOLD: uint64 := 9999;
  const MAX_COMBINED_OPS: uint64 := 9999;
  const MAX_THREADS_PER_REPLICA: uint64 := 32;

  /*
   * Anything which is allocated on a NUMA node
   */

  linear datatype NodeReplica = NodeReplica(
    linear actual_replica: nrifc.DataStructureType,
    glinear ghost_replica: Replica,
    glinear combiner: CombinerToken
  )
  {
    predicate WF(nodeId: NodeId) {
      && ghost_replica.state == nrifc.I(actual_replica)
      && ghost_replica.nodeId == nodeId
      && combiner.state == CombinerReady
      && combiner.nodeId == nodeId
    }
  }

  linear datatype Node = Node(
    linear combiner: Atomic<uint64, ()>,
    linear replica: RwLock<NodeReplica>,
    linear context: map<Tid, nrifc.UpdateOp>,
    nodeId: uint64,
    next: Atomic<Tid, ()>
  )
  {
    predicate WF() {
      && (forall nodeReplica :: replica.inv(nodeReplica) <==> nodeReplica.WF(nodeId as int))
      && 0 <= nodeId as int < NUM_REPLICAS as int
    }
  }

  /*
   * Central cyclic buffer stuff
   */

  glinear datatype LocalTailTokens = LocalTailTokens(
      glinear localTail: LocalTail,
      glinear cbLocalTail: CBLocalTail)

  glinear datatype GlobalTailTokens = GlobalTailTokens(
      glinear globalTail: GlobalTail,
      glinear cbGlobalTail: CBGlobalTail)

  linear datatype NodeInfo = NodeInfo(
    linear localTail: Atomic<uint64, LocalTailTokens>
  )
  {
    predicate WF(nodeId: NodeId) {
      && (forall v, g :: atomic_inv(localTail, v, g) <==>
          g == LocalTailTokens(LocalTail(nodeId, v as int), CBLocalTail(nodeId, v as int)))
    }
  }

  linear datatype BufferEntry = BufferEntry(
    linear cell: Cell<LogEntry>,
    linear alive: Atomic<bool, AliveBit>)
  {
    predicate WF(i: nat)
    {
      && (forall v, g :: atomic_inv(alive, v, g) <==> g == AliveBit(i, v))
      && alive.namespace() == 0
    }
  }

  predicate BufferEntryInv(buffer: lseq<BufferEntry>, i: int, t: StoredType)
  requires |buffer| == BUFFER_SIZE as int
  {
    && t.cellContents.cell == buffer[i % BUFFER_SIZE as int].cell
    && (i >= 0 ==>
      && t.logEntry.glSome?
      && t.cellContents.v == LogEntry(t.logEntry.value.op, t.logEntry.value.node_id)
      && t.logEntry.value.idx == i
    )
  }

  predicate ContentsInv(buffer: lseq<BufferEntry>, contents: Contents)
  requires |buffer| == BUFFER_SIZE as int
  {
    && (forall i | i in contents.contents :: BufferEntryInv(buffer, i, contents.contents[i]))
  }

  linear datatype NR = NR(
    linear ctail: Atomic<uint64, Ctail>,
    linear head: Atomic<uint64, CBHead>,
    linear globalTail: Atomic<uint64, GlobalTailTokens>,
    linear node_info: lseq<NodeInfo>,

    linear buffer: lseq<BufferEntry>,
    glinear bufferContents: GhostAtomic<Contents>
  )
  {
    predicate WF() {
      && (forall v, g :: atomic_inv(ctail, v, g) <==> g == Ctail(v as int))
      && (forall v, g :: atomic_inv(head, v, g) <==> g == CBHead(v as int))
      && (forall v, g :: atomic_inv(globalTail, v, g) <==>
            g == GlobalTailTokens(GlobalTail(v as int), CBGlobalTail(v as int)))
      && |node_info| == NUM_REPLICAS as int
      && (forall nodeId | 0 <= nodeId < |node_info| :: nodeId in node_info)
      && (forall nodeId | 0 <= nodeId < |node_info| :: node_info[nodeId].WF(nodeId))
      && |buffer| == BUFFER_SIZE as int
      && (forall v, g :: atomic_inv(bufferContents, v, g) <==> ContentsInv(buffer, g))
      && (forall i: nat | 0 <= i < BUFFER_SIZE as int :: i in buffer)
      && (forall i: nat | 0 <= i < BUFFER_SIZE as int :: buffer[i].WF(i))

      && bufferContents.namespace() == 1
      && globalTail.namespace() == 0
    }
  }


  method is_replica_synced_for_reads(shared nr: NR, nodeId: uint64, ctail: uint64) 
  returns (is_synced: bool) 
  requires nr.WF()
  requires nodeId < NUM_REPLICAS
  {
    // https://github.com/vmware/node-replication/blob/1d92cb7c040458287bedda0017b97120fd8675a7/nr/src/log.rs#L708

    // TODO(unclear): what's so bad about `nr.node_info[nodeId as
    // nat].localTail`
    atomic_block var local_tail := execute_atomic_load(lseq_peek(nr.node_info, nodeId).localTail) { 
      // TODO(unclear): when we need to so stuff in the `atomic_block` and when
      // we don't
    }

    is_synced := local_tail >= ctail;
  }

  method try_combine(shared nr: NR, shared node: Node, tid: uint64)
  requires tid > 0
  requires nr.WF()
  {
    var i: uint64 := 0;
    while i < 5
    invariant 0 <= i <= 5
    {
      atomic_block var combiner := execute_atomic_load(node.combiner) {}
      if combiner != 0 {
        return;
      }
    }

    atomic_block var acquired := execute_atomic_compare_and_set_weak(node.combiner, 0, tid) {}
    if !acquired {
      return;
    }
    combine(nr, node, tid);
    atomic_block var _ := execute_atomic_store(node.combiner, 0) {}
  }

  method combine(shared nr: NR, shared node: Node, tid: uint64)
  requires tid > 0
  requires nr.WF() 
  {
    // https://github.com/vmware/node-replication/blob/1d92cb7c040458287bedda0017b97120fd8675a7/nr/src/replica.rs#L631
    //    fn combine(&self) {
    //        let mut buffer = self.buffer.borrow_mut();
    //        let mut operations = self.inflight.borrow_mut();
    //        let mut results = self.result.borrow_mut();
    //
    //        buffer.clear();
    //        results.clear();
    //
    //        let next = self.next.load(Ordering::Relaxed);
    //
    //        // Collect operations from each thread registered with this replica.
    //        for i in 1..next {
    //            operations[i - 1] = self.contexts[i - 1].ops(&mut buffer);
    //        }

//    atomic_block var next := execute_atomic_load(node.next) {}
//
//    linear var operations: lseq<uint64> := lseq_alloc<uint64>(MAX_THREADS_PER_REPLICA);
//    linear var buffer: lseq<nrifc.UpdateOp> := lseq_alloc<nrifc.UpdateOp>(MAX_THREADS_PER_REPLICA);
//    linear var results: lseq<nrifc.ReturnType> := lseq_alloc<nrifc.ReturnType>(MAX_THREADS_PER_REPLICA);

/* use something like this for initializing the `lseq` stuff:

  method init_batch_busy()
  returns (linear batch_busy: lseq<Atomic<bool, NullGhostType>>)
  ensures |batch_busy| == NUM_CHUNKS as int
  ensures (forall i :: 0 <= i < NUM_CHUNKS as int ==> lseq_has(batch_busy)[i])
  ensures (forall i, v, g :: 0 <= i < NUM_CHUNKS as int ==> atomic_inv(batch_busy[i], v, g) <==> true)
  {
    batch_busy := lseq_alloc<Atomic<bool, NullGhostType>>(NUM_CHUNKS_64());
    var i: uint64 := 0;
    while i < NUM_CHUNKS_64()
    invariant 0 <= i as int <= NUM_CHUNKS as int
    invariant |batch_busy| == NUM_CHUNKS as int
    invariant (forall j :: i as int <= j < NUM_CHUNKS as int ==> !lseq_has(batch_busy)[j])
    invariant (forall j :: 0 <= j < i as int ==> lseq_has(batch_busy)[j])
    invariant (forall j, v, g :: 0 <= j < i as int ==> atomic_inv(batch_busy[j], v, g) <==> true)
    {
      linear var ato := new_atomic(false, NullGhostType, (v, g) => true, 0);
      lseq_give_inout(inout batch_busy, i, ato);
      i := i + 1;
    }
  }
*/

//    var i := 0;
//    var j := 0;
//    while i < next-1 {
//      if i in node.context {
//        operations[i] = 1;      
//        buffer[j] = node.context[i];
//        j := j + 1;
//      }
//      else {
//        has_ops[i] = 0;
//      }
//    }


    //
    //        // Append all collected operations into the shared log. We pass a closure
    //        // in here because operations on the log might need to be consumed for GC.
    //        {
    //            let mut data = self.data.write(next);
    //            let f = |o: <D as Dispatch>::WriteOperation, i: usize| {
    //                #[cfg(not(loom))]
    //                let resp = data.dispatch_mut(o);
    //                #[cfg(loom)]
    //                let resp = data.dispatch_mut(o);
    //                if i == self.idx {
    //                    results.push(resp);
    //                }
    //            };
    //            self.slog.append(&buffer, self.idx, f);
    //        }
    //
    //        // Execute any operations on the shared log against this replica.
    //        {
    //            let mut data = self.data.write(next);
    //            let mut f = |o: <D as Dispatch>::WriteOperation, i: usize| {
    //                let resp = data.dispatch_mut(o);
    //                if i == self.idx {
    //                    results.push(resp)
    //                };
    //            };
    //            self.slog.exec(self.idx, &mut f);
    //        }
    //
    //        // Return/Enqueue responses back into the appropriate thread context(s).
    //        let (mut s, mut f) = (0, 0);
    //        for i in 1..next {
    //            if operations[i - 1] == 0 {
    //                continue;
    //            };
    //
    //            f += operations[i - 1];
    //            self.contexts[i - 1].enqueue_resps(&results[s..f]);
    //            s += operations[i - 1];
    //            operations[i - 1] = 0;
    //        }
    //    }

  }

  method do_read(shared nr: NR, shared node: Node, op: nrifc.ReadonlyOp,
      glinear ticket: Readonly)
  returns (result: nrifc.ReturnType, glinear stub: Readonly)
  requires nr.WF()
  requires node.WF()
  // The contract for this method works like this:
  // Input a ticket which "allows" us to perform the readonly operation specified
  // by the input parameter `op`
  requires ticket.rs == ReadonlyInit(op)
  // And we must return a stub that validates that we performed the operation
  // with the result being that value that we are returning.
  ensures stub.rid == ticket.rid && stub.rs.ReadonlyDone? && stub.rs.ret == result
  decreases * // method is not guaranteed to terminate
  {
    // https://github.com/vmware/node-replication/blob/1d92cb7c040458287bedda0017b97120fd8675a7/nr/src/replica.rs#L559
    //        let ctail = self.slog.get_ctail();
    //        while !self.slog.is_replica_synced_for_reads(self.idx, ctail) {
    //            self.try_combine(tid);
    //            spin_loop();
    //        }
    //
    //        return self.data.read(tid - 1).dispatch(op);

    // 1. Read ctail
    atomic_block var ctail := execute_atomic_load(nr.ctail) {
      ghost_acquire ctail_token; // declares ctail_token as a 'glinear' object
      assert ctail_token == Ctail(ctail as int); // this follows from the invariant on nr.ctail

      // perform transition of ghost state here ...
      stub := perform_TransitionReadonlyReadCtail(ticket, ctail_token);

      ghost_release ctail_token;
    }

    // 2. Read localTail (loop until you read a good value)
    var tid := 1; // TODO: tid comes from client calling do_read
    var synced := is_replica_synced_for_reads(nr, node.nodeId, ctail);
    while !synced {
      try_combine(nr, node, tid);
      Runtime.SpinLoopHint();
      synced := is_replica_synced_for_reads(nr, node.nodeId, ctail);
    }

    // 3. Take read-lock on replica; apply operation on replica
    linear var linear_guard := node.replica.acquire_shared();
    result := apply_readonly(linear_guard, op);
    node.replica.release_shared(linear_guard);
  }

  method apply_readonly(shared guard: SharedGuard<NodeReplica>, op: nrifc.ReadonlyOp) 
  returns (result: nrifc.ReturnType)
  {
    shared var shared_v := RwLockImpl.borrow_shared(guard);
    result := nrifc.do_readonly(shared_v.actual_replica, op);
  }

  method append(shared nr: NR, shared node: Node,
      shared ops: seq<nrifc.UpdateOp>,
      ghost requestIds: seq<RequestId>,
      glinear updates: map<nat, Update>,
      glinear combinerState: CombinerToken)
  returns (glinear combinerState': CombinerToken, glinear updates': map<nat, Update>)
  requires nr.WF()
  requires node.WF()
  requires |requestIds| == |ops| <= MAX_COMBINED_OPS as int
  requires combinerState.nodeId == node.nodeId as int
  requires combinerState.state == CombinerReady
  requires forall i | 0 <= i < |requestIds| ::
      i in updates && updates[i] == Update(requestIds[i], UpdateInit(ops[i]))
  ensures combinerState'.nodeId == node.nodeId as int
  ensures combinerState'.state == CombinerPlaced(requestIds)
  ensures forall i | 0 <= i < |requestIds| ::
      i in updates'
        && updates'[i].us.UpdatePlaced?
        && updates'[i] == Update(requestIds[i], UpdatePlaced(node.nodeId as int, updates'[i].us.idx))
  decreases *
  {
    updates' := updates;
    combinerState' := combinerState;

    var nops := seq_length(ops);
    var iteration := 1;
    var waitgc := 1;

    var done := false;
    while !done
    invariant 0 <= iteration as int <= WARN_THRESHOLD as int
    invariant 0 <= waitgc as int <= WARN_THRESHOLD as int
    invariant !done ==>
      && combinerState' == combinerState
      && updates' == updates

    invariant done ==>
      && combinerState'.nodeId == node.nodeId as int
      && combinerState'.state == CombinerPlaced(requestIds)
      && (forall i | 0 <= i < |requestIds| ::
          i in updates'
            && updates'[i].us.UpdatePlaced?
            && updates'[i] == Update(requestIds[i], UpdatePlaced(node.nodeId as int, updates'[i].us.idx))
      )

    decreases *
    {
      if iteration % WARN_THRESHOLD == 0 {
        iteration := 0;
        print "append takes too many iterations to complete\n";
      }
      iteration := iteration + 1;

      atomic_block var tail := execute_atomic_load(nr.globalTail) { }

      glinear var advance_tail_state;
      atomic_block var head := execute_atomic_load(nr.head) {
        ghost_acquire h;
        advance_tail_state := init_advance_tail_state(h);
        ghost_release h;
      }

      if tail > head + (BUFFER_SIZE - GC_FROM_HEAD) {
        if waitgc % WARN_THRESHOLD == 0 {
          waitgc := 0;
          print "append takes too many waitgc to complete\n";
        }
        waitgc := waitgc + 1;

        // TODO call `exec`

        dispose_anything(advance_tail_state);
      } else {

        assume tail as int + nops as int < 0x1_0000_0000_0000_0000; // TODO
        var advance: bool := (tail + nops > head + (BUFFER_SIZE - GC_FROM_HEAD));

        glinear var log_entries;
        glinear var cyclic_buffer_entries;
        glinear var appendStateOpt;

        atomic_block var success := execute_atomic_compare_and_set_weak(
            nr.globalTail, tail, tail + nops)
        {
          ghost_acquire globalTailTokens;
          atomic_block var _ := execute_atomic_noop(nr.bufferContents)
          {
            ghost_acquire contents;
            if success {
              glinear var GlobalTailTokens(globalTail, cbGlobalTail) := globalTailTokens;
              glinear var appendState;
              globalTail, updates', combinerState', log_entries :=
                perform_AdvanceTail(globalTail, updates', combinerState', ops, requestIds, node.nodeId as int);
              cbGlobalTail, cyclic_buffer_entries, appendState := finish_advance_tail(
                  advance_tail_state, cbGlobalTail, tail as int + nops as int, contents);
              appendStateOpt := glSome(appendState);
              globalTailTokens := GlobalTailTokens(globalTail, cbGlobalTail);
            } else {
              // no transition
              log_entries := glmap_empty(); // to satisfy linearity checker
              cyclic_buffer_entries := glmap_empty();
              appendStateOpt := glNone;

              dispose_anything(advance_tail_state);
            }
            ghost_release contents;
          }
          ghost_release globalTailTokens;
        }

        if success {
          glinear var append_state := unwrap_value(appendStateOpt);

          ghost var original_cyclic_buffer_entries := cyclic_buffer_entries;
          
          var j := 0;
          while j < nops
          invariant 0 <= j <= nops
          invariant append_state.cur_idx == tail as int + j as int
          invariant append_state.tail == tail as int + nops as int
          invariant forall i: int | j as int <= i < |requestIds| ::
              i in log_entries
                && log_entries[i] == Log(tail as int + i, ops[i], node.nodeId as int)
          invariant forall i: int | j as int <= i < |requestIds| ::
              && (tail as int + i) in cyclic_buffer_entries
              && cyclic_buffer_entries[tail as int + i]
                  == original_cyclic_buffer_entries[tail as int + i]
          {
            // Get the single 'Log' token we're going to store
            glinear var log_entry, cyclic_buffer_entry;
            log_entries, log_entry := glmap_take(log_entries, j as int);
            // Get the access to the 'Cell' in the buffer entry
            cyclic_buffer_entries, cyclic_buffer_entry :=
                glmap_take(cyclic_buffer_entries, tail as int + j as int);

            assert BufferEntryInv(nr.buffer,
                (tail as int + j as int) - BUFFER_SIZE as int, cyclic_buffer_entry);

            glinear var StoredType(cellContents, oldLogEntry) := cyclic_buffer_entry;

            dispose_anything(oldLogEntry); // don't need this anymore

            var bounded_idx := (tail + j) % BUFFER_SIZE;
            calc {
              ((tail as int + j as int) - BUFFER_SIZE as int) % BUFFER_SIZE as int;
              bounded_idx as int;
            }

            assert nr.buffer[bounded_idx as int].WF(bounded_idx as int);

            // Physically write the log entry into the cyclic buffer
            write_cell(lseq_peek(nr.buffer, bounded_idx).cell,
                inout cellContents,
                LogEntry(seq_get(ops, j), node.nodeId as int));
            
            cyclic_buffer_entry := StoredType(cellContents, glSome(log_entry));
            assert BufferEntryInv(nr.buffer,
                (tail as int + j as int), cyclic_buffer_entry);

            var m := ((tail + j) / BUFFER_SIZE) % 2 == 0;
            atomic_block var _ := execute_atomic_store(
                lseq_peek(nr.buffer, bounded_idx).alive, m)
            {
              ghost_acquire aliveToken;
              atomic_block var _ := execute_atomic_noop(nr.bufferContents)
              {
                ghost_acquire contents;
                append_state, aliveToken, contents :=
                  append_flip_bit(append_state, aliveToken, contents, cyclic_buffer_entry);
                ghost_release contents;
              }
              ghost_release aliveToken;
            }

            j := j + 1;
          }

          dispose_anything(log_entries);
          dispose_anything(cyclic_buffer_entries);
          dispose_anything(append_state);

          if advance {
            advance_head(nr, node);
          }
          
          done := true;
        } else {
          dispose_anything(log_entries);
          dispose_anything(cyclic_buffer_entries);
          dispose_anything(appendStateOpt);
        }
      }
    }
  }

  predicate pre_exec(node: Node,
      requestIds: seq<RequestId>,
      responses: seq<nrifc.ReturnType>,
      updates: map<nat, Update>,
      combinerState: CombinerToken)
  {
    && combinerState.nodeId == node.nodeId as int
    && combinerState.state == CombinerPlaced(requestIds)
    && |responses| == NUM_REPLICAS as int
    && |requestIds| <= NUM_REPLICAS as int
    && (forall i | 0 <= i < |requestIds| ::
      i in updates
        && updates[i].us.UpdatePlaced?
        && updates[i] == Update(requestIds[i],
            UpdatePlaced(node.nodeId as int, updates[i].us.idx))
    )
  }

  predicate post_exec(node: Node,
      requestIds: seq<RequestId>,
      responses': seq<nrifc.ReturnType>,
      updates': map<nat, Update>,
      combinerState': CombinerToken)
  {
    && combinerState'.nodeId == node.nodeId as int
    && combinerState'.state == CombinerReady
    && |responses'| == NUM_REPLICAS as int
    && |requestIds| <= NUM_REPLICAS as int
    && (forall i | 0 <= i < |requestIds| as int ::
            i in updates'
              && updates'[i].us.UpdateDone?
              && updates'[i].rid == requestIds[i]
              && updates'[i].us.ret == responses'[i]
    )
  }

  method exec(shared nr: NR, shared node: Node,
      linear actual_replica: nrifc.DataStructureType,
      linear responses: seq<nrifc.ReturnType>,
      glinear ghost_replica: Replica,
      ghost requestIds: seq<RequestId>,
      glinear updates: map<nat, Update>,
      glinear combinerState: CombinerToken,
      glinear reader: Reader)
  returns (
    linear actual_replica': nrifc.DataStructureType,
    linear responses': seq<nrifc.ReturnType>,
    glinear ghost_replica': Replica,
    glinear updates': map<nat, Update>,
    glinear combinerState': CombinerToken,
    glinear reader': Reader)
  requires nr.WF()
  requires node.WF()
  requires reader.nodeId == node.nodeId as int
  requires reader.rs.ReaderIdle?
  requires ghost_replica.state == nrifc.I(actual_replica)
  requires ghost_replica.nodeId == node.nodeId as int
  requires combinerState.state.CombinerReady?
      || combinerState.state.CombinerPlaced?
  requires combinerState.nodeId == node.nodeId as int
  requires |responses| == NUM_REPLICAS as int
  requires combinerState.state.CombinerPlaced? ==>
      pre_exec(node, requestIds, responses, updates, combinerState)
  ensures combinerState.state.CombinerPlaced? ==>
      post_exec(node, requestIds, responses', updates', combinerState')
  ensures combinerState.state.CombinerReady? ==>
      responses == responses' && combinerState' == combinerState
  ensures reader' == reader
  ensures ghost_replica.state == nrifc.I(actual_replica)
  ensures ghost_replica.nodeId == node.nodeId as int
  decreases *
  {
    actual_replica' := actual_replica;
    ghost_replica' := ghost_replica;
    combinerState' := combinerState;
    updates' := updates;
    reader' := reader;
    responses' := responses;

    assert nr.node_info[node.nodeId as int].WF(node.nodeId as int);

    ghost var requestIds' := requestIds;
    if combinerState'.state.CombinerReady? {
      combinerState' := perform_TrivialStartCombining(combinerState');
      requestIds' := [];
    }

    atomic_block var ltail := execute_atomic_load(lseq_peek(nr.node_info, node.nodeId).localTail)
    {
      ghost_acquire ltail_token;
      combinerState' := perform_ExecLoadLtail(combinerState', ltail_token.localTail);
      reader' := reader_start(reader', ltail_token.cbLocalTail);
      ghost_release ltail_token;
    }

    atomic_block var gtail := execute_atomic_load(nr.globalTail)
    {
      ghost_acquire gtail_token;
      combinerState' := perform_ExecLoadGlobalTail(combinerState', gtail_token.globalTail);
      reader' := reader_enter(reader', gtail_token.cbGlobalTail);
      ghost_release gtail_token;
    }

    if ltail == gtail {
      // done
      assume false; // TODO
    } else {
      var responsesIndex: uint64 := 0;

      ghost var prev_combinerState := combinerState';
      var i := ltail;
      while i < gtail
      invariant 0 <= i <= gtail
      invariant combinerState'.nodeId == prev_combinerState.nodeId
      invariant combinerState'.state.Combiner?
      invariant combinerState'.state == prev_combinerState.state.(localTail := i as int)
      invariant reader' == Reader(node.nodeId as int, ReaderRange(ltail as int, gtail as int))
      invariant ghost_replica'.state == nrifc.I(actual_replica')
      invariant ghost_replica'.nodeId == node.nodeId as int
      invariant |responses'| == NUM_REPLICAS as int
      invariant 0 <= responsesIndex as int <= |requestIds'|
      invariant forall i | responsesIndex as int <= i < |requestIds'| ::
          i in updates'
            && updates'[i].us.UpdatePlaced?
            && updates'[i] == Update(requestIds'[i], UpdatePlaced(node.nodeId as int, updates'[i].us.idx))
      invariant forall i | 0 <= i < responsesIndex as int ::
          i in updates'
            && updates'[i].us.UpdateApplied?
            && updates'[i].rid == requestIds'[i]
            && updates'[i].us.ret == responses'[i]
      invariant responsesIndex == 0 ==> responses' == responses
      {
        var iteration := 1;

        var done := false;
        while !done
        invariant 0 <= iteration as int <= WARN_THRESHOLD as int
        invariant reader' == Reader(node.nodeId as int, ReaderRange(ltail as int, gtail as int))
        invariant ghost_replica'.state == nrifc.I(actual_replica')
        invariant ghost_replica'.nodeId == node.nodeId as int
        invariant combinerState'.nodeId == prev_combinerState.nodeId
        invariant combinerState'.state.Combiner?
        invariant !done ==> combinerState'.state == prev_combinerState.state.(localTail := i as int)
        invariant done ==> combinerState'.state == prev_combinerState.state.(localTail := i as int + 1)
        invariant 0 <= responsesIndex as int <= |requestIds'|
        invariant |responses'| == NUM_REPLICAS as int
        invariant forall i | responsesIndex as int <= i < |requestIds'| ::
            i in updates'
              && updates'[i].us.UpdatePlaced?
              && updates'[i] == Update(requestIds'[i], UpdatePlaced(node.nodeId as int, updates'[i].us.idx))
        invariant forall i | 0 <= i < responsesIndex as int ::
            i in updates'
              && updates'[i].us.UpdateApplied?
              && updates'[i].rid == requestIds'[i]
              && updates'[i].us.ret == responses'[i]
        invariant responsesIndex == 0 ==> responses' == responses

        decreases *
        {
          var bounded := i % BUFFER_SIZE;
          atomic_block var live_bit := execute_atomic_load(
              lseq_peek(nr.buffer, bounded).alive)
          {
            ghost_acquire alive_bit;
            atomic_block var _ := execute_atomic_noop(nr.bufferContents)
            {
              ghost_acquire contents;
              if live_bit == ((i / BUFFER_SIZE) % 2 == 0) {
                reader' := reader_guard(reader', alive_bit, i as int, contents);
              }
              ghost_release contents;
            }
            ghost_release alive_bit;
          }

          if live_bit == ((i / BUFFER_SIZE) % 2 == 0) {
            // read the log_entry from memory
            var log_entry := read_cell(lseq_peek(nr.buffer, bounded).cell,
                reader_borrow(reader').cellContents);

            var ret;
            actual_replica', ret := nrifc.do_update(actual_replica', log_entry.op);

            if log_entry.node_id == node.nodeId as int {
              // TODO add ret to results list
              assume responsesIndex as int < |requestIds'|; // TODO should follow from InfiniteLog inv

              glinear var my_update, my_update';
              updates', my_update := glmap_take(updates', responsesIndex as int);
              combinerState', ghost_replica', my_update' :=
                perform_ExecDispatchLocal(combinerState', ghost_replica',
                      my_update,
                      reader_borrow(reader').logEntry.value);
              updates' := glmap_insert(updates', responsesIndex as int, my_update');

              responses' := seq_set(responses', responsesIndex, ret);

              responsesIndex := responsesIndex + 1;
            } else {
              // TODO remote dispatch
              combinerState', ghost_replica' :=
                perform_ExecDispatchRemote(combinerState', ghost_replica',
                      reader_borrow(reader').logEntry.value);
            }

            reader' := reader_unguard(reader');
            done := true;
          } else {
            if iteration % WARN_THRESHOLD == 0 {
              print "exec warn threshold\n";
              iteration := 0;
            }
            iteration := iteration + 1;
          }
        }

        i := i + 1;
      }

      assume responsesIndex as int == |requestIds'|; // TODO should follow from InfiniteLog inv

      // fetch & max
      ghost var prev_combinerState1 := combinerState';
      ghost var prev_updates1 := updates';
      var done := false;
      while !done
      invariant !done ==> combinerState' == prev_combinerState1
      invariant !done ==> updates' == prev_updates1
      invariant done ==>
        && combinerState'.nodeId == node.nodeId as int
        && combinerState'.state == CombinerUpdatedCtail(
            prev_combinerState1.state.queued_ops, gtail as int)
      invariant done ==>
        forall i | 0 <= i < responsesIndex as int ::
            i in updates'
              && updates'[i].us.UpdateDone?
              && updates'[i].rid == requestIds'[i]
              && updates'[i].us.ret == responses'[i]
      decreases *
      {
        atomic_block var cur_ctail := execute_atomic_load(nr.ctail) { }
        var max_ctail := (if cur_ctail > gtail then cur_ctail else gtail);
        atomic_block done := execute_atomic_compare_and_set_strong(nr.ctail, cur_ctail, max_ctail)
        {
          ghost_acquire ctail_token;
          if done {
            combinerState', ctail_token :=
              perform_UpdateCompletedTail(combinerState', ctail_token);
            updates' := perform_UpdateDone(|requestIds'|, updates', combinerState');
          } else {
            // do nothing
          }
          ghost_release ctail_token;
        }
      }

      atomic_block var _ :=
        execute_atomic_store(lseq_peek(nr.node_info, node.nodeId).localTail, gtail)
      {
        ghost_acquire ltail_tokens;
        glinear var LocalTailTokens(localTail, cbLocalTail) := ltail_tokens;
        combinerState', localTail := perform_GoToCombinerReady(combinerState', localTail);
        reader', cbLocalTail := reader_finish(reader', cbLocalTail);
        ltail_tokens := LocalTailTokens(localTail, cbLocalTail);
        ghost_release ltail_tokens;
      }
    }
  }

  method advance_head(shared nr: NR, shared node: Node)
  requires nr.WF()
  requires node.WF()
  decreases *
  {
    // https://github.com/vmware/node-replication/blob/1d92cb7c040458287bedda0017b97120fd8675a7/nr/src/log.rs#L570

    var iteration: uint64 := 1;
    var done := false;
    while !done
    invariant 0 <= iteration as int <= WARN_THRESHOLD as int
    decreases *
    {
      var r := NUM_REPLICAS;
      atomic_block var global_head := execute_atomic_load(nr.head) {
        
      }
      atomic_block var f := execute_atomic_load(nr.globalTail) { }

      glinear var advance_state_token;

      atomic_block var min_local_tail :=
          execute_atomic_load(lseq_peek(nr.node_info, 0).localTail)
      {
        ghost_acquire ltail;
        advance_state_token := init_advance_head_state(ltail.cbLocalTail);
        ghost_release ltail;
      }

      var idx: uint64 := 1;
      while idx < r
      invariant 0 <= idx <= r
      invariant advance_state_token == AdvanceHeadState(idx as int, min_local_tail as int)
      {
        atomic_block var cur_local_tail :=
            execute_atomic_load(lseq_peek(nr.node_info, idx).localTail)
        {
          ghost_acquire ltail;
          advance_state_token := step_advance_head_state(ltail.cbLocalTail, advance_state_token);
          ghost_release ltail;
        }
        if cur_local_tail < min_local_tail {
          min_local_tail := cur_local_tail;
        }
        idx := idx + 1;
      }

      if min_local_tail == global_head {
        if iteration == WARN_THRESHOLD {
          print "Spending a long time in `advance_head`, are we starving?";
          iteration := 0;
        }
        iteration := iteration + 1;

        // TODO call `exec`

        dispose_anything(advance_state_token);
      } else {
        atomic_block var _ := execute_atomic_store(nr.head, min_local_tail)
        {
          ghost_acquire head;
          head := finish_advance_head_state(head, advance_state_token);
          ghost_release head;
        }

        if f < min_local_tail + BUFFER_SIZE - GC_FROM_HEAD { // TODO bounded int errors
          done := true;
        } else {
          // TODO call `exec`
        }
      }
    }
  }
}
