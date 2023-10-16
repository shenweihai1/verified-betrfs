// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause
//
#![allow(unused_imports)]
use builtin::*;
use vstd::prelude::*;
use vstd::math;

use builtin_macros::*;
use state_machines_macros::state_machine;

use vstd::prelude::*;
use vstd::map::*;
use vstd::map_lib::*;
use crate::abstract_system::StampedMap_v::LSN;
use crate::abstract_system::MsgHistory_v::*;
use crate::disk::GenericDisk_v::*;
use crate::disk::GenericDisk_v::AU;
use crate::allocation_layer::AllocationJournal_v::*;

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

    transition!{
        load_ephemeral_from_persistent(lbl: Label, new_journal: AllocationJournal::State, journal_config: AllocationJournal::Config) {
            require lbl is LoadEphemeralFromPersistent;
            require pre.ephemeral is Unknown;
            require journal_config === AllocationJournal::Config::initialize(new_journal.journal, pre.persistent);
            require AllocationJournal::State::init_by(new_journal, journal_config);
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
        commit_start(lbl: Label, frozen_journal: StoreImage, new_journal: AllocationJournal::State) {
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
                new_journal, 
                AllocationJournal::Label::FreezeForCommit{ frozen_journal: frozen_journal},
            );
            update ephemeral = Ephemeral::Known{ v: new_journal };
            update inflight = Option::Some(frozen_journal);
        }
    }

    transition!{
        commit_complete(lbl: Label, new_journal: AllocationJournal::State) {
            require lbl is CommitComplete;
            require pre.ephemeral is Known;
            require pre.inflight is Some;

            require AllocationJournal::State::next(
                pre.ephemeral.get_Known_v(), 
                new_journal, 
                AllocationJournal::Label::DiscardOld{ 
                    start_lsn: pre.inflight.get_Some_0().tj.seq_start(), 
                    require_end: lbl.get_CommitComplete_require_end(),
                    deallocs: lbl.get_CommitComplete_discarded(),
                },
            );
            
            // Watch the `update` keyword!
            update persistent = pre.inflight.get_Some_0();
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
            let ephemeral_disk = self.ephemeral.get_Known_v().get_tj().disk_view;
            let persistent_disk = self.persistent.tj.disk_view;
            &&& Map::agrees(ephemeral_disk.entries, persistent_disk.entries)
        }
        // inflight is always a subset of ephemeral
        &&& self.ephemeral is Known && self.inflight is Some ==> {
            let ephemeral_disk = self.ephemeral.get_Known_v().get_tj().disk_view;
            let inflight_disk = self.inflight.get_Some_0().tj.disk_view;
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
            &&& AllocationJournal::State::journal_pages_not_free(persistent_disk.entries.dom(), v.mini_allocator)
        }
        &&& self.ephemeral is Known && self.inflight is Some ==> {
            let v = self.ephemeral.get_Known_v();
            let inflight_disk = self.inflight.get_Some_0().tj.disk_view;
            &&& AllocationJournal::State::journal_pages_not_free(inflight_disk.entries.dom(), v.mini_allocator)
        }
    }

    #[invariant]
    pub open spec(checked) fn inv(self) -> bool {
        &&& self.ephemeral is Unknown ==> self.inflight is None
        &&& self.ephemeral is Known ==> self.ephemeral.get_Known_v().inv()
        &&& self.inflight is Some ==> self.inflight.get_Some_0().tj.decodable()
        &&& self.persistent.tj.decodable()
        // not used here but easier to maintain here
        &&& self.state_relations()
        &&& self.journal_pages_not_free()
    }
           
    #[inductive(initialize)]
    fn initialize_inductive(post: Self) {
        assume(post.persistent.tj.decodable()); // show empty is decodable
    }
   
    #[inductive(load_ephemeral_from_persistent)]
    fn load_ephemeral_from_persistent_inductive(pre: Self, post: Self, lbl: Label,
        new_journal: AllocationJournal::State, journal_config: AllocationJournal::Config) 
    { 
        assert(pre.ephemeral is Known ==> pre.ephemeral.get_Known_v().inv());
        assume(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()); // promised by submodule inv currently not accessible
        assume(post.journal_pages_not_free());
    }
   
    #[inductive(read_for_recovery)]
    fn read_for_recovery_inductive(pre: Self, post: Self, lbl: Label) 
    { 
        assume(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()); // promised by submodule inv currently not accessible
    }
   
    #[inductive(query_end_lsn)]
    fn query_end_lsn_inductive(pre: Self, post: Self, lbl: Label) 
    { 
        assume(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()); // promised by submodule inv currently not accessible
    }
   
    #[inductive(put)]
    fn put_inductive(pre: Self, post: Self, lbl: Label, new_journal: AllocationJournal::State) 
    { 
        assume(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()); // promised by submodule inv currently not accessible
        assume(post.journal_pages_not_free());
        assume(post.state_relations());
    }
   
    #[inductive(internal)]
    fn internal_inductive(pre: Self, post: Self, lbl: Label, new_journal: AllocationJournal::State) 
    {
        assume(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()); // promised by submodule inv currently not accessible
        assume(post.journal_pages_not_free());
        assume(post.state_relations());
    }
   
    #[inductive(query_lsn_persistence)]
    fn query_lsn_persistence_inductive(pre: Self, post: Self, lbl: Label) 
    {
        assume(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()); // promised by submodule inv currently not accessible
     }
   
    #[inductive(commit_start)]
    fn commit_start_inductive(pre: Self, post: Self, lbl: Label, frozen_journal: StoreImage, new_journal: AllocationJournal::State) 
    {
        assume(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()); // promised by submodule inv currently not accessible
        assume(post.inflight is Some ==> post.inflight.get_Some_0().tj.decodable()); // should reveal inflight 
        assume(post.journal_pages_not_free());
        assume(post.state_relations());
    }
   
    #[inductive(commit_complete)]
    fn commit_complete_inductive(pre: Self, post: Self, lbl: Label, new_journal: AllocationJournal::State) 
    { 
        assume(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()); // promised by submodule inv currently not accessible
        assume(post.journal_pages_not_free());
    }
   
    #[inductive(crash)]
    fn crash_inductive(pre: Self, post: Self, lbl: Label) 
    {
        assume(post.ephemeral is Known ==> post.ephemeral.get_Known_v().inv()); // promised by submodule inv currently not accessible
    }

  }} // state_machine
} // verus