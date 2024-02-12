// Copyright 2018-2023 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, University of Washington
// SPDX-License-Identifier: BSD-2-Clause
// #![allow(unused_imports)]
use builtin::*;
use state_machines_macros::state_machine;
use vstd::prelude::*;

use crate::abstract_system::MsgHistory_v::*;
use crate::abstract_system::StampedMap_v::LSN;
use crate::disk::GenericDisk_v::AU;
use crate::journal::LinkedJournal_v::{LinkedJournal};
use crate::allocation_layer::AllocationJournal_v::*;
use crate::allocation_layer::MiniAllocator_v::*;

verus! {

#[is_variant]
pub enum Ephemeral {
    Unknown,
    Known { v: AllocationJournal::State },
}

impl Ephemeral {
    pub open spec(checked) fn wf(self) -> bool {
        self is Known ==> self.get_Known_v().wf()
    }
}

impl JournalImage {
    pub open spec(checked) fn init_by(self, aj: AllocationJournal::State) -> bool 
        recommends self.valid_image()
    {
        aj == AllocationJournal::State{
            journal: LinkedJournal::State{
                truncated_journal: self.tj,
                unmarshalled_tail: MsgHistory::empty_history_at(self.tj.seq_end()),
            },
            lsn_au_index: self.tj.build_lsn_au_index(self.first),
            first: self.first,
            mini_allocator: MiniAllocator::empty(),
        }
    }
}

// valid image
state_machine!{AllocationCrashAwareJournal{
    fields {
      pub persistent: JournalImage,
      pub ephemeral: Ephemeral,
      pub inflight: Option<JournalImage>
    }

    init!{
        initialize() {
            init persistent = JournalImage::empty();
            init ephemeral = Ephemeral::Unknown;
            init inflight = Option::None;
      }
    }

    #[is_variant]
    pub enum Label
    {
        LoadEphemeralFromPersistent,
        ReadForRecovery{ records: MsgHistory },
        QueryEndLsn{ end_lsn: LSN },
        Put{ records: MsgHistory },
        Internal{allocs: Set<AU>, deallocs: Set<AU>},
        QueryLsnPersistence{ sync_lsn: LSN },
        CommitStart{ new_boundary_lsn: LSN, max_lsn: LSN },
        CommitComplete{ require_end: LSN, discarded: Set<AU> },
        Crash,
    }

    pub open spec(checked) fn fresh_label(self, lbl: Label) -> bool
        recommends lbl is Internal ==> self.ephemeral is Known
    {
        lbl is Internal ==> {
            &&& lbl.get_Internal_allocs().disjoint(self.persistent.accessible_aus())
            &&& lbl.get_Internal_allocs().disjoint(self.ephemeral.get_Known_v().accessible_aus())
            &&& self.inflight is Some ==> lbl.get_Internal_allocs().disjoint(self.inflight.unwrap().accessible_aus())
        }
    }

    transition!{
        load_ephemeral_from_persistent(lbl: Label, new_journal: AllocationJournal::State) {
            require lbl is LoadEphemeralFromPersistent;
            require pre.ephemeral is Unknown;
            require pre.persistent.init_by(new_journal);
            update ephemeral = Ephemeral::Known{ v: new_journal };
        }
    }

    transition!{
        read_for_recovery(lbl: Label) {
            require lbl is ReadForRecovery;
            require pre.ephemeral is Known;
            require AllocationJournal::State::next(
                pre.ephemeral.get_Known_v(),
                pre.ephemeral.get_Known_v(),
                AllocationJournal::Label::ReadForRecovery{ messages: lbl.get_ReadForRecovery_records() }
            );
        }
    }

    transition!{
        query_end_lsn(lbl: Label) {
            require lbl is QueryEndLsn;
            require pre.ephemeral is Known;
            require AllocationJournal::State::next(
                pre.ephemeral.get_Known_v(),
                pre.ephemeral.get_Known_v(),
                AllocationJournal::Label::QueryEndLsn{ end_lsn: lbl.get_QueryEndLsn_end_lsn() },
            );
        }
    }

    transition!{
        put(lbl: Label, new_journal: AllocationJournal::State) {
            require lbl is Put;
            require pre.ephemeral is Known;
            require AllocationJournal::State::next(
                pre.ephemeral.get_Known_v(),
                new_journal,
                AllocationJournal::Label::Put{ messages: lbl.get_Put_records() },
            );
            update ephemeral = Ephemeral::Known{ v: new_journal };
        }
    }

    transition!{
        internal(lbl: Label, new_journal: AllocationJournal::State) {
            require lbl is Internal;
            require pre.ephemeral is Known;
            require pre.fresh_label(lbl);
            require AllocationJournal::State::next(
                pre.ephemeral.get_Known_v(),
                new_journal,
                AllocationJournal::Label::InternalAllocations{ allocs: lbl.get_Internal_allocs(), deallocs: lbl.get_Internal_deallocs() }
            );
            update ephemeral = Ephemeral::Known{ v: new_journal };
        }
    }

    transition!{
        query_lsn_persistence(lbl: Label) {
            require lbl is QueryLsnPersistence;
            require lbl.get_QueryLsnPersistence_sync_lsn() <= pre.persistent.tj.seq_end();
        }
    }

    transition!{
        commit_start(lbl: Label, frozen_journal: JournalImage) {
            require lbl is CommitStart;
            require pre.ephemeral is Known;
            // Can't start a commit if one is in-flight, or we'd forget to maintain the
            // invariants for the in-flight one.
            require pre.inflight is None;
            // Frozen journal stitches to frozen map
            require frozen_journal.tj.seq_start() == lbl.get_CommitStart_new_boundary_lsn();
            // Journal doesn't go backwards
            require pre.persistent.tj.seq_end() <= frozen_journal.tj.seq_end();
            // There should be no way for the frozen journal to have passed the ephemeral map!
            require frozen_journal.tj.seq_start() <= lbl.get_CommitStart_max_lsn();
            require AllocationJournal::State::next(
                pre.ephemeral.get_Known_v(),
                pre.ephemeral.get_Known_v(),
                AllocationJournal::Label::FreezeForCommit{frozen_journal},
            );
            update inflight = Option::Some(frozen_journal);
        }
    }

    transition!{
        commit_complete(lbl: Label, new_journal: AllocationJournal::State) {
            require lbl is CommitComplete;
            require pre.ephemeral is Known;
            require pre.inflight is Some;

            // upon a successful write to super block, we truncate ephemeral
            // journal to line up with the beginning of the newly persisted journal
            // another option would be to truncate the ephemeral journal to the
            // end of persitent journal, but this means that to reason about the
            // full system, we will need to reason about persistent tree,
            // persistent journal stitched at the front of the ephemeral journal.
            // since there's no runtime cost to track ephemeral journal as a
            // superset of persistent journal, that's what we do
            require AllocationJournal::State::next(
                pre.ephemeral.get_Known_v(),
                new_journal,
                AllocationJournal::Label::DiscardOld{
                    start_lsn: pre.inflight.unwrap().tj.seq_start(),
                    require_end: lbl.get_CommitComplete_require_end(),
                    // where do we specify which aus are in deallocs?
                    deallocs: lbl.get_CommitComplete_discarded(),
                },
            );

            // Watch the `update` keyword!
            update persistent = pre.inflight.unwrap();
            update ephemeral = Ephemeral::Known{ v: new_journal };
            update inflight = Option::None;
        }
    }

    transition!{
        crash(lbl: Label) {
            require lbl is Crash;
            update ephemeral = Ephemeral::Unknown;
            update inflight = Option::None;
        }
    }

    pub open spec(checked) fn state_relations(self) -> bool
    recommends
        self.ephemeral.wf(),
        self.inflight is Some ==> self.inflight.unwrap().tj.wf(),
        self.persistent.tj.wf()
    {
        &&& self.ephemeral is Known ==> {
            let ephemeral_tj = self.ephemeral.get_Known_v().tj();
            let persistent_tj = self.persistent.tj;
            &&& persistent_tj.seq_end() <= ephemeral_tj.seq_end()
            &&& persistent_tj.disk_view.is_sub_disk(ephemeral_tj.disk_view)
        }
        &&& self.ephemeral is Known && self.inflight is Some ==> {
            let ephemeral_tj = self.ephemeral.get_Known_v().tj();
            let inflight_tj = self.inflight.unwrap().tj;
            &&& inflight_tj.seq_end() <= ephemeral_tj.seq_end()
            &&& inflight_tj.disk_view.is_sub_disk_with_newer_lsn(ephemeral_tj.disk_view)
        }
    }

    #[invariant]
    pub open spec(checked) fn inv(self) -> bool {
        &&& self.ephemeral is Unknown ==> self.inflight is None
        &&& self.ephemeral is Known ==> self.ephemeral.get_Known_v().inv()
        &&& self.inflight is Some ==> self.inflight.unwrap().valid_image()
        &&& self.persistent.valid_image()
        &&& self.state_relations()
    }

    #[inductive(initialize)]
    fn initialize_inductive(post: Self) {
        JournalImage::empty_is_valid_image();
    }

    #[inductive(load_ephemeral_from_persistent)]
    fn load_ephemeral_from_persistent_inductive(pre: Self, post: Self, lbl: Label, new_journal: AllocationJournal::State)
    {
    }

    #[inductive(read_for_recovery)]
    fn read_for_recovery_inductive(pre: Self, post: Self, lbl: Label)
    {
    }

    #[inductive(query_end_lsn)]
    fn query_end_lsn_inductive(pre: Self, post: Self, lbl: Label)
    {
    }

    #[inductive(put)]
    fn put_inductive(pre: Self, post: Self, lbl: Label, new_journal: AllocationJournal::State)
    {
        reveal(AllocationJournal::State::next);
        reveal(AllocationJournal::State::next_by);

        reveal(LinkedJournal::State::next);
        reveal(LinkedJournal::State::next_by);

        assert(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv());
        assert(post.state_relations());
    }

    #[inductive(internal)]
    fn internal_inductive(pre: Self, post: Self, lbl: Label, new_journal: AllocationJournal::State)
    {
        reveal(AllocationJournal::State::next);
        reveal(AllocationJournal::State::next_by);

        let aj_lbl = AllocationJournal::Label::InternalAllocations{ allocs: lbl.get_Internal_allocs(), deallocs: lbl.get_Internal_deallocs() };
        AllocationJournal::State::inv_next(pre.ephemeral.get_Known_v(), post.ephemeral.get_Known_v(), aj_lbl);
        assert(post.ephemeral.get_Known_v().inv());

        match choose |step| AllocationJournal::State::next_by(pre.ephemeral.get_Known_v(), post.ephemeral.get_Known_v(), aj_lbl, step)
        {
            AllocationJournal::Step::internal_journal_marshal(cut, addr, post_linked_journal) => {
                if post.inflight is Some {
                    let pre_ephemeral_disk = pre.ephemeral.get_Known_v().tj().disk_view;
                    let ephemeral_disk = post.ephemeral.get_Known_v().tj().disk_view;
                    let inflight_disk = post.inflight.unwrap().tj.disk_view;

                    assert(inflight_disk.is_sub_disk_with_newer_lsn(pre_ephemeral_disk));
                    assert(pre_ephemeral_disk.is_sub_disk(ephemeral_disk));
                    assert(inflight_disk.entries <= pre_ephemeral_disk.entries);
                    assert(inflight_disk.entries <= ephemeral_disk.entries);
                    assert(inflight_disk.is_sub_disk_with_newer_lsn(ephemeral_disk));
                    assert(post.state_relations());
                }
            }
            _ => {  assert(post.state_relations()); }
        }
    }

    #[inductive(query_lsn_persistence)]
    fn query_lsn_persistence_inductive(pre: Self, post: Self, lbl: Label)
    {
        assert(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv());
    }

    #[inductive(commit_start)]
    fn commit_start_inductive(pre: Self, post: Self, lbl: Label, frozen_journal: JournalImage)
    {
        reveal(AllocationJournal::State::next);
        reveal(AllocationJournal::State::next_by);

        let pre_ephemeral = pre.ephemeral.get_Known_v();
        let new_bdy = frozen_journal.tj.seq_start();
        let aj_lbl = AllocationJournal::Label::FreezeForCommit{frozen_journal};

        AllocationJournal::State::frozen_journal_is_valid_image(pre_ephemeral, pre_ephemeral, aj_lbl);
        assert(post.inflight.unwrap().valid_image());
        assert(frozen_journal.tj.seq_end() <= pre_ephemeral.tj().seq_end());
        assert(post.state_relations());
    }

    #[inductive(commit_complete)]
    fn commit_complete_inductive(pre: Self, post: Self, lbl: Label, new_journal: AllocationJournal::State)
    {
        reveal(AllocationJournal::State::next);
        reveal(AllocationJournal::State::next_by);

        assert(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()) by {
            let alloc_lbl = AllocationJournal::Label::DiscardOld{
                start_lsn: pre.inflight.unwrap().tj.seq_start(),
                require_end: lbl.get_CommitComplete_require_end(),
                deallocs: lbl.get_CommitComplete_discarded(),
            };

            AllocationJournal::State::inv_next(pre.ephemeral.get_Known_v(),
                post.ephemeral.get_Known_v(), alloc_lbl);
        }

        let pre_ephemeral = pre.ephemeral.get_Known_v();
        let post_ephemeral = post.ephemeral.get_Known_v();

        let pre_ephemeral_disk = pre_ephemeral.tj().disk_view;
        let post_ephemeral_disk = post_ephemeral.tj().disk_view;
        let post_persistent_disk = post.persistent.tj.disk_view;

        assert(post_persistent_disk.is_sub_disk_with_newer_lsn(pre_ephemeral_disk));
        assert(post_ephemeral_disk.boundary_lsn == post_persistent_disk.boundary_lsn);

        assert(post_persistent_disk.entries.dom() <= post_ephemeral_disk.entries.dom()) by {
            let post_persistent_index = post.persistent.tj.build_lsn_au_index(post.persistent.first);
            let post_ephemeral_index = post_ephemeral.tj().build_lsn_au_index(post_ephemeral.first);

            assert(post_persistent_disk.domain_tight_wrt_index(post_persistent_index));
            assert(post_ephemeral_disk.domain_tight_wrt_index(post_ephemeral_index));

            assert(post_persistent_index.dom() <= post_ephemeral.lsn_au_index.dom()) by {
                post.persistent.tj.build_lsn_au_index_ensures(post.persistent.first);
                post_ephemeral.tj().build_lsn_au_index_ensures(post_ephemeral.first);
            }

            post.persistent.tj.sub_disk_build_sub_lsn_au_index(post.persistent.first, pre_ephemeral.tj(), pre_ephemeral.first);
            post_ephemeral.tj().sub_disk_build_sub_lsn_au_index(post_ephemeral.first, pre_ephemeral.tj(), pre_ephemeral.first);

            assert(post_persistent_index <= post_ephemeral.lsn_au_index);
        }

        assert(post_persistent_disk.is_sub_disk(post_ephemeral_disk));
        assert(post.state_relations());
    }

    #[inductive(crash)]
    fn crash_inductive(pre: Self, post: Self, lbl: Label)
    {
    }

  }}  // state_machine


} // verus!
  // verus
