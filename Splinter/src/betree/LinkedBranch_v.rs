// Copyright 2018-2023 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, University of Washington
// SPDX-License-Identifier: BSD-2-Clause
use builtin::*;

use builtin_macros::*;

use vstd::prelude::*;
// use vstd::seq::*;
// use vstd::seq_lib::*;
use crate::spec::KeyType_t::*;
use crate::spec::Messages_t::*;
// use crate::betree::Buffer_v::*;
// use crate::betree::Domain_v::*;
use crate::disk::GenericDisk_v::*;

// LinkedBranch module stores each node in the b+tree on a different disk address

verus! {

#[is_variant]
pub enum SplitArg {
    SplitIndex{pivot: Key, pivot_index: int},
    SplitLeaf{pivot: Key}
}

impl SplitArg {
    pub open spec(checked) fn wf(self, split_branch: LinkedBranch) -> bool
        recommends split_branch.has_root()
    {
        let root = split_branch.root();
        match self {
            Self::SplitLeaf{pivot} => {
                &&& root is Leaf
                &&& root.get_Leaf_keys().len() == root.get_Leaf_msgs().len()
                &&& 0 < Key::largest_lt(root.get_Leaf_keys(), pivot) + 1 < root.get_Leaf_keys().len()
            }
            Self::SplitIndex{pivot, pivot_index} => {
                &&& root is Index
                &&& root.get_Index_children().len() == root.get_Index_pivots().len() + 1
                &&& split_branch.acyclic() ==> split_branch.all_keys_in_range()
                &&& 0 <= pivot_index < root.get_Index_pivots().len()
                &&& root.get_Index_pivots()[pivot_index] == pivot
            }
        }
    }

    pub open spec(checked) fn get_pivot(self) -> Key
    {
        if self is SplitLeaf {
            self.get_SplitLeaf_pivot()
        } else {
            self.get_SplitIndex_pivot()
        }
    }
}

#[is_variant]
pub enum Node {
    Index{pivots: Seq<Key>, children: Seq<Address>},
    Leaf{keys: Seq<Key>, msgs: Seq<Message>}
}

impl Node {
    pub open spec(checked) fn wf(self) -> bool
    {
        match self {
            Self::Leaf{keys, msgs} => {
                &&& keys.len() == msgs.len()
                &&& Key::is_strictly_sorted(keys)
            }
            Self::Index{pivots, children} => {
                &&& pivots.len() == children.len() - 1
                &&& Key::is_strictly_sorted(pivots)
            }
        }
    }

    pub open spec(checked) fn valid_child_index(self, i: nat) -> bool
    {
        &&& self is Index
        &&& i < self.get_Index_children().len()
    }

    pub open spec(checked) fn route(self, key: Key) -> int
        recommends self.wf()
    {
        let s = if self is Leaf { self.get_Leaf_keys() } else { self.get_Index_pivots() };
        Key::largest_lte(s, key)
    }
}

#[verifier::ext_equal]
pub struct DiskView {
    pub entries: Map<Address, Node>
}

impl DiskView {
    pub open spec(checked) fn wf(self) -> bool
    {
        &&& self.entries_wf()
        &&& self.no_dangling_address()
    }

    pub open spec(checked) fn entries_wf(self) -> bool
    {
        forall |addr| #[trigger] self.entries.contains_key(addr) ==> self.entries[addr].wf()
    }

    pub open spec(checked) fn valid_address(self, addr: Address) -> bool
    {
        self.entries.contains_key(addr)
    }

    pub open spec(checked) fn node_has_valid_child_address(self, node: Node) -> bool
    {
        node is Index ==>
            forall |idx| 0 <= idx < node.get_Index_children().len() ==> self.valid_address(#[trigger] node.get_Index_children()[idx])
    }

    // disk is closed wrt to all the address in the nodes on disk
    pub open spec(checked) fn no_dangling_address(self) -> bool
    {
        forall |addr| #[trigger] self.entries.contains_key(addr) ==> self.node_has_valid_child_address(self.entries[addr])
    }

    pub open spec(checked) fn get(self, addr: Address) -> Node
        recommends self.valid_address(addr)
    {
        self.entries[addr]
    }

    pub open spec(checked) fn get_keys(self, addr: Address) -> Set<Key>
        recommends self.valid_address(addr)
    {
        let node = self.get(addr);
        if node is Index {
            node.get_Index_pivots().to_set()
        } else {
            node.get_Leaf_keys().to_set()
        }
    }

    pub open spec(checked) fn representation(self) -> Set<Address>
    {
        self.entries.dom()
    }

    pub open spec(checked) fn agrees_with_disk(self, other: DiskView) -> bool
    {
        self.entries.agrees(other.entries)
    }

    pub open spec(checked) fn is_subset_of(self, other: DiskView) -> bool
    {
        self.entries <= other.entries
    }

    // The node at this address has child pointers that respect ranking
    pub open spec(checked) fn node_children_respects_rank(self, ranking: Ranking, addr: Address) -> bool
        recommends
            self.wf(),
            self.entries.contains_key(addr),
            ranking.contains_key(addr)
    {
        let node = self.entries[addr];
        forall |child_idx: nat| #[trigger] node.valid_child_index(child_idx) ==> {
            &&& ranking.contains_key(node.get_Index_children()[child_idx as int]) // ranking is closed
            &&& ranking[node.get_Index_children()[child_idx as int]] < ranking[addr]
        }
    }

    // Together with NodeChildrenRespectsRank, this says that ranking is closed
    pub open spec(checked) fn valid_ranking(self, ranking: Ranking) -> bool
        recommends self.wf()
    {
        forall |addr| #[trigger] ranking.contains_key(addr) && self.entries.contains_key(addr) ==>
            self.node_children_respects_rank(ranking, addr)
    }

    pub open spec(checked) fn is_fresh(self, addrs: Set<Address>) -> bool
    {
        addrs.disjoint(self.entries.dom())
    }

    pub closed spec(checked) fn merge_disk(self, other: DiskView) -> DiskView
    {
        DiskView{entries: self.entries.union_prefer_right(other.entries)}
    }

    pub closed spec(checked) fn remove_disk(self, other: DiskView) -> DiskView
    {
        DiskView{entries: self.entries.remove_keys(other.entries.dom())}
    }

    pub open spec(checked) fn modify_disk(self, addr: Address, item: Node) -> DiskView
    {
        DiskView{entries: self.entries.insert(addr, item)}
    }

    pub open spec(checked) fn same_except(self, other: DiskView, except: Set<Address>) -> bool
    {
        self.entries.remove_keys(except) == other.entries.remove_keys(except)
    }
}

pub open spec(checked) fn empty_disk() -> DiskView
{
    DiskView{entries: map!{}}
}

#[verifier::ext_equal]
pub struct LinkedBranch {
    pub root: Address,
    pub disk_view: DiskView
}

impl LinkedBranch {
    pub open spec(checked) fn wf(self) -> bool
    {
        &&& self.disk_view.wf()
        &&& self.has_root()
    }

    pub open spec(checked) fn has_root(self) -> bool
    {
        self.disk_view.valid_address(self.root)
    }

    pub open spec(checked) fn root(self) -> Node
        recommends self.has_root()
    {
        self.disk_view.get(self.root)
    }

    pub open spec(checked) fn get_rank(self, ranking: Ranking) -> nat
        recommends self.wf()
    {
        if ranking.contains_key(self.root) { ranking[self.root] + 1 } else { 0 }
    }

    pub open spec(checked) fn valid_ranking(self, ranking: Ranking) -> bool
        recommends self.wf()
    {
        &&& self.disk_view.valid_ranking(ranking)
        &&& ranking.contains_key(self.root) // ranking covers tree from this root
    }

    pub open spec(checked) fn the_ranking(self) -> Ranking
        recommends self.acyclic()
    {
        let ranking = choose |ranking| self.valid_ranking(ranking);
        ranking
    }

    pub open spec(checked) fn acyclic(self) -> bool
    {
        &&& self.wf()
        &&& exists |ranking| self.valid_ranking(ranking)
    }

    pub open spec(checked) fn all_keys_in_range(self) -> bool
        recommends self.acyclic()
    {
        self.all_keys_in_range_internal(self.the_ranking())
    }

    pub open spec(checked) fn all_keys_in_range_internal(self, ranking: Ranking) -> bool
        recommends
            self.wf(),
            self.valid_ranking(ranking),
            decreases self.get_rank(ranking), 1int
    {
        self.root() is Index ==> {
            &&& forall |i| 0 <= i < self.root().get_Index_children().len() ==> self.child_all_keys_in_range_internal(ranking, i)
            &&& forall |i| 0 <= i < self.root().get_Index_children().len() - 1 ==> self.all_keys_below_bound(i, ranking)
            &&& forall |i| 0 < i < self.root().get_Index_children().len() ==> self.all_keys_above_bound(i, ranking)
        }
    }

    pub open spec/*XXX (checked)*/ fn child_all_keys_in_range_internal(self, ranking: Ranking, i: nat) -> bool
        recommends
            self.wf(),
            self.valid_ranking(ranking),
            self.root() is Index,
            0 <= i < self.root().get_Index_children().len()
        decreases self.get_rank(ranking), 0int
        when {
            &&& self.root() is Index
            &&& self.root().valid_child_index(i)
            &&& self.child_at_idx(i).get_rank(ranking) < self.get_rank(ranking)
        }
    {
        // Need valid ranking implies child has valid ranking to restore checked
        self.child_at_idx(i).all_keys_in_range_internal(ranking)
    }

    // Union of sets of all keys of children[i..]
    pub open spec(checked) fn children_keys(self, ranking: Ranking, i: nat) -> Set<Key>
        recommends
            self.wf(),
            self.valid_ranking(ranking),
            self.root() is Index,
            0 <= i <= self.root().get_Index_children().len()
        decreases
            self.get_rank(ranking),
            0int,
            self.root().get_Index_children().len() - i
        when {
            &&& self.root() is Index
            &&& 0 <= i <= self.root().get_Index_children().len()
            &&& self.root().valid_child_index(i) ==>
                self.child_at_idx(i).get_rank(ranking) < self.get_rank(ranking)
        }
    {
        if i == self.root().get_Index_children().len() {
            set!{}
        } else {
            self.child_at_idx(i).all_keys(ranking) + self.children_keys(ranking, i + 1)
        }
    }

    pub open spec(checked) fn all_keys(self, ranking: Ranking) -> Set<Key>
        recommends
            self.wf(),
            self.valid_ranking(ranking)
        decreases self.get_rank(ranking), 1int
    {
        // TODO (x9du): the match doesn't satisfy the self.root() is Index recommends
        // but the if does?
        if self.root() is Leaf {
            self.root().get_Leaf_keys().to_set()
        } else {
            let pivot_keys = self.root().get_Index_pivots().to_set();
            let index_keys = self.children_keys(ranking, 0);
            pivot_keys + index_keys
        }
        // match self.root() {
        //     Node::Leaf{keys, msgs} => {
        //         keys.to_set()
        //     }
        //     Node::Index{pivots, children} => {
        //         let pivot_keys = pivots.to_set();
        //         let index_keys = self.children_keys(ranking, 0);
        //         pivot_keys + index_keys
        //     }
        // }
    }

    pub open spec/*XXX (checked)*/ fn all_keys_below_bound(self, i: int, ranking: Ranking) -> bool
        recommends
            self.wf(),
            self.valid_ranking(ranking),
            self.root() is Index,
            0 <= i < self.root().get_Index_pivots().len()
        decreases self.get_rank(ranking)
    {
        // Need valid ranking implies child has valid ranking to restore checked
        forall |key| self.child_at_idx(i as nat).all_keys(ranking).contains(key) ==> Key::lt(key, self.root().get_Index_pivots()[i])
    }

    pub open spec/*XXX (checked)*/ fn all_keys_above_bound(self, i: int, ranking: Ranking) -> bool
        recommends
            self.wf(),
            self.valid_ranking(ranking),
            self.root() is Index,
            0 <= i - 1 < self.root().get_Index_pivots().len()
        decreases self.get_rank(ranking)
    {
        // Need valid ranking implies child has valid ranking to restore checked
        forall |key| self.child_at_idx(i as nat).all_keys(ranking).contains(key) ==> #[trigger] Key::lte(self.root().get_Index_pivots()[i-1], key)
    }

    pub open spec(checked) fn child_at_idx(self, i: nat) -> LinkedBranch
        recommends
            self.has_root(),
            self.root().valid_child_index(i)
    {
        LinkedBranch{root: self.root().get_Index_children()[i as int], disk_view: self.disk_view}
    }

    pub open spec(checked) fn representation(self) -> Set<Address>
        recommends self.acyclic()
    {
        self.reachable_addrs_using_ranking(self.the_ranking())
    }

    pub open spec(checked) fn reachable_addrs_using_ranking(self, ranking: Ranking) -> Set<Address>
        recommends
            self.wf(),
            self.valid_ranking(ranking)
        decreases self.get_rank(ranking), 1int
    {
        if !self.has_root() {
            set!{}
        } else if self.root() is Leaf {
            set!{self.root}
        } else {
            let num_children = self.root().get_Index_children().len();
            let subtree_addrs = Seq::new(num_children, |i: int| self.child_reachable_addrs_using_ranking(ranking, i as nat));
            union_seq_of_sets(subtree_addrs).insert(self.root)
        }
    }

    pub open spec(checked) fn child_reachable_addrs_using_ranking(self, ranking: Ranking, i: nat) -> Set<Address>
        recommends
            self.wf(),
            self.valid_ranking(ranking),
            self.root() is Index,
            0 <= i < self.root().get_Index_children().len()
        decreases self.get_rank(ranking), 0int
        when {
            &&& 0 <= i < self.root().get_Index_children().len()
            &&& self.child_at_idx(i).get_rank(ranking) < self.get_rank(ranking)
        }
    {
        self.child_at_idx(i).reachable_addrs_using_ranking(ranking)
    }

    pub open spec(checked) fn tight_disk_view(self) -> bool
    {
        self.acyclic() ==> self.representation() == self.disk_view.representation()
    }

    pub open spec/*XXX (checked)*/ fn query_internal(self, key: Key, ranking: Ranking) -> Message
        recommends
            self.wf(),
            self.valid_ranking(ranking)
        decreases self.get_rank(ranking)
        when {
            self.root() is Index ==> {
                let r = self.root().route(key);
                &&& self.root().valid_child_index((r + 1) as nat)
                &&& self.child_at_idx((r + 1) as nat).get_rank(ranking) < self.get_rank(ranking)
            }
        }
    {
        // Need route and child_at_idx ensures to restore checked
        let node = self.root();
        let r = node.route(key);
        if node is Leaf {
            if r >= 0 && node.get_Leaf_keys()[r] == key {
                node.get_Leaf_msgs()[r]
            } else {
                Message::Update{delta: nop_delta()}
            }
        } else {
            self.child_at_idx((r+1) as nat).query_internal(key, ranking)
        }
    }

    pub open spec/*XXX (checked)*/ fn query(self, key: Key) -> Message
    {
        // Need route ensures to satisfy query_internal when to restore checked
        if self.acyclic() {
            self.query_internal(key, self.the_ranking())
        } else {
            Message::Update{delta: nop_delta()}
        }
    }

    pub open spec(checked) fn grow(self, addr: Address) -> LinkedBranch
        recommends
            self.wf(),
            self.disk_view.is_fresh(set!{addr})
    {
        let new_root = Node::Index{pivots: seq![], children: seq![self.root]};
        let new_disk_view = self.disk_view.modify_disk(addr, new_root);
        LinkedBranch{root: addr, disk_view: new_disk_view}
    }

    pub open spec/*XXX (checked)*/ fn insert_leaf(self, key: Key, msg: Message) -> LinkedBranch
        recommends
            self.wf(),
            self.root() is Leaf
    {
        // Need largest_lte ensures to restore checked
        let node = self.root();
        let llte = Key::largest_lte(node.get_Leaf_keys(), key);
        let new_node =
            if 0 <= llte && node.get_Leaf_keys()[llte] == key {
                Node::Leaf{keys: node.get_Leaf_keys(), msgs: node.get_Leaf_msgs().update(llte, msg)}
            } else {
                Node::Leaf{keys: node.get_Leaf_keys().insert(llte+1, key), msgs: node.get_Leaf_msgs().insert(llte+1, msg)}
            };
        LinkedBranch{root: self.root, disk_view: self.disk_view.modify_disk(self.root, new_node)}
    }

    pub open spec/*XXX (checked)*/ fn insert(self, key: Key, msg: Message, path: Path) -> LinkedBranch
        recommends
            self.wf(),
            path.valid(),
            path.branch == self,
            path.key == key,
            path.target().root() is Leaf,
    {
        // Need path.valid() ==> path.target().has_root() && path.target().wf() to restore checked
        path.substitute(path.target().insert_leaf(key, msg))
    }

    pub open spec(checked) fn append_to_new_leaf(self, new_keys: Seq<Key>, new_msgs: Seq<Message>) -> LinkedBranch
        recommends
            self.wf(),
            self.root() is Leaf,
            new_keys.len() == new_msgs.len(),
            Key::is_strictly_sorted(new_keys)
    {
        let new_node = Node::Leaf{keys: new_keys, msgs: new_msgs};
        let new_disk_view = self.disk_view.modify_disk(self.root, new_node);
        LinkedBranch{root: self.root, disk_view: new_disk_view}
    }

    pub open spec/*XXX (checked)*/ fn append(self, keys: Seq<Key>, msgs: Seq<Message>, path: Path) -> LinkedBranch
        recommends
            self.wf(),
            path.valid(),
            path.branch == self,
            path.target().root() == (Node::Leaf{keys: seq![], msgs: seq![]}),
            keys.len() > 0,
            keys.len() == msgs.len(),
            Key::is_strictly_sorted(keys),
            path.key == keys[0],
            path.path_equiv(keys.last())
    {
        // Need path.valid() ==> path.target().wf() to restore checked
        path.substitute(path.target().append_to_new_leaf(keys, msgs))
    }

    pub open spec(checked) fn split_leaf(self, split_arg: SplitArg, right_root_addr: Address) -> (LinkedBranch, LinkedBranch)
        recommends
            self.has_root(),
            split_arg.wf(self),
            self.disk_view.is_fresh(set!{right_root_addr})
    {
        let pivot = split_arg.get_pivot();
        let split_index = Key::largest_lt(self.root().get_Leaf_keys(), pivot) + 1;
        let left_root = Node::Leaf{
            keys: self.root().get_Leaf_keys().take(split_index),
            msgs: self.root().get_Leaf_msgs().take(split_index)
        };
        let right_root = Node::Leaf{
            keys: self.root().get_Leaf_keys().skip(split_index),
            msgs: self.root().get_Leaf_msgs().skip(split_index)
        };
        let new_disk_view = self.disk_view
            .modify_disk(self.root, left_root)
            .modify_disk(right_root_addr, right_root);
        let left_index = LinkedBranch{root: self.root, disk_view: new_disk_view};
        let right_index = LinkedBranch{root: right_root_addr, disk_view: new_disk_view};
        (left_index, right_index)
    }

    pub open spec(checked) fn sub_index(self, from: int, to: int) -> Node
        recommends
            self.has_root(),
            self.root() is Index,
            self.root().get_Index_children().len() == self.root().get_Index_pivots().len() + 1,
            0 <= from < to <= self.root().get_Index_children().len()
    {
        Node::Index{
            pivots: self.root().get_Index_pivots().subrange(from, to-1),
            children: self.root().get_Index_children().subrange(from, to)
        }
    }

    pub open spec/*XXX (checked)*/ fn split_index(self, split_arg: SplitArg, right_root_addr: Address) -> (LinkedBranch, LinkedBranch)
        recommends
            self.has_root(),
            split_arg.wf(self),
            self.disk_view.is_fresh(set!{right_root_addr})
    {
        // Possibly lexical match failure for sub_index recommends
        let pivot_index = split_arg.get_SplitIndex_pivot_index();
        let left_root = self.sub_index(0, pivot_index + 1);
        let right_root = self.sub_index(pivot_index + 1, self.root().get_Index_children().len() as int);
        let new_disk_view = self.disk_view
            .modify_disk(self.root, left_root)
            .modify_disk(right_root_addr, right_root);
        let left_index = LinkedBranch{root: self.root, disk_view: new_disk_view};
        let right_index = LinkedBranch{root: right_root_addr, disk_view: new_disk_view};
        (left_index, right_index)
    }

    pub open spec(checked) fn split_node(self, split_arg: SplitArg, right_root_addr: Address) -> (LinkedBranch, LinkedBranch)
        recommends
            self.has_root(),
            split_arg.wf(self),
            self.disk_view.is_fresh(set!{right_root_addr})
    {
        if (self.root() is Leaf) {
            self.split_leaf(split_arg, right_root_addr)
        } else {
            self.split_index(split_arg, right_root_addr)
        }
    }

    pub open spec/*XXX (checked)*/ fn can_split_child_of_index(self, split_arg: SplitArg, new_child_addr: Address) -> bool
    {
        // Need route ensures to restore checked
        &&& self.has_root()
        &&& self.root() is Index
        &&& self.root().wf()
        &&& {
            let child_idx = self.root().route(split_arg.get_pivot()) + 1;
            &&& self.child_at_idx(child_idx as nat).has_root()
            &&& split_arg.wf(self.child_at_idx(child_idx as nat))
            &&& self.child_at_idx(child_idx as nat).disk_view.is_fresh(set!{new_child_addr})
            }
    }

    pub open spec/*XXX (checked)*/ fn split_child_of_index(self, split_arg: SplitArg, new_child_addr: Address) -> LinkedBranch
        recommends self.can_split_child_of_index(split_arg, new_child_addr)
    {
        // Need route ensures to restore checked
        let pivot = split_arg.get_pivot();
        let child_idx = self.root().route(pivot) + 1;
        let (left_branch, right_branch) = self.child_at_idx(child_idx as nat).split_node(split_arg, new_child_addr);
        let new_root = Node::Index{
            pivots: self.root().get_Index_pivots().insert(child_idx, pivot),
            children: self.root().get_Index_children().insert(child_idx + 1, new_child_addr)
        };
        let new_disk_view = self.disk_view
            .merge_disk(left_branch.disk_view)
            .modify_disk(self.root, new_root);
        LinkedBranch{root: self.root, disk_view: new_disk_view}
    }

    pub open spec(checked) fn split(self, addr: Address, path: Path, split_arg: SplitArg) -> LinkedBranch
        recommends
            self.wf(),
            path.valid(),
            path.branch == self,
            path.target().can_split_child_of_index(split_arg, addr),
            self.disk_view.is_fresh(set!{addr})
    {
        path.substitute(path.target().split_child_of_index(split_arg, addr))
    }
}

pub open spec(checked) fn empty_linked_branch(root: Address) -> LinkedBranch
{
    LinkedBranch{root: root, disk_view: empty_disk().modify_disk(root, Node::Leaf{keys: seq![], msgs: seq![]})}
}

// TODO (x9du): may want to move this to a utils file
pub open spec(checked) fn union_seq_of_sets<T>(s: Seq<Set<T>>) -> Set<T>
    decreases s.len()
{
    if s.len() == 0 {
        set!{}
    } else {
        s[0] + union_seq_of_sets(s.skip(1))
    }
}

#[verifier::ext_equal]
pub struct Path {
    pub branch: LinkedBranch,
    pub key: Key,
    pub depth: nat
}

impl Path {
    pub open spec/*XXX (checked)*/ fn subpath(self) -> Path
        recommends
            0 < self.depth,
            self.branch.wf(),
            self.branch.root() is Index
    {
        // Need route ensures to restore checked
        let r = self.branch.root().route(self.key) + 1;
        Path{branch: self.branch.child_at_idx(r as nat), key: self.key, depth: (self.depth - 1) as nat}
    }

    pub open spec(checked) fn valid(self) -> bool
        decreases self.depth
    {
        &&& self.branch.wf()
        &&& 0 < self.depth ==> self.branch.root() is Index
        &&& 0 < self.depth ==> self.subpath().valid()
    }

    pub open spec(checked) fn target(self) -> LinkedBranch
        recommends self.valid()
        decreases self.depth
    {
        if 0 == self.depth {
            self.branch
        } else {
            self.subpath().target()
        }
    }

    pub open spec(checked) fn substitute(self, replacement: LinkedBranch) -> LinkedBranch
        recommends self.valid()
    {
        LinkedBranch{root: self.branch.root, disk_view: replacement.disk_view}
    }

    pub open spec(checked) fn path_equiv(self, other_key: Key) -> bool
        recommends self.valid()
        decreases self.depth, 1int
    {
        &&& self.branch.root().route(self.key) == self.branch.root().route(other_key)
        &&& 0 < self.depth ==> self.subpath().path_equiv(other_key)
    }
}

}