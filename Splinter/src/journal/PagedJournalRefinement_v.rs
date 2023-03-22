#[allow(unused_imports)]
use builtin::*;

use builtin_macros::*;

use crate::pervasive::prelude::*;
use crate::coordination_layer::StampedMap_v::LSN;
use crate::coordination_layer::MsgHistory_v::*;
use crate::coordination_layer::AbstractJournal_v::*;
use crate::journal::PagedJournal_v::*;

verus! {

impl JournalRecord {
    pub open spec fn i(self, boundary_lsn: LSN) -> MsgHistory
    decreases self
    {
        if self.message_seq.can_discard_to(boundary_lsn)
            { self.message_seq.discard_old(boundary_lsn) } // and don't deref the prior_rec!
        else
            { Self::i_opt(*self.prior_rec, boundary_lsn).concat(self.message_seq) }
    }

    pub open spec fn i_opt(ojr: Option<Self>, boundary_lsn: LSN) -> MsgHistory
    decreases ojr
    {
        match ojr {
            None => MsgHistory::empty_history_at(boundary_lsn),
            Some(rec) => rec.i(boundary_lsn)
        }
    }

    // TODO(chris): another 50 lines to do what a single-line 'ensures' on a recursive definition did in Dafny.
    pub proof fn i_lemma(self, boundary_lsn: LSN)
    requires
        self.valid(boundary_lsn),
    ensures ({
        let out = self.i(boundary_lsn);
        &&& out.wf()
        &&& out.seq_start == boundary_lsn
        &&& out.seq_end === self.message_seq.seq_end
        })
    decreases self
    {
        // whole lotta copy-pasted boilerplate :v(
        if self.message_seq.can_discard_to(boundary_lsn)
        {
        }
        else
        {
            let ojr = *self.prior_rec;
            match ojr {
                None => {},
                Some(rec) => {rec.i_lemma(boundary_lsn)},
            }
        }
    }

    pub proof fn i_lemma_forall()
    ensures
        forall(|selff: Self, boundary_lsn: LSN|
            selff.valid(boundary_lsn)
            ==>
            ({
            let out = selff.i(boundary_lsn);
            &&& out.wf()
            &&& out.seq_start == boundary_lsn
            &&& out.seq_end === selff.message_seq.seq_end
            })
        )
    {
        assert forall |selff: Self, boundary_lsn: LSN|
            selff.valid(boundary_lsn)
            implies
            ({
            let out = selff.i(boundary_lsn);
            &&& out.wf()
            &&& out.seq_start == boundary_lsn
            &&& out.seq_end === selff.message_seq.seq_end
            }) by {
            selff.i_lemma(boundary_lsn);
        }
    }

    pub proof fn cant_crop(self, bdy: LSN, depth: nat)
    requires
        0 < depth,
        self.can_crop_head_records(bdy, (depth-1) as nat),
        self.crop_head_records(bdy, (depth-1) as nat).is_Some(),
        self.crop_head_records(bdy, (depth-1) as nat).unwrap().message_seq.can_discard_to(bdy),
    ensures
        !self.can_crop_head_records(bdy, depth+1)
    decreases depth
    {
        Self::opt_rec_crop_head_records_lemma_forall();
        if 1 < depth {
            self.cropped_prior(bdy).unwrap().cant_crop(bdy, (depth-1) as nat);
        }
    }

    pub proof fn crop_head_records_chaining(self, bdy: LSN, depth: nat)
    requires
        0 < depth,
        self.can_crop_head_records(bdy, (depth-1) as nat),
        self.crop_head_records(bdy, (depth-1) as nat).is_Some(),
        self.can_crop_head_records(bdy, depth),
    ensures
        self.crop_head_records(bdy, (depth-1) as nat).unwrap().cropped_prior(bdy) == self.crop_head_records(bdy, depth),
    decreases depth
    {
        Self::opt_rec_crop_head_records_lemma_forall();
        if 1<depth {
            self.cropped_prior(bdy).unwrap().crop_head_records_chaining(bdy, (depth-1) as nat);
            // Dafny didn't need this trigger
            assert(
                self.crop_head_records(bdy, depth)
                ==
                Self::opt_rec_crop_head_records(self.cropped_prior(bdy), bdy, (depth-1) as nat)
            );
        }
    }

    pub proof fn cropped_subseq_in_interpretation(self, bdy: LSN, depth: nat, msgs: MsgHistory)
    requires
        msgs.wf(),
        self.can_crop_head_records(bdy, depth+1),
        self.can_crop_head_records(bdy, depth),
        self.crop_head_records(bdy, depth).is_Some(),
        self.crop_head_records(bdy, depth).unwrap().i(bdy).includes_subseq(msgs),
    ensures
        0 < depth ==> self.can_crop_head_records(bdy, (depth-1) as nat),
        self.crop_head_records(bdy, 0).unwrap().i(bdy).includes_subseq(msgs),
    decreases depth
    {
        Self::i_lemma_forall();
        //Self::opt_rec_crop_head_records_lemma_forall(); // TODO(jonh): implicit defn ensures worked in Dafny; wrong trigger here
        if 0 < depth {
            self.can_crop_monotonic(bdy, (depth-1) as nat, depth);
            self.can_crop_more_yields_some(bdy, (depth-1) as nat, depth);
            let self_pre = self.crop_head_records(bdy, (depth-1) as nat).unwrap();
            assert(!self_pre.message_seq.can_discard_to(bdy)) by {
                if self_pre.message_seq.can_discard_to(bdy) {
                    self.cant_crop(bdy, depth);
                    assert(false);  // contradiction
                }
            }
            self.crop_head_records_chaining(bdy, depth);

            // TODO(chris): couldn't trigger forall version successfully, so manual invocation.
            let out = self.crop_head_records(bdy, (depth-1) as nat);
            self.crop_head_records_lemma(bdy, (depth-1) as nat, out);

            self.cropped_subseq_in_interpretation(bdy, (depth-1) as nat, msgs);
        }
    }
}

impl TruncatedJournal {
    pub open spec fn i(self) -> MsgHistory
    {
        JournalRecord::i_opt(self.freshest_rec, self.boundary_lsn)
    }
}

impl PagedJournal::Label {
    pub open spec fn wf(self) -> bool
    {
        match self {
            PagedJournal::Label::FreezeForCommit{frozen_journal} => frozen_journal.wf(),
            _ => true,
        }
    }

    pub open spec fn i(self) -> AbstractJournal::Label
    {
        match self {
            PagedJournal::Label::ReadForRecovery{messages}
                => AbstractJournal::Label::ReadForRecoveryLabel{messages},
            PagedJournal::Label::FreezeForCommit{frozen_journal}
                => AbstractJournal::Label::FreezeForCommitLabel{frozen_journal: frozen_journal.i()},
            PagedJournal::Label::QueryEndLsn{end_lsn}
                => AbstractJournal::Label::QueryEndLsnLabel{end_lsn},
            PagedJournal::Label::Put{messages}
                => AbstractJournal::Label::PutLabel{messages},
            PagedJournal::Label::DiscardOld{start_lsn, require_end}
                => AbstractJournal::Label::DiscardOldLabel{start_lsn, require_end},
            PagedJournal::Label::Internal{}
                => AbstractJournal::Label::InternalLabel{},
        }
    }
}

impl PagedJournal::State {
    pub open spec fn i(self) -> AbstractJournal::State
    {
        AbstractJournal::State{journal: self.truncated_journal.i().concat(self.unmarshalled_tail)}
    }

    pub proof fn read_for_recovery_refines(self, post: Self, lbl: PagedJournal::Label, depth: nat)
    requires 
        PagedJournal::State::read_for_recovery(self, post, lbl, depth),
    ensures
        AbstractJournal::State::next(self.i(), post.i(), lbl.i()),
    {
        // New calls
        JournalRecord::i_lemma_forall(); // superstition
        reveal(AbstractJournal::State::next_by);    // unfortunate defaults
        reveal(AbstractJournal::State::next);

        let ojr = self.truncated_journal.freshest_rec;
        let bdy = self.truncated_journal.boundary_lsn;
        let msgs = lbl.get_ReadForRecovery_messages();
        if ojr.is_Some() {
            ojr.unwrap().can_crop_monotonic(bdy, depth, depth+1);
            ojr.unwrap().can_crop_more_yields_some(bdy, depth, depth+1);

            // New explicit call: Ten lines of debugging later, I needed this call:
            ojr.unwrap().crop_head_records_lemma(bdy, depth, ojr.unwrap().crop_head_records(bdy, depth));

            ojr.unwrap().cropped_subseq_in_interpretation(bdy, depth, msgs);

            // New explicit call: was broadcast from concat
            ojr.unwrap().i(bdy).concat_lemma(self.unmarshalled_tail);
        }

        // New for step witness. Dafny AbstractJournal didn't have a Step.
        assert(AbstractJournal::State::next_by(self.i(), post.i(), lbl.i(), AbstractJournal::Step::read_for_recovery()));
    }

}

}//verus
