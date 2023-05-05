#![allow(unused_imports)]

use builtin_macros::*;
use builtin::*;

use crate::spec::FloatingSeq_t::*;
use crate::spec::MapSpec_t::*;
use crate::spec::TotalKMMap_t::*;
use crate::coordination_layer::MsgHistory_v::MsgHistory;

verus! {
pub type LSN = nat;

// TODO(jonh): Templating isn't helping, would
// like to define wf for StampedMap
pub struct Stamped<T>{
  pub value: T, 
  pub seq_end: LSN 
}

pub type StampedMap = Stamped<TotalKMMap>;

pub open spec fn empty() -> StampedMap {
  Stamped{ value: TotalKMMap::empty(), seq_end: 0}
}

impl StampedMap {
  pub open spec fn plus_history(self, history: MsgHistory) -> StampedMap
    recommends
      self.value.wf(),
      history.wf(),
      history.can_follow(self.seq_end),
  {
    history.apply_to_stamped_map(self)
  }
}

}


fn main() {}
