include "../ByteBlockCacheSystem/Marshalling.i.dfy"
include "StateImpl.i.dfy"
include "MarshallingImpl.i.dfy"
include "MkfsModel.i.dfy"

module MkfsImpl {
  import MarshallingImpl
  import IMM = MarshallingModel
  import opened Options
  import opened NativeTypes
  import opened BucketWeights
  import SM = StateModel
  import opened BucketImpl
  import opened BoxNodeImpl
  import Marshalling
  import MkfsModel
  import opened LinearSequence_s
  import opened LinearSequence_i

  import BT = PivotBetreeSpec
  import BC = BlockCache
  import opened SectorType
  import ReferenceType`Internal
  import opened DiskLayout
  import opened Bounds
  import ValueType`Internal
  import SI = StateImpl
  import D = AsyncDisk
  import IT = IndirectionTable

  import ADM = ByteSystem

  method Mkfs() returns (diskContents :  map<Addr, seq<byte>>)
  ensures MkfsModel.InitDiskContents(diskContents)
  ensures ADM.BlocksDontIntersect(diskContents)
  {
    var s1addr := Superblock1Location().addr;
    var s2addr := Superblock2Location().addr;
    var indirectionTableAddr := IndirectionTable1Addr();
    var nodeAddr := NodeBlockSizeUint64() * MinNodeBlockIndexUint64();

    WeightBucketEmpty();
    
    linear var empty := MutBucket.Alloc();
    linear var buckets := lseq_alloc(1);
    lseq_give_inout(inout buckets,0, empty);
    var node := new Node([], None, buckets);

    WeightBucketListOneEmpty();
    assert node.I().buckets == [empty.I()];    // OBSERVE (trigger)
    ghost var sector:SI.Sector := SI.SectorNode(node);
    ghost var is:SM.Sector := SI.ISector(sector);

    assert SM.WFNode(is.node) by {
      reveal_WeightBucketList();
    }
    var bNode_array := MarshallingImpl.MarshallCheckedSector(SI.SectorNode(node));
    var bNode := bNode_array[..];

    var nodeLoc := Location(nodeAddr, |bNode| as uint64);
    assert ValidNodeLocation(nodeLoc)
      by {
        ValidNodeAddrMul(MinNodeBlockIndexUint64());
      }

    var sectorIndirectionTable := new IT.BoxedIndirectionTable(nodeLoc);

    assert sectorIndirectionTable.I() == IndirectionTable(
      map[0 := nodeLoc],
      map[0 := []]
    );

    assert BC.WFCompleteIndirectionTable(sectorIndirectionTable.I());
    assert SM.WFSector(SI.ISector(SI.SectorIndirectionTable(sectorIndirectionTable)));
    var bIndirectionTable_array := MarshallingImpl.MarshallCheckedSector(SI.SectorIndirectionTable(sectorIndirectionTable));

    assert bIndirectionTable_array != null;

    var bIndirectionTable := bIndirectionTable_array[..];

    var indirectionTableLoc := Location(indirectionTableAddr, |bIndirectionTable| as uint64);
    assert ValidIndirectionTableLocation(indirectionTableLoc);

    var sectorSuperblock := SI.SectorSuperblock(Superblock(0, 0, 0, indirectionTableLoc));
    var bSuperblock_array := MarshallingImpl.MarshallCheckedSector(sectorSuperblock);
    var bSuperblock := bSuperblock_array[..];

    ghost var ghosty := true;
    if ghosty {
      if overlap(Superblock1Location(), nodeLoc) {
        overlappingLocsSameType(Superblock1Location(), nodeLoc);
      }
      if overlap(Superblock2Location(), nodeLoc) {
        overlappingLocsSameType(Superblock2Location(), nodeLoc);
      }
      if overlap(indirectionTableLoc, nodeLoc) {
        overlappingLocsSameType(indirectionTableLoc, nodeLoc);
      }
    }

    ghost var gnode := Marshalling.parseCheckedSector(bNode).value.node;
    assert gnode.pivotTable == [];
    assert gnode.children == None;
    //assert gnode.buckets == [ EmptyBucket() ];
    //assert Marshalling.parseCheckedSector(bNode).Some?;// == Some(SectorNode(BT.G.Node([], None, [MkfsModel.B(map[])])));
    
    diskContents := map[
      // Map ref 0 to lba 1
      s1addr := bSuperblock,
      s2addr := bSuperblock,
      indirectionTableAddr := bIndirectionTable,
      nodeAddr := bNode
    ];
  }
}
