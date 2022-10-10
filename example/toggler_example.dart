// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

import 'package:toggler/toggler.dart';

/// This is a CLI example. Toggler does not depend on Flutter, but is a basis
/// of UiModel mixin that let bind Flutter widget tree to Toggler based Models.
/// Toggler with Flutter example App is in example/flutter_example.dart file.

/// **Always** use symbolic names for Toggler item (bit) index.
/// You may stub biNames and smNames with script:
///`dart run tool/print_named_indice.dart > lib/src/tg_names.dart`
const biName0 = 0;
const biNameA = 1;
const biNameB = 2;
const biNameC = 3;
const biNameD = 4;
const biNameE = 5;
const biNameF = 6;

void main() {
  void ourAfterHandler(_, Toggler cu) {
    var tg = '    set: ';
    var ds = ' active: ';
    for (int i = 0; i < 27; i++) {
      tg += cu[i] ? ' ^' : ' -';
      ds += cu.active(i) ? ' .' : ' !';
    }
    print(' biName:  0 A B C D E F G H I J K L M N O P Q R S T U W V X Y Z');
    print(tg);
    print(ds);
    print('          -----------------------------------------------------');
  }

  // oS is a copy of our previous state, nS is our the "to be" state
  // `fix` handler implements a "business logic" or "view logic", in
  // simpler Apps it may implement both.
  bool ourStateFixer(Toggler oS, Toggler nS) {
    // 'NameA' may toggle only if 'Name0' was previously set.
    if (!oS[biName0] && oS[biNameA] != nS[biNameA]) {
      print('      >>> NameA change supressed by validator');
      return false; // disallow change to 'NameA'
    }
    // fix B,C if F radio was toggled
    if (oS[biNameF] != nS[biNameF]) {
      if (nS[biNameF]) {
        nS.disable(biNameB);
        nS.disable(biNameC);
        nS.clear(biNameB);
        nS.clear(biNameC);
      } else {
        nS.enable(biNameB);
        nS.enable(biNameC);
      }
    }
    return true; // accept changes and instruct Toggler to commit new state
    // return false; // instruct Toggler to abandon changes
  }

  final flags = Toggler(after: ourAfterHandler, fix: ourStateFixer);

  // declare a radioGroup, up to 17 groups can be made over 51 items.
  flags.radioGroup(biNameD, biNameF);
  // fiddle:
  print('Trying to set A (StateFix validator disallows this)');
  flags.set1(biNameA);
  print('Set 0, NameA can be set only if Name0 was set before');
  flags.set1(biName0);
  print('Now A is allowed to be toggled');
  flags.set1(biNameA);
  print('Set B');
  flags.set1(biNameB);
  print('Set C');
  flags.set1(biNameC);
  print('Set D (of D..F radio group)');
  flags.set1(biNameD);
  print('Set E of radio D..F - D will clear automatically.');
  flags.set1(biNameE);
  print('Set F radio. E will clear then B and C are disabled by StateFix');
  flags.set1(biNameF);
  print('Set D radio. F will clear; then B and C are enabled by StateFix');
  flags.set1(biNameD);
}

/// A few extensions are put here to show how Toggler can be tailored for
/// different purposes.

/// If you migrate from (or still use) _reactive_ style state management
/// you may extend Toggler to get it feel Rx familiar.
extension TogglerRx on Toggler {
  /// unconditionally remove handlers from cloned object
  void freeze() => fix = after = notifier = null;

  /// apply externally mutated state, opt forcibly, opt fire notifications.
  bool apply(Toggler src, {bool doNotify = true, bool force = false}) {
    if (!force && hh > src.hh) return false;
    Toggler? oldS;
    if (after != null || notifier != null) oldS = state();
    bits = src.bits;
    ds = src.ds;
    rg = src.rg;
    hh = src.hh;
    if (oldS != null) {
      chb = (bits ^ oldS.bits) | (ds ^ oldS.ds);
      if (doNotify) {
        if (after != null) {
          after!(oldS, this);
        } else if (notifier != null) {
          notifier!.pump(chb);
        }
      }
    }
    return true;
  }
}

extension TogglerNums on Toggler {
  /// returns item at sIndex state as 0..3 int of b1:ds b0:tg
  /// for use with `switch`.
  int numAt(int sIndex) => (ds >> sIndex) << 1 | bits >> sIndex;

  /// Toggler has 8 bits reserved for an extension state, get/set all 8 of them.
  /// See also [BrandedTogglers].
  int get numExt => hh.toUnsigned(16) >> 8;
  set numExt(int sIndex) => hh = hh & ~0xff00 | sIndex.toUnsigned(8) << 8;
}

/// If your UI is based on UiModel mixin, `replay` can be used to "demo play"
/// live App actions, giving eg. an interactive tutorial. Replay can allow us to
/// get our _debug_ App to the same state a bug reporter person experienced.
extension TogglerReplay on Toggler {
  /// _compact action byte_ is the most recent change coming from a state setter.
  /// Saved (by `fix` or `after`) to the bytes blob it can be used to feed the
  /// [replay] method below.
  ///
  /// CaByte keeps _incoming_ changes, not ones made internally by `fix`.
  /// CaByte layout: `(0/1) b7:tg/ds b6:clear/set b5..b0 index of change`
  int get cabyte => hh.toUnsigned(8);

  /// takes compact action byte and applies it - emulating a setter run.
  /// Used for testing and debugging (eg. with actions saved at end user devices).
  void replay(int cas) {
    final i = cas.toUnsigned(6);
    final isDs = cas & 1 << 7 != 0;
    final actS = cas & 1 << 6 != 0;
    final va = isDs
        ? actS
            ? ds |= (1 << i)
            : ds &= ~(1 << i)
        : actS
            ? bits |= (1 << i)
            : bits &= ~(1 << i);
    verto(i, va, isDs, actS);
  }
}

/// For a really big (server side) Models you may reluctantly use branded
/// Togglers. Don't do it with Flutter - 52 moving parts per route (page) is
/// for sure too much. With Flutter use submodels owned by your ViewModel.
extension BrandedTogglers on Toggler {
  /// _brand_ property allows to give Toggler object a number in 0..31 range.
  /// Then a single common `fix` method may know which one of that many
  /// Togglers changed its state and called it (_fix_). These Togglers usually
  /// are put on a List<Toggler> under _brand_ index.
  int get brand => hh.toUnsigned(16) >> 8;
  set brand(int i) => hh = hh & ~0xff00 | i.toUnsigned(8) << 8;

  /// returns _true_ if brand of object and brand in _branded index_ match,
  bool checkBrand(int i) => hh & 0xff00 == i & 0xff00;
}

extension SignalDirect on Toggler {
  /// sets direct signal limit, flags over that index can be used to direct
  /// signaling. Note that direct signaling can not be replayed, then neither
  /// state fixer nor after will run. Ie. bits used for direct signals
  /// are NOT part of your state machine (nor even they register).
  void allowDirectSignalsOver(int i) =>
      hh = hh & ~0xff00 | i.toUnsigned(6) << 8;

  /// pump sMask containing 1s on positions over previously set limit
  /// directly to the notifier
  void sigDirect(int sMask) {
    assert(() {
      final lim = (hh.toUnsigned(16) >> 8);
      if (lim == 0 || sMask.toUnsigned(lim) != 0) return false;
      return true;
    }(), '''
  Direct signal mask contains at least one bit that is NOT over the
  allowDirectSignalsOver(${hh.toUnsigned(16) >> 8}) limit.
''');
    notifier?.pump(sMask & ~((1 << (hh.toUnsigned(16) >> 8)) - 1));
  }
}
