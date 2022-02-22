abstract module AtomicStateMachineMod {
  // This interface is for a state machine where the inputs arrive, event
  // occurs, and outputs are delivered all atomically. The Async module
  // converts one of these machines into one where all three events are
  // separate asynchronous steps.

  // Application Interface -- parameters to transition labels that
  // become Requests and Replies in AsyncMod.
  type Input
  type Output

  // State machine
  type Variables

  // NB: we're boldly not using Lamport-style predicate for init. That's
  // because in practice we never exploit that freedom, and having a
  // distinguished Init state available as a function output makes writing
  // other stuff easier.
  function InitState() : Variables

  predicate Next(v: Variables, v': Variables, input: Input, out: Output)
}
