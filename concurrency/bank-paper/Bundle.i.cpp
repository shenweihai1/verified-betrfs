// Dafny program Impl.i.dfy compiled into Cpp
#include "DafnyRuntime.h"
#include "Extern.h"
#include "LinearExtern.h"
#include "Impl.i.h"
#include <chrono>
#include <random>
#include <unistd.h> // Header file for usleep
using BigNumber = int;
const int num_threads = 10;
const int keyspace=100*10000; // 1M keys
const int initBalance=5001;

using namespace std::chrono;

// g++ -pthread -std=gnu++17 -g -O3 -I ../../.dafny/dafny/Binaries/ -I ../framework/ -DUSE_VSPACE -o Bundle.o Bundle.i.cpp
namespace _System  {












}// end of namespace _System 
namespace NativeTypes_Compile  {



  typedef int16 int16;

  typedef uint16 uint16;

  typedef int32 int32;

  typedef uint32 uint32;

  typedef int64 int64;

  typedef uint64 uint64;

  typedef int8 nat8;

  typedef int16 nat16;

  typedef int32 nat32;

  typedef int64 nat64;



  uint64 __default::Uint64Size()
  {
    return (uint64)8;
  }
  uint64 __default::Uint32Size()
  {
    return (uint64)4;
  }
  uint64 __default::Uint16Size()
  {
    return (uint64)2;
  }
}// end of namespace NativeTypes_Compile 
namespace Options_Compile  {

  template <typename V>
bool operator==(const Option_None<V> &left, const Option_None<V> &right) {
    (void)left; (void) right;
	return true ;
  }
  template <typename V>
bool operator==(const Option_Some<V> &left, const Option_Some<V> &right) {
    	return true 		&& left.value == right.value
    ;
  }
  template <typename V>
Option<V>::Option() {
    Option_None<V> COMPILER_result_subStruct;
    v = COMPILER_result_subStruct;
  }
  template <typename V>
inline bool is_Option_None(const struct Option<V> d) { return std::holds_alternative<Option_None<V>>(d.v); }
  template <typename V>
inline bool is_Option_Some(const struct Option<V> d) { return std::holds_alternative<Option_Some<V>>(d.v); }

}// end of namespace Options_Compile 
namespace MathUtils_Compile  {

}// end of namespace MathUtils_Compile 
namespace Bank_Compile  {

  typedef int64 nat64;





  
bool operator==(const M_M &left, const M_M &right) {
    	return true 		&& left.account__balances == right.account__balances
    ;
  }
  
bool operator==(const M_Invalid &left, const M_Invalid &right) {
    (void)left; (void) right;
	return true ;
  }
  
M::M() {
    M_M COMPILER_result_subStruct;
    COMPILER_result_subStruct.account__balances = DafnyMap<BigNumber,BigNumber>::empty();
    v = COMPILER_result_subStruct;
  }
  
inline bool is_M_M(const struct M d) { return std::holds_alternative<M_M>(d.v); }
  
inline bool is_M_Invalid(const struct M d) { return std::holds_alternative<M_Invalid>(d.v); }

  
AccountTransfer::AccountTransfer() {
    source__account = 0;
    dest__account = 0;
    money = 0;
  }
  
bool operator==(const AccountTransfer &left, const AccountTransfer &right)  {
    	return true 		&& left.source__account == right.source__account
    		&& left.dest__account == right.dest__account
    		&& left.money == right.money
    ;
  }

   BigNumber __default::NumberOfAccounts =  init__NumberOfAccounts();
   BigNumber __default::FixedTotalMoney =  init__FixedTotalMoney();

}// end of namespace Bank_Compile 
namespace GlinearMap_Compile  {

}// end of namespace GlinearMap_Compile 
namespace GhostLoc_Compile  {

  
bool operator==(const Loc_BaseLoc &left, const Loc_BaseLoc &right) {
    (void)left; (void) right;
	return true ;
  }
  
bool operator==(const Loc_ExtLoc &left, const Loc_ExtLoc &right) {
    (void)left; (void) right;
	return true ;
  }
  
Loc::Loc() {
    Loc_BaseLoc COMPILER_result_subStruct;
    v = COMPILER_result_subStruct;
  }
  
inline bool is_Loc_BaseLoc(const struct Loc d) { return std::holds_alternative<Loc_BaseLoc>(d.v); }
  
inline bool is_Loc_ExtLoc(const struct Loc d) { return std::holds_alternative<Loc_ExtLoc>(d.v); }

}// end of namespace GhostLoc_Compile 
namespace RequestIds_Compile  {


}// end of namespace RequestIds_Compile 
namespace Rw_PCMWrap_ON_Bank__Compile  {





  
M::M() {
  }
  
bool operator==(const M &left, const M &right)  {
    	return true ;
  }
}// end of namespace Rw_PCMWrap_ON_Bank__Compile 
namespace Tokens_ON_Rw__PCMWrap__ON__Bank____Compile  {


  
Token::Token() {
  }
  
bool operator==(const Token &left, const Token &right)  {
    	return true ;
  }


}// end of namespace Tokens_ON_Rw__PCMWrap__ON__Bank____Compile 
namespace PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile  {





}// end of namespace PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile 
namespace Rw_PCMExt_ON_Bank__Compile  {








}// end of namespace Rw_PCMExt_ON_Bank__Compile 
namespace Tokens_ON_Rw__PCMExt__ON__Bank____Compile  {


  
Token::Token() {
  }
  
bool operator==(const Token &left, const Token &right)  {
    	return true ;
  }


}// end of namespace Tokens_ON_Rw__PCMExt__ON__Bank____Compile 
namespace ExtTokens_ON_Rw__PCMWrap__ON__Bank___Rw__PCMExt__ON__Bank____Compile  {






}// end of namespace ExtTokens_ON_Rw__PCMWrap__ON__Bank___Rw__PCMExt__ON__Bank____Compile 
namespace RwTokens_ON_Bank__Compile  {











}// end of namespace RwTokens_ON_Bank__Compile 
namespace GlinearOption_Compile  {


  template <typename V>
bool operator==(const glOption_glNone<V> &left, const glOption_glNone<V> &right) {
    (void)left; (void) right;
	return true ;
  }
  template <typename V>
bool operator==(const glOption_glSome<V> &left, const glOption_glSome<V> &right) {
    (void)left; (void) right;
	return true ;
  }
  template <typename V>
glOption<V>::glOption() {
    glOption_glNone<V> COMPILER_result_subStruct;
    v = COMPILER_result_subStruct;
  }
  template <typename V>
inline bool is_glOption_glNone(const struct glOption<V> d) { return std::holds_alternative<glOption_glNone<V>>(d.v); }
  template <typename V>
inline bool is_glOption_glSome(const struct glOption<V> d) { return std::holds_alternative<glOption_glSome<V>>(d.v); }

}// end of namespace GlinearOption_Compile 
namespace Ptrs  {



  template <typename V>
PointsTo<V>::PointsTo() {
  }
  template <typename V>
bool operator==(const PointsTo<V> &left, const PointsTo<V> &right)  {
    	return true ;
  }

  template <typename V>
bool operator==(const PointsToLinear_PointsToLinear<V> &left, const PointsToLinear_PointsToLinear<V> &right) {
    (void)left; (void) right;
	return true ;
  }
  template <typename V>
bool operator==(const PointsToLinear_PointsToEmpty<V> &left, const PointsToLinear_PointsToEmpty<V> &right) {
    (void)left; (void) right;
	return true ;
  }
  template <typename V>
PointsToLinear<V>::PointsToLinear() {
    PointsToLinear_PointsToLinear<V> COMPILER_result_subStruct;
    v = COMPILER_result_subStruct;
  }
  template <typename V>
inline bool is_PointsToLinear_PointsToLinear(const struct PointsToLinear<V> d) { return std::holds_alternative<PointsToLinear_PointsToLinear<V>>(d.v); }
  template <typename V>
inline bool is_PointsToLinear_PointsToEmpty(const struct PointsToLinear<V> d) { return std::holds_alternative<PointsToLinear_PointsToEmpty<V>>(d.v); }

  template <typename V>
PointsToArray<V>::PointsToArray() {
  }
  template <typename V>
bool operator==(const PointsToArray<V> &left, const PointsToArray<V> &right)  {
    	return true ;
  }


}// end of namespace Ptrs 
namespace BankTokens_Compile  {










  
Account::Account() {
  }
  
bool operator==(const Account &left, const Account &right)  {
    	return true ;
  }

}// end of namespace BankTokens_Compile 
namespace LinearCells  {



  template <typename V>
LCellContents<V>::LCellContents() {
    v = Options_Compile::Option<V>();
  }
  template <typename V>
bool operator==(const LCellContents<V> &left, const LCellContents<V> &right)  {
    	return true 		&& left.v == right.v
    ;
  }

}// end of namespace LinearCells 
namespace BitOps_Compile  {


  uint8 __default::bit__or__uint8(uint8 a, uint8 b)
  {
    return uint8((uint8(a)) | (uint8(b)));
  }
  uint8 __default::bit__and__uint8(uint8 a, uint8 b)
  {
    return uint8((uint8(a)) & (uint8(b)));
  }
  uint8 __default::bit__xor__uint8(uint8 a, uint8 b)
  {
    return uint8((uint8(a)) ^ (uint8(b)));
  }
  uint64 __default::bit__or__uint64(uint64 a, uint64 b)
  {
    return uint64((uint64(a)) | (uint64(b)));
  }
  uint64 __default::bit__and__uint64(uint64 a, uint64 b)
  {
    return uint64((uint64(a)) & (uint64(b)));
  }
  uint64 __default::bit__xor__uint64(uint64 a, uint64 b)
  {
    return uint64((uint64(a)) ^ (uint64(b)));
  }
}// end of namespace BitOps_Compile 
namespace Atomics  {







}// end of namespace Atomics 
namespace Mutexes  {





  template <typename V>
Mutex<V>::Mutex() {
    at = Atomics::get_Atomic_default<bool, GlinearOption_Compile::glOption <LinearCells::LCellContents <V> > >();
    cell = LinearCells::get_LinearCell_default<V>();
  }
  template <typename V>
bool operator==(const Mutex<V> &left, const Mutex<V> &right)  {
    	return true 		&& left.at == right.at
    		&& left.cell == right.cell
    ;
  }
  
  template <typename V>
  V Mutex<V>::acquire()
  {
    V v = get_default<V>::call();
    bool _633_done;
    _633_done = false;
    while (!(_633_done)) {
      {
        Atomics::Atomic <bool, GlinearOption_Compile::glOption <LinearCells::LCellContents <V> > > * _634_atomic__tmp0;
        _634_atomic__tmp0 = &( ((*this).at));
        bool _out0;
        _out0 = Atomics::execute__atomic__compare__and__set__strong <bool, GlinearOption_Compile::glOption <LinearCells::LCellContents <V> > > ((*_634_atomic__tmp0), false, true);
        _633_done = _out0;
        if (_633_done) {
        }
      }
    }
    V _out1;
    _out1 = LinearCells::take__lcell <V> (((*this).cell));
    v = _out1;
    return v;
  }
  
  template <typename V>
  void Mutex<V>::release(V v)
  {
    LinearCells::give__lcell <V> (((*this).cell), v);
    {
      Atomics::Atomic <bool, GlinearOption_Compile::glOption <LinearCells::LCellContents <V> > > * _635_atomic__tmp0;
      _635_atomic__tmp0 = &( ((*this).at));
      Atomics::execute__atomic__store <bool, GlinearOption_Compile::glOption <LinearCells::LCellContents <V> > > ((*_635_atomic__tmp0), false);
    }
  }

  template <typename V>
MutexHandle<V>::MutexHandle() {
  }
  template <typename V>
bool operator==(const MutexHandle<V> &left, const MutexHandle<V> &right)  {
    	return true ;
  }

}// end of namespace Mutexes 
namespace LinearMaybe  {


}// end of namespace LinearMaybe 
namespace LinearExtern  {




}// end of namespace LinearExtern 
namespace LinearSequence__i_Compile  {






  template <typename __A>
  LinearExtern::linear_seq<__A> __default::seq__alloc__init(uint64 length, __A a)
  {
    return LinearExtern::seq_alloc <__A> (length, a);
  }
  template <typename __A>
  uint64 __default::lseq__length__as__uint64(LinearExtern::lseq <__A> & s)
  {
    return LinearExtern::lseq_length_raw <__A> (s);
  }
  template <typename __A>
  uint64 __default::lseq__length__uint64(LinearExtern::lseq <__A> & s)
  {
    uint64 n = 0;
    LinearExtern::lseq_length_bound <__A> (s);
    n = LinearExtern::lseq_length_raw <__A> (s);
    return n;
  }
  template <typename __A>
  __A* __default::lseq__peek(LinearExtern::lseq <__A> & s, uint64 i)
  {
    return &( *(LinearMaybe::peek <__A> (*(LinearExtern::lseq_share_raw <__A> (s, i)))) );
  }
  template <typename __A>
  LinearExtern::lseq <__A>  __default::lseq__alloc(uint64 length)
  {
    LinearExtern::lseq <__A>  s = LinearExtern::get_lseq_default<__A>();
    s = LinearExtern::lseq_alloc_raw <__A> (length);
    return s;
  }
  //template <typename __A>
  //LinearExtern::lseq <__A>  __default::lseq__alloc__hugetables(uint64 length)
  //{
  //  LinearExtern::lseq <__A>  s = LinearExtern::get_lseq_default<__A>();
  //  s = LinearExtern::lseq_alloc_raw_hugetables <__A> (length);
  //  return s;
  //}
  template <typename __A>
  void __default::lseq__free(LinearExtern::lseq <__A>  s)
  {
    Tuple0 _636___v0;
    _636___v0 = LinearExtern::lseq_free_raw <__A> (s);
  }
  template <typename __A>
  Tuple0 __default::lseq__free__fun(LinearExtern::lseq <__A>  s)
  {
    return LinearExtern::lseq_free_raw <__A> (s);
  }
  template <typename __A>
  struct Tuple<LinearExtern::lseq <__A> , __A> __default::lseq__swap(LinearExtern::lseq <__A>  s1, uint64 i, __A a1)
  {
    LinearExtern::lseq <__A>  s2 = LinearExtern::get_lseq_default<__A>();
    __A a2 = get_default<__A>::call();
    LinearMaybe::maybe <__A>  _637_x1;
    _637_x1 = LinearMaybe::give <__A> (a1);
    Tuple <LinearExtern::lseq <__A> , LinearMaybe::maybe <__A> >  _let_tmp_rhs0 = LinearExtern::lseq_swap_raw_fun <__A> (s1, i, _637_x1);
    LinearExtern::lseq <__A>  _638_s2tmp = (_let_tmp_rhs0).template get<0>();
    LinearMaybe::maybe <__A>  _639_x2 = (_let_tmp_rhs0).template get<1>();
    s2 = _638_s2tmp;
    a2 = LinearMaybe::unwrap <__A> (_639_x2);
    return Tuple<LinearExtern::lseq <__A> , __A>(s2, a2);
  }
  template <typename __A>
  __A __default::lseq__swap__inout(LinearExtern::lseq <__A> & s, uint64 i, __A a1)
  {
    __A a2 = get_default<__A>::call();
    LinearExtern::lseq <__A>  _out2;
    __A _out3;
    auto _outcollector0 = LinearSequence__i_Compile::__default::lseq__swap <__A> (s, i, a1);
    _out2 = _outcollector0.template get<0>();
    _out3 = _outcollector0.template get<1>();
    s = _out2;
    a2 = _out3;
    return a2;
  }
  template <typename __A>
  struct Tuple<LinearExtern::lseq <__A> , __A> __default::lseq__take(LinearExtern::lseq <__A>  s1, uint64 i)
  {
    LinearExtern::lseq <__A>  s2 = LinearExtern::get_lseq_default<__A>();
    __A a = get_default<__A>::call();
    LinearMaybe::maybe <__A>  _640_x1;
    _640_x1 = LinearMaybe::empty <__A> ();
    Tuple <LinearExtern::lseq <__A> , LinearMaybe::maybe <__A> >  _let_tmp_rhs1 = LinearExtern::lseq_swap_raw_fun <__A> (s1, i, _640_x1);
    LinearExtern::lseq <__A>  _641_s2tmp = (_let_tmp_rhs1).template get<0>();
    LinearMaybe::maybe <__A>  _642_x2 = (_let_tmp_rhs1).template get<1>();
    s2 = _641_s2tmp;
    a = LinearMaybe::unwrap <__A> (_642_x2);
    return Tuple<LinearExtern::lseq <__A> , __A>(s2, a);
  }
  template <typename __A>
  __A __default::lseq__take__inout(LinearExtern::lseq <__A> & s, uint64 i)
  {
    __A a = get_default<__A>::call();
    LinearExtern::lseq <__A>  _out4;
    __A _out5;
    auto _outcollector1 = LinearSequence__i_Compile::__default::lseq__take <__A> (s, i);
    _out4 = _outcollector1.template get<0>();
    _out5 = _outcollector1.template get<1>();
    s = _out4;
    a = _out5;
    return a;
  }
  template <typename __A>
  Tuple <LinearExtern::lseq <__A> , __A>  __default::lseq__take__fun(LinearExtern::lseq <__A>  s1, uint64 i)
  {
    LinearMaybe::maybe <__A>  _643_x1 = LinearMaybe::empty <__A> ();
    Tuple <LinearExtern::lseq <__A> , LinearMaybe::maybe <__A> >  _let_tmp_rhs2 = LinearExtern::lseq_swap_raw_fun <__A> (s1, i, _643_x1);
    LinearExtern::lseq <__A>  _644_s2tmp = (_let_tmp_rhs2).template get<0>();
    LinearMaybe::maybe <__A>  _645_x2 = (_let_tmp_rhs2).template get<1>();
    return Tuple<LinearExtern::lseq <__A> , __A>(_644_s2tmp, LinearMaybe::unwrap <__A> (_645_x2));
  }
  template <typename __A>
  LinearExtern::lseq <__A>  __default::lseq__give(LinearExtern::lseq <__A>  s1, uint64 i, __A a)
  {
    LinearExtern::lseq <__A>  s2 = LinearExtern::get_lseq_default<__A>();
    LinearMaybe::maybe <__A>  _646_x1;
    _646_x1 = LinearMaybe::give <__A> (a);
    Tuple <LinearExtern::lseq <__A> , LinearMaybe::maybe <__A> >  _let_tmp_rhs3 = LinearExtern::lseq_swap_raw_fun <__A> (s1, i, _646_x1);
    LinearExtern::lseq <__A>  _647_s2tmp = (_let_tmp_rhs3).template get<0>();
    LinearMaybe::maybe <__A>  _648_x2 = (_let_tmp_rhs3).template get<1>();
    s2 = _647_s2tmp;
    Tuple0 _649___v1;
    _649___v1 = LinearMaybe::discard <__A> (_648_x2);
    return s2;
  }
  template <typename __A>
  void __default::lseq__give__inout(LinearExtern::lseq <__A> & s1, uint64 i, __A a)
  {
    LinearExtern::lseq <__A>  _out6;
    _out6 = LinearSequence__i_Compile::__default::lseq__give <__A> (s1, i, a);
    s1 = _out6;
  }
  template <typename __A>
  void __default::SeqCopy(LinearExtern::shared_seq<__A>& source, LinearExtern::linear_seq<__A>& dest, uint64 start, uint64 end, uint64 dest__start)
  {
    uint64 _650_i;
    _650_i = (uint64)0;
    uint64 _651_len;
    _651_len = (end) - (start);
    while ((_650_i) < (_651_len)) {
      LinearSequence__i_Compile::__default::mut__seq__set <__A> (dest, (_650_i) + (dest__start), LinearExtern::seq_get <__A> (source, (_650_i) + (start)));
      _650_i = (_650_i) + ((uint64)1);
    }
  }
  template <typename __A>
  LinearExtern::linear_seq<__A> __default::AllocAndCopy(LinearExtern::shared_seq<__A>& source, uint64 from, uint64 to)
  {
    LinearExtern::linear_seq<__A> dest = LinearExtern::linear_seq<__A>();
    if ((to) == (from)) {
      dest = LinearExtern::seq_empty <__A> ();
    } else {
      dest = LinearExtern::seq_alloc <__A> ((to) - (from), LinearExtern::seq_get <__A> (source, from));
    }
    LinearSequence__i_Compile::__default::SeqCopy <__A> (source, dest, from, to, (uint64)0);
    return dest;
  }
  template <typename __A>
  struct Tuple<LinearExtern::lseq <__A> , LinearExtern::lseq <__A> > __default::AllocAndMoveLseq(LinearExtern::lseq <__A>  source, uint64 from, uint64 to)
  {
    LinearExtern::lseq <__A>  looted = LinearExtern::get_lseq_default<__A>();
    LinearExtern::lseq <__A>  loot = LinearExtern::get_lseq_default<__A>();
    looted = source;
    LinearExtern::lseq <__A>  _out7;
    _out7 = LinearSequence__i_Compile::__default::lseq__alloc <__A> ((to) - (from));
    loot = _out7;
    uint64 _652_i;
    _652_i = from;
    while ((_652_i) < (to)) {
      __A _653_elt = get_default<__A>::call();
      LinearExtern::lseq <__A>  _out8;
      __A _out9;
      auto _outcollector2 = LinearSequence__i_Compile::__default::lseq__take <__A> (looted, _652_i);
      _out8 = _outcollector2.template get<0>();
      _out9 = _outcollector2.template get<1>();
      looted = _out8;
      _653_elt = _out9;
      LinearExtern::lseq <__A>  _out10;
      _out10 = LinearSequence__i_Compile::__default::lseq__give <__A> (loot, (_652_i) - (from), _653_elt);
      loot = _out10;
      _652_i = (_652_i) + ((uint64)1);
    }
    return Tuple<LinearExtern::lseq <__A> , LinearExtern::lseq <__A> >(looted, loot);
  }
  template <typename __A>
  LinearExtern::linear_seq<__A> __default::SeqResize(LinearExtern::linear_seq<__A> s, uint64 newlen, __A a)
  {
    LinearExtern::linear_seq<__A> s2 = LinearExtern::linear_seq<__A>();
    LinearExtern::shared_seq_length_bound <__A> (s);
    uint64 _654_i;
    _654_i = LinearExtern::seq_length <__A> (s);
    LinearExtern::linear_seq<__A> _out11;
    _out11 = LinearExtern::TrustedRuntimeSeqResize <__A> (s, newlen);
    s2 = _out11;
    while ((_654_i) < (newlen)) {
      s2 = LinearExtern::seq_set <__A> (s2, _654_i, a);
      _654_i = (_654_i) + ((uint64)1);
    }
    return s2;
  }
  template <typename __A>
  void __default::SeqResizeMut(LinearExtern::linear_seq<__A>& s, uint64 newlen, __A a)
  {
    LinearExtern::shared_seq_length_bound <__A> (s);
    uint64 _655_i;
    _655_i = LinearExtern::seq_length <__A> (s);
    LinearExtern::linear_seq<__A> _out12;
    _out12 = LinearExtern::TrustedRuntimeSeqResize <__A> (s, newlen);
    s = _out12;
    while ((_655_i) < (newlen)) {
      LinearSequence__i_Compile::__default::mut__seq__set <__A> (s, _655_i, a);
      _655_i = (_655_i) + ((uint64)1);
    }
  }
  template <typename __A>
  LinearExtern::linear_seq<__A> __default::InsertSeq(LinearExtern::linear_seq<__A> s, __A a, uint64 pos)
  {
    LinearExtern::linear_seq<__A> s2 = LinearExtern::linear_seq<__A>();
    uint64 _656_len;
    _656_len = LinearExtern::seq_length <__A> (s);
    uint64 _657_newlen;
    _657_newlen = (uint64(_656_len)) + ((uint64)1);
    LinearExtern::linear_seq<__A> _out13;
    _out13 = LinearExtern::TrustedRuntimeSeqResize <__A> (s, _657_newlen);
    s2 = _out13;
    uint64 _658_i;
    _658_i = (_657_newlen) - ((uint64)1);
    while ((_658_i) > (pos)) {
      __A _659_prevElt;
      _659_prevElt = LinearExtern::seq_get <__A> (s2, (_658_i) - ((uint64)1));
      s2 = LinearExtern::seq_set <__A> (s2, _658_i, _659_prevElt);
      _658_i = (_658_i) - ((uint64)1);
    }
    s2 = LinearExtern::seq_set <__A> (s2, pos, a);
    return s2;
  }
  template <typename __A>
  LinearExtern::lseq <__A>  __default::InsertLSeq(LinearExtern::lseq <__A>  s, __A a, uint64 pos)
  {
    LinearExtern::lseq <__A>  s2 = LinearExtern::get_lseq_default<__A>();
    uint64 _660_len;
    _660_len = LinearExtern::lseq_length_raw <__A> (s);
    uint64 _661_newlen;
    _661_newlen = (_660_len) + ((uint64)1);
    LinearExtern::lseq <__A>  _out14;
    _out14 = LinearExtern::TrustedRuntimeLSeqResize <__A> (s, _661_newlen);
    s2 = _out14;
    uint64 _662_i;
    _662_i = (_661_newlen) - ((uint64)1);
    while ((_662_i) > (pos)) {
      __A _663_prevElt = get_default<__A>::call();
      LinearExtern::lseq <__A>  _out15;
      __A _out16;
      auto _outcollector3 = LinearSequence__i_Compile::__default::lseq__take <__A> (s2, (_662_i) - ((uint64)1));
      _out15 = _outcollector3.template get<0>();
      _out16 = _outcollector3.template get<1>();
      s2 = _out15;
      _663_prevElt = _out16;
      LinearExtern::lseq <__A>  _out17;
      _out17 = LinearSequence__i_Compile::__default::lseq__give <__A> (s2, _662_i, _663_prevElt);
      s2 = _out17;
      _662_i = (_662_i) - ((uint64)1);
    }
    LinearExtern::lseq <__A>  _out18;
    _out18 = LinearSequence__i_Compile::__default::lseq__give <__A> (s2, pos, a);
    s2 = _out18;
    return s2;
  }
  template <typename __A>
  struct Tuple<LinearExtern::lseq <__A> , __A> __default::Replace1With2Lseq(LinearExtern::lseq <__A>  s, __A l, __A r, uint64 pos)
  {
    LinearExtern::lseq <__A>  s2 = LinearExtern::get_lseq_default<__A>();
    __A replaced = get_default<__A>::call();
    LinearExtern::lseq <__A>  _out19;
    __A _out20;
    auto _outcollector4 = LinearSequence__i_Compile::__default::lseq__swap <__A> (s, pos, l);
    _out19 = _outcollector4.template get<0>();
    _out20 = _outcollector4.template get<1>();
    s2 = _out19;
    replaced = _out20;
    LinearExtern::lseq <__A>  _out21;
    _out21 = LinearSequence__i_Compile::__default::InsertLSeq <__A> (s2, r, (pos) + ((uint64)1));
    s2 = _out21;
    return Tuple<LinearExtern::lseq <__A> , __A>(s2, replaced);
  }
  template <typename __A>
  __A __default::Replace1With2Lseq__inout(LinearExtern::lseq <__A> & s, __A l, __A r, uint64 pos)
  {
    __A replaced = get_default<__A>::call();
    __A _out22;
    _out22 = LinearSequence__i_Compile::__default::lseq__swap__inout <__A> (s, pos, l);
    replaced = _out22;
    LinearExtern::lseq <__A>  _out23;
    _out23 = LinearSequence__i_Compile::__default::InsertLSeq <__A> (s, r, (pos) + ((uint64)1));
    s = _out23;
    return replaced;
  }
  template <typename __A>
  void __default::mut__seq__set(LinearExtern::linear_seq<__A>& s, uint64 i, __A a)
  {
    s = LinearExtern::seq_set <__A> (s, i, a);
  }
}// end of namespace LinearSequence__i_Compile 
namespace BankImplementation_Compile  {

  typedef int64 nat64;






  
AccountEntry::AccountEntry() {
    balance = 0;
  }
  
bool operator==(const AccountEntry &left, const AccountEntry &right)  {
    	return true 		&& left.balance == right.balance
    ;
  }

  
AccountSeq::AccountSeq() {
    accounts = LinearExtern::get_lseq_default<Mutexes::Mutex <BankImplementation_Compile::AccountEntry> >();
  }
  
bool operator==(const AccountSeq &left, const AccountSeq &right)  {
    	return true 		&& left.accounts == right.accounts
    ;
  }

  bool __default::TryAccountTransfer(BankImplementation_Compile::AccountSeq& accountSeq, uint64 sourceAccountId, uint64 destAccountId, BigNumber amount)
  {
    bool success = false;
    LinearExtern::lseq <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > * _664_accounts;
    _664_accounts = &( ((accountSeq).accounts));
    BankImplementation_Compile::AccountEntry _665_sourceAccountEntry = BankImplementation_Compile::AccountEntry();
    BankImplementation_Compile::AccountEntry _666_destAccountEntry = BankImplementation_Compile::AccountEntry();
    BankImplementation_Compile::AccountEntry _out24;
    _out24 = (*(LinearSequence__i_Compile::__default::lseq__peek <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > ((*_664_accounts), sourceAccountId)))->acquire();
    _665_sourceAccountEntry = _out24;
    BankImplementation_Compile::AccountEntry _out25;
    _out25 = (*(LinearSequence__i_Compile::__default::lseq__peek <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > ((*_664_accounts), destAccountId)))->acquire();
    _666_destAccountEntry = _out25;
    BankImplementation_Compile::AccountEntry _let_tmp_rhs4 = _665_sourceAccountEntry;
    BigNumber _667_sourceBalance = ((_let_tmp_rhs4).balance);
    BankImplementation_Compile::AccountEntry _let_tmp_rhs5 = _666_destAccountEntry;
    BigNumber _668_destBalance = ((_let_tmp_rhs5).balance);
    BigNumber _669_newSourceBalance = 0;
    BigNumber _670_newDestBalance = 0;
    if (true || (amount) <= (_667_sourceBalance)) {
      int64 _671_a = 0;
      int64 _672_b = 0;
      int64 _673_c = 0;
      int64 _674_d = 0;
      int64 _675_e = 0;
      _671_a = (_667_sourceBalance);
      _672_b = (_668_destBalance);
      _673_c = (amount);
      _674_d = (_671_a) - (_673_c);
      _675_e = (_672_b) + (_673_c);
      _669_newSourceBalance = (_674_d);
      _670_newDestBalance = (_675_e);
      success = true;
    } else {
      _669_newSourceBalance = _667_sourceBalance;
      _670_newDestBalance = _668_destBalance;
      success = false;
    }
    //std::cout<<"a:"<<sourceAccountId<<":"<<_669_newSourceBalance<<",b:"<<destAccountId<<":"<<_670_newDestBalance<<std::endl;
    (*(LinearSequence__i_Compile::__default::lseq__peek <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > ((*_664_accounts), sourceAccountId)))->release(BankImplementation_Compile::AccountEntry(_669_newSourceBalance));
    (*(LinearSequence__i_Compile::__default::lseq__peek <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > ((*_664_accounts), destAccountId)))->release(BankImplementation_Compile::AccountEntry(_670_newDestBalance));
    return success;
  }
  BigNumber __default::AssertAccountIsNotTooRich(BankImplementation_Compile::AccountSeq& accountSeq, uint64 accountId)
  {
    BigNumber bal = 0;
    LinearExtern::lseq <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > * _676_accounts;
    _676_accounts = &( ((accountSeq).accounts));
    BankImplementation_Compile::AccountEntry _677_accountEntry = BankImplementation_Compile::AccountEntry();
    BankImplementation_Compile::AccountEntry _out26;
    _out26 = (*(LinearSequence__i_Compile::__default::lseq__peek <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > ((*_676_accounts), accountId)))->acquire();
    _677_accountEntry = _out26;
    BankImplementation_Compile::AccountEntry _let_tmp_rhs6 = _677_accountEntry;
    BigNumber _678_balance = ((_let_tmp_rhs6).balance);
    (*(LinearSequence__i_Compile::__default::lseq__peek <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > ((*_676_accounts), accountId)))->release(BankImplementation_Compile::AccountEntry(_678_balance));
    bal = _678_balance;
    return bal;
  }

}// end of namespace BankImplementation_Compile 
namespace Cells  {


  template <typename V>
CellContents<V>::CellContents() {
    v = get_default<V>::call();
  }
  template <typename V>
bool operator==(const CellContents<V> &left, const CellContents<V> &right)  {
    	return true 		&& left.v == right.v
    ;
  }

}// end of namespace Cells 
namespace TicketStubSingletonLoc_Compile  {


}// end of namespace TicketStubSingletonLoc_Compile 
namespace MapRemove_s_Compile  {

}// end of namespace MapRemove_s_Compile 
namespace Maps_Compile  {



}// end of namespace Maps_Compile 
namespace _module  {













































}// end of namespace _module 
template <typename V>
struct get_default<Options_Compile::Option<V> > {
  static Options_Compile::Option<V> call() {
    return Options_Compile::Option<V>();
  }
};
template <>
struct get_default<Bank_Compile::M > {
  static Bank_Compile::M call() {
    return Bank_Compile::M();
  }
};
template <>
struct get_default<Bank_Compile::AccountTransfer > {
  static Bank_Compile::AccountTransfer call() {
    return Bank_Compile::AccountTransfer();
  }
};
template <>
struct get_default<GhostLoc_Compile::Loc > {
  static GhostLoc_Compile::Loc call() {
    return GhostLoc_Compile::Loc();
  }
};
template <>
struct get_default<Rw_PCMWrap_ON_Bank__Compile::M > {
  static Rw_PCMWrap_ON_Bank__Compile::M call() {
    return Rw_PCMWrap_ON_Bank__Compile::M();
  }
};
template <>
struct get_default<Tokens_ON_Rw__PCMWrap__ON__Bank____Compile::Token > {
  static Tokens_ON_Rw__PCMWrap__ON__Bank____Compile::Token call() {
    return Tokens_ON_Rw__PCMWrap__ON__Bank____Compile::Token();
  }
};
template <>
struct get_default<Tokens_ON_Rw__PCMExt__ON__Bank____Compile::Token > {
  static Tokens_ON_Rw__PCMExt__ON__Bank____Compile::Token call() {
    return Tokens_ON_Rw__PCMExt__ON__Bank____Compile::Token();
  }
};
template <typename V>
struct get_default<GlinearOption_Compile::glOption<V> > {
  static GlinearOption_Compile::glOption<V> call() {
    return GlinearOption_Compile::glOption<V>();
  }
};
template <typename V>
struct get_default<Ptrs::PointsTo<V> > {
  static Ptrs::PointsTo<V> call() {
    return Ptrs::PointsTo<V>();
  }
};
template <typename V>
struct get_default<Ptrs::PointsToLinear<V> > {
  static Ptrs::PointsToLinear<V> call() {
    return Ptrs::PointsToLinear<V>();
  }
};
template <typename V>
struct get_default<Ptrs::PointsToArray<V> > {
  static Ptrs::PointsToArray<V> call() {
    return Ptrs::PointsToArray<V>();
  }
};
template <>
struct get_default<BankTokens_Compile::Account > {
  static BankTokens_Compile::Account call() {
    return BankTokens_Compile::Account();
  }
};
template <typename V>
struct get_default<LinearCells::LCellContents<V> > {
  static LinearCells::LCellContents<V> call() {
    return LinearCells::LCellContents<V>();
  }
};
template <typename V>
struct get_default<Mutexes::Mutex<V> > {
  static Mutexes::Mutex<V> call() {
    return Mutexes::Mutex<V>();
  }
};
template <typename V>
struct get_default<Mutexes::MutexHandle<V> > {
  static Mutexes::MutexHandle<V> call() {
    return Mutexes::MutexHandle<V>();
  }
};
template <>
struct get_default<BankImplementation_Compile::AccountEntry > {
  static BankImplementation_Compile::AccountEntry call() {
    return BankImplementation_Compile::AccountEntry();
  }
};
template <>
struct get_default<BankImplementation_Compile::AccountSeq > {
  static BankImplementation_Compile::AccountSeq call() {
    return BankImplementation_Compile::AccountSeq();
  }
};
template <typename V>
struct get_default<Cells::CellContents<V> > {
  static Cells::CellContents<V> call() {
    return Cells::CellContents<V>();
  }
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_sbyte > > {
static std::shared_ptr<NativeTypes_Compile::class_sbyte > call() {
return std::shared_ptr<NativeTypes_Compile::class_sbyte >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_byte > > {
static std::shared_ptr<NativeTypes_Compile::class_byte > call() {
return std::shared_ptr<NativeTypes_Compile::class_byte >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_int16 > > {
static std::shared_ptr<NativeTypes_Compile::class_int16 > call() {
return std::shared_ptr<NativeTypes_Compile::class_int16 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_uint16 > > {
static std::shared_ptr<NativeTypes_Compile::class_uint16 > call() {
return std::shared_ptr<NativeTypes_Compile::class_uint16 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_int32 > > {
static std::shared_ptr<NativeTypes_Compile::class_int32 > call() {
return std::shared_ptr<NativeTypes_Compile::class_int32 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_uint32 > > {
static std::shared_ptr<NativeTypes_Compile::class_uint32 > call() {
return std::shared_ptr<NativeTypes_Compile::class_uint32 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_int64 > > {
static std::shared_ptr<NativeTypes_Compile::class_int64 > call() {
return std::shared_ptr<NativeTypes_Compile::class_int64 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_uint64 > > {
static std::shared_ptr<NativeTypes_Compile::class_uint64 > call() {
return std::shared_ptr<NativeTypes_Compile::class_uint64 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_nat8 > > {
static std::shared_ptr<NativeTypes_Compile::class_nat8 > call() {
return std::shared_ptr<NativeTypes_Compile::class_nat8 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_nat16 > > {
static std::shared_ptr<NativeTypes_Compile::class_nat16 > call() {
return std::shared_ptr<NativeTypes_Compile::class_nat16 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_nat32 > > {
static std::shared_ptr<NativeTypes_Compile::class_nat32 > call() {
return std::shared_ptr<NativeTypes_Compile::class_nat32 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_nat64 > > {
static std::shared_ptr<NativeTypes_Compile::class_nat64 > call() {
return std::shared_ptr<NativeTypes_Compile::class_nat64 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::class_uint128 > > {
static std::shared_ptr<NativeTypes_Compile::class_uint128 > call() {
return std::shared_ptr<NativeTypes_Compile::class_uint128 >();}
};
template <>
struct get_default<std::shared_ptr<NativeTypes_Compile::__default > > {
static std::shared_ptr<NativeTypes_Compile::__default > call() {
return std::shared_ptr<NativeTypes_Compile::__default >();}
};
template <>
struct get_default<std::shared_ptr<Bank_Compile::class_nat64 > > {
static std::shared_ptr<Bank_Compile::class_nat64 > call() {
return std::shared_ptr<Bank_Compile::class_nat64 >();}
};
template <>
struct get_default<std::shared_ptr<Bank_Compile::__default > > {
static std::shared_ptr<Bank_Compile::__default > call() {
return std::shared_ptr<Bank_Compile::__default >();}
};
template <>
struct get_default<std::shared_ptr<PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile::class_GToken > > {
static std::shared_ptr<PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile::class_GToken > call() {
return std::shared_ptr<PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile::class_GToken >();}
};
template <>
struct get_default<std::shared_ptr<RwTokens_ON_Bank__Compile::class_Token > > {
static std::shared_ptr<RwTokens_ON_Bank__Compile::class_Token > call() {
return std::shared_ptr<RwTokens_ON_Bank__Compile::class_Token >();}
};
template <>
struct get_default<std::shared_ptr<RwTokens_ON_Bank__Compile::__default > > {
static std::shared_ptr<RwTokens_ON_Bank__Compile::__default > call() {
return std::shared_ptr<RwTokens_ON_Bank__Compile::__default >();}
};
template <>
struct get_default<std::shared_ptr<GlinearOption_Compile::__default > > {
static std::shared_ptr<GlinearOption_Compile::__default > call() {
return std::shared_ptr<GlinearOption_Compile::__default >();}
};
template <>
struct get_default<std::shared_ptr<BankTokens_Compile::__default > > {
static std::shared_ptr<BankTokens_Compile::__default > call() {
return std::shared_ptr<BankTokens_Compile::__default >();}
};
template <>
struct get_default<std::shared_ptr<BitOps_Compile::__default > > {
static std::shared_ptr<BitOps_Compile::__default > call() {
return std::shared_ptr<BitOps_Compile::__default >();}
};
template <>
struct get_default<std::shared_ptr<LinearSequence__i_Compile::__default > > {
static std::shared_ptr<LinearSequence__i_Compile::__default > call() {
return std::shared_ptr<LinearSequence__i_Compile::__default >();}
};
template <>
struct get_default<std::shared_ptr<BankImplementation_Compile::class_nat64 > > {
static std::shared_ptr<BankImplementation_Compile::class_nat64 > call() {
return std::shared_ptr<BankImplementation_Compile::class_nat64 >();}
};
template <>
struct get_default<std::shared_ptr<BankImplementation_Compile::__default > > {
static std::shared_ptr<BankImplementation_Compile::__default > call() {
return std::shared_ptr<BankImplementation_Compile::__default >();}
};


// checking TryTranfer function
BankImplementation_Compile::AccountSeq generateRandomAccounts(int numAccounts, int balancePerAccount) {
    LinearExtern::lseq <Mutexes::Mutex <BankImplementation_Compile::AccountEntry>> accounts = LinearExtern::get_lseq_default<Mutexes::Mutex <BankImplementation_Compile::AccountEntry>>();
    accounts = LinearExtern::lseq_alloc_raw <Mutexes::Mutex <BankImplementation_Compile::AccountEntry>> (numAccounts);
    BankImplementation_Compile::AccountSeq accountSeq(accounts);

    for (int i = 0; i < numAccounts; ++i) {
      uint64 accountId = i;
      LinearExtern::lseq <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > * _664_accounts;
      _664_accounts = &( ((accountSeq).accounts));
      (*(LinearSequence__i_Compile::__default::lseq__peek <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > ((*_664_accounts), accountId)))->release(BankImplementation_Compile::AccountEntry(balancePerAccount));
    }

    return accountSeq;
}

void updateBalance(BankImplementation_Compile::AccountSeq& accountSeq, int accountId, int balance) {
   LinearExtern::lseq <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > * _664_accounts;
   _664_accounts = &( ((accountSeq).accounts));
   (*(LinearSequence__i_Compile::__default::lseq__peek <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > ((*_664_accounts), accountId)))->release(BankImplementation_Compile::AccountEntry(balance));
}

int getBalance(BankImplementation_Compile::AccountSeq& accountSeq, int accountId) {
  auto accounts = (accountSeq).accounts;
  LinearMaybe::maybe<Mutexes::Mutex<BankImplementation_Compile::AccountEntry>> d0 = accounts.ptr[accountId];
  Mutexes::Mutex<BankImplementation_Compile::AccountEntry> d1 = d0.a;
  LinearCells::LinearCell<BankImplementation_Compile::AccountEntry> d2 = d1.cell;
  BankImplementation_Compile::AccountEntry d3 = d2.v;
  //std::cout << "[Info] account:" << accountId <<", current balance:" << d3.balance << std::endl;
  return d3.balance;
}


// global account information
BankImplementation_Compile::AccountSeq accountSeq = generateRandomAccounts(keyspace, initBalance);

void checkSum() {
  long tol = 0;
  int MOD=100*100*10000;
  for (int i=0; i<keyspace; i++) {
     int b = getBalance(accountSeq, i);
     tol+=b;
     //tol = tol%MOD;
     //std::cout<<"acount_id:"<<i<<",balance:"<<b<<std::endl;
  }
  std::cout << "tol: " << tol << ", initBalance: " << (initBalance) << ", keyspace: " << keyspace << std::endl;
}

void worker(int thread_id) {
  long suc=0, aborts=0;
  std::mt19937 eng(thread_id);
  std::uniform_int_distribution<int> distr(1, keyspace-2);
  //std::cout<<"thread-id:"<<thread_id<< ",p:"<<p<<",q:"<<q<<std::endl;
  auto start = high_resolution_clock::now();
  int runtime = 3;
  seconds run_duration(runtime);
  while (true) {
    // possible to have a dead lock;
    int p = distr(eng);
    int q = distr(eng);
    if (p==q) {
      q+=1;
    }

    if (p>q) {
       int tmp = p;
       p = q;
       q = tmp;
    }
    
    //usleep(100*1000);
    auto now = high_resolution_clock::now();
    if (duration_cast<seconds>(now - start) >= run_duration) { break; }
    if (BankImplementation_Compile::__default::TryAccountTransfer(accountSeq, p, q, 1)) {
       suc += 1;
    } else {
       aborts += 1;
    }
  }
  printf("thread-id:%d, runtime:%d, suc/time:%.lf, aborts/time:%.lf\n",thread_id,runtime,suc/(runtime+0.0),aborts/(runtime+0.0)); 
}


int main() {
  //uint64 a = 1, b = 2; 
  //BigNumber amount = 1;
  //std::cout<<"success:"<<BankImplementation_Compile::__default::TryAccountTransfer(accountSeq, a, b, amount)<<std::endl;
  //getBalance(accountSeq, a);
  //getBalance(accountSeq, b);
  //std::cout<<"success:"<<BankImplementation_Compile::__default::TryAccountTransfer(accountSeq, a, b, 800000000)<<std::endl;
  //getBalance(accountSeq, a);
  //getBalance(accountSeq, b);
  //updateBalance(accountSeq, a, 3333);
  //getBalance(accountSeq, a);

  std::vector<std::thread> threads(num_threads); 
  for (int i = 0; i < num_threads; ++i) {
      threads[i] = std::thread(worker, i);
  }

  for (int i = 0; i < num_threads; ++i) {
     threads[i].join();
  }
  checkSum();
  
  return 0;
}
