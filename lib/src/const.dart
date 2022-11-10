export "const.dart" if (dart.library.io) 'const64.dart';

/// max usable index of a state bit. Web:31, Native:62
const bIndexMax = 31; // web
/// mask to select all state bits
const sMaskAll = 0xffffffff; // web
/// true in dart2js compilations, false on native
const kIsWeb = true;

// Error: The integer literal can't be represented exactly in JavaScript.
// const internal = kIsWeb ? shortmask : longmask; // does not work
/// internal thing, must be public as Dart tools lack capabilty to do a real
/// conditional compilation.  See https://github.com/dart-lang/sdk/issues/33249
/// ```
/// // 63 bit, native
/// const bIndexMax            = 62;
/// const kIsWeb               = false;
/// const sMaskAll             = 0x7fffffffffffffff;
/// const sTogglerPlatformMask = 0x7fffffffffff01ff;
///
/// // js compat, 52/32 bit
/// const bIndexMax            = 31;
/// const kIsWeb               = true;
/// const sMaskAll             = 0x00000000ffffffff;
/// const sTogglerPlatformMask = 0x000fffffffff01ff;
/// ```
const sTogglerPlatformMask = 0x000fffffffff01ff; // 52bit js
