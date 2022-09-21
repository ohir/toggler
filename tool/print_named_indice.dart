import 'package:toggler/toggler.dart';

/// You may scaffold your tg_names.dart by running this script:
/// \$> dart run tool/print_named_indice.dart > lib/src/tg_names.dart

void main() {
  print('''
// Toggler works best with named indice. You generated it, hopefully to
// conventional 'tg_names.dart' file. Now you should make use of your editor
// and rename "ReNameMeNUM" (without prefice!) to a meaningful name you want.
// Enjoy!

// keep tgFreeIndex updated to be 1 over your last renamed index''');
  print('const tgFreeIndex = $tgIndexMax;');
  print('// then smAll mask will cover just bits you use, not more');
  print('const smAll = (1 << tgFreeIndex) - 1;');
  print(
      "// rename below with 'search & replace' to keep 'tg' and 'sm' prefixes ");

  int n = 0;
  for (; n < tgIndexMax; n++) {
    print('const tgReNameMe$n = $n;');
    print('const smReNameMe$n = 1 << tgReNameMe$n;');
  }
}
