include "Impl.s.dfy"
include "BankTokens.i.dfy"
include "../framework/Mutex.i.dfy"
include "../../lib/Lang/LinearSequence.i.dfy"

module BankImplementation refines BankSpec {
  newtype{:nativeType "long"} nat64 = i:int | 0 <= i < 0x8000000000000000
  import Bank
  import BankTokens
  import opened Mutexes
  import opened LinearSequence_i
  import opened LinearSequence_s

  linear datatype AccountEntry = AccountEntry(
      balance: nat,
      glinear token: BankTokens.Account
    )

  predicate Inv(loc_s: nat, accountId: nat, entry: AccountEntry) {
    entry.token == BankTokens.Account(loc_s, accountId, entry.balance)
  }

  linear datatype AccountSeq = AccountSeq(
      ghost s_loc: nat,
      linear accounts: lseq<Mutex<AccountEntry>>
  )

  predicate WF(a: AccountSeq)
  {
    && |a.accounts| == Bank.NumberOfAccounts
    && (forall accountId | 0 <= accountId < Bank.NumberOfAccounts ::
        accountId in a.accounts)
    && (forall accountId | 0 <= accountId < Bank.NumberOfAccounts ::
        && a.accounts[accountId].WF()
        && (forall entry ::
          a.accounts[accountId].inv(entry) <==> Inv(a.s_loc, accountId, entry)
        )
    )
  }

  /*
   * Do the transfer (but only if the source account has enough money)
   * Return 'true' on success (the return value is not verified in any sense)
   */
  method TryAccountTransfer(
      shared accountSeq: AccountSeq,
      sourceAccountId: uint64,
      destAccountId: uint64,
      amount: nat)
  returns (success: bool)
  //requires WF(accountSeq)
  //requires 0 <= sourceAccountId as int < Bank.NumberOfAccounts
  //requires 0 <= destAccountId as int < Bank.NumberOfAccounts
  //requires sourceAccountId != destAccountId
  decreases *
  {
    shared var accounts := accountSeq.accounts;

    // 1. Acquire the two mutexes

    linear var sourceAccountEntry, destAccountEntry;
    glinear var handle1, handle2;
    sourceAccountEntry, handle1 := lseq_peek(accounts, sourceAccountId).acquire();
    destAccountEntry, handle2 := lseq_peek(accounts, destAccountId).acquire();

    // unpack the datatypes to the physical state (sourceBalance and destBalance)
    // and the ghost state (sourceToken and destToken)

    linear var AccountEntry(sourceBalance, sourceToken) := sourceAccountEntry;
    linear var AccountEntry(destBalance, destToken) := destAccountEntry;

    var newSourceBalance: nat;
    var newDestBalance: nat;

    if amount <= sourceBalance {
      // 2. Update the source balance.

      // (We do this all on the stack, but an alternative implementation might have
      // us update a shared memory cell, which we would gain exclusive access to via
      // the mutex.)

      var a : nat64;
      var b : nat64;
      var c : nat64;
      var d : nat64;
      var e : nat64;
      a := sourceBalance as nat64;
      b := destBalance as nat64;
      c := amount as nat64;
      d := a - c;
      e := b + c;
      
      // newSourceBalance := sourceBalance - amount;
      newSourceBalance := d as nat;

      // 3. Update the dest balance.
      // newDestBalance := destBalance + amount;
      newDestBalance := e as nat;

      // 4. Ghost update here

      ////////////////////////////
      ////////////////////////////

      sourceToken, destToken := BankTokens.do_transfer(sourceToken, destToken, amount);

      ////////////////////////////
      ////////////////////////////

      success := true;
    } else {
      newSourceBalance := sourceBalance;
      newDestBalance := destBalance;

      success := false;
    }

    // 5. Release the locks

    lseq_peek(accounts, sourceAccountId).release(AccountEntry(newSourceBalance, sourceToken), handle1);
    lseq_peek(accounts, destAccountId).release(AccountEntry(newDestBalance, destToken), handle2);
  }

  method AssertAccountIsNotTooRich(
      shared accountSeq: AccountSeq,
      accountId: uint64)
  returns (bal: int)
  //requires WF(accountSeq)
  //requires 0 <= accountId as int < Bank.NumberOfAccounts
  decreases *
  {
    shared var accounts := accountSeq.accounts;

    linear var accountEntry;
    glinear var handle;
    accountEntry, handle := lseq_peek(accounts, accountId).acquire();

    linear var AccountEntry(balance, token) := accountEntry;

    BankTokens.get_bound(token);

    assert balance <= 300;

    lseq_peek(accounts, accountId).release(AccountEntry(balance, token), handle);

    bal := balance;
  }
}
