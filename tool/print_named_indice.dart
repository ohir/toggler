// ignore_for_file: avoid_print

import 'package:toggler/toggler.dart';

/// You may scaffold your tg_names.dart by running this script:
/// \$> dart run tool/print_named_indice.dart > lib/src/tg_names.dart

bool model = false;
bool bare = false;
int start = 10;
int count = 16;
int max = 52;
int nMax = 52;
int min = 0;
String core = 'ReNameMe';
String sufix = '';
String prefix = '';
var names = <String>[];

void main(List<String> argi) {
  for (final arg in argi) {
    if (arg == 'model') {
      model = true;
      continue;
    }
    if (arg == 'bare') {
      bare = true;
      continue;
    }
    if (arg.startsWith(RegExp('count[:=][0-9]'))) {
      count = int.parse(arg.substring(6));
      continue;
    }
    if (arg.startsWith(RegExp('start[:=][0-9]'))) {
      start = int.parse(arg.substring(6));
      continue;
    }
    if (arg.startsWith(RegExp('max[:=][0-9]'))) {
      max = int.parse(arg.substring(4));
      continue;
    }
    if (arg.startsWith(RegExp('prefix[:=]'))) {
      prefix = arg.substring(7);
      continue;
    }
    if (arg.startsWith(RegExp('sufix[:=]'))) {
      sufix = arg.substring(6);
      continue;
    }
    if (arg.startsWith(RegExp('core[:=]'))) {
      core = arg.substring(5);
      continue;
    }
    if (arg.contains(RegExp('-h'))) {
      help();
      return;
    }
    if (arg.codeUnitAt(0) < 0x5b && arg.codeUnitAt(0) > 0x40) names.add(arg);
  }
  if (model) {
    min = 128;
    nMax = 256;
    max = max > nMax ? nMax : max;
    max = max < min ? nMax : max;
    sane();
    models();
  } else {
    min = 0;
    nMax = 52;
    sane();
    tgBits();
  }
}

void sane() {
  max = max < min ? min : max;
  max = max > nMax ? nMax : max;
  start = start < min ? min : start;
  start = start > nMax ? nMax : start;
  count = start + count > nMax ? nMax - start : count;
  start = start < min ? min : start;
}

void help() {
  print('''
Usage: [model] [opts] [NameA NameB...]
 default  print bit indice and their select mask
   model  print model indice
          if Names are given print using them, for their count:
          Name must begin with A-Z ascii character
 opts:
      max:$max\tnot above this number
    start:0\tfrom this number. For "model" default is 128
    count:$count\tthat many
   prefix:$prefix\tadd prefix
    sufix:$sufix\tadd sufix
     core:$core; (search-replace template)
''');
}

void models() {
  if (names.isNotEmpty) {
    int n = start;
    for (final v in names) {
      print('const m$prefix$v$sufix = $n;');
      n++;
      if (n > max) {
        print('// ----------- max:$max reached, can not continue ------------');
        break;
      }
    }
  } else {
    for (int n = start; n <= start + count; n++) {
      print('const m$prefix$core$n$sufix = $n;');
    }
  }
}

void tgBits() {
  if (!bare) {
    print('''
// Toggler works best with named indice. You generated them, hopefully to
// conventional 'tg_names.dart' file. Now you should make use of your editor
// select consecutive two lines and rename "ReNameMe#" (no b and s prefice!)
// to any meaningful name you want. Enjoy!

// keep bFreeIndex updated to be 1 over your last renamed index''');
    print('const bFreeIndex = ${max + 1};');
    print('// then sAll mask will cover just bits you use, not more');
    print('const sAll = (1 << bFreeIndex) - 1;');
    print('const sNone = 0;');
    print(
        "// rename below with 'search & replace' to keep 'b' and 's' prefixes ");
  }
  if (names.isNotEmpty) {
    int n = start;
    for (final v in names) {
      print('const b$prefix$v$sufix = $n;');
      print('const s$prefix$v$sufix = 1 << b$prefix$v$sufix;');
      n++;
      if (n > max) {
        print('// ----------- max:$max reached, can not continue ------------');
        break;
      }
    }
  } else {
    for (int n = start; n <= start + count; n++) {
      print('const b$prefix$core$n$sufix = $n;');
      print('const s$prefix$core$n$sufix = 1 << b$prefix$core$n$sufix;');
    }
  }
}
