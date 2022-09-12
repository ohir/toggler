/// Toggler library can be a part of state management solution. It is designed
/// for use in "ambient" (singleton) Models but it also may support _reactive_
/// architectures via its `state` and `clone` copying constructors.
/// For safe use as singleton Toggler has built-in data race detection and
/// automatic abandon of an outdated change.
///
/// Toggler supports pre-commit state validation and mutation. After any single
/// change it first fires `fix` state transition handler, then commits new state
/// `fix` prepared, then calls `notify` to inform outer world of changes made.
///
/// Toggler is small, fast, and it has no dependecies.
///
/// Test coverage: 100.0% (129 of 129 lines)
library toggler;

const _noweb = 0; // 0:web 10:noWeb
const _b63 = 52 + _noweb; // dart2js int is 53 bit
const _b62 = 51 + _noweb; //

/// Last usable bit index. While it could be 62, it is now 51 to enable web use.
/// If you need no web and need more than 52 flags you may use source package
/// and update it with `const _noweb = 10;`
const kTGindexMax = _b62;

/// Toggler class keeps state of up to 52 boolean values (items) that can be
/// manipulated one by one, or in concert. _Radio group_ behaviour can be
/// declared on up to 17 separated groups of items. Independent _disabled_ flag
/// is avaliable for every item, to be used in UI builders.  Each value can be
/// retrieved using index[] operator, usually with a constant symbolic name.
/// Toggler object with non-null state transition handlers (`fix`, `notify`) is
/// said to be a _live_ one. Otherwise it is a plain _state copy_.
class Toggler {
  /// togglee item 0..51 value bit:     1:set 0:cleared
  int tg;

  /// togglee item 0..51 disable bit:   1:disabled 0:enabled
  int ds;

  /// radio-groups 0..51 mask:          1:member of adjacent 1s group
  int rm;

  /// history hash and `serial` counter - updated on each fix or notify call
  ///
  /// Note: Whether `hh` should be serialized and restored depends on App's state
  /// management architecture used.
  int hh;

  /// `void notify(Toggler oldState, Toggler current)`
  /// is called after state change has been _commited_.
  TogglerChangeNotify? notify;

  /// `bool fix(Toggler oldState, Toggler newState)`
  /// manages state transitions. Eg. enabling or disabling items if some
  /// condition is met.  If not given (fix == null), every single state change
  /// is commited immediately.
  ///
  /// validates and possibly mutates pending _newState_. In simpler Apps `fix`
  /// state handler is the only place where business-logic is implemented and where
  /// Model state transitions occur.
  ///
  /// On _true_ return, _newState_ will be commited, ie. copied to the live
  /// Toggler object in a single run.  Then `notify` part will run, if present
  /// and unless supressed.
  ///
  /// A `fix` code may suppress subsequent `notify` call by setting _done_ flag
  /// on a _newState_. This internal _done_ state is not copied to the live
  /// Toggler on commit.
  TogglerValidateFix? fix;

  /// All Toggler members are public for easy tests and custom serialization.
  Toggler({
    this.notify,
    this.fix,
    this.tg = 0,
    this.ds = 0,
    this.rm = 0,
    this.hh = 0,
  }) {
    rm.toUnsigned(_b63); // always clear done flag on copy/clone/deserialize
  }

  /// get copy of the state: _done_ flag and transition handlers are cleared.
  Toggler state() => Toggler(tg: tg, ds: ds, rm: rm, hh: hh);

  /// returns a deep copy of the Toggler, including `notify` and `fix`
  /// function pointers but with _done_ flag cleared. _There be dragons!_
  Toggler clone() =>
      Toggler(tg: tg, ds: ds, hh: hh, rm: rm, notify: notify, fix: fix);

  int _v(int i) {
    assert(i < _b63 && i >= 0, 'Toggler index ($i) out of range!');
    if (i < _b63 && i > 0) return i;
    error = true;
    return 0;
  }

  /// change engine, exposed to allow easy testing and debugging (Apps).
  /// Do not call this in App code unless you keep to KWYAD principle.
  /// See TogglerRx extension, `replay(cas)` method in examples for
  /// legitimate use of pump.
  void pump(int i, int nEW, bool isDs, bool actSet) {
    if (notify == null && fix == null) {
      isDs ? ds = nEW : tg = nEW;
      return;
    }
    final oldS = Toggler(tg: tg, ds: ds, rm: rm, hh: hh);
    if (done) oldS.setDone(); // fix and notify should know
    /// `b7:tg0/ds1 b6:clear0/set1 b5..b0 index`
    final nhh = (((hh.toUnsigned(_b63) >> 16) + 1) << 16) |
        ((hh.toUnsigned(8) << 8) |
            (isDs ? (1 << 7) : 0) |
            (actSet ? (1 << 6) : 0) |
            i.toUnsigned(6));
    if (fix != null) {
      final newS =
          Toggler(tg: isDs ? tg : nEW, ds: isDs ? nEW : ds, rm: rm, hh: nhh);
      if (fix!(oldS, newS)) {
        if (hh != oldS.hh) {
          ds |= 1 << _b63;
          error = true;
          assert(hh == oldS.hh,
              'Data race detected on _ckFix update! [history: ${hh.toUnsigned(16)}]');
          return;
        }
        tg = newS.tg;
        ds = newS.ds;
        hh = newS.hh;
        rm = newS.rm; // may come 'done'
      }
    } else {
      hh = nhh;
      rm = rm.toUnsigned(_b63);
      isDs ? ds = nEW : tg = nEW;
    }
    if (notify != null) {
      done ? rm = rm.toUnsigned(_b63) : notify!(oldS, this);
    }
  }

  /// can be set on a _live_ Toggler by an outer code. 'Done' flag always
  /// will be cleared at state change, ie. right after a setter runs.
  ///
  /// Both `fix` and `notify` handlers may test _oldState_ whether _done_ was
  /// set.  The `fix` mutator may also set _done_ on a _newState_ to suppress
  /// subsequent _notify_ (_done_ from `fix` does __not__ make to the commited
  /// new state).
  ///
  /// In _reactive_ settings _done_ flag can be set on a state clone to mark it
  /// as "being spent". Note that _done_ flag __always__ comes cleared on all new
  /// copies and clones - whether made of live object or a state copy.
  bool get done => rm & 1 << _b63 != 0;
  set done(bool e) => e ? rm |= 1 << _b63 : rm = rm.toUnsigned(_b63);

  /// sets done, returns true - for `setDone() ? : ` constructs.
  bool setDone() => (rm |= 1 << _b63) != 0;

  /// Error flag is set if index was not in 0..51 range, or data race occured.
  ///
  /// In release code it is prudent to check error sparsely, eg. on leaving
  /// a route (if error happened it means your tests are broken - as in debug builds
  /// an assertion should threw.
  bool get error => tg & 1 << _b63 != 0;
  set error(bool e) => e ? tg |= 1 << _b63 : tg = tg.toUnsigned(_b63);

  /// set internally if Toggler live object was modified while `fix`
  /// has been doing changes based on the older state.
  ///
  /// If such a race occurs, changes based on older state are **not** applied
  /// (are lost).  Races should not happen with fix calling only sync code, but
  /// may happen if fix awaited for something slow.
  bool get race => ds & 1 << _b63 != 0;
  set race(bool e) => e ? ds |= 1 << _b63 : ds = ds.toUnsigned(_b63);

  /// a `compact action` CAS byte of the most recent singular change.
  /// On state copies `recent` value is frozen to the value origin had at copy
  /// creation time.
  ///
  /// CAS keep _incoming_ changes, not ones made internally by `fix`.
  /// CAS layout: `(0/1) b7:tg/ds b6:clear/set b5..b0 change index`
  /// See TogglerRx extension `replay(cas)` method in examples.
  ///
  int get recent => hh.toUnsigned(8);

  /// monotonic counter of changes. Increased on each `notify` call. In state
  /// copies `serial` is frozen to the value origin had at copy creation time.
  int get serial => hh.toUnsigned(_b63) >> 16;

  /// _true_ if other copy has been created after us. A live Toggler object can
  /// never be older than a copy or other live Toggler.
  bool isOlderThan(Toggler other) => notify != null
      ? false
      : other.notify != null
          ? true
          : hh >> 16 < other.hh >> 16;

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
      while (k < _b63 && rm & n != 0) {
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
    if (ntg != tg) pump(i, ntg, false, true);
  }

  /// clear (to _0_, _off_, _false_ state) item at index `i`.
  /// Optional argument `ifActive: true` permits change only if item is enabled,
  /// By default state changes are not suppressed by the _disable_ flag.
  void clear(int i, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    int ntg = tg;
    ntg &= ~(1 << _v(i));
    if (ntg != tg) pump(i, ntg, false, false);
  }

  /// sets item state at index `i` to the explicit given value.
  /// Optional argument `ifActive: true` allows changes only of an active item.
  void setTo(int i, bool state, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    state ? set(i) : clear(i);
  }

  /// toggle changes item at index i to the opposite state.
  ///
  /// Note that toggle does not know about radio groups by itself
  /// so toggle on an active radio will make all in group being off.
  /// Programmatic changes do not take _disabled_ status into account
  /// unless explicitly wanted by passing `ifActive: true`.
  void toggle(int i, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    if (tg & (1 << _v(i)) != 0) {
      int ntg = tg;
      ntg &= ~(1 << i);
      if (ntg != tg) pump(i, ntg, false, false);
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
    if (nds != ds) pump(i, nds, true, enable);
  }

  /// radioGroup declares a range of items that have "one of" behaviour.
  /// Ranges may not overlap nor even be adjacent. Ie. there must be at least
  /// one non-grouped item placed between two radio groups. Eg. ranges 0..3 and
  /// 5..7 (gap at 4) are OK but 0..3 and 4..6 are NOT (no 3 to 4 gap).
  /// Gap index is fully usable for an independent item.
  ///
  /// Allowed group boundaries are: `0 <= first < last < 53`, if this condition
  /// is not met, or ranges touch or overlap, radioGroup will throw on debug
  /// build, or it will set error flag on _release_ build.
  ///
  /// A radioGroup creation does not `notify`. Any number of calls to radioGroup
  /// can be replaced by assigning a predefined constant to the `rm` member.
  void radioGroup(int first, int last) {
    if (first > _b62 || last > _b62 || last < 0 || first < 0 || first >= last) {
      error = true;
      assert(false,
          'Bad radio range. Valid ranges: 0 <= first < last < _b63 | first:$first last:$last');
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
  bool anyInSet({int first = 0, last = _b62}) {
    first = _v(first);
    last = _v(last);
    if (first > last) return false;
    int n = 1 << first;
    while (first < _b63 && first <= last) {
      if (tg & n != 0) return true;
      n <<= 1;
      first++;
    }
    return false;
  }

  /// _true_ if state of `this` and `other` differs, possibly only within a given
  /// range _first..last_ (inclusive).  This can be used to fire ChangeNotifiers
  /// distinct for a provided range within a common to the App Toggler state.
  bool differsFrom(Toggler other, {int first = 0, int last = _b62}) {
    if (first > _b62 || last > _b62 || last < 0 || first < 0 || first > last) {
      assert(
          false, 'Bad range. Valid ranges: 0 <= first <= last < 52web|63aot');
      return false; // do nothing on release
    }
    int p = first;
    int n = 1 << first;
    int d = tg ^ other.tg;
    while (p < _b63 && p <= last) {
      if (d & n != 0) return true;
      n <<= 1;
      p++;
    }
    p = first;
    n = 1 << first;
    d = ds ^ other.ds;
    while (p < _b63 && p <= last) {
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
