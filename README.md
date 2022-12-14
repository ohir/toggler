**Toggler** is an observable state machine register. It orchestrates state transitions, validation and finally it may notify observers of a just commited state change.

**Toggler** instance may keep up to 63 (web 32) boolean values (bits, flags) reflecting state of the same number of _items_. Register bits can be manipulated one by one or in concert.

For direct use in ViewModels of _Flutter_ UI **Toggler** provides an independent _disabled_ property for each of state register bits and supports "radio grouping" among adjacent two or more of them.

**Toggler** was designed for MVVM and similar newer architectures with unidirectional flow of state changes and it was specifically tailored for safe use with singleton _Models_.

**Toggler** based state machine transitions are fully synchronous. It means these are reproducibly testable.

Toggler is a single concrete class library with no dependencies.

Test coverage: `100.0% (194 of 194 lines)`

## Why should I use this for app state managnment?

State machines, ie. _Models_, built on Toggler promise to be fully testable, as **all** state transitions within are dealt with by a **synchronous** code of the "state fixers".

Async things that in app will _signal_ Toggler can be mocked at ease and both their signals and their values permuted at will at test time - **reproducibly** on a **predictable** schedule.

(_In author's opinion_) using Toggler for state transitions should be as safe as _Reactive_ setups but without hundreds of lines of boilerplate _copyWith_ constructors for user to write.

Will Toggler deliver on its promise? Time will tell. That's a fresh idea and fresh code.
> _If this promise sounds good for your business future I am for hire now_

<!-- Longer story at end of README

## When should I use this?

If you know your app functionality will only grow.  If you need elasticity.  If you like to have control over your code paths.
-->

## Observable State Register?

Its simple:
1. every _bit_ of a register reflects something (an _item_) that may change in your _Model_.
(Terms _item, flag, bit_ (of Toggler) are used interchangeably in docs).
2. if that _item_ changes, it _signals_ register about change: just with its given (at birth) bit _index_. If _item_ happens to be a boolean value, it can just be set, or toggled directly at the register. Such _direct change_ also is a kind of _signal_ and fires Toggler state transition machinery.
3. copy of a current register along with _signal_ bit position is then passed to the state machine _fixer_ realizing some business-logic for the _Model_.
4. fixer, knowing who has changed from its _signal_ position, may inspect content of the _item_ then may flip, set, or clear respective bit of register to accept (or decline) signalled change.
5. Fixer can also initiate change of other _items_, if state transition schema so mandates. Then bits of these other _items_ will also be toggled, set, or cleared.
6. Finally, realized by fixer state machine arrives at its prescribed next stable state, new content of the register is compared to the previous, diff made, then this diff is exposed to the _outer world_. Eg. pushed to a _notifier_. Or statically read from Toggler's `chb` property.

Observers from the _outer world_ seeing this diff (changed-bits signal) may decide whether the recent changes are of any interest to them. Simply by filtering the coming diff using a const bitmask.

## Getting started

_Toggler library does not depend on anything from Flutter and can be used server side with pure Dart:_.

 1. `$> dart pub get toggler` (for CLI)
 1. `$> dart pub get uimodel` (for Flutter GUI binding of the next example)
 2. import toggler: `import 'package:toggler/toggler.dart';`
 3. declare meaningful names for your flags/items/bits:
 ```Dart
     const bTurn = 0; //           item index
     const sTurn = 1 << bTurn; // item select bitmask
     const bClaim = 1;
     const sClaim = 1 << bClaim;
     const bPrize = 2; // ...
 ```
 4. instantiate and use
 ```Dart
     final flags = Toggler(fix: ourStateFixer, after: ourAfterHandler);
     // ...
     flags[bTurn] = true; // or flags.set1(bTurn);
     flags[bPrize] = false // or flags.set0(bPrize);
     if (flags[bTurn] && didUserWon()) flags.set1(bPrize);
     void claim() => flags.toggle(bClaim);
     String get result => flags[bPrize] ? 'Your Prize!' : 'Try again!';
 ```
_See toggler_example.dart for Toggler basics._

For _Flutter_ apps use there is a thin wrapper around Toggler called [UiModel](https://pub.dev/packages/uimodel) that allows UI Views be wired to a Toggler based singleton Models (ViewModels) by just two lines of code - first in Model, second in Widget's `build`:
```Dart
// make a Model (ViewModel):
class ViewModel with UiModel { // (0) now your ViewModel has a Toggler under the hood
  ViewModel(){...; linkUi();}  // (0) wire Model to View(s) by `linkUi()`
  // ...
}
// ...
MyWidget extends StatelessWidget with UiModelLink { // (0) wire View to Model(s)
// (0) state flow stage 0 is-a wiring code
// ... then in a formerly "stateless" Widget stages 1..5 occur:
// (1) get your ViewModel object in scope
// (2) declare what to observe in Model (in Model's Toggler)
// (3) read and use data from Model
// (4) pass actions to Model
//     -> Model changes; if fix toggles bTurn or bPrize ->
// (5) rebuild on either sTurn or sPrize change notification
  Widget build(BuildContext context) { // (0, 5)
    final m = ViewModel(); // (1) get singleton Model with UiModel
    watches(m, sTurn | sPrize)); // (b0, b2) observe these pieces of Model
    // Here View knows M and knows when M changes Turn and/or Prize...
      // it can read and use data from Model...
      Text('${m[bPrize] ? m.prize : 'Try again!'}'), // (3)
        // Here unidirectional state flow both begins and completes:
        m[bPrize] // (3)
          ? MyButton('Claim Prize!', onPressed: m.claim), // (0) (4)
          : MyButton('Dice Roll', onPressed: m.droll), // (0) (4)
```
_See example/flutter_example.dart for a complete app code._


### the App state flow

> Pre: Some property in your Model is mutated, eg. a background service just hinted Model with a new _NameString_. NameString setter then registers state change in Model's internal Toggler, eg. by calling `signal(bName)`. Then:

1. `Toggle` setter changes a **single** state bit, (here one at `bName` index), this change is put on a `newState` object that is a _state copy_ of the Toggler, but with _bName_ bit toggled. Then both `liveState` and `newState` are passed to the state transition handler `fix(liveState, newState)`. The `fix` handler is the "business logic" function provided by you.
2. `Fix` may test, validate and change _newState_ further, eg. setting the _bNameHintReceived_ flag, and clearing _bWaitingForNameHint_ one. When new state is properly set, `fix` returns _true_.
3. then the _newState_ is commited to the Toggler, ie. it becomes its current (aka _live_) state. This is a state that outer world sees.
4. Next, the `after(JustCommitedLiveState)` handler (also provided by you) runs. It may not change anything further, but it may decide whether the outer world should know about the changes. If so, it may notify others by itself, then/or pass baton to the
5. `notifier` object that informs its subscribers, if it has any. If there is no `after` handler installed, and `notifier` object is, its _pump(changes)_ method runs automatically on commit.
6. World is notified, so it may react: the View layer may hide a progress spinner and show an edit field filled with just received _NameString_, background connection to the hint service may observe _bNameHintReceived_ then close, and so on.
7. -> 1. State machine transition mill will run again at the next change that registers in Toggler.

### API DTL;DR

You should read at least `fix` docs to make any serious use of Toggler.
Skim over a below included api cheat-sheet for the rest.

#### constructor:
```Dart
Toggler({
  fix? = onChange(liveState, newState) //     // state transition handler, 
  after? = afterChange(justCommitedLiveState) // state finalize handler,
  notifier? = ToggledNotifier(), //           // let others know
  bits: 0, ds: 0, rg: 0, hh: 0, chb: 0, // register of state is public
})
```
- at least one state transition handler is needed to make a _live state_ Toggler. All other members can be given to default constructor, too - used eg. in saved state deserializer and tests. An all-defaults Toggler can be mutated at will, eg. in an explicit App state initializer. The `fix`, `after`, and `notifier` handlers can be attached later.
- your code in `fix` may manipulate _newState_ at will, it even may assign a some predefined const values to the `bits` and/or `ds` properties of it. Usually `fix` is a Model's internal function so it may have access to all other pieces of your business logic (and/or of ViewModel logic). The `newState` is a transition state object, a Toggler subclass. Its `bits` and `ds` initially are a copy of the _live state_. The `newState` may change during the `fix` run, either mutated directly or indirectly by `fix` actions (indirectly: if sets or signals come back to the _live state_ from a synchronous code called by `fix` on this run).
- your code in `after` is given a just commited state before anyone else will see it.
- `After` then may decide whether a `notifier` should run or it may elect to dispatch some  notifications by itself. Eg. if your legacy Widget code builds of StreamBuilder, `after` may feed the Stream just for it - passing the rest to the `notifier`.
- a `notifier` object usually comes from an associated library, but it can also be yours.

#### factories:
- `state()` returns a new Toggler being a _copy of state_ only. Ie. _bits_, _ds_, _hh_, and _rg_.  Other fields are at their defaults, no handlers, no notifier.

#### getters:
- `[i]` returns state of item bit at index i (_true_ for a set1 item).
- `active(i)` returns negation of _disabled_ property of item at index i.

#### setters:
- `[i]=` sets state of item bit at index i
- `toggle(i)` flip state of item bit at index i
- `set1(i)`, `set0(i)`, `setTo(i, state)` change a single item bit value at `i` index
- `enable(i)`, `disable(i)`, `setDS(i, state)` mutate _disabled_ property of an item
- `set1(i, ifActive: true)`, `...` bit setters may depend on a _disabled_ property
- `signal(i)` does not change state bits by itself but informs that some change was made and likely it should be reflected at bit i, possibly after some checks. First signal fires `fix` and more signals may come in response to changes that originate in the `fix` handler.

#### state fixer:
- `signals` keeps 1 at index of signal that fired fix and any later
- `fixBits(i, value)`, `fixDs(i, value)` non-registering setters
- `clearComingAt` clears a coming signal bit
- `supressOutAt`  forcibly sets an outgoing changes mask (chb)
- `fixOutSignal`  supress or force a changed-bit signal

#### state tests:
- `chb` property has bits set to 1 at positions that recently changed state
- `recent` is index of a latest singular state bit change that came from a setter
- `serial` is a monotonic state serial number (36b), bigger is newer
- `changed(selmask)` tells if there was a change on any of _selmask_ positions
- `changedAt(bIndex)` tells if there was a change at _bIndex_
- `anyOfSet({first, last, selmask})` _true_ if any item bit is set in range or by selmask
- `differsFrom(other, {first, last, selmask})` compares this and other state (bits, ds)

#### diagnostics:
- `error` _true_ if in release build Toggler method got a wrong index
- `done` _true_ if set by your App code. Cleared at every new change.
- `held` _true_ if changes to state register were supressed by `hold()`,
  _false_ if changes are allowed, ie. after a call to `resume()`

#### radio group setup:
- `radioGroup(first, last)` If one in given range is set, others are cleared automatically.

#### serialize:
Toggler intentionally has no `toString` nor `toJSON` methods. Its whole state is public and consist of just four _ints_. It should be handled seamlessly by any serialization method one may have chosen for a whole _Model_.


## the price tag

Toggler based Models use indice and masks.  Named for the sake of humans, but just numbers to the code. Naming numbers is a one-time chore supported by included const file generator. So, if your App/Model state machine can be represented on up to 63(32) bits, you're set.

But If 63/32 is not enough, or you want to work with many submodels there is a caveat: while names will be unique, index numbers and masks will not.

It then may happen that you inadverently pass a name meant for submodel A, to the submodel B, or C. As Toggler code sees only numbers it will act on these not knowing that `const bPrecise = 7` meant for `Measure` submodel came to the `Storage` submodel where index 7 is a `bDeleteAll` action.

This could be vetted in the base code, but then Toggler core would no longer be simple nor fast. Hence validating and correcting index/mask numbers (per an instance) deliberately were left out for the user implementation suiting particular needs.

For the practical usage a simpler solution exists that wastes no cpu cycles and works for many submodels as well:

### Toggler naming conventions

1. index name starts with `b` (bit), mask name starts with `s` (select mask), Toggler based _Model_ indice are prefixed with `m`.
2. then the _ChosenName_ comes giving `bChosenName`, `sChosenName` (of some `mModelName`).
3. for a single Toggler registering for a single Model - thats all.
4. if there are more Toggler based submodels in your Model, each of them and its bits names are given the same capital letters suffix, eg: `watches(mToppartBX, sRenamedBX | sSavedBX);` (`watches` from [uimodel]).

_Follow the convention. Then if not you visually at writing, your linter later may spot that the ending of a parameter name does not match the suffix of the name of the receiving object and warn you accordingly_.


### hints, traps, and remedies

- This library is synchronous so your handler methods should complete fast enough. Any interface with async code should be done via a proper state cycle (eg. in a separate Isolate). Ie. while your async code may easily register in Toggler, you should pass any changes back only using a `notifier`.

- While `fix` runs the live Toggler state is on hold. External changes and signals are coming directly to the `newState` that is not externally observable until commited. Others, including other's `fix` handlers know only about stable state. Nonetheless, all changes made and signals that came on the run will be reflected at the _changed bits_ outgoing signal. (Unless user intentinally supress them from within the `fix`).

<!--
#### promised longer intro

_Any and every app IS-A state machine. With Dart async code it is hard to have a predictable and testable state machine encompassing a big app like a tax-forms filling aid. We usually deal with state transitions complexity by isolating and chopping functionality to smallest possible pieces, ones that transit just a few bits of state. Then we do a patchwork of them to get at envisioned user experience._

_This approach usualy works. Until it wont anymore due to "impossible states" that start to show: usually at random, at some devices, for some users - as our app grew. Unit tests can't catch intertwined state transitions. Integration tests are asynchronous, so they shall, but all run on our machines: with proverbial "here it works" results. Then we bloat code with more monitors hoping to catch culprit in the wild. Nope. Surrounded by monitors heisenbug hides well... Its manifestation depends of some async changes coming in exact "triggering" order we did not anticipated in our mental model of the App._

_Then "go Reactive" comes to mind. You `copyWith` then hand over immutable snapshot of the whole relevant state. Easy-peasy: 30 + 30 lines of copying constructor here, 20+20 there. Sounds generous, erm. generativable, ain't it?  Then you realize that this very part that makes these copies still must internally do state transitions.  Plus, to have any form of feedback, it must either keep a local reference to each sent and not yet spent copy or run on a closures mill. So 30+30 here, 20+20 there and you just moved heisenbugs' den from the back of the dark cellar to its corner._
-->
