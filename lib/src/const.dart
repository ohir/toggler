export "const.dart" if (dart.library.io) 'const64.dart';

/// max usable index of a state bit. Web:31, Native:62
const bIndexMax = 31; // web
/// mask to select all state bits
const sMaskAll = 0xffffffff; // web
/// true in dart2js compilations, false on native
const kWeb = true;

// Error: The integer literal can't be represented exactly in JavaScript.
// const internal = kWeb ? shortmask : longmask; // does not work
/// internal thing, must be public as Dart tools lack capabilty to do a real
/// conditional compilation.  See https://github.com/dart-lang/sdk/issues/33249
/// ```
/// const mTogglerPlatformMask = 0x7fffffffffff01ff; // 63bit native
/// const mTogglerPlatformMask =   0x1fffffffff01ff; // 52bit js
/// ```
const mTogglerPlatformMask = 0x1fffffffff01ff; // web
