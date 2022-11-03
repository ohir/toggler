**Toggler** is an observable state machine register. It orchestrates state transitions, validation, and finally it may notify observers of a just commited state change.

**Toggler** instance may keep up to 52 boolean values (bits, flags, items) that can be manipulated one by one or in concert.

For direct use in ViewModels of _Flutter_ UI **Toggler** provides an independent _disabled_ property for each of state register bits and supports "radio grouping" among adjacent two or more of them.

**Toggler** was designed for MVVM and similar newer architectures with unidirectional flow of state changes. It was specifically tailored for safe use with singleton _Models_.
With ultimate goal of it being as safe as _Reactive_ setups but without hundreds of boilerplate _copyWith_ constructors for user to write.

Toggler is a single concrete class library with no dependencies.

Test coverage: `100.0% (200 of 200 lines)`

## Why should I use this for app state managnment?

TL;DR State machines, ie. _Models_, built on Toggler promise to be fully testable, as **all** state transitions within are dealt with by a **synchronous** code of "state fixers".  Async things that in app will _signal_ Toggler can be mocked at ease and both their signals and their values permuted at will at test time - **reproducibly** on a **predictable** schedule.

Will Toggler deliver on this promise? Time will tell. That's a fresh idea and fresh code.

Longer story at end of README

## When should I use this?

If you know your app functionality will only grow.


## Observable State Register?

Its simple:
1. every _bit_ of a register reflects _something_ (an item) that may change in your _Model_.
2. if that _item_ changes, it _signals_ register about change: just with its given (at birth) bit _index_. If _item_ happens to be a boolean value, it can just be set, or toggled directly at the register, that also can be a _signal_.
3. copy of a current register along with _signal_ bit position is then passed to the state machine _fixer_ realizing some business-logic for the _Model_.
4. fixer, knowing who changed from _signal_, may inspect content of the _item_ then may flip, set, or clear respective bit of register to accept (or decline) signalled change.
5. Fixer can also initiate change of other _items_, if state transition schema so mandates. Then bits of these other _items_ will also be toggled, set, or cleared.
6. Finally, realized by fixer state machine arrives at its prescribed next stable state, new content of the register is compared to the previous, diff made, then this diff is exposed to the _outer world_. Eg. pushed to a _notifier_.

Observers from the _outer world_ seeing this diff (changed-bits signal) may decide whether the recent changes are of any interest to them. Simply with filtering coming diff with a bitmask.

## Getting started

_Note: item, flag, bit (of Toggler) are used interchangeably in docs._

 1. `$> dart pub get toggler` (for CLI)
 1. `$> dart pub get uimodel` (for Flutter GUI binding)
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
     flags.set1(bTurn); // or flags[bTurn] = true;
     flags.clear(bPrize); // or flags[bPrize] = false;
     if (flags[bTurn] && didUserWon()) flags.set1(bPrize);
     void claim() => flags.toggle(bClaim);
     String get result => flags[bPrize] ? 'Your Prize!' : 'Try again!';
 ```
_See toggler_example.dart for Toggler basics (and possible Toggler extensions)._

For _Flutter_ apps use there is a thin wrapper around Toggler called [UiModel](https://pub.dev/packages/uimodel) that allows UI Views be wired to a Toggler based singleton Models (ViewModels) by just two lines of code - first in Model, second in Widget's `build`:
```Dart
// make a Model (ViewModel):
class ViewModel with UiModel { // (0) now your ViewModel has a Toggler
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
    watches(m, sTurn | sPrize)); // (0, 2, 5) observe these pieces of Model
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

1. `Toggle` setter changes a **single** state bit, (here one at `bName` index), this change is put on a `newState` object that is a _state copy_ of the Toggler, but with _bName_ bit toggled. A verbatim _state copy_ is taken as _oldState_, then both are passed to the state transition handler `fix(oldState, newState)`. The `fix` handler is the "business logic" function provided by you.
2. `Fix` may test, validate and change _newState_ further, eg. setting the _bNameHintReceived_ flag, and clearing _bWaitingForNameHint_ one. When new state is properly set, `fix` returns _true_.
3. then the _newState_ is commited to the Toggler, ie. it becomes its current (aka _live_) state. This is a state that outer world sees.
4. Next, the `after(oldState, liveState)` handler (also provided by you) runs. It may not change anything further, but it may decide whether the outer world should know about the changes. If so, it may notify others by itself, then/or pass baton to the
5. `notifier` object that informs its subscribers, if it has any. If there is no `after` handler installed, and `notifier` object is, its _pump(changes)_ method runs automatically on commit.
6. World is notified, so it may react: the View layer may hide a progress spinner and show an edit field filled with just received _NameString_, background connection to the hint service may observe _bNameHintReceived_ then close, and so on.
7. -> 1. State machine will run again at the next change that registers in Toggler.

<!--
-->
### API DTL;DR

You should read at least `fix` docs to make any serious use of Toggler.
Skim over a below included api cheat-sheet for the rest.

#### constructor:
```Dart
Toggler({
  fix? = onChange(oldState, newState) handler, 
  after? = afterChange(oldState, liveState) handler,
  notifier? = ToggledNotifier(),
  bits: 0, ds: 0, rg: 0, hh: 0, chb: 0, // internal registers are public too
})
```
- at least one state transition handler is needed to make a _live state_ Toggler. All other members can be given to default constructor, too - used eg. in saved state deserializer and tests. An all-defaults Toggler can be mutated at will, eg. in an explicit App state initializer. The `fix`, `after`, and `notifier` handlers can be attached later.
- your code in `fix` may manipulate _newState_ at will, it even may assign a some predefined const values to the `bits` and/or `ds` properties of it. Usually `fix` is a Model's internal function so it may have access to all other pieces of your business logic (and/or of ViewModel logic).
- your code in `after` may decide whether `notifier` should run, it may also do notifications by itself. Eg. if your legacy Widget code builds of StreamBuilder, `after` may feed the Stream just for it - passing the rest to the `notifier`.
- a `notifier` object usually comes from an associated library, but it can also be yours.

#### factories:
- `clone()` returns a _deep copy_ of `this`, handlers including. _Caveat emptor!_
- `state()` returns a _copy of state_ only. Ie. _bits_, _ds_, _hh_, and _rg_.
  Other fields are at default, no handlers, no notifier.

#### getters:
- `[i]` returns state of item bit at index i (_true_ for a set1 item).
- `active(i)` returns negation of _disabled_ property of item at index i.

#### setters:
- `[i]=` sets state of item bit at index i
- `toggle(i)` flip state of item bit at index i
- `set1(i)`, `set0(i)`, `setTo(i, state)` change a single item bit value at `i` index
- `enable(i)`, `disable(i)`, `setDS(i, state)` mutate _disabled_ property of an item
- `set1(i, ifActive: true)`, `...` bit setters may depend on a _disabled_ property
- `signal(i)` does not change state bits by itself but informs that some change was made
  and likely it should be reflected at bit i, possibly after some checks.

#### state fixer:
- `fixBits(i, value)`, `fixDs(bIndex, value)` non-registering setters
- `fixSignals(i, value)` supress or force a changed-bit signal (for fix only)

#### state tests:
- `chb` property has bits set to 1 at positions that recently changed state
- `recent` is index of a latest singular state bit change that came from a setter
- `serial` is a monotonic state serial number (35b), bigger is newer
- `changed(selmask)` tells if there was a change on any of _selmask_ positions
- `changedAt(bIndex)` tells if there was a change at _bIndex_
- `anyOfSet({first, last, selmask})` _true_ if any item bit is set in range or by selmask
- `differsFrom(other, {first, last, selmask})` compares this and other state (bits, ds)
- `isOlderThan(other)` compares serial numbers of this and other

#### diagnostics:
- `v` internally verifies index (as given to any of methods)
- `vma` internally verifies mask (as given to any of methods)
- `error` _true_ if in release build Toggler method got a wrong index
- `done` _true_ if set by your App code. Cleared at every new change.
- `held` _true_ if changes to state register were supressed by `hold()`,
  _false_ if changes are allowed, ie. after a call to `resume()`

#### radio group setup:
- `radioGroup(first, last)` If one in given range is set, others are cleared automatically.

#### serialize:
Toggler intentionally has no `toString` nor `toJSON` methods. Its whole state is public and consist of just four _ints_. It should be handled seamlessly by any serialization method one may have chosen for a whole _Model_.


## the price tag

Toggler based Models use indice and masks.  Named for the sake of humans, but just numbers to the code. Naming numbers is a one-time chore supported by included const file generator. So, if your App/Model state machine can be represented on up to 52 bits, you're set.

But If 52 is not enough, or you want to work with many submodels there is a caveat: while names will be unique, index numbers and masks will not.

It then may happen that you inadverently pass a name meant for submodel A, to the submodel B, or C. As Toggler code sees only numbers it will act on these not knowing that `const bPrecise = 7` meant for `Measure` submodel came to the `Storage` submodel where index 7 is a `bDeleteAll` action flag.

This could be vetted in the base code, but then Toggler core would no longer be simple nor fast. Hence validating and correcting index/mask numbers (per an instance) deliberately were left to the possible subclasses: both index verifier `v` and mask verifier `vma` are public and can be overriden to suit a particular need.

For the practical usage a simpler solution exists that wastes no cpu cycles and works for many submodels as well:

### Toggler naming conventions

1. index name starts with `b` (bit), mask name starts with `s` (select mask)
2. then the _ChosenName_ comes (`bChosenName`, `sChosenName`)
3. for a single Toggler in use - thats all.
4. if there are more Toggler based submodels in your Model, each of them and its bits names are given the same capital letters suffix, eg: `watches(m.toppartBX, sRenamedBX | sSavedBX);` (`watches` from [uimodel]).

_Follow the convention. Then if not you visually at writing, your linter later may spot that the ending of a parameter name does not match the suffix of the name of the receiving object and warn you accordingly_.


### hints, traps, and remedies

- This library is synchronous so your handler methods should complete fast. Any interface with async code should be done via a proper state cycle (eg. in a separate Isolate). Ie. while your async code may easily register in Toggler, you should pass any changes back only using a `notifier`.

- While `fix` runs the live Toggler state is on [hold]. It means that any further direct changes to the register are forbidden. Signals though work, so if your `fix` code mutates an external item that normally signals register about a change, this signal will come and it will be reflected at the _changed bits_ outgoing signal (unless you supress it within the `fix` handler).

#### promised longer intro

_Any and every app IS-A state machine. With Dart async code it is hard to have a predictable and testable state machine encompassing a big app, like a tax filling tool. We usually deal with state transitions complexity by isolating and chopping functionality to smallest possible pieces, ones that transit just a few bits of state. Then we do a patchwork of them to get at envisioned user experience._

_This approach usualy works. Until it wont anymore due to "impossible states" that starts to show: usually at random, at some machines, for some users - as our app grew. Unit tests can't catch intertwined state transitions. Integration tests are asynchronous, so they shall, but all run on our machines - so "here it works". Then we bloat code with more monitors hoping to catch culprit in the wild. Nope. Surrounded by monitors heisenbug hides well..._
