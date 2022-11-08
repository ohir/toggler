export "const.dart" if (dart.library.io) 'const64.dart';

/// max usable index of a state bit. Web:31, Native:62
const bIndexMax = 31; // web
/// mask to select all state bits
const sMaskAll = 0xffffffff; // web

/// internal thing, must be public as Dart tools lack capabilty to do a real
/// conditional compilation.  See https://github.com/dart-lang/sdk/issues/33249
/// ```
/// Error: The integer literal can't be represented exactly in JavaScript.
/// const internal = kWeb ? shortmask : longmask; // does not work
/// ```
const mTogglerPlatformMask = 0x1fffffffff00ff; // web
