// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

import 'package:toggler/toggler.dart';
import 'package:test/test.dart';

final Matcher throwsAssertionError = throwsA(isA<AssertionError>());

class TCNo extends ToggledNotifier {
  int seen = 0;
  @override
  void pump(int chb) => seen = chb;
  void reset() => seen = 0;
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
      flags.notifier = flags.after = flags.fix = null;
    });

    test('Set 0 Max', () {
      flags[0] = true; // cover []= setter
      flags.set1(bIndexMax);
      expect(flags[0] && !flags[1] && !flags[bIndexMax - 1] && flags[bIndexMax],
          isTrue);
      flags.set0(0);
      flags.set0(bIndexMax);
      expect(!flags[0] && !flags[bIndexMax], isTrue);
    });
    test('Disable/enable 0 Max', () {
      flags.disable(0);
      expect(flags.active(0), isFalse);
      flags.disable(bIndexMax);
      expect(flags.active(bIndexMax), isFalse);
      flags.enable(0);
      expect(flags.active(0), isTrue);
      flags.enable(bIndexMax);
      expect(flags.active(bIndexMax), isTrue);
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
      flags.set0(bIndexMax, ifActive: true);
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
    test('DisableEnable bIndexMax', () {
      flags.set1(bIndexMax, ifActive: true);
      flags.disable(bIndexMax);
      flags.set0(bIndexMax, ifActive: true);
      expect(flags[bIndexMax], isTrue);
      flags.setTo(bIndexMax, false, ifActive: true);
      expect(flags[bIndexMax], isTrue);
      flags.enable(bIndexMax);
      flags.set0(bIndexMax, ifActive: true);
      expect(flags[bIndexMax], isFalse);
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
    test('serial must go up on live', () {
      var cLive = Toggler(fix: (liveState, newState) => true);
      var c0 = cLive.state();
      var c1 = cLive.state();
      cLive[7] = true;
      var c2 = cLive.state();
      expect(cLive.recent, equals(7));
      expect(c0.serial, equals(cLive.serial - 1));
      c1[3] = true;
      c2[9] = true;
      expect(c0.hh == c1.hh, isTrue); // copies may not alter history
      expect(c0.serial, equals(c1.serial));
      expect(c1.recent, equals(0));
      expect(c2.recent, equals(7));
    });
    test('refused may not alter state', () {
      var cLive = Toggler(fix: (liveState, newState) => false);
      var c0 = cLive.state();
      cLive[7] = true;
      expect(cLive.hh, equals(c0.hh)); // refused may not alter
      expect(cLive.ds, equals(c0.ds));
      expect(cLive.bits, equals(c0.bits));
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
      flags.notifier = TCNo(); // now only live objects update chb
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
      flags.set1(bIndexMax - 1);
      flags.disable(bIndexMax); // cm must reflect any change at index
      expect(flags.chb == 1 << bIndexMax, isTrue);
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
    test('Set flag position | should throw', () {
      expect(() {
        flags.set1(bIndexMax + 1);
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
      expect(bIndexMax, equals(62));
      expect(() {
        flags.differsFrom(flags.state(), bLast: bIndexMax + 1);
      }, throwsAssertionError);
    });
  });
  group('Done and history :: ', () {
    int ntCnt = 0;
    int fixCnt = 0;
    void chnote(Toggler nS) => ntCnt++;

    bool chfix(Toggler oS, TransientState nS) {
      fixCnt++;
      return true;
    }

    Toggler flags = Toggler();
    const ohh = 0xabcdef0000;
    setUp(() {
      // flags.bits = flags.hh = flags.ds = flags.rg = flags.chb = 0;
      flags = Toggler();
      flags.hh = ohh;
      flags.fix = chfix;
      flags.after = chnote;
      ntCnt = 0;
      fixCnt = 0;
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
      expect(fixCnt, equals(1));
    });
    test('history changes with just notify', () {
      flags.fix = null;
      flags.toggle(5);
      expect(flags[5] && flags.hh != ohh, isTrue);
      expect(ntCnt, equals(1));
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
      expect(flags[5], isTrue);
      expect(flags.done, isFalse);
      flags.done = true;
      expect(flags.done, isTrue);
      flags.toggle(5);
      expect(flags[5], isFalse);
      expect(flags.done, isFalse);
      expect(fixCnt, equals(2));
      expect(ntCnt, equals(0));
      flags.disable(0);
      expect(flags.active(0), isFalse);
      expect(fixCnt, equals(3));
      flags.disable(bIndexMax);
      expect(flags.active(bIndexMax), isFalse);
      expect(fixCnt, equals(4));
      flags.enable(0);
      expect(flags.active(0), isTrue);
      expect(fixCnt, equals(5));
      flags.enable(bIndexMax);
      expect(flags.active(bIndexMax), isTrue);
      expect(fixCnt, equals(6));
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
      expect(ntCnt, equals(2));
      expect(fixCnt, equals(0));
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
      expect(flags.chb, equals(32));
      expect(noo.seen, equals(0));
    });
    test('live state on hold may never change', () {
      final flags = Toggler();
      expect(flags.isFixed, isTrue);
      flags.fix = null;
      flags.after = null;
      var noo = TCNo();
      flags.notifier = noo;
      flags.hold();
      expect(flags.held, isTrue);
      flags.set1(5);
      expect(noo.seen, equals(0));
      expect(flags.bits, equals(0));
      flags.resume();
      flags.toggle(5);
      expect(flags.isFixed, isTrue);
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
    void chnote(Toggler cS) => last++;
    bool chfix(Toggler oS, TransientState nS) {
      fixes++;
      last++;
      expect(nS.signalTag, equals(0));
      return true;
    }

    setUp(() {
      flags = Toggler(after: chnote, fix: chfix); // make anew
      m0 = Model(0, flags);
      m1 = Model(1, flags);
      m2 = Model(2, flags);
      fixes = last = 0;
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
    test('Returning signal', () {
      void bk() => flags.signal(5);
      Toggler cpy = Toggler();
      int bkval = 0;
      bool cf(Toggler oS, TransientState nS) {
        bk();
        oS.copyStateTo(cpy);
        bkval = nS.signals;
        return true;
      }

      flags.fix = cf;
      flags.set1(0);
      flags.disable(1);
      expect(flags.bits, equals(1));
      expect(flags.ds, equals(2));
      expect(bkval, equals(32));
    });
    test('Returning set1', () {
      void bk() => flags.set1(5); // b5
      Toggler cpy = Toggler();
      int bkval = 0;
      bool cf(Toggler oS, TransientState nS) {
        oS.copyStateTo(cpy);
        expect(flags.bits, equals(0));
        expect(oS.bits, equals(0));
        bk(); // 32
        expect(oS.bits, equals(0));
        bkval = nS.bits;
        return true;
      }

      flags.fix = cf;
      expect(flags.bits, equals(0));
      flags.set1(0); // 5 + 0 -> 33
      // flags.disable(1);
      expect(flags.bits, equals(33));
      //expect(flags.ds, equals(2));
      expect(bkval, equals(33)); // +b0
    });
    test('Returning set0', () {
      Toggler flags = Toggler(bits: 36); // b5 b2
      int fired = 0;
      void bk() => flags[5] = false;
      bool cf(Toggler oS, TransientState nS) {
        expect(fired, equals(0));
        expect(nS.bits, equals(37));
        bk(); // b5->0
        expect(nS.bits, equals(5));
        fired++;
        return true;
      }

      flags.fix = cf;
      flags.set1(0);
      expect(flags.bits, equals(5)); // !32+4+1
    });
    test('Returning disable', () {
      Toggler flags = Toggler(bits: 8, ds: 8);
      void bk() => flags.disable(0);
      int bkval = 0;
      bool cf(Toggler oS, TransientState nS) {
        bk();
        bkval = nS.ds;
        return true;
      }

      flags.fix = cf;
      flags.set1(0);
      expect(flags.bits, equals(9)); // 8+1
      expect(flags.ds, equals(9)); // 8+1
      expect(bkval, equals(9)); // -b5
    });
    test('Modify from after', () {
      Toggler flags = Toggler(bits: 8, ds: 8);
      void bk(int what) {
        if (what == 0) flags.set0(0);
        if (what == 1) flags.set1(0);
        if (what == 2) flags.disable(0);
      }

      void af(Toggler cur) => bk(cur.recent);
      flags.after = af;
      expect(() => flags.set1(1), throwsAssertionError);
      expect(() => flags.set0(0), throwsAssertionError);
      expect(() => flags.disable(2), throwsAssertionError);
    });

    test('outer signal makes to us', () {
      int fixes = 0;
      bool cf(Toggler oS, TransientState nS) {
        expect(nS.signals, equals(1));
        m1.val = 1;
        expect(nS.signals, equals(3));
        m2.val = 2;
        expect(nS.signals, equals(7));
        fixes++;
        return true;
      }

      flags.fix = cf;

      m0.val = 2;
      expect(fixes, equals(1));
      expect(flags.chb, equals(7));
    });

    test('fixSignal works', () {
      int fixes = 0;
      bool cf(Toggler oS, TransientState nS) {
        expect(nS.signals, equals(1));
        m1.val = 1;
        expect(nS.signals, equals(3));
        m2.val = 2;
        expect(nS.signals, equals(7));
        nS.fixOutSignal(1, false); // clear 2
        nS.fixOutSignal(4, true); // set 16
        fixes++;
        return true;
      }

      flags.fix = cf;

      m0.val = 2;
      expect(fixes, equals(1));
      expect(flags.chb, equals(21)); // 1 => 0, 4 => 1
    });
  });

  group('FixNotify :: ', () {
    int last = 0;
    void chnote(Toggler nS) => last++;

    bool chfix(Toggler oS, TransientState nS) {
      oS.differsFrom(nS, bFirst: 11, bLast: 16); // cover !differs path
      if (nS[1] && nS.differsFrom(oS)) nS.set1(0); // test state fixing on 1
      if (nS[7] && nS.differsFrom(oS)) {
        nS.skipAfterAndNotify(); // test skip notify on 7
      }
      if (nS[9] && nS.differsFrom(oS)) nS.done = true; // test skip notify on 9
      if (nS[8]) {
        nS[14] = true;
        nS[14] = false;
      }
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
    test('Add to newS', () {
      last = 1;
      flags.set1(8);
      expect(last, equals(2));
      expect(flags[8], isTrue);
      expect(flags[14], isFalse);
    });
    test('Set newS.done skips notify', () {
      last = 3;
      flags.set1(7);
      expect(last, equals(3)); // notify skipped, setDone()
      flags.set1(9);
      expect(last, equals(3)); // notify skipped, setDone()
    });
    test('on hold works', () {
      last = 0;
      flags.set1(6);
      flags.hold();
      flags.set1(2);
      flags.set1(3);
      flags.set1(4);
      flags.resume();
      expect(last, equals(1));
      expect(flags.bits, equals(64));
    });
  });
  group('OldState :: ', () {
    late Toggler flags;

    setUp(() {
      flags = Toggler();
    });
    test('Serial, supress', () {
      flags.fix = (Toggler oS, TransientState nS) {
        nS.bits = 0x17f; // b8 ~b7 b6..b0
        // signal 9              b9 -> 1
        flags.signal(7); //      b7 -> 1
        nS.supressOutAt(8); //   b8 -> 0
        nS.clearComingAt(9); // !b9
        //                       255
        expect(nS.signalTag, equals(33)); // tag 33
        expect(nS.serial, equals(0)); // but serial 0
        return true;
      };
      flags.signal(8, tag: 33);
      expect(flags.chb, equals(255));
    });
    test('bad set on live', () {
      flags.fix = (Toggler oS, TransientState nS) {
        expect(nS.bits, equals(0));
        expect(nS[10], isFalse);
        oS[10] = true; // should pass to nS
        expect(nS[10], isTrue);
        nS.set1(0);
        return true;
      };
      expect(flags.bits, equals(0));
      flags.signal(8, tag: 33);
      expect(flags.bits, equals(1025)); // 10 + 0
    });
    test('Set1', () {
      // (OldState oS, Toggler nS) => ;
      flags.fix = (Toggler oS, TransientState nS) {
        nS.set1(oS.recent); //        b0  1
        nS.set1(nS.recent); //        b1  2
        nS.set1(nS.recent + 1); //    b2  4
        nS.set1(nS.recent + 2); //    b3  8
        //                           --- 15
        nS.fixOutSignal(2, false); //   ~b2  4 -> 0
        nS.fixOutSignal(4, true); //     b4   -> 16
        nS.disable(nS.signalTag); // b11 -> 2048
        flags.signal(2, tag: 33); // ------ 2067
        flags.signal(3, tag: 61); //  b3 -> 8
        //                           ------ 2075
        expect(nS.signalTag, equals(11)); // only firing
        expect(nS.recent, equals(1));
        return true;
      };
      flags.signal(1, tag: 11);
      expect(flags.error, isFalse);
      expect(flags.active(11), isFalse);
      expect(flags.bits, equals(15));
      expect(flags.chb, equals(2075)); // b11,
    });
    test('Break fuse', () {
      flags.after = (Toggler nS) {
        flags.signal(5);
      };
      flags.fix = (Toggler oS, TransientState nS) {
        flags.signal(7); //      b7 -> 1
        return true;
      };
      // expect(() => flags.set1(8), returnsNormally);
      expect(() => flags.set1(8), throwsAssertionError);
    });
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
