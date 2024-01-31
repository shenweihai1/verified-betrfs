// Copyright 2018-2023 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, University of Washington
// SPDX-License-Identifier: BSD-2-Clause
#![allow(unused_imports)]
use builtin::*;
use vstd::prelude::*;
use state_machines_macros::state_machine;

use crate::abstract_system::StampedMap_v::LSN;
use crate::abstract_system::MsgHistory_v::*;
use crate::disk::GenericDisk_v::{Address, AU};
use crate::allocation_layer::AllocationJournal_v::*;
use crate::journal::LinkedJournal_v;

verus!{
pub type StoreImage = JournalImage;

#[is_variant]
pub enum Ephemeral
{
    Unknown,
    Known{v: AllocationJournal::State}
}

impl Ephemeral {
    pub open spec(checked) fn wf(self) -> bool
    {
      self is Known ==> self.get_Known_v().wf()
    }
}

state_machine!{AllocationCrashAwareJournal{
    fields {
      pub persistent: StoreImage,
      pub ephemeral: Ephemeral,
      pub inflight: Option<StoreImage>
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
            require AllocationJournal::State::init_by(new_journal, 
                AllocationJournal::Config::initialize(new_journal.journal, pre.persistent));
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
        commit_start(lbl: Label, frozen_journal: StoreImage) {
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
    {
        // persistent and ephemeral agree on values
        &&& self.ephemeral is Known ==> {
            let ephemeral_disk = self.ephemeral.get_Known_v().tj().disk_view;
            let persistent_disk = self.persistent.tj.disk_view;
            &&& Map::agrees(ephemeral_disk.entries, persistent_disk.entries)
        }
        // inflight is always a subset of ephemeral
        &&& self.ephemeral is Known && self.inflight is Some ==> {
            let ephemeral_disk = self.ephemeral.get_Known_v().tj().disk_view;
            let inflight_disk = self.inflight.unwrap().tj.disk_view;
            &&& inflight_disk.is_sub_disk_with_newer_lsn(ephemeral_disk)
        }
    }

    pub open spec(checked) fn journal_pages_not_free(self) -> bool
        recommends self.ephemeral is Known ==> self.ephemeral.get_Known_v().inv()
    {
        // ephemeral pages are not free as promised by the recommends
        &&& self.ephemeral is Known ==> {
            let v = self.ephemeral.get_Known_v();
            let persistent_disk = self.persistent.tj.disk_view;
            &&& AllocationJournal::State::disk_domain_not_free(persistent_disk, v.mini_allocator)
        }
        &&& self.ephemeral is Known && self.inflight is Some ==> {
            let v = self.ephemeral.get_Known_v();
            let inflight_disk = self.inflight.unwrap().tj.disk_view;
            &&& AllocationJournal::State::disk_domain_not_free(inflight_disk, v.mini_allocator)
        }
    }

    #[invariant]
    pub open spec(checked) fn inv(self) -> bool {
        &&& self.ephemeral is Unknown ==> self.inflight is None
        &&& self.ephemeral is Known ==> self.ephemeral.get_Known_v().inv()
        &&& self.inflight is Some ==> self.inflight.unwrap().valid_image()
        &&& self.persistent.valid_image()

        // not used here but easier to maintain here
        &&& self.state_relations()
        &&& self.journal_pages_not_free()
    }

    #[inductive(initialize)]
    fn initialize_inductive(post: Self) {
        JournalImage::empty_is_valid_image();
    }
   
    #[inductive(load_ephemeral_from_persistent)]
    fn load_ephemeral_from_persistent_inductive(pre: Self, post: Self, lbl: Label, new_journal: AllocationJournal::State) 
    {
        reveal(AllocationJournal::State::init_by);
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

        reveal(LinkedJournal_v::LinkedJournal::State::next);
        reveal(LinkedJournal_v::LinkedJournal::State::next_by);
        
        assert(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv());

        assert(post.journal_pages_not_free());
        assert(post.state_relations());
    }
   
    #[inductive(internal)]
    fn internal_inductive(pre: Self, post: Self, lbl: Label, new_journal: AllocationJournal::State) 
    {
        reveal(AllocationJournal::State::next);
        reveal(AllocationJournal::State::next_by);

        let aj_lbl = AllocationJournal::Label::InternalAllocations{ allocs: lbl.get_Internal_allocs(), deallocs: lbl.get_Internal_deallocs() };
        match choose |step| AllocationJournal::State::next_by(pre.ephemeral.get_Known_v(), post.ephemeral.get_Known_v(), aj_lbl, step)
        {
            AllocationJournal::Step::internal_journal_marshal(cut, addr, post_linked_journal) => {
                AllocationJournal::State::internal_journal_marshal_inductive(pre.ephemeral.get_Known_v(), 
                post.ephemeral.get_Known_v(), aj_lbl, cut, addr, new_journal.journal);
                assert(post.ephemeral.get_Known_v().inv());
                assert(post.journal_pages_not_free());

                if post.inflight is Some {
                    let pre_ephemeral_disk = pre.ephemeral.get_Known_v().tj().disk_view;
                    let ephemeral_disk = post.ephemeral.get_Known_v().tj().disk_view;
                    let inflight_disk = post.inflight.unwrap().tj.disk_view;

                    assert(inflight_disk.is_sub_disk_with_newer_lsn(pre_ephemeral_disk));
                    // assert(pre_ephemeral_disk.is_sub_disk(ephemeral_disk));
                    assert(inflight_disk.is_sub_disk_with_newer_lsn(ephemeral_disk));
                }
            }
            _ => { }
        }
        assert(post.state_relations());

        assume(post.inv()); // TODO(JL)
    }
   
    #[inductive(query_lsn_persistence)]
    fn query_lsn_persistence_inductive(pre: Self, post: Self, lbl: Label) 
    {
        assert(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv());
    }

    #[inductive(commit_start)]
    fn commit_start_inductive(pre: Self, post: Self, lbl: Label, frozen_journal: StoreImage) 
    {
        reveal(AllocationJournal::State::next);
        reveal(AllocationJournal::State::next_by);
        reveal(LinkedJournal_v::LinkedJournal::State::next);
        reveal(LinkedJournal_v::LinkedJournal::State::next_by);

        let aj = pre.ephemeral.get_Known_v();
        let new_bdy = frozen_journal.tj.seq_start();

        AllocationJournal::State::frozen_journal_is_valid_image(aj, aj, AllocationJournal::Label::FreezeForCommit{frozen_journal});
        assert(post.inflight.unwrap().valid_image());

        // use aj.frozen_journal_is_valid_image
        assume(false);
        // ephemeral_discarded_disk.build_tight_builds_sub_disks(frozen_journal.tj.freshest_rec);
        // /*assert(ephemeral_discarded_disk.build_tight(frozen_journal.tj.freshest_rec) == frozen_journal.tj.disk_view);
        // assert(frozen_journal.tj.disk_view.entries <= ephemeral_disk.entries);
        // assert(frozen_journal.tj.disk_view.is_sub_disk_with_newer_lsn(ephemeral_disk));*/
        // assert(post.state_relations());

        // // assert(AllocationJournal::State::journal_pages_not_free(ephemeral_disk.entries.dom(), aj.mini_allocator));
        // assert(frozen_journal.tj.disk_view.entries.dom() <= ephemeral_disk.entries.dom()); // trigger
        // // assert(AllocationJournal::State::journal_pages_not_free(frozen_journal.tj.disk_view.entries.dom(), aj.mini_allocator));
        // assert(post.journal_pages_not_free());
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
            AllocationJournal::State::discard_old_inductive(pre.ephemeral.get_Known_v(), 
                post.ephemeral.get_Known_v(), alloc_lbl, new_journal.journal);
        }
        assert(post.journal_pages_not_free());

        let pre_ephemeral_disk = pre.ephemeral.get_Known_v().tj().disk_view;
        let pre_inflight_disk = pre.inflight.unwrap().tj.disk_view;
        assert(pre_inflight_disk.is_sub_disk_with_newer_lsn(pre_ephemeral_disk));

        let post_ephemeral_disk = post.ephemeral.get_Known_v().tj().disk_view;
        assert(post_ephemeral_disk.is_sub_disk_with_newer_lsn(pre_ephemeral_disk));

        assert forall |addr| pre_inflight_disk.entries.dom().contains(addr) 
            && post_ephemeral_disk.entries.dom().contains(addr) 
            ==> pre_ephemeral_disk.entries.dom().contains(addr) by {}

        assert(Map::agrees(pre_inflight_disk.entries, post_ephemeral_disk.entries));
        assert(post.state_relations());
    }
   
    #[inductive(crash)]
    fn crash_inductive(pre: Self, post: Self, lbl: Label) 
    {
    }

  }} // state_machine
} // verus