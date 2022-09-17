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
/// Test coverage: 100.0% (145 of 145 lines)
library toggler;

const _noweb = 0; // 0:web 10:noWeb // dart2js int is 53 bit
const _bf = 52 + _noweb; // flag bit
const _im = 51 + _noweb; // item max bit

/// Last usable bit index. While it could be 62, it is now 51 to enable web use.
/// If you need no web and need more than 52 flags you may use source package
/// and update it with `const _noweb = 10;`
const tgIndexMax = _im;

/// Toggler class keeps state of up to 52 boolean values (items) that can be
/// manipulated one by one or in concert. _Radio group_ behaviour can be
/// declared on up to 17 separated groups of items. Independent _disabled_ flag
/// is avaliable for every item, to be used in UI builders.  Each value can be
/// retrieved using index[] operator, usually with a constant symbolic name.
/// By convention Toggler const indice use `tg` name prefix, and respective const
/// mask bits use `tm`. Eg. `const tgPrize = 33; const tmPrize = 1 << tgPrize;`
class Toggler {
  /// togglee item 0..51 value bit:     1:set 0:cleared.
  int tg;

  /// togglee item 0..51 disable bit:   1:disabled 0:enabled.
  ///
  /// Note that class api operates in terms of "active", ie. on negation of _ds_
  /// bits.
  int ds;

  /// radio-groups 0..51 (mask):        1:member of adjacent 1s group.
  int rg;

  /// recently changed at 0..51 (bits): 1:at this bit index.
  ///
  /// changed bits indicator tells indice of all state changes, both in _tg_ and
  /// in _ds_.  At `fix` call _newState.chb_ will have only one bit set, for use
  /// in `fix` code, then after `fix` _chb_ will be updated to reflect **all**
  /// changed indice, including ones changed by `fix`. Use _changed_ method to
  /// access _chb_ in a readable way.
  int chb;

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
  /// Toggler object with state transition handlers (`fix`, `notify`) is
  /// said to be a _live_ one. Otherwise, if handlers are null, it is a _state
  /// copy_ object.
  Toggler({
    this.notify,
    this.fix,
    this.tg = 0,
    this.ds = 0,
    this.rg = 0,
    this.chb = 0,
    this.hh = 0,
  }) {
    rg = rg.toUnsigned(_im); // never copy with done
  }

  /// flag can be set on a _live_ Toggler by an outer code. 'Done' always
  /// is cleared at any state change, ie. right after any setter runs.
  ///
  /// Both `fix` and `notify` handlers may test _oldState_ whether _done_ was
  /// set.  The `fix` handler may also set _done_ on a _newState_ to suppress
  /// subsequent _notify_ (_done_ from `fix` does __not__ make to the commited
  /// new state).
  ///
  /// In _reactive_ settings _done_ flag can be set on a state clone to mark it
  /// as "being spent". Note that _done_ flag __always__ comes cleared on all new
  /// copies and clones - whether made of live object or of a state copy.
  bool get done => rg & 1 << _bf != 0;
  set done(bool e) => e ? rg |= 1 << _bf : rg = rg.toUnsigned(_im);

  /// Error flag is set if index was not in 0..51 range, or if data race occured.
  ///
  /// In release code it is prudent to check error sparsely, eg. on leaving
  /// a route (if error happened it means your tests are broken: as in debug
  /// builds an assertion should threw right after setting _error_ or _race_.
  bool get error => tg & 1 << _bf != 0;
  set error(bool e) => e ? tg |= 1 << _bf : tg = tg.toUnsigned(_im);

  /// set internally if Toggler live object was modified while `fix`
  /// has been doing changes based on an older state.
  ///
  /// If such a race occurs, changes based on older state are **not** applied
  /// (are lost).  Races should not happen with _fix_ calling only sync code,
  /// but may happen if fix awaited for something slow.
  bool get race => ds & 1 << _bf != 0;
  set race(bool e) => e ? ds |= 1 << _bf : ds = ds.toUnsigned(_im);

  /// index of the most recent single change coming from a state setter
  int get recent => hh.toUnsigned(6);

  /// monotonic counter increased on each state change. In _state copies_
  /// `serial` is frozen at value origin had at copy creation time.
  int get serial => hh.toUnsigned(_bf) >> 16;

  int _v(int i) {
    assert(i < _bf && i >= 0, 'Toggler index ($i) out of range!');
    if (i < _bf && i > 0) return i;
    error = true;
    return 0;
  }

  // /* methods */ /////////////////////////////////////////////////////////////
  /// _true_ if any item is set, optionally test can be confined to positions
  /// provided with _relmask_ (relevant bit: 1), or within a given _first..last_
  /// indice range. The _relmask_ has higher priority than optional range, so
  /// either query with _relmask_ or with _first..last_, not both.
  bool anyInSet({int first = 0, int last = _im, int relmask = 0}) {
    if (relmask != 0) return tg & relmask != 0 || ds & relmask != 0;
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

  /// _true_ if Toggler item at index `i` is enabled (has _ds_ bit 0).
  bool active(int i) => ds & (1 << _v(i)) == 0;

  /// _true_ if latest changes happened at _i_ index, or at one of _relmask_
  /// set (1) positions.
  bool changed({int? i, int relmask = 0}) {
    if (i != null && relmask == 0) return chb & (1 << _v(i)) != 0;
    if (i == null) return chb ^ relmask != 0;
    return relmask & chb & (1 << _v(i)) != 0;
  }

  /// clear (to _0_, _off_, _false_ state) item at index `i`.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie. item will be cleared only if it is active.
  ///
  /// Note that _clear_ does not know about radio groups by itself
  /// so _clear_ of an active radio member will make all in group being off.
  void clear(int i, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    int ntg = tg;
    ntg &= ~(1 << _v(i));
    if (ntg != tg) pump(i, ntg, false, false);
  }

  /// returns a deep copy of the Toggler, including `notify` and `fix`
  /// function pointers; _done_ flag is cleared always.
  Toggler clone() => Toggler(
      tg: tg, ds: ds, hh: hh, rg: rg, chb: chb, notify: notify, fix: fix);

  /// _true_ if state of `this` and `other` differs. Optionally just at positions
  /// provided with _relmask_ (1), or within a given _first..last__ indice
  /// range. _Relmask_ has higher priority than range, so either query with
  /// _relmask_ or with _first..last_, not both.
  ///
  /// Both range and relmask allow eg. for ChangeNotifiers be distinct for
  /// different parts of a common to the App Toggler.
  bool differsFrom(Toggler other,
      {int first = 0, int last = _im, int relmask = 0}) {
    if (relmask != 0) {
      return tg & relmask != other.tg & relmask ||
          ds & relmask != other.ds & relmask;
    }
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

  /// enable item at index `i`.
  void enable(int i) => setDS(i, false);

  /// disable item at index `i`.
  void disable(int i) => setDS(i, true);

  /// _true_ if other copy has been created after us. A live Toggler object
  /// (one with a non-null notify) can never be older than a copy or other live
  /// Toggler.
  ///
  /// Note! A concession is made for _reactive_ uses: live state clones with
  /// only `fix` attached compare with each other just as copies do.
  bool isOlderThan(Toggler other) => notify != null
      ? false
      : other.notify != null
          ? true
          : hh.toUnsigned(_bf) >> 16 < other.hh.toUnsigned(_bf) >> 16;

  /// Toggler change engine. Exposed only to allow straighforward testing and
  /// debugging Apps.  Do not call `pump` for managing App state unless you
  /// really really KWYAD.  For legitimate use of pump see `replay(cas)` method
  /// in example TogglerRx extension.
  void pump(int i, int nEW, bool isDs, bool actSet) {
    if (notify == null && fix == null) {
      chb = isDs ? ds ^ nEW : tg ^ nEW;
      isDs ? ds = nEW : tg = nEW;
      return;
    }
    final oldS = Toggler(tg: tg, ds: ds, rg: rg, hh: hh);
    if (done) oldS.setDone(); // fix and notify should know
    final nhh = (((hh.toUnsigned(_bf) >> 16) + 1) << 16) | // serial++
        ((hh.toUnsigned(8) & ~0xff) | // b15..b8: internal use
            (isDs ? (1 << 7) : 0) | // cabyte b7: tg/ds
            (actSet ? (1 << 6) : 0) | //      b6: clear/set
            i.toUnsigned(6)); //          b5..b0: item index
    if (fix != null) {
      final newS =
          Toggler(tg: isDs ? tg : nEW, ds: isDs ? nEW : ds, rg: rg, hh: nhh);
      newS.chb = isDs ? ds ^ nEW : tg ^ nEW; // pass coming single change bit
      if (fix!(oldS, newS)) {
        if (hh != oldS.hh) {
          ds |= 1 << _bf;
          error = true;
          assert(hh == oldS.hh,
              'Data race detected on state update! [history: ${hh.toUnsigned(16)}]');
          return;
        }
        tg = newS.tg;
        ds = newS.ds;
        hh = newS.hh;
        rg = newS.rg; // may come 'done'
        chb = (tg ^ oldS.tg) | (ds ^ oldS.ds); // change mask of fixed
      }
    } else {
      hh = nhh;
      rg = rg.toUnsigned(_im);
      chb = isDs ? ds ^ nEW : tg ^ nEW;
      isDs ? ds = nEW : tg = nEW;
    }
    if (notify != null) {
      done ? rg = rg.toUnsigned(_im) : notify!(oldS, this);
    }
  }

  /// radioGroup declares a range of items that have "one of" behaviour.
  /// Ranges may not overlap nor even be adjacent. Ie. there must be at least
  /// one non-grouped item placed between two radio groups. Eg. ranges 0..3 and
  /// 5..7 (gap at 4) are OK but 0..3 and 4..6 are not (no 3 to 4 gap).
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
    var nrm = rg;
    var i = first;
    var c = 1 << (first - (i == 0 ? 0 : 1));
    bool overlap() {
      if (rg & c != 0) {
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
    rg = nrm;
  }

  /// set (_1_, _on_, _true_) item at index `i`.  By default state changes are
  /// not suppresed, but an optional argument `ifActive: true` mandates prior
  /// _active_ check. Ie. item will be set only if it is active.
  void set(int i, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    i = _v(i);
    int ntg = tg;
    if (rg & (1 << i) != 0) {
      // clear all in this radio group
      int k = i;
      int n = 1 << i;
      while (k < _bf && rg & n != 0) {
        ntg &= ~n;
        n <<= 1;
        k++;
      }
      k = i;
      n = 1 << i;
      while (k >= 0 && rg & n != 0) {
        ntg &= ~n;
        n >>= 1;
        k--;
      }
    }
    ntg |= 1 << i;
    if (ntg != tg) pump(i, ntg, false, true);
  }

  /// sets done, always returns true (for `setDone() ? ... : null ` constructs).
  bool setDone() => (rg |= 1 << _bf) != 0;

  /// disable (true) or enable (false) an item at index `i`.
  ///
  /// Note that _ds_ property has bit set to 1 for _disabled_ items.
  void setDS(int i, bool disable) {
    int nds = ds;
    disable ? nds |= 1 << _v(i) : nds &= ~(1 << _v(i));
    if (nds != ds) pump(i, nds, true, disable);
  }

  /// sets item state at index `i` to the explicit given value.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie.  item will change state only if it is active.
  void setTo(int i, bool state, {bool ifActive = false}) {
    if (ifActive && !active(i)) return;
    state ? set(i) : clear(i);
  }

  /// get copy of state; _done_ flag and handlers are cleared on the copy.
  Toggler state() => Toggler(tg: tg, ds: ds, rg: rg, chb: chb, hh: hh);

  /// toggle changes item at index _i_ to the opposite state.
  /// Optional argument `ifActive: true` mandates prior _active_ check.
  /// Ie. item will change state only if it is active.
  ///
  /// Note that toggle does not know about radio groups by itself
  /// so toggle on an active radio will make all in group being off.
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

  /// _true_ if Toggler item at _index_ is set (`tg` item bit is 1).
  bool operator [](int i) => tg & (1 << _v(i)) != 0;

  /// unconditionally set value of item at index _i_.
  void operator []=(int i, bool v) => setTo(i, v);
}

/// `fix` function signature
typedef TogglerValidateFix = bool Function(Toggler oldState, Toggler newState);

/// `notify` function signature
typedef TogglerChangeNotify = void Function(Toggler oldState, Toggler current);
