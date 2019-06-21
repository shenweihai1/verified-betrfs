include "BlockInterface.dfy"  
include "../lib/sequences.dfy"
include "../lib/Maps.dfy"
include "MapSpec.dfy"
include "Graph.dfy"

module BetreeGraph refines Graph {
  import MS = MapSpec

  type Value(!new)

  type Key = MS.Key
  datatype BufferEntry = Insertion(value: Value)
  type Buffer = imap<Key, seq<BufferEntry>>
  datatype Node = Node(children: imap<Key, Reference>, buffer: Buffer)

  function Successors(node: Node) : iset<Reference>
  {
    iset k | k in node.children :: node.children[k]
  }
}

module BetreeBlockInterface refines BlockInterface {
  import G = BetreeGraph
}

module DiskBetree {
  import MS = MapSpec
  import BI = BetreeBlockInterface
  import opened G = BetreeGraph
  import opened Sequences
  import opened Maps
  
  datatype Layer = Layer(ref: Reference, node: Node)
  type Lookup = seq<Layer>

  predicate BufferIsDefining(log: seq<BufferEntry>) {
    && |log| > 0
  }

  predicate BufferDefinesValue(log: seq<BufferEntry>, value: Value) {
    && BufferIsDefining(log)
    && log[0].value == value
  }
  
  predicate WFNode(node: Node) {
    && (forall k :: k in node.buffer)
    && (forall k :: k !in node.children ==> BufferIsDefining(node.buffer[k]))
  }

  predicate LookupFollowsChildRefs(key: Key, lookup: Lookup) {
    && (forall i :: 0 <= i < |lookup| - 1 ==> key in lookup[i].node.children)
    && (forall i :: 0 <= i < |lookup| - 1 ==> lookup[i].node.children[key] == lookup[i+1].ref)
  }
  
  predicate LookupRespectsDisk(view: BI.View, lookup: Lookup) {
    forall i :: 0 <= i < |lookup| ==> IMapsTo(view, lookup[i].ref, lookup[i].node)
  }

  predicate LookupVisitsWFNodes(lookup: Lookup) {
    forall i :: 0 <= i < |lookup| ==> WFNode(lookup[i].node)
  }

  predicate IsPathFromRootLookup(k: Constants, view: BI.View, key: Key, lookup: Lookup) {
    && |lookup| > 0
    && lookup[0].ref == Root()
    && LookupRespectsDisk(view, lookup)
    && LookupFollowsChildRefs(key, lookup)
  }

  function TotalLog(lookup: Lookup, key: Key) : seq<BufferEntry>
  requires LookupVisitsWFNodes(lookup);
  {
    if |lookup| == 0 then [] else TotalLog(lookup[..|lookup|-1], key) + lookup[|lookup|-1].node.buffer[key]
  }

  predicate IsSatisfyingLookup(k: Constants, view: BI.View, key: Key, value: Value, lookup: Lookup) {
    && IsPathFromRootLookup(k, view, key, lookup)
    && LookupVisitsWFNodes(lookup)
    && BufferDefinesValue(TotalLog(lookup, key), value)
  }

  // Now we define the state machine
  
  datatype Constants = Constants(bck: BI.Constants)
  datatype Variables = Variables(bcv: BI.Variables)

  function EmptyNode() : Node {
    var buffer := imap key | MS.InDomain(key) :: [Insertion(MS.EmptyValue())];
    Node(imap[], buffer)
  }
    
  predicate Init(k: Constants, s: Variables) {
    && BI.Init(k.bck, s.bcv, EmptyNode())
  }
    
  predicate Query(k: Constants, s: Variables, s': Variables, key: Key, value: Value, lookup: Lookup) {
    && s == s'
    && IsSatisfyingLookup(k, s.bcv.view, key, value, lookup)
  }

  function AddMessageToBuffer(buffer: Buffer, key: Key, msg: BufferEntry) : Buffer
    requires key in buffer
  {
    buffer[key := [msg] + buffer[key]]
  }
  
  function AddMessageToNode(node: Node, key: Key, msg: BufferEntry) : Node
    requires WFNode(node)
  {
    Node(node.children, AddMessageToBuffer(node.buffer, key, msg))
  }
  
  predicate InsertMessage(k: Constants, s: Variables, s': Variables, key: Key, msg: BufferEntry, oldroot: Node) {
    && IMapsTo(s.bcv.view, Root(), oldroot)
    && WFNode(oldroot)
    && var newroot := AddMessageToNode(oldroot, key, msg);
    && var writeop := G.WriteOp(Root(), newroot);
    && BI.Transaction(k.bck, s.bcv, s'.bcv, [writeop])
  }

  predicate Flush(k: Constants, s: Variables, s': Variables, parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference) {
    var movedKeys := iset k | k in parent.children && parent.children[k] == childref;
    && IMapsTo(s.bcv.view, parentref, parent)
    && IMapsTo(s.bcv.view, childref, child)
    && WFNode(parent)
    && WFNode(child)
    && var newbuffer := imap k :: (if k in movedKeys then parent.buffer[k] + child.buffer[k] else child.buffer[k]);
    && var newchild := Node(child.children, newbuffer);
    && var newparentbuffer := imap k :: (if k in movedKeys then [] else parent.buffer[k]);
    && var newparentchildren := imap k | k in parent.children :: (if k in movedKeys then newchildref else parent.children[k]);
    && var newparent := Node(newparentchildren, newparentbuffer);
    && var allocop := G.AllocOp(newchildref, newchild);
    && var writeop := G.WriteOp(parentref, newparent);
    && BI.Transaction(k.bck, s.bcv, s'.bcv, [allocop, writeop])
  }

  predicate Grow(k: Constants, s: Variables, s': Variables, oldroot: Node, newchildref: Reference) {
    && IMapsTo(s.bcv.view, Root(), oldroot)
    && var newchild := oldroot;
    && var newroot := Node(
        imap key | MS.InDomain(key) :: newchildref,
        imap key | MS.InDomain(key) :: []);
    && var allocop := G.AllocOp(newchildref, newchild);
    && var writeop := G.WriteOp(Root(), newroot);
    && BI.Transaction(k.bck, s.bcv, s'.bcv, [allocop, writeop])
  }

  datatype NodeFusion = NodeFusion(
    parentref: Reference,
    fused_childref: Reference,
    left_childref: Reference,
    right_childref: Reference,
    fused_parent: Node,
    split_parent: Node,
    fused_child: Node,
    left_child: Node,
    right_child: Node,
    
    left_keys: iset<Key>,
    right_keys: iset<Key>
  )

  predicate ValidFusion(fusion: NodeFusion)
  {
    && fusion.left_keys !! fusion.right_keys
    && (forall key :: key in fusion.left_keys ==> IMapsTo(fusion.fused_parent.children, key, fusion.fused_childref))
    && (forall key :: key in fusion.left_keys ==> IMapsTo(fusion.split_parent.children, key, fusion.left_childref))

    && (forall key :: key in fusion.right_keys ==> IMapsTo(fusion.fused_parent.children, key, fusion.fused_childref))
    && (forall key :: key in fusion.right_keys ==> IMapsTo(fusion.split_parent.children, key, fusion.right_childref))

    && (forall key :: (key !in fusion.left_keys) && (key !in fusion.right_keys) ==>
      IMapsAgreeOnKey(fusion.split_parent.children, fusion.fused_parent.children, key))

    && fusion.fused_parent.buffer == fusion.split_parent.buffer

    && (forall key :: key in fusion.left_keys ==> IMapsAgreeOnKey(fusion.fused_child.children, fusion.left_child.children, key))
    && (forall key :: key in fusion.left_keys ==> IMapsAgreeOnKey(fusion.fused_child.buffer, fusion.left_child.buffer, key))

    && (forall key :: key in fusion.right_keys ==> IMapsAgreeOnKey(fusion.fused_child.children, fusion.right_child.children, key))
    && (forall key :: key in fusion.right_keys ==> IMapsAgreeOnKey(fusion.fused_child.buffer, fusion.right_child.buffer, key))
  }

  predicate Split(k: Constants, s: Variables, s': Variables, fusion: NodeFusion)
  {
    && IMapsTo(s.bcv.view, fusion.parentref, fusion.fused_parent)
    && IMapsTo(s.bcv.view, fusion.fused_childref, fusion.fused_child)
    && ValidFusion(fusion)
    && WFNode(fusion.fused_parent)
    && WFNode(fusion.fused_child)
    && WFNode(fusion.left_child)
    && WFNode(fusion.right_child)
    && var allocop_left := G.AllocOp(fusion.left_childref, fusion.left_child);
    && var allocop_right := G.AllocOp(fusion.right_childref, fusion.right_child);
    && var writeop := G.WriteOp(fusion.parentref, fusion.split_parent);
    && BI.Transaction(k.bck, s.bcv, s'.bcv, [allocop_left, allocop_right, writeop])
  }

  predicate Merge(k: Constants, s: Variables, s': Variables, fusion: NodeFusion)
  {
    && IMapsTo(s.bcv.view, fusion.parentref, fusion.split_parent)
    && IMapsTo(s.bcv.view, fusion.left_childref, fusion.left_child)
    && IMapsTo(s.bcv.view, fusion.right_childref, fusion.right_child)
    && ValidFusion(fusion)
    && var allocop := G.AllocOp(fusion.fused_childref, fusion.fused_child);
    && var writeop := G.WriteOp(fusion.parentref, fusion.fused_parent);
    && BI.Transaction(k.bck, s.bcv, s'.bcv, [allocop, writeop])
  }

  predicate GC(k: Constants, s: Variables, s': Variables, refs: iset<Reference>) {
    BI.GC(k.bck, s.bcv, s'.bcv, refs)
  }
  
  datatype Step =
    | QueryStep(key: Key, value: Value, lookup: Lookup)
    | InsertMessageStep(key: Key, msg: BufferEntry, oldroot: Node)
    | FlushStep(parentref: Reference, parent: Node, childref: Reference, child: Node, newchildref: Reference)
    | GrowStep(oldroot: Node, newchildref: Reference)
    | SplitStep(fusion: NodeFusion)
    | GCStep(refs: iset<Reference>)
    
  predicate NextStep(k: Constants, s: Variables, s': Variables, step: Step) {
    match step {
      case QueryStep(key, value, lookup) => Query(k, s, s', key, value, lookup)
      case InsertMessageStep(key, msg, oldroot) => InsertMessage(k, s, s', key, msg, oldroot)
      case FlushStep(parentref, parent, childref, child, newchildref) => Flush(k, s, s', parentref, parent, childref, child, newchildref)
      case GrowStep(oldroot, newchildref) => Grow(k, s, s', oldroot, newchildref)
      case SplitStep(fusion) => Split(k, s, s', fusion)
      case GCStep(refs) => GC(k, s, s', refs)
    }
  }

  predicate Next(k: Constants, s: Variables, s': Variables) {
    exists step: Step :: NextStep(k, s, s', step)
  }
}
