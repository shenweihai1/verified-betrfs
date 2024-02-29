// Dafny program Impl.i.dfy compiled into a Cpp header file
#pragma once
#include "DafnyRuntime.h"
namespace _System  {
}// end of namespace _System  declarations
namespace NativeTypes_Compile  {
  class class_sbyte;
  class class_byte;
  class class_int16;
  class class_uint16;
  class class_int32;
  class class_uint32;
  class class_int64;
  class class_uint64;
  class class_nat8;
  class class_nat16;
  class class_nat32;
  class class_nat64;
  class class_uint128;
  class __default;
}// end of namespace NativeTypes_Compile  declarations
namespace Options_Compile  {
  template <typename V>
struct Option;
}// end of namespace Options_Compile  declarations
namespace MathUtils_Compile  {
}// end of namespace MathUtils_Compile  declarations
namespace Bank_Compile  {
  class class_nat64;
  
struct M;
  
struct AccountTransfer;
  class __default;
}// end of namespace Bank_Compile  declarations
namespace GlinearMap_Compile  {
}// end of namespace GlinearMap_Compile  declarations
namespace GhostLoc_Compile  {
  
struct Loc;
}// end of namespace GhostLoc_Compile  declarations
namespace RequestIds_Compile  {
}// end of namespace RequestIds_Compile  declarations
namespace Rw_PCMWrap_ON_Bank__Compile  {
  
struct M;
}// end of namespace Rw_PCMWrap_ON_Bank__Compile  declarations
namespace Tokens_ON_Rw__PCMWrap__ON__Bank____Compile  {
  
struct Token;
}// end of namespace Tokens_ON_Rw__PCMWrap__ON__Bank____Compile  declarations
namespace PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile  {
   using GToken = Tokens_ON_Rw__PCMWrap__ON__Bank____Compile::Token;
  class class_GToken;
}// end of namespace PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile  declarations
namespace Rw_PCMExt_ON_Bank__Compile  {
}// end of namespace Rw_PCMExt_ON_Bank__Compile  declarations
namespace Tokens_ON_Rw__PCMExt__ON__Bank____Compile  {
  
struct Token;
}// end of namespace Tokens_ON_Rw__PCMExt__ON__Bank____Compile  declarations
namespace ExtTokens_ON_Rw__PCMWrap__ON__Bank___Rw__PCMExt__ON__Bank____Compile  {
}// end of namespace ExtTokens_ON_Rw__PCMWrap__ON__Bank___Rw__PCMExt__ON__Bank____Compile  declarations
namespace RwTokens_ON_Bank__Compile  {
   using Token = Tokens_ON_Rw__PCMExt__ON__Bank____Compile::Token;
  class class_Token;
  class __default;
}// end of namespace RwTokens_ON_Bank__Compile  declarations
namespace GlinearOption_Compile  {
  template <typename V>
struct glOption;
  class __default;
}// end of namespace GlinearOption_Compile  declarations
namespace Ptrs  {
  template <typename V>
struct PointsTo;
  template <typename V>
struct PointsToLinear;
  template <typename V>
struct PointsToArray;
  // Extern declaration of Ptr
 struct Ptr;
}// end of namespace Ptrs  declarations
namespace BankTokens_Compile  {
  
struct Account;
  class __default;
}// end of namespace BankTokens_Compile  declarations
namespace LinearCells  {
  // Extern declaration of LinearCell
template <typename V> struct LinearCell;
  template <typename V>
struct LCellContents;
}// end of namespace LinearCells  declarations
namespace BitOps_Compile  {
  class __default;
}// end of namespace BitOps_Compile  declarations
namespace Atomics  {
}// end of namespace Atomics  declarations
namespace Mutexes  {
  template <typename V>
struct Mutex;
  template <typename V>
struct MutexHandle;
}// end of namespace Mutexes  declarations
namespace LinearMaybe  {
}// end of namespace LinearMaybe  declarations
namespace LinearExtern  {
}// end of namespace LinearExtern  declarations
namespace LinearSequence__i_Compile  {
  class __default;
}// end of namespace LinearSequence__i_Compile  declarations
namespace BankImplementation_Compile  {
  class class_nat64;
  
struct AccountEntry;
  
struct AccountSeq;
  class __default;
}// end of namespace BankImplementation_Compile  declarations
namespace Cells  {
  // Extern declaration of Cell
template <typename V> struct Cell;
  template <typename V>
struct CellContents;
}// end of namespace Cells  declarations
namespace TicketStubSingletonLoc_Compile  {
}// end of namespace TicketStubSingletonLoc_Compile  declarations
namespace MapRemove_s_Compile  {
}// end of namespace MapRemove_s_Compile  declarations
namespace Maps_Compile  {
}// end of namespace Maps_Compile  declarations
namespace _module  {
}// end of namespace _module  declarations
namespace _System  {
}// end of namespace _System  datatype declarations
namespace NativeTypes_Compile  {
}// end of namespace NativeTypes_Compile  datatype declarations
namespace Options_Compile  {
  template <typename V>
bool operator==(const Option<V> &left, const Option<V> &right); 
  template <typename V>
struct Option_None;
  template <typename V>
bool operator==(const Option_None<V> &left, const Option_None<V> &right); 
  template <typename V>
struct Option_None {
    friend bool operator==<V>(const Option_None &left, const Option_None &right); 
    friend bool operator!=(const Option_None &left, const Option_None &right) { return !(left == right); } 
  };
  template <typename V>
struct Option_Some;
  template <typename V>
bool operator==(const Option_Some<V> &left, const Option_Some<V> &right); 
  template <typename V>
struct Option_Some {
    V value;
    friend bool operator==<V>(const Option_Some &left, const Option_Some &right); 
    friend bool operator!=(const Option_Some &left, const Option_Some &right) { return !(left == right); } 
  };
  template <typename V>
struct Option {
    std::variant<Option_None<V>, Option_Some<V>> v;
    static Option create_None() {
      Option<V> COMPILER_result;
      Option_None<V> COMPILER_result_subStruct;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    static Option create_Some(V value) {
      Option<V> COMPILER_result;
      Option_Some<V> COMPILER_result_subStruct;
      COMPILER_result_subStruct.value = value;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    Option();
    ~Option() {}
    Option(const Option &other) {
      v = other.v;
    }
    Option& operator=(const Option other) {
      v = other.v;
      return *this;
    }
    bool is_Option_None() const { return std::holds_alternative<Option_None<V>>(v); }
    bool is_Option_Some() const { return std::holds_alternative<Option_Some<V>>(v); }
    Option* operator->() { return this; }
    friend bool operator==(const Option &left, const Option &right) { 
    	return left.v == right.v;
}
    V& dtor_value() {
      return std::get<Option_Some<V>>(v).value; 
    }
    friend bool operator!=(const Option &left, const Option &right) { return !(left == right); } 
  };
  template <typename V>
inline bool is_Option_None(const struct Option<V> d);
  template <typename V>
inline bool is_Option_Some(const struct Option<V> d);
}// end of namespace Options_Compile  datatype declarations
namespace MathUtils_Compile  {
}// end of namespace MathUtils_Compile  datatype declarations
namespace Bank_Compile  {
  
bool operator==(const M &left, const M &right); 
  
struct M_M;
  
bool operator==(const M_M &left, const M_M &right); 
  
struct M_M {
    DafnyMap<BigNumber,BigNumber> account__balances;
    friend bool operator==(const M_M &left, const M_M &right); 
    friend bool operator!=(const M_M &left, const M_M &right) { return !(left == right); } 
  };
  
struct M_Invalid;
  
bool operator==(const M_Invalid &left, const M_Invalid &right); 
  
struct M_Invalid {
    friend bool operator==(const M_Invalid &left, const M_Invalid &right); 
    friend bool operator!=(const M_Invalid &left, const M_Invalid &right) { return !(left == right); } 
  };
  
struct M {
    std::variant<M_M, M_Invalid> v;
    static M create_M(DafnyMap<BigNumber,BigNumber> account__balances) {
      M COMPILER_result;
      M_M COMPILER_result_subStruct;
      COMPILER_result_subStruct.account__balances = account__balances;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    static M create_Invalid() {
      M COMPILER_result;
      M_Invalid COMPILER_result_subStruct;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    M();
    ~M() {}
    M(const M &other) {
      v = other.v;
    }
    M& operator=(const M other) {
      v = other.v;
      return *this;
    }
    bool is_M_M() const { return std::holds_alternative<M_M>(v); }
    bool is_M_Invalid() const { return std::holds_alternative<M_Invalid>(v); }
    M* operator->() { return this; }
    friend bool operator==(const M &left, const M &right) { 
    	return left.v == right.v;
}
    DafnyMap<BigNumber,BigNumber>& dtor_account__balances() {
      return std::get<M_M>(v).account__balances; 
    }
    friend bool operator!=(const M &left, const M &right) { return !(left == right); } 
  };
  
inline bool is_M_M(const struct M d);
  
inline bool is_M_Invalid(const struct M d);
  
bool operator==(const AccountTransfer &left, const AccountTransfer &right); 
  
struct AccountTransfer {
    BigNumber source__account;
    BigNumber dest__account;
    BigNumber money;
    AccountTransfer(BigNumber source__account, BigNumber dest__account, BigNumber money) : source__account (source__account),  dest__account (dest__account),  money (money) {}
    AccountTransfer();
    AccountTransfer* operator->() { return this; }
    friend bool operator==(const AccountTransfer &left, const AccountTransfer &right);
    friend bool operator!=(const AccountTransfer &left, const AccountTransfer &right) { return !(left == right); } 
  };
  
inline bool is_AccountTransfer(const struct AccountTransfer d) { (void) d; return true; }
}// end of namespace Bank_Compile  datatype declarations
namespace GlinearMap_Compile  {
}// end of namespace GlinearMap_Compile  datatype declarations
namespace GhostLoc_Compile  {
  
struct Loc;
  
bool operator==(const Loc &left, const Loc &right); 
  
struct Loc_BaseLoc;
  
bool operator==(const Loc_BaseLoc &left, const Loc_BaseLoc &right); 
  
struct Loc_BaseLoc {
    friend bool operator==(const Loc_BaseLoc &left, const Loc_BaseLoc &right); 
    friend bool operator!=(const Loc_BaseLoc &left, const Loc_BaseLoc &right) { return !(left == right); } 
  };
  
struct Loc_ExtLoc;
  
bool operator==(const Loc_ExtLoc &left, const Loc_ExtLoc &right); 
  
struct Loc_ExtLoc {
    friend bool operator==(const Loc_ExtLoc &left, const Loc_ExtLoc &right); 
    friend bool operator!=(const Loc_ExtLoc &left, const Loc_ExtLoc &right) { return !(left == right); } 
  };
  
struct Loc {
    std::variant<Loc_BaseLoc, Loc_ExtLoc> v;
    static Loc create_BaseLoc() {
      Loc COMPILER_result;
      Loc_BaseLoc COMPILER_result_subStruct;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    static Loc create_ExtLoc() {
      Loc COMPILER_result;
      Loc_ExtLoc COMPILER_result_subStruct;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    Loc();
    ~Loc() {}
    Loc(const Loc &other) {
      v = other.v;
    }
    Loc& operator=(const Loc other) {
      v = other.v;
      return *this;
    }
    bool is_Loc_BaseLoc() const { return std::holds_alternative<Loc_BaseLoc>(v); }
    bool is_Loc_ExtLoc() const { return std::holds_alternative<Loc_ExtLoc>(v); }
    Loc* operator->() { return this; }
    friend bool operator==(const Loc &left, const Loc &right) { 
    	return left.v == right.v;
}
    friend bool operator!=(const Loc &left, const Loc &right) { return !(left == right); } 
  };
  
inline bool is_Loc_BaseLoc(const struct Loc d);
  
inline bool is_Loc_ExtLoc(const struct Loc d);
}// end of namespace GhostLoc_Compile  datatype declarations
namespace RequestIds_Compile  {
}// end of namespace RequestIds_Compile  datatype declarations
namespace Rw_PCMWrap_ON_Bank__Compile  {
  
bool operator==(const M &left, const M &right); 
  
struct M {
    M();
    M* operator->() { return this; }
    friend bool operator==(const M &left, const M &right);
    friend bool operator!=(const M &left, const M &right) { return !(left == right); } 
  };
  
inline bool is_M(const struct M d) { (void) d; return true; }
}// end of namespace Rw_PCMWrap_ON_Bank__Compile  datatype declarations
namespace Tokens_ON_Rw__PCMWrap__ON__Bank____Compile  {
  
bool operator==(const Token &left, const Token &right); 
  
struct Token {
    Token();
    Token* operator->() { return this; }
    friend bool operator==(const Token &left, const Token &right);
    friend bool operator!=(const Token &left, const Token &right) { return !(left == right); } 
  };
  
inline bool is_Token(const struct Token d) { (void) d; return true; }
}// end of namespace Tokens_ON_Rw__PCMWrap__ON__Bank____Compile  datatype declarations
namespace PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile  {
}// end of namespace PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile  datatype declarations
namespace Rw_PCMExt_ON_Bank__Compile  {
}// end of namespace Rw_PCMExt_ON_Bank__Compile  datatype declarations
namespace Tokens_ON_Rw__PCMExt__ON__Bank____Compile  {
  
bool operator==(const Token &left, const Token &right); 
  
struct Token {
    Token();
    Token* operator->() { return this; }
    friend bool operator==(const Token &left, const Token &right);
    friend bool operator!=(const Token &left, const Token &right) { return !(left == right); } 
  };
  
inline bool is_Token(const struct Token d) { (void) d; return true; }
}// end of namespace Tokens_ON_Rw__PCMExt__ON__Bank____Compile  datatype declarations
namespace ExtTokens_ON_Rw__PCMWrap__ON__Bank___Rw__PCMExt__ON__Bank____Compile  {
}// end of namespace ExtTokens_ON_Rw__PCMWrap__ON__Bank___Rw__PCMExt__ON__Bank____Compile  datatype declarations
namespace RwTokens_ON_Bank__Compile  {
}// end of namespace RwTokens_ON_Bank__Compile  datatype declarations
namespace GlinearOption_Compile  {
  template <typename V>
bool operator==(const glOption<V> &left, const glOption<V> &right); 
  template <typename V>
struct glOption_glNone;
  template <typename V>
bool operator==(const glOption_glNone<V> &left, const glOption_glNone<V> &right); 
  template <typename V>
struct glOption_glNone {
    friend bool operator==<V>(const glOption_glNone &left, const glOption_glNone &right); 
    friend bool operator!=(const glOption_glNone &left, const glOption_glNone &right) { return !(left == right); } 
  };
  template <typename V>
struct glOption_glSome;
  template <typename V>
bool operator==(const glOption_glSome<V> &left, const glOption_glSome<V> &right); 
  template <typename V>
struct glOption_glSome {
    friend bool operator==<V>(const glOption_glSome &left, const glOption_glSome &right); 
    friend bool operator!=(const glOption_glSome &left, const glOption_glSome &right) { return !(left == right); } 
  };
  template <typename V>
struct glOption {
    std::variant<glOption_glNone<V>, glOption_glSome<V>> v;
    static glOption create_glNone() {
      glOption<V> COMPILER_result;
      glOption_glNone<V> COMPILER_result_subStruct;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    static glOption create_glSome() {
      glOption<V> COMPILER_result;
      glOption_glSome<V> COMPILER_result_subStruct;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    glOption();
    ~glOption() {}
    glOption(const glOption &other) {
      v = other.v;
    }
    glOption& operator=(const glOption other) {
      v = other.v;
      return *this;
    }
    bool is_glOption_glNone() const { return std::holds_alternative<glOption_glNone<V>>(v); }
    bool is_glOption_glSome() const { return std::holds_alternative<glOption_glSome<V>>(v); }
    glOption* operator->() { return this; }
    friend bool operator==(const glOption &left, const glOption &right) { 
    	return left.v == right.v;
}
    friend bool operator!=(const glOption &left, const glOption &right) { return !(left == right); } 
  };
  template <typename V>
inline bool is_glOption_glNone(const struct glOption<V> d);
  template <typename V>
inline bool is_glOption_glSome(const struct glOption<V> d);
}// end of namespace GlinearOption_Compile  datatype declarations
namespace Ptrs  {
  template <typename V>
bool operator==(const PointsTo<V> &left, const PointsTo<V> &right); 
  template <typename V>
struct PointsTo {
    PointsTo();
    PointsTo* operator->() { return this; }
    friend bool operator==<V>(const PointsTo &left, const PointsTo &right);
    friend bool operator!=(const PointsTo &left, const PointsTo &right) { return !(left == right); } 
  };
  template <typename V>
inline bool is_PointsTo(const struct PointsTo<V> d) { (void) d; return true; }
  template <typename V>
bool operator==(const PointsToLinear<V> &left, const PointsToLinear<V> &right); 
  template <typename V>
struct PointsToLinear_PointsToLinear;
  template <typename V>
bool operator==(const PointsToLinear_PointsToLinear<V> &left, const PointsToLinear_PointsToLinear<V> &right); 
  template <typename V>
struct PointsToLinear_PointsToLinear {
    friend bool operator==<V>(const PointsToLinear_PointsToLinear &left, const PointsToLinear_PointsToLinear &right); 
    friend bool operator!=(const PointsToLinear_PointsToLinear &left, const PointsToLinear_PointsToLinear &right) { return !(left == right); } 
  };
  template <typename V>
struct PointsToLinear_PointsToEmpty;
  template <typename V>
bool operator==(const PointsToLinear_PointsToEmpty<V> &left, const PointsToLinear_PointsToEmpty<V> &right); 
  template <typename V>
struct PointsToLinear_PointsToEmpty {
    friend bool operator==<V>(const PointsToLinear_PointsToEmpty &left, const PointsToLinear_PointsToEmpty &right); 
    friend bool operator!=(const PointsToLinear_PointsToEmpty &left, const PointsToLinear_PointsToEmpty &right) { return !(left == right); } 
  };
  template <typename V>
struct PointsToLinear {
    std::variant<PointsToLinear_PointsToLinear<V>, PointsToLinear_PointsToEmpty<V>> v;
    static PointsToLinear create_PointsToLinear() {
      PointsToLinear<V> COMPILER_result;
      PointsToLinear_PointsToLinear<V> COMPILER_result_subStruct;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    static PointsToLinear create_PointsToEmpty() {
      PointsToLinear<V> COMPILER_result;
      PointsToLinear_PointsToEmpty<V> COMPILER_result_subStruct;
      COMPILER_result.v = COMPILER_result_subStruct;
      return COMPILER_result;
    }
    PointsToLinear();
    ~PointsToLinear() {}
    PointsToLinear(const PointsToLinear &other) {
      v = other.v;
    }
    PointsToLinear& operator=(const PointsToLinear other) {
      v = other.v;
      return *this;
    }
    bool is_PointsToLinear_PointsToLinear() const { return std::holds_alternative<PointsToLinear_PointsToLinear<V>>(v); }
    bool is_PointsToLinear_PointsToEmpty() const { return std::holds_alternative<PointsToLinear_PointsToEmpty<V>>(v); }
    PointsToLinear* operator->() { return this; }
    friend bool operator==(const PointsToLinear &left, const PointsToLinear &right) { 
    	return left.v == right.v;
}
    friend bool operator!=(const PointsToLinear &left, const PointsToLinear &right) { return !(left == right); } 
  };
  template <typename V>
inline bool is_PointsToLinear_PointsToLinear(const struct PointsToLinear<V> d);
  template <typename V>
inline bool is_PointsToLinear_PointsToEmpty(const struct PointsToLinear<V> d);
  template <typename V>
bool operator==(const PointsToArray<V> &left, const PointsToArray<V> &right); 
  template <typename V>
struct PointsToArray {
    PointsToArray();
    PointsToArray* operator->() { return this; }
    friend bool operator==<V>(const PointsToArray &left, const PointsToArray &right);
    friend bool operator!=(const PointsToArray &left, const PointsToArray &right) { return !(left == right); } 
  };
  template <typename V>
inline bool is_PointsToArray(const struct PointsToArray<V> d) { (void) d; return true; }
}// end of namespace Ptrs  datatype declarations
namespace BankTokens_Compile  {
  
bool operator==(const Account &left, const Account &right); 
  
struct Account {
    Account();
    Account* operator->() { return this; }
    friend bool operator==(const Account &left, const Account &right);
    friend bool operator!=(const Account &left, const Account &right) { return !(left == right); } 
  };
  
inline bool is_Account(const struct Account d) { (void) d; return true; }
}// end of namespace BankTokens_Compile  datatype declarations
namespace LinearCells  {
  template <typename V>
bool operator==(const LCellContents<V> &left, const LCellContents<V> &right); 
  template <typename V>
struct LCellContents {
    Options_Compile::Option <V>  v;
    LCellContents(Options_Compile::Option <V>  v) : v (v) {}
    LCellContents();
    LCellContents* operator->() { return this; }
    friend bool operator==<V>(const LCellContents &left, const LCellContents &right);
    friend bool operator!=(const LCellContents &left, const LCellContents &right) { return !(left == right); } 
  };
  template <typename V>
inline bool is_LCellContents(const struct LCellContents<V> d) { (void) d; return true; }
}// end of namespace LinearCells  datatype declarations
namespace BitOps_Compile  {
}// end of namespace BitOps_Compile  datatype declarations
namespace Atomics  {
}// end of namespace Atomics  datatype declarations
namespace Mutexes  {
  template <typename V>
bool operator==(const Mutex<V> &left, const Mutex<V> &right); 
  template <typename V>
struct Mutex {
    Atomics::Atomic <bool, GlinearOption_Compile::glOption <LinearCells::LCellContents <V> > >  at;
    LinearCells::LinearCell <V>  cell;
    Mutex(Atomics::Atomic <bool, GlinearOption_Compile::glOption <LinearCells::LCellContents <V> > >  at, LinearCells::LinearCell <V>  cell) : at (at),  cell (cell) {}
    Mutex();
    Mutex* operator->() { return this; }
    friend bool operator==<V>(const Mutex &left, const Mutex &right);
    friend bool operator!=(const Mutex &left, const Mutex &right) { return !(left == right); } 
    
    V acquire();
    
    void release(V v);
  };
  template <typename V>
inline bool is_Mutex(const struct Mutex<V> d) { (void) d; return true; }
  template <typename V>
bool operator==(const MutexHandle<V> &left, const MutexHandle<V> &right); 
  template <typename V>
struct MutexHandle {
    MutexHandle();
    MutexHandle* operator->() { return this; }
    friend bool operator==<V>(const MutexHandle &left, const MutexHandle &right);
    friend bool operator!=(const MutexHandle &left, const MutexHandle &right) { return !(left == right); } 
  };
  template <typename V>
inline bool is_MutexHandle(const struct MutexHandle<V> d) { (void) d; return true; }
}// end of namespace Mutexes  datatype declarations
namespace LinearMaybe  {
}// end of namespace LinearMaybe  datatype declarations
namespace LinearExtern  {
}// end of namespace LinearExtern  datatype declarations
namespace LinearSequence__i_Compile  {
}// end of namespace LinearSequence__i_Compile  datatype declarations
namespace BankImplementation_Compile  {
  
bool operator==(const AccountEntry &left, const AccountEntry &right); 
  
struct AccountEntry {
    BigNumber balance;
    AccountEntry(BigNumber balance) : balance (balance) {}
    AccountEntry();
    AccountEntry* operator->() { return this; }
    friend bool operator==(const AccountEntry &left, const AccountEntry &right);
    friend bool operator!=(const AccountEntry &left, const AccountEntry &right) { return !(left == right); } 
  };
  
inline bool is_AccountEntry(const struct AccountEntry d) { (void) d; return true; }
  
bool operator==(const AccountSeq &left, const AccountSeq &right); 
  
struct AccountSeq {
    LinearExtern::lseq <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> >  accounts;
    AccountSeq(LinearExtern::lseq <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> >  accounts) : accounts (accounts) {}
    AccountSeq();
    AccountSeq* operator->() { return this; }
    friend bool operator==(const AccountSeq &left, const AccountSeq &right);
    friend bool operator!=(const AccountSeq &left, const AccountSeq &right) { return !(left == right); } 
  };
  
inline bool is_AccountSeq(const struct AccountSeq d) { (void) d; return true; }
}// end of namespace BankImplementation_Compile  datatype declarations
namespace Cells  {
  template <typename V>
bool operator==(const CellContents<V> &left, const CellContents<V> &right); 
  template <typename V>
struct CellContents {
    V v;
    CellContents(V v) : v (v) {}
    CellContents();
    CellContents* operator->() { return this; }
    friend bool operator==<V>(const CellContents &left, const CellContents &right);
    friend bool operator!=(const CellContents &left, const CellContents &right) { return !(left == right); } 
  };
  template <typename V>
inline bool is_CellContents(const struct CellContents<V> d) { (void) d; return true; }
}// end of namespace Cells  datatype declarations
namespace TicketStubSingletonLoc_Compile  {
}// end of namespace TicketStubSingletonLoc_Compile  datatype declarations
namespace MapRemove_s_Compile  {
}// end of namespace MapRemove_s_Compile  datatype declarations
namespace Maps_Compile  {
}// end of namespace Maps_Compile  datatype declarations
namespace _module  {
}// end of namespace _module  datatype declarations
namespace _System  {
}// end of namespace _System  class declarations
namespace NativeTypes_Compile  {
  class class_sbyte {
    public:
    // Default constructor
    class_sbyte() {}
    static int8 get_Default() {
      return 0;
    }
  };
  class class_byte {
    public:
    // Default constructor
    class_byte() {}
    static uint8 get_Default() {
      return 0;
    }
  };
  class class_int16 {
    public:
    // Default constructor
    class_int16() {}
    static int16 get_Default() {
      return 0;
    }
  };
  class class_uint16 {
    public:
    // Default constructor
    class_uint16() {}
    static uint16 get_Default() {
      return 0;
    }
  };
  class class_int32 {
    public:
    // Default constructor
    class_int32() {}
    static int32 get_Default() {
      return 0;
    }
  };
  class class_uint32 {
    public:
    // Default constructor
    class_uint32() {}
    static uint32 get_Default() {
      return 0;
    }
  };
  class class_int64 {
    public:
    // Default constructor
    class_int64() {}
    static int64 get_Default() {
      return 0;
    }
  };
  class class_uint64 {
    public:
    // Default constructor
    class_uint64() {}
    static uint64 get_Default() {
      return 0;
    }
  };
  class class_nat8 {
    public:
    // Default constructor
    class_nat8() {}
    static int8 get_Default() {
      return 0;
    }
  };
  class class_nat16 {
    public:
    // Default constructor
    class_nat16() {}
    static int16 get_Default() {
      return 0;
    }
  };
  class class_nat32 {
    public:
    // Default constructor
    class_nat32() {}
    static int32 get_Default() {
      return 0;
    }
  };
  class class_nat64 {
    public:
    // Default constructor
    class_nat64() {}
    static int64 get_Default() {
      return 0;
    }
  };
  class class_uint128 {
    public:
    // Default constructor
    class_uint128() {}
    static __m128i get_Default() {
      return _mm_setr_epi32(0,0,0,0);
    }
  };
  class __default {
    public:
    // Default constructor
    __default() {}
    static uint64 Uint64Size();static uint64 Uint32Size();static uint64 Uint16Size();  };
}// end of namespace NativeTypes_Compile  class declarations
namespace Options_Compile  {
}// end of namespace Options_Compile  class declarations
namespace MathUtils_Compile  {
}// end of namespace MathUtils_Compile  class declarations
namespace Bank_Compile  {
  class class_nat64 {
    public:
    // Default constructor
    class_nat64() {}
    static int64 get_Default() {
      return 0;
    }
  };
  class __default {
    public:
    // Default constructor
    __default() {}
    static BigNumber init__NumberOfAccounts() {
      return 7;
    }
    static BigNumber NumberOfAccounts;
    static BigNumber init__FixedTotalMoney() {
      return 300;
    }
    static BigNumber FixedTotalMoney;
  };
}// end of namespace Bank_Compile  class declarations
namespace GlinearMap_Compile  {
}// end of namespace GlinearMap_Compile  class declarations
namespace GhostLoc_Compile  {
}// end of namespace GhostLoc_Compile  class declarations
namespace RequestIds_Compile  {
}// end of namespace RequestIds_Compile  class declarations
namespace Rw_PCMWrap_ON_Bank__Compile  {
}// end of namespace Rw_PCMWrap_ON_Bank__Compile  class declarations
namespace Tokens_ON_Rw__PCMWrap__ON__Bank____Compile  {
}// end of namespace Tokens_ON_Rw__PCMWrap__ON__Bank____Compile  class declarations
namespace PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile  {
  class class_GToken {
    public:
    // Default constructor
    class_GToken() {}
    static GToken get_Default() {
      return Tokens_ON_Rw__PCMWrap__ON__Bank____Compile::Token();
    }
  };
}// end of namespace PCMWrapTokens_ON_Rw__PCMWrap__ON__Bank____Compile  class declarations
namespace Rw_PCMExt_ON_Bank__Compile  {
}// end of namespace Rw_PCMExt_ON_Bank__Compile  class declarations
namespace Tokens_ON_Rw__PCMExt__ON__Bank____Compile  {
}// end of namespace Tokens_ON_Rw__PCMExt__ON__Bank____Compile  class declarations
namespace ExtTokens_ON_Rw__PCMWrap__ON__Bank___Rw__PCMExt__ON__Bank____Compile  {
}// end of namespace ExtTokens_ON_Rw__PCMWrap__ON__Bank___Rw__PCMExt__ON__Bank____Compile  class declarations
namespace RwTokens_ON_Bank__Compile  {
  class class_Token {
    public:
    // Default constructor
    class_Token() {}
    static Token get_Default() {
      return Tokens_ON_Rw__PCMExt__ON__Bank____Compile::Token();
    }
  };
  class __default {
    public:
    // Default constructor
    __default() {}
  };
}// end of namespace RwTokens_ON_Bank__Compile  class declarations
namespace GlinearOption_Compile  {
  class __default {
    public:
    // Default constructor
    __default() {}
  };
}// end of namespace GlinearOption_Compile  class declarations
namespace Ptrs  {
}// end of namespace Ptrs  class declarations
namespace BankTokens_Compile  {
  class __default {
    public:
    // Default constructor
    __default() {}
  };
}// end of namespace BankTokens_Compile  class declarations
namespace LinearCells  {
}// end of namespace LinearCells  class declarations
namespace BitOps_Compile  {
  class __default {
    public:
    // Default constructor
    __default() {}
    static uint8 bit__or__uint8(uint8 a, uint8 b);static uint8 bit__and__uint8(uint8 a, uint8 b);static uint8 bit__xor__uint8(uint8 a, uint8 b);static uint64 bit__or__uint64(uint64 a, uint64 b);static uint64 bit__and__uint64(uint64 a, uint64 b);static uint64 bit__xor__uint64(uint64 a, uint64 b);  };
}// end of namespace BitOps_Compile  class declarations
namespace Atomics  {
}// end of namespace Atomics  class declarations
namespace Mutexes  {
}// end of namespace Mutexes  class declarations
namespace LinearMaybe  {
}// end of namespace LinearMaybe  class declarations
namespace LinearExtern  {
}// end of namespace LinearExtern  class declarations
namespace LinearSequence__i_Compile  {
  class __default {
    public:
    // Default constructor
    __default() {}
    template <typename __A>
    static LinearExtern::linear_seq<__A> seq__alloc__init(uint64 length, __A a);template <typename __A>
    static uint64 lseq__length__as__uint64(LinearExtern::lseq <__A> & s);template <typename __A>
    static uint64 lseq__length__uint64(LinearExtern::lseq <__A> & s);
    template <typename __A>
    static __A* lseq__peek(LinearExtern::lseq <__A> & s, uint64 i);template <typename __A>
    static LinearExtern::lseq <__A>  lseq__alloc(uint64 length);
    template <typename __A>
    static LinearExtern::lseq <__A>  lseq__alloc__hugetables(uint64 length);
    template <typename __A>
    static void lseq__free(LinearExtern::lseq <__A>  s);
    template <typename __A>
    static Tuple0 lseq__free__fun(LinearExtern::lseq <__A>  s);template <typename __A>
    static struct Tuple<LinearExtern::lseq <__A> , __A> lseq__swap(LinearExtern::lseq <__A>  s1, uint64 i, __A a1);
    template <typename __A>
    static __A lseq__swap__inout(LinearExtern::lseq <__A> & s, uint64 i, __A a1);
    template <typename __A>
    static struct Tuple<LinearExtern::lseq <__A> , __A> lseq__take(LinearExtern::lseq <__A>  s1, uint64 i);
    template <typename __A>
    static __A lseq__take__inout(LinearExtern::lseq <__A> & s, uint64 i);
    template <typename __A>
    static Tuple <LinearExtern::lseq <__A> , __A>  lseq__take__fun(LinearExtern::lseq <__A>  s1, uint64 i);template <typename __A>
    static LinearExtern::lseq <__A>  lseq__give(LinearExtern::lseq <__A>  s1, uint64 i, __A a);
    template <typename __A>
    static void lseq__give__inout(LinearExtern::lseq <__A> & s1, uint64 i, __A a);
    template <typename __A>
    static void SeqCopy(LinearExtern::shared_seq<__A>& source, LinearExtern::linear_seq<__A>& dest, uint64 start, uint64 end, uint64 dest__start);
    template <typename __A>
    static LinearExtern::linear_seq<__A> AllocAndCopy(LinearExtern::shared_seq<__A>& source, uint64 from, uint64 to);
    template <typename __A>
    static struct Tuple<LinearExtern::lseq <__A> , LinearExtern::lseq <__A> > AllocAndMoveLseq(LinearExtern::lseq <__A>  source, uint64 from, uint64 to);
    template <typename __A>
    static LinearExtern::linear_seq<__A> SeqResize(LinearExtern::linear_seq<__A> s, uint64 newlen, __A a);
    template <typename __A>
    static void SeqResizeMut(LinearExtern::linear_seq<__A>& s, uint64 newlen, __A a);
    template <typename __A>
    static LinearExtern::linear_seq<__A> InsertSeq(LinearExtern::linear_seq<__A> s, __A a, uint64 pos);
    template <typename __A>
    static LinearExtern::lseq <__A>  InsertLSeq(LinearExtern::lseq <__A>  s, __A a, uint64 pos);
    template <typename __A>
    static struct Tuple<LinearExtern::lseq <__A> , __A> Replace1With2Lseq(LinearExtern::lseq <__A>  s, __A l, __A r, uint64 pos);
    template <typename __A>
    static __A Replace1With2Lseq__inout(LinearExtern::lseq <__A> & s, __A l, __A r, uint64 pos);
    template <typename __A>
    static void mut__seq__set(LinearExtern::linear_seq<__A>& s, uint64 i, __A a);
  };
}// end of namespace LinearSequence__i_Compile  class declarations
namespace BankImplementation_Compile  {
  class class_nat64 {
    public:
    // Default constructor
    class_nat64() {}
    static int64 get_Default() {
      return 0;
    }
  };
  class __default {
    public:
    // Default constructor
    __default() {}
    static bool TryAccountTransfer(BankImplementation_Compile::AccountSeq& accountSeq, uint64 sourceAccountId, uint64 destAccountId, BigNumber amount);
    static BigNumber AssertAccountIsNotTooRich(BankImplementation_Compile::AccountSeq& accountSeq, uint64 accountId);
  };
}// end of namespace BankImplementation_Compile  class declarations
namespace Cells  {
}// end of namespace Cells  class declarations
namespace TicketStubSingletonLoc_Compile  {
}// end of namespace TicketStubSingletonLoc_Compile  class declarations
namespace MapRemove_s_Compile  {
}// end of namespace MapRemove_s_Compile  class declarations
namespace Maps_Compile  {
}// end of namespace Maps_Compile  class declarations
namespace _module  {
}// end of namespace _module  class declarations
template <typename V>
struct std::hash<Options_Compile::Option_None<V>> {
  std::size_t operator()(const Options_Compile::Option_None<V>& x) const {
    size_t seed = 0;
    (void)x;
    return seed;
  }
};
template <typename V>
struct std::hash<Options_Compile::Option_Some<V>> {
  std::size_t operator()(const Options_Compile::Option_Some<V>& x) const {
    size_t seed = 0;
    hash_combine<V>(seed, x.value);
    return seed;
  }
};
template <typename V>
struct std::hash<Options_Compile::Option<V>> {
  std::size_t operator()(const Options_Compile::Option<V>& x) const {
    size_t seed = 0;
    if (x.is_Option_None()) {
      hash_combine<uint64>(seed, 0);
      hash_combine<struct Options_Compile::Option_None<V>>(seed, std::get<Options_Compile::Option_None<V>>(x.v));
    }
    if (x.is_Option_Some()) {
      hash_combine<uint64>(seed, 1);
      hash_combine<struct Options_Compile::Option_Some<V>>(seed, std::get<Options_Compile::Option_Some<V>>(x.v));
    }
    return seed;
  }
};
template <>
struct std::hash<Bank_Compile::M_M> {
  std::size_t operator()(const Bank_Compile::M_M& x) const {
    size_t seed = 0;
    hash_combine<DafnyMap<BigNumber,BigNumber>>(seed, x.account__balances);
    return seed;
  }
};
template <>
struct std::hash<Bank_Compile::M_Invalid> {
  std::size_t operator()(const Bank_Compile::M_Invalid& x) const {
    size_t seed = 0;
    (void)x;
    return seed;
  }
};
template <>
struct std::hash<Bank_Compile::M> {
  std::size_t operator()(const Bank_Compile::M& x) const {
    size_t seed = 0;
    if (x.is_M_M()) {
      hash_combine<uint64>(seed, 0);
      hash_combine<struct Bank_Compile::M_M>(seed, std::get<Bank_Compile::M_M>(x.v));
    }
    if (x.is_M_Invalid()) {
      hash_combine<uint64>(seed, 1);
      hash_combine<struct Bank_Compile::M_Invalid>(seed, std::get<Bank_Compile::M_Invalid>(x.v));
    }
    return seed;
  }
};
template <>
struct std::hash<Bank_Compile::AccountTransfer> {
  std::size_t operator()(const Bank_Compile::AccountTransfer& x) const {
    size_t seed = 0;
    hash_combine<BigNumber>(seed, x.source__account);
    hash_combine<BigNumber>(seed, x.dest__account);
    hash_combine<BigNumber>(seed, x.money);
    return seed;
  }
};
template <>
struct std::hash<GhostLoc_Compile::Loc_BaseLoc> {
  std::size_t operator()(const GhostLoc_Compile::Loc_BaseLoc& x) const {
    size_t seed = 0;
    (void)x;
    return seed;
  }
};
template <>
struct std::hash<GhostLoc_Compile::Loc_ExtLoc> {
  std::size_t operator()(const GhostLoc_Compile::Loc_ExtLoc& x) const {
    size_t seed = 0;
    (void)x;
    return seed;
  }
};
template <>
struct std::hash<GhostLoc_Compile::Loc> {
  std::size_t operator()(const GhostLoc_Compile::Loc& x) const {
    size_t seed = 0;
    if (x.is_Loc_BaseLoc()) {
      hash_combine<uint64>(seed, 0);
      hash_combine<struct GhostLoc_Compile::Loc_BaseLoc>(seed, std::get<GhostLoc_Compile::Loc_BaseLoc>(x.v));
    }
    if (x.is_Loc_ExtLoc()) {
      hash_combine<uint64>(seed, 1);
      hash_combine<struct GhostLoc_Compile::Loc_ExtLoc>(seed, std::get<GhostLoc_Compile::Loc_ExtLoc>(x.v));
    }
    return seed;
  }
};
template <>
struct std::hash<std::shared_ptr<GhostLoc_Compile::Loc>> {
  std::size_t operator()(const std::shared_ptr<GhostLoc_Compile::Loc>& x) const {
    struct std::hash<GhostLoc_Compile::Loc> hasher;
    std::size_t h = hasher(*x);
    return h;
  }
};
template <>
struct std::hash<Rw_PCMWrap_ON_Bank__Compile::M> {
  std::size_t operator()(const Rw_PCMWrap_ON_Bank__Compile::M& x) const {
    size_t seed = 0;
    return seed;
  }
};
template <>
struct std::hash<Tokens_ON_Rw__PCMWrap__ON__Bank____Compile::Token> {
  std::size_t operator()(const Tokens_ON_Rw__PCMWrap__ON__Bank____Compile::Token& x) const {
    size_t seed = 0;
    return seed;
  }
};
template <>
struct std::hash<Tokens_ON_Rw__PCMExt__ON__Bank____Compile::Token> {
  std::size_t operator()(const Tokens_ON_Rw__PCMExt__ON__Bank____Compile::Token& x) const {
    size_t seed = 0;
    return seed;
  }
};
template <typename V>
struct std::hash<GlinearOption_Compile::glOption_glNone<V>> {
  std::size_t operator()(const GlinearOption_Compile::glOption_glNone<V>& x) const {
    size_t seed = 0;
    (void)x;
    return seed;
  }
};
template <typename V>
struct std::hash<GlinearOption_Compile::glOption_glSome<V>> {
  std::size_t operator()(const GlinearOption_Compile::glOption_glSome<V>& x) const {
    size_t seed = 0;
    (void)x;
    return seed;
  }
};
template <typename V>
struct std::hash<GlinearOption_Compile::glOption<V>> {
  std::size_t operator()(const GlinearOption_Compile::glOption<V>& x) const {
    size_t seed = 0;
    if (x.is_glOption_glNone()) {
      hash_combine<uint64>(seed, 0);
      hash_combine<struct GlinearOption_Compile::glOption_glNone<V>>(seed, std::get<GlinearOption_Compile::glOption_glNone<V>>(x.v));
    }
    if (x.is_glOption_glSome()) {
      hash_combine<uint64>(seed, 1);
      hash_combine<struct GlinearOption_Compile::glOption_glSome<V>>(seed, std::get<GlinearOption_Compile::glOption_glSome<V>>(x.v));
    }
    return seed;
  }
};
template <typename V>
struct std::hash<Ptrs::PointsTo<V>> {
  std::size_t operator()(const Ptrs::PointsTo<V>& x) const {
    size_t seed = 0;
    return seed;
  }
};
template <typename V>
struct std::hash<Ptrs::PointsToLinear_PointsToLinear<V>> {
  std::size_t operator()(const Ptrs::PointsToLinear_PointsToLinear<V>& x) const {
    size_t seed = 0;
    (void)x;
    return seed;
  }
};
template <typename V>
struct std::hash<Ptrs::PointsToLinear_PointsToEmpty<V>> {
  std::size_t operator()(const Ptrs::PointsToLinear_PointsToEmpty<V>& x) const {
    size_t seed = 0;
    (void)x;
    return seed;
  }
};
template <typename V>
struct std::hash<Ptrs::PointsToLinear<V>> {
  std::size_t operator()(const Ptrs::PointsToLinear<V>& x) const {
    size_t seed = 0;
    if (x.is_PointsToLinear_PointsToLinear()) {
      hash_combine<uint64>(seed, 0);
      hash_combine<struct Ptrs::PointsToLinear_PointsToLinear<V>>(seed, std::get<Ptrs::PointsToLinear_PointsToLinear<V>>(x.v));
    }
    if (x.is_PointsToLinear_PointsToEmpty()) {
      hash_combine<uint64>(seed, 1);
      hash_combine<struct Ptrs::PointsToLinear_PointsToEmpty<V>>(seed, std::get<Ptrs::PointsToLinear_PointsToEmpty<V>>(x.v));
    }
    return seed;
  }
};
template <typename V>
struct std::hash<Ptrs::PointsToArray<V>> {
  std::size_t operator()(const Ptrs::PointsToArray<V>& x) const {
    size_t seed = 0;
    return seed;
  }
};
template <>
struct std::hash<BankTokens_Compile::Account> {
  std::size_t operator()(const BankTokens_Compile::Account& x) const {
    size_t seed = 0;
    return seed;
  }
};
template <typename V>
struct std::hash<LinearCells::LCellContents<V>> {
  std::size_t operator()(const LinearCells::LCellContents<V>& x) const {
    size_t seed = 0;
    hash_combine<Options_Compile::Option <V> >(seed, x.v);
    return seed;
  }
};
template <typename V>
struct std::hash<Mutexes::Mutex<V>> {
  std::size_t operator()(const Mutexes::Mutex<V>& x) const {
    size_t seed = 0;
    hash_combine<Atomics::Atomic <bool, GlinearOption_Compile::glOption <LinearCells::LCellContents <V> > > >(seed, x.at);
    hash_combine<LinearCells::LinearCell <V> >(seed, x.cell);
    return seed;
  }
};
template <typename V>
struct std::hash<Mutexes::MutexHandle<V>> {
  std::size_t operator()(const Mutexes::MutexHandle<V>& x) const {
    size_t seed = 0;
    return seed;
  }
};
template <>
struct std::hash<BankImplementation_Compile::AccountEntry> {
  std::size_t operator()(const BankImplementation_Compile::AccountEntry& x) const {
    size_t seed = 0;
    hash_combine<BigNumber>(seed, x.balance);
    return seed;
  }
};
template <>
struct std::hash<BankImplementation_Compile::AccountSeq> {
  std::size_t operator()(const BankImplementation_Compile::AccountSeq& x) const {
    size_t seed = 0;
    hash_combine<LinearExtern::lseq <Mutexes::Mutex <BankImplementation_Compile::AccountEntry> > >(seed, x.accounts);
    return seed;
  }
};
template <typename V>
struct std::hash<Cells::CellContents<V>> {
  std::size_t operator()(const Cells::CellContents<V>& x) const {
    size_t seed = 0;
    hash_combine<V>(seed, x.v);
    return seed;
  }
};
