/// Togglers keeps state of up to 63 items (flags) with built-in support for
/// _radio-button_ type groups and independent _enable_/_disable_ semantics
/// for UI use.  Togglers library supports on-change state validation and fixes,
/// and it can be wired to almost any state management library via its `notify`
/// interface.
///
/// Togglers library is 160 lines of pure Dart with zero dependencies.
///
/// Each Togglers item on/off state can be retrieved using index[] operator,
/// usually with a constant symbolic index number in 0..62 range.
library togglers;

/// class Togglers {
/// ```
///   tg: int items_state,
///   ds: int disable_state,
///   rm: int radio_groups_config,
///   hh: int history_hash,
///   check:  bool verify_and_fix(old_state,current_object)
///   notify: void on_change(current_object)
/// ```
/// }
class Togglers {
  /// items state (0:off/cleared, 1:on/set)
  int tg;

  /// disabled state (0:enabled/active, 1:disabled/inactive)
  int ds;

  /// radio groups configuration (1: marks a radio group member)
  int rm;

  /// history hash, updated for "live" Togglers (ie. having a non-null notifier).
  /// Hh keeps changes counter and keeps a list of most recent 'changed' indice.
  int hh;

  /// Check'n'fix validator: bool check(Togglers prev, Togglers current) {};
  /// where `prev` argument keeps a previous Togglers state and `current`
  /// references current (live) Togglers object with state changed.
  /// Check should return true to have changes stay and notification recipient
  /// called, and return false should changes needs to be retracted.
  ///
  /// Check function may NOT make changes to the `current` Togglers object
  /// as it would then be recursively called again. To alter (fix) current state
  /// it MAY change the COPY it got as 'prev' argument; then it MAY update live
  /// object using its `updateFromCopy` method:
  /// ```Dart
  /// bool check(Togglers pt, Togglers cu) {
  ///   // pt is a copy of the previous state, cu is the current live object,
  ///   // ...perform checks...
  ///   // ...seems that backend altered the ktgFreeUser flag...
  ///
  ///   if (cu[ktgFreeUser] && cu.hasActive(ktgDoNotShowBanners)) {
  ///
  ///     // disable Ad opt-outs for free users:
  ///     pt.syncFrom(cu); // sync state, pt now is our scratchpad of cu
  ///     pt.disable(ktgDoNotShowBanners);
  ///     pt.disable(ktgDoNotShowInterst);
  ///     pt.off(ktgDoNotShowBanners);
  ///     pt.off(ktgDoNotShowInterst);
  ///
  ///     // apply changes to our live Togglers, check for races too:
  ///     if (!cu.updateFromCopy(pt)) {
  ///       raceDetected();
  ///       return false;
  ///     }
  ///   }
  ///   return true; // say OK
  /// }
  /// ```
  TogglersValidateFix? check;

  /// change notifier function `void Function(Togglers current)`;
  /// If notifier is set, Togglers object is said to be "live" one, otherwise
  /// it is a scratchpad data object, usually used to make many consecutive
  /// changes further applied to the live Togglers via `updateFromCopy` call.
  TogglersChangeNotify? notify;

  /// ```
  ///   check:  verify or fix state  check(previous, current)
  ///   notify: call after change     notify(current)
  ///   tg, ds, rm, keep the state;   hh changes for each notify
  /// ```
  /// )
  Togglers({
    this.check,
    this.notify,
    this.tg = 0,
    this.ds = 0,
    this.rm = 0,
    this.hh = 0,
  });

  void _err(String estr, int i) {
    tg |= 1 << 63; // clear with: x.tg = x.tg.toUnsigned(63);
    assert(false, '$estr (given: $i)');
  }

  int _v(int i) {
    if (i > 62 || i < 0) _err('Togglers index out of range!', i);
    return i.toUnsigned(6);
  }

  void _notify(int i) {
    if (notify != null) {
      // hh is updated only for live Togglers object
      hh = (((hh >> 30) + 1) << 30) |
          ((hh.toUnsigned(24) << 6) | i.toUnsigned(6));
      notify!(this);
    }
  }

  /// Error flag is set if index was not in 0..62 range, or if race occured.
  /// In production code it is prudent to check error sparsely, eg. on leaving
  /// a route (if error happened it means your tests are broken - in debug mode
  /// assertion should threw. Error flag clear: `x.tg = x.tg.toUnsigned(63);`)
  bool get error => tg & 1 << 63 != 0;

  /// Race flag is set if Togglers live object was modified while `check` call
  /// has been doing changes based on the older state. In such circumstances
  /// final state of the Togglers object is undefined. Race should not happen
  /// with `check` calling only sync code, but it may happen if check awaits
  /// for something. Without detection hunting for heisenbugs caused by races
  /// on the state would not be possible. If there was a race, error is set too.
  /// You may clear race flag using: `x.ds = x.ds.toUnsigned(63);` code.
  bool get race => ds & 1 << 63 != 0;

  /// provides an index of a last singular change coming from the outer code.
  /// The `hh` member keeps history (indice) of most recent five outer changes.
  int get lastChangeIndex => hh.toUnsigned(6);

  /// sync `tg` and `ds` state from other live Togglers object.
  void syncFrom(Togglers from) {
    tg = from.tg;
    ds = from.ds;
  }

  /// Update state from a copied Togglers object (usually check's prev argument)
  /// Returns `false` if there was a race (or if `from` was not a copy of `this`).
  bool updateFromCopy(Togglers from) {
    tg = from.tg;
    ds = from.ds;
    if (hh != from.hh) {
      ds |= 1 << 63; // clear with: x.ds = x.ds.toUnsigned(63);
      _err('Data race on update spotted!', hh.toUnsigned(30));
      return false;
    }
    return true;
  }

  /// Index operator returns true if Togglers item is set at given index.
  /// Usually index number is provided as a constant for symbolic name:
  /// ```Dart
  ///   final flags = Togglers();
  ///   const ktgFreeUser = 11;
  ///   ...
  ///   return (flags[ktgFreeUser])
  ///      ? const IconFree(...)
  ///      : const IconPU(...),
  /// ```
  bool operator [](int i) => tg & (1 << _v(i)) != 0;

  /// hasActive returns true if Togglers item at index `i` is enabled
  /// `if (flags.hasActive(ktgPremium)) {...}`
  bool hasActive(int i) => ds & (1 << _v(i)) == 0;

  /// method `on` sets item at index i
  void set(int i) {
    i = _v(i);
    int prev = tg;
    if (rm & (1 << i) != 0) {
      int k = i;
      int n = 1 << i;
      // clear all in this radio group
      while (k < 63 && rm & n != 0) {
        tg &= ~n;
        n <<= 1;
        k++;
      }
      k = i;
      n = 1 << i;
      while (k >= 0 && rm & n != 0) {
        tg &= ~n;
        n >>= 1;
        k--;
      }
    }
    tg |= 1 << i;
    if (tg != prev) {
      if (check == null ||
          check!(Togglers(tg: prev, ds: ds, rm: rm, hh: hh), this)) {
        _notify(i);
      } else {
        tg = prev; // check returned false
      }
    }
  }

  /// clears item at index i
  void clear(int i) {
    int prev = tg;
    tg &= ~(1 << _v(i));
    if (tg != prev) {
      if (check == null ||
          check!(Togglers(tg: prev, ds: ds, rm: rm, hh: hh), this)) {
        _notify(i);
      } else {
        tg = prev; // check returned false
      }
    }
  }

  /// method `setTo` sets item at index i to the explicit state on:true or off:false.
  /// Optional argument `ifActive: true` allow changes only for an Active item.
  void setTo(int i, bool state, {bool ifActive = false}) {
    if (ifActive && !hasActive(i)) return;
    if (state) {
      set(i);
    } else {
      clear(i);
    }
  }

  /// toggle changes item at index i to the opposite state.
  /// Note that toggle does not know about radio groups by itself
  /// so toggle on an active radio will make all in group being off!
  void toggle(int i, {bool ifActive = false}) {
    if (ifActive && !hasActive(i)) return;
    if (tg & (1 << _v(i)) != 0) {
      int prev = tg;
      tg &= ~(1 << i);
      if (check == null ||
          check!(Togglers(tg: prev, ds: ds, rm: rm, hh: hh), this)) {
        _notify(i);
      } else {
        tg = prev;
      }
    } else {
      set(i);
    }
  }

  /// enables item at index i
  void enable(int i) => setDS(i, true);

  /// disables item at index i
  void disable(int i) => setDS(i, false);

  /// set enable (true) or disable(false) state
  void setDS(int i, bool state) {
    int prev = ds;
    if (state) {
      ds &= ~(1 << _v(i)); // 0:enabled
    } else {
      ds |= 1 << _v(i); // 1:disabled
    }
    if (ds != prev) {
      if (check == null ||
          check!(Togglers(tg: tg, ds: prev, rm: rm, hh: hh), this)) {
        _notify(i);
      } else {
        ds = prev;
      }
    }
  }

  /// radioGroup setup declares a range of items that have "one of:" behaviour.
  /// Ranges may neither overlap nor even be adjacent. Ie. there must be at
  /// least one non-grouped item placed between two radio groups. Eg. ranges
  /// 1..3, 5..7 (gap at 4) are OK but 1..3 and 4..6 are NOT (no 3 to 4 gap).
  /// Gap index is fully usable for an alone Togglers item.
  /// Allowed group boundaries assertion is: `0 < first < last < 63`, if this
  /// condition is not met, or ranges touch or overlap, radioGroup will throw at
  /// debug build or set error flag on production.
  void radioGroup(int first, int last) {
    if (first > 62 || last > 62 || last < 1 || first < 1 || first >= last) {
      _err('Bad radio range. Valid ranges: 0 < first < last < 63', last);
      return; // do nothing on production
    }
    const emsg = 'Radio ranges may NOT overlap nor be adjacent to each other';
    var i = first;
    if (i > 0 && rm & (1 << (i - 1)) != 0) _err(emsg, i);
    while (i <= last) {
      if (rm & (1 << i) != 0) _err(emsg, i);
      rm |= 1 << i;
      i++;
    }
    if (rm & (1 << i) != 0) _err(emsg, i);
  }

  /// returns true if any item is set in a range (inclusive)
  /// It eg. can be used to test whether user made a choice tapping on a button
  /// in a radio group that initially had all items off.
  bool anyInRange({int first = 0, last = 0}) {
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
}

/// The `check & fix` validator returning false will make Togglers to _retract_
/// current change. If it returns true new state will stay and notify will fire.
/// Validator may also tinker with state, hence Fix in name.
typedef TogglersValidateFix = bool Function(Togglers prev, Togglers current);

/// change notifier for Togglers
typedef TogglersChangeNotify = void Function(Togglers current);
