use builtin_macros::*;
use vstd::{map::*,set::*};
use crate::spec::KeyType_t::*;
use crate::spec::Messages_t::*;

verus! {

pub open spec(checked) fn all_keys() -> Set<Key> {
    Set::new( |k| true )
}

pub open spec(checked) fn total_keys(keys: Set<Key>) -> bool {
    forall |k| keys.contains(k)
}

#[verifier::ext_equal]
pub struct Buffer { 
    pub map: Map<Key, Message>
}

impl Buffer {
    pub open spec(checked) fn query(self, key: Key) -> Message {
        if self.map.contains_key(key) {
            self.map[key]
        } else {
            Message::Update{ delta: nop_delta() }
        }
    }

    pub open spec(checked) fn apply_filter(self, accept: Set<Key>) -> Buffer {
        Buffer{ map: Map::new( |k| accept.contains(k) && self.map.contains_key(k), |k| self.map[k] ) }
    }

    pub open spec(checked) fn merge(self, new_buffer: Buffer) -> Buffer {
        Buffer{ map: Map::new( |k| self.map.contains_key(k) || new_buffer.map.contains_key(k), 
            |k| if new_buffer.map.contains_key(k) && self.map.contains_key(k) { 
                    self.map[k].merge(new_buffer.map[k]) 
                } else if new_buffer.map.contains_key(k) { 
                    new_buffer.map[k] 
                } else { 
                    self.map[k]
                }) 
        }
    }

    pub open spec(checked) fn empty() -> Buffer {
        Buffer{ map: Map::empty() }
    }
} // end impl Buffer
}  // end verus!
