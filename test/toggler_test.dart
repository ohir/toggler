import 'package:toggler/toggler.dart';
import 'package:test/test.dart';

final Matcher throwsAssertionError = throwsA(isA<AssertionError>());

void main() {
  group('Rudimentary', () {
    final flags = Toggler();

    setUp(() {
      flags.tg = flags.ds = flags.rm = flags.hh = 0; // reset
      // Additional setup goes here.
      // flags.radioGroup(1, 3);
      // flags.radioGroup(5, 7);
    });

    test('Set 0 62', () {
      flags.set(0);
      flags.set(62);
      expect(flags[0] && flags[62], isTrue);
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
