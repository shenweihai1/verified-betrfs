// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause
use builtin::*;
use builtin_macros::*;

use vstd::prelude::*;
//use vstd::bytes::*;
//use vstd::slice::*;
use crate::marshalling::Slice_v::*;

verus! {

pub trait Deepview {
    type DV;

    spec fn deepv(&self) -> Self::DV;
}

impl<T: Deepview> Deepview for Vec<T> {
    type DV = Seq<<T as Deepview>::DV>;

    open spec fn deepv(&self) -> Self::DV {
        Seq::new(self.len() as nat, |i: int| self[i].deepv())
    }
}

// Only want this to apply to types that are not already DeepView. :v/
// impl<T: View> Deepview for T {
//     type DV = <T as View>::V;
// 
//     fn deepv(&self) -> Self::DV;
// }

pub trait Premarshalling<U: Deepview> {
    spec fn valid(&self) -> bool;

    spec fn parsable(&self, data: Seq<u8>) -> bool
    recommends self.valid()
    ;

    exec fn exec_parsable(&self, slice: Slice, data: &Vec<u8>) -> (p: bool)
    requires
        self.valid(),
    ensures
        p == self.parsable(slice.i(data@))
    ;

    spec fn marshallable(&self, value: U::DV) -> bool
    ;

    spec fn spec_size(&self, value: U::DV) -> usize
    recommends 
        self.valid(),
        self.marshallable(value)
    ;

    exec fn exec_size(&self, value: &U) -> (sz: usize)
    requires 
        self.valid(),
        self.marshallable(value.deepv()),
    ensures
        sz == self.spec_size(value.deepv())
    ;
}

pub trait Marshalling<U: Deepview> : Premarshalling<U> {
    spec fn parse(&self, data: Seq<u8>) -> U::DV
    recommends 
        self.valid(),
        self.parsable(data)
    ;

    exec fn try_parse(&self, slice: Slice, data: &Vec<u8>) -> (ov: Option<U>)
    requires
        self.valid(),
    ensures
        self.parsable(slice.i(data@)) <==> ov is Some,
        self.parsable(slice.i(data@)) ==> ov.unwrap().deepv() == self.parse(slice.i(data@))
    ;

    // jonh skipping translation of Parse -- does it ever save more than
    // a cheap if condition?

    exec fn marshall(&self, value: &U, data: &mut Vec<u8>, start: usize) -> (end: usize)
    requires 
        self.valid(),
        self.marshallable(value.deepv()),
        start as int + self.spec_size(value.deepv()) as int <= old(data).len(),
    ensures
        end == start + self.spec_size(value.deepv()),
        data.len() == old(data).len(),
        forall |i| 0 <= i < start ==> data[i] == old(data)[i],
        forall |i| end <= i < data.len() ==> data[i] == old(data)[i],
        self.parsable(data@.subrange(start as int, end as int)),
        self.parse(data@.subrange(start as int, end as int)) == value.deepv()
    ;
}

} // verus!
