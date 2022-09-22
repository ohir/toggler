// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

import 'package:toggler/toggler.dart';

/// This is a CLI example. Toggler does not depend on Flutter, but is a basis
/// of UiModel mixin that let bind Flutter widget tree to Toggler based Models.
/// Toggler with Flutter example App is in example/flutter_example.dart file.

/// **Always** use symbolic names for Toggler item (bit) index.
/// You may stub tgNames and smNames with script:
///`dart run tool/print_named_indice.dart > lib/src/tg_names.dart`
const tgName0 = 0;
const tgNameA = 1;
const tgNameB = 2;
const tgNameC = 3;
const tgNameD = 4;
const tgNameE = 5;
const tgNameF = 6;

void main() {
  void ourAfterHandler(_, Toggler cu) {
    var tg = '    set: ';
    var ds = ' active: ';
    for (int i = 0; i < 27; i++) {
      tg += cu[i] ? ' ^' : ' -';
      ds += cu.active(i) ? ' .' : ' !';
    }
    print(' tgName:  0 A B C D E F G H I J K L M N O P Q R S T U W V X Y Z');
    print(tg);
    print(ds);
    print('          -----------------------------------------------------');
  }

  // oS is a copy of our previous state, nS is our the "to be" state
  // `fix` handler implements a "business logic" or "view logic", in
  // simpler Apps it may implement both.
  bool ourStateFixer(Toggler oS, Toggler nS) {
    // 'NameA' may toggle only if 'Name0' was previously set.
    if (!oS[tgName0] && oS[tgNameA] != nS[tgNameA]) {
      print('      >>> NameA change supressed by validator');
      return false; // disallow change to 'NameA'
    }
    // fix B,C if F radio was toggled
    if (oS[tgNameF] != nS[tgNameF]) {
      if (nS[tgNameF]) {
        nS.disable(tgNameB);
        nS.disable(tgNameC);
        nS.clear(tgNameB);
        nS.clear(tgNameC);
      } else {
        nS.enable(tgNameB);
        nS.enable(tgNameC);
      }
    }
    return true; // accept changes and instruct Toggler to commit new state
    // return false; // instruct Toggler to abandon changes
  }

  final flags = Toggler(after: ourAfterHandler, fix: ourStateFixer);

  // declare a radioGroup, up to 17 groups can be made over 51 items.
  flags.radioGroup(tgNameD, tgNameF);
  // fiddle:
  print('Trying to set A (StateFix validator disallows this)');
  flags.set1(tgNameA);
  print('Set 0, NameA can be set only if Name0 was set before');
  flags.set1(tgName0);
  print('Now A is allowed to be toggled');
  flags.set1(tgNameA);
  print('Set B');
  flags.set1(tgNameB);
  print('Set C');
  flags.set1(tgNameC);
  print('Set D (of D..F radio group)');
  flags.set1(tgNameD);
  print('Set E of radio D..F - D will clear automatically.');
  flags.set1(tgNameE);
  print('Set F radio. E will clear then B and C are disabled by StateFix');
  flags.set1(tgNameF);
  print('Set D radio. F will clear; then B and C are enabled by StateFix');
  flags.set1(tgNameD);
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
    tg = src.tg;
    ds = src.ds;
    rg = src.rg;
    hh = src.hh;
    if (oldS != null) {
      chb = (tg ^ oldS.tg) | (ds ^ oldS.ds);
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
  /// returns item at tgIndex state as 0..3 int of b1:ds b0:tg
  /// for use with `switch`.
  int numAt(int tgIndex) => (ds >> tgIndex) << 1 | tg >> tgIndex;

  /// Toggler has 8 bits reserved for an extension state, get/set all 8 of them.
  /// See also [BrandedTogglers].
  int get numExt => hh.toUnsigned(16) >> 8;
  set numExt(int tgIndex) => hh = hh & ~0xff00 | tgIndex.toUnsigned(8) << 8;
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
            ? tg |= (1 << i)
            : tg &= ~(1 << i);
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
  int get brand => hh.toUnsigned(13) >> 8;
  set brand(int i) => hh = hh & ~0x1f00 | i.toUnsigned(5) << 6;

  /// returns _true_ if brand of object and brand in _branded index_ match,
  /// and if resulting index can safely be used in Toggler methods.
  bool checkBrand(int i) =>
      i >= 0 && hh & 0x1f00 == i & 0x1f00 && i & 0x3f <= tgIndexMax;

  /// zeroes brand bits of _i_ index so returned int can be used with
  /// Toggler methods (note that _i_ should always be subject to [checkBrand]
  /// before clamping: `if (tg.checkBrand(bi)) smth = tg[clampBrand(bi)]`)
  int clampBrand(int i) => i.toUnsigned(6);

  /// merge this object brand bits into the index
  int brandIndex(int i) => (hh & 0x1f00) >> 2 | i.toUnsigned(5);
}
