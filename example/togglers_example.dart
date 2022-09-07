import 'package:togglers/togglers.dart';

void main() {
  void ourNotify(Togglers cu) {
    var tg = '    set: ';
    var ds = ' active: ';
    for (int i = 0; i < 27; i++) {
      tg += cu[i] ? ' ^' : ' -';
      ds += cu.hasActive(i) ? ' .' : ' !';
    }
    print('ktgName:  0 A B C D E F G H I J K L M N O P Q R S T U W V X Y Z');
    print(tg);
    print(ds);
    print('          -----------------------------------------------------');
  }

  // pt is a copy of previous state, cu is the current (live) state
  bool ourCheck(Togglers pt, Togglers cu) {
    // validate: 'NameA' can toggle only if 'Name0' was set.
    if (!pt[ktgName0] && pt[ktgNameA] != cu[ktgNameA]) {
      print('      >>> NameA change retracted');
      return false; // disallow change to 'NameA'
    }
    // fix state: disable B,C if F radio is set
    pt.syncFrom(cu); // update old state copy to current state
    if (pt[ktgNameF]) {
      pt.disable(ktgNameB);
      pt.disable(ktgNameC);
      pt.clear(ktgNameB);
      pt.clear(ktgNameC);
      cu.updateFromCopy(pt);
    } else if (!pt.hasActive(ktgNameB) || !pt.hasActive(ktgNameC)) {
      pt.enable(ktgNameB);
      pt.enable(ktgNameC);
      if (!cu.updateFromCopy(pt)) {
        // raceDetected!
        // data races may happen if code in Check called async code and other
        // piece of code altered our state in meantime.
      }
    }
    return true; // accept changes
  }

  final flags = Togglers(notify: ourNotify, checkFix: ourCheck);

  // declare a radioGroup, up to 21 groups can be made over 63 items.
  flags.radioGroup(ktgNameD, ktgNameF);
  // fiddle:
  print('Trying to set A (ourCheck validator disallows this)');
  flags.set(ktgNameA);
  print('Set 0, NameA can be set only if Name0 was set before');
  flags.set(ktgName0);
  print('Now A is allowed to be toggled');
  flags.set(ktgNameA);
  print('Set B');
  flags.set(ktgNameB);
  print('Set C');
  flags.set(ktgNameC);
  print('Set D (of D..F radio group)');
  flags.set(ktgNameD);
  print('Set E of radio D..F - D will clear automatically.');
  flags.set(ktgNameE);
  print('Set F radio. E will clear then B and C are disabled by ourCheck');
  flags.set(ktgNameF);
  print('Set D radio. F will clear; then B and C are enabled by ourCheck');
  flags.set(ktgNameD);
}

const ktgName0 = 0;
const ktgNameA = 1;
const ktgNameB = 2;
const ktgNameC = 3;
const ktgNameD = 4;
const ktgNameE = 5;
const ktgNameF = 6;
const ktgNameG = 7;
const ktgNameH = 8;
const ktgNameI = 9;
const ktgNameJ = 10;
const ktgNameK = 11;
const ktgNameL = 12;
const ktgNameM = 13;
const ktgNameN = 14;
const ktgNameO = 15;
const ktgNameP = 16;
const ktgNameQ = 17;
const ktgNameR = 18;
const ktgNameS = 19;
const ktgNameT = 20;
const ktgNameU = 21;
const ktgNameW = 22;
const ktgNameV = 23;
const ktgNameX = 24;
const ktgNameY = 25;
const ktgNameZ = 26;
