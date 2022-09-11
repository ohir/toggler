/// Toggler library can be a part of state management solution. It is designed
/// for use in "ambient" (singleton) Models but it also may support _reactive_
/// architectures via its `state` and `clone` copying constructors.
/// For safe use in a singleton Toggler has built-in data race detection and
/// automatic abandon of an outdated change.
///
/// Toggler supports pre-commit state validation and mutation; then it fires
/// change notifications on a new state commit. Toggler is small, fast, and it has
/// no dependecies.
library toggler;

/// Toggler class keeps state of up to 63 boolean values (items) that can be
/// manipulated one by one, or in concert. _Radio group_ behaviour can be
/// declared on up to 20 separated groups of items. Independent _disabled_ flag
/// is avaliable for every item, to be used in UI builders.  Each value can be
/// retrieved using index[] operator, usually with a constant symbolic name.
class Toggler {
  /// togglee item 0..62 value bit:     1:set 0:cleared
  int tg; //
  /// togglee item 0..62 disable bit:   1:disabled 0:enabled
  int ds; //
  /// radio-groups 0..62 mask:          1:member of adjacent 1s group
  int rm; //
  /// history hash and `serial` counter - updated on each notify call
  int hh; //

  /// `void Function(Toggler oldState, Toggler current)`
  /// notify is called after change to the Toggler state has been commited.
  ///
  /// Toggler object with a non-null notifier is said to be a _live_ one,
  /// otherwise object is said to be a _state copy_.
  TogglerChangeNotify? notify;

  /// Function `bool fix(Toggler oldState, Toggler newState)`
  /// validates and possibly mutates pending _newState_. Upon _true_ return
  /// _newState_ will be applied to the live Toggler object in a single run.
  /// Otherwise changes will be abandoned. The `fix` may also suppress subsequent
  /// `notify` by setting `done` on a _newState_.  If `fix` is _null_, every
  /// single state change is commited immediately then `notify` function is
  /// called, if provided.
  TogglerValidateFix? fix;

  /// All Toggler members are public for easy tests and custom serialization.
  ///
  /// Note: _the `hh` member keeps state identity bits (serial and history tail).
  /// Whether it should be serialized and restored depends on App's state
  /// management architecture used._
  Toggler({
    this.notify,
    this.fix,
    this.tg = 0,
    this.ds = 0,
    this.rm = 0,
    this.hh = 0,
  }) {
    rm.toUnsigned(63); // always clear done flag on copy/clone/deserialize
  }

  /// get copy of the state. Returned new _Toggler_ has _notify_ and _fix_
  /// fields set to `null`.
  Toggler state() => Toggler(tg: tg, ds: ds, rm: rm, hh: hh);

  /// returns deep copy of the Toggler, including `notify` and `fix`
  /// function pointers. _Here be dragons!_
  Toggler clone() =>
      Toggler(tg: tg, ds: ds, hh: hh, rm: rm, notify: notify, fix: fix);

  int _v(int i) {
    assert(i < 63 && i >= 0, 'Toggler index ($i) out of range!');
    if (i > 62 || i < 0) error = true;
    return i.toUnsigned(6);
  }

  void _ckFix(int i, int nEW, bool isDs) {
    final oldS = Toggler(tg: tg, ds: ds, rm: rm, hh: hh);
    final nhh = notify == null
        ? hh // copy of state may mutate but may not alter serial nor history
        : (((hh.toUnsigned(63) >> 18) + 1) << 18) |
            ((hh.toUnsigned(12) << 6) | i.toUnsigned(6));
    if (fix != null) {
      final newS =
          Toggler(tg: isDs ? tg : nEW, ds: isDs ? nEW : ds, rm: rm, hh: nhh);
      if (fix!(oldS, newS)) {
        if (hh != oldS.hh) {
          ds |= 1 << 63; // clear with: x.ds = x.ds.toUnsigned(63);
          error = true;
          assert(hh == oldS.hh,
              'Data race detected on _ckFix update! [history: ${hh.toUnsigned(18)}]');
          return;
        }
        tg = newS.tg;
        ds = newS.ds;
        rm = newS.rm;
        hh = newS.hh;
      }
    } else {
      isDs ? ds = nEW : tg = nEW;
      hh = nhh;
    }
    if (notify != null) {
      done ? rm = rm.toUnsigned(63) : notify!(oldS, this);
    }
  }

  /// Error flag is set if index was not in 0..62 range, or data race occured.
  /// In release code it is prudent to check error sparsely, eg. on leaving
  /// a route (if error happened it means your tests are broken - as in debug builds
  /// an assertion should threw.
  bool get error => tg & 1 << 63 != 0;
  set error(bool e) => e ? tg |= 1 << 63 : tg = tg.toUnsigned(63);

  /// Race flag is set if Toggler live object was modified while `fix`
  /// has been doing changes based on the older state. If such a race occurs,
  /// changes based on older state are **not** applied (are lost).
  /// Races should not happen with fix calling only sync code, but may
  /// happen if fix awaited for something slow.
  bool get race => ds & 1 << 63 != 0;
  set race(bool e) => e ? ds |= 1 << 63 : ds = ds.toUnsigned(63);

  /// Done flag can be set on a state copy to mark it as "used". Copy or clone
  /// always will have _done_ set to false. _Done_ flag of a _live_ Toggler
  /// object is cleared right before _notify_ call.
  bool get done => rm & 1 << 63 != 0;
  set done(bool e) => e ? rm |= 1 << 63 : rm = rm.toUnsigned(63);

  /// set _done_ _true_, always returns _true_
  bool setDone() => (rm |= 1 << 63) != 0;

  /// provides an index of a last singular change coming from the outer code (
  /// ie. indice of related changes made by `fix` are not preserved).
  /// Note that on the copied state objects `recent` value is frozen
  /// to the value origin had at copy creation time.
  int get recent => hh.toUnsigned(6);

  /// monotonic counter of changes. Increased on each `notify` call. In state
  /// copies `serial` is frozen to the value origin had at copy creation time.
  int get serial => hh >> 18;

  /// _true_ if other copy has been created after us. A live Toggler object can
  /// never be older than a copy or other live Toggler.
  bool isOlderThan(Toggler other) => notify != null
      ? false
      : other.notify != null
          ? true
          : hh >> 18 < other.hh >> 18;

  /// _true_ if Toggler item at _index_ is set (`tg` item bit is 1).
  bool operator [](int i) => tg & (1 << _v(i)) != 0;

  /// _true_ if Toggler item at index `i` is enabled
  bool active(int i) => ds & (1 << _v(i)) == 0;

  /// set (_1_, _on_, _true_) item at index `i`.
  /// Optional argument `ifActive: true` permits change only if item is enabled,
  /// By default state changes are not suppressed by the _disable_ flag.
  void set(int i, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
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

  /// clear (to _0_, _off_, _false_ state) item at index `i`.
  /// Optional argument `ifActive: true` permits change only if item is enabled,
  /// By default state changes are not suppressed by the _disable_ flag.
  void clear(int i, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    int ntg = tg;
    ntg &= ~(1 << _v(i));
    if (ntg != tg) _ckFix(i, ntg, false);
  }

  /// sets item state at index `i` to the explicit given value.
  /// Optional argument `ifActive: true` allows changes only of an active item.
  void setTo(int i, bool state, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    state ? set(i) : clear(i);
  }

  /// toggle changes item at index i to the opposite state.
  /// Note that toggle does not know about radio groups by itself
  /// so toggle on an active radio will make all in group being off.
  /// Programmatic changes do not take _disabled_ status into account
  /// unless explicitly wanted by passing `ifActive: true`.
  void toggle(int i, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    if (tg & (1 << _v(i)) != 0) {
      int ntg = tg;
      ntg &= ~(1 << i);
      if (ntg != tg) _ckFix(i, ntg, false);
    } else {
      set(i);
    }
  }

  /// enable item at index `i`
  void enable(int i) => setDS(i, true);

  /// disable item at index `i`
  void disable(int i) => setDS(i, false);

  /// enable (true) or disable (false) an item at index `i`
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
  /// build, or it will set error flag on _release_ build.
  ///
  /// A radioGroup creation does not `notify`. Any number of calls to radioGroup
  /// can be replaced by assigning a predefined constant to the `rm` member.
  void radioGroup(int first, int last) {
    if (first > 62 || last > 62 || last < 0 || first < 0 || first >= last) {
      error = true;
      assert(false,
          'Bad radio range. Valid ranges: 0 <= first < last < 63 | first:$first last:$last');
      return; // do nothing at release
    }
    var nrm = rm;
    var i = first;
    var c = 1 << (first - (i == 0 ? 0 : 1));
    bool overlap() {
      if (rm & c != 0) {
        error = true;
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

  /// _true_ if any item is set, optionally in a given indice range.
  bool anyInSet({int first = 0, last = 62}) {
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

  /// _true_ if state of `this` and `other` differs, possibly only within a given
  /// range _first..last_ (inclusive).  This can be used to fire ChangeNotifiers
  /// distinct for a provided range of a common to the App Toggler state.
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

/// `fix` function signature
typedef TogglerValidateFix = bool Function(Toggler oldState, Toggler newState);

/// `notify` function signature
typedef TogglerChangeNotify = void Function(Toggler oldState, Toggler current);
