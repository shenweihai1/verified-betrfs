#![allow(unused_imports)]

use builtin_macros::*;
use builtin::*;
use vstd::prelude::*;
use vstd::set_lib::*;

use crate::spec::Messages_t::*;

verus!{

pub struct Key(pub int); // TODO: this is a placeholder for the Key type

pub struct TotalKMMap(pub Map<Key, Message>);

pub open spec fn total_domain() -> Set<Key>
{
    Set::new(|k:Key| true)
}

impl TotalKMMap
{
    pub open spec fn empty() -> TotalKMMap
    {
        // TODO(verus): Should not have to declare binder twice.
        TotalKMMap(Map::new(
            |k: Key| true,
            |k: Key| Message::empty(),
        ))
    }

    // pass through to Map :v/
    pub open spec fn spec_index(self, idx: Key) -> Message {
        self.0[idx]
    }

    // pass through to Map :v/
    pub open spec fn insert(self, key: Key, value: Message) -> Self {
        TotalKMMap(self.0.insert(key, value))
    }

    // pass through to Map :v/
    pub open spec fn dom(self) -> Set<Key> {
        self.0.dom()
    }

    pub open spec fn wf(self) -> bool
    {
        self.dom() == total_domain()
    }

    pub proof fn insert_lemma(self)
    requires
        self.wf(),
    ensures
        forall |k: Key, v: Message| #![auto] self.insert(k, v).wf(),
    {
        assert forall |k: Key, v: Message| (#[trigger] self.insert(k, v)).wf() by {
            assert_sets_equal!(self.insert(k, v).dom(), total_domain());
        }
    }
}

}
