**Toggler** manages App state booleans: with easy state transitions, pre-commit state validation, and post-commit change notifications.

**Toggler** object keeps state of up to 63 boolean values (items) that can be manipulated one by one or in concert. _Radio group_ behaviour can be declared on up to 20 separated groups of items. Independent _disabled_ property is avaliable for every item – to be used from within UI builders.

**Toggler** was designed specifically for singleton _Models_ and for _observer_ style state flows, though it can also be used in _reactive_ state management architectures via its `state` and `clone` copying constructors.  For safe use within a singleton _Model_ Toggler has built-in data race detection and automatically skips changes coming from an outdated ancestor state.

Toggler is a single class library with no dependencies.

## Getting started

 1. `$> dart pub get toggler`
 1. import toggler for your Model: `import 'package:toggler/toggler.dart';`
 2. declare meaningful names for your knobs:
 ```Dart
     const kTG_Turn = 0; // min Toggler item index
     const kTG_Claim = 1; // ...
     const kTG_Prized = 62; // max Toggler item index
 ```
 4. add a ChangeNotifier `final fchg = ChangeNotifier<int>(0)` to your Model
 4. add Toggler `final flags = Toggler(notify: (Toggler _, Toggler n) => fchg.value = n.serial);`
 4. wire it to your UI code (_example with [get_it_mixin](https://pub.dev/packages/get_it_mixin)_):

```Dart
  // ...somewhere in your Widget tree:
  Widget build(BuildContext context) {
    final flags = getX((Model m) => m.flags);
    watchX((Model m) => m.fchg);
    // ...
    return flags[kTG_Turn] // somewhere in build
      ? const IconYou(...)
      : const IconOpponent(...),
            // ... disable ClaimPrizeButton unless Prized is set
            onPressed: flags.active(kTG_Prized)
              ? () => flags.set(kTG_Claim)
              : null,
```


## API 101

constructors:
- `Toggler({fix: onChange, notify: afterChange, tg: 0, ds: 0, rm: 0, hh: 0})`
  > at least `notify` is needed to make a _live_ Toggler. All other members can be given to default constructor, too - used eg. in saved state deserializer and tests. An all-default Toggler can be mutated at will, eg. in an explicit App state initializer, then `notify` and/or `fix` handlers can be attached later.
- `Toggler.state()` returns a copy of _state_ only (ie. with `fix` = `notify` = null).
- `Toggler.clone()` returns a deep copy of `this`. _Caveat emptor!_

getters:
- `[i]` returns state of item at index i (_true_ for a set item).
- `active(i)` returns negation of _disabled_ property of item at index i.

setters:
- `toggle(i)`, `set(i)`, `clear(i)`, `setTo(i, state)`
  > mutate a single item state at index i.
- `toggle(i, ifActive: true)`, `set(i, ifActive: true)`, `...`
  > item state setters may depend on _disabled_ property.
- `enable(i)`, `disable(i)`, `setDS(i, state)`
  > mutate _disabled_ property of item at index i.

state tests:
- `recent` is index of a latest singular change.
  > In a `fix` function this means change that fired it.
- `serial` is a monotonic state serial number (45b), bigger is newer
- `isOlderThan(other)` compares serial numbers of state copies.
  > Any _live_ object always is newer than any other Toggler object.
- `anyInSet({first = 0, last = 62})`
  > returns _true_ if any value in _first..last_ range is _set_.
- `differsFrom(other, {first = 0, last = 62})`
  > compares both value and _disabled_ property of _this_ and _other_ item in _first..last_ index range. Returns _true_ if any in range differs.

diagnostics:
- `error`
  > set to _true_ if any Toggler method taking `i` index number got it out of valid range 0..62.
- `race`
  > set to _true_ if `fix` of older generation state tried to update a _live_ object, eg. after `fix` being suspended by await. Such state is never commited, but it is signalled by a `race` flag set (_test_ builds asserts and throw on both `error` and `race`).
- `done`
  > flag used in _reactive_ state managnment diagnostics to signal that state copy object was already used (eg. to build a subtree). Copy or clone of an already _done_ copy will have `done` flag cleared automatically. State transition of `fix` handler may set `done` on a _newState_ to signal that `notify` is not needed after new state commit.

radio group setup:
- `radioGroup(first, last)`
  > makes items in _first..last_ range be dependent on each other, so if one is set any other in group will be cleared automatically. Up to 20 groups can be defined - a single group per each `radioGroup` call. RadioGroup ranges may not overlap nor be adjacent.

serialize:
- Toggler intentionally has no `toString` method, nor

### State flow

1. somewhere in your App code: a state of a single item in a _live_ Toggler in Model is changed
2. State transition function `bool fix(oldState, newState)` is called (if `fix` was given)
3. New state is commited to the _live_ object (`fix` returned _true_, or is not present)
4. Notifier `notify(oldState, liveState)` is called (if newState from `fix` is not already `done`)

If `fix(oldState, newState)` function has not been provided, a single item change made by setter is commited immediately. Otherwise `fix` is called after every single change coming from setter methods. Your code there may manipulate _newState_, or even assign a some predefined const values to the `tg` and/or `ds` properties. Then `fix` returns _true_ to have _newState_ commited; or _false_, would changes be abandoned.

Then, if new state has been commited, the `notify(oldState, current)` function (you provided) is called. Within your `notify` handler you may selectively check where changes were made using `differsFrom(oldState, rangeFirst, rangeLast)` helper, then subsequently fire your chosen state passing machinery (eg. updating InheritedWidget state, feeding an EventObserver, pushing a cloned object to the Rx sink, or - authors' preffered - just copy `serial` of a new state to the [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html).value that is observed in the **stateless** widgets tree using [get_it_mixin](https://pub.dev/packages/get_it_mixin))
