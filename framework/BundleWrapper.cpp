#include "BundleWrapper.h"
#include "Bundle.cpp"

using namespace MainHandlers_Compile;

std::pair<Constants, Variables> handle_InitState()
{
  auto tup2 = __default::InitState();
  Constants k;
  k.k = shared_ptr<BetreeGraphBlockCache_Compile::Constants>(
      new BetreeGraphBlockCache_Compile::Constants(tup2.t0));
  Variables hs;
  hs.hs = tup2.t1;
  return make_pair(k, hs);
}

DafnyMap<uint64, DafnySequence<uint8>> handle_Mkfs()
{
  return MkfsImpl_Compile::__default::Mkfs();
}

uint64 handle_PushSync(Constants k, Variables hs, shared_ptr<MainDiskIOHandler_Compile::DiskIOHandler> io)
{
  return __default::handlePushSync(*k.k, hs.hs, io);
}

std::pair<bool, bool> handle_PopSync(Constants k, Variables hs, shared_ptr<MainDiskIOHandler_Compile::DiskIOHandler> io, uint64 id)
{
  auto p = __default::handlePopSync(*k.k, hs.hs, io, id);
  return make_pair(p.t0, p.t1);
}

bool handle_Insert(Constants k, Variables hs, shared_ptr<MainDiskIOHandler_Compile::DiskIOHandler> io, Key const& key, DafnySequence<uint8> value)
{
  return __default::handleInsert(*k.k, hs.hs, io, key, value);
}

std::pair<bool, DafnySequence<uint8>> handle_Query(Constants k, Variables hs, shared_ptr<MainDiskIOHandler_Compile::DiskIOHandler> io, Key const& key)
{
  auto p = __default::handleQuery(*k.k, hs.hs, io, key);
  return make_pair(p.is_Some(), p.v_Some.value);
}

std::pair<bool, UI_Compile::SuccResultList> handle_Succ(Constants k, Variables hs, shared_ptr<MainDiskIOHandler_Compile::DiskIOHandler> io, UI_Compile::RangeStart start, uint64 maxToFind)
{
  auto p = __default::handleSucc(*k.k, hs.hs, io, start, maxToFind);
  return make_pair(p.is_Some(), p.v_Some.value);
}

void handle_ReadResponse(Constants k, Variables hs, shared_ptr<MainDiskIOHandler_Compile::DiskIOHandler> io)
{
  __default::handleReadResponse(*k.k, hs.hs, io);
}

void handle_WriteResponse(Constants k, Variables hs, shared_ptr<MainDiskIOHandler_Compile::DiskIOHandler> io)
{
  __default::handleWriteResponse(*k.k, hs.hs, io);
}

uint64 MaxKeyLen()
{
  return KeyType_Compile::MaxLen();
}

uint64 MaxValueLen()
{
  return ValueType_Compile::__default::MaxLen();
}
