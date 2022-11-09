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
  void ourAfterHandler(Toggler cu) {
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
        nS.set0(biNameB);
        nS.set0(biNameC);
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

extension TogglerExt on Toggler {
  /// returns item at sIndex state as 0..3 int of b1:ds b0:tg
  /// for use with `switch`.
  // int numAt(int sIndex) => (ds >> sIndex) << 1 | bits >> sIndex;
}
