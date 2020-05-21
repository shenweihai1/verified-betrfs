include "EvictModel.i.dfy"
include "DeallocImpl.i.dfy"
include "SyncImpl.i.dfy"

module EvictImpl {
  import opened IOImpl
  import opened BookkeepingImpl
  import opened DeallocImpl
  import opened SyncImpl
  import EvictModel
  import opened DiskOpImpl
  import opened StateImpl
  import opened Bounds
  import opened MainDiskIOHandler

  import opened Options
  import opened Maps
  import opened Sequences
  import opened Sets

  import opened NativeTypes

  import LruModel

  method Evict(k: ImplConstants, s: ImplVariables, ref: BT.G.Reference)
  requires s.WF()
  requires s.ready
  requires ref in s.cache.I()
  modifies s.Repr()
  ensures WellUpdated(s)
  ensures s.ready
  ensures s.I() == EvictModel.Evict(Ic(k), old(s.I()), ref)
  {
    s.lru.Remove(ref);
    s.cache.Remove(ref);
    assert s.I().cache == EvictModel.Evict(Ic(k), old(s.I()), ref).cache;
  }

  method NeedToWrite(s: ImplVariables, ref: BT.G.Reference)
  returns (b: bool)
  requires s.WF()
  requires s.ready
  ensures b == EvictModel.NeedToWrite(s.I(), ref)
  {
    var eph := s.ephemeralIndirectionTable.GetEntry(ref);
    if eph.Some? && eph.value.loc.None? {
      return true;
    }

    if (s.frozenIndirectionTable != null) {
      var fro := s.frozenIndirectionTable.GetEntry(ref);
      if fro.Some? && fro.value.loc.None? {
        return true;
      }
    }

    return false;
  }

  method CanEvict(s: ImplVariables, ref: BT.G.Reference)
  returns (b: bool)
  requires s.WF()
  requires s.ready
  requires ref in s.ephemeralIndirectionTable.I().graph ==>
      ref in s.ephemeralIndirectionTable.I().locs
  ensures b == EvictModel.CanEvict(s.I(), ref)
  {
    var eph := s.ephemeralIndirectionTable.GetEntry(ref);
    if (eph.Some?) {
      return BC.OutstandingWrite(ref, eph.value.loc.value) !in s.outstandingBlockWrites.Values;
    } else {
      return true;
    }
  }

  method EvictOrDealloc(k: ImplConstants, s: ImplVariables, io: DiskIOHandler)
  requires Inv(k, s)
  requires s.ready
  requires io.initialized()
  requires |s.cache.I()| > 0
  requires io !in s.Repr()
  modifies io
  modifies s.Repr()
  ensures WellUpdated(s)
  ensures s.ready
  ensures EvictModel.EvictOrDealloc(Ic(k), old(s.I()), old(IIO(io)), s.I(), IIO(io))
  {
    var ref := FindDeallocable(s);
    DeallocModel.FindDeallocableCorrect(s.I());

    if ref.Some? {
      print "dealloc\n";
      Dealloc(k, s, io, ref.value);
    } else {
      var refOpt := s.lru.NextOpt();
      if refOpt.None? {
        print "lru none\n";
      } else {
        var ref := refOpt.value;
        var needToWrite := NeedToWrite(s, ref);
        if needToWrite {
          if s.outstandingIndirectionTableWrite.None? {
            print "trying to write block ", ref, "\n";
            TryToWriteBlock(k, s, io, ref);
          } else {
            print "not writing due to indirection table ", ref, "\n";
          }
        } else {
          var canEvict := CanEvict(s, ref);
          if canEvict {
            print "evict ", ref, "\n";
            Evict(k, s, ref);
          } else {
            print "can't evict ", ref, "\n";
          }
        }
      }
    }
  }

  method cleanOldestNodes(k: ImplConstants, s: ImplVariables, io: DiskIOHandler)
  requires Inv(k, s)
  requires s.ready
  requires io.initialized()
  requires |s.cache.I()| > 0
  requires io !in s.Repr()
  modifies io
  modifies s.Repr()
  ensures WellUpdated(s)
  ensures s.ready
  {
    return;
    var headroom;
    if MaxCacheSizeUint64() < s.cache.Count() {
      headroom := 0;
    } else {
      headroom := MaxCacheSizeUint64() - s.cache.Count();
    }
    if 10 <= headroom {
      return;
    }
    var count := 10 - headroom;
    var refs := s.lru.NextN(count);
    var i: uint64 := 0;
    while i < |refs| as uint64 {
      var ref := refs[i];
      var needToWrite := NeedToWrite(s, ref);
      if needToWrite {
        if s.outstandingIndirectionTableWrite.None? {
          TryToWriteBlock(k, s, io, ref);
        } else {
        }
      }
      i := i + 1;
    }
  }

  
  method PageInNodeReqOrMakeRoom(k: ImplConstants, s: ImplVariables, io: DiskIOHandler, ref: BT.G.Reference)
  requires Inv(k, s)
  requires s.ready
  requires io.initialized()
  requires io !in s.Repr()
  requires ref in s.ephemeralIndirectionTable.I().graph
  requires ref !in s.cache.I()
  modifies io
  modifies s.Repr()
  ensures WellUpdated(s)
  ensures s.ready
  ensures EvictModel.PageInNodeReqOrMakeRoom(Ic(k), old(s.I()), old(IIO(io)), ref, s.I(), IIO(io))
  {
    EvictModel.reveal_PageInNodeReqOrMakeRoom();

    cleanOldestNodes(k, s, io);
    
    if TotalCacheSize(s) <= MaxCacheSizeUint64() - 1 {
      PageInNodeReq(k, s, io, ref);
    } else {
      var c := s.cache.Count(); 
      if c > 0 {
        EvictOrDealloc(k, s, io);
      }
    }
  }
}
