// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

import 'package:toggler/toggler.dart';

void main() {
  void ourNotify(_, Toggler cu) {
    var tg = '    set: ';
    var ds = ' active: ';
    for (int i = 0; i < 27; i++) {
      tg += cu[i] ? ' ^' : ' -';
      ds += cu.active(i) ? ' .' : ' !';
    }
    print('kTGname:  0 A B C D E F G H I J K L M N O P Q R S T U W V X Y Z');
    print(tg);
    print(ds);
    print('          -----------------------------------------------------');
  }

  // pt is a copy of previous state, cu is the current (live) state
  bool ourCheck(Toggler oS, Toggler nS) {
    // validate: 'NameA' can toggle only if 'Name0' was set.
    if (!oS[kTGname0] && oS[kTGnameA] != nS[kTGnameA]) {
      print('      >>> NameA change supressed by validator');
      return false; // disallow change to 'NameA'
    }
    // fix B,C if F radio was toggled
    if (oS[kTGnameF] != nS[kTGnameF]) {
      if (nS[kTGnameF]) {
        nS.disable(kTGnameB);
        nS.disable(kTGnameC);
        nS.clear(kTGnameB);
        nS.clear(kTGnameC);
      } else {
        nS.enable(kTGnameB);
        nS.enable(kTGnameC);
      }
    }
    return true; // accept changes
  }

  final flags = Toggler(after: ourNotify, fix: ourCheck);

  // declare a radioGroup, up to 17 groups can be made over 51 items.
  flags.radioGroup(kTGnameD, kTGnameF);
  // fiddle:
  print('Trying to set A (ourCheck validator disallows this)');
  flags.set(kTGnameA);
  print('Set 0, NameA can be set only if Name0 was set before');
  flags.set(kTGname0);
  print('Now A is allowed to be toggled');
  flags.set(kTGnameA);
  print('Set B');
  flags.set(kTGnameB);
  print('Set C');
  flags.set(kTGnameC);
  print('Set D (of D..F radio group)');
  flags.set(kTGnameD);
  print('Set E of radio D..F - D will clear automatically.');
  flags.set(kTGnameE);
  print('Set F radio. E will clear then B and C are disabled by ourCheck');
  flags.set(kTGnameF);
  print('Set D radio. F will clear; then B and C are enabled by ourCheck');
  flags.set(kTGnameD);
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
    pump(i, va, isDs, actS);
  }
}

/// always use symbolic index
const kTGname0 = 0;
const kTGnameA = 1;
const kTGnameB = 2;
const kTGnameC = 3;
const kTGnameD = 4;
const kTGnameE = 5;
const kTGnameF = 6;
const kTGnameG = 7;
const kTGnameH = 8;
const kTGnameI = 9;
const kTGnameJ = 10;
const kTGnameK = 11;
const kTGnameL = 12;
const kTGnameM = 13;
const kTGnameN = 14;
const kTGnameO = 15;
const kTGnameP = 16;
const kTGnameQ = 17;
const kTGnameR = 18;
const kTGnameS = 19;
const kTGnameT = 20;
const kTGnameU = 21;
const kTGnameW = 22;
const kTGnameV = 23;
const kTGnameX = 24;
const kTGnameY = 25;
const kTGnameZ = 26;
