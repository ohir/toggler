// ignore_for_file: avoid_print

import 'package:toggler/toggler.dart';

/// You may scaffold your tg_names.dart by running this script:
/// \$> dart run tool/print_named_indice.dart > lib/src/tg_names.dart

void main() {
  print('''
// Toggler works best with named indice. You generated them, hopefully to
// conventional 'tg_names.dart' file. Now you should make use of your editor
// select consecutive two lines and rename "ReNameMe#" (no b and s prefice!)
// to any meaningful name you want. Enjoy!

// keep biFreeIndex updated to be 1 over your last renamed index''');
  print('const bFreeIndex = $bIndexMax;');
  print('// then sAll mask will cover just bits you use, not more');
  print('const sAll = (1 << biFreeIndex) - 1;');
  print('const sNone = 0;');
  print(
      "// rename below with 'search & replace' to keep 'tg' and 'sm' prefixes ");

  int n = 0;
  for (; n < bIndexMax; n++) {
    print('const bReNameMe$n = $n;');
    print('const sReNameMe$n = 1 << bReNameMe$n;');
  }
}
