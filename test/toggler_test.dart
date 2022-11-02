// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

import 'package:toggler/toggler.dart';
import 'package:test/test.dart';

final Matcher throwsAssertionError = throwsA(isA<AssertionError>());

class TCNo extends ToggledNotifier {
  int seen = 0;
  @override
  void pump(int chb) => seen = chb;
}

/// toggles on setting val to > 10, otherwise signals
class Model {
  Toggler msr;
  final int sigAt;
  int _v = -1;
  Model(this.sigAt, this.msr);
  sig(int at) => msr.signal(at);
  tap(int at) => msr.toggle(at);
  int get val => _v;
  set val(int v) {
    _v = v;
    v > 10 ? msr.toggle(sigAt) : msr.signal(sigAt);
  }
}

void main() {
  group('Rudimentary :: ', () {
    final flags = Toggler();

    setUp(() {
      flags.bits = flags.hh = flags.ds = flags.rg = flags.chb = 0;
      flags.fix = flags.after = null;
    });

    test('Set 0 Max', () {
      flags[0] = true; // cover []= setter
      flags.set1(bIndexMax);
      expect(flags[0] && !flags[1] && !flags[bIndexMax - 1] && flags[bIndexMax],
          isTrue);
      flags.clear(0);
      flags.clear(bIndexMax);
      expect(!flags[0] && !flags[bIndexMax], isTrue);
    });
    test('Is Set in range set boundry', () {
      flags.set1(7);
      flags.set1(12);
      expect(flags.anyOfSet(rangeFirst: 7, rangeLast: 10), isTrue);
      expect(flags.anyOfSet(rangeFirst: 8, rangeLast: 12), isTrue);
    });
    test('Is Set in range not set boundary', () {
      flags.set1(7);
      flags.set1(12);
      expect(flags.anyOfSet(rangeFirst: 8, rangeLast: 11), isFalse);
    });
    test('fixDs fixBits may not register change', () {
      flags.fixDS(1, true);
      expect(flags.active(1), isFalse);
      expect(flags.chb, equals(0));
      flags.fixBits(1, true);
      expect(flags[1], isTrue);
      expect(flags.chb, equals(0));
    });
    test('DisableEnable', () {
      flags.disable(0);
      expect(flags.active(0), isFalse);
      flags.set1(0, ifActive: true);
      expect(flags[0], isFalse);
      flags.enable(0);
      flags.set1(0, ifActive: true);
      expect(flags[0], isTrue);
    });
    test('setDisable setEnable', () {
      flags.setDS(0, true);
      expect(flags.active(0), isFalse);
      flags.set1(0, ifActive: true);
      expect(flags[0], isFalse);
      flags.setDS(0, false);
      flags.set1(0, ifActive: true);
      expect(flags[0], isTrue);
    });
    test('Disable Max', () {
      flags.set1(bIndexMax);
      flags.disable(bIndexMax);
      flags.clear(bIndexMax, ifActive: true);
      flags.setTo(bIndexMax, false, ifActive: true);
      expect(flags[bIndexMax], isTrue);
      flags.setTo(bIndexMax, false);
      expect(flags[bIndexMax], isFalse);
    });
    test('DisableEnable Max-1', () {
      flags.disable(bIndexMax - 1);
      flags.set1(bIndexMax - 1, ifActive: true);
      expect(flags[bIndexMax - 1], isFalse);
      flags.setTo(bIndexMax - 1, true, ifActive: true);
      expect(flags[bIndexMax - 1], isFalse);
      flags.enable(bIndexMax - 1);
      flags.set1(bIndexMax - 1, ifActive: true);
      expect(flags[bIndexMax - 1], isTrue);
    });
    test('DisableEnable 33', () {
      flags.set1(33, ifActive: true);
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
    test('generational behaviour [A]', () {
      var cLive = Toggler(after: (Toggler a, Toggler b) => a.isOlderThan(b));
      var c0 = cLive.state();
      var c1 = cLive.state();
      cLive.set1(7);
      var c2 = cLive.state();
      cLive.clear(1);
      expect(c0.isOlderThan(c1), isFalse); // copy to copy
      expect(c1.isOlderThan(c2), isTrue); // copy to copy
      expect(c2.isOlderThan(c1), isFalse); // copy to copy
      expect(c2.isOlderThan(c2), isFalse); // copy to copy
    });
    test('generational behaviour [B]', () {
      var cLive = Toggler(after: (Toggler a, Toggler b) {});
      var c0 = cLive.state();
      var c1 = cLive.state();
      cLive.set1(7);
      var cL2 = Toggler(after: (Toggler a, Toggler b) {});
      var c4 = cLive.state();
      expect(cLive.isOlderThan(cL2), isFalse); // live to live, always false
      expect(c4.isOlderThan(cL2), isTrue); // copy to live, always true

      c0.set1(15);
      c1.set1(33);
      expect(c0.hh == c1.hh, isTrue); // copies may not alter history
      expect(c0.serial == c1.serial, isTrue);
      expect(c0.recent == c1.recent, isTrue);
    });
    test('copy may not mutate history', () {
      var c0 = Toggler();
      c0.disable(3);
      c0.set1(2);
      var c1 = c0.state();
      c1.set1(16);
      var c2 = c1.state();
      expect(
          c0[2] &&
              c1[2] &&
              c2[2] &&
              c1[16] &&
              c2[16] &&
              c0.hh == c1.hh &&
              c2.hh == c0.hh &&
              c2.hh == 0,
          isTrue);
    });
    test('Change mask A', () {
      flags.set1(0);
      expect(flags.chb == 1, isTrue);
      flags.set1(10);
      expect(flags.chb == 1024, isTrue);
      expect(flags.changedAt(9), isFalse);
      expect(flags.changedAt(10), isTrue);
      expect(flags.changedAt(11), isFalse);
      expect(flags.changed(1 << 9), isFalse);
      expect(flags.changed(1 << 10), isTrue);
      expect(flags.changed(1 << 11), isFalse);
      flags.set1(11);
      flags.set1(33);
      flags.disable(51); // cm must reflect any change at index
      expect(flags.chb == 1 << 51, isTrue);
    });
    test('Change mask B', () {
      bool cf(Toggler o, Toggler n) {
        n.set1(1);
        n.disable(2);
        return true;
      }

      flags.fix = cf;
      flags.set1(0);
      expect(flags.chb, equals(7)); // b0,b1,b2 changed
    });
    test('Differs', () {
      var c1 = flags.state();
      expect(c1.differsFrom(flags), isFalse);
      c1.set1(5);
      expect(c1.differsFrom(flags), isTrue);
      expect(c1.differsFrom(flags, mask: 63), isTrue);
      expect(c1.differsFrom(flags, mask: 31), isFalse);
      flags.set1(5);
      expect(c1.differsFrom(flags), isFalse);
      flags.set1(8);
      c1.set1(23);
      expect(c1.differsFrom(flags, bFirst: 8, bLast: 22), isTrue);
      expect(c1.differsFrom(flags, bFirst: 9, bLast: 22), isFalse);
      expect(c1.differsFrom(flags, bFirst: 9, bLast: 23), isTrue);
    });
    test('Set 63 | should throw', () {
      expect(() {
        flags.set1(63);
      }, throwsAssertionError);
    });
    test('Set -1 | should throw', () {
      expect(() {
        flags.set1(-1);
      }, throwsAssertionError);
    });
  });
  group('Radio :: ', () {
    final flags = Toggler();

    setUp(() {
      flags.bits = flags.hh = flags.ds = flags.rg = flags.chb = 0;
      flags.radioGroup(kA, kC);
      flags.radioGroup(kE, kH);
      flags.set1(kA);
      flags.set1(kH);
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
      flags.rg = 0; // reset radios
      flags.radioGroup(k0, kC);
      flags.set1(k0);
      expect(flags[k0], isTrue);
      flags.set1(kC);
      expect(!flags[k0] && !flags[kA] && !flags[kB] && flags[kC], isTrue);
      flags.set1(kB);
      expect(!flags[k0] && !flags[kA] && flags[kB] && !flags[kC], isTrue);
      flags.set1(kA);
      expect(!flags[k0] && flags[kA] && !flags[kB] && !flags[kC], isTrue);
    });
    test('Set 60..63 radio | should throw', () {
      expect(() {
        flags.rg = 0; // reset radios
        flags.radioGroup(60, 63);
      }, throwsAssertionError);
    });
    test('A H should be set in setup', () {
      expect(flags[kA] && flags[kH] && !flags[k0] && !flags[kI], isTrue);
    });
    test('set C E', () {
      flags.set1(kC);
      flags.set1(kE);
      expect(flags[kC] && flags[kE] && !flags[kA] && !flags[kH], isTrue);
    });
    test('set B F', () {
      flags.set1(kB);
      flags.set1(kF);
      expect(flags[kB] && flags[kF] && !flags[kA] && !flags[kH], isTrue);
    });
    test('set D I', () {
      flags.set1(kD);
      flags.set1(kI);
      expect(flags[kA] && flags[kH] && flags[kD] && flags[kI], isTrue);
    });
  });
  group('Diagnostics :: ', () {
    final flags = Toggler();

    setUp(() {
      flags.bits = flags.hh = flags.ds = flags.rg = flags.chb = 0;
    });
    test('Err/Done set true', () {
      flags.error = true;
      flags.done = true;
      expect(flags.error, isTrue);
      expect(flags.done, isTrue);
    });
    test('Err/Done set false', () {
      flags.error = true;
      flags.done = true;
      flags.error = false;
      flags.done = false;
      expect(flags.error, isFalse);
      expect(flags.done, isFalse);
      flags.markDone();
      expect(flags.done, isTrue);
    });
    test('Demand bad diff| should throw', () {
      expect(() {
        flags.differsFrom(flags.state(), bLast: 63);
      }, throwsAssertionError);
    });
  });
  group('Done and history :: ', () {
    int ntlast = 0;
    int filast = 0;
    void chnote(Toggler oS, Toggler nS) => ntlast++;

    bool chfix(Toggler oS, Toggler nS) {
      filast++;
      return true;
    }

    final flags = Toggler();
    const ohh = 7777777777;
    setUp(() {
      flags.bits = flags.hh = flags.ds = flags.rg = flags.chb = 0;
      flags.hh = ohh;
      flags.fix = chfix;
      flags.after = chnote;
      ntlast = 0;
      filast = 0;
    });

    test('no history changes', () {
      flags.after = null;
      flags.fix = null;
      flags.toggle(5);
      expect(flags[5] && flags.hh == ohh, isTrue);
    });
    test('done is cleared with copy', () {
      flags.markDone();
      final c1 = flags.state();
      expect(flags != c1, isTrue);
      expect(flags.done, isTrue);
      expect(c1.done, isFalse);
    });
    test('done is cleared with clone', () {
      flags.markDone();
      final c1 = flags.clone();
      expect(flags.done, isTrue);
      expect(c1.done, isFalse);
    });
    test('done is cleared on copy of copy', () {
      final c1 = flags.state();
      c1.done = true;
      expect(c1.done, isTrue);
      final c2 = c1.state();
      expect(c2.done, isFalse);
    });
    test('history changes with just fix', () {
      flags.after = null;
      flags.toggle(5);
      expect(flags[5], isTrue);
      expect(flags.hh != ohh, isTrue);
      expect(filast, equals(1));
    });
    test('history changes with just notify', () {
      flags.fix = null;
      flags.toggle(5);
      expect(flags[5] && flags.hh != ohh, isTrue);
      expect(ntlast, equals(1));
    });
    test('history changes with just notifier', () {
      flags.fix = null;
      flags.after = null;
      flags.notifier = TCNo();
      flags.toggle(5);
      expect(flags[5] && flags.hh != ohh, isTrue);
    });
    test('done is cleared on fix only', () {
      flags.after = null;
      expect(flags.done, isFalse);
      flags.markDone();
      expect(flags.done, isTrue);
      flags.toggle(5);
      expect(flags.done, isFalse);
      flags.done = true;
      expect(flags.done, isTrue);
      flags.toggle(5);
      expect(flags.done, isFalse);
      expect(!flags[5] && flags.hh != ohh, isTrue);
      expect(ntlast, equals(0));
      expect(filast, equals(2));
    });
    test('done is cleared on notify only', () {
      flags.fix = null;
      expect(flags.done, isFalse);
      flags.markDone();
      expect(flags.done, isTrue);
      flags.toggle(5);
      expect(flags.done, isFalse);
      flags.done = true;
      expect(flags.done, isTrue);
      flags.toggle(5);
      expect(flags.done, isFalse);
      expect(!flags[5] && flags.hh != ohh, isTrue);
      expect(ntlast, equals(2));
      expect(filast, equals(0));
    });
    test('done is cleared on notifier only', () {
      flags.fix = null;
      flags.after = null;
      flags.notifier = TCNo();
      expect(flags.done, isFalse);
      flags.markDone();
      expect(flags.done, isTrue);
      flags.toggle(5);
      expect(flags.done, isFalse);
      flags.done = true;
      expect(flags.done, isTrue);
      flags.toggle(5);
      expect(flags.done, isFalse);
      expect(!flags[5] && flags.hh != ohh, isTrue);
    });
    test('notifier should fire alone', () {
      var noo = TCNo();
      flags.fix = null;
      flags.after = null;
      flags.notifier = noo;
      flags.toggle(5);
      expect(flags.chb == noo.seen, isTrue);
      expect(noo.seen, equals(1 << 5));
    });
    test('notifier may not fire if notify handler is present', () {
      var noo = TCNo();
      flags.fix = null;
      flags.notifier = noo;
      flags.toggle(5);
      expect(flags.chb == noo.seen, isFalse);
      expect(noo.seen, equals(0));
    });
    test('brand may not change with history', () {
      flags.hh = 0xff << 8;
      flags.toggle(49);
      flags.toggle(50);
      flags.toggle(51);
      expect(flags.hh >> 8 == 0x3ff, isTrue);
    });
    test('live state on hold may never change', () {
      final flags = Toggler();
      expect(flags.fixed, isTrue);
      flags.fix = null;
      flags.after = null;
      var noo = TCNo();
      flags.notifier = noo;
      flags.hold();
      flags.set1(5);
      expect(noo.seen, equals(0));
      expect(flags.bits, equals(0));
      flags.resume();
      flags.toggle(5);
      expect(flags.fixed, isTrue);
      expect(flags.chb == noo.seen, isTrue);
      expect(noo.seen, equals(1 << 5));
    });
    /*
    */
  });
  group('Signalling :: ', () {
    late Toggler flags;
    late Model m0;
    late Model m1;
    late Model m2;
    int last = 0;
    int fixes = 0;
    void chnote(Toggler oS, Toggler cS) => last++;

    bool chfix(Toggler oS, Toggler nS) {
      fixes++;
      return true;
    }

    setUp(() {
      flags = Toggler(after: chnote, fix: chfix); // make anew
      m0 = Model(0, flags);
      m1 = Model(1, flags);
      m2 = Model(2, flags);
    });
    test('Simple Signals', () {
      m0.val = 2;
      expect(flags.chb, equals(1));
      expect(fixes, equals(1));
      m1.val = 3;
      expect(flags.chb, equals(2));
      m2.val = 1;
      expect(flags.chb, equals(4));
    });
    test('set value on fix throws', () {
      bool cf(Toggler oS, Toggler nS) {
        expect(flags.signalsComing, equals(1));
        m1.val = 1;
        expect(flags.signalsComing, equals(3));
        m2.val = 11;
        expect(flags.signalsComing, equals(7));
        return true;
      }

      flags.fix = cf;
      expect(() => m0.val = 2, throwsAssertionError);
    });

    test('outer signal makes to us', () {
      int fixes = 0;
      bool cf(Toggler oS, Toggler nS) {
        expect(oS.signalsComing, equals(1));
        m1.val = 1;
        expect(oS.signalsComing, equals(3));
        m2.val = 2;
        expect(oS.signalsComing, equals(7));
        fixes++;
        return true;
      }

      flags.fix = cf;

      m0.val = 2;
      expect(fixes, equals(1));
      expect(flags.chb, equals(7));
    });

    test('clearSignal mask works', () {
      int fixes = 0;
      bool cf(Toggler oS, Toggler nS) {
        expect(oS.signalsComing, equals(1));
        m1.val = 1;
        expect(oS.signalsComing, equals(3));
        m2.val = 2;
        expect(oS.signalsComing, equals(7));
        oS.fixSignal(1, false);
        fixes++;
        return true;
      }

      flags.fix = cf;

      m0.val = 2;
      expect(fixes, equals(1));
      expect(flags.chb, equals(5)); // 1 masked
    });
  });

  group('FixNotifyRaces :: ', () {
    int last = 0;
    void chnote(Toggler oS, Toggler nS) => last++;

    bool chfix(Toggler oS, Toggler nS) {
      if (oS.recent == 25) {
        oS.hh <<= 1; // test abandon older state
      }
      oS.differsFrom(nS, bFirst: 11, bLast: 16); // cover !differs path
      if (nS[1] && nS.differsFrom(oS)) nS.set1(0); // test state fixing on 1
      if (nS[7] && nS.differsFrom(oS)) nS.markDone(); // test skip notify on 7
      if (nS[9] && nS.differsFrom(oS)) nS.done = true; // test skip notify on 9
      return true;
    }

    final flags = Toggler(after: chnote, fix: chfix);

    setUp(() {
      flags.bits = flags.ds = flags.rg = flags.hh = 0; // reset
    });
    test('Notify 0', () {
      flags.set1(0);
      expect(flags[0] && !flags[1], isTrue);
      expect(last == 1, isTrue);
    });
    test('Notify 1', () {
      flags.set1(1);
      expect(last == 2, isTrue);
      expect(flags[0] && flags[1], isTrue);
    });
    test('Notify via clone', () {
      var nf = flags.clone();
      nf.set1(5);
      expect(nf[5] && !flags[5], isTrue);
      expect(last == 3, isTrue);
    });
    test('Internal fix', () {
      flags.set1(7);
      expect(last == 3, isTrue); // notify skipped, setDone()
      flags.set1(9);
      expect(last == 3, isTrue); // notify skipped, done = true
    });
    /* XXX no reentrant races now */
    test('Make artificial race | should throw', () {
      expect(() {
        flags.set1(25);
        flags.set1(0);
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
