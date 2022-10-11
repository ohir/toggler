**Toggler** is an observable state machine register. It orchestrates state transitions, validation, and finally it may notify observers of a just commited state change.

**Toggler** instance may keep up to 52 boolean values (bits, flags, items) that can be manipulated one by one or in concert.

For direct use in ViewModels of _Flutter_ UI **Toggler** provides an independent _disabled_ property for each of state register bits and supports "radio grouping" among adjacent two or more of them.

**Toggler** was designed for MVVM and similar newer architectures with unidirectional flow of state changes. It was specifically tailored for safe use in singleton _Models_, guaranteeing that changes coming from an outdated ancestor state will be detected and automatically skipped. Yet it may also be used in _reactive_ state management architectures, having the `clone` method.

Toggler is a single concrete class library with no dependencies.

Test coverage: `100.0% (156 of 156 lines)`

## Getting started

_Note: item, flag, bit (of Toggler) are used interchangeably in docs._

 1. `$> dart pub get toggler` (for CLI)
 1. `$> dart pub get uimodel` (for Flutter GUI binding)
 2. import toggler: `import 'package:toggler/toggler.dart';`
 3. declare meaningful names for your flags/items/bits:
 ```Dart
     const biTurn = 0; //           item index
     const smTurn = 1 << biTurn; // item select bitmask
     const biClaim = 1;
     const smClaim = 1 << biClaim;
     const biPrize = 2; // ...
 ```
 4. instantiate and use
 ```Dart
     final flags = Toggler(fix: ourStateFixer, after: ourAfterHandler);
     // ...
     flags.set1(biTurn); // or flags[biTurn] = true;
     flags.clear(biPrize); // or flags[biPrize] = false;
     if (flags[biTurn] && didUserWon()) flags.set1(biPrize);
     void claim() => flags.toggle(biClaim);
     String get result => flags[biPrize] ? 'Your Prize!' : 'Try again!';
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
//     -> Model changes; if fix toggles biTurn or biPrize ->
// (5) rebuild on either smTurn or smPrize change notification
  Widget build(BuildContext context) { // (0, 5)
    final m = ViewModel(); // (1) get singleton Model with UiModel
    watches(m, smTurn | smPrize)); // (0, 2, 5) observe these pieces of Model
    // Here View knows M and knows when M changes Turn and/or Prize...
      // it can read and use data from Model...
      Text('${m[biPrize] ? m.prize : 'Try again!'}'), // (3)
        // Here unidirectional state flow both begins and completes:
        m[biPrize] // (3)
          ? MyButton('Claim Prize!', onPressed: m.claim), // (0) (4)
          : MyButton('Dice Roll', onPressed: m.droll), // (0) (4)
```
_See example/flutter_example.dart for a complete app code._


### the App state flow

> Pre: Some property in your Model is mutated, eg. a background service just hinted Model with a new _NameString_. NameString setter then registers state change in Model's internal Toggler, eg. by calling `signal(biName)`. Then:

1. `Toggle` setter changes a **single** state bit, (here one at `biName` index), this change is put on a `newState` object that is a _state copy_ of the Toggler, but with _biName_ bit toggled. A verbatim _state copy_ is taken as _oldState_, then both are passed to the state transition handler `fix(oldState, newState)`. The `fix` handler is the "business logic" function provided by you.
2. `Fix` may test, validate and change _newState_ further, eg. setting the _biNameHintReceived_ flag, and clearing _biWaitingForNameHint_ one. When new state is properly set, `fix` returns _true_.
3. then the _newState_ is commited to the Toggler, ie. it becomes its current (aka _live_) state. This is a state that outer world sees.
4. Next, the `after(oldState, liveState)` handler (also provided by you) runs. It may not change anything further, but it may decide whether the outer world should know about the changes. If so, it may notify others by itself, then/or pass baton to the
5. `notifier` object that informs its subscribers, if it has any. If there is no `after` handler installed, and `notifier` object is, its _pump(changes)_ method runs automatically on commit.
6. World is notified, so it may react: the View layer may hide a progress spinner and show an edit field filled with just received _NameString_, background connection to the hint service may observe _biNameHintReceived_ then close, and so on.
7. -> 1. State machine will run again at the next change that registers in Toggler.


## API 101

#### constructors:
```Dart
Toggler({
  fix? = onChange(oldState, newState) handler, 
  after? = afterChange(oldState, liveState) handler,
  notifier? = ToggledNotifier()
  // bits: 0, ds: 0, rm: 0, rg: 0, chb: 0, hh: 0 // internals are exposed too
})
```
- at least one state transition handler is needed to make a _live state_ Toggler. All other members can be given to default constructor, too - used eg. in saved state deserializer and tests. An all-default Toggler can be mutated at will, eg. in an explicit App state initializer. The `fix`, `after`, and `notifier` handlers can be attached later.
- your code in `fix` may manipulate _newState_ at will, it even may assign a some predefined const values to the `bits` and/or `ds` properties of it. Usually `fix` is a Model's internal function so it may have access to all other pieces of your business logic (and of ViewModel logic).
- your code in `after` may decide whether `notifier` should run, it may also do notifications by itself. Eg. if your legacy Widget code builds of StreamBuilder, `after` may feed the Stream for it.
- a `notifier` object usually comes from an associated library, but it can also be yours.

#### factories:
- `state()` returns a _copy of state_ only (`fix`, `after`, `notifier` are null).
- `clone()` returns a _deep copy_ of `this`. _Caveat emptor!_

#### getters:
- `[i]` returns state of item at index i (_true_ for a set item).
- `active(i)` returns negation of _disabled_ property of item at index i.

#### setters:
- `[i]=` sets state of item at index i
- `set1(i)`, `clear(i)`, `setTo(i, state)` change a single item value at `i` index
- `enable(i)`, `disable(i)`, `setDS(i, state)` mutate _disabled_ property of an item.
- `set1(i, ifActive: true)`, `...` setters may depend on a _disabled_ property.

#### state tests:
- `chb` property has bits set to 1 at positions that recently changed state
- `recent` is index of a latest singular change coming from setter.
- `serial` is a monotonic state serial number (35b), bigger is newer
- `isOlderThan(other)` compares serial numbers of state copies.
- `changedAt(bIndex)` tells if there was a change at _bIndex_.
- `changed(selmask)` tells if there was a change on any of _selmask_ positions
- `anyOfSet({first, last, selmask})` _true_ if any item is set in range or by selmask
- `differsFrom(other, {first, last, selmask})` compares this and other state

#### diagnostics:
- `v` internally verifies index (as given to any of methods)
- `vma` internally verifies mask (as given to any of methods)
- `error` _true_ if in release build Toggler method got a wrong index
- `race` _true_ if `fix` of older generation tried to update a newer object
- `done` _true_ if set by your App code. Cleared at every new change.

#### radio group setup:
- `radioGroup(first, last)` If one in given range is set, others are cleared automatically.

#### serialize:
Toggler intentionally has no `toString` nor `toJSON` methods. Its whole state is public and consist of just four _ints_. It should be handled seamlessly by any serialization method one may have chosen for a whole _Model_.


## the price tag

Toggler based Models use indice and masks.  Named for the sake of humans, but just numbers to the code. Naming numbers is a one-time chore supported by included const file generator. So, if your App/Model state machine can be represented on up to 52 bits, you're set.

But If 52 is not enough, or you want to work with many submodels there is a caveat: while names will be unique, index numbers and masks will not.

It then may happen that you inadverently pass a name meant for submodel A, to the submodel B, or C. As Toggler code sees only numbers it will act on these not knowing that `const biPrecise = 7` meant for `Measure` submodel came to the `Storage` submodel where index 7 is a `biDeleteAll` action flag.

This could be vetted in the base code, but then Toggler core would no longer be simple nor fast. Hence validating and correcting index/mask numbers (per an instance) deliberately were left to the possible subclasses: both index verifier `v` and mask verifier `vma` are public and can be overriden to suit a particular need.

For the practical usage a simpler solution exists that wastes no cpu cycles and works for many submodels as well:

### Toggler naming conventions

1. index name starts with `bi` (bit index), mask name starts with `sm` (select mask)
2. then the _ChosenName_ comes (`biChosenName`, `smChosenName`)
3. for a single Toggler in use - thats all.
4. if there are more Toggler based submodels in your Model, each of them and its bits names are given the same capital letters suffix, eg: `watches(m.toppartBX, smRenamedBX | smSavedBX);` (`watches` from [uimodel]).

_Follow the convention. Then if not you visually at writing, your linter later may spot that the ending of a parameter name does not match the suffix of the name of the receiving object and warn you accordingly_.


### traps and remedies

- This library is synchronous so your handler methods must complete fast. Any interface with async code should be done via a proper state cycle and in a separate Isolate.

- While fixing state you must either avoid calling your Model setters that would subsequently register in this very Toggler (effecting in an internal race, or worse: a loop). If you can't avoid it, you should get the live object on `hold` before such mutation then `resume` it after (at last before returning from `fix`).
