**Toggler** manages App state booleans: with easy state transitions, pre-commit state validation, and post-commit change notifications.

**Toggler** object keeps state of up to 52 boolean values (items) that can be manipulated one by one or in concert. _Radio group_ behaviour can be declared on up to 17 separated groups of items. Independent _disabled_ property is avaliable for every item – to be used from within UI builders.

**Toggler** was designed specifically for singleton _Models_ and for _observer_ style state flows, though it can also be used in _reactive_ state management architectures via its `state` and `clone` copying constructors.  For safe use within a singleton _Model_ Toggler has built-in data race detection and automatically skips changes coming from an outdated ancestor state.

Toggler is a single class library with no dependencies.

Test coverage: `100.0% (133 of 133 lines)`

## Getting started

 1. `$> dart pub get toggler`
 1. import toggler for your Model: `import 'package:toggler/toggler.dart';`
 2. declare meaningful names for your knobs:
 ```Dart
     const flagTurn = 0; // min Toggler item index
     const flagOther = 1; // ...
     const flagClaim = kTGindexMax; // max Toggler item index (52 or 63)
 ```
 4. add a ValueNotifier `final fchg = ValueNotifier<int>(0)` to your Model
 4. add Toggler `final tog = Toggler(notify: (Toggler _, Toggler n) => fchg.value = n.serial);`
 4. wire it to your UI code (_example with [get_it_mixin](https://pub.dev/packages/get_it_mixin)_):

```Dart
  // ...somewhere in your Widget tree:
  Widget build(BuildContext context) {
    final tog = getX((Model m) => m.tog);
    watchX((Model m) => m.fchg);
    // ...
    return tog[flagTurn] // somewhere in build
      ? const IconYou(...)
      : const IconOpponent(...),
            // ... ClaimPrize is shown disabled unless active
            onPressed: tog.active(flagClaim)
              ? () => tog.toggle(flagClaim)
              : null,
```

### State flow

1. somewhere in your App code a state of a single item in a _live_ Toggler in Model is changed by a `toggle(flagName)` call (or other _state setters_: `set`, `clear`, `enable`, `disable`).
2. State transition function `bool fix(oldState, newState)` is called next,
3. then "fixed" new state is commited to the state of Toggler instance,
4. then `notify(oldState, liveState)` is called, there Model's _ValueNotifiers_ can be updated or _notifyListeners_ called to pass "changed" baton to the Presentation layer.

If `fix` handler has not been provided, any single item change made by setter is commited immediately. Otherwise `fix` is called with _newState_ reflecting change that came from a setter. Then `fix` returns _true_, to have _newState_ commited; Or _false_ for changes to be abandoned.

Your code in `fix` may manipulate _newState_ at will, it even may assign a some predefined const values to the `tg` and/or `ds` properties of it. Usually `fix` is Model's internal function, so it may have access to all other pieces of your business logic.

After succesful new state commit `notify` is called. Within this handler you may selectively check where changes were made, eg using `recent` index, or `differsFrom(oldState, rangeFirst, rangeLast)` helper. Then you may run your chosen state passing machinery (Eg. update InheritedWidget state, feed an EventObserver, push a cloned object to the Stream...).
> Toggler author's preffered mechanics: copy `serial` of a new state to the [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html).value that is observed in the **stateless** widgets tree using [get_it_mixin](https://pub.dev/packages/get_it_mixin)).


### API 101

#### constructors:
- `Toggler({fix: onChange, notify: afterChange, tg: 0, ds: 0, rm: 0, hh: 0})`
  > at least `notify` is needed to make a _live_ Toggler. All other members can be given to default constructor, too - used eg. in saved state deserializer and tests. An all-default Toggler can be mutated at will, eg. in an explicit App state initializer, then `notify` and/or `fix` handlers can be attached later.
- `state()` method returns a _copy of state_ only (ie. with `fix` = `notify` = null).
- `clone()` method returns a deep copy of `this`. _Caveat emptor!_

#### getters:
- `[i]` returns state of item at index i (_true_ for a set item).
- `active(i)` returns negation of _disabled_ property of item at index i.

#### setters:
- `toggle(i)`, `set(i)`, `clear(i)`, `setTo(i, state)`
  > mutate a single item state at index i.
- `toggle(i, ifActive: true)`, `set(i, ifActive: true)`, `...`
  > item state setters may depend on _disabled_ property.
- `enable(i)`, `disable(i)`, `setDS(i, state)`
  > mutate _disabled_ property of item at index i.

#### state tests:
- `recent` is index of a latest singular change.
  > In a `fix` function this means change that fired it.
- `serial` is a monotonic state serial number (34b), bigger is newer
- `isOlderThan(other)` compares serial numbers of state copies.
  > Any _live_ object always is newer than any other Toggler object.
- `anyInSet({first = 0, last = kTGindexMax})`
  > returns _true_ if any value in _first..last_ range is _set_.
- `differsFrom(other, {first = 0, last = kTGindexMax})`
  > compares both value and _disabled_ property of _this_ and _other_ item in _first..last_ index range. Returns _true_ if any in range differs.

#### diagnostics:
- `error`
  > set to _true_ if any Toggler method taking `i` index number got it out of valid range 0..max.
- `race`
  > set to _true_ if `fix` of older generation state unsuccesfully tried to update a _live_ object, eg. after `fix` being suspended by await.
- `done`
  > can be set by your App code to signal that changes were seen/used. This flag is automatically cleared on every new change.

#### radio group setup:
- `radioGroup(first, last)`
  > makes items in _first..last_ range be dependent on each other, so if one is set any other in group will be cleared automatically. Up to 17 separate groups can be defined - a single group per each `radioGroup` call. RadioGroup ranges may not overlap nor be adjacent.

#### serialize:
- Toggler intentionally has no `toString` nor `toJSON` methods. Its whole state is public and consist of just four _ints_. It should be handled seamlesslly by any serialization method one may have chosen for a whole _Model_.

#### state serial overflow:
- Serial counter will overflow once per 16 billion changes. It is 500 years of once per second user taps, 9 years of per-frame toggles @60fps, or 6 months of counting every network frame @12Mbps. If overflow happens, the `isOlderThan` method may lie comparing state copies made before and after overflow. (_IOW: it may concern you if you use _reactive_ style state management __and__ use serial as identity-age sentinel __and__ your code is meant to work 24/365. Then you may consider resetting `hh` to 0 at suitable moments eg. when your input queque empties_).
