**Toggler** manages App state booleans: with easy state transitions, pre-commit state validation, and post-commit change notifications.

**Toggler** object keeps state of up to 52 boolean values (items, flags, bits) that can be manipulated one by one or in concert. _Radio group_ behaviour can be declared on up to 17 separated groups of items. Independent _disabled_ property is avaliable for every item – to be used from within UI builders. If 52 is not enough, Togglers can be used in paralel or even be cascaded.

**Toggler** was designed for MVVM and similar newer architectures with unidirectional flow of state changes. It was specifically designed for safe use in singleton _Models_, though it can also be used in _reactive_ state management architectures (it has a `clone` method). Built-in data race detection may automatically skip changes coming from an outdated ancestor state.

Toggler is a single concrete class library with no dependencies.

Test coverage: `100.0% (162 of 162 lines)`

## Getting started

 1. `$> dart pub get toggler`
 2. import toggler for your Model: `import 'package:toggler/toggler.dart';`
 3. declare meaningful names for your tgKnobs (and their smMasks):
 ```Dart
     const tgTurn = 0; //           item index
     const smTurn = 1 << tgTurn; // item select bitmask
     const tgClaim = 1;
     const smClaim = 1 << tgClaim;
     const tgPrize = 2; // ...
 ```
 4. instantiate and use
 ```Dart
     final flags = Toggler(after: ourAfterHandler, fix: ourStateFixer);
     // ...
     flags.set(tgTurn); //      or flags[tgTurn] = true;
     if (flags[tgTurn]) { ... }
     flags.toggle(tgClaim);
     flags.clear(tgTurn); //    or flags[tgTurn] = false;
     smth = flags[tgClaim] ? 'Got Prize!' : '';
 ```
_See toggler_example.dart for Toggler basics (and possible Toggler extensions)._

There is also a complete Toggler based state manager for Flutter Apps called [UiModel](https://pub.dev/packages/uimodel). With it and [get_it_mixin](https://pub.dev/packages/get_it_mixin) you may seamlessly bind your _Flutter_ Views to your Models and vice versa. It takes just two lines per Widget observing Model:
```Dart
// early on you make a ViewModel:
class ViewModel with UiModel { // so your ViewModel now has a Toggler
} // and register it as a get-it-table singleton
void main() {
   GetIt.I.registerSingleton<ViewModel>(ViewModel());
   runApp(const MyApp()); // then you run your App
}
// ...
// ...deep into the tree, in a stateless widget, stages 1, 2, 3, 4, 5 occur:
// (1) get ViewModel at hand
// (2) bind to change notifications,
// (3) read and use data from Model
// (4) hook actions to Model
//     -> Model changes
// (5) rebuild on either notification
  Widget build(BuildContext context) {
    final m = get<ViewModel>(); // (1)  Two lines, as promised
    watch(target: m(smTurn | smPrize)); // (2), (5)
    // Here View knows M and knows when M changes at Turn or Prize ...
      // it can read data from Model ...
      Text('${m.prize}'), // (3)
        // then it both begins and completes the MVVM flow
        // by hooking actions to Model methods:
        m[tgPrize] // (3)
          ? MyFancyButton(onPressed: m.claim), // (4)
          : MyFancyButton(onPressed: m.droll), // (4)
```
_See example/flutter_example.dart for a complete app code._


### State flow

_Note: item, flag, bit (of Toggler) are used interchangeably in docs._

1. somewhere in your App code you call a setter. Eg. `set(tgName)`,
2. each setter changes state of a **single** item – one at `tgName` index,
4. a state transition handler `fix(oldState, newState)` runs next,
5. (if `fix` returned _true_) then "fixed" state is commited to the Toggler instance,
6. then `after(oldState, liveState)` runs. It may decide whether recent calls for change notifications should be sent to the outer worldt. If yes, it may pass baton to the
7. `notifier` that informs subscribers, if it has any. If there is no `after` handler installed, and `notifier` handler is, it runs automatically.

Your code in `fix` may manipulate _newState_ at will, it even may assign a some predefined const values to the `tg` and/or `ds` properties of it. Usually `fix` is a Model's internal function so it may have access to all other pieces of your business logic (or viewmodel logic).


## API 101

#### constructors:
```Dart
Toggler({
  fix? = onChange handler, 
  after? = afterChange handler,
  notifier? = ToggledNotifier()
  // tg: 0, ds: 0, rm: 0, cm: 0, hh: 0 // internal state is exposed too
})
```
at least one state cycle handler is needed to make a _live_ Toggler. All other members can be given to default constructor, too - used eg. in saved state deserializer and tests. An all-default Toggler can be mutated at will, eg. in an explicit App state initializer. The `after`, or `notifier`, and/or `fix` handlers can be attached later.

#### factories:
- `state()` returns a _copy of state_ only (`fix`, `after`, `notifier` null).
- `clone()` returns a _deep copy_ of `this`. _Caveat emptor!_

#### getters:
- `[i]` returns state of item at index i (_true_ for a set item).
- `active(i)` returns negation of _disabled_ property of item at index i.

#### setters:
- `set(i)`, `clear(i)`, `setTo(i, state)` a single item value at `i` index
- `enable(i)`, `disable(i)`, `setDS(i, state)` mutate _disabled_ property of an item.
- `set(i, ifActive: true)`, `...` setters may depend on a _disabled_ property.

#### state tests:
- `recent` is index of a latest singular change (coming from setter).
- `serial` is a monotonic state serial number (36b), bigger is newer
- `isOlderThan(other)` compares serial numbers of state copies.
- `changed(i?, selmask)` tells if there was a change at _i_ or _selmask_ positions
- `anyInSet({first, last, selmask})` _true_ if any item is set in range or by selmask
- `differsFrom(other, {first, last, selmask})` compares this and other state
- `chb` property has bits set to 1 at positions that recently changed state

#### diagnostics:
- `error` _true_ if in release build Toggler method got a wrong index
- `race` _true_ if `fix` of older generation tried to update a newer object
- `done` _true_ if set by your App code. Cleared at every new change.

#### radio group setup:
- `radioGroup(first, last)` only one flag in range can be set, others then are cleared.

#### serialize:
Toggler intentionally has no `toString` nor `toJSON` methods. Its whole state is public and consist of just four _ints_. It should be handled seamlesslly by any serialization method one may have chosen for a whole _Model_.
