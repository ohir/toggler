import 'package:toggler/toggler.dart';
import 'package:test/test.dart';

final Matcher throwsAssertionError = throwsA(isA<AssertionError>());

void main() {
  group('Rudimentary', () {
    final flags = Toggler();

    setUp(() {
      flags.tg = flags.ds = flags.rm = flags.hh = 0; // reset
    });

    test('Set 0 62', () {
      flags.set(0);
      flags.set(62);
      expect(flags[0] && !flags[1] && !flags[61] && flags[62], isTrue);
      flags.clear(0);
      flags.clear(62);
      expect(!flags[0] && !flags[62], isTrue);
    });
    test('Is Set in range set boundry', () {
      flags.set(7);
      flags.set(12);
      expect(flags.anySetInRange(first: 7, last: 10), isTrue);
      expect(flags.anySetInRange(first: 8, last: 12), isTrue);
    });
    test('Is Set in range not set boundary', () {
      flags.set(7);
      flags.set(12);
      expect(flags.anySetInRange(first: 8, last: 11), isFalse);
    });
    test('DisableEnable', () {
      flags.disable(0);
      expect(flags.active(0), isFalse);
      flags.set(0, ifActive: true);
      expect(flags[0], isFalse);
      flags.enable(0);
      flags.set(0, ifActive: true);
      expect(flags[0], isTrue);
    });
    test('Disable 62', () {
      flags.set(62);
      flags.disable(62);
      flags.clear(62, ifActive: true);
      flags.setTo(62, false, ifActive: true);
      expect(flags[62], isTrue);
      flags.setTo(62, false);
      expect(flags[62], isFalse);
    });
    test('DisableEnable 55', () {
      flags.disable(55);
      flags.set(55, ifActive: true);
      expect(flags[55], isFalse);
      flags.setTo(55, true, ifActive: true);
      expect(flags[55], isFalse);
      flags.enable(55);
      flags.set(55, ifActive: true);
      expect(flags[55], isTrue);
    });
    test('DisableEnable 33', () {
      flags.set(33, ifActive: true);
      flags.disable(33);
      flags.clear(33, ifActive: true);
      expect(flags[33], isTrue);
      flags.setTo(33, false, ifActive: true);
      expect(flags[33], isTrue);
      flags.enable(33);
      flags.clear(33, ifActive: true);
      expect(flags[33], isFalse);
    });
    test('Toggle 0', () {
      flags.disable(0);
      flags.toggle(0, ifActive: true);
      expect(flags[0], isFalse);
      flags.toggle(0);
      expect(flags[0], isTrue);
      flags.toggle(0);
      expect(flags[0], isFalse);
    });
    // test('name ', () {});
    test('generational behaviour', () {
      var cLive = Toggler(notify: (Toggler a, Toggler b) => a.isOlderThan(b));
      var c0 = cLive.state();
      var c1 = cLive.state();
      cLive.set(7);
      var c2 = cLive.state();
      cLive.clear(1);
      expect(c1.isOlderThan(c2), isTrue); // copy to copy
      expect(c2.isOlderThan(c1), isFalse); // copy to copy
      expect(c2.isOlderThan(c2), isFalse); // copy to copy

      var cL2 = Toggler(notify: (Toggler a, Toggler b) => a.isOlderThan(b));
      var c4 = cLive.state();
      expect(cLive.isOlderThan(cL2), isFalse); // live to live, always false
      expect(c4.isOlderThan(cL2), isTrue); // copy to live, always true

      c0.set(15);
      expect(c0.hh == c1.hh, isTrue); // copies may not alter history
      expect(c0.serial == c1.serial, isTrue);
      expect(c0.lastChangeIndex == c1.lastChangeIndex, isTrue);
    });
    test('Differs', () {
      var c1 = flags.state();
      expect(c1.differsFrom(flags), isFalse);
      c1.set(5);
      expect(c1.differsFrom(flags), isTrue);
      flags.set(5);
      expect(c1.differsFrom(flags), isFalse);
      flags.set(8);
      c1.set(23);
      expect(c1.differsFrom(flags, first: 8, last: 22), isTrue);
      expect(c1.differsFrom(flags, first: 9, last: 22), isFalse);
      expect(c1.differsFrom(flags, first: 9, last: 23), isTrue);
    });
    test('Set 63 | should throw', () {
      expect(() {
        flags.set(63);
      }, throwsAssertionError);
    });
    test('Set -1 | should throw', () {
      expect(() {
        flags.set(-1);
      }, throwsAssertionError);
    });
  });
  group('Radio', () {
    final flags = Toggler();

    setUp(() {
      flags.tg = flags.ds = flags.rm = flags.hh = 0; // reset
      flags.radioGroup(kA, kC);
      flags.radioGroup(kE, kH);
      flags.set(kA);
      flags.set(kH);
    });
    test('Set overlapping radio | should throw', () {
      expect(() {
        flags.radioGroup(kI, kL);
      }, throwsAssertionError);
    });
    test('Set single radio | should throw', () {
      expect(() {
        flags.radioGroup(kL, kL);
      }, throwsAssertionError);
    });
    test('Set 0..3 radio', () {
      flags.rm = 0; // reset radios
      flags.radioGroup(k0, kC);
      flags.set(k0);
      expect(flags[k0], isTrue);
      flags.set(kC);
      expect(!flags[k0] && !flags[kA] && !flags[kB] && flags[kC], isTrue);
      flags.set(kB);
      expect(!flags[k0] && !flags[kA] && flags[kB] && !flags[kC], isTrue);
      flags.set(kA);
      expect(!flags[k0] && flags[kA] && !flags[kB] && !flags[kC], isTrue);
    });
    test('Set 60..63 radio | should throw', () {
      expect(() {
        flags.rm = 0; // reset radios
        flags.radioGroup(60, 63);
      }, throwsAssertionError);
    });
    test('A H should be set in setup', () {
      expect(flags[kA] && flags[kH] && !flags[k0] && !flags[kI], isTrue);
    });
    test('set C E', () {
      flags.set(kC);
      flags.set(kE);
      expect(flags[kC] && flags[kE] && !flags[kA] && !flags[kH], isTrue);
    });
    test('set B F', () {
      flags.set(kB);
      flags.set(kF);
      expect(flags[kB] && flags[kF] && !flags[kA] && !flags[kH], isTrue);
    });
    test('set D I', () {
      flags.set(kD);
      flags.set(kI);
      expect(flags[kA] && flags[kH] && flags[kD] && flags[kI], isTrue);
    });
  });
  group('Errs', () {
    final flags = Toggler();

    setUp(() {
      flags.tg = flags.ds = flags.rm = flags.hh = 0; // reset
      flags.tg |= 1 << 63; // set err
      flags.ds |= 1 << 63; // set race
    });
    test('Race/Err getters', () {
      expect(flags.error, isTrue);
      expect(flags.race, isTrue);
    });
    test('Demand bad diff| should throw', () {
      expect(() {
        flags.differsFrom(flags.state(), last: 63);
      }, throwsAssertionError);
    });
  });
  group('FixNotifyRaces', () {
    int last = 0;
    void chnote(Toggler oS, Toggler nS) => last++;

    bool chfix(Toggler oS, Toggler nS) {
      if (nS.lastChangeIndex == 25) nS.hh <<= 1;
      oS.differsFrom(nS, first: 11, last: 16);
      if (nS[1] && nS.differsFrom(oS)) nS.set(0);
      return true;
    }

    final flags = Toggler(notify: chnote, checkFix: chfix);

    setUp(() {
      flags.tg = flags.ds = flags.rm = flags.hh = 0; // reset
    });
    test('Notify 0', () {
      flags.set(0);
      expect(flags[0] && !flags[1], isTrue);
      expect(last == 1, isTrue);
    });
    test('Notify 1', () {
      flags.set(1);
      expect(last == 2, isTrue);
      expect(flags[0] && flags[1], isTrue);
    });
    test('Notify via clone', () {
      var nf = flags.clone();
      nf.set(5);
      expect(nf[5] && !flags[5], isTrue);
      expect(last == 3, isTrue);
    });
    test('Make artificial race | should throw', () {
      expect(() {
        flags.set(25);
        flags.set(0);
      }, throwsAssertionError);
    });
    // TODOx Make real racing test to hit `if (hh != newS.hh)` in _ckFix
  });
}

const k0 = 0;
const kA = 1;
const kB = 2;
const kC = 3;
const kD = 4;
const kE = 5;
const kF = 6;
const kG = 7;
const kH = 8;
const kI = 9;
const kJ = 10;
const kK = 11;
const kL = 12;
const kM = 13;
const kN = 14;
const kO = 15;
const kP = 16;
const kQ = 17;
const kR = 18;
const kS = 19;
const kT = 20;
const kU = 21;
const kW = 22;
const kV = 23;
const kX = 24;
const kY = 25;
const kZ = 26;
