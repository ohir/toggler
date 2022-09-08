/// Toggler keeps state of up to 63 items (flags) with built-in support for
/// _radio-button_ type groups and for independent _enable_/_disable_ semantics
/// of GUI use.  Each Toggler item on/off state can be retrieved using index[]
/// operator, usually using symbolic names (const ints in 0..62 range).
///
/// Toggler library supports pre-commit state validation and fixes, and after
/// new state is applied the outer code will be notified.
///
/// `Toggler` is small, has no dependecies, not even on a `dart:` libraries,
/// and is meant to be used in "ambient" (singleton based) Models. For this
/// `Toggler` supports data race detection, abiding to "abandon older" principle.
library toggler;

/// class Toggler {
/// ```
///   tg: int items_state    (0: false/cleared,  1: true/set)
///   ds: int items_active,  (0: active/enabled, 1: inactive/disabled)
///   rm: int grouping,      (1: a radio group member)
///   hh: int history_hash,  (hi 33b change counter, lo 30b changes history)
///   checkFix:  bool validator(oldState, newState)
///   notify:    void  notifier(oldState, current)
/// ```
/// }
class Toggler {
  /// items state (0:off/cleared, 1:on/set)
  int tg;

  /// disabled state (0:enabled/active, 1:disabled/inactive)
  int ds;

  /// radio groups configuration (1: marks a radio group member)
  int rm;

  /// history hash, updated for "live" Toggler (ie. having a non-null notifier).
  /// Hh keeps changes 33b counter and a list of 5 most recent changes indice.
  /// Hh is guaranteed to be unique for over 8 billion toggles, thus it can be
  /// used to seed ValueNotifiers in 'observer' based App state management.
  /// See Flutter example.
  int hh;

  /// CheckFix validator: `bool checkFix(Toggler oldState, Toggler newState)`
  /// If checkFix returns false changes to the live Toggler are abandoned.
  ///
  /// CheckFix may mutate newState prior to returning. Any changes made will be
  /// applied to the live Toggler object in a single run upon 'true' return:
  ///
  /// ```Dart
  /// bool checkFix(Toggler oS, Toggler nS) {
  ///   // ...perform checks...
  ///   // ...seems that backend altered the kTG_freeUser flag...
  ///
  ///   if (nS[kTG_freeUser] && nS.hasActive(kTG_doNotShowBanners)) {
  ///     // disable Ad opt-outs for free users:
  ///     nS.disable(kTG_doNotShowBanners);
  ///     nS.disable(kTG_doNotShowInterst);
  ///     nS.clear(kTG_doNotShowBanners);
  ///     nS.clear(kTG_doNotShowInterst);
  ///   }
  ///   return true; // apply changes
  /// }
  /// ```
  TogglerValidateFix? checkFix;

  /// change notifier function `void Function(Toggler current)`;
  /// If notifier is set, Toggler object is said to be "live" one, otherwise
  /// it is just a state object.
  TogglerChangeNotify? notify;

  /// ```
  ///   checkFix: verify and fix state   checkFix(oldState, newState)
  ///     notify: call after change         notify(oldState, current)
  ///      state: tg, ds, rm
  ///   identity: hh                 unique for each next notify call
  /// ```
  /// )
  Toggler({
    this.checkFix,
    this.notify,
    this.tg = 0,
    this.ds = 0,
    this.rm = 0,
    this.hh = 0,
  });

  void _seterr() => tg |= 1 << 63; // clear with: x.tg = x.tg.toUnsigned(63);

  int _v(int i) {
    assert(i < 63 && i >= 0, 'Toggler index ($i) out of range!');
    if (i > 62 || i < 0) _seterr();
    return i.toUnsigned(6);
  }

  void _ckFix(int i, int nEW, bool isDs) {
    final oldS = Toggler(tg: tg, ds: ds, rm: rm, hh: hh);
    if (checkFix != null) {
      final newS =
          Toggler(tg: isDs ? tg : nEW, ds: isDs ? nEW : ds, rm: rm, hh: hh);
      if (checkFix!(oldS, newS)) {
        if (hh != newS.hh) {
          ds |= 1 << 63; // clear with: x.ds = x.ds.toUnsigned(63);
          _seterr();
          assert(hh == newS.hh,
              'Data race detected on _ckFix update! [hh: ${hh.toUnsigned(30)}]');
          return;
        }
        tg = newS.tg;
        ds = newS.ds;
        rm = newS.rm;
      }
    } else {
      isDs ? ds = nEW : tg = nEW;
    }
    if (notify != null) {
      hh = (((hh.toUnsigned(63) >> 30) + 1) << 30) |
          ((hh.toUnsigned(24) << 6) | i.toUnsigned(6));
      notify!(oldS, this);
    }
  }

  /// Error flag is set if index was not in 0..62 range, or if race occured.
  /// In production code it is prudent to check error sparsely, eg. on leaving
  /// a route (if error happened it means your tests are broken - in debug mode
  /// assertion should threw. Error flag clear: `x.tg = x.tg.toUnsigned(63);`)
  bool get error => tg & 1 << 63 != 0;

  /// Race flag is set if Toggler live object was modified while `checkFix`
  /// has been doing changes based on the older state. If such race occurs,
  /// changes based on older state are **not** applied (are lost).
  /// Races should not happen with checkFix calling only sync code, but may
  /// happen if checkFix awaited for something slow.
  /// You may clear race flag using: `x.ds = x.ds.toUnsigned(63);` code.
  bool get race => ds & 1 << 63 != 0;

  /// provides an index of a last singular change coming from the outer code.
  /// Indice of following changes (by the checkFix fixer) are not preserved.
  /// The `hh` member keeps history of five most recent changes.
  int get lastChangeIndex => hh.toUnsigned(6);

  /// Index operator returns true if Toggler item is set at given index
  /// (usually const int for a symbolic name). Example with get_it_mixin:
  /// ```Dart
  ///   const kTG_freeUser = 11; // in common code
  ///   final flags = Toggler(); // in model.dart
  ///   ...
  ///   final flags = getX((Model m) => m.flags);
  ///   watchX((Model m) => m.flChg); // flChg is a simple ValueNotifier
  ///   ...
  ///   return (flags[kTG_freeUser])  // <= Toggler was designed for this
  ///      ? const IconFree(...)
  ///      : const IconPaid(...),
  /// ```
  bool operator [](int i) => tg & (1 << _v(i)) != 0;

  /// hasActive returns true if Toggler item at index `i` is enabled
  /// `if (flags.hasActive(kTG_premium)) {...}`
  bool hasActive(int i) => ds & (1 << _v(i)) == 0;

  /// set (on:true) item at index i
  void set(int i, {bool ifActive = false}) {
    if (ifActive && !hasActive(i)) return;
    i = _v(i);
    int ntg = tg;
    if (rm & (1 << i) != 0) {
      // clear all in this radio group
      int k = i;
      int n = 1 << i;
      while (k < 63 && rm & n != 0) {
        ntg &= ~n;
        n <<= 1;
        k++;
      }
      k = i;
      n = 1 << i;
      while (k >= 0 && rm & n != 0) {
        ntg &= ~n;
        n >>= 1;
        k--;
      }
    }
    ntg |= 1 << i;
    if (ntg != tg) _ckFix(i, ntg, false);
  }

  /// clears item at index i
  void clear(int i, {bool ifActive = false}) {
    if (ifActive && !hasActive(i)) return;
    int ntg = tg;
    ntg &= ~(1 << _v(i));
    if (ntg != tg) _ckFix(i, ntg, false);
  }

  /// method `setTo` sets item at index i to the explicit state on:true or off:false.
  /// Optional argument `ifActive: true` allows changes only of an Active item.
  void setTo(int i, bool state, {bool ifActive = false}) {
    if (ifActive && !hasActive(i)) return;
    state ? set(i) : clear(i);
  }

  /// toggle changes item at index i to the opposite state.
  /// Note that toggle does not know about radio groups by itself
  /// so toggle on an active radio will make all in group being off!
  /// Programmatic changes do not take 'disabled' status into account
  /// unless explicitly wanted by passing ifActive: true.
  void toggle(int i, {bool ifActive = false}) {
    if (ifActive && !hasActive(i)) return;
    if (tg & (1 << _v(i)) != 0) {
      int ntg = tg;
      ntg &= ~(1 << i);
      if (ntg != tg) _ckFix(i, ntg, false);
    } else {
      set(i);
    }
  }

  /// enable item at index i
  void enable(int i) => setDS(i, true);

  /// disable item at index i
  void disable(int i) => setDS(i, false);

  /// enable (true) or disable (false) an item at index i
  void setDS(int i, bool enable) {
    int nds = ds;
    enable ? nds &= ~(1 << _v(i)) : nds |= 1 << _v(i);
    if (nds != ds) _ckFix(i, nds, true);
  }

  /// radioGroup declares a range of items that have "one of" behaviour.
  /// Ranges may not overlap nor even be adjacent. Ie. there must be at least
  /// one non-grouped item placed between two radio groups. Eg. ranges 0..3 and
  /// 5..7 (gap at 4) are OK but 0..3 and 4..6 are NOT (no 3 to 4 gap).
  /// Gap index is fully usable for an independent item.
  ///
  /// Allowed group boundaries are: `0 <= first < last < 63`, if this condition
  /// is not met, or ranges touch or overlap, radioGroup will throw on debug
  /// build, or it will set error flag on production.
  void radioGroup(int first, int last) {
    if (first > 62 || last > 62 || last < 0 || first < 0 || first >= last) {
      _seterr();
      assert(false,
          'Bad radio range. Valid ranges: 0 <= first < last < 63 | first:$first last:$last');
      return; // do nothing on production
    }
    var nrm = rm;
    var i = first;
    var c = 1 << (first - (i == 0 ? 0 : 1));
    bool overlap() {
      if (rm & c != 0) {
        _seterr();
        assert(false,
            'Radio ranges may NOT overlap nor be adjacent to each other [$first..$last])');
        return true;
      }
      return false;
    }

    if (overlap()) return; // i-1
    if (i > 0) c <<= 1;
    while (true) {
      if (overlap()) return; // i
      if (i > last) break;
      nrm |= c;
      c <<= 1;
      i++;
    }
    rm = nrm;
  }

  /// returns true if any item is set, possibly within a given range (inclusive)
  /// It eg. can be used to test whether user made a choice tapping on a button
  /// in a radio group that initially had all items off.
  bool setInRange({int first = 0, last = 62}) {
    _v(first);
    _v(last);
    if (first > last) return false;
    int n = 1 << first;
    while (first < 63 && first <= last) {
      if (tg & n != 0) return true;
      n <<= 1;
      first++;
    }
    return false;
  }

  /// returns true if state of this and other differs, possibly within a given
  /// indice range first..last (inclusive).
  /// This can be used to separately fire distinct ChangeNotifiers for a subsets
  /// of Toggler's state:
  /// ```Dart
  ///
  /// ```
  bool differsFrom(Toggler other, {int first = 0, int last = 62}) {
    if (first > 62 || last > 62 || last < 0 || first < 0 || first > last) {
      assert(false, 'Bad range. Valid ranges: 0 <= first <= last < 63');
      return false; // do nothing on production
    }
    int p = first;
    int n = 1 << first;
    int d = tg ^ other.tg;
    while (p < 63 && p <= last) {
      if (d & n != 0) return true;
      n <<= 1;
      p++;
    }
    p = first;
    n = 1 << first;
    d = ds ^ other.ds;
    while (p < 63 && p <= last) {
      if (d & n != 0) return true;
      n <<= 1;
      p++;
    }
    return false;
  }
}

/// The `check & fix` validator returning false will make Toggler to abandon
/// pending change. If it returns true new state will be applied and ChangeNotify
/// will fire.  Validator may also tinker with state, hence Fix in name.
typedef TogglerValidateFix = bool Function(Toggler oldState, Toggler newState);

/// Change notifier for Toggler is provided both oldState (copy) and current
/// object. It allows for static wiring into many Flutter state management
/// libraries like `provider` or `get_it_mixin`. Having both old and current
/// state at hand allows for pushing a fine-grained change notifications from
/// a single Toggler object.
typedef TogglerChangeNotify = void Function(Toggler oldState, Toggler current);
