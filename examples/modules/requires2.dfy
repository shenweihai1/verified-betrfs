// Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
// SPDX-License-Identifier: BSD-2-Clause

// TotalOrder (for, e.g., KeyType)

abstract module TotalOrder {
  // abstract module: these need to be filled in
  type K
  function lt(a: K, b: K)
  lemma is_transitive ...
}

module TotalOrderUtil(T: TotalOrder) {
  // useful utilities like IsStrictlySorted
  // this module doesn't depend on the definition
  // of lt, all its lemmas can be proven from
  // the abstract TotalOrder.
  // Therefore, TotalOrderUtil is *concrete*:
  // that is, it automatically becomes concrete when supplied
  // with a concrete T.
}

abstract module TotalOrderImpl(T: TotalOrder) {
  // For fast implementation of lt and so on.

  // This module is abstract. Even if someone picks out
  // a concrete T, they need to implement the compute_lt method.

  method compute_lt(a: T.K, b: T.K)
}

// State machines

abstract module Ifc {
  type TransitionLabel
}

abstract module StateMachine(ifc: Ifc) {
  type Variables
  predicate Next(s: Variables, s': Variables)
  // ...
}

abstract module StateMachineRefinement(L: StateMachine, H: StateMachine)
    requires L.ifc == H.ifc
{
  // ...
}

// MapSpec

abstract module ValueType {
  type Value
}

module MapIfc(K: TotalOrder, V: ValueType) {
  // concrete when K and V are concrete
  type TransitionLabel =
    | Query(k: K.K, v: V.V)
    | Insert(k: K.K, v: V.V)
    | ...
}

module MapSpec(K: TotalOrder, V: ValueType)
    refines StateMachine(MapIfc(K, V))
{
  // concrete when K and V are concrete
}

// MessageType

abstract module MessageType(V: ValueType) {
  type Delta // abstract

  datatype Message =
    | Define(value: V.Value)
    | Update(delta: Delta)

  // abstract lemmas here for
  // properties of Delta (e.g., associativity lemmas)
}

// Concretize MessageType into a BasicMessageType
// where the only delta is a no-op. Hence the only Messages
// are updates and no-ops.
// Still parameterized over V.
module BasicMessage(V: ValueType) refines MessageType(V) {
  datatype Delta = NoOp

  // ...
}

// B-epsilon tree
// Parameterized over key, value, and message type

module Betree(K: TotalOrder, M: MessageType)
  refines StateMachine(MapIfc(K, M.V))
{
  import V = M.V
}

module Betree_Refines_Map(K: TotalOrder, V: ValueType)
  refines StateMachineRefinement(
    Betree(K, BasicMessage(V)),
    MapSpec(K, V)
  )


// PivotBetree

abstract module Graph {
  type Reference
  type Node
  function successors(n: Node) : set<Reference>
}

abstract module GraphOps(Ifc: Ifc, G: Graph) {
  // ...
}

module GraphStateMachine(Ops: GraphOps)
  refines StateMachine(Ops.Ifc)
{
  // ...
}

module PivotBetreeGraph(K: KeyType, M: MessageType) refines Graph {
  import V = M.V
  type Reference = uint64
  type Node = Node(...)
  function successors(n: Node) : set<Reference> { ... }
}

module PivotBetreeGraphOps(K: KeyType, M: MessageType)
    refines GraphOps(MapIfc(K, V), PivotBetreeGraph(K, M))
{
  import V = M.V
  // define split, query, insert, etc.
}

// module aliasing
module PivotBetree(K: TotalOrder, M: MessageType) :=
  GraphStateMachine(PivotBetreeGraphOps(K, M))

module PivotBetree_Refines_Betree(K: TotalOrder, M: MessageType)
  refines StateMachineRefinement(PivotBetree(K, M), Betree(K, M))
{
  import V = M.V
  import TotalOrderUtil(K) // this will probably be useful for the proof

  // ...
}

// Generic mechanism for composing two refinements

module ComposeRefinements(
    Ref1: StateMachineRefinement,
    Ref2: StateMachineRefinement)
  refines StateMachineRefinement(Ref1.L, Ref2.H)
  requires Ref1.H == Ref2.L
{
  // This module is concrete, proof of composition
  // is entirely self-contained and dependent only on
  // abstract properties of Ref1 and Ref2

  import A = Ref1.L
  import B = Ref1.H
  import C = Ref2.H

  // proof here ...
}

// Now we can put it together:
// (Assume K and V are some bound modules)
import PivotBetree_Refines_Map =
  ComposeRefinements(
    PivotBetree_Refines_Betree(K, BasicMessage(V)),
    Betree_Refines_Map(K, V))

// Define what it means to be CrashSafe

module CrashableIfc(InnerIfc: Ifc) refines Ifc
{
  type TransitionLabel =
    | CrashOp
    | NormalOp(InnerIfc.TransitionLabel)
}

module CrashSafeMachine(sm: StateMachine(Ifc))
  refines StateMachine(sm)  // note bound arg

// Define IOSystem

module Machine(Ifc: Ifc) {
}

module IOSystem(m: Machine(Ifc))
  refines StateMachine(CrashableIfc(m.Ifc)) // NB reduced redundant param
{
  // ...
}

// Define a cache

module BlockCache(Ops: GraphOps)
  refines Machine(Ops.Ifc)
{
  // ...
}

module BlockCacheRefinementThm(Ops: GraphOps)
  refines StateMachineRefinement(
    IOSystem(Ops.Ifc, BlockCache(Ops)),
    CrashSafeMachine(GraphStateMachine(Ops))
  )
{
  // proof here
}

// BlockCacheRefinementThm can now be instantiated

module AwesomeTheorem refines BlockCacheRefinementThm(
    PivotBetreeGraphOps(K, V))
{
    // Hmm, not sure how this was supposed to work.
}

// Suppose in our implementation, we have a bunch of
// nested modules from the top level: Impl
// imports A which imports B ...
// all parameterized over KeyType
//
// Impl(K) -> A(K) -> B(K) -> C(K) -> D(K) -> E(K) -> TotalOrderImpl(K)
//
// As mentioned above, TotalOrderImpl(K) is abstract, so this whole chain
// is abstract. What's the best way to instantiate this module?
//
// In this system, we could make TotalOrderImpl a concrete argument,
//
// module Impl(K: KeyType, KI: TotalOrderImpl(K))
//
// and pass KI down the entire module chain.
//
// Thus any module which depends (even indirectly) on TotalOrderImpl will
// need to declare this in their signature and pass it down to the child module.
// I don't think this is necessarily a bad thing.
// Eww. :v)
