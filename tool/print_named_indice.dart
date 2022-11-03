// ignore_for_file: avoid_print

/// You may scaffold your tg_names.dart by running this script:
/// \$> dart run tool/print_named_indice.dart > lib/src/tg_names.dart

enum Kind { model, bits, none }

Kind sel = Kind.none;
bool bare = false;
bool wnum = false;
bool uhlp = false;
int count = 16;
int start = 0;
int max = 0;
int min = 0;
String core = 'ReNameMe';
String sufix = '';
String prefix = '';
var names = <String>[];

void main(List<String> argi) {
  for (final arg in argi) {
    if (arg == 'model') {
      start = 100;
      max = 255;
      sel = Kind.model;
      continue;
    }
    if (arg == 'bits') {
      start = 0;
      max = 52;
      sel = Kind.bits;
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
    if (arg.contains(RegExp('addnum'))) {
      wnum = true;
      continue;
    }
    if (arg.contains(RegExp('-h'))) {
      uhlp = true;
      continue;
    }
    if (arg.codeUnitAt(0) < 0x5b && arg.codeUnitAt(0) > 0x40) names.add(arg);
  }
  if (uhlp) sel = Kind.none;
  switch (sel) {
    case Kind.model:
      max = 255;
      if (start < 64) {
        print('// BEWARE: model indice in bits-indice range!');
      }
      models();
      break;
    case Kind.bits:
      max = 52;
      start = start > max ? max - 1 : start;
      count = start + count > max ? max - start : count;
      tgBits();
      break;
    case Kind.none:
      help();
      break;
  }
}

void help() {
  print('''
Usage: bits|model [opts] [NameA NameB...]
    bits  print bit indice and their select mask
   model  print model indice

  If Names are given print using them, for their count.
  Name must begin with A-Z ascii character. It will be prefixed with Toggler
  defaults: b for bit index, s for select bit mask, m for model index.
 opts:
      max:$max\tnot above this number
    start:$start\tfrom this number
    count:$count\tthat many
   prefix:$prefix\tadd prefix
    sufix:$sufix\tadd sufix
     core:$core - A single name for search-replace later
   addnum: add tailing numbers to user provided names
''');
}

void models() {
  if (names.isNotEmpty) {
    int n = start;
    for (final v in names) {
      print('const m$prefix$v${wnum ? n : ''}$sufix = $n;');
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
  if (!bare && names.isEmpty) {
    print('''
// Toggler works best with named indice. You generated them, hopefully to
// conventional 'tg_names.dart' file. Now you should make use of your editor
// select consecutive two lines and rename "ReNameMe#" (no b and s prefice!)
// to any meaningful name you want. Enjoy!
''');
    print(
        "// rename below with 'search & replace' to keep 'b' and 's' prefixes ");
  }
  int n = start;
  if (names.isNotEmpty) {
    for (final v in names) {
      final cna = '$prefix$v${wnum ? n : ''}$sufix';
      print('const b$cna = $n;');
      print('const s$cna = 1 << b$cna;');
      n++;
      if (n > max) {
        print('// ----------- max:$max reached, can not continue ------------');
        break;
      }
    }
  } else {
    for (n = start; n <= start + count; n++) {
      print('const b$prefix$core$n$sufix = $n;');
      print('const s$prefix$core$n$sufix = 1 << b$prefix$core$n$sufix;');
    }
  }
  if (!bare && names.isEmpty) {
    print('''
// keep bFreeIndex updated to be 1 over your last bit index
// then sAll mask will cover just bits you use, not more
    const bFreeIndex = $n;
    const sAll = (1 << bFreeIndex) - 1;
    const sNone = 0;'
''');
  }
}
