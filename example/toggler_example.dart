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

  final flags = Toggler(notify: ourNotify, fix: ourCheck);

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

/// for use in Rx settings state methods can be added as an extension
extension TogglerRx on Toggler {
  /// apply externally mutated state to the _Model_ object.
  bool apply(Toggler src, {bool doNotify = true, bool force = false}) {
    if (!force && hh > src.hh) return false;
    Toggler? oldS;
    if (doNotify && notify != null) oldS = state();
    tg = src.tg;
    ds = src.ds;
    rm = src.rm;
    hh = src.hh;
    if (doNotify && notify != null) notify!(oldS!, this);
    return true;
  }

  /// remove handlers from clone, you may also want to call setDone()
  void freeze() => fix = notify = null;

  /// takes compact state action `sa` and applies it emulating a setter run.
  /// Used for testing and debugging (eg. with actions saved at end user devices).
  /// Actions are saved in a single byte per action with bit layout:
  /// `b7:tg0/ds1 b6:clear0/set1 b5..b0 index`
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
