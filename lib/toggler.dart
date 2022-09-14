// Copyright (c) 2022 Wojciech S. Czarnecki, aka Ohir Ripe

/// Toggler library can be a part of state management solution. It is designed
/// for use in singleton aka "ambient" Models but it also may support _reactive_
/// architectures via its `state` and `clone` copying constructors.
/// For safe use as a singleton Toggler has built-in data race detection and
/// automatic abandon of an outdated change.
///
/// Toggler supports pre-commit state validation and mutation. After any single
/// change it first fires `fix` state transition handler, then commits new state
/// `fix` prepared, then calls `notify` to inform outer world of changes made.
///
/// Toggler is small, fast, and it has no dependecies.
///
/// Test coverage: 100.0% (138 of 138 lines)
library toggler;

const _noweb = 0; // 0:web 10:noWeb // dart2js int is 53 bit
const _bf = 52 + _noweb; // flag bit
const _im = 51 + _noweb; // item max bit

/// Last usable bit index. While it could be 62, it is now 51 to enable web use.
/// If you need no web and need more than 52 flags you may use source package
/// and update it with `const _noweb = 10;`
const kTGindexMax = _im;

/// Toggler class keeps state of up to 52 boolean values (items) that can be
/// manipulated one by one or in concert. _Radio group_ behaviour can be
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

  /// changed at 0..51 mask:            1:just changed at this bit index
  ///
  /// change mask allows for a fine-grain control of what logical parts of UI
  /// Presentation layer should rebuild. At `fix` call _newState.cm_ will have
  /// only one bit set, for use in `fix` code, then after `fix` _cm_ will be
  /// updated to reflect **all** changed indice, including ones changed in
  /// `fix`.
  int cm;

  /// history hash keeps `serial`, `cabyte`, and `recent` values.
  /// Live Toggler updates `hh` on each state change. State copies have `hh`
  /// frozen at values origin had at copy creation time.
  ///
  /// Note: Whether `hh` should be serialized and restored depends on App's state
  /// management architecture used.
  int hh;

  /// handler `void notify(Toggler oldState, Toggler current)`
  /// is called after state change has been _commited_.
  TogglerChangeNotify? notify;

  /// handler `bool fix(Toggler oldState, Toggler newState)`
  /// manages state transitions. Eg. enabling or disabling items if some
  /// condition is met.  If `fix` is null every single state change from a
  /// setter is commited immediately.
  ///
  /// On _true_ return, _newState_ will be commited, ie. copied to the live
  /// Toggler object in a single run.  Then `notify` part will run, if present
  /// and unless supressed.
  ///
  /// A `fix` code may suppress subsequent `notify` call by setting _done_ flag
  /// on a _newState_. This internal _done_ state is not copied to the live
  /// Toggler on commit.
  ///
  /// In simpler Apps `fix` state handler is the only place where business-logic
  /// is implemented and where Model state transitions occur. In _reactive_
  /// state management, usually `notify` is null and `fix` alone sends state
  /// copies up some Stream.
  TogglerValidateFix? fix;

  /// All Toggler members are public for easy tests and custom serialization.
  Toggler({
    this.notify,
    this.fix,
    this.tg = 0,
    this.ds = 0,
    this.rm = 0,
    this.cm = 0,
    this.hh = 0,
  }) {
    rm = rm.toUnsigned(_im); // never copy with done
  }

  /// get copy of the state; _done_ flag and handlers are cleared.
  Toggler state() => Toggler(tg: tg, ds: ds, rm: rm, cm: cm, hh: hh);

  /// returns a deep copy of the Toggler, including `notify` and `fix`
  /// function pointers; and _done_ flag cleared.
  Toggler clone() =>
      Toggler(tg: tg, ds: ds, hh: hh, rm: rm, cm: cm, notify: notify, fix: fix);

  int _v(int i) {
    assert(i < _bf && i >= 0, 'Toggler index ($i) out of range!');
    if (i < _bf && i > 0) return i;
    error = true;
    return 0;
  }

  /// Toggler change engine. Exposed only to allow straighforward testing and debugging Apps.
  /// Do not call `pump` in App code unless you really really KWYAD.
  /// For legitimate use of pump see `replay(cas)` method in example TogglerRx
  /// extension
  void pump(int i, int nEW, bool isDs, bool actSet) {
    if (notify == null && fix == null) {
      cm = isDs ? ds ^ nEW : tg ^ nEW;
      isDs ? ds = nEW : tg = nEW;
      return;
    }
    final oldS = Toggler(tg: tg, ds: ds, rm: rm, hh: hh);
    if (done) oldS.setDone(); // fix and notify should know
    final nhh = (((hh.toUnsigned(_bf) >> 16) + 1) << 16) |
        ((hh.toUnsigned(8) << 8) |
            (isDs ? (1 << 7) : 0) | //   b7: tg/ds
            (actSet ? (1 << 6) : 0) | // b6: clear/set
            i.toUnsigned(6)); //     b5..b0: item index
    if (fix != null) {
      final newS =
          Toggler(tg: isDs ? tg : nEW, ds: isDs ? nEW : ds, rm: rm, hh: nhh);
      newS.cm = isDs ? ds ^ nEW : tg ^ nEW; // pass coming single change mask
      if (fix!(oldS, newS)) {
        if (hh != oldS.hh) {
          ds |= 1 << _bf;
          error = true;
          assert(hh == oldS.hh,
              'Data race detected on _ckFix update! [history: ${hh.toUnsigned(16)}]');
          return;
        }
        tg = newS.tg;
        ds = newS.ds;
        hh = newS.hh;
        rm = newS.rm; // may come 'done'
        cm = (tg ^ oldS.tg) | (ds ^ oldS.ds); // change mask of fixed
      }
    } else {
      hh = nhh;
      rm = rm.toUnsigned(_im);
      cm = isDs ? ds ^ nEW : tg ^ nEW;
      isDs ? ds = nEW : tg = nEW;
    }
    if (notify != null) {
      done ? rm = rm.toUnsigned(_im) : notify!(oldS, this);
    }
  }

  /// can be set on a _live_ Toggler by an outer code. 'Done' flag always
  /// will be cleared at state change, ie. right after a setter runs.
  ///
  /// Both `fix` and `notify` handlers may test _oldState_ whether _done_ was
  /// set.  The `fix` handler may also set _done_ on a _newState_ to suppress
  /// subsequent _notify_ (_done_ from `fix` does __not__ make to the commited
  /// new state).
  ///
  /// In _reactive_ settings _done_ flag can be set on a state clone to mark it
  /// as "being spent". Note that _done_ flag __always__ comes cleared on all new
  /// copies and clones - whether made of live object or of a state copy.
  bool get done => rm & 1 << _bf != 0;
  set done(bool e) => e ? rm |= 1 << _bf : rm = rm.toUnsigned(_im);

  /// sets done, returns true - for `setDone() ? : ` constructs.
  bool setDone() => (rm |= 1 << _bf) != 0;

  /// Error flag is set if index was not in 0..51 range, or data race occured.
  ///
  /// In release code it is prudent to check error sparsely, eg. on leaving
  /// a route (if error happened it means your tests are broken - as in debug builds
  /// an assertion should threw.
  bool get error => tg & 1 << _bf != 0;
  set error(bool e) => e ? tg |= 1 << _bf : tg = tg.toUnsigned(_im);

  /// set internally if Toggler live object was modified while `fix`
  /// has been doing changes based on an older state.
  ///
  /// If such a race occurs, changes based on older state are **not** applied
  /// (are lost).  Races should not happen with fix calling only sync code, but
  /// may happen if fix awaited for something slow.
  bool get race => ds & 1 << _bf != 0;
  set race(bool e) => e ? ds |= 1 << _bf : ds = ds.toUnsigned(_im);

  /// _compact action byte_ of the most recent change coming from a state setter.
  ///
  /// CAbyte keep _incoming_ changes, not ones made internally by `fix`.
  /// CAbyte layout: `(0/1) b7:tg/ds b6:clear/set b5..b0 change index`
  int get cabyte => hh.toUnsigned(8);

  /// index of the most recent change coming from a state setter
  int get recent => hh.toUnsigned(6);

  /// monotonic counter increased on each state change. In _state copies_
  /// `serial` is frozen at value origin had at copy creation time.
  int get serial => hh.toUnsigned(_bf) >> 16;

  /// _true_ if other copy has been created after us. A live Toggler object
  /// (one with a non-null notify) can never be older than a copy or other live
  /// Toggler.
  ///
  /// Note! A concession is made for _reactive_ uses: live state clones with
  /// only `fix` being non-null compare with each other as copies do.
  bool isOlderThan(Toggler other) => notify != null
      ? false
      : other.notify != null
          ? true
          : hh.toUnsigned(_bf) >> 16 < other.hh.toUnsigned(_bf) >> 16;

  /// _true_ if Toggler item at _index_ is set (`tg` item bit is 1).
  bool operator [](int i) => tg & (1 << _v(i)) != 0;
  void operator []=(int i, bool v) => setTo(i, v);

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
      while (k < _bf && rm & n != 0) {
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
    if (first > _im || last > _im || last < 0 || first < 0 || first >= last) {
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
  bool anyInSet({int first = 0, last = _im}) {
    first = _v(first);
    last = _v(last);
    if (first > last) return false;
    int n = 1 << first;
    while (first < _bf && first <= last) {
      if (tg & n != 0) return true;
      n <<= 1;
      first++;
    }
    return false;
  }

  /// _true_ if state of `this` and `other` differs, possibly only within a given
  /// range _first..last_ (inclusive).  This can be used to fire ChangeNotifiers
  /// distinct for a provided range within a common to the App Toggler state.
  bool differsFrom(Toggler other, {int first = 0, int last = _im}) {
    if (first > _im || last > _im || last < 0 || first < 0 || first > last) {
      assert(
          false, 'Bad range. Valid ranges: 0 <= first <= last < 52web|63aot');
      return false; // do nothing on release
    }
    int p = first;
    int n = 1 << first;
    int d = tg ^ other.tg;
    while (p < _bf && p <= last) {
      if (d & n != 0) return true;
      n <<= 1;
      p++;
    }
    p = first;
    n = 1 << first;
    d = ds ^ other.ds;
    while (p < _bf && p <= last) {
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
