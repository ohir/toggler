// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

import 'package:toggler/toggler.dart';

/// **always** use symbolic names for Toggler item (bit) index
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

  // pt is a copy of previous state, cu is the current (live) state
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
    return true; // accept changes
  }

  final flags = Toggler(after: ourAfterHandler, fix: ourStateFixer);

  // declare a radioGroup, up to 17 groups can be made over 51 items.
  flags.radioGroup(tgNameD, tgNameF);
  // fiddle:
  print('Trying to set A (StateFix validator disallows this)');
  flags.set(tgNameA);
  print('Set 0, NameA can be set only if Name0 was set before');
  flags.set(tgName0);
  print('Now A is allowed to be toggled');
  flags.set(tgNameA);
  print('Set B');
  flags.set(tgNameB);
  print('Set C');
  flags.set(tgNameC);
  print('Set D (of D..F radio group)');
  flags.set(tgNameD);
  print('Set E of radio D..F - D will clear automatically.');
  flags.set(tgNameE);
  print('Set F radio. E will clear then B and C are disabled by StateFix');
  flags.set(tgNameF);
  print('Set D radio. F will clear; then B and C are enabled by StateFix');
  flags.set(tgNameD);
}

/// toMask int extensiom takes index and returns const in with 1 set at index
extension TogglerMask on int {
  toMask(int i) => i >= 0 && i <= tgIndexMax ? 1 << i : 0;
}

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
  /// Toggler methods (note that _i_ should always be subject to _checkBrand_
  /// before clamping: `if (tgo.checkBrand(bi)) smth = tgo[clampBrand(bi)]`)
  int clampBrand(int i) => i.toUnsigned(6);

  /// merge this object brand bits into the index
  int brandIndex(int i) => (hh & 0x1f00) >> 2 | i.toUnsigned(5);
}

/// for use in Rx settings state methods can be added as an extension
extension TogglerRx on Toggler {
  /// apply externally mutated state to the _Model_ object.
  bool apply(Toggler src, {bool doNotify = true, bool force = false}) {
    if (!force && hh > src.hh) return false;
    Toggler? oldS;
    if (doNotify && after != null) oldS = state();
    tg = src.tg;
    ds = src.ds;
    rg = src.rg;
    hh = src.hh;
    if (doNotify && after != null) after!(oldS!, this);
    return true;
  }

  /// unconditionally remove handlers from cloned object
  void freeze() => fix = after = null;

  /// _compact action byte_ of the most recent change coming from a state setter.
  /// For use with `replay` method below.
  ///
  /// CAbyte keeps _incoming_ changes, not ones made internally by `fix`.
  /// CAbyte layout: `(0/1) b7:tg/ds b6:clear/set b5..b0 change index`
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
