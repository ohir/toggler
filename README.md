**Toggler** manages App booleans: with easy pre-commit state validation, cross-dependent state mutation, then post-commit change notifications.

## Features

**Toggler** object keeps state of up to 63 boolean values (items) that can be manipulated one by one or in concert. _Radio group_ behaviour can be declared on up to 20 separated groups of items. Independent _disabled_ flag is avaliable for every item – to be used from within UI builders.

**Toggler** was designed specifically for singleton _Models_ and for _observer_ style state flows, though it can be used also in _reactive_ state management architectures via its `state` and `clone` copying constructors.  For safe use within a singleton _Model_ Toggler has built-in data race detection and automatically skips changes coming from an outdated ancestor state.

Toggler is a single class library with no dependencies.

## Getting started

 1. `$> dart pub get toggler`
 1. Then import toggler for your Model: `import 'package:toggler/toggler.dart';`
 1. declare `const kTG_flagName`s that next will be used to give your knobs and their _Model_ representation clear meaning:
 ```Dart
     const kTG_NetConnected = 0;
     const kTG_freeUser = 1;
     const kTG_LoggedIn = 2;
     const kTG_NoBanners = 3;
     const kTG_NoInterst = 4;
     // ...
     const kTG_Claim = 61;
     const kTG_Prized = 62; // Single Toggler object keeps up to 63 items (flags)
 ```
 4. make a Toggler `var flags = Toggler();`
 5. use Toggler API:

(_example with [get_it_mixin](https://pub.dev/packages/get_it_mixin)_)
```Dart
  // somewhere in common code declare flag symbolic names:
     const kTG_Turn = 0; // min item index
     const kTG_Claim = 11;
     const kTG_Prized = 62; // max item index
  // ...somewhere in model.dart:
  final flchg = ValueNotifier<int>(0); // rebuild kicker
  void chn(Toggler _, Toggler n) => flchg.value = n.hh));
  final flags = Toggler(notify: chn);
  // ...somewhere in Widget tree:
  Widget build(BuildContext context) {
    final flags = getX((Model m) => m.flags);
    watchX((Model m) => m.flchg);
    // ...somewhere in Widget build:
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
- `Toggler(checkFix: beforeChangeCommit, notify: afterChangeCommit)` other properties can be set too just obeing KWAYD (know what you are doing) principle - usually members are set by deserializer, and in testing. Toggler with non-null `notify` field is said to be a _live_ Toggler object.
- `Toggler.state()` returns _non-live_ copy of the state, ie. object with both `checkFix` and `notify` fields set to null.
- `Toggler.clone()` returns full copy of object, ie. cloned _live_ Toggler will still be _live_. This constructor is of use in very simple apps with a single InheritedWidget as state managenment solution.

getters:
- `[i]` returns state of item at index i (_true_ for a set item).
- `active(i)` returns !_disabled_ property of item at index i.

setters:
- `toggle(i)`, `set(i)`, `clear(i)`, `setTo(i, state)` mutate a single item state at index i
- `toggle(i, ifActive: true)`, `set(i, ifActive: true)`, `...` state setters may depend on _disabled_ property, on demand.
- `enable(i)`, `disable(i)`, `setDS(i, state)` mutate item's at index i _disabled_ property

state tests:
- `anyInSet({first = 0, last = 62})` returns _true_ if any value in first..last range is _set_.
- `differsFrom(other, {first = 0, last = 62})` compares items values and _disabled_ state, in first..last index range. Returns _true_ if any value in range or its _disabled_ property is not equal to the same index value in _other_.
- `isOlderThan(other)` compares state serial numbers
- `serial` monotonic state serial number, bigger is newer

diagnostics:
- `error` set to _true_ if a Toggler method taking index got it out of 0..62 range.
- `race` set to _true_ if `checkFix` of older generation state tries to update newer _live_ object, eg. after being internally suspended by await for a while. Such state is never commited, but it is signalled by `race` set in _release_ build - in _debug_ builds both `error` and `race` are subject to an assertion, so both throw immediately.
- `done` flag can be used in _reactive_ state managnment diagnostics to signal that state copy object was already used (eg. to build a subtree). Copy or clone of an already _done_ copy will have `done` flag zeroed automatically. Done may not be set on a _live_ Toggler object.

radio group setup:
- `radioGroup(first, last)`

### State changes flow

After a single item state was changed by setter, the `checkFix(oldState, newState)` function (you provided) is called. Your code there may manipulate whole _newState_ using above methods, or even assigning some predefined const values to the `tg` and/or `ds` properties. Then `checkFix` returns _true_ to have _newState_ commited (or _false_, would changes be abandoned). If no `checkFix` is given, a single item change made by setter is commited immediately.

Then, if new state has been commited the `notify(oldState, current)` function (you provided) is called. Within your `notify` handler you may selectively check where changes were made using `differsFrom(oldState, rangeFirst, rangeLast)` helper, then subsequently fire your chosen state passing machinery (eg. updating InheritedWidget state, feeding an EventObserver, pushing a cloned object to the Rx sink, or - authors' preffered - just copy the `hh` of a new state to the [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html).value that is observed in the **stateless** widgets tree using [get_it_mixin](https://pub.dev/packages/get_it_mixin))

- `flags.set(kTG_freeUser);` set 'freeUser' to _true_ ("on", "set");

- `if (flags[kTG_freeUser]) {...}` test item state using `operator[]`

- `flags.disable(kTG_freeUser);` UI code may then check whether a flag is Active and decide whether to enable some Button

- `... onPressed ? flags.isActive(kTG_freeUser) ? () {...} : null,`

- `flags.clear(kTG_freeUser, ifActive: true);`
