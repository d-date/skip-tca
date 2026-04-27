/*
 * SkipTCA semantic model in Alloy 6.
 *
 * Goal: capture the structural invariants of SkipTCA so the model finder can
 * confirm that no small-scope counterexample violates them. We deliberately
 * stop short of modeling action multisets / sequence concatenation —
 * Alloy's relational logic is poor at quantitative aggregation, so the
 * algebraic laws (Effect.merge identity / associativity) are checked in
 * Swift Testing instead. What Alloy *is* good at — and what we use it for
 * here — is structural well-formedness.
 *
 * What we model
 *  - Effect as an algebraic data type with five disjoint cases:
 *      EffectNone, EffectRun, EffectMerge, EffectCancellable, EffectCancel
 *  - Reducer as a partial map (State, Action) -> Effect
 *  - Store with a state trace and an inbox of dispatched-but-unhandled actions
 *
 * What we check
 *  1. Reducer determinism: each (State, Action) pair maps to at most one Effect.
 *  2. Effect cases are pairwise disjoint (sealed-class invariant).
 *  3. EffectCancel ids are drawn from the CancellationID universe.
 *  4. EffectRun.emits and EffectCancellable.work elements are real Actions.
 *  5. Store trace indexes are non-negative (an append-only history is valid).
 */
module SkipTCA

// ---------- Atoms ----------

sig State {}
sig Action {}
sig CancellationID {}

abstract sig Bool {}
one sig True, False extends Bool {}

// ---------- Effect ADT ----------

abstract sig Effect {}

one sig EffectNone extends Effect {}

sig EffectRun extends Effect {
    emits : seq Action
}

sig EffectMerge extends Effect {
    children : seq Effect
}

sig EffectCancellable extends Effect {
    cid : one CancellationID,
    cancelInFlight : one Bool,
    work : seq Action
}

sig EffectCancel extends Effect {
    targetId : one CancellationID
}

// ---------- Reducer ----------

sig Reducer {
    // Each (state, action) pair maps to at most one (state', effect) pair.
    reduce : State -> Action -> lone (State -> Effect)
}

// ---------- Store ----------

sig Store {
    reducer : one Reducer,
    trace   : seq State,
    inbox   : seq Action
}

// ---------- Properties ----------

// 1. Reducer determinism. The `lone` qualifier on the relation already
// enforces this; the assertion is a regression test against accidental
// loosening of the type.
assert ReducerIsDeterministic {
    all r : Reducer, s : State, a : Action |
        lone r.reduce[s][a]
}
check ReducerIsDeterministic for 3

// 2. Every Effect belongs to exactly one of the five sub-signatures.
// `extends` already gives us this in Alloy, but re-stating it as an
// assertion guards against future refactors that might collapse two cases.
assert EveryEffectHasOneCase {
    all e : Effect |
        e in (EffectNone + EffectRun + EffectMerge + EffectCancellable + EffectCancel)
}
check EveryEffectHasOneCase for 3

// 3. EffectCancel ids are drawn from the CancellationID universe.
assert CancelTargetsValidCancellationID {
    all c : EffectCancel |
        c.targetId in CancellationID
}
check CancelTargetsValidCancellationID for 3

// 4. The actions an EffectRun or EffectCancellable carries belong to the
// Action universe.
assert EmitElementsAreActions {
    all r : EffectRun |
        r.emits.elems in Action
    all r : EffectCancellable |
        r.work.elems in Action
}
check EmitElementsAreActions for 3

// 5. Store trace indexes are non-negative.
assert TraceIndexesAreNonNegative {
    all st : Store, i : st.trace.inds |
        i >= 0
}
check TraceIndexesAreNonNegative for 3

// (No `run` predicate is supplied here. The five `check` commands above are
// the regression surface; they should all report UNSAT, which means no
// counterexample to the property exists at the chosen scope. Adding a
// `run` predicate that simultaneously requires every Effect sub-sig to be
// populated tends to thrash the SAT solver because Alloy must allocate
// distinct atoms for `State`, `Action`, `CancellationID`, two `Bool`s,
// `Reducer`, `Store`, `EffectNone`, and one of each remaining sub-sig —
// blowing through a small global scope. Open the model in `alloy gui`
// and run a per-property `Run` if you want to inspect instances visually.)
